"""Boarding carbine: a short energy rifle on modern carbine lines.

    flatpak run org.blender.Blender -b --python $PWD/tools/blender/carbine.py [-- draft]
"""
import math
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from palette import metal, bare, dark, brass, glow

kit.reset()
body = []
BORE = 0.053
TOP = 0.079  # where the rail sits

# Upper receiver, with the ejection port on the right.
upper = kit.loft("upper", [
    (-0.105, 0.055, 0.036, 0.044, 0.008, 0.003),
    (-0.100, 0.055, 0.040, 0.048, 0.010, 0.003),
    (0.165, 0.055, 0.040, 0.048, 0.010, 0.003),
    (0.172, 0.055, 0.034, 0.042, 0.008, 0.003),
], metal())
kit.cut(upper, kit.box("port", (0.012, 0.058, 0.018), (-0.020, -0.030, 0.058), bevel=0.003))
kit.cut(upper, kit.box("handle_track", (0.004, 0.110, 0.007), (0.020, 0.020, 0.066), bevel=0.001))
body.append(upper)
body.append(kit.box("deflector", (0.007, 0.014, 0.016), (-0.0205, 0.010, 0.058), metal(), bevel=0.003))

# Lower receiver: magazine well, trigger housing, grip tang.
body.append(kit.prism("lower", [
    (-0.096, 0.034), (0.172, 0.034), (0.172, 0.004), (0.150, -0.004), (0.000, -0.004),
    (-0.026, -0.008), (-0.030, -0.042), (-0.094, -0.036),
], 0.034, metal(), bevel=0.003))
body.append(kit.prism("magwell_flare", [
    (-0.098, -0.022), (-0.026, -0.027), (-0.031, -0.044), (-0.097, -0.038),
], 0.039, metal(), bevel=0.003))
for y, z, r in ((-0.085, 0.022, 0.0035), (0.155, 0.020, 0.0035), (0.040, 0.014, 0.002), (0.072, 0.016, 0.002)):
    body.append(kit.pin("pin", (0.017, y, z), r, proud=0.0008, material=bare()))
body.append(kit.pin("selector_axle", (0.017, 0.095, 0.020), 0.005, proud=0.002, material=bare()))
body.append(kit.box("selector", (0.004, 0.024, 0.006), (0.020, 0.085, 0.022), bare(), bevel=0.001, rot=(-0.3, 0, 0)))
body.append(kit.box("mag_release", (0.004, 0.012, 0.014), (-0.0185, -0.012, 0.012), bare(), bevel=0.001))
body.append(kit.box("bolt_catch", (0.004, 0.010, 0.024), (0.0185, -0.040, 0.022), bare(), bevel=0.001))

guard = kit.prism("guard", [
    (-0.030, -0.004), (0.092, -0.004), (0.092, -0.018), (0.074, -0.047), (-0.030, -0.047),
], 0.012, metal(), bevel=0.0012)
kit.cut(guard, kit.prism("guard_hole", [
    (-0.040, 0.004), (0.087, 0.004), (0.087, -0.017), (0.071, -0.042), (-0.040, -0.042),
], 0.1))
body.append(guard)
body.append(kit.prism("trigger", [
    (0.035, -0.004), (0.046, -0.004), (0.045, -0.014), (0.041, -0.024), (0.036, -0.033),
    (0.032, -0.032), (0.036, -0.023), (0.038, -0.014),
], 0.006, bare(), bevel=0.001))

# Pistol grip.
RAKE = math.radians(20)
body.append(kit.loft("grip", [
    (-0.012, 0.000, 0.028, 0.046, 0.012, 0.012),
    (0.018, 0.000, 0.031, 0.042, 0.013, 0.013),
    (0.060, 0.001, 0.032, 0.045, 0.014, 0.014),
    (0.098, 0.002, 0.032, 0.050, 0.014, 0.014),
    (0.105, 0.002, 0.028, 0.046, 0.012, 0.012),
], dark(), rot=(RAKE - math.pi / 2, 0, 0), at=(0, 0.118, 0.000)))

