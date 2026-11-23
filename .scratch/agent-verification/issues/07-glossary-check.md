Status: needs-info
Blocked by: none

# Glossary check

## Parent

`.scratch/agent-verification/spec.md`, build order 7 of 9.

## What to build

A check that new code uses `CONTEXT.md`'s terms, which the factory contract requires and nothing enforces.

`CONTEXT.md` defines about 40 terms but lists no words to avoid, so there is nothing to check against yet.

- **Add an `_Avoid_:` line** to the entries where a rival word is plausible, for example Pirate (player), Raid (mission, level), Container (chest, crate as a loot holder), Hatch (airlock), Loot (gold, coins as the general word). The maintainer confirms the list: some rival words are legitimate in other senses (`player_3d.gd` exists, a crate is also a prop).
- **`tests/check_glossary.sh [base]`**: reads the `_Avoid_:` lines, and reports any avoided word in identifiers, comments and strings on lines added since `base` (default `main`) under `scripts/`, `scenes/`, `tests/` and `.scratch/`. Added lines only: existing code is not rewritten by this ticket.
- **Advisory, not a gate.** It prints its hits and exits 0; the Code Reviewer reads them. Promote it to the gate later if the hit rate proves clean.
- Document it in `docs/agents/validation.md` beside the note that names use the glossary's terms.

## Acceptance criteria

- [ ] (human) The maintainer has confirmed the `_Avoid_:` list.
- [ ] (agent) `CONTEXT.md` carries the confirmed `_Avoid_:` lines.
- [ ] (agent) A scratch diff adding an avoided word in a function name is reported with file and line; a diff without one reports nothing.
- [ ] (agent) Running it against `main` itself reports nothing (no added lines).
- [ ] (agent) `docs/agents/validation.md` documents the command and that it is advisory.

## Comments

2026-11-22, orchestrating session: proposed `_Avoid_:` list, waiting on the maintainer. Chosen so that every word has zero or near-zero legitimate use in `scripts/` and `tests/` today (counts from a whole-word grep, `scripts/proto/` excluded).

| Term | Avoid | Uses today |
| ---- | ----- | ---------: |
| Ship Layout | blueprint, floorplan, map (as a noun for a ship) | 0 |
| Room | compartment, chamber | 0 |
| Corridor | hallway, hall, passage | 0 |
| Bridge | cockpit | 3 (all in the glossary's own sense: "no separate cockpit Role") |
| Door | doorway as a synonym for Door (a doorway is the gap; fine as that) | not checked by tool |
| Hatch | airlock | 1 (a Boarding Pod comment) |
| Boarding Pod | shuttle, dropship, escape pod | 0 |
| Crew (Guard, Worker) | enemy, enemies, npc, mob, hostile (as a noun) | 0 |
| Guard | soldier (as a crew type; the rig file is `soldier.glb`) | 5, all the rig |
| Worker | engineer (as a crew type; the rig file is `engineer.glb`), civilian | 5, all the rig |
| Awareness | detection, suspicion (as the value's name), stealth meter | 0 |
| Alarm | alert (as a noun for the ship-wide state), siren, klaxon (as the state; fine as the sound) | 2 (`alert()` is a perception function) |
| Job | task, duty | 0 |
| Post | station (as a crew member's home Room) | not counted |
| Raid | mission, level (as a visit to a ship), run | `level` 44, all XP level |
| Extraction | escape, exfil, evac | 0 |
| Loot | coins, money, treasure, reward | 1 |
| Container | chest, loot box | `chest` 4, all the body part |
| XP | experience, exp, score | 0 |
| Pirate | hero, character, avatar | 0 |
| Clamber | mantle, vault, climb | 3 (`vault` is a Room synonym in the generator's self-test) |
| Slide | dash, dodge | 0 |
| Melee | punch, bash, knife | 0 |
| Aim Down Sights | scope, zoom (as the action's name), iron sights mode | 0 |
| Assault Rifle | carbine?, machine gun, smg | see question below |
| Marksman Rifle | sniper, sniper rifle, dmr | 0 |

Left out on purpose, because they are legitimate words here: `player` (900 uses; `player_3d.gd` is the Pirate's script), `crate` (a prop), `pod`, `tile`, `weapon`, `gun`, `level` in the XP sense, `noise`.

Questions for the maintainer:
1. The glossary says Assault Rifle; the code and the screenshot tool say Carbine (`tools/blender/carbine.py`, "wheel=1 shoots the Carbine"). Which is the term? The other goes on the avoid list or the glossary changes.
2. `soldier`/`engineer` name the rig files. Avoid them as crew-type words in code and comments, with the file names exempt?
3. Should `player` be discouraged in new prose and comments (not identifiers), or left alone entirely?
