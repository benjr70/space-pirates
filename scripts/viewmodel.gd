class_name Viewmodel
extends Node3D
## The weapon as the Pirate sees it: the node under the camera that carries
## the mesh, moved every frame from what he is doing. Weapon only, no arms.
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
## Wall clipping is handled by material flags: every surface is squashed
## toward the camera in depth and drawn with its own narrow FOV, so the
## weapon never pokes through a wall he stands against. No SubViewport.

@export_group("Poses")
## Holder position and rotation for each pose, in camera space. The mesh
## faces +Z, so every pose turns it round.
@export var pose_hip := Vector3(0.25, -0.28, -0.45)
@export var pose_ads := Vector3(0.0, -0.19, -0.36)
@export var pose_low := Vector3(0.30, -0.42, -0.40)
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
@export var recoil_push := 0.05
@export var recoil_kick_degrees := 7.0
## A shot's recoil is 1.0; this much of it goes per second, so it is gone
## in a sixth of a second.
@export var recoil_decay := 6.0
@export var camera_kick_degrees := 1.2
## The camera kick recovers in about 0.1 s.
@export var camera_kick_recovery := 12.0

@export_group("Descope")
## The camera roll a Descope starts with, and how fast it levels out.
@export var descope_roll_degrees := 2.5
@export var descope_roll_decay := 12.0

@export_group("Wall clipping")
@export var z_clip_scale := 0.35
@export var fov_override := 50.0

## Below this the feet are not really moving, so no bob.
const BOB_MIN_SPEED := 0.3
const RELOAD_CLIPS: Array[StringName] = [&"reload_tactical", &"reload_empty"]

## Degrees of roll a Descope is still asking of the camera. The Pirate's
## camera work reads it into its roll target.
var descope_roll := 0.0

## The clip layer and the mesh it moves.
@onready var clips: AnimationPlayer = $Clips
@onready var mesh: Node3D = $Blaster

## The Pirate: the scene this Viewmodel is built into.
var _pirate: CharacterBody3D
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
	reset()
	_flag_materials()
	_pirate.fired.connect(_on_fired)
	_pirate.descoped.connect(_on_descoped)
	_pirate.reload_started.connect(_on_reload_started)
	_pirate.reload_cancelled.connect(_stop_clip)
	_pirate.melee_swung.connect(_on_melee_swung)


## Everything at rest in the hip pose: what a respawn wants.
func reset() -> void:
	_sway = Vector2.ZERO
	_bob_phase = 0.0
	_recoil = 0.0
	_camera_kick = 0.0
	descope_roll = 0.0
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
	position = _pose_position + sway + bob + Vector3(0.0, 0.0, recoil_push * _recoil)
	rotation_degrees = _pose_rotation \
			+ Vector3(recoil_kick_degrees * _recoil + sway.y * sway_tilt_degrees, -sway.x * sway_tilt_degrees, 0.0)

	_camera_kick = move_toward(_camera_kick, 0.0, camera_kick_degrees * camera_kick_recovery * delta)
	_camera.rotation_degrees.x = _camera_kick
	descope_roll = move_toward(descope_roll, 0.0, descope_roll_decay * delta)


func _on_fired() -> void:
	_recoil = 1.0
	_camera_kick = camera_kick_degrees
	if not _reload_clip_playing():
		_play_clip("fire")


## The clip stretched or squeezed to the Profile's reload time.
func _on_reload_started(from_empty: bool) -> void:
	var clip: StringName = RELOAD_CLIPS[1] if from_empty else RELOAD_CLIPS[0]
	var wanted: float = _pirate.weapon.reload_empty if from_empty else _pirate.weapon.reload_tactical
	_play_clip(clip, clips.get_animation(clip).length / maxf(wanted, 0.01))


func _on_melee_swung(_target: Node3D, _killed: bool) -> void:
	_play_clip("melee")


func _reload_clip_playing() -> bool:
	return clips.is_playing() and clips.current_animation in RELOAD_CLIPS


## From the top, even when the same clip is already running: a second shot
## inside the fire clip restarts it.
func _play_clip(clip: StringName, speed: float = 1.0) -> void:
	clips.stop()
	clips.play(clip, -1, speed)


## Whatever was playing stops, and the mesh sits at rest on the Viewmodel.
func _stop_clip() -> void:
	clips.stop()
	mesh.position = Vector3.ZERO
	mesh.rotation = Vector3.ZERO


func _on_descoped() -> void:
	descope_roll = descope_roll_degrees


## Godot 4.5+ material flags in place of a SubViewport overlay. Each surface
## gets its own copy so the shared mesh resource is untouched.
func _flag_materials() -> void:
	for found in find_children("*", "MeshInstance3D", true, false):
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
