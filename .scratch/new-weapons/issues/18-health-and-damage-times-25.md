Status: resolved
Blocked by: 17

# Scale Health and damage by 25, with a segmented Health bar

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 2 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Damage model" and "HUD" sections, and `issues/07-damage-model.md` and `issues/14-hud-for-new-guns.md`.

Crew Health becomes 100 and Pirate Health 150. Pistol and Assault Rifle damage become 25, Melee from the front 75 (the kill from behind is unchanged), and a crew shot does 25. Everything stays an int. Nothing should play differently.

The HUD's six pips are replaced by one bar where the pips were, in their green, split into six segments of 25 by dividers and filling continuously, so 13 damage shows.

## Acceptance criteria

- [x] A crew member dies to 4 Pistol or Assault Rifle hits, and to one Melee from behind; a front Melee leaves 25.
- [x] The Pirate dies to 6 crew hits.
- [x] The Health bar shows 150 as full, moves on a hit of any size and has six segments.
- [x] `tests/run_all.sh` passes, with its Health and damage expectations updated.

## Comments

**Build note (2026-11-22).** Crew Health 100 (`scenes/crew_3d.tscn`), Pirate Health 150 (`scenes/player_3d.tscn`), Pistol and Assault Rifle damage 25 (`resources/weapons/*.tres`), `melee_damage` 75 (`scripts/player_3d.gd`; the kill from behind still deals the target's remaining Health), crew shots 25 (`scripts/projectile_3d.gd` default). The `WeaponProfile.damage` default is 25 too, and the test-only heavy pistol 75, so nothing defaults to the old scale. 2D scripts and scenes are untouched. The HUD pips are gone: `scripts/ui/hud.gd` draws one 180 x 10 px bar where they were, in their green, with a divider every 25 Health (six segments at 150) and a fill that is continuous (`health_segments()`, `health_fill_width()`, `health_bar_width()` are the test seams).

Verified headless: new `_check_health_and_damage` in `tests/test_crew.gd` (4 Pistol and 4 Assault Rifle hits kill a crew member from the real scene, 3 do not; 6 crew shots kill a fresh Pirate, 5 do not); the melee checks in `tests/test_pirate.gd` now use 100 Health dummies (front Melee leaves 25, back Melee kills); new `_check_hud_health` (6 segments, full at 150, 13 and 14 damage both move the fill, 0 empties it). Every other Health and damage expectation was scaled by 25. `tests/run_all.sh` green. Not checked by eye: how the bar looks in a running Raid.

