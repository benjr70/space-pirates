Status: resolved
Blocked by: none

# Guns with replaceable parts and mount points

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 4 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Models and mounting", `issues/06-how-attachments-mount-on-a-gun.md` and `issues/09-attachment-look.md`. Reference: `tools/blender/proto_split_gun.py` on branch `prototype/attachment-look`, which builds each gun from its own script with the parts split out by standing in for a few `kit` calls. Do it properly here: change `tools/blender/kit.py` and the four gun scripts so each gun is built this way without a wrapper.

- Every mesh stays its own object on the gun's one skeleton. A bone's mesh is named `<Bone>Mesh`.
- Separate meshes: Pistol: magazine. Assault Rifle: barrel, sights, stock, cell. Shotgun: barrel (with magazine tube, clamp and heat shield), front sight, rear sight, stock. Marksman Rifle: barrel, sights, butt pad with cheek riser, magazine.
- Mount points as named markers: `MountSight`, `MountMuzzle` (not on the Shotgun), `MountUnder`, at the positions in the prototype's wrapper.
- One baked atlas per gun, as today. Re-export and re-import the four `.glb` files. The Viewmodel and the model scenes under `scenes/weapons/` keep working.

Bare, nothing looks or plays differently.

## Acceptance criteria

- [x] (agent) Each gun's imported model has the separate meshes and the mount markers listed above, by name.
- [x] (agent) Each gun's `Muzzle` and `SightTip` are where they were before, within 1 mm.
- [x] (agent) The fire, reload and rack clips still move the same bones; the existing `pirate` checks on rigs and clips pass unchanged.
- [x] (agent) `tests/shots.sh viewmodel` for each of the four guns shows no missing part, hole or texture fault against the defect checklist, compared with shots taken before the change.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) Each bare gun looks as it did, at the hip, aimed and through a reload.

## Evidence

- Separate meshes and mount markers: `tests/gun_model_checks.gd::_check_meshes` asserts each imported `.glb` has exactly these MeshInstance3D nodes, all skinned to its one Skeleton3D: Pistol `Pistol`, `SlideMesh`, `TriggerMesh`, `MagazineMesh`; Assault Rifle `AssaultRifle`, `Barrel`, `Sights`, `Stock`, `CellMesh`, `BoltMesh`; Shotgun `Shotgun`, `Barrel` (with magazine tube, clamp and heat shield), `FrontSight`, `Sights` (rear sight), `Stock`, `PumpMesh`, `ShellMesh`; Marksman Rifle `MarksmanRifle`, `Barrel`, `Sights`, `Stock` (butt pad and cheek riser), `MagazineMesh`, `BoltMesh`. `_check_markers` asserts `MountSight`, `MountMuzzle` and `MountUnder` on each gun within 1 mm of the prototype wrapper's positions, and that the Shotgun has no `MountMuzzle`. `_check_rig` asserts each `<Bone>Mesh` is weighted only to its bone and every other mesh only to `Body`. Run by the `pirate` suite (`tests/test_pirate.gd`, `GunModelChecks.run`).
- Muzzle and SightTip in place: `tests/gun_model_checks.gd::_check_markers` asserts `Muzzle`, `SightTip` (and `SightRear` on the two rifles) within 0.001 m of the places read from the models before the change (Pistol Muzzle (0, 0.018, 0.131), SightTip (0, 0.033, 0.1125); Assault Rifle (0, 0.053, 0.522), (0, 0.116, 0.345); Shotgun (0, 0.060, 0.604), (0, 0.111, 0.584); Marksman Rifle (0, 0.056, 0.656), (0, 0.126, 0.270)). The checks were written and passed against the old models first, then failed only on the new meshes and mounts until the rebuild.
- Same bones: `tests/gun_model_checks.gd::_check_rig` asserts the bone list is unchanged (no `_2` renames) and the bones each clip actually moves, recorded from the old models: Pistol fire Slide+Trigger, reload Magazine, rack Slide; Assault Rifle fire Bolt, reload Cell, rack Bolt; Shotgun fire Pump, shell Shell, pump Pump; Marksman Rifle fire Bolt, reload Magazine, rack Bolt. A one-off comparison of the old and new `.glb` clips gave identical moved bones, travel and key counts. The existing `test_pirate.gd` rig and clip checks (`_check_shotgun_rig`, `_check_marksman_rifle_rig`, `_check_pistol_clips`, `_check_holder_model`, `_check_clips_play`) pass unchanged: `pirate movement and gunplay: PASS (1143 checks, 6 s)`.
- Screenshots: `tests/shots.sh viewmodel wheel=<0..3> out=.godot/shots/before/w<n>` before and `.godot/shots/after/w<n>` after, all PASS the automatic checks; side by side in `.godot/shots/compare_w<n>.png`. Each gun's model reads identical before and after; differences are only the crew's idle pose and the tracer and flash in flight.
  - Pistol `after/w0/hip.png`: slide, frame and rail lower right, no gap or fault. `ads.png`: rear sight with both glow dots, front sight centred. `low.png`: pistol lowered out of view bottom right, as before. `tracer.png`: pistol, tracer and flash, no fault.
  - Assault Rifle `after/w1/hip.png`: receiver, rail, rear aperture, handguard and cell all there, barrel meets the handguard with no gap. `ads.png`: aperture with front post centred. `low.png`: rifle tilted up, barrel, front sight and rail whole. `tracer.png`: rifle as at the hip.
  - Shotgun `after/w2/hip.png`: receiver, shell saddle, ghost ring, heat shield and counter whole. `ads.png`: ghost ring and front post, red shells left. `low.png`: shield, barrel and front sight whole. `tracer.png`: pellets and flash, gun whole.
  - Marksman Rifle `after/w3/hip.png`: rail, rear aperture, receiver whole. `ads.png`: aperture and post centred, brass cheek rest. `low.png`: barrel with brass rings, muzzle flutes and front sight whole. `tracer.png`: rifle as at the hip.
  - No mesh missing, no magenta or untextured surface, nothing floating or clipping the camera in any of the 16.
