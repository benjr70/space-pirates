Type: prototype
Status: resolved
Blocked by: 06
Map: ../map.md

# What the Marksman Rifle looks like

## Question

What does the Marksman Rifle look like in the Viewmodel? No model exists. Build rough candidates headless in Blender from `tools/blender/` (it must read as a semi-automatic rifle with an 8-round magazine, distinct in silhouette from the Assault Rifle at a glance) and mount them in the Viewmodel so the user can judge them in first person at the hip, in Aim Down Sights and lowered. It carries open sights and no scope, as decided in [How the precision rifle aims](09-precision-rifle-aiming.md); the sights must read clearly at 3x zoom.

## Answer

Picked by playing: the Marksman Rifle is the **black bullpup**: the magazine behind the pistol grip, a slab polymer shell, a long barrel with brass rings, a full top rail with a hooded front post and rear aperture, and a brass cheek rest. The walnut long rifle is not used. No changes were asked for.

- **Hip pose.** (0.15, -0.2, -0.36) in camera space.
- **Aimed distance.** 0.36 ahead of the eye in Aim Down Sights.
- **Lowered pose.** Not tuned; the prototype used (0.20, -0.30, -0.36).

The model played was rough. What the build owes it:

- A finished pass at the Assault Rifle's standard: the shell is blocky, and its textures were baked at 1024, half the Assault Rifle's.
- A skeleton and clips (`kit.rig`, `kit.clip`): a bolt that cycles on each shot and a magazine that drops and seats behind the grip. Nothing moved in the prototype.
- Importing into `assets/models/` and a scene under `scenes/weapons/`.

**Prototype.** Branch `prototype/marksman-look` (local, never merged), commit 1c8b35c: `tools/blender/marksman.py` (builds both candidates; the starting point for the real model), `scenes/proto_marksman_look.tscn` and `scripts/proto/proto_marksman_look.gd`. To run it from that branch, build both with `flatpak run --filesystem=$PWD org.blender.Blender -b --python $PWD/tools/blender/marksman.py -- bullpup` (and `walnut`), copy the two `.glb` files from `tools/blender/out/` into `assets/models/proto_marksman/`, reimport, then `flatpak run org.godotengine.Godot --path . res://scenes/proto_marksman_look.tscn -- --seed=7 --class=large`. Draft renders of both are in `tools/blender/out/marksman_*.png` (untracked).
