class_name Crew3D
extends CharacterBody3D
## Hostile crew: patrols its room, builds Awareness of the pirate through a
## forward sight cone ([CrewPerception]), comes to look when suspicious,
## hunts him once spotted, and a Guard fights from cover ([CrewCover]):
## down behind a prop, a wall or a corner, peeking to fire. The whole system
## is written up in `CREW_AI.md` beside this file.
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

## A Guard's reload began: from a dry gun, or topping up ([CrewMagazine]).
## A reload pose plays from here.
signal reload_started(from_empty: bool)
## A shell is seated in a shell-by-shell reload (the Shotgun).
signal shell_loaded
## The reload is over: full, or [param broken] off to fire (the Shotgun).
signal reload_ended(broken: bool)

## Newer states go last so the older ones keep their numbers.
## COWER is a Worker hiding ([CrewHiding]); REPORT, a Worker come out of
## hiding walking to raise the Alarm or a Guard.
enum State { PATROL, HUNT, FIGHT, COVER, SEARCH, DEAD, INVESTIGATE, FLEE, COWER, REPORT }

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
## A Worker with the Pirate this close and in sight is cornered
## ([method _cornered]): read by the smoke run's bot; Surrender (crew-combat
## ticket 24) is to decide what it does.
const CORNERED_RANGE := 3.0
## Chance a Worker spotting him with the Alarm down freezes and hides rather
## than run to raise it.
const HIDE_CHANCE := 0.25
## A fleeing Worker has reached its Guard this close, and raises it.
const GUARD_REACH := 2.5
## A Worker has reached an Alarm Panel this close to its use spot.
const PANEL_REACH := 0.9
## On Edge, a patrolling Guard pauses this fraction as long at each stop.
const ON_EDGE_PAUSE := 0.5
## Under the Alarm, a sweeping Guard's pause at each Room it checks.
const SWEEP_PAUSE := 1.5
## A crew member trying to walk that moves less than UNSTICK_MOVE metres in
## UNSTICK_AFTER seconds is stuck and works itself loose: re-routes, then
## steps SIDESTEP metres aside.
const UNSTICK_AFTER := 1.0
const UNSTICK_MOVE := 0.3
const SIDESTEP := 1.0
## Out of the fight, blocked by a Guard holding its spot in one with no way
## round, it gives that walk up and stands this many seconds.
const BLOCKED_PAUSE := 1.5
## Stuck against another crew member (centres closer than GIVE_WAY_NEAR,
## it ahead): go round it if the floor allows; else, both walking, one gives
## way, stepping off the other's way and waiting there until the other has
## walked GIVE_WAY_PASSED metres on, stopped, or GIVE_WAY_WAIT seconds are up.
## Which one is fixed (see [method _gives_way]); after GIVE_WAY_INSIST tries
## still blocked, either will.
const GIVE_WAY_NEAR := 1.0
## Stuck this many tries with nobody that near, it looks for one in its way
## out to GIVE_WAY_FAR (a body just past arm's length closing a lane).
const GIVE_WAY_LOOK_FURTHER := 3
const GIVE_WAY_FAR := 1.5
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
## Roughly where a gun is held, metres off the floor and ahead of the
## body: where its action sounds ring, and the muzzle of a crew member with
## no gun model. A Guard's shots leave its gun's own `Muzzle` marker
## ([method aim_muzzle]). Shots are aimed at the target's torso.
const MUZZLE_HEIGHT := 1.3
const MUZZLE_FORWARD := 0.625
const TORSO_HEIGHT := 1.0
## A Guard keeps its gun up in the aimed hold this long after a shot, even
## out of FIGHT (firing on his cover, a break-off shot).
const AIM_HOLD := 0.5
## The muzzle line is tested as a ball this wide (a bolt's 0.09 m overlap
## sphere and a hair), stopping this short of the target's centre (his
## capsule's 0.35 m radius and a margin).
const MUZZLE_BALL := 0.1
const MUZZLE_TARGET_GAP := 0.4
## How far out from the muzzle the edges of its spread must be clear too.
const MUZZLE_NEAR := 1.5
## A pellet straying up or down is kept out of the ship for this far past
## the muzzle ([method _over_own_cover]).
const OWN_COVER := 2.5
static var _bolt_ball := _ball(MUZZLE_BALL)
## Its body's room to stand: the capsule's 0.35 m radius, a hair less.
static var _body_ball := _ball(0.33)
## A spot a Guard fighting in the open moves to for a clear shot is at
## least this far from where it stands, a real step rather than a shuffle.
const FIRING_STEP := 1.0
## A reload's sounds play this high at the Guard's position, metres: its
## hands.
const RELOAD_HEIGHT := 1.0

@export_group("Movement")
@export var max_speed := 3.59
@export var acceleration := 28.0
@export var friction := 34.4
## How close counts as having reached a waypoint.
@export var arrive_radius := 0.44

@export_group("Perception")
@export var vision_range := CrewPerception.SIGHT_RANGE
## Seconds out of sight before a hunting Guard gives up and searches (a
## Guard fighting from cover gives up after [constant CrewCover.UNSEEN_SEARCH]).
@export var lose_target_after := 3.0

