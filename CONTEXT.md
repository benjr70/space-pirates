# Context

Glossary for Space Pirates. Terms here are the canonical names; code should use
them verbatim. Implementation lives in the code, decisions in `docs/adr/`.

## Ship Layout

A whole ship expressed as data: its rooms, the doors between them, and the
hatches through its hull. Every ship the game builds — the pirate's own and
every raid target — is a Ship Layout. Whether one was hand-authored or
generated from a seed is not a distinction anything downstream cares about.

## Room

One compartment of a ship, described in tile coordinates. A Room's floor is its
walkable area; the wall ring around it is implied. Hand-authored Rooms are
usually single rectangles; any Room may be a union of abutting rects forming
one open space (generated ones are clipped against the Hull).

Every non-corridor Room must clear the Fight Core floor — the minimum was
walk-tested in first person, not derived on paper.

## Seam

The shared edge between two abutting rects of the same Room. A Seam is open
floor, never wall: the builder walls the ring around each rect and then
removes anything that is floor, so the Seam disappears into the Room. Each rect
is convex, so crew steer straight inside one and cross a Seam at a chosen
point when their route needs the neighbouring rect.

## Fight Core

The clear axis-aligned rectangle a Room must contain somewhere inside it for a
first-person firefight to work: space to break line of sight, take cover and
flank. The fightable-floor invariant is an inscribed Fight Core plus a minimum
total floor area; corridor Rooms of the Skeleton are exempt and carry their own
narrower width floor instead.

## Room Role

What a Room is for. Roles are a closed set — Bridge, Engine, Shield, Armory,
Cargo, Medbay, Quarters and Corridor — and a Role is the unit of interior
generation: each Role knows how to furnish and crew its own rect. Every Room has
exactly one Role. Which Room gets which Role is a ranking over the finished
partition, read from Flow Distance and Hull Exposure, so assignment always
produces an answer and never sends a ship back to be repacked.

## Bridge

The Room Role a ship is flown from. There is no separate "cockpit" Role — a
one-seat cockpit and a capital ship's bridge are the same Role at different
sizes and prop densities.

## Corridor

The Room Role of a Skeleton's walkway. A Corridor is a Room like any other but
never counts toward a Ship Class's Room count, never takes a Hatch, and is
exempt from the Fight Core floor in favour of a minimum width.

## Flow Distance

How deep a Room is: the fewest Doors a pirate must pass through to reach it from
the nearest Hatch. A Room holding a Hatch has Flow Distance zero. The Armory is
the deepest Room on the ship, which is what makes reading a silhouette worth
doing.

## Hull Exposure

How much of a Room's wall is Hull. Rooms that load and unload — Cargo — sit
against the skin; Rooms worth guarding do not.

## Hull

The outer boundary of a ship: every wall tile reachable from outside the ship.
A wall tile sealed inside a pocket between Rooms is not Hull, even though no
Room lies on its far side.

Generated Hulls are built outline-first as a union of **Masses** and are
deliberately asymmetric: exploring one flank must not reveal the other.

## Mass

One solid lump of a generated Hull's outline. A ship has a main Mass shaped by
its archetype (wedge, hammerhead, saucer, block, boomtail) plus zero or more
secondary Masses (side pod, cockpit boom, aft wing, blister) hung off one side.
Rooms are packed flush against the union of all Masses.

## Skeleton

The corridor structure a generated ship's Rooms hang off: a fore–aft spine, a
ring around a central core, or a chain of Rooms opening directly into each
other. Carved out of the Hull before any flank Room is placed.

## Sliver

A patch of floor left over when Rooms are clipped against a ragged Hull —
along a prong, a pod, a blister edge or a taper — that is too small or too
thin to clear the Fight Core floor. A Sliver never survives as a Room: it is
merged into the neighbouring Room it shares the most wall with, or it becomes
Bulk.

## Bulk

Space inside the Hull that has no floor: machinery, plating, tankage. Bulk is
how a generated ship keeps its silhouette where a Sliver could not become a
Room. Bulk is solid, so it is never walked, never lit and never takes a Door or
a Hatch.

## Apron

The floor straight in front of a Door or Hatch, inside a Room, that no prop
may occupy: the space a pirate steps into before the fight starts. Every Role
keeps its Aprons clear.

