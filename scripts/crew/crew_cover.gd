class_name CrewCover
extends RefCounted
## How one Guard fights from cover: it finds a spot behind a prop, a wall, a
## door frame or a corner, walks there by a fair way, stays down, and peeks
## to fire (up over low cover, out to the side of full cover), in its gun's
## rhythm. It leaves when flanked, closed on, left with no shot, out of its
## range band, or when the Pirate has been gone a while. With no cover in
## reach it falls back out of his sight, or fights where it stands.
##
## Every Guard holds one ([member Crew3D.cover]). The body drives it from
## its FIGHT and COVER states: [method begin] on entering either, [method
## tick] every physics step, [method release] on leaving. It sets the body's
## state to COVER while moving to a spot, down or stepping back, and to
## FIGHT while up, stepping out or fighting in the open. Spots are found
## from the walking grid ([CrewPaths]) and sight rays when needed; nothing is
## authored. See "Guard combat" in `CREW_AI.md`.

enum Mode { NONE, MOVE, DOWN, OUT, SHOOT, BACK, OPEN }
const MODE_NAMES: PackedStringArray = ["none", "to cover", "down", "stepping out", "up", "back in", "in the open"]

## A fighting Guard is driven by these rules while the Pirate's last-seen
## spot is within this many metres; further off, and while flanking,
## today's hunt carries it.
const TAKE_OVER := 18.0
## How far from the Guard a cover spot may be, metres.
const SEARCH_RADIUS := 8.0
## How far it searches for a tile out of his sight with no cover in reach.
const FALL_BACK_RADIUS := 14.0
## A spot in reach as the crow flies whose walk round props and through
## Doors is longer than this many times the search radius is out of reach.
const WALK_REACH := 1.5
## A walk passing this close to a crew member standing still is out of
## reach: it would stall against the body.
const BODY_CLEAR := 0.6
## The open floor a walk may cross in his view, metres, and how much nearer
## him than both its ends it may come.
const OPEN_RUN := 2.5
const NEARER_SLACK := 1.0
## Points along a walk tested for his view, metres apart.
const WALK_SAMPLE := 0.5
## Of the best-scored spots, how many have their walk tried.
const TRIED := 6
## The score: near the Guard, low cover (full cover FULL_SHARE of it),
## inside its range band (falling to nothing BAND_FALLOFF metres outside),
## less a penalty for another Guard or its spot within SPACING metres.
const W_NEAR := 20.0
const W_LOW := 40.0
const FULL_SHARE := 0.5
const W_RANGE := 20.0
const BAND_FALLOFF := 4.0
const W_CROWD := 20.0
const SPACING := 2.0
## Every time in the rhythm (settle, gap between bursts, time down) varies
## by this fraction either way.
const JITTER := 0.3
## Up with no shot, it waits this long and ducks.
const WAIT_UP := 1.2
## Peeks in a row with nothing to shoot before it picks again.
const BLIND_PEEKS := 2
## Seconds he must see it crouched before it counts as flanked.
const FLANKED_AFTER := 0.4
## In sight this close, it picks a spot further off.
const TOO_CLOSE := 3.0
## Seconds held out of its range band before it shifts a spot nearer or
## further, and how much better that spot must score. (The per-gun holds
## come with "A habit per gun".)
const HOLD_BEFORE_SHIFTING := 6.0
const BETTER := 0.2
## Seconds he has been unseen before it moves a spot nearer where he was,
## and before it gives up and searches.
const UNSEEN_ADVANCE := 5.0
const UNSEEN_SEARCH := 14.0
## A shot of his passing this close keeps it down this much longer, or
## sends it down if up.
const NEAR_MISS := 1.2
const NEAR_MISS_HOLD := 0.8
## Seconds between looks for real cover while hiding with no shot, and
## while fighting in the open.
const LOOK_HIDING := 1.0
const LOOK_OPEN := 1.5
## Seconds before it weighs a shift again after weighing one.
const LOOK_SHIFT := 1.5
## Seconds a Guard moving up or back holds the one mover's place.
const MOVER_TIME := 4.0
## Seconds down on first reaching a spot, before its first peek.
const ARRIVE_DOWN := 0.3
## Seconds it walks to a spot without moving MOVE_PROGRESS metres before
## giving up on reaching it (the way blocked by a body or a prop no route
## knows of) and thinking again; the spot is then passed over for
## UNREACHABLE_FOR seconds.
const MOVE_GIVE_UP := 3.0
const MOVE_PROGRESS := 0.5
const UNREACHABLE_FOR := 10.0
## Seconds it may take to step out to, or back from, its firing tile.
const STEP_GIVE_UP := 2.5
## A walk to a spot or a firing tile ends this close to its centre: the
## sight and muzzle lines were judged from there.
const ON_SPOT := 0.12
## Between bursts in the open it pauses this fraction of a time down.
const OPEN_PAUSE := 0.6
## Up with no shot and him unseen this long, half the time it stays down
## half as long again rather than bob up.
const UNSEEN_STAY_DOWN := 2.0
## Down, the body is sunk this far into the floor (a stand-in until the
## poses ticket) and its capsule cut to this fraction of its height.
const SINK := 0.8
const CROUCH := 0.55

