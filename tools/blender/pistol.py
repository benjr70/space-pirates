"""Sidearm: a full-size service pistol with a steel slide and frame.

    flatpak run org.blender.Blender -b --python $PWD/tools/blender/pistol.py [-- draft]
"""
import math
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from palette import metal, bare, dark, glow

kit.reset()
BORE = 0.018
RAKE = math.radians(18)
GRIP_AT = (0, 0.048, -0.014)
GRIP_ROT = (RAKE - math.pi / 2, 0, 0)


def down_grip(distance, back=0.0):
    """(y, z) of a point `distance` down the grip's axis, `back` behind it."""
    return (GRIP_AT[1] + distance * math.sin(RAKE) + back * math.cos(RAKE),
            GRIP_AT[2] - distance * math.cos(RAKE) + back * math.sin(RAKE))


body = []

# Frame: dust cover, trigger housing, beavertail.
body.append(kit.prism("frame", [
    (-0.118, 0.003), (0.078, 0.003), (0.093, -0.002), (0.091, -0.008), (0.076, -0.014), (0.072, -0.024),
    (0.020, -0.024), (0.012, -0.016), (-0.046, -0.016), (-0.052, -0.013), (-0.118, -0.013),
], 0.026, metal(), bevel=0.003, segments=3))
for i in range(4):
    body.append(kit.box("rail_lug", (0.021, 0.0055, 0.004), (0, -0.108 + i * 0.011, -0.0145), metal(), bevel=0.001, segments=1))

guard = kit.prism("guard", [
    (-0.052, -0.012), (0.046, -0.012), (0.046, -0.057), (-0.037, -0.057), (-0.052, -0.041),
], 0.012, metal(), bevel=0.0012)
kit.cut(guard, kit.prism("guard_hole", [
    (-0.047, -0.008), (0.060, -0.008), (0.060, -0.052), (-0.035, -0.052), (-0.047, -0.039),
], 0.1))
body.append(guard)

# Grip: an oval column with a flared base, and its screws.
grip = kit.loft("grip", [
    (-0.012, 0.000, 0.026, 0.050, 0.010, 0.010),
    (0.012, 0.000, 0.030, 0.052, 0.012, 0.012),
    (0.050, 0.001, 0.031, 0.053, 0.013, 0.013),
    (0.092, 0.002, 0.031, 0.056, 0.013, 0.013),
    (0.100, 0.002, 0.033, 0.058, 0.013, 0.013),
    (0.104, 0.002, 0.030, 0.054, 0.012, 0.012),
], dark(), rot=GRIP_ROT, at=GRIP_AT)
# Grooves down the front strap, where the fingers wrap.
for i in range(9):
    y, z = down_grip(0.022 + i * 0.008, back=-0.027)
    kit.cut(grip, kit.box("strap_groove", (0.018, 0.004, 0.0025), (0, y, z), rot=(RAKE, 0, 0)))
body.append(grip)
for distance in (0.024, 0.078):
    y, z = down_grip(distance, back=0.004)
    body.append(kit.pin("grip_screw", (0.0155, y, z), 0.0032, proud=0.0006, material=bare()))

# Barrel: the chamber shows in the ejection port, the muzzle stands proud.
body.append(kit.lathe("barrel", [
    (0.008, 0.0078), (-0.034, 0.0078), (-0.034, 0.0068), (-0.130, 0.0068), (-0.130, 0.0046), (-0.100, 0.0046),
], BORE, bare()))
body.append(kit.lathe("guide_rod", [(-0.110, 0.0032), (-0.1275, 0.0032), (-0.1275, 0.0)], 0.0065, bare(), sides=16))

# Controls on the left, where the thumb finds them.
body.append(kit.box("slide_stop", (0.003, 0.032, 0.005), (0.0143, -0.016, -0.003), bare(), bevel=0.001))
body.append(kit.pin("slide_stop_pin", (0.013, -0.030, -0.004), 0.003, proud=0.002, material=bare()))
body.append(kit.box("safety", (0.004, 0.022, 0.006), (0.0148, 0.064, -0.003), bare(), bevel=0.0015, rot=(-0.15, 0, 0)))
body.append(kit.pin("safety_axle", (0.013, 0.073, -0.006), 0.0035, proud=0.0015, material=bare()))
body.append(kit.pin("mag_release", (0.013, 0.018, -0.021), 0.0035, proud=0.0025, material=bare()))
body.append(kit.pin("frame_pin", (0.013, 0.050, -0.012), 0.0018, proud=0.0005, material=bare()))

# Hammer, cocked.
hammer = kit.prism("hammer", [
    (0.076, 0.004), (0.085, 0.006), (0.094, 0.018), (0.092, 0.026), (0.086, 0.027), (0.080, 0.016),
], 0.008, bare(), bevel=0.001)
kit.cut(hammer, kit.cyl("hammer_hole", 0.0028, 0.05, (0, 0.0885, 0.020), axis="X", sides=12))
body.append(hammer)

pistol = kit.join("Pistol", body)

