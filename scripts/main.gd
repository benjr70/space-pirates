extends Node2D
## Builds the ship the pirate is standing in, drops him at its entry room and
## lifts the darkness off rooms as he walks into them.

## Leave null to use the hand-authored player ship.
@export var layout_override: ShipLayout

@onready var ship: Node2D = $Ship
@onready var player: CharacterBody2D = $Player

var layout: ShipLayout
var tracker: RoomTracker


func _ready() -> void:
	layout = layout_override if layout_override != null else PlayerShipLayout.create()
	ShipBuilder.build(layout, ship)
	player.global_position = ShipBuilder.room_center_world(layout.rooms[layout.entry_room])
	player.spawn_point = player.global_position

	var fog: RoomFog = ship.get_node("Fog")
	tracker = RoomTracker.new()
	tracker.name = "RoomTracker"
	add_child(tracker)
	tracker.setup(layout, player)
	tracker.room_changed.connect(func(room: int, _previous: int) -> void: fog.reveal(room))
	fog.reveal(layout.entry_room)
