extends Node3D
## PROTOTYPE — walk the shared cover-and-sightline vocabulary (issue #13).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_cover_walk.tscn \
##       -- seed=1 bare=0 density=2
##
## density=1 was walked first and NOT FELT against bare=1: one crate per
## doorway and seven along the corridor vanish in first person. density=2
## makes every breaker an L of crates and every corridor alcove a pair, and
## adds free-standing cover islands scaled to Room area; density=3 doubles
## the islands. The knob is the question now.
##
## Four packed Rooms and a corridor, furnished by ONE generic rule set that
## every Role interior generator would inherit. No Role flavour: the question
## is whether the shared rules alone make Rooms fightable and Containers
## findable. `bare=1` skips the doorway breakers and lane cutters so the
## difference can be felt on foot.
##
## You start in the entry Cargo bay (a Hatch Room: halved threat, 1 crew).
## Corridor runs north–south. East of it: Quarters (the 10×14 minimum, 2 crew),
## then the Armory (14×16 ≈ 220 tiles, 4 crew = the cap, two big lockers).
## West of it: a wide, shallow Cargo hold (18×12, 3 crew, four crates).
## Prints an ASCII plan on start so the placement can be read alongside the walk.
##
## Legend: . floor  # crate(1.1m)  = console(1.0m)  P cryopod(full)  $ container
##         L locker(full)  x crew  D door  , apron (kept clear)

const CONTAINER_SCENE: PackedScene = preload("res://scenes/props3d/proto_container_3d.tscn")
const LOCKER_SCENE: PackedScene = preload("res://scenes/props3d/proto_locker_3d.tscn")

## --- The vocabulary, as numbers. Tweak here, re-run, walk. ---
## Tiles kept clear straight in front of a doorway, inside the Room.
const APRON_DEPTH := 2
## How far in from the doorway the first breaker (crate) stands.
const BREAKER_DEPTH := 3
## Lateral offset of the breaker from the doorway's centre line.
const BREAKER_SIDESTEP := 1
## Spacing of alternating alcove crates along a corridor.
const CORRIDOR_STAGGER := 6
## Most prop islands allowed inside the 10×10 Fight Core.
const CORE_ISLANDS := 2

