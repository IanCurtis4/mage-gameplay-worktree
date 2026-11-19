class_name KitHudState
extends RefCounted
## E12 C1 — validator of the kit HUD format `ragrpg_kit_hud_v1` (ClassKit.hud_state).
## Static only: never instantiated, never in a snapshot. API and rules:
## docs/epics/e12/h1_hud_seam_api.md; contract: docs/epics/e12_contract.md §2.
##
## validate() is pure and cheap (no tree walk); it checks shape, types and ranges only.
## Whether a `target_id` is still alive is the consumer's lookup (the overlay skips IDs
## it does not know), so a victim dying this frame never blanks the whole HUD.

const SCHEMA := "ragrpg_kit_hud_v1"

const INVALID_SCHEMA := &"kit_hud_invalid_schema"
const KIT_MISMATCH := &"kit_hud_kit_mismatch"
const UNKNOWN_KEY := &"kit_hud_unknown_key"
const INVALID_RESOURCE := &"kit_hud_invalid_resource"
const DUPLICATE_RESOURCE := &"kit_hud_duplicate_resource"
const UNKNOWN_SKILL := &"kit_hud_unknown_skill"
const INVALID_SKILL := &"kit_hud_invalid_skill"
const INVALID_ZONE := &"kit_hud_invalid_zone"
const INVALID_MARK := &"kit_hud_invalid_mark"
const NON_FINITE := &"kit_hud_non_finite"
## Every error code, in the order of the contract table (§2.3).
const ERROR_CODES: Array[StringName] = [INVALID_SCHEMA, KIT_MISMATCH, UNKNOWN_KEY, INVALID_RESOURCE, DUPLICATE_RESOURCE, UNKNOWN_SKILL, INVALID_SKILL, INVALID_ZONE, INVALID_MARK, NON_FINITE]

const TOP_KEYS: Array[String] = ["schema", "kit_id", "resources", "skills", "zones", "target_marks"]
const RESOURCE_KEYS: Array[String] = ["id", "label", "kind", "value", "max", "unlimited", "remaining", "total", "element"]
const SKILL_KEYS: Array[String] = ["ready", "reason", "charges", "max_charges", "recharge_remaining", "recharge_total"]
const ZONE_KEYS: Array[String] = ["role", "space", "center", "shape", "radius", "half_angle", "facing", "element", "remaining", "total"]
const MARK_KEYS: Array[String] = ["target_id", "key", "kind", "value", "max", "element"]

const KIND_PIPS := &"pips"
const KIND_CHARGES := &"charges"
const KIND_TIMER := &"timer"
const KIND_BADGE := &"badge"
const RESOURCE_KINDS: Array[StringName] = [KIND_PIPS, KIND_CHARGES, KIND_TIMER]
const MARK_KINDS: Array[StringName] = [KIND_PIPS, KIND_BADGE]
const SPACE_WORLD := &"world"
const SPACE_FLAT := &"flat"
const SPACES: Array[StringName] = [SPACE_WORLD, SPACE_FLAT]
## Presentation elements; empty means "no element colour".
const ELEMENTS: Array[StringName] = [&"", &"none", &"fire", &"ice", &"lightning", &"tricolor", &"light", &"shadow", &"arcane"]
## Resource IDs carry the kit prefix (ClassKitRegistry.IDENTITIES) or a system prefix.
const SYSTEM_PREFIXES: Array[String] = ["sanctuary_", "flank_", "madness_"]

## Skill IDs of each kit script, cached: catalog data is immutable (AGENTS), and building
## the SkillDefinitions every HUD frame would be wasted work.
static var _skill_cache: Dictionary = {}
## Warning keys already reported (PlayerActor.kit_hud_state): one per kit and error code.
static var _warned: Dictionary = {}

## {"ok": bool, "error_code": StringName, "detail": String}. {} is valid (kit without HUD).
static func validate(state: Dictionary, kit: ClassKit) -> Dictionary:
	if state.is_empty(): return _ok()
	if typeof(state.get("schema")) != TYPE_STRING or String(state["schema"]) != SCHEMA:
		return _fail(INVALID_SCHEMA, "schema")
	if kit == null or typeof(state.get("kit_id")) != TYPE_STRING_NAME or StringName(state["kit_id"]) != kit.kit_id():
		return _fail(KIT_MISMATCH, "kit_id")
	for key: Variant in state:
		if typeof(key) != TYPE_STRING or String(key) not in TOP_KEYS:
			return _fail(UNKNOWN_KEY, str(key))
	var non_finite := _non_finite_path(state, "")
	if not non_finite.is_empty(): return _fail(NON_FINITE, non_finite)
	if state.has("resources"):
		var result := _validate_resources(state["resources"], kit)
		if not result["ok"]: return result
	if state.has("skills"):
		var result := _validate_skills(state["skills"], kit)
		if not result["ok"]: return result
	if state.has("zones"):
		var result := _validate_zones(state["zones"])
		if not result["ok"]: return result
	if state.has("target_marks"):
		var result := _validate_marks(state["target_marks"])
		if not result["ok"]: return result
	return _ok()

