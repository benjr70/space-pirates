#!/usr/bin/env bash
# One command for every headless check: the generator sweep with its
# distributions and self-test, the 2D layout suite, and the 3D suite with
# the built sample. Each suite prints its own per-Class results; this
# prints one line per suite at the end and fails if any suite failed.
#
#   tests/run_all.sh            # full sweep
#   tests/run_all.sh seeds=10   # narrowed generator sweep (distributions then run on few seeds)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-"flatpak run org.godotengine.Godot"}
status=0
summary=()
run() {
	local label=$1; shift
	if [ ! -f "$1" ]; then
		summary+=("$label: skipped (no $1)")
		return
	fi
	local script=$1; shift
	echo "=== $label"
	# pipefail: the pipeline's status is Godot's own, not grep's.
	$GODOT --headless --path . --script "res://$script" -- "$@" 2>&1 | grep -vE '^$|^Godot Engine'
	local code=$?
	if [ "$code" -eq 0 ]; then
		summary+=("$label: PASS")
	else
		summary+=("$label: FAIL (exit $code)")
		status=1
	fi
}
run "generator sweep" tests/test_generator.gd "$@"
run "2D layouts" tests/test_layouts.gd
run "3D ship and built sample" tests/test_ship_3d.gd
echo "=== summary"
printf '%s\n' "${summary[@]}"
exit $status
