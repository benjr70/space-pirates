Status: resolved
Blocked by: 15

# Attachments as data and the Built Weapon

## Parent

Part of `.scratch/weapon-attachments/spec.md` (Spec: weapon Attachments and the Loadout). Build order 2 of 10. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "How an Attachment changes a weapon", "New Weapon Profile attributes" (conspicuous) and "Slots and the catalogue", and `issues/03`, `issues/04`, `issues/13`.

- An Attachment Resource: Slot kind, name, a list of changes (attribute and factor), whether it makes the gun aim through a lens, an optional replacement shot sound. Model fields come in a later ticket.
- Fourteen Attachment files under `resources/attachments/` with the spec's factors.
- On Weapon Profile: its Slots and, per Slot, the Attachments that fit, filled in for the four guns from the spec's fit table; and the conspicuous attribute, 1.0 for every gun.
- A function that builds a Built Weapon from a bare Profile and a choice per Slot: a fresh Weapon Profile with every factor multiplied in, the limits applied (whole rounds never under 1; times and spreads never under 0; zoom never under 1.0), the lens mark and the replaced sound carried. It refuses an Attachment the gun does not take and any change to damage, Headshot multiplier, pellet count, semi or automatic fire, or shell-by-shell reload.
- Crew build Awareness of the Pirate faster by the conspicuous factor of the weapon he holds.
- The three suppressed shot sounds from `prototype/suppressed-sounds` (`assets/audio/audition_picks/`, with `LICENSE.txt`), imported under `assets/audio/` beside the other shot sounds and set on the Suppressor per gun. Decide how one Attachment carries a sound per gun and say so under Comments.
- A new suite, `tests/test_attachments.gd`, in `tests/run_all.sh` and in the suite and coverage tables of `docs/agents/validation.md`.

Nothing in play uses Attachments yet: this ticket is data and the builder.

## Acceptance criteria

- [x] (agent) For every gun and every Attachment it takes (34 pairs), the Built Weapon's changed attributes equal bare times factor: counts exactly, the rest within 1%.
- [x] (agent) The Built Weapon numbers tabled in `issues/13-starting-numbers.md` hold: Assault Rifle with Drum has 75 rounds and a 2.88 s tactical reload; Pistol with Quick Magazine has 10 rounds; Marksman Rifle with Quick Magazine has 6; a suppressed gun's loudness is 9.6; Shotgun with Reflex Sight has zoom 1.0; Marksman Rifle with Long Scope has zoom 5.01 within 1% and is marked as a lens.
- [x] (agent) Two Attachments on one attribute multiply: Assault Rifle with Combat Scope, Long Barrel, Drum, Foregrip and Heavy Stock has an aim time of 0.59 s within 0.01.
- [x] (agent) Building never changes the bare Profile or an Attachment file.
- [x] (agent) An Attachment the gun does not take is refused, as is one that changes damage.
- [x] (agent) With a Laser on the gun the Pirate holds, time to spotted at 10 m is the bare time divided by 1.3, within 10%.
- [x] (agent) A suppressed Pistol shot at 12 m raises no suspicion in a crew member; the bare shot does.
- [x] (agent) `tests/run_all.sh` passes, with the new suite in it.

## Evidence

