# Reference values: Halo Infinite movement and pistol feel

Resolves [#31](https://github.com/benjr70/space-pirates/issues/31) (part of #29). Researched 2026-09-28.

Purpose: give the movement prototype a known starting point instead of guesses. Every number below is tagged with where it came from. **Official** means 343 Industries (Halo Support / Halo Waypoint patch notes and articles). **Halopedia** is the community wiki, which is usually careful but rarely cites frame data. **Community** means a player measurement or a guide claim that no official source confirms. **Unknown** means no public number was found; the suggested value is our own guess and is marked as such.

Halo Infinite's Forge documents its own scale: **1 world unit (wu) = 1 foot** (official, Community Forge Map Requirements). Conversions to metres below use 0.3048 m/ft.

## Project baseline (for the translation column)

- Scale: 1 m per tile.
- Walk 5.16 m/s, sprint multiplier 1.55 (= 8.0 m/s), jump velocity 4.5 m/s (about 1.03 m apex under 9.8 m/s² gravity).
- Capsule 1.8 m tall.
- Player 6 hit points; crew have small hit-point pools.
- Pistol fires projectiles, not hitscan.

## Findings

### Sprint speed relative to walk

- Halopedia (Sprint): in Halo Infinite "sprinting [is] only about 8% faster than normal walking", substantially slower than Halo 5. No citation given on the page. [1]
- Community (XboxEra tech-preview writeup, Aug 2021): "approximately a 9% difference between sprinting and normal player movement". [2]
- Official: the Technical Preview Outcomes post says only that "the current speed and balance is playing well"; no number. [3]
- Official: sprint no longer delays shield recharge (Halopedia notes this as a change from Halo 5). Sprinting shows on the motion tracker; Season 2 added an "edge" indicator for sprinting players just outside tracker range. [1][4]
- Halo Infinite also has a separate slow **walk** on PC ("Player Walk Throttle Scale" setting), distinct from crouch. [5]

Conclusion: sprint is roughly **1.08–1.10× walk**. The project's 1.55 is far outside Halo's feel; Halo gets its "swift" feel from a high base speed, not from sprint.

### Sprint FOV change

- **Unknown.** Halo Infinite exposes a single FOV slider (default 78, range 65–120) and a separate weapon-offset setting; no official or wiki source documents a sprint FOV kick. [6] Visually, sprint adds a mild "wind streak" and distortion effect that can be disabled in Accessibility settings (official settings guide), which is the game's sprint feedback rather than an FOV change. [5]

### Slide

- Official: slide requires sprint; "Maintain Sprint" auto-resumes sprint after "crouch sliding". [5]
- Official (Season 2 patch notes, May 2022): "Velocity gained from landing into a slide on a ramp has proportional reduction based on fall height." Developer note: "the output speed of a slide has a scaling reduction based on your incoming vertical speed". This confirms the slide is a velocity-preserving state whose entry speed comes from the player's current velocity (which is why "curb slides" and ramp boosts exist), not a fixed-length dash. [4]
- Official (Winter Update, Nov 2022, via Pure Xbox summary of the Waypoint blog): "snap sliding" physics bug fixed. [7]
- Duration, base speed and decay curve: **unknown.** No official or measured figure found. Community guides only describe it as "a short distance". [1][8]

### Clamber

- Official (Community Forge Map Requirements): "Jump height without using clamber is 8 units" (2.44 m); "Comfortable clamber height is 12 units" (3.66 m); overhead clearance needed to jump without a head bonk is 18 wu (5.49 m); grapple range 80 wu. Design rules: "No toe clambers (clambering on geometry that's very short)" and keep a "buffer zone between clamber and no clamber". [9]
- Official: "Auto Clamber" setting mantles automatically "while airborne when moving near an accessible ledge". [5]
- Community: during the clamber animation "players can't do anything" (weapon down, vulnerable). [10]
- Animation time: **unknown.** One guide claims "0:50 seconds", which is ambiguous and unverified. [10]
- Community (XboxEra tech-preview writeup): 343 added "a new step mechanic which results in quicker jumps up smaller steps" so that short ledges do not trigger a full clamber; this is the "Step Jump" option in the settings guide. [2][5]

Ratio worth carrying over: comfortable clamber height is 1.5× the unassisted jump height, and there is an explicit dead band above jump height where you must clamber.

### Crouch

- Official: crouch is a hold-or-toggle input; sliding is "crouch/slide" on the same button. [5]
- Community: crouching keeps the player off the motion tracker while moving. [11]
- Crouch height and crouch movement speed: **unknown.** No official, wiki or measured number found.

### Melee

- Halopedia: Infinite "takes on the Halo 3 mechanics of the basic melee" - two hits kill a fully shielded Spartan, one hit kills an unshielded one. Weapon clashes ("clangs") deal half damage and can happen twice. Assassination animations were removed; a melee from behind is a "back smack". [12]
- Halopedia (general melee rule, all games): "A melee from behind ... is sufficient to kill virtually any enemy in the games, regardless of how much shielding or armor they happen to be wearing". [12] Community guides for Infinite state the same: a hit to the back is an instant kill regardless of shields. [13]
- Official (Season 2 patch notes): global melee damage reduced 10% (multiplayer and campaign); "Forward input ignored after a successful lunge for 0.2 seconds"; aim "snaps" toward the target on a successful lunge; the "clang" rule that let the higher-HP player win a simultaneous melee was removed so both players take damage and trades happen. [4]
- Community (Reddit user S3xyTrap, reported by ScreenRant): time for two melee hits depends on the held weapon - Sidekick 1.00 s, Skewer 1.10 s, Battle Rifle 1.15 s, Shock Rifle 1.25 s. So one melee cycle is roughly 0.5–0.6 s. [14]
- Lunge range: community guides say "a foot or two" of lunge when close, or "approximately 3 meters" maximum; neither is measured. [11][15] Official notes only say lunge "snapping" was improved. [4]

### Mk50 Sidekick (starting sidearm)

- Halopedia: semi-automatic; 12-round magazine (Striker variant 14); reserve 84 total (48 in multiplayer); kinetic damage; 1.40× zoom; headshot-capable; "mild amount of spread and vertical recoil"; bloom when fired rapidly. Kills a fully shielded Spartan in **7–10 shots: 6 to break shields, then 4 body shots or 1 headshot** (so a perfect kill is 7). [16][17]
- Halopedia: reload is "very rapid" and has two lengths - with rounds left in the magazine the player just seats a new magazine; from empty the slide release is added. No times given. [16]
- Community: optimal time-to-kill about **0.6 s** (7 shots); implies roughly 0.1 s between shots, about 600 RPM, but this is derived from an unverified chart, not an official rate. [18]
- Fire rate (RPM), reload time in seconds, damage per shot: **unknown** officially. An official Feb 2023 patch note confirms "Semi-automatic weapons, such as the Sidekick, now appear to fire at a correct rate from the perspective of other players", but gives no rate. [19]
- Hitscan vs projectile: no official statement. Community guides treat the Sidekick and other kinetic ballistic weapons as hitscan and the plasma/heavy weapons as projectile. [20]

### Shields (for context on shots-to-kill)

- Official (Halo Support, Shields in Halo Infinite): shields absorb all damage until depleted; "If you go without taking damage for about five seconds", shields and health replenish. Once shields are down, headshots do extra damage. [21]
- Official: exact shield and health point values are not published. Halopedia's Health page has no Infinite numbers either. [22]

## Suggested starting values for this project

Scale is 1 m per tile, capsule 1.8 m. Halo's Spartan is taller (Forge numbers imply a 2.1 m-class character; jump apex 2.44 m), so height-based numbers are given as ratios to the player's own jump/height, then converted.

| Parameter | Halo Infinite reference | Source class | Suggested start here | Note |
|---|---|---|---|---|
| Walk speed | (not published; feel is "swift") | - | keep 5.16 m/s | Base speed carries the feel, not sprint |
| Sprint multiplier | ~1.08–1.09× walk | Halopedia / community | **1.10** (5.7 m/s) | Current 1.55 is Halo 5-like, not Infinite-like |
| Sprint FOV change | none documented | unknown | **0°** (or at most +3°) | Use a subtle wind-streak/bob instead |
| Sprint shield/regen penalty | none | official (S2 notes, Halopedia) | none | If the project adds regen later |
| Slide entry | requires sprint | official | require sprint | |
| Slide speed curve | entry = current velocity, scaled down with fall speed | official (S2 notes) | start at 1.15× sprint, ease-out to walk over the slide | Curve shape is a guess |
| Slide duration | unknown | unknown | **0.6 s** | Guess; tune |
| Unassisted jump apex | 8 wu = 2.44 m (about 1.15× character height) | official | keep 1.03 m for now | Halo jumps are ~2.4× ours relative to height; revisit with the prototype |
| Clamber trigger band | > jump apex up to 12 wu = 3.66 m (1.5× jump apex) | official | **1.1 m – 1.6 m** ledge height | Scaled from our 1.03 m apex; add a small "step" band below it |
| Clamber dead band | "buffer zone between clamber and no clamber"; "no toe clambers" | official | do not clamber ledges below ~0.6 m; step up instead | |
| Clamber animation | unknown, player locked out | community | **0.5 s**, weapon lowered, no input | Guess |
| Crouch height | unknown | unknown | **1.2 m** capsule (2/3 of 1.8 m) | Guess |
| Crouch speed | unknown | unknown | **0.5× walk** (2.6 m/s) | Guess; Halo crouch also hides from radar |
| Melee damage (front) | 2 hits kill full shields; 1 hit unshielded | Halopedia | **3 HP** per hit (2 hits kill a 6 HP player) | Crew with ≤3 HP die in one |
| Melee back hit | instant kill regardless of shields | Halopedia / community | **kill** when attacker is inside a ~120° cone behind the target's facing | Cone width is a guess |
| Melee cycle | ~0.5–0.6 s per hit | community | **0.55 s** | |
| Melee lunge range | "a foot or two" up to "~3 m", unmeasured | community | **2.0 m** trigger, snap facing toward target | 0.2 s forward-input lock after a lunge (official) |
| Melee trade | both take damage, no "higher HP wins" rule | official (S2 notes) | resolve both hits | |
| Pistol magazine | 12 | Halopedia | **12** | |
| Pistol reserve | 84 total (48 MP) | Halopedia | 48 | |
| Pistol fire rate | semi-auto; ~0.1 s/shot implied by 0.6 s TTK | community | **0.12 s** min interval (500 RPM) | Semi-auto, no auto-fire |
| Pistol reload | "very rapid"; tactical shorter than empty | Halopedia | **1.2 s** tactical, **1.6 s** empty | Times are guesses |
| Pistol shots to kill | 7 perfect / 10 body vs full shields | Halopedia | **1 HP** body, **2 HP** head: 6 body or 3 head to kill a 6 HP player | Keeps the "many small hits" feel |
| Pistol projectile speed | effectively hitscan | community | **80 m/s** | 15 m room crosses in <0.2 s; feels hitscan at ship scale |
| Pistol bloom | spread grows when fired rapidly | Halopedia | small bloom, resets in ~0.3 s | |
| Shield regen delay | ~5 s without damage | official | 5 s | Only if regen is added |

## Sources

1. Halopedia, "Sprint" - https://www.halopedia.org/Sprint
2. XboxEra, "Halo Infinite - Did 343 accomplish the impossible?" (Aug 2021, tech-preview writeup; now hosted at playday.one) - https://playday.one/2021/08/06/halo-infinite-did-343-accomplish-the-impossible/
3. Halo Waypoint, "Technical Preview Outcomes" (343 Industries) - https://www.halowaypoint.com/news/technical-preview-outcomes
4. Halo Support, "Halo Infinite Season 2: Lone Wolves - Patch Notes" (343 Industries) - https://support.halowaypoint.com/hc/en-us/articles/5890104346644-Halo-Infinite-Season-2-Lone-Wolves-Patch-Notes
5. Halo Support, "Guide to Halo Infinite Game Settings" (343 Industries) - https://support.halowaypoint.com/hc/en-us/articles/4407649252116-Guide-to-Halo-Infinite-Game-Settings
6. Halo Support, "How to Change the Field of View (FOV) Setting in Halo Infinite" - https://support.halowaypoint.com/hc/en-us/articles/4408359189652-How-to-Change-the-Field-of-View-FOV-Setting-in-Halo-Infinite
7. Pure Xbox, "Halo Infinite Details Sandbox Balance Changes Coming In Winter Update" (summary of the Halo Waypoint blog, Nov 2022) - https://www.purexbox.com/news/2022/11/halo-infinite-details-sandbox-balance-changes-coming-in-winter-update
8. Inven Global, "How pros are using movement in Halo: Infinite" - https://www.invenglobal.com/articles/15789/guide-how-pros-are-using-movement-in-halo-infinite
9. Halo Support, "Community Forge Map Requirements" (343 Industries) - https://support.halowaypoint.com/hc/en-us/articles/14796740242708-Community-Forge-Map-Requirements
10. GamesKeys, "Turn Off Auto Clamber in Halo Infinite" - https://gameskeys.net/turn-off-auto-clamber-in-halo-infinite/
11. NME, "Halo Infinite: 5 tips for beginners in multiplayer" - https://www.nme.com/guides/gaming-guides/halo-infinite-5-tips-for-beginners-in-multiplayer-3096790
12. Halopedia, "Melee" - https://www.halopedia.org/Melee
13. Pro Game Guides, "How to kill an Enemy Spartan from Behind with a Melee Attack in Halo Infinite Multiplayer" - https://progameguides.com/halo/how-to-kill-an-enemy-spartan-from-behind-with-a-melee-attack-in-halo-infinite-multiplayer/
14. ScreenRant, "Halo Infinite Weapons Confirmed To Have Different Melee Speeds" (reporting Reddit user S3xyTrap's test) - https://screenrant.com/halo-infinite-different-weapon-melee-speeds-test-video/
15. DanielDigitalDiary, "How to Lunge Melee in Halo Infinite" - https://danieldigitaldiary.com/how-to-lunge-melee-in-halo-infinite/
16. Halopedia, "Mk50 Sidekick" - https://www.halopedia.org/Mk50_Sidekick
17. Halopedia, "Sidekick" and "Striker Sidekick" - https://www.halopedia.org/Sidekick , https://www.halopedia.org/Striker_Sidekick
18. Blueberries.gg, "Halo Infinite TTK Chart" (community chart; page did not render for verification) - https://www.blueberries.gg/halo/halo-infinite-ttk/
19. Halo Infinite Tracker, patch note list, Feb 15 2023 entry (quoting official notes) - https://tracker.gg/halo-infinite/articles/halo-infinite
20. GameRant, "How To Use Every New Weapon In Halo Infinite's Multiplayer" - https://gamerant.com/halo-infinite-multiplayer-new-weapons-tips/
21. Halo Support, "Shields in Halo Infinite" (343 Industries) - https://support.halowaypoint.com/hc/en-us/articles/24284987877524-Shields-in-Halo-Infinite
22. Halopedia, "Health" - https://www.halopedia.org/Health
