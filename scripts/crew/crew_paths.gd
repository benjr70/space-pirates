class_name CrewPaths
extends RefCounted
## Walking round props. [ShipNavigator] strings doorways and seam crossings
## together and leaves a crew member to steer straight between them, but a
## Room's props break those straight lines by design. This bends each leg a
## prop would block round it, over a tile grid made from what the layout
## already says: floor tiles, unlocked doorways, and every prop's footprint
## ([method Interiors.footprint]) taken out. Prop boxes sit inside their
## tiles, so an open tile is somewhere a crew member can stand.
##
## The grid is built once per layout and kept on it; a route is one A* query
## per blocked leg and a string-pull, run only when a crew member re-paths.

## Half-width of the square kept clear along a straight leg: the crew
## capsule's 0.35 m radius and a margin, inside half a tile.
const CLEARANCE := 0.45
## Spacing of the points tested along a straight leg, metres.
const SAMPLE := 0.2
## How many tiles out to look for an open tile next to an end that is not on one.
const SNAP := 2
const META := &"crew_paths_grid"


## The layout's walking grid: one cell per tile, open where a crew member can
## stand. Built on first use and cached on the layout.
static func grid(layout: ShipLayout) -> AStarGrid2D:
	if layout.has_meta(META):
		return layout.get_meta(META)
	var open := {}
	for room in layout.rooms:
		open.merge(room.tiles())
	for door in layout.doors:
		if not door.locked:
			for tile in door.tiles():
				open[tile] = true
	for room in layout.rooms:
		for prop in room.props:
			var at: Vector2i = prop.get("tile", Vector2i.ZERO)
			for off in Interiors.footprint(prop.get("type", &""), prop.get("rotated", false)):
				open.erase(at + off)
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for tile: Vector2i in open:
		lo = Vector2i(mini(lo.x, tile.x), mini(lo.y, tile.y))
		hi = Vector2i(maxi(hi.x, tile.x), maxi(hi.y, tile.y))
	var astar := AStarGrid2D.new()
	if open.is_empty():
		lo = Vector2i.ZERO
		hi = Vector2i.ZERO
	astar.region = Rect2i(lo - Vector2i.ONE, hi - lo + Vector2i(3, 3))
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	astar.fill_solid_region(astar.region, true)
	for tile: Vector2i in open:
		astar.set_point_solid(tile, false)
	layout.set_meta(META, astar)
	return astar


