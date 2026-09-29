extends SceneTree
## Headless checks on the pirate: the movement state machine (clamber ledge
## band, sprint grace and latch, slide-jump, crouch headroom, the CLAMBER
## input lock) and the Sidearm (semi-auto trigger, dry-pull reload, reload
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
		health.take_damage(amount, from)


func _initialize() -> void:
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
	await _check_ads_states()
	await _check_ads_ends()
	await _check_ads_raise()
	await _check_ads_numbers()
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
	await _check_sidearm_model()
	await _check_sidearm_clips()
	await _check_hud_crosshair()
	await _check_hud_ammo()
	await _check_hud_dry_click()
	await _check_audio_events()
	await _check_audio_reload()
	await _check_audio_footsteps()
	await _check_audio_impact_and_respawn()
	_report()
	quit(1 if failures.size() > 0 else 0)


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
	# old life, not the new one.
	await physics_frame
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


## --- the Sidearm ---

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
	_expect(profile.magazine_size == 12, "the Sidearm holds %d rounds, expected 12" % profile.magazine_size)
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
	var sidearm: WeaponProfile = player.weapon
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
	player.weapon = sidearm
	_clear_shots()


func _clear_shots() -> void:
	for node in world.get_children():
		if node is Projectile3D:
			node.free()


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
	await _aim(false)
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
	await _seconds(0.1)
	_expect(not player.ads, "sights up 0.1 s into the raise")
	await _seconds(0.2)
	_expect(player.ads, "sights still down 0.3 s after aiming out of a sprint")
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
	# A 75 deg hip view at 1.3x magnification is 61.1 deg, worked by hand.
	_expect(absf(hip_fov - 75.0) < 0.01, "hip FOV is %.1f, the check below assumes 75" % hip_fov)
	_expect(absf(player.camera.fov - 61.1) < 0.5,
			"ADS FOV is %.1f, expected 61.1 for %.1fx zoom" % [player.camera.fov, profile.ads_zoom])
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
	await _dummy(4, 1.5)
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == dummy, "a dummy 1.5 m ahead was not the melee target")
	_expect(dummy.health.current == 1, "a front hit on 4 HP left %d, not 1" % dummy.health.current)
	await _cycle()

	await _place(RUNWAY)
	await _dummy(4, 3.0)
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == null, "a dummy 3 m ahead was hit by a melee")
	_expect(dummy.health.current == 4, "a dummy 3 m ahead took melee damage")
	await _cycle()

	await _place(RUNWAY)
	await _dummy(4, 1.5, 20.0)
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == null, "a dummy 20 deg off the axis was hit by a melee")
	_expect(dummy.health.current == 4, "a dummy 20 deg off the axis took melee damage")
	await _cycle()

	# A body just outside the cone but close enough for the crosshair ray to
	# graze is still swept by the whiff: no lunge, but the blow lands. (The
	# ray leaves the eyes at 1.6 m, up in the capsule's top cap, so the body
	# has to be near.)
	await _place(RUNWAY)
	await _dummy(4, 0.75, 17.0)
	_expect(player.melee_target() == null, "a dummy 17 deg off the axis was inside the cone")
	var before := player.global_position
	await _swing()
	_expect(swings.size() == 1 and swings[0][0] == dummy, "the whiff ray did not sweep a dummy 0.75 m ahead")
	_expect(dummy.health.current == 1, "a swept dummy took %d damage, not 3" % (4 - dummy.health.current))
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
	await _dummy(9, 1.9, 10.0)
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
	_expect(dummy.health.current == 6, "the lunge landed %d damage, not 3" % (9 - dummy.health.current))
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
## outright; from the front it does its 3.
func _check_melee_back_hit() -> void:
	await _place(RUNWAY)
	# Facing away from him: he is squarely behind.
	await _dummy(4, 1.5, 0.0, Vector3.FORWARD)
	await _swing()
	_expect(not dummy.is_alive(), "a back hit left the dummy on %d HP" % dummy.health.current)
	_expect(swings.size() == 1 and swings[0][1] == true, "the back-hit kill was not reported as one")
	await _cycle()

	# Facing him: front.
	await _place(RUNWAY)
	await _dummy(4, 1.5, 0.0, Vector3.BACK)
	await _swing()
	_expect(dummy.health.current == 1, "a front hit on 4 HP left %d, not 1" % dummy.health.current)
	_expect(swings.size() == 1 and swings[0][1] == false, "a front hit was reported as a kill")
	await _cycle()

	# Facing sideways: 90 deg from behind, outside the 60 deg half-cone.
	await _place(RUNWAY)
	await _dummy(4, 1.5, 0.0, Vector3.RIGHT)
	await _swing()
	_expect(dummy.health.current == 1, "a side hit on 4 HP left %d, not 1" % dummy.health.current)
	await _cycle()

	# Facing 50 deg off away: inside the back cone.
	await _place(RUNWAY)
	await _dummy(4, 1.5, 0.0, Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(50.0)))
	await _swing()
	_expect(not dummy.is_alive(), "a hit 50 deg inside the back cone left the dummy on %d HP" % dummy.health.current)
	await _cycle()


