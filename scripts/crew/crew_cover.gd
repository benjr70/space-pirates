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
## shows a sight line before each shot. Dry, it reloads down behind its
## cover, or where it stands backing away with none in reach; down with him
## unseen a while, it tops up ([CrewMagazine]).
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
## How much nearer him than both its ends a walk may come, metres. The open
## floor it may cross in his view is the Sandbox's `open_floor`.
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
# Seconds he must see it crouched before it counts as flanked, and in
# sight how close he must be before it picks a spot further off, are the
# Sandbox's `flank_reaction` and `too_close`.
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
## Covering fire: a Guard changes cover only while another fighting him is
## up and has fired within COVER_FIRE seconds, waiting up to COVER_WAIT for
## it; with no partner able to fire when it starts waiting, it moves at once.
const COVER_FIRE := 1.0
const COVER_WAIT := 3.0
## The flank's end: a spot in his Room within this of the Door it came
## through, metres.
const FLANK_SPOT_REACH := 5.0
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
## Down behind cover a Guard squats or kneels on one knee, picked again at
## every drop ([method _crouch]) from a shuffled bag of this many squats and
## knees, so three drops in five are squats and the order is never the same.
const SQUATS := 3
const KNEES := 2
## Down behind its cover with him unseen this long, seconds, it tops up a
## part-used magazine.
const TOP_UP_UNSEEN := 3.0
## A Shotgun loading shell by shell, with a shell in and him in its sight
## this close, metres, breaks its reload off and fires.
const BREAK_OFF := 3.0
## Reloading where it stands (no cover in reach), it backs away from him
## this far, metres, at this fraction of its speed.
const BACK_AWAY := 2.0
const BACK_AWAY_SPEED := 0.4

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
## Between cover tiles: it left a spot it held for another and has not got
## down there yet. One Guard fighting him at a time, not counting a flanker.
var between := false
## Walking to its spot inside the Door it flanked through: it needs no
## covering fire and is not the one mover.
var flank_end := false
## Seconds it has waited to change cover (negative while it wants to stay),
## and whether it waits for covering fire at all (a partner able to fire
## when it started waiting).
var _move_wait := -1.0
var _wait_for_cover := false
## Asked to change cover in this tick ([method _may_leave]): a tick without
## asking ends the wait.
var _asked := false
## Held back from changing cover in this tick.
var _held_back := false
## It found where its habit would shift it to and waits to go.
var _want_shift := false
## Another Guard has fought him beside it in this fight (in his Room or one
## joined to it, or flanking); with none left now it is the last Guard: it
## moves up no more, picks a spot further from him once (_fell_back) and
## holds.
var had_partner := false
var last_guard := false
var _fell_back := false
## Which side of the prop it fires past next while firing on his cover.
var _edge_side := 1.0
var crouched := false
## How it is down: squatting or on one knee ([CrewPose.Stance]); STAND while
## up. The capsule's top follows it ([constant CrewPose.BODY_TOP]).
var stance: CrewPose.Stance = CrewPose.Stance.STAND
## What is left of the bag the next stances are drawn from, and its own
## draws, seeded off the body's, so picking a stance changes no other draw.
var _stances: Array[CrewPose.Stance] = []
var _stance_rng := RandomNumberGenerator.new()
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
## Reloading where it stands in the open fight, and backing away meanwhile.
var _open_reload := false
var _backing := false
var _capsule: CapsuleShape3D
var _shape: CollisionShape3D
var _stand_height := 1.7
var _stand_y := 0.85


func _init(body: Crew3D) -> void:
	crew = body
	gun = CrewHabit.gun_of(body.weapon)
	_stance_rng.seed = hash([body._rng.seed, "stance"])
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
	between = false
	flank_end = false
	_move_wait = -1.0
	_want_shift = false
	had_partner = false
	last_guard = false
	_fell_back = false
	_open_reload = false
	_backing = false