var crew: Crew3D
var mode := Mode.NONE
## The claimed tile, its centre, the tile it steps out to (INF for low
## cover or none), and what kind of spot it is.
var tile := Vector2i.MAX
var spot := Vector3.INF
var step := Vector3.INF
var low := false
var has_peek := false
var score := 0.0
## Counts down the current wait (down, settling, between bursts).
var timer := 0.0
## Seconds in the current mode.
var clock := 0.0
## Seconds held at this spot.
var held := 0.0
## Seconds he has seen it crouched.
var exposed := 0.0
## Seconds up with no shot.
var wait := 0.0
## Peeks in a row with nothing to shoot.
var blind := 0
var bursts := 0
## Counts down to its next look for better cover.
var think := 0.0
## Seconds left holding the one mover's place.
var mover_clock := 0.0
var crouched := false
## {tile: seconds left} it gave up walking to.
var unreachable := {}
## How many times it has got down, and ducked or stayed down for a near
## miss: a watcher can tell one stretch down from the next.
var downs := 0
var near_misses := 0
## Had its one step onto the point this mode ([method _walk_onto]).
var _nudged := false
## Where it last made progress on its walk, and how long ago.
var _progress_at := Vector3.INF
var _stalled := 0.0
var _capsule: CapsuleShape3D
var _shape: CollisionShape3D
var _stand_height := 1.7
var _stand_y := 0.85


func _init(body: Crew3D) -> void:
	crew = body
	_shape = body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if _shape != null and _shape.shape is CapsuleShape3D:
		# Its own, so lowering it lowers no one else's.
		_capsule = (_shape.shape as CapsuleShape3D).duplicate()
		_shape.shape = _capsule
		_stand_height = _capsule.height
		_stand_y = _shape.position.y


## Whether a Guard hunting with the Pirate last seen at [param last_seen]
## is near enough for these rules to take over.
static func takes_over(crew_at: Vector3, last_seen: Vector3) -> bool:
	return _flat(crew_at, last_seen) <= TAKE_OVER


## Starts the cover fight: it picks a spot on its next tick.
func begin() -> void:
	_stand()
	_unclaim()
	_set_mode(Mode.NONE)
	crew.state = Crew3D.State.COVER
	held = 0.0
	blind = 0
	exposed = 0.0
	think = 0.0


## Out of the fight (searching, dead, back on routine): stands up and frees
## its spot.
func release() -> void:
	_stand()
	_unclaim()
	mover_clock = 0.0
	mode = Mode.NONE


func is_engaged() -> bool:
	return mode != Mode.NONE


