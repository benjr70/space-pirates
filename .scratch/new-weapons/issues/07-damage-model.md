Type: grilling
Status: resolved
Blocked by: 05, 06
Map: ../map.md

# What the damage model needs

## Question

Damage is a flat int per hit against a crew Health of 4 and a Pirate Health of 6, with no headshots and no falloff. Given the roles decided for the Shotgun and the precision rifle, what must change for four weapons to have distinct roles: headshots or weak points, damage falloff over distance, finer-grained health and damage, different health for the Pirate and crew? Each change becomes Weapon Profile fields, never per-gun code.

## Answer

Three changes, each a field or a scale, none of them per-gun code. No damage falloff.

- **Finer Health.** Everything scales by 25 and stays an int: crew Health 100, Pirate Health 150, Pistol and Assault Rifle damage 25, Melee 75. Nothing plays differently on day one. The reason is the sheet: at Health 4 the only choices were a kill in 1, 2 or 4 hits.
- **Headshots.** Crew get a head zone that follows the model's head, separate from the body. Every Weapon Profile gets a headshot multiplier, where 1 means no bonus:
  - Marksman Rifle 2 (50 body, 100 head)
  - Pistol 1.5 (4 body hits, or 3 with headshots)
  - Assault Rifle 1
  - Shotgun 1
- **The Pirate's head.** Crew shots never headshot the Pirate; he has one zone.
- **No damage falloff.** Damage does not drop with distance. Range comes from spread and from how far a bolt flies (speed times lifetime). The Shotgun is short-ranged because its pellets scatter and die early. [How the Shotgun's pellets fly](08-shotgun-pellet-pattern.md) may reopen this if the Shotgun feels wrong without it.
- **Pellets.** The Profile gets a pellet count, 1 for every gun today. Damage is per pellet, and the sheet shows a derived damage per shot. The Shotgun's count and per-pellet damage come from the pellet prototype.
- **Headshot feedback.** A headshot has its own hit marker look and sound, distinct from a body hit and from a kill. The sound is picked in the sound booth.
- **Melee in the sheet.** Melee damage joins the sheet under the Pirate, with the kill-from-behind rule shown as a read-only note.

Follows from the scale: the Pirate's six HUD pips are now worth 25 each; how the HUD shows 150 Health is left to the HUD fog on the map.
