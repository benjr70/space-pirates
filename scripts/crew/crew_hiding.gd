class_name CrewHiding
extends RefCounted
## One Worker's hiding: the 1 s freeze of a Worker that rolled to hide,
## picking a hiding place, the run there and staying put, and when it comes
## out. Every Worker holds one (`Crew3D.hiding`); it drives the Worker's
## COWER state, which is hiding. See "Workers: running and hiding" in
## `CREW_AI.md`.
##
## **A hiding place** is an open floor tile, scored by preference: a corner
## or a wedge between wall and prop (a wall or a prop on two or more of its
## four sides), then out of sight of every doorway of its Room (no clear
## line at 1.5 m from the tile to the middle of each Door and Hatch, on the
## Room's side), then far from the Pirate and from every Guard's cover spot.
## Never a tile a Guard has claimed, or another Worker's, or an Apron. It is
## looked for in the Worker's Post Room while the run there is fair, else in
## the joined Room furthest from him. With none it hides where it stands.
##
## **The run** is at full speed, by a route that never comes nearer him than
## both its ends do (less NEARER_SLACK), and that crosses the line between
## him and a fighting Guard only when no other hiding place's route avoids
## it.
##
## Surrender (crew-combat ticket 24, `Crew3D._gives_up`, run before each
## tick) reads [method is_hidden] and [member phase], and [method find] and
## [method fair_run] for a way out past him; Workers' poses ([CrewPose],
## ticket 25) read [method is_hidden], and face [member facing] on the
## tile, back to the wall.

## Where it is in hiding: frozen on the spot (the 1 s freeze), running to
## its hiding place, on it, or hiding where it stands with nowhere to run.
enum Phase { NONE, FREEZE, RUN, HIDDEN, IN_PLACE }
const PHASE_NAMES: PackedStringArray = ["none", "freezing", "running", "hidden", "hiding where it stands"]

signal phase_changed(phase: Phase)

## Seconds a Worker that rolled to hide stands frozen before it runs.
const FREEZE := 1.0
## Seconds with no sight or sound of him before a hidden Worker comes out,
## with the Alarm down.
const COME_OUT := 20.0
## The score. A corner or wedge outweighs everything else, so a Worker
## takes one whenever one is in reach.
const W_CORNER := 100.0
const W_UNSEEN := 30.0
const W_FAR := 20.0
## His distance at which a tile scores all of W_FAR.
const FAR_FULL := 14.0
const W_GUARD := 20.0
## A tile this near a Guard's cover spot loses W_GUARD.
const GUARD_NEAR := 2.0
## The doorway sight test's height at both ends, metres.
const DOORWAY_EYE := 1.5
## The doorway's point is this far into the Room from the middle of the gap.
const DOORWAY_IN := 0.55
## The fair-run rule's slack, as a Guard's fair walk ([CrewCover]).
const NEARER_SLACK := 1.0
const WALK_SAMPLE := 0.5
## Only the best few tiles of a Room have their run tested.
const TRIED := 8
## On its hiding tile: within this of its centre.
const ON_TILE := 0.5
## A run that has not arrived in this long gives the tile up for another.
const RUN_GIVE_UP := 30.0
## Hiding where it stands, it looks again for a place to run this often.
const LOOK_AGAIN := 1.0
## A run that has not moved STALL_MOVE metres in STALL seconds (not stood
## giving way) hides on the tile it stands on, if that is a corner
## ([method _hide_here]), else gives its tile up and runs for another.
const STALL := 2.0
const STALL_MOVE := 0.3
const META := &"crew_hiding_tiles"

var crew: Crew3D
var phase := Phase.NONE
## The hiding tile and its centre: Vector2i.MAX and INF with none.
var tile := Vector2i.MAX
var spot := Vector3.INF
## Shot and still alive: it hides with no roll and never comes out.
var wounded := false
## No hiding place in reach by a fair run: it hides where it stands.
var no_way_out := false
## Seconds since it last saw or heard him.
var quiet_for := 0.0
## Which way it faces on its tile: into the Room, back to the wall.
var facing := Vector3.ZERO
var _freeze_left := 0.0
var _clock := 0.0
## Tiles whose run never arrived, given up for this hiding.
var _refused := {}
## Where its run last made progress, and how long ago.
var _stall_at := Vector3.INF
var _stall_for := 0.0
## Its own draws, seeded from the ship's seed and its spawn tile, so a Retry
## of the same ship rolls the same; nothing else draws from it.
var _rng := RandomNumberGenerator.new()


