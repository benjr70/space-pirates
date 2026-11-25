"""PROTOTYPE, throwaway: all fourteen Attachments
(.scratch/weapon-attachments/issues/09-attachment-look.md).

    flatpak run org.blender.Blender -b --python $PWD/tools/blender/proto_attachments.py [-- draft]

Two kinds. A SHARED Attachment is one model built around its own origin, the
point where it meets a gun: every gun gives a mount point for it. A PER-GUN
Attachment takes the place of one of that gun's own parts, so it is built in
that gun's space, one model for each gun it fits, named `<Gun>_<Attachment>`.
"""
import math
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from palette import metal, bare, dark, brass, glow

kit.reset()
made = []


def part(name, objs):
    made.append(kit.join(name, objs))


def glass():
    return kit.surface("Glass", (0.02, 0.05, 0.08), rough=0.08, metallic=0.6, wear_amount=0.0, grain=0.0)


# ---------------------------------------------------------------- shared ---
# Sights: the origin is on top of the rail; -Y is toward the muzzle.
EYE = 0.026
frame = kit.box("reflex_frame", (0.036, 0.006, 0.034), (0, -0.022, EYE), metal(), bevel=0.003)
kit.cut(frame, kit.box("reflex_window", (0.029, 0.05, 0.027), (0, -0.022, EYE), bevel=0.002))
part("ReflexSight", [
    kit.box("reflex_base", (0.028, 0.056, 0.008), (0, 0.000, 0.004), metal(), bevel=0.002),
    frame,
    kit.box("reflex_hood", (0.014, 0.020, 0.010), (0, 0.018, 0.012), dark(), bevel=0.003),
    kit.box("reflex_dot", (0.0022, 0.0006, 0.0022), (0, -0.022, EYE), glow()),
])
kit.marker("ReflexSight_SightTip", (0, -0.022, EYE))


def scope(prefix, axis, front, rear, tube, bell, eyepiece):
    """A scope along Y from `front` to `rear`, its axis `axis` above the rail."""
    mid = (front + rear) / 2
    return [
        kit.tube(prefix + "_tube", tube, tube - 0.002, rear - front, (0, mid, axis), material=metal(), sides=28),
        kit.tube(prefix + "_bell", bell, bell - 0.003, 0.046, (0, front + 0.018, axis), material=metal(), sides=28),
        kit.tube(prefix + "_eye", eyepiece, eyepiece - 0.003, 0.034, (0, rear - 0.012, axis), material=dark(), sides=28),
        kit.cyl(prefix + "_glass_front", bell - 0.003, 0.002, (0, front + 0.004, axis), material=glass(), sides=28),
        kit.cyl(prefix + "_glass_rear", eyepiece - 0.003, 0.002, (0, rear - 0.004, axis), material=glass(), sides=28),
        kit.box(prefix + "_ring_a", (0.020, 0.014, axis), (0, mid - 0.030, axis / 2), metal(), bevel=0.002),
        kit.box(prefix + "_ring_b", (0.020, 0.014, axis), (0, mid + 0.030, axis / 2), metal(), bevel=0.002),
        kit.cyl(prefix + "_turret_top", 0.008, 0.012, (0, mid, axis + tube + 0.004), axis="Z", material=bare(), sides=16, bevel=0.001),
        kit.cyl(prefix + "_turret_side", 0.008, 0.012, (tube + 0.004, mid, axis), axis="X", material=bare(), sides=16, bevel=0.001),
    ]


part("CombatScope", scope("combat", 0.030, -0.085, 0.070, 0.0150, 0.0190, 0.0185))
kit.marker("CombatScope_SightTip", (0, 0.066, 0.030))
part("LongScope", scope("long", 0.036, -0.170, 0.085, 0.0160, 0.0260, 0.0200) + [
    kit.tube("long_shade", 0.0270, 0.0245, 0.050, (0, -0.190, 0.036), material=dark(), sides=28),
    kit.lathe("long_band", [(-0.150, 0.0268), (-0.144, 0.0268)], 0.036, brass(), sides=28),
])
kit.marker("LongScope_SightTip", (0, 0.081, 0.036))

