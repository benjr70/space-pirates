class_name Interiors
extends RefCounted
## Stage 8 of the generator, the shared cover-and-sightline vocabulary: every
## Room is furnished per rect, its Doors and Hatches already fixed, at the
## walk-tested density. In order: Aprons, Breakers, Lane cutters, islands,
## Containers then consoles, crew, and the Corridor's alcoves. Every piece
## is placed only if every floor tile stays reachable from every doorway.
##
## Ported from proto/cover-vocabulary at density 2.

## Tiles kept clear straight in front of a doorway, inside the Room.
const APRON_DEPTH := 2
## How far in from the doorway the Breaker stands, and how far to the side.
const BREAKER_DEPTH := 3
const BREAKER_SIDESTEP := 1
## One island of two crates per this many floor tiles of a rect.
const ISLAND_PER_TILES := 70
## Clear tiles kept around an island.
const ISLAND_GAP := 3
## Alcove crate pairs alternate sides every this many tiles along a Corridor.
const ALCOVE_STAGGER := 5
## Gold from which a Container is a full-height locker.
const LOCKER_GOLD := 3
## Consoles per Room until the Role flavour table lands (#26), which also
## brings each Role's own Container kind; until then a Container of
## [constant LOCKER_GOLD] or more is a locker.
const CONSOLES := 1

## No tile: what the crew placement returns when nothing can stand anywhere.
const UNSET := Vector2i(-99999, -99999)

## Footprints in tiles around the anchor.
const ONE: Array[Vector2i] = [Vector2i.ZERO]
const CONSOLE_X: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
const CONSOLE_Y: Array[Vector2i] = [Vector2i(0, -1), Vector2i.ZERO, Vector2i(0, 1)]
const CRYOPOD_Y: Array[Vector2i] = [Vector2i(0, -1), Vector2i.ZERO, Vector2i(0, 1)]


## The tiles a prop of this type covers around its anchor; a console turned
## a quarter turn (`rotated`) runs along y instead of x.
static func footprint(type: StringName, rotated: bool = false) -> Array[Vector2i]:
	if type == &"console" or type == &"engine_console":
		return CONSOLE_Y if rotated else CONSOLE_X
	if type == &"cryopod":
		return CRYOPOD_Y
	return ONE


## One doorway as seen from inside a Room.
class Opening:
	extends RefCounted
	## The wall tiles the doorway replaces.
	var tiles: Array[Vector2i] = []
	## Points into the Room.
	var normal := Vector2i.ZERO
	## Runs along the doorway.
	var lateral := Vector2i.ZERO
	var centre := Vector2.ZERO

	## The tiles kept clear straight in front, `depth` deep.
	func apron(depth: int) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for t in tiles:
			for d in range(1, depth + 1):
				out.append(t + normal * d)
		return out


## The furnishing of one Room in progress.
class Plan:
	extends RefCounted
	var room: RoomData
	var floor := {}
	## Tiles no prop may take: doorway Aprons.
	var apron := {}
	## Tiles a prop stands on.
	var solid := {}
	## Anchor tile of every cover piece: {tile: true}.
	var pieces := {}
	## Anchor and extra tiles of Breakers: crew never hide behind these.
	var breakers := {}
	var openings: Array[Opening] = []


## Furnish every Room of [param layout]: props and crew spawn points.
static func furnish(layout: ShipLayout, rng: RandomNumberGenerator) -> void:
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		room.props.clear()
		room.crew_spawns.clear()
		var plan := Plan.new()
		plan.room = room
		plan.floor = room.tiles()
		plan.openings = openings(layout, i)
		_rule_aprons(plan)
		if room.role == &"corridor":
			_rule_lane_cutters(plan)
			_rule_alcoves(plan)
		else:
			_rule_breakers(plan)
			_rule_lane_cutters(plan)
			_rule_islands(plan, rng)
			_rule_containers(plan)
			_rule_consoles(plan, rng, CONSOLES)
		_place_crew(plan)


## Every Door and Hatch of Room [param index] as seen from inside it.
static func openings(layout: ShipLayout, index: int) -> Array[Opening]:
	var room := layout.rooms[index]
	var out: Array[Opening] = []
	for door in layout.doors:
		if door.room_a == index or door.room_b == index:
			out.append(_opening(room, door.tiles(), door.horizontal))
	for hatch in layout.hatches:
		if hatch.room == index:
			out.append(_opening(room, hatch.tiles(), hatch.horizontal))
	return out


static func _opening(room: RoomData, tiles: Array[Vector2i], horizontal: bool) -> Opening:
	var o := Opening.new()
	o.tiles = tiles
	o.lateral = Vector2i.RIGHT if horizontal else Vector2i.DOWN
	var across := Vector2i.DOWN if horizontal else Vector2i.RIGHT
	o.normal = across if room.has_tile(tiles[0] + across) else -across
	var sum := Vector2.ZERO
	for t in tiles:
		sum += Vector2(t)
	o.centre = sum / tiles.size()
	return o


