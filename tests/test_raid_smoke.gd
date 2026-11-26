extends SceneTree
## Whole Raids, end to end: the real ship scene boarded the way the main menu
## starts it, played by a scripted Pirate, on every Ship Class at several
## generated seeds. A change that breaks the loop between systems (boarding,
## Doors, crew, the Alarm, Containers, Extraction, the ledger, the end
## screens) fails here even when every piece still passes its own suite.
##
##   flatpak run org.godotengine.Godot --headless --fixed-fps 60 --path . --script res://tests/test_raid_smoke.gd -- seed=<n>
##
## Args: `seed=<n>` (SuiteSeed: the run's seed), `seeds=<n>` ship seeds per
## Ship Class (default 5), and to narrow a replay `class=small|medium|large`,
## `ship=<ship seed>` and `script=quiet|loud|caught`. Each Raid reseeds the
## global RNG from the run seed, its Class, its ship seed and its script, so
## a narrowed replay draws what the same Raid drew in the full run (physics
## contact order can still differ between a narrowed and a full run; the
## full `seed=` replay is the exact one). Ship seeds come from the run seed
## too: every run sweeps fresh ships, and `seed=` replays the same ones.
## Every failure line names its Raid and the command that replays it.
##
## The scripted Pirate is not an AI. It holds the same input actions a
## player does (move, crouch, interact) and calls the Pirate's public
## `fire()`, `melee()` and `switch_weapon()`; it looks by turning his body
## and head. It walks the navigator's waypoints (`ShipNavigator.waypoints_3d`,
## the room route crew walk), and between two waypoints steers round props
## on a half-metre cell grid (A*), because the navigator steers straight
## lines through a Room and a Lane between doorways is broken by a prop by
## design. A cell is open when its tile is floor and a box the Pirate's width
## (plus a margin) at waist height overlaps no world geometry but Door
## leaves, which it opens with the interact key as it reaches them. The
## Boarding Pod is in no Room, so a route into or out of it runs straight
## through the Hatch gap, as crew routes do. It shoots at crew it has a clear
## line to from its eyes and from the barrel, sights up, leading a walking
## target and firing only while the cone is tight enough for the range, and
## swings at one inside 1.6 m.
##
## Every Raid carries a fitted Loadout, given the way a Raid from the menu
## gives it: the Assault Rifle with a Suppressor and a Drum, in hand, and the
## Shotgun with a Short Barrel. The scripts fire the Assault Rifle.
##
## Three scripts per ship. Each is what the bot tries; the verdict does not
## ask it to win (see "The verdict" below):
## - **Quiet**: Assault Rifle out, crouch-walks in, shuts the boarding Hatch behind
##   him, loots one Container, comes back, extracts. He fires only at crew
##   that have noticed him (suspicious, or HUNT, FIGHT, COVER, a Worker
##   fleeing to raise the Alarm, or one hiding or surrendered cornered at his elbow),
##   standing to do it. Plays for a Ghost
##   Extraction.
## - **Loud**: Assault Rifle out, walks to the first occupied Room and fires there,
##   falls back to the pod mouth shooting whoever follows and holds it until
##   nobody has been in sight for 8 s; with nobody down yet, stalks the
##   nearest Worker (else Guard), crouched until crew are after him, until
##   one is; then loots a Container and extracts, fighting anyone in sight on
##   the way. Before looting, with a kill made, he spends up to SPARE_FOR
##   seconds tying up one Worker (_tie_up_one): he goes after the nearest
##   hiding or surrendered Worker (else the nearest Worker) shooting no
##   Worker but one running for a panel, rests his crosshair on a hiding
##   one in his sight within its aim reach until it surrenders, walks up to the first surrendered one he
##   sees and ties it up with the interact key (_bind). A Bound Worker is
##   never shot. Down to 3 health in a fight he falls back to the pod mouth
##   (twice a Raid at most).
##   Plays for an Extraction with a kill.
## - **Caught**: walks up to the nearest Guard and stands in its view
##   without firing, repositioning so it can hit him (see _caught). Must go
##   down, every Raid.
##
## Target-picking rules (so a route is chosen by rule, never by excluding
## seeds):
## - A Container is a candidate when it holds gold and has a stand cell
##   (open, within 1.4 m of it, and 0.6 m clear of every Door's and Hatch's
##   reach so the interact key searches it instead of working a door) that
##   the grid reaches from where he starts.
## - Quiet takes the candidate with the lowest exposure: route length from
##   the boarding Hatch in metres, plus 20 for every crew member posted in a
##   Room on the way (the Container's own included), 40 in a Guard's Post
##   (Armory, Bridge, Corridor). A ship with no candidate fails.
## - Loud takes the nearest candidate by route from wherever the fight left
##   him.
## - A Container whose every stand cell has a crew member planted on it is
##   swapped for the nearest other candidate, up to 3 Containers.
## - Loud's first occupied Room is the Room of the living crew member
##   nearest by route from the boarding Hatch; Caught's Guard is the living
##   Guard nearest by route, re-picked each second as crew move.
## - A navigator waypoint the grid cannot reach (a seam crossing boxed in by
##   props) is skipped for the next; a crew member he walks into is steered
##   round on the next plan, and a walk that ends short of its goal is
##   planned again.
##
## The verdict. Crew are meant to be dangerous, so a bot that is spotted
## into an Alarm or shot down has played a legitimate Raid. Each Raid is
## judged on three things; none is replayed on a second draw.
##
## Invariants, strict on every Raid whatever the script (_check_invariants,
## _on_shot, _search, _attempt):
## 1. no engine error (a logger counts every error and script error raised
##    while the Raid runs);
## 2. the Pirate never leaves the Hull (his tile is floor, or he is in his
##    pod) or drops below the floor while alive;
## 3. no crew member is stuck: walking to a Job (on routine, or sweeping
##    under the Alarm) without moving 1 m in STUCK_LIMIT simulated seconds;
## 4. no Guard fighting from cover is stuck down with the Pirate in its
##    sight longer than its longest time down plus COVER_SLACK; no crew
##    member, in any state, tries to walk without moving FIGHT_STUCK_MOVE
##    (0.3 m) in FIGHT_STUCK_TIME (5 s); and none puts COVER_SHOTS shots in
##    a row into the ship within COVER_SHOT_RANGE of its own muzzle;
## 4a. firefights (crew-combat ticket 27, _open_with_cover, _check_invariants,
##    _on_shot): no Guard fights in the open (not reloading) for more than
##    OPEN_LIMIT (3 s) while a cover spot it would take (CrewCover.find) is
##    in its reach; never more than TRUE_AIM_MOST (2) Guards aim true in one
##    frame (CrewFire.holders, asked at the start of the frame); no Worker
##    fires; no Bound Worker moves BOUND_MOVE from where it was Bound;
## 5. the HUD offers a Door's prompt only while the Pirate is in a Door's
##    reach, and its Alarm banner shows exactly while the Alarm is raised;
## 6. at a Container in reach and facing it, the HUD offers the search and
##    the interact key searches it (no fallback), and the Loot line shows
##    the gold carried;
## 7. the Raid reaches an end state (extracted, or the Pirate down) within
##    its script's time budget; a bot that cannot go on (no route, stuck)
##    fails with its reason.
##
## Ending consistency, on whatever ending the Raid reached, read from what
## the UI reads (_check_ending): the ledger's kills equal the crew down; the
## HUD's spotted stings equal the crew that tipped into spotted (counted by
## a listener in the same group); the ledger's Alarm is the ship's.
## Extracted: the end screen reads EXTRACTED, the HUD is hidden, the gold
## carried is banked and the tally shows it, the banked XP is kill (a kill
## on a surrendered or Bound Worker counts 0) + bind + extraction + Ghost XP
## from the ledger, the tally shows the Ghost bonus if and only if the Alarm
## was never raised, and the kill count. Down: the end screen reads YOU
## DIED, the HUD is hidden, no gold is banked, only the kill and bind XP
## are, and the tally says so. Script rules: Caught must be down and
## must not have fired; Quiet extracted carries gold; Loud extracted has a
## kill and a crew member spotted.
##
## Sweep floors, so the sweep still proves each path works (_check_floors,
## on a full sweep only: no class=, ship= or script=). A broken Extraction
## or banking path gives 0 on each. Measured 2026-11-22 over eleven
## `seeds=10` sweeps (run seeds 1111 2222 3333 4444 5555 6666 7777 8888
## 9999 1212 3434: 330 Raids of each script); each floor sits well below
## the lowest rate seen and far above zero:
## - Quiet ending in a Ghost Extraction: 319 of 330 (97%), lowest sweep
##   28 of 30; floor QUIET_GHOST_FLOOR 60% (9 of 15 at the default 5 ships).
## - Loud extracting with a kill: 323 of 330 (98%), lowest sweep 29 of 30;
##   floor LOUD_KILL_FLOOR 60% (9 of 15).
## - Quiet and Loud banking Loot: lowest sweep 58 of 60 (97%); floor
##   LOOT_FLOOR 70% (21 of 30).
## - Each of those two endings per Ship Class: lowest 9 of 10 in a sweep,
##   3 of 5 (large Loud) in a default run; floor CLASS_FLOOR 40% (2 of 5).
## Caught went down in 330 of 330 and stays strict per Raid. Only a Raid
## that passed counts towards a floor. A full sweep also needs some Raid to
## bind a Worker; the `firefights` line reports the Raids that did and the
## most Guards seen aiming true at once.
##
## Banking goes to a throwaway per-process profile, never the player's.

const SUITE := "raid_smoke"
const STEP := 1.0 / 60.0
const SCRIPTS: Array[StringName] = [&"quiet", &"loud", &"caught"]
## The Loadout every Raid carries, given as a Raid from the menu gives it
## ([method Raid.arm]): the Assault Rifle first, in hand, with a Suppressor
## and a Drum; the Shotgun second with a Short Barrel.
const FITTED := {
	&"first": preload("res://resources/weapons/assault_rifle.tres"),
	&"second": preload("res://resources/weapons/shotgun.tres"),
	&"suppressor": preload("res://resources/attachments/suppressor.tres"),
	&"drum": preload("res://resources/attachments/drum.tres"),
	&"short_barrel": preload("res://resources/attachments/short_barrel.tres"),
}
const DEFAULT_SEEDS := 5
## Simulated seconds each script may take to reach its end state.
const BUDGET := {&"quiet": 240.0, &"loud": 300.0, &"caught": 150.0}
## A crew member walking to a Job this long without moving STUCK_MOVE is
## stuck. Longer than the routine's own give-up (JOB_GIVE_UP), so a Job
## abandoned by design is not counted; still stuck after that is a bug.
const STUCK_LIMIT := Crew3D.JOB_GIVE_UP + 10.0
const STUCK_MOVE := 1.0
## The floor's top is y = 0; the Pirate's origin sits on it.
const BELOW_FLOOR := -0.3

## Grid: cell (i, j) is the world point (i, j) * CELL on the floor.
const CELL := 0.5
## Half-width of the box a cell must keep clear: the Pirate's capsule (0.35)
## plus a margin.
const CLEARANCE := 0.4
## Where the clearance box sits: above the floor, below a lintel.
const BOX_Y := 0.9
const BOX_HEIGHT := 1.2
## A stand cell is this close to its Container, and this far outside any
## door's reach box (the Pirate's capsule plus a margin).
const STAND_REACH := 1.4
const STAND_DOOR_GAP := 0.6
## Quiet's exposure cost, in metres of route, of each crew member posted in
## a Room on the way, twice over for a Guard's Post (CrewTypes.GUARD_ROLES).
const CREW_POST_COST := 20.0

## Seconds without closing on the next waypoint before the route is planned
## again, and how many re-plans before the Pirate counts as stuck.
const REPLAN_AFTER := 2.5
const REPLANS := 10
## Radius of the cells a crew member he has walked into blocks on a re-plan.
const CREW_BLOCK := 0.8
## A crew member he walks at has to move this far before he plans again.
const FOLLOW_SLACK := 1.5
## How far he sees crew to shoot at.
const SIGHT := 22.0
## Caught: he stands no closer than this to the Guard shooting at him, and
## moves to a fresh spot in its view after this long unhurt.
const CAUGHT_GAP := 3.0
const CAUGHT_PATIENCE := 6.0
const HIDE_TIME := 5.0
## Nearest and furthest, in metres, a spot he picks near a Guard may be.
const SPOT_NEAR := Vector2(3.0, 8.0)
## The same when no spot that far off will do.
const SPOT_CLOSE := Vector2(1.5, 3.0)
## A Guard fighting from cover ([CrewCover]) that stays down with the
## Pirate in its sight, since it got down or last ducked a near miss, for
## longer than its longest time down (CrewCover.longest_down: its
## Gunnery's time down ceiling varied up 30%, plus the 0.8 s near-miss
## hold; 3.4 s Pistol, 4.05 s Assault Rifle, 2.75 s Shotgun, 6.0 s Marksman
## Rifle; or its longest reload, which it sits out down there whatever
## happens, where that is longer: only the Shotgun's six shells, 4.2 s,
## crew-combat ticket 17) and COVER_SLACK fails the Raid: it should have
## peeked. Time it
## spends down waiting on its gun's habit (CrewCover.waited: a Marksman
## Rifle waiting for a true-aim place to start its sight line, a Shotgun
## holding fire with him beyond 8 m; crew-combat ticket 20; one hiding with
## no peek waiting its turn to move under covering fire, ticket 21) is left out:
## that is the habit, not a missed peek; for the Rifle's place wait (with a
## peek) at most PLACE_WAIT_HANDOVERS true-aim handovers, each doubled (it
## is queued first for the next place to free); its turn to move, hiding
## with no peek, is not capped (crew-combat ticket 22 fixed the cap
## catching that too). One trying
## to walk in a fight for FIGHT_STUCK_TIME without moving FIGHT_STUCK_MOVE
## (a second's standing still starts the count again) fails it too. These
## replace the old limit on time in COVER (crew-combat ticket 18), which a
## Guard dug in now rightly passes: it holds a spot, hiding or trading
## shots, for as long as the fight lasts there.
const COVER_SLACK := 0.5
const PLACE_WAIT_HANDOVERS := 2.0
const FIGHT_STUCK_TIME := 5.0
const FIGHT_STUCK_MOVE := 0.3
## A crew member putting this many shots (a Shotgun's pellets one shot) in a row into the ship within
## COVER_SHOT_RANGE of its own muzzle (cover at its shoulder or in front of
## it), never a body, fails the Raid. Longest such streak seen over 990
## Raids: 2.
const COVER_SHOTS := 4
const COVER_SHOT_RANGE := 2.0
## Firefights (crew-combat ticket 27). A Guard fighting in the open
## (CrewCover.Mode.OPEN, not reloading) while a cover spot it would take
## (CrewCover.find: hidden from him, a peek, a fair walk in reach) has been
## there for longer than OPEN_LIMIT seconds fails the Raid; the spot is
## looked for every OPEN_LOOK seconds. Its own look comes every
## CrewCover.LOOK_OPEN (1.5 s), so a Guard that looks never comes near it.
const OPEN_LIMIT := 3.0
const OPEN_LOOK := 0.5
## Never more Guards aiming true in one frame than this (CrewFire.holders).
const TRUE_AIM_MOST := 2
## A Bound Worker moving further than this from where it was first seen
## Bound fails the Raid: it never moves again.
const BOUND_MOVE := 0.05
## Loud ties up a Worker that surrenders to him (_tie_up_one): he walks to within BIND_STAND of it and holds the interact key until it
## is Bound, giving up after BIND_TRIES tries or BIND_PATIENCE seconds of
## holding.
const BIND_STAND := 1.4
const BIND_TRIES := 3
const BIND_PATIENCE := 3.0
## Seconds Loud spends at most trying to tie up a Worker, so one that never
## surrenders does not hold him for the rest of the Raid.
const SPARE_FOR := 30.0
## Seconds he keeps pressing interact at a Container in reach before the
## Raid fails, and seconds he may spend closing the last stretch to it.
const SEARCH_PATIENCE := 10.0
## Containers he tries before giving up on looting.
const LOOT_TRIES := 3
## Times a walk that ends short of where it was going (a re-plan round a
## crew member snapped its end to a neighbouring cell) is planned again.
const SHORT_ENDS := 3

enum Walk { WALKING, ARRIVED, STUCK }
## Whom he shoots at: nobody, crew already after him, anyone in sight.
enum Fire { NONE, THREATS, ALL }
## Crew states that mean it is after him.
const THREAT_STATES: Array[Crew3D.State] = [Crew3D.State.HUNT, Crew3D.State.FIGHT, Crew3D.State.COVER,
		Crew3D.State.FLEE]
## Seconds of each sidestep that clears his barrel round a corner.
const SIDESTEP_TIME := 0.6
## Down to this much health in a fight he falls back to the pod mouth.
const RETREAT_HEALTH := 3
const RETREATS := 2
## Inside this flat distance he swings instead of shooting.
const MELEE_REACH := 1.6
## He pulls the trigger only while his cone (half-angle) is inside a body's
## half-width at the range, or this tight whatever the range.
const BODY_HALF_WIDTH := 0.3
const MIN_SPREAD := 0.6
## Where he aims on a crew member: its chest, above the 1.1 m crates;
## on a Guard down in cover (its capsule cut, crew-combat ticket 18),
## CHEST_BELOW_TOP under the top of its body as it is now, so he never
## counts a Guard hidden behind low cover as a target he can hit.
const CHEST := 1.3
const CHEST_BELOW_TOP := 0.2
## Seconds shooting at one crew member further off than GIVE_UP_BEYOND
## without a wound before leaving it be, and for how long.
const GIVE_UP_AFTER := 2.0
const GIVE_UP_FOR := 4.0
const GIVE_UP_BEYOND := 5.0
## Loud: nobody in sight this long at the pod mouth before he goes looting.
const HOLD_SPELL := 8.0

## Sweep floors (see the header): the fraction of a sweep's Raids of a
## script that must reach each ending. Checked only on a full sweep (no
## class=, ship= or script=).
const QUIET_GHOST_FLOOR := 0.6
const LOUD_KILL_FLOOR := 0.6
const LOOT_FLOOR := 0.7
## The same for each Ship Class on its own, so a path broken on one Class
## alone still fails.
const CLASS_FLOOR := 0.4

var failures: Array[String] = []
var checks := 0
var run_seed := 0
var seeds_per_class := DEFAULT_SEEDS
var only_class: StringName = &""
var only_script: StringName = &""
var only_ship := 0
var tap: ErrorTap
## "class/script" -> [passed, run]
var tally := {}
## script -> ending ("ghost", "extracted", "down", "failed") -> Raid count;
## "loot" counts Raids that banked gold, "kill" extractions with a kill;
## only Raids that passed count as anything but "failed".
var endings := {}
## script -> the Raids that did not reach the floor's ending, for the report.
var misses := {}
## "script/class" -> [Raids that reached the floor's ending, Raids played].
var class_reached := {}
var grids := {}

# --- one Raid's state ---------------------------------------------------------
var main: Node3D
var player: CharacterBody3D
var layout: ShipLayout
var pod: BoardingPod
var extraction: Extraction
var hud: Hud
var screen: RaidEndScreen
var alarm: ShipAlarm
var grid: AStarGrid2D
var floors: Dictionary
var crew: Array[Crew3D] = []
var hatch_leaf: Door3D
var entry := Vector3.ZERO
var home := Vector3.ZERO
var label := ""
## [Ship Class, ship seed, script] of the Raid being played, for replays.
var _raid := [&"", 0, &""]
var t := 0.0
var raid_failures: Array[String] = []
var left_hull := ""
var below_floor := ""
var stuck_crew := ""
var cover_held := ""
var cover_fire := ""
var wrong_prompt := ""
var alarm_banner := ""
var open_fight := ""
var too_many_true := ""
var worker_fired := ""
var bound_moved := ""
## Per Guard in the open: [cover spot in reach since (-1: none), last look].
var _open := {}
## Bound Worker to where it was first seen Bound.
var _bound_at := {}
## While Loud tries to tie a Worker up he shoots no Worker but a runner.
var _sparing := false
var _bind_tries := 0
## Across the run: the most Guards seen aiming true in one frame, and the
## Raids that bound a Worker.
var true_most := 0
var bound_raids: Array[String] = []
## Counts crew tipping into spotted, beside the HUD's own count.
var spots: SpotCounter
var _anchors := {}
## Input actions tapped, by frames since the press.
var _taps := {}
var route: Array[Vector3] = []
var goal := Vector3.ZERO
var _best := INF
var _best_t := 0.0
var _replans := 0
var _engaged := {}
## The last walk to a Container could not reach any stand cell of it.
var box_blocked := false
## The sights come down once this passes without a shot taken.
var _aim_until := 0.0
## Per Guard fighting from cover: [stretch down in sight began, downs,
## near misses, its habit wait then] and [anchor, seconds walking, seconds still].
var _down_in_sight := {}
var _fight_walk := {}
## Crew shots in a row that hit the ship rather than a body, by shooter.
var _wasted := {}
## Crew member to the physics frame of the last shot counted in its streak:
## a Shotgun shot's pellets all leave on one frame and count once.
var _wasted_shot := {}
var _given_up := {}
var _retreats := 0


class ErrorTap extends Logger:
	var lines: Array[String] = []
	var on := false
	var _lock := Mutex.new()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_lock.lock()
		if on:
			lines.append("%s (%s:%d)" % [rationale if rationale != "" else code, file.get_file(), line])
		_lock.unlock()

	func begin() -> void:
		_lock.lock()
		lines.clear()
		on = true
		_lock.unlock()

	func end() -> Array[String]:
		_lock.lock()
		on = false
		var out := lines.duplicate()
		_lock.unlock()
		return out


## Joins Crew3D.SPOTTED_GROUP, as the HUD's markers do, and counts the calls.
class SpotCounter extends Node:
	var count := 0

	func on_crew_spotted(_crew: Node) -> void:
		count += 1


