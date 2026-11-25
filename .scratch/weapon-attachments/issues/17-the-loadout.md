Status: ready-for-agent
Blocked by: 16

# The Loadout

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 3 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Loadout" and `issues/05-loadout-rules.md`.

- The Loadout: a first and a second weapon, and for each of the four weapons the Attachment in each of its Slots.
- Saved in the profile file beside XP and gold (`scripts/profile.gd`). Loading drops anything stale without failing: an unknown Attachment or one the gun does not take becomes an empty Slot; an unknown or doubled weapon becomes the default (Pistol first, Assault Rifle second, bare).
- A Raid started from the menu reads the Loadout once, builds the two Built Weapons and gives them to the Pirate, first in hand. A Retry and a New Raid do the same from the saved Loadout.
- The Pirate's default carried list, for scenes that do not come from the menu, stays as it is; suites keep setting weapons directly.

No screen yet: the Loadout is set by code and by the profile file.

## Acceptance criteria

- [ ] (agent) With no saved Loadout a Raid from the menu carries the Pistol then the Assault Rifle, both bare, Pistol in hand.
- [ ] (agent) A Loadout of Shotgun first and Marksman Rifle second with a Suppressor survives save and load, and a Raid from it carries exactly those two, Shotgun in hand, the Marksman Rifle's loudness 9.6.
- [ ] (agent) Key 1 picks the first weapon and key 2 the second; the wheel flips between them; keys 3 and 4 do nothing.
- [ ] (agent) A saved Loadout naming an unknown Attachment, an Attachment the gun does not take, an unknown weapon and the same weapon twice each load without error to the fallbacks above.
- [ ] (agent) A weapon not in the Loadout keeps its saved Attachments through a save and load.
- [ ] (agent) A Retry carries the same two Built Weapons as the Raid before it.
- [ ] (agent) `raid_smoke` runs whole Raids with a fitted Loadout (Assault Rifle with Suppressor and Drum, Shotgun with Short Barrel) and passes.
- [ ] (agent) `tests/run_all.sh` passes.

## Comments
