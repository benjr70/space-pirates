Status: resolved
Blocked by: none

# A Worker works 1.6 m from its prop

## Parent

Found on 2026-11-22: the crew suite's routines check failed once in a full gate run after `02-crew-stuck-on-props.md` was fixed.

## What is wrong

`tests/test_crew.gd` reported `routines: 6 working samples away from or facing off their prop`: a Worker doing a Job stood 1.6 m from its prop against the check's 1.5 m limit. Suspected, not confirmed: the routing fix ends a Job's route on the nearest open tile rather than at the work spot.

Replay: `tests/run_all.sh only=crew seed=558625915`

## Acceptance criteria

- [x] (agent) The cause is confirmed and recorded in the evidence.
- [x] (agent) A crew member working a Job stands within the existing 1.5 m limit of its prop and faces it; the existing routines check is unchanged and the replay passes.
- [x] (agent) `tests/run_all.sh only=crew` passes on 20 different seeds.

## Evidence

- Cause confirmed (traced on `tests/run_all.sh only=crew seed=558625915`), and it is not the suspected one: the Worker's route did end exactly on its work spot (74.5, 29.5). Another crew member was already working that same spot: two loops can hold the same prop's single spot. The newcomer pressed against it, popped its last waypoint at 0.41 m during a sidestep, and was pushed back by the contact to 0.55 m off the spot (1.55 m from the prop, reported "1.6 m"). It worked from there. A second way to the same symptom showed up during the fix: a way round a body standing on the destination ended beside it. That is fixed too (`CrewPaths.route_around` always ends on the real destination).
- Fix (`scripts/crew/crew.gd`, recorded in `scripts/crew/CREW_AI.md`, Routines): one crew member per work spot. A work Job whose spot another crew member is walking to or working at is skipped for the next (`Crew3D._spot_taken`, used by `_start_job`). With every spot in the loop held, it waits 1–3 s where it is and tries again, rather than wandering its Post and "working" a far-off prop. A crew member asked to make way while working (ticket 06) walks back to its spot before working again. The existing routines check (`tests/test_crew.gd::_check_routines`, 1.5 m and facing 0.8) is unchanged.
- New check `tests/test_crew.gd::_check_shared_work_spot`: two Workers whose loops share one console spot, one already working it. Asserted: they never work it at the same time; the other never stands pressed (within 0.8 m) against the one working it for more than `SHARED_PRESS` = 1 s; every work sample is within 1.5 m of the prop, facing it at 0.8 or more. Before: `FAIL  work spot: a Worker stood pressed against the one working its spot for 4.2 s, want at most 1 s`. After: PASS.
- Replay: `tests/run_all.sh only=crew seed=558625915` PASS (107 checks, 11 s).
- `tests/run_all.sh only=crew` on 20 seeds (101, 202, ..., 2020, steps of 101), final code: 20 of 20 PASS, 107 checks each. An earlier pass found seeds 404 and 1616 failing (a Worker "working" 14 m and 26.9 m from its prop): the all-spots-held fallback wandered the Post. That is why it now waits; both seeds pass, and the full 20 were rerun.

## Owed to playtest

- None: this ticket has no `(human)` criteria.

## Comments

2026-11-22: fixed by a subagent, test-first; 20 consecutive full gate runs passed. The orchestrating session re-ran the full gate afterwards (7 suites PASS, 168 s). Play session owed.
