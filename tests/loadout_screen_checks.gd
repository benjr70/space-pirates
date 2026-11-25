class_name LoadoutScreenChecks
extends RefCounted
## The Loadout screen (`.scratch/weapon-attachments/issues/22-the-loadout-screen.md`):
## a Loadout button on the main menu between Play and Exit opening the
## workbench; the two places and the swap; Slot tags, "no Slot" where a gun
## has none; a Slot's list with a gain and cost line made from each
## Attachment's changes; the bars against the bare gun; turning the gun;
## the keyboard alone; and a fitted Attachment carried into a Raid.
## Run from the pirate suite: `await LoadoutScreenChecks.run(_expect, self)`,
## with the suite's own course paused, after `LoadoutChecks`.

const PISTOL: WeaponProfile = preload("res://resources/weapons/pistol.tres")
const ASSAULT_RIFLE: WeaponProfile = preload("res://resources/weapons/assault_rifle.tres")
const SHOTGUN: WeaponProfile = preload("res://resources/weapons/shotgun.tres")
const SUPPRESSOR: Attachment = preload("res://resources/attachments/suppressor.tres")
const DRUM: Attachment = preload("res://resources/attachments/drum.tres")
const LASER: Attachment = preload("res://resources/attachments/laser.tres")
const QUICK_MAGAZINE: Attachment = preload("res://resources/attachments/quick_magazine.tres")
const ATTACHMENT_DIR := "res://resources/attachments/"

## The Assault Rifle with a Suppressor and a Drum, from the spec's catalogue
## (bare: bolt 100, spread 1.2, ads_spread 0.45, kick 3, aim 0.22, 30 rounds,
## tactical reload 1.8, heard at 24 m, zoom 1.6): each bar's built value, 1%,
## and whether it is better (1), worse (-1) or the same (0) as bare.
const RIFLE_BARS := {
	"Bolt speed": [80.0, -1],
	"Hip accuracy": [1.2, 0],
	"Aimed accuracy": [0.54, 0],
	"Recoil control": [3.0, 0],
	"Handling": [0.275, -1],
	"Magazine": [75.0, 1],
	"Reload": [2.88, -1],
	"Quiet": [9.6, 1],
	"Zoom": [1.6, 0],
}
## Lines a person wrote from the spec's Gain and Cost columns, which the
## generated ones must read as.
const LINES := {
	"suppressor": "quieter, suppressed shot · slower bolt",
	"laser": "tighter hip fire · crew notice him sooner",
	"drum": "more rounds · slower reload, slower to the sights, slower swap",
	"long_barrel": "faster bolt, tighter hip fire, tighter aimed · slower to the sights, slower swap",
	"combat_scope": "more zoom, tighter aimed, scope lens · slower to the sights, slower aimed",
	"foregrip": "less recoil · slower to the sights",
}


static func run(expect: Callable, tree: SceneTree) -> void:
	var saved_path := Profile.path
	Profile.path = RaidChecks.test_profile
	_forget()
	await _check_home(expect, tree)
	_check_lines(expect)
	await _check_places(expect, tree)
	await _check_no_slot(expect, tree)
	await _check_list(expect, tree)
	await _check_bars(expect, tree)
	await _check_preview(expect, tree)
	await _check_turn(expect, tree)
	_forget()
	await _check_keyboard(expect, tree)
	_forget()
	await _check_drum_into_raid(expect, tree)
	_forget()
	Profile.path = saved_path
	Profile.load_saved()


static func _forget() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	Profile.load_saved()


static func _menu(tree: SceneTree) -> Node:
	var menu: Node = load(Raid.MENU_SCENE).instantiate()
	tree.root.add_child(menu)
	tree.current_scene = menu
	await tree.process_frame
	return menu


static func _drop(tree: SceneTree, menu: Node) -> void:
	if tree.current_scene == menu:
		tree.current_scene = null
	tree.root.remove_child(menu)
	menu.free()
	await tree.process_frame


static func _home(menu: Node) -> Control:
	return menu.get_node("UI/Root/Column/Home")


