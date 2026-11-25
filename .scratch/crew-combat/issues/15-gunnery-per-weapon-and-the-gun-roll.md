Status: resolved

# A Gunnery per weapon and the gun roll

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 1 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Which Guard carries which gun" and "Fair fire" (Gunnery's shape), and `issues/03`, `issues/06`.

- Gunnery becomes one Resource per weapon under `resources/gunnery/` (pistol, assault_rifle, shotgun, marksman_rifle) with the spec's fields and starting numbers: aim error; opening spread multiple and closing time; shots per burst (low, high); bursts per peek; gap between bursts; time down (low, high); settle; lead; range band; hold before shifting; reload factor. `guard.tres` and `worker.tres` go. Fields nothing reads yet are still filled in; later tickets use them.
- The gun roll in `ShipBuilder3D`: base weights by Ship Class slid by Richness, Post Room multipliers, the caps, a re-roll on a broken cap, in a fixed order from its own random stream seeded off the layout's seed. Each Guard gets its Weapon Profile and that weapon's Gunnery. Workers get neither.
- Guards fight as they do today, but with their own gun: its damage, projectile, time between shots, pellets (every pellet of a Shotgun shot is fired), sounds and loudness, and bursts of the Gunnery's shots-per-burst. Aim error comes from the weapon's Gunnery. Nothing else about behaviour changes in this ticket.
- Workers no longer fire: remove the cornered fight and the Worker's Pistol. A cornered Worker cowers, until the Workers ticket replaces that.
- The Sandbox sheet keeps working: its Gunnery section shows the four weapon Gunneries (the full layout is a later ticket).
- Update `CREW_AI.md` and `docs/sandbox.md`.

## Acceptance criteria

- [x] (agent) Over the generator suite's seed sweep, no small ship has a Marksman Rifle, no medium ship more than 1, no large ship more than 2, no Room two, and no Room of three or more Guards is all Shotguns.
- [x] (agent) Over at least 200 large ships at Richness 1.0, the share of Guards with each gun is within 5 percentage points of what the weights and Post Room multipliers predict for those ships' Guards.
- [x] (agent) Building the same layout twice gives every Guard the same gun; a layout built before and after an unrelated extra random draw elsewhere in the build still gives the same guns.
- [x] (agent) No Worker has a weapon or fires in 30 s cornered within 3 m of the Pirate.
- [x] (agent) A Shotgun Guard's shot spawns 12 projectiles; a Marksman Rifle Guard's projectile travels at 200 m/s within 1%.
- [x] (agent) Each of the four Gunnery files loads with the spec's aim error (7.5, 6, 8, 0 degrees) and range band.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) A ship's Guards visibly differ in how they shoot, by sound alone.

## Evidence

