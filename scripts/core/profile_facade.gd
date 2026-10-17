class_name ProfileFacade
extends RefCounted
## Transactional profile operations. Runtime combat receives only copied run state.

const MAX_REQUEST_ID_LENGTH := 64

var _store: ProfileStore
var _catalog: ProfileCatalog
var _reward_resolver: ProfileRewardResolver
var _profile: ProfileState = null
var _operation_in_progress := false
var _active_request_id := ""
var _uncertain_transaction: Dictionary = {}
var _read_only := false
var _read_only_error_code: StringName = &""

func _init(store: ProfileStore = null, reward_resolver: ProfileRewardResolver = null) -> void:
	_store = store if store != null else ProfileStore.new()
	_catalog = _store.catalog_copy()
	_reward_resolver = reward_resolver.copy_resolver() if reward_resolver != null else ProfileRewardResolver.new()

func open_profile() -> Dictionary:
	if not _uncertain_transaction.is_empty():
		return {"ok": false, "error_code": &"result_uncertain", "read_only": true}
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress"}
	_operation_in_progress = true
	var result := _open_profile_transaction()
	_operation_in_progress = false
	return _public_result(result)

func current_profile() -> ProfileState:
	return _profile.copy_state() if _profile != null else null

func create_character(request_id: String, expected_revision: int, display_name: String, base_class_id: StringName) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	if _profile.characters.size() >= ProfileState.MAX_CHARACTERS:
		return _finish_operation(request_id, {"ok": false, "error_code": &"character_limit"})
	if not _catalog.base_class_is_available(base_class_id):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_origin"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var character_id := IdentityIds.character_id(candidate.profile_id, candidate.next_character_counter)
	var character := CharacterState.new(character_id, display_name, base_class_id)
	character.action_slots = ActionBarLayout.empty()
	var initial_slots := _catalog.initial_skill_slots(base_class_id)
	var starter_equipment := EquipmentRules.empty_layout()
	for slot: StringName in IdentityIds.equipment_slots():
		var definition_id: Variant = _catalog.starter_equipment(base_class_id)[slot]
		if definition_id == null:
			continue
		var instance_id := candidate.first_instance_for_definition(definition_id)
		if instance_id.is_empty():
			var created_instance := candidate.add_equipment_instance(definition_id, _catalog.equipment_metadata(definition_id))
			if not created_instance["ok"]:
				return _finish_operation(request_id, created_instance)
			instance_id = created_instance["instance_id"]
			candidate.lifetime_stats[&"equipment_unlocked"] += 1
		starter_equipment[slot] = instance_id
	character.equipped = starter_equipment.duplicate(true)
	for preset: Dictionary in character.presets:
		preset["active_slots"] = initial_slots["active_slots"].duplicate(true)
		preset["passive_slots"] = initial_slots["passive_slots"].duplicate(true)
		preset["equipped"] = starter_equipment.duplicate(true)
	candidate.characters.append(character)
	candidate.selected_character_id = character_id
	candidate.next_character_counter += 1

	var committed := _resolve_commit(before, candidate, _commit_candidate(candidate, character_id))
	if committed["ok"]:
		committed["character_id"] = character_id
	return _finish_operation(request_id, committed)

func select_character(request_id: String, expected_revision: int, character_id: String) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	if _profile.character_by_id(character_id) == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if _profile.selected_character_id == character_id:
		return _finish_operation(request_id, {
			"ok": true,
			"already_applied": true,
			"new_revision": _profile.revision,
			"profile": _profile,
			"selected_character_id": character_id,
		})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	candidate.selected_character_id = character_id
	var committed := _resolve_commit(before, candidate, _commit_candidate(candidate, character_id))
	if committed["ok"]:
		committed["selected_character_id"] = character_id
	return _finish_operation(request_id, committed)