## Rule 1: Aprons. Every doorway keeps [constant APRON_DEPTH] tiles clear
## straight ahead, inside the Room.
static func _rule_aprons(plan: Plan) -> void:
	for o in plan.openings:
		for t in o.apron(APRON_DEPTH):
			if plan.floor.has(t):
				plan.apron[t] = true


## Rule 2: Breakers. Past the Apron, an L of three crates anchored
## [constant BREAKER_DEPTH] in and one to the side of the doorway's centre
## line, sides alternating per doorway. Crew never take cover behind one.
static func _rule_breakers(plan: Plan) -> void:
	var side := 1
	for o in plan.openings:
		var base := Vector2i(o.centre.round()) + o.normal * BREAKER_DEPTH
		for attempt: int in [side, -side, 2 * side, -2 * side, 3 * side, -3 * side]:
			var tile: Vector2i = base + o.lateral * (BREAKER_SIDESTEP * attempt)
			if _add(plan, &"crate", tile, ONE, false, true):
				for extra: Vector2i in [tile + o.normal, tile + o.lateral * signi(attempt)]:
					_add(plan, &"crate", extra, ONE, false, true)
				break
		side = -side


## Rule 3: Lane cutters. Two doorways of one Room facing each other with
## overlapping spans get a full-height prop on the midpoint, or a crate pair
## when a cryopod will not fit.
static func _rule_lane_cutters(plan: Plan) -> void:
	for a in plan.openings.size():
		for b in range(a + 1, plan.openings.size()):
			var oa := plan.openings[a]
			var ob := plan.openings[b]
			if oa.normal != -ob.normal:
				continue
			var lat := oa.lateral
			var lo_a := mini(_dot(oa.tiles[0], lat), _dot(oa.tiles[-1], lat))
			var hi_a := maxi(_dot(oa.tiles[0], lat), _dot(oa.tiles[-1], lat))
			var lo_b := mini(_dot(ob.tiles[0], lat), _dot(ob.tiles[-1], lat))
			var hi_b := maxi(_dot(ob.tiles[0], lat), _dot(ob.tiles[-1], lat))
			if hi_a < lo_b or hi_b < lo_a:
				continue
			var mid := Vector2i(((oa.centre + ob.centre) / 2.0).round())
			# A cryopod is full height and stands on the midpoint whichever way
			# the lane runs; a crate pair across the lane when it will not fit.
			if not _add(plan, &"cryopod", mid, CRYOPOD_Y, false, false):
				_add(plan, &"crate", mid, ONE, false, false)
				_add(plan, &"crate", mid + lat, ONE, false, false)


static func _dot(t: Vector2i, axis: Vector2i) -> int:
	return t.x * axis.x + t.y * axis.y


## Rule 4: islands. Free-standing two-crate blocks, one per
## [constant ISLAND_PER_TILES] of a rect, each [constant ISLAND_GAP] tiles
## from any other solid piece and outside every Apron.
static func _rule_islands(plan: Plan, rng: RandomNumberGenerator) -> void:
	@warning_ignore("integer_division")
	var total: int = plan.room.area() / ISLAND_PER_TILES
	var rects := plan.room.shape().duplicate()
	rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_area() > b.get_area())
	# The Room's islands shared out by rect area, the remainder on the largest.
	var quota: Array[int] = []
	var left := total
	for k in range(1, rects.size()):
		@warning_ignore("integer_division")
		var share: int = total * rects[k].get_area() / maxi(plan.room.area(), 1)
		quota.append(share)
		left -= share
	quota.insert(0, left)
	for k in rects.size():
		var rect: Rect2i = rects[k]
		var want := quota[k]
		var placed := 0
		for attempt in 60:
			if placed >= want or rect.size.x < 8 or rect.size.y < 7:
				break
			var t := Vector2i(rng.randi_range(rect.position.x + 2, rect.end.x - 4),
					rng.randi_range(rect.position.y + 2, rect.end.y - 3))
			var clear := true
			for dx in range(-ISLAND_GAP + 1, ISLAND_GAP + 1):
				for dy in range(-ISLAND_GAP + 1, ISLAND_GAP):
					if plan.solid.has(t + Vector2i(dx, dy)):
						clear = false
			if not clear:
				continue
			if _add(plan, &"crate", t, ONE, false, false):
				_add(plan, &"crate", t + Vector2i.RIGHT, ONE, false, false)
				placed += 1


