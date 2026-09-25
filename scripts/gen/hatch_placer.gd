class_name HatchPlacer
extends RefCounted
## Stage 5 of the generator: Hatch placement on the Role-less partition,
## using only the packer's Bridge, Engine and Corridor tags. Two to four
## Hatches by Class, each a two-wide gap in the Hull opening into one Room,
## well separated along the Hull and at least two Rooms apart inside.

## Hatch count band per Class.
const HATCH_BAND := {&"small": Vector2i(2, 2), &"medium": Vector2i(2, 3), &"large": Vector2i(3, 4)}
## Fewest Doors between any two Hatch Rooms.
const FLOW_FLOOR := 2
## Random draws per relaxation level before the next one is tried.
const TRIES := 40


class Result:
	extends RefCounted
	var hatches: Array[HatchData] = []
	## The relaxation level reached: 0 strict, 1 without the Flow Distance
	## floor, 2 with half the Hull separation as well; -1 when even that
	## placed nothing and the ship must be rerolled.
	var relaxed := 0


## Least Hull distance between any two of [param count] Hatches on a Hull of
## [param hull_size] tiles, at a relaxation level.
static func separation(hull_size: int, count: int, relaxed: int) -> float:
	var out := float(hull_size) / (2.0 * count)
	return out / 2.0 if relaxed >= 2 else out


## Place Hatches on [param layout]. [param pinned] Rooms keep a packer tag
## through Role assignment and so cannot serve its Armories or Cargo. A
## result with `relaxed` of -1 holds no Hatches: the ship must be rerolled.
static func place(layout: ShipLayout, ship_class: StringName, rng: RandomNumberGenerator,
		pinned: int = 0) -> Result:
	var result := Result.new()
	var band: Vector2i = HATCH_BAND[ship_class]
	var count := rng.randi_range(band.x, band.y)
	# Role assignment needs Rooms clear of any Hatch for its Armories and
	# all but one Cargo; the count leaves it that many.
	var ranges: Dictionary = RoleAssigner.RANGES[ship_class]
	var pool := 0
	for room in layout.rooms:
		if not ShipGraph.is_fixed_role(room.role):
			pool += 1
	count = clampi(pool - pinned - (ranges[&"cargo"].x - 1) - ranges[&"armory"].x, band.x, count)
	var hull := ShipGraph.hull_tiles(layout)
	var floors := ShipGraph.floor_without_hatches(layout)
	var wall_set := ShipGraph.walls(layout, floors)
	var out_set := ShipGraph.outside(floors, wall_set)
	var adjacency := ShipGraph.adjacency(layout)

	# Candidate gaps per eligible Room.
	var rooms: Array[int] = []
	var spots := {}
	for i in layout.rooms.size():
		if ShipGraph.is_fixed_role(layout.rooms[i].role):
			continue
		var found := _candidates(layout, i, hull, out_set)
		if not found.is_empty():
			rooms.append(i)
			spots[i] = found
	if rooms.size() < count:
		count = rooms.size()
	if count < band.x:
		result.relaxed = -1
		return result

	for level in 3:
		var apart := separation(hull.size(), count, level)
		for attempt in TRIES:
			var picked := _try_pick(layout, rng, rooms, spots, count, hull, apart, level >= 1, adjacency)
			if picked.size() == count:
				result.hatches = picked
				result.relaxed = level
				return result
	result.relaxed = -1
	return result


## One draw: Rooms in random order; the first Hatch lands on a random gap,
## each later one on the gap of its Room farthest along the Hull from those
## already picked, kept when that clears the separation and the Room is far
## enough inside.
static func _try_pick(layout: ShipLayout, rng: RandomNumberGenerator, rooms: Array[int], spots: Dictionary,
		count: int, hull: Dictionary, separation: float, skip_flow: bool, adjacency: Dictionary) -> Array[HatchData]:
	var order := rooms.duplicate()
	_shuffle(order, rng)
	var picked: Array[HatchData] = []
	# One Hull distance map per picked Hatch; candidates are looked up in them.
	var reach: Array[Dictionary] = []
	for room: int in order:
		if not skip_flow:
			var near := false
			for other in picked:
				var dist := ShipGraph.distances(layout, [other.room], adjacency)
				if dist[room] >= 0 and dist[room] < FLOW_FLOOR:
					near = true
					break
			if near:
				continue
		var options: Array = spots[room]
		var hatch: HatchData = null
		if picked.is_empty():
			hatch = options[rng.randi_range(0, options.size() - 1)]
		else:
			var best := -1
			for option: HatchData in options:
				var nearest := 1 << 30
				for map in reach:
					nearest = mini(nearest, map.get(option.tile, -1))
				if nearest > best:
					best = nearest
					hatch = option
			if best < separation:
				continue
		picked.append(hatch)
		reach.append(ShipGraph.hull_distances(hull, hatch.tile))
		if picked.size() == count:
			break
	return picked


## Every two-wide run of Hull wall beside [param room]'s floor with outside
## beyond it, as ready HatchData.
static func _candidates(layout: ShipLayout, room: int, hull: Dictionary, out_set: Dictionary) -> Array:
	var data := layout.rooms[room]
	var found: Array = []
	var seen := {}
	for t: Vector2i in data.tiles():
		for step in TileShapes.SIDES:
			var w := t + step
			if not hull.has(w) or not out_set.has(w + step):
				continue
			var horizontal := step.y != 0
			var along := Vector2i.RIGHT if horizontal else Vector2i.DOWN
			for start: Vector2i in [w, w - along]:
				var w2 := start + along
				if not hull.has(start) or not hull.has(w2):
					continue
				if not (data.has_tile(start - step) and data.has_tile(w2 - step)):
					continue
				if not (out_set.has(start + step) and out_set.has(w2 + step)):
					continue
				var key := "%s/%s" % [start, horizontal]
				if seen.has(key):
					continue
				seen[key] = true
				var hatch := HatchData.new()
				hatch.room = room
				hatch.tile = start
				hatch.horizontal = horizontal
				hatch.width = 2
				found.append(hatch)
	return found


## Fisher-Yates on the generator's own RNG, so the draw is seeded.
static func _shuffle(list: Array, rng: RandomNumberGenerator) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp
