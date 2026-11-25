class_name LoadoutChecks
extends RefCounted
## The Loadout: two different weapons, each as fitted, kept in the profile
## file beside XP and gold, dropping anything stale quietly on load; and a
## Raid from the main menu carrying its two Built Weapons, the first in hand,
## keys 1 and 2 and the wheel between them, a Retry carrying the same two.
## Run from the pirate suite: `await LoadoutChecks.run(_expect, self)`, with
## the suite's own course paused, so the keys reach only the Raid's Pirate.

const PISTOL: WeaponProfile = preload("res://resources/weapons/pistol.tres")
const ASSAULT_RIFLE: WeaponProfile = preload("res://resources/weapons/assault_rifle.tres")
const SHOTGUN: WeaponProfile = preload("res://resources/weapons/shotgun.tres")
const MARKSMAN_RIFLE: WeaponProfile = preload("res://resources/weapons/marksman_rifle.tres")
const SUPPRESSOR: Attachment = preload("res://resources/attachments/suppressor.tres")
const DRUM: Attachment = preload("res://resources/attachments/drum.tres")
const SHORT_BARREL: Attachment = preload("res://resources/attachments/short_barrel.tres")
const REFLEX_SIGHT: Attachment = preload("res://resources/attachments/reflex_sight.tres")
const FRAME := 1.0 / 60.0


static func run(expect: Callable, tree: SceneTree) -> void:
	var saved_path := Profile.path
	Profile.path = RaidChecks.test_profile
	_forget(expect)
	_check_default(expect)
	_check_round_trip(expect)
	_check_place_swap(expect)
	_check_stale(expect)
	_check_uncarried_keeps(expect)
	_check_beside_xp_and_gold(expect)
	_forget(expect)
	await _check_raid_default(expect, tree)
	await _check_raid_fitted(expect, tree)
	_forget(expect)
	Profile.path = saved_path
	Profile.load_saved()


## No profile file at all.
static func _forget(_expect: Callable) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	Profile.load_saved()


static func _write(lines: String) -> void:
	var file := FileAccess.open(Profile.path, FileAccess.WRITE)
	file.store_string(lines)
	file.close()


## Every stored field of [param built] equals [param bare]'s, and nothing is
## fitted: the bare gun as a Built Weapon.
static func _is_bare(built: WeaponProfile, bare: WeaponProfile) -> bool:
	if built == null or not built.attachments.is_empty():
		return false
	for property in bare.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and not String(property.name).begins_with("resource_"):
			if built.get(property.name) != bare.get(property.name):
				return false
	return true


static func _empty_everywhere(loadout: Loadout) -> bool:
	for weapon in Loadout.all_weapons():
		for slot: Attachment.Slot in Attachment.Slot.values():
			if loadout.get_attachment(weapon, slot) != null:
				return false
	return true


## Before anything is saved: Pistol first, Assault Rifle second, every Slot empty.
static func _check_default(expect: Callable) -> void:
	for loadout: Loadout in [Loadout.new(), Loadout.load_saved()]:
		expect.call(loadout.get_first() == PISTOL and loadout.get_second() == ASSAULT_RIFLE,
				"loadout: the default is %s then %s, want the Pistol then the Assault Rifle"
				% [Loadout.weapon_name(loadout.get_first()), Loadout.weapon_name(loadout.get_second())])
		expect.call(_empty_everywhere(loadout), "loadout: the default has an Attachment fitted")
		var built := loadout.build_weapons()
		expect.call(built.size() == 2 and _is_bare(built[0], PISTOL) and _is_bare(built[1], ASSAULT_RIFLE),
				"loadout: the default does not build a bare Pistol and a bare Assault Rifle")
	expect.call(Loadout.all_weapons() == [PISTOL, ASSAULT_RIFLE, SHOTGUN, MARKSMAN_RIFLE],
			"loadout: the four weapons are not the Pistol, Assault Rifle, Shotgun and Marksman Rifle")


