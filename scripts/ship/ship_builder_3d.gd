class_name ShipBuilder3D
extends RefCounted
## Turns a [ShipLayout] into 3D geometry: GridMap floors, walls and ceilings on
## a 1 tile = 1 metre grid. Nothing else in the game should place cells by hand.
##
## Rooms live on the XZ plane; 2D tile y maps to 3D z. The meshes come from a
## MeshLibrary so the placeholder boxes can be swapped for a modular kit without
## touching this code.

## Metres per tile. Every 2D pixel constant divides by the old TILE_SIZE of 32
## to land here, so speeds and ranges carry their balance over unchanged.
const TILE := 1.0
const WALL_HEIGHT := 3.5
const CEILING_THICKNESS := 0.1
const FLOOR_THICKNESS := 0.1

## Wall neighbour mask bits, kept from the 2D builder so a directional kit can
## pick meshes per mask later. A bit is set when that side is ALSO a wall.
const N := 1
const E := 2
const S := 4
const W := 8

## MeshLibrary item ids, fixed so tests can assert on them.
const ITEM_FLOOR_PLATE := 0
const ITEM_FLOOR_BRIGHT := 1
const ITEM_FLOOR_ENGINE := 2
const ITEM_FLOOR_DOOR := 3
const ITEM_WALL := 4
const ITEM_CEILING := 5

## Floor look per room role. Unlisted roles fall back to plain plate.
const FLOOR_ITEM := {
	&"bridge": ITEM_FLOOR_BRIGHT,
	&"medbay": ITEM_FLOOR_BRIGHT,
	&"engine": ITEM_FLOOR_ENGINE,
	&"cargo": ITEM_FLOOR_PLATE,
	&"quarters": ITEM_FLOOR_PLATE,
	&"corridor": ITEM_FLOOR_PLATE,
}

const DOOR_SCENE: PackedScene = preload("res://scenes/door_3d.tscn")
const CREW_SCENE: PackedScene = preload("res://scenes/crew_3d.tscn")

const PROP_SCENES := {
	&"console": preload("res://scenes/props3d/prop_console_3d.tscn"),
	&"cryopod": preload("res://scenes/props3d/prop_cryopod_3d.tscn"),
	&"crate": preload("res://scenes/props3d/prop_crate_3d.tscn"),
	&"engine_console": preload("res://scenes/props3d/prop_engine_console_3d.tscn"),
	&"container": preload("res://scenes/props3d/prop_container_3d.tscn"),
	&"locker": preload("res://scenes/props3d/prop_locker_3d.tscn"),
}

static var _library: MeshLibrary


## Centre of a tile at floor level.
static func tile_to_world(tile: Vector2i) -> Vector3:
	return Vector3((tile.x + 0.5) * TILE, 0.0, (tile.y + 0.5) * TILE)


static func world_to_tile(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / TILE), floori(pos.z / TILE))


## Centre of a doorway at floor level, accounting for how many tiles wide it is.
static func door_center_world(door: DoorData) -> Vector3:
	return _span_center_world(door.tile, door.width, door.horizontal)


## Centre of a hatch gap at floor level.
static func hatch_center_world(hatch: HatchData) -> Vector3:
	return _span_center_world(hatch.tile, hatch.width, hatch.horizontal)


## Where a pirate boarding through [param hatch] stands: the centre of the
## first floor tile inside the gap, which every Hatch has (invariant 9),
## clear of the leaf. A step and a half would reach the second tile, and
## behind a Hatch on a ragged Hull the Room can be one tile deep.
static func hatch_entry_world(layout: ShipLayout, hatch: HatchData) -> Vector3:
	var step := hatch.inward(layout.rooms[hatch.room])
	return hatch_center_world(hatch) + Vector3(step.x, 0.0, step.y) * 1.0 * TILE


static func _span_center_world(tile: Vector2i, width: int, horizontal: bool) -> Vector3:
	var span := Vector2(width, 1) if horizontal else Vector2(1, width)
	var c := (Vector2(tile) + span / 2.0) * TILE
	return Vector3(c.x, 0.0, c.y)


