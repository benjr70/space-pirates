"""PROTOTYPE, throwaway: one rough Attachment or more for each Slot of the
Assault Rifle, built in the rifle's own space so each sits where it mounts
(.scratch/weapon-attachments/issues/06-how-attachments-mount-on-a-gun.md).

    flatpak run org.blender.Blender -b --python $PWD/tools/blender/proto_ar_attachments.py [-- draft]
"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from palette import metal, bare, dark, glow

kit.reset()
BORE = 0.053
TOP = 0.079
UNDER = BORE - 0.025  # the handguard's underside
made = []


def part(name, objs):
    made.append(kit.join(name, objs))


# Sight: both sit on the rail over the receiver and take the irons' place.
EYE = TOP + 0.034
frame = kit.box("reflex_frame", (0.036, 0.006, 0.034), (0, 0.040, EYE), metal(), bevel=0.003)
kit.cut(frame, kit.box("reflex_window", (0.029, 0.05, 0.027), (0, 0.040, EYE), bevel=0.002))
part("ReflexSight", [
    kit.box("reflex_base", (0.030, 0.056, 0.012), (0, 0.062, TOP + 0.010), metal(), bevel=0.002),
    frame,
    kit.box("reflex_emitter", (0.010, 0.012, 0.008), (0, 0.084, TOP + 0.020), dark(), bevel=0.002),
    kit.box("reflex_dot", (0.0025, 0.0008, 0.0025), (0, 0.040, EYE), glow()),
])
kit.marker("ReflexSight_SightTip", (0, 0.040, EYE))

SCOPE = TOP + 0.038
part("CombatScope", [
    kit.tube("scope_tube", 0.016, 0.0135, 0.150, (0, 0.045, SCOPE), material=metal(), sides=24),
    kit.tube("scope_bell", 0.021, 0.0175, 0.036, (0, -0.045, SCOPE), material=metal(), sides=24),
    kit.tube("scope_eye", 0.019, 0.0155, 0.030, (0, 0.128, SCOPE), material=dark(), sides=24),
    kit.box("scope_ring_a", (0.022, 0.014, 0.026), (0, 0.010, TOP + 0.016), metal(), bevel=0.002),
    kit.box("scope_ring_b", (0.022, 0.014, 0.026), (0, 0.085, TOP + 0.016), metal(), bevel=0.002),
    kit.box("scope_turret", (0.014, 0.014, 0.012), (0, 0.048, SCOPE + 0.020), bare(), bevel=0.003),
    kit.box("scope_dot", (0.002, 0.0008, 0.002), (0, -0.030, SCOPE), glow()),
])
kit.marker("CombatScope_SightTip", (0, -0.030, SCOPE))

# Barrel: the Suppressor screws onto the rifle's own barrel; the other two
# take its place from the handguard's front (y = -0.385) forward.
part("Suppressor", [kit.lathe("can", [
    (-0.500, 0.0125), (-0.506, 0.0190), (-0.690, 0.0190), (-0.696, 0.0170), (-0.696, 0.0062), (-0.500, 0.0062),
], BORE, dark())] + [
    kit.lathe("can_band", [(-0.530 - i * 0.05, 0.0196), (-0.536 - i * 0.05, 0.0196)], BORE, bare(), sides=24) for i in range(3)
])
kit.marker("Suppressor_Muzzle", (0, -0.698, BORE))

part("LongBarrel", [
    kit.lathe("long", [
        (-0.385, 0.0090), (-0.610, 0.0090), (-0.610, 0.0100), (-0.616, 0.0100), (-0.616, 0.0118),
        (-0.672, 0.0118), (-0.676, 0.0108), (-0.676, 0.0062), (-0.618, 0.0062),
    ], BORE, bare()),
    kit.lathe("long_emitter", [(-0.626, 0.0060), (-0.622, 0.0060)], BORE, glow(), sides=16),
])
kit.marker("LongBarrel_Muzzle", (0, -0.678, BORE))

part("ShortBarrel", [
    kit.lathe("short", [
        (-0.385, 0.0100), (-0.392, 0.0100), (-0.392, 0.0125), (-0.432, 0.0125), (-0.436, 0.0112),
        (-0.436, 0.0062), (-0.394, 0.0062),
    ], BORE, bare()),
    kit.lathe("short_emitter", [(-0.402, 0.0060), (-0.398, 0.0060)], BORE, glow(), sides=16),
])
kit.marker("ShortBarrel_Muzzle", (0, -0.438, BORE))

# Magazine: both take the cell's place and ride its bone through the reload.
part("ExtendedMagazine", [
    kit.prism("ext", [(-0.090, -0.010), (-0.036, -0.010), (-0.060, -0.235), (-0.114, -0.235)], 0.026, dark(), bevel=0.004, segments=3),
    kit.prism("ext_floor", [(-0.117, -0.233), (-0.057, -0.233), (-0.058, -0.244), (-0.118, -0.244)], 0.031, dark(), bevel=0.002),
    kit.prism("ext_window", [(-0.071, -0.056), (-0.065, -0.056), (-0.082, -0.215), (-0.088, -0.215)], 0.0275, glow()),
])
part("Drum", [
    kit.prism("drum_neck", [(-0.090, -0.010), (-0.036, -0.010), (-0.042, -0.070), (-0.096, -0.070)], 0.026, dark(), bevel=0.004, segments=3),
    kit.cyl("drum_body", 0.058, 0.052, (0, -0.070, -0.110), axis="X", material=dark(), sides=32, bevel=0.004),
    kit.cyl("drum_hub", 0.016, 0.058, (0, -0.070, -0.110), axis="X", material=bare(), sides=20, bevel=0.002),
    kit.cyl("drum_glow", 0.040, 0.054, (0, -0.070, -0.110), axis="X", material=glow(), sides=32),
])

# Underbarrel: both clamp under the handguard and replace nothing.
part("Foregrip", [
    kit.box("grip_clamp", (0.030, 0.040, 0.010), (0, -0.250, UNDER - 0.004), metal(), bevel=0.002),
    kit.cyl("grip_post", 0.0145, 0.090, (0, -0.250, UNDER - 0.054), axis="Z", material=dark(), sides=20, bevel=0.004),
])
part("Laser", [
    kit.box("laser_clamp", (0.026, 0.030, 0.008), (0, -0.330, UNDER - 0.003), metal(), bevel=0.002),
    kit.box("laser_body", (0.024, 0.062, 0.022), (0, -0.335, UNDER - 0.018), dark(), bevel=0.004),
    kit.cyl("laser_lens", 0.006, 0.004, (0, -0.367, UNDER - 0.018), axis="Y", material=glow(), sides=16),
])
kit.marker("Laser_Origin", (0, -0.370, UNDER - 0.018))

# Stock: both take the skeleton butt's place on the receiver extension.
part("HeavyStock", [
    kit.prism("heavy", [
        (0.225, 0.080), (0.400, 0.080), (0.412, 0.068), (0.412, -0.074), (0.396, -0.086), (0.340, -0.086),
        (0.292, 0.016), (0.225, 0.030),
    ], 0.042, dark(), bevel=0.008, segments=3),
    kit.box("heavy_cheek", (0.036, 0.120, 0.016), (0, 0.300, 0.088), dark(), bevel=0.006),
    kit.prism("heavy_pad", [(0.412, 0.076), (0.428, 0.071), (0.428, -0.080), (0.412, -0.084)], 0.044, dark(), bevel=0.004, segments=3),
])
part("LightStock", [
    kit.box("light_plate", (0.030, 0.010, 0.100), (0, 0.380, 0.026), metal(), bevel=0.003),
    kit.box("light_collar", (0.032, 0.020, 0.032), (0, 0.366, 0.055), metal(), bevel=0.003),
    kit.box("light_strut", (0.008, 0.150, 0.008), (0, 0.305, -0.004), metal(), bevel=0.002, rot=(-0.22, 0, 0)),
])

kit.report()
kit.bake("proto_ar_attachments", made, size=1024)
kit.export("proto_ar_attachments")
kit.render("proto_ar_attachments")
