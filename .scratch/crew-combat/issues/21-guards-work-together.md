Status: ready-for-agent
Blocked by: 19, 20

# Guards work together

## Parent

Part of `.scratch/crew-combat/spec.md` (Spec: crew combat). Build order 7 of 14. Vocabulary is `CONTEXT.md`'s. Numbers are starting numbers, tuned in the last ticket.

## What to build

See the spec's "Guards together" and `issues/13`.

- Covering fire: a Guard changes cover only while another is up and firing at the Pirate (true or a deliberate miss), waiting up to 3 s; alone, or with no partner able to fire, it moves anyway.
- One mover at a time in a fight, plus one flanker.
- Flank: today's rule, ending at a cover spot inside the far Door picked by the cover rules; exempt from the fair-walk rule between Rooms; needs no covering fire; on giving up at 20 s it takes cover where it stands. Flanker chosen by gun: Shotgun, then Pistol, then Assault Rifle, never a Marksman Rifle. Where his Room has a second Door the Shotgun's doorway ambush is at that Door.
- Suppression: when he breaks sight behind a prop during a fight, Pistol and Assault Rifle Guards that can see the prop fire at its edges for up to 4 s, deliberate misses only; one Guard may move up meanwhile; then they hold.
- A Guard radioed in runs upright until 18 m from the last-seen spot or until it enters a Room joined to his, then follows the cover rules.
- A sweeping Guard that sees him uses the cover rules.
- The last Guard fighting in his Room and the Rooms joined to it stops moving up, picks cover further from him and holds.
- The suppression time lives on the Sandbox resource.
- Update `CREW_AI.md`.

## Acceptance criteria

- [ ] (agent) With two Guards in a fight, whenever one leaves its cover tile for another the other has fired within the previous 1 s, or the mover had waited 3 s, within 0.2 s.
- [ ] (agent) Over a 60 s three-Guard fight, never more than one Guard is between cover tiles at once, not counting a flanker.
- [ ] (agent) In a Room with two Doors and a Shotgun, a Pistol and an Assault Rifle Guard outside, the flanker is the Shotgun Guard, and it ends within 0.5 m of a tile hidden from the Pirate inside the second Door.
- [ ] (agent) A Marksman Rifle Guard is never the flanker over 20 seeded fights.
- [ ] (agent) After the Pirate breaks sight behind a crate, at least one shot is aimed within 0.8 m of the crate's edge in the next 4 s, none is aimed true, and none is fired at it after 4.5 s.
- [ ] (agent) A Guard radioed from two Rooms away is on a cover tile hidden from the Pirate when it first comes within 10 m of him.
- [ ] (agent) With one Guard left, its cover tile 10 s later is further from the Pirate than the one it held, and it does not come nearer in the next 20 s.
- [ ] (agent) `tests/run_all.sh` passes.
- [ ] (human) Guards feel like they are working together: fire picks up when one moves, and hiding does not buy silence.

## Comments
