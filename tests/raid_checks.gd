class_name RaidChecks
extends RefCounted
## The main menu and the Raid it starts: the menu offers Play and Exit, Play
## offers the three Ship Classes, and its backdrop is a generated ship. A
## Raid's seed rebuilds the same target every time it is boarded, which is
## what Retry stands on, and the ship scene boards it ahead of its own
## fallback. Going down raises the death screen instead of getting back up.
## Run from the headless 3D suite: `RaidChecks.run(_expect, root)`.

const SEED := 4242


static func run(expect: Callable, root: Node) -> void:
	_check_menu(expect, root)
	_check_raid(expect, root)


static func _check_menu(expect: Callable, root: Node) -> void:
	expect.call(ProjectSettings.get_setting("application/run/main_scene") == Raid.MENU_SCENE,
			"menu: the game does not launch into the main menu")
	var menu: Node3D = load(Raid.MENU_SCENE).instantiate()
	root.add_child(menu)
	var column := menu.get_node("UI/Root/Column")
	expect.call((column.get_node("Title") as Label).text == "SPACE PIRATE", "menu: no title")
	var home: Control = column.get_node("Home")
	var classes: Control = column.get_node("Classes")
	expect.call(home.visible and not classes.visible, "menu: does not open on Play and Exit")
	expect.call(home.has_node("Play") and home.has_node("Exit"), "menu: home lacks Play or Exit")
	(home.get_node("Play") as Button).pressed.emit()
	expect.call(classes.visible and not home.visible, "menu: Play did not offer the Ship Classes")
	for button in ["SmallShip", "MediumShip", "LargeShip", "Back"]:
		expect.call(classes.has_node(button), "menu: no %s button" % button)
	(classes.get_node("Back") as Button).pressed.emit()
	expect.call(home.visible, "menu: Back did not return to Play and Exit")
	var backdrop: MenuBackdrop = menu.get_node("Backdrop")
	expect.call(backdrop.layout != null and backdrop.layout.gen_seed > 0, "menu: backdrop is not a generated ship")
	expect.call(backdrop.get_node("Hull/Plates").multimesh.instance_count > 0, "menu: backdrop hull has no plating")
	root.remove_child(menu)
	menu.free()


static func _check_raid(expect: Callable, root: Node) -> void:
	expect.call(not Raid.is_active() and Raid.layout() == null, "raid: one is on before any was started")
	Raid.ship_class = &"small"
	Raid.seed = SEED
	var first := Raid.layout()
	var again := Raid.layout()
	expect.call(first.gen_seed == SEED and first.ship_class == &"small", "raid: layout is not the picked target")
	expect.call(first.ship_name == again.ship_name and first.rooms.size() == again.rooms.size()
			and first.floor_tiles() == again.floor_tiles(), "raid: the same seed built a different ship")

	var main: Node3D = load(Raid.RAID_SCENE).instantiate()
	root.add_child(main)
	expect.call(main.layout.gen_seed == SEED and main.layout.ship_class == &"small",
			"raid: the ship scene did not board the Raid's target")
	var player: CharacterBody3D = main.get_node("Player")
	var screen: DeathScreen = main.get_node("DeathScreen")
	expect.call(not screen.is_showing(), "raid: death screen up before dying")
	player.take_damage(player.health.max_health)
	expect.call(screen.is_showing(), "raid: no death screen when the pirate went down")
	expect.call(not player.auto_respawn and not player.is_alive(), "raid: the pirate got back up on his own")
	expect.call(not (main.get_node("Hud") as Hud).visible, "raid: the HUD stayed up over the death screen")
	expect.call(_has_button(screen, "Retry"), "raid: death screen has no Retry")
	expect.call(_has_button(screen, "Menu"), "raid: death screen has no way back to the menu")
	root.remove_child(main)
	main.free()
	Raid.seed = 0
	Raid.ship_class = &""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func _has_button(node: Node, button_name: String) -> bool:
	return node.find_child(button_name, true, false) is Button
