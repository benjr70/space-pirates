class_name RaidChecks
extends RefCounted
## The main menu and the Raid it starts: the menu offers Play and Exit, Play
## offers the three Ship Classes, and its backdrop is a generated ship. A
## Raid's seed rebuilds the same target every time it is boarded, which is
## what Retry stands on, and the ship scene boards it ahead of its own
## fallback. Going down raises the death screen instead of getting back up.
## Run from the headless 3D suite: `RaidChecks.run(_expect, root)`.

const SEED := 4242


## Throwaway profile the checks bank into, never the player's own. Named
## per process: every worktree of the project shares one user:// directory,
## so two suites running at once must not bank into the same file.
static var test_profile := "user://test_profile_%d.cfg" % OS.get_process_id()


static func run(expect: Callable, root: Node) -> void:
	Profile.path = test_profile
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_profile))
	Profile.load_saved()
	_check_levels(expect)
	_check_ledger(expect)
	_check_menu(expect, root)
	_check_raid(expect, root)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_profile))
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
	expect.call(Profile.xp == start.x + 3 * RaidLedger.KILL_XP + RaidLedger.EXTRACT_XP[&"large"] + RaidLedger.GHOST_XP[&"large"]
			and Profile.gold == start.y + 120, "ledger: extracting did not bank kill XP, the bonuses and the gold")
	Profile.load_saved()
	expect.call(Profile.gold == start.y + 120, "ledger: banked gold did not survive a reload from disk")
	# Stealth: an unaware kill is worth 150, a spotted one 100; Ghost only
	# with the Alarm never raised.
	var quiet := RaidLedger.new(&"medium")
	quiet.record_kill(true)
	quiet.record_kill(false)
	expect.call(quiet.kill_xp() == RaidLedger.UNAWARE_KILL_XP + RaidLedger.KILL_XP and RaidLedger.UNAWARE_KILL_XP == 150,
			"ledger: an unaware and a spotted kill are worth %d XP, want 250" % quiet.kill_xp())
	var before := Profile.xp
	quiet.settle_extracted()
	expect.call(Profile.xp - before == 250 + RaidLedger.EXTRACT_XP[&"medium"] + RaidLedger.GHOST_XP[&"medium"],
			"ledger: extracting unseen did not bank the Ghost bonus")
	var loud := RaidLedger.new(&"medium")
	loud.alarm_raised = true
	before = Profile.xp
	loud.settle_extracted()
	expect.call(Profile.xp - before == RaidLedger.EXTRACT_XP[&"medium"] and loud.ghost_xp() == 0,
			"ledger: extracting after the Alarm still banked the Ghost bonus")


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
	player.hit_landed.emit(victim, true, false)
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
	_check_kill_as_he_extracts(expect, root)
	_check_surrender_xp(expect, root)
	_check_ghost_with_bound(expect, root)
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
	expect.call(screen.detail_text().contains("Ghost"), "extract: the tally does not show the Ghost bonus earned")
	expect.call(root.get_tree().paused and not main.get_node("PauseMenu").enabled, "extract: the ship kept running under the extracted screen")
	expect.call(_has_button(screen, "NewRaid") and _has_button(screen, "Menu"), "extract: no New Raid or Main Menu")
	expect.call(not (screen.find_child("Retry", true, false) as Button).visible, "extract: offers a Retry after getting out")
	root.get_tree().paused = false
	root.remove_child(main)
	main.free()


## A kill in the last instant of the countdown is his: a bolt of his that
## fells a crew member in the physics step the pod casts off in is reported
## before the Raid is settled, not after the shot's report delay, when the
## settled ledger would drop it (raid-smoke-bugs ticket 09). The bolt is a
## real one from the Pirate's `fire()`, struck on the victim the way its
## sweep strikes, so it goes through the Pirate's own hit report.
static func _check_kill_as_he_extracts(expect: Callable, root: Node) -> void:
	var main: Node3D = load(Raid.RAID_SCENE).instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var extraction: Extraction = main.extraction
	var pod: BoardingPod = main.get_node("Ship/BoardingPod")
	var screen: RaidEndScreen = main.get_node("RaidEndScreen")
	player.global_position = pod.to_global(Vector3(0, 0, BoardingPod.COLLAR_Z + BoardingPod.DEPTH - 0.4))
	extraction.boarded = true
	extraction.begin()
	extraction._process(extraction.duration * 0.5)
	var victim: Crew3D = root.get_tree().get_nodes_in_group(&"crew")[0]
	victim.health.current = 1
	var shot: Projectile3D = player.fire()
	expect.call(shot != null, "extract: no shot for the kill in the countdown's last step")
	if shot != null:
		shot._strike(victim)
	# This suite's own projectiles container is the first in the group, so
	# the bolt lives outside the Raid scene: nothing of it outlives the check.
	for pellet: Projectile3D in player.last_pellets:
		if is_instance_valid(pellet):
			pellet.disarm()
	expect.call(not victim.is_alive(), "extract: the bolt did not fell the crew member")
	var xp_before := Profile.xp
	extraction._process(extraction.duration)
	expect.call(extraction.is_done, "extract: the countdown ran out without extracting after the kill")
	expect.call(main.ledger.kills == 1, "extract: a kill in the step the pod cast off in counted %d kills, want 1"
			% main.ledger.kills)
	var banked: int = Profile.xp - xp_before
	var want: int = main.ledger.kill_xp() + main.ledger.extract_xp() + main.ledger.ghost_xp()
	expect.call(main.ledger.kill_xp() > 0 and banked == want, "extract: banked %d XP with a kill in the last step, want %d with %d kill XP"
			% [banked, want, main.ledger.kill_xp()])
	expect.call(screen.detail_text().contains("(1 kill"), "extract: the tally does not show the kill in the last step: %s"
			% screen.detail_text().replace("\n", " / "))
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


