# Research note: how reference shooters structure weapon attachments

Researched 2026-11-24. Question: how do shooters with weapon attachments structure them, what do the attachments do in numbers, how is the change shown on the loadout screen, and what do the developers treat as the main mistakes?

Games covered: Call of Duty (Modern Warfare 2019 to Black Ops 6), Battlefield 4 and 2042, Escape from Tarkov, Halo Infinite, plus Hunt: Showdown for its suppressor sound numbers.

## How to read the sources

Each claim carries a source tag.

- **[P]** primary: the developer's or publisher's own blog, patch notes or support page.
- **[W]** community wiki. Used where the wiki transcribes in-game text or stat cards, or cites datamined values. Treated as high trust for transcriptions and medium trust for analysis.
- **[S]** secondary press. Used only where marked.

Full URLs are in [Sources](#sources). Every number that could not be traced to a primary or transcribed in-game source is listed in [Numbers that could not be confirmed](#numbers-that-could-not-be-confirmed).

## Summary table

| Game | Slot types | Slots filled per weapon | Shared or per weapon | Numbers shown to player |
|---|---|---|---|---|
| CoD Modern Warfare (2019) | 8 attachment areas plus a perk | 5 | Per weapon | Six bars, pro and con text, no numbers |
| CoD Black Ops Cold War | Same family of types | 5, or 8 with Gunfighter | Per weapon and faction | Percent on every pro and con |
| CoD Modern Warfare II (2022) | Receiver plus the usual types | 5 | Platform pool plus a universal pool | Bars, pro and con text, tuning sliders |
| CoD Modern Warfare III (2023) | As MWII | 5 | Some sharing | Pro and con text, plus a Detailed Statistics view |
| CoD Black Ops 6 | 11 types, 8 or 9 per weapon class | 5, or 8 with Gunfighter | Optics shared per class, the rest per weapon | Four bars, plus a numeric Details toggle |
| Battlefield 4 | Optic, accessory, barrel, underbarrel | Up to 5 customisable points | Same attachment types across classes, unlocked per weapon | Text description with a percent |
| Battlefield 2042 | Sight, barrel, ammo or magazine, underbarrel | 4 | Not confirmed | Tips on each attachment |
| Escape from Tarkov | A slot tree per weapon, 20-odd part categories | Varies by weapon | Parts fit by platform and mount | Numeric stat list per part |
| Halo Infinite | None | 0 | Fixed variants of a base weapon | One-line description |
| Hunt: Showdown | None | 0 | Fixed variants, plus ammo types | Description and stat card |

## Call of Duty: Gunsmith

### Slots and sharing

- **Modern Warfare (2019).** The player fills up to five of the available areas: "how many of the five augmentations you've added". The areas are "the muzzle, lasers, optic, stock, rear grip, magazine, underbarrel, and barrel". A weapon perk can take the fifth slot. [P: Activision, Loadouts basics] An earlier post lists nine categories by counting Perks. [P: Activision, Customization] Attachments unlock on each weapon's own progression path. [P: Activision, Customization]
- **Black Ops Cold War.** Five attachments by default, eight with the Gunfighter wildcard, no gun perks. [W: CoD wiki, Gunsmith] Attachments come in NATO and Warsaw Pact sets, and the same attachment carries slightly different numbers on different guns. [W: CoD wiki, Agency Suppressor, Field Agent Grip]
- **Modern Warfare II (2022).** Five attachments. Weapons sit on a Weapons Platform. Levelling a platform unlocks two kinds of attachment. Platform attachments are "Receivers, Barrels, Stocks, Rear Grips, and Magazines", "sharable within the Platform across all Receivers". Universal attachments are "Optics, Ammunition, Underbarrels and Foregrips, and Muzzles", usable "across ALL weapons that are able to equip them", so "you only need to unlock them once". [P: Infinity Ward, Gunsmith first look] This game also had Weapon Tuning, where each attachment on a max-level weapon could be slid between two traits. [W: CoD wiki, Gunsmith]
- **Modern Warfare III (2023).** Tuning was removed and platforms are no longer named, though some weapons still share attachments. [W: CoD wiki, Gunsmith]
- **Black Ops 6.** Eleven attachment types exist: Optic, Muzzle, Barrel, Underbarrel, Magazine, Comb, Rear Grip, Stock, Laser, Fire Mods, Stock Pad. Each weapon class uses eight or nine of them. A weapon has five Attachment Points, or eight with Gunfighter. "Each weapon type has more available Attachment types than points." Optics are shared across a weapon class. Every other type is "unique to the weapon in question in terms of unlocking and usage". [P: Treyarch, BO6 weapons blog]

The through-line: the slot count stays at five while the number of slot types stays at eight or nine. The choice the player makes is which types to leave empty.

### What each slot does

Black Ops 6 gives the clearest official statement of what each type is for. [P: Treyarch, BO6 weapons blog]

| Slot | Stated purpose | Stated cost |
|---|---|---|
| Optic | Accuracy. Sometimes improves gun kick | "More powerful scopes ... may reduce ADS Speed" |
| Muzzle | "reduce or control recoil" | None stated |
| Barrel | "improve damage range and velocity" | None stated |
| Underbarrel | Foregrips reduce recoil and sway. Launchers add an alt-fire | None stated |
| Magazine | Extended mags add rounds. Fast mags improve handling | Extended: "sometimes at the expense of Handling". Fast: "fewer bullets" |
| Stock | Light stocks add movement speed. Heavy stocks add flinch resistance | None stated |
| Rear Grip | ADS speed, sprint-to-fire, slide-to-fire, dive-to-fire | None stated |

### Magnitudes

**Modern Warfare (2019): no official numbers.** The game showed pros and cons as text and six bars only. Example: the Monolithic Suppressor lists "+ Sound Suppression, + Damage Range" against "- Aim Down Sight Speed, - Aim Walking Steadiness", with no figures. [W: CoD wiki, Monolithic Suppressor]

**Black Ops Cold War: the in-game cards carry percentages.** These rows are wiki transcriptions of those cards. [W: CoD wiki, per attachment page]

| Attachment | Slot | Gain | Cost |
|---|---|---|---|
| Agency Suppressor | Muzzle | +100% muzzle flash concealment, +7% vertical recoil control | -20% to -33% effective damage range, -15% to -30% bullet velocity, depending on weapon |
| Field Agent Grip | Underbarrel | +14% to +20% horizontal recoil control, +2% to +8% vertical | -26% to -30% shooting move speed |
| Raider Stock | Stock | +30% sprint-to-fire, +40% aim walking movement speed | -30% hip fire accuracy |
| Fast Mag | Magazine | +18% to +23% reload quickness | None |

**Modern Warfare III: patch notes give step sizes and timings.** [P: Sledgehammer, MWIII launch-window, Season 1 and Season 2 patch notes]

- Optic aim-down-sights penalties, before and after one tuning pass: dots and holographics 30 ms to 0 ms, 2.5x optics 70 ms to 15 ms, 4x and hybrids 40 ms to 20 ms, scopes 100 ms to 50 ms.
- For scale, base aim-down-sights times in the same notes: 190 ms to 230 ms on submachine guns (Season 1), and 390 ms raised to 470 ms on one sniper rifle conversion kit (Season 2).
- High Velocity ammunition: bullet velocity multiplier cut from 1.2x to 1.15x, and from 1.3x to 1.17x on sniper rifles.
- Single-attachment adjustments move in steps of 5% to 14%: "Increased gun kick control benefit by 7%" on an integrated suppressor barrel, "Added 9% aim down sights time benefit" on a short barrel, "Decreased hipfire spread benefit by 14%" on a muzzle.

**Suppressor sound.** Call of Duty models the suppressor as hiding the shooter's mini-map ping. Black Ops 6 lists "firing ping on the Mini-Map" as part of the Firepower stat. [P: Treyarch, BO6 weapons blog] No Call of Duty source found gives an audible distance in metres.

**Magazine size against reload time.** No official figure was found. Black Ops 6 states the direction only (see table above).

### How the loadout screen shows the change

- **Modern Warfare (2019).** "A bar chart displays six stats": "accuracy, damage, range, fire rate, mobility, and control". Hovering an attachment shows "a brief description, the pro and con of using it" and the bar change. [P: Activision, Loadouts basics]
- **Black Ops Cold War.** Percentages on each pro and con (see table above).
- **Modern Warfare III.** "Detailed Statistics are now viewable while choosing an Attachment in the Gunsmith." [P: Sledgehammer, MWIII patch notes]
- **Black Ops 6.** Four grey bars, Firepower, Accuracy, Mobility and Handling, in the corner of the attachment menu. Each bar is defined by the stats under it: Handling is "Reload quickness (both with rounds and empty), ADS Speed, Sprint to Fire Time, and Weapon Swap Speed". A "Details" toggle shows "how each attachment affects the weapon specifically, and numerically". [P: Treyarch, BO6 weapons blog]

## Battlefield 4

### Slots and sharing

Primary weapons have "up to five customizable points" and sidearms three. [W: Battlefield wiki, Customization] The wiki's attachment infoboxes name the slots Optic, Accessory (also labelled Secondary), Barrel and Underbarrel. There is no magazine slot and no stock slot. The same attachment types serve every weapon class, with the same effect. Each weapon unlocks its own copy by kills: the Compensator costs 30 kills on a personal defence weapon and 120 on an assault rifle. [W: Battlefield wiki, Compensator]

### Magnitudes

Battlefield 4 printed percentages in its attachment descriptions, and the community site Symthic published the underlying values. All rows are from the Battlefield wiki, which quotes both.

| Attachment | Slot | Gain | Cost |
|---|---|---|---|
| Heavy Barrel | Barrel | 50% lower maximum aimed spread | 33% more recoil |
| Muzzle Brake | Barrel | 10% less vertical recoil | 12.5% more spread increase per shot |
| Compensator | Barrel | 25% less horizontal recoil | 30% more spread increase per shot |
| Suppressor | Barrel | Quieter shot, less muzzle flash, hidden on mini-map when firing | Bullet velocity down "about 30-50%", always below 360 m/s. More bullet drop. Worse hip fire |
| Flash Hider | Barrel | No muzzle flash | 17% slower spread recovery while aiming, added in a 2015 patch |
| Angled Grip | Underbarrel | 33% less first-shot recoil | 33% slower spread recovery (all grips) |
| Stubby Grip | Underbarrel | 20% less spread increase per shot, 17% lower maximum aimed spread | 33% slower spread recovery (all grips) |
| Laser Sight | Accessory | 33% reduction in hip fire penalty | Visible beam |

Three of these have conflicts between sources. They are listed under unconfirmed numbers.

Two structural points are worth noting. Battlefield 4 pairs each gain with a cost on a different axis: recoil is bought with spread, spread with recoil. And the wiki notes that a Stubby Grip offsets the spread cost of a Muzzle Brake or Compensator, so two sidegrades can combine into a build with little net cost. [W: Battlefield wiki, Stubby Grip]

### Loadout screen

Each attachment has a one-sentence description with the percent in it, for example: "Improves Stability by reducing muzzle drift by 25%, but adds a 30% penalty to the Accuracy of rapid fire." [W: Battlefield wiki, Compensator, quoting the Battlelog description]

## Battlefield 2042

### Slots and sharing

Four slots, laid out as a cross: top rail (iron sights and optics), barrel (suppressors, compensators, muzzle brakes), ammo (extended magazines and alternate ammunition types) and underbarrel (grips and launchers). The Plus System lets the player swap among the attachments they brought while in the field. Some weapons lack a slot. [W: Battlefield wiki, Plus System] Whether unlocks are per weapon was not confirmed from a source read for this note.

Magazine and ammunition type share one slot, so capacity is traded against round type. Subsonic magazines hold fewer rounds: Update 6.2 raised the MP9 subsonic magazine "from 21 to 25 bullets". [P: DICE, Update 6.2]

### Magnitudes

DICE mostly describes attachment effects in words. The numbers it has published concern suppressors. [P: DICE, Updates 6.0 and 6.2]

Distance beyond which a suppressed shot no longer marks the shooter on the mini-map:

| Build | Before 6.0 | Update 6.0 | Update 6.2 |
|---|---|---|---|
| Light suppressor | 20 m | 40 m | 30 m |
| Light suppressor plus subsonic | 20 m | 20 m | 15 m |
| Heavy suppressor | Any distance | 20 m | 15 m |
| Heavy suppressor plus subsonic | Any distance | Any distance | Any distance |

Heavy suppressor costs, Update 6.2: the PB Heavy Suppressor's damage multiplier went from 0.85x to 0.9x and its bullet velocity multiplier from 0.8x to 0.85x. The Type 4 Heavy Suppressor went from 0.9x to 0.95x damage and 0.75x to 0.8x velocity.

So a heavy suppressor in 2042 costs 5% to 15% damage and 15% to 25% bullet velocity, and a light one buys less stealth for less cost. The stealth is expressed as a distance threshold, which is the closest reference found to a suppressor that cuts how far enemies hear a shot.

### Loadout screen

"Tips on advantages are shown for each attachment" in the Plus menu. [W: Battlefield wiki, Plus System] DICE had to fix these more than once: "Factory and Extended Barrel descriptions now display the correct fire rate changes" (4.0), and "Fixed an issue where minimap stealth bonuses from suppressors and subsonic ammo was not consistent with descriptions and in game behavior" (6.0). [P: DICE, Updates 4.0 and 6.0]

## Escape from Tarkov

### Slots and sharing

Tarkov has no fixed slot count. Each weapon has a tree of mount points, and parts open further mount points. The wiki sorts parts into three groups. [W: Tarkov wiki, Weapon mods]

- **Functional mods:** bipods, foregrips, flashlights, tactical devices, auxiliary parts, muzzle devices (adapters, flash hiders and muzzle brakes, suppressors) and sights.
- **Gear mods:** charging handles, magazines, mounts, stocks and chassis, underbarrel launchers.
- **Vital parts:** barrels, gas blocks, handguards, pistol grips, receivers.

Parts are real-world items that fit by platform and mount, so sharing is by compatibility, not by design. The catalogue is very large: the wiki tables hold 166 flash hiders and muzzle brakes, 81 suppressors, 212 magazines, 259 stocks and 197 barrels.

### Magnitudes

Every part carries a small numeric modifier and the weapon's stats are the sum. The ranges below were counted from the wiki's tables for this note. [W: Tarkov wiki, Weapon mods]

| Part type | Recoil | Ergonomics | Other |
|---|---|---|---|
| Foregrips | -0.5% to -3.5% | -2 to +12 | |
| Flash hiders and muzzle brakes | -0.5% to -20% | -11.5 to +5 | Accuracy -3% to +6% |
| Suppressors | -0.5% to -15% | -2 to -28 | Durability burn +20% to +115%. Heat +5% to +34%. Muzzle velocity +0.2 to +1.5 |
| Stocks and chassis | -0.5% to -35% | -4 to +40 | |
| Barrels | -1% to -19.8% | -45 to +3 | Muzzle velocity -54 to +18.9 |
| Sights (reflex) | none | -1 to -6 | |
| Sights (scopes) | none | -2 to -10 | Magnification up to 7x |
| Magazines | none | -20 to +5 | Capacity 2 to 100. Load and unload speed -35% to +25%. Check speed -75% to +30% |

Worked examples: the Hexagon Wafflemaker suppressor is -5% recoil, -22 ergonomics, +75% durability burn. The SIG SRD9 suppressor is -1% recoil, -5 ergonomics, +50% durability burn.

Ergonomics is the common cost. It sets "the speed that the player aims down their sights", the noise made when aiming, and stamina drain while aimed. [W: Tarkov wiki, Performance modifiers] So Tarkov's central trade is recoil against handling, paid through one shared currency.

A suppressor in Tarkov lowers recoil. Its costs are ergonomics, weapon wear and heat, not ballistics. How far a suppressed shot carries is not shown to the player, and no number was found.

### Loadout screen

The modding screen lists each stat as a number: ergonomics, accuracy in minutes of angle, recoil, muzzle velocity. [W: Tarkov wiki, Weapon mods and Performance modifiers] The wiki warns that the accuracy stat is shown as a radius, "meaning, the spread is twice as big as expected", a case of a real number with a misleading unit.

## Halo Infinite

Halo Infinite has no attachment slots. It ships weapon variants: a fixed modification of a base weapon with a new name. 343 Industries' support page lists them under the class "Weapon Variant" with a one-line gameplay description each. [P: Halo Support, inventory]

| Variant | Official description |
|---|---|
| MA40 Longshot | "Precision MA40 with improved long-range performance." |
| Convergence Bulldog | "High-capacity magazine with tighter projectile spread and improved range." |
| Impact Commando | "High-capacity magazine with reduced accuracy but increased damage." |
| BR75 Breacher | "Improved stopping power tuned for close-range encounters." |
| Arcane Sentinel Beam | "lower capacity but extremely increased damage" |
| Pursuit Hydra | "Increased long-range proficiency with faster target lock and improved rocket velocity." |
| Pinpoint Needler | "advanced target acquisition and lower supercombine requirement" |

About half of the descriptions name only gains. Variants are campaign rewards and map pickups, not loadout choices, so they do not need to balance against the base weapon. In campaign they are bought with Valor or won from bosses. In multiplayer they appear in a few playlists and in Forge. [W: Halopedia, Special weapons]

343 publishes no numbers for variants. Halopedia reports the Longshot's magazine as 25 against the MA40's 36. [W: Halopedia, via search result, page not read in full]

What it adds for us: a variant is a named bundle of two or three stat changes with one sentence of explanation. That is the cheapest readable form of an attachment.

## Hunt: Showdown

Hunt has no attachment slots either. A silencer is a separate variant of a gun, bought at its own price, and ammunition type is the second lever. It is included here because Crytek published sound distances. [W: Hunt wiki, Update 2.2 notes, a copy of Crytek's patch notes]

- A silenced weapon firing standard ammunition can be located by other players "up to around 100m out".
- A silenced weapon firing Subsonic Ammo is "much harder to pinpoint at medium range up to around 50m already" and becomes "completely inaudible over longer distances".
- An unsilenced weapon with Subsonic Ammo "does not travel across the whole map anymore".
- Subsonic Ammo "increases the extra ammo capacity by around 20%, but reduces muzzle velocity by around 15%".

This update made silencers louder than before. Press coverage of the following update quotes Crytek as wanting "to increase the cost of silence" and reports a 10% damage cut on silenced variants. [S: PC Gamer headline and search summary. The patch notes themselves were not read.]

## What the developers treat as mistakes

### Attachments with unclear or misreported effects

This is the mistake with the most primary evidence.

- DICE on the 2042 overhaul: "it was unclear what the impact on your weapons would be when switching between them." [P: DICE, Update 4.0]
- Sledgehammer corrected the Gunsmith's pro and con labels in nearly every Modern Warfare III season: "Corrected inaccurate Pros and Cons displayed for several Attachments" (Season 1), "Adjusted Pros and Cons for multiple Optic Attachments to reflect their true statistics" (Season 3), "Adjusted descriptions and Pros and Cons for various Attachments to more accurately reflect their true statistics" (Season 4). [P: Sledgehammer, MWIII patch notes] The labels were written by hand and drifted from the tuned values.
- The same studio added a numeric view in the launch window: "Detailed Statistics are now viewable while choosing an Attachment in the Gunsmith." [P: Sledgehammer, MWIII patch notes]
- Treyarch on stats spread over many attachments: "Instead of having a weapon function – such as ADS speed – being affected by multiple attachments that are difficult to keep track of, they are related to a single Attachment type." [P: Treyarch, BO6 weapons blog]

### Too many near-identical choices

- DICE: "Previously, some attachments had effects that were too similar from others". The fix was to give each a distinct pair of axes. The Warhawk Compensator went from "improved horizontal recoil control, reduced vertical recoil control" to "improved recoil control, reduced weapon accuracy". [P: DICE, Update 4.0]
- Treyarch: "the focus for Black Ops 6 is to condense and streamline Attachments so you can easily understand the bonuses". [P: Treyarch, BO6 weapons blog]
- Modern Warfare II's tuning sliders, which multiplied the options on every attachment, were dropped in the next game. [W: CoD wiki, Gunsmith] No developer statement of the reason was found.

### Strictly better attachments

The studios disagree here, and that is the finding.

- Treyarch chose attachments that are almost all upside: "Attachments almost always come with a benefit (Pro), and not a detriment (Con), so you know you're creating a weapon more potent than the base version." It adds that "the more slots used, the better the weapon is likely to perform". [P: Treyarch, BO6 weapons blog] The cost in that design is the slot limit: five points among eight or nine types.
- Battlefield 4 and Cold War attach a cost to nearly every attachment. Where one had none, it was later given one: Battlefield 4's Flash Hider gained its 17% penalty in a 2015 patch. [W: Battlefield wiki, Flash Hider trivia, uncited]
- Crytek judged its silencers underpriced and raised the cost twice, first in sound and then, as reported, in damage. [W: Hunt wiki, Update 2.2] [S: PC Gamer]
- DICE retuned 2042's suppressors twice in two patches, stating the aim as "to promote as much variety in weapons and builds as possible". [P: DICE, Updates 6.0 and 6.2]

### Effects too small to notice

A press report on a YouTuber's measurements found most Black Ops 6 barrels made little practical difference. [S: PC Gamer, not verified against the game] Tarkov's 1% to 3% parts work only because a build stacks ten or more of them.

## Numbers that could not be confirmed

- **Modern Warfare (2019) attachment magnitudes.** The game showed none. Community measurements exist and were not used.
- **Call of Duty suppressor audible range in metres.** Not published. Only the mini-map effect is documented.
- **Magazine size against reload time, any game.** No primary source gives a paired figure. Black Ops 6 states the direction. Cold War's Fast Mag gives +18% to +23% reload quickness with no capacity change. Tarkov gives load speed and ergonomics per magazine, not reload time.
- **Absolute per-attachment values in Modern Warfare III and Black Ops 6.** They exist in the in-game detail views. Only patch-note deltas were read.
- **Battlefield 4 Heavy Barrel recoil cost.** The wiki says 33% more recoil. A search summary of the Prima guide says 50% muzzle climb. Not resolved.
- **Battlefield 4 Muzzle Brake spread cost.** The Muzzle Brake page says 12.5%. The Stubby Grip page refers to "their 30% spread increase penalty" for both barrel devices. Not resolved.
- **Battlefield 4 Stubby Grip.** The in-game description says the automatic fire penalty is reduced by 15%. The Symthic-sourced infobox says 20%.
- **Battlefield 4 Symthic values in general.** Symthic is offline. The wiki's copies were used.
- **Battlefield 4 suppressor velocity.** "About 30-50%" appears in the wiki's general suppressor text and may describe the series more than Battlefield 4 alone.
- **Battlefield 4's fifth customisable point.** Believed to be paint. Not confirmed in a source read here.
- **Battlefield 2042 unlock model, and numbers for grips, barrels, sights and stocks.** The EA notes describe these in words only. 2042 has no stock slot.
- **Tarkov suppressor loudness.** Not shown in game and not found.
- **Tarkov muzzle velocity units.** The wiki column has no unit. Read as percent or m/s with care.
- **Halo Infinite variant numbers.** 343 publishes none. The 36 to 25 magazine figure for the Longshot comes from Halopedia through a search result.
- **Hunt: Showdown unsilenced audible range, and the 10% silencer damage cut.** Crytek's notes say an unsilenced shot crosses "the whole map" without a figure. The damage cut comes from a search summary of press coverage.
- **Why Modern Warfare III removed tuning.** No developer statement found.
- **Design talks.** No conference talk on attachment design was located. The developer positions above come from blogs and patch notes.

## What this suggests for a 12 to 16 attachment catalogue

Our case: four guns, five slots (Sight, Barrel, Magazine, Underbarrel, Stock), all projectile, no damage falloff, every attachment shared and a sidegrade, and a suppressor that cuts how far enemies hear a shot.

1. **Give each slot one job.** With about three attachments per slot, follow the Black Ops 6 rule that a function belongs to one attachment type. A workable split from the references: Sight owns zoom against aim time. Barrel owns bullet velocity, recoil and sound. Magazine owns capacity against reload. Underbarrel owns recoil against hip fire. Stock owns steadiness against movement. Then no stat is the sum of three slots, and the screen stays readable.

2. **Without falloff, the cost pool is small, so guard it.** The reference suppressors and barrels mostly pay in damage range, which we do not have. The costs that remain and have precedent are bullet velocity (Cold War -15% to -30%, 2042 0.75x to 0.85x), aim-down-sights time (MWIII optics 15 ms to 100 ms on a 200 ms to 250 ms base), movement speed while firing (Cold War -26% to -30%), hip fire accuracy (Cold War -30%), spread or spread recovery (Battlefield 4 12.5% to 33%), reload, and capacity. Bullet velocity is a real cost only because our guns are projectile, which makes it the natural price for the suppressor.

3. **Make effects large.** One attachment per slot means nothing stacks, so Tarkov's 1% to 5% steps would be invisible. Battlefield 4 (10% to 50%) and Cold War (7% to 40%) are the right scale. A gain or cost under about 10% is unlikely to be felt.

4. **Pay each gain on a different axis.** Battlefield 4's pattern, recoil bought with spread and spread bought with recoil, is what keeps an attachment a sidegrade and not a smaller upgrade. Check pairs across slots: Battlefield 4's Stubby Grip cancels the Muzzle Brake's cost. With 12 to 16 attachments there are few enough pairs to check every one by hand.

5. **Treat the suppressor as the hardest to price.** Every reference game retuned it after launch. Hunt's figures give a range to start from: locatable to about 100 m, or about 50 m with a second investment. 2042 uses 15 m to 40 m thresholds on much shorter sightlines. Expressing the effect as a distance, as both do, is clearer than a percent. Price it in bullet velocity and handling, and expect to adjust.

6. **Show real numbers generated from the tuning data.** Sledgehammer's repeated pro and con corrections came from hand-written labels. Show each change as a number with a unit ("Aim time 220 ms to 260 ms"), in green or red, computed from the same values the gun uses. Battlefield 4's single sentence with a percent in it is a good model for the short form. If there are bars, define what feeds each one, as Black Ops 6 does, and keep the number beside it.

7. **Use percentages so shared attachments scale across four guns.** Cold War lets the same attachment carry different numbers per gun, which costs readability. With a shared catalogue, prefer one multiplier that reads the same on the Pistol and the Marksman Rifle, and mark the exceptions plainly, as Black Ops 6's Yes, Some, No table does for which class takes which type.

8. **Keep the empty slot a real choice.** Black Ops 6 says a fuller gun is a better gun. An all-sidegrade catalogue says the opposite, so the bare gun should be a sound build and the screen should not present empty slots as unfinished.

9. **Name the trade, not the part.** Halo's variants and Battlefield 4's descriptions both fit an attachment into one sentence that states the gain and the cost. With 16 items, each can have a name and a sentence a player remembers. If two attachments would need the same sentence, cut one: that is the 2042 lesson.

## Sources

Primary:

- Activision, "A Deeper Look at Modern Warfare Customization" (2019): https://blog.activision.com/call-of-duty/2019-09/A-Deeper-Look-at-Modern-Warfare-Customization
- Activision, "The Basics of Call of Duty: Modern Warfare: Loadouts" (2019): https://blog.activision.com/call-of-duty/2019-10/The-Basics-of-Call-of-Duty-Modern-Warfare-Loadouts
- Infinity Ward, "Call of Duty: Modern Warfare II Gunsmith First Look" (2022): https://news.blizzard.com/en-gb/article/23858186/call-of-duty-modern-warfare-ii-gunsmith-first-look
- Sledgehammer Games, Modern Warfare III launch patch notes, including the November 2023 updates: https://www.callofduty.com/patchnotes/2023/11/call-of-duty--modern-warfare-iii-launch-patch-notes.html
- Sledgehammer Games, Modern Warfare III Season 1 patch notes: https://www.callofduty.com/patchnotes/2023/12/call-of-duty-modern-warfare-iii-season-1-patch-notes.html
- Sledgehammer Games, Modern Warfare III Season 2 patch notes: https://www.callofduty.com/patchnotes/2024/02/call-of-duty-modern-warfare-iii-season-2-patch-notes
- Sledgehammer Games, Modern Warfare III Season 3 patch notes: https://www.callofduty.com/patchnotes/2024/04/call-of-duty-modern-warfare-iii-season-3-patch-notes
- Sledgehammer Games, Modern Warfare III Season 4 patch notes: https://www.callofduty.com/patchnotes/2024/05/call-of-duty-modern-warfare-iii-season-4-patch-notes
- Treyarch, "Launch Comms: Weapons Hot. Primary, Secondary, and Melee Weapons Detail for Black Ops 6" (2024): https://www.callofduty.com/blog/2024/10/call-of-duty-black-ops-6-launch-comms-weapons-attachments-intel
- DICE, Battlefield 2042 Update 4.0 notes: https://www.ea.com/en-gb/games/battlefield/battlefield-2042/news/battlefield-2042-update-notes-4-0
- DICE, Battlefield 2042 Update 6.0 notes: https://www.ea.com/en-gb/games/battlefield/battlefield-2042/news/battlefield-2042-update-notes-6-0
- DICE, Battlefield 2042 Update 6.2 notes: https://www.ea.com/en-gb/games/battlefield/battlefield-2042/news/battlefield-2042-update-notes-6-2
- Halo Support, "Halo Infinite Weapon, Equipment, and Vehicle Inventory": https://support.halowaypoint.com/hc/en-us/articles/6882880281364-Halo-Infinite-Weapon-Equipment-and-Vehicle-Inventory

Community wikis:

- Call of Duty wiki: https://callofduty.fandom.com/wiki/Gunsmith , https://callofduty.fandom.com/wiki/Monolithic_Suppressor , https://callofduty.fandom.com/wiki/Agency_Suppressor , https://callofduty.fandom.com/wiki/Field_Agent_Grip , https://callofduty.fandom.com/wiki/Raider_Stock , https://callofduty.fandom.com/wiki/Fast_Mag
- Battlefield wiki: https://battlefield.fandom.com/wiki/Customization , https://battlefield.fandom.com/wiki/Plus_System , https://battlefield.fandom.com/wiki/Heavy_Barrel , https://battlefield.fandom.com/wiki/Muzzle_Brake , https://battlefield.fandom.com/wiki/Compensator , https://battlefield.fandom.com/wiki/Suppressor , https://battlefield.fandom.com/wiki/Flash_Hider , https://battlefield.fandom.com/wiki/Angled_Grip , https://battlefield.fandom.com/wiki/Stubby_Grip , https://battlefield.fandom.com/wiki/Laser_Sight
- Escape from Tarkov wiki: https://escapefromtarkov.fandom.com/wiki/Weapon_mods , https://escapefromtarkov.fandom.com/wiki/Performance_modifiers
- Halopedia: https://www.halopedia.org/Special_weapons_(Halo_Infinite) , https://www.halopedia.org/MA40_Longshot
- Hunt: Showdown wiki, Update 2.2 notes: https://huntshowdown.fandom.com/wiki/Update_2.2.0.35

Secondary press:

- PC Gamer on Black Ops 6 barrels: https://www.pcgamer.com/games/call-of-duty/black-ops-6-barrels-barely-do-anything
- PC Gamer on Hunt: Showdown silencers: https://pcgamer.com/games/fps/we-want-to-increase-the-cost-of-silence-hunt-showdown-1896s-latest-update-brings-a-new-event-a-massive-list-of-bugfixes-and-a-tougher-challenge-for-stealthy-players
