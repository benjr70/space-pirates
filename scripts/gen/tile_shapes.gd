class_name TileShapes
extends RefCounted
## Tile-set arithmetic the generator shapes Hulls and Rooms with. A tile set
## is {Vector2i: true}; a Hull row is a sorted list of [x0, x1) intervals held
## as Vector2i(x0, x1).

const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Merge a list of [x0, x1) intervals; touching or overlapping become one.
static func merge_intervals(list: Array) -> Array:
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


## Remove [cut.x, cut.y) from every interval.
static func cut_intervals(list: Array, cut: Vector2i) -> Array:
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


## Widest single interval on a row.
static func row_width(intervals: Array) -> int:
	var w := 0
	for iv: Vector2i in intervals:
		w = maxi(w, iv.y - iv.x)
	return w


## Every tile of every rect, as a set.
static func tiles_of(rects: Array[Rect2i]) -> Dictionary:
	var out := {}
	for r in rects:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				out[Vector2i(x, y)] = true
	return out


## Split a tile set into its 4-connected components.
static func components(tiles: Dictionary) -> Array[Dictionary]:
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
			for step in SIDES:
				var n := t + step
				if tiles.has(n) and not seen.has(n):
					seen[n] = true
					comp[n] = true
					frontier.append(n)
		out.append(comp)
	return out


## Bounding box of a non-empty tile set.
static func bounds(tiles: Dictionary) -> Rect2i:
	var box := Rect2i()
	var first := true
	for t: Vector2i in tiles:
		if first:
			box = Rect2i(t, Vector2i.ONE)
			first = false
		else:
			box = box.expand(t).expand(t + Vector2i.ONE)
	return box


## Side of the largest axis-aligned square fully inside the tile set.
static func largest_square(tiles: Dictionary) -> int:
	if tiles.is_empty():
		return 0
	var best := 0
	var memo := {}
	var box := bounds(tiles)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var t := Vector2i(x, y)
			if not tiles.has(t):
				continue
			var v: int = 1 + mini(memo.get(t + Vector2i.UP, 0),
					mini(memo.get(t + Vector2i.LEFT, 0), memo.get(t + Vector2i(-1, -1), 0)))
			memo[t] = v
			best = maxi(best, v)
	return best


## Decompose a tile set into maximal rects: per-row runs, each merged with
## the identical run directly above it. Rects never overlap and abut along
## Seams, so the result is a valid [member RoomData.rects].
static func rects_from_tiles(tiles: Dictionary) -> Array[Rect2i]:
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


## Longest run of equal values in values[y0..y1), as (start, end).
static func longest_equal_run(values: Array[int], y0: int, y1: int) -> Vector2i:
	var best := Vector2i(y0, y0)
	var start := y0
	for y in range(y0 + 1, y1 + 1):
		if y == y1 or values[y] != values[start]:
			if y - start > best.y - best.x:
				best = Vector2i(start, y)
			start = y
	return best
