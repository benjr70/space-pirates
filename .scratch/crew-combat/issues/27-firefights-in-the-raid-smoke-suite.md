Status: resolved
Blocked by: 21, 24

# Firefights in the raid smoke suite

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 13 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Testing Decisions" and `issues/14`.

- The raid smoke suite's scripted Raids check on every ship, for the whole Raid: no Guard in a fight stands in the open, fighting, for more than 3 s while a valid cover spot was in its reach; no crew member is stuck (trying to walk and moving under 0.3 m in 5 s); never more than two Guards aiming true; no Worker fires; no Bound Worker moves.
- Its scripted Pirate should meet Workers as the Raids already meet crew; add a script that aims at a cornered Worker and binds it, if no existing script would reach one.
- A failure prints the replay command as the suite does today.
- Add the invariants to the suite and coverage tables of `docs/agents/validation.md`.

## Acceptance criteria

- [x] (agent) `tests/run_all.sh only=raid_smoke seeds=20` passes with the new invariants reported in its check count.
- [x] (agent) With the fair-walk rule switched off for one run (a mutation), the cover invariant or a cover check fails on at least one seed, showing the invariant bites.
- [x] (agent) At least one scripted Raid in the default sweep binds a Worker, and the suite reports it.
- [ ] (agent) `tests/run_all.sh` passes, and the smoke suite takes no more than 20% longer than before this ticket.

## Comments

Built 2026-11-26 (build order 13). Not resolved: the new "no crew member stuck" invariant fails on some Raids of every sweep tried, from crew walking problems that predate this spec (see Findings). Left `Status: ready-for-agent`.

**What was built.** `tests/test_raid_smoke.gd`:
- `_open_with_cover`: a Guard in `CrewCover.Mode.OPEN` (not `_open_reload`) while `CrewCover.find(0)` has returned a spot, looked for every 0.5 s, for more than 3 s fails the Raid. "Valid cover spot in its reach" is read as the spot the Guard's own rules would take (hidden crouched, a peek, a fair walk within `SEARCH_RADIUS * WALK_REACH`). Reloading in the open is left out: it is not fighting, and ticket 17 has it reload where it stands.
- `_check_invariants` asks `CrewFire.of(player).update()` at the start of every frame and fails on more than two `holders`; `_on_shot` fails on any bolt with a Worker as its shooter; a Bound Worker moving 0.05 m from where it was first seen Bound fails.
- `_stuck_walking`: the 0.3 m in 5 s rule (a second standing still restarts it) now runs for every crew member in every state, not only Guards in a cover fight. The 1 m / 40 s Job rule is kept beside it.
- Loud gains `_tie_up_one` after its stalk, before looting: up to 30 s going after the nearest hiding or surrendered Worker (else the nearest Worker), shooting no Worker but a runner, crosshair on a hiding one in reach until it surrenders, then `_bind` walks to 1.4 m and holds the interact key. Bound Workers are never targets and never quarry.
- A `firefights:` line prints the most Guards seen aiming true at once and every Raid that bound a Worker; a full sweep fails with no bind.
- Failure lines for stuck crew now say what the crew body pressed against is doing.

**Game change (`scripts/crew/crew.gd`, `_get_past` / new `_give_up_walk`).** The first two stuck findings were clear and small, so they are fixed: a walker out of a fight blocked by a crew member standing still that cannot make way (a Worker working at a prop at the end of a one-wide lane) gave up only when the blocker was in a fight; now it gives up for any still blocker, and also when a way round was already taken (`_stuck_tries >= GIVE_WAY_LOOK_FURTHER`) and it is still stuck. On routine it moves on to its next Job; hunting behind a partner fighting him it enters COVER where it stands; otherwise it stands `BLOCKED_PAUSE`. `crew` passes on it (535 checks, seed 196533784). `CREW_AI.md` updated.

