Status: resolved
Blocked by: none

# A kill in the step the pod casts off in is not counted

## Parent

Found by the whole-Raid smoke run's wide sweep (`tests/run_all.sh only=raid_smoke seeds=20`), on the `crew-combat` branch, 2026-11-25. Recorded earlier on `cbc2ac2` in `.scratch/weapon-attachments/issues/19-attachment-models-in-the-viewmodel.md` ("6 kills with 7 crew down", Quiet), probably the same bug (not replayed). Not confirmed in a play session.

## What was seen

One Quiet Raid in a sweep failed the ending check "the ledger's kills equal the crew down":

- sweep seed 888720613: `medium seed 497549325 quiet: the ledger counts 1 kills with 2 crew down  [t=24.9 s]`
- sweep seed 188082639: `small seed 360261566 quiet: the ledger counts 3 kills with 4 crew down  [t=14.3 s]`

Both Raids pass when replayed alone (`class=... ship=... script=quiet`).

## Cause

A game bug, not a test artefact. The Pirate's kill is counted through his hit report (`hit_landed` into `RaidLedger.record_kill` in `scripts/main_3d.gd`). Since the Shotgun (`64170a1`) that report waits `SHOT_REPORT_DELAY` (1.5 physics steps) after a shot's first strike, so late pellets join it. Going down already reported every waiting hit before settling the ledger (`08833ed`), but the pod casting off did not: `Extraction` reaches zero in `_process`, `main_3d.gd` calls `ledger.settle_extracted()` at once, and a crew member felled by a bolt in the physics step of that same frame had its report still waiting. When the timer fired, the ledger was settled and `record_kill` dropped it. Walking away to the menu from the pause menu had the same race.

What a player would see: he fires during the extraction countdown and drops a crew member in its last instant. The EXTRACTED screen counts the crew member down ("2 of 14 crew down") but not the kill ("1 kill"), and he banks 100 XP (150 if unaware) less than he earned.

Why only inside a sweep: the smoke bot fires at threats while it waits out the countdown (`_extract`). Measured (Evidence): in a Raid started mid-sweep, physics-side events (bolts, deaths) land one frame earlier relative to the countdown, which runs in `_process`, than in the same Raid replayed alone. Replayed alone, the extraction ends on the same Raid frame but the last kill would land one frame later, after the Raid is over. The likely mechanism, not traced further: a Raid mid-sweep is added from a coroutine resumed by `physics_frame`, between one frame's physics and process steps, while a Raid alone is added from `_initialize` before the first frame. Nothing found leaking between Raids: the miscount is the race, and the sweep only puts a kill on the last frame.

## Fix

`scripts/player_3d.gd`: the loop in `_on_died` that reports every waiting hit at once is now the public `report_hits_now()`. `scripts/main_3d.gd` calls it before `settle_extracted()` when the pod casts off, and before `settle_lost()` when the pause menu's Main Menu walks away. Going down calls it as before. The timers' later reports find nothing to do (reports are keyed by id). Written up in `scripts/crew/CREW_AI.md` (Stealth XP) and `docs/agents/validation.md` (Smoke run, Coverage).

## Acceptance criteria

- [x] (agent) The exact crew member that went down uncounted, what killed it and the frame are identified in the failing sweeps.
- [x] (agent) A crew member felled by the Pirate's bolt in the step the pod casts off in counts as 1 kill and its kill XP is banked and shown on the EXTRACTED tally; asserted in `tests/raid_checks.gd` (in `ship_3d`), failing without the fix.
- [x] (agent) Both sweeps pass on replay: `tests/run_all.sh only=raid_smoke seeds=20 seed=888720613` and `seed=188082639`.
- [x] (agent) `tests/run_all.sh only=raid_smoke seeds=20` passes three times on fresh seeds.
- [x] (agent) The full gate `tests/run_all.sh` passes twice.

## Evidence

