class_name TwoRectRoomChecks
extends RefCounted
## A Room made of two abutting rects must build, light, reveal, track and route
## as ONE Room. Run from the headless 3D suite: `TwoRectRoomChecks.run(_expect, root)`.
##
## Fixture: an L-shaped cargo Room (a 10x10 block with a 6x4 alcove off its
## right) over a plain quarters Room, joined by one doorway.
##
##   0         10    16
##   ##########.......   y 0
##   #  block  # alc #
##   #         #######   y 4
##   #         #
##   ###+++#####         y 10   (door at (3,10) width 3)
##   # lower   #
##   H         #         y 14   (hatch at (-1,14) width 2, through the hull)
##   ###########         y 19

const BLOCK := Rect2i(0, 0, 10, 10)
const ALCOVE := Rect2i(10, 0, 6, 4)
const LOWER := Rect2i(0, 11, 10, 8)
const CREW := 6


static func run(expect: Callable, root: Node) -> void:
	var layout := make_layout()
	var ship := Node3D.new()
	ship.name = "TwoRectShip"
	root.add_child(ship)
	ShipBuilder3D.build(layout, ship)

	_check_layout_reads_union(expect, layout)
	_check_geometry(expect, layout, ship)
	_check_lights_and_reveal(expect, ship)
	_check_tracker(expect, layout, root)
	_check_crew_spawn(expect, layout, ship)
	_check_routing(expect, layout)

	root.remove_child(ship)
	ship.free()


static func make_layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.ship_name = "Two Rect"
	var upper := RoomData.new()
	upper.rects = [BLOCK, ALCOVE]
	upper.role = &"cargo"
	upper.crew_count = CREW
	var lower := RoomData.new()
	lower.rects = [LOWER]
	lower.role = &"quarters"
	layout.rooms = [upper, lower]
	var door := DoorData.new()
	door.room_a = 0
	door.room_b = 1
	door.tile = Vector2i(3, 10)
	door.horizontal = true
	door.width = 3
	layout.doors = [door]
	var hatch := HatchData.new()
	hatch.room = 1
	hatch.tile = Vector2i(-1, 14)
	hatch.horizontal = false
	hatch.width = 2
	layout.hatches = [hatch]
	return layout


static func _check_layout_reads_union(expect: Callable, layout: ShipLayout) -> void:
	var floors := layout.floor_tiles()
	expect.call(floors.size() == 100 + 24 + 80 + 3 + 2,
			"two-rect layout: %d floor tiles, expected 209" % floors.size())
	expect.call(layout.room_at(Vector2i(2, 2)) == 0, "two-rect: block tile is not in room 0")
	expect.call(layout.room_at(Vector2i(14, 2)) == 0, "two-rect: alcove tile is not in room 0")
	expect.call(layout.room_at(Vector2i(14, 5)) == -1, "two-rect: tile below the alcove counted as a room")
	expect.call(layout.room_at(Vector2i(2, 12)) == 1, "two-rect: lower tile is not in room 1")


static func _check_geometry(expect: Callable, layout: ShipLayout, ship: Node3D) -> void:
	var floor_map: GridMap = ship.get_node("Floor")
	var wall_map: GridMap = ship.get_node("Walls")
	var expected := layout.floor_tiles()
	expect.call(floor_map.get_used_cells().size() == expected.size(),
			"two-rect: placed %d floor cells, expected %d" % [floor_map.get_used_cells().size(), expected.size()])

	# The seam between block and alcove is open floor, not wall.
	var seam_walls := 0
	for y in range(ALCOVE.position.y, ALCOVE.end.y):
		for x in [BLOCK.end.x - 1, ALCOVE.position.x]:
			if wall_map.get_cell_item(Vector3i(x, 0, y)) != GridMap.INVALID_CELL_ITEM:
				seam_walls += 1
	expect.call(seam_walls == 0, "two-rect: %d wall cells sit on the seam between the rects" % seam_walls)

	# But the alcove is still walled in on its other sides.
	var missing := 0
	for x in range(ALCOVE.position.x, ALCOVE.end.x + 1):
		if wall_map.get_cell_item(Vector3i(x, 0, ALCOVE.end.y)) == GridMap.INVALID_CELL_ITEM:
			missing += 1
	for y in range(ALCOVE.position.y - 1, ALCOVE.end.y + 1):
		if wall_map.get_cell_item(Vector3i(ALCOVE.end.x, 0, y)) == GridMap.INVALID_CELL_ITEM:
			missing += 1
	expect.call(missing == 0, "two-rect: %d wall cells missing around the alcove" % missing)

	var walls := ShipBuilder3D.wall_tiles(layout, expected)
	var clashes := 0
	for tile: Vector2i in walls:
		if expected.has(tile):
			clashes += 1
	expect.call(clashes == 0, "two-rect: %d tiles are both floor and wall" % clashes)


static func _check_lights_and_reveal(expect: Callable, ship: Node3D) -> void:
	var lights: Node3D = ship.get_node("Lights")
	expect.call(lights.get_child_count() == 2,
			"two-rect: %d lights for 2 rooms" % lights.get_child_count())
	if lights.get_child_count() > 0:
		var light: OmniLight3D = lights.get_child(0)
		var tile := ShipBuilder3D.world_to_tile(light.position)
		expect.call(BLOCK.has_point(tile) or ALCOVE.has_point(tile),
				"two-rect: room 0's light hangs over %s, off the floor" % tile)
		expect.call(light.omni_range >= 16.0 * 0.9,
				"two-rect: light range %.1f does not span the 16-tile bounds" % light.omni_range)

	var reveal: RoomReveal = ship.get_node("Reveal")
	expect.call(not reveal.is_revealed(0), "two-rect: room 0 revealed before entry")
	reveal.reveal(0)
	expect.call(reveal.is_revealed(0), "two-rect: room 0 did not reveal")
	expect.call(reveal._lights.get(0, []).size() == 1,
			"two-rect: room 0 registered %d lights, expected 1" % reveal._lights.get(0, []).size())


