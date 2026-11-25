Type: grilling
Status: resolved
Map: ../map.md

# Crew magazines and reloads

## Question

Crew guns get magazines and reloads. How much of a Weapon Profile does a Guard now obey?

- Magazine size and reload time: the Profile's own, or scaled for crew.
- Where a Guard reloads: only behind cover, or wherever the magazine runs dry. What it does when caught empty in the open.
- The Shotgun's shell-by-shell reload: whether a Guard breaks it off to fire, as the Pirate can.
- Which Profile fields crew still ignore (bloom, recoil, Aim Down Sights, sway) and which Gunnery now replaces or sits on top of.
- What the Pirate sees and hears of a reload, so the window can be read.
- Whether burst length in Gunnery still exists once a magazine does, and how the two relate for a pump Shotgun and a semi-automatic Marksman Rifle.

## Answer

Grilled with the user on 2026-11-25. Numbers are starting numbers, tuned in the Sandbox sheet.

**What a Guard obeys.** From its Weapon Profile: magazine size (Pistol 12, Assault Rifle 30, Shotgun 6, Marksman Rifle 8), both reload times, the Shotgun's shell-by-shell reload, the time between shots, pellets, damage, the projectile, the reload and shot sounds, and loudness. It still ignores bloom, recoil, Aim Down Sights, sway, movement spread and swap time; Gunnery's aim error stands in for them. There is no crew-only magazine size.

**Ammunition.** A Guard counts every shot. It has unlimited magazines, and starts every Raid and every Retry with a full one.

**Reload time.** A Guard reloads slower than the Pirate: the Profile's time times a crew reload factor, starting at 1.5 (an empty Assault Rifle takes about 3.5 s). The factor is a Gunnery number, not a Profile field. Whether Gunnery is per weapon or per crew type is for "Gunnery that feels fair".

**Burst and magazine.** Burst length stays in Gunnery as the shots fired per peek; the magazine caps it. A Guard fires bursts until the magazine is dry, then reloads. A Shotgun or Marksman Rifle Guard fires one shot per peek. Burst lengths per weapon are for "Gunnery that feels fair".

**Where it reloads.** A Guard that runs dry goes to cover first and reloads there. With no cover in reach it reloads where it stands, backing away from the Pirate. It never fires during a reload.

**A reload always finishes.** Being shot, flanked or closed on does not cancel or restart it. The Guard keeps facing where it last saw the Pirate, finishes, then acts. The one exception is the Shotgun.

**Topping up.** In cover with the Pirate out of sight for 3 s, a Guard tops up a part-used magazine, using the Profile's shorter reload time and the same factor.

**The Shotgun.** It loads shell by shell with the Profile's times and the same factor. If the Pirate is in sight within 3 m while it has at least one shell in, it breaks off and fires; otherwise it loads to full.

**Reading it.** The Profile's own reload sounds play at the Guard's position, and the Guard plays a reload clip, down behind its cover. There is no HUD marker. Whether the sound alone reads well enough is owed to playtest; a shouted callout is a later option.

**Left to another ticket.** Whether another Guard steps up its fire while one reloads goes to "Gunnery that feels fair", with the question of who is allowed to hit.

**Glossary.** `CONTEXT.md`: Gunnery gains how slowly a wielder reloads.
