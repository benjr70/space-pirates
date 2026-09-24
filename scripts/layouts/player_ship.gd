class_name PlayerShipLayout
extends RefCounted
## The pirate's own ship, hand-authored -- the same five compartments as before,
## sized to the fightable floor every ship must meet: each Room holds a clear
## 10x10 Fight Core and at least 140 tiles, and doorways are wide enough that
## a fight spills through them instead of queuing single file.
##
## Rooms sit one tile apart so the gap between them becomes their shared wall,
## which is where doorways get punched. Two hatches open the hull: one on the
## starboard side of the cargo hold, the boarding point a raid defaults to, and
## one on the port side of the medbay, so there is a second way off the ship.
##
## The crew counts are here so there is something to fight while the raid loop
## is still being built -- the pirate's own ship is standing in for a target.


static func create() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.ship_name = "Pirate"
	layout.rooms = [
		_room(Rect2i(0, 0, 21, 10), &"bridge", 2, [
			{"type": &"console", "tile": Vector2i(10, 1)},
			{"type": &"console", "tile": Vector2i(4, 1)},
			{"type": &"console", "tile": Vector2i(16, 1)},
		]),
		_room(Rect2i(0, 11, 10, 14), &"medbay", 1, [
			{"type": &"cryopod", "tile": Vector2i(1, 14)},
			{"type": &"cryopod", "tile": Vector2i(8, 14)},
			{"type": &"console", "tile": Vector2i(4, 23)},
		]),
		_room(Rect2i(11, 11, 10, 14), &"quarters", 2, [
			{"type": &"cryopod", "tile": Vector2i(19, 14)},
			{"type": &"crate", "tile": Vector2i(12, 23)},
			{"type": &"crate", "tile": Vector2i(13, 23)},
		]),
		_room(Rect2i(0, 26, 21, 12), &"cargo", 0, [
			{"type": &"crate", "tile": Vector2i(1, 27)},
			{"type": &"crate", "tile": Vector2i(2, 27)},
			{"type": &"crate", "tile": Vector2i(1, 28)},
			{"type": &"crate", "tile": Vector2i(19, 27)},
			{"type": &"crate", "tile": Vector2i(19, 28)},
			{"type": &"crate", "tile": Vector2i(2, 36)},
			{"type": &"crate", "tile": Vector2i(3, 36)},
			{"type": &"crate", "tile": Vector2i(18, 36)},
		]),
		_room(Rect2i(0, 39, 21, 10), &"engine", 2, [
			{"type": &"engine_console", "tile": Vector2i(5, 40)},
			{"type": &"engine_console", "tile": Vector2i(15, 40)},
			{"type": &"crate", "tile": Vector2i(10, 45)},
		]),
	]
	layout.doors = [
		_door(0, 1, Vector2i(3, 10), true, 3),
		_door(0, 2, Vector2i(15, 10), true, 3),
		_door(1, 2, Vector2i(10, 15), false, 3, true),
		_door(1, 3, Vector2i(3, 25), true, 3),
		_door(2, 3, Vector2i(15, 25), true, 3),
		_door(3, 4, Vector2i(9, 38), true, 4),
	]
	layout.hatches = [
		_hatch(3, Vector2i(21, 33)),
		_hatch(1, Vector2i(-1, 17)),
	]
	return layout


static func _room(rect: Rect2i, role: StringName, crew: int, props: Array) -> RoomData:
	var room := RoomData.new()
	room.rects = [rect]
	room.role = role
	room.crew_count = crew
	room.props.assign(props)
	return room


## A hatch through a side wall: two tiles tall, running along Y.
static func _hatch(room: int, tile: Vector2i) -> HatchData:
	var hatch := HatchData.new()
	hatch.room = room
	hatch.tile = tile
	hatch.horizontal = false
	hatch.width = 2
	return hatch


static func _door(a: int, b: int, tile: Vector2i, horizontal: bool, width: int, locked := false) -> DoorData:
	var door := DoorData.new()
	door.room_a = a
	door.room_b = b
	door.tile = tile
	door.horizontal = horizontal
	door.width = width
	door.locked = locked
	return door
