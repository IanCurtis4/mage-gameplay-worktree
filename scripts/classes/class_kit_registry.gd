class_name ClassKitRegistry
extends RefCounted
## E09 C1.1 — closed registry of the class kits. Only T1 edits this file; each kit
## task edits its own folder. Aggregates module data for ClassCatalog,
## ProfileCatalog, BuildEffectCatalog, FeedbackRecipeCatalog and SkillCopy.
## E10a C1: also lists the pure kits of registered bases (origin and branch by data)
## and aggregates the base modules of ClassBaseRegistry through the same accessors
## (skill owner, definitions, passives, recipes, texts, effects, families, bodies).
## APIs: docs/epics/e09/t1_kit_seam_api.md and docs/epics/e10a/t1_base_seam_api.md.

const MODULES := {
	&"sp_ac": "res://scripts/classes/sp_ac/sp_ac_kit.gd",
	&"mg_ac": "res://scripts/classes/mg_ac/mg_ac_kit.gd",
	&"sp_la": "res://scripts/classes/sp_la/sp_la_kit.gd",
	&"mg_la": "res://scripts/classes/mg_la/mg_la_kit.gd",
	&"priest": "res://scripts/classes/priest/priest_kit.gd",
	&"cultist": "res://scripts/classes/cultist/cultist_kit.gd",
}

## Section 1 of the E09 contract: identity, origin, affinity label, body folder and skill
## prefix; E10a C1.5 adds the branch (2-1, 2-2 pure; 2-3 hybrid) and the pure kits.
const IDENTITIES := {
	&"sp_ac": {"name": "Paladino", "origin": &"swordsman", "affinity": &"acolyte", "branch": &"2-3", "body": &"paladin", "prefix": "paladin_"},
	&"mg_ac": {"name": "Taumaturgo", "origin": &"mage", "affinity": &"acolyte", "branch": &"2-3", "body": &"thaumaturge", "prefix": "thaumaturge_"},
	&"sp_la": {"name": "Duelista", "origin": &"swordsman", "affinity": &"rogue", "branch": &"2-3", "body": &"duelist", "prefix": "duelist_"},
	&"mg_la": {"name": "Lâmina Arcana", "origin": &"mage", "affinity": &"rogue", "branch": &"2-3", "body": &"arcane_blade", "prefix": "arcane_blade_"},
	&"priest": {"name": "Sacerdote", "origin": &"acolyte", "affinity": &"", "branch": &"2-1", "body": &"priest", "prefix": "priest_"},
	&"cultist": {"name": "Cultista", "origin": &"acolyte", "affinity": &"", "branch": &"2-2", "body": &"cultist", "prefix": "cultist_"},
}
## E10a C1.8: kits whose arcane presentation rows are shown as light (the Acólito affinity
## of the E09 hybrids). Presentation only; the gameplay element stays SkillDefinition.element.
const LIGHT_PRESENTATION_KITS: Array[StringName] = [&"sp_ac", &"mg_ac"]

## Stable skill IDs per kit, in job order (20 entry, 23, 25, 28, 31, 34, 37).
const SKILL_IDS := {
	&"sp_ac": [&"paladin_oath", &"paladin_guard_grace", &"paladin_consecrated_impact", &"paladin_oath_aegis", &"paladin_unshaken_faith", &"paladin_condemned_seal", &"paladin_oath_hour"],
	&"mg_ac": [&"thaumaturge_votive_circle", &"thaumaturge_votive_prism", &"thaumaturge_healing_refraction", &"thaumaturge_altar_shift", &"thaumaturge_elemental_choir", &"thaumaturge_prismatic_judgment", &"thaumaturge_convergent_dawn"],
	&"sp_la": [&"duelist_parry", &"duelist_read_opponent", &"duelist_fatal_riposte", &"duelist_feint", &"duelist_patient_guard", &"duelist_guarded_retreat", &"duelist_duel"],
	&"mg_la": [&"arcane_blade_refracted_mark", &"arcane_blade_enchanted_edge", &"arcane_blade_refraction", &"arcane_blade_prismatic_leap", &"arcane_blade_light_fracture", &"arcane_blade_prismatic_sentence", &"arcane_blade_prism_specter"],
	&"priest": [&"priest_sanctuary", &"priest_grace", &"priest_aegis", &"priest_judgment", &"priest_exorcist", &"priest_light_seal", &"priest_holy_hour"],
	&"cultist": [&"cultist_abyss_gaze", &"cultist_ecstasy", &"cultist_impossible_idol", &"cultist_shared_delirium", &"cultist_open_pupil", &"cultist_impossible_geometry", &"cultist_revelation"],
}
const JOB_LEVELS: Array[int] = [20, 23, 25, 28, 31, 34, 37]
## Categories of the seven slots (section 1): active, passive, active, active, passive, active, active.
const SLOT_CATEGORIES: Array[StringName] = [&"active", &"passive", &"active", &"active", &"passive", &"active", &"active"]
const ONBOARDING_PATTERN := "res://scripts/ui/classes/%s_onboarding.gd"
## Accepted SkillDefinition.element values of kit skills (A2: light is magic damage;
## E10a C1.8 / D5: shadow too, a tag with no resistance axis).
const KIT_ELEMENTS: Array[StringName] = [&"", &"physical", &"fire", &"ice", &"lightning", &"light", &"shadow", &"arcane", &"spirit"]