# Suppressor: the origin is the muzzle's tip, on the bore. It slips back
# over whatever the gun ends in.
part("Suppressor", [kit.lathe("can", [
    (0.022, 0.0150), (0.016, 0.0168), (-0.160, 0.0168), (-0.166, 0.0150), (-0.166, 0.0055), (-0.150, 0.0055),
    (-0.150, 0.0142), (0.022, 0.0142),
], 0.0, dark())] + [
    kit.lathe("can_band", [(-0.020 - i * 0.045, 0.0174), (-0.026 - i * 0.045, 0.0174)], 0.0, bare(), sides=24) for i in range(3)
])
kit.marker("Suppressor_Muzzle", (0, -0.168, 0))

# Underbarrel: the origin is the gun's underside; everything hangs below it.
part("Foregrip", [
    kit.box("grip_clamp", (0.030, 0.042, 0.010), (0, 0, -0.005), metal(), bevel=0.002),
    kit.cyl("grip_post", 0.0150, 0.088, (0, 0.004, -0.054), axis="Z", material=dark(), sides=20, bevel=0.004, radius2=0.0135),
    kit.cyl("grip_cap", 0.0158, 0.006, (0, 0.004, -0.099), axis="Z", material=bare(), sides=20, bevel=0.002),
])
part("Laser", [
    kit.box("laser_clamp", (0.026, 0.030, 0.008), (0, 0, -0.004), metal(), bevel=0.002),
    kit.box("laser_body", (0.022, 0.058, 0.020), (0, -0.006, -0.018), dark(), bevel=0.004),
    kit.cyl("laser_lens", 0.0055, 0.004, (0, -0.036, -0.018), axis="Y", material=glow(), sides=16),
    kit.box("laser_switch", (0.006, 0.012, 0.004), (0.012, 0.004, -0.018), bare(), bevel=0.001),
])
kit.marker("Laser_Origin", (0, -0.039, -0.018))
part("Bipod", [
    kit.box("bipod_clamp", (0.034, 0.030, 0.012), (0, 0, -0.006), metal(), bevel=0.002),
    kit.cyl("bipod_hinge", 0.006, 0.044, (0, 0, -0.015), axis="X", material=bare(), sides=16),
] + [
    o for side in (-1, 1) for o in (
        kit.cyl("bipod_leg", 0.0045, 0.190, (side * 0.019, -0.098, -0.017), axis="Y", material=metal(), sides=14),
        kit.cyl("bipod_leg_inner", 0.0034, 0.050, (side * 0.019, -0.206, -0.017), axis="Y", material=bare(), sides=14),
        kit.box("bipod_foot", (0.012, 0.012, 0.016), (side * 0.019, -0.236, -0.017), dark(), bevel=0.003),
    )
])

