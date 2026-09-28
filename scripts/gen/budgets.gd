class_name Budgets
extends RefCounted
## Stage 7 of the generator: the Threat Budget and the Loot Budget, both read
## from the Ship Class and the one Richness roll so danger and reward rise
## together, split across Rooms by Role weight so the Shares sum exactly.

## Crew per counted Room by Class, from poorest to richest, and the total band.
const THREAT_DENSITY := {&"small": Vector2(1.0, 1.4), &"medium": Vector2(1.4, 1.7), &"large": Vector2(1.7, 2.0)}
const THREAT_BAND := {&"small": Vector2i(4, 8), &"medium": Vector2i(11, 19), &"large": Vector2i(24, 36)}
const THREAT_WEIGHT := {&"armory": 3.0, &"bridge": 2.5, &"engine": 2.0, &"shield": 2.0,
		&"quarters": 1.5, &"cargo": 1.5, &"medbay": 1.0, &"corridor": 0.5}
## Most crew in one Room, and in one of at least [constant BIG_ROOM] tiles.
const CREW_CAP := 4
const CREW_CAP_BIG := 5
const BIG_ROOM := 200
const BRIDGE_FLOOR := 1
const ARMORY_FLOOR := 2

## Gold units per counted Room by Class, poorest to richest, and the total band.
const LOOT_DENSITY := {&"small": Vector2(1.0, 1.5), &"medium": Vector2(1.5, 2.2), &"large": Vector2(2.2, 3.0)}
const LOOT_BAND := {&"small": Vector2i(4, 9), &"medium": Vector2i(12, 24), &"large": Vector2i(31, 54)}
const LOOT_WEIGHT := {&"armory": 4.0, &"cargo": 3.0, &"bridge": 1.0, &"quarters": 1.0,
		&"medbay": 1.0, &"engine": 0.5, &"shield": 0.5, &"corridor": 0.0}
const ARMORY_LOOT_FLOOR := 3
const CARGO_LOOT_FLOOR := 1
## The one tuning constant from Loot units to the gold the pirate sees: a
## Container's `gold` is in units, its displayed value is
## [method displayed_gold].
const GOLD_PER_UNIT := 10
## Gold per Container by Role: a range rolled per Container.
const CONTAINER_SIZE := {&"armory": Vector2i(3, 5), &"cargo": Vector2i(1, 2)}
const MAX_CONTAINERS := 6


## The gold the pirate sees for a Container of [param units].
static func displayed_gold(units: int) -> int:
	return units * GOLD_PER_UNIT


## Set every Room's crew_count, loot_share and containers on [param layout].
## Reads only the Class and the ship's Richness: no further rolls.
static func apply(layout: ShipLayout, ship_class: StringName) -> void:
	var counted: Array[int] = []
	for i in layout.rooms.size():
		if layout.rooms[i].role != &"corridor":
			counted.append(i)
	var hatch_rooms := {}
	for h in layout.hatches:
		hatch_rooms[h.room] = true

	var threat := threat_total(ship_class, counted.size(), layout.richness)
	var shares := _split_threat(layout, counted, hatch_rooms, threat)
	for i in layout.rooms.size():
		layout.rooms[i].crew_count = shares[i]

	var loot := loot_total(ship_class, counted.size(), layout.richness)
	var loot_shares := _split_loot(layout, loot)
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		room.loot_share = loot_shares[i]
		room.containers = containers_for(room.role, room.loot_share)


## The Threat Budget for a Class, a counted Room count and a Richness.
static func threat_total(ship_class: StringName, counted: int, richness: float) -> int:
	return _total(THREAT_DENSITY[ship_class], THREAT_BAND[ship_class], counted, richness)


## The Loot Budget for a Class, a counted Room count and a Richness.
static func loot_total(ship_class: StringName, counted: int, richness: float) -> int:
	return _total(LOOT_DENSITY[ship_class], LOOT_BAND[ship_class], counted, richness)


## A Budget: the per-Room density at this Richness times the counted Rooms,
## held to the Class band.
static func _total(density: Vector2, band: Vector2i, counted: int, richness: float) -> int:
	return clampi(roundi(lerpf(density.x, density.y, richness) * counted), band.x, band.y)


## Integer shares of [param total] proportional to [param weights], by
## largest remainder, so they sum to the total exactly.
static func split(weights: Array[float], total: int) -> Array[int]:
	var sum := 0.0
	for w in weights:
		sum += w
	var shares: Array[int] = []
	var remainders: Array[float] = []
	var given := 0
	for w in weights:
		var exact := 0.0 if sum <= 0.0 else total * w / sum
		shares.append(int(floor(exact)))
		remainders.append(exact - floor(exact))
		given += shares[shares.size() - 1]
	var order: Array[int] = []
	for i in weights.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return remainders[a] > remainders[b] if remainders[a] != remainders[b] else weights[a] > weights[b])
	for k in range(total - given):
		shares[order[k % order.size()]] += 1
	return shares


