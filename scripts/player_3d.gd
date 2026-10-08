extends CharacterBody3D
## The pirate, in first person. WASD to move, mouse to look, left click to
## shoot, right click to aim. Shift sprints, Ctrl or C crouches, Space jumps
## and clambers, R reloads, V or the mouse's side button melees, E works
## doors, and the mouse wheel turns through the weapons he carries.
##
## Movement is a six-state machine in the feel of Halo Infinite:
##   WALK     default on the floor
##   SPRINT   sprint held with forward input; a shot drops out and latches
##            until the key is released
##   CROUCH   crouch held; the capsule shrinks to 1.2 m at half speed, and
##            standing back up waits for headroom
##   SLIDE    crouch while sprinting on the floor, or within a short grace
##            after it; keeps momentum and eases to walk speed, firing allowed
##   AIR      off the floor; light steering, never past walk speed; a held
##            jump toward a ledge tries a clamber
##   CLAMBER  the one full lockout: the body tweens up and onto a ledge that
##            pure physics found 0.6-1.6 m above the feet, with a camera dip
## The camera work for moves lives here; the Viewmodel above reads `state`,
## `ads` and `flat_speed()` for the weapon's pose and lends this camera work
## its Descope roll.
##
## The Sidearm is a Weapon Profile: every number the gun has lives on the
## resource, and the Pirate only pulls the trigger. Semi-auto, one shot per
## press; a dry magazine reloads on the next pull, not the last shot; the
## reload runs on through every move. Spread is a cone that blooms per shot
## and widens or tightens with what he is doing.
##
## Aim Down Sights is a flag beside the state, valid in WALK, CROUCH and AIR:
## hold aim for the Profile's zoom, slowdown and tighter cone. A sprint,
## slide, clamber, reload or melee lowers it and a jump keeps it. While aim
## stays held the sights come back up by themselves the moment they may:
## after the reload, after the swing, and a short recovery after a hit
## descopes them. Aiming out of a sprint ends the sprint at once and raises
## the sights after a short beat.
##
## The Melee is a lunge: the nearest body in a narrow cone within reach is
## pulled to, faced and struck, and a strike from inside the cone behind the
## target's facing kills outright. With nobody in the cone the swing still
## lands on anything a short ray ahead finds. It ends a sprint and the sights,
## drops a running reload, and is the one thing a clamber refuses outright.

signal died
signal ammo_changed(in_mag: int)
signal fired
## A trigger pull on an empty magazine: the one click before the reload.
signal dry_fired
signal reloading_changed(reloading: bool)
signal reload_started(from_empty: bool)
signal reload_cancelled
## He has a different weapon in hand: a turn of the wheel, or a Profile set
## from outside.
signal weapon_changed(profile: WeaponProfile)
## The live cone half-angle, for the crosshair and the viewmodel.
signal spread_changed(degrees: float)
signal state_changed(from: State, to: State)
## The sights came up, or went down for any reason.
signal ads_changed(on: bool)
## A Descope: a hit knocked the sights down; they recover on their own if aim
## is still held, or at once on a fresh press.
signal descoped
## A swing landed on [param target] (null for a whiff into air) and whether it
## finished them.
signal melee_swung(target: Node3D, killed: bool)
## A shot or a swing hurt something that can be hurt: the hit marker's cue.
signal hit_landed(target: Node3D, killed: bool)

enum State { WALK, SPRINT, CROUCH, SLIDE, AIR, CLAMBER }

const TEAM := &"pirate"

@export_group("Movement")
## Top walking speed in metres per second (was 165 px/s over 32 px tiles).
@export var max_speed: float = 5.16
## Halo Infinite's sprint is barely faster than its walk; the commitment is
## the lowered weapon, not the pace.
@export var sprint_multiplier: float = 1.10
@export var acceleration: float = 43.75
@export var friction: float = 43.75
@export var jump_velocity: float = 4.5
## Fraction of walking acceleration left for steering in the air.
@export var air_control: float = 0.25

