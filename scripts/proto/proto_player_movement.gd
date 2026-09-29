extends "res://scripts/player_3d.gd"
## PROTOTYPE — the pirate's movement state machine (issue #32).
##
## Replaces the base player's `_physics_process` with six states and camera
## work only: no weapon animation beyond a lower on sprint. Every number is a
## knob the walk scene sets from the command line. Throwaway.
##
## States
##   WALK    default on the floor
##   SPRINT  sprint held + moving forward; weapon lowered; fire drops you out
##   CROUCH  crouch held; capsule shrinks, head drops, speed halves
##   SLIDE   crouch pressed while SPRINTing on the floor; keeps momentum,
##           eases to walk speed over slide_time; firing allowed
##   AIR     off the floor; jump held near a ledge tries a clamber
##   CLAMBER locked; position tweens up then forward; camera dips

enum State { WALK, SPRINT, CROUCH, SLIDE, AIR, CLAMBER }
const STATE_NAMES := ["WALK", "SPRINT", "CROUCH", "SLIDE", "AIR", "CLAMBER"]

## --- Knobs (the walk scene overwrites these from args) ---
var k_sprint_mult := 1.10
var k_sprint_fov := 0.0
var k_crouch_height := 1.2
var k_crouch_speed_mult := 0.5
var k_slide_time := 0.6
var k_slide_boost := 1.15
var k_slide_tilt_deg := 6.0
var k_clamber_min := 0.6
var k_clamber_max := 1.6
var k_clamber_time := 0.5
var k_clamber_dip := 0.18
## How far ahead of the feet the ledge probe looks.
var k_probe_dist := 0.75
## Clamber only while the jump button is held (Halo's auto clamber is the
## `false` case: any airborne approach to a ledge mantles).
var k_clamber_needs_jump_held := true

const STAND_HEIGHT := 1.8
const HEAD_RATIO := 1.6 / 1.8
const CAM_LERP := 12.0

var state: State = State.WALK
var base_fov := 75.0
var _capsule: CapsuleShape3D
var _collider: CollisionShape3D
var _weapon: Node3D
var _weapon_rest := Vector3.ZERO
var _slide_timer := 0.0
var _slide_dir := Vector3.ZERO
var _slide_speed := 0.0
var _sprint_latched := false   # fire cancelled sprint; needs a fresh press
var _clamber_tween: Tween
var _head_target_y := 1.6
var _dip := 0.0
## Debug readout for the walk scene's label.
var last_probe := "no probe yet"
var last_event := ""


func _ready() -> void:
	super()
	_collider = $CollisionShape3D
	_capsule = _collider.shape.duplicate()
	_collider.shape = _capsule
	_weapon = $Head/Camera3D/Weapon
	_weapon_rest = _weapon.position
	base_fov = camera.fov
	if not InputMap.has_action("crouch"):
		InputMap.add_action("crouch")
		for code in [KEY_CTRL, KEY_C]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event("crouch", ev)


func state_name() -> String:
	return STATE_NAMES[state]


