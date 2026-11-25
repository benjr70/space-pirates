Type: grilling
Status: resolved
Blocked by: 01, 03
Map: ../map.md

# Which Slots each weapon has and what the Attachments are

## Question

What is the catalogue: every Attachment by name, its Slot, what it gains and what it costs in words, and which weapons it fits? And which of the five Slots do the Pistol, the Assault Rifle, the Shotgun and the Marksman Rifle each have?

The charting decisions bound it: about 12 to 16 Attachments, 2 to 3 per Slot, shared across weapons where sensible, every one a sidegrade, magnified scopes in the Sight Slot, a suppressor in the Barrel Slot, passive Underbarrels, Magazines that change capacity and reload only. Each Attachment's gain and cost must be something the model from "How an Attachment changes a weapon" can express. Each weapon keeps its role (the Shotgun is the doorway gun, the Marksman Rifle the precision gun): which Attachments would blur a role and should not fit? New terms go into `CONTEXT.md` as they are named.

## Answer

Grilled with the user on 2026-11-24. Gains and costs are in words; the numbers are a later ticket. No glossary entry per Attachment: the fourteen names live in the spec and the data files and are used verbatim in code; `CONTEXT.md` keeps only Attachment, Slot and Built Weapon.

**One job per Slot**

| Slot | Job |
|---|---|
| Sight | zoom against speed to the sights |
| Barrel | sound, bolt speed, spread |
| Magazine | rounds against reload |
| Underbarrel | recoil and hip fire |
| Stock | steadiness against handling |

No recoil part in the Barrel Slot (no compensator): recoil belongs to the Underbarrel.

**Catalogue (14)**

| Slot | Attachment | Gain | Cost |
|---|---|---|---|
| Sight | Reflex Sight | faster aim time, faster aimed walk | less zoom than the gun's own sights |
| Sight | Combat Scope (about 2.5x on the Assault Rifle) | more zoom, tighter aimed spread | slower aim time, slower aimed walk |
| Sight | Long Scope (about 5x on the Marksman Rifle) | most zoom | slower aim time, more sway |
| Barrel | Suppressor | crew hear the shot much less far | slower bolt |
| Barrel | Long Barrel | faster bolt, tighter spread | slower aim time, slower swap |
| Barrel | Short Barrel | faster aim time, faster swap | wider spread, slower bolt |
| Magazine | Extended Magazine | about 1.5x rounds | slower reload |
| Magazine | Quick Magazine | faster reload | fewer rounds |
| Magazine | Drum | about 2.5x rounds | much slower reload, slower aim time and swap |
| Underbarrel | Foregrip | less recoil and kick | slower aim time |
| Underbarrel | Laser | tighter hip fire | crew build Awareness faster while he holds the gun |
| Underbarrel | Bipod | much tighter and steadier crouched | slower aim time, slower swap |
| Stock | Heavy Stock | less sway, tighter aimed on the move | slower aim time, slower aimed walk |
| Stock | Light Stock | faster aim time, swap and aimed walk | more sway, more recoil |

**Fit**

| Weapon | Sight | Barrel | Magazine | Underbarrel | Stock |
|---|---|---|---|---|---|
| Pistol | Reflex | Suppressor | Extended, Quick | Laser | no Slot |
| Assault Rifle | Reflex, Combat Scope | Suppressor, Long, Short | Extended, Quick, Drum | Foregrip, Laser, Bipod | Heavy, Light |
| Shotgun | Reflex | Long, Short | no Slot | Foregrip, Laser | Heavy, Light |
| Marksman Rifle | Long Scope | Suppressor, Long | Extended, Quick | Foregrip, Bipod | Heavy, Light |

The Assault Rifle and Marksman Rifle have five Slots; the Pistol and Shotgun four.

**Role guards**

- The Shotgun takes no Suppressor: it stays the loudest gun. It has no Magazine Slot and stays at six shells.
- The Marksman Rifle keeps its own open sights at 3x bare (it has no scope today; corrected 2026-11-24); its only Sight is the Long Scope. No Reflex Sight, Short Barrel or Drum: they would make it a second Assault Rifle.
- The Pistol has no Stock Slot and its only Barrel is the Suppressor.
- The Marksman Rifle keeps the Suppressor even though a quiet one-shot Headshot gun is the strongest Ghost tool. The Suppressor shortens how far a shot is heard and never to nothing: crew close by still hear it. Whether it is too strong is a question for the balance pass.

**Changes to the model in "How an Attachment changes a weapon"**

- A Sight multiplies the zoom like any other change (Reflex about x0.85, Combat Scope about x1.55, Long Scope about x1.67); it no longer sets it outright. The guns' own sights zoom differently (Shotgun 1.15x, Pistol and Assault Rifle 1.6x, Marksman Rifle 3x), so a fixed zoom could not be "less than the gun's own" on all of them.
- One more new Profile attribute: how conspicuous the gun is, a factor on how fast crew build Awareness of the Pirate while he holds it; 1 for every bare gun. Only the Laser changes it. It needs a small change where crew see.

**Laser**

- The Laser draws a visible dot where the gun points, matching its cost. Its look is judged in "What each Attachment looks like".
