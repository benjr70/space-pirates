Status: ready-for-human
Blocked by: 15, 16, 17, 18, 19, 20, 21, 22, 23

# First balance pass of the Attachments

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 10 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

Nothing is built: the user plays Raids with the sheet (F1) and its debug Loadout strip, dials the Attachment factors and the four guns' aim and swap times, and saves. `docs/sandbox.md` records where they land.

Look first at what the map flagged (`issues/13-starting-numbers.md`):

- Every aim time and swap time factor: no range of what can be felt was found.
- The slowest stacked builds: Assault Rifle 0.59 s and Marksman Rifle 0.75 s to the sights.
- The Laser on the Shotgun: pellets from 5 to 3.5 degrees.
- The suppressed Marksman Rifle as a Ghost tool, and 9.6 m as the distance a suppressed shot is heard.
- Any Attachment nobody would fit, and any nobody would leave off.
- How loud the suppressed shots are against the bare ones.

## Acceptance criteria

- [ ] (human) Every Attachment has been played on every gun it fits.
- [ ] (human) No Slot has one choice that is always right.
- [ ] (human) The numbers are saved and `docs/sandbox.md` matches them.
- [ ] (agent) After the save, `tests/run_all.sh` passes with the catalogue checks updated to the saved numbers.

## Comments
