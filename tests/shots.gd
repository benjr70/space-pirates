extends SceneTree
## Offscreen screenshots for an agent to look at: the game rendered on the GPU
## with no display, a preset at a time, each frame checked cheaply before it
## is saved. Run it through `tests/shots.sh <preset> [args]`, which wraps it
## in `gamescope --backend headless` and checks the files; see
## `docs/agents/validation.md` for the presets and the defect checklist.
##
## It needs a real renderer: under `--headless` it says so and exits 1. It
## does no window work until [method _initialize], so it loads cleanly in a
## headless parse of every script.
##
## Presets (first argument after `--`):
##   viewmodel  hip, ads, low, tracer. wheel=<n> turns the weapon wheel n
##              places first (wheel=1 is the Assault Rifle); hip=x,y,z ads=x,y,z
##              low=x,y,z lowrot=x,y,z override the Viewmodel's poses;
##              pistol=1 scale=<f> rot=x,y,z pos=x,y,z hides the Holder and
##              mounts a fresh pistol.glb at that transform instead.
##   attachments each gun bare and in two full builds of Attachments, held
##              side-on and at the hip: <gun>_<bare|a|b>_<side|hip>.png.
##   scoped     aimed through each scope's lens and the Reflex Sight down a
##              long hall, each also with the gun 6 mm off its aimed pose;
##              measures the reticle's centre and a 1 m target's span at 50 m.
##   ship       class=<small|medium|large> seed=<n>: one shot per Room from a
##              corner at eye height, room_<i>_<role>.png, plus overview.png.
##   crew       one of each crew type side by side, front.png and side.png;
##              a Guard with each gun carried, walking and aimed
##              (guns_*.png), each gun's hands close up (hands_<gun>_<patrol|aim>.png)
##              and the Marksman Rifle's sight line (sight_line.png).
##   hud        the in-Raid HUD with known values: hud.png, hud_busy.png.
##   menu       the main menu's screens (home, classes), the Loadout screen
##              (loadout: bare; loadout_slot: a fitted Assault Rifle with its
##              Underbarrel list open) and the Raid's own (pause, death,
##              extracted).
##   scene      path=<res://...> cam=x,y,z look=x,y,z [fov=<deg>] [name=<png>]
##   sheet      the Sandbox sheet (F1) open in a Raid carrying a fitted Loadout:
##              sheet.png (strip and Weapons), sheet_attachments.png and
##              sheet_attachments_end.png (the Attachments table, top and
##              bottom, the Suppressor's loudness dialled to 0.5).
##
## Every preset takes out=<dir> (default res://.godot/shots/<preset>).
## Output lines the wrapper reads: `SHOT_EXPECT <file>` for each frame the
## preset will save, `SHOT_SAVED <file>`, `SHOT_FAIL <file>: <why>` when a
## frame fails a check, and `SHOTS_DONE ok|fail` last.

## A frame whose every sampled channel stays inside this range is one flat
## colour: black, a clear colour, nothing drawn.
const FLAT_RANGE := 0.03
## Pure magenta is Godot's missing-texture colour; more than this share of
## sampled pixels fails the frame.
const MAGENTA_MAX := 0.005
## Pirate's eye height, metres, for the Room shots.
const EYE_HEIGHT := 1.6
const ROOM_FOV := 90.0

var preset := ""
var args := {}
var out := ""
var failed := false
var _expected: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var at := a.find("=")
		if at < 0:
			if preset == "":
				preset = a
		else:
			args[a.substr(0, at)] = a.substr(at + 1)
	if DisplayServer.get_name() == "headless":
		printerr("shots: needs a renderer, not --headless; run it through tests/shots.sh")
		print("SHOTS_DONE fail")
		quit(1)
		return
	out = args.get("out", "res://.godot/shots/%s" % preset)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# A Raid a preset builds banks into a throwaway profile, never the
	# player's; the menu then shows a fresh level 1 pirate.
	Profile.path = "user://shots_profile_%d.cfg" % OS.get_process_id()
	_run()


func _run() -> void:
	match preset:
		"viewmodel": await _viewmodel()
		"attachments": await _attachments()
		"scoped": await _scoped()
		"ship": await _ship()
		"crew": await _crew()
		"hud": await _hud()
		"menu": await _menu()
		"scene": await _scene()
		"sheet": await _sheet()
		_:
			printerr("shots: unknown preset '%s'; want viewmodel, attachments, scoped, ship, crew, hud, menu, scene or sheet" % preset)
			failed = true
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.path))
	print("SHOTS_DONE ", "fail" if failed else "ok")
	quit(1 if failed else 0)


# --- viewmodel -------------------------------------------------------------