static func _screen(menu: Node) -> LoadoutScreen:
	return menu.get_node_or_null("UI/LoadoutScreen") as LoadoutScreen


## The menu with the Loadout screen open on it by its button.
static func _open(tree: SceneTree) -> Array:
	var menu := await _menu(tree)
	(_home(menu).get_node("Loadout") as Button).pressed.emit()
	await tree.process_frame
	return [menu, _screen(menu)]


## Home reads Play, Loadout, Exit, and Loadout opens the screen over the
## backdrop; Back closes it, back on the home list.
static func _check_home(expect: Callable, tree: SceneTree) -> void:
	var menu := await _menu(tree)
	var home := _home(menu)
	var names := []
	for child in home.get_children():
		if child is Button:
			names.append(String(child.name))
	expect.call(names == ["Play", "Loadout", "Exit"], "loadout screen: the home list is %s, want Play, Loadout, Exit" % [names])
	if not home.has_node("Loadout"):
		await _drop(tree, menu)
		return
	(home.get_node("Loadout") as Button).pressed.emit()
	await tree.process_frame
	var screen := _screen(menu)
	expect.call(screen != null and screen.visible and not menu.get_node("UI/Root").visible,
			"loadout screen: the Loadout button did not open the screen in place of the menu")
	expect.call(screen != null and menu.get_node("Backdrop").visible, "loadout screen: the backdrop is not behind the screen")
	if screen != null:
		screen.back_button().pressed.emit()
		await tree.process_frame
		expect.call(not screen.visible and home.visible and menu.get_node("UI/Root").visible,
				"loadout screen: Back did not return to the home list")
	await _drop(tree, menu)


## Every Attachment's line is made from its changes: the lines read as the
## spec's columns, a changed factor changes the line, every field any
## Attachment changes has words, and no Attachment file holds words.
static func _check_lines(expect: Callable) -> void:
	for file: String in LINES:
		var attachment: Attachment = load(ATTACHMENT_DIR + file + ".tres")
		var line := WeaponAttributes.describe(attachment)
		expect.call(line == LINES[file], "loadout screen: %s's line is '%s', want '%s'" % [file, line, LINES[file]])
	var changed: Attachment = QUICK_MAGAZINE.duplicate()
	changed.changes = {&"magazine_size": 2.0}
	expect.call(WeaponAttributes.describe(changed) == "more rounds",
			"loadout screen: a Quick Magazine made to double the rounds reads '%s'" % WeaponAttributes.describe(changed))
	changed.changes = {&"magazine_size": 2.0, &"loudness": 1.5}
	expect.call(WeaponAttributes.describe(changed) == "more rounds · louder",
			"loadout screen: doubled rounds and 1.5x loudness read '%s'" % WeaponAttributes.describe(changed))
	changed.lens = true
	expect.call(WeaponAttributes.describe(changed).contains(WeaponAttributes.LENS), "loadout screen: a lens is not in the line")
	var words := 0
	for file in DirAccess.get_files_at(ATTACHMENT_DIR):
		if not file.ends_with(".tres"):
			continue
		var attachment: Attachment = load(ATTACHMENT_DIR + file)
		expect.call(WeaponAttributes.describe(attachment) != "", "loadout screen: %s has an empty line" % file)
		for field: StringName in attachment.changes:
			for f: float in [0.5, 2.0]:
				var alone := Attachment.new()
				alone.changes = {field: f}
				expect.call(WeaponAttributes.describe(alone) != "",
						"loadout screen: %s changes %s, which no words cover" % [file, field])
		# Only the fields the Attachment script declares, and none of them words.
		var text := FileAccess.get_file_as_string(ATTACHMENT_DIR + file)
		for line in text.split("\n"):
			if line.contains(" = ") and not line.begins_with("["):
				var key := line.get_slice(" = ", 0)
				expect.call(key in ["script", "slot", "display_name", "changes", "lens", "suppresses", "model", "models",
						"mount", "hides", "rides"], "loadout screen: %s holds '%s'" % [file, key])
		words += 1
	expect.call(words == 14, "loadout screen: %d Attachment files read, want 14" % words)
	for property in Attachment.new().get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.type == TYPE_STRING:
			expect.call(property.name == "display_name", "loadout screen: an Attachment holds text in %s" % property.name)


