Status: resolved
Blocked by: 15

# Crew magazines and reloads

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 3 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Magazines and reloads" and `issues/04`.

- A Guard counts rounds against its Profile's magazine, starts full, and has unlimited magazines.
- Dry, it reloads: the Profile's empty reload time times the Gunnery's reload factor (1.5). It goes behind cover first where today's cover search finds any, else reloads where it stands, backing away. It does not fire while reloading. Being shot, flanked or closed on does not cancel or restart it.
- Topping up: behind cover with the Pirate unseen for 3 s, a part-used magazine is reloaded with the Profile's shorter time times the factor.
- The Shotgun loads shell by shell with the Profile's times times the factor; with the Pirate in sight within 3 m and at least one shell in, it breaks off and fires.
- The Profile's reload sounds play at the Guard's position, at the start and end of a reload (each shell for the Shotgun).
- Burst length stays the Gunnery's; the magazine caps it.
- Update `CREW_AI.md`.

## Acceptance criteria

- [x] (agent) A Pistol, Assault Rifle, Shotgun and Marksman Rifle Guard each fire exactly 12, 30, 6 and 8 shots before the first reload.
- [x] (agent) An empty Assault Rifle reload takes 3.45 s (2.3 x 1.5), within 5%, and no shot is fired during it.
- [x] (agent) A Guard hit twice during a reload still finishes it at the same time, within 0.1 s.
- [x] (agent) A Guard behind cover with 5 rounds left and the Pirate unseen for 3 s is at a full magazine 1.2 x 1.5 s later for the Pistol, within 10%.
- [x] (agent) A Shotgun Guard reloading with 2 shells in fires within 0.6 s of the Pirate coming into sight inside 3 m; with him at 6 m it loads to 6 before firing.
- [x] (agent) A reload sound is played at the reloading Guard's position when a reload starts.
- [x] (agent) `tests/run_all.sh` passes.
- [ ] (human) A Guard's reload can be heard in a fight and reads as a chance to move.

## Evidence

- 12, 30, 6 and 8 shots before the first reload: `tests/test_crew.gd::_check_cover_ring`, the ring of four Guards (one per gun) fighting the Pirate past crates; it counts each Guard's shots (a Shotgun's 12 pellets as one) up to its first `reload_started` and asserts exactly the Profile's magazine size and that the reload is from empty.
- Empty Assault Rifle reload 3.45 s within 5 %, no shot: `tests/test_crew.gd::_check_reloads`, run 0: an Assault Rifle Guard in the ring left 3 rounds runs dry; asserts the reload begins down behind its cover, lasts 3.45 s within 5 % (`reload_started` to `reload_ended`, measured 3.450 s), and no shot of its is fired between them. It also asserts 2.3 x 1.5 = 3.45.
- Hit twice, same end within 0.1 s: `tests/test_crew.gd::_check_reloads`, run 1: the same Guard's next empty reload, hit at 0.5 s and 1.5 s and closed on (the Pirate moved 2.5 m off in its sight at 1.0 s); asserts it took the unhit run's time and 3.45 s, each within 0.1 s (measured 3.450 s), started once, never left its tile while reloading, and fired nothing.
- Pistol topping up in 1.2 x 1.5 s within 10 %: `tests/test_crew.gd::_check_top_up`: a Pistol Guard down behind a crate, set to 5 rounds and held down, the Pirate taken out of sight; asserts the reload is a top-up and the magazine is full 1.8 s within 10 % after the frame its `_seen_ago` reached 3 s, still down.
- Shotgun breaking off inside 3 m, loading to 6 at 6 m: `tests/test_crew.gd::_check_shotgun_reload`: a Shotgun Guard down behind a crate, out of the Pirate's sight, set to 2 shells and reloading; he is put 2.5 m off in its sight (and clear of its muzzle line): asserts the reload was broken off and its first shot came within 0.6 s. Again with him 6 m off: asserts the reload ended unbroken at 6 shells and no shot came before it ended.
- Reload sound at the Guard's position at the start: `tests/test_crew.gd::_check_cover_ring`: on every `reload_started` of each of the four Guards, asserts an `AudioStreamPlayer3D` playing one of that gun's `reload_sounds` started in that physics frame within 0.05 m (flat) of the Guard.
- `tests/run_all.sh` passes: see Validation under Comments.

## Owed to playtest

- (human) A Guard's reload can be heard in a fight and reads as a chance to move.

## Comments

Built 2026-11-26, after tickets 18 to 21 (so the reload is fitted into the cover fight, fair fire, the habits and the team as they stand).

