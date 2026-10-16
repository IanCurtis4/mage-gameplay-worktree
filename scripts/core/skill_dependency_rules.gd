class_name SkillDependencyRules
extends RefCounted
## Approved immutable prerequisite map; inspect consumes canonical preview metadata.
const REQUIREMENTS := {
	&"slash": {},
	&"dash": {},
	&"shield_wall": {},
	&"provoke": {&"shield_wall": 2},
	&"perseverance": {&"shield_wall": 2},
	&"piercing_shout": {},
	&"fury": {},
	&"brutal_strike": {&"slash": 2},
	&"concentrated_rage": {&"brutal_strike": 2},
	&"terrifying_shout": {&"piercing_shout": 2},
	&"swordsman_resistance": {},
	&"vigor": {},
	&"blood_thirst": {&"fury": 2},
	&"fireball": {},
	&"fire_wall": {},
	&"fire_spear": {&"fire_wall": 2},
	&"ice_spear": {},
	&"lightning": {},
	&"electric_discharge": {&"lightning": 2},
	&"lightning_wall": {&"electric_discharge": 2},
	&"soul_impact": {},
	&"haunt": {&"soul_impact": 2},
	&"phantom_barrier": {},
	&"ice_wall": {&"ice_spear": 2},
	&"teleport": {},
	&"mage_mana_regeneration": {},
	&"double_shot": {},
	&"piercing_arrow": {&"double_shot": 2},
	&"arrow_rain": {&"piercing_arrow": 2},
	&"extended_aim": {},
	&"snare_trap": {},
	&"explosive_trap": {&"snare_trap": 2},
	&"slowing_arrow": {},
	&"foliage_shelter": {},
	&"archer_precision": {},
	&"archer_cadence": {&"double_shot": 2},
	&"trap_technique": {&"snare_trap": 2},
	&"defender_counterstroke": {},
	&"defender_watch": {},
	&"defender_anchor": {&"shield_wall": 2},
	&"defender_line_lock": {&"defender_anchor": 2},
	&"defender_guard_return": {&"defender_counterstroke": 2},
	&"defender_wall_advance": {&"dash": 2},
	&"defender_reprisal_wave": {&"defender_counterstroke": 3},
	&"defender_riposte": {&"defender_guard_return": 2},
	&"defender_retreat_guard": {},
	&"berserker_rupture": {},
	&"berserker_obstinacy": {&"fury": 3},
	&"berserker_wound_leap": {&"dash": 2},
	&"berserker_execution": {&"berserker_rupture": 3},
	&"berserker_pursuit": {&"berserker_rupture": 2},
	&"berserker_blood_rift": {},
	&"berserker_breath_steal": {&"berserker_pursuit": 2},
	&"berserker_pursuit_cut": {&"berserker_wound_leap": 2},
	&"berserker_deep_bleeding": {&"berserker_blood_rift": 3},
	&"elementalist_flame_burst": {},
	&"elementalist_prismatic_focus": {},
	&"elementalist_glacial_ring": {&"ice_spear": 2},
	&"elementalist_lightning_arc": {&"lightning": 2},
	&"elementalist_prismatic_resonance": {&"elementalist_prismatic_focus": 2},
	&"elementalist_ember_path": {&"elementalist_flame_burst": 2},
	&"elementalist_tri_nova": {&"elementalist_glacial_ring": 2},
	&"spiritualist_echo_curse": {},
	&"spiritualist_echo_recovery": {&"spiritualist_echo_curse": 2},
	&"spiritualist_soul_drain": {},
	&"spiritualist_spectral_veil": {&"phantom_barrier": 2},
	&"spiritualist_channel_focus": {&"spiritualist_soul_drain": 2},
	&"spiritualist_procession": {&"soul_impact": 2},
	&"spiritualist_dissipation": {&"spiritualist_echo_curse": 3},
	&"sentinel_headshot": {},
	&"sentinel_observe": {},
	&"sentinel_precision_stance": {&"extended_aim": 2},
	&"sentinel_piercing_shot": {&"piercing_arrow": 2},
	&"sentinel_net_shot": {},
	&"sentinel_explosive_shot": {},
	&"sentinel_opening_read": {&"sentinel_observe": 2},
	&"sentinel_concussion_shot": {&"sentinel_net_shot": 2},
	&"sentinel_absolute_focus": {&"sentinel_precision_stance": 2},
	&"hunter_freezing_trap": {},
	&"hunter_tar_trap": {},
	&"hunter_thorn_trap": {&"hunter_freezing_trap": 2},
	&"hunter_mark": {},
	&"hunter_shooting_discipline": {&"double_shot": 2},
	&"hunter_covering_shot": {&"slowing_arrow": 2},
	&"hunter_easy_prey": {&"hunter_mark": 2},
	&"hunter_total_cover": {&"foliage_shelter": 2},
	&"geometer_trace": {},
	&"geometer_incidence": {&"geometer_trace": 2},
	&"geometer_translation": {&"teleport": 2},
	&"geometer_triangulation": {},
	&"geometer_vector_memory": {},
	&"geometer_collapse": {&"geometer_triangulation": 2},
	&"geometer_rewrite": {&"geometer_translation": 2},
}