func select_preset(request_id: String, expected_revision: int, character_id: String, preset_index: int) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	var character := _profile.character_by_id(character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if preset_index < 0 or preset_index >= CharacterState.PRESET_COUNT:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_presets"})
	if character.selected_preset == preset_index:
		return _finish_operation(request_id, {
			"ok": true,
			"already_applied": true,
			"new_revision": _profile.revision,
			"profile": _profile,
			"character_id": character_id,
			"selected_preset": preset_index,
		})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var candidate_character := candidate.character_by_id(character_id)
	candidate_character.selected_preset = preset_index
	candidate_character.equipped = candidate_character.presets[preset_index]["equipped"].duplicate(true)
	var committed := _resolve_commit(before, candidate, _commit_candidate(candidate, character_id))
	if committed["ok"]:
		committed["character_id"] = character_id
		committed["selected_preset"] = preset_index
	return _finish_operation(request_id, committed)

func available_build_options(character_id: String) -> Dictionary:
	var character := _profile.character_by_id(character_id) if _profile != null else null
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	# Editor and combat share legal learned availability, including job gates.
	var snapshot := _build_snapshot(character)
	var active_skills := snapshot.learned_skill_ids(ProfileCatalog.ACTIVE)
	var composed := _permanent_effect_preview(character)
	if not composed.get("ok", false): return composed
	for id: StringName in composed.get("item_grants", {}):
		if id not in active_skills: active_skills.append(id)
	var passive_skills := snapshot.learned_skill_ids(ProfileCatalog.PASSIVE)
	var equipment_by_slot: Dictionary[StringName, Array] = {}
	for slot: StringName in IdentityIds.equipment_slots():
		equipment_by_slot[slot] = []
	for instance_id: StringName in _profile.equipment_instance_ids():
		var item_id := _profile.equipment_instances[instance_id].definition_id
		for slot: StringName in IdentityIds.equipment_slots():
			if _catalog.equipment_is_allowed(item_id, slot, character.base_class_id, character.evolution_id):
				equipment_by_slot[slot].append(instance_id)
	return {
		"ok": true,
		"character_id": character_id,
		"active_skills": active_skills,
		"effective_cast_ranks": composed["skill_ranks"].duplicate(true),
		"passive_skills": passive_skills,
		"equipment_by_slot": equipment_by_slot,
	}

func update_preset(
	request_id: String,
	expected_revision: int,
	character_id: String,
	preset_index: int,
	active_slots: Array[Variant],
	passive_slots: Array[Variant],
	equipped: Dictionary[StringName, Variant]
) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	var character := _profile.character_by_id(character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if preset_index < 0 or preset_index >= CharacterState.PRESET_COUNT:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_presets"})
	if active_slots.size() != CharacterState.ACTIVE_SLOT_COUNT or passive_slots.size() != CharacterState.PASSIVE_SLOT_COUNT:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_presets"})
	if equipped.size() != IdentityIds.equipment_slots().size():
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_equipment"})
	# Existing disabled references may be retained or moved; a new unlearned
	# assignment is still rejected before any candidate can be published.
	var permanent := CharacterProgression.effective_skill_ranks(character, _catalog)
	for key: String in ["active_slots", "passive_slots"]:
		var retained: Array = []
		for preset: Dictionary in character.presets: retained.append_array(preset[key])
		var proposed: Array = active_slots if key == "active_slots" else passive_slots
		for value: Variant in proposed:
			if value == null: continue
			var id := ActionBarLayout.skill_id(value)
			if int(permanent.get(id,0)) <= 0 and value not in retained:
				return _finish_operation(request_id, {"ok": false, "error_code": &"requirements_unmet"})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var candidate_character := candidate.character_by_id(character_id)
	var candidate_preset: Dictionary = candidate_character.presets[preset_index]
	candidate_preset["active_slots"] = active_slots.duplicate(true)
	candidate_preset["passive_slots"] = passive_slots.duplicate(true)
	candidate_preset["equipped"] = equipped.duplicate(true)
	candidate_character.selected_preset = preset_index
	candidate_character.equipped = equipped.duplicate(true)
	var committed := _resolve_commit(before, candidate, _commit_candidate(candidate, character_id))
	if committed["ok"]:
		committed["character_id"] = character_id
		committed["selected_preset"] = preset_index
	return _finish_operation(request_id, committed)

func run_mutation_status(run_id: String, character_id: String) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress"}
	if _read_only or not _uncertain_transaction.is_empty() or _store.has_pending_transaction():
		return {"ok": false, "error_code": &"result_uncertain" if _read_only else &"recovery_required"}
	if _profile == null or _profile.reward_session == null:
		return {"ok": false, "error_code": &"invalid_session"}
	if _profile.reward_session["run_id"] != run_id or _profile.reward_session["character_id"] != character_id or _profile.selected_character_id != character_id:
		return {"ok": false, "error_code": &"invalid_session"}
	return {"ok": true}

func equip_between_encounters(request_id: String, expected_revision: int, controller: RunController, intent: Dictionary) -> Dictionary:
	if controller == null or controller.persistent_facade != self or controller.build_service == null or request_id != intent.get("request_id") or not intent.has("resource_state") or not controller.build_service._busy or controller.build_service._committing_intent != intent:
		return {"ok": false, "error_code": &"invalid_session", "request_id": request_id}
	var prepared := controller.build_service._prepare(intent)
	if not prepared["ok"]:
		return prepared
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var character := candidate.character_by_id(controller.run_state.character_id)
	candidate.card_inventory = prepared["inventory"].copy_inventory()
	var equipped: Dictionary = prepared["snapshot"].equipped
	character.equipped.assign(equipped)
	character.presets[character.selected_preset]["equipped"] = equipped.duplicate(true)
	return _finish_operation(request_id, _resolve_commit(before, candidate, _commit_candidate(candidate, character.character_id), true))

func update_action_slots(request_id: String, expected_revision: int, character_id: String, slots: Array[Variant]) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var character := _profile.character_by_id(character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if not _catalog.build_is_ready(character):
		return _finish_operation(request_id, {"ok": false, "error_code": &"content_unavailable"})
	var snapshot := _build_snapshot(character)
	if not ActionBarLayout.valid_preserving(slots, snapshot.learned_skill_ids(ProfileCatalog.ACTIVE), ActionBarLayout.for_character(character), ItemSkillAdapters.reference_ids(character.base_class_id)):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_action_slots"})
	# Unlike build edits this is legal during a run: only shortcut organization.
	if _profile.reward_session != null and _profile.reward_session.character_id != character_id:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	candidate.character_by_id(character_id).action_slots = slots.duplicate(true)
	return _finish_operation(request_id, _resolve_commit(before, candidate, _store.commit(candidate)))

func progression_summary(character_id: String) -> Dictionary:
	if _profile == null:
		var opened := open_profile()
		if not opened["ok"]:
			return opened
	var character := _profile.character_by_id(character_id)
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	var result := CharacterProgression.summary(character, _catalog)
	result["character_id"] = character_id
	result["migration_report"] = _profile.extension_fields.get("all_skill_dependencies_migration", _profile.extension_fields.get("swordsman_skill_tree_migration", {})).duplicate(true)
	return result.duplicate(true)

func evolution_options(character_id: String) -> Dictionary:
	return _evolution_options(character_id, false)

func playtest_evolution_options(character_id: String) -> Dictionary:
	return _evolution_options(character_id, true)

func _evolution_options(character_id: String, allow_switch: bool) -> Dictionary:
	# Unlike the older queries, this contract never opens or repairs a profile as
	# a side effect. The caller must establish the facade state explicitly.
	if _profile == null:
		return {"ok": false, "error_code": &"profile_unavailable"}
	var character := _profile.character_by_id(character_id)
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	var base_level := ProgressionRules.base_level_for_xp(character.base_xp_total)
	var job_level := ProgressionRules.job_level_for_xp(character.job_xp_total, not character.evolution_id.is_empty())
	var run_active := _profile.reward_session != null
	var options: Array[Dictionary] = []
	for definition: EvolutionDefinition in _catalog.evolution_definitions_for_origin(character.base_class_id):
		var requirements_met := base_level >= definition.required_base_level and job_level >= definition.required_job_level
		var is_current := character.evolution_id == definition.id
		var blocking_reasons: Array[StringName] = []
		if not requirements_met:
			blocking_reasons.append(&"requirements_unmet")
		if not definition.content_ready:
			blocking_reasons.append(&"content_unavailable")
		if run_active:
			blocking_reasons.append(&"run_active")
		if _read_only:
			blocking_reasons.append(&"profile_read_only")
		if is_current:
			blocking_reasons.append(&"already_current")
		if not allow_switch and not character.evolution_id.is_empty() and not is_current:
			blocking_reasons.append(&"evolution_locked")
		options.append({
			"evolution_id": definition.id,
			"display_name": definition.display_name,
			"origin_class_id": definition.origin_class_id,
			"branch_kind": definition.branch_kind,
			"affinity_class_id": definition.affinity_class_id,
			"required_base_level": definition.required_base_level,
			"required_job_level": definition.required_job_level,
			"entry_skill_id": definition.entry_skill_id,
			"exclusive_skill_ids": definition.exclusive_skill_ids.duplicate(),
			"is_current": is_current,
			"requirements_met": requirements_met,
			"content_ready": definition.content_ready,
			"can_select": blocking_reasons.is_empty(),
			"blocking_reasons": blocking_reasons.duplicate(),
		})
	return {
		"ok": true,
		"character_id": character_id,
		"base_class_id": character.base_class_id,
		"current_evolution_id": character.evolution_id,
		"base_level": base_level,
		"job_level": job_level,
		"run_active": run_active,
		"profile_read_only": _read_only,
		"profile_revision": _profile.revision,
		"options": options,
	}

func progression_skill_options(character_id: String) -> Dictionary:
	if _profile == null:
		var opened := open_profile()
		if not opened["ok"]:
			return opened
	var character := _profile.character_by_id(character_id)
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	return _progression_skill_options_for(character)

func _progression_skill_options_for(character: CharacterState) -> Dictionary:
	var progression := CharacterProgression.summary(character, _catalog)
	var effective_ranks: Dictionary[StringName, int] = progression["effective_skill_ranks"]
	var skill_ids: Array[StringName] = []
	for raw_skill_id: Variant in _catalog._skills:
		var skill_id := StringName(raw_skill_id)
		var metadata := _catalog.skill_metadata(skill_id)
		if character.base_class_id in metadata["allowed_base_classes"]:
			skill_ids.append(skill_id)
	skill_ids.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
	var skills: Array[Dictionary] = []
	for skill_id: StringName in skill_ids:
		var metadata := _catalog.skill_metadata(skill_id)
		var rank: int = effective_ranks.get(skill_id, 0)
		var purchased_rank: int = character.purchased_skill_ranks.get(skill_id, 0)
		var maximum_rank: int = int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
		var available := _catalog.skill_is_allowed(skill_id, character.base_class_id, character.evolution_id)
		var next_rank := rank + 1
		var next_result: Dictionary = {"ok": false, "error_code": &"rank_cap_reached"}
		var next_requirement: Dictionary = {}
		if next_rank <= maximum_rank:
			next_requirement = metadata["rank_requirements"][next_rank].duplicate(true)
			var wallet_key: StringName = &"base_skill_points_available" if metadata["wallet"] == ProfileCatalog.BASE_WALLET else &"evolution_skill_points_available"
			if not available:
				next_result = {"ok": false, "error_code": &"requirements_unmet"}
			elif int(progression[wallet_key]) <= 0:
				next_result = {"ok": false, "error_code": &"insufficient_points"}
			else:
				next_result = _catalog.check_rank_requirements(skill_id, next_rank, int(progression["job_level"]), effective_ranks)
		skills.append({
			"skill_id": skill_id,
			"metadata": metadata,
			"rank": rank,
			"purchased_rank": purchased_rank,
			"maximum_rank": maximum_rank,
			"available": available,
			"next_rank": next_rank if next_rank <= maximum_rank else null,
			"next_rank_requirement": next_requirement,
			"next_rank_available": next_result["ok"],
			"next_rank_error_code": next_result.get("error_code", &""),
		})
	return {
		"ok": true,
		"character_id": character.character_id,
		"skills": skills,
	}

## Read-only draft, without opening or repairing the profile.
func skill_allocation_preview(character_id: String, expected_revision: int, ordered_skill_ids: Array) -> Dictionary:
	if _profile == null:
		return {"ok": false, "error_code": &"profile_unavailable"}
	if expected_revision != _profile.revision:
		return {"ok": false, "error_code": &"stale_revision", "current_revision": _profile.revision}
	var character := _profile.character_by_id(character_id)
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	var candidate := character.copy_state()
	var simulation := _apply_skill_sequence(candidate, ordered_skill_ids)
	if not simulation["ok"]:
		return simulation
	var options := _progression_skill_options_for(candidate)
	var composed := _permanent_effect_preview(candidate)
	if not composed.get("ok", false): return composed
	var represented: Array[StringName] = []
	for option: Dictionary in options["skills"]:
		var id: StringName = option["skill_id"]
		represented.append(id)
		option["item_rank"] = int(composed.get("item_grants", {}).get(id, 0))
		option["effective_cast_rank"] = int(composed["skill_ranks"].get(id, 0))
	for id: StringName in composed.get("item_grants", {}):
		if id in represented: continue
		var item_rank := int(composed["item_grants"][id])
		var metadata := _catalog.skill_metadata(id)
		metadata["required_evolution_id"] = &"items"
		metadata["wallet"] = &"items"
		options["skills"].append({"skill_id": id, "item_only": true, "metadata": metadata, "rank": 0, "item_rank": item_rank, "effective_cast_rank": int(composed["skill_ranks"].get(id, 0)), "purchased_rank": 0, "maximum_rank": item_rank, "available": true, "next_rank": null, "next_rank_available": false, "next_rank_requirement": {}, "next_rank_error_code": &"item_only"})
	options["effective_cast_ranks"] = composed["skill_ranks"].duplicate(true)
	options["summary"] = CharacterProgression.summary(candidate, _catalog)
	options["original_ranks"] = CharacterProgression.summary(character, _catalog)["effective_skill_ranks"].duplicate(true)
	options["profile_revision"] = _profile.revision
	options["pending_count"] = ordered_skill_ids.size()
	options["can_apply"] = not _read_only and _profile.reward_session == null
	options["run_active"] = _profile.reward_session != null
	options["pending_counts"] = simulation["pending_counts"].duplicate(true)
	return options.duplicate(true)

func _apply_skill_sequence(character: CharacterState, ordered_skill_ids: Array) -> Dictionary:
	if ordered_skill_ids.size() > 512:
		return {"ok": false, "error_code": &"invalid_skill_allocations"}
	var counts: Dictionary = {}
	for index: int in ordered_skill_ids.size():
		var raw: Variant = ordered_skill_ids[index]
		if not (raw is StringName or raw is String):
			return {"ok": false, "error_code": &"invalid_skill_id", "failed_index": index}
		var id := StringName(raw)
		var result := CharacterProgression.learn_skill(character, _catalog, id)
		if not result["ok"]:
			result["failed_index"] = index
			result["skill_id"] = id
			return result
		counts[id] = int(counts.get(id, 0)) + 1
	return {"ok": true, "pending_counts": counts, "spent": ordered_skill_ids.size()}

func apply_skill_allocations(request_id: String, expected_revision: int, character_id: String, ordered_skill_ids: Array) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var boundary := _progression_boundary(character_id)
	if not boundary["ok"]:
		return _finish_operation(request_id, boundary)
	if ordered_skill_ids.is_empty():
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_skill_allocations"})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var mutation := _apply_skill_sequence(candidate.character_by_id(character_id), ordered_skill_ids)
	return _finish_progression_mutation(request_id, before, candidate, character_id, mutation, true)

func build_preview(character_id: String, modifier_sources: Array[Dictionary] = []) -> Dictionary:
	if _profile == null:
		var opened := open_profile()
		if not opened["ok"]:
			return opened
	var character := _profile.character_by_id(character_id)
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	var snapshot := _build_snapshot(character)
	var loaded := BuildContentLoader.load_catalog_for_profile(_catalog)
	if not loaded["ok"]: return loaded
	var stats_result := BuildEffectComposer.compose(snapshot,{},modifier_sources,loaded["catalog"])
	if not stats_result["ok"]:
		return stats_result
	return {
		"ok": true,
		"character_id": character_id,
		"snapshot": snapshot,
		"stat_breakdown": stats_result["breakdown"],
	}

func attribute_purchase_preview(character_id: String, attribute_id: StringName, amount: int = 1, modifier_sources: Array[Dictionary] = []) -> Dictionary:
	# Strictly read-only: no open/repair/migration or revision/selection change.
	if _profile == null:
		return {"ok": false, "error_code": &"profile_unavailable"}
	var character := _profile.character_by_id(character_id)
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	if attribute_id not in IdentityIds.attribute_ids() or amount <= 0:
		return {"ok": false, "error_code": &"invalid_attribute_allocations"}
	var snapshot := _build_snapshot(character)
	var loaded := BuildContentLoader.load_catalog_for_profile(_catalog)
	if not loaded["ok"]: return loaded
	var before_result := BuildEffectComposer.compose(snapshot,{},modifier_sources,loaded["catalog"])
	if not before_result["ok"]:
		return before_result
	var before: StatBreakdown = before_result["breakdown"]
	var initial := IdentityIds.initial_attributes(character.base_class_id)
	var permanent := int(initial[attribute_id]) + character.attribute_allocations[attribute_id]
	var cost := ProgressionRules.attribute_increment_cost(permanent, amount)
	var available := ProgressionRules.attribute_points_available(character.base_xp_total, character.attribute_allocations, character.base_class_id)
	var result := {
		"ok": true, "attribute_id": attribute_id, "amount": amount,
		"permanent": permanent, "effective": before.primary_value(attribute_id),
		"cost": cost, "available": available, "can_purchase": false,
		"blocking_reason": &"", "before": before, "after": null,
		"next_milestones": StatCalculator.next_attribute_milestones(attribute_id, before.primary_value(attribute_id)),
		"derived_changes": [],
	}
	if cost < 0:
		result["blocking_reason"] = &"attribute_cap_reached"
		return result
	# Use a copied build to recalculate allocation-dependent passives as well.
	var candidate := character.copy_state()
	candidate.attribute_allocations[attribute_id] += amount
	var after_result := BuildEffectComposer.compose(_build_snapshot(candidate),{},modifier_sources,loaded["catalog"])
	if not after_result["ok"]:
		return after_result
	var after: StatBreakdown = after_result["breakdown"]
	result["after"] = after
	var changes: Array[Dictionary] = []
	for stat_id: StringName in StatCalculator.DERIVED_IDS:
		if not is_equal_approx(before.value(stat_id), after.value(stat_id)):
			changes.append({"stat_id": stat_id, "before": before.value(stat_id), "after": after.value(stat_id)})
	result["derived_changes"] = changes
	if _read_only:
		result["blocking_reason"] = &"profile_read_only"
	elif _profile.reward_session != null:
		result["blocking_reason"] = &"run_active"
	elif available < cost:
		result["blocking_reason"] = &"insufficient_points"
	else:
		result["can_purchase"] = true
	return result

func allocate_attributes(request_id: String, expected_revision: int, character_id: String, increments: Dictionary) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var boundary := _progression_boundary(character_id)
	if not boundary["ok"]:
		return _finish_operation(request_id, boundary)
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var mutation := CharacterProgression.allocate_attributes(candidate.character_by_id(character_id), increments)
	return _finish_progression_mutation(request_id, before, candidate, character_id, mutation)

func learn_skill(request_id: String, expected_revision: int, character_id: String, skill_id: StringName) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var boundary := _progression_boundary(character_id)
	if not boundary["ok"]:
		return _finish_operation(request_id, boundary)
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var mutation := CharacterProgression.learn_skill(candidate.character_by_id(character_id), _catalog, skill_id)
	return _finish_progression_mutation(request_id, before, candidate, character_id, mutation)

func respec_attributes(request_id: String, expected_revision: int, character_id: String) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var boundary := _progression_boundary(character_id)
	if not boundary["ok"]:
		return _finish_operation(request_id, boundary)
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var mutation := CharacterProgression.respec_attributes(candidate.character_by_id(character_id))
	return _finish_progression_mutation(request_id, before, candidate, character_id, mutation)

func respec_skills(request_id: String, expected_revision: int, character_id: String) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var boundary := _progression_boundary(character_id)
	if not boundary["ok"]:
		return _finish_operation(request_id, boundary)
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var mutation := CharacterProgression.respec_skills(candidate.character_by_id(character_id), _catalog)
	return _finish_progression_mutation(request_id, before, candidate, character_id, mutation)

func change_evolution(request_id: String, expected_revision: int, character_id: String, evolution_id: StringName) -> Dictionary:
	return _change_evolution(request_id, expected_revision, character_id, evolution_id, false)

func change_playtest_evolution(request_id: String, expected_revision: int, character_id: String, evolution_id: StringName) -> Dictionary:
	return _change_evolution(request_id, expected_revision, character_id, evolution_id, true)

func _change_evolution(request_id: String, expected_revision: int, character_id: String, evolution_id: StringName, allow_switch: bool) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var boundary := _progression_boundary(character_id)
	if not boundary["ok"]:
		return _finish_operation(request_id, boundary)
	var current: CharacterState = _profile.character_by_id(character_id)
	if not allow_switch and not current.evolution_id.is_empty() and current.evolution_id != evolution_id:
		return _finish_operation(request_id, {"ok": false, "error_code": &"evolution_locked"})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var mutation := CharacterProgression.change_evolution(candidate.character_by_id(character_id), _catalog, evolution_id)
	return _finish_progression_mutation(request_id, before, candidate, character_id, mutation)

## Training copies the saved build but never creates a reward session or writes a profile.
func prepare_playtest_training(character_id: String) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress"}
	if _profile == null:
		return {"ok": false, "error_code": &"profile_unavailable"}
	if _read_only or _store.has_pending_transaction():
		return {"ok": false, "error_code": &"recovery_required"}
	if _profile.reward_session != null:
		return {"ok": false, "error_code": &"run_active"}
	var character := _profile.character_by_id(character_id)
	if character == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	if not character.evolution_id.is_empty() and not _catalog.evolution_is_ready(character.evolution_id, character.base_class_id):
		return {"ok": false, "error_code": &"content_unavailable"}
	if not _catalog.build_is_ready(character):
		return {"ok": false, "error_code": &"invalid_loadout"}
	return {"ok": true, "run_state": RunState.from_build("", _build_snapshot(character))}

## Menu-only playtest shortcut. XP remains ordinary persisted progression; no ranks,
## allocations, evolution, or catalog availability are changed here.
func grant_playtest_progression(request_id: String, expected_revision: int, character_id: String, action: StringName, amount: int = 0) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	var boundary := _progression_boundary(character_id)
	if not boundary["ok"]:
		return _finish_operation(request_id, boundary)
	if (action == &"base_xp" or action == &"job_xp") and amount <= 0:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_playtest_amount"})
	if action not in [&"base_xp", &"job_xp", &"prepare_evolution", &"max_levels"]:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_playtest_action"})
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var character: CharacterState = candidate.character_by_id(character_id)
	var evolved := not character.evolution_id.is_empty()
	match action:
		&"base_xp":
			character.base_xp_total = ProgressionRules.add_base_xp(character.base_xp_total, mini(amount, ProgressionRules.MAX_BASE_XP))
		&"job_xp":
			character.job_xp_total = ProgressionRules.add_job_xp(character.job_xp_total, mini(amount, ProgressionRules.MAX_JOB_XP), evolved)
		&"prepare_evolution":
			character.base_xp_total = maxi(character.base_xp_total, ProgressionRules.EVOLUTION_MIN_BASE_XP)
			character.job_xp_total = maxi(character.job_xp_total, ProgressionRules.EVOLUTION_MIN_JOB_XP)
		&"max_levels":
			character.base_xp_total = ProgressionRules.MAX_BASE_XP
			character.job_xp_total = ProgressionRules.MAX_JOB_XP if evolved else ProgressionRules.UNEVOLVED_MAX_JOB_XP
	var unchanged := character.base_xp_total == before.character_by_id(character_id).base_xp_total and character.job_xp_total == before.character_by_id(character_id).job_xp_total
	return _finish_progression_mutation(request_id, before, candidate, character_id, {"ok": true, "already_applied": unchanged, "playtest_action": action})

func start_run(request_id: String, expected_revision: int) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _store.has_pending_transaction():
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true}))
	if not _reward_resolver.is_compatible_with(_catalog):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_catalog"})
	if _profile.reward_session != null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_active"})
	var character := _profile.character_by_id(_profile.selected_character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if not character.evolution_id.is_empty() and not _catalog.evolution_is_ready(character.evolution_id, character.base_class_id):
		return _finish_operation(request_id, {"ok": false, "error_code": &"content_unavailable"})
	if not _catalog.build_is_ready(character):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_loadout"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var run_id := IdentityIds.run_id(candidate.profile_id, candidate.next_run_counter)
	candidate.next_run_counter += 1
	candidate.reward_session = {
		"run_id": run_id,
		"character_id": character.character_id,
		"last_committed_seq": 0,
	}
	candidate.lifetime_stats[&"runs_started"] += 1
	var committed := _resolve_commit(before, candidate, _commit_candidate(candidate, character.character_id))
	if committed["ok"]:
		var committed_character := _profile.character_by_id(character.character_id)
		var snapshot := _build_snapshot(committed_character)
		committed["run_id"] = run_id
		committed["run_state"] = RunState.from_build(run_id, snapshot)
	return _finish_operation(request_id, committed)

func grant_reward(request_id: String, expected_revision: int, run_id: String, sequence: int, reward_id: StringName) -> Dictionary:
	return _grant_reward_payload(request_id, expected_revision, run_id, sequence, reward_id)

func grant_run_ticket(controller: RunController, ticket_id: String) -> Dictionary:
	if controller == null or controller.persistent_facade != self or controller.reward_service == null or controller.encounter_active or controller.run_finished or not controller.player.is_alive():
		return {"ok": false, "error_code": &"invalid_session", "request_id": ticket_id}
	var ticket := controller.reward_service._durable_ticket(ticket_id)
	if ticket.is_empty():
		return {"ok": false, "error_code": &"invalid_reward", "request_id": ticket_id}
	var boundary := run_mutation_status(controller.run_state.run_id, controller.run_state.character_id)
	if not boundary["ok"]:
		return boundary
	return _grant_reward_payload(ticket["request_id"], _profile.revision, controller.run_state.run_id, ticket["sequence"], ticket["reward_id"], ticket["payload"])

func reward_definition(reward_id: StringName) -> Dictionary:
	return _reward_resolver.resolve(reward_id)

func _grant_reward_payload(request_id: String, expected_revision: int, run_id: String, sequence: int, reward_id: StringName, frozen_payload: Dictionary = {}) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_context(request_id)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _store.has_pending_transaction():
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true}))
	if _profile.reward_session == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_inactive"})
	var session: Dictionary = _profile.reward_session
	if run_id != session["run_id"] or sequence < 1:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_reward_sequence"})
	var cursor: int = session["last_committed_seq"]
	if sequence <= cursor:
		return _finish_operation(request_id, {
			"ok": true,
			"already_applied": true,
			"new_revision": _profile.revision,
			"profile": _profile,
			"run_id": run_id,
			"sequence": sequence,
		})
	var revision_result := _check_expected_revision(expected_revision)
	if not revision_result["ok"]:
		return _finish_operation(request_id, revision_result)
	if sequence != cursor + 1:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_reward_sequence"})
	var resolved := _reward_resolver.resolve(reward_id) if frozen_payload.is_empty() else {"ok": true, "reward": frozen_payload.duplicate(true)}
	if not resolved["ok"]:
		return _finish_operation(request_id, resolved)
	var reward: Dictionary = resolved["reward"]
	for item_id: StringName in reward["equipment_ids"]:
		if not _catalog.knows_equipment(item_id):
			return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_catalog"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var candidate_session: Dictionary = candidate.reward_session
	var character := candidate.character_by_id(candidate_session["character_id"])
	if character == null:
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"invalid_reward_session", "read_only": true}))
	character.base_xp_total = ProgressionRules.add_base_xp(character.base_xp_total, reward["base_xp"])
	character.job_xp_total = ProgressionRules.add_job_xp(character.job_xp_total, reward["job_xp"], not character.evolution_id.is_empty())
	var acquired: Array[StringName] = []
	var drops: Array = reward.get("equipment_drops", [])
	if not reward.has("equipment_drops"):
		for definition_id: StringName in reward["equipment_ids"]:
			var metadata := _catalog.equipment_metadata(definition_id)
			metadata["definition_id"] = definition_id
			drops.append(metadata)
	for drop: Dictionary in drops:
		var definition_id := StringName(drop.get("definition_id", &""))
		if not _catalog.knows_equipment(definition_id):
			return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_catalog"})
		var metadata := _catalog.equipment_metadata(definition_id)
		for field: String in ["origin_id", "item_level", "quality_id", "socket_capacity"]:
			metadata[field] = drop.get(field)
		metadata["recipe_revision_id"] = drop.get("recipe_revision_id", &"catalog_v1")
		metadata["power_ruleset_id"] = drop.get("power_ruleset_id", &"legacy_unscaled")
		var was_known := not candidate.first_instance_for_definition(definition_id).is_empty()
		var added := candidate.add_equipment_instance(definition_id, metadata)
		if not added["ok"]:
			return _finish_operation(request_id, added)
		acquired.append(added["instance_id"])
		if not was_known:
			candidate.lifetime_stats[&"equipment_unlocked"] += 1
	var card_id := StringName(reward.get("card_id", &""))
	var acquired_card: StringName = &""
	if not card_id.is_empty():
		var content := BuildContentLoader.load_catalog_for_profile(_catalog)
		if not content["ok"]: return _finish_operation(request_id,content)
		var grant := candidate.card_inventory.grant(card_id,content["catalog"],run_id+":"+request_id)
		if not grant["ok"]: return _finish_operation(request_id,grant)
		acquired_card = grant["card_instance_id"]
	for stat_id: StringName in reward["stat_increments"]:
		candidate.lifetime_stats[stat_id] = candidate.lifetime_stats.get(stat_id, 0) + reward["stat_increments"][stat_id]
	candidate_session["last_committed_seq"] = sequence
	candidate.reward_session = candidate_session
	var committed := _resolve_commit(before, candidate, _store.commit(candidate), not frozen_payload.is_empty())
	if committed["ok"]:
		committed["run_id"] = run_id
		committed["sequence"] = sequence
		committed["reward_id"] = reward_id
		committed["applied_reward"] = reward.duplicate(true)
		committed["equipment_instance_ids"] = acquired.duplicate()
		committed["card_instance_id"] = acquired_card
	return _finish_operation(request_id, committed)

