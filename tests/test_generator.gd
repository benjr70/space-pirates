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
## Budget per generation attempt, so the pre-raid view can generate targets
## live. A seed that rerolls generates again from scratch, so a rerolled
## ship may take the budget once per attempt.
const TIME_BUDGET_MS := 200.0

var failures: Array[String] = []
var checks := 0
var _ship_failures: Array[String] = []
var seeds_per_class := SEEDS_PER_CLASS
## Name tallies over the whole sweep: prefixed ships and ships per shape.
var _prefixed := 0
var _shapes := {}
var _named := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds_per_class = maxi(int(arg.trim_prefix("seeds=")), 1)
	_ship_failures.clear()
	_check_data_driven()
	for f in _ship_failures:
		failures.append("flavour table: %s" % f)
	_ship_failures.clear()
	_check_harness_bites()
	for f in _ship_failures:
		failures.append("harness self-test on medium seed %d: %s" % [FIRST_SEED, f])
	for ship_class in ShipGenerator.CLASSES:
		var sweep := Sweep.new()
		var dumped := false
		for seed in range(FIRST_SEED, FIRST_SEED + seeds_per_class):
			var started := Time.get_ticks_usec()
			var report := ShipGenerator.generate_report(ship_class, seed)
			var took := (Time.get_ticks_usec() - started) / 1000.0
			# Wall clock measures cost, not scheduler jitter: a ship over
			# budget is timed twice more and its best reading counts.
			for again in 2:
				if took <= TIME_BUDGET_MS * (report.rerolls + 1):
					break
				started = Time.get_ticks_usec()
				ShipGenerator.generate_report(ship_class, seed)
				took = minf(took, (Time.get_ticks_usec() - started) / 1000.0)
			sweep.add(report, took)
			_ship_failures.clear()
			_check_ship(report, ship_class)
			_expect(took <= TIME_BUDGET_MS * (report.rerolls + 1),
					"generation took %.0f ms over %d attempts, budget %.0f ms per attempt" % [took, report.rerolls + 1, TIME_BUDGET_MS])
			_check_deterministic(report, ship_class, seed)
			if not _ship_failures.is_empty():
				for f in _ship_failures:
					failures.append("%s seed %d: %s  [%s]" % [ship_class, seed, f, report.sentence])
				if not dumped:
					dumped = true
					print("--- first failing %s seed %d: %s" % [ship_class, seed, report.sentence])
					print(ShipDumper.ascii(report.layout))
					print(ShipDumper.listing(report.layout))
		print(sweep.summary(ship_class, seeds_per_class))
		_ship_failures.clear()
		_check_distributions(ship_class, sweep)
		for f in _ship_failures:
			failures.append("%s sweep: %s" % [ship_class, f])
	_ship_failures.clear()
	_check_name_distribution()
	for f in _ship_failures:
		failures.append("name sweep: %s" % f)
	_report()
	quit(1 if failures.size() > 0 else 0)


