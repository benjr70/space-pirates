class_name CrewFire
extends RefCounted
## Fair fire: where a Guard's shot is aimed before its spread is applied.
## Every Guard in a fight fires, but at most a few aim true at once (the
## Sandbox's `true_aim_count`, 2); the rest aim at miss points 0.4 to 0.8 m
## off his body. True aim passes on by a timer. A true-aimed shot leads him
## by its Gunnery's fraction of the true intercept, and the first burst of a
## sighting walks in from one side. See "Fair fire" in `CREW_AI.md`.
##
## One of these per Pirate ([method of]), shared by every Guard fighting
## him, so the limit holds across them all. It decides who aims true once
## per physics frame ([method update]), at the start of the frame, before
## any Guard has moved or fired in it: the first Guard to tick or ask does
## the work, and nothing changes who aims true until the next frame.

## Rounds of a walk-in before the last are aimed at least this fraction of
## the walk-in distance to the side: from the whole distance on the first
## round down to this on the last but one, then on him.
const WALK_IN_NEAREST := 0.4
## A miss point is this far from his body centre, metres, drawn MISS_MARGIN
## inside the band.
const MISS_NEAR := 0.4
const MISS_FAR := 0.8
const MISS_MARGIN := 0.02
## In the open a miss passes beside his head: this far above his body
## centre, and at least this far from it in all.
const HEAD_RISE := 0.5
const HEAD_MISS_NEAR := 0.55
## The height above his body centre a miss at the edge of his cover is aimed
## at, before it is drawn into the band.
const EDGE_RISE := 0.3
## He is behind cover from a Guard when the tile this far from him toward
## that Guard is a prop or a wall on the walking grid.
const COVER_PROBE := 0.8
## His peek side is read from where he stands off his cover's centre, when
## he is at least this far to one side of it.
const PEEK_OFF := 0.15
## The true-aim handover time is halved with him this close to the Guard
## holding it.
const CLOSE := 3.0
## Above this speed he is moving, for which side a miss passes him.
const MOVING := 0.5
const META := &"crew_fire"

## The Pirate this fight is against.
var target: Node3D
## The Guards aiming true now, in the order they took it.
var holders: Array = []
## {Guard: seconds it has held true aim this time}.
var _held_for := {}
## {Guard: fight clock when it last gave true aim up}.
var _last_held := {}
## {cover tile: where he stood, clearly to one side of it, when last seen
## there}: the side of that cover he last peeked from.
var _peek_at := {}
## Seconds of this fight, counted in physics frames.
var clock := 0.0
var _frame := -1


## The fair-fire record for [param pirate], made on first asking; null with
## no Pirate.
static func of(pirate: Node3D) -> CrewFire:
	if pirate == null or not is_instance_valid(pirate):
		return null
	if pirate.has_meta(META):
		return pirate.get_meta(META)
	var fire := CrewFire.new()
	fire.target = pirate
	pirate.set_meta(META, fire)
	return fire


## Whether [param crew] aims true this frame.
func aims_true(crew: Crew3D) -> bool:
	update()
	return crew in holders


## A Guard gives true aim up at once (ticket "Crew magazines and reloads"
## calls this as a reload starts; [method Crew3D.can_aim_true] then keeps
## it from taking it back until the reload is done). Another takes the place
## on the next frame.
func give_up(crew: Crew3D) -> void:
	if crew in holders:
		_drop(crew)


## Who aims true this physics frame. Runs once a frame; later calls in the
## same frame do nothing.
func update() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		return
	var step := 1.0 / Engine.physics_ticks_per_second
	var dt := 0.0 if _frame < 0 else (frame - _frame) * step
	_frame = frame
	clock += dt
	var members := fighting()
	for held: Variant in holders.duplicate():
		if not is_instance_valid(held) or not held in members:
			_drop(held)
	for held in holders:
		_held_for[held] = _held_for.get(held, 0.0) + dt
	var waiting: Array[Crew3D] = []
	var clear: Array[Crew3D] = []
	for crew in members:
		if crew.can_aim_true():
			clear.append(crew)
			if not crew in holders:
				waiting.append(crew)
	waiting.sort_custom(_sooner)
	var places := places_count(members)
	while holders.size() > places:
		_drop(holders[-1])
	# A holder with no clear line hands over at once to one with.
	for held in holders.duplicate():
		if waiting.is_empty():
			break
		if not held in clear:
			_drop(held)
			_take(waiting.pop_front())
	while holders.size() < places and not waiting.is_empty():
		_take(waiting.pop_front())
	for held in holders.duplicate():
		if waiting.is_empty():
			break
		if _held_for.get(held, 0.0) >= handover_time(held):
			_drop(held)
			_take(waiting.pop_front())
	if _last_held.size() > 64:
		for key in _last_held.keys():
			if not is_instance_valid(key):
				_last_held.erase(key)