## Starts the cover fight at the end of a flank: a spot by the cover rules
## inside the Door at [param door], in his Room [param room], within
## FLANK_SPOT_REACH of it, walked to without the fair-walk rule (it is
## coming in from round the side). False with none: it picks as usual.
func begin_flank(door: Vector3, room: int) -> bool:
	var found := find(0, false, INF, room, door)
	if found.is_empty():
		return false
	_claim(found, false, true)
	return true


## Out of the fight (searching, dead, back on routine): stands up and frees
## its spot.
func release() -> void:
	_stand()
	_unclaim()
	_end_line()
	_give_up_place()
	between = false
	flank_end = false
	_move_wait = -1.0
	_want_shift = false
	hip = false
	ambushing = false
	_open_reload = false
	_backing = false
	if mode in [Mode.OUT, Mode.BACK]:
		crew._speed_scale = 1.0
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
	if _move_wait >= 0.0:
		_move_wait += delta
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
	_count_partners()
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
			if _reload_down():
				pass  # reloading: nothing makes it leave or peek
			elif not _watch(delta):
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
			_asked = false
			_wait_in_ambush()
			if not _asked:
				_move_wait = -1.0


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
## walk into its band). [param only_room] and [param around]: only a spot in
## that Room within FLANK_SPOT_REACH of that point, walked to without the
## fair-walk rule (the end of a flank). Only a Shotgun takes a spot within
## SHOTGUN_CLOSE of him. A Marksman Rifle searches out to PERCH_RADIUS and
## scores a spot by its clear line to him ([method _score]). The last Guard
## takes no spot nearer him than the one it holds.
func find(want: int, relaxed := false, max_far := INF, only_room := -1, around := Vector3.INF) -> Dictionary:
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
	if only_room >= 0:
		rooms = [only_room]
	var no_nearer := _flat(spot if spot != Vector3.INF else here, last) if last_guard else -INF
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
			if far > max_far or far < no_nearer - 0.01:
				continue
			if around != Vector3.INF and _flat(at, around) > FLANK_SPOT_REACH:
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
		if fair_walk(entry.at, radius * WALK_REACH, not relaxed and only_room < 0):
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
## ends do, less NEARER_SLACK, and crosses no more than the Sandbox's `open_floor` metres
## of floor in his view (a sample every WALK_SAMPLE metres whose torso his
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
				if seen > crew.sandbox.open_floor:
					return false
		cursor = point
	return true


## Claims [param found] and sets off for it; [param ambush]: to wait there
## in ambush (Shotgun) rather than get down; [param flank]: the spot inside
## the Door it flanked through. Leaving a spot it held for another makes it
## the one mover until it gets down there.
func _claim(found: Dictionary, ambush := false, flank := false) -> void:
	if found.tile != tile:
		held = 0.0
		if tile != Vector2i.MAX and mode in [Mode.DOWN, Mode.OUT, Mode.SHOOT, Mode.BACK, Mode.AMBUSH]:
			between = true
	flank_end = flank
	if flank:
		between = false
	_move_wait = -1.0
	_want_shift = false
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
	# Guards come first: a Worker hiding on this tile moves on ([CrewHiding]).
	CrewHiding.guard_claimed(crew, tile)
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


## The other living Guards fighting him (FIGHT or COVER).
func _partners_fighting() -> Array[Crew3D]:
	var out: Array[Crew3D] = []
	for other in _guards():
		if other.target == crew.target and other.cover != null and other.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
			out.append(other)
	return out


## Another Guard fighting him is between cover tiles now (a flanker on its
## way to its spot does not count): one mover at a time.
func _someone_moving() -> bool:
	for other in _partners_fighting():
		if other.cover.between and not other.cover.flank_end:
			return true
	return false


## Up and firing at him, true or a deliberate miss: in a peek or the open
## fight, its last shot within COVER_FIRE. It covers a partner changing
## cover.
func covering() -> bool:
	return mode in [Mode.SHOOT, Mode.OPEN] and crew.shot_age() <= COVER_FIRE and not crew.is_reloading()


