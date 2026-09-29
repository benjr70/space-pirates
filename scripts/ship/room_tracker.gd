class_name RoomTracker
extends Node
## Reports which room a body is standing in. Doorway tiles belong to no room, so
## the last real room is held onto while crossing a threshold.

signal room_changed(room: int, previous: int)

const TILE_SIZE := 32

var layout: ShipLayout
## Either a Node2D (tiles are 32 px) or a Node3D (tiles are 1 m on XZ).
var target: Node
var current_room := -1


func setup(ship_layout: ShipLayout, tracked: Node) -> void:
	layout = ship_layout
	target = tracked
	current_room = -1


func _physics_process(_delta: float) -> void:
	if layout == null or target == null:
		return
	var tile: Vector2i
	if target is Node3D:
		tile = ShipBuilder3D.world_to_tile((target as Node3D).global_position)
	else:
		var pos: Vector2 = (target as Node2D).global_position
		tile = Vector2i(floori(pos.x / TILE_SIZE), floori(pos.y / TILE_SIZE))
	var room := layout.room_at(tile)
	if room == -1 or room == current_room:
		return
	var previous := current_room
	current_room = room
	room_changed.emit(room, previous)
