Status: resolved
Blocked by: none

# Static load check

## Parent

`.scratch/agent-verification/spec.md`, build order 1 of 9.

## What to build

A suite that proves every script, scene and resource in the project loads, so a file no behaviour suite touches cannot be broken silently.

- `tests/test_static.gd` (a `SceneTree` script like the other suites): walk `res://` outside `addons/`, `.godot/` and `tools/`, and `load()` every `.gd`, `.tscn` and `.tres`. A `null` result or a script that fails to compile is a failure, reported with its path. Instantiate each `.tscn` once and free it, so a scene with a broken node path or missing dependency fails too.
- One process for the whole walk. Launching Godot once per file (`--check-only --script <file>`) works but costs a flatpak start for each of ~85 scripts.
- Add it to `tests/run_all.sh` as the first suite, so the cheapest failure shows first.
- Delete `tests/_sights_tmp.gd` (a one-off measuring script committed with the pistol work; nothing references it).
- Document the suite under Gate in `docs/agents/paperclip.md`.

## Acceptance criteria

- [x] (agent) `tests/run_all.sh` runs the static suite first and prints a `PASS`/`FAIL` line for it.
- [x] (agent) A deliberately broken script placed under `scripts/` (parse error) makes the suite fail and names the file; removing it restores the pass.
- [x] (agent) A scene referencing a missing resource makes the suite fail and names the scene.
- [x] (agent) The suite passes on current `main` with no files excluded beyond `addons/`, `.godot/` and `tools/`; any further exclusion is listed in the suite with its reason.
- [x] (agent) `tests/_sights_tmp.gd` and its `.uid` are gone.

## Evidence

Run 2026-11-22 on `main` working tree (Godot 4.7.2 flatpak, headless).

- **Static suite first, with a PASS/FAIL line.** `tests/run_all.sh` (full, 5m27s, exit 0); `run "static load check" tests/test_static.gd` is the first `run` line. Summary:
  ```
  === summary
  static load check: PASS (122 checks)
  generator sweep: PASS (341833 checks)
  ...
  ```
- **Broken script under `scripts/` fails and is named; removing it restores the pass.** Planted `scripts/zz_broken_probe.gd` (`func f(:`), ran `flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_static.gd`, deleted it (and any `.uid`), ran again:
  ```
  SCRIPT ERROR: Parse Error: Expected parameter name.
            at: GDScript::reload (res://scripts/zz_broken_probe.gd:2)
  FAIL  res://scripts/zz_broken_probe.gd: script did not compile
  FAILED  1 of 123 checks
  exit 1
  --- after removing it:
  PASS  122 checks
  exit 0
  ```
- **Scene with a missing resource fails and is named.** Planted `scenes/zz_missing_probe.tscn` with an `ext_resource` to `res://scripts/does_not_exist.gd` on its root node, same command, then deleted it:
  ```
  FAIL  res://scenes/zz_missing_probe.tscn: missing dependency res://scripts/does_not_exist.gd
  FAILED  1 of 123 checks
  exit 1
  ```
- **Passes on current `main` with only the allowed exclusions.** Same command on the clean tree: `PASS  122 checks` in about 2 s, no engine error lines. The walk skips `addons/`, `.godot/`, `tools/` (has `.gdignore`) and hidden directories (`.claude/`, `.scratch/`, `.git/`); the hidden-directory skip is listed in the suite header with its reason (not project content, never scanned by Godot, and `.claude/worktrees/` holds full project copies). 122 matches `find . -path './.*' -prune -o -path ./addons -prune -o -path ./tools -prune -o \( -name '*.gd' -o -name '*.tscn' -o -name '*.tres' \) -print | wc -l`. No script needed excluding: the windowed-only `tests/shots.gd` loads clean headless (`tests/viewmodel_shots.gd` was removed by the screenshots work during this run).
- **`tests/_sights_tmp.gd` and its `.uid` are gone.** `git status --short` shows `D tests/_sights_tmp.gd` and `D tests/_sights_tmp.gd.uid`; `grep -rn _sights_tmp` outside `.scratch/` finds nothing.

## Comments

2026-11-22: built by a subagent. The orchestrating session re-ran `tests/test_static.gd` (`PASS  122 checks`, exit 0) and confirmed no probe files remain in the tree.
