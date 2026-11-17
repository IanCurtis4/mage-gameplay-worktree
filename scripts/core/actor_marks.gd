class_name ActorMarks
extends RefCounted
## E09 C1.5: generic marks on one combat actor, by key, with owner, value and an
## expiry on the gameplay clock (advanced by CombatActor.advance_statuses, so the
## pause freezes it). Cleared with the actor's statuses (death, death recovery).
## Values are plain data; an entity reference belongs in `owner_id` only.

const NO_EXPIRY := -1.0
const MAX_MARKS := 32

## key -> {"owner_id": int, "value": Variant, "remaining": float (NO_EXPIRY = until removed)}
var _entries: Dictionary = {}
var revision := 0

## Sets or replaces a mark. duration <= 0 means NO_EXPIRY. Returns false when the
## key/duration is invalid or the actor already carries MAX_MARKS other keys.
func set_mark(key: StringName, owner_id: int, value: Variant, duration: float = NO_EXPIRY) -> bool:
	if key.is_empty() or not is_finite(duration) or (not _entries.has(key) and _entries.size() >= MAX_MARKS): return false
	if typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]: return false
	_entries[key] = {"owner_id": owner_id, "value": value, "remaining": duration if duration > 0.0 else NO_EXPIRY}
	revision += 1
	return true

func has_mark(key: StringName) -> bool:
	return _entries.has(key)

## Detached copy of one mark, or {} when absent.
func get_mark(key: StringName) -> Dictionary:
	return _entries.get(key, {}).duplicate(true)

func value(key: StringName, default: Variant = null) -> Variant:
	return _entries[key]["value"] if _entries.has(key) else default

func owner_of(key: StringName) -> int:
	return int(_entries[key]["owner_id"]) if _entries.has(key) else 0

func remaining(key: StringName) -> float:
	return float(_entries[key]["remaining"]) if _entries.has(key) else 0.0

## Updates only the value; keeps owner and expiry. False when absent.
func update_value(key: StringName, new_value: Variant) -> bool:
	if not _entries.has(key) or typeof(new_value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]: return false
	_entries[key]["value"] = new_value
	revision += 1
	return true

func remove(key: StringName) -> bool:
	if not _entries.erase(key): return false
	revision += 1
	return true

## Removes every mark of an owner (for example when the owner marks another victim).
func remove_owner(owner_id: int) -> int:
	var removed := 0
	for key: StringName in _entries.keys():
		if int(_entries[key]["owner_id"]) == owner_id:
			_entries.erase(key)
			removed += 1
	if removed > 0: revision += 1
	return removed

func keys() -> Array[StringName]:
	var result: Array[StringName] = []
	for key: StringName in _entries: result.append(key)
	result.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return result

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0: return
	var expired := false
	for key: StringName in _entries.keys():
		var entry: Dictionary = _entries[key]
		if float(entry["remaining"]) == NO_EXPIRY: continue
		entry["remaining"] = maxf(0.0, float(entry["remaining"]) - delta)
		if float(entry["remaining"]) <= 0.0:
			_entries.erase(key)
			expired = true
	if expired: revision += 1

func clear() -> void:
	if _entries.is_empty(): return
	_entries.clear()
	revision += 1

func is_empty() -> bool:
	return _entries.is_empty()

func valid() -> bool:
	if _entries.size() > MAX_MARKS or revision < 0: return false
	for key: Variant in _entries:
		if not key is StringName or String(key).is_empty() or not _entries[key] is Dictionary: return false
		var entry: Dictionary = _entries[key]
		if entry.size() != 3 or typeof(entry.get("owner_id")) != TYPE_INT or typeof(entry.get("remaining")) not in [TYPE_FLOAT, TYPE_INT]: return false
		var left := float(entry["remaining"])
		if not is_finite(left) or (left != NO_EXPIRY and left <= 0.0): return false
	return true
