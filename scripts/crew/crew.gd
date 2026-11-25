class_name Crew3D
extends CharacterBody3D
## Hostile crew: patrols its room, builds Awareness of the pirate through a
## forward sight cone ([CrewPerception]), comes to look when suspicious,
## hunts him once spotted, and fights from cover -- shoot a burst, duck
## behind something to reload, lean back out. The whole system is written up
## in `CREW_AI.md` beside this file.
##
## A straight port of the 2D crew onto the XZ plane. Movement between rooms
## rides the door graph via [ShipNavigator]; inside a room [CrewPaths] bends
## any leg a prop would block round it, and a crew member that gets nowhere
## re-routes or steps aside ([method _watch_progress]). Cover is worked out
## by raycast at the moment it is needed rather than baked into the layout.
## Sight rays run at eye height; the cover ray runs lower, at the height of
## someone tucked down behind a crate.
##
## Each crew member dresses at spawn in its type's rig, the Soldier for
## Guards and the Engineer for Workers, stood `RIG_HEIGHT` tall on the floor
## under `Model`; the rigs share one skeleton and Quaternius's clip names,
## which the brain plays by state.

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
## A Worker with the Pirate this close and in sight is cornered: it cowers
## where it is rather than run.
const CORNERED_RANGE := 3.0
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
## Seconds a crew member runs for its cover point before giving up on
## reaching it (the way blocked by the Pirate, another body or a prop) and
## holding where it is.
const COVER_GIVE_UP := 3.0
## A crew member trying to walk that moves less than UNSTICK_MOVE metres in
## UNSTICK_AFTER seconds is stuck and works itself loose: re-routes, then
## steps SIDESTEP metres aside.
const UNSTICK_AFTER := 1.0
const UNSTICK_MOVE := 0.3
const SIDESTEP := 1.0
## Stuck against another crew member (centres closer than GIVE_WAY_NEAR,
## it ahead): go round it if the floor allows; else, both walking, one gives
## way, stepping off the other's way and waiting there until the other has
## walked GIVE_WAY_PASSED metres on, stopped, or GIVE_WAY_WAIT seconds are up.
## Which one is fixed (see [method _gives_way]); after GIVE_WAY_INSIST tries
## still blocked, either will.
const GIVE_WAY_NEAR := 1.0
const GIVE_WAY_PASSED := 2.0
const GIVE_WAY_WAIT := 5.0
const GIVE_WAY_INSIST := 8
## How fast the body turns to face where it is looking, radians a second.
const TURN_RATE := 6.0

const TEAM := &"crew"
## Layer 1 is the ship itself: hull, props and shut doors.
const WORLD_LAYER := 1

## Where the sight ray leaves and arrives, in metres off the floor.
const EYE_HEIGHT := 1.5
## Cover only counts if it hides someone crouched this high.
const COVER_HEIGHT := 0.9
## Shots leave here, this far ahead of the body, and are aimed at the
## target's torso. Where the gun sits on the body, not a gun number.
const MUZZLE_HEIGHT := 1.3
const MUZZLE_FORWARD := 0.625
const TORSO_HEIGHT := 1.0
## The muzzle line is tested as a ball this wide (a bolt's 0.09 m overlap
## sphere and a hair), stopping this short of the target's centre (his
## capsule's 0.35 m radius and a margin).
const MUZZLE_BALL := 0.1
const MUZZLE_TARGET_GAP := 0.4
## How far out from the muzzle the edges of its spread must be clear too.
const MUZZLE_NEAR := 1.5
static var _bolt_ball := _ball(MUZZLE_BALL)
## A spot it moves to for a clear shot is at least this far from where it
## stands, so it steps out from cover rather than shuffling against it.
const FIRING_STEP := 1.0
## Metres off the Pirate a Guard opens fire from, whatever its gun, until
## the cover ticket of the crew-combat spec replaces FIGHT.
const ENGAGE_RANGE := 10.6

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
## What a Guard fires: one of the Pirate's four bare weapons, the same live
## Resource, rolled by [ShipBuilder3D] ([GunRoll]); the Pistol unless set.
## A Sandbox sheet edit reaches crew shots too. Crew read its damage,
## projectile, pellets, time between shots, sounds and loudness, and ignore
## its magazine, reloads, bloom, Aim Down Sights, recoil and Viewmodel: they
## fire a burst and pause. A Worker carries nothing: null from spawn.
@export var weapon: WeaponProfile = preload("res://resources/weapons/pistol.tres")
## How a Guard handles it ([Gunnery]): aim error, shots per burst, time
## down. Left empty, it is the weapon's own at spawn; a Worker has none.
@export var gunnery: Gunnery
@export var projectile_scene: PackedScene = preload("res://scenes/projectile_3d.tscn")
## How loud their shot rings at the muzzle. What it sounds like is the
## weapon's own shot sounds, and distance does the rest.
@export var shot_volume_db := -3.0

