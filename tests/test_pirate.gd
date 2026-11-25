extends SceneTree
## Headless checks on the pirate: the movement state machine (clamber ledge
## band, sprint grace and latch, slide-jump, crouch headroom, the CLAMBER
## input lock) and the Pistol (semi-auto trigger, dry-pull reload, reload
## carrying through moves, spread and bloom, a swapped Weapon Profile) and
## Aim Down Sights (where it is allowed, what ends it, the raise out of a
## sprint, its zoom, slowdown and tighter cone) and the Melee (the cone, the
## lunge and its input lock, the back-hit kill, the reload cancel, where it
## is refused) and the Viewmodel's procedural layer (poses, sway, bob,
## recoil, camera kick and Descope roll, the wall-clipping material flags)
## and its clips (which plays on what, what a fire or a melee may interrupt,
## the reload cancel reset), the HUD (crosshair opening with spread and
## collapsing to a dot in ADS, the red zero, the dry click) and the sounds
## (one per event, the reload sequence and its cancel, footsteps only on
## the move). Runs
## on a flat course built here, not on a ship, so every height is exact and
## the checks cost seconds.
##
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/test_pirate.gd

const UP := Vector3.UP
const PLAYER_SCENE: PackedScene = preload("res://scenes/player_3d.tscn")
const HEAVY_PISTOL: WeaponProfile = preload("res://tests/weapons/heavy_pistol.tres")
const ASSAULT_RIFLE: WeaponProfile = preload("res://resources/weapons/assault_rifle.tres")
const SHOTGUN: WeaponProfile = preload("res://resources/weapons/shotgun.tres")
const MARKSMAN_RIFLE: WeaponProfile = preload("res://resources/weapons/marksman_rifle.tres")
## Pinpoint aimed and still, looser aimed and walking, with sway: the shape
## of an aimed long gun without being one.
const STEADY_RIFLE: WeaponProfile = preload("res://tests/weapons/steady_rifle.tres")
const FRAME := 1.0 / 60.0
## Course blocks, one per height, spaced along X with their near face at Z -2.5.
const BLOCK_HEIGHTS := [0.3, 0.5, 0.7, 0.9, 1.1, 1.3, 1.5, 1.7, 1.9, 2.1]
const BLOCK_SPACING := 3.0
const BLOCK_Z := -3.0
## A 0.9 m block with a slab 1.3 m over its top: a clamber that lands crouched.
const LOW_BLOCK_X := 40.0
const LOW_BLOCK_HEIGHT := 0.9
const LOW_HEADROOM := 1.3
## A slab 1.3 m over the floor to crouch under.
const SLAB_X := -8.0
const SLAB_CLEARANCE := 1.3
## Open floor for the sprint and slide runs.
const RUNWAY := Vector3(15.0, 0.0, 15.0)
## A wall past the runway's far end, deep enough that an 80 m/s bolt (1.3 m
## per physics step) cannot skip it.
const BACKSTOP_Z := 5.5

var failures: Array[String] = []
var checks := 0
## The seed this run draws from (`-- seed=<n>` to replay one).
var run_seed := 0
var world: Node3D
var player: CharacterBody3D
var door: Door3D
var states_seen: Array = []
var shots_fired := 0
var reloads_started: Array = []
var reloads_cancelled := 0
var ads_seen: Array = []
var descopes := 0
var swings: Array = []
## Every hit the pirate landed, as [target, killed].
var hits_landed: Array = []
var dummy: Dummy
var weapon: Viewmodel
var hud: Hud
var dry_fires := 0
var dry_clicks := 0
var audio: PirateAudio
## Every sound the pirate's audio played, as [kind, stream].
var sounds: Array = []


## A body a Melee can hit: on layer 2 with hit points, a team and a facing,
## like the crew, but with none of their brains.
class Dummy extends CharacterBody3D:
	var health: Health

	func _init(hit_points: int) -> void:
		name = "Dummy"
		collision_layer = 2
		collision_mask = 1
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.7
		shape.shape = capsule
		shape.position.y = 0.85
		add_child(shape)
		health = Health.new()
		health.name = "Health"
		health.max_health = hit_points
		add_child(health)

	func get_team() -> StringName:
		return &"crew"

	func is_alive() -> bool:
		return health.is_alive()

	func take_damage(amount: int, from: Node = null) -> void:
		if health.take_damage(amount, from):
			# Dead: out of the way of bolts and swings, like a crew corpse.
			collision_layer = 0


func _initialize() -> void:
	run_seed = SuiteSeed.pick("pirate")
	_build_course()
	_run()


func _run() -> void:
	# GridMap-free course, but body shapes still come live a frame after entry.
	await physics_frame
	await physics_frame
	_check_ledge_band()
	await _check_clamber_by_input()
	await _check_clamber_lands_crouched()
	await _check_sprint_grace()
	await _check_sprint_latch()
	await _check_slide_jump()
	await _check_crouch_headroom()
	await _check_clamber_lockout()
	await _check_semi_auto()
	await _check_dry_reload()
	await _check_reload_carries()
	await _check_spread()
	await _check_profile_swap()
	await _check_weapon_wheel()
	await _check_swap_is_busy()
	await _check_weapon_keys()
	await _check_assault_rifle_full_auto()
	await _check_assault_rifle_model()
	await _check_shotgun_pellets()
	await _check_shotgun_hit_marker()
	await _check_shotgun_model()
	await _check_shell_reload()
	await _check_shotgun_rig()
	await _check_marksman_rifle_model()
	await _check_marksman_rifle_rig()
	await _check_marksman_rifle_cones()
	await _check_marksman_rifle_on_the_sight()
	await _check_marksman_rifle_descopes()
	await _check_ads_states()
	await _check_ads_ends()
	await _check_ads_raise()
	await _check_ads_numbers()
	await _check_cones_unchanged()
	await _check_aimed_moving_spread()
	await _check_aimed_sway()
	await _check_mouse_slowed_by_zoom()
	await _check_descope_recovery()
	_check_aim_and_swap_numbers()
	await _check_aim_time_pose()
	await _check_aim_time_cone()
	await _check_shot_halfway_up()
	await _check_descope_full_aim_time()
	await _check_swap_time_of_drawn()
	await _check_melee_cone()
	await _check_melee_lunge()
	await _check_melee_back_hit()
	await _check_melee_cancels_reload()
	await _check_melee_states()
	await _check_viewmodel_materials()
	await _check_viewmodel_poses()
	await _check_viewmodel_ads_pose()
	await _check_viewmodel_sway()
	await _check_viewmodel_bob()
	await _check_viewmodel_recoil()
	await _check_viewmodel_descope()
	_check_clips_exist()
	await _check_clips_play()
	await _check_clips_follow_profile()
	await _check_holder_model()
	await _check_pistol_clips()
	await _check_hud_crosshair()
	await _check_hud_ammo()
	_check_hud_health()
	await _check_hud_dry_click()
	await _check_audio_events()
	_check_shot_sounds_only_in_profiles()
	await _check_audio_reload()
	await _check_audio_footsteps()
	await _check_audio_impact_and_respawn()
	await _check_crew_shot_sound()
	await _check_bolt_reach()
	await _check_hit_markers()
	await _check_tracer()
	await _check_crew_models()
	_report()
	await _silence()
	quit(1 if failures.size() > 0 else 0)


## Under the runner's fixed frame step the suite outruns the audio mixer, which
## still plays in real time: stop every sound so none is mid-play at exit.
func _silence() -> void:
	for node in root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.stop()
	OS.delay_msec(300)
	await process_frame
	await process_frame


## --- the course ---

func _build_course() -> void:
	world = Node3D.new()
	world.name = "Course"
	root.add_child(world)
	_box("Floor", Vector3(120.0, 0.2, 60.0), Vector3(20.0, -0.1, 0.0))
	_box("Ceiling", Vector3(120.0, 0.1, 60.0), Vector3(20.0, ShipBuilder3D.WALL_HEIGHT + 0.05, 0.0))
	for i in BLOCK_HEIGHTS.size():
		var h: float = BLOCK_HEIGHTS[i]
		_box("Block%d" % i, Vector3(1.0, h, 1.0), Vector3(_block_x(i), h / 2.0, BLOCK_Z))
	_box("LowBlock", Vector3(1.0, LOW_BLOCK_HEIGHT, 1.0), Vector3(LOW_BLOCK_X, LOW_BLOCK_HEIGHT / 2.0, BLOCK_Z))
	_box("LowSlab", Vector3(3.0, 0.2, 3.0),
			Vector3(LOW_BLOCK_X, LOW_BLOCK_HEIGHT + LOW_HEADROOM + 0.1, BLOCK_Z))
	_box("Slab", Vector3(3.0, 0.2, 3.0), Vector3(SLAB_X, SLAB_CLEARANCE + 0.1, BLOCK_Z))
	_box("Backstop", Vector3(3.0, 3.4, 3.0), Vector3(RUNWAY.x + 1.0, 1.7, BACKSTOP_Z))

	# A shut door within reach of the 1.1 m block's start position, so the
	# interact key can be tried mid-clamber.
	door = ShipBuilder3D.DOOR_SCENE.instantiate()
	door.setup_span(3, true, false)
	door.position = Vector3(_block_x(4), 0.0, -0.5)
	world.add_child(door)

	player = PLAYER_SCENE.instantiate()
	world.add_child(player)
	weapon = player.get_node("Head/Camera3D/Weapon")
	player.dry_fired.connect(func() -> void: dry_fires += 1)

	# The HUD, watching the pirate as it does under the main scene. It
	# builds itself on entering the tree, so the watch waits for a frame.
	hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	hud.ready.connect(func() -> void: hud.watch(player))
	hud.dry_click.connect(func() -> void: dry_clicks += 1)
	audio = player.get_node("Audio")
	audio.played.connect(func(kind: StringName, stream: AudioStream) -> void: sounds.append([kind, stream]))
	player.state_changed.connect(func(_from: int, to: int) -> void: states_seen.append(to))
	player.fired.connect(func() -> void: shots_fired += 1)
	player.reload_started.connect(func(from_empty: bool) -> void: reloads_started.append(from_empty))
	player.reload_cancelled.connect(func() -> void: reloads_cancelled += 1)
	player.ads_changed.connect(func(on: bool) -> void: ads_seen.append(on))
	player.descoped.connect(func() -> void: descopes += 1)
	player.melee_swung.connect(func(target: Node3D, killed: bool) -> void: swings.append([target, killed]))
	player.hit_landed.connect(func(target: Node3D, killed: bool, _headshot: bool) -> void: hits_landed.append([target, killed]))


func _block_x(i: int) -> float:
	return i * BLOCK_SPACING


func _box(box_name: String, size: Vector3, centre: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = box_name
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = centre
	world.add_child(body)
	return body


## --- driving the pirate ---

## Stand him at `at`, facing -Z, in WALK with nothing held.
func _place(at: Vector3) -> void:
	for action in ["move_up", "move_down", "move_left", "move_right", "sprint", "crouch", "jump", "interact", "shoot", "reload", "aim", "melee"]:
		Input.action_release(action)
	# A press made in the last check lands a frame late; let it land on the
	# old life, not the new one. Bolts still flying belong to it too.
	await physics_frame
	_clear_shots()
	player.spawn_point = at
	player.respawn()
	player.rotation.y = 0.0
	await physics_frame
	await physics_frame
	states_seen.clear()
	shots_fired = 0
	reloads_started.clear()
	reloads_cancelled = 0
	ads_seen.clear()
	descopes = 0
	swings.clear()
	hits_landed.clear()
	dry_fires = 0
	dry_clicks = 0
	sounds.clear()


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _seconds(t: float) -> void:
	await _frames(ceili(t / FRAME))


func _before_block(i: int) -> Vector3:
	return Vector3(_block_x(i), 0.0, BLOCK_Z + 0.5 + 0.5)


## --- checks ---

## The floor probe alone: which heights offer a ledge from a standing start.
func _check_ledge_band() -> void:
	for i in BLOCK_HEIGHTS.size():
		var h: float = BLOCK_HEIGHTS[i]
		player.global_position = _before_block(i)
		player.rotation.y = 0.0
		var ledge: Dictionary = player.find_ledge()
		var expected := h >= 0.7 and h <= 1.5
		_expect(ledge.is_empty() != expected,
				"%.1f m block: ledge %s, expected %s" % [h, "found" if not ledge.is_empty() else "refused", "found" if expected else "refused"])
		if not ledge.is_empty():
			_expect(absf(ledge.height - h) < 0.05, "%.1f m block measured as %.2f m" % [h, ledge.height])
			_expect(not ledge.crouched, "%.1f m block under a 3.5 m ceiling lands crouched" % h)
	player.global_position = Vector3(LOW_BLOCK_X, 0.0, BLOCK_Z + 1.0)
	var low: Dictionary = player.find_ledge()
	_expect(not low.is_empty() and low.crouched, "a ledge with 1.3 m headroom should be offered as a crouched landing")


## Hold jump and forward at every block: the band clambers over 0.5 s and the
## rest either hop in place or mantle only after the jump has lifted the feet
## into the band.
func _check_clamber_by_input() -> void:
	for i in BLOCK_HEIGHTS.size():
		var h: float = BLOCK_HEIGHTS[i]
		await _place(_before_block(i))
		Input.action_press("move_up")
		Input.action_press("jump")
		await _frames(2)
		var from_floor: bool = player.state == player.State.CLAMBER
		# Let go once the move has started, or he walks straight off the far
		# side of a one-metre block.
		Input.action_release("jump")
		Input.action_release("move_up")
		await _seconds(0.7)
		var in_band := h >= 0.7 and h <= 1.5
		_expect(from_floor == in_band,
				"%.1f m block: clamber from the floor %s" % [h, "started" if from_floor else "refused"])
		if in_band:
			_expect(player.state == player.State.WALK,
					"%.1f m block: ended the clamber in %s, expected WALK" % [h, player.State.keys()[player.state]])
			_expect(absf(player.global_position.y - h) < 0.1,
					"%.1f m block: stood at y %.2f after the clamber" % [h, player.global_position.y])
		elif h < 0.7:
			_expect(not states_seen.has(player.State.CLAMBER),
					"%.1f m block: clambered, below the band" % h)
		# Above the band a held jump lifts the feet into it mid-air, which is
		# Halo's jump-then-mantle. A tap must still be refused: checked below.
	for i in [7, 8]:
		var h: float = BLOCK_HEIGHTS[i]
		await _place(_before_block(i))
		Input.action_press("move_up")
		Input.action_press("jump")
		await _frames(1)
		Input.action_release("jump")
		await _seconds(1.0)
		Input.action_release("move_up")
		_expect(not states_seen.has(player.State.CLAMBER),
				"%.1f m block: a tapped jump clambered" % h)
		_expect(player.global_position.y < 0.1,
				"%.1f m block: a tapped jump left him at y %.2f" % [h, player.global_position.y])


func _check_clamber_lands_crouched() -> void:
	await _place(Vector3(LOW_BLOCK_X, 0.0, BLOCK_Z + 1.0))
	Input.action_press("move_up")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_release("move_up")
	await _seconds(0.7)
	_expect(states_seen.has(player.State.CLAMBER), "the 1.3 m headroom ledge was not clambered")
	_expect(player.state == player.State.CROUCH,
			"under 1.3 m of headroom he ended in %s, expected CROUCH" % player.State.keys()[player.state])
	_expect(absf(player.global_position.y - LOW_BLOCK_HEIGHT) < 0.1,
			"stood at y %.2f on the low block" % player.global_position.y)


func _sprint_up() -> void:
	Input.action_press("move_up")
	Input.action_press("sprint")
	await _seconds(0.5)
	_expect(player.state == player.State.SPRINT,
			"holding sprint and forward gave %s" % player.State.keys()[player.state])


func _check_sprint_grace() -> void:
	await _place(RUNWAY)
	await _sprint_up()
	var sprint_speed: float = player.flat_speed()
	_expect(absf(sprint_speed - player.max_speed * 1.10) < 0.1,
			"sprint runs at %.2f m/s, expected walk x1.10 = %.2f" % [sprint_speed, player.max_speed * 1.10])
	Input.action_release("sprint")
	await _seconds(0.1)
	_expect(player.state == player.State.WALK, "releasing sprint gave %s" % player.State.keys()[player.state])
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE,
			"crouch 0.1 s after sprint gave %s, expected SLIDE" % player.State.keys()[player.state])
	_expect(player.flat_speed() > player.max_speed * 1.10,
			"slide entered at %.2f m/s, expected above sprint" % player.flat_speed())

	await _place(RUNWAY)
	await _sprint_up()
	Input.action_release("sprint")
	await _seconds(0.3)
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.CROUCH,
			"crouch 0.3 s after sprint gave %s, expected CROUCH" % player.State.keys()[player.state])
	_expect(absf(player.collider.shape.height - 1.2) < 0.01, "crouched capsule is not 1.2 m")


func _check_sprint_latch() -> void:
	await _place(RUNWAY)
	await _sprint_up()
	var shot: Projectile3D = player.fire()
	_expect(shot == null, "the trigger fired a shot out of a sprint")
	_expect(player.state == player.State.WALK,
			"firing during sprint gave %s, expected WALK" % player.State.keys()[player.state])
	await _seconds(0.3)
	_expect(player.state == player.State.WALK,
			"sprint re-entered while still held after firing: %s" % player.State.keys()[player.state])
	Input.action_release("sprint")
	await _frames(2)
	Input.action_press("sprint")
	await _frames(3)
	_expect(player.state == player.State.SPRINT,
			"a fresh sprint press after the latch gave %s" % player.State.keys()[player.state])


func _check_slide_jump() -> void:
	await _place(RUNWAY)
	await _sprint_up()
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE, "crouch during sprint gave %s" % player.State.keys()[player.state])
	await _frames(3)
	# Damage interrupts nothing: a hit mid-slide just lands.
	player.take_damage(1)
	await _frames(1)
	_expect(player.state == player.State.SLIDE,
			"taking damage mid-slide gave %s" % player.State.keys()[player.state])
	var slide_speed: float = player.flat_speed()
	Input.action_press("jump")
	await _frames(2)
	_expect(player.state == player.State.AIR, "jumping out of a slide gave %s" % player.State.keys()[player.state])
	_expect(absf(player.flat_speed() - slide_speed) < 0.3,
			"slide-jump flew at %.2f m/s, slide was %.2f" % [player.flat_speed(), slide_speed])
	_expect(player.flat_speed() > player.max_speed, "slide-jump lost the slide's momentum")
	Input.action_release("jump")
	Input.action_release("crouch")
	Input.action_release("move_up")
	Input.action_release("sprint")


func _check_crouch_headroom() -> void:
	await _place(Vector3(SLAB_X, 0.0, 0.0))
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.CROUCH, "holding crouch gave %s" % player.State.keys()[player.state])
	Input.action_press("move_up")
	await _seconds(1.2)
	Input.action_release("move_up")
	await _frames(2)
	_expect(player.global_position.z < BLOCK_Z + 1.4 and player.global_position.z > BLOCK_Z - 1.4,
			"crouch-walk did not carry him under the slab: z %.2f" % player.global_position.z)
	_expect(not player.can_stand(), "the slab is not read as blocking a stand")
	Input.action_release("crouch")
	await _seconds(0.2)
	_expect(player.state == player.State.CROUCH,
			"stood up under the 1.3 m slab into %s" % player.State.keys()[player.state])
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	_expect(player.state == player.State.AIR, "crouch-jump under the slab gave %s" % player.State.keys()[player.state])
	_expect(absf(player.collider.shape.height - 1.2) < 0.01, "the capsule stood up in the air under the slab")
	await _seconds(0.5)
	_expect(player.state == player.State.CROUCH,
			"landed under the slab in %s, expected CROUCH" % player.State.keys()[player.state])
	Input.action_press("move_down")
	await _seconds(1.5)
	Input.action_release("move_down")
	_expect(player.state == player.State.WALK,
			"still %s after backing out from under the slab" % player.State.keys()[player.state])