func _initialize() -> void:
	run_seed = SuiteSeed.pick(SUITE)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seeds="):
			seeds_per_class = maxi(int(arg.trim_prefix("seeds=")), 1)
		elif arg.begins_with("class="):
			only_class = StringName(arg.trim_prefix("class="))
		elif arg.begins_with("ship="):
			only_ship = int(arg.trim_prefix("ship="))
		elif arg.begins_with("script="):
			only_script = StringName(arg.trim_prefix("script="))
	# Anything a Raid banks goes to a throwaway profile, never the player's.
	Profile.path = RaidChecks.test_profile
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaidChecks.test_profile))
	Profile.load_saved()
	tap = ErrorTap.new()
	OS.add_logger(tap)

	var ships := RandomNumberGenerator.new()
	ships.seed = run_seed
	for ship_class: StringName in ShipGenerator.CLASSES:
		var started := Time.get_ticks_msec()
		var ship_seeds: Array[int] = []
		for i in seeds_per_class:
			ship_seeds.append(ships.randi_range(1, Raid.SEED_MAX))
		if only_class != &"" and ship_class != only_class:
			continue
		for ship_seed in ship_seeds:
			if only_ship != 0 and ship_seed != only_ship:
				continue
			for script in SCRIPTS:
				if only_script != &"" and script != only_script:
					continue
				await _play(ship_class, ship_seed, script)
		var line := "%s:" % ship_class
		for script in SCRIPTS:
			var key := "%s/%s" % [ship_class, script]
			if tally.has(key):
				line += "  %s %d/%d" % [script, tally[key][0], tally[key][1]]
		print("%s  (%.1f s)" % [line, (Time.get_ticks_msec() - started) / 1000.0])

	OS.remove_logger(tap)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaidChecks.test_profile))
	Profile.load_saved()
	_check_floors()
	_report()
	await _silence()
	quit(1 if failures.size() > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		raid_failures.append(message)


## The endings across the sweep, one line per script, and on a full sweep
## the floors: enough Quiet Raids end in a Ghost Extraction, enough Loud
## Raids extract with a kill, enough Quiet and Loud Raids bank Loot. A
## floor failure lists the Raids that missed, each with its replay.
func _check_floors() -> void:
	for script in SCRIPTS:
		if not endings.has(script):
			continue
		var e: Dictionary = endings[script]
		print("endings %s: %d Raids, ghost %d, extracted (Alarm raised) %d, down %d, failed %d; banked Loot %d, extracted with a kill %d" % [
			script, e.raids, e.ghost, e.extracted, e.down, e.failed, e.loot, e.kill])
	print("firefights: at most %d Guards aimed true in one frame; %d Raids bound a Worker%s" % [
		true_most, bound_raids.size(), (": " + "; ".join(bound_raids)) if not bound_raids.is_empty() else ""])
	if only_class != &"" or only_ship != 0 or only_script != &"":
		print("sweep floors not checked on a narrowed run")
		return
	# Some scripted Raid ties a Worker up, so binding is played end to end.
	checks += 1
	if bound_raids.is_empty() and endings.has(&"loud"):
		failures.append("sweep: no Raid bound a Worker  [%s]" % _replay())
	var quiet: Dictionary = endings.get(&"quiet", {})
	var loud: Dictionary = endings.get(&"loud", {})
	_floor(quiet.get("ghost", 0), quiet.get("raids", 0), QUIET_GHOST_FLOOR, &"quiet",
			"Quiet Raids ended in a Ghost Extraction")
	_floor(loud.get("kill", 0), loud.get("raids", 0), LOUD_KILL_FLOOR, &"loud",
			"Loud Raids extracted with a kill")
	_floor(quiet.get("loot", 0) + loud.get("loot", 0), quiet.get("raids", 0) + loud.get("raids", 0), LOOT_FLOOR, &"",
			"Quiet and Loud Raids banked Loot")
	for key: String in class_reached:
		var script := StringName(key.get_slice("/", 0))
		_floor(class_reached[key][0], class_reached[key][1], CLASS_FLOOR, script, "%s %s Raids %s" % [
			key.get_slice("/", 1), script, "ended in a Ghost Extraction" if script == &"quiet" else "extracted with a kill"],
			key.get_slice("/", 1) + " ")


func _floor(reached: int, raids: int, fraction: float, script: StringName, what: String, ship_class := "") -> void:
	checks += 1
	var need := ceili(fraction * raids)
	print("floor: %d of %d %s, need %d (%.0f%%)" % [reached, raids, what, need, fraction * 100.0])
	if reached >= need:
		return
	var missed: Array = misses.get(script, []) if script != &"" else misses.get(&"quiet", []) + misses.get(&"loud", [])
	missed = missed.filter(func(m: String) -> bool: return m.begins_with(ship_class))
	failures.append("sweep floor: only %d of %d %s, need %d; missed: %s  [%s]" % [
		reached, raids, what, need, "; ".join(missed.slice(0, 8)), _replay()])


func _report() -> void:
	for f in failures:
		print("FAIL  ", f)
	if failures.is_empty():
		print("PASS  %d checks" % checks)
	else:
		print("FAILED  %d of %d checks" % [failures.size(), checks])
		print(_replay())


## The command that replays just the current Raid.
func _replay_raid() -> String:
	return "%s class=%s ship=%d script=%s" % [_replay(), _raid[0], _raid[1], _raid[2]]


func _replay() -> String:
	var line := SuiteSeed.replay_line(SUITE, run_seed)
	if seeds_per_class != DEFAULT_SEEDS:
		line += " seeds=%d" % seeds_per_class
	return line


## Stops every sound before quitting: the mixer runs in real time.
func _silence() -> void:
	for node in root.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
			node.stop()
	OS.delay_msec(300)
	await process_frame
	await process_frame


# --- one Raid -----------------------------------------------------------------

func _play(ship_class: StringName, ship_seed: int, script: StringName) -> void:
	label = "%s seed %d %s" % [ship_class, ship_seed, script]
	_raid = [ship_class, ship_seed, script]
	var result := await _attempt(ship_class, ship_seed, script)
	var tally_key := "%s/%s" % [ship_class, script]
	if not tally.has(tally_key):
		tally[tally_key] = [0, 0]
	tally[tally_key][1] += 1
	if raid_failures.is_empty():
		tally[tally_key][0] += 1
	for f in raid_failures:
		failures.append("%s: %s  [t=%.1f s; %s]" % [label, f, t, _replay_raid()])
	# A Raid that failed counts towards no floor, whatever its ending.
	if not raid_failures.is_empty():
		result = ["failed", false, false]
	var e: Dictionary = endings.get_or_add(script, {"raids": 0, "ghost": 0, "extracted": 0, "down": 0,
			"failed": 0, "loot": 0, "kill": 0})
	e.raids += 1
	e[result[0]] += 1
	e.loot += 1 if result[1] else 0
	e.kill += 1 if result[2] else 0
	var reached: bool = result[0] == "ghost" if script == &"quiet" else result[2]
	if script != &"caught":
		var c: Array = class_reached.get_or_add("%s/%s" % [script, ship_class], [0, 0])
		c[0] += 1 if reached else 0
		c[1] += 1
	if script != &"caught" and not reached:
		misses.get_or_add(script, []).append("%s ended %s (%s)" % [label, result[0], _replay_raid().get_slice("replay: ", 1)])


## Plays one Raid and gives its verdict in [member raid_failures]. Returns
## [ending, banked Loot, extracted with a kill]: the ending is "ghost"
## (extracted, the Alarm never raised), "extracted" (with the Alarm
## raised), "down" or "none" (no end state, which has already failed).
func _attempt(ship_class: StringName, ship_seed: int, script: StringName) -> Array:
	seed(hash([run_seed, ship_class, ship_seed, script]))
	raid_failures.clear()
	left_hull = ""
	below_floor = ""
	stuck_crew = ""
	cover_held = ""
	cover_fire = ""
	wrong_prompt = ""
	alarm_banner = ""
	open_fight = ""
	too_many_true = ""
	worker_fired = ""
	bound_moved = ""
	_open.clear()
	_bound_at.clear()
	_sparing = false
	_bind_tries = 0
	_anchors.clear()
	_taps.clear()
	_engaged.clear()
	_aim_until = 0.0
	_given_up.clear()
	_retreats = 0
	_down_in_sight.clear()
	_fight_walk.clear()
	_wasted.clear()
	_wasted_shot.clear()
	route.clear()
	t = 0.0

	Raid.ship_class = ship_class
	Raid.seed = ship_seed
	Raid.arm(_fitted_loadout())
	main = load(Raid.RAID_SCENE).instantiate()
	root.add_child(main)
	spots = SpotCounter.new()
	spots.add_to_group(Crew3D.SPOTTED_GROUP)
	main.add_child(spots)
	# GridMap collision comes live a frame after the scene enters the tree.
	await physics_frame
	await physics_frame
	player = main.get_node("Player")
	_expect(player.weapons.size() == 2 and player.weapon == player.weapons[0]
			and player.weapons[0].attachments == [FITTED[&"suppressor"], FITTED[&"drum"]]
			and player.weapons[1].attachments == [FITTED[&"short_barrel"]],
			"the Pirate does not carry the fitted Loadout, the Assault Rifle in hand")
	layout = main.layout
	pod = main.get_node("Ship/BoardingPod")
	extraction = main.extraction
	hud = main.get_node("Hud")
	screen = main.get_node("RaidEndScreen")
	alarm = ShipAlarm.of(self)
	floors = layout.floor_tiles()
	crew.clear()
	for node in get_nodes_in_group(&"crew"):
		crew.append(node)
	hatch_leaf = main.get_node("Ship/Hatches").get_child(main.entry_hatch)
	entry = ShipBuilder3D.hatch_entry_world(layout, layout.hatches[main.entry_hatch])
	home = pod.to_global(Vector3(0, 0, BoardingPod.COLLAR_Z + BoardingPod.DEPTH - 0.4))
	var key := "%s:%d" % [ship_class, ship_seed]
	if not grids.has(key):
		grids[key] = _build_grid()
	grid = grids[key]
	var start := Vector2i(Profile.xp, Profile.gold)
	main.get_node("Projectiles").child_entered_tree.connect(_on_shot)

	tap.begin()
	var stopped := raid_failures.size()
	match script:
		&"quiet":
			await _quiet()
		&"loud":
			await _loud()
		&"caught":
			await _caught()
	# The script stopped short of an end state for a reason it recorded
	# (stuck, no route, the key refused).
	var stopped_why := raid_failures.size() > stopped
	if not player.is_alive():
		# A frame for the death screen to come up after the fatal hit.
		await _frame(INF)
	var errors := tap.end()

	_expect(errors.is_empty(), "%d engine errors, first: %s" % [errors.size(), errors[0] if errors.size() > 0 else ""])
	_expect(left_hull == "" and below_floor == "", "the Pirate %s" % (left_hull if left_hull != "" else below_floor))
	_expect(stuck_crew == "", stuck_crew)
	_expect(cover_held == "", cover_held)
	_expect(cover_fire == "", cover_fire)
	_expect(wrong_prompt == "", wrong_prompt)
	_expect(alarm_banner == "", alarm_banner)
	_expect(open_fight == "", open_fight)
	_expect(too_many_true == "", too_many_true)
	_expect(worker_fired == "", worker_fired)
	_expect(bound_moved == "", bound_moved)
	if main.ledger.bound > 0:
		bound_raids.append("%s (%d)" % [label, main.ledger.bound])
	var result := _check_ending(script, start)
	if result[0] == "none" and not stopped_why:
		_expect(false, "no end state within the %.0f s budget (%.1f s simulated)" % [BUDGET[script], t])

	_release_all()
	paused = false
	root.remove_child(main)
	main.free()
	Raid.seed = 0
	Raid.ship_class = &""
	Raid.weapons = []
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return result


func _fitted_loadout() -> Loadout:
	var loadout := Loadout.new()
	loadout.set_first(FITTED[&"first"])
	loadout.set_second(FITTED[&"second"])
	for fit in [[&"first", Attachment.Slot.BARREL, &"suppressor"], [&"first", Attachment.Slot.MAGAZINE, &"drum"],
			[&"second", Attachment.Slot.BARREL, &"short_barrel"]]:
		_expect(loadout.set_attachment(FITTED[fit[0]], fit[1], FITTED[fit[2]]),
				"the fitted Loadout refused its %s" % fit[2])
	return loadout


## Checks the Raid's ending is consistent with what happened in it, through
## what the UI reads (the end screen's heading and tally, the HUD, the
## Profile the menu shows), whichever ending it was. Returns what
## _attempt returns.
func _check_ending(script: StringName, start: Vector2i) -> Array:
	var ledger: RaidLedger = main.ledger
	var down := 0
	for member in crew:
		if is_instance_valid(member) and not member.is_alive():
			down += 1
	_expect(ledger.kills == down, "the ledger counts %d kills with %d crew down" % [ledger.kills, down])
	_expect(hud.markers.stings == spots.count, "the HUD stung %d times for %d crew tipping into spotted"
			% [hud.markers.stings, spots.count])
	_expect(ledger.alarm_raised == alarm.is_raised, "the ledger's Alarm (%s) is not the ship's (%s)"
			% [ledger.alarm_raised, alarm.is_raised])
	var detail := screen.detail_text().replace("\n", " / ")
	var kills_text := "1 kill" if ledger.kills == 1 else "%d kills" % ledger.kills
	var carried := ledger.carried_gold
	if script == &"caught":
		_expect(player.ammo == player.weapon.magazine_size, "the Pirate fired")
		_expect(not player.is_alive(), "the Caught Pirate is still up (%s)"
				% ("extracted" if extraction.is_done else "no end state"))
	if not player.is_alive():
		_expect(screen.title_text() == "YOU DIED", "end screen reads '%s', want YOU DIED" % screen.title_text())
		_expect(not hud.visible, "the HUD stayed up over the death screen")
		_expect(Profile.gold == start.y, "dying banked %d gold" % (Profile.gold - start.y))
		_expect(Profile.xp == start.x + ledger.kept_xp(), "dying banked %d XP, want the %d kill and bind XP"
				% [Profile.xp - start.x, ledger.kept_xp()])
		var lost := "%d gold left behind" % carried if carried > 0 else "no gold carried"
		_expect(detail.contains("+%d XP kept  (%s" % [ledger.kept_xp(), kills_text]) and detail.contains(lost),
				"the death tally does not show %d XP kept, %s and %s: %s" % [ledger.kept_xp(), kills_text, lost, detail])
		return ["down", false, false]
	if not extraction.is_done:
		return ["none", false, false]
	_expect(screen.title_text() == "EXTRACTED", "end screen reads '%s', want EXTRACTED" % screen.title_text())
	_expect(not hud.visible, "the HUD stayed up over the extracted screen")
	_expect(Profile.gold == start.y + carried, "banked %d gold carrying %d" % [Profile.gold - start.y, carried])
	_expect(detail.contains("%d gold banked" % carried), "the tally does not show %d gold banked: %s" % [carried, detail])
	var ghost: int = 0 if alarm.is_raised else RaidLedger.GHOST_XP[layout.ship_class]
	var earned: int = ledger.kept_xp() + RaidLedger.EXTRACT_XP[layout.ship_class] + ghost
	_expect(Profile.xp == start.x + earned, "banked %d XP, want %d (%s, Alarm %s)"
			% [Profile.xp - start.x, earned, kills_text, "raised" if alarm.is_raised else "never raised"])
	# ", <n> Ghost" in the XP breakdown: a ship's name can hold the word.
	_expect(detail.contains(", %d Ghost)" % RaidLedger.GHOST_XP[layout.ship_class]) != alarm.is_raised, "the tally %s the Ghost bonus with the Alarm %s: %s"
			% ["shows" if alarm.is_raised else "lacks", "raised" if alarm.is_raised else "never raised", detail])
	_expect(detail.contains("(" + kills_text), "the tally does not show %s: %s" % [kills_text, detail])
	match script:
		&"quiet":
			_expect(carried > 0, "Quiet extracted carrying no gold")
		&"loud":
			_expect(ledger.kills > 0 and spots.count > 0, "Loud extracted with %d kills and %d crew spotted"
					% [ledger.kills, spots.count])
	return ["extracted" if alarm.is_raised else "ghost", carried > 0, ledger.kills > 0]


## One physics frame of the Raid: step, release the last frame's taps,
## check the invariants. False once the budget is spent.
func _frame(budget: float) -> bool:
	await physics_frame
	# A tap is held two frames (a press registers for the frame after it),
	# then released for one before it can be tapped again.
	for action: StringName in _taps.keys():
		_taps[action] += 1
		if _taps[action] == 2:
			Input.action_release(action)
		elif _taps[action] > 2:
			_taps.erase(action)
	t += STEP
	if t > _aim_until:
		Input.action_release(&"aim")
	_check_invariants()
	return t < budget


## A Guard fighting from cover that is stuck: down with him in its sight
## past its longest time down, or walking and getting nowhere. Empty when
## it is not.
func _stuck_in_fight(member: Crew3D) -> String:
	var cover: CrewCover = member.cover
	var what := _crew_name(member)
	if cover == null or not member.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
		_down_in_sight.erase(member)
		return _stuck_walking(member, what)
	if cover.mode != CrewCover.Mode.DOWN or not member._can_see:
		_down_in_sight.erase(member)
	elif not _down_in_sight.has(member) or _down_in_sight[member][1] != cover.downs or _down_in_sight[member][2] != cover.near_misses:
		_down_in_sight[member] = [t, cover.downs, cover.near_misses, cover.waited]
	else:
		var habit: float = cover.waited - _down_in_sight[member][3]
		if cover.gun == CrewHabit.Gun.MARKSMAN_RIFLE and cover.has_peek:
			# Waiting for a place (it needs a peek to want one). Hiding with
			# no peek, its wait is its turn to move, which is not capped.
			habit = minf(habit, PLACE_WAIT_HANDOVERS * 2.0 * member.sandbox.true_aim_handover)
		if t - _down_in_sight[member][0] - habit > cover.longest_down() + COVER_SLACK:
			return "%s stayed down %.1f s (%.1f s of it waiting on its habit) with him in its sight, longer than %.2f + %.1f s (t=%.1f s)" % [what,
					t - _down_in_sight[member][0], habit, cover.longest_down(), COVER_SLACK, t]
	return _stuck_walking(member, what)


## "a Guard (gun, cover mode or state, metres from the Pirate)" or "a Worker
## (state, metres from the Pirate)", for failure lines.
func _crew_name(member: Crew3D) -> String:
	var far := _flat(member.global_position).distance_to(_flat(player.global_position))
	if member.is_worker():
		return "a Worker (%s, %.1f m from the Pirate)" % [Crew3D.State.keys()[member.state], far]
	var cover: CrewCover = member.cover
	var doing: String = Crew3D.State.keys()[member.state]
	if cover != null and member.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
		doing = "mode " + CrewCover.MODE_NAMES[cover.mode]
	return "a Guard (%s, %s, %.1f m from the Pirate)" % [member.weapon.resource_path.get_file() if member.weapon else "unarmed",
			doing, far]


## Any crew member trying to walk FIGHT_STUCK_TIME without moving
## FIGHT_STUCK_MOVE (a second's standing still starts the count again):
## what it is and where, else empty. Crew-combat ticket 18 checked Guards in
## a cover fight so; ticket 27 checks every crew member in every state.
func _stuck_walking(member: Crew3D, what: String) -> String:
	var flat := _flat(member.global_position)
	if not _fight_walk.has(member) or flat.distance_to(_fight_walk[member][0]) > FIGHT_STUCK_MOVE:
		_fight_walk[member] = [flat, 0.0, 0.0]
	elif member.is_walking():
		_fight_walk[member][1] += STEP
		_fight_walk[member][2] = 0.0
		if _fight_walk[member][1] > FIGHT_STUCK_TIME:
			return "%s tried to walk %.0f s without moving %.1f m, at %s, pressed against %s (t=%.1f s)" % [what, FIGHT_STUCK_TIME,
					FIGHT_STUCK_MOVE, ShipBuilder3D.world_to_tile(member.global_position), _pressed_against(member), t]
	else:
		_fight_walk[member][2] += STEP
		if _fight_walk[member][2] >= 1.0:
			_fight_walk[member] = [flat, 0.0, 0.0]
	return ""


func _check_invariants() -> void:
	if player.is_alive():
		var at := player.global_position
		if left_hull == "" and not floors.has(ShipBuilder3D.world_to_tile(at)) and not pod.contains(at):
			left_hull = "left the Hull at %s (t=%.1f s)" % [at, t]
		if below_floor == "" and at.y < BELOW_FLOOR:
			below_floor = "fell below the floor at %s (t=%.1f s)" % [at, t]
		# The HUD offers a Door only to a Pirate in that Door's reach.
		if wrong_prompt == "":
			var offered: String = main._door_prompt()
			if offered != "" and not _in_door_reach():
				wrong_prompt = "the HUD offered '%s' with the Pirate in no Door's reach (t=%.1f s)" % [offered, t]
	if alarm_banner == "" and hud.alarm_showing() != alarm.is_raised:
		alarm_banner = "the HUD's Alarm banner %s with the Alarm %s (t=%.1f s)" % [
			"showing" if hud.alarm_showing() else "hidden", "raised" if alarm.is_raised else "not raised", t]
	# Who aims true this frame, asked first as the crew will ask it.
	var fire := CrewFire.of(player)
	if fire != null:
		fire.update()
		true_most = maxi(true_most, fire.holders.size())
		if too_many_true == "" and fire.holders.size() > TRUE_AIM_MOST:
			too_many_true = "%d Guards aimed true at once, more than %d (t=%.1f s)" % [fire.holders.size(), TRUE_AIM_MOST, t]
	for member in crew:
		if not is_instance_valid(member) or not member.is_alive():
			continue
		var stuck_fighting := _stuck_in_fight(member)
		if cover_held == "" and stuck_fighting != "":
			cover_held = stuck_fighting
		if open_fight == "":
			open_fight = _open_with_cover(member)
		if member.is_bound():
			var at: Vector3 = _bound_at.get_or_add(member, member.global_position)
			if bound_moved == "" and at.distance_to(member.global_position) > BOUND_MOVE:
				bound_moved = "a Bound Worker moved %.2f m from where it was Bound, more than %.2f m (t=%.1f s)" % [
					at.distance_to(member.global_position), BOUND_MOVE, t]
		var walking: bool = member.state == Crew3D.State.PATROL and member.routine != null \
				and member.job_phase == Crew3D.JobPhase.WALKING
		var flat := Vector3(member.global_position.x, 0.0, member.global_position.z)
		if not walking or not _anchors.has(member) or flat.distance_to(_anchors[member][0]) > STUCK_MOVE:
			_anchors[member] = [flat, t]
			continue
		if t - _anchors[member][1] > STUCK_LIMIT and not _anchors[member].size() > 2:
			_anchors[member].append(true)
			var against := _pressed_against(member)
			var what := "a %s posted in Room %d (%s) walked to a Job without moving %.0f m for %.0f s at %s, pressed against %s" % [
				"Worker" if member.is_worker() else "Guard", member.home_room, layout.rooms[member.home_room].role,
				STUCK_MOVE, STUCK_LIMIT, flat, against]
			if stuck_crew == "":
				stuck_crew = "%s (t=%.1f s)" % [what, t]


## A Guard fighting in the open (not reloading there) while a cover spot it
## would take has been in its reach for longer than OPEN_LIMIT: what it is
## and where, else empty. The spot is the one [method CrewCover.find] gives
## it, its own pick (hidden from him crouched, a peek, a fair walk within
## its reach), looked for every OPEN_LOOK seconds.
func _open_with_cover(member: Crew3D) -> String:
	var cover: CrewCover = member.cover
	if cover == null or cover.mode != CrewCover.Mode.OPEN or cover._open_reload \
			or not member.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
		_open.erase(member)
		return ""
	var seen: Array = _open.get_or_add(member, [-1.0, -INF, Vector2i.MAX])
	if t - seen[1] >= OPEN_LOOK - 0.0001:
		seen[1] = t
		var found := cover.find(0)
		if found.is_empty():
			seen[0] = -1.0
		elif seen[0] < 0.0:
			seen[0] = t
			seen[2] = found.tile
	if seen[0] >= 0.0 and t - seen[0] > OPEN_LIMIT:
		return "%s fought in the open %.1f s with a cover spot (tile %s) in its reach, longer than %.0f s (t=%.1f s)" % [
			_crew_name(member), t - seen[0], seen[2], OPEN_LIMIT, t]
	return ""


## The Pirate's body is in some Door's (or Hatch's) Trigger.
func _in_door_reach() -> bool:
	for node in get_nodes_in_group(&"doors"):
		if player in node.get_node("Trigger").get_overlapping_bodies():
			return true
	return false


## What a crew member walked into on its last move: a prop, a wall, a Door,
## a body, or nothing.
func _pressed_against(member: Crew3D) -> String:
	for k in member.get_slide_collision_count():
		var collision := member.get_slide_collision(k)
		if absf(collision.get_normal().y) > 0.7:
			continue  # the floor
		var hit := collision.get_collider() as Node
		if hit is GridMap:
			return "a wall (%s)" % hit.name
		if hit is CharacterBody3D:
			if hit == player:
				return "a body (the Pirate)"
			var other := hit as Crew3D
			return "a body (crew: %s %s, %s, %s)" % ["Worker" if other.is_worker() else "Guard", Crew3D.State.keys()[other.state],
					"walking" if other.is_walking() else ("giving way" if other._yield_to != null else "still"),
					("job " + Crew3D.JobPhase.keys()[other.job_phase]) if other.routine != null else "no routine"]
		if hit != null and _is_door(hit):
			return "a Door"
		if hit != null:
			return "a prop (%s at %s)" % [hit.scene_file_path.get_file().get_basename() if hit.scene_file_path != "" else hit.name,
					ShipBuilder3D.world_to_tile((hit as Node3D).global_position)]
	return "nothing"


## Watches crew shots: one crew member putting COVER_SHOTS shots in a row
## into the ship within COVER_SHOT_RANGE of its muzzle (never a body) fails
## the Raid. A shot is every projectile one crew member launches on one
## physics frame, so a Shotgun's 12 pellets count once (since crew-combat
## ticket 15 gave Guards their own guns), and any of them striking a body
## breaks the streak. A projectile that strikes further off (a miss past
## the Pirate, his own cover) breaks no streak and adds to none.
func _on_shot(node: Node) -> void:
	var shot := node as Projectile3D
	if shot == null or not shot.shooter is Crew3D:
		return
	var member: Crew3D = shot.shooter
	if member.is_worker() and worker_fired == "":
		worker_fired = "a Worker (%s) fired (t=%.1f s)" % [Crew3D.State.keys()[member.state], t]
	var fired_on := Engine.get_physics_frames()
	# Its gun's Muzzle, where the bolt was born (crew-combat ticket 16).
	var muzzle := shot.global_position
	shot.hit.connect(func(body: Node3D, _head: bool) -> void:
		if body is CharacterBody3D:
			_wasted[member] = 0
			return
		if not is_instance_valid(member):
			return
		if muzzle.distance_to(shot.global_position) > COVER_SHOT_RANGE:
			return
		if _wasted_shot.get(member, -1) == fired_on:
			return  # another pellet of a shot already counted
		_wasted_shot[member] = fired_on
		_wasted[member] = _wasted.get(member, 0) + 1
		if _wasted[member] == COVER_SHOTS and cover_fire == "":
			cover_fire = "a %s (%s) put %d shots in a row into the ship within %.0f m of its muzzle (%s at %s) from %.1f m off the Pirate (t=%.1f s)" % [
				"Worker" if member.is_worker() else "Guard", member.weapon.resource_path.get_file() if member.weapon else "unarmed",
				COVER_SHOTS, COVER_SHOT_RANGE,
				body.scene_file_path.get_file().get_basename() if body.scene_file_path != "" else body.name,
				ShipBuilder3D.world_to_tile(shot.global_position),
				_flat(member.global_position).distance_to(_flat(player.global_position)), t])


# --- the scripts --------------------------------------------------------------
# Each script plays until its Raid reaches an end state (extracted, or the
# Pirate down) and returns; _check_ending then judges that ending. A script
# that cannot go on (no route, stuck, the interact key refused) records why
# with _expect and returns false. Going down is an ending, not a failure.

## Crouched all the way: in, Hatch shut behind him, one Container, back
## out, extract. He fires only at crew that have noticed him (suspicious of
## him, a Guard fighting or hunting him, a Worker running for a panel or
## hiding cornered),
## standing up to do it. A Ghost Extraction is what it plays for; seen into
## an Alarm or shot down is a legitimate ending, counted against the floor.
func _quiet() -> bool:
	var budget: float = BUDGET[&"quiet"]
	var target := _pick_container(entry, true)
	_expect(target[0] != null, "no Container with gold the Pirate can reach")
	if target[0] == null:
		return false
	var box: Container3D = target[0]
	if not await _walk_to(entry, true, budget, "the boarding Hatch", Fire.THREATS):
		return false
	# Shut the Hatch behind him: an open boarding Hatch is a trace crew act on.
	if not await _loot(box, target[1], true, budget, Fire.THREATS, true):
		return false
	if not await _walk_to(home, true, budget, "the home door", Fire.THREATS):
		return false
	return await _extract(budget, Fire.THREATS)


## Assault Rifle out, into the first occupied Room, a shot there, then back to the
## pod mouth shooting whoever follows, until nobody has been in sight for a
## spell; if nobody is down yet, after the nearest Worker (else Guard),
## crouched while nobody is after him, until one is; then a Container,
## fighting on the way, and out. Hurt down to RETREAT_HEALTH in a fight, he
## falls back to the pod mouth. Extracting with a kill is what it plays for.
func _loud() -> bool:
	var budget: float = BUDGET[&"loud"]
	if not await _walk_to(entry, false, budget, "the boarding Hatch"):
		return false
	# Walk at the nearest crew member until he sees one or stands in its Room.
	var repick := 0.0
	var victim: Crew3D = null
	while true:
		if t >= repick or victim == null or not victim.is_alive():
			victim = _nearest_crew(false)
			repick = t + 1.0
			if victim == null:
				break
		var room := layout.room_at(ShipBuilder3D.world_to_tile(player.global_position))
		if not _targets(false).is_empty() or (room >= 0 and room == layout.room_at(ShipBuilder3D.world_to_tile(victim.global_position))):
			break
		if _follow(victim) == Walk.STUCK:
			_expect(false, "stuck on the way to the first occupied Room at %s" % player.global_position)
			return false
		if not await _frame(budget) or not player.is_alive():
			return false
	# The first shot, at whoever is in sight or into the Room.
	_stop()
	var seen := _targets(false)
	if not seen.is_empty():
		_aim_at(seen[0])
	player.fire()
	# Back to the pod mouth, shooting on the way, and hold it.
	if not await _walk_to(entry, false, budget, "the pod mouth", Fire.ALL, false, true):
		return false
	if not await _fight(budget, HOLD_SPELL, Fire.ALL):
		return false
	# Nobody followed him out: he goes after the nearest Worker (a Guard
	# once none is left) until one is down, crouched while nobody is after
	# him so the first shot is his.
	var quarry: Crew3D = null
	repick = 0.0
	while main.ledger.kills == 0:
		if t >= repick or quarry == null or not quarry.is_alive() or quarry.is_bound():
			quarry = _nearest_crew(false, true)
			repick = t + 1.0
			if quarry == null:
				break
		if not _targets(false).is_empty():
			if not await _fight(budget, 1.0, Fire.ALL):
				return false
			repick = 0.0
			route.clear()
			continue
		if _follow(quarry, not _hunted()) == Walk.STUCK:
			_expect(false, "stuck going after the crew at %s" % player.global_position)
			return false
		if not await _frame(budget) or not player.is_alive():
			return false
	if not await _tie_up_one(budget):
		return false
	var target := _pick_container(player.global_position, false)
	_expect(target[0] != null, "no Container with gold the Pirate can reach after the fight")
	if target[0] == null:
		return false
	if not await _loot(target[0], target[1], false, budget, Fire.ALL, false):
		return false
	if not await _walk_to(home, false, budget, "the home door", Fire.ALL):
		return false
	return await _extract(budget, Fire.ALL)


## Loud, a kill made: ties up one Worker, for at most SPARE_FOR seconds.
## He goes after the nearest hiding or surrendered Worker by route (else
## the nearest Worker, which hides or runs once it spots him), shooting no
## Worker but one running for a panel (and fighting any Guard in sight as
## usual); rests his crosshair on a hiding one in his sight within its aim
## reach until it surrenders (Sandbox surrender_aim_time), and walks up to the first surrendered one he sees
## and ties it up (_bind, at most BIND_TRIES tries). False only when he
## went down or the budget ran out; finding nobody to tie up is no failure.
func _tie_up_one(budget: float) -> bool:
	var until := t + SPARE_FOR
	var quarry: Crew3D = null
	var repick := 0.0
	_sparing = true
	var going := true
	while going and main.ledger.bound == 0 and _bind_tries < BIND_TRIES and t < until:
		if t >= repick or quarry == null or not quarry.is_alive() or quarry.is_bound():
			quarry = _nearest_worker()
			repick = t + 1.0
			if quarry == null:
				break
		if not _targets(false).is_empty():
			going = await _fight(budget, 1.0, Fire.ALL)
			repick = 0.0
			route.clear()
			continue
		var surrendered := _worker_in_sight(Crew3D.State.SURRENDER, SIGHT)
		if surrendered != null:
			going = await _bind(surrendered, budget)
			repick = 0.0
			route.clear()
			continue
		var hiding := _worker_in_sight(Crew3D.State.COWER, quarry.sandbox.surrender_aim_reach - 0.5)
		if hiding != null:
			_stop()
			_look_at(_chest(hiding))
			route.clear()
		elif _follow(quarry) == Walk.STUCK:
			break  # out of reach: no Worker tied up this Raid
		going = await _frame(budget) and player.is_alive()
	_sparing = false
	_stop()
	return going and player.is_alive()


## The living Worker not Bound nearest by route, one hiding or surrendered
## before any other, or null.
func _nearest_worker() -> Crew3D:
	var best: Crew3D = null
	var best_length := INF
	for member in crew:
		if not member.is_alive() or not member.is_worker() or member.is_bound():
			continue
		var length := _route_length(_route(player.global_position, member.global_position))
		if not member.state in [Crew3D.State.COWER, Crew3D.State.SURRENDER]:
			length += 100000.0
		if length < best_length:
			best = member
			best_length = length
	return best


## Up to the nearest Guard and stand in its view, never firing. Stood
## closer than CAUGHT_GAP to the Guard shooting at him he first walks to a
## spot 3 to 8 m from it that it can see, so a Guard boxed in beside him has
## room to work. Unhurt for CAUGHT_PATIENCE seconds while a Guard fights
## him, he moves to such a spot with nothing between his body and its
## muzzle (or, with none that far off, 1.5 to 3 m from it); unhurt that
## long again he steps out of its sight for HIDE_TIME seconds, which sends
## it searching, and then walks back into view. Going down is the only
## ending that passes.
func _caught() -> bool:
	var budget: float = BUDGET[&"caught"]
	if not await _walk_to(entry, false, budget, "the boarding Hatch"):
		return false
	var guard: Crew3D = null
	var repick := 0.0
	var spot := Vector3.INF
	var hiding := false
	var moved_out := false
	var hide_until := 0.0
	var health: int = player.health.current
	var hurt_at := t
	while player.is_alive():
		if player.health.current != health:
			health = player.health.current
			hurt_at = t
			moved_out = false
		var shooter := _guard_fighting()
		if hiding:
			if _walk(false) != Walk.WALKING:
				_stop()
				if t >= hide_until:
					hiding = false
					hurt_at = t
					repick = 0.0
		elif shooter != null:
			var gap := _flat(player.global_position).distance_to(_flat(shooter.global_position))
			if t - hurt_at > CAUGHT_PATIENCE and not moved_out:
				# Unhurt: perhaps cover between his body and its muzzle. Out
				# into the open, or with none, right up to it.
				spot = _spot_near(shooter, true)
				if spot == Vector3.INF:
					spot = _spot_near(shooter, true, SPOT_CLOSE)
				hurt_at = t
				moved_out = true
				if spot != Vector3.INF and not _plan(spot):
					spot = Vector3.INF
			elif t - hurt_at > CAUGHT_PATIENCE:
				var cover := _spot_near(shooter, false)
				moved_out = false
				if cover != Vector3.INF:
					hiding = true
					hide_until = t + HIDE_TIME
					_plan(cover)
			elif spot == Vector3.INF and gap < CAUGHT_GAP:
				spot = _spot_near(shooter, true)
				if spot != Vector3.INF:
					_plan(spot)
			if not hiding:
				var to_guard := shooter.global_position - player.global_position
				if spot == Vector3.INF or _walk(false, to_guard) != Walk.WALKING:
					spot = Vector3.INF
					_stop()
				_aim_at(shooter)
		else:
			spot = Vector3.INF
			if t >= repick or guard == null or not guard.is_alive():
				guard = _nearest_crew(true)
				repick = t + 1.0
				if guard == null:
					_expect(false, "no Guard aboard to be caught by")
					return false
			if _follow(guard) != Walk.WALKING:
				_stop()
				_aim_at(guard)
		if not await _frame(budget):
			return false
	return true


# --- moves --------------------------------------------------------------------

## One frame of walking at a crew member, planning again only when it has
## moved FOLLOW_SLACK from where the route ends (or he has none).
func _follow(member: Crew3D, crouch := false) -> Walk:
	if route.is_empty() or _flat(goal).distance_to(_flat(member.global_position)) > FOLLOW_SLACK:
		if not _plan(member.global_position):
			return Walk.STUCK
	return _walk(crouch)


## Walks to [param to]. Crew [param fire] picks out are fought: stood still
## until nobody has been in sight for a second, or with [param on_the_move]
## shot at without breaking stride. [param shut_hatch]: shuts the boarding
## Hatch once through it. Walking to a Container's stand cell, [param box]:
## he stops wherever it is already in reach (a crew member may be stood on
## the cell), and when stuck on the way tries up to two other stand cells
## clear of crew; still stuck, it returns false with [member box_blocked]
## set and no failure recorded, for the caller to pick another Container.
## A route that ends more than half a metre short of [param to] is planned
## again, up to SHORT_ENDS times.
func _walk_to(to: Vector3, crouch: bool, budget: float, what: String, fire := Fire.NONE,
		shut_hatch := false, on_the_move := false, box: Container3D = null) -> bool:
	box_blocked = false
	var other_cells := 2
	var short_ends := SHORT_ENDS
	if not _plan(to):
		_expect(false, "no route to %s" % what)
		return false
	while true:
		var targets: Array[Crew3D] = []
		if fire != Fire.NONE:
			targets = _targets(fire == Fire.THREATS)
		if not targets.is_empty() and not on_the_move:
			if not await _fight(budget, 1.0, fire):
				return false
			# Re-plans so far still count: a walk broken by fight after fight
			# that never gets there still ends STUCK.
			var replans := _replans
			if not _plan(to):
				_expect(false, "no route to %s after a fight" % what)
				return false
			_replans = replans
		if shut_hatch and hatch_leaf.is_open and hatch_leaf.in_reach_of(player) \
				and _flat(player.global_position).distance_to(_flat(hatch_leaf.global_position)) > 1.5:
			_tap(&"interact")
		var look := Vector3.ZERO
		if not targets.is_empty():
			look = targets[0].global_position - player.global_position
		elif fire != Fire.NONE:
			_reload_in_lull()
		# Crouched until crew are after him: then up, to see over cover.
		var state := _walk(crouch and not _hunted(), look)
		if not targets.is_empty():
			_aim_at(targets[0])
			_fire_at(targets[0])
		if box != null and _within_reach(box) and not _in_door_reach():
			_stop()
			return true
		if state == Walk.ARRIVED and short_ends > 0 and _flat(player.global_position).distance_to(_flat(to)) > 0.5:
			# The route ended short of where he was going (a re-plan round a
			# crew member snaps its end to a neighbouring cell): plan again.
			short_ends -= 1
			state = Walk.WALKING if _plan(to) else Walk.STUCK
		if state == Walk.ARRIVED:
			_stop()
			return true
		if state == Walk.STUCK and box != null and other_cells > 0:
			# Someone stood on the stand cell: another one, clear of crew.
			other_cells -= 1
			var other := _stand_cell(box, true)
			if other != Vector3.INF and _plan(other):
				to = other
				state = Walk.WALKING
		if state == Walk.STUCK and box != null:
			box_blocked = true
			return false
		if state == Walk.STUCK:
			_expect(false, "stuck on the way to %s at %s" % [what, player.global_position])
			return false
		if not await _frame(budget):
			return false
		if not player.is_alive():
			return false  # down: an ending, judged by _check_ending
	return false


## Stands and shoots the nearest crew member [param fire] picks out until
## nobody has been in sight for [param spell] seconds (HOLD_SPELL at least
## once down to RETREAT_HEALTH, when he also falls back to the pod mouth
## while he shoots, at most RETREATS times a Raid so that a hurt Pirate
## does not shuttle between a fight and the pod for ever). He reloads in
## the lulls. One he sees past a corner his barrel does not clear, he
## sidesteps for.
func _fight(budget: float, spell: float, fire: Fire) -> bool:
	var calm := 0.0
	var falling_back := false
	while calm < (maxf(spell, HOLD_SPELL) if player.health.current <= RETREAT_HEALTH else spell):
		Input.action_release(&"crouch")
		var targets := _targets(fire == Fire.THREATS)
		var retreat: bool = player.health.current <= RETREAT_HEALTH \
				and _flat(player.global_position).distance_to(_flat(entry)) > 1.0
		if retreat and not falling_back and _retreats < RETREATS:
			falling_back = _plan(entry)
			_retreats += 1
		var look := Vector3.ZERO
		if not targets.is_empty():
			look = targets[0].global_position - player.global_position
		var peeker: Crew3D = _barrel_blocked() if targets.is_empty() else null
		if retreat and falling_back and _walk(false, look) == Walk.WALKING:
			pass
		elif peeker != null:
			# His eyes see it past a corner his barrel does not clear: a
			# sidestep, one way then the other.
			var to := _flat(peeker.global_position - player.global_position).normalized()
			var side := to.cross(Vector3.UP) * (1.0 if int(t / SIDESTEP_TIME) % 2 == 0 else -1.0)
			_drive(side, false, to)
			_aim_at(peeker)
		else:
			_stop()
		if targets.is_empty():
			calm += STEP
			_reload_in_lull()
		else:
			calm = 0.0
			_aim_at(targets[0])
			_fire_at(targets[0])
		if not await _frame(budget):
			return false
		if not player.is_alive():
			return false  # down: an ending, judged by _check_ending
	return true


## With nobody to shoot and the magazine half spent, reloads now rather
## than mid-fight.
func _reload_in_lull() -> void:
	if player.ammo * 2 < player.weapon.magazine_size and not player.is_reloading():
		player.start_reload()


## Attacks a crew member he is aimed at: a melee swing inside MELEE_REACH
## (his barrel would be inside it), otherwise sights up and the trigger
## whenever the cone is tight enough for the range. One further off
## than GIVE_UP_BEYOND that he has been shooting at for GIVE_UP_AFTER
## seconds without a wound (a bolt that keeps catching cover his eyes see
## past) is left alone for GIVE_UP_FOR.
func _fire_at(member: Crew3D) -> void:
	if _flat(member.global_position).distance_to(_flat(player.global_position)) < MELEE_REACH:
		player.melee()
		return
	var health: int = member.health.current
	var near := _flat(member.global_position).distance_to(_flat(player.global_position)) < GIVE_UP_BEYOND
	if near or not _engaged.has(member) or _engaged[member][0] != health:
		_engaged[member] = [health, t]
	elif t - _engaged[member][1] > GIVE_UP_AFTER:
		_given_up[member] = t + GIVE_UP_FOR
		_engaged.erase(member)
		return
	# Sights up, and the trigger only while the cone is tight enough to land
	# on a body at this range: bursts, not a hosepipe.
	Input.action_press(&"aim")
	_aim_until = t + 0.5
	var distance: float = player.camera.global_position.distance_to(_chest(member))
	if player.spread_degrees() <= maxf(rad_to_deg(atan(BODY_HALF_WIDTH / distance)), MIN_SPREAD):
		player.fire()


## Walks to [param box] and searches it. A Container he cannot get to (a
## crew member planted on every stand cell, or his walk ending short of its
## reach against a wall corner) is swapped for the nearest other candidate,
## up to LOOT_TRIES Containers.
func _loot(box: Container3D, stand: Vector3, crouch: bool, budget: float, fire: Fire, shut_hatch: bool) -> bool:
	var tried: Array[Container3D] = []
	for attempt in LOOT_TRIES:
		if await _walk_to(stand, crouch, budget, "the Container", fire, shut_hatch, false, box):
			if await _search(box, budget, fire):
				return true
		if not box_blocked:
			return false
		tried.append(box)
		var next := _pick_container(player.global_position, false, tried)
		if next[0] == null:
			break
		box = next[0]
		stand = next[1]
	_expect(false, "no Container reachable after %d tries (crew planted on the stand cells, or short of reach)" % tried.size())
	return false


## Faces the Container and works the interact key until it is searched.
## Short of its reach (his walk can end a little short), or with another
## Container nearer in his view (the key works the nearest he faces), he
## first steps straight at it, and stood in a Door's reach (where the Door's prompt
## comes first, by design) he steps to its stand cell, clear of every Door;
## for up to SEARCH_PATIENCE seconds. In reach, clear of the Doors and
## facing it, the HUD must offer the search and the key must search it
## within SEARCH_PATIENCE seconds; anything else fails the Raid. Never in
## reach (clear of the Doors) by then, it returns false with
## [member box_blocked] set and no verdict, for _loot to try another. Crew [param fire]
## picks out are fought first, and the patience starts again after.
func _search(box: Container3D, budget: float, fire: Fire) -> bool:
	box_blocked = false
	var before: int = main.ledger.carried_gold
	var started := t
	var prompt_checked := false
	while not box.is_open and t < started + SEARCH_PATIENCE:
		if not _targets(fire == Fire.THREATS).is_empty():
			if not await _fight(budget, 1.0, fire):
				return false
			started = t
		var to_box := _flat(box.global_position - player.global_position)
		if _in_door_reach():
			# A Door's prompt comes first here, by design: over to the
			# Container's stand cell, clear of every Door.
			var stand := _stand_cell(box)
			var to_stand := _flat(stand - player.global_position) if stand != Vector3.INF else to_box
			_drive(to_stand.normalized(), false, to_stand)
		elif not _workable(box):
			# Short of it, or another Container is nearer in his view (the
			# key works the nearest he faces): closer to this one.
			_drive(to_box.normalized(), false, to_box)
		else:
			_stop()
			_look_at(box.global_position + Vector3(0, 0.5, 0))
			if not prompt_checked:
				prompt_checked = true
				started = t  # the key's own patience starts in reach
				_expect(main._prompt() == box.prompt_text(), "facing a Container %.2f m off, the HUD offers '%s', not '%s'"
						% [to_box.length(), main._prompt(), box.prompt_text()])
			_tap(&"interact")
		if not await _frame(budget):
			return false
		if not player.is_alive():
			return false  # down: an ending, judged by _check_ending
	if not box.is_open and (not _workable(box) or _in_door_reach()):
		# Never got to work it: no verdict on the key; _loot tries another.
		_stop()
		box_blocked = true
		return false
	_expect(box.is_open and main.ledger.carried_gold > before, "the interact key did not search the Container in reach in %.0f s (%.2f m off, prompt '%s')"
			% [SEARCH_PATIENCE, _flat(box.global_position).distance_to(_flat(player.global_position)), main._prompt()])
	_expect(hud.loot_text().contains(str(main.ledger.carried_gold)), "the HUD Loot line '%s' does not show %d gold" % [hud.loot_text(), main.ledger.carried_gold])
	return box.is_open


## Whether he could work [param box] from where he stands, facing it.
func _within_reach(box: Container3D) -> bool:
	var to := _flat(box.global_position - player.global_position)
	return to.length() < Container3D.REACH - 0.2 and box.in_reach(player, to)


## In reach of [param box] and, facing it, it is the Container the
## interact key would work (the nearest he faces; `main_3d.gd`).
func _workable(box: Container3D) -> bool:
	if not _within_reach(box):
		return false
	var saved: Basis = player.global_basis
	var to := _flat(box.global_position - player.global_position)
	player.global_basis = Basis.looking_at(to.normalized(), Vector3.UP)
	var offered: Container3D = main._container_in_reach()
	player.global_basis = saved
	return offered == box


## Works the home door and waits out the countdown, shooting whoever
## [param fire] picks out without stepping off the spot.
func _extract(budget: float, fire: Fire) -> bool:
	while not extraction.is_done:
		_stop()
		Input.action_release(&"crouch")
		var targets := _targets(fire == Fire.THREATS)
		if not extraction.is_counting() and extraction.can_begin():
			_look_at(home + (home - entry).normalized() + Vector3(0, 1.6, 0))
			_tap(&"interact")
		elif not targets.is_empty():
			_aim_at(targets[0])
			_fire_at(targets[0])
		if not await _frame(budget):
			return false
		if not player.is_alive():
			return false  # down: an ending, judged by _check_ending
	return true


func _tap(action: StringName) -> void:
	if _taps.has(action):
		return
	Input.action_press(action)
	_taps[action] = 0


func _release_all() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right", &"crouch", &"interact", &"sprint", &"shoot", &"jump", &"aim"]:
		Input.action_release(action)


func _stop() -> void:
	for action in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		Input.action_release(action)


## Moves along [param direction] (flat) looking along [param look], or along
## the direction when look is zero, through the same actions a player holds.
func _drive(direction: Vector3, crouch: bool, look := Vector3.ZERO) -> void:
	if crouch:
		Input.action_press(&"crouch")
	else:
		Input.action_release(&"crouch")
	var facing := look if look.length_squared() > 0.0001 else direction
	facing.y = 0.0
	if facing.length_squared() > 0.0001:
		player.global_basis = Basis.looking_at(facing.normalized(), Vector3.UP)
	var local := player.global_basis.inverse() * direction
	_press(&"move_right", local.x)
	_press(&"move_left", -local.x)
	_press(&"move_down", local.z)
	_press(&"move_up", -local.z)


func _press(action: StringName, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, minf(strength, 1.0))
	else:
		Input.action_release(action)


func _look_at(point: Vector3) -> void:
	var camera: Camera3D = player.camera
	var to := point - camera.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length_squared() > 0.0001:
		player.global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	player.head.rotation.x = atan2(to.y, flat.length())


## Looks at a crew member's chest, led by where its walk carries it while
## the bolt flies.
func _aim_at(member: Crew3D) -> void:
	var chest := _chest(member)
	var flight: float = player.camera.global_position.distance_to(chest) / player.weapon.projectile_speed
	_look_at(chest + Vector3(member.velocity.x, 0.0, member.velocity.z) * flight)


# --- what he sees -------------------------------------------------------------

## The point he aims at on [param member]: CHEST up, or lower while its
## body is lowered behind cover.
func _chest(member: Crew3D) -> Vector3:
	var height := CHEST
	var shape := member.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is CapsuleShape3D:
		height = minf(CHEST, shape.position.y + (shape.shape as CapsuleShape3D).height / 2.0 - CHEST_BELOW_TOP)
	return member.global_position + Vector3(0, height, 0)


## Living crew he would shoot at: a clear line from his eyes and from the
## muzzle to the chest, within SIGHT, not given up on; a fleeing Worker
## first, then nearest first. With
## [param threats_only], only crew already after him: a Guard hunting or
## fighting him, a Worker fleeing to raise the Alarm or hiding cornered,
## or anyone suspicious of him (_onto_him).
func _targets(threats_only: bool) -> Array[Crew3D]:
	var out: Array[Crew3D] = []
	var eye: Vector3 = player.camera.global_position
	# Where his next bolt leaves from: the barrel tip as drawn.
	var muzzle: Vector3 = player._shot_origin()
	var space := player.get_world_3d().direct_space_state
	for member in crew:
		if not is_instance_valid(member) or not member.is_alive() or _given_up.get(member, -1.0) > t:
			continue
		if member.is_bound() or (threats_only and not _onto_him(member)):
			continue
		if _sparing and member.is_worker() and member.state != Crew3D.State.FLEE:
			continue
		var chest := _chest(member)
		if eye.distance_to(chest) > SIGHT:
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, chest, 1)).is_empty() \
				and space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, chest, 1)).is_empty():
			out.append(member)
	# A Worker running for an Alarm Panel first, then nearest first.
	out.sort_custom(func(a: Crew3D, b: Crew3D) -> bool:
		var a_runs := a.state == Crew3D.State.FLEE
		if a_runs != (b.state == Crew3D.State.FLEE):
			return a_runs
		return a.global_position.distance_to(eye) < b.global_position.distance_to(eye))
	return out


