class_name MenuStyle
extends RefCounted
## The look the main menu and the death screen share: flat dark buttons with
## an amber edge that lights on hover, and the big outlined headings.

const ACCENT := Color(1.0, 0.62, 0.2)
const TEXT := Color(0.88, 0.92, 1.0)
const DIM_TEXT := Color(0.6, 0.66, 0.76)
const PANEL := Color(0.03, 0.04, 0.07, 0.72)
const BUTTON_SIZE := Vector2(280, 52)


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BUTTON_SIZE
	b.focus_mode = Control.FOCUS_ALL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_focus_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(Color(0.06, 0.08, 0.12, 0.85), Color(1, 1, 1, 0.12)))
	b.add_theme_stylebox_override("hover", _box(Color(0.1, 0.11, 0.15, 0.92), ACCENT))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), ACCENT))
	b.add_theme_stylebox_override("pressed", _box(Color(0.22, 0.14, 0.06, 0.95), ACCENT))
	return b


static func heading(text: String, size: int, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05, 1.0))
	label.add_theme_constant_override("outline_size", maxi(size / 10, 2))
	label.add_theme_color_override("font_shadow_color", Color(color, 0.35))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)
	label.add_theme_constant_override("shadow_outline_size", maxi(size / 4, 4))
	return label


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var box := _box(PANEL, Color(1, 1, 1, 0.08))
	box.content_margin_left = 32
	box.content_margin_right = 32
	box.content_margin_top = 28
	box.content_margin_bottom = 28
	p.add_theme_stylebox_override("panel", box)
	return p


static func _box(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(0)
	box.border_width_left = 3
	box.set_corner_radius_all(2)
	box.content_margin_left = 22
	box.content_margin_right = 18
	return box
