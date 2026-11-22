extends SceneTree
## Headless checks on the Sandbox: `docs/sandbox.md` matches the resources
## (the stale check), a hand edit to a `.tres` makes it fail, the sheet's
## edits, Save and Revert over scratch copies of the resources, the Pirate
## and crew taking Health from the Sandbox resource, and the in-Raid sheet:
## F1 and Esc, the pause, a live edit reaching the next shot.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_sandbox.gd

## Scratch copies of the resources, so no check here writes the real ones.
const SCRATCH := "user://sandbox_test/"

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_check_doc_fresh()
	var copies := _scratch_copies()
	_check_stale_on_hand_edit(copies)
	_check_edit_save_revert(_scratch_copies())
	_check_read_only()
	await _check_in_raid()
	_check_release_has_no_sheet()
	_remove_scratch()
	_report()
	quit(1 if failures.size() > 0 else 0)


## The committed Markdown view is what the resources on disk say.
func _check_doc_fresh() -> void:
	var report := SandboxSheet.from_disk().stale_report()
	_expect(report == "", "stale check: %s" % report)
	var doc := FileAccess.get_file_as_string(SandboxSheet.DOC_PATH)
	for heading in ["## Weapons", "## Health and Melee", "| | Pistol | Assault Rifle |", "| **Trigger** |",
			"| **Derived** |", "| = Shots to kill crew | 4 | 4 |", "| Pirate Health | 150 |", "| Crew Health | 100 |",
			"| Melee Damage | 75 |", "kills outright"]:
		_expect(doc.contains(heading), "docs/sandbox.md lacks \"%s\"" % heading)


## Fresh copies of the weapons and the Sandbox under SCRATCH, with their own
## Markdown view. Returns {weapons: PackedStringArray, sandbox: String, doc: String}.
func _scratch_copies() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	var weapons := PackedStringArray()
	for path in SandboxSheet.carried_weapon_paths():
		var copy := SCRATCH + path.get_file()
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))
		weapons.append(copy)
	var sandbox := SCRATCH + "sandbox.tres"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(Sandbox.PATH), ProjectSettings.globalize_path(sandbox))
	var sheet := SandboxSheet.from_disk(weapons, sandbox)
	sheet.doc_path = SCRATCH + "sandbox.md"
	sheet.write_doc()
	return {"weapons": weapons, "sandbox": sandbox, "doc": sheet.doc_path}


## Changing a number in a `.tres` by hand, without regenerating, fails it.
func _check_stale_on_hand_edit(copies: Dictionary) -> void:
	var report := SandboxSheet.from_disk(copies.weapons, copies.sandbox).stale_report(copies.doc)
	_expect(report == "", "stale check fails on a freshly written view: %s" % report)
	var pistol: String = copies.weapons[0]
	_expect(pistol.get_file() == "pistol.tres", "the first carried weapon is %s, not the Pistol" % pistol.get_file())
	var text := FileAccess.get_file_as_string(pistol)
	var edited := RegEx.create_from_string("(?m)^damage = \\d+$").sub(text, "damage = 31")
	if edited == text:
		edited = text.strip_edges() + "\ndamage = 31\n"
	var file := FileAccess.open(pistol, FileAccess.WRITE)
	file.store_string(edited)
	file.close()
	report = SandboxSheet.from_disk(copies.weapons, copies.sandbox).stale_report(copies.doc)
	_expect(report.contains("stale"), "stale check passed after the Pistol's damage was edited by hand")
	var sandbox_text := FileAccess.get_file_as_string(copies.sandbox).replace("crew_health = 100", "crew_health = 90")
	file = FileAccess.open(copies.sandbox, FileAccess.WRITE)
	file.store_string(sandbox_text)
	file.close()
	var fresh := SandboxSheet.from_disk(copies.weapons, copies.sandbox)
	fresh.write_doc(copies.doc)
	_expect(fresh.stale_report(copies.doc) == "", "stale check still fails after regenerating")


