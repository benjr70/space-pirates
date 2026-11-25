class_name Attachment
extends Resource
## One part fitted to a weapon in one of its Slots: a list of changes, each
## a Weapon Profile attribute times a factor, and the few things that are not
## factors. A new Attachment is a new data file under `resources/attachments/`,
## never new code. It knows nothing about guns: each Weapon Profile lists the
## Attachments that fit it ([member WeaponProfile.fits]), and
## [method WeaponProfile.build] turns a bare Profile and a choice per Slot
## into the Built Weapon. An Attachment does the same thing on every gun.

enum Slot { SIGHT, BARREL, MAGAZINE, UNDERBARREL, STOCK }

## The Slot kind it goes in.
@export var slot := Slot.SIGHT
## Its name as the player reads it: "Reflex Sight".
@export var display_name := ""
## Weapon Profile attribute (by field name) to the factor it multiplies it
## by. Two Attachments on one attribute multiply; order never matters. It may
## never touch damage, the Headshot multiplier, pellet count, semi or
## automatic fire or the shell-by-shell reload: a gun refuses it.
@export var changes: Dictionary[StringName, float] = {}
## A scope: the Built Weapon aims through a lens, magnified by its `ads_zoom`.
@export var lens := false
## The Suppressor: the Built Weapon plays the gun's own suppressed takes
## ([member WeaponProfile.suppressed_shot_sounds]) in place of its shot, so
## one Attachment sounds right on every gun it fits and still knows nothing
## about any of them.
@export var suppresses := false
