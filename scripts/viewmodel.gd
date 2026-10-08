class_name Viewmodel
extends Node3D
## The weapon as the Pirate sees it: the node under the camera that carries
## the Sidearm, moved every frame from what he is doing. Weapon only, no arms.
##
## This is the procedural layer. It owns the Viewmodel's transform:
##   pose    hip by default; sights centred under the crosshair in Aim Down
##           Sights; sprint-low while sprinting or clambering
##   sway    the mouse drags the weapon a little behind the look, and tilts
##           it a touch the same way
##   bob     a walk rocks it, in step with his speed, less crouched or
##           aiming, not at all in the air or lowered
##   recoil  a shot pushes it back and kicks it up, settling on its own
## It also kicks the camera's pitch on a shot and offers a roll on a Descope
## that the Pirate's own camera work (crouch drop, slide roll, clamber dip)
## adds to its target.
##
## Below it, the clip layer: `Clips` plays `fire`, `reload_tactical`,
## `reload_empty` and `melee` on the mesh child from the library in
## `resources/animations/viewmodel_clips.tres`. The reload clips are authored
## at the Sidearm's durations and played at whatever speed makes them last
## the Weapon Profile's, so a new Profile never needs a new clip. A reload
## owns the mesh until it ends or is cancelled: a shot never cuts a reload
## clip, a Melee does (the Pirate has already dropped the reload by then),
## and a cancel stops the clip and puts the mesh back at rest.
##
## What hangs under `Sidearm` is whatever the Weapon Profile's `model` scene
## is: the holder keeps its name from the first weapon, but the wheel swaps
## the mesh under it. A swap dips the Viewmodel out of the bottom of the view
## and changes the mesh while it is out of sight; each mesh brings its own
## `Muzzle` and `SightTip` markers and the Profile its own poses, so the shot
## leaves the right barrel and the right front sight centres in Aim Down
## Sights with nothing calibrated by hand.
##
## A weapon's mesh (built by the scripts under `tools/blender`) brings its own
## skeleton clips: the slide cycles on a
## shot, the magazine drops and seats on a reload, and the slide racks to
## close an empty reload. The Weapon Profile names those clips and times
## them, so they play on the mesh's AnimationPlayer time-scaled the same way
## as the holder clips, and a cancel resets the bones.
##
## Wall clipping is handled by material flags: every surface is squashed
## toward the camera in depth and drawn with its own narrow FOV, so the
## weapon never pokes through a wall he stands against. No SubViewport.

@export_group("Poses")
## Holder rotation for each pose, in camera space. The mesh faces +Z, so
## every pose turns it round. The positions come from the Weapon Profile.
@export var rotation_hip := Vector3(0.0, 180.0, 0.0)
@export var rotation_low := Vector3(-35.0, 180.0, 15.0)
## How fast the Viewmodel settles toward its target pose.
@export var pose_lerp := 10.0

@export_group("Sway")
## Metres of drag per pixel of mouse travel.
@export var sway_per_pixel := 0.0006
@export var sway_max := 0.04
@export var sway_ads_scale := 0.2
@export var sway_decay := 10.0
## Degrees the weapon tilts per metre of sway.
@export var sway_tilt_degrees := 40.0

@export_group("Bob")
## The bob at walking speed; slower steps bob less in proportion.
@export var bob_amplitude := 0.012
## Radians of bob per metre walked.
@export var bob_rate := 1.8
@export var bob_crouch_scale := 0.6
@export var bob_ads_scale := 0.3

@export_group("Recoil")
## A shot's recoil is 1.0; this much of it goes per second, so it is gone
## in a sixth of a second. How far it pushes and kicks is the Weapon
## Profile's, and differs in Aim Down Sights.
@export var recoil_decay := 6.0
## The camera kick recovers in about 0.1 s.
@export var camera_kick_recovery := 12.0

@export_group("Descope")
## The camera roll a Descope starts with, and how fast it levels out.
@export var descope_roll_degrees := 2.5
@export var descope_roll_decay := 12.0

