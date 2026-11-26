class_name CrewCover
extends RefCounted
## How one Guard fights from cover: it finds a spot behind a prop, a wall, a
## door frame or a corner, walks there by a fair way, stays down, and peeks
## to fire (up over low cover, out to the side of full cover), in its gun's
## rhythm. It leaves when flanked, closed on, left with no shot, out of its
## range band, or when the Pirate has been gone a while. With no cover in
## reach it falls back out of his sight, or fights where it stands. What its
## gun changes is its habit ([CrewHabit]): the Shotgun ambushes at a
## doorway and racks before it shows itself, the Marksman Rifle perches and
## shows a sight line before each shot.
##
## Every Guard holds one ([member Crew3D.cover]). The body drives it from
## its FIGHT and COVER states: [method begin] on entering either, [method
## tick] every physics step, [method release] on leaving. It sets the body's
## state to COVER while moving to a spot, down or stepping back, and to
## FIGHT while up, stepping out or fighting in the open. Spots are found
## from the walking grid ([CrewPaths]) and sight rays when needed; nothing is
## authored. See "Guard combat" in `CREW_AI.md`.

enum Mode { NONE, MOVE, DOWN, OUT, SHOOT, BACK, OPEN, AMBUSH }
const MODE_NAMES: PackedStringArray = ["none", "to cover", "down", "stepping out", "up", "back in", "in the open", "in ambush"]

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
## A spot out of its range band, held its Gunnery's hold before shifting,
## is left for one nearer or further only if that one scores this much
## better.
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
## The gun it fights with, for its habit.
var gun: CrewHabit.Gun
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
## Seconds of this stretch down spent waiting on its habit rather than its
## time down: for a true-aim place to start its sight line (Marksman Rifle),
## or holding fire with him beyond SHOTGUN_HOLD_FIRE (Shotgun). A watcher
## timing how long it stays down leaves these out.
var waited := 0.0
## A Marksman Rifle with him inside PERCH_CLOSE and no fair walk to a
## further perch fires from the hip: no sight line, its cone doubled, an
## ordinary gun for true aim.
var hip := false
## A Shotgun walking to, or waiting at, its ambush beside the doorway at
## door_at.
var ambushing := false
var door_at := Vector3.INF
## The Marksman Rifle's sight line: seconds left on it (negative with none
## showing), where it points now, and where it locked SIGHT_LOCK before the
## shot.
var line_left := -1.0
var line: CrewSightLine
var _line_at := Vector3.INF
var _locked := Vector3.INF
## It fired (or lost) its shot this peek: it wants no true-aim place again
## until it next gets down.
var _peek_spent := false
## Racked for the pop up ahead (Shotgun).
var _racked := false
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
	gun = CrewHabit.gun_of(body.weapon)
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
	waited = 0.0
	hip = false
	ambushing = false
	_racked = false


## Out of the fight (searching, dead, back on routine): stands up and frees
## its spot.
func release() -> void:
	_stand()
	_unclaim()
	_end_line()
	_give_up_place()
	mover_clock = 0.0
	hip = false
	ambushing = false
	mode = Mode.NONE


func is_engaged() -> bool:
	return mode != Mode.NONE


## Down behind its own cover, or stepping out or back: out of his sight
## because it ducked, not because he broke sight, so its aim is held
## ([member Crew3D._exposed_for]).
func behind_own_cover() -> bool:
	return mode in [Mode.DOWN, Mode.OUT, Mode.BACK]