## The nearest crew member after him that his eyes see but his barrel
## does not (a corner between the muzzle and its chest), within 8 m; null
## when none.
func _barrel_blocked() -> Crew3D:
	var eye: Vector3 = player.camera.global_position
	var muzzle: Vector3 = player._shot_origin()
	var space := player.get_world_3d().direct_space_state
	var best: Crew3D = null
	for member in crew:
		if not is_instance_valid(member) or not member.is_alive() or not member.state in THREAT_STATES:
			continue
		var chest := _chest(member)
		if eye.distance_to(chest) > 8.0 or (best != null and eye.distance_to(chest) > eye.distance_to(best.global_position)):
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, chest, 1)).is_empty() \
				and not space.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle, chest, 1)).is_empty():
			best = member
	return best


## A crew member after him (THREAT_STATES), or one that has noticed him
## (suspicious, coming to look): shot before it spots him, it never
## fires back and never runs for an Alarm Panel. A Worker hiding (COWER,
## crew-combat ticket 23) is harmless and left be, unless it hides cornered (him in its sight
## within Crew3D.CORNERED_RANGE): stood at his elbow it can wall off his
## way out (seen on the way to the home door, 0.7 m off, in a gate after
## crew-combat ticket 15), and before that ticket a cornered Worker fought
## (FIGHT) and was shot as a threat, so it is still shot. A Worker that
## has surrendered to him (SURRENDER, crew-combat ticket 24; a hiding Worker
## surrenders when he comes within 4 m) is the same: harmless, left be,
## shot only at his elbow, its kill worth 0 XP. A Bound one is never shot
## (Loud ties one up, _bind; _targets leaves Bound Workers out).
func _onto_him(member: Crew3D) -> bool:
	if member.state in [Crew3D.State.COWER, Crew3D.State.SURRENDER]:
		return member._cornered()
	if member.state == Crew3D.State.BOUND:
		return false
	return member.state in THREAT_STATES or member.perception.awareness >= CrewPerception.SUSPICIOUS