# --------------------------------------------------------------- per gun ---
# Assault Rifle (bore 0.053; barrel leaves the handguard at y = -0.385).
B = 0.053
part("AR_LongBarrel", [
    kit.lathe("long", [
        (-0.385, 0.0090), (-0.610, 0.0090), (-0.610, 0.0100), (-0.616, 0.0100), (-0.616, 0.0118),
        (-0.672, 0.0118), (-0.676, 0.0108), (-0.676, 0.0062), (-0.618, 0.0062),
    ], B, bare()),
    kit.lathe("long_emitter", [(-0.626, 0.0060), (-0.622, 0.0060)], B, glow(), sides=16),
    kit.lathe("long_block", [(-0.470, 0.0125), (-0.490, 0.0125)], B, metal(), sides=24),
])
kit.marker("AR_LongBarrel_Muzzle", (0, -0.678, B))
part("AR_ShortBarrel", [
    kit.lathe("short", [
        (-0.385, 0.0100), (-0.392, 0.0100), (-0.392, 0.0130), (-0.432, 0.0130), (-0.436, 0.0116),
        (-0.436, 0.0062), (-0.394, 0.0062),
    ], B, bare()),
    kit.lathe("short_emitter", [(-0.402, 0.0060), (-0.398, 0.0060)], B, glow(), sides=16),
])
kit.marker("AR_ShortBarrel_Muzzle", (0, -0.438, B))
part("AR_ExtendedMagazine", [
    kit.prism("ext", [(-0.090, -0.010), (-0.036, -0.010), (-0.060, -0.235), (-0.114, -0.235)], 0.026, dark(), bevel=0.004, segments=3),
    kit.prism("ext_floor", [(-0.117, -0.233), (-0.057, -0.233), (-0.058, -0.244), (-0.118, -0.244)], 0.031, dark(), bevel=0.002),
    kit.prism("ext_window", [(-0.071, -0.056), (-0.065, -0.056), (-0.082, -0.215), (-0.088, -0.215)], 0.0275, glow()),
])
part("AR_QuickMagazine", [
    kit.prism("quick", [(-0.090, -0.010), (-0.036, -0.010), (-0.046, -0.105), (-0.100, -0.105)], 0.026, dark(), bevel=0.004, segments=3),
    kit.prism("quick_floor", [(-0.104, -0.103), (-0.042, -0.103), (-0.043, -0.114), (-0.105, -0.114)], 0.033, brass(), bevel=0.002),
    kit.prism("quick_window", [(-0.071, -0.050), (-0.065, -0.050), (-0.070, -0.092), (-0.076, -0.092)], 0.0275, glow()),
    kit.tube("quick_loop", 0.014, 0.010, 0.006, (0, -0.074, -0.128), axis="X", material=brass(), sides=20),
])
part("AR_Drum", [
    kit.prism("drum_neck", [(-0.090, -0.010), (-0.036, -0.010), (-0.042, -0.070), (-0.096, -0.070)], 0.026, dark(), bevel=0.004, segments=3),
    kit.cyl("drum_body", 0.058, 0.052, (0, -0.070, -0.110), axis="X", material=dark(), sides=32, bevel=0.004),
    kit.cyl("drum_face", 0.046, 0.056, (0, -0.070, -0.110), axis="X", material=metal(), sides=32, bevel=0.002),
    kit.tube("drum_ring", 0.036, 0.030, 0.058, (0, -0.070, -0.110), axis="X", material=glow(), sides=32),
    kit.cyl("drum_hub", 0.014, 0.062, (0, -0.070, -0.110), axis="X", material=bare(), sides=20, bevel=0.002),
])
part("AR_HeavyStock", [
    kit.prism("heavy", [
        (0.225, 0.080), (0.400, 0.080), (0.412, 0.068), (0.412, -0.074), (0.396, -0.086), (0.340, -0.086),
        (0.292, 0.016), (0.225, 0.030),
    ], 0.042, dark(), bevel=0.008, segments=3),
    kit.box("heavy_cheek", (0.036, 0.120, 0.016), (0, 0.300, 0.088), dark(), bevel=0.006),
    kit.prism("heavy_pad", [(0.412, 0.076), (0.428, 0.071), (0.428, -0.080), (0.412, -0.084)], 0.044, dark(), bevel=0.004, segments=3),
    kit.pin("heavy_bolt", (0.021, 0.250, 0.055), 0.005, proud=0.002, material=bare()),
])
part("AR_LightStock", [
    kit.box("light_plate", (0.030, 0.010, 0.100), (0, 0.380, 0.026), metal(), bevel=0.003),
    kit.box("light_collar", (0.032, 0.020, 0.032), (0, 0.366, 0.055), metal(), bevel=0.003),
    kit.box("light_strut", (0.008, 0.150, 0.008), (0, 0.305, -0.004), metal(), bevel=0.002, rot=(-0.22, 0, 0)),
])