func tick(delta: float) -> void:
	timer -= delta
	clock += delta
	think -= delta
	mover_clock -= delta
	for key in unreachable.keys():
		unreachable[key] -= delta
		if unreachable[key] <= 0.0:
			unreachable.erase(key)
	if crew.target == null or not is_instance_valid(crew.target) \
			or (crew._seen_ago > UNSEEN_SEARCH and not perched()):
		crew._enter(Crew3D.State.SEARCH)
		return
	if mode in [Mode.DOWN, Mode.OUT, Mode.SHOOT, Mode.BACK]:
		held += delta
	if hip and _flat(crew.global_position, crew._last_seen) >= CrewHabit.PERCH_CLOSE:
		hip = false
	match mode:
		Mode.NONE:
			if not _pick(0):
				_no_cover()
		Mode.MOVE:
			if crew._path.is_empty() and not _walk_onto(spot):
				if ambushing:
					_set_mode(Mode.AMBUSH)
				else:
					_get_down(ARRIVE_DOWN)
			elif _stalling(delta) > MOVE_GIVE_UP:
				# Cannot get there: think again, and not about this spot.
				unreachable[tile] = UNREACHABLE_FOR
				crew._path.clear()
				_unclaim()
				_set_mode(Mode.NONE)
		Mode.DOWN:
			if not _watch(delta):
				if timer <= 0.0:
					if _holds_down():
						waited += delta
					else:
						_start_peek()
				elif gun == CrewHabit.Gun.SHOTGUN and has_peek and (low or step == Vector3.INF) \
						and not _racked and timer <= CrewHabit.RACK_LEAD and not holds_fire():
					# Racked while still down: the tell before it pops up.
					crew.rack()
					_racked = true
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
		Mode.AMBUSH:
			_wait_in_ambush()


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
## [param max_far]: only a spot no further than this from him (a Shotgun's
## walk into its band). Only a Shotgun takes a spot within SHOTGUN_CLOSE of
## him. A Marksman Rifle searches out to PERCH_RADIUS and scores a spot by
## its clear line to him ([method _score]).
func find(want: int, relaxed := false, max_far := INF) -> Dictionary:
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
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE:
		radius = maxf(radius, CrewHabit.PERCH_RADIUS)
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
			if far > max_far:
				continue
			if gun != CrewHabit.Gun.SHOTGUN and far < CrewHabit.SHOTGUN_CLOSE:
				continue
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
			# The length of its clear line to him from where it fires.
			var line_far := far
			if peek:
				line_far = _flat(at if is_low else out, last)
				if gun == CrewHabit.Gun.MARKSMAN_RIFLE and line_far > CrewHabit.PERCH_LINE:
					continue  # past its sight: no line from there
			found.append({"tile": t, "at": at, "low": is_low, "step": out, "peek": peek,
					"score": _score(at, far, is_low, radius, others, line_far if peek else 0.0)})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.score > y.score)

	# Only the best few are walked: is the way there one it would take?
	var tries := CrewHabit.PERCH_TRIED if gun == CrewHabit.Gun.MARKSMAN_RIFLE else TRIED
	var tried := 0
	for entry in found:
		if tried >= tries:
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


## The score: near it, low cover, its range band, less crowding. A
## Marksman Rifle scores the length of its clear line to him
## ([param line_far], up to PERCH_LINE) in place of its band.
func _score(at: Vector3, far: float, is_low: bool, radius: float, others: Array[Vector3], line_far := 0.0) -> float:
	var reach := 0.0
	var gunnery := crew.gunnery
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE:
		reach = CrewHabit.W_LINE * clampf(line_far / CrewHabit.PERCH_LINE, 0.0, 1.0)
	else:
		var fit := 1.0
		if gunnery != null:
			if far < gunnery.range_near:
				fit = clampf(1.0 - (gunnery.range_near - far) / BAND_FALLOFF, 0.0, 1.0)
			elif far > gunnery.range_far:
				fit = clampf(1.0 - (far - gunnery.range_far) / BAND_FALLOFF, 0.0, 1.0)
		reach = W_RANGE * fit
	var near := 1.0 - clampf(_flat(crew.global_position, at) / radius, 0.0, 1.0)
	var crowded := others.any(func(p: Vector3) -> bool: return _flat(p, at) < SPACING)
	return W_NEAR * near + reach + W_LOW * (1.0 if is_low else FULL_SHARE) - (W_CROWD if crowded else 0.0)


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


