class_name ShipAlarm
extends Node
## The ship-wide Alarm: off until a crew member raises it at an
## [AlarmPanel], then on for the rest of the Raid. Raised, the Room lights
## turn red and pulse, every routine stops, Guards hunt the Pirate's last
## known position and Workers hide. Built by [ShipBuilder3D] as "Alarm";
## found through the "ship_alarm" group. See `CREW_AI.md`.

signal raised(at: Vector3)

const RED := Color(1.0, 0.12, 0.08)
## The red pulses this fast, and dims to this fraction at its low.
const PULSE_SPEED := 3.0
const PULSE_LOW := 0.55

var is_raised := false
## Where the Pirate was last known when it was raised.
var raised_at := Vector3.ZERO
var _lights: Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	add_to_group(&"ship_alarm")
	set_process(false)


func setup(lights: Array[OmniLight3D]) -> void:
	_lights = lights


## The ship's Alarm, or null on a scene with none.
static func of(tree: SceneTree) -> ShipAlarm:
	return tree.get_first_node_in_group(&"ship_alarm") as ShipAlarm


## Raises the Alarm with the Pirate last known at [param at]. Once only.
func raise(at: Vector3) -> void:
	if is_raised:
		return
	is_raised = true
	raised_at = at
	for light in _lights:
		light.light_color = RED
	for panel in get_tree().get_nodes_in_group(&"alarm_panels"):
		panel.show_raised()
	get_tree().call_group(&"crew", "on_alarm", at)
	set_process(true)
	raised.emit(at)


func _process(delta: float) -> void:
	_time += delta
	var pulse := lerpf(PULSE_LOW, 1.0, 0.5 + 0.5 * sin(_time * PULSE_SPEED))
	for light in _lights:
		light.light_color = RED * pulse