@export_group("Weapon swap")
## How far the weapon drops out of view while it is swapped for the next.
@export var swap_drop := 0.35

@export_group("Wall clipping")
@export var z_clip_scale := 0.35
@export var fov_override := 50.0

## Below this the feet are not really moving, so no bob.
const BOB_MIN_SPEED := 0.3
const RELOAD_CLIPS: Array[StringName] = [&"reload_tactical", &"reload_empty"]

## Degrees of roll a Descope is still asking of the camera. The Pirate's
## camera work reads it into its roll target.
var descope_roll := 0.0

## Holder position for each pose, in camera space: the mounted weapon's.
## The sights pose is worked out from its SightTip, so the front sight sits
## on the camera axis.
var pose_hip := Vector3(0.16, -0.18, -0.30)
var pose_ads := Vector3(0.0, -0.1076, -0.32)
var pose_low := Vector3(0.20, -0.26, -0.30)

## The clip layer and the holder it moves.
@onready var clips: AnimationPlayer = $Clips
@onready var sidearm: Node3D = $Sidearm
@onready var _muzzle: Node3D = $Muzzle
@onready var _sight_tip: Node3D = $SightTip
## The mounted mesh's own skeleton clips and bones.
var sidearm_clips: AnimationPlayer
var _skeleton: Skeleton3D
## Every model mounted so far, by its scene; all but one are hidden.
var _models := {}
var _mounted: Node3D
## Seconds of swap dip left, and how long the whole dip is.
var _swap_left := 0.0
var _swap_time := 0.0
## True while the empty reload's magazine clip runs, so its end racks the slide.
var _rack_after_reload := false

## The Pirate: the scene this Viewmodel is built into.
var _pirate: CharacterBody3D
## What he is holding, read live so a swapped Profile takes effect.
var profile: WeaponProfile:
	get: return _pirate.weapon
var _camera: Camera3D
var _sway := Vector2.ZERO
var _bob_phase := 0.0
var _recoil := 0.0
var _camera_kick := 0.0
## Where the eased pose is, before the offsets ride on it.
var _pose_position := Vector3.ZERO
var _pose_rotation := Vector3.ZERO


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_pirate = owner as CharacterBody3D
	_mount(profile)
	reset()
	_pirate.fired.connect(_on_fired)
	_pirate.descoped.connect(_on_descoped)
	_pirate.reload_started.connect(_on_reload_started)
	_pirate.reload_cancelled.connect(_stop_clip)
	_pirate.melee_swung.connect(_on_melee_swung)
	_pirate.weapon_changed.connect(_on_weapon_changed)


## Everything at rest in the hip pose: what a respawn wants.
func reset() -> void:
	_sway = Vector2.ZERO
	_bob_phase = 0.0
	_recoil = 0.0
	_camera_kick = 0.0
	descope_roll = 0.0
	_swap_left = 0.0
	_mount(profile)
	_pose_position = pose_hip
	_pose_rotation = rotation_hip
	position = pose_hip
	rotation_degrees = rotation_hip
	_camera.rotation_degrees.x = 0.0
	_stop_clip()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_sway = (_sway + (event as InputEventMouseMotion).relative * sway_per_pixel).limit_length(sway_max)


