Status: ready-for-agent
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

- [ ] A Pistol hit on a crew member's head does 38 and on the body 25; three Headshots kill.
- [ ] An Assault Rifle hit does 25 on either.
- [ ] A crew shot that strikes the Pirate high does plain damage.
- [ ] The head zone moves with a crouching crew member.
- [ ] A Headshot flashes gold, a body hit white, any kill red.
- [ ] `tests/run_all.sh` passes.

## Comments
