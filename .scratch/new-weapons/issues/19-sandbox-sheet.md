Status: ready-for-agent
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

- [ ] F1 opens and closes the sheet in a Raid; the Raid is paused while it is open.
- [ ] Changing Pistol damage in the sheet changes the next shot without a restart.
- [ ] Save rewrites the weapon and Sandbox resources and `docs/sandbox.md`; Revert undoes unsaved changes.
- [ ] Editing a `.tres` by hand without regenerating makes the stale check fail.
- [ ] The sheet is absent from an exported build.
- [ ] `tests/run_all.sh` passes.

## Comments
