Type: grilling
Status: resolved
Blocked by: 01, 04, 05
Map: ../map.md

# Gunnery that feels fair

## Question

What makes a Guard's shooting feel fair, for each of the four weapons?

Today Gunnery is four numbers per crew type (aim error, burst length, pause, engage range), and aim tightens to half spread after 3 s of sight. With "Fair fire and cover in reference shooters", "Crew magazines and reloads" and "Guards in cover" answered:

- Which fairness techniques this game takes: a first shot that misses, aim that lags a moving Pirate, accuracy that falls with his speed or rises with his exposure, a limit on how many Guards fire at once, a tell before a shot.
- Whether Gunnery becomes one per weapon, one per crew type, or both multiplied.
- What Gunnery's fields are after this, and which of today's four go or change.
- Whether the tightening-aim curve stays.
- How deadly each gun should be in a Guard's hands: roughly how long an exposed, standing Pirate lives against one Guard with each weapon at its preferred range. Starting numbers only; the Sandbox sheet tunes them.
- Burst length per weapon (shots per peek), now that the magazine caps it, and where the crew reload factor sits.
- Whether another Guard steps up its fire while one reloads.
- The Marksman Rifle in particular: a one-shot threat needs a tell. What it is.

## Answer

Grilled with the user on 2026-11-25. Every number is a starting number, tuned in the Sandbox sheet. The hit chances are arithmetic from cone size against body size, not measured.

**Exposure ramp.** A Guard's spread opens at 3x on first sight and closes to 1x (the gun's own spread plus its Gunnery's aim error) over 2 s of unbroken sight. It resets when the Pirate breaks sight. It never goes tighter than 1x: today's 0.5x floor goes. This is what the cover prototype was played with.

**The first burst walks in.** The first burst on each new sighting starts aimed 1 m to one side and reaches him on its last round. The Shotgun and Marksman Rifle skip this; they have tells.

**Who may hit.** Every Guard fires, but at most two aim true at once, on every Ship Class. The rest aim at miss points. Whenever any Guard has him in sight with a clear muzzle line, at least one aims true; a lone Guard always does. True aim passes on by a timer: 0.8 s base, doubled while he is crouched or in cover, halved inside 3 m. It goes to the Guard nearest him with a clear line that held it least recently. A Guard that starts a reload gives it up at once; there is no other step-up for a reloading partner.

**Miss points.** 0.4 to 0.8 m off his body: at the edge of his cover on the side he last peeked from, or in the open, beside his head on the side away from his movement. They are real projectiles and hit him if he walks into one.

**Lead.** A Guard leads a moving Pirate by a fraction of the true intercept: Pistol 0.3, Assault Rifle 0.5, Shotgun 0, Marksman Rifle 1.0. A Slide or a Clamber halves it.

**How deadly.** For a standing, exposed Pirate at full health (150) against one Guard at its range, with the peek rhythm from "Guards in cover":

| Gun | Lives about | Hit chance once aim has closed | Aim error |
|---|---|---|---|
| Pistol, 6 m | 10 s | about 50% | 7.5 degrees |
| Assault Rifle, 7.5 m | 6 s | about 45% | 6 degrees |
| Shotgun, 3.5 m | two shots, 3 s | about half its pellets a shot | 8 degrees |
| Marksman Rifle, 11 m | three shots, 11 s | about 80% | 0 (the gun's own 3 degree cone) |

**The Shotgun never kills in one.** At most 9 pellets of one crew Shotgun shot hurt the Pirate (117). Two shots still kill.

**Tells.** Marksman Rifle: a thin red sight line from the rifle to him for 0.9 s before each shot; the shot goes where the line pointed 0.2 s before firing, so a late sidestep dodges it. It needs true aim to shoot at all: it waits for one of the two places, takes it when its sight line starts and gives it up after the shot, and never fires a deliberate miss. Shotgun: an audible rack before it steps out or pops up. The Pistol and Assault Rifle have no tell beyond the first burst walking in.

**Hitting a Guard spoils its aim.** A Guard the Pirate hits has its spread thrown back to 3x and the closing restarts. A Marksman Rifle Guard hit during its sight line loses the shot and ducks.

**No distance penalty.** No extra accuracy falloff by distance; the cone and the range bands do that work.

**Gunnery's shape.** One Gunnery per weapon, four files; the Guard and Worker Gunnery files go. Fields: aim error; opening spread multiple and closing time; shots per burst (low, high); bursts per peek; gap between bursts; time down (low, high); settle before the first shot; lead; reload factor. Today's pause between bursts and engage range go: time down replaces the first, and the range band from "Where each gun stands" the second. The Sandbox sheet shows four Gunnery columns.

**Glossary.** `CONTEXT.md`: Gunnery rewritten as per weapon; Sandbox now says each weapon's Gunnery. True aim and miss points get no glossary entry.