## The FIRST and SECOND tabs name their guns; picking the other place's gun
## swaps the two.
static func _check_places(expect: Callable, tree: SceneTree) -> void:
	_forget()
	var opened := await _open(tree)
	var screen: LoadoutScreen = opened[1]
	expect.call(screen.tab(0).text.contains("PISTOL") and screen.tab(1).text.contains("ASSAULT RIFLE"),
			"loadout screen: the tabs read '%s' and '%s'" % [screen.tab(0).text, screen.tab(1).text])
	expect.call(screen.place == 0, "loadout screen: it does not open on the first place")
	screen.weapon_button(ASSAULT_RIFLE).pressed.emit()
	expect.call(screen.loadout.get_first() == ASSAULT_RIFLE and screen.loadout.get_second() == PISTOL,
			"loadout screen: choosing the second place's gun for the first did not swap the two")
	expect.call(screen.tab(0).text.contains("ASSAULT RIFLE") and screen.tab(1).text.contains("PISTOL"),
			"loadout screen: after the swap the tabs read '%s' and '%s'" % [screen.tab(0).text, screen.tab(1).text])
	screen.tab(1).pressed.emit()
	screen.weapon_button(SHOTGUN).pressed.emit()
	expect.call(screen.loadout.get_first() == ASSAULT_RIFLE and screen.loadout.get_second() == SHOTGUN,
			"loadout screen: carrying the Shotgun second did not leave the Assault Rifle first")
	expect.call(screen.shown_weapon() == SHOTGUN, "loadout screen: the bench does not show the second place's gun")
	await _drop(tree, opened[0])


## The Pistol's Stock and the Shotgun's Magazine are greyed, disabled, "no Slot".
static func _check_no_slot(expect: Callable, tree: SceneTree) -> void:
	_forget()
	var opened := await _open(tree)
	var screen: LoadoutScreen = opened[1]
	for case: Array in [[PISTOL, Attachment.Slot.STOCK], [SHOTGUN, Attachment.Slot.MAGAZINE]]:
		screen.weapon_button(case[0]).pressed.emit()
		for slot: Attachment.Slot in Attachment.Slot.values():
			var tag := screen.tag(slot)
			var none: bool = slot == case[1]
			expect.call(tag.disabled == none and tag.text.contains("no Slot") == none,
					"loadout screen: %s's %s tag reads '%s', disabled %s" % [Loadout.weapon_name(case[0]),
					Attachment.Slot.find_key(slot), tag.text.replace("\n", " / "), tag.disabled])
			expect.call(tag.text.begins_with(String(Attachment.Slot.find_key(slot))),
					"loadout screen: the %s tag does not lead with its Slot's name" % Attachment.Slot.find_key(slot))
	await _drop(tree, opened[0])


