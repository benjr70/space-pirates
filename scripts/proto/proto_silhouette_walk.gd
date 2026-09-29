extends Node3D
## PROTOTYPE — walk a silhouette candidate in first person (issue #4).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_silhouette_walk.tscn \
##       -- recipe=B class=large seed=3
##
## Sections become bare Rooms with doorways at every seam; fore floor is
## bright (bridge), aft is engine-orange, so you can read orientation from
## inside. No crew, no props — this judges shape only.

@export var recipe := "B"
@export var ship_class: StringName = &"medium"
@export var walk_seed := 1


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"recipe":
				recipe = kv[1]
			"class":
				ship_class = StringName(kv[1])
			"seed":
				walk_seed = int(kv[1])

	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	main.layout_override = ProtoSilhouette.make_layout(recipe, ship_class, walk_seed)
	main.explore_darkness = false
	add_child(main)
	print("walking %s" % main.layout_override.ship_name)
