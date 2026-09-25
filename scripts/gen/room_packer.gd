class_name RoomPacker
extends RefCounted
## Stage 3 of the generator: packs Rooms against a rolled [HullGrammar.Hull].
## Rooms are tile sets first (every 4-connected patch of a band is its own
## Room) so the repairs can reason about them; rects come at the very end.
##
## Bridge fore, Engine aft, the Skeleton's corridor between them, flank bays
## banded independently per side. Then the ceiling split, the Sliver rule and
## the count fit, in that order. Ported from proto/room-packing.

const FIGHT_CORE := RoomData.FIGHT_CORE.x
const FLOOR_AREA := RoomData.MIN_AREA
const CEILING_AREA := RoomData.MAX_AREA
## Placeholder filler Roles until Role assignment lands.
const FILLER_ROLES: Array[StringName] = [&"cargo", &"quarters", &"cargo", &"medbay"]


## A Room in the making: a tile set with a Role. Emptied when it is merged
## away, filled solid or stranded.
class Patch:
	extends RefCounted
	var tiles := {}
	var role: StringName = &"quarters"
	var stranded := false
	## The Role is a packer tag that survives assignment (a ring's fore cap).
	var pinned := false
	## The floor verdict is cached against the tile count: every edit here
	## (merge, split, pod, fill) changes the count.
	var _floor_checked_at := -1
	var _floor_ok := false

	func _init(floor_tiles: Dictionary, room_role: StringName) -> void:
		tiles = floor_tiles
		role = room_role

	func is_corridor() -> bool:
		return role == &"corridor"

	func is_empty() -> bool:
		return tiles.is_empty()

	## The fightable floor as the packer sees it, on raw tiles.
	func passes_floor() -> bool:
		if tiles.size() != _floor_checked_at:
			_floor_checked_at = tiles.size()
			_floor_ok = _floor_verdict()
		return _floor_ok

	## Cheap answers first: too few tiles or too thin a box fails, a full
	## rectangle passes, and only ragged shapes need the square search.
	func _floor_verdict() -> bool:
		if tiles.size() < FLOOR_AREA:
			return false
		var box := TileShapes.bounds(tiles)
		if mini(box.size.x, box.size.y) < FIGHT_CORE:
			return false
		if tiles.size() == box.size.x * box.size.y:
			return true
		return TileShapes.largest_square(tiles) >= FIGHT_CORE


## A doorway asked for by the packer, before stitching confirms it.
class Gap:
	extends RefCounted
	var tile: Vector2i
	var horizontal: bool
	var width: int

	func _init(at: Vector2i, along_x: bool, span: int = 2) -> void:
		tile = at
		horizontal = along_x
		width = span

	func tiles() -> Array[Vector2i]:
		var step := Vector2i.RIGHT if horizontal else Vector2i.DOWN
		var out: Array[Vector2i] = []
		for i in maxi(width, 1):
			out.append(tile + step * i)
		return out


## What the packer hands the stitcher.
class Result:
	extends RefCounted
	var patches: Array[Patch] = []
	var seeded: Array[Gap] = []
	var features: Array[String] = []
	## Whether the Bridge and an Engine stand where the Skeleton's end Doors
	## open, so the ship reads fore to aft along its axis.
	var caps_on_axis := true

	## Whether a standing Room carries the Role.
	func has_role(role: StringName) -> bool:
		for p in patches:
			if not p.is_empty() and p.role == role:
				return true
		return false

	## Non-corridor Rooms still standing: what counts toward the Class band.
	func counted_rooms() -> int:
		var n := 0
		for p in patches:
			if not p.is_empty() and not p.is_corridor():
				n += 1
		return n