## Able to give covering fire: fighting in the open, or holding (or on its
## way to) a spot with a way to shoot, not holding its fire, and with him in
## its sight now, or within COVER_WAIT while it is down behind its own cover
## or walking to its spot, or his cover to fire on. Not one hiding with no
## shot, a Shotgun waiting in ambush out of his sight, nor one up that has
## lost him. A reload changes nothing here: a partner reloading down behind
## its cover will be up again like one in its time down, and the wait is
## capped at COVER_WAIT ([method covering] does say no while it reloads).
func can_cover() -> bool:
	if covering():
		return true
	if mode in [Mode.NONE, Mode.AMBUSH] or holds_fire():
		return false
	if mode != Mode.OPEN and not has_peek:
		return false
	if crew._can_see:
		return true
	if (behind_own_cover() or mode == Mode.MOVE) and crew._seen_ago <= COVER_WAIT:
		return true
	var team := CrewTeam.of(crew.target)
	return team != null and team.suppresses(crew)


## Whether it may change cover now. One Guard fighting him moves at a time;
## and it waits for a partner up and firing (covering fire), up to
## COVER_WAIT, unless no partner was able to fire when it started waiting.
## Call it every tick it wants to move: a tick without asking ends the wait.
func _may_leave() -> bool:
	_asked = true
	if _move_wait < 0.0:
		_move_wait = 0.0
		_wait_for_cover = _partners_fighting().any(func(other: Crew3D) -> bool: return other.cover.can_cover())
	var may := not _someone_moving() and (not _wait_for_cover or _move_wait >= COVER_WAIT \
			or _partners_fighting().any(func(other: Crew3D) -> bool: return other.cover.covering()))
	_held_back = _held_back or not may
	return may


## Seconds it has waited to change cover so far (negative when it is not
## waiting): for checks.
func move_wait() -> float:
	return _move_wait


## Who fights him beside it: another living Guard after him in his Room or
## one joined to it, or flanking. With none, a Guard that has had one is the
## last Guard.
func _count_partners() -> void:
	var layout := crew.layout
	var near: Array[int] = []
	if layout != null:
		near = CrewCombat.rooms_near(layout, CrewNoise.rooms_at(layout, crew._last_seen))
	for other in _guards():
		if other.target != crew.target or not other.state in [Crew3D.State.HUNT, Crew3D.State.FIGHT, Crew3D.State.COVER]:
			continue
		if other.flanking or near.is_empty() \
				or CrewNoise.rooms_at(layout, other.global_position).any(func(room: int) -> bool: return room in near):
			had_partner = true
			last_guard = false
			_fell_back = false
			return
	last_guard = had_partner


## No cover in reach: fall back out of his sight, or fight where it stands.
func _no_cover() -> void:
	if _pick(0, true):
		return
	_unclaim()
	_stand()
	crew._path.clear()
	between = false
	flank_end = false
	think = LOOK_OPEN
	_set_mode(Mode.OPEN)
	_start_burst()
	timer = crew.gunnery.settle * _jitter() if crew.gunnery != null else 0.0


## Leaves its spot for another: the best ([param want] 0) or one further
## (-1); with none, no cover ([method _no_cover]).
func _leave(want: int) -> void:
	if not _pick(want):
		_no_cover()


# --- holding a spot -------------------------------------------------------------

func _get_down(time: float) -> void:
	timer = time
	downs += 1
	waited = 0.0
	_racked = false
	_peek_spent = false
	between = false
	flank_end = false
	_crouch()
	var look := crew._last_seen - crew.global_position
	look.y = 0.0
	if look.length_squared() > 0.01:
		crew._aim = look.normalized()
	_set_mode(Mode.DOWN)
	if crew.magazine != null and crew.magazine.is_dry():
		# Dry: it reloads as it gets down ([method _reload_down]).
		crew.magazine.start()


