class_name BuiltSampleChecks
extends RefCounted
## The built sample: a few generated seeds per Class built through the 3D
## builder inside the main scene, checked over two physics frames each:
## geometry, prop placement and collision, every Door and Hatch swept by
## the player's capsule, the floor holding a ray, a route from the Bridge
## to an Engine, and crew finding cover. Driven a frame at a time from the
## headless 3D suite: `begin(...)`, then `tick()` until it returns true.
##
## The gunfight itself runs once, on the hand-authored ship: it costs
## hundreds of frames per ship and proves the crew, not the generator.

const SEEDS_PER_CLASS := 3
const FIRST_SEED := 1

var _expect: Callable
var _root: Node
var _ships: Array = []   # [{ship_class, seed}]
var _index := 0
var _state := 0
var _main: Node3D
var _layout: ShipLayout


func begin(expect: Callable, root: Node) -> void:
	_expect = expect
	_root = root
	for ship_class in ShipGenerator.CLASSES:
		for seed in range(FIRST_SEED, FIRST_SEED + SEEDS_PER_CLASS):
			_ships.append({ship_class = ship_class, seed = seed})


## Advance one physics frame. True once every ship has been checked.
func tick() -> bool:
	if _index >= _ships.size():
		return true
	var ship: Dictionary = _ships[_index]
	match _state:
		0:
			_layout = ShipGenerator.generate(ship.ship_class, ship.seed)
			_main = load("res://scenes/main_3d.tscn").instantiate()
			_main.layout_override = _layout
			_main.explore_darkness = false
			_root.add_child(_main)
			_check_geometry(ship)
			_check_props(ship)
			for leaf: Door3D in _main.get_node("Ship/Doors").get_children() + _main.get_node("Ship/Hatches").get_children():
				leaf.open()
			_state = 1
		1:
			# GridMap and prop physics come live a frame after entering the tree.
			_state = 2
		2:
			_check_sweeps(ship)
			_check_floor(ship)
			_check_route(ship)
			_check_prop_collision(ship)
			_check_cover(ship)
			_root.remove_child(_main)
			_main.free()
			_main = null
			_index += 1
			_state = 0
	return _index >= _ships.size()


func _tag(ship: Dictionary) -> String:
	return "built %s seed %d" % [ship.ship_class, ship.seed]


func _check_geometry(ship: Dictionary) -> void:
	var floor_map: GridMap = _main.get_node("Ship/Floor")
	var wall_map: GridMap = _main.get_node("Ship/Walls")
	var expected := _layout.floor_tiles()
	_expect.call(floor_map.get_used_cells().size() == expected.size(),
			"%s: %d floor cells for %d floor tiles" % [_tag(ship), floor_map.get_used_cells().size(), expected.size()])
	var clashes := 0
	for cell: Vector3i in wall_map.get_used_cells():
		if expected.has(Vector2i(cell.x, cell.z)):
			clashes += 1
	_expect.call(clashes == 0, "%s: %d cells both floor and wall" % [_tag(ship), clashes])
	_expect.call(_main.get_node("Ship/Doors").get_child_count() == _layout.doors.size(),
			"%s: door leaves do not match doors" % _tag(ship))
	_expect.call(_main.get_node("Ship/Hatches").get_child_count() == _layout.hatches.size(),
			"%s: hatch leaves do not match hatches" % _tag(ship))
	var crew: Node3D = _main.get_node("Ship/Crew")
	var expected_crew := 0
	for room in _layout.rooms:
		expected_crew += room.crew_count
	_expect.call(crew.get_child_count() == expected_crew, "%s: %d crew for %d shares" % [_tag(ship), crew.get_child_count(), expected_crew])
	for member: Crew3D in crew.get_children():
		var room: RoomData = _layout.rooms[member.home_room]
		var tile := ShipBuilder3D.world_to_tile(member.global_position)
		_expect.call(room.crew_spawns.has(tile), "%s: crew of room %d stands on %s, not a spawn tile" % [_tag(ship), member.home_room, tile])
		var k := room.crew_spawns.find(tile)
		if k >= 0 and k < room.crew_facings.size() and room.crew_facings[k] != Vector2i.ZERO:
			var f := room.crew_facings[k]
			var want := atan2(-float(f.x), -float(f.y))
			_expect.call(is_equal_approx(wrapf(member.rotation.y - want, -PI, PI), 0.0),
					"%s: crew of room %d at %s faces %.2f rad, layout says %s" % [_tag(ship), member.home_room, tile, member.rotation.y, f])
		member.set_physics_process(false)
	# Every Room's light carries its Role's tint from the flavour table.
	var lights: Node3D = _main.get_node("Ship/Lights")
	_expect.call(lights.get_child_count() == _layout.rooms.size(), "%s: %d lights for %d rooms" % [_tag(ship), lights.get_child_count(), _layout.rooms.size()])
	for i in mini(lights.get_child_count(), _layout.rooms.size()):
		var light: OmniLight3D = lights.get_child(i)
		var want := RoleFlavour.light(_layout.rooms[i].role)
		_expect.call(light.light_color.is_equal_approx(want),
				"%s: room %d (%s) lit %s, table says %s" % [_tag(ship), i, _layout.rooms[i].role, light.light_color, want])


