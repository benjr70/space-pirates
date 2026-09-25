class_name RoleAssigner
extends RefCounted
## Stage 6 of the generator: Role assignment as a ranking over the finished
## partition, read from Flow Distance and Hull Exposure. Always produces an
## answer and never sends a ship back.

## Role multiplicity per Class: {role: Vector2i(min, max)}.
const RANGES := {
	&"small": {&"bridge": Vector2i(1, 1), &"engine": Vector2i(1, 1), &"shield": Vector2i(0, 0),
			&"armory": Vector2i(0, 1), &"cargo": Vector2i(1, 2), &"medbay": Vector2i(0, 1), &"quarters": Vector2i(0, 1)},
	&"medium": {&"bridge": Vector2i(1, 1), &"engine": Vector2i(1, 2), &"shield": Vector2i(0, 1),
			&"armory": Vector2i(1, 2), &"cargo": Vector2i(2, 3), &"medbay": Vector2i(1, 1), &"quarters": Vector2i(1, 2)},
	&"large": {&"bridge": Vector2i(1, 1), &"engine": Vector2i(2, 3), &"shield": Vector2i(1, 2),
			&"armory": Vector2i(2, 3), &"cargo": Vector2i(3, 5), &"medbay": Vector2i(1, 2), &"quarters": Vector2i(2, 4)},
}
## How often a small ship that can hold an Armory rolls one. A third of
## small ships have every pool Room taken by a Hatch and can hold none, so
## this lands the sweep near the spec's 35% of all small ships.
const SMALL_ARMORY_CHANCE := 0.5
## The optional Roles in roll order, then the trim order (reverse of
## importance): Quarters first, then Medbay, Shield, extra Cargo, extra Armory.
const ROLL_ORDER: Array[StringName] = [&"armory", &"shield", &"medbay", &"quarters", &"cargo"]
const TRIM_ORDER: Array[StringName] = [&"quarters", &"medbay", &"shield", &"cargo", &"armory"]


