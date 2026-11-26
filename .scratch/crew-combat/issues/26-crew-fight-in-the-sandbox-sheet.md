Status: ready-for-agent
Blocked by: 19, 21

# Crew fight in the Sandbox sheet

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 12 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Threat Budget, Health and the Sandbox sheet" and `issues/14`.

- The sheet's Gunnery section: four columns, one per weapon, a row for every Gunnery field (aim error, opening spread, closing time, shots per burst low and high, bursts per peek, burst gap low and high, time down low and high, settle, lead, range band near and far, hold before shifting, reload factor). Edits reach Guards already in the Raid and save to that weapon's Gunnery file.
- A new Crew fight section, one column: how many aim true, the true-aim handover time, the first burst's walk-in distance, the Shotgun pellet cap, suppression time, the too-close distance, the flank reaction, the open floor a Guard will cross in view. Saved with the Sandbox resource.
- `docs/sandbox.md` regenerated from the sheet, and the `sandbox` suite extended.

## Acceptance criteria

- [x] (agent) The sheet lists four Gunnery columns named for the four weapons and every field above as a row.
- [x] (agent) Setting the Assault Rifle's aim error to 0 in the sheet makes the next Assault Rifle Guard shot use the gun's own spread only, and leaves a Pistol Guard's unchanged.
- [x] (agent) Setting "how many aim true" to 1 gives no frame with two Guards aiming true over the next 20 s of a five-Guard fight.
- [x] (agent) A Gunnery edit saved, then the resources reloaded from disk, keeps its value; the Crew fight values do the same.
- [x] (agent) `docs/sandbox.md` matches what the sheet writes (the suite's existing doc check).
- [ ] (agent) `tests/run_all.sh` passes. (awaits the final verification)
- [ ] (human) A fight can be retuned from the sheet without leaving the Raid.

## Comments

- The three numbers the spec names that were still constants moved onto the Sandbox's "Crew fight" group at their values: `CrewCover.TOO_CLOSE` 3.0 -> `too_close`, `FLANKED_AFTER` 0.4 -> `flank_reaction`, `OPEN_RUN` 2.5 -> `open_floor`. `CrewCover` reads `crew.sandbox.<field>` at its three uses, so an edit reaches Guards already in the Raid; the constants are gone. `tests/test_crew.gd::_walk_unfair` reads `open_floor` from the Guard's Sandbox in place of `CrewCover.OPEN_RUN` (same 2.5). Every other number (covering fire 1 s / 3 s, flank distances, suppression geometry, habit numbers, magazine and pose numbers) stays a constant, as the spec's "Everything else is a named constant in code" says.
- Choice: the Sandbox resource is split into three tables by its export groups (`SheetTable.from_resources` takes an optional group list): Health and Melee (Health, Melee), Crew fight (the eight numbers, one "Value" column, with a note saying what each does), and Surrender and Bound (ticket 24's six, which had been rows of the Health table). All three save to `resources/sandbox.tres`. Table order: Weapons, Health and Melee, Gunnery, Crew fight, Surrender and Bound, Attachments.
- The Gunnery section already had four columns and every field (ticket 15); its note's stale "Not read yet: reload factor" now says what the factor does.
- `tests/test_crew.gd::_check_true_aim` takes a count (default 2, unchanged); the count-1 run is placed last in the suite so it moves no earlier check's draws. The fixed-seed medians stayed (Pistol 9.56 s, Assault Rifle 5.68 s).
- `tests/shots.sh sheet` gains `sheet_crew_fight.png` (scrolled to the Crew fight table); `docs/agents/validation.md` updated for it and for the new checks.

## Evidence

- Four Gunnery columns, every field a row: `tests/test_sandbox.gd::_check_edit_save_revert` asserts the Gunnery table's columns are exactly Pistol, Assault Rifle, Shotgun, Marksman Rifle, each of the sixteen fields (`GUNNERY_KEYS`: aim error, opening spread, closing time, lead, shots per burst low/high, bursts per peek, burst gap low/high, time down low/high, settle, range near/far, hold before shifting, reload factor) is an editable row, and the table has exactly sixteen rows. `::_check_crew_fight_table` asserts the one-column Crew fight table's rows are exactly the eight numbers in order at 2, 0.8, 1.0, 9, 4.0, 3.0, 0.4, 2.5, each editable, and Health and Melee holds only its three. `docs/sandbox.md` shows both (asserted in `::_check_doc_fresh`). Screenshot `.godot/shots/sheet/sheet_crew_fight.png` (`tests/shots.sh sheet`): Crew fight heading, Value column, eight rows and the note, nothing cut off or overlapping.
- Assault Rifle aim error 0: `tests/test_sandbox.gd::_check_rifle_aim_error` (in the debug Raid): two Guards armed, one with the Assault Rifle and its Gunnery, one with the Pistol and its; the sheet's own Gunnery cell (Assault Rifle column) set to 0; with aim closed, asserts the Assault Rifle Guard's shot spread (`spread_degrees()`, what `_fire` scatters by) equals the gun's `spread_base_degrees` (is_equal_approx) and that it fires, and the Pistol Guard's cone is exactly what it was before the edit.
- How many aim true at 1: `tests/test_crew.gd::_check_true_aim(1)`, run last in the `crew` suite: the count set to 1 through `SandboxSheet.build(...).table(CREW_FIGHT).set_value` on the live Sandbox the Guards read, five Guards fighting him for 20 s; asserts no physics frame with more than one Guard aiming true (plus the existing at-least-one, passed-round and miss-point assertions). `tests/run_all.sh only=crew`: PASS (540 checks, 96 s).
- Save and reload: Gunnery: `tests/test_sandbox.gd::_check_edit_save_revert` saves the Assault Rifle's shots per burst low 4 and the Pistol's range far 12.5 and asserts both on the files reloaded with `CACHE_MODE_IGNORE`. Crew fight: `::_check_crew_fight_save` sets all eight to new values (1, 1.25, 1.5, 7, 5.5, 3.5, 0.6, 2.0), saves, asserts each on the reloaded Sandbox file and on a sheet built from disk, and the Markdown view not stale.
- `docs/sandbox.md` regenerated with `scripts/sandbox/write_sandbox_doc.gd`; `tests/test_sandbox.gd::_check_doc_fresh` (stale check) passes: `tests/run_all.sh only=sandbox`: PASS (537 checks).
- `tests/run_all.sh` passes: not run, by the 2026-11-26 light-validation decision; awaits the final verification. Run: `only=sandbox` PASS, `only=static` PASS (182 checks), `only=crew` PASS (540 checks).

## Owed to playtest

- [ ] (human) A fight can be retuned from the sheet without leaving the Raid.