## What makes it leave, or change what it is doing, while down. True when
## it did. Every change of spot waits its turn ([method _may_leave]).
func _watch(delta: float) -> bool:
	_asked = false
	_held_back = false
	var acted := _watch_for(delta)
	if not _asked:
		_move_wait = -1.0
	elif _held_back and not acted and not has_peek:
		# Hiding with no shot, waiting its turn to move: it cannot peek, so
		# this counts with its habit's waits.
		waited += delta
	return acted


func _watch_for(delta: float) -> bool:
	var target := crew.target
	var eye: Vector3 = target.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
	var far := _flat(crew.global_position, target.global_position)
	# Flanked: he can see it where it hides.
	if far <= crew.vision_range and _alive(target) \
			and not crew._blocked(crew.global_position + Vector3.UP * Crew3D.COVER_HEIGHT, eye):
		exposed += delta
	else:
		exposed = 0.0
	if exposed > crew.sandbox.flank_reaction:
		if not _may_leave():
			# With a shot it peeks as usual meanwhile.
			return false
		exposed = 0.0
		_leave(0)
		return true
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE:
		# Him close: back to a further perch, or the hip. It takes the place
		# of "too close".
		if _marksman_close():
			return true
	elif crew._can_see and far < crew.sandbox.too_close and gun != CrewHabit.Gun.SHOTGUN:
		# Too close; the Shotgun stays.
		if not _may_leave():
			return false
		_leave(-1)
		return true
	if not has_peek and crew._can_see:
		# Hiding where he could not see it standing, and now he can: it no
		# longer hides, and it has no shot from here.
		if not _may_leave():
			return false
		_leave(0)
		return true
	if not has_peek and think <= 0.0 and _may_leave():
		# Hiding with no shot: look again for real cover.
		think = LOOK_HIDING
		if _pick(0):
			return true
	if blind >= BLIND_PEEKS:
		# A Marksman Rifle with him hidden holds its perch.
		if gun == CrewHabit.Gun.MARKSMAN_RIFLE and crew._seen_ago >= WAIT_UP:
			blind = 0
		elif _may_leave():
			blind = 0
			if _pick(0):
				return true
	if last_guard:
		return _fall_back()
	return _shift()


## The last Guard fighting him: once, a spot at least a metre further from
## him, then it holds (no shift, no moving up). True when it set off.
func _fall_back() -> bool:
	if _fell_back or not _may_leave() or think > 0.0:
		return false
	think = LOOK_SHIFT
	if _pick(-1):
		_fell_back = true
		return true
	return false


## Moving one spot by its habit: out of its band after holding it its
## Gunnery's hold before shifting (a Shotgun into its band, else to its
## ambush), or nearer where he was after UNSEEN_ADVANCE unseen, or while
## the others fire on the prop he hid behind (one Guard). A Marksman Rifle
## never moves up. It looks every LOOK_SHIFT; having found somewhere, it
## waits its turn ([method _may_leave]) and goes. True when it set off.
func _shift() -> bool:
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE or crew.gunnery == null:
		return false
	if not _want_shift:
		if think > 0.0:
			return false
		think = LOOK_SHIFT
		if _shift_target().is_empty():
			return false
		_want_shift = true
	if not _may_leave():
		return false
	_want_shift = false
	# Its turn: where it goes now, looked for afresh.
	var found := _shift_target()
	if found.is_empty():
		_move_wait = -1.0
		return false
	_claim(found, found.get("ambush", false))
	if found.get("up", false):
		CrewTeam.of(crew.target).moved_up(crew)
	return true