@export_group("Gunnery")
## What a Guard fires: one of the Pirate's four bare weapons, the same live
## Resource, rolled by [ShipBuilder3D] ([GunRoll]); the Pistol unless set.
## A Sandbox sheet edit reaches crew shots too. Crew read its damage,
## projectile, pellets, time between shots, sounds and loudness, and ignore
## its magazine, reloads, bloom, Aim Down Sights, recoil and Viewmodel: they
## fire their bursts and go down. A Worker carries nothing: null from spawn.
@export var weapon: WeaponProfile = preload("res://resources/weapons/pistol.tres")
## How a Guard handles it ([Gunnery]): aim error, its rhythm in cover, its
## range band. Left empty, it is the weapon's own at spawn; a Worker has none.
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
## How far a Worker looks for somewhere to cower.
@export var cover_search_radius := 6.9

## Set by [ShipBuilder3D] so the crew can route around its own ship.
var layout: ShipLayout
## Guard or Worker ([CrewTypes]), set by [ShipBuilder3D] from the Post
## Room's Role before the crew member enters the tree.
var crew_type: CrewTypes.Type = CrewTypes.Type.GUARD
## A Guard's cover fight, which drives its FIGHT and COVER states; null
## for a Worker.
var cover: CrewCover
## A Guard's magazine and its reloads; null for a Worker.
var magazine: CrewMagazine
## A Guard's gun, seen in its hands, whose `Muzzle` its shots leave from;
## null for a Worker.
var gun: CrewGun
## A Guard's body in a fight: down, ducking, running low, stepping out
## ([CrewPose]); null for a Worker.
var pose: CrewPose
## The Guard a fleeing Worker is running to.
var _flee_to: Crew3D
## The Alarm Panel a fleeing Worker is running to, instead of a Guard.
var _flee_panel: AlarmPanel
## A Worker's hiding ([CrewHiding]), which drives its COWER state; null for
## a Guard.
var hiding: CrewHiding
## Set while [method _hide] enters COWER after a roll: freeze first.
var _freeze_next := false
var _alarm: ShipAlarm
## The physics frame this crew member last started a burst on, so no two
## start in step ([method CrewCombat.burst_blocked]).
var burst_frame := -1000
## Seconds the Pirate has been in its sight without a break: its spread
## closes with it ([method spread_degrees]). Held, not reset, while it is
## down behind its own cover or stepping out or back (it ducked; he did not
## break sight); reset when he breaks sight, and when he hits it.
var _exposed_for := 0.0
## Bursts it has started in this sighting: the first walks in.
var _sighting_bursts := 0
## The burst it is on walks in, and to which side (+1 right, -1 left).
var _walk_in := false
var _walk_side := 1.0
## Its last shot, before spread: where it was aimed from and at, whether it
## aimed true, whether it was a walk-in round, and for a miss whether he was
## behind cover ("cover") or in the open ("open"), or it fired on the prop
## he hid behind ("prop", [CrewTeam]).
var last_aim_origin := Vector3.ZERO
var last_aim_point := Vector3.ZERO
var last_aimed_true := false
var last_walk_in := false
var last_miss_kind := ""
## Where its next shot goes, set by its habit for that one shot: the
## Marksman Rifle's sight line, fixed before the shot. INF otherwise.
var aim_override := Vector3.INF
## Where its next shot goes as a deliberate miss, never true: the edge of
## the prop he broke sight behind ([CrewTeam]). INF otherwise.
var miss_at := Vector3.INF
## The physics frame it last fired on: a partner up and firing within
## [constant CrewCover.COVER_FIRE] covers a Guard changing cover.
var shot_frame := -1000000
## The physics frame it last racked its gun (the Shotgun's tell).
var _rack_frame := -1000000
var _share_timer := 0.0
## A Guard going round through another Door while another pins him
## ([CrewTeam] picks it), the centre of that Door, and his Room behind it.
var flanking := false
var _flank_door := Vector3.INF
var _flank_room := -1
## It has flanked in this fight: it flanks no more until it loses him.
var flank_done := false
## Set while [method _start_flank] enters HUNT, so entering does not look
## for a flanker again.
var _starting_flank := false
## Hunting where a trace (a body, the open Hatch) says he was, not where
## anyone saw him: today's hunt carries it, into his pod if that is where
## it leads, until it sees him.
var _hunting_trace := false
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
## Crew readied so far in this run, and this one's place among them: who
## gives way to whom, which instance ids (they differ run to run) cannot
## replay.
static var _readied := 0
var _ready_order := 0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _anim: AnimationPlayer


func _ready() -> void:
	health.died.connect(_on_died)
	apply_sandbox()
	if target == null:
		target = get_tree().get_first_node_in_group(&"player")
	# Seeded off the global RNG (randomized at launch) so a test can replay it.
	_rng.seed = randi()
	_readied += 1
	_ready_order = _readied
	if is_worker():
		# Workers are unarmed.
		weapon = null
		gunnery = null
	elif gunnery == null:
		gunnery = Gunnery.for_weapon(weapon)
	if not is_worker():
		magazine = CrewMagazine.new(self)
		cover = CrewCover.new(self)
	else:
		hiding = CrewHiding.new(self)
	_gap_jitter = CrewCombat.jitter(_rng)
	_new_burst()
	_dress()
	if not is_worker():
		# The pose first: the gun is placed from the posed chest.
		pose = CrewPose.fit(self)
		gun = CrewGun.arm(self)
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