## Claims [param found] and sets off for it; [param ambush]: to wait there
## in ambush (Shotgun) rather than get down.
func _claim(found: Dictionary, ambush := false) -> void:
	if found.tile != tile:
		held = 0.0
	tile = found.tile
	spot = found.at
	step = found.step
	low = found.low
	has_peek = found.peek
	score = found.score
	blind = 0
	exposed = 0.0
	ambushing = ambush
	door_at = found.get("door", Vector3.INF)
	_stand()
	# Already on it (a walk ends within its arrive radius, so a spot that
	# near is still walked onto: its lines were judged from the centre).
	if _flat(crew.global_position, spot) <= ON_SPOT:
		crew._path.clear()
		if ambush:
			_set_mode(Mode.AMBUSH)
		else:
			_get_down(ARRIVE_DOWN)
		return
	crew._repath_to(spot)
	_set_mode(Mode.MOVE)


## Seconds its walk has gone without moving MOVE_PROGRESS metres.
func _stalling(delta: float) -> float:
	# Stood aside letting another crew member by is waiting, not stalling.
	if _progress_at == Vector3.INF or _flat(crew.global_position, _progress_at) > MOVE_PROGRESS or crew._yield_to != null:
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
## hiding), or are stuck trying to walk (jammed against someone): a walk
## through one of them would stall against its body.
func _bodies_in_the_way() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for node in crew.get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other != null and other != crew and other.is_alive() and (not other.is_walking() or other._stuck_tries > 0) \
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
	waited = 0.0
	_racked = false
	_peek_spent = false
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
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE:
		# Him close: back to a further perch, or the hip. It takes the place
		# of "too close".
		if _marksman_close():
			return true
	elif crew._can_see and far < TOO_CLOSE and gun != CrewHabit.Gun.SHOTGUN:
		# Too close; the Shotgun stays.
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
		# A Marksman Rifle with him hidden holds its perch.
		if (gun != CrewHabit.Gun.MARKSMAN_RIFLE or crew._seen_ago < WAIT_UP) and _pick(0):
			return true
	if think <= 0.0 and not _someone_moving():
		return _shift()
	return false


## Moving one spot by its habit: out of its band after holding it its
## Gunnery's hold before shifting (a Shotgun into its band, else to its
## ambush), or nearer where he was after UNSEEN_ADVANCE unseen. A Marksman
## Rifle never moves up. True when it set off.
func _shift() -> bool:
	var gunnery := crew.gunnery
	var hold := gunnery.hold_before_shifting if gunnery != null else -1.0
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE or gunnery == null:
		return false
	var cover_far := _flat(spot, crew._last_seen)
	var out_of_band := hold >= 0.0 and held > hold
	if gun == CrewHabit.Gun.SHOTGUN and out_of_band and cover_far > gunnery.range_far:
		think = LOOK_SHIFT
		var into := find(0, false, gunnery.range_far)
		if not into.is_empty():
			mover_clock = MOVER_TIME
			_claim(into)
			return true
		var lie := ambush_spot()
		if not lie.is_empty():
			mover_clock = MOVER_TIME
			_claim(lie, true)
			return true
	var hidden := crew._seen_ago > UNSEEN_ADVANCE
	var want := 0
	if hidden:
		want = 1
	elif out_of_band:
		if cover_far > gunnery.range_far:
			want = 1
		elif cover_far < gunnery.range_near:
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
		_racked = false
		return
	var pops_up := low or step == Vector3.INF
	if gun == CrewHabit.Gun.SHOTGUN and CrewHabit.racks(crew.weapon):
		# The rack, its tell: still down RACK_LEAD before a pop up, or as it
		# starts its step out from behind full cover.
		if pops_up and not _racked:
			crew.rack()
			_racked = true
			timer = CrewHabit.RACK_LEAD
			return
		if not pops_up:
			crew.rack()
	_stand()
	if pops_up:
		_begin_shooting()
	else:
		crew._path.assign([step])
		_set_mode(Mode.OUT)