static var _modules: Dictionary = {}
static var _fixtures: Dictionary = {}
## A14: test-only body folder per identity (install_fixture_body); empty in production.
static var _fixture_bodies: Dictionary = {}
## Bumped whenever the effective module set changes (fixtures); catalogs rebuild on change.
static var revision := 0
static var _cache_revision := -1
static var _skills: Dictionary = {}
static var _skill_owner: Dictionary = {}
static var _validation: Dictionary = {}

static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in MODULES: result.append(id)
	return result

static func is_kit(evolution_id: StringName) -> bool:
	return MODULES.has(evolution_id)

## E10a C1.5: branch of a kit evolution (&"2-1", &"2-2" or &"2-3"); empty when unknown.
static func branch(evolution_id: StringName) -> StringName:
	return StringName(IDENTITIES.get(evolution_id, {}).get("branch", &""))

static func is_pure(evolution_id: StringName) -> bool:
	return branch(evolution_id) in [&"2-1", &"2-2"]

## The E09 hybrid kits (branch 2-3), in registry order.
static func hybrid_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in MODULES:
		if branch(id) == &"2-3": result.append(id)
	return result

## The pure kits of registered bases (branches 2-1 and 2-2), in registry order.
static func pure_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in MODULES:
		if is_pure(id): result.append(id)
	return result

## Affinity label of a kit (reserved or registered base); empty for pure kits.
static func affinity(evolution_id: StringName) -> StringName:
	return StringName(IDENTITIES.get(evolution_id, {}).get("affinity", &""))

## Module of the seam for any ID: a kit module or a registered base module (C1.1).
static func seam_module(module_id: StringName) -> ClassKit:
	if MODULES.has(module_id): return module(module_id)
	return ClassBaseRegistry.module(module_id)

## Kits and registered bases whose data the accessors below aggregate.
static func seam_ids() -> Array[StringName]:
	var result := ids()
	result.append_array(ClassBaseRegistry.ids())
	return result

static func identity(evolution_id: StringName) -> Dictionary:
	return IDENTITIES.get(evolution_id, {}).duplicate(true)

static func origin(evolution_id: StringName) -> StringName:
	return StringName(IDENTITIES.get(evolution_id, {}).get("origin", &""))

## Body folder of a kit or (E10a C1.8) of a registered base.
static func body_folder(evolution_id: StringName) -> StringName:
	if _fixture_bodies.has(evolution_id): return _fixture_bodies[evolution_id]
	if ClassBaseRegistry.is_base(evolution_id): return ClassBaseRegistry.body_folder(evolution_id)
	return StringName(IDENTITIES.get(evolution_id, {}).get("body", &""))

static func body_folders() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in IDENTITIES: result.append(body_folder(id))
	for id: StringName in ClassBaseRegistry.ids(): result.append(body_folder(id))
	return result

static func is_body_kind(kind: StringName) -> bool:
	return kind in body_folders()

## One step back from a body folder without art: a kit folder gives its origin body
## (the folder of a registered base, or the E00 base), a base folder gives its
## fallback body. legacy_body_kind() follows the chain to a legacy atlas kind.
static func body_origin(kind: StringName) -> StringName:
	for id: StringName in IDENTITIES:
		if body_folder(id) == kind:
			var origin_id: StringName = IDENTITIES[id]["origin"]
			return body_folder(origin_id) if ClassBaseRegistry.is_base(origin_id) else origin_id
	for id: StringName in ClassBaseRegistry.ids():
		if body_folder(id) == kind: return ClassBaseRegistry.fallback_body(id)
	return &""

