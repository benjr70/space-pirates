"""Shared helpers for building low-poly models from Blender Python scripts.

Run a model script headless:
    flatpak run org.blender.Blender -b --python tools/blender/<model>.py

Convention: build the weapon with its barrel along Blender -Y and up along +Z,
in metres at life size. The glTF exporter turns that into Godot's +Z forward,
+Y up, which is how the Viewmodel expects a weapon mesh to face.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "out")
# `-- draft` on the command line skips the bake and export: two quick renders
# of the shape, in seconds, for working on the modelling.
DRAFT = "draft" in sys.argv


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


_materials = {}
_bake = {}


def surface(name, base, rough, metallic=0.0, wear=(0.5, 0.5, 0.52), wear_rough=0.3, wear_amount=1.0,
            grain=0.3, grain_scale=600.0, streak=0.0, emission=0.0):
    """A procedural PBR material: mottled, worn bright on its edges, grimy in
    its creases. It only renders in Cycles; `bake` turns it into textures.

    `wear` is the colour that shows where the finish has rubbed through,
    `grain` the depth of the fine surface texture, `streak` how strongly a
    grain runs along the barrel (wood).
    """
    if name in _materials:
        return _materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    N, L = m.node_tree.nodes, m.node_tree.links
    bsdf = N["Principled BSDF"]
    coords = N.new("ShaderNodeTexCoord").outputs["Object"]

    def noise(scale, detail=4.0, stretch=None):
        n = N.new("ShaderNodeTexNoise")
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        src = coords
        if stretch:
            mapping = N.new("ShaderNodeMapping")
            mapping.inputs["Scale"].default_value = stretch
            L.new(coords, mapping.inputs["Vector"])
            src = mapping.outputs["Vector"]
        L.new(src, n.inputs["Vector"])
        return n.outputs[0]

    def calc(op, a, b=None, clamp=False):
        n = N.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                n.inputs[i].default_value = v
            else:
                L.new(v, n.inputs[i])
        return n.outputs[0]

    def mix(fac, a, b, colour=True):
        n = N.new("ShaderNodeMix")
        n.data_type = "RGBA" if colour else "FLOAT"
        ia, ib, out = (6, 7, 2) if colour else (2, 3, 0)
        for socket, v in ((n.inputs[0], fac), (n.inputs[ia], a), (n.inputs[ib], b)):
            if isinstance(v, tuple):
                socket.default_value = (*v, 1.0)
            elif isinstance(v, (int, float)):
                socket.default_value = v
            else:
                L.new(v, socket)
        return n.outputs[out]

    # Where the surface turns a corner: the bevel node's rounded normal
    # leaves the true one only near an edge.
    bevel = N.new("ShaderNodeBevel")
    bevel.samples = 8
    bevel.inputs["Radius"].default_value = 0.0025
    geometry = N.new("ShaderNodeNewGeometry")
    dot = N.new("ShaderNodeVectorMath")
    dot.operation = "DOT_PRODUCT"
    L.new(bevel.outputs["Normal"], dot.inputs[0])
    L.new(geometry.outputs["True Normal"], dot.inputs[1])
    edge = calc("MULTIPLY", calc("SUBTRACT", 1.0, dot.outputs["Value"]), 14.0, clamp=True)
    # Only convex edges wear; creases collect dirt instead.
    convex = calc("MULTIPLY", calc("SUBTRACT", geometry.outputs["Pointiness"], 0.5), 60.0, clamp=True)
    edge = calc("MULTIPLY", edge, convex)

    occlusion = N.new("ShaderNodeAmbientOcclusion")
    occlusion.samples = 8
    occlusion.inputs["Distance"].default_value = 0.02
    dirt = calc("MULTIPLY", calc("SUBTRACT", 1.0, occlusion.outputs["AO"]), 1.3, clamp=True)

    mottle = noise(22.0, 6.0)
    chips = calc("SUBTRACT", calc("MULTIPLY", noise(90.0, 6.0), 2.4), 0.6, clamp=True)
    scuffs = calc("MULTIPLY", calc("SUBTRACT", noise(140.0, 3.0, stretch=(1.0, 0.03, 1.0)), 0.74, clamp=True), 1.5, clamp=True)
    worn = calc("MULTIPLY", calc("MAXIMUM", calc("MULTIPLY", edge, chips), scuffs), wear_amount, clamp=True)
    fine = noise(grain_scale, 2.0)

    lo = tuple(c * 0.88 for c in base)
    hi = tuple(min(1.0, c * 1.1) for c in base)
    colour = mix(mottle, lo, hi)
    if streak:
        bands = noise(70.0, 6.0, stretch=(1.0, 0.04, 1.0))
        colour = mix(calc("MULTIPLY", bands, streak), colour, tuple(c * 0.35 for c in base))
    colour = mix(worn, colour, wear)
    colour = mix(calc("MULTIPLY", dirt, 0.7), colour, (0.012, 0.011, 0.010))

    roughness = calc("ADD", rough, calc("MULTIPLY", calc("SUBTRACT", mottle, 0.5), 0.14))
    roughness = mix(worn, roughness, wear_rough, colour=False)
    roughness = calc("ADD", roughness, calc("MULTIPLY", dirt, 0.3), clamp=True)

    height = calc("SUBTRACT", calc("MULTIPLY", fine, grain), calc("MULTIPLY", worn, 0.5))
    bump = N.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 1.0
    bump.inputs["Distance"].default_value = 0.0004
    L.new(height, bump.inputs["Height"])
    L.new(bevel.outputs["Normal"], bump.inputs["Normal"])

    L.new(colour, bsdf.inputs["Base Color"])
    L.new(roughness, bsdf.inputs["Roughness"])
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*base, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission

    _materials[name] = m
    _bake[name] = {"color": colour, "rough": roughness, "metal": metallic,
                   "emission": tuple(base) if emission else (0.0, 0.0, 0.0), "strength": emission}
    return m


def _finish(obj, material, bevel, segments=2):
    if material:
        obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segments
        mod.limit_method = "ANGLE"
    return obj


def box(name, size, at, material=None, bevel=0.0, rot=(0, 0, 0), segments=2):
    """A box `size` (x, y, z) metres centred on `at`."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=at, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return _finish(obj, material, bevel, segments)