## Down with its time down spent, it stays down for its habit: a Shotgun
## with him beyond SHOTGUN_HOLD_FIRE, or a Marksman Rifle waiting for a
## true-aim place to start its sight line (it is queued for one,
## [method wants_place]).
func _holds_down() -> bool:
	if holds_fire():
		return true
	return uses_line() and has_peek and not _holds_place()


func _begin_shooting() -> void:
	bursts = crew.gunnery.bursts_per_peek if crew.gunnery != null else 1
	_start_burst()
	wait = 0.0
	_peek_spent = false
	var settle := crew.gunnery.settle * _jitter() if crew.gunnery != null else 0.0
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE:
		# Its sight line is its settle; from the hip, an ordinary one.
		settle = CrewHabit.HIP_SETTLE * _jitter() if hip else 0.0
	elif CrewHabit.racks(crew.weapon):
		# Its first shot RACK_EARLIEST to RACK_LATEST after its rack.
		var age := crew.rack_age()
		settle = clampf(settle, CrewHabit.RACK_EARLIEST - age, CrewHabit.RACK_LATEST - age)
	timer = settle
	_set_mode(Mode.SHOOT)


func _start_burst() -> void:
	crew._new_burst()


func _shoot(delta: float) -> void:
	if timer > 0.0:
		return  # settling, or between bursts
	if uses_line() and _flat(crew.global_position, crew._last_seen) < CrewHabit.PERCH_CLOSE:
		# Him close: no line; down, to fall back or take to the hip.
		_duck()
		return
	if not crew._can_see or crew._muzzle_blocked() or holds_fire():
		_end_line()
		wait += delta
		if wait > WAIT_UP:
			blind += 1
			_duck()
		return
	wait = 0.0
	if uses_line():
		if _peek_spent or crew._shots_left <= 0:
			blind = 0
			_duck()
			return
		if _line_up(delta) == LINE_WAITING:
			# Up with no true-aim place (it lost one): it waits, then ducks.
			wait += delta
			if wait > WAIT_UP:
				_duck()
		return
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
	if CrewHabit.racks(crew.weapon):
		# Every Shotgun shot comes RACK_EARLIEST to RACK_LATEST after a rack.
		var age := crew.rack_age()
		if age > CrewHabit.RACK_LATEST:
			crew.rack()
			crew._shot_timer = CrewHabit.RACK_LEAD
			return
		if age < CrewHabit.RACK_EARLIEST:
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
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE and not hip and _marksman_close():
		return
	if think <= 0.0:
		think = LOOK_OPEN
		if _pick(0):
			return
		var gunnery := crew.gunnery
		if gun == CrewHabit.Gun.SHOTGUN and gunnery != null and gunnery.hold_before_shifting >= 0.0 \
				and clock > gunnery.hold_before_shifting and not _someone_moving() \
				and _flat(crew.global_position, crew._last_seen) > gunnery.range_far:
			# Out of its band with no cover: to its ambush, if it has one.
			var lie := ambush_spot()
			if not lie.is_empty():
				mover_clock = MOVER_TIME
				_claim(lie, true)
				return
		if crew._path.is_empty() and (not crew._can_see or crew._muzzle_blocked()):
			var to := crew._find_firing_position()
			if to != Vector3.INF:
				crew._repath_to(to)
	if not crew._path.is_empty() and _stalling(delta) > MOVE_GIVE_UP:
		crew._path.clear()
	if timer > 0.0:
		return
	if not crew._can_see or crew._muzzle_blocked() or holds_fire():
		_end_line()
		return
	if uses_line():
		if _line_up(delta) == LINE_FIRED:
			_start_burst()
			timer = _down_time() * OPEN_PAUSE
			_peek_spent = false
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
		_racked = false
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
	if not next in [Mode.OUT, Mode.SHOOT]:
		# The peek is over: its sight line goes, and its true-aim place.
		_end_line()
		_give_up_place()
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


# --- the Shotgun's ambush ---------------------------------------------------------