@export_group("Crouch and slide")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.2
@export var crouch_speed_multiplier: float = 0.5
@export var slide_time: float = 0.6
## Slide entry speed over the faster of the current speed and a sprint.
@export var slide_boost: float = 1.15
@export var slide_roll_degrees: float = 6.0
## Seconds after leaving SPRINT in which a crouch still starts a slide, so a
## pinky moving from Shift to Ctrl does not lose it.
@export var sprint_grace: float = 0.25

@export_group("Clamber")
## Ledge heights above the feet that can be climbed.
@export var clamber_min: float = 0.6
@export var clamber_max: float = 1.6
@export var clamber_time: float = 0.5
@export var clamber_dip: float = 0.18
## How far ahead of the feet the ledge probe looks.
@export var clamber_reach: float = 0.75

@export_group("Aim Down Sights")
## Seconds from a sprint's lowered weapon to the sights.
@export var ads_raise_time: float = 0.12
## Seconds after a Descope before held aim brings the sights back.
@export var descope_recovery: float = 0.35
## How fast the FOV settles into and out of the zoom.
@export var ads_zoom_speed: float = 14.0

@export_group("Melee")
## The cone a target is picked from, measured on the floor plane.
@export var melee_range: float = 2.0
@export var melee_cone_degrees: float = 30.0
## With nobody in the cone, the swing still lands this far straight ahead.
@export var melee_whiff_reach: float = 1.2
## The lunge pulls him to this gap from the target over this long.
@export var melee_lunge_stop: float = 0.9
@export var melee_lunge_time: float = 0.15
## Movement input ignored after the lunge lands.
@export var melee_input_lock: float = 0.2
@export var melee_damage: int = 3
## A strike from inside this cone behind the target's facing kills outright.
@export var melee_back_cone_degrees: float = 120.0
## Seconds before the next swing, shot or reload.
@export var melee_cycle: float = 0.55

@export_group("Look")
## Radians of turn per pixel of mouse travel.
@export var mouse_sensitivity: float = 0.002
@export var pitch_limit_degrees: float = 89.0

@export_group("Gunnery")
## What he is holding. Swap the resource and every number follows.
@export var weapon: WeaponProfile = preload("res://resources/weapons/sidearm.tres"):
	set(value):
		if value == weapon:
			return
		weapon = value
		if is_node_ready():
			weapon_changed.emit(weapon)
## What he carries, in the order the mouse wheel turns through them.
@export var weapons: Array[WeaponProfile] = [
	preload("res://resources/weapons/sidearm.tres"),
	preload("res://resources/weapons/carbine.tres"),
]
## Seconds a weapon swap keeps the trigger, the sights and the reload busy.
@export var swap_time := 0.4
@export var projectile_scene: PackedScene = preload("res://scenes/projectile_3d.tscn")
## How far ahead the crosshair ray looks for something to converge on.
@export var aim_distance: float = 100.0

## Seconds spent down before getting back up at the entry room.
@export var respawn_delay := 1.5
## Below this height the pirate has left the ship (out through a Hatch, or a
## hole nothing should have) and is put back at the boarding point.
const FALL_LIMIT := -10.0
## How fast the head and camera settle toward their targets.
const CAMERA_LERP := 12.0
## How far short of a wall a bolt starts when the barrel is through it.
const MUZZLE_WALL_GAP := 0.05
## The ship's walls, floors and props: what a crouch or clamber probes.
const WORLD_LAYER := 1
## Bodies that can be hit: the crew and the pirate himself.
const BODY_LAYER := 2

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
## Rides the Viewmodel, so a shot leaves wherever the weapon is posed.
@onready var muzzle: Node3D = $Head/Camera3D/Weapon/Muzzle
@onready var viewmodel: Viewmodel = $Head/Camera3D/Weapon
@onready var audio: PirateAudio = $Audio
@onready var health: Health = $Health
@onready var collider: CollisionShape3D = $CollisionShape3D

## Where he comes back, set by the scene that built the ship.
var spawn_point := Vector3.ZERO
var state: State = State.WALK
## Sights up. Read with `state`: it never replaces one.
var ads := false