## Degrees either side a shot may stray once its aim has closed (1x): the
## weapon's base cone plus its Gunnery's aim error.
## A Marksman Rifle firing from the hip has it doubled ([constant CrewHabit.HIP_CONE]).
func base_cone_degrees() -> float:
	if weapon == null:
		return 0.0
	var cone := weapon.spread_base_degrees + (gunnery.aim_error_degrees if gunnery != null else 0.0)
	if cover != null and cover.hip:
		cone *= CrewHabit.HIP_CONE
	return cone


## Degrees either side a shot strays now: its base cone times the exposure
## ramp, its Gunnery's opening spread (3x) on first sight closing to 1x over
## its closing time (2 s) of unbroken sight. Never under 1x.
func spread_degrees() -> float:
	var base := base_cone_degrees()
	if gunnery == null:
		return base
	var closed := clampf(_exposed_for / gunnery.closing_time, 0.0, 1.0) if gunnery.closing_time > 0.0 else 1.0
	return base * lerpf(maxf(gunnery.opening_spread, 1.0), 1.0, closed)


## Whether it could aim true now: a Guard in the fight with the Pirate in
## sight from its eyes and a clear muzzle line. Judged afresh, at the start
## of a frame, by [CrewFire]. A Guard reloading, or dry on its way to
## reload, takes none (it gave its place up as the reload started). A Shotgun holding its fire takes none; a
## Marksman Rifle firing by its sight line wants one only to start its line
## ([method CrewCover.wants_place]).
func can_aim_true() -> bool:
	if is_worker() or not is_alive() or target == null or not is_instance_valid(target):
		return false
	if magazine != null and not magazine.can_fire():
		return false  # reloading, or dry on its way to reload
	if cover != null and cover.uses_line():
		return cover.wants_place()
	if cover != null and cover.holds_fire():
		return false
	if _flat_distance(global_position, target.global_position) > vision_range:
		return false
	if _blocked(global_position + Vector3.UP * EYE_HEIGHT, target.global_position + Vector3.UP * EYE_HEIGHT):
		return false
	return not _muzzle_blocked()


## Starts a fresh burst: its Gunnery's shots per burst, drawn, capped by
## the rounds left in its magazine.
func _new_burst() -> void:
	burst_length = gunnery.draw_shots(_rng) if gunnery != null else 0
	if magazine != null and magazine.rounds > 0:
		burst_length = mini(burst_length, magazine.rounds)
	_shots_left = burst_length


## Reloading now ([CrewMagazine]): it fires nothing and takes no true-aim
## place until the reload ends.
func is_reloading() -> bool:
	return magazine != null and magazine.reloading


## Holding its gun in the aimed hold ([CrewGun]): fighting (today's FIGHT),
## or within AIM_HOLD of a shot.
func aiming() -> bool:
	return state == State.FIGHT or shot_age() < AIM_HOLD


## Where its shots leave from when it stands at [param at] and aims at
## [param toward]: its gun's `Muzzle` marker in the aimed hold
## ([method CrewGun.muzzle_from]). A crew member with no gun model: muzzle
## height, a little ahead of its axis. The clear-shot test sweeps from here.
func aim_muzzle(at: Vector3, toward: Vector3) -> Vector3:
	if gun != null:
		return gun.muzzle_from(at, toward)
	var flat := Vector3(toward.x - at.x, 0.0, toward.z - at.z)
	var ahead := flat.normalized() if flat.length_squared() > 0.000001 else _aim
	return at + Vector3.UP * MUZZLE_HEIGHT + ahead * MUZZLE_FORWARD


## Takes Health from the Sandbox, full: at spawn, and when the Sandbox sheet
## changes it mid-Raid on anyone still standing.
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
	# Hit: its aim is spoiled, thrown back open to close again; a Marksman
	# Rifle hit during its sight line loses the shot.
	_exposed_for = 0.0
	if cover != null:
		cover.hit()
	# Being shot at from somewhere unseen still tells you roughly where to look.
	if from != null and is_instance_valid(from) and from is Node3D:
		_last_seen = (from as Node3D).global_position
		_seen_ago = 0.0
	if perception.alert():
		_announce_spotted()
	if hiding != null:
		# A Worker shot and alive hides, with no roll, and never comes out.
		hiding.wounded = true
		_hide()
		return
	match state:
		State.PATROL, State.SEARCH, State.INVESTIGATE:
			_react_spotted()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if not is_worker() and target != null and is_instance_valid(target):
		# Who aims true this frame, and what the team does (a flank, fire on
		# his cover), settled before anyone moves or fires.
		CrewFire.of(target).update()
		CrewTeam.of(target).update()
	_update_perception(delta)
	if magazine != null:
		# A reload runs to its end whatever the Guard does meanwhile.
		magazine.tick(delta)
	_shot_timer = maxf(_shot_timer - delta, 0.0)
	_hold_timer = maxf(_hold_timer - delta, 0.0)
	_repath_timer = maxf(_repath_timer - delta, 0.0)
	_glance_timer = maxf(_glance_timer - delta, 0.0)
	_chat_cooldown = maxf(_chat_cooldown - delta, 0.0)

	match state:
		State.PATROL:
			_tick_patrol()
		State.HUNT:
			_tick_hunt()
		State.FIGHT, State.COVER:
			_tick_fight(delta)
		State.SEARCH:
			_tick_search()
		State.INVESTIGATE:
			_tick_investigate()
		State.FLEE:
			_tick_flee()
		State.COWER:
			_tick_cower(delta)
		State.REPORT:
			_tick_report()

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
			_hunting_trace = false
			if hiding != null:
				hiding.noticed()
			_exposed_for += delta
			_share_timer -= delta
			if not is_worker() and _share_timer <= 0.0:
				_share_timer = CrewCombat.SHARE_EVERY
				CrewCombat.share(self, _last_seen)
		else:
			_seen_ago += delta
			if cover == null or not cover.behind_own_cover():
				_break_sight()
		return
	_break_sight()

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


