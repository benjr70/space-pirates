"""Marksman Rifle: a black bullpup with a long ringed barrel and open sights.

    flatpak run --filesystem=$PWD org.blender.Blender -b --python $PWD/tools/blender/marksman_rifle.py [-- draft]

The magazine sits behind the pistol grip and the action inside the butt,
under one polymer shell. A full top rail carries a hooded front post and a
rear aperture on one level line, which is all the gun aims with: no scope.
"""
import math
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import kit
from palette import metal, bare, dark, brass, glow

kit.reset()
body = []
BORE = 0.056
TOP = 0.086    # where the rail sits
HALF = 0.023   # half the shell's width
SIGHT = TOP + 0.040
FRONT_SIGHT, REAR_SIGHT = -0.270, 0.150


def groove(target, y0, z0, y1, z1, depth=0.0012, width=0.0016):
    """A panel line from (y0, z0) to (y1, z1), cut into both sides."""
    length = math.hypot(y1 - y0, z1 - z0)
    angle = math.atan2(z1 - z0, y1 - y0)
    for side in (-1, 1):
        kit.cut(target, kit.box("panel_line", (depth * 2, length, width),
                                (side * HALF, (y0 + y1) / 2, (z0 + z1) / 2), rot=(angle, 0, 0)))


# The fore-end: a rounded tube of the shell round the barrel, slotted so the
# coil that drives the bolt glows through.
forend = kit.loft("forend", [
    (-0.300, 0.058, 0.040, 0.052, 0.008, 0.010),
    (-0.294, 0.058, 0.046, 0.056, 0.010, 0.012),
    (-0.120, 0.054, 0.046, 0.064, 0.010, 0.012),
], dark())
for i in range(4):
    y = -0.270 + i * 0.045
    kit.cut(forend, kit.box("vent", (0.1, 0.030, 0.007), (0, y, BORE), bevel=0.003, segments=3))
    kit.cut(forend, kit.box("vent_under", (0.007, 0.030, 0.03), (0, y, 0.030), bevel=0.003, segments=3))
body.append(forend)
body.append(kit.lathe("coil", [(-0.292, 0.0066), (-0.110, 0.0066)], BORE, glow(), sides=16))
for i in range(9):
    body.append(kit.lathe("coil_ring", [(-0.288 + i * 0.022, 0.0088), (-0.283 + i * 0.022, 0.0088)], BORE, bare(), sides=16))
# A steel nose cap where the barrel leaves the shell.
body.append(kit.lathe("nose_cap", [(-0.296, 0.0190), (-0.306, 0.0190), (-0.309, 0.0165), (-0.309, 0.0140)], BORE, metal(), sides=24))

# The shell from the trigger back: grip, magazine well and butt in one
# moulding, its edges well rounded.
shell = kit.prism("shell", [
    (-0.125, 0.030), (-0.125, TOP), (0.345, TOP), (0.356, 0.074), (0.356, -0.066), (0.342, -0.074),
    (0.262, -0.074), (0.250, -0.016), (0.120, -0.012), (0.085, -0.004), (-0.085, -0.004), (-0.125, 0.020),
], HALF * 2, dark(), bevel=0.012, segments=5)
# Ejection port on the right, beside the cheek, over the magazine.
kit.cut(shell, kit.box("port", (0.014, 0.060, 0.017), (-HALF, 0.190, 0.060), bevel=0.003))
# The charging handle's track on the left.
kit.cut(shell, kit.box("handle_track", (0.008, 0.090, 0.007), (HALF, 0.150, 0.072), bevel=0.0015))
# The magazine well.
kit.cut(shell, kit.prism("magwell", [(0.148, 0.020), (0.224, 0.020), (0.222, -0.030), (0.146, -0.030)], 0.032))
# Panel lines: the receiver insert, the butt cap and the seam down the side.
groove(shell, -0.080, 0.003, -0.080, 0.074)
groove(shell, 0.300, 0.074, 0.300, -0.068)
groove(shell, -0.080, 0.032, 0.120, 0.032)
groove(shell, 0.120, 0.032, 0.250, 0.000)
# A sling slot through the butt.
kit.cut(shell, kit.box("sling_slot", (0.1, 0.030, 0.008), (0, 0.322, -0.040), bevel=0.003))
body.append(shell)
# Steel liners in the port and well, and a brass deflector behind the port.
body.append(kit.box("port_liner", (0.002, 0.064, 0.021), (-HALF + 0.007, 0.190, 0.060), metal()))
body.append(kit.box("deflector", (0.007, 0.012, 0.020), (-HALF - 0.002, 0.226, 0.060), brass(), bevel=0.003))
lip = kit.prism("magwell_lip", [(0.144, -0.006), (0.228, -0.010), (0.227, -0.024), (0.143, -0.020)], HALF * 2 + 0.003,
                metal(), bevel=0.002)
