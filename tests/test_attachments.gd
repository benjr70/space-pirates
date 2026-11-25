extends SceneTree
## Headless checks on Attachments as data and the Built Weapon: every
## Attachment a gun takes changes exactly the attributes the catalogue says,
## by its factor, with the limits applied; the Built Weapon numbers tabled in
## `.scratch/weapon-attachments/issues/13-starting-numbers.md`; stacking;
## building leaves the bare Profile and the Attachment files alone; and a
## gun refuses what it does not take and any change to what kind of gun it is.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_attachments.gd

const WEAPONS := "res://resources/weapons/%s.tres"
const ATTACHMENTS := "res://resources/attachments/%s.tres"
const SUPPRESSED := "res://assets/audio/suppressed_shots/%s_suppressed.ogg"

## The catalogue's factors, copied by hand from the spec's "Slots and the
## catalogue" table: the independent truth the data files are checked against.
const FACTORS := {
	"reflex_sight": {"aim_time": 0.80, "ads_speed": 1.10, "ads_zoom": 0.85},
	"combat_scope": {"ads_zoom": 1.55, "ads_spread": 0.75, "aim_time": 1.30, "ads_speed": 0.85},
	"long_scope": {"ads_zoom": 1.67, "aim_time": 1.35, "ads_sway_degrees": 1.5},
	"suppressor": {"loudness": 0.4, "projectile_speed": 0.80},
	"long_barrel": {"projectile_speed": 1.25, "spread_base_degrees": 0.85, "aim_time": 1.20, "swap_time": 1.20},
	"short_barrel": {"aim_time": 0.80, "swap_time": 0.80, "spread_base_degrees": 1.25, "projectile_speed": 0.85},
	"extended_magazine": {"magazine_size": 1.5, "reload_tactical": 1.25, "reload_empty": 1.25},
	"quick_magazine": {"reload_tactical": 0.70, "reload_empty": 0.70, "magazine_size": 0.8},
	"drum": {"magazine_size": 2.5, "reload_tactical": 1.60, "reload_empty": 1.60, "aim_time": 1.25, "swap_time": 1.30},
	"foregrip": {"recoil_kick_degrees": 0.70, "ads_recoil_kick_degrees": 0.70, "camera_kick_degrees": 0.70, "aim_time": 1.15},
	"laser": {"spread_base_degrees": 0.70, "ads_spread": 1.0 / 0.70, "ads_moving_spread": 1.0 / 0.70, "conspicuous": 1.3},
	"bipod": {"spread_crouch": 0.5, "ads_sway_degrees": 0.5, "aim_time": 1.20, "swap_time": 1.20},
	"heavy_stock": {"ads_sway_degrees": 0.6, "ads_moving_spread": 0.8, "aim_time": 1.20, "ads_speed": 0.85},
	"light_stock": {"aim_time": 0.80, "swap_time": 0.80, "ads_speed": 1.15, "ads_sway_degrees": 1.3, "recoil_kick_degrees": 1.25},
}
## Each Attachment's Slot and display name, from the same table.
const SLOTS := {
	"reflex_sight": [Attachment.Slot.SIGHT, "Reflex Sight"],
	"combat_scope": [Attachment.Slot.SIGHT, "Combat Scope"],
	"long_scope": [Attachment.Slot.SIGHT, "Long Scope"],
	"suppressor": [Attachment.Slot.BARREL, "Suppressor"],
	"long_barrel": [Attachment.Slot.BARREL, "Long Barrel"],
	"short_barrel": [Attachment.Slot.BARREL, "Short Barrel"],
	"extended_magazine": [Attachment.Slot.MAGAZINE, "Extended Magazine"],
	"quick_magazine": [Attachment.Slot.MAGAZINE, "Quick Magazine"],
	"drum": [Attachment.Slot.MAGAZINE, "Drum"],
	"foregrip": [Attachment.Slot.UNDERBARREL, "Foregrip"],
	"laser": [Attachment.Slot.UNDERBARREL, "Laser"],
	"bipod": [Attachment.Slot.UNDERBARREL, "Bipod"],
	"heavy_stock": [Attachment.Slot.STOCK, "Heavy Stock"],
	"light_stock": [Attachment.Slot.STOCK, "Light Stock"],
}
## The spec's fit table: which Attachments each gun takes.
const FITS := {
	"pistol": ["reflex_sight", "suppressor", "extended_magazine", "quick_magazine", "laser"],
	"assault_rifle": ["reflex_sight", "combat_scope", "suppressor", "long_barrel", "short_barrel",
			"extended_magazine", "quick_magazine", "drum", "foregrip", "laser", "bipod", "heavy_stock", "light_stock"],
	"shotgun": ["reflex_sight", "long_barrel", "short_barrel", "foregrip", "laser", "heavy_stock", "light_stock"],
	"marksman_rifle": ["long_scope", "suppressor", "long_barrel", "extended_magazine", "quick_magazine",
			"foregrip", "bipod", "heavy_stock", "light_stock"],
}
## What an Attachment may never change.
const FORBIDDEN := ["damage", "headshot_multiplier", "pellet_count", "semi_auto", "shell_reload"]

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	_check_catalogue()
	_check_slots_and_fits()
	_check_every_pair()
	_check_starting_numbers()
	_check_stacking()
	_check_shot_sounds()
	_check_untouched()
	_check_refusals()
	_report()
	quit(1 if failures.size() > 0 else 0)


