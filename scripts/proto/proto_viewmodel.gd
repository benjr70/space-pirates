extends Node3D
## PROTOTYPE — the Viewmodel (issue #36). Sits on $Head/Camera3D/Weapon.
##
## Two layers, as the research recommended:
##   * this node moves procedurally: state pose (hip / ADS / sprint-low),
##     mouse sway, walk bob, recoil push, all lerped every frame;
##   * an AnimationPlayer built in code plays discrete clips on the Blaster
##     child: fire, reload_tactical, reload_empty, melee.
## Wall clipping uses the 4.5+ material flags (z_clip_scale, fov_override),
## no SubViewport. Throwaway.

var pirate: Node3D
var blaster: Node3D
var anim: AnimationPlayer
var cam: Camera3D

## Poses: position / rotation_degrees of this holder.
var pose_hip := [Vector3(0.25, -0.28, -0.45), Vector3(0, 180, 0)]
var pose_ads := [Vector3(0.0, -0.19, -0.36), Vector3(0, 180, 0)]
var pose_low := [Vector3(0.30, -0.42, -0.40), Vector3(-35, 180, 15)]

var k_sway := 0.0006
var k_sway_max := 0.04
var k_bob_amp := 0.012
var k_bob_rate := 1.8
var k_recoil_pos := 0.05
var k_recoil_rot := 7.0
var k_cam_kick_deg := 1.2
var k_pose_lerp := 10.0
var k_viewmodel_fov := 50.0
var k_zclip := 0.35

var _sway := Vector2.ZERO
var _bob_t := 0.0
var _recoil := 0.0
var _cam_kick := 0.0
var _cam_roll := 0.0
var last_clip := ""


