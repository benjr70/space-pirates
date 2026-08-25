extends Node2D
## Builds the ship the pirate is standing in and drops him at its entry room.

## Leave null to use the hand-authored player ship.
@export var layout_override: ShipLayout

@onready var ship: Node2D = $Ship
@onready var player: CharacterBody2D = $Player

var layout: ShipLayout


func _ready() -> void:
	layout = layout_override if layout_override != null else PlayerShipLayout.create()
	ShipBuilder.build(layout, ship)
	player.global_position = ShipBuilder.room_center_world(layout.rooms[layout.entry_room])
