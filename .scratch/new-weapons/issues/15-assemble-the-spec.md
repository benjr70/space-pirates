Type: grilling
Status: resolved
Blocked by: 12, 13, 14
Map: ../map.md

# Assembling the spec

## Question

Write `.scratch/new-weapons/spec.md` from every resolved ticket on the map, settling the last small questions with the user as they come up: the order of four weapons on the Weapon Wheel; how the Pistol and Assault Rifle rename is carried through code, resources, scenes and asset folders; the full list of new Weapon Profile fields and sheet rows; and the order the build should go in, ending with the first balance pass in the in-Raid sheet (starting numbers are in the tickets; crew Gunnery is retuned by playtest there).

## Answer

The spec is written: [spec.md](../spec.md). It carries every decision on the map, each section linking the ticket that holds the detail.

Settled in this ticket:

- **Weapon Wheel order.** Pistol, Assault Rifle, Shotgun, Marksman Rifle. A Raid starts on the Pistol.
- **Number keys.** Keys 1 to 4 pick a weapon directly, under the same swap time and rules. The wheel stays.
- **Rename.** Sidearm to Pistol and Carbine to Assault Rifle everywhere (about 20 files: resources, scenes, asset folders, node names, identifiers, tests, Blender scripts), as the first build step and alone.
- **Starting numbers no prototype fixed.** Loudness 24 m for the Pistol, Assault Rifle and Marksman Rifle and 32 m for the Shotgun. Marksman Rifle bolt 200 m/s with an 80 m reach. Guard Gunnery: aim error 6 degrees, burst 3, pause 1.1 s, engage 10.6 m; Worker: aim error 11 degrees, burst 2, same pause and range. The Pistol's Headshot is 25 times 1.5, rounded to 38.
- **Build order.** Twelve steps, each playable, the sheet third so every later step is dialled with it, the balance pass last. Listed in the spec.

Worked out while writing, for the build to check:

- The aimed-and-moving spread is a multiplier on the base cone, used in place of `ads_spread` while aimed and walking. The Pistol (0.6) and Assault Rifle (0.585) get their old aimed multiplier times their walking multiplier, so they play as today.
- Per-weapon sounds need more Profile fields than the shot alone: reload sounds, and an action sound with a delay for the Shotgun's pump.
- The spec's status is `needs-triage`. Build tickets are not cut yet.
