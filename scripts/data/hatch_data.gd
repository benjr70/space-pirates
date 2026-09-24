class_name HatchData
extends Resource
## A gap punched through the Hull, joining one Room to the outside. How a Raid
## begins and ends: the pirate boards through a Hatch and extracts through one.
##
## Shares [DoorData]'s span contract -- a start tile on the wall ring plus a
## direction and width -- so builders size both the same way. Which side is
## the Room is not stored: it follows from the Room, see [method inward].

## Index into [member ShipLayout.rooms]: the one Room this Hatch opens into.
@export var room: int = -1
## The Hull wall tile the Hatch replaces. Must sit in the Room's wall ring.
@export var tile: Vector2i = Vector2i.ZERO
## True when the Hull wall runs along X here, so the gap does too and the
## pirate passes through along Y (3D z).
@export var horizontal: bool = true
## How many tiles wide the gap is. Hatches are two wide: wide enough to fight
## through, narrow enough to read as a door rather than a bay.
@export var width: int = 2


## Every wall tile this Hatch replaces, starting at [member tile].
func tiles() -> Array[Vector2i]:
	var step := Vector2i.RIGHT if horizontal else Vector2i.DOWN
	var out: Array[Vector2i] = []
	for i in maxi(width, 1):
		out.append(tile + step * i)
	return out


## The one-tile step from the Hatch into [param room]'s floor, or ZERO when
## the Hatch does not touch that Room on either side.
func inward(room_data: RoomData) -> Vector2i:
	var sides: Array[Vector2i] = []
	if horizontal:
		sides = [Vector2i.UP, Vector2i.DOWN]
	else:
		sides = [Vector2i.LEFT, Vector2i.RIGHT]
	for step: Vector2i in sides:
		if room_data.has_tile(tile + step):
			return step
	return Vector2i.ZERO