func tick(delta: float) -> void:
	timer -= delta
	clock += delta
	think -= delta
	mover_clock -= delta
	for key in unreachable.keys():
		unreachable[key] -= delta
		if unreachable[key] <= 0.0:
			unreachable.erase(key)
	if crew._seen_ago > UNSEEN_SEARCH or crew.target == null or not is_instance_valid(crew.target):
		crew._enter(Crew3D.State.SEARCH)
		return
	match mode:
		Mode.NONE:
			if not _pick(0):
				_no_cover()
		Mode.MOVE:
			if crew._path.is_empty() and not _walk_onto(spot):
				_get_down(ARRIVE_DOWN)
			elif _stalling(delta) > MOVE_GIVE_UP:
				# Cannot get there: think again, and not about this spot.
				unreachable[tile] = UNREACHABLE_FOR
				crew._path.clear()
				_unclaim()
				_set_mode(Mode.NONE)
		Mode.DOWN:
			held += delta
			if not _watch(delta) and timer <= 0.0:
				_start_peek()
		Mode.OUT:
			if (crew._path.is_empty() and not _walk_onto(step)) or clock > STEP_GIVE_UP:
				crew._path.clear()
				_begin_shooting()
		Mode.SHOOT:
			_shoot(delta)
		Mode.BACK:
			if (crew._path.is_empty() and not _walk_onto(spot)) or clock > STEP_GIVE_UP:
				crew._path.clear()
				_get_down(_down_time())
		Mode.OPEN:
			_fight_in_open(delta)


# --- choosing a spot ------------------------------------------------------------

## Picks a spot and sets off. [param want]: 0 the best, +1 only one at least
## a metre nearer him than it stands, -1 only one at least a metre further.
## [param relaxed]: anywhere out of his sight standing, out to
## FALL_BACK_RADIUS, with no fair-walk rule. False with none.
func _pick(want: int, relaxed := false) -> bool:
	var found := find(want, relaxed)
	if found.is_empty():
		return false
	_claim(found)
	return true


## The spot it would pick: {tile, at, low, step, peek, score}, or empty.
func find(want: int, relaxed := false) -> Dictionary:
	var layout := crew.layout
	if layout == null:
		return {}
	var last := crew._last_seen
	var eye := last + Vector3.UP * Crew3D.EYE_HEIGHT
	var torso := last + Vector3.UP * Crew3D.TORSO_HEIGHT
	var astar := CrewPaths.grid(layout)
	var here := crew.global_position
	var here_far := _flat(here, last)
	var radius := FALL_BACK_RADIUS if relaxed else SEARCH_RADIUS
	var rooms: Array[int] = []
	for at: Vector3 in [here, last]:
		for room in CrewNoise.rooms_at(layout, at):
			if not room in rooms:
				rooms.append(room)
	if rooms.is_empty() and crew.home_room >= 0 and crew.home_room < layout.rooms.size():
		rooms.append(crew.home_room)
	rooms = CrewCombat.rooms_near(layout, rooms)
	var claimed := _claimed()
	var others := _other_spots()

	var found: Array[Dictionary] = []
	for room in rooms:
		var breakers := crew._breaker_tiles(room)
		for t: Vector2i in layout.rooms[room].tiles():
			if not astar.is_in_boundsv(t) or astar.is_point_solid(t) or breakers.has(t) or claimed.has(t) or unreachable.has(t):
				continue
			var at := ShipBuilder3D.tile_to_world(t)
			if _flat(here, at) > radius:
				continue
			var far := _flat(at, last)
			if want > 0 and far > here_far - 1.0:
				continue
			if want < 0 and far < here_far + 1.0:
				continue
			if relaxed:
				# Anywhere he cannot see a standing body.
				if not crew._blocked(at + Vector3.UP * Crew3D.EYE_HEIGHT, eye):
					continue
			else:
				# Hidden crouched: from his torso and from his eyes, or he
				# would see it there and it would count itself flanked.
				if not _against_something(astar, t):
					continue
				if not crew._blocked(at + Vector3.UP * Crew3D.COVER_HEIGHT, torso) \
						or not crew._blocked(at + Vector3.UP * Crew3D.COVER_HEIGHT, eye):
					continue
			var is_low := not crew._muzzle_blocked_from(at, torso) \
					and crew._blocked(at + Vector3.UP * Crew3D.COVER_HEIGHT, eye)
			var out := Vector3.INF
			if not is_low:
				out = _step_out(astar, t, torso, claimed)
			var peek := is_low or out != Vector3.INF
			if not peek and not relaxed:
				continue
			found.append({"tile": t, "at": at, "low": is_low, "step": out, "peek": peek,
					"score": _score(at, far, is_low, radius, others)})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.score > y.score)

	# Only the best few are walked: is the way there one it would take?
	var tried := 0
	for entry in found:
		if tried >= TRIED:
			break
		tried += 1
		if fair_walk(entry.at, radius * WALK_REACH, not relaxed):
			return entry
	return {}


