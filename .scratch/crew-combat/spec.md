Status: ready-for-agent
Map: map.md

# Spec: crew combat

Assembled on 2026-11-25 from the wayfinder map beside this file. Every decision below was made in a ticket under `issues/`; each section links the ticket that holds the detail and the reasoning. Vocabulary is `CONTEXT.md`'s: Guard, Worker, Gunnery, Weapon Profile, Sandbox, Surrender, Bound, Alarm, Alarm Panel, Awareness, Breaker, Lane, Post, Headshot.

Numbers in this spec are **starting numbers**. The build's checks assert them; the last build step is a balance pass in the Sandbox sheet, played by the user, which is where they get tuned.

The yardstick for every part: a cover shooter firefight. Guards hold positions and trade shots, the Pirate takes damage mostly when he stays exposed or pushes carelessly, and he can read what a Guard will do from the gun it holds. Not a horde that closes distance.

## Problem Statement

Every crew member fires the same Pistol. A Guard that spots the Pirate runs straight at his last-seen position, fires a burst, ducks for a second and comes again, and its aim tightens to half the gun's spread while he stays in view. The result is a rush of very good shots: unnatural to fight and impossible to read. Workers carry a gun they almost never use, and under the Alarm they hide where they stand.

## Solution

- **Guns.** Each Guard carries one of the Pirate's four weapons, rolled from the ship's seed, seen in its hands, with its own magazine and reload.
- **Cover.** A fighting Guard picks a spot behind a prop, a wall, a door frame or a corner, refuses a walk that runs at the Pirate or crosses open floor in his view, stays down, and peeks to fire: up over low cover, or out from the side of full cover.
- **Fair fire.** Aim opens wide and closes to the gun's own spread, never tighter. The first burst walks in. Everyone fires but at most two aim true. The Marksman Rifle shows a sight line and the Shotgun racks before it appears.
- **A habit per gun.** The Shotgun ambushes at a doorway, the Pistol shifts, the Assault Rifle anchors, the Marksman Rifle perches.
- **Together.** A Guard moves only under another's fire; one flanks, chosen by its gun; they fire on the Pirate's cover when he hides.
- **Workers.** Unarmed. They run to raise the Alarm or to hide in a corner, surrender when cornered or aimed at, and can be tied up.

## User Stories

1. As a pirate, I want Guards to fight from cover, so that a firefight is trading shots and not being rushed.
2. As a pirate, I want to tell what a Guard will do from the gun it carries, so that scouting a Room pays.
3. As a pirate, I want enemy fire to warn before it hurts, so that damage is the price of staying exposed.
4. As a pirate, I want a Guard's reload to be an opening I can hear, so that pushing is a decision.
5. As a pirate, I want a Shotgun Guard to be something I must not walk round a corner into, and a Marksman Rifle Guard to own a line I must plan around.
6. As a pirate, I want a Guard on one knee to leave its head showing, so that patience behind my own cover is sometimes rewarded.
7. As a pirate, I want Workers to run and hide like people, so that a ship under the Alarm feels afraid of me.
8. As a pirate playing quietly, I want a witness to be a problem I can solve without a kill, so that stealth has more than one answer.
9. As a pirate, I want poses and moves to vary between crew, so that no two fights look the same.

## Implementation Decisions

### Which Guard carries which gun ([Which Guard carries which gun](issues/03-which-guard-carries-which-gun.md))

Each Guard rolls one of the four weapons by weight when the ship is built from its Ship Layout, where crew type is decided today. The gun is not stored in the layout. Rolls run in a fixed order (Rooms by index, Guards by spawn order) from their own random stream seeded off the layout's seed, so a Retry gives the same guns and later features never reshuffle them. Workers roll nothing.

Base weights. Richness slides a ship from its Class's poor row to its rich row:

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| Small, poor | 60 | 25 | 15 | 0 |
| Small, rich | 40 | 35 | 25 | 0 |
| Medium, poor | 35 | 35 | 25 | 5 |
| Medium, rich | 20 | 45 | 25 | 10 |
| Large, poor | 20 | 45 | 25 | 10 |
| Large, rich | 10 | 50 | 25 | 15 |

The Post Room multiplies the weights, which are then renormalised:

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| Corridor | x1 | x1.5 | x0.5 | x2 |
| Armory | x0.5 | x1.5 | x2 | x0.5 |
| Bridge | x1.5 | x1.5 | x1 | x1 |
| Quarters | x2 | x1 | x1 | x0.5 |