func end_run(request_id: String, expected_revision: int, run_id: String, outcome: StringName) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]:
		return _finish_operation(request_id, ready)
	if _store.has_pending_transaction():
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true}))
	if _profile.reward_session == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"run_inactive"})
	var session: Dictionary = _profile.reward_session
	if run_id != session["run_id"]:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_reward_sequence"})
	if outcome not in [&"completed", &"death", &"abandoned"]:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_run_outcome"})

	var before := _profile.copy_state()
	var candidate := before.copy_state()
	candidate.reward_session = null
	if outcome == &"completed":
		candidate.lifetime_stats[&"runs_completed"] += 1
	elif outcome == &"death":
		candidate.lifetime_stats[&"deaths"] += 1
	var committed := _resolve_commit(before, candidate, _store.commit(candidate))
	if committed["ok"]:
		committed["run_id"] = run_id
		committed["outcome"] = outcome
	return _finish_operation(request_id, committed)

func _begin_operation(request_id: String, expected_revision: int) -> Dictionary:
	var ready := _begin_context(request_id)
	if not ready["ok"]:
		return ready
	return _check_expected_revision(expected_revision)

func _progression_boundary(character_id: String) -> Dictionary:
	if _profile.reward_session != null:
		return {"ok": false, "error_code": &"run_active"}
	if _profile.character_by_id(character_id) == null:
		return {"ok": false, "error_code": &"invalid_character_id"}
	return {"ok": true}