## CLAMBER ignores every input, interact included; once it ends the same
## interact key works the door.
func _check_clamber_lockout() -> void:
	await _place(_before_block(4))
	door.close()
	await _frames(2)
	_expect(door.in_reach(), "the course door is not in reach of the clamber start")
	_expect(player.can_interact(), "cannot interact while standing still")
	Input.action_press("move_up")
	Input.action_press("jump")
	await _frames(2)
	_expect(player.state == player.State.CLAMBER, "no clamber at the 1.1 m block")
	var mid := player.global_position
	Input.action_release("jump")
	Input.action_release("move_up")
	Input.action_press("move_left")
	Input.action_press("interact")
	await _frames(1)
	Input.action_release("interact")
	await _frames(3)
	_expect(not player.can_interact(), "can interact mid-clamber")
	_expect(not door.is_open, "interact opened the door mid-clamber")
	var rounds: int = player.ammo
	_expect(player.fire() == null, "the trigger fired mid-clamber")
	_expect(player.ammo == rounds, "a clamber pull spent a round")
	_expect(player.state == player.State.CLAMBER, "input broke the clamber: %s" % player.State.keys()[player.state])
	_expect(absf(player.global_position.x - mid.x) < 0.01,
			"strafe input moved him %.2f m sideways during a clamber" % (player.global_position.x - mid.x))
	Input.action_release("move_left")
	await _seconds(0.6)
	_expect(player.state == player.State.WALK, "clamber ended in %s" % player.State.keys()[player.state])
	_expect(door.in_reach(), "the clamber carried him out of the door's reach")
	Input.action_press("interact")
	await _frames(1)
	Input.action_release("interact")
	await _frames(3)
	_expect(door.is_open, "interact after the clamber did not open the door")


## --- the Pistol ---

func _pull_trigger(frames_held: int = 1) -> void:
	Input.action_press("shoot")
	await _frames(frames_held)
	Input.action_release("shoot")


## Pulls the trigger directly and drops the shot; true if one went off.
func _fire_and_drop() -> bool:
	var shot: Projectile3D = player.fire()
	if shot != null:
		shot.queue_free()
	return shot != null


## The running reload must last its whole duration, then refill the magazine.
func _check_reload_lasts(seconds: float, label: String) -> void:
	await _seconds(seconds - 0.1)
	_expect(player.is_reloading(), "the %s reload finished under %.1f s" % [label, seconds])
	await _seconds(0.2)
	_expect(not player.is_reloading(), "the %s reload ran past %.1f s" % [label, seconds])
	_expect(player.ammo == player.weapon.magazine_size, "the %s reload left %d rounds" % [label, player.ammo])


## One shot per press: a held trigger never repeats, and a second press
## inside the minimum interval is swallowed.
func _check_semi_auto() -> void:
	await _place(RUNWAY)
	var profile: WeaponProfile = player.weapon
	_expect(profile.magazine_size == 12, "the Pistol holds %d rounds, expected 12" % profile.magazine_size)
	_expect(player.ammo == 12, "the pirate started with %d rounds" % player.ammo)
	await _pull_trigger(60)
	await _frames(2)
	_expect(shots_fired == 1, "holding the trigger for 1 s fired %d shots, expected 1" % shots_fired)
	_expect(player.ammo == 11, "one shot left %d rounds" % player.ammo)
	await _seconds(0.3)
	shots_fired = 0
	await _pull_trigger(1)
	await _frames(2)
	await _pull_trigger(1)
	await _frames(2)
	_expect(shots_fired == 1, "two presses 0.05 s apart fired %d shots, expected 1" % shots_fired)
	await _seconds(0.3)
	shots_fired = 0
	await _pull_trigger(1)
	await _seconds(0.15)
	await _pull_trigger(1)
	await _frames(2)
	_expect(shots_fired == 2, "two presses 0.15 s apart fired %d shots, expected 2" % shots_fired)
	var shot: Projectile3D = player.fire()
	_expect(shot == null, "a pull inside the 0.12 s interval fired")
	await _seconds(0.2)
	shot = player.fire()
	_expect(shot != null, "a pull after the interval did not fire")
	if shot != null:
		_expect(is_equal_approx(shot.speed, profile.projectile_speed),
				"shot flies at %.1f m/s, profile says %.1f" % [shot.speed, profile.projectile_speed])
		_expect(is_equal_approx(shot.lifetime, profile.projectile_lifetime),
				"shot lives %.2f s, profile says %.2f" % [shot.lifetime, profile.projectile_lifetime])
		_expect(shot.damage == profile.damage, "shot does %d damage, profile says %d" % [shot.damage, profile.damage])
		shot.queue_free()
	_clear_shots()


## The last round does not reload; the next pull does, at the empty
## duration, while a partial magazine reloads at the tactical one.
func _check_dry_reload() -> void:
	await _place(RUNWAY)
	var profile: WeaponProfile = player.weapon
	for i in profile.magazine_size:
		_expect(_fire_and_drop(), "round %d of the magazine did not fire" % (i + 1))
		await _seconds(0.13)
	_expect(player.ammo == 0, "%d rounds left after emptying the magazine" % player.ammo)
	_expect(not player.is_reloading(), "the last round started a reload by itself")
	_expect(reloads_started.is_empty(), "reload_started fired on the last round")
	var dry: Projectile3D = player.fire()
	_expect(dry == null, "a dry magazine fired")
	_expect(player.is_reloading(), "the pull on a dry magazine did not start the reload")
	_expect(reloads_started == [true], "dry reload signalled %s, expected [from_empty=true]" % [reloads_started])
	await _check_reload_lasts(profile.reload_empty, "empty")

	_fire_and_drop()
	reloads_started.clear()
	Input.action_press("reload")
	await _frames(1)
	Input.action_release("reload")
	# A press lands on the frame after it is made, so give the key a beat.
	await _frames(2)
	_expect(player.is_reloading(), "R did not start a tactical reload")
	_expect(reloads_started == [false], "tactical reload signalled %s, expected [from_empty=false]" % [reloads_started])
	await _check_reload_lasts(profile.reload_tactical, "tactical")

	# A cancelled reload gains nothing and says so: the hook a melee uses.
	_fire_and_drop()
	await _frames(1)
	player.start_reload()
	_expect(player.is_reloading(), "reload did not start before the cancel")
	player.cancel_reload()
	_expect(not player.is_reloading(), "cancel_reload left the reload running")
	_expect(reloads_cancelled == 1, "reload_cancelled fired %d times, expected 1" % reloads_cancelled)
	_expect(player.ammo == profile.magazine_size - 1, "a cancelled reload changed the magazine to %d" % player.ammo)
	_clear_shots()


## A reload keeps running through a sprint and a slide.
func _check_reload_carries() -> void:
	await _place(RUNWAY)
	_fire_and_drop()
	await _frames(1)
	player.start_reload()
	_expect(player.is_reloading(), "reload did not start")
	await _sprint_up()
	_expect(player.is_reloading(), "sprinting stopped the reload")
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE, "crouch out of the sprint gave %s" % player.State.keys()[player.state])
	_expect(player.is_reloading(), "sliding stopped the reload")
	await _seconds(0.8)
	_expect(not player.is_reloading(), "the reload never finished across the moves")
	_expect(player.ammo == player.weapon.magazine_size, "the carried reload left %d rounds" % player.ammo)
	_expect(reloads_cancelled == 0, "a move cancelled the reload")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_up")
	_clear_shots()


## Spread per state at zero bloom, and one shot's bloom decaying to nothing.
func _check_spread() -> void:
	await _place(RUNWAY)
	await _frames(2)
	_expect(is_equal_approx(player.spread_degrees(), 1.0),
			"standing still spread is %.2f deg, expected 1.0" % player.spread_degrees())
	Input.action_press("crouch")
	await _frames(3)
	_expect(player.state == player.State.CROUCH, "crouch gave %s" % player.State.keys()[player.state])
	_expect(is_equal_approx(player.spread_degrees(), 0.7),
			"crouched spread is %.2f deg, expected 0.7" % player.spread_degrees())
	Input.action_release("crouch")
	await _frames(3)
	Input.action_press("move_up")
	await _seconds(0.3)
	_expect(is_equal_approx(player.spread_degrees(), 1.2),
			"walking spread is %.2f deg, expected 1.2" % player.spread_degrees())
	Input.action_press("sprint")
	await _seconds(0.3)
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE, "slide did not start: %s" % player.State.keys()[player.state])
	_expect(is_equal_approx(player.spread_degrees(), 1.5),
			"sliding spread is %.2f deg, expected 1.5" % player.spread_degrees())
	_expect(_fire_and_drop(), "a slide refused the trigger")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_up")

	await _place(RUNWAY)
	await _frames(2)
	var spreads: Array[float] = []
	player.spread_changed.connect(func(deg: float) -> void: spreads.append(deg))
	_fire_and_drop()
	_expect(is_equal_approx(player.spread_degrees(), 1.5),
			"one shot took still spread to %.2f deg, expected 1.5" % player.spread_degrees())
	await _seconds(0.15)
	_expect(player.spread_degrees() < 1.3 and player.spread_degrees() > 1.1,
			"bloom halfway through its decay reads %.2f deg" % player.spread_degrees())
	await _seconds(0.2)
	_expect(is_equal_approx(player.spread_degrees(), 1.0),
			"bloom did not decay back to base within 0.3 s: %.2f deg" % player.spread_degrees())
	_expect(spreads.size() > 2 and spreads[0] > 1.4 and is_equal_approx(spreads[-1], 1.0),
			"spread_changed did not track the bloom: %s" % [spreads])

	# A jump lands in AIR: x1.5, the same as a slide.
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_expect(player.state == player.State.AIR, "jump gave %s" % player.State.keys()[player.state])
	_expect(is_equal_approx(player.spread_degrees(), 1.5),
			"airborne spread is %.2f deg, expected 1.5" % player.spread_degrees())
	await _seconds(1.0)
	_clear_shots()


## A different .tres changes the numbers with no code change.
func _check_profile_swap() -> void:
	var pistol: WeaponProfile = player.weapon
	player.weapon = HEAVY_PISTOL
	await _place(RUNWAY)
	_expect(player.ammo == HEAVY_PISTOL.magazine_size,
			"the heavy pistol loaded %d rounds, its profile says %d" % [player.ammo, HEAVY_PISTOL.magazine_size])
	var shot: Projectile3D = player.fire()
	_expect(shot != null, "the heavy pistol did not fire")
	if shot != null:
		_expect(shot.damage == HEAVY_PISTOL.damage, "heavy pistol shot does %d damage, profile says %d" % [shot.damage, HEAVY_PISTOL.damage])
		_expect(is_equal_approx(shot.speed, HEAVY_PISTOL.projectile_speed), "heavy pistol shot flies at %.1f m/s" % shot.speed)
		shot.queue_free()
	await _seconds(0.2)
	_expect(player.fire() == null, "the heavy pistol fired again inside its %.2f s interval" % HEAVY_PISTOL.fire_interval)
	await _seconds(HEAVY_PISTOL.fire_interval)
	_expect(_fire_and_drop(), "the heavy pistol would not fire after its interval")
	_expect(is_equal_approx(player.spread_degrees(),
			(HEAVY_PISTOL.spread_base_degrees + HEAVY_PISTOL.bloom_per_shot_degrees) * HEAVY_PISTOL.spread_still),
			"heavy pistol spread after a shot is %.2f deg" % player.spread_degrees())
	player.weapon = pistol
	_clear_shots()


func _clear_shots() -> void:
	for node in world.get_children():
		if node is Projectile3D:
			node.free()


## --- the weapon wheel ---

func _wheel(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)


## The wheel turns Pistol, Assault Rifle, Shotgun, Marksman Rifle and back
## round, either way, and each keeps the rounds it had.
func _check_weapon_wheel() -> void:
	var pistol: WeaponProfile = player.weapon
	await _place(RUNWAY)
	_expect(player.weapons == [pistol, ASSAULT_RIFLE, SHOTGUN, MARKSMAN_RIFLE],
			"he does not carry the Pistol, the Assault Rifle, the Shotgun and the Marksman Rifle in that order")
	_expect(_fire_and_drop(), "no shot from the Pistol before the swap")
	await _wheel(&"weapon_next")
	_expect(player.weapon == ASSAULT_RIFLE, "wheel down did not bring up the Assault Rifle")
	_expect(player.ammo == ASSAULT_RIFLE.magazine_size, "the Assault Rifle came up with %d rounds, not a full %d" % [player.ammo, ASSAULT_RIFLE.magazine_size])
	await _seconds(player.weapon.swap_time + 0.05)
	_expect(_fire_and_drop(), "no shot from the Assault Rifle after the swap")
	await _wheel(&"weapon_next")
	_expect(player.weapon == SHOTGUN, "a second turn did not bring up the Shotgun")
	_expect(player.ammo == SHOTGUN.magazine_size, "the Shotgun came up with %d shells, not a full %d" % [player.ammo, SHOTGUN.magazine_size])
	await _wheel(&"weapon_next")
	_expect(player.weapon == MARKSMAN_RIFLE, "a third turn did not bring up the Marksman Rifle")
	_expect(player.ammo == MARKSMAN_RIFLE.magazine_size, "the Marksman Rifle came up with %d rounds, not a full %d" % [player.ammo, MARKSMAN_RIFLE.magazine_size])
	await _wheel(&"weapon_next")
	_expect(player.weapon == pistol, "a fourth turn did not come back to the Pistol")
	_expect(player.ammo == pistol.magazine_size - 1, "the Pistol came back with %d rounds, it was stowed with %d" % [player.ammo, pistol.magazine_size - 1])
	await _wheel(&"weapon_prev")
	_expect(player.weapon == MARKSMAN_RIFLE, "wheel up did not bring up the Marksman Rifle")
	await _wheel(&"weapon_prev")
	_expect(player.weapon == SHOTGUN, "wheel up twice did not bring up the Shotgun")
	await _wheel(&"weapon_prev")
	_expect(player.weapon == ASSAULT_RIFLE, "wheel up three times did not bring up the Assault Rifle")
	_expect(player.ammo == ASSAULT_RIFLE.magazine_size - 1, "the Assault Rifle came back with %d rounds, it was stowed with %d" % [player.ammo, ASSAULT_RIFLE.magazine_size - 1])
	await _wheel(&"weapon_prev")
	_expect(player.weapon == pistol, "the wheel did not end on the Pistol")
	await _place(RUNWAY)
	_expect(player.weapon == pistol and player.ammo == pistol.magazine_size, "a respawn did not leave him a full Pistol")
	player.switch_weapon(1)
	_expect(player.ammo == ASSAULT_RIFLE.magazine_size, "a respawn did not refill the stowed Assault Rifle")
	player.switch_weapon(-1)
	await _place(RUNWAY)


## A swap holds the trigger and the sights for its time, and drops a reload.
func _check_swap_is_busy() -> void:
	var pistol: WeaponProfile = player.weapon
	await _place(RUNWAY)
	_expect(_fire_and_drop(), "no shot to start a reload from")
	await _seconds(pistol.fire_interval + 0.05)
	player.start_reload()
	_expect(player.is_reloading(), "no reload to swap out of")
	await _aim(true)
	player.switch_weapon(1)
	_expect(not player.is_reloading(), "the swap did not drop the reload")
	_expect(player.is_swapping(), "the swap is not busy")
	_expect(player.fire() == null, "a shot went off mid-swap")
	await _frames(3)
	_expect(not player.ads, "the sights came up mid-swap")
	await _seconds(player.weapon.swap_time + 0.1)
	_expect(not player.is_swapping(), "the swap outlasted its %.1f s" % player.weapon.swap_time)
	_expect(player.ads, "held aim did not come back after the swap")
	_expect(_fire_and_drop(), "no shot after the swap")
	await _aim(false)
	player.switch_weapon(-1)
	_expect(player.ammo == pistol.magazine_size - 1, "the dropped reload still filled the Pistol")
	await _place(RUNWAY)


## Keys 1 to 4 pick the Pistol, Assault Rifle, Shotgun and Marksman Rifle
## directly, each through the same swap as the wheel: it takes the swap
## time and is refused mid-swing. The key of the weapon in hand does nothing.
func _check_weapon_keys() -> void:
	var pistol: WeaponProfile = player.weapon
	await _place(RUNWAY)
	var wanted := [pistol, ASSAULT_RIFLE, SHOTGUN, MARKSMAN_RIFLE]
	for i in 4:
		var action := StringName("weapon_%d" % (i + 1))
		var bound := InputMap.has_action(action) and InputMap.action_get_events(action).any(
				func(e: InputEvent) -> bool: return e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_1 + i)
		_expect(bound, "no %s action on the %d key" % [action, i + 1])
	if not InputMap.has_action(&"weapon_1"):
		return
	await _wheel(&"weapon_1")
	_expect(player.weapon == pistol and not player.is_swapping(), "the Pistol's key swapped the Pistol in hand")
	for i in [3, 1, 2, 0]:
		await _wheel(StringName("weapon_%d" % (i + 1)))
		_expect(player.weapon == wanted[i], "key %d brought up %s" % [i + 1, player.weapon.resource_path.get_file()])
		_expect(player.is_swapping() and player.fire() == null, "the swap to key %d was not busy" % (i + 1))
		await _seconds(player.weapon.swap_time - 0.1)
		_expect(player.is_swapping(), "the swap to key %d ended before %.1f s" % [i + 1, player.weapon.swap_time])
		await _seconds(0.15)
		_expect(not player.is_swapping(), "the swap to key %d outlasted %.1f s" % [i + 1, player.weapon.swap_time])
	await _dummy(100, 6.0)
	await _swing()
	await _wheel(&"weapon_4")
	_expect(player.weapon == pistol, "a key swapped weapons mid-swing")
	await _cycle()
	await _clear_dummy()
	await _place(RUNWAY)

## The Assault Rifle is fully automatic: a held trigger keeps firing at its
## interval, where the Pistol fires once.
func _check_assault_rifle_full_auto() -> void:
	var pistol: WeaponProfile = player.weapon
	await _place(RUNWAY)
	player.switch_weapon(1)
	await _seconds(player.weapon.swap_time + 0.05)
	_expect(not ASSAULT_RIFLE.semi_auto, "the Assault Rifle's Profile is semi-automatic")
	shots_fired = 0
	Input.action_press("shoot")
	await _seconds(1.0)
	Input.action_release("shoot")
	var wanted := int(1.0 / ASSAULT_RIFLE.fire_interval)
	_expect(absi(shots_fired - wanted) <= 2, "a second of held trigger fired %d shots, about %d expected" % [shots_fired, wanted])
	_expect(player.ammo == ASSAULT_RIFLE.magazine_size - shots_fired, "the Assault Rifle spent %d rounds on %d shots" % [ASSAULT_RIFLE.magazine_size - player.ammo, shots_fired])
	await _frames(2)
	_clear_shots()
	player.switch_weapon(-1)
	_expect(player.weapon == pistol, "the wheel did not end on the Pistol")
	await _place(RUNWAY)


