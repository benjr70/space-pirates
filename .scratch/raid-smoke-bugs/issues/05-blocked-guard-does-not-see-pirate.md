Status: resolved
Blocked by: none

# A blocked crew member walks into the Pirate without seeing him

## Parent

Found on 2026-11-22 by the whole-Raid smoke run (`.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Not yet confirmed in a play session.

## What is wrong

A patrolling Guard pressed against the standing Pirate for 40 s with Awareness 0. Its facing stayed 90 degrees off its walking direction, because facing is not updated while it cannot move, so the Pirate was outside its cone at 0.7 m.

Replay: `tests/run_all.sh only=raid_smoke seed=21 seeds=10 class=large ship=943549193 script=caught`

## Acceptance criteria

- [x] (agent) A crew member blocked by the Pirate's body faces its direction of travel (or otherwise notices him) within a stated time; asserted in `tests/test_crew.gd`.
- [x] (agent) The replay above passes (it fails today on the stuck invariant).

## Evidence

- Root cause confirmed (debug print in the replay): the Guard set off for a new Job already pressed against the Pirate, so `move_and_slide` left its velocity at exactly zero from the first step; `_face` only turned toward the velocity, so its facing stayed where it was, 92° off its path, with the Pirate (in line with its path) outside the cone at 0.7 m. A Guard that was already moving when it hit him did turn, which is why the first draft of the check passed. Fix: `crew.gd::_face` now looks toward the next path point when it is trying to walk but not moving.
- Stated time: faces its direction of travel within 0.5 s and spots him within 1 s. `tests/test_crew.gd::_check_blocked_by_pirate`: a Guard facing 90° off, capsules touching the standing Pirate, path through him; asserts facing within 26° of its way in ≤ 0.5 s and Awareness 1 within 1 s in all. Before the fix: `FAIL  blocked: a Guard walking into the Pirate turned to its way after -1.00 s, want within 0.5 s` and `... spotted him after -2.00 s, want within 1 s`. After: PASS. Recorded in `scripts/crew/CREW_AI.md` (end of States).
- Replay: `tests/run_all.sh only=raid_smoke seed=21 seeds=10 class=large ship=943549193 script=caught` failed before (`a Guard posted in Room 10 (quarters) walked to a Job without moving 1 m for 40 s ... pressed against a body (the Pirate)`); after: `PASS  8 checks`, also with `CREW_STEERING_BUG_IS_NOTE` false.

## Owed to playtest

None: no `(human)` criteria.

## Comments

2026-11-22: fixed by a subagent, test-first. The orchestrating session re-ran the full gate after the smoke suite was hardened (all 7 suites PASS, 149 s); reintroducing this bug was shown to fail the gate (mutation table in `.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Play session owed.
