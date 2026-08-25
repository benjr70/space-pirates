extends SceneTree
## Headless checks on ship layouts and the geometry ShipBuilder makes from them.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_layouts.gd

## A room smaller than this cannot hold a fight -- the pirate, a couple of
## crewmates and a few hostiles all need somewhere to move.
const MIN_ROOM_SIZE := Vector2i(8, 6)
const MIN_ROOM_AREA := 60

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
var phase := 0
var locked_push := Vector2.ZERO
var locked_from := -1
var locked_to := -1
var test_door: Door
var test_door_data: DoorData
var frames := 0
var escapes := 0


func _initialize() -> void:
	var layout := PlayerShipLayout.create()
	_check_rooms_disjoint(layout)
	_check_rooms_fightable(layout)
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

	if phase == 2:
		_physics_open_door()
		return false
	if phase == 1:
		_physics_locked_door()
		return false

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
			_begin_open_door_phase()
	return false


## Stand him next to an unlocked door; it should notice him and open.
func _begin_open_door_phase() -> void:
	# The sweep dragged him through several rooms; the fog should have lifted off them.
	var fog: RoomFog = main.get_node("Ship/Fog")
	var seen := 0
	for i in built_layout.rooms.size():
		if fog.is_revealed(i):
			seen += 1
	_expect(seen > 1, "only %d room revealed after walking the whole ship" % seen)

	var doors: Node2D = main.get_node("Ship/Doors")
	for i in built_layout.doors.size():
		if not built_layout.doors[i].locked:
			test_door = doors.get_child(i)
			test_door_data = built_layout.doors[i]
			break
	if test_door == null:
		_begin_locked_door_phase()
		return
	# Straight back from the threshold on the room_a side: close enough to reach
	# the controls, far enough that his collider is clear of the doorway itself.
	var from := ShipBuilder.room_center_world(built_layout.rooms[test_door_data.room_a])
	var door_pos: Vector2 = ShipBuilder.door_center_world(test_door_data)
	var across := Vector2.DOWN if test_door_data.horizontal else Vector2.RIGHT
	var side := signf((from - door_pos).dot(across))
	player.global_position = door_pos + across * (side if side != 0.0 else 1.0) * 44.0
	player.velocity = Vector2.ZERO
	phase = 2
	frames = 0


## Walks the interact key through a full open/close cycle on one door.
func _physics_open_door() -> void:
	player.move_and_slide()
	frames += 1
	match frames:
		5:
			_expect(test_door.in_reach(), "door did not notice the player standing next to it")
			_expect(test_door.close(), "door would not shut with nobody in the doorway")
		7:
			_expect(not test_door.is_open, "door is still open after being shut")
		8:
			Input.action_press("interact")
		9:
			Input.action_release("interact")
		14:
			_expect(test_door.is_open, "pressing interact did not open the door")
		15:
			Input.action_press("interact")
		16:
			Input.action_release("interact")
		21:
			_expect(not test_door.is_open, "pressing interact again did not shut the door")
			_begin_locked_door_phase()


## Park him in the medbay and shove him at the locked interior door.
func _begin_locked_door_phase() -> void:
	var locked_door: DoorData = null
	for d in built_layout.doors:
		if d.locked:
			locked_door = d
			break
	if locked_door == null:
		_report()
		quit(1 if failures.size() > 0 else 0)
		return
	locked_from = locked_door.room_a
	locked_to = locked_door.room_b
	player.global_position = ShipBuilder.room_center_world(built_layout.rooms[locked_from])
	player.velocity = Vector2.ZERO
	var toward: Vector2 = ShipBuilder.room_center_world(built_layout.rooms[locked_to]) - player.global_position
	locked_push = toward.normalized()
	phase = 1
	frames = 0


func _physics_locked_door() -> void:
	player.velocity = locked_push * 500.0
	player.move_and_slide()
	frames += 1
	if frames >= 240:
		var room := built_layout.room_at(ShipBuilder.world_to_tile(player.global_position))
		_expect(room != locked_to,
				"player walked through a locked door into room %d" % locked_to)
		_report()
		quit(1 if failures.size() > 0 else 0)