## Breaker

The first piece of cover past a doorway's Apron, set to one side of the line
through the door. A Breaker belongs to whoever enters: crew never take
position behind one. It is what turns walking through a Door into a decision
rather than an ambush.

## Lane

A straight sightline joining two doorways, through a Room or across a
Corridor. A Lane inside a Room is broken by a full-height prop; a Lane across
a Corridor cannot be, so Door placement never lets two doorways face each
other across one.

## Door

A gap punched through the wall shared by two Rooms. Interior only — a Door
always joins exactly two Rooms.

## Hatch

A gap through the Hull, joining one Room to the outside. Hatches are permanent
features of a ship, placed when it is generated. They are how a raid begins and
how it ends: the pirate chooses a Hatch to board through and leaves through a
Hatch to extract.

A Room holds at most one Hatch, and every ship has at least two, one of them
always into a Cargo Room — the legible boarding point a silhouette can be read
by. A Bridge or Engine Room never takes a Hatch. Which Hatch a raid enters
through is a choice made at Raid start, not a fact about the ship.

## Boarding Pod

The pirate's own airlock tube, docked outside the one Hatch a Raid boards
through. A Raid starts inside it, facing the shut Hatch; it is the way home.
Every other Hatch has nothing docked outside and is **sealed**: locked for
good and striped so it never reads as an ordinary Door.

## Awareness

How much one crew member has noticed the Pirate, from unaware through
**suspicious** (it comes to look) to **spotted** (it fights or flees). Built
up by seeing him in a forward cone, faster the closer and the more upright he
is, and drained slowly once he is out of view. Being shot spots him at once.
Shown over each crew member's head as a bar filling white, yellow, red.

## Post

The Room a crew member belongs to: where it starts the Raid (the Threat
Budget decides how many start in each Room) and where its routine keeps
bringing it back.

## Job

One stop in a crew member's routine: working at a prop in some Room for a
while, or pausing at a Room on a patrol route. A crew member loops through
its Jobs until something makes it suspicious, then picks up where it was.

## Guard

A crew member posted in the Armory, Bridge or a Corridor (and half of
Quarters): armed and trained, walks patrol routes between Rooms, and hunts
and fights the Pirate once it spots him.

## Worker

A crew member posted in the Engine, Cargo, Shield or Medbay (and half of
Quarters): works at props around the ship, and on spotting the Pirate runs to
raise the nearest Guard or hides. It fights back only when cornered.

## Alarm

The ship-wide state a crew member raises by reaching an Alarm Panel. Once
raised it stays up for the rest of the Raid: the lights turn red, routines
stop, Guards hunt and sweep the ship, Workers hide.

## Alarm Panel

A wall panel in each Bridge and Armory from which the Alarm is raised. The
Pirate can shoot one out so it raises nothing, at the cost of the noise.

## On Edge

How a crew member stays once it has lost the Pirate or heard the Alarm: it
goes back to its routine but spots him faster, and never returns to fully
unaware for the rest of the Raid.

## Raid

One visit to a target ship: board through a Hatch, take what can be taken,
extract through a Hatch. Space Pirates is an extraction shooter, so a Raid that
is not extracted from is a Raid whose gains are not kept.

A Raid's target is picked on the main menu as a Ship Class and rolled a fresh
seed. Dying offers a Retry, which boards the same seed again with every crew
member back at their post, or the way back to the menu to pick another.

## Extraction

Getting out of a Raid alive, the way the pirate came: once he has set foot
aboard, he works the home door at the back of his Boarding Pod and waits out
a countdown inside the tube. Stepping out of the pod or going down calls it
off. An extracted Raid offers a New Raid on a fresh ship of the same Class;
a lost one offers a Retry of the same ship.

## XP

What the pirate earns for kills and for extracting, and keeps whichever way
a Raid ends. XP adds up across Raids into his level.

## Ghost

An Extraction with the Alarm never raised. It earns a bonus on top of the
extraction XP, as kills on crew that never spotted the Pirate earn more than
kills in a fight.

## Loot

Gold taken from Containers during a Raid. It is carried, not kept: only an
Extraction banks it into the pirate's hold. Going down, or walking away from
the Raid, leaves it on the ship.

