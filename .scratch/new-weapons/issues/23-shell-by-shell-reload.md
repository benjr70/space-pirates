Status: ready-for-agent
Blocked by: 22

# Shell-by-shell reload

## Parent

Part of `.scratch/new-weapons/spec.md` (Spec: Shotgun, Marksman Rifle and the Sandbox sheet). Build order 7 of 12. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's Shotgun reload rules and `issues/13-shotgun-shell-reload.md`. The prototype on branch `prototype/shell-reload` is the reference for feel; the user picked its starting values unchanged.

The Weapon Profile gains a shell-by-shell reload switch and four times: first shell 0.55 s, each shell after 0.45 s, closing pump 0.45 s, break-out 0.25 s. With the switch on:

- One tap of reload loads shells until the gun is full or the reload is broken.
- A shell counts, the ammo counter rises by one and the shell sound plays when that shell's time is up.
- A shot, a Melee or a weapon swap breaks the reload and keeps the shells already in; the shell in hand is lost.
- A shot can break in only with a shell in the gun. The gun then fires by itself after the break-out time: the press that broke the reload is the press that fires.
- The closing pump runs only when loading began from empty, and a shot cannot break it.
- A dry pull starts the reload. A Sprint does not break it.

The Shotgun uses it. The magazine guns are unchanged, including losing everything on an interrupted reload. The four times and seconds from empty to full join the sheet.

## Acceptance criteria

- [ ] Empty to full takes 3.25 s and ends at 6 shells.
- [ ] A shot pressed after two shells are in leaves two shells loaded, less the one fired, and fires 0.25 s after the press.
- [ ] A Melee and a swap mid-reload both keep the shells already in.
- [ ] From 3 shells, a reload to full ends without a closing pump.
- [ ] An interrupted Pistol reload still gains nothing.
- [ ] `tests/run_all.sh` passes.

## Comments
