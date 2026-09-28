class_name ShipGenerator
extends RefCounted
## A seeded generator for raid-target ships. Takes a Ship Class and a seed
## and emits a [ShipLayout] the builder consumes exactly as it consumes the
## hand-authored one. The seed is the ship's identity: the same seed always
## yields the same ship.
##
## Stages, in order, each fixed before the next runs: Class and Richness
## roll, Hull silhouette ([HullGrammar]), Room packing ([RoomPacker]) with the
## count-first area loop, Door stitching ([DoorStitcher]), Hatch placement
## ([HatchPlacer]), Role assignment ([RoleAssigner]), the Threat and Loot
## Budgets ([Budgets]) and interiors ([Interiors]: the shared vocabulary,
## then each Role's row of the flavour table, [RoleFlavour]) and the name
## ([ShipNamer]). Validation with bounded reroll lands on its own.

const CLASSES: Array[StringName] = [&"small", &"medium", &"large"]
## Counted (non-corridor) Room count per Class. Nothing rolls 7 or 12 to 13.
const ROOM_BAND := {&"small": Vector2i(4, 6), &"medium": Vector2i(8, 11), &"large": Vector2i(14, 18)}
## Mean of the 140 to 220 tiles a packed Room aims for, plus the overhead of corridor,
## shared walls, solid nose and tail, and the Bulk the Sliver rule leaves.
## Tuned so the first pack lands the wanted count about as often as not.
const ROOM_TARGET := 175
const SKELETON_OVERHEAD := 1.8
## How many times the Hull is rescaled and repacked when the counted Room
## count misses the Class band.
const MAX_RESIZES := 8
## A ship that fails any invariant ([ShipInvariants]) is rerolled from
## scratch, archetype included, on a sub-seed derived from the ship seed,
## this many times at most; the seed stays the ship's identity. The count
## is not a smooth function of area and some silhouettes cannot hold some
## counts, so a reroll is also how a Hull that never lands the band is
## replaced.
const MAX_REROLLS := 8


## What a generation run reports beyond the layout, for the harness and dumper.
class Report:
	extends RefCounted
	var layout: ShipLayout
	## Archetype, Skeleton, features and repairs, in one line.
	var sentence := ""
	## The Skeleton the Hull rolled: spine, ring or chain.
	var skeleton: StringName = &""
	## Hull rescales it took to land the Room count in band, on the emitted attempt.
	var resizes := 0
	## Whole-ship rerolls it took to emit a valid ship (see [constant MAX_REROLLS]).
	var rerolls := 0
	## Invariants the emitted ship still fails: empty for every ship the
	## generator is allowed to hand out, non-empty only when every reroll
	## failed too.
	var violations: Array[String] = []
	## Counted Room count inside the Class band.
	var in_band := true
	## Whether Hatches were placed, at some relaxation level.
	var hatches_placed := true
	var counted_rooms := 0
	var stranded := 0
	## Hatch placement relaxation level that was needed (see [HatchPlacer.Result]).
	var hatch_relaxed := 0


## The ship for a seed. Convenience over [method generate_report].
static func generate(ship_class: StringName, seed: int) -> ShipLayout:
	return generate_report(ship_class, seed).layout


## The ship for a seed with the account of how it was generated: the seed's
## own roll first, then, while the emitted ship fails an invariant, a
## fresh roll on the next sub-seed of the seed, up to [constant MAX_REROLLS]
## times. The last attempt is emitted either way, with its violations.
static func generate_report(ship_class: StringName, seed: int) -> Report:
	assert(ship_class in CLASSES, "unknown ship class %s" % ship_class)
	var report: Report
	for attempt in MAX_REROLLS + 1:
		report = _attempt(ship_class, seed, attempt)
		if report.violations.is_empty():
			break
	return report