## What a Class's sweep adds up: everything the distribution checks read.
class Sweep:
	extends RefCounted
	var ships := 0
	var slowest := 0.0
	var resizes := 0
	var most_resizes := 0
	var rerolled := 0
	var rerolls := 0
	var out_of_band := 0
	var armories := 0
	var armory_capable := 0
	var relaxed := 0
	var relaxed_twice := 0
	var bare_bridges := 0
	var invalid := 0
	## {"archetype/skeleton": count}
	var combos := {}
	var room_area := 0
	var counted_rooms := 0
	var empty_rooms := 0
	var crew := 0
	var loot := 0
	var hatches := 0
	var richness := 0.0
	var rerolled_seeds: Array[int] = []

	func add(report: ShipGenerator.Report, took: float) -> void:
		var layout := report.layout
		ships += 1
		slowest = maxf(slowest, took)
		resizes += report.resizes
		most_resizes = maxi(most_resizes, report.resizes)
		if report.rerolls > 0:
			rerolled += 1
			rerolled_seeds.append(layout.gen_seed)
		rerolls += report.rerolls
		if not report.in_band:
			out_of_band += 1
		if not report.violations.is_empty():
			invalid += 1
		if report.hatch_relaxed > 0:
			relaxed += 1
		if report.hatch_relaxed > 1:
			relaxed_twice += 1
		if ShipInvariants.count_props(layout, &"bridge", &"console") == 0:
			bare_bridges += 1
		var combo := "%s/%s" % [layout.archetype, report.skeleton]
		combos[combo] = combos.get(combo, 0) + 1
		var has_armory := false
		var armory_capable := false
		var hatch_rooms := {}
		for h in layout.hatches:
			hatch_rooms[h.room] = true
		hatches += layout.hatches.size()
		richness += layout.richness
		for i in layout.rooms.size():
			var room := layout.rooms[i]
			crew += room.crew_count
			loot += room.loot_share
			if room.role == &"corridor":
				continue
			counted_rooms += 1
			room_area += room.area()
			if room.crew_count == 0:
				empty_rooms += 1
			if room.role == &"armory":
				has_armory = true
			if not ShipGraph.is_fixed_role(room.role) and not hatch_rooms.has(i):
				armory_capable = true
		if has_armory:
			armories += 1
		if armory_capable:
			self.armory_capable += 1

	func summary(ship_class: StringName, seeds: int) -> String:
		return "%s: %d seeds, slowest %.0f ms, resizes mean %.2f max %d, rerolled %d (%d rerolls, invalid %d), out of band %d, armory rate %d%% (%d%% could hold one), hatches relaxed on %d (%d to half separation), mean room area %.0f, %d archetype/skeleton combos" % [
				ship_class, seeds, slowest, float(resizes) / maxi(seeds, 1), most_resizes, rerolled, rerolls, invalid, out_of_band,
				armories * 100 / maxi(seeds, 1), armory_capable * 100 / maxi(seeds, 1), relaxed, relaxed_twice,
				float(room_area) / maxi(counted_rooms, 1), combos.size()]


## Sweep-level distributions for one Class: every legal archetype ×
## Skeleton combination appears; mean Room area 150 to 210; small-ship
## Armory rate 25% to 45%; reroll rate under 5% and no invalid ship
## emitted; Threat, Loot, empty-Room share and Hatch counts within their
## bands in aggregate and Richness unbiased; Hatch relaxation and bare
## Bridges rare.
func _check_distributions(ship_class: StringName, sweep: Sweep) -> void:
	var n := maxi(sweep.ships, 1)
	var legal := _legal_combos(ship_class)
	for combo in legal:
		_expect(sweep.combos.has(combo), "no ship rolled %s" % combo)
	for combo in sweep.combos:
		_expect(combo in legal, "%d ships rolled the illegal combination %s" % [sweep.combos[combo], combo])
	var mean_area := float(sweep.room_area) / maxi(sweep.counted_rooms, 1)
	_expect(mean_area >= 150.0 and mean_area <= 210.0, "mean room area %.1f, want 150 to 210" % mean_area)
	if ship_class == &"small":
		_expect(sweep.armories * 100 >= 25 * n and sweep.armories * 100 <= 45 * n,
				"small ships rolled an Armory %d%% of the time, want 25%% to 45%%" % (sweep.armories * 100 / n))
	_expect(sweep.rerolled * 100 < 5 * n, "%d%% of seeds rerolled (%s), ceiling 5%%" % [sweep.rerolled * 100 / n, sweep.rerolled_seeds])
	_expect(sweep.invalid == 0, "%d ships were emitted invalid after every reroll" % sweep.invalid)
	_expect(sweep.out_of_band == 0, "%d ships were emitted out of the Room band" % sweep.out_of_band)
	var threat_band: Vector2i = Budgets.THREAT_BAND[ship_class]
	var loot_band: Vector2i = Budgets.LOOT_BAND[ship_class]
	var hatch_band: Vector2i = HatchPlacer.HATCH_BAND[ship_class]
	var mean_crew := float(sweep.crew) / n
	var mean_loot := float(sweep.loot) / n
	var mean_hatches := float(sweep.hatches) / n
	var mean_richness := sweep.richness / n
	_expect(mean_crew >= threat_band.x and mean_crew <= threat_band.y, "mean crew %.1f outside the band %s" % [mean_crew, threat_band])
	_expect(mean_loot >= loot_band.x and mean_loot <= loot_band.y, "mean loot %.1f outside the band %s" % [mean_loot, loot_band])
	_expect(mean_hatches >= hatch_band.x and mean_hatches <= hatch_band.y, "mean hatches %.2f outside the band %s" % [mean_hatches, hatch_band])
	_expect(sweep.empty_rooms * 3 <= sweep.counted_rooms, "%d of %d counted rooms are empty over the sweep" % [sweep.empty_rooms, sweep.counted_rooms])
	_expect(absf(mean_richness - 0.5) <= 0.1, "mean richness %.2f, want near 0.5" % mean_richness)
	# Hatch placement relaxes only where it must (small ships with one
	# usable flank cannot help it), and the Bridge bank fits nearly always.
	var relax_ceiling := 40 if ship_class == &"small" else 5
	_expect(sweep.relaxed * 100 <= relax_ceiling * n, "hatches relaxed on %d%% of ships, ceiling %d%%" % [sweep.relaxed * 100 / n, relax_ceiling])
	_expect(sweep.bare_bridges * 100 <= 5 * n, "%d%% of bridges hold no console bank, ceiling 5%%" % (sweep.bare_bridges * 100 / n))


