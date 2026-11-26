class_name SandboxSheet
extends RefCounted
## Every Sandbox number as tables: the four Weapon Profiles side by side
## with their derived rows, the [Sandbox] resource's Health and Melee, each
## weapon's [Gunnery], the Sandbox's Crew fight and Surrender and Bound, and
## every [Attachment]'s factors. One
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
const CREW_FIGHT := "Crew fight"
const SURRENDER := "Surrender and Bound"
## The [Sandbox] export groups each of its tables shows.
const SANDBOX_GROUPS := {
	HEALTH: ["Health", "Melee"],
	CREW_FIGHT: ["Crew fight"],
	SURRENDER: ["Surrender and Bound"],
}
const GUNNERY := "Gunnery"
const ATTACHMENTS := "Attachments"
const ATTACHMENT_DIR := "res://resources/attachments/"
const REGENERATE := "flatpak run org.godotengine.Godot --headless --path . --script res://scripts/sandbox/write_sandbox_doc.gd"

var tables: Array[SheetTable] = []
var sandbox: Sandbox
## Where Save writes the Markdown view.
var doc_path := DOC_PATH
## The Built Weapons the Pirate carries, set by the in-Raid sheet: each
## shown beside the bare Profile it was built from ([method built_value]),
## and rebuilt when that Profile or an Attachment is dialled ([method
## rebuild_carried]). Never written to `docs/sandbox.md`.
var carried: Array[WeaponProfile] = []


## The sheet over these live Resources: the ones the Raid is playing with.
## [param gunneries] are one [Gunnery] per weapon, in [constant
## Gunnery.NAMES] order; none, and the sheet has no Gunnery table.
## [param attachments] are every [Attachment], in [method attachment_paths]
## order; none, and no Attachments table.
static func build(weapons: Array, sandbox_resource: Sandbox, gunneries: Array = [],
		attachments: Array = []) -> SandboxSheet:
	var sheet := SandboxSheet.new()
	sheet.sandbox = sandbox_resource
	var names := PackedStringArray()
	for weapon: Resource in weapons:
		names.append(weapon_name(weapon))
	var weapon_table := SheetTable.from_resources(WEAPONS, names, weapons)
	_add_weapon_derived(weapon_table, sandbox_resource)
	sheet.add_table(weapon_table)
	var health := SheetTable.from_resources(HEALTH, PackedStringArray(["Value"]), [sandbox_resource],
			PackedStringArray(SANDBOX_GROUPS[HEALTH]))
	health.add_note("Melee from behind (inside the %s degree cone behind the target's facing) kills outright, whatever the damage."
			% SheetTable.format(_player_default(&"melee_back_cone_degrees")))
	sheet.add_table(health)
	if not gunneries.is_empty():
		var gunnery := SheetTable.from_resources(GUNNERY, Gunnery.NAMES.slice(0, gunneries.size()), gunneries)
		gunnery.add_note("A Guard fires the gun it rolled at ship build: that weapon's damage, projectile, pellets, time between shots and sounds. "
				+ "Aim error adds to the weapon's base cone. Each Guard draws its own %s-%sx on time between shots at spawn. "
				% [SheetTable.format(CrewCombat.JITTER.x), SheetTable.format(CrewCombat.JITTER.y)]
				+ "Spread opens at the opening spread times (base cone plus aim error) on first sight and closes to 1x over the closing time. "
				+ "Range band is where it likes to fight from (a term in its cover score); hold before shifting is how long it holds a spot out of its band before moving one nearer or further, negative never (the Marksman Rifle). "
				+ "Reload factor multiplies the weapon's reload times in a Guard's hands.")
		sheet.add_table(gunnery)
	var fight := SheetTable.from_resources(CREW_FIGHT, PackedStringArray(["Value"]), [sandbox_resource],
			PackedStringArray(SANDBOX_GROUPS[CREW_FIGHT]))
	fight.add_note("How many aim true at once (at least one always does while any has a shot) and the seconds each holds it before handing on; "
			+ "the walk-in is metres to one side the first burst of a sighting starts; the pellet cap is how many pellets of one crew Shotgun shot do damage. "
			+ "Suppression time is seconds Pistol and Assault Rifle Guards fire at the edges of the prop he broke sight behind. "
			+ "Too close (metres, in his sight) sends a Guard to a spot further off; flank reaction is the seconds he must see it where it hides before it moves; "
			+ "open floor is the metres in his view a Guard's walk to a spot may cross. Read live: an edit reaches Guards already in the Raid.")
	sheet.add_table(fight)
	sheet.add_table(SheetTable.from_resources(SURRENDER, PackedStringArray(["Value"]), [sandbox_resource],
			PackedStringArray(SANDBOX_GROUPS[SURRENDER])))
	if not attachments.is_empty():
		var names_of := PackedStringArray()
		for attachment: Resource in attachments:
			names_of.append(attachment.display_name)
		var order := PackedStringArray()
		for p: Dictionary in weapon_table.targets[0].get_property_list() if not weapons.is_empty() else []:
			order.append(p.name)
		var table := SheetTable.from_factors(ATTACHMENTS, names_of, attachments, order)
		table.add_note("Each cell multiplies that attribute of the gun the Attachment is fitted to; blank changes nothing. "
				+ "Two on one attribute multiply. A whole-number attribute rounds and never goes under 1; times and spreads never go under 0; zoom never under 1.")
		sheet.add_table(table)
	return sheet


