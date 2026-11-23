#!/usr/bin/env bash
# Offscreen screenshots: renders a preset of tests/shots.gd on the GPU inside
# a headless gamescope (no window, no display needed) and fails unless every
# frame the preset announced was saved, non-empty, and passed the shot
# script's flat-colour and magenta checks. See docs/agents/validation.md.
#
#   tests/shots.sh viewmodel [wheel=1] [hip=x,y,z ...]
#   tests/shots.sh ship class=medium seed=1
#   tests/shots.sh crew | hud | menu
#   tests/shots.sh scene path=res://scenes/props3d/prop_crate_3d.tscn cam=2,1.5,2 look=0,0.5,0
#
# Common args: out=<dir under the project> (default .godot/shots/<preset>,
# git-ignored; the flatpak Godot cannot write /tmp), size=WxH (default
# 1280x720). SHOTS_TIMEOUT (seconds, default 300) caps the run.
set -uo pipefail
cd "$(dirname "$0")/.."
root=$(pwd)

if [ $# -lt 1 ]; then
	sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
fi
preset=$1; shift

out="res://.godot/shots/$preset"
size="1280x720"
pass=()
for a in "$@"; do
	case $a in
		out=*) out=${a#out=} ;;
		size=*) size=${a#size=} ;;
		*) pass+=("$a") ;;
	esac
done
case $out in
	res://*) dir="$root/${out#res://}" ;;
	/*) dir=$out; out="res://${out#"$root"/}" ;;
	*) dir="$root/$out"; out="res://$out" ;;
esac
case $dir in
	"$root"/*) ;;
	*) echo "shots: out= must be inside the project ($root); the flatpak Godot cannot write elsewhere" >&2; exit 2 ;;
esac
w=${size%x*}; h=${size#*x}

mkdir -p "$dir"
rm -f "$dir"/*.png "$dir/shots.log"
log="$dir/shots.log"
start=$(date +%s)
# gamescope dumps core on shutdown after Godot has exited; its status is
# ignored and the run is judged by Godot's output and the files.
# The subshell swallows bash's own report of that core dump.
( timeout "${SHOTS_TIMEOUT:-300}" gamescope --backend headless -W "$w" -H "$h" -- \
	flatpak run org.godotengine.Godot --path . --resolution "$size" \
	--script res://tests/shots.gd -- "$preset" "${pass[@]}" "out=$out" 2>&1 \
	| tee "$log" \
	| grep -vE '^$|^Godot Engine|^\[gamescope\]|^> |xkbcomp|^\(EE\) failed to read Wayland' ) 2>/dev/null
elapsed=$(( $(date +%s) - start ))

status=0
mapfile -t expected < <(sed -n 's/^SHOT_EXPECT //p' "$log")
if [ ${#expected[@]} -eq 0 ]; then
	echo "shots: FAIL, the shot script announced no frames (did it start?)"
	status=1
fi
for f in "${expected[@]}"; do
	if [ ! -s "$dir/$f" ]; then
		echo "shots: FAIL, missing or empty $dir/$f"
		status=1
	fi
done
if grep -q '^SHOT_FAIL ' "$log"; then
	status=1
fi
# A script error ends the preset's coroutine early without stopping the run.
if grep -q '^SCRIPT ERROR' "$log"; then
	echo "shots: FAIL, script error during the run (see the log)"
	status=1
fi
if ! grep -q '^SHOTS_DONE ok' "$log"; then
	echo "shots: FAIL, the shot script did not finish cleanly"
	status=1
fi
if [ $status -eq 0 ]; then
	echo "shots: PASS $preset, ${#expected[@]} frames in ${elapsed}s, in $dir"
else
	echo "shots: FAIL $preset after ${elapsed}s, see $log"
fi
exit $status