@export_group("Sandbox")
## Health at spawn, shared with the Pirate and the Sandbox sheet.
@export var sandbox: Sandbox = preload("res://resources/sandbox.tres")

@export_group("Look")
## The bodies crew wear: the first for Workers, the second for Guards.
@export var rigs: Array[PackedScene] = [
	preload("res://assets/models/crew/engineer.glb"),
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
## Set once this crew member's body has been found and reported, so the
## crew raise nothing over it twice.
var reported := false
## It fell without having spotted the Pirate: a stealth kill.
var died_unaware := false
## The trace this crew member is walking to look at ([CrewTraces]).
var _trace: Node3D
var _trace_timer := 0.0
## Traces this crew member gave up on reaching: it does not keep going back.
var abandoned_traces: Array[Node3D] = []
## A Worker running to raise the Alarm over a trace does not stop to hide.
var _no_hiding := false
## Chance this Worker hides rather than runs; [constant HIDE_CHANCE] unless
## a test wants it certain.
var hide_chance := HIDE_CHANCE
var home_room := 0
var target: Node3D
var state := State.PATROL

@onready var model: Node3D = $Model
@onready var health: Health = $Health
## Its head, riding the rig's head bone: a bolt that strikes it is a
## Headshot. Null only for a rig without a head bone.
var head_zone: HeadZone

var _path: Array[Vector3] = []
var _aim := Vector3.FORWARD
var _shots_left := 0
var _shot_timer := 0.0
var _reload_timer := 0.0
## This crew member's own rhythm, drawn at spawn over its weapon's base
## values: a multiplier on the time between shots.
var _gap_jitter := 1.0
## Shots in the burst it is on: drawn from its Gunnery's shots per burst
## as each burst starts; 0 for a Worker.
var burst_length := 0
## The projectiles of its last shot: one, or a Shotgun's pellets.
var last_pellets: Array[Projectile3D] = []
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
## Seconds since it ducked for cover, for giving up on a cover point it
## cannot reach.
var _cover_clock := 0.0
## In FIGHT, walking to a spot it picked because its muzzle line was blocked.
var _stepping_out := false
## Where it last made progress along its path, how long since, and how many
## times in a row it has had to work itself loose ([method _watch_progress]).
var _stuck_at := Vector3.INF
var _stuck_clock := 0.0
var _stuck_tries := 0
## Giving way: the crew member it stepped aside for, how many points at the
## front of its path are still the walk to its spot, where the other stood
## then, and how long ago that was.
var _yield_to: Crew3D
var _yield_left := 0
var _yield_from := Vector3.ZERO
var _yield_clock := 0.0
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _anim: AnimationPlayer


func _ready() -> void:
	health.died.connect(_on_died)
	apply_sandbox()
	if target == null:
		target = get_tree().get_first_node_in_group(&"player")
	# Seeded off the global RNG (randomized at launch) so a test can replay it.
	_rng.seed = randi()
	if is_worker():
		# Workers are unarmed.
		weapon = null
		gunnery = null
	elif gunnery == null:
		gunnery = Gunnery.for_weapon(weapon)
	_gap_jitter = CrewCombat.jitter(_rng)
	cover_hold_time *= CrewCombat.jitter(_rng)
	_new_burst()
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
	var skeletons := rig.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		head_zone = HeadZone.attach(skeletons[0], self)
	if head_zone == null:
		push_warning("%s: the rig has no %s bone, so no head zone" % [name, HeadZone.BONE])


## Workers wear the first rig, Guards the second. A rig list of one serves
## both.
func _rig_for(type: CrewTypes.Type) -> PackedScene:
	if rigs.size() < 2:
		return rigs[0]
	return rigs[0] if type == CrewTypes.Type.WORKER else rigs[1]


func is_worker() -> bool:
	return crew_type == CrewTypes.Type.WORKER

func get_team() -> StringName:
	return TEAM


## Takes Health from the Sandbox, full: at spawn, and when the Sandbox sheet
## changes it mid-Raid on anyone still standing.
## Degrees either side a shot may stray before aim tightens
## ([method CrewCombat.spread]): the weapon's base cone plus its Gunnery's
## aim error.
func base_cone_degrees() -> float:
	if weapon == null:
		return 0.0
	return weapon.spread_base_degrees + (gunnery.aim_error_degrees if gunnery != null else 0.0)


## Metres off the Pirate this crew member opens fire from:
## [constant ENGAGE_RANGE], whatever its gun.
func engage_range() -> float:
	return ENGAGE_RANGE


## Starts a fresh burst: its Gunnery's shots per burst, drawn.
func _new_burst() -> void:
	burst_length = gunnery.draw_shots(_rng) if gunnery != null else 0
	_shots_left = burst_length


func apply_sandbox() -> void:
	health.max_health = sandbox.crew_health
	health.reset()


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
		State.FLEE:
			if _cornered():
				_enter(State.COWER)
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

	var waiting := _waiting_to_pass(delta)
	_steer(delta, waiting)
	_open_doors_ahead()
	_close_doors_behind()
	move_and_slide()
	if waiting:
		_stuck_at = global_position
		_stuck_clock = 0.0
	else:
		_watch_progress(delta)
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

	_look_for_traces(delta)
	var crouched: bool = target.has_method("is_crouched") and target.is_crouched()
	if _in_view:
		_noticed_at = target.global_position
	# The gun in his hands: a Laser's dot makes him easier to notice.
	var held: WeaponProfile = target.get("weapon") as WeaponProfile
	var conspicuous := held.conspicuous if held != null else 1.0
	if perception.sense(delta, _in_view, distance, crouched, conspicuous):
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


## Every so often, a look round for something the Pirate left behind. A new
## one makes it suspicious and sends it to look.
func _look_for_traces(delta: float) -> void:
	_trace_timer -= delta
	if _trace_timer > 0.0:
		return
	_trace_timer = CrewTraces.LOOK_EVERY
	var found := CrewTraces.spot(self)
	if found == null or found == _trace:
		return
	_trace = found
	_noticed_at = found.global_position
	perception.awareness = maxf(perception.awareness, CrewTraces.AWARENESS)
	if state == State.INVESTIGATE:
		_repath_to(_noticed_at)
		_hold_timer = INVESTIGATE_LINGER


## Reached a trace: report it, once. A serious one (a body, the boarding
## Hatch) sends a Worker to raise the Alarm (or to a Guard once it is up)
## and a Guard hunting from there, telling the others; for the Hatch, the
## hunt goes into the Pirate's Boarding Pod. A minor one (an emptied
## Container, a Door left open) puts it On Edge: it shuts the Door, a Guard
## searches about, a Worker goes back to work.
func _report(trace: Node3D) -> void:
	_trace = null
	if not CrewTraces.is_trace(trace):
		return
	trace.set("reported", true)
	perception.on_edge = true
	_last_seen = trace.global_position
	_seen_ago = 0.0
	if trace is Door3D:
		var door := trace as Door3D
		if door.is_hatch():
			var pod := get_tree().get_first_node_in_group(&"boarding_pod") as BoardingPod
			if pod != null:
				_last_seen = pod.spawn_point()
		else:
			door.close(self)
	if not CrewTraces.serious(trace):
		# Awareness is left to drain on its own: a minor trace never calms
		# a crew member already suspicious of something else.
		_enter(State.PATROL if is_worker() else State.SEARCH)
	elif is_worker():
		_no_hiding = true
		_enter(State.FLEE)
		_no_hiding = false
	else:
		perception.awareness = 1.0
		_enter(State.HUNT)
		CrewCombat.share(self, _last_seen)


## Which way this crew member is looking, flat.
func facing() -> Vector3:
	return -global_basis.z


func _in_combat() -> bool:
	return state in [State.HUNT, State.FIGHT, State.COVER, State.FLEE, State.COWER]


## Just spotted him: a Guard hunts him; a Worker runs, unless he is right
## on top of it, when it cowers where it is.
func _react_spotted() -> void:
	if not is_worker():
		_enter(State.HUNT)
		_share_timer = CrewCombat.SHARE_EVERY
		CrewCombat.share(self, _last_seen)
	elif _cornered():
		_enter(State.COWER)
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
func _blocked(from: Vector3, to: Vector3, ignore: Node = null) -> bool:
	var params := PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER)
	var skip: Array[RID] = [get_rid()]
	if ignore is CollisionObject3D:
		skip.append((ignore as CollisionObject3D).get_rid())
	# Assigned whole: appending to params.exclude edits a copy.
	params.exclude = skip
	return not get_world_3d().direct_space_state.intersect_ray(params).is_empty()