## Assign a Role to every non-corridor Room of [param layout] in place.
## [param pinned] maps Rooms whose packer tag survives (a ring's fore cap
## stays Quarters) to that Role; they leave the pool.
static func assign(layout: ShipLayout, ship_class: StringName, rng: RandomNumberGenerator,
		pinned: Dictionary = {}) -> void:
	# Pinned Rooms already fill part of their Role's band.
	var ranges: Dictionary = (RANGES[ship_class] as Dictionary).duplicate()
	for i: int in pinned:
		var r: Vector2i = ranges[pinned[i]]
		ranges[pinned[i]] = Vector2i(maxi(r.x - 1, 0), maxi(r.y - 1, 0))
	var adjacency := ShipGraph.adjacency(layout)
	var flow := ShipGraph.flow_distances(layout)
	var floors := ShipGraph.floor_without_hatches(layout)
	var hull := ShipGraph.hull_tiles(layout)
	var hatch_rooms := {}
	for h in layout.hatches:
		hatch_rooms[h.room] = true

	var counted: Array[int] = []
	for i in layout.rooms.size():
		if layout.rooms[i].role != &"corridor":
			counted.append(i)
	var bridge := -1
	for i in counted:
		if layout.rooms[i].role == &"bridge":
			bridge = i
	var engines := _settle_engines(layout, counted, ranges[&"engine"], hatch_rooms, adjacency)

	var pool: Array[int] = []
	for i in counted:
		if i != bridge and not engines.has(i) and not pinned.has(i):
			pool.append(i)
	var can_hold_armory := false
	for i in pool:
		if not hatch_rooms.has(i):
			can_hold_armory = true
	var counts := _roll_counts(ship_class, ranges, pool.size(), rng, can_hold_armory)
	# Armories and Cargo both need Rooms clear of a Hatch; Cargo's minimum
	# is served first.
	var clear_rooms := 0
	for i in pool:
		if not hatch_rooms.has(i):
			clear_rooms += 1
	counts[&"armory"] = clampi(counts[&"armory"], 0, maxi(clear_rooms - (ranges[&"cargo"].x - 1), 0))

	var exposure := {}
	for i in pool:
		exposure[i] = ShipGraph.hull_exposure(layout.rooms[i], floors, hull)
	var assigned := {}

	# The Cargo every ship owes a Hatch: the Hatch Room with the highest Hull Exposure.
	var promised := _best(pool, assigned, func(i: int) -> bool: return hatch_rooms.has(i),
			func(i: int) -> float: return exposure[i])
	if promised >= 0:
		assigned[promised] = &"cargo"
		counts[&"cargo"] -= 1

	# Armories deepest by Flow Distance, never in a Hatch Room.
	for n in counts[&"armory"]:
		var pick := _best(pool, assigned, func(i: int) -> bool: return not hatch_rooms.has(i),
				func(i: int) -> float: return float(flow[i]) + layout.rooms[i].area() / 10000.0)
		if pick < 0:
			break
		assigned[pick] = &"armory"

	# Shields Door-adjacent to an Engine.
	for n in counts[&"shield"]:
		var pick := _best(pool, assigned, func(i: int) -> bool:
			for e: int in engines:
				if adjacency[i].has(e):
					return true
			return false, func(i: int) -> float: return -float(flow[i]))
		if pick < 0:
			pick = _best(pool, assigned, func(_i: int) -> bool: return true, func(i: int) -> float: return -float(flow[i]))
		if pick < 0:
			break
		assigned[pick] = &"shield"

	# Cargo, never another Hatch Room: on large ships the largest Room first,
	# then by Hull Exposure.
	var no_hatch := func(i: int) -> bool: return not hatch_rooms.has(i)
	if ship_class == &"large" and counts[&"cargo"] > 0:
		var pick := _best(pool, assigned, no_hatch, func(i: int) -> float: return float(layout.rooms[i].area()))
		if pick >= 0:
			assigned[pick] = &"cargo"
			counts[&"cargo"] -= 1
	for n in counts[&"cargo"]:
		var pick := _best(pool, assigned, no_hatch, func(i: int) -> float: return exposure[i])
		if pick < 0:
			break
		assigned[pick] = &"cargo"

	# Medbay most central by mean Flow Distance.
	for n in counts[&"medbay"]:
		var pick := _best(pool, assigned, func(_i: int) -> bool: return true,
				func(i: int) -> float: return -ShipGraph.mean_distance(layout, i, adjacency))
		if pick < 0:
			break
		assigned[pick] = &"medbay"

	# What remains: Quarters, fore preferred; when Quarters is at its band,
	# another optional Role still under its band, so the table holds where
	# it can (a Cargo that found no Room clear of a Hatch lands here).
	var tally := {}
	for i in assigned:
		tally[assigned[i]] = tally.get(assigned[i], 0) + 1
	var rest := pool.filter(func(i: int) -> bool: return not assigned.has(i))
	rest.sort_custom(func(a: int, b: int) -> bool: return layout.rooms[a].center_tile().y < layout.rooms[b].center_tile().y)
	for i in rest:
		var role: StringName = &"quarters"
		var found := false
		# A Role still under its minimum comes first, then any under its
		# band; never an Armory, which must be the deepest Room and was
		# placed first.
		for floor_pass in 2:
			for candidate: StringName in [&"cargo", &"quarters", &"medbay", &"shield"]:
				if candidate == &"cargo" and hatch_rooms.has(i):
					continue
				var have: int = tally.get(candidate, 0)
				var bound: int = ranges[candidate].x if floor_pass == 0 else ranges[candidate].y
				if have < bound:
					role = candidate
					found = true
					break
			if found:
				break
		assigned[i] = role
		tally[role] = tally.get(role, 0) + 1
	_rebalance(layout, pool, assigned, tally, ranges, hatch_rooms, promised, exposure)

	for i in pool:
		layout.rooms[i].role = assigned[i]
	for i: int in pinned:
		layout.rooms[i].role = pinned[i]
	for e in engines:
		layout.rooms[e].role = &"engine"
	if bridge >= 0:
		layout.rooms[bridge].role = &"bridge"


## Move Rooms between Roles until every count sits inside the table where
## the pool allows: a Role over its band gives a Room to one under its band,
## a Role under its minimum takes one from a Role above its minimum. Cargo
## only ever takes a Room clear of a Hatch, the promised Cargo and the
## Armories never move.
static func _rebalance(layout: ShipLayout, pool: Array[int], assigned: Dictionary, tally: Dictionary,
		ranges: Dictionary, hatch_rooms: Dictionary, promised: int, exposure: Dictionary) -> void:
	const MOVABLE: Array[StringName] = [&"quarters", &"medbay", &"shield", &"cargo"]
	var guard := 16
	while guard > 0:
		guard -= 1
		var moved := false
		for role in MOVABLE:
			var have: int = tally.get(role, 0)
			var target: StringName = &""
			var donor_role: StringName = &""
			if have > ranges[role].y:
				donor_role = role
				for other in MOVABLE:
					if other != role and tally.get(other, 0) < ranges[other].y:
						target = other
						break
			elif have < ranges[role].x:
				target = role
				for other in MOVABLE:
					if other != role and tally.get(other, 0) > ranges[other].x:
						donor_role = other
						break
			if target.is_empty() or donor_role.is_empty():
				continue
			var best := -1
			for i in pool:
				if assigned[i] != donor_role or i == promised:
					continue
				if target == &"cargo" and hatch_rooms.has(i):
					continue
				if best < 0 or exposure[i] > exposure[best]:
					best = i
			if best < 0:
				continue
			assigned[best] = target
			tally[donor_role] -= 1
			tally[target] = tally.get(target, 0) + 1
			moved = true
			break
		if not moved:
			break


