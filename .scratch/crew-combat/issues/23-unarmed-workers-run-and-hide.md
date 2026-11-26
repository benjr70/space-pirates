Status: resolved
Blocked by: 15

# Unarmed Workers run and hide

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 9 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Workers" and `issues/08`.

- Spotting the Pirate with the Alarm down: three in four run for the nearest working Alarm Panel, else the nearest living Guard; one in four freeze 1 s and run to a hiding place; with neither panel nor Guard, hide.
- Alarm up: every Worker not already hiding runs to a hiding place; one on its way to a Guard switches.
- A hiding place, scored by preference: a corner or a wedge between wall and prop; out of sight of every doorway of its Room; far from the Pirate and from any Guard's cover. In its Post Room if reachable without passing him, else in the joined Room furthest from him. Never a tile a Guard has claimed; if a Guard claims its tile it moves to its next best.
- It runs at full speed, by no route that runs toward him, avoiding the line between him and a fighting Guard where another route exists.
- Hiding: it stays put when found, and through a fight in its Room.
- Coming out: never with the Alarm up. With it down, after 20 s with no sight or sound of him it comes out On Edge and walks to the nearest working panel (raising the Alarm) or Guard (alerting it), then resumes its routine; with neither, it resumes On Edge. This replaces the 15 s silent return.
- A Worker shot and alive always hides, with no roll, and never comes out.
- Traces unchanged.
- Poses are a later ticket: use today's stance or a stand-in and say which.
- Update `CREW_AI.md`.

## Acceptance criteria

- [x] (agent) No Worker fires a shot in any check of the crew suite.
- [x] (agent) With the Alarm raised, every living Worker is within 0.5 m of a tile with wall or prop on at least two sides within 25 s, on a generated medium ship.
- [ ] (agent) Over 20 seeds, at least 80% of hiding tiles have no clear line at 1.5 m to any doorway of their Room.
- [x] (agent) No Worker's hiding tile is a tile a Guard has claimed as cover, over a 60 s fight.
- [x] (agent) A Worker running to hide is never nearer the Pirate than both ends of its route less 1 m.
- [x] (agent) Over 400 spottings with the Alarm down and a panel in reach, between 20% and 30% of Workers hide and the rest run for a panel or a Guard.
- [x] (agent) A hidden Worker with the Alarm down and the Pirate gone raises the Alarm at a working panel, having left its tile 20 s after last noticing him, within 1 s.
- [x] (agent) With every panel broken and no Guard alive, that Worker is back on its routine and On Edge, and the Alarm is still down.
- [x] (agent) A Worker hit for less than its Health is on a hiding tile within 15 s and has not left it 60 s later, Alarm down.
- [x] (agent) A hidden Worker with the Pirate standing 5 m off in its sight for 10 s does not leave its tile.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) Under the Alarm the ship feels afraid: Workers run and are found tucked into corners.
- [ ] (human) Leaving a witness with the Alarm down feels like a real cost.

## Evidence