## Shotgun first, Marksman Rifle second with a Suppressor, through the file.
static func _check_round_trip(expect: Callable) -> void:
	var loadout := Loadout.new()
	loadout.set_first(SHOTGUN)
	loadout.set_second(MARKSMAN_RIFLE)
	expect.call(loadout.set_attachment(MARKSMAN_RIFLE, Attachment.Slot.BARREL, SUPPRESSOR),
			"loadout: the Marksman Rifle refused a Suppressor")
	expect.call(not loadout.set_attachment(SHOTGUN, Attachment.Slot.BARREL, SUPPRESSOR),
			"loadout: the Shotgun took a Suppressor, which it has no suppressed shot for")
	expect.call(not loadout.set_attachment(PISTOL, Attachment.Slot.SIGHT, DRUM),
			"loadout: a Drum went in the Pistol's Sight Slot")
	loadout.save()
	var back := Loadout.load_saved()
	expect.call(back.get_first() == SHOTGUN and back.get_second() == MARKSMAN_RIFLE,
			"loadout: Shotgun then Marksman Rifle came back as %s then %s"
			% [Loadout.weapon_name(back.get_first()), Loadout.weapon_name(back.get_second())])
	expect.call(back.get_attachment(MARKSMAN_RIFLE, Attachment.Slot.BARREL) == SUPPRESSOR,
			"loadout: the Marksman Rifle's Suppressor did not survive save and load")
	expect.call(back.get_attachment(SHOTGUN, Attachment.Slot.BARREL) == null
			and back.get_attachment(PISTOL, Attachment.Slot.SIGHT) == null,
			"loadout: a refused Attachment was saved")
	var built := back.build_weapons()
	expect.call(built.size() == 2 and _is_bare(built[0], SHOTGUN), "loadout: the first Built Weapon is not a bare Shotgun")
	expect.call(built.size() == 2 and built[1].attachments == [SUPPRESSOR] and built[1].model == MARKSMAN_RIFLE.model
			and absf(built[1].loudness - 9.6) <= 9.6 * 0.01,
			"loadout: the second Built Weapon is not a suppressed Marksman Rifle heard at 9.6 m (%.2f)"
			% (built[1].loudness if built.size() == 2 else -1.0))


## Never the same weapon twice: picking the gun in the other place swaps them.
static func _check_place_swap(expect: Callable) -> void:
	var loadout := Loadout.new()
	loadout.set_first(ASSAULT_RIFLE)
	expect.call(loadout.get_first() == ASSAULT_RIFLE and loadout.get_second() == PISTOL,
			"loadout: picking the second gun first did not swap the two")
	loadout.set_second(ASSAULT_RIFLE)
	expect.call(loadout.get_first() == PISTOL and loadout.get_second() == ASSAULT_RIFLE,
			"loadout: picking the first gun second did not swap the two")
	loadout.set_first(null)
	expect.call(loadout.get_first() == PISTOL, "loadout: an empty first place was taken")


## Stale entries load without error to the fallbacks.
static func _check_stale(expect: Callable) -> void:
	_write('[loadout]\nfirst="marksman_rifle"\nsecond="shotgun"\n\n[loadout_marksman_rifle]\nbarrel="flux_capacitor"\nsight="reflex_sight"\n')
	var unknown := Loadout.load_saved()
	expect.call(unknown.get_attachment(MARKSMAN_RIFLE, Attachment.Slot.BARREL) == null,
			"loadout: an unknown Attachment was not dropped to an empty Slot")
	expect.call(unknown.get_attachment(MARKSMAN_RIFLE, Attachment.Slot.SIGHT) == null,
			"loadout: a Reflex Sight the Marksman Rifle does not take was not dropped")
	expect.call(unknown.get_first() == MARKSMAN_RIFLE and unknown.get_second() == SHOTGUN,
			"loadout: a stale Attachment changed the carried weapons")
	expect.call(unknown.build_weapons().size() == 2, "loadout: a stale Attachment stopped the build")

	_write('[loadout_shotgun]\nbarrel="drum"\nmagazine="suppressor"\n')
	var misfit := Loadout.load_saved()
	expect.call(misfit.get_attachment(SHOTGUN, Attachment.Slot.BARREL) == null
			and misfit.get_attachment(SHOTGUN, Attachment.Slot.MAGAZINE) == null,
			"loadout: an Attachment the Shotgun does not take, or in the wrong Slot, was not dropped")

	_write('[loadout]\nfirst="ray_gun"\nsecond="shotgun"\n')
	var stranger := Loadout.load_saved()
	expect.call(stranger.get_first() == PISTOL and stranger.get_second() == SHOTGUN,
			"loadout: an unknown first weapon did not become the Pistol")
	_write('[loadout]\nfirst="shotgun"\nsecond=12\n')
	stranger = Loadout.load_saved()
	expect.call(stranger.get_first() == SHOTGUN and stranger.get_second() == ASSAULT_RIFLE,
			"loadout: an unknown second weapon did not become the Assault Rifle")

	_write('[loadout]\nfirst="shotgun"\nsecond="shotgun"\n')
	var twice := Loadout.load_saved()
	expect.call(twice.get_first() == PISTOL and twice.get_second() == ASSAULT_RIFLE,
			"loadout: the same weapon twice did not become the Pistol then the Assault Rifle")
	_write('[loadout]\nfirst="ray_gun"\nsecond="pistol"\n')
	twice = Loadout.load_saved()
	expect.call(twice.get_first() == PISTOL and twice.get_second() == ASSAULT_RIFLE,
			"loadout: an unknown first weapon falling back onto the second did not become the default")

	_write("this is [not a config file\n")
	var garbage := Loadout.load_saved()
	expect.call(garbage.get_first() == PISTOL and garbage.get_second() == ASSAULT_RIFLE and _empty_everywhere(garbage),
			"loadout: an unreadable profile file did not load the default")


