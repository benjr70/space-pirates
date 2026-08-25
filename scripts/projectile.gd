class_name Projectile
extends Area2D
## A single shot. Travels in a straight line until it hits ship or crew.

signal hit(target: Node2D)

@export var speed := 760.0
@export var damage := 1
## Seconds before it gives up, so strays never pile up off in the dark.
@export var lifetime := 1.6

var direction := Vector2.RIGHT
## Whoever fired it, so the shot does not immediately hit them in the back.
var shooter: Node2D

var _age := 0.0


## Aim and arm the shot. Call before adding it to the tree.
func launch(from: Vector2, aim: Vector2, by: Node2D) -> void:
	global_position = from
	direction = aim.normalized() if aim.length_squared() > 0.0 else Vector2.RIGHT
	shooter = by
	rotation = direction.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	hit.emit(body)
	queue_free()
