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
	_check_floor_rule(expect)
	_check_corridor_width(expect)
	_check_display_name(expect)


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


## The one fightable floor: a non-corridor Room holds a 10x10 Fight Core and
## 140 tiles; 6x10 was rejected on foot and 10x14 is the minimum that passed.
static func _check_floor_rule(expect: Callable) -> void:
	var room := _room([Rect2i(0, 0, 6, 10)])
	room.role = &"cargo"
	expect.call(not room.meets_floor(), "floor: a 6x10 room passes")
	room.rects = [Rect2i(0, 0, 10, 14)]
	expect.call(room.meets_floor(), "floor: a 10x14 room fails")
	room.rects = [Rect2i(0, 0, 10, 13)]
	expect.call(not room.meets_floor(), "floor: a 10x13 room (130 tiles) passes the 140 minimum")
	room.rects = [Rect2i(0, 0, 12, 12)]
	expect.call(room.meets_floor(), "floor: a 12x12 room fails")
	# Enough tiles but no core: two 7-wide arms.
	room.rects = [Rect2i(0, 0, 7, 20), Rect2i(7, 0, 7, 5)]
	expect.call(room.area() >= RoomData.MIN_AREA, "floor: fixture has fewer than 140 tiles")
	expect.call(not room.meets_floor(), "floor: 175 tiles with no 10x10 core passes")
	# The ceiling: 260 is the most a Room may hold, in any Role.
	room.rects = [Rect2i(0, 0, 20, 13)]
	expect.call(room.meets_floor(), "floor: a 20x13 room (260 tiles) fails the ceiling it sits on")
	room.rects = [Rect2i(0, 0, 21, 13)]
	expect.call(not room.meets_floor(), "floor: a 21x13 room (273 tiles) passes the 260 ceiling")
	room.role = &"corridor"
	expect.call(room.meets_floor(), "floor: a 273-tile corridor is held to a ceiling a ring corridor cannot meet; corridors are exempt")


## Corridors are exempt from the Fight Core and instead must be at least 3
## wide along their whole length.
static func _check_corridor_width(expect: Callable) -> void:
	var corridor := _room([Rect2i(0, 0, 3, 20)])
	corridor.role = &"corridor"
	expect.call(corridor.meets_floor(), "corridor: a 3x20 corridor fails the floor")
	expect.call(not corridor.has_fight_core(), "corridor: fixture unexpectedly holds a Fight Core")
	corridor.rects = [Rect2i(0, 0, 2, 20)]
	expect.call(not corridor.meets_floor(), "corridor: a 2-wide corridor passes")
	corridor.rects = [Rect2i(0, 0, 20, 3), Rect2i(0, 3, 3, 15)]
	expect.call(corridor.meets_floor(), "corridor: an L of two 3-wide arms fails")
	corridor.rects = [Rect2i(0, 0, 20, 3), Rect2i(0, 3, 2, 15)]
	expect.call(not corridor.meets_floor(), "corridor: a 3-wide run with a 2-wide arm passes")
	corridor.rects = [Rect2i(0, 0, 20, 3), Rect2i(20, 1, 5, 1)]
	expect.call(not corridor.meets_floor(), "corridor: a 3-wide run with a 1-wide stub passes")
	expect.call(corridor.has_clear_width(1), "corridor: has_clear_width(1) fails on any floor")
	# The same shape as a non-corridor Room is judged by the Fight Core instead.
	corridor.rects = [Rect2i(0, 0, 3, 20)]
	corridor.role = &"quarters"
	expect.call(not corridor.meets_floor(), "corridor: a 3x20 quarters passes the fightable floor")


## A ship stores its bare name; display prepends "The" unless it carries a
## registry prefix.
static func _check_display_name(expect: Callable) -> void:
	var layout := ShipLayout.new()
	layout.ship_name = "Pirate"
	expect.call(layout.display_name() == "The Pirate", "name: 'Pirate' displays as '%s'" % layout.display_name())
	layout.ship_name = "ISV Pirate"
	expect.call(layout.display_name() == "ISV Pirate", "name: 'ISV Pirate' displays as '%s'" % layout.display_name())
	layout.ship_name = "CSS Long Night"
	expect.call(layout.display_name() == "CSS Long Night", "name: 'CSS Long Night' displays as '%s'" % layout.display_name())
	layout.ship_name = "Rusty Hauler"
	expect.call(layout.display_name() == "The Rusty Hauler", "name: 'Rusty Hauler' displays as '%s'" % layout.display_name())


## A small ship with a corridor Role Room, for the suites' layout-level floor
## check: two fightable Rooms either side of a 3-wide corridor.
##
##   ##########   #####   ##########
##   # 10x14  #+++# 3 #+++# 10x14  #
##   ##########   #x18#   ##########
##                #####
static func corridor_layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.ship_name = "Corridor"
	var west := _room([Rect2i(0, 0, 10, 14)])
	west.role = &"cargo"
	var corridor := _room([Rect2i(11, 0, 3, 18)])
	corridor.role = &"corridor"
	var east := _room([Rect2i(15, 0, 10, 14)])
	east.role = &"quarters"
	layout.rooms = [west, corridor, east]
	layout.doors = [_side_door(0, 1, Vector2i(10, 5)), _side_door(1, 2, Vector2i(14, 5))]
	layout.hatches = [_side_hatch(0, Vector2i(-1, 6)), _side_hatch(2, Vector2i(25, 6))]
	return layout


## A two-wide doorway through a vertical wall.
static func _side_door(a: int, b: int, tile: Vector2i) -> DoorData:
	var door := DoorData.new()
	door.room_a = a
	door.room_b = b
	door.tile = tile
	door.horizontal = false
	door.width = 2
	return door


## A hatch through a vertical hull wall.
static func _side_hatch(room: int, tile: Vector2i) -> HatchData:
	var hatch := HatchData.new()
	hatch.room = room
	hatch.tile = tile
	hatch.horizontal = false
	return hatch
