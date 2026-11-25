class_name WeaponAttributes
extends RefCounted
## What a Weapon Profile's numbers mean to the player, in one place: for each
## attribute, the fields behind it, which way is better, and the words for a
## gain and a cost. The Loadout screen's bars and the line under each
## Attachment both read this, so a bar turns green exactly when the line says
## the part gains there. No Attachment holds words of its own: its line is
## made here from its changes, its lens and its Suppressor.

## Each attribute: `name`; `fields`, the Weapon Profile fields whose product
## it is (and whose factors multiply into an Attachment's effect on it);
## `less`, true when less is better; `gain` and `cost`, the words; `bar` with
## `format`, `lo` and `hi` for the nine the Loadout screen draws (a bar is
## laid out on a log scale from `lo` to `hi`); `same_as`, an attribute whose
## words already say it when the two change by the same factor.
const ALL: Array[Dictionary] = [
	{name = "Zoom", fields = [&"ads_zoom"], less = false, gain = "more zoom", cost = "less zoom",
		bar = 9, format = "%.2fx", lo = 1.0, hi = 6.0},
	{name = "Bolt speed", fields = [&"projectile_speed"], less = false, gain = "faster bolt", cost = "slower bolt",
		bar = 1, format = "%d m/s", lo = 30.0, hi = 300.0},
	{name = "Hip accuracy", fields = [&"spread_base_degrees"], less = true,
		gain = "tighter hip fire", cost = "wider hip fire", bar = 2, format = "%.2f°", lo = 0.3, hi = 8.0},
	{name = "Aimed accuracy", fields = [&"spread_base_degrees", &"ads_spread"], less = true,
		gain = "tighter aimed", cost = "looser aimed", bar = 3, format = "%.2f°", lo = 0.03, hi = 6.0},
	{name = "Aimed on the move", fields = [&"spread_base_degrees", &"ads_moving_spread"], less = true,
		gain = "tighter aimed on the move", cost = "looser aimed on the move", same_as = "Aimed accuracy"},
	{name = "Crouched", fields = [&"spread_crouch"], less = true, gain = "tighter crouched", cost = "wider crouched"},
	{name = "Sway", fields = [&"ads_sway_degrees"], less = true, gain = "steadier aimed", cost = "more sway"},
	{name = "Recoil control", fields = [&"recoil_kick_degrees"], less = true, gain = "less recoil", cost = "more recoil",
		bar = 4, format = "%.1f°", lo = 1.0, hi = 20.0},
	{name = "Aimed recoil", fields = [&"ads_recoil_kick_degrees"], less = true, gain = "less recoil", cost = "more recoil"},
	{name = "View kick", fields = [&"camera_kick_degrees"], less = true, gain = "less recoil", cost = "more recoil"},
	{name = "Magazine", fields = [&"magazine_size"], less = false, gain = "more rounds", cost = "fewer rounds",
		bar = 6, format = "%d", lo = 2.0, hi = 100.0},
	{name = "Reload", fields = [&"reload_tactical"], less = true, gain = "faster reload", cost = "slower reload",
		bar = 7, format = "%.1f s", lo = 0.5, hi = 6.0},
	{name = "Empty reload", fields = [&"reload_empty"], less = true, gain = "faster reload", cost = "slower reload"},
	{name = "Quiet", fields = [&"loudness"], less = true, gain = "quieter", cost = "louder",
		bar = 8, format = "%.0f m", lo = 4.0, hi = 40.0},
	{name = "Handling", fields = [&"aim_time"], less = true, gain = "faster to the sights", cost = "slower to the sights",
		bar = 5, format = "%.2f s", lo = 0.05, hi = 1.0},
	{name = "Aimed walk", fields = [&"ads_speed"], less = false, gain = "quicker aimed", cost = "slower aimed"},
	{name = "Swap", fields = [&"swap_time"], less = true, gain = "faster swap", cost = "slower swap"},
	{name = "Notice", fields = [&"conspicuous"], less = true, gain = "crew notice him later", cost = "crew notice him sooner"},
]
## The words for what is not a factor.
const LENS := "scope lens"
const SUPPRESSED := "suppressed shot"
## Two factors closer than this are the same.
const SAME := 0.0005


## The nine attributes the Loadout screen draws as bars, in bar order.
static func bars() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for attribute in ALL:
		if attribute.has("bar"):
			out.append(attribute)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.bar < b.bar)
	return out


## The attribute called [param attribute_name].
static func named(attribute_name: String) -> Dictionary:
	for attribute in ALL:
		if attribute.name == attribute_name:
			return attribute
	return {}


## [param attribute]'s value on [param weapon]: its fields multiplied, except
## the Reload of a shell-by-shell gun, which is from dry to full.
static func value(attribute: Dictionary, weapon: WeaponProfile) -> float:
	if attribute.name == "Reload" and weapon.shell_reload:
		return weapon.seconds_empty_to_full()
	var out := 1.0
	for field: StringName in attribute.fields:
		out *= float(weapon.get(field))
	return out


## 1 when [param built] is better than [param bare] on [param attribute], -1
## when worse, 0 when the same.
static func verdict(attribute: Dictionary, bare: float, built: float) -> int:
	if absf(built - bare) <= SAME * maxf(absf(bare), 1e-6):
		return 0
	return 1 if (built < bare) == attribute.less else -1


## How far along its bar [param amount] of [param attribute] sits, 0 to 1,
## the better end full: on a log scale, so a factor reads the same on every gun.
static func score(attribute: Dictionary, amount: float) -> float:
	var lo: float = attribute.lo
	var hi: float = attribute.hi
	var s := clampf(log(maxf(amount, lo) / lo) / log(hi / lo), 0.0, 1.0)
	return 1.0 - s if attribute.less else s


## The factor [param attachment] puts on [param attribute].
static func factor(attribute: Dictionary, attachment: Attachment) -> float:
	var out := 1.0
	for field: StringName in attribute.fields:
		out *= attachment.changes.get(field, 1.0)
	return out


## What [param attachment] gains and costs, in one line made from its
## changes: "faster bolt, tighter hip fire · slower to the sights".
static func describe(attachment: Attachment) -> String:
	var gains: Array[String] = []
	var costs: Array[String] = []
	for attribute in ALL:
		var f := factor(attribute, attachment)
		if absf(f - 1.0) <= SAME:
			continue
		if attribute.has("same_as") and absf(factor(named(attribute.same_as), attachment) - f) <= SAME:
			continue
		var gained := verdict(attribute, 1.0, f) > 0
		var words: Array[String] = gains if gained else costs
		var word: String = attribute.gain if gained else attribute.cost
		if not word in words:
			words.append(word)
	if attachment.lens:
		gains.append(LENS)
	if attachment.suppresses:
		gains.append(SUPPRESSED)
	var sides := PackedStringArray()
	for words in [gains, costs]:
		if not words.is_empty():
			sides.append(", ".join(PackedStringArray(words)))
	return " · ".join(sides)


## The red line under the bars when crew notice [param built] sooner than
## a bare gun (its conspicuous above 1): blank when they do not.
static func notice(built: WeaponProfile) -> String:
	var attribute := named("Notice")
	if verdict(attribute, 1.0, value(attribute, built)) >= 0:
		return ""
	var cost: String = attribute.cost
	return cost.left(1).to_upper() + cost.substr(1)
