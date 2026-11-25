class_name LaserDot
extends Node
## The Laser's dot (`.scratch/weapon-attachments/spec.md`, "The Laser"): with
## a Laser fitted to the weapon in hand, a small red dot on the first surface
## or body along the gun's line, from the Laser's `Laser_Origin` marker down
## the barrel, at the hip and aimed, out to [constant REACH]. Beyond that,
## nothing; no beam. Hidden while the weapon is lowered for a Sprint or a
## Clamber, and during a swap.
##
## A visual for the player only: the dot is a bare mesh with nothing for a
## ray, a bolt or a crew member's eyes to meet (crew noticing him sooner is
## the Laser's conspicuous factor on Awareness), and the ray leaves the
## Pirate himself out. The dot draws on the world's layer, not the
## Viewmodel's, so a scope's lens camera shows it too: it is in the world.

## How far the dot reaches, in metres.
const REACH := 30.0
## What the gun's line stops on: the ship (layer 1) and bodies such as the
## crew (layer 2). Bolts (layer 4) and areas do not take the dot.
const MASK := 1 | 2
## The dot's radius as it would be 1 m from the eye: it is drawn at a fixed
## size on screen whatever its distance, so it stays a small dot at 30 m.
const SIZE := 0.006
const COLOUR := Color(1.0, 0.06, 0.04)
## The render layer it draws on: the world's, which every camera sees.
const LAYER := 1

## The dot itself, at the point the gun's line meets; hidden when there is none.
var dot: MeshInstance3D

var _pirate: CharacterBody3D
var _viewmodel: Viewmodel
var _laser: Attachment = preload("res://resources/attachments/laser.tres")
## The fitted Laser's `Laser_Origin` on the gun in hand, or null.
var _origin: Node3D


func _ready() -> void:
	_pirate = get_parent() as CharacterBody3D
	_viewmodel = _pirate.get_node("Head/Camera3D/Weapon")

	var ball := SphereMesh.new()
	ball.radius = SIZE
	ball.height = SIZE * 2.0
	ball.radial_segments = 12
	ball.rings = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = COLOUR
	material.fixed_size = true
	material.disable_receive_shadows = true
	dot = MeshInstance3D.new()
	dot.name = "Dot"
	dot.mesh = ball
	dot.material_override = material
	dot.layers = 1 << (LAYER - 1)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.top_level = true
	dot.visible = false
	add_child(dot)

	_viewmodel.mounted.connect(_on_mounted)
	_on_mounted()


## The dot is showing on something within reach.
func shown() -> bool:
	return dot.visible


## A new gun or Built Weapon in hand: find its Laser, if it has one.
func _on_mounted() -> void:
	var fitting := _viewmodel.fitting
	var model := fitting.model_of(_laser) if fitting != null else null
	_origin = model.get_node_or_null("Laser_Origin") as Node3D if model != null else null


func _process(_delta: float) -> void:
	dot.visible = false
	if _origin == null or _pirate.is_swapping() \
			or _pirate.state in [_pirate.State.SPRINT, _pirate.State.CLAMBER]:
		return
	# The barrel runs down the Viewmodel's +Z, the muzzle ahead of the grip.
	var from := _origin.global_position
	var to := from + _viewmodel.global_basis.z.normalized() * REACH
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK, [_pirate.get_rid()])
	var hit := _pirate.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	dot.global_position = hit.position
	dot.visible = true
