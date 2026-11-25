Type: prototype
Status: resolved
Blocked by: 04
Map: ../map.md

# What a suppressed shot sounds like

## Question

What does each weapon that takes the suppressor sound like with it fitted? Gather candidate suppressed shots for each such weapon and put them in the sound booth beside the unsuppressed shot for the user to pick by ear. Does any other Attachment in the catalogue change a sound (a Magazine's reload, a Barrel's shot), and if so what does it sound like?

## Answer

Picked by the user's ear in the sound booth on 2026-11-24, over two rounds. All three picks are real recordings from "The Free Firearm Sound Library" (CC0, OpenGameArt): a smaller or subsonic round standing in for the suppressed gun.

| Gun | Suppressed shot | Source take |
|---|---|---|
| Pistol | Walther PPQ 9 mm, mid distance | `Walther PPQ/X_31P.wav` |
| Assault Rifle | Ruger Single Six .22 revolver, near | `Ruger Single Six/S_14P.wav` |
| Marksman Rifle | Savage 10 .300 Blackout, mid distance, low-passed at 5 kHz | `Savage 10 .300 Blackout/T_17P.wav` |

- Round 1 offered, per gun: the gun's own shot through two filters, a real small or subsonic round, the one CC0 "Hollywood" silencer and a stylised voice-made silencer. The user took the real round for the Assault Rifle and the Marksman Rifle and called every Pistol candidate bad, the real .22 pistol included.
- Round 2 offered twelve more real recordings for the Pistol, mostly mid-distance takes; the user took the 9 mm at mid distance, unfiltered.
- The pattern, as I read it: real recordings win, filtered or designed ones lose, as with the unsuppressed shots.
- In the booth each candidate played 8 dB under the gun's unsuppressed shot. The picks are cut at that level; how loud a suppressed shot is to the player in the game is for the build to match and the playtest to judge.
- Each pick is one take. The library has a second take of each gun at the other distance; no variants were picked.
- No true recording of a suppressed gun was found under CC0: OpenGameArt holds only the two silencer packs offered in round 1.

**Not asked here**: whether any other Attachment changes a sound. It stays on the map under "Not yet specified" (reload sounds with a different Magazine).

**Assets.** Local branch `prototype/suppressed-sounds` (never merged, not pushed): the three picks under `assets/audio/audition_picks/` with `LICENSE.txt`; both rounds' candidates under `assets/audio/audition_round_1/` and `assets/audio/audition/`; `assets/audio/audition/cut.py`, which made the cuts from the downloaded library. The booth is `scripts/proto/proto_sound_audition.gd` on main.