func _viewmodel() -> void:
	_expect(["hip", "ads", "low", "tracer"])
	var world := _test_room()
	# Two crew, one of each rig if the draw allows, standing 3 m off facing him.
	for i in 2:
		var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
		crew.position = Vector3(-0.9 + i * 1.8, 0.0, -3.0)
		world.add_child(crew)
		crew.set_physics_process(false)
		crew.face_direction(Vector3.BACK)
	var player: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.position = Vector3.ZERO
	var weapon: Node3D = player.get_node("Head/Camera3D/Weapon")
	if args.get("pistol", "") == "1":
		weapon.get_node("Holder").visible = false
		var holder := Node3D.new()
		holder.name = "PistolHolder"
		holder.add_child(load("res://assets/models/pistol/pistol.glb").instantiate())
		holder.scale = Vector3.ONE * float(args.get("scale", "0.02"))
		holder.rotation_degrees = _v3(args.get("rot", "0,-90,0"))
		holder.position = _v3(args.get("pos", "0,0,0"))
		weapon.add_child(holder)
	var wheel := int(args.get("wheel", "0"))
	if wheel != 0:
		# Drawn on the spot: a copy of the next weapon with no swap time.
		var index := posmod(player.weapons.find(player.weapon) + wheel, player.weapons.size())
		var drawn: WeaponProfile = player.weapons[index].duplicate()
		drawn.swap_time = 0.0
		player.weapons[index] = drawn
		player.switch_weapon(wheel)
	if args.has("hip"):
		weapon.pose_hip = _v3(args.hip)
		weapon.position = weapon.pose_hip
	if args.has("ads"):
		weapon.pose_ads = _v3(args.ads)
	if args.has("low"):
		weapon.pose_low = _v3(args.low)
	if args.has("lowrot"):
		weapon.rotation_low = _v3(args.lowrot)
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _snap("hip")
	player.set_physics_process(false)
	weapon.set_process(false)
	weapon.position = weapon.pose_ads
	weapon.rotation_degrees = weapon.rotation_hip
	await _snap("ads")
	weapon.position = weapon.pose_low
	weapon.rotation_degrees = weapon.rotation_low
	await _snap("low")
	# A bolt in flight, caught a few metres out, for the tracer's look.
	weapon.position = weapon.pose_hip
	weapon.rotation_degrees = weapon.rotation_hip
	player.set_physics_process(true)
	# Pitched up a touch so the bolts have the back wall to fly to.
	player.head.rotation.x = 0.12
	player.fire()
	await physics_frame
	await process_frame
	await process_frame
	_save("tracer")


# --- attachments -----------------------------------------------------------

## Per gun, two full builds (Slot to Attachment file stem) that between them
## show every Attachment the gun takes but the Assault Rifle's Suppressor and
## Extended Magazine, which the other guns show.
const BUILDS := {
	"pistol": [
		["reflex_sight", "suppressor", "extended_magazine", "laser"],
		["reflex_sight", "quick_magazine"],
	],
	"assault_rifle": [
		["reflex_sight", "short_barrel", "quick_magazine", "laser", "heavy_stock"],
		["combat_scope", "long_barrel", "drum", "bipod", "light_stock"],
	],
	"shotgun": [
		["reflex_sight", "long_barrel", "foregrip", "heavy_stock"],
		["short_barrel", "laser", "light_stock"],
	],
	"marksman_rifle": [
		["long_scope", "suppressor", "extended_magazine", "foregrip", "heavy_stock"],
		["long_scope", "long_barrel", "quick_magazine", "bipod", "light_stock"],
	],
}


## Each gun bare and in its two builds, held side-on in front of the eye
## (barrel left) and at the hip: `<gun>_<bare|a|b>_<side|hip>.png`.
func _attachments() -> void:
	var labels: Array = []
	for gun: String in BUILDS:
		for build in ["bare", "a", "b"]:
			labels.append_array(["%s_%s_side" % [gun, build], "%s_%s_hip" % [gun, build]])
	_expect(labels)
	var world := _test_room()
	var player: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.position = Vector3.ZERO
	var weapon: Viewmodel = player.get_node("Head/Camera3D/Weapon")
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_physics_process(false)
	weapon.set_process(false)
	for gun: String in BUILDS:
		var bare: WeaponProfile = load("res://resources/weapons/%s.tres" % gun)
		var at: int = player.weapons.find(bare)
		var builds: Array = [[]]
		builds.append_array(BUILDS[gun])
		for i in builds.size():
			var choice := {}
			for file: String in builds[i]:
				var attachment: Attachment = load("res://resources/attachments/%s.tres" % file)
				choice[attachment.slot] = attachment
			var built: WeaponProfile = bare.build(choice)
			if built == null:
				printerr("shots: %s refused %s" % [gun, builds[i]])
				failed = true
				continue
			# Drawn on the spot: no swap dip.
			built.swap_time = 0.0
			player.weapons[at] = built
			player.weapon = built
			var label := "%s_%s" % [gun, ["bare", "a", "b"][i]]
			# Side-on, barrel to the left, the long guns held further off.
			var long_gun := gun != "pistol"
			weapon.position = Vector3(0.12, -0.03, -1.45) if long_gun else Vector3(-0.05, 0.0, -0.66)
			weapon.basis = Basis(Vector3.UP, -PI / 2)
			await _snap(label + "_side")
			weapon.position = weapon.pose_hip
			weapon.rotation_degrees = weapon.rotation_hip
			await _snap(label + "_hip")
		player.weapons[at] = bare