var walk_seed := 1
var bare := false
var density := 2
var _rng := RandomNumberGenerator.new()
## Room index -> {tile: char}, for the ASCII plan.
var _plan := {}
## Room index -> Array[Vector2i] crew spawn tiles.
var _spawns := {}
## Room index -> Array of {type, tile} for props the builder does not know.
var _extra_props := {}
## Room index -> {tile: true} for breaker crates, which crew never hide behind:
## they are the cover an ENTERING pirate reaches, not the defender's.
var _breakers := {}
## Room index -> {anchor tile: true}, one per prop, so a 3-tile console is one
## piece of cover and not three.
var _pieces := {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seed":
				walk_seed = int(kv[1])
			"bare":
				bare = int(kv[1]) != 0
			"density":
				density = int(kv[1])
	_rng.seed = walk_seed

	var layout := _make_layout()
	_furnish_all(layout)

	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	main.layout_override = layout
	main.explore_darkness = false
	add_child(main)
	_spawn_extras(main, layout)
	_place_crew(main, layout)
	_print_plan(layout)
	print("cover walk seed=%d bare=%s density=%d" % [walk_seed, bare, density])


# ---------------------------------------------------------------------------
# Layout: hand-packed, shapes chosen to stress the rules.
# ---------------------------------------------------------------------------

func _make_layout() -> ShipLayout:
	var layout := ShipLayout.new()
	layout.ship_name = "Cover Walk %d" % walk_seed
	layout.rooms = [
		_room(Rect2i(0, 0, 4, 42), &"corridor", 1),      # 0 corridor, N–S
		_room(Rect2i(5, 0, 12, 14), &"cargo", 1),        # 1 entry bay (Hatch Room)
		_room(Rect2i(5, 15, 14, 10), &"quarters", 2),    # 2 minimum Room
		_room(Rect2i(5, 26, 14, 16), &"armory", 4),      # 3 big Room at the cap
		_room(Rect2i(-19, 10, 18, 12), &"cargo", 3),     # 4 wide shallow hold
	]
	layout.doors = [
		_door(0, 1, Vector2i(4, 11), false, 2),   # corridor ↔ entry bay
		_door(0, 2, Vector2i(4, 19), false, 2),   # corridor ↔ quarters
		_door(0, 3, Vector2i(4, 33), false, 2),   # corridor ↔ armory
		_door(2, 3, Vector2i(10, 25), true, 2),   # quarters ↔ armory (second door)
		_door(0, 4, Vector2i(-1, 11), false, 2),  # corridor ↔ west hold, FACES the entry door
	]
	layout.hatches = [ProtoHatch.through_hull(layout, 1)]
	return layout


func _room(rect: Rect2i, role: StringName, crew: int) -> RoomData:
	var r := RoomData.new()
	r.rects = [rect]
	r.role = role
	r.crew_count = crew
	return r


func _door(a: int, b: int, tile: Vector2i, horizontal: bool, width: int) -> DoorData:
	var d := DoorData.new()
	d.room_a = a
	d.room_b = b
	d.tile = tile
	d.horizontal = horizontal
	d.width = width
	return d


# ---------------------------------------------------------------------------
# The shared vocabulary.
# ---------------------------------------------------------------------------

## One doorway as seen from inside a given Room.
class Opening:
	var tiles: Array[Vector2i]   # the door's wall tiles
	var normal: Vector2i         # points INTO the room
	var lateral: Vector2i        # runs along the doorway
	var centre: Vector2          # centre of the doorway, in tile space

	func apron(depth: int) -> Array[Vector2i]:
		var out: Array[Vector2i] = []
		for t in tiles:
			for d in range(1, depth + 1):
				out.append(t + normal * d)
		return out


func _openings(layout: ShipLayout, index: int) -> Array[Opening]:
	var rect := layout.rooms[index].largest_rect()
	var out: Array[Opening] = []
	for door in layout.doors:
		if door.room_a != index and door.room_b != index:
			continue
		var o := Opening.new()
		o.tiles = door.tiles()
		o.lateral = Vector2i.RIGHT if door.horizontal else Vector2i.DOWN
		var first := o.tiles[0]
		if door.horizontal:
			o.normal = Vector2i.DOWN if first.y < rect.position.y else Vector2i.UP
		else:
			o.normal = Vector2i.RIGHT if first.x < rect.position.x else Vector2i.LEFT
		var sum := Vector2.ZERO
		for t in o.tiles:
			sum += Vector2(t)
		o.centre = sum / o.tiles.size()
		out.append(o)
	return out


## Per-Room bookkeeping. Other prototypes reuse the rules by instancing this
## script without adding it to the tree, calling this, then the rules.
func _init_rooms(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		_plan[i] = {}
		_extra_props[i] = []
		_spawns[i] = []
		_breakers[i] = {}
		_pieces[i] = {}


func _furnish_all(layout: ShipLayout) -> void:
	_init_rooms(layout)
	_furnish_corridor(layout, 0)
	_furnish_room(layout, 1, 0, [])              # entry bay: no containers, one crew
	_furnish_room(layout, 2, 1, [1])             # quarters: one footlocker-sized container
	_furnish_room(layout, 3, 2, [5, 3])          # armory: two lockers, 5 and 3 gold
	_furnish_room(layout, 4, 2, [2, 2, 1, 1])    # cargo: four crates
	for i in layout.rooms.size():
		_place_crew_spawns(layout, i)
		_check_reachability(layout, i)


## Occupancy per Room: tile -> true for anything solid.
func _solid(index: int) -> Dictionary:
	var out := {}
	for t in _plan[index]:
		if _plan[index][t] != ",":
			out[t] = true
	return out


func _mark(index: int, tile: Vector2i, ch: String) -> void:
	_plan[index][tile] = ch


func _free(layout: ShipLayout, index: int, tile: Vector2i) -> bool:
	return layout.rooms[index].largest_rect().has_point(tile) and not _plan[index].has(tile)


func _add_prop(layout: ShipLayout, index: int, type: StringName, tile: Vector2i, ch: String, footprint: Array[Vector2i], clearance := false) -> bool:
	for off in footprint:
		if not _free(layout, index, tile + off):
			return false
	if clearance:
		# Rule 8: furniture never touches another solid piece, so props cannot
		# pocket a tile between them (invariant 18).
		for off in footprint:
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n: Vector2i = tile + off + d
				if _plan[index].has(n) and _plan[index][n] != ",":
					return false
	for off in footprint:
		_mark(index, tile + off, ch)
	_pieces[index][tile] = ch
	if type == &"container" or type == &"locker":
		_extra_props[index].append({type = type, tile = tile})
	else:
		layout.rooms[index].props.append({type = type, tile = tile})
	return true


const ONE: Array[Vector2i] = [Vector2i.ZERO]
const CONSOLE_X: Array[Vector2i] = [Vector2i(-1, 0), Vector2i.ZERO, Vector2i(1, 0)]
const CRYOPOD_Y: Array[Vector2i] = [Vector2i(0, -1), Vector2i.ZERO, Vector2i(0, 1)]


## Rule 1: aprons. Every doorway keeps APRON_DEPTH tiles clear straight ahead.
func _rule_aprons(layout: ShipLayout, index: int, openings: Array[Opening]) -> void:
	for o in openings:
		for t in o.apron(APRON_DEPTH):
			if layout.rooms[index].largest_rect().has_point(t):
				_mark(index, t, ",")


## Rule 2: breaker. Past the apron, a crate stands BREAKER_DEPTH in and one tile
## to the side of the doorway's centre line, so someone entering has a piece of
## low cover to reach without being walled off. Sides alternate per doorway.
func _rule_breakers(layout: ShipLayout, index: int, openings: Array[Opening]) -> void:
	var side := 1
	for o in openings:
		var base := Vector2i(o.centre.round()) + o.normal * BREAKER_DEPTH
		var placed := false
		for attempt: int in [side, -side, 2 * side, -2 * side]:
			var tile: Vector2i = base + o.lateral * (BREAKER_SIDESTEP * attempt)
			if _add_prop(layout, index, &"crate", tile, "#", ONE):
				_breakers[index][tile] = true
				if density >= 2:
					# An L: one more crate deeper in, one further to the side,
					# so the breaker reads as a piece of furniture, not a pebble.
					for extra: Vector2i in [tile + o.normal, tile + o.lateral * signi(attempt)]:
						if _add_prop(layout, index, &"crate", extra, "#", ONE):
							_breakers[index][extra] = true
				placed = true
				break
		if not placed:
			push_warning("no breaker fits for a doorway in room %d" % index)
		side = -side


## Rule 3: lane cutter. Two doorways in the same Room that face each other with
## overlapping spans make a firing lane across the Room. A full-height prop on
## the midpoint breaks it without closing either doorway.
func _rule_lane_cutters(layout: ShipLayout, index: int, openings: Array[Opening]) -> void:
	for a in openings.size():
		for b in range(a + 1, openings.size()):
			var oa := openings[a]
			var ob := openings[b]
			if oa.normal != -ob.normal:
				continue
			var lat := oa.lateral
			var span_a := [_dot(oa.tiles[0], lat), _dot(oa.tiles[-1], lat)]
			var span_b := [_dot(ob.tiles[0], lat), _dot(ob.tiles[-1], lat)]
			if span_a[1] < span_b[0] or span_b[1] < span_a[0]:
				continue
			var mid := Vector2i(((oa.centre + ob.centre) / 2.0).round())
			var footprint := CRYOPOD_Y if oa.normal.x != 0 else ONE
			# A cryopod runs along z; across an x-facing lane that is exactly
			# the wall we want. Across a z-facing lane use a crate pair.
			if oa.normal.x != 0:
				if not _add_prop(layout, index, &"cryopod", mid, "P", footprint):
					_add_prop(layout, index, &"crate", mid, "#", ONE)
			else:
				_add_prop(layout, index, &"crate", mid, "#", ONE)
				_add_prop(layout, index, &"crate", mid + Vector2i.RIGHT, "#", ONE)


func _dot(t: Vector2i, axis: Vector2i) -> int:
	return t.x * axis.x + t.y * axis.y


## Rule 4: wall furniture. Consoles sit one tile off a long horizontal wall,
## never in an apron; low cover that also says "someone works here".
func _rule_wall_furniture(layout: ShipLayout, index: int, count: int) -> void:
	var rect := layout.rooms[index].largest_rect()
	var rows := [rect.position.y + 1, rect.end.y - 2]
	var placed := 0
	for attempt in 12:
		if placed >= count:
			return
		var y: int = rows[attempt % 2]
		var x := _rng.randi_range(rect.position.x + 2, rect.end.x - 3)
		if _add_prop(layout, index, &"console", Vector2i(x, y), "=", CONSOLE_X, true):
			placed += 1


## Rule 5: Containers hug the walls, farthest wall from the nearest doorway
## first, so the loot is at the back of the Room and the fight is on the way
## to it. Lockers (≥3 gold) are full height and stand flush; crates are 1.1 m.
func _rule_containers(layout: ShipLayout, index: int, openings: Array[Opening], sizes: Array) -> void:
	var rect := layout.rooms[index].largest_rect()
	var ring: Array[Vector2i] = []
	for x in range(rect.position.x, rect.end.x):
		ring.append(Vector2i(x, rect.position.y))
		ring.append(Vector2i(x, rect.end.y - 1))
	for y in range(rect.position.y + 1, rect.end.y - 1):
		ring.append(Vector2i(rect.position.x, y))
		ring.append(Vector2i(rect.end.x - 1, y))
	ring.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return _door_distance(p, openings) > _door_distance(q, openings))
	var cursor := 0
	for gold: int in sizes:
		var big: bool = gold >= 3
		while cursor < ring.size():
			var t: Vector2i = ring[cursor]
			cursor += 1
			# Keep crates in pairs-ish: skip a tile between placements.
			if _add_prop(layout, index, &"locker" if big else &"container", t, "L" if big else "$", ONE):
				cursor += 1
				break


func _door_distance(t: Vector2i, openings: Array[Opening]) -> float:
	var best := INF
	for o in openings:
		best = minf(best, Vector2(t).distance_to(o.centre))
	return best


## Rule 6: the Fight Core stays open. Count prop islands inside the inscribed
## 10×10 and warn if the rules above exceeded the budget, so the walk knows.
func _rule_core_budget(layout: ShipLayout, index: int) -> void:
	var rect := layout.rooms[index].largest_rect()
	if rect.size.x < 10 or rect.size.y < 10:
		return
	var core := Rect2i(rect.position + (rect.size - Vector2i(10, 10)) / 2, Vector2i(10, 10))
	var islands := 0
	var seen := {}
	for t in _plan[index]:
		if _plan[index][t] == "," or seen.has(t) or not core.has_point(t):
			continue
		islands += 1
		var stack: Array = [t]
		while stack:
			var c: Vector2i = stack.pop_back()
			if seen.has(c) or not _plan[index].has(c) or _plan[index][c] == ",":
				continue
			seen[c] = true
			for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				stack.append(c + d)
	if islands > CORE_ISLANDS:
		push_warning("room %d: %d prop islands inside the Fight Core (budget %d)" % [index, islands, CORE_ISLANDS])


## Rule 9: islands. Free-standing cover in the open floor, one per ~70 tiles
## at density 2 and ~35 at density 3, placed at least 3 tiles from any other
## solid piece and outside every apron, so the middle of a big Room is not a
## shooting gallery. Islands are crate pairs (a 2-tile block) so they read.
func _rule_islands(layout: ShipLayout, index: int) -> void:
	if density < 2:
		return
	var rect := layout.rooms[index].largest_rect()
	var want := rect.get_area() / (70 if density == 2 else 35)
	var placed := 0
	for attempt in 60:
		if placed >= want:
			return
		var t := Vector2i(_rng.randi_range(rect.position.x + 2, rect.end.x - 4),
				_rng.randi_range(rect.position.y + 2, rect.end.y - 3))
		var clear := true
		for dx in range(-2, 4):
			for dy in range(-2, 3):
				var n := t + Vector2i(dx, dy)
				if _plan[index].has(n) and _plan[index][n] != ",":
					clear = false
		if not clear:
			continue
		if _add_prop(layout, index, &"crate", t, "#", ONE):
			_add_prop(layout, index, &"crate", t + Vector2i.RIGHT, "#", ONE)
			placed += 1


func _furnish_room(layout: ShipLayout, index: int, consoles: int, containers: Array) -> void:
	var openings := _openings(layout, index)
	_rule_aprons(layout, index, openings)
	if not bare:
		_rule_breakers(layout, index, openings)
		_rule_lane_cutters(layout, index, openings)
		_rule_islands(layout, index)
	_rule_containers(layout, index, openings, containers)
	_rule_wall_furniture(layout, index, consoles)
	_rule_core_budget(layout, index)


## Corridor rule: alcove crates alternate sides every CORRIDOR_STAGGER tiles so
## no straight run is a full-length lane, and facing doorways across the
## corridor get a lane cutter like any Room.
func _furnish_corridor(layout: ShipLayout, index: int) -> void:
	var openings := _openings(layout, index)
	_rule_aprons(layout, index, openings)
	if bare:
		return
	_rule_lane_cutters(layout, index, openings)
	var rect := layout.rooms[index].largest_rect()
	var side := 0
	var y := rect.position.y + 2
	while y < rect.end.y - 1:
		var x := rect.position.x if side == 0 else rect.end.x - 1
		_add_prop(layout, index, &"crate", Vector2i(x, y), "#", ONE)
		if density >= 2:
			_add_prop(layout, index, &"crate", Vector2i(x, y + 1), "#", ONE)
		if density >= 3:
			var inward := 1 if side == 0 else -1
			_add_prop(layout, index, &"crate", Vector2i(x + inward, y), "#", ONE)
		side = 1 - side
		y += CORRIDOR_STAGGER if density < 2 else CORRIDOR_STAGGER - 1


## Rule 7: crew spawn behind cover, deepest cover first, on the far side of the
## piece from the nearest doorway. Never in an apron, never more than the cap.
func _place_crew_spawns(layout: ShipLayout, index: int) -> void:
	var room := layout.rooms[index]
	var openings := _openings(layout, index)
	var cover: Array[Vector2i] = []
	for t in _pieces[index]:
		if _pieces[index][t] in ["#", "=", "$", "L", "P"] and not _breakers[index].has(t):
			cover.append(t)
	cover.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		return _door_distance(p, openings) > _door_distance(q, openings))
	var used := {}
	for n in room.crew_count:
		var spot := Vector2i.ZERO
		var found := false
		for c in cover:
			if used.has(c):
				continue
			# A rect with no doorway of its own (a multi-rect Room's annex):
			# stand on the side of the cover away from the rect's centre.
			var away := c + (_nearest_opening(c, openings).normal if not openings.is_empty()
					else Vector2i((Vector2(c) - Vector2(room.largest_rect().get_center())).sign()).clamp(Vector2i(-1, -1), Vector2i(1, 1)))
			if _free(layout, index, away):
				spot = away
				used[c] = true
				found = true
				break
		if not found:
			# No cover left: stand in the far corner rather than the doorway.
			spot = room.largest_rect().end - Vector2i(2, 2)
		_mark(index, spot, "x")
		_spawns[index].append(spot)