- Caps over the sweep: `tests/test_generator.gd::_check_guns`, run on every ship of the generator sweep (100 seeds per Class, seeds 1–100), which rolls `GunRoll.roll` on the emitted layout and asserts no Marksman Rifle on a small ship, at most 1 on a medium and 2 on a large, at most 1 in any Room, and no Room of three or more Guards all Shotguns (also a gun for every Guard, none for a Worker). Mutation proof: with both caps disabled in `gun_roll.gd` and the small ship given a Marksman weight of 5, the suite failed with 16 ship-cap, 11 two-in-a-Room and 13 all-Shotgun failures; restored, it passes.
- Shares on large ships: `tests/test_generator.gd::_check_gun_shares`, over the sweep's 100 large ships topped up with seeds 101–200 (200 ships), each set to Richness 1.0, asserting each gun's share of the Guards is within 5 points of the sum of `GunRoll.weights_for` (base weights times Post Room multipliers, renormalised) over those same Guards. Output: `guns: 2690 Guards on 200 large ships at Richness 1.0: Pistol 8.5% (predicted 8.7%), Assault Rifle 57.7% (predicted 54.1%), Shotgun 27.5% (predicted 29.8%), Marksman Rifle 6.4% (predicted 7.4%)`.
- Same guns twice: `tests/generated_ship_checks.gd::_check_guns` (in `ship_3d`), on the large ship the suite boards: every Guard of the Raid holds a weapon from the four and `Gunnery.for_weapon` of it; building the same layout again with `ShipBuilder3D.build` gives the same gun per crew member in spawn order; building it once more after 17 extra `randi()` draws on the global stream (which every other build draw, such as each crew member's spawn seed, comes from) gives the same guns again.
- Workers unarmed and cornered: `tests/test_crew.gd::_check_worker`: a Worker has `weapon == null` and `gunnery == null`; with the Pirate held 2.5 m in front of it for 30 s (1800 fixed frames, following it wherever it cowers) it had him in sight within 3 m (`_cornered()`) on at least 90% of frames, spawned 0 projectiles (counted by shooter on the projectiles node), never started a burst, ends in COWER and still holds no weapon. `ship_3d` asserts the built ship's Workers carry no weapon or Gunnery.
- Shotgun pellets and Marksman bolt: `tests/test_crew.gd::_check_gunnery`, which arms a Guard with each of the four guns as `ShipBuilder3D` does and fires once: the Shotgun Guard's shot spawns 12 projectiles (`last_pellets.size() == 12`); the Marksman Rifle Guard's bolt speed is asserted within 2.0 m/s (1%) of 200. Each gun's projectile count, damage and lifetime are asserted as its Profile's.
- Gunnery files: `tests/test_crew.gd::_check_gunnery` loads each of `resources/gunnery/{pistol,assault_rifle,shotgun,marksman_rifle}.tres` uncached and asserts aim error 7.5, 6, 8, 0 degrees and range band 4–8, 5–10, 2–5, 8–14 m (plus shots per burst, time down, opening spread 3, closing time 2 s, reload factor 1.5), and that `guard.tres` and `worker.tres` are gone.
- The gate: `tests/run_all.sh` (full, no arguments), exit 0, every suite PASS: static 172 checks, generator 357186, layouts 252, ship_3d 3714, pirate 2402, crew 245, sandbox 490, attachments 1674, raid_smoke 1104; total 184 s.

Screenshots (defect checklist, no defects found):
- `.godot/shots/crew/front.png`: the Guard (Soldier) left and the Worker (Engineer) right, standing, faced to camera, no gun shown yet (ticket 16), nothing floating or missing.
- `.godot/shots/crew/side.png`: the same two side-on, nothing clipped or floating.
- `.godot/shots/sheet/sheet.png`, `sheet_attachments.png`, `sheet_attachments_end.png`: the sheet opens and lays out as before; the Gunnery table sits between them and is not in a preset frame. Its four columns and every field are checked by `tests/test_sandbox.gd::_check_edit_save_revert` and `_check_doc_fresh` (`docs/sandbox.md`'s Gunnery table).

## Owed to playtest

- (human) A ship's Guards visibly differ in how they shoot, by sound alone.

## Comments

Built 2026-11-25.

Choices made where the ticket left them open:

- **Gunnery fields** (`scripts/crew/gunnery.gd`): `aim_error_degrees`, `opening_spread`, `closing_time`, `lead`, `shots_per_burst_low`/`_high`, `bursts_per_peek`, `gap_between_bursts_low`/`_high` (the spec's table gives the gap as a range, 0.4 to 0.8 s; 0 where the table is blank), `time_down_low`/`_high`, `settle`, `range_near`/`range_far`, `hold_before_shifting`, `reload_factor`. Ranges are two scalar fields so the Sandbox sheet edits them with no change to `SheetTable`. The Marksman Rifle's "never moves up" is `hold_before_shifting = -1` (negative means never). Files are named as the weapon's file; `Gunnery.for_weapon(profile)` finds one, falling back to the Pistol's for a weapon with no file of its own (a test's duplicate). `Gunnery.PATHS` and `NAMES` are in wheel order.
- **What reads the Gunnery today**: aim error (the cone, unchanged curve), shots per burst (a fresh `randi_range(low, high)` each burst; it replaces the old per-Guard ±1 burst offset) and time down (a fresh draw after each spent burst, in place of the old pause between bursts times a spawn jitter, which is gone). Today's engage range is gone from the Gunnery as the spec says; to keep behaviour otherwise unchanged it is now the constant `Crew3D.ENGAGE_RANGE = 10.6` for every gun, until ticket 18 (cover) replaces FIGHT and ticket 20 drops it. Nothing reads opening spread, closing time, lead, bursts per peek, gap, settle, range band, hold or reload factor yet.
- **Firing**: every pellet of a shot is its own projectile, each with its own yaw draw inside the cone (crew spread stays yaw-only, as before); one shot sound, one action sound (the Shotgun's pump, `action_sound_delay` after, through a timer connection so a freed body plays nothing) and one gunshot noise at the gun's loudness per shot. `Crew3D.last_pellets` holds the last shot's projectiles. The Shotgun pellet cap (9) is ticket 19's, not built.
- **The roll** lives in `scripts/ship/gun_roll.gd` (`GunRoll`), called from `ShipBuilder3D.build`, which sets each crew member's `weapon` (`GunRoll.weapon(i)`, the cached bare Profile) and `gunnery`. Stream seed: `hash([layout.gen_seed, "gun roll"])`. A broken cap zeroes that weapon and draws again from the same stream. The hand-authored ship (no Ship Class) rolls with the small ship's weights. `GunRoll` names the weapons by path rather than through `Loadout.WEAPONS`, because a `--script` suite that touches `Loadout` keeps its preloaded weapons alive at exit (an engine error in the gate).
- **Workers**: `Crew3D._ready` nulls a Worker's `weapon` and `gunnery`. Spotted while cornered it enters COWER instead of FIGHT; cornered while fleeing, or shot while fleeing and cornered, likewise; cornered in COWER it stays. `CORNER_RELEASE` is gone. A Worker that somehow reached FIGHT goes straight to COWER.
- A crew member's `weapon` export still defaults to the Pistol, so a Guard placed by hand (tests, the shots presets) carries the Pistol and its Gunnery.

Checks changed because the ticket replaces what they asserted:

- `tests/test_crew.gd::_check_worker`: the cornered Worker used to be required to fire its Pistol; it is now required to carry nothing, fire nothing in 30 s and cower.
- `tests/test_crew.gd::_check_gunnery`: asserted the Guard and Worker files (6 and 11 degrees, burst 3 and 2, pause 1.1 s, engage range 10.6 m) and both types holding the Pistol; it now asserts the four weapon files, a Guard firing each gun, burst lengths over each Gunnery's range and time down after a burst. A Pistol Guard's cone is now 1 + 7.5 = 8.5 degrees (was 1 + 6).
- `tests/test_sandbox.gd`: the Gunnery table's columns (Guard, Worker → the four weapons), its rows in `docs/sandbox.md`, the hand-edit stale check (now on the Assault Rifle's Gunnery), the edit/Save round trip (now shots per burst and range far), and the in-Raid check, which now finds a Pistol Guard (arming one if the rolled ship has none) and dials the Pistol Gunnery (disk value 7.5, was 6.0).
- `tests/test_ship_3d.gd`: the dead-eye gunman copies the Pistol Gunnery in place of the Guard file.

Docs: `scripts/crew/CREW_AI.md` (files, crew types, Worker states, Guns rewritten with the Gunnery table and the roll, rhythm, tuning), `docs/sandbox.md` regenerated, `docs/agents/validation.md` (coverage rows for `scripts/crew/`, `scripts/ship/` and `scripts/sandbox/`, generator timing: 357186 checks, 49 s, up from 41 s because the share check generates 100 more large ships).
