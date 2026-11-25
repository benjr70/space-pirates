Type: grilling
Status: resolved
Blocked by: none
Map: ../map.md

# How an Attachment changes a weapon

## Question

What is an Attachment as data, and how do the Attachments in a weapon's Slots turn its Weapon Profile into the weapon the Pirate holds?

- Which Weapon Profile attributes may an Attachment touch, and does each change multiply, add or replace? What happens when two Attachments touch the same attribute?
- "A longer barrel increases range", but there is no damage falloff: a shot's reach is `projectile_speed` times `projectile_lifetime`. Is range those two numbers, tighter spread, or does this effort add falloff to the damage model?
- Which attributes do not exist yet and must be added for Attachments to mean something (time to raise the sights, swap time, movement speed with the weapon out)?
- Where does the built weapon live: is it worked out once from Profile plus Attachments when the Loadout is read, and does anything else (crew, the Sandbox sheet, tests) still read the bare Profile?
- How does it sit with the rule "a new weapon is a new Profile, never new code", and with the Sandbox sheet saving live dials back to `.tres` files?
- Does this need an ADR?

## Answer

Grilled with the user on 2026-11-24. `CONTEXT.md` gained **Built Weapon** and the Attachment and Slot entries were sharpened. No ADR: the glossary and the spec carry it, and changing course later is a migration of a few data files.

**Shape**

- An Attachment is data only: its Slot kind, its name, its model and a list of changes. A new Attachment is a new data file, never new code.
- The **Built Weapon** is a new Weapon Profile worked out from the bare Profile plus the Attachments in its Slots. The Pirate reads it like any Profile; no shooting code knows Attachments exist.
- The Built Weapon is never saved. It is rebuilt whenever the bare Profile or an Attachment changes, live in a Raid.

**Changes**

- A change is one Profile attribute times a factor (bolt speed x1.2, magazine x1.5, loudness x0.4). Two Attachments on the same attribute multiply together; order never matters.
- Three things replace outright in place of multiplying: a Sight sets the zoom, a suppressor swaps the shot sound, and any Attachment may swap a part of the model.
- An Attachment has one set of factors wherever it fits. No per-gun overrides: a gun that needs a different effect gets a different Attachment.
- Limits: magazine size rounds to whole rounds and is never under 1; times and spreads are never under zero. No other clamps: a bad factor is a tuning mistake seen in the sheet, not an error.

**What may change**

- Never: damage, Headshot multiplier, pellet count, semi or automatic fire, shell-by-shell reload. Shots-to-kill stay as balanced.
- Fair game: fire interval, magazine size, reload times, bolt speed, all spread and bloom, aimed spread, sway, zoom, aimed walk speed, recoil and kick, loudness, aim time, swap time.

**Range**

- No damage falloff is added. Every gun already reaches past any Room at full damage, so "more range" means a faster bolt (less lead on moving crew) and tighter spread.

**New Profile attributes**

- **Aim time**: seconds to raise the sights. Today it is the same for every gun.
- **Swap time**: moves from the Pirate (`swap_time`, 0.4 s in `scripts/player_3d.gd`) onto each Profile.
- No movement speed by weapon: walking speed stays the Pirate's.

**Who reads what**

- Each weapon's Profile lists its Slots and, per Slot, which Attachments fit. An Attachment knows nothing about guns.
- Crew, the existing suites and the Sandbox sheet's weapon rows keep reading bare Profiles. The sheet dials bare Profiles and Attachments separately, each saved to its own file.
- The Loadout screen's comparison is computed from the Built Weapon against the bare Profile. An Attachment carries no hand-written pros and cons.

**Amended 2026-11-24 by "Which Slots each weapon has and what the Attachments are"**: a Sight multiplies the zoom, it does not set it; and a third new Profile attribute joins aim time and swap time: how conspicuous the gun is to crew. See that ticket.

**Amended 2026-11-24 by "What each Attachment's starting numbers are"**: one more limit: zoom is never under 1.0.
