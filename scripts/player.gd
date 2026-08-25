extends CharacterBody2D
## Top-down spaceman controlled with WASD (or arrow keys).

## Top speed in pixels per second.
@export var max_speed: float = 165.0
## How quickly the spaceman gets up to speed, in pixels per second squared.
@export var acceleration: float = 1400.0
## How quickly he coasts to a stop when there is no input.
@export var friction: float = 1400.0
## Rotate the sprite to face the direction of travel.
@export var face_movement: bool = true

@onready var sprite: Sprite2D = $Sprite2D


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if direction != Vector2.ZERO:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
		if face_movement:
			# The sprite art points up, so offset by 90 degrees.
			sprite.rotation = lerp_angle(sprite.rotation, direction.angle() + PI / 2.0, 12.0 * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()