## Where its habit would shift it now, or empty.
func _shift_target() -> Dictionary:
	var gunnery := crew.gunnery
	var hold := gunnery.hold_before_shifting
	var cover_far := _flat(spot, crew._last_seen)
	var out_of_band := hold >= 0.0 and held > hold
	if gun == CrewHabit.Gun.SHOTGUN and out_of_band and cover_far > gunnery.range_far:
		var into := find(0, false, gunnery.range_far)
		if not into.is_empty():
			return into
		var lie := ambush_spot()
		if not lie.is_empty():
			lie["ambush"] = true
			return lie
	var team := CrewTeam.of(crew.target)
	var up := team != null and team.may_move_up(crew)
	var hidden := crew._seen_ago > UNSEEN_ADVANCE or up
	var want := 0
	if hidden:
		want = 1
	elif out_of_band:
		if cover_far > gunnery.range_far:
			want = 1
		elif cover_far < gunnery.range_near:
			want = -1
	if want != 0:
		var found := find(want)
		if not found.is_empty() and (hidden or found.score > score * (1.0 + BETTER)):
			found["up"] = up and crew._seen_ago <= UNSEEN_ADVANCE
			return found
	return {}


# --- peeking and firing ---------------------------------------------------------

func _start_peek() -> void:
	if not has_peek:
		timer = LOOK_HIDING
		return
	if not crew._can_see and crew._seen_ago > UNSEEN_STAY_DOWN and not _suppresses() and crew._rng.randf() < 0.5:
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


## [param now]: no settle (a Shotgun breaking its reload off), only what
## its rack needs.
func _begin_shooting(now := false) -> void:
	bursts = crew.gunnery.bursts_per_peek if crew.gunnery != null else 1
	_start_burst()
	wait = 0.0
	_peek_spent = false
	var settle := crew.gunnery.settle * _jitter() if crew.gunnery != null else 0.0
	if now:
		settle = 0.0
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
	var magazine := crew.magazine
	if magazine != null and not magazine.can_fire():
		# Dry: down behind its cover to reload there.
		blind = 0
		_end_line()
		if spot == Vector3.INF:
			magazine.start()
		else:
			_duck()
		return
	if timer > 0.0:
		return  # settling, or between bursts
	if uses_line() and _flat(crew.global_position, crew._last_seen) < CrewHabit.PERCH_CLOSE:
		# Him close: no line; down, to fall back or take to the hip.
		_duck()
		return
	var edge := Vector3.INF
	if not crew._can_see or crew._muzzle_blocked() or holds_fire():
		# No shot at him: at the prop he hid behind, if the team fires on it.
		edge = _suppress_at()
		if edge == Vector3.INF:
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
	_fire_when_ready(edge)


## Fires its next shot once the gun is ready, never starting a burst in step
## with another crew member's: at him, or as a deliberate miss at
## [param edge] (the edge of the prop he hid behind) when that is set.
func _fire_when_ready(edge := Vector3.INF) -> void:
	if crew._shot_timer > 0.0 or (crew.magazine != null and not crew.magazine.can_fire()):
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
	var at: Vector3 = crew.target.global_position + Vector3.UP * Crew3D.TORSO_HEIGHT if edge == Vector3.INF else edge
	crew._aim = (at - (crew.global_position + Vector3.UP * Crew3D.MUZZLE_HEIGHT)).normalized()
	if edge != Vector3.INF:
		crew.miss_at = edge
		_edge_side = -_edge_side
	crew._fire()


## Whether it fires on the prop he broke sight behind now (a Pistol or an
## Assault Rifle, while the team does: [CrewTeam]).
func _suppresses() -> bool:
	var team := CrewTeam.of(crew.target)
	return team != null and team.suppresses(crew)


