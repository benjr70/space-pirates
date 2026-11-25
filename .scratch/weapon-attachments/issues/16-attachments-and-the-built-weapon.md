Status: ready-for-agent
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

- [ ] (agent) For every gun and every Attachment it takes (34 pairs), the Built Weapon's changed attributes equal bare times factor: counts exactly, the rest within 1%.
- [ ] (agent) The Built Weapon numbers tabled in `issues/13-starting-numbers.md` hold: Assault Rifle with Drum has 75 rounds and a 2.88 s tactical reload; Pistol with Quick Magazine has 10 rounds; Marksman Rifle with Quick Magazine has 6; a suppressed gun's loudness is 9.6; Shotgun with Reflex Sight has zoom 1.0; Marksman Rifle with Long Scope has zoom 5.01 within 1% and is marked as a lens.
- [ ] (agent) Two Attachments on one attribute multiply: Assault Rifle with Combat Scope, Long Barrel, Drum, Foregrip and Heavy Stock has an aim time of 0.59 s within 0.01.
- [ ] (agent) Building never changes the bare Profile or an Attachment file.
- [ ] (agent) An Attachment the gun does not take is refused, as is one that changes damage.
- [ ] (agent) With a Laser on the gun the Pirate holds, time to spotted at 10 m is the bare time divided by 1.3, within 10%.
- [ ] (agent) A suppressed Pistol shot at 12 m raises no suspicion in a crew member; the bare shot does.
- [ ] (agent) `tests/run_all.sh` passes, with the new suite in it.

## Comments