- No Worker fires: `tests/test_crew.gd::_check_no_worker_shots`, run last; a `node_added` hook set in `_initialize` counts every `Projectile3D` entering the tree by its `shooter` across every check of the suite, and asserts 0 from Workers and more than 0 from Guards (so the count is listening).
- Every Worker in a corner within 25 s: `tests/test_crew.gd::_check_workers_in_fight`: a medium ship rolled from the suite seed with its whole crew, the Pirate (unkillable, still) in the middle of the Post Room of the most Workers, the Alarm raised there; at 25 s every living Worker is within 0.5 m of a tile centre with a wall or prop on at least two of its four sides (`CrewHiding.tucked`, from the walking grid).
- No hiding tile a Guard claimed, over a 60 s fight: `tests/test_crew.gd::_check_workers_in_fight`, every frame of the same 60 s, no Worker's hiding tile (running to it or on it) is in the set of Guards' claimed cover tiles; asserts a fight happened (Guards' claims > 0). Plus `_check_hide_run`: a Guard claiming a hidden Worker's tile sends it running at once and onto another corner within 10 s.
- A run never nearer than both ends less 1 m: `tests/test_crew.gd::_check_hide_run`: a Worker that rolled to hide with the Pirate 4.1 m off, its distance to him sampled every frame of the freeze and run; asserts the nearest is at least min(start, hiding tile) - 1 m (measured 4.12 m against ends 4.12 and 12.81 m).
- 20 to 30% of 400 spottings hide: `tests/test_crew.gd::_check_hide_roll`: 100 spottings by each of four Workers on the hiding rig (its own `gen_seed`, so the rolls are fixed), a working panel in reach, Alarm down; asserts every spotting either froze to hide or ran for the panel and the hide count is 80 to 120 (measured 115, 28.75%); and a Worker spawned again on the same tile rolls the same sequence.
- Comes out 20 s after last noticing him, within 1 s, and raises the Alarm: `tests/test_crew.gd::_check_out_to_panel`: hidden, the Pirate parked off the ship 0.5 s after it hides; the last frame it had him in sight (`_can_see`) against the first frame it is more than 0.5 m off its tile, asserted 20 s within 1 s (measured 20.15 s); then the Alarm is raised with the Worker within 1.5 m of the panel's use spot.
- Every panel broken, no Guard: `tests/test_crew.gd::_check_out_with_nothing`: hidden then left 23 s quiet; asserts state PATROL with a planned routine, On Edge, the Alarm still down.
- Wounded hides for good: `tests/test_crew.gd::_check_wounded_hides`: hit for 1 with a working panel in reach and the Alarm down; asserts on its hiding tile (within 0.5 m, HIDDEN) within 15 s, then never more than 0.5 m off it, still COWER, Alarm down, over the next 60 s.
- Found, it stays: `tests/test_crew.gd::_check_hide_run`: the Pirate set 5 m from the hiding tile with a clear eye line for 10 s; asserts he was in its sight on at least 90% of frames and it never moved more than 0.5 m off its tile.
- `tests/run_all.sh` passes: see the gate runs in Comments.

## Owed to playtest

- (human) Under the Alarm the ship feels afraid: Workers run and are found tucked into corners.
- (human) Leaving a witness with the Alarm down feels like a real cost.

## Comments

Built 2026-11-26.

**Unmet: "Over 20 seeds, at least 80% of hiding tiles have no clear line at 1.5 m to any doorway of their Room."** Left unticked. The generated Rooms cannot give it under the spec's rule that a Worker hides in its Post Room when the run there is fair. Measured before building (medium seeds 1 to 20, every Worker's Post Room, a ray at 1.5 m from each open tile to each Door and Hatch): only 55 of 106 Worker Rooms have any open tile out of every doorway's sight at all (52 have one that is also a corner); at the hidden Worker's crouched height it is no better. These are big open Rooms (130 to 250 open tiles) whose props are mostly under 1.5 m. Built as the spec says (doorway-hidden is the second preference, after a corner), `tests/test_crew.gd::_check_hiding_sweep` measures 54 of 131 hiding tiles out of sight (41%), and asserts what the build does control: where the Room offers a corner out of every doorway's sight, at least 80% of picks take one (54 of 62; the rest are corners whose run would be unfair). Reaching 80% overall needs the spec changed (let a Worker leave its Post Room for a hidden corner elsewhere) or the generator (tall props or L-shaped Rooms in Worker Rooms), both outside this ticket. Status is left `ready-for-agent` for that reason.

