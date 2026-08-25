class_name ShipLayout
extends Resource
## A whole ship as data. Hand-authored today, generated from a seed later --
## [ShipBuilder] does not care which, it only ever reads this.

@export var rooms: Array[RoomData] = []
@export var doors: Array[DoorData] = []
## Index of the room the pirate boards through.
@export var entry_room: int = 0
## Seed this ship was generated from; 0 means hand-authored.
@export var gen_seed: int = 0
## Display name, e.g. "Rusty Hauler".
@export var ship_name: String = "Unnamed"


## Every tile occupied by walkable floor, including door gaps.
func floor_tiles() -> Dictionary:
	var tiles := {}
	for room in rooms:
		for x in range(room.rect.position.x, room.rect.end.x):
			for y in range(room.rect.position.y, room.rect.end.y):
				tiles[Vector2i(x, y)] = true
	for door in doors:
		tiles[door.tile] = true
	return tiles


## Which room contains a tile, or -1. Linear scan -- ships have tens of rooms.
func room_at(tile: Vector2i) -> int:
	for i in rooms.size():
		if rooms[i].rect.has_point(tile):
			return i
	return -1