## He broke its sight: its spread opens again and its next burst walks in.
func _break_sight() -> void:
	_exposed_for = 0.0
	_sighting_bursts = 0


## A noise reached this crew member (see [CrewNoise]). Raises Awareness toward
## suspicious, never to spotted, and gives it somewhere to look. Crew shrug
## off their mates' footsteps and doors, not their gunfire. Returns whether
## it took any notice.
func hear(at: Vector3, kind: CrewNoise.Kind, source: Node = null) -> bool:
	if state == State.COWER and hiding != null and not source is Crew3D:
		# A sound of him keeps a hiding Worker hidden ([CrewHiding]). (Workers'
		# poses, crew-combat ticket 25, duck lower at a gunshot here.)
		hiding.noticed()
		return true
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
		# No roll to hide: straight for a panel, or a Guard.
		_enter(State.FLEE)
	else:
		perception.awareness = 1.0
		_enter(State.HUNT)
		_hunting_trace = true
		CrewCombat.share(self, _last_seen, true)


## Which way this crew member is looking, flat.
func facing() -> Vector3:
	return -global_basis.z


func _in_combat() -> bool:
	return state in [State.HUNT, State.FIGHT, State.COVER, State.FLEE, State.COWER]


## Just spotted him: a Guard hunts him. A Worker, with the Alarm down,
## runs for the nearest working Alarm Panel, else the nearest living Guard,
## three times in four, and one time in four freezes 1 s and hides; with
## neither panel nor Guard, or wounded, or with the Alarm up, it hides.
func _react_spotted() -> void:
	if not is_worker():
		_enter(State.HUNT)
		_share_timer = CrewCombat.SHARE_EVERY
		CrewCombat.share(self, _last_seen)
	elif hiding.wounded or _alarm_raised() or (_nearest_panel() == null and _nearest_guard() == null):
		_hide()
	elif hiding.rolls_hide():
		_hide(true)
	else:
		_enter(State.FLEE)


## A Worker goes to hide (COWER), frozen 1 s first when [param freeze]; one
## already hiding carries on.
func _hide(freeze := false) -> void:
	if state == State.COWER or state == State.DEAD:
		return
	_freeze_next = freeze
	_enter(State.COWER)
	_freeze_next = false


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


## True when its body cannot stand at [param point]: the hull or a prop is
## within its capsule's radius there, so it would stop short of the point
## and fire from somewhere else. (A prop the walking grid does not know of
## stops it the same way.)
func _no_room(point: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _body_ball
	params.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.6)
	params.collision_mask = WORLD_LAYER
	return not get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


static func _ball(radius: float) -> SphereShape3D:
	var ball := SphereShape3D.new()
	ball.radius = radius
	return ball


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# --- states -------------------------------------------------------------------

func _enter(next: State) -> void:
	if cover != null and not next in [State.FIGHT, State.COVER]:
		cover.release()
	if hiding != null and next != State.COWER:
		hiding.release()
	state = next
	_stop_giving_way()
	_speed_scale = 1.0
	flanking = false
	_hunting_trace = false
	if next in [State.PATROL, State.SEARCH]:
		flank_done = false
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
			if not _starting_flank:
				_try_flank()
		State.FIGHT, State.COVER:
			# A Guard fights from cover; a Worker has nothing to fight with.
			_path.clear()
			if cover != null:
				_listen_for_shots()
				cover.begin()
		State.FLEE:
			_flee_panel = null
			_flee_to = null
			_pick_flight()
		State.COWER:
			_flee_to = null
			_flee_panel = null
			if hiding != null:
				hiding.begin(_freeze_next)
			else:
				_path.clear()
		State.REPORT:
			_speed_scale = ROUTINE_SPEED
			_pick_report()
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
			_hide()
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
			if _path.is_empty() and not job.patrol and _walk_clock <= JOB_GIVE_UP \
					and _flat_distance(global_position, job.at) > arrive_radius + 0.05:
				# Pushed off the end of its walk (a body passing in a lane):
				# on to the spot itself before working.
				_path.assign([job.at])
			elif _path.is_empty():
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
## with the fresher position. [param from_trace]: only where a trace says
## he was, so it hunts there the old way rather than taking cover from it.
func hear_position(at: Vector3, from_trace := false) -> void:
	if state == State.DEAD or is_worker():
		return
	if state in [State.FIGHT, State.COVER]:
		return
	_last_seen = at
	_seen_ago = 0.0
	perception.awareness = 1.0
	if state != State.HUNT:
		_enter(State.HUNT)
	_hunting_trace = from_trace


