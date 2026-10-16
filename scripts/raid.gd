class_name Raid
extends RefCounted
## The Raid being played: which Ship Class the pirate picked and the seed of
## the target rolled for it. Static, so it outlives the scene change from the
## main menu into the ship and back, and a retry boards the very same ship
## with every crew member back at their post.

const MENU_SCENE := "res://scenes/main_menu.tscn"
const RAID_SCENE := "res://scenes/main_3d.tscn"
## Seeds are rolled in this range so one fits in a bug report.
const SEED_MAX := 999_999_999

static var ship_class: StringName = &""
## Zero while no Raid is on: the ship scene then falls back to its own source.
static var seed := 0


## Rolls a fresh target of this Class and boards it.
static func start(chosen_class: StringName) -> void:
	assert(chosen_class in ShipGenerator.CLASSES, "unknown ship class %s" % chosen_class)
	ship_class = chosen_class
	seed = randi_range(1, SEED_MAX)
	_tree().change_scene_to_file(RAID_SCENE)


## Boards the same target again, rebuilt from its seed.
static func retry() -> void:
	_tree().change_scene_to_file(RAID_SCENE)


## A fresh target of the same Class, after getting out of the last one.
## Medium when no Raid was on (the ship scene was launched on its own).
static func new_raid() -> void:
	start(ship_class if ship_class in ShipGenerator.CLASSES else &"medium")


## Abandons the Raid and goes back to pick another.
static func to_menu() -> void:
	ship_class = &""
	seed = 0
	_tree().change_scene_to_file(MENU_SCENE)


static func is_active() -> bool:
	return seed > 0


## The target this Raid boards, or null when no Raid is on.
static func layout() -> ShipLayout:
	if not is_active():
		return null
	return ShipGenerator.generate(ship_class, seed)


## Whatever scene comes next starts running, whether or not the one it
## replaces was paused.
static func _tree() -> SceneTree:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	return tree
