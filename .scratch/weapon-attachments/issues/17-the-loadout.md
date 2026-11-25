Status: resolved
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

- [x] (agent) With no saved Loadout a Raid from the menu carries the Pistol then the Assault Rifle, both bare, Pistol in hand.
- [x] (agent) A Loadout of Shotgun first and Marksman Rifle second with a Suppressor survives save and load, and a Raid from it carries exactly those two, Shotgun in hand, the Marksman Rifle's loudness 9.6.
- [x] (agent) Key 1 picks the first weapon and key 2 the second; the wheel flips between them; keys 3 and 4 do nothing.
- [x] (agent) A saved Loadout naming an unknown Attachment, an Attachment the gun does not take, an unknown weapon and the same weapon twice each load without error to the fallbacks above.
- [x] (agent) A weapon not in the Loadout keeps its saved Attachments through a save and load.
- [x] (agent) A Retry carries the same two Built Weapons as the Raid before it.
- [x] (agent) `raid_smoke` runs whole Raids with a fitted Loadout (Assault Rifle with Suppressor and Drum, Shotgun with Short Barrel) and passes.
- [x] (agent) `tests/run_all.sh` passes.

## Evidence

- No saved Loadout: `tests/loadout_checks.gd::_check_raid_default` (run by `tests/test_pirate.gd::_check_loadout`, `only=pirate`), which deletes the profile file, presses Small Ship on the real main menu, waits for the Raid scene and asserts the Pirate carries exactly two weapons, every stored field equal to the bare Pistol then the bare Assault Rifle with no Attachments, the first in hand with a full magazine. `_check_default` also asserts `Loadout.new()` and `Loadout.load_saved()` with no file are Pistol, Assault Rifle, every Slot empty.
- Shotgun and suppressed Marksman Rifle: `tests/loadout_checks.gd::_check_round_trip` sets Shotgun first, Marksman Rifle second with a Suppressor in its Barrel Slot, saves, loads and asserts the same two weapons and the Suppressor came back, and the Built Weapons are a bare Shotgun and a Marksman Rifle with `attachments == [Suppressor]` and loudness 9.6 within 1%. `_check_raid_fitted` saves that Loadout, boards from the menu and asserts the Raid carries exactly those two (bare Shotgun, Marksman Rifle with only the Suppressor), the Shotgun in hand and full, the Marksman Rifle's loudness 9.6 within 1%.
- Keys and wheel: `tests/loadout_checks.gd::_check_raid_fitted`, on the Raid's Pirate with the suite's course switched off, presses `weapon_2` (second in hand), `weapon_1` (first in hand), then `weapon_3` and `weapon_4` and asserts the first stays in hand and no swap started; `weapon_next` flips to the second, `weapon_next` back to the first, `weapon_prev` to the second.
- Stale entries: `tests/loadout_checks.gd::_check_stale` writes profile files by hand and asserts each loads, with no error (the runner fails on any `ERROR:` line), to: an unknown Attachment (`flux_capacitor`) and a Reflex Sight on the Marksman Rifle each an empty Slot with the carried weapons unchanged and the build still two weapons; a Drum in the Shotgun's Barrel and a Suppressor in its Magazine each empty; an unknown first weapon to the Pistol (second kept), an unknown second (a number) to the Assault Rifle; the Shotgun twice to Pistol then Assault Rifle; an unknown first falling back onto a Pistol second to Pistol then Assault Rifle; an unreadable file to the default.
- Weapon not in the Loadout: `tests/loadout_checks.gd::_check_uncarried_keeps` fits a Suppressor and a Drum to the Assault Rifle, carries the Shotgun and Marksman Rifle, saves and loads, and asserts the Assault Rifle still has both; emptying its Magazine Slot then survives a save and load too.
- Retry: `tests/loadout_checks.gd::_check_raid_fitted` saves a different (default) Loadout, calls `Raid.retry()` and asserts the new Pirate's two weapons are the very same Built Weapon objects as the Raid before, the first in hand and full.
- Smoke run with a fitted Loadout: `tests/test_raid_smoke.gd::_attempt` gives every Raid `Raid.arm(_fitted_loadout())` (Assault Rifle with Suppressor and Drum first, Shotgun with Short Barrel second) and asserts the Pirate carries those two, Assault Rifle in hand, with exactly those Attachments; `tests/run_all.sh only=raid_smoke` passed (1080 checks, all floors met: Quiet Ghost 12 of 15, Loud kill 12 of 15, Loot 26 of 30).
- The gate: `tests/run_all.sh` passed in full, every suite PASS (pirate 1255 checks, raid_smoke 1104 checks), `total: 211 s`.

## Comments

Built 2026-11-24.

- `scripts/loadout.gd`: `class_name Loadout` (RefCounted). `all_weapons()`, `weapon_name(weapon)`, `get_first()`, `get_second()`, `set_first(weapon)`, `set_second(weapon)` (picking the gun in the other place swaps the two, so never the same twice; anything not one of the four is refused), `get_attachment(weapon, slot)`, `set_attachment(weapon, slot, attachment) -> bool` (null empties; false and unchanged when `why_refused` says no), `choice(weapon)` (the dictionary `build` takes), `build_weapons() -> Array[WeaponProfile]` (first, second), `save()`, `static load_saved() -> Loadout`. Every weapon keeps its own Attachments, carried or not.
- Profile file (`Profile.path`): section `[loadout]` with `first` and `second` as weapon file names (`"shotgun"`), and a section `[loadout_<weapon>]` per weapon with something fitted, key the Slot's name in lower case, value the Attachment's file name (`barrel="suppressor"`). `Profile.save` now loads the file before writing XP and gold, so banking a Raid no longer wipes the Loadout (it wrote a fresh file before).
- `scripts/raid.gd`: `Raid.weapons` (the two Built Weapons), `Raid.arm(loadout)`; `start` (and so a New Raid) arms from `Loadout.load_saved()`; `retry` reuses the same Built Weapons; `to_menu` clears them.
- `scripts/main_3d.gd`: with a Raid on and `Raid.weapons` set, gives them to the Pirate through the new `Player3D.carry(list)` (first in hand, magazines full, stowed ammo cleared). Scenes not from the menu, `RaidChecks` and every suite that sets `Raid.seed` directly keep the Pirate's default four.
- The Sandbox sheet is attached before `carry`, so it still dials the bare Profiles; in a menu Raid its changes do not reach the carried Built Weapons until ticket 23 reworks it.
- `tests/test_raid_smoke.gd`: the scripts no longer `switch_weapon(1)` to get the Assault Rifle out; it is first, in hand.
- No acceptance number disagreed with the spec.

