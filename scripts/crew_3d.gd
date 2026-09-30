class_name Crew3D
extends CharacterBody3D
## Hostile crew: patrols its room, hunts the pirate when it spots him, and
## fights from cover -- shoot a burst, duck behind something to reload, lean
## back out.
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

enum State { PATROL, HUNT, FIGHT, COVER, SEARCH, DEAD }

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
@export var vision_range := 14.4
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
## The bodies a crew member may spawn in, one drawn per member.
@export var rigs: Array[PackedScene] = [
	preload("res://assets/models/crew/gunner.glb"),
	preload("res://assets/models/crew/soldier.glb"),
]
## How tall a rig stands once fitted, metres.
const RIG_HEIGHT := 1.8
## Clips that must loop while a state holds them.
const LOOPING_CLIPS: Array[StringName] = [&"CharacterArmature|Idle", &"CharacterArmature|Idle_Gun",
		&"CharacterArmature|Idle_Gun_Pointing", &"CharacterArmature|Run", &"CharacterArmature|Walk"]

@export_group("Cover")
@export var cover_search_radius := 6.9
## Seconds spent behind cover before leaning back out.
@export var cover_hold_time := 1.2

## Set by [ShipBuilder3D] so the crew can route around its own ship.
var layout: ShipLayout
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
var _rng := RandomNumberGenerator.new()
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _anim: AnimationPlayer


func _ready() -> void:
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player")
	_shots_left = burst_size
	_rng.randomize()
	_dress()
	_anim = _find_animation_player(model)
	if _anim != null:
		for clip in LOOPING_CLIPS:
			if _anim.has_animation(clip):
				_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_enter(State.PATROL)
	_update_animation()


## One of the rigs, instanced under Model as "Rig" and scaled so it stands
## RIG_HEIGHT tall with its feet on the floor. Rigs come in whatever units
## their author used, so the fit is measured, not assumed.
func _dress() -> void:
	if rigs.is_empty():
		return
	var rig: Node3D = rigs[_rng.randi() % rigs.size()].instantiate()
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
	match state:
		State.PATROL, State.SEARCH:
			_enter(State.HUNT)
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

	_steer(delta)
	_open_doors_ahead()
	move_and_slide()
	_face()
	_update_animation()


# --- perception ---------------------------------------------------------------

func _update_perception(delta: float) -> void:
	_can_see = false
	if target == null or not is_instance_valid(target):
		_seen_ago += delta
		return
	if target.has_method("is_alive") and not target.is_alive():
		_seen_ago += delta
		return
	if _flat_distance(global_position, target.global_position) <= vision_range \
			and not _blocked(global_position + Vector3.UP * EYE_HEIGHT,
					target.global_position + Vector3.UP * EYE_HEIGHT):
		_can_see = true
		_last_seen = target.global_position
		_seen_ago = 0.0
	else:
		_seen_ago += delta


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
	match next:
		State.PATROL:
			_path.clear()
			_hold_timer = _rng.randf_range(0.4, 1.6)
		State.HUNT:
			_repath_to(_last_seen)
		State.FIGHT:
			_path.clear()
			_shots_left = burst_size
		State.COVER:
			var spot := _find_cover_point()
			if spot != Vector3.INF:
				_repath_to(spot)
			else:
				_path.clear()
			_hold_timer = cover_hold_time
		State.SEARCH:
			_repath_to(_last_seen)
			_hold_timer = 2.5


func _tick_patrol() -> void:
	if _can_see:
		_enter(State.HUNT)
		return
	if _path.is_empty() and _hold_timer <= 0.0:
		_path.append(_random_point_in_room(home_room))
		_hold_timer = _rng.randf_range(0.8, 2.2)


func _tick_hunt() -> void:
	if _can_see and _flat_distance(global_position, target.global_position) <= engage_range:
		_enter(State.FIGHT)
		return
	if _seen_ago > lose_target_after:
		_enter(State.SEARCH)
		return
	if _repath_timer <= 0.0:
		_repath_to(_last_seen)


func _tick_fight() -> void:
	if _seen_ago > lose_target_after:
		_enter(State.SEARCH)
		return

	if _can_see:
		_path.clear()
		_aim = (target.global_position + Vector3.UP * TORSO_HEIGHT
				- (global_position + Vector3.UP * MUZZLE_HEIGHT)).normalized()
		if _shots_left > 0:
			if _shot_timer <= 0.0:
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
		_enter(State.SEARCH)
		return
	if not _path.is_empty():
		return  # still getting there
	if _hold_timer > 0.0 or _reload_timer > 0.0:
		return  # tucked in, reloading
	_enter(State.FIGHT)


func _tick_search() -> void:
	if _can_see:
		_enter(State.HUNT)
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
			flat = flat.move_toward(direction * max_speed, acceleration * delta)
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
		if door.is_open or door.locked:
			continue
		if _flat_distance(global_position, door.global_position) <= 1.75:
			door.open()


func _face() -> void:
	var facing := _aim
	if state == State.FIGHT or _can_see:
		facing = _last_seen - global_position
	elif Vector2(velocity.x, velocity.z).length_squared() > 0.004:
		facing = velocity
	facing.y = 0.0
	if facing.length_squared() > 0.001:
		_aim = facing.normalized()
		rotation.y = atan2(-facing.x, -facing.z)


# --- gunnery ------------------------------------------------------------------

func _fire() -> Projectile3D:
	if projectile_scene == null:
		return null
	_shots_left -= 1
	_shot_timer = burst_gap
	if _shots_left <= 0:
		_reload_timer = reload_time

	var spread := deg_to_rad(_rng.randf_range(-spread_degrees, spread_degrees))
	var direction := _aim.rotated(Vector3.UP, spread)
	var origin := global_position + Vector3.UP * MUZZLE_HEIGHT + direction * muzzle_offset
	var shot: Projectile3D = projectile_scene.instantiate()
	shot.launch(origin, direction, self, TEAM)
	_shot_parent().add_child(shot)
	if not shot_streams.is_empty():
		SoundAt.play(_shot_parent(), origin, shot_streams.pick_random(), shot_volume_db, 0.06, "Shot")
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
	if Vector2(velocity.x, velocity.z).length_squared() > 0.25:
		_play_any(["CharacterArmature|Run", "CharacterArmature|Walk", "Run", "Walk"])
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
