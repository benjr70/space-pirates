extends Node
## PROTOTYPE, throwaway -- what aim time and swap time feel like on each gun
## (.scratch/weapon-attachments/issues/12-aim-time-and-swap-time.md).
##
##   flatpak run org.godotengine.Godot --path . res://scenes/proto_aim_swap_time.tscn \
##       -- --seed=7 --class=large
##
## A real Raid carrying a Loadout of two guns. Each gun has its own aim time
## (seconds for the sights to come up) and swap time, where today every gun
## raises its sights at one speed and swaps in 0.4 s.
##
##   [ ]       aim time of the gun in hand, shorter / longer
##   - =       swap time of the gun in hand, shorter / longer
##   F5        what aiming gives while the sights are still rising:
##             at once (today) / with the rise / only once they are up
##   F6        whose swap time a swap takes: the gun drawn / the gun put away /
##             half of each
##   F7        sights back after a Descope: the full aim time / half of it
##   F8        next Loadout (which two guns)
##   F9        today's feel, on/off: one speed for every gun, 0.4 s swap
##   F2        cannot die, on/off (starts on)
##
## The bar under the crosshair fills as the sights rise.

const NAMES := {"pistol": "Pistol", "assault_rifle": "Assault Rifle", "shotgun": "Shotgun", "marksman_rifle": "Marksman Rifle"}
const LOADOUTS := [["pistol", "assault_rifle"], ["pistol", "shotgun"], ["pistol", "marksman_rifle"],
	["assault_rifle", "shotgun"], ["assault_rifle", "marksman_rifle"], ["shotgun", "marksman_rifle"]]
const GIVES := ["at once (today)", "with the rise", "only once up"]
const WHOSE := ["the gun drawn", "the gun put away", "half of each"]
## Today: the pose settles at 10 a second and the zoom at 14, about 0.25 s.
const TODAY_POSE := 10.0
const TODAY_ZOOM := 14.0
const TODAY_SWAP := 0.4

var _player: Node
var _view: Node
var _stock := {}
var _profiles := {}
var _aim := {"pistol": 0.15, "assault_rifle": 0.22, "shotgun": 0.22, "marksman_rifle": 0.32}
var _swap := {"pistol": 0.30, "assault_rifle": 0.40, "shotgun": 0.45, "marksman_rifle": 0.50}
var _loadout := 0
var _gives := 1
var _whose := 0
var _descope_half := false
var _today := false
var _immortal := true
var _progress := 0.0
var _after_descope := false
var _label: Label
var _bar: ColorRect


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_player = get_parent().player
	_view = _player.viewmodel
	for file: String in NAMES:
		_stock[file] = load("res://resources/weapons/%s.tres" % file)
		_profiles[file] = (_stock[file] as WeaponProfile).duplicate()
	_player.descoped.connect(func() -> void: _after_descope = true)
	_carry()

	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(24, 110)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_label)
	var track := ColorRect.new()
	track.color = Color(0, 0, 0, 0.5)
	track.set_anchors_preset(Control.PRESET_CENTER)
	track.position = Vector2(-60, 60)
	track.size = Vector2(120, 6)
	layer.add_child(track)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.62, 0.2)
	_bar.size = Vector2(0, 6)
	track.add_child(_bar)
	if "--selftest" in OS.get_cmdline_user_args():
		_selftest()


func _carry() -> void:
	var pair: Array = LOADOUTS[_loadout]
	var guns: Array[WeaponProfile] = [_profiles[pair[0]], _profiles[pair[1]]]
	_player.weapons = guns
	_player.swap_time = 0.0
	_player.weapon = guns[0]
	_view._mount(guns[0])
	_player.ammo = guns[0].magazine_size
	_player.ammo_changed.emit(_player.ammo)


func _in_hand() -> String:
	for file: String in _profiles:
		if _profiles[file] == _player.weapon:
			return file
	return "pistol"