## Attachments belong to the weapon: one not carried keeps its own.
static func _check_uncarried_keeps(expect: Callable) -> void:
	_forget(expect)
	var loadout := Loadout.new()
	loadout.set_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE, DRUM)
	loadout.set_attachment(ASSAULT_RIFLE, Attachment.Slot.BARREL, SUPPRESSOR)
	loadout.set_first(SHOTGUN)
	loadout.set_second(MARKSMAN_RIFLE)
	loadout.save()
	var back := Loadout.load_saved()
	expect.call(back.get_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE) == DRUM
			and back.get_attachment(ASSAULT_RIFLE, Attachment.Slot.BARREL) == SUPPRESSOR,
			"loadout: the Assault Rifle, not carried, lost its Drum and Suppressor through save and load")
	back.set_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE, null)
	back.save()
	expect.call(Loadout.load_saved().get_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE) == null,
			"loadout: an emptied Slot came back fitted")


## One file: banking a Raid keeps the Loadout, saving the Loadout keeps XP and gold.
static func _check_beside_xp_and_gold(expect: Callable) -> void:
	_forget(expect)
	Profile.bank(300, 40)
	var loadout := Loadout.new()
	loadout.set_first(SHOTGUN)
	loadout.save()
	Profile.load_saved()
	expect.call(Profile.xp == 300 and Profile.gold == 40, "loadout: saving the Loadout lost XP or gold")
	Profile.bank(100, 10)
	expect.call(Loadout.load_saved().get_first() == SHOTGUN, "loadout: banking a Raid wiped the saved Loadout")
	var file := ConfigFile.new()
	expect.call(file.load(Profile.path) == OK and file.get_value("pirate", "xp", 0) == 400
			and file.get_value("loadout", "first", "") == "shotgun",
			"loadout: the profile file does not hold the Loadout beside XP and gold")


## Presses Small Ship on the main menu and waits for the Raid scene.
static func _board_from_menu(expect: Callable, tree: SceneTree) -> Node:
	var menu: Node = load(Raid.MENU_SCENE).instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	var small: Button = menu.find_child("SmallShip", true, false)
	expect.call(small != null, "loadout: no Small Ship button on the menu")
	if small == null:
		return null
	small.pressed.emit()
	return await _next_scene(tree, menu)


static func _next_scene(tree: SceneTree, leaving: Node) -> Node:
	for i in 10:
		await tree.process_frame
		if tree.current_scene != null and tree.current_scene != leaving and is_instance_valid(tree.current_scene) \
				and tree.current_scene.scene_file_path == Raid.RAID_SCENE:
			await tree.physics_frame
			return tree.current_scene
	return null


static func _leave(tree: SceneTree) -> void:
	tree.unload_current_scene()
	Raid.seed = 0
	Raid.ship_class = &""
	Raid.weapons.clear()
	await tree.process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


