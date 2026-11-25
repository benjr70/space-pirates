Status: ready-for-agent

# A Gunnery per weapon and the gun roll

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 1 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Which Guard carries which gun" and "Fair fire" (Gunnery's shape), and `issues/03`, `issues/06`.

- Gunnery becomes one Resource per weapon under `resources/gunnery/` (pistol, assault_rifle, shotgun, marksman_rifle) with the spec's fields and starting numbers: aim error; opening spread multiple and closing time; shots per burst (low, high); bursts per peek; gap between bursts; time down (low, high); settle; lead; range band; hold before shifting; reload factor. `guard.tres` and `worker.tres` go. Fields nothing reads yet are still filled in; later tickets use them.
- The gun roll in `ShipBuilder3D`: base weights by Ship Class slid by Richness, Post Room multipliers, the caps, a re-roll on a broken cap, in a fixed order from its own random stream seeded off the layout's seed. Each Guard gets its Weapon Profile and that weapon's Gunnery. Workers get neither.
- Guards fight as they do today, but with their own gun: its damage, projectile, time between shots, pellets (every pellet of a Shotgun shot is fired), sounds and loudness, and bursts of the Gunnery's shots-per-burst. Aim error comes from the weapon's Gunnery. Nothing else about behaviour changes in this ticket.
- Workers no longer fire: remove the cornered fight and the Worker's Pistol. A cornered Worker cowers, until the Workers ticket replaces that.
- The Sandbox sheet keeps working: its Gunnery section shows the four weapon Gunneries (the full layout is a later ticket).
- Update `CREW_AI.md` and `docs/sandbox.md`.

## Acceptance criteria

- [ ] (agent) Over the generator suite's seed sweep, no small ship has a Marksman Rifle, no medium ship more than 1, no large ship more than 2, no Room two, and no Room of three or more Guards is all Shotguns.
- [ ] (agent) Over at least 200 large ships at Richness 1.0, the share of Guards with each gun is within 5 percentage points of what the weights and Post Room multipliers predict for those ships' Guards.
- [ ] (agent) Building the same layout twice gives every Guard the same gun; a layout built before and after an unrelated extra random draw elsewhere in the build still gives the same guns.
- [ ] (agent) No Worker has a weapon or fires in 30 s cornered within 3 m of the Pirate.
- [ ] (agent) A Shotgun Guard's shot spawns 12 projectiles; a Marksman Rifle Guard's projectile travels at 200 m/s within 1%.
- [ ] (agent) Each of the four Gunnery files loads with the spec's aim error (7.5, 6, 8, 0 degrees) and range band.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) A ship's Guards visibly differ in how they shoot, by sound alone.

## Comments
