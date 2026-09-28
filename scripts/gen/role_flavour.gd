class_name RoleFlavour
extends RefCounted
## The Role flavour table: one data row per Room Role, read from
## `res://data/role_flavour.json`, that each Role's interior generator adds
## on top of the shared vocabulary. Changing a row changes the built Room
## without a code change; the parent generator reads nothing from it.
##
## A row holds: `container` (the prop kind its Containers take, or "none"
## for the vocabulary default), `signature` and `wall` (the signature prop
## and the wall it runs along; "fore" and "aft" put the Role's consoles on
## that wall with stations behind them, "long", "far" and "centre" name
## where the signature rule already looks), `islands` (what a free-standing island is
## made of), `consoles` (a [min, max] range), `crew` (posture: "deepest"
## cover first, "stations" at the signature consoles, "ring" around the
## signature prop, or "alcoves" for a Corridor) and `light` (an [r, g, b]
## tint for the Room's light). Cargo also carries `runs`, the [min, max]
## length of a Container run along the wall.
##
## New prop kinds (safe, generator, cabinet, footlocker) are named here and
## mapped to placeholder prop types under `placeholders`, so the generator
## never changes when the art for one lands.

const PATH := "res://data/role_flavour.json"

## The row every unknown Role falls back to: the bare vocabulary.
const DEFAULT_ROW := {
	container = "none", signature = "", wall = "long", islands = "crates",
	consoles = [1, 1], crew = "deepest", light = [1.0, 1.0, 1.0],
}

static var _table: Dictionary = {}


## The whole table, loaded on first use.
static func table() -> Dictionary:
	if _table.is_empty():
		_table = load_table(PATH)
	return _table


## Replace the table in use (tests swap a row and put it back with
## [method reset]).
static func use(new_table: Dictionary) -> void:
	_table = new_table


## Drop the table in use so the next read loads the file again.
static func reset() -> void:
	_table = {}


## Parse the table at [param path]; an unreadable file yields an empty
## table and every Role reads [constant DEFAULT_ROW].
static func load_table(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("RoleFlavour: cannot read %s" % path)
		return {roles = {}, placeholders = {}}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("RoleFlavour: %s is not a JSON object" % path)
		return {roles = {}, placeholders = {}}
	return parsed


## The row for a Role, with every field present.
static func row(role: StringName) -> Dictionary:
	var rows: Dictionary = table().get("roles", {})
	var out := DEFAULT_ROW.duplicate()
	var found: Variant = rows.get(String(role), null)
	if found is Dictionary:
		out.merge(found, true)
	return out


## The prop type a kind is built as until its own art lands: "safe" reads
## as a locker, "generator" as a cryopod, "cabinet" as a console and
## "footlocker" as a crate-sized Container. A kind with no placeholder is
## its own type.
static func placeholder(kind: StringName) -> StringName:
	var map: Dictionary = table().get("placeholders", {})
	return StringName(map.get(String(kind), String(kind)))


## The light tint of a Role's Room.
static func light(role: StringName) -> Color:
	var rgb: Array = row(role).light
	return Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))


## A Role's console count, rolled inside its range.
static func console_count(role: StringName, rng: RandomNumberGenerator) -> int:
	var range_: Array = row(role).consoles
	return rng.randi_range(int(range_[0]), int(range_[1]))
