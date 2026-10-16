class_name Crew3D
extends CharacterBody3D
## Hostile crew: patrols its room, builds Awareness of the pirate through a
## forward sight cone ([CrewPerception]), comes to look when suspicious,
## hunts him once spotted, and fights from cover -- shoot a burst, duck
## behind something to reload, lean back out. The whole system is written up
## in `CREW_AI.md` beside this file.
##
## A straight port of the 2D crew onto the XZ plane. Movement between rooms
## rides the door graph via [ShipNavigator]; inside a room the crew steers
## straight at its waypoint, which is enough because rooms are convex
## rectangles. Cover is worked out by raycast at the moment it is needed rather
## than baked into the layout. Sight rays run at eye height; the cover ray runs
## lower, at the height of someone tucked down behind a crate.
##
## Each crew member dresses at spawn in one of the `rigs`, drawn at random
## for variety, stood `RIG_HEIGHT` tall on the floor under `Model`; the rigs
## share Quaternius's clip names, which the brain plays by state.

## Newer states go last so the older ones keep their numbers.
enum State { PATROL, HUNT, FIGHT, COVER, SEARCH, DEAD, INVESTIGATE, FLEE, COWER }

## Called on every node in this group, with the crew member, each time one
## tips into spotted: the HUD's sting and markers listen here.
const SPOTTED_GROUP := &"awareness_listeners"
## Awareness a crew member keeps on giving up a chase: still suspicious.
const SEARCH_AWARENESS := 0.7
## Fraction of full speed a suspicious crew member walks at to look.
const INVESTIGATE_SPEED := 0.45
## Seconds stood at the spot it came to look at before giving up.
const INVESTIGATE_LINGER := 2.0
## Seconds an investigation may run with nothing in view before it is
## dropped, even short of the spot (it may be inside a prop).
const INVESTIGATE_GIVE_UP := 10.0
## Awareness a heard noise lifts a crew member to: a footstep or door, and
## a gunshot. Hearing never reaches spotted.
const HEARD_NOISE := 0.45
const HEARD_GUNSHOT := 0.6
const HEARD_CAP := 0.95
## How far an unaware crew member's idle glances turn, either way.
const GLANCE_DEGREES := 70.0
## Fraction of full speed a crew member walks at about its routine.
const ROUTINE_SPEED := 0.5
## Below this flat speed a moving crew member walks rather than runs.
const WALK_ANIM_SPEED := 2.4
## Doors a crew member opened on routine are shut again once it is this far
## past them; further off than DOOR_FORGET, it no longer bothers.
const DOOR_CLOSE_AFTER := 2.0
const DOOR_FORGET := 6.0
## An open door a routine crew member passes this close to becomes its to shut.
const DOOR_ADOPT := 1.0
## Two routine crew passing this close may stop to chat: the chance, how
## long it lasts, and how long before either chats again.
const CHAT_RANGE := 1.6
const CHAT_CHANCE := 0.3
const CHAT_TIME := Vector2(3.0, 5.0)
const CHAT_COOLDOWN := 40.0
## Seconds walking toward one Job before giving it up as unreachable.
const JOB_GIVE_UP := 30.0
## A Worker fights only with the Pirate this close and in sight, and goes
## back to running once he is further than CORNER_RELEASE.
const CORNERED_RANGE := 3.0
const CORNER_RELEASE := 5.0
## Chance a spotted Worker hides where it is rather than run for a Guard.
const HIDE_CHANCE := 0.25
## A fleeing Worker has reached its Guard this close, and raises it.
const GUARD_REACH := 2.5
## A Worker has reached an Alarm Panel this close to its use spot.
const PANEL_REACH := 0.9
## On Edge, a patrolling Guard pauses this fraction as long at each stop.
const ON_EDGE_PAUSE := 0.5
## Under the Alarm, a sweeping Guard's pause at each Room it checks.
const SWEEP_PAUSE := 1.5
## Seconds a hiding Worker stays put with nothing in sight before it
## creeps back to its routine.
const COWER_CALM := 15.0
## A Worker's sidearm: wider spread and shorter bursts than a Guard's rifle.
const WORKER_SPREAD := 12.0
const WORKER_BURST := 2
## How fast the body turns to face where it is looking, radians a second.
const TURN_RATE := 6.0

const TEAM := &"crew"
## Layer 1 is the ship itself: hull, props and shut doors.
const WORLD_LAYER := 1

## Where the sight ray leaves and arrives, in metres off the floor.
const EYE_HEIGHT := 1.5
## Cover only counts if it hides someone crouched this high.
const COVER_HEIGHT := 0.9
## Shots leave here and are aimed at the target's torso.
const MUZZLE_HEIGHT := 1.3
const TORSO_HEIGHT := 1.0

@export_group("Movement")
@export var max_speed := 3.59
@export var acceleration := 28.0
@export var friction := 34.4
## How close counts as having reached a waypoint.
@export var arrive_radius := 0.44

@export_group("Perception")
@export var vision_range := CrewPerception.SIGHT_RANGE
## Seconds out of sight before the crew stops shooting and starts searching.
@export var lose_target_after := 3.0