func _finish_progression_mutation(
	request_id: String,
	before: ProfileState,
	candidate: ProfileState,
	character_id: String,
	mutation: Dictionary,
	retain_runtime_transaction: bool = false
) -> Dictionary:
	if not mutation["ok"]:
		return _finish_operation(request_id, mutation)
	if mutation.get("already_applied", false):
		var no_op := mutation.duplicate(true)
		no_op["new_revision"] = _profile.revision
		no_op["profile"] = _profile
		no_op["character_id"] = character_id
		no_op["progression"] = CharacterProgression.summary(_profile.character_by_id(character_id), _catalog)
		return _finish_operation(request_id, no_op)
	var committed := _resolve_commit(before, candidate, _commit_candidate(candidate, character_id), retain_runtime_transaction)
	if committed["ok"]:
		committed["character_id"] = character_id
		committed["progression"] = CharacterProgression.summary(_profile.character_by_id(character_id), _catalog)
		for key: Variant in mutation:
			if key != "ok":
				committed[key] = mutation[key]
	return _finish_operation(request_id, committed)

func _begin_context(request_id: String) -> Dictionary:
	_active_request_id = request_id
	_operation_in_progress = true
	if not _valid_request_id(request_id):
		return {"ok": false, "error_code": &"invalid_request_id"}
	if _read_only:
		return {"ok": false, "error_code": _read_only_error_code, "read_only": true}
	if _profile == null:
		var opened := _open_profile_transaction()
		if not opened["ok"]:
			return opened
	return {"ok": true}

