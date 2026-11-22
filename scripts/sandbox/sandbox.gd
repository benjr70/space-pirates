class_name Sandbox
extends Resource
## The Sandbox numbers that belong to no weapon: Pirate Health, crew Health
## and Melee damage. One file, `resources/sandbox.tres`, read by the Pirate
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
