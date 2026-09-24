class_name DoorStitcher
extends RefCounted
## Stage 4 of the generator: Door stitching. Keeps the packer's seeded Doors
## that land between two Rooms, then union-finds the Room graph and punches
## Doors through shared walls until the ship is one component. A Room with no
## reachable neighbour is stranded and becomes Bulk.
##
## No Lane may cross a Corridor: two doorways on opposite walls of a Corridor
## with a straight run of Corridor floor between them are refused, seeded or
## punched, so the Corridor's own cover is never a firing lane's backstop.


## Stitch [param patches] into one component. Returns the confirmed Gaps;
## stranded patches are emptied and flagged.
static func stitch(patches: Array[RoomPacker.Patch], seeded: Array[RoomPacker.Gap],
		rng: RandomNumberGenerator) -> Array[RoomPacker.Gap]:
	var owner := {}
	var corridor := {}
	for i in patches.size():
		for t: Vector2i in patches[i].tiles:
			owner[t] = i
			if patches[i].is_corridor():
				corridor[t] = true
	var parent: Array[int] = []
	for i in patches.size():
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

	var doors: Array[RoomPacker.Gap] = []
	for gap in seeded:
		var ends := _rooms_either_side(gap, owner)
		if ends.x < 0 or lane_between_any(gap, doors, corridor):
			continue
		doors.append(gap)
		parent[find.call(ends.x)] = find.call(ends.y)

	# Every wall tile between two different Rooms is a candidate Door,
	# gathered once as a one-tile gap and widened only when drawn.
	var cands: Array[RoomPacker.Gap] = []
	var cand_ends: Array[Vector2i] = []
	for i in patches.size():
		for t: Vector2i in patches[i].tiles:
			for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
				var w: Vector2i = t + step
				if owner.has(w):
					continue
				var j: int = owner.get(t + step * 2, -1)
				if j < 0 or j == i:
					continue
				cands.append(RoomPacker.Gap.new(w, step.y == 1, 1))
				cand_ends.append(Vector2i(i, j))
	# Draw candidates that still join two components; one too narrow to
	# widen, or that would face a Door across a Corridor, is struck out.
	var dead := {}
	while true:
		var open: Array[int] = []
		for c in cands.size():
			if not dead.has(c) and find.call(cand_ends[c].x) != find.call(cand_ends[c].y):
				open.append(c)
		if open.is_empty():
			break
		var pick: int = open[rng.randi_range(0, open.size() - 1)]
		var gap := _widen(cands[pick], owner)
		if gap.width < 2 or lane_between_any(gap, doors, corridor):
			dead[pick] = true
			continue
		doors.append(gap)
		parent[find.call(cand_ends[pick].x)] = find.call(cand_ends[pick].y)

	var groups := {}
	for i in patches.size():
		if not patches[i].is_empty():
			groups[find.call(i)] = true
	if groups.size() > 1:
		_strand_minorities(patches, find)
		# Doors into a stranded Room go with it.
		var kept: Array[RoomPacker.Gap] = []
		for gap in doors:
			var ends := _rooms_either_side(gap, owner)
			if not patches[ends.x].is_empty() and not patches[ends.y].is_empty():
				kept.append(gap)
		doors = kept
	return doors


## The Rooms on the two sides of a Gap, or (-1, -1) unless every tile of the
## gap is wall with the same two Rooms across it.
static func _rooms_either_side(gap: RoomPacker.Gap, owner: Dictionary) -> Vector2i:
	var across := Vector2i(0, 1) if gap.horizontal else Vector2i(1, 0)
	var a := -1
	var b := -1
	for t in gap.tiles():
		if owner.has(t):
			return Vector2i(-1, -1)
		var ta: int = owner.get(t - across, -1)
		var tb: int = owner.get(t + across, -1)
		if ta < 0 or tb < 0 or ta == tb:
			return Vector2i(-1, -1)
		if a < 0:
			a = ta
			b = tb
		elif ta != a or tb != b:
			return Vector2i(-1, -1)
	return Vector2i(a, b)


## Grow a one-tile gap to two along its wall, either way, if the second tile
## also sits between the same two Rooms.
static func _widen(gap: RoomPacker.Gap, owner: Dictionary) -> RoomPacker.Gap:
	var perp := Vector2i(1, 0) if gap.horizontal else Vector2i(0, 1)
	for start: Vector2i in [gap.tile, gap.tile - perp]:
		var wide := RoomPacker.Gap.new(start, gap.horizontal, 2)
		if _rooms_either_side(wide, owner).x >= 0:
			return wide
	return gap


## Rooms outside the largest component become Bulk rather than strand the walker.
static func _strand_minorities(patches: Array[RoomPacker.Patch], find: Callable) -> void:
	var sizes := {}
	for i in patches.size():
		if not patches[i].is_empty():
			var r: int = find.call(i)
			sizes[r] = sizes.get(r, 0) + patches[i].tiles.size()
	var main := -1
	for r: int in sizes:
		if main < 0 or sizes[r] > sizes[main]:
			main = r
	for i in patches.size():
		if not patches[i].is_empty() and find.call(i) != main:
			patches[i].tiles = {}
			patches[i].stranded = true


## Whether [param gap] would face any of [param doors] straight across
## Corridor floor.
static func lane_between_any(gap: RoomPacker.Gap, doors: Array[RoomPacker.Gap], corridor: Dictionary) -> bool:
	for other in doors:
		if lane_between(gap.tiles(), other.tiles(), gap.horizontal, other.horizontal, corridor):
			return true
	return false


## Whether a straight sightline runs from one doorway to the other entirely
## over Corridor floor. Only doorways of the same orientation can face each
## other: you look through a doorway along its passage axis.
static func lane_between(a: Array[Vector2i], b: Array[Vector2i], a_horizontal: bool,
		b_horizontal: bool, corridor: Dictionary) -> bool:
	if a_horizontal != b_horizontal:
		return false
	for ta in a:
		for tb in b:
			if a_horizontal and ta.x != tb.x:
				continue
			if not a_horizontal and ta.y != tb.y:
				continue
			var delta := tb - ta
			var n := absi(delta.x + delta.y)
			if n < 2:
				continue
			var step := delta / n
			var clear := true
			for k in range(1, n):
				if not corridor.has(ta + step * k):
					clear = false
					break
			if clear:
				return true
	return false


## Every pair of Doors on a built layout that face each other across a
## Corridor, as "door i / door j" strings. Empty on a ship that keeps the rule.
static func lanes_across_corridors(layout: ShipLayout) -> Array[String]:
	var corridor := {}
	for room in layout.rooms:
		if room.role == &"corridor":
			corridor.merge(room.tiles())
	var out: Array[String] = []
	for i in layout.doors.size():
		for j in range(i + 1, layout.doors.size()):
			var a := layout.doors[i]
			var b := layout.doors[j]
			if lane_between(a.tiles(), b.tiles(), a.horizontal, b.horizontal, corridor):
				out.append("door %d at %s / door %d at %s" % [i, a.tile, j, b.tile])
	return out
