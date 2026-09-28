class_name Interiors
extends RefCounted
## Stage 8 of the generator: the shared cover-and-sightline vocabulary, then
## each Role's flavour row from [RoleFlavour]. Every Room is furnished per
## rect, its Doors and Hatches already fixed, at the walk-tested density. In
## order: Aprons, Breakers, Lane cutters, the Role's signature furniture
## (a Bridge's console bank, an Engine's consoles, a Shield's generator, a
## Medbay's cryopod row, Quarters' bunks), islands of the Role's kind,
## Containers of the Role's kind, the Role's remaining consoles, crew in the
## Role's posture, and the Corridor's alcoves. Every piece is placed only if
## every floor tile stays reachable from every doorway; signature furniture
## yields to whatever the doorway rules placed.
##
## Ported from proto/cover-vocabulary at density 2; flavour from
## proto/large-walk.

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
## Gold from which a Container is a full-height locker, for a Role whose
## row names no Container kind.
const LOCKER_GOLD := 3
## Consoles on a signature wall stand this far apart, anchor to anchor:
## three tiles of console and one of gap.
const BANK_PITCH := 4
## Cryopods in a row stand this far apart along their wall.
const ROW_PITCH := 4
## Bunk pairs stand this far apart along their wall.
const BUNK_PITCH := 5
## How far from the Room's centre a generator may be pushed to fit.
const CENTRE_REACH := 5
## Most bunk pairs in Quarters, cryopods in a Medbay row.
const MAX_BUNKS := 3
const MAX_ROW := 4

## No tile: what the crew placement returns when nothing can stand anywhere.
const UNSET := Vector2i(-99999, -99999)

## Footprints in tiles around the anchor.
const ONE: Array[Vector2i] = [Vector2i.ZERO]
const CONSOLE_X: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
const CONSOLE_Y: Array[Vector2i] = [Vector2i(0, -1), Vector2i.ZERO, Vector2i(0, 1)]
const CRYOPOD_Y: Array[Vector2i] = [Vector2i(0, -1), Vector2i.ZERO, Vector2i(0, 1)]
const CRYOPOD_X: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]


## The tiles a prop of this type covers around its anchor; a console or a
## cryopod turned a quarter turn (`rotated`) runs along the other axis. A
## kind named only in the flavour table covers what its placeholder covers.
static func footprint(type: StringName, rotated: bool = false) -> Array[Vector2i]:
	var built := RoleFlavour.placeholder(type)
	if built == &"console" or built == &"engine_console":
		return CONSOLE_Y if rotated else CONSOLE_X
	if built == &"cryopod":
		return CRYOPOD_X if rotated else CRYOPOD_Y
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
	## The Role's row of the flavour table.
	var row := {}
	## Floor kept free of props for crew at their stations: {tile: true}.
	var reserved := {}
	## Where crew at their stations stand and face, in order:
	## [{tile: Vector2i, facing: Vector2i}].
	var stations: Array[Dictionary] = []
	## Tiles at the ends of bunks, where Quarters' footlockers go first.
	var bunk_ends: Array[Vector2i] = []


## Furnish every Room of [param layout]: props and crew spawn points.
static func furnish(layout: ShipLayout, rng: RandomNumberGenerator) -> void:
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		room.props.clear()
		room.crew_spawns.clear()
		room.crew_facings.clear()
		var plan := Plan.new()
		plan.room = room
		plan.floor = room.tiles()
		plan.openings = openings(layout, i)
		plan.row = RoleFlavour.row(room.role)
		_rule_aprons(plan)
		if room.role == &"corridor":
			_rule_lane_cutters(plan)
			_rule_alcoves(plan)
		else:
			_rule_breakers(plan)
			_rule_lane_cutters(plan)
			var consoles := RoleFlavour.console_count(room.role, rng)
			var on_wall: bool = plan.row.wall in ["fore", "aft"]
			if on_wall:
				_rule_console_bank(plan, rng, consoles)
			_rule_signature(plan, rng)
			_rule_islands(plan, rng)
			_rule_containers(plan, rng)
			if not on_wall:
				_rule_consoles(plan, rng, consoles)
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


## Rule 4: islands. Free-standing blocks of the Role's kind (two crates by
## default; Cargo doubles the count, an Engine stands engine console stubs,
## a Medbay cryopods, Quarters cryopod pairs), one per
## [constant ISLAND_PER_TILES] of a rect, each [constant ISLAND_GAP] tiles
## from any other solid piece and outside every Apron.
static func _rule_islands(plan: Plan, rng: RandomNumberGenerator) -> void:
	var kind: String = plan.row.islands
	if kind == "none":
		return
	@warning_ignore("integer_division")
	var total: int = plan.room.area() / ISLAND_PER_TILES
	if kind == "crates_doubled":
		total *= 2
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
			if _add_island(plan, kind, t):
				placed += 1