## The sheet over what is on disk, loaded apart from anything the game has
## cached: what the stale check compares `docs/sandbox.md` against.
static func from_disk(weapon_paths: PackedStringArray = all_weapon_paths(),
		sandbox_path: String = Sandbox.PATH, gunnery_paths: PackedStringArray = Gunnery.PATHS,
		attachment_files: PackedStringArray = attachment_paths()) -> SandboxSheet:
	var weapons := []
	for path in weapon_paths:
		weapons.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE))
	var gunneries := []
	for path in gunnery_paths:
		gunneries.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE))
	var attachments := []
	for path in attachment_files:
		attachments.append(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE))
	var sandbox_resource: Sandbox = ResourceLoader.load(sandbox_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var sheet := build(weapons, sandbox_resource, gunneries, attachments)
	# Loaded apart from the cache, so give each column back its file.
	for table in sheet.tables:
		if table.title == WEAPONS:
			table.paths = weapon_paths
		elif table.title in SANDBOX_GROUPS:
			table.paths = PackedStringArray([sandbox_path])
		elif table.title == GUNNERY:
			table.paths = gunnery_paths
		elif table.title == ATTACHMENTS:
			table.paths = attachment_files
		table.reload_disk()
	return sheet


## The four weapons, in wheel order, whatever the Pirate carries.
static func all_weapon_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for weapon in Loadout.all_weapons():
		paths.append(weapon.resource_path)
	return paths


## Every Attachment file, by Slot and then by file name: the Attachments
## table's column order.
static func attachment_paths() -> PackedStringArray:
	var by_slot := []
	for file in DirAccess.get_files_at(ATTACHMENT_DIR):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			by_slot.append([load(ATTACHMENT_DIR + file).slot, file])
	by_slot.sort()
	var paths := PackedStringArray()
	for pair: Array in by_slot:
		paths.append(ATTACHMENT_DIR + pair[1])
	return paths


## Every Attachment, the live ones the game builds with, in
## [method attachment_paths] order.
static func all_attachments() -> Array[Attachment]:
	var out: Array[Attachment] = []
	for path in attachment_paths():
		out.append(load(path))
	return out


## "assault_rifle.tres" reads "Assault Rifle".
static func weapon_name(weapon: Resource) -> String:
	return weapon.resource_path.get_file().get_basename().capitalize()


static func _player_default(property: StringName) -> Variant:
	var script: Script = load("res://scripts/player_3d.gd")
	return script.get_property_default_value(property)


## Static, and reading the Sandbox through a local: a lambda that captured
## the sheet would hold it alive from its own table, and the pair (with every
## Weapon Profile) would never be freed.
static func _add_weapon_derived(table: SheetTable, sandbox: Sandbox) -> void:
	table.add_derived(&"reach", "Reach (m)", func(w: WeaponProfile) -> float:
		return w.projectile_speed * w.projectile_lifetime)
	table.add_derived(&"damage_per_shot", "Damage per shot", func(w: WeaponProfile) -> int:
		return w.damage * w.pellet_count)
	table.add_derived(&"shots_to_kill_crew", "Shots to kill crew", func(w: WeaponProfile) -> int:
		return _shots_to_kill_crew(w, sandbox))
	# Every bolt on the head: for the Shotgun, every pellet.
	table.add_derived(&"shots_to_kill_crew_headshot", "Shots to kill crew by Headshot", func(w: WeaponProfile) -> int:
		return ceili(float(sandbox.crew_health) / maxi(w.headshot_damage() * w.pellet_count, 1)))
	# Only a gun with pellets has its own row: for one bolt it is the shots.
	table.add_derived(&"pellets_to_kill_crew", "Pellets to kill crew", func(w: WeaponProfile) -> Variant:
		return ceili(float(sandbox.crew_health) / maxi(w.damage, 1)) if w.pellet_count > 1 else null)
	table.add_derived(&"seconds_to_kill_crew", "Seconds to kill crew (from a full magazine)", func(w: WeaponProfile) -> float:
		var shots := _shots_to_kill_crew(w, sandbox)
		@warning_ignore("integer_division")
		var reloads := (shots - 1) / maxi(w.magazine_size, 1)
		return (shots - 1 - reloads) * w.fire_interval + reloads * w.seconds_empty_to_full())
	table.add_derived(&"shots_per_second", "Shots per second", func(w: WeaponProfile) -> float:
		return 1.0 / maxf(w.fire_interval, 0.001))
	table.add_derived(&"seconds_empty_to_full", "Seconds from empty to full", func(w: WeaponProfile) -> float:
		return w.seconds_empty_to_full())


## With every pellet landing.
static func _shots_to_kill_crew(w: WeaponProfile, sandbox: Sandbox) -> int:
	return ceili(float(sandbox.crew_health) / maxi(w.damage * w.pellet_count, 1))


## The carried Built Weapon's value on a Weapons row, for the column of the
## bare Profile it was built from; null where none is carried, where it is
## the same as bare, and on rows that are not numbers.
func built_value(key: StringName, column: int) -> Variant:
	var weapons := table(WEAPONS)
	var r := weapons.row(key)
	if r.is_empty() or r.kind == SheetTable.Kind.READ_ONLY:
		return null
	for built in carried:
		if built.bare == weapons.targets[column]:
			var v: Variant = weapons.value_of(key, built)
			return null if SheetTable.same(v, weapons.value(key, column)) else v
	return null


## Rebuilds every carried Built Weapon from its bare Profile and its
## Attachments as they are now in the sheet.
func rebuild_carried() -> void:
	for built in carried:
		built.rebuild()


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
	parts.append("# Sandbox\n\nEvery Sandbox number, generated from `resources/weapons/`, `resources/sandbox.tres`, `resources/gunnery/` and `resources/attachments/`. "
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