## Ship Class

How big a ship is, counted in Rooms: small, medium or large. A Class is chosen
before a ship is generated, not inferred from one afterwards — it is what a
target is advertised as before boarding, and what the Threat and Loot Budget
curves are read from. Rooms stay roughly the same size at every Class, so a
larger ship is one with more compartments rather than bigger ones.

## Mandatory Role

A Room Role a ship of a given Class must have at least one of. The rest of a
ship's Rooms are filled from the optional pool, so a ship that comes out smaller
than expected is still a legal ship.

## Threat Budget

The number of hostile crew a generated ship holds, counted in bodies. Read from
the Ship Class and the ship's Richness, then split across Rooms by Role weight
into each Room's Threat Share; the Shares always sum to the Budget exactly. A
Room's Threat Share is what its Role hands to interior generation — where the
crew stand is the Role's business, how many is not.

## Richness

One roll a generated ship makes that positions both its Threat Budget and its
Loot Budget inside their Class bands. A ship is never crewed heavily and poor,
or rich and undefended: danger and reward rise together within a Class as they
do across Classes.

## Loot Budget

The gold a generated ship holds, in total. Read from the Ship Class and the
ship's Richness, then split across Rooms by Role weight into each Room's Loot
Share; the Shares always sum to the Budget exactly. A Room turns its Loot Share
into Containers. For now loot is gold and nothing else: items and inventory are
a later system.

## Container

A prop the pirate opens to take gold. Distinct from cover: a Container is
something to loot, whether or not it also blocks a sightline. Each Room Role
has its own kind of Container — a Cargo crate and an Armory locker are
different props — and a Room's Loot Share decides how many it holds and how
much each one is worth.

## Pirate

The player: the one body boarding a target ship on a Raid, seen in first
person. Everything the pirate can do with their body or weapon is a
first-person mechanic in the sense used by Halo Infinite: no visible body,
only the Viewmodel and the camera.

## Viewmodel

The weapon as the Pirate sees it, drawn in front of the camera. It is the
whole of first-person animation: firing, reloading, lowering for a Sprint and
swinging a Melee are all things the Viewmodel does, together with camera
motion. There are no visible arms or legs.

## Sprint

The Pirate's fast run, held rather than toggled. Sprinting lowers the
Viewmodel: a Pirate cannot fire or Melee while sprinting, and either input
ends the Sprint.

## Crouch

The Pirate's low stance, held rather than toggled. Crouching is what a Pirate
does behind cover, and it is the input that turns a Sprint into a Slide.

## Slide

A ground dash begun by crouching during a Sprint. A Slide keeps the Sprint's
momentum and lets the Pirate fire, which is what makes sprinting into a Room
a play rather than a mistake.

## Clamber

Pulling up onto a ledge. A Clamber is what a jump becomes when a reachable
ledge is in front of the Pirate: the same input, no separate key. What counts
as a reachable ledge is a fact found by walk-testing, not by rule.

## Melee

A close-range strike with the weapon, delivered as a lunge. A Melee that lands
from behind kills; one from the front does not, so flanking is rewarded the way
the ship's Lanes and Breakers are built to reward it. The weapon is busy for
the swing's cycle: no shot or reload until it ends. A Melee drops a running
reload with nothing gained, and it is refused only during a Clamber.

## Pistol

The Pirate's handgun: semi-automatic, one shot per trigger press, firing a
projectile like every other weapon in the game. Crew carry it too: a Guard's
Pistol is the Pirate's Pistol, handled with a Guard's Gunnery. Nothing in Space Pirates is
hitscan, so every weapon is a variation on the same shot. A dry pull, the
trigger on an empty magazine, clicks once and starts the reload; the HUD's
crosshair opens with the Pistol's spread, and a landed hit flashes a marker
with a tick, red when it killed.

## Assault Rifle

The Pirate's long gun: fully automatic, firing for as long as the trigger is
held, with a bigger magazine and a longer reload than the Pistol. It is a
second Weapon Profile and nothing else.

## Shotgun

The Pirate's doorway gun: pump-action, firing a spread of pellets that kills
in one shot up close and falls away fast with distance. It loads one shell at
a time, and a reload broken off keeps the shells already in. It is the loudest
weapon he carries, and the one a Slide does not spoil.

