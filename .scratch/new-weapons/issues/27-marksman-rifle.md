Status: ready-for-agent
Blocked by: 21, 25, 26

# The Marksman Rifle, and a wheel of four

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 11 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "The Marksman Rifle" and "Weapon Wheel" sections, and `issues/06-precision-rifle-identity.md`, `issues/09-precision-rifle-aiming.md` and `issues/11-marksman-rifle-look.md`. The prototypes on branches `prototype/marksman-aim` and `prototype/marksman-look` are the reference for feel and look.

Add the Marksman Rifle as a Weapon Profile with the spec's starting values: 50 damage with a headshot multiplier of 2, 0.4 s between shots, a 200 m/s bolt reaching 80 m, 8 rounds, a 3 degree hip cone, pinpoint aimed and still and 1.2 degrees aimed and walking, zoom 3 over its sights, aimed speed 0.6, sway 0.25 degrees, loudness 24, the picked shot and magazine sounds.

Model: start from `tools/blender/marksman.py` on `prototype/marksman-look` (the bullpup variant; drop the walnut one). Finish it to the Assault Rifle's standard with a 2048 bake, and rig it with a bolt that cycles on each shot and a magazine that drops and seats behind the grip. Import it with a scene under `scenes/weapons/`, at hip pose (0.15, -0.2, -0.36) and aimed distance 0.36, with a lowered pose. Its sights must read clearly at 3x. No scope.

Weapon Wheel: the order is Pistol, Assault Rifle, Shotgun, Marksman Rifle, and keys 1 to 4 pick a weapon directly under the same swap time and rules as the wheel. A Raid starts on the Pistol.

## Acceptance criteria

- [ ] One Marksman Rifle Headshot kills a crew member; two body shots kill.
- [ ] Aimed and still, shots land on the front sight at 20 m; from the hip they scatter.
- [ ] A hit while aimed Descopes it like any gun.
- [ ] The bolt cycles on each shot and the magazine drops and seats on a reload.
- [ ] Keys 1 to 4 and the wheel reach all four weapons in order; a swap by key takes the swap time.
- [ ] `tests/run_all.sh` passes.

## Comments