# Handguard: slotted, so the coil that drives the bolt shows through.
handguard = kit.loft("handguard", [
    (-0.388, BORE, 0.034, 0.042, 0.012, 0.012),
    (-0.380, BORE, 0.040, 0.050, 0.015, 0.015),
    (-0.105, BORE, 0.040, 0.050, 0.015, 0.015),
], metal())
for i in range(6):
    y = -0.352 + i * 0.044
    kit.cut(handguard, kit.box("slot", (0.1, 0.030, 0.0075), (0, y, BORE), bevel=0.003, segments=3))
    kit.cut(handguard, kit.box("slot_under", (0.0075, 0.030, 0.03), (0, y, BORE - 0.022), bevel=0.003, segments=3))
body.append(handguard)
body.append(kit.lathe("coil", [(-0.378, 0.0062), (-0.108, 0.0062)], BORE, glow(), sides=16))
for i in range(13):
    body.append(kit.lathe("coil_ring", [(-0.374 + i * 0.022, 0.0085), (-0.369 + i * 0.022, 0.0085)], BORE, bare(), sides=16))
for y in (-0.372, -0.240, -0.115):
    body.append(kit.pin("handguard_screw", (0.020, y, BORE - 0.016), 0.0028, proud=0.0006, material=bare()))

# Barrel and a three-slot muzzle device, bored through.
hider = kit.lathe("barrel", [
    (-0.385, 0.0085), (-0.462, 0.0085), (-0.462, 0.0098), (-0.468, 0.0098), (-0.468, 0.0115),
    (-0.516, 0.0115), (-0.520, 0.0105), (-0.520, 0.0062), (-0.470, 0.0062),
], BORE, bare())
for i in range(3):
    kit.cut(hider, kit.box("hider_slot", (0.004, 0.026, 0.04), (0, -0.500, BORE), rot=(0, i * math.pi / 3, 0), bevel=0.0015))
body.append(hider)
body.append(kit.lathe("emitter", [(-0.476, 0.0060), (-0.472, 0.0060)], BORE, glow(), sides=16))

# Full-length top rail with folding-style iron sights.
body += kit.rail("rail", -0.378, 0.160, TOP, metal())
# The sight line runs level at SIGHT: the front post's tip and the centre of
# the rear ring are both on it, so the eye behind the ring sees the tip in its
# middle. The ring is wide and thin-walled, to be looked through, not at.
SIGHT = TOP + 0.037
FRONT_SIGHT, REAR_SIGHT = -0.345, 0.145
for y in (FRONT_SIGHT, REAR_SIGHT):
    body.append(kit.box("sight_base", (0.024, 0.026, 0.009), (0, y, TOP + 0.0135), metal(), bevel=0.002))
for side in (-1, 1):
    body.append(kit.prism("front_ear", [(FRONT_SIGHT - 0.011, TOP + 0.018), (FRONT_SIGHT - 0.007, SIGHT + 0.008),
                                        (FRONT_SIGHT + 0.005, SIGHT + 0.008), (FRONT_SIGHT + 0.011, TOP + 0.018)],
                          0.003, metal(), bevel=0.0008, x=side * 0.0105))
body.append(kit.box("front_post", (0.003, 0.003, 0.020), (0, FRONT_SIGHT, SIGHT - 0.010), dark()))
body.append(kit.box("front_dot", (0.0032, 0.0008, 0.004), (0, FRONT_SIGHT + 0.0017, SIGHT - 0.002), glow()))
body.append(kit.box("rear_stem", (0.007, 0.004, 0.012), (0, REAR_SIGHT, TOP + 0.0235), metal()))
body.append(kit.tube("aperture", 0.0085, 0.0058, 0.003, (0, REAR_SIGHT, SIGHT), material=metal(), sides=24))

