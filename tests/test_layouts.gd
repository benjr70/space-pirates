extends SceneTree
## Headless checks on ship layouts and the geometry ShipBuilder makes from them.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_layouts.gd

var failures: Array[String] = []
var checks := 0

var main: Node2D
var player: CharacterBody2D
var floors: Dictionary
var directions := [
	Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
	Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
	Vector2(1, -1).normalized(), Vector2(-1, -1).normalized(),
]
var dir_index := 0
var built_layout: ShipLayout
var geometry_checked := false
var frames := 0
var escapes := 0


func _initialize() -> void:
	var layout := PlayerShipLayout.create()
	_check_rooms_disjoint(layout)
	_check_doors(layout)
	_check_connectivity(layout)

	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	player.set_physics_process(false)
	floors = layout.floor_tiles()
	built_layout = layout


func _physics_process(_delta: float) -> bool:
	# The scene's _ready runs after _initialize returns, so the built geometry is
	# only there to inspect once the first physics frame comes round.
	if not geometry_checked:
		geometry_checked = true
		_check_built_geometry(built_layout)

	# Shove the player hard in every direction; his centre must never leave the floor.
	player.velocity = directions[dir_index] * 500.0
	player.move_and_slide()
	if not floors.has(ShipBuilder.world_to_tile(player.global_position)):
		escapes += 1
	frames += 1
	if frames >= 150:
		frames = 0
		dir_index += 1
		if dir_index >= directions.size():
			_expect(escapes == 0, "player escaped the hull on %d physics frames" % escapes)
			_report()
			quit(1 if failures.size() > 0 else 0)
	return false


func _check_rooms_disjoint(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		for j in range(i + 1, layout.rooms.size()):
			var a := layout.rooms[i].rect
			var b := layout.rooms[j].rect
			_expect(not a.intersects(b), "rooms %d and %d overlap (%s / %s)" % [i, j, a, b])
			# Rooms must also not touch, or they would share no wall tile.
			_expect(not a.grow(1).intersects(b), "rooms %d and %d are flush; need a 1-tile wall gap" % [i, j])


func _check_doors(layout: ShipLayout) -> void:
	var floor_set := {}
	for room in layout.rooms:
		for x in range(room.rect.position.x, room.rect.end.x):
			for y in range(room.rect.position.y, room.rect.end.y):
				floor_set[Vector2i(x, y)] = true

	for d in layout.doors:
		_expect(d.room_a >= 0 and d.room_a < layout.rooms.size(), "door has bad room_a %d" % d.room_a)
		_expect(d.room_b >= 0 and d.room_b < layout.rooms.size(), "door has bad room_b %d" % d.room_b)
		_expect(not floor_set.has(d.tile), "door at %s sits on floor, not on a wall" % d.tile)
		var ring_a: Rect2i = layout.rooms[d.room_a].rect.grow(1)
		var ring_b: Rect2i = layout.rooms[d.room_b].rect.grow(1)
		_expect(ring_a.has_point(d.tile) and ring_b.has_point(d.tile),
				"door at %s is not on the wall shared by rooms %d and %d" % [d.tile, d.room_a, d.room_b])


func _check_connectivity(layout: ShipLayout) -> void:
	var adjacency := {}
	for i in layout.rooms.size():
		adjacency[i] = []
	for d in layout.doors:
		adjacency[d.room_a].append(d.room_b)
		adjacency[d.room_b].append(d.room_a)

	var seen := {layout.entry_room: true}
	var queue := [layout.entry_room]
	while not queue.is_empty():
		var room: int = queue.pop_front()
		for neighbour in adjacency[room]:
			if not seen.has(neighbour):
				seen[neighbour] = true
				queue.append(neighbour)

	_expect(seen.size() == layout.rooms.size(),
			"only %d of %d rooms reachable from the entry room" % [seen.size(), layout.rooms.size()])


func _check_built_geometry(layout: ShipLayout) -> void:
	var ship: Node2D = main.get_node("Ship")
	var floor_layer: TileMapLayer = ship.get_node("Floor")
	var wall_layer: TileMapLayer = ship.get_node("Walls")

	var expected_floor := layout.floor_tiles()
	_expect(floor_layer.get_used_cells().size() == expected_floor.size(),
			"painted %d floor tiles, expected %d" % [floor_layer.get_used_cells().size(), expected_floor.size()])
	_expect(wall_layer.get_used_cells().size() > 0, "no wall tiles were painted")

	# No tile may be both floor and wall, or doorways would be blocked.
	var clashes := 0
	for tile in wall_layer.get_used_cells():
		if expected_floor.has(tile):
			clashes += 1
	_expect(clashes == 0, "%d tiles are both floor and wall" % clashes)

	# Walls must fully enclose the floor: every floor tile's neighbours are floor or wall.
	var walls := ShipBuilder.wall_tiles(layout, expected_floor)
	var leaks := 0
	for tile in expected_floor:
		for step in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = tile + step
			if not expected_floor.has(n) and not walls.has(n):
				leaks += 1
	_expect(leaks == 0, "%d floor tiles open onto empty space" % leaks)

	var props: Node2D = ship.get_node("Props")
	var expected_props := 0
	for room in layout.rooms:
		expected_props += room.props.size()
	_expect(props.get_child_count() == expected_props,
			"spawned %d props, expected %d" % [props.get_child_count(), expected_props])


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _report() -> void:
	if failures.is_empty():
		print("PASS  %d checks" % checks)
	else:
		for f in failures:
			print("FAIL  ", f)
		print("FAILED  %d of %d checks" % [failures.size(), checks])