func _other() -> String:
	var pair: Array = LOADOUTS[_loadout]
	return pair[1] if pair[0] == _in_hand() else pair[0]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) or _label == null:
		return
	var gun := _in_hand()
	match event.physical_keycode:
		KEY_BRACKETLEFT: _aim[gun] = maxf(_aim[gun] - 0.02, 0.04)
		KEY_BRACKETRIGHT: _aim[gun] = minf(_aim[gun] + 0.02, 1.0)
		KEY_MINUS: _swap[gun] = maxf(_swap[gun] - 0.05, 0.05)
		KEY_EQUAL: _swap[gun] = minf(_swap[gun] + 0.05, 1.5)
		KEY_F5: _gives = (_gives + 1) % GIVES.size()
		KEY_F6: _whose = (_whose + 1) % WHOSE.size()
		KEY_F7: _descope_half = not _descope_half
		KEY_F8:
			_loadout = (_loadout + 1) % LOADOUTS.size()
			_carry()
		KEY_F9: _today = not _today
		KEY_F2: _immortal = not _immortal
		_: return
	print("[aim and swap time] ", _state_line())


func _state_line() -> String:
	var guns := PackedStringArray()
	for file: String in NAMES:
		guns.append("%s aim %.2f s swap %.2f s" % [NAMES[file], _aim[file], _swap[file]])
	return "%s | aiming gives: %s | a swap takes: %s | after a Descope: %s aim time%s" % [
		", ".join(guns), GIVES[_gives], WHOSE[_whose], "half the" if _descope_half else "the full",
		" | TODAY'S FEEL ON" if _today else ""]


func _process(delta: float) -> void:
	if _label == null:
		return
	if _immortal and _player.health.is_alive():
		_player.health.current = _player.health.max_health
		get_parent().hud.set_health(_player.health.current)
	var gun := _in_hand()
	var profile: WeaponProfile = _profiles[gun]
	var stock: WeaponProfile = _stock[gun]

	if _today:
		_view.pose_lerp = TODAY_POSE
		_player.ads_zoom_speed = TODAY_ZOOM
		_player.swap_time = TODAY_SWAP
		profile.ads_spread = stock.ads_spread
		profile.ads_moving_spread = stock.ads_moving_spread
		profile.ads_speed = stock.ads_speed
		_progress = 1.0 if _player.ads else 0.0
	else:
		var rise: float = _aim[gun] * (0.5 if _after_descope and _descope_half else 1.0)
		_progress = move_toward(_progress, 1.0 if _player.ads else 0.0, delta / maxf(rise, 0.01))
		if _progress >= 1.0 or not _player.ads and _progress <= 0.0:
			_after_descope = false
		# The pose and the zoom ease in; make them all but there in `rise`.
		_view.pose_lerp = 3.0 / maxf(rise, 0.01)
		_player.ads_zoom_speed = 3.0 / maxf(rise, 0.01)
		var given := 1.0
		match _gives:
			1: given = _progress
			2: given = 1.0 if _progress >= 1.0 else 0.0
		profile.ads_spread = lerpf(1.0, stock.ads_spread, given)
		profile.ads_moving_spread = lerpf(stock.spread_walking, stock.ads_moving_spread, given)
		profile.ads_speed = lerpf(1.0, stock.ads_speed, given)
		# With two guns the next one is always the other.
		match _whose:
			0: _player.swap_time = _swap[_other()]
			1: _player.swap_time = _swap[gun]
			2: _player.swap_time = (_swap[gun] + _swap[_other()]) * 0.5

	_bar.size.x = 120.0 * _progress
	_label.text = "AIM AND SWAP TIME PROTOTYPE\nin hand: %s   other: %s\n%s\n\n[ ] aim time   - = swap time (gun in hand)   F5 aiming gives   F6 swap takes   F7 Descope   F8 Loadout   F9 today's feel   F2 cannot die: %s" % [
		NAMES[gun], NAMES[_other()], _state_line().replace(" | ", "\n").replace(", ", "\n"), "on" if _immortal else "off"]


func _selftest() -> void:
	for i in LOADOUTS.size():
		_loadout = i
		_carry()
		for f in 3:
			await get_tree().process_frame
		print("[selftest] carrying %s and %s, swap %.2f, pose speed %.1f" % [NAMES[_in_hand()], NAMES[_other()],
			_player.swap_time, _view.pose_lerp])
	_player.switch_weapon(1)
	await get_tree().create_timer(0.7).timeout
	print("[selftest] swapped to ", NAMES[_in_hand()])
	get_tree().quit()
