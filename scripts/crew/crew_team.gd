class_name CrewTeam
extends RefCounted
## Guards working together against one Pirate: which Guard flanks, chosen by
## the gun it carries, and suppression: when he breaks sight behind a prop
## in a fight, Pistol and Assault Rifle Guards that can see the prop fire at
## its edges for the Sandbox's suppression time (4 s), deliberate misses
## only, while one Guard may move up; then they hold. See "Guards together"
## in `CREW_AI.md`.
##
## One of these per Pirate ([method of]), shared by every Guard fighting
## him. It settles once per physics frame ([method update]), at the start of
## the frame, before any Guard has moved or fired in it, as [CrewFire] does.
## The rest of working together (covering fire, one mover at a time, the
## last Guard) is each Guard's [CrewCover] asking about the others.

const META := &"crew_team"
## Seconds between looks for a flanker.
const FLANK_LOOK := 1.0
## Who flanks first, by gun; a gun not listed (the Marksman Rifle) never.
const FLANK_ORDER := {
	CrewHabit.Gun.SHOTGUN: 0,
	CrewHabit.Gun.PISTOL: 1,
	CrewHabit.Gun.ASSAULT_RIFLE: 2,
}
## He broke sight behind a prop when every Guard fighting him that had a
## shot at him (in its sight with a clear muzzle line) lost it in one frame,
## one of them standing still (moved under STILL metres, in the same mode,
## so it did not duck or step away), and going from him toward that Guard a
## prop's tile comes within PROP_PROBE metres of him before any wall does;
## tested every PROBE_STEP metres. (A Guard's eyes see over a crate he
## crouches behind; its shot does not, and that is what he hides from.)
const STILL := 0.15
const PROP_PROBE := 2.0
const PROBE_STEP := 0.25
## A shot at the prop is aimed this far past one of its side edges (as the
## Guard sees it), at his body centre's height: it skims the edge rather
## than strike the prop.
const EDGE_OUT := 0.15
## Guns that fire on his cover: a Marksman Rifle has no sight line without a
## target, and a Shotgun holds fire beyond 8 m.
const SUPPRESSORS: Array[CrewHabit.Gun] = [CrewHabit.Gun.PISTOL, CrewHabit.Gun.ASSAULT_RIFLE]

## The Pirate this team fights.
var target: Node3D
## The prop tile he broke sight behind (Vector2i.MAX with none), on which
## ship, and seconds since.
var prop := Vector2i.MAX
var prop_layout: ShipLayout
var since := 0.0
## How long the Guards fire on it: the Sandbox's suppression time, read from
## the Guard that lost him.
var _time := 4.0
## The one Guard that moved up while the others fire on his cover.
var mover_up: Crew3D
## The Guards that had a shot at him at the start of the last frame:
## [Guard, where it stood, its cover mode].
var _saw: Array = []
var _flank_timer := 0.0
var _frame := -1


## The team fighting [param pirate], made on first asking; null with no
## Pirate.
static func of(pirate: Node3D) -> CrewTeam:
	if pirate == null or not is_instance_valid(pirate):
		return null
	if pirate.has_meta(META):
		return pirate.get_meta(META)
	var team := CrewTeam.new()
	team.target = pirate
	pirate.set_meta(META, team)
	return team