# --- scoped ----------------------------------------------------------------

## Each Sight aimed through, by gun and Attachment file stem, as
## `<label>.png` and `<label>_shifted.png`.
const SCOPED := [
	["long_scope", "marksman_rifle", "long_scope"],
	["combat_scope", "assault_rifle", "combat_scope"],
	["reflex", "assault_rifle", "reflex_sight"],
]
## How far the gun is pushed off its aimed pose for the shifted shots.
const SCOPED_SHIFT := 0.006
## The reticle's centre on the screen's centre within this many pixels, and
## the target's span in the lens within this share of what the lens's zoom
## gives (`.scratch/weapon-attachments/issues/20-scoped-view-and-reflex-sight.md`).
const RETICLE_TOLERANCE := 2.0
const SPAN_TOLERANCE := 0.05
## The target: 1 m wide at 50 m, pure blue and unlit, at eye height.
const TARGET_RANGE := 50.0
const TARGET_WIDTH := 1.0


## Down a long lit hall with a blue board 1 m wide at 50 m, aimed through the
## Long Scope, the Combat Scope and the Reflex Sight, each also with the gun
## shifted 6 mm off its aimed pose. Each frame's reticle centre is measured
## against the screen's centre, and in the lens the board's span against what
## the lens's zoom should give; either out of tolerance fails the frame.
func _scoped() -> void:
	var labels: Array = []
	for case: Array in SCOPED:
		labels.append_array([case[0], case[0] + "_shifted"])
	_expect(labels)
	var world := _hall()
	var player: CharacterBody3D = load("res://scenes/player_3d.tscn").instantiate()
	world.add_child(player)
	player.position = Vector3.ZERO
	var weapon: Viewmodel = player.get_node("Head/Camera3D/Weapon")
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.set_physics_process(false)
	weapon.set_process(false)
	var hip_tan := tan(deg_to_rad(player.hip_fov()) * 0.5)
	for case: Array in SCOPED:
		var bare: WeaponProfile = load("res://resources/weapons/%s.tres" % case[1])
		var attachment: Attachment = load("res://resources/attachments/%s.tres" % case[2])
		var built: WeaponProfile = bare.build({attachment.slot: attachment})
		built.swap_time = 0.0
		player.weapons[player.weapons.find(bare)] = built
		player.weapon = built
		# Sights all the way up, the view zoomed as aiming leaves it.
		player.ads = true
		player.aim_progress = 1.0
		player.camera.fov = rad_to_deg(2.0 * atan(hip_tan / built.view_zoom()))
		weapon.rotation_degrees = weapon.rotation_hip
		for shifted in [false, true]:
			var label: String = case[0] + ("_shifted" if shifted else "")
			var shift := Vector3(1, -1, 0).normalized() * SCOPED_SHIFT if shifted else Vector3.ZERO
			weapon.position = weapon.pose_ads + shift
			print("shots: %s: %s with %s, view zoom %.2fx, lens zoom %s, gun shifted %s" % [label, case[1], case[2],
					built.view_zoom(), "%.2fx" % built.ads_zoom if built.aims_through_lens else "none", shift])
			await _snap(label)
			var img := root.get_viewport().get_texture().get_image()
			_measure_reticle(label, img)
			if built.aims_through_lens:
				var want := TARGET_WIDTH / TARGET_RANGE * built.ads_zoom / hip_tan * img.get_height() * 0.5
				_measure_span(label, img, want)
		player.weapons[player.weapons.find(built)] = bare
		player.ads = false
		player.aim_progress = 0.0


