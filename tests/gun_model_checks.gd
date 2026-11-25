class_name GunModelChecks
extends RefCounted
## The four guns' imported models: each replaceable part (barrel, sights,
## stock, magazine) is its own mesh on the gun's one skeleton, each bone's
## mesh is named `<Bone>Mesh` so the importer leaves the bone's name alone,
## the mount points an Attachment goes on are named markers, and splitting
## the parts out moved nothing: the Muzzle and sights are where they were and
## the clips drive the same bones.
## Run from the pirate suite: `GunModelChecks.run(_expect)`.

## Within 1 mm of the recorded place.
const TOLERANCE := 0.001

## Per gun: its meshes by name, its bones, the bones each clip moves, and
## where each marker sits in the model's own space (Godot's axes: +Y up, +Z
## toward the muzzle). Muzzle, SightTip and SightRear, and the bones each clip
## moves, are what the models had before the parts were split out; the mounts
## are the prototype's (`tools/blender/proto_split_gun.py` on
## `prototype/attachment-look`).
const GUNS := {
	"pistol": {
		"meshes": ["Pistol", "SlideMesh", "TriggerMesh", "MagazineMesh"],
		"bones": ["Body", "Magazine", "Slide", "Trigger"],
		"clips": {"fire": ["Slide", "Trigger"], "reload": ["Magazine"], "rack": ["Slide"]},
		"markers": {
			"Muzzle": Vector3(0, 0.018, 0.131),
			"SightTip": Vector3(0, 0.033, 0.1125),
			"MountSight": Vector3(0, 0.0285, -0.030),
			"MountMuzzle": Vector3(0, 0.018, 0.131),
			"MountUnder": Vector3(0, -0.0165, 0.088),
		},
	},
	"assault_rifle": {
		"meshes": ["AssaultRifle", "Barrel", "Sights", "Stock", "CellMesh", "BoltMesh"],
		"bones": ["Body", "Bolt", "Cell"],
		"clips": {"fire": ["Bolt"], "reload": ["Cell"], "rack": ["Bolt"]},
		"markers": {
			"Muzzle": Vector3(0, 0.053, 0.522),
			"SightTip": Vector3(0, 0.116, 0.345),
			"SightRear": Vector3(0, 0.116, -0.145),
			"MountSight": Vector3(0, 0.088, -0.060),
			"MountMuzzle": Vector3(0, 0.053, 0.522),
			"MountUnder": Vector3(0, 0.028, 0.250),
		},
	},
	"shotgun": {
		"meshes": ["Shotgun", "Barrel", "FrontSight", "Sights", "Stock", "PumpMesh", "ShellMesh"],
		"bones": ["Body", "Pump", "Shell"],
		"clips": {"fire": ["Pump"], "shell": ["Shell"], "pump": ["Pump"]},
		"markers": {
			"Muzzle": Vector3(0, 0.060, 0.604),
			"SightTip": Vector3(0, 0.111, 0.584),
			"MountSight": Vector3(0, 0.093, 0.030),
			"MountUnder": Vector3(0, 0.004, 0.330),
		},
	},
	"marksman_rifle": {
		"meshes": ["MarksmanRifle", "Barrel", "Sights", "Stock", "MagazineMesh", "BoltMesh"],
		"bones": ["Body", "Bolt", "Magazine"],
		"clips": {"fire": ["Bolt"], "reload": ["Magazine"], "rack": ["Bolt"]},
		"markers": {
			"Muzzle": Vector3(0, 0.056, 0.656),
			"SightTip": Vector3(0, 0.126, 0.270),
			"SightRear": Vector3(0, 0.126, -0.150),
			"MountSight": Vector3(0, 0.095, -0.095),
			"MountMuzzle": Vector3(0, 0.056, 0.656),
			"MountUnder": Vector3(0, 0.023, 0.215),
		},
	},
}

## Every mount point a gun may give.
const MOUNTS := ["MountSight", "MountMuzzle", "MountUnder"]


static func run(expect: Callable) -> void:
	for gun in GUNS:
		var model: Node3D = load("res://assets/models/%s/%s.glb" % [gun, gun]).instantiate()
		_check_meshes(expect, gun, model)
		_check_rig(expect, gun, model)
		_check_markers(expect, gun, model)
		model.free()