## True when a point is inside the hull or a prop, so nobody can stand there.
func _solid(point: Vector3) -> bool:
	var params := PhysicsPointQueryParameters3D.new()
	params.position = point + Vector3.UP * 0.5
	params.collision_mask = WORLD_LAYER
	return not get_world_3d().direct_space_state.intersect_point(params, 1).is_empty()


static func _ball(radius: float) -> SphereShape3D:
	var ball := SphereShape3D.new()
	ball.radius = radius
	return ball


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# --- states -------------------------------------------------------------------

func _enter(next: State) -> void:
	state = next
	_stop_giving_way()
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
			_stepping_out = false
			_new_burst()
			# A beat before the first shot, different every time.
			_shot_timer = _rng.randf_range(0.05, 0.35)
		State.COVER:
			_cover_clock = 0.0
			var spot := _find_cover_point()
			if spot != Vector3.INF:
				_repath_to(spot)
			else:
				_path.clear()
			_hold_timer = cover_hold_time
		State.FLEE:
			_flee_panel = null
			_flee_to = null
			if not _no_hiding and _rng.randf() < hide_chance:
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
## speed, Room to random Room, pausing briefly to look about in each, and
## gives up on a Room it has not reached in JOB_GIVE_UP.
func _tick_sweep() -> void:
	_speed_scale = 1.0
	job_phase = JobPhase.WALKING
	if not _path.is_empty():
		_walk_clock += get_physics_process_delta_time()
		if _walk_clock <= JOB_GIVE_UP:
			return
		# A Room it cannot get to (a Worker hiding in the doorway): another.
		_path.clear()
	if _hold_timer > 0.0:
		_glance()
		return
	_repath_to(_random_point_in_room(_rng.randi_range(0, layout.rooms.size() - 1)))
	_walk_clock = 0.0
	_hold_timer = SWEEP_PAUSE


