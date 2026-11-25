Status: ready-for-agent
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

- [ ] (agent) Each gun's imported model has the separate meshes and the mount markers listed above, by name.
- [ ] (agent) Each gun's `Muzzle` and `SightTip` are where they were before, within 1 mm.
- [ ] (agent) The fire, reload and rack clips still move the same bones; the existing `pirate` checks on rigs and clips pass unchanged.
- [ ] (agent) `tests/shots.sh viewmodel` for each of the four guns shows no missing part, hole or texture fault against the defect checklist, compared with shots taken before the change.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Each bare gun looks as it did, at the hip, aimed and through a reload.

## Comments