## A tag opens its Slot's list: None, then each Attachment that fits, the
## fitted one marked, each with its line; picking one fits it and closes it.
static func _check_list(expect: Callable, tree: SceneTree) -> void:
	_forget()
	var opened := await _open(tree)
	var screen: LoadoutScreen = opened[1]
	screen.tab(1).pressed.emit()
	var tag := screen.tag(Attachment.Slot.MAGAZINE)
	expect.call(tag.text.contains("empty"), "loadout screen: an empty Magazine tag reads '%s'" % tag.text)
	tag.pressed.emit()
	expect.call(screen.open_slot == Attachment.Slot.MAGAZINE, "loadout screen: the Magazine tag did not open its list")
	var items := screen.list_items()
	var want: Array = [null]
	want.append_array(ASSAULT_RIFLE.fits_in(Attachment.Slot.MAGAZINE))
	expect.call(items == want, "loadout screen: the Magazine list is not None then the Magazines that fit (%d)" % items.size())
	expect.call(screen.is_marked(null), "loadout screen: None is not marked with the Slot empty")
	for attachment in ASSAULT_RIFLE.fits_in(Attachment.Slot.MAGAZINE):
		expect.call(screen.list_line(attachment) == WeaponAttributes.describe(attachment),
				"loadout screen: %s's line in the list is '%s'" % [attachment.display_name, screen.list_line(attachment)])
	screen.list_button(DRUM).pressed.emit()
	expect.call(screen.loadout.get_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE) == DRUM,
			"loadout screen: picking the Drum did not fit it")
	expect.call(screen.open_slot == -1, "loadout screen: picking an Attachment did not close the list")
	expect.call(tag.text.contains("Drum"), "loadout screen: the Magazine tag reads '%s' with a Drum" % tag.text)
	tag.pressed.emit()
	expect.call(screen.is_marked(DRUM) and not screen.is_marked(null), "loadout screen: the fitted Drum is not the marked one")
	screen.list_button(null).pressed.emit()
	expect.call(screen.loadout.get_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE) == null,
			"loadout screen: None did not empty the Slot")
	await _drop(tree, opened[0])


## The Assault Rifle with a Suppressor and a Drum: each bar's value is the
## Built Weapon's, green exactly when better than bare, red when worse; the
## Laser brings the red "Crew notice him sooner".
static func _check_bars(expect: Callable, tree: SceneTree) -> void:
	_forget()
	var opened := await _open(tree)
	var screen: LoadoutScreen = opened[1]
	screen.tab(1).pressed.emit()
	for fit: Array in [[Attachment.Slot.BARREL, SUPPRESSOR], [Attachment.Slot.MAGAZINE, DRUM]]:
		screen.tag(fit[0]).pressed.emit()
		screen.list_button(fit[1]).pressed.emit()
	var built := screen.shown_build()
	expect.call(built.magazine_size == 75 and built.attachments == [SUPPRESSOR, DRUM],
			"loadout screen: the bench's Built Weapon is not a suppressed Assault Rifle with a Drum")
	for name: String in RIFLE_BARS:
		var bar := screen.bar(name)
		expect.call(bar != null, "loadout screen: no %s bar" % name)
		if bar == null:
			continue
		var want: float = RIFLE_BARS[name][0]
		var shown: float = bar.get_meta("value")
		var attribute := WeaponAttributes.named(name)
		expect.call(is_equal_approx(shown, WeaponAttributes.value(attribute, built)) and absf(shown - want) <= want * 0.01,
				"loadout screen: the %s bar shows %.3f, want the Built Weapon's %.3f" % [name, shown, want])
		var value_label: Label = bar.get_node("Value")
		expect.call(value_label.text == attribute.format % shown, "loadout screen: the %s number reads '%s'" % [name, value_label.text])
		var colour: Color = value_label.get_theme_color("font_color")
		var change: ColorRect = bar.get_node("Track/Change")
		match int(RIFLE_BARS[name][1]):
			1:
				expect.call(colour == LoadoutScreen.GAIN and change.visible and change.color == LoadoutScreen.GAIN,
						"loadout screen: the %s bar is not green for a gain" % name)
			-1:
				expect.call(colour == LoadoutScreen.COST and change.visible and change.color == LoadoutScreen.COST,
						"loadout screen: the %s bar is not red for a cost" % name)
			0:
				expect.call(colour != LoadoutScreen.GAIN and colour != LoadoutScreen.COST and not change.visible,
						"loadout screen: the %s bar is coloured with nothing changed" % name)
	expect.call(not screen.notice_label().visible, "loadout screen: 'Crew notice him sooner' shows with no Laser")
	screen.tag(Attachment.Slot.UNDERBARREL).pressed.emit()
	screen.list_button(LASER).pressed.emit()
	expect.call(screen.notice_label().visible and screen.notice_label().text == "Crew notice him sooner"
			and screen.notice_label().get_theme_color("font_color") == LoadoutScreen.COST,
			"loadout screen: no red 'Crew notice him sooner' with a Laser")
	await _drop(tree, opened[0])


