class_name SuiteSeed
extends RefCounted
## The seed a behaviour suite runs under, so any failing run can be replayed
## exactly. Every behaviour draw in the game comes from Godot's global RNG
## or from an RNG seeded off it when its owner enters the tree, so seeding
## the global RNG first thing in `_initialize` fixes them all.
##
## `-- seed=<n>` after the script picks the seed; without it one is rolled.
## The seed is printed at the start, and again on failure with the command
## that replays it.

## Rolled seeds stay in this range so one fits in a bug report.
const MAX := 999_999_999


## Seeds the global RNG from `seed=<n>`, or a fresh roll, and prints it.
## [param suite] is the runner's name for the suite (`crew`, `pirate`, ...).
static func pick(suite: String) -> int:
	var n := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seed="):
			var value := arg.trim_prefix("seed=")
			if not value.is_valid_int() or int(value) <= 0:
				push_error("seed=%s is not a positive integer" % value)
			else:
				n = int(value)
	if n == 0:
		n = randi_range(1, MAX)
	seed(n)
	print("seed: %d" % n)
	return n


## The seed and the command that replays it, for a failure report.
static func replay_line(suite: String, n: int) -> String:
	return "seed: %d  replay: tests/run_all.sh only=%s seed=%d" % [n, suite, n]