## With another Guard already pinning him, one Guard goes round through his
## Room's other Door rather than in behind it: the team picks which, by gun
## ([method CrewTeam.consider_flank]).
func _try_flank() -> void:
	if is_worker() or target == null or not is_instance_valid(target):
		return
	var team := CrewTeam.of(target)
	if team != null:
		team.consider_flank()


## Sets off on a flank: [param route] round to the Door at [param door] into
## his Room [param room], out of the cover fight if it was in it.
func _start_flank(route: Array[Vector3], door: Vector3, room: int) -> void:
	_starting_flank = true
	_enter(State.HUNT)
	_starting_flank = false
	_path = CrewPaths.route(layout, global_position, route)
	flanking = true
	_flank_clock = 0.0
	flank_done = true
	_flank_door = door
	_flank_room = room


## Hunting him the straight way, or going round on a flank. Within
## [constant CrewCover.TAKE_OVER] of where he was last seen, or in his Room
## or one joined to it, and not flanking, it fights from cover instead.
## Radioed in from further off, it runs until then.
func _tick_hunt() -> void:
	if flanking:
		_flank_clock += get_physics_process_delta_time()
		var to_door := _flat_distance(global_position, _flank_door)
		if to_door <= CrewCombat.FLANK_ARRIVE or _path.is_empty() or (_can_see and to_door <= CrewCombat.FLANK_SEE):
			# At the Door it went round to: a cover spot inside it.
			_end_flank()
		elif _can_see:
			_enter(State.FIGHT)
		elif _flank_clock > CrewCombat.FLANK_GIVE_UP:
			# Given up: it takes cover where it stands.
			_enter(State.COVER)
		return
	if cover != null and not _hunting_trace \
			and (CrewCover.takes_over(global_position, _last_seen) or _in_rooms_by(_last_seen)):
		_enter(State.COVER)
		return
	if _seen_ago > lose_target_after:
		_enter(State.SEARCH)
		return
	if _repath_timer <= 0.0:
		_repath_to(_last_seen)


## The flank's end: into the cover fight, on a spot inside the Door it came
## round to, picked by the cover rules ([method CrewCover.begin_flank]).
func _end_flank() -> void:
	var door := _flank_door
	var room := _flank_room
	_enter(State.COVER)
	if cover != null:
		cover.begin_flank(door, room)


## Whether it stands in the Room holding [param at] or one a Door joins to it.
func _in_rooms_by(at: Vector3) -> bool:
	if layout == null:
		return false
	var near := CrewCombat.rooms_near(layout, CrewNoise.rooms_at(layout, at))
	for room in CrewNoise.rooms_at(layout, global_position):
		if room in near:
			return true
	return false


## FIGHT and COVER: a Guard's cover fight ([CrewCover]) drives both. A
## Worker has nothing to fight with and cowers.
func _tick_fight(delta: float) -> void:
	if cover == null:
		_enter(State.COWER)
		return
	cover.tick(delta)


## A Guard hears every shot the Pirate fires, to duck a near miss
## ([method CrewCover.near_miss]).
func _listen_for_shots() -> void:
	if target == null or not is_instance_valid(target) or not target.has_signal(&"fired"):
		return
	if not target.is_connected(&"fired", _on_target_fired):
		target.connect(&"fired", _on_target_fired)


func _on_target_fired() -> void:
	if cover == null or not cover.is_engaged() or not is_alive():
		return
	var camera := target.get("camera") as Camera3D
	if camera == null:
		return
	cover.near_miss(camera.global_position, -camera.global_basis.z)


## A Worker running for an Alarm Panel to raise it, or for the nearest
## Guard to raise it; it hides on arrival. If its Guard dies on the way it
## runs on to the next.
func _tick_flee() -> void:
	if _flee_panel != null:
		if _flee_panel.broken or _alarm_raised():
			# Shot out, or someone beat it there: somewhere else to run.
			_pick_flight()
		elif _flat_distance(global_position, _flee_panel.use_at) <= PANEL_REACH:
			_raise_alarm()
			# (The Alarm itself sends it to hide: see on_alarm.)
			_hide()
		elif _repath_timer <= 0.0:
			_repath_to(_flee_panel.use_at)
		return
	if _flee_to == null or not is_instance_valid(_flee_to) or not _flee_to.is_alive():
		# Its Guard is gone: on to the next one, without a second roll to hide.
		_flee_to = _nearest_guard()
		if _flee_to == null:
			_hide()
		else:
			_repath_to(_flee_to.global_position)
		return
	if _flat_distance(global_position, _flee_to.global_position) <= GUARD_REACH:
		_raise(_flee_to)
		_hide()
		return
	if _repath_timer <= 0.0:
		_repath_to(_flee_to.global_position)


