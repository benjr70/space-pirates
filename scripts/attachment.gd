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

@export_group("Model")
## What it looks like on a gun: a model in
## `assets/models/attachments/attachments.glb`, by name. A gun is named by
## its model's body mesh (`Pistol`, `AssaultRifle`, `Shotgun`,
## `MarksmanRifle`). These say only what is the Attachment's own;
## [WeaponModel] puts it on.
##
## The model it shows on every gun, built around its mount point:
## `Suppressor`. Blank when the model is per gun ([member models]).
@export var model: StringName = &""
## Per gun where it differs, the model it shows there, built in that gun's
## space: `{&"AssaultRifle": &"AssaultRifle_LongBarrel"}`.
@export var models: Dictionary[StringName, StringName] = {}
## The mount point on the gun its [member model] goes on: `MountSight`,
## `MountMuzzle` or `MountUnder`. Blank for a model built in the gun's space.
@export var mount: StringName = &""
## Per gun, the gun's own part meshes it takes the place of, hidden while it
## is fitted: `{&"AssaultRifle": ["Barrel"]}`. A gun it is not listed for
## keeps all its parts (the Pistol keeps its sights under a Reflex Sight).
@export var hides: Dictionary[StringName, PackedStringArray] = {}
## Per gun, the bone of the gun's skeleton it rides, so the gun's own clips
## move it: a Magazine rides the magazine's bone. Not listed: it sits still
## on the body.
@export var rides: Dictionary[StringName, StringName] = {}


## The model it shows on [param gun] (a gun's model name), blank for none.
func model_on(gun: StringName) -> StringName:
	return models.get(gun, model)


## The parts of [param gun] it hides.
func hides_on(gun: StringName) -> PackedStringArray:
	return hides.get(gun, PackedStringArray())


## The bone of [param gun] it rides, blank for none.
func rides_on(gun: StringName) -> StringName:
	return rides.get(gun, &"")