## Where a Shotgun waits in ambush: beside the doorway of his Room nearest
## to it, within AMBUSH_REACH of the opening, where he cannot see it
## standing, by a fair walk; the tile nearest the opening first. Empty with
## none (his Room has no Door, or nowhere hidden near it).
func ambush_spot() -> Dictionary:
	var layout := crew.layout
	if layout == null:
		return {}
	var last := crew._last_seen
	var his := CrewNoise.rooms_at(layout, last)
	var door: DoorData = null
	var door_far := INF
	for d in layout.doors:
		if d.locked or not (d.room_a in his or d.room_b in his):
			continue
		var far := _flat(crew.global_position, ShipBuilder3D.door_center_world(d))
		if far < door_far:
			door_far = far
			door = d
	if door == null:
		return {}
	var centre := ShipBuilder3D.door_center_world(door)
	var eye := last + Vector3.UP * Crew3D.EYE_HEIGHT
	var astar := CrewPaths.grid(layout)
	var claimed := _claimed()
	var found: Array[Dictionary] = []
	for room in [door.room_a, door.room_b]:
		if room < 0 or room >= layout.rooms.size():
			continue
		var breakers := crew._breaker_tiles(room)
		for t: Vector2i in layout.rooms[room].tiles():
			if not astar.is_in_boundsv(t) or astar.is_point_solid(t) or breakers.has(t) or claimed.has(t) or unreachable.has(t):
				continue
			var at := ShipBuilder3D.tile_to_world(t)
			var near := _flat(at, centre)
			if near > CrewHabit.AMBUSH_REACH:
				continue
			if not crew._blocked(at + Vector3.UP * Crew3D.EYE_HEIGHT, eye):
				continue  # he would see it there
			found.append({"tile": t, "at": at, "low": false, "step": Vector3.INF, "peek": false,
					"score": -near, "door": centre})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x.score > y.score)
	var tried := 0
	for entry in found:
		if tried >= TRIED:
			break
		tried += 1
		if fair_walk(entry.at, FALL_BACK_RADIUS * WALK_REACH):
			return entry
	return {}


## Waiting in ambush, stood beside the doorway facing it, out of his sight.
## He comes into sight: within SHOTGUN_HOLD_FIRE with a clear muzzle line it
## fires from where it stands (and fights on from there by the cover
## rules), else it picks again. A fair walk into its band appearing, it
## takes it. Unseen UNSEEN_SEARCH, it searches ([method tick]).
func _wait_in_ambush() -> void:
	_stand()
	var look := door_at - crew.global_position
	look.y = 0.0
	if door_at != Vector3.INF and look.length_squared() > 0.01:
		crew._aim = look.normalized()
	if crew._can_see:
		ambushing = false
		if _flat(crew.global_position, crew.target.global_position) <= CrewHabit.SHOTGUN_HOLD_FIRE \
				and not crew._muzzle_blocked():
			low = true
			has_peek = true
			_begin_shooting()
		elif not _pick(0):
			_no_cover()
		return
	var gunnery := crew.gunnery
	if think <= 0.0 and gunnery != null and not _someone_moving():
		think = LOOK_SHIFT
		var into := find(0, false, gunnery.range_far)
		if not into.is_empty():
			mover_clock = MOVER_TIME
			_claim(into)


# --- the Marksman Rifle's perch and sight line -------------------------------------

## What [method _line_up] did this tick.
enum { LINE_WAITING, LINE_SHOWING, LINE_FIRED }


## A Marksman Rifle firing by its sight line (not from the hip).
func uses_line() -> bool:
	return gun == CrewHabit.Gun.MARKSMAN_RIFLE and not hip


## A Marksman Rifle on a cover spot with a peek: it holds it however long
## he is unseen.
func perched() -> bool:
	return gun == CrewHabit.Gun.MARKSMAN_RIFLE and has_peek and spot != Vector3.INF


## A Shotgun with him beyond SHOTGUN_HOLD_FIRE: it holds its fire.
func holds_fire() -> bool:
	if gun != CrewHabit.Gun.SHOTGUN or crew.target == null or not is_instance_valid(crew.target):
		return false
	var at: Vector3 = crew.target.global_position if crew._can_see else crew._last_seen
	return _flat(crew.global_position, at) > CrewHabit.SHOTGUN_HOLD_FIRE


