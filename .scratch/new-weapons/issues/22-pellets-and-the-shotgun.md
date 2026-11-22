Status: ready-for-agent
Blocked by: 21

# Pellets and the Shotgun

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 6 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Shotgun" section, `issues/05-shotgun-role.md` and `issues/08-shotgun-pellet-pattern.md`. The prototype on branch `prototype/shotgun-pellets` is the reference for feel.

The Weapon Profile gains a pellet count, 1 for the existing guns. A shot launches that many projectiles, each thrown at random inside the live cone, evenly over its area, each doing the Profile's damage. One shot gives one hit marker per crew member and counts one kill, however many pellets land: a pellet striking a crew member already killed by the same shot must not report a second kill.

Add the Shotgun as a Weapon Profile with the spec's starting values (12 pellets of 13, 5 degree cone with no bloom, 15 m reach, 0.8 s between shots, 6 shells, the Aim Down Sights and recoil numbers, no Slide widening, loudness 32, the picked shot sound) and put it on the Weapon Wheel after the Assault Rifle. Import the model built by `tools/blender/shotgun.py` into `assets/models/` with a scene under `scenes/weapons/`, at hip pose (0.15, -0.24, -0.34) and aimed distance 0.30, with a lowered pose set clearly below the hip pose. The model has no skeleton yet: give it the minimum the Viewmodel needs to mount it; its real clips are a later ticket. Until then it reloads like a magazine gun.

Pellet count, damage per shot and pellets needed to kill join the sheet.

## Acceptance criteria

- [ ] A Shotgun shot launches 12 pellets, all inside the cone.
- [ ] A shot that kills one crew member awards one kill's XP and flashes one marker.
- [ ] At about 3 m a centred shot kills; at about 8 m it usually takes two.
- [ ] A shot during a Slide is no wider than one standing still.
- [ ] The Shotgun is on the wheel and shows the pump-action model at the hip, aimed and lowered.
- [ ] The Pistol and Assault Rifle still fire one projectile.
- [ ] `tests/run_all.sh` passes.

## Comments