**Findings (unfixed, game side).** On run seed 641152174 seven Raids fail "tried to walk 5 s without moving 0.3 m": crew pressed against a wall corner (Walls GridMap) while running to hide or walking a routine, against a crate, and two walking crew pressing into each other (Guard PATROL vs Guard PATROL, Worker PATROL vs Guard SEARCH). One replayed with tracing (`seed=1111 class=large`, ship 173938916 loud, before the last bot change): a COWER Worker running to hide stood with zero velocity at a wall corner at (67, 42) for 5+ s with a path whose next point lay diagonally past a doorway jamb; `_watch_progress` found no crew in the way and no clear sidestep, and `CrewHiding` rescues it only at `RUN_GIVE_UP` (30 s). These are routing and give-way limits from before this spec (the old 40 s Job rule hid them); a fix is in `CrewPaths.route`/`_watch_progress` and is more than this ticket should take on. The invariant is not loosened.

**Timing.** Seed 1111, code before the ticket: 1104 checks, 195 s. With the invariants and the first (stalk-only) bind script: 1285 checks, 188 to 202 s (three runs). With the final `_tie_up_one`, seed 641152174 took 344 s (seed 641152174 was not measured on the old code, and failing Raids and Alarms change the run's length), so the 20% line is not shown for the final code.

## Evidence

- `seeds=20` passes: not met. `tests/run_all.sh only=raid_smoke seed=641152174` (final code): `FAILED 7 of 1285 checks`, all seven the stuck-walking invariant (Findings). Not run with `seeds=20` (light validation).
- Fair-walk mutation: `CrewCover.fair_walk` forced to `fair = false`; `tests/run_all.sh only=crew seed=196533784`: `FAIL flanked: seen crouched from (540, 5), the Guard left (543, 8) for a hidden tile after -1.00 s ... want within 2 s` and `FAIL flanked: the walk to its next spot` (`tests/test_crew.gd::_check_flanked_and_closed_on`), `FAILED 2 of 535 checks`. The smoke run on seed 1111 under the mutation showed no open-fight failure: the smoke invariant asks `CrewCover.find`, which the mutation also loosens, so it cannot bite on this mutation; the cover check does. Reverted, and `crew` passes unmutated.
- Binds a Worker: `tests/test_raid_smoke.gd::_tie_up_one` / `_bind`, reported by the `firefights:` line and checked by the full-sweep bind check in `_check_floors`. `tests/run_all.sh only=raid_smoke seed=641152174`: `firefights: at most 2 Guards aimed true in one frame; 14 Raids bound a Worker: small seed 506148488 loud (1); ...` (14 of 15 Loud Raids).
- `tests/run_all.sh` passes and the smoke run within 20%: awaits the final verification; also not met while the stuck findings stand, and the timing is not shown for the final code (see Timing).

## Owed to playtest

(none: this ticket has no `(human)` lines)


- Final verification, 2026-11-26, by the coordinator on the whole branch at `2f70b4d` (after the two stuck-crew fix rounds, `.scratch/raid-smoke-bugs/issues/12-crew-pinned-by-their-own-walking-rules.md`):
  - `tests/run_all.sh only=raid_smoke seed=166163022 seeds=20`: PASS, 5087 checks, 180 Raids, none failed, 1279 s (run by the fix builder on the final code). The same seed had failed 4 checks before the second fix round. First line ticked.
  - `tests/run_all.sh`: PASS, seed 21166296, every suite (static 182, generator 358259, layouts 252, ship_3d 3733, pirate 2402, crew 555, sandbox 537, attachments 1674, raid_smoke 1285), 493 s.
  - Timing half of the last line is NOT met: the smoke suite took 307 s in that gate (327 s in the gate before it) against 195 s before this ticket on seed 1111, about 57% longer, not 20%. The line stays unticked and the ticket stays `ready-for-agent` until the user rules: accept the longer run, or trim the suite.

- Closed 2026-11-26 at the user's close-out of the spec, with the last line still unticked: the gate passed (above), but the smoke suite runs about 57% longer than before the ticket, not within 20%. The user was told and did not ask for it trimmed.