## Pack Rooms against [param hull] for [param ship_class], aiming its Room
## count at [param band], and report what the repairs did.
static func pack(hull: HullGrammar.Hull, ship_class: StringName, band: Vector2i,
		rng: RandomNumberGenerator) -> Result:
	var out := Result.new()
	_carve_bands(hull, rng, out)
	_engine_pods(hull, ship_class, rng, out)

	var split_count := _split_big(out.patches)
	if split_count > 0:
		out.features.append("split×%d" % split_count)
	var repair := _repair_slivers(out.patches)
	if repair.merged > 0:
		out.features.append("merged×%d" % repair.merged)
	if repair.filled > 0:
		out.features.append("solid×%d" % repair.filled)
	var fit := _fit_count(out.patches, band)
	if fit.split > 0:
		out.features.append("fit-split×%d" % fit.split)
	if fit.merged > 0:
		out.features.append("fit-merge×%d" % fit.merged)
	# A merge can leave a neighbour's remnant behind; nothing failing survives.
	var again := _repair_slivers(out.patches)
	if again.merged + again.filled > 0:
		out.features.append("re-repair×%d" % (again.merged + again.filled))
	out.caps_on_axis = _settle_caps(out.patches, hull)
	return out


## Widest a band may be in one piece and still fit under the ceiling at a
## bay's depth; wider bands are cut across into side-by-side Rooms no wider
## than [constant PIECE_WIDTH], which at 13 deep stays under the ceiling.
const MAX_BAND_WIDTH := 26
const PIECE_WIDTH := 20
## Deepest any bay rolls; a band's width is measured over this many rows so
## its cap holds however deep it ends up.
const MAX_BAND_DEPTH := 20


## The 4-connected components of the Hull floor between rows [y0, y1) and
## per-row x bounds, as tile sets. Runs narrower than 4 tiles are left to
## the walls. A band wider than [constant MAX_BAND_WIDTH] is cut across by
## wall columns into equal pieces no wider than [constant PIECE_WIDTH], the
## ceiling split done by geometry rather than search. Components are found
## by joining runs that overlap between neighbouring rows, which is far
## cheaper than a flood fill over every tile. With `axis_x` given, the cuts
## are centred on it instead, so the piece holding the Skeleton axis, where a
## cap band's Door onto the corridor lands, is a full one and any narrow
## remainder falls at the Hull's edges for the Sliver rule.
static func _region_components(hull: HullGrammar.Hull, y0: int, y1: int, lo: Callable, hi: Callable,
		axis_x: int = -1) -> Array[Dictionary]:
	var runs: Array[Vector3i] = []   # (y, x0, x1)
	var xmin := 1 << 30
	var xmax := -(1 << 30)
	for y in range(y0, y1):
		var lo_x: int = lo.call(y)
		var hi_x: int = hi.call(y)
		for iv: Vector2i in hull.rows[y]:
			var x0: int = maxi(iv.x, lo_x)
			var x1: int = mini(iv.y, hi_x)
			if x1 - x0 >= 4:
				runs.append(Vector3i(y, x0, x1))
				xmin = mini(xmin, x0)
				xmax = maxi(xmax, x1)
	var width := xmax - xmin
	if width > MAX_BAND_WIDTH:
		var walls: Array[int] = []
		if axis_x >= 0:
			@warning_ignore("integer_division")
			var half: int = PIECE_WIDTH / 2
			var x := axis_x - half - 1
			while x > xmin:
				walls.append(x)
				x -= PIECE_WIDTH + 1
			x = axis_x + half
			while x < xmax - 1:
				walls.append(x)
				x += PIECE_WIDTH + 1
		else:
			@warning_ignore("integer_division")
			var pieces: int = (width + 1 + PIECE_WIDTH) / (PIECE_WIDTH + 1)
			for k in range(1, pieces):
				@warning_ignore("integer_division")
				walls.append(xmin + (width * k) / pieces)
		for wall_x in walls:
			var cut: Array[Vector3i] = []
			for r in runs:
				if wall_x <= r.y or wall_x >= r.z:
					cut.append(r)
					continue
				if wall_x - r.y >= 1:
					cut.append(Vector3i(r.x, r.y, wall_x))
				if r.z - wall_x - 1 >= 1:
					cut.append(Vector3i(r.x, wall_x + 1, r.z))
			runs = cut
	# Union-find over runs: two runs join when on neighbouring rows with
	# overlapping x.
	var parent: Array[int] = []
	for i in runs.size():
		parent.append(i)
	var find := func(start: int) -> int:
		var r := start
		while parent[r] != r:
			r = parent[r]
		return r
	for i in runs.size():
		for j in range(i + 1, runs.size()):
			if runs[j].x > runs[i].x + 1:
				break
			if runs[j].x == runs[i].x + 1 and runs[j].y < runs[i].z and runs[i].y < runs[j].z:
				parent[find.call(i)] = find.call(j)
	var groups := {}
	for i in runs.size():
		var root: int = find.call(i)
		if not groups.has(root):
			groups[root] = {}
		var tiles: Dictionary = groups[root]
		for x in range(runs[i].y, runs[i].z):
			tiles[Vector2i(x, runs[i].x)] = true
	var out: Array[Dictionary] = []
	for root in groups:
		out.append(groups[root])
	return out