## The living Workers aboard [param main]'s ship.
static func _workers(main: Node3D) -> Array[Crew3D]:
	var out: Array[Crew3D] = []
	for node in main.get_tree().get_nodes_in_group(&"crew"):
		var member := node as Crew3D
		if member != null and main.is_ancestor_of(member) and member.is_worker() and member.is_alive():
			out.append(member)
	return out


## [param worker] surrendered and stood [param away] from the Pirate.
static func _surrendered(worker: Crew3D, player: CharacterBody3D, away: Vector3) -> void:
	worker.global_position = player.global_position + away
	worker.perception.awareness = 1.0
	worker._enter(Crew3D.State.SURRENDER)


## The last frame of a hold on [param worker]: the interact key down, the
## Sandbox's bind time held (the hold itself, frame by frame, is the crew
## suite's `_check_bind_hold`).
static func _finish_hold(player: CharacterBody3D, worker: Crew3D) -> void:
	Input.action_press("interact")
	player._binding = worker
	player.bind_held = 0.0
	player._tick_bind(player.sandbox.bind_time)
	Input.action_release("interact")


## Surrender and Bound in a Raid (crew-combat ticket 24): the interact key
## goes to a Container he faces over a surrendered Worker beside him, and
## to the Worker he faces, with its prompt and an empty ring; binding adds
## 50 XP with a toast; killing a surrendered Worker and killing a Bound one
## each add 0, with a toast saying so; an unaware Worker's kill still adds
## 150.
static func _check_surrender_xp(expect: Callable, root: Node) -> void:
	Raid.ship_class = &"medium"
	var main: Node3D = load(Raid.RAID_SCENE).instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var hud: Hud = main.get_node("Hud")
	var ledger: RaidLedger = main.ledger
	var workers := _workers(main)
	expect.call(workers.size() >= 3, "surrender: the medium ship has %d Workers, want 3" % workers.size())
	var boxes := main.get_tree().get_nodes_in_group(&"containers").filter(func(b: Node) -> bool: return main.is_ancestor_of(b))
	if workers.size() < 3 or boxes.is_empty():
		root.remove_child(main)
		main.free()
		Raid.ship_class = &"small"
		return
	# The key goes to what he faces: a Container ahead, the Worker beside.
	var box: Container3D = boxes[0]
	var away := Vector3(1.2, 0, 0)
	player.global_position = box.global_position + away
	player.global_basis = Basis.looking_at(-away, Vector3.UP)
	var bound := workers[0]
	_surrendered(bound, player, Vector3(0, 0, 1.5))
	expect.call(main._prompt() == box.prompt_text() and player.bind_target() == null and player.can_interact(),
			"surrender: facing a Container, a surrendered Worker beside him took the key (prompt '%s')" % main._prompt())
	player.global_basis = Basis.looking_at(Vector3(0, 0, 1), Vector3.UP)
	expect.call(main._prompt() == main.BIND_PROMPT and main._prompt() == "Hold E to tie up" and player.bind_target() == bound
			and not player.can_interact() and main._bind_progress() == 0.0,
			"surrender: facing a surrendered Worker 1.5 m off, the HUD offers '%s' (ring %.2f)" % [main._prompt(), main._bind_progress()])
	player.global_position += Vector3(0, 0, -1.0)
	expect.call(main._prompt() != main.BIND_PROMPT and player.bind_target() == null,
			"surrender: 2.5 m from a surrendered Worker, the HUD still offers to tie it up")
	player.global_position += Vector3(0, 0, 1.0)
	# Binding: 50 XP and a toast.
	var xp := ledger.kept_xp()
	_finish_hold(player, bound)
	expect.call(bound.is_bound() and ledger.kept_xp() - xp == RaidLedger.BIND_XP and RaidLedger.BIND_XP == 50
			and ledger.bound == 1 and hud.toast_texts().has("+50 XP  bound"),
			"surrender: binding added %d XP (Bound %s, toasts %s), want 50" % [ledger.kept_xp() - xp, bound.is_bound(), hud.toast_texts()])
	expect.call(main._prompt() != main.BIND_PROMPT, "surrender: a Bound Worker is still offered to tie up")
	# Killing the Bound one: 0, said so.
	xp = ledger.kept_xp()
	bound.health.current = 1
	player._strike(bound)
	expect.call(not bound.is_alive() and ledger.kills == 1 and ledger.kept_xp() == xp and hud.toast_texts().has("+0 XP  it was Bound"),
			"surrender: killing a Bound Worker added %d XP (toasts %s), want 0 said so" % [ledger.kept_xp() - xp, hud.toast_texts()])
	# Killing a surrendered one: 0, said so.
	var kneeling := workers[1]
	_surrendered(kneeling, player, Vector3(0, 0, 1.5))
	xp = ledger.kept_xp()
	kneeling.health.current = 1
	player._strike(kneeling)
	expect.call(not kneeling.is_alive() and ledger.kills == 2 and ledger.kept_xp() == xp and hud.toast_texts().has("+0 XP  it had surrendered"),
			"surrender: killing a surrendered Worker added %d XP (toasts %s), want 0 said so" % [ledger.kept_xp() - xp, hud.toast_texts()])
	# An unaware Worker: 150 as ever.
	var unaware := workers[2]
	unaware.perception.awareness = 0.0
	unaware.global_position = player.global_position + Vector3(0, 0, 1.5)
	xp = ledger.kept_xp()
	unaware.health.current = 1
	player._strike(unaware)
	expect.call(not unaware.is_alive() and ledger.kept_xp() - xp == RaidLedger.UNAWARE_KILL_XP and RaidLedger.UNAWARE_KILL_XP == 150,
			"surrender: an unaware Worker's kill added %d XP, want 150" % (ledger.kept_xp() - xp))
	root.remove_child(main)
	main.free()
	Raid.ship_class = &"small"


