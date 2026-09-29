class_name Door3D
extends Node3D
## A powered leaf filling a gap in a wall: a doorway between two rooms, or a
## hatch through the hull that seals the ship until it is worked.
##
## Built from its layout data rather than authored: [method setup] creates the
## blocker, threshold and leaves sized to the doorway span before the door is
## added to the tree. Stand close and press the interact key to work it. The
## coloured trim of the 2D door became emissive leaf edges; the HUD carries the
## readable prompt instead.

signal opened
signal closed
## Emitted when someone tries a locked door, for a sound or a nudge later.
signal refused

const TILE := 1.0
## Doors fill the wall gap from floor to ceiling, so they follow the wall height.
const HEIGHT := ShipBuilder3D.WALL_HEIGHT
const SLIDE_TIME := 0.18
## How far either side of the threshold the door can be reached from.
const REACH := 1.75

const COLOR_PANEL := Color(0.22, 0.26, 0.34)
const COLOR_TRIM := Color(0.42, 0.47, 0.56)
## Brightened while someone is close enough to work it.
const COLOR_TRIM_HINT := Color(0.55, 0.85, 0.95)
const COLOR_TRIM_LOCKED := Color(0.72, 0.27, 0.27)

## Locked doors refuse to open -- the hook for keycards.
@export var locked := false

var is_open := false

var _span := 3
var _horizontal := true
## Bodies close enough to reach the controls.
var _nearby := 0
## Bodies standing in the doorway itself, who would be shut in.
var _in_threshold := 0
var _tween: Tween

var _blocker_shape: CollisionShape3D
var _leaf_a: MeshInstance3D
var _leaf_b: MeshInstance3D
var _trim_material: StandardMaterial3D


## Configure from a doorway between two rooms. Call before adding to the tree.
func setup(data: DoorData) -> void:
	setup_span(data.width, data.horizontal, data.locked)


## Configure from a hatch through the hull. Hatches are never locked: the
## pirate chose this one to board by.
func setup_hatch(data: HatchData) -> void:
	setup_span(data.width, data.horizontal, false)


## Size the leaf to a gap `width` tiles long, running along X when
## `horizontal`. Call before adding to the tree.
func setup_span(width: int, horizontal: bool, is_locked: bool) -> void:
	_span = maxi(width, 1)
	_horizontal = horizontal
	locked = is_locked
	_build_geometry()


## The doorway runs along X when horizontal, along Z otherwise; passage is the
## other axis. All shapes span the full wall height.
func _build_geometry() -> void:
	var length := _span * TILE
	var thickness := TILE
	var size := Vector3(length, HEIGHT, thickness) if _horizontal \
			else Vector3(thickness, HEIGHT, length)
	var reach_size := Vector3(length, HEIGHT, thickness + REACH * 2.0) if _horizontal \
			else Vector3(thickness + REACH * 2.0, HEIGHT, length)
	var center := Vector3(0.0, HEIGHT / 2.0, 0.0)

	var blocker := StaticBody3D.new()
	blocker.name = "Blocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	_blocker_shape = _box_shape(size)
	blocker.add_child(_blocker_shape)
	_blocker_shape.position = center
	add_child(blocker)

	var threshold := Area3D.new()
	threshold.name = "Threshold"
	threshold.collision_layer = 0
	threshold.collision_mask = 2
	var threshold_shape := _box_shape(size)
	threshold.add_child(threshold_shape)
	threshold_shape.position = center
	add_child(threshold)

	var trigger := Area3D.new()
	trigger.name = "Trigger"
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var trigger_shape := _box_shape(reach_size)
	trigger.add_child(trigger_shape)
	trigger_shape.position = center
	add_child(trigger)

	# Two leaves that retract into the walls on either side. Visual only; the
	# Blocker is what actually stops bodies, same as the 2D door.
	_trim_material = StandardMaterial3D.new()
	_trim_material.albedo_color = COLOR_PANEL
	_trim_material.emission_enabled = true
	var half := length / 2.0
	var leaf_size := Vector3(half, HEIGHT - 0.1, thickness * 0.7) if _horizontal \
			else Vector3(thickness * 0.7, HEIGHT - 0.1, half)
	_leaf_a = _leaf(leaf_size)
	_leaf_b = _leaf(leaf_size)
	add_child(_leaf_a)
	add_child(_leaf_b)
	_place_leaves(0.0)
	_update_trim()


