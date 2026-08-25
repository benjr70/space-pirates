class_name Health
extends Node
## Hit points for anything that can be shot. Lives as a child node so the pirate
## and the crew share one implementation.

signal damaged(amount: int, from: Node)
signal healed(amount: int)
signal died(from: Node)

@export var max_health: int = 5

var current: int = 0


func _ready() -> void:
	current = max_health


func is_alive() -> bool:
	return current > 0


## Returns true if this blow was fatal.
func take_damage(amount: int, from: Node = null) -> bool:
	if amount <= 0 or not is_alive():
		return false
	current = maxi(current - amount, 0)
	damaged.emit(amount, from)
	if current == 0:
		died.emit(from)
		return true
	return false


func heal(amount: int) -> void:
	if amount <= 0:
		return
	current = mini(current + amount, max_health)
	healed.emit(amount)


func reset() -> void:
	current = max_health
