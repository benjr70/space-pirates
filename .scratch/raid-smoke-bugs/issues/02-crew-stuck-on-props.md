Status: resolved
Blocked by: none

# Crew get stuck on props, walls and each other

## Parent

Found on 2026-11-22 by the whole-Raid smoke run (`.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Not yet confirmed in a play session.

## What is wrong

Crew steer straight at each navigator waypoint with no way round props. A crew member can walk into a Breaker crate, a cryopod, a console, a wall corner or another stuck crew member and stay there Job after Job, well past `JOB_GIVE_UP`. Several per large ship.

Replay: `tests/run_all.sh only=raid_smoke seed=1101 class=medium ship=266296903 script=quiet`

## Acceptance criteria

- [x] (agent) `CREW_STEERING_BUG_IS_NOTE` is set to false (or removed) in `tests/test_raid_smoke.gd` and the smoke run passes at `seeds=10` on three run seeds: no crew member walking to a Job goes 40 s without moving 1 m.
- [ ] (human) Crew routines look natural in a play session; nobody walks on the spot against furniture.

## Evidence

- Root cause confirmed: `Crew3D._steer` steered straight at each `ShipNavigator` waypoint (doorway centres and seam crossings), and a straight line through a Room can run through a prop; once pressed against one, nothing changed the path, so the next Job from the same spot was usually blocked too. Also confirmed: two crew, or a crew member and the Pirate, could block each other head-on with nothing to break the deadlock.
- Fix: new `scripts/crew/crew_paths.gd` (`CrewPaths`). It builds one walking grid per layout (one cell per tile: Room floor plus unlocked doorways, minus every prop's `Interiors.footprint`), made from the layout data the generator already writes and cached on the layout, so there is no second source of truth and nothing is read from the built scene. `Crew3D._repath_to`, `_route_by_pod` and `_try_flank` pass the navigator route through `CrewPaths.route`: a leg whose 0.9 m-wide swept square touches only open tiles stays straight; otherwise it becomes an A* path over the grid, string-pulled. A destination inside a prop ends on the nearest open tile; a boxed-in seam crossing is skipped; a way round through a Room other than the leg's own is not taken (so a flank still avoids the Pirate's Room). Fallback (`Crew3D._watch_progress`): trying to walk but moving under 0.3 m in 1 s, it re-routes from where it stands; stuck again, it steps 1 m aside onto open floor, alternating sides, and walks on. `JOB_GIVE_UP` (30 s) still drops a Job it cannot reach. Recorded in `scripts/crew/CREW_AI.md` ("Getting about"). No generator or prop placement change.
- `tests/test_crew.gd::_check_round_props`: a ten-tile Room with a bar of props (crate, three-tile console, crate) across its middle; a crew member walking straight across it, from 2 m in front and from pressed against the console, must arrive within 8 s (`ROUND_PROPS_TIME`). Before: `FAIL  steering: from (404.5, 1.5) across a bar of props took -1.0 s (stood at (404.5, 0.000875, 3.698802))` (pressed against the console for 10 s), and the same from (403.5, 3.4). After: PASS.
- `tests/test_crew.gd::_check_unstick`: walking head-on into a crew member standing in its way (a body no route knows of), it arrives 3 m beyond within 6 s (`UNSTICK_TIME`). Before: `FAIL  steering: walking head-on into a crew member standing in its way took -1.0 s (stood at (3.999993, 0.000963, 18.20151))`. After: PASS.
- Replays: `tests/run_all.sh only=raid_smoke seed=1101 class=medium ship=266296903 script=quiet` and `seed=3303 class=small ship=467636757 script=quiet` print no stuck NOTE or stuck failure now. The 3303 replay passes. The 1101 replay now fails because the Quiet bot loses on both draws (the Alarm raised, 9 of 16 crew down), not because anyone is stuck.
- Criterion **not ticked**. `CREW_STEERING_BUG_IS_NOTE` is false. Across three `seeds=10` sweeps no crew member got stuck (0 stuck failures, 0 stuck NOTEs in 270 Raids), but two of the three sweeps did not pass, for reasons other than steering:
  - `tests/run_all.sh only=raid_smoke seeds=10 seed=2222`: PASS (995 checks).
  - `seed=1111`: FAIL, 88/90 Raids. One Raid is `large 420601337 quiet` (the Alarm raised on both draws; it fails the same way on the pre-fix crew code). The other is `large 634657355 quiet`: "searching the Container took nothing in 10 s (prompt '')", with the bot stopped 1.96 m from the Container (reach 1.8) and no crew within 2.5 m. That is a test-bot issue, no longer hidden by the old door-prompt fallback.
  - `seed=3333`: FAIL, 88/90 Raids. `large 124144911` quiet and loud: the bot went down to three Guards fighting it in one Room, on both draws, every invariant holding. On the pre-fix crew code both Raids passed, with 4 and 6 crew stuck there for good.
- Criterion now met (2026-11-22, smoke-gate hardening). `CREW_STEERING_BUG_IS_NOTE` is removed from `tests/test_raid_smoke.gd`: any crew member walking to a Job (on routine, or sweeping under the Alarm) that goes `STUCK_LIMIT` (40 s) without moving 1 m fails its Raid, whatever it is pressed against. The two non-steering failures above are gone: the bot's walk now re-plans when a route ends short of its goal and closes the last stretch to a Container (`_walk_to`, `_search`), so `large 634657355 quiet` passes; and the verdict no longer asks the bot to win (an Alarm or a Pirate shot down is a legitimate ending, judged for consistency), so `large 420601337 quiet` and `large 124144911` pass. On the final suite: `tests/run_all.sh only=raid_smoke seeds=10 seed=1111` PASS (1833 checks), `seed=2222` PASS (1832), `seed=3333` PASS (1833), plus ten full gates on rolled seeds all PASS (seeds and times in `.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Mutation proof: with `CrewPaths.route` returning its points unchanged, the default smoke run fails on run seeds 101 and 202 (`FAIL  large seed 711022607 loud: a Guard posted in Room 12 (armory) walked to a Job without moving 1 m for 40 s ... pressed against a prop (prop_crate_3d at (80, 53))`; `small seed 590716357` quiet and loud the same against a crate and a console); restored byte-identical (md5).
- Still open, not steering round props: two living crew can block each other (head-on in a 2-wide doorway, or one stood in the other's way, the sidestep oscillating) and neither gets past for 40 s. Seen in 4 of about 2200 Raids, all large-ship Loud, so the gate fails on it about one run in twelve. Replays: `tests/run_all.sh only=raid_smoke seed=4444 seeds=10 class=large ship=739174378 script=loud` (two Guards in the doorway at tile (55, 90)), `seed=6666 seeds=10 class=large ship=803174260 script=loud`, `seed=9999 seeds=10 class=large ship=599767254 script=loud` (`pressed against nothing`, 39 unstick tries, another crew member 0.7 m off). Worth its own ticket.

## Owed to playtest

- (human) Crew routines look natural in a play session; nobody walks on the spot against furniture.

## Comments

2026-11-22: fixed by a subagent, test-first. The orchestrating session re-ran the full gate after the smoke suite was hardened (all 7 suites PASS, 149 s); reintroducing this bug was shown to fail the gate (mutation table in `.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Play session owed.
Crew blocking each other (as opposed to props and walls) is not fully fixed: see `06-crew-block-each-other.md`.