@export_group("Gunnery")
@export var engage_range := 10.6
@export var burst_size := 3
@export var burst_gap := 0.14
@export var reload_time := 1.1
## Crew are worse shots than the player.
@export var spread_degrees := 7.0
@export var muzzle_offset := 0.625
@export var projectile_scene: PackedScene = preload("res://scenes/projectile_3d.tscn")
## What their shot sounds like, rung at the muzzle: the same gun as the
## Pirate's, and distance does the rest.
@export var shot_streams: Array[AudioStream] = [
	preload("res://assets/audio/kurt_gunshots/shot_1.ogg"),
	preload("res://assets/audio/kurt_gunshots/shot_2.ogg"),
	preload("res://assets/audio/kurt_gunshots/shot_3.ogg"),
	preload("res://assets/audio/kurt_gunshots/shot_4.ogg"),
]
@export var shot_volume_db := -3.0

@export_group("Look")
## The bodies crew wear: the first for Workers, the second for Guards.
@export var rigs: Array[PackedScene] = [
	preload("res://assets/models/crew/gunner.glb"),
	preload("res://assets/models/crew/soldier.glb"),
]
## How tall a rig stands once fitted, metres: a head over the Pirate, since
## these stylised bodies read small beside 3.5 m rooms.
const RIG_HEIGHT := 2.0
## Clips that must loop while a state holds them.
const LOOPING_CLIPS: Array[StringName] = [&"CharacterArmature|Idle", &"CharacterArmature|Idle_Gun",
		&"CharacterArmature|Idle_Gun_Pointing", &"CharacterArmature|Run", &"CharacterArmature|Walk"]

@export_group("Cover")
@export var cover_search_radius := 6.9
## Seconds spent behind cover before leaning back out.
@export var cover_hold_time := 1.2

## Set by [ShipBuilder3D] so the crew can route around its own ship.
var layout: ShipLayout
## Guard or Worker ([CrewTypes]), set by [ShipBuilder3D] from the Post
## Room's Role before the crew member enters the tree.
var crew_type: CrewTypes.Type = CrewTypes.Type.GUARD
## The colour its rig is tinted, white for none.
var body_tint := Color.WHITE
## The Guard a fleeing Worker is running to.
var _flee_to: Crew3D
## The Alarm Panel a fleeing Worker is running to, instead of a Guard.
var _flee_panel: AlarmPanel
var _alarm: ShipAlarm
## The physics frame this crew member last started a burst on, so no two
## start in step ([method CrewCombat.burst_blocked]).
var burst_frame := -1000
## Seconds the Pirate has been in its sight without a break: its aim
## tightens with it ([method CrewCombat.spread]).
var _exposed_for := 0.0
var _share_timer := 0.0
## A Guard going round through another Door while another pins him.
var flanking := false
var _flank_clock := 0.0
## Chance this Worker hides rather than runs; [constant HIDE_CHANCE] unless
## a test wants it certain.
var hide_chance := HIDE_CHANCE
var home_room := 0
var target: Node3D
var state := State.PATROL

@onready var model: Node3D = $Model
@onready var health: Health = $Health

var _path: Array[Vector3] = []
var _aim := Vector3.FORWARD
var _shots_left := 0
var _shot_timer := 0.0
var _reload_timer := 0.0
## Counts down inside states that wait: holding cover, pausing on patrol.
var _hold_timer := 0.0
var _repath_timer := 0.0
var _last_seen := Vector3.ZERO
var _seen_ago := 999.0
var _can_see := false
## In the forward cone and line of sight: what builds Awareness. _can_see
## ignores the cone, which is how a crew member already fighting tracks him.
var _in_view := false
var perception := CrewPerception.new()
## Where the pirate was when this crew member last noticed him.
var _noticed_at := Vector3.ZERO
var _glance_timer := 0.0
var _speed_scale := 1.0
## Its loop of Jobs ([CrewRoutine]); null without a layout to plan from,
## when it falls back to wandering its own Room.
var routine: CrewRoutine
enum JobPhase { WAITING, WALKING, WORKING, CHATTING }
var job_phase := JobPhase.WAITING
var _opened_doors: Array[Door3D] = []
var _chat_with: Crew3D
var _chat_cooldown := 0.0
## Seconds spent walking to the current Job; a route that never arrives
## (blocked by a body in a doorway, say) is given up on.
var _walk_clock := 0.0
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _anim: AnimationPlayer


func _ready() -> void:
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player")
	_rng.randomize()
	if is_worker():
		spread_degrees = WORKER_SPREAD
		burst_size = WORKER_BURST
	else:
		# No two Guards keep the same rhythm.
		burst_size = clampi(burst_size + _rng.randi_range(-1, 1), 2, 4)
	burst_gap *= CrewCombat.jitter(_rng)
	reload_time *= CrewCombat.jitter(_rng)
	cover_hold_time *= CrewCombat.jitter(_rng)
	_shots_left = burst_size
	_dress()
	_anim = _find_animation_player(model)
	if _anim != null:
		for clip in LOOPING_CLIPS:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	if layout != null and home_room >= 0 and home_room < layout.rooms.size():
		routine = CrewRoutine.plan(layout, home_room, _rng, crew_type == CrewTypes.Type.GUARD)
	_enter(State.PATROL)
	# Each starts its routine after a moment of its own, not all at once.
	job_phase = JobPhase.WAITING
	_path.clear()
	_hold_timer = _rng.randf_range(0.0, 5.0)
	_chat_cooldown = _rng.randf_range(5.0, CHAT_COOLDOWN)
	_update_animation()


