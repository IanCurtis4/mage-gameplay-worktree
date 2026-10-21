class_name ExpeditionCampaignState
extends RefCounted
## Pure transitions; the service stages these inside a canonical writer cut.
var expedition_id := ""
var character_id := ""
var manifest_data: Dictionary = {}
var policy: Dictionary = {}
var current_stage_id := ""
var lifecycle := "active"
var stages: Dictionary = {}
var slots: Dictionary = {}
var population_rules: Dictionary = {}
var clock := ExpeditionWaveClock.new()
var anchor: Dictionary = {}
var entry_claims: Dictionary = {}
var death_events: Dictionary = {}
var current_death_id := ""
var objectives: Dictionary = {}
var traversed_edges: Dictionary = {}
var completed := false

static func create(id: String, character: String, manifest: ExpeditionManifest, catalog: MobCatalog, rules: Dictionary) -> Dictionary:
	if not IdentityIds.is_technical_id(id) or character.is_empty(): return BuildEffectCatalog.failure(&"invalid_identity")
	var planned := ExpeditionPopulationPlanner.build(manifest, catalog, rules)
	if not planned["ok"]: return planned
	var result := ExpeditionCampaignState.new()
	result.expedition_id = id
	result.character_id = character
	result.manifest_data = manifest.to_data()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition/policies/e07_initial.json"))
	if not parsed is Dictionary or parsed.get("revision") != 1: return BuildEffectCatalog.failure(&"policy_unresolved")
	result.policy = parsed
	result.slots = planned["slots"]
	result.population_rules = rules.duplicate(true)
	result.clock.interval = result.policy["interval_seconds"]
	for stage: Dictionary in result.manifest_data["stages"]:
		result.stages[stage["stage_id"]] = {"visited": false, "cleared_once": false}
	result.current_stage_id = result.manifest_data["input"]["entry_stage_id"]
	result.anchor = result.entrance(result.current_stage_id)
	return {"ok": true, "state": result, "worlds": planned["worlds"]}

func entrance(stage_id: String) -> Dictionary:
	for stage: Dictionary in manifest_data["stages"]:
		if stage["stage_id"] != stage_id: continue
		for socket: Dictionary in stage["sockets"]:
			if socket["socket_id"] == stage["entrance"]: return ExpeditionWorldPoint.create(stage_id, socket["surface_id"], socket["position"]).to_data()
	return {}

func visit(stage_id: String) -> Array[String]:
	var grants: Array[String] = []
	if stages[stage_id]["visited"]: return grants
	stages[stage_id]["visited"] = true
	check_clear(stage_id)
	var sources: Array[String] = ["entry_stage:" + stage_id]
	if stage_id == manifest_data["input"]["entry_stage_id"]: sources.push_front("entry_run")
	for source: String in sources:
		if entry_claims.has(source): continue
		entry_claims[source] = true
		grants.append(source)
	return grants

func record_death(slot_id: String, generation: int, event_id: String) -> Dictionary:
	if not slots.has(slot_id) or event_id.is_empty(): return BuildEffectCatalog.failure(&"invalid_death_source")
	var slot: Dictionary = slots[slot_id]
	var key := str(generation)
	if slot["deaths"].has(key):
		return {"ok": true, "already_applied": true} if slot["deaths"][key] == event_id else BuildEffectCatalog.failure(&"request_conflict")
	if generation != slot["generation"] or slot["life_state"] != "alive": return BuildEffectCatalog.failure(&"stale_entity_generation")
	slot["deaths"][key] = event_id
	slot["life_state"] = "dead"
	if generation == 0: slot["initial_resolved"] = true
	var stage_id: String = slot["stage_id"]
	check_clear(stage_id)
	return {"ok": true, "cleared": stages[stage_id]["cleared_once"]}

func check_clear(stage_id: String) -> void:
	var cleared := true
	for other: Dictionary in slots.values():
		if other["stage_id"] == stage_id and other["blocks_clear"] and not other["initial_resolved"]: cleared = false
	if cleared and not stages[stage_id]["cleared_once"]:
		stages[stage_id]["cleared_once"] = true
		clock.arm()

func advance(delta: float, frozen: bool = false) -> bool:
	if lifecycle != "active" or clock.advance(delta, frozen) == 0: return false
	queue_wave()
	return true

func queue_wave() -> void:
	for slot: Dictionary in slots.values():
		if slot["trash"] and slot["life_state"] == "dead" and stages[slot["stage_id"]]["cleared_once"]:
			slot["life_state"] = "respawn_pending"
			slot["pending_wave"] = clock.wave_index

func admit_respawn(slot_id: String) -> Dictionary:
	if not slots.has(slot_id): return BuildEffectCatalog.failure(&"invalid_occurrence")
	var slot: Dictionary = slots[slot_id]
	if slot["life_state"] != "respawn_pending": return BuildEffectCatalog.failure(&"invalid_respawn")
	slot["generation"] += 1
	slot["life_state"] = "alive"
	slot["pending_wave"] = 0
	return {"ok": true, "generation": slot["generation"]}

func player_died(event_id: String) -> Dictionary:
	if death_events.has(event_id): return {"ok": true, "already_applied": true}
	if lifecycle != "active" or event_id.is_empty(): return BuildEffectCatalog.failure(&"invalid_death_source")
	death_events[event_id] = {"revived": false}
	current_death_id = event_id
	lifecycle = "recovering"
	return {"ok": true}

