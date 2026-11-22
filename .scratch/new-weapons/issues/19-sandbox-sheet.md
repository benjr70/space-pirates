Status: resolved
Blocked by: 18

# The Sandbox sheet: in-Raid sheet, Sandbox resource and docs/sandbox.md

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 3 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Sandbox sheet" section and `issues/04-master-weapon-sheet.md`. The throwaway prototype on branch `prototype/sandbox-sheet` shows the shape; rewrite it, do not promote it.

- A Sandbox resource holding Pirate Health, crew Health and Melee damage, read by the Pirate and crew at spawn in place of the scene values.
- The in-Raid sheet: F1 during a Raid pauses it and opens a table with weapons as columns and Weapon Profile attributes as rows, grouped as the Profile groups them, plus a Health table. A change applies live. Cells that differ from disk are marked and show the disk value. Save writes the `.tres` files; Revert restores them. Debug builds only.
- Derived, read-only rows: reach, damage per shot, shots to kill crew, seconds to kill crew, shots per second.
- Model, poses, clip names and sounds are shown read-only.
- `docs/sandbox.md`: every row as Markdown tables, rewritten on Save, and a check in the test suite that fails when it is stale against the resources.

Gunnery rows arrive with the crew ticket, and each later ticket adds the rows for its own fields.

## Acceptance criteria

- [x] F1 opens and closes the sheet in a Raid; the Raid is paused while it is open.
- [x] Changing Pistol damage in the sheet changes the next shot without a restart.
- [x] Save rewrites the weapon and Sandbox resources and `docs/sandbox.md`; Revert undoes unsaved changes.
- [x] Editing a `.tres` by hand without regenerating makes the stale check fail.
- [x] The sheet is absent from an exported build.
- [x] `tests/run_all.sh` passes.

## Comments

Build note (2026-11-22): built on `new-weapons`.

- `Sandbox` resource (`scripts/sandbox/sandbox.gd`, `resources/sandbox.tres`): `pirate_health` 150, `crew_health` 100, `melee_damage` 75. The Pirate and crew take Health from it in `_ready` via `apply_sandbox()`; the `max_health` overrides are gone from `player_3d.tscn` and `crew_3d.tscn`. The Pirate's `melee_damage` export is gone; Melee reads `sandbox.melee_damage` live.
- `SheetTable` (`scripts/sandbox/sheet_table.gd`): generic table, a Resource per column, rows from the script's exported properties grouped by `@export_group`; numbers and switches editable, everything else read-only; `add_derived()` rows under "Derived"; disk values loaded apart from the cache; `set_value`, `is_changed`, `revert`, `save`, `to_markdown`.
- `SandboxSheet` (`scripts/sandbox/sandbox_sheet.gd`): the Weapons table (with derived reach, damage per shot, shots and seconds to kill crew, shots per second) and the Health and Melee table, with the Melee from-behind note. One generator for `docs/sandbox.md`: Save, `scripts/sandbox/write_sandbox_doc.gd` (headless) and `stale_report()` all call `to_markdown()`. Gunnery (ticket 20) is `add_table(SheetTable.from_resources(...))` in `build()`.
- `SandboxSheetView` (`scripts/sandbox/sandbox_sheet_view.gd`): F1 in a Raid, attached by `main_3d.gd` only when `OS.is_debug_build()`. Esc closes the sheet while it is open, opens the pause menu otherwise; F1 does nothing over the pause menu or after the Raid ends. A Health edit is pushed onto the Pirate (refilled) and the living crew.
- `tests/test_sandbox.gd`, added to `tests/run_all.sh`: stale check on the committed `docs/sandbox.md`; a hand edit to a scratch `.tres` makes it fail; edit, changed-cell marking, Save (resources and Markdown) and Revert on scratch copies under `user://`; read-only rows; in a Raid: Health from the Sandbox, F1/Esc/pause, a Pistol damage cell edit reaching the next shot, the disk value shown, Revert; `attach(host, false)` adds nothing.

Verified headless: `bash tests/run_all.sh` all PASS (sandbox 71 checks). Not verified: the sheet's look on screen (never seen), the Save button against the real `res://` files in a running game (the same `save()` is tested on scratch copies), and an actual exported release build (the gate is `OS.is_debug_build()`; the scripts still ship, the sheet is never created). A first real Save will rewrite the weapon `.tres` files in Godot's own format, dropping lines that equal the script defaults.
