class_name RoomDataChecks
extends RefCounted
## Unit checks on [RoomData]'s shape helpers, run from inside each headless
## suite: `RoomDataChecks.run(_expect)`.


static func run(expect: Callable) -> void:
	_check_single_rect(expect)
	_check_two_rects_union(expect)
	_check_fight_core_across_seam(expect)
	_check_fight_core_needs_union_not_bounds(expect)
	_check_center_stands_on_floor(expect)


static func _room(rects: Array[Rect2i]) -> RoomData:
	var room := RoomData.new()
	room.rects = rects
	return room


## A hand-authored Room is one rect; every helper must read it as the whole
## shape.
static func _check_single_rect(expect: Callable) -> void:
	var room := _room([Rect2i(3, 5, 10, 14)])
	expect.call(room.shape() == [Rect2i(3, 5, 10, 14)], "single rect: shape is not the rect")
	expect.call(room.bounds() == Rect2i(3, 5, 10, 14), "single rect: bounds differ from rect")
	expect.call(room.area() == 140, "single rect: area %d, expected 140" % room.area())
	expect.call(room.tiles().size() == 140, "single rect: %d tiles, expected 140" % room.tiles().size())
	expect.call(room.has_tile(Vector2i(3, 5)), "single rect: corner tile not in room")
	expect.call(room.has_tile(Vector2i(12, 18)), "single rect: far corner tile not in room")
	expect.call(not room.has_tile(Vector2i(13, 18)), "single rect: tile past the end counted as floor")
	expect.call(not room.has_tile(Vector2i(2, 5)), "single rect: tile before the start counted as floor")
	expect.call(room.center_tile() == Vector2(8, 12), "single rect: centre %s, expected (8, 12)" % room.center_tile())
	expect.call(room.has_fight_core(), "10x14 room fails the Fight Core it was walk-tested to hold")

	room.rects = [Rect2i(0, 0, 6, 10)]
	expect.call(not room.has_fight_core(), "6x10 room passes the Fight Core it was rejected on")
	room.rects = [Rect2i(0, 0, 9, 9)]
	expect.call(not room.has_fight_core(), "9x9 room passes a 10x10 Fight Core")
	room.rects = [Rect2i(-4, -4, 10, 10)]
	expect.call(room.has_fight_core(), "exact 10x10 room at negative origin fails the Fight Core")


## Two abutting rects: a 10x10 block with a 6x4 alcove on its right.
static func _check_two_rects_union(expect: Callable) -> void:
	var room := _room([Rect2i(0, 0, 10, 10), Rect2i(10, 0, 6, 4)])
	expect.call(room.area() == 124, "two rects: area %d, expected 124" % room.area())
	expect.call(room.tiles().size() == 124, "two rects: %d tiles, expected 124" % room.tiles().size())
	expect.call(room.bounds() == Rect2i(0, 0, 16, 10), "two rects: bounds %s, expected (0,0,16,10)" % room.bounds())
	expect.call(room.has_tile(Vector2i(9, 9)), "two rects: block corner missing")
	expect.call(room.has_tile(Vector2i(10, 0)), "two rects: first alcove tile missing")
	expect.call(room.has_tile(Vector2i(15, 3)), "two rects: last alcove tile missing")
	expect.call(not room.has_tile(Vector2i(15, 4)), "two rects: tile below the alcove counted as floor")
	expect.call(not room.has_tile(Vector2i(16, 0)), "two rects: tile past the alcove counted as floor")
	expect.call(room.has_fight_core(), "block plus alcove fails the Fight Core the block alone holds")


## Neither rect holds a 10x10 on its own; only the union across the seam does.
static func _check_fight_core_across_seam(expect: Callable) -> void:
	var room := _room([Rect2i(0, 0, 6, 10), Rect2i(6, 0, 4, 10)])
	expect.call(room.area() == 100, "seam: area %d, expected 100" % room.area())
	expect.call(room.has_fight_core(), "6x10 + 4x10 abutting fails the Fight Core their union holds")

	var short := _room([Rect2i(0, 0, 6, 10), Rect2i(6, 0, 3, 10)])
	expect.call(not short.has_fight_core(), "6x10 + 3x10 (a 9x10 union) passes a 10x10 Fight Core")

	# Rects listed in either order, and stacked vertically, behave the same.
	var stacked := _room([Rect2i(0, 7, 10, 3), Rect2i(0, 0, 10, 7)])
	expect.call(stacked.has_fight_core(), "10x7 over 10x3 fails the Fight Core their union holds")


## An L whose bounding box is 10x15 but which nowhere contains a clear 10x10.
static func _check_fight_core_needs_union_not_bounds(expect: Callable) -> void:
	var room := _room([Rect2i(0, 0, 10, 5), Rect2i(0, 5, 5, 10)])
	expect.call(room.bounds() == Rect2i(0, 0, 10, 15), "L: bounds %s, expected (0,0,10,15)" % room.bounds())
	expect.call(room.area() == 100, "L: area %d, expected 100" % room.area())
	expect.call(not room.has_fight_core(), "L-shaped room passes the Fight Core on its bounding box")
	expect.call(room.has_fight_core(Vector2i(5, 5)), "L-shaped room fails a 5x5 core it plainly holds")
	expect.call(not room.has_fight_core(Vector2i(6, 11)), "L-shaped room passes a 6x11 core its arms cannot hold")


## The centre is a standing spot, so it is the centre of the largest rect,
## never the centre of a bounding box that may be wall for an L-shaped Room.
static func _check_center_stands_on_floor(expect: Callable) -> void:
	var room := _room([Rect2i(0, 0, 10, 5), Rect2i(0, 5, 5, 12)])
	expect.call(room.center_tile() == Vector2(2.5, 11), "L: centre %s, expected the bigger arm's centre (2.5, 11)" % room.center_tile())
	expect.call(room.has_tile(Vector2i(room.center_tile().floor())), "L: centre tile is not floor")

	var alcove := _room([Rect2i(10, 0, 6, 4), Rect2i(0, 0, 10, 10)])
	expect.call(alcove.center_tile() == Vector2(5, 5), "block + alcove: centre %s, expected the block's (5, 5)" % alcove.center_tile())
