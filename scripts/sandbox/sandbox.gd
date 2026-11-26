class_name Sandbox
extends Resource
## The Sandbox numbers that belong to no weapon: Pirate Health, crew Health,
## Melee damage and the crew fight's numbers. One file, `resources/sandbox.tres`, read by the Pirate
## and the crew at spawn in place of anything in their scenes, so the
## Sandbox sheet can Save them without ever writing into a scene.

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
@export var true_aim_count := 2
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
