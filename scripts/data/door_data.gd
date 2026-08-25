class_name DoorData
extends Resource
## A gap punched through the wall shared by two rooms.

## Index into [member ShipLayout.rooms].
@export var room_a: int = -1
@export var room_b: int = -1
## The wall tile the door replaces. Must sit in both rooms' wall rings.
@export var tile: Vector2i = Vector2i.ZERO
## True when the two rooms are stacked vertically, so the door slides sideways.
@export var horizontal: bool = true
@export var locked: bool = false