## Validates and, when invalid, reports one warning per kit and error code. Returns the
## state itself when valid, {} otherwise. Used by PlayerActor.kit_hud_state.
static func checked(state: Dictionary, kit: ClassKit) -> Dictionary:
	var result := validate(state, kit)
	if result["ok"]: return state
	var key := "%s:%s" % [String(kit.kit_id()) if kit != null else "", String(result["error_code"])]
	if not _warned.has(key):
		_warned[key] = true
		push_warning("KitHudState: invalid HUD state from kit '%s' (%s at %s); the HUD shows nothing for it." % [key.get_slice(":", 0), result["error_code"], result["detail"]])
	return {}

## Warning keys already reported ("<kit_id>:<error_code>"), for tests and diagnostics.
static func reported_warnings() -> Array[String]:
	var keys: Array[String] = []
	for key: String in _warned: keys.append(key)
	keys.sort()
	return keys

## Test helper: forgets the reported warnings and the skill cache.
static func reset_reports() -> void:
	_warned.clear()
	_skill_cache.clear()

# --- Sections ---------------------------------------------------------------------------

static func _validate_resources(value: Variant, kit: ClassKit) -> Dictionary:
	if not value is Array: return _fail(INVALID_RESOURCE, "resources")
	var seen := {}
	var prefixes := _resource_prefixes(kit)
	var index := -1
	for entry: Variant in value:
		index += 1
		var path := "resources[%d]" % index
		if not entry is Dictionary: return _fail(INVALID_RESOURCE, path)
		var resource: Dictionary = entry
		var unknown := _unknown_key(resource, RESOURCE_KEYS)
		if not unknown.is_empty(): return _fail(INVALID_RESOURCE, path + "." + unknown)
		if not _is_name(resource.get("id")) or not _has_prefix(String(resource["id"]), prefixes):
			return _fail(INVALID_RESOURCE, path + ".id")
		if typeof(resource.get("label")) != TYPE_STRING or String(resource["label"]).strip_edges().is_empty():
			return _fail(INVALID_RESOURCE, path + ".label")
		if typeof(resource.get("kind")) != TYPE_STRING_NAME or StringName(resource["kind"]) not in RESOURCE_KINDS:
			return _fail(INVALID_RESOURCE, path + ".kind")
		if not _element_ok(resource): return _fail(INVALID_RESOURCE, path + ".element")
		var kind := StringName(resource["kind"])
		var unlimited := false
		if resource.has("unlimited"):
			if kind != KIND_PIPS or typeof(resource["unlimited"]) != TYPE_BOOL: return _fail(INVALID_RESOURCE, path + ".unlimited")
			unlimited = bool(resource["unlimited"])
		if kind == KIND_TIMER:
			if resource.has("value") or resource.has("max"): return _fail(INVALID_RESOURCE, path + ".value")
			if not resource.has("remaining"): return _fail(INVALID_RESOURCE, path + ".remaining")
		else:
			if not _is_int(resource.get("value")) or int(resource["value"]) < 0: return _fail(INVALID_RESOURCE, path + ".value")
			if not _is_int(resource.get("max")) or int(resource["max"]) < 1: return _fail(INVALID_RESOURCE, path + ".max")
			if not unlimited and int(resource["value"]) > int(resource["max"]): return _fail(INVALID_RESOURCE, path + ".value")
			if kind == KIND_PIPS and (resource.has("remaining") != unlimited or resource.has("total") != unlimited):
				return _fail(INVALID_RESOURCE, path + ".remaining")
		if not _clock_ok(resource, "remaining", "total"): return _fail(INVALID_RESOURCE, path + ".remaining")
		var id := StringName(resource["id"])
		if seen.has(id): return _fail(DUPLICATE_RESOURCE, path + ".id")
		seen[id] = true
	return _ok()

