class_name ShipNavigator
extends RefCounted
## Routes across a ship using the door graph the layout already describes.
##
## Rooms are convex rectangles, so steering straight at a point works inside
## one. All this has to solve is which doorways to string together to get from
## one room to another.


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
## centre of each doorway on the way, then the destination itself.
static func waypoints(layout: ShipLayout, from: Vector2, to: Vector2) -> Array[Vector2]:
	var start := layout.room_at(ShipBuilder.world_to_tile(from))
	var goal := layout.room_at(ShipBuilder.world_to_tile(to))
	var rooms := room_path(layout, start, goal)
	var points: Array[Vector2] = []
	if rooms.is_empty():
		return points
	for i in range(rooms.size() - 1):
		var door := door_between(layout, rooms[i], rooms[i + 1])
		if door != null:
			points.append(ShipBuilder.door_center_world(door))
	points.append(to)
	return points
