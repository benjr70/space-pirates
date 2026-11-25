Label: wayfinder:map

# Crew combat: guns, cover and Workers who give up

## Destination

One spec at `.scratch/crew-combat/spec.md`, with build tickets, that a build can start from with nothing left to decide. It covers five things: each Guard carrying one of the four existing weapons; Guards finding, holding and peeking from cover; where a Guard stands being set by the gun it holds; crew fire that feels fair; and Workers who are unarmed and run, hide, cower or surrender.

The yardstick every ticket is judged against: a cover shooter firefight. Guards hold positions and trade shots, the Pirate takes damage mostly when he stays exposed or pushes carelessly, and he can read what a Guard will do from the gun it holds. Not a horde that closes distance.

## Notes

- Domain: Godot 4 first-person extraction shooter. Crew behaviour lives under `scripts/crew/`, with `scripts/crew/CREW_AI.md` as its design record. Read `CONTEXT.md` for vocabulary (Guard, Worker, Gunnery, Weapon Profile, Sandbox, Alarm, Alarm Panel, Awareness, Breaker, Lane, Apron, Fight Core). "Enemy" is crew; "sniper rifle" is the Marksman Rifle.
- Planning only: tickets resolve decisions. Prototypes are throwaway, on local `prototype/<name>` branches, never merged. The one exception is "Awareness bar hidden behind walls", a build ticket the user asked to ride along: it is built with `/implement`, not resolved as a decision.
- Skills: `grilling` and `domain-modeling` for every grilling ticket; `prototype` for prototype tickets; `research` for research tickets.
- Glossary changes (Worker unarmed, surrender, a Guard's gun) are written into `CONTEXT.md` by the ticket that settles each one.
- Decided while charting:
  - Crew stay Guard and Worker. The Officer is not part of this effort.
  - Each Guard's weapon is rolled from the ship's seed when the ship is generated, so a Retry puts the same guns on the same Guards. A Guard visibly carries that gun's model.
  - Workers carry no gun and never fire. A cornered Worker surrenders instead of fighting.
  - Surrender has consequences beyond an animation; a ticket decides them.
  - A Guard advances cover to cover until it is at its weapon's preferred range, then holds and peeks. It never runs across open floor at the Pirate. Pin and flank stays, rebuilt on top of cover. The Alarm sweep stays as it is.
  - Crew guns get magazines and reloads, so a Guard reloading behind cover is a window to push.
  - Cover and peek behaviour is decided in a playable prototype, not on paper.
  - "Stay far" for a Marksman Rifle Guard means holding cover at the far end of the longest Lane or Corridor it can find, even one Room back, rather than a fixed distance. The exact rule waits on the prototype.
- Facts at charting time:
  - Every crew member fires the Pistol. Guard Gunnery is 6 degrees of aim error, 3-round bursts, a 1.1 s pause and a 10.6 m engage range; the aim tightens to half its spread after 3 s of continuous sight.
  - The Guard loop is HUNT, FIGHT, COVER: it paths at the Pirate's last-seen position, fires a burst, and ducks for 1.2 s behind the nearest prop within 6.9 m (`_find_cover_point` in `scripts/crew/crew.gd`). Breakers are never crew cover.
  - Crew ignore a weapon's magazine, reload, bloom and recoil.
  - Crew sight reaches 14.4 m.
  - The crew rig holds 24 clips, of which crew code plays six. There is no crouch, kneel, cower or hands-up, and crew hold no gun model.
  - A Worker today flees to an Alarm Panel or a Guard, cowers one time in four, and fires the Pistol when cornered within 3 m. Under the Alarm it hides where it stands.
  - Gunnery is one `.tres` per crew type under `resources/gunnery/`, edited in the Sandbox sheet.
- Looks are judged by the user in a prototype scene; sounds are picked by the user's ear in the sound booth, never by measurement.

## Decisions so far

- [Fair fire and cover in reference shooters](issues/01-fair-fire-and-cover-in-reference-shooters.md): accuracy should ramp with the Pirate's exposure and never tighten below base spread (today's 0.5x floor is the outlier); first shots miss; a token gates hitting, not shooting; cover is filter-then-score with paths toward the Pirate rejected; each weapon scores a preferred range band.
- [Where new crew clips come from](issues/02-where-new-crew-clips-come-from.md): every pose is reachable for free, mostly by Blender script on the existing rig; the peek needs no new clip; a long gun needs a shouldered pose and left-hand IK; Mixamo is not used.
- [Which Guard carries which gun](issues/03-which-guard-carries-which-gun.md): a weighted roll per Guard at ship build, heavier guns with Ship Class and Richness, tilted by Post Room, Marksman Rifles capped; the gun shows on patrol; same XP for every gun.
- [Crew magazines and reloads](issues/04-crew-magazines-and-reloads.md): Guards use the Profile's own magazine and reload at 1.5x its time, in cover where they can; a reload always finishes; the Shotgun breaks off inside 3 m; the tell is the reload sound.
- [Guards in cover](issues/05-guards-in-cover.md): played and accepted. Cover is any tile against a wall or prop that hides a crouched Guard and has a shot; low cover is popped up over, full cover stepped out from; a spot is refused if the walk runs at the Pirate or crosses 2.5 m in his view; a Guard leaves when flanked, crowded, shotless or out of its range.
- [Gunnery that feels fair](issues/06-gunnery-that-feels-fair.md): spread opens 3x and closes to 1x over 2 s; first burst walks in; all fire but at most two aim true; partial lead by gun; Marksman Rifle shows a sight line, Shotgun racks and never kills in one; one Gunnery per weapon.
- [Where each gun stands](issues/07-where-each-gun-stands.md): a range band per gun in its Gunnery, and one habit each: the Shotgun ambushes at a doorway, the Pistol shifts, the Assault Rifle anchors, the Marksman Rifle perches on the longest line and hip-fires badly inside 5 m.
- [Unarmed Workers run and hide](issues/08-unarmed-workers-run-and-hide.md): Workers run for a panel or a Guard, or to a corner out of sight of the doorways; under the Alarm all run to hide; a hidden one stays put when found, and with the Alarm down comes out after 20 s to report; a wounded one hides for good.
- [What surrender means](issues/09-what-surrender-means.md): a cornered or aimed-at Worker raises its hands and kneels while watched, then hides again; holding interact for 2 s leaves it Bound for the Raid (50 XP, a serious trace); killing one that has surrendered earns nothing.
- [How crew look in a fight](issues/10-how-crew-look-in-a-fight.md): poses made in code over the rig's clips; every pair of candidates is used, not chosen between: squat or one knee re-picked each time a Guard goes down (one knee leaves the head hittable), the run matches the cover, each Worker rolls its own hiding, surrender, kneeling and Bound poses; hands on guns still owed.
- [Guards working together from cover](issues/13-guards-working-together-from-cover.md): a Guard moves only under another's fire; one mover at a time plus one flanker, chosen by gun (Shotgun first, never the Marksman Rifle), ending in cover; Pistols and Assault Rifles fire on the Pirate's cover for 4 s when he hides; the last Guard falls back and holds.
- [Budget, sheet and checks](issues/14-budget-sheet-and-checks.md): crew counts and Pirate Health stay for the first build; the sheet gains four Gunnery columns and a Crew fight section, the rest are constants; a list of outcomes the suites must prove, with firefight invariants added to the raid smoke suite.
- [Assemble the spec](issues/12-assemble-the-spec.md): [`spec.md`](spec.md) written and sliced into fourteen build tickets, `issues/15` to `issues/28`. The map is complete: no decision ticket is open.

## Not yet specified

Nothing. Every patch has become a ticket or been answered.

## Out of scope

- The Officer crew type: a third type muddies the weapon and cover decisions. Its ticket stays in `.scratch/crew-ai/issues/11-officer-crew-type.md`.
- Awareness, stealth and Ghost rules, apart from the bar fix above.
- Routines, Jobs and Posts.
- How the Alarm is raised and what it does.
- New weapons, and Attachments on crew guns.
- Changes to ship generation, unless cover turns out to need prop data the layout lacks.
- Picking up a dead Guard's gun: the Loadout is two weapons chosen on the menu, and pickups would undo that.
