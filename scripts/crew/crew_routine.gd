class_name CrewRoutine
extends RefCounted
## What a crew member does while nobody is robbing the ship: a loop of Jobs
## starting from its Post, the Room it spawned in. A work Job walks to a prop
## (a console, a locker, a container) and stands at it facing it for a while;
## a patrol Job walks to a Room's centre and looks about. Pure planning: the
## crew body walks it and asks for the next Job when one ends.
## See `CREW_AI.md`.

## Props a crew member works at. Crates count only in Cargo, and a Breaker
## never: it is the Pirate's cover on the way in.
const WORK_PROPS: Array[StringName] = [&"console", &"engine_console", &"generator", &"locker",
		&"container", &"safe", &"cabinet", &"footlocker", &"cryopod"]
const JOBS_MIN := 3
const JOBS_MAX := 5
## Seconds stood at a work Job's prop, and at a patrol Job's stop.
const WORK_TIME := Vector2(3.0, 8.0)
const PATROL_PAUSE := Vector2(1.5, 3.5)
## Share of crew whose loop is a patrol route instead of work.
const PATROLLER_SHARE := 0.33
## Chance each work Job is in some other Room rather than the Post.
const AWAY_CHANCE := 0.5


class Job:
	extends RefCounted
	var room := -1
	## Where to stand, and which way to face once there (ZERO: look about).
	var at := Vector3.ZERO
	var face := Vector3.ZERO
	## The prop worked at, for a work Job.
	var prop_at := Vector3.ZERO
	var duration := 0.0
	var patrol := false


var post := -1
var jobs: Array[Job] = []
var index := 0
var patroller := false


## A loop for a crew member posted in [param post_room].
static func plan(layout: ShipLayout, post_room: int, rng: RandomNumberGenerator) -> CrewRoutine:
	var routine := CrewRoutine.new()
	routine.post = post_room
	routine.patroller = rng.randf() < PATROLLER_SHARE
	var count := rng.randi_range(JOBS_MIN, JOBS_MAX)
	var spots := work_spots(layout)
	var home: Array = spots.filter(func(s: Job) -> bool: return s.room == post_room)
	var away: Array = spots.filter(func(s: Job) -> bool: return s.room != post_room)
	var last_room := post_room
	for i in count:
		var job: Job
		if routine.patroller:
			# Every stop is a different Room from the one before it.
			var room := rng.randi_range(0, layout.rooms.size() - 1)
			if layout.rooms.size() > 1:
				while room == last_room:
					room = rng.randi_range(0, layout.rooms.size() - 1)
			last_room = room
			job = _patrol_stop(layout, room)
			job.duration = rng.randf_range(PATROL_PAUSE.x, PATROL_PAUSE.y)
		else:
			var pool: Array = away if (home.is_empty() or rng.randf() < AWAY_CHANCE) else home
			# The loop always comes back through the Post and always leaves it.
			if i == 0 and not home.is_empty():
				pool = home
			elif i == 1 and not away.is_empty():
				pool = away
			if pool.is_empty():
				pool = spots
			if pool.is_empty():
				job = _patrol_stop(layout, post_room)
			else:
				job = _copy(pool[rng.randi_range(0, pool.size() - 1)])
			job.duration = rng.randf_range(WORK_TIME.x, WORK_TIME.y)
		routine.jobs.append(job)
	# Mid-routine at the start of the Raid, so the ship is not in lockstep.
	routine.index = rng.randi_range(0, routine.jobs.size() - 1)
	return routine


## The Job to do now.
func current() -> Job:
	return jobs[index] if not jobs.is_empty() else null


## Moves on to the next Job in the loop and returns it.
func advance() -> Job:
	if jobs.is_empty():
		return null
	index = (index + 1) % jobs.size()
	return jobs[index]


## Every place a crew member could work: the floor tile beside each work
## prop, facing it. One spot per prop.
static func work_spots(layout: ShipLayout) -> Array[Job]:
	var out: Array[Job] = []
	var floors := layout.floor_tiles()
	for room_index in layout.rooms.size():
		var room := layout.rooms[room_index]
		var taken := {}
		for prop in room.props:
			taken[prop.get("tile", Vector2i.ZERO)] = true
		for prop in room.props:
			var kind: StringName = prop.get("type", &"")
			if prop.get("breaker", false):
				continue
			if not (kind in WORK_PROPS or (kind == &"crate" and room.role == &"cargo")):
				continue
			var tile: Vector2i = prop.get("tile", Vector2i.ZERO)
			for side: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
				var stand := tile + side
				if not room.has_tile(stand) or taken.has(stand) or not floors.has(stand):
					continue
				var job := Job.new()
				job.room = room_index
				job.at = ShipBuilder3D.tile_to_world(stand)
				job.prop_at = ShipBuilder3D.tile_to_world(tile)
				job.face = job.prop_at - job.at
				out.append(job)
				break
	return out


static func _patrol_stop(layout: ShipLayout, room: int) -> Job:
	var job := Job.new()
	job.room = room
	job.patrol = true
	job.at = ShipBuilder3D.room_center_world(layout.rooms[room])
	return job


static func _copy(spot: Job) -> Job:
	var job := Job.new()
	job.room = spot.room
	job.at = spot.at
	job.face = spot.face
	job.prop_at = spot.prop_at
	job.patrol = spot.patrol
	return job
