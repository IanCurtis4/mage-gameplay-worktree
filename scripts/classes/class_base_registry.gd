class_name ClassBaseRegistry
extends RefCounted
## E10a C1.1 — closed registry of the base (origin) modules. Only T1 edits this file;
## each base task edits its own folder `scripts/classes/bases/<id>/`. The three E00
## bases (swordsman, mage, archer) are not registered and keep their fixed code.
## API and error codes: docs/epics/e10a/t1_base_seam_api.md.
## Script cycles: this registry never names ClassKitRegistry nor IdentityIds (they read it);
## a cycle among these static-state scripts is not released at exit by Godot 4.7.2.

const MODULES := {
	&"acolyte": "res://scripts/classes/bases/acolyte/acolyte_base.gd",
}

## Section 1 of the E10a contract (A5): name, body folder, fallback body (used while
## the folder has no art) and skill prefix.
const IDENTITIES := {
	&"acolyte": {"name": "Acólito", "body": &"acolyte", "fallback_body": &"mage", "prefix": "acolyte_"},
}

## Stable library skill IDs per base (section 1 of the E10a contract).
const SKILL_IDS := {
	&"acolyte": [&"acolyte_punishing_light", &"acolyte_prayer", &"acolyte_votive_shield", &"acolyte_shadow_seal", &"acolyte_disturbing_whisper", &"acolyte_eldritch_vision", &"acolyte_devotion", &"acolyte_protective_faith"],
}
## Categories of each library skill (section 1): six actives and two passives.
const SKILL_CATEGORIES := {
	&"acolyte": [&"active", &"active", &"active", &"active", &"active", &"active", &"passive", &"passive"],
}
## Basic-attack types of the module data and the PlayerActor delivery they select.
const DELIVERIES := {&"magic": &"mage", &"precision": &"precision", &"direct": &"direct"}
## Accepted SkillDefinition.element values of base skills (C1.8: shadow joins light).
const BASE_ELEMENTS: Array[StringName] = [&"", &"physical", &"fire", &"ice", &"lightning", &"light", &"shadow", &"arcane", &"spirit"]
const ATTRIBUTE_TOTAL := 30
## Same six IDs as IdentityIds.attribute_ids() (kept here to avoid a script cycle).
const ATTRIBUTE_IDS: Array[StringName] = [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]
const MAX_BASE_JOB_LEVEL := 19

static var _modules: Dictionary = {}
static var _fixtures: Dictionary = {}
## Test-only forced availability per base (force_ready_fixture); empty in production.
static var _forced_ready: Dictionary = {}
## Bumped whenever the effective module set changes (fixtures); ClassKitRegistry.seam_revision()
## adds it to its own, so every catalog rebuilds on change.
static var revision := 0
static var _cache_revision := -1
static var _validation: Dictionary = {}

static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in MODULES: result.append(id)
	return result

static func is_base(base_id: StringName) -> bool:
	return MODULES.has(base_id)

static func identity(base_id: StringName) -> Dictionary:
	return IDENTITIES.get(base_id, {}).duplicate(true)