## The fore-aft bands: prong Rooms, the fore cap, the mid band by Skeleton,
## and the Engine band aft.
static func _carve_bands(hull: HullGrammar.Hull, rng: RandomNumberGenerator, out: Result) -> void:
	var neg_inf := func(_y: int) -> int: return -999
	var pos_inf := func(_y: int) -> int: return 999
	var m0 := hull.mid_y0
	var m1 := hull.mid_y1

	if hull.prong_len > 0:
		# Each prong is a Room no deeper than its width allows under the ceiling.
		var mid := func(_y: int) -> int: return hull.notch_c
		var depth := mini(hull.prong_len, depth_cap(hull.widest(0, hull.prong_len)))
		for comp in _region_components(hull, hull.prong_len - depth, hull.prong_len, neg_inf, mid):
			out.patches.append(Patch.new(comp, &"cargo"))
		for comp in _region_components(hull, hull.prong_len - depth, hull.prong_len, mid, pos_inf):
			out.patches.append(Patch.new(comp, &"cargo"))

	# The fore cap: the Bridge, or Quarters when a ring puts the Bridge at its
	# core. Its Door onto the corridor lands on the axis, so cuts centre
	# there, and only the piece on the axis carries the ring's Quarters tag.
	for comp in _region_components(hull, hull.bridge_y0, m0 - 1, neg_inf, pos_inf, hull.cx):
		var cap := Patch.new(comp, &"quarters" if hull.skeleton == &"ring" else &"bridge")
		cap.pinned = hull.skeleton == &"ring" and comp.has(Vector2i(hull.cx - 1, m0 - 2))
		out.patches.append(cap)

	if hull.skeleton == &"chain":
		_carve_chain(hull, rng, out, neg_inf, pos_inf)
	else:
		_carve_corridor(hull, rng, out, neg_inf, pos_inf)

	for comp in _region_components(hull, m1 + 1, hull.engine_y1, neg_inf, pos_inf, hull.cx):
		out.patches.append(Patch.new(comp, &"engine"))


## Chain Skeleton: full-width bands opening straight into each other.
static func _carve_chain(hull: HullGrammar.Hull, rng: RandomNumberGenerator, out: Result,
		neg_inf: Callable, pos_inf: Callable) -> void:
	var m0 := hull.mid_y0
	var m1 := hull.mid_y1
	var y := m0
	while m1 - y >= 10:
		var rolled := rng.randi_range(10, 20)
		var band_len := _band_length(rolled, depth_cap(hull.widest(y, y + MAX_BAND_DEPTH)), m1 - y)
		var role: StringName = FILLER_ROLES[rng.randi_range(0, 3)]
		for comp in _region_components(hull, y, y + band_len, neg_inf, pos_inf):
			out.patches.append(Patch.new(comp, role))
		var d := _chain_door(hull, y - 1, rng)
		if d != null:
			out.seeded.append(d)
		y += band_len + 1
	var last := _chain_door(hull, m1, rng)
	if last != null:
		out.seeded.append(last)