- Gate: `tests/run_all.sh` ends `total: 205 s` with every suite PASS: static 142, generator 341845, layouts 252, ship_3d 3681, pirate 1143, crew 200, sandbox 107, raid_smoke 906.

## Owed to playtest

- (human) Each bare gun looks as it did, at the hip, aimed and through a reload.

## Comments

Built 2026-11-24 on branch `weapon-attachments-18`.

- `tools/blender/kit.py`: new `kit.split(name, objs, parts)` joins the body like `kit.join` but pulls each replaceable part's pieces (by the names they were made with) into a mesh of its own, and raises if a listed piece name matches nothing. `kit.rig(name, body, bones, still=None)` no longer joins anything: every mesh stays its own object with an Armature modifier on the one skeleton, `still` meshes on `Body`, and each bone's mesh is renamed `<Bone>Mesh`. One atlas per gun as before: the scripts pass the split parts to `kit.bake`.
- The four gun scripts call `kit.split` with the prototype's part lists, pass the parts to `kit.bake` and `kit.rig`, and add `MountSight`, `MountMuzzle` (not the Shotgun) and `MountUnder` with `kit.marker` at the prototype's positions, parented to the body like `Muzzle`. No wrapper; `proto_split_gun.py` is not needed.
- Part mesh names follow the prototype so the mounting code can lift from it: `Barrel`, `Sights`, `Stock`, and the Shotgun's `FrontSight` (its rear sight is `Sights`).
- All four `.glb` re-baked, re-exported and re-imported. `scripts/viewmodel.gd` and `scenes/weapons/*_model.tscn` unchanged.
- New checks in `tests/gun_model_checks.gd`, called with one line from `tests/test_pirate.gd`; coverage row added to `docs/agents/validation.md`.
- Note for the mounting ticket: every marker hangs off the body mesh, so the Pistol's `MountSight` does not ride the slide. Ticket 09 says the Reflex Sight moves with the slide, and the Shotgun's Foregrip and Laser with the pump, so the mounting code has to put those on the `Slide` or `Pump` bone (a BoneAttachment3D, say).