func _init(body: Crew3D) -> void:
	crew = body
	if body.layout != null and body.layout.gen_seed > 0:
		_rng.seed = hash([body.layout.gen_seed, "worker hide", ShipBuilder3D.world_to_tile(body.global_position)])
	else:
		_rng.seed = hash([body._rng.seed, "worker hide"])


## Spotting him with the Alarm down: whether this one hides (one time in
## four, [member Crew3D.hide_chance]) rather than run to raise it.
func rolls_hide() -> bool:
	return _rng.randf() < crew.hide_chance


## Starts hiding: frozen first when [param freeze], else straight to a
## hiding place.
func begin(freeze := false) -> void:
	quiet_for = 0.0
	_refused.clear()
	if freeze:
		crew._path.clear()
		_freeze_left = FREEZE
		_set_phase(Phase.FREEZE)
	else:
		_run()


## Out of hiding (another state): nothing held.
func release() -> void:
	tile = Vector2i.MAX
	spot = Vector3.INF
	no_way_out = false
	_set_phase(Phase.NONE)


## It saw or heard him: the come-out clock starts again.
func noticed() -> void:
	quiet_for = 0.0


## On its hiding tile, or hiding where it stands: still, watching.
func is_hidden() -> bool:
	return phase in [Phase.HIDDEN, Phase.IN_PLACE]


func tick(delta: float) -> void:
	quiet_for += delta
	_clock += delta
	match phase:
		Phase.FREEZE:
			crew._path.clear()
			_freeze_left -= delta
			if _freeze_left <= 0.0:
				_run()
		Phase.RUN:
			if _taken():
				_run()
			elif _flat(crew.global_position, spot) <= ON_TILE and crew._path.is_empty():
				_arrive()
			elif _clock > RUN_GIVE_UP:
				_refused[tile] = true
				_run()
			elif crew._path.is_empty() and crew._hold_timer > 0.0:
				_stalled(delta)  # its run given up: it stands Crew3D.BLOCKED_PAUSE
			elif _stalled(delta) and crew._yield_to == null and not _hide_here():
				# Stalled with no corner underfoot: whatever stops it (a crew
				# member working on the tile, a wall corner its route cannot
				# get it past) gives the tile up for another now, not at
				# RUN_GIVE_UP (raid-smoke-bugs 12).
				_refused[tile] = true
				_run()
			elif crew._path.is_empty():
				# Pushed off the end of its run, or its run given up behind
				# a crew member that will not move (once it has stood
				# Crew3D.BLOCKED_PAUSE): on to the tile, by a route. Not in a
				# straight line, which from a run given up far off runs into
				# the hull (raid-smoke-bugs 12).
				crew._repath_to(spot)
		Phase.HIDDEN:
			if _taken():
				# A Guard claimed it: on to the next best.
				_run()
			elif crew._path.is_empty() and _flat(crew.global_position, spot) > ON_TILE:
				# Shoved off it: back on.
				crew._path.assign([spot])
		Phase.IN_PLACE:
			crew._path.clear()
			if _clock >= LOOK_AGAIN:
				_clock = 0.0
				var found := find()
				if not found.is_empty():
					_go(found)
	if is_hidden() and not wounded and quiet_for >= COME_OUT and not crew._alarm_raised():
		crew._come_out()


## A Guard just claimed [param claimed] as cover: a Worker hiding there, or
## running to it, moves on to its next best at once.
static func guard_claimed(guard: Crew3D, claimed: Vector2i) -> void:
	for node in guard.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other.hiding == null or not other.is_alive() or other.layout != guard.layout:
			continue
		if other.hiding.tile == claimed and other.hiding.phase in [Phase.RUN, Phase.HIDDEN]:
			other.hiding._run()


