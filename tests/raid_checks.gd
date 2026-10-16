class_name RaidChecks
extends RefCounted
## The main menu and the Raid it starts: the menu offers Play and Exit, Play
## offers the three Ship Classes, and its backdrop is a generated ship. A
## Raid's seed rebuilds the same target every time it is boarded, which is
## what Retry stands on, and the ship scene boards it ahead of its own
## fallback. Going down raises the death screen instead of getting back up.
## Run from the headless 3D suite: `RaidChecks.run(_expect, root)`.

const SEED := 4242


## Throwaway profile the checks bank into, never the player's own.
const TEST_PROFILE := "user://test_profile.cfg"


static func run(expect: Callable, root: Node) -> void:
	Profile.path = TEST_PROFILE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	Profile.load_saved()
	_check_levels(expect)
	_check_ledger(expect)
	_check_menu(expect, root)
	_check_raid(expect, root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	Profile.load_saved()


## Level 1 at 0 XP, each level taking 500 more than the last.
static func _check_levels(expect: Callable) -> void:
	for pair in [[0, 1], [499, 1], [500, 2], [1499, 2], [1500, 3], [2999, 3], [3000, 4]]:
		expect.call(Profile.level_for(pair[0]) == pair[1],
				"profile: %d XP is level %d, want %d" % [pair[0], Profile.level_for(pair[0]), pair[1]])
	expect.call(Profile.level_progress(700) == Vector2i(200, 1000), "profile: 700 XP is not 200 of 1000 into level 2")


## XP is kept either way; gold only by extracting. A settled Raid stays settled.
static func _check_ledger(expect: Callable) -> void:
	var start := Vector2i(Profile.xp, Profile.gold)
	var lost := RaidLedger.new(&"small")
	lost.record_kill()
	lost.record_kill()
	lost.carry(70)
	lost.settle_lost()
	lost.record_kill()
	lost.carry(10)
	lost.settle_extracted()
	expect.call(Profile.xp == start.x + 2 * RaidLedger.KILL_XP and Profile.gold == start.y,
			"ledger: dying banked %d XP and %d gold, want 200 and none" % [Profile.xp - start.x, Profile.gold - start.y])
	var won := RaidLedger.new(&"large")
	won.record_kill()
	won.carry(120)
	won.settle_extracted()
	expect.call(Profile.xp == start.x + 3 * RaidLedger.KILL_XP + RaidLedger.EXTRACT_XP[&"large"]
			and Profile.gold == start.y + 120, "ledger: extracting did not bank kill XP, the bonus and the gold")
	Profile.load_saved()
	expect.call(Profile.gold == start.y + 120, "ledger: banked gold did not survive a reload from disk")


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
	var pause: PauseMenu = main.get_node("PauseMenu")
	expect.call(not pause.is_showing() and not root.get_tree().paused, "raid: starts paused")
	pause.pause()
	expect.call(pause.is_showing() and root.get_tree().paused, "raid: pause did not freeze the ship")
	expect.call(not player.can_process() and pause.can_process(), "raid: pause froze the menu or not the pirate")
	expect.call(_has_button(pause, "Resume") and _has_button(pause, "Menu"), "raid: pause menu lacks Resume or Main Menu")
	pause.resume()
	expect.call(not pause.is_showing() and not root.get_tree().paused, "raid: Resume did not unfreeze the ship")
	var screen: RaidEndScreen = main.get_node("RaidEndScreen")
	expect.call(not screen.is_showing(), "raid: death screen up before dying")
	var before := Vector2i(Profile.xp, Profile.gold)
	var victim: Node3D = root.get_tree().get_nodes_in_group(&"crew")[0]
	player.hit_landed.emit(victim, true)
	main.ledger.carry(50)
	player.take_damage(player.health.max_health)
	expect.call(Profile.xp == before.x + RaidLedger.KILL_XP and Profile.gold == before.y,
			"raid: dying did not keep the kill XP and drop the gold")
	expect.call(screen.title_text() == "YOU DIED", "raid: no death screen when the pirate went down")
	expect.call(not player.auto_respawn and not player.is_alive(), "raid: the pirate got back up on his own")
	expect.call(not (main.get_node("Hud") as Hud).visible, "raid: the HUD stayed up over the death screen")
	expect.call(_has_button(screen, "Retry"), "raid: death screen has no Retry")
	expect.call(_has_button(screen, "Menu"), "raid: death screen has no way back to the menu")
	pause.pause()
	expect.call(not pause.is_showing() and not root.get_tree().paused, "raid: paused over the death screen")
	root.remove_child(main)
	main.free()
	_check_extraction(expect, root)
	Raid.seed = 0
	Raid.ship_class = &""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Out through the pod: not before he has been aboard, not from where he
## starts, called off by stepping out, and ending the Raid at zero.
static func _check_extraction(expect: Callable, root: Node) -> void:
	var main: Node3D = load(Raid.RAID_SCENE).instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var extraction: Extraction = main.extraction
	var pod: BoardingPod = main.get_node("Ship/BoardingPod")
	var screen: RaidEndScreen = main.get_node("RaidEndScreen")
	expect.call(extraction != null, "extract: no extraction on a ship with a pod")
	expect.call(not pod.at_home_door(player.global_position), "extract: the home door is in reach from the spawn point")
	_check_search(expect, main)
	var gold_before := Profile.gold
	var carried: int = main.ledger.carried_gold
	var home := pod.to_global(Vector3(0, 0, BoardingPod.COLLAR_Z + BoardingPod.DEPTH - 0.4))
	player.global_position = home
	expect.call(pod.at_home_door(home) and not extraction.can_begin(), "extract: offered before he set foot aboard")
	extraction.boarded = true
	expect.call(extraction.can_begin() and main._prompt() == "E — Extract", "extract: not offered at the home door")
	extraction.begin()
	expect.call(extraction.is_counting(), "extract: working the home door started no countdown")
	var hatch: HatchData = main.layout.hatches[main.entry_hatch]
	player.global_position = ShipBuilder3D.hatch_entry_world(main.layout, hatch)
	extraction._process(0.1)
	expect.call(not extraction.is_counting() and not extraction.is_done, "extract: stepping out of the pod did not call it off")
	player.global_position = home
	extraction.begin()
	extraction._process(extraction.duration * 0.5)
	expect.call(extraction.is_counting() and not screen.is_showing(), "extract: ended halfway through the countdown")
	extraction._process(extraction.duration)
	expect.call(extraction.is_done and screen.title_text() == "EXTRACTED", "extract: the countdown ran out without extracting")
	expect.call(carried > 0 and Profile.gold == gold_before + carried, "extract: the carried gold was not banked")
	expect.call(root.get_tree().paused and not main.get_node("PauseMenu").enabled, "extract: the ship kept running under the extracted screen")
	expect.call(_has_button(screen, "NewRaid") and _has_button(screen, "Menu"), "extract: no New Raid or Main Menu")
	expect.call(not (screen.find_child("Retry", true, false) as Button).visible, "extract: offers a Retry after getting out")
	root.get_tree().paused = false
	root.remove_child(main)
	main.free()


static func _has_button(node: Node, button_name: String) -> bool:
	return node.find_child(button_name, true, false) is Button


## Standing at a Container and facing it offers a search; searching takes
## its gold once into the carried loot and leaves it empty.
static func _check_search(expect: Callable, main: Node3D) -> void:
	var player: CharacterBody3D = main.get_node("Player")
	var boxes := main.get_tree().get_nodes_in_group(&"containers")
	expect.call(not boxes.is_empty(), "loot: the raid ship has no Containers")
	if boxes.is_empty():
		return
	var box: Container3D = boxes[0]
	var worth := box.displayed_gold()
	var away := Vector3(1.2, 0, 0)
	player.global_position = box.global_position + away
	player.global_basis = Basis.looking_at(-away, Vector3.UP)
	expect.call(main._container_in_reach() == box and main._prompt() == "E — Search",
			"loot: facing a Container does not offer a search (prompt '%s')" % main._prompt())
	player.global_basis = Basis.looking_at(away, Vector3.UP)
	expect.call(main._container_in_reach() != box, "loot: a Container behind him can be searched")
	main.search(box)
	expect.call(worth > 0 and main.ledger.carried_gold == worth, "loot: searching carried %d gold, the Container held %d" % [main.ledger.carried_gold, worth])
	expect.call((main.get_node("Hud") as Hud).loot_text().contains(str(worth)), "loot: the HUD does not show the carried gold")
	main.search(box)
	expect.call(main.ledger.carried_gold == worth and box.is_open and box.prompt_text() == "Empty",
			"loot: a searched Container gave gold twice")