## Marksman Rifle

The Pirate's precision gun: semi-automatic, one deliberate shot per press,
killing with a single shot to the head. It is poor fired from the hip and
exact in Aim Down Sights held still, so it asks for the commitment a Descope
punishes. Its shot is the fastest and reaches the furthest.

## Headshot

A shot that lands on a crew member's head rather than the body. Each weapon
says how much more a Headshot hurts; for some it is no more at all. Only crew
have a head to hit: nothing that strikes the Pirate is a Headshot.

## Weapon Wheel

How the Pirate changes what he holds: the mouse wheel turns through the
weapons of his Loadout, either way round, and a number key picks one outright. A
weapon keeps the rounds it had when it was put away. The swap takes a beat, as
long as the weapon being drawn needs, in
which he cannot shoot, aim or reload, and it drops a running reload with
nothing gained, save the shells a Shotgun had already taken. A Clamber or a
Melee refuses it.

## Aim Down Sights

Raising the weapon to its sights, held rather than toggled: the view zooms a
little, the Pirate slows a little and shots land tighter. The sights take a
moment to come up, longer for a bigger gun, and what aiming gives comes in as
they rise. Any move that needs
the weapon elsewhere — a Sprint, a Slide, a Clamber, a Melee, a reload — ends
it, and so does being hit, which is what makes a pistol duel swing. Jumping
does not. Between aiming and sprinting the newer input wins: pressing aim ends
a Sprint, and starting a Sprint drops the sights.

## Descope

Being hit while Aiming Down Sights: the sights drop and the view flinches, so
a duel swings on every hit. Held aim brings them back after a short recovery,
and a fresh press brings them back at once; a Descope costs a beat, not the
fight.

## Weapon Profile

One weapon's whole behaviour as data: how it fires, how many shots it holds,
how long it reloads, what its shot is, how tight it groups and how far off
crew hear it. A new weapon is
a new Profile, never new code; the Pistol is the first and the Assault Rifle
the second. Modifiers for later
weapon types are variations on a Profile's shot, which is why nothing is
hitscan.

## Attachment

One part fitted to a weapon that changes how it behaves and how it looks: a
scope, a longer barrel, a bigger magazine. Every Attachment costs something
for what it gives, so none is simply better than going without. It never
changes what kind of gun the weapon is: how hard a shot hits and how the gun
fires and loads stay the weapon's own. An Attachment does the same thing to
every weapon it fits. Only the Pirate's weapons take them; crew carry theirs
bare.

## Built Weapon

A weapon as the Pirate carries it: its Weapon Profile with every fitted
Attachment's changes applied. It is still a Weapon Profile, so nothing about
shooting knows an Attachment was involved. It is worked out from the Loadout
and never kept: change the weapon or an Attachment and it is built again.

## Slot

A place on a weapon an Attachment fits. There are five kinds: Sight, Barrel,
Magazine, Underbarrel and Stock. A Slot holds one Attachment or none, and a
weapon has only the Slots that make sense for it, so some weapons take more
Attachments than others. The weapon says which Attachments fit each of its
Slots. A weapon with every Slot empty is the weapon as it comes.

## Loadout

What the Pirate takes on a Raid: two different weapons, a first and a second,
each as he has fitted it. The first is the one in his hands when the Raid
starts. Every weapon remembers its own Attachments whether or not it is in the
Loadout. It is set on the main menu, kept between sessions, and used by every
Raid and Retry until he changes it there. Before he has ever set one it is the
Pistol and the Assault Rifle, bare.

## Sandbox

Every weapon in the game taken together, and how their numbers sit against
each other: every Weapon Profile, each crew type's Gunnery, and the Health of
the Pirate and the crew. Balancing is done to the Sandbox, never to one weapon
alone. How crew see, move and take cover is behaviour, not Sandbox.

## Gunnery

How well a wielder handles a weapon, apart from what the weapon is: the aim
error it adds to the weapon's own cone, how long a burst it fires, how long it
pauses between bursts and how far off it opens fire. Each crew type has its
own Gunnery. The Pirate has none: the player's hands are his.