## Sets off for the current Job. A patrol stop whose centre is blocked
## moves to any free spot in that Room; a work Job whose spot is blocked, or
## held by another crew member ([method _spot_taken]), is skipped. With
## every spot held it waits where it is a moment and tries again; with
## nothing reachable at all it just wanders its Post.
func _start_job() -> void:
	var spot := Vector3.INF
	var held := false
	for _try in routine.jobs.size():
		var job := routine.current()
		if not _solid(job.at) and (job.patrol or not _spot_taken(job.at)):
			spot = job.at
			break
		if job.patrol:
			spot = _random_point_in_room(job.room)
			break
		held = held or not _solid(job.at)
		routine.advance()
	if spot == Vector3.INF and held:
		_path.clear()
		job_phase = JobPhase.WAITING
		_hold_timer = _rng.randf_range(1.0, 3.0)
		return
	if spot == Vector3.INF:
		spot = _random_point_in_room(home_room)
	_repath_to(spot)
	job_phase = JobPhase.WALKING
	_walk_clock = 0.0


## Another crew member is on its way to, or working at, the work spot
## [param at]: a prop has one spot, so it is theirs until they move on.
func _spot_taken(at: Vector3) -> bool:
	for node in get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == self or other.state != State.PATROL or other.routine == null \
				or not other.job_phase in [JobPhase.WALKING, JobPhase.WORKING]:
			continue
		var job := other.routine.current()
		if job != null and not job.patrol and job.at.distance_to(at) < 0.1:
			return true
	return false


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
	if is_instance_valid(_trace) and not CrewTraces.is_trace(_trace):
		# Someone else got there first: nothing left to look at.
		_trace = null
	if is_instance_valid(_trace):
		if _flat_distance(global_position, _trace.global_position) <= CrewTraces.REACH:
			_report(_trace)
			return
		if _walk_clock <= INVESTIGATE_GIVE_UP * 2.0:
			# Something to look at: stays suspicious until it gets there.
			perception.awareness = maxf(perception.awareness, CrewPerception.SUSPICIOUS + 0.05)
		else:
			abandoned_traces.append(_trace)
			_trace = null
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
	_path = CrewPaths.route(layout, global_position, route)
	flanking = true
	_flank_clock = 0.0


func _tick_hunt() -> void:
	if flanking:
		_flank_clock += get_physics_process_delta_time()
		if _can_see and _flat_distance(global_position, target.global_position) <= engage_range():
			_enter(State.FIGHT)
		elif _path.is_empty() or _flank_clock > CrewCombat.FLANK_GIVE_UP:
			# Arrived, or given up: back to hunting him the straight way.
			flanking = false
			_repath_to(_last_seen)
		return
	if _can_see and _flat_distance(global_position, target.global_position) <= engage_range():
		_enter(State.FIGHT)
		return
	if _seen_ago > lose_target_after:
		_enter(State.SEARCH)
		return
	if _repath_timer <= 0.0:
		_repath_to(_last_seen)


