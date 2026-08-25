class_name Door
extends Node2D
## A powered doorway filling the gap between two rooms.
##
## Sized from its [DoorData] rather than authored: the scene holds placeholder
## shapes that [method setup] resizes to the doorway span before it is added to
## the tree. Stand close and press the interact key to work it.

signal opened
signal closed
## Emitted when someone tries a locked door, for a sound or a nudge later.
signal refused

const TILE_SIZE := 32
const SLIDE_TIME := 0.18
## How far either side of the threshold the door can be reached from.
const REACH := 1.5 * TILE_SIZE

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


## Configure from layout data. Call before adding the door to the tree.
func setup(data: DoorData) -> void:
	_span = maxi(data.width, 1)
	_horizontal = data.horizontal
	locked = data.locked
	_apply_geometry()


func _apply_geometry() -> void:
	var length := _span * TILE_SIZE
	var thickness := float(TILE_SIZE)
	# `size` is measured along the doorway; `reach` also runs through it.
	var size := Vector2(length, thickness) if _horizontal else Vector2(thickness, length)
	var reach := Vector2(length, thickness + REACH * 2.0) if _horizontal \
			else Vector2(thickness + REACH * 2.0, length)

	var blocker_shape: RectangleShape2D = $Blocker/CollisionShape2D.shape
	blocker_shape.size = size
	var threshold_shape: RectangleShape2D = $Threshold/CollisionShape2D.shape
	threshold_shape.size = size
	var trigger_shape: RectangleShape2D = $Trigger/CollisionShape2D.shape
	trigger_shape.size = reach

	# Two halves that retract into the walls on either side.
	var half := length / 2.0
	var leaf := Vector2(half, thickness * 0.7) if _horizontal else Vector2(thickness * 0.7, half)
	var offset := Vector2(half / 2.0, 0.0) if _horizontal else Vector2(0.0, half / 2.0)
	_shape_leaf($LeafA, leaf)
	_shape_leaf($LeafB, leaf)
	$LeafA.position = -offset
	$LeafB.position = offset

	var edge := Vector2(0.0, thickness * 0.35) if _horizontal else Vector2(thickness * 0.35, 0.0)
	$LeafA/Trim.points = PackedVector2Array([-edge, edge])
	$LeafB/Trim.points = PackedVector2Array([-edge, edge])
	$LeafA/Trim.position = offset * 0.5
	$LeafB/Trim.position = -offset * 0.5
	_update_trim()


func _shape_leaf(leaf: Polygon2D, size: Vector2) -> void:
	var h := size / 2.0
	leaf.polygon = PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)
	])
	leaf.color = COLOR_PANEL


func _ready() -> void:
	$Trigger.body_entered.connect(_on_reach_entered)
	$Trigger.body_exited.connect(_on_reach_exited)
	$Threshold.body_entered.connect(func(_b: Node2D) -> void: _in_threshold += 1)
	$Threshold.body_exited.connect(func(_b: Node2D) -> void: _in_threshold = maxi(_in_threshold - 1, 0))


func _physics_process(_delta: float) -> void:
	if _nearby > 0 and Input.is_action_just_pressed("interact"):
		toggle()


func _on_reach_entered(_body: Node2D) -> void:
	_nearby += 1
	_update_trim()


func _on_reach_exited(_body: Node2D) -> void:
	_nearby = maxi(_nearby - 1, 0)
	_update_trim()


## True when someone is close enough to work the controls.
func in_reach() -> bool:
	return _nearby > 0


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
	$Blocker/CollisionShape2D.set_deferred("disabled", true)
	_slide(_span * TILE_SIZE / 2.0)
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
	$Blocker/CollisionShape2D.set_deferred("disabled", false)
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
	$LeafA/Trim.default_color = color
	$LeafB/Trim.default_color = color


## Retracts both leaves by [param distance] along the doorway.
func _slide(distance: float) -> void:
	var half := _span * TILE_SIZE / 4.0
	var axis := Vector2.RIGHT if _horizontal else Vector2.DOWN
	var a := axis * -(half + distance)
	var b := axis * (half + distance)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property($LeafA, "position", a, SLIDE_TIME).set_trans(Tween.TRANS_SINE)
	_tween.tween_property($LeafB, "position", b, SLIDE_TIME).set_trans(Tween.TRANS_SINE)
