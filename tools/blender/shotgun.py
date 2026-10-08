"""Boarding shotgun: a pump-action 12-bore with a heat shield and side saddle.

    flatpak run org.blender.Blender -b --python $PWD/tools/blender/shotgun.py [-- draft]
"""
import math
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
from palette import metal, bare, dark, brass, glow, hull

kit.reset()
body = []
BORE = 0.060   # height of the barrel's axis
TUBE = 0.0335  # height of the magazine tube's axis

# Receiver: round-topped, flat-sided, dropping away at the wrist.
receiver = kit.loft("receiver", [
    (-0.142, 0.046, 0.036, 0.070, 0.012, 0.004),
    (-0.134, 0.046, 0.042, 0.078, 0.014, 0.004),
    (0.090, 0.046, 0.042, 0.078, 0.014, 0.004),
    (0.150, 0.038, 0.040, 0.060, 0.014, 0.006),
    (0.166, 0.036, 0.036, 0.052, 0.014, 0.008),
], metal())
# Ejection port on the right, with the bolt showing through it.
kit.cut(receiver, kit.box("port", (0.012, 0.072, 0.024), (-0.021, -0.045, 0.062), bevel=0.003))
# Loading port underneath.
kit.cut(receiver, kit.box("loading_port", (0.024, 0.080, 0.010), (0, -0.075, 0.007), bevel=0.003))
body.append(receiver)
body.append(kit.box("bolt", (0.006, 0.068, 0.021), (-0.0155, -0.045, 0.062), bare(), bevel=0.001))
body.append(kit.box("bolt_notch", (0.0065, 0.010, 0.010), (-0.0155, -0.060, 0.062), dark()))
body.append(kit.box("lifter", (0.021, 0.074, 0.002), (0, -0.075, 0.0105), bare(), rot=(0.04, 0, 0)))
for y, z, r in ((-0.030, 0.022, 0.003), (0.070, 0.020, 0.003), (-0.115, 0.050, 0.0035)):
    body.append(kit.pin("pin", (0.021, y, z), r, proud=0.0008, material=bare()))

# Trigger group.
body.append(kit.prism("trigger_housing", [
    (-0.025, 0.010), (0.140, 0.010), (0.140, -0.004), (0.100, -0.008), (-0.012, -0.008),
], 0.034, dark(), bevel=0.003))
# The guard is a 5 mm strip: keep its bevel well under half of that, or the
# bevel folds over and fills the loop in.
guard = kit.prism("guard", [
    (0.000, -0.006), (0.090, -0.006), (0.090, -0.020), (0.073, -0.047), (0.015, -0.047), (-0.001, -0.031),
], 0.014, dark(), bevel=0.0012)
kit.cut(guard, kit.prism("guard_hole", [
    (0.004, 0.000), (0.085, 0.000), (0.085, -0.019), (0.070, -0.042), (0.018, -0.042), (0.004, -0.029),
], 0.1))
body.append(guard)
body.append(kit.prism("trigger", [
    (0.045, -0.006), (0.056, -0.006), (0.055, -0.016), (0.051, -0.026), (0.046, -0.035),
    (0.042, -0.034), (0.046, -0.025), (0.048, -0.016),
], 0.006, bare(), bevel=0.001))
body.append(kit.pin("safety", (0.017, 0.100, 0.001), 0.004, proud=0.002, material=bare()))
body.append(kit.box("slide_release", (0.004, 0.012, 0.008), (0.018, -0.008, -0.002), bare(), bevel=0.001))

# Pistol grip: an oval column, raked back.
RAKE = math.radians(17)
body.append(kit.loft("grip", [
    (-0.010, 0.000, 0.030, 0.050, 0.013, 0.013),
    (0.020, 0.000, 0.033, 0.045, 0.014, 0.014),
    (0.060, 0.001, 0.034, 0.047, 0.015, 0.015),
    (0.100, 0.002, 0.034, 0.052, 0.015, 0.015),
    (0.108, 0.002, 0.030, 0.048, 0.013, 0.013),
], dark(), rot=(RAKE - math.pi / 2, 0, 0), at=(0, 0.112, 0.000)))

