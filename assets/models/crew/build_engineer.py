# Builds the Worker crew rig, "engineer.glb": the Quaternius Soldier's body and
# skeleton (so every crew clip plays), re-dressed as a ship engineer: orange
# coveralls with reflective bands, the Gunner's open space-helmet head, a tool
# belt with pouches and a wrench, and twin air tanks on the back.
#
# Reads soldier.glb and gunner.glb beside it and writes engineer.glb there.
# Run from the repo root, then reimport in Godot:
#   flatpak run --filesystem=$PWD org.blender.Blender -b \
#     --python "$PWD/assets/models/crew/build_engineer.py"
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

CREW = os.path.dirname(os.path.abspath(__file__)) + "/"
OUT = CREW + "engineer.glb"

for o in list(bpy.data.objects): bpy.data.objects.remove(o)
bpy.ops.import_scene.gltf(filepath=CREW + "soldier.glb")
arm = bpy.data.objects['CharacterArmature']
keep_actions = set(a.name for a in bpy.data.actions)
soldier_objs = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=CREW + "gunner.glb")
gunner_objs = set(bpy.data.objects) - soldier_objs
garm = [o for o in gunner_objs if o.type == 'ARMATURE'][0]

def bone_pos(a, name):
    return a.matrix_world @ a.data.bones[name].head_local

# The Gunner's head, moved onto the Soldier's skeleton.
head = [o for o in gunner_objs if o.name.startswith('SpaceSuit_Head')][0]
offset = bone_pos(arm, 'Head') - bone_pos(garm, 'Head')
print('head offset', offset)
mw = head.matrix_world.copy()
head.parent = arm
head.matrix_world = Matrix.Translation(offset) @ mw
for m in head.modifiers:
    if m.type == 'ARMATURE': m.object = arm
for o in gunner_objs:
    if o != head: bpy.data.objects.remove(o)
for a in list(bpy.data.actions):
    if a.name not in keep_actions: bpy.data.actions.remove(a)
for name in ['Swat_Head', 'Icosphere']:
    if name in bpy.data.objects: bpy.data.objects.remove(bpy.data.objects[name])

def mat(name, rgb, rough=0.6, metal=0.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*rgb, 1)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1)
        b.inputs['Emission Strength'].default_value = 1.0
    return m

def recolour(name, rgb, rough=None):
    m = bpy.data.materials.get(name)
    if m is None: return
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*rgb, 1)
    if rough is not None: b.inputs['Roughness'].default_value = rough

ORANGE = (0.62, 0.20, 0.035)
recolour('Swat', ORANGE, 0.75)                 # coveralls
recolour('Swat_Black', (0.035, 0.035, 0.04))   # gloves, boots, straps
recolour('SciFi_Light_Accent', ORANGE)         # helmet trim to match
recolour('SciFi_Light', (0.55, 0.55, 0.52))    # helmet shell, off-white

REFLECT = mat('Reflective', (0.75, 0.75, 0.62), 0.3, 0.2, emit=(0.06, 0.06, 0.05))
BELT = mat('Belt', (0.05, 0.035, 0.025), 0.8)
POUCH = mat('Pouch', (0.10, 0.10, 0.09), 0.85)
STEEL = mat('Steel', (0.45, 0.46, 0.48), 0.35, 1.0)
TANK = mat('Tank', (0.50, 0.50, 0.48), 0.4, 0.3)
CAP = mat('TankCap', ORANGE, 0.5)

parts = []

def skin(obj, bone, material):
    obj.data.materials.append(material)
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    parts.append(obj)

def band(name, centre, rx, ry, height, thick, bone, material, segs=24):
    # An elliptical ring around the vertical axis.
    bm = bmesh.new()
    rings = []
    for (r_add, z) in [(thick, -height/2), (thick, height/2), (0, height/2), (0, -height/2)]:
        ring = []
        for i in range(segs):
            a = 2*math.pi*i/segs
            ring.append(bm.verts.new((centre[0] + (rx + r_add)*math.cos(a), centre[1] + (ry + r_add)*math.sin(a), centre[2] + z)))
        rings.append(ring)
    for k in range(4):
        r0, r1 = rings[k], rings[(k+1) % 4]
        for i in range(segs):
            j = (i+1) % segs
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    skin(o, bone, material)
    return o

def box(name, centre, size, bone, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre, rotation=rot)
    o = bpy.context.active_object; o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    skin(o, bone, material)
    return o

