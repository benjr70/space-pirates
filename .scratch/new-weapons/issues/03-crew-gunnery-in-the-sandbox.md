Type: grilling
Status: resolved
Blocked by: none
Map: ../map.md

# How crew gunnery sits in the Sandbox sheet

## Question

Crew guns are not Weapon Profiles today: burst size, burst gap, reload time, spread and engage range are exports on `scripts/crew/crew.gd`, and the projectile's speed and damage come from the scene. The sheet must show crew numbers beside the Pirate's, and a future map will have crew use the same weapons. How do crew numbers enter the sheet now: as rows of their own shape, or by splitting them into a weapon part (a Weapon Profile) and a wielder part (how well a Guard or Worker handles it)? Which crew numbers count as Sandbox attributes and which are behaviour?

## Answer

Crew numbers split into a weapon part and a wielder part, and crew hold the Pirate's own Pistol.

**Weapon part.** Crew fire the **Pistol** Weapon Profile, the same resource the Pirate holds. There is no crew-only gun. From the Profile crew read damage, projectile speed, projectile lifetime, time between shots and the shot sound. Crew ignore the magazine, both reloads, bloom, Aim Down Sights, recoil and the Viewmodel fields: they still fire a burst and pause, and never count rounds.

**Wielder part: Gunnery.** A new glossary term for how a wielder handles a weapon, apart from what the weapon is. One Gunnery row per crew type (Guard and Worker now, Officer later):

- aim error in degrees, added on top of the Profile's own cone (Pistol base 1 degree plus Guard aim error 6 gives today's 7)
- burst length
- pause between bursts (today's `reload_time`)
- engage range (stays here for now; whether it moves to the Profile is for the future crew-weapons map)

The Worker's spread and burst constants in `scripts/crew/crew.gd` move into data so the sheet can dial them. Per-crew spawn jitter stays in code as behaviour; the sheet shows base values. The Pirate has no Gunnery: his handling is the Profile's spread, bloom and recoil.

**Accepted consequence.** The Pistol's bolt flies at 80 m/s against the crew's 23.75 m/s today (lifetime 0.5 s against 1.6 s, 0.12 s between shots against 0.14 s, damage 1 either way). Crew bolts get 3.4 times faster, so sidestepping a burst mostly stops working. That is accepted: one gun behaves one way, and crew are retuned through Gunnery in the first balance pass by playtest.

**Health is in the Sandbox.** The sheet shows and edits Pirate Health (6 today) and crew Health (4 today) beside the weapons, since shots to kill mean nothing without them.

**Not in the Sandbox.** Perception, cover search, movement speed and Awareness are behaviour and stay out of the sheet.

**What the sheet therefore holds:** Weapon Profile rows (Pistol, Assault Rifle, and the new guns), Gunnery rows per crew type, and Health for the Pirate and crew. Cells crew ignore need no marking now that no row is crew-only.

**Scope change.** Crew drawing from the same Weapon Profiles is now inside this map for the Pistol only. Crew holding any other weapon stays out of scope.
