Status: resolved
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

- [x] (agent) The home list has Play, Loadout, Exit in that order, and Loadout opens the screen.
- [x] (agent) Fitting the Drum to the Assault Rifle through the screen, leaving and starting a Raid gives an Assault Rifle with 75 rounds.
- [x] (agent) Choosing the second place's gun for the first place swaps the two.
- [x] (agent) The Pistol's Stock tag and the Shotgun's Magazine tag are disabled and read "no Slot".
- [x] (agent) Each bar's built value equals the Built Weapon's attribute, and a bar is green exactly when the built value is better than bare and red when worse, for the Assault Rifle with Suppressor and Drum.
- [x] (agent) Every Attachment's gain and cost line is produced from its changes: no Attachment file holds descriptive text.
- [x] (agent) Dragging 100 px across the gun turns it and it stays turned; a double click returns it to side-on.
- [x] (agent) The screen can be worked with the keyboard alone: a Slot opened, an Attachment fitted, the screen left.
- [x] (agent) `tests/shots.sh menu`: the Loadout shots show the gun with its fitted Attachments, no overlapping or clipped text, tags inside the screen.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) The screen reads at a glance and the bars tell what a part did.

## Evidence

- Home list and opening: `tests/loadout_screen_checks.gd::_check_home` (in `pirate`) asserts the home list's buttons are exactly Play, Loadout, Exit in that order, that pressing Loadout shows the `LoadoutScreen` in place of the menu column with the backdrop still behind it, and that Back returns to the home list.
- Drum into a Raid: `tests/loadout_screen_checks.gd::_check_drum_into_raid` picks SECOND, opens the Magazine tag, picks the Drum, presses Back, then Play and Small Ship on the same menu; asserts the Raid's second gun is the Assault Rifle with `magazine_size` 75, and after key 2 and its swap time that the Assault Rifle in hand holds 75 rounds.
- Swap: `tests/loadout_screen_checks.gd::_check_places` presses the Assault Rifle (carried second) on the FIRST place and asserts the Loadout is Assault Rifle first, Pistol second, with both tabs renamed; then carrying the Shotgun second leaves the Assault Rifle first.
- No Slot: `tests/loadout_screen_checks.gd::_check_no_slot` asserts, for the Pistol and the Shotgun, that exactly the Pistol's Stock tag and the Shotgun's Magazine tag are disabled and read "no Slot", and every other tag is enabled and does not, each led by its Slot's name.
- Bars: `tests/loadout_screen_checks.gd::_check_bars` fits a Suppressor and a Drum to the Assault Rifle through the screen and, for each of the nine bars, asserts its value equals `WeaponAttributes.value` on the Built Weapon and the literal from the spec's catalogue within 1% (Bolt speed 80, Hip 1.2, Aimed 0.54, Recoil 3.0, Handling 0.275, Magazine 75, Reload 2.88, Quiet 9.6, Zoom 1.6), the number reads that value, and the number and the coloured part are green for Magazine and Quiet, red for Bolt speed, Handling and Reload, and neither (no coloured part) for the other four. Also: no "Crew notice him sooner" without a Laser; with a Laser it shows, red. Mutation: with the gain direction flipped in `WeaponAttributes.verdict`, 14 checks fail, five of them bar colours.
- Lines from changes: `tests/loadout_screen_checks.gd::_check_lines` asserts six Attachments' generated lines equal lines written from the spec's Gain and Cost columns (e.g. Laser "tighter hip fire · crew notice him sooner"), that changing a copy's `changes` changes its line ("more rounds", then "more rounds · louder"), that `lens` adds "scope lens", that every field any of the 14 files changes has words, that every `.tres` under `resources/attachments/` holds only the Attachment script's fields, and that the Attachment script's only String field is `display_name`. `_check_list` asserts each line in a Slot's list is the generated one. All words live in `scripts/ui/weapon_attributes.gd`, which the bars read too.
- Turning: `tests/loadout_screen_checks.gd::_check_turn` pushes a left press on the bench gun, ten 10 px motions (100 px) and a release through the window; asserts the gun's pivot turned, is unchanged 30 frames later, and is back side-on after a double click. Mutation: with the double click doing nothing it fails.
- Keyboard: `tests/loadout_screen_checks.gd::_check_keyboard` uses only `ui_*` key actions: down from Play to Loadout, Enter opens the screen on FIRST, right and Enter picks SECOND, down to the tags and right round them to Magazine, Enter opens its list with None focused, down to the Drum, Enter fits it and returns focus to the tag, Esc closes a reopened list only, Esc again leaves to the home list with Loadout focused, and the saved Loadout holds the Drum.
- Screenshots: `tests/shots.sh menu` PASS, 7 frames, in `.godot/shots/menu/`, read against the defect checklist at 1280x720:
  - `home.png`, `classes.png`: unchanged menu screens (home now Play, Loadout, Exit).
  - `loadout.png`: darkened backdrop; FIRST PISTOL marked, Pistol marked in the weapon row; the bare Pistol still and side-on, barrel left; five tags round it, Stock greyed "no Slot", the others "empty"; Pistol bars, all grey; nothing overlapping or clipped, every tag inside the bench.
  - `loadout_slot.png`: SECOND ASSAULT RIFLE; the rifle side-on with its Combat Scope, Suppressor, Drum, Laser and Light Stock on it; tags naming each in amber; the Underbarrel list (None, Foregrip, Laser marked, Bipod) with a generated line under each (Bipod's wraps to a second line inside the panel); the bars with red and green parts and numbers; red "Crew notice him sooner"; no overlap or clipping, every tag inside the screen.
  - `pause.png`, `death.png`, `extracted.png`: unchanged.
  - Also looked at (temporary frames, not kept): the Shotgun (Magazine "no Slot") and the Marksman Rifle turned by a drag, both framed inside the bench.
- The gate: `tests/run_all.sh` on seed 362708440, exit 0: every suite PASS (static 165, generator 341845, layouts 252, ship_3d 3681, pirate 2106, crew 205, sandbox 475, attachments 1674, raid_smoke 1092 checks), total 295 s.

## Owed to playtest

- (human) The screen reads at a glance and the bars tell what a part did.

## Comments

Built 2026-11-24 on `weapon-attachments`:

- `scripts/ui/loadout_screen.gd` (`LoadoutScreen`): the workbench lifted from the prototype's F1 layout, built once and refreshed in place. The bench gun is one instance per weapon in its own SubViewport world, fitted with `WeaponModel.of(model).fit(built)`, centred on its bare bounding box and framed side-on with the muzzle to the left (the camera's side is worked out from the Muzzle marker); it carries none of the Viewmodel's material flags. Tags are kept inside the bench; left and right go round the open tags; Esc closes an open list first, then saves and leaves.
- `scripts/ui/weapon_attributes.gd` (`WeaponAttributes`): the one table of attributes (fields, which way is better, gain and cost words), read by the bars and by the line under each Attachment. A line is made from `changes`, `lens` and `suppresses`; "Aimed on the move" is left out when it changes by the same factor as Aimed accuracy, so the Laser reads "tighter hip fire · crew notice him sooner". Bars sit on a log scale between fixed ends per attribute, so a factor reads the same length on every gun.
- `scripts/ui/main_menu.gd`: Loadout between Play and Exit; the screen replaces the menu column over the backdrop and returns focus to Loadout.
- `tests/loadout_screen_checks.gd`, run from `pirate` after `LoadoutChecks`; `tests/shots.gd` `menu` gains `loadout` and `loadout_slot`; `docs/agents/validation.md` coverage and preset lines.

