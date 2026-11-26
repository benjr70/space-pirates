Status: resolved
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

- [x] (agent) In a test Room with a crate between them, a Guard told of the Pirate 8 m away is within 0.5 m of a tile from which a ray at 0.9 m to his torso is blocked, within 6 s.
- [x] (agent) On its way there, no more than 2.5 m of its path (sampled every 0.5 m, within 0.5 m) has a clear line to the Pirate's eyes, and no sample is nearer him than both ends of the walk less 1 m.
- [x] (agent) Behind low cover it fires from the cover tile; behind full cover it fires from a neighbouring tile and is back on the cover tile within 2.5 s of its last shot.
- [x] (agent) Over 20 peeks each, shots per burst and seconds down fall inside the spec's ranges widened by 30%, for all four guns.
- [x] (agent) With the Pirate moved to where he sees it crouched, it has left that tile for another hidden one within 2 s.
- [x] (agent) With the Pirate walked to 2.5 m in its sight, its next spot is at least 1 m further from him.
- [x] (agent) Two Guards never claim the same tile, and no Guard's cover tile is beside a Breaker.
- [x] (agent) In an empty Room with no prop and no corner out of his sight, a Guard fires at him from where it stands within 3 s rather than closing to under 4 m.
- [x] (agent) Sixty simulated seconds of a three-Guard fight on a generated medium ship end with no crew stuck (no Guard trying to walk and moving under 0.3 m in 5 s).
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) A fight feels like trading shots with Guards who are dug in, not being rushed, as the prototype did.

## Evidence

- Hidden within 6 s: `tests/test_crew.gd::_check_cover_ring`. Four Guards (one per gun) each start 8 m from the Pirate with a crate between, are told where he is (`hear_position`), and each must be within 0.5 m of a tile from which the 0.9 m ray to his torso is blocked within 6 s.
- The walk: `tests/test_crew.gd::_walk_unfair`, applied to the four walks in `_check_cover_ring`, the walk behind the locker in `_check_full_cover` and the walk away from a flank in `_check_flanked_and_closed_on`. The recorded body positions are resampled every 0.5 m along the walk. It asserts that at most 2.5 m (+0.5 m) of samples have a clear line from torso height to the Pirate's eyes, and that no sample is nearer him than the nearer end less 1 m (−0.5 m).
- Low and full cover fire: `_check_cover_ring` asserts each Guard's spot is low cover and that every shot leaves within 0.5 m of its cover tile. `_check_full_cover` (a locker) asserts every shot leaves from a tile beside the cover tile (8-neighbour, within 0.5 m of that tile's centre, never the cover tile itself). It also asserts that over four peeks the Guard is back within 0.5 m of its cover tile within 2.5 s of the peek's last shot.
- Rhythm, all four guns: `_check_cover_ring` runs until every Guard has made 20 or more peeks after its first one. For every completed burst it asserts shots per burst lie in [low × 0.7, high × 1.3]. For every stretch down after a peek it asserts the seconds down lie in [time_down_low × 0.7, time_down_high × 1.3] (± one physics step). The low and high come from that gun's Gunnery. `_check_gunnery` also asserts 200 drawn times down fall in the same band and go past both unvaried ends.
- Flanked: `_check_flanked_and_closed_on`. In the crate grid, with the Guard down, the Pirate is moved to a tile 4–8 m off from which his eyes see it crouched. Within 2 s it must stand more than 0.5 m off the old tile, with a new claimed tile from which the 0.9 m ray to his torso is blocked. It must then reach that tile by a fair walk.
- Too close: `_check_flanked_and_closed_on`. With the Guard down, the Pirate is put 2.5 m off it on open floor in its sight. Within 1 s its claimed spot must change to one at least 1 m further from him than it stood.
- One Guard per tile, none beside a Breaker: `_check_cover_fight_on_ship`. Every frame of 60 s it asserts no two Guards hold the same `cover.tile`, and that no held tile is in the set of tiles beside a Breaker (`Crew3D._breaker_tiles`, over every Room). Picking skips tiles beside a Breaker and tiles another Guard holds (`CrewCover.find`, `_claimed`).
- No cover, fights where it stands: `_check_open_fight`. In the empty 8 × 24 test Room, a Pistol Guard told of the Pirate 8 m off must fire within 3 s, less than 0.5 m from where it stood, in the open-fight mode. It must never come within 4 m of him over 6 s.
- No crew stuck: `_check_cover_fight_on_ship`. A medium ship is generated from a seed drawn off the run seed, so a replay gives the same ship. Three Guards with rolled guns fight the Pirate (who cannot die) in its largest Room for 60 simulated seconds, and he is moved to a fresh spot every 10 s. A Guard is stuck when it tries to walk (`is_walking()`) for 5 s without moving 0.3 m. A second's standing still restarts the count, and none may be stuck. The check also asserts at least two of the three got down in cover.
- `tests/run_all.sh`: see the gate runs under Comments.