var ammo := 0
var _cooldown := 0.0
var _reload_timer := 0.0
var _reload_from_empty := false
var _swap_left := 0.0
## Rounds left in the magazine of each weapon he is not holding.
var _stowed_ammo := {}
## Degrees of spread the last shots added, decaying back to zero.
var _bloom := 0.0
var _last_spread := -1.0
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

var _capsule: CapsuleShape3D
## Eye height as a fraction of capsule height, read from the scene.
var _head_ratio := 1.6 / 1.8
var _head_target_y := 1.6
var _dip := 0.0
var _sprint_latched := false
var _sprint_grace_left := 0.0
var _slide_left := 0.0
var _slide_dir := Vector3.ZERO
var _slide_speed := 0.0
var _clamber_tween: Tween
var _ads_raise_left := 0.0
## Seconds of Descope still keeping held aim down.
var _descope_left := 0.0
var _hip_fov := 75.0
var _melee_cycle_left := 0.0
## Seconds the lunge still owns his movement.
var _melee_lock_left := 0.0
var _lunge_tween: Tween


func _ready() -> void:
	health.died.connect(_on_died)
	ammo = weapon.magazine_size
	# Each pirate gets his own capsule so a crouch never resizes the scene's.
	_capsule = collider.shape.duplicate()
	collider.shape = _capsule
	_head_ratio = head.position.y / stand_height
	_set_capsule(stand_height)
	_hip_fov = camera.fov
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func get_team() -> StringName:
	return TEAM


func is_alive() -> bool:
	return health.is_alive()


## Damage interrupts no move: a hit mid-slide or mid-clamber just lands. It
## does knock the sights down.
func take_damage(amount: int, from: Node = null) -> void:
	health.take_damage(amount, from)
	# A hit on the sights, or on sights still recovering from the last one:
	# every hit of a burst is a Descope and pushes the recovery back.
	if ads or _descope_left > 0.0:
		_lower_sights()
		_descope_left = descope_recovery
		descoped.emit()


## Speed over the floor, whatever the state.
func flat_speed() -> float:
	return _flat_velocity().length()


func _flat_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


## Doors and Containers ask before honouring the interact key.
func can_interact() -> bool:
	return state != State.CLAMBER


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotate_x(-motion.relative.y * mouse_sensitivity)
		var limit := deg_to_rad(pitch_limit_degrees)
		head.rotation.x = clampf(head.rotation.x, -limit, limit)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		# The click that takes the mouse back is not a trigger pull.
		Input.action_release("shoot")
	elif event.is_action_pressed("weapon_next"):
		switch_weapon(1)
	elif event.is_action_pressed("weapon_prev"):
		switch_weapon(-1)


