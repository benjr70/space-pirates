class_name RoomData
extends Resource
## One Room, described in TILE coordinates.
##
## A Room's floor is a union of abutting rects: the walkable floor only -- the
## surrounding wall ring is implied and painted by [ShipBuilder]. Two Rooms that
## should share a wall are placed with exactly one tile of gap between them;
## that gap tile becomes the shared wall.
##
## Hand-authored Rooms usually list one rect; generated Rooms list their
## maximal-rect decomposition. Read the shape through [method shape] and the
## helpers below.

## The clear axis-aligned rectangle every non-corridor Room must contain
## somewhere for a first-person firefight to work. Walk-tested, not derived.
const FIGHT_CORE := Vector2i(10, 10)
## Fewest floor tiles a non-corridor Room may have; 10x14 is the walk-tested
## minimum and this is its area.
const MIN_AREA := 140
## Most floor tiles any Room may have before it reads as a warehouse.
const MAX_AREA := 260
## Corridors skip the Fight Core and must be this wide along their length.
const CORRIDOR_WIDTH := 3

## The floor: at least one rect, pairwise non-overlapping and abutting so the
## union is one open space.
@export var rects: Array[Rect2i] = [Rect2i(0, 0, 4, 4)]
## What the room is for: &"bridge", &"engine", &"cargo", &"medbay", &"quarters",
## &"shield", &"armory", or &"corridor" for a Skeleton's walkway.
@export var role: StringName = &"quarters"
## How many hostile crew start in this Room: its Threat Share of the ship's
## Threat Budget. Hand-authored ships set it directly.
@export var crew_count: int = 0
## This Room's Loot Share of the ship's Loot Budget, in gold units.
@export var loot_share: int = 0
## The Containers the Loot Share becomes, as the gold each holds, largest
## first. Interior generation places them as props; Corridors hold none.
@export var containers: Array[int] = []
## Props to spawn, as [{type = StringName, tile = Vector2i}]. `tile` is the tile
## the prop is centred on, so odd-sized props line up with the grid. A
## Container prop also carries `gold`, whatever its kind; a Breaker crate
## carries `breaker = true` and crew never take cover behind it; a prop
## turned a quarter turn carries `rotated = true`. Kinds named only in the
## Role flavour table (safe, generator, cabinet, footlocker) are built as
## the placeholder [RoleFlavour] maps them to.
@export var props: Array[Dictionary] = []
## Where each hostile crew member starts, one tile per body, chosen by
## interior generation behind cover. Empty means spread them across the floor.
@export var crew_spawns: Array[Vector2i] = []
## Which way each body in [member crew_spawns] faces at its spawn, one entry
## per spawn: a unit tile step, or zero for no preference. Crew at a station
## face into the Room; crew behind cover face the doorway.
@export var crew_facings: Array[Vector2i] = []


## The rects making up the floor.
func shape() -> Array[Rect2i]:
	return rects


## The largest rect, first on ties: the open part of the Room, where anything
## that wants a guaranteed standing spot (lights, spawns, the pirate) goes.
## Not the Fight Core, which is a size requirement rather than a place.
func largest_rect() -> Rect2i:
	var best: Rect2i = rects[0]
	for r in rects:
		if r.size.x * r.size.y > best.size.x * best.size.y:
			best = r
	return best


## Bounding box of the whole floor.
func bounds() -> Rect2i:
	var parts := shape()
	var box: Rect2i = parts[0]
	for i in range(1, parts.size()):
		box = box.merge(parts[i])
	return box


## Floor tiles in total, summed over the rects (they never overlap).
func area() -> int:
	var total := 0
	for r in shape():
		total += r.size.x * r.size.y
	return total


## Every floor tile as a set: {Vector2i: true}.
func tiles() -> Dictionary:
	var out := {}
	for r in shape():
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				out[Vector2i(x, y)] = true
	return out


## Whether `tile` is walkable floor of this Room.
func has_tile(tile: Vector2i) -> bool:
	for r in shape():
		if r.has_point(tile):
			return true
	return false


## Centre of the Room's [method largest_rect]: always over floor, unlike the
## centre of an L-shaped Room's bounding box.
func center_tile() -> Vector2:
	var core := largest_rect()
	return Vector2(core.position) + Vector2(core.size) / 2.0


## The one fightable floor every Room must meet: a corridor is
## [constant CORRIDOR_WIDTH] wide along its whole length; anything else holds
## a [constant FIGHT_CORE] and [constant MIN_AREA] to [constant MAX_AREA]
## tiles. A corridor is a walkway, not a warehouse, so a ring or a long spine
## may run past the ceiling.
func meets_floor() -> bool:
	if role == &"corridor":
		return has_clear_width(CORRIDOR_WIDTH)
	return area() >= MIN_AREA and area() <= MAX_AREA and has_fight_core()


## Whether every floor tile sits inside some clear `width`-square block of
## floor: the shape is at least `width` wide everywhere, stubs included. A
## square block is deliberately stricter than "wide": a run shorter than
## `width` along its own length fails too, so no corridor ends in a notch.
func has_clear_width(width: int) -> bool:
	var floor_set := tiles()
	var core := Vector2i(width, width)
	for tile: Vector2i in floor_set:
		var covered := false
		for dx in range(width):
			for dy in range(width):
				if _fits_at(tile - Vector2i(dx, dy), core, floor_set):
					covered = true
					break
			if covered:
				break
		if not covered:
			return false
	return true


## Whether a clear `core`-sized rectangle fits somewhere inside the floor
## union -- it may straddle the seam between rects. Props are not considered;
## this is the shape invariant only.
func has_fight_core(core: Vector2i = FIGHT_CORE) -> bool:
	var floor_set := tiles()
	var box := bounds()
	for origin in floor_set:
		if origin.x + core.x > box.end.x or origin.y + core.y > box.end.y:
			continue
		if _fits_at(origin, core, floor_set):
			return true
	return false


## Whether every tile of a `core`-sized block at `origin` is in `floor_set`.
func _fits_at(origin: Vector2i, core: Vector2i, floor_set: Dictionary) -> bool:
	for dx in range(core.x):
		for dy in range(core.y):
			if not floor_set.has(origin + Vector2i(dx, dy)):
				return false
	return true