## Owed to playtest

- (human) A fight feels like trading shots with Guards who are dug in, not being rushed, as the prototype did.

## Comments

Built 2026-11-25.

**Shape.** `scripts/crew/crew_cover.gd` (`CrewCover`) sits beside `crew_combat.gd`. Every Guard holds one (`Crew3D.cover`, made in `_ready`, null for a Worker). The body's FIGHT and COVER states both run `_tick_fight`, which hands over to `cover.tick`. `_enter(FIGHT|COVER)` calls `cover.begin()`, and entering any other state, or dying, calls `cover.release()`. The cover module sets the body's state as the prototype did: COVER while walking to a spot, down, or stepping back; FIGHT while up, stepping out, or in the open. HUNT hands over when the last-seen spot is within 18 m and the Guard is not flanking. A flanker that sees him within `ENGAGE_RANGE` (still 10.6 m, the stopgap) enters FIGHT, which is the cover fight. Claims are not shared state: a tile is held while some living Guard's `cover.tile` is that tile, so death and leaving free it. The one-mover rule reads the other Guards' `mover_clock` in the same way.

**Rules and numbers kept from the prototype**: radius 8 m, fall-back 14 m, the score weights (20 / 40, full cover half of that / 20 with a 4 m falloff / −20 within 2 m), the best six tried, the fair walk (2.5 m in view, both ends less 1 m), ±30 %, wait up 1.2 s, two blind peeks, flanked 0.4 s, too close 3 m, 6 s hold and 20 % better, unseen 5 s and 14 s, near miss 1.2 m and 0.8 s, look again 1 s (hiding) and 1.5 s (open), mover 4 s, arrive-down 0.3 s, step give-up 2.5 s, open pause 0.6 of a time down, sink 0.8 m and capsule 55 %. The rhythm reads the Gunnery: shots per burst, bursts per peek, gap, settle and time down. The prototype's own per-gun settle multipliers and its Marksman Rifle spread factor are replaced by the Gunnery's `settle` (0.35 s / 0.9 s), as the spec says. The prototype's knobs (the push-at-him option, Breakers allowed, peek modes, the 3x aim curve) are not ported. Aim stays today's `CrewCombat.spread` until "Fair fire".

**Choices and changes to the prototype, each because the prototype misbehaved or the ticket left it open:**

