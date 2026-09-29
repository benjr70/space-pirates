extends Node3D
## Builds the ship the pirate is standing in, drops him just inside the hatch
## this raid boards through and lifts the darkness off rooms as he walks into
## them. Also wires the HUD to everything it reports on.

## Leave null to use the hand-authored player ship, or a generated one when
## the game was launched with `-- --seed=N --class=large`.
@export var layout_override: ShipLayout

## Which of the ship's hatches this raid boards through, chosen at raid start.
## Not a fact about the ship: the same target can be entered by any of them.
@export var entry_hatch := 0

## Unexplored rooms start dark with their crew hidden, lifting as the pirate
## walks in. Off means the whole ship starts lit and visible.
@export var explore_darkness := true

@onready var ship: Node3D = $Ship
@onready var player: CharacterBody3D = $Player
@onready var hud: Hud = $Hud

var layout: ShipLayout
var tracker: RoomTracker


func _ready() -> void:
	layout = layout_override if layout_override != null else _layout_from_args()
	ShipBuilder3D.build(layout, ship)
	# A layout with no Hatches (none is generated so) boards the aft-most Room.
	var boarding_room := ShipGenerator.aft_most_room(layout)
	if layout.hatches.is_empty():
		player.global_position = ShipBuilder3D.room_center_world(layout.rooms[boarding_room])
	else:
		var hatch: HatchData = layout.hatches[entry_hatch]
		boarding_room = hatch.room
		player.global_position = ShipBuilder3D.hatch_entry_world(layout, hatch)
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


func _process(_delta: float) -> void:
	hud.show_prompt(_door_prompt())


## The prompt for the nearest door the pirate can reach, or nothing.
func _door_prompt() -> String:
	for node in get_tree().get_nodes_in_group(&"doors"):
		var door: Door3D = node
		if door.in_reach():
			return door.prompt_text()
	return ""