## A doorway through a full-width band wall, landing anywhere legal along it.
static func _chain_door(hull: HullGrammar.Hull, wall_y: int, rng: RandomNumberGenerator) -> Gap:
	var cand: Array[Vector2i] = []
	for a: Vector2i in hull.rows[wall_y - 1]:
		for b: Vector2i in hull.rows[wall_y + 1]:
			var x0 := maxi(a.x, b.x) + 1
			var x1 := mini(a.y, b.y) - 3
			if x1 >= x0:
				cand.append(Vector2i(x0, x1))
	if cand.is_empty():
		return null
	var c: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]
	return Gap.new(Vector2i(rng.randi_range(c.x, c.y), wall_y), true)


## Spine and ring Skeletons: the corridor down the middle (with its core Room
## when a ring), Bridge and Engine doors at its ends, and flank bays banded
## independently per side with a door onto the corridor each.
static func _carve_corridor(hull: HullGrammar.Hull, rng: RandomNumberGenerator, out: Result,
		neg_inf: Callable, pos_inf: Callable) -> void:
	var m0 := hull.mid_y0
	var m1 := hull.mid_y1
	var cx := hull.cx

	var corridor := {}
	for comp in _region_components(hull, m0, m1, hull.corridor_xmin, hull.corridor_xmax):
		corridor.merge(comp)
	if hull.skeleton == &"ring":
		var carve := hull.core.grow(1)
		for x in range(carve.position.x, carve.end.x):
			for y in range(carve.position.y, carve.end.y):
				corridor.erase(Vector2i(x, y))
	out.patches.append(Patch.new(corridor, &"corridor"))
	# The Doors at the corridor's ends alternate sides of its axis so none
	# faces another straight down the corridor, or across a ring's legs.
	out.seeded.append(Gap.new(Vector2i(cx - 2, m0 - 1), true))
	out.seeded.append(Gap.new(Vector2i(cx, m1), true))
	if hull.skeleton == &"ring":
		out.patches.append(Patch.new(TileShapes.tiles_of([hull.core]), &"bridge"))
		out.seeded.append(Gap.new(Vector2i(cx, hull.core.position.y - 1), true))
		out.seeded.append(Gap.new(Vector2i(cx - 2, hull.core.end.y), true))

	# Bays only, every band >= 10 deep; each side rolls short or long bays.
	var styles: Array[Vector2i] = []
	for k in 2:
		styles.append(Vector2i(10, 13) if rng.randf() < 0.5 else Vector2i(14, 20))
	if styles[0] != styles[1]:
		out.features.append("uneven flanks")
	for side_i in 2:
		var sgn: int = -1 if side_i == 0 else 1
		var style: Vector2i = styles[side_i]
		var y := m0
		while m1 - y >= 10:
			var rolled := rng.randi_range(style.x, style.y)
			var band_len := _band_length(rolled, depth_cap(_flank_width(hull, y, mini(y + MAX_BAND_DEPTH, m1), sgn)), m1 - y)
			var band_end := y + band_len
			var comps: Array[Dictionary]
			if sgn < 0:
				comps = _region_components(hull, y, band_end, neg_inf,
						func(row: int) -> int: return _flank_xmin(hull, row) - 1)
			else:
				comps = _region_components(hull, y, band_end,
						func(row: int) -> int: return _flank_xmax(hull, row) + 1, pos_inf)
			for comp in comps:
				out.patches.append(Patch.new(comp, FILLER_ROLES[rng.randi_range(0, 3)]))
				var door := _flank_door(hull, comp, sgn, y, band_end)
				if door != null:
					out.seeded.append(door)
			y = band_end + 1


## The corridor's bounds as the flanks see them: the rows just outside a hub
## count as hub rows too, so a flank never sits flush against the widened
## corridor with no wall between.
static func _flank_xmin(hull: HullGrammar.Hull, row: int) -> int:
	if hull.hub_half > 0 and row >= hull.hub_y0 - 1 and row <= hull.hub_y1:
		return hull.cx - hull.hub_half
	return hull.corridor_xmin(row)