## Some crew member within SIGHT is after him (THREAT_STATES).
func _hunted() -> bool:
	for member in crew:
		if is_instance_valid(member) and member.is_alive() and member.state in THREAT_STATES \
				and member.global_position.distance_to(player.global_position) < SIGHT:
			return true
	return false


## The living crew member (a Guard when [param guard]) nearest by route
## from where he stands; with [param worker_first], the nearest Worker while
## any lives.
func _nearest_crew(guard: bool, worker_first := false) -> Crew3D:
	var best: Crew3D = null
	var best_length := INF
	for member in crew:
		if not member.is_alive() or member.is_bound() or (guard and member.is_worker()):
			continue
		var length := _route_length(_route(player.global_position, member.global_position))
		if worker_first and not member.is_worker():
			length += 100000.0
		if length < best_length:
			best = member
			best_length = length
	return best


## The nearest living Worker in [param state] within [param reach] metres
## with a clear line from his eyes to its chest, or null.
func _worker_in_sight(state: Crew3D.State, reach: float) -> Crew3D:
	var eye: Vector3 = player.camera.global_position
	var space := player.get_world_3d().direct_space_state
	var best: Crew3D = null
	for member in crew:
		if not is_instance_valid(member) or not member.is_alive() or not member.is_worker() or member.state != state:
			continue
		var chest := _chest(member)
		if eye.distance_to(chest) > reach or (best != null and eye.distance_to(chest) > eye.distance_to(_chest(best))):
			continue
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, chest, 1)).is_empty():
			best = member
	return best


