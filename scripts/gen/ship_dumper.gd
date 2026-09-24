class_name ShipDumper
extends RefCounted
## ASCII plan of a [ShipLayout], so a seed is legible in a terminal: '#'
## wall, '.' floor, '+' doorway, 'H' hatch, with each Room's first tile
## lettered by Role. Fore is at the LEFT: the plan is rotated a quarter turn
## so terminal glyph aspect shows true proportion.

const ROLE_GLYPH := {
	&"bridge": "B", &"engine": "E", &"corridor": "C", &"cargo": "c",
	&"quarters": "q", &"medbay": "m", &"shield": "s", &"armory": "a",
}


## The plan as text, one character per tile.
static func ascii(layout: ShipLayout) -> String:
	var floors := layout.floor_tiles()
	var marks := {}
	for door in layout.doors:
		for t in door.tiles():
			marks[t] = "+"
	for hatch in layout.hatches:
		for t in hatch.tiles():
			marks[t] = "H"
	for room in layout.rooms:
		var at := Vector2i(room.center_tile().floor())
		marks[at] = ROLE_GLYPH.get(room.role, "?")
	var walls := {}
	var bounds: Rect2i = layout.rooms[0].bounds().grow(1)
	for room in layout.rooms:
		bounds = bounds.merge(room.bounds().grow(1))
		for rect in room.shape():
			var ring := rect.grow(1)
			for x in range(ring.position.x, ring.end.x):
				for y in range(ring.position.y, ring.end.y):
					var t := Vector2i(x, y)
					if not floors.has(t):
						walls[t] = true
	var lines: Array[String] = []
	for x in range(bounds.position.x, bounds.end.x):
		var line := ""
		for y in range(bounds.position.y, bounds.end.y):
			var t := Vector2i(x, y)
			if marks.has(t):
				line += marks[t]
			elif walls.has(t):
				line += "#"
			elif floors.has(t):
				line += "."
			else:
				line += " "
		lines.append(line)
	return "\n".join(lines)


## One-line summary: seed, Class, Room count, Doors, floor tiles and size.
static func summary(report: ShipGenerator.Report) -> String:
	var layout := report.layout
	var bounds := layout.rooms[0].bounds()
	for room in layout.rooms:
		bounds = bounds.merge(room.bounds())
	return "seed %d  class %s  |  %d rooms (%d counted), %d doors, %d floor tiles, %dx%d m\n%s" % [
			layout.gen_seed, layout.ship_class, layout.rooms.size(), report.counted_rooms,
			layout.doors.size(), layout.floor_tiles().size(), bounds.size.x, bounds.size.y,
			report.sentence]


## One line per Room and Door: index, Role, area, rects; Door ends and tile.
static func listing(layout: ShipLayout) -> String:
	var lines: Array[String] = []
	for i in layout.rooms.size():
		var room := layout.rooms[i]
		lines.append("room %2d  %-9s %4d tiles  %s" % [i, room.role, room.area(), room.rects])
	for i in layout.doors.size():
		var door := layout.doors[i]
		lines.append("door %2d  %d-%d at %s %s w%d" % [i, door.room_a, door.room_b, door.tile,
				"along x" if door.horizontal else "along y", door.width])
	return "\n".join(lines)
