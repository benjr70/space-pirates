Status: ready-for-agent
Map: map.md

# Spec: weapon Attachments and the Loadout

Assembled on 2026-11-24 from the wayfinder map beside this file. Every decision below was made in a ticket under `issues/`; each section links the ticket that holds the detail and the reasoning. Vocabulary is `CONTEXT.md`'s: Attachment, Slot, Built Weapon, Loadout, Weapon Profile, Sandbox, Viewmodel, Aim Down Sights, Descope, Weapon Wheel, Awareness.

Numbers in this spec are **starting numbers**. The build's checks assert them; the last build step is a balance pass in the sheet, played by the user, which is where they get tuned.

## Problem Statement

The Pirate carries all four guns on every Raid and every gun is the same gun every time. Nothing is chosen before boarding, so there is no way to prepare for a quiet Raid or a loud one, and nothing about a weapon can be made his own.

## Solution

- **Attachments**: fourteen parts in five Slots (Sight, Barrel, Magazine, Underbarrel, Stock). Each changes how a weapon behaves and is seen on the gun in first person. Every one costs something for what it gives. A weapon has only the Slots that suit it.
- **The Loadout**: two different weapons, each as he has fitted it, chosen on the main menu, saved, and carried into every Raid.
- **A Loadout screen**: a workbench behind a Loadout button on the main menu, showing the gun, its Slots and what the fitted Attachments did to it.

Underneath, an Attachment is data: a list of factors on Weapon Profile attributes. A weapon's Profile plus its Attachments gives a **Built Weapon**, which is itself a Weapon Profile, so nothing about shooting changes. Two attributes become per weapon to give Attachments something to cost (aim time, swap time), one is new (how conspicuous the gun is to crew), and scopes get a real lens.

## User Stories

1. As a pirate, I want to choose two weapons before a Raid, so that what I carry is a decision.
2. As a pirate, I want to fit a Suppressor, so that a shot is heard at 9.6 m and not 24 m and a Ghost run is possible with a gun.
3. As a pirate, I want every Attachment to cost something, so that there is no one right build.
4. As a pirate, I want to see my Attachments on the gun in my hands, so that the build is mine.
5. As a pirate, I want a scope that magnifies through its lens while the room around it blurs and darkens, so that aiming through glass feels like it.
6. As a pirate, I want a Reflex Sight whose dot stays on where the shot goes, so that fast aiming is honest.
7. As a pirate, I want bars showing the gun as built against the gun bare, so that I see what a part did before I board.
8. As a pirate, I want my Loadout kept between sessions and each gun to remember its parts, so that I set it once.
9. As a pirate, I want a bigger gun to be slower to its sights and slower to draw, so that handling is part of the choice.
10. As the maintainer, I want every Attachment's numbers in the Sandbox sheet, so that they are balanced by playing.
11. As the maintainer, I want to change the Loadout inside a Raid in debug builds, so that balancing needs no trip to the menu.

## Implementation Decisions

### Names (decided while charting; `CONTEXT.md`)

Attachment, Slot, Built Weapon and Loadout are glossary terms. "Clip" is Magazine; the under-barrel Slot is Underbarrel. The fourteen Attachment names below are used verbatim in code and data and have no glossary entry each.

### How an Attachment changes a weapon ([How an Attachment changes a weapon](issues/03-how-an-attachment-changes-a-weapon.md))

- An Attachment is a data Resource: its Slot kind, its name, its model or models, and a list of changes. A new Attachment is a new data file, never new code.
- A change is one Weapon Profile attribute times a factor. Changes from several Attachments on one attribute multiply; order never matters.
- Three things are not factors: a scope marks the Built Weapon as aiming through a lens; the Suppressor replaces the shot sound; an Attachment may hide a part of the gun's model.
- An Attachment has one set of factors on every gun it fits.
- It may never change: damage, Headshot multiplier, pellet count, semi or automatic fire, shell-by-shell reload.
- Limits: magazine size rounds to whole rounds, never under 1; times and spreads never under 0; zoom never under 1.0. Nothing else is clamped.
- The **Built Weapon** is a fresh Weapon Profile worked out from the bare Profile and the Attachments in its Slots. The Pirate holds Built Weapons. It is never saved, and it is rebuilt whenever the bare Profile or an Attachment changes, live in a Raid.
- Each weapon's Profile lists its Slots and, per Slot, the Attachments that fit. An Attachment knows nothing about guns.
- Crew, the existing suites and the sheet's weapon columns read bare Profiles. Crew weapons take no Attachments.
- No damage falloff is added. "Range" is bolt speed and spread.

