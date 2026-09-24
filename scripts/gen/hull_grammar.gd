class_name HullGrammar
extends RefCounted
## Stage 2 of the generator: the Hull silhouette, rolled as a grammar. A main
## Mass shaped by an archetype, zero to two secondary Masses hung off one
## side, features (prongs, split tail), a Skeleton (spine, ring or chain) and
## the fore-aft bands the packer fills. Deliberately asymmetric: the two
## flanks are different shapes, not a wobbled mirror.
##
## Ported from the walk-approved "hull-pack" recipe on proto/hull-silhouette.

## The fore-aft axis every Hull is built around. Rows run fore (low y) to aft.
const SPINE := 64

const ARCHETYPES: Array[StringName] = [&"wedge", &"hammerhead", &"saucer", &"block", &"boomtail"]
const MASS_KINDS: Array[String] = ["side pod", "cockpit boom", "aft wing", "blister"]


## Everything the packer needs to know about a rolled Hull.
class Hull:
	extends RefCounted
	var arch: StringName
	var skeleton: StringName
	## Per row, a merged list of [x0, x1) floor intervals.
	var rows: Array = []
	var length := 0
	var beam := 0
	## Skeleton axis x: the corridor's centre.
	var cx := SPINE
	## Fore-aft bands: [prongs) [bridge_y0, mid_y0-1) wall [mid_y0, mid_y1) wall [engine).
	var bridge_y0 := 0
	var mid_y0 := 0
	var mid_y1 := 0
	## One past the Engine band's last row; rows beyond it are a Bulk tail.
	var engine_y1 := 0
	var prong_len := 0
	var notch_c := SPINE
	var tail_len := 0
	## Ring or plaza widening of the corridor: half-width and row span.
	var hub_half := 0
	var hub_y0 := 0
	var hub_y1 := 0
	## The ring's core Room (the Bridge); empty unless the Skeleton is a ring.
	var core := Rect2i()
	var features: Array[String] = []

	## The corridor's leftmost floor x at a row.
	func corridor_xmin(y: int) -> int:
		return cx - hub_half if hub_half > 0 and y >= hub_y0 and y < hub_y1 else cx - 2

	## One past the corridor's rightmost floor x at a row.
	func corridor_xmax(y: int) -> int:
		return cx + hub_half if hub_half > 0 and y >= hub_y0 and y < hub_y1 else cx + 2

	## The widest row in [y0, y1), clipped to the Hull.
	func widest(y0: int, y1: int) -> int:
		var w := 0
		for y in range(maxi(y0, 0), mini(y1, rows.size())):
			w = maxi(w, TileShapes.row_width(rows[y]))
		return w

	## The roll as a sentence: archetype, Skeleton and features.
	func sentence() -> String:
		var out := "%s / %s" % [arch, skeleton]
		if not features.is_empty():
			out += " / " + ", ".join(features)
		return out


## Hull width envelope per archetype: t 0 = fore, 1 = aft; result × beam.
static func envelope(arch: StringName, t: float) -> float:
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


## The archetype and length-to-beam ratio for a ship: rolled once per ship,
## so a resize keeps the same silhouette family and the Room count moves
## with the area instead of jumping between shapes.
static func roll_archetype(ship_class: StringName, rng: RandomNumberGenerator) -> Dictionary:
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
	return {arch = arch, aspect = aspect}


## Roll a Hull for [param ship_class] of the given [param archetype] (from
## [method roll_archetype]) enclosing about [param target_area] floor tiles.
static func roll(ship_class: StringName, rng: RandomNumberGenerator, target_area: int,
		archetype: Dictionary) -> Hull:
	var hull := Hull.new()
	hull.arch = archetype.arch
	var aspect: float = archetype.aspect
	hull.beam = clampi(_even(int(round(sqrt(target_area / (0.8 * aspect))))), 16, 56)
	hull.length = maxi(int(round(target_area / (0.8 * hull.beam))), 30)

	_roll_main_mass(hull, rng)
	_roll_secondary_masses(hull, ship_class, rng)
	_roll_bands(hull, ship_class, rng)
	_roll_skeleton(hull, ship_class, rng)
	return hull


## The main Mass: the archetype envelope with independent per-side bias waves
## and jitter, laid down in short runs of equal rows.
static func _roll_main_mass(hull: Hull, rng: RandomNumberGenerator) -> void:
	var amp_p := rng.randf_range(0.0, 0.18)
	var amp_s := rng.randf_range(0.0, 0.18)
	var ph_p := rng.randf_range(0.0, TAU)
	var ph_s := rng.randf_range(0.0, TAU)
	var beam := hull.beam
	while hull.rows.size() < hull.length:
		var run := rng.randi_range(2, 4)
		var t := float(hull.rows.size()) / float(hull.length)
		var base := beam * envelope(hull.arch, t) / 2.0
		var hp := clampi(int(round(base * (1.0 + amp_p * sin(TAU * t + ph_p)))) + rng.randi_range(-1, 1), 4, beam)
		var hs := clampi(int(round(base * (1.0 + amp_s * sin(TAU * t + ph_s)))) + rng.randi_range(-1, 1), 4, beam)
		for i in run:
			hull.rows.append([Vector2i(SPINE - hp, SPINE + hs)])
	hull.rows.resize(hull.length)