## The Viewmodel swaps the mesh: the Assault Rifle's own clips, muzzle and sights,
## its front sight on the camera axis in ADS, and the pistol back afterwards.
func _check_assault_rifle_model() -> void:
	var pistol: WeaponProfile = player.weapon
	await _place(RUNWAY)
	var pistol_clips: AnimationPlayer = weapon.model_clips
	var pistol_muzzle: Vector3 = player.muzzle.position
	player.switch_weapon(1)
	await _seconds(player.weapon.swap_time + 0.3)
	var anim: AnimationPlayer = weapon.model_clips
	_expect(anim != null and anim != pistol_clips, "the Assault Rifle did not bring its own clips")
	if anim != null:
		for clip_name in [ASSAULT_RIFLE.model_fire_clip, ASSAULT_RIFLE.model_reload_clip, ASSAULT_RIFLE.model_rack_clip]:
			_expect(anim.has_animation(clip_name), "the Assault Rifle mesh lacks the %s clip" % clip_name)
	_expect(player.muzzle.position.z > pistol_muzzle.z + 0.2, "the Assault Rifle's muzzle is at %s, no further out than the pistol's" % player.muzzle.position)
	_at_pose(ASSAULT_RIFLE.pose_hip, "Assault Rifle at the hip")
	var shown := 0
	for model in weapon.holder.get_children():
		if (model as Node3D).visible:
			shown += 1
	_expect(shown == 1, "%d weapon meshes are showing" % shown)
	_expect(_fire_and_drop(), "no shot for the Assault Rifle fire clip")
	await _frames(1)
	_expect(anim.current_animation == ASSAULT_RIFLE.model_fire_clip and anim.is_playing(), "a shot played %s on the Assault Rifle" % anim.current_animation)
	await _aim(true)
	await _seconds(0.5)
	var sight: Node3D = weapon.get_node("SightTip")
	var in_camera: Vector3 = player.camera.to_local(sight.global_position)
	_expect(absf(in_camera.x) < 0.005 and absf(in_camera.y) < 0.005,
			"in ADS the Assault Rifle's front sight sits at (%.3f, %.3f) m off the camera axis" % [in_camera.x, in_camera.y])
	_expect(in_camera.z < 0.0, "the Assault Rifle's front sight is behind the camera in ADS")
	# The rear ring sits on the same line, nearer the eye, so he looks
	# through it at the post.
	var rear: Node3D = weapon.holder.find_child("SightRear", true, false)
	_expect(rear != null, "the Assault Rifle mesh has no SightRear marker")
	if rear != null:
		var ring: Vector3 = player.camera.to_local(rear.global_position)
		_expect(absf(ring.x) < 0.003 and absf(ring.y) < 0.003,
				"in ADS the Assault Rifle's rear ring sits at (%.3f, %.3f) m off the camera axis" % [ring.x, ring.y])
		_expect(ring.z < -0.06 and ring.z > in_camera.z + 0.3,
				"the rear ring is %.2f m out and the post %.2f m: not a sight line to look down" % [-ring.z, -in_camera.z])
	# Braced in the shoulder: an aimed shot comes straight back, the muzzle
	# does not climb and the sights stay on the line.
	var rest_pitch: float = weapon.rotation_degrees.x
	var rest_z: float = weapon.position.z
	_expect(_fire_and_drop(), "no aimed shot from the Assault Rifle")
	var climb := 0.0
	var push := 0.0
	var drift := 0.0
	for i in 10:
		await physics_frame
		climb = maxf(climb, absf(weapon.rotation_degrees.x - rest_pitch))
		push = maxf(push, weapon.position.z - rest_z)
		var tip: Vector3 = player.camera.to_local(sight.global_position)
		drift = maxf(drift, Vector2(tip.x, tip.y).length())
	_expect(climb < 0.2, "an aimed Assault Rifle shot tipped the weapon %.1f deg" % climb)
	_expect(push > 0.01, "an aimed Assault Rifle shot pushed it back only %.3f m" % push)
	_expect(drift < 0.005, "an aimed Assault Rifle shot threw the front sight %.3f m off the line" % drift)
	await _aim(false)
	_clear_shots()
	player.switch_weapon(-1)
	await _seconds(player.weapon.swap_time + 0.3)
	_expect(player.weapon == pistol and weapon.model_clips == pistol_clips, "the pistol's mesh did not come back")
	_expect(player.muzzle.position.is_equal_approx(pistol_muzzle), "the muzzle did not go back to the pistol's")
	await _place(RUNWAY)



## The skeleton of the model showing in the holder.
func _mounted_skeleton() -> Skeleton3D:
	for model in weapon.holder.get_children():
		if (model as Node3D).visible:
			return model.find_child("Skeleton3D", true, false)
	return null


## How far [param bone] on the mounted model's skeleton sits from its rest.
func _bone_offset(bone: String) -> float:
	var skeleton := _mounted_skeleton()
	var i := skeleton.find_bone(bone)
	return (skeleton.get_bone_pose_position(i) - skeleton.get_bone_rest(i).origin).length()


## The Shotgun's rig: the fore-end racks 7.5 cm after every shot, starting
## 0.15 s in and back by 0.55 s, with the pump sound 0.2 s after the shot.
## Each shell loaded plays the shell clip and the shell sound once, the
## sound with the counter; a reload from empty ends with the pump clip and
## sound, a top-up does not; a shot breaking in stops the clip and puts the
## bones back at rest.
func _check_shotgun_rig() -> void:
	# Read through variables: the Profile is a constant, and a field still
	# blank would not parse.
	var pump_sound: AudioStream = SHOTGUN.action_sound
	var shell_sound: AudioStream = SHOTGUN.reload_sounds[0] if not SHOTGUN.reload_sounds.is_empty() else null
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	var anim: AnimationPlayer = weapon.model_clips
	var skeleton := _mounted_skeleton()
	for bone in ["Pump", "Shell"]:
		_expect(skeleton != null and skeleton.find_bone(bone) >= 0, "the Shotgun's skeleton has no %s bone" % bone)
	for clip_name in [SHOTGUN.model_fire_clip, SHOTGUN.model_reload_clip, SHOTGUN.model_rack_clip]:
		_expect(clip_name != &"" and anim.has_animation(clip_name), "the Shotgun mesh lacks the '%s' clip" % clip_name)
	if skeleton == null or skeleton.find_bone("Pump") < 0 or not anim.has_animation(SHOTGUN.model_rack_clip) \
			or not anim.has_animation(SHOTGUN.model_reload_clip):
		await _hold(player.weapons[0])
		return
	_expect(is_equal_approx(anim.get_animation(SHOTGUN.model_fire_clip).length, 0.55)
			and is_equal_approx(SHOTGUN.fire_cycle_time, 0.55),
			"the Shotgun's pump clip is %.2f s played over %.2f s, not 0.55" % [anim.get_animation(SHOTGUN.model_fire_clip).length, SHOTGUN.fire_cycle_time])
	_expect(pump_sound != null and pump_sound.resource_path.ends_with("shotgun_pump.ogg")
			and is_equal_approx(SHOTGUN.action_sound_delay, 0.2),
			"the Shotgun's action sound is %s after %.2f s, not the pump after 0.2 s" % [pump_sound, SHOTGUN.action_sound_delay])

	# The pump after a shot.
	sounds.clear()
	_expect(_fire_and_drop(), "no Shotgun shot for the pump")
	await _seconds(0.1)
	_expect(_bone_offset("Pump") < 0.003, "the fore-end moved %.3f m before 0.15 s" % _bone_offset("Pump"))
	_expect(not sounds.any(func(s: Array) -> bool: return s[0] == &"action"), "the pump sounded before 0.2 s")
	await _seconds(0.2)
	_expect(absf(_bone_offset("Pump") - 0.075) < 0.006, "0.3 s after the shot the fore-end is %.3f m back, not 0.075" % _bone_offset("Pump"))
	var pumps := sounds.filter(func(s: Array) -> bool: return s[0] == &"action")
	_expect(pumps.size() == 1 and pumps[0][1] == pump_sound, "the pump after the shot sounded %s" % [sounds])
	await _seconds(0.3)
	_expect(_bone_offset("Pump") < 0.003 and not anim.is_playing(), "0.6 s after the shot the fore-end is still %.3f m back" % _bone_offset("Pump"))
	_clear_shots()

	# Empty to full: one shell clip and one shell sound per shell, then the pump.
	var started: Array = []
	var on_clip := func(clip: StringName) -> void: started.append(clip)
	anim.animation_started.connect(on_clip)
	var out_of_step: Array = []
	var on_shell := func() -> void:
		var shell_sounds := sounds.filter(func(s: Array) -> bool: return s[0] == &"shell_in").size()
		if shell_sounds != player.ammo:
			out_of_step.append([player.ammo, shell_sounds])
	player.shell_loaded.connect(on_shell)
	sounds.clear()
	player.ammo = 0
	player.start_reload()
	await _frames(1)
	_expect(anim.current_animation == SHOTGUN.model_reload_clip, "loading the first shell plays '%s'" % anim.current_animation)
	await _seconds(SHOTGUN.seconds_empty_to_full() + 0.2)
	_expect(player.ammo == 6 and not player.is_reloading(), "the Shotgun did not fill from empty (%d)" % player.ammo)
	var shells := started.count(SHOTGUN.model_reload_clip)
	_expect(shells == 6, "six shells played the shell clip %d times" % shells)
	_expect(started.back() == SHOTGUN.model_rack_clip and started.count(SHOTGUN.model_rack_clip) == 1,
			"a reload from empty did not end on one pump clip: %s" % [started])
	var shell_in := sounds.filter(func(s: Array) -> bool: return s[0] == &"shell_in")
	_expect(shell_in.size() == 6 and shell_in.all(func(s: Array) -> bool: return s[1] == shell_sound),
			"six shells sounded %d shell sounds" % shell_in.size())
	_expect(shell_sound != null and shell_sound.resource_path.ends_with("shell_in.ogg"), "the Shotgun's shell sound is %s" % shell_sound)
	_expect(out_of_step.is_empty(), "the shell sound fell out of step with the counter: [shells, sounds] %s" % [out_of_step])
	var closing := sounds.filter(func(s: Array) -> bool: return s[0] == &"pump")
	_expect(closing.size() == 1 and closing[0][1] == pump_sound, "the closing pump sounded %s" % [closing])
	_expect(_bone_offset("Pump") < 0.003 and _bone_offset("Shell") < 0.003, "the bones did not come to rest after the reload")

	# A top-up from 4: two shells, no pump.
	started.clear()
	sounds.clear()
	player.ammo = 4
	player.start_reload()
	await _seconds(SHOTGUN.first_shell_time + SHOTGUN.shell_time + 0.2)
	_expect(player.ammo == 6 and not player.is_reloading(), "the top-up from 4 left %d shells" % player.ammo)
	_expect(started.count(SHOTGUN.model_reload_clip) == 2 and not started.has(SHOTGUN.model_rack_clip),
			"a top-up of two played %s" % [started])
	_expect(sounds.filter(func(s: Array) -> bool: return s[0] == &"shell_in").size() == 2
			and not sounds.any(func(s: Array) -> bool: return s[0] == &"pump"),
			"a top-up of two sounded %s" % [sounds])

	# A shot breaking in stops the shell clip with the bones at rest.
	player.ammo = 1
	player.start_reload()
	await _seconds(SHOTGUN.first_shell_time + 0.2)
	_expect(anim.current_animation == SHOTGUN.model_reload_clip and _bone_offset("Shell") > 0.003,
			"the second shell is not on its way in (%s)" % anim.current_animation)
	player.fire()
	await _frames(1)
	_expect(not anim.is_playing() and _bone_offset("Shell") < 0.001 and _bone_offset("Pump") < 0.001,
			"a shot breaking in left '%s' playing, the shell %.3f m out" % [anim.current_animation, _bone_offset("Shell")])
	await _seconds(SHOTGUN.break_out_time + 0.05)
	_expect(anim.current_animation == SHOTGUN.model_fire_clip, "the break-out shot played '%s'" % anim.current_animation)
	await _seconds(0.6)

	anim.animation_started.disconnect(on_clip)
	player.shell_loaded.disconnect(on_shell)
	_clear_shots()
	await _hold(player.weapons[0])
	await _place(RUNWAY)

## --- the Marksman Rifle ---

## The Marksman Rifle comes up as the black bullpup at its picked poses,
## with its own clips, its own shot sound and 3x over sights that line up.
func _check_marksman_rifle_model() -> void:
	await _place(RUNWAY)
	var pistol_clips: AnimationPlayer = weapon.model_clips
	var hip_fov: float = player.camera.fov
	await _hold(MARKSMAN_RIFLE)
	var anim: AnimationPlayer = weapon.model_clips
	_expect(anim != null and anim != pistol_clips, "the Marksman Rifle did not bring its own clips")
	if anim != null:
		for clip_name in [MARKSMAN_RIFLE.model_fire_clip, MARKSMAN_RIFLE.model_reload_clip, MARKSMAN_RIFLE.model_rack_clip]:
			_expect(anim.has_animation(clip_name), "the Marksman Rifle mesh lacks the %s clip" % clip_name)
	var bones := _mounted_skeleton()
	for bone in ["Bolt", "Magazine"]:
		_expect(bones != null and bones.find_bone(bone) >= 0, "the mounted Marksman Rifle has no %s bone" % bone)
	var shown := 0
	for model in weapon.holder.get_children():
		if (model as Node3D).visible:
			shown += 1
	_expect(shown == 1, "%d weapon meshes are showing" % shown)
	_expect(MARKSMAN_RIFLE.pose_hip.is_equal_approx(Vector3(0.15, -0.2, -0.36)) and is_equal_approx(MARKSMAN_RIFLE.ads_distance, 0.36),
			"the Marksman Rifle's hip pose is %s and aimed distance %.2f, not the picked (0.15, -0.2, -0.36) and 0.36" % [MARKSMAN_RIFLE.pose_hip, MARKSMAN_RIFLE.ads_distance])
	_expect(MARKSMAN_RIFLE.pose_low.y < MARKSMAN_RIFLE.pose_hip.y - 0.08, "the Marksman Rifle's lowered pose %s is not clearly below its hip pose" % MARKSMAN_RIFLE.pose_low)
	_at_pose(MARKSMAN_RIFLE.pose_hip, "Marksman Rifle at the hip")
	sounds.clear()
	_expect(_fire_and_drop(), "no Marksman Rifle shot")
	var shot_streams := sounds.filter(func(s: Array) -> bool: return s[0] == &"shot")
	_expect(shot_streams.size() == 1 and (shot_streams[0][1] as AudioStream).resource_path.contains("firearm_library_marksman/shot"),
			"a Marksman Rifle shot sounded %s, not its own shot" % [sounds])
	_expect(is_equal_approx(MARKSMAN_RIFLE.loudness, 24.0), "the Marksman Rifle is %.1f m loud, not 24" % MARKSMAN_RIFLE.loudness)
	_expect(player.fire() == null, "the Marksman Rifle fired again inside its 0.4 s")
	await _seconds(0.45)
	_expect(_fire_and_drop(), "the Marksman Rifle did not fire again after 0.4 s")
	await _aim(true)
	await _seconds(0.5)
	var zoomed_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(hip_fov) / 2.0) / 3.0))
	_expect(absf(player.camera.fov - zoomed_fov) < 0.5, "the Marksman Rifle's aimed FOV is %.1f, not %.1f for 3x" % [player.camera.fov, zoomed_fov])
	var tip: Vector3 = player.camera.to_local((weapon.get_node("SightTip") as Node3D).global_position)
	_expect(absf(tip.x) < 0.005 and absf(tip.y) < 0.005 and tip.z < 0.0,
			"in ADS the Marksman Rifle's front sight sits at (%.3f, %.3f) m off the camera axis" % [tip.x, tip.y])
	# The holder keeps every model mounted so far: look in the one showing.
	var rear: Node3D = null
	for model in weapon.holder.get_children():
		if (model as Node3D).visible:
			rear = model.find_child("SightRear", true, false)
	_expect(rear != null, "the Marksman Rifle mesh has no SightRear marker")
	if rear != null:
		var ring: Vector3 = player.camera.to_local(rear.global_position)
		_expect(absf(ring.x) < 0.003 and absf(ring.y) < 0.003,
				"in ADS the Marksman Rifle's rear ring sits at (%.3f, %.3f) m off the camera axis" % [ring.x, ring.y])
		_expect(ring.z < -0.06 and ring.z > tip.z + 0.3,
				"the rear ring is %.2f m out and the post %.2f m: not a sight line to look down" % [-ring.z, -tip.z])
	await _aim(false)
	Input.action_press("move_up")
	Input.action_press("sprint")
	await _seconds(0.4)
	_expect(player.state == player.State.SPRINT, "no Sprint for the Marksman Rifle's lowered pose")
	_at_pose(MARKSMAN_RIFLE.pose_low, "Marksman Rifle lowered in a Sprint")
	Input.action_release("sprint")
	Input.action_release("move_up")
	_clear_shots()
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## The Marksman Rifle's rig: the bolt runs back and home on every shot; a
## reload drops the magazine out below the butt and seats a fresh one, with
## the magazine sound's two halves as it comes out and as it goes in; a
## reload from empty racks the bolt after.
func _check_marksman_rifle_rig() -> void:
	await _place(RUNWAY)
	await _hold(MARKSMAN_RIFLE)
	var anim: AnimationPlayer = weapon.model_clips
	var skeleton := _mounted_skeleton()
	if skeleton == null or skeleton.find_bone("Bolt") < 0 or skeleton.find_bone("Magazine") < 0:
		_expect(false, "no Marksman Rifle skeleton to watch")
		await _hold(player.weapons[0])
		return
	var mag := skeleton.find_bone("Magazine")
	for shot in 2:
		_expect(_fire_and_drop(), "no Marksman Rifle shot %d for the bolt" % (shot + 1))
		var travel := 0.0
		for i in 12:
			await physics_frame
			travel = maxf(travel, _bone_offset("Bolt"))
		_expect(travel > 0.03, "shot %d moved the bolt %.3f m, not a cycle" % [shot + 1, travel])
		_expect(_bone_offset("Bolt") < 0.002, "after shot %d the bolt is still %.3f m back" % [shot + 1, _bone_offset("Bolt")])
		await _seconds(0.3)
	_clear_shots()

	var started: Array = []
	var on_clip := func(clip: StringName) -> void: started.append(clip)
	anim.animation_started.connect(on_clip)
	sounds.clear()
	player.start_reload()
	_expect(player.is_reloading(), "no Marksman Rifle reload")
	var lowest := 0.0
	for i in ceili(MARKSMAN_RIFLE.reload_tactical / FRAME) + 6:
		await physics_frame
		var at := skeleton.get_bone_global_pose(mag).origin - skeleton.get_bone_global_rest(mag).origin
		lowest = minf(lowest, at.y)
	_expect(lowest < -0.2, "the magazine dropped only %.3f m on a reload" % -lowest)
	_expect(not player.is_reloading() and player.ammo == 8, "the reload left %d rounds" % player.ammo)
	_expect(_bone_offset("Magazine") < 0.002, "the fresh magazine did not seat (%.3f m out)" % _bone_offset("Magazine"))
	var kinds := _sound_kinds()
	_expect(kinds.has(&"mag_out") and kinds.has(&"mag_in"), "the Marksman Rifle reload sounded %s" % [kinds])
	var reload_streams := sounds.filter(func(s: Array) -> bool: return s[0] == &"mag_out" or s[0] == &"mag_in").map(
			func(s: Array) -> String: return (s[1] as AudioStream).resource_path.get_file())
	_expect(reload_streams == ["rifle_magazine_out.ogg", "rifle_magazine_in.ogg"],
			"the Marksman Rifle reload played %s" % [reload_streams])
	started.clear()
	player.ammo = 0
	player.start_reload()
	await _seconds(MARKSMAN_RIFLE.reload_empty + 0.1)
	_expect(started == [MARKSMAN_RIFLE.model_reload_clip, MARKSMAN_RIFLE.model_rack_clip],
			"a reload from empty played %s, not the magazine then the rack" % [started])
	_expect(player.ammo == 8 and _bone_offset("Bolt") < 0.002 and _bone_offset("Magazine") < 0.002,
			"the reload from empty did not end full with the bones at rest")
	anim.animation_started.disconnect(on_clip)
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## The Marksman Rifle's cones: 3 degrees at the hip, pinpoint aimed and
## still or crouched, 1.2 degrees aimed and walking, and wide in the air.
func _check_marksman_rifle_cones() -> void:
	var cones: Dictionary = await _stance_cones(MARKSMAN_RIFLE)
	var wanted := {"hip still": 3.0, "hip walking": 4.5, "hip crouched": 2.4, "hip air": 6.0, "hip slide": 6.0,
			"aimed still": 0.05, "aimed walking": 1.2, "aimed crouched": 0.04, "aimed air": 0.1}
	for stance: String in wanted:
		_expect(absf(cones[stance] - wanted[stance]) < 0.001,
				"the Marksman Rifle's %s cone is %.3f deg, want %.3f" % [stance, cones[stance], wanted[stance]])


