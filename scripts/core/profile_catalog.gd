class_name ProfileCatalog
extends RefCounted
## Minimal persistence metadata. E03/E06 extend this catalog before new IDs are saved.

const ACTIVE: StringName = &"active"
const PASSIVE: StringName = &"passive"
const BASE_WALLET: StringName = &"base"
const EVOLUTION_WALLET: StringName = &"evolution"
const MAX_ACTIVE_RANK := 5
const MAX_PASSIVE_RANK := 3

var _skills: Dictionary[StringName, Dictionary] = {}
var _equipment: Dictionary[StringName, Dictionary] = {}
var _evolutions: Dictionary[StringName, EvolutionDefinition] = {}
var _evolution_order: Array[StringName] = []
var _sealed := false
var _build_error := false

static func pilot(
	additional_equipment: Dictionary = {},
	additional_skills: Dictionary = {},
	evolution_overrides: Dictionary = {}
) -> ProfileCatalog:
	var catalog := ProfileCatalog.new()
	catalog.add_skill(&"slash", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"dash", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"shield_wall", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"provoke", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"perseverance", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"piercing_shout", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"fury", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"brutal_strike", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"concentrated_rage", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"terrifying_shout", [&"swordsman"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"swordsman_resistance", [&"swordsman"], PASSIVE, BASE_WALLET, 0, 3)
	catalog.add_skill(&"vigor", [&"swordsman"], PASSIVE, BASE_WALLET, 0, 3)
	catalog.add_skill(&"blood_thirst", [&"swordsman"], PASSIVE, BASE_WALLET, 0, 3)
	catalog.add_skill(&"fireball", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"fire_wall", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"fire_spear", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"ice_spear", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"lightning", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"electric_discharge", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"lightning_wall", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"soul_impact", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"haunt", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"phantom_barrier", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"ice_wall", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"teleport", [&"mage"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"mage_mana_regeneration", [&"mage"], PASSIVE, BASE_WALLET, 0, 3)
	catalog.add_skill(&"double_shot", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"piercing_arrow", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"arrow_rain", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"extended_aim", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"snare_trap", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"explosive_trap", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"slowing_arrow", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"foliage_shelter", [&"archer"], ACTIVE, BASE_WALLET, 0, 5)
	catalog.add_skill(&"archer_precision", [&"archer"], PASSIVE, BASE_WALLET, 0, 3)
	catalog.add_skill(&"archer_cadence", [&"archer"], PASSIVE, BASE_WALLET, 0, 3)
	catalog.add_skill(&"trap_technique", [&"archer"], PASSIVE, BASE_WALLET, 0, 3)
	# A fixture may replace Defender's entire exclusive library; production never mixes both sets.
	if not evolution_overrides.has(&"defender") and not evolution_overrides.has("defender"):
		catalog._register_defender_skills()
	if not evolution_overrides.has(&"berserker") and not evolution_overrides.has("berserker"):
		catalog._register_berserker_skills()
	if not evolution_overrides.has(&"elementalist") and not evolution_overrides.has("elementalist"):
		catalog._register_elementalist_skills()
	if not evolution_overrides.has(&"spiritualist") and not evolution_overrides.has("spiritualist"):
		catalog._register_spiritualist_skills()
	var raw_geometer_override: Variant = evolution_overrides.get(&"mg_ar", evolution_overrides.get("mg_ar", {}))
	var geometer_override: Dictionary = raw_geometer_override if raw_geometer_override is Dictionary else {}
	if not geometer_override.has("exclusive_skill_ids") and not geometer_override.has(&"exclusive_skill_ids"):
		catalog._register_geometer_skills()
	var raw_sentinel_override: Variant = evolution_overrides.get(&"sentinel", evolution_overrides.get("sentinel", {}))
	var sentinel_override: Dictionary = raw_sentinel_override if raw_sentinel_override is Dictionary else {}
	if not sentinel_override.has("exclusive_skill_ids") and not sentinel_override.has(&"exclusive_skill_ids"):
		catalog._register_sentinel_skills()
	for raw_item_id: Variant in additional_equipment:
		var metadata: Dictionary = additional_equipment[raw_item_id]
		var allowed_base_classes: Array[StringName] = []
		allowed_base_classes.assign(metadata.get("allowed_base_classes", []))
		catalog.add_equipment(StringName(raw_item_id), metadata.get("slot", &""), allowed_base_classes, metadata.get("starter", false))
	for raw_skill_id: Variant in additional_skills:
		var metadata: Dictionary = additional_skills[raw_skill_id]
		var allowed_base_classes: Array[StringName] = []
		allowed_base_classes.assign(metadata.get("allowed_base_classes", []))
		catalog.add_skill(
			StringName(raw_skill_id),
			allowed_base_classes,
			metadata.get("category", &""),
			metadata.get("wallet", &""),
			int(metadata.get("free_rank", -1)),
			int(metadata.get("max_purchased_rank", -1)),
			metadata.get("required_evolution_id", &""),
			metadata.get("rank_requirements", {})
		)
	catalog._register_e00_evolutions(evolution_overrides)
	return catalog.seal()

func add_skill(
	skill_id: StringName,
	allowed_base_classes: Array[StringName],
	category: StringName,
	wallet: StringName,
	free_rank: int,
	max_purchased_rank: int,
	required_evolution_id: StringName = &"",
	rank_requirements: Dictionary = {}
) -> bool:
	if _sealed:
		return false
	if _skills.has(skill_id):
		_build_error = true
		return false
	var total_rank := free_rank + max_purchased_rank
	var requirements_result := _validated_rank_requirements(total_rank, wallet, rank_requirements)
	if not requirements_result["ok"]:
		_build_error = true
		return false
	_skills[skill_id] = {
		"allowed_base_classes": allowed_base_classes.duplicate(),
		"category": category,
		"wallet": wallet,
		"free_rank": free_rank,
		"max_purchased_rank": max_purchased_rank,
		"required_evolution_id": required_evolution_id,
		"rank_requirements": requirements_result["requirements"],
	}
	return true

func add_evolution(definition: EvolutionDefinition) -> bool:
	if _sealed:
		return false
	if definition == null or _evolutions.has(definition.id):
		_build_error = true
		return false
	_evolutions[definition.id] = definition.copy_definition()
	_evolution_order.append(definition.id)
	return true

func add_equipment(item_id: StringName, slot: StringName, allowed_base_classes: Array[StringName], starter: bool = false) -> bool:
	if _sealed:
		return false
	if _equipment.has(item_id):
		_build_error = true
		return false
	_equipment[item_id] = {
		"slot": slot,
		"allowed_base_classes": allowed_base_classes.duplicate(),
		"starter": starter,
	}
	return true

func seal() -> ProfileCatalog:
	_sealed = true
	return self

func copy_catalog() -> ProfileCatalog:
	var copy := ProfileCatalog.new()
	copy._skills = _skills.duplicate(true)
	copy._equipment = _equipment.duplicate(true)
	for evolution_id: StringName in _evolution_order:
		copy._evolutions[evolution_id] = _evolutions[evolution_id].copy_definition()
	copy._evolution_order = _evolution_order.duplicate()
	copy._build_error = _build_error
	return copy.seal()

func is_valid() -> bool:
	if _build_error:
		return false
	for skill_id: StringName in _skills:
		if not IdentityIds.is_technical_id(String(skill_id)):
			return false
		var metadata: Dictionary = _skills[skill_id]
		if metadata.get("category") not in [ACTIVE, PASSIVE] or metadata.get("wallet") not in [BASE_WALLET, EVOLUTION_WALLET]:
			return false
		if int(metadata.get("free_rank", -1)) < 0 or int(metadata.get("free_rank", -1)) > 1 or int(metadata.get("max_purchased_rank", -1)) < 0:
			return false
		var total_rank := int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
		var rank_cap := MAX_ACTIVE_RANK if metadata["category"] == ACTIVE else MAX_PASSIVE_RANK
		if total_rank > rank_cap:
			return false
		if not _valid_origins(metadata.get("allowed_base_classes")):
			return false
		var required_evolution_id: StringName = metadata.get("required_evolution_id", &"")
		if metadata["wallet"] == EVOLUTION_WALLET:
			if not IdentityIds.is_evolution(required_evolution_id) or not _evolution_matches_any_origin(required_evolution_id, metadata["allowed_base_classes"]):
				return false
		elif not required_evolution_id.is_empty():
			return false
		if not _rank_requirements_are_valid(skill_id, metadata):
			return false
	if _has_requirement_cycle():
		return false
	if not _evolution_definitions_are_valid():
		return false
	var starter_slots: Dictionary[StringName, bool] = {}
	for metadata: Dictionary in _equipment.values():
		if metadata.get("slot") not in IdentityIds.equipment_slots() or not _valid_origins(metadata.get("allowed_base_classes")):
			return false
		if not metadata.get("starter") is bool:
			return false
		if metadata["starter"]:
			for base_class_id: StringName in metadata["allowed_base_classes"]:
				var starter_key := StringName("%s:%s" % [base_class_id, metadata["slot"]])
				if starter_slots.has(starter_key):
					return false
				starter_slots[starter_key] = true
	return true

func skill_metadata(skill_id: StringName) -> Dictionary:
	return _skills.get(skill_id, {}).duplicate(true)

func equipment_metadata(item_id: StringName) -> Dictionary:
	return _equipment.get(item_id, {}).duplicate(true)

func evolution_definition(evolution_id: StringName) -> EvolutionDefinition:
	var definition: EvolutionDefinition = _evolutions.get(evolution_id)
	return definition.copy_definition() if definition != null else null

func evolution_definitions() -> Array[EvolutionDefinition]:
	var definitions: Array[EvolutionDefinition] = []
	for evolution_id: StringName in _evolution_order:
		definitions.append(_evolutions[evolution_id].copy_definition())
	return definitions

func evolution_definitions_for_origin(base_class_id: StringName) -> Array[EvolutionDefinition]:
	var definitions: Array[EvolutionDefinition] = []
	for evolution_id: StringName in _evolution_order:
		var definition: EvolutionDefinition = _evolutions[evolution_id]
		if definition.origin_class_id == base_class_id:
			definitions.append(definition.copy_definition())
	return definitions

func knows_equipment(item_id: StringName) -> bool:
	return _equipment.has(item_id)

func base_class_is_available(base_class_id: StringName) -> bool:
	if not IdentityIds.is_base_class(base_class_id):
		return false
	var counts := _base_skill_counts(base_class_id)
	return counts[ACTIVE] >= 2 and counts[PASSIVE] >= 1

func initial_skill_slots(base_class_id: StringName) -> Dictionary:
	var active_slots: Array[Variant] = []
	var passive_slots: Array[Variant] = []
	active_slots.resize(CharacterState.ACTIVE_SLOT_COUNT)
	passive_slots.resize(CharacterState.PASSIVE_SLOT_COUNT)
	return {"active_slots": active_slots, "passive_slots": passive_slots}

func starter_equipment(base_class_id: StringName) -> Dictionary[StringName, Variant]:
	var equipped: Dictionary[StringName, Variant] = {}
	for slot: StringName in IdentityIds.equipment_slots():
		equipped[slot] = null
	for item_id: StringName in _equipment:
		var metadata: Dictionary = _equipment[item_id]
		if metadata["starter"] and base_class_id in metadata["allowed_base_classes"]:
			equipped[metadata["slot"]] = item_id
	return equipped

func starter_item_ids(base_class_id: StringName) -> Array[StringName]:
	var item_ids: Array[StringName] = []
	var equipped := starter_equipment(base_class_id)
	for slot: StringName in IdentityIds.equipment_slots():
		var item_id: Variant = equipped[slot]
		if item_id != null:
			item_ids.append(item_id)
	return item_ids

func skill_ids_for_identity(base_class_id: StringName, evolution_id: StringName = &"") -> Array[StringName]:
	## Legal catalog library, including unlearned skills; a directional affinity never grants its other origin's library.
	var skill_ids: Array[StringName] = []
	if not IdentityIds.is_base_class(base_class_id):
		return skill_ids
	if not evolution_id.is_empty() and not IdentityIds.evolution_belongs_to(evolution_id, base_class_id):
		return skill_ids
	for skill_id: StringName in _skills:
		if skill_is_allowed(skill_id, base_class_id, evolution_id):
			skill_ids.append(skill_id)
	return skill_ids

func effective_skill_ranks(
	base_class_id: StringName,
	evolution_id: StringName,
	purchased_ranks: Dictionary[StringName, int],
	granted_ranks: Dictionary[StringName, int] = {}
) -> Dictionary[StringName, int]:
	var effective: Dictionary[StringName, int] = {}
	for skill_id: StringName in skill_ids_for_identity(base_class_id, evolution_id):
		var metadata: Dictionary = _skills[skill_id]
		var rank: int = int(metadata["free_rank"]) + int(granted_ranks.get(skill_id, 0)) + int(purchased_ranks.get(skill_id, 0))
		if rank > 0:
			effective[skill_id] = rank
	return effective

func skill_points_spent(purchased_ranks: Dictionary[StringName, int], wallet: StringName) -> int:
	var spent := 0
	for skill_id: StringName in purchased_ranks:
		var metadata: Dictionary = _skills.get(skill_id, {})
		if not metadata.is_empty() and metadata["wallet"] == wallet:
			spent += int(purchased_ranks[skill_id])
	return spent

func check_rank_requirements(
	skill_id: StringName,
	target_rank: int,
	job_level: int,
	effective_ranks: Dictionary[StringName, int]
) -> Dictionary:
	var metadata: Dictionary = _skills.get(skill_id, {})
	if metadata.is_empty() or target_rank < 1:
		return {"ok": false, "error_code": &"invalid_skill_id"}
	var requirements: Dictionary = metadata["rank_requirements"]
	if not requirements.has(target_rank):
		return {"ok": false, "error_code": &"rank_cap_reached"}
	var requirement: Dictionary = requirements[target_rank]
	if job_level < int(requirement["job_level"]):
		return {"ok": false, "error_code": &"requirements_unmet"}
	for prerequisite_id: StringName in requirement["skill_ranks"]:
		if effective_ranks.get(prerequisite_id, 0) < int(requirement["skill_ranks"][prerequisite_id]):
			return {"ok": false, "error_code": &"requirements_unmet"}
	return {"ok": true}

func validate_purchased_ranks(
	base_class_id: StringName,
	evolution_id: StringName,
	job_level: int,
	purchased_ranks: Dictionary[StringName, int],
	granted_ranks: Dictionary[StringName, int] = {}
) -> Dictionary:
	var effective := effective_skill_ranks(base_class_id, evolution_id, purchased_ranks, granted_ranks)
	for skill_id: StringName in granted_ranks:
		if not skill_is_allowed(skill_id, base_class_id, evolution_id):
			return {"ok": false, "error_code": &"invalid_catalog"}
		var granted := int(granted_ranks[skill_id])
		var granted_metadata := _skills[skill_id]
		if granted < 1 or granted > int(granted_metadata["free_rank"]) + int(granted_metadata["max_purchased_rank"]):
			return {"ok": false, "error_code": &"invalid_skill_ranks"}
	for skill_id: StringName in purchased_ranks:
		if not skill_is_allowed(skill_id, base_class_id, evolution_id):
			return {"ok": false, "error_code": &"invalid_catalog"}
		var metadata := _skills[skill_id]
		var purchased := int(purchased_ranks[skill_id])
		var granted: int = int(granted_ranks.get(skill_id, 0))
		var maximum_rank: int = int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
		if purchased < 0 or purchased > int(metadata["max_purchased_rank"]) or granted + purchased > maximum_rank:
			return {"ok": false, "error_code": &"invalid_skill_ranks"}
		for target_rank: int in range(int(metadata["free_rank"]) + granted + 1, int(metadata["free_rank"]) + granted + purchased + 1):
			var requirement := check_rank_requirements(skill_id, target_rank, job_level, effective)
			if not requirement["ok"]:
				return requirement
	return {"ok": true}

func evolution_is_ready(evolution_id: StringName, base_class_id: StringName) -> bool:
	var definition: EvolutionDefinition = _evolutions.get(evolution_id)
	return definition != null and definition.origin_class_id == base_class_id and definition.content_ready

func build_is_ready(character: CharacterState) -> bool:
	if character == null or not base_class_is_available(character.base_class_id):
		return false
	return character.evolution_id.is_empty() or evolution_is_ready(character.evolution_id, character.base_class_id)

func skill_is_allowed(skill_id: StringName, base_class_id: StringName, evolution_id: StringName) -> bool:
	if not IdentityIds.is_base_class(base_class_id):
		return false
	if not evolution_id.is_empty() and not IdentityIds.evolution_belongs_to(evolution_id, base_class_id):
		return false
	var metadata: Dictionary = _skills.get(skill_id, {})
	if metadata.is_empty() or base_class_id not in metadata["allowed_base_classes"]:
		return false
	var required_evolution_id: StringName = metadata["required_evolution_id"]
	return required_evolution_id.is_empty() or required_evolution_id == evolution_id

func equipment_is_allowed(item_id: StringName, slot: StringName, base_class_id: StringName) -> bool:
	var metadata: Dictionary = _equipment.get(item_id, {})
	return not metadata.is_empty() and metadata["slot"] == slot and base_class_id in metadata["allowed_base_classes"]

func _register_defender_skills() -> void:
	var origin: Array[StringName] = [&"swordsman"]
	add_skill(&"defender_counterstroke", origin, ACTIVE, EVOLUTION_WALLET, 1, 4, &"defender", _evolution_rank_requirements(5, 20))
	add_skill(&"defender_watch", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"defender", _evolution_rank_requirements(3, 23))
	add_skill(&"defender_anchor", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"defender", _evolution_rank_requirements(5, 25))
	add_skill(&"defender_line_lock", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"defender", _evolution_rank_requirements(5, 28))
	add_skill(&"defender_guard_return", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"defender", _evolution_rank_requirements(3, 31))
	add_skill(&"defender_wall_advance", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"defender", _evolution_rank_requirements(5, 34))
	add_skill(&"defender_reprisal_wave", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"defender", _evolution_rank_requirements(5, 37))

func _register_berserker_skills() -> void:
	var origin: Array[StringName] = [&"swordsman"]
	add_skill(&"berserker_rupture", origin, ACTIVE, EVOLUTION_WALLET, 1, 4, &"berserker", _evolution_rank_requirements(5, 20))
	add_skill(&"berserker_obstinacy", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"berserker", _evolution_rank_requirements(3, 23))
	add_skill(&"berserker_wound_leap", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"berserker", _evolution_rank_requirements(5, 25))
	add_skill(&"berserker_execution", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"berserker", _evolution_rank_requirements(5, 28))
	add_skill(&"berserker_pursuit", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"berserker", _evolution_rank_requirements(3, 31))
	add_skill(&"berserker_blood_rift", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"berserker", _evolution_rank_requirements(5, 34))
	add_skill(&"berserker_breath_steal", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"berserker", _evolution_rank_requirements(5, 37))

func _register_elementalist_skills() -> void:
	var origin: Array[StringName] = [&"mage"]
	add_skill(&"elementalist_flame_burst", origin, ACTIVE, EVOLUTION_WALLET, 1, 4, &"elementalist", _evolution_rank_requirements(5, 20))
	add_skill(&"elementalist_prismatic_focus", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"elementalist", _evolution_rank_requirements(3, 23))
	add_skill(&"elementalist_glacial_ring", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"elementalist", _evolution_rank_requirements(5, 25))
	add_skill(&"elementalist_lightning_arc", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"elementalist", _evolution_rank_requirements(5, 28))
	add_skill(&"elementalist_prismatic_resonance", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"elementalist", _evolution_rank_requirements(3, 31))
	add_skill(&"elementalist_ember_path", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"elementalist", _evolution_rank_requirements(5, 34))
	add_skill(&"elementalist_tri_nova", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"elementalist", _evolution_rank_requirements(5, 37))

func _register_spiritualist_skills() -> void:
	var origin: Array[StringName] = [&"mage"]
	add_skill(&"spiritualist_echo_curse", origin, ACTIVE, EVOLUTION_WALLET, 1, 4, &"spiritualist", _evolution_rank_requirements(5, 20))
	add_skill(&"spiritualist_echo_recovery", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"spiritualist", _evolution_rank_requirements(3, 23))
	add_skill(&"spiritualist_soul_drain", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"spiritualist", _evolution_rank_requirements(5, 25))
	add_skill(&"spiritualist_spectral_veil", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"spiritualist", _evolution_rank_requirements(5, 28))
	add_skill(&"spiritualist_channel_focus", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"spiritualist", _evolution_rank_requirements(3, 31))
	add_skill(&"spiritualist_procession", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"spiritualist", _evolution_rank_requirements(5, 34))
	add_skill(&"spiritualist_dissipation", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"spiritualist", _evolution_rank_requirements(5, 37))

func _register_geometer_skills() -> void:
	var origin: Array[StringName] = [&"mage"]
	add_skill(&"geometer_trace", origin, ACTIVE, EVOLUTION_WALLET, 1, 4, &"mg_ar", _evolution_rank_requirements(5, 20))
	add_skill(&"geometer_incidence", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"mg_ar", _evolution_rank_requirements(3, 23))
	add_skill(&"geometer_translation", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"mg_ar", _evolution_rank_requirements(5, 25))
	add_skill(&"geometer_triangulation", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"mg_ar", _evolution_rank_requirements(5, 28))
	add_skill(&"geometer_vector_memory", origin, PASSIVE, EVOLUTION_WALLET, 0, 3, &"mg_ar", _evolution_rank_requirements(3, 31))
	add_skill(&"geometer_collapse", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"mg_ar", _evolution_rank_requirements(5, 34))
	add_skill(&"geometer_rewrite", origin, ACTIVE, EVOLUTION_WALLET, 0, 5, &"mg_ar", _evolution_rank_requirements(5, 37))

func _register_sentinel_skills() -> void:
	var origin: Array[StringName] = [&"archer"]
	var gates: Array[int] = [20, 20, 23, 25, 28, 31, 31, 34, 37]
	for index: int in SentinelTuning.SKILL_IDS.size():
		var skill_id := SentinelTuning.SKILL_IDS[index]
		var maximum := SentinelTuning.max_rank(skill_id)
		var free_rank := 1 if index == 0 else 0
		add_skill(skill_id, origin, PASSIVE if maximum == 3 else ACTIVE, EVOLUTION_WALLET, free_rank, maximum - free_rank, &"sentinel", _evolution_rank_requirements(maximum, gates[index]))

func _evolution_rank_requirements(max_rank: int, job_level: int) -> Dictionary:
	var requirements: Dictionary = {}
	for rank: int in range(1, max_rank + 1):
		requirements[rank] = {"job_level": job_level}
	return requirements

func _register_e00_evolutions(overrides: Dictionary) -> void:
	var specs: Array[Dictionary] = [
		{"id": IdentityIds.DEFENDER, "name": "Defendente", "branch": EvolutionDefinition.BRANCH_2_1, "affinity": &""},
		{"id": IdentityIds.BERSERKER, "name": "Berserker", "branch": EvolutionDefinition.BRANCH_2_2, "affinity": &""},
		{"id": IdentityIds.SP_MG, "name": "Cavaleiro Rúnico", "branch": EvolutionDefinition.BRANCH_2_3, "affinity": IdentityIds.MAGE},
		{"id": IdentityIds.SP_AR, "name": "Baluarte de Cerco", "branch": EvolutionDefinition.BRANCH_2_3, "affinity": IdentityIds.ARCHER},
		{"id": IdentityIds.ELEMENTALIST, "name": "Elementalista", "branch": EvolutionDefinition.BRANCH_2_1, "affinity": &""},
		{"id": IdentityIds.SPIRITUALIST, "name": "Espiritualista", "branch": EvolutionDefinition.BRANCH_2_2, "affinity": &""},
		{"id": IdentityIds.MG_SP, "name": "Devastador Astral", "branch": EvolutionDefinition.BRANCH_2_3, "affinity": IdentityIds.SWORDSMAN},
		{"id": IdentityIds.MG_AR, "name": "Geômetra", "branch": EvolutionDefinition.BRANCH_2_3, "affinity": IdentityIds.ARCHER},
		{"id": IdentityIds.SENTINEL, "name": "Sentinela", "branch": EvolutionDefinition.BRANCH_2_1, "affinity": &""},
		{"id": IdentityIds.HUNTER, "name": "Caçador", "branch": EvolutionDefinition.BRANCH_2_2, "affinity": &""},
		{"id": IdentityIds.AR_SP, "name": "Saqueador", "branch": EvolutionDefinition.BRANCH_2_3, "affinity": IdentityIds.SWORDSMAN},
		{"id": IdentityIds.AR_MG, "name": "Caçador de Espectros", "branch": EvolutionDefinition.BRANCH_2_3, "affinity": IdentityIds.MAGE},
	]
	var normalized_overrides: Dictionary[StringName, Dictionary] = {}
	for raw_id: Variant in overrides:
		if not (raw_id is String or raw_id is StringName) or not overrides[raw_id] is Dictionary:
			_build_error = true
			continue
		normalized_overrides[StringName(raw_id)] = overrides[raw_id].duplicate(true)
	var known_ids: Dictionary[StringName, bool] = {}
	for spec: Dictionary in specs:
		known_ids[spec["id"]] = true
	for evolution_id: StringName in normalized_overrides:
		if not known_ids.has(evolution_id):
			_build_error = true
	for spec: Dictionary in specs:
		var definition := EvolutionDefinition.new()
		definition.id = spec["id"]
		definition.display_name = spec["name"]
		definition.origin_class_id = IdentityIds.evolution_origin(definition.id)
		definition.branch_kind = spec["branch"]
		definition.affinity_class_id = spec["affinity"]
		if definition.id == &"defender" and not normalized_overrides.has(definition.id):
			definition.entry_skill_id = &"defender_counterstroke"
			definition.content_ready = true
			definition.exclusive_skill_ids = [
				&"defender_counterstroke", &"defender_watch", &"defender_anchor",
				&"defender_line_lock", &"defender_guard_return",
				&"defender_wall_advance", &"defender_reprisal_wave",
			]
		if definition.id == &"berserker" and not normalized_overrides.has(definition.id):
			definition.entry_skill_id = &"berserker_rupture"
			definition.content_ready = true
			definition.exclusive_skill_ids = [
				&"berserker_rupture", &"berserker_obstinacy", &"berserker_wound_leap",
				&"berserker_execution", &"berserker_pursuit",
				&"berserker_blood_rift", &"berserker_breath_steal",
			]
		if definition.id == &"elementalist" and not normalized_overrides.has(definition.id):
			definition.entry_skill_id = &"elementalist_flame_burst"
			definition.content_ready = true
			definition.exclusive_skill_ids = [
				&"elementalist_flame_burst", &"elementalist_prismatic_focus",
				&"elementalist_glacial_ring", &"elementalist_lightning_arc",
				&"elementalist_prismatic_resonance", &"elementalist_ember_path",
				&"elementalist_tri_nova",
			]
		if definition.id == &"spiritualist" and not normalized_overrides.has(definition.id):
			definition.entry_skill_id = &"spiritualist_echo_curse"
			definition.content_ready = true
			definition.exclusive_skill_ids = [&"spiritualist_echo_curse", &"spiritualist_echo_recovery", &"spiritualist_soul_drain", &"spiritualist_spectral_veil", &"spiritualist_channel_focus", &"spiritualist_procession", &"spiritualist_dissipation"]
		if definition.id == &"mg_ar" and (not normalized_overrides.has(definition.id) or (not normalized_overrides[definition.id].has("exclusive_skill_ids") and not normalized_overrides[definition.id].has(&"exclusive_skill_ids"))):
			definition.entry_skill_id = &"geometer_trace"
			# G7 integrated candidate; publishing playtest still requires technical review.
			definition.content_ready = true
			definition.exclusive_skill_ids = [&"geometer_trace", &"geometer_incidence", &"geometer_translation", &"geometer_triangulation", &"geometer_vector_memory", &"geometer_collapse", &"geometer_rewrite"]
		if definition.id == &"sentinel" and (not normalized_overrides.has(definition.id) or (not normalized_overrides[definition.id].has("exclusive_skill_ids") and not normalized_overrides[definition.id].has(&"exclusive_skill_ids"))):
			definition.entry_skill_id = &"sentinel_headshot"
			# S0 data are available to isolated tests, never a partial playtest candidate.
			definition.content_ready = false
			definition.exclusive_skill_ids = SentinelTuning.SKILL_IDS.duplicate()
		if normalized_overrides.has(definition.id):
			_apply_evolution_override(definition, normalized_overrides[definition.id])
		add_evolution(definition)

func _apply_evolution_override(definition: EvolutionDefinition, override: Dictionary) -> void:
	for raw_field: Variant in override:
		if not (raw_field is String or raw_field is StringName):
			_build_error = true
			continue
		var field := String(raw_field)
		var value: Variant = override[raw_field]
		match field:
			"entry_skill_id":
				if not (value is String or value is StringName):
					_build_error = true
				else:
					definition.entry_skill_id = StringName(value)
			"exclusive_skill_ids":
				if not value is Array:
					_build_error = true
				else:
					var skill_ids: Array[StringName] = []
					for raw_skill_id: Variant in value:
						if not (raw_skill_id is String or raw_skill_id is StringName):
							_build_error = true
							continue
						skill_ids.append(StringName(raw_skill_id))
					definition.exclusive_skill_ids = skill_ids
			"content_ready":
				if not value is bool:
					_build_error = true
				else:
					definition.content_ready = value
			_:
				_build_error = true

func _evolution_definitions_are_valid() -> bool:
	if _evolution_order.size() != _evolutions.size():
		return false
	var seen: Dictionary[StringName, bool] = {}
	for evolution_id: StringName in _evolution_order:
		if seen.has(evolution_id) or not _evolutions.has(evolution_id):
			return false
		seen[evolution_id] = true
		if not _evolution_definition_is_valid(_evolutions[evolution_id]):
			return false
	return true

func _evolution_definition_is_valid(definition: EvolutionDefinition) -> bool:
	if definition == null or not IdentityIds.is_evolution(definition.id):
		return false
	if definition.origin_class_id != IdentityIds.evolution_origin(definition.id):
		return false
	if definition.display_name.strip_edges().is_empty():
		return false
	if definition.required_base_level != 10 or definition.required_job_level != ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL:
		return false
	var is_pure := definition.id in IdentityIds.pure_evolution_ids()
	if is_pure:
		if definition.branch_kind not in [EvolutionDefinition.BRANCH_2_1, EvolutionDefinition.BRANCH_2_2] or not definition.affinity_class_id.is_empty():
			return false
	else:
		if definition.branch_kind != EvolutionDefinition.BRANCH_2_3:
			return false
		if not IdentityIds.is_base_class(definition.affinity_class_id) or definition.affinity_class_id == definition.origin_class_id:
			return false
	var seen_skills: Dictionary[StringName, bool] = {}
	for skill_id: StringName in definition.exclusive_skill_ids:
		if not IdentityIds.is_technical_id(String(skill_id)) or seen_skills.has(skill_id):
			return false
		seen_skills[skill_id] = true
		if not _evolution_skill_reference_is_valid(skill_id, definition):
			return false
	if not definition.entry_skill_id.is_empty():
		if definition.entry_skill_id not in definition.exclusive_skill_ids:
			return false
		if not _entry_skill_is_valid(definition.entry_skill_id, definition):
			return false
	if not definition.content_ready:
		return true
	if definition.entry_skill_id.is_empty() or definition.exclusive_skill_ids.is_empty():
		return false
	var declared_skills: Dictionary[StringName, bool] = {}
	for skill_id: StringName in definition.exclusive_skill_ids:
		declared_skills[skill_id] = true
	var catalog_skills: Dictionary[StringName, bool] = {}
	var free_skill_ids: Array[StringName] = []
	for skill_id: StringName in _skills:
		var metadata: Dictionary = _skills[skill_id]
		if metadata["required_evolution_id"] != definition.id:
			continue
		catalog_skills[skill_id] = true
		if int(metadata["free_rank"]) > 0:
			free_skill_ids.append(skill_id)
	return declared_skills == catalog_skills and free_skill_ids == [definition.entry_skill_id]

func _evolution_skill_reference_is_valid(skill_id: StringName, definition: EvolutionDefinition) -> bool:
	var metadata: Dictionary = _skills.get(skill_id, {})
	if metadata.is_empty() or metadata["wallet"] != EVOLUTION_WALLET:
		return false
	if metadata["required_evolution_id"] != definition.id:
		return false
	var origins: Array = metadata["allowed_base_classes"]
	return origins.size() == 1 and origins[0] == definition.origin_class_id

func _entry_skill_is_valid(skill_id: StringName, definition: EvolutionDefinition) -> bool:
	if not _evolution_skill_reference_is_valid(skill_id, definition):
		return false
	var metadata: Dictionary = _skills[skill_id]
	if metadata["category"] != ACTIVE or int(metadata["free_rank"]) != 1 or int(metadata["max_purchased_rank"]) != 4:
		return false
	var requirement: Dictionary = metadata["rank_requirements"].get(1, {})
	return int(requirement.get("job_level", -1)) == definition.required_job_level and requirement.get("skill_ranks", {}) == {}

func _valid_origins(value: Variant) -> bool:
	if not value is Array or value.is_empty():
		return false
	for base_class_id: Variant in value:
		if not base_class_id is StringName or not IdentityIds.is_base_class(base_class_id):
			return false
	return true

func _evolution_matches_any_origin(evolution_id: StringName, origins: Array) -> bool:
	for base_class_id: StringName in origins:
		if IdentityIds.evolution_belongs_to(evolution_id, base_class_id):
			return true
	return false

func _base_skill_counts(base_class_id: StringName) -> Dictionary[StringName, int]:
	var counts: Dictionary[StringName, int] = {ACTIVE: 0, PASSIVE: 0}
	for metadata: Dictionary in _skills.values():
		if metadata["wallet"] == BASE_WALLET and StringName(metadata["required_evolution_id"]).is_empty() and base_class_id in metadata["allowed_base_classes"]:
			counts[metadata["category"]] += 1
	return counts

func _validated_rank_requirements(total_rank: int, wallet: StringName, provided: Dictionary) -> Dictionary:
	if total_rank < 1:
		return {"ok": false}
	var declarations: Dictionary[int, Dictionary] = {}
	for raw_rank: Variant in provided:
		var rank := _rank_key(raw_rank)
		if rank < 1 or rank > total_rank or declarations.has(rank):
			return {"ok": false}
		var raw_requirement: Variant = provided[raw_rank]
		if not raw_requirement is Dictionary:
			return {"ok": false}
		var fields: Dictionary[String, Variant] = {}
		for raw_field: Variant in raw_requirement:
			if not (raw_field is String or raw_field is StringName):
				return {"ok": false}
			var field := String(raw_field)
			if field not in ["job_level", "skill_ranks"] or fields.has(field):
				return {"ok": false}
			fields[field] = raw_requirement[raw_field]
		var default_job_level: int = ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL if wallet == EVOLUTION_WALLET else 1
		var job_level: Variant = fields.get("job_level", default_job_level)
		var skill_ranks: Variant = fields.get("skill_ranks", {})
		if not job_level is int or int(job_level) < 1 or int(job_level) > ProgressionRules.MAX_JOB_LEVEL:
			return {"ok": false}
		if not skill_ranks is Dictionary:
			return {"ok": false}
		declarations[rank] = {
			"job_level": int(job_level),
			"skill_ranks": skill_ranks.duplicate(true),
		}

	var normalized: Dictionary = {}
	for rank: int in range(1, total_rank + 1):
		var default_job_level: int = ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL if wallet == EVOLUTION_WALLET else 1
		normalized[rank] = declarations.get(rank, {
			"job_level": default_job_level,
			"skill_ranks": {},
		}).duplicate(true)
	return {"ok": true, "requirements": normalized}

func _rank_key(raw_rank: Variant) -> int:
	if raw_rank is int:
		return int(raw_rank)
	if not (raw_rank is String or raw_rank is StringName):
		return -1
	var text := String(raw_rank)
	if text.is_empty():
		return -1
	var parsed := text.to_int()
	return parsed if text == str(parsed) else -1

func _rank_requirements_are_valid(skill_id: StringName, metadata: Dictionary) -> bool:
	var total_rank := int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
	if total_rank < 1:
		return false
	var requirements: Variant = metadata.get("rank_requirements")
	if not requirements is Dictionary or requirements.size() != total_rank:
		return false
	for rank: int in range(1, total_rank + 1):
		if not requirements.has(rank) or not requirements[rank] is Dictionary:
			return false
		var requirement: Dictionary = requirements[rank]
		if requirement.size() != 2 or not requirement.has("job_level") or not requirement.has("skill_ranks"):
			return false
		if not requirement["job_level"] is int or int(requirement["job_level"]) < 1 or int(requirement["job_level"]) > ProgressionRules.MAX_JOB_LEVEL:
			return false
		if not requirement["skill_ranks"] is Dictionary:
			return false
		if rank <= int(metadata["free_rank"]):
			var free_job_cap := ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL if metadata["wallet"] == EVOLUTION_WALLET else 1
			if int(requirement["job_level"]) > free_job_cap:
				return false
		for raw_prerequisite_id: Variant in requirement["skill_ranks"]:
			if not (raw_prerequisite_id is String or raw_prerequisite_id is StringName):
				return false
			var prerequisite_id := StringName(raw_prerequisite_id)
			if prerequisite_id == skill_id or not _skills.has(prerequisite_id):
				return false
			var prerequisite_rank: Variant = requirement["skill_ranks"][raw_prerequisite_id]
			if not prerequisite_rank is int or int(prerequisite_rank) < 1:
				return false
			var prerequisite: Dictionary = _skills[prerequisite_id]
			if int(prerequisite_rank) > int(prerequisite["free_rank"]) + int(prerequisite["max_purchased_rank"]):
				return false
			if rank <= int(metadata["free_rank"]) and int(prerequisite_rank) > int(prerequisite["free_rank"]):
				return false
			if metadata["wallet"] == BASE_WALLET and prerequisite["wallet"] != BASE_WALLET:
				return false
			if prerequisite["wallet"] == EVOLUTION_WALLET and prerequisite["required_evolution_id"] != metadata["required_evolution_id"]:
				return false
			for origin: StringName in metadata["allowed_base_classes"]:
				if origin not in prerequisite["allowed_base_classes"]:
					return false
	return true

func _has_requirement_cycle() -> bool:
	var visiting: Dictionary[StringName, bool] = {}
	var visited: Dictionary[StringName, bool] = {}
	for skill_id: StringName in _skills:
		if _requirement_cycle_from(skill_id, visiting, visited):
			return true
	return false

func _requirement_cycle_from(skill_id: StringName, visiting: Dictionary[StringName, bool], visited: Dictionary[StringName, bool]) -> bool:
	if visiting.has(skill_id):
		return true
	if visited.has(skill_id):
		return false
	visiting[skill_id] = true
	var metadata: Dictionary = _skills[skill_id]
	for requirement: Dictionary in metadata["rank_requirements"].values():
		for raw_prerequisite_id: Variant in requirement["skill_ranks"]:
			if _requirement_cycle_from(StringName(raw_prerequisite_id), visiting, visited):
				return true
	visiting.erase(skill_id)
	visited[skill_id] = true
	return false