## The bench shows the Built Weapon's Attachments on its model, without the
## Viewmodel's field-of-view flags.
static func _check_preview(expect: Callable, tree: SceneTree) -> void:
	_forget()
	var opened := await _open(tree)
	var screen: LoadoutScreen = opened[1]
	screen.tab(1).pressed.emit()
	for fit: Array in [[Attachment.Slot.BARREL, SUPPRESSOR], [Attachment.Slot.MAGAZINE, DRUM]]:
		screen.tag(fit[0]).pressed.emit()
		screen.list_button(fit[1]).pressed.emit()
	var model := screen.shown_model()
	var fitting := WeaponModel.of(model)
	expect.call(fitting.fitted == [SUPPRESSOR, DRUM] and fitting.model_of(SUPPRESSOR) != null
			and fitting.model_of(SUPPRESSOR).is_visible_in_tree() and fitting.model_of(DRUM).is_visible_in_tree(),
			"loadout screen: the bench's gun does not show its Suppressor and Drum")
	var flagged := 0
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		for i in (mesh.mesh.get_surface_count() if mesh.mesh != null else 0):
			var material := mesh.get_active_material(i)
			if material != null and material.get("use_fov_override") == true:
				flagged += 1
	expect.call(flagged == 0, "loadout screen: %d of the bench gun's materials carry the Viewmodel's field of view" % flagged)
	screen.weapon_button(PISTOL).pressed.emit()
	expect.call(screen.shown_weapon() == PISTOL and screen.shown_model().is_visible_in_tree() and not model.is_visible_in_tree(),
			"loadout screen: carrying the Pistol did not put it on the bench in place of the rifle")
	await _drop(tree, opened[0])