## Legacy atlas kind behind a seam body folder (the chain of body_origin()).
static func legacy_body_kind(kind: StringName) -> StringName:
	var current := kind
	for step: int in 4:
		if not is_body_kind(current): return current
		current = body_origin(current)
	return current

## Catalog module instance (fixture first). Null when the module is missing, and
## in editor tooling (non-tool scripts would be placeholders there).
static func module(evolution_id: StringName) -> ClassKit:
	if _fixtures.has(evolution_id): return _fixtures[evolution_id]
	if not MODULES.has(evolution_id) or Engine.is_editor_hint(): return null
	if not _modules.has(evolution_id):
		var path: String = MODULES[evolution_id]
		var script := load(path) as Script if ResourceLoader.exists(path) else null
		var instance: Variant = script.new() if script != null else null
		_modules[evolution_id] = instance if instance is ClassKit else null
	return _modules[evolution_id]

## Module ready and valid. Only ready kits are offered by ProfileCatalog (C1.3).
static func ready_for_play(evolution_id: StringName) -> bool:
	var kit := module(evolution_id)
	return kit != null and kit.ready_for_play() and validate(evolution_id)["ok"]

static func display_name(evolution_id: StringName) -> String:
	var kit := module(evolution_id)
	var name := kit.display_name() if kit != null else ""
	return name if not name.is_empty() else String(IDENTITIES.get(evolution_id, {}).get("name", evolution_id))

## Kit or registered base owning a skill ID (by the fixed ID tables); empty when none.
static func skill_owner(skill_id: StringName) -> StringName:
	_ensure_cache()
	return _skill_owner.get(skill_id, &"")

static func skill_definition(skill_id: StringName) -> SkillDefinition:
	_ensure_cache()
	return _skills.get(skill_id)