## Every prop stands where the layout put it, with collision, Containers
## carrying their gold.
func _check_props(ship: Dictionary) -> void:
	var props: Node3D = _main.get_node("Ship/Props")
	var by_tile := {}
	for node: Node3D in props.get_children():
		by_tile[ShipBuilder3D.world_to_tile(node.position)] = node
	var expected := 0
	for i in _layout.rooms.size():
		for prop in _layout.rooms[i].props:
			expected += 1
			var node: Node3D = by_tile.get(prop.tile, null)
			_expect.call(node != null, "%s: no prop node at %s for %s" % [_tag(ship), prop.tile, prop.type])
			if node == null:
				continue
			_expect.call(node.find_child("CollisionShape3D", true, false) != null, "%s: prop %s at %s has no collision" % [_tag(ship), prop.type, prop.tile])
			if prop.has("gold"):
				_expect.call(node is Container3D and node.gold == prop.gold and node.is_in_group(&"containers"),
						"%s: %s at %s does not carry %d gold as a Container" % [_tag(ship), prop.type, prop.tile, prop.gold])
			if prop.get("breaker", false):
				_expect.call(node.is_in_group(&"breakers"), "%s: breaker at %s not marked" % [_tag(ship), prop.tile])
	_expect.call(props.get_child_count() == expected, "%s: %d prop nodes for %d props" % [_tag(ship), props.get_child_count(), expected])


## The player's capsule passes through every open Door and Hatch.
func _check_sweeps(ship: Dictionary) -> void:
	var player: CharacterBody3D = _main.get_node("Player")
	var blocked := 0
	for door in _layout.doors:
		if _sweep_hits(player, ShipBuilder3D.door_center_world(door), door.horizontal):
			blocked += 1
	for hatch in _layout.hatches:
		if _sweep_hits(player, ShipBuilder3D.hatch_center_world(hatch), hatch.horizontal):
			blocked += 1
	_expect.call(blocked == 0, "%s: the capsule caught on %d of %d doorways" % [_tag(ship), blocked, _layout.doors.size() + _layout.hatches.size()])


func _sweep_hits(player: CharacterBody3D, centre: Vector3, horizontal: bool) -> bool:
	var across := Vector3(0, 0, 1) if horizontal else Vector3(1, 0, 0)
	var from := Transform3D(Basis.IDENTITY, centre - across * 1.5)
	return player.test_move(from, across * 3.0)


## Floor holds a ray under the boarding point of every Hatch.
func _check_floor(ship: Dictionary) -> void:
	var player: CharacterBody3D = _main.get_node("Player")
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	for hatch in _layout.hatches:
		var at := ShipBuilder3D.hatch_entry_world(_layout, hatch)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP, at - Vector3.UP, 1))
		_expect.call(not hit.is_empty(), "%s: no floor under the boarding point of the hatch at %s" % [_tag(ship), hatch.tile])


func _check_route(ship: Dictionary) -> void:
	var bridge := -1
	var engine := -1
	for i in _layout.rooms.size():
		if _layout.rooms[i].role == &"bridge":
			bridge = i
		elif _layout.rooms[i].role == &"engine" and engine < 0:
			engine = i
	var rooms := ShipNavigator.room_path(_layout, bridge, engine)
	_expect.call(not rooms.is_empty(), "%s: no route from the bridge to an engine" % _tag(ship))
	var points := ShipNavigator.waypoints_3d(_layout, ShipBuilder3D.room_center_world(_layout.rooms[bridge]),
			ShipBuilder3D.room_center_world(_layout.rooms[engine]))
	_expect.call(points.size() >= rooms.size(), "%s: %d waypoints for a %d-room route" % [_tag(ship), points.size(), rooms.size()])


## A ray from above every prop lands on that prop.
func _check_prop_collision(ship: Dictionary) -> void:
	var props: Node3D = _main.get_node("Ship/Props")
	var space: PhysicsDirectSpaceState3D = props.get_world_3d().direct_space_state
	var missing := 0
	for node: Node3D in props.get_children():
		var top: Vector3 = node.global_position + Vector3.UP * 2.4
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, node.global_position + Vector3.UP * 0.05, 1))
		if hit.is_empty() or hit.collider != node:
			missing += 1
	_expect.call(missing == 0, "%s: %d props have no collision where they stand" % [_tag(ship), missing])


## Crew stood at their spawn can find cover from a pirate at their Room's
## doorway: somewhere solid stands between the two, for at least half of
## the first six tried.
func _check_cover(ship: Dictionary) -> void:
	var player: CharacterBody3D = _main.get_node("Player")
	var found := 0
	var tried := 0
	for member: Crew3D in _main.get_node("Ship/Crew").get_children():
		var room: int = member.home_room
		var openings := Interiors.openings(_layout, room)
		if openings.is_empty():
			continue
		var apron: Vector2i = openings[0].tiles[0] + openings[0].normal
		player.global_position = ShipBuilder3D.tile_to_world(apron)
		member.target = player
		member._last_seen = player.global_position
		tried += 1
		if member._find_cover_point() != Vector3.INF:
			found += 1
		if tried >= 6:
			break
	_expect.call(found * 2 >= tried, "%s: only %d of %d crew could find cover from the doorway" % [_tag(ship), found, tried])