func _check_expected_revision(expected_revision: int) -> Dictionary:
	if expected_revision != _profile.revision:
		return {"ok": false, "error_code": &"stale_revision", "current_revision": _profile.revision}
	return {"ok": true}

func _open_profile_transaction() -> Dictionary:
	var loaded := _store.load_profile()
	if not loaded["ok"]:
		return _block_with(loaded)
	_profile = loaded["profile"].copy_state()
	_clear_read_only()
	if _profile.reward_session == null:
		return loaded
	if _store.has_pending_transaction():
		return _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true})
	var before := _profile.copy_state()
	var abandoned_session: Dictionary = before.reward_session
	var candidate := before.copy_state()
	candidate.reward_session = null
	var closed := _resolve_commit(before, candidate, _store.commit(candidate))
	if not closed["ok"]:
		return _block_with(closed)
	closed["abandoned_run_closed"] = true
	closed["abandoned_run_id"] = abandoned_session["run_id"]
	for metadata_key: String in ["warning", "recovered", "migrated"]:
		if loaded.has(metadata_key):
			closed[metadata_key] = loaded[metadata_key]
	return closed

func _build_snapshot(character: CharacterState, owner_profile: ProfileState = null) -> BuildSnapshot:
	var effective_ranks := CharacterProgression.effective_skill_ranks(character, _catalog)
	var snapshot := BuildSnapshot.from_character(
		character,
		ProgressionRules.base_level_for_xp(character.base_xp_total),
		ProgressionRules.job_level_for_xp(character.job_xp_total, not character.evolution_id.is_empty()),
		effective_ranks,
		_catalog.skill_ids_for_identity(character.base_class_id, character.evolution_id),
		_catalog,
		(owner_profile if owner_profile != null else _profile).equipment_instances
	)
	snapshot.card_inventory = (owner_profile if owner_profile != null else _profile).card_inventory.copy_inventory()
	return snapshot

