#!/usr/bin/env bash
# One command for every headless check: the static load check first (every
# script, scene and resource loads), then the generator sweep with its
# distributions and self-test, the 2D layout suite, the 3D suite with the
# built sample, the pirate's movement course, the crew's Awareness, the
# Sandbox sheet with its stale check on docs/sandbox.md, and the whole-Raid
# smoke run (scripted Pirates playing Raids end to end). Each suite prints
# its own per-Class results; this prints one line per suite at the end, with
# its check count and wall time in seconds, then the total, and fails if any
# suite failed.
#
# A suite fails when Godot exits non-zero, when its file is missing, or when
# its output holds an engine error (`SCRIPT ERROR:` anywhere, or a line
# starting `ERROR:`) that is not on the ALLOWED list below, even if it exited 0.
#
#   tests/run_all.sh                       # full sweep: the gate
#   tests/run_all.sh seeds=10              # narrowed generator sweep (distributions then run on few seeds)
#   tests/run_all.sh only=crew             # just the named suite(s), same strictness and summary
#   tests/run_all.sh only=generator,layouts seeds=10
#   tests/run_all.sh only=crew seed=123456 # replay a run: same seed, same draws
#   tests/run_all.sh only=raid_smoke seeds=20  # wider smoke sweep: 20 ships per Class
#
# only= takes a comma-separated list of suite names, each a file stem without
# `test_`: static, generator, layouts, ship_3d, pirate, crew, sandbox, raid_smoke. They
# run in the gate's order whatever order they are given in. An unknown or empty name is
# an error (exit 2), not a no-op.
#
# seed=<n> is the seed the behaviour suites (layouts, ship_3d, pirate, crew,
# raid_smoke) seed Godot's global RNG with, and so every crew decision, spread
# roll and timing jitter they draw (and the smoke run's ships). Without it the runner rolls one per run and prints
# it first; a failing suite's summary line is followed by the exact command
# that replays it. The generator sweep runs its own fixed seed corpus and the
# static check draws nothing, so neither takes it.
#
# Every other argument passes through to the generator sweep and the smoke
# run: seeds=<n> narrows the generator sweep and sets the smoke run's ships
# per Class (default 5); class=, ship= and script= narrow the smoke run to
# one Raid (its failure lines print them). Only the full run, with no only=
# and no seeds=, is the gate.
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-"flatpak run org.godotengine.Godot"}

# Engine error lines a check provokes on purpose: one extended regex per line,
# matched against the whole error line, each with a comment naming the check.
ALLOWED=(
	# Freeing the Pirate (player_3d.tscn) under the headless dummy renderer:
	# freeing the Viewmodel's mounted Pistol mesh (Pistol MeshInstance3D from
	# pistol.glb) trips material_get_instance_shader_parameters in
	# servers/rendering/dummy/storage/material_storage.cpp. Engine-side, headless
	# only; nothing is wrong in the game. Provoked by test_ship_3d.gd's teardown
	# of each Raid in generated_ship_checks.gd (run), raid_checks.gd
	# (_check_raid, _check_extraction) and built_sample_checks.gd (tick), and by
	# test_crew.gd's Pirate being freed when the suite quits, and by
	# test_raid_smoke.gd's teardown of each Raid (_play).
	'ERROR: Parameter "material" is null\.'
)

SUITES=(static generator layouts ship_3d pirate crew sandbox raid_smoke)
# Suites that advance physics run on a fixed frame step: every frame is
# exactly 1/60 s of game time, one physics tick (physics_ticks_per_second is
# the default 60) and one process frame, with no real-time sync. Results then
# do not depend on machine load (_process code such as the Viewmodel, the
# Alarm and the HUD markers sees the same deltas every run), and the suites
# run as fast as the CPU allows instead of in real time.
STEPPED=(layouts ship_3d pirate crew raid_smoke)
only=""
run_seed=""
pass=()
for arg in "$@"; do
	case $arg in
		only=*) only=${only:+$only,}${arg#only=} ;;
		seed=*) run_seed=${arg#seed=} ;;
		*) pass+=("$arg") ;;
	esac