## Centre of a room at floor level. Handles even-sized rooms correctly.
static func room_center_world(room: RoomData) -> Vector3:
	var c := room.center_tile() * TILE
	return Vector3(c.x, 0.0, c.y)


## Builds [param layout] as children of [param parent], which is cleared first
## so a ship can be re-rolled in place.
static func build(layout: ShipLayout, parent: Node3D) -> void:
	for child in parent.get_children():
		child.queue_free()
		parent.remove_child(child)

	var floors := layout.floor_tiles()
	var walls := wall_tiles(layout, floors)
	var lib := library()

	var floor_map := _make_gridmap("Floor", lib)
	parent.add_child(floor_map)
	var wall_map := _make_gridmap("Walls", lib)
	parent.add_child(wall_map)
	var ceiling_map := _make_gridmap("Ceiling", lib)
	parent.add_child(ceiling_map)

	for room in layout.rooms:
		var item: int = FLOOR_ITEM.get(room.role, ITEM_FLOOR_PLATE)
		for tile: Vector2i in room.tiles():
			floor_map.set_cell_item(Vector3i(tile.x, 0, tile.y), item)
			ceiling_map.set_cell_item(Vector3i(tile.x, 0, tile.y), ITEM_CEILING)

	for door in layout.doors:
		for tile in door.tiles():
			floor_map.set_cell_item(Vector3i(tile.x, 0, tile.y), ITEM_FLOOR_DOOR)
			ceiling_map.set_cell_item(Vector3i(tile.x, 0, tile.y), ITEM_CEILING)

	# Hatch gaps are punched through the hull the same way: the wall ring
	# already skips them because they are floor, so they only need a threshold.
	for hatch in layout.hatches:
		for tile in hatch.tiles():
			floor_map.set_cell_item(Vector3i(tile.x, 0, tile.y), ITEM_FLOOR_DOOR)
			ceiling_map.set_cell_item(Vector3i(tile.x, 0, tile.y), ITEM_CEILING)

	for tile: Vector2i in walls:
		wall_map.set_cell_item(Vector3i(tile.x, 0, tile.y), ITEM_WALL)

	var reveal := RoomReveal.new()
	reveal.name = "Reveal"
	parent.add_child(reveal)
	reveal.setup(layout)

	var lights := Node3D.new()
	lights.name = "Lights"
	parent.add_child(lights)
	for i in layout.rooms.size():
		var light := _room_light(layout.rooms[i])
		lights.add_child(light)
		reveal.register_light(i, light)

	var props := Node3D.new()
	props.name = "Props"
	parent.add_child(props)
	for i in layout.rooms.size():
		for prop in layout.rooms[i].props:
			var node := _spawn_prop(prop, props)
			if node != null:
				reveal.register_content(i, node)

	var doors := Node3D.new()
	doors.name = "Doors"
	parent.add_child(doors)
	for door_data in layout.doors:
		var door: Door3D = DOOR_SCENE.instantiate()
		# Sized before it enters the tree, since the span comes from the layout.
		door.setup(door_data)
		door.position = door_center_world(door_data)
		doors.add_child(door)

	# A leaf in every hatch gap keeps the hull sealed until the pirate works
	# it, so boarding and extracting are the same interaction as any door.
	var hatches := Node3D.new()
	hatches.name = "Hatches"
	parent.add_child(hatches)
	for hatch_data in layout.hatches:
		var leaf: Door3D = DOOR_SCENE.instantiate()
		leaf.setup_hatch(hatch_data)
		leaf.position = hatch_center_world(hatch_data)
		hatches.add_child(leaf)

	var crew := Node3D.new()
	crew.name = "Crew"
	parent.add_child(crew)
	for i in layout.rooms.size():
		var room: RoomData = layout.rooms[i]
		for n in room.crew_count:
			var hostile: Crew3D = CREW_SCENE.instantiate()
			hostile.layout = layout
			hostile.home_room = i
			# Interior generation names each body's tile; hand-authored Rooms
			# are spread across the floor.
			if n < room.crew_spawns.size():
				hostile.position = tile_to_world(room.crew_spawns[n])
				if n < room.crew_facings.size() and room.crew_facings[n] != Vector2i.ZERO:
					hostile.face_direction(Vector3(room.crew_facings[n].x, 0.0, room.crew_facings[n].y))
			else:
				hostile.position = crew_spawn_position(room, n)
			crew.add_child(hostile)
			reveal.register_mobile(hostile)


