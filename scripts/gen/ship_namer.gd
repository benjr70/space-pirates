class_name ShipNamer
extends RefCounted
## Stage 9 of the generator: a ship's name from its seed, in the shape
## `[prefix ]name`. A registry prefix on some ships (the formal half of the
## register); a name that is an epithet of two words ("Rusty Hauler"), a
## proper noun ("Kestrel") or a place and a thing ("Vesta Tide", "Orrin's
## Hand"), the scrappy half. Every word list, weight and chance lives in
## `res://data/ship_names.json` so writing passes never touch this code.
##
## The name hints softly at archetype and Class through a few extra
## epithet words each contributes, never at Roles: reading the silhouette
## for an Armory is the skill the pre-raid rule rewards. Collisions between
## seeds are accepted; "The" is never stored ([method ShipLayout.display_name]
## prepends it to unprefixed names).

const PATH := "res://data/ship_names.json"
## The three shapes in a fixed order, so a reordered data file never
## reshuffles every ship's name.
const SHAPES: Array[String] = ["epithet", "proper", "place"]

static var _table: Dictionary = {}


## The word lists, loaded on first use.
static func table() -> Dictionary:
	if _table.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		if parsed is Dictionary:
			_table = parsed
		else:
			push_error("ShipNamer: cannot read %s; every ship is Nameless" % PATH)
			_table = {prefixes = []}
	return _table


## The registry prefixes a name may carry: a prefixed ship is not "The"
## anything.
static func prefixes() -> Array:
	return table().get("prefixes", [])


## The name for a ship: {name, prefix, shape}. Rolled on its own RNG from
## the Class and seed, so it does not move when an earlier stage rolls
## differently. [param archetype] is the Hull's, for its epithet words.
static func roll(ship_class: StringName, seed: int, archetype: StringName) -> Dictionary:
	var t := table()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("name#%s#%d" % [ship_class, seed])
	var prefix := ""
	if not prefixes().is_empty() and rng.randf() < float(t.get("prefix_chance", 0.0)):
		prefix = _pick(prefixes(), rng)
	var shape := _roll_shape(t.get("shapes", {}), rng)
	var name: String
	match shape:
		"epithet":
			name = _epithet(t, ship_class, archetype, rng)
		"place":
			name = _place(t.get("place", {}), rng)
		_:
			name = _pick(t.get("proper", []), rng)
	return {name = (prefix + " " + name) if prefix != "" else name, prefix = prefix, shape = shape}


## The name alone, for the generator.
static func name_for(ship_class: StringName, seed: int, archetype: StringName) -> String:
	return roll(ship_class, seed, archetype).name


## One of [constant SHAPES] by the table's weights; a proper noun when the
## table names none.
static func _roll_shape(shapes: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for shape in SHAPES:
		total += float(shapes.get(shape, 0.0))
	if total <= 0.0:
		return "proper"
	var r := rng.randf() * total
	for shape in SHAPES:
		r -= float(shapes.get(shape, 0.0))
		if r < 0.0:
			return shape
	return SHAPES[-1]


## Adjective and noun from the shared pools plus the archetype's and the
## Class's few words, so those hint without ever dominating.
static func _epithet(t: Dictionary, ship_class: StringName, archetype: StringName, rng: RandomNumberGenerator) -> String:
	var shared: Dictionary = t.get("epithet", {})
	var adjectives: Array = (shared.get("adjectives", []) as Array).duplicate()
	var nouns: Array = (shared.get("nouns", []) as Array).duplicate()
	for extra: Dictionary in [hint_words(t.get("archetypes", {}), archetype), hint_words(t.get("classes", {}), ship_class)]:
		adjectives.append_array(extra.get("adjectives", []))
		nouns.append_array(extra.get("nouns", []))
	return "%s %s" % [_pick(adjectives, rng), _pick(nouns, rng)]


## The few epithet words an archetype or a Class contributes, from its
## entry of [param pool]: {adjectives: [...], nouns: [...]}.
static func hint_words(pool: Dictionary, key: StringName) -> Dictionary:
	return pool.get(String(key), {})


## A place and a thing, sometimes possessive: "Vesta Tide", "Orrin's Hand".
static func _place(place: Dictionary, rng: RandomNumberGenerator) -> String:
	var where := _pick(place.get("places", ["Nowhere"]), rng)
	var what := _pick(place.get("things", ["Thing"]), rng)
	if rng.randf() < float(place.get("possessive_chance", 0.0)):
		return "%s's %s" % [where, what]
	return "%s %s" % [where, what]


static func _pick(words: Array, rng: RandomNumberGenerator) -> String:
	if words.is_empty():
		return "Nameless"
	return String(words[rng.randi_range(0, words.size() - 1)])
