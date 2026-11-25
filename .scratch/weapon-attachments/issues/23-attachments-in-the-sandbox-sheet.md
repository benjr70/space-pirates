Status: resolved
Blocked by: 17

# Attachments in the Sandbox sheet

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 9 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Sandbox sheet" and `issues/14-sheet-hud-laser-and-reload-sounds.md`.

- A fourth table, "Attachments": a column per Attachment, a row per attribute any Attachment changes, each cell its factor, blank where it changes nothing. Dialled, amber when it differs from disk, saved to the Attachment files, reverted, and written to `docs/sandbox.md` with a check that the doc is not stale, as the other tables are.
- The weapon columns are all four weapons always, whatever is carried.
- For the two carried guns, the Built Weapon's value shown read-only beside the bare one wherever it differs. Not written to the doc.
- A dialled factor or bare number reaches the gun in hand at once: the Built Weapon is rebuilt.
- A debug strip at the top: FIRST and SECOND gun pickers and a picker per Slot under each, offering only what fits. Applied when the sheet closes, ammo refilled. It never writes the saved Loadout.

## Acceptance criteria

- [x] (agent) The Attachments table has fourteen columns and its cells equal the Attachment files' factors; `docs/sandbox.md` has the same table and the stale-doc check covers it.
- [x] (agent) Setting the Suppressor's loudness factor to 0.5 in the sheet makes the carried suppressed gun's loudness 12.0 before the sheet closes; Save writes 0.5 to the Attachment file; Revert restores 0.4.
- [x] (agent) With two guns carried the Weapons table still has four columns.
- [x] (agent) With a Drum fitted, the Assault Rifle's magazine row shows 30 and, beside it, 75.
- [x] (agent) Changing the first gun and a Slot in the debug strip and closing the sheet puts that Built Weapon in hand with a full magazine, and the profile file's Loadout is unchanged.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) The table is readable and a factor is quick to change mid-Raid.

## Evidence

- Attachments table and doc: `tests/test_sandbox.gd::_check_attachments_table` (from `_check_doc_fresh`) asserts `SandboxSheet.from_disk()`'s Attachments table has exactly 14 columns (Combat Scope … Light Stock, by Slot then file), loads every file under `resources/attachments/` apart from the cache and asserts each cell equals that file's factor (within float tolerance) and is blank where the file has none, one row per attribute any file changes, 52 factor cells; `docs/sandbox.md` carries the `## Attachments` heading, the 14-column header, and the Loudness (Suppressor 0.4) and Magazine Size (2.5, 1.5, 0.8) lines. The stale check covers it: `_check_doc_fresh` asserts `stale_report()` is empty against the regenerated doc, and `_check_stale_on_hand_edit` edits the scratch Suppressor's loudness to 0.45 by hand and asserts the report says stale.
- Suppressor at 0.5: `tests/test_sandbox.gd::_check_menu_raid` arms a menu Raid with the Assault Rifle (Suppressor, Drum), opens the sheet, sets the Suppressor's loudness factor through its SpinBox cell to 0.5 and asserts, with the sheet still open, the gun in hand (the same object) is 12.0 loud and the Weapons table shows "12.0" beside the bare 24; Revert then asserts the factor 0.4 and the gun 9.6. `_check_factor_save_revert` (scratch copies) asserts set 0.5 → live 0.5 and marked against disk 0.4, Revert → 0.4, set 0.5 and Save → the file reloaded apart from the cache has loudness 0.5 (projectile speed 0.8, `suppresses`, name kept) and the saved view shows 0.5.
- Four columns with two carried: `tests/test_sandbox.gd::_check_menu_raid` asserts, with the Pirate carrying two Built Weapons, the Weapons table columns are exactly Pistol, Assault Rifle, Shotgun, Marksman Rifle.
- Drum 30 beside 75: `tests/test_sandbox.gd::_check_menu_raid` asserts the Assault Rifle's magazine cell is 30 and `built_shown` beside it is "75"; also nothing beside where built equals bare (damage), on the bare carried Pistol, or on the uncarried Shotgun.
- Debug strip: `tests/test_sandbox.gd::_check_menu_raid` picks Shotgun in the FIRST picker and Short Barrel in its Barrel picker (which offers exactly no Barrel, Long Barrel, Short Barrel; no Magazine picker for the Shotgun), asserts the gun is unchanged while open, closes with F1 and asserts the gun in hand is built from the Shotgun with exactly a Short Barrel, ammo 6 (full; a shot was fired from the rifle first), the Pistol still second, and the profile file's text byte-for-byte unchanged; opening and closing again with no change leaves the same object in hand.
- The gate: `tests/run_all.sh` passed in full, every suite PASS (static 160, generator 341845, layouts 252, ship_3d 3681, pirate 1255, crew 205, sandbox 475, attachments 1674, raid_smoke 1095 checks), `total: 229 s`.

