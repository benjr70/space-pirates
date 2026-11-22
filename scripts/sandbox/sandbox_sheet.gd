class_name SandboxSheet
extends RefCounted
## Every Sandbox number as tables: the Weapon Profiles side by side with
## their derived rows, the [Sandbox] resource's Health and Melee, and each
## crew type's [Gunnery]. One
## generator for both views of it: the in-Raid sheet ([SandboxSheetView])
## edits these tables live and Saves them, and `docs/sandbox.md` is
## [method to_markdown] of them, written on Save and by
## `scripts/sandbox/write_sandbox_doc.gd`, and checked against the
## resources on disk by [method stale_report] in the test suite.
##
## A later table is [method add_table] in [method build]; later derived
## rows go in [method _add_weapon_derived].

const DOC_PATH := "res://docs/sandbox.md"
const WEAPONS := "Weapons"
const HEALTH := "Health and Melee"
const GUNNERY := "Gunnery"
const REGENERATE := "flatpak run org.godotengine.Godot --headless --path . --script res://scripts/sandbox/write_sandbox_doc.gd"

var tables: Array[SheetTable] = []
var sandbox: Sandbox
## Where Save writes the Markdown view.
var doc_path := DOC_PATH


## The sheet over these live Resources: the ones the Raid is playing with.
## [param gunneries] are one [Gunnery] per crew type, in [constant
## Gunnery.NAMES] order; none, and the sheet has no Gunnery table.
static func build(weapons: Array, sandbox_resource: Sandbox, gunneries: Array = []) -> SandboxSheet:
	var sheet := SandboxSheet.new()
	sheet.sandbox = sandbox_resource
	var names := PackedStringArray()
	for weapon: Resource in weapons:
		names.append(weapon_name(weapon))
	var weapon_table := SheetTable.from_resources(WEAPONS, names, weapons)
	sheet._add_weapon_derived(weapon_table)
	sheet.add_table(weapon_table)
	var health := SheetTable.from_resources(HEALTH, PackedStringArray(["Value"]), [sandbox_resource])
	health.add_note("Melee from behind (inside the %s degree cone behind the target's facing) kills outright, whatever the damage."
			% SheetTable.format(_player_default(&"melee_back_cone_degrees")))
	sheet.add_table(health)
	if not gunneries.is_empty():
		var gunnery := SheetTable.from_resources(GUNNERY, Gunnery.NAMES.slice(0, gunneries.size()), gunneries)
		gunnery.add_note("Crew fire the Pistol: its damage, bolt and time between shots. Aim error adds to the Pistol's base cone. "
				+ "Each crew member draws its own rhythm at spawn: a Guard's burst a round either way, and %s-%sx on time between shots and pause."
				% [SheetTable.format(CrewCombat.JITTER.x), SheetTable.format(CrewCombat.JITTER.y)])
		sheet.add_table(gunnery)
	return sheet


