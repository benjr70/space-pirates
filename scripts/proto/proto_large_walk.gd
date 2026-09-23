extends Node3D
## PROTOTYPE — walk a whole packed ship, furnished (issue #16).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_large_walk.tscn \
##       -- seed=1 class=large density=2
##
## Joins the hull-pack partition (proto/room-packing, recipe F) with the
## shared cover vocabulary (proto/cover-vocabulary, density 2) and a compact
## cut of the Role-assignment ranking, Threat/Loot budgets and per-Role
## flavour rows. Everything the map has decided, on one large seed, walked
## end to end. The question: does a 14–18-Room ship of big bays read as a
## warehouse, or do Roles plus the vocabulary give it enough texture?
##
## You board at the stern in the entry Room (the Hatch stand-in; the packer
## has no Hatches). Floors and lights are tinted by Role; the console prints
## the ship sentence, the Role of every Room with its crew and gold, and the
## ASCII plan.

const CoverWalk := preload("res://scripts/proto/proto_cover_walk.gd")

const THREAT_WEIGHT := {&"armory": 3.0, &"bridge": 2.5, &"engine": 2.0, &"shield": 2.0,
		&"quarters": 1.5, &"cargo": 1.5, &"medbay": 1.0, &"corridor": 0.5}
const LOOT_WEIGHT := {&"armory": 4.0, &"cargo": 3.0, &"bridge": 1.0, &"quarters": 1.0,
		&"medbay": 1.0, &"engine": 0.5, &"shield": 0.5, &"corridor": 0.0}
const THREAT_DENSITY := {&"small": 1.2, &"medium": 1.55, &"large": 1.85}
const LOOT_DENSITY := {&"small": 1.25, &"medium": 1.85, &"large": 2.6}
const CONSOLES := {&"bridge": 3, &"engine": 0, &"shield": 1, &"armory": 1, &"cargo": 0,
		&"medbay": 1, &"quarters": 1, &"corridor": 0}
const LIGHT := {&"bridge": Color(0.85, 0.92, 1.0), &"engine": Color(1.0, 0.6, 0.3),
		&"shield": Color(0.5, 0.65, 1.0), &"armory": Color(0.9, 0.35, 0.3),
		&"cargo": Color(0.9, 0.9, 0.85), &"medbay": Color(1.0, 1.0, 1.0),
		&"quarters": Color(1.0, 0.85, 0.65), &"corridor": Color(0.6, 0.6, 0.6)}

var walk_seed := 1
var ship_class: StringName = &"large"
var density := 2

## Group = one Room of the plan (several rects). group_of[rect index] -> group.
var _group_of: Array[int] = []
var _rects_of: Array = []      # group -> Array[int] of rect indices
var _role_of: Array[StringName] = []
var _corridor: Array[bool] = []
var _adj: Array = []           # group -> Array[int]
var _flow: Array[int] = []
var _entry_group := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"seed":
				walk_seed = int(kv[1])
			"class":
				ship_class = StringName(kv[1])
			"density":
				density = int(kv[1])

	var pack_rng := RandomNumberGenerator.new()
	pack_rng.seed = hash("F#%d" % walk_seed)
	var plan: Dictionary = ProtoSilhouette._hull_pack(ship_class, pack_rng)
	var layout := _layout_from_plan(plan)
	_assign_roles(layout)
	var budgets := _budgets(layout)
	var helper: Node3D = CoverWalk.new()
	helper.density = density
	helper._rng.seed = walk_seed
	_furnish(layout, helper, budgets)

	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	main.layout_override = layout
	main.explore_darkness = false
	add_child(main)
	helper._spawn_extras(main, layout)
	helper._place_crew(main, layout)
	_tint_lights(main, layout)

	print("ship: %s" % plan.sentence)
	print("class=%s rooms=%d threat=%d loot=%d" % [ship_class, _counted(), budgets.threat, budgets.loot])
	for g in _rects_of.size():
		var crew := 0
		var area := 0
		for i in _rects_of[g]:
			crew += layout.rooms[i].crew_count
			area += layout.rooms[i].rect.get_area()
		print("  room %2d %-9s flow=%d area=%3d crew=%d gold=%d" % [g, _role_of[g], _flow[g], area, crew, budgets.gold[g]])
	helper._print_plan(layout)
	helper.queue_free()