func _tick_fight() -> void:
	if is_worker():
		# Unarmed: nothing to fight with.
		_enter(State.COWER)
		return
	if _seen_ago > lose_target_after:
		_enter(_lost_state())
		return

	# Stepping out to a spot it chose for a clear shot, it goes all the way
	# rather than firing the moment its line clears by a hair.
	var stepping := _stepping_out and not _path.is_empty()
	if _can_see and not stepping and not _muzzle_blocked():
		_stepping_out = false
		_path.clear()
		_aim = (target.global_position + Vector3.UP * TORSO_HEIGHT
				- (global_position + Vector3.UP * MUZZLE_HEIGHT)).normalized()
		if _shots_left > 0:
			if _shot_timer <= 0.0:
				if _shots_left == burst_length:
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

	# Lost the angle but not the scent, or its eyes see over cover its
	# muzzle would hit: hold fire and move somewhere with a shot.
	if _path.is_empty():
		var spot := _find_firing_position()
		_stepping_out = _can_see and spot != Vector3.INF
		_repath_to(spot if spot != Vector3.INF else _last_seen)


func _tick_cover() -> void:
	if _seen_ago > lose_target_after:
		_enter(_lost_state())
		return
	_cover_clock += get_physics_process_delta_time()
	if not _path.is_empty():
		if _cover_clock < COVER_GIVE_UP:
			return  # still getting there
		_path.clear()  # the way is blocked: hold here instead
	if _hold_timer > 0.0 or _reload_timer > 0.0:
		return  # tucked in, reloading
	_enter(State.FIGHT)


## A Worker running to the nearest Guard to raise it; it hides on arrival,
## and cowers where it is if cornered on the way.
func _tick_flee() -> void:
	if _cornered():
		_enter(State.COWER)
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


## Tucked behind cover, cornered or not, and once nothing has been seen for
## a while creeps back to its routine.
func _tick_cower() -> void:
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

func _steer(delta: float, waiting := false) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if _path.is_empty() or waiting:
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
	else:
		var point: Vector3 = _path[0]
		if _flat_distance(global_position, point) <= arrive_radius:
			_path.pop_front()
			_yield_left = maxi(_yield_left - 1, 0)
		else:
			var direction := point - global_position
			direction.y = 0.0
			direction = direction.normalized()
			flat = flat.move_toward(direction * max_speed * _speed_scale, acceleration * delta)
	velocity.x = flat.x
	velocity.z = flat.z


## Trying to walk but getting nowhere: UNSTICK_MOVE in UNSTICK_AFTER
## seconds. The first time it re-routes from where it stands (round the
## props it may have been pushed against). After that, with another crew
## member in its way, it gets past it ([method _get_past]); with anything
## else no route knows of (the Pirate), it steps aside, a side at a time, and
## walks on. A Job it still cannot reach is given up at JOB_GIVE_UP.
func _watch_progress(delta: float) -> void:
	if _path.is_empty():
		_stuck_tries = 0
	if _path.is_empty() or _flat_distance(global_position, _stuck_at) > UNSTICK_MOVE:
		_stuck_at = global_position
		_stuck_clock = 0.0
		return
	_stuck_clock += delta
	if _stuck_clock < UNSTICK_AFTER:
		return
	_stuck_clock = 0.0
	_stuck_tries += 1
	if _yield_to != null:
		# Blocked on the way to the spot it was stepping to: wait here instead.
		_path = _path.slice(_yield_left)
		_yield_left = 0
		return
	if _stuck_tries == 1 and layout != null:
		_path = CrewPaths.route(layout, global_position, _path)
		return
	var other := _crew_in_way()
	if other != null and layout != null:
		_get_past(other)
		return
	var ahead := _path[0] - global_position
	ahead.y = 0.0
	if ahead.length_squared() < 0.0001:
		return
	var side := ahead.normalized().cross(Vector3.UP) * (1.0 if _stuck_tries % 2 == 0 else -1.0)
	for turn in [1.0, -1.0]:
		var spot: Vector3 = global_position + side * turn * SIDESTEP
		if layout == null or CrewPaths.clear(CrewPaths.grid(layout), global_position, spot):
			_path.push_front(spot)
			# Not straight back onto the old line by a periodic re-path.
			_repath_timer = UNSTICK_AFTER
			return