## A wall or a prop on one of its four sides.
static func _against_something(astar: AStarGrid2D, t: Vector2i) -> bool:
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if not astar.is_in_boundsv(t + side) or astar.is_point_solid(t + side):
			return true
	return false


## The nearest tile beside [param t] it can step straight to and fire from,
## or INF.
func _step_out(astar: AStarGrid2D, t: Vector2i, torso: Vector3, claimed: Dictionary) -> Vector3:
	var at := ShipBuilder3D.tile_to_world(t)
	var best := Vector3.INF
	var best_far := INF
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var side := t + Vector2i(dx, dy)
			if side == t or not astar.is_in_boundsv(side) or astar.is_point_solid(side) or claimed.has(side):
				continue
			var point := ShipBuilder3D.tile_to_world(side)
			if not CrewPaths.clear(astar, at, point):
				continue
			if crew._muzzle_blocked_from(point, torso):
				continue
			var far := at.distance_to(point)
			if far < best_far:
				best_far = far
				best = point
	return best


func _score(at: Vector3, far: float, is_low: bool, radius: float, others: Array[Vector3]) -> float:
	var fit := 1.0
	var gunnery := crew.gunnery
	if gunnery != null:
		if far < gunnery.range_near:
			fit = clampf(1.0 - (gunnery.range_near - far) / BAND_FALLOFF, 0.0, 1.0)
		elif far > gunnery.range_far:
			fit = clampf(1.0 - (far - gunnery.range_far) / BAND_FALLOFF, 0.0, 1.0)
	var near := 1.0 - clampf(_flat(crew.global_position, at) / radius, 0.0, 1.0)
	var crowded := others.any(func(p: Vector3) -> bool: return _flat(p, at) < SPACING)
	return W_NEAR * near + W_RANGE * fit + W_LOW * (1.0 if is_low else FULL_SHARE) - (W_CROWD if crowded else 0.0)


## Whether the walk from where it stands to [param to] is no longer than
## [param reach] and, when [param fair] (the fall-back walk need not be),
## fair: it never comes nearer the Pirate's last-seen spot than both its
## ends do, less NEARER_SLACK, and crosses no more than OPEN_RUN metres of
## floor in his view (a sample every WALK_SAMPLE metres whose torso his
## eyes can see).
func fair_walk(to: Vector3, reach := INF, fair := true) -> bool:
	var last := crew._last_seen
	var eye := last + Vector3.UP * Crew3D.EYE_HEIGHT
	var route: Array[Vector3] = []
	route.assign(crew._waypoints(to))
	if route.is_empty():
		route.append(to)
	route = CrewPaths.route(crew.layout, crew.global_position, route)
	var length := 0.0
	var at := crew.global_position
	for point in route:
		length += _flat(at, point)
		at = point
	if length > reach:
		return false
	var bodies := _bodies_in_the_way()
	if not bodies.is_empty():
		at = crew.global_position
		for point in route:
			var leg := _flat(at, point)
			var steps := maxi(ceili(leg / WALK_SAMPLE), 1)
			for i in range(1, steps + 1):
				var sample := at.lerp(point, float(i) / steps)
				if bodies.any(func(b: Vector3) -> bool: return _flat(b, sample) < BODY_CLEAR):
					return false
			at = point
	if not fair:
		return true
	var floor_far := minf(_flat(crew.global_position, last), _flat(to, last)) - NEARER_SLACK
	var seen := 0.0
	var cursor := crew.global_position
	for point in route:
		var leg := _flat(cursor, point)
		var steps := maxi(ceili(leg / WALK_SAMPLE), 1)
		for i in range(1, steps + 1):
			var sample := cursor.lerp(point, float(i) / steps)
			if _flat(sample, last) < floor_far:
				return false
			if not crew._blocked(sample + Vector3.UP * Crew3D.TORSO_HEIGHT, eye):
				seen += leg / steps
				if seen > OPEN_RUN:
					return false
		cursor = point
	return true