func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT:
		respawn()
		return
	_tick_gunnery_timers(delta)
	_melee_lock_left = maxf(_melee_lock_left - delta, 0.0)
	if state == State.CLAMBER:
		# The tween owns the body; nothing else is read until it lets go.
		_lower_sights()
		_animate_camera(delta)
		_report_spread()
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _melee_lock_left > 0.0:
		# The lunge owns his feet; the sticks are read again once it lets go.
		input = Vector2.ZERO
	var direction := (global_transform.basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.0 else Vector3.ZERO
	var forward_held := input.y < -0.5
	var crouch_held := Input.is_action_pressed("crouch")
	var sprint_held := Input.is_action_pressed("sprint")
	if not sprint_held:
		_sprint_latched = false
	_sprint_grace_left = maxf(_sprint_grace_left - delta, 0.0)

	if not is_on_floor():
		velocity.y -= _gravity * delta
		_set_state(State.AIR)
		if Input.is_action_pressed("jump") and forward_held and _try_clamber():
			return
	else:
		_choose_floor_state(delta, direction, forward_held, crouch_held, sprint_held)
		if state == State.CLAMBER:
			return

	_update_ads(delta)
	_move(delta, direction)

	if Input.is_action_just_pressed("melee"):
		melee()
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("shoot") or (Input.is_action_pressed("shoot") and not weapon.semi_auto):
		fire()

	_animate_camera(delta)
	_report_spread()
	move_and_slide()


## The floor states and the moves that leave them.
func _choose_floor_state(delta: float, direction: Vector3, forward_held: bool,
		crouch_held: bool, sprint_held: bool) -> void:
	if state == State.AIR:
		# Crouch held on landing goes straight down; so does a landing under
		# something too low to stand beneath.
		_set_state(State.CROUCH if crouch_held or not can_stand() else State.WALK)

	if Input.is_action_just_pressed("jump"):
		# A ledge in reach is climbed instead of jumped at. A slide-jump keeps
		# the slide's momentum into the air.
		if _try_clamber():
			return
		velocity.y = jump_velocity
		_set_state(State.AIR)
		return

	match state:
		State.SLIDE:
			_slide_left -= delta
			if _slide_left <= 0.0 or not crouch_held or direction.dot(_slide_dir) < -0.5:
				var next := State.CROUCH if crouch_held else State.WALK
				if not crouch_held and _wants_sprint(sprint_held, forward_held):
					next = State.SPRINT
				_set_state(next)
		State.CROUCH:
			if not crouch_held and can_stand():
				_set_state(State.WALK)
		State.SPRINT:
			if crouch_held:
				_start_slide(direction)
			elif not _wants_sprint(sprint_held, forward_held):
				_set_state(State.WALK)
		State.WALK:
			if crouch_held:
				if _sprint_grace_left > 0.0:
					_start_slide(direction)
				else:
					_set_state(State.CROUCH)
			elif _wants_sprint(sprint_held, forward_held):
				_set_state(State.SPRINT)


func _wants_sprint(sprint_held: bool, forward_held: bool) -> bool:
	return sprint_held and forward_held and not _sprint_latched


func _move(delta: float, direction: Vector3) -> void:
	var flat := _flat_velocity()
	match state:
		State.SLIDE:
			# Holds its speed, then sheds it: the curve the prototype locked.
			var t := 1.0 - _slide_left / slide_time
			flat = _slide_dir * lerpf(_slide_speed, max_speed, ease(t, 2.0))
		State.AIR:
			# Light steering: turn what he has, never build past walk speed.
			if direction != Vector3.ZERO:
				var speed := maxf(flat.length(), max_speed)
				flat = flat.move_toward(direction * speed, acceleration * air_control * delta)
		State.SPRINT:
			flat = _walk(flat, direction, sprint_multiplier, delta)
		State.CROUCH:
			flat = _walk(flat, direction, crouch_speed_multiplier, delta)
		_:
			flat = _walk(flat, direction, 1.0, delta)
	velocity.x = flat.x
	velocity.z = flat.z


func _walk(flat: Vector3, direction: Vector3, multiplier: float, delta: float) -> Vector3:
	if ads:
		multiplier *= weapon.ads_speed
	if direction != Vector3.ZERO:
		return flat.move_toward(direction * max_speed * multiplier, acceleration * delta)
	return flat.move_toward(Vector3.ZERO, friction * delta)


## Where the sights may be up: on the floor or in the air, but never
## committed to a move or a magazine swap.
func _ads_allowed() -> bool:
	return state in [State.WALK, State.CROUCH, State.AIR] and not is_reloading() and not is_meleeing() \
			and not is_swapping()


## The newer input wins between aim and sprint: pressing aim ends a sprint,
## and starting a sprint drops the sights. Held aim raises the sights
## whenever they are allowed and no Descope is still recovering; a fresh
## press skips the recovery.
func _update_ads(delta: float) -> void:
	# The Descope recovers on the clock, whatever else he is doing.
	_descope_left = maxf(_descope_left - delta, 0.0)
	var want := Input.is_action_pressed("aim")
	if Input.is_action_just_pressed("aim"):
		_descope_left = 0.0
		if state == State.SPRINT:
			# The sprint ends at once; the sights need the raise first.
			_end_sprint_latched()
			_ads_raise_left = ads_raise_time
	if not want:
		_descope_left = 0.0
		_lower_sights()
	elif not _ads_allowed():
		_lower_sights()
	elif not ads:
		if _descope_left > 0.0:
			return
		_ads_raise_left = maxf(_ads_raise_left - delta, 0.0)
		if _ads_raise_left == 0.0:
			_set_ads(true)


func _set_ads(on: bool) -> void:
	if ads == on:
		return
	ads = on
	ads_changed.emit(on)


## Sights down and any raise abandoned.
func _lower_sights() -> void:
	_ads_raise_left = 0.0
	_set_ads(false)


func _set_state(next: State) -> void:
	if next == state:
		return
	var from := state
	state = next
	if from == State.SPRINT and next == State.WALK:
		_sprint_grace_left = sprint_grace
	# The air keeps whatever stance he left the floor in; landing sets it.
	if next == State.CROUCH or next == State.SLIDE:
		_set_capsule(crouch_height)
	elif next != State.AIR:
		_set_capsule(stand_height)
	state_changed.emit(from, next)


func _set_capsule(height: float) -> void:
	_capsule.height = height
	collider.position.y = height / 2.0
	_head_target_y = height * _head_ratio


## A shot out of a sprint ends it and latches it until the key is released.
func _end_sprint_latched() -> void:
	_sprint_latched = true
	_set_state(State.WALK)


func _start_slide(direction: Vector3) -> void:
	var flat := _flat_velocity()
	if flat.length_squared() > 0.01:
		_slide_dir = flat.normalized()
	elif direction != Vector3.ZERO:
		_slide_dir = direction
	else:
		_slide_dir = -global_transform.basis.z
	_slide_speed = maxf(flat.length(), max_speed * sprint_multiplier) * slide_boost
	_slide_left = slide_time
	_set_state(State.SLIDE)


## True when there is room to stand up from a crouch where he is.
func can_stand() -> bool:
	return _world_ray(global_position + Vector3.UP * (crouch_height - 0.05),
			global_position + Vector3.UP * stand_height).is_empty()


## What the ship has between two points, the pirate's own body excepted.
func _world_ray(from: Vector3, to: Vector3) -> Dictionary:
	return _ray(from, to, WORLD_LAYER)


## The first thing on [param mask] along the crosshair, out to [param reach].
func _view_ray(reach: float, mask: int) -> Dictionary:
	var from := camera.global_position
	return _ray(from, from - camera.global_transform.basis.z * reach, mask)


func _ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, mask)
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(params)