func _process(delta: float) -> void:
	var lowered: bool = _pirate.state in [_pirate.State.SPRINT, _pirate.State.CLAMBER]
	var aiming: bool = _pirate.ads

	var sway := Vector3(-_sway.x, _sway.y, 0.0) * (sway_ads_scale if aiming else 1.0)
	_sway = _sway.lerp(Vector2.ZERO, minf(sway_decay * delta, 1.0))

	var bob := Vector3.ZERO
	var speed: float = _pirate.flat_speed()
	if _pirate.is_on_floor() and speed > BOB_MIN_SPEED and not lowered:
		_bob_phase += delta * speed * bob_rate
		var amplitude: float = bob_amplitude * minf(speed / _pirate.max_speed, 1.0)
		if aiming:
			amplitude *= bob_ads_scale
		if _pirate.state == _pirate.State.CROUCH:
			amplitude *= bob_crouch_scale
		bob = Vector3(sin(_bob_phase), absf(cos(_bob_phase)), 0.0) * amplitude
	else:
		_bob_phase = 0.0

	_recoil = move_toward(_recoil, 0.0, recoil_decay * delta)

	# A swap dips the weapon out of view and back; the mesh changes at the
	# bottom, where nobody sees it.
	var dip := Vector3.ZERO
	if _swap_left > 0.0:
		var before := _swap_left
		_swap_left = maxf(_swap_left - delta, 0.0)
		var half := _swap_time * 0.5
		if before > half and _swap_left <= half:
			_mount(profile)
			_pose_position = pose_hip
		dip = Vector3.DOWN * swap_drop * sin(PI * (1.0 - _swap_left / _swap_time))

	# The pose eases; the sway, bob and recoil ride on top at full size, since
	# each is already smooth or is meant to snap.
	var pose_position: Vector3
	var pose_rotation: Vector3
	if lowered:
		pose_position = pose_low
		pose_rotation = rotation_low
	else:
		pose_position = pose_ads if aiming else pose_hip
		pose_rotation = rotation_hip
	var t := minf(pose_lerp * delta, 1.0)
	_pose_position = _pose_position.lerp(pose_position, t)
	_pose_rotation = _pose_rotation.lerp(pose_rotation, t)
	var recoil_push: float = profile.ads_recoil_push if aiming else profile.recoil_push
	var recoil_kick: float = profile.ads_recoil_kick_degrees if aiming else profile.recoil_kick_degrees
	position = _pose_position + sway + bob + dip + Vector3(0.0, 0.0, recoil_push * _recoil)
	# Turned round to face down the camera, a negative pitch is muzzle-up.
	rotation_degrees = _pose_rotation \
			+ Vector3(-recoil_kick * _recoil + sway.y * sway_tilt_degrees, -sway.x * sway_tilt_degrees, 0.0)

	_camera_kick = move_toward(_camera_kick, 0.0, profile.camera_kick_degrees * camera_kick_recovery * delta)
	_camera.rotation_degrees.x = _camera_kick
	descope_roll = move_toward(descope_roll, 0.0, descope_roll_decay * delta)


## Where in the world the barrel's tip appears to be. The weapon is drawn
## with its own narrow FOV, so on screen its muzzle sits further off the
## crosshair than the Muzzle marker's true place in the world; a bolt born at
## the marker would seem to start beside the barrel. This is the point at the
## muzzle's depth that the camera draws on the same pixel.
func muzzle_point() -> Vector3:
	var in_camera := _camera.to_local(_muzzle.global_position)
	var widen := tan(deg_to_rad(_camera.fov) * 0.5) / tan(deg_to_rad(fov_override) * 0.5)
	return _camera.to_global(Vector3(in_camera.x * widen, in_camera.y * widen, in_camera.z))


func _on_fired() -> void:
	_recoil = 1.0
	_camera_kick = profile.camera_kick_degrees
	if not _reload_clip_playing():
		if profile.fire_clip != &"":
			_play_clip(profile.fire_clip)
		_play_for(sidearm_clips, profile.model_fire_clip, profile.fire_cycle_time)


## The clips stretched or squeezed to the Profile's reload time. The empty
## reload spends its last beat racking the slide, when the Profile has a
## rack and the reload is long enough to hold one.
func _on_reload_started(from_empty: bool) -> void:
	var wanted: float = profile.reload_empty if from_empty else profile.reload_tactical
	_play_for(clips, RELOAD_CLIPS[1] if from_empty else RELOAD_CLIPS[0], wanted)
	_rack_after_reload = profile.racks_after(from_empty)
	_play_for(sidearm_clips, profile.model_reload_clip, profile.swap_time(from_empty))