## Every tile that should hold wall: the one-tile ring around each rect of each
## room, minus anything that is floor somewhere (which is what makes two rooms
## placed a tile apart share a single wall, and leaves the seam between a
## room's own rects open).
static func wall_tiles(layout: ShipLayout, floors: Dictionary) -> Dictionary:
	var walls := {}
	for room in layout.rooms:
		for rect in room.shape():
			var ring := rect.grow(1)
			for x in range(ring.position.x, ring.end.x):
				for y in range(ring.position.y, ring.end.y):
					var tile := Vector2i(x, y)
					if not floors.has(tile):
						walls[tile] = true
	return walls


## Which of a wall tile's four neighbours are also wall. The placeholder wall is
## a plain box so every mask draws alike, but a directional kit keys off this.
static func wall_mask(tile: Vector2i, walls: Dictionary) -> int:
	var mask := 0
	if walls.has(tile + Vector2i.UP):
		mask |= N
	if walls.has(tile + Vector2i.RIGHT):
		mask |= E
	if walls.has(tile + Vector2i.DOWN):
		mask |= S
	if walls.has(tile + Vector2i.LEFT):
		mask |= W
	return mask


## Spreads crew across a room, keeping clear of the tiles its props sit on.
## A multi-rect room deals crew round-robin across its rects, so a crew of
## any size straddles the seams.
static func crew_spawn_position(room: RoomData, index: int) -> Vector3:
	var parts := room.shape()
	var rect: Rect2i = parts[index % parts.size()]
	@warning_ignore("integer_division")
	index = index / parts.size()
	var inner := rect.grow(-1)
	if inner.size.x < 1 or inner.size.y < 1:
		inner = rect

	var taken := {}
	for prop in room.props:
		var at: Vector2i = prop.get("tile", Vector2i.ZERO)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				taken[at + Vector2i(dx, dy)] = true

	for attempt in 12:
		var step := index * 3 + attempt * 5
		var tile := inner.position + Vector2i(
				(step + 1) % inner.size.x,
				(step * 2 + 2) % inner.size.y)
		if not taken.has(tile):
			return tile_to_world(tile)
	return room_center_world(room)


static func _make_gridmap(map_name: String, lib: MeshLibrary) -> GridMap:
	var map := GridMap.new()
	map.name = map_name
	map.mesh_library = lib
	map.cell_size = Vector3(TILE, WALL_HEIGHT, TILE)
	map.cell_center_y = false
	map.collision_layer = 1
	map.collision_mask = 0
	return map


## A Room's light, tinted by its Role's row of the flavour table: the
## cheapest two-second read a greybox has.
static func _room_light(room: RoomData) -> OmniLight3D:
	var light := OmniLight3D.new()
	var center := room_center_world(room)
	light.position = Vector3(center.x, WALL_HEIGHT - 0.3, center.z)
	light.light_color = RoleFlavour.light(room.role)
	var box := room.bounds()
	light.omni_range = maxf(float(box.size.x), float(box.size.y)) * TILE * 0.9 + 2.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	return light


