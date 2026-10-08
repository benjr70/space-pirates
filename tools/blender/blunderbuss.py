"""Scatter blunderbuss: a wooden-stocked bell-mouth with an energy lock.

    flatpak run org.blender.Blender -b --python $PWD/tools/blender/blunderbuss.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from palette import metal, dark, wood, brass, glow

kit.reset()
body = []
BORE_Z = 0.050

# One piece of wood from forestock to butt, drawn as a side silhouette.
body.append(kit.prism("stock", [
    (-0.30, 0.012), (-0.30, 0.036), (0.10, 0.040), (0.16, 0.026), (0.22, -0.004),
    (0.37, -0.030), (0.39, -0.115), (0.355, -0.122), (0.325, -0.078), (0.20, -0.058),
    (0.13, -0.050), (0.09, -0.012), (-0.02, -0.006), (-0.26, 0.004),
], 0.040, wood(), bevel=0.006))
body.append(kit.box("butt_plate", (0.044, 0.010, 0.094), (0, 0.378, -0.074), brass(), bevel=0.002, rot=(-0.2, 0, 0)))

# Barrel, flaring to the bell.
body.append(kit.cyl("barrel", 0.019, 0.42, (0, -0.13, BORE_Z), material=dark(), sides=10))
body.append(kit.cyl("bell", 0.019, 0.11, (0, -0.395, BORE_Z), material=brass(), sides=10, radius2=0.046))
body.append(kit.cyl("bell_lip", 0.050, 0.012, (0, -0.456, BORE_Z), material=brass(), sides=10))
body.append(kit.cyl("bore", 0.038, 0.004, (0, -0.4615, BORE_Z), material=dark(), sides=10))
body.append(kit.cyl("bore_core", 0.016, 0.004, (0, -0.4625, BORE_Z), material=glow(), sides=10))
for y in (-0.28, -0.10):
    body.append(kit.box("band", (0.048, 0.016, 0.066), (0, y, 0.040), brass(), bevel=0.003))
body.append(kit.box("bead", (0.005, 0.008, 0.010), (0, -0.445, BORE_Z + 0.053), brass()))

# The lock: a metal housing with a cell glowing through both sides.
body.append(kit.prism("lock", [
    (0.02, 0.030), (0.02, 0.074), (0.05, 0.084), (0.13, 0.084), (0.16, 0.060), (0.16, 0.030),
], 0.048, metal(), bevel=0.004))
body.append(kit.cyl("cell", 0.015, 0.056, (0, 0.085, 0.056), axis="X", material=glow(), sides=8))
body.append(kit.cyl("cell_ring", 0.020, 0.052, (0, 0.085, 0.056), axis="X", material=brass(), sides=8))
body.append(kit.prism("hammer", [(0.135, 0.080), (0.150, 0.080), (0.185, 0.112), (0.170, 0.118), (0.150, 0.100)], 0.010, brass(), bevel=0.001))
body.append(kit.box("rear_notch_l", (0.005, 0.012, 0.010), (-0.007, 0.060, 0.089), dark()))
body.append(kit.box("rear_notch_r", (0.005, 0.012, 0.010), (0.007, 0.060, 0.089), dark()))

# Trigger guard and trigger, brass.
guard = kit.prism("guard", [(-0.010, 0.0), (0.105, -0.030), (0.110, -0.066), (0.0, -0.058)], 0.012, brass(), bevel=0.002)
kit.cut(guard, kit.prism("guard_hole", [(-0.003, 0.004), (0.100, -0.024), (0.103, -0.059), (0.005, -0.052)], 0.1))
body.append(guard)
body.append(kit.prism("trigger", [(0.050, -0.008), (0.062, -0.010), (0.056, -0.042), (0.048, -0.040)], 0.006, dark()))

blunderbuss = kit.join("Blunderbuss", body)
kit.marker("Muzzle", (0, -0.465, BORE_Z), blunderbuss)
kit.marker("SightTip", (0, -0.445, BORE_Z + 0.058), blunderbuss)

kit.report()
kit.export("blunderbuss")
kit.render("blunderbuss")
