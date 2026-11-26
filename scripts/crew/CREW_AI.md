# Crew AI

How the hostile crew aboard a raid target think. This file is the design
record for everything under `scripts/crew/`; every change to crew behaviour
updates it in the same commit. Terms are `CONTEXT.md`'s. The plan this is
being built toward is `.scratch/crew-combat/spec.md`, after spec #52
(tickets #53–#63).

## Files

| File | What it owns |
|---|---|
| `crew.gd` (`Crew3D`) | The body: movement, health, animation, door handling, gunnery, and the state machine that ties them together. |
| `crew_hiding.gd` (`CrewHiding`) | One Worker's hiding: the 1 s freeze, the hide roll (from the ship's seed), picking a hiding place (a corner out of sight of the Room's doorways, far from him and the Guards' cover), the fair run there, staying put, giving its tile up to a Guard, and when it comes out. Every Worker holds one (`Crew3D.hiding`); it drives the Worker's COWER state. Null for a Guard. |
| `head_zone.gd` (`HeadZone`) | The head: a 0.16 m ball on physics layer 4, riding the rig's `Head` bone through a `BoneAttachment3D`, so a bolt that strikes it is a Headshot. The capsule stays the body. |
| `crew_perception.gd` (`CrewPerception`) | Awareness: the sight cone, how fast Awareness fills and drains, and its bands. Pure arithmetic, tested without physics. |
| `crew_types.gd` (`CrewTypes`) | Guard or Worker, from the Post Room's Role. |
| `gunnery.gd` (`Gunnery`) | How a Guard handles one weapon: aim error, opening spread and closing time, shots per burst, bursts per peek, gap between bursts, time down, settle, lead, range band, hold before shifting, reload factor. One `.tres` per weapon under `resources/gunnery/`, named as the weapon's file, edited in the Sandbox sheet. |
| `../ship/gun_roll.gd` (`GunRoll`) | Which weapon each Guard carries, rolled when `ShipBuilder3D` builds the ship (see Guns below). |
| `crew_routine.gd` (`CrewRoutine`) | Routines: a crew member's Post and its loop of Jobs, planned from the layout's props and Rooms. Pure planning; the body walks it. |
| `crew_traces.gd` (`CrewTraces`) | What the Pirate leaves behind that crew find: bodies, the open boarding Hatch, emptied Containers, Doors left open. |
| `crew_combat.gd` (`CrewCombat`) | Guard teamwork: sharing the Pirate's position, staggered bursts, flank routes and the Door a flank goes in by. |
| `crew_team.gd` (`CrewTeam`) | Guards together against one Pirate: which Guard flanks (by gun), and firing on the prop he broke sight behind (suppression). One per Pirate, settled once a physics frame like `CrewFire`. |
| `crew_fire.gd` (`CrewFire`) | Fair fire: who aims true (at most two at once, handed on by a timer), and where every shot is aimed before its spread: at him, led and walking in, or at a miss point beside him. One per Pirate, shared by every Guard fighting him. |
| `crew_cover.gd` (`CrewCover`) | One Guard's fight from cover: finding and claiming a spot, the fair walk there, holding it, peeking in its gun's rhythm, leaving it, and fighting with no cover in reach; its gun's habit: the Shotgun's ambush and rack, the Marksman Rifle's perch, sight line and hip fire; and its part in the team: covering fire, one mover at a time, the flank's last leg, firing on his cover, the last Guard. Every Guard holds one (`Crew3D.cover`); it drives the Guard's FIGHT and COVER states. |
| `crew_magazine.gd` (`CrewMagazine`) | A Guard's magazine: rounds counted against its weapon's magazine size, and its reloads (empty, topping up, the Shotgun's shell by shell and its break-off), with their times and sounds. Every Guard holds one (`Crew3D.magazine`); `CrewCover` decides where and when a reload starts. |
| `crew_habit.gd` (`CrewHabit`) | A habit per gun: which of the four guns a Guard carries (`gun_of`, by its weapon's file) and the habit numbers (the Shotgun's 4 m and 8 m, its ambush reach and rack timing; the Marksman Rifle's perch radius, line length and weight, 5 m, sight lock and hip fire). |
| `crew_sight_line.gd` (`CrewSightLine`) | The Marksman Rifle's sight line: a thin red unshaded line from the rifle's muzzle to where it aims, made on first use under the Guard. |
| `crew_gun.gd` (`CrewGun`) | A Guard's gun in its hands: its Weapon Profile's model, 1.15x, under the body's Model node from spawn; carried, down behind cover, reloading or aimed; the arms solved onto it, the wrists squared and the fingers closed round its grip and fore-end, and the left hand's way through a reload; where its `Muzzle` stands when aimed, for the shot and the clear-shot test. A skeleton modifier on the rig's skeleton (`Crew3D.gun`); null for a Worker. |
| `crew_pose.gd` (`CrewPose`) | A Guard's body in a fight: down behind cover squatting or on one knee, ducking a near miss, running low to low cover, and stepping out from full cover on feet that step. A skeleton modifier run before the gun's (`Crew3D.pose`); null for a Worker. Its stance is chosen by `CrewCover` (`stance`), which also sets the capsule. |
| `crew_rig_modifier.gd` (`CrewRigModifier`) | What the two crew skeleton modifiers share: bones read and written in the rig's own space, and the two-bone solve for an arm or a leg. |
| `ship_alarm.gd` (`ShipAlarm`) | The ship-wide Alarm: raised once, red lights, every crew member told. Built per ship as `Ship/Alarm`. |
| `alarm_panel.gd` (`AlarmPanel`) | The wall panels the Alarm is raised from, where they go, and breaking them. Built under `Ship/AlarmPanels`. |
| `crew_noise.gd` (`CrewNoise`) | Hearing: noise events (footsteps, gunshots, doors), how far each reaches, and which Rooms it carries into. |
| `crew_paths.gd` (`CrewPaths`) | Walking round props: the tile grid made from the layout's floor and prop footprints, and bending a navigator route round what blocks it. |
| `../ui/awareness_markers.gd` (`AwarenessMarkers`) | The bar over each crew member's head and the spotted sting, drawn by the HUD. |

Scene: `scenes/crew_3d.tscn`. Tests: `tests/test_crew.gd` (Awareness, the walk
to look, being shot, the sting, hearing, Workers fleeing and cornered, crew
types, On Edge, Guards sharing his position, each weapon's
Gunnery and a Guard firing each gun, a Guard's gun in its hands (every
living Guard on a generated ship showing its Weapon Profile's model and no
Worker one; aiming each gun with both wrists within 4 cm of their places on
it; every bolt from its gun's Muzzle marker, the clear-shot test's point; a
dead Guard's gun hidden), fair fire (the exposure ramp, the
walk-in, five Guards with at most two aiming true, miss points in the open
and at cover, lead, the Shotgun's pellet cap, and the median time to die
against a Pistol and an Assault Rifle), magazines and reloads (each gun's
shots before its first reload, a reload sound at the Guard as every reload
starts, the empty Assault Rifle reload's 3.45 s with no shot in it and the
same time when hit twice and closed on, a Pistol topping up behind cover,
the Shotgun breaking its shell reload off for him inside 3 m and loading to
full with him at 6 m), a habit per gun (each gun's cover
tile in its band after 20 s, the Shotgun holding fire at 10 m, waiting in
ambush beside a doorway, racking before each shot; the Marksman Rifle's
sight line before every perched shot, dodged by a late sidestep, lost when
it is hit, waiting for a true-aim place, holding its perch with him hidden,
falling back to a further perch and firing from the hip in a small Room),
Guards together (the Shotgun picked to flank and ending on a hidden spot
inside the second Door, no Marksman Rifle flanking over 20 seeded fights,
covering fire for every move between cover tiles, firing at a crate's edges
for 4 s when he hides behind it, a Guard radioed from two Rooms away
arriving spot to spot, the last Guard falling back and holding),
staggered bursts,
flanking, a cover spot it cannot reach, facing a body in its way, holding
fire when its muzzle line is blocked, fighting from cover (the ring of four
Guards, one per gun: hidden within 6 s by a fair walk, firing from low
cover, 20 peeks of each gun's rhythm; full cover from a locker; flanked and
closed on in a grid of crates; no cover in an empty Room; and 60 s of three
Guards on a generated medium ship with no one stuck, no shared tile, no
tile beside a Breaker and never two between cover tiles at once), walking round props and round a body in its way,
two crew head-on in a two-wide doorway (both arrive within 12 s), one
standing in a one-wide gap with a way round (passed within 15 s), a Worker
working in a dead-end lane making way for one walking out (out within 11 s,
the Worker back at its spot), two Workers sharing one work spot,
bodies and other traces, routes into the pod, the Alarm and its panels, Headshots, and 60 simulated seconds of routines
on a generated medium ship ending in the Alarm; and Workers running and
hiding: no Worker bolt in the whole suite, the hide roll over 400 spottings
and its replay from the ship's seed, the freeze and a fair run to a corner,
staying put with him 5 m off in its sight, giving its tile up to a Guard,
the wounded hiding for good, coming out after 20 s to raise the Alarm or
back to its routine with nothing to raise, the hiding sweep over 20 medium
ships, and 60 s of a fight on a generated medium ship under the Alarm with
every Worker in a corner by 25 s and none on a Guard's tile), plus the crew fight and
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
- **Workers** walk work loops, are **unarmed** (no weapon and no Gunnery:
  `weapon` and `gunnery` are null from spawn) and never fight. Spotted, a
  Worker runs or hides (see "Workers: running and hiding" below).
- Guards wear the dark Quaternius Soldier; Workers wear the Engineer, the
  Soldier's body and skeleton re-dressed in Blender in orange coveralls with
  reflective bands, an open helmet, a tool belt and air tanks
  (`assets/models/crew/build_engineer.py`). One skeleton, so both play every
  crew clip, and they read apart at a glance.

## States

```
PATROL ──suspicious──▶ INVESTIGATE
  │  ▲                    │
  │  └──Awareness faded───┘
  │                       │ spotted
  └──────spotted──────────┴──▶ HUNT ──within 18 m of where he was seen, or in a Room joined to his, not flanking──▶ COVER ◀──▶ FIGHT
                                │                                                     (CrewCover drives both)
                       3 s out of sight                                                    │
                                ▼                                                 14 s without seeing him
                             SEARCH ◀──────────────────────────────────────────────────────┘
                                │
                       nothing found ▶ PATROL
```

That is a Guard. A Worker swaps HUNT for FLEE, and COWER is hiding:

```
PATROL / INVESTIGATE ──spotted, 3 in 4──▶ FLEE ──raised a panel or a Guard──▶ COWER (hiding)
        │                                                                      ▲    │
        ├──spotted, 1 in 4: freeze 1 s─────────────────────────────────────────┘    │ Alarm down, 20 s with no
        ├──spotted with the Alarm up, wounded, or no panel and no Guard─────────────┘ │ sight or sound of him,
        └──the Alarm──────────────────────────────────────────────▶ COWER            ▼ not wounded
                                                       PATROL ◀──raised it── REPORT (On Edge, walking)
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
- **HUNT**: runs to his last-seen position by the door graph (or flanks, see
  Guards together). Once that position is within 18 m (`CrewCover.TAKE_OVER`),
  or it stands in his Room or a Room joined to it, and it is not flanking,
  it fights from cover instead: a Guard radioed in from further off runs
  until then and arrives spot to spot. A flanker that sees him further than
  6 m from the Door it goes in by turns to fight him where it is. 3 s with him out of sight sends a hunter to SEARCH. A
  Guard hunting where a trace says he was (a body, the open boarding Hatch,
  or told so by the Guard that found it) keeps hunting the old way, into his
  Boarding Pod if that is where the trace leads, until it sees him.
- **COVER / FIGHT**: the cover fight (see Guard combat). COVER while it walks
  to a spot, is down behind it, steps back to it or waits in ambush (a
  Shotgun); FIGHT while it is up, stepping out to fire, or fighting in the
  open. 14 s without seeing him sends it to SEARCH, which walks to the
  last-seen spot and waits 2.5 s; a Marksman Rifle on its perch never
  searches (see A habit per gun).
- **A clear shot**: a Guard fires whenever it has him in sight and a clear
  muzzle line, at any distance, except the Shotgun beyond 8 m (the old
  engage range is gone). It fires only while its muzzle line is clear as
  well as its eye line. The muzzle is its gun's `Muzzle` marker in the
  aimed hold, turned to face him (`Crew3D.aim_muzzle`; see A Guard's gun):
  about 1.5 m up and 0.5 m (Pistol) to 0.9 m (long guns) ahead of its axis.
  The muzzle line is a ball 0.1 m across (a bolt's overlap sphere is
  0.09 m) swept along the barrel, from the body's axis at the muzzle's
  height to the muzzle, then from the muzzle to 0.4 m short of the
  Pirate's torso, plus the two edges of its current spread for the first
  1.5 m, so a crate he crouches behind, or a prop at its own shoulder that
  the barrel pokes past, stops it firing. Up in cover with no clear shot it
  waits 1.2 s and ducks; in the open it walks to the nearest tile at least
  1 m away, with room for its body (nothing within its capsule's radius
  there, `Crew3D._no_room`, so it does not stop short of the tile and judge
  its shot from elsewhere), within its sight of him (14.4 m; a Shotgun's
  8 m), whose muzzle line is clear, in its Room (both Rooms if it stands in
  a doorway).
- **DEAD**: collision off, death clip or tip-over; its cover spot is freed.

### Guns: one of four weapons and its Gunnery

Each **Guard** carries one of the Pirate's four weapons (`Crew3D.weapon`),
the bare live Resource under `resources/weapons/`, so a Sandbox sheet edit
reaches crew shots too. A **Worker** carries nothing. From its gun a crew
shot takes its damage, projectile speed and lifetime, every pellet (a
Shotgun shot throws all 12, each inside the cone on its own, and at most
the Sandbox's pellet cap of them, 9, do damage: 117 of his 150), the time
between shots in a burst, its shot sound, its action sound (the Shotgun's
pump, which a crew Shotgun racks before each shot as its tell rather than
after it), its loudness, and its magazine size, reload times, shell-by-shell
reload and reload sounds (see Magazines and reloads below). Crew ignore its
bloom, Aim Down Sights, sway, recoil, movement spread, swap time and
Viewmodel; the Gunnery's aim error stands in for them. How a Guard handles its gun is that gun's **Gunnery**
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

Read today: the aim error, opening spread, closing time and lead (see Fair
fire), and the rhythm, range band and hold of the cover fight: shots per
burst, bursts per peek, gap between bursts, settle (the Marksman Rifle's is
its sight line), time down, range band near and far, hold before shifting
(see Guard combat and A habit per gun), and the reload factor (see
Magazines and reloads). All
are read at the moment of use, so a Sandbox sheet edit reaches crew already
in the Raid.

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

### A Guard's gun

From `.scratch/crew-combat/issues/16-guards-carry-their-guns.md`
(`CrewGun`, `Crew3D.gun`). A Guard shows its Weapon Profile's `model`
scene (the Pirate's own gun model), 1.15x, from the moment it spawns; a
Worker shows none. It is a skeleton modifier over whatever clip the body
plays, as the look prototype (`prototype/crew-look`) made it: nothing is
baked into clips, so every crew clip and every pose of the body
(`CrewPose`, below) carry it.

- **Carried** (patrol, routine, walking and running): the Pistol hangs at the right thigh in the
  right hand, the left arm free to its clip; a long gun is held low across
  the body, muzzle down and to the left, both hands on it. Placed from the
  chest bone as the clip moves it, so it rides Idle, Walk and Run.
- **Aimed** (`Crew3D.aiming`: today's FIGHT, or within 0.5 s of a shot,
  `AIM_HOLD`, so firing on his cover or a break-off shot raise it too): the
  Pistol in two hands at the chest, the left closed round the right; a long
  gun shouldered, right hand on the grip, left under the fore-end, fingers
  up its right side, the spine turned 30 degrees side-on with the head kept
  ahead. Placed from the chest's place in `Idle_Gun_Pointing`, held still,
  and turned about the body's axis to point where the Guard aims (where it
  looks, or its last shot's aim point), so its `Muzzle` is exactly where
  `CrewGun.muzzle_from` puts it for a Guard standing there aiming at that
  point. The Shotgun sits 8 cm further back along its barrel, so the left
  hand reaches the pump.
- **Blend**: 0.2 s between the two. A shot snaps it to aimed at once.
- **Hands**: each arm's two bones solved so the wrist lands on its place on
  the gun, the clavicle swung forward up to 30 degrees when the hand is out
  of reach (the rig's arms are short beside a 1.15x long gun); the wrist
  turned square to the gun, and the four fingers (knuckle 52, middle 64, tip
  40 degrees) and the thumb closed toward the palm. A place is where the
  hand grips (`CrewGun.HOLDS`, in the gun model's own space: the middle of
  the grip or fore-end, the way it runs across the hand and the way the
  palm faces it), less the hole a closed hand makes from its wrist
  (`FIST`, measured on the rig). Aiming, every wrist lands within 2 cm of
  its place (the Shotgun's left is the furthest, 1.8 cm).
- **Shots**: `Crew3D._fire` aims from where the muzzle will be, turns the
  gun onto the aim point and sends every pellet from its `Muzzle` marker
  (the shot sound rings there too). The Marksman Rifle's sight line starts
  at the same marker. The clear-shot test sweeps from that point (see A
  clear shot).
- **Down behind cover** (blended in with the body's pose): a long gun held
  in close, muzzle up and across to the left, so it keeps out of the prop
  it hides behind (a cover tile's prop face is 0.55 m ahead); the Pistol in
  both hands at the chest, muzzle up (`CrewGun.DOWN_LONG`, `DOWN_PISTOL`).
- **Reloading** (crew-combat ticket 22; never aimed while reloading): the
  gun tipped up and left (`RELOAD_LONG`, `RELOAD_PISTOL`) and the left hand
  off it along a way timed to the reload's progress (`RELOAD_WAY`): to the
  magazine well (`WELLS`, measured off each model's magazine), the old
  magazine pulled clear, down to the pouch on the belt (`BELT`, off the
  hips bone), up to the well with the new one, held there while it seats,
  and back onto the fore-end. The Shotgun goes from its loading port to the
  belt and back for every shell (`SHELL_WAY`, by the shell's own time). No
  reload clip was used: the rig has none, and the library's
  `Pistol_Reload` would need a retarget in Blender onto a different
  skeleton (`issues/02`), so this is still made in code, along a smooth
  way through seven places rather than the prototype's three. The magazine
  itself does not leave the gun.
- **Dead**: the gun is hidden and its modifier stops, so nothing is left to
  pick up.

### A Guard's body in a fight

From `.scratch/crew-combat/issues/22-guards-poses-in-a-fight.md`
(`CrewPose`, `Crew3D.pose`; the stance is `CrewCover`'s). A skeleton
modifier over whatever clip plays, run before the gun's, as the look
prototype posed it: the hips (`Body` bone) lowered and moved back, the
spine leaned over its three bones, the head turned, and each leg's two
bones solved onto its foot. The numbers start from the prototype's
(`prototype/crew-look`: `DOWN`, `DOWN_KNEE`, `DOWN_DEEP`, `RUN_LOW`); where
they changed it is for a rule below.

- **Down behind cover: a squat or one knee**, picked again at every drop
  (every `CrewCover._get_down`: on reaching a spot, ducking back after a
  peek over low cover, stepping back behind full cover), from a shuffled
  bag of three squats and two knees (`CrewCover.SQUATS`, `KNEES`), so three
  drops in five are squats and the order never repeats. The bag draws from
  its own generator seeded off the body's (`_stance_rng`), so picking a
  stance changes no other draw.
  - **Squat** (`CrewPose.SQUAT`: hips down 0.76 m and back 0.17 m, the spine
    leaned 56 degrees): the top of its head zone at 0.99 m, under a 1.1 m
    crate; its capsule's top 0.82 m. The prototype's squat (0.72 m, 38
    degrees) put the head's top at 1.14 m, over a crate, so it went lower;
    the hips go back so the head stays clear of the crate's face.
  - **One knee** (`KNEE`: hips down 0.54 m, the right foot back 0.5 m, toes
    down, the knee just off the floor): the top of its head zone at 1.35 m
    (centre 1.19 m), so it shows over a 1.1 m crate and a level shot at
    1.2 m strikes it, a Headshot; its capsule's top 1.0 m.
  - **The capsule follows the stance** (`CrewPose.BODY_TOP`, set by
    `CrewCover._crouch`), the top of its back and shoulders in that pose:
    under a crate's top either way, so the body cannot be hit over low
    cover; above it, only the head zone. It changes at once as the Guard
    goes down or stands; the drawn pose takes 0.15 s down and 0.2 s up
    (the gun's own blend, so a popped up Guard is up as its gun is).
  - **The head zone** rides the head bone, which the pose moves even on a
    body the ship's reveal hides (only the legs and feet are left out
    there), so a hidden Guard's head is where its stance puts it.
- **Duck at a near miss**: down, it ducks lower for 0.5 s
  (`SQUAT_DEEP`, `KNEE_DEEP`), 0.12 s in.
- **Pop up** over low cover: stands (the body's clip, `Idle_Gun_Pointing`)
  as the gun comes up to the aimed hold.
- **Step out** from full cover and back (`CrewCover.stepping`: out to its
  firing tile, up there, and back): its feet step. Each foot stays planted
  where it stands in the world while the other steps (0.14 s, lifted 7 cm)
  toward where the clip would put it, led by the body's speed; a foot
  steps when it is 8 cm or 25 degrees from there. It walks out and back at
  `CrewPose.STEP_SPEED` (0.45) of its speed so the steps keep up, and plays
  its standing clip, not a run. Down again, the feet blend into the stance
  over 0.15 s.
- **Reloading**: the head turns down and to the gun; the arms are the
  gun's (above).
- **Runs**: running to low cover (`CrewCover.low`, walking to its spot) the
  hips go down 0.3 m and it leans into it (`RUN_LOW`); to full cover, to a
  hiding place, to an ambush or with nowhere to go it runs upright.
- **Cost**: standing as the clip has it, the pose does nothing. About 2.3 s
  of the `crew` suite's run is the pose (most of it Guards down in the
  long fights); the gun's arm solve is about 9 s.

### Magazines and reloads

From `.scratch/crew-combat/issues/04-crew-magazines-and-reloads.md`
(`CrewMagazine`, `Crew3D.magazine`; where it reloads is `CrewCover`'s).

- **Rounds.** A Guard counts every shot against its weapon's magazine size
  (Pistol 12, Assault Rifle 30, Shotgun 6, Marksman Rifle 8), has unlimited
  magazines, and spawns full, so every Raid and Retry starts full. Burst
  length stays its Gunnery's, capped by the rounds left (`Crew3D._new_burst`).
  With none in, or reloading, `Crew3D._fire` fires nothing.
- **Times.** A reload takes the Profile's time times the Gunnery's reload
  factor (1.5): from dry the empty reload (Pistol 1.6 s, so 2.4 s; Assault
  Rifle 2.3, so 3.45 s; Marksman Rifle 2.4, so 3.6 s), topping up the
  tactical one (1.2, 1.8, 2.0 s, so 1.8, 2.7, 3.0 s). The Shotgun loads shell
  by shell: the first shell's time (0.55 s) then a shell's time (0.45 s) for
  each after, times 1.5, each shell counting as it seats (6 from dry: 4.2 s).
  It has no closing pump of its own: it racks before every shot anyway, and
  that rack is its pump.
- **Where.** Dry while up in a peek, it ducks (`_duck`) and reloads as it
  gets down, behind its cover. Dry in the open fight, it first takes cover
  if the cover search finds any (`_pick`, then the hiding fall-back) and
  reloads on getting down there; with none, it reloads where it stands,
  backing away from him 2 m (`BACK_AWAY`, straight back or angled off past
  a prop) at 0.4 of its speed (`BACK_AWAY_SPEED`), facing him. Its peek
  comes when both its time down and its reload are done.
- **It always finishes.** While it reloads down behind cover it does not
  peek and nothing makes it leave: being shot, flanked or closed on changes
  nothing, nor does a near miss (which still lengthens its time down); it
  faces where it last saw him. A reload is ticked by the body every physics
  step (`Crew3D._physics_process`), so it runs to its end whatever the Guard
  does meanwhile. A Guard reloading is never picked to flank.
- **Topping up.** Down behind its cover with him unseen for 3 s
  (`CrewCover.TOP_UP_UNSEEN`) and a part-used magazine, it tops up.
- **The Shotgun breaks off**: loading shell by shell with at least one
  shell in and him in its sight within 3 m (`CrewCover.BREAK_OFF`), it
  stops loading and fires: over low cover or in the open it racks if its
  last rack is stale and shoots once the rack allows (0.2 s), with no
  settle; behind full cover it steps out as usual. Otherwise it loads to
  full.
- **Fair fire.** Starting a reload gives true aim up at once
  (`CrewFire.give_up`), and a Guard reloading, or dry on its way to reload,
  takes none (`Crew3D.can_aim_true`); a Marksman Rifle reloading wants no
  true-aim place (`CrewCover.wants_place`).
- **Covering fire.** A Guard reloading is not covering a partner's move
  (`CrewCover.covering`), but still counts as able to (`can_cover`), like
  one between peeks: it will be up again, and the partner waits at most
  3 s.
- **The tell**: the Profile's reload sounds at the Guard's position, 1 m
  up (`Crew3D.RELOAD_HEIGHT`): the first as a reload starts, the second as
  it ends; the Shotgun's as it starts and as each shell seats. No HUD
  marker. The body emits `reload_started(from_empty)`, `shell_loaded` and
  `reload_ended(broken)`, and `Crew3D.is_reloading()` says whether one is
  running, for the reload pose ("Guards' poses in a fight").

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
  - **another crew member** (living, ahead, centres within 1 m; stuck 3
    tries with nobody that near, within 1.5 m, `GIVE_WAY_FAR`, so a body
    just past arm's length closing a lane counts): it gets
    past (`_get_past`). If that one is standing still (working, waiting,
    chatting, or itself giving way) it goes round it over open floor, the
    tiles within 0.75 m of every crew body near shut (`CrewPaths.route_around`);
    with no way round it asks it to **make way** (`make_way_for`): a crew
    member on routine working at a prop or waiting, or one with no routine
    stood still between wanders, steps off the walker's way
    as below and waits; one that was working then walks back to its spot
    and works the Job again from the start. A Guard holding its spot in a
    fight (down in cover, a Shotgun in ambush) never makes way: a walker
    out of the fight blocked by one with no way round gives that walk up
    and stands 1.5 s (`BLOCKED_PAUSE`) before it walks anywhere again
    (crew-combat ticket 22: a searching Guard walked into a Shotgun in
    ambush in a one-wide way and stood there pushing for the rest of the
    fight). If both are
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
  - **serious**: a **Worker** flees as if it had spotted him, with no roll
    to hide: to an Alarm Panel while the Alarm is down, else to a Guard.
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

A fighting Guard whose last-seen spot for the Pirate is within 18 m fights
from cover (`CrewCover`); further off, and while flanking, the hunt carries
it (see States). Ported from the accepted prototype
(`prototype/guards-in-cover`, `.scratch/crew-combat/issues/05-guards-in-cover.md`),
its rules and numbers kept.

- **A cover spot** is an open tile of the walking grid (`CrewPaths`) with a
  wall or a prop on one of its four sides, from which a crouched body
  (0.9 m) is hidden from his last-seen position, both from his torso and
  from his eyes (so he would not see it there and count it flanked), and
  which has a way to shoot. Found from sight rays when needed; nothing is
  authored. A tile beside a Breaker is never crew cover.
  - **Low cover**: its muzzle line from standing there is clear (it can fire
    over it). It pops up to shoot.
  - **Full cover**: it steps out to the nearest of the eight tiles round it
    that it can walk to straight and whose muzzle line is clear, fires, and
    steps back.
- **Picking.** Filter: within 8 m of it as the crow flies and 12 m by its
  walk (`WALK_REACH`), in its Room, his Room or one joined to either,
  hidden, unclaimed, with a peek, and (for every gun but the Shotgun) at
  least 4 m from him. Score: near it 20 (falling to 0 at 8 m), low cover 40
  (full 20), inside its Gunnery's range band 20 (falling to 0 4 m outside),
  minus 20 if another Guard or its spot is within 2 m. The band is a term
  in the score, never a filter. (The Marksman Rifle searches and scores
  differently: see A habit per gun.) One Guard per spot: claimed on
  choosing, freed on leaving or dying. Of the best six it takes the first
  whose walk is fair and passes no closer than 0.6 m to another crew member
  standing still or stuck trying to walk (it would stall against the body).
- **A fair walk** (its planned route sampled every 0.5 m) never comes nearer
  his last-seen spot than both its ends do, less 1 m, and crosses no more
  than 2.5 m of floor whose torso height he can see.
- **Getting there**: it runs, and stands on the spot (a last step if its
  walk ended short; a spot it is already within its arrive radius of is
  walked onto too, so its lines, judged from the tile's centre, hold). A
  walk passing within 0.6 m of a crew member standing still, or stuck
  trying to walk, is out of reach; stood aside letting another by, it is
  not stalling. Walking 3 s without moving 0.5 m it gives up the spot,
  passes it over for 10 s and thinks again.
- **Rhythm**: down, then up: a settle, its bursts, down again. Per gun from
  its Gunnery: shots per burst (a fresh draw each burst), bursts per peek,
  the gap between bursts, the settle and the time down. Every time (settle,
  gap, time down) varies by ±30 %. Up with no shot it waits 1.2 s and ducks.
  On first reaching a spot it is down 0.3 s. Up with him unseen over 2 s,
  half the time it stays down half a time down longer rather than bob.
  Bursts never start within 0.3 s of another crew member's fighting the
  same Pirate.
- **Down**, it squats or kneels on one knee, picked again at every drop,
  its capsule cut to that stance's top (0.82 m or 1.0 m); squatting, low
  cover hides its head zone too; on one knee the top of its head shows. See
  A Guard's body in a fight.
- **Leaving a spot** (checked while down):
  - **Flanked**: he can see it crouched for 0.4 s: it picks again (that
    holds for a Guard hiding with no shot too).
  - **Too close**: he is in sight within 3 m: it picks a spot at least 1 m
    further from him. Not the Shotgun, which stays; the Marksman Rifle's
    own rule at 5 m takes its place.
  - **No shot**: two peeks running with nothing to shoot: it picks again
    (a Marksman Rifle with him hidden holds its perch).
  - **Out of band**: held its Gunnery's hold before shifting (Pistol 4 s,
    Assault Rifle 8 s, Shotgun 4 s; counted while it holds the spot, down
    or up) with its spot outside its range band, it looks for a spot at
    least 1 m nearer or further, taking it only if it scores 20 % better.
    The Shotgun first tries a walk into its band, then its ambush (see A
    habit per gun). The Marksman Rifle never shifts.
  - **Unseen 5 s**: it moves to a spot at least 1 m nearer where he was
    last seen (never the Marksman Rifle). **Unseen 14 s**: it searches
    (never a Marksman Rifle on its perch).
  - Every change of spot from one it holds waits its turn: one mover at a
    time, under covering fire (see Guards together).
- **Near misses**: a shot of his whose line (from his camera) passes within
  1.2 m of it keeps it down 0.8 s longer (never past its longest time down
  plus 0.8 s), or sends it down if up.
- **Reloading**: dry, it reloads down behind its cover; with him unseen 3 s
  it tops up there; while it reloads it stays down whatever happens (see
  Magazines and reloads). The longest one stretch down can last with him
  in sight (`CrewCover.longest_down`) is its longest time down plus a near
  miss's hold, or its longest reload if that is longer (only the Shotgun's,
  4.2 s against 2.75 s).
- **No cover in reach**: it falls back to the best tile within 14 m (and
  21 m by its walk) where he cannot see it standing, with no fair-walk
  rule, and looks for real cover each second. Once he can see it there
  (it can see him) it no longer hides and picks again. With nowhere to hide either
  it fights where it stands: its first burst after a settle, then bursts
  with pauses of 0.6 of a time down, stepping to a clear shot when it has
  none, and looking for cover every 1.5 s.
- **Sharing**: a Guard that spots the Pirate, and once a second while it keeps
  him in sight, tells every living Guard in its own Room and the Rooms a Door
  joins to it (open or shut: radios) where he is (`CrewCombat.share`). A Guard
  told it while on routine, investigating or searching goes to Awareness 1 and
  hunts there; one already hunting takes the fresher position; one fighting
  ignores it.
- **Aim**: see Fair fire below.
- **Shots**: each Guard draws its own multiplier (0.75–1.35×) at spawn on its
  gun's time between shots.
- **Pin and flank**: one Guard goes round through another Door into his Room
  while another fights; who, and how it ends, is under Guards together.

## Fair fire

Where a Guard's shot goes (`CrewFire`, `Crew3D._fire`). Every Guard fires;
at most two aim true; the rest aim to miss, close. From
`.scratch/crew-combat/issues/06-gunnery-that-feels-fair.md` and the research
note `docs/research/fair-fire-and-cover.md` (branch `research/fair-fire-and-cover`).

- **Exposure ramp.** Spread is its base (its gun's base cone plus its
  Gunnery's aim error) times a multiple that opens at the Gunnery's opening
  spread (3x) on first sight and closes linearly to 1x over its closing time
  (2 s) of unbroken sight, never under 1x (`Crew3D.spread_degrees`). The
  clock (`_exposed_for`) runs while it can see him; it resets when he breaks
  sight, but is held (neither runs nor resets) while the Guard is down
  behind its own cover or stepping out or back (`CrewCover.behind_own_cover`):
  it ducked, he did not break sight. Behind low cover its eyes still see
  him, so the clock runs while it is down.
- **A real cone.** Each pellet strays evenly over the disc of the cone round
  the aim (`CrewFire.scatter`), up and down as well as sideways, so the
  spec's hit chances (a cone against a 0.7 m by 1.8 m body) hold. A
  Shotgun's pellets each draw their own. A draw that would strike the ship
  within 2.5 m of the muzzle (the crate it fires over) has its up-and-down
  stray turned the other way, or dropped if that strikes too
  (`Crew3D._over_own_cover`): it holds its gun over its cover, not into it.
- **Hit, aim spoiled.** A hit on a Guard throws its exposure back to 0: 3x,
  closing again.
- **First burst walks in.** The first burst of a sighting (the first burst
  started since the clock last reset) starts aimed the Sandbox's walk-in
  distance (1 m) to one side, drawn left or right, and walks in: the first
  round the whole distance, falling to 0.4 of it on the last but one, the
  last on him. A round whose line to its point would strike the ship (a
  door frame or wall corner beside him) is aimed the other side, else at
  him. A one-round burst (the Shotgun's, the Marksman Rifle's) has
  nothing to walk, so those guns skip it. Only a Guard aiming true walks in;
  the others aim at miss points.
- **True aim** (one `CrewFire` per Pirate, `CrewFire.of`, kept as meta on
  him). Once a physics frame, at its start, before any Guard has moved or
  fired in it, it settles who aims true: of the Guards fighting him (FIGHT
  or COVER), at most the Sandbox's count (2) hold it. A Guard can take it
  when it has him in sight from its eyes and a clear muzzle line
  (`Crew3D.can_aim_true`, judged afresh). A holder with no clear line hands
  over at once to one with; empty places fill at once; so whenever any has a
  clear line at least one aims true, and a lone Guard always does. A holder
  that has held it the handover time (the Sandbox's 0.8 s, doubled while he
  is crouched or behind cover from it, halved with him within 3 m of it)
  passes it to the waiting Guard with a clear line that held it least
  recently (never first), the nearer him on a tie. A holder that stops
  fighting or dies loses it at once. `CrewFire.give_up` takes it from a
  Guard at once, as a reload starts; a Guard reloading, or dry, cannot take
  it (`can_aim_true`).
- **Lead.** A true-aimed shot goes at his body centre (1.0 m up) plus the
  Gunnery's lead fraction (Pistol 0.3, Assault Rifle 0.5, Shotgun 0,
  Marksman Rifle 1.0) of the way to the true intercept for its bolt's speed
  and his flat velocity; half that during a Slide or Clamber
  (`in_slide_or_clamber` on the Pirate).
- **Fire on his cover** (suppression, see Guards together) is aimed at the
  prop's edge, never true, and is no part of a sighting (it does not walk
  in, and does not count as the sighting's first burst).
- **Miss points.** A Guard not aiming true aims 0.4 to 0.8 m from his body
  centre. Behind cover from it (the tile 0.8 m from him toward it is a prop
  or a wall on the walking grid): at that tile's edge on the side he last
  peeked from, 0.3 m above his body centre, drawn into the band. The side is
  the side of the tile he stands off by 0.15 m or more, remembered per tile
  for when he is square behind it; never seen off it, a coin toss. In the
  open: beside his head (0.5 m above his body centre), on the side away from
  his movement (a coin toss when he is still). They are real bolts and hit
  him if he walks into one.
- **No distance penalty** beyond the cone.

The Marksman Rifle's sight line, its claim on a true-aim place and the
Shotgun's rack are in A habit per gun below.

## A habit per gun

What the gun changes about how a Guard fights (`CrewHabit`, used by
`CrewCover`), from `.scratch/crew-combat/issues/07-where-each-gun-stands.md`
and the tells of `issues/06`. Which gun a Guard carries is read from its
weapon's file (`CrewHabit.gun_of`).

| Gun | Range band | Holds before shifting | Habit |
|---|---|---|---|
| Shotgun | 2 to 5 m | 4 s | ambushes |
| Pistol | 4 to 8 m | 4 s | shifts |
| Assault Rifle | 5 to 10 m | 8 s | anchors |
| Marksman Rifle | 8 to 14 m | never moves up (-1) | perches |

Band and hold are each Gunnery's `range_near`/`range_far` and
`hold_before_shifting`. **Pistol: shifts** and **Assault Rifle: anchors**
are the out-of-band rule above with their holds.

- **Firing range.** A Guard fires at any distance with sight and a clear
  muzzle line. The Shotgun holds fire with him beyond 8 m
  (`SHOTGUN_HOLD_FIRE`): down, it does not peek (it waits, counted in
  `CrewCover.waited`); up, it has no shot; it takes no true-aim place.
- **Shotgun: ambushes.**
  - The only gun that may take a spot within 4 m of him (`SHOTGUN_CLOSE`);
    too close (3 m) does not send it back.
  - Out of its band (beyond 5 m) after holding 4 s with no fair walk to a
    spot inside its band, it goes to its **ambush** (`CrewCover.ambush_spot`):
    the doorway of his Room nearest to it, a tile in either Room the Door
    joins within 5 m of the opening (`AMBUSH_REACH`), where he cannot see a
    standing body, nearest the opening first, reached by a fair walk. With
    no cover at all (in the open) the same after 4 s in the open. His Room
    with no Door: no ambush, and it shifts as the others do. **Where his
    Room has a second Door** and another Guard fights him, the ambush is at
    the Door furthest from the Guard nearest him (the Door a flank goes in
    by, `CrewCombat.far_door`); with no hidden tile in reach there, at the
    Door nearest the Shotgun.
  - **Waiting** (mode AMBUSH, state COVER) it stands facing the doorway.
    He comes into sight within 8 m with a clear muzzle line: it fires from
    where it stands and fights on from there by the cover rules (the tile
    counts as low cover). Seen further off, it picks again. A fair walk into
    its band appearing (looked for every 1.5 s), it takes it. Unseen 14 s,
    it searches.
  - **The rack**, its tell: the Profile's action sound (the pump), played
    before the shot instead of after it. Down behind low cover it racks
    0.3 s before its time down ends (`RACK_LEAD`) and pops up; behind full
    cover it racks as it starts its step out, and its settle is cut so the
    shot comes no later than 0.95 s after the rack (`RACK_LATEST`). Every
    shot (the open fight and the ambush too) comes 0.2 to 0.95 s after a
    rack: one older is racked again and the shot waits 0.3 s.
- **Marksman Rifle: perches.**
  - It searches out to 14 m (`PERCH_RADIUS`, 21 m by its walk) and scores a
    spot by the length of its clear line to him from where it fires (low
    cover: the spot; full cover: its step-out tile), up to its 14.4 m sight
    (`PERCH_LINE`), weighted 40 (`W_LINE`), in place of the band term; a
    spot whose line is longer than its sight is no perch. It tries the best
    18 (`PERCH_TRIED`) for a fair walk, not six, since the longest lines
    are often across open floor.
  - A perch in a Room one back counts only while the Door between stands
    open: a shut Door blocks the sight and muzzle rays, so the spot has no
    peek. It opens no Door for the purpose (a Door it opens on its walk is
    one it walks through).
  - It never moves up: no out-of-band shift, no advance when he hides, no
    search however long he is unseen while it holds a perch, and no new
    spot after blind peeks while he is hidden. It leaves when flanked, or:
  - **Him inside 5 m** (`PERCH_CLOSE`, from where it last saw him): it falls
    back to a spot at least 1 m further from him by a fair walk, if one
    exists; if not it fires **from the hip**: no sight line, its base cone
    (the gun's 3 degrees plus its aim error of 0) doubled (`HIP_CONE`), a
    settle of 0.35 s, and an ordinary gun for true aim (it may aim at a miss
    point and needs no place of its own). It looks again for a further
    perch every 1.5 s, and is off the hip once he is 5 m off again. Up with
    its line showing when he comes inside 5 m, it drops the line and ducks.
- **The sight line** (`CrewSightLine`, the Marksman Rifle's tell). Every
  shot not from the hip, perched or in the open:
  - It needs one of the true-aim places to shoot at all. Down with its time
    down spent, or up with a shot, it wants one (`CrewCover.wants_place`):
    `CrewFire` queues it ahead of the other waiting Guards, and fills an
    empty place or hands one on to it as usual. It waits down until it has
    one (counted in `CrewCover.waited`, which watchers timing a stretch
    down leave out), then pops up or steps out. A place it holds while it
    wants it is never handed on or swapped.
  - Up with its place and a clear shot, the line shows from the rifle's
    muzzle to him (led by its Gunnery's 1.0, so the full intercept) for its
    Gunnery's settle (0.9 s), following him until 0.2 s before the shot
    (`SIGHT_LOCK`), then fixed. The shot goes where the line was fixed
    (`Crew3D.aim_override`), so a sidestep in the last 0.2 s dodges it. It
    then gives up its place. It never fires a deliberate miss.
  - Losing sight or its muzzle line, the line goes and it waits as any Guard
    up with no shot. Hit during the line, it loses the shot, gives up its
    place and ducks (in the open, pauses). A near miss ducks it too.
  - The line starts no burst within the stagger of another Guard's, so the
    shot is never held past its line.

## Guards together

How several Guards fight him as one (`CrewCover`, `CrewTeam`), from
`.scratch/crew-combat/issues/13-guards-working-together-from-cover.md`.

- **Covering fire.** A Guard changes cover (leaves a spot it holds for
  another: flanked, too close, no shot, hiding with no peek, a shift by its
  habit, falling back, or out of its ambush) only while another Guard
  fighting him is up and firing at him, true or a deliberate miss: in a
  peek or the open fight, its last shot within 1 s (`COVER_FIRE`,
  `CrewCover.covering`). It waits for that up to 3 s (`COVER_WAIT`) and then
  goes anyway. When it starts waiting with no partner able to fire, it goes
  at once. Able to fire (`CrewCover.can_cover`): fighting in the open, or
  holding or walking to a spot with a way to shoot, not holding its fire,
  and with him in its sight now, or seen within 3 s while it is down behind
  its own cover or walking to its spot, or firing on his cover. A partner
  up that has lost him is not able. A partner reloading is not covering
  (it fires nothing) but is still able: down reloading it will be up again
  like one between peeks, and the wait is capped at 3 s.
  While it waits it keeps its rhythm, peeking as usual; hiding with no peek,
  the wait counts with its habit's waits (`CrewCover.waited`). The wait is
  `CrewCover.move_wait()`.
- **One mover at a time.** Leaving a spot it held makes a Guard the mover
  (`CrewCover.between`) until it gets down at its new spot, waits in ambush,
  or has no spot and fights in the open; no other Guard fighting him leaves
  its spot meanwhile. Coming into the fight with no spot yet, or from the
  open, it is not between cover tiles. A flanker does not count and does
  not wait.
- **Flank.** One flanker at a time, while another Guard fights him
  (`CrewTeam.consider_flank`, looked at on entering HUNT and every 1 s):
  of the Guards after him that have not flanked in this fight (`flank_done`,
  cleared on PATROL and SEARCH), are outside his Room and have a way round,
  the first by gun: Shotgun, then Pistol, then Assault Rifle; a Marksman
  Rifle never. On a tie, one still hunting before one already fighting,
  then the nearer him. It may leave its spot to go (it needs no covering
  fire and is not the mover). The way round is today's
  (`CrewCombat.flank_route`): the Door into his Room furthest from the Guard
  pinning him (the other fighter nearest him), if its own straight way in
  is not that Door, by a route that avoids his Room, with no fair-walk rule
  between Rooms. Within 1.5 m of that Door (`FLANK_ARRIVE`), at the route's
  end, or seeing him within 6 m of it (`FLANK_SEE`), it enters the cover
  fight on a spot by the cover rules inside that Door: in his Room within
  5 m of it (`FLANK_SPOT_REACH`), walked to without the fair-walk rule
  (`CrewCover.begin_flank`), still no mover (`flank_end`) until it gets
  down. No such spot: it picks as any Guard. Seeing him further from the
  Door it turns to fight where it is. After 20 s it gives up and takes cover
  where it stands (enters the cover fight there).
- **Suppression.** When every Guard fighting him that had a shot at him (in
  its sight with a clear muzzle line) loses it in one frame, one of them
  having stood still (not ducked or stepped away), and a prop's tile lies
  within 2 m beyond him on the line to that Guard (`CrewTeam.prop_between`;
  a wall or a doorway frame is not a prop), he broke sight behind that
  prop. (A Guard's eyes see over a crate he crouches behind; its shot does
  not, and that is what he hides from.) For the Sandbox's suppression time
  (4 s) the Pistol and Assault Rifle Guards fighting him fire at the prop's
  edges: each shot aimed 0.15 m past one of its side edges as that Guard
  sees it (alternating), at his body centre's height (1.0 m), if its eyes
  and muzzle line reach it, a deliberate miss (`Crew3D.miss_at`,
  `last_miss_kind` "prop"), never true. They peek for it in their rhythm,
  and one in the open does not step for a clear shot meanwhile. A
  Marksman Rifle (no line without a target) and a Shotgun (holding fire
  beyond 8 m) take no part. One Guard (not a Marksman Rifle) may move up a
  spot meanwhile, under that covering fire (`CrewTeam.may_move_up`). Then
  they hold. It ends early when any of them has a shot at him again.
- **Called from other Rooms.** A Guard radioed in (`CrewCombat.share`, or
  told by a Worker) hunts upright by its normal route until it is 18 m from
  his last-seen spot or stands in his Room or one joined to it, then
  follows the cover rules and arrives spot to spot.
- **The Alarm sweep.** A sweeping Guard that spots him hunts, and within 18 m
  (he is in its sight, so always) or in a Room joined to his it fights by
  the cover rules like any other. No code of its own.
- **The last Guard.** A Guard that has had another Guard fighting him beside
  it (after him and in his Room or one joined to it, or flanking) and now
  has none is the last Guard (`CrewCover.last_guard`): it moves up no more
  (no shift by its habit, no advance, no ambush, no flank), takes no spot
  nearer him than the one it holds, once picks a spot at least 1 m further
  from him (`_fall_back`), and holds. It does not flee or surrender.

## Workers: running and hiding

Crew-combat ticket 23 (`.scratch/crew-combat/issues/23-unarmed-workers-run-and-hide.md`).
`CrewHiding` holds the rules; Worker states are FLEE (running to raise the
Alarm or a Guard), COWER (hiding) and REPORT (come out, walking to report).

- **Spotting him, Alarm down** (`Crew3D._react_spotted`): three times in four
  it **flees** to the nearest working Alarm Panel (raising the Alarm on
  arrival, see Alarm), else to the nearest living Guard; reaching within
  2.5 m of a Guard it **raises** it (the Guard gets the Pirate's last-seen
  position, goes to Awareness 1 and hunts), then hides. If its Guard dies
  on the way it runs on to the next, with no second roll. One time in four
  (`HIDE_CHANCE`, 0.25) it **freezes** 1 s where it stands, then runs to a
  hiding place. With no working panel and no living Guard it hides with no
  roll. The roll draws from the Worker's own generator, seeded from the
  ship's seed (`ShipLayout.gen_seed`) and its spawn tile, so a Retry of the
  same ship rolls the same and no other draw moves; on a hand-built layout
  with no seed it is seeded off the crew member's own.
- **Spotting him with the Alarm up**, or wounded: it hides, no roll.
- **The Alarm going up**: every Worker not already hiding runs to a hiding
  place; one on its way to a Guard, or walking to report, switches.
- **A hiding place** (`CrewHiding.find`): an open floor tile, never on an
  Apron (the 2 tiles in front of a doorway, so it never blocks one), never a
  tile a Guard holds as cover or another Worker hides on or runs to. Scored:
  a corner or a wedge between wall and prop (a wall or prop on two or more
  of its four sides) 100, so it takes one whenever one is in reach; out of
  sight of every doorway of its Room (no clear line at 1.5 m from the tile
  to the middle of each Door and Hatch, 0.55 m inside the Room) 30; far from
  him, up to 20 at 14 m; within 2 m of a Guard's cover spot, less 20. The
  doorway sight and the sides are worked out by ray once per Room and kept
  on the layout. It looks in its **Post Room** first; of the best 8 tiles
  there it takes the first whose run is fair; with none, the Rooms joined
  to the Room it stands in (and that Room), furthest from him first. With
  no fair run anywhere it **hides where it stands** (`no_way_out`) and
  looks again each second.
- **The run**: full speed, along the route it will walk (the door graph and
  `CrewPaths`), which never comes nearer him than both its ends do, less
  1 m (the Guards' fair-walk rule without the open-floor limit), sampled
  every 0.5 m. Of the fair runs it prefers one that does not cross the line
  between him and a Guard fighting him; it takes one that does only when no
  other of the 8 avoids it. A run that has not arrived in 30 s gives that
  tile up for the next.
- **Hidden**: on its tile (within 0.5 m) it stands still, back to the wall,
  facing into the Room, and turns to watch him while he is in sight. Found,
  it stays put; a fight in its Room does not move it (stray shots can kill
  it). A Guard claiming its tile (`CrewCover._claim` calls
  `CrewHiding.guard_claimed`) sends it on to its next best at once.
- **Coming out**: never with the Alarm up. With it down, after 20 s
  (`COME_OUT`) with no sight (its all-round sight while in COWER) or sound
  (his footsteps, shots and Doors; crew sounds do not count) of him, it
  comes out On Edge at Awareness 0.15 and walks (routine speed) to the
  nearest working panel, raising the Alarm, or the nearest living Guard,
  raising it; then back to its routine (which under the Alarm means
  hiding). With neither it goes back to its routine On Edge. A broken panel
  on the way: the next panel, else a Guard. Spotting him on the way, it
  reacts as to any spotting (a fresh roll). This replaced the 15 s silent
  return: a witness left hiding costs the Pirate his Ghost.
- **Wounded**: a Worker shot and alive always hides, with no roll, and
  never comes out (`CrewHiding.wounded`).
- **Cornered** (`Crew3D._cornered`: him in sight within 3 m) no longer
  changes what a Worker does; the smoke run's bot still reads it, and
  Surrender (ticket 24) is to use it.
- **The look**: today's stance. A hiding Worker stands in the Idle clip
  (the stand-in until Workers' poses, ticket 25); it runs in the Run clip.
  For ticket 25: `CrewHiding.phase` (freezing, running, hidden, hiding where
  it stands) and its `phase_changed` signal, `wounded`, and REPORT; a sound
  of him reaching a hiding Worker arrives in `Crew3D.hear` (where it would
  duck at a gunshot). For ticket 24: `CrewHiding.is_hidden()`, `spot` and
  `no_way_out`; the hook for "he comes within 4 m, or his crosshair rests on
  it" is marked at the end of `CrewHiding.tick`.

## Alarm

**Alarm Panels** (`AlarmPanel.spots`): one in every Bridge and every Armory, on
the wall beside the floor tile nearest the Room's centre that has wall straight
behind it, is not a prop's tile, and is not beside a doorway or Hatch gap. The
panel's screen glows orange; a crew member works it from the tile in front.

**Raising**: a fleeing Worker, or one come out of hiding to report him
(REPORT), that gets within 0.9 m of a working panel raises the **Alarm**
(`ShipAlarm.raise`) with the Pirate's last-seen position, then hides. Once
raised it stays up for the rest of the Raid:
- every Room light turns red and pulses (55 %–100 %, ~0.5 Hz); working panels
  turn red; the HUD shows **ALARM RAISED**;
- every crew member is told (`on_alarm`) and goes **On Edge**;
- **routines stop**: every Worker not already hiding runs to a hiding place
  (COWER), one fleeing to a Guard or walking to report included, and never
  comes out (a Worker that has not seen him hides from where the Alarm says
  he is); Guards on routine, investigating or searching
  hunt the last-seen position, and once that goes cold they **sweep** the ship
  at full speed, Room to random Room, pausing 1.5 s in each, instead of their
  patrol loop, giving up on a Room it has not reached in 30 s. Guards already
  fighting carry on.

**Breaking a panel**: the Pirate's shot breaks a panel (screen goes dark); crew
shots do not. A broken panel raises nothing: a Worker running to it when it
breaks re-picks the nearest working panel, then a Guard. Breaking one is a
gunshot like any other, heard as far as the weapon's loudness (24 m).

**On Edge**: a crew member that has lost the Pirate (entered SEARCH), come
out of hiding, or heard the Alarm is On Edge for the rest of the Raid: every
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
  is given up for the next. A crew member whose walk ends further than its
  arrive radius from the spot (pushed off it by a body passing in a lane)
  walks on to the spot before it works.
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

A bar is drawn only while there is a **clear line** from the Pirate's camera
to the crew member's eye height (1.5 m) on the same world layer crew sight
uses (hull, props, shut Doors), tested every frame, on screen and pinned
alike. Crew through the hull or behind a shut Door show no bar.

It rings the **spotted sting** once per tip into red, whether or not the bar
is drawn. The sting is a
placeholder (`kenney_impact/impactMetal_light_001.ogg`) until one is picked by
ear in the sound booth.

## Tuning

All numbers above are constants in `crew_perception.gd` (`CONE_HALF_DEGREES`,
`SIGHT_RANGE`, `SUSPICIOUS`, `DECAY_PER_SECOND`, `SPOT_TIMES`, `CROUCH_FACTOR`)
and `crew.gd` (`SEARCH_AWARENESS`, `INVESTIGATE_SPEED`, `INVESTIGATE_LINGER`,
`GLANCE_DEGREES`, `TURN_RATE`, `INVESTIGATE_GIVE_UP`, `ROUTINE_SPEED`,
`WALK_ANIM_SPEED`, `DOOR_CLOSE_AFTER`, `DOOR_FORGET`, `DOOR_ADOPT`, `CHAT_*`,
`JOB_GIVE_UP`, `CORNERED_RANGE`, `HIDE_CHANCE`,
`GUARD_REACH`, `PANEL_REACH`,
`ON_EDGE_PAUSE`, `SWEEP_PAUSE`, `MUZZLE_BALL`,
`MUZZLE_TARGET_GAP`, `MUZZLE_NEAR`, `OWN_COVER`, `FIRING_STEP`, `RELOAD_HEIGHT`, `UNSTICK_AFTER`, `BLOCKED_PAUSE`,
`UNSTICK_MOVE`, `SIDESTEP`, `GIVE_WAY_NEAR`, `GIVE_WAY_PASSED`,
`GIVE_WAY_WAIT`, `GIVE_WAY_INSIST`), `crew_paths.gd` (`CLEARANCE`, `SAMPLE`,
`SNAP`, `BODY_GAP`, `MAKE_WAY_REACH`, `MAKE_WAY_CLEAR`), `crew_perception.gd` (`ON_EDGE_FACTOR`),
`crew_combat.gd` (`BURST_STAGGER_FRAMES`, `SHARE_EVERY`, `FLANK_GIVE_UP`,
`FLANK_ARRIVE`, `FLANK_SEE`, `JITTER`), `crew_team.gd` (`FLANK_LOOK`,
`FLANK_ORDER`, `STILL`, `PROP_PROBE`, `PROBE_STEP`, `EDGE_OUT`,
`SUPPRESSORS`), `crew_fire.gd` (`WALK_IN_NEAREST`, `MISS_NEAR`, `MISS_FAR`,
`MISS_MARGIN`, `HEAD_RISE`, `HEAD_MISS_NEAR`, `EDGE_RISE`, `COVER_PROBE`,
`PEEK_OFF`, `CLOSE`, `MOVING`),
`crew_cover.gd` (`TAKE_OVER`, `SEARCH_RADIUS`, `FALL_BACK_RADIUS`,
`WALK_REACH`, `OPEN_RUN`, `NEARER_SLACK`, `TRIED`, the score's `W_*`,
`FULL_SHARE`, `BAND_FALLOFF`, `SPACING`, `JITTER`, `WAIT_UP`, `BLIND_PEEKS`,
`FLANKED_AFTER`, `TOO_CLOSE`, `BETTER`,
`UNSEEN_ADVANCE`, `UNSEEN_SEARCH`, `NEAR_MISS`, `NEAR_MISS_HOLD`,
`LOOK_HIDING`, `LOOK_OPEN`, `COVER_FIRE`, `COVER_WAIT`, `FLANK_SPOT_REACH`,
`ARRIVE_DOWN`, `MOVE_GIVE_UP`,
`UNREACHABLE_FOR`, `STEP_GIVE_UP`, `OPEN_PAUSE`, `SQUATS`, `KNEES`,
`TOP_UP_UNSEEN`, `BREAK_OFF`, `BACK_AWAY`, `BACK_AWAY_SPEED`),
`crew_habit.gd` (`SHOTGUN_CLOSE`, `SHOTGUN_HOLD_FIRE`, `AMBUSH_REACH`,
`RACK_LEAD`, `RACK_EARLIEST`, `RACK_LATEST`, `PERCH_RADIUS`, `PERCH_LINE`,
`W_LINE`, `PERCH_TRIED`, `PERCH_CLOSE`, `SIGHT_LOCK`, `HIP_CONE`,
`HIP_SETTLE`), `crew_sight_line.gd` (`WIDTH`, `COLOUR`),
`crew_pose.gd` (`SQUAT`, `KNEE`, `SQUAT_DEEP`, `KNEE_DEEP`, `RUN_LOW`, `STEP`,
`BODY_TOP`, `DROP_TIME`, `RISE_TIME`, `FLINCH_IN`, `FLINCH`, `RELOAD_LOOK`,
`STEP_TRIGGER`, `STEP_TURN`, `STEP_TIME`, `STEP_LIFT`, `STEP_SPEED`),
`crew_gun.gd` (the holds, `HOLDS`, `WELLS`, `BELT`, `WELL_CLEAR`,
`RELOAD_WAY`, `SHELL_WAY`),
`crew_hiding.gd` (`FREEZE`, `COME_OUT`, the score's `W_*`, `FAR_FULL`,
`GUARD_NEAR`, `DOORWAY_EYE`, `DOORWAY_IN`, `NEARER_SLACK`, `WALK_SAMPLE`,
`TRIED`, `ON_TILE`, `RUN_GIVE_UP`, `LOOK_AGAIN`),
`crew_traces.gd` (`LOOK_EVERY`, `REACH`, `AWARENESS`, `AIM_HEIGHT`),
`ship_alarm.gd` (`RED`, `PULSE_*`), `alarm_panel.gd` (`ROLES`, `SIZE`, `HEIGHT`),
`crew_types.gd` (`GUARD_ROLES`, `WORKER_ROLES`), `HEARD_NOISE`, `HEARD_GUNSHOT`, `HEARD_CAP`) and
`crew_routine.gd` (`WORK_PROPS`, `JOBS_MIN`/`MAX`, `WORK_TIME`,
`PATROL_PAUSE`, `AWAY_CHANCE`) and `crew_noise.gd` (`SPRINT_STEP`, `WALK_STEP`, `DOOR`). They are starting values to be tuned by
playtest. Gun numbers are not here: they are each weapon's Profile and its
Gunnery, edited in the Sandbox sheet (`docs/sandbox.md`), as are the crew
fight's five numbers on the Sandbox resource (how many aim true, the
handover time, the walk-in distance, the Shotgun pellet cap, the
suppression time); the gun roll's
weights, multipliers and caps are constants in `scripts/ship/gun_roll.gd`
(`BASE`, `ROOM`, `MARKSMAN_CAP`, `ALL_SHOTGUN_ROOM`).

## Stealth XP

The crew's Awareness feeds the Pirate's XP (`RaidLedger`):
- A crew member records, as it falls, whether it **died unaware**: not in
  combat (HUNT, FIGHT, COVER, FLEE, COWER) and not spotted. A Worker come out
  of hiding and walking to report (REPORT) is not in combat, at Awareness
  0.15: killed then, it died unaware. A kill on one is
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