func _commit_candidate(candidate: ProfileState, character_id: String) -> Dictionary:
	# Validate persistent preferences with the same compositor used by the run,
	# before any disk write. No cards, augments or temporary buffs enter the save.
	var encoded := ProfileCodec.encode(candidate, _catalog)
	if not encoded["ok"]:
		return encoded
	var loaded := BuildContentLoader.load_catalog_for_profile(_catalog)
	if not loaded["ok"]:
		return loaded
	var character := candidate.character_by_id(character_id)
	if character == null:
		return BuildEffectCatalog.failure(&"invalid_character_id")
	# Check only the edited character; unrelated alts cannot prevent a repair.
	# Dormant identities may remain stored; start_run separately rejects them.
	var owners: Array[CharacterState] = []
	if candidate.card_inventory.to_record() != _profile.card_inventory.to_record(): owners.assign(candidate.characters)
	else: owners.append(character)
	for owner: CharacterState in owners:
		if not owner.evolution_id.is_empty() and not _catalog.evolution_is_ready(owner.evolution_id,owner.base_class_id): continue
		for preset_index: int in owner.presets.size():
			var selected := owner.copy_state()
			selected.selected_preset = preset_index
			selected.equipped = selected.presets[preset_index]["equipped"].duplicate(true)
			var composed := BuildEffectComposer.compose(_build_snapshot(selected, candidate), {}, [], loaded["catalog"])
			if not composed["ok"]:
				return composed
	return _store.commit(candidate)

func _resolve_commit(before: ProfileState, candidate: ProfileState, commit_result: Dictionary, retain_runtime_transaction: bool = false) -> Dictionary:
	var result := _reconcile_commit(before, candidate, commit_result)
	if retain_runtime_transaction and not result["ok"] and result.get("read_only", false):
		_uncertain_transaction = {"request_id": _active_request_id, "before": before.copy_state(), "candidate": candidate.copy_state()}
	else:
		_uncertain_transaction = {}
	return result

func reconcile_transaction(request_id: String) -> Dictionary:
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	if _uncertain_transaction.is_empty() or _uncertain_transaction["request_id"] != request_id:
		return {"ok": false, "error_code": &"invalid_transaction", "request_id": request_id}
	_operation_in_progress = true
	var pending := _uncertain_transaction.duplicate()
	var result := _reconcile_commit(pending["before"], pending["candidate"], {"ok": false, "error_code": &"save_failed"})
	if result["ok"] or not result.get("read_only", false):
		_uncertain_transaction = {}
		_clear_read_only()
	return _finish_operation(request_id, result)

func _reconcile_commit(before: ProfileState, candidate: ProfileState, commit_result: Dictionary) -> Dictionary:
	if commit_result["ok"]:
		_profile = commit_result["profile"].copy_state()
		_clear_read_only()
		return commit_result
	if commit_result.get("error_code", &"") == &"stale_revision":
		var refreshed := _refresh_after_stale()
		if not refreshed["ok"]:
			return refreshed
		var stale_result := commit_result.duplicate(true)
		stale_result["current_revision"] = _profile.revision if _profile != null else -1
		return stale_result
	if commit_result.get("error_code", &"") != &"save_failed":
		if commit_result.get("read_only", false):
			return _block_with(commit_result)
		return commit_result

	var loaded := _store.load_profile()
	if loaded["ok"]:
		var durable: ProfileState = loaded["profile"]
		if _matches_committed_candidate(durable, candidate):
			_profile = durable.copy_state()
			_clear_read_only()
			return {
				"ok": true,
				"profile": durable,
				"new_revision": durable.revision,
				"recovered_after_uncertain_result": true,
			}
		if _same_profile(durable, before):
			var cleanup := _store.discard_failed_pending(before, candidate)
			if cleanup["ok"]:
				_profile = durable.copy_state()
				return commit_result
			return _block_with(cleanup)
		if loaded.get("created_empty", false) and before.revision == 0:
			return commit_result
	var cleanup := _store.discard_failed_pending(before, candidate)
	if cleanup["ok"] and cleanup.get("discarded_pending", false):
		_profile = before.copy_state()
		return commit_result
	if not cleanup["ok"]:
		return _block_with(cleanup)
	if not loaded["ok"]:
		return _block_with(loaded)
	return _block_with({"ok": false, "error_code": &"result_uncertain", "read_only": true})

