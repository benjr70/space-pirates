class_name ShipInvariants
extends RefCounted
## Every invariant a generated [ShipLayout] must satisfy, read off the
## emitted ship and never off how it was built. The generator runs these
## on every ship it makes and rerolls a seed that fails; the harness runs
## them on every seed of the sweep with its own `expect`.
##
## The spec's clauses (#17, Testing Decisions) and where each is asserted:
##  1  Rooms pairwise disjoint, rects abut         [method _check_rooms]
##  2  every floor tile owned once                 [method _check_floor_ownership]
##  3  Fight Core, 140 to 260 tiles                [method _check_rooms]
##  4  Corridors 3 wide throughout                 [method _check_rooms] (meets_floor)
##  5  Doors join two Rooms across a wall, ≥ 2     [method _check_doors]
##  6  every Room reachable from every Hatch       [method _check_connectivity]
##  7  not mirror-symmetric                        [method _check_asymmetry]
##  8  2 to 4 Hatches, in the Class band           [method _check_hatches]
##  9  Hatch tiles are Hull, reachable, one Room   [method _check_hatches]
## 10  ≤ 1 Hatch per Room, none on fixed Roles,
##     exactly one Cargo Hatch Room                [method _check_hatches]
## 11  Hatch separation along the Hull and inside  [method _check_hatches]
## 12  counted Rooms in the Class band             [method _check_roles]
## 13  Bridge fore, Engines aft, multiplicity,
##     Armory deepest and never a Hatch Room       [method _check_roles]
## 14  Threat Budget and its floors, caps, empties [method _check_budgets]
## 15  Loot Budget, Containers per Room            [method _check_budgets]
## 16  crew spawns equal crew_count on free floor  [method _check_interiors]
## 17  no prop on or in front of a doorway         [method _check_interiors]
## 18  every floor tile reachable past props       [method _check_interiors]
## 19  no Lane across a Corridor                   [method check]
## 20  same seed, same ship                        the harness ([code]_check_deterministic[/code])
## 21  ≤ 200 ms per ship                           the harness
## 22  name non-empty and deterministic            [method _check_name] and the harness
## plus the Role flavour rows ([method _check_flavour]).

## Takes every check's verdict: `(ok: bool, message: String)`.
var _verdict: Callable


func _init(expect: Callable) -> void:
	_verdict = expect


func _expect(ok: bool, message: String) -> void:
	_verdict.call(ok, message)


## Every violated clause of [param layout] as a message, empty when the
## ship is valid.
static func violations(layout: ShipLayout, ship_class: StringName) -> Array[String]:
	var out: Array[String] = []
	var checker := ShipInvariants.new(func(ok: bool, message: String) -> void:
		if not ok:
			out.append(message))
	checker.check(layout, ship_class)
	return out


## Run every check on [param layout].
func check(layout: ShipLayout, ship_class: StringName) -> void:
	_expect(layout.ship_class == ship_class, "layout carries Class '%s', generated as '%s'" % [layout.ship_class, ship_class])
	_expect(layout.rooms.size() >= 2, "ship has %d rooms" % layout.rooms.size())
	if layout.rooms.size() < 2:
		return
	_check_rooms(layout)
	_check_floor_ownership(layout)
	_check_doors(layout)
	_check_connectivity(layout)
	_check_asymmetry(layout)
	_check_hatches(layout, ship_class)
	_check_roles(layout, ship_class)
	_check_budgets(layout, ship_class)
	_check_interiors(layout)
	_check_flavour(layout)
	_check_name(layout, ship_class)
	var lanes := DoorStitcher.lanes_across_corridors(layout)
	_expect(lanes.is_empty(), "lanes cross a corridor: %s" % ", ".join(lanes))