func flat_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT:
		respawn()
		return
	if state == State.CLAMBER:
		_animate_camera(delta)
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction := (global_transform.basis * Vector3(input.x, 0.0, input.y))
	direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.0 else Vector3.ZERO
	var forward_held := input.y < -0.5
	var crouch_held := Input.is_action_pressed("crouch")
	var sprint_held := Input.is_action_pressed("sprint")
	if not sprint_held:
		_sprint_latched = false
	var firing := Input.is_action_pressed("shoot") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if firing and state == State.SPRINT:
		_sprint_latched = true
		_set_state(State.WALK, "fire cancelled sprint")

	# --- pick the state ---
	if not is_on_floor():
		velocity.y -= _gravity * delta
		if state != State.AIR:
			_set_state(State.AIR, "left the floor")
		if (Input.is_action_pressed("jump") or not k_clamber_needs_jump_held) and forward_held:
			_try_clamber()
			if state == State.CLAMBER:
				return
	else:
		if state == State.AIR:
			_set_state(State.CROUCH if crouch_held else State.WALK, "landed")
		if Input.is_action_just_pressed("jump") and state != State.SLIDE:
			if not _try_clamber():
				velocity.y = jump_velocity
				_set_state(State.AIR, "jumped")
		elif state == State.SLIDE:
			_slide_timer -= delta
			if _slide_timer <= 0.0 or not crouch_held or direction.dot(_slide_dir) < -0.5:
				var next := State.CROUCH if crouch_held else State.WALK
				if not crouch_held and sprint_held and forward_held and not _sprint_latched:
					next = State.SPRINT
				_set_state(next, "slide ended")
		elif crouch_held:
			if state == State.SPRINT:
				_start_slide(direction)
			else:
				_set_state(State.CROUCH, "crouch held")
		elif state == State.CROUCH:
			if _can_stand():
				_set_state(State.WALK, "stood up")
		elif sprint_held and forward_held and not _sprint_latched and not firing:
			_set_state(State.SPRINT, "sprint held")
		elif state == State.SPRINT and not (sprint_held and forward_held):
			_set_state(State.WALK, "sprint released")

	# --- move ---
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	match state:
		State.SLIDE:
			var t := 1.0 - _slide_timer / k_slide_time
			var speed := lerpf(_slide_speed, max_speed, ease(t, 2.0))
			flat = _slide_dir * speed
		State.AIR:
			# Halo air control is light: steer, never accelerate past walk.
			if direction != Vector3.ZERO:
				flat = flat.move_toward(direction * maxf(flat.length(), max_speed), acceleration * 0.25 * delta)
		_:
			var mult := 1.0
			if state == State.SPRINT:
				mult = k_sprint_mult
			elif state == State.CROUCH:
				mult = k_crouch_speed_mult
			if direction != Vector3.ZERO:
				flat = flat.move_toward(direction * max_speed * mult, acceleration * delta)
			else:
				flat = flat.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = flat.x
	velocity.z = flat.z

	# --- gunnery, unchanged from the base pirate ---
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _reload_timer > 0.0:
		_reload_timer = maxf(_reload_timer - delta, 0.0)
		if _reload_timer == 0.0:
			ammo = magazine_size
			ammo_changed.emit(ammo)
			reloading_changed.emit(false)
	if Input.is_action_just_pressed("reload"):
		start_reload()
	if firing and state != State.SPRINT:
		fire()

	_animate_camera(delta)
	move_and_slide()


func _set_state(next: State, why: String) -> void:
	if next == state:
		return
	last_event = "%s -> %s (%s)" % [STATE_NAMES[state], STATE_NAMES[next], why]
	state = next
	var crouched := next == State.CROUCH or next == State.SLIDE
	_set_capsule(k_crouch_height if crouched else STAND_HEIGHT)


func _set_capsule(height: float) -> void:
	_capsule.height = height
	_collider.position.y = height / 2.0
	_head_target_y = height * HEAD_RATIO


func _can_stand() -> bool:
	var from := global_position + Vector3.UP * (k_crouch_height - 0.05)
	var to := global_position + Vector3.UP * STAND_HEIGHT
	var params := PhysicsRayQueryParameters3D.create(from, to, 1)
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(params).is_empty()


func _start_slide(direction: Vector3) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	_slide_dir = flat.normalized() if flat.length_squared() > 0.01 else (direction if direction != Vector3.ZERO else -global_transform.basis.z)
	_slide_speed = maxf(flat.length(), max_speed * k_sprint_mult) * k_slide_boost
	_slide_timer = k_slide_time
	_set_state(State.SLIDE, "crouched while sprinting")