func _refresh_after_stale() -> Dictionary:
	var loaded := _store.load_profile()
	if loaded["ok"]:
		_profile = loaded["profile"].copy_state()
		_clear_read_only()
		return {"ok": true}
	return _block_with(loaded)

func _block_with(result: Dictionary) -> Dictionary:
	_read_only = true
	_read_only_error_code = result.get("error_code", &"result_uncertain")
	var blocked := result.duplicate(true)
	blocked["ok"] = false
	blocked["error_code"] = _read_only_error_code
	blocked["read_only"] = true
	return blocked

func _clear_read_only() -> void:
	_read_only = false
	_read_only_error_code = &""

func _matches_committed_candidate(durable: ProfileState, candidate: ProfileState) -> bool:
	var expected := candidate.copy_state()
	expected.revision += 1
	return _same_profile(durable, expected)

func _same_profile(left: ProfileState, right: ProfileState) -> bool:
	var left_encoded := ProfileCodec.encode(left, _catalog)
	var right_encoded := ProfileCodec.encode(right, _catalog)
	return left_encoded["ok"] and right_encoded["ok"] and left_encoded["text"] == right_encoded["text"]

func _finish_operation(request_id: String, result: Dictionary) -> Dictionary:
	_operation_in_progress = false
	var public_result := _public_result(result)
	public_result["request_id"] = request_id
	return public_result

func _public_result(result: Dictionary) -> Dictionary:
	var public_result: Dictionary = {}
	for key: Variant in result:
		public_result[key] = result[key]
	if public_result.get("profile") is ProfileState:
		public_result["profile"] = public_result["profile"].copy_state()
	return public_result

func _valid_request_id(request_id: String) -> bool:
	if request_id.is_empty() or request_id.length() > MAX_REQUEST_ID_LENGTH:
		return false
	for index: int in request_id.length():
		var codepoint := request_id.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return false
	return true

var _inventory_pending: Dictionary = {}

func preview_inventory_change(character_id: String, intent: Dictionary) -> Dictionary:
	if not _inventory_pending.is_empty() or _operation_in_progress: return BuildEffectCatalog.failure(&"save_in_progress")
	var prepared := _prepare_inventory_change(character_id,intent)
	prepared.erase("candidate")
	return prepared

func commit_inventory_change(character_id: String, intent: Dictionary) -> Dictionary:
	if not _inventory_pending.is_empty():
		if _inventory_pending["character_id"] != character_id or _inventory_pending["intent"] != intent: return BuildEffectCatalog.failure(&"result_uncertain")
		var reconciled := reconcile_transaction(String(intent.get("request_id","")))
		if reconciled["ok"] or not reconciled.get("read_only",false): _inventory_pending.clear()
		return reconciled
	var prepared := _prepare_inventory_change(character_id,intent)
	if not prepared["ok"]: return prepared
	var request_id := String(intent["request_id"])
	var ready := _begin_operation(request_id,int(intent["profile_revision"]))
	if not ready["ok"]: return _finish_operation(request_id,ready)
	var candidate: ProfileState = prepared["candidate"]
	var result := _resolve_commit(_profile.copy_state(),candidate,_commit_candidate(candidate,character_id),true)
	if not result["ok"] and result.get("read_only",false): _inventory_pending = {"character_id":character_id,"intent":intent.duplicate(true)}
	return _finish_operation(request_id,result)

func _prepare_inventory_change(character_id: String, intent: Dictionary) -> Dictionary:
	if _profile == null: return BuildEffectCatalog.failure(&"profile_unavailable")
	if _read_only: return BuildEffectCatalog.failure(&"recovery_required")
	if _profile.reward_session != null: return BuildEffectCatalog.failure(&"run_active")
	if not intent.get("request_id") is String or intent["request_id"].is_empty() or intent["request_id"].length()>MAX_REQUEST_ID_LENGTH: return BuildEffectCatalog.failure(&"invalid_request_id")
	if typeof(intent.get("profile_revision")) != TYPE_INT or intent["profile_revision"] != _profile.revision: return BuildEffectCatalog.failure(&"stale_revision")
	for key: Variant in intent:
		if key not in ["request_id","profile_revision","kind","slot","equipment_instance_id","card_instance_id","socket_index","from_equipment_instance_id","from_socket_index"]: return BuildEffectCatalog.failure(&"invalid_intent")
	for key: String in ["kind","slot","equipment_instance_id","card_instance_id","from_equipment_instance_id"]:
		if intent.has(key) and typeof(intent[key]) not in [TYPE_STRING,TYPE_STRING_NAME]: return BuildEffectCatalog.failure(&"invalid_intent")
	var candidate := _profile.copy_state()
	var character := candidate.character_by_id(character_id)
	if character == null: return BuildEffectCatalog.failure(&"invalid_character_id")
	var kind := StringName(intent.get("kind",&""))
	if kind in [&"equip",&"unequip"]:
		var slot := StringName(intent.get("slot",&"")); var item := StringName(intent.get("equipment_instance_id",&""))
		if slot not in IdentityIds.equipment_slots(): return BuildEffectCatalog.failure(&"invalid_slot")
		if kind == &"equip" and not candidate.equipment_instances.has(item): return BuildEffectCatalog.failure(&"item_not_owned")
		character.equipped[slot] = item if kind == &"equip" else null
		character.presets[character.selected_preset]["equipped"] = character.equipped.duplicate(true)
	var checked := candidate.card_inventory.preview(intent,character.equipped,candidate.equipment_instances,_catalog.all_equipment_metadata())
	if not checked["ok"]: return checked
	candidate.card_inventory = checked["inventory"]
	var loaded := BuildContentLoader.load_catalog_for_profile(_catalog)
	if not loaded["ok"]: return loaded
	var previous := BuildEffectComposer.compose(_build_snapshot(_profile.character_by_id(character_id)),{},[],loaded["catalog"])
	var after := BuildEffectComposer.compose(_build_snapshot(character,candidate),{},[],loaded["catalog"])
	if not previous["ok"]: return previous
	if not after["ok"]: return after
	if character.equipped == _profile.character_by_id(character_id).equipped and candidate.card_inventory.sockets() == _profile.card_inventory.sockets(): return BuildEffectCatalog.failure(&"no_change")
	return {"ok":true,"intent":intent.duplicate(true),"candidate":candidate,"request_id":intent["request_id"],"equipped":character.equipped.duplicate(true),"inventory":candidate.card_inventory.describe(),"before":previous["breakdown"].values(),"after":after["breakdown"].values(),"sources":after["provenance"],"inactive":after["inactive"],"skill_rules":after["skill_rules"],"skill_ranks":after["skill_ranks"],"item_grants":after["item_grants"],"kit_policies":after["kit_policies"],"procs":after["procs"]}

