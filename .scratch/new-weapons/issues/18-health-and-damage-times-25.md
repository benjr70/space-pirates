Status: ready-for-agent
Blocked by: 17

# Scale Health and damage by 25, with a segmented Health bar

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 2 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Damage model" and "HUD" sections, and `issues/07-damage-model.md` and `issues/14-hud-for-new-guns.md`.

Crew Health becomes 100 and Pirate Health 150. Pistol and Assault Rifle damage become 25, Melee from the front 75 (the kill from behind is unchanged), and a crew shot does 25. Everything stays an int. Nothing should play differently.

The HUD's six pips are replaced by one bar where the pips were, in their green, split into six segments of 25 by dividers and filling continuously, so 13 damage shows.

## Acceptance criteria

- [ ] A crew member dies to 4 Pistol or Assault Rifle hits, and to one Melee from behind; a front Melee leaves 25.
- [ ] The Pirate dies to 6 crew hits.
- [ ] The Health bar shows 150 as full, moves on a hit of any size and has six segments.
- [ ] `tests/run_all.sh` passes, with its Health and damage expectations updated.

## Comments
