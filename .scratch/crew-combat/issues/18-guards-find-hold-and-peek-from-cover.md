Status: ready-for-agent
Blocked by: 15

# Guards find, hold and peek from cover

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 4 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Cover" and `issues/05`. The accepted behaviour is `git show prototype/guards-in-cover:scripts/proto/proto_guards_in_cover.gd`: port it into `scripts/crew/` properly (a cover module beside `crew_combat.gd`, not a brain bolted on), keeping its rules and numbers.

- Cover spots found from the walking grid and sight rays: an open tile against a wall or a prop, hiding a crouched body from the Pirate's last-seen position, with a peek. Low cover (it can fire over it) or full cover (it steps out to a neighbouring tile with a clear muzzle line). Never a Breaker.
- Picking: the filter, the score (near 20, low 40 or full 20, range band 20, crowding -20 within 2 m), one Guard per spot, the best six tried for a fair walk.
- The fair walk: never nearer the Pirate than both ends less 1 m; no more than 2.5 m in his view.
- The rhythm per gun from its Gunnery (shots per burst, bursts per peek, gap, settle, time down), each varied by plus or minus 30%; up with no shot it waits 1.2 s and ducks.
- Leaving: flanked 0.4 s; too close 3 m; two peeks with no shot; out of band after holding 6 s (the per-gun holds come in "A habit per gun"), only for a 20% better score; unseen 5 s, one spot nearer; unseen 14 s, search. One Guard moves up or back at a time.
- A near miss within 1.2 m: 0.8 s longer down, or back down if up.
- No cover in reach: fall back out of his sight (to 14 m, no fair-walk rule), looking again each second; else fight where it stands, looking every 1.5 s.
- Who is driven: a fighting Guard within 18 m of the last-seen spot; further off, and while flanking, today's hunt.
- Reloads from "Crew magazines and reloads" happen down, if that ticket is in; if not, keep today's pause.
- Down, the Guard's collision is lowered so it is hidden behind low cover; the pose is a later ticket, so use the prototype's stand-in (the body sunk) or today's standing pose and say which.
- Today's `_find_cover_point`, COVER hold and the stepping-out search go where this replaces them. Keep the clear-shot test.
- Rewrite the States and Guard combat sections of `CREW_AI.md`.

## Acceptance criteria

- [ ] (agent) In a test Room with a crate between them, a Guard told of the Pirate 8 m away is within 0.5 m of a tile from which a ray at 0.9 m to his torso is blocked, within 6 s.
- [ ] (agent) On its way there, no more than 2.5 m of its path (sampled every 0.5 m, within 0.5 m) has a clear line to the Pirate's eyes, and no sample is nearer him than both ends of the walk less 1 m.
- [ ] (agent) Behind low cover it fires from the cover tile; behind full cover it fires from a neighbouring tile and is back on the cover tile within 2.5 s of its last shot.
- [ ] (agent) Over 20 peeks each, shots per burst and seconds down fall inside the spec's ranges widened by 30%, for all four guns.
- [ ] (agent) With the Pirate moved to where he sees it crouched, it has left that tile for another hidden one within 2 s.
- [ ] (agent) With the Pirate walked to 2.5 m in its sight, its next spot is at least 1 m further from him.
- [ ] (agent) Two Guards never claim the same tile, and no Guard's cover tile is beside a Breaker.
- [ ] (agent) In an empty Room with no prop and no corner out of his sight, a Guard fires at him from where it stands within 3 s rather than closing to under 4 m.
- [ ] (agent) Sixty simulated seconds of a three-Guard fight on a generated medium ship end with no crew stuck (no Guard trying to walk and moving under 0.3 m in 5 s).
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) A fight feels like trading shots with Guards who are dug in, not being rushed, as the prototype did.

## Comments
