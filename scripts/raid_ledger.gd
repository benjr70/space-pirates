class_name RaidLedger
extends RefCounted
## One Raid's takings, settled into the [Profile] when it ends. XP is earned
## for kills and kept whichever way the Raid ends; gold is carried from the
## Containers he opens and banked only if he extracts with it.

const KILL_XP := 100
## Extraction XP by Ship Class: the bigger the ship, the further from home.
const EXTRACT_XP := {&"small": 200, &"medium": 350, &"large": 500}

var ship_class: StringName = &""
var kills := 0
## Gold he is carrying, lost if he does not get out with it.
var carried_gold := 0
## Set once the Raid is settled; nothing counts after.
var settled := false


func _init(raid_class: StringName = &"") -> void:
	ship_class = raid_class


func kill_xp() -> int:
	return kills * KILL_XP


func extract_xp() -> int:
	return EXTRACT_XP.get(ship_class, EXTRACT_XP[&"medium"])


func record_kill() -> void:
	if not settled:
		kills += 1


func carry(gold: int) -> void:
	if not settled:
		carried_gold += gold


## Got out: kill XP, the extraction bonus and every coin carried are kept.
func settle_extracted() -> void:
	if settled:
		return
	settled = true
	Profile.bank(kill_xp() + extract_xp(), carried_gold)


## Went down or walked away: kill XP is kept, the gold stays on the ship.
func settle_lost() -> void:
	if settled:
		return
	settled = true
	Profile.bank(kill_xp(), 0)