## The living Guards fighting him (FIGHT or COVER).
func fighting() -> Array[Crew3D]:
	var out: Array[Crew3D] = []
	if not is_instance_valid(target) or not target.is_inside_tree():
		return out
	for node in target.get_tree().get_nodes_in_group(&"crew"):
		var crew := node as Crew3D
		if crew != null and crew.target == target and not crew.is_worker() and crew.is_alive() \
				and crew.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
			out.append(crew)
	return out


## How many may aim true at once: the Sandbox's count, never under one.
func places_count(members: Array[Crew3D]) -> int:
	var sandbox := _sandbox(members)
	return maxi(sandbox.true_aim_count if sandbox != null else 2, 1)


## Seconds [param crew] holds true aim before handing it on: the Sandbox's
## handover time, doubled while he is crouched or behind cover from it,
## halved with him within CLOSE of it.
func handover_time(crew: Crew3D) -> float:
	var sandbox := crew.sandbox
	var time := sandbox.true_aim_handover if sandbox != null else 0.8
	if (target.has_method("is_crouched") and target.is_crouched()) or behind_cover(crew) != Vector2i.MAX:
		time *= 2.0
	if _flat(crew.global_position, target.global_position) < CLOSE:
		time *= 0.5
	return time


## Of two Guards waiting for true aim, whether [param a] goes first: the one
## that held it least recently (never first), then the one nearer him.
func _sooner(a: Crew3D, b: Crew3D) -> bool:
	var la: float = _last_held.get(a, -INF)
	var lb: float = _last_held.get(b, -INF)
	if la != lb:
		return la < lb
	return _flat(a.global_position, target.global_position) < _flat(b.global_position, target.global_position)


func _take(crew: Crew3D) -> void:
	holders.append(crew)
	_held_for[crew] = 0.0


## Takes true aim from [param crew], which may have been freed.
func _drop(crew: Variant) -> void:
	holders.erase(crew)
	_held_for.erase(crew)
	if is_instance_valid(crew):
		_last_held[crew] = clock


func _sandbox(members: Array[Crew3D]) -> Sandbox:
	if not members.is_empty() and members[0].sandbox != null:
		return members[0].sandbox
	return load(Sandbox.PATH)


# --- where a shot is aimed --------------------------------------------------------

## His body centre: where a true-aimed shot at a still Pirate goes.
static func body_centre(pirate: Node3D) -> Vector3:
	return pirate.global_position + Vector3.UP * Crew3D.TORSO_HEIGHT


## His flat velocity.
static func velocity_of(pirate: Node3D) -> Vector3:
	var v: Variant = pirate.get("velocity")
	if not v is Vector3:
		return Vector3.ZERO
	return Vector3(v.x, 0.0, v.z)


## Where a bolt at [param speed] from [param from] meets a body now at
## [param at] moving at [param velocity]: the true intercept. [param at]
## itself when the bolt is no faster than he is.
static func intercept(from: Vector3, at: Vector3, velocity: Vector3, speed: float) -> Vector3:
	var r := at - from
	var a := velocity.dot(velocity) - speed * speed
	if a >= 0.0:
		return at
	var b := 2.0 * r.dot(velocity)
	var c := r.dot(r)
	var t := (-b - sqrt(b * b - 4.0 * a * c)) / (2.0 * a)
	return at + velocity * maxf(t, 0.0)


## The true aim point of [param crew] at its target from [param from]: his
## body centre led by its Gunnery's fraction of the true intercept, half
## that during a Slide or Clamber.
static func lead_point(crew: Crew3D, from: Vector3) -> Vector3:
	var pirate := crew.target
	var centre := body_centre(pirate)
	var lead := crew.gunnery.lead if crew.gunnery != null else 0.0
	if pirate.has_method("in_slide_or_clamber") and pirate.in_slide_or_clamber():
		lead *= 0.5
	if lead <= 0.0 or crew.weapon == null:
		return centre
	var meet := intercept(from, centre, velocity_of(pirate), crew.weapon.projectile_speed)
	return centre + (meet - centre) * lead