## A swing drops a running reload with nothing gained; the next R starts a
## fresh one at the full duration.
func _check_melee_cancels_reload() -> void:
	await _place(RUNWAY)
	await _dummy(4, 6.0)
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
	await _dummy(4, 6.0)
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
	_expect(_fire_and_drop(), "no shot for the recoil check")
	var push := 0.0
	var kick := 0.0
	var camera_kick := 0.0
	for i in 12:
		await physics_frame
		push = maxf(push, weapon.position.z - rest.z)
		kick = maxf(kick, weapon.rotation_degrees.x - rest_pitch)
		camera_kick = maxf(camera_kick, player.camera.rotation_degrees.x)
	_expect(push > 0.01, "the shot pushed the Viewmodel back only %.3f m" % push)
	_expect(kick > 1.5, "the shot kicked the Viewmodel up only %.1f deg" % kick)
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
	var mesh: Node3D = weapon.sidearm
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
	_expect(_mesh_at_identity(), "the mesh is off identity after the fire clip: %s %s" % [weapon.sidearm.position, weapon.sidearm.rotation_degrees])

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
	_expect(_mesh_at_identity(), "the reload cancel left the mesh at %s %s" % [weapon.sidearm.position, weapon.sidearm.rotation_degrees])

	# Empty reload on the dry pull.
	player.ammo = 0
	player.fire()
	await _frames(1)
	_expect(player.is_reloading(), "the dry pull did not reload")
	_expect(clips.current_animation == "reload_empty", "an empty reload played %s" % clips.current_animation)
	await _seconds(0.3)
	# A melee mid-reload cancels it and plays its own clip.
	await _dummy(4, 6.0)
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
	var sidearm: WeaponProfile = player.weapon
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
	player.weapon = sidearm
	await _place(RUNWAY)


## --- the Sidearm mesh ---

