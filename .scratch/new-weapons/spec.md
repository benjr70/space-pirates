Status: ready-for-agent
Map: map.md

# Spec: Shotgun, Marksman Rifle and the Sandbox sheet

Assembled on 2026-11-22 from the wayfinder map beside this file. Every decision below was made in a ticket under `issues/`; each section links the ticket that holds the detail and the reasoning. Vocabulary is `CONTEXT.md`'s: Pistol, Assault Rifle, Shotgun, Marksman Rifle, Weapon Profile, Sandbox, Gunnery and Headshot are already defined there.

Numbers in this spec are **starting numbers**. The last build step is a balance pass in the sheet, played by the user, which is where they get tuned.

## Problem Statement

The Pirate has two guns, and both kill a crew member in four hits. There is no close-range gun and no gun that rewards aim. Weapon numbers sit in one file per weapon with about 34 fields each, crew gun numbers sit in the crew script in a different shape, and Health sits in two scenes, so nothing can be compared side by side and balancing means opening five files. Health 4 against damage 1 leaves almost nothing to dial: a kill takes 1, 2 or 4 hits and nothing between.

## Solution

Two new weapons, each a Weapon Profile and nothing else:

- The **Shotgun**, the doorway gun: pump-action, 12 pellets, a one-shot kill up close, loaded one shell at a time.
- The **Marksman Rifle**: semi-automatic, kills with one Headshot or two body shots, poor from the hip and exact when aimed and still.

A **Sandbox sheet** over every number that decides a fight: an in-Raid sheet (F1) that dials weapons, crew Gunnery and Health live and saves them, and a generated `docs/sandbox.md` that records them in git.

Underneath, the mechanics the two guns need are added once as Weapon Profile fields (pellets, Headshot multiplier, loudness, shell-by-shell reload, aimed-and-moving spread, sway, per-weapon sounds), Health and damage are scaled by 25 so they can be dialled, and crew fire the Pirate's own Pistol with a per-crew-type Gunnery on top.

## User Stories

1. As a pirate, I want a Shotgun that kills in one shot inside about 4 m and fades out by 12 m, so that going through a door is its own kind of fight.
2. As a pirate, I want the Shotgun to pump between shots, so that a miss up close costs me.
3. As a pirate, I want to load the Shotgun one shell at a time and fire the moment I need to, so that topping up between Rooms is a habit and never a trap.
4. As a pirate, I want the Shotgun to fire true out of a Slide, so that sprinting into a Room and sliding is a play.
5. As a pirate, I want a Marksman Rifle that kills with one shot to the head, so that careful aim is rewarded.
6. As a pirate, I want the Marksman Rifle to be poor from the hip and exact when I aim and stand still, so that using it is a commitment a hit can break.
7. As a pirate, I want a Headshot to look different from a body hit, so that I know the shot counted.
8. As a pirate, I want each gun to sound like itself, and the Shotgun to be heard furthest, so that the loud option has a cost.
9. As a pirate, I want to pick any of four weapons with the wheel or a number key, so that the right gun is one press away.
10. As a pirate, I want my Health shown as a bar that moves with every hit, so that partial damage reads.
11. As a designer, I want every weapon's numbers side by side in one sheet while a Raid is paused, so that I can change one and feel it at once.
12. As a designer, I want derived numbers (shots to kill, time to kill, reach, damage per shot) beside the raw ones, so that I balance outcomes and not fields.
13. As a designer, I want crew Gunnery and Health in the same sheet, so that a fight's two sides are tuned together.
14. As a designer, I want the saved Sandbox written to a Markdown file in git, so that every balance change is a readable diff.
15. As a designer, I want damage and Health fine-grained, so that there are choices between "twice as strong" and "the same".
16. As a developer, I want a new weapon to stay a new Profile and never new code, so that the next gun is a data file.
17. As a developer, I want the code to say Pistol and Assault Rifle, so that it matches the glossary.

## Implementation Decisions

### Names (decided while charting the map)

