# Crew AI

How the hostile crew aboard a raid target think. This file is the design
record for everything under `scripts/crew/`; every change to crew behaviour
updates it in the same commit. Terms are `CONTEXT.md`'s. The plan this is
being built toward is spec #52 (tickets #53–#63).

## Files

| File | What it owns |
|---|---|
| `crew.gd` (`Crew3D`) | The body: movement, health, animation, door handling, gunnery, cover search, and the state machine that ties them together. |
| `crew_perception.gd` (`CrewPerception`) | Awareness: the sight cone, how fast Awareness fills and drains, and its bands. Pure arithmetic, tested without physics. |
| `crew_types.gd` (`CrewTypes`) | Guard or Worker, from the Post Room's Role, and the Worker tint. |
| `crew_routine.gd` (`CrewRoutine`) | Routines: a crew member's Post and its loop of Jobs, planned from the layout's props and Rooms. Pure planning; the body walks it. |
| `crew_traces.gd` (`CrewTraces`) | What the Pirate leaves behind that crew find: bodies. |
| `crew_combat.gd` (`CrewCombat`) | Guard teamwork: sharing the Pirate's position, aim that tightens, staggered bursts, flank routes. |
| `ship_alarm.gd` (`ShipAlarm`) | The ship-wide Alarm: raised once, red lights, every crew member told. Built per ship as `Ship/Alarm`. |
| `alarm_panel.gd` (`AlarmPanel`) | The wall panels the Alarm is raised from, where they go, and breaking them. Built under `Ship/AlarmPanels`. |
| `crew_noise.gd` (`CrewNoise`) | Hearing: noise events (footsteps, gunshots, doors), how far each reaches, and which Rooms it carries into. |
| `../ui/awareness_markers.gd` (`AwarenessMarkers`) | The bar over each crew member's head and the spotted sting, drawn by the HUD. |

Scene: `scenes/crew_3d.tscn`. Tests: `tests/test_crew.gd` (Awareness, the walk
to look, being shot, the sting, hearing, Workers fleeing and cornered, crew
types, On Edge, Guards sharing his position, aim tightening, staggered bursts,
flanking, bodies, the Alarm and its panels, and 60 simulated seconds of routines
on a generated medium ship ending in the Alarm), plus the crew fight in
`tests/test_ship_3d.gd`.

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
- A Worker fights only when **cornered**: the Pirate in sight within 3 m.
  Then it fires a sidearm (12° spread, 2-round bursts, against a Guard's 7°
  and 3) and goes back to fleeing once he is more than 5 m off. A Worker that
  loses him hides (COWER) where a Guard would search.
- Until each type's model is picked in the booth (#62), Workers wear the light
  gunner rig tinted orange (`CrewTypes.WORKER_TINT`, multiplied into copies of
  the rig's materials) and Guards the dark soldier rig, so they read apart at
  a glance.

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
                                   │  ▲                         │
                         cornered (≤3 m)  └── he is > 5 m off ── FIGHT ◀── cornered
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
  10.6 m after a 0.05–0.35 s beat; a spent burst goes to COVER to reload and
  hold; 3 s out of sight sends any of them to SEARCH, which walks to the
  last-seen spot and waits 2.5 s. Base numbers, before each Guard's jitter:
  3-round bursts 0.14 s apart, 7° spread, 1.1 s reload, 1.2 s cover hold.
- **DEAD**: collision off, death clip or tip-over.

The body turns toward where it is looking at 6 rad/s rather than snapping;
shots leave along the aim direction regardless of where the body has got to.

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
mid-fill speeds it up.

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

Things the Pirate leaves behind that crew can find (`CrewTraces`). So far:
**bodies**. A dead crew member stays where it fell.

- Four times a second, a crew member not in combat looks for an unreported
  trace: within 14.4 m, in its sight cone, with a clear line from its eyes to
  0.4 m up the trace. The nearest one it sees becomes its trace to look at.
- Seeing one lifts Awareness to at least 0.5 (suspicious, never spotted) and
  sends it to INVESTIGATE at the trace. It stays suspicious until it gets
  there, giving up after 20 s (and never going back to one it gave up on),
  or dropping it as soon as another crew member reports it.
- Within 1.6 m it **reports** the trace, once: the trace is marked and no
  crew member reacts to it again. The finder goes On Edge, takes the trace's
  position as the last place the Pirate was, and:
  - a **Worker** flees as if it had spotted him, without the chance to hide:
    to an Alarm Panel while the Alarm is down, else to a Guard;
  - a **Guard** hunts from there and shares the position with nearby Guards.

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
  exposed is what gets him hit. Workers' sidearms follow the same curve from
  their wider base.
- **Rhythm**: each crew member draws its own multipliers (0.75–1.35×) on burst
  gap, reload and cover hold, and each Guard's burst is 2–4 rounds. No crew
  member starts a burst within 18 physics frames (0.3 s) of another's; it waits.
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
  patrol loop. Crew already fighting or fleeing carry on.

**Breaking a panel**: the Pirate's shot breaks a panel (screen goes dark); crew
shots do not. A broken panel raises nothing: a Worker running to it when it
breaks re-picks the nearest working panel, then a Guard. Breaking one is a
gunshot like any other, heard 24 m off.

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
| Gunshot | GUNSHOT | 24 m | the Pirate and crew, every shot |
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
`JOB_GIVE_UP`, `CORNERED_RANGE`, `CORNER_RELEASE`, `HIDE_CHANCE`,
`GUARD_REACH`, `COWER_CALM`, `WORKER_SPREAD`, `WORKER_BURST`, `PANEL_REACH`,
`ON_EDGE_PAUSE`, `SWEEP_PAUSE`), `crew_perception.gd` (`ON_EDGE_FACTOR`),
`crew_combat.gd` (`OPEN_SPREAD`, `TIGHT_SPREAD`, `TIGHTEN_TIME`,
`BURST_STAGGER_FRAMES`, `SHARE_EVERY`, `FLANK_GIVE_UP`, `JITTER`),
`crew_traces.gd` (`LOOK_EVERY`, `REACH`, `AWARENESS`, `BODY_HEIGHT`),
`ship_alarm.gd` (`RED`, `PULSE_*`), `alarm_panel.gd` (`ROLES`, `SIZE`, `HEIGHT`),
`crew_types.gd` (`GUARD_ROLES`, `WORKER_ROLES`, `WORKER_TINT`), `HEARD_NOISE`, `HEARD_GUNSHOT`, `HEARD_CAP`) and
`crew_routine.gd` (`WORK_PROPS`, `JOBS_MIN`/`MAX`, `WORK_TIME`,
`PATROL_PAUSE`, `AWAY_CHANCE`) and `crew_noise.gd` (`SPRINT_STEP`, `WALK_STEP`, `GUNSHOT`, `DOOR`). They are starting values to be tuned by
playtest.

## Not yet built

Other traces (#60) and
stealth XP (#61).
