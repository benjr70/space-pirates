class_name ProtoSilhouette
extends RefCounted
## PROTOTYPE — throwaway code for issue #4 ("what silhouette recipe makes a
## ship read as a ship?"). Not production; the winning recipe gets folded into
## the generator spec and this file dies on a proto branch.
##
## Three candidate recipes, each producing a list of stacked, bilaterally
## symmetric section rects in tile coordinates (fore at low y, aft at high y,
## spine at x = SPINE). Sections sit one tile apart so the gap becomes their
## shared wall, exactly like RoomData rects.
##
##   A "three-block"  — fixed fore/mid/aft, independently rolled bands.
##   B "spine-walk"   — 3–7 sections, each width derived from the previous one
##                      (continuity + perturbation, Davies-style).
##   C "featured"     — spine-walk base plus class features: a tapered nose,
##                      an occasional aft flare, nacelles on large ships.

## Spine x. Sections are centred here; all widths are even so mirror symmetry
## is exact.
const SPINE := 64

## Smallest legal section: BSP may leave it unsplit, so it must clear the
## fightable-room floor (>=8x6 and >=60 tiles).
const MIN_W := 8
const MIN_L := 8

## Class -> target floor area in tiles (~150 tiles/room x band midpoint).
const AREA := {&"small": 750, &"medium": 1400, &"large": 2400}


## Widest section a ship of this seed gets: solved from the area target and a
## rolled length:beam ratio so hulls come out ship-shaped instead of noodles.
static func _beam(target: int, rng: RandomNumberGenerator) -> int:
	var aspect := rng.randf_range(1.8, 3.0)
	return clampi(_even(int(round(sqrt(target / (0.8 * aspect))))), MIN_W + 4, 36)


