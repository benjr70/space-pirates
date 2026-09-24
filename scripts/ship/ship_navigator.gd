class_name ShipNavigator
extends RefCounted
## Routes across a ship using the door graph the layout already describes.
##
## Every rect of a Room is convex, so steering straight at a point works inside
## one. All this has to solve is which doorways to string together to get from
## one room to another, and, inside a multi-rect Room, which seams between its
## rects to cross on the way.
##
## Routing is done in tile units (floats, tile corners at integers); the
## dimension-specific entry points convert to and from world space.


## Room indices from [param from_room] to [param to_room] inclusive, or an empty
## array if there is no way through unlocked doors. Breadth-first, so the route
## passes through as few rooms as possible.
static func room_path(layout: ShipLayout, from_room: int, to_room: int) -> Array[int]:
	if from_room == -1 or to_room == -1:
		return []
	if from_room == to_room:
		return [from_room]

	var came_from := {from_room: -1}
	var queue: Array[int] = [from_room]
	while not queue.is_empty():
		var room: int = queue.pop_front()
		if room == to_room:
			break
		for door in layout.doors:
			if door.locked:
				continue
			var next := -1
			if door.room_a == room:
				next = door.room_b
			elif door.room_b == room:
				next = door.room_a
			if next == -1 or came_from.has(next):
				continue
			came_from[next] = room
			queue.append(next)

	if not came_from.has(to_room):
		return []

	var path: Array[int] = []
	var step := to_room
	while step != -1:
		path.push_front(step)
		step = came_from[step]
	return path


## The doorway joining two rooms, or null if they are not neighbours.
static func door_between(layout: ShipLayout, room_a: int, room_b: int) -> DoorData:
	for door in layout.doors:
		if (door.room_a == room_a and door.room_b == room_b) \
				or (door.room_a == room_b and door.room_b == room_a):
			return door
	return null


## World points to steer through to walk from one position to another: the
## centre of each doorway and seam crossing on the way, then the destination.
static func waypoints(layout: ShipLayout, from: Vector2, to: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for p in waypoint_tiles(layout, from / ShipBuilder.TILE_SIZE, to / ShipBuilder.TILE_SIZE):
		points.append(p * ShipBuilder.TILE_SIZE)
	return points


## The route in tile units: through each room on the way (crossing seams
## between its rects where needed), out through the doorway to the next, and
## finally to `to`. Empty when either end is in no room, or unreachable.
static func waypoint_tiles(layout: ShipLayout, from: Vector2, to: Vector2) -> Array[Vector2]:
	var start := layout.room_at(Vector2i(from.floor()))
	var goal := layout.room_at(Vector2i(to.floor()))
	var rooms := room_path(layout, start, goal)
	var points: Array[Vector2] = []
	if rooms.is_empty():
		return points
	var cursor := from
	for i in rooms.size():
		var target := to
		if i < rooms.size() - 1:
			var door := door_between(layout, rooms[i], rooms[i + 1])
			if door == null:
				continue
			target = door_center_tile(door)
		for seam in through_room(layout.rooms[rooms[i]], cursor, target):
			points.append(seam)
		points.append(target)
		cursor = target
	return points


## Centre of a doorway in tile units, accounting for how many tiles wide it is.
static func door_center_tile(door: DoorData) -> Vector2:
	var span := Vector2(door.width, 1) if door.horizontal else Vector2(1, door.width)
	return Vector2(door.tile) + span / 2.0


## Points to steer through to get from `from` to `to` inside one Room, not
## including `to` itself: one crossing per seam between the rects on the way.
## Empty when both ends are in the same rect, since a rect is convex. Either
## end may sit just outside the floor (a doorway); it is routed from the rect
## nearest to it.
static func through_room(room: RoomData, from: Vector2, to: Vector2) -> Array[Vector2]:
	var parts := room.shape()
	var chain := rect_path(parts, _rect_near(parts, from), _rect_near(parts, to))
	var points: Array[Vector2] = []
	var cursor := from
	for i in range(chain.size() - 1):
		var crossing := seam_crossing(parts[chain[i]], parts[chain[i + 1]], cursor, to)
		points.append(crossing)
		cursor = crossing
	return points


## Indices of the rects to walk through from rect `a` to rect `b` inclusive,
## stepping only between rects that share a seam. Breadth-first. Empty if the
## rects are not joined, which a well-formed Room never is.
static func rect_path(parts: Array[Rect2i], a: int, b: int) -> Array[int]:
	if a == b:
		return [a]
	var came_from := {a: -1}
	var queue: Array[int] = [a]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		if current == b:
			break
		for next in parts.size():
			if came_from.has(next) or not abuts(parts[current], parts[next]):
				continue
			came_from[next] = current
			queue.append(next)
	if not came_from.has(b):
		return []
	var path: Array[int] = []
	var step := b
	while step != -1:
		path.push_front(step)
		step = came_from[step]
	return path


## Whether two rects share an edge of at least one tile (touching corners do
## not count: there is no walking between them).
static func abuts(a: Rect2i, b: Rect2i) -> bool:
	var x_touch := a.end.x == b.position.x or b.end.x == a.position.x
	var y_touch := a.end.y == b.position.y or b.end.y == a.position.y
	var x_overlap := mini(a.end.x, b.end.x) - maxi(a.position.x, b.position.x) > 0
	var y_overlap := mini(a.end.y, b.end.y) - maxi(a.position.y, b.position.y) > 0
	return (x_touch and y_overlap) or (y_touch and x_overlap)


## Where to cross the Seam between abutting rects `a` and `b` on the way from
## `from` to `to`: the midpoint of `from` and `to` projected onto the shared
## edge, clamped half a tile in from the edge's ends so the walker clears the
## corner. Not the shortest crossing, but always on floor. Assumes [method abuts].
static func seam_crossing(a: Rect2i, b: Rect2i, from: Vector2, to: Vector2) -> Vector2:
	var mid := (from + to) / 2.0
	if a.end.x == b.position.x or b.end.x == a.position.x:
		var x := float(a.end.x if a.end.x == b.position.x else b.end.x)
		var lo := maxi(a.position.y, b.position.y) + 0.5
		var hi := mini(a.end.y, b.end.y) - 0.5
		return Vector2(x, clampf(mid.y, lo, hi))
	var y := float(a.end.y if a.end.y == b.position.y else b.end.y)
	var lo := maxi(a.position.x, b.position.x) + 0.5
	var hi := mini(a.end.x, b.end.x) - 0.5
	return Vector2(clampf(mid.x, lo, hi), y)


## The rect containing `point`, else the nearest one (a doorway sits on the
## wall ring, one tile outside every rect).
static func _rect_near(parts: Array[Rect2i], point: Vector2) -> int:
	var best := 0
	var best_distance := INF
	for i in parts.size():
		var r := Rect2(parts[i])
		if r.has_point(point):
			return i
		var nearest := point.clamp(r.position, r.end)
		var distance := point.distance_to(nearest)
		if distance < best_distance:
			best_distance = distance
			best = i
	return best
