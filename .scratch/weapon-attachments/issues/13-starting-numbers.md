Type: grilling
Status: resolved
Blocked by: 12
Map: ../map.md

# What each Attachment's starting numbers are

## Question

What factor does each of the fourteen Attachments in "Which Slots each weapon has and what the Attachments are" put on each attribute it changes? Fill the table: one row per Attachment, one factor per change, and the Built Weapon numbers that result on every gun it fits (rounds, seconds, degrees, metres heard). Hold each to the findings of the shooter research: no effect under 10%, and the cost felt as much as the gain. "What aim time and swap time feel like on each gun" set the bare values but found no range of what can be felt, so the aim time and swap time factors are chosen on the research's 10% floor alone and flagged for the balance pass. How far off do crew hear each suppressed gun, in metres, against a Room's size? How much faster does a Laser build Awareness? These are starting numbers for the build's checks to assert; the balance pass in the sheet moves them afterwards.

## Answer

Grilled with the user on 2026-11-24; every factor below was accepted as a starting number for the build's checks to assert. The balance pass in the sheet moves them afterwards. No range of what can be felt was found for aim time or swap time, so those factors rest on the research's 10% floor alone.

**Factors** (each multiplies the bare gun's attribute; Weapon Profile fields in backticks)

| Attachment | Gain | Cost |
|---|---|---|
| Reflex Sight | aim time x0.80; `ads_speed` x1.10 | `ads_zoom` x0.85 |
| Combat Scope | `ads_zoom` x1.55, as a lens; `ads_spread` x0.75 | aim time x1.30; `ads_speed` x0.85 |
| Long Scope | `ads_zoom` x1.67, as a lens | aim time x1.35; `ads_sway_degrees` x1.5 |
| Suppressor | `loudness` x0.4; the suppressed shot sound | `projectile_speed` x0.80 |
| Long Barrel | `projectile_speed` x1.25; `spread_base_degrees` x0.85 | aim time x1.20; swap time x1.20 |
| Short Barrel | aim time x0.80; swap time x0.80 | `spread_base_degrees` x1.25; `projectile_speed` x0.85 |
| Extended Magazine | `magazine_size` x1.5 | `reload_tactical` and `reload_empty` x1.25 |
| Quick Magazine | `reload_tactical` and `reload_empty` x0.70 | `magazine_size` x0.8 |
| Drum | `magazine_size` x2.5 | `reload_tactical` and `reload_empty` x1.60; aim time x1.25; swap time x1.30 |
| Foregrip | `recoil_kick_degrees`, `ads_recoil_kick_degrees` and `camera_kick_degrees` x0.70 | aim time x1.15 |
| Laser | `spread_base_degrees` x0.70, with `ads_spread` and `ads_moving_spread` x(1/0.70) so aimed fire is unchanged | conspicuous x1.3 |
| Bipod | `spread_crouch` x0.5; `ads_sway_degrees` x0.5 | aim time x1.20; swap time x1.20 |
| Heavy Stock | `ads_sway_degrees` x0.6; `ads_moving_spread` x0.8 | aim time x1.20; `ads_speed` x0.85 |
| Light Stock | aim time x0.80; swap time x0.80; `ads_speed` x1.15 | `ads_sway_degrees` x1.3; `recoil_kick_degrees` x1.25 |

**Built Weapon numbers the checks can assert**

| | Pistol | Assault Rifle | Shotgun | Marksman Rifle |
|---|---|---|---|---|
| Zoom, bare | 1.6 | 1.6 | 1.15 | 3.0 |
| Zoom, Reflex Sight | 1.36 | 1.36 | 1.0 (floored) | |
| Zoom, scope | | 2.48 Combat | | 5.01 Long |
| Heard at, bare / suppressed (m) | 24 / 9.6 | 24 / 9.6 | 32 / no Suppressor | 24 / 9.6 |
| Bolt speed, bare / suppressed (m/s) | 80 / 64 | 100 / 80 | 60 | 200 / 160 |
| Bolt speed, Long / Short Barrel | | 125 / 85 | 75 / 51 | 250 |
| Hip spread, bare / Long / Short Barrel (degrees) | 1.0 | 1.2 / 1.02 / 1.5 | 5.0 / 4.25 / 6.25 | 3.0 / 2.55 |
| Hip spread, Laser | 0.7 | 0.84 | 3.5 | |
| Rounds, bare / Extended / Quick / Drum | 12 / 18 / 10 | 30 / 45 / 24 / 75 | 6 | 8 / 12 / 6 |
| Tactical reload, bare / Extended / Quick / Drum (s) | 1.2 / 1.5 / 0.84 | 1.8 / 2.25 / 1.26 / 2.88 | | 2.0 / 2.5 / 1.4 |
| Aim time, bare (s) | 0.15 | 0.22 | 0.22 | 0.32 |
| Aim time, fastest and slowest build (s) | 0.12 / 0.15 | 0.11 / 0.59 | 0.11 / 0.37 | 0.26 / 0.75 |
| Sway, bare / Bipod and Heavy Stock together (degrees) | | | | 0.25 / 0.075 |

**Rules settled with the numbers**

- Zoom never goes under 1.0: the Reflex Sight on the Shotgun gives no zoom, not a zoom out. This joins the limits in "How an Attachment changes a weapon".
- No cap on stacked aim time. The slowest builds are slow because that build chose every cost.
- The Bipod and the Heavy Stock both cut sway and stack. The game has no sway by stance, so the Bipod's cut applies standing too; its own job stays the crouched spread.
- The Laser tightens the Shotgun's pellets from 5 to 3.5 degrees, which pushes its one-shot range out. Kept.
- A suppressed shot is heard at 9.6 m against 24 m bare: roughly, the next Room hears nothing.

**Flagged for the balance pass**

- Every aim time and swap time factor (no felt range was found).
- The slowest stacked builds: Assault Rifle 0.59 s and Marksman Rifle 0.75 s to the sights.
- The Laser on the Shotgun.
- The suppressed Marksman Rifle as a Ghost tool, from "Which Slots each weapon has and what the Attachments are".
