class_name RoomReveal
extends Node3D
## Keeps unexplored rooms dark and their contents hidden, and lifts both the
## first time the pirate walks in. The 3D stand-in for the old 2D fog: crew in
## a room the pirate has never entered are invisible but still solid.

## Per-room light energy once revealed.
const LIT_ENERGY := 1.2
const REVEAL_TIME := 0.4

var layout: ShipLayout

var _lights := {}
var _contents := {}
## Things that walk between rooms; their visibility follows the room they are
## stood in, not the room they were spawned in.
var _mobiles: Array[Node3D] = []
var _revealed := {}


func setup(ship_layout: ShipLayout) -> void:
	layout = ship_layout
	_lights.clear()
	_contents.clear()
	_mobiles.clear()
	_revealed.clear()


## Lights start dark; the builder registers them before anything is revealed.
func register_light(room: int, light: Light3D) -> void:
	if not _lights.has(room):
		_lights[room] = []
	_lights[room].append(light)
	light.light_energy = 0.0


## Props hide until their room is revealed. Collision stays on, same as the 2D
## fog which hid crew without removing them.
func register_content(room: int, node: Node3D) -> void:
	if not _contents.has(room):
		_contents[room] = []
	_contents[room].append(node)
	if not _revealed.has(room):
		node.visible = false


## Crew move between rooms, so their visibility is polled from wherever they
## are stood each frame: hidden in the dark, seen the moment they step
## somewhere the pirate has been. The 2D fog gave exactly that for free by
## painting over rooms; this is the positional equivalent.
func register_mobile(node: Node3D) -> void:
	_mobiles.append(node)
	node.visible = false


func _process(_delta: float) -> void:
	if layout == null:
		return
	for i in range(_mobiles.size() - 1, -1, -1):
		var node := _mobiles[i]
		if not is_instance_valid(node):
			_mobiles.remove_at(i)
			continue
		var room := layout.room_at(ShipBuilder3D.world_to_tile(node.global_position))
		# A doorway belongs to no room; keep whatever visibility they had.
		if room != -1:
			node.visible = _revealed.has(room)


func is_revealed(room: int) -> bool:
	return _revealed.has(room)


## Turns the lights on and shows what the room holds. Permanent: the darkness
## never comes back, so this is idempotent.
func reveal(room: int) -> void:
	if _revealed.has(room):
		return
	_revealed[room] = true
	for light: Light3D in _lights.get(room, []):
		var tween := create_tween()
		tween.tween_property(light, "light_energy", LIT_ENERGY, REVEAL_TIME)
	for node: Node3D in _contents.get(room, []):
		if is_instance_valid(node):
			node.visible = true