## The nearest living crew member ahead of it within GIVE_WAY_NEAR, or null.
func _crew_in_way() -> Crew3D:
	var ahead := _path[0] - global_position
	ahead.y = 0.0
	var best: Crew3D = null
	var best_distance := GIVE_WAY_NEAR
	for node in get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other == null or other == self or not other.is_alive():
			continue
		var to_other := other.global_position - global_position
		to_other.y = 0.0
		var distance := to_other.length()
		if distance < best_distance and to_other.dot(ahead) > 0.0:
			best = other
			best_distance = distance
	return best


## Stuck against [param other]. One standing still: it goes round it over
## open floor if there is a way, else asks it to make way
## ([method make_way_for]) and waits. Two walking into each other: only one
## of them acts ([method _acts_first]), going round the other if it can,
## else stepping off its way to wait for it to pass.
func _get_past(other: Crew3D) -> void:
	var detour := CrewPaths.route_around(layout, global_position, _path, _bodies_near())
	if not other.is_walking():
		if not detour.is_empty():
			_path = detour
			_repath_timer = UNSTICK_AFTER
		else:
			other.make_way_for(self)
		return
	if other._yield_to == self:
		return  # it is stepping aside for this one
	var spot: Array[Vector3] = []
	if detour.is_empty():
		spot = CrewPaths.make_way(layout, global_position, other._way(), _bodies_near())
		if spot.is_empty():
			return  # nothing it can do: the other's to act
	if not _acts_first(other):
		return
	if not detour.is_empty():
		_path = detour
		_repath_timer = UNSTICK_AFTER
		return
	_yield_to = other
	_yield_from = other.global_position
	_yield_clock = 0.0
	_yield_left = spot.size()
	spot.append_array(_path)
	_path = spot
	_repath_timer = GIVE_WAY_WAIT


## Asked by [param walker], which it stands in the way of with no way
## round: a crew member on routine working at a prop or waiting steps off the
## walker's way and waits there as one giving way does; one that was working
## then walks back to its spot and works its Job again from the start.
## Anyone else (chatting, hiding, fighting, already giving way) stays put.
## Returns whether it moved.
func make_way_for(walker: Crew3D) -> bool:
	if state != State.PATROL or routine == null or _yield_to != null or layout == null \
			or not job_phase in [JobPhase.WORKING, JobPhase.WAITING]:
		return false
	var spot := CrewPaths.make_way(layout, global_position, walker._way(), _bodies_near())
	if spot.is_empty():
		return false
	_path.clear()
	if job_phase == JobPhase.WORKING:
		var job := routine.current()
		_path.append(job.at if not job.patrol else Vector3(global_position.x, 0.0, global_position.z))
		job_phase = JobPhase.WALKING
		_walk_clock = 0.0
	_yield_to = walker
	_yield_from = walker.global_position
	_yield_clock = 0.0
	_yield_left = spot.size()
	spot.append_array(_path)
	_path = spot
	return true


## Of two walking crew blocking each other, which acts, so they never mirror
## each other. Called only on one that can act (go round or step aside):
## it does if the other cannot, and of two that both can, the one created
## first (lower instance id), always the same one of the pair. Stuck
## GIVE_WAY_INSIST tries, it acts whenever it can.
func _acts_first(other: Crew3D) -> bool:
	if _stuck_tries >= GIVE_WAY_INSIST or get_instance_id() < other.get_instance_id():
		return true
	return not other._can_get_past(self)


## Whether, blocked by [param other], it has a way round or somewhere off
## the other's way to step to.
func _can_get_past(other: Crew3D) -> bool:
	var bodies := _bodies_near()
	return not CrewPaths.route_around(layout, global_position, _path, bodies).is_empty() \
			or not CrewPaths.make_way(layout, global_position, other._way(), bodies).is_empty()


## Walking somewhere, not stood giving way.
func is_walking() -> bool:
	return is_alive() and not _path.is_empty() and _yield_to == null


## Where it is and the next few points it is walking to.
func _way() -> Array[Vector3]:
	var way: Array[Vector3] = [Vector3(global_position.x, 0.0, global_position.z)]
	way.append_array(_path.slice(0, 3))
	return way


## Where the other living crew within a few metres stand.
func _bodies_near() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for node in get_tree().get_nodes_in_group(&"crew"):
		var other := node as Crew3D
		if other != null and other != self and other.is_alive() \
				and _flat_distance(global_position, other.global_position) < 6.0:
			out.append(other.global_position)
	return out


