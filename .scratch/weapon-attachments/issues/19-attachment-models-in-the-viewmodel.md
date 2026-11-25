Status: resolved
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

- [x] (agent) For all 34 gun-and-Attachment pairs the Attachment's model is visible on the mounted gun and every part it replaces is hidden.
- [x] (agent) On the Assault Rifle, with a Suppressor the Viewmodel's muzzle is 0.168 m further forward than bare, and with the Long Barrel 0.156 m, each within 5 mm; the tracer starts there.
- [x] (agent) With any Sight fitted and aimed, the Sight's aim point is on the camera's axis within 1 mm.
- [x] (agent) Halfway through a reload an Extended Magazine and a Drum are displaced from rest by the same offset as the gun's own magazine bone, within 1 mm.
- [x] (agent) The Shotgun's Foregrip moves with the pump through a shot's cycle.
- [x] (agent) `tests/shots.sh attachments` shows every fitted part attached to its gun with no floating piece, gap or texture fault against the defect checklist.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) Every Attachment reads as what it is in first person and matches the guns, as it did in the prototype.

## Evidence

- All 34 pairs: `tests/attachment_model_checks.gd::_check_every_pair` (run in the `pirate` suite), which draws each gun bare and then built with each Attachment it takes, through the weapon wheel, and asserts the model named in its own table (the spec's list) is a visible mesh on the gun in hand, every part that Attachment replaces is hidden and every other part shows, and that 34 pairs were checked. Bare, every part shows and no Attachment model does. Mutation: with `hides` ignored it fails on 19 pairs.
- Assault Rifle muzzle and tracer: `tests/attachment_model_checks.gd::_check_muzzle`, which asserts the Viewmodel's Muzzle moved 0.168 m (Suppressor) and 0.156 m (Long Barrel) forward of bare within 0.005 m, and that a shot's bolt starts within 0.005 m of where the Attachment's own `Suppressor_Muzzle` / `AssaultRifle_LongBarrel_Muzzle` marker is drawn. Measured: Suppressor (0, 0, 0.168), Long Barrel (0, 0, 0.156); tracer 0.0000 m off the marker for both.
- Aim point on the axis: `tests/attachment_model_checks.gd::_check_aim_points`, which aims each Sight (Pistol, Assault Rifle and Shotgun Reflex Sight, Assault Rifle Combat Scope, also with a Long Barrel, Shotgun Reflex Sight with a Long Barrel, Marksman Rifle Long Scope) and the Shotgun's Long and Short Barrel bead with no Sight, waits out three aim times, and asserts the Attachment's own `_SightTip` marker is within 0.001 m of the camera axis. Measured: 0.0000 m in all nine.
- Magazines halfway through a reload: `tests/attachment_model_checks.gd::_check_magazines_ride`, which starts a tactical reload, waits half of it and asserts the Extended Magazine (Pistol, Assault Rifle, Marksman Rifle) and the Drum moved from rest, in the skeleton's space, by the magazine bone's own offset within 0.001 m, and that the bone moved over 0.01 m. Measured: off by 0.000000 to 0.000002 m.
- Shotgun Foregrip on the pump: `tests/attachment_model_checks.gd::_check_pump_and_slide_riders`, which fires and asserts at every frame of the shot's cycle that the Foregrip (and the Laser, and the Pistol's Reflex Sight on the slide) is displaced as its bone is, within 0.001 m, and that the bone moved over 0.01 m. Measured: pump travel 0.075 m, Foregrip and Laser off by at most 0.000001 m; slide 0.035 m, Reflex Sight 0.000002 m. Mutation: with riders off it fails all three.
- Screenshots: `tests/shots.sh attachments` PASS, 24 frames, in `.godot/shots/attachments/`; read against the defect checklist, no floating piece, gap, magenta or untextured surface in any:
  - `pistol_bare_side.png`, `pistol_bare_hip.png`: Pistol as before, own sights and magazine.
  - `pistol_a_side.png`: Reflex Sight on the slide over the kept sights, Suppressor on the muzzle, Laser under the frame, Extended Magazine out of the grip, no own magazine showing. `pistol_a_hip.png`: Suppressor and Reflex Sight window with its dot, attached.
  - `pistol_b_side.png`, `pistol_b_hip.png`: Reflex Sight and the brass-floored Quick Magazine flush with the grip.
  - `assault_rifle_bare_side.png`, `assault_rifle_bare_hip.png`: own barrel, iron sights, stock and cell.
  - `assault_rifle_a_side.png`, `assault_rifle_a_hip.png`: Reflex Sight in place of the iron sights, Short Barrel out of the handguard, Quick Magazine with loop, Laser under, Heavy Stock with cheek riser; no own sights.
  - `assault_rifle_b_side.png`, `assault_rifle_b_hip.png`: Combat Scope on its rings, Long Barrel, Drum in the well, Bipod under, Light Stock plate and strut.
  - `shotgun_bare_side.png`, `shotgun_bare_hip.png`: own barrel with heat shield and front sight, rear sight, stock.
  - `shotgun_a_side.png`, `shotgun_a_hip.png`: Reflex Sight, no front or rear sight, Long Barrel with rib and bead, Foregrip under the pump, Heavy Stock.
  - `shotgun_b_side.png`, `shotgun_b_hip.png`: no Sight: rear sight kept, front sight gone, Short Barrel's brass bead at the muzzle, Laser under the pump, Light Stock rods and plate.
  - `marksman_rifle_bare_side.png`, `marksman_rifle_bare_hip.png`: own barrel, sights, butt pad and magazine.
  - `marksman_rifle_a_side.png`, `marksman_rifle_a_hip.png`: Long Scope with shade and brass band, Suppressor, Extended Magazine, Foregrip, Heavy Stock riser and foot; no iron sights.
  - `marksman_rifle_b_side.png`, `marksman_rifle_b_hip.png`: Long Scope, Long Barrel with brass rings, Quick Magazine, Bipod, Light Stock plate.