def cyl(name, radius, length, at, axis="Y", material=None, sides=24, bevel=0.0, radius2=None):
    """A cylinder (or cone frustum with `radius2`) centred on `at`, along `axis`."""
    rot = {"X": (0, math.pi / 2, 0), "Y": (math.pi / 2, 0, 0), "Z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cone_add(
        vertices=sides, radius1=radius, radius2=radius if radius2 is None else radius2,
        depth=length, location=at, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return _finish(obj, material, bevel)


def prism(name, profile, width, material=None, bevel=0.0, x=0.0, segments=2):
    """Extrude a side-view outline, a list of (y, z) points, `width` wide on X.

    This is the workhorse for gun shapes: draw the silhouette, give it a
    thickness.
    """
    bm = bmesh.new()
    near = [bm.verts.new((x - width / 2, y, z)) for y, z in profile]
    far = [bm.verts.new((x + width / 2, y, z)) for y, z in profile]
    bm.faces.new(near)
    bm.faces.new(reversed(far))
    n = len(profile)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((near[j], near[i], far[i], far[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return _finish(obj, material, bevel, segments)


def _skin(name, rings, material):
    """Join a row of equal-sized vertex rings into a capped tube."""
    bm = bmesh.new()
    loops = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(loops[0])
    for a, b in zip(loops, loops[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(loops[0])
    bm.faces.new(reversed(loops[-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return _finish(obj, material, 0.0)


def loft(name, sections, material=None, arc=4, rot=(0, 0, 0), at=(0, 0, 0)):
    """A body whose cross-section changes along its length: receivers,
    stocks, grips, fore-ends. Nothing a real gun is made of is a box.

    Each section is (y, z_centre, width, height, top_radius, bottom_radius):
    a rounded rectangle standing across the barrel at `y`. `rot` and `at`
    then place the whole body, for parts that do not run along the barrel
    (a grip is a loft stood on end).
    """
    rings = []
    for y, zc, w, h, rt, rb in sections:
        hw, hh = w / 2, h / 2
        rt = max(0.0004, min(rt, hw, hh))
        rb = max(0.0004, min(rb, hw, hh))
        ring = []
        for cx, cz, r, start in ((hw - rt, hh - rt, rt, 0), (rt - hw, hh - rt, rt, 90),
                                 (rb - hw, rb - hh, rb, 180), (hw - rb, rb - hh, rb, 270)):
            for i in range(arc + 1):
                a = math.radians(start + 90.0 * i / arc)
                ring.append((cx + r * math.cos(a), y, zc + cz + r * math.sin(a)))
        rings.append(ring)
    obj = _skin(name, rings, material)
    obj.rotation_euler = rot
    obj.location = at
    return obj


def lathe(name, profile, z, material=None, sides=32, x=0.0):
    """Turned parts on the bore axis: barrels, tubes, muzzle devices.

    `profile` is (y, radius) points; two points at one `y` make a step, and
    a profile that doubles back inside itself bores a hole.
    """
    rings = []
    for y, r in profile:
        r = max(r, 0.0002)
        rings.append([(x + r * math.cos(2 * math.pi * i / sides), y, z + r * math.sin(2 * math.pi * i / sides))
                      for i in range(sides)])
    return _skin(name, rings, material)


def rail(name, y0, y1, z, material=None):
    """An accessory rail from `y0` to `y1`, sitting on `z`: the slotted
    strip on top of every modern gun."""
    length = y1 - y0
    parts = [box(name, (0.015, length, 0.005), (0, (y0 + y1) / 2, z + 0.0025), material)]
    count = int(length / 0.010)
    for i in range(count):
        y = y0 + 0.005 + i * 0.010
        parts.append(box(name + "_lug", (0.021, 0.0052, 0.0045), (0, y, z + 0.0068), material, bevel=0.0012, segments=1))
    return parts


def cut(target, cutter):
    """Boolean-subtract `cutter` from `target` and remove the cutter."""
    # The walls of the cut take the target's finish.
    if not cutter.data.materials and target.data.materials:
        cutter.data.materials.append(target.data.materials[0])
    mod = target.modifiers.new("cut", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    bpy.context.view_layer.objects.active = target
    # Booleans must sit before the bevel so the cut edges get bevelled too.
    while target.modifiers[0] != mod:
        bpy.ops.object.modifier_move_up(modifier=mod.name)
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter)
    return target


def marker(name, at, parent=None):
    """An empty, exported as a named Node3D (muzzle, sight tip, grip)."""
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.01
    e.location = at
    bpy.context.collection.objects.link(e)
    if parent:
        e.parent = parent
    return e


def join(name, objs):
    """Apply modifiers and join `objs` into one flat-shaded mesh named `name`."""
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    # Triangulate now so the baked normal map and the exported mesh agree.
    tri = obj.modifiers.new("tri", "TRIANGULATE")
    bpy.ops.object.modifier_apply(modifier=tri.name)
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    return obj


def tube(name, radius, bore, length, at, axis="Y", material=None, sides=24, bevel=0.0):
    """A cylinder with a real hole down it."""
    obj = cyl(name, radius, length, at, axis, material, sides, bevel)
    return cut(obj, cyl("bore", bore, length * 1.2, at, axis, sides=sides))


def pin(name, at, radius=0.004, proud=0.0015, material=None):
    """A pin or screw head through the gun on X, showing on both sides.

    `at` is (half_width, y, z): the head stands `proud` of each side.
    """
    half, y, z = at
    return cyl(name, radius, (half + proud) * 2, (0, y, z), axis="X", material=material, sides=12, bevel=0.0006)


def rig(name, body, parts):
    """Skin the model to a skeleton so its moving parts can be animated.

    `body` is the mesh that stays put; `parts` maps a bone name to the mesh
    that bone carries. Every bone sits at the origin with Blender's axes, so
    a pose location is a plain (x, y, z) offset in metres. Everything is
    joined into `body`, which is returned with the armature as its parent.
    """
    armature = bpy.data.armatures.new(name + "Armature")
    holder = bpy.data.objects.new(name + "Armature", armature)
    bpy.context.collection.objects.link(holder)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = holder
    bpy.ops.object.mode_set(mode="EDIT")
    root = None
    for bone_name in ["Body"] + list(parts):
        bone = armature.edit_bones.new(bone_name)
        bone.head = (0, 0, 0)
        bone.tail = (0, 0.05, 0)
        bone.roll = 0
        bone.parent = root
        root = root or bone
    bpy.ops.object.mode_set(mode="OBJECT")

    for mesh, bone_name in [(body, "Body")] + [(m, n) for n, m in parts.items()]:
        world = mesh.matrix_world.copy()
        mesh.parent = None
        mesh.matrix_world = world
        mesh.vertex_groups.new(name=bone_name).add(range(len(mesh.data.vertices)), 1.0, "REPLACE")
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.modifiers.new("Armature", "ARMATURE").object = holder
    body.parent = holder
    bpy.context.scene.render.fps = 30
    return holder


def clip(holder, name, tracks):
    """An animation clip on a rigged model, exported under `name`.

    `tracks` maps a bone to its keys: (frame, (x, y, z)) at 30 frames a
    second, frame 1 being the start.
    """
    data = holder.animation_data or holder.animation_data_create()
    action = bpy.data.actions.new(name)
    data.action = action
    for bone_name, keys in tracks.items():
        bone = holder.pose.bones[bone_name]
        for frame, location in keys:
            bone.location = location
            bone.keyframe_insert("location", frame=frame)
        bone.location = (0, 0, 0)
    data.action = None
    track = data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 1, action)
    track.mute = True


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def bounds():
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in mesh_objects():
        for corner in o.bound_box:
            p = o.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
    return lo, hi


def report():
    lo, hi = bounds()
    size = hi - lo
    tris = sum(len(p.vertices) - 2 for o in mesh_objects() for p in o.data.polygons)
    print("MODEL size x=%.3f y=%.3f z=%.3f m, %d tris, %d meshes" % (*size, tris, len(mesh_objects())))


def export(name):
    if DRAFT:
        return None
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_apply=True, export_yup=True,
                              export_tangents=True, export_image_format="AUTO")
    print("EXPORTED", path)
    return path


def _cycles(samples, gpu):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = samples
    scene.cycles.device = "CPU"
    if not gpu:
        return
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        for kind in ("OPTIX", "CUDA"):
            prefs.compute_device_type = kind
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                scene.cycles.device = "GPU"
                return
    except Exception as error:  # no GPU in the sandbox: the CPU does it
        print("GPU unavailable:", error)


def bake(name, objs, size=2048):
    if DRAFT:
        return None
    """Unwrap `objs` into one atlas, bake their procedural materials to
    base colour / roughness+metallic / normal / emission PNGs, and replace
    the materials with one textured material that glTF and Godot understand.
    """
    import numpy as np

    scene = bpy.context.scene
    _cycles(24, gpu=False)
    scene.render.bake.margin = 8
    scene.render.bake.use_clear = False

    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")

    def image(kind, data, fill=(0, 0, 0, 1)):
        img = bpy.data.images.new("%s_%s" % (name, kind), size, size, alpha=False, is_data=data)
        img.generated_color = fill
        return img

    images = {"color": image("color", False), "rough": image("rough", True), "metal": image("metal", True),
              "emission": image("emission", False), "normal": image("normal", True, (0.5, 0.5, 1.0, 1.0))}

    used = {m.name: m for o in objs for m in o.data.materials if m}
    rigs = {}
    for m in used.values():
        N = m.node_tree.nodes
        target = N.new("ShaderNodeTexImage")
        N.active = target
        rigs[m.name] = (target, N.new("ShaderNodeEmission"), N["Principled BSDF"],
                        next(n for n in N if n.type == "OUTPUT_MATERIAL"))

    glows = False
    for kind in ("color", "rough", "metal", "emission", "normal"):
        for m in used.values():
            target, emit, bsdf, out = rigs[m.name]
            L = m.node_tree.links
            target.image = images[kind]
            info = _bake[m.name]
            for link in list(emit.inputs["Color"].links):
                L.remove(link)
            if kind == "normal":
                L.new(bsdf.outputs[0], out.inputs["Surface"])
                continue
            L.new(emit.outputs[0], out.inputs["Surface"])
            value = info[kind]
            if isinstance(value, (int, float)):
                emit.inputs["Color"].default_value = (value, value, value, 1.0)
            elif isinstance(value, tuple):
                emit.inputs["Color"].default_value = (*value, 1.0)
                glows = glows or (kind == "emission" and any(value))
            else:
                L.new(value, emit.inputs["Color"])
        bpy.ops.object.bake(type="NORMAL" if kind == "normal" else "EMIT")
        print("BAKED", name, kind)

    # glTF wants roughness in green and metallic in blue of one image.
    def pixels(img):
        buf = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(buf)
        return buf.reshape(-1, 4)

    orm = np.ones((size * size, 4), dtype=np.float32)
    orm[:, 1] = pixels(images["rough"])[:, 0]
    orm[:, 2] = pixels(images["metal"])[:, 0]
    images["orm"] = image("orm", True)
    images["orm"].pixels.foreach_set(orm.ravel())
    for kind in ("rough", "metal"):
        bpy.data.images.remove(images.pop(kind))
    if not glows:
        bpy.data.images.remove(images.pop("emission"))
    for kind, img in images.items():
        img.filepath_raw = os.path.join(OUT, "%s_%s.png" % (name, kind))
        img.file_format = "PNG"
        img.save()

    final = bpy.data.materials.new(name)
    final.use_nodes = True
    N, L = final.node_tree.nodes, final.node_tree.links
    bsdf = N["Principled BSDF"]

    def texture(kind):
        n = N.new("ShaderNodeTexImage")
        n.image = images[kind]
        return n

    L.new(texture("color").outputs["Color"], bsdf.inputs["Base Color"])
    split = N.new("ShaderNodeSeparateColor")
    L.new(texture("orm").outputs["Color"], split.inputs[0])
    L.new(split.outputs[1], bsdf.inputs["Roughness"])
    L.new(split.outputs[2], bsdf.inputs["Metallic"])
    normal = N.new("ShaderNodeNormalMap")
    L.new(texture("normal").outputs["Color"], normal.inputs["Color"])
    L.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    if glows:
        L.new(texture("emission").outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = max(i["strength"] for i in _bake.values())

    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(final)
        o.data.polygons.foreach_set("material_index", [0] * len(o.data.polygons))
    return final


def render(name, views=("side", "three_quarter", "front_quarter", "top"), res=(1400, 900)):
    """Render preview PNGs of everything in the scene, one per view."""
    scene = bpy.context.scene
    if DRAFT:
        views = ("side", "three_quarter", "front_quarter")
    lo, hi = bounds()
    centre = (lo + hi) / 2
    reach = (hi - lo).length

    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.07, 0.073, 0.08, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world

    # Three softboxes: metal needs something big and bright to reflect.
    for loc, watts, span in (((-1.2, -1.4, 1.8), 45.0, 1.6), ((1.6, 0.4, 0.9), 18.0, 1.2), ((0.3, 1.6, -0.4), 22.0, 1.2)):
        at = centre + Vector(loc) * reach
        light = bpy.data.objects.new("softbox", bpy.data.lights.new("softbox", "AREA"))
        light.data.energy = watts * reach * reach
        light.data.size = span * reach
        light.location = at
        light.rotation_euler = (centre - at).to_track_quat("-Z", "Y").to_euler()
        scene.collection.objects.link(light)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = reach * 1.05
    scene.collection.objects.link(cam)
    scene.camera = cam

    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    _cycles(32 if DRAFT else 96, gpu=True)
    scene.cycles.use_denoising = True

    directions = {
        "side": (1, 0, 0),             # barrel pointing left
        "three_quarter": (1, -1.1, 0.6),
        "front_quarter": (-0.8, -1.3, 0.5),
        "top": (0.001, 0, 1),
    }
    paths = []
    for view in views:
        d = Vector(directions[view]).normalized()
        cam.location = centre + d * reach * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        if view == "top":
            cam.rotation_euler = (0, 0, math.pi / 2)
        path = os.path.join(OUT, "%s_%s.png" % (name, view))
        scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    print("RENDERED", *paths)
    return paths