## Rooms are pairwise disjoint with a wall between them; a Room's rects abut
## into one open space; every Room meets the fightable floor.
func _check_rooms(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		var parts := room.shape()
		_expect(parts.size() >= 1, "room %d has no rects" % i)
		for a in parts.size():
			for b in range(a + 1, parts.size()):
				_expect(not parts[a].intersects(parts[b]), "room %d rects %s and %s overlap" % [i, parts[a], parts[b]])
		_expect(_rects_abut(parts), "room %d is not one connected floor" % i)
		_expect(room.meets_floor(), "room %d (%s, %d tiles, %s) fails the fightable floor" % [i, room.role, room.area(), room.bounds().size])
	# Two Rooms never share an edge: a wall tile always lies between them.
	var owner := _room_owner(layout)
	var flush := {}
	for t: Vector2i in owner:
		for side in TileShapes.SIDES:
			var other: int = owner.get(t + side, -1)
			if other != -1 and other != owner[t]:
				flush["%d/%d" % [mini(owner[t], other), maxi(owner[t], other)]] = true
	_expect(flush.is_empty(), "rooms share an edge with no wall between: %s" % ", ".join(flush.keys()))


## Every floor tile belongs to exactly one Room, Door or Hatch.
func _check_floor_ownership(layout: ShipLayout) -> void:
	var owners := {}
	var clashes := 0
	var room_tiles := 0
	for i in layout.rooms.size():
		room_tiles += layout.rooms[i].area()
	owners = _room_owner(layout)
	# Two Rooms on one tile leave fewer owners than tiles.
	clashes += room_tiles - owners.size()
	for i in layout.doors.size():
		for t in layout.doors[i].tiles():
			if owners.has(t):
				clashes += 1
			owners[t] = "door %d" % i
	for i in layout.hatches.size():
		for t in layout.hatches[i].tiles():
			if owners.has(t):
				clashes += 1
			owners[t] = "hatch %d" % i
	_expect(clashes == 0, "%d floor tiles have more than one owner" % clashes)
	_expect(owners.size() == _floors(layout).size(), "floor_tiles() disagrees with the owners")


## Whether rects form one open space: every rect reachable from the first
## through rects that share an edge of at least one tile (a corner touch is
## not a Seam).
static func _rects_abut(parts: Array[Rect2i]) -> bool:
	var seen := {0: true}
	var stack: Array[int] = [0]
	while not stack.is_empty():
		var a: Rect2i = parts[stack.pop_back()]
		for k in parts.size():
			if seen.has(k):
				continue
			var b: Rect2i = parts[k]
			var along_x := (a.end.x == b.position.x or b.end.x == a.position.x) \
					and mini(a.end.y, b.end.y) - maxi(a.position.y, b.position.y) >= 1
			var along_y := (a.end.y == b.position.y or b.end.y == a.position.y) \
					and mini(a.end.x, b.end.x) - maxi(a.position.x, b.position.x) >= 1
			if along_x or along_y:
				seen[k] = true
				stack.append(k)
	return seen.size() == parts.size()


## Per-ship readings built once and shared by the checks: each Room's
## tiles, the ship's floor, and which Room owns every floor tile.
var _cached_for: ShipLayout
var _room_tiles: Array[Dictionary] = []
var _floor := {}
var _owner := {}


func _cache(layout: ShipLayout) -> void:
	if _cached_for == layout:
		return
	_cached_for = layout
	_room_tiles.clear()
	_owner = {}
	for i in layout.rooms.size():
		var tiles := layout.rooms[i].tiles()
		_room_tiles.append(tiles)
		for t: Vector2i in tiles:
			_owner[t] = i
	_floor = _owner.duplicate()
	for door in layout.doors:
		for t in door.tiles():
			_floor[t] = true
	for hatch in layout.hatches:
		for t in hatch.tiles():
			_floor[t] = true


## Floor tiles of Room [param i]: {tile: true}.
func _tiles(layout: ShipLayout, i: int) -> Dictionary:
	_cache(layout)
	return _room_tiles[i]


## Every floor tile of the ship, Doors and Hatches included.
func _floors(layout: ShipLayout) -> Dictionary:
	_cache(layout)
	return _floor


## Which Room owns every floor tile: {tile: room index}.
func _room_owner(layout: ShipLayout) -> Dictionary:
	_cache(layout)
	return _owner


## Every Door joins exactly two distinct Rooms across a shared wall, is at
## least two wide, and every tile of it has those two Rooms either side.
func _check_doors(layout: ShipLayout) -> void:
	_expect(layout.doors.size() >= layout.rooms.size() - 1, "only %d doors for %d rooms" % [layout.doors.size(), layout.rooms.size()])
	for i in layout.doors.size():
		var d := layout.doors[i]
		var ok := d.room_a >= 0 and d.room_a < layout.rooms.size() \
				and d.room_b >= 0 and d.room_b < layout.rooms.size() and d.room_a != d.room_b
		_expect(ok, "door %d joins rooms %d and %d" % [i, d.room_a, d.room_b])
		_expect(d.width >= 2, "door %d is %d wide" % [i, d.width])
		if not ok:
			continue
		var across := Vector2i(0, 1) if d.horizontal else Vector2i(1, 0)
		for t in d.tiles():
			var sides := [layout.room_at(t - across), layout.room_at(t + across)]
			_expect((sides[0] == d.room_a and sides[1] == d.room_b) or (sides[0] == d.room_b and sides[1] == d.room_a),
					"door %d tile %s does not sit between rooms %d and %d" % [i, t, d.room_a, d.room_b])


## Every Room reachable from every Hatch Room through Doors.
func _check_connectivity(layout: ShipLayout) -> void:
	var adjacency := {}
	for i in layout.rooms.size():
		adjacency[i] = []
	for d in layout.doors:
		if d.room_a < 0 or d.room_b < 0:
			continue
		adjacency[d.room_a].append(d.room_b)
		adjacency[d.room_b].append(d.room_a)
	var starts: Array[int] = [0]
	for h in layout.hatches:
		starts.append(h.room)
	for start in starts:
		var seen := {start: true}
		var queue := [start]
		while not queue.is_empty():
			var room: int = queue.pop_front()
			for n in adjacency[room]:
				if not seen.has(n):
					seen[n] = true
					queue.append(n)
		_expect(seen.size() == layout.rooms.size(), "only %d of %d rooms reachable from room %d through doors" % [seen.size(), layout.rooms.size(), start])


## The floor is not mirror-symmetric about the fore-aft axis.
func _check_asymmetry(layout: ShipLayout) -> void:
	var floors := _floors(layout)
	var box := TileShapes.bounds(floors)
	var mirrored := {}
	for t: Vector2i in floors:
		mirrored[Vector2i(box.position.x + box.end.x - 1 - t.x, t.y)] = true
	var same := mirrored.size() == floors.size()
	if same:
		for t: Vector2i in floors:
			if not mirrored.has(t):
				same = false
				break
	_expect(not same, "floor is mirror-symmetric about the fore-aft axis")


## Hatches: count in the Class band, each a two-wide gap in Hull reachable
## from outside opening into exactly one Room, at most one per Room, none on
## the Bridge, an Engine or a Corridor, exactly one Hatch Room a Cargo, and
## every pair separated along the Hull and by at least two Rooms inside,
## at the relaxation level the ship records ([member ShipLayout.hatch_relaxation]).
func _check_hatches(layout: ShipLayout, ship_class: StringName) -> void:
	var relaxed := layout.hatch_relaxation
	var band: Vector2i = HatchPlacer.HATCH_BAND[ship_class]
	var n := layout.hatches.size()
	_expect(n >= 2 and n <= 4 and n >= band.x and n <= band.y, "%d hatches, band is %s" % [n, band])
	if n == 0:
		return
	var floors := ShipGraph.floor_without_hatches(layout)
	var wall_set := ShipGraph.walls(layout, floors)
	var out_set := ShipGraph.outside(floors, wall_set)
	var hull := ShipGraph.hull_from(wall_set, out_set)
	var rooms_with := {}
	var cargo_hatches := 0
	for h in layout.hatches:
		_expect(h.width == 2, "hatch at %s is %d wide" % [h.tile, h.width])
		_expect(h.room >= 0 and h.room < layout.rooms.size(), "hatch at %s has room %d" % [h.tile, h.room])
		if h.room < 0 or h.room >= layout.rooms.size():
			continue
		var room := layout.rooms[h.room]
		_expect(not ShipGraph.is_fixed_role(room.role), "hatch at %s opens into the %s" % [h.tile, room.role])
		_expect(not rooms_with.has(h.room), "room %d holds two hatches" % h.room)
		rooms_with[h.room] = true
		if room.role == &"cargo":
			cargo_hatches += 1
		var step := h.inward(room)
		_expect(step != Vector2i.ZERO, "hatch at %s does not face room %d" % [h.tile, h.room])
		for t in h.tiles():
			_expect(hull.has(t), "hatch tile %s is not a hull tile" % t)
			_expect(room.has_tile(t + step) and out_set.has(t - step),
					"hatch tile %s does not run from outside into room %d" % [t, h.room])
			var touching := {}
			for side in TileShapes.SIDES:
				var r := layout.room_at(t + side)
				if r != -1:
					touching[r] = true
			_expect(touching.size() == 1 and touching.has(h.room), "hatch tile %s touches rooms %s" % [t, touching.keys()])
	_expect(cargo_hatches == 1, "%d hatch rooms are cargo, want exactly one" % cargo_hatches)
	# The separation rules, at the relaxation level the placer had to reach:
	# strict, then without the Flow Distance floor, then half the Hull separation.
	var separation := HatchPlacer.separation(hull.size(), n, relaxed)
	var adjacency := ShipGraph.adjacency(layout)
	for i in n:
		var along_hull := ShipGraph.hull_distances(hull, layout.hatches[i].tile)
		for j in range(i + 1, n):
			var a := layout.hatches[i]
			var b := layout.hatches[j]
			var along: int = along_hull.get(b.tile, -1)
			_expect(along >= separation, "hatches %d and %d are %d hull tiles apart, want %.0f" % [i, j, along, separation])
			if relaxed >= 1:
				continue
			var dist := ShipGraph.distances(layout, [a.room], adjacency)
			_expect(dist[b.room] < 0 or dist[b.room] >= HatchPlacer.FLOW_FLOOR,
					"hatch rooms %d and %d are %d doors apart" % [a.room, b.room, dist[b.room]])


## Counted Room count in the Class band; exactly one Bridge, fore of every
## Engine; at least one Engine, aft of the ship's midline; every Role count
## inside the multiplicity table; no Armory in a Hatch Room; the Armory the
## deepest Room by Flow Distance.
func _check_roles(layout: ShipLayout, ship_class: StringName) -> void:
	var band: Vector2i = ShipGenerator.ROOM_BAND[ship_class]
	var counted := 0
	var bridges: Array[int] = []
	var engines: Array[int] = []
	var floors := _floors(layout)
	var box := TileShapes.bounds(floors)
	var midline := (box.position.y + box.end.y) / 2.0
	var tally := {}
	for i in layout.rooms.size():
		var role := layout.rooms[i].role
		_expect(role in [&"bridge", &"engine", &"corridor", &"cargo", &"quarters", &"medbay", &"shield", &"armory"],
				"room %d has role %s" % [i, role])
		if role != &"corridor":
			counted += 1
			tally[role] = tally.get(role, 0) + 1
		if role == &"bridge":
			bridges.append(i)
		if role == &"engine":
			engines.append(i)
	_expect(counted >= band.x and counted <= band.y, "%d counted rooms, band is %s" % [counted, band])
	_expect(bridges.size() == 1, "%d bridges" % bridges.size())
	_expect(engines.size() >= 1, "no engine room")
	var ranges: Dictionary = RoleAssigner.RANGES[ship_class]
	for role in ranges:
		var r: Vector2i = ranges[role]
		var have: int = tally.get(role, 0)
		_expect(have >= r.x and have <= r.y, "%d %s rooms, table allows %d to %d" % [have, role, r.x, r.y])
	var hatch_rooms := {}
	for h in layout.hatches:
		hatch_rooms[h.room] = true
	# The deepest Room an Armory may take: not the Bridge, an Engine, a
	# Corridor or a Hatch Room.
	var flow := ShipGraph.flow_distances(layout)
	var deepest := 0
	for i in layout.rooms.size():
		if not ShipGraph.is_fixed_role(layout.rooms[i].role) and not hatch_rooms.has(i):
			deepest = maxi(deepest, flow[i])
	for i in layout.rooms.size():
		if layout.rooms[i].role != &"armory":
			continue
		_expect(not hatch_rooms.has(i), "armory room %d holds a hatch" % i)
	var armory_flow := -1
	for i in layout.rooms.size():
		if layout.rooms[i].role == &"armory":
			armory_flow = maxi(armory_flow, flow[i])
	if armory_flow >= 0:
		_expect(armory_flow == deepest, "deepest armory is %d doors in, the deepest room is %d" % [armory_flow, deepest])
	if bridges.size() != 1:
		return
	var bridge_y := layout.rooms[bridges[0]].center_tile().y
	for e in engines:
		var engine_y := layout.rooms[e].center_tile().y
		_expect(engine_y > bridge_y, "engine room %d is not aft of the bridge" % e)
		_expect(engine_y >= midline, "engine room %d sits fore of the midline" % e)
	# A ring Skeleton puts the Bridge at its core, wrapped in Corridor; every
	# other Skeleton puts it at the fore end.
	if not _is_ring_core(layout, bridges[0]):
		_expect(bridge_y <= midline, "bridge sits aft of the midline")
	# On a spine or ring the Bridge and an Engine hang directly off the Corridor.
	var corridors: Array[int] = []
	for i in layout.rooms.size():
		if layout.rooms[i].role == &"corridor":
			corridors.append(i)
	if corridors.is_empty():
		return
	_expect(_opens_onto(layout, bridges[0], corridors), "bridge has no door onto the corridor")
	var engine_on_corridor := false
	for e in engines:
		if _opens_onto(layout, e, corridors):
			engine_on_corridor = true
	_expect(engine_on_corridor, "no engine room has a door onto the corridor")


## Threat: the crew sum to a Budget in the Class band, no Room over its cap,
## the Bridge and every Armory at their floors when the Budget allows, at
## most a third of counted Rooms empty, Hatch Rooms at half weight (a Hatch
## Room never out-crews the same Role without a Hatch by more than one).
## Loot: the Shares sum to a Budget in band, every Armory at least 3 and
## every Cargo at least 1, each Room's Containers sum to its Share with at
## most 6, Corridors hold none. Richness moves both Budgets the same way.
func _check_budgets(layout: ShipLayout, ship_class: StringName) -> void:
	var counted: Array[int] = []
	var crew := 0
	var loot := 0
	var empties := 0
	var hatch_rooms := {}
	for h in layout.hatches:
		hatch_rooms[h.room] = true
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		crew += room.crew_count
		loot += room.loot_share
		_expect(room.crew_count >= 0 and room.loot_share >= 0, "room %d has negative shares" % i)
		var cap := Budgets.CREW_CAP_BIG if room.area() >= Budgets.BIG_ROOM else Budgets.CREW_CAP
		_expect(room.crew_count <= cap, "room %d (%s) holds %d crew, cap %d" % [i, room.role, room.crew_count, cap])
		var gold := 0
		for g in room.containers:
			gold += g
			_expect(g > 0, "room %d has an empty container" % i)
		_expect(gold == room.loot_share, "room %d containers hold %d gold for a share of %d" % [i, gold, room.loot_share])
		_expect(room.containers.size() <= Budgets.MAX_CONTAINERS, "room %d holds %d containers" % [i, room.containers.size()])
		var size: Vector2i = Budgets.CONTAINER_SIZE.get(room.role, Vector2i(1, 1))
		for g in room.containers:
			_expect(g >= size.x and (g <= size.y or room.containers.size() == Budgets.MAX_CONTAINERS),
					"room %d (%s) has a %d-gold container outside %s" % [i, room.role, g, size])
		if room.role == &"corridor":
			_expect(room.containers.is_empty() and room.loot_share == 0, "corridor %d holds loot" % i)
			continue
		counted.append(i)
		if room.crew_count == 0:
			empties += 1
	var threat_band: Vector2i = Budgets.THREAT_BAND[ship_class]
	var loot_band: Vector2i = Budgets.LOOT_BAND[ship_class]
	_expect(crew >= threat_band.x and crew <= threat_band.y, "crew total %d, band %s" % [crew, threat_band])
	_expect(loot >= loot_band.x and loot <= loot_band.y, "loot total %d, band %s" % [loot, loot_band])
	_expect(crew == Budgets.threat_total(ship_class, counted.size(), layout.richness),
			"crew total %d is not the Threat Budget for richness %.2f" % [crew, layout.richness])
	_expect(loot == Budgets.loot_total(ship_class, counted.size(), layout.richness),
			"loot total %d is not the Loot Budget for richness %.2f" % [loot, layout.richness])
	_expect(empties * 3 <= counted.size(), "%d of %d counted rooms are empty" % [empties, counted.size()])
	# Hatch Rooms weigh half: one never out-crews a Room of the same Role
	# without a Hatch by more than a body.
	for i in counted:
		if not hatch_rooms.has(i):
			continue
		for j in counted:
			if hatch_rooms.has(j) or layout.rooms[j].role != layout.rooms[i].role:
				continue
			_expect(layout.rooms[i].crew_count <= layout.rooms[j].crew_count + 1,
					"hatch room %d holds %d crew, room %d of the same role %d" % [i, layout.rooms[i].crew_count, j, layout.rooms[j].crew_count])
	for i in counted:
		var room := layout.rooms[i]
		if room.role == &"bridge":
			_expect(room.crew_count >= Budgets.BRIDGE_FLOOR, "bridge holds %d crew" % room.crew_count)
		if room.role == &"armory":
			_expect(room.crew_count >= Budgets.ARMORY_FLOOR, "armory %d holds %d crew" % [i, room.crew_count])
			_expect(room.loot_share >= Budgets.ARMORY_LOOT_FLOOR, "armory %d holds %d gold" % [i, room.loot_share])
		if room.role == &"cargo":
			_expect(room.loot_share >= Budgets.CARGO_LOOT_FLOOR, "cargo %d holds %d gold" % [i, room.loot_share])
	# Richness: poorer and richer rolls of this ship move both Budgets together.
	var poorer_threat := Budgets.threat_total(ship_class, counted.size(), 0.0)
	var richer_threat := Budgets.threat_total(ship_class, counted.size(), 1.0)
	var poorer_loot := Budgets.loot_total(ship_class, counted.size(), 0.0)
	var richer_loot := Budgets.loot_total(ship_class, counted.size(), 1.0)
	_expect(richer_threat >= poorer_threat and richer_loot >= poorer_loot
			and crew >= poorer_threat and crew <= richer_threat and loot >= poorer_loot and loot <= richer_loot,
			"richness does not move both budgets the same way")


## Interiors: every prop on its Room's floor, none on a Door or Hatch tile
## or the tile in front on either side; every floor tile reachable from every
## doorway across prop-free tiles, per Room across all its rects; crew spawn
## points equal crew_count, distinct, on prop-free floor, never beside a
## Breaker; Container gold in a Room sums to its Loot Share; a Breaker
## crate stands three tiles in from every doorway that has room for one.
func _check_interiors(layout: ShipLayout) -> void:
	var front := {}
	for d in layout.doors:
		var across := Vector2i.DOWN if d.horizontal else Vector2i.RIGHT
		for t in d.tiles():
			front[t] = true
			front[t + across] = true
			front[t - across] = true
	for h in layout.hatches:
		var across := Vector2i.DOWN if h.horizontal else Vector2i.RIGHT
		for t in h.tiles():
			front[t] = true
			front[t + across] = true
			front[t - across] = true
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		var floors := _tiles(layout, i)
		var solid := {}
		var breakers := {}
		var gold := 0
		for prop in room.props:
			for off in Interiors.footprint(prop.type, prop.get("rotated", false)):
				var t: Vector2i = prop.tile + off
				_expect(floors.has(t), "room %d prop %s at %s is off its floor" % [i, prop.type, t])
				_expect(not front.has(t), "room %d prop %s at %s blocks a doorway" % [i, prop.type, t])
				_expect(not solid.has(t), "room %d has two props on %s" % [i, t])
				solid[t] = true
				if prop.get("breaker", false):
					breakers[t] = true
			if prop.has("gold"):
				gold += prop.gold
				_expect(prop.gold > 0, "room %d has a container with no gold" % i)
		_expect(gold == room.loot_share, "room %d containers hold %d gold for a share of %d" % [i, gold, room.loot_share])
		var openings := Interiors.openings(layout, i)
		# Reachability from every doorway across prop-free tiles.
		var starts: Array[Vector2i] = []
		for o in openings:
			var t: Vector2i = o.tiles[0] + o.normal
			_expect(floors.has(t) and not solid.has(t), "room %d doorway at %s opens onto a prop or a wall" % [i, o.tiles[0]])
			if floors.has(t) and not solid.has(t):
				starts.append(t)
		if not starts.is_empty():
			var seen := {starts[0]: true}
			var stack: Array[Vector2i] = [starts[0]]
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				for side in TileShapes.SIDES:
					var n := c + side
					if floors.has(n) and not solid.has(n) and not seen.has(n):
						seen[n] = true
						stack.append(n)
			var walkable := floors.size() - solid.size()
			_expect(seen.size() == walkable, "room %d: %d floor tiles unreachable behind props" % [i, walkable - seen.size()])
			for s in starts:
				_expect(seen.has(s), "room %d doorway at %s cannot reach the rest of the room" % [i, s])
		# Crew spawns.
		_expect(room.crew_spawns.size() == room.crew_count,
				"room %d has %d spawn points for %d crew" % [i, room.crew_spawns.size(), room.crew_count])
		var distinct := {}
		for t in room.crew_spawns:
			_expect(floors.has(t) and not solid.has(t), "room %d crew spawn %s is not on prop-free floor" % [i, t])
			_expect(not distinct.has(t), "room %d spawns two crew on %s" % [i, t])
			distinct[t] = true
			for side in TileShapes.SIDES:
				_expect(not breakers.has(t + side), "room %d crew stand behind a breaker at %s" % [i, t])
		# Breakers three tiles in from doorways of non-corridor Rooms, wherever
		# a tile there is floor outside every doorway's Apron with floor either
		# side of it, so a crate leaves a way past (a one-tile passage cannot).
		if room.role == &"corridor":
			continue
		var aprons := {}
		for o in openings:
			for t in o.apron(Interiors.APRON_DEPTH):
				aprons[t] = true
		for o in openings:
			var base := Vector2i(o.centre.round()) + o.normal * Interiors.BREAKER_DEPTH
			var fits := false
			var has := false
			for k: int in [-3, -2, -1, 1, 2, 3]:
				var t := base + o.lateral * k
				if floors.has(t) and not aprons.has(t) and floors.has(t + o.lateral) and floors.has(t - o.lateral):
					fits = true
				if breakers.has(t):
					has = true
			if fits:
				_expect(has, "room %d doorway at %s has no breaker crate three tiles in" % [i, o.tiles[0]])


## Role flavour, read from the table: Containers take the Role's kind;
## Bridge crew stand at the console bank one tile off the fore wall facing
## aft; Engine crew stand behind the engine consoles at the aft wall; Shield
## crew ring the generator; Medbay and Quarters carry cryopods; every crew
## spawn has a facing entry.
func _check_flavour(layout: ShipLayout) -> void:
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		_expect(room.crew_facings.size() == room.crew_spawns.size(),
				"room %d has %d facings for %d spawns" % [i, room.crew_facings.size(), room.crew_spawns.size()])
		var row := RoleFlavour.row(room.role)
		var kind := StringName(row.container)
		for prop in room.props:
			if prop.has("gold") and kind != &"none":
				_expect(prop.type == kind, "room %d (%s) holds a %s container, table says %s" % [i, room.role, prop.type, kind])
		var solid := {}
		for prop in room.props:
			for off in Interiors.footprint(prop.type, prop.get("rotated", false)):
				solid[prop.tile + off] = prop.type
		match room.role:
			&"bridge":
				var consoles := count_props(layout, &"bridge", &"console")
				var at_station := 0
				for k in mini(room.crew_spawns.size(), consoles):
					var t: Vector2i = room.crew_spawns[k]
					if solid.get(t + Vector2i.DOWN, &"") == &"console" and room.crew_facings[k] == Vector2i.DOWN:
						at_station += 1
				_expect(at_station == mini(room.crew_spawns.size(), consoles),
						"bridge: %d of %d crew stand at a fore-wall console facing aft" % [at_station, mini(room.crew_spawns.size(), consoles)])
				# The bank stands one tile off the fore wall; only a wall too
				# ragged for any console lets them fall back to the long walls.
				var banked := 0
				for prop in room.props:
					if prop.type == &"console" and room.has_tile(prop.tile + Vector2i.UP) \
							and not room.has_tile(prop.tile + Vector2i.UP * 2):
						banked += 1
				_expect(banked == consoles or banked == 0, "bridge: %d of %d consoles stand off the fore wall" % [banked, consoles])
			&"engine":
				var consoles := count_props(layout, &"engine", &"engine_console")
				_expect(consoles >= 1, "engine room %d has no engine console" % i)
				var at_station := 0
				var behind := 0
				for k in room.crew_spawns.size():
					var t: Vector2i = room.crew_spawns[k]
					if solid.get(t + Vector2i.UP, &"") == &"engine_console" and room.crew_facings[k] == Vector2i.UP:
						at_station += 1
				for prop in room.props:
					if prop.type == &"engine_console" and room.has_tile(prop.tile + Vector2i.DOWN) \
							and not room.has_tile(prop.tile + Vector2i.DOWN * 2):
						behind += 1
				if behind > 0:
					_expect(at_station >= mini(room.crew_spawns.size(), 1),
							"engine room %d: no crew stands behind an aft-wall engine console" % i)
			&"shield":
				var generator := Vector2i.ZERO
				var generators := 0
				for prop in room.props:
					if prop.type == &"generator":
						generators += 1
						generator = prop.tile
				_expect(generators == 1, "shield room %d holds %d generators" % [i, generators])
				if generators == 1:
					var ringed := 0
					for k in room.crew_spawns.size():
						var t: Vector2i = room.crew_spawns[k]
						var d := t - generator
						if maxi(absi(d.x), absi(d.y) - 1) == 1 and room.crew_facings[k] != Vector2i.ZERO:
							ringed += 1
					_expect(ringed == room.crew_spawns.size(), "shield room %d: %d of %d crew ring the generator" % [i, ringed, room.crew_spawns.size()])
			&"medbay":
				_expect(count_props(layout, &"medbay", &"cryopod") >= 1, "medbay %d has no cryopod" % i)
			&"quarters":
				_expect(count_props(layout, &"quarters", &"cryopod") >= 2, "quarters %d has fewer than two bunks" % i)
			&"cargo":
				var containers := 0
				var paired := 0
				for prop in room.props:
					if not prop.has("gold"):
						continue
					containers += 1
					for side in TileShapes.SIDES:
						if solid.get(prop.tile + side, &"") == prop.type:
							paired += 1
							break
				if containers >= 2:
					_expect(paired >= 2, "cargo %d: %d containers but none run in pairs" % [i, containers])


## Words a name may never carry beyond the Roles themselves: a name never
## says what Rooms a ship rolled.
const ROLE_SYNONYMS: Array[String] = ["armoury", "hold", "vault", "barracks", "infirmary", "hospital",
		"reactor", "warehouse", "cockpit", "helm", "arsenal", "magazine"]


## Every Role name plus [constant ROLE_SYNONYMS], lower case.
func _role_words() -> Array[String]:
	var out: Array[String] = ["corridor"]
	for role: StringName in RoleAssigner.RANGES[&"large"]:
		out.append(String(role).to_lower())
	out.append_array(ROLE_SYNONYMS)
	return out


## The name: non-empty, never starts with "The", equals what the namer rolls
## for the seed and archetype, carries no Role word, carries an archetype's
## or a Class's words only on a ship of that archetype or Class, and
## displays with "The" only when unprefixed.
func _check_name(layout: ShipLayout, ship_class: StringName) -> void:
	var name := layout.ship_name
	_expect(not name.is_empty(), "ship has no name")
	_expect(not name.begins_with("The "), "name '%s' stores the article" % name)
	_expect(layout.archetype in HullGrammar.ARCHETYPES, "layout carries archetype '%s'" % layout.archetype)
	var roll := ShipNamer.roll(ship_class, layout.gen_seed, layout.archetype)
	_expect(name == roll.name, "name '%s' is not the namer's '%s' for this seed" % [name, roll.name])
	if roll.prefix != "":
		_expect(name.begins_with(roll.prefix + " "), "prefixed name '%s' does not start with %s" % [name, roll.prefix])
		_expect(layout.display_name() == name, "prefixed name displays as '%s'" % layout.display_name())
	else:
		_expect(layout.display_name() == "The " + name, "unprefixed name displays as '%s'" % layout.display_name())
	var words: Array[String] = []
	for w in name.split(" "):
		words.append(w.trim_suffix("'s").to_lower())
	var role_words := _role_words()
	for w in words:
		_expect(not w in role_words, "name '%s' carries the Role word '%s'" % [name, w])
	for arch in HullGrammar.ARCHETYPES:
		if arch == layout.archetype:
			continue
		for w: String in _flat(ShipNamer.hint_words(ShipNamer.table().archetypes, arch)):
			_expect(not w.to_lower() in words, "%s ship named '%s' carries the %s word '%s'" % [layout.archetype, name, arch, w])
	for cls in ShipGenerator.CLASSES:
		if cls == ship_class:
			continue
		for w: String in _flat(ShipNamer.hint_words(ShipNamer.table().classes, cls)):
			_expect(not w.to_lower() in words, "%s ship named '%s' carries the %s word '%s'" % [ship_class, name, cls, w])


## Every word of a {adjectives: [...], nouns: [...]} entry.
func _flat(entry: Dictionary) -> Array:
	var out := []
	for key in entry:
		out.append_array(entry[key])
	return out


## How many props of a type the Rooms of a Role hold.
static func count_props(layout: ShipLayout, role: StringName, type: StringName) -> int:
	var n := 0
	for room in layout.rooms:
		if room.role != role:
			continue
		for prop in room.props:
			if prop.type == type:
				n += 1
	return n


## Whether a Room has a Door onto any of the given Rooms.
func _opens_onto(layout: ShipLayout, room: int, targets: Array[int]) -> bool:
	for d in layout.doors:
		if (d.room_a == room and d.room_b in targets) or (d.room_b == room and d.room_a in targets):
			return true
	return false


## Whether a Room is a ring's core: every Door of it opens onto a Corridor
## and Corridor floor lies both fore and aft of it.
func _is_ring_core(layout: ShipLayout, room: int) -> bool:
	var doors := 0
	for d in layout.doors:
		if d.room_a != room and d.room_b != room:
			continue
		doors += 1
		var other := d.room_b if d.room_a == room else d.room_a
		if layout.rooms[other].role != &"corridor":
			return false
	if doors == 0:
		return false
	var box := layout.rooms[room].bounds()
	var fore := false
	var aft := false
	for x in range(box.position.x, box.end.x):
		var r := layout.room_at(Vector2i(x, box.position.y - 2))
		if r != -1 and layout.rooms[r].role == &"corridor":
			fore = true
		r = layout.room_at(Vector2i(x, box.end.y + 1))
		if r != -1 and layout.rooms[r].role == &"corridor":
			aft = true
	return fore and aft