Screenshots (`tests/shots.sh sheet`, new preset, PASS, 3 frames), read against the defect checklist, no overlap or clipping found:
- `.godot/shots/sheet/sheet.png`: the strip (FIRST Assault Rifle, Suppressor, Drum, empty Sight, Underbarrel, Stock; SECOND Pistol), the Weapons table with all four columns on screen and "built 75", "built 2.88", "built 3.68" in green beside the Assault Rifle's magazine and reloads.
- `.godot/shots/sheet/sheet_attachments.png`: the Attachments heading, all 14 columns on screen with wrapped names, factors in their cells, blanks elsewhere.
- `.godot/shots/sheet/sheet_attachments_end.png`: the bottom rows, the Suppressor's Loudness 0.5 in amber with "disk 0.4" under it, the note wrapped inside the screen.

## Owed to playtest

- (human) The table is readable and a factor is quick to change mid-Raid.

## Comments

Built 2026-11-24.

- `SheetTable`: a fourth row kind, FACTOR (one entry of a column's `changes`), built by `SheetTable.from_factors`; `is_cell_editable` (a blank factor cell takes nothing), `value_of(key, resource)`. Edit, amber, Revert and Save go through the same code as other rows; blank cells are blank in the Markdown.
- `SandboxSheet`: `ATTACHMENTS` table (`build(..., attachments)`, `from_disk(..., attachment_files)`, `attachment_paths()` by Slot then file, `all_attachments()`); weapon columns are `all_weapon_paths()` (the Loadout's four), replacing `carried_weapon_paths()`. `carried` (the Built Weapons, set by the view), `built_value(key, column)` (null when equal to bare, not carried, or a read-only row) and `rebuild_carried()`. Built values never reach `to_markdown`.
- `WeaponProfile`: a Built Weapon now carries `bare` (typed `Resource`, as `build` is) and `rebuild()`, which builds again from `bare` and its `attachments` and copies every stored field into itself, so the Pirate's hand and `Raid.weapons` see the change with no swap.
- How a dial reaches the gun: the sheet edits the cached bare Profile or Attachment; `SandboxSheetView._applied` calls `sheet.rebuild_carried()` for any Weapons or Attachments edit (and each reverted cell), which rebuilds the carried Built Weapons in place.
- Debug strip (`SandboxSheetView`): FIRST and SECOND OptionButtons and a picker per Slot of each gun ("no <Slot>" plus what fits), on its own `Loadout` read from what he carries at each open. On close, only if the strip changed, `player.carry(loadout.build_weapons())` (magazines full) and, in a menu Raid, `Raid.weapons` too, so a Retry keeps the pick; a New Raid reads the saved Loadout. `save()` is never called.
- Layout: read-only Weapons cells (models, sound lists) are clipped to 170 px with the full text on hover, so all four weapon columns fit at 1280×720 (before, only the Pistol's did); the Attachments table uses 70 px factor cells and wrapped 12 pt names to fit 14 columns; table notes wrap.
- `tests/shots.gd`: new `sheet` preset; documented in `docs/agents/validation.md` with a `scripts/sandbox/` coverage row. `docs/sandbox.md` regenerated.

