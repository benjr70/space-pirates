Status: resolved
Blocked by: 19

# Headshots

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 9 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Damage model" and "HUD" sections, `issues/07-damage-model.md` and `issues/14-hud-for-new-guns.md`.

Crew get a head zone that follows the model's head (including when they crouch behind cover), separate from the body. A projectile that strikes it is a Headshot. The Weapon Profile gains a headshot multiplier, 1 for no bonus: Pistol 1.5 (25 becomes 38, rounded), Assault Rifle 1. A Headshot does the Profile's damage times the multiplier.

Nothing that strikes the Pirate is a Headshot.

A Headshot flashes the hit marker's X in gold (1.0, 0.8, 0.25); a Headshot that kills is red like any kill. It plays the hit-marker tick for now: its own sound is open in `issues/16-headshot-and-assault-rifle-sounds.md`, so make the sound easy to swap.

The multiplier and shots to kill by Headshot join the sheet.

## Acceptance criteria

- [x] A Pistol hit on a crew member's head does 38 and on the body 25; three Headshots kill.
- [x] An Assault Rifle hit does 25 on either.
- [x] A crew shot that strikes the Pirate high does plain damage.
- [x] The head zone moves with a crouching crew member.
- [x] A Headshot flashes gold, a body hit white, any kill red.
- [x] `tests/run_all.sh` passes.

## Comments

**Build note (2026-11-22).** `scripts/crew/head_zone.gd` (`HeadZone`, an `Area3D` with a 0.16 m sphere on physics layer 4, value 8) rides the `Head` bone of both rigs (engineer and soldier) through a `BoneAttachment3D`, centred 0.14 m up the bone; its scale undoes the soldier skeleton's hundredfold import scale. Standing, it sits at about 1.78 to 1.81 m, above the 1.7 m capsule; it is disabled on death. The capsule stays the body. New field `WeaponProfile.headshot_multiplier` (default 1, Pistol 1.5), rounded by `WeaponProfile.head_damage()`; bolts carry it as `Projectile3D.headshot_multiplier`. A bolt looks for a head zone along its line with an areas-only ray: nearer than what stopped it, or that body's own head up to 0.8 m behind where it struck; a bolt grazing a capsule with its 0.09 m width checks the same way. Signals: `Projectile3D.hit(target, on_head)` and `hit_landed(target, killed, headshot)`, where headshot needs a multiplier above 1; a split pellet shot still reports once. The crosshair's convergence ray (`aim_point`) now sees head zones, or a shot aimed at a head above the capsule passed beside it by the muzzle offset. HUD: gold `HITMARKER_HEADSHOT_COLOR`, kill still red. Sound: `PirateAudio.headshot_stream` (kind `headshot`), the hit tick for now. Sheet: Headshot Multiplier row and "Shots to kill crew by Headshot" (3, 4, 1). Covered in `tests/test_crew.gd` (`_check_headshots`, `_check_head_follows_pose`, `_check_pirate_has_no_head`). Crew have no crouch clip and their capsule does not shrink, so "moves with a crouching crew member" is checked with the Roll clip 0.2 s in (head about 1.0 m), where a Pistol shot at the moved head is a Headshot. Not seen in game: how the zone fits the heads by eye, and the gold marker on screen.