## Zero to two secondary Masses, each with its own size and off-axis
## placement, so one flank's shape says nothing about the other's.
static func _roll_secondary_masses(hull: Hull, ship_class: StringName, rng: RandomNumberGenerator) -> void:
	var beam := hull.beam
	var length := hull.length
	var budget := rng.randi_range(0, 1) if ship_class == &"small" else rng.randi_range(1, 2)
	for n in budget:
		var kind: String = MASS_KINDS[rng.randi_range(0, 3)]
		hull.features.append(kind)
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
		@warning_ignore("integer_division")
		var mid_half: int = beam / 2
		var off: int = sgn * int(mid_half * rng.randf_range(0.55, 1.0))
		for y in range(m_y0, mini(m_y0 + m_len, length)):
			var mt := float(y - m_y0) / float(maxi(m_len, 1))
			var mh := clampi(int(round(m_beam / 2.0 * (0.55 + 0.45 * sin(PI * mt)))) + rng.randi_range(-1, 1), 3, m_beam)
			var c := SPINE + off
			hull.rows[y] = TileShapes.merge_intervals(hull.rows[y] + [Vector2i(c - mh, c + mh)])


## Fore-aft bands and the notch features: prongs cut into the nose, a split
## tail cut into the stern. The Bridge band starts at the first row wide
## enough to hold a Fight Core; rows forward of it are solid nose.
static func _roll_bands(hull: Hull, ship_class: StringName, rng: RandomNumberGenerator) -> void:
	# Both caps must hold a Fight Core, so neither band rolls under 10 deep.
	var bridge_len := rng.randi_range(10, 14)
	var engine_len := rng.randi_range(10, 13)
	var notch_w := 0
	var wants_prongs: bool = hull.arch != &"saucer" and hull.arch != &"hammerhead" \
			and ship_class != &"small"
	if wants_prongs and rng.randf() < 0.45:
		hull.features.append("prongs")
		hull.prong_len = clampi(int(hull.length * rng.randf_range(0.12, 0.2)), 6, 14)
		notch_w = rng.randi_range(2, 4) * 2
		hull.notch_c = SPINE + rng.randi_range(-5, 5)
	var tail_w := 0
	var tail_c := SPINE
	if hull.arch != &"boomtail" and engine_len >= 9 and rng.randf() < 0.35:
		hull.features.append("split tail")
		hull.tail_len = clampi(int(hull.length * rng.randf_range(0.08, 0.14)), 4, engine_len - 4)
		tail_w = rng.randi_range(2, 4) * 2
		tail_c = SPINE + rng.randi_range(-5, 5)

	# Notches: guarantee lobes both sides of the cut, then cut.
	@warning_ignore("integer_division")
	if hull.prong_len > 0:
		var half: int = notch_w / 2
		for y in range(0, mini(hull.prong_len + 3, hull.length)):
			hull.rows[y] = TileShapes.merge_intervals(hull.rows[y] + [Vector2i(hull.notch_c - half - 5, hull.notch_c + half + 5)])
		for y in hull.prong_len:
			hull.rows[y] = TileShapes.cut_intervals(hull.rows[y], Vector2i(hull.notch_c - half, hull.notch_c + half))
	@warning_ignore("integer_division")
	if hull.tail_len > 0:
		var half: int = tail_w / 2
		for y in range(maxi(hull.length - hull.tail_len - 3, 0), hull.length):
			hull.rows[y] = TileShapes.merge_intervals(hull.rows[y] + [Vector2i(tail_c - half - 5, tail_c + half + 5)])
		for y in range(hull.length - hull.tail_len, hull.length):
			hull.rows[y] = TileShapes.cut_intervals(hull.rows[y], Vector2i(tail_c - half, tail_c + half))

	# The Bridge band starts at the first row wide enough for a Fight Core
	# (rows forward of it are solid nose or prong notches) and the Engine
	# band ends at the last such row (a thinner tail is Bulk). Neither is so
	# deep for its width that no cut brings it under the ceiling, and the
	# Engine band is fed rows until its floor is comfortably over the minimum.
	var b0 := hull.prong_len + 1 if hull.prong_len > 0 else 0
	while b0 < hull.length - 1 and TileShapes.row_width(hull.rows[b0]) < 12:
		b0 += 1
	bridge_len = RoomPacker.band_depth_cap(bridge_len, hull.widest(b0, b0 + bridge_len))
	var e1 := hull.length
	while e1 > 1 and TileShapes.row_width(hull.rows[e1 - 1]) < 12:
		e1 -= 1
	engine_len = RoomPacker.band_depth_cap(engine_len, hull.widest(e1 - engine_len, e1))
	while engine_len < 16 and _floor_area(hull, e1 - engine_len, e1) < RoomData.MIN_AREA + 20:
		engine_len += 1
	hull.bridge_y0 = b0
	hull.mid_y0 = b0 + bridge_len + 1
	hull.mid_y1 = e1 - engine_len - 1
	hull.engine_y1 = e1
	# The mid band holds two bays and a wall at the least.
	while hull.mid_y1 - hull.mid_y0 < 21:
		hull.rows.insert(e1, (hull.rows[e1 - 1] as Array).duplicate())
		hull.length += 1
		e1 += 1
		hull.mid_y1 = e1 - engine_len - 1
		hull.engine_y1 = e1


