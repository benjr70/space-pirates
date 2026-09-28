class_name ShipGraph
extends RefCounted
## Readings of a finished [ShipLayout] that Hatch placement, Role assignment
## and the harness share: the Door graph and Flow Distance over it, the wall
## ring, the Hull (walls reachable from outside) and Hull Exposure.


## Roles fixed by the Skeleton: never a Hatch, never reassigned.
const FIXED_ROLES: Array[StringName] = [&"bridge", &"engine", &"corridor"]


## Whether a Room of this Role may take a Hatch or an optional Role.
static func is_fixed_role(role: StringName) -> bool:
	return role in FIXED_ROLES


## Neighbours of every Room through Doors: {room: Array[int]}.
static func adjacency(layout: ShipLayout) -> Dictionary:
	var out := {}
	for i in layout.rooms.size():
		out[i] = []
	for d in layout.doors:
		if d.room_a < 0 or d.room_b < 0:
			continue
		out[d.room_a].append(d.room_b)
		out[d.room_b].append(d.room_a)
	return out


## Fewest Doors from the nearest of [param sources] to every Room, -1 where
## unreachable. With the Hatch Rooms as sources this is Flow Distance.
static func distances(layout: ShipLayout, sources: Array[int], adjacency_map: Dictionary = {}) -> Array[int]:
	var adj := adjacency_map if not adjacency_map.is_empty() else adjacency(layout)
	var dist: Array[int] = []
	dist.resize(layout.rooms.size())
	dist.fill(-1)
	var queue: Array[int] = []
	for s in sources:
		if s >= 0 and s < dist.size() and dist[s] < 0:
			dist[s] = 0
			queue.append(s)
	var head := 0
	while head < queue.size():
		var room := queue[head]
		head += 1
		for n: int in adj[room]:
			if dist[n] < 0:
				dist[n] = dist[room] + 1
				queue.append(n)
	return dist


## Flow Distance of every Room from the nearest Hatch Room.
static func flow_distances(layout: ShipLayout) -> Array[int]:
	var sources: Array[int] = []
	for h in layout.hatches:
		sources.append(h.room)
	return distances(layout, sources)


## Mean Door count from a Room to every other reachable Room: low is central.
static func mean_distance(layout: ShipLayout, room: int, adjacency_map: Dictionary) -> float:
	var dist := distances(layout, [room], adjacency_map)
	var total := 0
	var n := 0
	for i in dist.size():
		if i != room and dist[i] >= 0:
			total += dist[i]
			n += 1
	return float(total) / maxi(n, 1)


## Every wall tile: the one-tile ring around each rect of each Room, minus
## anything that is floor (the same rule the builders paint by).
static func walls(layout: ShipLayout, floors: Dictionary) -> Dictionary:
	var out := {}
	for room in layout.rooms:
		for rect in room.shape():
			var ring := rect.grow(1)
			for x in range(ring.position.x, ring.end.x):
				for y in range(ring.position.y, ring.end.y):
					var t := Vector2i(x, y)
					if not floors.has(t):
						out[t] = true
	return out


## Every empty tile reachable by flood-fill from outside the ship's bounding
## box; floor and walls are solid to the fill.
static func outside(floors: Dictionary, wall_set: Dictionary) -> Dictionary:
	var all := floors.duplicate()
	all.merge(wall_set)
	if all.is_empty():
		return {}
	var box := TileShapes.bounds(all).grow(2)
	var start := box.position
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for side in TileShapes.SIDES:
			var n := t + side
			if seen.has(n) or not box.has_point(n) or floors.has(n) or wall_set.has(n):
				continue
			seen[n] = true
			queue.append(n)
	return seen


## Every floor tile of Rooms and Doors, leaving Hatches out: a Hatch tile is
## a Hull tile, so the Hull is read before Hatches or with them set aside.
static func floor_without_hatches(layout: ShipLayout) -> Dictionary:
	var tiles := {}
	for room in layout.rooms:
		tiles.merge(room.tiles())
	for door in layout.doors:
		for t in door.tiles():
			tiles[t] = true
	return tiles


## The Hull: wall tiles with empty space reachable from outside beside them.
## Hatch tiles count as Hull.
static func hull_tiles(layout: ShipLayout) -> Dictionary:
	var floors := floor_without_hatches(layout)
	var wall_set := walls(layout, floors)
	return hull_from(wall_set, outside(floors, wall_set))


## The Hull read off a wall set and the outside already flooded, for a
## caller that holds both.
static func hull_from(wall_set: Dictionary, out_set: Dictionary) -> Dictionary:
	var hull := {}
	for t: Vector2i in wall_set:
		for side in TileShapes.SIDES:
			if out_set.has(t + side):
				hull[t] = true
				break
	return hull


## Share of a Room's wall ring that is Hull, 0 to 1.
static func hull_exposure(room: RoomData, floors: Dictionary, hull: Dictionary) -> float:
	var ring := {}
	for rect in room.shape():
		var box := rect.grow(1)
		for x in range(box.position.x, box.end.x):
			for y in range(box.position.y, box.end.y):
				var t := Vector2i(x, y)
				if not floors.has(t):
					ring[t] = true
	var exposed := 0
	for t: Vector2i in ring:
		if hull.has(t):
			exposed += 1
	return float(exposed) / maxi(ring.size(), 1)


## Steps along the Hull (8-connected) from one Hull tile to every other:
## {Vector2i: int}. Tiles not reached are absent.
static func hull_distances(hull: Dictionary, from: Vector2i) -> Dictionary:
	var dist := {}
	if not hull.has(from):
		return dist
	dist[from] = 0
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var t := queue[head]
		head += 1
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var n := t + Vector2i(dx, dy)
				if (dx != 0 or dy != 0) and hull.has(n) and not dist.has(n):
					dist[n] = dist[t] + 1
					queue.append(n)
	return dist
