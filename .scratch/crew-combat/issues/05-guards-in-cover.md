Type: prototype
Status: resolved
Blocked by: 01
Map: ../map.md

# Guards in cover

## Question

How does a Guard find cover, hold it and peek from it, so a fight reads as trading shots with someone dug in?

Build a throwaway test Room (and one Room plus a Corridor) with crates, low props, a door frame and a corner, a few Guards, and knobs the user can turn while playing. Use what "Fair fire and cover in reference shooters" found workable. Placeholder poses are fine; how it looks is another ticket.

To settle by playing:

- What a cover spot is: behind a prop, beside a door frame, round a corner. Low cover against full cover.
- How a Guard picks one: how far it will go, how it weighs protection against a line of fire, whether it avoids a spot another Guard holds.
- The peek: out to the side or up over the top, how long it stays out, how long it stays down, how regular the rhythm is.
- When it leaves: flanked, cover shot at, Pirate too close, Pirate gone.
- Moving cover to cover toward the Pirate without crossing open floor in his view, and what it does when no cover lies between.
- What happens on first sight with no cover in reach.

The answer records the rules that felt right and the knob values they were played at.

## Answer

Prototyped and played by the user on 2026-11-25: "that feels so much better, let's go with that". Accepted as built, against today's behaviour on the F9 switch. The user reported no knob changes, so the values below are the prototype's defaults and are starting numbers for the Sandbox sheet. Prototype: branch `prototype/guards-in-cover`, commit `5f2bf8c` (`scripts/proto/proto_guards_in_cover.gd`).

**What a cover spot is.** An open floor tile with a wall or a prop on one of its four sides, from which a crouched body (0.9 m) is hidden from the Pirate's last-seen position, and which has a way to shoot. Door frames and corners need nothing special: they are tiles against a wall. Spots are found from the walking grid and sight rays when a Guard needs one; nothing is authored and the ship generator is unchanged. Breakers stay the Pirate's: crew never use them.

**Two kinds, two peeks.**
- Low cover: the Guard can fire over it standing. It crouches behind it and pops up to shoot.
- Full cover: it cannot fire over it. It crouches behind it, steps out to the nearest neighbouring tile with a clear muzzle line, shoots, and steps back.

**Picking a spot.** Filter, then score. Filter: within 8 m of the Guard, in its Room, the Pirate's Room or one joined to either; hidden from him; not held by another Guard; has a peek. Score: near the Guard 20, low cover 40 (full cover half of that), inside its gun's range band 20, minus 20 if another Guard or its spot is within 2 m. One Guard per spot, claimed on choosing, freed on leaving or dying.

**The walk there must be fair.** Of the best six, it takes the first whose route never comes nearer the Pirate than both ends do (less 1 m), and crosses no more than 2.5 m of floor in his view. This is what ends the rush.

**The rhythm.** Down, then up: 0.35 s to settle, then its bursts, then down again. Per gun (shots per burst, bursts per peek, seconds down): Pistol 2 to 3, one, 1.0 to 2.0; Assault Rifle 3 to 5, two bursts 0.4 to 0.8 s apart, 1.5 to 2.5; Shotgun 1, one, 1.2 to 1.5; Marksman Rifle 1, one, 2.5 to 4.0 after a 0.9 s settle. Every time varies by plus or minus 30%. Up with no shot, it waits 1.2 s and ducks. It reloads down, as "Crew magazines and reloads" decided.

**When it leaves.**
- Flanked: the Pirate can see it crouched for 0.4 s. It picks again.
- Too close: the Pirate in sight within 3 m. It picks a spot further off.
- No shot: two peeks running with nothing to shoot at. It picks again.
- Out of its range band after holding 6 s: it moves one spot nearer or further, only for a spot scoring 20% better.
- Pirate out of sight for 5 s: it moves one spot nearer where he was last seen. After 14 s unseen it gives up and searches as today.
- Only one Guard moves up or back at a time.

**Near misses.** A shot of the Pirate's passing within 1.2 m keeps a Guard that is down there 0.8 s longer, and sends one that is up back down.

**No cover in reach.** It falls back to the nearest tile where he cannot see it standing, searching out to 14 m without the fair-walk rule, and looks again for real cover each second. With nowhere to hide either, it fights where it stands in bursts and pauses, looking for cover every 1.5 s.

**Who is driven.** A Guard in a fight whose last-seen spot for the Pirate is within 18 m. Further off, and while flanking, today's hunt carries it.

**Aim, as played.** The cone opened at 3x and closed to the gun's own spread over 2 s. This is what the user played against; "Gunnery that feels fair" decides it properly.

**Not built, so not judged.** One Guard firing to cover another's move; leaving cover because the cover itself is being shot; any pose (the crouch was a body sunk into the floor); a Marksman Rifle tell beyond the long settle. Range bands used were the research's starting numbers (Shotgun 2 to 5 m, Pistol 4 to 8, Assault Rifle 5 to 10, Marksman Rifle 8 to 14) and belong to "Where each gun stands".

## Comments

2026-11-25: prototype built on local branch `prototype/guards-in-cover` (commit `5f2bf8c`, local, never merged). Scene `scenes/proto_guards_in_cover.tscn`, brain `scripts/proto/proto_guards_in_cover.gd`, one hook in `scripts/crew/crew.gd` (`proto_brain`). Run:

    flatpak run org.godotengine.Godot --path . res://scenes/proto_guards_in_cover.tscn -- --seed=12 --class=medium

Not built in it: Guards sharing fire while one moves, and a Guard leaving because its cover is being shot (a near miss only keeps it down or ducks it).
