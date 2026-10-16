class_name RaidLedger
extends RefCounted
## One Raid's takings, settled into the [Profile] when it ends. XP is earned
## for kills, more for kills on crew that never saw him coming, and kept
## whichever way the Raid ends; gold is carried from the Containers he opens
## and banked only if he extracts with it. Extracting with the Alarm never
## raised adds the Ghost bonus.

const KILL_XP := 100
## A kill on a crew member that had not spotted him.
const UNAWARE_KILL_XP := 150
## Extraction XP by Ship Class: the bigger the ship, the further from home.
const EXTRACT_XP := {&"small": 200, &"medium": 350, &"large": 500}
## Ghost: extracting with the Alarm never raised, by Ship Class.
const GHOST_XP := {&"small": 150, &"medium": 250, &"large": 350}

var ship_class: StringName = &""
var kills := 0
## Of those, kills on crew that had not spotted him.
var unaware_kills := 0
## The ship's Alarm went up at some point this Raid: no Ghost bonus.
var alarm_raised := false
## Gold he is carrying, lost if he does not get out with it.
var carried_gold := 0
## Set once the Raid is settled; nothing counts after.
var settled := false


func _init(raid_class: StringName = &"") -> void:
	ship_class = raid_class


func kill_xp() -> int:
	return (kills - unaware_kills) * KILL_XP + unaware_kills * UNAWARE_KILL_XP


## The Ghost bonus this Raid would earn on extracting now: zero once the
## Alarm has gone up.
func ghost_xp() -> int:
	return 0 if alarm_raised else GHOST_XP.get(ship_class, GHOST_XP[&"medium"])


func extract_xp() -> int:
	return EXTRACT_XP.get(ship_class, EXTRACT_XP[&"medium"])


## [param unaware]: the crew member had not spotted him when it fell.
func record_kill(unaware := false) -> void:
	if not settled:
		kills += 1
		if unaware:
			unaware_kills += 1


func carry(gold: int) -> void:
	if not settled:
		carried_gold += gold


## Got out: kill XP, the extraction bonus and every coin carried are kept.
func settle_extracted() -> void:
	if settled:
		return
	settled = true
	Profile.bank(kill_xp() + extract_xp() + ghost_xp(), carried_gold)


## Went down or walked away: kill XP is kept, the gold stays on the ship.
func settle_lost() -> void:
	if settled:
		return
	settled = true
	Profile.bank(kill_xp(), 0)