## One past the corridor's rightmost x as the flanks see it; see [method _flank_xmin].
static func _flank_xmax(hull: HullGrammar.Hull, row: int) -> int:
	if hull.hub_half > 0 and row >= hull.hub_y0 - 1 and row <= hull.hub_y1:
		return hull.cx + hull.hub_half
	return hull.corridor_xmax(row)


## How deep this band is, given the roll, the depth cap for its width and
## the rows left. The roll is nudged inside [10, cap] until what remains
## after the band can still be cut into bays of 10 to cap rows, or is
## nothing at all. When no depth manages that the band keeps to its cap and
## whatever is left at the end, under 10 rows, stays Bulk.
static func _band_length(rolled: int, cap: int, remaining: int) -> int:
	if remaining <= cap:
		return remaining
	var want := clampi(rolled, 10, cap)
	for off in range(0, cap):
		for band_len: int in ([want + off, want - off] if off > 0 else [want]):
			if band_len < 10 or band_len > cap:
				continue
			var rest := remaining - band_len - 1
			if rest >= 10 and _bands_fit(rest, cap):
				return band_len
	return want


## Whether `rows` can be cut into bays of 10 to `cap` rows with a wall
## between each pair.
static func _bands_fit(rows: int, cap: int) -> bool:
	var k := 1
	while 10 * k + (k - 1) <= rows:
		if rows <= cap * k + (k - 1):
			return true
		k += 1
	return false


## Deepest a band may be for the width it spans so its Rooms can meet the
## ceiling: a band no wider than [constant MAX_BAND_WIDTH] fits in one
## piece; a wider one is cut across into pieces up to [constant PIECE_WIDTH]
## wide, which at 13 deep stay under the ceiling.
static func depth_cap(width: int) -> int:
	if width > MAX_BAND_WIDTH:
		return 13
	@warning_ignore("integer_division")
	return clampi(CEILING_AREA / maxi(width, 1), 10, MAX_BAND_DEPTH)


## A rolled band depth held to [method depth_cap] and the Fight Core floor
## (a wide band's pieces need 11 rows to reach 140 tiles).
static func band_depth_cap(rolled: int, width: int) -> int:
	return clampi(rolled, 11 if width > MAX_BAND_WIDTH else 10, depth_cap(width))


## The widest a flank gets over rows [y0, y1): Hull floor outboard of the
## corridor wall on that side.
static func _flank_width(hull: HullGrammar.Hull, y0: int, y1: int, sgn: int) -> int:
	var w := 0
	for y in range(y0, mini(y1, hull.rows.size())):
		for iv: Vector2i in hull.rows[y]:
			if sgn < 0:
				w = maxi(w, mini(iv.y, hull.corridor_xmin(y) - 1) - iv.x)
			else:
				w = maxi(w, iv.y - maxi(iv.x, hull.corridor_xmax(y) + 1))
	return w


## A two-tile doorway from a flank bay onto the corridor, on a row pair where
## the corridor wall is straight, preferring the band's middle.
static func _flank_door(hull: HullGrammar.Hull, comp: Dictionary, sgn: int, y0: int, y1: int) -> Gap:
	var wall_at := func(row: int) -> int:
		return (_flank_xmin(hull, row) - 1) if sgn < 0 else _flank_xmax(hull, row)
	var dy := -1
	for row in range(y0, y1 - 1):
		var wall_x: int = wall_at.call(row)
		if wall_x == int(wall_at.call(row + 1)) and comp.has(Vector2i(wall_x + sgn, row)) \
				and comp.has(Vector2i(wall_x + sgn, row + 1)):
			dy = row
			@warning_ignore("integer_division")
			if row >= (y0 + y1) / 2:
				break
	if dy < 0:
		return null
	return Gap.new(Vector2i(wall_at.call(dy), dy), false)