## The hiding place it would run to now: {tile, at}, or empty with none in
## reach by a fair run. Its Post Room first; else the Rooms joined to the
## Room it stands in (that one too), furthest from him first.
func find() -> Dictionary:
	var layout := crew.layout
	if layout == null:
		return {}
	var him := crew._last_seen
	var tried := {}
	if crew.home_room >= 0 and crew.home_room < layout.rooms.size():
		tried[crew.home_room] = true
		var found := _best_in(crew.home_room, him)
		if not found.is_empty():
			return found
	var here := CrewNoise.rooms_at(layout, crew.global_position)
	var others: Array[int] = []
	for room in CrewCombat.rooms_near(layout, here):
		if not tried.has(room):
			others.append(room)
	others.sort_custom(func(a: int, b: int) -> bool:
		return _flat(ShipBuilder3D.room_center_world(layout.rooms[a]), him) \
				> _flat(ShipBuilder3D.room_center_world(layout.rooms[b]), him))
	for room in others:
		var found := _best_in(room, him)
		if not found.is_empty():
			return found
	return {}


## The best hiding tile of [param room] with a fair run to it, preferring a
## run that keeps off the line between him and a fighting Guard; empty with
## none.
func _best_in(room: int, him: Vector3) -> Dictionary:
	var taken := _claimed_tiles()
	var spots := _guard_spots()
	var found: Array[Dictionary] = []
	for entry: Dictionary in tiles_of(crew, room):
		var t: Vector2i = entry.tile
		if taken.has(t) or _refused.has(t):
			continue
		var score := (W_CORNER if entry.sides >= 2 else 0.0) + (W_UNSEEN if entry.unseen else 0.0) \
				+ W_FAR * clampf(_flat(entry.at, him) / FAR_FULL, 0.0, 1.0)
		if spots.any(func(p: Vector3) -> bool: return _flat(p, entry.at) < GUARD_NEAR):
			score -= W_GUARD
		found.append({"tile": t, "at": entry.at, "score": score})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.score > y.score)
	var lines := _fight_lines(him)
	var crossing := {}
	for i in mini(found.size(), TRIED):
		var route := _route_to(found[i].at)
		if not fair_run(route, found[i].at, him):
			continue
		if not _crosses(route, lines):
			return found[i]
		if crossing.is_empty():
			crossing = found[i]
	return crossing


## Whether [param route], from where it stands to [param to], never comes
## nearer [param him] than both its ends do, less NEARER_SLACK: a run that
## does not run toward him.
func fair_run(route: Array[Vector3], to: Vector3, him: Vector3) -> bool:
	var floor_far := minf(_flat(crew.global_position, him), _flat(to, him)) - NEARER_SLACK
	var cursor := crew.global_position
	for point in route:
		var leg := _flat(cursor, point)
		var steps := maxi(ceili(leg / WALK_SAMPLE), 1)
		for i in range(1, steps + 1):
			if _flat(cursor.lerp(point, float(i) / steps), him) < floor_far:
				return false
		cursor = point
	return true


## The route it would run to [param to], as [method Crew3D._repath_to]
## makes it.
func _route_to(to: Vector3) -> Array[Vector3]:
	var route: Array[Vector3] = []
	route.assign(crew._waypoints(to))
	if route.is_empty():
		route.append(to)
	return CrewPaths.route(crew.layout, crew.global_position, route)


## The lines from him to each Guard fighting him: [from, to] pairs, flat.
func _fight_lines(him: Vector3) -> Array:
	var out := []
	for guard in _guards():
		if guard.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
			out.append([Vector2(him.x, him.z), Vector2(guard.global_position.x, guard.global_position.z)])
	return out


func _crosses(route: Array[Vector3], lines: Array) -> bool:
	if lines.is_empty():
		return false
	var cursor := Vector2(crew.global_position.x, crew.global_position.z)
	for point in route:
		var next := Vector2(point.x, point.z)
		for line in lines:
			if Geometry2D.segment_intersects_segment(cursor, next, line[0], line[1]) != null:
				return true
		cursor = next
	return false