## The archetype × Skeleton combinations the Hull grammar can roll for a
## Class: small ships take spine or chain on the four small archetypes;
## larger ones add boomtail and ring, a saucer only ring or spine.
func _legal_combos(ship_class: StringName) -> Array[String]:
	var out: Array[String] = []
	for arch in HullGrammar.ARCHETYPES:
		if ship_class == &"small" and arch == &"boomtail":
			continue
		var skeletons: Array[StringName] = [&"spine", &"chain"]
		if ship_class != &"small" and arch == &"saucer":
			skeletons = [&"spine", &"ring"]
		elif ship_class != &"small":
			skeletons = [&"spine", &"chain", &"ring"]
		for sk in skeletons:
			out.append("%s/%s" % [arch, sk])
	return out


## The harness bites: a ship broken on purpose fails the invariant that
## was broken, so a silent regression cannot pass. Each tamper names its
## clause.
func _check_harness_bites() -> void:
	var clean := ShipGenerator.generate_report(&"medium", FIRST_SEED)
	_expect(ShipInvariants.violations(clean.layout, &"medium").is_empty(), "the untouched ship fails an invariant")
	# A Hatch on the Bridge (clause 10).
	var broken := ShipGenerator.generate_report(&"medium", FIRST_SEED)
	for i in broken.layout.rooms.size():
		if broken.layout.rooms[i].role == &"bridge":
			broken.layout.hatches[0].room = i
	_expect(_violates(broken, "opens into the bridge"), "a hatch on the bridge went unnoticed")
	# A prop on a Door tile (clause 17).
	broken = ShipGenerator.generate_report(&"medium", FIRST_SEED)
	var door := broken.layout.doors[0]
	broken.layout.rooms[door.room_a].props.append({type = &"crate", tile = door.tile})
	_expect(_violates(broken, "blocks a doorway"), "a crate in a doorway went unnoticed")
	# A Door dropped (clause 6).
	broken = ShipGenerator.generate_report(&"medium", FIRST_SEED)
	broken.layout.doors.clear()
	_expect(_violates(broken, "reachable"), "a ship with no doors went unnoticed")
	# Crew standing on a prop (clause 16).
	broken = ShipGenerator.generate_report(&"medium", FIRST_SEED)
	for room in broken.layout.rooms:
		if room.crew_count > 0 and not room.props.is_empty():
			room.crew_spawns[0] = room.props[0].tile
			break
	_expect(_violates(broken, "not on prop-free floor"), "crew standing on a prop went unnoticed")
	# A Room over its crew cap (clause 14).
	broken = ShipGenerator.generate_report(&"medium", FIRST_SEED)
	broken.layout.rooms[0].crew_count = 9
	_expect(_violates(broken, "cap"), "a room over its crew cap went unnoticed")
	# A stored article (clause 22).
	broken = ShipGenerator.generate_report(&"medium", FIRST_SEED)
	broken.layout.ship_name = "The " + broken.layout.ship_name
	_expect(_violates(broken, "article"), "a stored 'The' went unnoticed")