## Engine pods roll per side against the outermost Hull edge of the engine
## band, widening the Engine Room.
static func _engine_pods(hull: HullGrammar.Hull, ship_class: StringName,
		rng: RandomNumberGenerator, out: Result) -> void:
	if ship_class == &"small":
		return
	var engines: Array[Patch] = []
	for patch in out.patches:
		if patch.role == &"engine":
			engines.append(patch)
	var m1 := hull.mid_y1
	var pod_end := mini(hull.engine_y1, hull.length - hull.tail_len if hull.tail_len > 0 else hull.length)
	for pod_side: Array in [[-1, "port pod"], [1, "stbd pod"]]:
		if rng.randf() >= 0.45:
			continue
		var sgn: int = pod_side[0]
		var edge: Array[int] = []
		for y in range(0, hull.length):
			var ivs: Array = hull.rows[y]
			edge.append(int(ivs[0].x) if sgn < 0 else int(ivs[ivs.size() - 1].y))
		var run := TileShapes.longest_equal_run(edge, m1 + 1, pod_end)
		if run.y - run.x < 5:
			continue
		out.features.append(pod_side[1])
		var pod_w := 4 + rng.randi_range(0, 1) * 2
		var pod_l := mini(run.y - run.x, 10)
		@warning_ignore("integer_division")
		var pod_y: int = run.x + (run.y - run.x - pod_l) / 2
		for yy in range(pod_y, pod_y + pod_l):
			# A pod row only hangs off a row an Engine Room actually reaches.
			var anchor := Vector2i(edge[run.x] if sgn < 0 else edge[run.x] - 1, yy)
			for engine in engines:
				if not engine.tiles.has(anchor):
					continue
				for i in pod_w:
					var xx: int = edge[run.x] - 1 - i if sgn < 0 else edge[run.x] + i
					engine.tiles[Vector2i(xx, yy)] = true
				break


## Try to cut one Room along the long axis of its bounding box. First a cut
## that leaves every piece fightable and resolvable, tried from the middle
## outward; failing that, when shedding is allowed, the nearest cut that
## keeps at least half the floor in fightable pieces, anywhere along the
## axis, so a Room whose core sits mid-span is trimmed at an edge. What is
## shed goes to the Sliver rule. Returns the pieces or [].
static func _try_split(tiles: Dictionary, shed_slivers: bool) -> Array[Dictionary]:
	var b := TileShapes.bounds(tiles)
	var along_x: bool = b.size.x >= b.size.y
	var start: int = b.position.x if along_x else b.position.y
	var long_side: int = b.size.x if along_x else b.size.y
	@warning_ignore("integer_division")
	var mid: int = start + long_side / 2
	# Tiles before each cut line, so cuts that cannot leave enough floor on
	# the right sides are skipped before any flood fill.
	var per_line: Array[int] = []
	per_line.resize(long_side)
	per_line.fill(0)
	for t: Vector2i in tiles:
		per_line[(t.x if along_x else t.y) - start] += 1
	var before: Array[int] = [0]
	for n in per_line:
		before.append(before[before.size() - 1] + n)

	for shedding in ([false, true] if shed_slivers else [false]):
		for off in range(0, long_side):
			for cut: int in ([mid + off, mid - off] if off > 0 else [mid]):
				if cut <= start or cut >= start + long_side - 1:
					continue
				var left: int = before[cut - start]
				var right: int = tiles.size() - before[cut - start + 1]
				if shedding:
					if maxi(left, right) < FLOOR_AREA:
						continue
				elif left < FLOOR_AREA or right < FLOOR_AREA:
					continue
				var rest := {}
				for t: Vector2i in tiles:
					if (t.x if along_x else t.y) != cut:
						rest[t] = true
				var parts := TileShapes.components(rest)
				if parts.size() < 2:
					continue
				var kept := 0
				var all_ok := true
				for p in parts:
					if p.size() >= FLOOR_AREA and TileShapes.largest_square(p) >= FIGHT_CORE and _resolvable(p):
						kept += p.size()
					else:
						all_ok = false
				if all_ok or (shedding and kept * 2 >= tiles.size()):
					return parts
	return []


