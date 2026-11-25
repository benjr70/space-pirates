Type: research
Status: resolved
Map: ../map.md

# Fair fire and cover in reference shooters

## Question

How do well-regarded single-player shooters make enemy gunfire feel fair, and how do their enemies choose and use cover?

Two halves, each answered from primary sources (developer talks, postmortems, published AI papers, engine documentation), not from forum opinion:

1. Fair fire. What techniques stop AI from being either harmless or a laser: deliberate first-shot misses, aim that lags a moving target, accuracy that depends on the target's speed and exposure, limits on how many enemies may fire at once, tells before a shot, suppression fire aimed to miss. For each, which games use it and what numbers they publish.
2. Cover. How enemies find cover points (authored markers, generated from geometry, sampled at runtime), how they score one against another (distance, protection from the player, line of fire, distance to allies), how they peek and for how long, when they change cover, and how they advance or fall back. Include how weapon type changes the choice (a shotgunner against a sniper).

Reference games to start from: F.E.A.R., Halo (Combat Evolved through Infinite), The Last of Us, Killzone, Uncharted, The Division. Add others the sources point to.

Report what would transfer to a small Godot 4 game whose ships are tile-grid Rooms with box props, with 2 to 8 crew in a fight.

## Answer

Researched 2026-11-25. Full findings, with a URL for every claim: `docs/research/fair-fire-and-cover.md` on branch `research/fair-fire-and-cover` (commit `fa25409`, pushed, never merged). Its transfer section lists eight fair-fire candidates (F1 to F8) and nine cover candidates (C1 to C9), each with the source's numbers in one column and suggested starting numbers in another.

Fair fire:

- The best documented trick is an exposure ramp. Uncharted 2 drops enemy accuracy to 0% when the player leaves cover and restores it over 3.5 s. Half-Life 2 opens the spread cone at 3x and closes it to 1x over 0.6 s. Halo CE gets more accurate the longer the player stays out of cover.
- This game's ramp (1.5x closing to 0.5x over 3 s) is the outlier: no source tightens below the weapon's base spread. The 0.5x floor is the likely cause of the laser feel.
- First shots miss by design: Halo CE starts a burst beside the target and sweeps it in; BioShock's first enemy shots always missed.
- Uncharted 2 publishes chance to hit by distance: 0.9 at 0 to 4 m, 0.5 at 8 m, 0.4 at 12 to 20 m, 0.3 at 30 m; times 0.9 for a running target and 0.5 for a rolling one.
- Tokens should gate hitting, not shooting (Game AI Pro 3): everyone fires, only the token holder's shots are aimed true, one timer hands the token on. Base delay 0.5 s, doubled when the player is crouched or in cover, halved inside 5 m. Hard firing slots have a known failure: Half-Life 2 shotgunners stood idle in front of the player because the slots were taken.
- The Last of Us sets a floor, not a ceiling: at least one enemy is always shooting while the others take cover or flank.
- Deliberate misses land where the player sees them: the edge of his cover, or past his face.
- With no hitscan here, "chance to hit" becomes "where the projectile is aimed". That reframing is the researcher's, not a source's.

Cover:

- Cover points come from authored markers (Halo, F.E.A.R.), offline generation from geometry (The Last of Us, Killzone) or runtime sampling (Brink). A generated tile-grid ship points at generating them from prop footprints and wall corners.
- Choosing is filter, then score. Killzone's weights: proximity 20, line of fire from partial cover 40, cover from other threats 20, preferred range 10.
- The Last of Us rejects cover whose path runs toward the player. It was added because playtesters complained enemies rushed forward, the symptom this effort starts from.
- Stickiness: re-evaluate once a second, move only for a 10 to 20% better score.
- Peek rhythm: Half-Life 2 at medium aggression fires 3 to 6 shots then stays down 0.6 to 2.5 s; its shotgunner rests 1.2 to 1.5 s between shots.
- Movement is covered by fire: in F.E.A.R. one suppresses while others move. In Days Gone a passive player makes the squad more aggressive.
- Weapon type sets a preferred range band scored per weapon (Halo, Killzone, Uncharted 2). Snipers back off when approached (Division 2) or hold perches (Days Gone).

Not verified from a primary source: anything on Halo 3 onward, The Division's cover selection, DOOM 2016's tokens. No source gives a telegraph duration before a shot, so any tell timing is a guess to be played.