## Whether the ship's violations mention [param needle].
func _violates(report: ShipGenerator.Report, needle: String) -> bool:
	for v in ShipInvariants.violations(report.layout, report.layout.ship_class):
		if v.contains(needle):
			return true
	return false


func _check_ship(report: ShipGenerator.Report, ship_class: StringName) -> void:
	var layout := report.layout
	_expect(layout.gen_seed > 0, "layout does not carry its seed")
	_expect(report.violations.is_empty(), "generator emitted a ship it knew was invalid: %s" % "; ".join(report.violations))
	ShipInvariants.new(_expect).check(layout, ship_class)
	var roll := ShipNamer.roll(ship_class, layout.gen_seed, layout.archetype)
	_named += 1
	if roll.prefix != "":
		_prefixed += 1
	_shapes[roll.shape] = _shapes.get(roll.shape, 0) + 1



## Over the sweep: prefixed names near 40%, the three shapes near 45/35/20.
## Eight points is about three sigma at 300 ships; the seeds are fixed, so
## only a change to the namer's hash string re-rolls the sample.
func _check_name_distribution() -> void:
	if _named == 0:
		return
	var prefixed := _prefixed * 100 / _named
	print("names: %d ships, %d%% prefixed, shapes %s" % [_named, prefixed, _shapes])
	_expect(absi(prefixed - 40) <= 8, "%d%% of names carry a registry prefix, want near 40%%" % prefixed)
	var want := {"epithet": 45, "proper": 35, "place": 20}
	for shape: String in want:
		var got: int = _shapes.get(shape, 0) * 100 / _named
		_expect(absi(got - want[shape]) <= 8, "%d%% of names are %s, want near %d%%" % [got, shape, want[shape]])
	for shape in _shapes:
		_expect(want.has(shape), "unknown name shape '%s'" % shape)


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
	_expect(ShipInvariants.count_props(swapped, &"bridge", &"console") == 0, "bridge still holds consoles with a row of none")
	_expect(_fingerprint(swapped) != before, "swapping the bridge row left the ship unchanged")
	RoleFlavour.reset()
	_expect(_fingerprint(ShipGenerator.generate(&"medium", FIRST_SEED)) == before, "restoring the table did not restore the ship")
	for role in [&"bridge", &"engine", &"shield", &"armory", &"cargo", &"medbay", &"quarters", &"corridor"]:
		_expect(RoleFlavour.table().roles.has(String(role)), "no flavour row for %s" % role)


## The same seed twice yields identical Rooms, Doors, Roles and name, and
## a seed that rerolls rerolls the same way: seed identity holds.
func _check_deterministic(report: ShipGenerator.Report, ship_class: StringName, seed: int) -> void:
	var again := ShipGenerator.generate_report(ship_class, seed)
	_expect(_fingerprint(report.layout) == _fingerprint(again.layout), "generating twice gave different ships")
	_expect(report.sentence == again.sentence, "generating twice gave different sentences")
	_expect(report.rerolls == again.rerolls, "generating twice rerolled %d then %d times" % [report.rerolls, again.rerolls])


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