## One island of the Role's kind at [param t]; true when its first piece stood.
static func _add_island(plan: Plan, kind: String, t: Vector2i) -> bool:
	match kind:
		"engine_stubs":
			return _add(plan, &"engine_console", t, CONSOLE_X, false, false)
		"cryopods":
			return _add(plan, &"cryopod", t, CRYOPOD_Y, false, false)
		"cryopod_pairs":
			if not _add(plan, &"cryopod", t, CRYOPOD_Y, false, false):
				return false
			_add(plan, &"cryopod", t + Vector2i.RIGHT, CRYOPOD_Y, false, false)
			return true
		_:
			if not _add(plan, &"crate", t, ONE, false, false):
				return false
			_add(plan, &"crate", t + Vector2i.RIGHT, ONE, false, false)
			return true


## Rule 5a: Containers, of the Role's kind, hug the wall farthest from the
## nearest doorway, so loot sits at the back with the fight on the way to
## it. Where the row names no kind, a Container of [constant LOCKER_GOLD]
## or more gold is a full-height locker. Cargo's crates stand in wall runs
## of the row's length; Quarters' footlockers take bunk ends first; a
## Medbay's cabinets are console-sized and lie along the wall.
static func _rule_containers(plan: Plan, rng: RandomNumberGenerator) -> void:
	var ring: Array[Vector2i] = []
	for t: Vector2i in plan.floor:
		for side in TileShapes.SIDES:
			if not plan.floor.has(t + side):
				ring.append(t)
				break
	ring.sort_custom(_farthest_first(plan.openings))
	var kind := StringName(plan.row.container)
	if plan.row.signature == "crate_runs":
		_containers_in_runs(plan, rng, kind, ring)
		return
	var cursor := 0
	for gold: int in plan.room.containers:
		var type := kind
		if kind == &"none":
			type = &"locker" if gold >= LOCKER_GOLD else &"container"
		var placed := false
		while not plan.bunk_ends.is_empty() and not placed:
			placed = _add(plan, type, plan.bunk_ends.pop_front(), footprint(type), false, false, gold)
		while cursor < ring.size() and not placed:
			var t := ring[cursor]
			cursor += 1
			if _add_container(plan, type, t, gold):
				cursor += 1   # a tile between Containers, so they read as pieces
				placed = true
		if not placed:
			_add_anywhere(plan, type, gold)


## The back wall is full: a Container anywhere on the floor, farthest from
## the doorways first.
static func _add_anywhere(plan: Plan, type: StringName, gold: int) -> void:
	var everywhere: Array[Vector2i] = []
	everywhere.assign(plan.floor.keys())
	everywhere.sort_custom(_farthest_first(plan.openings))
	for t in everywhere:
		if _add_container(plan, type, t, gold):
			return


## A Container at [param t], turned to lie along whichever wall it touches
## when its kind is console-sized.
static func _add_container(plan: Plan, type: StringName, t: Vector2i, gold: int) -> bool:
	var shape := footprint(type)
	if shape.size() == 1:
		return _add(plan, type, t, shape, false, false, gold)
	var along_x := not plan.floor.has(t + Vector2i.UP) or not plan.floor.has(t + Vector2i.DOWN)
	if _add(plan, type, t, footprint(type, not along_x), false, false, gold, not along_x):
		return true
	return _add(plan, type, t, footprint(type, along_x), false, false, gold, along_x)