# Stock: slim at the wrist, deep at the butt, with a sling slot.
stock = kit.loft("stock", [
    (0.150, 0.036, 0.032, 0.048, 0.014, 0.010),
    (0.220, 0.027, 0.035, 0.058, 0.015, 0.012),
    (0.330, 0.012, 0.039, 0.092, 0.016, 0.014),
    (0.425, -0.002, 0.040, 0.124, 0.014, 0.014),
], dark())
kit.cut(stock, kit.box("sling_slot", (0.1, 0.034, 0.008), (0, 0.375, -0.012), bevel=0.003))
body.append(stock)
body.append(kit.loft("butt_plate", [
    (0.425, -0.002, 0.041, 0.125, 0.014, 0.014),
    (0.429, -0.002, 0.041, 0.125, 0.014, 0.014),
], bare()))
butt = kit.loft("butt_pad", [
    (0.429, -0.002, 0.040, 0.124, 0.014, 0.014),
    (0.447, -0.002, 0.040, 0.124, 0.016, 0.016),
    (0.452, -0.002, 0.034, 0.116, 0.015, 0.015),
], dark())
for i in range(7):
    kit.cut(butt, kit.box("pad_groove", (0.1, 0.004, 0.003), (0, 0.4405, -0.050 + i * 0.016)))
body.append(butt)

# Barrel, bored at the muzzle, over the magazine tube.
body.append(kit.lathe("barrel", [
    (-0.140, 0.0125), (-0.598, 0.0125), (-0.602, 0.0115), (-0.602, 0.0093), (-0.560, 0.0093),
], BORE, bare()))
body.append(kit.lathe("mag_tube", [
    (-0.140, 0.0120), (-0.552, 0.0120), (-0.552, 0.0132), (-0.572, 0.0132), (-0.576, 0.0110), (-0.576, 0.0050),
    (-0.580, 0.0050), (-0.580, 0.0),
], TUBE, metal()))
body.append(kit.box("clamp", (0.031, 0.012, 0.064), (0, -0.530, 0.0465), metal(), bevel=0.011, segments=3))
body.append(kit.pin("clamp_bolt", (0.0155, -0.530, 0.0468), 0.0035, material=bare()))
body.append(kit.cyl("sling_stud", 0.004, 0.014, (0, -0.530, 0.012), axis="Z", material=bare(), sides=12))

# Heat shield: a perforated half-pipe standing off the barrel.
shield = kit.tube("shield", 0.0190, 0.0165, 0.320, (0, -0.310, BORE), material=metal(), sides=32)
kit.cut(shield, kit.box("shield_under", (0.1, 0.4, 0.04), (0, -0.31, BORE - 0.024)))
for i in range(14):
    y = -0.168 - i * 0.022
    kit.cut(shield, kit.cyl("vent", 0.0048, 0.1, (0, y, BORE + 0.007), axis="X", sides=12))
    if i < 13:
        kit.cut(shield, kit.cyl("vent_top", 0.0048, 0.05, (0, y - 0.011, BORE + 0.03), axis="Z", sides=12))
body.append(shield)
for y in (-0.160, -0.462):
    body.append(kit.box("shield_strap", (0.040, 0.008, 0.012), (0, y, BORE - 0.002), metal(), bevel=0.002))