### New Weapon Profile attributes ([What aim time and swap time feel like on each gun](issues/12-aim-time-and-swap-time.md), [Which Slots each weapon has and what the Attachments are](issues/04-slots-and-the-catalogue.md))

| Attribute | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| Aim time (s) | 0.15 | 0.22 | 0.22 | 0.32 |
| Swap time (s) | 0.30 | 0.40 | 0.45 | 0.50 |
| Conspicuous | 1.0 | 1.0 | 1.0 | 1.0 |

- **Aim time**: the gun and the zoom ease up and are 95% there at the aim time (pose and zoom speeds of 3 divided by the aim time, where today they are 10 and 14 a second for every gun). The sights drop over the same time.
- What aiming gives comes in with the rise: `ads_spread`, `ads_moving_spread` and `ads_speed` each blend in a straight line over the aim time from the hip value to the aimed value. He may fire while the sights are rising; the shot groups by how far up they are.
- After a Descope the sights come back over the full aim time, once the Descope's own recovery has passed. The mouse still slows the moment he aims.
- **Swap time** moves from the Pirate onto each Profile. A swap takes the swap time of the weapon being drawn.
- **Conspicuous**: a factor on how fast crew build Awareness of the Pirate while he holds the weapon.

### Slots and the catalogue ([Which Slots each weapon has and what the Attachments are](issues/04-slots-and-the-catalogue.md), [What each Attachment's starting numbers are](issues/13-starting-numbers.md))

One job per Slot: Sight is zoom against speed to the sights; Barrel is sound, bolt speed and spread; Magazine is rounds against reload; Underbarrel is recoil and hip fire; Stock is steadiness against handling.

| Slot | Attachment | Gain | Cost |
|---|---|---|---|
| Sight | Reflex Sight | aim time x0.80; `ads_speed` x1.10 | `ads_zoom` x0.85 |
| Sight | Combat Scope | `ads_zoom` x1.55, lens; `ads_spread` x0.75 | aim time x1.30; `ads_speed` x0.85 |
| Sight | Long Scope | `ads_zoom` x1.67, lens | aim time x1.35; `ads_sway_degrees` x1.5 |
| Barrel | Suppressor | `loudness` x0.4; suppressed shot sound | `projectile_speed` x0.80 |
| Barrel | Long Barrel | `projectile_speed` x1.25; `spread_base_degrees` x0.85 | aim time x1.20; swap time x1.20 |
| Barrel | Short Barrel | aim time x0.80; swap time x0.80 | `spread_base_degrees` x1.25; `projectile_speed` x0.85 |
| Magazine | Extended Magazine | `magazine_size` x1.5 | `reload_tactical`, `reload_empty` x1.25 |
| Magazine | Quick Magazine | `reload_tactical`, `reload_empty` x0.70 | `magazine_size` x0.8 |
| Magazine | Drum | `magazine_size` x2.5 | `reload_tactical`, `reload_empty` x1.60; aim time x1.25; swap time x1.30 |
| Underbarrel | Foregrip | `recoil_kick_degrees`, `ads_recoil_kick_degrees`, `camera_kick_degrees` x0.70 | aim time x1.15 |
| Underbarrel | Laser | `spread_base_degrees` x0.70, with `ads_spread` and `ads_moving_spread` x(1/0.70) so aimed fire is unchanged | conspicuous x1.3 |
| Underbarrel | Bipod | `spread_crouch` x0.5; `ads_sway_degrees` x0.5 | aim time x1.20; swap time x1.20 |
| Stock | Heavy Stock | `ads_sway_degrees` x0.6; `ads_moving_spread` x0.8 | aim time x1.20; `ads_speed` x0.85 |
| Stock | Light Stock | aim time x0.80; swap time x0.80; `ads_speed` x1.15 | `ads_sway_degrees` x1.3; `recoil_kick_degrees` x1.25 |

