Status: resolved
Blocked by: 19

# Aiming: aimed-and-moving spread, sway and a mouse slowed by zoom

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 10 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "New Weapon Profile fields" section and `issues/09-precision-rifle-aiming.md`.

- The Weapon Profile gains an aimed-and-moving spread. While aimed, the cone is the base times `ads_spread` when still or crouched, and the base times the aimed-and-moving spread when walking; the air and Slide multipliers still apply on top. The Pistol gets 0.6 and the Assault Rifle 0.585 (their aimed multiplier times their walking multiplier), so both play as today.
- The Profile gains aimed sway in degrees, 0 for the existing guns: a slow figure of eight laid over the aim in Aim Down Sights.
- While aimed, the mouse slows by the weapon's zoom, for every gun.

Both new fields join the sheet.

## Acceptance criteria

- [x] The Pistol's and Assault Rifle's cones are unchanged in every stance, aimed or not.
- [x] A Profile with a small `ads_spread` and a larger aimed-and-moving spread is pinpoint aimed and still and looser aimed and walking.
- [x] With sway set, the aim drifts while aimed and stops when the sights drop.
- [x] Aimed with a 1.6 zoom, the same hand movement turns the view 1.6 times less.
- [x] `tests/run_all.sh` passes.

## Comments

Built. `WeaponProfile` gains `ads_moving_spread` (Pistol 0.6, Assault Rifle 0.585, Shotgun 0.8; each its `ads_spread` times its `spread_walking`) and `ads_sway_degrees` (0 for all three, the default); both are rows on the Sandbox sheet. Aimed cone per stance: still `(base + bloom) * spread_still * ads_spread`; walking `(base + bloom) * ads_moving_spread`; crouched `(base + bloom) * spread_crouch * ads_spread`; air `(base + bloom) * spread_air * ads_spread`. The crouch multiplier still applies aimed (the spec's wording would drop it), so the Pistol and Assault Rifle cones are unchanged in every stance. Sway is the prototype's figure of eight, applied each physics frame as the change since last frame and taken back whole when the sights drop (`Pirate._sway_aim`). Mouse look moved into `Pirate.look(relative)`, which divides by the held gun's `ads_zoom` on the aimed flag, not the easing camera zoom. Tested with `tests/weapons/steady_rifle.tres`; 35 new checks in `tests/test_pirate.gd`.