## Each listed mesh, and no other, skinned to the gun's one skeleton.
static func _check_meshes(expect: Callable, gun: String, model: Node3D) -> void:
	var want: Array = GUNS[gun]["meshes"]
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	expect.call(skeletons.size() == 1, "gun models: %s has %d skeletons, not one" % [gun, skeletons.size()])
	var names: Array = []
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		names.append(String(mesh.name))
		expect.call(mesh.get_parent() is Skeleton3D and mesh.skin != null,
				"gun models: %s's %s is not skinned to the skeleton" % [gun, mesh.name])
	names.sort()
	var sorted := want.duplicate()
	sorted.sort()
	expect.call(names == sorted, "gun models: %s's meshes are %s, want %s" % [gun, names, sorted])


## The same bones by the same names, each clip moves the same bones on the
## skeleton, and each mesh rides its own bone: `<Bone>Mesh` on that bone,
## every other mesh on Body.
static func _check_rig(expect: Callable, gun: String, model: Node3D) -> void:
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var bones: Array = []
	if skeleton != null:
		for i in skeleton.get_bone_count():
			bones.append(skeleton.get_bone_name(i))
	expect.call(bones == GUNS[gun]["bones"], "gun models: %s's bones are %s, want %s" % [gun, bones, GUNS[gun]["bones"]])
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var clips: Dictionary = GUNS[gun]["clips"]
	for clip in clips:
		if player == null or not player.has_animation(clip):
			expect.call(false, "gun models: %s has no '%s' clip" % [gun, clip])
			continue
		var animation := player.get_animation(clip)
		var moved: Array = []
		for t in animation.get_track_count():
			var path := animation.track_get_path(t)
			expect.call(model.get_node_or_null(NodePath(path.get_concatenated_names())) == skeleton,
					"gun models: %s's '%s' clip drives %s, not the skeleton" % [gun, clip, path])
			var first: Variant = animation.track_get_key_value(t, 0)
			for k in animation.track_get_key_count(t):
				var value: Variant = animation.track_get_key_value(t, k)
				if value is Vector3 and (value - first).length() > 0.0001:
					moved.append(String(path.get_concatenated_subnames()))
					break
		moved.sort()
		expect.call(moved == clips[clip], "gun models: %s's '%s' clip moves %s, want %s" % [gun, clip, moved, clips[clip]])
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		var want := "Body"
		if String(mesh.name).ends_with("Mesh"):
			want = String(mesh.name).trim_suffix("Mesh")
		var riding := _bones_of(mesh)
		expect.call(riding == [want], "gun models: %s's %s rides %s, want [%s]" % [gun, mesh.name, riding, want])


## The bones [param mesh]'s vertices are weighted to, by name.
static func _bones_of(mesh: MeshInstance3D) -> Array:
	var names: Array = []
	if mesh.mesh == null or mesh.skin == null:
		return names
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		for i in joints.size():
			if weights[i] <= 0.0:
				continue
			var bind := mesh.skin.get_bind_name(joints[i])
			if not names.has(String(bind)):
				names.append(String(bind))
	names.sort()
	return names


## Each marker within 1 mm of its place, and no mount the gun does not give.
static func _check_markers(expect: Callable, gun: String, model: Node3D) -> void:
	var markers: Dictionary = GUNS[gun]["markers"]
	for marker in markers:
		var node := model.find_child(marker, true, false) as Node3D
		if node == null:
			expect.call(false, "gun models: %s has no %s marker" % [gun, marker])
			continue
		var at := _in_model(model, node)
		expect.call(at.distance_to(markers[marker]) <= TOLERANCE,
				"gun models: %s's %s is at %s, want %s within 1 mm" % [gun, marker, at, markers[marker]])
	for mount in MOUNTS:
		if not markers.has(mount):
			expect.call(model.find_child(mount, true, false) == null, "gun models: %s gives a %s it should not" % [gun, mount])


## [param node]'s place in [param model]'s own space, outside the tree.
static func _in_model(model: Node3D, node: Node3D) -> Vector3:
	var transform := Transform3D.IDENTITY
	var at: Node = node
	while at != model:
		transform = (at as Node3D).transform * transform
		at = at.get_parent()
	return transform.origin
