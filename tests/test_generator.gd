extends SceneTree
## Seeded harness for the ship generator: a fixed contiguous range of seeds
## per Class, swept at layout level. Every check reads the emitted ShipLayout
## and asserts what the ship IS, never how it was built. Every failure prints
## its seed and the ship's sentence; the first failing seed per Class is
## also dumped as ASCII.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_generator.gd
##
## Change the seed range only deliberately: it is the regression corpus.

const FIRST_SEED := 1
## The full sweep; `-- seeds=N` after the script narrows it for a quick run.
const SEEDS_PER_CLASS := 100
## Per-ship budget, so the pre-raid view can generate targets live.
const TIME_BUDGET_MS := 200.0

var failures: Array[String] = []
var checks := 0
var _ship_failures: Array[String] = []
var seeds_per_class := SEEDS_PER_CLASS


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds_per_class = maxi(int(arg.trim_prefix("seeds=")), 1)
	_ship_failures.clear()
	_check_data_driven()
	for f in _ship_failures:
		failures.append("flavour table: %s" % f)
	for ship_class in ShipGenerator.CLASSES:
		var dumped := false
		var slowest := 0.0
		var resizes := 0
		var most_resizes := 0
		var rerolls := 0
		var out_of_band := 0
		var armories := 0
		var armory_capable := 0
		var relaxed := 0
		var relaxed_twice := 0
		var bare_bridges := 0
		for seed in range(FIRST_SEED, FIRST_SEED + seeds_per_class):
			var started := Time.get_ticks_usec()
			var report := ShipGenerator.generate_report(ship_class, seed)
			var took := (Time.get_ticks_usec() - started) / 1000.0
			slowest = maxf(slowest, took)
			resizes += report.resizes
			most_resizes = maxi(most_resizes, report.resizes)
			rerolls += report.rerolls
			if not report.in_band:
				out_of_band += 1
			if _has_role(report.layout, &"armory"):
				armories += 1
			if _can_hold_armory(report.layout):
				armory_capable += 1
			if report.hatch_relaxed > 0:
				relaxed += 1
			if report.hatch_relaxed > 1:
				relaxed_twice += 1
			if _count_props(report.layout, &"bridge", &"console") == 0:
				bare_bridges += 1
			_ship_failures.clear()
			_check_ship(report, ship_class)
			_expect(took <= TIME_BUDGET_MS, "generation took %.0f ms, over the %.0f ms budget" % [took, TIME_BUDGET_MS])
			_check_deterministic(report, ship_class, seed)
			if not _ship_failures.is_empty():
				for f in _ship_failures:
					failures.append("%s seed %d: %s  [%s]" % [ship_class, seed, f, report.sentence])
				if not dumped:
					dumped = true
					print("--- first failing %s seed %d: %s" % [ship_class, seed, report.sentence])
					print(ShipDumper.ascii(report.layout))
					print(ShipDumper.listing(report.layout))
		print("%s: %d seeds, slowest %.0f ms, resizes mean %.2f max %d, archetype rerolls %d, out of band %d, armory rate %d%% (%d%% could hold one), hatches relaxed on %d (%d to half separation)" % [
				ship_class, seeds_per_class, slowest, float(resizes) / seeds_per_class, most_resizes, rerolls, out_of_band,
				armories * 100 / seeds_per_class, armory_capable * 100 / seeds_per_class, relaxed, relaxed_twice])
		# Sweep-level: the small-ship Armory rate, and how often Hatch placement
		# had to relax (small ships with one usable flank cannot help it).
		_ship_failures.clear()
		if ship_class == &"small":
			_expect(armories * 100 >= 25 * seeds_per_class and armories * 100 <= 45 * seeds_per_class,
					"small ships rolled an Armory %d%% of the time, want 25%% to 45%%" % (armories * 100 / seeds_per_class))
		var relax_ceiling := 40 if ship_class == &"small" else 5
		_expect(relaxed * 100 <= relax_ceiling * seeds_per_class,
				"hatches relaxed on %d%% of ships, ceiling %d%%" % [relaxed * 100 / seeds_per_class, relax_ceiling])
		# Flavour at sweep level: the Bridge bank fits on nearly every ship.
		_expect(bare_bridges * 100 <= 5 * seeds_per_class,
				"%d%% of bridges hold no console bank, ceiling 5%%" % (bare_bridges * 100 / seeds_per_class))
		for f in _ship_failures:
			failures.append("%s sweep: %s" % [ship_class, f])
	_report()
	quit(1 if failures.size() > 0 else 0)