## The red reticle's centre (a weighted centroid of red within 12 px of the
## middle) on the screen's centre within RETICLE_TOLERANCE pixels.
func _measure_reticle(label: String, img: Image) -> void:
	var middle := Vector2(img.get_width(), img.get_height()) * 0.5
	var sum := Vector2.ZERO
	var weight := 0.0
	for y in range(int(middle.y) - 12, int(middle.y) + 12):
		for x in range(int(middle.x) - 12, int(middle.x) + 12):
			var c := img.get_pixel(x, y)
			var red := c.r - maxf(c.g, c.b)
			if c.r > 0.5 and red > 0.3:
				sum += Vector2(x + 0.5, y + 0.5) * red
				weight += red
	if weight == 0.0:
		print("SHOT_FAIL %s.png: no red reticle within 12 px of the middle" % label)
		failed = true
		return
	var centre := sum / weight
	var off := centre.distance_to(middle)
	print("SHOT_MEASURE %s.png: reticle centre %s, screen centre %s, off by %.2f px (want within %.1f)" % [
			label, centre, middle, off, RETICLE_TOLERANCE])
	if off > RETICLE_TOLERANCE:
		print("SHOT_FAIL %s.png: the reticle's centre is %.2f px off the screen's centre" % [label, off])
		failed = true


## The blue target's span in the lens, read along a row 5 px above the
## middle (clear of the cross's arms and centre dot), over the unbroken run
## of blue pixels through the middle: each counts by how blue it is against
## the bluest, in linear light, so a part-covered edge pixel counts by the
## share it covers. Within SPAN_TOLERANCE of [param want] pixels.
func _measure_span(label: String, img: Image, want: float) -> void:
	var y := img.get_height() / 2 - 5
	var middle := img.get_width() / 2
	var bluest := _blueness(img.get_pixel(middle, y))
	if bluest < 0.3:
		print("SHOT_FAIL %s.png: no blue target in the middle of the lens" % label)
		failed = true
		return
	var span := 0.0
	for step in [-1, 1]:
		var x: int = middle if step == 1 else middle - 1
		while x >= 0 and x < img.get_width():
			var blue := _blueness(img.get_pixel(x, y))
			if blue < 0.05 * bluest:
				break
			span += blue / bluest
			x += step
	var share := span / want - 1.0
	print("SHOT_MEASURE %s.png: target spans %.1f px in the lens, want %.1f, off by %.1f%% (want within %.0f%%)" % [
			label, span, want, share * 100.0, SPAN_TOLERANCE * 100.0])
	if absf(share) > SPAN_TOLERANCE:
		print("SHOT_FAIL %s.png: the target spans %.1f px in the lens, want %.1f" % [label, span, want])
		failed = true


## How much bluer than red or green [param c] is, in linear light.
static func _blueness(c: Color) -> float:
	var linear := c.srgb_to_linear()
	return maxf(linear.b - maxf(linear.r, linear.g), 0.0)


## A lit hall 12 m wide running 90 m ahead (-Z), crates and two crew along
## it, and the blue target board 1 m wide at 50 m on a pale wall just behind.
func _hall() -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	_box(world, Vector3(12, 0.2, 100), Vector3(0, -0.1, -40), Color(0.35, 0.36, 0.4))
	_box(world, Vector3(12, 0.2, 100), Vector3(0, 4.1, -40), Color(0.3, 0.3, 0.32))
	_box(world, Vector3(0.2, 4, 100), Vector3(-6, 2, -40), Color(0.45, 0.47, 0.5))
	_box(world, Vector3(0.2, 4, 100), Vector3(6, 2, -40), Color(0.5, 0.48, 0.45))
	_box(world, Vector3(12, 4, 0.2), Vector3(0, 2, -90), Color(0.5, 0.55, 0.6))
	_box(world, Vector3(6, 3, 0.2), Vector3(0, 1.5, -(TARGET_RANGE + 1.0)), Color(0.8, 0.8, 0.78))
	for at in [Vector3(-3.5, 0.5, -6), Vector3(3, 0.5, -14), Vector3(-2.5, 0.5, -25), Vector3(2.5, 0.5, -38)]:
		_box(world, Vector3(1, 1, 1), at, Color(0.6, 0.45, 0.3))
	for i in 2:
		var crew: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
		crew.position = Vector3(-1.6 + i * 3.4, 0.0, -9.0 - i * 9.0)
		world.add_child(crew)
		crew.set_physics_process(false)
		crew.face_direction(Vector3.BACK)
	var board := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(TARGET_WIDTH, 1.0)
	board.mesh = quad
	var unlit := StandardMaterial3D.new()
	unlit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unlit.albedo_color = Color(0, 0, 1)
	board.material_override = unlit
	board.position = Vector3(0, 1.6, -TARGET_RANGE)
	world.add_child(board)
	_light(world)
	return world


# --- ship ------------------------------------------------------------------

