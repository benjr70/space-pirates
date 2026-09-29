class_name ProtoHatch
extends RefCounted
## Throwaway: gives a prototype layout a boarding hatch so main_3d can spawn
## the walker. Picks the first two-tile run of hull wall around `room` with
## empty space beyond it. Real hatch placement is the generator's job.


static func through_hull(layout: ShipLayout, room: int) -> HatchData:
	var floors := layout.floor_tiles()
	var walls := ShipBuilder3D.wall_tiles(layout, floors)
	var data: RoomData = layout.rooms[room]
	for rect in data.shape():
		# Vertical walls (gap runs along Y), then horizontal ones.
		for x in [rect.position.x - 1, rect.end.x]:
			var out := Vector2i.LEFT if x < rect.position.x else Vector2i.RIGHT
			for y in range(rect.position.y, rect.end.y - 1):
				var hatch := _try(layout, room, Vector2i(x, y), false, out, floors, walls)
				if hatch != null:
					return hatch
		for y in [rect.position.y - 1, rect.end.y]:
			var out := Vector2i.UP if y < rect.position.y else Vector2i.DOWN
			for x in range(rect.position.x, rect.end.x - 1):
				var hatch := _try(layout, room, Vector2i(x, y), true, out, floors, walls)
				if hatch != null:
					return hatch
	push_warning("ProtoHatch: room %d has no hull wall; hatch forced on its left" % room)
	var first: Rect2i = data.shape()[0]
	return _make(room, Vector2i(first.position.x - 1, first.position.y), false)


static func _try(layout: ShipLayout, room: int, tile: Vector2i, horizontal: bool,
		out: Vector2i, floors: Dictionary, walls: Dictionary) -> HatchData:
	var hatch := _make(room, tile, horizontal)
	for t in hatch.tiles():
		if floors.has(t) or not walls.has(t):
			return null
		var beyond: Vector2i = t + out
		if floors.has(beyond) or walls.has(beyond):
			return null
		if layout.room_at(t - out) != room:
			return null
	return hatch


static func _make(room: int, tile: Vector2i, horizontal: bool) -> HatchData:
	var hatch := HatchData.new()
	hatch.room = room
	hatch.tile = tile
	hatch.horizontal = horizontal
	hatch.width = 2
	return hatch