## Where its next shot at the prop he hid behind goes, or INF with none to
## fire (not suppressing, or neither edge in its sight).
func _suppress_at() -> Vector3:
	var team := CrewTeam.of(crew.target)
	return team.suppress_point(crew, _edge_side) if team != null else Vector3.INF


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
	if _reload_in_open(delta):
		return
	if gun == CrewHabit.Gun.MARKSMAN_RIFLE and not hip and _marksman_close():
		return
	if think <= 0.0:
		think = LOOK_OPEN
		if _pick(0):
			return
		var gunnery := crew.gunnery
		if gun == CrewHabit.Gun.SHOTGUN and gunnery != null and gunnery.hold_before_shifting >= 0.0 \
				and clock > gunnery.hold_before_shifting and not last_guard \
				and _flat(crew.global_position, crew._last_seen) > gunnery.range_far:
			# Out of its band with no cover: to its ambush, if it has one.
			var lie := ambush_spot()
			if not lie.is_empty():
				_claim(lie, true)
				return
		if crew._path.is_empty() and (not crew._can_see or crew._muzzle_blocked()) and not _suppresses():
			# (Firing on his cover, it stays and fires at its edges.)
			var to := crew._find_firing_position()
			if to != Vector3.INF:
				crew._repath_to(to)
	if not crew._path.is_empty() and _stalling(delta) > MOVE_GIVE_UP:
		crew._path.clear()
	if timer > 0.0:
		return
	var edge := Vector3.INF
	if not crew._can_see or crew._muzzle_blocked() or holds_fire():
		edge = _suppress_at()
		if edge == Vector3.INF:
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
	_fire_when_ready(edge)


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
		timer = maxf(timer, minf(timer + NEAR_MISS_HOLD, _longest_time_down()))
		_racked = false
	elif mode == Mode.SHOOT and spot != Vector3.INF:
		_duck()
		timer += NEAR_MISS_HOLD
	if crouched and crew.pose != null:
		crew.pose.flinch()  # ducked lower for a moment
	return true


# --- reloading ----------------------------------------------------------------------

## Down behind its cover: dry, it reloads there; with him unseen
## TOP_UP_UNSEEN and a part-used magazine, it tops up. While the reload runs
## it stays down and nothing makes it leave or peek (being shot, flanked or
## closed on), except a Shotgun with a shell in and him in its sight within
## BREAK_OFF, which breaks off and fires. True while it reloads.
func _reload_down() -> bool:
	var magazine := crew.magazine
	if magazine == null:
		return false
	if not magazine.reloading:
		if magazine.is_dry() or (not magazine.is_full() and crew._seen_ago >= TOP_UP_UNSEEN):
			magazine.start()
		if not magazine.reloading:
			return false
	# No wait to change cover runs on through a reload.
	_move_wait = -1.0
	if _breaks_off():
		magazine.break_off()
		_up_now()
	return true


## Dry in the open fight: behind cover first where the cover search finds
## any, else it reloads where it stands, backing away from him BACK_AWAY.
## True while it reloads (or set off for cover), so it does nothing else.
func _reload_in_open(delta: float) -> bool:
	var magazine := crew.magazine
	if magazine == null:
		return false
	if not magazine.reloading and magazine.is_dry():
		if _pick(0) or _pick(0, true):
			return true
		magazine.start()
		_open_reload = true
		_back_away()
	if magazine.reloading:
		if _breaks_off():
			magazine.break_off()
		else:
			if not crew._path.is_empty() and _stalling(delta) > MOVE_GIVE_UP:
				crew._path.clear()
			return true
	if _open_reload:
		# The reload is done: a fresh burst after a settle.
		_open_reload = false
		_end_back_away()
		_start_burst()
		# (Broken off with him close, a Shotgun fires at once.)
		timer = 0.0 if not magazine.is_full() else crew.gunnery.settle * _jitter()
	return false


## A Shotgun loading shell by shell with a shell in and him in its sight
## within BREAK_OFF.
func _breaks_off() -> bool:
	var target := crew.target
	return crew.magazine.can_break_off() and crew._can_see and target != null and is_instance_valid(target) \
			and _flat(crew.global_position, target.global_position) <= BREAK_OFF


## Up at once from its reload to fire (a Shotgun breaking off): over low
## cover it racks if its last rack is stale and shoots as soon as the rack
## allows, with no settle; from full cover it steps out as usual.
func _up_now() -> void:
	timer = 0.0
	if not has_peek:
		return  # nowhere to fire from: the cover rules carry on
	if not (low or step == Vector3.INF):
		_start_peek()
		return
	if CrewHabit.racks(crew.weapon) and crew.rack_age() > CrewHabit.RACK_EARLIEST:
		crew.rack()
	_racked = true
	_stand()
	_begin_shooting(true)


