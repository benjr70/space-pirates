class_name Crew
extends CharacterBody2D
## Hostile crew: patrols its room, hunts the pirate when it spots him, and
## fights from cover -- shoot a burst, duck behind something to reload, lean
## back out.
##
## Movement between rooms rides the door graph via [ShipNavigator]; inside a
## room the crew steers straight at its waypoint, which is enough because rooms
## are convex rectangles. Cover is worked out by raycast at the moment it is
## needed rather than baked into the layout, so it stays correct however the
## room was generated and wherever the pirate happens to be standing.

enum State { PATROL, HUNT, FIGHT, COVER, SEARCH, DEAD }

const TEAM := &"crew"
## Layer 1 is the ship itself: hull, props and shut doors.
const WORLD_LAYER := 1

@export_group("Movement")
@export var max_speed := 115.0
@export var acceleration := 900.0
@export var friction := 1100.0
## How close counts as having reached a waypoint.
@export var arrive_radius := 14.0

@export_group("Perception")
@export var vision_range := 460.0
## Seconds out of sight before the crew stops shooting and starts searching.
@export var lose_target_after := 3.0

@export_group("Gunnery")
@export var engage_range := 340.0
@export var burst_size := 3
@export var burst_gap := 0.14
@export var reload_time := 1.1
## Crew are worse shots than the player.
@export var spread_degrees := 7.0
@export var muzzle_offset := 20.0
@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@export_group("Cover")
@export var cover_search_radius := 220.0
## Seconds spent behind cover before leaning back out.
@export var cover_hold_time := 1.2

## Set by [ShipBuilder] so the crew can route around its own ship.
var layout: ShipLayout
var home_room := 0
var target: Node2D
var state := State.PATROL

@onready var sprite: Sprite2D = $Sprite2D
@onready var health: Health = $Health

var _path: Array[Vector2] = []
var _aim := Vector2.DOWN
var _shots_left := 0
var _shot_timer := 0.0
var _reload_timer := 0.0
## Counts down inside states that wait: holding cover, pausing on patrol.
var _hold_timer := 0.0
var _repath_timer := 0.0
var _last_seen := Vector2.ZERO
var _seen_ago := 999.0
var _can_see := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	health.died.connect(_on_died)
	if target == null:
		target = get_tree().get_first_node_in_group(&"player")
	_shots_left = burst_size
	_rng.randomize()
	_enter(State.PATROL)


func get_team() -> StringName:
	return TEAM


func take_damage(amount: int, from: Node = null) -> void:
	if state == State.DEAD:
		return
	if health.take_damage(amount, from):
		return
	# Being shot at from somewhere unseen still tells you roughly where to look.
	if from != null and is_instance_valid(from) and from is Node2D:
		_last_seen = (from as Node2D).global_position
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


# --- perception ---------------------------------------------------------------

func _update_perception(delta: float) -> void:
	_can_see = false
	if target == null or not is_instance_valid(target):
		_seen_ago += delta
		return
	if target.has_method("is_alive") and not target.is_alive():
		_seen_ago += delta
		return
	var to_target: Vector2 = target.global_position - global_position
	if to_target.length() <= vision_range and not _blocked(global_position, target.global_position):
		_can_see = true
		_last_seen = target.global_position
		_seen_ago = 0.0
	else:
		_seen_ago += delta


## True when the ship itself stands between two points.
func _blocked(from: Vector2, to: Vector2) -> bool:
	var params := PhysicsRayQueryParameters2D.create(from, to, WORLD_LAYER)
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(params).is_empty()


## True when a point is inside the hull or a prop, so nobody can stand there.
func _solid(point: Vector2) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = point
	params.collision_mask = WORLD_LAYER
	return not get_world_2d().direct_space_state.intersect_point(params, 1).is_empty()


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
			if spot != Vector2.INF:
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
	if _can_see and global_position.distance_to(target.global_position) <= engage_range:
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
		_aim = (target.global_position - global_position).normalized()
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
		_repath_to(spot if spot != Vector2.INF else _last_seen)


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
	if _path.is_empty():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		return
	var point: Vector2 = _path[0]
	if global_position.distance_to(point) <= arrive_radius:
		_path.pop_front()
		return
	var direction := (point - global_position).normalized()
	velocity = velocity.move_toward(direction * max_speed, acceleration * delta)