static func inspect(skill: StringName, options: Array[Dictionary], summary: Dictionary) -> Dictionary:
	var by_id: Dictionary = {}
	for option: Dictionary in options:
		if not option.get("item_only", false): by_id[StringName(option["skill_id"])] = option
	var result := {"valid": true, "requirements": [], "ancestors": [], "missing_by_wallet": {&"base": 0, &"evolution": 0}, "purchase_by_wallet": {&"base": 0, &"evolution": 0}, "required_job": 1, "job_met": true, "points_met": true, "prerequisites_met": true, "maximum": true}
	if not by_id.has(skill): return result
	var selected: Dictionary = by_id[skill]
	var metadata: Dictionary = selected["metadata"]
	var current := int(selected.get("rank", 0))
	var maximum := int(selected["maximum_rank"])
	result["maximum"] = current >= maximum
	var target := mini(maximum, current + 1)
	var requirement: Dictionary = metadata["rank_requirements"].get(target, {})
	result["required_job"] = int(requirement.get("job_level", 1))
	var needed: Dictionary = {}
	for raw: Variant in requirement.get("skill_ranks", {}):
		var id := StringName(raw)
		var required := int(requirement["skill_ranks"][raw])
		needed[id] = required
		if not by_id.has(id) or not by_id[id].get("available", false):
			result["valid"] = false
			continue
		var source: Dictionary = by_id[id]
		var learned := int(source.get("rank", 0))
		result["requirements"].append({"skill_id": id, "required_rank": required, "learned_rank": learned, "job_id": StringName(source["metadata"].get("required_evolution_id", &"")), "wallet": StringName(source["metadata"]["wallet"]), "satisfied": learned >= required})
		if learned < required: result["prerequisites_met"] = false
	# Fixed point union: shared ancestors pay only their highest needed rank.
	for iteration: int in by_id.size() + 1:
		var changed := false
		for id: StringName in needed.keys():
			if not by_id.has(id) or not by_id[id].get("available", false):
				result["valid"] = false
				continue
			var source: Dictionary = by_id[id]
			var learned := int(source.get("rank", 0))
			var required := int(needed[id])
			if required > int(source["maximum_rank"]):
				result["valid"] = false
				continue
			for rank: int in range(1, required + 1):
				var ancestor_requirement: Dictionary = source["metadata"]["rank_requirements"].get(rank, {})
				result["required_job"] = maxi(int(result["required_job"]), int(ancestor_requirement.get("job_level", 1)))
				for ancestor: StringName in ancestor_requirement.get("skill_ranks", {}):
					var amount := int(ancestor_requirement["skill_ranks"][ancestor])
					if amount > int(needed.get(ancestor, 0)):
						needed[ancestor] = amount
						changed = true
		if not changed: break
		if iteration == by_id.size(): result["valid"] = false
	for id: StringName in needed:
		if not by_id.has(id): continue
		var source: Dictionary = by_id[id]
		var wallet := StringName(source["metadata"]["wallet"])
		if wallet not in [&"base", &"evolution"]:
			result["valid"] = false
			continue
		result["ancestors"].append({"skill_id": id, "required_rank": int(needed[id]), "learned_rank": int(source.get("rank", 0)), "job_id": StringName(source["metadata"].get("required_evolution_id", &"")), "wallet": wallet, "satisfied": int(source.get("rank", 0)) >= int(needed[id])})
		result["missing_by_wallet"][wallet] += maxi(0, int(needed[id]) - int(source.get("rank", 0)))
	if not result["maximum"]:
		var wallet := StringName(metadata["wallet"])
		if result["purchase_by_wallet"].has(wallet): result["purchase_by_wallet"][wallet] = 1
	result["job_met"] = int(summary.get("job_level", 1)) >= int(result["required_job"])
	for wallet: StringName in [&"base", &"evolution"]:
		var available := int(summary.get("%s_skill_points_available" % wallet, 0))
		if int(result["missing_by_wallet"][wallet]) + int(result["purchase_by_wallet"][wallet]) > available: result["points_met"] = false
	return result
