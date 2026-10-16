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
| `crew_noise.gd` (`CrewNoise`) | Hearing: noise events (footsteps, gunshots, doors), how far each reaches, and which Rooms it carries into. |
| `../ui/awareness_markers.gd` (`AwarenessMarkers`) | The bar over each crew member's head and the spotted sting, drawn by the HUD. |

Scene: `scenes/crew_3d.tscn`. Tests: `tests/test_crew.gd` (Awareness, the walk
to look, being shot, the sting, hearing), plus the crew fight in
`tests/test_ship_3d.gd`.

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

- **PATROL**: wanders random floor points in its own Room (its Post Room,
  `home_room`), holding 0.8–2.2 s between walks. While stood still it glances
  around: every 1.5–4 s it turns up to 70° either way, so the sight cone is
  never a fixed wedge.
- **INVESTIGATE** (new in #53): entered when Awareness is suspicious but not
  spotted, whether from a glimpse or a noise. Walks at 45 % speed toward where the Pirate was last noticed, faces
  it, re-paths while it still has him in view, and lingers 2 s at the spot.
  Goes back to PATROL once nothing is in view, it has arrived, the linger is
  over and Awareness has drained below suspicious.
- **HUNT / FIGHT / COVER / SEARCH**: the combat loop, unchanged from before #53
  apart from how it is entered. HUNT paths to the last-seen position; FIGHT
  fires 3-round bursts (0.14 s apart, 7° spread) inside 10.6 m; a spent burst
  goes to COVER for a 1.1 s reload and a 1.2 s hold; 3 s out of sight sends
  any of them to SEARCH, which walks to the last-seen spot and waits 2.5 s.
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
`GLANCE_DEGREES`, `TURN_RATE`, `HEARD_NOISE`, `HEARD_GUNSHOT`, `HEARD_CAP`) and
`crew_noise.gd` (`SPRINT_STEP`, `WALK_STEP`, `GUNSHOT`, `DOOR`). They are starting values to be tuned by
playtest.

## Not yet built

Routines and roaming (#55), Guard and Worker types (#56), the
ship-wide Alarm (#57), Guard teamwork (#58), bodies (#59), traces (#60) and
stealth XP (#61).
