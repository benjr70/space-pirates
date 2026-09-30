class_name PirateAudio
extends Node
## What the Pirate hears of himself: the Sidearm's shot and dry click, the
## reload's magazine and rack, a landed Melee, his footsteps and landings,
## and the hit he takes. Driven by the Pirate's signals alone, plus his
## speed over the floor for the stride, so it never reaches into his state.
##
## Every sound plays on one of a few non-positional players so that a shot
## does not cut a footstep: `shot`, `gun` (click, magazine, rack), `body`
## (steps, landing, hit) and `melee`. A small random pitch keeps repeats
## from sounding stamped. All of it sits on the `sfx` bus.
##
## Headless, nothing is audible, so every play also emits `played` with the
## kind and the stream: the suite listens to that.

## A sound went off: [param kind] names the event, [param stream] what played.
signal played(kind: StringName, stream: AudioStream)

@export_group("Sidearm")
@export var shot_streams: Array[AudioStream] = [
	preload("res://assets/audio/kurt_gunshots/shot_1.ogg"),
	preload("res://assets/audio/kurt_gunshots/shot_2.ogg"),
	preload("res://assets/audio/kurt_gunshots/shot_3.ogg"),
	preload("res://assets/audio/kurt_gunshots/shot_4.ogg"),
]
@export var dry_stream: AudioStream = preload("res://assets/audio/oga_reload/dry_click.ogg")
@export var mag_out_stream: AudioStream = preload("res://assets/audio/oga_reload/clipload1.ogg")
@export var mag_in_stream: AudioStream = preload("res://assets/audio/oga_reload/clipload2.ogg")
@export var rack_stream: AudioStream = preload("res://assets/audio/kenney_impact/impactMetal_light_001.ogg")
## Where in the reload the magazine seats, as a fraction of the swap.
@export var mag_in_at := 0.6
@export var shot_volume_db := 0.0
@export var gun_volume_db := -6.0
## The tick that says a shot or swing landed; a kill drops its pitch.
@export var hitmark_stream: AudioStream = preload("res://assets/audio/hitmark/hitmark.ogg")
@export var hitmark_volume_db := -4.0

@export_group("Melee")
@export var melee_streams: Array[AudioStream] = [
	preload("res://assets/audio/kenney_impact/impactPunch_heavy_000.ogg"),
	preload("res://assets/audio/kenney_impact/impactPunch_heavy_001.ogg"),
]
@export var melee_volume_db := -3.0

@export_group("Body")
@export var step_streams: Array[AudioStream] = [
	preload("res://assets/audio/kenney_impact/footstep_concrete_000.ogg"),
	preload("res://assets/audio/kenney_impact/footstep_concrete_001.ogg"),
	preload("res://assets/audio/kenney_impact/footstep_concrete_002.ogg"),
	preload("res://assets/audio/kenney_impact/footstep_concrete_003.ogg"),
	preload("res://assets/audio/kenney_impact/footstep_concrete_004.ogg"),
]
@export var hit_streams: Array[AudioStream] = [
	preload("res://assets/audio/kenney_impact/impactSoft_heavy_000.ogg"),
	preload("res://assets/audio/kenney_impact/impactSoft_heavy_001.ogg"),
]
## Metres of floor between footsteps: the walk is a 5 m/s run, so this is a
## running stride; a crouch covers it at half the speed, so half as often.
@export var stride := 1.4
@export var step_volume_db := -8.0
@export var crouch_step_volume_db := -16.0
@export var land_volume_db := -4.0
## Playback pitch varies by up to this much either way.
@export var pitch_spread := 0.06

const BUS := &"sfx"
## Below this the feet are not really moving, so no step.
const STEP_MIN_SPEED := 0.5