Caps: Marksman Rifles none on a small ship, at most 1 on a medium, at most 2 on a large, never two posted in one Room. A Room of three or more Guards is never all Shotguns. A roll that breaks a cap is rolled again among the remaining weapons. Nothing is guaranteed present. A kill is worth the same XP whatever the Guard held.

### Magazines and reloads ([Crew magazines and reloads](issues/04-crew-magazines-and-reloads.md))

A Guard obeys its Weapon Profile's magazine size (12, 30, 6, 8), both reload times, the Shotgun's shell-by-shell reload, the time between shots, pellets, damage, projectile, sounds and loudness. It ignores bloom, recoil, Aim Down Sights, sway, movement spread and swap time. It counts every shot, has unlimited magazines and starts every Raid and Retry full.

- Reload time is the Profile's times the Gunnery's reload factor (1.5).
- Dry, it goes to cover and reloads there; with none in reach it reloads where it stands, backing away. It never fires while reloading.
- A reload always finishes: being shot, flanked or closed on does not cancel or restart it.
- In cover with the Pirate unseen for 3 s it tops up a part-used magazine with the shorter reload time.
- The Shotgun loads shell by shell; with the Pirate in sight within 3 m and one shell in, it breaks off and fires.
- The tell is the Profile's reload sounds at the Guard's position and its reload pose. No HUD marker.

### Cover ([Guards in cover](issues/05-guards-in-cover.md), prototype `prototype/guards-in-cover`)

A fighting Guard whose last-seen spot for the Pirate is within 18 m is driven by these rules in place of today's HUNT, FIGHT and COVER. Further off, and while flanking between Rooms, today's hunt carries it.

**A cover spot** is an open floor tile with a wall or a prop on one of its four sides, from which a crouched body (0.9 m) is hidden from his last-seen position, and which has a way to shoot. Spots are found from the walking grid and sight rays when needed; nothing is authored and the ship generator is unchanged. Breakers are never crew cover.

- **Low cover**: the Guard can fire over it standing. It pops up.
- **Full cover**: it steps out to the nearest neighbouring tile with a clear muzzle line, fires, and steps back.

**Picking.** Filter: within 8 m, in its Room, his Room or one joined to either; hidden from him; unclaimed; has a peek. Score: near the Guard 20, low cover 40 (full cover 20), inside its range band 20, minus 20 if another Guard or its spot is within 2 m. One Guard per spot, claimed on choosing, freed on leaving or dying. Of the best six, it takes the first whose walk is fair.

**A fair walk** never comes nearer the Pirate than both its ends do (less 1 m) and crosses no more than 2.5 m of floor in his view.

**Rhythm.** Down, then up: a settle, its bursts, down again. Every time varies by plus or minus 30%. Up with no shot, it waits 1.2 s and ducks.

| Gun | Shots per burst | Bursts per peek | Gap between bursts | Settle | Time down |
|---|---|---|---|---|---|
| Pistol | 2 to 3 | 1 | | 0.35 s | 1.0 to 2.0 s |
| Assault Rifle | 3 to 5 | 2 | 0.4 to 0.8 s | 0.35 s | 1.5 to 2.5 s |
| Shotgun | 1 | 1 | | 0.35 s | 1.2 to 1.5 s |
| Marksman Rifle | 1 | 1 | | 0.9 s (its sight line) | 2.5 to 4.0 s |

**Leaving a spot.**
- Flanked: he can see it crouched for 0.4 s. It picks again.
- Too close: he is in sight within 3 m. It picks a spot further off.
- No shot: two peeks running with nothing to shoot. It picks again.
- Out of its range band after holding (per gun, below): one spot nearer or further, only for a spot scoring 20% better.
- He is unseen for 5 s: one spot nearer where he was last seen. Unseen for 14 s: it searches as today.

**Near misses.** A shot of his passing within 1.2 m keeps a Guard that is down there 0.8 s longer and sends one that is up back down.

**No cover in reach.** It falls back to the nearest tile where he cannot see it standing (out to 14 m, without the fair-walk rule) and looks again for real cover each second. With nowhere to hide either it fights where it stands in bursts and pauses, looking for cover every 1.5 s.

### Fair fire ([Gunnery that feels fair](issues/06-gunnery-that-feels-fair.md), research `research/fair-fire-and-cover`)