static func sections(recipe: String, ship_class: StringName, seed_: int) -> Array[Rect2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s#%d" % [recipe, seed_])
	match recipe:
		"A":
			return _three_block(ship_class, rng)
		"B":
			return _spine_walk(ship_class, rng)
		"C":
			return _featured(ship_class, rng)
		"D":
			return _stepped(ship_class, rng)
		"E":
			return _spine_corridor(ship_class, rng)
		"F":
			var plan := _hull_pack(ship_class, rng)
			var out: Array[Rect2i] = []
			for room: Dictionary in plan.rooms:
				out.append_array(room.rects)
			return out
	push_error("unknown recipe %s" % recipe)
	return []


## Recipe A: classic narrow fore / wide mid / medium aft, each band rolled
## independently of the others.
static func _three_block(ship_class: StringName, rng: RandomNumberGenerator) -> Array[Rect2i]:
	var target: int = AREA[ship_class] * rng.randf_range(0.9, 1.1)
	var mid_w := _beam(target, rng)
	var fore_w := _even(int(mid_w * rng.randf_range(0.45, 0.62)))
	var aft_w := _even(int(mid_w * rng.randf_range(0.68, 0.88)))

	var fore_f := rng.randf_range(0.20, 0.28)
	var mid_f := rng.randf_range(0.42, 0.50)
	var widths: Array[int] = [fore_w, mid_w, aft_w]
	var fracs: Array[float] = [fore_f, mid_f, 1.0 - fore_f - mid_f]
	var out: Array[Rect2i] = []
	var y := 0
	for i in 3:
		var w: int = maxi(widths[i], MIN_W)
		var l: int = maxi(int(round(target * fracs[i] / w)), MIN_L)
		out.append(Rect2i(SPINE - w / 2, y, w, l))
		y += l + 1
	return out


## Recipe B: walk the spine fore->aft; each section's width is the previous
## one perturbed — growing to a peak, shrinking after. Variety comes from
## continuity plus perturbation, not independent rolls.
static func _spine_walk(ship_class: StringName, rng: RandomNumberGenerator,
		target_scale := 1.0) -> Array[Rect2i]:
	var target: int = AREA[ship_class] * rng.randf_range(0.9, 1.1) * target_scale
	var n := 3
	match ship_class:
		&"small":
			n = 3
		&"medium":
			n = rng.randi_range(4, 5)
		&"large":
			n = rng.randi_range(5, 7)
	var peak := clampi(int(round(n * rng.randf_range(0.35, 0.55))), 1, n - 2)
	var beam := _beam(target, rng)

	var widths: Array[int] = []
	var w := beam * rng.randf_range(0.35, 0.5)
	for i in n:
		if i > 0:
			if i <= peak:
				w *= rng.randf_range(1.25, 1.55)
			else:
				w *= rng.randf_range(0.72, 0.92)
		if i == peak:
			w = beam
		widths.append(clampi(_even(int(round(w))), MIN_W, beam))

	# Raw length rolls, then scaled so total area lands near target.
	var raw: Array[float] = []
	var area := 0.0
	for i in n:
		raw.append(rng.randf_range(0.6, 1.4))
		area += raw[i] * widths[i]
	var out: Array[Rect2i] = []
	var y := 0
	for i in n:
		var l: int = maxi(int(round(raw[i] * target / area)), MIN_L)
		out.append(Rect2i(SPINE - widths[i] / 2, y, widths[i], l))
		y += l + 1
	return out


## Recipe C: spine-walk base plus discrete features — a tapered nose on
## everything, an aft flare half the time, and nacelles flanking the aft
## section on large ships.
static func _featured(ship_class: StringName, rng: RandomNumberGenerator) -> Array[Rect2i]:
	# Features add floor on top of the spine, so the spine aims low to keep
	# the total inside the class band (nose ~7%; nacelles another ~15%).
	var out := _spine_walk(ship_class, rng, 0.78 if ship_class == &"large" else 0.92)

	# Aft flare: the tail section kicks back out wider than its neighbour.
	if rng.randf() < 0.5:
		var tail := out[out.size() - 1]
		var flared := _even(int(out[out.size() - 2].size.x * rng.randf_range(1.0, 1.2)))
		flared = clampi(flared, MIN_W, 34)
		out[out.size() - 1] = Rect2i(SPINE - flared / 2, tail.position.y, flared, tail.size.y)

	# Nose: a short narrow section ahead of the fore section.
	var nose_w := _even(rng.randi_range(8, mini(10, out[0].size.x - 2)))
	var nose_l := rng.randi_range(MIN_L, 10)
	for i in out.size():
		out[i].position.y += nose_l + 1
	out.insert(0, Rect2i(SPINE - nose_w / 2, 0, nose_w, nose_l))

	# Nacelles: large ships get a symmetric pair of pods flanking the
	# second-to-last section, joined through its side walls.
	if ship_class == &"large":
		var host := out[out.size() - 2]
		var pod_w := _even(rng.randi_range(8, 10))
		var pod_l := clampi(host.size.y + _even(rng.randi_range(0, 6)), MIN_L, host.size.y + 6)
		var pod_y: int = host.position.y + (host.size.y - pod_l) / 2
		out.append(Rect2i(host.position.x - 1 - pod_w, pod_y, pod_w, pod_l))
		out.append(Rect2i(host.end.x + 1, pod_y, pod_w, pod_l))
	return out


static func _even(v: int) -> int:
	return maxi(v - (v % 2), MIN_W)


## Recipe F: hull-outline-first, rooms packed to fill it (the RPG deck-plan
## pattern). Each seed rolls a GRAMMAR: hull archetype x interior skeleton x
## feature set, so seeds compress to different sentences. Returns
## {rooms: [{rects, role}], doors: [{tile, horizontal, width}], sentence}.
## A "room" is several abutting rects sharing no wall - one open space whose
## edges follow the hull.

const SIDE_ROLES: Array[StringName] = [&"cargo", &"quarters", &"cargo", &"medbay"]


## Hull width envelope per archetype, t 0=fore 1=aft, result x beam.
static func _env_at(arch: StringName, t: float) -> float:
	match arch:
		&"wedge":
			if t < 0.55:
				return 0.35 + 0.65 * sin(t / 0.55 * PI / 2)
			return 1.0 - 0.4 * sin((t - 0.55) / 0.45 * PI / 2)
		&"hammerhead":
			if t < 0.15:
				return 1.0
			if t < 0.32:
				return lerpf(1.0, 0.5, (t - 0.15) / 0.17)
			if t < 0.8:
				return 0.5
			return lerpf(0.5, 0.68, (t - 0.8) / 0.2)
		&"saucer":
			return 0.25 + 0.75 * pow(sin(PI * clampf(t, 0.02, 0.98)), 0.7)
		&"block":
			return 0.75 if t < 0.08 or t > 0.92 else 0.92
		&"boomtail":
			if t < 0.45:
				return 0.4 + 0.6 * sin(t / 0.45 * PI / 2)
			if t < 0.58:
				return lerpf(1.0, 0.32, (t - 0.45) / 0.13)
			if t < 0.82:
				return 0.32
			return 0.72
	return 1.0


## Class is room count (#2); footprint falls out of it. Roll the count in the
## class band, size the hull from it, and reroll the whole ship if the packed
## count still lands outside the band (#5, Q1 + Q3 fallback).
const ROOM_BAND := {&"small": Vector2i(4, 6), &"medium": Vector2i(8, 11), &"large": Vector2i(14, 18)}
const ROOM_TARGET := 175   # mean of the 140–220 band
const SKELETON_OVERHEAD := 1.15   # corridor + shared walls
const FIGHT_CORE := 10
const FLOOR_AREA := 140
const CEILING_AREA := 260
const MAX_REROLLS := 8


static func _hull_pack(ship_class: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var band: Vector2i = ROOM_BAND[ship_class]
	var want := rng.randi_range(band.x, band.y)
	var scale := 1.0
	var plan := {}
	for attempt in MAX_REROLLS:
		plan = _hull_pack_once(ship_class, rng, want, scale)
		var got := 0
		for room: Dictionary in plan.rooms:
			if not room.get("corridor", false):
				got += 1
		plan.room_count = got
		if got >= band.x and got <= band.y:
			if attempt > 0:
				plan.sentence += " / resize×%d" % attempt
			return plan
		# FEEDBACK: same count, hull area rescaled by the miss. Overheads
		# (solid fills, nose, hub, band walls) vary per hull, so the flat
		# allowance can't be right for every seed; this converges instead.
		scale *= clampf(pow(float(want) / float(maxi(got, 1)), 0.6), 0.75, 1.5)
	plan.sentence += " / OUT OF BAND after %d resizes" % MAX_REROLLS
	return plan


static func _hull_pack_once(ship_class: StringName, rng: RandomNumberGenerator, room_count: int,
		area_scale := 1.0) -> Dictionary:
	var target: int = int(room_count * ROOM_TARGET * SKELETON_OVERHEAD * area_scale * rng.randf_range(0.95, 1.05))

	var arch_pool: Array[StringName] = [&"wedge", &"hammerhead", &"saucer", &"block"]
	if ship_class != &"small":
		arch_pool.append(&"boomtail")
	var arch: StringName = arch_pool[rng.randi_range(0, arch_pool.size() - 1)]

	var aspect := rng.randf_range(1.5, 2.2)
	match arch:
		&"saucer":
			aspect = rng.randf_range(1.05, 1.35)
		&"block":
			aspect = rng.randf_range(2.2, 3.0)
		&"boomtail":
			aspect = rng.randf_range(2.3, 3.0)
	var beam := clampi(_even(int(round(sqrt(target / (0.8 * aspect))))), 16, 56)
	var length := maxi(int(round(target / (0.8 * beam))), 30)

	var features: Array[String] = []

	# STRUCTURAL ASYMMETRY: the hull is a union of masses — the main envelope
	# plus rolled secondary blobs (side pod, cockpit boom, aft wing, blister),
	# each with its own size and off-axis placement. Two flanks are different
	# SHAPES, not a wobbled mirror.
	# hull_rows[y] is a merged list of floor intervals [x0, x1).
	var amp_p := rng.randf_range(0.0, 0.18)
	var amp_s := rng.randf_range(0.0, 0.18)
	var ph_p := rng.randf_range(0.0, TAU)
	var ph_s := rng.randf_range(0.0, TAU)
	var hull_rows: Array = []
	while hull_rows.size() < length:
		var l := rng.randi_range(2, 4)
		var t := float(hull_rows.size()) / float(length)
		var base := beam * _env_at(arch, t) / 2.0
		var hp := clampi(int(round(base * (1.0 + amp_p * sin(TAU * t + ph_p)))) + rng.randi_range(-1, 1), 4, beam)
		var hs := clampi(int(round(base * (1.0 + amp_s * sin(TAU * t + ph_s)))) + rng.randi_range(-1, 1), 4, beam)
		for i in l:
			hull_rows.append([Vector2i(SPINE - hp, SPINE + hs)])
	hull_rows.resize(length)

	# Secondary masses.
	var mass_budget := rng.randi_range(0, 1) if ship_class == &"small" else rng.randi_range(1, 2)
	for n in mass_budget:
		var kinds: Array[String] = ["side pod", "cockpit boom", "aft wing", "blister"]
		var kind: String = kinds[rng.randi_range(0, 3)]
		features.append(kind)
		var sgn := -1 if rng.randf() < 0.5 else 1
		var m_len := 0
		var m_y0 := 0
		var m_beam := 0
		match kind:
			"side pod":
				m_len = int(length * rng.randf_range(0.25, 0.45))
				m_y0 = rng.randi_range(int(length * 0.25), int(length * 0.6))
				m_beam = clampi(int(beam * rng.randf_range(0.4, 0.6)), 8, beam)
			"cockpit boom":
				m_len = int(length * rng.randf_range(0.25, 0.4))
				m_y0 = 0
				m_beam = rng.randi_range(10, 14)
			"aft wing":
				m_len = int(length * rng.randf_range(0.2, 0.35))
				m_y0 = length - m_len
				m_beam = clampi(int(beam * rng.randf_range(0.35, 0.55)), 8, beam)
			"blister":
				m_len = rng.randi_range(6, 11)
				m_y0 = rng.randi_range(int(length * 0.2), int(length * 0.7))
				m_beam = rng.randi_range(6, 10)
		var mid_half: int = beam / 2
		var off: int = sgn * int(mid_half * rng.randf_range(0.55, 1.0))
		var m_ph := rng.randf_range(0.0, TAU)
		for y in range(m_y0, mini(m_y0 + m_len, length)):
			var mt := float(y - m_y0) / float(maxi(m_len, 1))
			var mh := clampi(int(round(m_beam / 2.0 * (0.55 + 0.45 * sin(PI * mt)))) + rng.randi_range(-1, 1), 3, m_beam)
			var c := SPINE + off
			hull_rows[y] = _merge_iv(hull_rows[y] + [Vector2i(c - mh, c + mh)])

	# Fore-aft bands: [prongs] wall bridge wall mid wall engine.
	var bridge_len := rng.randi_range(10, 14)
	var engine_len := rng.randi_range(8, 13)
	var prong_len := 0
	var notch_w := 0
	var notch_c := SPINE
	var wants_prongs: bool = arch != &"saucer" and arch != &"hammerhead" \
			and ship_class != &"small"
	if wants_prongs and rng.randf() < 0.45:
		features.append("prongs")
		prong_len = clampi(int(length * rng.randf_range(0.12, 0.2)), 6, 14)
		notch_w = rng.randi_range(2, 4) * 2
		notch_c = SPINE + rng.randi_range(-5, 5)
	# BRIDGE AFT OF THE TAPER (#5, Q4): the Skeleton's fore end starts at the
	# first row where the hull is >= 12 wide, so the Bridge can hold a 10x10
	# fight core. Rows forward of it are solid nose (or prong notches).
	var b0 := prong_len + 1 if prong_len > 0 else 0
	while b0 < length - 1 and _row_width(hull_rows[b0]) < 12:
		b0 += 1
	var m0 := b0 + bridge_len + 1
	var m1 := length - engine_len - 1
	while m1 - m0 < 14:
		hull_rows.append(hull_rows[length - 1].duplicate())
		length += 1
		m1 = length - engine_len - 1

	var tail_len := 0
	var tail_w := 0
	var tail_c := SPINE
	if arch != &"boomtail" and engine_len >= 9 and rng.randf() < 0.35:
		features.append("split tail")
		tail_len = clampi(int(length * rng.randf_range(0.08, 0.14)), 4, engine_len - 4)
		tail_w = rng.randi_range(2, 4) * 2
		tail_c = SPINE + rng.randi_range(-5, 5)

	# Notches: guarantee lobes both sides of the cut, then cut.
	if prong_len > 0:
		for y in range(0, mini(prong_len + 3, length)):
			hull_rows[y] = _merge_iv(hull_rows[y] + [Vector2i(notch_c - notch_w / 2 - 5, notch_c + notch_w / 2 + 5)])
		for y in prong_len:
			hull_rows[y] = _cut_iv(hull_rows[y], Vector2i(notch_c - notch_w / 2, notch_c + notch_w / 2))
	if tail_len > 0:
		for y in range(maxi(length - tail_len - 3, 0), length):
			hull_rows[y] = _merge_iv(hull_rows[y] + [Vector2i(tail_c - tail_w / 2 - 5, tail_c + tail_w / 2 + 5)])
		for y in range(length - tail_len, length):
			hull_rows[y] = _cut_iv(hull_rows[y], Vector2i(tail_c - tail_w / 2, tail_c + tail_w / 2))

	# The corridor rides off-axis; its strip is added to the hull union so it
	# always fits, door rows included.
	var co := rng.randi_range(-5, 5)
	if absi(co) >= 2:
		features.append("offset corridor")
	var cx := SPINE + co
	for y in range(maxi(m0 - 3, 0), mini(m1 + 3, length)):
		hull_rows[y] = _merge_iv(hull_rows[y] + [Vector2i(cx - 4, cx + 4)])

	# Interior skeleton.
	var skeleton: StringName = &"spine"
	if ship_class == &"small":
		skeleton = &"chain" if rng.randf() < 0.6 else &"spine"
	elif arch == &"saucer":
		skeleton = &"ring" if rng.randf() < 0.75 else &"spine"
	else:
		var roll := rng.randf()
		if roll < 0.25:
			skeleton = &"chain"
		elif roll < 0.45 and beam >= 28:
			skeleton = &"ring"
	if skeleton == &"ring" and m1 - m0 < 26:
		skeleton = &"spine"

	var hub_half := 0
	var hub_y0 := 0
	var hub_y1 := 0
	var core := Rect2i()
	if skeleton == &"ring":
		# Core is the Bridge and must clear the floor: 10-12 wide, 14-16 long.
		# Flanks outboard of the ring only survive where the hull is wide
		# enough; thin ones are filled solid by the sliver rule (#5, Q6).
		var core_half := rng.randi_range(5, 6)
		hub_half = core_half + 4
		var core_len := rng.randi_range(14, 16)
		hub_y0 = m0 + (m1 - m0 - core_len - 8) / 2
		hub_y1 = hub_y0 + core_len + 8
		core = Rect2i(cx - core_half, hub_y0 + 4, core_half * 2, core_len)
	elif skeleton == &"spine" and ship_class != &"small":
		if beam >= 24 and m1 - m0 >= 22 and rng.randf() < 0.7:
			hub_half = 6 if beam >= 28 else 5
			hub_y0 = m0 + (m1 - m0) / 2 - 5
			hub_y1 = mini(hub_y0 + rng.randi_range(8, 12), m1)
	for y in range(hub_y0, hub_y1):
		hull_rows[y] = _merge_iv(hull_rows[y] + [Vector2i(cx - hub_half - 5, cx + hub_half + 5)])

	var cxmin := func(y: int) -> int:
		return cx - hub_half if hub_half > 0 and y >= hub_y0 and y < hub_y1 else cx - 2
	var cxmax := func(y: int) -> int:
		return cx + hub_half if hub_half > 0 and y >= hub_y0 and y < hub_y1 else cx + 2
	var neg_inf := func(_y: int) -> int: return -999
	var pos_inf := func(_y: int) -> int: return 999

	var region_tiles := func(y0: int, y1: int, lo_f: Callable, hi_f: Callable) -> Dictionary:
		var tiles := {}
		for y in range(y0, y1):
			for iv: Vector2i in hull_rows[y]:
				var x0: int = maxi(iv.x, int(lo_f.call(y)))
				var x1: int = mini(iv.y, int(hi_f.call(y)))
				if x1 - x0 >= 4:
					for x in range(x0, x1):
						tiles[Vector2i(x, y)] = true
		return tiles

	# Rooms as tile sets first; every 4-connected patch is its own room so
	# the stitcher can reason about them. Rects come at the very end.
	var rooms: Array[Dictionary] = []
	var seeded: Array[Dictionary] = []

	if prong_len > 0:
		var mid := func(_y: int) -> int: return notch_c
		for comp: Dictionary in _components(region_tiles.call(0, prong_len, neg_inf, mid)):
			rooms.append({tiles = comp, role = &"cargo"})
		for comp: Dictionary in _components(region_tiles.call(0, prong_len, mid, pos_inf)):
			rooms.append({tiles = comp, role = &"cargo"})

	for comp: Dictionary in _components(region_tiles.call(b0, m0 - 1, neg_inf, pos_inf)):
		rooms.append({tiles = comp, role = &"quarters" if skeleton == &"ring" else &"bridge"})

	if skeleton == &"chain":
		var y := m0
		while m1 - y >= 10:
			var band_len := mini(rng.randi_range(10, 20), m1 - y)
			if m1 - (y + band_len + 1) < 10:
				band_len = m1 - y
			var role: StringName = SIDE_ROLES[rng.randi_range(0, 3)]
			for comp: Dictionary in _components(region_tiles.call(y, y + band_len, neg_inf, pos_inf)):
				rooms.append({tiles = comp, role = role})
			var d := _chain_door(hull_rows, y - 1, rng)
			if not d.is_empty():
				seeded.append(d)
			y += band_len + 1
		var last := _chain_door(hull_rows, m1, rng)
		if not last.is_empty():
			seeded.append(last)
	else:
		var corr: Dictionary = region_tiles.call(m0, m1, cxmin, cxmax)
		if skeleton == &"ring":
			var carve := core.grow(1)
			for x in range(carve.position.x, carve.end.x):
				for y2 in range(carve.position.y, carve.end.y):
					corr.erase(Vector2i(x, y2))
		rooms.append({tiles = corr, role = &"medbay", corridor = true})
		seeded.append({tile = Vector2i(cx - 1, m0 - 1), horizontal = true, width = 2})
		seeded.append({tile = Vector2i(cx - 1, m1), horizontal = true, width = 2})
		if skeleton == &"ring":
			var core_tiles := {}
			for x in range(core.position.x, core.end.x):
				for y2 in range(core.position.y, core.end.y):
					core_tiles[Vector2i(x, y2)] = true
			rooms.append({tiles = core_tiles, role = &"bridge"})
			seeded.append({tile = Vector2i(cx - 1, core.position.y - 1), horizontal = true, width = 2})
			seeded.append({tile = Vector2i(cx - 1, core.end.y), horizontal = true, width = 2})

		# ASYMMETRY: flanks are banded independently AND in different styles.
		# BAYS ONLY (#5, Q2): every band is >= 10 deep so it can hold a 10x10
		# fight core; the cabin-run style (6-9 deep) is gone. "Uneven flanks"
		# is now short bays vs long bays, not cabins vs bays.
		var styles: Array[Vector2i] = []
		for k in 2:
			styles.append(Vector2i(10, 13) if rng.randf() < 0.5 else Vector2i(14, 20))
		if styles[0] != styles[1]:
			features.append("uneven flanks")
		for side_i in 2:
			var sgn: int = -1 if side_i == 0 else 1
			var style: Vector2i = styles[side_i]
			var y := m0
			while m1 - y >= 10:
				var band_len := mini(rng.randi_range(style.x, style.y), m1 - y)
				if m1 - (y + band_len + 1) < 10:
					band_len = m1 - y
				var band_end := y + band_len
				var side_tiles: Dictionary
				if sgn < 0:
					side_tiles = region_tiles.call(y, band_end, neg_inf,
							func(row: int) -> int: return int(cxmin.call(row)) - 1)
				else:
					side_tiles = region_tiles.call(y, band_end,
							func(row: int) -> int: return int(cxmax.call(row)) + 1, pos_inf)
				for comp: Dictionary in _components(side_tiles):
					rooms.append({tiles = comp, role = SIDE_ROLES[rng.randi_range(0, 3)]})
					var dy := -1
					for row in range(y, band_end - 1):
						var wall_x: int = (int(cxmin.call(row)) - 1) if sgn < 0 else int(cxmax.call(row))
						var wall_x2: int = (int(cxmin.call(row + 1)) - 1) if sgn < 0 else int(cxmax.call(row + 1))
						if wall_x == wall_x2 and comp.has(Vector2i(wall_x + sgn, row)) \
								and comp.has(Vector2i(wall_x + sgn, row + 1)):
							dy = row
							if row >= (y + band_end) / 2:
								break
					if dy >= 0:
						var wall_x: int = (int(cxmin.call(dy)) - 1) if sgn < 0 else int(cxmax.call(dy))
						seeded.append({tile = Vector2i(wall_x, dy), horizontal = false, width = 2})
				y = band_end + 1

	var eng: Dictionary = region_tiles.call(m1 + 1, length, neg_inf, pos_inf)
	if ship_class != &"small":
		# Engine pods roll per side against the outermost hull edge.
		var pod_end := length - tail_len if tail_len > 0 else length
		for pod_side: Array in [[-1, "port pod"], [1, "stbd pod"]]:
			if rng.randf() >= 0.45:
				continue
			var sgn: int = pod_side[0]
			var edge: Array[int] = []
			for y in range(0, length):
				var ivs: Array = hull_rows[y]
				edge.append(int(ivs[0].x) if sgn < 0 else int(ivs[ivs.size() - 1].y))
			var run := _longest_equal_run(edge, m1 + 1, pod_end)
			if run.y - run.x < 5:
				continue
			features.append(pod_side[1])
			var pod_w := 4 + rng.randi_range(0, 1) * 2
			var pod_l := mini(run.y - run.x, 10)
			var pod_y: int = run.x + (run.y - run.x - pod_l) / 2
			for yy in range(pod_y, pod_y + pod_l):
				for i in pod_w:
					var xx: int = edge[run.x] - 1 - i if sgn < 0 else edge[run.x] + i
					eng[Vector2i(xx, yy)] = true
	for comp: Dictionary in _components(eng):
		rooms.append({tiles = comp, role = &"engine"})

	# CEILING (#5, Q5): a Room over 260 tiles is split along its long axis if
	# both halves still clear the floor.
	var split_count := _split_big(rooms)
	if split_count > 0:
		features.append("split×%d" % split_count)

	# SLIVER RULE (#5, Q3): a Room that fails the fightable floor is merged
	# into the neighbour it shares the longest wall with (never the corridor),
	# and whatever still fails is filled solid — machinery bulk behind the
	# hull plating.
	var repair := _repair_slivers(rooms)
	if repair.merged > 0:
		features.append("merged×%d" % repair.merged)
	if repair.filled > 0:
		features.append("solid×%d" % repair.filled)
	var fit := _fit_count(rooms, ROOM_BAND[ship_class])
	if fit.split > 0:
		features.append("fit-split×%d" % fit.split)
	if fit.merged > 0:
		features.append("fit-merge×%d" % fit.merged)

	# STITCH: union-find over seeded doors, then punch extra doors through
	# shared walls until every room is reachable. Guarantees connectivity for
	# any hull the mass union produced.
	var doors := _stitch(rooms, seeded, rng)
	var stranded := 0
	for room: Dictionary in rooms:
		if room.get("stranded", false):
			stranded += 1
	if stranded > 0:
		features.append("stranded×%d" % stranded)

	var out_rooms: Array[Dictionary] = []
	for room: Dictionary in rooms:
		if room.tiles.is_empty():
			continue
		out_rooms.append({rects = _rects_from_tiles(room.tiles), role = room.role,
				corridor = room.get("corridor", false)})

	var sentence := "%s / %s" % [arch, skeleton]
	if not features.is_empty():
		sentence += " / " + ", ".join(features)
	return {rooms = out_rooms, doors = doors, sentence = sentence}


## A doorway through a full-width band wall, landing anywhere legal along it.
static func _chain_door(hull_rows: Array, wall_y: int, rng: RandomNumberGenerator) -> Dictionary:
	var cand: Array = []
	for a: Vector2i in hull_rows[wall_y - 1]:
		for b: Vector2i in hull_rows[wall_y + 1]:
			var x0 := maxi(a.x, b.x) + 1
			var x1 := mini(a.y, b.y) - 3
			if x1 >= x0:
				cand.append(Vector2i(x0, x1))
	if cand.is_empty():
		return {}
	var c: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
	return {tile = Vector2i(rng.randi_range(c.x, c.y), wall_y), horizontal = true, width = 2}


## Merge a list of [x0, x1) intervals; touching or overlapping become one.
static func _merge_iv(list: Array) -> Array:
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var out: Array = []
	for iv: Vector2i in list:
		if out.is_empty() or iv.x > int(out[out.size() - 1].y):
			out.append(iv)
		else:
			var last: Vector2i = out[out.size() - 1]
			last.y = maxi(last.y, iv.y)
			out[out.size() - 1] = last
	return out


## Remove [cut.x, cut.y) from every interval, dropping slivers under 1 tile.
static func _cut_iv(list: Array, cut: Vector2i) -> Array:
	var out: Array = []
	for iv: Vector2i in list:
		if cut.y <= iv.x or cut.x >= iv.y:
			out.append(iv)
			continue
		if cut.x - iv.x >= 1:
			out.append(Vector2i(iv.x, cut.x))
		if iv.y - cut.y >= 1:
			out.append(Vector2i(cut.y, iv.y))
	return out


## Connectivity guarantee: keep the seeded doors that land between two rooms,
## then union-find the room graph and punch doors through shared walls until
## one component remains. A room with no reachable neighbour is deleted.
static func _stitch(rooms: Array[Dictionary], seeded: Array[Dictionary],
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var owner := {}
	for i in rooms.size():
		for t: Vector2i in rooms[i].tiles:
			owner[t] = i
	var parent: Array[int] = []
	for i in rooms.size():
		parent.append(i)
	var find := func(start: int) -> int:
		var r := start
		while parent[r] != r:
			r = parent[r]
		var i := start
		while parent[i] != r:
			var nxt: int = parent[i]
			parent[i] = r
			i = nxt
		return r

	var doors: Array[Dictionary] = []
	for d: Dictionary in seeded:
		var across := Vector2i(0, 1) if d.horizontal else Vector2i(1, 0)
		var a: int = owner.get(d.tile - across, -1)
		var b: int = owner.get(d.tile + across, -1)
		if a < 0 or b < 0 or owner.has(d.tile):
			continue
		doors.append(d)
		parent[find.call(a)] = find.call(b)

	var guard := rooms.size() * 2
	while guard > 0:
		guard -= 1
		var groups := {}
		for i in rooms.size():
			if not rooms[i].tiles.is_empty():
				groups[find.call(i)] = true
		if groups.size() <= 1:
			break
		var cands: Array = []
		for i in rooms.size():
			for t: Vector2i in rooms[i].tiles:
				for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
					var w: Vector2i = t + step
					if owner.has(w):
						continue
					var j: int = owner.get(t + step * 2, -1)
					if j >= 0 and find.call(j) != find.call(i):
						cands.append({tile = w, horizontal = step.y == 1, a = i, b = j})
		if cands.is_empty():
			# Unreachable rooms: delete them rather than strand the walker.
			var main: int = find.call(0)
			for i in rooms.size():
				if find.call(i) != main and not rooms[i].tiles.is_empty():
					rooms[i].tiles = {}
					rooms[i].stranded = true
			break
		var pick: Dictionary = cands[rng.randi_range(0, cands.size() - 1)]
		var across := Vector2i(0, 1) if pick.horizontal else Vector2i(1, 0)
		var perp := Vector2i(1, 0) if pick.horizontal else Vector2i(0, 1)
		var tile: Vector2i = pick.tile
		var width := 1
		var t2: Vector2i = tile + perp
		if not owner.has(t2) and owner.has(t2 - across) and owner.has(t2 + across):
			width = 2
		else:
			t2 = tile - perp
			if not owner.has(t2) and owner.has(t2 - across) and owner.has(t2 + across):
				tile = t2
				width = 2
		doors.append({tile = tile, horizontal = pick.horizontal, width = width})
		parent[find.call(pick.a)] = find.call(pick.b)
	return doors


## Widest single interval on a hull row.
static func _row_width(ivs: Array) -> int:
	var w := 0
	for iv: Vector2i in ivs:
		w = maxi(w, iv.y - iv.x)
	return w


## Side of the largest axis-aligned square inside the tile set.
static func _largest_square(tiles: Dictionary) -> int:
	var best := 0
	var memo := {}
	var keys: Array = tiles.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for t: Vector2i in keys:
		var v: int = 1 + mini(memo.get(t + Vector2i.UP, 0),
				mini(memo.get(t + Vector2i.LEFT, 0), memo.get(t + Vector2i(-1, -1), 0)))
		memo[t] = v
		best = maxi(best, v)
	return best


## The fightable floor from #12: inscribed 10x10 core AND >= 140 tiles.
static func _passes_floor(tiles: Dictionary) -> bool:
	return tiles.size() >= FLOOR_AREA and _largest_square(tiles) >= FIGHT_CORE


## Try to cut one Room along the long axis of its bounding box (a few
## offsets) so every piece clears the floor. Returns the pieces, or [] if no
## cut works.
static func _try_split(tiles: Dictionary) -> Array[Dictionary]:
	var b := _bounds(tiles)
	var along_x: bool = b.size.x >= b.size.y
	var mid: int = (b.position.x + b.end.x) / 2 if along_x else (b.position.y + b.end.y) / 2
	for off: int in [0, -1, 1, -2, 2, -3, 3]:
		var cut := mid + off
		var rest := {}
		for t: Vector2i in tiles:
			if (t.x if along_x else t.y) != cut:
				rest[t] = true
		var parts := _components(rest)
		if parts.size() < 2:
			continue
		var all_ok := true
		for p: Dictionary in parts:
			if not _passes_floor(p):
				all_ok = false
				break
		if all_ok:
			return parts
	return []


## Rooms over the ceiling are cut if every resulting piece clears the floor.
static func _split_big(rooms: Array[Dictionary]) -> int:
	var count := 0
	var i := 0
	while i < rooms.size():
		var room: Dictionary = rooms[i]
		i += 1
		if room.get("corridor", false) or room.tiles.size() <= CEILING_AREA:
			continue
		var parts := _try_split(room.tiles)
		if parts.is_empty():
			continue
		room.tiles = parts[0]
		for k in range(1, parts.size()):
			rooms.append({tiles = parts[k], role = room.role})
		count += 1
	return count


## Merge Room i into the neighbour it shares the longest wall with (never the
## corridor, never over `cap`). The shared wall tiles become floor. Returns
## false if no neighbour qualifies.
static func _merge_into_neighbour(rooms: Array[Dictionary], i: int, cap: int) -> bool:
	var owner := _owner_map(rooms)
	var shared := {}
	for t: Vector2i in rooms[i].tiles:
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var w := t + step
			if owner.has(w):
				continue
			var j: int = owner.get(w + step, -1)
			if j < 0 or j == i or rooms[j].get("corridor", false):
				continue
			if not shared.has(j):
				shared[j] = {}
			shared[j][w] = true
	var best := -1
	var best_len := 0
	for j: int in shared:
		var n: int = shared[j].size()
		if n >= 3 and n > best_len and rooms[i].tiles.size() + rooms[j].tiles.size() + n <= cap:
			best = j
			best_len = n
	if best < 0:
		return false
	for t: Vector2i in rooms[i].tiles:
		rooms[best].tiles[t] = true
	for w: Vector2i in shared[best]:
		rooms[best].tiles[w] = true
	rooms[i].tiles = {}
	return true


## Merge failing patches into a neighbour; fill whatever still fails solid.
static func _repair_slivers(rooms: Array[Dictionary]) -> Dictionary:
	var merged := 0
	var filled := 0
	var changed := true
	while changed:
		changed = false
		# Smallest failing patch first, so slivers glue onto real Rooms
		# rather than onto each other's failures.
		var failing: Array[int] = []
		for i in rooms.size():
			if not rooms[i].tiles.is_empty() and not rooms[i].get("corridor", false) \
					and not _passes_floor(rooms[i].tiles):
				failing.append(i)
		failing.sort_custom(func(a: int, b: int) -> bool: return rooms[a].tiles.size() < rooms[b].tiles.size())
		for i in failing:
			if _merge_into_neighbour(rooms, i, CEILING_AREA):
				merged += 1
				changed = true
				break
	for room: Dictionary in rooms:
		if not room.tiles.is_empty() and not room.get("corridor", false) and not _passes_floor(room.tiles):
			room.tiles = {}
			filled += 1
	return {merged = merged, filled = filled}


## COUNT FIT (#5, Q1): under the band, split the largest Rooms; over it, merge
## the smallest into a neighbour. Returns {split, merged}; the caller rerolls
## only if the count is still out.
static func _fit_count(rooms: Array[Dictionary], band: Vector2i) -> Dictionary:
	var split := 0
	var merged := 0
	var guard := 40
	while guard > 0:
		guard -= 1
		var live: Array[int] = []
		for i in rooms.size():
			if not rooms[i].tiles.is_empty() and not rooms[i].get("corridor", false):
				live.append(i)
		live.sort_custom(func(a: int, b: int) -> bool: return rooms[a].tiles.size() > rooms[b].tiles.size())
		if live.size() < band.x:
			var done := false
			for i in live:
				var parts := _try_split(rooms[i].tiles)
				if parts.is_empty():
					continue
				rooms[i].tiles = parts[0]
				for k in range(1, parts.size()):
					rooms.append({tiles = parts[k], role = rooms[i].role})
				split += 1
				done = true
				break
			if not done:
				break
		elif live.size() > band.y:
			live.reverse()
			var done := false
			for cap: int in [CEILING_AREA, CEILING_AREA + 60]:
				for i in live:
					if _merge_into_neighbour(rooms, i, cap):
						merged += 1
						done = true
						break
				if done:
					break
			if not done:
				break
		else:
			break
	return {split = split, merged = merged}


static func _owner_map(rooms: Array[Dictionary]) -> Dictionary:
	var owner := {}
	for i in rooms.size():
		for t: Vector2i in rooms[i].tiles:
			owner[t] = i
	return owner


static func _bounds(tiles: Dictionary) -> Rect2i:
	var x0 := 1 << 30
	var y0 := 1 << 30
	var x1 := -(1 << 30)
	var y1 := -(1 << 30)
	for t: Vector2i in tiles:
		x0 = mini(x0, t.x)
		y0 = mini(y0, t.y)
		x1 = maxi(x1, t.x + 1)
		y1 = maxi(y1, t.y + 1)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


## Split a tile set into 4-connected components.
static func _components(tiles: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for start: Vector2i in tiles:
		if seen.has(start):
			continue
		var comp := {start: true}
		seen[start] = true
		var frontier: Array[Vector2i] = [start]
		while not frontier.is_empty():
			var t: Vector2i = frontier.pop_back()
			for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var n := t + step
				if tiles.has(n) and not seen.has(n):
					seen[n] = true
					comp[n] = true
					frontier.append(n)
		out.append(comp)
	return out




## Decompose a tile set into maximal rects: per-row runs, merged with the
## identical run directly above.
static func _rects_from_tiles(tiles: Dictionary) -> Array[Rect2i]:
	var rows := {}
	for t: Vector2i in tiles:
		if not rows.has(t.y):
			rows[t.y] = []
		rows[t.y].append(t.x)
	var ys: Array = rows.keys()
	ys.sort()
	var out: Array[Rect2i] = []
	var open := {}
	for y_idx in ys.size() + 1:
		var y := 0
		var runs: Array[Vector2i] = []
		if y_idx < ys.size():
			y = ys[y_idx]
			var xs: Array = rows[y]
			xs.sort()
			var start: int = xs[0]
			var prev: int = xs[0]
			for i in range(1, xs.size()):
				if xs[i] != prev + 1:
					runs.append(Vector2i(start, prev + 1))
					start = xs[i]
				prev = xs[i]
			runs.append(Vector2i(start, prev + 1))
		var contiguous: bool = y_idx > 0 and y_idx < ys.size() and y == int(ys[y_idx - 1]) + 1
		var next_open := {}
		for r in runs:
			var key := "%d:%d" % [r.x, r.y]
			if contiguous and open.has(key):
				var idx: int = open[key]
				var grown: Rect2i = out[idx]
				grown.size.y += 1
				out[idx] = grown
				next_open[key] = idx
			else:
				out.append(Rect2i(r.x, y, r.y - r.x, 1))
				next_open[key] = out.size() - 1
		open = next_open
	return out


## Maximal rects covering rows [y0, y1) between per-row bounds (xmax
## exclusive); rows narrower than 4 tiles are left to the walls.
static func _runs(y0: int, y1: int, xmin: Callable, xmax: Callable) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var run_start := -1
	var cur := Vector2i.ZERO
	for y in range(y0, y1 + 1):
		var span := Vector2i(xmin.call(y), xmax.call(y)) if y < y1 else Vector2i(0, -1)
		var valid: bool = y < y1 and span.y - span.x >= 4
		if run_start >= 0 and (not valid or span != cur):
			out.append(Rect2i(cur.x, run_start, cur.y - cur.x, y - run_start))
			run_start = -1
		if valid and run_start < 0:
			run_start = y
			cur = span
	return out


## A row (with the row after it inside the range too) where [param edge] is
## unchanged, preferring the middle — a safe two-tile door spot.
static func _steady_row(y0: int, y1: int, edge: Callable) -> int:
	var best := y0
	for y in range(y0, y1 - 1):
		if edge.call(y) == edge.call(y + 1):
			best = y
			if y >= (y0 + y1) / 2:
				return y
	return best


## Longest run of equal values in widths[y0..y1) as (start, end).
static func _longest_equal_run(widths: Array[int], y0: int, y1: int) -> Vector2i:
	var best := Vector2i(y0, y0)
	var start := y0
	for y in range(y0 + 1, y1 + 1):
		if y == y1 or widths[y] != widths[start]:
			if y - start > best.y - best.x:
				best = Vector2i(start, y)
			start = y
	return best


## Width envelope along the hull, 0=fore 1=aft: narrow nose, beam just aft of
## midship, moderate tail. The pow skews the peak aftward.
static func _envelope(t: float) -> float:
	return 0.45 + 0.55 * sin(PI * pow(t, 0.75))


## Recipe D: the hull as many thin slices under a smooth width envelope plus
## per-slice jitter, so the outline steps like plating instead of slab edges.
## Slices ABUT (no wall gap): they are one hull volume, not compartments —
## abutting rooms grow no wall between them, so the walk is one open space.
static func _stepped(ship_class: StringName, rng: RandomNumberGenerator) -> Array[Rect2i]:
	var target: int = AREA[ship_class] * rng.randf_range(0.9, 1.1)
	var beam := _beam(target, rng)
	var length := int(round(target / (0.75 * beam)))

	var out: Array[Rect2i] = []
	var y := 0
	var area := 0
	while area < target:
		var l := rng.randi_range(3, 5)
		var t := clampf(float(y) / maxf(float(length), 1.0), 0.0, 1.0)
		var jitter := rng.randi_range(-1, 1) * 2
		var w := clampi(_even(int(round(beam * (0.35 + 0.65 * sin(PI * pow(t, 0.7))))) + jitter),
				MIN_W, beam)
		out.append(Rect2i(SPINE - w / 2, y, w, l))
		y += l
		area += w * l
	return out


## Recipe E: a fore-aft corridor down the spine with compartments hanging off
## it port and starboard, capped by a full-width bridge fore and engine aft.
## The corridor is the connector; the stepped flank widths shape the outline.
## Rect order convention (make_layout relies on it): 0 fore cap, 1 corridor,
## 2 aft cap, then compartments in port/starboard pairs.
static func _spine_corridor(ship_class: StringName, rng: RandomNumberGenerator) -> Array[Rect2i]:
	var target: int = AREA[ship_class] * rng.randf_range(0.9, 1.1)
	var beam := _beam(target, rng)
	var cw := 4 if ship_class == &"small" else 6

	var nose_w := clampi(_even(int(round(beam * rng.randf_range(0.5, 0.65)))), MIN_W + 2, beam)
	var nose_l := rng.randi_range(8, 12)
	var tail_w := clampi(_even(int(round(beam * rng.randf_range(0.55, 0.75)))), MIN_W + 2, beam)
	var tail_l := rng.randi_range(8, 12)

	# Flanked rows fill the middle until the area target is met.
	var rows: Array[Vector2i] = []  # (row height, flank width)
	var area := nose_w * nose_l + tail_w * tail_l
	var mid_len := 0
	var guess_len := maxi(int(round(target / (0.8 * beam))) - nose_l - tail_l, 12)
	while area < target - tail_w * tail_l / 2:
		var h := rng.randi_range(MIN_L, MIN_L + 4)
		var t := clampf(float(mid_len) / float(guess_len), 0.0, 1.0)
		var jitter := rng.randi_range(-1, 1) * 2
		var flank := (clampi(_even(int(round(beam * _envelope(lerpf(0.15, 0.85, t))))) + jitter,
				cw + 2 + 2 * MIN_W, beam) - cw - 2) / 2
		rows.append(Vector2i(h, flank))
		mid_len += h + 1
		area += 2 * flank * h + cw * h

	var out: Array[Rect2i] = []
	out.append(Rect2i(SPINE - nose_w / 2, 0, nose_w, nose_l))
	var mid_y := nose_l + 1
	out.append(Rect2i(SPINE - cw / 2, mid_y, cw, mid_len - 1))
	out.append(Rect2i(SPINE - tail_w / 2, mid_y + mid_len, tail_w, tail_l))
	var y := mid_y
	for row in rows:
		out.append(Rect2i(SPINE - cw / 2 - 1 - row.y, y, row.y, row.x))
		out.append(Rect2i(SPINE + cw / 2 + 1, y, row.y, row.x))
		y += row.x + 1
	return out


## ASCII plan of a section list: '#' wall, '.' floor, fore at the LEFT (the
## ship is printed rotated 90 degrees: terminal glyphs are ~2:1 tall, so a
## sideways ship both fits the screen and reads in true proportion).
## Same wall rule as ShipBuilder3D: one-tile ring minus anything that is floor.
static func ascii(rects: Array[Rect2i]) -> String:
	var floors := {}
	for r in rects:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				floors[Vector2i(x, y)] = true
	var walls := {}
	for r in rects:
		var ring := r.grow(1)
		for x in range(ring.position.x, ring.end.x):
			for y in range(ring.position.y, ring.end.y):
				var t := Vector2i(x, y)
				if not floors.has(t):
					walls[t] = true

	var bounds: Rect2i = rects[0].grow(1)
	for r in rects:
		bounds = bounds.merge(r.grow(1))
	var lines: Array[String] = []
	for x in range(bounds.position.x, bounds.end.x):
		var line := ""
		for y in range(bounds.position.y, bounds.end.y):
			var t := Vector2i(x, y)
			if walls.has(t):
				line += "#"
			elif floors.has(t):
				line += "."
			else:
				line += " "
		lines.append(line)
	return "\n".join(lines)


static func area_of(rects: Array[Rect2i]) -> int:
	var a := 0
	for r in rects:
		a += r.size.x * r.size.y
	return a


## A walkable ShipLayout: one Room per section, doorways punched through every
## seam wall. Fore floor reads bright (bridge), aft reads engine-orange, so
## orientation can be judged from inside.
static func make_layout(recipe: String, ship_class: StringName, seed_: int) -> ShipLayout:
	var rects := sections(recipe, ship_class, seed_)
	var layout := ShipLayout.new()
	layout.gen_seed = seed_
	layout.ship_name = "Proto %s %s #%d" % [recipe, ship_class, seed_]

	if recipe == "E":
		return _corridor_layout(rects, layout)
	if recipe == "F":
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s#%d" % [recipe, seed_])
		return _hull_pack_layout(_hull_pack(ship_class, rng), layout)

	# Stacked recipes: every seam gets a doorway. D's short slices get wide
	# openings so the string of bands reads as one hull, not a door maze.
	var door_w := 5 if recipe == "D" else 3
	for i in rects.size():
		var room := RoomData.new()
		room.rect = rects[i]
		room.role = &"bridge" if i == 0 else (&"engine" if i == rects.size() - 1 else &"cargo")
		layout.rooms.append(room)
	for a in rects.size():
		for b in range(a + 1, rects.size()):
			var door := _seam_door(a, b, rects[a], rects[b], door_w)
			if door != null:
				layout.doors.append(door)
	layout.entry_room = 0
	return layout


## Recipe E walk-layout: rect 0 is the bridge cap, 1 the corridor, 2 the
## engine cap, the rest flanking compartments. Everything doors onto the
## corridor; compartments do not connect to each other.
static func _corridor_layout(rects: Array[Rect2i], layout: ShipLayout) -> ShipLayout:
	const ROLES: Array[StringName] = [&"bridge", &"quarters", &"engine"]
	for i in rects.size():
		var room := RoomData.new()
		room.rect = rects[i]
		room.role = ROLES[i] if i < 3 else &"cargo"
		layout.rooms.append(room)

	var cap_door_w: int = mini(3, rects[1].size.x - 2)
	layout.doors.append(_seam_door(0, 1, rects[0], rects[1], cap_door_w))
	layout.doors.append(_seam_door(2, 1, rects[2], rects[1], cap_door_w))
	for i in range(3, rects.size()):
		var door := _seam_door(i, 1, rects[i], rects[1], 3)
		if door != null:
			layout.doors.append(door)
	layout.entry_room = 0
	return layout


## A doorway through the one-tile wall between two rects, or null when they
## don't share a usable seam. Handles stacked (vertical) and flanking
## (horizontal) neighbours.
## Recipe F walk-layout: one RoomData per rect (abutting rects of the same
## room stay open to each other), doors resolved to whatever rects flank them.
static func _hull_pack_layout(plan: Dictionary, layout: ShipLayout) -> ShipLayout:
	layout.ship_name += " — " + plan.sentence
	for room: Dictionary in plan.rooms:
		for rect: Rect2i in room.rects:
			var data := RoomData.new()
			data.rect = rect
			data.role = room.role
			layout.rooms.append(data)
	for d: Dictionary in plan.doors:
		var door := DoorData.new()
		door.tile = d.tile
		door.horizontal = d.horizontal
		door.width = d.width
		var across := Vector2i(0, 1) if d.horizontal else Vector2i(1, 0)
		door.room_a = layout.room_at(d.tile - across)
		door.room_b = layout.room_at(d.tile + across)
		if door.room_a < 0 or door.room_b < 0:
			push_warning("proto: door at %s flanks no room, dropped" % d.tile)
			continue
		layout.doors.append(door)
	# Board at the stern, walk forward — engine rects sit at the tail of the
	# room list.
	layout.entry_room = layout.rooms.size() - 1
	return layout


## ASCII plan of a built layout: '#' wall, '.' floor, '+' doorway, fore at
## the LEFT (rotated 90 degrees so terminal glyph aspect shows true
## proportion). Wall rule matches ShipBuilder3D: ring minus floor.
static func ascii_layout(layout: ShipLayout) -> String:
	var floors := layout.floor_tiles()
	var door_tiles := {}
	for door in layout.doors:
		for t in door.tiles():
			door_tiles[t] = true
	var walls := {}
	var bounds: Rect2i = layout.rooms[0].rect.grow(1)
	for room in layout.rooms:
		bounds = bounds.merge(room.rect.grow(1))
		var ring := room.rect.grow(1)
		for x in range(ring.position.x, ring.end.x):
			for y in range(ring.position.y, ring.end.y):
				var t := Vector2i(x, y)
				if not floors.has(t):
					walls[t] = true
	var lines: Array[String] = []
	for x in range(bounds.position.x, bounds.end.x):
		var line := ""
		for y in range(bounds.position.y, bounds.end.y):
			var t := Vector2i(x, y)
			if door_tiles.has(t):
				line += "+"
			elif walls.has(t):
				line += "#"
			elif floors.has(t):
				line += "."
			else:
				line += " "
		lines.append(line)
	return "\n".join(lines)


static func _seam_door(a: int, b: int, ra: Rect2i, rb: Rect2i, door_w := 3) -> DoorData:
	var DOOR_W := door_w
	var door := DoorData.new()
	door.room_a = a
	door.room_b = b
	door.width = DOOR_W
	if ra.end.y + 1 == rb.position.y or rb.end.y + 1 == ra.position.y:
		var lo: int = maxi(ra.position.x, rb.position.x)
		var hi: int = mini(ra.end.x, rb.end.x)
		if hi - lo < DOOR_W + 2:
			return null
		door.horizontal = true
		door.tile = Vector2i((lo + hi) / 2 - DOOR_W / 2, ra.end.y if ra.end.y + 1 == rb.position.y else rb.end.y)
		return door
	if ra.end.x + 1 == rb.position.x or rb.end.x + 1 == ra.position.x:
		var lo: int = maxi(ra.position.y, rb.position.y)
		var hi: int = mini(ra.end.y, rb.end.y)
		if hi - lo < DOOR_W + 2:
			return null
		door.horizontal = false
		door.tile = Vector2i(ra.end.x if ra.end.x + 1 == rb.position.x else rb.end.x, (lo + hi) / 2 - DOOR_W / 2)
		return door
	return null
