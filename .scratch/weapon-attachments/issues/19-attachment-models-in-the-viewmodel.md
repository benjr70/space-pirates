Status: ready-for-agent
Blocked by: 16, 18

# Attachment models on the gun in hand

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 5 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Models and mounting", `issues/06` and `issues/09`. Reference: branch `prototype/attachment-look`: `tools/blender/proto_attachments.py` (all 25 models) and `scripts/proto/proto_attachment_look.gd` (the mounting, per-gun tables, markers and riders). Lift the models as they are; the user accepted their look.

- The 25 models built by a real script under `tools/blender/`, baked and imported: seven shared (Reflex Sight, Combat Scope, Long Scope, Suppressor, Foregrip, Laser, Bipod), each with its origin at its mount point; eighteen per gun.
- The Attachment Resource says, per gun where it differs, which model it shows, whether it hides one of the gun's parts and which, and what it rides.
- When the Viewmodel mounts a Built Weapon it shows each fitted Attachment's model, hides the parts those replace, and takes `Muzzle` and `SightTip` from a fitted Barrel or Sight in place of the gun's. The Shotgun's own front sight shows only with its own barrel and no Sight; its Long and Short Barrel bring a bead that is the aim point when no Sight is fitted.
- Magazines ride the magazine's bone; the Shotgun's Foregrip and Laser ride the pump; the Pistol's Reflex Sight rides the slide.
- Added meshes get the Viewmodel's material flags.
- A `tests/shots.sh attachments` preset: each gun bare and in two full builds, side-on and at the hip. Document it in `docs/agents/validation.md`.

Poses stay the weapon's own. The lens view and the Laser's dot are later tickets: scopes here have dark glass.

## Acceptance criteria

- [ ] (agent) For all 34 gun-and-Attachment pairs the Attachment's model is visible on the mounted gun and every part it replaces is hidden.
- [ ] (agent) On the Assault Rifle, with a Suppressor the Viewmodel's muzzle is 0.168 m further forward than bare, and with the Long Barrel 0.156 m, each within 5 mm; the tracer starts there.
- [ ] (agent) With any Sight fitted and aimed, the Sight's aim point is on the camera's axis within 1 mm.
- [ ] (agent) Halfway through a reload an Extended Magazine and a Drum are displaced from rest by the same offset as the gun's own magazine bone, within 1 mm.
- [ ] (agent) The Shotgun's Foregrip moves with the pump through a shot's cycle.
- [ ] (agent) `tests/shots.sh attachments` shows every fitted part attached to its gun with no floating piece, gap or texture fault against the defect checklist.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Every Attachment reads as what it is in first person and matches the guns, as it did in the prototype.

## Comments