## [param v] dropped onto the floor plane and normalised; zero stays zero.
static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized()


## The ledge in front of the feet as {height, target, crouched}, or empty.
## The ship marks nothing: this is pure physics against layer 1, the GridMap
## walls and floors and the props' StaticBodies.
func find_ledge() -> Dictionary:
	var forward := _flat(-global_transform.basis.z)
	var feet := global_position
	var ahead := feet + forward * clamber_reach
	# Something must block the way at chest height.
	if _world_ray(feet + Vector3.UP * 0.5, ahead + Vector3.UP * 0.5).is_empty():
		return {}
	# Its top must lie inside the band: a ray dropped from just above it.
	var top := _world_ray(ahead + Vector3.UP * (clamber_max + 0.3), ahead + Vector3.UP * (clamber_min - 0.3))
	if top.is_empty():
		return {}
	var height: float = top.position.y - feet.y
	if height < clamber_min or height > clamber_max:
		return {}
	# And there must be room on top to stand, or at least to crouch.
	var land: Vector3 = top.position + forward * 0.15
	var crouched := false
	if not _world_ray(land + Vector3.UP * 0.05, land + Vector3.UP * stand_height).is_empty():
		if not _world_ray(land + Vector3.UP * 0.05, land + Vector3.UP * crouch_height).is_empty():
			return {}
		crouched = true
	return {height = height, target = land, crouched = crouched}