## One of the rigs, instanced under Model as "Rig" and scaled so it stands
## RIG_HEIGHT tall with its feet on the floor. Rigs come in whatever units
## their author used, so the fit is measured, not assumed.
func _dress() -> void:
	if rigs.is_empty():
		return
	var rig: Node3D = _rig_for(crew_type).instantiate()
	rig.name = "Rig"
	model.add_child(rig)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = (mi as MeshInstance3D).get_aabb()
		var to_rig: Transform3D = (mi as MeshInstance3D).transform
		var up: Node = mi.get_parent()
		while up != rig and up is Node3D:
			to_rig = (up as Node3D).transform * to_rig
			up = up.get_parent()
		var in_rig := to_rig * bounds
		lo = lo.min(in_rig.position)
		hi = hi.max(in_rig.end)
	var height := hi.y - lo.y
	if height > 0.01:
		var fit := RIG_HEIGHT / height
		rig.scale = Vector3.ONE * fit
		rig.position.y = -lo.y * fit
	_tint(rig, CrewTypes.tint(crew_type))


## Until the booth picks a model per type (#62), each type wears one of the
## two rigs so they read apart at a glance: Workers the light gunner, whose
## armour shows the tint, Guards the dark soldier. A rig list of one serves
## both.
func _rig_for(type: CrewTypes.Type) -> PackedScene:
	if rigs.size() < 2:
		return rigs[0]
	return rigs[0] if type == CrewTypes.Type.WORKER else rigs[1]


## Multiplies every surface of the rig by [param color], on copies of its
## materials so the other crew sharing the rig keep theirs.
func _tint(rig: Node3D, color: Color) -> void:
	body_tint = color
	if color == Color.WHITE:
		return
	for node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i in mesh.get_surface_override_material_count():
			var material := mesh.get_active_material(i) as BaseMaterial3D
			if material == null:
				continue
			var tinted := material.duplicate() as BaseMaterial3D
			tinted.albedo_color *= color
			mesh.set_surface_override_material(i, tinted)


func is_worker() -> bool:
	return crew_type == CrewTypes.Type.WORKER

func get_team() -> StringName:
	return TEAM


