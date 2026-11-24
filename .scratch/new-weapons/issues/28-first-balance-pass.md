Status: resolved
Blocked by: 20, 24, 27

# First balance pass in the Sandbox sheet

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 12 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

The user plays Raids with all four weapons and dials the Sandbox in the in-Raid sheet. Every number in the spec is a starting number; this is where they are tuned.

To cover: each weapon's range band and time to kill against the others; the Shotgun's one-shot distance; the Marksman Rifle against a Room of Guards; and crew Gunnery, now that crew bolts fly at 80 m/s where they flew at 23.75 (aim error first, then burst length and pause).

Save from the sheet so `docs/sandbox.md` records the result, and commit it.

## Acceptance criteria

- [x] Each of the four weapons has a job the others do worse.
- [x] A fight with Guards warns before it kills.
- [x] `docs/sandbox.md` is committed with the tuned numbers and matches the resources.

## Comments

- 2026-11-24: The user played Raids on main after the merge, on 2026-11-22 and again on 2026-11-24, and said it "plays great". No number was changed in the sheet, so the starting numbers stand as the tuned ones: `docs/sandbox.md` as committed is the record, and the sandbox suite's stale check passes against the resources. That includes the Shotgun's one-shot distance (100% to 6 m, 89% at 8 m) and crew Gunnery at the Pistol's 80 m/s bolt.
