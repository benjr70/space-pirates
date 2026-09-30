class_name Hud
extends CanvasLayer
## First-person HUD: ship name, crosshair, health pips, ammo counter,
## interact prompt and a damage vignette. Built in code so it stays one file.
##
## The crosshair's four lines open and close with the Pirate's live spread,
## and collapse to a dot while he Aims Down Sights. A landed hit flashes an
## X of four short diagonals around it, red when it killed, fading in a
## quarter second; the playtest wanted to know when a shot landed. The ammo
## counter reads `n / ∞` and turns red at zero, and a dry pull rings
## `dry_click` once for whatever plays the sound.

## Something wants to make the empty click: a dry pull, once each.
signal dry_click

const PIP_COLOR := Color(0.45, 0.9, 0.55)
const PIP_EMPTY := Color(0.2, 0.24, 0.28, 0.7)
const CROSSHAIR_COLOR := Color(0.9, 0.95, 1.0, 0.9)
const HITMARKER_COLOR := Color(1.0, 1.0, 1.0)
const HITMARKER_KILL_COLOR := Color(1.0, 0.25, 0.2)
const HITMARKER_FADE := 0.25
## The X's arms: how far from the centre they start and how long they are.
const HITMARKER_GAP := 6.0
const HITMARKER_LENGTH := 7.0
const AMMO_COLOR := Color(1.0, 1.0, 1.0)
const AMMO_EMPTY_COLOR := Color(1.0, 0.25, 0.2)
## Pixels between the centre and a crosshair line at zero spread, and per
## degree of spread on top.
const CROSSHAIR_GAP_MIN := 5.0
const CROSSHAIR_GAP_PER_DEGREE := 6.0
## One line each way from the centre; `_lines` runs in this order.
const CROSSHAIR_DIRECTIONS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

var _pips: Array[ColorRect] = []
var _pip_row: HBoxContainer
var _ammo_label: Label
var _prompt_label: Label
var _name_label: Label
var _vignette: ColorRect
var _lines: Array[ColorRect] = []
var _dot: ColorRect
var _hitmarker: Control
var _hitmarker_kill := false
var _hitmarker_tween: Tween
var _magazine := 0
var _reloading := false
var _spread_degrees := 0.0
var _ads := false


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_vignette)

	var crosshair := Control.new()
	crosshair.name = "Crosshair"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)
	for direction in CROSSHAIR_DIRECTIONS:
		var line := ColorRect.new()
		line.color = CROSSHAIR_COLOR
		line.size = Vector2(4, 2) if direction.x != 0.0 else Vector2(2, 4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		crosshair.add_child(line)
		_lines.append(line)
	_dot = ColorRect.new()
	_dot.color = CROSSHAIR_COLOR
	_dot.size = Vector2(2, 2)
	_dot.position = Vector2(-1, -1)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	crosshair.add_child(_dot)
	_hitmarker = Control.new()
	_hitmarker.name = "Hitmarker"
	_hitmarker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hitmarker.modulate.a = 0.0
	crosshair.add_child(_hitmarker)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var arm := ColorRect.new()
		arm.color = HITMARKER_COLOR
		arm.size = Vector2(HITMARKER_LENGTH, 2)
		arm.pivot_offset = Vector2(0, 1)
		arm.rotation = corner.angle()
		arm.position = corner.normalized() * HITMARKER_GAP - Vector2(0, 1)
		arm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hitmarker.add_child(arm)
	_layout_crosshair()

	_pip_row = HBoxContainer.new()
	_pip_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_pip_row.position = Vector2(24, -40)
	_pip_row.add_theme_constant_override("separation", 6)
	root.add_child(_pip_row)

	_ammo_label = Label.new()
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.position = Vector2(-140, -44)
	_ammo_label.add_theme_font_size_override("font_size", 24)
	root.add_child(_ammo_label)

	_name_label = Label.new()
	_name_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_name_label.position = Vector2(24, 20)
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.modulate = Color(0.85, 0.9, 1.0, 0.85)
	root.add_child(_name_label)

	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-120, -110)
	_prompt_label.custom_minimum_size = Vector2(240, 0)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 18)
	_prompt_label.text = ""
	root.add_child(_prompt_label)


