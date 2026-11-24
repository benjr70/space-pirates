class_name HeadZone
extends Area3D
## A crew member's head: a ball riding the rig's head bone, separate from the
## body capsule, so a bolt that strikes it is a Headshot. Crew wear it at
## spawn ([method attach]); the Pirate has none, so nothing that strikes him
## is a Headshot.
##
## It sits on its own physics layer that only a bolt's head check looks at
## ([method Projectile3D._sweep]), with bodies-only rays and the crew's own
## movement blind to it. The capsule stays the body: the rigs stand 2 m tall
## over a 1.7 m capsule, so a head can be struck above the capsule, or behind
## its surface by a bolt that strikes the capsule first.

## Physics layer 4: heads, and nothing else.
const LAYER := 8
## The bone it rides on every crew rig.
const BONE := &"Head"
## The ball's radius, metres: the soldier's head is about 0.26 m across and
## 0.31 m tall, the engineer's about 0.33 by 0.36 with its cap.
const RADIUS := 0.16
## How far above the head bone, along the bone, the ball's centre sits: the
## bone is the base of the skull.
const LIFT := 0.14

## Whose head this is.
var body: Node3D

var _shape: CollisionShape3D


## A head zone on [param skeleton]'s head bone, for [param owner_body].
## Returns null when the skeleton has no head bone.
static func attach(skeleton: Skeleton3D, owner_body: Node3D) -> HeadZone:
	var bone := skeleton.find_bone(BONE)
	if bone < 0:
		return null
	var follow := BoneAttachment3D.new()
	follow.name = "HeadAttachment"
	follow.bone_name = BONE
	skeleton.add_child(follow)
	var zone := HeadZone.new()
	zone.name = "HeadZone"
	zone.body = owner_body
	# Rigs come in their author's units, so the skeleton may be scaled a
	# hundredfold: undo that, so the ball is RADIUS in metres.
	var scale := (skeleton.global_transform * skeleton.get_bone_global_rest(bone)).basis.get_scale()
	zone.scale = Vector3.ONE / scale
	zone.position = Vector3(0.0, LIFT / scale.y, 0.0)
	follow.add_child(zone)
	return zone


func _init() -> void:
	collision_layer = LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true
	_shape = CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = RADIUS
	_shape.shape = ball
	add_child(_shape)


## A dead crew member's head is no target.
func disable() -> void:
	_shape.set_deferred("disabled", true)