## The Engines: those the packer tagged, the one on the corridor first and
## then aft-most, capped by the Class maximum (the rest rejoin the pool) and
## topped up to the minimum from aft-most Rooms beside an Engine that hold
## no Hatch.
static func _settle_engines(layout: ShipLayout, counted: Array[int], range_: Vector2i,
		hatch_rooms: Dictionary, adjacency: Dictionary) -> Dictionary:
	var by_aft := counted.duplicate()
	by_aft.sort_custom(func(a: int, b: int) -> bool:
		return layout.rooms[a].center_tile().y > layout.rooms[b].center_tile().y)
	var on_corridor := func(i: int) -> bool:
		for n: int in adjacency[i]:
			if layout.rooms[n].role == &"corridor":
				return true
		return false
	var tagged := by_aft.filter(func(i: int) -> bool: return layout.rooms[i].role == &"engine")
	tagged.sort_custom(func(a: int, b: int) -> bool:
		var ca: bool = on_corridor.call(a)
		var cb: bool = on_corridor.call(b)
		return ca and not cb if ca != cb else by_aft.find(a) < by_aft.find(b))
	var engines := {}
	for i in tagged:
		if engines.size() < range_.y:
			engines[i] = true
	while engines.size() < range_.x:
		var pick := -1
		for i in by_aft:
			if engines.has(i) or hatch_rooms.has(i) or layout.rooms[i].role == &"bridge":
				continue
			var beside := false
			for e: int in engines:
				if adjacency[i].has(e):
					beside = true
			if beside:
				pick = i
				break
		if pick < 0:
			for i in by_aft:
				if not engines.has(i) and not hatch_rooms.has(i) and layout.rooms[i].role != &"bridge":
					pick = i
					break
		if pick < 0:
			break
		engines[pick] = true
	return engines


## Roll the optional Role counts inside their bands, reserve one Cargo for
## the Hatch promise, then trim or top up until they cover the pool exactly.
static func _roll_counts(ship_class: StringName, ranges: Dictionary, pool: int,
		rng: RandomNumberGenerator, can_hold_armory: bool) -> Dictionary:
	var counts := {}
	for role in ROLL_ORDER:
		var r: Vector2i = ranges[role]
		if role == &"armory" and ship_class == &"small":
			counts[role] = 1 if can_hold_armory and rng.randf() < SMALL_ARMORY_CHANCE else 0
		else:
			counts[role] = rng.randi_range(r.x, r.y)
	counts[&"cargo"] = maxi(counts[&"cargo"], 1)
	var total := _total(counts)
	var guard := 64
	while total > pool and guard > 0:
		guard -= 1
		var trimmed := false
		for role in TRIM_ORDER:
			var floor_: int = ranges[role].x
			if role == &"cargo":
				floor_ = maxi(floor_, 1)
			if role == &"armory" and ship_class != &"small":
				floor_ = maxi(floor_, 1)
			if counts[role] > floor_:
				counts[role] -= 1
				trimmed = true
				break
		if not trimmed:
			break
		total = _total(counts)
	# Under the pool: top up alternating Cargo and Quarters while their bands
	# allow; past both, the other optional Roles up to their bands, so the
	# table holds wherever it can; only then Quarters over its band.
	var next_cargo := true
	guard = 64
	while total < pool and guard > 0:
		guard -= 1
		var order: Array[StringName] = []
		if next_cargo:
			order.append_array([&"cargo", &"quarters"])
		else:
			order.append_array([&"quarters", &"cargo"])
		order.append_array([&"medbay", &"shield", &"armory"])
		var grew := false
		for role in order:
			if counts[role] < ranges[role].y:
				counts[role] += 1
				grew = true
				break
		if not grew:
			counts[&"quarters"] += 1
		next_cargo = not next_cargo
		total = _total(counts)
	return counts


## Rooms the rolled counts would fill.
static func _total(counts: Dictionary) -> int:
	var n := 0
	for role in counts:
		n += counts[role]
	return n


## The unassigned pool Room passing [param eligible] with the highest
## [param score], or -1.
static func _best(pool: Array[int], assigned: Dictionary, eligible: Callable, score: Callable) -> int:
	var best := -1
	var best_score := -INF
	for i in pool:
		if assigned.has(i) or not eligible.call(i):
			continue
		var s: float = score.call(i)
		if s > best_score:
			best_score = s
			best = i
	return best