# ---------------------------------------------------------------------------
# Plan -> layout, keeping the Room grouping the single-rect RoomData loses.
# ---------------------------------------------------------------------------

func _layout_from_plan(plan: Dictionary) -> ShipLayout:
	var layout := ShipLayout.new()
	layout.gen_seed = walk_seed
	layout.ship_name = "Large Walk #%d" % walk_seed
	for room: Dictionary in plan.rooms:
		var g := _rects_of.size()
		_rects_of.append([])
		_role_of.append(room.role)
		_corridor.append(room.get("corridor", false))
		for rect: Rect2i in room.rects:
			var data := RoomData.new()
			data.rect = rect
			data.role = room.role
			_rects_of[g].append(layout.rooms.size())
			_group_of.append(g)
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
			continue
		layout.doors.append(door)
	_adj.resize(_rects_of.size())
	for g in _adj.size():
		_adj[g] = []
	for door in layout.doors:
		var a := _group_of[door.room_a]
		var b := _group_of[door.room_b]
		if a != b:
			_adj[a].append(b)
			_adj[b].append(a)
	return layout


func _counted() -> int:
	var n := 0
	for c in _corridor:
		if not c:
			n += 1
	return n


## Compact cut of the Role-assignment ranking: entry (Hatch stand-in) is the
## sternmost non-Engine flank Room and becomes Cargo; Armory is deepest by
## flow; Shield is Engine-adjacent; Medbay most central; largest is Cargo;
## the rest alternate Cargo / Quarters. Corridors are Corridors.
func _assign_roles(layout: ShipLayout) -> void:
	var n := _rects_of.size()
	var fixed: Array[bool] = []
	fixed.resize(n)
	for g in n:
		if _corridor[g]:
			_role_of[g] = &"corridor"
			fixed[g] = true
		elif _role_of[g] == &"bridge" or _role_of[g] == &"engine":
			fixed[g] = true
	# Entry: the unfixed group whose rects reach furthest aft (max y).
	var best_y := -1
	for g in n:
		if fixed[g]:
			continue
		for i in _rects_of[g]:
			best_y = maxi(best_y, layout.rooms[i].rect.end.y)
			if layout.rooms[i].rect.end.y == best_y:
				_entry_group = g
	_role_of[_entry_group] = &"cargo"
	fixed[_entry_group] = true
	layout.entry_room = _rects_of[_entry_group][0]
	# Flow distance from the entry over the door graph.
	_flow.resize(n)
	_flow.fill(99)
	_flow[_entry_group] = 0
	var queue: Array[int] = [_entry_group]
	while queue:
		var g: int = queue.pop_front()
		for h: int in _adj[g]:
			if _flow[h] > _flow[g] + 1:
				_flow[h] = _flow[g] + 1
				queue.append(h)
	var pool: Array[int] = []
	for g in n:
		if not fixed[g]:
			pool.append(g)
	# Armory ×2 deepest, Shield engine-adjacent, Medbay most central, biggest Cargo.
	pool.sort_custom(func(a: int, b: int) -> bool: return _flow[a] > _flow[b])
	for k in mini(2, pool.size()):
		_role_of[pool[k]] = &"armory"
	pool = pool.slice(mini(2, pool.size()))
	for g in pool:
		var near_engine := false
		for h: int in _adj[g]:
			if _role_of[h] == &"engine":
				near_engine = true
		if near_engine:
			_role_of[g] = &"shield"
			pool.erase(g)
			break
	if pool.size() > 0:
		pool.sort_custom(func(a: int, b: int) -> bool: return _centrality(a) < _centrality(b))
		_role_of[pool[0]] = &"medbay"
		pool = pool.slice(1)
	if pool.size() > 0:
		pool.sort_custom(func(a: int, b: int) -> bool: return _area(layout, a) > _area(layout, b))
		_role_of[pool[0]] = &"cargo"
		pool = pool.slice(1)
	var flip := false
	for g in pool:
		_role_of[g] = &"quarters" if flip else &"cargo"
		flip = not flip
	for g in n:
		for i in _rects_of[g]:
			layout.rooms[i].role = _role_of[g]