## Hiding ([CrewHiding]): frozen, running to its hiding place, or on it.
## It comes out ([method _come_out]) only with the Alarm down, after
## [constant CrewHiding.COME_OUT] seconds with no sight or sound of him, and
## never once wounded.
func _tick_cower(delta := -1.0) -> void:
	if hiding == null:
		return
	hiding.tick(delta if delta >= 0.0 else get_physics_process_delta_time())


## Out of hiding, On Edge: it walks to the nearest working Alarm Panel or
## Guard to report him (REPORT); with neither it goes back to its routine.
func _come_out() -> void:
	perception.awareness = CrewPerception.SUSPICIOUS * 0.5
	perception.on_edge = true
	if _nearest_panel() == null and _nearest_guard() == null:
		_enter(State.PATROL)
	else:
		_enter(State.REPORT)


## Where a Worker come out of hiding walks to report him: the nearest
## working Alarm Panel, else the nearest living Guard; with neither, back to
## its routine.
func _pick_report() -> void:
	_flee_panel = _nearest_panel()
	_flee_to = null if _flee_panel != null else _nearest_guard()
	if _flee_panel != null:
		_repath_to(_flee_panel.use_at)
	elif _flee_to != null:
		_repath_to(_flee_to.global_position)
	else:
		_enter(State.PATROL)


## Walking On Edge to report him: at a working panel it raises the Alarm
## (which sends it to hide), at a Guard it alerts it to where it last saw
## him; then back to its routine. Spotting him again on the way, it reacts
## as to any spotting.
func _tick_report() -> void:
	if _spotted():
		_react_spotted()
		return
	if _flee_panel != null:
		if _flee_panel.broken:
			_pick_report()
		elif _flat_distance(global_position, _flee_panel.use_at) <= PANEL_REACH:
			_raise_alarm()
			if state == State.REPORT:
				_enter(State.PATROL)
		elif _repath_timer <= 0.0:
			_repath_to(_flee_panel.use_at)
		return
	if _flee_to == null or not is_instance_valid(_flee_to) or not _flee_to.is_alive():
		_pick_report()
		return
	if _flat_distance(global_position, _flee_to.global_position) <= GUARD_REACH:
		_raise(_flee_to)
		_enter(State.PATROL)
	elif _repath_timer <= 0.0:
		_repath_to(_flee_to.global_position)


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
		_hide()
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
## routine stops. A Guard not already fighting hunts there; every Worker
## not already hiding runs to a hiding place, one running for a Guard or
## walking to report included. Everyone is On Edge from now on.
func on_alarm(at: Vector3) -> void:
	if state == State.DEAD:
		return
	perception.on_edge = true
	if is_worker():
		if state in [State.PATROL, State.INVESTIGATE, State.SEARCH, State.REPORT]:
			# It has not seen him: it hides from where the Alarm says he is.
			_last_seen = at
		if state != State.COWER:
			_hide()
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
	if other == null and _stuck_tries >= GIVE_WAY_LOOK_FURTHER:
		other = _crew_in_way(GIVE_WAY_FAR)
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