## Everything the HUD reports on the Pirate, in one place for the main scene
## and the headless suite alike.
func watch(player: Node) -> void:
	set_ammo(player.ammo)
	player.ammo_changed.connect(set_ammo)
	player.reloading_changed.connect(set_reloading)
	player.spread_changed.connect(set_spread)
	player.ads_changed.connect(set_ads)
	player.dry_fired.connect(dry_fire)
	player.hit_landed.connect(flash_hitmarker)


## The ship the pirate is aboard, as the player reads it ("The Pirate").
func set_ship_name(text: String) -> void:
	_name_label.text = text


## What the name label reads; a seam for the headless suite.
func ship_name_text() -> String:
	return _name_label.text


func set_max_health(value: int) -> void:
	for pip in _pips:
		pip.queue_free()
	_pips.clear()
	for i in value:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(22, 10)
		pip.color = PIP_COLOR
		_pip_row.add_child(pip)
		_pips.append(pip)


func set_health(value: int) -> void:
	for i in _pips.size():
		_pips[i].color = PIP_COLOR if i < value else PIP_EMPTY


func set_ammo(in_mag: int) -> void:
	_magazine = in_mag
	_refresh_ammo()


func set_reloading(reloading: bool) -> void:
	_reloading = reloading
	_refresh_ammo()


## `n / ∞`: reserves are infinite until an ammo effort makes them a count.
## The number is red at zero; the reloading text never is.
func _refresh_ammo() -> void:
	if _reloading:
		_ammo_label.text = "RELOADING…"
		_ammo_label.add_theme_color_override("font_color", AMMO_COLOR)
		return
	_ammo_label.text = "%d / ∞" % _magazine
	_ammo_label.add_theme_color_override("font_color", AMMO_EMPTY_COLOR if _magazine == 0 else AMMO_COLOR)


func ammo_text() -> String:
	return _ammo_label.text


## The counter is showing the empty magazine in red.
func ammo_reads_empty() -> bool:
	return _ammo_label.get_theme_color("font_color") == AMMO_EMPTY_COLOR


## The Pirate's live cone half-angle: the lines open with it.
func set_spread(degrees: float) -> void:
	_spread_degrees = maxf(degrees, 0.0)
	_layout_crosshair()


## Sights up: the lines give way to a dot.
func set_ads(on: bool) -> void:
	_ads = on
	_layout_crosshair()


## Pixels from the centre to each line right now.
func crosshair_gap() -> float:
	return CROSSHAIR_GAP_MIN + CROSSHAIR_GAP_PER_DEGREE * _spread_degrees


func crosshair_is_dot() -> bool:
	return _ads


func _layout_crosshair() -> void:
	_dot.visible = _ads
	var gap := crosshair_gap()
	for i in _lines.size():
		var line := _lines[i]
		var direction := CROSSHAIR_DIRECTIONS[i]
		line.visible = not _ads
		# The near end sits `gap` out along the direction (a rect's origin
		# is its top-left, so the left and up lines step back their own
		# length), centred across.
		var length := maxf(line.size.x, line.size.y)
		var reach := gap + (length if direction.x < 0.0 or direction.y < 0.0 else 0.0)
		var across := Vector2(0.0, -1.0) if direction.x != 0.0 else Vector2(-1.0, 0.0)
		line.position = direction * reach + across


## A hit landed: the X shows and fades, red when it killed.
func flash_hitmarker(_target: Node3D = null, killed: bool = false) -> void:
	_hitmarker_kill = killed
	for arm in _hitmarker.get_children():
		(arm as ColorRect).color = HITMARKER_KILL_COLOR if killed else HITMARKER_COLOR
	if _hitmarker_tween != null and _hitmarker_tween.is_valid():
		_hitmarker_tween.kill()
	_hitmarker.modulate.a = 1.0
	_hitmarker_tween = create_tween()
	_hitmarker_tween.tween_interval(0.05)
	_hitmarker_tween.tween_property(_hitmarker, "modulate:a", 0.0, HITMARKER_FADE)


func hitmarker_alpha() -> float:
	return _hitmarker.modulate.a


func hitmarker_is_kill() -> bool:
	return _hitmarker_kill and _hitmarker.modulate.a > 0.0


## The empty click of a dry pull. The sound belongs to the sound effort;
## this is where it hangs.
func dry_fire() -> void:
	dry_click.emit()


## Empty text hides the prompt.
func show_prompt(text: String) -> void:
	_prompt_label.text = text


func flash_damage() -> void:
	_vignette.color.a = 0.35
	var tween := create_tween()
	tween.tween_property(_vignette, "color:a", 0.0, 0.4)