## Ties up [param member], a surrendered Worker, as a player does: walks to
## within BIND_STAND of it, faces it, presses the interact key afresh and
## holds it until it is Bound (the Sandbox's bind time) or BIND_PATIENCE
## passes. A Worker he cannot reach, or one that stops being surrendered,
## ends the try. False only when he went down or the budget ran out.
func _bind(member: Crew3D, budget: float) -> bool:
	_bind_tries += 1
	_taps.erase(&"interact")
	Input.action_release(&"interact")
	if not _plan(member.global_position):
		return true
	var short_ends := SHORT_ENDS
	while member.is_surrendered() and _flat(member.global_position).distance_to(_flat(player.global_position)) > BIND_STAND:
		var state := _walk(false, member.global_position - player.global_position)
		if state == Walk.ARRIVED:
			short_ends -= 1
			if short_ends < 0 or not _plan(member.global_position):
				return true
		elif state == Walk.STUCK:
			return true
		if not await _frame(budget) or not player.is_alive():
			return false
	_stop()
	_look_at(member.global_position + Vector3.UP * 0.6)
	if not await _frame(budget) or not player.is_alive():
		return false
	Input.action_press(&"interact")
	var until := t + BIND_PATIENCE
	while member.is_surrendered() and t < until:
		_look_at(member.global_position + Vector3.UP * 0.6)
		if not await _frame(budget) or not player.is_alive():
			Input.action_release(&"interact")
			return false
	Input.action_release(&"interact")
	return true


