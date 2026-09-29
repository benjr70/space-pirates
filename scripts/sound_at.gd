class_name SoundAt
extends Object
## A one-off positional sound: a bolt striking the hull, a crew member's
## shot. Spawns an `AudioStreamPlayer3D` beside [param parent] at [param at],
## plays it on the sfx bus with a little random pitch, and lets it free
## itself when done, or after the stream's length where nothing is audible
## (headless), so none pile up.


static func play(parent: Node, at: Vector3, stream: AudioStream, volume_db: float,
		pitch_spread: float = 0.06, node_name: String = "Sound") -> AudioStreamPlayer3D:
	if stream == null or parent == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.stream = stream
	player.bus = &"sfx"
	player.volume_db = volume_db
	player.pitch_scale = randf_range(1.0 - pitch_spread, 1.0 + pitch_spread)
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.global_position = at
	player.play()
	player.get_tree().create_timer(stream.get_length() + 0.1).timeout.connect(player.queue_free)
	return player
