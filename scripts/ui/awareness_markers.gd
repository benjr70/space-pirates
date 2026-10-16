class_name AwarenessMarkers
extends Control
## A small bar over each crew member's head that fills with its Awareness of
## the Pirate: white while unaware, yellow once suspicious, solid red when
## spotted. Drawn on the HUD over the 3D view, only for crew that are on
## screen (or within [constant NEAR] metres) and aware of him at all.
## Rings the spotted sting once each time a crew member tips into red.

const WHITE := Color(1.0, 1.0, 1.0, 0.9)
const YELLOW := Color(1.0, 0.82, 0.2)
const RED := Color(1.0, 0.22, 0.18)
const OUTLINE := Color(0.0, 0.0, 0.0, 0.6)
## Bar size in pixels, and how far over the crew member's origin it floats.
const BAR := Vector2(8.0, 26.0)
const HEAD_OFFSET := 2.35
## Crew this close are marked even behind the camera, pinned to the screen's
## bottom edge, so a suspicious crew member at his back still reads.
const NEAR := 6.0
## Crew further than this are not marked even on screen.
const FAR := 22.0
## Placeholder sting until one is picked by ear in the sound booth.
const STING: AudioStream = preload("res://assets/audio/kenney_impact/impactMetal_light_001.ogg")

var stings := 0
var _sting: AudioStreamPlayer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group(Crew3D.SPOTTED_GROUP)
	_sting = AudioStreamPlayer.new()
	_sting.stream = STING
	_sting.volume_db = -4.0
	_sting.bus = &"Master"
	add_child(_sting)


## The fill colour for an Awareness value.
static func color_for(awareness: float) -> Color:
	match CrewPerception.band_of(awareness):
		CrewPerception.Band.SPOTTED:
			return RED
		CrewPerception.Band.SUSPICIOUS:
			return YELLOW
	return WHITE


## Called through [constant Crew3D.SPOTTED_GROUP] when a crew member tips red.
func on_crew_spotted(_crew: Node) -> void:
	stings += 1
	_sting.play()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for node in get_tree().get_nodes_in_group(&"crew"):
		var crew := node as Crew3D
		if crew == null or not crew.is_alive() or crew.perception.awareness <= 0.0:
			continue
		var head := crew.global_position + Vector3.UP * HEAD_OFFSET
		var distance := camera.global_position.distance_to(head)
		var behind := camera.is_position_behind(head)
		if distance > FAR or (behind and distance > NEAR):
			continue
		var screen := get_viewport_rect().size
		var at := camera.unproject_position(head)
		if behind:
			# Mirror across the centre and pin to the bottom edge.
			at = Vector2(screen.x - at.x, screen.y - BAR.y)
		at.x = clampf(at.x, BAR.x, screen.x - BAR.x)
		at.y = clampf(at.y, BAR.y, screen.y - BAR.y)
		_draw_bar(at, crew.perception.awareness)


func _draw_bar(at: Vector2, awareness: float) -> void:
	var box := Rect2(at - BAR / 2.0, BAR)
	draw_rect(box.grow(1.5), OUTLINE)
	var fill := clampf(awareness, 0.0, 1.0) * BAR.y
	draw_rect(Rect2(box.position.x, box.end.y - fill, BAR.x, fill), color_for(awareness))