## The Threat Shares: Role weight with Hatch Rooms halved, then Bridge and
## Armory floors, per-Room caps with the overflow spilling to the next
## weighted Room with headroom, and at most a third of counted Rooms empty.
static func _split_threat(layout: ShipLayout, counted: Array[int], hatch_rooms: Dictionary, total: int) -> Array[int]:
	var n := layout.rooms.size()
	var weights: Array[float] = []
	for i in n:
		var w: float = THREAT_WEIGHT.get(layout.rooms[i].role, 1.0)
		if hatch_rooms.has(i):
			w /= 2.0
		weights.append(w)
	var shares := split(weights, total)
	var by_weight: Array[int] = []
	for i in n:
		by_weight.append(i)
	by_weight.sort_custom(func(a: int, b: int) -> bool: return weights[a] > weights[b])

	var floors: Array[int] = []
	var caps: Array[int] = []
	for i in n:
		var room := layout.rooms[i]
		floors.append(BRIDGE_FLOOR if room.role == &"bridge" else (ARMORY_FLOOR if room.role == &"armory" else 0))
		caps.append(CREW_CAP_BIG if room.area() >= BIG_ROOM else CREW_CAP)

	# Floors: pull bodies from the heaviest Rooms above their own floor.
	for i in n:
		while shares[i] < floors[i]:
			var donor := _donor(shares, floors, by_weight, i)
			if donor < 0:
				break
			shares[donor] -= 1
			shares[i] += 1
	# Caps: spill to the next weighted Room with headroom (any Room with
	# headroom when none follows), never reroll.
	for k in by_weight.size():
		var i := by_weight[k]
		while shares[i] > caps[i]:
			var taker := -1
			for step in range(1, by_weight.size()):
				var j := by_weight[(k + step) % by_weight.size()]
				if shares[j] < caps[j]:
					taker = j
					break
			if taker < 0:
				break
			shares[i] -= 1
			shares[taker] += 1
	# Empty-Room limit: at most a third of counted Rooms at zero; each extra
	# takes one body from the heaviest Room above its floor.
	var allowed_empty := counted.size() / 3
	var empties: Array[int] = []
	for i in counted:
		if shares[i] == 0:
			empties.append(i)
	var k := 0
	while empties.size() - k > allowed_empty:
		var target := empties[k]
		var donor := _donor(shares, floors, by_weight, target)
		if donor < 0:
			break
		shares[donor] -= 1
		shares[target] += 1
		k += 1
	return shares


## The heaviest Room (by weight order) with a body to spare above its floor,
## keeping at least one so it is not emptied, or -1.
static func _donor(shares: Array[int], floors: Array[int], by_weight: Array[int], not_room: int) -> int:
	var best := -1
	for j in by_weight:
		if j == not_room or shares[j] <= maxi(floors[j], 1):
			continue
		if best < 0 or shares[j] > shares[best]:
			best = j
	return best


## The Loot Shares: Role weight, no Hatch discount, no depth multiplier,
## then every Armory at least 3 and every Cargo at least 1, pulled from the
## richest Room above its own floor.
static func _split_loot(layout: ShipLayout, total: int) -> Array[int]:
	var n := layout.rooms.size()
	var weights: Array[float] = []
	var floors: Array[int] = []
	for i in n:
		var role := layout.rooms[i].role
		weights.append(LOOT_WEIGHT.get(role, 1.0))
		floors.append(ARMORY_LOOT_FLOOR if role == &"armory" else (CARGO_LOOT_FLOOR if role == &"cargo" else 0))
	var shares := split(weights, total)
	for i in n:
		while shares[i] < floors[i]:
			var donor := -1
			for j in n:
				if j != i and shares[j] > floors[j] and (donor < 0 or shares[j] > shares[donor]):
					donor = j
			if donor < 0:
				break
			shares[donor] -= 1
			shares[i] += 1
	return shares


## A Room's Loot Share as Containers, greedy largest-first at the Role's
## Container size and never one under it: a cut that would leave less than
## the smallest size is shortened so the remainder makes a whole Container.
## At most [constant MAX_CONTAINERS], the surplus in the largest. Corridors
## hold none. Deterministic: no roll is spent here.
static func containers_for(role: StringName, share: int) -> Array[int]:
	var out: Array[int] = []
	if role == &"corridor" or share <= 0:
		return out
	var size: Vector2i = CONTAINER_SIZE.get(role, Vector2i(1, 1))
	var left := share
	while left > 0:
		if out.size() >= MAX_CONTAINERS:
			out[0] += left
			break
		var gold := mini(size.y, left)
		var rest := left - gold
		if rest > 0 and rest < size.x and gold - (size.x - rest) >= size.x:
			gold -= size.x - rest
		out.append(gold)
		left -= gold
	out.sort()
	out.reverse()
	return out