- 34 pairs, bare times factor: `tests/test_attachments.gd::_check_every_pair`, which builds each of the four guns with each Attachment it takes (asserting exactly 34 built), compares every exported number on the Built Weapon with the bare Profile times the catalogue factor typed into the suite from the spec's table (counts exactly after rounding, never under 1; the rest within 1%, zoom floored at 1.0), and asserts every other number is unchanged. `_check_catalogue` asserts each of the fourteen files carries exactly those factors (within 0.0001).
- Starting numbers: `tests/test_attachments.gd::_check_starting_numbers` asserts Assault Rifle with Drum has exactly 75 rounds and a tactical reload of 2.88 s within 1%; Pistol with Quick Magazine exactly 10 rounds; Marksman Rifle with Quick Magazine exactly 6; the suppressed Pistol, Assault Rifle and Marksman Rifle each heard at 9.6 m within 1%; Shotgun with Reflex Sight zoom exactly 1.0 and not a lens; Marksman Rifle with Long Scope zoom 5.01 within 1% (measured 5.01) and marked as a lens (the bare one not).
- Stacking: `tests/test_attachments.gd::_check_stacking` asserts the Assault Rifle with Combat Scope, Long Barrel, Drum, Foregrip and Heavy Stock aims in 0.59 s within 0.01 (measured 0.592), and the Marksman Rifle with Bipod and Heavy Stock sways 0.075 within 1%.
- Untouched: `tests/test_attachments.gd::_check_untouched` snapshots every script field of the four bare Profiles and every Attachment's changes, builds all 34 pairs and a full Assault Rifle, and asserts the snapshots are equal afterwards, the bare Profiles equal a fresh load from disk, and the Built Weapon is not the bare Profile object.
- Refusals: `tests/test_attachments.gd::_check_refusals` asserts `build` returns null for the Pistol with a Combat Scope, the Shotgun with a Suppressor and a Reflex Sight in the Barrel Slot, and for an Attachment fitted to a scratch Pistol that changes each of damage, Headshot multiplier, pellet count, semi or automatic fire and shell-by-shell reload, with `why_refused` naming the attribute; an empty choice and an empty Slot build.
- Laser: `tests/test_crew.gd::_check_conspicuous` measures time to spotted at 10 m bare and with a Laser on the held Pistol and asserts the Laser time is the bare time / 1.3 within 10% (measured 1.167 s against 1.517 / 1.3 = 1.167 s).
- Suppressed at 12 m: `tests/test_crew.gd::_check_suppressed` fires the Pirate's suppressed Pistol with a crew member 12 m off and asserts its Awareness stays 0, then the bare Pistol and asserts the crew member is suspicious.
- The gate: `tests/run_all.sh` passed with the new `attachments` suite in it: every suite PASS, `attachments` 1674 checks, total 201 s (2026-11-24).

## Comments

Built 2026-11-24.

- `scripts/attachment.gd`: `Attachment` Resource with `enum Slot { SIGHT, BARREL, MAGAZINE, UNDERBARREL, STOCK }`, `slot`, `display_name`, `changes: Dictionary[StringName, float]` (Weapon Profile field to factor), `lens` and `suppresses`. Model fields are left for ticket 19.
- Fourteen files under `resources/attachments/` with the spec's factors.
- `scripts/weapon_profile.gd`: `fits: Array[Attachment]` (Attachments group) lists every Attachment the gun takes; its Slots are derived, `slots()` and `fits_in(slot)`, so a Slot exists exactly when something fits it. `conspicuous := 1.0` (Crew group). `build(choice: Dictionary) -> Resource` (a WeaponProfile; typed Resource because naming its own class in the signature made `weapon_profile.gd` hold itself, and the copy `SandboxSheet.from_disk` loads apart from the cache then leaked at exit, failing `ship_3d` with "2 resources still in use") takes Slot to Attachment (null for empty) and returns a fresh Profile, or null when `why_refused(choice) -> String` is not blank (wrong Slot, does not fit, a forbidden attribute in `FIXED`, a change to a field that is not a number, a Suppressor on a gun with no suppressed takes). Limits: int fields (magazine) round, never under 1; `NEVER_NEGATIVE` times and spreads never under 0; `ads_zoom` never under 1.0. The Built Weapon carries `aims_through_lens` (the lens mark) and `attachments` (in Slot order), both plain vars, never saved.
- Crew: `CrewPerception.sense` takes the held weapon's `conspicuous` and divides the spot time by it; `Crew3D._update_perception` reads it from the target's `weapon`.
- **How one Attachment carries a sound per gun:** it does not. The Suppressor only says `suppresses = true`; each gun keeps its own suppressed takes in a new Weapon Profile field, `suppressed_shot_sounds`, and the Built Weapon's `shot_sounds` becomes that list. This keeps "an Attachment knows nothing about guns" and lets the sheet show the takes as a row per gun. The three takes are in `assets/audio/suppressed_shots/` with `LICENSE.txt`.
- `docs/sandbox.md` regenerated: new rows Suppressed Shot Sounds, Conspicuous and Fits. `tests/test_attachments.gd` (`only=attachments`) is in `tests/run_all.sh` and in the suite list, timings and coverage tables of `docs/agents/validation.md`.
- No acceptance number disagreed with the spec's tables.