# Pistol: the magazine runs down the grip, raked back 18 degrees.
RAKE = math.radians(18)
GRIP_AT, GRIP_ROT = (0, 0.048, -0.014), (RAKE - math.pi / 2, 0, 0)
part("Pistol_ExtendedMagazine", [
    kit.loft("pext_body", [(0.004, 0.002, 0.019, 0.034, 0.003, 0.003), (0.150, 0.002, 0.019, 0.034, 0.003, 0.003)],
             bare(), rot=GRIP_ROT, at=GRIP_AT),
    kit.loft("pext_sleeve", [(0.106, 0.002, 0.027, 0.050, 0.009, 0.009), (0.146, 0.002, 0.027, 0.050, 0.009, 0.009)],
             dark(), rot=GRIP_ROT, at=GRIP_AT),
    kit.loft("pext_pad", [(0.146, 0.002, 0.028, 0.052, 0.010, 0.010), (0.152, 0.001, 0.031, 0.058, 0.011, 0.011),
                          (0.158, 0.000, 0.031, 0.060, 0.011, 0.011), (0.161, 0.000, 0.027, 0.056, 0.010, 0.010)],
             dark(), rot=GRIP_ROT, at=GRIP_AT),
])
part("Pistol_QuickMagazine", [
    kit.loft("pq_body", [(0.004, 0.002, 0.019, 0.034, 0.003, 0.003), (0.104, 0.002, 0.019, 0.034, 0.003, 0.003)],
             bare(), rot=GRIP_ROT, at=GRIP_AT),
    kit.loft("pq_pad", [(0.104, 0.002, 0.030, 0.056, 0.010, 0.010), (0.108, 0.001, 0.036, 0.066, 0.012, 0.012),
                        (0.122, 0.000, 0.036, 0.068, 0.012, 0.012), (0.126, 0.000, 0.030, 0.060, 0.010, 0.010)],
             brass(), rot=GRIP_ROT, at=GRIP_AT),
])

# Shotgun (bore 0.060, magazine tube 0.0335; both leave the receiver at -0.140).
S, T = 0.060, 0.0335


def shotgun_barrel(prefix, muzzle, tube_end):
    return [
        kit.lathe(prefix, [(-0.140, 0.0125), (muzzle + 0.004, 0.0125), (muzzle, 0.0115), (muzzle, 0.0093), (muzzle + 0.042, 0.0093)], S, bare()),
        kit.lathe(prefix + "_tube", [(-0.140, 0.0120), (tube_end + 0.024, 0.0120), (tube_end + 0.024, 0.0132), (tube_end + 0.004, 0.0132),
                                     (tube_end, 0.0110), (tube_end, 0.0)], T, metal()),
        kit.box(prefix + "_clamp", (0.031, 0.012, 0.064), (0, tube_end + 0.046, 0.0465), metal(), bevel=0.011, segments=3),
        kit.box(prefix + "_bead_base", (0.012, 0.022, 0.006), (0, muzzle + 0.020, S + 0.0145), metal(), bevel=0.002),
        kit.cyl(prefix + "_bead", 0.0028, 0.006, (0, muzzle + 0.020, S + 0.0200), axis="Z", material=brass(), sides=12),
    ]


part("Shotgun_LongBarrel", shotgun_barrel("slong", -0.760, -0.576) + [
    kit.box("slong_rib", (0.008, 0.560, 0.004), (0, -0.440, S + 0.0140), metal(), bevel=0.001),
])
kit.marker("Shotgun_LongBarrel_Muzzle", (0, -0.762, S))
kit.marker("Shotgun_LongBarrel_SightTip", (0, -0.740, S + 0.023))
part("Shotgun_ShortBarrel", shotgun_barrel("sshort", -0.490, -0.478))
kit.marker("Shotgun_ShortBarrel_Muzzle", (0, -0.492, S))
kit.marker("Shotgun_ShortBarrel_SightTip", (0, -0.470, S + 0.023))
part("Shotgun_HeavyStock", [
    kit.loft("sheavy", [
        (0.150, 0.036, 0.034, 0.050, 0.014, 0.010),
        (0.220, 0.030, 0.040, 0.066, 0.015, 0.012),
        (0.330, 0.020, 0.046, 0.110, 0.016, 0.014),
        (0.425, 0.006, 0.046, 0.140, 0.014, 0.014),
    ], dark()),
    kit.box("sheavy_cheek", (0.040, 0.130, 0.018), (0, 0.330, 0.078), dark(), bevel=0.007),
    kit.loft("sheavy_pad", [(0.425, 0.006, 0.046, 0.140, 0.014, 0.014), (0.452, 0.006, 0.046, 0.140, 0.016, 0.016),
                            (0.458, 0.006, 0.040, 0.130, 0.015, 0.015)], dark()),
])
part("Shotgun_LightStock", [
    kit.loft("slight_wrist", [(0.150, 0.036, 0.032, 0.048, 0.014, 0.010), (0.185, 0.032, 0.026, 0.036, 0.010, 0.010)], dark()),
    kit.cyl("slight_rod_top", 0.006, 0.240, (0, 0.300, 0.040), axis="Y", material=metal(), sides=14),
    kit.box("slight_strut", (0.008, 0.215, 0.008), (0, 0.300, -0.010), metal(), bevel=0.002, rot=(-0.28, 0, 0)),
    kit.box("slight_plate", (0.030, 0.010, 0.120), (0, 0.424, -0.002), metal(), bevel=0.003),
])