func _try_clamber() -> bool:
	var ledge := find_ledge()
	if ledge.is_empty():
		return false
	_set_state(State.CLAMBER)
	velocity = Vector3.ZERO
	_dip = clamber_dip
	var target: Vector3 = ledge.target
	var rise := Vector3(global_position.x, target.y, global_position.z)
	_clamber_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_clamber_tween.tween_property(self, "global_position", rise, clamber_time * 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_clamber_tween.tween_property(self, "global_position", target, clamber_time * 0.4) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_clamber_tween.tween_callback(_finish_clamber.bind(ledge.crouched))
	return true


func _finish_clamber(crouched: bool) -> void:
	_clamber_tween = null
	_set_state(State.CROUCH if crouched else State.WALK)
	# Refresh the floor contact now, or the next frame reads the new perch as
	# a fall and stands him up under whatever he ducked beneath.
	velocity = Vector3.ZERO
	move_and_slide()


func _animate_camera(delta: float) -> void:
	var zoom := weapon.ads_zoom if ads else 1.0
	var fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(_hip_fov) / 2.0) / zoom))
	camera.fov = lerpf(camera.fov, fov, ads_zoom_speed * delta)
	_dip = move_toward(_dip, 0.0, clamber_dip / maxf(clamber_time, 0.01) * delta)
	head.position.y = lerpf(head.position.y, _head_target_y - _dip, CAMERA_LERP * delta)
	var roll := deg_to_rad(slide_roll_degrees) if state == State.SLIDE else 0.0
	roll += deg_to_rad(viewmodel.descope_roll)
	camera.rotation.z = lerpf(camera.rotation.z, roll, CAMERA_LERP * delta)


