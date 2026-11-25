Status: resolved
Blocked by: 19

# The Laser's dot

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 7 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Laser" and `issues/14-sheet-hud-laser-and-reload-sounds.md`.

With a Laser fitted to the weapon in hand, a small red dot on the first surface or body along the line the gun points, from the Laser's `Laser_Origin` marker, at the hip and aimed, out to 30 m. Beyond 30 m, nothing. No beam. Hidden while the weapon is lowered for a Sprint or a Clamber, and during a swap. Crew do not react to it; the conspicuous factor already does that work.

## Acceptance criteria

- [x] (agent) Facing a wall 5 m away with a Laser fitted, a dot exists within 2 cm of where a ray along the gun's line meets the wall.
- [x] (agent) Facing open space with nothing inside 30 m, no dot is shown.
- [x] (agent) Without a Laser, and with one while sprinting, no dot is shown.
- [x] (agent) `tests/shots.sh attachments` with a Laser build shows one red dot on the far wall and no beam.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) The dot is easy to see without drawing the eye from the crosshair.

## Evidence

- Wall at 5 m: `tests/laser_dot_checks.gd::_check_dot_on_wall` (pirate suite), for the Pistol, Assault Rifle and Shotgun each built with a Laser, at the hip and aimed, asserts the dot is shown and within 0.02 m of where the line from `Laser_Origin` along the Viewmodel's barrel axis meets the wall plane 5 m off, worked out analytically (the dot comes from a physics ray). Measured with the tolerance set to 0 for one run: 0.000 m in every case (e.g. Pistol hip dot at (70.16, 1.4466, 5.0), on the gun's line, not the crosshair's). It also asserts the hip dot is more than 0.05 m off the camera's axis, so it follows the gun.
- Open space: `tests/laser_dot_checks.gd::_check_open_space` asserts no dot facing open floor with nothing inside 30 m, at the hip and aimed; `_check_reach` asserts the same wall shows the dot at 28 m and none at 32 m.
- No Laser, and sprinting: `tests/laser_dot_checks.gd::_check_no_laser` (Pistol bare, Assault Rifle with a Combat Scope, Marksman Rifle bare, facing the wall, hip and aimed: no dot) and `_check_hidden_lowered` (with a Laser, sprinting toward a wall 11 m off: no dot on any frame drawn in SPRINT, and the dot returns at a walk; the same through a Clamber). `_check_hidden_in_swap` asserts no dot on any frame drawn during a swap out of and back into a Laser build. A mutation run with the hide and the origin removed failed all of these (13 checks).
- Screenshot: `tests/shots.sh attachments` PASS, 24 frames. `.godot/shots/attachments/pistol_a_hip.png`, `assault_rifle_a_hip.png` and `shotgun_b_hip.png` (the Laser builds) each show one small red dot on the far wall just right of and below the screen's middle, and no beam; `assault_rifle_b_hip.png` and every bare `_hip.png` (no Laser) show no dot. No other defects from the checklist in the frames read.
- Gate: `tests/run_all.sh` passed, every suite PASS, last line `total: 266 s` (pirate suite 2014 checks).

## Owed to playtest

- (human) The dot is easy to see without drawing the eye from the crosshair.

## Comments

Built 2026-11-24 on `weapon-attachments-21`. `scripts/laser_dot.gd` (`LaserDot`, `player.laser_dot`, a `LaserDot` node in `scenes/player_3d.tscn`): on each `mounted` it finds the fitted Laser's `Laser_Origin` through `fitting.model_of`; each frame it casts a ray from there along the gun's barrel (the Viewmodel's +Z, so sway and recoil tilt move it) out to 30 m against the ship and bodies (layers 1 and 2, not bolts or areas), the Pirate excluded, and puts the dot at the hit. Hidden without a Laser, with no hit, in SPRINT or CLAMBER, and while `is_swapping()`. The dot is a bare unshaded red sphere drawn at a fixed screen size (radius 0.006 at 1 m, about 5 px across on 720 px at any range), no shadow, no collision: crew cannot see or meet it.

Seen through a scope's lens: yes. The dot draws on render layer 1, the world's, which the lens camera keeps (it leaves out only the Viewmodel's layer 2), so an Assault Rifle with a Laser and a Combat Scope shows the dot in the lens; `_check_dot_is_only_a_visual` asserts the lens camera's cull mask takes the dot's layer. Not screenshotted through a lens.

The ray starts at the marker's true place in the world, not at the widened on-screen place `Viewmodel.muzzle_point` uses for bolts; with no beam drawn the difference only moves the hip dot a few centimetres, and the playtest can say if it reads wrong. `docs/agents/validation.md` gets a row for the new file.
