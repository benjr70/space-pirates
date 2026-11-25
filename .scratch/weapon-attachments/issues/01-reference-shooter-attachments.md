Type: research
Status: resolved
Blocked by: none
Map: ../map.md

# How reference shooters build their attachment systems

## Question

How do shooters with weapon attachments structure them, and what do the attachments do in numbers? Look at Call of Duty's Gunsmith (Modern Warfare 2019 onward), Battlefield (4 and 2042), Escape from Tarkov and Halo Infinite's weapon variants, plus one or two others if they add something. For each: the slot types and how many slots a weapon has; whether attachments are shared across weapons or made per weapon; the typical attachments in each of sight, barrel, magazine, underbarrel and stock; what each one gains and costs, with magnitudes where a primary source gives them (percent recoil, aim-down-sights time, bullet velocity, sound range for a suppressor, magazine size against reload time); and how the game shows the change to the player on its loadout screen. What do these games treat as the main mistakes: attachments that are strictly better, too many near-identical choices, unreadable stat bars?

## Answer

Full note: `docs/research/reference-shooter-attachments.md` on branch `research/reference-shooter-attachments` (pushed, never merged). Battlefield 4, Cold War, Tarkov and Hunt numbers come from wiki transcriptions, not developer pages; no design talks were found.

**Structure**

- Call of Duty fills 5 slots from 8 to 9 types. Modern Warfare II shares optics, muzzles and underbarrels across all guns; Black Ops 6 shares only optics.
- Battlefield 4 has optic, accessory, barrel and underbarrel; 2042 has 4 slots.
- Tarkov uses per-weapon slot trees.
- Halo Infinite and Hunt: Showdown have fixed weapon variants, not attachments.

**Magnitudes**

- Battlefield 4: 10 to 50% per effect (Compensator: 25% less horizontal recoil, 30% more spread).
- Cold War: 7 to 40% (suppressor: 15 to 30% less bullet velocity).
- Modern Warfare III: optics cost 0 to 100 ms of aim time.
- Battlefield 2042: heavy suppressor 0.75 to 0.85x velocity, hidden from the minimap beyond 15 to 40 m.
- Hunt: silenced shots can be located to about 100 m, about 50 m with subsonic ammo.
- Tarkov: 1 to 20% recoil per part, paid in ergonomics.

**Mistakes these games ran into**

- Unclear or misreported effects has the most evidence (DICE's 4.0 overhaul, Sledgehammer's repeated corrections to listed pros and cons).
- Then near-identical choices.
- On strictly-better Attachments studios disagree: Black Ops 6 deliberately ships mostly pros-only.

**What it suggests for a catalogue of 12 to 16**

- One job per Slot.
- Effects of 10% or more, so each is felt.
- A cost on a different axis from the gain.
- The suppressor priced in bullet velocity, its effect stated as a distance.
- The numbers shown on the Loadout screen generated from the tuning data, never written by hand.

**Not confirmed**

- Modern Warfare 2019 magnitudes; how far a Call of Duty suppressed shot is heard.
- Magazine size against reload time, in any game.
- Absolute per-attachment values in Modern Warfare III and Black Ops 6.
- Battlefield 4: sources conflict on Heavy Barrel, Muzzle Brake and Stubby Grip, and on the "30 to 50%" suppressor velocity.
- Battlefield 2042's unlock model and non-suppressor numbers.
- Tarkov suppressor loudness; Halo variant numbers.
- Hunt's unsilenced range and its 10% silencer damage cut.
