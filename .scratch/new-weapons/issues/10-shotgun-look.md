Type: prototype
Status: resolved
Blocked by: 05
Map: ../map.md

# What the Shotgun looks like

## Question

Which model is the Shotgun in the Viewmodel: the pump-action boarding shotgun, the bell-mouth blunderbuss (both already built in `tools/blender/out/`), or a new build? Mount the candidates in the Viewmodel so the user can judge them in first person, including hip, Aim Down Sights and lowered poses.

## Answer

Picked by playing: the Shotgun is the **pump-action boarding shotgun** already built by `tools/blender/shotgun.py` (heat shield, side saddle of shells, pistol grip, ring sights). The bell-mouth blunderbuss is not used. No changes to the model were asked for.

- **Hip pose.** (0.15, -0.24, -0.34) in camera space.
- **Aimed distance.** 0.30 ahead of the eye in Aim Down Sights.
- **Lowered pose.** Not tuned. The prototype's guess of (0.20, -0.27, -0.34) now sits barely below the hip pose and needs dropping in the build.

What the build still owes the model, since the prototype faked or skipped it:

- It has no skeleton and no clips. The Viewmodel expects every weapon to bring an AnimationPlayer and a Skeleton3D, so `shotgun.py` needs `kit.rig` and `kit.clip` like the Assault Rifle's. Its fore-end is already a separate mesh named Pump.
- The pump after each shot was a stand-in: the fore-end travels 7.5 cm back and returns within 0.55 s, starting 0.15 s after the shot. That read well enough to keep as the starting point.
- There is no reload clip of any kind.
- The model is not in `assets/models/` yet, and has no scene under `scenes/weapons/`.

**Prototype.** Branch `prototype/shotgun-look` (local, never merged), commit 1d2c83e: `scenes/proto_shotgun_look.tscn` and `scripts/proto/proto_shotgun_look.gd`. To run it from that branch, first copy `tools/blender/out/shotgun.glb` and `blunderbuss.glb` into `assets/models/proto_shotgun/` and reimport, then `flatpak run org.godotengine.Godot --path . res://scenes/proto_shotgun_look.tscn -- --seed=7 --class=medium`.
