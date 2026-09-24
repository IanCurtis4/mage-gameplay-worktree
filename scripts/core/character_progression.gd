class_name CharacterProgression
extends RefCounted
## Pure E03 progression rules applied to candidate CharacterState copies.
## Persistence and revision ownership remain in ProfileFacade/ProfileStore.

static func summary(character: CharacterState, catalog: ProfileCatalog) -> Dictionary:
	if character == null:
		return _failure(&"invalid_character_id")
	var evolved := not character.evolution_id.is_empty()
	var base_level := ProgressionRules.base_level_for_xp(character.base_xp_total)
	var job_level := ProgressionRules.job_level_for_xp(character.job_xp_total, evolved)
	var base_spent := catalog.skill_points_spent(character.purchased_skill_ranks, ProfileCatalog.BASE_WALLET)
	var evolution_spent := catalog.skill_points_spent(character.purchased_skill_ranks, ProfileCatalog.EVOLUTION_WALLET)
	var base_granted := ProgressionRules.base_skill_points_granted(character.job_xp_total, evolved)
	var evolution_granted := ProgressionRules.evolution_skill_points_granted(character.job_xp_total, evolved)
	return {
		"ok": true,
		"base_level": base_level,
		"job_level": job_level,
		"evolution_eligible": not evolved and base_level >= 10 and job_level >= ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL,
		"job_progress_blocked": not evolved and character.job_xp_total >= ProgressionRules.UNEVOLVED_MAX_JOB_XP,
		"attribute_points_granted": ProgressionRules.attribute_points_granted(character.base_xp_total),
		"attribute_points_spent": ProgressionRules.attribute_points_spent(character.attribute_allocations),
		"attribute_points_available": ProgressionRules.attribute_points_available(character.base_xp_total, character.attribute_allocations),
		"base_skill_points_granted": base_granted,
		"base_skill_points_spent": base_spent,
		"base_skill_points_available": base_granted - base_spent,
		"evolution_skill_points_granted": evolution_granted,
		"evolution_skill_points_spent": evolution_spent,
		"evolution_skill_points_available": evolution_granted - evolution_spent,
		"effective_skill_ranks": catalog.effective_skill_ranks(
			character.base_class_id,
			character.evolution_id,
			character.purchased_skill_ranks,
			character.granted_skill_ranks
		),
	}

static func allocate_attributes(character: CharacterState, increments: Dictionary) -> Dictionary:
	if character == null:
		return _failure(&"invalid_character_id")
	if increments.is_empty():
		return {"ok": true, "already_applied": true}
	var normalized: Dictionary[StringName, int] = {}
	var total_cost := 0
	var initial := IdentityIds.initial_attributes(character.base_class_id)
	for raw_id: Variant in increments:
		if not (raw_id is String or raw_id is StringName):
			return _failure(&"invalid_attribute_allocations")
		var attribute_id := StringName(raw_id)
		if attribute_id not in IdentityIds.attribute_ids():
			return _failure(&"invalid_attribute_allocations")
		var raw_amount: Variant = increments[raw_id]
		if not raw_amount is int or int(raw_amount) <= 0:
			return _failure(&"invalid_attribute_allocations")
		var amount := int(raw_amount)
		if int(initial[attribute_id]) + character.attribute_allocations[attribute_id] + amount > StatCalculator.INVESTED_ATTRIBUTE_MAX:
			return _failure(&"attribute_cap_reached")
		normalized[attribute_id] = normalized.get(attribute_id, 0) + amount
		total_cost += amount
	if total_cost > ProgressionRules.attribute_points_available(character.base_xp_total, character.attribute_allocations):
		return _failure(&"insufficient_points")
	for attribute_id: StringName in normalized:
		character.attribute_allocations[attribute_id] += normalized[attribute_id]
	return {"ok": true, "spent": total_cost}

static func learn_skill(character: CharacterState, catalog: ProfileCatalog, skill_id: StringName) -> Dictionary:
	if character == null:
		return _failure(&"invalid_character_id")
	var metadata: Dictionary = catalog.skill_metadata(skill_id)
	if metadata.is_empty():
		return _failure(&"invalid_skill_id")
	if not catalog.skill_is_allowed(skill_id, character.base_class_id, character.evolution_id):
		return _failure(&"requirements_unmet")
	var purchased: int = character.purchased_skill_ranks.get(skill_id, 0)
	var legacy_grant: int = character.granted_skill_ranks.get(skill_id, 0)
	var maximum_rank: int = int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
	var current_rank: int = int(metadata["free_rank"]) + legacy_grant + purchased
	if current_rank >= maximum_rank:
		return _failure(&"rank_cap_reached")
	var wallet: StringName = metadata["wallet"]
	var evolved: bool = not character.evolution_id.is_empty()
	var granted: int = ProgressionRules.skill_points_granted(wallet, character.job_xp_total, evolved)
	var spent: int = catalog.skill_points_spent(character.purchased_skill_ranks, wallet)
	if spent >= granted:
		return _failure(&"insufficient_points")
	var effective_ranks: Dictionary[StringName, int] = catalog.effective_skill_ranks(
		character.base_class_id,
		character.evolution_id,
		character.purchased_skill_ranks,
		character.granted_skill_ranks
	)
	var target_rank: int = current_rank + 1
	var requirement: Dictionary = catalog.check_rank_requirements(
		skill_id,
		target_rank,
		ProgressionRules.job_level_for_xp(character.job_xp_total, evolved),
		effective_ranks
	)
	if not requirement["ok"]:
		return requirement
	character.purchased_skill_ranks[skill_id] = purchased + 1
	return {"ok": true, "skill_id": skill_id, "rank": target_rank, "wallet": wallet}