## One prop. A kind named only in the flavour table (safe, generator,
## cabinet, footlocker) is built as its placeholder scene until its art
## lands; whatever carries gold is a Container, whatever its shape.
static func _spawn_prop(prop: Dictionary, parent: Node3D) -> Node3D:
	var type: StringName = prop.get("type", &"")
	if not PROP_SCENES.has(type):
		type = RoleFlavour.placeholder(type)
	if not PROP_SCENES.has(type):
		push_warning("ShipBuilder3D: unknown prop type %s" % type)
		return null
	var node: Node3D = PROP_SCENES[type].instantiate()
	node.position = tile_to_world(prop.get("tile", Vector2i.ZERO))
	if prop.get("rotated", false):
		node.rotation.y = PI / 2.0
	if prop.has("gold") and not node is Container3D:
		node.set_script(Container3D)
	if node is Container3D:
		node.gold = prop.get("gold", 0)
	if prop.get("breaker", false):
		node.add_to_group(&"breakers")
	parent.add_child(node)
	return node


## The MeshLibrary in use: placeholder boxes today, a modular kit once one is
## exported over the top. Built once and cached.
static func library() -> MeshLibrary:
	if _library != null:
		return _library
	_library = _fallback_library()
	return _library


## Grey-box items with real collision, so gameplay and headless tests never
## depend on imported art.
static func _fallback_library() -> MeshLibrary:
	var lib := MeshLibrary.new()
	_add_box_item(lib, ITEM_FLOOR_PLATE, "floor_plate",
			Vector3(TILE, FLOOR_THICKNESS, TILE), -FLOOR_THICKNESS / 2.0,
			"res://assets/textures/kenney_prototype/dark_01.png", Color(0.55, 0.58, 0.62))
	_add_box_item(lib, ITEM_FLOOR_BRIGHT, "floor_bright",
			Vector3(TILE, FLOOR_THICKNESS, TILE), -FLOOR_THICKNESS / 2.0,
			"res://assets/textures/kenney_prototype/light_01.png", Color(0.8, 0.82, 0.85))
	_add_box_item(lib, ITEM_FLOOR_ENGINE, "floor_engine",
			Vector3(TILE, FLOOR_THICKNESS, TILE), -FLOOR_THICKNESS / 2.0,
			"res://assets/textures/kenney_prototype/orange_01.png", Color(0.85, 0.6, 0.35))
	_add_box_item(lib, ITEM_FLOOR_DOOR, "floor_door",
			Vector3(TILE, FLOOR_THICKNESS, TILE), -FLOOR_THICKNESS / 2.0,
			"res://assets/textures/kenney_prototype/red_01.png", Color(0.8, 0.45, 0.3))
	# Wall collision runs slightly proud of the mesh so neighbouring boxes
	# overlap: a fast capsule can catch the seam between two flush shapes and
	# get squeezed through an inside corner.
	_add_box_item(lib, ITEM_WALL, "wall",
			Vector3(TILE, WALL_HEIGHT, TILE), WALL_HEIGHT / 2.0,
			"res://assets/textures/kenney_prototype/dark_08.png", Color(0.4, 0.44, 0.52),
			Vector3(TILE + 0.08, WALL_HEIGHT, TILE + 0.08))
	_add_box_item(lib, ITEM_CEILING, "ceiling",
			Vector3(TILE, CEILING_THICKNESS, TILE), WALL_HEIGHT + CEILING_THICKNESS / 2.0,
			"res://assets/textures/kenney_prototype/purple_01.png", Color(0.35, 0.35, 0.42))
	return lib


static func _add_box_item(lib: MeshLibrary, id: int, item_name: String,
		size: Vector3, y_offset: float, texture_path: String, tint: Color,
		shape_size: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	if ResourceLoader.exists(texture_path):
		material.albedo_texture = load(texture_path)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mesh.material = material

	var shape := BoxShape3D.new()
	shape.size = shape_size if shape_size != Vector3.ZERO else size
	var offset := Transform3D(Basis.IDENTITY, Vector3(0.0, y_offset, 0.0))

	lib.create_item(id)
	lib.set_item_name(id, item_name)
	lib.set_item_mesh(id, mesh)
	lib.set_item_mesh_transform(id, offset)
	lib.set_item_shapes(id, [shape, offset])