## Settles this physics frame: whether he just broke sight behind a prop,
## how long the Guards have fired on it, and every FLANK_LOOK seconds
## whether a Guard should flank. Runs once a frame; later calls in the same
## frame do nothing.
func update() -> void:
	var frame := Engine.get_physics_frames()
	if frame == _frame:
		return
	var step := 1.0 / Engine.physics_ticks_per_second
	var dt := 0.0 if _frame < 0 else (frame - _frame) * step
	_frame = frame
	var members := _fighting()
	if members.is_empty():
		prop = Vector2i.MAX
		_saw.clear()
		return
	var shooters: Array = []
	for crew in members:
		if crew._can_see and crew.cover != null and not crew._muzzle_blocked():
			shooters.append([crew, crew.global_position, crew.cover.mode])
	if prop != Vector2i.MAX:
		since += dt
	if not shooters.is_empty():
		# A shot at him again: whatever he hid behind is over.
		prop = Vector2i.MAX
		mover_up = null
		_saw = shooters
	elif not _saw.is_empty():
		# Every shot at him lost since last frame. He broke it (rather than
		# the Guard ducking or stepping away) if one of them stood still;
		# behind a prop if one lies just beyond him from it.
		for entry: Array in _saw:
			var crew: Crew3D = entry[0] if is_instance_valid(entry[0]) else null
			if crew == null or not crew in members or crew.cover.mode != entry[2] \
					or crew.cover.mode in [CrewCover.Mode.OUT, CrewCover.Mode.BACK, CrewCover.Mode.MOVE] \
					or _flat(crew.global_position, entry[1]) > STILL:
				continue
			var tile := prop_between(crew)
			if tile != Vector2i.MAX:
				prop = tile
				prop_layout = crew.layout
				since = 0.0
				var sandbox: Sandbox = crew.sandbox if crew.sandbox != null else load(Sandbox.PATH)
				_time = sandbox.suppression_time
				mover_up = null
				break
		_saw.clear()
	_flank_timer -= dt
	if _flank_timer <= 0.0:
		_flank_timer = FLANK_LOOK
		consider_flank()


## The living Guards fighting him (FIGHT or COVER).
func _fighting() -> Array[Crew3D]:
	var fire := CrewFire.of(target)
	return fire.fighting() if fire != null else ([] as Array[Crew3D])


## Every living Guard after him: hunting, fighting or flanking.
func _team() -> Array[Crew3D]:
	var out: Array[Crew3D] = []
	if not is_instance_valid(target) or not target.is_inside_tree():
		return out
	for node in target.get_tree().get_nodes_in_group(&"crew"):
		var crew := node as Crew3D
		if crew != null and crew.target == target and not crew.is_worker() and crew.is_alive() \
				and crew.state in [Crew3D.State.HUNT, Crew3D.State.FIGHT, Crew3D.State.COVER]:
			out.append(crew)
	return out


# --- suppression ----------------------------------------------------------------

## The prop tile he stands just behind from [param crew]: going from him
## toward it, the first solid tile of the walking grid within PROP_PROBE,
## when that is a prop in a Room (not a wall). Vector2i.MAX otherwise.
func prop_between(crew: Crew3D) -> Vector2i:
	var layout := crew.layout
	if layout == null or not is_instance_valid(target):
		return Vector2i.MAX
	var toward := crew.global_position - target.global_position
	toward.y = 0.0
	if toward.length_squared() < 0.0001:
		return Vector2i.MAX
	toward = toward.normalized()
	var astar := CrewPaths.grid(layout)
	var own := ShipBuilder3D.world_to_tile(target.global_position)
	var along := PROBE_STEP
	while along <= PROP_PROBE + 0.001:
		var tile := ShipBuilder3D.world_to_tile(target.global_position + toward * along)
		along += PROBE_STEP
		if tile == own:
			continue
		if not astar.is_in_boundsv(tile) or layout.room_at(tile) < 0:
			return Vector2i.MAX  # a wall or a doorway's frame: no prop
		if astar.is_point_solid(tile):
			return tile
	return Vector2i.MAX


## Whether the Guards are firing on the prop he broke sight behind: from the
## sight break for the Sandbox's suppression time.
func suppressing() -> bool:
	return prop != Vector2i.MAX and since <= _time


## Whether [param crew] takes part: a Pistol or Assault Rifle Guard on the
## prop's ship, while the team is suppressing.
func suppresses(crew: Crew3D) -> bool:
	return suppressing() and crew.layout == prop_layout and crew.cover != null and crew.cover.gun in SUPPRESSORS


## Where [param crew] aims a shot at the prop's edge: just past its side
## edge on [param side] (+1 right, -1 left, as it sees the prop), at his
## body centre's height, or past the other edge when that one is not in its
## sight or muzzle line. INF when it does not take part or sees neither.
func suppress_point(crew: Crew3D, side: float) -> Vector3:
	if not suppresses(crew):
		return Vector3.INF
	var centre := ShipBuilder3D.tile_to_world(prop)
	var across := CrewFire.side_axis(crew.global_position, centre)
	var eye := crew.global_position + Vector3.UP * Crew3D.EYE_HEIGHT
	for sign: float in [side, -side]:
		var at := centre + across * sign * (ShipBuilder3D.TILE * 0.5 + EDGE_OUT)
		at.y = Crew3D.TORSO_HEIGHT
		if not crew._blocked(eye, at) and not crew._muzzle_blocked_from(crew.global_position, at):
			return at
	return Vector3.INF