## [param points] (a route to walk, from [param from]) with every leg that a
## prop would block bent round it through tile centres. A leg's end inside a
## prop becomes the nearest open tile; an intermediate point no open tile
## reaches (a seam crossing boxed in by props) is skipped; a leg with no way
## round, or one whose way round leaves the Rooms at its ends, is kept
## straight as before.
static func route(layout: ShipLayout, from: Vector3, points: Array[Vector3]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if layout == null:
		out.assign(points)
		return out
	var astar := grid(layout)
	var cursor := from
	for k in points.size():
		var to := points[k]
		if clear(astar, cursor, to):
			out.append(to)
			cursor = to
			continue
		var legs := _round(layout, astar, cursor, to)
		if legs.is_empty():
			if k < points.size() - 1 and _solid(astar, to):
				continue  # boxed in: on to the next point
			out.append(to)
			cursor = to
			continue
		out.append_array(legs)
		cursor = out.back()
	return out


## True when a crew member can walk straight from [param a] to [param b]:
## every tile the clearance square touches along the way is open.
static func clear(astar: AStarGrid2D, a: Vector3, b: Vector3) -> bool:
	var from := Vector2(a.x, a.z)
	var to := Vector2(b.x, b.z)
	var samples := maxi(ceili(from.distance_to(to) / SAMPLE), 1)
	for s in samples + 1:
		var p := from.lerp(to, float(s) / samples)
		for corner in [Vector2(-CLEARANCE, -CLEARANCE), Vector2(CLEARANCE, -CLEARANCE),
				Vector2(-CLEARANCE, CLEARANCE), Vector2(CLEARANCE, CLEARANCE)]:
			var q: Vector2 = p + corner
			if _solid_tile(astar, Vector2i(floori(q.x), floori(q.y))):
				return false
	return true


## Tile centres (and the end itself, when it is on open floor) to steer
## through from [param from] to [param to] round whatever blocks the
## straight line; empty when there is no way round within the Rooms at the
## two ends.
static func _round(layout: ShipLayout, astar: AStarGrid2D, from: Vector3, to: Vector3) -> Array[Vector3]:
	var none: Array[Vector3] = []
	var a := _open_near(astar, from)
	var b := _open_near(astar, to)
	if a == Vector2i.MAX or b == Vector2i.MAX:
		return none
	var tiles := astar.get_id_path(a, b)
	if tiles.is_empty():
		return none
	var allowed := _leg_rooms(layout, from, to)
	var stops: Array[Vector3] = []
	for tile in tiles:
		if not allowed.has(layout.room_at(tile)):
			return none  # the way round runs through another Room
		stops.append(ShipBuilder3D.tile_to_world(tile))
	if not _solid(astar, to):
		stops[-1] = Vector3(to.x, 0.0, to.z)
	# Pull the string: from each anchor, on to the furthest stop in a clear line.
	var out: Array[Vector3] = []
	var anchor := from
	var i := -1
	while i < stops.size() - 1:
		var far := i + 1
		for j in range(i + 2, stops.size()):
			if not clear(astar, anchor, stops[j]):
				break
			far = j
		out.append(stops[far])
		anchor = stops[far]
		i = far
	return out


## The Rooms a leg's way round may pass through, plus doorway tiles
## themselves (-1). An end in a Room stands for that Room, an end in a
## doorway for the two its Door joins; the leg's own Room is the one both
## ends share (so from one doorway to the next across a Room, that Room),
## else every Room either end stands for.
static func _leg_rooms(layout: ShipLayout, from: Vector3, to: Vector3) -> Array:
	var ends := [_rooms_at(layout, _tile(from)), _rooms_at(layout, _tile(to))]
	var rooms := []
	for room in ends[0]:
		if ends[1].has(room):
			rooms.append(room)
	if rooms.is_empty():
		rooms = ends[0] + ends[1]
	rooms.append(-1)
	return rooms


## The Room a tile is in, or the two Rooms joined by the Door it is a
## doorway tile of.
static func _rooms_at(layout: ShipLayout, tile: Vector2i) -> Array:
	var room := layout.room_at(tile)
	if room >= 0:
		return [room]
	for door in layout.doors:
		if door.tiles().has(tile):
			return [door.room_a, door.room_b]
	return []


## Crew bodies stand between half-tiles, so a body near a tile's edge blocks
## the tiles both sides: a tile is shut to a walker whose centre is closer
## than this to a body's (two capsule radii and a margin).
const BODY_GAP := 0.75


## [method route] with the tiles round each of [param bodies] (other crew
## stood in the way, which the grid knows nothing of) shut as well, for a
## crew member at [param from] that walked into them. Empty when no way
## round them reaches its next points, or the way found is the one it is on.
static func route_around(layout: ShipLayout, from: Vector3, points: Array[Vector3], bodies: Array[Vector3]) -> Array[Vector3]:
	var none: Array[Vector3] = []
	if layout == null or points.is_empty():
		return none
	var astar := grid(layout)
	var shut := _shut_round(astar, bodies, [])
	var out := route(layout, from, points)
	# Pressed against a body, its own clearance square already touches the
	# tiles shut round it, so the walk to the first stop is not tested; the
	# legs after it must keep clear of every body.
	var ok := not out.is_empty() and out[0] != points[0] and not _solid(astar, out[0])
	for k in range(1, mini(out.size(), 4)):
		ok = ok and clear(astar, out[k - 1], out[k])
	for tile in shut:
		astar.set_point_solid(tile, false)
	# A body stood on the destination (a work spot) shuts it, and the way
	# round ends beside it: the walk still ends where it was going.
	if ok and out.back() != points.back():
		out.append(points.back())
	return out if ok else none


## Somewhere for a crew member at [param from] to stand out of the way of
## another walking [param way] (its position, then the points it walks to):
## the tile centres to walk through, ending on the nearest open tile within
## MAKE_WAY_REACH steps whose centre is MAKE_WAY_CLEAR or more off that way,
## reached without passing through any of [param bodies] (every other crew
## member near, the other one included). Empty when there is nowhere.
const MAKE_WAY_REACH := 5
const MAKE_WAY_CLEAR := 1.0

static func make_way(layout: ShipLayout, from: Vector3, way: Array[Vector3], bodies: Array[Vector3]) -> Array[Vector3]:
	var none: Array[Vector3] = []
	if layout == null or way.is_empty():
		return none
	var astar := grid(layout)
	var start := _open_near(astar, from)
	if start == Vector2i.MAX:
		return none
	var shut := _shut_round(astar, bodies, [start])
	var came := {start: start}
	var frontier: Array[Vector2i] = [start]
	var found := Vector2i.MAX
	for _step in MAKE_WAY_REACH:
		var next: Array[Vector2i] = []
		for tile in frontier:
			for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var on := tile + side
				if came.has(on) or _solid_tile(astar, on):
					continue
				came[on] = tile
				next.append(on)
				if found == Vector2i.MAX and _off_way(ShipBuilder3D.tile_to_world(on), way):
					found = on
		if found != Vector2i.MAX or next.is_empty():
			break
		frontier = next
	for tile in shut:
		astar.set_point_solid(tile, false)
	if found == Vector2i.MAX:
		return none
	var chain: Array[Vector3] = []
	var at := found
	while at != start:
		chain.push_front(ShipBuilder3D.tile_to_world(at))
		at = came[at]
	return chain


## True when [param point] is MAKE_WAY_CLEAR or more from every leg of [param way].
static func _off_way(point: Vector3, way: Array[Vector3]) -> bool:
	var p := Vector2(point.x, point.z)
	if way.size() == 1:
		return p.distance_to(Vector2(way[0].x, way[0].z)) >= MAKE_WAY_CLEAR
	for k in way.size() - 1:
		var a := Vector2(way[k].x, way[k].z)
		var b := Vector2(way[k + 1].x, way[k + 1].z)
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < MAKE_WAY_CLEAR:
			return false
	return true


## Shuts every open tile whose centre is within BODY_GAP of one of
## [param bodies], except [param keep]; returns the tiles shut, for the
## caller to open again.
static func _shut_round(astar: AStarGrid2D, bodies: Array[Vector3], keep: Array) -> Array[Vector2i]:
	var shut: Array[Vector2i] = []
	for body in bodies:
		var at := _tile(body)
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var tile := at + Vector2i(dx, dy)
				if keep.has(tile) or _solid_tile(astar, tile):
					continue
				var centre := ShipBuilder3D.tile_to_world(tile)
				if Vector2(centre.x - body.x, centre.z - body.z).length() < BODY_GAP:
					astar.set_point_solid(tile, true)
					shut.append(tile)
	return shut


static func _tile(point: Vector3) -> Vector2i:
	return ShipBuilder3D.world_to_tile(point)


static func _solid_tile(astar: AStarGrid2D, tile: Vector2i) -> bool:
	return not astar.is_in_boundsv(tile) or astar.is_point_solid(tile)


static func _solid(astar: AStarGrid2D, point: Vector3) -> bool:
	return _solid_tile(astar, _tile(point))


## The open tile under [param point], else the nearest open one within SNAP
## tiles, else Vector2i.MAX.
static func _open_near(astar: AStarGrid2D, point: Vector3) -> Vector2i:
	var at := _tile(point)
	if not _solid_tile(astar, at):
		return at
	var best := Vector2i.MAX
	var best_distance := INF
	var flat := Vector2(point.x, point.z)
	for dx in range(-SNAP, SNAP + 1):
		for dy in range(-SNAP, SNAP + 1):
			var tile := at + Vector2i(dx, dy)
			if _solid_tile(astar, tile):
				continue
			var distance := flat.distance_to(Vector2(tile) + Vector2(0.5, 0.5))
			if distance < best_distance:
				best = tile
				best_distance = distance
	return best
