Status: resolved
Blocked by: none

# Two crew block each other for over 40 s

## Parent

Found on 2026-11-22 by the hardened whole-Raid smoke run, after `02-crew-stuck-on-props.md` was fixed. Not confirmed in a play session.

## What is wrong

Two crew members meet head-on in a 2-wide doorway, or one stands in the other's way, and the sidestep added by ticket 02 loops without either getting past. Neither moves 1 m in 40 s, which fails the smoke run's stuck invariant. Seen in 4 of about 2200 Raids, all Loud on large ships; it fails roughly one full gate run in twelve.

Replays:
- `tests/run_all.sh only=raid_smoke seed=4444 seeds=10 class=large ship=739174378 script=loud`
- `tests/run_all.sh only=raid_smoke seed=6666 seeds=10 class=large ship=803174260 script=loud`
- `tests/run_all.sh only=raid_smoke seed=9999 seeds=10 class=large ship=599767254 script=loud`
- `tests/run_all.sh only=raid_smoke seed=558625915`

## Acceptance criteria

- [x] (agent) Two crew members walking head-on through a 2-wide doorway both reach their destinations within a stated time; asserted in `tests/test_crew.gd`.
- [x] (agent) A crew member whose route is blocked by a standing crew member gets past within a stated time; asserted in `tests/test_crew.gd`.
- [x] (agent) The four replays above pass.
- [x] (agent) 20 consecutive full `tests/run_all.sh` runs pass.
- [ ] (human) Crew passing each other in doorways looks natural in a play session.

## Evidence

- Causes confirmed (2026-11-22, by tracing each replay):
  - `seed=4444 ... ship=739174378`: a leg from one doorway to the next Door in the same wall row (tiles (55-56, 90) to (64-65, 90)) ran straight along the wall row into the wall. `CrewPaths._round` would not bend it because both ends were doorway tiles, in no Room, so the only way round (through Room 17 between them) counted as "another Room". Four to six crew piled up in the doorway; neighbours made it read as "pressed against a body". Also: a crew member that gave up its Job standing on a doorway tile got no door-graph route (`ShipNavigator` returns nothing from no Room) and walked one straight line at its destination through the hull.
  - `seed=9999 ... ship=599767254`, `seed=6666 ... ship=803174260`, `seed=558625915` (`large 23025201 loud`): head-on meetings at the mouth of a one-wide dead-end pocket beside props (between a prop row and the hull). The one inside cannot move; the one outside's 1 m sidestep found no open tile either side, so neither ever moved. In 9999 the outside one then worked a Job standing in the pocket's mouth for 7 s more.
  - Found during the 20-gate count (`tests/run_all.sh only=raid_smoke seed=419177962 class=medium ship=295289809 script=loud`): a Worker at the dead end of a one-wide lane, the way out blocked by a Worker working a spot in the lane that never left it for 40 s. Fixed (make way, below) and the count restarted.
- Fix (`scripts/crew/crew.gd`, `scripts/crew/crew_paths.gd`; written up in `scripts/crew/CREW_AI.md`, "Getting about"):
  - A leg's end on a doorway tile stands for the two Rooms its Door joins, and the leg's own Room is the one both ends share (`CrewPaths._leg_rooms`). A crew member re-pathing from a doorway steps first onto the neighbouring Room tile with the shorter route (`Crew3D._waypoints`).
  - Stuck against another living crew member (`_get_past`): if it stands still, go round it over open floor with the tiles within 0.75 m of every body near shut (`CrewPaths.route_around`), else ask it to make way (`make_way_for`: a crew member on routine, working or waiting, steps off the walker's way, waits, then walks back to its spot and works its Job again). If both walk, only one acts (`_acts_first`): the one that can (has a way round or an open tile 1 m off the other's way within 5 steps, `CrewPaths.make_way`), and of two that both can, the lower instance id. It goes round, or steps aside and waits until the other has walked 2 m on, stopped, or 5 s are up. After 8 stuck tries either acts if it can. A Guard sweeping under the Alarm gives up a Room not reached in 30 s.
  - Cannot deadlock by construction in the symmetric case: two crew mirroring each other need both to act or neither. For a walking pair, whenever either can act, exactly one does, by an order that never changes, and the other holds still while the actor leaves its way or goes round. Neither can act only in a corridor closed at both ends, where the Job's 30 s give-up still applies. A standing blocker either makes way (working, waiting) or ends on a timer (chat, give-way); a hiding Worker under the Alarm is outlasted by the sweep give-up.