func _ship() -> void:
	var ship_class := StringName(String(args.get("class", "medium")).to_lower())
	if not ship_class in ShipGenerator.CLASSES:
		printerr("shots: unknown class '%s'; want small, medium or large" % ship_class)
		failed = true
		return
	var seed := int(args.get("seed", "1"))
	var report := ShipGenerator.generate_report(ship_class, seed)
	var layout := report.layout
	print("shots: %s seed %d, \"%s\": rooms=%d counted=%d" % [ship_class, seed, layout.display_name(),
			layout.rooms.size(), report.counted_rooms])
	var labels: Array[String] = []
	for i in layout.rooms.size():
		labels.append(_room_label(layout, i))
	labels.append("overview")
	_expect(labels)

	var main := _raid_scene(layout, false)
	var ship: Node3D = main.get_node("Ship")
	main.get_node("Hud").visible = false
	var player: Node3D = main.get_node("Player")
	player.visible = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	# Held at their posts so every Room shows its crew where they stand.
	for crew in get_nodes_in_group(&"crew"):
		crew.set_physics_process(false)
	var cam := Camera3D.new()
	main.add_child(cam)
	cam.make_current()
	# Let the reveal tweens bring every Room's light up.
	await create_timer(0.6).timeout

	cam.fov = ROOM_FOV
	var space := root.get_world_3d().direct_space_state
	for i in layout.rooms.size():
		var pair := _room_camera(layout.rooms[i])
		cam.look_at_from_position(pair[0], pair[1])
		var probe := PhysicsPointQueryParameters3D.new()
		probe.position = pair[0]
		if not space.intersect_point(probe, 1).is_empty():
			print("SHOT_WARN %s.png: camera starts inside geometry" % labels[i])
		print("shots: %s from %s toward %s" % [labels[i], pair[0], pair[1]])
		await _snap(labels[i])

	# Straight down with the ceiling off, orthographic over the whole floor.
	ship.get_node("Ceiling").visible = false
	var bounds := Rect2i()
	for r in layout.rooms:
		bounds = r.bounds() if bounds.size == Vector2i.ZERO else bounds.merge(r.bounds())
	var mid := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var aspect := float(root.size.x) / float(root.size.y)
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = maxf(bounds.size.y, bounds.size.x / aspect) + 4.0
	cam.far = 200.0
	cam.position = Vector3(mid.x, 60.0, mid.y)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	# Room lights alone leave the floor plan murky from up here; a sun from
	# straight above shows every Room, prop and doorway. Overview only.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-90, 0, 0)
	sun.light_energy = 0.6
	main.add_child(sun)
	await _snap("overview")


func _room_label(layout: ShipLayout, i: int) -> String:
	return "room_%02d_%s" % [i, layout.rooms[i].role]


## [eye, target]: from the corner of the Room's largest rect farthest from
## any prop or crew post, across the floor to the opposite corner.
func _room_camera(room: RoomData) -> Array:
	var r := room.largest_rect()
	var inset := 0.7
	var lo := Vector2(r.position) + Vector2(inset, inset)
	var hi := Vector2(r.end) - Vector2(inset, inset)
	var corners := [Vector2(lo.x, lo.y), Vector2(hi.x, lo.y), Vector2(hi.x, hi.y), Vector2(lo.x, hi.y)]
	var blockers: Array[Vector2] = []
	for prop in room.props:
		blockers.append(Vector2(prop.get("tile", Vector2i.ZERO)) + Vector2(0.5, 0.5))
	for spawn in room.crew_spawns:
		blockers.append(Vector2(spawn) + Vector2(0.5, 0.5))
	var best := 0
	var best_clear := -1.0
	for c in 4:
		var clear := 1e9
		for b in blockers:
			clear = minf(clear, corners[c].distance_to(b))
		if clear > best_clear:
			best_clear = clear
			best = c
	var eye: Vector2 = corners[best]
	var far: Vector2 = corners[(best + 2) % 4]
	return [Vector3(eye.x, EYE_HEIGHT, eye.y), Vector3(far.x, 1.0, far.y)]


# --- crew ------------------------------------------------------------------

