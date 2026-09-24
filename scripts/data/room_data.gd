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

## The floor: at least one rect, pairwise non-overlapping and abutting so the
## union is one open space.
@export var rects: Array[Rect2i] = [Rect2i(0, 0, 4, 4)]
## What the room is for: &"bridge", &"engine", &"cargo", &"medbay", &"quarters".
@export var role: StringName = &"quarters"
## How many hostile crew start in this room. The generator will set this from
## a threat budget later.
@export var crew_count: int = 0
## Props to spawn, as [{type = StringName, tile = Vector2i}]. `tile` is the tile
## the prop is centred on, so odd-sized props line up with the grid.
@export var props: Array[Dictionary] = []


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