func _check_ship(report: ShipGenerator.Report, ship_class: StringName) -> void:
	var layout := report.layout
	_expect(layout.gen_seed > 0 and layout.ship_class == ship_class, "layout does not carry its seed and Class")
	_expect(not layout.ship_name.is_empty(), "ship has no name")
	_expect(layout.rooms.size() >= 2, "ship has %d rooms" % layout.rooms.size())
	if layout.rooms.size() < 2:
		return
	_check_rooms(layout)
	_check_floor_ownership(layout)
	_check_doors(layout)
	_check_connectivity(layout)
	_check_asymmetry(layout)
	_check_hatches(layout, ship_class, report.hatch_relaxed)
	_check_roles(layout, ship_class)
	_check_budgets(layout, ship_class)
	_check_interiors(layout)
	_check_flavour(layout)
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
		_expect(TileShapes.components(room.tiles()).size() == 1, "room %d is not one connected floor" % i)
		_expect(room.meets_floor(), "room %d (%s, %d tiles, %s) fails the fightable floor" % [i, room.role, room.area(), room.bounds().size])
	# Two Rooms never share an edge: a wall tile always lies between them.
	var owner := {}
	for i in layout.rooms.size():
		for t: Vector2i in layout.rooms[i].tiles():
			owner[t] = i
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
	for i in layout.rooms.size():
		for t: Vector2i in layout.rooms[i].tiles():
			if owners.has(t):
				clashes += 1
			owners[t] = "room %d" % i
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
	_expect(owners.size() == layout.floor_tiles().size(), "floor_tiles() disagrees with the owners")


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
	var floors := layout.floor_tiles()
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
## every pair separated along the Hull and by at least two Rooms inside.
func _check_hatches(layout: ShipLayout, ship_class: StringName, relaxed: int) -> void:
	var band: Vector2i = HatchPlacer.HATCH_BAND[ship_class]
	var n := layout.hatches.size()
	_expect(n >= 2 and n <= 4 and n >= band.x and n <= band.y, "%d hatches, band is %s" % [n, band])
	if n == 0:
		return
	var wall_set := ShipGraph.walls(layout, ShipGraph.floor_without_hatches(layout))
	var out_set := ShipGraph.outside(ShipGraph.floor_without_hatches(layout), wall_set)
	var hull := ShipGraph.hull_tiles(layout)
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
		for j in range(i + 1, n):
			var a := layout.hatches[i]
			var b := layout.hatches[j]
			var along := ShipGraph.hull_distance(hull, a.tile, b.tile)
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
	var floors := layout.floor_tiles()
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
		var floors := room.tiles()
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
				var consoles := _count_props(layout, &"bridge", &"console")
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
				var consoles := _count_props(layout, &"engine", &"engine_console")
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
				_expect(_count_props(layout, &"medbay", &"cryopod") >= 1, "medbay %d has no cryopod" % i)
			&"quarters":
				_expect(_count_props(layout, &"quarters", &"cryopod") >= 2, "quarters %d has fewer than two bunks" % i)
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


## How many props of a type the Rooms of a Role hold.
func _count_props(layout: ShipLayout, role: StringName, type: StringName) -> int:
	var n := 0
	for room in layout.rooms:
		if room.role != role:
			continue
		for prop in room.props:
			if prop.type == type:
				n += 1
	return n


## The table is data: swapping the Bridge row for one with no consoles and
## no islands changes the furnished ship, and putting it back restores it.
func _check_data_driven() -> void:
	var layout := ShipGenerator.generate(&"medium", FIRST_SEED)
	var before := _fingerprint(layout)
	var table: Dictionary = RoleFlavour.table().duplicate(true)
	var bridge: Dictionary = table.roles.bridge
	bridge.consoles = [0, 0]
	bridge.islands = "none"
	bridge.light = [0.1, 0.2, 0.3]
	RoleFlavour.use(table)
	_expect(RoleFlavour.light(&"bridge").is_equal_approx(Color(0.1, 0.2, 0.3)), "swapped table does not tint the bridge")
	var swapped := ShipGenerator.generate(&"medium", FIRST_SEED)
	_expect(_count_props(swapped, &"bridge", &"console") == 0, "bridge still holds consoles with a row of none")
	_expect(_fingerprint(swapped) != before, "swapping the bridge row left the ship unchanged")
	RoleFlavour.reset()
	_expect(_fingerprint(ShipGenerator.generate(&"medium", FIRST_SEED)) == before, "restoring the table did not restore the ship")
	for role in [&"bridge", &"engine", &"shield", &"armory", &"cargo", &"medbay", &"quarters", &"corridor"]:
		_expect(RoleFlavour.table().roles.has(String(role)), "no flavour row for %s" % role)


## Whether some Room other than the Bridge, an Engine, a Corridor or a Hatch
## Room exists for an Armory to take.
func _can_hold_armory(layout: ShipLayout) -> bool:
	var hatch_rooms := {}
	for h in layout.hatches:
		hatch_rooms[h.room] = true
	for i in layout.rooms.size():
		if not ShipGraph.is_fixed_role(layout.rooms[i].role) and not hatch_rooms.has(i):
			return true
	return false


## Whether any Room carries the Role.
func _has_role(layout: ShipLayout, role: StringName) -> bool:
	for room in layout.rooms:
		if room.role == role:
			return true
	return false


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


## The same seed twice yields identical Rooms, Doors, Roles and name.
func _check_deterministic(report: ShipGenerator.Report, ship_class: StringName, seed: int) -> void:
	var again := ShipGenerator.generate_report(ship_class, seed)
	_expect(_fingerprint(report.layout) == _fingerprint(again.layout), "generating twice gave different ships")
	_expect(report.sentence == again.sentence, "generating twice gave different sentences")


func _fingerprint(layout: ShipLayout) -> String:
	var parts: Array[String] = [layout.ship_name, str(layout.richness)]
	for room in layout.rooms:
		parts.append("%s%s c%d l%d %s %s %s %s" % [room.role, room.rects, room.crew_count, room.loot_share, room.containers, room.props, room.crew_spawns, room.crew_facings])
	for door in layout.doors:
		parts.append("%d-%d@%s/%s/%d" % [door.room_a, door.room_b, door.tile, door.horizontal, door.width])
	for hatch in layout.hatches:
		parts.append("H%d@%s" % [hatch.room, hatch.tile])
	return "|".join(parts)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		_ship_failures.append(message)


func _report() -> void:
	if failures.is_empty():
		print("PASS  %d checks" % checks)
	else:
		for f in failures:
			print("FAIL  ", f)
		print("FAILED  %d of %d checks" % [failures.size(), checks])