func _claim(found: Dictionary) -> void:
	tile = found.tile
	spot = found.at
	step = found.step
	low = found.low
	has_peek = found.peek
	score = found.score
	held = 0.0
	blind = 0
	exposed = 0.0
	_stand()
	if _flat(crew.global_position, spot) <= crew.arrive_radius:
		crew._path.clear()
		_get_down(ARRIVE_DOWN)
		return
	crew._repath_to(spot)
	_set_mode(Mode.MOVE)


## Seconds its walk has gone without moving MOVE_PROGRESS metres.
func _stalling(delta: float) -> float:
	if _progress_at == Vector3.INF or _flat(crew.global_position, _progress_at) > MOVE_PROGRESS:
		_progress_at = crew.global_position
		_stalled = 0.0
	else:
		_stalled += delta
	return _stalled


## Stopped short of [param point] (a walk ends within the body's arrive
## radius): one more step, aimed past it, so it stands on it. Once per
## mode; false when it already stands on it or has had its step.
func _walk_onto(point: Vector3) -> bool:
	var off := point - crew.global_position
	off.y = 0.0
	if off.length() <= ON_SPOT or _nudged:
		return false
	_nudged = true
	crew._path.assign([point + off.normalized() * maxf(crew.arrive_radius - ON_SPOT * 0.5, 0.0)])
	return true


func _unclaim() -> void:
	tile = Vector2i.MAX
	spot = Vector3.INF
	step = Vector3.INF
	has_peek = false


## The living Guards fighting beside this one, on its ship.
func _guards() -> Array[Crew3D]:
	var out: Array[Crew3D] = []
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other != null and other != crew and other.is_alive() and not other.is_worker() and other.layout == crew.layout:
			out.append(other)
	return out


## Tiles another Guard holds: {tile: true}. One Guard per spot.
func _claimed() -> Dictionary:
	var out := {}
	for other in _guards():
		if other.cover != null and other.cover.tile != Vector2i.MAX:
			out[other.cover.tile] = true
	return out


## Where every other Guard is, or will be: its spot if it has one.
func _other_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for other in _guards():
		if other.cover != null and other.cover.spot != Vector3.INF:
			out.append(other.cover.spot)
		else:
			out.append(other.global_position)
	return out


## Where the other crew stand still near it (down in cover, working,
## hiding): a walk through one of them would stall against its body.
func _bodies_in_the_way() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other != null and other != crew and other.is_alive() and not other.is_walking() \
				and _flat(other.global_position, crew.global_position) < FALL_BACK_RADIUS * WALK_REACH:
			out.append(other.global_position)
	return out


## Another Guard is moving up or back now.
func _someone_moving() -> bool:
	for other in _guards():
		if other.cover != null and other.cover.mover_clock > 0.0:
			return true
	return false


## No cover in reach: fall back out of his sight, or fight where it stands.
func _no_cover() -> void:
	if _pick(0, true):
		return
	_unclaim()
	_stand()
	crew._path.clear()
	think = LOOK_OPEN
	_set_mode(Mode.OPEN)
	_start_burst()
	timer = crew.gunnery.settle * _jitter() if crew.gunnery != null else 0.0


# --- holding a spot -------------------------------------------------------------