## The Viewmodel carries the Quaternius pistol: in ADS its front sight sits
## on the camera axis, from the hip it sits low right, and the shot leaves
## its muzzle.
func _check_sidearm_model() -> void:
	await _place(RUNWAY)
	var sidearm: Node3D = weapon.get_node_or_null("Sidearm")
	_expect(sidearm != null, "the Viewmodel has no Sidearm node")
	if sidearm == null:
		return
	_expect(weapon.sidearm == sidearm, "the Viewmodel's Sidearm node is not the pistol model")
	_expect(sidearm.find_child("Skeleton3D", true, false) != null, "the pistol has no skeleton")
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
func _check_sidearm_clips() -> void:
	await _place(RUNWAY)
	var anim: AnimationPlayer = weapon.sidearm_clips
	_expect(anim != null, "the Sidearm mesh has no AnimationPlayer")
	if anim == null:
		return
	var profile: WeaponProfile = player.weapon
	for clip_name in [profile.model_fire_clip, profile.model_reload_clip, profile.model_rack_clip]:
		_expect(anim.has_animation(clip_name), "the Sidearm mesh lacks the %s clip" % clip_name)
	_expect(not anim.is_playing(), "a pistol clip is playing at rest: %s" % anim.current_animation)
	_expect(_fire_and_drop(), "no shot for the pistol fire clip")
	await _frames(1)
	_expect(anim.current_animation == profile.model_fire_clip and anim.is_playing(), "a shot played %s on the Sidearm" % anim.current_animation)
	await _seconds(0.3)
	_expect(not anim.is_playing(), "the pistol fire clip outlasted 0.3 s")
	player.start_reload()
	await _frames(1)
	_expect(anim.current_animation == profile.model_reload_clip and anim.is_playing(), "a reload played %s on the Sidearm" % anim.current_animation)
	var wanted: float = anim.get_animation(profile.model_reload_clip).length / profile.reload_tactical
	_expect(absf(anim.get_playing_speed() - wanted) < 0.01, "the pistol reload runs at %.2fx, want %.2fx" % [anim.get_playing_speed(), wanted])
	await _seconds(0.4)
	var skeleton: Skeleton3D = weapon.sidearm.find_child("Skeleton3D", true, false)
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
	_expect(anim.current_animation == profile.model_reload_clip, "the empty reload played %s on the Sidearm" % anim.current_animation)
	await _seconds(profile.reload_empty - profile.rack_time / 2.0)
	_expect(anim.current_animation == profile.model_rack_clip and anim.is_playing(), "near the end of the empty reload the Sidearm plays %s, not the rack" % anim.current_animation)
	await _seconds(profile.rack_time / 2.0 + 0.1)
	_expect(not anim.is_playing(), "the Sidearm clip outlasted the empty reload")
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
	_expect(first_stream != null and first_stream.resource_path.contains("ppq_shot"), "the shot played %s" % [first_stream])
	sounds.clear()
	await _seconds(0.2)
	player.ammo = 0
	await _pull_trigger(30)
	_expect(_sounds_of(&"dry") == 1, "a held dry pull clicked %d times" % _sounds_of(&"dry"))
	_expect(_sounds_of(&"shot") == 0, "the dry pull played a shot")
	player.cancel_reload()
	await _frames(2)
	sounds.clear()

	await _place(RUNWAY)
	await _dummy(4, 6.0)
	await _swing()
	_expect(_sounds_of(&"melee") == 0, "a whiff into air played the melee landing")
	await _cycle()
	await _place(RUNWAY)
	await _dummy(9, 1.5)
	await _swing()
	_expect(_sounds_of(&"melee") == 1, "a landed melee played %d landing sounds" % _sounds_of(&"melee"))
	await _cycle()

	await _place(RUNWAY)
	player.take_damage(1)
	await _frames(1)
	_expect(_sounds_of(&"hit") == 1, "a hit taken played %d hit sounds" % _sounds_of(&"hit"))


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


## A bolt into the ship rings a metal impact where it struck and the ring
## frees itself; the sfx bus exists; a respawn mid-reload silences the rest
## of the reload and lands no thud.
func _check_audio_impact_and_respawn() -> void:
	_expect(AudioServer.get_bus_index("sfx") != -1, "no sfx bus in the layout")
	await _clear_dummy()
	await _place(RUNWAY)
	_clear_shots()
	var rings_before := _impact_rings()
	# Straight ahead into the backstop.
	var shot: Projectile3D = player.fire()
	_expect(shot != null, "no shot for the impact ring")
	await _seconds(0.4)
	_expect(_impact_rings() == rings_before + 1, "a bolt into the ship left %d rings, expected one" % (_impact_rings() - rings_before))
	await _seconds(1.2)
	_expect(_impact_rings() == rings_before, "the impact ring did not free itself")
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