## Whether a piece is under the ceiling, or long enough for its width that
## another cut can leave two fightable Rooms.
static func _resolvable(tiles: Dictionary) -> bool:
	if tiles.size() <= CEILING_AREA:
		return true
	var b := TileShapes.bounds(tiles)
	var short_side := mini(b.size.x, b.size.y)
	var long_side := maxi(b.size.x, b.size.y)
	@warning_ignore("integer_division")
	var piece := maxi(FIGHT_CORE, (FLOOR_AREA + short_side - 1) / maxi(short_side, 1))
	return long_side >= 2 * piece + 1


## Ceiling: a Room over 260 tiles is cut if every piece still clears the floor.
static func _split_big(patches: Array[Patch]) -> int:
	var count := 0
	var i := 0
	while i < patches.size():
		var patch := patches[i]
		if patch.is_corridor() or patch.tiles.size() <= CEILING_AREA:
			i += 1
			continue
		var parts := _try_split(patch.tiles, true)
		if parts.is_empty():
			i += 1
			continue
		# The pieces are checked again in turn: a very long Room takes several cuts.
		patch.tiles = parts[0]
		for k in range(1, parts.size()):
			patches.append(Patch.new(parts[k], patch.role))
		count += 1
	return count


## Which patch each floor tile belongs to: {Vector2i: index}.
static func _owner_map(patches: Array[Patch]) -> Dictionary:
	var owner := {}
	for i in patches.size():
		for t: Vector2i in patches[i].tiles:
			owner[t] = i
	return owner


## Merge patch i into the neighbour it shares the longest wall with (at
## least 3 tiles, never the corridor, never over `cap`). The shared wall
## becomes floor and `owner` is updated in place. False when no neighbour
## qualifies.
static func _merge_into_neighbour(patches: Array[Patch], i: int, cap: int, owner: Dictionary) -> bool:
	var shared := {}
	for t: Vector2i in patches[i].tiles:
		for step in TileShapes.SIDES:
			var w := t + step
			if owner.has(w):
				continue
			var j: int = owner.get(w + step, -1)
			if j < 0 or j == i or patches[j].is_corridor():
				continue
			# A wall tile that also borders a third Room stays wall, or the
			# merged Room would touch that neighbour with nothing between.
			var third := false
			for side in TileShapes.SIDES:
				var k: int = owner.get(w + side, -1)
				if k >= 0 and k != i and k != j:
					third = true
					break
			if third:
				continue
			if not shared.has(j):
				shared[j] = {}
			shared[j][w] = true
	var best := -1
	var best_len := 0
	for j: int in shared:
		var n: int = shared[j].size()
		if n >= 3 and n > best_len and patches[i].tiles.size() + patches[j].tiles.size() + n <= cap:
			best = j
			best_len = n
	if best < 0:
		return false
	for t: Vector2i in patches[i].tiles:
		patches[best].tiles[t] = true
		owner[t] = best
	for w: Vector2i in shared[best]:
		patches[best].tiles[w] = true
		owner[w] = best
	patches[i].tiles = {}
	return true


## The Sliver rule, smallest patch first: merge into a neighbour, else Bulk.
static func _repair_slivers(patches: Array[Patch]) -> Dictionary:
	var merged := 0
	var filled := 0
	var changed := true
	var owner := _owner_map(patches)
	while changed:
		changed = false
		var failing: Array[int] = []
		for i in patches.size():
			if not patches[i].is_empty() and not patches[i].is_corridor() and not patches[i].passes_floor():
				failing.append(i)
		failing.sort_custom(func(a: int, b: int) -> bool: return patches[a].tiles.size() < patches[b].tiles.size())
		if failing.is_empty():
			break
		for i in failing:
			if _merge_into_neighbour(patches, i, CEILING_AREA, owner):
				merged += 1
				changed = true
				break
	for patch in patches:
		if not patch.is_empty() and not patch.is_corridor() and not patch.passes_floor():
			patch.tiles = {}
			filled += 1
	return {merged = merged, filled = filled}