Choices made:
- New file `scripts/crew/crew_hiding.gd` (`CrewHiding`), one per Worker (`Crew3D.hiding`), drives COWER, which now means hiding. A new state REPORT (last in the enum) is a Worker come out walking to report. `_find_cover_point` and `cover_search_radius` are no longer used by the brain; they are left because `ship_3d` (`_check_cover`, `built_sample_checks.gd::_check_cover`) still tests them. A follow-up could swap those checks to `CrewHiding.find` and delete them.
- The score: corner or wedge (two or more solid sides of four) 100, out of every doorway's sight 30, far from him up to 20 at 14 m, within 2 m of a Guard's cover spot less 20. The corner weight is above the rest combined, so a Worker always takes a reachable corner (the 25 s line). Tiles on an Apron (2 tiles in front of a doorway) are never picked, so a hiding Worker never stands in a doorway lane; other Workers' tiles are never shared.
- "Doorway" is a Door or a Hatch (`Interiors.openings`), tested at the middle of the gap, 0.55 m inside the Room, both ends at 1.5 m.
- Room choice: the Post Room if one of its best 8 tiles has a fair run; else the Rooms joined to the Room it stands in (that Room too), furthest from him by Room centre first. None: it hides where it stands (`no_way_out`) and looks again every second.
- The fair run is the Guards' rule without the open-floor limit, with the same 1 m slack. "Avoiding the line between him and a fighting Guard where another route exists": of the fair candidates, the first whose route does not cross any line from him to a Guard in FIGHT or COVER; a crossing one only when none of the 8 avoids it.
- A Worker that has not seen him hides from the Alarm's position (`on_alarm` sets its last-seen spot).
- The hide roll draws from the Worker's own generator seeded `hash([gen_seed, "worker hide", spawn tile])`; nothing else draws from it, and no draw was added to the global RNG or `Crew3D._rng` (the old roll on `_rng` in FLEE's entry is gone). On a layout with no `gen_seed` (test rigs) it seeds off `_rng.seed`.
- "Sight or sound of him" for the 20 s: its all-round sight while hiding (`_can_see`), and any noise whose source is not crew (his steps, shots, Doors) reaching it through `Crew3D.hear`.
- Coming out it walks at routine speed (0.5). A broken panel on the way: next panel, else a Guard, else back to routine. Spotted on the way: a fresh spotting (new roll). Reaching a Guard it raises it and goes back to its routine; raising the Alarm, the Alarm sends it to hide.
- The FLEE "cornered, cower in place" rule is gone (the ticket replaces cowering); `_cornered()` stays for the smoke bot and ticket 24.
- Pose: today's stance. Hiding is the Idle clip, standing, back to the wall facing into the Room, turning to watch him while he is in sight; running is the Run clip.

For ticket 24 (Surrender): `CrewHiding.is_hidden()`, `spot`, `tile`, `no_way_out` (no fair run anywhere: "no route away that does not pass him"); the attach point is marked at the end of `CrewHiding.tick`. For ticket 25 (poses): `CrewHiding.phase` (freezing, running, hidden, hiding where it stands) with `phase_changed`, `wounded`, `facing`, the REPORT state, and `Crew3D.hear` where a gunshot reaches a hiding Worker.

Existing checks changed: `_check_worker`'s cornered case still asserts state COWER after 30 s (COWER is now hiding: with no panel and no Guard it hides, no roll); only its wording changed. `_check_alarm`, `_check_bodies`, `_check_routines` unchanged and passing. `tests/test_raid_smoke.gd`: comments only ("cowering" to "hiding"); the bot still leaves a hiding Worker alone unless it is cornered, so a Worker that hid from the Quiet bot can now come out and raise the Alarm. Quiet still ghosts above its floor (14 of 15 in the default run).

Noticed, not changed: a Worker in REPORT is not "in combat" at Awareness 0.15, so killing one counts as an unaware kill (150 XP); ticket 24 sets the XP rules for Workers.

Suite cost: `crew` went from about 64-74 s to 85-115 s (451 to 453 checks): the 60 s fight on a full medium ship and the 20-ship sweep.

Validation, 2026-11-26: full gate twice, both PASS (rolled seed, then seed 917293733: crew 453 checks 79 s / 91 s, smoke 1104 checks, totals 387 s and 415 s); `tests/run_all.sh only=raid_smoke seeds=20` PASS (seed 34374158, 4389 checks, Quiet Ghost 60 of 60, Loud with a kill 60 of 60, Loot 120 of 120); `tests/run_all.sh only=crew` three more times PASS (seeds 56314714, 16615419, 998005864; 453 checks each). `tests/shots.sh crew` PASS; `front.png` and `side.png` read: the Worker (orange, unarmed) and the Guard stand on the floor, nothing missing or clipping; the hiding stand-in is today's Idle stance, so nothing new to see.

- Closed 2026-11-26 at the user's close-out of the spec, with the "80% of hiding tiles out of every doorway's sight" line still unticked: measured 41%, because most Worker Post Rooms have no such tile; where a Room has one, Workers take it 87% of the time. The user was told and did not ask for a change. A generator change to give Rooms such tiles would be new work.
