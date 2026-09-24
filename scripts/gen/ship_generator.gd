class_name ShipGenerator
extends RefCounted
## A seeded generator for raid-target ships. Takes a Ship Class and a seed
## and emits a [ShipLayout] the builder consumes exactly as it consumes the
## hand-authored one. The seed is the ship's identity: the same seed always
## yields the same ship.
##
## Stages, in order, each fixed before the next runs: Class and Richness
## roll, Hull silhouette ([HullGrammar]), Room packing ([RoomPacker]) with the
## count-first area loop, Door stitching ([DoorStitcher]). Hatches, Roles,
## Budgets, interiors and names are later stages and land on their own.

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
## When that many resizes cannot land the band, the archetype is re-rolled
## and the resizes start over, this many times at most: the count is not a
## smooth function of area, and some silhouettes cannot hold some counts.
const MAX_REROLLS := 2


## What a generation run reports beyond the layout, for the harness and dumper.
class Report:
	extends RefCounted
	var layout: ShipLayout
	## Archetype, Skeleton, features and repairs, in one line.
	var sentence := ""
	## Hull rescales it took to land the Room count in band.
	var resizes := 0
	## Archetype re-rolls it took after the resizes ran out.
	var rerolls := 0
	var in_band := true
	var counted_rooms := 0
	var stranded := 0


## The ship for a seed. Convenience over [method generate_report].
static func generate(ship_class: StringName, seed: int) -> ShipLayout:
	return generate_report(ship_class, seed).layout


## The ship for a seed with the account of how it was generated.
static func generate_report(ship_class: StringName, seed: int) -> Report:
	assert(ship_class in CLASSES, "unknown ship class %s" % ship_class)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed(ship_class, seed)
	var band: Vector2i = ROOM_BAND[ship_class]
	var want := rng.randi_range(band.x, band.y)
	var richness := rng.randf()

	# Count first: size the Hull from the wanted count, and when the packed
	# count misses the band rescale the area by the miss and repack.
	var report := Report.new()
	var hull: HullGrammar.Hull
	var pack: RoomPacker.Result
	var doors: Array[RoomPacker.Gap] = []
	var landed := false
	for reroll in MAX_REROLLS + 1:
		var archetype := HullGrammar.roll_archetype(ship_class, rng)
		var scale := 1.0
		# The count is not smooth in area, so once a scale has come in under
		# the band and another over it, the next tries lie between them.
		var under_scale := 0.0
		var over_scale := 0.0
		report.rerolls = reroll
		for attempt in MAX_RESIZES:
			var target := int(want * ROOM_TARGET * SKELETON_OVERHEAD * scale * rng.randf_range(0.95, 1.05))
			hull = HullGrammar.roll(ship_class, rng, target, archetype)
			pack = RoomPacker.pack(hull, ship_class, band, rng)
			var got := pack.counted_rooms()
			report.resizes = attempt
			landed = _landed(pack, band)
			if landed:
				# Stitching can strand a Room into Bulk, so the count is read again after it.
				doors = DoorStitcher.stitch(pack.patches, pack.seeded, rng)
				got = pack.counted_rooms()
				landed = _landed(pack, band)
			if landed:
				break
			if got < band.x:
				under_scale = maxf(under_scale, scale)
			elif got > band.y:
				over_scale = scale if over_scale == 0.0 else minf(over_scale, scale)
			if under_scale > 0.0 and over_scale > under_scale:
				scale = (under_scale + over_scale) / 2.0
			else:
				scale *= clampf(float(want) / float(maxi(got, 1)), 0.6, 1.6)
		if landed:
			break

	if not landed:
		doors = DoorStitcher.stitch(pack.patches, pack.seeded, rng)
	report.layout = _assemble(ship_class, seed, richness, pack, doors)
	report.counted_rooms = pack.counted_rooms()
	report.in_band = landed
	for patch in pack.patches:
		if patch.stranded:
			report.stranded += 1

	var features := pack.features.duplicate()
	if report.stranded > 0:
		features.append("stranded×%d" % report.stranded)
	if report.resizes > 0:
		features.append("resize×%d" % report.resizes)
	if report.rerolls > 0:
		features.append("reroll×%d" % report.rerolls)
	if not report.in_band:
		features.append("OUT OF BAND")
	report.sentence = hull.sentence()
	if not features.is_empty():
		report.sentence += " / " + ", ".join(features)
	report.layout.gen_sentence = report.sentence
	return report


## Whether a pack has landed: counted Rooms in the Class band, with a Bridge
## and an Engine standing where the Skeleton ends.
static func _landed(pack: RoomPacker.Result, band: Vector2i) -> bool:
	var got := pack.counted_rooms()
	return got >= band.x and got <= band.y and pack.caps_on_axis \
			and pack.has_role(&"bridge") and pack.has_role(&"engine")


## The RNG seed for a Class and ship seed: stable across runs and machines.
static func rng_seed(ship_class: StringName, seed: int) -> int:
	return hash("%s#%d" % [ship_class, seed])


## Turn packed patches and confirmed gaps into a [ShipLayout].
static func _assemble(ship_class: StringName, seed: int, richness: float,
		pack: RoomPacker.Result, doors: Array[RoomPacker.Gap]) -> ShipLayout:
	var layout := ShipLayout.new()
	layout.gen_seed = seed
	layout.ship_class = ship_class
	layout.richness = richness
	layout.ship_name = "%s target %d" % [ship_class.capitalize(), seed]

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


## The aft-most Room by centre: where a raid boards until Hatches land.
static func aft_most_room(layout: ShipLayout) -> int:
	var best := 0
	for i in layout.rooms.size():
		if layout.rooms[i].center_tile().y > layout.rooms[best].center_tile().y:
			best = i
	return best
