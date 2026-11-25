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
	await _check_menu_raid()
	_check_release_has_no_sheet()
	_remove_scratch()
	_report()
	await _silence()
	quit(1 if failures.size() > 0 else 0)


## The Raid check fires shots; let the audio server drop their playbacks
## before quitting, or the streams are reported as leaked at exit.
func _silence() -> void:
	for node in root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.stop()
	OS.delay_msec(300)
	await process_frame
	await process_frame


## The committed Markdown view is what the resources on disk say.
func _check_doc_fresh() -> void:
	var report := SandboxSheet.from_disk().stale_report()
	_expect(report == "", "stale check: %s" % report)
	var doc := FileAccess.get_file_as_string(SandboxSheet.DOC_PATH)
	for heading in ["## Weapons", "## Health and Melee", "| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |", "| **Trigger** |",
			"| **Derived** |", "| = Shots to kill crew | 4 | 4 | 1 | 2 |", "| Pellet Count | 1 | 1 | 12 | 1 |",
			"| = Damage per shot | 25 | 25 | 156 | 50 |", "| Headshot Multiplier | 1.5 | 1.0 | 1.0 | 2.0 |",
			"| = Shots to kill crew by Headshot | 3 | 4 | 1 | 1 |", "| = Pellets to kill crew | - | - | 8 | - |",
			"| = Reach (m) | 40.0 | 50.0 | 15.0 | 80.0 |", "| Pirate Health | 150 |", "| Crew Health | 100 |",
			"| Melee Damage | 75 |", "kills outright", "## Gunnery", "| | Guard | Worker |", "| **Aim** |",
			"| Aim Error Degrees | 6.0 | 11.0 |", "| Burst Length | 3 | 2 |", "| Pause Between Bursts | 1.1 | 1.1 |",
			"| Engage Range | 10.6 | 10.6 |", "Crew fire the Pistol",
			"| Aim Time | 0.15 | 0.22 | 0.22 | 0.32 |", "| Swap Time | 0.3 | 0.4 | 0.45 | 0.5 |"]:
		_expect(doc.contains(heading), "docs/sandbox.md lacks \"%s\"" % heading)
	# Aim time and swap time are each weapon's own, editable in the sheet.
	var weapons := SandboxSheet.from_disk().table(SandboxSheet.WEAPONS)
	for key: StringName in [&"aim_time", &"swap_time"]:
		_expect(not weapons.row(key).is_empty() and weapons.is_editable(key), "the sheet has no editable %s row" % key)
	_check_attachments_table(doc)


## The Attachments table: a column per Attachment file, a row per attribute
## any of them changes, each cell that file's factor, blank elsewhere; and
## the same table in `docs/sandbox.md`.
func _check_attachments_table(doc: String) -> void:
	var table := SandboxSheet.from_disk().table(SandboxSheet.ATTACHMENTS)
	_expect(table != null, "the sheet has no Attachments table")
	if table == null:
		return
	_expect(table.columns.size() == 14, "the Attachments table has %d columns, want 14" % table.columns.size())
	var want_columns := PackedStringArray(["Combat Scope", "Long Scope", "Reflex Sight", "Long Barrel", "Short Barrel",
			"Suppressor", "Drum", "Extended Magazine", "Quick Magazine", "Bipod", "Foregrip", "Laser", "Heavy Stock", "Light Stock"])
	_expect(table.columns == want_columns, "Attachment columns are %s" % table.columns)
	var files := DirAccess.get_files_at("res://resources/attachments/")
	var keys := {}
	var cells := 0
	for file in files:
		if not file.ends_with(".tres"):
			continue
		var attachment: Resource = ResourceLoader.load("res://resources/attachments/" + file, "", ResourceLoader.CACHE_MODE_IGNORE)
		var column := table.columns.find(attachment.display_name)
		_expect(column >= 0, "no column for %s" % attachment.display_name)
		if column < 0:
			continue
		for row in table.rows:
			var want: Variant = attachment.changes.get(row.key)
			var have: Variant = table.value(row.key, column)
			_expect((want == null and have == null) or (want != null and have != null and is_equal_approx(have, want)),
					"%s's %s cell is %s, its file says %s" % [attachment.display_name, row.key, have, want])
			cells += int(want != null)
		for key: StringName in attachment.changes:
			keys[key] = true
			_expect(not table.row(key).is_empty(), "no Attachments row for %s, which %s changes" % [key, attachment.display_name])
	_expect(table.rows.size() == keys.size(), "the Attachments table has %d rows; the files change %d attributes" % [table.rows.size(), keys.size()])
	_expect(cells == 52, "%d factor cells, want 52 (the files' changes)" % cells)
	for line in ["## Attachments", "| | %s |" % " | ".join(want_columns),
			"| Loudness |  |  |  |  |  | 0.4 |  |  |  |  |  |  |  |  |",
			"| Magazine Size |  |  |  |  |  |  | 2.5 | 1.5 | 0.8 |  |  |  |  |  |"]:
		_expect(doc.contains(line), "docs/sandbox.md lacks \"%s\"" % line)