- **Hidden means from his eyes as well as his torso.** The prototype filtered spots on the 0.9 m ray to his torso but called a Guard flanked on the 0.9 m ray to his eyes. Over a 1.1 m crate within about 4.3 m of him, a spot passes the first test and fails the second. A Guard then claimed it, was "flanked" 0.4 s later, re-picked the same tile and got down again for 0.3 s, in a loop. A spot must now pass both tests. Criterion 1 still measures the torso ray.
- **A hiding Guard (no peek) that he can see picks again.** The prototype left it crouched in his view with no shot, since its flank test needed a peek. Found by the smoke sweep (stayed down 4.6 s with him in sight).
- **Standing on the spot.** A walk ends within the body's 0.44 m arrive radius. When it stopped short of a full-cover step tile, the muzzle line judged from the tile's centre clipped the locker. Each walk (to a spot, out, back) now takes one last step aimed past the point (`_walk_onto`).
- **Reach by walk, and giving up.** The prototype filtered on straight-line distance and gave up after 5 s of walking. On the built sample, an 8 m spot lay 20 m away round props, and the Guard gave up halfway across the ship. A spot's walk may now be at most 1.5 × the radius (12 m, or 21 m when falling back), and must pass no closer than 0.6 m to a crew member standing still: the sweep found Guards stalled 5 s against a Guard down in a lane. A walk gives up after 3 s without moving 0.5 m. 3 s is the old `COVER_GIVE_UP`, now `CrewCover.MOVE_GIVE_UP`. The spot is then passed over for 10 s.
- **Open fight first burst.** The prototype waited 0.2 s and then a pause of 0.6 × time down before the first shot. The first burst in the open now comes after the settle. With no clear shot in the open (out of sight, or the muzzle line blocked; the prototype only did this out of sight) it walks to `_find_firing_position`. That step-out search is kept for the open fight only. `_find_cover_point` is kept for Workers (COWER) only.
- **Near misses** come from the Pirate's `fired` signal: his camera's line passing within 1.2 m of the body, connected when a Guard enters the fight. Down, the timer is never pushed past the gun's longest time down + 0.8 s (`longest_down`). The prototype capped at a flat 3.5 s, which could shorten a Marksman Rifle's time down. Being hit no longer sends a Guard in FIGHT to COVER 60 % of the time; the near miss covers it.
- **Pose stand-in**: the prototype's sunk body (model 0.8 m into the floor, capsule 1.7 → 0.94 m). Its head zone rides the head bone, so it sinks too.
- **Reloads**: ticket 17 is not built, so today's pause stays. Crew count no rounds, and the time down is the pause. `_fire` no longer draws a time down itself; `Crew3D._reload_timer`, `cover_hold_time`, `_cover_clock`, `_stepping_out` and `_tick_cover` are gone.
- **Trace hunts stay today's hunt.** A Guard that found a body or the open boarding Hatch, or is told by the one that found it (`hear_position(at, true)`, `CrewCombat.share(..., true)`), hunts the old way until it sees him. Without this, `_check_hatch` failed: the finder took cover from the inside of the pod instead of following him in, and the CREW_AI rule "the pod is not a safe zone" would have gone. A Guard that has actually seen him, or been told by one that has, fights from cover around the pod like anywhere else.

**Outside the ticket, fixed because they blocked the gate:**

- `scripts/ui/awareness_markers.gd::mark_at`: a crew member exactly on the camera's plane (the ring rig's east and west Guards, abeam of a Pirate at yaw 0) made `unproject_position` raise an engine error every frame. That point is now nudged a centimetre behind the camera and pinned like anything behind. In a Raid it needs float-exact alignment, but it is a real error path.
- `scripts/crew/crew.gd::_tick_routine`: `_check_routines` failed on seed 811298643. A Worker whose walk ended 0.53 m from its work spot, pushed back while a Guard passed it head-on in a lane, worked 1.5 m from its prop. This is not cover code. It showed because the cover checks before it change the random stream, and the original code passes on that seed only because its stream differs. A Worker now walks on to the spot when its walk ends further than its arrive radius from it.
- `tests/test_crew.gd` now silences every sound before it quits (`_silence`, as `test_pirate.gd` does). The ship fight's last gunshots were still in the mixer at exit and leaked Ogg playbacks ("resources still in use").

**Existing checks changed because the spec replaces what they asserted:**

- `test_crew.gd::_check_cover_blocked` asserted the old COVER give-up (out of COVER into FIGHT within `Crew3D.COVER_GIVE_UP` + 0.1 s). It now boxes a Guard in with crates the grid does not know of. It asserts the Guard gives up the spot it set off for within `CrewCover.MOVE_GIVE_UP` + 0.1 s and does not set off for it again in the next 3 s. Mutation: with the give-up disabled, this check fails.
- `test_crew.gd::_check_muzzle_blocked` asserted, in 6 s, no bolt into the cover from where it stood, a step over 0.5 m, and a hit on the Pirate. In both rigs the Guard now takes cover behind the prop and fires a few shots a peek, with the spread reset each time it ducks. A hit at 10 m in 6 s is then luck (one run had 2 shots and 0 hits). The check now runs 12 s and asserts no bolt into the cover from where it stood, a step over 0.5 m, no bolt fired with its muzzle line blocked (tested at launch), and at least one bolt past the cover (into him, or the wall behind him). The flake the last builder saw in the locker case did not show on real code in about fifteen crew runs.
- `test_crew.gd::_check_gunnery`: "a spent burst stays down within the Gunnery's time down" read `_reload_timer`. It now draws `CrewCover.down_time` 200 times and asserts the band varied by 30 %, reaching past both ends. `_has_fired` reads `last_pellets` in place of `_reload_timer`.
- `test_ship_3d.gd` crew phase: the dead-eye gunman had to land a hit by frame 240 (4 s). It may now hide or walk to a spot first, so the phase waits for the first hit up to `CREW_SHOT_FRAMES` (900, 15 s) and runs the rest of the phase then. The check itself (a hit lands, no friendly fire) is unchanged.
- `test_raid_smoke.gd` invariant 4: "no crew member holds COVER past its limit" (3.5–4.5 s) is replaced. A dug-in Guard now rightly sits in COVER for as long as the fight lasts there: hiding, holding while he is unseen, or between peeks. Two checks replace it, to keep catching a stuck or broken Guard. (a) Down with him in its sight for longer than `CrewCover.longest_down()` + 0.5 s since it got down or last ducked a near miss (`cover.downs` and `cover.near_misses` tell one stretch from the next). (b) Trying to walk in the fight for 5 s without moving 0.3 m, with a second standing still restarting the count. Mutation: a Guard that never peeks fails (a) on `class=small seed=101`. The muzzle-streak invariant is unchanged.