func _run() -> void:
	var found := find()
	if found.is_empty():
		tile = Vector2i.MAX
		spot = Vector3.INF
		no_way_out = true
		crew._path.clear()
		_clock = 0.0
		_set_phase(Phase.IN_PLACE)
		return
	_go(found)


func _go(found: Dictionary) -> void:
	no_way_out = false
	tile = found.tile
	spot = found.at
	_clock = 0.0
	_stall_at = crew.global_position
	_stall_for = 0.0
	crew._speed_scale = 1.0
	if _flat(crew.global_position, spot) <= ON_TILE:
		_arrive()
		return
	crew._repath_to(spot)
	_set_phase(Phase.RUN)


## Running, it has not moved STALL_MOVE in STALL seconds (another Worker
## in its way down a one-wide dead end, each wanting the other's tile).
func _stalled(delta: float) -> bool:
	if _flat(crew.global_position, _stall_at) > STALL_MOVE:
		_stall_at = crew.global_position
		_stall_for = 0.0
		return false
	_stall_for += delta
	return _stall_for >= STALL


## Stalled on its run: it hides on the tile it stands on, if that is a
## corner or wedge of its Room no Guard holds and no other Worker hides on
## (one still running to it moves on). True if it did.
func _hide_here() -> bool:
	_stall_for = 0.0
	var here := ShipBuilder3D.world_to_tile(crew.global_position)
	if here == tile or _claimed_tiles(false).has(here):
		return false
	var room := crew.layout.room_at(here)
	if room < 0:
		return false
	for entry: Dictionary in tiles_of(crew, room):
		if entry.tile == here and entry.sides >= 2:
			tile = here
			spot = entry.at
			_arrive()
			return true
	return false


## Its run given up ([method Crew3D._give_up_walk]): it hides where it
## stands, as with no way out, and looks again for a place to run after
## [param pause] seconds. Hiding so, with him in sight within reach, it
## surrenders (a run pressed against the Pirate himself never ended).
func hold_here(pause: float) -> void:
	if phase != Phase.RUN:
		return
	tile = Vector2i.MAX
	spot = Vector3.INF
	no_way_out = true
	crew._path.clear()
	_clock = LOOK_AGAIN - pause
	_set_phase(Phase.IN_PLACE)


## On its tile: still, back to the wall, facing into the Room.
func _arrive() -> void:
	crew._path.clear()
	facing = _into_room(tile)
	if facing != Vector3.ZERO:
		crew._aim = facing
	# Its pose sits or crouches back against the wall behind it ([CrewPose]).
	crew.seat_back = Crew3D.seat_back_for(crew.wall_behind(facing))
	_set_phase(Phase.HIDDEN)


## The way from [param t] into the open: away from its solid sides. On a
## tile between two solid sides facing each other (a slot, with nothing
## behind), along the open way that looks most toward the Room's middle.
func _into_room(t: Vector2i) -> Vector3:
	var astar := CrewPaths.grid(crew.layout)
	var out := Vector2.ZERO
	var open: Array[Vector2i] = []
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not astar.is_in_boundsv(t + side) or astar.is_point_solid(t + side):
			out -= Vector2(side)
		else:
			open.append(side)
	if out.length_squared() < 0.01:
		var room := crew.layout.room_at(t)
		if open.is_empty() or room < 0:
			return Vector3.ZERO
		var middle := ShipBuilder3D.room_center_world(crew.layout.rooms[room]) - ShipBuilder3D.tile_to_world(t)
		var to_middle := Vector2(middle.x, middle.z)
		open.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Vector2(a).dot(to_middle) > Vector2(b).dot(to_middle))
		out = Vector2(open[0])
	out = out.normalized()
	return Vector3(out.x, 0.0, out.y)


## A Guard has claimed its tile, or another Worker hides on it.
func _taken() -> bool:
	return tile != Vector2i.MAX and _claimed_tiles(false).has(tile)