func _tick_gunnery_timers(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_swap_left = maxf(_swap_left - delta, 0.0)
	_melee_cycle_left = maxf(_melee_cycle_left - delta, 0.0)
	if weapon.bloom_decay_seconds > 0.0:
		_bloom = maxf(_bloom - weapon.bloom_per_shot_degrees / weapon.bloom_decay_seconds * delta, 0.0)
	else:
		_bloom = 0.0
	if _reload_timer > 0.0:
		_reload_timer = maxf(_reload_timer - delta, 0.0)
		if _reload_timer == 0.0:
			ammo = weapon.magazine_size
			ammo_changed.emit(ammo)
			reloading_changed.emit(false)


func is_reloading() -> bool:
	return _reload_timer > 0.0


## Begins a magazine swap unless one is running, the magazine is full, or the
## weapon is busy with a clamber or a swing. A dry magazine takes the longer,
## racked reload.
func start_reload() -> void:
	if is_reloading() or ammo == weapon.magazine_size or state == State.CLAMBER or is_meleeing() or is_swapping():
		return
	_reload_from_empty = ammo == 0
	_reload_timer = weapon.reload_empty if _reload_from_empty else weapon.reload_tactical
	_lower_sights()
	reloading_changed.emit(true)
	reload_started.emit(_reload_from_empty)


func is_swapping() -> bool:
	return _swap_left > 0.0


## The next weapon he carries, [param step] places round the wheel. Each
## keeps the rounds it had; the swap drops a running reload and the sights,
## and holds the trigger for `swap_time`. Refused mid-clamber and mid-swing.
func switch_weapon(step: int) -> void:
	if weapons.is_empty() or state == State.CLAMBER or is_meleeing():
		return
	var next: WeaponProfile = weapons[posmod(weapons.find(weapon) + step, weapons.size())]
	if next == weapon:
		return
	cancel_reload()
	_lower_sights()
	_stowed_ammo[weapon] = ammo
	_swap_left = swap_time
	_bloom = 0.0
	ammo = _stowed_ammo.get(next, next.magazine_size)
	weapon = next
	ammo_changed.emit(ammo)


## Drops a running reload with nothing gained: the hook a melee and a weapon
## swap use.
func cancel_reload() -> void:
	if not is_reloading():
		return
	_reload_timer = 0.0
	reloading_changed.emit(false)
	reload_cancelled.emit()


## The cone half-angle a shot would scatter inside right now.
func spread_degrees() -> float:
	var multiplier: float
	match state:
		State.CROUCH:
			multiplier = weapon.spread_crouch
		State.SLIDE:
			multiplier = weapon.spread_slide
		State.AIR:
			multiplier = weapon.spread_air
		_:
			multiplier = weapon.spread_walking if flat_speed() > 0.5 else weapon.spread_still
	if ads:
		multiplier *= weapon.ads_spread
	return (weapon.spread_base_degrees + _bloom) * multiplier


func _report_spread() -> void:
	var spread := spread_degrees()
	if not is_equal_approx(spread, _last_spread):
		_last_spread = spread
		spread_changed.emit(spread)


## The world point under the crosshair: whatever the camera ray hits, or a spot
## far along the view axis when it hits nothing.
func aim_point() -> Vector3:
	var hit := _view_ray(aim_distance, WORLD_LAYER | BODY_LAYER)
	if not hit.is_empty():
		return hit.position
	return camera.global_position - camera.global_transform.basis.z * aim_distance


## One trigger pull. Returns the shot, or null when the pull did something
## else or nothing: a clamber ignores it, a sprint is ended by it, a reload,
## a swing or the interval swallows it, and a dry magazine spends it on the
## reload.
func fire() -> Projectile3D:
	if state == State.CLAMBER:
		return null
	if state == State.SPRINT:
		_end_sprint_latched()
		return null
	if _cooldown > 0.0 or projectile_scene == null or is_reloading() or is_meleeing() or is_swapping():
		return null
	if ammo <= 0:
		dry_fired.emit()
		start_reload()
		return null
	_cooldown = weapon.fire_interval
	ammo -= 1
	ammo_changed.emit(ammo)

	var origin := _shot_origin()
	var direction := _scatter((aim_point() - origin).normalized())
	var shot: Projectile3D = projectile_scene.instantiate()
	shot.speed = weapon.projectile_speed
	shot.lifetime = weapon.projectile_lifetime
	shot.damage = weapon.damage
	shot.launch(origin, direction, self, TEAM)
	shot.hit.connect(_on_shot_hit)
	_shot_parent().add_child(shot)
	_bloom += weapon.bloom_per_shot_degrees
	fired.emit()
	return shot


## Where a bolt starts: the tip of the barrel as it is drawn. A barrel poked
## into a wall he is standing against starts the bolt on his side of it.
func _shot_origin() -> Vector3:
	var eye := camera.global_position
	var origin := viewmodel.muzzle_point()
	var wall := _world_ray(eye, origin)
	if not wall.is_empty():
		origin = wall.position + (eye - wall.position).normalized() * MUZZLE_WALL_GAP
	return origin


## The bolt struck [param target]: a hit if it could be hurt, and a kill if
## that finished it.
func _on_shot_hit(target: Node3D) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var killed: bool = target.has_method("is_alive") and not target.is_alive()
	hit_landed.emit(target, killed)


## A random yaw and pitch inside the live cone, applied to the aim.
func _scatter(direction: Vector3) -> Vector3:
	var cone := deg_to_rad(spread_degrees())
	var yaw := _rng.randf_range(-cone, cone)
	var pitch := _rng.randf_range(-cone, cone)
	return direction.rotated(Vector3.UP, yaw) \
			.rotated(camera.global_transform.basis.x, pitch).normalized()


## --- Melee ---

func is_meleeing() -> bool:
	return _melee_cycle_left > 0.0


## One swing. Refused mid-clamber and inside the cycle of the last one. It
## ends a sprint (latched) and the sights, drops a running reload, then either
## lunges at the target in the cone and strikes on arrival, or strikes at once
## whatever the whiff ray finds ahead.
func melee() -> void:
	if state == State.CLAMBER or is_meleeing():
		return
	_melee_cycle_left = melee_cycle
	cancel_reload()
	_lower_sights()
	if state == State.SPRINT:
		_end_sprint_latched()
	var target := melee_target()
	if target == null:
		var swept := _whiff_target()
		if swept != null:
			_strike(swept)
		else:
			melee_swung.emit(null, false)
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var direction := _flat(to)
	rotation.y = atan2(-direction.x, -direction.z)
	var stop := global_position + direction * maxf(to.length() - melee_lunge_stop, 0.0)
	velocity.x = 0.0
	velocity.z = 0.0
	_melee_lock_left = melee_lunge_time + melee_input_lock
	_lunge_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_lunge_tween.tween_property(self, "global_position", stop, melee_lunge_time) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_callback(_land_lunge.bind(target))


func _land_lunge(target: Node3D) -> void:
	_lunge_tween = null
	_strike(target)


## The blow: 3 from the front, a kill from inside the cone behind the target.
func _strike(target: Node3D) -> void:
	if not is_instance_valid(target):
		melee_swung.emit(null, false)
		return
	var amount := melee_damage
	if _is_behind(target):
		var target_health := target.get_node_or_null("Health") as Health
		if target_health != null:
			amount = maxi(target_health.current, amount)
	target.take_damage(amount, self)
	var killed: bool = target.has_method("is_alive") and not target.is_alive()
	hit_landed.emit(target, killed)
	melee_swung.emit(target, killed)


## The attacker stands inside the back cone of the target's facing.
func _is_behind(target: Node3D) -> bool:
	var facing := _flat(-target.global_transform.basis.z)
	var offset := _flat(global_position - target.global_position)
	if facing == Vector3.ZERO or offset == Vector3.ZERO:
		return false
	return rad_to_deg((-facing).angle_to(offset)) <= melee_back_cone_degrees / 2.0


## The body a swing would lunge at: something with `take_damage` on the body
## layer, not his own team, inside the cone on the floor plane and within
## reach, nearest the crosshair. Null when the cone is empty.
func melee_target() -> Node3D:
	var shape := SphereShape3D.new()
	shape.radius = melee_range
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), global_position + Vector3.UP * stand_height / 2.0)
	query.collision_mask = BODY_LAYER
	query.exclude = [get_rid()]
	var forward := _flat(-global_transform.basis.z)
	var best: Node3D = null
	var best_angle := INF
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
		var body := hit.collider as Node3D
		if not _can_strike(body):
			continue
		var to: Vector3 = body.global_position - global_position
		to.y = 0.0
		if to.length() > melee_range or to.length_squared() < 0.0001:
			continue
		var angle := rad_to_deg(forward.angle_to(_flat(to)))
		if angle <= melee_cone_degrees / 2.0 and angle < best_angle:
			best_angle = angle
			best = body
	return best