- `test_raid_smoke.gd` bot aim: the bot aimed at and judged lines to a fixed chest height of 1.3 m. A Guard down with its capsule cut to 0.94 m behind full cover was still a "target" to it, so it fired over the Guard forever without hitting. Each shot was a near miss that kept the Guard down, so neither side ever ended the fight. A `seeds=20` sweep failed on this: `seed=641421776 seeds=20 class=medium ship=255880753 script=loud`, no end state in 300 s. It reproduces only inside a sweep, for example `class=medium script=loud` on that seed. The bot now aims 0.2 m under the top of the body as it is now (`_chest`), capped at 1.3 m. The replay sweep passes (20/20).

**For later tickets.**
- "Fair fire" replaces `CrewCombat.spread` inside `Crew3D._fire`, and adds true aim. The cover module calls `crew._fire()` after setting `_aim`.
- "Crew magazines and reloads" adds a RELOAD mode to `CrewCover` (the prototype has one to copy). Today the time down is the pause.
- "A habit per gun" replaces `HOLD_BEFORE_SHIFTING` (6 s for all) with the Gunnery's `hold_before_shifting` and drops `ENGAGE_RANGE`. That range is now read only by the flanker's switch-over and `_find_firing_position`.
- "Guards work together" replaces the one-mover rule (`mover_clock`) with covering fire.
- "Guards' poses in a fight" replaces `CrewCover._crouch`/`_stand` (the sink).
- `_find_cover_point` and `cover_search_radius` serve Workers only; "Unarmed Workers run and hide" replaces them.
- Near misses can pin a Guard down for as long as the Pirate keeps firing past it, since every near miss adds 0.8 s, capped per stretch but renewed by each shot. That follows the spec's rule, and it is what kept the smoke bot's fight above going. Whether it needs a limit is a question for the playtest or "Guards work together".
- The fight changes no Sandbox number. `docs/sandbox.md` is unchanged.

**Seen and not fixed**: `tests/test_ship_3d.gd::_check_cover` and `tests/built_sample_checks.gd::_check_cover` still test `_find_cover_point`, which is now the Worker's. They pass and are left alone; a Guard's cover is tested in `crew`.

Screenshots: `tests/shots.sh crew` (PASS, 2 frames). `front.png` shows the Guard (left, the Soldier) and the Worker (right, the Engineer) facing the camera beside a crate, both whole, textured and on the floor. `side.png` shows the same two turned side-on. Nothing is missing, magenta, floating or sunk. No preset shows a Guard down in a fight, so the sunk stand-in is checked only by `_check_cover_ring` (the capsule's top below the crate's 1.1 m while down).

**Validation, on the final code:**
- Full gate twice, both PASS: seed 694519843 (232 s) and seed 843094293 (234 s). Every suite passed: static 173, generator 357186, layouts 252, ship_3d 3720, pirate 2402, crew 297, sandbox 490, attachments 1674, raid_smoke 1104 checks.
- `tests/run_all.sh only=raid_smoke seeds=20`: PASS, seed 531403830, 4372 checks, 491 s. Endings: Quiet 58 Ghost of 60; Loud 57 extracted with a kill of 60; Caught 60 down of 60.
- `tests/run_all.sh only=crew` three more times: PASS on seeds 2157084, 597721376 and 890641891 (297 checks, 22 s each).
- An earlier round on the code before the bot's aim fix passed both gates and the crew runs, and failed only the `seeds=20` sweep on the bot case described above. A sweep before that one found the stuck-behind-a-body and hiding-in-sight cases that are fixed above. Every one of those replays passes.
