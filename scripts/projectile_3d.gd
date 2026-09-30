class_name Projectile3D
extends Area3D
## A single bolt. Travels in a straight line until it hits ship or crew.
##
## At 80 m/s it covers more than a body's width in one physics step, so
## every step sweeps a ray from where it was to where it is going and stops
## at the first thing in the way; the Area3D overlap only catches what it
## is born inside. Hitting the ship makes no sound.

signal hit(target: Node3D)

## Metres per second (was 760 px/s over 32 px tiles).
@export var speed := 23.75
@export var damage := 1
## Seconds before it gives up, so strays never pile up off in the dark.
@export var lifetime := 1.6

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
	var from := global_position
	var to := from + direction * speed * delta
	var blocked := _sweep(from, to)
	if not blocked.is_empty():
		global_position = blocked.position
		_strike(blocked.collider)
		return
	global_position = to
	_age += delta
	if _age >= lifetime:
		queue_free()


## The first body on the way from [param from] to [param to] that this bolt
## can hit: not its shooter, not its shooter's side.
func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	if shooter is CollisionObject3D:
		params.exclude = [(shooter as CollisionObject3D).get_rid()]
	var found := get_world_3d().direct_space_state.intersect_ray(params)
	if found.is_empty():
		return {}
	var body := found.collider as Node3D
	if body == null or _passes_through(body):
		return {}
	return found


func _on_body_entered(body: Node3D) -> void:
	if body == shooter or _passes_through(body):
		return
	_strike(body)


## Friendly fire passes through rather than stopping the shot dead.
func _passes_through(body: Node3D) -> bool:
	return body.has_method("get_team") and body.get_team() == team


func _strike(body: Node3D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, shooter)
	hit.emit(body)
	queue_free()
