extends SceneTree
## PROTOTYPE — ASCII dumper for issue #4. Flip through silhouette seeds:
##
##   flatpak run org.godotengine.Godot --headless --path . \
##       --script res://scripts/proto/proto_silhouette_dump.gd -- [recipe] [class] [count] [first_seed]
##
## e.g. `-- B large 6 1`. With no args, dumps 4 seeds of every recipe at
## every class.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var recipes: Array = ["F"] if args.size() < 1 else [args[0]]
	var classes: Array = [&"small", &"medium", &"large"] if args.size() < 2 else [StringName(args[1])]
	var count := 4 if args.size() < 3 else int(args[2])
	var first := 1 if args.size() < 4 else int(args[3])

	for recipe: String in recipes:
		for ship_class: StringName in classes:
			for s in range(first, first + count):
				var layout := ProtoSilhouette.make_layout(recipe, ship_class, s)
				var rects: Array[Rect2i] = []
				for room in layout.rooms:
					rects.append(room.rect)
				var bounds: Rect2i = rects[0]
				for r in rects:
					bounds = bounds.merge(r)
				print("=== recipe %s  class %s  seed %d  |  %d rects, %d doors, %d tiles, %dx%d m ===" % [
						recipe, ship_class, s, rects.size(), layout.doors.size(),
						ProtoSilhouette.area_of(rects), bounds.size.x, bounds.size.y])
				print(layout.ship_name)
				print(ProtoSilhouette.ascii_layout(layout))
				var stranded := _unreachable_floor(layout)
				if stranded > 0:
					print("!!! %d floor tiles unreachable from entry" % stranded)
				print("")
	quit()


## Floor tiles a walker starting in the entry room can never reach.
func _unreachable_floor(layout: ShipLayout) -> int:
	var floors := layout.floor_tiles()
	var start: Vector2i = layout.rooms[layout.entry_room].rect.position
	var seen := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_back()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := tile + step
			if floors.has(next) and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	return floors.size() - seen.size()
