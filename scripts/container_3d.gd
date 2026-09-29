class_name Container3D
extends StaticBody3D
## A prop the pirate opens to take gold: a crate-sized Container or a
## full-height locker. Distinct from cover, though it blocks a sightline
## like any solid piece. The gold is set by the builder from the layout.

## Gold units inside, in the Loot Budget's units; what the pirate sees is
## [method displayed_gold].
@export var gold := 0


## The gold the pirate sees when opening this Container.
func displayed_gold() -> int:
	return Budgets.displayed_gold(gold)


func _ready() -> void:
	add_to_group(&"containers")
