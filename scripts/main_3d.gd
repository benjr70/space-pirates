extends Node3D
## Builds the ship the pirate is standing in, docks his Boarding Pod on the
## hatch this raid boards through and starts him in it, facing in, and lifts the darkness off rooms as he walks into
## them. Also wires the HUD to everything it reports on.

## Leave null to board the [Raid] picked on the main menu, or with no Raid on,
## the hand-authored player ship, or a generated one when the game was
## launched with `-- --seed=N --class=large`.
@export var layout_override: ShipLayout

## Which of the ship's hatches this raid boards through, chosen at raid start.
## Not a fact about the ship: the same target can be entered by any of them.
## -1 picks one a [BoardingPod] docks at cleanly, and is replaced by it.
@export var entry_hatch := -1

## Unexplored rooms start dark with their crew hidden, lifting as the pirate
## walks in. Off means the whole ship starts lit and visible.
@export var explore_darkness := true

@onready var ship: Node3D = $Ship
@onready var player: CharacterBody3D = $Player
@onready var hud: Hud = $Hud
@onready var end_screen: RaidEndScreen = $RaidEndScreen
@onready var pause_menu: PauseMenu = $PauseMenu

var layout: ShipLayout
var tracker: RoomTracker
## Null on a ship with no Hatch to dock a pod at.
var extraction: Extraction
## Seconds since boarding, for the extracted screen.
var raid_time := 0.0


func _ready() -> void:
	layout = layout_override
	if layout == null:
		layout = Raid.layout()
	if layout == null:
		layout = _layout_from_args()
	# A layout with no Hatches (none is generated so) boards the aft-most Room.
	var boarding_room := ShipGenerator.aft_most_room(layout)
	if layout.hatches.is_empty():
		ShipBuilder3D.build(layout, ship)
		player.global_position = ShipBuilder3D.room_center_world(layout.rooms[boarding_room])
	else:
		if entry_hatch < 0:
			entry_hatch = BoardingPod.choose_hatch(layout)
		ShipBuilder3D.build(layout, ship, entry_hatch)
		boarding_room = layout.hatches[entry_hatch].room
		var pod: BoardingPod = ship.get_node("BoardingPod")
		player.global_position = pod.spawn_point()
		player.global_basis = pod.spawn_basis()
	player.spawn_point = player.global_position

	var reveal: RoomReveal = ship.get_node("Reveal")
	tracker = RoomTracker.new()
	tracker.name = "RoomTracker"
	add_child(tracker)
	tracker.setup(layout, player)
	if explore_darkness:
		tracker.room_changed.connect(func(room: int, _previous: int) -> void: reveal.reveal(room))
		reveal.reveal(boarding_room)
	else:
		for i in layout.rooms.size():
			reveal.reveal(i)

	_wire_hud()
	_wire_raid_end()
	if ship.has_node("BoardingPod"):
		_wire_extraction(ship.get_node("BoardingPod"))


## The hand-authored ship, or a generated target when `--seed=N` (and
## optionally `--class=small|medium|large`) follow `--` on the command line.
static func _layout_from_args(args: PackedStringArray = OS.get_cmdline_user_args()) -> ShipLayout:
	var seed := 0
	var ship_class: StringName = &"medium"
	for arg in args:
		if arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--class="):
			ship_class = StringName(arg.trim_prefix("--class="))
	if seed <= 0:
		return PlayerShipLayout.create()
	if not ship_class in ShipGenerator.CLASSES:
		push_warning("main: unknown class %s, boarding a medium target" % ship_class)
		ship_class = &"medium"
	return ShipGenerator.generate(ship_class, seed)


func _wire_hud() -> void:
	hud.set_ship_name(layout.display_name())
	hud.set_max_health(player.health.max_health)
	hud.set_health(player.health.current)
	hud.watch(player)

	player.health.damaged.connect(func(_amount: int, _from: Node) -> void:
		hud.set_health(player.health.current)
		hud.flash_damage())
	player.health.died.connect(func(_from: Node) -> void: hud.set_health(0))
	player.died.connect(func() -> void: hud.show_prompt(""))


## Down is down: the pirate stays dead until Retry rebuilds the ship from its
## seed, crew and all, or the menu takes him off it. Esc pauses until then.
func _wire_raid_end() -> void:
	player.auto_respawn = false
	player.died.connect(func() -> void:
		_close_raid()
		end_screen.show_death(_death_detail()))
	end_screen.retry_pressed.connect(Raid.retry)
	end_screen.new_raid_pressed.connect(Raid.new_raid)
	end_screen.menu_pressed.connect(Raid.to_menu)
	pause_menu.menu_pressed.connect(Raid.to_menu)


## Out the way he came: the home door at the back of the pod, once he has
## set foot aboard. Getting out freezes the ship under the extracted screen.
func _wire_extraction(pod: BoardingPod) -> void:
	extraction = Extraction.new()
	extraction.name = "Extraction"
	add_child(extraction)
	extraction.setup(pod, player)
	tracker.room_changed.connect(func(_room: int, _previous: int) -> void: extraction.boarded = true)
	extraction.extracted.connect(func() -> void:
		_close_raid()
		get_tree().paused = true
		end_screen.show_extracted(_extract_detail()))


## Whichever way the Raid ended, the HUD and the pause menu step aside.
func _close_raid() -> void:
	hud.visible = false
	pause_menu.enabled = false


func _extract_detail() -> String:
	var crew := get_tree().get_nodes_in_group(&"crew")
	var down := 0
	for body in crew:
		if not body.is_alive():
			down += 1
	@warning_ignore("integer_division")
	var clock := "%d:%02d" % [int(raid_time) / 60, int(raid_time) % 60]
	return "Off %s  ·  %s aboard  ·  %d of %d crew down" % [layout.display_name(), clock, down, crew.size()]


func _death_detail() -> String:
	if layout.gen_seed > 0:
		return "Aboard %s  ·  %s  ·  seed %d" % [layout.display_name(), String(layout.ship_class).capitalize(), layout.gen_seed]
	return "Aboard %s" % layout.display_name()


func _process(delta: float) -> void:
	raid_time += delta
	if extraction != null and Input.is_action_just_pressed("interact") and extraction.can_begin():
		extraction.begin()
	hud.show_prompt(_prompt())


## What the HUD offers: the Extraction under way, the home door, or a door.
func _prompt() -> String:
	if extraction != null:
		if extraction.is_counting():
			return "Extracting — %.1f s  (leave the pod to abort)" % extraction.time_left()
		if extraction.can_begin():
			return "E — Extract"
	return _door_prompt()


## The prompt for the nearest door the pirate can reach, or nothing.
func _door_prompt() -> String:
	for node in get_tree().get_nodes_in_group(&"doors"):
		var door: Door3D = node
		if door.in_reach():
			return door.prompt_text()
	return ""
