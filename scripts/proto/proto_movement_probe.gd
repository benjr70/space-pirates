extends SceneTree
## Throwaway: stand the pirate in front of each course block and print the probe.
func _init() -> void:
	var scene: Node = load("res://scenes/proto_movement_walk.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var p: CharacterBody3D = scene.player
	var course: Rect2i = scene.COURSE_ROOM
	var row_z: int = course.position.y + 3
	for i in 10:
		var tile := Vector2i(course.position.x + 1 + i, row_z + 2)
		p.global_position = ShipBuilder3D.tile_to_world(tile)
		p.rotation.y = 0.0  # face -Z (north), toward the block
		await physics_frame
		var ledge: Dictionary = p._find_ledge()
		print("block %d: %s -> %s" % [i, p.last_probe, "clamber" if not ledge.is_empty() else "no"])
	# crouch gap
	var gap := Vector2i(course.position.x + 2, course.end.y - 3)
	p.global_position = ShipBuilder3D.tile_to_world(gap) + Vector3(0.5, 0, 1.5)
	await physics_frame
	print("under slab standing ok? ", p._can_stand())
	p.global_position = ShipBuilder3D.tile_to_world(gap) + Vector3(0.5, 0, 0)
	await physics_frame
	print("in slab, can stand? ", p._can_stand(), " (expect false)")
	quit()
