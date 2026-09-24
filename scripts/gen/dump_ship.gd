extends SceneTree
## Print any seed's plan and sentence, headless:
##
##   flatpak run org.godotengine.Godot --headless --path . \
##       --script res://scripts/gen/dump_ship.gd -- [class] [seed] [count]
##
## e.g. `-- large 7` or `-- small 1 5`. With no args, one seed of every Class.


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var classes: Array[StringName] = ShipGenerator.CLASSES.duplicate()
	if args.size() >= 1 and args[0] != "all":
		classes = [StringName(args[0])]
	var first := 1 if args.size() < 2 else int(args[1])
	var count := 1 if args.size() < 3 else int(args[2])
	for ship_class in classes:
		for seed in range(first, first + count):
			var report := ShipGenerator.generate_report(ship_class, seed)
			print("=== " + ShipDumper.summary(report))
			print(ShipDumper.ascii(report.layout))
			print(ShipDumper.listing(report.layout))
			print("")
	quit()