func _box_shape(size: Vector3) -> CollisionShape3D:
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	return shape


func _leaf(size: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _trim_material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _ready() -> void:
	add_to_group(&"doors")
	var trigger: Area3D = $Trigger
	trigger.body_entered.connect(_on_reach_entered)
	trigger.body_exited.connect(_on_reach_exited)
	var threshold: Area3D = $Threshold
	threshold.body_entered.connect(func(_b: Node3D) -> void: _in_threshold += 1)
	threshold.body_exited.connect(func(_b: Node3D) -> void: _in_threshold = maxi(_in_threshold - 1, 0))


func _physics_process(_delta: float) -> void:
	if _nearby > 0 and Input.is_action_just_pressed("interact") and _a_body_can_interact():
		toggle()


## The interact key belongs to whoever is at the controls, and a body mid-move
## (a clambering pirate) cannot use them. Bodies without the hook never press it.
func _a_body_can_interact() -> bool:
	for body in $Trigger.get_overlapping_bodies():
		if body.has_method("can_interact") and body.can_interact():
			return true
	return false


func _on_reach_entered(_body: Node3D) -> void:
	_nearby += 1
	_update_trim()


func _on_reach_exited(_body: Node3D) -> void:
	_nearby = maxi(_nearby - 1, 0)
	_update_trim()


## True when someone is close enough to work the controls.
func in_reach() -> bool:
	return _nearby > 0


## What the HUD should offer whoever is stood at the controls.
func prompt_text() -> String:
	if locked:
		return "Hatch locked"
	return "E — Close hatch" if is_open else "E — Open hatch"


func toggle() -> void:
	if locked:
		refused.emit()
		return
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if locked or is_open:
		return
	is_open = true
	_blocker_shape.set_deferred("disabled", true)
	_slide(_span * TILE / 2.0)
	_update_trim()
	opened.emit()


## Refuses while someone is standing in the doorway, rather than shutting them in.
func close() -> bool:
	if not is_open:
		return false
	if _in_threshold > 0:
		refused.emit()
		return false
	is_open = false
	_blocker_shape.set_deferred("disabled", false)
	_slide(0.0)
	_update_trim()
	closed.emit()
	return true


func _update_trim() -> void:
	var color := COLOR_TRIM
	if locked:
		color = COLOR_TRIM_LOCKED
	elif _nearby > 0:
		color = COLOR_TRIM_HINT
	_trim_material.emission = color
	_trim_material.emission_energy_multiplier = 0.6


## Retracts both leaves by [param distance] along the doorway.
func _slide(distance: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	var half := _span * TILE / 4.0
	var axis := Vector3.RIGHT if _horizontal else Vector3.BACK
	var a := axis * -(half + distance) + Vector3.UP * (HEIGHT / 2.0)
	var b := axis * (half + distance) + Vector3.UP * (HEIGHT / 2.0)
	_tween.tween_property(_leaf_a, "position", a, SLIDE_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_leaf_b, "position", b, SLIDE_TIME).set_trans(Tween.TRANS_SINE)


func _place_leaves(distance: float) -> void:
	var half := _span * TILE / 4.0
	var axis := Vector3.RIGHT if _horizontal else Vector3.BACK
	_leaf_a.position = axis * -(half + distance) + Vector3.UP * (HEIGHT / 2.0)
	_leaf_b.position = axis * (half + distance) + Vector3.UP * (HEIGHT / 2.0)