## Cargo's Containers: runs of `runs` [min, max] consecutive crates along
## the back wall, a gap of two between runs.
static func _containers_in_runs(plan: Plan, rng: RandomNumberGenerator, kind: StringName, ring: Array[Vector2i]) -> void:
	var run_range: Array = plan.row.get("runs", [2, 4])
	var on_ring := {}
	for t in ring:
		on_ring[t] = true
	var used := {}
	var queue := plan.room.containers.duplicate()
	var cursor := 0
	while not queue.is_empty() and cursor < ring.size():
		var start := ring[cursor]
		cursor += 1
		if used.has(start):
			continue
		var want := mini(rng.randi_range(int(run_range[0]), int(run_range[1])), queue.size())
		# Run along the wall: the side with the most free ring tiles ahead.
		var dir := Vector2i.ZERO
		var best := -1
		for side in TileShapes.SIDES:
			var free := 0
			var t := start + side
			while on_ring.has(t) and not used.has(t) and not plan.solid.has(t) and free < want:
				free += 1
				t += side
			if free > best:
				best = free
				dir = side
		# A start that cannot take a run (a corner, a one-tile finger) is
		# left for the next Container; the wall's flank comes first.
		if want >= 2 and best == 0:
			continue
		var t := start
		var placed := 0
		while placed < want and on_ring.has(t) and not used.has(t):
			if not _add(plan, kind, t, ONE, false, false, queue[0]):
				break
			queue.pop_front()
			used[t] = true
			placed += 1
			t += dir
		if placed == 0:
			continue
		# The gap after a run, both ends, so runs read apart.
		for k in range(1, 3):
			used[t + dir * (k - 1)] = true
			used[start - dir * k] = true
	for gold: int in queue:
		_add_anywhere(plan, kind, gold)


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
static func _rule_consoles(plan: Plan, rng: RandomNumberGenerator, count: int,
		type: StringName = &"console") -> void:
	if count <= 0:
		return
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
		if _add(plan, type, tile, footprint(type, rotated), true, false, 0, rotated):
			placed += 1


## The Role's consoles along its signature wall (a Bridge's bank one tile
## off the fore wall, an Engine's consoles one off the aft wall),
## [constant BANK_PITCH] apart, each with a station in the gap behind it
## where a body stands facing into the Room. Yields to the doorway rules;
## a wall too ragged for any console falls back to the long-wall rule.
static func _rule_console_bank(plan: Plan, rng: RandomNumberGenerator, count: int) -> void:
	if count <= 0:
		return
	var type: StringName = &"engine_console" if plan.row.signature == "engine_consoles" else &"console"
	var wall := Vector2i.UP if plan.row.wall == "fore" else Vector2i.DOWN
	var anchors: Array[Vector2i] = []
	for t: Vector2i in plan.floor:
		if plan.floor.has(t + wall) and not plan.floor.has(t + wall * 2):
			anchors.append(t)
	anchors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if a.x != b.x else a.y < b.y)
	var placed := 0
	var last_x := -99999
	for t in anchors:
		if placed >= count:
			break
		if t.x - last_x < BANK_PITCH:
			continue
		var gap := t + wall
		if not _standable(plan, gap, {}):
			continue
		if not _add(plan, type, t, CONSOLE_X, true, false):
			continue
		placed += 1
		last_x = t.x
		# The body behind the console faces the Room; the gap either side of
		# it is a station too, for a crowded Bridge.
		for k: int in [0, -1, 1]:
			var stand := gap + Vector2i(k, 0)
			if _standable(plan, stand, {}):
				plan.reserved[stand] = true
				plan.stations.append({tile = stand, facing = -wall})
	if placed == 0:
		_rule_consoles(plan, rng, count, type)


## The Role's signature furniture: a Shield's generator at the Room's
## centre with a ring of stations round it; a Medbay's cryopod row and
## Quarters' bunk pairs along a long wall. Bridge and Engine signatures are
## their console banks; an Armory's and Cargo's are their Containers.
static func _rule_signature(plan: Plan, rng: RandomNumberGenerator) -> void:
	match String(plan.row.signature):
		"generator":
			_rule_generator(plan)
		"cryopod_row":
			_rule_cryopod_row(plan, rng, false)
		"bunk_pairs":
			_rule_cryopod_row(plan, rng, true)


## One full-height generator as near the centre of the largest rect as it
## fits, the free tiles round it reserved as stations facing outward.
static func _rule_generator(plan: Plan) -> void:
	var rect := plan.room.largest_rect()
	var centre := Vector2i(rect.get_center())
	var offsets: Array[Vector2i] = []
	for dx in range(-CENTRE_REACH, CENTRE_REACH + 1):
		for dy in range(-CENTRE_REACH, CENTRE_REACH + 1):
			offsets.append(Vector2i(dx, dy))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var la := a.length_squared()
		var lb := b.length_squared()
		return la < lb if la != lb else (a.y < b.y or (a.y == b.y and a.x < b.x)))
	for off in offsets:
		var at := centre + off
		if not _add(plan, &"generator", at, footprint(&"generator"), true, false):
			continue
		for t in ring_tiles(at, footprint(&"generator")):
			if not _standable(plan, t, {}):
				continue
			plan.reserved[t] = true
			var d := t - at
			var facing := Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) - 1 else Vector2i(0, signi(d.y))
			plan.stations.append({tile = t, facing = facing})
		return