func _centrality(g: int) -> float:
	# Mean hop distance to every other group, BFS from g.
	var dist := {g: 0}
	var queue: Array[int] = [g]
	while queue:
		var a: int = queue.pop_front()
		for b: int in _adj[a]:
			if not dist.has(b):
				dist[b] = dist[a] + 1
				queue.append(b)
	var total := 0
	for k in dist:
		total += dist[k]
	return float(total) / maxi(dist.size(), 1)


func _area(layout: ShipLayout, g: int) -> int:
	var a := 0
	for i in _rects_of[g]:
		a += layout.rooms[i].rect.get_area()
	return a


# ---------------------------------------------------------------------------
# Budgets: the Threat and Loot decisions, at the class's mid-band density.
# ---------------------------------------------------------------------------

func _budgets(layout: ShipLayout) -> Dictionary:
	var counted := _counted()
	var threat := roundi(counted * THREAT_DENSITY[ship_class])
	var loot := roundi(counted * LOOT_DENSITY[ship_class])
	var crew := _split(threat, THREAT_WEIGHT, true)
	var gold := _split(loot, LOOT_WEIGHT, false)
	# Floors and caps.
	for g in crew.size():
		if _role_of[g] == &"bridge":
			crew[g] = maxi(crew[g], 1)
		if _role_of[g] == &"armory":
			crew[g] = maxi(crew[g], 2)
			gold[g] = maxi(gold[g], 3)
		if _role_of[g] == &"cargo":
			gold[g] = maxi(gold[g], 1)
		crew[g] = mini(crew[g], 5 if _area(layout, g) >= 200 else 4)
	# Crew per rect: proportional to area, remainder to the largest rect.
	for g in crew.size():
		var rects: Array = _rects_of[g].duplicate()
		rects.sort_custom(func(a: int, b: int) -> bool:
			return layout.rooms[a].rect.get_area() > layout.rooms[b].rect.get_area())
		var left: int = crew[g]
		var total := _area(layout, g)
		for k in range(1, rects.size()):
			var share := int(floor(crew[g] * float(layout.rooms[rects[k]].rect.get_area()) / total))
			layout.rooms[rects[k]].crew_count = share
			left -= share
		layout.rooms[rects[0]].crew_count = left
	return {threat = threat, loot = loot, crew = crew, gold = gold}


func _split(total: int, weights: Dictionary, hatch_half: bool) -> Array[int]:
	var n := _rects_of.size()
	var w: Array[float] = []
	var sum := 0.0
	for g in n:
		var v: float = weights.get(_role_of[g], 0.0)
		if hatch_half and g == _entry_group:
			v *= 0.5
		w.append(v)
		sum += v
	var out: Array[int] = []
	var rem: Array = []
	var used := 0
	for g in n:
		var exact := total * w[g] / sum if sum > 0 else 0.0
		out.append(int(floor(exact)))
		used += out[g]
		rem.append([exact - floor(exact), g])
	rem.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in range(total - used):
		out[rem[k % n][1]] += 1
	return out


## Gold -> Container sizes per Role: Armory 3–5, Cargo 1–2, others 1.
func _containers(role: StringName, gold: int) -> Array:
	var out: Array = []
	var left := gold
	while left > 0 and out.size() < 6:
		var size := 1
		if role == &"armory":
			size = clampi(left, 3, 5) if left >= 3 else left
		elif role == &"cargo":
			size = mini(left, 2)
		out.append(size)
		left -= size
	if left > 0 and out.size() > 0:
		out[0] += left
	return out


