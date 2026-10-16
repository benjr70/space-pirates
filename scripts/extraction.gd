class_name Extraction
extends Node
## Getting out: once the pirate has been aboard, working the home door at
## the back of his Boarding Pod starts a countdown he must wait out inside
## the tube. Stepping out of the pod or going down calls it off; reaching
## zero ends the Raid as extracted.

signal started
signal cancelled
signal extracted

## Seconds the pod takes to cast off once the home door is worked.
@export var duration := 5.0

var pod: BoardingPod
var player: Node3D
## He has set foot in the ship: there is nothing to extract from before.
var boarded := false
var is_done := false

var _left := -1.0


func setup(boarding_pod: BoardingPod, pirate: Node3D) -> void:
	pod = boarding_pod
	player = pirate


func is_counting() -> bool:
	return _left >= 0.0


func time_left() -> float:
	return maxf(_left, 0.0)


## Whether the pirate is stood where working the home door would start one.
func can_begin() -> bool:
	return boarded and not is_done and not is_counting() and player.is_alive() \
			and pod.at_home_door(player.global_position)


func begin() -> void:
	if not can_begin():
		return
	_left = duration
	pod.set_extracting(true)
	started.emit()


func cancel() -> void:
	if not is_counting():
		return
	_left = -1.0
	pod.set_extracting(false)
	cancelled.emit()


func _process(delta: float) -> void:
	if not is_counting():
		return
	if not player.is_alive() or not pod.contains(player.global_position):
		cancel()
		return
	_left -= delta
	if _left <= 0.0:
		_left = -1.0
		is_done = true
		extracted.emit()