## The sheet over what is on disk, loaded apart from anything the game has
## cached: what the stale check compares `docs/sandbox.md` against.
static func from_disk(weapon_paths: PackedStringArray = carried_weapon_paths(),
		sandbox_path: String = Sandbox.PATH, gunnery_paths: PackedStringArray = Gunnery.PATHS) -> SandboxSheet:
	var weapons := []
	for path in weapon_paths:
		weapons.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE))
	var gunneries := []
	for path in gunnery_paths:
		gunneries.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE))
	var sandbox_resource: Sandbox = ResourceLoader.load(sandbox_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var sheet := build(weapons, sandbox_resource, gunneries)
	# Loaded apart from the cache, so give each column back its file.
	for table in sheet.tables:
		if table.title == WEAPONS:
			table.paths = weapon_paths
		elif table.title == HEALTH:
			table.paths = PackedStringArray([sandbox_path])
		elif table.title == GUNNERY:
			table.paths = gunnery_paths
		table.reload_disk()
	return sheet


## The weapons the Pirate carries, in his wheel order.
static func carried_weapon_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for weapon: Resource in _player_default(&"weapons"):
		paths.append(weapon.resource_path)
	return paths


## "assault_rifle.tres" reads "Assault Rifle".
static func weapon_name(weapon: Resource) -> String:
	return weapon.resource_path.get_file().get_basename().capitalize()


static func _player_default(property: StringName) -> Variant:
	var script: Script = load("res://scripts/player_3d.gd")
	return script.get_property_default_value(property)


func _add_weapon_derived(table: SheetTable) -> void:
	table.add_derived(&"reach", "Reach (m)", func(w: WeaponProfile) -> float:
		return w.projectile_speed * w.projectile_lifetime)
	table.add_derived(&"damage_per_shot", "Damage per shot", func(w: WeaponProfile) -> int:
		return w.damage * w.pellet_count)
	table.add_derived(&"shots_to_kill_crew", "Shots to kill crew", _shots_to_kill_crew)
	# Only a gun with pellets has its own row: for one bolt it is the shots.
	table.add_derived(&"pellets_to_kill_crew", "Pellets to kill crew", func(w: WeaponProfile) -> Variant:
		return ceili(float(sandbox.crew_health) / maxi(w.damage, 1)) if w.pellet_count > 1 else null)
	table.add_derived(&"seconds_to_kill_crew", "Seconds to kill crew (from a full magazine)", func(w: WeaponProfile) -> float:
		var shots := _shots_to_kill_crew(w)
		@warning_ignore("integer_division")
		var reloads := (shots - 1) / maxi(w.magazine_size, 1)
		return (shots - 1 - reloads) * w.fire_interval + reloads * w.reload_empty)
	table.add_derived(&"shots_per_second", "Shots per second", func(w: WeaponProfile) -> float:
		return 1.0 / maxf(w.fire_interval, 0.001))


## With every pellet landing.
func _shots_to_kill_crew(w: WeaponProfile) -> int:
	return ceili(float(sandbox.crew_health) / maxi(w.damage * w.pellet_count, 1))


func add_table(table: SheetTable) -> void:
	tables.append(table)


func table(table_title: String) -> SheetTable:
	for t in tables:
		if t.title == table_title:
			return t
	return null


func changed_count() -> int:
	var count := 0
	for t in tables:
		count += t.changed_count()
	return count


## Puts every unsaved change back. Returns [table, key, column] for each.
func revert() -> Array:
	var reverted := []
	for t in tables:
		for cell in t.revert():
			reverted.append([t, cell[0], cell[1]])
	return reverted


## Writes every table's Resources and the Markdown view.
func save() -> Error:
	for t in tables:
		var err := t.save()
		if err != OK:
			return err
	return write_doc()


func write_doc(path: String = doc_path) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_markdown())
	file.close()
	return OK


func to_markdown() -> String:
	var parts := PackedStringArray()
	parts.append("# Sandbox\n\nEvery Sandbox number, generated from `resources/weapons/`, `resources/sandbox.tres` and `resources/gunnery/`. "
			+ "Do not edit by hand: change numbers in the in-Raid sheet (F1, debug builds) and Save, or edit the "
			+ "resources and run `%s`. Rows marked `=` are derived.\n" % REGENERATE)
	for t in tables:
		parts.append(t.to_markdown())
	return "\n".join(parts)


## Empty when [param path] matches these tables, else what is wrong.
func stale_report(path: String = doc_path) -> String:
	if not FileAccess.file_exists(path):
		return "%s is missing; run %s" % [path, REGENERATE]
	var on_disk := FileAccess.get_file_as_string(path)
	var want := to_markdown()
	if on_disk == want:
		return ""
	var have_lines := on_disk.split("\n")
	var want_lines := want.split("\n")
	for i in maxi(have_lines.size(), want_lines.size()):
		var have := have_lines[i] if i < have_lines.size() else "<end>"
		var line := want_lines[i] if i < want_lines.size() else "<end>"
		if have != line:
			return "%s is stale at line %d: has \"%s\", resources say \"%s\"; run %s" % [path, i + 1, have, line, REGENERATE]
	return "%s is stale; run %s" % [path, REGENERATE]