func _get_down(time: float) -> void:
	timer = time
	downs += 1
	_crouch()
	var look := crew._last_seen - crew.global_position
	look.y = 0.0
	if look.length_squared() > 0.01:
		crew._aim = look.normalized()
	_set_mode(Mode.DOWN)


## What makes it leave, or change what it is doing, while down. True when
## it did.
func _watch(delta: float) -> bool:
	var target := crew.target
	var eye: Vector3 = target.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
	var far := _flat(crew.global_position, target.global_position)
	# Flanked: he can see it where it hides.
	if far <= crew.vision_range and _alive(target) \
			and not crew._blocked(crew.global_position + Vector3.UP * Crew3D.COVER_HEIGHT, eye):
		exposed += delta
	else:
		exposed = 0.0
	if exposed > FLANKED_AFTER:
		exposed = 0.0
		if not _pick(0):
			_no_cover()
		return true
	if crew._can_see and far < TOO_CLOSE:
		if not _pick(-1):
			_no_cover()
		return true
	if not has_peek and crew._can_see:
		# Hiding where he could not see it standing, and now he can: it no
		# longer hides, and it has no shot from here.
		if not _pick(0):
			_no_cover()
		return true
	if not has_peek and think <= 0.0:
		# Hiding with no shot: look again for real cover.
		think = LOOK_HIDING
		if _pick(0):
			return true
	if blind >= BLIND_PEEKS:
		blind = 0
		if _pick(0):
			return true
	if think <= 0.0 and not _someone_moving():
		var cover_far := _flat(spot, crew._last_seen)
		var hidden := crew._seen_ago > UNSEEN_ADVANCE
		var want := 0
		if hidden:
			want = 1
		elif held > HOLD_BEFORE_SHIFTING and crew.gunnery != null:
			if cover_far > crew.gunnery.range_far:
				want = 1
			elif cover_far < crew.gunnery.range_near:
				want = -1
		if want != 0:
			think = LOOK_SHIFT
			var found := find(want)
			if not found.is_empty() and (hidden or found.score > score * (1.0 + BETTER)):
				mover_clock = MOVER_TIME
				_claim(found)
				return true
	return false


# --- peeking and firing ---------------------------------------------------------

func _start_peek() -> void:
	if not has_peek:
		timer = LOOK_HIDING
		return
	if not crew._can_see and crew._seen_ago > UNSEEN_STAY_DOWN and crew._rng.randf() < 0.5:
		# Nothing to shoot at: stay down a little longer rather than bob.
		timer = _down_time() * 0.5
		return
	_stand()
	if low or step == Vector3.INF:
		_begin_shooting()
	else:
		crew._path.assign([step])
		_set_mode(Mode.OUT)


func _begin_shooting() -> void:
	bursts = crew.gunnery.bursts_per_peek if crew.gunnery != null else 1
	_start_burst()
	wait = 0.0
	timer = crew.gunnery.settle * _jitter() if crew.gunnery != null else 0.0
	_set_mode(Mode.SHOOT)


func _start_burst() -> void:
	crew._new_burst()


func _shoot(delta: float) -> void:
	if timer > 0.0:
		return  # settling, or between bursts
	if not crew._can_see or crew._muzzle_blocked():
		wait += delta
		if wait > WAIT_UP:
			blind += 1
			_duck()
		return
	wait = 0.0
	if crew._shots_left <= 0:
		bursts -= 1
		if bursts <= 0:
			blind = 0
			_duck()
			return
		_start_burst()
		var gunnery := crew.gunnery
		timer = crew._rng.randf_range(gunnery.gap_between_bursts_low,
				maxf(gunnery.gap_between_bursts_high, gunnery.gap_between_bursts_low)) * _jitter()
		return
	_fire_when_ready()