## Aimed and still, a Marksman Rifle shot strikes a wall 20 m off within a
## few centimetres of where the front sight sits; from the hip shots
## scatter across the 3 degree cone.
func _check_marksman_rifle_on_the_sight() -> void:
	const FAR := Vector3(60.0, 0.0, 25.0)
	var wall := _box("SightWall", Vector3(8.0, 3.0, 0.2), Vector3(FAR.x, 1.5, FAR.z - 20.1))
	await _place(FAR)
	await _hold(MARKSMAN_RIFLE)
	player.head.rotation.x = 0.0
	var aimed: Array[float] = await _misses_at_wall(FAR.z - 20.0, true)
	var hip: Array[float] = await _misses_at_wall(FAR.z - 20.0, false)
	_expect(aimed.size() == 8 and aimed.max() < 0.03,
			"aimed and still at 20 m, shots struck %s m from the front sight, want within 0.03" % [aimed])
	var scatter: float = hip.max() if not hip.is_empty() else 0.0
	_expect(hip.size() == 8 and scatter > 0.25 and scatter < 1.1,
			"from the hip at 20 m, shots struck %s m from the crosshair, want scattered over the 3 degree cone (up to 1.05)" % [hip])
	wall.free()
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## Eight shots at the wall standing at [param wall_z], each waited out, and
## how far each struck from where the crosshair (and in ADS the front sight)
## pointed the moment it fired.
func _misses_at_wall(wall_z: float, aimed: bool) -> Array[float]:
	if aimed:
		await _aim(true)
		await _seconds(0.5)
		var tip: Vector3 = player.camera.to_local((weapon.get_node("SightTip") as Node3D).global_position)
		_expect(Vector2(tip.x, tip.y).length() < 0.005, "the front sight is off the aim line for the 20 m check")
	var misses: Array[float] = []
	for i in 8:
		player.ammo = MARKSMAN_RIFLE.magazine_size
		var aim: Vector3 = player.aim_point()
		var shot: Projectile3D = player.fire()
		if shot == null:
			continue
		var t := (wall_z - shot.global_position.z) / shot.direction.z
		var struck := shot.global_position + shot.direction * t
		misses.append(snappedf(struck.distance_to(aim), 0.001))
		await _seconds(0.6)
		_clear_shots()
	if aimed:
		await _aim(false)
	return misses


## A hit while aimed drops the Marksman Rifle's sights like any gun's.
func _check_marksman_rifle_descopes() -> void:
	await _place(RUNWAY)
	await _hold(MARKSMAN_RIFLE)
	await _aim(true)
	await _seconds(0.3)
	_expect(player.ads, "no Marksman Rifle sights up to hit")
	descopes = 0
	player.take_damage(1)
	await _frames(1)
	_expect(not player.ads and descopes == 1, "a hit did not Descope the Marksman Rifle")
	await _seconds(0.4)
	_expect(player.ads, "the Marksman Rifle's sights did not come back with aim held")
	await _aim(false)
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## --- the Shotgun ---

## Angles in degrees between each pellet of the last shot and the line from
## where it started to the crosshair, read the moment it is fired.
func _pellet_angles() -> Array[float]:
	var angles: Array[float] = []
	for pellet: Projectile3D in player.last_pellets:
		var aim: Vector3 = (player.aim_point() - pellet.global_position).normalized()
		angles.append(rad_to_deg(aim.angle_to(pellet.direction)))
	return angles


## Round the wheel to [param profile], and the swap waited out.
func _hold(profile: WeaponProfile) -> void:
	player.switch_weapon(player.weapons.find(profile) - player.weapons.find(player.weapon))
	await _seconds(player.weapon.swap_time + 0.3)
	_expect(player.weapon == profile, "the wheel did not reach %s" % profile.resource_path.get_file())


## A Shotgun shot spends one shell and launches 12 pellets, each doing the
## Profile's damage, all inside the 5 degree cone and spread over its area,
## not bunched on the crosshair or pushed to the rim. A Slide does not widen
## it. The Pistol and Assault Rifle still fire one projectile.
func _check_shotgun_pellets() -> void:
	await _place(RUNWAY)
	_expect(_fire_and_drop(), "no Pistol shot to count")
	_expect(player.last_pellets.size() == 1, "a Pistol shot launched %d projectiles" % player.last_pellets.size())
	await _hold(ASSAULT_RIFLE)
	_expect(_fire_and_drop(), "no Assault Rifle shot to count")
	_expect(player.last_pellets.size() == 1, "an Assault Rifle shot launched %d projectiles" % player.last_pellets.size())
	_clear_shots()
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	_expect(SHOTGUN.pellet_count == 12 and SHOTGUN.damage == 13, "the Shotgun fires %d pellets of %d, not 12 of 13" % [SHOTGUN.pellet_count, SHOTGUN.damage])
	_expect(is_equal_approx(player.spread_degrees(), 5.0), "the Shotgun's cone stood still is %.2f deg, not 5" % player.spread_degrees())
	var angles: Array[float] = []
	for i in SHOTGUN.magazine_size:
		_expect(player.fire() != null, "Shotgun shot %d did not fire" % i)
		_expect(player.last_pellets.size() == 12, "a Shotgun shot launched %d pellets" % player.last_pellets.size())
		for pellet in player.last_pellets:
			_expect(pellet.damage == SHOTGUN.damage, "a pellet does %d damage, the Profile says %d" % [pellet.damage, SHOTGUN.damage])
		angles.append_array(_pellet_angles())
		_expect(player.ammo == SHOTGUN.magazine_size - 1 - i, "%d Shotgun shots left %d shells" % [i + 1, player.ammo])
		_expect(is_equal_approx(player.spread_degrees(), 5.0), "a Shotgun shot bloomed the cone to %.2f deg" % player.spread_degrees())
		await _frames(1)
		_clear_shots()
		await _seconds(SHOTGUN.fire_interval + 0.05)
	var widest: float = angles.max()
	var inner := angles.filter(func(a: float) -> bool: return a < 2.5).size() / float(angles.size())
	_expect(widest <= 5.01, "a pellet flew %.2f deg off the crosshair, outside the 5 deg cone" % widest)
	_expect(widest > 4.0, "no pellet of %d went past 4 deg: the cone is not filled" % angles.size())
	# Even over the area, a quarter land inside half the radius.
	_expect(inner > 0.1 and inner < 0.45, "%.0f%% of pellets landed inside half the cone, a quarter expected" % (inner * 100.0))

	# Sprint into a Slide and fire: the cone stays 5 degrees.
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	Input.action_press("move_up")
	Input.action_press("sprint")
	await _seconds(0.3)
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE, "no Slide for the Shotgun: %s" % player.State.keys()[player.state])
	_expect(is_equal_approx(player.spread_degrees(), 5.0), "the Shotgun's cone in a Slide is %.2f deg, not 5" % player.spread_degrees())
	_expect(player.fire() != null, "the Shotgun would not fire in a Slide")
	var slide_widest: float = _pellet_angles().max()
	_expect(slide_widest <= 5.01, "a pellet fired in a Slide flew %.2f deg off, wider than standing" % slide_widest)
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _frames(1)
	_clear_shots()
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## A Shotgun shot that kills reports one kill and flashes one marker with one
## tick, however many pellets land; one that only wounds reports one hit.
func _check_shotgun_hit_marker() -> void:
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	player.head.rotation.x = -0.05
	await _dummy(1000, 3.0)
	sounds.clear()
	hits_landed.clear()
	_expect(player.fire() != null, "no Shotgun shot for the wound")
	await _seconds(0.3)
	_expect(dummy.health.current < 1000 - 13 * 6, "the Shotgun shot at a dummy 3 m off did only %d damage" % (1000 - dummy.health.current))
	_expect(hits_landed == [[dummy, false]], "a wounding Shotgun shot reported %s, want one hit" % [hits_landed])
	_expect(_sounds_of(&"hitmark") == 1, "a wounding Shotgun shot played %d hit ticks" % _sounds_of(&"hitmark"))
	_clear_shots()
	await _seconds(SHOTGUN.fire_interval)

	await _dummy(100, 3.0)
	sounds.clear()
	hits_landed.clear()
	_expect(player.fire() != null, "no Shotgun shot for the kill")
	await _seconds(0.3)
	_expect(not dummy.health.is_alive(), "the Shotgun shot 3 m off left the dummy on %d" % dummy.health.current)
	_expect(hits_landed == [[dummy, true]], "a killing Shotgun shot reported %s, want one kill" % [hits_landed])
	_expect(hud.hitmarker_is_kill(), "a killing Shotgun shot did not show the kill marker")
	_expect(_sounds_of(&"hitmark") == 1, "a killing Shotgun shot played %d hit ticks" % _sounds_of(&"hitmark"))
	player.head.rotation.x = 0.0
	_clear_shots()
	await _clear_dummy()
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## The Shotgun mounts the pump-action model with the clips the Viewmodel
## plays, at its hip pose, its sights on the camera axis aimed, and a
## lowered pose well under the hip; until shells load one at a time it
## reloads like a magazine gun, in 2.4 s.
func _check_shotgun_model() -> void:
	await _place(RUNWAY)
	var pistol_clips: AnimationPlayer = weapon.model_clips
	await _hold(SHOTGUN)
	var anim: AnimationPlayer = weapon.model_clips
	_expect(anim != null and anim != pistol_clips, "the Shotgun did not bring its own clips")
	if anim != null:
		for clip_name in [SHOTGUN.model_fire_clip, SHOTGUN.model_reload_clip]:
			_expect(anim.has_animation(clip_name), "the Shotgun mesh lacks the %s clip" % clip_name)
	var bones := _mounted_skeleton()
	_expect(bones != null and bones.find_bone("Pump") >= 0, "the mounted Shotgun has no Pump bone: not the pump-action model")
	var shown := 0
	for model in weapon.holder.get_children():
		if (model as Node3D).visible:
			shown += 1
	_expect(shown == 1, "%d weapon meshes are showing" % shown)
	_expect(SHOTGUN.pose_hip.is_equal_approx(Vector3(0.15, -0.24, -0.34)) and is_equal_approx(SHOTGUN.ads_distance, 0.30),
			"the Shotgun's hip pose is %s and aimed distance %.2f, not the picked (0.15, -0.24, -0.34) and 0.30" % [SHOTGUN.pose_hip, SHOTGUN.ads_distance])
	_expect(SHOTGUN.pose_low.y < SHOTGUN.pose_hip.y - 0.08, "the Shotgun's lowered pose %s is not clearly below its hip pose" % SHOTGUN.pose_low)
	_at_pose(SHOTGUN.pose_hip, "Shotgun at the hip")
	sounds.clear()
	_expect(_fire_and_drop(), "no Shotgun shot for its fire clip")
	await _frames(1)
	_expect(anim.current_animation == SHOTGUN.model_fire_clip, "a Shotgun shot played %s on the model" % anim.current_animation)
	var shot_streams := sounds.filter(func(s: Array) -> bool: return s[0] == &"shot")
	_expect(shot_streams.size() == 1 and (shot_streams[0][1] as AudioStream).resource_path.contains("firearm_library_shotgun/shot"),
			"a Shotgun shot sounded %s, not its own shot" % [sounds])
	_expect(is_equal_approx(SHOTGUN.loudness, 32.0), "the Shotgun is %.1f m loud, not 32" % SHOTGUN.loudness)
	await _aim(true)
	await _seconds(0.5)
	var tip: Vector3 = player.camera.to_local((weapon.get_node("SightTip") as Node3D).global_position)
	_expect(absf(tip.x) < 0.005 and absf(tip.y) < 0.005 and tip.z < 0.0,
			"in ADS the Shotgun's front sight sits at (%.3f, %.3f) m off the camera axis" % [tip.x, tip.y])
	await _aim(false)
	Input.action_press("move_up")
	Input.action_press("sprint")
	await _seconds(0.4)
	_expect(player.state == player.State.SPRINT, "no Sprint for the Shotgun's lowered pose")
	_at_pose(SHOTGUN.pose_low, "Shotgun lowered in a Sprint")
	Input.action_release("sprint")
	Input.action_release("move_up")
	_clear_shots()
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## The Shotgun loads one shell at a time: one tap fills it, each shell counts
## when its time is up, the closing pump runs only from empty and a shot
## cannot break it, and a shot, a Melee or a swap breaks the reload keeping
## the shells already in. A shot that breaks in fires by itself after the
## break-out time. A Sprint does not break it. The Pistol still loses
## everything on an interrupted reload.
func _check_shell_reload() -> void:
	_expect(SHOTGUN.shell_reload and not player.weapons[0].shell_reload and not ASSAULT_RIFLE.shell_reload,
			"only the Shotgun should load shell by shell")
	_expect(is_equal_approx(SHOTGUN.first_shell_time, 0.55) and is_equal_approx(SHOTGUN.shell_time, 0.45)
			and is_equal_approx(SHOTGUN.closing_pump_time, 0.45) and is_equal_approx(SHOTGUN.break_out_time, 0.25),
			"the Shotgun's shell times are %.2f / %.2f / %.2f / %.2f, not 0.55 / 0.45 / 0.45 / 0.25"
			% [SHOTGUN.first_shell_time, SHOTGUN.shell_time, SHOTGUN.closing_pump_time, SHOTGUN.break_out_time])
	_expect(is_equal_approx(SHOTGUN.seconds_empty_to_full(), 3.25),
			"the Shotgun fills from empty in %.2f s, not 3.25" % SHOTGUN.seconds_empty_to_full())
	var shells := [0]
	var pumps := [0]
	var ended: Array = []
	var started: Array = []
	var on_shell := func() -> void: shells[0] += 1
	var on_pump := func() -> void: pumps[0] += 1
	var on_end := func(broken: bool) -> void: ended.append(broken)
	var on_start := func(from_empty: bool) -> void: started.append(from_empty)
	player.shell_loaded.connect(on_shell)
	player.closing_pump_started.connect(on_pump)
	player.shell_reload_ended.connect(on_end)
	player.shell_reload_started.connect(on_start)

	# Empty to full: a dry pull starts it, six shells, a closing pump, 3.25 s.
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	player.ammo = 0
	player.ammo_changed.emit(0)
	reloads_started.clear()
	_expect(player.fire() == null, "a dry Shotgun fired")
	_expect(player.is_reloading(), "a dry Shotgun pull did not start the reload")
	_expect(started == [true], "the shell reload signalled %s, expected [from_empty=true]" % [started])
	_expect(reloads_started.is_empty(), "the shell reload sent the magazine reload_started")
	_expect(hud.ammo_text() == "RELOADING…", "the HUD reads '%s' while loading" % hud.ammo_text())
	await _seconds(0.5)
	_expect(player.ammo == 0, "a shell counted before its 0.55 s were up")
	await _seconds(0.1)
	_expect(player.ammo == 1 and shells[0] == 1, "after 0.6 s the Shotgun holds %d shells (%d signalled), not 1" % [player.ammo, shells[0]])
	await _seconds(0.35)
	_expect(player.ammo == 1, "the second shell counted before its 0.45 s were up")
	await _seconds(0.1)
	_expect(player.ammo == 2, "after 1.05 s the Shotgun holds %d shells, not 2" % player.ammo)
	await _seconds(1.8)
	_expect(player.ammo == 6 and shells[0] == 6, "after 2.85 s the Shotgun holds %d shells, not 6" % player.ammo)
	_expect(pumps[0] == 1 and player.is_reloading(), "no closing pump after loading from empty (pumps %d)" % pumps[0])
	_expect(player.fire() == null, "a shot broke the closing pump")
	await _seconds(0.3)
	_expect(player.is_reloading(), "the reload from empty ended under 3.25 s")
	await _seconds(0.15)
	_expect(not player.is_reloading(), "the reload from empty ran past 3.25 s")
	_expect(player.ammo == 6 and ended == [false], "empty to full ended at %d shells, signalled %s" % [player.ammo, ended])
	_expect(shots_fired == 0, "a shot pressed in the closing pump fired later")
	_expect(hud.ammo_text() == "6 / ∞", "the HUD reads '%s' after the reload" % hud.ammo_text())

	# A shot after two shells: keeps them, loses the one in hand, fires 0.25 s later.
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	player.ammo = 0
	player.start_reload()
	await _seconds(0.2)
	_expect(player.fire() == null and player.is_reloading(), "a shot broke in with no shell in the gun")
	await _seconds(1.0)
	_expect(player.ammo == 2, "%d shells in before the shot, expected 2" % player.ammo)
	ended.clear()
	shots_fired = 0
	_expect(player.fire() == null, "the shot breaking in fired at once")
	_expect(not player.is_reloading() and ended == [true], "a shot did not break the reload (ended %s)" % [ended])
	_expect(player.ammo == 2, "breaking in left %d shells, not 2" % player.ammo)
	_expect(player.fire() == null, "a second press in the break-out fired")
	await _seconds(0.2)
	_expect(shots_fired == 0, "the break-out shot fired before 0.25 s")
	await _seconds(0.1)
	_expect(shots_fired == 1, "the break-out shot did not fire by 0.3 s (%d shots)" % shots_fired)
	_expect(player.ammo == 1, "the break-out shot left %d shells, not 1" % player.ammo)
	await _seconds(0.7)
	_expect(player.ammo == 1 and not player.is_reloading(), "the lost shell came back: %d shells" % player.ammo)
	_clear_shots()

	# A Melee and a swap keep the shells already in.
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	player.ammo = 0
	player.start_reload()
	await _seconds(1.2)
	player.melee()
	_expect(not player.is_reloading(), "the reload survived a Melee")
	_expect(player.ammo == 2, "a Melee left %d shells, not 2" % player.ammo)
	await _seconds(player.melee_cycle + 0.1)
	shots_fired = 0
	player.ammo = 0
	player.start_reload()
	await _seconds(1.2)
	ended.clear()
	player.switch_weapon(-1)
	_expect(not player.is_reloading() and ended == [true], "the reload survived a swap (ended %s)" % [ended])
	await _seconds(player.weapon.swap_time + 0.1)
	await _hold(SHOTGUN)
	_expect(player.ammo == 2, "a swap left %d shells, not 2" % player.ammo)
	_expect(shots_fired == 0, "a Melee or swap fired a shot")

	# From 3: a reload to full with no closing pump; a Sprint does not break it.
	await _place(RUNWAY)
	await _hold(SHOTGUN)
	player.ammo = 3
	pumps[0] = 0
	started.clear()
	player.start_reload()
	_expect(started == [false], "a reload from 3 signalled %s" % [started])
	await _sprint_up()
	_expect(player.is_reloading() and player.ammo == 3, "a Sprint broke the reload (%d shells)" % player.ammo)
	await _seconds(1.0)
	_expect(player.ammo == 6, "from 3, %d shells after 1.5 s" % player.ammo)
	_expect(not player.is_reloading() and pumps[0] == 0, "the reload from 3 pumped or ran on")
	Input.action_release("sprint")
	Input.action_release("move_up")

	# An interrupted Pistol reload still gains nothing.
	await _hold(player.weapons[0])
	await _place(RUNWAY)
	_expect(_fire_and_drop(), "no Pistol shot to open the magazine")
	await _seconds(0.2)
	player.start_reload()
	await _seconds(1.0)
	player.melee()
	_expect(not player.is_reloading() and player.ammo == player.weapon.magazine_size - 1,
			"an interrupted Pistol reload left %d rounds" % player.ammo)
	await _seconds(player.melee_cycle + 0.1)

	player.shell_loaded.disconnect(on_shell)
	player.closing_pump_started.disconnect(on_pump)
	player.shell_reload_ended.disconnect(on_end)
	player.shell_reload_started.disconnect(on_start)
	_clear_shots()
	await _place(RUNWAY)


## --- Aim Down Sights ---

func _aim(on: bool) -> void:
	if on:
		Input.action_press("aim")
	else:
		Input.action_release("aim")
	await _frames(3)


## ADS is a flag valid in WALK, CROUCH and AIR, refused in SPRINT, SLIDE,
## CLAMBER and while reloading.
func _check_ads_states() -> void:
	await _place(RUNWAY)
	await _aim(true)
	_expect(player.ads, "aim while standing did not raise the sights")
	_expect(ads_seen == [true], "ads_changed signalled %s on the raise" % [ads_seen])
	Input.action_press("crouch")
	await _frames(3)
	_expect(player.state == player.State.CROUCH and player.ads, "crouching dropped the sights")
	Input.action_release("crouch")
	await _frames(3)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_expect(player.state == player.State.AIR and player.ads, "jumping dropped the sights")
	await _seconds(1.0)
	await _aim(false)
	_expect(not player.ads, "releasing aim kept the sights up")

	await _place(RUNWAY)
	await _sprint_up()
	await _aim(true)
	_expect(player.state == player.State.WALK, "aim during sprint left him in %s" % player.State.keys()[player.state])
	Input.action_release("sprint")
	await _aim(false)
	await _place(RUNWAY)
	await _sprint_up()
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE, "no slide to test against")
	await _aim(true)
	_expect(not player.ads, "sights came up during a slide")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _aim(false)

	await _place(_before_block(4))
	Input.action_press("move_up")
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_release("move_up")
	_expect(player.state == player.State.CLAMBER, "no clamber to test against")
	await _aim(true)
	_expect(not player.ads, "sights came up during a clamber")
	await _seconds(0.6)
	await _aim(false)

	await _place(RUNWAY)
	_fire_and_drop()
	await _frames(1)
	player.start_reload()
	await _aim(true)
	_expect(not player.ads, "sights came up during a reload")
	await _aim(false)
	_clear_shots()


