Status: resolved
Blocked by: none

# Rename Sidearm to Pistol and Carbine to Assault Rifle

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 1 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

A pure rename so the code uses the glossary's names. Nothing else changes in this ticket.

Sidearm becomes Pistol and Carbine becomes Assault Rifle everywhere they appear: `resources/weapons/sidearm.tres` and `carbine.tres`, `scenes/weapons/sidearm_model.tscn` and `carbine_model.tscn`, the asset folders `assets/models/sidearm` and `assets/models/carbine` with their import files, node names in `scenes/player_3d.tscn` and `scenes/main_3d.tscn`, identifiers such as `sidearm_clips` in `scripts/viewmodel.gd`, `resources/animations/viewmodel_clips.tres`, `scripts/player_3d.gd`, `scripts/pirate_audio.gd`, `scripts/weapon_profile.gd`, `scripts/crew/crew.gd`, `scripts/crew/CREW_AI.md`, the tests (`tests/test_pirate.gd`, `tests/test_crew.gd`, `tests/shots.gd`, `tests/run_all.sh`), and `tools/blender/pistol.py` and `carbine.py`. File names use `pistol` and `assault_rifle`. Move files with `git mv` and keep Godot's `.uid` and `.import` files with them so references survive.

## Acceptance criteria

- [x] No file, node, identifier or comment says sidearm or carbine outside `.scratch/`, `docs/research/` and git history (a case-insensitive grep finds none).
- [x] `tests/run_all.sh` passes with no test logic changed.
- [x] A Raid plays as before: both guns fire, reload, aim and swap.

## Comments

Built 2026-11-22. Files moved with `git mv` (each `.import` kept with its file; every `uid` unchanged, checked in the diff): `resources/weapons/pistol.tres` and `assault_rifle.tres`, `scenes/weapons/pistol_model.tscn` and `assault_rifle_model.tscn`, `assets/models/pistol/` and `assets/models/assault_rifle/`, `tools/blender/assault_rifle.py`. All `res://` paths, comments, test names and messages renamed.

Two choices worth knowing:
- The Viewmodel's mount node was `Sidearm` but carries whichever gun is wielded, so it is now `Holder` (the word the code already used), not `Pistol`: `viewmodel.holder`, `viewmodel.model_clips` (was `sidearm_clips`), `_on_model_clip_finished`, and the `Holder:` tracks in `viewmodel_clips.tres`. A Worker's gun in `crew.gd`/`CREW_AI.md` became "pistol".
- `assault_rifle.glb` held "Carbine" in its internal glTF names. The JSON chunk was rewritten in place (geometry and textures byte-identical): nodes/mesh `AssaultRifle`, `AssaultRifleArmature`, material `assault_rifle`, images `assault_rifle_*`, matching what `tools/blender/assault_rifle.py` now exports. Reimport extracted no new textures.

The ticket names `tests/shots.gd`; on this branch the file is `tests/viewmodel_shots.gd` and was updated (not run). `tests/run_all.sh` had no occurrence.

Verified: case-insensitive grep for sidearm|carbine outside `.scratch/`, `docs/research/` and `.godot/` finds nothing (binaries included); `bash tests/run_all.sh` passes, all five suites (pirate 597, crew 88). Fire, reload, ADS and swap of both guns are covered by the pirate suite; not playtested by hand.
