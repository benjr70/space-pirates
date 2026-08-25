class_name RoomTracker
extends Node
## Reports which room a body is standing in. Doorway tiles belong to no room, so
## the last real room is held onto while crossing a threshold.

signal room_changed(room: int, previous: int)

const TILE_SIZE := 32

var layout: ShipLayout
var target: Node2D
var current_room := -1


func setup(ship_layout: ShipLayout, tracked: Node2D) -> void:
	layout = ship_layout
	target = tracked
	current_room = -1


func _physics_process(_delta: float) -> void:
	if layout == null or target == null:
		return
	var tile := Vector2i(floori(target.global_position.x / TILE_SIZE), floori(target.global_position.y / TILE_SIZE))
	var room := layout.room_at(tile)
	if room == -1 or room == current_room:
		return
	var previous := current_room
	current_room = room
	room_changed.emit(room, previous)