## Rule 5a: Containers hug the wall farthest from the nearest doorway, so
## loot sits at the back with the fight on the way to it. A Container of
## [constant LOCKER_GOLD] or more gold is a full-height locker.
static func _rule_containers(plan: Plan) -> void:
	var ring: Array[Vector2i] = []
	for t: Vector2i in plan.floor:
		for side in TileShapes.SIDES:
			if not plan.floor.has(t + side):
				ring.append(t)
				break
	ring.sort_custom(_farthest_first(plan.openings))
	var cursor := 0
	for gold: int in plan.room.containers:
		var type: StringName = &"locker" if gold >= LOCKER_GOLD else &"container"
		while cursor < ring.size():
			var t := ring[cursor]
			cursor += 1
			if _add(plan, type, t, ONE, false, false, gold):
				cursor += 1   # a tile between Containers, so they read as pieces
				break


## Sort order for tiles: farthest from the nearest of `refs` first, then
## top-left first so equal distances stay deterministic.
static func _farthest_first(refs: Array[Opening]) -> Callable:
	return func(p: Vector2i, q: Vector2i) -> bool:
		var dp := _door_distance(p, refs)
		var dq := _door_distance(q, refs)
		return dp > dq if dp != dq else (p.y < q.y or (p.y == q.y and p.x < q.x))


static func _door_distance(t: Vector2i, openings: Array[Opening]) -> float:
	var best := INF
	for o in openings:
		best = minf(best, Vector2(t).distance_to(o.centre))
	return best if openings.size() > 0 else 0.0


## Rule 5b: consoles sit one tile off a long wall of the largest rect, never
## touching another solid piece.
static func _rule_consoles(plan: Plan, rng: RandomNumberGenerator, count: int) -> void:
	var rect := plan.room.largest_rect()
	if mini(rect.size.x, rect.size.y) < 4 or maxi(rect.size.x, rect.size.y) < 7:
		return
	# The long walls; a console along them is turned when they run along y.
	var rotated := rect.size.y > rect.size.x
	var placed := 0
	for attempt in 12:
		if placed >= count:
			return
		var tile: Vector2i
		if rotated:
			var x: int = rect.position.x + 1 if attempt % 2 == 0 else rect.end.x - 2
			tile = Vector2i(x, rng.randi_range(rect.position.y + 2, rect.end.y - 3))
		else:
			var y: int = rect.position.y + 1 if attempt % 2 == 0 else rect.end.y - 2
			tile = Vector2i(rng.randi_range(rect.position.x + 2, rect.end.x - 3), y)
		if _add(plan, &"console", tile, footprint(&"console", rotated), true, false, 0, rotated):
			placed += 1


## Corridor rule: alcove crate pairs alternate sides every
## [constant ALCOVE_STAGGER] tiles along each rect's long axis.
static func _rule_alcoves(plan: Plan) -> void:
	for rect in plan.room.shape():
		var along_y := rect.size.y >= rect.size.x
		var length := rect.size.y if along_y else rect.size.x
		var side := 0
		var k := 2
		while k < length - 2:
			var a: Vector2i
			var b: Vector2i
			if along_y:
				var x := rect.position.x if side == 0 else rect.end.x - 1
				a = Vector2i(x, rect.position.y + k)
				b = a + Vector2i.DOWN
			else:
				var y := rect.position.y if side == 0 else rect.end.y - 1
				a = Vector2i(rect.position.x + k, y)
				b = a + Vector2i.RIGHT
			if _add(plan, &"crate", a, ONE, false, false):
				_add(plan, &"crate", b, ONE, false, false)
			side = 1 - side
			k += ALCOVE_STAGGER


## Place a prop if its footprint is free floor outside every Apron (and,
## with `clearance`, touches no other solid piece) and every floor tile
## stays reachable from every doorway afterwards.
static func _add(plan: Plan, type: StringName, tile: Vector2i, shape: Array[Vector2i],
		clearance: bool, breaker: bool, gold: int = 0, rotated: bool = false) -> bool:
	var footprint := shape
	for off in footprint:
		var t := tile + off
		if not plan.floor.has(t) or plan.apron.has(t) or plan.solid.has(t):
			return false
		if clearance:
			for side in TileShapes.SIDES:
				if plan.solid.has(t + side):
					return false
	for off in footprint:
		plan.solid[tile + off] = true
	# A one-tile piece whose free neighbours run round it in one unbroken arc
	# can pocket nothing; anything else is checked by flood fill.
	if not _single_arc(plan, tile, footprint) and not _all_reachable(plan):
		for off in footprint:
			plan.solid.erase(tile + off)
		return false
	plan.pieces[tile] = true
	var prop := {type = type, tile = tile}
	if rotated:
		prop.rotated = true
	if gold > 0:
		prop.gold = gold
	if breaker:
		prop.breaker = true
		for off in footprint:
			plan.breakers[tile + off] = true
	plan.room.props.append(prop)
	return true


## The eight neighbours of a tile in ring order.
const RING: Array[Vector2i] = [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
		Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0)]