## Turn to face [param direction] on the floor plane, at spawn: crew at a
## station face into their Room, crew behind cover face the doorway.
func face_direction(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	_aim = direction.normalized()
	rotation.y = atan2(-_aim.x, -_aim.z)


func take_damage(amount: int, from: Node = null) -> void:
	if state == State.DEAD:
		return
	if health.take_damage(amount, from):
		return
	# Being shot at from somewhere unseen still tells you roughly where to look.
	if from != null and is_instance_valid(from) and from is Node3D:
		_last_seen = (from as Node3D).global_position
		_seen_ago = 0.0
	if perception.alert():
		_announce_spotted()
	match state:
		State.PATROL, State.SEARCH, State.INVESTIGATE:
			_react_spotted()
		State.FLEE, State.COWER:
			if _cornered():
				_enter(State.FIGHT)
		State.FIGHT:
			if _rng.randf() < 0.6:
				_enter(State.COVER)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	_update_perception(delta)
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	_reload_timer = maxf(_reload_timer - delta, 0.0)
	_hold_timer = maxf(_hold_timer - delta, 0.0)
	_repath_timer = maxf(_repath_timer - delta, 0.0)
	_glance_timer = maxf(_glance_timer - delta, 0.0)
	_chat_cooldown = maxf(_chat_cooldown - delta, 0.0)

	match state:
		State.PATROL:
			_tick_patrol()
		State.HUNT:
			_tick_hunt()
		State.FIGHT:
			_tick_fight()
		State.COVER:
			_tick_cover()
		State.SEARCH:
			_tick_search()
		State.INVESTIGATE:
			_tick_investigate()
		State.FLEE:
			_tick_flee()
		State.COWER:
			_tick_cower()

	_steer(delta)
	_open_doors_ahead()
	_close_doors_behind()
	move_and_slide()
	_face()
	_update_animation()


# --- perception ---------------------------------------------------------------

func _update_perception(delta: float) -> void:
	_can_see = false
	_in_view = false
	if target == null or not is_instance_valid(target):
		_seen_ago += delta
		return
	if target.has_method("is_alive") and not target.is_alive():
		_seen_ago += delta
		return
	var distance := _flat_distance(global_position, target.global_position)
	if distance <= vision_range \
			and not _blocked(global_position + Vector3.UP * EYE_HEIGHT,
					target.global_position + Vector3.UP * EYE_HEIGHT):
		_can_see = true
		_in_view = CrewPerception.in_cone(facing(), target.global_position - global_position)

	if _in_combat():
		# A fight tracks him all round and never second-guesses itself.
		perception.awareness = 1.0
		if _can_see:
			_last_seen = target.global_position
			_seen_ago = 0.0
			_exposed_for += delta
			_share_timer -= delta
			if not is_worker() and _share_timer <= 0.0:
				_share_timer = CrewCombat.SHARE_EVERY
				CrewCombat.share(self, _last_seen)
		else:
			_seen_ago += delta
			_exposed_for = 0.0
		return
	_exposed_for = 0.0

	var crouched: bool = target.has_method("is_crouched") and target.is_crouched()
	if _in_view:
		_noticed_at = target.global_position
	if perception.sense(delta, _in_view, distance, crouched):
		_last_seen = target.global_position
		_seen_ago = 0.0
		_announce_spotted()
	else:
		_seen_ago += delta


## A noise reached this crew member (see [CrewNoise]). Raises Awareness toward
## suspicious, never to spotted, and gives it somewhere to look. Crew shrug
## off their mates' footsteps and doors, not their gunfire. Returns whether
## it took any notice.
func hear(at: Vector3, kind: CrewNoise.Kind, source: Node = null) -> bool:
	if state == State.DEAD or _in_combat():
		return false
	if kind != CrewNoise.Kind.GUNSHOT and source is Crew3D:
		return false
	var loud := HEARD_GUNSHOT if kind == CrewNoise.Kind.GUNSHOT else HEARD_NOISE
	# Only ever raises it: a noise never talks a crew member back down.
	perception.awareness = maxf(perception.awareness, minf(loud, HEARD_CAP))
	_noticed_at = at
	if state == State.INVESTIGATE:
		_repath_to(at)
		_hold_timer = INVESTIGATE_LINGER
	return true


## Which way this crew member is looking, flat.
func facing() -> Vector3:
	return -global_basis.z


func _in_combat() -> bool:
	return state in [State.HUNT, State.FIGHT, State.COVER, State.FLEE, State.COWER]


## Just spotted him: a Guard hunts him; a Worker runs, unless he is right
## on top of it, when it fights.
func _react_spotted() -> void:
	if not is_worker():
		_enter(State.HUNT)
		_share_timer = CrewCombat.SHARE_EVERY
		CrewCombat.share(self, _last_seen)
	elif _cornered():
		_enter(State.FIGHT)
	else:
		_enter(State.FLEE)


## The Pirate is in sight and within arm's reach of a Worker.
func _cornered() -> bool:
	return _can_see and target != null and is_instance_valid(target) \
			and _flat_distance(global_position, target.global_position) <= CORNERED_RANGE


## Where a crew member goes on losing him: a Guard searches, a Worker hides.
func _lost_state() -> State:
	return State.COWER if is_worker() else State.SEARCH


func _spotted() -> bool:
	return perception.band() == CrewPerception.Band.SPOTTED


func _suspicious() -> bool:
	return perception.band() == CrewPerception.Band.SUSPICIOUS


func _announce_spotted() -> void:
	get_tree().call_group(SPOTTED_GROUP, "on_crew_spotted", self)


## True when the ship itself stands between two points.
func _blocked(from: Vector3, to: Vector3) -> bool:
	var params := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	params.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(params).is_empty()


## True when a point is inside the hull or a prop, so nobody can stand there.
func _solid(point: Vector3) -> bool:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = point + Vector3.UP * 0.5
	params.collision_mask = WORLD_LAYER
	return not get_world_3d().direct_space_state.intersect_point(params, 1).is_empty()


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# --- states -------------------------------------------------------------------

func _enter(next: State) -> void:
	state = next
	_speed_scale = 1.0
	flanking = false
	match next:
		State.PATROL:
			_path.clear()
			_hold_timer = _rng.randf_range(0.4, 1.6)
			if routine != null:
				# Back to whatever Job it was on.
				_speed_scale = ROUTINE_SPEED
				_start_job()
		State.INVESTIGATE:
			_speed_scale = INVESTIGATE_SPEED
			_walk_clock = 0.0
			_repath_to(_noticed_at)
			_hold_timer = INVESTIGATE_LINGER
		State.HUNT:
			_repath_to(_last_seen)
			_try_flank()
		State.FIGHT:
			_path.clear()
			_shots_left = burst_size
			# A beat before the first shot, different every time.
			_shot_timer = _rng.randf_range(0.05, 0.35)
		State.COVER:
			var spot := _find_cover_point()
			if spot != Vector3.INF:
				_repath_to(spot)
			else:
				_path.clear()
			_hold_timer = cover_hold_time
		State.FLEE:
			_flee_panel = null
			_flee_to = null
			if _rng.randf() < hide_chance:
				_enter(State.COWER)
				return
			_pick_flight()
		State.COWER:
			_flee_to = null
			_flee_panel = null
			_hold_timer = COWER_CALM
			var spot := _find_cover_point()
			if spot != Vector3.INF:
				_repath_to(spot)
			else:
				_path.clear()
		State.SEARCH:
			perception.on_edge = true
			perception.awareness = minf(perception.awareness, SEARCH_AWARENESS)
			_repath_to(_last_seen)
			_hold_timer = 2.5


func _tick_patrol() -> void:
	if _spotted():
		_react_spotted()
		return
	if _suspicious():
		_enter(State.INVESTIGATE)
		return
	if routine != null:
		_tick_routine()
		return
	if _path.is_empty() and _hold_timer <= 0.0:
		_path.append(_random_point_in_room(home_room))
		_hold_timer = _rng.randf_range(0.8, 2.2)
	elif _path.is_empty():
		_glance()


## Stood still and unaware: look about, so the cone is not a fixed wedge.
func _glance() -> void:
	if _glance_timer > 0.0:
		return
	_aim = _aim.rotated(Vector3.UP, deg_to_rad(_rng.randf_range(-GLANCE_DEGREES, GLANCE_DEGREES)))
	_glance_timer = _rng.randf_range(1.5, 4.0)


## Walk to the Job, do it, move on to the next; stop to chat now and then.
func _tick_routine() -> void:
	if _alarm_raised():
		if is_worker():
			_enter(State.COWER)
		else:
			_tick_sweep()
		return
	_speed_scale = ROUTINE_SPEED
	var job := routine.current()
	match job_phase:
		JobPhase.WAITING:
			_glance()
			if _hold_timer <= 0.0:
				_start_job()
		JobPhase.WALKING:
			_walk_clock += get_physics_process_delta_time()
			if _path.is_empty():
				job_phase = JobPhase.WORKING
				_hold_timer = job.duration * (ON_EDGE_PAUSE if perception.on_edge and job.patrol else 1.0)
			elif _walk_clock > JOB_GIVE_UP:
				routine.advance()
				_start_job()
			else:
				_maybe_chat()
		JobPhase.WORKING:
			if job.patrol:
				_glance()
			else:
				_aim = job.face.normalized()
			if _hold_timer <= 0.0:
				routine.advance()
				_start_job()
		JobPhase.CHATTING:
			if is_instance_valid(_chat_with):
				_aim = (_chat_with.global_position - global_position).normalized()
			if _hold_timer <= 0.0 or not is_instance_valid(_chat_with) or _chat_with.state != State.PATROL:
				_chat_with = null
				_start_job()


## Under the Alarm a Guard has no routine: it sweeps the ship at full
## speed, Room to random Room, pausing briefly to look about in each.
func _tick_sweep() -> void:
	_speed_scale = 1.0
	job_phase = JobPhase.WALKING
	if not _path.is_empty():
		return
	if _hold_timer > 0.0:
		_glance()
		return
	_repath_to(_random_point_in_room(_rng.randi_range(0, layout.rooms.size() - 1)))
	_hold_timer = SWEEP_PAUSE


## Sets off for the current Job. A patrol stop whose centre is blocked
## moves to any free spot in that Room; a work Job whose spot is blocked is
## skipped. With nothing reachable it just wanders its Post.
func _start_job() -> void:
	var spot := Vector3.INF
	for _try in routine.jobs.size():
		var job := routine.current()
		if not _solid(job.at):
			spot = job.at
			break
		if job.patrol:
			spot = _random_point_in_room(job.room)
			break
		routine.advance()
	if spot == Vector3.INF:
		spot = _random_point_in_room(home_room)
	_repath_to(spot)
	job_phase = JobPhase.WALKING
	_walk_clock = 0.0


## Two crew passing each other on routine sometimes stop to talk.
func _maybe_chat() -> void:
	if _chat_cooldown > 0.0:
		return
	for node in get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == self or other.state != State.PATROL \
				or other.job_phase != JobPhase.WALKING or other._chat_cooldown > 0.0:
			continue
		if _flat_distance(global_position, other.global_position) > CHAT_RANGE:
			continue
		_chat_cooldown = CHAT_COOLDOWN
		other._chat_cooldown = CHAT_COOLDOWN
		if _rng.randf() >= CHAT_CHANCE:
			return
		var time := _rng.randf_range(CHAT_TIME.x, CHAT_TIME.y)
		_start_chat(other, time)
		other._start_chat(self, time)
		return


func _start_chat(other: Crew3D, time: float) -> void:
	_path.clear()
	_chat_with = other
	job_phase = JobPhase.CHATTING
	_hold_timer = time


## Suspicious: walk to where he was noticed, look, and give up once the
## feeling fades with nothing more to see.
func _tick_investigate() -> void:
	if _spotted():
		_react_spotted()
		return
	if _in_view:
		# Still something there: keep closing on it.
		if _repath_timer <= 0.0:
			_repath_to(_noticed_at)
		_hold_timer = INVESTIGATE_LINGER
		_walk_clock = 0.0
		return
	_walk_clock += get_physics_process_delta_time()
	var calm := perception.awareness < CrewPerception.SUSPICIOUS
	if calm and ((_path.is_empty() and _hold_timer <= 0.0) or _walk_clock > INVESTIGATE_GIVE_UP):
		_enter(State.PATROL)


## Told by another Guard where the Pirate is: hunt there, or keep hunting
## with the fresher position.
func hear_position(at: Vector3) -> void:
	if state == State.DEAD or is_worker():
		return
	if state in [State.FIGHT, State.COVER]:
		return
	_last_seen = at
	_seen_ago = 0.0
	perception.awareness = 1.0
	if state != State.HUNT:
		_enter(State.HUNT)


## With another Guard already pinning him, go round through his Room's
## other Door rather than in behind it.
func _try_flank() -> void:
	if is_worker():
		return
	var pinner: Crew3D = null
	for node in get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == self or other.is_worker() or not other.is_alive():
			continue
		if other.flanking:
			return  # someone is already going round
		if other.state in [State.FIGHT, State.COVER]:
			pinner = other
	if pinner == null:
		return
	var route := CrewCombat.flank_route(self, _last_seen, pinner.global_position)
	if route.is_empty():
		return
	_path = route
	flanking = true
	_flank_clock = 0.0


func _tick_hunt() -> void:
	if flanking:
		_flank_clock += get_physics_process_delta_time()
		if _can_see and _flat_distance(global_position, target.global_position) <= engage_range:
			_enter(State.FIGHT)
		elif _path.is_empty() or _flank_clock > CrewCombat.FLANK_GIVE_UP:
			# Arrived, or given up: back to hunting him the straight way.
			flanking = false
			_repath_to(_last_seen)
		return
	if _can_see and _flat_distance(global_position, target.global_position) <= engage_range:
		_enter(State.FIGHT)
		return
	if _seen_ago > lose_target_after:
		_enter(State.SEARCH)
		return
	if _repath_timer <= 0.0:
		_repath_to(_last_seen)


func _tick_fight() -> void:
	if is_worker() and not _cornered() and target != null and is_instance_valid(target) \
			and _flat_distance(global_position, target.global_position) > CORNER_RELEASE:
		_enter(State.FLEE)
		return
	if _seen_ago > lose_target_after:
		_enter(_lost_state())
		return

	if _can_see:
		_path.clear()
		_aim = (target.global_position + Vector3.UP * TORSO_HEIGHT
				- (global_position + Vector3.UP * MUZZLE_HEIGHT)).normalized()
		if _shots_left > 0:
			if _shot_timer <= 0.0:
				if _shots_left == burst_size:
					# Start of a burst: never in step with another's.
					if CrewCombat.burst_blocked(self):
						_shot_timer = 0.05
						return
					burst_frame = Engine.get_physics_frames()
				_fire()
		else:
			# Burst spent: get behind something while reloading.
			_enter(State.COVER)
		return

	# Lost the angle but not the scent: move somewhere with a shot.
	if _path.is_empty():
		var spot := _find_firing_position()
		_repath_to(spot if spot != Vector3.INF else _last_seen)


func _tick_cover() -> void:
	if _seen_ago > lose_target_after:
		_enter(_lost_state())
		return
	if not _path.is_empty():
		return  # still getting there
	if _hold_timer > 0.0 or _reload_timer > 0.0:
		return  # tucked in, reloading
	_enter(State.FIGHT)


## A Worker running to the nearest Guard to raise it; it hides on arrival,
## and fights only if cornered on the way.
func _tick_flee() -> void:
	if _cornered():
		_enter(State.FIGHT)
		return
	if _flee_panel != null:
		if _flee_panel.broken or _alarm_raised():
			# Shot out, or someone beat it there: somewhere else to run.
			_pick_flight()
		elif _flat_distance(global_position, _flee_panel.use_at) <= PANEL_REACH:
			_raise_alarm()
			_enter(State.COWER)
		elif _repath_timer <= 0.0:
			_repath_to(_flee_panel.use_at)
		return
	if _flee_to == null or not is_instance_valid(_flee_to) or not _flee_to.is_alive():
		# Its Guard is gone: on to the next one, without a second roll to hide.
		_flee_to = _nearest_guard()
		if _flee_to == null:
			_enter(State.COWER)
		else:
			_repath_to(_flee_to.global_position)
		return
	if _flat_distance(global_position, _flee_to.global_position) <= GUARD_REACH:
		_raise(_flee_to)
		_enter(State.COWER)
		return
	if _repath_timer <= 0.0:
		_repath_to(_flee_to.global_position)


## Tucked behind cover; fights only if cornered, and once nothing has been
## seen for a while creeps back to its routine.
func _tick_cower() -> void:
	if _cornered():
		_enter(State.FIGHT)
		return
	if _can_see or _alarm_raised():
		# Under the Alarm a Worker stays hidden for good.
		_hold_timer = COWER_CALM
	if _path.is_empty() and _hold_timer <= 0.0:
		perception.awareness = CrewPerception.SUSPICIOUS * 0.5
		perception.on_edge = true
		_enter(State.PATROL)


## Where a fleeing Worker runs: while the Alarm is down, the nearest working
## Alarm Panel to raise it; otherwise the nearest Guard; with neither, it
## hides.
func _pick_flight() -> void:
	_flee_panel = null if _alarm_raised() else _nearest_panel()
	if _flee_panel != null:
		_flee_to = null
		_repath_to(_flee_panel.use_at)
		return
	_flee_to = _nearest_guard()
	if _flee_to == null:
		_enter(State.COWER)
	else:
		_repath_to(_flee_to.global_position)


func _nearest_panel() -> AlarmPanel:
	var best: AlarmPanel = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"alarm_panels"):
		var panel := node as AlarmPanel
		if panel == null or panel.broken:
			continue
		var distance := _flat_distance(global_position, panel.use_at)
		if distance < best_distance:
			best = panel
			best_distance = distance
	return best