- Sidearm becomes **Pistol** and Carbine becomes **Assault Rifle** everywhere: `resources/weapons/*.tres`, `scenes/weapons/*_model.tscn`, `assets/models/sidearm` and `assets/models/carbine`, node names in `scenes/player_3d.tscn`, identifiers such as `sidearm_clips` in `scripts/viewmodel.gd`, `resources/animations/viewmodel_clips.tres`, `tests/test_pirate.gd` and `tests/shots.gd`, `tools/blender/pistol.py` and `carbine.py`, `scripts/crew/CREW_AI.md`. About 20 files. It is the first build step and contains nothing else, so the suite stays green across a pure rename.

### Damage model ([What the damage model needs](issues/07-damage-model.md))

- Health and damage scale by 25 and stay ints: crew Health **100**, Pirate Health **150**, Pistol and Assault Rifle damage **25**, Melee **75** from the front (the kill from behind is unchanged). Crew shots do the Pistol's 25.
- Crew get a **head zone** that follows the model's head, separate from the body. A hit on it is a Headshot.
- Every Weapon Profile has a **headshot multiplier**; 1 means no bonus. Marksman Rifle 2, Pistol 1.5 (25 becomes 38, rounded), Assault Rifle 1, Shotgun 1.
- Nothing that strikes the Pirate is a Headshot: he has one zone.
- **No damage falloff.** Range comes from spread and from reach (speed times lifetime).
- Every Profile has a **pellet count**, 1 for all but the Shotgun. Damage is per pellet.
- One shot counts **one kill and one hit marker per crew member**, however many pellets land. A pellet that strikes a crew member already killed by the same shot must not report a second kill ([How the Shotgun's pellets fly](issues/08-shotgun-pellet-pattern.md)).

### New Weapon Profile fields

Added once; every existing weapon gets the value that keeps it behaving as today unless stated.

| Field | Meaning | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|---|
| pellet count | projectiles per shot | 1 | 1 | 12 | 1 |
| headshot multiplier | damage times this on a head zone | 1.5 | 1 | 1 | 2 |
| loudness | metres at which crew hear the shot | 24 | 24 | 32 | 24 |
| shot sounds | the takes a shot plays, one at random | new Pistol shot | today's gunshot | Shotgun shot | Marksman Rifle shot |
| reload sounds | magazine out and in, or shell in | today's | today's | shell in | rifle magazine |
| action sound, delay | a sound after each shot, and how long after | none | none | pump, 0.2 s | none |
| shell-by-shell reload | loads one round at a time | off | off | on | off |
| first shell time | seconds for the first shell | n/a | n/a | 0.55 | n/a |
| shell time | seconds for each shell after | n/a | n/a | 0.45 | n/a |
| closing pump time | seconds to pump after loading from empty | n/a | n/a | 0.45 | n/a |
| break-out time | seconds from a shot breaking the reload to the gun firing | n/a | n/a | 0.25 | n/a |
| aimed-and-moving spread | multiplier on the base cone while aimed and walking | 0.6 | 0.585 | 0.8 | 0.4 |
| aimed sway | degrees the aim drifts in Aim Down Sights | 0 | 0 | 0 | 0.25 |

- **Aimed spread changes shape.** Today the cone is base, times a movement multiplier, times the aimed multiplier, which cannot give a 3 degree hip cone, a pinpoint aimed-and-still cone and a 1.2 degree aimed-and-walking cone together ([How the precision rifle aims](issues/09-precision-rifle-aiming.md)). While aimed, the cone is the base times `ads_spread` when still or crouched, and the base times the new aimed-and-moving spread when walking; the air and Slide multipliers still apply on top. The Pistol and Assault Rifle values above are their old aimed multiplier times their walking multiplier, so they play as today.
- **The mouse slows by the zoom** while aimed, for every gun.
- **Sway** is a slow figure of eight laid over the aim.
- The gunshot noise crew hear takes the Profile's loudness in place of the one constant in `scripts/crew/crew_noise.gd`.
- Shot sounds leave `scripts/pirate_audio.gd` and `scripts/crew/crew.gd` for the Profile.

### The Shotgun

Role: [What the Shotgun is for](issues/05-shotgun-role.md). Pellets: [How the Shotgun's pellets fly](issues/08-shotgun-pellet-pattern.md). Reload: [How the Shotgun's shell-by-shell reload plays](issues/13-shotgun-shell-reload.md). Look: [What the Shotgun looks like](issues/10-shotgun-look.md).

| | Starting value |
|---|---|
| Trigger | one shot per press, 0.8 s between shots |
| Pellets | 12, each thrown at random inside the cone, evenly over its area |
| Damage | 13 per pellet: 8 of 12 kill a crew member, a full shot does 156 |
| Cone | 5 degrees; no bloom; unchanged crouched, standing, walking and in a Slide; 1.3 times in the air |
| Reach | 15 m: 60 m/s for 0.25 s |
| Capacity | 6 shells |
| Aim Down Sights | cone times 0.8, zoom 1.15, speed 0.85 |
| Recoil | kick 11 degrees and push 0.09 at the hip; 6 and 0.07 aimed; camera kick 3 |
| Headshot multiplier | 1 |
| Loudness | 32 m |
| Hip pose | (0.15, -0.24, -0.34); aimed distance 0.30; lowered pose to be set below the hip pose |

- Expected range band: a one-shot kill inside about 4 m, two shots to about 8 m, near useless past 12 m. One shot may kill two crew standing close.
- **Reload.** One tap of reload loads shells until the gun is full or the reload is broken. A shell counts, and its sound plays, when its time is up. A shot, a Melee or a weapon swap breaks the reload and keeps the shells already in; the shell in hand is lost. A shot can break in only with a shell in the gun, and the gun then fires by itself after the break-out time: the press that broke the reload is the press that fires. The closing pump cannot be broken by a shot. A dry pull starts the reload. A Sprint does not break it.
- **Model.** The pump-action boarding shotgun built by `tools/blender/shotgun.py`. It has no skeleton or clips yet: add `kit.rig` and `kit.clip` as on the Assault Rifle. Its fore-end is already a separate mesh named Pump. Clips owed: the pump after a shot (the fore-end travels 7.5 cm back and returns within 0.55 s, starting 0.15 s after the shot), one shell going in, and the closing pump. Import it into `assets/models/` with a scene under `scenes/weapons/`.

### The Marksman Rifle

Identity: [What the precision rifle is](issues/06-precision-rifle-identity.md). Aiming: [How the precision rifle aims](issues/09-precision-rifle-aiming.md). Look: [What the Marksman Rifle looks like](issues/11-marksman-rifle-look.md).

| | Starting value |
|---|---|
| Trigger | one shot per press, 0.4 s between shots |
| Damage | 50 body, 100 on a Headshot: one Headshot or two body shots kill |
| Bolt | 200 m/s for 0.4 s, an 80 m reach: the fastest and furthest in the Sandbox |
| Magazine | 8 rounds; magazine reload of 2.0 s, 2.4 s from empty |
| Hip cone | 3 degrees; bloom 1 degree per shot, gone in 0.5 s; crouched 0.8, walking 1.5, Slide 2, air 2 |
| Aim Down Sights | sights on the Viewmodel, zoom 3; pinpoint (0.05 degrees) still or crouched; 1.2 degrees walking; speed 0.6; sway 0.25 degrees |
| Recoil | kick 5 degrees at the hip; push 0.05 aimed; camera kick 1.6 |
| Headshot multiplier | 2 |
| Loudness | 24 m |
| Hip pose | (0.15, -0.2, -0.36); aimed distance 0.36; lowered pose to be set |

- Descope is the same rule as every gun, with no protection. It is this gun's counter.
- No scope overlay. Scopes come with weapon attachments, a later effort.
- **Model.** The black bullpup from `tools/blender/marksman.py` on branch `prototype/marksman-look`: the magazine behind the pistol grip, a slab polymer shell, a long barrel with brass rings, a full top rail with a hooded front post and rear aperture, a brass cheek rest. The prototype model is rough. Owed: a finished pass at the Assault Rifle's standard (2048 bake), a skeleton and clips (a bolt that cycles on each shot, a magazine that drops and seats behind the grip), importing and a scene. The sights must read clearly at 3x.

### Crew and Gunnery ([How crew gunnery sits in the Sandbox sheet](issues/03-crew-gunnery-in-the-sandbox.md))

- Crew fire the **Pistol** Weapon Profile, the same resource the Pirate holds. From it they read damage, projectile speed, projectile lifetime, time between shots, the shot sound and its loudness. They ignore the magazine, reloads, bloom, Aim Down Sights, recoil and Viewmodel fields: they fire a burst and pause, and never count rounds.
- **Gunnery** is a new resource, one per crew type, at `resources/gunnery/guard.tres` and `worker.tres`:

| | Guard | Worker |
|---|---|---|
| aim error, degrees, added to the Pistol's own 1 degree cone | 6 | 11 |
| burst length | 3 | 2 |
| pause between bursts, s | 1.1 | 1.1 |
| engage range, m | 10.6 | 10.6 |

- The Worker's spread and burst constants in `scripts/crew/crew.gd` move into its Gunnery. Spawn jitter stays in code; the resources hold base values.
- Accepted consequence: crew bolts go from 23.75 m/s to the Pistol's 80 m/s. Crew are retuned through Gunnery in the balance pass, by playtest.
- Crew hold no other weapon. Update `scripts/crew/CREW_AI.md`.

### The Sandbox sheet ([What the master weapon sheet is](issues/04-master-weapon-sheet.md))

- **In-Raid sheet.** F1 during a Raid pauses it and opens a table: weapons as columns, attributes as rows grouped as the Profile groups them, with Gunnery (a column per crew type) and Health as their own tables. A change applies live; closing the sheet resumes the Raid with it. Cells that differ from disk are marked, with the disk value shown. Save writes to disk; Revert restores what is on disk. Debug builds only, stripped from an export.
- **Where numbers live.** Weapons stay one `.tres` each under `resources/weapons/`; there is no single master data file. Gunnery is one `.tres` per crew type. Pirate Health, crew Health and Melee damage live in one small Sandbox resource that the Pirate and crew read at spawn, so Save never writes into a scene.
- **Generated view.** `docs/sandbox.md`, committed: every row of the sheet as Markdown tables. Rewritten on every Save, and checked by the test suite, which fails when it is stale against the resources.
- **Derived rows**, read-only, in both: reach, damage per shot, shots to kill crew (body, and by Headshot where the multiplier is above 1), seconds to kill crew, shots per second, and for the Shotgun pellets needed to kill and seconds from empty to full.
- **Read-only cells.** Model, poses and clip names are edited in the Godot Inspector; the sheet shows them and the Markdown lists them. Sounds likewise.
- The Melee kill-from-behind rule shows as a read-only note.
- The throwaway prototype is on branch `prototype/sandbox-sheet`. Rewrite it; do not promote it.

### HUD ([How the HUD shows the new guns](issues/14-hud-for-new-guns.md))

- The crosshair stays today's four lines for every gun, the Shotgun included. No new crosshair.
- A Headshot flashes the same X as a body hit in gold (1.0, 0.8, 0.25). A body hit stays white, a kill red; a Headshot that kills is red.
- Health is one bar, where the pips were and in their green, split into six segments of 25 by dividers and filling continuously. It replaces the pips.
- The ammo counter rises by one as each Shotgun shell goes in.

### Weapon Wheel

- Order: Pistol, Assault Rifle, Shotgun, Marksman Rifle. A Raid starts on the Pistol.
- Keys 1 to 4 pick a weapon directly, under the same swap time and rules as the wheel.

### Sounds ([Which sounds the new guns make](issues/12-new-gun-sounds.md))

All picked by ear in the sound booth, all CC0 from OpenGameArt. The cuts, a `LICENSE.txt` naming each source file and URL, and the script that cut them are on branch `prototype/new-gun-sounds` under `assets/audio/audition_picks/`.

| For | Pick |
|---|---|
| Shotgun shot | Winchester Model 12 at mid distance, raised 12 dB into a limiter |
| Shotgun pump | shotgun cock |
| Shotgun shell going in | first shell |
| Marksman Rifle shot | Tikka .30-06 at mid distance |
| Marksman Rifle magazine | gun reload |
| Pistol shot (Pirate and crew) | kurt's .22 Magnum, replacing today's gunshot |
| Assault Rifle shot | today's gunshot, until revisited |
| Headshot | the hit-marker tick, until a sound is picked |

- Each pick is one take. Today's gunshot plays one of four; the source recordings hold several shots, so cut more variants from the same files.
- The Headshot sound and the Assault Rifle's shot are open in [What a Headshot sounds like, and the Assault Rifle's shot](issues/16-headshot-and-assault-rifle-sounds.md). They do not hold up the build.

## Testing Decisions

- Headless checks in the existing suites, run by `tests/run_all.sh`:
  - the rename leaves every suite green with no other change;
  - a Shotgun shot launches 12 pellets inside its cone, and a shot that kills one crew member reports one kill and one hit marker;
  - the shell-by-shell reload: empty to full takes 3.25 s and ends at 6; a shot mid-reload keeps the loaded shells, loses the one in hand and fires after the break-out time; the closing pump runs only from empty; a Melee and a swap both keep the shells;
  - a Marksman Rifle hit on the head zone does 100 and on the body 50; the Pistol does 38 and 25; the Assault Rifle and Shotgun do the same on either; a crew shot to the Pirate's head does plain damage;
  - the aimed cone is pinpoint when still and 1.2 degrees when walking for the Marksman Rifle, and unchanged for the Pistol and Assault Rifle;
  - crew shots carry the Pistol Profile's damage and speed, and a Guard's cone is the Pistol's plus its aim error;
  - crew hear each weapon at its loudness;
  - keys 1 to 4 and the wheel reach all four weapons in order;
  - `docs/sandbox.md` matches the resources (the stale check), and a Save from the sheet rewrites both.
- Feel is judged in playtest after each step, not on paper. The five gameplay prototypes on the `prototype/*` branches are the reference for how each mechanic felt when it was picked.

## Out of Scope

- Loadouts: the Pirate carries all four weapons.
- Crew holding any weapon but the Pistol; crew magazines and reloads.
- Ammo reserves and pickups: reserves stay infinite.
- Scopes, and weapon attachments and modifications generally.
- Damage falloff over distance.
- Crew perception, cover, movement and Awareness: behaviour, not Sandbox, and not in the sheet.

## Build Order

Each step leaves the game playable; playtest after each before starting the next. One ticket per step, numbered on from the map's decision tickets (01 to 16) in the same folder.

1. [Rename Sidearm to Pistol and Carbine to Assault Rifle](issues/17-rename-pistol-and-assault-rifle.md)
2. [Scale Health and damage by 25, with a segmented Health bar](issues/18-health-and-damage-times-25.md)
3. [The Sandbox sheet: in-Raid sheet, Sandbox resource and docs/sandbox.md](issues/19-sandbox-sheet.md)
4. [Crew fire the Pistol, handled with a Gunnery](issues/20-crew-fire-the-pistol.md)
5. [Per-weapon sounds and loudness](issues/21-per-weapon-sound-and-loudness.md)
6. [Pellets and the Shotgun](issues/22-pellets-and-the-shotgun.md)
7. [Shell-by-shell reload](issues/23-shell-by-shell-reload.md)
8. [Shotgun rig, clips and sounds](issues/24-shotgun-rig-clips-and-sounds.md)
9. [Headshots](issues/25-headshots.md)
10. [Aiming: aimed-and-moving spread, sway and a mouse slowed by zoom](issues/26-aiming-spread-sway-and-mouse.md)
11. [The Marksman Rifle, and a wheel of four](issues/27-marksman-rifle.md)
12. [First balance pass in the Sandbox sheet](issues/28-first-balance-pass.md)