## A reload, a sprint or damage ends ADS; a jump keeps it.
func _check_ads_ends() -> void:
	await _place(RUNWAY)
	_fire_and_drop()
	await _aim(true)
	_expect(player.ads, "no ADS to end")
	player.start_reload()
	await _frames(1)
	_expect(player.is_reloading() and not player.ads, "starting a reload kept the sights up")
	_expect(ads_seen == [true, false], "ads_changed signalled %s around the reload" % [ads_seen])
	await _aim(false)
	await _seconds(1.3)

	await _aim(true)
	_expect(player.ads, "sights did not come back up after the reload")
	player.take_damage(1)
	await _frames(1)
	_expect(not player.ads, "taking damage kept the sights up")
	_expect(descopes == 1, "descoped fired %d times, expected 1" % descopes)
	_expect(player.state == player.State.WALK, "damage changed the state to %s" % player.State.keys()[player.state])
	Input.action_release("aim")
	await _seconds(0.5)
	_expect(not player.ads, "sights came back up with aim released")
	player.take_damage(1)
	await _frames(1)
	_expect(descopes == 1, "descoped fired for a hit taken off the sights")

	await _aim(true)
	Input.action_press("move_up")
	Input.action_press("sprint")
	await _frames(3)
	_expect(player.state == player.State.SPRINT, "sprint refused while aiming: %s" % player.State.keys()[player.state])
	_expect(not player.ads, "sprinting kept the sights up")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _aim(false)
	_clear_shots()


## Aim during SPRINT drops to WALK at once; the sights take 0.2 s to come up.
func _check_ads_raise() -> void:
	await _place(RUNWAY)
	await _sprint_up()
	Input.action_press("aim")
	await _frames(2)
	_expect(player.state == player.State.WALK, "aim during sprint left him in %s" % player.State.keys()[player.state])
	_expect(not player.ads, "sights came up straight out of the sprint")
	await _seconds(player.ads_raise_time * 0.5)
	_expect(not player.ads, "sights up halfway into the raise")
	await _seconds(player.ads_raise_time + 0.1)
	_expect(player.ads, "sights still down %.2f s after aiming out of a sprint" % (player.ads_raise_time * 1.5 + 0.1))
	_expect(player.state == player.State.WALK, "sprint re-entered while aiming: %s" % player.State.keys()[player.state])
	Input.action_release("aim")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _frames(3)


## Zoom, slowdown and the tighter cone come from the Weapon Profile.
func _check_ads_numbers() -> void:
	await _place(RUNWAY)
	var profile: WeaponProfile = player.weapon
	var hip_fov: float = player.camera.fov
	await _aim(true)
	await _seconds(0.5)
	_expect(is_equal_approx(player.spread_degrees(), 0.5),
			"ADS spread while still is %.2f deg, expected 0.5" % player.spread_degrees())
	# The Pistol zooms 1.6x: a 75 deg hip view narrows to 51.2 deg.
	_expect(is_equal_approx(profile.ads_zoom, 1.6), "the Pistol zooms %.2fx, spec says 1.6" % profile.ads_zoom)
	_expect(is_equal_approx(player.ads_raise_time, 0.12), "the ADS raise is %.2f s, spec says 0.12" % player.ads_raise_time)
	var zoomed_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(hip_fov) / 2.0) / profile.ads_zoom))
	_expect(absf(hip_fov - 75.0) < 0.01 and absf(zoomed_fov - 51.2) < 0.1, "75 deg at 1.6x should be 51.2, got %.1f" % zoomed_fov)
	_expect(absf(player.camera.fov - zoomed_fov) < 0.5,
			"ADS FOV is %.1f, expected %.1f for %.1fx zoom" % [player.camera.fov, zoomed_fov, profile.ads_zoom])
	Input.action_press("move_up")
	await _seconds(0.5)
	_expect(is_equal_approx(player.flat_speed(), player.max_speed * 0.8),
			"ADS walk runs at %.2f m/s, expected 0.8 x walk = %.2f" % [player.flat_speed(), player.max_speed * 0.8])
	Input.action_release("move_up")
	await _seconds(0.3)
	Input.action_press("crouch")
	await _frames(3)
	_expect(player.state == player.State.CROUCH and player.ads, "crouching under the sights gave %s" % player.State.keys()[player.state])
	_expect(is_equal_approx(player.spread_degrees(), 0.35),
			"crouched ADS spread is %.2f deg, expected 0.7 x 0.5 = 0.35" % player.spread_degrees())
	Input.action_release("crouch")
	await _aim(false)
	await _seconds(0.5)
	_expect(absf(player.camera.fov - hip_fov) < 0.5, "FOV did not return to %.1f after ADS: %.1f" % [hip_fov, player.camera.fov])


## The cone a Profile gives in each stance, hip and aimed, at zero bloom:
## still, walking, crouched and in the air, and a Slide from the hip.
func _stance_cones(profile: WeaponProfile) -> Dictionary:
	var held: WeaponProfile = player.weapon
	player.weapon = profile
	var cones := {}
	for aimed in [false, true]:
		var tag := "aimed " if aimed else "hip "
		await _place(RUNWAY)
		if aimed:
			await _aim(true)
			await _seconds(profile.aim_time)
		await _frames(2)
		cones[tag + "still"] = player.spread_degrees()
		Input.action_press("move_up")
		await _seconds(0.4)
		cones[tag + "walking"] = player.spread_degrees() if player.flat_speed() > 0.5 else -1.0
		Input.action_release("move_up")
		await _seconds(0.4)
		Input.action_press("crouch")
		await _frames(3)
		cones[tag + "crouched"] = player.spread_degrees() if player.state == player.State.CROUCH else -1.0
		Input.action_release("crouch")
		await _frames(3)
		Input.action_press("jump")
		await _frames(3)
		Input.action_release("jump")
		cones[tag + "air"] = player.spread_degrees() if player.state == player.State.AIR else -1.0
		await _seconds(1.0)
		cones[tag + "still sights up"] = player.ads == aimed
		if aimed:
			await _aim(false)
	await _place(RUNWAY)
	await _sprint_up()
	Input.action_press("crouch")
	await _frames(2)
	cones["hip slide"] = player.spread_degrees() if player.state == player.State.SLIDE else -1.0
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_up")
	player.weapon = held
	await _place(RUNWAY)
	return cones


## The aimed-and-moving spread leaves the Pistol and Assault Rifle exactly
## as they were in every stance: aimed walking is still their aimed
## multiplier times their walking one, and an aimed crouch still takes the
## crouch multiplier.
func _check_cones_unchanged() -> void:
	var expected := {
		"Pistol": [player.weapon, {
			"hip still": 1.0, "hip walking": 1.2, "hip crouched": 0.7, "hip air": 1.5, "hip slide": 1.5,
			"aimed still": 0.5, "aimed walking": 0.6, "aimed crouched": 0.35, "aimed air": 0.75}],
		"Assault Rifle": [ASSAULT_RIFLE, {
			"hip still": 1.2, "hip walking": 1.56, "hip crouched": 0.84, "hip air": 2.16, "hip slide": 1.92,
			"aimed still": 0.54, "aimed walking": 0.702, "aimed crouched": 0.378, "aimed air": 0.972}],
	}
	for gun: String in expected:
		var cones: Dictionary = await _stance_cones(expected[gun][0])
		_expect(cones["aimed still sights up"] and cones["hip still sights up"], "%s: the sights were not where the stance check wanted them" % gun)
		var wanted: Dictionary = expected[gun][1]
		for stance: String in wanted:
			_expect(is_equal_approx(cones[stance], wanted[stance]),
					"%s %s cone is %.3f deg, was %.3f" % [gun, stance, cones[stance], wanted[stance]])


## A Profile with a tiny aimed multiplier and a larger aimed-and-moving one
## is pinpoint aimed and still or crouched, and a 1.2 degree cone aimed and
## walking, out of a 3 degree hip cone.
func _check_aimed_moving_spread() -> void:
	var cones: Dictionary = await _stance_cones(STEADY_RIFLE)
	_expect(is_equal_approx(cones["hip still"], 3.0), "the steady rifle's hip cone is %.3f deg, not 3" % cones["hip still"])
	_expect(cones["aimed still"] > 0.0 and cones["aimed still"] < 0.05, "aimed and still is %.3f deg, not pinpoint" % cones["aimed still"])
	_expect(cones["aimed crouched"] > 0.0 and cones["aimed crouched"] < 0.05, "aimed and crouched is %.3f deg, not pinpoint" % cones["aimed crouched"])
	_expect(is_equal_approx(cones["aimed walking"], 1.2), "aimed and walking is %.3f deg, not 1.2" % cones["aimed walking"])


## Aimed sway: a gun with sway drifts the view in a figure of eight while
## aimed, inside its sway, and hands the view back exactly where it was
## when the sights drop. A gun without sway holds dead still.
func _check_aimed_sway() -> void:
	await _place(RUNWAY)
	player.head.rotation.x = 0.0
	await _aim(true)
	var yaw: float = player.rotation.y
	await _seconds(1.0)
	_expect(is_equal_approx(player.rotation.y, yaw) and is_equal_approx(player.head.rotation.x, 0.0),
			"the Pistol, with no sway, drifted the aim")
	await _aim(false)

	var held: WeaponProfile = player.weapon
	player.weapon = STEADY_RIFLE
	await _place(RUNWAY)
	player.head.rotation.x = 0.0
	await _frames(2)
	yaw = player.rotation.y
	var sway := deg_to_rad(STEADY_RIFLE.ads_sway_degrees)
	await _aim(true)
	var yaws: Array[float] = []
	var pitches: Array[float] = []
	for i in 300:
		await physics_frame
		yaws.append(player.rotation.y - yaw)
		pitches.append(player.head.rotation.x)
	var yaw_span: float = yaws.max() - yaws.min()
	var pitch_span: float = pitches.max() - pitches.min()
	_expect(yaw_span > sway and yaw_span <= 2.0 * sway + 0.0001,
			"aimed sway swung the yaw %.3f deg, expected up to %.2f either side" % [rad_to_deg(yaw_span), STEADY_RIFLE.ads_sway_degrees])
	_expect(pitch_span > sway * 0.5 and pitch_span <= sway + 0.0001,
			"aimed sway swung the pitch %.3f deg, expected up to half the yaw's" % rad_to_deg(pitch_span))
	await _aim(false)
	_expect(absf(player.rotation.y - yaw) < 0.00001 and absf(player.head.rotation.x) < 0.00001,
			"dropping the sights left the aim %.4f deg yaw, %.4f deg pitch off" % [rad_to_deg(player.rotation.y - yaw), rad_to_deg(player.head.rotation.x)])
	await _seconds(0.5)
	_expect(absf(player.rotation.y - yaw) < 0.00001 and absf(player.head.rotation.x) < 0.00001,
			"the aim kept drifting with the sights down")
	player.weapon = held
	await _place(RUNWAY)


## Aimed, the mouse turns the view less by the held gun's zoom, so a hand
## movement covers the same distance on screen.
func _check_mouse_slowed_by_zoom() -> void:
	await _place(RUNWAY)
	player.head.rotation.x = 0.0
	var yaw: float = player.rotation.y
	player.look(Vector2(100.0, 40.0))
	var hip_yaw: float = yaw - player.rotation.y
	var hip_pitch: float = -player.head.rotation.x
	await _aim(true)
	_expect(player.ads and is_equal_approx(player.weapon.ads_zoom, 1.6), "no 1.6 zoom aim to turn under")
	yaw = player.rotation.y
	var pitch: float = player.head.rotation.x
	player.look(Vector2(100.0, 40.0))
	var aimed_yaw: float = yaw - player.rotation.y
	var aimed_pitch: float = pitch - player.head.rotation.x
	_expect(hip_yaw > 0.0 and is_equal_approx(hip_yaw / aimed_yaw, 1.6),
			"aimed, the mouse turned %.4f rad against %.4f at the hip, not 1.6 times less" % [aimed_yaw, hip_yaw])
	_expect(hip_pitch > 0.0 and is_equal_approx(hip_pitch / aimed_pitch, 1.6),
			"aimed, the mouse pitched %.4f rad against %.4f at the hip, not 1.6 times less" % [aimed_pitch, hip_pitch])
	await _aim(false)
	player.head.rotation.x = 0.0


## Sights that survive a fight: a hit drops them and they come back on
## their own while aim is held, every hit of a burst pushing that back; a
## reload or a melee lowers them and they rise again the moment it ends.
func _check_descope_recovery() -> void:
	await _place(RUNWAY)
	await _aim(true)
	_expect(player.ads, "no ADS to test under fire")
	player.take_damage(1)
	await _frames(1)
	_expect(not player.ads and descopes == 1, "a hit did not descope")
	await _seconds(0.4)
	_expect(player.ads, "the sights did not come back within 0.4 s of a hit with aim held")
	_expect(ads_seen == [true, false, true], "ads_changed signalled %s around the hit" % [ads_seen])

	# A burst: the second hit lands mid-recovery, counts as its own Descope
	# and restarts the clock.
	player.take_damage(1)
	await _seconds(0.2)
	player.take_damage(1)
	await _frames(1)
	_expect(descopes == 3, "the second hit of a burst was not a Descope (%d)" % descopes)
	await _seconds(0.2)
	_expect(not player.ads, "the sights came back 0.2 s after the second hit of a burst")
	await _seconds(0.25)
	_expect(player.ads, "the sights did not come back after the burst")

	_fire_and_drop()
	await _seconds(0.2)
	ads_seen.clear()
	player.start_reload()
	await _frames(1)
	_expect(not player.ads, "the reload kept the sights up")
	await _seconds(player.weapon.reload_tactical)
	await _frames(2)
	_expect(not player.is_reloading() and player.ads, "the sights did not rise as the reload ended")
	_clear_shots()

	await _dummy(100, 6.0)
	ads_seen.clear()
	await _swing()
	_expect(not player.ads, "the melee kept the sights up")
	await _cycle()
	await _frames(2)
	_expect(player.ads, "the sights did not rise as the melee cycle ended")
	await _aim(false)
	await _clear_dummy()


## --- aim time and swap time ---

## Each bare gun's aim time and swap time, from the spec, exactly.
func _check_aim_and_swap_numbers() -> void:
	var wanted := [[player.weapons[0], "Pistol", 0.15, 0.30], [ASSAULT_RIFLE, "Assault Rifle", 0.22, 0.40],
			[SHOTGUN, "Shotgun", 0.22, 0.45], [MARKSMAN_RIFLE, "Marksman Rifle", 0.32, 0.50]]
	for row: Array in wanted:
		var profile: WeaponProfile = row[0]
		_expect(is_equal_approx(profile.aim_time, row[2]), "the %s's aim time is %.3f s, spec says %.2f" % [row[1], profile.aim_time, row[2]])
		_expect(is_equal_approx(profile.swap_time, row[3]), "the %s's swap time is %.3f s, spec says %.2f" % [row[1], profile.swap_time, row[3]])
	_expect(not "swap_time" in player, "the Pirate still keeps a swap time of his own")


## Holds [param profile] at rest at the hip, presses aim and returns on the
## first frame the sights are up: by then the Pirate and the Viewmodel have
## each taken one frame of the rise, and each physics frame after is one more.
func _start_aim(profile: WeaponProfile) -> void:
	if player.weapon != profile:
		await _hold(profile)
	await _place(RUNWAY)
	player.head.rotation.x = 0.0
	await _seconds(0.3)
	Input.action_press("aim")
	for i in 10:
		if player.ads:
			break
		await physics_frame
	_expect(player.ads, "%s: the sights did not come up" % profile.resource_path.get_file())


## Frames, counting the one already taken, until the Viewmodel is within 5%
## of the aimed pose, measured from where it started.
func _frames_to_aimed_pose(from: Vector3) -> int:
	var aimed: Vector3 = weapon.pose_ads
	var steps := 1
	while weapon.position.distance_to(aimed) > 0.05 * from.distance_to(aimed) and steps < 120:
		await physics_frame
		steps += 1
	return steps


## Holding aim from the hip, each gun's Viewmodel is within 5% of its aimed
## pose at its aim time, and the zoom with it, each within 10% of that time.
func _check_aim_time_pose() -> void:
	for profile: WeaponProfile in player.weapons:
		var label := profile.resource_path.get_file()
		await _start_aim(profile)
		var hip: Vector3 = weapon.pose_hip
		# The hip view is 75 degrees (`_check_ads_numbers`); the camera has
		# already taken a frame of the zoom by now.
		var hip_fov := 75.0
		var zoomed_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(hip_fov) / 2.0) / profile.ads_zoom))
		_expect(not weapon.position.is_equal_approx(hip), "%s: the Viewmodel had not started up with the sights" % label)
		var pose_steps := -1
		var zoom_steps := -1
		for steps in range(1, 120):
			if pose_steps < 0 and weapon.position.distance_to(weapon.pose_ads) <= 0.05 * hip.distance_to(weapon.pose_ads):
				pose_steps = steps
			if zoom_steps < 0 and absf(player.camera.fov - zoomed_fov) <= 0.05 * absf(hip_fov - zoomed_fov):
				zoom_steps = steps
			if pose_steps > 0 and zoom_steps > 0:
				break
			await physics_frame
		var pose_t := pose_steps * FRAME
		var zoom_t := zoom_steps * FRAME
		_expect(absf(pose_t - profile.aim_time) <= 0.1 * profile.aim_time,
				"%s: the Viewmodel came within 5%% of the sights in %.3f s, aim time %.2f s +-10%%" % [label, pose_t, profile.aim_time])
		_expect(absf(zoom_t - profile.aim_time) <= 0.1 * profile.aim_time,
				"%s: the zoom came within 5%% in %.3f s, aim time %.2f s +-10%%" % [label, zoom_t, profile.aim_time])
		# And down again at the same rate.
		Input.action_release("aim")
		var aimed: Vector3 = weapon.position
		await physics_frame
		var down_steps := 1
		while weapon.position.distance_to(hip) > 0.05 * aimed.distance_to(hip) and down_steps < 120:
			await physics_frame
			down_steps += 1
		_expect(absf(down_steps * FRAME - profile.aim_time) <= 0.1 * profile.aim_time,
				"%s: the Viewmodel came back within 5%% of the hip in %.3f s, aim time %.2f s" % [label, down_steps * FRAME, profile.aim_time])
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## The Assault Rifle's aimed-still cone rises in a straight line over its
## aim time: 1.2 degrees at the hip, halfway (0.87) halfway up within 10%,
## and the aimed 0.54 at the aim time within 2%; it falls back the same way.
func _check_aim_time_cone() -> void:
	var rifle := ASSAULT_RIFLE
	await _hold(rifle)
	await _place(RUNWAY)
	await _seconds(0.3)
	_expect(is_equal_approx(player.spread_degrees(), 1.2), "the Assault Rifle's hip cone is %.3f deg, not 1.2" % player.spread_degrees())
	await _start_aim(rifle)
	var half_steps := roundi(rifle.aim_time * 0.5 / FRAME)
	var full_steps := roundi(rifle.aim_time / FRAME)
	var cones := {}
	for steps in range(1, full_steps + 1):
		cones[steps] = player.spread_degrees()
		await physics_frame
	var halfway := (1.2 + 0.54) * 0.5
	_expect(absf(cones[half_steps] - halfway) <= 0.1 * halfway,
			"%.3f s up the Assault Rifle's cone is %.3f deg, halfway is %.3f +-10%%" % [half_steps * FRAME, cones[half_steps], halfway])
	_expect(absf(cones[full_steps] - 0.54) <= 0.02 * 0.54,
			"at its %.2f s aim time (%.3f s) the Assault Rifle's cone is %.3f deg, aimed is 0.54 +-2%%" % [rifle.aim_time, full_steps * FRAME, cones[full_steps]])
	var rising := true
	for steps in range(2, full_steps + 1):
		rising = rising and cones[steps] < cones[steps - 1]
	_expect(rising, "the Assault Rifle's cone did not narrow every frame of the rise: %s" % [cones.values()])
	await _seconds(0.3)
	Input.action_release("aim")
	await _seconds(rifle.aim_time * 0.5)
	var falling: float = player.spread_degrees()
	_expect(falling > 0.6 and falling < 1.15, "half an aim time after the sights drop the cone is %.3f deg, not on its way back" % falling)
	await _seconds(rifle.aim_time)
	_expect(is_equal_approx(player.spread_degrees(), 1.2), "an aim time after the sights drop the cone is %.3f deg, not the hip's 1.2" % player.spread_degrees())
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## A shot fired halfway up is allowed and counts: it goes off, spends a
## round, signals, lands on a body 6 m ahead, and leaves a cone halfway
## between the hip's and the aimed one.
func _check_shot_halfway_up() -> void:
	var rifle := ASSAULT_RIFLE
	await _hold(rifle)
	await _dummy(100, 6.0)
	await _start_aim(rifle)
	await _frames(roundi(rifle.aim_time * 0.5 / FRAME) - 1)
	var cone: float = player.spread_degrees()
	var rounds: int = player.ammo
	var shot: Projectile3D = player.fire()
	_expect(shot != null, "a shot halfway up the sights was refused")
	_expect(player.ammo == rounds - 1 and shots_fired == 1, "the shot halfway up spent %d rounds and signalled %d shots" % [rounds - player.ammo, shots_fired])
	_expect(cone > 0.54 and cone < 1.2 and absf(cone - 0.87) <= 0.087, "the shot halfway up went off in a %.3f deg cone, not about 0.87" % cone)
	await _seconds(0.3)
	_expect(dummy.health.current == 75 and hits_landed.size() == 1, "the shot halfway up did not land (dummy at %d)" % dummy.health.current)
	Input.action_release("aim")
	await _clear_dummy()
	_clear_shots()
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## After a Descope the sights wait out the recovery, then come up over the
## Marksman Rifle's full 0.32 s aim time, within 10%.
func _check_descope_full_aim_time() -> void:
	var rifle := MARKSMAN_RIFLE
	await _start_aim(rifle)
	await _seconds(0.5)
	player.take_damage(1)
	await _frames(1)
	_expect(not player.ads, "the hit did not descope")
	var frames := 0
	while not player.ads and frames < 120:
		await physics_frame
		frames += 1
	_expect(absf(frames * FRAME - player.descope_recovery) <= 2 * FRAME,
			"the sights came back %.3f s after the hit, the recovery is %.2f s" % [frames * FRAME, player.descope_recovery])
	var steps: int = await _frames_to_aimed_pose(weapon.pose_hip)
	_expect(absf(steps * FRAME - rifle.aim_time) <= 0.1 * rifle.aim_time,
			"after the Descope the sights came back in %.3f s, aim time %.2f s +-10%%" % [steps * FRAME, rifle.aim_time])
	Input.action_release("aim")
	await _hold(player.weapons[0])
	await _place(RUNWAY)