func _gun(gun: String) -> WeaponProfile:
	return load(WEAPONS % gun)


func _part(part: String) -> Attachment:
	return load(ATTACHMENTS % part)


## The gun built with these Attachments, each in its own Slot.
func _built(gun: String, parts: Array) -> WeaponProfile:
	var choice := {}
	for part: String in parts:
		var attachment := _part(part)
		choice[attachment.slot] = attachment
	return _gun(gun).build(choice)


## Fourteen files, each in its Slot under its name, changing exactly the
## catalogue's attributes by its factors.
func _check_catalogue() -> void:
	var dir := DirAccess.get_files_at("res://resources/attachments/")
	var files := Array(dir).filter(func(f: String) -> bool: return f.ends_with(".tres"))
	_expect(files.size() == 14, "%d Attachment files, want 14" % files.size())
	for part: String in FACTORS:
		var attachment := _part(part)
		_expect(attachment != null, "no Attachment file %s" % part)
		if attachment == null:
			continue
		_expect(attachment.slot == SLOTS[part][0], "%s is in Slot %d" % [part, attachment.slot])
		_expect(attachment.display_name == SLOTS[part][1], "%s is named \"%s\"" % [part, attachment.display_name])
		var want: Dictionary = FACTORS[part]
		_expect(attachment.changes.size() == want.size(), "%s has %d changes, want %d" % [part, attachment.changes.size(), want.size()])
		for key: String in want:
			var factor: float = attachment.changes.get(StringName(key), attachment.changes.get(key, NAN))
			_expect(absf(factor - want[key]) <= 0.0001, "%s: %s x%s, want x%s" % [part, key, factor, want[key]])
		_expect(attachment.lens == (part in ["combat_scope", "long_scope"]), "%s: lens is %s" % [part, attachment.lens])
		_expect(attachment.suppresses == (part == "suppressor"), "%s: suppresses is %s" % [part, attachment.suppresses])


## Each gun's Slots and what fits them are the spec's fit table, and every
## bare gun is conspicuous 1.0.
func _check_slots_and_fits() -> void:
	var slot_counts := {"pistol": 4, "assault_rifle": 5, "shotgun": 4, "marksman_rifle": 5}
	for gun: String in FITS:
		var profile := _gun(gun)
		_expect(is_equal_approx(profile.conspicuous, 1.0), "%s is conspicuous %s, not 1.0" % [gun, profile.conspicuous])
		_expect(profile.slots().size() == slot_counts[gun], "%s has %d Slots, want %d" % [gun, profile.slots().size(), slot_counts[gun]])
		var taken := []
		for slot in profile.slots():
			for attachment in profile.fits_in(slot):
				_expect(attachment.slot == slot, "%s lists %s under the wrong Slot" % [gun, attachment.display_name])
				taken.append(attachment.resource_path.get_file().get_basename())
		taken.sort()
		var want: Array = FITS[gun].duplicate()
		want.sort()
		_expect(taken == want, "%s takes %s, want %s" % [gun, taken, want])
	_expect(not _gun("pistol").slots().has(Attachment.Slot.STOCK), "the Pistol has a Stock Slot")
	_expect(not _gun("shotgun").slots().has(Attachment.Slot.MAGAZINE), "the Shotgun has a Magazine Slot")