## Finds a ledge in front of the feet and returns {height, target, crouched},
## or an empty Dictionary. The ship marks nothing: this is pure physics against
## layer 1 (GridMap walls and floors, prop StaticBodies).
func _find_ledge() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var feet := global_position
	var ahead := feet + fwd * k_probe_dist
	# 1. Something must block the way at knee-to-chest height.
	var chest := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.5, ahead + Vector3.UP * 0.5, 1)
	chest.exclude = [get_rid()]
	if space.intersect_ray(chest).is_empty():
		last_probe = "nothing in front"
		return {}
	# 2. Drop a ray from above the max onto whatever is ahead.
	var down := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * (k_clamber_max + 0.3), ahead + Vector3.UP * (k_clamber_min - 0.3), 1)
	down.exclude = [get_rid()]
	var top := space.intersect_ray(down)
	if top.is_empty():
		last_probe = "front blocked, no top within band"
		return {}
	var height: float = top.position.y - feet.y
	if height < k_clamber_min or height > k_clamber_max:
		last_probe = "ledge %.2f m: outside %.1f–%.1f" % [height, k_clamber_min, k_clamber_max]
		return {}
	# 3. Room to stand (or at least crouch) on top.
	var land: Vector3 = top.position + fwd * 0.15
	var crouched := false
	var stand := PhysicsRayQueryParameters3D.create(land + Vector3.UP * 0.05, land + Vector3.UP * STAND_HEIGHT, 1)
	if not space.intersect_ray(stand).is_empty():
		var crouch := PhysicsRayQueryParameters3D.create(land + Vector3.UP * 0.05, land + Vector3.UP * k_crouch_height, 1)
		if not space.intersect_ray(crouch).is_empty():
			last_probe = "ledge %.2f m: no headroom on top" % height
			return {}
		crouched = true
	last_probe = "ledge %.2f m: OK%s" % [height, " (lands crouched)" if crouched else ""]
	return {height = height, target = land, crouched = crouched}


func _try_clamber() -> bool:
	var ledge := _find_ledge()
	if ledge.is_empty():
		return false
	_set_state(State.CLAMBER, "ledge %.2f m" % ledge.height)
	velocity = Vector3.ZERO
	_dip = k_clamber_dip
	_lower_weapon(true)
	var target: Vector3 = ledge.target
	var up_first := Vector3(global_position.x, target.y, global_position.z)
	_clamber_tween = create_tween()
	_clamber_tween.tween_property(self, "global_position", up_first, k_clamber_time * 0.6).set_ease(Tween.EASE_OUT)
	_clamber_tween.tween_property(self, "global_position", target, k_clamber_time * 0.4).set_ease(Tween.EASE_IN_OUT)
	_clamber_tween.tween_callback(func() -> void:
		var crouched: bool = ledge.crouched
		_set_state(State.CROUCH if crouched else State.WALK, "clamber done")
		_lower_weapon(false))
	return true


func _lower_weapon(lowered: bool) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_weapon, "position", _weapon_rest + (Vector3(0.05, -0.12, 0.05) if lowered else Vector3.ZERO), 0.15)
	tw.tween_property(_weapon, "rotation_degrees", Vector3(-35, 0, 15) if lowered else Vector3.ZERO, 0.15)


var _weapon_lowered := false

func _animate_camera(delta: float) -> void:
	var lowered := state == State.SPRINT or state == State.CLAMBER
	if lowered != _weapon_lowered:
		_weapon_lowered = lowered
		_lower_weapon(lowered)
	var fov_target := base_fov + (k_sprint_fov if state == State.SPRINT else 0.0)
	camera.fov = lerpf(camera.fov, fov_target, CAM_LERP * delta)
	_dip = move_toward(_dip, 0.0, k_clamber_dip / maxf(k_clamber_time, 0.01) * delta)
	head.position.y = lerpf(head.position.y, _head_target_y - _dip, CAM_LERP * delta)
	var tilt := deg_to_rad(k_slide_tilt_deg) if state == State.SLIDE else 0.0
	camera.rotation.z = lerpf(camera.rotation.z, tilt, CAM_LERP * delta)