# Slide: its own mesh, so a shot can cycle it. Sights ride on it.
slide = kit.loft("slide", [
    (-0.1265, 0.0150, 0.0235, 0.0230, 0.006, 0.001),
    (-0.1225, 0.0150, 0.0270, 0.0260, 0.007, 0.001),
    (0.0730, 0.0150, 0.0270, 0.0260, 0.007, 0.001),
    (0.0760, 0.0150, 0.0245, 0.0235, 0.006, 0.001),
], metal())
kit.cut(slide, kit.box("port", (0.016, 0.034, 0.016), (-0.008, -0.012, 0.025), bevel=0.002))
kit.cut(slide, kit.cyl("muzzle_hole", 0.0076, 0.02, (0, -0.125, BORE)))
kit.cut(slide, kit.cyl("rod_hole", 0.0038, 0.02, (0, -0.125, 0.0065), sides=16))
for i in range(8):
    for side in (-1, 1):
        kit.cut(slide, kit.box("serration", (0.0024, 0.0028, 0.022), (side * 0.0135, 0.028 + i * 0.0058, 0.0125), rot=(0.25, 0, 0)))
# A flat milled along each flank, the way a real slide is relieved.
for side in (-1, 1):
    kit.cut(slide, kit.box("flank", (0.0016, 0.120, 0.008), (side * 0.0135, -0.050, 0.0085), bevel=0.0006))
slide_parts = [slide]
slide_parts.append(kit.box("rear_sight", (0.020, 0.012, 0.0055), (0, 0.062, 0.0305), dark(), bevel=0.001))
kit.cut(slide_parts[-1], kit.box("rear_notch", (0.0040, 0.03, 0.0042), (0, 0.062, 0.0318)))
for side in (-1, 1):
    slide_parts.append(kit.cyl("rear_dot", 0.0011, 0.0006, (side * 0.0055, 0.0681, 0.0312), material=glow(), sides=8))
slide_parts.append(kit.prism("front_sight", [(-0.119, 0.0275), (-0.116, 0.0330), (-0.109, 0.0330), (-0.104, 0.0275)], 0.0035, dark(), bevel=0.0005))
slide_parts.append(kit.cyl("front_dot", 0.0011, 0.0006, (0, -0.1087, 0.0314), material=glow(), sides=8))
slide_parts.append(kit.box("extractor", (0.0016, 0.026, 0.003), (-0.0133, 0.018, 0.019), bare()))
slide = kit.join("Slide", slide_parts)

# Trigger and magazine are separate too, for the reload and the pull.
trigger = kit.join("Trigger", [kit.prism("trigger", [
    (-0.010, -0.014), (0.002, -0.014), (0.001, -0.024), (-0.003, -0.034), (-0.008, -0.043),
    (-0.012, -0.042), (-0.008, -0.033), (-0.006, -0.024),
], 0.006, bare(), bevel=0.001)])

magazine = kit.join("Magazine", [
    kit.loft("mag_body", [(0.004, 0.002, 0.019, 0.034, 0.003, 0.003), (0.104, 0.002, 0.019, 0.034, 0.003, 0.003)],
             bare(), rot=GRIP_ROT, at=GRIP_AT),
    kit.loft("mag_pad", [(0.104, 0.002, 0.028, 0.052, 0.010, 0.010), (0.108, 0.001, 0.031, 0.058, 0.011, 0.011),
                         (0.114, 0.000, 0.031, 0.060, 0.011, 0.011), (0.117, 0.000, 0.027, 0.056, 0.010, 0.010)],
             dark(), rot=GRIP_ROT, at=GRIP_AT),
])

kit.report()
kit.bake("pistol", [pistol, slide, trigger, magazine])

# Skeleton and the clips the Viewmodel plays, named in the Weapon Profile.
armature = kit.rig("Pistol", pistol, {"Slide": slide, "Trigger": trigger, "Magazine": magazine})
TRAVEL = (0, 0.038, 0)  # the slide's stroke, straight back
REST = (0, 0, 0)


def dropped(distance):
    """The magazine `distance` out of the grip, along the grip's rake."""
    return (0, distance * math.sin(RAKE), -distance * math.cos(RAKE))


kit.clip(armature, "fire", {
    "Slide": [(1, REST), (3, TRAVEL), (6, REST)],
    "Trigger": [(1, REST), (2, (0, 0.004, 0)), (5, REST)],
})
# The magazine falls clear of the view, and a fresh one comes up and seats.
kit.clip(armature, "reload", {
    "Magazine": [(1, REST), (6, dropped(0.12)), (10, dropped(0.5)), (16, dropped(0.5)),
                 (21, dropped(0.12)), (27, dropped(0.008)), (31, REST)],
})
kit.clip(armature, "rack", {
    "Slide": [(1, REST), (5, TRAVEL), (8, TRAVEL), (11, REST)],
})

kit.marker("Muzzle", (0, -0.131, BORE), pistol)
kit.marker("SightTip", (0, -0.1125, 0.0330), pistol)

kit.export("pistol")
kit.render("pistol")
