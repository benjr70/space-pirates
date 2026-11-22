Type: research
Status: resolved
Blocked by: none
Map: ../map.md

# How reference shooters tune shotguns and precision rifles

## Question

How do projectile-based arena shooters, Halo Infinite first since it is this game's stated reference, tune their shotguns and precision weapons? For the Bulldog, the Battle Rifle, the Commando, the Stalker Rifle and the sniper rifle, and comparable guns in one or two other shooters: pellet count and pattern (fixed or random), damage against health in shots-to-kill, fire rate, magazine, reload style, effective range and falloff, zoom levels, headshot rules and descope. What distinguishes a shotgun's and a precision rifle's role from the automatic rifle's in those sandboxes?

## Answer

Full findings and comparison table: `docs/research/reference-shooter-numbers.md` on branch `research/reference-shooter-numbers` (pushed, never merged). Read it with `git show origin/research/reference-shooter-numbers:docs/research/reference-shooter-numbers.md`. Many Halo Infinite numbers could not be confirmed; the note marks each and fills none from memory.

Confirmed in official 343 posts:

- Bulldog: deliberately "not a power weapon", "fast-firing and fast-loading".
- Commando: damage cut from 20 to 17.5, taking it from 8 to 9 bullets to kill.
- BR75: nerfed through aim assist, not damage.
- S7 sniper: no-scope error cut.

Confirmed in community wikis or tag data (Halopedia, Apex wiki):

- Bulldog: 7-round drum, 2-shot kill, 1.4x zoom, no headshot bonus.
- BR75: 36 rounds, 4 bursts with the last to the head, 2.5x zoom.
- Commando: 20 rounds.
- Stalker Rifle: 3 headshots or 5 body shots, overheats after 7 shots, 3x and 6x zoom.
- S7 sniper: 4 rounds, 1 head or 2 body, 5x and 10x zoom, about 1.23 shots per second.
- Assault Rifle: 36 rounds, 12 rounds per second, no multiplayer headshot bonus.
- Reach DMR: 5-shot kill, 15 rounds, 3x zoom.
- Apex: Peacekeeper fires 9 pellets in a fixed star; Mastiff fires 5 in a line and reloads shell by shell.

Unconfirmed:

- Bulldog pellet count, pattern type, fire rate, reload time and falloff.
- BR75, Commando and Stalker fire rates; every Infinite reload time.
- Infinite shield and health values.
- Descope and flinch rules in any Halo.
- Damage falloff for every Halo gun.
- Destiny 2 entirely: its sources refused automated reading.

Roles: precision rifles kill in a fixed number of shots with a finishing headshot; the automatic rifle has volume and spread and no headshot bonus; shotguns have the shortest range.
