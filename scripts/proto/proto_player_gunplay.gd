extends "res://scripts/proto/proto_player_movement.gd"
## PROTOTYPE — pistol, ADS and melee on top of the movement set (issue #36).
##
## Every rule here is the one the map locked (#33, #34, #35); every number is
## a knob the walk scene sets. The viewmodel script on $Head/Camera3D/Weapon
## listens to the signals below and does the animating. Throwaway.

signal ads_changed(on: bool)
signal melee_swung(hit: Node3D, killed: bool)
signal reload_started(from_empty: bool)
signal reload_cancelled
signal descoped

## --- Weapon Profile knobs (the Sidearm) ---
var w_interval := 0.12
var w_magazine := 12
var w_reload_tactical := 1.2
var w_reload_empty := 1.6
var w_speed := 80.0
var w_life := 0.5
var w_damage := 1
var w_spread_base_deg := 1.0
var w_bloom_deg := 0.5
var w_bloom_decay := 0.3
var w_state_mult := {crouch = 0.7, still = 1.0, walking = 1.2, slide = 1.5, air = 1.5}
var w_ads_spread := 0.5
var w_ads_zoom := 1.3
var w_ads_speed := 0.8
## Seconds from sprint-low to sights before ADS takes effect.
var w_ads_raise := 0.2

## --- Melee knobs ---
var m_range := 2.0
var m_cone_deg := 30.0
var m_lunge_stop := 0.9
var m_lunge_time := 0.15
var m_input_lock := 0.2
var m_damage := 3
var m_back_cone_deg := 120.0
var m_cycle := 0.55
var m_whiff_reach := 1.2

var ads := false
var _ads_pending := 0.0
var _bloom := 0.0
var _melee_timer := 0.0
var _melee_lock := 0.0
var _reload_from_empty := false
var last_shot := ""
var last_melee := ""


func _ready() -> void:
	super()
	magazine_size = w_magazine
	ammo = magazine_size
	fire_interval = w_interval
	for a in [["aim", []], ["melee", []]]:
		if not InputMap.has_action(a[0]):
			InputMap.add_action(a[0])
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("aim", rmb)
	var v := InputEventKey.new()
	v.physical_keycode = KEY_V
	InputMap.action_add_event("melee", v)
	var m4 := InputEventMouseButton.new()
	m4.button_index = MOUSE_BUTTON_XBUTTON1
	InputMap.action_add_event("melee", m4)


func _input_locked() -> bool:
	return _melee_lock > 0.0


func _extra_speed_mult() -> float:
	return w_ads_speed if ads else 1.0


func _physics_process(delta: float) -> void:
	_bloom = maxf(_bloom - (w_bloom_deg / w_bloom_decay) * delta, 0.0)
	_melee_timer = maxf(_melee_timer - delta, 0.0)
	_melee_lock = maxf(_melee_lock - delta, 0.0)
	_update_ads(delta)
	if Input.is_action_just_pressed("melee") and state != State.CLAMBER and _melee_timer == 0.0:
		_melee()
	super(delta)


# ---------------------------------------------------------------------------
# ADS
# ---------------------------------------------------------------------------

func _ads_allowed() -> bool:
	return state in [State.WALK, State.CROUCH, State.AIR] and not is_reloading()


func _update_ads(delta: float) -> void:
	var want := Input.is_action_pressed("aim") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if want and state == State.SPRINT:
		# Aim ends the sprint; ADS waits for the raise.
		_sprint_latched = true
		_set_state(State.WALK, "aim ended sprint")
		_ads_pending = w_ads_raise
	if want and not ads and _ads_allowed():
		if _ads_pending > 0.0:
			_ads_pending -= delta
		else:
			_set_ads(true)
	elif ads and (not want or not _ads_allowed()):
		_set_ads(false)
	if not want:
		_ads_pending = 0.0
	var zoom := w_ads_zoom if ads else 1.0
	var target_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) / 2.0) / zoom))
	camera.fov = lerpf(camera.fov, target_fov, 14.0 * delta)


func _set_ads(on: bool) -> void:
	if ads == on:
		return
	ads = on
	ads_changed.emit(on)


func take_damage(amount: int, from: Node = null) -> void:
	super(amount, from)
	if ads:
		_set_ads(false)
		descoped.emit()


# ---------------------------------------------------------------------------
# Pistol
# ---------------------------------------------------------------------------

func spread_deg() -> float:
	var mult: float
	match state:
		State.CROUCH: mult = w_state_mult.crouch
		State.SLIDE: mult = w_state_mult.slide
		State.AIR: mult = w_state_mult.air
		_: mult = w_state_mult.walking if flat_speed() > 0.5 else w_state_mult.still
	if ads:
		mult *= w_ads_spread
	return (w_spread_base_deg + _bloom) * mult


