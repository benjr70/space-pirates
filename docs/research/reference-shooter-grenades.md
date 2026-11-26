# Reference shooter grenades: carrying, throwing, frag, flash, smoke

Research date: 2026-11-25. Answers the question in `.scratch/equipment/issues/01-reference-shooter-grenades.md`. Facts and options only; this note decides nothing.

## Summary

- **Carrying.** Every game studied caps grenades hard and low: Halo Infinite 2 per kind, Call of Duty 1 lethal + 1 tactical by default (0 to 2 by vest in MWIII), Counter-Strike 2 four in total with one of each kind (two flashbangs), Siege 2 or 3 of one chosen kind. Only Tarkov leaves it to inventory space.
- **Throwing.** Two families. Halo and Call of Duty throw from a dedicated key with the gun still in hand. Counter-Strike, Siege and Tarkov draw the grenade into the hands first (CS2: 1.0 s draw). Cooking exists in Call of Duty and existed in Siege until Ubisoft removed it in 2023 as "the main reason" frags were too strong. Counter-Strike has a line-up reticle and a practice-only preview, never a live arc.
- **Frag.** Fuses run 3 to 5 s from release. Three independent developers lengthened or constrained the fuse to give the victim time to react (343: +0.2 s; Ubisoft: no cooking, 4 s; Valve: no cooking at all). Lethal cores are small and outer rings wide: MWIII deals 225 inside, 150 mid-ring out to 3.8 m, against 150 health.
- **Flash.** Counter-Strike and Siege both work blindness out per victim from distance, facing and line of sight. Siege's 2021 rework fixed full intensity and varies only duration, because "it's not fun to use a gadget and be unsure of exactly how it will affect your enemy". MWIII publishes three range bands: 3.5 s / 2.75 s / 1 s.
- **Smoke.** CS2 smoke is one shared volume that fills the space it lands in, lasts about 20 s (wiki), and is opened briefly by bullets and HE blasts. Valve's patch history is mostly fixes for smoke that one side could see through. Halo's Shroud Screen is opaque both ways and blanks the motion tracker inside.
- **HUD.** Count and kind sit beside the weapon readout. No developer source for a live-grenade warning marker was found in this pass for any of the five games.
- **Mistakes named by developers.** Grenade spam and the dying throw (343), cooking that removes counterplay (Ubisoft), unpredictable flashes (Ubisoft), one-way smoke and explosions (Valve), equipment that regenerates on a timer making spam cheap (Call of Duty's Restock is the lever).
- **Gaps.** Halo Infinite's absolute fuse, damage and inner radius are not published. No source was found for what flash or smoke does to AI in any of these games beyond two Tarkov patch-note lines. See "Not found".

## How to read this note

Source tiers, as in `reference-shooter-numbers.md`:

- **[O] Official**: developer page, patch notes or developer post.
- **[D] Game data**: a value read out of shipped game files (here, CS2's `weapons.vdata` as mirrored by SteamDatabase).
- **[W] Wiki**: community wiki. Every number tagged [W] is wiki-sourced and unverified against the developer.
- **[G] Fan guide or fan site**: a single guide, database site or measurement reported second-hand. Treated as unconfirmed.
- **UNCONFIRMED**: no source I could open states it.

Sources that refused automated reading and were **not** consulted: support.halowaypoint.com (403, as in the earlier note), developer.valvesoftware.com (403), liquipedia.net (403), counterstrike.fandom.com / callofduty.fandom.com / escapefromtarkov.fandom.com / rainbowsix.fandom.com (402), gamepur.com (403), api.tarkov.dev (server unavailable). The interactive page counter-strike.net/cs2 returned only its title. Search-engine summaries of those pages are not used as evidence except where flagged "search summary only".

### What the earlier research already holds

Both earlier notes were read first. Neither covers grenades or Equipment; they are reused here for context only:

- `research/halo-infinite-feel-reference` (`docs/research/halo-infinite-feel-reference.md`): Halo Infinite shields absorb all damage until depleted and recharge after "about five seconds" without damage [O]; exact shield and health values are not published. Forge documents 1 world unit = 1 foot [O].
- `research/reference-shooter-numbers` (`docs/research/reference-shooter-numbers.md`): the same unpublished-health finding; the list of tuning levers 343 publishes; a caution that Halo tag data is traditionally read at 1 wu = 10 ft, **which conflicts with the Forge figure above**. That conflict matters here: the frag's official radius of 2.5 wu is 0.76 m at 1 ft per wu and 7.6 m at 10 ft per wu. Neither note resolved it and neither does this one; 7.6 m is the only reading that makes sense for an outer damage radius.

## Halo Infinite

Halo Infinite has no flash grenade and no smoke grenade. Its grenades are frag, plasma (sticks), spike (sticks, fires spikes) and dynamo (shock field). The nearest thing to smoke is the Shroud Screen, a piece of Equipment.

### Carrying

- Four kinds exist; "with default settings, players can hold two" of a kind [W, Halopedia Dynamo grenade]. Fan guides state the multiplayer rule as two kinds at a time, two of each, four in total [G, search summary of GameRant / Pro Game Guides; not opened].
- Multiplayer spawns the player with frags [G, same]. More are picked up from the map and from bodies; the campaign carry limit and its upgrades are UNCONFIRMED.
- Switching kind: controller D-pad left ("Switch Grenade"; in campaign it opens a Grenade Switcher with one D-pad direction per kind); keyboard N (next) and B (previous). Direct-select bindings per kind exist but have no default key [W, Halopedia HINF:Control schemes].
- Equipment is a separate slot on its own key (controller right bumper, keyboard Q) [W, same]. In multiplayer it "is earned via combat and/or scavenging the playspace" [O, Inside Infinite January 2021]. Shroud Screen holds up to four charges in multiplayer [W].

### Throwing

- Dedicated key, gun stays in hand: controller left bumper, keyboard G or C [W, HINF:Control schemes].
- No cooking and no arc preview: UNCONFIRMED by any source opened (no source mentions either feature existing).
- Throw speed, arc, throw duration and what is locked out mid-throw: UNCONFIRMED.
- Bounce: the frag's Forge description says "Skilled users can bounce the grenade to get hard-to-reach targets and bypass obstacles" [O via W, in-game text quoted on Halopedia]. The dynamo grenade "do[es] not bounce very far after contacting surfaces" [W].

### Frag

- Damage radius: **2.7 wu reduced to 2.5 wu** in February 2023 [O, February Update Preview]. See the unit caution above.
- Fuse: absolute value not published. The Winter Update 2022 "increased detonation timer by 0.2 seconds" [O, Sandbox Balance Updates Winter Update]. A fan wiki gives "a three-second fuse" [G, Giant Bomb, search summary only].
- Damage, inner (lethal) radius, falloff curve, self-damage, what blocks the blast: UNCONFIRMED.
- Knockback is tuned separately from damage. Season-era sandbox update: frag "instantaneous acceleration increased 1.75 >> 3.5", and "grounded player acceleration scalar decreased 1 >> 0.1", so the blast launches airborne players (grenade jumps) but barely shoves a player standing on the ground [O, Sandbox Update Halo Infinite].
- Plasma grenade: "Stuck plasma grenades bypass shields" [O via W, Forge description]. Halopedia's general article says it detonates about 3 seconds after coming to rest but does not tie that to Infinite [W].

### Flash and smoke equivalents

- Flash: none. (Halopedia notes that in Halo 5 players at the edge of a plasma grenade blast were blinded [W]; that is not in Infinite.)
- Shroud Screen: launched, activates on contact with a surface, makes "a spherical shroud upon landing, obstructing line-of-sight and motion tracker" [O, Sandbox Updates Season 3]. "The spherical region is opaque, preventing players outside of its perimeter from seeing into or past the sphere"; players inside cannot see out either; motion trackers of players inside stop showing enemies; outside audio is muffled inside; it blocks no projectiles; a Threat Sensor reveals players inside it [W, Halopedia Shroud Screen]. Radius, duration and effect on campaign AI: UNCONFIRMED (it is a multiplayer item).

### Showing it

- HUD position of the grenade count: UNCONFIRMED. One fan guide says kinds carried show as lines under the grenade icon "in the lower right" [G, GamePur, search summary only; page refused]. Halopedia's HUD article gives nothing for Infinite [W].
- Warning marker for a live grenade: no source found that Infinite has one. UNCONFIRMED.

### What 343 treats as the mistakes

- **The dying throw.** "The Frag Grenade has received feedback that it's a bit too effective"; "throwing one just before dying results in easier trades than intended." The fix was a longer fuse: "This will give players a little bit more time to react to a grenade that has landed near them. It will also reward players for better placed grenades." [O, Winter Update]
- **Grenade spam.** The radius cut "should help reward skilled Frag Grenade placement" and address "the concerns around grenade spam effectiveness in gameplay." [O, February Update Preview]
- **Equipment needs telegraphing.** Sandbox designers on Equipment generally: "a low skill floor and a high skill ceiling"; "there's engaging counterplay or clear telegraphing that give players on both sides an opportunity to display skill mastery"; Equipment "is meant to be a force multiplier by design". [O, Inside Infinite January 2021]

## Call of Duty: Modern Warfare (2019) to Modern Warfare III (2023)

### Carrying

- Two categories, each its own slot: "Lethal Equipment – These items are designed to maximize harm to your enemies"; tactical equipment is "often used to confuse or stagger the enemy or offer a unique benefit on the battlefield" [O, Activision blog, The Basics of MW Loadouts, 2019].
- MWIII makes the counts a loadout choice through vests. Infantry: 1 tactical + 1 lethal. Engineer: 2 tacticals, no lethal. Demolition: 1 tactical + 2 lethals. CCT Comms: neither. "Your Vest determines how many Tacticals and Lethals you can carry, from none to two." [O, Gear Up: MWIII Loadouts, Activision via Blizzard news]
- Resupply is on a timer and is a perk, not a default. MW2019 Restock "recharges equipment over 30 seconds" [O, Activision blog]. MWIII Demolition Vest: "Resupply Lethal and Tactical Equipment every 25 seconds" [O, Gear Up].
- Switching kind: none. A loadout holds one lethal kind and one tactical kind; the kind is chosen before the match.
- Count of each kind carried in MW2019 by default (commonly one lethal and one or two of the tactical): UNCONFIRMED from a source opened.

### Throwing

- Dedicated keys, one for the lethal and one for the tactical, gun stays in hand: default bindings UNCONFIRMED from a source opened.
- Cooking: the frag is officially "Cookable fragmentation grenade" [O, Gear Up]. MWIII launch-period notes: "Removed undocumented reduction to the cook duration of Frag Grenades" [O, MWIII launch patch notes].
- Thrown-back grenades are a supported mechanic: Ordnance Gloves "Throw equipment farther. Reset fuse timer on thrown back grenades." [O, Gear Up]
- Fuse: about 3 s [G, guide, search summary only]. Arc preview: none mentioned in any source. Throw speed and throw time: UNCONFIRMED.

### Frag

- MWIII, where the developer publishes the rings (player health is 150 in MWIII multiplayer; that figure is from memory and UNCONFIRMED here):
  - Inner explosive damage: 250, then **225** from Season 3 [O, MWIII Season 3 patch notes].
  - Intermediate explosive damage: 150, cut to 130 at Season 3, then back to **150** two weeks later, while the intermediate radius went from **4.9 m to 3.8 m** [O, same page, later dated update].
  - Outer ring damage and outer radius, and the inner radius: UNCONFIRMED. A fan-site figure for a later title gives 6.5 m radius and 240 maximum damage [G, Dot Esports, search summary only]; a Warzone guide gives 8 m, 140 centre, 75 edge [G, MeinMMO, search summary only].
- Mitigation is gear: EOD Padding "Reduces damage from non-killstreak explosives and fire"; "incoming explosive damage is now properly clamped at 80% of the player's maximum health", which means a player wearing it cannot be killed from full health by one grenade [O, Gear Up; MWIII launch patch notes].
- Self-damage and what blocks the blast: UNCONFIRMED.

### Flash and stun

Call of Duty splits the job in two: the flash blinds and deafens; the stun slows movement and aim.

- Flash, MWIII: close-range duration 4 s reduced to **3.5 s**; medium range 2.35 s raised to **2.75 s**; far range 0.45 s raised to **1 s** [O, MWIII Season 3 patch notes]. The notes call these "stun duration" on the Flash Grenade. The distances that bound the three bands: UNCONFIRMED.
- Stun, MWIII: "Decreased victim aim slowness duration to 300ms"; "Victim movement and aim slowness now linearly scales down throughout the stun duration"; no aim slowness at all on a victim wearing Tac Mask [O, same].
- Tac Mask "Reduces strength of enemy flash, stun, and gas grenades", and was given "immunity to Flash Grenades (Tactical) thrown by the player's self" [O, Gear Up; MWIII launch patch notes]. So self-flash is real by default.
- MW2019 / Warzone: maximum stun 5.16 s, maximum flash 4.7 s, both about 6 m radius, weaker with distance; Battle Hardened cuts them to 2.15 s and 3.2 s; the flash "wears off after about half its duration" [G, MeinMMO reporting measurements by the YouTuber TheXclusiveAce]. Measured by a player, not published.
- Whether facing matters in Call of Duty: UNCONFIRMED.

### Smoke

- "Deploys a smoke screen that blocks vision and automated targeting systems" [O, Gear Up]. Bloom time, size, duration: UNCONFIRMED.

### Showing it

- HUD placement and the grenade danger indicator (the on-screen marker pointing at a live frag, long a series feature): no official source opened describes either. UNCONFIRMED.

### What the series treats as the mistakes

- No designer statement was found. The patch record shows the direction: frag power is moved out of the wide ring and into a tight one (radius 4.9 m to 3.8 m) [O]; flash is made weaker point-blank and more reliable at range [O]; counters are sold as loadout slots (EOD Padding, Tac Mask) rather than built into the grenade [O]; regenerating supply costs a perk or vest slot [O].

## Counter-Strike 2

Grenades in Counter-Strike are bought each round and are the game's main tactical layer, so Valve's rules are the most worked-out of the five.

### Carrying

- Four grenades in total; one each of HE, smoke, molotov/incendiary and decoy, and up to two flashbangs [G, csdb.gg grenade guide]. The cap is the server setting `ammo_grenade_limit_total`, which "now also enforces the total number of grenades a player is allowed to purchase in a round" [O, CS2 release notes 2026-09-22].
- Prices: flashbang 200, HE 300, smoke 300, molotov 400, decoy 50 [D, `weapons.vdata` `m_nPrice`].
- Resupply: bought at round start only; "grenades can now be dropped just like weapons" [O, Operation Riptide notes, 2021-09-22].
- Switching kind: each kind is its own slot in the grenade group (`GEAR_SLOT_GRENADES`), selected by key or by cycling [D].

### Throwing

- Drawn into the hands: the grenade replaces the gun. Draw time 1.0 s (`m_flDeployDuration = 1.0`) [D]. A flashbang "can be redeployed after thrown so that players can quickly throw multiple in sequence" [O, 2023-06-14].
- Throw speed: `m_flThrowVelocity = 750.0` units/s for every grenade [D]. At the usual Source scale of 0.75 inch per unit (not re-verified in this pass) that is about 14.3 m/s.
- Three strengths from two buttons: primary = full, secondary = short lob, both = medium [G, csdb.gg]. Valve's own notes confirm the middle one: "50% throw-strength grenades are now guaranteed if both attack buttons are held long enough then released within a short time from each other" [O, 2024-02-16]; "You can now get an intermediate strength grenade throw without a delay by pressing primary and secondary attack simultaneously" [O, 2023-12-04].
- The thrower's movement carries into the throw; a jump throw is so central that Valve built it in and plays "a dedicated player-only sound when a grenade is correctly jump-thrown" [O, 2023-03-30; 2024-08-19 "Side-stepping Skill" post].
- No cooking: holding the button holds the pin; the fuse starts on release. (No source opened states this in one sentence; it follows from the pin-pull notes below. Treat as UNCONFIRMED.)
- Commitment: "Weapon switching after releasing the fire button(s) will no longer cancel grenade throws" [O, 2023-12-06]; a later fix closed "a case where it was possible to cancel a grenade throw after the throw was started near the end of the pin pull animation" [O, 2026-05-14]. So a throw can be cancelled while the pin is held, and not after release.
- Arc preview: none in live play. Valve added "a grenade line-up reticle that appears shortly after pulling the pin", with timing configurable per grenade type [O, 2024-04-25], and a practice-mode "grenade preview camera" that "now shows the result of a jump throw" [O, 2024-11-13]. "Enabled grenade crosshairs in freeze time" [O, 2026-09-30].
- Bounce is treated as something that must be predictable: dozens of notes "to make grenade bounces more predictable", and "set many smaller props to exclude player movement and grenade bounces" [O, 2024-02-06; 2024-11-13]. Bounce sounds are audible to others and their range was tuned down [O, 2023-11-08]. Each grenade has its own draw, pin-pull and throw sounds [O, 2025-09-16].

### Frag (HE grenade)

- Maximum damage 99, radius 350 units (about 6.7 m at 0.75 inch per unit), armour ratio 1.2 [D, `m_nDamage`, `m_flRange`, `m_flArmorRatio`]. In practice about 98 to an unarmoured player and 57 to an armoured one at point blank, falling with distance [G, csdb.gg]. Against 100 health, **one HE never kills an armoured player from full health, and a point-blank HE on an unarmoured player leaves 1 or 2 health.**
- Fuse: time-fused, no impact detonation. Value UNCONFIRMED from a source opened.
- "Damage from HE grenades that explode mid-air near the ground will no longer be calculated as if they exploded on the ground" [O, 2026-01-30]: the blast origin is the real position.
- Walls: "HE grenades no longer affect smokes through walls" [O, 2023-03-30]. Whether walls fully block blast damage, and self-damage rules: UNCONFIRMED (the data file tags every grenade `self_damage_on_miss__inflicts_damage` [D]).

### Flash

- A flashbang is drawn, thrown and fused like the HE [D]. Fuse value UNCONFIRMED.
- "Up to 5 seconds of full blindness (varies by exposure)"; turning away reduces or avoids it [G, csdb.gg]. The per-angle and per-distance table is on the wikis that refused reading: UNCONFIRMED.
- Line of sight decides it: "Adjusted particle effect sprite opacity for fully occluded flashbangs" and "Fixed flashbang inconsistency with metal gratings" [O, 2026-04-29; 2023-11-16].
- Other players can read a blinded player: the third-person pose "now accurately represents the player's visibility level, and the pose will only show the player's arm covering their eyes when they are completely blinded" [O, 2024-11-13].
- It deafens too, and Valve turned that down at launch: "Lowered volume of flashbang ringing and volume ducking effect" [O, 2023-03-24].
- AI: Counter-Strike's bots are not a design reference here; nothing found.

### Smoke

- One shared volume that fills the space: Valve's notes call it "[ VOLUMETRIC SMOKE ]", with a "smoke expansion algorithm" that had to be fixed "when detonating very close to a wall" [O, 2023-06-08], and "Adjusted smoke behavior to cover cases where smoke would stop less than a player's height above the ground" [O, 2023-09-27].
- Duration about 20 s, against 18 s in CS:GO [G, csdb.gg]. Bloom time and size: UNCONFIRMED.
- It reacts to the fight. Bullets cut holes ("Shotguns now create larger holes in smoke volumes") and an HE clears it briefly ("HE grenade effect times on smoke has been reduced") [O, 2023-06-06]. "The bomb explosion now interacts with smoke grenade clouds and molotov/incendiary fire" [O, 2026-07-20]. A smoke puts out fire [O, 2025-08-26 fix note].
- It pops where it lands, with a floor: "Smoke grenades now have a minimum fuse duration to prevent smokes from prematurely detonating if stuck in crevices" [O, 2023-11-02].
- Standing inside one builds up a screen effect: "HE grenade explosions within smoke now clear the accumulated smoke screen effect on players inside that smoke" [O, 2024-10-28].

### Showing it

- Grenades appear as a row of icons in the weapon list (the notes mention "four grenade icons ... in the team hud") [O, 2023-07-18]. Exact placement: UNCONFIRMED.
- No warning marker for a live grenade. The warning is sound: bounce, pin-pull, and the thrower's automatic radio call ("Flashbang in the hole", "Smoke in the hole" strings in the data) [D].

### What Valve treats as the mistakes

Valve writes no design notes, but the fix list is one long campaign against **smoke and explosions that hide one side only**:

- "Fixed one-way visibility for players inside HE grenade explosions" [O, 2024-06-10].
- "Adjusted visibility of player silhouettes in smoke"; "Fixed a bug where enemies were visible on the radar when viewed through a combination of smoke and translucent surfaces such as glass" [O, 2024-02-08].
- "Fixed a case where fire was visible through smoke" [O, 2025-05-08]; "Player reflections in water are now occluded by smoke" [O, 2023-09-27]; "Smoke bullet holes are now fixed relative to the firstperson camera" [O, 2023-03-24]; a Windows HDR bug "that led to smokes intermittently disappearing" [O, 2023-10-19].
- Second theme, **unpredictable physics**: grenades falling through the world, wedging in gaps, detonating early when stuck ("Flashbangs and HE grenades no longer prematurely detonate when they exceed their 'stuck bounce' limit" [O, 2024-10-02]).

## Rainbow Six Siege

### Carrying

- Grenades are a "secondary gadget": each operator's loadout offers two or three gadget options and the player takes one kind for the round. No switching, no resupply.
- Count per kind (commonly 2 frags, 3 stuns, 2 smokes): UNCONFIRMED from a source opened. Ubisoft confirms frags come in more than one: "We evaluated reducing the amount to only 1 per operator" and rejected it [O, Y8S4 Designer's Notes].

### Throwing

- Drawn into the hands on the gadget key, then thrown: UNCONFIRMED from a source opened (standard for the game).
- **Cooking was removed from the frag in Y8S4 (November 2023).** New fuse system: "Removed ability to cook the grenade. Added fuse time reduction after the first bounce. Initial fuse time: 4 seconds (from 5). Reduced fuse time: 2 seconds." [O, Y8S4 Designer's Notes, as quoted in search results and confirmed by fetching the page] The fuse runs 4 s from the throw, and the first bounce cuts whatever remains down to 2 s if it was longer.
- "We have adopted the fuse system from the Stun Grenade" [O, same]: the stun already worked this way. The wiki says stuns "detonate 3 seconds after they are thrown and cannot be 'cooked'" [W, Rainbow Six wiki, search summary only].

### Frag

- Fuse as above. Damage and radius: UNCONFIRMED.
- Frags damage through destructible floors and thin surfaces; Ubisoft tested "reducing or removing damage through surfaces" and found it "stopped attacks from below, but did not reduce power for most operators" [O, Y8S4 Designer's Notes, paraphrased by the fetch tool].
- Self and team damage: UNCONFIRMED here (friendly fire is on in Siege).

### Flash (Stun Grenade)

- Y6S3 (2021) "flash detection" rework, applied to the Stun Grenade, Ying's Candela and Blitz's shield. Four inputs: "the operator's distance from the explosion, their orientation, the surrounding environment, and the angle of the explosion", worked out separately for each player in the radius [O, Y6S3 Pre-Season Designer's Notes].
- Intensity is binary; only time varies: "If an Operator is affected, they will always be flashed at 100%, but the duration will change each time." [O, same] The addendum adds a flash-effect update that "reduces flash duration based on the player's orientation" [O, Y6S3 patch notes addendum, search summary only].
- Numbers: none published. The wiki gives a 15 m maximum reach and full blindness out to 11 m when facing the grenade [W, search summary only]; a 2022 guide says about five seconds in total [G, Dignitas, search summary only].

### Smoke

- No number or rule found in a source that could be opened. Ubisoft mentions smoke only as Osa's "least picked secondary gadget option" [O, Y8S4]. Duration, size, propagation: UNCONFIRMED.

### Showing it

- A gadget HUD shows the equipped gadget and count; a Y11S1.3 note mentions the frag being "highlighted in the Gadget HUD" [O, search summary only]. Siege shows a warning icon over a live frag near the player; no official source for it was found: UNCONFIRMED.

### What Ubisoft treats as the mistakes

Ubisoft is the only studio here that wrote the reasoning down in full [O, Y8S4 Designer's Notes]:

- **Cooking was the problem.** "This change removes a skill component when using them, but this aspect has been identified as the main reason why they are too powerful." "Skilled players have reached a level that even ignores the correct counters for grenades."
- The goal was to "bring down the power level of the Frag Grenade to be in line with all the other Secondary Gadgets", so more operators could carry one.
- Alternatives tested and rejected: no damage through surfaces (did not reduce power enough); **non-lethal frags** (reduced power but "removed too much of the gadget's identity"); one per operator (choice became "too binary"); **random 3 to 5 s fuse** (fun, made defenders react, but added randomness they did not want).
- **Flash must be predictable.** "It's not fun to use a gadget and be unsure of exactly how it will affect your enemy." [O, Y6S3 Pre-Season Designer's Notes]

## Escape from Tarkov (the extraction shooter)

Tarkov was chosen over Hunt: Showdown because its grenades are the conventional frag, flash and smoke. It is also the worst documented: Battlestate publishes no numbers, the official wiki refused reading, and the public data API was down. Everything numeric below is from one fan database.

### Carrying

- Grenades are inventory items; the limit is space, not a rule. A guide advises "2 to 4 grenades a raid" [G, eft-ammo guide]. They are bought from traders with restock limits, crafted, or looted; AI "hold grenades in their pocket slots" [G, same].
- Where a grenade must sit to be thrown (rig or pockets) and the key (commonly G): UNCONFIRMED from a source opened.

### Throwing

- Drawn into the hands. Overhand and underhand throws: "You can also underhand grenade throw for a shorter distance" [G, eft-ammo guide].
- "Strength impacts the throw distance" and grenade weight varies by kind [G, same]; the Throwables skill adds 0.5 % throw strength per level, to +25 % [G, tarkovforge].
- Grenades "WILL roll quite a distance" [G, eft-ammo guide]. Pulling the pin makes an audible click [G, same].
- Cooking and arc preview: one guide claims both [G, ludo.guide], but the same page names grenades that are not in the game, so it is discarded. UNCONFIRMED.

### Frag

Fan database values [G, tarkovforge; origin of its data not stated]:

| Grenade | Fuse | Explosion radius, min to max | Fragments | Contusion radius |
|---|---|---|---|---|
| F-1 | 3.5 s | 3 to 7 m | 90 | 12 m |
| RGD-5 | 3.5 s | 3 to 7 m | 70 | 10 m |
| M67 | 5 s | 4 to 8 m | 75 | 11 m |
| VOG-17 | 3 s | 2 to 6 m | 100 | 9 m |
| VOG-25 | 2 s | 2 to 7 m | 35 | 7 m |
| RGO / RGN (impact) | 3.5 s or on impact | 2 to 7 m / 2 to 5 m | 85 / 75 | 12 / 13 m |

- Damage is carried by simulated fragments, each with its own "fragment chance, projectile speed, damage, pen power, armor damage" and bleed chance; fragments "can even deflect" [G, eft-ammo guide]. Cover therefore blocks as it blocks bullets. Self-damage is total.
- A wider "contusion" ring stuns hearing and vision without wounding [G, tarkovforge column].

### Flash

- Zarya: fuse 2 s, contusion radius 10 m. M7290: fuse 1.5 s, 10 m [G, tarkovforge].
- Blinding "depends on the distance to the flash, type of flash", eyewear, and "if the opponent is looking into the flash"; "You can dodge a flash by turning away from it" [G, eft-ammo guide]. Durations: UNCONFIRMED.
- AI: guides use flashes to probe for bosses [G]. What a flash does to an AI enemy: UNCONFIRMED.

### Smoke

- RDG-2B fuse 3.5 s; M18 fuse 1 s [G, tarkovforge].
- "Increased the cloud size and spread speed of smoke grenades by 30%" [O, patch 0.13.0.4, as reproduced by GINX].
- AI: "Fixed bots' reactions to smoke grenades" [O, patch 0.13.0.0, as reproduced by GINX]. So bots do react to smoke, but the rule (whether it blocks their sight) is not published. A guide says thermal sights cannot see through smoke [G, eft-ammo guide].

### Showing it

- No HUD count and no warning marker: Tarkov has almost no HUD. UNCONFIRMED from a source, but nothing found suggests either exists.

### AI and grenades

- AI throw grenades at the player (patch note: "Fixed a rare bug where bosses or their guards would freeze after throwing a grenade" [O, 0.13.1.0 via GINX]) and "will reposition" when one is thrown at them [G, eft-ammo guide].

## Cross-game comparison

| | Halo Infinite | Call of Duty (MW2019 to MWIII) | Counter-Strike 2 | Rainbow Six Siege | Tarkov |
|---|---|---|---|---|---|
| Kinds carried at once | 2 [G] | 1 lethal + 1 tactical [O] | up to 5 [G] | 1 [UNCONFIRMED] | any |
| Count | 2 per kind [W] | 0 to 2 per slot by vest [O] | 4 total, 1 per kind, 2 flash [G][O] | 2 to 3 [UNCONFIRMED] | inventory space |
| Resupply | map and bodies | timer perk: 30 s / 25 s [O] | bought per round | none | traders, loot |
| Input | dedicated key, gun in hand [W] | dedicated keys, gun in hand | drawn, 1.0 s [D] | drawn | drawn |
| Cook | no [UNCONFIRMED] | yes [O] | no [UNCONFIRMED] | removed 2023 [O] | UNCONFIRMED |
| Arc preview | none found | none found | line-up reticle only [O] | none found | UNCONFIRMED |
| Frag fuse | about 3 s [G], +0.2 s in 2022 [O] | about 3 s [G] | UNCONFIRMED | 4 s, 2 s after first bounce [O] | 3 to 5 s [G] |
| Frag radius | 2.5 wu [O] | mid ring 3.8 m [O] | 350 units, about 6.7 m [D] | UNCONFIRMED | 3 to 7 m [G] |
| Frag damage vs health | UNCONFIRMED | 225 inner, 150 mid vs 150 [O] | 99 vs 100; 57 armoured [D][G] | UNCONFIRMED | fragments |
| Flash rule | no flash | 3 range bands: 3.5 / 2.75 / 1 s [O] | distance, facing, line of sight; up to 5 s [G][O] | distance, facing, environment, angle; full or nothing [O] | distance, facing, eyewear [G] |
| Smoke duration | UNCONFIRMED | UNCONFIRMED | about 20 s [G] | UNCONFIRMED | UNCONFIRMED |

## What this suggests for Space Pirates

Options only. The map's settled points (thrown from its own key with the gun in hand, a limited count, HUD shows it, crew react but never throw) match Halo Infinite and Call of Duty, so those two are the closest models for input and Counter-Strike and Siege are the closest for flash and smoke rules.

**Carry shape.**

- *Halo shape*: up to two kinds, two of each, one key to switch kind. Needs a switch key and a HUD that shows the selected kind.
- *Call of Duty shape*: two fixed slots (one damaging, one not), each on its own key, no switching. The Loadout picks the kind per slot. Three grenades into two slots means frag is the "lethal" and flash or smoke is the "tactical" choice.
- *Counter-Strike shape*: one of each kind, flat cap on the total. Simplest to explain; no Loadout choice at all until more kinds exist.
- Every reference keeps the total at 2 to 4. None gives more than two frags.

**Supply.** Three models: none within a round (Siege, Counter-Strike), found aboard (Halo: map and bodies; Tarkov: loot), or a recharge timer (Call of Duty, and only as a paid perk). 343's spam complaint arose in the game where grenades are picked up freely.

**Cook or no cook.** Call of Duty keeps cooking. Ubisoft removed it as the main cause of frags being overpowered, and replaced it with "the first bounce shortens the fuse", which still rewards a placed throw. Halo and Counter-Strike never had it. Against AI crew the counterplay argument is weaker (crew do not complain), but cooking also decides whether a crew flee-the-grenade reaction ever has time to play.

**Frag numbers to start a prototype from.** Fuse 3 to 4 s from release (Halo about 3 s, Siege 4 s, Tarkov F-1 3.5 s). Two or three rings instead of a smooth curve, as MWIII publishes: a small lethal core, a mid ring out to roughly 4 m that hurts badly, an outer edge at roughly 6 to 7 m (CS2's 350 units, Halo's 2.5 wu at the 10 ft reading). Whether the core one-shots is the real decision: MWIII's does (225 vs 150), CS2's deliberately does not quite (99 vs 100). The Pirate has 6 hit points and crew have small pools, so almost any frag damage will one-shot crew; the open question is what it does to the Pirate.

**Self-damage.** Tarkov: total. Call of Duty: yes for flash unless Tac Mask is worn. Halo: turns the blast into movement instead (knockback only when airborne). Nothing found says any of these games spares the thrower from his own frag.

**Blast and cover.** Tarkov simulates fragments, so cover works exactly as for bullets. CS2 computes from the true blast position. Siege lets frags hurt through thin and destructible surfaces and treats that as a feature. A line-of-sight test from the blast point is the cheapest version of all three.

**Flash rule.** Two published designs: Siege's (full blind or nothing; duration from distance, facing, environment) and MWIII's (three distance bands with fixed durations: 3.5 / 2.75 / 1 s). Both studios moved toward predictability. For crew, the same test (line of sight to the flash, facing within some angle, distance band) gives a blind time per crew member; no reference documents what its AI does while blind, so that part is original design.

**Smoke rule.** The lesson from Valve's patch list is that smoke must be the same thing for sight, for AI and for every renderer effect: one volume, opaque both ways, with reflections, radar, silhouettes and fire all occluded by it. For a game with AI crew the cheap, symmetric form is a volume that blocks the crew's sight test and is also truly opaque on screen, so neither side sees through. Halo's Shroud Screen adds that it also blanks the tracker of anyone inside. Numbers available: about 20 s duration (CS2, wiki), a 1 to 3.5 s fuse before it starts (Tarkov, fan site), a minimum fuse so it cannot pop while still wedged (Valve).

**Warning the victim.** No developer source for an on-screen grenade marker was found. What the sources do show is warning by sound (pin-pull, bounce, a shouted callout) and by time (343 and Ubisoft both lengthened or fixed the fuse so a landed grenade can be reacted to). For crew, that maps to: a grenade is heard when it lands, and the fuse after landing is long enough for a flee reaction to be visible.

**HUD.** Halo and Call of Duty both put the grenade icon and count beside the weapon and ammo readout, with the selected kind as the icon. Exact corner was not confirmed for either.

## Not found

- Halo Infinite: absolute frag fuse; frag damage and inner radius; plasma, spike and dynamo numbers; throw speed and throw duration; what is locked out during a throw; campaign carry limits; HUD corner; whether campaign AI flee grenades (they visibly do, but no source was opened); Shroud Screen radius and duration.
- The Halo world-unit scale conflict (1 ft vs 10 ft per wu) left open by the two earlier notes.
- Call of Duty: MW2019 default counts and key bindings; frag fuse; outer ring and inner radius; self-damage rule; flash range-band distances; whether facing matters; all smoke numbers; any official description of the grenade danger indicator or of grenade throwback outside the Ordnance Gloves line.
- Counter-Strike 2: HE and flashbang fuse times; the flashbang angle and distance table; smoke bloom time and size; an official statement of the carry rule (only the convar name is official); Valve's "Responsive Smokes" announcement text (page did not render).
- Rainbow Six Siege: frag damage and radius; counts per gadget; stun durations; every smoke number; an official source for the frag warning icon.
- Tarkov: any developer-published number; the carry and key rules; flash durations; what flash and smoke do to AI.
- Hunt: Showdown: not researched (Tarkov taken as the extraction shooter).
- For every game: what a flash does to AI enemies, and whether AI see through smoke. Only Tarkov's two patch-note lines touch it.

## Sources

Official:

- 343 Industries, Sandbox Balance Updates, Winter Update: https://www.halowaypoint.com/news/sandbox-balance-updates-winter-update
- 343 Industries, February Update Preview (2023): https://www.halowaypoint.com/news/february-update-preview
- 343 Industries, Sandbox Updates, Season 3: https://www.halowaypoint.com/news/sandbox-updates-season-3
- 343 Industries, Sandbox Update, Halo Infinite: https://www.halowaypoint.com/news/sandbox-update-halo-infinite
- 343 Industries, Inside Infinite, January 2021: https://www.halowaypoint.com/news/inside-infinite-january-2021
- Activision, The Basics of Call of Duty: Modern Warfare: Loadouts (2019): https://blog.activision.com/call-of-duty/2019-10/The-Basics-of-Call-of-Duty-Modern-Warfare-Loadouts
- Activision (via Blizzard news), Gear Up: Modern Warfare III Loadouts: https://news.blizzard.com/en-us/blizzard/24025488/gear-up-modern-warfare-iii-loadouts-what-you-need-to-know
- Activision, Modern Warfare III launch patch notes: https://www.callofduty.com/patchnotes/2023/11/call-of-duty--modern-warfare-iii-launch-patch-notes
- Activision, Modern Warfare III Season 3 patch notes: https://www.callofduty.com/patchnotes/2024/04/call-of-duty-modern-warfare-iii-season-3-patch-notes
- Valve, Counter-Strike 2 release notes, read through the Steam news feed for app 730 (`ISteamNews/GetNewsForApp`, feed `steam_community_announcements`); each note is cited above by its date. Browsable at https://store.steampowered.com/news/app/730
- Ubisoft, Y8S4 Designer's Notes: https://www.ubisoft.com/en-us/game/rainbow-six/siege/news-updates/1BZt0t9asNHvdTBHU9OUGZ/y8s4-designers-notes
- Ubisoft, Y8S3 Designer's Notes: https://www.ubisoft.com/en-us/game/rainbow-six/siege/news-updates/2Btj0mP7e7gVKIODGSLuiX/y8s3-designers-notes
- Ubisoft, Y6S3 Pre-Season Designer's Notes: https://www.ubisoft.com/en-gb/game/rainbow-six/siege/news-updates/2zsUnVBdSsc10rirkPl1K5/y6s3-preseason-designers-notes
- Battlestate Games patch notes 0.13.0.0, 0.13.0.4 and 0.13.1.0, as reproduced by GINX (official page not opened): https://www.ginx.tv/en/patch-notes-14

Game data:

- Counter-Strike 2 `weapons.vdata`, SteamDatabase GameTracking-CS2 mirror of the shipped files: https://github.com/SteamDatabase/GameTracking-CS2/blob/master/game/csgo/pak01_dir/scripts/weapons.vdata

Wiki (Halopedia):

- HINF:Control schemes: https://www.halopedia.org/HINF:Control_schemes
- Dynamo grenade: https://www.halopedia.org/Dynamo_grenade
- Shroud Screen: https://www.halopedia.org/Shroud_Screen
- M9 fragmentation grenade: https://www.halopedia.org/M9_fragmentation_grenade
- Plasma grenade: https://www.halopedia.org/Type-1_plasma_grenade
- Heads-up display: https://www.halopedia.org/Heads-up_display

Fan guides and fan sites (unconfirmed tier):

- csdb.gg, Grenades and Utility Guide (CS2): https://csdb.gg/guides/grenade-guide/
- MeinMMO, stun or flash in Modern Warfare and Warzone (reports TheXclusiveAce's measurements): https://mein-mmo.de/cod-modern-warfare-warzone-stun-or-flash/
- tarkovforge, grenades table: https://tarkovforge.com/grenades
- eft-ammo, Tarkov grenade guide: https://eft-ammo.com/wiki/escape-from-tarkov-grenade-guide-13-grenade-tips-and-tricks-from-sherpas
- Discarded as unreliable: ludo.guide Tarkov grenade page (names grenades that are not in the game).

Earlier research in this repository:

- `docs/research/halo-infinite-feel-reference.md` on branch `research/halo-infinite-feel-reference`
- `docs/research/reference-shooter-numbers.md` on branch `research/reference-shooter-numbers`
