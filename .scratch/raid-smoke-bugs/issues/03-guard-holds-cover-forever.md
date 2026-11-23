Status: resolved
Blocked by: none

# A Guard holds COVER forever

## Parent

Found on 2026-11-22 by the whole-Raid smoke run (`.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Not yet confirmed in a play session.

## What is wrong

`crew.gd::_tick_cover` waits while `_path` is not empty. When the path to the cover point is blocked (by a prop, or the Pirate's body) it never empties and, still seeing the Pirate, the Guard never leaves COVER or fires again.

Replay: `tests/run_all.sh only=raid_smoke seed=1101 class=small ship=84506838 script=caught`

## Acceptance criteria

- [x] (agent) A Guard whose path to cover is blocked leaves COVER within a stated time; asserted in `tests/test_crew.gd` with a blocked cover point.
- [x] (agent) The replay above ends with the Caught Pirate down inside the time budget.

## Evidence

- Root cause confirmed as described: `_tick_cover` returned while `_path` was not empty, and nothing ever emptied a blocked path. Fix: `Crew3D.COVER_GIVE_UP` = 3.0 s; after running for its cover point that long it clears the path and holds where it is, then leaves COVER for FIGHT once its hold and reload are done (`crew.gd::_tick_cover`, `_cover_clock`). Stated time: leaves COVER within 3 s of ducking (3.0 s give-up plus one tick, 3.1 s asserted). Recorded in `scripts/crew/CREW_AI.md` (States, "Cover it cannot reach").
- Blocked cover point: `tests/test_crew.gd::_check_cover_blocked`, which sends a Guard into COVER with its path running straight through a crate the layout does not know of, the Pirate in view 6 m off, and asserts it is in FIGHT within `COVER_GIVE_UP + 0.1` s. Before the fix: `FAIL  cover: a Guard whose way to cover is blocked left COVER after -1.00 s (state 3), want FIGHT within 3.1 s` (still in COVER after 6 s). After: PASS (`tests/run_all.sh only=crew`, seeds 777, 1–9).
- Replay: `tests/run_all.sh only=raid_smoke seed=1101 class=small ship=84506838 script=caught` → `PASS  8 checks` with no COVER NOTE (with `COVER_GIVE_UP` set to 9999 it prints `NOTE ... a Guard held COVER for 8 s, 2.8 m from the Pirate ... never firing`). Caught ends with the Pirate down inside the 150 s budget. Re-run after all four fixes with `CREW_STEERING_BUG_IS_NOTE` false: PASS.

## Owed to playtest

None: no `(human)` criteria.

## Comments

2026-11-22: fixed by a subagent, test-first. The orchestrating session re-ran the full gate after the smoke suite was hardened (all 7 suites PASS, 149 s); reintroducing this bug was shown to fail the gate (mutation table in `.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Play session owed.
