extends SceneTree
## PROTOTYPE: a sound booth. Lists every ogg/wav under assets/audio/audition
## (make the folder, drop candidates in, delete it after) and plays one per
## key (1-9, then 0 and Q..P for more). Used 2026-09-29 to pick the gunshot.
##
##   flatpak run org.godotengine.Godot --path . --script res://scripts/proto/proto_sound_audition.gd

const DIR := "res://assets/audio/audition"
const KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_Q, KEY_W, KEY_E, KEY_R, KEY_T, KEY_Y, KEY_U, KEY_I, KEY_O, KEY_P]
const KEY_NAMES := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"]

var files: Array[String] = []
var player: AudioStreamPlayer
var label: Label
var last := ""


func _initialize() -> void:
	var dir := DirAccess.open(DIR)
	for f in dir.get_files():
		if f.ends_with(".ogg") or f.ends_with(".wav"):
			files.append(f)
	files.sort()
	var root_control := Control.new()
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(root_control)
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(bg)
	label = Label.new()
	label.position = Vector2(30, 30)
	label.add_theme_font_size_override("font_size", 22)
	root_control.add_child(label)
	player = AudioStreamPlayer.new()
	player.bus = &"sfx"
	root.add_child(player)
	var booth := Booth.new()
	booth.owner_tree = self
	root.add_child(booth)
	_refresh()


func _refresh() -> void:
	var text := "SOUND BOOTH  -  press a key to play, Esc to quit\n\n"
	for i in files.size():
		text += "  [%s]  %s%s\n" % [KEY_NAMES[i], files[i], "   <- playing" if files[i] == last else ""]
	label.text = text


## A Node to receive input, since a SceneTree script gets none directly.
class Booth extends Node:
	var owner_tree: SceneTree
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				owner_tree.quit()
			else:
				owner_tree._handle_key(event.keycode)


func _handle_key(keycode: int) -> void:
	var i := KEYS.find(keycode)
	if i < 0 or i >= files.size():
		return
	last = files[i]
	player.stream = load(DIR + "/" + last)
	player.play()
	_refresh()