## Reloading in the open: one step BACK_AWAY straight away from him (or
## angled off where a prop stands behind it), at BACK_AWAY_SPEED, facing
## him.
func _back_away() -> void:
	var away := crew.global_position - crew._last_seen
	away.y = 0.0
	if away.length_squared() < 0.01 or crew.layout == null:
		return
	away = away.normalized()
	var astar := CrewPaths.grid(crew.layout)
	for degrees: float in [0.0, 35.0, -35.0, 70.0, -70.0]:
		var to := crew.global_position + away.rotated(Vector3.UP, deg_to_rad(degrees)) * BACK_AWAY
		if CrewPaths.clear(astar, crew.global_position, to):
			crew._path.assign([to])
			crew._speed_scale = BACK_AWAY_SPEED
			_backing = true
			_progress_at = Vector3.INF
			_stalled = 0.0
			return


func _end_back_away() -> void:
	if not _backing:
		return
	_backing = false
	crew._speed_scale = 1.0
	crew._path.clear()


# --- down and up ------------------------------------------------------------------

## Down behind its cover: a squat or one knee, the next from the bag, its
## capsule cut to that stance's top. The pose shows it ([CrewPose]).
func _crouch() -> void:
	if crouched:
		return
	crouched = true
	stance = next_stance()
	if _capsule != null:
		var top: float = CrewPose.BODY_TOP[stance]
		_capsule.height = maxf(top, _capsule.radius * 2.0)
		_shape.position.y = _capsule.height / 2.0


func _stand() -> void:
	if not crouched:
		return
	crouched = false
	stance = CrewPose.Stance.STAND
	if _capsule != null:
		_capsule.height = _stand_height
		_shape.position.y = _stand_y


## The stance it gets down in next: drawn from a bag of SQUATS squats and
## KNEES knees, shuffled, filled again when empty.
func next_stance() -> CrewPose.Stance:
	if _stances.is_empty():
		for i in SQUATS:
			_stances.append(CrewPose.Stance.SQUAT)
		for i in KNEES:
			_stances.append(CrewPose.Stance.KNEE)
		for i in range(_stances.size() - 1, 0, -1):
			var j := _stance_rng.randi_range(0, i)
			var swap := _stances[i]
			_stances[i] = _stances[j]
			_stances[j] = swap
	return _stances.pop_back()


## Stepping out from full cover to its firing tile, up there, or stepping
## back: its feet step ([CrewPose]) and it moves at [constant
## CrewPose.STEP_SPEED] of its speed.
func stepping() -> bool:
	return mode in [Mode.OUT, Mode.SHOOT, Mode.BACK] and step != Vector3.INF and not low and spot != Vector3.INF


## The longest one stretch down can last with him in sight: its Gunnery's
## longest time down, varied up, and a near miss's hold on top; or its
## longest reload (from dry, the Profile's time times the reload factor),
## which it sits out down there whatever happens and which a near miss does
## not lengthen, if that is longer.
func longest_down() -> float:
	var reload := crew.magazine.longest() if crew.magazine != null else 0.0
	return maxf(_longest_time_down(), reload)


func _longest_time_down() -> float:
	return (crew.gunnery.time_down_high if crew.gunnery != null else 1.0) * (1.0 + JITTER) + NEAR_MISS_HOLD


func _set_mode(next: Mode) -> void:
	if next != Mode.OPEN:
		# (A walk it sets off on keeps its path; only the slow step ends.)
		_open_reload = false
		if _backing:
			_backing = false
			crew._speed_scale = 1.0
	if not next in [Mode.OUT, Mode.SHOOT]:
		# The peek is over: its sight line goes, and its true-aim place.
		_end_line()
		_give_up_place()
	if next in [Mode.DOWN, Mode.AMBUSH, Mode.OPEN]:
		# Got there (or has no spot to go to): no longer moving.
		between = false
		flank_end = false
	if next in [Mode.OUT, Mode.BACK]:
		# A step, not a run, so its feet keep up.
		crew._speed_scale = CrewPose.STEP_SPEED
	elif mode in [Mode.OUT, Mode.BACK]:
		crew._speed_scale = 1.0
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

