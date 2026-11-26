class_name CrewMagazine
extends RefCounted
## A Guard's magazine: the rounds in its gun, counted against its Weapon
## Profile's magazine size, and its reloads. It starts full and has
## unlimited magazines. A reload takes the Profile's time times the
## Gunnery's reload factor: the empty reload from dry, the shorter tactical
## reload to top up a part-used magazine. A Shotgun loads shell by shell
## with the Profile's shell times times the factor, and may break off with
## a shell in to fire. Nothing else cancels or restarts a reload: being
## shot, flanked or closed on does not. The Profile's reload sounds play at
## the Guard's position: the first as a magazine comes out, the second as
## the new one goes in; for the Shotgun the first as it reaches for a shell
## and again as each shell seats.
##
## Every Guard holds one ([member Crew3D.magazine]); [CrewCover] decides
## where and when a reload starts, and the body ticks it every physics
## step, so a reload runs to its end whatever the Guard does meanwhile. A
## Guard reloading takes no true-aim place and fires nothing. The body
## emits [signal Crew3D.reload_started], [signal Crew3D.shell_loaded] and
## [signal Crew3D.reload_ended] for its pose. See "Magazines and reloads" in
## `CREW_AI.md`.

var crew: Crew3D
## Rounds in the gun now.
var rounds := 0
## Reloading now, and whether this reload began from a dry gun.
var reloading := false
var from_empty := false
## Seconds left on the whole reload (a magazine), or on the shell being
## loaded (a Shotgun).
var left := 0.0
## Seconds this reload takes in all, from its start: for checks.
var duration := 0.0


func _init(body: Crew3D) -> void:
	crew = body
	rounds = size()


## The Profile's magazine size; 0 unarmed.
func size() -> int:
	return maxi(crew.weapon.magazine_size, 1) if crew.weapon != null else 0


func is_dry() -> bool:
	return rounds <= 0


func is_full() -> bool:
	return rounds >= size()


## Whether its gun can fire now: a round in and not reloading.
func can_fire() -> bool:
	return not reloading and rounds > 0


## One round fired.
func spend() -> void:
	rounds = clampi(rounds - 1, 0, size())


## The Gunnery's reload factor (1.5).
func factor() -> float:
	return crew.gunnery.reload_factor if crew.gunnery != null else 1.0


func shell_by_shell() -> bool:
	return crew.weapon != null and crew.weapon.shell_reload


## Seconds a reload from [param rounds_in] rounds to full takes in a Guard's
## hands. A magazine: the Profile's empty reload from dry, else its
## tactical reload. Shell by shell: the first shell's time, then a shell's
## time for each after it. The crew Shotgun has no closing pump of its own:
## it racks before its next shot anyway ([method Crew3D.rack]), and that
## rack is its pump.
func time_from(rounds_in: int) -> float:
	var weapon := crew.weapon
	if weapon == null:
		return 0.0
	if weapon.shell_reload:
		var shells := size() - rounds_in
		if shells <= 0:
			return 0.0
		return (weapon.first_shell_time + weapon.shell_time * (shells - 1)) * factor()
	return (weapon.reload_empty if rounds_in <= 0 else weapon.reload_tactical) * factor()


## The longest a reload of this gun takes: from dry.
func longest() -> float:
	return time_from(0)


## Seconds left until this reload ends (full), or 0 when not reloading.
func time_left() -> float:
	if not reloading:
		return 0.0
	if shell_by_shell():
		var weapon := crew.weapon
		return left + weapon.shell_time * factor() * maxi(size() - rounds - 1, 0)
	return left


## Starts a reload: from dry, or topping up a part-used magazine. Gives up
## true aim at once ([method CrewFire.give_up]). Does nothing when already
## reloading, full or unarmed.
func start() -> void:
	if reloading or is_full() or crew.weapon == null:
		return
	reloading = true
	from_empty = is_dry()
	duration = time_from(rounds)
	var weapon := crew.weapon
	left = weapon.first_shell_time * factor() if weapon.shell_reload else duration
	if crew.target != null and is_instance_valid(crew.target):
		var fire := CrewFire.of(crew.target)
		if fire != null:
			fire.give_up(crew)
	_sound(0)
	crew.reload_started.emit(from_empty)


func tick(delta: float) -> void:
	if not reloading:
		return
	left -= delta
	if left > 0.00001:
		return
	if not shell_by_shell():
		rounds = size()
		_sound(1)
		_end(false)
		return
	# A shell seated; the next one's time starts from there.
	rounds = mini(rounds + 1, size())
	_sound(0)
	crew.shell_loaded.emit()
	if is_full():
		_end(false)
	else:
		left += crew.weapon.shell_time * factor()


## Whether it could break off its reload to fire now: shell by shell, with
## at least one shell in.
func can_break_off() -> bool:
	return reloading and shell_by_shell() and rounds > 0


## Breaks a shell-by-shell reload off, keeping the shells already in (the
## one in hand is lost). True when it did.
func break_off() -> bool:
	if not can_break_off():
		return false
	_end(true)
	return true


## Stops a reload with nothing more loaded: the Guard died.
func stop() -> void:
	reloading = false
	left = 0.0


func _end(broken: bool) -> void:
	reloading = false
	left = 0.0
	crew.reload_ended.emit(broken)


## The Profile's reload sound [param index] (the first if there is no
## such), at the Guard's position.
func _sound(index: int) -> void:
	var weapon := crew.weapon
	if weapon == null or weapon.reload_sounds.is_empty() or not crew.is_inside_tree():
		return
	var stream: AudioStream = weapon.reload_sounds[mini(index, weapon.reload_sounds.size() - 1)]
	SoundAt.play(crew._shot_parent(), crew.global_position + Vector3.UP * Crew3D.RELOAD_HEIGHT, stream, crew.shot_volume_db, 0.06, "Reload")
