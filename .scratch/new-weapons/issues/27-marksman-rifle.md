Status: resolved
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

- [x] One Marksman Rifle Headshot kills a crew member; two body shots kill.
- [x] Aimed and still, shots land on the front sight at 20 m; from the hip they scatter.
- [x] A hit while aimed Descopes it like any gun.
- [x] The bolt cycles on each shot and the magazine drops and seats on a reload.
- [x] Keys 1 to 4 and the wheel reach all four weapons in order; a swap by key takes the swap time.
- [x] `tests/run_all.sh` passes.

## Comments

Built 2026-11-22 on `new-weapons`.

- `resources/weapons/marksman_rifle.tres` holds the spec's numbers exactly. `ads_spread` is 0.0166667 (3 deg x 0.0167 = 0.05 deg aimed and still; 0.04 crouched) and `ads_moving_spread` 0.4 (1.2 deg). The spec gives no aimed kick, so `ads_recoil_kick_degrees` is 0, as on the Assault Rifle: the gun is braced in the shoulder. The hip push is the default 0.05. Lowered pose is (0.21, -0.32, -0.36).
- Model: `tools/blender/marksman_rifle.py`, the bullpup only, design unchanged. The finishing pass gave it a rounded fore-end with a nose cap and coil rings behind the vents, a shell with bigger bevels, panel lines, pins, a selector, a magazine release, a magazine-well lip, a right-hand ejection port with a liner and a brass deflector, a left-hand charging handle track, a cheek riser under the brass plate, a grooved butt pad, a sling slot, a closed trigger guard (the prototype's guard was an open bar) and a muzzle brake. Baked at 2048. Bones Body, Bolt (the bolt in the port plus the charging handle, which cycles on the left where the Viewmodel can see it) and Magazine. Clips: `fire` (bolt 4.5 cm back and home over 0.15 s), `reload` (the magazine drops 36 cm along its rake below the butt and a fresh one seats at 0.6 of the clip) and `rack`. Imported to `assets/models/marksman_rifle/`, scene `scenes/weapons/marksman_rifle_model.tscn`.
- Sounds: `assets/audio/firearm_library_marksman/shot.ogg` is the Tikka cut as picked; it holds one shot (silencedetect finds only the tail). The magazine take is split at its 0.4 s gap into `oga_gun_reload_sounds/rifle_magazine_out.ogg` (the release click) and `rifle_magazine_in.ogg` (the magazine going in and the slap home), so the second half plays as the magazine seats.
- Weapon Wheel: the Marksman Rifle is fourth. Input actions `weapon_1` to `weapon_4` sit on keys 1 to 4 and call `select_weapon(index)`, which goes through `switch_weapon`, so they have the same swap time and refusals. The key for the weapon already in hand does nothing.
- Checks: `test_pirate.gd` covers the wheel of four, the keys, the model, poses, sights and 3x zoom, the rig and reload sounds, the cones, aimed shots landing within 3 cm at 20 m while hip shots scatter, and the Descope. `test_crew.gd` checks that one Headshot or two body shots kill. `test_sandbox.gd` checks the fourth column. `bash tests/run_all.sh` passes: pirate 967, crew 181, sandbox 107.
- Not checked by eye or ear: how the model looks in first person at the hip, aimed and lowered; how the bolt and magazine clips look; how the split magazine sound lands against the clip. These are for the playtest.
