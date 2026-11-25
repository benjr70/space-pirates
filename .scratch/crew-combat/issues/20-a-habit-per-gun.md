Status: ready-for-agent
Blocked by: 18, 19

# A habit per gun

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 6 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "A habit per gun", "Fair fire" (the two tells) and `issues/07`, `issues/06`.

- Range band and hold-before-shifting per gun from its Gunnery (Shotgun 2 to 5 m, 4 s; Pistol 4 to 8 m, 4 s; Assault Rifle 5 to 10 m, 8 s; Marksman Rifle 8 to 14 m, never moves up). The band is a term in the cover score, never a filter.
- A Guard fires at any distance with sight and a clear muzzle line; the engage range goes. The Shotgun holds fire beyond 8 m.
- Shotgun: may take cover within 4 m of the Pirate (no other gun picks a spot that close); too close does not send it back. With no fair walk into its band after 4 s it waits beside the doorway of his Room nearest to it, out of his sight and within 5 m of the opening, leaving when a fair walk appears or to search at 14 s. It racks audibly (the Profile's action sound) before each step out or pop up.
- Marksman Rifle: scores spots by the length of clear line to him up to 14.4 m and searches to 14 m; a perch one Room back counts only while the Door between is open and it opens none for the purpose; it does not move up when he hides or when out of band. With him inside 5 m it falls back to a further perch by a fair walk, else fires from the hip: doubled aim error, no sight line, may miss on purpose, needs no true-aim place.
- The sight line: a thin red line from the rifle to him for 0.9 s before each shot; the shot goes where the line pointed 0.2 s before firing. The rifle must hold one of the two true-aim places from the line's start to the shot, waits for one, and never fires a deliberate miss while perched. Hit during the line, it loses the shot and ducks.
- Update `CREW_AI.md`.

## Acceptance criteria

- [ ] (agent) In a 14 x 10 m test Room with cover throughout, after 20 s each Guard's cover tile is inside its band from a stationary Pirate, within 1 m: Shotgun 2 to 5 m, Pistol 4 to 8, Assault Rifle 5 to 10, Marksman Rifle 8 to 14.
- [ ] (agent) In a 6 x 6 m Room a Marksman Rifle Guard still takes a cover spot and fires within 6 s.
- [ ] (agent) A Shotgun Guard fires no shot at a Pirate in sight 10 m away in 10 s, and does at 6 m.
- [ ] (agent) A Shotgun Guard with only open floor between it and its band is, within 10 s, within 5 m of the doorway of his Room nearest to it and out of his sight, having crossed no more than 2.5 m in his view.
- [ ] (agent) The Shotgun's action sound plays between 0.2 and 1.0 s before each of its shots that follows a step out or pop up.
- [ ] (agent) A sight line is visible from 0.9 s before every perched Marksman Rifle shot, within 0.1 s; a Pirate who sidesteps 1.5 m in the last 0.15 s is not hit; one who stands still is aimed at.
- [ ] (agent) A perched Marksman Rifle Guard fires nothing while both true-aim places are held by others, and fires within 2 s of one freeing.
- [ ] (agent) A Marksman Rifle Guard does not change tile in 20 s with the Pirate hidden; with him walked to 4 m and a fair walk to a further perch, it has moved there within 5 s; with none, its next shot has no sight line and twice the aim error.
- [ ] (agent) A Marksman Rifle Guard hit during its sight line fires no shot from that line.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Each gun's habit can be recognised in a fight: the Shotgun waits for you, the Pistol moves, the Assault Rifle holds, the Marksman Rifle owns a line.
- [ ] (human) The sight line and the rack give enough warning to act on.

## Comments