func revive(event_id: String) -> Dictionary:
	if not death_events.has(event_id): return BuildEffectCatalog.failure(&"invalid_death_source")
	if death_events[event_id]["revived"]: return {"ok": true, "already_applied": true}
	if current_death_id != event_id or lifecycle != "recovering": return BuildEffectCatalog.failure(&"invalid_death_source")
	death_events[event_id]["revived"] = true
	if clock.penalize(policy["death_penalty_seconds"]): queue_wave()
	lifecycle = "active"
	return {"ok": true}

func occurrence(slot_id: String) -> MobOccurrence:
	var slot: Dictionary = slots[slot_id]
	var result := MobOccurrence.new()
	result.occurrence_id = ExpeditionPopulationPlanner.occurrence_id(expedition_id, slot["stage_id"], slot_id, slot["generation"])
	result.mob_base_id = StringName(slot["species_id"])
	result.category_id = StringName(slot["occurrence_category"])
	result.origin_id = StringName(slot["origin_id"])
	return result

func reward_terms(slot_id: String) -> Dictionary:
	var slot: Dictionary = slots[slot_id]
	var generation: int = slot["generation"]
	return {"base_xp": ExpeditionRewardPolicy.scale_integer(slot["base_xp"], generation, 7), "job_xp": ExpeditionRewardPolicy.scale_integer(slot["job_xp"], generation, 7), "gold_factor": pow(policy["gold_factor"], generation), "equipment_factor": pow(policy["equipment_factor"], generation), "card_factor": pow(policy["card_factor"], generation), "policy_revision": int(policy["revision"]), "generation": generation}

func portal_view(portal_id: String) -> Dictionary:
	for portal: Dictionary in manifest_data["portals"]:
		if portal["portal_id"] != portal_id: continue
		var copy := portal.duplicate(true)
		var returning := traversed_edges.has(ExpeditionCanonical.digest([portal["to_stage"], portal["from_stage"]]))
		copy["open"] = portal["kind"] == "local" or returning or stages[portal["from_stage"]]["cleared_once"]
		return copy
	return {}

func view() -> Dictionary:
	return {"expedition_id": expedition_id, "stage_id": current_stage_id, "lifecycle": lifecycle, "stages": stages.duplicate(true), "slots": slots.duplicate(true), "remaining": clock.remaining, "wave_index": clock.wave_index, "anchor": anchor.duplicate(true)}

func valid() -> bool:
	if not IdentityIds.is_technical_id(expedition_id) or character_id.is_empty() or not clock.valid() or lifecycle not in ["active", "suspended", "recovering", "completed"]: return false
	if policy != JSON.parse_string(FileAccess.get_file_as_string("res://data/expedition/policies/e07_initial.json")) or clock.interval != policy["interval_seconds"]: return false
	if not manifest_data.has_all(["input", "stages", "population", "portals", "objectives", "witnesses"]) or not stages.has(current_stage_id) or slots.size() != population_rules.size(): return false
	if anchor.is_empty() or not stages.has(anchor.get("stage_id")) or not anchor.get("position") is Vector3 or not anchor["position"].is_finite(): return false
	if completed != (lifecycle == "completed"): return false
	if stages.size() != manifest_data["stages"].size() or slots.size() != manifest_data["population"]["slots"].size(): return false
	var any_cleared := false
	var expected_claims := {}
	for stage_id: String in stages:
		var stage: Variant = stages[stage_id]
		if not stage is Dictionary or not stage.get("visited") is bool or not stage.get("cleared_once") is bool: return false
		if stage["visited"]:
			expected_claims["entry_stage:" + stage_id] = true
			if stage_id == manifest_data["input"]["entry_stage_id"]: expected_claims["entry_run"] = true
		if stage["cleared_once"]:
			if not stage["visited"]: return false
			any_cleared = true
			for slot: Dictionary in slots.values():
				if slot["stage_id"] == stage_id and slot["blocks_clear"] and not slot["initial_resolved"]: return false
	if entry_claims != expected_claims or clock.started != any_cleared: return false
	for original: Dictionary in manifest_data["population"]["slots"]:
		var id: String = original["slot_id"]
		if not slots.has(id) or not population_rules.has(id): return false
		var slot: Dictionary = slots[id]
		for field: String in original:
			if slot.get(field) != original[field]: return false
		if not EquipmentRules.exact_integer(slot.get("generation"), 0) or not slot.get("deaths") is Dictionary or not slot.get("initial_resolved") is bool or slot.get("life_state") not in ["alive", "dead", "respawn_pending"]: return false
		var rules: Dictionary = population_rules[id]
		for field: String in ["trash", "base_xp", "job_xp"]:
			if slot.get(field) != rules.get(field): return false
		if slot["trash"] and slot["occurrence_category"] not in ["normal", "elite"]: return false
		if slot["generation"] > 0 and (not slot["trash"] or not stages[slot["stage_id"]]["cleared_once"]): return false
		if not EquipmentRules.exact_integer(slot.get("pending_wave"), 0, clock.wave_index): return false
		if (slot["pending_wave"] > 0) != (slot["life_state"] == "respawn_pending"): return false
		if slot["initial_resolved"] != slot["deaths"].has("0"): return false
		var deaths: int = slot["generation"] + (0 if slot["life_state"] == "alive" else 1)
		if deaths != slot["deaths"].size(): return false
		for index: int in deaths:
			if not slot["deaths"].get(str(index)) is String or slot["deaths"][str(index)].is_empty(): return false
		if slot["life_state"] == "respawn_pending" and (not slot["trash"] or not stages[slot["stage_id"]]["cleared_once"]): return false
	return true