- **Exposure ramp.** Spread opens at 3x on first sight and closes to 1x (the gun's own spread plus the Gunnery's aim error) over 2 s of unbroken sight. It resets when he breaks sight. Never tighter than 1x; today's 0.5x floor goes.
- **First burst walks in.** The first burst of each sighting starts aimed 1 m to one side and reaches him on its last round. The Shotgun and Marksman Rifle skip this.
- **Who may hit.** Every Guard fires, but at most two aim true at once, on every Ship Class; at least one whenever any has him in sight with a clear muzzle line. True aim passes on by a timer: 0.8 s, doubled while he is crouched or in cover, halved inside 3 m, to the Guard nearest him with a clear line that held it least recently. A Guard starting a reload gives it up at once.
- **Miss points.** A Guard not aiming true aims 0.4 to 0.8 m off his body: at the edge of his cover on the side he last peeked from, or in the open beside his head on the side away from his movement. Real projectiles; they hit if he walks into one.
- **Lead.** A fraction of the true intercept: Pistol 0.3, Assault Rifle 0.5, Shotgun 0, Marksman Rifle 1.0. A Slide or Clamber halves it.
- **The Shotgun never kills in one.** At most 9 pellets of one crew Shotgun shot hurt him (117 of 150).
- **Marksman Rifle tell.** A thin red sight line from the rifle to him for 0.9 s before each shot; the shot goes where the line pointed 0.2 s before firing. It needs one of the two true-aim places to shoot at all, takes it when the line starts and gives it up after the shot, and never fires a deliberate miss.
- **Shotgun tell.** An audible rack before it steps out or pops up.
- **Hitting a Guard spoils its aim.** Its spread is thrown back to 3x and closing restarts. A Marksman Rifle Guard hit during its sight line loses the shot and ducks.
- **No distance penalty** beyond the cone.

Targets, for a standing exposed Pirate at full health against one Guard at its range (hit chances are arithmetic, not measured):