**Shape.** `scripts/crew/crew_magazine.gd` (`CrewMagazine`) is new: every Guard holds one (`Crew3D.magazine`, null for a Worker), made full in `_ready`. It counts rounds against the live Weapon Profile's `magazine_size`, times reloads (Profile time x Gunnery `reload_factor`), plays the reload sounds and emits the body's new signals. The body ticks it every physics step (`Crew3D._physics_process`), so a reload runs to its end whatever the Guard does. `CrewCover` decides when and where one starts. `Crew3D._fire` spends a round and fires nothing when dry or reloading; `_new_burst` caps the Gunnery's drawn burst at the rounds left.

**Choices where the ticket left them open:**

- **The reload happens while down** (ticket 18's stand-in replaced). Dry while up, it ducks (`_duck`) and the reload starts as it gets down (`_get_down`). The peek comes when its drawn time down and the reload have both run out, so a stretch down holding a reload lasts max(time down, reload). The time down is not added on top of the reload.
- **Nothing makes it leave mid-reload.** While reloading down (`CrewCover._reload_down`) `_watch` is skipped (no flanked, too close, shift, blind re-pick, fall back), it does not peek, and any wait to change cover is cleared. A near miss still lengthens its time down, as before. A reloading Guard is never picked to flank (`CrewTeam.consider_flank`).
- **Dry in the open fight** (`_reload_in_open`): it first tries `_pick(0)` then the hiding fall-back `_pick(0, true)` (the same search `_no_cover` uses) and reloads on getting down there. With neither, it reloads where it stands and backs away once, 2 m (`BACK_AWAY`), straight back or angled 35 or 70 degrees off where a prop stands behind it, at 0.4 of its speed (`BACK_AWAY_SPEED`), facing him (FIGHT state). After the reload it starts a fresh burst after a settle.
- **Topping up** happens only in mode DOWN, with `_seen_ago >= 3 s` (`TOP_UP_UNSEEN`). Not in ambush, up, or walking.
- **Shotgun.** Shell by shell: the first shell's time then a shell's time per shell, x 1.5, each shell counting as it seats (6 from dry: 4.2 s). **No closing pump for the crew Shotgun**: it racks before every shot anyway (ticket 20's tell, `Crew3D.rack`), so that rack stands in for the pump, as the coordinator's note on the rack replacing the pump suggested. If the closing pump should be added (4.875 s from dry), it is one line in `CrewMagazine.time_from`, and `longest_down` follows. **Break-off** (`BREAK_OFF` 3 m, him in sight, at least one shell in): over low cover or in the open it racks if its last rack is over 0.2 s old and fires once the rack allows (0.2 s), with no settle (`_begin_shooting(true)`); behind full cover it steps out as usual (that can take longer than 0.6 s; the criterion's rig is low cover).
- **Sounds.** Played at the Guard's position 1 m up (`Crew3D.RELOAD_HEIGHT`) with `SoundAt`, named "Reload". Magazine guns: `reload_sounds[0]` at the start, `[1]` at the end. Shotgun (one sound): at the start and as each shell seats.
- **Fair fire.** `CrewMagazine.start` calls `CrewFire.give_up`. `Crew3D.can_aim_true` is false while the magazine cannot fire, which means reloading or dry (a dry Guard walking to cover to reload cannot fire either). `CrewCover.wants_place` is false likewise, so a reloading Marksman Rifle does not queue for a place.
- **Covering fire (ticket 21's question): `can_cover` is unchanged; `covering` is false while reloading.** The spec says a Guard waits for a partner "up and firing", and moves at once only "with no partner able to fire". Ticket 21 already counts a partner down between peeks (him seen within 3 s) as able, since it will be up again soon. A partner reloading down is in the same position. The wait is capped at 3 s anyway. So a reloading partner still counts as able, and the mover waits for its fire up to 3 s. But a reloading partner fires nothing, so it never counts as covering a move, even in the 1 s after its last shot.
- **Signals for ticket 22**: `Crew3D.reload_started(from_empty)`, `shell_loaded`, `reload_ended(broken)`, and `Crew3D.is_reloading()`. A reload started in the open shows `cover.mode == OPEN`; one behind cover shows `DOWN`.
- **Numbers**: the reload factor stays on the Gunnery files (already there, 1.5). The 3 s top-up, 3 m break-off and the back-away numbers are `CrewCover` constants (spec issue 14: "everything else is a named constant"). No Sandbox field was added.

**Existing checks changed, because the spec replaces what they asserted:**

- `tests/test_crew.gd::_check_cover_ring` (ticket 18's 20-peek rhythm): a burst the magazine cuts short (the gun ran dry mid-burst; "the magazine caps it") is left out of the shots-per-burst range and held only to 1 to the Gunnery's highest. A stretch down holding a reload is left out of the time-down range and held to [reload time, max(time down x 1.3, reload + the Shotgun's 0.3 s rack lead)] + 3 frames. The 20-peek counts of uncut bursts and reload-free stretches are unchanged; the loop runs until it has them and at least one reload stretch. The check also gains criteria 1 and 6.
- `tests/test_crew.gd::_check_true_aim` ("at least one aims true whenever any has a clear muzzle line"): a Guard reloading, or dry, no longer counts as having a line. The spec: "A Guard starting a reload gives it up at once".
- `CrewCover.longest_down()`, the limit the smoke run's invariant 4(a) uses, is now max(the time-down limit as before, the gun's longest reload). The longest reload is the Profile's empty time x factor, which the Guard sits out down there whatever happens and which a near miss does not lengthen. Only the Shotgun's changes (2.75 s to 4.2 s); the other three guns' reloads (2.4, 3.45, 3.6 s) sit under their old limits (3.4, 4.05, 6.0 s). The near-miss cap inside `near_miss` still uses the old time-down limit (`_longest_time_down`), so near misses pin no Guard longer than before. The smoke run's code is unchanged; its comment and `docs/agents/validation.md` state the new limit.

**Fixed on the way, outside the ticket:** the first full gate (seed 797068784) failed `_check_cover_fight_on_ship` with "ship fight (medium seed 471708): only 1 of 3 Guards ever got down in cover". From the replay, two Guards were placed at the east end of a long 26 x 10 tile Room with five props. Neither `find(0)` nor the hiding fall-back found anything from there, so both rightly fought in the open all minute. To show it was not this ticket's, I forced the same ship, guns (Marksman Rifle, Assault Rifle, Marksman Rifle) and starting tiles in a clean worktree of the pre-ticket commit 9323751. It fails the same way. The reload code only changed which ship the rolled seed picked, since reload sounds draw from the global RNG for pitch. Fix, in the test rig only: each Guard is re-placed (from the same 5 to 10 m tiles) until it has cover in reach (`find(0)` or the fall-back), so "at least 2 of 3 got down" tests the cover fight and not the room. The replay passes; the forced case passes.

**Median time to die** (`_check_time_to_die`, fixed seeds): unchanged, Pistol 10.08 s at 6 m, Assault Rifle 7.56 s at 7.5 m. Most runs end before the first reload, and the per-run list moved by at most 0.1 s in a few later runs.

**Mutation proof** (crew, seed 859769361): letting a reload not hold the Guard (`_reload_down` returning false while reloading) and removing the top-up fails `_check_cover_ring` (reload stretches too short, all four guns), `_check_reloads` (a shot during the reload; left its tile) and `_check_top_up`. With no Shotgun break-off, `_check_shotgun_reload` fails at 2.5 m.

**For later tickets.**
- 22 (poses): reload pose from `reload_started` to `reload_ended` / `is_reloading()`; the Shotgun's `shell_loaded` per shell. Reloading in the open the Guard walks slowly backward (`_speed_scale` 0.4) facing him.
- 26 (sheet): `reload_factor` is already a Gunnery field on the sheet; `TOP_UP_UNSEEN`, `BREAK_OFF`, `BACK_AWAY`, `BACK_AWAY_SPEED` are constants.
- 27 (smoke firefights): `Crew3D.is_reloading()`; "never more than two aiming true" is unaffected.
- 28 (balance): the crew Shotgun's missing closing pump (above) is a deliberate choice to confirm.

**Validation, on the final code:**
- Full gate twice, both PASS: seed 51435748 (317 s) and seed 479562287 (302 s). Every suite passed: static 178, generator 357186, layouts 252, ship_3d 3720, pirate 2402, crew 401, sandbox 490, attachments 1674, raid_smoke 1104 checks.
- `tests/run_all.sh only=raid_smoke seeds=20`: PASS, seed 275179483, 4383 checks, 661 s. Endings: Quiet 58 Ghost of 60; Loud 59 extracted with a kill of 60; Caught 60 down of 60.
- `tests/run_all.sh only=crew` three more times: PASS on seeds 71386497, 33138292 and 316576607 (401 checks, 48 to 49 s).
- An earlier full gate (seed 797068784) failed only on the ship-fight rig case fixed above; its replay passes. One default smoke run (seed 484247571) passed earlier.
- Screenshots: `tests/shots.sh crew` (PASS, 3 frames), read against the defect checklist with no defects: `front.png`, `side.png` the Guard and the Worker beside a crate, whole, textured, on the floor; `sight_line.png` one thin red line. This ticket adds nothing visible (the reload pose is ticket 22).
- Every headless run here was bounded by `timeout`; none is left running.