## Fresh copies of the weapons, the Sandbox, the Gunnery and the
## Attachments under SCRATCH, with their own Markdown view. Returns
## {weapons: PackedStringArray, sandbox: String, gunnery: PackedStringArray,
## attachments: PackedStringArray, doc: String}.
func _scratch_copies() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCRATCH))
	var weapons := PackedStringArray()
	for path in SandboxSheet.all_weapon_paths():
		var copy := SCRATCH + path.get_file()
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))
		weapons.append(copy)
	var sandbox := SCRATCH + "sandbox.tres"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(Sandbox.PATH), ProjectSettings.globalize_path(sandbox))
	var gunnery := PackedStringArray()
	for path in Gunnery.PATHS:
		var copy := SCRATCH + "gunnery_" + path.get_file()
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))
		gunnery.append(copy)
	var attachments := PackedStringArray()
	for path in SandboxSheet.attachment_paths():
		var copy := SCRATCH + "attachment_" + path.get_file()
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(copy))
		attachments.append(copy)
	var sheet := SandboxSheet.from_disk(weapons, sandbox, gunnery, attachments)
	sheet.doc_path = SCRATCH + "sandbox.md"
	sheet.write_doc()
	return {"weapons": weapons, "sandbox": sandbox, "gunnery": gunnery, "attachments": attachments, "doc": sheet.doc_path}


## Changing a number in a `.tres` by hand, without regenerating, fails it.
func _check_stale_on_hand_edit(copies: Dictionary) -> void:
	var report := SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments).stale_report(copies.doc)
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
	report = SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments).stale_report(copies.doc)
	_expect(report.contains("stale"), "stale check passed after the Pistol's damage was edited by hand")
	SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments).write_doc(copies.doc)
	var worker_path: String = copies.gunnery[1]
	var worker_text := FileAccess.get_file_as_string(worker_path).replace("burst_length = 2", "burst_length = 5")
	file = FileAccess.open(worker_path, FileAccess.WRITE)
	file.store_string(worker_text)
	file.close()
	report = SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments).stale_report(copies.doc)
	_expect(report.contains("stale"), "stale check passed after the Worker's Gunnery was edited by hand")
	SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments).write_doc(copies.doc)
	var suppressor_path := _attachment_copy(copies, "suppressor.tres")
	var suppressor_text := FileAccess.get_file_as_string(suppressor_path).replace("&\"loudness\": 0.4", "&\"loudness\": 0.45")
	_expect(suppressor_text != FileAccess.get_file_as_string(suppressor_path), "the Suppressor file has no loudness 0.4 to edit")
	file = FileAccess.open(suppressor_path, FileAccess.WRITE)
	file.store_string(suppressor_text)
	file.close()
	report = SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments).stale_report(copies.doc)
	_expect(report.contains("stale"), "stale check passed after the Suppressor's loudness factor was edited by hand")
	var sandbox_text := FileAccess.get_file_as_string(copies.sandbox).replace("crew_health = 100", "crew_health = 90")
	file = FileAccess.open(copies.sandbox, FileAccess.WRITE)
	file.store_string(sandbox_text)
	file.close()
	var fresh := SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments)
	fresh.write_doc(copies.doc)
	_expect(fresh.stale_report(copies.doc) == "", "stale check still fails after regenerating")