# Marksman Rifle (bore 0.056, top 0.086): a bullpup, so its stock is the butt
# of the shell, and its barrel leaves the nose cap at y = -0.300.
M, TOP = 0.056, 0.086
part("Marksman_LongBarrel", [
    kit.lathe("mlong", [
        (-0.300, 0.0140), (-0.520, 0.0140), (-0.520, 0.0095), (-0.740, 0.0085), (-0.740, 0.0130),
        (-0.792, 0.0130), (-0.796, 0.0115), (-0.796, 0.0058), (-0.742, 0.0058),
    ], M, bare()),
] + [kit.lathe("mlong_ring", [(y, 0.0155), (y + 0.012, 0.0155)], M, brass(), sides=24) for y in (-0.330, -0.370, -0.410, -0.450, -0.490)]
  + [kit.lathe("mlong_flute", [(-0.786 + i * 0.012, 0.0136), (-0.780 + i * 0.012, 0.0136)], M, metal(), sides=24) for i in range(4)]
  + [kit.lathe("mlong_emitter", [(-0.750, 0.0056), (-0.746, 0.0056)], M, glow(), sides=16)])
kit.marker("Marksman_LongBarrel_Muzzle", (0, -0.796, M))
part("Marksman_ExtendedMagazine", [
    kit.prism("mext", [(0.150, 0.016), (0.222, 0.016), (0.209, -0.166), (0.137, -0.162)], 0.030, metal(), bevel=0.003, segments=3),
    kit.prism("mext_floor", [(0.134, -0.160), (0.212, -0.164), (0.211, -0.174), (0.133, -0.170)], 0.034, dark(), bevel=0.002),
    kit.prism("mext_window", [(0.180, -0.026), (0.187, -0.026), (0.176, -0.150), (0.169, -0.150)], 0.0315, glow()),
])
part("Marksman_QuickMagazine", [
    kit.prism("mquick", [(0.150, 0.016), (0.222, 0.016), (0.214, -0.096), (0.142, -0.092)], 0.030, metal(), bevel=0.003, segments=3),
    kit.prism("mquick_floor", [(0.136, -0.090), (0.220, -0.094), (0.219, -0.106), (0.135, -0.102)], 0.038, brass(), bevel=0.002),
    kit.prism("mquick_window", [(0.180, -0.026), (0.187, -0.026), (0.181, -0.082), (0.174, -0.082)], 0.0315, glow()),
    kit.tube("mquick_loop", 0.014, 0.010, 0.006, (0, 0.178, -0.118), axis="X", material=brass(), sides=20),
])
part("Marksman_HeavyStock", [
    kit.prism("mheavy_pad", [(0.356, 0.084), (0.386, 0.078), (0.386, -0.078), (0.356, -0.082)], 0.052, dark(), bevel=0.006, segments=3),
    kit.prism("mheavy_riser", [(0.180, TOP - 0.002), (0.192, TOP + 0.018), (0.326, TOP + 0.018), (0.340, TOP - 0.002)], 0.040, dark(), bevel=0.005),
    kit.box("mheavy_rest", (0.034, 0.116, 0.004), (0, 0.259, TOP + 0.020), brass(), bevel=0.0015),
    kit.cyl("mheavy_foot", 0.007, 0.050, (0, 0.320, -0.094), axis="Z", material=bare(), sides=14),
    kit.cyl("mheavy_pad_foot", 0.011, 0.006, (0, 0.320, -0.120), axis="Z", material=dark(), sides=14),
])
part("Marksman_LightStock", [
    kit.prism("mlight_plate", [(0.356, 0.070), (0.364, 0.068), (0.364, -0.066), (0.356, -0.068)], 0.036, metal(), bevel=0.002, segments=2),
])

kit.report()
kit.bake("proto_attachments", made)
kit.export("proto_attachments")
kit.render("proto_attachments")