## The nearest living crew member ahead of it within [param reach]
## (GIVE_WAY_NEAR), or null.
func _crew_in_way(reach := GIVE_WAY_NEAR) -> Crew3D:
	var ahead := _path[0] - global_position
	ahead.y = 0.0
	var best: Crew3D = null
	var best_distance := reach
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
		elif not other.make_way_for(self) and other.state in [State.FIGHT, State.COVER] \
				and not state in [State.FIGHT, State.COVER]:
			# No way round, and the one in the way holds its spot in a fight
			# (down in cover, a Shotgun in ambush) and will not move: out of
			# the fight itself, it gives this walk up and stands a moment
			# before it walks anywhere again.
			_path.clear()
			_hold_timer = maxf(_hold_timer, BLOCKED_PAUSE)
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
## round: a crew member on routine working at a prop or waiting, or one with
## no routine stood still between wanders, steps off the walker's way and
## waits there as one giving way does; one that was working then walks back
## to its spot and works its Job again from the start. Anyone else
## (chatting, hiding, fighting, already giving way) stays put. Returns
## whether it moved.
func make_way_for(walker: Crew3D) -> bool:
	if state != State.PATROL or _yield_to != null or layout == null:
		return false
	if routine == null and not _path.is_empty():
		return false
	if routine != null and not job_phase in [JobPhase.WORKING, JobPhase.WAITING]:
		return false
	var spot := CrewPaths.make_way(layout, global_position, walker._way(), _bodies_near())
	if spot.is_empty():
		return false
	_path.clear()
	if routine != null and job_phase == JobPhase.WORKING:
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
## first (readied first), always the same one of the pair. Stuck
## GIVE_WAY_INSIST tries, it acts whenever it can.
func _acts_first(other: Crew3D) -> bool:
	if _stuck_tries >= GIVE_WAY_INSIST or _ready_order < other._ready_order:
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
## its own, with the gun's shot sound, action sound and loudness. Aimed
## first by fair fire ([CrewFire]): true at him (led, and walking in on the
## first burst of a sighting) or at a miss point beside him; then each
## pellet strays inside its spread ([method spread_degrees]), a real cone.
## A Shotgun shot hurts with at most the Sandbox's pellet cap. Each shot
## spends a round of its magazine; with none in, or reloading, it fires
## nothing. Returns the first projectile ([member last_pellets] holds them
## all), or null unarmed, dry or reloading.
func _fire() -> Projectile3D:
	last_pellets.clear()
	if projectile_scene == null or weapon == null or gunnery == null:
		return null
	if magazine != null:
		if not magazine.can_fire():
			return null
		magazine.spend()
	var in_burst := burst_length - _shots_left
	if in_burst <= 0:
		if miss_at != Vector3.INF:
			# Fire on his cover is no part of a sighting, and never walks in.
			_walk_in = false
		else:
			# The first round of a burst: the first of a sighting walks in.
			_walk_in = _sighting_bursts == 0
			_walk_side = 1.0 if _rng.randf() < 0.5 else -1.0
			_sighting_bursts += 1
	_shots_left -= 1
	shot_frame = Engine.get_physics_frames()
	_shot_timer = weapon.fire_interval * _gap_jitter

	# From its gun's Muzzle in the aimed hold: aimed from where the muzzle
	# will be, then the gun turned onto that point and the shot sent from
	# its marker.
	var toward := target.global_position + Vector3.UP * TORSO_HEIGHT \
			if target != null and is_instance_valid(target) else global_position + _aim
	var from := aim_muzzle(global_position, toward)
	var aim_at := _aim_point(from, maxi(in_burst, 0))
	if gun != null:
		gun.aim_at(aim_at)
		from = gun.muzzle_point()
		last_aim_origin = from
	var along := (aim_at - from).normalized() if aim_at.distance_squared_to(from) > 0.0001 else _aim
	var origin := from
	var cone := spread_degrees()
	var volley := Projectile3D.Volley.new()
	volley.cap = sandbox.shotgun_pellet_cap if sandbox != null and weapon.pellet_count > 1 else -1
	for i in maxi(weapon.pellet_count, 1):
		var direction := _over_own_cover(from, along, CrewFire.scatter(along, cone, _rng), aim_at)
		var shot: Projectile3D = projectile_scene.instantiate()
		shot.damage = weapon.damage
		shot.headshot_multiplier = weapon.headshot_multiplier
		shot.speed = weapon.projectile_speed
		shot.lifetime = weapon.projectile_lifetime
		shot.volley = volley
		shot.launch(from, direction, self, TEAM)
		_shot_parent().add_child(shot)
		last_pellets.append(shot)
	if not weapon.shot_sounds.is_empty():
		SoundAt.play(_shot_parent(), origin, weapon.shot_sounds.pick_random(), shot_volume_db, 0.06, "Shot")
	if weapon.action_sound != null and not CrewHabit.racks(weapon):
		# (A Shotgun racks before its shot instead: [method rack].)
		_play_action_later(weapon.action_sound, weapon.action_sound_delay)
	CrewNoise.make(get_tree(), global_position, CrewNoise.Kind.GUNSHOT, weapon.loudness, self)
	return last_pellets[0]


## [param direction], a pellet's draw inside the cone round [param along],
## kept out of the prop or wall just in front of the muzzle (the low cover it
## fires over): a draw whose first OWN_COVER metres (or less, short of
## [param aim_at]) would strike the ship has its up-and-down stray turned the
## other way, and failing that dropped. A real cone strays down as well as
## sideways, and a Guard holds its gun over its cover, not into it.
func _over_own_cover(from: Vector3, along: Vector3, direction: Vector3, aim_at: Vector3) -> Vector3:
	var reach := minf(OWN_COVER, from.distance_to(aim_at) - MUZZLE_TARGET_GAP)
	if reach <= 0.0 or not _ball_blocked(from, direction * reach):
		return direction
	var right := along.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		return direction
	right = right.normalized()
	var up := right.cross(along).normalized()
	var rise := direction.dot(up)
	var flipped := (direction - up * rise * 2.0).normalized()
	if not _ball_blocked(from, flipped * reach):
		return flipped
	return (direction - up * rise).normalized()


## Where this shot goes before its spread, from the muzzle at [param from],
## round [param in_burst] (from 0) of its burst. Records it in the
## last_aim_* fields.
func _aim_point(from: Vector3, in_burst: int) -> Vector3:
	last_aim_origin = from
	last_walk_in = false
	last_miss_kind = ""
	if target == null or not is_instance_valid(target):
		last_aimed_true = false
		last_aim_point = from + _aim
		return last_aim_point
	var fire := CrewFire.of(target)
	last_aimed_true = fire.aims_true(self)
	if miss_at != Vector3.INF:
		# At the edge of the prop he hid behind: a deliberate miss.
		last_aimed_true = false
		last_miss_kind = "prop"
		last_aim_point = miss_at
		miss_at = Vector3.INF
		return last_aim_point
	if aim_override != Vector3.INF:
		last_aim_point = aim_override
		aim_override = Vector3.INF
		return last_aim_point
	if not last_aimed_true:
		var kind := []
		last_aim_point = fire.miss_point(self, _rng, kind)
		last_miss_kind = kind[0] if not kind.is_empty() else ""
		return last_aim_point
	var at := CrewFire.lead_point(self, from)
	if _walk_in:
		var distance := sandbox.walk_in_distance if sandbox != null else 1.0
		var off := CrewFire.walk_in_offset(in_burst, burst_length, distance)
		if off > 0.0:
			# A round walking in is aimed where the ship does not stand in its
			# way (a door frame or a wall corner beside him): the other side,
			# else at him.
			var across := CrewFire.side_axis(from, at)
			for side: float in [_walk_side, -_walk_side]:
				var aside: Vector3 = at + across * side * off
				var reach := from.distance_to(aside) - MUZZLE_TARGET_GAP
				if reach <= 0.0 or not _ball_blocked(from, (aside - from).normalized() * reach):
					_walk_side = side
					last_walk_in = true
					at = aside
					break
	last_aim_point = at
	return at


