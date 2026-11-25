# Crew AI

How the hostile crew aboard a raid target think. This file is the design
record for everything under `scripts/crew/`; every change to crew behaviour
updates it in the same commit. Terms are `CONTEXT.md`'s. The plan this is
being built toward is `.scratch/crew-combat/spec.md`, after spec #52
(tickets #53–#63).

## Files

| File | What it owns |
|---|---|
| `crew.gd` (`Crew3D`) | The body: movement, health, animation, door handling, gunnery, cover search, and the state machine that ties them together. |
| `head_zone.gd` (`HeadZone`) | The head: a 0.16 m ball on physics layer 4, riding the rig's `Head` bone through a `BoneAttachment3D`, so a bolt that strikes it is a Headshot. The capsule stays the body. |
| `crew_perception.gd` (`CrewPerception`) | Awareness: the sight cone, how fast Awareness fills and drains, and its bands. Pure arithmetic, tested without physics. |
| `crew_types.gd` (`CrewTypes`) | Guard or Worker, from the Post Room's Role. |
| `gunnery.gd` (`Gunnery`) | How a Guard handles one weapon: aim error, opening spread and closing time, shots per burst, bursts per peek, gap between bursts, time down, settle, lead, range band, hold before shifting, reload factor. One `.tres` per weapon under `resources/gunnery/`, named as the weapon's file, edited in the Sandbox sheet. |
| `../ship/gun_roll.gd` (`GunRoll`) | Which weapon each Guard carries, rolled when `ShipBuilder3D` builds the ship (see Guns below). |
| `crew_routine.gd` (`CrewRoutine`) | Routines: a crew member's Post and its loop of Jobs, planned from the layout's props and Rooms. Pure planning; the body walks it. |
| `crew_traces.gd` (`CrewTraces`) | What the Pirate leaves behind that crew find: bodies, the open boarding Hatch, emptied Containers, Doors left open. |
| `crew_combat.gd` (`CrewCombat`) | Guard teamwork: sharing the Pirate's position, aim that tightens, staggered bursts, flank routes. |
| `ship_alarm.gd` (`ShipAlarm`) | The ship-wide Alarm: raised once, red lights, every crew member told. Built per ship as `Ship/Alarm`. |
| `alarm_panel.gd` (`AlarmPanel`) | The wall panels the Alarm is raised from, where they go, and breaking them. Built under `Ship/AlarmPanels`. |
| `crew_noise.gd` (`CrewNoise`) | Hearing: noise events (footsteps, gunshots, doors), how far each reaches, and which Rooms it carries into. |
| `crew_paths.gd` (`CrewPaths`) | Walking round props: the tile grid made from the layout's floor and prop footprints, and bending a navigator route round what blocks it. |
| `../ui/awareness_markers.gd` (`AwarenessMarkers`) | The bar over each crew member's head and the spotted sting, drawn by the HUD. |

Scene: `scenes/crew_3d.tscn`. Tests: `tests/test_crew.gd` (Awareness, the walk
to look, being shot, the sting, hearing, Workers fleeing and cornered, crew
types, On Edge, Guards sharing his position, aim tightening, each weapon's
Gunnery and a Guard firing each gun, staggered bursts,
flanking, cover it cannot reach, facing a body in its way, holding fire when
its muzzle line is blocked, walking round props and round a body in its way,
two crew head-on in a two-wide doorway (both arrive within 12 s), one
standing in a one-wide gap with a way round (passed within 15 s), a Worker
working in a dead-end lane making way for one walking out (out within 11 s,
the Worker back at its spot), two Workers sharing one work spot,
bodies and other traces, routes into the pod, the Alarm and its panels, Headshots, and 60 simulated seconds of routines
on a generated medium ship ending in the Alarm), plus the crew fight and
each Guard's rolled gun in `tests/test_ship_3d.gd`, the gun roll's caps and
shares in `tests/test_generator.gd`, and whole Raids in
`tests/test_raid_smoke.gd`.

## Crew types

Every crew member is a **Guard** or a **Worker**, set by `ShipBuilder3D` from
its Post Room's Role (`CrewTypes.for_role`):

| Post Room | Type |
|---|---|
| Armory, Bridge, Corridor (and anything unlisted) | Guard |
| Engine, Cargo, Shield, Medbay | Worker |
| Quarters | alternating: the 1st, 3rd... crew posted there are Guards, the 2nd, 4th... Workers |

- **Guards** walk patrol loops (see Routines) and, once spotted, hunt and fight
  as described under States.
- **Workers** walk work loops. Spotted, a Worker does not hunt. One time in
  four it **cowers** behind cover where it is; otherwise it **flees**: to the
  nearest working Alarm Panel while the Alarm is down (raising it on arrival,
  see Alarm), else to the nearest living Guard, else it cowers. Reaching within
  2.5 m of a Guard it **raises** it (the Guard gets the Pirate's last-seen
  position, goes to Awareness 1 and hunts) and then cowers. If its Guard dies
  on the way it runs on to the next, without a second roll to hide. A cowering Worker returns to its
  routine after 15 s with nothing in sight, at Awareness 0.15.
- A Worker is **unarmed**: no weapon and no Gunnery (`weapon` and
  `gunnery` are null from spawn). **Cornered** (the Pirate in sight within
  3 m), it cowers where it is (COWER) instead of running, and stays
  cowering while he is in sight; shot while fleeing and cornered, the same.
  A Worker that loses him hides (COWER) where a Guard would search. (The
  Workers ticket of the crew-combat spec replaces cowering with running and
  hiding.)
- Guards wear the dark Quaternius Soldier; Workers wear the Engineer, the
  Soldier's body and skeleton re-dressed in Blender in orange coveralls with
  reflective bands, an open helmet, a tool belt and air tanks
  (`assets/models/crew/build_engineer.py`). One skeleton, so both play every
  crew clip, and they read apart at a glance.

## States

```
PATROL ──suspicious──▶ INVESTIGATE ──spotted──▶ HUNT ◀──────────┐
  │  ▲                    │                       │              │
  │  └──Awareness faded───┘                 in range + seen      │
  └──────────spotted──────────────────────────▶ FIGHT ──burst spent──▶ COVER
                                                  │                    │
                                     3 s out of sight            reloaded
                                                  ▼                    │
                                               SEARCH ◀────────────────┘ (3 s out of sight)
                                                  │
                                       nothing found ▶ PATROL
```

That is a Guard. A Worker swaps HUNT for FLEE and SEARCH for COWER:

```
PATROL / INVESTIGATE ──spotted──▶ FLEE ──reached its Guard──▶ COWER ──15 s calm──▶ PATROL
        │                          │                             ▲
        └──spotted, cornered (≤3 m)┴──────cornered (≤3 m)────────┘
```

- **PATROL**: on routine (see Routines below): walking its loop of Jobs at
  half speed, working at props, now and then stopping to chat. A crew member
  with no layout to plan from (a test rig) wanders random floor points in its
  own Room instead. While stood still and not working at a prop it glances
  around: every 1.5–4 s it turns up to 70° either way, so the sight cone is
  never a fixed wedge.
- **INVESTIGATE** (new in #53): entered when Awareness is suspicious but not
  spotted, whether from a glimpse or a noise. Walks at 45 % speed toward where the Pirate was last noticed, faces
  it, re-paths while it still has him in view, and lingers 2 s at the spot.
  Goes back to PATROL once Awareness has drained below suspicious and either it
  has arrived and the linger is over, or 10 s have passed with nothing in view
  (the spot may be inside a prop). Back on PATROL it picks up the Job it was on.
- **HUNT / FIGHT / COVER / SEARCH**: the combat loop. HUNT paths to the
  last-seen position (or flanks, see Guard combat); FIGHT fires bursts inside
  10.6 m (`ENGAGE_RANGE`, the same for every gun) after a 0.05–0.35 s beat; a spent burst goes to
  COVER to pause and hold; 3 s out of sight sends any of them to SEARCH,
  which walks to the last-seen spot and waits 2.5 s. See Guns below for the
  numbers; cover hold is 1.2 s before jitter.
- **A clear shot**: FIGHT fires only while its muzzle line is clear as well
  as its eye line. The muzzle line is a ball 0.1 m across (a bolt's overlap
  sphere is 0.09 m) swept from the body's axis at muzzle height (1.3 m) to
  0.4 m short of the Pirate's torso, plus the two edges of its current
  spread for the first 1.5 m, so a crate he crouches behind, or a prop at
  its own shoulder that the barrel pokes past, stops it firing. It then holds
  fire and steps out: to the nearest tile at least 1 m away, in range, whose
  muzzle line is clear, walking all the way there before it fires again;
  with no such tile it closes on him.
- **Cover it cannot reach**: a crew member that has run for its cover point
  for 3 s without getting there (the way blocked by the Pirate, another body
  or a prop) holds where it is instead, and leaves COVER as soon as its hold
  and pause are done, at most 3 s after ducking.
- **DEAD**: collision off, death clip or tip-over.

### Guns: one of four weapons and its Gunnery

Each **Guard** carries one of the Pirate's four weapons (`Crew3D.weapon`),
the bare live Resource under `resources/weapons/`, so a Sandbox sheet edit
reaches crew shots too. A **Worker** carries nothing. From its gun a crew
shot takes its damage, projectile speed and lifetime, every pellet (a
Shotgun shot throws all 12, each inside the cone on its own), the time
between shots in a burst, its shot sound, its action sound (the Shotgun's
pump) and its loudness. Crew ignore its magazine, reloads, bloom, Aim Down
Sights, recoil and Viewmodel: they fire a burst and pause, and never count
rounds. How a Guard handles its gun is that gun's **Gunnery**
(`Crew3D.gunnery`, `resources/gunnery/<weapon>.tres`, `Gunnery.for_weapon`):

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| aim error, degrees, added to the gun's base cone | 7.5 | 6 | 8 | 0 |
| opening spread, closing time | 3x, 2 s | 3x, 2 s | 3x, 2 s | 3x, 2 s |
| shots per burst | 2 to 3 | 3 to 5 | 1 | 1 |
| bursts per peek, gap between | 1 | 2, 0.4 to 0.8 s | 1 | 1 |
| time down, s | 1.0 to 2.0 | 1.5 to 2.5 | 1.2 to 1.5 | 2.5 to 4.0 |
| settle, s | 0.35 | 0.35 | 0.35 | 0.9 |
| lead | 0.3 | 0.5 | 0 | 1.0 |
| range band, m | 4 to 8 | 5 to 10 | 2 to 5 | 8 to 14 |
| hold before shifting, s | 4 | 8 | 4 | never moves up (-1) |
| reload factor | 1.5 | 1.5 | 1.5 | 1.5 |

Read today: the aim error (the cone, see Guard combat), shots per burst (a
fresh draw for every burst) and time down (a fresh draw after every spent
burst, the time it keeps down in COVER before the next). The rest are filled
in for the cover, fair fire, reload and habit tickets of
`.scratch/crew-combat/spec.md`. All are read at the moment of use, so a
Sandbox sheet edit reaches crew already in the Raid.

**The gun roll** (`GunRoll.roll`, called by `ShipBuilder3D.build`): each
Guard rolls one weapon by weight. Base weights by Ship Class, slid from the
poor row to the rich row by Richness:

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| Small, poor | 60 | 25 | 15 | 0 |
| Small, rich | 40 | 35 | 25 | 0 |
| Medium, poor | 35 | 35 | 25 | 5 |
| Medium, rich | 20 | 45 | 25 | 10 |
| Large, poor | 20 | 45 | 25 | 10 |
| Large, rich | 10 | 50 | 25 | 15 |

times the Post Room's multipliers (Corridor x1 / x1.5 / x0.5 / x2, Armory
x0.5 / x1.5 / x2 / x0.5, Bridge x1.5 / x1.5 / x1 / x1, Quarters x2 / x1 /
x1 / x0.5; any other Room x1), renormalised. Caps: no Marksman Rifle on a
small ship, at most 1 on a medium and 2 on a large, never two in one Room;
a Room of three or more Guards is never all Shotguns. A roll that breaks a
cap is rolled again among the remaining weapons with the same weights.
Rolls run Rooms by index and Guards by spawn order, from a random stream of
their own seeded off the layout's seed (`hash([gen_seed, "gun roll"])`), so
the same layout always gives the same guns (a Retry too) whatever else the
build draws. The gun is not stored in the layout. The hand-authored ship
(no Ship Class) rolls with the small ship's weights. Workers roll nothing.

The body turns toward where it is looking at 6 rad/s rather than snapping;
shots leave along the aim direction regardless of where the body has got to.
Out of combat a walking crew member looks the way it moves; one trying to
walk but held still (a body in its way) looks the way it is trying to go,
so a Pirate blocking its path is in its cone (spotted within 1 s from
pressed against him, facing 90° off).

## Getting about

Between Rooms crew follow the door graph (`ShipNavigator`): doorway centres
and seam crossings. Inside a Room a straight line between two of those can
run through a prop (by design: props break up Lanes), so `CrewPaths` bends
each leg a prop would block round it:

- The **walking grid** is one cell per tile: every Room's floor and every
  unlocked doorway, minus every prop's footprint (`Interiors.footprint`). It
  is made from the layout once, the first time any crew member routes, and
  kept on the layout; nothing is read back from the built scene.
- A leg is walked **straight** when a square 0.9 m across (the 0.7 m capsule
  and a margin) swept along it touches only open tiles; otherwise it is
  replaced by an A* route over the grid, string-pulled to the furthest tile
  centre still in a clear straight line. A destination inside a prop ends on
  the nearest open tile; a seam crossing boxed in by props is skipped. A way
  round that would pass through a Room other than the leg's own is not
  taken (the leg stays straight), so a flank still avoids the Pirate's Room.
  An end in a doorway stands for the two Rooms its Door joins, and the leg's
  own Room is the one both ends share: so a leg from one doorway to the next
  across a Room (two Doors in the same wall row, where the straight line
  runs inside the wall) is bent through that Room.
- A crew member **stood in a doorway** (in no Room) that re-paths steps
  first onto whichever Room tile beside it gives the shorter door-graph
  route, rather than walking straight at its destination through the hull.
- **Getting loose**: a crew member trying to walk that moves less than
  0.3 m in 1 s re-routes from where it stands. Stuck again, something no
  route knows of is in its way:
  - **another crew member** (living, ahead, centres within 1 m): it gets
    past (`_get_past`). If that one is standing still (working, waiting,
    chatting, or itself giving way) it goes round it over open floor, the
    tiles within 0.75 m of every crew body near shut (`CrewPaths.route_around`);
    with no way round it asks it to **make way** (`make_way_for`): a crew
    member on routine working at a prop or waiting steps off the walker's way
    as below and waits; one that was working then walks back to its spot
    and works the Job again from the start. If both are
    walking, **only one of the pair acts**: the one that can (has a way
    round, or an open tile within 5 steps whose centre is 1 m or more off
    the other's way, reached without passing through a body:
    `CrewPaths.make_way`), and of two that both can, the one created first
    (lower instance id). It goes round if it can; else it **gives way**:
    steps to that tile and waits there until the other has walked 2 m on,
    stopped, or 5 s are up, then routes on. One that is being given way to
    never acts itself. Still stuck after 8 tries, either acts whenever it
    can (in case the two ever judged it from different positions).
  - **anything else** (the Pirate): it steps 1 m aside (alternating sides,
    and only onto open tiles) and walks on, with its periodic re-path held
    off for 1 s.

  A Job it still cannot reach is given up at 30 s as before.
- **Why it cannot deadlock**: two crew mirroring each other forever needs
  both to act, or neither. Of a walking pair blocked by each other, the
  rule above picks exactly one whenever either can act, by an order that
  never changes (instance ids are fixed), so the other holds still; the
  actor then leaves the other's way entirely (1 m off it) or goes round.
  Neither can act only when neither has a way round nor any open tile off
  the other's way within 5 steps (a corridor closed at both ends); then
  the Job's 30 s give-up still applies. A crew member standing in the way
  with no way round it makes way if it is working or waiting (a Worker can
  work the same spot Job after Job, so its timer alone is no promise);
  chats and give-ways end on a timer; and a Guard sweeping under the Alarm
  (where a hiding Worker never moves) gives up a Room it has not reached in
  30 s.

## Awareness

Each crew member holds an Awareness of the Pirate from 0 to 1, in three bands:

| Band | Awareness | Behaviour |
|---|---|---|
| Unaware | below 0.3 | routine (PATROL) |
| Suspicious | 0.3 to just under 1 | INVESTIGATE |
| Spotted | 1 | combat (HUNT and on) |

**Sight** is a 110° forward cone (55° each side of the way the body faces),
out to 14.4 m, with a clear line from eye height (1.5 m) to eye height on the
world layer (hull, props, shut doors). Outside the cone, sight adds nothing.

**Filling**: while the Pirate is in view, Awareness rises by
`delta / spot_time(distance)` each tick. Time from unaware to spotted, standing
in the open, square in view:

| Distance | Seconds |
|---|---|
| 3 m or closer | 0.3 |
| 10 m | 1.5 |
| 14 m or further | 3.0 |

Linear between those points. A crouched or sliding Pirate (`is_crouched()`)
takes **2×** as long. The rate follows the current distance, so closing in
mid-fill speeds it up. The weapon he holds multiplies the rate by its
`conspicuous` (1.0 on every bare gun; a Laser's x1.3 makes every time above
1.3× shorter).

**Draining**: out of view, Awareness falls by 0.2 a second (spotted to zero in
5 s).

**Overrides**:
- While in combat (HUNT, FIGHT, COVER) Awareness is pinned at 1 and the cone
  is ignored: a crew member already fighting tracks him all round as before.
- Giving up a chase (entering SEARCH) caps Awareness at 0.7, so it is still
  suspicious and re-spots him faster than a fresh crew member would.
- Being shot sets Awareness to 1 at once and points the crew member at the
  shooter's position, from any direction.

**Hearing** (see below) lifts Awareness to suspicious but never to spotted.

**Tipping into spotted** (reaching 1 from below, by sight or by being shot)
calls `on_crew_spotted(crew)` on every node in the `awareness_listeners` group.

## Traces

Things the Pirate leaves behind that crew can find (`CrewTraces.is_trace`):

| Trace | When | Severity |
|---|---|---|
| Body | a dead crew member, where it fell | serious |
| Boarding Hatch | the Hatch his pod is docked at, standing open | serious |
| Emptied Container | a Container he searched | minor |
| Door left open | a Door standing open that was opened by anyone but crew | minor |

A Door crew opened is never a trace (routine traffic), and shutting a Door
clears it. Sealed Hatches never open, so are never traces.

- Four times a second, a crew member not in combat looks for an unreported
  trace: within 14.4 m, in its sight cone, with a clear line from its eyes to
  0.4 m up the trace (the trace's own collision ignored). The nearest one it
  sees becomes its trace to look at.
- Seeing one lifts Awareness to at least 0.5 (suspicious, never spotted) and
  sends it to INVESTIGATE at the trace. It stays suspicious until it gets
  there, giving up after 20 s (and never going back to one it gave up on),
  or dropping it as soon as another crew member reports it.
- Within 1.6 m it **reports** the trace, once: the trace is marked and no
  crew member reacts to it again. The finder goes On Edge and takes the
  trace's position as the last place the Pirate was. Then:
  - **serious**: a **Worker** flees as if it had spotted him, without the
    chance to hide: to an Alarm Panel while the Alarm is down, else to a Guard.
    A **Guard** hunts from there and shares the position with nearby Guards;
    for the boarding Hatch, the place it hunts is inside the Pirate's
    Boarding Pod.
  - **minor**: a Door left open is shut. A **Guard** searches about the spot
    (SEARCH) and goes back to its routine; a **Worker** goes straight back to
    its routine. Either way it is now On Edge.

**The pod is not a safe zone.** The Boarding Pod is in no Room, so the door
graph cannot reach it; a crew route into the pod runs to the boarding Hatch's
inner floor tile, through the Hatch and in, and a route out runs the other way.
Any crew member hunting the Pirate while he waits out an Extraction follows
him in.

## Guard combat

- **Sharing**: a Guard that spots the Pirate, and once a second while it keeps
  him in sight, tells every living Guard in its own Room and the Rooms a Door
  joins to it (open or shut: radios) where he is (`CrewCombat.share`). A Guard
  told it while on routine, investigating or searching goes to Awareness 1 and
  hunts there; one already hunting takes the fresher position; one fighting
  ignores it.
- **Aim**: spread is `base × 1.5` on first sight, closing linearly to
  `base × 0.5` after 3 s of continuous sight, and back to 1.5× the moment the
  Pirate breaks line of sight. A Guard's first shots mostly warn; staying
  exposed is what gets him hit. Base is its gun's base cone plus its
  Gunnery's aim error. (The fair fire ticket replaces this curve with the
  Gunnery's opening spread and closing time.)
- **Rhythm**: each Guard draws its own multipliers (0.75–1.35×) at spawn on
  its gun's time between shots and its cover hold; each burst's length is a
  fresh draw from its Gunnery's shots per burst, and the time down after it
  a fresh draw from its time down. No crew member starts a burst within 18
  physics frames (0.3 s) of another's; it waits.
- **Pin and flank**: a Guard entering HUNT while another Guard is already
  fighting (FIGHT or COVER), and no Guard is already flanking, tries to go
  round: the Door into the Pirate's Room furthest from the pinning Guard, if
  that is not the Door its own straight route would use anyway, reached by a
  route that avoids the Pirate's Room, then through the Door and one metre in.
  It fights as soon as it has him in range and sight, and drops the flank on
  arrival or after 20 s.

## Alarm

**Alarm Panels** (`AlarmPanel.spots`): one in every Bridge and every Armory, on
the wall beside the floor tile nearest the Room's centre that has wall straight
behind it, is not a prop's tile, and is not beside a doorway or Hatch gap. The
panel's screen glows orange; a crew member works it from the tile in front.

**Raising**: a fleeing Worker that gets within 0.9 m of a working panel raises
the **Alarm** (`ShipAlarm.raise`) with the Pirate's last-seen position, then
cowers. Once raised it stays up for the rest of the Raid:
- every Room light turns red and pulses (55 %–100 %, ~0.5 Hz); working panels
  turn red; the HUD shows **ALARM RAISED**;
- every crew member is told (`on_alarm`) and goes **On Edge**;
- **routines stop**: Workers on routine, investigating or searching hide
  (COWER) and never come out; Guards on routine, investigating or searching
  hunt the last-seen position, and once that goes cold they **sweep** the ship
  at full speed, Room to random Room, pausing 1.5 s in each, instead of their
  patrol loop, giving up on a Room it has not reached in 30 s. Crew already
  fighting or fleeing carry on.

**Breaking a panel**: the Pirate's shot breaks a panel (screen goes dark); crew
shots do not. A broken panel raises nothing: a Worker running to it when it
breaks re-picks the nearest working panel, then a Guard. Breaking one is a
gunshot like any other, heard as far as the weapon's loudness (24 m).

**On Edge**: a crew member that has lost the Pirate (entered SEARCH), crept
back from hiding, or heard the Alarm is On Edge for the rest of the Raid: every
spot time is **0.6×**, and a patrolling Guard pauses half as long at each stop.

## Routines

Every crew member has a **Post**, the Room it spawned in (the Threat Budget
still decides how many start in each Room), and a loop of 3–5 **Jobs**
(`CrewRoutine.plan`). The whole ship starts mid-routine: each crew member
begins at a random point in its loop, after a random 0–5 s pause.

- **Work Jobs**: stand on the floor tile beside a prop and face it for 3–8 s.
  Work props are consoles, engine consoles, generators, lockers, containers,
  safes, cabinets, footlockers and cryopods, plus crates in Cargo; a Breaker
  never. The loop's first Job is at the Post and its second elsewhere, so
  every loop both comes home and leaves; the rest are elsewhere half the time.
- **Patrol loops**: Guards patrol instead of working. Each stop is a Room's
  centre (Corridors included), never the same Room twice running, with a
  1.5–3.5 s pause looking about; a centre blocked by a prop moves to any free
  spot in that Room.
- Crew walk routine at **50 %** speed (Walk clip below 2.4 m/s, Run above).
- A work Job whose spot turns out blocked is skipped; one not reached within 30 s
  is given up for the next.
- **One crew member per work spot**: a prop has one spot, and a work Job
  whose spot another crew member is walking to or working at is skipped
  for the next, so nobody works pressed against someone already there (and
  nudged off the spot, facing past the prop). With every spot in its loop
  held it waits 1–3 s where it is and tries again.
- **Chat**: two routine crew walking within 1.6 m of each other have a 30 %
  chance to stop face to face for 3–5 s; either way neither chats again for
  40 s.
- **Doors**: crew open shut Doors within 1.75 m of their path. On routine they
  shut the ones they opened (or walked through open, within 1 m) once 2 m past,
  unless someone is still in the doorway, trying each tick until 6 m away.
  So the last crew member through a doorway closes it.
- Suspicion or combat interrupts the routine; returning to PATROL resumes the
  current Job.

## Hearing

`CrewNoise.make(tree, at, kind, reach, source)` rings a noise for every living
crew member that can hear it. A noise reaches a crew member when both:

- it is within the noise's **reach** (flat distance), and
- it **carries**: the listener is in the same Room as the noise (a point in a
  doorway counts as both Rooms the Door joins), or in a Room joined to the
  noise's Room by a **Door standing open**. Hull and shut Doors stop it, and a
  noise one Room further on is not heard. A point in a Hatch gap or outside the
  ship is in no Room, so noise there carries to nobody.

| Noise | Kind | Reach | Who makes it |
|---|---|---|---|
| Sprinting step | STEP | 9 m | the Pirate, once per stride (the step he hears in `PirateAudio`) |
| Walking step | STEP | 3 m | the Pirate |
| Crouched or sliding step | — | silent | the Pirate |
| Gunshot | GUNSHOT | the weapon's `loudness` (24 m; the Shotgun's 32 m) | the Pirate and Guards, every shot |
| Door opening or closing | DOOR | 6 m | whoever works it |

A crew member that hears a noise (`Crew3D.hear`):
- ignores it while dead or already in combat;
- ignores other crew members' footsteps and doors (routine traffic), but not
  their gunshots, which draw it to look;
- lifts Awareness to at least **0.45** (step, door) or **0.6** (gunshot), never past
  **0.95** and never lowering it: suspicious, never spotted;
- takes the noise position as the place to look; already investigating, it
  re-paths there and its linger restarts.

## What the Pirate sees

`AwarenessMarkers` draws a bar 8 × 26 px over each living crew member's head
(2.35 m up) whose Awareness is above zero, filled from the bottom by its
Awareness: **white** while unaware, **yellow** once suspicious, **red** when
spotted. It marks crew on screen within 22 m, and crew within 6 m even behind
the camera (pinned to the bottom edge, mirrored), so something closing in at
his back still reads.

It rings the **spotted sting** once per tip into red. The sting is a
placeholder (`kenney_impact/impactMetal_light_001.ogg`) until one is picked by
ear in the sound booth.

## Tuning

All numbers above are constants in `crew_perception.gd` (`CONE_HALF_DEGREES`,
`SIGHT_RANGE`, `SUSPICIOUS`, `DECAY_PER_SECOND`, `SPOT_TIMES`, `CROUCH_FACTOR`)
and `crew.gd` (`SEARCH_AWARENESS`, `INVESTIGATE_SPEED`, `INVESTIGATE_LINGER`,
`GLANCE_DEGREES`, `TURN_RATE`, `INVESTIGATE_GIVE_UP`, `ROUTINE_SPEED`,
`WALK_ANIM_SPEED`, `DOOR_CLOSE_AFTER`, `DOOR_FORGET`, `DOOR_ADOPT`, `CHAT_*`,
`JOB_GIVE_UP`, `CORNERED_RANGE`, `ENGAGE_RANGE`, `HIDE_CHANCE`,
`GUARD_REACH`, `COWER_CALM`, `PANEL_REACH`,
`ON_EDGE_PAUSE`, `SWEEP_PAUSE`, `COVER_GIVE_UP`, `MUZZLE_BALL`,
`MUZZLE_TARGET_GAP`, `MUZZLE_NEAR`, `FIRING_STEP`, `UNSTICK_AFTER`,
`UNSTICK_MOVE`, `SIDESTEP`, `GIVE_WAY_NEAR`, `GIVE_WAY_PASSED`,
`GIVE_WAY_WAIT`, `GIVE_WAY_INSIST`), `crew_paths.gd` (`CLEARANCE`, `SAMPLE`,
`SNAP`, `BODY_GAP`, `MAKE_WAY_REACH`, `MAKE_WAY_CLEAR`), `crew_perception.gd` (`ON_EDGE_FACTOR`),
`crew_combat.gd` (`OPEN_SPREAD`, `TIGHT_SPREAD`, `TIGHTEN_TIME`,
`BURST_STAGGER_FRAMES`, `SHARE_EVERY`, `FLANK_GIVE_UP`, `JITTER`),
`crew_traces.gd` (`LOOK_EVERY`, `REACH`, `AWARENESS`, `AIM_HEIGHT`),
`ship_alarm.gd` (`RED`, `PULSE_*`), `alarm_panel.gd` (`ROLES`, `SIZE`, `HEIGHT`),
`crew_types.gd` (`GUARD_ROLES`, `WORKER_ROLES`), `HEARD_NOISE`, `HEARD_GUNSHOT`, `HEARD_CAP`) and
`crew_routine.gd` (`WORK_PROPS`, `JOBS_MIN`/`MAX`, `WORK_TIME`,
`PATROL_PAUSE`, `AWAY_CHANCE`) and `crew_noise.gd` (`SPRINT_STEP`, `WALK_STEP`, `DOOR`). They are starting values to be tuned by
playtest. Gun numbers are not here: they are each weapon's Profile and its
Gunnery, edited in the Sandbox sheet (`docs/sandbox.md`); the gun roll's
weights, multipliers and caps are constants in `scripts/ship/gun_roll.gd`
(`BASE`, `ROOM`, `MARKSMAN_CAP`, `ALL_SHOTGUN_ROOM`).

## Stealth XP

The crew's Awareness feeds the Pirate's XP (`RaidLedger`):
- A crew member records, as it falls, whether it **died unaware**: not in
  combat (HUNT, FIGHT, COVER, FLEE, COWER) and not spotted. A kill on one is
  worth **150 XP** against 100, and its toast reads "+150 XP unaware". A shot
  that only wounds spots the Pirate, so the kill that follows is a normal one.
- A kill counts through the Pirate's hit report, which waits a step and a
  half after a shot's first strike (`SHOT_REPORT_DELAY`) so a Shotgun's late
  pellets join it. Every way a Raid settles reports the waiting hits first
  (`report_hits_now` in `scripts/player_3d.gd`): going down, the pod casting off, walking away
  to the menu. A crew member felled in the step the pod casts off in is still
  his kill.
- **Ghost**: extracting with the Alarm never raised this Raid adds 150 / 250 /
  350 XP for a small / medium / large ship. The EXTRACTED tally shows unaware
  kills and the Ghost bonus when earned. Avoiding kills earns nothing extra.

## Not yet built

The Officer (#63, deferred) and each type's own model (#62, picked by the
player in the model booth).