## An edit changes the live Resource and marks the cell against disk;
## Revert puts it back; Save writes the Resources and the Markdown view.
func _check_edit_save_revert(copies: Dictionary) -> void:
	var pistol: WeaponProfile = load(copies.weapons[0])
	var rifle: WeaponProfile = load(copies.weapons[1])
	var sandbox: Sandbox = load(copies.sandbox)
	var sheet := SandboxSheet.build([pistol, rifle], sandbox)
	sheet.doc_path = copies.doc
	var weapons := sheet.table(SandboxSheet.WEAPONS)
	var health := sheet.table(SandboxSheet.HEALTH)
	_expect(weapons.columns == PackedStringArray(["Pistol", "Assault Rifle"]), "weapon columns are %s" % weapons.columns)
	_expect(sheet.changed_count() == 0, "a fresh sheet has %d changed cells" % sheet.changed_count())

	_expect(weapons.set_value(&"damage", 0, 40), "the Pistol's damage would not take 40")
	_expect(pistol.damage == 40, "the sheet did not change the live Pistol (damage %d)" % pistol.damage)
	_expect(weapons.is_changed(&"damage", 0) and weapons.disk_value(&"damage", 0) == 25,
			"the edited cell is not marked against the disk value 25")
	_expect(not weapons.is_changed(&"damage", 1), "the Assault Rifle's damage is marked changed")
	_expect(weapons.value(&"shots_to_kill_crew", 0) == 3 and weapons.value(&"shots_to_kill_crew", 1) == 4,
			"shots to kill crew at 40 and 25 damage are %s and %s, want 3 and 4"
			% [weapons.value(&"shots_to_kill_crew", 0), weapons.value(&"shots_to_kill_crew", 1)])
	_expect(weapons.value(&"reach", 0) == 40.0 and weapons.value(&"shots_per_second", 1) > 11.0,
			"derived reach or shots per second is wrong")
	_expect(is_equal_approx(weapons.value(&"seconds_to_kill_crew", 1), 0.27),
			"the Assault Rifle kills crew in %s s, want 0.27 (three intervals of 0.09)" % weapons.value(&"seconds_to_kill_crew", 1))

	sheet.revert()
	_expect(pistol.damage == 25 and sheet.changed_count() == 0, "Revert left the Pistol on %d damage" % pistol.damage)

	weapons.set_value(&"damage", 0, 40)
	weapons.set_value(&"semi_auto", 1, true)
	health.set_value(&"crew_health", 0, 120)
	_expect(weapons.value(&"shots_to_kill_crew", 0) == 3 and weapons.value(&"shots_to_kill_crew", 1) == 5,
			"shots to kill crew did not follow crew Health 120")
	_expect(sheet.changed_count() == 3, "three edits mark %d cells" % sheet.changed_count())
	var err := sheet.save()
	_expect(err == OK, "Save failed: %s" % error_string(err))
	_expect(sheet.changed_count() == 0, "after Save %d cells still differ from disk" % sheet.changed_count())
	var saved_pistol: WeaponProfile = ResourceLoader.load(copies.weapons[0], "", ResourceLoader.CACHE_MODE_IGNORE)
	var saved_rifle: WeaponProfile = ResourceLoader.load(copies.weapons[1], "", ResourceLoader.CACHE_MODE_IGNORE)
	var saved_sandbox: Sandbox = ResourceLoader.load(copies.sandbox, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(saved_pistol.damage == 40, "Save wrote the Pistol's damage as %d" % saved_pistol.damage)
	_expect(saved_rifle.semi_auto, "Save did not write the Assault Rifle's trigger")
	_expect(saved_rifle.model != null and saved_rifle.model.resource_path == "res://scenes/weapons/assault_rifle_model.tscn",
			"Save lost the Assault Rifle's model")
	_expect(saved_sandbox.crew_health == 120, "Save wrote crew Health as %d" % saved_sandbox.crew_health)
	_expect(SandboxSheet.from_disk(copies.weapons, copies.sandbox).stale_report(copies.doc) == "",
			"Save left the Markdown view stale")
	_expect(FileAccess.get_file_as_string(copies.doc).contains("| Damage | 40 | 25 |"), "the saved view lacks the Pistol at 40")


## Model, poses, clip names are shown, never edited.
func _check_read_only() -> void:
	var pistol: WeaponProfile = ResourceLoader.load("res://resources/weapons/pistol.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var sheet := SandboxSheet.build([pistol], ResourceLoader.load(Sandbox.PATH, "", ResourceLoader.CACHE_MODE_IGNORE))
	var weapons := sheet.table(SandboxSheet.WEAPONS)
	for key in [&"model", &"pose_hip", &"model_fire_clip", &"fire_clip"]:
		var row := weapons.row(key)
		_expect(not row.is_empty() and row.kind == SheetTable.Kind.READ_ONLY, "%s is not a read-only row" % key)
	var before := pistol.pose_hip
	_expect(not weapons.set_value(&"pose_hip", 0, Vector3.ONE) and pistol.pose_hip == before, "the sheet changed a pose")
	_expect(not weapons.set_value(&"reach", 0, 5.0), "the sheet changed a derived row")
	_expect(weapons.value(&"model", 0) is PackedScene and SheetTable.format(weapons.value(&"model", 0)) == "pistol_model.tscn",
			"the model cell does not read pistol_model.tscn")


## The Raid: Health from the Sandbox, F1 and Esc, a live edit on the next shot.
func _check_in_raid() -> void:
	var sandbox: Sandbox = load(Sandbox.PATH)
	sandbox.pirate_health = 123
	sandbox.crew_health = 77
	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var player: CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	var pause: PauseMenu = main.get_node("PauseMenu")
	_expect(player.health.max_health == 123 and player.health.current == 123,
			"the Pirate spawned on %d Health, not the Sandbox's 123" % player.health.max_health)
	var crew := get_nodes_in_group(&"crew")
	_expect(not crew.is_empty(), "the Raid has no crew")
	for body in crew:
		_expect(body.health.max_health == 77 and body.health.current == 77,
				"a crew member spawned on %d Health, not the Sandbox's 77" % body.health.max_health)
	sandbox.pirate_health = 150
	sandbox.crew_health = 100

	var view: SandboxSheetView = main.get_node_or_null("SandboxSheet")
	_expect(view != null, "a debug Raid has no Sandbox sheet")
	if view == null:
		main.free()
		return
	_expect(not view.is_open() and not paused, "the sheet starts open or the Raid paused")
	_key(KEY_F1)
	_expect(view.is_open() and paused and not pause.is_showing(), "F1 did not open the sheet over a paused Raid")
	_expect(not player.can_process() and view.can_process(), "the open sheet froze itself or not the Pirate")
	_key(KEY_F1)
	_expect(not view.is_open() and not paused, "F1 again did not close the sheet and resume")
	_key(KEY_F1)
	_key(KEY_ESCAPE)
	_expect(not view.is_open() and not paused and not pause.is_showing(), "Esc did not close the sheet, or opened the pause menu")
	_key(KEY_ESCAPE)
	_expect(pause.is_showing() and paused, "Esc no longer opens the pause menu")
	_key(KEY_F1)
	_expect(not view.is_open() and pause.is_showing(), "F1 opened the sheet over the pause menu")
	_key(KEY_ESCAPE)
	_expect(not pause.is_showing() and not paused, "Esc did not resume from the pause menu")

	# A live edit through the sheet's own cell reaches the next shot.
	_key(KEY_F1)
	var pistol: WeaponProfile = player.weapon
	_expect(pistol.resource_path == "res://resources/weapons/pistol.tres", "the Pirate does not start on the Pistol")
	var cell := view.cell(SandboxSheet.WEAPONS, &"damage", 0) as SpinBox
	_expect(cell != null, "the Pistol's damage cell is not a number field")
	if cell != null:
		cell.value = 40
		_expect(pistol.damage == 40, "editing the cell left the Pistol on %d damage" % pistol.damage)
		_expect(view.disk_shown(SandboxSheet.WEAPONS, &"damage", 0) == "25", "the changed cell does not show the disk value 25")
		_expect(view.disk_shown(SandboxSheet.WEAPONS, &"damage", 1) == "", "an unchanged cell shows a disk value")
		_expect((view.cell(SandboxSheet.WEAPONS, &"shots_to_kill_crew", 0) as Label).text == "3",
				"the derived shots-to-kill cell did not follow the edit")
	_key(KEY_F1)
	var shot: Projectile3D = player.fire()
	_expect(shot != null and shot.damage == 40, "the next shot after the edit does %s damage, not 40" % (shot.damage if shot else "no"))
	# Pirate Health applies live too.
	_key(KEY_F1)
	(view.cell(SandboxSheet.HEALTH, &"pirate_health", 0) as SpinBox).value = 175
	_expect(player.health.max_health == 175 and player.health.current == 175, "a Pirate Health edit did not reach the Pirate")
	view.revert_button().pressed.emit()
	_expect(pistol.damage == 25 and sandbox.pirate_health == 150 and player.health.max_health == 150,
			"Revert left damage %d, Pirate Health %d" % [pistol.damage, sandbox.pirate_health])
	_expect((view.cell(SandboxSheet.WEAPONS, &"damage", 0) as SpinBox).value == 25.0
			and view.disk_shown(SandboxSheet.WEAPONS, &"damage", 0) == "", "the cell does not show the reverted value")
	_key(KEY_F1)
	paused = false
	main.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A release build gets no sheet.
func _check_release_has_no_sheet() -> void:
	var host := Node.new()
	root.add_child(host)
	_expect(SandboxSheetView.attach(host, false) == null and host.get_child_count() == 0, "a release build got a Sandbox sheet")
	host.free()


func _remove_scratch() -> void:
	for file in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH + file))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))


func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)
	var up := event.duplicate()
	up.pressed = false
	root.push_input(up)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func _report() -> void:
	for f in failures:
		print("FAIL  ", f)
	if failures.is_empty():
		print("PASS  %d checks" % checks)
	else:
		print("FAILED  %d of %d checks" % [failures.size(), checks])