| Gun | Lives about | Hit chance once closed | Aim error |
|---|---|---|---|
| Pistol, 6 m | 10 s | about 50% | 7.5 degrees |
| Assault Rifle, 7.5 m | 6 s | about 45% | 6 degrees |
| Shotgun, 3.5 m | two shots, 3 s | about half its pellets a shot | 8 degrees |
| Marksman Rifle, 11 m | three shots, 11 s | about 80% | 0 (the gun's own 3 degree cone) |

**Gunnery's shape.** One Gunnery per weapon, four files; the Guard and Worker files go. Fields: aim error; opening spread multiple and closing time; shots per burst (low, high); bursts per peek; gap between bursts; time down (low, high); settle; lead; range band (near, far); hold before shifting; reload factor. Today's pause between bursts and engage range go.

### A habit per gun ([Where each gun stands](issues/07-where-each-gun-stands.md))

| Gun | Range band | Holds before shifting | Habit |
|---|---|---|---|
| Shotgun | 2 to 5 m | 4 s | ambushes |
| Pistol | 4 to 8 m | 4 s | shifts |
| Assault Rifle | 5 to 10 m | 8 s | anchors |
| Marksman Rifle | 8 to 14 m | never moves up | perches |

The band is a preference in the cover score, never a filter. A Guard fires whenever it has sight and a clear muzzle line, at any distance, except the Shotgun beyond 8 m. A Guard fights in its own Room, his Room, or a Room joined to either.

- **Shotgun.** The only gun that may take cover within 4 m of him; too close does not send it back. With no fair walk into its band after 4 s it waits beside the doorway of his Room nearest to it, out of his sight and within 5 m of the opening. It leaves when a fair walk into its band appears, or to search after 14 s.
- **Marksman Rifle.** It scores spots by the length of its clear line to him (up to 14.4 m), searching out to 14 m. A perch one Room back counts only while the Door between stands open; it opens none to make one. It stays until flanked or until he is within 5 m. Then it falls back to a perch further off if a fair walk exists; if none does it fires from the hip with doubled aim error and no sight line, as an ordinary gun that may miss on purpose and needs no true-aim place.

### Guards together ([Guards working together from cover](issues/13-guards-working-together-from-cover.md))

- **Covering fire.** A Guard changes cover only while another is up and firing at him, true or not. It waits up to 3 s; alone, or with no partner able to fire, it moves anyway.
- **One mover at a time**, plus one flanker.
- **Flank.** As today (one flanker, through a different Door into his Room, while another fights, 20 s to give up), but it ends at a cover spot inside that Door, is exempt from the fair-walk rule between Rooms, needs no covering fire, and takes cover where it stands on giving up. Flanker by gun: Shotgun, then Pistol, then Assault Rifle; never the Marksman Rifle. Where his Room has a second Door, the Shotgun's ambush is at that Door.
- **Suppression.** When he breaks sight behind a prop in a fight, Pistol and Assault Rifle Guards that can see the prop fire at its edges for up to 4 s, deliberate misses only. One Guard may move up meanwhile. Then they hold.
- **Called from other Rooms.** A Guard radioed in runs upright until 18 m from his last-seen spot or until it enters a Room joined to his, then comes spot to spot.
- **The Alarm sweep.** A sweeping Guard that sees him uses the cover rules like any other.
- **The last Guard** fighting in his Room and those joined to it stops moving up, picks cover further off and holds.

### How crew look ([How crew look in a fight](issues/10-how-crew-look-in-a-fight.md), [Where new crew clips come from](issues/02-where-new-crew-clips-come-from.md), prototype `prototype/crew-look`)

Where the prototype showed two candidates the game uses both. Poses are made in code over the rig's own clips, as the prototype does (hips lowered and legs re-solved onto the feet, arms solved onto the gun or the head); the build may bake them into clips if that is cheaper at run time. The prototype's script holds every pose's numbers.

- **A Guard's gun** is seen from patrol on: the Weapon Profile's model, 1.15x, positioned first with the hands put on it. Pistol at the thigh on patrol and aimed with two hands; a long gun low across the body on patrol and shouldered to aim, right hand on the grip and left on the fore-end. Hands must close on each gun with the wrists squared to it: the prototype's did not, and that was the user's one criticism.
- **Down behind cover**: a squat or one knee, picked again each time it drops back after a peek, 60 to 40. Squatting, its head is below the cover; on one knee the top of its head shows. The head zone follows the pose, so a Headshot over low cover is there to take only against one knee. The body's collision lowers with the pose.
- **Moves**: pop up, step out and back, duck lower at a near miss, reload while down. The reload and the step-out were rough in the prototype and are owed better.
- **Runs**: low to low cover; upright to full cover or with none to go to.
- **Workers** each roll their own set once at ship build, from the ship's seed, even odds on each: hiding crouched with arms over the head (ducking lower at a gunshot) or sat down; hands by the head or straight up; kneeling upright or on the heels; Bound sat against the wall or kneeling with hands behind the back.

### Workers ([Unarmed Workers run and hide](issues/08-unarmed-workers-run-and-hide.md))

The Worker's Pistol, its Gunnery and fighting when cornered go.

- **Spotting him, Alarm down.** Three in four run for the nearest working Alarm Panel, else the nearest living Guard, as today. One in four freeze 1 s, then run to a hiding place. With neither panel nor Guard, it hides.
- **Alarm up.** Every Worker not already hiding runs to a hiding place.
- **A hiding place**, by preference: a corner or a wedge between wall and prop; out of sight of every doorway of its Room; far from him and from any Guard's cover. In its Post Room if it can get there without passing him, else in the joined Room furthest from him. Never a tile a Guard has claimed; a Guard may claim a Worker's tile and the Worker moves on.
- **Running.** Full speed, never by a route that runs toward him, avoiding the line between him and a fighting Guard where another route exists.
- **Found.** It stays put and watches him. A fight in its Room does not move it; stray shots can kill it.
- **Coming out.** Alarm up: never. Alarm down: after 20 s with no sight or sound of him it comes out On Edge, walks to the nearest working panel (raising the Alarm) or Guard (alerting it), then resumes its routine; with neither it resumes On Edge. A witness left hiding costs him his Ghost.
- **Wounded.** A Worker shot and alive always hides and never comes out.
- **Traces** are unchanged: a Worker finding a body or the open boarding Hatch runs for a panel or Guard with no roll.

### Surrender and Bound ([What surrender means](issues/09-what-surrender-means.md))

- **Trigger.** A Worker surrenders when it sees him and either he is within 4 m or his crosshair rests on it within 10 m for 0.5 s, and it is hiding or has no route away that does not pass him. A Worker running with a way out keeps running. Guards never surrender. The Alarm changes nothing here.
- **Surrendered.** Hands up, facing him; kneeling after 1.5 s. It holds while he is in its sight. Out of his sight it hides again and the hiding rules apply.
- **Bound.** Holding interact on a surrendered Worker within 2 m for 2 s ties it up: weapon lowered, cancelled by a hit or by letting go. It never reports or moves for the rest of the Raid. The HUD shows "Hold [interact] to tie up" with a fill ring; a Bound Worker shows no Awareness bar.
- **A Bound Worker is a serious trace**, like a body. The finder does not untie it.
- **XP.** Binding 50. Killing a surrendered or Bound Worker 0, and the toast says so. Unaware kill 150 and running or hiding kill 100, as today. The end screen lists Workers bound.
- **Ghost** is unaffected. Shots and Melee work on a kneeling or Bound Worker as on any crew.

### Threat Budget, Health and the Sandbox sheet ([Budget, sheet and checks](issues/14-budget-sheet-and-checks.md))

Crew per Ship Class and the Pirate's 150 Health are unchanged for the first build.

The sheet's Gunnery section becomes four columns, one per weapon, with every Gunnery field. A new Crew fight section, one column: how many aim true (2), the true-aim handover time (0.8 s), the first burst's walk-in distance (1 m), the Shotgun pellet cap (9), suppression time (4 s), the too-close distance (3 m), the flank reaction (0.4 s), the open floor a Guard will cross in view (2.5 m). Everything else is a named constant in code.

### The Awareness bar

The build ticket [Awareness bar hidden behind walls](issues/11-awareness-bar-hidden-behind-walls.md) rides along: a bar is drawn only with a clear line from the camera to the crew member.

## Testing Decisions

- Behaviour is checked in the suite that covers its code: `crew` for cover, fire, habits, teamwork and Workers; `generator` or `ship_3d` for the gun roll; `sandbox` for the sheet; `pirate` for binding and its HUD.
- What a suite must prove is listed in [Budget, sheet and checks](issues/14-budget-sheet-and-checks.md) and carried into each build ticket as `(agent)` criteria with a value and a tolerance.
- The raid smoke suite gains invariants on every Raid: no Guard fights standing in the open for more than 3 s while a valid cover spot was in reach; no crew stuck; never more than two aiming true. No new suite.
- Looks are checked with `tests/shots.sh crew` against the defect checklist, then by the user.
- Every change to crew behaviour updates `scripts/crew/CREW_AI.md` in the same commit, and a new or changed check updates `docs/agents/validation.md`.

## Out of Scope

- The Officer crew type.
- Awareness, stealth and Ghost rules, apart from the bar fix and the Worker that comes out to report.
- Routines, Jobs and Posts.
- How the Alarm is raised and what it does, apart from who now reaches a panel.
- New weapons, and Attachments on crew guns.
- Changes to ship generation.
- Picking up a dead Guard's gun.
- A non-lethal takedown of an unaware Worker.

## Build Order

| Order | Ticket | Blocked by |
|---|---|---|
| 1 | [A Gunnery per weapon and the gun roll](issues/15-gunnery-per-weapon-and-the-gun-roll.md) | none |
| 2 | [Guards carry their guns](issues/16-guards-carry-their-guns.md) | 15 |
| 3 | [Crew magazines and reloads](issues/17-magazines-and-reloads.md) | 15 |
| 4 | [Guards find, hold and peek from cover](issues/18-guards-find-hold-and-peek-from-cover.md) | 15 |
| 5 | [Fair fire](issues/19-fair-fire.md) | 18 |
| 6 | [A habit per gun](issues/20-a-habit-per-gun.md) | 18, 19 |
| 7 | [Guards work together](issues/21-guards-work-together.md) | 19, 20 |
| 8 | [Guards' poses in a fight](issues/22-guards-poses-in-a-fight.md) | 16, 17, 18 |
| 9 | [Unarmed Workers run and hide](issues/23-unarmed-workers-run-and-hide.md) | 15 |
| 10 | [Surrender and Bound](issues/24-surrender-and-bound.md) | 23 |
| 11 | [Workers' poses](issues/25-workers-poses.md) | 22, 24 |
| 12 | [Crew fight in the Sandbox sheet](issues/26-crew-fight-in-the-sandbox-sheet.md) | 19, 21 |
| 13 | [Firefights in the raid smoke suite](issues/27-firefights-in-the-raid-smoke-suite.md) | 21, 24 |
| 14 | [First balance pass of crew combat](issues/28-first-balance-pass.md) | all thirteen |
| any | [Awareness bar hidden behind walls](issues/11-awareness-bar-hidden-behind-walls.md) | none |

## Prototypes and research (primary sources, never merged)

- `prototype/guards-in-cover` (local, `5f2bf8c`): `scripts/proto/proto_guards_in_cover.gd`, the cover brain as played and accepted.
- `prototype/crew-look` (local, `76e13fc`): `scripts/proto/proto_crew_look.gd`, every pose's numbers and the code that makes them.
- `research/fair-fire-and-cover` (origin): `docs/research/fair-fire-and-cover.md`.
- `research/crew-clips` (origin): `docs/research/crew-clips.md`.

Read from them with `git show <branch>:<path>`.

## Owed to playtest

The fight reads as trading shots, not a rush; each gun's habit is recognisable; the Marksman Rifle's sight line and the Shotgun's rack give enough warning; the reload sound alone reads as a window; the one-knee head is a fair opening; hands on the guns look right; Worker poses read as fear and surrender; leaving a witness feels like a real cost; how each crew gun sounds from the receiving end; whether crew counts and the Pirate's Health still fit.