var _pirate: CharacterBody3D
var _shot: AudioStreamPlayer
var _gun: AudioStreamPlayer
var _body: AudioStreamPlayer
var _melee: AudioStreamPlayer
var _hitmark: AudioStreamPlayer
var _walked := 0.0
## He has been off the floor since the last landing, so the next floor
## state is a landing and not a respawn.
var _airborne := false
var _reload_sequence: Tween
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_pirate = owner as CharacterBody3D
	_shot = _player("Shot", shot_volume_db)
	_gun = _player("Gun", gun_volume_db)
	_body = _player("Body", step_volume_db)
	_melee = _player("Melee", melee_volume_db)
	_hitmark = _player("Hitmark", hitmark_volume_db)
	_pirate.fired.connect(_on_fired)
	_pirate.dry_fired.connect(_on_dry_fired)
	_pirate.reload_started.connect(_on_reload_started)
	_pirate.reload_cancelled.connect(_stop_reload_sequence)
	_pirate.melee_swung.connect(_on_melee_swung)
	_pirate.hit_landed.connect(_on_hit_landed)
	_pirate.state_changed.connect(_on_state_changed)
	# Children are ready before their owner, so his Health is fetched by path.
	(_pirate.get_node("Health") as Health).damaged.connect(_on_damaged)


func _player(player_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.bus = BUS
	player.volume_db = volume_db
	add_child(player)
	return player


## Silence, and nothing owed: what a respawn wants.
func reset() -> void:
	_stop_reload_sequence()
	_walked = stride * 0.5
	_airborne = false
	for player in [_shot, _gun, _body, _melee, _hitmark]:
		player.stop()


func _process(delta: float) -> void:
	if not _pirate.is_on_floor():
		_airborne = true
	# Footsteps: one every stride of floor covered, only while walking on it.
	if _pirate.is_on_floor() and _pirate.state in [_pirate.State.WALK, _pirate.State.SPRINT, _pirate.State.CROUCH]:
		var speed: float = _pirate.flat_speed()
		if speed > STEP_MIN_SPEED:
			_walked += speed * delta
			if _walked >= stride:
				_walked -= stride
				var crouched: bool = _pirate.state == _pirate.State.CROUCH
				_play(_body, &"step", step_streams.pick_random(), crouch_step_volume_db if crouched else step_volume_db)
			return
	_walked = stride * 0.5


func _on_fired() -> void:
	_play(_shot, &"shot", shot_streams.pick_random())


func _on_dry_fired() -> void:
	_play(_gun, &"dry", dry_stream)


## Magazine out now, in partway through, and on an empty reload the rack in
## its last beat. A cancel kills whatever has not sounded yet.
func _on_reload_started(from_empty: bool) -> void:
	_stop_reload_sequence()
	var profile: WeaponProfile = _pirate.weapon
	var swap := profile.swap_time(from_empty)
	_play(_gun, &"mag_out", mag_out_stream)
	_reload_sequence = create_tween()
	_reload_sequence.tween_interval(swap * mag_in_at)
	_reload_sequence.tween_callback(_play.bind(_gun, &"mag_in", mag_in_stream))
	if profile.racks_after(from_empty):
		_reload_sequence.tween_interval(swap * (1.0 - mag_in_at))
		_reload_sequence.tween_callback(_play.bind(_gun, &"rack", rack_stream))


func _stop_reload_sequence() -> void:
	if _reload_sequence != null and _reload_sequence.is_valid():
		_reload_sequence.kill()
	_reload_sequence = null


func _on_melee_swung(target: Node3D, _killed: bool) -> void:
	if target != null:
		_play(_melee, &"melee", melee_streams.pick_random())


## A landing: back on the floor after being off it, not a respawn's reset
## to WALK, and not the start of a clamber.
func _on_hit_landed(_target: Node3D, killed: bool) -> void:
	_play(_hitmark, &"hitmark", hitmark_stream)
	if killed:
		_hitmark.pitch_scale *= 0.8


func _on_state_changed(from: int, to: int) -> void:
	if from == _pirate.State.AIR and to != _pirate.State.AIR and to != _pirate.State.CLAMBER and _airborne:
		_airborne = false
		_play(_body, &"land", step_streams.pick_random(), land_volume_db)


func _on_damaged(_amount: int, _from: Node) -> void:
	_play(_body, &"hit", hit_streams.pick_random())


func _play(player: AudioStreamPlayer, kind: StringName, stream: AudioStream, volume_db: float = NAN) -> void:
	if stream == null:
		return
	player.stream = stream
	if not is_nan(volume_db):
		player.volume_db = volume_db
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_spread, pitch_spread)
	player.play()
	played.emit(kind, stream)
