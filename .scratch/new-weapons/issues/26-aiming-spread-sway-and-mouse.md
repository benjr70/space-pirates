Status: ready-for-agent
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

- [ ] The Pistol's and Assault Rifle's cones are unchanged in every stance, aimed or not.
- [ ] A Profile with a small `ads_spread` and a larger aimed-and-moving spread is pinpoint aimed and still and looser aimed and walking.
- [ ] With sway set, the aim drifts while aimed and stops when the sights drop.
- [ ] Aimed with a 1.6 zoom, the same hand movement turns the view 1.6 times less.
- [ ] `tests/run_all.sh` passes.

## Comments
