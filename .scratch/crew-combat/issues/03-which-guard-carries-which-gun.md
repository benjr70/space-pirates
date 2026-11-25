Type: grilling
Status: resolved
Map: ../map.md

# Which Guard carries which gun

## Question

Each Guard's weapon is rolled from the ship's seed at generation. What is the roll?

- The mix: how many of each of the four weapons a ship holds, and whether that changes with Ship Class or Richness.
- Whether a Guard's Post Room weights its gun (a Corridor Guard more likely a Marksman Rifle, an Armory Guard a Shotgun), or the roll is flat.
- Any guarantees or caps: at least one of something, never more than one Marksman Rifle on a small ship.
- Whether the gun a Guard was rolled is part of the Ship Layout data or decided when the ship is built from it.
- Whether a Guard's gun changes anything outside the fight: how it looks on patrol, how loud it is to other crew.

## Answer

Grilled with the user on 2026-11-25. All numbers are starting numbers, tuned in the Sandbox sheet.

**The roll.** Each Guard rolls one of the four weapons by weight. Workers roll nothing: the Worker Gunnery and the Worker's Pistol go.

Base weights by Ship Class. Richness slides a ship from its Class's poor row to its rich row:

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| Small, poor | 60 | 25 | 15 | 0 |
| Small, rich | 40 | 35 | 25 | 0 |
| Medium, poor | 35 | 35 | 25 | 5 |
| Medium, rich | 20 | 45 | 25 | 10 |
| Large, poor | 20 | 45 | 25 | 10 |
| Large, rich | 10 | 50 | 25 | 15 |

The Guard's Post Room multiplies those weights, which are then renormalised:

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| Corridor | x1 | x1.5 | x0.5 | x2 |
| Armory | x0.5 | x1.5 | x2 | x0.5 |
| Bridge | x1.5 | x1.5 | x1 | x1 |
| Quarters | x2 | x1 | x1 | x0.5 |

**Caps.** Nothing is guaranteed present. Marksman Rifles: none on a small ship, at most 1 on a medium, at most 2 on a large, and never two posted in the same Room. A Room holding three or more Guards is never all Shotguns. A roll that breaks a cap is rolled again among the remaining weapons with the same weights.

**Where it lives.** The gun is decided when the ship is built from its Ship Layout, where crew type is decided today (`ShipBuilder3D`), not stored in the layout. Rolls run in a fixed order (Rooms by index, Guards by spawn order) from their own random stream seeded off the layout's seed, so a Retry gives the same guns and later features never reshuffle the guns on an existing seed.

**Outside the fight.** A Guard carries its gun visibly on patrol, so the Pirate can scout what each one holds. Nothing else changes out of a fight: Awareness, patrols and hearing are the same for every gun. Each gun's own loudness applies when it fires (the Shotgun's 32 m against 24 m draws crew from further).

**XP.** A kill is worth the same whatever the Guard held.

**Ruled out.** A dead Guard's gun cannot be picked up (see the map's Out of scope).

**Glossary.** `CONTEXT.md`: Guard now says it carries one of the Pirate's four weapons; Pistol points at Guard instead of saying crew carry it. No term was coined for the roll.