- The gate: `tests/run_all.sh` on seed 519348002: every suite PASS (static 160, generator 341845, layouts 252, ship_3d 3681, pirate 1729, crew 205, sandbox 111, attachments 1674, raid_smoke 924 checks), total 201 s.

## Owed to playtest

- (human) Every Attachment reads as what it is in first person and matches the guns, as it did in the prototype.

## Comments

Built 2026-11-24 on `weapon-attachments-19`.

- `tools/blender/attachments.py` builds the 25 models from the prototype's geometry unchanged, baked to one atlas, imported as `assets/models/attachments/attachments.glb`. Each model's origin is set to the world origin after joining: the mount point for the seven shared models, the gun's origin for the eighteen per-gun ones, so both go on with an identity transform (the prototype's flaw is gone). Per-gun models are named after the gun's body mesh: `AssaultRifle_LongBarrel`, `MarksmanRifle_HeavyStock` (the prototype's `AR_` and `Marksman_`). Markers are children of the model that brings them (`<Model>_Muzzle`, `<Model>_SightTip`, `Laser_Origin`). Each scope's rear glass is pulled out as its own child mesh, `CombatScope_RearGlass` and `LongScope_RearGlass`, for ticket 20's lens; same geometry, same atlas.
- `Attachment` gains `model`, `models`, `mount`, `hides`, `rides` (per-gun ones keyed by the gun's body mesh name) and `model_on`, `hides_on`, `rides_on`. The fourteen files carry the prototype's tables.
- `scripts/weapon_model.gd` (`WeaponModel`) puts a Built Weapon's Attachments on any instance of a gun's model scene: `WeaponModel.of(model).fit(weapon)`, then `muzzle()`, `sight_tip()` and `model_of(attachment)`. It needs no tree, so a menu preview (ticket 22) can use it as it is. Riders hang on `BoneAttachment3D`s under the skeleton.
- The Viewmodel fits the weapon in hand in `_mount`, also when only the Built Weapon changed on the same gun, and takes its Muzzle and SightTip from `fitting`; the Attachment meshes come in with the gun, so `_flag_materials` flags them. No change to `player_3d.gd`.
- `tests/shots.sh attachments` added and documented in `docs/agents/validation.md` with a coverage row. Its two builds per gun show every Attachment model but the Assault Rifle's Suppressor and Extended Magazine, whose shared or sibling models show on the other guns.
- The muzzle numbers in the criteria matched the models: 0.168 and 0.156 m measured exactly.
- Found, not this ticket's: the gate on seed 398781113 failed one Raid in the smoke run, `tests/run_all.sh only=raid_smoke seed=398781113 class=medium ship=887517315 script=quiet`: "the ledger counts 6 kills with 7 crew down" at t=26.7 s. It fails the same on `cbc2ac2` without this ticket's changes, so it is an existing bug in the kill count (or the crew-down count), worth a ticket.
