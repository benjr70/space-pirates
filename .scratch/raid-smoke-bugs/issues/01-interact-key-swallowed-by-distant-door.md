Status: resolved
Blocked by: none

# The interact key is swallowed by a Door across the ship

## Parent

Found on 2026-11-22 by the whole-Raid smoke run (`.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Not yet confirmed in a play session.

## What is wrong

`main_3d.gd::_door_prompt` offers the prompt of any Door whose `Door3D.in_reach()` is true, and `in_reach` counts any body in the Door's trigger, crew included. `_interact` then returns early, so while any crew member stands at any Door anywhere on the ship the Pirate cannot search a Container and the HUD shows a Door prompt for a Door tens of metres away. Seen on about half the Quiet and Loud Raids (19 of 45 Raids in one gate run).

Replay: `tests/run_all.sh only=raid_smoke seed=2202 class=small ship=700037802 script=quiet`

## Acceptance criteria

- [x] (agent) A Door prompt is offered only when the Pirate is in that Door's reach; asserted in a suite check with a crew member standing at a distant Door.
- [x] (agent) The `search()` fallback and its NOTE are removed from `tests/test_raid_smoke.gd`, and the smoke run passes with the bot using the interact key only.
- [ ] (human) Searching a Container works in a play session while crew move through Doors elsewhere.

## Evidence

- Door prompt only in the Pirate's own reach: `tests/test_ship_3d.gd::_physics_door_prompt` (phase 8, set up in `_setup_door_prompt`). On generated medium seed 1 it parks one crew member, held still, in the Trigger of the unlocked Door furthest from a Container (over 10 m, asserted; 78 m in the run), and stands the Pirate facing that Container, out of every Door's Trigger (asserted). It asserts the Door does see the crew member (`in_reach()`), that `_door_prompt()` is empty and `_prompt()` is `E — Search`, that pressing the interact key searches the Container and leaves the distant Door as it was, and then, with the Pirate moved 1.4 m from that Door, that `_door_prompt()` and `_prompt()` are the Door's own prompt. Before the fix it failed 3 checks (`a crew member at a Door 78 m away offers its prompt 'E — Open hatch'`, `facing a Container offers 'E — Open hatch', not the search`, `the interact key did not search the Container`); after, `3D ship and built sample: PASS (3680 checks)`. Fix: `Door3D.in_reach_of(body)`, used by `main_3d.gd::_door_prompt` with the Pirate. Full gate on 2026-11-22: every suite PASS except one `crew` failure while another agent was editing the crew suite; its replay (`tests/run_all.sh only=crew seed=247777568`) and two more crew runs passed (91 checks). `tests/shots.sh hud` still shows the game's own `E — Open hatch` prompt at the Boarding Pod's Hatch (`.godot/shots/hud/hud.png`).
- `search()` fallback removed (2026-11-22, smoke-gate hardening): `tests/test_raid_smoke.gd::_search` no longer calls `main.search`, `_foreign_door_prompt` and `DOOR_BUG_PATIENCE` are gone, and the suite prints no `NOTE` lines at all. At a Container in reach (clear of every Door, and the one the key would work) the bot only taps the interact key, and the Raid fails if the HUD does not offer `E — Search` or the key has not searched it in 10 s. `_check_invariants` also fails a Raid on any frame where the HUD offers a Door's prompt with the Pirate in no Door's reach. With `main_3d.gd` put back to `door.in_reach()` (mutation proof, run seeds 101 and 202) every Quiet and Loud Raid but one failed, e.g. `FAIL  small seed 219197912 quiet: the HUD offered 'E — Open hatch' with the Pirate in no Door's reach (t=7.5 s)` and `... loud: facing a Container 1.57 m off, the HUD offers 'E — Close hatch', not 'E — Search'`; restored byte-identical (md5). Passing with the key only: see the sweep evidence in `.scratch/agent-verification/issues/06-whole-raid-smoke-run.md` (Comments, 2026-11-22 hardening entry): the full gate and `tests/run_all.sh only=raid_smoke seeds=10` on run seeds 1111, 2222 and 3333.

## Owed to playtest

- (human) Searching a Container works in a play session while crew move through Doors elsewhere.

## Comments

2026-11-22: fixed by a subagent, test-first. The orchestrating session re-ran the full gate after the smoke suite was hardened (all 7 suites PASS, 149 s); reintroducing this bug was shown to fail the gate (mutation table in `.scratch/agent-verification/issues/06-whole-raid-smoke-run.md`, Comments). Play session owed.