static func _press(tree: SceneTree, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await tree.process_frame
	await tree.process_frame


static func _wait(tree: SceneTree, seconds: float) -> void:
	for i in ceili(seconds / FRAME):
		await tree.physics_frame


## With no saved Loadout a Raid from the menu carries the Pistol then the
## Assault Rifle, both bare, the Pistol in hand.
static func _check_raid_default(expect: Callable, tree: SceneTree) -> void:
	var main := await _board_from_menu(expect, tree)
	expect.call(main != null, "loadout: Small Ship did not board a Raid")
	if main == null:
		return
	var player: Node = main.get_node("Player")
	var carried: Array = player.weapons
	expect.call(carried.size() == 2 and _is_bare(carried[0], PISTOL) and _is_bare(carried[1], ASSAULT_RIFLE),
			"loadout: a Raid with no saved Loadout does not carry a bare Pistol then a bare Assault Rifle (%d carried)" % carried.size())
	expect.call(carried.size() == 2 and player.weapon == carried[0] and player.ammo == PISTOL.magazine_size,
			"loadout: the Pistol is not in hand, full, at Raid start")
	await _leave(tree)


## Shotgun first, Marksman Rifle with a Suppressor second: the Raid carries
## exactly those, Shotgun in hand; keys 1 and 2 and the wheel; a Retry
## carries the same two Built Weapons.
static func _check_raid_fitted(expect: Callable, tree: SceneTree) -> void:
	var loadout := Loadout.new()
	loadout.set_first(SHOTGUN)
	loadout.set_second(MARKSMAN_RIFLE)
	loadout.set_attachment(MARKSMAN_RIFLE, Attachment.Slot.BARREL, SUPPRESSOR)
	loadout.save()
	var main := await _board_from_menu(expect, tree)
	expect.call(main != null, "loadout: Small Ship did not board a Raid")
	if main == null:
		return
	var player: Node = main.get_node("Player")
	var carried: Array = player.weapons.duplicate()
	var fitted: bool = carried.size() == 2 and _is_bare(carried[0], SHOTGUN) and carried[1].model == MARKSMAN_RIFLE.model \
			and carried[1].attachments == [SUPPRESSOR]
	expect.call(fitted, "loadout: the Raid does not carry a bare Shotgun then a suppressed Marksman Rifle")
	if not fitted:
		await _leave(tree)
		return
	expect.call(absf(carried[1].loudness - 9.6) <= 9.6 * 0.01,
			"loadout: the Raid's Marksman Rifle is heard at %.2f m, want 9.6 within 1%%" % carried[1].loudness)
	expect.call(player.weapon == carried[0] and player.ammo == SHOTGUN.magazine_size, "loadout: the Shotgun is not in hand at Raid start")

	await _press(tree, &"weapon_2")
	expect.call(player.weapon == carried[1], "loadout: key 2 did not bring up the second weapon")
	await _wait(tree, carried[1].swap_time + 0.1)
	await _press(tree, &"weapon_1")
	expect.call(player.weapon == carried[0], "loadout: key 1 did not bring up the first weapon")
	await _wait(tree, carried[0].swap_time + 0.1)
	for action: StringName in [&"weapon_3", &"weapon_4"]:
		await _press(tree, action)
		expect.call(player.weapon == carried[0] and not player.is_swapping(), "loadout: %s did something with two carried" % action)
	await _press(tree, &"weapon_next")
	expect.call(player.weapon == carried[1], "loadout: the wheel did not flip to the second weapon")
	await _wait(tree, carried[1].swap_time + 0.1)
	await _press(tree, &"weapon_next")
	expect.call(player.weapon == carried[0], "loadout: the wheel did not flip back to the first weapon")
	await _wait(tree, carried[0].swap_time + 0.1)
	await _press(tree, &"weapon_prev")
	expect.call(player.weapon == carried[1], "loadout: the wheel up did not flip to the second weapon")
	await _wait(tree, carried[1].swap_time + 0.1)

	# A Retry boards the same ship with the same two Built Weapons, first in hand,
	# even with the saved Loadout changed under it.
	Loadout.new().save()
	Raid.retry()
	var again := await _next_scene(tree, main)
	expect.call(again != null, "loadout: Retry did not board the Raid again")
	if again != null:
		var retried: Node = again.get_node("Player")
		expect.call(retried.weapons.size() == 2 and retried.weapons[0] == carried[0] and retried.weapons[1] == carried[1],
				"loadout: a Retry did not carry the same two Built Weapons as the Raid before it")
		expect.call(retried.weapon == carried[0] and retried.ammo == SHOTGUN.magazine_size,
				"loadout: a Retry did not start with the first weapon in hand, full")
	await _leave(tree)
