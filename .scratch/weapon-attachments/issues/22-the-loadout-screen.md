Status: ready-for-agent
Blocked by: 17, 19

# The Loadout screen

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 8 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Loadout screen" and `issues/08-loadout-screen.md`. Reference: `scripts/proto/proto_loadout_screen.gd` on branch `prototype/loadout-screen`, the F1 "workbench" layout, which the user called perfect once the gun stopped spinning. Its bar numbers are placeholders and its gun shows no Attachments; here both are real.

- A Loadout button on the main menu's home list, under Play, opening the screen over the darkened backdrop.
- FIRST and SECOND tabs; a row of the four weapons to change the gun carried in the chosen place; picking the other place's gun swaps them.
- The gun still and side-on, barrel left, with its fitted Attachments on it. Drag turns it freely and it stays; a double click resets.
- Five Slot tags around the gun: name over the fitted Attachment, "empty", or greyed "no Slot".
- A tag opens its list: None and each Attachment that fits, the fitted one marked, each with one gain and cost line generated from its changes.
- Nine bars of the Built Weapon against the bare gun (Bolt speed, Hip accuracy, Aimed accuracy, Recoil control, Handling, Magazine, Reload, Quiet, Zoom): grey to the lower, green for a gain, red for a cost, the built value as a number in that colour. A red line "Crew notice him sooner" with a Laser.
- Mouse, and keyboard focus (arrows, Enter, Esc). Back or Esc saves the Loadout and returns to the menu.
- The `menu` screenshot preset gains the Loadout screen: bare, and with a Slot list open on a fitted gun.

## Acceptance criteria

- [ ] (agent) The home list has Play, Loadout, Exit in that order, and Loadout opens the screen.
- [ ] (agent) Fitting the Drum to the Assault Rifle through the screen, leaving and starting a Raid gives an Assault Rifle with 75 rounds.
- [ ] (agent) Choosing the second place's gun for the first place swaps the two.
- [ ] (agent) The Pistol's Stock tag and the Shotgun's Magazine tag are disabled and read "no Slot".
- [ ] (agent) Each bar's built value equals the Built Weapon's attribute, and a bar is green exactly when the built value is better than bare and red when worse, for the Assault Rifle with Suppressor and Drum.
- [ ] (agent) Every Attachment's gain and cost line is produced from its changes: no Attachment file holds descriptive text.
- [ ] (agent) Dragging 100 px across the gun turns it and it stays turned; a double click returns it to side-on.
- [ ] (agent) The screen can be worked with the keyboard alone: a Slot opened, an Attachment fitted, the screen left.
- [ ] (agent) `tests/shots.sh menu`: the Loadout shots show the gun with its fitted Attachments, no overlapping or clipped text, tags inside the screen.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) The screen reads at a glance and the bars tell what a part did.

## Comments