static func _validate_skills(value: Variant, kit: ClassKit) -> Dictionary:
	if not value is Dictionary: return _fail(INVALID_SKILL, "skills")
	var known := _kit_skill_ids(kit)
	for skill: Variant in value:
		if typeof(skill) != TYPE_STRING_NAME or StringName(skill) not in known:
			return _fail(UNKNOWN_SKILL, "skills." + str(skill))
	for skill: Variant in value:
		var path := "skills." + String(skill)
		if not value[skill] is Dictionary: return _fail(INVALID_SKILL, path)
		var entry: Dictionary = value[skill]
		var unknown := _unknown_key(entry, SKILL_KEYS)
		if not unknown.is_empty(): return _fail(INVALID_SKILL, path + "." + unknown)
		if typeof(entry.get("ready")) != TYPE_BOOL: return _fail(INVALID_SKILL, path + ".ready")
		var reason: Variant = entry.get("reason", &"")
		if typeof(reason) != TYPE_STRING_NAME or bool(entry["ready"]) != StringName(reason).is_empty():
			return _fail(INVALID_SKILL, path + ".reason")
		if entry.has("charges") != entry.has("max_charges"): return _fail(INVALID_SKILL, path + ".charges")
		if entry.has("charges"):
			if not _is_int(entry["charges"]) or not _is_int(entry["max_charges"]) or int(entry["max_charges"]) < 1 or int(entry["charges"]) < 0 or int(entry["charges"]) > int(entry["max_charges"]):
				return _fail(INVALID_SKILL, path + ".charges")
		if not _clock_ok(entry, "recharge_remaining", "recharge_total"): return _fail(INVALID_SKILL, path + ".recharge_remaining")
	return _ok()

static func _validate_zones(value: Variant) -> Dictionary:
	if not value is Array: return _fail(INVALID_ZONE, "zones")
	var index := -1
	for entry: Variant in value:
		index += 1
		var path := "zones[%d]" % index
		if not entry is Dictionary: return _fail(INVALID_ZONE, path)
		var zone: Dictionary = entry
		var unknown := _unknown_key(zone, ZONE_KEYS)
		if not unknown.is_empty(): return _fail(INVALID_ZONE, path + "." + unknown)
		if not _is_name(zone.get("role")): return _fail(INVALID_ZONE, path + ".role")
		if typeof(zone.get("space")) != TYPE_STRING_NAME or StringName(zone["space"]) not in SPACES: return _fail(INVALID_ZONE, path + ".space")
		var flat := StringName(zone["space"]) == SPACE_FLAT
		if typeof(zone.get("center")) != TYPE_VECTOR3 or (flat and not is_zero_approx((zone["center"] as Vector3).z)):
			return _fail(INVALID_ZONE, path + ".center")
		if typeof(zone.get("shape")) != TYPE_STRING_NAME or StringName(zone["shape"]) not in SanctuaryRules.SHAPES:
			return _fail(INVALID_ZONE, path + ".shape")
		if not _is_number(zone.get("radius")) or float(zone["radius"]) <= 0.0: return _fail(INVALID_ZONE, path + ".radius")
		var cone := StringName(zone["shape"]) == SanctuaryRules.SHAPE_CONE
		if zone.has("half_angle") != cone: return _fail(INVALID_ZONE, path + ".half_angle")
		if cone and (not _is_number(zone["half_angle"]) or float(zone["half_angle"]) <= 0.0 or float(zone["half_angle"]) > PI):
			return _fail(INVALID_ZONE, path + ".half_angle")
		if cone and not zone.has("facing"): return _fail(INVALID_ZONE, path + ".facing")
		if zone.has("facing"):
			if typeof(zone["facing"]) != TYPE_VECTOR3 or (zone["facing"] as Vector3).is_zero_approx() or (flat and not is_zero_approx((zone["facing"] as Vector3).z)):
				return _fail(INVALID_ZONE, path + ".facing")
		if not _element_ok(zone): return _fail(INVALID_ZONE, path + ".element")
		if not _clock_ok(zone, "remaining", "total"): return _fail(INVALID_ZONE, path + ".remaining")
	return _ok()