Which gun takes what:

| Weapon | Sight | Barrel | Magazine | Underbarrel | Stock |
|---|---|---|---|---|---|
| Pistol | Reflex | Suppressor | Extended, Quick | Laser | no Slot |
| Assault Rifle | Reflex, Combat Scope | Suppressor, Long, Short | Extended, Quick, Drum | Foregrip, Laser, Bipod | Heavy, Light |
| Shotgun | Reflex | Long, Short | no Slot | Foregrip, Laser | Heavy, Light |
| Marksman Rifle | Long Scope | Suppressor, Long | Extended, Quick | Foregrip, Bipod | Heavy, Light |

The Built Weapon numbers these give, for checks to assert, are tabled in [What each Attachment's starting numbers are](issues/13-starting-numbers.md). No cap on stacked aim time.

### The Loadout ([What the rules of a Loadout are](issues/05-loadout-rules.md))

- Exactly two weapons, never one, never the same weapon twice. First is in hand at Raid start and on key 1; second on key 2; the wheel flips between them.
- Attachments belong to the weapon: all four weapons remember theirs whether carried or not.
- Default: Pistol first, Assault Rifle second, every Slot empty.
- Saved in the profile file beside XP and gold when he leaves the Loadout screen. On load anything stale is dropped quietly: an unknown Attachment or one that no longer fits becomes an empty Slot; an unknown or doubled weapon becomes the default.
- A Raid reads it once at its start; a Retry and a New Raid reuse it. It changes only on the main menu.
- It applies only to a Raid started from the menu. Suites and prototype scenes set the Pirate's weapons directly, any number.

### Models and mounting ([How Attachments mount on a gun model](issues/06-how-attachments-mount-on-a-gun.md), [What each Attachment looks like](issues/09-attachment-look.md))

- An Attachment either adds itself or takes the place of one of the gun's own parts. Which is a fact about the Attachment: the Suppressor, Foregrip, Laser and Bipod add; Sights, Long and Short Barrel, Magazines and Stocks replace. The Pistol keeps its own sights under the Reflex Sight.
- Each gun's model keeps its replaceable parts as separate meshes on its one skeleton: Pistol: magazine. Assault Rifle: barrel, sights, stock, cell. Shotgun: barrel with magazine tube and heat shield, front sight, rear sight, stock. Marksman Rifle: barrel, sights, butt pad with cheek riser, magazine. Bare, every gun looks as it does today.
- Each gun gives mount points: `MountSight`, `MountMuzzle` (none on the Shotgun), `MountUnder`.
- Seven shared models, each built around its mount point: Reflex Sight, Combat Scope, Long Scope, Suppressor, Foregrip, Laser, Bipod. Eighteen per-gun models, built in that gun's space: Long Barrel (Assault Rifle, Shotgun, Marksman Rifle), Short Barrel (Assault Rifle, Shotgun), Extended and Quick Magazine (Pistol, Assault Rifle, Marksman Rifle), Drum (Assault Rifle), Heavy and Light Stock (Assault Rifle, Shotgun, Marksman Rifle).
- A Barrel brings its own `Muzzle`; a Sight brings its own `SightTip`; the Shotgun's Long and Short Barrel bring a bead that is the aim point when no Sight is fitted. The Viewmodel reads the marker from the Attachment in place of the gun's.
- Magazines ride the magazine's bone, so the gun's own reload clip serves every Magazine. The Shotgun's Foregrip and Laser ride the pump. The Pistol's Reflex Sight rides the slide.
- The hip, lowered and aimed poses stay the weapon's own.
- Lift the models and the split from `prototype/attachment-look`: `tools/blender/proto_attachments.py` and `tools/blender/proto_split_gun.py`. For the real build: give each shared model its origin at its mount point; name a bone's mesh apart from the bone (`CellMesh`), or Godot renames the bone; give meshes added after the Viewmodel mounts a gun the same material flags (`Viewmodel._flag_materials`).

### Scoped view ([What the scoped view looks like](issues/07-scoped-view.md), [How a magnified scope is drawn in Godot 4](issues/02-scope-rendering-in-godot.md))

- The Combat Scope and Long Scope are a picture-in-picture lens: only the lens magnifies, by the Built Weapon's `ads_zoom`; the gun stays on screen.
- The view around the lens zooms 1.25x. Everything outside the lens blurs (screen mipmap level 2.0) and fades to black toward the screen's edge (full), fading in as the sights rise and out as they drop or on a Descope.
- The eye sits 0.06 m from the rear glass. The reticle is a red cross on the shot line, seen only through the lens. The mouse slows by the lens's magnification.
- The Reflex Sight is an unmagnified window with a red dot on the shot line; the whole view zooms as with a gun's own sights; no blur.
- A gun's own sights are unchanged: the whole view zooms.
- Build notes from the prototype on `prototype/scoped-view`: the Viewmodel goes on its own render layer, left out of the lens camera; the lens camera copies the Pirate's camera and renders only while aimed through a scope (1024 px square, covering 1.15 half-heights of screen); the lens and reticle sample by screen position, not lens UVs; the lens shader sets the Viewmodel's field of view and depth scale itself; read a lens's live material with `get_active_material`.

### The Laser ([What the sheet, the HUD, the Laser's dot and the reload sounds do](issues/14-sheet-hud-laser-and-reload-sounds.md))

A small red dot on whatever the gun points at, at the hip and aimed, out to 30 m. No beam. A visual for the player only.

### The Loadout screen ([What the Loadout screen looks like](issues/08-loadout-screen.md))

The workbench, as prototyped on `prototype/loadout-screen` (F1 layout):

- A Loadout button on the main menu's home list, under Play. The screen lies over the menu's backdrop, darkened.
- FIRST and SECOND tabs, each naming its gun; a row of the four weapons to change which is carried in the chosen place; picking the gun in the other place swaps them.
- The gun in the middle, still and side-on, barrel left, **showing its fitted Attachments**. Drag turns it freely and it stays; a double click resets it. It never turns by itself.
- Five Slot tags around the gun: the Slot's name over the fitted Attachment, "empty", or greyed "no Slot".
- A tag opens that Slot's list: None, then each Attachment that fits, the fitted one marked, each with one line of gain and cost generated from its changes.
- Nine bars of the Built Weapon against the bare gun: Bolt speed, Hip accuracy, Aimed accuracy, Recoil control, Handling, Magazine, Reload, Quiet, Zoom. Grey to the lower of the two, then green for a gain or red for a cost, the built value as a number in the same colour. A red line, "Crew notice him sooner", with a Laser fitted.
- Only the two carried guns are edited. Mouse, and keyboard focus as on the rest of the menu. Back or Esc returns to the menu and saves. No Raid button here.

### Sandbox sheet ([What the sheet, the HUD, the Laser's dot and the reload sounds do](issues/14-sheet-hud-laser-and-reload-sounds.md), [What the rules of a Loadout are](issues/05-loadout-rules.md))

- A fourth table, "Attachments": fourteen columns, a row per attribute any Attachment changes, a factor per cell, blank where it changes nothing. Dialled, saved and written to `docs/sandbox.md` like the others.
- The weapon columns are all four weapons always, not the carried list. Aim time, swap time and conspicuous are rows.
- For the two carried guns, a read-only Built Weapon value beside the bare one wherever it differs. Not written to `docs/sandbox.md`.
- A debug strip at the top: FIRST and SECOND gun pickers and a picker per Slot under each. Applied when the sheet closes, ammo refilled. Never touches the saved Loadout.

### HUD ([What the sheet, the HUD, the Laser's dot and the reload sounds do](issues/14-sheet-hud-laser-and-reload-sounds.md))

The crosshair hides while aimed through a lens or a Reflex Sight. The ammo counter shows the Built Weapon's magazine. Nothing else changes.

### Sounds ([What a suppressed shot sounds like](issues/10-suppressed-shot-sounds.md))

The three suppressed shots are on `prototype/suppressed-sounds` under `assets/audio/audition_picks/` with their sources: Pistol (9 mm, mid distance), Assault Rifle (.22 revolver), Marksman Rifle (.300 Blackout). Each is one take, cut 8 dB under the bare shot. Magazines keep the gun's own reload sounds.

## Testing Decisions

- Every number in the catalogue is asserted on the Built Weapon, exactly for counts and within 1% for the rest: a check builds each gun with each Attachment it takes and compares against the tables in [What each Attachment's starting numbers are](issues/13-starting-numbers.md). These live in a new suite, `tests/test_attachments.gd` (`only=attachments`), added to `tests/run_all.sh` and to the suite and coverage tables in `docs/agents/validation.md`.
- Behaviour in play goes where its code is covered: aim time, swap time, the Loadout at Raid start and the Viewmodel's markers in `pirate`; hearing distance and Awareness with the Laser in `crew`; the sheet in `tests/test_sandbox.gd`; whole Raids with a fitted Loadout in `raid_smoke`.
- Looks get screenshots: a new `tests/shots.sh attachments` preset (each gun bare and in two full builds, side-on and at the hip), `scoped` (lens up, Reflex up) and the `menu` preset extended with the Loadout screen. Each is read against the defect checklist in `docs/agents/validation.md`.
- What only a person can judge is tagged `(human)` in each ticket and listed under "Owed to playtest".
- The full gate, `tests/run_all.sh`, passes before any ticket closes.

## Out of Scope

- Buying Attachments with gold, unlocking by level, finding them as Loot.
- Attachments on crew weapons.
- Underbarrel Attachments with their own input.
- Ammo types.
- Changing Attachments or weapons during a Raid, outside the debug sheet.
- Damage falloff.
- Gamepad on the Loadout screen.
- New reload sounds or clips per Magazine.

## Build Order

1. [Aim time and swap time per weapon](issues/15-aim-time-and-swap-time-per-weapon.md)
2. [Attachments as data and the Built Weapon](issues/16-attachments-and-the-built-weapon.md)
3. [The Loadout](issues/17-the-loadout.md)
4. [Guns with replaceable parts and mount points](issues/18-guns-with-replaceable-parts.md)
5. [Attachment models on the gun in hand](issues/19-attachment-models-in-the-viewmodel.md)
6. [The scoped view and the Reflex Sight](issues/20-scoped-view-and-reflex-sight.md)
7. [The Laser's dot](issues/21-the-lasers-dot.md)
8. [The Loadout screen](issues/22-the-loadout-screen.md)
9. [Attachments in the Sandbox sheet](issues/23-attachments-in-the-sandbox-sheet.md)
10. [First balance pass of the Attachments](issues/24-first-balance-pass.md)

## Prototypes (primary sources, local branches, never merged)

| Branch | Holds |
|---|---|
| `prototype/attachment-mounting` | first mounting test on the Assault Rifle |
| `prototype/attachment-look` | all 25 models, the gun split, the mounting code for four guns |
| `prototype/scoped-view` | the lens, reticle, overlay and surround shaders |
| `prototype/loadout-screen` | the workbench (and two rejected layouts) |
| `prototype/suppressed-sounds` | the three picked sounds, sources, cut script |
| `prototype/aim-and-swap-time` | aim time and swap time behaviour |

Research, on pushed branches: `research/reference-shooter-attachments`, `research/scope-rendering-in-godot`.