## Floor tiles in the widest interval of every row in [y0, y1).
static func _floor_area(hull: Hull, y0: int, y1: int) -> int:
	var a := 0
	for y in range(maxi(y0, 0), mini(y1, hull.rows.size())):
		a += TileShapes.row_width(hull.rows[y])
	return a


## The Skeleton: an off-axis corridor strip added to the Hull so it always
## fits, then spine, ring or chain, with a ring core or a spine plaza where
## the Hull is wide enough.
static func _roll_skeleton(hull: Hull, ship_class: StringName, rng: RandomNumberGenerator) -> void:
	var co := rng.randi_range(-5, 5)
	if absi(co) >= 2:
		hull.features.append("offset corridor")
	hull.cx = SPINE + co
	var cx := hull.cx
	var m0 := hull.mid_y0
	var m1 := hull.mid_y1
	for y in range(maxi(m0 - 3, 0), mini(m1 + 3, hull.length)):
		hull.rows[y] = TileShapes.merge_intervals(hull.rows[y] + [Vector2i(cx - 4, cx + 4)])
	# Where the corridor's end Doors land, the strip must join the cap's
	# body, not a Sliver beside it: those rows are filled from the strip out
	# to the widest interval already there.
	for y in range(maxi(m0 - 3, 0), m0):
		hull.rows[y] = _bridge_to_widest(hull.rows[y], cx)
	for y in range(m1 + 1, mini(m1 + 4, hull.length)):
		hull.rows[y] = _bridge_to_widest(hull.rows[y], cx)

	var skeleton: StringName = &"spine"
	if ship_class == &"small":
		skeleton = &"chain" if rng.randf() < 0.6 else &"spine"
	elif hull.arch == &"saucer":
		skeleton = &"ring" if rng.randf() < 0.75 else &"spine"
	else:
		var roll := rng.randf()
		if roll < 0.25:
			skeleton = &"chain"
		elif roll < 0.45 and hull.beam >= 28:
			skeleton = &"ring"
	if skeleton == &"ring" and m1 - m0 < 26:
		skeleton = &"spine"
	hull.skeleton = skeleton

	@warning_ignore("integer_division")
	if skeleton == &"ring":
		# Core is the Bridge and must clear the floor: 10-12 wide, 14-16 long.
		var core_half := rng.randi_range(5, 6)
		hull.hub_half = core_half + 4
		var core_len := rng.randi_range(14, 16)
		hull.hub_y0 = m0 + (m1 - m0 - core_len - 8) / 2
		hull.hub_y1 = hull.hub_y0 + core_len + 8
		hull.core = Rect2i(cx - core_half, hull.hub_y0 + 4, core_half * 2, core_len)
	elif skeleton == &"spine" and ship_class != &"small":
		if hull.beam >= 24 and m1 - m0 >= 22 and rng.randf() < 0.7:
			hull.hub_half = 6 if hull.beam >= 28 else 5
			hull.hub_y0 = m0 + (m1 - m0) / 2 - 5
			hull.hub_y1 = mini(hull.hub_y0 + rng.randi_range(8, 12), m1)
	for y in range(hull.hub_y0, hull.hub_y1):
		hull.rows[y] = TileShapes.merge_intervals(hull.rows[y] + [Vector2i(cx - hull.hub_half - 5, cx + hull.hub_half + 5)])


## The row with its widest interval joined to the corridor strip at `cx`.
static func _bridge_to_widest(row: Array, cx: int) -> Array:
	var widest := Vector2i(cx - 4, cx + 4)
	for iv: Vector2i in row:
		if iv.y - iv.x > widest.y - widest.x:
			widest = iv
	return TileShapes.merge_intervals(row + [Vector2i(mini(cx - 4, widest.x), maxi(cx + 4, widest.y))])


## The next even number at or above `v`, so beams mirror exactly about the spine.
static func _even(v: int) -> int:
	return v if v % 2 == 0 else v + 1