func _ship_alarm() -> ShipAlarm:
	if _alarm == null or not is_instance_valid(_alarm):
		_alarm = ShipAlarm.of(get_tree())
	return _alarm


func _alarm_raised() -> bool:
	var alarm := _ship_alarm()
	return alarm != null and alarm.is_raised


func _raise_alarm() -> void:
	var alarm := _ship_alarm()
	if alarm != null:
		alarm.raise(_last_seen)


## The ship's Alarm went up, the Pirate last known at [param at]: every
## routine stops. A Guard not already fighting hunts there; a Worker not
## already running or fighting hides. Everyone is On Edge from now on.
func on_alarm(at: Vector3) -> void:
	if state == State.DEAD:
		return
	perception.on_edge = true
	if is_worker():
		if state in [State.PATROL, State.INVESTIGATE, State.SEARCH]:
			_enter(State.COWER)
		return
	if state in [State.PATROL, State.INVESTIGATE, State.SEARCH]:
		_last_seen = at
		_seen_ago = 0.0
		perception.awareness = 1.0
		_enter(State.HUNT)


## A Worker reaching a Guard tells it where the Pirate was: it hunts there.
func _raise(guard: Crew3D) -> void:
	guard._last_seen = _last_seen
	guard._seen_ago = 0.0
	guard.perception.awareness = 1.0
	if not guard._in_combat():
		guard._enter(State.HUNT)


