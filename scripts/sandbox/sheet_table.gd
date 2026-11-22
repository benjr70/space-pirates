class_name SheetTable
extends RefCounted
## One table of the Sandbox sheet: a Resource per column, a row per exported
## property, grouped as the Resource's script groups them, plus read-only
## derived rows computed from each column's Resource. It knows what is on
## disk for every column, so it can say which cells changed, put them back,
## and save them. The in-Raid sheet draws it; [SandboxSheet] renders it as
## Markdown.
##
## A new kind of table (Gunnery, one Resource per crew type) is
## [method from_resources] over its Resources; a new derived row is
## [method add_derived]; a new exported field on a Resource is a new row
## with no change here.

## EDIT: a number or a switch, changed in the sheet. READ_ONLY: anything
## else (a model, a pose, a clip name, a sound), edited in the Inspector.
## DERIVED: computed from the column, never stored.
enum Kind { EDIT, READ_ONLY, DERIVED }

const DERIVED_GROUP := "Derived"

var title: String
var columns: PackedStringArray
## One Resource per column: the live one, shared with the game.
var targets: Array[Resource] = []
## Where each column's Resource lives on disk; Save writes there.
var paths: PackedStringArray
## {key: StringName, label: String, group: String, kind: Kind, type: int,
## compute: Callable}, in display order.
var rows: Array[Dictionary] = []
## Read-only lines shown under the table, in the sheet and the Markdown.
var notes: PackedStringArray
## Each column's Resource as it is on disk, loaded apart from the live one.
var _disk: Array[Resource] = []


## A table over [param resources], one column each, named by
## [param column_names], with a row per exported script property.
static func from_resources(table_title: String, column_names: PackedStringArray,
		resources: Array) -> SheetTable:
	var table := SheetTable.new()
	table.title = table_title
	table.columns = column_names
	for resource: Resource in resources:
		table.targets.append(resource)
		table.paths.append(resource.resource_path)
	if not resources.is_empty():
		table._rows_from(resources[0])
	table.reload_disk()
	return table


func _rows_from(resource: Resource) -> void:
	var group := ""
	for p: Dictionary in resource.get_property_list():
		if p.usage & PROPERTY_USAGE_GROUP:
			group = p.name
		elif p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR:
			var editable: bool = p.type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]
			rows.append({"key": StringName(p.name), "label": String(p.name).capitalize(), "group": group,
					"kind": Kind.EDIT if editable else Kind.READ_ONLY, "type": p.type, "compute": Callable()})


## A read-only row under the Derived group: [param compute] takes a
## column's Resource and returns the value.
func add_derived(key: StringName, label: String, compute: Callable) -> void:
	rows.append({"key": key, "label": label, "group": DERIVED_GROUP, "kind": Kind.DERIVED,
			"type": TYPE_NIL, "compute": compute})


func add_note(text: String) -> void:
	notes.append(text)


func row(key: StringName) -> Dictionary:
	for r in rows:
		if r.key == key:
			return r
	return {}


func is_editable(key: StringName) -> bool:
	var r := row(key)
	return not r.is_empty() and r.kind == Kind.EDIT


func value(key: StringName, column: int) -> Variant:
	return _read(row(key), targets[column])


func disk_value(key: StringName, column: int) -> Variant:
	var disk := _disk[column]
	return null if disk == null else _read(row(key), disk)


func _read(r: Dictionary, resource: Resource) -> Variant:
	if r.is_empty():
		return null
	if r.kind == Kind.DERIVED:
		return r.compute.call(resource)
	return resource.get(r.key)


## Whether an editable cell differs from what is on disk.
func is_changed(key: StringName, column: int) -> bool:
	if not is_editable(key) or _disk[column] == null:
		return false
	return not same(value(key, column), disk_value(key, column))


func changed_count() -> int:
	var count := 0
	for r in rows:
		for c in columns.size():
			count += int(is_changed(r.key, c))
	return count


## Changes the live Resource. Returns false for a read-only or derived row,
## or a value no different from the one already there.
func set_value(key: StringName, column: int, new_value: Variant) -> bool:
	var r := row(key)
	if r.is_empty() or r.kind != Kind.EDIT:
		return false
	match r.type:
		TYPE_INT: new_value = int(new_value)
		TYPE_FLOAT: new_value = float(new_value)
		TYPE_BOOL: new_value = bool(new_value)
	if same(targets[column].get(key), new_value):
		return false
	targets[column].set(key, new_value)
	return true


## Puts every changed cell back to its disk value. Returns the cells put
## back, as [key, column] pairs.
func revert() -> Array:
	var reverted := []
	for r in rows:
		for c in columns.size():
			if is_changed(r.key, c):
				targets[c].set(r.key, disk_value(r.key, c))
				reverted.append([r.key, c])
	return reverted


## Writes every column's Resource to its file, then rereads the disk.
func save() -> Error:
	for c in targets.size():
		if paths[c] == "":
			continue
		var err := ResourceSaver.save(targets[c], paths[c])
		if err != OK:
			return err
	reload_disk()
	return OK


## Rereads each column's file, apart from the live Resource.
func reload_disk() -> void:
	_disk.clear()
	for path in paths:
		var disk: Resource = null
		if path != "" and ResourceLoader.exists(path):
			disk = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		_disk.append(disk)


## Every row as a Markdown table, groups as bold rows, derived rows marked
## with `=`, and the notes after it.
func to_markdown() -> String:
	var lines := PackedStringArray()
	lines.append("## %s" % title)
	lines.append("")
	lines.append("| | %s |" % " | ".join(columns))
	lines.append("|---|%s" % "---|".repeat(columns.size()))
	var group := ""
	for r in rows:
		if r.group != group:
			group = r.group
			lines.append("| **%s** |%s" % [group, " |".repeat(columns.size())])
		var cells := PackedStringArray()
		for c in columns.size():
			cells.append(format(value(r.key, c)))
		lines.append("| %s%s | %s |" % ["= " if r.kind == Kind.DERIVED else "", r.label, " | ".join(cells)])
	if not notes.is_empty():
		lines.append("")
		for note in notes:
			lines.append(note)
	return "\n".join(lines) + "\n"


## How a cell reads, in the sheet and the Markdown alike.
static func format(v: Variant) -> String:
	if v == null:
		return "-"
	match typeof(v):
		TYPE_FLOAT:
			return String.num(v, 4)
		TYPE_STRING_NAME, TYPE_STRING:
			return "-" if String(v) == "" else String(v)
		TYPE_VECTOR3:
			return "(%s, %s, %s)" % [String.num(v.x, 4), String.num(v.y, 4), String.num(v.z, 4)]
		TYPE_OBJECT:
			if v is Resource and v.resource_path != "":
				return v.resource_path.get_file()
			return str(v)
	return str(v)


static func same(a: Variant, b: Variant) -> bool:
	if typeof(a) == TYPE_FLOAT and typeof(b) == TYPE_FLOAT:
		return is_equal_approx(a, b)
	return typeof(a) == typeof(b) and a == b
