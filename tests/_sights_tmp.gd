extends SceneTree
func _initialize() -> void:
	var s: Node3D = load("res://assets/models/quaternius_pistol/pistol.glb").instantiate()
	root.add_child(s)
	await process_frame
	await process_frame
	var rootnode: Node3D = s.get_node("RootNode")
	var mi: MeshInstance3D = s.find_child("Muzzle", true, false)
	var baked: ArrayMesh = mi.bake_mesh_from_current_skeleton_pose()
	var to_root: Transform3D = rootnode.global_transform.affine_inverse() * mi.global_transform
	var verts: Array[Vector3] = []
	for i in baked.get_surface_count():
		for v in baked.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
			verts.append(to_root * v)
	var lo := Vector3.INF; var hi := -Vector3.INF
	for v in verts: lo = lo.min(v); hi = hi.max(v)
	print("baked bounds in RootNode frame lo ", lo, " hi ", hi, " size ", hi - lo)
	var slices := {}
	for v in verts:
		var k := int(floor(v.x * 4.0))
		if not slices.has(k) or v.y > slices[k].y: slices[k] = v
	var keys := slices.keys(); keys.sort()
	for k in keys: print("x>=%.2f top %s" % [k / 4.0, slices[k]])
	quit()
