extends CharacterBody2D
## The pirate. Moves on WASD, aims and shoots wherever the mouse is.

## Top speed in pixels per second.
@export var max_speed: float = 165.0
## How quickly the spaceman gets up to speed, in pixels per second squared.
@export var acceleration: float = 1400.0
## How quickly he coasts to a stop when there is no input.
@export var friction: float = 1400.0
## Turn to face the mouse. Off means he faces the way he is walking instead.
@export var aim_at_mouse: bool = true
## Seconds between shots while the trigger is held.
@export var fire_interval: float = 0.16
## How far out of his middle a shot spawns, so it clears his own collider.
@export var muzzle_offset: float = 20.0

@export var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")

@onready var sprite: Sprite2D = $Sprite2D

## Unit vector the pirate is currently pointing.
var aim_direction := Vector2.DOWN

var _cooldown := 0.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if aim_at_mouse:
		aim_toward(get_global_mouse_position())
	elif direction != Vector2.ZERO:
		set_aim(direction)

	_cooldown = maxf(_cooldown - delta, 0.0)
	if Input.is_action_pressed("shoot"):
		fire()

	move_and_slide()


## Points him at a world position. Split out from the mouse read so the aim can
## be driven from anywhere -- tests, or crew reusing this later.
func aim_toward(world_position: Vector2) -> void:
	set_aim(world_position - global_position)


## Turns him to face [param direction]. Facing and aiming are the same thing, so
## the sprite is turned here rather than once a frame.
func set_aim(direction: Vector2) -> void:
	if direction.length_squared() <= 1.0:
		return
	aim_direction = direction.normalized()
	if sprite != null:
		# The sprite art points up, so offset by 90 degrees.
		sprite.rotation = aim_direction.angle() + PI / 2.0


## Fires if the weapon is off cooldown. Returns the shot, or null.
func fire() -> Projectile:
	if _cooldown > 0.0 or projectile_scene == null:
		return null
	_cooldown = fire_interval

	var shot: Projectile = projectile_scene.instantiate()
	shot.launch(global_position + aim_direction * muzzle_offset, aim_direction, self)
	_shot_parent().add_child(shot)
	return shot


## Shots live beside the ship, not under the pirate, so they do not ride his
## transform around the room.
func _shot_parent() -> Node:
	var container := get_tree().get_first_node_in_group(&"projectiles")
	return container if container != null else get_parent()