static func _mouse_button(at: Vector2, pressed: bool, double := false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	return event


## Dragging 100 px across the gun turns it, and it stays turned; a double
## click puts it back side-on.
static func _check_turn(expect: Callable, tree: SceneTree) -> void:
	_forget()
	var opened := await _open(tree)
	var screen: LoadoutScreen = opened[1]
	await tree.process_frame
	var pivot := screen.pivot()
	var side_on := pivot.basis
	var at := screen.gun_view().get_global_rect().get_center()
	var window := tree.root
	window.push_input(_mouse_button(at, true))
	for step in 10:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = Vector2(10, 0)
		at += motion.relative
		motion.position = at
		motion.global_position = at
		window.push_input(motion)
	window.push_input(_mouse_button(at, false))
	var turned := pivot.basis
	expect.call(not turned.is_equal_approx(side_on), "loadout screen: dragging 100 px across the gun did not turn it")
	for i in 30:
		await tree.process_frame
	expect.call(pivot.basis.is_equal_approx(turned), "loadout screen: the gun did not stay where it was turned")
	window.push_input(_mouse_button(at, true, true))
	window.push_input(_mouse_button(at, false))
	expect.call(pivot.basis.is_equal_approx(side_on), "loadout screen: a double click did not put the gun back side-on")
	await _drop(tree, opened[0])


static func _key(tree: SceneTree, action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await tree.process_frame


static func _focus(tree: SceneTree) -> Control:
	return tree.root.gui_get_focus_owner()


## Keys alone, from the menu: down to Loadout, Enter; right to SECOND,
## Enter; down to the tags and round to Magazine, Enter; down to the Drum,
## Enter; Esc leaves and saves; Esc again closes nothing more.
static func _check_keyboard(expect: Callable, tree: SceneTree) -> void:
	var menu := await _menu(tree)
	var home := _home(menu)
	expect.call(_focus(tree) == home.get_node("Play"), "loadout screen: the menu does not open with Play focused")
	await _key(tree, &"ui_down")
	expect.call(_focus(tree) == home.get_node_or_null("Loadout"), "loadout screen: down from Play does not reach Loadout")
	await _key(tree, &"ui_accept")
	var screen := _screen(menu)
	expect.call(screen != null and screen.visible, "loadout screen: Enter on Loadout did not open the screen")
	if screen == null or not screen.visible:
		await _drop(tree, menu)
		return
	expect.call(_focus(tree) == screen.tab(0), "loadout screen: it does not open with the FIRST tab focused")
	await _key(tree, &"ui_right")
	await _key(tree, &"ui_accept")
	expect.call(screen.place == 1 and screen.shown_weapon() == ASSAULT_RIFLE, "loadout screen: right and Enter did not pick SECOND")
	var magazine := screen.tag(Attachment.Slot.MAGAZINE)
	for i in 4:
		if _focus(tree) in screen.tags():
			break
		await _key(tree, &"ui_down")
	expect.call(_focus(tree) in screen.tags(), "loadout screen: down does not reach the Slot tags")
	for i in 5:
		if _focus(tree) == magazine:
			break
		await _key(tree, &"ui_right")
	expect.call(_focus(tree) == magazine, "loadout screen: right does not go round the tags to Magazine")
	await _key(tree, &"ui_accept")
	expect.call(screen.open_slot == Attachment.Slot.MAGAZINE and _focus(tree) == screen.list_button(null),
			"loadout screen: Enter on the Magazine tag did not open its list with None focused")
	for i in 4:
		if _focus(tree) == screen.list_button(DRUM):
			break
		await _key(tree, &"ui_down")
	expect.call(_focus(tree) == screen.list_button(DRUM), "loadout screen: down does not reach the Drum in the list")
	await _key(tree, &"ui_accept")
	expect.call(screen.loadout.get_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE) == DRUM and screen.open_slot == -1
			and _focus(tree) == magazine, "loadout screen: Enter on the Drum did not fit it and return to its tag")
	# Esc with a list open closes the list; with none, leaves.
	await _key(tree, &"ui_accept")
	await _key(tree, &"ui_cancel")
	expect.call(screen.visible and screen.open_slot == -1, "loadout screen: Esc with a list open did not just close the list")
	await _key(tree, &"ui_cancel")
	expect.call(not screen.visible and home.visible and _focus(tree) == home.get_node("Loadout"),
			"loadout screen: Esc did not return to the home list with Loadout focused")
	expect.call(Loadout.load_saved().get_attachment(ASSAULT_RIFLE, Attachment.Slot.MAGAZINE) == DRUM,
			"loadout screen: leaving with Esc did not save the Loadout")
	await _drop(tree, menu)


## The Drum fitted to the Assault Rifle through the screen; Back; Play,
## Small Ship: the Raid's Assault Rifle holds 75 rounds.
static func _check_drum_into_raid(expect: Callable, tree: SceneTree) -> void:
	var opened := await _open(tree)
	var menu: Node = opened[0]
	var screen: LoadoutScreen = opened[1]
	screen.tab(1).pressed.emit()
	screen.tag(Attachment.Slot.MAGAZINE).pressed.emit()
	screen.list_button(DRUM).pressed.emit()
	screen.back_button().pressed.emit()
	await tree.process_frame
	(_home(menu).get_node("Play") as Button).pressed.emit()
	(menu.find_child("SmallShip", true, false) as Button).pressed.emit()
	var main := await LoadoutChecks._next_scene(tree, menu)
	expect.call(main != null, "loadout screen: Small Ship did not board a Raid")
	if main == null:
		return
	var player: Node = main.get_node("Player")
	var carried: Array = player.weapons
	expect.call(carried.size() == 2 and carried[1].model == ASSAULT_RIFLE.model and carried[1].magazine_size == 75,
			"loadout screen: the Raid's second gun is not an Assault Rifle holding 75")
	await LoadoutChecks._press(tree, &"weapon_2")
	await LoadoutChecks._wait(tree, ASSAULT_RIFLE.swap_time * 1.3 + 0.1)
	expect.call(player.weapon == carried[1] and player.ammo == 75,
			"loadout screen: the Assault Rifle in hand holds %d rounds, want 75" % player.ammo)
	await LoadoutChecks._leave(tree)