## Seconds a fresh swap holds the trigger: fire is tried every frame until
## one goes off.
func _seconds_until_fire() -> float:
	var frames := 0
	while not _fire_and_drop() and frames < 120:
		await physics_frame
		frames += 1
	return frames * FRAME


## A swap takes the swap time of the weapon being drawn: Pistol to Marksman
## Rifle blocks fire for 0.50 s, and back to the Pistol for 0.30 s, each
## within 0.02 s.
func _check_swap_time_of_drawn() -> void:
	var pistol: WeaponProfile = player.weapons[0]
	await _hold(pistol)
	await _place(RUNWAY)
	player.select_weapon(player.weapons.find(MARKSMAN_RIFLE))
	_expect(player.weapon == MARKSMAN_RIFLE, "no swap to the Marksman Rifle")
	var blocked := await _seconds_until_fire()
	_expect(absf(blocked - 0.5) <= 0.02, "Pistol to Marksman Rifle blocked fire %.3f s, wanted 0.50 +-0.02" % blocked)
	await _seconds(MARKSMAN_RIFLE.fire_interval + 0.05)
	player.select_weapon(0)
	_expect(player.weapon == pistol, "no swap back to the Pistol")
	blocked = await _seconds_until_fire()
	_expect(absf(blocked - 0.3) <= 0.02, "Marksman Rifle to Pistol blocked fire %.3f s, wanted 0.30 +-0.02" % blocked)
	_clear_shots()
	await _place(RUNWAY)


## --- reporting ---

## --- Melee ---

## A fresh dummy of [param hit_points] on the runway, [param ahead] metres in
## front of the pirate and [param off_axis] degrees to his right, facing
## [param facing] on the floor plane (toward him unless told otherwise, so a
## hit is a front hit). The old one goes.
func _dummy(hit_points: int, ahead: float, off_axis: float = 0.0, facing: Vector3 = Vector3.BACK) -> void:
	if dummy != null:
		dummy.free()
	dummy = Dummy.new(hit_points)
	var offset := Vector3.FORWARD.rotated(Vector3.UP, -deg_to_rad(off_axis)) * ahead
	dummy.position = RUNWAY + offset
	dummy.rotation.y = atan2(-facing.x, -facing.z)
	world.add_child(dummy)
	await _frames(2)


## One press, then long enough for a lunge to land its strike.
## Takes the melee dummy off the course, so a walk ahead is not into it.
func _clear_dummy() -> void:
	if dummy != null:
		dummy.free()
		dummy = null
		await _frames(1)


func _swing() -> void:
	Input.action_press("melee")
	await _frames(1)
	Input.action_release("melee")
	await _seconds(player.melee_lunge_time)
	await _frames(2)


## Sees the swing's cycle out, with a frame or two to spare.
func _cycle() -> void:
	await _seconds(player.melee_cycle + 0.05)


func _flat_gap() -> float:
	var to := dummy.global_position - player.global_position
	to.y = 0.0
	return to.length()


## The target is the body inside the 30 deg cone within 2 m; a whiff
## reaches 1.2 m straight ahead and no further.
func _check_melee_cone() -> void:
	await _place(RUNWAY)
	await _dummy(100, 1.5)
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == dummy, "a dummy 1.5 m ahead was not the melee target")
	_expect(dummy.health.current == 25, "a front hit on 100 HP left %d, not 25" % dummy.health.current)
	await _cycle()

	await _place(RUNWAY)
	await _dummy(100, 3.0)
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == null, "a dummy 3 m ahead was hit by a melee")
	_expect(dummy.health.current == 100, "a dummy 3 m ahead took melee damage")
	await _cycle()

	await _place(RUNWAY)
	await _dummy(100, 1.5, 20.0)
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == null, "a dummy 20 deg off the axis was hit by a melee")
	_expect(dummy.health.current == 100, "a dummy 20 deg off the axis took melee damage")
	await _cycle()

	# A body just outside the cone but close enough for the crosshair ray to
	# graze is still swept by the whiff: no lunge, but the blow lands. (The
	# ray leaves the eyes at 1.6 m, up in the capsule's top cap, so the body
	# has to be near.)
	await _place(RUNWAY)
	await _dummy(100, 0.75, 17.0)
	_expect(player.melee_target() == null, "a dummy 17 deg off the axis was inside the cone")
	var before := player.global_position
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == dummy, "the whiff ray did not sweep a dummy 0.75 m ahead")
	_expect(dummy.health.current == 25, "a swept dummy took %d damage, not 75" % (100 - dummy.health.current))
	_expect(player.global_position.distance_to(before) < 0.02, "a whiff lunged")
	await _cycle()

	# The ship itself is never a target: a swing at a shut door in reach
	# whiffs into air and leaves the door be.
	await _place(_before_block(4))
	door.close()
	await _frames(2)
	_expect(door.in_reach(), "the course door is not in reach for the melee whiff")
	await _swing()
	_expect(swings == [[null, false]], "a swing at a door reported %s" % [swings])
	_expect(not door.is_open, "a melee opened the door")
	await _cycle()


## The lunge pulls him to 0.9 m from the target over 0.15 s, snaps his
## facing to it, and ignores movement input for 0.2 s after.
func _check_melee_lunge() -> void:
	await _place(RUNWAY)
	await _dummy(225, 1.9, 10.0)
	var start := player.global_position
	await _swing()
	var gap := _flat_gap()
	_expect(absf(gap - player.melee_lunge_stop) < 0.08,
			"the lunge stopped %.2f m from the target, not %.2f" % [gap, player.melee_lunge_stop])
	_expect(player.global_position.distance_to(start) > 0.5, "the lunge did not move him")
	var to := dummy.global_position - player.global_position
	var facing := -player.global_transform.basis.z
	_expect(rad_to_deg(Vector2(facing.x, facing.z).angle_to(Vector2(to.x, to.z).normalized())) < 2.0,
			"the lunge did not snap his facing to the target")
	_expect(dummy.health.current == 150, "the lunge landed %d damage, not 75" % (225 - dummy.health.current))
	# Movement input is ignored for a beat after the lunge lands.
	var landed := player.global_position
	Input.action_press("move_left")
	await _seconds(0.1)
	_expect(player.global_position.distance_to(landed) < 0.02,
			"movement input moved him %.2f m within 0.1 s of the lunge" % player.global_position.distance_to(landed))
	await _seconds(0.3)
	_expect(player.global_position.distance_to(landed) > 0.3,
			"movement input was still ignored 0.4 s after the lunge")
	Input.action_release("move_left")
	await _cycle()


## From inside the 120 deg cone behind the target's facing a melee kills
## outright; from the front it does its 75.
func _check_melee_back_hit() -> void:
	await _place(RUNWAY)
	# Facing away from him: he is squarely behind.
	await _dummy(100, 1.5, 0.0, Vector3.FORWARD)
	await _swing()
	_expect(not dummy.is_alive(), "a back hit left the dummy on %d HP" % dummy.health.current)
	_expect(swings.size() == 1 and swings[0][1] == true, "the back-hit kill was not reported as one")
	await _cycle()

	# Facing him: front.
	await _place(RUNWAY)
	await _dummy(100, 1.5, 0.0, Vector3.BACK)
	await _swing()
	_expect(dummy.health.current == 25, "a front hit on 100 HP left %d, not 25" % dummy.health.current)
	_expect(swings.size() == 1 and swings[0][1] == false, "a front hit was reported as a kill")
	await _cycle()

	# Facing sideways: 90 deg from behind, outside the 60 deg half-cone.
	await _place(RUNWAY)
	await _dummy(100, 1.5, 0.0, Vector3.RIGHT)
	await _swing()
	_expect(dummy.health.current == 25, "a side hit on 100 HP left %d, not 25" % dummy.health.current)
	await _cycle()

	# Facing 50 deg off away: inside the back cone.
	await _place(RUNWAY)
	await _dummy(100, 1.5, 0.0, Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(50.0)))
	await _swing()
	_expect(not dummy.is_alive(), "a hit 50 deg inside the back cone left the dummy on %d HP" % dummy.health.current)
	await _cycle()


## A swing drops a running reload with nothing gained; the next R starts a
## fresh one at the full duration.
func _check_melee_cancels_reload() -> void:
	await _place(RUNWAY)
	await _dummy(100, 6.0)
	_expect(_fire_and_drop(), "no shot to open the magazine")
	await _seconds(0.2)
	player.start_reload()
	await _seconds(0.5)
	_expect(player.is_reloading(), "no reload running to cancel")
	await _swing()
	_expect(not player.is_reloading(), "the reload survived a melee")
	_expect(reloads_cancelled == 1, "the melee's reload cancel was not signalled")
	_expect(player.ammo == player.weapon.magazine_size - 1, "the cancelled reload gained rounds")
	await _cycle()
	Input.action_press("reload")
	await _frames(1)
	Input.action_release("reload")
	await _frames(2)
	_expect(player.is_reloading(), "R after the melee did not start a reload")
	await _check_reload_lasts(player.weapon.reload_tactical, "post-melee")
	_clear_shots()


## Allowed in WALK, CROUCH, SLIDE and AIR; ends a SPRINT and latches it,
## drops the sights; ignored in CLAMBER.
func _check_melee_states() -> void:
	await _place(RUNWAY)
	await _dummy(100, 6.0)
	await _sprint_up()
	await _swing()
	_expect(player.state == player.State.WALK, "melee out of SPRINT gave %s" % player.State.keys()[player.state])
	_expect(swings.size() == 1, "melee out of SPRINT did not swing")
	await _seconds(0.3)
	_expect(player.state == player.State.WALK, "sprint re-entered after a melee with sprint still held")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _cycle()

	# ADS drops for the swing.
	await _place(RUNWAY)
	await _aim(true)
	_expect(player.ads, "no ADS to end")
	await _swing()
	_expect(not player.ads, "a melee left the sights up")
	await _aim(false)
	await _cycle()

	# Crouch, slide and air all swing.
	await _place(RUNWAY)
	Input.action_press("crouch")
	await _seconds(0.2)
	await _swing()
	_expect(swings.size() == 1 and player.state == player.State.CROUCH, "no melee from CROUCH")
	Input.action_release("crouch")
	await _cycle()

	await _place(RUNWAY)
	await _sprint_up()
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE, "no slide to melee from")
	await _swing()
	_expect(swings.size() == 1, "no melee from SLIDE")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _cycle()
	await _seconds(0.6)

	await _place(RUNWAY)
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_expect(player.state == player.State.AIR, "not airborne for the air melee")
	await _swing()
	_expect(swings.size() == 1, "no melee from AIR")
	await _cycle()
	await _seconds(0.8)

	# A second press inside the cycle is ignored.
	await _place(RUNWAY)
	await _swing()
	await _swing()
	_expect(swings.size() == 1, "a melee inside the 0.55 s cycle swung again")
	await _cycle()
	await _swing()
	_expect(swings.size() == 2, "no melee after the cycle ended")
	await _cycle()

	# CLAMBER ignores it.
	await _place(_before_block(4))
	Input.action_press("move_up")
	Input.action_press("jump")
	await _frames(2)
	_expect(player.state == player.State.CLAMBER, "no clamber at the 1.1 m block")
	Input.action_release("jump")
	Input.action_release("move_up")
	await _swing()
	_expect(swings.is_empty(), "a melee swung mid-clamber")
	_expect(player.state == player.State.CLAMBER, "melee broke the clamber")
	await _seconds(0.6)


## --- Viewmodel ---

## Largest distance between two samples of the Viewmodel's position over
## [param frames], with the axis picked by [param axis] (-1 for all).
func _travel(frames: int, axis: int = -1) -> float:
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for i in frames:
		await physics_frame
		lo = lo.min(weapon.position)
		hi = hi.max(weapon.position)
	var span := hi - lo
	return span.length() if axis < 0 else span[axis]


func _at_pose(pose: Vector3, label: String, tolerance: float = 0.03) -> void:
	_expect(weapon.position.distance_to(pose) < tolerance,
			"%s: Viewmodel at %s, pose %s" % [label, weapon.position, pose])


## Every surface on the weapon mesh carries the wall-clipping flags.
func _check_viewmodel_materials() -> void:
	var surfaces := 0
	for mesh in weapon.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		for i in instance.mesh.get_surface_count():
			surfaces += 1
			var material := instance.get_active_material(i)
			_expect(material != null, "%s surface %d has no material" % [instance.name, i])
			if material == null:
				continue
			_expect(material.get("use_z_clip_scale") == true and is_equal_approx(material.get("z_clip_scale"), weapon.z_clip_scale),
					"%s surface %d z_clip_scale is %s" % [instance.name, i, material.get("z_clip_scale")])
			_expect(material.get("use_fov_override") == true and is_equal_approx(material.get("fov_override"), weapon.fov_override),
					"%s surface %d fov_override is %s" % [instance.name, i, material.get("fov_override")])
	_expect(is_equal_approx(weapon.z_clip_scale, 0.35) and is_equal_approx(weapon.fov_override, 50.0),
			"the clipping flags are %.2f / %.0f, spec says 0.35 / 50" % [weapon.z_clip_scale, weapon.fov_override])
	_expect(surfaces > 0, "the weapon mesh has no surfaces to flag")


## Hip at rest; sprint-low within 0.3 s of SPRINT or CLAMBER and back within
## 0.3 s of leaving.
func _check_viewmodel_poses() -> void:
	await _place(RUNWAY)
	await _seconds(0.5)
	_at_pose(weapon.pose_hip, "at rest")
	Input.action_press("move_up")
	Input.action_press("sprint")
	await _frames(3)
	_expect(player.state == player.State.SPRINT, "no sprint for the low pose")
	await _seconds(0.3)
	_at_pose(weapon.pose_low, "0.3 s into SPRINT")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _seconds(0.3)
	_at_pose(weapon.pose_hip, "0.3 s after SPRINT")

	await _place(_before_block(4))
	await _seconds(0.3)
	Input.action_press("move_up")
	Input.action_press("jump")
	await _frames(2)
	_expect(player.state == player.State.CLAMBER, "no clamber for the low pose")
	Input.action_release("jump")
	Input.action_release("move_up")
	await _seconds(0.3)
	_at_pose(weapon.pose_low, "0.3 s into CLAMBER")
	await _seconds(0.25)
	_expect(player.state == player.State.WALK, "clamber still running for the pose check")
	await _seconds(0.3)
	_at_pose(weapon.pose_hip, "0.3 s after CLAMBER")


## The sights pose puts the muzzle on the camera's forward axis.
func _check_viewmodel_ads_pose() -> void:
	await _place(RUNWAY)
	await _aim(true)
	await _seconds(0.5)
	_expect(player.ads, "no ADS for the sights pose")
	_at_pose(weapon.pose_ads, "in ADS", 0.01)
	var muzzle_x: float = player.camera.to_local(player.muzzle.global_position).x
	_expect(absf(muzzle_x) < 0.01, "ADS muzzle is %.3f m off the camera axis" % muzzle_x)
	await _aim(false)
	await _seconds(0.5)
	_at_pose(weapon.pose_hip, "after ADS")
	var hip_x: float = player.camera.to_local(player.muzzle.global_position).x
	_expect(hip_x > 0.1, "hip muzzle sits at x %.3f, not off to the right" % hip_x)