## For every gun and every Attachment it takes (34 pairs), each changed
## attribute is bare times factor (counts exactly, the rest within 1%, after
## the limits) and nothing else moves.
func _check_every_pair() -> void:
	var pairs := 0
	for gun: String in FITS:
		var bare := _gun(gun)
		for part: String in FITS[gun]:
			var built := _built(gun, [part])
			_expect(built != null, "%s refused %s" % [gun, part])
			if built == null:
				continue
			pairs += 1
			var want: Dictionary = FACTORS[part]
			for p in _numbers(bare):
				var before: Variant = bare.get(p)
				var after: Variant = built.get(p)
				if not want.has(String(p)):
					_expect(after == before, "%s + %s changed %s from %s to %s" % [gun, part, p, before, after])
					continue
				var raw: float = before * want[String(p)]
				if typeof(before) == TYPE_INT:
					var rounds := maxi(roundi(raw), 1)
					_expect(after == rounds, "%s + %s: %s is %s, want %d" % [gun, part, p, after, rounds])
				else:
					var expected := maxf(raw, 1.0) if p == &"ads_zoom" else raw
					_expect(_within(after, expected, 0.01), "%s + %s: %s is %s, want %s within 1%%" % [gun, part, p, after, expected])
	_expect(pairs == 34, "%d gun and Attachment pairs built, want 34" % pairs)


## The Built Weapon numbers tabled in `issues/13-starting-numbers.md`.
func _check_starting_numbers() -> void:
	var drum := _built("assault_rifle", ["drum"])
	_expect(drum.magazine_size == 75, "Assault Rifle with Drum has %d rounds, want 75" % drum.magazine_size)
	_expect(_within(drum.reload_tactical, 2.88, 0.01), "Assault Rifle with Drum reloads in %.3f s, want 2.88" % drum.reload_tactical)
	var pistol_quick := _built("pistol", ["quick_magazine"])
	_expect(pistol_quick.magazine_size == 10, "Pistol with Quick Magazine has %d rounds, want 10" % pistol_quick.magazine_size)
	var marksman_quick := _built("marksman_rifle", ["quick_magazine"])
	_expect(marksman_quick.magazine_size == 6, "Marksman Rifle with Quick Magazine has %d rounds, want 6" % marksman_quick.magazine_size)
	for gun in ["pistol", "assault_rifle", "marksman_rifle"]:
		var quiet := _built(gun, ["suppressor"])
		_expect(_within(quiet.loudness, 9.6, 0.01), "suppressed %s is heard at %.2f m, want 9.6" % [gun, quiet.loudness])
	var shotgun_reflex := _built("shotgun", ["reflex_sight"])
	_expect(shotgun_reflex.ads_zoom == 1.0, "Shotgun with Reflex Sight has zoom %s, want 1.0" % shotgun_reflex.ads_zoom)
	_expect(not shotgun_reflex.aims_through_lens, "the Reflex Sight marks the Shotgun as a lens")
	var long_scope := _built("marksman_rifle", ["long_scope"])
	_expect(_within(long_scope.ads_zoom, 5.01, 0.01), "Marksman Rifle with Long Scope has zoom %.3f, want 5.01" % long_scope.ads_zoom)
	_expect(long_scope.aims_through_lens, "the Long Scope does not mark the Marksman Rifle as a lens")
	_expect(not _gun("marksman_rifle").aims_through_lens, "the bare Marksman Rifle is marked as a lens")
	_expect(long_scope.attachments.size() == 1 and long_scope.attachments[0] == _part("long_scope"),
			"the Built Weapon does not carry its Long Scope")


## Two Attachments on one attribute multiply.
func _check_stacking() -> void:
	var built := _built("assault_rifle", ["combat_scope", "long_barrel", "drum", "foregrip", "heavy_stock"])
	_expect(absf(built.aim_time - 0.59) <= 0.01, "the slowest Assault Rifle aims in %.3f s, want 0.59 within 0.01" % built.aim_time)
	var light := _built("marksman_rifle", ["bipod", "heavy_stock"])
	_expect(_within(light.ads_sway_degrees, 0.075, 0.01), "Marksman Rifle with Bipod and Heavy Stock sways %.4f, want 0.075" % light.ads_sway_degrees)


