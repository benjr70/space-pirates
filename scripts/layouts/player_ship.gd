class_name PlayerShipLayout
extends RefCounted
## The pirate's own ship, hand-authored -- the same four-compartment hull that
## used to live in scenes/ship.tscn, now described as data.
##
## Rooms sit one tile apart so the gap between them becomes their shared wall,
## which is where doors get punched.


static func create() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.ship_name = "The Pirate"
	layout.rooms = [
		_room(Rect2i(0, 0, 7, 4), &"bridge", [
			{"type": &"console", "tile": Vector2i(3, 0)},
		]),
		_room(Rect2i(0, 5, 3, 5), &"medbay", [
			{"type": &"cryopod", "tile": Vector2i(1, 7)},
		]),
		_room(Rect2i(4, 5, 3, 5), &"quarters", [
			{"type": &"crate", "tile": Vector2i(5, 7)},
		]),
		_room(Rect2i(0, 11, 7, 5), &"cargo", [
			{"type": &"crate", "tile": Vector2i(1, 12)},
			{"type": &"crate", "tile": Vector2i(2, 14)},
			{"type": &"crate", "tile": Vector2i(5, 13)},
		]),
		_room(Rect2i(0, 17, 7, 4), &"engine", [
			{"type": &"engine_console", "tile": Vector2i(3, 18)},
		]),
	]
	layout.doors = [
		_door(0, 1, Vector2i(1, 4), true),
		_door(0, 2, Vector2i(5, 4), true),
		_door(1, 2, Vector2i(3, 7), false),
		_door(1, 3, Vector2i(1, 10), true),
		_door(2, 3, Vector2i(5, 10), true),
		_door(3, 4, Vector2i(3, 16), true),
	]
	layout.entry_room = 3
	return layout


static func _room(rect: Rect2i, role: StringName, props: Array) -> RoomData:
	var room := RoomData.new()
	room.rect = rect
	room.role = role
	room.props.assign(props)
	return room


static func _door(a: int, b: int, tile: Vector2i, horizontal: bool) -> DoorData:
	var door := DoorData.new()
	door.room_a = a
	door.room_b = b
	door.tile = tile
	door.horizontal = horizontal
	return door