func _check_rooms_disjoint(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		for j in range(i + 1, layout.rooms.size()):
			var a := layout.rooms[i].rect
			var b := layout.rooms[j].rect
			_expect(not a.intersects(b), "rooms %d and %d overlap (%s / %s)" % [i, j, a, b])
			# Rooms must also not touch, or they would share no wall tile.
			_expect(not a.grow(1).intersects(b), "rooms %d and %d are flush; need a 1-tile wall gap" % [i, j])


func _check_rooms_fightable(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		var size := layout.rooms[i].rect.size
		_expect(size.x >= MIN_ROOM_SIZE.x and size.y >= MIN_ROOM_SIZE.y,
				"room %d is %s tiles, below the %s minimum for a fight" % [i, size, MIN_ROOM_SIZE])
		_expect(size.x * size.y >= MIN_ROOM_AREA,
				"room %d has %d floor tiles, want at least %d" % [i, size.x * size.y, MIN_ROOM_AREA])


func _check_doors(layout: ShipLayout) -> void:
	var floor_set := {}
	for room in layout.rooms:
		for x in range(room.rect.position.x, room.rect.end.x):
			for y in range(room.rect.position.y, room.rect.end.y):
				floor_set[Vector2i(x, y)] = true

	for d in layout.doors:
		_expect(d.room_a >= 0 and d.room_a < layout.rooms.size(), "door has bad room_a %d" % d.room_a)
		_expect(d.room_b >= 0 and d.room_b < layout.rooms.size(), "door has bad room_b %d" % d.room_b)
		_expect(d.width >= 1, "door at %s has width %d" % [d.tile, d.width])
		var ring_a: Rect2i = layout.rooms[d.room_a].rect.grow(1)
		var ring_b: Rect2i = layout.rooms[d.room_b].rect.grow(1)
		for tile in d.tiles():
			_expect(not floor_set.has(tile), "doorway tile %s sits on floor, not on a wall" % tile)
			_expect(ring_a.has_point(tile) and ring_b.has_point(tile),
					"doorway tile %s is not on the wall shared by rooms %d and %d" % [tile, d.room_a, d.room_b])


func _check_connectivity(layout: ShipLayout) -> void:
	var adjacency := {}
	for i in layout.rooms.size():
		adjacency[i] = []
	for d in layout.doors:
		if d.locked:
			continue  # a locked door must never be the only way into a room
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
			"only %d of %d rooms reachable from the entry room through unlocked doors" % [seen.size(), layout.rooms.size()])


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

	var doors: Node2D = ship.get_node("Doors")
	_expect(doors.get_child_count() == layout.doors.size(),
			"spawned %d doors, expected %d" % [doors.get_child_count(), layout.doors.size()])
	for i in mini(doors.get_child_count(), layout.doors.size()):
		var node: Door = doors.get_child(i)
		var data: DoorData = layout.doors[i]
		_expect(node.position.is_equal_approx(ShipBuilder.door_center_world(data)),
				"door %d sits at %s, expected %s" % [i, node.position, ShipBuilder.door_center_world(data)])
		var shape: RectangleShape2D = node.get_node("Blocker/CollisionShape2D").shape
		var span := data.width * ShipBuilder.TILE_SIZE
		var along := shape.size.x if data.horizontal else shape.size.y
		_expect(is_equal_approx(along, span),
				"door %d blocks %s px of a %d px doorway" % [i, along, span])
		_expect(not node.is_open, "door %d starts open" % i)
		if data.locked:
			node.open()
			_expect(not node.is_open, "locked door %d opened anyway" % i)

	# Doorways stay lit so exits are visible from inside a dark room.
	var shades: Array[Rect2] = []
	_collect_shades(ship.get_node("Fog"), shades)
	_expect(shades.size() > 0, "fog painted nothing")
	var covered := 0
	for d in layout.doors:
		for tile in d.tiles():
			var center := ShipBuilder.tile_to_world(tile)
			for shade in shades:
				if shade.has_point(center):
					covered += 1
					break
	_expect(covered == 0, "%d doorway tiles are hidden under the fog" % covered)

	var fog: RoomFog = ship.get_node("Fog")
	_expect(fog.is_revealed(layout.entry_room), "entry room is still dark")
	for i in layout.rooms.size():
		if i != layout.entry_room:
			_expect(not fog.is_revealed(i), "room %d was revealed before being entered" % i)

	# Doors no longer open on approach, so prop the ship open for the roam below.
	for door_node in doors.get_children():
		door_node.open()

	var props: Node2D = ship.get_node("Props")
	var expected_props := 0
	for room in layout.rooms:
		expected_props += room.props.size()
	_expect(props.get_child_count() == expected_props,
			"spawned %d props, expected %d" % [props.get_child_count(), expected_props])


func _collect_shades(node: Node, out: Array[Rect2]) -> void:
	for child in node.get_children():
		if child is ColorRect:
			out.append(Rect2(child.global_position, child.size))
		else:
			_collect_shades(child, out)


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