func _set_phase(next: Phase) -> void:
	if next == phase:
		return
	if next != Phase.HIDDEN and crew.state != Crew3D.State.BOUND:
		crew.seat_back = 0.0  # off its tile: no wall behind to sit back to
	phase = next
	phase_changed.emit(next)


## Tiles Guards hold as cover and other Workers hide on or run to (with
## [param running] false, only hide on): {tile: true}.
func _claimed_tiles(running := true) -> Dictionary:
	var out := {}
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == crew or not other.is_alive() or other.layout != crew.layout:
			continue
		if other.cover != null and other.cover.tile != Vector2i.MAX:
			out[other.cover.tile] = true
		elif other.hiding != null and other.hiding.tile != Vector2i.MAX \
				and (running or other.hiding.phase == Phase.HIDDEN):
			out[other.hiding.tile] = true
	return out


## Where every living Guard's cover spot is.
func _guard_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for guard in _guards():
		if guard.cover != null and guard.cover.spot != Vector3.INF:
			out.append(guard.cover.spot)
	return out


func _guards() -> Array[Crew3D]:
	var out: Array[Crew3D] = []
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other != null and other.is_alive() and not other.is_worker() and other.layout == crew.layout:
			out.append(other)
	return out


## Every tile of [param room] a Worker may hide on, with what the score
## needs: [{tile, at, sides, unseen}]. Open floor off every Apron; sides is
## how many of its four sides are a wall or a prop; unseen, whether no
## doorway of the Room has a clear line to it at DOORWAY_EYE. Worked out by
## ray once per Room and kept on the layout (props and walls never move).
static func tiles_of(body: Crew3D, room: int) -> Array:
	var layout := body.layout
	var cache: Dictionary = layout.get_meta(META) if layout.has_meta(META) else {}
	if cache.has(room):
		return cache[room]
	var astar := CrewPaths.grid(layout)
	var space := body.get_world_3d().direct_space_state
	var doorways: Array[Vector3] = doorway_points(layout, room)
	var aprons := {}
	for o in Interiors.openings(layout, room):
		for t in o.apron(Interiors.APRON_DEPTH):
			aprons[t] = true
	var out := []
	for t: Vector2i in layout.rooms[room].tiles():
		if not astar.is_in_boundsv(t) or astar.is_point_solid(t) or aprons.has(t):
			continue
		var sides := 0
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if not astar.is_in_boundsv(t + side) or astar.is_point_solid(t + side):
				sides += 1
		var at := ShipBuilder3D.tile_to_world(t)
		out.append({"tile": t, "at": at, "sides": sides, "unseen": unseen_from(space, at, doorways)})
	cache[room] = out
	layout.set_meta(META, cache)
	return out


## The middle of each doorway (Door or Hatch) of [param room], DOORWAY_IN
## into the Room, at DOORWAY_EYE.
static func doorway_points(layout: ShipLayout, room: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for o in Interiors.openings(layout, room):
		out.append(Vector3((o.centre.x + 0.5 + o.normal.x * DOORWAY_IN) * ShipBuilder3D.TILE, DOORWAY_EYE,
				(o.centre.y + 0.5 + o.normal.y * DOORWAY_IN) * ShipBuilder3D.TILE))
	return out


## No clear line at DOORWAY_EYE from the tile at [param at] to any of
## [param doorways].
static func unseen_from(space: PhysicsDirectSpaceState3D, at: Vector3, doorways: Array[Vector3]) -> bool:
	var eye := Vector3(at.x, DOORWAY_EYE, at.z)
	for point in doorways:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, point, Crew3D.WORLD_LAYER)).is_empty():
			return false
	return true


## A wall or a prop on at least two of the four sides of the tile under
## [param at] (a corner, or a wedge between wall and prop).
static func tucked(layout: ShipLayout, at: Vector3) -> bool:
	var astar := CrewPaths.grid(layout)
	var t := ShipBuilder3D.world_to_tile(at)
	var sides := 0
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not astar.is_in_boundsv(t + side) or astar.is_point_solid(t + side):
			sides += 1
	return sides >= 2


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