## An edit changes the live Resource and marks the cell against disk;
## Revert puts it back; Save writes the Resources and the Markdown view.
func _check_edit_save_revert(copies: Dictionary) -> void:
	var pistol: WeaponProfile = load(copies.weapons[0])
	var rifle: WeaponProfile = load(copies.weapons[1])
	var shotgun: WeaponProfile = load(copies.weapons[2])
	var marksman: WeaponProfile = load(copies.weapons[3])
	var sandbox: Sandbox = load(copies.sandbox)
	var guard: Gunnery = load(copies.gunnery[0])
	var worker: Gunnery = load(copies.gunnery[1])
	var attachments := []
	for path in copies.attachments:
		attachments.append(load(path))
	var sheet := SandboxSheet.build([pistol, rifle, shotgun, marksman], sandbox, [guard, worker], attachments)
	sheet.doc_path = copies.doc
	var weapons := sheet.table(SandboxSheet.WEAPONS)
	var health := sheet.table(SandboxSheet.HEALTH)
	var gunnery := sheet.table(SandboxSheet.GUNNERY)
	_expect(gunnery != null and gunnery.columns == PackedStringArray(["Guard", "Worker"]), "the sheet has no Guard and Worker Gunnery table")
	if gunnery == null:
		return
	for key in [&"aim_error_degrees", &"burst_length", &"pause_between_bursts", &"engage_range"]:
		_expect(gunnery.is_editable(key), "Gunnery's %s is not editable in the sheet" % key)
	_expect(weapons.columns == PackedStringArray(["Pistol", "Assault Rifle", "Shotgun", "Marksman Rifle"]), "weapon columns are %s" % weapons.columns)
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
	for key in [&"shell_reload", &"first_shell_time", &"shell_time", &"closing_pump_time", &"break_out_time"]:
		_expect(weapons.is_editable(key), "the shell reload's %s is not editable in the sheet" % key)
	_expect(is_equal_approx(weapons.value(&"seconds_empty_to_full", 2), 3.25)
			and is_equal_approx(weapons.value(&"seconds_empty_to_full", 0), 1.6),
			"empty to full reads %s s for the Shotgun and %s s for the Pistol, want 3.25 and 1.6"
			% [weapons.value(&"seconds_empty_to_full", 2), weapons.value(&"seconds_empty_to_full", 0)])
	_expect(weapons.set_value(&"shell_time", 2, 0.5) and is_equal_approx(weapons.value(&"seconds_empty_to_full", 2), 3.5),
			"empty to full did not follow a 0.5 s shell time: %s" % weapons.value(&"seconds_empty_to_full", 2))
	_expect(is_equal_approx(weapons.value(&"seconds_to_kill_crew", 1), 0.27),
			"the Assault Rifle kills crew in %s s, want 0.27 (three intervals of 0.09)" % weapons.value(&"seconds_to_kill_crew", 1))

	sheet.revert()
	_expect(pistol.damage == 25 and sheet.changed_count() == 0, "Revert left the Pistol on %d damage" % pistol.damage)

	weapons.set_value(&"damage", 0, 40)
	weapons.set_value(&"semi_auto", 1, true)
	health.set_value(&"crew_health", 0, 120)
	gunnery.set_value(&"burst_length", 1, 4)
	gunnery.set_value(&"engage_range", 0, 12.5)
	_expect(worker.burst_length == 4 and guard.engage_range == 12.5, "the sheet did not change the live Gunnery")
	_expect(weapons.value(&"shots_to_kill_crew", 0) == 3 and weapons.value(&"shots_to_kill_crew", 1) == 5,
			"shots to kill crew did not follow crew Health 120")
	_expect(sheet.changed_count() == 5, "five edits mark %d cells" % sheet.changed_count())
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
	var saved_guard: Gunnery = ResourceLoader.load(copies.gunnery[0], "", ResourceLoader.CACHE_MODE_IGNORE)
	var saved_worker: Gunnery = ResourceLoader.load(copies.gunnery[1], "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(saved_worker.burst_length == 4 and is_equal_approx(saved_guard.engage_range, 12.5),
			"Save wrote the Worker's burst as %d and the Guard's engage range as %s" % [saved_worker.burst_length, saved_guard.engage_range])
	_expect(SandboxSheet.from_disk(copies.weapons, copies.sandbox, copies.gunnery, copies.attachments).stale_report(copies.doc) == "",
			"Save left the Markdown view stale")
	_expect(FileAccess.get_file_as_string(copies.doc).contains("| Damage | 40 | 25 |"), "the saved view lacks the Pistol at 40")
	_check_factor_save_revert(sheet, copies)


