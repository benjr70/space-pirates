class_name Sandbox
extends Resource
## The Sandbox numbers that belong to no weapon: Pirate Health, crew Health,
## Melee damage, the crew fight's numbers and Surrender and Bound. One file, `resources/sandbox.tres`, read by the Pirate
## and the crew at spawn in place of anything in their scenes, so the
## Sandbox sheet can Save them without ever writing into a scene. Health is
## taken at spawn; the crew fight's numbers and Surrender and Bound are read
## live, so a sheet edit reaches Guards already in the Raid.

const PATH := "res://resources/sandbox.tres"

@export_group("Health")
## The Pirate's Health at spawn.
@export var pirate_health := 150
## Every crew member's Health at spawn.
@export var crew_health := 100

@export_group("Melee")
## What a Melee strike does from the front. From behind it kills outright.
@export var melee_damage := 75

@export_group("Crew fight")
## How many Guards aim true at once ([CrewFire]); at least one always does
## while any has a shot.
@export var true_aim_count := 3
## Seconds a Guard holds true aim before it passes on: doubled while he is
## crouched or in cover, halved with him within 3 m.
@export var true_aim_handover := 0.8
## Metres to one side the first burst of a sighting starts, walking in to
## him on its last round.
@export var walk_in_distance := 1.0
## At most this many pellets of one crew Shotgun shot do damage.
@export var shotgun_pellet_cap := 9
## Seconds Pistol and Assault Rifle Guards fire at the edges of the prop he
## broke sight behind ([CrewTeam]), deliberate misses only, before they hold.
@export var suppression_time := 4.0
## In his sight this near (metres), a Guard leaves its spot for one further
## off ([CrewCover]); the Shotgun stays, the Marksman Rifle backs off its own
## way.
@export var too_close := 3.0
## Seconds he must see a Guard where it hides before it counts as flanked
## and changes spot.
@export var flank_reaction := 0.4
## Metres of open floor in his view a Guard's walk to a spot may cross.
@export var open_floor := 2.5

@export_group("Surrender and Bound")
## A Worker that sees him this near (metres) surrenders, when it is hiding
## or has no route away that does not pass him.
@export var surrender_reach := 4.0
## Or when his crosshair rests on it this long (seconds) within this reach
## (metres).
@export var surrender_aim_time := 0.5
@export var surrender_aim_reach := 10.0
## Seconds after surrendering that it kneels.
@export var kneel_after := 1.5
## Holding the interact key this long (seconds) on a surrendered Worker
## within this reach (metres) ties it up: Bound.
@export var bind_time := 2.0
@export var bind_reach := 2.0