# Stock: a receiver extension tube carrying a skeleton butt.
body.append(kit.lathe("extension", [(0.170, 0.0135), (0.176, 0.0145), (0.184, 0.0145), (0.184, 0.0125), (0.375, 0.0125)], 0.055, metal()))
stock = kit.prism("stock", [
    (0.235, 0.076), (0.385, 0.076), (0.396, 0.066), (0.396, -0.048), (0.384, -0.058), (0.358, -0.058),
    (0.300, 0.026), (0.235, 0.034),
], 0.034, dark(), bevel=0.007, segments=3)
kit.cut(stock, kit.prism("stock_window", [(0.326, 0.026), (0.374, 0.026), (0.374, -0.036), (0.364, -0.036)], 0.1, bevel=0.004))
body.append(stock)
butt = kit.prism("butt_pad", [(0.396, 0.074), (0.410, 0.070), (0.410, -0.054), (0.396, -0.056)], 0.036, dark(), bevel=0.004, segments=3)
for i in range(7):
    kit.cut(butt, kit.box("pad_groove", (0.1, 0.004, 0.003), (0, 0.410, -0.040 + i * 0.017)))
body.append(butt)
body.append(kit.box("stock_latch", (0.014, 0.034, 0.006), (0, 0.262, 0.031), bare(), bevel=0.002, rot=(0.12, 0, 0)))
body.append(kit.pin("sling_swivel", (0.017, 0.300, 0.058), 0.005, proud=0.002, material=bare()))

carbine = kit.join("Carbine", body)

# The power cell is its own mesh so a reload clip can drop and seat it.
cell = kit.join("Cell", [
    kit.prism("cell", [(-0.090, -0.010), (-0.036, -0.010), (-0.050, -0.150), (-0.104, -0.150)], 0.026, dark(), bevel=0.004, segments=3),
    kit.prism("cell_floor", [(-0.107, -0.148), (-0.047, -0.148), (-0.048, -0.158), (-0.108, -0.158)], 0.031, dark(), bevel=0.002),
    kit.prism("cell_window", [(-0.071, -0.056), (-0.065, -0.056), (-0.073, -0.136), (-0.079, -0.136)], 0.0275, glow()),
] + [
    kit.prism("cell_rib", [(-0.093 - i * 0.0027, -0.058 - i * 0.027), (-0.083 - i * 0.0027, -0.058 - i * 0.027),
                           (-0.0845 - i * 0.0027, -0.072 - i * 0.027), (-0.0945 - i * 0.0027, -0.072 - i * 0.027)],
              0.0285, dark(), bevel=0.001) for i in range(3)
])

# So are the bolt and its charging handle, which cycle on every shot.
bolt = kit.join("Bolt", [
    kit.box("bolt", (0.005, 0.054, 0.016), (-0.0150, -0.030, 0.058), bare(), bevel=0.001),
    kit.box("bolt_stem", (0.030, 0.012, 0.006), (0.006, -0.025, 0.066), bare()),
    kit.box("charging_handle", (0.012, 0.012, 0.009), (0.024, -0.025, 0.066), dark(), bevel=0.002),
])

kit.report()
kit.bake("carbine", [carbine, cell, bolt])

# Skeleton and the clips the Viewmodel plays, named in the Weapon Profile.
armature = kit.rig("Carbine", carbine, {"Bolt": bolt, "Cell": cell})
STROKE = (0, 0.050, 0)  # the bolt's travel, straight back
REST = (0, 0, 0)


def dropped(distance):
    """The cell `distance` out of the magazine well, along the well's rake."""
    return (0, -0.0995 * distance, -0.995 * distance)


kit.clip(armature, "fire", {"Bolt": [(1, REST), (2, STROKE), (4, REST)]})
# The cell falls clear of the view, and a fresh one comes up and seats.
kit.clip(armature, "reload", {
    "Cell": [(1, REST), (6, dropped(0.14)), (10, dropped(0.6)), (17, dropped(0.6)),
             (23, dropped(0.14)), (28, dropped(0.010)), (31, REST)],
})
kit.clip(armature, "rack", {"Bolt": [(1, REST), (5, STROKE), (8, STROKE), (11, REST)]})

kit.marker("Muzzle", (0, -0.522, BORE), carbine)
kit.marker("SightTip", (0, FRONT_SIGHT, SIGHT), carbine)
kit.marker("SightRear", (0, REAR_SIGHT, SIGHT), carbine)

kit.export("carbine")
kit.render("carbine")
