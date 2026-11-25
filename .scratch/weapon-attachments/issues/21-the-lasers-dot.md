Status: ready-for-agent
Blocked by: 19

# The Laser's dot

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 7 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Laser" and `issues/14-sheet-hud-laser-and-reload-sounds.md`.

With a Laser fitted to the weapon in hand, a small red dot on the first surface or body along the line the gun points, from the Laser's `Laser_Origin` marker, at the hip and aimed, out to 30 m. Beyond 30 m, nothing. No beam. Hidden while the weapon is lowered for a Sprint or a Clamber, and during a swap. Crew do not react to it; the conspicuous factor already does that work.

## Acceptance criteria

- [ ] (agent) Facing a wall 5 m away with a Laser fitted, a dot exists within 2 cm of where a ray along the gun's line meets the wall.
- [ ] (agent) Facing open space with nothing inside 30 m, no dot is shown.
- [ ] (agent) Without a Laser, and with one while sprinting, no dot is shown.
- [ ] (agent) `tests/shots.sh attachments` with a Laser build shows one red dot on the far wall and no beam.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) The dot is easy to see without drawing the eye from the crosshair.

## Comments