## Where a Shotgun waits in ambush: beside a doorway of his Room, within
## AMBUSH_REACH of the opening, where he cannot see it standing, by a fair
## walk; the tile nearest the opening first. Where his Room has a second
## Door and another Guard fights him, the Door furthest from that Guard (the
## one a flank goes in by: [method CrewCombat.far_door]); else, or with no
## such tile there, the Door nearest to it. Empty with none (his Room has
## no Door, or nowhere hidden near one).
func ambush_spot() -> Dictionary:
	var layout := crew.layout
	if layout == null:
		return {}
	var last := crew._last_seen
	var his := CrewNoise.rooms_at(layout, last)
	var nearest: DoorData = null
	var door_far := INF
	var doors := 0
	for d in layout.doors:
		if d.locked or not (d.room_a in his or d.room_b in his):
			continue
		doors += 1
		var far := _flat(crew.global_position, ShipBuilder3D.door_center_world(d))
		if far < door_far:
			door_far = far
			nearest = d
	if nearest == null:
		return {}
	var tries: Array[DoorData] = []
	var pinner: Crew3D = null
	for other in _partners_fighting():
		if pinner == null or _flat(other.global_position, last) < _flat(pinner.global_position, last):
			pinner = other
	if doors > 1 and pinner != null and his.size() == 1:
		var second := CrewCombat.far_door(layout, his[0], pinner.global_position)
		if second != null:
			tries.append(second)
	if not nearest in tries:
		tries.append(nearest)
	for door in tries:
		var found := _ambush_at(door)
		if not found.is_empty():
			return found
	return {}


## The ambush tile beside [param door], or empty.
func _ambush_at(door: DoorData) -> Dictionary:
	var layout := crew.layout
	var last := crew._last_seen
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
		if _flat(crew.global_position, crew.target.global_position) <= CrewHabit.SHOTGUN_HOLD_FIRE \
				and not crew._muzzle_blocked():
			ambushing = false
			low = true
			has_peek = true
			_begin_shooting()
		elif _may_leave():
			ambushing = false
			_leave(0)
		return
	var gunnery := crew.gunnery
	if gunnery == null or last_guard:
		return
	if not _want_shift:
		if think > 0.0:
			return
		think = LOOK_SHIFT
		if find(0, false, gunnery.range_far).is_empty():
			return
		_want_shift = true
	if not _may_leave():
		return
	_want_shift = false
	var into := find(0, false, gunnery.range_far)
	if into.is_empty():
		_move_wait = -1.0
		return
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
	if crew.magazine != null and not crew.magazine.can_fire():
		return false  # reloading, or about to
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
	var torso: Vector3 = crew.target.global_position + Vector3.UP * Crew3D.TORSO_HEIGHT
	var from := crew.aim_muzzle(crew.global_position, torso)
	if line_left > CrewHabit.SIGHT_LOCK or _line_at == Vector3.INF:
		_line_at = CrewFire.lead_point(crew, from)
	elif _locked == Vector3.INF:
		_locked = _line_at
	var at := _locked if _locked != Vector3.INF else _line_at
	var along := (at - from).normalized()
	crew._aim = along
	# From the rifle's own muzzle, wherever its gun has got to.
	_sight_line().show_between(crew.gun.muzzle_point() if crew.gun != null else from, at)
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
	# From a spot it holds, it waits its turn to leave ([method _may_leave]).
	if mode != Mode.OPEN and spot != Vector3.INF and not _may_leave():
		return false
	if hip and think > 0.0:
		return false
	think = LOOK_SHIFT
	var further := find(-1)
	if not further.is_empty():
		hip = false
		_claim(further)
		return true
	hip = true
	return false