## One roll of every stage on the seed's [param attempt]-th sub-seed.
static func _attempt(ship_class: StringName, seed: int, attempt: int) -> Report:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed(ship_class, seed, attempt)
	var band: Vector2i = ROOM_BAND[ship_class]
	var want := rng.randi_range(band.x, band.y)
	var richness := rng.randf()

	# Count first: size the Hull from the wanted count, and when the packed
	# count misses the band rescale the area by the miss and repack.
	var report := Report.new()
	report.rerolls = attempt
	var hull: HullGrammar.Hull
	var pack: RoomPacker.Result
	var doors: Array[RoomPacker.Gap] = []
	var layout: ShipLayout
	var hatches: HatchPlacer.Result
	var landed := false
	var archetype := HullGrammar.roll_archetype(ship_class, rng)
	var scale := 1.0
	# The count is not smooth in area, so once a scale has come in under
	# the band and another over it, the next tries lie between them.
	var under_scale := 0.0
	var over_scale := 0.0
	for resize in MAX_RESIZES:
		var target := int(want * ROOM_TARGET * SKELETON_OVERHEAD * scale * rng.randf_range(0.95, 1.05))
		hull = HullGrammar.roll(ship_class, rng, target, archetype)
		pack = RoomPacker.pack(hull, ship_class, band, rng)
		var got := pack.counted_rooms()
		report.resizes = resize
		landed = _landed(pack, band)
		if landed:
			# Stitching can strand a Room into Bulk, so the count is read again after it.
			doors = DoorStitcher.stitch(pack.patches, pack.seeded, rng)
			got = pack.counted_rooms()
			landed = _landed(pack, band)
		if landed:
			# Hatches need Rooms far enough apart; a ship that cannot hold
			# them is resized like one that missed the band.
			layout = _assemble(ship_class, seed, richness, pack, doors)
			hatches = HatchPlacer.place(layout, ship_class, rng, _pinned_roles(pack).size())
			landed = hatches.relaxed >= 0
		if landed:
			break
		if got < band.x:
			under_scale = maxf(under_scale, scale)
		elif got > band.y:
			over_scale = scale if over_scale == 0.0 else minf(over_scale, scale)
		if under_scale > 0.0 and over_scale > under_scale:
			scale = (under_scale + over_scale) / 2.0
		else:
			# Undamped: the spec's (wanted ÷ got)^0.6 step, clamped 0.75 to
			# 1.5, was tried and landed the band later on more seeds.
			scale *= clampf(float(want) / float(maxi(got, 1)), 0.6, 1.6)

	if not landed:
		doors = DoorStitcher.stitch(pack.patches, pack.seeded, rng)
		layout = _assemble(ship_class, seed, richness, pack, doors)
		hatches = HatchPlacer.place(layout, ship_class, rng, _pinned_roles(pack).size())
	layout.hatches = hatches.hatches
	layout.hatch_relaxation = maxi(hatches.relaxed, 0)
	RoleAssigner.assign(layout, ship_class, rng, _pinned_roles(pack))
	Budgets.apply(layout, ship_class)
	Interiors.furnish(layout, rng)
	layout.archetype = hull.arch
	layout.ship_name = ShipNamer.name_for(ship_class, seed, hull.arch)
	report.layout = layout
	report.skeleton = hull.skeleton
	report.hatch_relaxed = hatches.relaxed
	report.hatches_placed = hatches.relaxed >= 0
	# Read off the emitted ship: the last stitch can still strand a Room.
	report.counted_rooms = 0
	for room in layout.rooms:
		if room.role != &"corridor":
			report.counted_rooms += 1
	report.in_band = report.counted_rooms >= band.x and report.counted_rooms <= band.y
	for patch in pack.patches:
		if patch.stranded:
			report.stranded += 1
	report.violations = ShipInvariants.violations(layout, ship_class)

	var features := pack.features.duplicate()
	if report.stranded > 0:
		features.append("stranded×%d" % report.stranded)
	if report.resizes > 0:
		features.append("resize×%d" % report.resizes)
	if report.rerolls > 0:
		features.append("reroll×%d" % report.rerolls)
	if report.hatch_relaxed > 0:
		features.append("hatches relaxed×%d" % report.hatch_relaxed)
	elif report.hatch_relaxed < 0:
		features.append("NO HATCHES")
	if not report.in_band:
		features.append("OUT OF BAND")
	if not report.violations.is_empty():
		features.append("INVALID×%d" % report.violations.size())
	report.sentence = hull.sentence()
	if not features.is_empty():
		report.sentence += " / " + ", ".join(features)
	report.layout.gen_sentence = report.sentence
	return report


## Rooms whose packer tag survives Role assignment, by their index in the
## assembled layout (standing patches in order): {room: role}.
static func _pinned_roles(pack: RoomPacker.Result) -> Dictionary:
	var out := {}
	var index := 0
	for patch in pack.patches:
		if patch.is_empty():
			continue
		if patch.pinned:
			out[index] = patch.role
		index += 1
	return out


## Whether a pack has landed: counted Rooms in the Class band, with a Bridge
## and an Engine standing where the Skeleton ends.
static func _landed(pack: RoomPacker.Result, band: Vector2i) -> bool:
	var got := pack.counted_rooms()
	return got >= band.x and got <= band.y and pack.caps_on_axis \
			and pack.has_role(&"bridge") and pack.has_role(&"engine")


## The RNG seed for a Class and ship seed: stable across runs and machines.
## Attempt 0 is the seed's own roll; each reroll takes the next sub-seed.
static func rng_seed(ship_class: StringName, seed: int, attempt: int = 0) -> int:
	if attempt == 0:
		return hash("%s#%d" % [ship_class, seed])
	return hash("%s#%d#reroll%d" % [ship_class, seed, attempt])


## Turn packed patches and confirmed gaps into a [ShipLayout].
static func _assemble(ship_class: StringName, seed: int, richness: float,
		pack: RoomPacker.Result, doors: Array[RoomPacker.Gap]) -> ShipLayout:
	var layout := ShipLayout.new()
	layout.gen_seed = seed
	layout.ship_class = ship_class
	layout.richness = richness

	for patch in pack.patches:
		if patch.is_empty():
			continue
		var room := RoomData.new()
		room.rects = TileShapes.rects_from_tiles(patch.tiles)
		room.role = patch.role
		layout.rooms.append(room)

	for gap in doors:
		var door := DoorData.new()
		door.tile = gap.tile
		door.horizontal = gap.horizontal
		door.width = gap.width
		var across := Vector2i(0, 1) if gap.horizontal else Vector2i(1, 0)
		door.room_a = layout.room_at(gap.tile - across)
		door.room_b = layout.room_at(gap.tile + across)
		if door.room_a < 0 or door.room_b < 0:
			push_warning("ShipGenerator: door at %s flanks no room, dropped" % gap.tile)
			continue
		layout.doors.append(door)
	return layout


## The aft-most Room by centre: where a raid boards a ship with no Hatches.
static func aft_most_room(layout: ShipLayout) -> int:
	var best := 0
	for i in layout.rooms.size():
		if layout.rooms[i].center_tile().y > layout.rooms[best].center_tile().y:
			best = i
	return best
