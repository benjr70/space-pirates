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
## Ship Class it was advertised and generated as: small, medium or large.
## Empty for the hand-authored ship.
@export var ship_class: StringName = &""
## The archetype of the Hull's main Mass (wedge, hammerhead, saucer, block,
## boomtail): what the silhouette reads as, and what the name may hint at.
## Empty for the hand-authored ship.
@export var archetype: StringName = &""
## The one roll in [0, 1] that positions both Budgets inside their Class bands.
@export var richness: float = 0.0
## How far the Hatch separation rules were relaxed to place this ship's
## Hatches: 0 strict, 1 without the Flow Distance floor, 2 at half the
## Hull separation too. A fact about the ship the invariants read.
@export var hatch_relaxation: int = 0
## The generator's one-line account of its roll and repairs, for the dumper.
@export var gen_sentence: String = ""
## The stored name, bare: "Rusty Hauler" or "ISV Rusty Hauler". Never holds
## "The"; see [method display_name].
@export var ship_name: String = "Unnamed"



## What the pirate reads: "The Rusty Hauler", or the name as stored when it
## carries a registry prefix (the pool is [ShipNamer]'s data file).
func display_name() -> String:
	var first := ship_name.get_slice(" ", 0)
	if ship_name.contains(" ") and first in ShipNamer.prefixes():
		return ship_name
	return "The " + ship_name


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
