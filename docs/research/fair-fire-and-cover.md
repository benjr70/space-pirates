# Fair fire and cover in reference shooters

Research date: 2026-11-25. Ticket: `.scratch/crew-combat/issues/01-fair-fire-and-cover-in-reference-shooters.md`.

Question: how do well-regarded single-player shooters make enemy gunfire feel fair, and how do their enemies choose and use cover? What of that transfers to a tile-grid ship with box props, projectiles only, and 2 to 8 crew in a fight?

## How to read this note

Every claim carries a source tier and a link.

- **[P] Primary**: written or presented by the developers themselves (a Game AI Pro chapter, a GDC talk's slides or speaker notes, a developer-written article, shipped source code, a first-party interview).
- **[D] Engine or tag documentation**: Epic's documentation, or the Reclaimers Library (c20), which is a community-written reference for Bungie's official Halo CE tag format. c20 documents what a field does, not what Bungie set it to.
- **[S] Secondary**: a write-up by someone else of a developer talk. Used only where no primary text could be opened, and flagged each time.
- **Mine**: my suggestion for this game. No source states it.

Sections 1 and 2 are findings. Section 3 is what would transfer, and every number there is marked source or mine. Section 4 lists what I could not verify.

Sources, with the short names used below:

| Short name | What it is | Tier |
|---|---|---|
| Ocio | Sergio Ocio Barriales, "Using Your Combat AI Accuracy to Balance Difficulty", Game AI Pro 3 ch. 33. <http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter33_Using_Your_Combat_AI_Accuracy_to_Balance_Difficulty.pdf> | P |
| TLOU | Travis McIntosh, "Human Enemy AI in The Last of Us", Game AI Pro 2 ch. 34. <http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter34_Human_Enemy_AI_in_The_Last_of_Us.pdf> | P |
| UC2 | Benson Russell (senior designer, Naughty Dog), "The Secrets Of Enemy AI In Uncharted 2", 2010. <https://www.gamedeveloper.com/design/the-secrets-of-enemy-ai-in-i-uncharted-2-i-> | P |
| Halo 2002 | Chris Butcher and Jaime Griesemer, "The Illusion of Intelligence", GDC 2002, slides with speaker notes. <https://halo.bungie.org/misc/gdc.2002.haloai/talk.html?page=1> (pages cited individually) | P |
| Halo 2 | Damian Isla, "Handling Complexity in the Halo 2 AI", GDC 2005. <https://www.gamedeveloper.com/programming/gdc-2005-proceeding-handling-complexity-in-the-i-halo-2-i-ai> | P |
| Halo CE tags | Reclaimers Library, `actor_variant` tag. <https://c20.reclaimers.net/h1/tags/actor_variant/> | D |
| FEAR | Jeff Orkin, "Three States and a Plan: The A.I. of F.E.A.R.", GDC 2006. <https://www.gamedevs.org/uploads/three-states-plan-ai-of-fear.pdf> (a mirror; the author's MIT page did not serve the PDF) | P |
| Killzone | Arjen Beij and Remco Straatman, "Killzone's AI: Dynamic Procedural Tactics", GDC Europe 2005 slides. <https://www.guerrilla-games.com/media/News/Files/gdce05_killzone_ai.pdf> | P |
| Killzone 3 | Straatman, Verweij, Champandard, Morcus, Kleve, "Hierarchical AI for Multiplayer Bots in Killzone 3", Game AI Pro ch. 29. <http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter29_Hierarchical_AI_for_Multiplayer_Bots_in_Killzone_3.pdf> | P |
| Crytek TPS | Matthew Jack, "Tactical Position Selection", Game AI Pro ch. 26 (Crysis 2, with notes on Far Cry, Crysis, Killzone 3, Brink). <http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter26_Tactical_Position_Selection.pdf> | P |
| Johnson | Eric Johnson, "Taming Spatial Queries", Game AI Pro Online Edition 2021 ch. 5. <http://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter05_Taming_Spatial_Queries_Tips_for_Natural_Position_Selection.pdf> | P |
| Days Gone | Tobias Karlsson, "Squad Coordination in Days Gone", Game AI Pro Online Edition 2021 ch. 12. <http://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter12_Squad_Coordination_in_Days_Gone.pdf> | P |
| Reckoning | Michael Dawe, "Beyond the Kung-Fu Circle", Game AI Pro ch. 28 (Kingdoms of Amalur: Reckoning). <http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter28_Beyond_the_Kung-Fu_Circle_A_Flexible_System_for_Managing_NPC_Attacks.pdf> | P |
| HL2 source | Valve, Source SDK 2013 (Half-Life 2 and Episodes AI code). <https://github.com/ValveSoftware/source-sdk-2013/tree/master/src/game> (files cited individually) | P |
| Division 2 interview | Ubisoft News interview with Drew Rechner (lead AI designer) and Philip Dunstan (lead AI programmer), Massive, 2019. <https://news.ubisoft.com/en-us/article/5wu3eterDz21wNKiAcDJlJ/the-division-2-making-enemies-tougher-and-friendlies-smarter> | P |
| Division write-up | Tommy Thompson, "Enemy AI Design in Tom Clancy's The Division", 2018, summarising Massive's GDC 2016 talks. <https://www.gamedeveloper.com/design/enemy-ai-design-in-tom-clancy-s-the-division> | S |
| DOOM write-up | Tommy Thompson, "Cyber Demons: The AI of DOOM (2016)", 2018, summarising id Software's GDC 2017 and 2018 talks. <https://www.gamedeveloper.com/design/cyber-demons-the-ai-of-doom-2016-> | S |
| BioShock tweet | Ken Levine, 2017-09-02, as quoted in Chris Kerr, "Tricks of the trade". <https://www.gamedeveloper.com/design/tricks-of-the-trade-devs-reveal-how-their-games-fool-players> (tweet: <https://twitter.com/levine/status/903803566825119745>) | P, read through the article |
| UC4 | Matthew Gallant (Naughty Dog), post on his GDC 2017 talk "Authored vs. Systemic". <https://gangles.ca/?p=483> | P |
| EQS | Epic, "Environment Query System Overview". <https://dev.epicgames.com/documentation/en-us/unreal-engine/environment-query-system-overview-in-unreal-engine> | D |

## 1. Fair fire

The sources agree on the goal and state it plainly. Ocio: with several enemies firing at once "unexpected damage spikes can occur", and the fix is to control "the amount of damage the player can receive", then hide that control so enemies do not "look ridiculous or unrealistic when they are purposely missing" [P, Ocio]. Halo's designers put the other half: "Don't be afraid to kill the Player", provided "he can tell how he messed up" [P, Halo 2002, <https://halo.bungie.org/misc/gdc.2002.haloai/talk.html?page=17>].

### 1.1 Accuracy that ramps with exposure time

The most widely documented technique, and the one this game already has in a weaker form.

- **Halo CE**: "our AI gets more accurate the longer the Players stays out of cover", so "a long charge will almost always get you killed". It was added to discourage rushing with the Assault Rifle. No number is given. [P, Halo 2002, <https://halo.bungie.org/misc/gdc.2002.haloai/talk.html?page=17>]
- **Uncharted 2**: a per-weapon "Time To Accurate Cover". When the player pops out of cover the AI's accuracy drops to `accuracy-cover-worst` (0.0 in the published example) and climbs back over `time-to-accurate-cover` (3.5 s in the example). Russell: "when the player pops out of cover to take a shot they have 3.5 seconds where the AI's accuracy will go from 0 percent back up". Easier enemy classes get a longer time, tougher ones a shorter time. [P, UC2]
- **Half-Life 2**: on acquiring an enemy, an NPC's spread cone is multiplied by `ai_spread_defocused_cone_multiplier` (3.0) and shrinks linearly to 1.0 over `ai_spread_cone_focus_time` (0.6 s). A second value, the spread bias, is scaled linearly from 0 up to its full value over `ai_spread_pattern_focus_time` (0.8 s), and that second ramp restarts when the enemy is reacquired after being lost. [P, HL2 source, `ai_basenpc.cpp` lines 196 to 203 and `GetSpreadBias` / `GetAttackSpread` at about line 9604: <https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/ai_basenpc.cpp>]
- **Halo CE tag format**: every actor variant has a "New target" firing pattern: "How long this AI follows 'New target' firing modifiers when first engaging a target", with separate multipliers for burst duration, burst separation and projectile error in that window, plus a "First burst delay time: the delay in seconds before the actor starts its first burst on a new target". Shipped values were not retrieved. [D, Halo CE tags]

Note the two clocks. Uncharted 2 restarts the ramp when the player **leaves cover**. Half-Life 2 restarts it when the enemy is **acquired or reacquired**. This game's current ramp (1.5× closing to 0.5× over 3 s, reset on losing line of sight) is the Half-Life 2 kind, with a far smaller opening penalty and a far longer ramp.

### 1.2 First shots that miss, and bursts that walk in

- **BioShock**: Ken Levine: "First shots from an enemy against you in BioShock always missed...that was the design". [P, BioShock tweet, read through the article]
- **Halo CE tag format**: a burst does not start on the target. "Burst origin radius: the starting point of the burst, randomly to the left or right of the target in world units"; "Burst return length: how far the burst point moves back towards the target"; "Burst angular velocity: sets the maximum rotational rate that the burst can sweep". So a burst begins beside the target and sweeps toward it, which is a miss that reads as aim being corrected. [D, Halo CE tags]
- **Half-Life 2**: the 0.6 s and 0.8 s ramps above mean the first shots on a fresh sighting are spread three times wider. [P, HL2 source]

### 1.3 Accuracy by distance

- **Uncharted 2** publishes a whole curve. For one assault-rifle skill, chance to hit by distance, linear between points: 0 to 4 m 0.9, 8 m 0.5, 12 m 0.4, 20 m 0.4, 30 m 0.3, 60 m 0.0. Curves are separate from weapons so they can be reused. [P, UC2]
- **Ocio** scales the time between allowed hits instead: no change beyond 15 m, halved inside 5 m. [P, Ocio]
- **Half-Life 2** scales the weapon's spread by the NPC's proficiency with that weapon. For the AR2 and SMG1 the spread multipliers are 7.0 (poor), 5.0 (average), 3.0 or 3.33 (good), 1.67 (very good), 1.0 (perfect). Combine soldiers are "good" with the SMG1, "good" or "very good" with the AR2, and "perfect" with the shotgun. [P, HL2 source, `weapon_ar2.cpp` and `weapon_smg1.cpp` at line 498, `npc_combine.cpp` at line 3139: <https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/hl2/npc_combine.cpp>]

### 1.4 Accuracy by what the target is doing

- **Uncharted 2**: multipliers on the chance to hit: target standing 1.0, running 0.9, rolling 0.5. Tougher classes add a flat 0.1 ("Master Accuracy Additive"). [P, UC2]
- **Ocio**: time between allowed hits is doubled if the player is crouching, doubled again if in valid cover, doubled if the player faces more than 170° away from the shooter, halved if running toward the shooter (velocity within 30°), unchanged between 45° and 90°, and lengthened toward 180° (running away). Worked examples from a 0.5 s base: crouched in cover at 30 m gives one hit per 2 s; running at the enemy in the open at 10 m gives one per 0.1875 s. [P, Ocio]
- **Halo CE**: "Our AI isn't very good at shooting at someone moving quickly very close to them", which the designers countered with strong enemy melee. [P, Halo 2002, page 17]
- **Halo CE tag format**: "Target tracking" and "Target leading" fields, each 0 to 1, set how closely the actor follows a moving target and how far ahead it leads. Aim lag is a per-enemy tuning value. [D, Halo CE tags]
- **Half-Life 2**: the trajectory code's own comment: "This code PENALIZES a target for moving directly along the shooter's line of sight. This code REWARDS a target for moving perpendicular to the shooter's line of sight." The default lead time (`ai_lead_time`) is 0.0. [P, HL2 source, `ai_basenpc.cpp` at about line 9670]
- **DOOM (2016)**: "Demon accuracy is intentionally reduced the faster the player moves". [S, DOOM write-up; the GDC talk itself was not read]

### 1.5 Limits on who may fire or hit (attack tokens)

- **Half-Life 2**: a squad has two attack slots: "reserve 2 attack slots for most squads". A Combine soldier must occupy `SQUAD_SLOT_ATTACK1` or `ATTACK2` to run a ranged attack; one that has a line of fire but no slot waits in an "overwatch" slot or moves to establish a line of fire. The first to spot the enemy takes slot 1 and suppresses at once. [P, HL2 source, <https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/ai_squadslot.h> and `npc_combine.cpp` at about line 1505]
- The same code records the failure this causes. Shotgunners fire slowly, so "they spend relatively long periods of time without an attack squad slot"; cornered with the slots taken and no cover, one "will stand around like an idiot, right in front of you". Valve's patch was to send it in for a melee attack. [P, HL2 source, `npc_combine.cpp` at about line 1880]
- **Ocio** names the same failure ("AIs being at perfect spots to shoot and hit the player but not even trying") and gives the fix: tokens gate **hitting**, not **shooting**. Everyone fires; "shots can only actually hit the player if the shooter has a token; any other shot will deliberately miss". One global timer since the last hit hands out the token. Who gets it is a weighted sum of distance, how exposed the player is to that shooter, enemy type, whether the player is attacking that enemy, and how long since that enemy last had it. [P, Ocio]
- **The Last of Us** runs it the other way: a floor, not a ceiling. "It was only necessary for one NPC to be shooting the player at any given time; all other NPCs could spend their time taking cover, flanking, etc." A Combat Coordinator hands out exclusive roles (Flanker, Approacher, Investigator, StayUpAndAimer, OpportunisticShooter). Whoever can see him takes OpportunisticShooter and fires at once, interrupting any animation, because in playtests slow reactions meant a rushing player "would be almost completely untouched". [P, TLOU]
- **Kingdoms of Amalur: Reckoning** (melee, but the general form): the player carries a grid capacity and an attack capacity; each enemy has a grid weight and each attack an attack weight. Example numbers: capacity 12, soldier 4, troll 8; attack capacity 10, attacks costing 3 to 6. Difficulty changes the capacities. [P, Reckoning]
- **DOOM (2016)**: demons "ask to attack the player"; each attack type "has a limited number of tokens", counts differ by difficulty, and demons "can actually steal tokens from one another". No counts given. [S, DOOM write-up]
- **Uncharted 2** spreads targets rather than limiting fire: a "dog-pile" weight of -1.0 per teammate already targeting the same enemy. [P, UC2]

### 1.6 Suppression and shots aimed to miss

- **Ocio**, on where a deliberate miss should land: not a random point around the target, since then "the only thing players are going to notice for most of the shots is their tracers". Against full cover, aim at the ground beside the side he would peek from, or at the cover itself. Against half cover, aim mostly at its top edge, "closer to the eyes of the target". In the open, "whiz tracers right past the player's face at eye level". Prefer destructible objects in his view. [P, Ocio]
- **Half-Life 2** does this in code: after spread is applied, "Look for an opportunity to make misses hit interesting things", redirecting a missing shot at a nearby "miss target". [P, HL2 source, `ai_basenpc.cpp` at about line 9770]
- **Killzone** defines suppression as "Fire near hidden threats to pin them down", and explicitly not "firing into the wall behind which the threat is hiding" or "into locations the threat cannot reach". The method: score the positions around the hidden threat from **his** point of view (20 to 30 for giving him a line of fire on the attacker, 20 for nearby cover), keep those scoring 40 or more that the attacker can fire into, and shoot bursts at them. [P, Killzone, slides 22 to 31]
- **F.E.A.R.**: suppression is what one squad member does so the others can move. "Get-to-Cover gets all squad members who are not currently in valid cover into valid cover, while one squad member lays suppression fire." Enemies also "blind fire if they have no better position", and one shot while in cover "blind fires for a while to make himself harder to hit". No numbers. [P, FEAR]

### 1.7 Tells before a shot

The thinnest half of the evidence. No primary source read gives a telegraph duration for a gunshot.

- **Halo CE tag format**: the "First burst delay time" field is a built-in pause between noticing a new target and firing. [D, Halo CE tags]
- **Uncharted 2**: fire patterns were tuned per weapon "to make them sound a bit more unique so as to be more easily identified by the player". The tell is which gun is firing. [P, UC2]
- **The Division**: elite and named NPCs carry "custom laser sights that have absolutely zero effect on their gameplay ability", there to put the player on edge. [S, Division write-up]
- **The Last of Us**: dialogue "allowed the AI to communicate the decisions they make to the player". [P, TLOU] F.E.A.R. makes the same point about squad barks. [P, FEAR]
- **Halo CE**: readable enemies as a principle: the player should predict them from "lots of simple cause and effect reactions". [P, Halo 2002, <https://halo.bungie.org/misc/gdc.2002.haloai/talk.html?page=7>]

### 1.8 Burst rhythm (published numbers)

- **Uncharted 2**, one assault-rifle skill: automatic bursts of 3 to 5 rounds; a 33 % chance a burst is instead 1 to 3 single shots 0.16 to 0.20 s apart; 0.4 to 0.8 s between bursts. [P, UC2]
- **Half-Life 2**: SMG1 bursts of 2 to 5, shotgun 1 to 3. A Combine shotgunner in the Episodes rests 1.2 to 1.5 s between shots, a change made "to address difficulty concerns". [P, HL2 source, <https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/hl2/weapon_shotgun.cpp> lines 61 and 225 to 255, and `weapon_smg1.cpp` line 40]

## 2. Cover

### 2.1 Where cover points come from

Three approaches, all shipped.

- **Authored markers.** Halo CE: "designers place points grouped where they want a squad to be located"; movement through a space is controlled "solely by assigning them different sets of firing points". [P, Halo 2002, <https://halo.bungie.org/misc/gdc.2002.haloai/talk.html?page=22>] Halo 2 keeps them: "Firing positions are simply discrete points which the AI can consider as destinations". [P, Halo 2] F.E.A.R. uses designer-placed Cover and Ambush nodes. [P, FEAR] Far Cry and Crysis used oriented "hide anchors" with "a directional cone from which cover was provided". [P, Crytek TPS]
- **Generated offline from geometry.** The Last of Us: "all possible cover spots were precalculated by a tool analyzing the collision mesh". [P, TLOU] Killzone 3: "For each waypoint, cover data is stored that describes the cover available in each direction. The cover data is automatically created in an offline process." [P, Killzone 3] Killzone stores it compactly: per waypoint, per radial sector, "the largest distance from where an attacker within that sector can fire at the waypoint", 64 KB for 4000 waypoints, "pessimistic about cover", "inaccurate, but consistent". [P, Killzone, slides 33 to 34]
- **Sampled at runtime.** Brink "had no such static database and relied entirely on dynamically generated points", in concentric rings. Crysis 2 falls back to a 10 m grid around the agent when no hidespot qualifies. [P, Crytek TPS] Uncharted 2 mixes all three into one candidate set: a fixed grid filtered by the navmesh, cover points, and zone markers. [P, UC2] Unreal's EQS is the generic form: a Generator "produces the locations or Actors, referred to as Items, that will be tested and weighted", and Tests "filter and (or) score" them. [D, EQS]

Naughty Dog later tried to have the system find strong positions by itself in Uncharted 4 ("Vantage") and dropped it because it "failed to generate consistent results"; they shipped designer-marked "hard points" whose use is "left entirely up to the systemic combat logic". [P, UC4]

### 2.2 How points are scored

- **Killzone**: a weighted sum. The published example for an attack position: proximity to the agent 20; line of fire to the primary threat 40 if from partial cover, 20 otherwise; cover from the other threats 20; inside the preferred fighting range 10. Highest total wins. The same function with different weights gives different personalities and actions. [P, Killzone, slides 7 to 16]
- **The Last of Us**: filter, then multiply. Gather the 20 nearest cover spots "facing away from the threat"; cast 4 rays per spot to check the NPC "could shoot and hit their target" from it and reject those where every ray is blocked; then each criterion returns 0 to 1 and they are multiplied. 17 selectors shipped, one per behaviour, all evaluated continuously so "the ideal post for any given post selector was always available". A published selector ("panic") requires a valid path, availability, not behind the player, and a distance curve from 0.0 at 3 m to 1.0 at 5 m. [P, TLOU]
- **The Last of Us**, the criterion they single out: reject cover whose **path** runs toward the player. Playtesters complained enemies "would rush forward to take cover"; the best spot needed a run at the player first. Paths to every candidate were refreshed about every half second for this. [P, TLOU]
- **Uncharted 2**: a weighted map re-evaluated once per second per enemy. A published mid-range behaviour: stay within 15 m of the target, no closer than 5 m, 2 m from friends; cover weight 10; move up to 15 m to reach cover; ignore cover within 8 m of the target; sticky factor 1 for the cover already held; target visibility weight 5. Russell names the flaw The Last of Us later fixed: the path is planned separately, so the enemy may run within the repel distance to get there. [P, UC2]
- **Crysis 2**: generation, conditions, weights. The published example for "my spot is compromised": hidespots from the target within 15 m, at least 5 m from me, which I can reach before the target can, preferring hard cover over soft (weight -10 on soft) and nearer points (-1 per metre). [P, Crytek TPS]
- **Claiming.** Far Cry and Crysis never picked "a hidespot that another agent had already claimed". [P, Crytek TPS] F.E.A.R.'s squad layer ensures "other A.I. are not ordered to go to the same node". [P, FEAR] The Last of Us has an "available" criterion. [P, TLOU]
- **Paths as well as points.** Killzone adds to A* link costs for "traversing a friendly line-of-fire" and "being under fire from one or more threats". [P, Killzone, slides 17 to 21] The Last of Us overlays an "exposure map" (a bitmap of what the player can see) as a path cost; its first flanking was exactly that. [P, TLOU]

### 2.3 Peeking: how, and for how long

Few sources publish timings. What exists:

- **F.E.A.R.** states the rule and rejects the alternative: earlier games' enemies "pop in and out randomly like a shooting gallery"; F.E.A.R.'s "always try to stay covered, never leave cover unless threatened and other cover is available, and fire from cover to the best of their ability". [P, FEAR]
- **Half-Life 2** publishes a table. Its standoff behaviour (fight from cover, pop up, shoot, duck) is parameterised by aggression: [P, HL2 source, <https://github.com/ValveSoftware/source-sdk-2013/blob/master/src/game/server/ai_behavior_standoff.cpp> at about line 1182]

  | Aggression | minTimeShots, s | maxTimeShots, s | minShots | maxShots | oddsCover, % | flAbandonTimeLimit, s |
  |---|---|---|---|---|---|---|
  | Very low | 4.0 | 8.0 | 2 | 4 | 50 | 30 |
  | Low | 2.0 | 5.0 | 3 | 5 | 25 | 20 |
  | Medium | 0.6 | 2.5 | 3 | 6 | 25 | 10 |
  | High | 0.2 | 1.5 | 5 | 8 | 10 | 10 |
  | Very high | 0 | 0 | 100 | 100 | 0 | 5 |

  The column names are the code's. I read them as: the wait between groups of shots, the number of shots per group, the chance of ducking after a group, and how long to hold a spot with no shot before giving it up; I did not trace each through the code. All but "very high" also take cover to reload.
- **Uncharted 2**: light soldiers use a cover-fire animation that exposes more of the body than medium soldiers' does, so how much shows during a peek is a difficulty setting. [P, UC2]
- **The Division 2**: aggressive factions "fire in longer bursts"; defensive ones fire shorter bursts with less exposure and reposition less. [P, Division 2 interview]

### 2.4 When they change cover

- **When it stops working.** F.E.A.R.: leave only when "threatened and other cover is available"; a compromised enemy with no cover goes to an Ambush node. [P, FEAR] Crysis 2: once committed, re-check the held point with a cheap query that asks only whether it is "still good enough", and re-pick when "a grenade lands or an enemy movement leaves a position clearly exposed"; changing for "a slightly better spot ... will often look artificial". [P, Crytek TPS]
- **With hysteresis.** Johnson: re-score the current destination alongside the new candidates and move only if the winner is better "by more than some threshold (say, 10%)"; his worked example uses 20 %. Too high a threshold holds stale spots. [P, Johnson] Uncharted 2: a sticky factor for the held cover, plus extra filtering because otherwise enemies "end up bouncing around needlessly". [P, UC2]
- **When the player goes quiet.** The Last of Us: enemies surround and advance; after 10 s or more without seeing him one is sent to check his last known position. That cycle ran nearly 2 minutes in focus tests, so they cheated: if he moves more than 5 m from where they think he is, one goes at once, cutting it to about 30 s. [P, TLOU]
- **One invalidation must not cascade.** Days Gone: mixing the two sides "can lead to cascading cover invalidation if the first AI invalidates someone else's cover while moving". Its fix is to keep the squad behind a line. [P, Days Gone]

### 2.5 Advancing and falling back

- **F.E.A.R.**: four squad behaviours. "Advance-Cover moves members of a squad to valid cover closer to a threat, while one squad member lays suppression fire." Flanking is a side effect: an enemy moving to the only valid cover it knows "may take a back route and resurface on the player's side". [P, FEAR]
- **Days Gone**: a Frontline between the squad and its enemies; each member gets a Lane behind it, which spreads them and keeps them out of each other's fire. Advancing: those furthest from the line move while the rest give cover fire. Retreating: half move a short distance back to new cover while half cover; those nearest the line or without valid cover go first. Flankers come from the ends of the line and "always leave an opening at the rear" so the enemy can retreat. [P, Days Gone]
- **Days Gone**, on when: a squad Confidence value. Against the player it is deliberately contrary: "more passively against an aggressive player, and likewise more aggressively against a passive player". A stationary player raises it, "even faster if the player is hunkering down in cover"; charging, melee, or aiming at an enemy lowers it. [P, Days Gone]
- **Halo CE**: morale is visible. "When a squad takes enough casualties it will retreat ... the squad members will stay in cover longer and fight defensively. This tells the Player that he has won." Grunts flee when their Elite dies. [P, Halo 2002, page 7 and page 17] Halo 2 turns this into styles: "Defensive styles do not allow charge or search behaviors. Aggressive styles do not allow self-preservation." [P, Halo 2]
- **The Last of Us**: flank routes come from a cost shape laid along the "combat vector" (the average direction of the enemies from the player, weighted by recent shots), so a flanker swings wide and comes round behind; only the one best-placed enemy may hold the Flanker role. [P, TLOU]

### 2.6 How weapon and enemy type change the choice

- **A preferred range per weapon.** Halo 2: a firing position is chosen with "a clear line of sight, and which also puts the AI at an appropriate range from the target", "based on the kind of weapon being used". [P, Halo 2] Halo CE's tag format has "Desired combat range: the distance in world units the actor will try to be in to attack", a minimum and a maximum per actor variant. [D, Halo CE tags] Killzone scores "preferred fighting range" as its own term. [P, Killzone] Uncharted 2 swaps whole Combat Behaviours (attract and repel distances) from a library. [P, UC2]
- **Snipers.** The Division 2: a sniper backs away when an enemy gets close, to "put more distance between them and their foe". [P, Division 2 interview] Days Gone keeps snipers out of the Frontline altogether, "confined to small sniper perches", because their immobility would stop the line moving; "rushers" are excluded for the opposite reason. [P, Days Gone]
- **Shotgunners.** Half-Life 2 gives them perfect proficiency (no added spread), a long rest between shots, and a charge into melee when they can neither fire nor find cover. [P, HL2 source, cited above]
- **Squad-level assignment.** Crysis 2 notes the failure of each enemy choosing alone: "the rifleman who occupies the ideal location for a grenadier", and resolves it by assigning points at squad level. [P, Crytek TPS]
- **Archetypes by job.** The Division's nine archetypes divide the pressure: Tanks and Heavies keep the player in cover, Throwers flush him out, Rushers close, Snipers hold range. [S, Division write-up]

## 3. What would transfer to this game

The game as it stands, from `scripts/crew/CREW_AI.md` and `resources/`: a tile is 1 m; props occupy whole tiles; a walking grid already exists per layout (`CrewPaths`); Guards share the Pirate's position; a spread ramp of 1.5× to 0.5× over 3 s; no burst starts within 0.3 s of another's; engage range 10.6 m; every shot is a projectile (Pistol 80 m/s, Assault Rifle 100 m/s, Shotgun 60 m/s, Marksman Rifle 200 m/s, from `resources/weapons/`).

One difference from every source above matters: their shots are mostly instant, so "chance to hit" is a dice roll. Here a shot is a projectile the Pirate can sidestep, so the equivalent lever is **where the shot is aimed**: at him, at where he will be, or at a chosen point beside him. Every candidate below is written in those terms. That translation is mine.

### Fair fire candidates

| # | Technique | Source and its numbers | Suggested start here (mine) |
|---|---|---|---|
| F1 | **Hit budget.** Every Guard may fire, but only the token holder's shots are aimed true; the rest are aimed at a chosen miss point. One timer since the last true-aimed burst hands the token on. | Ocio: base delay 0.5 s; ×2 crouched; ×2 in cover; ×0.5 inside 5 m, ×1 beyond 15 m; ×0.5 running at the shooter; ×2 facing away. | Base 0.8 s. Keep Ocio's multipliers but scale the distance band to ship rooms: ×0.5 inside 3 m, ×1 beyond 8 m. Token goes to the Guard scoring highest on nearness, a clear muzzle line, and time since it last held it. |
| F2 | **Miss points that read as pressure.** A non-token shot aims at the top or peek-side edge of the prop he is behind, or past his head in the open. | Ocio (cover edge, top of half cover, eye level in the open); Half-Life 2 (`FindMissTarget`); Killzone (fire at positions he would use, not at the wall he is behind). | Miss point 0.4 to 0.8 m from his body centre, on the side he last peeked from; in the open, 0.5 m beside the head on the side away from his velocity. |
| F3 | **Exposure ramp restarted by leaving cover.** | Uncharted 2: 0 % to full over 3.5 s from leaving cover, shorter for tougher classes. Half-Life 2: cone 3× to 1× over 0.6 s from acquiring. Halo CE: more accurate the longer he is out of cover (no number). | Replace the 1.5× to 0.5× ramp. Open at 3× (Half-Life 2's number) and close to 1× over 2.0 s for Guards and 3.0 s for Workers, restarting when he leaves cover or is reacquired. Do not go below 1×: the current 0.5× floor is where the laser feel comes from. |
| F4 | **First burst walks in.** | Halo CE tag format: burst origin beside the target, returning toward it. BioShock: first shots always miss. | The first burst on a new sighting starts 1.0 m to one side and reaches him on its last round. With a 3-round burst that is two warning shots and one real one. |
| F5 | **Partial lead.** | Halo CE tag format: tracking and leading are 0-to-1 fields. Half-Life 2: default lead 0, and code that rewards moving across the line of fire. Uncharted 2: running 0.9, rolling 0.5. | Lead fraction of the true intercept: Pistol 0.3, Assault Rifle 0.5, Shotgun 0 (the spread does the work), Marksman Rifle 1.0 (it has a tell, F7). A Slide or Clamber halves it for its duration. |
| F6 | **Attack slots by weight**, as a ceiling on true-aimed fire, alongside a floor of one. | Half-Life 2: 2 attack slots per squad, and the shotgunner starvation bug. The Last of Us: always at least one shooter, instantly. Reckoning: capacity 12, weights 4 and 8. | Capacity 4. Weights: Pistol 1, Assault Rifle 2, Shotgun 2, Marksman Rifle 3. So a Marksman and a Pistol, or two rifles, hold it. A Guard with no slot still fires at miss points (F2), which avoids Valve's idle-shotgunner bug. Keep the 0.3 s burst stagger. |
| F7 | **A tell for the heavy shots.** | Thin. Halo CE tag format: a first-burst delay field. The Division: laser sights on elites [S]. Uncharted 2: a distinct fire pattern per gun so the ear identifies it. | Marksman Rifle: a visible sight line on him for 0.9 s before each shot, and the shot goes where it pointed 0.2 s before firing, so a late sidestep dodges it. Shotgun: an audible rack before stepping out. No tell for Pistol or Assault Rifle beyond F4. |
| F8 | **Distance curve per gun**, applied as extra aim error. | Uncharted 2 curve: 0.9 at 0 to 4 m, 0.5 at 8 m, 0.4 at 12 to 20 m, 0.3 at 30 m, 0 at 60 m. | Shipboard ranges are short, so only the Shotgun and Pistol need a curve. Shotgun: no added error to 4 m, doubling by 8 m. Pistol: no added error to 6 m, doubling by 12 m. |

Order of value, in my judgement: F3 and F4 are cheap changes to code that exists and remove most of the laser feel. F1 with F2 is the structural fix for 5 to 8 crew. F6 matters once the four guns exist.

### Cover candidates

| # | Technique | Source and its numbers | Suggested start here (mine) |
|---|---|---|---|
| C1 | **Generate cover points from the tile grid at layout time.** For every open tile next to a prop footprint or a wall corner, record which of 8 directions are blocked and whether the blocker is full height or half height. | The Last of Us (precalculated from collision); Killzone and Killzone 3 (per waypoint, per direction, offline, "pessimistic"); Far Cry and Crysis (a point plus a cone). | Store on the layout beside the `CrewPaths` grid. A tile is cover against a threat if the blocker lies within 45° of the direction to him. No authored markers and no runtime rays to find candidates. |
| C2 | **Filter, then score.** Filter: reachable, unclaimed, covered from him, and with a tile to step out to that has a clear muzzle line. Score the rest. | The Last of Us (nearest 20, 4 rays each, multiply 0-to-1 criteria); Killzone weights (proximity 20, line of fire from partial cover 40, cover from other threats 20, preferred range 10); Uncharted 2 (cover weight 10, visibility 5, friend repel 2 m). | Candidates: cover tiles within 8 m of the Guard by path. Killzone's weights as they stand, plus -20 for any Guard within 2 m (Uncharted 2's distance). The existing muzzle-line sweep supplies the step-out test. |
| C3 | **Reject cover whose path runs at him.** | The Last of Us, from playtest complaints of enemies rushing forward. Uncharted 2 names the same flaw. | Reject if any path tile is nearer to him than both the Guard's start and the cover tile, unless the Guard's role is to advance (C7). This is the direct cure for "run straight at the player". |
| C4 | **Claims.** | Far Cry and Crysis; F.E.A.R.'s squad layer; The Last of Us. | One Guard per cover tile, claimed on choosing it, released on leaving or dying. |
| C5 | **Stickiness.** | Johnson: move only for a 10 % better score (20 % in his example). Uncharted 2: re-evaluate once per second. Crysis 2: cheap "still good enough" check. | Re-score once per second. Each tick, check the held tile is still covered from him; if so, move only for a 20 % better score. |
| C6 | **Peek rhythm by gun**, in place of the single 1.2 s hold. | Half-Life 2 standoff, medium aggression: 3 to 6 shots, then 0.6 to 2.5 s down, 25 % chance to duck; high: 5 to 8 shots, 0.2 to 1.5 s. Shotgunner 1.2 to 1.5 s between shots. Uncharted 2: 3 to 5 round bursts 0.4 to 0.8 s apart. | Pistol: 2 to 3 shots up, 1.0 to 2.0 s down. Assault Rifle: two bursts of 3 to 5 rounds 0.4 to 0.8 s apart (Uncharted 2's numbers), then 1.5 to 2.5 s down. Shotgun: 1 shot, 1.2 to 1.5 s down (Half-Life 2's numbers). Marksman Rifle: 1 shot after its 0.9 s tell, 2.5 to 4.0 s down. Keep the existing per-crew 0.75 to 1.35× jitter. |
| C7 | **When to move.** Leave cover only when it is invalid, when it has had no shot for a while, or on an ordered advance or retreat. | F.E.A.R. (only when threatened and other cover exists). Half-Life 2 (abandon limits of 10 to 30 s). The Last of Us (10 s unseen sends one to check; 5 m of unseen movement sends one at once). Days Gone (cover fire while others move; furthest advance, nearest retreat; passive player raises confidence). | Invalid: he has a line to the Guard's tile from a direction it does not block. No shot for 6 s: re-pick. Advance: after 8 s of him holding one position, the furthest Guard moves one cover nearer while the token holder fires. Fall back: a Guard hurt below half health, or the last Guard standing, picks cover further from him. |
| C8 | **A range band per gun**, as a term in C2's score. | Halo 2 and Halo CE tag format (desired combat range per weapon); Killzone (preferred fighting range); Uncharted 2 (5 to 15 m mid-range behaviour, no cover within 8 m of the target); The Division 2 (snipers back off); Days Gone (snipers hold perches, rushers ignore the line). | Shotgun 2 to 5 m, and it is the only gun allowed cover within 4 m of him. Pistol 4 to 8 m. Assault Rifle 5 to 10 m. Marksman Rifle 8 m or more: it prefers the cover tile with the longest clear sight line (the far end of a Lane or Corridor), does not advance, and re-picks if he comes within 5 m. |
| C9 | **Suppress his cover when he hides**, instead of the current rush to his last-seen spot. | Killzone (fire at the positions he would shoot from); F.E.A.R. (one suppresses, the rest move). | When he breaks sight behind a prop, the token holder fires C6 bursts at that prop's edges for up to 4 s while one other Guard moves (C7 advance, or the existing pin-and-flank route). |

The existing pin-and-flank already matches The Last of Us's single-Flanker rule and F.E.A.R.'s flank-as-side-effect; nothing in the sources argues for changing it.

## 4. What I could not verify from a primary source

- **Halo beyond CE and 2.** I found no developer source giving Halo 3, Reach, 4, 5 or Infinite enemy accuracy rules or numbers. The Halo CE claims rest on the 2002 talk (principles, no numbers) and on c20's description of the tag fields. The values Bungie set in those fields per enemy were not retrieved.
- **The Division.** Massive's two GDC 2016 talks are video only (<https://gdcvault.com/play/1023056/> and <https://gdcvault.com/play/1023055/>) and were not watched. Nothing here on how its enemies find or score cover comes from a primary source; the laser-sight and archetype claims are from a secondary write-up.
- **DOOM (2016) tokens and speed-scaled accuracy.** Secondary write-up only; the GDC talks (<https://gdcvault.com/play/1024940/>) were not watched. No token counts are published in what I read.
- **Killzone's proceedings paper** (Straatman, van der Sterren, Beij) was found only as a PDF whose text would not extract. The slides were used instead; the paper's extra detail on terrain representation is not covered.
- **Lars Lidén, "Artificial Stupidity: The Art of Intentional Mistakes"** (AI Game Programming Wisdom 2), which Ocio cites for visible misses and which is the usual citation for "miss the first shot", is a print chapter I could not open. It is not used as evidence.
- **BioShock's first-shot miss.** Read as quoted in an article, not from the tweet. A search summary reported that Levine hedged on whether it was fully implemented and that the game's AI designer called it more complicated; I did not open either statement.
- **F.E.A.R.** publishes no accuracy or timing numbers in the paper read.
- **The Last of Us and Uncharted 4** publish no peek or cover-hold timings in what I read. The Uncharted 4 talk (<https://gdcvault.com/play/1023949/Authored-vs-Systemic-Finding-a>) is video and was not watched.
- **Half-Life 2.** The numbers are read directly from the code. Two readings are mine: what the spread bias does inside the shot manipulator (I did not open that class), and the exact meaning of the standoff table's columns (inferred from their names).
- **Tells before a shot.** No primary source read gives a telegraph duration for enemy gunfire. F7's numbers are entirely mine.
- **Peek durations** in general: only Half-Life 2 and Uncharted 2 publish any.