## A Guard shooting at him (or about to), with him in its sight.
func _guard_fighting() -> Crew3D:
	for member in _targets(false):
		if not member.is_worker() and member.state in [Crew3D.State.FIGHT, Crew3D.State.COVER]:
			return member
	return null


## An open cell [param ring] metres from [param member] (SPOT_NEAR by
## default), nearest him, that he can walk to: with [param seen], a clear
## line from eye height there to its chest and from its muzzle to the top
## and bottom of his body (a bolt grazes the line, so both ends must be
## clear); without, the eye line blocked. INF when none.
func _spot_near(member: Crew3D, seen: bool, ring := SPOT_NEAR) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var chest := _chest(member)
	var centre := _cell(member.global_position)
	var best := Vector3.INF
	var best_distance := INF
	var cells := ceili(ring.y / CELL)
	for dx in range(-cells, cells + 1):
		for dz in range(-cells, cells + 1):
			var cell := centre + Vector2i(dx, dz)
			var reach := Vector2(dx, dz).length() * CELL
			if reach < ring.x or reach > ring.y or not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
				continue
			var point := _world(cell)
			var distance := _flat(point).distance_to(_flat(player.global_position))
			if distance >= best_distance:
				continue
			var clear := space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3(0, 1.6, 0), chest, 1)).is_empty()
			if clear and seen:
				# From its gun's Muzzle as it would aim at him there.
				var muzzle := member.aim_muzzle(member.global_position, point + Vector3.UP * Crew3D.TORSO_HEIGHT)
				for height in [0.7, 1.3]:
					clear = clear and space.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3(0, height, 0),
							muzzle, 1)).is_empty()
			if clear == seen and not _route(player.global_position, point).is_empty():
				best = point
				best_distance = distance
	return best