## Two Workers Bound and the Alarm never raised: extracting earns the Ghost
## bonus and the bind XP, and the end screen shows 2 bound.
static func _check_ghost_with_bound(expect: Callable, root: Node) -> void:
	Raid.ship_class = &"medium"
	var main: Node3D = load(Raid.RAID_SCENE).instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	var extraction: Extraction = main.extraction
	var pod: BoardingPod = main.get_node("Ship/BoardingPod")
	var screen: RaidEndScreen = main.get_node("RaidEndScreen")
	var workers := _workers(main)
	expect.call(workers.size() >= 2, "ghost bound: the medium ship has %d Workers, want 2" % workers.size())
	for worker in workers.slice(0, 2):
		_surrendered(worker, player, Vector3(0, 0, -1.5))
		player.global_basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
		_finish_hold(player, worker)
		expect.call(worker.is_bound(), "ghost bound: a Worker was not Bound")
	var xp_before := Profile.xp
	player.global_position = pod.to_global(Vector3(0, 0, BoardingPod.COLLAR_Z + BoardingPod.DEPTH - 0.4))
	extraction.boarded = true
	extraction.begin()
	extraction._process(extraction.duration + 0.1)
	var ledger: RaidLedger = main.ledger
	var detail := screen.detail_text().replace("\n", " / ")
	expect.call(extraction.is_done and not ledger.alarm_raised and ledger.ghost_xp() == RaidLedger.GHOST_XP[&"medium"],
			"ghost bound: extracting after binding two Workers earned Ghost %d (Alarm %s)" % [ledger.ghost_xp(), ledger.alarm_raised])
	var want: int = 2 * RaidLedger.BIND_XP + RaidLedger.EXTRACT_XP[&"medium"] + RaidLedger.GHOST_XP[&"medium"]
	expect.call(Profile.xp - xp_before == want, "ghost bound: banked %d XP, want %d" % [Profile.xp - xp_before, want])
	expect.call(detail.contains("2 bound") and detail.contains(", %d Ghost)" % RaidLedger.GHOST_XP[&"medium"]),
			"ghost bound: the end screen does not show 2 bound and the Ghost bonus: %s" % detail)
	root.get_tree().paused = false
	root.remove_child(main)
	main.free()
	Raid.ship_class = &"small"
