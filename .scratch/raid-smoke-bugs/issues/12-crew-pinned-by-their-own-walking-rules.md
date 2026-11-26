Status: ready-for-agent
Blocked by: none

# Crew pinned 5 s or more by their own walking rules

## Parent

Found by crew-combat ticket 27 (`.scratch/crew-combat/issues/27-firefights-in-the-raid-smoke-suite.md`), 2026-11-26: its smoke invariant "no crew member tries to walk 5 s without moving 0.3 m, in any state" (`tests/test_raid_smoke.gd::_stuck_walking`) failed 7 of 1285 checks on `tests/run_all.sh only=raid_smoke seed=641152174`, all of that kind: crew pressed against wall corners, a crate, and each other. The old rule (1 m in 40 s, only on the way to a Job) hid them.

## What was seen

On `40c7c63`, seed 641152174: Workers on routine and Workers running to hide pinned against a wall (Walls GridMap) at (61, 63), (65, 14), (67, 12), (65, 16); a Worker against a crate at (61, 21); a Guard on patrol against another walking Guard at (66, 56); a Worker on patrol against a Guard searching at (63, 15). Each was replayed narrowed (`class= ship= script=`) and in the full run with a throwaway trace in `Crew3D._watch_progress` (every stuck second: state, position, path, whether the next leg is clear, the crew member in the way, its state, position and path) and at each place a path is set. Every fix shifted the run (the RNG and physics diverge once one crew member moves differently), so each full replay uncovered the next case; all of them below were traced. The invariant was never loosened.

## Causes

1. **A routine walk that wandered its Post walked a straight line to its Job's spot.** `_start_job` wanders the Post when no Job's spot can be stood on, but leaves the routine on that Job. Arrived, `_tick_routine`'s "pushed off the end of its walk" branch saw the Job's spot far off and walked `[job.at]`: one point, 31 m away through the hull (medium 971281456 loud: from (63.1, 72.5) to (54.5, 32.5), pinned at (61, 63)).
2. **A routine walk given up behind a Guard fighting was sent straight back.** `_give_up_walk` cleared the path and set `BLOCKED_PAUSE`, but the same branch put the Job's spot back next frame, a raw line again (large 673802884 loud). Moved on to the next Job at once instead, a walker pressed on into a Guard in cover in its Room's only doorway, Job after Job (large 673802884 caught).
3. **Re-routing only on the first stuck second of a walk.** `_stuck_tries` counts for the whole walk, so a walker pushed off its line later (its next point now past a wall corner or a doorway jamb) was never re-routed, and with nobody in its way and no clear sidestep it pressed on (large 395627976 loud: the leg from (67.6, 12.4) to (74.5, 7.5) through the bridge wall).
4. **A route from a body pressed against a prop went back to its own tile's centre.** `CrewPaths._round` string-pulled from where the walker stands with the full 0.9 m clearance square, which a body against a prop always breaks, so the first stop was its own tile's centre: 0.5 m back, under a Guard standing there (medium 718629668 caught: a Worker at (66.30, 16.04) beside a prop, a Guard in cover at (66.54, 16.70)).
5. **One giving way, stopped short of its spot in the other's way, was waited for.** Three Guards spawned in a one-wide lane at a gap (large 395627976 quiet, (59, 0)): the one giving way, blocked on the way to its spot, waits where it stands (by design), which was the gap's mouth; the others treated it as giving way and waited for it, 5 s.
6. **A queue behind one that will not move.** A walker behind another walking the same way that is itself stuck saw a walking pair and ran the head-on rules (large 673802884 caught: three Workers running north in a corridor behind a Guard fighting).
7. **Ways round that got nowhere.** Two walkers each going where the other stands (medium 971281456 loud, a doorway at (69, 63)): `route_around` shuts the destination under the body, ends the way round on the walker's own tile and appends the destination, so the "way round" led straight back through the body and neither ever gave way.
8. **A Worker in the way of a Guard walking to cover.** The two went round each other, each into the other's way, in a 3-wide corridor (medium 718629668 caught, (66, 27)); and with the Worker standing still, a Guard in a fight with no way round never asked it to make way.
9. **A run to hide pressed 30 s at a stalled tile.** Stalled with no corner underfoot, a runner kept running at a tile a working Worker stood on (large 673802884 caught) or past a corner it could not get by, until `RUN_GIVE_UP`; a run given up behind a crew member restarted next frame (ignoring `BLOCKED_PAUSE`) and in a straight line to the tile (large 153407904 loud).
10. **No route to a destination in a doorway.** A doorway tile is in no Room, so the door graph (`ShipNavigator.waypoint_tiles`) returns nothing for it, and `_repath_to` walked the bare point. Found on the fresh-seed check (seed 845239490, medium 750825199 loud): a Guard searching where the Pirate was last seen, a doorway tile two Rooms off at (62.94, 19.23), walked straight at it from (68.39, 18.59) and pressed into the wall for the rest of the Raid.

## Fix

