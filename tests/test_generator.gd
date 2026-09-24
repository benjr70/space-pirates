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
const SEEDS_PER_CLASS := 100
## Per-ship budget, so the pre-raid view can generate targets live.
const TIME_BUDGET_MS := 200.0

var failures: Array[String] = []
var checks := 0
var _ship_failures: Array[String] = []


func _initialize() -> void:
	for ship_class in ShipGenerator.CLASSES:
		var dumped := false
		var slowest := 0.0
		var resizes := 0
		var most_resizes := 0
		var rerolls := 0
		var out_of_band := 0
		for seed in range(FIRST_SEED, FIRST_SEED + SEEDS_PER_CLASS):
			var started := Time.get_ticks_usec()
			var report := ShipGenerator.generate_report(ship_class, seed)
			var took := (Time.get_ticks_usec() - started) / 1000.0
			slowest = maxf(slowest, took)
			resizes += report.resizes
			most_resizes = maxi(most_resizes, report.resizes)
			rerolls += report.rerolls
			if not report.in_band:
				out_of_band += 1
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
		print("%s: %d seeds, slowest %.0f ms, resizes mean %.2f max %d, archetype rerolls %d, out of band %d" % [
				ship_class, SEEDS_PER_CLASS, slowest, float(resizes) / SEEDS_PER_CLASS, most_resizes, rerolls, out_of_band])
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
	_check_roles(layout, ship_class)
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


## Every Room reachable from every other through Doors (Hatches come later).
func _check_connectivity(layout: ShipLayout) -> void:
	var adjacency := {}
	for i in layout.rooms.size():
		adjacency[i] = []
	for d in layout.doors:
		if d.room_a < 0 or d.room_b < 0:
			continue
		adjacency[d.room_a].append(d.room_b)
		adjacency[d.room_b].append(d.room_a)
	var seen := {0: true}
	var queue := [0]
	while not queue.is_empty():
		var room: int = queue.pop_front()
		for n in adjacency[room]:
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	_expect(seen.size() == layout.rooms.size(), "only %d of %d rooms reachable through doors" % [seen.size(), layout.rooms.size()])


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


## Counted Room count in the Class band; exactly one Bridge, fore of every
## Engine; at least one Engine, aft of the ship's midline; Roles in the set.
func _check_roles(layout: ShipLayout, ship_class: StringName) -> void:
	var band: Vector2i = ShipGenerator.ROOM_BAND[ship_class]
	var counted := 0
	var bridges: Array[int] = []
	var engines: Array[int] = []
	var floors := layout.floor_tiles()
	var box := TileShapes.bounds(floors)
	var midline := (box.position.y + box.end.y) / 2.0
	for i in layout.rooms.size():
		var role := layout.rooms[i].role
		_expect(role in [&"bridge", &"engine", &"corridor", &"cargo", &"quarters", &"medbay", &"shield", &"armory"],
				"room %d has role %s" % [i, role])
		if role != &"corridor":
			counted += 1
		if role == &"bridge":
			bridges.append(i)
		if role == &"engine":
			engines.append(i)
	_expect(counted >= band.x and counted <= band.y, "%d counted rooms, band is %s" % [counted, band])
	_expect(bridges.size() == 1, "%d bridges" % bridges.size())
	_expect(engines.size() >= 1, "no engine room")
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
		parts.append("%s%s" % [room.role, room.rects])
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