func _ready() -> void:
	pirate = get_parent().get_parent().get_parent()
	cam = get_parent()
	blaster = get_child(0)
	pose_hip = [position, rotation_degrees]
	_build_clips()
	_fix_clipping()
	pirate.fired.connect(_on_fired)
	pirate.reload_started.connect(func(empty: bool) -> void: _play("reload_empty" if empty else "reload_tactical"))
	pirate.reload_cancelled.connect(func() -> void: anim.stop(); blaster.position = Vector3.ZERO; blaster.rotation_degrees = Vector3.ZERO)
	pirate.melee_swung.connect(func(_hit: Node3D, _killed: bool) -> void: _play("melee"))
	pirate.descoped.connect(func() -> void: _cam_roll = 2.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_sway += (event as InputEventMouseMotion).relative * k_sway


func _process(delta: float) -> void:
	var state: String = pirate.state_name()
	var lowered := state == "SPRINT" or state == "CLAMBER"
	var pose: Array = pose_low if lowered else (pose_ads if pirate.ads else pose_hip)
	var sway_scale := 0.2 if pirate.ads else 1.0
	_sway = _sway.limit_length(k_sway_max)
	var sway := Vector3(-_sway.x, _sway.y, 0.0) * sway_scale
	_sway = _sway.lerp(Vector2.ZERO, 10.0 * delta)

	var speed: float = pirate.flat_speed()
	var bob := Vector3.ZERO
	if pirate.is_on_floor() and speed > 0.3 and not lowered:
		_bob_t += delta * speed * k_bob_rate
		var amp := k_bob_amp * (0.3 if pirate.ads else 1.0) * (0.6 if state == "CROUCH" else 1.0)
		bob = Vector3(sin(_bob_t) * amp, absf(cos(_bob_t)) * amp, 0.0)
	else:
		_bob_t = 0.0

	_recoil = move_toward(_recoil, 0.0, 6.0 * delta)
	var recoil_pos := Vector3(0, 0, k_recoil_pos * _recoil)
	var recoil_rot := Vector3(k_recoil_rot * _recoil, 0, 0)

	var target_pos: Vector3 = pose[0] + sway + bob + recoil_pos
	var target_rot: Vector3 = pose[1] + recoil_rot + Vector3(sway.y * 40.0, sway.x * -40.0, 0.0)
	position = position.lerp(target_pos, k_pose_lerp * delta)
	rotation_degrees = rotation_degrees.lerp(target_rot, k_pose_lerp * delta)

	_cam_kick = move_toward(_cam_kick, 0.0, k_cam_kick_deg * 8.0 * delta)
	_cam_roll = move_toward(_cam_roll, 0.0, 12.0 * delta)
	cam.rotation_degrees.x = _cam_kick
	# The movement layer owns roll for the slide tilt; add the descope flinch on top.
	if _cam_roll > 0.0:
		cam.rotation_degrees.z += _cam_roll * 0.3


func _on_fired() -> void:
	_recoil = 1.0
	_cam_kick = k_cam_kick_deg
	if not anim.is_playing() or anim.current_animation == "fire":
		_play("fire")


func _play(clip: String) -> void:
	last_clip = clip
	anim.stop()
	anim.play(clip)


# ---------------------------------------------------------------------------
# Clips, built in code so the prototype is one file.
# ---------------------------------------------------------------------------

func _build_clips() -> void:
	anim = AnimationPlayer.new()
	anim.name = "Clips"
	add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation("fire", _clip(0.12, [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.03, Vector3(0, 0.01, 0.05), Vector3(6, 0, 0)],
		[0.12, Vector3.ZERO, Vector3.ZERO]]))
	lib.add_animation("reload_tactical", _clip(1.2, [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.25, Vector3(0.03, -0.04, 0.02), Vector3(-28, 0, -12)],     # tilt in
		[0.5, Vector3(0.03, -0.10, 0.02), Vector3(-28, 0, -12)],      # mag out (drop)
		[0.85, Vector3(0.03, -0.04, 0.02), Vector3(-28, 0, -12)],     # mag in
		[1.2, Vector3.ZERO, Vector3.ZERO]]))                          # settle
	lib.add_animation("reload_empty", _clip(1.6, [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.25, Vector3(0.03, -0.04, 0.02), Vector3(-28, 0, -12)],
		[0.55, Vector3(0.03, -0.10, 0.02), Vector3(-28, 0, -12)],
		[0.95, Vector3(0.03, -0.04, 0.02), Vector3(-28, 0, -12)],
		[1.25, Vector3(0.0, -0.01, 0.0), Vector3(-6, 0, 0)],
		[1.4, Vector3(0.0, 0.01, 0.06), Vector3(4, 0, 0)],             # slide release snap
		[1.6, Vector3.ZERO, Vector3.ZERO]]))
	lib.add_animation("melee", _clip(0.55, [
		[0.0, Vector3.ZERO, Vector3.ZERO],
		[0.08, Vector3(0.10, 0.05, 0.10), Vector3(10, 20, 25)],       # wind up
		[0.18, Vector3(-0.25, -0.05, -0.15), Vector3(-15, -40, -60)],  # whip across
		[0.55, Vector3.ZERO, Vector3.ZERO]]))
	anim.add_animation_library("", lib)


func _clip(length: float, keys: Array) -> Animation:
	var a := Animation.new()
	a.length = length
	var p := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(p, "Blaster:position")
	var r := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(r, "Blaster:rotation_degrees")
	for k in keys:
		a.track_insert_key(p, k[0], k[1])
		a.track_insert_key(r, k[0], k[2])
	return a


## Godot 4.5+ material flags replace the SubViewport overlay: the weapon is
## squashed toward the camera in depth and drawn with its own FOV.
func _fix_clipping() -> void:
	blaster.name = "Blaster"
	for mesh in blaster.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(i)
			if mat == null:
				continue
			var dup := mat.duplicate()
			dup.set("use_z_clip_scale", true)
			dup.set("z_clip_scale", k_zclip)
			dup.set("use_fov_override", true)
			dup.set("fov_override", k_viewmodel_fov)
			mi.set_surface_override_material(i, dup)