## The tiles one step (diagonals included) outside a footprint at an anchor.
static func ring_tiles(anchor: Vector2i, shape: Array[Vector2i]) -> Array[Vector2i]:
	var inside := {}
	for off in shape:
		inside[anchor + off] = true
	var out: Array[Vector2i] = []
	for off in shape:
		for r in RING:
			var t := anchor + off + r
			if not inside.has(t) and not out.has(t):
				out.append(t)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
	return out


## Cryopods along the long walls of the largest rect: a Medbay's row
## (single pods, [constant ROW_PITCH] apart, up to [constant MAX_ROW]) or
## Quarters' bunks (pairs, [constant BUNK_PITCH] apart, up to
## [constant MAX_BUNKS], their ends noted for footlockers). Pods lie along
## the wall, turned when it runs along x.
static func _rule_cryopod_row(plan: Plan, rng: RandomNumberGenerator, pairs: bool) -> void:
	var rect := plan.room.largest_rect()
	var tall := rect.size.y >= rect.size.x
	var along := Vector2i.DOWN if tall else Vector2i.RIGHT
	var length := rect.size.y if tall else rect.size.x
	var shape := CRYOPOD_Y if tall else CRYOPOD_X
	var pitch := BUNK_PITCH if pairs else ROW_PITCH
	var most := MAX_BUNKS if pairs else MAX_ROW
	var walls: Array[Vector2i] = [rect.position, rect.end - Vector2i.ONE]
	if rng.randf() < 0.5:
		walls.reverse()
	var placed := 0
	for w in walls.size():
		var wall_side := 1 if w == 0 else -1   # inward from this wall
		var k := 1
		while k + 1 < length and placed < most:
			var anchor: Vector2i
			if tall:
				anchor = Vector2i(walls[w].x, rect.position.y + k)
			else:
				anchor = Vector2i(rect.position.x + k, walls[w].y)
			k += pitch
			if not _add(plan, &"cryopod", anchor, shape, false, false, 0, not tall):
				continue
			placed += 1
			if not pairs:
				continue
			var ends: Array[Vector2i] = [anchor + along * 2, anchor - along * 2]
			var inward := (Vector2i.RIGHT if tall else Vector2i.DOWN) * wall_side
			var mate := anchor + inward
			if _add(plan, &"cryopod", mate, shape, false, false, 0, not tall):
				ends.append(mate + along * 2)
				ends.append(mate - along * 2)
			for e in ends:
				if plan.floor.has(e):
					plan.bunk_ends.append(e)
		if placed >= most:
			break


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


## Place a prop if its footprint is free floor outside every Apron and
## every station (and, with `clearance`, touches no other solid piece) and
## every floor tile stays reachable from every doorway afterwards.
static func _add(plan: Plan, type: StringName, tile: Vector2i, shape: Array[Vector2i],
		clearance: bool, breaker: bool, gold: int = 0, rotated: bool = false) -> bool:
	var footprint := shape
	for off in footprint:
		var t := tile + off
		if not plan.floor.has(t) or plan.apron.has(t) or plan.solid.has(t) or plan.reserved.has(t):
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
## first, on its far side facing the doorway; Breakers excluded; when cover
## runs out, the far corner, never an Apron. A multi-rect Room's crew split
## across its rects by area, the remainder on the largest; in a rect with
## no doorway of its own they stand on the side of the cover away from the
## rect's centre. A Role whose row posts crew at stations (a Bridge's and an
## Engine's consoles, a ring round a Shield's generator) fills those first,
## facing as the station says, then the rest by the shared rule.
static func _place_crew(plan: Plan) -> void:
	var room := plan.room
	if room.crew_count <= 0:
		return
	var used := {}
	var taken := {}
	if plan.row.crew in ["stations", "ring"]:
		for station in plan.stations:
			if room.crew_spawns.size() >= room.crew_count:
				break
			var t: Vector2i = station.tile
			if not _standable(plan, t, taken):
				continue
			taken[t] = true
			room.crew_spawns.append(t)
			room.crew_facings.append(station.facing)
	var remaining := room.crew_count - room.crew_spawns.size()
	if remaining <= 0:
		return
	var rects := room.shape().duplicate()
	rects.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_area() > b.get_area())
	var total := room.area()
	var quota: Array[int] = []
	var left := remaining
	for k in range(1, rects.size()):
		@warning_ignore("integer_division")
		var share: int = remaining * rects[k].get_area() / total
		quota.append(share)
		left -= share
	quota.insert(0, left)
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
			var facing := Vector2i.ZERO
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
					facing = -step
					used[c] = true
					break
			if spot == UNSET:
				spot = _far_corner(plan, rect, refs, taken)
			if spot == UNSET:
				continue
			taken[spot] = true
			room.crew_spawns.append(spot)
			room.crew_facings.append(facing)


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