## Giving way: true while it stands at its spot waiting for the other to go
## by; once the other has walked GIVE_WAY_PASSED on, stopped, or
## GIVE_WAY_WAIT is up, it routes on along what is left of its path.
func _waiting_to_pass(delta: float) -> bool:
	if _yield_to == null:
		return false
	_yield_clock += delta
	var other := _yield_to
	if not _path.is_empty() and is_instance_valid(other) and other.is_walking() \
			and _flat_distance(other.global_position, _yield_from) < GIVE_WAY_PASSED \
			and _yield_clock <= GIVE_WAY_WAIT:
		return _yield_left == 0
	_yield_to = null
	_path = _path.slice(_yield_left)
	_yield_left = 0
	if not _path.is_empty() and layout != null:
		_path = CrewPaths.route(layout, global_position, _path)
	return false


func _stop_giving_way() -> void:
	_yield_to = null
	_yield_left = 0


func _repath_to(destination: Vector3) -> void:
	_repath_timer = 0.5
	_stop_giving_way()
	_path.clear()
	if layout != null and _route_by_pod(destination):
		return
	if layout != null:
		_path.assign(_waypoints(destination))
	if _path.is_empty():
		_path.append(destination)
	if layout != null:
		_path = CrewPaths.route(layout, global_position, _path)


## The door graph's waypoints from here to [param destination]. A doorway
## belongs to no Room, so stood in one it steps onto whichever Room tile
## beside it gives the shorter route first, rather than walking straight
## at the destination through the hull.
func _waypoints(destination: Vector3) -> Array[Vector3]:
	var at := ShipBuilder3D.world_to_tile(global_position)
	if layout.room_at(at) >= 0:
		return ShipNavigator.waypoints_3d(layout, global_position, destination)
	var best: Array[Vector3] = []
	var best_length := INF
	for side: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if layout.room_at(at + side) < 0:
			continue
		var step := ShipBuilder3D.tile_to_world(at + side)
		var legs := ShipNavigator.waypoints_3d(layout, step, destination)
		if legs.is_empty():
			continue
		var length := _flat_distance(global_position, step)
		var cursor := step
		for point in legs:
			length += _flat_distance(cursor, point)
			cursor = point
		if length < best_length:
			best_length = length
			best.assign([step])
			best.append_array(legs)
	return best


## The Pirate's Boarding Pod is in no Room, so the door graph cannot reach
## it: a route into it runs to the boarding Hatch and through, and one out
## of it runs through the Hatch first. False when neither end is in a pod.
func _route_by_pod(destination: Vector3) -> bool:
	var pod := get_tree().get_first_node_in_group(&"boarding_pod") as BoardingPod
	if pod == null or pod.hatch == null:
		return false
	var into := pod.contains(destination)
	var out_of := pod.contains(global_position)
	if into == out_of:
		if into:
			_path.append(destination)
		return into
	var gap := ShipBuilder3D.hatch_center_world(pod.hatch)
	var inside := ShipBuilder3D.hatch_entry_world(layout, pod.hatch)
	if into:
		var legs := ShipNavigator.waypoints_3d(layout, global_position, inside)
		if legs.is_empty():
			legs.append(inside)
		_path = CrewPaths.route(layout, global_position, legs)
		_path.append(gap)
		_path.append(destination)
	else:
		_path.append(gap)
		_path.append(inside)
		var legs := ShipNavigator.waypoints_3d(layout, inside, destination)
		if legs.is_empty():
			legs.append(destination)
		_path.append_array(CrewPaths.route(layout, inside, legs))
	return true


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
	elif not _path.is_empty():
		# Trying to move but blocked (a body in the way): face the way it
		# wants to go, so it sees what is stopping it.
		look = _path[0] - global_position
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