func _repath_to(destination: Vector2) -> void:
	_repath_timer = 0.5
	_path.clear()
	if layout != null:
		_path.assign(ShipNavigator.waypoints(layout, global_position, destination))
	if _path.is_empty():
		_path.append(destination)


## Crew work the doors they walk into; the pirate has to press E, they do not.
func _open_doors_ahead() -> void:
	if _path.is_empty():
		return
	for node in get_tree().get_nodes_in_group(&"doors"):
		var door: Door = node
		if door.is_open or door.locked:
			continue
		if global_position.distance_to(door.global_position) <= 56.0:
			door.open()


func _face() -> void:
	var facing := _aim
	if state == State.FIGHT or _can_see:
		facing = (_last_seen - global_position)
	elif velocity.length_squared() > 4.0:
		facing = velocity
	if facing.length_squared() > 1.0:
		_aim = facing.normalized()
		# The sprite art points up, so offset by 90 degrees.
		sprite.rotation = _aim.angle() + PI / 2.0


# --- gunnery ------------------------------------------------------------------

func _fire() -> Projectile:
	if projectile_scene == null:
		return null
	_shots_left -= 1
	_shot_timer = burst_gap
	if _shots_left <= 0:
		_reload_timer = reload_time

	var spread := deg_to_rad(_rng.randf_range(-spread_degrees, spread_degrees))
	var direction := _aim.rotated(spread)
	var shot: Projectile = projectile_scene.instantiate()
	shot.launch(global_position + direction * muzzle_offset, direction, self, TEAM)
	_shot_parent().add_child(shot)
	return shot


func _shot_parent() -> Node:
	var container := get_tree().get_first_node_in_group(&"projectiles")
	return container if container != null else get_parent()


# --- cover --------------------------------------------------------------------

## Somewhere nearby that the ship stands between us and the pirate.
func _find_cover_point() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.INF
	var aim_at: Vector2 = _last_seen
	var best := Vector2.INF
	var best_score := -INF
	for point in _candidate_points():
		if not _blocked(point, aim_at):
			continue  # exposed
		if _blocked(global_position, point):
			continue  # cannot get there in a straight line
		# Prefer close cover, but not cover so far back it abandons the fight.
		var score := -global_position.distance_to(point) - 0.35 * point.distance_to(aim_at)
		if score > best_score:
			best_score = score
			best = point
	return best


## Somewhere nearby with a clear shot at the pirate.
func _find_firing_position() -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.INF
	var aim_at: Vector2 = _last_seen
	var best := Vector2.INF
	var best_score := -INF
	for point in _candidate_points():
		if _blocked(point, aim_at):
			continue
		if point.distance_to(aim_at) > engage_range:
			continue
		var score := -global_position.distance_to(point)
		if score > best_score:
			best_score = score
			best = point
	return best


## Tile centres in the current room within the search radius, minus any that are
## inside the hull or a prop.
func _candidate_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	if layout == null:
		return points
	var room := layout.room_at(ShipBuilder.world_to_tile(global_position))
	if room == -1:
		room = home_room
	var rect: Rect2i = layout.rooms[room].rect
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var point := ShipBuilder.tile_to_world(Vector2i(x, y))
			if global_position.distance_to(point) > cover_search_radius:
				continue
			if _solid(point):
				continue
			points.append(point)
	return points


func _random_point_in_room(room: int) -> Vector2:
	if layout == null or room < 0 or room >= layout.rooms.size():
		return global_position
	var rect: Rect2i = layout.rooms[room].rect
	for _attempt in 8:
		var tile := Vector2i(
				_rng.randi_range(rect.position.x, rect.end.x - 1),
				_rng.randi_range(rect.position.y, rect.end.y - 1))
		var point := ShipBuilder.tile_to_world(tile)
		if not _solid(point):
			return point
	return ShipBuilder.room_center_world(layout.rooms[room])


# --- death --------------------------------------------------------------------

func _on_died(_from: Node) -> void:
	state = State.DEAD
	_path.clear()
	velocity = Vector2.ZERO
	set_collision_layer_value(2, false)
	$CollisionShape2D.set_deferred("disabled", true)
	z_index = 1
	create_tween().tween_property(sprite, "modulate", Color(0.35, 0.28, 0.3, 0.85), 0.4)


func is_alive() -> bool:
	return state != State.DEAD and health.is_alive()