static func _check_tracker(expect: Callable, layout: ShipLayout, root: Node) -> void:
	var probe := Node3D.new()
	root.add_child(probe)
	var tracker := RoomTracker.new()
	root.add_child(tracker)
	tracker.setup(layout, probe)
	var changes: Array[int] = []
	tracker.room_changed.connect(func(room: int, _previous: int) -> void: changes.append(room))

	probe.global_position = ShipBuilder3D.tile_to_world(Vector2i(2, 2))
	tracker._physics_process(0.0)
	probe.global_position = ShipBuilder3D.tile_to_world(Vector2i(9, 2))
	tracker._physics_process(0.0)
	probe.global_position = ShipBuilder3D.tile_to_world(Vector2i(14, 2))
	tracker._physics_process(0.0)
	expect.call(changes == [0], "two-rect: walking block to alcove reported rooms %s, expected [0]" % [changes])
	probe.global_position = ShipBuilder3D.tile_to_world(Vector2i(2, 12))
	tracker._physics_process(0.0)
	expect.call(changes == [0, 1], "two-rect: stepping into the lower room reported %s" % [changes])

	root.remove_child(tracker)
	tracker.free()
	root.remove_child(probe)
	probe.free()


static func _check_crew_spawn(expect: Callable, layout: ShipLayout, ship: Node3D) -> void:
	var holder: Node3D = ship.get_node("Crew")
	expect.call(holder.get_child_count() == CREW,
			"two-rect: spawned %d crew, expected %d" % [holder.get_child_count(), CREW])
	var in_block := 0
	var in_alcove := 0
	var outside := 0
	var tiles := {}
	for member in holder.get_children():
		var tile := ShipBuilder3D.world_to_tile(member.position)
		tiles[tile] = true
		if BLOCK.has_point(tile):
			in_block += 1
		elif ALCOVE.has_point(tile):
			in_alcove += 1
		else:
			outside += 1
		expect.call(layout.rooms[0].has_tile(tile), "two-rect: crew spawned at %s, off the room's floor" % tile)
	expect.call(outside == 0, "two-rect: %d crew spawned outside the room" % outside)
	expect.call(in_block > 0 and in_alcove > 0,
			"two-rect: crew all on one side of the seam (%d block, %d alcove)" % [in_block, in_alcove])
	expect.call(tiles.size() == CREW, "two-rect: crew share spawn tiles (%d distinct of %d)" % [tiles.size(), CREW])


static func _check_routing(expect: Callable, layout: ShipLayout) -> void:
	var from := ShipBuilder3D.tile_to_world(Vector2i(2, 8))
	var to := ShipBuilder3D.tile_to_world(Vector2i(14, 2))
	var path := ShipNavigator.waypoints_3d(layout, from, to)
	expect.call(path.size() >= 2, "two-rect: route from block to alcove has %d points, expected a seam point first" % path.size())
	if not path.is_empty():
		expect.call(path[path.size() - 1].is_equal_approx(to), "two-rect: route does not end at the destination")
		expect.call(is_equal_approx(path[0].x, BLOCK.end.x * ShipBuilder3D.TILE),
				"two-rect: first point %s is not on the seam at x=%d" % [path[0], BLOCK.end.x])
	expect.call(_stays_on_floor(layout, from, path), "two-rect: route from block to alcove crosses a wall")

	# Same rect: straight there, no detour.
	var near := ShipBuilder3D.tile_to_world(Vector2i(8, 8))
	var direct := ShipNavigator.waypoints_3d(layout, from, near)
	expect.call(direct.size() == 1, "two-rect: route within the block has %d points, expected 1" % direct.size())

	# Across the door from the lower room into the alcove: door, seam, destination.
	var below := ShipBuilder3D.tile_to_world(Vector2i(8, 15))
	var up := ShipNavigator.waypoints_3d(layout, below, to)
	expect.call(up.size() == 3, "two-rect: route lower->alcove has %d points, expected door, seam, destination" % up.size())
	if up.size() == 3:
		expect.call(up[0].is_equal_approx(ShipBuilder3D.door_center_world(layout.doors[0])),
				"two-rect: route lower->alcove does not go through the door first")
		var seam_tile := ShipBuilder3D.world_to_tile(up[1])
		expect.call(layout.rooms[0].has_tile(seam_tile), "two-rect: seam point %s is not on room 0's floor" % up[1])
		expect.call(_stays_on_floor(layout, up[0], up.slice(1)), "two-rect: route door->alcove crosses a wall")


## Samples every leg of `path` from `start` and checks each sample lands on
## floor (a Room's own tiles or a doorway).
static func _stays_on_floor(layout: ShipLayout, start: Vector3, path: Array[Vector3]) -> bool:
	var floors := layout.floor_tiles()
	var cursor := start
	for point in path:
		var length := cursor.distance_to(point)
		var steps := maxi(int(length / 0.1), 1)
		for i in range(1, steps + 1):
			var sample := cursor.lerp(point, float(i) / steps)
			if not floors.has(ShipBuilder3D.world_to_tile(sample)):
				return false
		cursor = point
	return true
