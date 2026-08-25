class_name PlayerShipLayout
extends RefCounted
## The pirate's own ship, hand-authored -- the same five compartments as before,
## sized so a boarding fight has room to happen: every room holds a dozen-odd
## combatants with space to circle, and doorways are wide enough that a fight
## spills through them instead of queuing single file.
##
## Rooms sit one tile apart so the gap between them becomes their shared wall,
## which is where doorways get punched.
##
## The crew counts are here so there is something to fight while the raid loop
## is still being built -- the pirate's own ship is standing in for a target.


static func create() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.ship_name = "The Pirate"
	layout.rooms = [
		_room(Rect2i(0, 0, 21, 8), &"bridge", 2, [
			{"type": &"console", "tile": Vector2i(10, 1)},
			{"type": &"console", "tile": Vector2i(4, 1)},
			{"type": &"console", "tile": Vector2i(16, 1)},
		]),
		_room(Rect2i(0, 9, 10, 10), &"medbay", 1, [
			{"type": &"cryopod", "tile": Vector2i(1, 12)},
			{"type": &"cryopod", "tile": Vector2i(8, 12)},
			{"type": &"console", "tile": Vector2i(4, 17)},
		]),
		_room(Rect2i(11, 9, 10, 10), &"quarters", 2, [
			{"type": &"cryopod", "tile": Vector2i(19, 12)},
			{"type": &"crate", "tile": Vector2i(12, 17)},
			{"type": &"crate", "tile": Vector2i(13, 17)},
		]),
		_room(Rect2i(0, 20, 21, 12), &"cargo", 0, [
			{"type": &"crate", "tile": Vector2i(1, 21)},
			{"type": &"crate", "tile": Vector2i(2, 21)},
			{"type": &"crate", "tile": Vector2i(1, 22)},
			{"type": &"crate", "tile": Vector2i(19, 21)},
			{"type": &"crate", "tile": Vector2i(19, 22)},
			{"type": &"crate", "tile": Vector2i(2, 30)},
			{"type": &"crate", "tile": Vector2i(3, 30)},
			{"type": &"crate", "tile": Vector2i(18, 30)},
		]),
		_room(Rect2i(0, 33, 21, 8), &"engine", 2, [
			{"type": &"engine_console", "tile": Vector2i(5, 34)},
			{"type": &"engine_console", "tile": Vector2i(15, 34)},
			{"type": &"crate", "tile": Vector2i(10, 39)},
		]),
	]
	layout.doors = [
		_door(0, 1, Vector2i(3, 8), true, 3),
		_door(0, 2, Vector2i(15, 8), true, 3),
		_door(1, 2, Vector2i(10, 13), false, 3, true),
		_door(1, 3, Vector2i(3, 19), true, 3),
		_door(2, 3, Vector2i(15, 19), true, 3),
		_door(3, 4, Vector2i(9, 32), true, 4),
	]
	layout.entry_room = 3
	return layout


static func _room(rect: Rect2i, role: StringName, crew: int, props: Array) -> RoomData:
	var room := RoomData.new()
	room.rect = rect
	room.role = role
	room.crew_count = crew
	room.props.assign(props)
	return room


static func _door(a: int, b: int, tile: Vector2i, horizontal: bool, width: int, locked := false) -> DoorData:
	var door := DoorData.new()
	door.room_a = a
	door.room_b = b
	door.tile = tile
	door.horizontal = horizontal
	door.width = width
	door.locked = locked
	return door
