class_name ShipBuilder
extends RefCounted
## Turns a [ShipLayout] into actual geometry: tilemap floors, colliding walls
## and props. Nothing else in the game should place tiles by hand.

const TILE_SIZE := 32
const SOURCE_ID := 0

const TILESET: TileSet = preload("res://assets/tilesets/ship_tileset.tres")

## Wall neighbour mask bits. A bit is set when that side is ALSO a wall, so the
## atlas tile can draw its bright trim only on the sides facing open floor.
const N := 1
const E := 2
const S := 4
const W := 8

## Floor look per room role. Unlisted roles fall back to plain plate.
const FLOOR_ATLAS := {
	&"bridge": Vector2i(2, 0),
	&"medbay": Vector2i(2, 0),
	&"engine": Vector2i(1, 0),
	&"cargo": Vector2i(0, 0),
	&"quarters": Vector2i(0, 0),
}
const DEFAULT_FLOOR_ATLAS := Vector2i(0, 0)
## Doorways get hazard striping so the gaps read as thresholds.
const DOOR_FLOOR_ATLAS := Vector2i(3, 0)

const DOOR_SCENE: PackedScene = preload("res://scenes/door.tscn")
const CREW_SCENE: PackedScene = preload("res://scenes/crew.tscn")

const PROP_SCENES := {
	&"console": preload("res://scenes/props/prop_console.tscn"),
	&"cryopod": preload("res://scenes/props/prop_cryopod.tscn"),
	&"crate": preload("res://scenes/props/prop_crate.tscn"),
	&"engine_console": preload("res://scenes/props/prop_engine_console.tscn"),
}


## Centre of a tile, in world pixels.
static func tile_to_world(tile: Vector2i) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * TILE_SIZE


static func world_to_tile(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / TILE_SIZE), floor(pos.y / TILE_SIZE))


## Centre of a doorway, in world pixels, accounting for how many tiles wide it is.
static func door_center_world(door: DoorData) -> Vector2:
	var span := Vector2(door.width, 1) if door.horizontal else Vector2(1, door.width)
	return (Vector2(door.tile) + span / 2.0) * TILE_SIZE


## Centre of a room, in world pixels. Handles even-sized rooms correctly.
static func room_center_world(room: RoomData) -> Vector2:
	return room.center_tile() * TILE_SIZE


## Builds [param layout] as children of [param parent], which is cleared first
## so a ship can be re-rolled in place.
static func build(layout: ShipLayout, parent: Node2D) -> void:
	for child in parent.get_children():
		child.queue_free()
		parent.remove_child(child)

	var floors := layout.floor_tiles()
	var walls := wall_tiles(layout, floors)

	var floor_layer := TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = TILESET
	floor_layer.z_index = -20
	parent.add_child(floor_layer)

	var wall_layer := TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = TILESET
	wall_layer.z_index = -10
	parent.add_child(wall_layer)

	for room in layout.rooms:
		var atlas: Vector2i = FLOOR_ATLAS.get(room.role, DEFAULT_FLOOR_ATLAS)
		for x in range(room.rect.position.x, room.rect.end.x):
			for y in range(room.rect.position.y, room.rect.end.y):
				floor_layer.set_cell(Vector2i(x, y), SOURCE_ID, atlas)

	for door in layout.doors:
		for tile in door.tiles():
			floor_layer.set_cell(tile, SOURCE_ID, DOOR_FLOOR_ATLAS)

	for tile in walls:
		wall_layer.set_cell(tile, SOURCE_ID, wall_atlas(tile, walls))

	var props := Node2D.new()
	props.name = "Props"
	parent.add_child(props)
	for room in layout.rooms:
		for prop in room.props:
			_spawn_prop(prop, props)

	var doors := Node2D.new()
	doors.name = "Doors"
	parent.add_child(doors)
	for door_data in layout.doors:
		var door: Door = DOOR_SCENE.instantiate()
		# Sized before it enters the tree, since the span comes from the layout.
		door.setup(door_data)
		door.position = door_center_world(door_data)
		doors.add_child(door)

	var crew := Node2D.new()
	crew.name = "Crew"
	parent.add_child(crew)
	for i in layout.rooms.size():
		var room: RoomData = layout.rooms[i]
		for n in room.crew_count:
			var hostile: Crew = CREW_SCENE.instantiate()
			hostile.layout = layout
			hostile.home_room = i
			hostile.position = crew_spawn_position(room, n)
			crew.add_child(hostile)

	var fog := RoomFog.new()
	fog.name = "Fog"
	fog.z_index = 10
	parent.add_child(fog)
	fog.setup(layout)


## Every tile that should hold wall: the one-tile ring around each room, minus
## anything that is floor somewhere (which is what makes two rooms placed a tile
## apart end up sharing a single wall between them).
static func wall_tiles(layout: ShipLayout, floors: Dictionary) -> Dictionary:
	var walls := {}
	for room in layout.rooms:
		var ring := room.rect.grow(1)
		for x in range(ring.position.x, ring.end.x):
			for y in range(ring.position.y, ring.end.y):
				var tile := Vector2i(x, y)
				if not floors.has(tile):
					walls[tile] = true
	return walls


## Picks the atlas tile for a wall from which of its four neighbours are wall.
static func wall_atlas(tile: Vector2i, walls: Dictionary) -> Vector2i:
	var mask := 0
	if walls.has(tile + Vector2i.UP):
		mask |= N
	if walls.has(tile + Vector2i.RIGHT):
		mask |= E
	if walls.has(tile + Vector2i.DOWN):
		mask |= S
	if walls.has(tile + Vector2i.LEFT):
		mask |= W
	return Vector2i(mask % 8, 1 + mask / 8)


## Spreads crew across a room, keeping clear of the tiles its props sit on.
static func crew_spawn_position(room: RoomData, index: int) -> Vector2:
	var inner := room.rect.grow(-1)
	if inner.size.x < 1 or inner.size.y < 1:
		inner = room.rect

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


static func _spawn_prop(prop: Dictionary, parent: Node2D) -> void:
	var type: StringName = prop.get("type", &"")
	if not PROP_SCENES.has(type):
		push_warning("ShipBuilder: unknown prop type %s" % type)
		return
	var node: Node2D = PROP_SCENES[type].instantiate()
	node.position = tile_to_world(prop.get("tile", Vector2i.ZERO))
	parent.add_child(node)
