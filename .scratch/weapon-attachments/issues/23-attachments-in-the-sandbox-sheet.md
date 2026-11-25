Status: ready-for-agent
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

- [ ] (agent) The Attachments table has fourteen columns and its cells equal the Attachment files' factors; `docs/sandbox.md` has the same table and the stale-doc check covers it.
- [ ] (agent) Setting the Suppressor's loudness factor to 0.5 in the sheet makes the carried suppressed gun's loudness 12.0 before the sheet closes; Save writes 0.5 to the Attachment file; Revert restores 0.4.
- [ ] (agent) With two guns carried the Weapons table still has four columns.
- [ ] (agent) With a Drum fitted, the Assault Rifle's magazine row shows 30 and, beside it, 75.
- [ ] (agent) Changing the first gun and a Slot in the debug strip and closing the sheet puts that Built Weapon in hand with a full magazine, and the profile file's Loadout is unchanged.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) The table is readable and a factor is quick to change mid-Raid.

## Comments
