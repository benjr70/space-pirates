class_name Projectile3D
extends Area3D
## A single bolt. Travels in a straight line until it hits ship or crew.
##
## At 80 m/s it covers more than a body's width in one physics step, so
## every step sweeps a ray from where it was to where it is going and stops
## at the first thing in the way; the Area3D overlap only catches what it
## is born inside. Hitting the ship makes no sound.
##
## It is drawn as a tracer: a thin streak of light 2 m long lying along
## the flight, its bright tip at the bolt and its tail trailing behind, so
## both sides' fire reads as lines through the air rather than balls. The
## streak grows out of the muzzle: its tail never reaches back past where the
## bolt was launched, or a shot would begin as a flash through the shooter's
## own eyes.
##
## A bolt that strikes a crew member's [HeadZone] is a Headshot: it does its
## damage times its headshot multiplier, rounded, and says so in [signal
## hit]. The head is looked for along the same line as the body, so a head
## struck above the body capsule, or behind the capsule's surface on a bolt
## that strikes the capsule first, both count.

## [param on_head] when it struck a head zone, whatever its multiplier.
signal hit(target: Node3D, on_head: bool)

## Metres per second (was 760 px/s over 32 px tiles).
@export var speed := 23.75
@export var damage := 25
## Damage times this on a head zone: the shooter's Weapon Profile's, carried
## by the bolt since the Pirate and crew share it.
@export var headshot_multiplier := 1.0
## Seconds before it gives up, so strays never pile up off in the dark.
@export var lifetime := 1.6

## The streak reaches full width after this many of its own lengths.
const WIDTH_GROWTH := 2.0
## How far past where it strikes a body a bolt looks for that body's head:
## more than the capsule is thick.
const HEAD_DEPTH := 0.8

var direction := Vector3.FORWARD
## Whoever fired it, so the shot does not immediately hit them in the back.
var shooter: Node3D
## Shots pass straight through anyone on the shooter's own side.
var team: StringName = &""

var _age := 0.0
## Metres flown, which is as long as the streak's tail may be.
var _travelled := 0.0
## The streak at full length, as the scene draws it, and how far behind the
## bolt its tail then reaches.
var _streak_rest: Transform3D
var _tail_length := 0.0

@onready var _streak: MeshInstance3D = $Streak
## Struck once: the overlap may fire in the same frame as the sweep.
var _struck := false


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
	_streak_rest = _streak.transform
	_tail_length = (_streak_rest * _streak.get_aabb()).end.z
	_draw_streak()


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from + direction * speed * delta
	var blocked := _sweep(from, to)
	if not blocked.is_empty():
		global_position = blocked.position
		_strike(blocked.collider, blocked.get("head", false))
		return
	global_position = to
	_travelled += from.distance_to(to)
	_draw_streak()
	_age += delta
	if _age >= lifetime:
		queue_free()


## The streak squeezed along the flight toward the bolt, so its tail ends
## where the bolt started until it has flown the streak's whole length. It
## starts thin as well and fattens over twice that distance: a full-width
## tail a hand's breadth from the shooter's eye fills his view.
func _draw_streak() -> void:
	var grown := clampf(_travelled / _tail_length, 0.0, 1.0)
	var width := clampf(_travelled / (_tail_length * WIDTH_GROWTH), 0.0, 1.0)
	_streak.visible = grown > 0.0
	if grown > 0.0:
		_streak.transform = Transform3D(Basis.from_scale(Vector3(width, width, grown)) * _streak_rest.basis,
				_streak_rest.origin * grown)


## The first body on the way from [param from] to [param to] that this bolt
## can hit: not its shooter, not its shooter's side. `head` is true when it
## is a crew member struck on its head zone, which comes back as `collider`
## the crew member itself.
func _sweep(from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	if shooter is CollisionObject3D:
		params.exclude = [(shooter as CollisionObject3D).get_rid()]
	var space := get_world_3d().direct_space_state
	var found := space.intersect_ray(params)
	var body: Node3D = null
	if not found.is_empty():
		body = found.collider as Node3D
		if body == null or _passes_through(body):
			return {}
	# The head: nearer than whatever stopped the bolt, or that very body's
	# own head just behind where the bolt struck it.
	var head := _head_on_line(from, to if found.is_empty() else found.position + direction * HEAD_DEPTH)
	if not head.is_empty() and (head.collider == body or body == null
			or from.distance_to(head.position) < from.distance_to(found.position)):
		if head.collider == body:
			head.position = found.position
		return head
	if found.is_empty():
		return {}
	found.head = false
	return found


## The first head zone this bolt can hit from [param from] to [param to], as
## its owner struck on the head; empty for none.
func _head_on_line(from: Vector3, to: Vector3) -> Dictionary:
	var params := PhysicsRayQueryParameters3D.create(from, to, HeadZone.LAYER)
	params.collide_with_areas = true
	params.collide_with_bodies = false
	params.hit_from_inside = true
	var found := get_world_3d().direct_space_state.intersect_ray(params)
	var zone := found.get("collider") as HeadZone
	if zone == null or zone.body == null or zone.body == shooter or _passes_through(zone.body):
		return {}
	return {collider = zone.body, position = found.position, head = true}


## A bolt born inside a body, or grazing one with its own width: a
## Headshot if it was flying into that body's head.
func _on_body_entered(body: Node3D) -> void:
	if body == shooter or _passes_through(body):
		return
	var head := _head_on_line(global_position, global_position + direction * HEAD_DEPTH)
	_strike(body, head.get("collider") == body)


## Friendly fire passes through rather than stopping the shot dead.
func _passes_through(body: Node3D) -> bool:
	return body.has_method("get_team") and body.get_team() == team


func _strike(body: Node3D, on_head := false) -> void:
	if _struck:
		return
	_struck = true
	if body.has_method("take_damage"):
		body.take_damage(WeaponProfile.head_damage(damage, headshot_multiplier) if on_head else damage, shooter)
	hit.emit(body, on_head)
	queue_free()