static func skill_ids(base_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(SKILL_IDS.get(base_id, []))
	return result

static func body_folder(base_id: StringName) -> StringName:
	return StringName(IDENTITIES.get(base_id, {}).get("body", &""))

static func fallback_body(base_id: StringName) -> StringName:
	return StringName(IDENTITIES.get(base_id, {}).get("fallback_body", &""))

## PlayerActor delivery of a module basic-attack type; empty when unknown.
static func delivery_of(kind: StringName) -> StringName:
	return StringName(DELIVERIES.get(kind, &""))

## Catalog module instance (fixture first). Null when missing, and in editor tooling.
static func module(base_id: StringName) -> ClassBase:
	if _fixtures.has(base_id): return _fixtures[base_id]
	if not MODULES.has(base_id) or Engine.is_editor_hint(): return null
	if not _modules.has(base_id):
		var path: String = MODULES[base_id]
		var script := load(path) as Script if ResourceLoader.exists(path) else null
		var instance: Variant = script.new() if script != null else null
		_modules[base_id] = instance if instance is ClassBase else null
	return _modules[base_id]

## Module declared ready (or forced by a fixture) and valid (C1.3).
static func ready_for_play(base_id: StringName) -> bool:
	var base := module(base_id)
	return base != null and (base.ready_for_play() or _forced_ready.has(base_id)) and validate(base_id)["ok"]

static func display_name(base_id: StringName) -> String:
	var base := module(base_id)
	var name := base.display_name() if base != null else ""
	return name if not name.is_empty() else String(IDENTITIES.get(base_id, {}).get("name", base_id))

static func initial_attributes(base_id: StringName) -> Dictionary[StringName, int]:
	var base := module(base_id)
	if base == null or not validate(base_id)["ok"]: return {}
	return base.initial_attributes().duplicate()

static func learning_entries(base_id: StringName) -> Array[Dictionary]:
	var base := module(base_id)
	return base.learning_entries() if base != null else []

## Basic-attack data with defaults: {"delivery" (PlayerActor delivery), "range", "power"}.
static func basic_attack(base_id: StringName) -> Dictionary:
	var base := module(base_id)
	var data: Dictionary = base.basic_attack() if base != null else {}
	var delivery := delivery_of(StringName(data.get("delivery", &"direct")))
	return {"delivery": delivery if not delivery.is_empty() else &"direct", "range": float(data.get("range", 50.0)), "power": float(data.get("power", 1.0))}

## {"ok", "error_code", "detail"}; codes listed in the API document.
static func validate(base_id: StringName) -> Dictionary:
	_ensure_cache()
	if not MODULES.has(base_id): return _failure(&"base_unknown_identity", String(base_id))
	return _validation.get(base_id, _failure(&"base_module_missing", String(base_id))).duplicate(true)

# --- Fixtures (tests only) ---------------------------------------------------------

## Replaces a production module by a fixture module until clear_fixtures(). The
## fixture must extend ClassBase and answer the same base_id().
static func install_fixture(base_id: StringName, base: ClassBase) -> bool:
	if not MODULES.has(base_id) or base == null or base.base_id() != base_id: return false
	_fixtures[base_id] = base
	revision += 1
	return true

## Forces ready_for_play for a valid module (e.g. a production skeleton) until
## clear_fixtures(), so profiles of fixture tests may create the base.
static func force_ready_fixture(base_id: StringName) -> bool:
	if not MODULES.has(base_id): return false
	_forced_ready[base_id] = true
	revision += 1
	return true

static func clear_fixtures() -> void:
	if _fixtures.is_empty() and _forced_ready.is_empty(): return
	_fixtures.clear()
	_forced_ready.clear()
	revision += 1

# --- Internals ------------------------------------------------------------------

static func _ensure_cache() -> void:
	if _cache_revision == revision: return
	_cache_revision = revision
	_validation = {}
	for id: StringName in MODULES:
		var base := module(id)
		_validation[id] = _validate_module(id, base) if base != null else _failure(&"base_module_missing", String(MODULES[id]))

static func _validate_module(id: StringName, base: ClassBase) -> Dictionary:
	if base.base_id() != id or base.kit_id() != id: return _failure(&"base_identity_mismatch", String(base.base_id()))
	var allowed: Array = SKILL_IDS[id]
	var categories: Array = SKILL_CATEGORIES[id]
	var seen: Dictionary = {}
	for definition: SkillDefinition in base.skill_definitions():
		if definition == null or definition.id not in allowed: return _failure(&"base_skill_outside_identity", String(definition.id) if definition != null else "null")
		if seen.has(definition.id): return _failure(&"base_skill_duplicate", String(definition.id))
		if definition.handler_id != SkillDefinition.Handler.KIT or not definition.is_rank_catalog_valid(): return _failure(&"base_skill_invalid", String(definition.id))
		if definition.element not in BASE_ELEMENTS or not EffectTags.valid(definition.tags): return _failure(&"base_skill_invalid", String(definition.id) + ":element_or_tags")
		var expected := SkillDefinition.Category.ACTIVE if categories[allowed.find(definition.id)] == &"active" else SkillDefinition.Category.PASSIVE
		if definition.category != expected: return _failure(&"base_skill_invalid", String(definition.id) + ":category")
		seen[definition.id] = true
	var learned: Dictionary = {}
	for entry: Dictionary in base.learning_entries():
		var skill := StringName(entry.get("skill_id", &""))
		if not seen.has(skill) or learned.has(skill): return _failure(&"base_learning_invalid", String(skill))
		var category := StringName(entry.get("category", &""))
		var cap := SkillDefinition.MAX_ACTIVE_RANK if category == &"active" else SkillDefinition.MAX_PASSIVE_RANK
		var job := int(entry.get("job_level", 1))
		if category != categories[allowed.find(skill)] or int(entry.get("free_rank", 0)) != 0 or int(entry.get("max_purchased_rank", -1)) != cap or job < 1 or job > MAX_BASE_JOB_LEVEL: return _failure(&"base_learning_invalid", String(skill))
		var prerequisites: Variant = entry.get("prerequisites", {})
		if not prerequisites is Dictionary: return _failure(&"base_learning_invalid", String(skill) + ":prerequisites")
		for raw: Variant in prerequisites:
			if StringName(raw) not in allowed or StringName(raw) == skill or not prerequisites[raw] is int or int(prerequisites[raw]) < 1: return _failure(&"base_learning_invalid", String(skill) + ":prerequisites")
		learned[skill] = true
	if learned.size() != seen.size(): return _failure(&"base_learning_invalid", "skills_without_learning")
	for skill: StringName in base.starting_skill_ids():
		if not learned.has(skill): return _failure(&"base_starting_invalid", String(skill))
	if not base.starting_passive_id().is_empty() and (not learned.has(base.starting_passive_id()) or categories[allowed.find(base.starting_passive_id())] != &"passive"): return _failure(&"base_starting_invalid", String(base.starting_passive_id()))
	var attributes := base.initial_attributes()
	if not attributes.is_empty():
		var total := 0
		for attribute: StringName in ATTRIBUTE_IDS:
			if not attributes.has(attribute) or not attributes[attribute] is int or int(attributes[attribute]) < 1: return _failure(&"base_attributes_invalid", String(attribute))
			total += int(attributes[attribute])
		if attributes.size() != ATTRIBUTE_IDS.size() or total != ATTRIBUTE_TOTAL: return _failure(&"base_attributes_invalid", "total_%d" % total)
	var attack := base.basic_attack()
	if not attack.is_empty():
		if delivery_of(StringName(attack.get("delivery", &""))).is_empty(): return _failure(&"base_attack_invalid", "delivery")
		for key: String in ["range", "power"]:
			if not attack.has(key) or not (attack[key] is float or attack[key] is int) or not is_finite(float(attack[key])) or float(attack[key]) <= 0.0: return _failure(&"base_attack_invalid", key)
	for skill: StringName in base.feedback_recipes():
		var row: Variant = base.feedback_recipes()[skill]
		if not seen.has(skill) or not row is Array or row.size() != 4 or row[0] not in FeedbackRecipeCatalog.FAMILIES or row[1] not in FeedbackRecipeCatalog.ELEMENTS or not StringName(row[2]).is_empty(): return _failure(&"base_recipe_invalid", String(skill))
	var prefix: String = IDENTITIES[id]["prefix"]
	for family: StringName in base.causal_families():
		if not String(family).begins_with(prefix): return _failure(&"base_family_invalid", String(family))
	for effect_id: StringName in base.vfx_effects():
		var spec: Variant = base.vfx_effects()[effect_id]
		if not String(effect_id).begins_with(prefix) or not spec is Dictionary or not seen.has(StringName(spec.get("skill_id", &""))) or not spec.get("kinds") is Array or spec["kinds"].is_empty(): return _failure(&"base_vfx_invalid", String(effect_id))
	for skill: StringName in base.skill_texts():
		if not seen.has(skill) or not base.skill_texts()[skill] is Dictionary: return _failure(&"base_text_invalid", String(skill))
	if base.ready_for_play():
		if seen.size() != allowed.size(): return _failure(&"base_incomplete", "skills")
		if attributes.is_empty() or attack.is_empty() or base.starting_skill_ids().is_empty(): return _failure(&"base_incomplete", "identity_data")
		for skill: StringName in allowed:
			if String(base.skill_texts().get(skill, {}).get("effect", "")).is_empty(): return _failure(&"base_incomplete", String(skill) + ":text")
			if not base.feedback_recipes().has(skill): return _failure(&"base_incomplete", String(skill) + ":recipe")
	return {"ok": true, "error_code": &"", "detail": ""}

static func _failure(code: StringName, detail: String = "") -> Dictionary:
	return {"ok": false, "error_code": code, "detail": detail}
