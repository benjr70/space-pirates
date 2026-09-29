class_name Projectile3D
extends Area3D
## A single bolt. Travels in a straight line until it hits ship or crew.

signal hit(target: Node3D)

## Metres per second (was 760 px/s over 32 px tiles).
@export var speed := 23.75
@export var damage := 1
## Seconds before it gives up, so strays never pile up off in the dark.
@export var lifetime := 1.6
## What a bolt sounds like hitting the ship itself, and how loud.
@export var impact_volume_db := -10.0
@export var impact_pitch_spread := 0.08
@export var impact_streams: Array[AudioStream] = [
	preload("res://assets/audio/kenney_impact/impactMetal_medium_000.ogg"),
	preload("res://assets/audio/kenney_impact/impactMetal_medium_001.ogg"),
	preload("res://assets/audio/kenney_impact/impactMetal_medium_002.ogg"),
]

var direction := Vector3.FORWARD
## Whoever fired it, so the shot does not immediately hit them in the back.
var shooter: Node3D
## Shots pass straight through anyone on the shooter's own side.
var team: StringName = &""

var _age := 0.0


## Aim and arm the shot. Call before adding it to the tree, which is why this
## sets the local transform: the projectile container sits at the origin.
func launch(from: Vector3, aim: Vector3, by: Node3D, of_team: StringName = &"") -> void:
	direction = aim.normalized() if aim.length_squared() > 0.0 else Vector3.FORWARD
	shooter = by
	team = of_team
	position = from
	if not direction.cross(Vector3.UP).is_zero_approx():
		basis = Basis.looking_at(direction)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == shooter:
		return
	# Friendly fire passes through rather than stopping the shot dead.
	if body.has_method("get_team") and body.get_team() == team:
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, shooter)
	else:
		_ring_impact()
	hit.emit(body)
	queue_free()


## A metal impact where the bolt struck, left behind to finish on its own.
func _ring_impact() -> void:
	if impact_streams.is_empty():
		return
	SoundAt.play(get_parent(), global_position, impact_streams.pick_random(),
			impact_volume_db, impact_pitch_spread, "Impact")