static func skill_ids(evolution_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	result.assign(SKILL_IDS.get(evolution_id, []))
	return result

static func learning_entries(evolution_id: StringName) -> Array[Dictionary]:
	var kit := module(evolution_id)
	return kit.learning_entries() if kit != null else []

static func entry_skill_id(evolution_id: StringName) -> StringName:
	for entry: Dictionary in learning_entries(evolution_id):
		if int(entry.get("free_rank", 0)) == 1: return StringName(entry["skill_id"])
	return &""

static func passive_modifier_source(skill_id: StringName, rank: int) -> Dictionary:
	var kit := seam_module(skill_owner(skill_id))
	return kit.passive_modifier_source(skill_id, rank) if kit != null else {}

static func causal_families(evolution_id: StringName = &"") -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in seam_ids():
		if not evolution_id.is_empty() and id != evolution_id: continue
		var kit := seam_module(id)
		if kit == null: continue
		for family: StringName in kit.causal_families():
			if family not in result: result.append(family)
	return result

static func feedback_recipe(skill_id: StringName) -> Array:
	var owner := skill_owner(skill_id)
	var kit := seam_module(owner)
	if kit == null: return []
	var row: Variant = kit.feedback_recipes().get(skill_id, [])
	return _presentation_row(owner, (row as Array).duplicate()) if row is Array else []

static func feedback_recipe_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id: StringName in seam_ids():
		var kit := seam_module(id)
		if kit == null: continue
		for skill: StringName in kit.feedback_recipes(): result.append(skill)
	return result

static func basic_attack_recipe(evolution_id: StringName) -> Array:
	var kit := seam_module(evolution_id)
	return _presentation_row(evolution_id, kit.basic_attack_recipe().duplicate()) if kit != null else []

## C1.8: the Acólito-affinity hybrids show their arcane rows in the light colour.
static func _presentation_row(owner: StringName, row: Array) -> Array:
	if owner in LIGHT_PRESENTATION_KITS and row.size() == 4 and row[1] == &"arcane": row[1] = &"light"
	return row

static func skill_text(skill_id: StringName) -> Dictionary:
	var kit := seam_module(skill_owner(skill_id))
	if kit == null: return {}
	var entry: Variant = kit.skill_texts().get(skill_id, {})
	return (entry as Dictionary).duplicate(true) if entry is Dictionary else {}

## Code effect of a skill for one bridge kind: {"effect_id", "size", "kit"} or {}.
static func vfx_effect(skill_id: StringName, kind: StringName) -> Dictionary:
	var owner := skill_owner(skill_id)
	var kit := seam_module(owner)
	if kit == null: return {}
	var effects := kit.vfx_effects()
	var ids_sorted: Array = effects.keys()
	ids_sorted.sort()
	for effect_id: StringName in ids_sorted:
		var spec: Dictionary = effects[effect_id]
		if StringName(spec.get("skill_id", &"")) == skill_id and kind in spec.get("kinds", []):
			return {"effect_id": effect_id, "size": float(spec.get("size", 96.0)), "kit": owner}
	return {}

static func draw_vfx(kit_id: StringName, effect_id: StringName, canvas: CanvasItem, pulse: Dictionary, position: Vector2, t: float) -> bool:
	var kit := seam_module(kit_id)
	return kit != null and kit.draw_vfx(effect_id, canvas, pulse, position, t)

## Presentation body for an evolution: the kit folder when its art exists, else the origin
## body. E10a C1.8: a registered base origin gives its own folder when it has art, else its
## fallback body; an empty evolution resolves the origin alone.
static func actor_kind(evolution_id: StringName, origin_id: StringName) -> StringName:
	var folder := body_folder(evolution_id) if is_kit(evolution_id) else &""
	if not folder.is_empty() and not DirectionalAnimationSet.kit_body_path(folder).is_empty(): return folder
	return base_actor_kind(origin_id)

## Body of an origin: an E00 base is itself; a registered base is its folder with art,
## else its fallback body.
static func base_actor_kind(origin_id: StringName) -> StringName:
	if not ClassBaseRegistry.is_base(origin_id): return origin_id
	var folder := body_folder(origin_id)
	return folder if not DirectionalAnimationSet.kit_body_path(folder).is_empty() else ClassBaseRegistry.fallback_body(origin_id)

## C1.12: `res://scripts/ui/classes/<id>_onboarding.gd` when it exists (kits and,
## E10a, registered bases).
static func onboarding_script(evolution_id: StringName) -> Script:
	var path := ONBOARDING_PATTERN % evolution_id
	return load(path) as Script if (is_kit(evolution_id) or ClassBaseRegistry.is_base(evolution_id)) and ResourceLoader.exists(path) else null

## {"ok", "error_code", "detail"}; codes listed in the API document.
static func validate(evolution_id: StringName) -> Dictionary:
	_ensure_cache()
	if not MODULES.has(evolution_id): return _failure(&"kit_unknown_identity", String(evolution_id))
	return _validation.get(evolution_id, _failure(&"kit_module_missing", String(evolution_id))).duplicate(true)

# --- Fixtures (tests only) ---------------------------------------------------------

## Replaces a production module by a fixture module for the rest of the process or
## until clear_fixtures(). Never used by production code.
static func install_fixture(evolution_id: StringName, kit: ClassKit) -> bool:
	if not MODULES.has(evolution_id) or kit == null or kit.kit_id() != evolution_id: return false
	_fixtures[evolution_id] = kit
	revision += 1
	return true

## A14: points the body folder of one identity at a fixture folder until
## clear_fixtures(), so the C1.8 fallback can be proven on a folder that never has
## art, whatever production art exists. Refuses unknown identities, empty names and
## folders that already belong to an identity. Never used by production code.
static func install_fixture_body(evolution_id: StringName, folder: StringName) -> bool:
	if not IDENTITIES.has(evolution_id) or folder.is_empty() or folder in body_folders(): return false
	_fixture_bodies[evolution_id] = folder
	revision += 1
	return true

static func clear_fixtures() -> void:
	ClassBaseRegistry.clear_fixtures()
	if _fixtures.is_empty() and _fixture_bodies.is_empty(): return
	_fixtures.clear()
	_fixture_bodies.clear()
	revision += 1

# --- Internals ------------------------------------------------------------------

static func _ensure_cache() -> void:
	if _cache_revision == revision: return
	_cache_revision = revision
	_skills = {}
	_skill_owner = {}
	_validation = {}
	for id: StringName in MODULES:
		for skill: StringName in SKILL_IDS[id]: _skill_owner[skill] = id
	# E10a C1.2: base library skills belong to their base module.
	for id: StringName in ClassBaseRegistry.ids():
		for skill: StringName in ClassBaseRegistry.skill_ids(id): _skill_owner[skill] = id
		if ClassBaseRegistry.validate(id)["ok"]:
			for definition: SkillDefinition in ClassBaseRegistry.module(id).skill_definitions(): _skills[definition.id] = definition
	for id: StringName in MODULES:
		var kit := module(id)
		if kit == null:
			_validation[id] = _failure(&"kit_module_missing", String(MODULES[id]))
			continue
		_validation[id] = _validate_module(id, kit)
		if not _validation[id]["ok"]: continue
		for definition: SkillDefinition in kit.skill_definitions(): _skills[definition.id] = definition

static func _validate_module(id: StringName, kit: ClassKit) -> Dictionary:
	if kit.kit_id() != id: return _failure(&"kit_identity_mismatch", String(kit.kit_id()))
	var allowed: Array = SKILL_IDS[id]
	var seen: Dictionary = {}
	for definition: SkillDefinition in kit.skill_definitions():
		if definition == null or definition.id not in allowed: return _failure(&"kit_skill_outside_identity", String(definition.id) if definition != null else "null")
		if seen.has(definition.id): return _failure(&"kit_skill_duplicate", String(definition.id))
		if definition.handler_id != SkillDefinition.Handler.KIT or not definition.is_rank_catalog_valid(): return _failure(&"kit_skill_invalid", String(definition.id))
		if definition.element not in KIT_ELEMENTS or not EffectTags.valid(definition.tags): return _failure(&"kit_skill_invalid", String(definition.id) + ":element_or_tags")
		var expected_category := SkillDefinition.Category.ACTIVE if SLOT_CATEGORIES[allowed.find(definition.id)] == &"active" else SkillDefinition.Category.PASSIVE
		if definition.category != expected_category: return _failure(&"kit_skill_invalid", String(definition.id) + ":category")
		seen[definition.id] = true
	var learned: Dictionary = {}
	for entry: Dictionary in kit.learning_entries():
		var skill := StringName(entry.get("skill_id", &""))
		if not seen.has(skill) or learned.has(skill): return _failure(&"kit_learning_invalid", String(skill))
		var slot := allowed.find(skill)
		var category := StringName(entry.get("category", &""))
		var free_rank := int(entry.get("free_rank", -1))
		var purchased := int(entry.get("max_purchased_rank", -1))
		var cap := SkillDefinition.MAX_ACTIVE_RANK if category == &"active" else SkillDefinition.MAX_PASSIVE_RANK
		if category != SLOT_CATEGORIES[slot] or int(entry.get("job_level", -1)) != JOB_LEVELS[slot] or free_rank != (1 if slot == 0 else 0) or purchased < 0 or free_rank + purchased != cap: return _failure(&"kit_learning_invalid", String(skill))
		if not entry.get("prerequisites", {}) is Dictionary: return _failure(&"kit_learning_invalid", String(skill) + ":prerequisites")
		learned[skill] = true
	if learned.size() != seen.size(): return _failure(&"kit_learning_invalid", "skills_without_learning")
	for skill: StringName in kit.feedback_recipes():
		var row: Variant = kit.feedback_recipes()[skill]
		if not seen.has(skill) or not row is Array or row.size() != 4 or row[0] not in FeedbackRecipeCatalog.FAMILIES or row[1] not in FeedbackRecipeCatalog.ELEMENTS or not StringName(row[2]).is_empty(): return _failure(&"kit_recipe_invalid", String(skill))
	for family: StringName in kit.causal_families():
		if not String(family).begins_with(IDENTITIES[id]["prefix"]): return _failure(&"kit_family_invalid", String(family))
	for effect_id: StringName in kit.vfx_effects():
		var spec: Variant = kit.vfx_effects()[effect_id]
		if not String(effect_id).begins_with(IDENTITIES[id]["prefix"]) or not spec is Dictionary or not seen.has(StringName(spec.get("skill_id", &""))) or not spec.get("kinds") is Array or spec["kinds"].is_empty(): return _failure(&"kit_vfx_invalid", String(effect_id))
	for skill: StringName in kit.skill_texts():
		if not seen.has(skill) or not kit.skill_texts()[skill] is Dictionary: return _failure(&"kit_text_invalid", String(skill))
	if kit.ready_for_play():
		if seen.size() != allowed.size(): return _failure(&"kit_incomplete", "skills")
		for skill: StringName in allowed:
			var text: Dictionary = kit.skill_texts().get(skill, {})
			if String(text.get("effect", "")).is_empty(): return _failure(&"kit_incomplete", String(skill) + ":text")
			if not kit.feedback_recipes().has(skill): return _failure(&"kit_incomplete", String(skill) + ":recipe")
	return {"ok": true, "error_code": &"", "detail": ""}

static func _failure(code: StringName, detail: String = "") -> Dictionary:
	return {"ok": false, "error_code": code, "detail": detail}
