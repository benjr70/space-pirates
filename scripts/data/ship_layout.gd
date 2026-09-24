class_name ShipLayout
extends Resource
## A whole ship as data. Hand-authored today, generated from a seed later --
## [ShipBuilder] does not care which, it only ever reads this.
##
## Where the pirate boards is not a fact about the ship: every ship offers at
## least two Hatches and a Raid picks one of them at its start.

@export var rooms: Array[RoomData] = []
@export var doors: Array[DoorData] = []
## Gaps through the Hull. At least two on every ship, one of them into a
## cargo Room, none on the bridge or engine.
@export var hatches: Array[HatchData] = []
## Seed this ship was generated from; 0 means hand-authored.
@export var gen_seed: int = 0
## Display name, e.g. "Rusty Hauler".
@export var ship_name: String = "Unnamed"


## Every tile occupied by walkable floor, including door and hatch gaps.
func floor_tiles() -> Dictionary:
	var tiles := {}
	for room in rooms:
		tiles.merge(room.tiles())
	for door in doors:
		for tile in door.tiles():
			tiles[tile] = true
	for hatch in hatches:
		for tile in hatch.tiles():
			tiles[tile] = true
	return tiles


## Which room contains a tile, or -1. Linear scan -- ships have tens of rooms.
func room_at(tile: Vector2i) -> int:
	for i in rooms.size():
		if rooms[i].has_tile(tile):
			return i
	return -1