- Uncounted crew member, killer and frame: both sweeps replayed with temporary tagged prints in `Crew3D.take_damage` (the killing blow and its `from`), the `hit_landed` handler and the extracted handler in `main_3d.gd`, and the smoke run's `_attempt` and `_check_ending` (removed before commit). Before the fix, without the prints, both sweeps failed deterministically on the same Raid: `medium seed 497549325 quiet: the ledger counts 1 kills with 2 crew down [t=24.9 s]` (`FAILED 1 of 4374 checks`) and `small seed 360261566 quiet: the ledger counts 3 kills with 4 crew down [t=14.3 s]` (`FAILED 1 of 4376 checks`). With the prints:
  - Sweep 888720613, Raid begun on physics frame 73502: crew member id 16860716208942 died on frame 74090 (75 damage from `Player`, melee) and was reported killed that frame. Crew member id 16862293271137 died on frame 74996 to a 25-damage bolt from `Player` (the Pirate of this Raid, in the tree). `_check_ending` ran on frame 74997 with `kills=1`, 14 crew in the group and in the suite's list (no stale crew), and 1 hit report still pending. No `hit_landed` for it before the end.
  - Sweep 188082639, Raid begun on frame 25014: three kills by `Player`'s bolts, each reported a frame later (25802/25803, 25825/25826, 25849/25850). Crew member `Crew` id 6078301476695 died on frame 25872 to a 25-damage bolt from `Player`. The ending on frame 25873 read `kills=3`, 8 crew, 1 report pending.
  - Across all four pre-fix sweeps, no crew member died to anything but the Pirate (a monitor on the debug output for any other `from` found none).
- Alone vs in the sweep (pre-fix code, prints on): `class=small ship=360261566 script=quiet` alone extracted on Raid frame 858 (`extracted frame=858 pending=0`), with its three kills on Raid frames 789, 812 and 836, each one frame later than in the sweep (788, 811, 835). The fourth crew member was never hit: `PASS 26 checks`. `class=medium ship=497549325 script=quiet` alone, with the extraction flush switched off: melee kill on Raid frame 589 (588 in the sweep), extracted on 1494 (the sweep's ending also came on Raid frame 1495), no second kill, `PASS 26 checks`. So the "passes alone" report holds. The countdown ends on the same Raid frame and the physics side is shifted one frame.
- Regression check: `tests/raid_checks.gd::_check_kill_as_he_extracts` (run by `ship_3d`). It boards the Raid, starts the countdown at the home door, drops a crew member to 1 health, fires the Pirate's gun (`fire()`), strikes that bolt on the crew member, then runs the countdown out in the same step. It asserts `ledger.kills == 1`, the XP banked equals kill XP plus the extraction and Ghost bonuses with kill XP above zero, and the EXTRACTED tally reads "(1 kill". Without the fix: `FAIL extract: a kill in the step the pod cast off in counted 0 kills, want 1`, the XP check failing (350 banked, no kill XP) and `FAIL extract: the tally does not show the kill in the last step: ... 1 of 11 crew down / +350 XP (0 kills, 200 extraction, 150 Ghost) ...`, `FAILED 3 of 3720 checks`. With the fix: `3D ship and built sample: PASS (3720 checks)`.
- Sweep replays on the final code: `tests/run_all.sh only=raid_smoke seeds=20 seed=888720613`: `PASS (4374 checks, 437 s)`, Ghost 58/60, Loud with a kill 58/60, Loot 117/120. `seed=188082639`: `PASS (4376 checks, 459 s)`, 59/60, 58/60, 118/120.
- Fresh `seeds=20` sweeps on the final code: seed 696536360 `PASS (4389 checks, 429 s)`; seed 276692000 `PASS (4383 checks, 389 s)`; seed 971117075 `PASS (4389 checks, 414 s)`.
- Full gate on the final code: seed 33805379, every suite PASS (static 172, generator 357186, layouts 252, ship_3d 3720, pirate 2402, crew 245, sandbox 490, attachments 1674, raid_smoke 1098), 221 s (run beside two sweeps). Seed 658066722, every suite PASS (raid_smoke 1104 checks), 196 s.

## Owed to playtest

None: no `(human)` criteria.

## Comments

2026-11-25: diagnosed and fixed by a subagent on `crew-combat`. Whether ticket 15's per-Guard guns (`55ee108`) made the failure more frequent was not measured.
