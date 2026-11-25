Type: grilling
Status: resolved
Map: ../map.md

# Budget, sheet and checks

## Question

Three things the spec needs that no ticket has decided. Each is small; together they are one session.

- **Threat Budget.** Guards now hold cover, carry heavier guns on bigger ships and seldom rush, and at most two aim true at once. Does the number of crew per Ship Class (small 4 to 8, medium 11 to 19, large 24 to 36) stay as it is for the first build, to be retuned after a playtest, or change now? Does the Pirate's Health (150, no regeneration) stay?
- **Sandbox sheet.** Which of the new numbers get a place in the in-Raid sheet (F1) and which stay constants in code: the four Gunnery columns; the true-aim numbers (how many, the handover timer); the cover numbers (search radius, open floor allowed, flank and too-close reactions, hold times); the gun roll's weights, Post Room multipliers and caps; the Worker numbers (hide roll, 20 s before coming out, surrender distances, binding time and XP).
- **How it is checked.** Which outcomes of this spec a suite can prove, so they become `(agent)` criteria, and which are playtest only. Candidates for a suite: a Guard reaches a cover spot hidden from the Pirate; it never crosses more than the allowed open floor in his view; time down and shots per peek per gun within tolerance; never more than two aiming true; a crew Shotgun shot never takes a full-health Pirate down; the gun roll's caps hold over many seeds and repeat on a Retry; a Worker never fires; a surrendered Worker left unwatched with the Alarm down raises it; a Bound Worker never does. Whether a headless firefight on a generated ship, replayed by seed, joins the raid smoke suite.

Not a decision, so not asked here and noted for the spec's "owed to playtest": how each crew gun sounds from the receiving end, and whether a reloading Guard needs more than its reload sound.

## Answer

Grilled with the user on 2026-11-25.

**Threat Budget and Health.** Unchanged for the first build: crew per Ship Class stays small 4 to 8, medium 11 to 19, large 24 to 36, and the Pirate keeps 150 Health with no regeneration. They are retuned only after a playtest of the finished behaviour, so a playtest reacts to one change at a time.

**In the Sandbox sheet.**
- The Gunnery section becomes four columns, one per weapon, holding every Gunnery field: aim error, opening spread and closing time, shots per burst, bursts per peek, burst gap, time down, settle, lead, range band, reload factor.
- A new Crew fight section, one column: how many aim true (2), the true-aim handover time (0.8 s), the first burst's walk-in distance (1 m), the Shotgun pellet cap (9), suppression time (4 s), the too-close distance (3 m), the flank reaction (0.4 s), the open floor a Guard will cross in view (2.5 m).

**Constants in code.** Everything else: the cover search radius and score weights, hold and advance times, the gun roll's weights, Post Room multipliers and caps, and every Worker number (hide roll, 20 s before coming out, surrender distances, 2 s to bind, XP values). Any may move to the sheet later.

**What a suite must prove.** Each becomes an `(agent)` criterion in a build ticket, with its value and tolerance:
- A Guard told of the Pirate reaches a cover spot hidden from him, and its route crosses no more than the allowed open floor in his view.
- Shots per peek and time down per gun fall inside their ranges.
- Never more than two Guards aim true in any frame, and at least one does when any has a clear line.
- In the first burst of a sighting only the last round is aimed at him.
- A crew Shotgun shot never takes a full-health Pirate down.
- A Guard's reload takes the Profile's time times the factor, and it does not fire meanwhile.
- The gun roll: caps hold across the seed sweep, the mix lands within tolerance of the weights, and the same seed gives the same guns.
- A Worker never fires; under the Alarm it ends on a hiding tile; one that surrendered and was left unwatched with the Alarm down raises it; a Bound one never does; a Bound one seen by a Guard starts a hunt.
- XP: binding 50, killing a surrendered Worker 0.

**The raid smoke suite.** No new suite. Its scripted Raids gain invariants checked on every ship: no Guard fights standing in the open for more than 3 s while a valid cover spot was in reach; no crew stuck; the true-aim count never above two.

**Playtest only.** The fight reads as trading shots, not a rush; each gun's habit is recognisable; the Marksman Rifle's sight line and the Shotgun's rack give enough warning; the reload sound alone reads as a window; the one-knee head is a fair opening; hands on the guns look right; Worker poses read as fear and surrender; leaving a witness feels like a real cost; how each crew gun sounds from the receiving end.