## Count fit: under the band, split the largest Rooms; over it, merge the
## smallest into a neighbour. The caller resizes if the count is still out.
static func _fit_count(patches: Array[Patch], band: Vector2i) -> Dictionary:
	var split := 0
	var merged := 0
	var guard := 40
	while guard > 0:
		guard -= 1
		var live: Array[int] = []
		for i in patches.size():
			if not patches[i].is_empty() and not patches[i].is_corridor():
				live.append(i)
		live.sort_custom(func(a: int, b: int) -> bool: return patches[a].tiles.size() > patches[b].tiles.size())
		if live.size() < band.x:
			var done := false
			for i in live:
				# Two fightable pieces need two floors and a wall between.
				if patches[i].tiles.size() < 2 * FLOOR_AREA + FIGHT_CORE:
					continue
				var parts := _try_split(patches[i].tiles, false)
				if parts.is_empty():
					continue
				patches[i].tiles = parts[0]
				for k in range(1, parts.size()):
					patches.append(Patch.new(parts[k], patches[i].role))
				split += 1
				done = true
				break
			if not done:
				break
		elif live.size() > band.y:
			live.reverse()
			var done := false
			var owner := _owner_map(patches)
			for i in live:
				if _merge_into_neighbour(patches, i, CEILING_AREA, owner):
					merged += 1
					done = true
					break
			if not done:
				break
		else:
			break
	return {split = split, merged = merged}


## The one non-corridor Room owning both `tile` and the tile to its right
## (the two floor tiles behind a two-wide Door), or -1.
static func _room_behind(patches: Array[Patch], owner: Dictionary, tile: Vector2i, not_room: int) -> int:
	var a: int = owner.get(tile, -1)
	var b: int = owner.get(tile + Vector2i.RIGHT, -1)
	if a < 0 or a != b or a == not_room or patches[a].is_corridor():
		return -1
	return a


## The caps are settled by where the Skeleton ends, as the repairs may have
## cut or merged the bands: the Room behind the corridor's fore Door is the
## Bridge (a ring's Bridge is its core) and the Room behind its aft Door is
## an Engine. Any other Room tagged Bridge becomes Quarters, so exactly one
## Bridge stands. A chain has no corridor; its caps keep their tags, the
## fore-most Bridge winning. Returns false when a corridor's end opens onto
## Bulk, which no retagging can mend: the pack has failed.
static func _settle_caps(patches: Array[Patch], hull: HullGrammar.Hull) -> bool:
	var owner := _owner_map(patches)
	var bridge := -1
	var on_axis := true
	if hull.skeleton == &"ring":
		bridge = owner.get(hull.core.position, -1)
		on_axis = bridge >= 0
	elif hull.skeleton == &"spine":
		# Both tiles behind the fore Door at (cx - 2, m0 - 1) belong to one Room.
		bridge = _room_behind(patches, owner, Vector2i(hull.cx - 2, hull.mid_y0 - 2), -1)
		on_axis = bridge >= 0
	if hull.skeleton != &"chain":
		# Likewise behind the aft Door at (cx, m1).
		var engine := _room_behind(patches, owner, Vector2i(hull.cx, hull.mid_y1 + 1), bridge)
		if engine >= 0:
			patches[engine].role = &"engine"
		else:
			on_axis = false
	if bridge < 0:
		var best_y := 1 << 30
		for i in patches.size():
			if patches[i].role == &"bridge" and not patches[i].is_empty():
				var y := TileShapes.bounds(patches[i].tiles).position.y
				if y < best_y:
					best_y = y
					bridge = i
	for i in patches.size():
		if patches[i].role == &"bridge" and i != bridge:
			patches[i].role = &"quarters"
	if bridge >= 0:
		patches[bridge].role = &"bridge"
	return on_axis
