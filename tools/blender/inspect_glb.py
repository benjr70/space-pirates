"""Render and measure an existing glb:  blender -b --python inspect_glb.py -- <path.glb> <name>"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy
import kit

path, name = sys.argv[sys.argv.index("--") + 1:][:2]
kit.reset()
bpy.ops.import_scene.gltf(filepath=path)
for o in bpy.context.scene.objects:
    print("OBJ", o.type, o.name, "parent=", o.parent.name if o.parent else None,
          "loc=", tuple(round(v, 3) for v in o.matrix_world.translation),
          "mats=", [m.name for m in o.data.materials] if o.type == "MESH" else "")
    if o.type == "ARMATURE":
        print("  BONES", [b.name for b in o.data.bones])
print("ACTIONS", [a.name for a in bpy.data.actions])
for m in bpy.data.materials:
    b = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
    if b:
        print("MAT", m.name, [round(v, 3) for v in b.inputs["Base Color"].default_value[:3]],
              "metal", round(b.inputs["Metallic"].default_value, 2), "rough", round(b.inputs["Roughness"].default_value, 2))
kit.report()
kit.render(name)