## Fires its next shot once the gun is ready, never starting a burst in step
## with another crew member's.
func _fire_when_ready() -> void:
	if crew._shot_timer > 0.0:
		return
	if crew._shots_left == crew.burst_length:
		if CrewCombat.burst_blocked(crew):
			crew._shot_timer = 0.05
			return
		crew.burst_frame = Engine.get_physics_frames()
	crew._path.clear()
	crew._aim = (crew.target.global_position + Vector3.UP * Crew3D.TORSO_HEIGHT
			- (crew.global_position + Vector3.UP * Crew3D.MUZZLE_HEIGHT)).normalized()
	crew._fire()


func _duck() -> void:
	if spot == Vector3.INF:
		return
	if low or step == Vector3.INF:
		_get_down(_down_time())
	else:
		crew._path.assign([spot])
		_stand()
		_set_mode(Mode.BACK)


## Seconds down after a peek: its Gunnery's time down, drawn, varied by
## JITTER either way.
func _down_time() -> float:
	return down_time(crew.gunnery, crew._rng)


static func down_time(gunnery: Gunnery, rng: RandomNumberGenerator) -> float:
	if gunnery == null:
		return 1.0
	return gunnery.draw_time_down(rng) * (1.0 + rng.randf_range(-JITTER, JITTER))


func _jitter() -> float:
	return 1.0 + crew._rng.randf_range(-JITTER, JITTER)


## No cover and nowhere to hide: bursts and pauses standing where it is,
## stepping to a spot with a clear shot when it has none, and looking again
## for cover every LOOK_OPEN seconds.
func _fight_in_open(delta: float) -> void:
	if think <= 0.0:
		think = LOOK_OPEN
		if _pick(0):
			return
		if crew._path.is_empty() and (not crew._can_see or crew._muzzle_blocked()):
			var to := crew._find_firing_position()
			if to != Vector3.INF:
				crew._repath_to(to)
	if not crew._path.is_empty() and _stalling(delta) > MOVE_GIVE_UP:
		crew._path.clear()
	if timer > 0.0:
		return
	if not crew._can_see or crew._muzzle_blocked():
		return
	if crew._shots_left <= 0:
		_start_burst()
		timer = _down_time() * OPEN_PAUSE
		return
	_fire_when_ready()


## A shot of his: one passing within NEAR_MISS of it keeps it down
## NEAR_MISS_HOLD longer (never past its longest time down and that), or
## sends it down if up. [param from] and [param along] are the shot's line.
func near_miss(from: Vector3, along: Vector3) -> bool:
	var to := crew.global_position + Vector3.UP - from
	var ahead := to.dot(along)
	if ahead <= 0.0 or (to - along * ahead).length() > NEAR_MISS:
		return false
	near_misses += 1
	if mode == Mode.DOWN:
		timer = maxf(timer, minf(timer + NEAR_MISS_HOLD, longest_down()))
	elif mode == Mode.SHOOT and spot != Vector3.INF:
		_duck()
		timer += NEAR_MISS_HOLD
	return true


# --- the stand-in crouch ----------------------------------------------------------

func _crouch() -> void:
	if crouched:
		return
	crouched = true
	crew.model.position.y = -SINK
	if _capsule != null:
		_capsule.height = _stand_height * CROUCH
		_shape.position.y = _stand_y * CROUCH


func _stand() -> void:
	if not crouched:
		return
	crouched = false
	crew.model.position.y = 0.0
	if _capsule != null:
		_capsule.height = _stand_height
		_shape.position.y = _stand_y


## The longest one stretch down can last with him in sight: its Gunnery's
## longest time down, varied up, and a near miss's hold on top.
func longest_down() -> float:
	return (crew.gunnery.time_down_high if crew.gunnery != null else 1.0) * (1.0 + JITTER) + NEAR_MISS_HOLD


func _set_mode(next: Mode) -> void:
	mode = next
	clock = 0.0
	_nudged = false
	_progress_at = Vector3.INF
	_stalled = 0.0
	crew.state = Crew3D.State.FIGHT if next in [Mode.OUT, Mode.SHOOT, Mode.OPEN] else Crew3D.State.COVER


static func _alive(node: Node) -> bool:
	return not node.has_method("is_alive") or node.is_alive()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