# Sights: a ghost ring on a short rail, and a winged post up front.
body += kit.rail("rail", -0.105, 0.065, 0.084, metal())
body.append(kit.box("rear_base", (0.020, 0.022, 0.008), (0, 0.045, 0.099), metal(), bevel=0.002))
ring = kit.tube("ghost_ring", 0.0075, 0.0048, 0.005, (0, 0.045, 0.111), material=metal(), sides=20)
body.append(ring)
for side in (-1, 1):
    body.append(kit.prism("rear_wing", [(0.034, 0.103), (0.034, 0.118), (0.040, 0.122), (0.052, 0.122), (0.056, 0.103)],
                          0.003, metal(), bevel=0.0008, x=side * 0.0105))
    body.append(kit.prism("front_wing", [(-0.596, BORE + 0.012), (-0.592, BORE + 0.052), (-0.580, BORE + 0.052), (-0.566, BORE + 0.012)],
                          0.0025, metal(), bevel=0.0008, x=side * 0.0075))
body.append(kit.box("front_base", (0.018, 0.034, 0.008), (0, -0.581, BORE + 0.013), metal(), bevel=0.002))
body.append(kit.box("front_post", (0.0028, 0.0028, 0.036), (0, -0.584, BORE + 0.033), metal()))
body.append(kit.box("front_dot", (0.003, 0.001, 0.003), (0, -0.5826, BORE + 0.0485), glow()))

# Side saddle: five spare shells on the left of the receiver.
body.append(kit.box("saddle", (0.005, 0.124, 0.034), (0.0235, -0.058, 0.044), dark(), bevel=0.002))
for i in range(5):
    y = -0.104 + i * 0.023
    body.append(kit.lathe("shell_hull", [(0.008, 0.0102), (0.060, 0.0102), (0.063, 0.0085)], 0.0, hull(), sides=16))
    body[-1].rotation_euler = (math.pi / 2, 0, 0)
    body[-1].location = (0.0355, y, 0.020)
    body.append(kit.lathe("shell_brass", [(-0.002, 0.0112), (0.0, 0.0112), (0.0, 0.0104), (0.009, 0.0104)], 0.0, brass(), sides=16))
    body[-1].rotation_euler = (math.pi / 2, 0, 0)
    body[-1].location = (0.0355, y, 0.020)
    body.append(kit.box("shell_clip", (0.016, 0.004, 0.012), (0.031, y + 0.0115, 0.044), dark(), bevel=0.001))
body.append(kit.box("shell_clip", (0.016, 0.004, 0.012), (0.031, -0.1155, 0.044), dark(), bevel=0.001))

# Round counter: a small lit window behind the saddle.
body.append(kit.box("counter_bezel", (0.003, 0.040, 0.014), (0.0205, 0.050, 0.060), dark(), bevel=0.001))
for i in range(6):
    body.append(kit.box("counter_pip", (0.0034, 0.004, 0.008), (0.0205, 0.036 + i * 0.0056, 0.060), glow()))

shotgun = kit.join("Shotgun", body)

# The fore-end and its action bars are their own mesh so a clip can rack them.
forend = kit.loft("forend", [
    (-0.452, 0.034, 0.038, 0.042, 0.014, 0.018),
    (-0.440, 0.031, 0.048, 0.054, 0.014, 0.024),
    (-0.215, 0.031, 0.048, 0.054, 0.014, 0.024),
    (-0.203, 0.034, 0.038, 0.042, 0.014, 0.018),
], dark())
for i in range(9):
    for side in (-1, 1):
        kit.cut(forend, kit.box("forend_groove", (0.005, 0.006, 0.060), (side * 0.0245, -0.425 + i * 0.024, 0.028), rot=(0.35, 0, 0)))
pump = kit.join("Pump", [forend] + [
    kit.box("action_bar", (0.003, 0.085, 0.007), (side * 0.0165, -0.165, TUBE + 0.002), bare()) for side in (-1, 1)
])
pump.parent = shotgun

kit.marker("Muzzle", (0, -0.604, BORE), shotgun)
kit.marker("SightTip", (0, -0.584, BORE + 0.051), shotgun)

kit.report()
kit.bake("shotgun", [shotgun, pump])
kit.export("shotgun")
kit.render("shotgun")