## Whether a one-tile footprint's free neighbours form a single unbroken arc
## around it, so placing it cannot cut the floor in two or pocket a tile.
## Larger footprints always answer false and are flood-checked.
static func _single_arc(plan: Plan, tile: Vector2i, footprint: Array[Vector2i]) -> bool:
	if footprint.size() != 1:
		return false
	var free: Array[bool] = []
	for off in RING:
		var n := tile + off
		free.append(plan.floor.has(n) and not plan.solid.has(n))
	var runs := 0
	for k in RING.size():
		if free[k] and not free[(k + RING.size() - 1) % RING.size()]:
			runs += 1
	return runs <= 1


## Whether every prop-free floor tile is reachable from every doorway.
static func _all_reachable(plan: Plan) -> bool:
	var starts: Array[Vector2i] = []
	for o in plan.openings:
		var t := o.tiles[0] + o.normal
		if plan.floor.has(t) and not plan.solid.has(t):
			starts.append(t)
	if starts.is_empty():
		return true
	var seen := {starts[0]: true}
	var stack: Array[Vector2i] = [starts[0]]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for side in TileShapes.SIDES:
			var n := c + side
			if plan.floor.has(n) and not plan.solid.has(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	for s in starts:
		if not seen.has(s):
			return false
	return seen.size() == plan.floor.size() - plan.solid.size()


## Rule 6: crew stand behind cover, deepest piece from the nearest doorway
## first, on its far side; Breakers excluded; when cover runs out, the far
## corner, never an Apron. A multi-rect Room's crew split across its rects by
## area, the remainder on the largest; in a rect with no doorway of its own
## they stand on the side of the cover away from the rect's centre.
static func _place_crew(plan: Plan) -> void:
	var room := plan.room
	if room.crew_count <= 0:
		return
	var rects := room.shape().duplicate()
	rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_area() > b.get_area())
	var total := room.area()
	var quota: Array[int] = []
	var left := room.crew_count
	for k in range(1, rects.size()):
		@warning_ignore("integer_division")
		var share: int = room.crew_count * rects[k].get_area() / total
		quota.append(share)
		left -= share
	quota.insert(0, left)
	var used := {}
	var taken := {}
	for k in rects.size():
		var rect: Rect2i = rects[k]
		var local: Array[Opening] = []
		for o in plan.openings:
			if rect.has_point(o.tiles[0] + o.normal):
				local.append(o)
		var cover: Array[Vector2i] = []
		for t: Vector2i in plan.pieces:
			if rect.has_point(t) and not plan.breakers.has(t):
				cover.append(t)
		var refs := local if not local.is_empty() else plan.openings
		cover.sort_custom(_farthest_first(refs))
		for n in quota[k]:
			var spot := UNSET
			for c in cover:
				if used.has(c):
					continue
				var step: Vector2i
				if not local.is_empty():
					step = _nearest(c, local).normal
				else:
					var centre := Vector2(rect.get_center())
					var dir := (Vector2(c) + Vector2(0.5, 0.5) - centre)
					step = Vector2i(signf(dir.x), 0) if absf(dir.x) >= absf(dir.y) else Vector2i(0, signf(dir.y))
				# Past the piece's own tiles (a console is three long) to its far side.
				var away := c + step
				var walked := 1
				while plan.solid.has(away) and walked < 3:
					away += step
					walked += 1
				if _standable(plan, away, taken):
					spot = away
					used[c] = true
					break
			if spot == UNSET:
				spot = _far_corner(plan, rect, refs, taken)
			if spot == UNSET:
				continue
			taken[spot] = true
			room.crew_spawns.append(spot)


static func _nearest(t: Vector2i, openings: Array[Opening]) -> Opening:
	var best: Opening = openings[0]
	var best_d := INF
	for o in openings:
		var d := Vector2(t).distance_to(o.centre)
		if d < best_d:
			best_d = d
			best = o
	return best


## Free floor outside every Apron, not already taken, and not beside a
## Breaker: a body there would be using the pirate's cover.
static func _standable(plan: Plan, t: Vector2i, taken: Dictionary) -> bool:
	if not plan.floor.has(t) or plan.solid.has(t) or plan.apron.has(t) or taken.has(t):
		return false
	for side in TileShapes.SIDES:
		if plan.breakers.has(t + side):
			return false
	return true


## The free tile of a rect farthest from the doorways, or an unset tile.
static func _far_corner(plan: Plan, rect: Rect2i, refs: Array[Opening], taken: Dictionary) -> Vector2i:
	var best := UNSET
	var best_d := -1.0
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var t := Vector2i(x, y)
			if not _standable(plan, t, taken):
				continue
			var d := _door_distance(t, refs)
			if d > best_d:
				best_d = d
				best = t
	return best