## Semi-auto: the base pirate calls this every frame the button is held; only
## the press counts. A dry magazine reloads on the pull, not on the last shot.
func fire() -> Projectile3D:
	if not Input.is_action_just_pressed("shoot") or state == State.SPRINT or state == State.CLAMBER:
		return null
	if is_reloading() or _melee_timer > 0.0:
		return null
	if ammo <= 0:
		start_reload()
		return null
	if _cooldown > 0.0:
		return null
	_cooldown = fire_interval
	ammo -= 1
	ammo_changed.emit(ammo)
	var origin := muzzle.global_position
	var direction := (aim_point() - origin).normalized()
	var cone := deg_to_rad(spread_deg())
	var rng := RandomNumberGenerator.new()
	var yaw := rng.randf_range(-cone, cone)
	var pitch := rng.randf_range(-cone, cone)
	direction = direction.rotated(Vector3.UP, yaw).rotated(camera.global_transform.basis.x, pitch).normalized()
	var shot: Projectile3D = projectile_scene.instantiate()
	shot.speed = w_speed
	shot.lifetime = w_life
	shot.damage = w_damage
	shot.launch(origin, direction, self, TEAM)
	_shot_parent().add_child(shot)
	_bloom += w_bloom_deg
	last_shot = "spread %.2f deg, %d left" % [spread_deg(), ammo]
	fired.emit()
	return shot


func start_reload() -> void:
	if is_reloading() or ammo == magazine_size or state == State.CLAMBER:
		return
	_reload_from_empty = ammo == 0
	_reload_timer = w_reload_empty if _reload_from_empty else w_reload_tactical
	reloading_changed.emit(true)
	reload_started.emit(_reload_from_empty)
	if ads:
		_set_ads(false)


func _cancel_reload() -> void:
	if not is_reloading():
		return
	_reload_timer = 0.0
	reloading_changed.emit(false)
	reload_cancelled.emit()


# ---------------------------------------------------------------------------
# Melee
# ---------------------------------------------------------------------------

func _melee() -> void:
	_melee_timer = m_cycle
	_cancel_reload()
	if ads:
		_set_ads(false)
	if state == State.SPRINT:
		_sprint_latched = true
		_set_state(State.WALK, "melee ended sprint")
	var target := _pick_melee_target()
	if target == null:
		var whiff := _whiff_target()
		last_melee = "whiff" + (" (swept %s)" % whiff.name if whiff else "")
		melee_swung.emit(whiff, false)
		if whiff != null:
			_strike(whiff)
		return
	# Lunge: pull to m_lunge_stop from the target, snap facing, lock input.
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var dir := to.normalized()
	rotation.y = atan2(-dir.x, -dir.z)
	var stop := global_position + dir * maxf(dist - m_lunge_stop, 0.0)
	velocity = Vector3.ZERO
	_melee_lock = m_input_lock + m_lunge_time
	var tw := create_tween()
	tw.tween_property(self, "global_position", stop, m_lunge_time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: _strike(target))


func _strike(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var back := _is_behind(target)
	var dmg := m_damage
	var killed := false
	if back and target.has_node("Health"):
		dmg = maxi(target.get_node("Health").current, m_damage)
	if target.has_method("take_damage"):
		target.take_damage(dmg, self)
		if target.has_method("is_alive"):
			killed = not target.is_alive()
	last_melee = "%s hit %s for %d%s" % ["BACK" if back else "front", target.name, dmg, " — kill" if killed else ""]
	melee_swung.emit(target, killed)


## Attacker inside the cone behind the target's facing.
func _is_behind(target: Node3D) -> bool:
	var facing := -target.global_transform.basis.z
	facing.y = 0.0
	var offset := global_position - target.global_position
	offset.y = 0.0
	if facing.length_squared() < 0.001 or offset.length_squared() < 0.001:
		return false
	var angle := rad_to_deg((-facing.normalized()).angle_to(offset.normalized()))
	return angle <= m_back_cone_deg / 2.0


func _pick_melee_target() -> Node3D:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = m_range
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), camera.global_position)
	q.collision_mask = 2
	q.exclude = [get_rid()]
	var best: Node3D = null
	var best_angle := INF
	var fwd := -camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	for hit in space.intersect_shape(q, 16):
		var body: Node3D = hit.collider
		if body == null or not body.has_method("take_damage"):
			continue
		if body.has_method("get_team") and body.get_team() == TEAM:
			continue
		var to: Vector3 = body.global_position - global_position
		to.y = 0.0
		if to.length() > m_range:
			continue
		var angle := rad_to_deg(fwd.angle_to(to.normalized()))
		if angle <= m_cone_deg / 2.0 and angle < best_angle:
			best_angle = angle
			best = body
	return best


func _whiff_target() -> Node3D:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * m_whiff_reach
	var params := PhysicsRayQueryParameters3D.create(from, to, 2)
	params.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(params)
	return hit.collider if not hit.is_empty() and hit.collider.has_method("take_damage") else null