# ---------------------------------------------------------------------------
# Furnishing: shared vocabulary per rect, then the Role's signature.
# ---------------------------------------------------------------------------

func _furnish(layout: ShipLayout, helper: Node3D, budgets: Dictionary) -> void:
	helper._init_rooms(layout)
	for g in _rects_of.size():
		var role := _role_of[g]
		var rects: Array = _rects_of[g].duplicate()
		rects.sort_custom(func(a: int, b: int) -> bool:
			return layout.rooms[a].rect.get_area() > layout.rooms[b].rect.get_area())
		for k in rects.size():
			var i: int = rects[k]
			if role == &"corridor":
				helper._furnish_corridor(layout, i)
				continue
			var containers: Array = _containers(role, budgets.gold[g]) if k == 0 else []
			var consoles: int = CONSOLES[role] if k == 0 else 0
			helper._furnish_room(layout, i, consoles, containers)
			if k == 0:
				_signature(layout, helper, i, role)
	for i in layout.rooms.size():
		helper._place_crew_spawns(layout, i)
	for g in _rects_of.size():
		_check_group_reachability(layout, helper, g)


## Invariant 18 at Room level: a multi-rect Room is one open space, so the
## flood runs across all its rects from every doorway apron.
func _check_group_reachability(layout: ShipLayout, helper: Node3D, g: int) -> void:
	var floor := {}
	var solid := {}
	for i in _rects_of[g]:
		var rect := layout.rooms[i].rect
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				floor[Vector2i(x, y)] = true
		for t in helper._plan[i]:
			if helper._plan[i][t] != "," and helper._plan[i][t] != "x":
				solid[t] = true
	var seen := {}
	var stack: Array = []
	for door in layout.doors:
		for i in _rects_of[g]:
			if door.room_a == i or door.room_b == i:
				for t in door.tiles():
					for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
						if floor.has(t + d) and not solid.has(t + d):
							stack.append(t + d)
	while stack:
		var c: Vector2i = stack.pop_back()
		if seen.has(c):
			continue
		seen[c] = true
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if floor.has(n) and not solid.has(n) and not seen.has(n):
				stack.append(n)
	var walkable := floor.size() - solid.size()
	if seen.size() < walkable:
		push_warning("room %d (%s): %d floor tiles unreachable behind props" % [g, _role_of[g], walkable - seen.size()])


## Per-Role signature props, placeholders per the flavour table. Yields to
## whatever the vocabulary already placed.
func _signature(layout: ShipLayout, helper: Node3D, i: int, role: StringName) -> void:
	var rect := layout.rooms[i].rect
	match role:
		&"engine":
			for x in [rect.position.x + 3, rect.end.x - 4]:
				helper._add_prop(layout, i, &"engine_console", Vector2i(x, rect.end.y - 2), "=", helper.CONSOLE_X, true)
		&"medbay":
			var y := rect.position.y + 2
			while y + 1 < rect.end.y - 1:
				helper._add_prop(layout, i, &"cryopod", Vector2i(rect.position.x, y), "P", helper.CRYOPOD_Y, true)
				y += 4
		&"quarters":
			var mid := rect.position.y + rect.size.y / 2
			helper._add_prop(layout, i, &"cryopod", Vector2i(rect.position.x, mid), "P", helper.CRYOPOD_Y, true)
			helper._add_prop(layout, i, &"cryopod", Vector2i(rect.end.x - 1, mid), "P", helper.CRYOPOD_Y, true)
		&"shield":
			var c := rect.position + rect.size / 2
			helper._add_prop(layout, i, &"cryopod", c, "P", helper.CRYOPOD_Y, true)
		_:
			pass


func _tint_lights(main: Node3D, layout: ShipLayout) -> void:
	var lights: Node3D = main.ship.get_node("Lights")
	for i in mini(lights.get_child_count(), layout.rooms.size()):
		var light := lights.get_child(i) as OmniLight3D
		if light:
			light.light_color = LIGHT.get(layout.rooms[i].role, Color.WHITE)