## The flat direction at right angles to the line from [param from] to
## [param to], to its right.
static func side_axis(from: Vector3, to: Vector3) -> Vector3:
	var along := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if along.length_squared() < 0.0001:
		return Vector3.RIGHT
	return along.normalized().cross(Vector3.UP).normalized()


## How far to the side round [param index] (from 0) of an [param rounds]-round
## walk-in is aimed, metres, over a walk-in [param distance]: the whole
## distance on the first round, falling to WALK_IN_NEAREST of it on the last
## but one, none on the last. A one-round burst has nothing to walk.
static func walk_in_offset(index: int, rounds: int, distance: float) -> float:
	if index >= rounds - 1:
		return 0.0
	if rounds <= 2:
		return distance
	return distance * lerpf(1.0, WALK_IN_NEAREST, float(index) / (rounds - 2))


## The cover tile he is behind from [param crew]: the tile COVER_PROBE from
## him toward it, when that is a prop or a wall on the walking grid;
## Vector2i.MAX in the open (or with no layout).
func behind_cover(crew: Crew3D) -> Vector2i:
	if crew.layout == null or not is_instance_valid(target):
		return Vector2i.MAX
	var toward := crew.global_position - target.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return Vector2i.MAX
	var tile := ShipBuilder3D.world_to_tile(target.global_position + toward.normalized() * COVER_PROBE)
	if tile == ShipBuilder3D.world_to_tile(target.global_position):
		return Vector2i.MAX
	var astar := CrewPaths.grid(crew.layout)
	if astar.is_in_boundsv(tile) and not astar.is_point_solid(tile):
		return Vector2i.MAX
	return tile


## Where a Guard not aiming true aims, 0.4 to 0.8 m off his body centre: at
## the edge of the cover he is behind from it, on the side he last peeked
## from, or in the open beside his head on the side away from his movement.
## [param kind] gets "cover" or "open".
func miss_point(crew: Crew3D, rng: RandomNumberGenerator, kind: Array = []) -> Vector3:
	var centre := body_centre(target)
	var side := side_axis(crew.global_position, target.global_position)
	var tile := behind_cover(crew)
	if tile != Vector2i.MAX:
		kind.assign(["cover"])
		var middle := ShipBuilder3D.tile_to_world(tile)
		var off := (target.global_position - middle).dot(side)
		var toward := 0.0
		if absf(off) >= PEEK_OFF:
			# Stood to one side of it: that is the side he peeks from.
			_peek_at[tile] = target.global_position
			toward = signf(off)
		elif _peek_at.has(tile):
			toward = signf((_peek_at[tile] - middle).dot(side))
		if toward == 0.0:
			toward = 1.0 if rng.randf() < 0.5 else -1.0
		var edge := middle + side * toward * ShipBuilder3D.TILE * 0.5
		edge.y = centre.y + EDGE_RISE
		return _into_band(centre, edge - centre, side * toward, rng)
	kind.assign(["open"])
	var moving := velocity_of(target)
	var away := 0.0
	if moving.length() > MOVING:
		away = -signf(moving.dot(side))
	if away == 0.0:
		away = 1.0 if rng.randf() < 0.5 else -1.0
	var far := rng.randf_range(HEAD_MISS_NEAR, MISS_FAR - MISS_MARGIN)
	var across := sqrt(far * far - HEAD_RISE * HEAD_RISE)
	return centre + Vector3.UP * HEAD_RISE + side * away * across


## [param offset] from [param centre], drawn into the miss band: kept as it
## is inside it, else shortened or stretched to a distance drawn inside it.
static func _into_band(centre: Vector3, offset: Vector3, fallback: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var near := MISS_NEAR + MISS_MARGIN
	var far := MISS_FAR - MISS_MARGIN
	var length := offset.length()
	if length < 0.01:
		offset = fallback
		length = 1.0
	if length < near or length > far:
		offset = offset / length * rng.randf_range(near, far)
	return centre + offset


## A direction within [param degrees] of [param direction], drawn evenly
## over the cone's disc: a real cone, up and down as well as sideways.
static func scatter(direction: Vector3, degrees: float, rng: RandomNumberGenerator) -> Vector3:
	if degrees <= 0.0:
		return direction
	var right := direction.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := right.cross(direction).normalized()
	var offset := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * tan(deg_to_rad(minf(degrees, 80.0)))
	return (direction + right * offset.x + up * offset.y).normalized()


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