- `scripts/crew/crew.gd`: `_job_spot` keeps where a walk to a Job ends (`_start_job`, `make_way_for`); the pushed-off branch walks on to it by `_repath_to`. `_give_up_walk` on routine moves on to the next Job only after standing `BLOCKED_PAUSE` (WAITING). `_watch_progress` re-routes again, with nobody within `GIVE_WAY_FAR` ahead, whenever the leg to its next point is not clear of the hull and props at `CrewPaths.SCRAPE` and the new route's first leg is. `_get_past`: a walker behind one giving way that stands still in its way steps aside itself and the other walks on (`_step_aside`, split out); one walking the same way and stuck itself 1 s (`_pinned_for`, `_heading`) counts as standing still; a Guard in a fight asks a crew member standing still to make way; of a walking pair one out of the fight and one in it, the one out of it acts (`_acts_first`, `_fighting`) and steps off the other's way rather than go round.
- `scripts/crew/crew.gd`: `_waypoints` reaches a destination in a doorway through whichever Room tile beside it gives the shorter route (the start-in-a-doorway case already did this); the old body is `_waypoints_to`.
- `scripts/crew/crew_paths.gd`: `clear` takes a clearance; `SCRAPE` (0.3 m half-width) is the thin test; `_round` pulls its first leg from where the walker stands at `SCRAPE`. `route_around` rejects a way round that takes the walker no more than `GETS_ON` (0.5 m) from where it stands.
- `scripts/crew/crew_hiding.gd`: stalled with no corner underfoot and not giving way, a runner gives its tile up for the next best; a run given up stands its `BLOCKED_PAUSE` out; one pushed off its end goes on by `_repath_to`, not a straight line.
- `scripts/crew/CREW_AI.md` ("Getting about", "Workers: running and hiding") updated.

## Acceptance criteria

- [x] (agent) Each stuck cause reproduced, explained and fixed at the cause, the invariant not loosened and no check weakened.
- [x] (agent) A regression check per fix in `crew`, failing without it.
- [x] (agent) `only=raid_smoke seed=641152174` passes; `only=crew` passes.
- [ ] (agent) `only=raid_smoke` passes on a fresh seed: seed 845239490 failed once (cause 10), was fixed and passes on replay; a third fresh seed, 238880540, fails (see What remains).
- [x] (agent) `_check_time_to_die` medians unchanged.

## Evidence

- Reproduction: traces (not committed) on every narrowed and full replay named under Causes; each cause's crew, positions, paths and the one in its way are quoted there.
- Regression checks, `tests/test_crew.gd::_check_walks_unstuck` (10 checks: the wander, the wall re-route, the prop-hugging route, the gap's mouth, the routine give-up pause, the queue, the swap, the fight make-way, the Worker clearing for a Guard to cover, the doorway destination) and `::_check_hide_stalled` (2 checks: the stalled run, the given-up run's pause and route). Each was mutated back to the old code one at a time in a throwaway runner that builds only the rigs they use, and each failed, for example `FAIL unstuck: at the end of a wander (true), its Job's spot in a crate, it walks on [(402.5, 0.0, 4.5)]`, `FAIL unstuck: going where another stands, its way round is [(3.5, 0.0, 10.5), (4.5, 0.0, 11.0)], which gets it nowhere`, `FAIL hide stalled: ran true for (4000, 11), still for 2.5 s, and still runs for (4000, 11)`, `FAIL unstuck: the way from one Room to a doorway two Rooms off is [], not through the Rooms between`.
- `tests/run_all.sh only=raid_smoke seed=641152174` (final code): `whole-Raid smoke run: PASS (1285 checks, 391 s)`; endings Loud 15 of 15 extracted with a kill, Caught 15 of 15 down.
- `tests/run_all.sh only=raid_smoke seed=845239490` (the fresh seed that found cause 10, replayed after the fix): `PASS (1285 checks, 344 s)`.
- `tests/run_all.sh only=crew seed=255510525`: `crew awareness: PASS (552 checks, 108 s)`; also passed on seeds 465942598 and 222565390 during the build.
- `_check_time_to_die` medians, every crew run: Pistol 9.56 s, Assault Rifle 5.68 s, unchanged.

## What remains

A third fresh seed, `tests/run_all.sh only=raid_smoke seed=238880540`, fails 2 of 1285 checks on the final code, both the stuck invariant: `large seed 399544609 caught: a Worker (PATROL) ... at (56, 128), pressed against a prop (prop_engine_console_3d at (55, 127))` and `medium seed 510307164 quiet: a Worker (PATROL) ... at (54, 58), pressed against a body (crew: Worker PATROL, still, job WAITING)`. Both were traced:
- (56, 128): the re-route of cause 3 is refused because its first leg fails the thin test from where the Worker stands: its centre is 0.30 m off the engine console's tile (prop boxes sit inside their tiles) and `SCRAPE` is 0.3 m, so the square touches the console's tile.
- (54, 58): a Worker in a one-tile pocket at its Job's spot, another at the mouth going to that spot. With its own tile shut round the body, `route_around` starts from the nearest open tile, two rows up past a row of props, and its untested first leg runs through them; both "go round", neither gives way.
Fixing both (`SCRAPE` 0.25 m; `route_around` testing its first leg at `SCRAPE` on the bare grid) made each Raid pass narrowed, and a check for the pocket failed without it, but the full runs then failed on seed 641152174 again (the three Guards at the gap, cause 5), on 845239490 and on a fresh seed, so both changes were taken out. What is left is the long tail of crowd cases, each needing its own trace. A full sweep shows about one or two stuck Raids per 45. Next: replay seed 238880540 with the trace, and find out why the first-leg test un-fixed cause 5 before putting it back.

## Owed to playtest

None: no `(human)` criteria.

## Comments

2026-11-26: the Loud "extracted with a kill" 10 of 15 and Caught down 13 of 15 on the failing run were the stuck Raids themselves: a Raid that fails any check counts as "failed" and towards no floor (`tests/test_raid_smoke.gd`, the ending tally), and the 5 Loud and 2 Caught "failed" endings were exactly the 7 stuck-crew failures. Not the bind step, and nothing else wrong.