static func respec_attributes(character: CharacterState) -> Dictionary:
	if character == null:
		return _failure(&"invalid_character_id")
	var refunded := ProgressionRules.attribute_points_spent(character.attribute_allocations)
	if refunded == 0:
		return {"ok": true, "already_applied": true, "refunded": 0}
	for attribute_id: StringName in IdentityIds.attribute_ids():
		character.attribute_allocations[attribute_id] = 0
	return {"ok": true, "refunded": refunded}

static func respec_skills(character: CharacterState, catalog: ProfileCatalog) -> Dictionary:
	if character == null:
		return _failure(&"invalid_character_id")
	var base_refund := catalog.skill_points_spent(character.purchased_skill_ranks, ProfileCatalog.BASE_WALLET)
	var evolution_refund := catalog.skill_points_spent(character.purchased_skill_ranks, ProfileCatalog.EVOLUTION_WALLET)
	if base_refund == 0 and evolution_refund == 0:
		return {"ok": true, "already_applied": true, "base_refund": 0, "evolution_refund": 0}
	character.purchased_skill_ranks.clear()
	var effective := catalog.effective_skill_ranks(
		character.base_class_id,
		character.evolution_id,
		character.purchased_skill_ranks,
		character.granted_skill_ranks
	)
	for preset: Dictionary in character.presets:
		_prune_slots(preset["active_slots"], ProfileCatalog.ACTIVE, effective, catalog)
		_prune_slots(preset["passive_slots"], ProfileCatalog.PASSIVE, effective, catalog)
	return {"ok": true, "base_refund": base_refund, "evolution_refund": evolution_refund}

static func change_evolution(character: CharacterState, catalog: ProfileCatalog, evolution_id: StringName) -> Dictionary:
	if character == null:
		return _failure(&"invalid_character_id")
	var definition := catalog.evolution_definition(evolution_id)
	if definition == null or definition.origin_class_id != character.base_class_id:
		return _failure(&"invalid_origin")
	if character.evolution_id == evolution_id:
		return {
			"ok": true,
			"already_applied": true,
			"evolution_id": evolution_id,
			"evolution_refund": 0,
			"cleared_slots_by_preset": _empty_cleared_slots(),
		}
	if not definition.content_ready:
		return _failure(&"content_unavailable")
	var base_level := ProgressionRules.base_level_for_xp(character.base_xp_total)
	var job_level := ProgressionRules.job_level_for_xp(character.job_xp_total, not character.evolution_id.is_empty())
	if base_level < definition.required_base_level or job_level < definition.required_job_level:
		return _failure(&"requirements_unmet")

	var evolution_refund := catalog.skill_points_spent(character.purchased_skill_ranks, ProfileCatalog.EVOLUTION_WALLET)
	_remove_wallet_ranks(character.purchased_skill_ranks, catalog, ProfileCatalog.EVOLUTION_WALLET)
	# Legacy grants are rights carried by the base catalog. Evolution entry ranks
	# are derived from the selected definition and must never survive a branch swap.
	_remove_wallet_ranks(character.granted_skill_ranks, catalog, ProfileCatalog.EVOLUTION_WALLET)
	character.evolution_id = evolution_id
	var effective := catalog.effective_skill_ranks(
		character.base_class_id,
		character.evolution_id,
		character.purchased_skill_ranks,
		character.granted_skill_ranks
	)
	var cleared_slots: Array[Dictionary] = []
	for preset_index: int in character.presets.size():
		var preset: Dictionary = character.presets[preset_index]
		cleared_slots.append({
			"preset_index": preset_index,
			"active_slot_indices": _prune_slots(preset["active_slots"], ProfileCatalog.ACTIVE, effective, catalog),
			"passive_slot_indices": _prune_slots(preset["passive_slots"], ProfileCatalog.PASSIVE, effective, catalog),
		})
	return {
		"ok": true,
		"evolution_id": evolution_id,
		"evolution_refund": evolution_refund,
		"cleared_slots_by_preset": cleared_slots,
	}

static func _remove_wallet_ranks(ranks: Dictionary[StringName, int], catalog: ProfileCatalog, wallet: StringName) -> void:
	var removed_ids: Array[StringName] = []
	for skill_id: StringName in ranks:
		var metadata := catalog.skill_metadata(skill_id)
		if not metadata.is_empty() and metadata["wallet"] == wallet:
			removed_ids.append(skill_id)
	for skill_id: StringName in removed_ids:
		ranks.erase(skill_id)

static func _empty_cleared_slots() -> Array[Dictionary]:
	var cleared_slots: Array[Dictionary] = []
	for preset_index: int in CharacterState.PRESET_COUNT:
		cleared_slots.append({
			"preset_index": preset_index,
			"active_slot_indices": [],
			"passive_slot_indices": [],
		})
	return cleared_slots

static func _prune_slots(slots: Array, category: StringName, effective: Dictionary[StringName, int], catalog: ProfileCatalog) -> Array[int]:
	var cleared_indices: Array[int] = []
	for index: int in slots.size():
		var value: Variant = slots[index]
		if value == null:
			continue
		var skill_id := StringName(value)
		var metadata := catalog.skill_metadata(skill_id)
		if metadata.is_empty() or metadata["category"] != category or effective.get(skill_id, 0) <= 0:
			slots[index] = null
			cleared_indices.append(index)
	return cleared_indices

static func _failure(error_code: StringName) -> Dictionary:
	return {"ok": false, "error_code": error_code}
