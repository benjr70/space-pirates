extends SceneTree
## PROTOTYPE — Room-packing stats for issue #5. Measures what the F
## "hull-pack" recipe produces per class against the class room-count bands
## (#2) and the fightable floor (#12: inscribed 10x10 core AND >= 140 tiles).
##
##   flatpak run org.godotengine.Godot --headless --path . \
##       --script res://scripts/proto/proto_pack_stats.gd -- [class] [count] [first_seed] [verbose]

const BANDS := {&"small": Vector2i(4, 6), &"medium": Vector2i(8, 11), &"large": Vector2i(14, 18)}
const CORE := 10
const MIN_AREA := 140
const MAX_AREA := 220


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var classes: Array = [&"small", &"medium", &"large"] if args.size() < 1 or args[0] == "all" else [StringName(args[0])]
	var count := 12 if args.size() < 2 else int(args[1])
	var first := 1 if args.size() < 3 else int(args[2])
	var verbose := args.size() >= 4

	for ship_class: StringName in classes:
		print("################ class %s  band %s  seeds %d..%d" % [ship_class, BANDS[ship_class], first, first + count - 1])
		var in_band := 0
		var all_rooms := 0
		var all_pass := 0
		var ships_clean := 0
		var sliver_hist := {}
		for s in range(first, first + count):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("F#%d" % s)
			var plan: Dictionary = ProtoSilhouette._hull_pack(ship_class, rng)
			var n_rooms := 0
			var n_pass := 0
			var fails: Array[String] = []
			var big: Array[String] = []
			var corridor_w := -1
			for room: Dictionary in plan.rooms:
				var tiles := _tiles_of(room.rects)
				var area := tiles.size()
				if room.get("corridor", false):
					corridor_w = _min_width(room.rects)
					continue
				n_rooms += 1
				var core := _largest_square(tiles)
				var ok := core >= CORE and area >= MIN_AREA
				if ok:
					n_pass += 1
				else:
					fails.append("%s %dt core%d" % [room.role, area, core])
					var bucket := int(area / 20) * 20
					sliver_hist[bucket] = sliver_hist.get(bucket, 0) + 1
				if area > MAX_AREA:
					big.append("%s %dt" % [room.role, area])
			all_rooms += n_rooms
			all_pass += n_pass
			var band: Vector2i = BANDS[ship_class]
			var band_ok := n_rooms >= band.x and n_rooms <= band.y
			if band_ok:
				in_band += 1
			if fails.is_empty():
				ships_clean += 1
			print("seed %2d  %-52s rooms=%2d %s  pass=%2d fail=%2d big=%d corridor_w=%d" % [
					s, plan.sentence, n_rooms, "IN " if band_ok else "OUT", n_pass, fails.size(), big.size(), corridor_w])
			if verbose or not fails.is_empty():
				if not fails.is_empty():
					print("         FAIL: " + " | ".join(fails))
				if verbose and not big.is_empty():
					print("         BIG:  " + " | ".join(big))
		print("---- %s: ships in band %d/%d, rooms passing floor %d/%d, ships with zero failures %d/%d" % [
				ship_class, in_band, count, all_pass, all_rooms, ships_clean, count])
		var keys: Array = sliver_hist.keys()
		keys.sort()
		var hist := ""
		for k in keys:
			hist += " %d-%d:%d" % [k, k + 19, sliver_hist[k]]
		print("     failing-room area histogram:%s" % hist)
		print("")
	quit()


static func _tiles_of(rects: Array) -> Dictionary:
	var out := {}
	for r: Rect2i in rects:
		for x in range(r.position.x, r.end.x):
			for y in range(r.position.y, r.end.y):
				out[Vector2i(x, y)] = true
	return out


## Corridor heuristic: the proto tags the corridor role medbay and it is the
## only medbay that is long and thin. Any rect group whose bounding box has a
## short side <= 5 and long side >= 20 is treated as corridor.
static func _is_corridor(rects: Array) -> bool:
	var b: Rect2i = rects[0]
	for r: Rect2i in rects:
		b = b.merge(r)
	return mini(b.size.x, b.size.y) <= 5 and maxi(b.size.x, b.size.y) >= 20


static func _min_width(rects: Array) -> int:
	var w := 999
	for r: Rect2i in rects:
		w = mini(w, mini(r.size.x, r.size.y))
	return w


## Side of the largest axis-aligned square fully inside the tile set.
static func _largest_square(tiles: Dictionary) -> int:
	var best := 0
	var memo := {}
	var keys: Array = tiles.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for t: Vector2i in keys:
		var up: int = memo.get(t + Vector2i.UP, 0)
		var left: int = memo.get(t + Vector2i.LEFT, 0)
		var diag: int = memo.get(t + Vector2i(-1, -1), 0)
		var v: int = 1 + mini(up, mini(left, diag))
		memo[t] = v
		best = maxi(best, v)
	return best