## A Marksman Rifle wanting one of the true-aim places, or holding one for
## its sight line: down and ready to peek, stepping out or up, or in the
## open with a shot. [CrewFire] queues it first and never hands its place on
## while it wants it; it gives the place up after the shot.
func wants_place() -> bool:
	if not uses_line() or _peek_spent:
		return false
	match mode:
		Mode.DOWN:
			return timer <= 0.0 and has_peek
		Mode.OUT:
			return true
		Mode.SHOOT:
			return line_left >= 0.0 or (crew._can_see and not crew._muzzle_blocked())
		Mode.OPEN:
			return timer <= 0.0 and crew._can_see and not crew._muzzle_blocked()
	return false


func _holds_place() -> bool:
	var fire := CrewFire.of(crew.target)
	return fire != null and crew in fire.holders


func _give_up_place() -> void:
	if not uses_line() or crew.target == null:
		return
	var fire := CrewFire.of(crew.target)
	if fire != null:
		fire.give_up(crew)


## Its sight line, up and with a shot: once it holds a true-aim place, a
## line from the rifle to him for its Gunnery's settle (0.9 s), following
## him (led) until SIGHT_LOCK before the shot and fixed there; the shot goes
## where it was fixed. Then it gives the place up.
func _line_up(delta: float) -> int:
	if not _holds_place():
		_end_line()
		return LINE_WAITING
	if line_left < 0.0:
		if CrewCombat.burst_blocked(crew):
			return LINE_WAITING
		crew.burst_frame = Engine.get_physics_frames()
		line_left = crew.gunnery.settle if crew.gunnery != null else 0.9
		_line_at = Vector3.INF
		_locked = Vector3.INF
	line_left -= delta
	var from := crew.global_position + Vector3.UP * Crew3D.MUZZLE_HEIGHT
	if line_left > CrewHabit.SIGHT_LOCK or _line_at == Vector3.INF:
		_line_at = CrewFire.lead_point(crew, from)
	elif _locked == Vector3.INF:
		_locked = _line_at
	var at := _locked if _locked != Vector3.INF else _line_at
	var along := (at - from).normalized()
	crew._aim = along
	_sight_line().show_between(from + along * Crew3D.MUZZLE_FORWARD, at)
	if line_left > 0.0:
		return LINE_SHOWING
	crew._path.clear()
	crew.aim_override = at
	crew._fire()
	_peek_spent = true
	_end_line()
	_give_up_place()
	return LINE_FIRED


func _end_line() -> void:
	line_left = -1.0
	_locked = Vector3.INF
	_line_at = Vector3.INF
	if line != null:
		line.visible = false


func _sight_line() -> CrewSightLine:
	if line == null:
		line = CrewSightLine.new()
		crew.add_child(line)
	return line


## Whether its sight line shows now.
func line_shown() -> bool:
	return line != null and line.visible


## Hit by him. During its sight line it loses the shot and ducks.
func hit() -> void:
	if line_left < 0.0:
		return
	_end_line()
	_give_up_place()
	_peek_spent = true
	if mode == Mode.SHOOT:
		_duck()
	elif mode == Mode.OPEN:
		_start_burst()
		timer = _down_time() * OPEN_PAUSE
		_peek_spent = false


## A Marksman Rifle with him inside PERCH_CLOSE falls back to a perch at
## least a metre further from him by a fair walk, else fires from the hip
## (looking again every LOOK_SHIFT). True when it set off.
func _marksman_close() -> bool:
	if _flat(crew.global_position, crew._last_seen) >= CrewHabit.PERCH_CLOSE:
		hip = false
		return false
	if hip and think > 0.0:
		return false
	think = LOOK_SHIFT
	var further := find(-1)
	if not further.is_empty():
		hip = false
		mover_clock = MOVER_TIME
		_claim(further)
		return true
	hip = true
	return false
