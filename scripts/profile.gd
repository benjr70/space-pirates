class_name Profile
extends RefCounted
## What the pirate keeps between Raids, saved to disk: the XP he has earned
## and the gold he has banked. XP is kept whichever way a Raid ends; gold is
## banked only by extracting with it.

## Where the profile is saved. Tests point it somewhere throwaway.
static var path := "user://profile.cfg"
## XP from one level to the next grows by this much each level.
const XP_STEP := 500

static var xp := 0
static var gold := 0
static var _loaded_from := ""


static func load_saved() -> void:
	xp = 0
	gold = 0
	var file := ConfigFile.new()
	if file.load(path) == OK:
		xp = int(file.get_value("pirate", "xp", 0))
		gold = int(file.get_value("pirate", "gold", 0))
	_loaded_from = path


static func save() -> void:
	var file := ConfigFile.new()
	file.set_value("pirate", "xp", xp)
	file.set_value("pirate", "gold", gold)
	file.save(path)


## Adds what one Raid earned and saves at once, so it survives a crash.
static func bank(earned_xp: int, earned_gold: int) -> void:
	_ensure_loaded()
	xp += earned_xp
	gold += earned_gold
	save()


## Level 1 at 0 XP; level n+1 takes [constant XP_STEP] * n more than level n.
static func level_for(total: int) -> int:
	return _walk(total).x


## XP gained into the current level, and what the whole level takes.
static func level_progress(total: int) -> Vector2i:
	var walk := _walk(total)
	return Vector2i(walk.y, walk.z)


## Level, XP into it, and XP the level takes.
static func _walk(total: int) -> Vector3i:
	var level := 1
	var need := XP_STEP
	while total >= need:
		total -= need
		level += 1
		need = XP_STEP * level
	return Vector3i(level, total, need)


static func level() -> int:
	_ensure_loaded()
	return level_for(xp)


static func _ensure_loaded() -> void:
	if _loaded_from != path:
		load_saved()