func _crew() -> void:
	var guns := ["pistol", "assault_rifle", "shotgun", "marksman_rifle"]
	var labels := ["front", "side", "guns_patrol_front", "guns_patrol_side", "guns_walk_side", "guns_aim_front", "guns_aim_side"]
	for gun in guns:
		labels.append("hands_%s_patrol" % gun)
		labels.append("hands_%s_aim" % gun)
	labels.append("sight_line")
	_expect(labels)
	var world := _test_room()
	var crew: Array[Crew3D] = []
	var types := [CrewTypes.Type.GUARD, CrewTypes.Type.WORKER]
	for i in types.size():
		var body: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
		body.crew_type = types[i]
		body.position = Vector3(-0.9 + i * 1.8, 0.0, -1.0)
		world.add_child(body)
		body.set_physics_process(false)
		crew.append(body)
	print("shots: left is the Guard, right the Worker")
	var cam := Camera3D.new()
	cam.fov = 50.0
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.2, 3.4), Vector3(0, 1.0, -1.0))
	cam.make_current()
	for body in crew:
		body.face_direction(Vector3.BACK)
	await _snap("front")
	for body in crew:
		body.face_direction(Vector3.LEFT)
	await _snap("side")
	for body in crew:
		body.free()

	# A Guard with each gun (crew-combat ticket 16), left to right: Pistol,
	# Assault Rifle, Shotgun, Marksman Rifle; carrying on patrol, walking,
	# and aimed; then each one's hands close up.
	var guards: Array[Crew3D] = []
	for i in guns.size():
		var guard: Crew3D = load("res://scenes/crew_3d.tscn").instantiate()
		guard.weapon = load("res://resources/weapons/%s.tres" % guns[i])
		guard.position = Vector3(-2.4 + i * 1.6, 0.0, -1.0)
		world.add_child(guard)
		guard.set_physics_process(false)
		guards.append(guard)
	print("shots: guns_* and hands_*: Pistol, Assault Rifle, Shotgun, Marksman Rifle, left to right")
	cam.fov = 60.0
	# Front: facing the camera. Side: facing left along the row, seen from
	# their left (the closeups show the right).
	cam.look_at_from_position(Vector3(0, 1.3, 3.6), Vector3(0, 1.0, -1.0))
	await _hold_guards(guards, false, Vector3.BACK)
	await _snap("guns_patrol_front")
	await _hold_guards(guards, false, Vector3.LEFT)
	await _snap("guns_patrol_side")
	await _hold_guards(guards, false, Vector3.LEFT, 1.4)
	await _snap("guns_walk_side")
	await _hold_guards(guards, true, Vector3.BACK)
	await _snap("guns_aim_front")
	await _hold_guards(guards, true, Vector3.LEFT)
	await _snap("guns_aim_side")
	cam.fov = 40.0
	for i in guns.size():
		var guard := guards[i]
		for aimed in [false, true]:
			await _hold_guards(guards, aimed, Vector3.BACK)
			var hands := guard.gun.hand_place_global("grip").origin.lerp(guard.gun.hand_place_global("fore").origin, 0.5)
			# From its right front, a little above the hands.
			cam.look_at_from_position(hands + Vector3(-0.75, 0.25, 0.85), hands)
			await _snap("hands_%s_%s" % [guns[i], "aim" if aimed else "patrol"])

	# The Marksman Rifle's sight line (crew-combat ticket 20) from its
	# rifle's muzzle to a point across the room, as a Guard shows it.
	var marksman := guards[3]
	await _hold_guards(guards, true, Vector3.RIGHT)
	var line := CrewSightLine.new()
	world.add_child(line)
	var muzzle := marksman.gun.muzzle_point()
	line.show_between(muzzle, muzzle + Vector3(6.0, -0.3, 1.5))
	cam.fov = 50.0
	cam.look_at_from_position(marksman.global_position + Vector3(-1.0, 1.5, 3.4), marksman.global_position + Vector3(1.0, 1.2, 0))
	print("shots: the Marksman Rifle Guard's sight line runs from its muzzle off to the right")
	await _snap("sight_line")


## Every Guard in [param guards] faced along [param facing], its gun carried
## (on patrol, walking at [param walking] m/s when above zero) or aimed
## there, the hold reached at once.
func _hold_guards(guards: Array[Crew3D], aimed: bool, facing: Vector3, walking := 0.0) -> void:
	for guard in guards:
		guard.face_direction(facing)
		guard.state = Crew3D.State.FIGHT if aimed else Crew3D.State.PATROL
		guard.velocity = facing * walking
		guard._update_animation()
		guard.gun.aim = 1.0 if aimed else 0.0
	for i in 3:
		await process_frame
	for guard in guards:
		guard.gun.aim = 1.0 if aimed else 0.0


# --- hud and menu ----------------------------------------------------------

## The Raid scene on a small seed-1 target, the Pirate stood in his Boarding
## Pod as at the start of a Raid, with the HUD showing known values.
func _hud_raid() -> Node3D:
	var main := _raid_scene(ShipGenerator.generate(&"small", 1), true)
	for i in 4:
		await process_frame
	var player: CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hud: Hud = main.get_node("Hud")
	hud.set_max_health(player.health.max_health)
	hud.set_health(maxi(1, player.health.max_health - 2))
	hud.set_ammo(5)
	hud.set_loot(240)
	print("shots: HUD set to health %d of %d, ammo 5, Loot 240" % [
			maxi(1, player.health.max_health - 2), player.health.max_health])
	return main


