Status: ready-for-agent
Blocked by: none

# Rename Sidearm to Pistol and Carbine to Assault Rifle

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 1 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

A pure rename so the code uses the glossary's names. Nothing else changes in this ticket.

Sidearm becomes Pistol and Carbine becomes Assault Rifle everywhere they appear: `resources/weapons/sidearm.tres` and `carbine.tres`, `scenes/weapons/sidearm_model.tscn` and `carbine_model.tscn`, the asset folders `assets/models/sidearm` and `assets/models/carbine` with their import files, node names in `scenes/player_3d.tscn` and `scenes/main_3d.tscn`, identifiers such as `sidearm_clips` in `scripts/viewmodel.gd`, `resources/animations/viewmodel_clips.tres`, `scripts/player_3d.gd`, `scripts/pirate_audio.gd`, `scripts/weapon_profile.gd`, `scripts/crew/crew.gd`, `scripts/crew/CREW_AI.md`, the tests (`tests/test_pirate.gd`, `tests/test_crew.gd`, `tests/shots.gd`, `tests/run_all.sh`), and `tools/blender/pistol.py` and `carbine.py`. File names use `pistol` and `assault_rifle`. Move files with `git mv` and keep Godot's `.uid` and `.import` files with them so references survive.

## Acceptance criteria

- [ ] No file, node, identifier or comment says sidearm or carbine outside `.scratch/`, `docs/research/` and git history (a case-insensitive grep finds none).
- [ ] `tests/run_all.sh` passes with no test logic changed.
- [ ] A Raid plays as before: both guns fire, reload, aim and swap.

## Comments