func _permanent_effect_preview(character: CharacterState) -> Dictionary:
	## Pure snapshot/composition; never creates a run, opens a save, or grants a purchase.
	var loaded := BuildContentLoader.load_catalog_for_profile(_catalog)
	if not loaded.get("ok", false): return loaded
	return BuildEffectComposer.compose(_build_snapshot(character), {}, [], loaded["catalog"])

## Transaction boundary for the playtest admin. The public service validates the
## live controller; this method owns dedupe, revision, save and reconciliation.
var _admin_pending: Dictionary = {}
const ADMIN_RECEIPTS_KEY := "playtest_admin_receipts_v1"
const ADMIN_RECEIPT_LIMIT := 128

func grant_playtest_admin(request_id: String, expected_revision: int, character_id: String, action: StringName, definition_id: StringName, options: Dictionary) -> Dictionary:
	if not _admin_pending.is_empty():
		if _admin_pending["request_id"] != request_id or _admin_pending["character_id"] != character_id or _admin_pending["action"] != action or _admin_pending["definition_id"] != definition_id or _admin_pending["options"] != options:
			return {"ok": false, "error_code": &"result_uncertain", "request_id": request_id}
		var reconciled := reconcile_transaction(request_id)
		if reconciled["ok"]:
			reconciled.merge(_admin_pending["result"], true)
		if reconciled["ok"] or not reconciled.get("read_only", false):
			_admin_pending.clear()
		return reconciled
	if _operation_in_progress:
		return {"ok": false, "error_code": &"save_in_progress", "request_id": request_id}
	if _profile == null:
		var opened := open_profile()
		if not opened["ok"]: return opened
	if not _valid_request_id(request_id):
		return {"ok": false, "error_code": &"invalid_request_id", "request_id": request_id}
	var receipts: Array = _profile.extension_fields.get(ADMIN_RECEIPTS_KEY, [])
	for receipt: Dictionary in receipts:
		if receipt["request_id"] != request_id: continue
		if receipt["character_id"] != character_id or receipt["action"] != String(action) or receipt["definition_id"] != String(definition_id) or receipt["options"] != options:
			return {"ok": false, "error_code": &"replayed_request", "request_id": request_id}
		var replay: Dictionary = receipt["result"].duplicate(true)
		replay["ok"] = true
		replay["already_applied"] = true
		replay["new_revision"] = _profile.revision
		replay["profile"] = _profile.copy_state()
		replay["request_id"] = request_id
		return replay
	var ready := _begin_operation(request_id, expected_revision)
	if not ready["ok"]: return _finish_operation(request_id, ready)
	if _store.has_pending_transaction():
		return _finish_operation(request_id, _block_with({"ok": false, "error_code": &"recovery_required", "read_only": true}))
	var before := _profile.copy_state()
	var candidate := before.copy_state()
	var character := candidate.character_by_id(character_id)
	if character == null:
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_character_id"})
	if candidate.reward_session != null and (candidate.reward_session["character_id"] != character_id or candidate.selected_character_id != character_id):
		return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_session"})
	var details: Dictionary = {}
	match action:
		&"equipment":
			if not _catalog.knows_equipment(definition_id):
				return _finish_operation(request_id, {"ok": false, "error_code": &"unknown_definition"})
			var metadata := _catalog.equipment_metadata(definition_id)
			for key: Variant in options:
				if key not in ["item_level", "quality_id", "socket_capacity"]:
					return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_options"})
			if options.has("item_level"):
				if typeof(options["item_level"]) != TYPE_INT or not EquipmentRules.exact_integer(options["item_level"], 1, 30):
					return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_options"})
				metadata["item_level"] = options["item_level"]
			if options.has("quality_id"):
				if typeof(options["quality_id"]) not in [TYPE_STRING, TYPE_STRING_NAME] or StringName(options["quality_id"]) not in EquipmentRules.QUALITY_IDS:
					return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_options"})
				metadata["quality_id"] = StringName(options["quality_id"])
			if options.has("socket_capacity"):
				if typeof(options["socket_capacity"]) != TYPE_INT or not EquipmentRules.exact_integer(options["socket_capacity"], 0, 4):
					return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_options"})
				metadata["socket_capacity"] = options["socket_capacity"]
			metadata["recipe_revision_id"] = EquipmentPowerRules.RECIPE_REVISION
			metadata["power_ruleset_id"] = EquipmentPowerRules.GROWTH_RULESET
			var known := not candidate.first_instance_for_definition(definition_id).is_empty()
			var added := candidate.add_equipment_instance(definition_id, metadata)
			if not added["ok"]: return _finish_operation(request_id, added)
			if not known: candidate.lifetime_stats[&"equipment_unlocked"] += 1
			details["equipment_instance_id"] = String(added["instance_id"])
		&"card":
			if not options.is_empty(): return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_options"})
			var content := BuildContentLoader.load_catalog_for_profile(_catalog)
			if not content["ok"]: return _finish_operation(request_id, content)
			var added := candidate.card_inventory.grant(definition_id, content["catalog"])
			if not added["ok"]: return _finish_operation(request_id, added)
			details["card_instance_id"] = String(added["card_instance_id"])
		&"unlock_skills":
			if not definition_id.is_empty() or not options.is_empty(): return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_options"})
			character.admin_skills_unlocked = true
			details["admin_skills_unlocked"] = true
		&"max_levels":
			if not definition_id.is_empty() or not options.is_empty(): return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_options"})
			character.base_xp_total = ProgressionRules.MAX_BASE_XP
			character.job_xp_total = ProgressionRules.MAX_JOB_XP if not character.evolution_id.is_empty() else ProgressionRules.UNEVOLVED_MAX_JOB_XP
			details["base_level"] = ProgressionRules.base_level_for_xp(character.base_xp_total)
			details["job_level"] = ProgressionRules.job_level_for_xp(character.job_xp_total, not character.evolution_id.is_empty())
		_:
			return _finish_operation(request_id, {"ok": false, "error_code": &"invalid_playtest_action"})
	if action in [&"unlock_skills", &"max_levels"] and ProfileCodec._character_to_dictionary(character) == ProfileCodec._character_to_dictionary(before.character_by_id(character_id)):
		var no_op := {"ok": true, "already_applied": true, "new_revision": before.revision, "profile": before, "character_id": character_id}
		no_op.merge(details)
		return _finish_operation(request_id, no_op)
	var result_record := {"character_id": character_id, "action": String(action), "definition_id": String(definition_id)}
	result_record.merge(details)
	var receipt := {"request_id": request_id, "character_id": character_id, "action": String(action), "definition_id": String(definition_id), "options": options.duplicate(true), "result": result_record}
	var next_receipts: Array = receipts.duplicate(true)
	next_receipts.append(receipt)
	if next_receipts.size() > ADMIN_RECEIPT_LIMIT: next_receipts.pop_front()
	candidate.extension_fields[ADMIN_RECEIPTS_KEY] = next_receipts
	var committed := _resolve_commit(before, candidate, _commit_candidate(candidate, character_id), true)
	if committed["ok"]:
		committed.merge(result_record, true)
		if action in [&"unlock_skills", &"max_levels"]:
			committed["progression"] = CharacterProgression.summary(_profile.character_by_id(character_id), _catalog)
	elif committed.get("read_only", false):
		_admin_pending = {"request_id": request_id, "character_id": character_id, "action": action, "definition_id": definition_id, "options": options.duplicate(true), "result": result_record}
	return _finish_operation(request_id, committed)