func _hud() -> void:
	_expect(["hud", "hud_busy"])
	var main := await _hud_raid()
	await create_timer(0.5).timeout
	await _snap("hud")
	var hud: Hud = main.get_node("Hud")
	hud.set_alarm(true)
	hud.toast("+150 XP  unaware")
	hud.set_ammo(0)
	print("shots: hud_busy adds the Alarm, a toast and an empty magazine")
	await _snap("hud_busy")


func _menu() -> void:
	_expect(["home", "classes", "loadout", "loadout_slot", "pause", "death", "extracted"])
	var menu: Node3D = load(Raid.MENU_SCENE).instantiate()
	root.add_child(menu)
	await _snap("home")
	var column := menu.get_node("UI/Root/Column")
	(column.get_node("Home/Play") as Button).pressed.emit()
	await _snap("classes")
	await _loadout_shots(menu)
	root.remove_child(menu)
	menu.free()

	var main := await _hud_raid()
	var pause: PauseMenu = main.get_node("PauseMenu")
	pause.pause()
	await _snap("pause")
	pause.resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The Raid scene hides the HUD under either end screen; the screens are
	# raised here by hand so nothing is settled into the player's Profile.
	main.get_node("Hud").visible = false
	var end: RaidEndScreen = main.get_node("RaidEndScreen")
	end.show_death("Shot by a Guard\nLost 240 gold")
	await _snap("death", 0.8)
	end.show_extracted("Out in 3:12\n+240 gold  +400 XP")
	await _snap("extracted", 0.8)


## The Loadout screen opened from the home list: the default Loadout bare,
## then the Assault Rifle fitted all round with its Underbarrel list open.
## Saves only into the preset's throwaway Profile.
func _loadout_shots(menu: Node) -> void:
	(menu.get_node("UI/Root/Column/Classes/Back") as Button).pressed.emit()
	(menu.get_node("UI/Root/Column/Home/Loadout") as Button).pressed.emit()
	await _snap("loadout")
	var screen: LoadoutScreen = menu.get_node("UI/LoadoutScreen")
	screen.choose_place(1)
	for fit: Array in [[Attachment.Slot.SIGHT, "combat_scope"], [Attachment.Slot.BARREL, "suppressor"],
			[Attachment.Slot.MAGAZINE, "drum"], [Attachment.Slot.UNDERBARREL, "laser"], [Attachment.Slot.STOCK, "light_stock"]]:
		screen.toggle_slot(fit[0])
		screen.fit(load("res://resources/attachments/%s.tres" % fit[1]))
	screen.toggle_slot(Attachment.Slot.UNDERBARREL)
	await _snap("loadout_slot")
	screen.leave()


# --- sheet -----------------------------------------------------------------

## The Sandbox sheet over a Raid carrying the Assault Rifle with a Suppressor
## and a Drum, then the Pistol: Built Weapon values beside the bare ones.
## Nothing is saved; the dialled factor is reverted before the end.
func _sheet() -> void:
	_expect(["sheet", "sheet_attachments", "sheet_attachments_end"])
	var rifle: WeaponProfile = load("res://resources/weapons/assault_rifle.tres")
	var loadout := Loadout.new()
	loadout.set_first(rifle)
	loadout.set_second(load("res://resources/weapons/pistol.tres"))
	loadout.set_attachment(rifle, Attachment.Slot.BARREL, load("res://resources/attachments/suppressor.tres"))
	loadout.set_attachment(rifle, Attachment.Slot.MAGAZINE, load("res://resources/attachments/drum.tres"))
	Raid.ship_class = &"small"
	Raid.seed = 1
	Raid.arm(loadout)
	var main := await _hud_raid()
	var view: SandboxSheetView = main.get_node("SandboxSheet")
	view.open()
	await _snap("sheet")
	var table := view.sheet.table(SandboxSheet.ATTACHMENTS)
	(view.cell(SandboxSheet.ATTACHMENTS, &"loudness", table.columns.find("Suppressor")) as SpinBox).value = 0.5
	var scroll: ScrollContainer = view.find_child("Scroll", true, false)
	await process_frame
	var tables := scroll.get_child(0)
	scroll.scroll_vertical = int(tables.get_child(tables.get_child_count() - 1).position.y)
	await _snap("sheet_attachments")
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _snap("sheet_attachments_end")
	view.revert_button().pressed.emit()
	Raid.seed = 0
	Raid.weapons = []


# --- scene -----------------------------------------------------------------

