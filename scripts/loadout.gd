class_name Loadout
extends RefCounted
## What the pirate takes into a Raid: a first and a second weapon, never the
## same one twice, and for each of the four weapons the Attachment in each of
## its Slots. Attachments belong to the weapon, so one not carried keeps its
## own. Kept in the profile file beside XP and gold ([member Profile.path]):
##
##   [loadout]
##   first="shotgun"
##   second="marksman_rifle"
##   [loadout_marksman_rifle]
##   barrel="suppressor"
##
## Weapons and Attachments are named by their file under
## `resources/weapons/` and `resources/attachments/`; a Slot by its name in
## lower case. Loading drops anything stale quietly: an unknown Attachment,
## or one the gun does not take, leaves its Slot empty; an unknown weapon, or
## the same weapon in both places, gives the default.

const WEAPONS: Array[WeaponProfile] = [
	preload("res://resources/weapons/pistol.tres"),
	preload("res://resources/weapons/assault_rifle.tres"),
	preload("res://resources/weapons/shotgun.tres"),
	preload("res://resources/weapons/marksman_rifle.tres"),
]
const ATTACHMENT_DIR := "res://resources/attachments/"
const SECTION := "loadout"
## Each weapon's Slots go in a section of their own: this, then its name.
const WEAPON_SECTION := "loadout_"

var _first: WeaponProfile = WEAPONS[0]
var _second: WeaponProfile = WEAPONS[1]
## Weapon to {Slot: Attachment}, only Slots with something fitted.
var _fitted := {}


## The four weapons a Loadout picks from, in wheel order.
static func all_weapons() -> Array[WeaponProfile]:
	return WEAPONS.duplicate()


## How the profile file names [param weapon]: its file's name.
static func weapon_name(weapon: WeaponProfile) -> String:
	return "" if weapon == null else weapon.resource_path.get_file().get_basename()


static func _weapon_named(weapon: String) -> WeaponProfile:
	for candidate in WEAPONS:
		if weapon_name(candidate) == weapon:
			return candidate
	return null


static func _attachment_named(attachment: String) -> Attachment:
	if not attachment.is_valid_identifier():
		return null
	var path := ATTACHMENT_DIR + attachment + ".tres"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Attachment


func get_first() -> WeaponProfile:
	return _first


func get_second() -> WeaponProfile:
	return _second


## Carries [param weapon] first. The gun already second swaps places with
## it; anything not one of the four is refused.
func set_first(weapon: WeaponProfile) -> void:
	if not weapon in WEAPONS:
		return
	if weapon == _second:
		_second = _first
	_first = weapon


## Carries [param weapon] second, as [method set_first] does first.
func set_second(weapon: WeaponProfile) -> void:
	if not weapon in WEAPONS:
		return
	if weapon == _first:
		_first = _second
	_second = weapon


## What is fitted in [param weapon]'s [param slot]; null when it is empty.
func get_attachment(weapon: WeaponProfile, slot: Attachment.Slot) -> Attachment:
	return _fitted.get(weapon, {}).get(slot)


## Fits [param attachment] in [param weapon]'s [param slot], or empties the
## Slot with null. False, changing nothing, when the weapon cannot be built
## with it there.
func set_attachment(weapon: WeaponProfile, slot: Attachment.Slot, attachment: Attachment) -> bool:
	if not weapon in WEAPONS:
		return false
	if attachment == null:
		_fitted.get(weapon, {}).erase(slot)
		return true
	if weapon.why_refused({slot: attachment}) != "":
		return false
	if not _fitted.has(weapon):
		_fitted[weapon] = {}
	_fitted[weapon][slot] = attachment
	return true


## [param weapon]'s fitted Slots as [method WeaponProfile.build] takes them.
func choice(weapon: WeaponProfile) -> Dictionary:
	return _fitted.get(weapon, {}).duplicate()


## The two Built Weapons, first then second.
func build_weapons() -> Array[WeaponProfile]:
	var built: Array[WeaponProfile] = []
	for weapon in [_first, _second]:
		var profile := weapon.build(choice(weapon)) as WeaponProfile
		built.append(profile if profile != null else weapon.build({}) as WeaponProfile)
	return built


## Writes this Loadout into the profile file, keeping what else is in it.
func save() -> void:
	var file := ConfigFile.new()
	file.load(Profile.path)
	for section in file.get_sections():
		if section == SECTION or section.begins_with(WEAPON_SECTION):
			file.erase_section(section)
	file.set_value(SECTION, "first", weapon_name(_first))
	file.set_value(SECTION, "second", weapon_name(_second))
	for weapon in WEAPONS:
		for slot: Attachment.Slot in _fitted.get(weapon, {}):
			file.set_value(WEAPON_SECTION + weapon_name(weapon), _slot_key(slot),
					_fitted[weapon][slot].resource_path.get_file().get_basename())
	file.save(Profile.path)


## The saved Loadout, with anything stale dropped; the default when none is saved.
static func load_saved() -> Loadout:
	var loadout := Loadout.new()
	var file := ConfigFile.new()
	if file.load(Profile.path) != OK:
		return loadout
	var first := _weapon_named(str(file.get_value(SECTION, "first", "")))
	var second := _weapon_named(str(file.get_value(SECTION, "second", "")))
	if first == null:
		first = WEAPONS[0]
	if second == null:
		second = WEAPONS[1]
	if first != second:
		loadout._first = first
		loadout._second = second
	for weapon in WEAPONS:
		var section := WEAPON_SECTION + weapon_name(weapon)
		if not file.has_section(section):
			continue
		for slot: Attachment.Slot in Attachment.Slot.values():
			var attachment := _attachment_named(str(file.get_value(section, _slot_key(slot), "")))
			if attachment != null:
				loadout.set_attachment(weapon, slot, attachment)
	return loadout


static func _slot_key(slot: Attachment.Slot) -> String:
	return String(Attachment.Slot.find_key(slot)).to_lower()
