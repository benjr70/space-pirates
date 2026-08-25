class_name DoorData
extends Resource
## A gap punched through the wall shared by two rooms.

## Index into [member ShipLayout.rooms].
@export var room_a: int = -1
@export var room_b: int = -1
## The wall tile the door replaces. Must sit in both rooms' wall rings.
@export var tile: Vector2i = Vector2i.ZERO
## True when the two rooms are stacked vertically, so the doorway runs along X.
@export var horizontal: bool = true
## How many tiles wide the opening is. Wide enough that a fight can spill
## through it rather than funnelling into a single-file choke point.
@export var width: int = 2
@export var locked: bool = false


## Every wall tile this doorway replaces, starting at [member tile].
func tiles() -> Array[Vector2i]:
	var step := Vector2i.RIGHT if horizontal else Vector2i.DOWN
	var out: Array[Vector2i] = []
	for i in maxi(width, 1):
		out.append(tile + step * i)
	return out