func _mouse(pixels: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = pixels
	Input.parse_input_event(motion)


## Mouse sway: 0.0006 m per pixel, clamped to 0.04 m, a fifth of that in ADS.
func _check_viewmodel_sway() -> void:
	await _place(RUNWAY)
	await _seconds(0.4)
	var rest := weapon.position
	for i in 20:
		_mouse(Vector2(200.0, 0.0))
		await physics_frame
	var swung: float = rest.x - weapon.position.x
	_expect(swung > weapon.sway_max * 0.6 and swung < weapon.sway_max * 1.1,
			"a hard mouse pull swung the Viewmodel %.3f m, clamp is %.3f" % [swung, weapon.sway_max])
	await _seconds(0.5)
	_expect(absf(weapon.position.x - rest.x) < 0.005, "sway did not settle: %.3f m off" % (weapon.position.x - rest.x))

	await _aim(true)
	await _seconds(0.5)
	rest = weapon.position
	for i in 20:
		_mouse(Vector2(200.0, 0.0))
		await physics_frame
	swung = rest.x - weapon.position.x
	var ads_clamp: float = weapon.sway_max * weapon.sway_ads_scale
	_expect(swung > ads_clamp * 0.5 and swung < ads_clamp * 1.5,
			"in ADS the same pull swung %.3f m, want about %.3f" % [swung, ads_clamp])
	await _aim(false)
	await _seconds(0.5)


## Walk bob: the Viewmodel rises and falls on the move, in step with speed,
## less crouched or in ADS, and not at all standing still.
func _check_viewmodel_bob() -> void:
	await _place(RUNWAY)
	await _seconds(0.4)
	var still := await _travel(30, 1)
	_expect(still < 0.002, "the Viewmodel moved %.3f m standing still" % still)
	Input.action_press("move_up")
	await _seconds(0.4)
	var walking := await _travel(45, 1)
	_expect(walking > 0.008, "walking bobbed only %.3f m" % walking)
	Input.action_press("crouch")
	await _seconds(0.5)
	var crouched := await _travel(45, 1)
	# Half the speed and the crouch scale on top: well under half the bob.
	_expect(crouched < walking * 0.5, "crouched bob %.3f m is not under half the walking %.3f m" % [crouched, walking])
	Input.action_release("crouch")
	await _aim(true)
	await _seconds(0.5)
	var aimed := await _travel(45, 1)
	_expect(aimed < walking * 0.5, "ADS bob %.3f m is not under half the walking %.3f m" % [aimed, walking])
	await _aim(false)
	Input.action_release("move_up")
	await _seconds(0.5)


## A shot pushes the Viewmodel back and kicks it up, and kicks the camera
## 1.2 deg up, all recovering in a beat.
func _check_viewmodel_recoil() -> void:
	await _place(RUNWAY)
	await _seconds(0.4)
	var rest := weapon.position
	var rest_pitch: float = weapon.rotation_degrees.x
	var rest_muzzle: Vector3 = player.camera.to_local(player.muzzle.global_position)
	_expect(_fire_and_drop(), "no shot for the recoil check")
	var push := 0.0
	var kick := 0.0
	var camera_kick := 0.0
	var muzzle_rise := 0.0
	var muzzle_back := 0.0
	for i in 12:
		await physics_frame
		push = maxf(push, weapon.position.z - rest.z)
		# The Viewmodel faces down the camera, so muzzle-up is a negative pitch.
		kick = maxf(kick, rest_pitch - weapon.rotation_degrees.x)
		var muzzle: Vector3 = player.camera.to_local(player.muzzle.global_position)
		muzzle_rise = maxf(muzzle_rise, muzzle.y - rest_muzzle.y)
		muzzle_back = maxf(muzzle_back, muzzle.z - rest_muzzle.z)
		camera_kick = maxf(camera_kick, player.camera.rotation_degrees.x)
	_expect(push > 0.01, "the shot pushed the Viewmodel back only %.3f m" % push)
	_expect(kick > 1.5, "the shot kicked the Viewmodel up only %.1f deg" % kick)
	_expect(muzzle_rise > 0.005, "the shot lifted the muzzle only %.3f m: recoil goes up" % muzzle_rise)
	_expect(muzzle_back > 0.01, "the shot brought the muzzle back only %.3f m: recoil goes back" % muzzle_back)
	_expect(camera_kick > 0.8 and camera_kick <= 1.2 + 0.01, "the camera kick peaked at %.2f deg, want 1.2" % camera_kick)
	await _seconds(0.5)
	_expect(weapon.position.distance_to(rest) < 0.005, "the Viewmodel did not settle after the shot")
	_expect(absf(player.camera.rotation_degrees.x) < 0.05, "the camera kick did not recover: %.2f deg" % player.camera.rotation_degrees.x)
	_clear_shots()


## A Descope rolls the camera for a moment, then it levels again.
func _check_viewmodel_descope() -> void:
	await _place(RUNWAY)
	await _aim(true)
	await _seconds(0.3)
	_expect(absf(player.camera.rotation_degrees.z) < 0.05, "the camera is not level before the Descope")
	player.take_damage(1)
	var roll := 0.0
	for i in 8:
		await physics_frame
		roll = maxf(roll, absf(player.camera.rotation_degrees.z))
	_expect(descopes == 1, "no Descope to roll on")
	_expect(roll > 0.2, "the Descope rolled the camera only %.2f deg" % roll)
	await _seconds(0.6)
	_expect(absf(player.camera.rotation_degrees.z) < 0.05, "the Descope roll did not level out: %.2f deg" % player.camera.rotation_degrees.z)
	await _aim(false)


## --- Viewmodel clips ---

## The four clips, at the spec's lengths.
func _check_clips_exist() -> void:
	var clips: AnimationPlayer = weapon.clips
	_expect(clips != null, "the Viewmodel has no AnimationPlayer")
	if clips == null:
		return
	var lengths := {"fire": 0.12, "reload_tactical": 1.2, "reload_empty": 1.6, "melee": 0.55}
	for clip_name: String in lengths:
		_expect(clips.has_animation(clip_name), "no %s clip" % clip_name)
		if clips.has_animation(clip_name):
			var length: float = clips.get_animation(clip_name).length
			_expect(is_equal_approx(length, lengths[clip_name]), "%s clip is %.2f s, want %.2f" % [clip_name, length, lengths[clip_name]])


func _mesh_at_identity() -> bool:
	var mesh: Node3D = weapon.holder
	return mesh.position.is_zero_approx() and mesh.rotation.is_zero_approx()


## Reload clips by the magazine's state, a cancel that stops and resets, a
## shot that never interrupts a reload, a melee that does.
func _check_clips_play() -> void:
	var clips: AnimationPlayer = weapon.clips
	await _place(RUNWAY)
	await _frames(2)
	_expect(not clips.is_playing(), "a clip is playing at rest: %s" % clips.current_animation)

	_expect(_fire_and_drop(), "no shot for the fire clip")
	await _frames(1)
	_expect(clips.current_animation == "fire" and clips.is_playing(), "a shot did not play fire, playing %s" % clips.current_animation)
	await _seconds(0.3)
	_expect(not clips.is_playing(), "fire clip still playing after 0.3 s")
	_expect(_mesh_at_identity(), "the mesh is off identity after the fire clip: %s %s" % [weapon.holder.position, weapon.holder.rotation_degrees])

	# Tactical reload with rounds left.
	player.start_reload()
	await _frames(1)
	_expect(clips.current_animation == "reload_tactical", "a tactical reload played %s" % clips.current_animation)
	await _seconds(0.4)
	_expect(not _mesh_at_identity(), "the reload clip is not moving the mesh")
	# A shot mid-reload is swallowed by the pirate; and were one to get
	# through, `fired` itself must not cut the clip.
	_expect(not _fire_and_drop(), "a shot went off mid-reload")
	player.fired.emit()
	await _frames(2)
	_expect(clips.current_animation == "reload_tactical" and clips.is_playing(), "`fired` stopped the reload clip")
	_expect(not _mesh_at_identity(), "`fired` reset the mesh mid-reload")
	# Cancel: clip stops, mesh back to identity.
	player.cancel_reload()
	await _frames(1)
	_expect(not clips.is_playing(), "the reload cancel left %s playing" % clips.current_animation)
	_expect(_mesh_at_identity(), "the reload cancel left the mesh at %s %s" % [weapon.holder.position, weapon.holder.rotation_degrees])

	# Empty reload on the dry pull.
	player.ammo = 0
	player.fire()
	await _frames(1)
	_expect(player.is_reloading(), "the dry pull did not reload")
	_expect(clips.current_animation == "reload_empty", "an empty reload played %s" % clips.current_animation)
	await _seconds(0.3)
	# A melee mid-reload cancels it and plays its own clip.
	await _dummy(100, 6.0)
	await _swing()
	_expect(clips.current_animation == "melee" and clips.is_playing(), "a melee mid-reload played %s" % clips.current_animation)
	await _cycle()
	_expect(not clips.is_playing(), "melee clip still playing after its cycle")
	_expect(_mesh_at_identity(), "the mesh is off identity after the melee clip")
	_clear_shots()


## The reload clips last the Weapon Profile's reload times, whatever the
## Profile: a swapped pistol stretches or squeezes them.
func _check_clips_follow_profile() -> void:
	var clips: AnimationPlayer = weapon.clips
	await _place(RUNWAY)
	var pistol: WeaponProfile = player.weapon
	player.weapon = HEAVY_PISTOL
	player.ammo = HEAVY_PISTOL.magazine_size - 1
	player.start_reload()
	await _frames(1)
	var wanted: float = clips.get_animation("reload_tactical").length / HEAVY_PISTOL.reload_tactical
	_expect(clips.current_animation == "reload_tactical", "the heavy pistol's reload played %s" % clips.current_animation)
	_expect(absf(clips.get_playing_speed() - wanted) < 0.01,
			"the heavy pistol's reload clip runs at %.2fx, want %.2fx for a %.1f s reload" % [clips.get_playing_speed(), wanted, HEAVY_PISTOL.reload_tactical])
	await _seconds(HEAVY_PISTOL.reload_tactical - 0.1)
	_expect(clips.is_playing(), "the reload clip ended before the heavy pistol's %.1f s reload" % HEAVY_PISTOL.reload_tactical)
	await _seconds(0.2)
	_expect(not clips.is_playing(), "the reload clip outlasted the heavy pistol's reload")
	player.weapon = pistol
	await _place(RUNWAY)


## --- the Pistol mesh ---

## The Viewmodel carries the pistol model: in ADS its front sight sits
## on the camera axis, from the hip it sits low right, and the shot leaves
## its muzzle.
func _check_holder_model() -> void:
	await _place(RUNWAY)
	var holder: Node3D = weapon.get_node_or_null("Holder")
	_expect(holder != null, "the Viewmodel has no Holder node")
	if holder == null:
		return
	_expect(weapon.holder == holder, "the Viewmodel's Holder node is not the pistol model")
	_expect(holder.find_child("Skeleton3D", true, false) != null, "the pistol has no skeleton")
	var sight: Node3D = weapon.get_node_or_null("SightTip")
	_expect(sight != null, "no SightTip marker on the Viewmodel")
	if sight == null:
		return
	await _aim(true)
	await _seconds(0.5)
	var in_camera: Vector3 = player.camera.to_local(sight.global_position)
	_expect(absf(in_camera.x) < 0.005 and absf(in_camera.y) < 0.005,
			"in ADS the front sight sits at (%.3f, %.3f) m off the camera axis" % [in_camera.x, in_camera.y])
	_expect(in_camera.z < 0.0, "the front sight is behind the camera in ADS")
	var muzzle_in_camera: Vector3 = player.camera.to_local(player.muzzle.global_position)
	_expect(absf(muzzle_in_camera.x) < 0.01, "in ADS the muzzle is %.3f m off the axis" % muzzle_in_camera.x)
	await _aim(false)
	await _seconds(0.5)
	in_camera = player.camera.to_local(sight.global_position)
	_expect(in_camera.x > 0.1 and in_camera.y < -0.05, "from the hip the sight sits at (%.2f, %.2f), not low right" % [in_camera.x, in_camera.y])


## The pistol's own clips: the slide cycles on a shot, the magazine on a
## reload for the Profile's time, and a cancel leaves the skeleton at rest.
func _check_pistol_clips() -> void:
	await _place(RUNWAY)
	var anim: AnimationPlayer = weapon.model_clips
	_expect(anim != null, "the Pistol mesh has no AnimationPlayer")
	if anim == null:
		return
	var profile: WeaponProfile = player.weapon
	for clip_name in [profile.model_fire_clip, profile.model_reload_clip, profile.model_rack_clip]:
		_expect(anim.has_animation(clip_name), "the Pistol mesh lacks the %s clip" % clip_name)
	_expect(not anim.is_playing(), "a pistol clip is playing at rest: %s" % anim.current_animation)
	_expect(_fire_and_drop(), "no shot for the pistol fire clip")
	await _frames(1)
	_expect(anim.current_animation == profile.model_fire_clip and anim.is_playing(), "a shot played %s on the Pistol" % anim.current_animation)
	await _seconds(0.3)
	_expect(not anim.is_playing(), "the pistol fire clip outlasted 0.3 s")
	player.start_reload()
	await _frames(1)
	_expect(anim.current_animation == profile.model_reload_clip and anim.is_playing(), "a reload played %s on the Pistol" % anim.current_animation)
	var wanted: float = anim.get_animation(profile.model_reload_clip).length / profile.reload_tactical
	_expect(absf(anim.get_playing_speed() - wanted) < 0.01, "the pistol reload runs at %.2fx, want %.2fx" % [anim.get_playing_speed(), wanted])
	await _seconds(0.4)
	var skeleton: Skeleton3D = weapon.holder.find_child("Skeleton3D", true, false)
	var magazine := skeleton.find_bone("Magazine")
	var moved: Vector3 = skeleton.get_bone_pose_position(magazine)
	_expect(not moved.is_equal_approx(skeleton.get_bone_rest(magazine).origin), "the reload clip is not moving the magazine bone")
	player.cancel_reload()
	await _frames(1)
	_expect(not anim.is_playing(), "the cancel left %s playing on the pistol" % anim.current_animation)
	_expect(skeleton.get_bone_pose_position(magazine).is_equal_approx(skeleton.get_bone_rest(magazine).origin),
			"the cancel left the magazine bone at %s" % skeleton.get_bone_pose_position(magazine))
	# The empty reload: magazine clip, then the rack in its last beat, and
	# nothing left playing once the reload ends.
	player.ammo = 0
	player.fire()
	await _frames(1)
	_expect(anim.current_animation == profile.model_reload_clip, "the empty reload played %s on the Pistol" % anim.current_animation)
	await _seconds(profile.reload_empty - profile.rack_time / 2.0)
	_expect(anim.current_animation == profile.model_rack_clip and anim.is_playing(), "near the end of the empty reload the Pistol plays %s, not the rack" % anim.current_animation)
	await _seconds(profile.rack_time / 2.0 + 0.1)
	_expect(not anim.is_playing(), "the Pistol clip outlasted the empty reload")
	_clear_shots()


## --- HUD ---

## The crosshair opens with the live spread, never closing as it grows, and
## is a dot while the sights are up.
func _check_hud_crosshair() -> void:
	await _place(RUNWAY)
	await _frames(2)
	_expect(not hud.crosshair_is_dot(), "the crosshair is a dot from the hip")
	var gaps: Array[float] = []
	for degrees in [0.5, 1.0, 1.5, 2.5, 4.0]:
		hud.set_spread(degrees)
		gaps.append(hud.crosshair_gap())
		_expect(_crosshair_reaches() == [hud.crosshair_gap(), hud.crosshair_gap(), hud.crosshair_gap(), hud.crosshair_gap()],
				"at %.1f deg the lines sit %s px out, gap is %.1f" % [degrees, _crosshair_reaches(), hud.crosshair_gap()])
	for i in range(1, gaps.size()):
		_expect(gaps[i] > gaps[i - 1], "crosshair gap %.1f px at wider spread is not past %.1f px" % [gaps[i], gaps[i - 1]])
	# Driven by the pirate: standing still, then walking, opens it. (He only
	# reports a change, so hand the HUD back his standing cone first.)
	hud.set_spread(player.spread_degrees())
	var still := hud.crosshair_gap()
	Input.action_press("move_up")
	await _seconds(0.4)
	_expect(hud.crosshair_gap() > still, "walking did not open the crosshair (%.1f vs %.1f px)" % [hud.crosshair_gap(), still])
	Input.action_release("move_up")
	await _seconds(0.4)
	await _aim(true)
	_expect(hud.crosshair_is_dot(), "ADS did not collapse the crosshair to a dot")
	await _aim(false)
	_expect(not hud.crosshair_is_dot(), "the crosshair stayed a dot after ADS")


## How far each visible crosshair line's near edge sits from the centre,
## read off the drawn rects.
func _crosshair_reaches() -> Array[float]:
	var reaches: Array[float] = []
	for child in hud.get_node("Root/Crosshair").get_children():
		var line := child as ColorRect
		if line == null or not line.visible or line.size == Vector2(2, 2):
			continue
		var rect := Rect2(line.position, line.size)
		var axis := 0 if rect.size.x > rect.size.y else 1
		var near: float = rect.position[axis] if rect.position[axis] > 0.0 else -rect.end[axis]
		reaches.append(near)
	return reaches


## `n / ∞`, red at zero and normal again at one.
func _check_hud_ammo() -> void:
	await _place(RUNWAY)
	_expect(hud.ammo_text() == "%d / ∞" % player.weapon.magazine_size, "ammo reads '%s'" % hud.ammo_text())
	_expect(not hud.ammo_reads_empty(), "a full magazine reads red")
	hud.set_ammo(1)
	_expect(hud.ammo_text() == "1 / ∞" and not hud.ammo_reads_empty(), "one round reads '%s', red %s" % [hud.ammo_text(), hud.ammo_reads_empty()])
	hud.set_ammo(0)
	_expect(hud.ammo_text() == "0 / ∞" and hud.ammo_reads_empty(), "zero reads '%s', red %s" % [hud.ammo_text(), hud.ammo_reads_empty()])
	hud.set_reloading(true)
	_expect(hud.ammo_text() == "RELOADING…" and not hud.ammo_reads_empty(), "reloading from empty reads '%s', red %s" % [hud.ammo_text(), hud.ammo_reads_empty()])
	hud.set_reloading(false)
	_expect(hud.ammo_reads_empty(), "the zero is not red again after the reload text")
	hud.set_ammo(1)
	_expect(not hud.ammo_reads_empty(), "the label stayed red at one round")
	hud.set_ammo(player.ammo)


## One bar where the pips were: the Pirate's full Health fills it, six
## segments of 25, and any hit, however small, shortens the fill.
func _check_hud_health() -> void:
	hud.set_max_health(player.health.max_health)
	hud.set_health(player.health.max_health)
	_expect(hud.health_segments() == 6, "the Health bar has %d segments, not 6" % hud.health_segments())
	var full := hud.health_fill_width()
	_expect(full > 0.0 and is_equal_approx(full, hud.health_bar_width()),
			"150 Health fills %.1f px of a %.1f px bar" % [full, hud.health_bar_width()])
	hud.set_health(player.health.max_health - 13)
	var hit := hud.health_fill_width()
	_expect(hit < full and is_equal_approx(hit, full * 137.0 / 150.0),
			"13 damage left the fill at %.1f px of %.1f" % [hit, full])
	hud.set_health(player.health.max_health - 14)
	_expect(hud.health_fill_width() < hit, "one more point of damage did not move the fill")
	hud.set_health(0)
	_expect(is_zero_approx(hud.health_fill_width()), "no Health still fills %.1f px" % hud.health_fill_width())
	hud.set_health(player.health.max_health)


## A dry pull clicks once, however long it is held, and the reload it starts
## swallows further pulls without another click.
func _check_hud_dry_click() -> void:
	await _place(RUNWAY)
	player.ammo = 0
	hud.set_ammo(0)
	await _pull_trigger(60)
	_expect(dry_fires == 1, "a held dry pull signalled %d dry fires, not 1" % dry_fires)
	_expect(dry_clicks == 1, "a held dry pull clicked %d times, not 1" % dry_clicks)
	_expect(player.is_reloading(), "the dry pull did not start the reload")
	await _pull_trigger(1)
	_expect(dry_clicks == 1, "a pull during the empty reload clicked again")
	await _seconds(player.weapon.reload_empty)
	_expect(not player.is_reloading(), "the empty reload is still running")
	_expect(not hud.ammo_reads_empty(), "the label is still red after the reload")
	await _pull_trigger(1)
	_expect(dry_clicks == 1 and dry_fires == 1, "a live pull after the reload clicked")
	_clear_shots()


## --- sounds ---

func _sound_kinds() -> Array:
	var out := []
	for s in sounds:
		out.append(s[0])
	return out


func _sounds_of(kind: StringName) -> int:
	return _sound_kinds().count(kind)


## One sound per event: the shot, the dry click, the melee landing, the hit
## taken; a whiff into air and a swing at a door stay silent.
func _check_audio_events() -> void:
	await _place(RUNWAY)
	await _frames(2)
	_expect(sounds.is_empty(), "sounds played at rest: %s" % [_sound_kinds()])
	_expect(_fire_and_drop(), "no shot for the shot sound")
	await _frames(1)
	_expect(_sound_kinds() == [&"shot"], "a shot played %s" % [_sound_kinds()])
	var first_stream: AudioStream = sounds[0][1]
	_expect(first_stream in player.weapon.shot_sounds and first_stream.resource_path.contains("kurt_22_magnum/shot"),
			"the Pistol's shot played %s" % [first_stream])
	_expect(player.weapon.shot_sounds.size() >= 2, "the Pistol has %d shot takes" % player.weapon.shot_sounds.size())
	sounds.clear()
	# The Assault Rifle sounds its own shot, not the Pistol's.
	await _seconds(0.2)
	player.switch_weapon(1)
	await _seconds(player.weapon.swap_time + 0.05)
	_expect(player.weapon == ASSAULT_RIFLE, "the wheel did not reach the Assault Rifle")
	_expect(_fire_and_drop(), "no Assault Rifle shot for the shot sound")
	await _frames(1)
	var rifle_stream: AudioStream = sounds[0][1] if sounds.size() == 1 else null
	_expect(rifle_stream != null and rifle_stream in ASSAULT_RIFLE.shot_sounds and rifle_stream.resource_path.contains("kurt_gunshots/shot"),
			"the Assault Rifle's shot played %s" % [sounds])
	for stream in ASSAULT_RIFLE.shot_sounds:
		_expect(not stream in player.weapons[0].shot_sounds, "the Pistol and the Assault Rifle share %s" % stream.resource_path)
	_expect(is_equal_approx(ASSAULT_RIFLE.loudness, 24.0), "the Assault Rifle is %.1f m loud, not 24" % ASSAULT_RIFLE.loudness)
	player.switch_weapon(-1)
	await _seconds(player.weapon.swap_time + 0.05)
	sounds.clear()
	await _check_action_sound()
	await _seconds(0.2)
	player.ammo = 0
	await _pull_trigger(30)
	_expect(_sounds_of(&"dry") == 1, "a held dry pull clicked %d times" % _sounds_of(&"dry"))
	_expect(_sounds_of(&"shot") == 0, "the dry pull played a shot")
	player.cancel_reload()
	await _frames(2)
	sounds.clear()

	await _place(RUNWAY)
	await _dummy(100, 6.0)
	await _swing()
	_expect(_sounds_of(&"melee") == 0, "a whiff into air played the melee landing")
	await _cycle()
	await _place(RUNWAY)
	await _dummy(225, 1.5)
	await _swing()
	_expect(_sounds_of(&"melee") == 1, "a landed melee played %d landing sounds" % _sounds_of(&"melee"))
	await _cycle()

	await _place(RUNWAY)
	player.take_damage(1)
	await _frames(1)
	_expect(_sounds_of(&"hit") == 1, "a hit taken played %d hit sounds" % _sounds_of(&"hit"))


## A Profile's action sound plays its delay after each shot; neither gun
## today has one. A test Profile carries it, since no gun does yet.
func _check_action_sound() -> void:
	var pistol: WeaponProfile = player.weapon
	_expect(pistol.action_sound == null and ASSAULT_RIFLE.action_sound == null, "a current gun has an action sound")
	var pumped: WeaponProfile = pistol.duplicate()
	var pump: AudioStream = pistol.reload_sounds[0]
	pumped.action_sound = pump
	pumped.action_sound_delay = 0.3
	player.weapon = pumped
	await _seconds(0.2)
	sounds.clear()
	_expect(_fire_and_drop(), "no shot from the test Profile")
	await _seconds(0.15)
	_expect(_sound_kinds() == [&"shot"], "0.15 s after a shot with a 0.3 s action the sounds were %s" % [_sound_kinds()])
	await _seconds(0.25)
	_expect(_sound_kinds() == [&"shot", &"action"] and sounds[1][1] == pump,
			"0.4 s after a shot with a 0.3 s action the sounds were %s" % [sounds])
	player.weapon = pistol
	sounds.clear()
	_fire_and_drop()
	await _seconds(0.5)
	_expect(_sounds_of(&"action") == 0, "the Pistol played an action sound")
	sounds.clear()


## No shot sound is named anywhere but a Weapon Profile: every take a
## carried Profile plays is referenced only under `resources/weapons`.
func _check_shot_sounds_only_in_profiles() -> void:
	var paths: Array[String] = []
	for profile in player.weapons:
		for stream in profile.shot_sounds:
			paths.append(stream.resource_path)
	_expect(paths.size() >= 2, "the carried Profiles name %d shot takes" % paths.size())
	var offenders: Array[String] = []
	for file in _source_files("res://"):
		if file.begins_with("res://resources/weapons/"):
			continue
		var text := FileAccess.get_file_as_string(file)
		for path in paths:
			if text.contains(path.get_base_dir() + "/"):
				offenders.append("%s names %s" % [file, path])
	_expect(offenders.is_empty(), "shot sounds named outside a Weapon Profile: %s" % [offenders])


func _source_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with(".") or sub in ["assets", "tests", "docs"]:
			continue
		out.append_array(_source_files(dir.path_join(sub)))
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			out.append(dir.path_join(file))
	return out


## The reload sequence: magazine out at the start, in later, the rack only on
## the empty reload and before it ends; a cancel stops what is still to come.
func _check_audio_reload() -> void:
	await _place(RUNWAY)
	_expect(_fire_and_drop(), "no shot to open the magazine")
	await _seconds(0.2)
	sounds.clear()
	player.start_reload()
	await _frames(2)
	_expect(_sound_kinds() == [&"mag_out"], "the tactical reload opened with %s" % [_sound_kinds()])
	await _seconds(player.weapon.reload_tactical + 0.1)
	_expect(_sound_kinds() == [&"mag_out", &"mag_in"], "the tactical reload played %s" % [_sound_kinds()])
	_expect(sounds.size() == 2 and [sounds[0][1], sounds[1][1]] == Array(player.weapon.reload_sounds),
			"the reload did not play the Profile's reload sounds in order: %s" % [sounds])
	_clear_shots()

	player.ammo = 0
	sounds.clear()
	player.fire()
	await _frames(2)
	_expect(_sound_kinds() == [&"dry", &"mag_out"], "the empty reload opened with %s" % [_sound_kinds()])
	await _seconds(player.weapon.reload_empty - player.weapon.rack_time / 2.0)
	_expect(_sounds_of(&"mag_in") == 1 and _sounds_of(&"rack") == 1, "near the end of the empty reload the sounds were %s" % [_sound_kinds()])
	await _seconds(player.weapon.rack_time)
	_expect(_sound_kinds() == [&"dry", &"mag_out", &"mag_in", &"rack"], "the empty reload played %s" % [_sound_kinds()])

	# A cancel before the magazine goes in leaves it out.
	await _seconds(0.2)
	_expect(_fire_and_drop(), "no shot to open the magazine for the cancel")
	await _seconds(0.2)
	sounds.clear()
	player.start_reload()
	await _seconds(0.3)
	player.cancel_reload()
	await _seconds(player.weapon.reload_tactical)
	_expect(_sound_kinds() == [&"mag_out"], "a cancelled reload played %s" % [_sound_kinds()])
	_clear_shots()


## Footsteps on the move, at a cadence, none standing still, sliding or in
## the air, a landing thud on touching down.
func _check_audio_footsteps() -> void:
	await _clear_dummy()
	await _place(RUNWAY)
	await _seconds(0.5)
	_expect(_sounds_of(&"step") == 0, "steps played standing still")
	Input.action_press("move_up")
	await _seconds(1.0)
	var steps := _sounds_of(&"step")
	_expect(steps >= 2 and steps <= 6, "a second of walking played %d steps" % steps)
	Input.action_release("move_up")
	await _seconds(0.5)
	sounds.clear()

	await _place(RUNWAY)
	Input.action_press("crouch")
	Input.action_press("move_up")
	await _seconds(1.0)
	var crouched := _sounds_of(&"step")
	_expect(crouched >= 1 and crouched < steps, "a second of crouched walking played %d steps against %d walking" % [crouched, steps])
	Input.action_release("crouch")
	Input.action_release("move_up")
	await _seconds(0.5)
	sounds.clear()

	await _place(RUNWAY)
	await _sprint_up()
	sounds.clear()
	Input.action_press("crouch")
	await _frames(2)
	_expect(player.state == player.State.SLIDE, "no slide for the footstep check")
	await _seconds(0.4)
	_expect(_sounds_of(&"step") == 0, "steps played mid-slide: %s" % [_sound_kinds()])
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_up")
	await _seconds(0.5)
	sounds.clear()

	await _place(RUNWAY)
	Input.action_press("move_up")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	sounds.clear()
	_expect(player.state == player.State.AIR, "not airborne for the footstep check")
	await _seconds(0.4)
	_expect(_sounds_of(&"step") == 0, "steps played in the air: %s" % [_sound_kinds()])
	await _seconds(0.8)
	_expect(_sounds_of(&"land") == 1, "landing played %d thuds" % _sounds_of(&"land"))
	Input.action_release("move_up")


## A bolt into the ship makes no sound; the sfx bus exists; a respawn
## mid-reload silences the rest of the reload and lands no thud.
func _check_audio_impact_and_respawn() -> void:
	_expect(AudioServer.get_bus_index("sfx") != -1, "no sfx bus in the layout")
	await _clear_dummy()
	await _place(RUNWAY)
	_clear_shots()
	var rings_before := _impact_rings()
	var shot: Projectile3D = player.fire()
	_expect(shot != null, "no shot for the impact check")
	await _seconds(0.3)
	_expect(_impact_rings() == rings_before, "a bolt into the ship left %d sounds; wall hits are silent" % (_impact_rings() - rings_before))
	_clear_shots()

	await _seconds(0.2)
	_expect(_fire_and_drop(), "no shot to open the magazine for the respawn")
	await _seconds(0.2)
	player.start_reload()
	await _seconds(0.2)
	sounds.clear()
	# Off the floor, then straight back to spawn: no landing, no magazine.
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_expect(player.state == player.State.AIR, "not airborne for the respawn check")
	player.respawn()
	await _seconds(player.weapon.reload_tactical)
	_expect(sounds.is_empty(), "a respawn mid-reload still played %s" % [_sound_kinds()])
	_clear_shots()


## A crew member's shot rings where they stand, positional, and frees
## itself like the bolt's impact does.
func _check_crew_shot_sound() -> void:
	await _clear_dummy()
	await _place(RUNWAY)
	_clear_shots()
	var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
	crew.position = RUNWAY + Vector3(0.0, 0.0, -6.0)
	world.add_child(crew)
	# No ship to patrol: its brain stays off, only its trigger is pulled.
	crew.set_physics_process(false)
	await _frames(2)
	var rings_before := _impact_rings()
	var shot: Projectile3D = crew._fire()
	_expect(shot != null, "the crew member did not fire")
	await _frames(1)
	_expect(_impact_rings() == rings_before + 1, "a crew shot left %d positional sounds, expected one" % (_impact_rings() - rings_before))
	var ring: AudioStreamPlayer3D = null
	for node in world.get_children():
		if node is AudioStreamPlayer3D and node.name.begins_with("Shot"):
			ring = node
	_expect(ring != null, "the crew shot sound is not named Shot")
	if ring != null:
		_expect(ring.global_position.distance_to(crew.global_position + Vector3.UP * Crew3D.MUZZLE_HEIGHT) < 1.0,
				"the crew shot rings %.1f m from the muzzle" % ring.global_position.distance_to(crew.global_position))
		_expect(ring.stream != null and ring.stream in crew.weapon.shot_sounds and ring.stream.resource_path.contains("kurt_22_magnum/shot"),
				"the crew shot plays %s, not the Pistol's" % [ring.stream])
	if shot != null:
		shot.queue_free()
	await _seconds(1.3)
	_expect(_impact_rings() == rings_before, "the crew shot sound did not free itself")
	crew.free()
	_clear_shots()


## --- the bolt ---

## A bolt at 80 m/s crosses 1.3 m a physics step, more than a body is
## wide: it must hit what it flies through, not only what it lands in. A
## target 7 m off is hit every time, and so is a wall thinner than a step.
func _check_bolt_reach() -> void:
	await _clear_dummy()
	await _place(RUNWAY)
	_clear_shots()
	await _dummy(750, 7.0)
	var hits := 0
	for i in 10:
		var shot: Projectile3D = player.fire()
		_expect(shot != null, "shot %d did not fire" % i)
		await _seconds(0.25)
		# Aim straight, no spread: the Profile's cone is 1 deg, well inside
		# the dummy at 14 m; if a shot misses, that is the tunnelling.
		await _seconds(player.weapon.fire_interval)
	hits = (750 - dummy.health.current) / player.weapon.damage
	_expect(hits == 10, "10 bolts at a dummy 7 m off landed %d hits" % hits)
	_clear_shots()
	await _clear_dummy()

	# The floor slab is 0.2 m thick: a bolt pitched down must stop in it.
	# The bolt strikes and frees itself well inside its 0.5 s life if the
	# slab stops it; a bolt that flew through is still alive at 0.2 s.
	await _place(RUNWAY)
	player.head.rotation.x = -0.6
	var bolt: Projectile3D = player.fire()
	player.head.rotation.x = 0.0
	_expect(bolt != null, "no bolt for the thin-wall check")
	await _seconds(0.2)
	_expect(not is_instance_valid(bolt), "a bolt pitched into the 0.2 m floor slab flew through it")
	_clear_shots()


## A landed shot or melee says so: `hit_landed(target, killed, headshot)`, the HUD
## flashes its marker (red on a kill) and fades it, and the hit tick plays
## once per hit. A bolt into the ship says nothing.
func _check_hit_markers() -> void:
	await _clear_dummy()
	await _place(RUNWAY)
	_clear_shots()
	_expect(is_zero_approx(hud.hitmarker_alpha()), "the hit marker shows at rest")
	# Into the backstop: no hit.
	var stray: Projectile3D = player.fire()
	await _seconds(0.25)
	_expect(hits_landed.is_empty(), "a bolt into the ship counted as a hit")
	_expect(is_zero_approx(hud.hitmarker_alpha()), "the hit marker flashed for a wall")
	_clear_shots()
	await _seconds(0.2)

	await _dummy(125, 6.0)
	sounds.clear()
	# Aimed at the chest: at eye height the crosshair sits on the capsule's
	# top cap, where the 1 deg cone can skim over.
	player.head.rotation.x = -0.05
	var shot: Projectile3D = player.fire()
	_expect(shot != null, "no shot for the hit marker")
	await _seconds(0.15)
	_expect(hits_landed == [[dummy, false]], "a landed shot reported %s" % [hits_landed])
	_expect(hud.hitmarker_alpha() > 0.5, "the hit marker did not flash on a hit (alpha %.2f)" % hud.hitmarker_alpha())
	_expect(not hud.hitmarker_is_kill(), "a plain hit showed the kill marker")
	_expect(_sounds_of(&"hitmark") == 1, "a landed shot played %d hit ticks" % _sounds_of(&"hitmark"))
	await _seconds(0.5)
	_expect(is_zero_approx(hud.hitmarker_alpha()), "the hit marker did not fade (alpha %.2f)" % hud.hitmarker_alpha())
	_clear_shots()

	# Four more rounds kill the 125 HP dummy: the last one is a kill marker.
	hits_landed.clear()
	sounds.clear()
	for i in 4:
		await _seconds(player.weapon.fire_interval + 0.05)
		_expect(player.fire() != null, "round %d of the kill did not fire" % i)
		await _seconds(0.15)
	_expect(hits_landed.size() == 4 and hits_landed[3][1] == true, "the killing shot reported %s" % [hits_landed])
	_expect(hud.hitmarker_is_kill(), "the killing shot did not show the kill marker")
	_expect(_sounds_of(&"hitmark") == 4, "four hits played %d hit ticks" % _sounds_of(&"hitmark"))
	player.head.rotation.x = 0.0
	_clear_shots()
	await _seconds(0.5)

	# A landed melee is a hit too.
	await _place(RUNWAY)
	await _dummy(225, 1.5)
	sounds.clear()
	await _swing()
	_expect(hits_landed == [[dummy, false]], "a landed melee reported %s" % [hits_landed])
	_expect(hud.hitmarker_alpha() > 0.3, "the hit marker did not flash on a melee")
	_expect(_sounds_of(&"hitmark") == 1, "a landed melee played %d hit ticks" % _sounds_of(&"hitmark"))
	await _cycle()
	await _clear_dummy()


## A bolt reads as a tracer: a thin streak at least a metre long, lying
## along its line of flight, not a ball.
func _check_tracer() -> void:
	await _clear_dummy()
	await _place(RUNWAY)
	_clear_shots()
	var bolt: Projectile3D = player.fire()
	_expect(bolt != null, "no bolt for the tracer check")
	if bolt == null:
		return
	var streak: MeshInstance3D = bolt.get_node_or_null("Streak")
	_expect(streak != null, "the bolt has no Streak mesh")
	if streak != null:
		# It starts on the pixel the barrel's tip is drawn on: the muzzle as
		# the Viewmodel's own FOV shows it, not the marker's place in the world.
		var born: Vector3 = bolt.global_position
		var eye: Camera3D = player.camera
		var seen: Vector3 = eye.to_local(born)
		var marker: Vector3 = eye.to_local(player.muzzle.global_position)
		var widen: float = tan(deg_to_rad(eye.fov) * 0.5) / tan(deg_to_rad(weapon.fov_override) * 0.5)
		_expect(seen.distance_to(Vector3(marker.x * widen, marker.y * widen, marker.z)) < 0.005,
				"the bolt started at %s in the camera, the barrel's tip is drawn at %s" % [seen, Vector3(marker.x * widen, marker.y * widen, marker.z)])
		# The streak grows out of the muzzle: no tail behind where it started.
		_expect(not streak.visible, "the streak shows before the bolt has flown")
		for i in 4:
			await physics_frame
			if not is_instance_valid(bolt):
				break
			var tail: Vector3 = bolt.global_transform * (streak.transform * streak.get_aabb()).end
			var behind: float = (born - tail).dot(bolt.direction)
			_expect(behind < 0.01, "frame %d: the streak's tail is %.2f m behind the muzzle" % [i, behind])
	if not is_instance_valid(bolt):
		_expect(false, "the bolt died before the tracer could be measured")
		_clear_shots()
		return
	if streak != null:
		var size: Vector3 = streak.get_aabb().size
		var local_length: float = (streak.transform.basis * size).abs().z
		_expect(local_length >= 1.0, "the streak is %.2f m long along the flight, want at least 1 m" % local_length)
		var across := (streak.transform.basis * size).abs()
		_expect(across.x <= 0.12 and across.y <= 0.12, "the streak is %.2f x %.2f m across, not thin" % [across.x, across.y])
		# The bolt's -Z is its direction of flight.
		var flight: Vector3 = -bolt.global_transform.basis.z
		_expect(flight.dot(bolt.direction) > 0.99, "the bolt's body does not lie along its flight")
	_expect(bolt.get_node_or_null("Mesh") == null, "the old ball mesh is still on the bolt")
	_clear_shots()


## The crew wear one of two rigs on one skeleton, one per crew type, stood
## RIG_HEIGHT tall and facing their forward, with the clips the crew brain
## plays.
func _check_crew_models() -> void:
	await _clear_dummy()
	await _place(RUNWAY)
	var seen := {}
	for i in 12:
		var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
		crew.crew_type = CrewTypes.Type.WORKER if i % 2 == 1 else CrewTypes.Type.GUARD
		crew.position = RUNWAY + Vector3(2.0 + i * 0.1, 0.0, -6.0)
		world.add_child(crew)
		crew.set_physics_process(false)
		await _frames(1)
		var rig: Node3D = crew.get_node_or_null("Model/Rig")
		_expect(rig != null, "crew %d has no Model/Rig" % i)
		if rig != null:
			seen[rig.scene_file_path] = true
			var anim: AnimationPlayer = crew._anim
			_expect(anim != null, "crew %d has no AnimationPlayer" % i)
			if anim != null:
				for clip in ["CharacterArmature|Idle", "CharacterArmature|Run", "CharacterArmature|Idle_Gun_Pointing", "CharacterArmature|Death"]:
					_expect(anim.has_animation(clip), "crew %d's rig lacks %s" % [i, clip])
				_expect(anim.current_animation.ends_with("Idle") and anim.is_playing(), "crew %d at rest plays %s" % [i, anim.current_animation])
			if i == 0:
				var lo := Vector3.INF
				var hi := -Vector3.INF
				for mi in rig.find_children("*", "MeshInstance3D", true, false):
					var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
					lo = lo.min(b.position)
					hi = hi.max(b.end)
				var height := hi.y - lo.y
				_expect(absf(height - Crew3D.RIG_HEIGHT) < 0.15, "the crew rig stands %.2f m tall, want about %.1f" % [height, Crew3D.RIG_HEIGHT])
				_expect(absf(lo.y - crew.global_position.y) < 0.1, "the crew rig's feet are %.2f m off the floor" % (lo.y - crew.global_position.y))
		crew.free()
	_expect(seen.size() == 2, "Guards and Workers wore %d different rigs, want both: %s" % [seen.size(), seen.keys()])
	for path in seen:
		_expect(path.contains("assets/models/crew/"), "a crew rig came from %s" % path)


func _impact_rings() -> int:
	var count := 0
	for node in world.get_children():
		if node is AudioStreamPlayer3D:
			count += 1
	return count


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
		print(SuiteSeed.replay_line("pirate", run_seed))