kit.cut(lip, kit.prism("magwell_lip_hole", [(0.149, 0.0), (0.223, 0.0), (0.222, -0.030), (0.148, -0.030)], 0.031))
body.append(lip)
for y, z, r in ((-0.060, 0.064, 0.0032), (0.040, 0.064, 0.0032), (0.272, 0.064, 0.0032), (0.020, 0.012, 0.0026),
                (0.105, 0.012, 0.0026), (0.338, -0.006, 0.0032)):
    body.append(kit.pin("pin", (HALF, y, z), r, proud=0.0008, material=bare()))
body.append(kit.pin("selector_axle", (HALF, 0.090, 0.020), 0.005, proud=0.002, material=bare()))
body.append(kit.box("selector", (0.004, 0.024, 0.006), (HALF + 0.003, 0.080, 0.022), bare(), bevel=0.001, rot=(-0.3, 0, 0)))
body.append(kit.box("mag_release", (HALF * 2 + 0.004, 0.010, 0.012), (0, 0.238, -0.030), bare(), bevel=0.002))
butt = kit.prism("butt_pad", [(0.356, 0.076), (0.370, 0.072), (0.370, -0.070), (0.356, -0.074)], HALF * 2 + 0.002, metal(),
                 bevel=0.004, segments=3)
for i in range(8):
    kit.cut(butt, kit.box("pad_groove", (0.1, 0.004, 0.003), (0, 0.370, -0.058 + i * 0.017)))
body.append(butt)
# A raised cheek riser, its top plated in brass.
body.append(kit.prism("cheek_riser", [(0.190, TOP - 0.002), (0.200, TOP + 0.006), (0.318, TOP + 0.006), (0.330, TOP - 0.002)],
                      0.036, dark(), bevel=0.003))
body.append(kit.box("cheek_rest", (0.032, 0.112, 0.004), (0, 0.260, TOP + 0.008), brass(), bevel=0.0015))
for y in (0.214, 0.306):
    body.append(kit.cyl("cheek_screw", 0.0026, 0.002, (0, y, TOP + 0.0105), axis="Z", material=bare(), sides=12))

# Pistol grip ahead of the magazine, and the trigger ahead of that.
RAKE = math.radians(18)
body.append(kit.loft("grip", [
    (-0.012, 0.000, 0.028, 0.046, 0.012, 0.012), (0.018, 0.000, 0.031, 0.042, 0.013, 0.013),
    (0.060, 0.001, 0.032, 0.045, 0.014, 0.014), (0.098, 0.002, 0.032, 0.050, 0.014, 0.014),
    (0.105, 0.002, 0.028, 0.046, 0.012, 0.012),
], dark(), rot=(RAKE - math.pi / 2, 0, 0), at=(0, 0.060, 0.000)))
guard = kit.prism("guard", [
    (-0.050, -0.004), (0.034, -0.004), (0.034, -0.018), (0.016, -0.047), (-0.036, -0.047), (-0.050, -0.033),
], 0.012, dark(), bevel=0.0012)
kit.cut(guard, kit.prism("guard_hole", [
    (-0.045, 0.004), (0.029, 0.004), (0.029, -0.017), (0.013, -0.042), (-0.033, -0.042), (-0.045, -0.030),
], 0.1))
body.append(guard)
body.append(kit.prism("trigger", [
    (-0.023, -0.004), (-0.012, -0.004), (-0.013, -0.014), (-0.017, -0.024), (-0.022, -0.033),
    (-0.026, -0.032), (-0.022, -0.023), (-0.020, -0.014),
], 0.006, bare(), bevel=0.001))

# A long fluted barrel out of the shell, ringed in brass.
body.append(kit.lathe("barrel", [
    (-0.300, 0.0140), (-0.470, 0.0140), (-0.470, 0.0095), (-0.600, 0.0085), (-0.600, 0.0130),
    (-0.652, 0.0130), (-0.656, 0.0115), (-0.656, 0.0058), (-0.602, 0.0058),
], BORE, bare()))
for y in (-0.330, -0.365, -0.400, -0.435):
    body.append(kit.lathe("barrel_ring", [(y, 0.0155), (y + 0.012, 0.0155)], BORE, brass(), sides=24))
for i in range(4):
    body.append(kit.lathe("muzzle_flute", [(-0.646 + i * 0.012, 0.0136), (-0.640 + i * 0.012, 0.0136)], BORE, metal(), sides=24))
body.append(kit.lathe("emitter", [(-0.610, 0.0056), (-0.606, 0.0056)], BORE, glow(), sides=16))

# Full-length top rail with a hooded front post and a rear aperture. The
# post's tip and the aperture's centre are both on SIGHT, so the eye behind
# the ring sees the tip in its middle.
body += kit.rail("rail", -0.292, 0.170, TOP, metal())
for side in (-1, 1):
    body.append(kit.prism("front_ear", [(FRONT_SIGHT - 0.011, TOP + 0.006), (FRONT_SIGHT - 0.007, SIGHT + 0.008),
                                        (FRONT_SIGHT + 0.005, SIGHT + 0.008), (FRONT_SIGHT + 0.011, TOP + 0.006)],
                          0.003, metal(), bevel=0.0008, x=side * 0.0105))
