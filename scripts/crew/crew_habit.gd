class_name CrewHabit
extends RefCounted
## A habit per gun: what the gun a Guard carries changes about how it fights
## from cover, apart from the numbers in its [Gunnery]. The Shotgun ambushes
## at a doorway, holds fire far off and racks before it shows itself; the
## Pistol shifts and the Assault Rifle anchors (their holds are Gunnery
## numbers); the Marksman Rifle perches, scores a spot by its clear line to
## the Pirate, never moves up, shows a sight line before each shot and, with
## him close and nowhere further to go, fires from the hip. [CrewCover] asks
## this which gun it fights with and reads these numbers. See "A habit per
## gun" in `CREW_AI.md`.

enum Gun { PISTOL, ASSAULT_RIFLE, SHOTGUN, MARKSMAN_RIFLE }

## --- Shotgun ---
## The only gun that may take cover this close to him, metres; every other
## gun's cover spot is at least this far off.
const SHOTGUN_CLOSE := 4.0
## It holds fire with him further off than this, metres.
const SHOTGUN_HOLD_FIRE := 8.0
## Its ambush tile is within this of the doorway's opening, metres.
const AMBUSH_REACH := 5.0
## It racks this long before it pops up over low cover, seconds, still down.
const RACK_LEAD := 0.3
## Every shot it fires is at least RACK_EARLIEST and at most RACK_LATEST
## after its last rack; one older than that is racked again first.
const RACK_EARLIEST := 0.2
const RACK_LATEST := 0.95

## --- Marksman Rifle ---
## How far from it a perch may be, metres: the cover search radius for this
## gun.
const PERCH_RADIUS := 14.0
## Its spot scores by the length of its clear line to him, up to this,
## metres (its sight), weighted this much.
const PERCH_LINE := 14.4
const W_LINE := 40.0
## Of its best-scored spots, how many have their walk tried: more than the
## other guns' six, since the longest lines are often across open floor.
const PERCH_TRIED := 18
## With him closer than this, metres, it falls back to a further perch, or
## fires from the hip.
const PERCH_CLOSE := 5.0
## Its sight line locks this long before the shot, seconds: the shot goes
## where the line pointed then.
const SIGHT_LOCK := 0.2
## From the hip its base cone (the gun's own plus its aim error) is this
## many times wider, and it settles this long before the shot, seconds, as
## an ordinary gun.
const HIP_CONE := 2.0
const HIP_SETTLE := 0.35

const _FILES := {
	"pistol.tres": Gun.PISTOL,
	"assault_rifle.tres": Gun.ASSAULT_RIFLE,
	"shotgun.tres": Gun.SHOTGUN,
	"marksman_rifle.tres": Gun.MARKSMAN_RIFLE,
}


## Which gun [param weapon] is, by its file (a Weapon Profile or its
## Gunnery share the name); a copy with no file is a Shotgun if it throws
## pellets, else a Pistol. Null is a Pistol.
static func gun_of(weapon: WeaponProfile) -> Gun:
	if weapon == null:
		return Gun.PISTOL
	var file := weapon.resource_path.get_file()
	if _FILES.has(file):
		return _FILES[file]
	return Gun.SHOTGUN if weapon.pellet_count > 1 else Gun.PISTOL


## Whether this gun racks before each shot (the Profile's action sound as
## its tell) rather than after it.
static func racks(weapon: WeaponProfile) -> bool:
	return weapon != null and weapon.action_sound != null and gun_of(weapon) == Gun.SHOTGUN