## The Suppressor plays each gun's own suppressed take; anything else keeps
## the gun's shot.
func _check_shot_sounds() -> void:
	for gun in ["pistol", "assault_rifle", "marksman_rifle"]:
		var quiet := _built(gun, ["suppressor"])
		var take: AudioStream = load(SUPPRESSED % gun)
		_expect(take != null, "no suppressed take for %s" % gun)
		_expect(quiet.shot_sounds == [take], "suppressed %s plays %s" % [gun, quiet.shot_sounds])
	var loud := _built("assault_rifle", ["long_barrel"])
	_expect(loud.shot_sounds == _gun("assault_rifle").shot_sounds, "the Long Barrel changed the Assault Rifle's shot")


## Building never changes the bare Profile or an Attachment file, and the
## Built Weapon is a fresh Profile.
func _check_untouched() -> void:
	var before := {}
	for gun: String in FITS:
		before[gun] = _snapshot(_gun(gun))
	var parts_before := {}
	for part: String in FACTORS:
		parts_before[part] = _part(part).changes.duplicate()
	var all_ar := _built("assault_rifle", ["combat_scope", "suppressor", "drum", "laser", "light_stock"])
	_expect(all_ar != _gun("assault_rifle"), "the Built Weapon is the bare Profile itself")
	for gun: String in FITS:
		for part: String in FITS[gun]:
			_built(gun, [part])
	for gun: String in FITS:
		_expect(_snapshot(_gun(gun)) == before[gun], "building changed the bare %s" % gun)
		var disk: WeaponProfile = ResourceLoader.load(WEAPONS % gun, "", ResourceLoader.CACHE_MODE_IGNORE)
		_expect(_snapshot(disk) == before[gun], "the bare %s in memory is not the one on disk" % gun)
	for part: String in FACTORS:
		_expect(_part(part).changes == parts_before[part], "building changed the %s" % part)


## A gun refuses an Attachment it does not take, one in the wrong Slot, and
## any Attachment that changes what kind of gun it is.
func _check_refusals() -> void:
	var pistol := _gun("pistol")
	_expect(pistol.build({Attachment.Slot.SIGHT: _part("combat_scope")}) == null, "the Pistol took a Combat Scope")
	_expect(_gun("shotgun").build({Attachment.Slot.BARREL: _part("suppressor")}) == null, "the Shotgun took a Suppressor")
	_expect(pistol.build({Attachment.Slot.BARREL: _part("reflex_sight")}) == null, "the Pistol took a Reflex Sight in its Barrel Slot")
	_expect(pistol.build({}) != null, "the Pistol refused to build bare")
	_expect(pistol.build({Attachment.Slot.SIGHT: null}) != null, "the Pistol refused an empty Sight Slot")
	for key: String in FORBIDDEN:
		var rogue: Attachment = _part("laser").duplicate()
		rogue.changes = {StringName(key): 2.0}
		# Fitted to the Pistol in a scratch copy, so only the change is wrong.
		var scratch: WeaponProfile = pistol.duplicate()
		scratch.fits = [rogue]
		_expect(scratch.build({Attachment.Slot.UNDERBARREL: rogue}) == null, "an Attachment that changes %s was not refused" % key)
		_expect(scratch.why_refused({Attachment.Slot.UNDERBARREL: rogue}).contains(key), "the refusal of %s does not name it" % key)


## Every exported bool, int and float on a Profile.
func _numbers(profile: WeaponProfile) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in profile.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR \
				and p.type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT]:
			out.append(StringName(p.name))
	return out


func _snapshot(profile: WeaponProfile) -> Dictionary:
	var out := {}
	for p: Dictionary in profile.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = profile.get(p.name)
			out[p.name] = value.duplicate() if value is Array or value is Dictionary else value
	return out


func _within(value: float, want: float, fraction: float) -> bool:
	return absf(value - want) <= absf(want) * fraction


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
