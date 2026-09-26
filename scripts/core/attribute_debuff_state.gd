class_name AttributeDebuffState
extends RefCounted
## Independent timed reductions/increases, keyed by attribute and application source.

const PHYSICAL_DEFENSE: StringName = &"physical_defense"
const MAGIC_DEFENSE: StringName = &"magic_defense"
const FLEE: StringName = &"flee_rating"
const MOVE_SPEED: StringName = &"move_speed"
const ATTACK_SPEED: StringName = &"attacks_per_second"
const DAMAGE_DEALT: StringName = &"damage_dealt_multiplier"
const DAMAGE_RECEIVED: StringName = &"damage_received_multiplier"

const LIMITS := {
	PHYSICAL_DEFENSE: 0.60,
	MAGIC_DEFENSE: 0.60,
	FLEE: 0.50,
	MOVE_SPEED: 0.50,
	ATTACK_SPEED: 0.50,
	DAMAGE_DEALT: 0.50,
	DAMAGE_RECEIVED: 0.50,
}

var _entries: Dictionary[StringName, Dictionary] = {}

func apply(attribute: StringName, source: StringName, fraction: float, duration: float) -> bool:
	if not LIMITS.has(attribute) or source.is_empty() or not is_finite(fraction) or not is_finite(duration) or fraction <= 0.0 or duration <= 0.0:
		return false
	var entries: Dictionary = _entries.get(attribute, {})
	entries[source] = {"fraction": minf(fraction, float(LIMITS[attribute])), "remaining": duration}
	_entries[attribute] = entries
	return true

func fraction(attribute: StringName) -> float:
	var strongest := 0.0
	for entry: Dictionary in _entries.get(attribute, {}).values():
		if float(entry["remaining"]) > 0.0:
			strongest = maxf(strongest, float(entry["fraction"]))
	return strongest

func remaining(attribute: StringName, source: StringName = &"") -> float:
	var entries: Dictionary = _entries.get(attribute, {})
	if not source.is_empty():
		return float(entries.get(source, {}).get("remaining", 0.0))
	var longest := 0.0
	for entry: Dictionary in entries.values():
		longest = maxf(longest, float(entry["remaining"]))
	return longest

func remove(attribute: StringName, source: StringName) -> bool:
	var entries: Dictionary = _entries.get(attribute, {})
	if not entries.has(source):
		return false
	entries.erase(source)
	if entries.is_empty():
		_entries.erase(attribute)
	else:
		_entries[attribute] = entries
	return true

func advance(delta: float) -> bool:
	if not is_finite(delta) or delta <= 0.0:
		return false
	var changed := false
	for attribute: StringName in _entries.keys():
		var entries: Dictionary = _entries[attribute]
		for source: StringName in entries.keys():
			var entry: Dictionary = entries[source]
			entry["remaining"] = maxf(0.0, float(entry["remaining"]) - delta)
			if float(entry["remaining"]) <= 0.0:
				entries.erase(source)
				changed = true
			else:
				entries[source] = entry
		if entries.is_empty():
			_entries.erase(attribute)
		else:
			_entries[attribute] = entries
	return changed

func clear() -> void:
	_entries.clear()
