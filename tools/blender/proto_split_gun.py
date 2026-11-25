"""PROTOTYPE, throwaway: build one of the four guns from its own script, but
leave the parts an Attachment can replace as separate meshes and add a mount
point for each Slot (.scratch/weapon-attachments/issues/09-attachment-look.md).

    flatpak run org.blender.Blender -b --python $PWD/tools/blender/proto_split_gun.py -- <gun> [draft]

<gun> is pistol, assault_rifle, shotgun or marksman_rifle. The gun's script
runs untouched; this file stands in for a few `kit` calls while it does:

- `kit.join` of the body pulls the named pieces out into their own meshes.
- `kit.rig` keeps every mesh its own object on the one skeleton, where the
  real one joins them all. A bone's mesh is named `<Bone>Mesh`, because
  Godot renames a bone that shares its name with a mesh.
- `kit.export` adds the mount points and writes `proto_<gun>.glb`.
"""
import os, re, runpy, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import bpy
import kit

GUNS = {
    "pistol": {
        "body": "Pistol", "parts": {},
        "mounts": {"MountSight": (0, 0.030, 0.0285), "MountMuzzle": (0, -0.131, 0.018), "MountUnder": (0, -0.088, -0.0165)},
    },
    "assault_rifle": {
        "body": "AssaultRifle",
        "parts": {
            "Barrel": {"barrel", "emitter"},
            "Sights": {"sight_base", "front_ear", "front_post", "front_dot", "rear_stem", "aperture"},
            "Stock": {"stock", "butt_pad", "stock_latch", "sling_swivel"},
        },
        "mounts": {"MountSight": (0, 0.060, 0.088), "MountMuzzle": (0, -0.522, 0.053), "MountUnder": (0, -0.250, 0.028)},
    },
    "shotgun": {
        "body": "Shotgun",
        "parts": {
            "Barrel": {"barrel", "mag_tube", "clamp", "clamp_bolt", "sling_stud", "shield", "shield_strap"},
            "FrontSight": {"front_wing", "front_base", "front_post", "front_dot"},
            "Sights": {"rear_base", "ghost_ring", "rear_wing"},
            "Stock": {"stock", "butt_plate", "butt_pad"},
        },
        "mounts": {"MountSight": (0, -0.030, 0.093), "MountUnder": (0, -0.330, 0.004)},
    },
    "marksman_rifle": {
        "body": "MarksmanRifle",
        "parts": {
            "Barrel": {"barrel", "barrel_ring", "muzzle_flute", "emitter"},
            "Sights": {"front_ear", "front_base", "front_post", "front_dot", "rear_base", "rear_stem", "aperture"},
            "Stock": {"butt_pad", "cheek_riser", "cheek_rest", "cheek_screw"},
        },
        "mounts": {"MountSight": (0, 0.095, 0.095), "MountMuzzle": (0, -0.656, 0.056), "MountUnder": (0, -0.215, 0.023)},
    },
}
gun = next(a for a in sys.argv if a in GUNS)
cfg = GUNS[gun]
extra = {}
real_join, real_bake, real_export, real_render = kit.join, kit.bake, kit.export, kit.render


def join(name, objs):
    if name != cfg["body"]:
        return real_join(name, objs)
    keep, groups = [], {}
    for o in objs:
        base = re.sub(r"\.\d+$", "", o.name)
        part = next((p for p, names in cfg["parts"].items() if base in names), None)
        (groups.setdefault(part, []) if part else keep).append(o)
    for part, members in groups.items():
        extra[part] = real_join(part, members)
    return real_join(name, keep)


def bake(name, objs, size=2048):
    return real_bake("proto_" + name, list(objs) + list(extra.values()), size)


def rig(name, body, parts):
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
    skinned = [(body, "Body")] + [(m, "Body") for m in extra.values()] + [(m, b) for b, m in parts.items()]
    for mesh, bone_name in skinned:
        world = mesh.matrix_world.copy()
        mesh.parent = None
        mesh.matrix_world = world
        if bone_name != "Body":
            mesh.name = bone_name + "Mesh"
            mesh.data.name = bone_name + "Mesh"
        mesh.vertex_groups.new(name=bone_name).add(range(len(mesh.data.vertices)), 1.0, "REPLACE")
        mesh.modifiers.new("Armature", "ARMATURE").object = holder
        mesh.parent = holder
    bpy.context.scene.render.fps = 30
    return holder


def export(name):
    for mount, at in cfg["mounts"].items():
        kit.marker(mount, at)
    return real_export("proto_" + name)


kit.join, kit.bake, kit.rig, kit.export = join, bake, rig, export
kit.render = lambda name, *a, **k: real_render("proto_" + name, *a, **k)
runpy.run_path(os.path.join(HERE, gun + ".py"), run_name="__main__")
print("SPLIT", gun, sorted(extra))