def cyl(name, centre, radius, depth, bone, material, rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=centre, rotation=rot)
    o = bpy.context.active_object; o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    skin(o, bone, material)
    return o

# Reflective bands: chest and both shins.
band('BandChest', (0, -0.068, 1.22), 0.142, 0.118, 0.04, 0.012, 'Torso', REFLECT)
band('BandWaist', (0, -0.068, 1.10), 0.143, 0.098, 0.03, 0.012, 'Abdomen', REFLECT)
for side, x in (('L', 0.1), ('R', -0.1)):
    band('BandShin' + side, (x, -0.075, 0.38), 0.068, 0.068, 0.035, 0.012, 'LowerLeg.' + side, REFLECT)
    band('BandThigh' + side, (x, -0.065, 0.72), 0.088, 0.1, 0.03, 0.012, 'UpperLeg.' + side, REFLECT)

# Tool belt with pouches and a wrench.
band('Belt', (0, -0.05, 0.95), 0.152, 0.115, 0.055, 0.018, 'Hips', BELT)
box('Buckle', (0, -0.183, 0.95), (0.06, 0.012, 0.045), 'Hips', STEEL)
box('PouchL', (0.135, -0.11, 0.92), (0.06, 0.05, 0.08), 'Hips', POUCH, rot=(0, 0, math.radians(-35)))
box('PouchR', (-0.135, -0.11, 0.92), (0.06, 0.05, 0.08), 'Hips', POUCH, rot=(0, 0, math.radians(35)))
box('PouchBack', (0.06, 0.08, 0.93), (0.08, 0.04, 0.07), 'Hips', POUCH)
cyl('WrenchShaft', (-0.175, -0.035, 0.85), 0.011, 0.2, 'Hips', STEEL)
box('WrenchJaw', (-0.175, -0.035, 0.955), (0.045, 0.018, 0.03), 'Hips', STEEL)

# Twin air tanks on a back plate.
box('TankPlate', (0, 0.07, 1.27), (0.19, 0.02, 0.26), 'Chest', POUCH)
for side, x in (('L', 0.055), ('R', -0.055)):
    cyl('Tank' + side, (x, 0.125, 1.27), 0.05, 0.26, 'Chest', TANK)
    cyl('TankCap' + side, (x, 0.125, 1.415), 0.032, 0.04, 'Chest', CAP)
cyl('TankHose', (0.0, 0.09, 1.46), 0.012, 0.13, 'Chest', BELT, rot=(0, math.radians(90), 0))

# One skinned gear mesh on the Soldier's skeleton.
bpy.ops.object.select_all(action='DESELECT')
for p in parts: p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
gear = bpy.context.active_object
gear.name = 'Engineer_Gear'
# Into the armature's own space, like the Quaternius meshes: identity local
# transform under the armature, vertices in its (1/100 scale) units.
gear.data.transform(arm.matrix_world.inverted() @ gear.matrix_world)
gear.parent = arm
gear.matrix_parent_inverse = Matrix.Identity(4)
gear.matrix_basis = Matrix.Identity(4)
mod = gear.modifiers.new('Armature', 'ARMATURE'); mod.object = arm

# Rename the Soldier's parts so the file reads as its own character.
for o in bpy.data.objects:
    if o.name.startswith('Swat_'): o.name = o.name.replace('Swat_', 'Engineer_')
head.name = 'Engineer_Head'

# Bake the armature's x100 scale and rotation into the rig so it exports as
# an identity node with everything in metres; Godot nests skinned meshes
# under a transformed armature node in the wrong space. Bone location keys
# are in armature units, so they scale with it.
SCALE = arm.scale.x
bpy.ops.object.select_all(action='DESELECT')
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for o in arm.children:
    if o.type == 'MESH':
        bpy.ops.object.select_all(action='DESELECT')
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
def fcurves(action):
    if hasattr(action, 'fcurves') and len(action.fcurves):
        return list(action.fcurves)
    out = []
    for layer in getattr(action, 'layers', []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out += list(bag.fcurves)
    return out
for a in bpy.data.actions:
    for fc in fcurves(a):
        if fc.data_path.endswith('.location'):
            for k in fc.keyframe_points:
                k.co.y *= SCALE; k.handle_left.y *= SCALE; k.handle_right.y *= SCALE
bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', export_animations=True, export_skins=True, export_yup=True)
print('WROTE', OUT, sorted(a.name for a in bpy.data.actions)[:3], len(bpy.data.actions))