func _nearest_opening(t: Vector2i, openings: Array[Opening]) -> Opening:
	var best: Opening = openings[0]
	var best_d := INF
	for o in openings:
		var d := Vector2(t).distance_to(o.centre)
		if d < best_d:
			best_d = d
			best = o
	return best


## Invariant 18 from the map: every floor tile reachable on foot from every
## doorway across prop-free tiles. Warn loudly if the rules walled anything off.
func _check_reachability(layout: ShipLayout, index: int) -> void:
	var rect := layout.rooms[index].largest_rect()
	var solid := _solid(index)
	for t in _spawns[index]:
		solid.erase(t)
	var openings := _openings(layout, index)
	if openings.is_empty():
		return
	var start := openings[0].tiles[0] + openings[0].normal
	var seen := {start: true}
	var stack: Array = [start]
	while stack:
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if rect.has_point(n) and not solid.has(n) and not seen.has(n):
				seen[n] = true
				stack.append(n)
	var walkable := rect.get_area() - solid.size()
	if seen.size() < walkable:
		push_warning("room %d: %d floor tiles unreachable behind props" % [index, walkable - seen.size()])


# ---------------------------------------------------------------------------
# Glue: things the real builder does not know about yet.
# ---------------------------------------------------------------------------

func _spawn_extras(main: Node3D, _layout: ShipLayout) -> void:
	var props: Node3D = main.ship.get_node("Props")
	for index in _extra_props:
		for p in _extra_props[index]:
			var scene := LOCKER_SCENE if p.type == &"locker" else CONTAINER_SCENE
			var node: Node3D = scene.instantiate()
			node.position = ShipBuilder3D.tile_to_world(p.tile)
			props.add_child(node)


func _place_crew(main: Node3D, _layout: ShipLayout) -> void:
	var counters := {}
	for crew in main.ship.get_node("Crew").get_children():
		var room: int = crew.home_room
		var n: int = counters.get(room, 0)
		counters[room] = n + 1
		if n < _spawns[room].size():
			crew.global_position = ShipBuilder3D.tile_to_world(_spawns[room][n])


func _print_plan(layout: ShipLayout) -> void:
	var bounds: Rect2i = layout.rooms[0].largest_rect()
	for r in layout.rooms:
		bounds = bounds.merge(r.largest_rect())
	bounds = bounds.grow(1)
	var chars := {}
	for i in layout.rooms.size():
		var rect := layout.rooms[i].largest_rect()
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				chars[Vector2i(x, y)] = "."
		for t in _plan[i]:
			chars[t] = _plan[i][t]
	for d in layout.doors:
		for t in d.tiles():
			chars[t] = "D"
	var lines := PackedStringArray()
	for y in range(bounds.position.y, bounds.end.y):
		var line := ""
		for x in range(bounds.position.x, bounds.end.x):
			line += chars.get(Vector2i(x, y), " ")
		lines.append(line)
	print("\n".join(lines))