func _scene() -> void:
	var path: String = args.get("path", "")
	if path == "" or not args.has("cam") or not args.has("look"):
		printerr("shots: scene wants path=<res://...> cam=x,y,z look=x,y,z")
		failed = true
		return
	var label: String = String(args.get("name", path.get_file().get_basename())).trim_suffix(".png")
	_expect([label])
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("shots: cannot load scene %s" % path)
		failed = true
		return
	var node := packed.instantiate()
	root.add_child(node)
	# A bare prop or model brings no light of its own: lend it the test room's.
	if node.find_children("*", "WorldEnvironment", true, false).is_empty() and not node is WorldEnvironment:
		_light(root)
		print("shots: %s has no WorldEnvironment; lit with the shot script's own" % path)
	var cam := Camera3D.new()
	cam.fov = float(args.get("fov", "70"))
	root.add_child(cam)
	cam.look_at_from_position(_v3(args.cam), _v3(args.look))
	cam.make_current()
	await _snap(label)


# --- building blocks -------------------------------------------------------

## The Raid scene on [param layout], lit throughout or boarded as in play.
func _raid_scene(layout: ShipLayout, dark: bool) -> Node3D:
	var main: Node3D = load(Raid.RAID_SCENE).instantiate()
	main.layout_override = layout
	main.explore_darkness = dark
	root.add_child(main)
	return main


## A small lit room: floor, ceiling, a back wall and a crate.
func _test_room() -> Node3D:
	var world := Node3D.new()
	root.add_child(world)
	_box(world, Vector3(8, 0.2, 8), Vector3(0, -0.1, 0), Color(0.35, 0.36, 0.4))
	_box(world, Vector3(8, 0.2, 8), Vector3(0, 3.6, 0), Color(0.3, 0.3, 0.32))
	_box(world, Vector3(8, 3.5, 0.2), Vector3(0, 1.75, -4), Color(0.5, 0.55, 0.6))
	_box(world, Vector3(1.0, 1.1, 1.0), Vector3(0.0, 0.55, -2.5), Color(0.6, 0.45, 0.3))
	_light(world)
	return world


## A key light and the same reflection-only sky as main_3d.tscn, so metal
## reads as it does in the game.
func _light(parent: Node) -> void:
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.2
	parent.add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.1, 0.1, 0.12)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 0.8
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.45, 0.47, 0.5)
	sm.sky_horizon_color = Color(0.7, 0.72, 0.75)
	sm.ground_bottom_color = Color(0.08, 0.08, 0.09)
	sm.ground_horizon_color = Color(0.3, 0.3, 0.32)
	sm.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sm
	e.sky = sky
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment = e
	parent.add_child(env)


func _box(parent: Node, size: Vector3, at: Vector3, color: Color) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	b.add_child(mi)
	b.position = at
	parent.add_child(b)


func _v3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


# --- capture and checks ----------------------------------------------------

func _expect(labels: Array) -> void:
	for label in labels:
		_expected.append("%s.png" % label)
		print("SHOT_EXPECT %s.png" % label)


## Saves the frame after a few frames have drawn, and [param settle]
## seconds more for anything that fades in.
func _snap(label: String, settle := 0.0) -> void:
	for i in 6:
		await process_frame
	if settle > 0.0:
		await create_timer(settle).timeout
	_save(label)


func _save(label: String) -> void:
	var file := "%s.png" % label
	var img := root.get_viewport().get_texture().get_image()
	var why := frame_defect(img)
	var err := img.save_png(ProjectSettings.globalize_path("%s/%s" % [out, file]))
	if err != OK:
		print("SHOT_FAIL %s: save_png error %d" % [file, err])
		failed = true
		return
	print("SHOT_SAVED ", file)
	if why != "":
		print("SHOT_FAIL %s: %s" % [file, why])
		failed = true


## Why a frame cannot be what was meant to be shot, or "" when it passes:
## one flat colour (nothing drawn), or too much of Godot's missing-texture
## magenta. Samples a grid of about 160 pixels across.
static func frame_defect(img: Image) -> String:
	var step := maxi(1, img.get_width() / 160)
	var lo := Color(1, 1, 1)
	var hi := Color(0, 0, 0)
	var magenta := 0
	var samples := 0
	for y in range(0, img.get_height(), step):
		for x in range(0, img.get_width(), step):
			var c := img.get_pixel(x, y)
			lo = Color(minf(lo.r, c.r), minf(lo.g, c.g), minf(lo.b, c.b))
			hi = Color(maxf(hi.r, c.r), maxf(hi.g, c.g), maxf(hi.b, c.b))
			if c.r > 0.9 and c.g < 0.1 and c.b > 0.9:
				magenta += 1
			samples += 1
	var spread := maxf(hi.r - lo.r, maxf(hi.g - lo.g, hi.b - lo.b))
	if spread < FLAT_RANGE:
		return "flat colour %s, nothing drawn" % lo.to_html(false)
	var share := float(magenta) / float(samples)
	if share > MAGENTA_MAX:
		return "%.1f%% magenta, a missing texture or material" % (share * 100.0)
	return ""