## One shot of its gun: every pellet of it, each thrown inside the cone on
## its own, with the gun's shot sound, action sound and loudness. Returns
## the first projectile ([member last_pellets] holds them all), or null
## unarmed.
func _fire() -> Projectile3D:
	last_pellets.clear()
	if projectile_scene == null or weapon == null or gunnery == null:
		return null
	_shots_left -= 1
	_shot_timer = weapon.fire_interval * _gap_jitter
	if _shots_left <= 0:
		_reload_timer = gunnery.draw_time_down(_rng)

	var cone := CrewCombat.spread(base_cone_degrees(), _exposed_for)
	var origin := global_position + Vector3.UP * MUZZLE_HEIGHT + _aim * MUZZLE_FORWARD
	for i in maxi(weapon.pellet_count, 1):
		var spread := deg_to_rad(_rng.randf_range(-cone, cone))
		var direction := _aim.rotated(Vector3.UP, spread)
		var shot: Projectile3D = projectile_scene.instantiate()
		shot.damage = weapon.damage
		shot.headshot_multiplier = weapon.headshot_multiplier
		shot.speed = weapon.projectile_speed
		shot.lifetime = weapon.projectile_lifetime
		shot.launch(global_position + Vector3.UP * MUZZLE_HEIGHT + direction * MUZZLE_FORWARD, direction, self, TEAM)
		_shot_parent().add_child(shot)
		last_pellets.append(shot)
	if not weapon.shot_sounds.is_empty():
		SoundAt.play(_shot_parent(), origin, weapon.shot_sounds.pick_random(), shot_volume_db, 0.06, "Shot")
	if weapon.action_sound != null:
		_play_action_later(weapon.action_sound, weapon.action_sound_delay)
	CrewNoise.make(get_tree(), global_position, CrewNoise.Kind.GUNSHOT, weapon.loudness, self)
	return last_pellets[0]


## The gun's action (a pump, a bolt) [param delay] seconds after a shot, at
## wherever the body is by then. A connection, not an await, so a body
## freed in between simply plays nothing.
func _play_action_later(sound: AudioStream, delay: float) -> void:
	if delay <= 0.0:
		_play_action(sound)
	else:
		get_tree().create_timer(delay, false).timeout.connect(_play_action.bind(sound))


func _play_action(sound: AudioStream) -> void:
	if is_inside_tree():
		SoundAt.play(_shot_parent(), global_position + Vector3.UP * MUZZLE_HEIGHT, sound, shot_volume_db, 0.06, "Action")


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


## True when the ship stands between the muzzle and the Pirate's torso,
## though its eyes may see over: bolts from here would hit the cover.
func _muzzle_blocked() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return _muzzle_blocked_from(global_position, target.global_position + Vector3.UP * TORSO_HEIGHT)


## The same from a crew member standing at [param at], aiming at [param torso]:
## a ball as wide as a bolt (whose overlap strikes whatever it brushes),
## swept from the body's axis at muzzle height, so a barrel poking into a
## prop counts, to just short of the target's body; and along both edges of
## its spread for the first MUZZLE_NEAR metres, so cover at its shoulder
## does not eat half of every burst.
func _muzzle_blocked_from(at: Vector3, torso: Vector3) -> bool:
	var from := at + Vector3.UP * MUZZLE_HEIGHT
	var reach := from.distance_to(torso) - MUZZLE_TARGET_GAP
	if reach <= 0.0:
		return false
	var along := (torso - from).normalized()
	if _ball_blocked(from, along * reach):
		return true
	var cone := deg_to_rad(CrewCombat.spread(base_cone_degrees(), _exposed_for))
	for side in [-1.0, 1.0]:
		if _ball_blocked(from, along.rotated(Vector3.UP, side * cone) * minf(reach, MUZZLE_NEAR)):
			return true
	return false


## A bolt-wide ball swept from [param from] by [param motion] touches the ship.
func _ball_blocked(from: Vector3, motion: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _bolt_ball
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = motion
	query.collision_mask = WORLD_LAYER
	return get_world_3d().direct_space_state.cast_motion(query)[0] < 1.0


## Somewhere nearby with a clear shot at the pirate.
func _find_firing_position() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.INF
	var aim_at := _last_seen + Vector3.UP * TORSO_HEIGHT
	var best := Vector3.INF
	var best_score := -INF
	for point in _candidate_points():
		if _flat_distance(point, _last_seen) > engage_range():
			continue
		if _flat_distance(point, global_position) < FIRING_STEP:
			continue  # where it stands already has no shot: a real step
		if _muzzle_blocked_from(point, aim_at):
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
	died_unaware = not _in_combat() and not _spotted()
	state = State.DEAD
	_path.clear()
	velocity = Vector3.ZERO
	set_collision_layer_value(2, false)
	$CollisionShape3D.set_deferred("disabled", true)
	if head_zone != null:
		head_zone.disable()
	if not _play_any(["CharacterArmature|Death", "Death", "Die"]):
		# No death clip: tip the model over so a corpse still reads as one.
		create_tween().tween_property(model, "rotation:x", -PI / 2.0, 0.4)


func is_alive() -> bool:
	return state != State.DEAD and health.is_alive()