static func _validate_marks(value: Variant) -> Dictionary:
	if not value is Array: return _fail(INVALID_MARK, "target_marks")
	var seen := {}
	var index := -1
	for entry: Variant in value:
		index += 1
		var path := "target_marks[%d]" % index
		if not entry is Dictionary: return _fail(INVALID_MARK, path)
		var mark: Dictionary = entry
		var unknown := _unknown_key(mark, MARK_KEYS)
		if not unknown.is_empty(): return _fail(INVALID_MARK, path + "." + unknown)
		if not _is_int(mark.get("target_id")) or int(mark["target_id"]) <= 0: return _fail(INVALID_MARK, path + ".target_id")
		if not _is_name(mark.get("key")): return _fail(INVALID_MARK, path + ".key")
		if typeof(mark.get("kind")) != TYPE_STRING_NAME or StringName(mark["kind"]) not in MARK_KINDS: return _fail(INVALID_MARK, path + ".kind")
		if StringName(mark["kind"]) == KIND_PIPS:
			if not _is_int(mark.get("max")) or int(mark["max"]) < 1: return _fail(INVALID_MARK, path + ".max")
			if not _is_int(mark.get("value")) or int(mark["value"]) < 0 or int(mark["value"]) > int(mark["max"]): return _fail(INVALID_MARK, path + ".value")
		elif mark.has("value") or mark.has("max"):
			return _fail(INVALID_MARK, path + ".value")
		if not _element_ok(mark): return _fail(INVALID_MARK, path + ".element")
		var pair := "%d:%s" % [int(mark["target_id"]), String(mark["key"])]
		if seen.has(pair): return _fail(INVALID_MARK, path + ".key")
		seen[pair] = true
	return _ok()

# --- Helpers ----------------------------------------------------------------------------

static func _ok() -> Dictionary:
	return {"ok": true, "error_code": &"", "detail": ""}

static func _fail(code: StringName, detail: String) -> Dictionary:
	return {"ok": false, "error_code": code, "detail": detail}

static func _is_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT

static func _is_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT]

static func _is_name(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING_NAME and not StringName(value).is_empty()

static func _element_ok(entry: Dictionary) -> bool:
	return not entry.has("element") or (typeof(entry["element"]) == TYPE_STRING_NAME and StringName(entry["element"]) in ELEMENTS)

## Both keys or neither; numbers with 0 <= remaining <= total and total > 0.
static func _clock_ok(entry: Dictionary, remaining_key: String, total_key: String) -> bool:
	if entry.has(remaining_key) != entry.has(total_key): return false
	if not entry.has(remaining_key): return true
	if not _is_number(entry[remaining_key]) or not _is_number(entry[total_key]): return false
	var remaining := float(entry[remaining_key])
	var total := float(entry[total_key])
	return total > 0.0 and remaining >= 0.0 and remaining <= total

static func _unknown_key(entry: Dictionary, allowed: Array[String]) -> String:
	for key: Variant in entry:
		if typeof(key) != TYPE_STRING or String(key) not in allowed: return str(key)
	return ""

static func _resource_prefixes(kit: ClassKit) -> Array[String]:
	var prefixes: Array[String] = SYSTEM_PREFIXES.duplicate()
	var identity: Variant = ClassKitRegistry.IDENTITIES.get(kit.kit_id())
	if identity is Dictionary and not String(identity.get("prefix", "")).is_empty(): prefixes.append(String(identity["prefix"]))
	return prefixes

static func _has_prefix(id: String, prefixes: Array[String]) -> bool:
	for prefix: String in prefixes:
		if id.begins_with(prefix) and id.length() > prefix.length(): return true
	return false

static func _kit_skill_ids(kit: ClassKit) -> Array[StringName]:
	var script: Script = kit.get_script()
	var key := "%d:%s" % [script.get_instance_id() if script != null else 0, String(kit.kit_id())]
	if _skill_cache.has(key): return _skill_cache[key]
	var ids: Array[StringName] = []
	for definition: SkillDefinition in kit.skill_definitions():
		if definition != null: ids.append(definition.id)
	_skill_cache[key] = ids
	return ids

## Path of the first non-finite number (float, vector component) or "" when all finite.
static func _non_finite_path(value: Variant, path: String) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return "" if is_finite(float(value)) else path
		TYPE_VECTOR2:
			return "" if (value as Vector2).is_finite() else path
		TYPE_VECTOR3:
			return "" if (value as Vector3).is_finite() else path
		TYPE_DICTIONARY:
			for key: Variant in value:
				var found := _non_finite_path(value[key], (path + "." if not path.is_empty() else "") + str(key))
				if not found.is_empty(): return found
		TYPE_ARRAY:
			var index := 0
			for item: Variant in value:
				var found := _non_finite_path(item, "%s[%d]" % [path, index])
				if not found.is_empty(): return found
				index += 1
	return ""