- Head-on through a two-wide doorway: `tests/test_crew.gd::_check_head_on_doorway`. Two crew walking head-on along the line through a two-wide doorway must both arrive 10 m on within `HEAD_ON_TIME` = 12 s (they take 9.2 s and 7.4 s at routine pace, the same on every seed). Before the fix: `FAIL  give way: the crew member from the west, head-on in a two-wide doorway, took -1.0 s to arrive (stood at (108.1535, 0.000977, 3.999999))`, and the same for the east one. After: PASS.
- Route blocked by a standing crew member: `tests/test_crew.gd::_check_standing_in_gap`. A crew member stands still in a one-wide gap between the wall and a row of crates, square in a walker's way, and the long way round is open. The walker must arrive within `STANDING_TIME` = 15 s (measured 11.9 s). Before: `FAIL  give way: walking through a one-wide gap a crew member stands in, with a way round, took -1.0 s (stood at (420.5, 0.000875, 3.7982))`. After: PASS. Also `tests/test_crew.gd::_check_working_in_lane`: a walker at the dead end of a one-wide lane, a Worker working in the lane for 60 s. The walker must be out within `LANE_TIME` = 11 s (measured 8.6 s) and the Worker back at work within 1.5 m of its crate, facing it. With `make_way_for` not called: `FAIL  give way: walking out of a dead-end lane past a Worker working in it took -1.0 s (stood at (431.34, 0.001, 5.500121))`. After: PASS. The "before" runs had the new behaviour switched off in the final code; the files were restored byte-identical (md5).
- The four replays, on the final code, all PASS: `tests/run_all.sh only=raid_smoke seed=4444 seeds=10 class=large ship=739174378 script=loud` (15 checks), `seed=6666 seeds=10 class=large ship=803174260 script=loud` (22), `seed=9999 seeds=10 class=large ship=599767254 script=loud` (22), `tests/run_all.sh only=raid_smoke seed=558625915` (924 checks, 100 s). The run-20 failure above, `tests/run_all.sh only=raid_smoke seed=419177962`, also PASS (918 checks).
- Wide sweeps on the final code, `tests/run_all.sh only=raid_smoke seeds=10 seed=<n>`: 4444 PASS (1832 checks; Ghost 28/30, Loud with a kill 29/30, Loot 59/60), 6666 PASS (1833; 30/30, 29/30, 59/60), 9999 PASS (1839; 29/30, 30/30, 60/60), 1111 PASS (1839; 29/30, 30/30, 60/60). Every invariant and floor is unchanged.
- 20 consecutive full `tests/run_all.sh` runs on rolled seeds, final code, all PASS (run, seed, result, total):
  - 1 seed 105908155 PASS 162 s; 2 seed 54335101 PASS 165 s; 3 seed 829181124 PASS 161 s; 4 seed 989885571 PASS 152 s; 5 seed 810095273 PASS 156 s;
  - 6 seed 919686532 PASS 149 s; 7 seed 312474540 PASS 150 s; 8 seed 493265525 PASS 155 s; 9 seed 499972276 PASS 145 s; 10 seed 479622756 PASS 160 s;
  - 11 seed 83788573 PASS 159 s; 12 seed 480979244 PASS 176 s; 13 seed 472141201 PASS 155 s; 14 seed 817193513 PASS 163 s; 15 seed 18530451 PASS 160 s;
  - 16 seed 14450146 PASS 147 s; 17 seed 860314278 PASS 166 s; 18 seed 679009349 PASS 168 s; 19 seed 828158051 PASS 161 s; 20 seed 365612145 PASS 145 s.
  An earlier count of 20 on the code before `make_way_for` passed 19 and failed run 20 (seed 419177962, above). That failure was this bug, so it was fixed and the count restarted.

## Owed to playtest

- (human) Crew passing each other in doorways looks natural in a play session.

## Comments

2026-11-22: fixed by a subagent, test-first; 20 consecutive full gate runs passed. The orchestrating session re-ran the full gate afterwards (7 suites PASS, 168 s). Play session owed.