func _on_sidearm_clip_finished(clip: StringName) -> void:
	if clip == profile.model_reload_clip and _rack_after_reload:
		_rack_after_reload = false
		_play_for(sidearm_clips, profile.model_rack_clip, profile.rack_time)


func _on_weapon_changed(_profile: WeaponProfile) -> void:
	_stop_clip()
	_swap_time = _pirate.swap_time
	_swap_left = _swap_time
	if _swap_time <= 0.0:
		_mount(profile)


## Puts [param weapon]'s model under the holder in place of the last one and
## takes its markers and poses. A Profile with no model keeps what is there.
func _mount(weapon: WeaponProfile) -> void:
	if weapon.model == null or (_mounted != null and _mounted == _models.get(weapon.model)):
		return
	_stop_clip()
	if _mounted != null:
		_mounted.visible = false
		sidearm_clips.animation_finished.disconnect(_on_sidearm_clip_finished)
	if not _models.has(weapon.model):
		var model: Node3D = weapon.model.instantiate()
		sidearm.add_child(model)
		_models[weapon.model] = model
		_flag_materials(model)
	_mounted = _models[weapon.model]
	_mounted.visible = true
	sidearm_clips = _mounted.find_child("AnimationPlayer", true, false)
	_skeleton = _mounted.find_child("Skeleton3D", true, false)
	sidearm_clips.animation_finished.connect(_on_sidearm_clip_finished)

	# The holder is at rest, so the model's markers map straight into the
	# Viewmodel's own space.
	var to_viewmodel := global_transform.affine_inverse()
	_muzzle.position = to_viewmodel * (_mounted.find_child("Muzzle", true, false) as Node3D).global_position
	_sight_tip.position = to_viewmodel * (_mounted.find_child("SightTip", true, false) as Node3D).global_position
	pose_hip = weapon.pose_hip
	pose_low = weapon.pose_low
	var sight := Basis.from_euler(rotation_hip * PI / 180.0) * _sight_tip.position
	pose_ads = Vector3(-sight.x, -sight.y, -weapon.ads_distance)


func _on_melee_swung(_target: Node3D, _killed: bool) -> void:
	_play_clip("melee")


func _reload_clip_playing() -> bool:
	return clips.is_playing() and clips.current_animation in RELOAD_CLIPS


## From the top, even when the same clip is already running: a second shot
## inside the fire clip restarts it.
func _play_clip(clip: StringName, speed: float = 1.0) -> void:
	clips.stop()
	clips.play(clip, -1, speed)


## [param clip] on [param player] from the top, at the speed that makes it
## last [param seconds].
func _play_for(player: AnimationPlayer, clip: StringName, seconds: float) -> void:
	player.stop()
	player.play(clip, -1, player.get_animation(clip).length / maxf(seconds, 0.01))


## Whatever was playing stops, the Sidearm sits at rest on the Viewmodel and
## its bones go back to their rest pose.
func _stop_clip() -> void:
	clips.stop()
	sidearm.position = Vector3.ZERO
	sidearm.rotation = Vector3.ZERO
	_rack_after_reload = false
	if sidearm_clips != null:
		sidearm_clips.stop()
		_skeleton.reset_bone_poses()


func _on_descoped() -> void:
	descope_roll = descope_roll_degrees


## Godot 4.5+ material flags in place of a SubViewport overlay. Each surface
## gets its own copy so the shared mesh resource is untouched.
func _flag_materials(model: Node3D) -> void:
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var instance := found as MeshInstance3D
		if instance.mesh == null:
			continue
		for i in instance.mesh.get_surface_count():
			var material := instance.get_active_material(i)
			if material == null:
				continue
			var own: Material = material.duplicate()
			own.set("use_z_clip_scale", true)
			own.set("z_clip_scale", z_clip_scale)
			own.set("use_fov_override", true)
			own.set("fov_override", fov_override)
			instance.set_surface_override_material(i, own)