## What a swing into an empty cone still connects with: the first body a
## short ray from the eyes finds, such as one a hair outside the cone.
func _whiff_target() -> Node3D:
	var hit := _view_ray(melee_whiff_reach, BODY_LAYER)
	if hit.is_empty():
		return null
	var body := hit.collider as Node3D
	return body if _can_strike(body) else null


func _can_strike(body: Node3D) -> bool:
	if body == null or not body.has_method("take_damage"):
		return false
	return not (body.has_method("get_team") and body.get_team() == TEAM)


## Shots live beside the ship, not under the pirate, so they do not ride his
## transform around the room.
func _shot_parent() -> Node:
	var container := get_tree().get_first_node_in_group(&"projectiles")
	return container if container != null else get_parent()


func _on_died(_from: Node) -> void:
	died.emit()
	velocity = Vector3.ZERO
	visible = false
	set_physics_process(false)
	collider.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_delay).timeout
	respawn()


func respawn() -> void:
	if _clamber_tween != null:
		_clamber_tween.kill()
		_clamber_tween = null
	if _lunge_tween != null:
		_lunge_tween.kill()
		_lunge_tween = null
	health.reset()
	global_position = spawn_point
	velocity = Vector3.ZERO
	visible = true
	ammo = weapon.magazine_size
	_stowed_ammo.clear()
	_swap_left = 0.0
	_reload_timer = 0.0
	_cooldown = 0.0
	_bloom = 0.0
	_sprint_latched = false
	_sprint_grace_left = 0.0
	_dip = 0.0
	_descope_left = 0.0
	_melee_cycle_left = 0.0
	_melee_lock_left = 0.0
	_lower_sights()
	# Silence first: the state reset below must not sound like a landing.
	audio.reset()
	_set_state(State.WALK)
	head.position.y = _head_target_y
	viewmodel.reset()
	camera.rotation.z = 0.0
	camera.fov = _hip_fov
	ammo_changed.emit(ammo)
	collider.set_deferred("disabled", false)
	set_physics_process(true)
