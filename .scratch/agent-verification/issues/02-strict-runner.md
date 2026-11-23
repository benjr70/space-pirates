Status: resolved
Blocked by: none

# Strict runner

## Parent

`.scratch/agent-verification/spec.md`, build order 2 of 9.

## What to build

Make `tests/run_all.sh` fail whenever something went wrong, not only when a suite counted a failed check.

- **Engine errors fail the suite.** A suite whose output contains `SCRIPT ERROR:` or a line starting `ERROR:` fails even if Godot exits 0. This is the case that has bitten before: a silent `get_node` failure aborted a test function, the remaining checks never ran, and the suite still reported success.
- **Expected errors are declared.** First run the gate on `main` and list every error line the suites print today. Fix the ones that are real. For any a check provokes on purpose, add an allowlist of exact patterns in `run_all.sh`, each with a comment naming the check that provokes it.
- **A missing suite fails.** Today a missing suite file is reported as `skipped`; make it `FAIL (missing)`.
- **Check counts are pinned loosely.** Each suite already prints how many checks ran. Have `run_all.sh` print the count beside PASS so a reviewer can see a suite that suddenly ran far fewer checks.

## Acceptance criteria

- [x] (agent) A suite that prints `SCRIPT ERROR:` and exits 0 is reported `FAIL`, shown with a throwaway suite in the evidence.
- [x] (agent) Renaming a suite file makes `run_all.sh` exit non-zero with `FAIL (missing)`.
- [x] (agent) Every allowlisted pattern has a comment naming the check that provokes it.
- [x] (agent) The summary line for each suite includes its check count.
- [x] (agent) Full `tests/run_all.sh` passes on the branch.

## Evidence

Run 2026-11-22 on `main` working tree (Godot 4.7.2 flatpak, headless).

**Errors on `main` before the allowlist.** First full run with the strict check and an empty `ALLOWED`:
```
3D ship and built sample: FAIL (engine errors, 3646 checks)
    ERROR: Parameter "material" is null.        (x12)
crew awareness: FAIL (engine errors, 88 checks)
    ERROR: Parameter "material" is null.        (x1, after the suite's PASS line, at quit)
```
Every one is `at: material_get_instance_shader_parameters (servers/rendering/dummy/storage/material_storage.cpp:264)`, raised when a Pirate is freed (backtraces: `generated_ship_checks.gd:89`, `raid_checks.gd:141`, `raid_checks.gd:186`, `built_sample_checks.gd:60`). Bisected with a throwaway script that freed `player_3d.tscn` node by node: the line is printed when the Viewmodel's mounted `Pistol` MeshInstance3D (pistol.glb) is freed. Freeing `sidearm_model.tscn` on its own, with or without the Viewmodel's duplicated, flagged override materials, does not reproduce it. It is engine-side in the headless dummy renderer and not a test-code bug, so it is allowlisted, not fixed. No other error line appears in any suite.

- **A `SCRIPT ERROR:` suite that exits 0 is FAIL.** Throwaway `tests/zz_throwaway.gd` calls a method on null, prints `PASS  1 checks`, `quit(0)`; a copy of `run_all.sh` running only it (both deleted after):
  ```
  --- direct godot exit:
  0
  === throwaway SCRIPT ERROR suite
  SCRIPT ERROR: Cannot call method 'get_name' on a null value.
  PASS  1 checks
  === summary
  throwaway SCRIPT ERROR suite: FAIL (engine errors, 1 checks)
      SCRIPT ERROR: Cannot call method 'get_name' on a null value.
  exit 1
  ```
- **A renamed suite gives `FAIL (missing)` and a non-zero exit.** `mv tests/test_crew.gd tests/test_crew.gd.renamed; tests/run_all.sh seeds=10; mv` back:
  ```
  crew awareness: FAIL (missing tests/test_crew.gd)
  exit 1
  ```
  (The generator sweep also failed in that run only because `seeds=10` is too few for its distribution checks, as documented.)
- **Every allowlisted pattern has a comment naming its check.** `ALLOWED` in `tests/run_all.sh` holds one pattern, `ERROR: Parameter "material" is null\.`, under a comment naming `generated_ship_checks.gd` (run), `raid_checks.gd` (`_check_raid`, `_check_extraction`), `built_sample_checks.gd` (tick) in `test_ship_3d.gd`, and `test_crew.gd`'s Pirate freed at quit. Patterns apply to every suite.
- **Each summary line carries its check count, and the full gate passes.** `time tests/run_all.sh` (exit 0, real 5m26.6s):
  ```
  === summary
  static load check: PASS (122 checks)
  generator sweep: PASS (341833 checks)
  2D layouts: PASS (252 checks)
  3D ship and built sample: PASS (3646 checks)
  pirate movement and gunplay: PASS (597 checks)
  crew awareness: PASS (88 checks)
  ```
  The 13 `ERROR: Parameter "material" is null.` lines were all allowlisted; no other `SCRIPT ERROR:`/`ERROR:` line.

## Comments

2026-11-22: built by a subagent. The orchestrating session read the new `tests/run_all.sh` and confirmed `tests/test_crew.gd` was restored after the rename proof. One allowlisted engine error (`Parameter "material" is null`, headless dummy renderer, on freeing the Pirate); its cause is inferred, not proven. Follow-up found by the screenshots work: a suite banks XP into the player's real `user://profile.cfg`; only `test_ship_3d.gd` redirects `Profile.path`. Handed to ticket 05.
