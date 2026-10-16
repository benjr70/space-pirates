class_name Container3D
extends StaticBody3D
## A prop the pirate opens to take gold: a crate-sized Container or a
## full-height locker. Distinct from cover, though it blocks a sightline
## like any solid piece. The gold is set by the builder from the layout.
## Opening one hands its gold over once and leaves it dark and empty.

const REACH := 1.8
## How squarely he must face it to work it, as a dot of facing and direction.
const FACING := 0.5
const COLOR_EMPTY := Color(0.18, 0.2, 0.2)

## Gold units inside, in the Loot Budget's units; what the pirate sees is
## [method displayed_gold].
@export var gold := 0

var is_open := false


## The gold the pirate sees when opening this Container.
func displayed_gold() -> int:
	return Budgets.displayed_gold(gold)


func _ready() -> void:
	add_to_group(&"containers")


## Whether a pirate at [param body], facing [param forward], can work it.
func in_reach(body: Node3D, forward: Vector3) -> bool:
	var to := global_position - body.global_position
	to.y = 0.0
	if to.length() > REACH:
		return false
	var flat := Vector3(forward.x, 0.0, forward.z).normalized()
	return to.length() < 0.6 or flat.dot(to.normalized()) >= FACING


func prompt_text() -> String:
	return "Empty" if is_open else "E — Search"


## Hands over its gold, once: every later call returns 0.
func open() -> int:
	if is_open:
		return 0
	is_open = true
	var taken := displayed_gold()
	gold = 0
	var mesh := get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		var dark := StandardMaterial3D.new()
		dark.albedo_color = COLOR_EMPTY
		mesh.material_override = dark
	return taken