## The nearest living Guard this crew member has a route to, or null.
func _nearest_guard() -> Crew3D:
	var best: Crew3D = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == self or other.is_worker() or not other.is_alive():
			continue
		var distance := _flat_distance(global_position, other.global_position)
		if distance < best_distance:
			best = other
			best_distance = distance
	return best


func _tick_search() -> void:
	if _spotted():
		_react_spotted()
		return
	if _path.is_empty() and _hold_timer <= 0.0:
		_enter(State.PATROL)


# --- movement -----------------------------------------------------------------

func _steer(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if _path.is_empty():
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
	else:
		var point: Vector3 = _path[0]
		if _flat_distance(global_position, point) <= arrive_radius:
			_path.pop_front()
		else:
			var direction := point - global_position
			direction.y = 0.0
			direction = direction.normalized()
			flat = flat.move_toward(direction * max_speed * _speed_scale, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z


func _repath_to(destination: Vector3) -> void:
	_repath_timer = 0.5
	_path.clear()
	if layout != null:
		# Empty when the crew is stood in a doorway, which belongs to no room.
		_path.assign(ShipNavigator.waypoints_3d(layout, global_position, destination))
	if _path.is_empty():
		_path.append(destination)


## Crew work the doors they walk into; the pirate has to press E, they do not.
func _open_doors_ahead() -> void:
	if _path.is_empty():
		return
	for node in get_tree().get_nodes_in_group(&"doors"):
		var door: Door3D = node
		if door.locked:
			continue
		if door.is_open:
			# On routine, a door it walks through is its to shut, whoever
			# opened it: so whichever crew member passes last closes it.
			if state == State.PATROL and not door in _opened_doors \
					and _flat_distance(global_position, door.global_position) <= DOOR_ADOPT:
				_opened_doors.append(door)
			continue
		if _flat_distance(global_position, door.global_position) <= 1.75:
			door.open(self)
			if door.is_open and not door in _opened_doors:
				_opened_doors.append(door)


## On routine, a crew member shuts the Doors it opened once it is through,
## unless someone is still in the doorway; it tries again next tick.
func _close_doors_behind() -> void:
	for door in _opened_doors.duplicate():
		if not is_instance_valid(door) or not door.is_open:
			_opened_doors.erase(door)
			continue
		var distance := _flat_distance(global_position, door.global_position)
		if distance > DOOR_FORGET:
			_opened_doors.erase(door)
		elif state == State.PATROL and distance > DOOR_CLOSE_AFTER and door.close(self):
			_opened_doors.erase(door)


func _face() -> void:
	var look := _aim
	if state == State.FIGHT or (_in_combat() and _can_see):
		look = _last_seen - global_position
	elif Vector2(velocity.x, velocity.z).length_squared() > 0.004:
		look = velocity
	elif state == State.INVESTIGATE:
		look = _noticed_at - global_position
	look.y = 0.0
	if look.length_squared() > 0.001:
		_aim = look.normalized()
		# The body turns at a human rate; shots leave along _aim regardless.
		var want := atan2(-look.x, -look.z)
		var step := TURN_RATE * get_physics_process_delta_time()
		var gap := wrapf(want - rotation.y, -PI, PI)
		rotation.y += clampf(gap, -step, step)


# --- gunnery ------------------------------------------------------------------

func _fire() -> Projectile3D:
	if projectile_scene == null:
		return null
	_shots_left -= 1
	_shot_timer = burst_gap
	if _shots_left <= 0:
		_reload_timer = reload_time

	var cone := CrewCombat.spread(spread_degrees, _exposed_for)
	var spread := deg_to_rad(_rng.randf_range(-cone, cone))
	var direction := _aim.rotated(Vector3.UP, spread)
	var origin := global_position + Vector3.UP * MUZZLE_HEIGHT + direction * muzzle_offset
	var shot: Projectile3D = projectile_scene.instantiate()
	shot.launch(origin, direction, self, TEAM)
	_shot_parent().add_child(shot)
	if not shot_streams.is_empty():
		SoundAt.play(_shot_parent(), origin, shot_streams.pick_random(), shot_volume_db, 0.06, "Shot")
	CrewNoise.make(get_tree(), global_position, CrewNoise.Kind.GUNSHOT, CrewNoise.GUNSHOT, self)
	return shot


func _shot_parent() -> Node:
	var container := get_tree().get_first_node_in_group(&"projectiles")
	return container if container != null else get_parent()


# --- cover --------------------------------------------------------------------

## Somewhere nearby that the ship stands between us and the pirate: the ray
## from a crouched head there to the pirate's torso must be blocked, and the
## walk to it must be clear.
func _find_cover_point() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.INF
	var aim_at := _last_seen + Vector3.UP * TORSO_HEIGHT
	var best := Vector3.INF
	var best_score := -INF
	for point in _candidate_points():
		if not _blocked(point + Vector3.UP * COVER_HEIGHT, aim_at):
			continue  # exposed
		if _blocked(global_position + Vector3.UP * COVER_HEIGHT, point + Vector3.UP * COVER_HEIGHT):
			continue  # cannot get there in a straight line
		# Prefer close cover, but not cover so far back it abandons the fight.
		var score := -_flat_distance(global_position, point) - 0.35 * _flat_distance(point, _last_seen)
		if score > best_score:
			best_score = score
			best = point
	return best


## Somewhere nearby with a clear shot at the pirate.
func _find_firing_position() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.INF
	var aim_at := _last_seen + Vector3.UP * TORSO_HEIGHT
	var best := Vector3.INF
	var best_score := -INF
	for point in _candidate_points():
		if _blocked(point + Vector3.UP * MUZZLE_HEIGHT, aim_at):
			continue
		if _flat_distance(point, _last_seen) > engage_range:
			continue
		var score := -_flat_distance(global_position, point)
		if score > best_score:
			best_score = score
			best = point
	return best


## Tile centres in the current room within the search radius, minus any that
## are inside the hull or a prop.
func _candidate_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if layout == null:
		return points
	var room := layout.room_at(ShipBuilder3D.world_to_tile(global_position))
	if room == -1:
		room = home_room
	var breakers := _breaker_tiles(room)
	for tile: Vector2i in layout.rooms[room].tiles():
		var point := ShipBuilder3D.tile_to_world(tile)
		if _flat_distance(global_position, point) > cover_search_radius:
			continue
		if _solid(point):
			continue
		# A Breaker is the pirate's cover on the way in, never the defender's.
		if breakers.has(tile):
			continue
		points.append(point)
	return points


## Tiles beside a Breaker crate in a Room: {Vector2i: true}.
func _breaker_tiles(room: int) -> Dictionary:
	var out := {}
	for prop in layout.rooms[room].props:
		if not prop.get("breaker", false):
			continue
		var at: Vector2i = prop.get("tile", Vector2i.ZERO)
		for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			out[at + side] = true
	return out


func _random_point_in_room(room: int) -> Vector3:
	if layout == null or room < 0 or room >= layout.rooms.size():
		return global_position
	var tiles := layout.rooms[room].tiles().keys()
	for _attempt in 8:
		var tile: Vector2i = tiles[_rng.randi_range(0, tiles.size() - 1)]
		var point := ShipBuilder3D.tile_to_world(tile)
		if not _solid(point):
			return point
	return ShipBuilder3D.room_center_world(layout.rooms[room])


# --- animation ----------------------------------------------------------------

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


## Plays the first clip the model actually has, so the code survives a model
## swap with different animation names. Returns false when none matched.
func _play_any(names: Array[String]) -> bool:
	if _anim == null:
		return false
	for wanted in names:
		if _anim.has_animation(wanted):
			if _anim.current_animation != wanted:
				_anim.play(wanted)
			return true
	return false


func _update_animation() -> void:
	if state == State.DEAD:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > WALK_ANIM_SPEED:
		_play_any(["CharacterArmature|Run", "CharacterArmature|Walk", "Run", "Walk"])
	elif speed > 0.5:
		_play_any(["CharacterArmature|Walk", "CharacterArmature|Run", "Walk", "Run"])
	elif state == State.FIGHT:
		_play_any(["CharacterArmature|Idle_Gun_Pointing", "CharacterArmature|Idle_Gun", "Idle_Gun", "Idle"])
	else:
		_play_any(["CharacterArmature|Idle", "Idle"])


# --- death --------------------------------------------------------------------

func _on_died(_from: Node) -> void:
	state = State.DEAD
	_path.clear()
	velocity = Vector3.ZERO
	set_collision_layer_value(2, false)
	$CollisionShape3D.set_deferred("disabled", true)
	if not _play_any(["CharacterArmature|Death", "Death", "Die"]):
		# No death clip: tip the model over so a corpse still reads as one.
		create_tween().tween_property(model, "rotation:x", -PI / 2.0, 0.4)


func is_alive() -> bool:
	return state != State.DEAD and health.is_alive()
