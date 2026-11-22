Status: resolved
Blocked by: 22

# Shell-by-shell reload

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 7 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's Shotgun reload rules and `issues/13-shotgun-shell-reload.md`. The prototype on branch `prototype/shell-reload` is the reference for feel; the user picked its starting values unchanged.

The Weapon Profile gains a shell-by-shell reload switch and four times: first shell 0.55 s, each shell after 0.45 s, closing pump 0.45 s, break-out 0.25 s. With the switch on:

- One tap of reload loads shells until the gun is full or the reload is broken.
- A shell counts, the ammo counter rises by one and the shell sound plays when that shell's time is up.
- A shot, a Melee or a weapon swap breaks the reload and keeps the shells already in; the shell in hand is lost.
- A shot can break in only with a shell in the gun. The gun then fires by itself after the break-out time: the press that broke the reload is the press that fires.
- The closing pump runs only when loading began from empty, and a shot cannot break it.
- A dry pull starts the reload. A Sprint does not break it.

The Shotgun uses it. The magazine guns are unchanged, including losing everything on an interrupted reload. The four times and seconds from empty to full join the sheet.

## Acceptance criteria

- [x] Empty to full takes 3.25 s and ends at 6 shells.
- [x] A shot pressed after two shells are in leaves two shells loaded, less the one fired, and fires 0.25 s after the press.
- [x] A Melee and a swap mid-reload both keep the shells already in.
- [x] From 3 shells, a reload to full ends without a closing pump.
- [x] An interrupted Pistol reload still gains nothing.
- [x] `tests/run_all.sh` passes.

## Comments

Built 2026-11-22. `WeaponProfile` gains `shell_reload`, `first_shell_time`, `shell_time`, `closing_pump_time`, `break_out_time` (Magazine group) and `seconds_empty_to_full()`; the Shotgun sets them to on, 0.55, 0.45, 0.45, 0.25. The Pirate runs it inside `start_reload`/`cancel_reload`/`is_reloading`. New signals for ticket 24: `shell_reload_started(from_empty)`, `shell_loaded` (after `ammo_changed`), `closing_pump_started`, `shell_reload_ended(broken)`; `reloading_changed` fires as before. The shell reload sends neither `reload_started` nor `reload_cancelled`, so for now it is silent and the Viewmodel plays no clip: the magazine sounds and clip, timed to a 2.4 s magazine reload, would be wrong against a reload of 0.55 s to 3.25 s. A shot breaking in is queued and fires through `fire()` once the break-out is up (and the fire interval has run out); a Melee or swap drops a queued shot, and a reload cannot start while one waits. The sheet shows the five fields and a derived "Seconds from empty to full"; "Seconds to kill crew" now uses it for reloads. Checks: `_check_shell_reload` in `tests/test_pirate.gd`, sheet rows in `tests/test_sandbox.gd`.