# --- targets ------------------------------------------------------------------

## The candidate Container nearest by route from [param from]; with
## [param quiet], the one with the least exposure (route metres plus
## CREW_POST_COST per crew member posted in each Room on the way, doubled for
## a Guard's Post). [Container3D or null, stand point].
func _pick_container(from: Vector3, quiet: bool, skip: Array[Container3D] = []) -> Array:
	var best: Container3D = null
	var best_stand := Vector3.ZERO
	var best_cost := INF
	for node in get_nodes_in_group(&"containers"):
		var box: Container3D = node
		if box.is_open or box.gold <= 0 or box in skip:
			continue
		var stand := _stand_cell(box)
		if stand == Vector3.INF:
			continue
		var path := _route(from, stand)
		if path.is_empty():
			continue
		var cost := _route_length(path, from)
		if quiet:
			var rooms := ShipNavigator.room_path(layout, layout.room_at(ShipBuilder3D.world_to_tile(from)),
					layout.room_at(ShipBuilder3D.world_to_tile(stand)))
			for room in rooms:
				var weight := 2.0 if layout.rooms[room].role in CrewTypes.GUARD_ROLES else 1.0
				cost += CREW_POST_COST * weight * layout.rooms[room].crew_count
		if cost < best_cost:
			best = box
			best_stand = stand
			best_cost = cost
	return [best, best_stand]


## The open cell nearest a Container within STAND_REACH, clear of every door
## by STAND_DOOR_GAP (and of every crew member when [param clear_of_crew]);
## INF when none.
func _stand_cell(box: Container3D, clear_of_crew := false) -> Vector3:
	var at := box.global_position
	var centre := _cell(at)
	var reach := ceili(STAND_REACH / CELL)
	var best := Vector3.INF
	var best_distance := INF
	for dx in range(-reach, reach + 1):
		for dz in range(-reach, reach + 1):
			var cell := centre + Vector2i(dx, dz)
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
				continue
			var point := _world(cell)
			var distance := _flat(point).distance_to(_flat(at))
			if distance > STAND_REACH or distance >= best_distance or _near_door(point):
				continue
			if clear_of_crew and crew.any(func(m: Crew3D) -> bool:
					return m.is_alive() and _flat(m.global_position).distance_to(_flat(point)) < CREW_BLOCK + 0.4):
				continue
			best = point
			best_distance = distance
	return best


## Whether a Pirate stood at [param point] would be in some door's reach
## (its Trigger box, widened by STAND_DOOR_GAP), so the interact key would
## work the door rather than search.
func _near_door(point: Vector3) -> bool:
	for node in get_nodes_in_group(&"doors"):
		var shape: CollisionShape3D = node.get_node("Trigger").get_child(0)
		var half: Vector3 = (shape.shape as BoxShape3D).size / 2.0
		var local := shape.global_transform.affine_inverse() * (point + Vector3(0, half.y, 0))
		if absf(local.x) < half.x + STAND_DOOR_GAP and absf(local.z) < half.z + STAND_DOOR_GAP:
			return true
	return false


# --- routes -------------------------------------------------------------------

## Plans a route from where he stands to [param to]. False when there is none.
func _plan(to: Vector3) -> bool:
	goal = to
	route = _route(player.global_position, to)
	_best = INF
	_best_t = t
	_replans = 0
	return not route.is_empty()


## One frame of walking the planned route.
func _walk(crouch: bool, look := Vector3.ZERO) -> Walk:
	var at := _flat(player.global_position)
	while not route.is_empty():
		var radius := 0.25 if route.size() == 1 else 0.4
		if at.distance_to(_flat(route[0])) > radius:
			break
		route.pop_front()
		_best = INF
		_best_t = t
	if route.is_empty():
		_stop()
		return Walk.ARRIVED
	var next := _flat(route[0])
	var distance := at.distance_to(next)
	if distance < _best - 0.1:
		_best = distance
		_best_t = t
	elif t - _best_t > REPLAN_AFTER:
		_replans += 1
		route = _route_round_crew(goal)
		if route.is_empty():
			# A crew member stood on the spot itself: the plain route, to
			# wait it out.
			route = _route(player.global_position, goal)
		_best = INF
		_best_t = t
		if route.is_empty() or _replans > REPLANS:
			_stop()
			return Walk.STUCK
		next = _flat(route[0])
	_open_doors_ahead(next)
	_drive((next - at).normalized(), crouch, look)
	return Walk.WALKING


## A fresh route to [param to] that steers round any crew member he has
## walked into (one stood working where he means to go, say): the cells
## within CREW_BLOCK of it count as solid for this one plan.
func _route_round_crew(to: Vector3) -> Array[Vector3]:
	var blocked: Array[Vector2i] = []
	for k in player.get_slide_collision_count():
		var body := player.get_slide_collision(k).get_collider() as Crew3D
		if body == null:
			continue
		var centre := _cell(body.global_position)
		var reach := ceili(CREW_BLOCK / CELL)
		for dx in range(-reach, reach + 1):
			for dz in range(-reach, reach + 1):
				var cell := centre + Vector2i(dx, dz)
				if Vector2(dx, dz).length() * CELL <= CREW_BLOCK and grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
					grid.set_point_solid(cell, true)
					blocked.append(cell)
	var points := _route(player.global_position, to)
	for cell in blocked:
		grid.set_point_solid(cell, false)
	return points


## Taps interact for a shut Door (or Hatch) in reach that the route runs
## through next.
func _open_doors_ahead(next: Vector3) -> void:
	var at := _flat(player.global_position)
	for node in get_nodes_in_group(&"doors"):
		var door: Door3D = node
		if door.is_open or door.locked or door.sealed or not door.in_reach_of(player):
			continue
		var to_door := _flat(door.global_position) - at
		if to_door.length() > 2.2:
			continue
		if _flat(door.global_position).distance_to(next) < 1.5 or to_door.normalized().dot((next - at).normalized()) > 0.3:
			_tap(&"interact")
			return


## Points to steer through from [param from] to [param to]: the navigator's
## waypoints, each reached by the cell grid. A waypoint the grid cannot
## reach (a seam crossing boxed in by props) is skipped for the next one;
## empty when the destination itself cannot be reached.
func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var head: Array[Vector3] = []
	var tail: Array[Vector3] = []
	var gap := ShipBuilder3D.hatch_center_world(pod.hatch)
	var in_pod_from := pod.contains(from + Vector3(0, 0.5, 0))
	var in_pod_to := pod.contains(to + Vector3(0, 0.5, 0))
	if in_pod_from and in_pod_to:
		return [to]
	if in_pod_from:
		head = [gap, entry]
		from = entry
	if in_pod_to:
		tail = [entry, gap, to]
		to = entry
	var legs := ShipNavigator.waypoints_3d(layout, from, to)
	if legs.is_empty():
		legs = [to]
	var points: Array[Vector3] = head.duplicate()
	var cursor := from
	for k in legs.size():
		var a := _open_cell(_cell(cursor))
		var b := _open_cell(_cell(legs[k]))
		var cells: Array[Vector2i] = []
		if a != Vector2i.MAX and b != Vector2i.MAX:
			cells = grid.get_id_path(a, b)
		if cells.is_empty():
			if k < legs.size() - 1:
				continue  # a waypoint boxed in by props: on to the next
			return []
		points.append_array(_smooth(cells))
		cursor = legs[k]
	points.append_array(tail)
	return points


func _route_length(points: Array[Vector3], from := Vector3.INF) -> float:
	if points.is_empty():
		return INF
	var cursor := player.global_position if from == Vector3.INF else from
	var length := 0.0
	for p in points:
		length += _flat(cursor).distance_to(_flat(p))
		cursor = p
	return length


## The cells worth steering at: the furthest along the path still in a
## clear straight line, again and again.
func _smooth(cells: Array[Vector2i]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var anchor := 0
	while anchor < cells.size() - 1:
		var far := anchor + 1
		for k in range(anchor + 2, cells.size()):
			if not _clear(cells[anchor], cells[k]):
				break
			far = k
		out.append(_world(cells[far]))
		anchor = far
	if out.is_empty():
		out.append(_world(cells[0]))
	return out


## Every cell around every point along the line is open.
func _clear(a: Vector2i, b: Vector2i) -> bool:
	var from := Vector2(a)
	var to := Vector2(b)
	var samples := ceili(from.distance_to(to) * 4.0)
	for s in samples + 1:
		var p := from.lerp(to, float(s) / maxf(samples, 1))
		for cell in [Vector2i(floori(p.x), floori(p.y)), Vector2i(ceili(p.x), floori(p.y)),
				Vector2i(floori(p.x), ceili(p.y)), Vector2i(ceili(p.x), ceili(p.y))]:
			if not grid.is_in_boundsv(cell) or grid.is_point_solid(cell):
				return false
	return true


func _cell(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x / CELL), roundi(point.z / CELL))


func _world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0.0, cell.y * CELL)


func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


## The cell itself when open, else the nearest open one within a metre.
func _open_cell(cell: Vector2i) -> Vector2i:
	if grid.is_in_boundsv(cell) and not grid.is_point_solid(cell):
		return cell
	var best := Vector2i.MAX
	var best_distance := INF
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var c := cell + Vector2i(dx, dz)
			if grid.is_in_boundsv(c) and not grid.is_point_solid(c) and Vector2(dx, dz).length() < best_distance:
				best = c
				best_distance = Vector2(dx, dz).length()
	return best


## The half-metre grid over the ship's floor: a cell is open when its tile
## is floor (a locked Door's tiles are not) and a box the Pirate's width at
## waist height overlaps nothing solid but Door leaves.
func _build_grid() -> AStarGrid2D:
	var tiles := floors.duplicate()
	for door in layout.doors:
		if door.locked:
			for tile in door.tiles():
				tiles.erase(tile)
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := -lo
	for tile: Vector2i in tiles:
		lo = Vector2i(mini(lo.x, tile.x), mini(lo.y, tile.y))
		hi = Vector2i(maxi(hi.x, tile.x), maxi(hi.y, tile.y))
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(lo * 2 - Vector2i.ONE, (hi - lo) * 2 + Vector2i(4, 4))
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	astar.fill_solid_region(astar.region, true)
	var space := main.get_world_3d().direct_space_state
	var box := BoxShape3D.new()
	box.size = Vector3(CLEARANCE * 2.0, BOX_HEIGHT, CLEARANCE * 2.0)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = 1
	var r := astar.region
	for x in range(r.position.x, r.end.x):
		for y in range(r.position.y, r.end.y):
			var cell := Vector2i(x, y)
			var at := _world(cell)
			if not tiles.has(ShipBuilder3D.world_to_tile(at)):
				continue
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0, BOX_Y, 0))
			var solid := false
			for hit in space.intersect_shape(query, 8):
				if not _is_door(hit.collider):
					solid = true
					break
			if not solid:
				astar.set_point_solid(cell, false)
	return astar


func _is_door(node: Object) -> bool:
	var n := node as Node
	while n != null and not n is BoardingPod and n != main:
		if n is Door3D:
			return true
		n = n.get_parent()
	return false
