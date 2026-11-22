Type: prototype
Status: resolved
Blocked by: none
Map: ../map.md

# Which sounds the new guns make

## Question

Which sounds do the Shotgun and Marksman Rifle make, and what does a Headshot sound like? Gather free candidates and audition them in the sound booth prototype (`scripts/proto/proto_sound_audition.gd`) so the user picks by ear: the Shotgun's shot, its pump and one shell going in; the Marksman Rifle's shot and its magazine out and in; the Headshot hit sound. Shot sounds move into the Weapon Profile, so also settle whether the Pistol and Assault Rifle keep sharing today's gunshot or get one each.

## Answer

Picked by ear in the sound booth, from 20 level-matched candidates. All sources are CC0 on OpenGameArt.

| For | Pick | Source |
|---|---|---|
| Shotgun shot | Winchester Model 12 at mid distance, raised 12 dB into a limiter (as recorded it was too quiet) | The Free Firearm Sound Library |
| Shotgun pump | shotgun cock | Gun reload sounds |
| Shotgun shell going in | first shell | Shotgun Reload Sound effects |
| Marksman Rifle shot | Tikka .30-06 at mid distance | The Free Firearm Sound Library |
| Marksman Rifle magazine | gun reload | Gun reload sounds |
| Pistol shot | kurt's .22 Magnum, replacing today's gunshot | Gunshots by kurt |

- **Shot sounds are per weapon.** The Pistol no longer shares a gunshot with the Assault Rifle, so the shot sound is a Weapon Profile field. Crew fire the Pistol, so crew get the new Pistol shot too.
- **Assault Rifle shot: not settled.** The Benelli Nova at mid distance was picked in the first round and then set aside. Until it is revisited the Assault Rifle keeps today's gunshot.
- **Headshot sound: not settled.** Twelve candidates (glass, a bong, a chime, a pluck, metal pings, cast iron clangs) were all rejected. Both open sounds are carried by [What a Headshot sounds like, and the Assault Rifle's shot](16-headshot-and-assault-rifle-sounds.md).

For the build: each pick is one take. Today's gunshot plays one of four variants; the shot recordings hold several shots each, so more variants can be cut from the same files. The Marksman Rifle and the magazine guns have no separate magazine-out and magazine-in pick here; the one reload sound covers the swap.

Left out on purpose: OpenGameArt's "Gunshot Sounds" pack, which the site tags CC0 but whose own text file says CC-BY 3.0.

**Assets.** Branch `prototype/new-gun-sounds` (local, never merged), commit a6ef019: the picked cuts under `assets/audio/audition_picks/`, with `LICENSE.txt` naming each source file and URL, and `cut.py`, which made the cuts. The booth is `scripts/proto/proto_sound_audition.gd` on main.