## Seconds since its last shot.
func shot_age() -> float:
	return (Engine.get_physics_frames() - shot_frame) / float(Engine.physics_ticks_per_second)


## Racks its gun now: the Profile's action sound at the muzzle, the
## Shotgun's tell before it shows itself ([CrewCover]).
func rack() -> void:
	_rack_frame = Engine.get_physics_frames()
	if weapon != null and weapon.action_sound != null:
		_play_action(weapon.action_sound)


## Seconds since it last racked its gun.
func rack_age() -> float:
	return float(Engine.get_physics_frames() - _rack_frame) / Engine.physics_ticks_per_second


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
## walk to it must be clear. Where a Worker cowers (a Guard's cover is
## [CrewCover]'s).
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
## though its eyes may see over: bolts from here would hit the cover. The
## muzzle is its gun's in the aimed hold ([method aim_muzzle]).
func _muzzle_blocked() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return _muzzle_blocked_from(global_position, target.global_position + Vector3.UP * TORSO_HEIGHT)


## The same from a crew member standing at [param at], aiming at [param torso]:
## a ball as wide as a bolt (whose overlap strikes whatever it brushes),
## swept along the barrel from the body's axis at the muzzle's height to the
## muzzle, so a barrel poking into a prop counts; then from the muzzle,
## where its shots leave, to just short of the target's body; and along
## both edges of its spread for the first MUZZLE_NEAR metres, so cover at
## its shoulder does not eat half of every burst.
func _muzzle_blocked_from(at: Vector3, torso: Vector3) -> bool:
	var from := aim_muzzle(at, torso)
	var axis := Vector3(at.x, from.y, at.z)
	if _ball_blocked(axis, from - axis):
		return true
	var reach := from.distance_to(torso) - MUZZLE_TARGET_GAP
	if reach <= 0.0:
		return false
	var along := (torso - from).normalized()
	if _ball_blocked(from, along * reach):
		return true
	var cone := deg_to_rad(spread_degrees())
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


## Somewhere nearby with a clear shot at the pirate, for a Guard fighting
## in the open ([CrewCover]).
func _find_firing_position() -> Vector3:
	if target == null or not is_instance_valid(target):
		return Vector3.INF
	var aim_at := _last_seen + Vector3.UP * TORSO_HEIGHT
	var best := Vector3.INF
	var best_score := -INF
	# Within its sight of him; a Shotgun, within the range it fires at.
	var reach := vision_range
	if CrewHabit.gun_of(weapon) == CrewHabit.Gun.SHOTGUN:
		reach = minf(reach, CrewHabit.SHOTGUN_HOLD_FIRE)
	for point in _candidate_points():
		if _flat_distance(point, _last_seen) > reach:
			continue
		if _flat_distance(point, global_position) < FIRING_STEP:
			continue  # where it stands already has no shot: a real step
		if _no_room(point):
			continue  # it would stop short, and judge its shot from elsewhere
		if _muzzle_blocked_from(point, aim_at):
			continue
		var score := -_flat_distance(global_position, point)
		if score > best_score:
			best_score = score
			best = point
	return best


## Tile centres in the current room within the search radius, minus any that
## are inside the hull or a prop. Stood in a doorway, both Rooms its Door
## joins; outside every Room, its Post.
func _candidate_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	if layout == null:
		return points
	var rooms := CrewNoise.rooms_at(layout, global_position)
	if rooms.is_empty() and home_room >= 0 and home_room < layout.rooms.size():
		rooms.append(home_room)
	for room in rooms:
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
	if cover != null and cover.stepping():
		# Stepping out from full cover and back: its feet step on their own
		# ([CrewPose]) under a still upper body.
		if state == State.FIGHT:
			_play_any(["CharacterArmature|Idle_Gun_Pointing", "CharacterArmature|Idle_Gun", "Idle_Gun", "Idle"])
		else:
			_play_any(["CharacterArmature|Idle", "Idle"])
	elif speed > WALK_ANIM_SPEED:
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
	if cover != null:
		cover.release()
	if magazine != null:
		magazine.stop()
	state = State.DEAD
	_path.clear()
	velocity = Vector3.ZERO
	set_collision_layer_value(2, false)
	$CollisionShape3D.set_deferred("disabled", true)
	if head_zone != null:
		head_zone.disable()
	if gun != null:
		gun.drop()
	if pose != null:
		pose.active = false
	if not _play_any(["CharacterArmature|Death", "Death", "Die"]):
		# No death clip: tip the model over so a corpse still reads as one.
		create_tween().tween_property(model, "rotation:x", -PI / 2.0, 0.4)


func is_alive() -> bool:
	return state != State.DEAD and health.is_alive()
