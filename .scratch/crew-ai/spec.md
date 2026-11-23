Status: ready-for-agent
Imported from: GitHub #52 (retired tracker). `#NN` below are the old GitHub ticket numbers; #53–#62 are built and closed, #63 lives on as `issues/11-officer-crew-type.md`.

# Spec: crew AI that lives on the ship and notices the pirate

Spec assembled from a grilling session on 2026-10-16. This document is the build-order view; every ticket below carries its slice in full. Vocabulary is `CONTEXT.md`'s; the new crew terms (Awareness, Post, Job, Guard, Worker, Alarm, Alarm Panel, On Edge, Ghost) are added there by the tickets that introduce them.

## Problem Statement

The crew feel staged and unnatural. Each crew member wanders random points inside the one Room it spawned in and never leaves it before contact. It sees the Pirate instantly through 360° anywhere within 14.4 m of clear line, with no facing, no reaction time and no difference for a crouched Pirate. It hears nothing: a gunshot alerts nobody, and only a crew member who is hit learns roughly where the shot came from. Nobody shares what they know. Combat is a fixed loop (a three-round burst, cover to reload, lean out) that every crew member runs in lockstep, and three seconds out of sight sends them to the last-seen point for 2.5 s and then back to wandering. Every Room is therefore a guaranteed gunfight, the back-hit melee kill has no approach to reward, and the ship never feels like it is going about its day while it is robbed.

## Solution

A crew that lives on the ship before the Pirate arrives and notices him the way people would. Every crew member is a **Guard** or a **Worker** with a **Post** and a loop of **Jobs** that walks them between Rooms. Each builds **Awareness** of the Pirate gradually, from sight in a forward cone, from sound, and from traces he leaves (bodies, emptied Containers, doors left open, the open boarding Hatch), shown over its head as a marker filling white, yellow, red. Workers who spot him run for help or an **Alarm Panel**; Guards fight together, sharing his position, pinning and flanking, with aim that tightens the longer he stays exposed. A raised ship-wide **Alarm** turns the robbery into a hunt for the rest of the Raid. Stealth is rewarded with XP. The whole system lives in `scripts/crew/` and is documented in `scripts/crew/CREW_AI.md`, kept current by every ticket.

## User Stories

1. As a pirate, I want crew to notice me only in front of them, so that I can approach someone from behind and use the back-hit melee kill.
2. As a pirate, I want being spotted to take time that grows with distance and with crouching, so that I can see it coming and back off.
3. As a pirate, I want a marker over each crew member's head that fills white, yellow and red, plus a sound when one tips into red, so that detection never feels random.
4. As a pirate, I want sprinting to be loud, walking quiet and crouching silent, so that how I move is a stealth decision.
5. As a pirate, I want my gunshots to carry through open doorways to nearby Rooms, so that going loud has a cost I can read.
6. As a pirate, I want crew to walk between Rooms doing jobs, so that the ship feels alive and timing a route through it matters.
7. As a pirate, I want Guards and Workers to look and act differently, so that I can read a Room and pick my target.
8. As a pirate, I want a Worker who spots me to run for help or an alarm panel, so that I face a chase-or-prepare decision.
9. As a pirate, I want a ship-wide alarm that someone must reach a panel to raise, so that stealth has a clear stake.
10. As a pirate, I want to shoot out an alarm panel at the price of the noise, so that I can plan ahead.
11. As a pirate, I want a raised alarm to turn the lights red, stop routines and send Guards hunting, so that getting caught changes the Raid.
12. As a pirate, I want crew who lose me to search and then stay on edge rather than forget me, so that being seen has a lasting cost.
13. As a pirate, I want Guards to share my position, pin me and flank through another door, so that fights feel like a team, not a loop.
14. As a pirate, I want a Guard's first shots to mostly miss and their aim to tighten while I stay exposed, so that a fight warns me before it kills me.
15. As a pirate, I want crew to find bodies where they fell and raise the alarm, so that where I kill someone matters.
16. As a pirate, I want crew to notice emptied Containers, doors left open and my open boarding Hatch, so that robbing the ship leaves traces I must manage.
17. As a pirate, I want crew to be able to follow me into my Boarding Pod, so that extraction under fire is a real risk.
18. As a pirate, I want more XP for kills on crew who have not noticed me and a Ghost bonus for extracting with the alarm never raised, so that stealth is worth its time.
19. As a player, I want to pick the Guard and Worker models by eye in the model booth, so that the crew look the way I want.
20. As a developer, I want the crew AI split into one script per concern under `scripts/crew/` with `CREW_AI.md` beside it, so that each ticket touches one piece and the design stays written down.
21. As a developer, I want perception, Awareness, routines, the Alarm and stealth XP covered by headless checks, so that feel decisions cannot regress silently.

## Implementation Decisions

### Structure and documentation
- `scripts/crew_3d.gd` (560 lines) is split into `scripts/crew/`: a slim `crew.gd` body (movement, health, animation, the state machine) plus one script per concern: perception and Awareness, hearing, routine, combat, crew types, and the ship-wide Alarm. Exact split is the first ticket's call; the concerns are fixed.
- `scripts/crew/CREW_AI.md` documents the system: states and transitions, every perception input and its numbers, routines, Alarm, combat rules, crew types and tuning constants. Every ticket that changes behaviour updates it in the same commit.
- New terms go into `CONTEXT.md` as they land.

