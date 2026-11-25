Status: ready-for-agent
Blocked by: 19, 21

# Crew fight in the Sandbox sheet

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 12 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Threat Budget, Health and the Sandbox sheet" and `issues/14`.

- The sheet's Gunnery section: four columns, one per weapon, a row for every Gunnery field (aim error, opening spread, closing time, shots per burst low and high, bursts per peek, burst gap low and high, time down low and high, settle, lead, range band near and far, hold before shifting, reload factor). Edits reach Guards already in the Raid and save to that weapon's Gunnery file.
- A new Crew fight section, one column: how many aim true, the true-aim handover time, the first burst's walk-in distance, the Shotgun pellet cap, suppression time, the too-close distance, the flank reaction, the open floor a Guard will cross in view. Saved with the Sandbox resource.
- `docs/sandbox.md` regenerated from the sheet, and the `sandbox` suite extended.

## Acceptance criteria

- [ ] (agent) The sheet lists four Gunnery columns named for the four weapons and every field above as a row.
- [ ] (agent) Setting the Assault Rifle's aim error to 0 in the sheet makes the next Assault Rifle Guard shot use the gun's own spread only, and leaves a Pistol Guard's unchanged.
- [ ] (agent) Setting "how many aim true" to 1 gives no frame with two Guards aiming true over the next 20 s of a five-Guard fight.
- [ ] (agent) A Gunnery edit saved, then the resources reloaded from disk, keeps its value; the Crew fight values do the same.
- [ ] (agent) `docs/sandbox.md` matches what the sheet writes (the suite's existing doc check).
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) A fight can be retuned from the sheet without leaving the Raid.

## Comments
