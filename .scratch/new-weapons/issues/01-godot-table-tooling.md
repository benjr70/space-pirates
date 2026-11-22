Type: research
Status: resolved
Blocked by: none
Map: ../map.md

# What Godot offers for editing many Resources as one table

## Question

What ways exist in Godot 4 to see and edit one custom Resource type across many instances as a single table, and to have changes show up in a running game? Cover: editor addons that show Resources as a spreadsheet, a CSV or JSON file as the source of truth loaded or imported into Resources, a single Resource holding an array of sub-resources, and live reload of changed resources during play. For each: maturity, Godot 4 version support, how it handles nested values such as Vector3, PackedScene and StringName fields, and how it diffs in git.

## Answer

Full findings: `docs/research/godot-table-tooling.md` on branch `research/godot-table-tooling` (pushed, never merged). Read it with `git show origin/research/godot-table-tooling:docs/research/godot-table-tooling.md`. Nothing was run in Godot; the project is on Godot 4.7 and `WeaponProfile` has 34 exports.

Verified in sources:

- Godot has no built-in table view of Resources; the proposal has been open since 2019.
- The "Edit Resources as Table" addon is actively maintained and edits the existing `.tres` files in place. Its Godot 4.7 fix is on master only, not in the asset-library build. It has no Vector3 cell, PackedScene changes go through the Inspector, and StringName saves correctly. Other addons are tiny, alpha with their own data model (Pandora), or archived.
- The engine reads CSV as strings only and claims `.csv` for the translation importer. CSV addons do not cover Vector3 or StringName.
- One Resource holding `Array[WeaponProfile]` stores every type natively, but the Inspector still shows one weapon at a time.
- Live changes: remote inspector edits are live but not saved. "Synchronize Scene Changes" forwards undo-redo property edits on saved Resources to the running game. Reimported files reload in the game (4.4+); plain `.tres` file changes do not. `CACHE_MODE_REPLACE` refreshes instances in place. There is no file watcher.

Inferred, untested:

- The addon's grid edits probably do not live-sync, because its undo-redo uses method calls rather than property sets.
- Vector3 cells would need the full `Vector3(...)` literal.
- PackedScene paths in a CSV would not follow renames.
- A one-row-per-weapon CSV diffs worse than `.tres`.
- Game code was not audited for cached Profile values.