### Awareness and sight
- Per crew member, an **Awareness** value 0 to 1 with three bands: unaware, **suspicious** (comes to look), **spotted** (combat or flight).
- Sight is a **110° forward cone**, eye-height line of sight on the world layer, range 14.4 m. Outside the cone, sight contributes nothing.
- Time to spotted, standing in the open, square in view: **~0.3 s within 3 m, ~1.5 s at 10 m, ~3 s at 14 m**, interpolated. Crouching **doubles** it. Starting values; tuned by playtest.
- Awareness decays slowly out of view. An unaware crew member glances around (head turns) now and then so the cone moves.
- A marker over the head fills white, yellow (suspicious), red (spotted); shown while on screen or near. A sting plays when any crew member tips into red.
- Light and shadow are out: every Room is evenly lit.

### Hearing
- Noise events carry a loudness and a position. Footsteps: **sprint loud, walk quiet, crouch silent**. Gunshots are loud and carry through **open** Doorways to neighbouring Rooms. Doors opening and closing make noise.
- Hearing raises Awareness toward suspicious and gives a position to investigate; only sight (or an Alarm) makes a crew member spotted.

### Routines
- Every crew member has a **Post** (home Room) and a loop of **Jobs**: walk to a Room, work at a prop there (console, crate, engine console, locker) for a while, move on. Guards' Jobs are patrol routes through Corridors and between Rooms; pairs sometimes stop to chat.
- The per-Room crew counts the Threat Budget already produces become where each crew member **starts** its routine, not a cage; the Armory still starts busy.
- Crew close Doors behind them on routine. Routes ride the existing door graph via `ShipNavigator`.

### Crew types
- **Guard**: armed and trained. Posted to the Armory and Bridge (and patrol routes). Full combat behaviour.
- **Worker**: Jobs in Engine, Cargo, Shield and Medbay. On spotted, most run for the nearest Guard or Alarm Panel; a few hide behind cover in their Room; fights back with a weak sidearm only when cornered.
- Type is assigned from the Post Room's Role at build time. Until the model booth pick lands, Workers carry a colour tint.
- **Officer** is deferred to the last ticket.

### Ship-wide Alarm
- **Alarm Panels** in the Bridge and Armory, possibly Corridors. A crew member who reaches a working panel raises the **Alarm**.
- Raised Alarm: lights turn red, routines stop, Guards hunt the Pirate's last known position, Workers hide or arm. It stays on for the rest of the Raid.
- The Pirate can **shoot a panel out**; the shot is a gunshot noise like any other.
- Individuals who lose the Pirate search with nearby crew, then return to routine **On Edge** (faster Awareness, Guards patrol more). Nobody returns to fully unaware.

### Guard combat
- Guards share the Pirate's last known position with Guards in the same and neighbouring Rooms.
- One pins (keeps firing from cover) while another takes another Door to **flank**, using the door graph.
- Aim starts loose and **tightens the longer the Pirate stays exposed** to that Guard; resets when he breaks line of sight.
- Burst size, peek and hold timings are jittered per Guard so no two move in step. No grenades.

### Traces
- **Bodies** stay where they fall; a crew member who sees one becomes suspicious and goes to raise the Alarm. No dragging.
- Emptied Containers, Doors left open that are normally shut, and the open boarding Hatch with the Boarding Pod outside all raise suspicion through the same path. The open boarding Hatch is a strong trace: crew come to look and can find the Pod.
- The Boarding Pod is not a safe zone: hunting crew can enter it during the Extraction countdown.

### Stealth XP
- A kill on a crew member who is not spotted-aware earns **1.5×** kill XP.
- **Ghost** bonus on Extraction if the Alarm was never raised. No reward for zero kills.

## Testing Decisions
- Headless checks in the existing suites (`tests/test_ship_3d.gd` and helpers) for: the sight cone (in front sees, behind does not), Awareness timing bands at 3, 10 and 14 m and doubling when crouched, noise loudness by stance and gunshots crossing open but not shut Doors, routine crew leaving their Post Room, Worker flight and Alarm raising at a panel, a shot-out panel refusing, On Edge after a lost search, Guard aim tightening with exposure, body and trace suspicion, and the stealth XP multipliers and Ghost bonus through `RaidLedger`.
- Feel (timings, marker readability, routine believability) is judged in playtest after each ticket, not on paper; tickets keep their numbers as exported constants.

## Out of Scope
- Light and shadow as a stealth factor.
- Dragging or hiding bodies.
- Grenades and equipment, for crew and Pirate.
- Voice barks with recorded audio (text or sound cues only).
- Hold-to-search Containers and Container search timers.

## Tickets (build order)

1. #53 Crew folder split, sight cone and Awareness meter
2. #54 Hearing: footsteps by stance, gunshots and doors
3. #55 Routines: Posts, Jobs and crew roaming between Rooms
4. #56 Guard and Worker crew types
5. #57 Ship-wide Alarm and Alarm Panels
6. #58 Guard combat: shared position, pin and flank, aim that tightens
7. #59 Bodies are found where they fall
8. #60 Traces of the robbery: emptied Containers, doors left open, the boarding Hatch
9. #61 Stealth XP: unaware kills and the Ghost bonus
10. #62 Model booth: pick the Guard and Worker models
11. #63 Officer crew type (later)

Playtest after each ticket before starting the next.