## A factor is dialled like any number: the live Attachment changes, the
## cell is marked against disk, Revert puts it back, Save writes the file.
func _check_factor_save_revert(sheet: SandboxSheet, copies: Dictionary) -> void:
	var table := sheet.table(SandboxSheet.ATTACHMENTS)
	var column := table.columns.find("Suppressor")
	var suppressor: Resource = table.targets[column]
	_expect(suppressor.resource_path == _attachment_copy(copies, "suppressor.tres"), "the Suppressor column is not its scratch file")
	_expect(not table.set_value(&"magazine_size", column, 2.0) and not suppressor.changes.has(&"magazine_size"),
			"a blank factor cell took a value")
	_expect(table.set_value(&"loudness", column, 0.5), "the Suppressor's loudness factor would not take 0.5")
	_expect(is_equal_approx(suppressor.changes[&"loudness"], 0.5), "the live Suppressor's loudness factor is %s" % suppressor.changes[&"loudness"])
	_expect(table.is_changed(&"loudness", column) and is_equal_approx(table.disk_value(&"loudness", column), 0.4),
			"the factor cell is not marked against the disk value 0.4")
	sheet.revert()
	_expect(is_equal_approx(suppressor.changes[&"loudness"], 0.4) and sheet.changed_count() == 0,
			"Revert left the Suppressor's loudness factor on %s" % suppressor.changes[&"loudness"])
	table.set_value(&"loudness", column, 0.5)
	_expect(sheet.save() == OK, "Save failed on a factor")
	var saved: Resource = ResourceLoader.load(suppressor.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	_expect(is_equal_approx(saved.changes[&"loudness"], 0.5) and is_equal_approx(saved.changes[&"projectile_speed"], 0.8)
			and saved.suppresses and saved.display_name == "Suppressor",
			"Save wrote the Suppressor as %s" % saved.changes)
	_expect(FileAccess.get_file_as_string(copies.doc).contains("| Loudness |  |  |  |  |  | 0.5 |"), "the saved view lacks the Suppressor at 0.5")


func _attachment_copy(copies: Dictionary, file: String) -> String:
	for path: String in copies.attachments:
		if path.ends_with("_" + file):
			return path
	return ""


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
	# Locals here are typed by their engine class (Node, Resource), not their
	# script class: naming PauseMenu, SandboxSheetView, Crew3D and the rest
	# as types in this function leaves their scripts "still in use" at exit
	# under --script, which the gate counts as an engine error.
	var sandbox: Resource = load(Sandbox.PATH)
	sandbox.pirate_health = 123
	sandbox.crew_health = 77
	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var player: CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	var pause: Node = main.get_node("PauseMenu")
	_expect(player.health.max_health == 123 and player.health.current == 123,
			"the Pirate spawned on %d Health, not the Sandbox's 123" % player.health.max_health)
	var crew := get_nodes_in_group(&"crew")
	_expect(not crew.is_empty(), "the Raid has no crew")
	for body in crew:
		_expect(body.health.max_health == 77 and body.health.current == 77,
				"a crew member spawned on %d Health, not the Sandbox's 77" % body.health.max_health)
	sandbox.pirate_health = 150
	sandbox.crew_health = 100

	var view: Node = main.get_node_or_null("SandboxSheet")
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
	var pistol: Resource = player.weapon
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
	var shot: Node = player.fire()
	_expect(shot != null and shot.damage == 40, "the next shot after the edit does %s damage, not 40" % (shot.damage if shot else "no"))
	# Crew fire the same Pistol, so the edit reaches their shots too.
	var gunman: Node = crew[0]
	_expect(gunman.weapon == pistol, "crew do not hold the Pirate's own Pistol")
	var crew_shot: Node = gunman._fire()
	_expect(crew_shot != null and crew_shot.damage == 40, "a crew shot after the edit does %s damage, not 40"
			% (crew_shot.damage if crew_shot else "no"))
	# A Gunnery edit reaches the crew of that type.
	_key(KEY_F1)
	var guard_gunnery: Resource = load(Gunnery.GUARD_PATH)
	(view.cell(SandboxSheet.GUNNERY, &"aim_error_degrees", 0) as SpinBox).value = 3.0
	for body: Node in crew:
		if not body.is_worker():
			_expect(body.gunnery == guard_gunnery and is_equal_approx(body.base_cone_degrees(), 4.0),
					"a Guard's cone is %.1f after aim error 3 on a 1 degree Pistol" % body.base_cone_degrees())
	_expect(view.disk_shown(SandboxSheet.GUNNERY, &"aim_error_degrees", 0) == "6.0", "the Gunnery cell does not show the disk value 6.0")
	_key(KEY_F1)
	# Pirate Health applies live too.
	_key(KEY_F1)
	(view.cell(SandboxSheet.HEALTH, &"pirate_health", 0) as SpinBox).value = 175
	_expect(player.health.max_health == 175 and player.health.current == 175, "a Pirate Health edit did not reach the Pirate")
	view.revert_button().pressed.emit()
	_expect(is_equal_approx(guard_gunnery.aim_error_degrees, 6.0), "Revert left the Guard's aim error on %s" % guard_gunnery.aim_error_degrees)
	_expect(pistol.damage == 25 and sandbox.pirate_health == 150 and player.health.max_health == 150,
			"Revert left damage %d, Pirate Health %d" % [pistol.damage, sandbox.pirate_health])
	_expect((view.cell(SandboxSheet.WEAPONS, &"damage", 0) as SpinBox).value == 25.0
			and view.disk_shown(SandboxSheet.WEAPONS, &"damage", 0) == "", "the cell does not show the reverted value")
	_key(KEY_F1)
	paused = false
	main.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## A Raid from the menu, carrying Built Weapons: the weapon columns stay
## four, a carried gun's Built Weapon value sits beside the bare one, a
## dialled factor or bare number reaches the gun in hand while the sheet is
## still open, and the debug strip swaps the Loadout on close without
## writing the saved one.
func _check_menu_raid() -> void:
	var profile := "user://sandbox_profile_%d.cfg" % OS.get_process_id()
	var saved_profile_path := Profile.path
	Profile.path = profile
	var rifle: Resource = load("res://resources/weapons/assault_rifle.tres")
	var pistol: Resource = load("res://resources/weapons/pistol.tres")
	var shotgun: Resource = load("res://resources/weapons/shotgun.tres")
	var suppressor: Resource = load("res://resources/attachments/suppressor.tres")
	var drum: Resource = load("res://resources/attachments/drum.tres")
	var short_barrel: Resource = load("res://resources/attachments/short_barrel.tres")
	var loadout := Loadout.new()
	loadout.set_first(rifle)
	loadout.set_second(pistol)
	loadout.set_attachment(rifle, Attachment.Slot.BARREL, suppressor)
	loadout.set_attachment(rifle, Attachment.Slot.MAGAZINE, drum)
	loadout.save()
	var profile_before := FileAccess.get_file_as_string(profile)
	_expect(profile_before.contains("suppressor"), "the test Loadout did not save")
	Raid.ship_class = &"small"
	Raid.seed = 1
	Raid.arm(Loadout.load_saved())
	var main: Node3D = load("res://scenes/main_3d.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	var player: CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	var view: Node = main.get_node("SandboxSheet")
	var held: Resource = player.weapon
	_expect(player.weapons.size() == 2 and held.attachments == [suppressor, drum] and is_equal_approx(held.loudness, 9.6),
			"the menu Raid does not carry the suppressed Assault Rifle with a Drum in hand")
	player.fire()
	_key(KEY_F1)
	_expect(view.is_open(), "F1 did not open the sheet in a menu Raid")

	var weapons: SheetTable = view.sheet.table(SandboxSheet.WEAPONS)
	_expect(weapons.columns == PackedStringArray(["Pistol", "Assault Rifle", "Shotgun", "Marksman Rifle"]),
			"with two guns carried the weapon columns are %s" % weapons.columns)
	_expect((view.cell(SandboxSheet.WEAPONS, &"magazine_size", 1) as SpinBox).value == 30.0
			and view.built_shown(SandboxSheet.WEAPONS, &"magazine_size", 1) == "75",
			"the Assault Rifle's magazine reads %s, beside it \"%s\"; want 30 and 75"
			% [(view.cell(SandboxSheet.WEAPONS, &"magazine_size", 1) as SpinBox).value, view.built_shown(SandboxSheet.WEAPONS, &"magazine_size", 1)])
	_expect(view.built_shown(SandboxSheet.WEAPONS, &"damage", 1) == "", "the Built Weapon's damage, the same as bare, is shown beside it")
	_expect(view.built_shown(SandboxSheet.WEAPONS, &"magazine_size", 0) == "", "the bare carried Pistol shows a Built Weapon value")
	_expect(view.built_shown(SandboxSheet.WEAPONS, &"magazine_size", 2) == "", "the Shotgun, not carried, shows a Built Weapon value")
	_expect(view.built_shown(SandboxSheet.WEAPONS, &"seconds_empty_to_full", 1) != "", "a derived row shows no Built Weapon value")

	var column: int = view.sheet.table(SandboxSheet.ATTACHMENTS).columns.find("Suppressor")
	var factor := view.cell(SandboxSheet.ATTACHMENTS, &"loudness", column) as SpinBox
	_expect(factor != null, "the Suppressor's loudness factor is not a number field")
	if factor != null:
		factor.value = 0.5
		_expect(view.is_open() and is_equal_approx(player.weapon.loudness, 12.0),
				"with the Suppressor's factor at 0.5 the gun in hand is %s loud, want 12.0" % player.weapon.loudness)
		_expect(player.weapon == held, "the rebuild swapped the gun in hand for another object")
		_expect(view.built_shown(SandboxSheet.WEAPONS, &"loudness", 1) == "12.0", "the loudness beside the bare 24 reads \"%s\", want 12.0"
				% view.built_shown(SandboxSheet.WEAPONS, &"loudness", 1))
		(view.cell(SandboxSheet.WEAPONS, &"magazine_size", 1) as SpinBox).value = 40
		_expect(player.weapon.magazine_size == 100, "a bare magazine of 40 with a Drum built %d, want 100" % player.weapon.magazine_size)
		view.revert_button().pressed.emit()
		_expect(is_equal_approx(suppressor.changes[&"loudness"], 0.4) and is_equal_approx(player.weapon.loudness, 9.6)
				and player.weapon.magazine_size == 75,
				"Revert left the factor %s, the gun %s loud with %d rounds"
				% [suppressor.changes[&"loudness"], player.weapon.loudness, player.weapon.magazine_size])

	# The debug strip: Shotgun first with a Short Barrel, applied on close.
	_pick(view.strip_gun(0), "Shotgun")
	var barrel: OptionButton = view.strip_slot(0, Attachment.Slot.BARREL)
	_expect(barrel != null, "the strip has no Barrel picker under the Shotgun")
	if barrel != null:
		var offered := PackedStringArray()
		for i in barrel.item_count:
			offered.append(barrel.get_item_text(i))
		_expect(offered == PackedStringArray(["no Barrel", "Long Barrel", "Short Barrel"]), "the Shotgun's Barrel picker offers %s" % offered)
		_pick(barrel, "Short Barrel")
	_expect(view.strip_slot(0, Attachment.Slot.MAGAZINE) == null, "the strip offers a Magazine on the Shotgun, which has none")
	_expect(player.weapon == held, "the strip changed the gun before the sheet closed")
	_key(KEY_F1)
	var now: Resource = player.weapon
	_expect(not view.is_open() and now.bare == shotgun and now.attachments == [short_barrel],
			"closing the sheet put %s with %s in hand, want the Shotgun with a Short Barrel" % [now.bare, now.attachments])
	_expect(player.ammo == now.magazine_size and player.ammo == 6, "the new gun's magazine holds %d, want full (6)" % player.ammo)
	_expect(player.weapons.size() == 2 and player.weapons[1].bare == pistol, "the second gun is no longer the Pistol")
	_expect(FileAccess.get_file_as_string(profile) == profile_before, "the debug strip wrote the saved Loadout")
	# Opening and closing again with no change leaves the guns alone.
	_key(KEY_F1)
	_key(KEY_F1)
	_expect(player.weapon == now, "closing the sheet without a strip change rebuilt the guns")

	paused = false
	main.free()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Raid.seed = 0
	Raid.ship_class = &""
	Raid.weapons = []
	DirAccess.remove_absolute(ProjectSettings.globalize_path(profile))
	Profile.path = saved_profile_path


func _pick(option: OptionButton, text: String) -> void:
	_expect(option != null, "no picker to pick %s in" % text)
	if option == null:
		return
	for i in option.item_count:
		if option.get_item_text(i) == text:
			option.select(i)
			option.item_selected.emit(i)
			return
	_expect(false, "the picker does not offer %s" % text)


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