done
if [[ " $* " == *" seed="* ]] && ! [[ $run_seed =~ ^[1-9][0-9]*$ ]]; then
	echo "run_all.sh: seed= takes a positive integer, got '$run_seed'" >&2
	exit 2
fi
[ -n "$run_seed" ] || run_seed=$(( (RANDOM << 15 | RANDOM) % 999999999 + 1 ))
declare -A picked=()
if [ -n "$only" ] || [[ " $* " == *" only="* ]]; then
	IFS=, read -ra names <<<"$only"
	[ ${#names[@]} -eq 0 ] && names=("")
	for name in "${names[@]}"; do
		if [[ " ${SUITES[*]} " != *" $name "* ]] || [ -z "$name" ]; then
			echo "run_all.sh: unknown suite '$name' in only=; known: ${SUITES[*]}" >&2
			exit 2
		fi
		picked[$name]=1
	done
else
	for name in "${SUITES[@]}"; do picked[$name]=1; done
fi

echo "seed: $run_seed"
log=$(mktemp)
trap 'rm -f "$log"' EXIT
status=0
summary=()
run() {
	local name=$1 label=$2; shift 2
	[ -n "${picked[$name]:-}" ] || return 0
	if [ ! -f "$1" ]; then
		summary+=("$label: FAIL (missing $1)")
		status=1
		return
	fi
	local script=$1; shift
	echo "=== $label"
	local started=$SECONDS
	local step=()
	[[ " ${STEPPED[*]} " == *" $name "* ]] && step=(--fixed-fps 60)
	# pipefail: the pipeline's status is Godot's own, not grep's or tee's.
	$GODOT --headless "${step[@]}" --path . --script "res://$script" -- "$@" 2>&1 | grep -vE '^$|^Godot Engine' | tee "$log"
	local code=$?
	local checks
	checks=$(grep -oE '^(PASS  [0-9]+|FAILED  [0-9]+ of [0-9]+) checks' "$log" | tail -1 | grep -oE '[0-9]+ checks$')
	checks=${checks:-"no check count"}
	checks+=", $((SECONDS - started)) s"
	local errors
	errors=$(grep -E 'SCRIPT ERROR:|^ERROR:' "$log")
	for pattern in "${ALLOWED[@]}"; do
		errors=$(grep -vxE -- "$pattern" <<<"$errors")
	done
	if [ "$code" -ne 0 ]; then
		summary+=("$label: FAIL (exit $code, $checks)")
		status=1
	elif [ -n "$errors" ]; then
		summary+=("$label: FAIL (engine errors, $checks)")
		while IFS= read -r line; do summary+=("    $line"); done <<<"$errors"
		status=1
	else
		summary+=("$label: PASS ($checks)")
		return
	fi
	if [[ " $* " == *" seed="* ]]; then
		summary+=("    replay: tests/run_all.sh only=$name seed=$run_seed${pass[*]:+ ${pass[*]}}")
	fi
}
run static "static load check" tests/test_static.gd
run generator "generator sweep" tests/test_generator.gd "${pass[@]}"
run layouts "2D layouts" tests/test_layouts.gd "seed=$run_seed"
run ship_3d "3D ship and built sample" tests/test_ship_3d.gd "seed=$run_seed"
run pirate "pirate movement and gunplay" tests/test_pirate.gd "seed=$run_seed"
run crew "crew awareness" tests/test_crew.gd "seed=$run_seed"
run sandbox "sandbox sheet and docs/sandbox.md" tests/test_sandbox.gd
run raid_smoke "whole-Raid smoke run" tests/test_raid_smoke.gd "seed=$run_seed" "${pass[@]}"
echo "=== summary"
printf '%s\n' "${summary[@]}"
echo "total: $SECONDS s"
exit $status