body.append(kit.box("front_base", (0.024, 0.024, 0.006), (0, FRONT_SIGHT, TOP + 0.009), metal(), bevel=0.002))
body.append(kit.box("front_post", (0.003, 0.003, SIGHT - TOP - 0.006), (0, FRONT_SIGHT, (SIGHT + TOP + 0.006) / 2), dark()))
body.append(kit.box("front_dot", (0.0032, 0.0008, 0.004), (0, FRONT_SIGHT + 0.0017, SIGHT - 0.002), glow()))
body.append(kit.box("rear_base", (0.024, 0.026, 0.008), (0, REAR_SIGHT, TOP + 0.010), metal(), bevel=0.002))
body.append(kit.box("rear_stem", (0.007, 0.004, SIGHT - TOP - 0.018), (0, REAR_SIGHT, (SIGHT + TOP) / 2 - 0.0005), metal()))
body.append(kit.tube("aperture", 0.0085, 0.0058, 0.003, (0, REAR_SIGHT, SIGHT), material=metal(), sides=24))

rifle = kit.join("MarksmanRifle", body)

# The magazine is its own mesh so a reload clip can drop and seat it.
magazine = kit.join("Magazine", [
    kit.prism("magazine", [(0.150, 0.016), (0.222, 0.016), (0.214, -0.096), (0.142, -0.092)], 0.030, metal(), bevel=0.003, segments=3),
    kit.prism("mag_floor", [(0.139, -0.090), (0.217, -0.094), (0.216, -0.104), (0.138, -0.100)], 0.034, dark(), bevel=0.002),
    kit.prism("mag_window", [(0.180, -0.026), (0.187, -0.026), (0.181, -0.082), (0.174, -0.082)], 0.0315, glow()),
    kit.prism("mag_spine", [(0.204, -0.030), (0.210, -0.030), (0.204, -0.086), (0.198, -0.086)], 0.0315, metal(), bevel=0.0008),
])

# So are the bolt in the right-hand port and the charging handle on the
# left, which cycle together on every shot.
bolt = kit.join("Bolt", [
    kit.box("bolt", (0.006, 0.056, 0.015), (-HALF + 0.0055, 0.190, 0.060), bare(), bevel=0.001),
    kit.box("bolt_lug", (0.0065, 0.008, 0.008), (-HALF + 0.0055, 0.168, 0.060), metal()),
    kit.box("handle_stem", (0.012, 0.008, 0.005), (HALF - 0.001, 0.112, 0.072), bare()),
    kit.box("charging_handle", (0.010, 0.014, 0.010), (HALF + 0.008, 0.112, 0.072), dark(), bevel=0.002),
])

kit.report()
kit.bake("marksman_rifle", [rifle, magazine, bolt])

# Skeleton and the clips the Viewmodel plays, named in the Weapon Profile.
# Keyed at 60 frames a second, from frame 0: the exporter times a key at its
# frame over the frame rate.
armature = kit.rig("MarksmanRifle", rifle, {"Bolt": bolt, "Magazine": magazine})
FPS = 60
bpy.context.scene.render.fps = FPS


def f(seconds):
    return round(seconds * FPS)


REST = (0, 0, 0)
STROKE = (0, 0.045, 0)  # the bolt's travel, straight back


def dropped(distance):
    """The magazine `distance` out of the well, along its rake, below the butt."""
    return (0, -0.095 * distance, -0.995 * distance)


# Played over the Profile's fire_cycle_time.
kit.clip(armature, "fire", {"Bolt": [(f(0), REST), (f(0.05), STROKE), (f(0.15), REST)]})
# The magazine falls clear of the view, and a fresh one comes up and seats
# about 0.6 of the way through, as the magazine-in sound plays.
kit.clip(armature, "reload", {
    "Magazine": [(f(0), REST), (f(0.10), dropped(0.06)), (f(0.20), dropped(0.36)), (f(0.40), dropped(0.36)),
                 (f(0.52), dropped(0.06)), (f(0.58), dropped(0.008)), (f(0.62), REST), (f(0.70), REST)],
})
kit.clip(armature, "rack", {"Bolt": [(f(0), REST), (f(0.10), STROKE), (f(0.18), STROKE), (f(0.26), REST), (f(0.30), REST)]})

kit.marker("Muzzle", (0, -0.656, BORE), rifle)
kit.marker("SightTip", (0, FRONT_SIGHT, SIGHT), rifle)
kit.marker("SightRear", (0, REAR_SIGHT, SIGHT), rifle)

kit.export("marksman_rifle")
kit.render("marksman_rifle")