## The two points a suppressing shot may be aimed at for [param crew] (the
## prop's side edges as it sees them, before EDGE_OUT): for checks.
func prop_edges(crew: Crew3D) -> Array[Vector3]:
	if prop == Vector2i.MAX:
		return []
	var centre := ShipBuilder3D.tile_to_world(prop)
	var across := CrewFire.side_axis(crew.global_position, centre)
	var out: Array[Vector3] = []
	for sign: float in [1.0, -1.0]:
		var at := centre + across * sign * ShipBuilder3D.TILE * 0.5
		at.y = Crew3D.TORSO_HEIGHT
		out.append(at)
	return out


## Whether [param crew] may be the one Guard to move up while the others
## fire on his cover (not a Marksman Rifle, which never moves up).
func may_move_up(crew: Crew3D) -> bool:
	return suppressing() and crew.cover != null and crew.cover.gun != CrewHabit.Gun.MARKSMAN_RIFLE \
			and (mover_up == null or not is_instance_valid(mover_up) or mover_up == crew)


func moved_up(crew: Crew3D) -> void:
	mover_up = crew


# --- the flank ------------------------------------------------------------------

## Whether someone after him is flanking now (going round, or walking to its
## spot inside the Door it came through).
func flanker() -> Crew3D:
	for crew in _team():
		if crew.flanking or (crew.cover != null and crew.cover.flank_end):
			return crew
	return null


## One flanker at a time, while another Guard fights him: of the Guards
## after him that have not flanked in this fight, are outside his Room and
## have a way round to another of its Doors, the first by gun (Shotgun, then
## Pistol, then Assault Rifle; never a Marksman Rifle), then one still
## hunting before one already fighting, then the nearer him. It sets off.
func consider_flank() -> void:
	var team := _team()
	if team.is_empty() or flanker() != null:
		return
	var fighters: Array[Crew3D] = []
	for crew in team:
		if crew.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
			fighters.append(crew)
	if fighters.is_empty():
		return
	var candidates: Array[Dictionary] = []
	for crew in team:
		var gun := CrewHabit.gun_of(crew.weapon)
		if not FLANK_ORDER.has(gun) or crew.flank_done or crew._hunting_trace or crew.layout == null:
			continue
		if crew.cover != null and crew.cover.last_guard:
			continue
		if crew.is_reloading():
			continue  # it finishes its reload where it is, then acts
		var his := crew.layout.room_at(ShipBuilder3D.world_to_tile(crew._last_seen))
		if his < 0 or his in CrewNoise.rooms_at(crew.layout, crew.global_position):
			continue  # no Room to go round into, or already in it
		# The Guard pinning him: the other fighter nearest him.
		var pinner: Crew3D = null
		for other in fighters:
			if other != crew and other.layout == crew.layout and (pinner == null \
					or _flat(other.global_position, crew._last_seen) < _flat(pinner.global_position, crew._last_seen)):
				pinner = other
		if pinner == null:
			continue
		candidates.append({"crew": crew, "pinner": pinner, "order": FLANK_ORDER[gun],
				"fighting": 1 if crew.state != Crew3D.State.HUNT else 0, "far": _flat(crew.global_position, crew._last_seen)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.order != b.order:
			return a.order < b.order
		if a.fighting != b.fighting:
			return a.fighting < b.fighting
		return a.far < b.far)
	for entry in candidates:
		var crew: Crew3D = entry.crew
		var door := []
		var route := CrewCombat.flank_route(crew, crew._last_seen, entry.pinner.global_position, door)
		if route.is_empty():
			continue
		crew._start_flank(route, door[0], crew.layout.room_at(ShipBuilder3D.world_to_tile(crew._last_seen)))
		return


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
