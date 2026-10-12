class_name MobSkillAdapters
extends RefCounted
## Whitelisted concrete projectiles; no other player class mechanisms are granted.
const IDS: Array[StringName] = [&"fire_spear", &"ice_spear"]
static func supports(skill: StringName, rank: int) -> bool:
	var definition := ClassCatalog.skill_definition(skill)
	return skill in IDS and definition != null and definition.rank_definition(rank) != null
static func capture(skill: StringName, rank: int, stats: StatBreakdown, source: int, target: int) -> Dictionary:
	if not supports(skill, rank) or stats == null:
		return BuildEffectCatalog.failure(&"invalid_mob_skill")
	var definition := ClassCatalog.skill_definition(skill)
	var tuning := definition.rank_definition(rank)
	var request := DamageRequest.new()
	request.source_id = source
	request.target_id = target
	request.skill_id = skill
	request.magic_damage = stats.value(&"magic_attack") * tuning.power
	request.accuracy_mode = definition.accuracy_mode
	request.can_crit = definition.can_crit
	request.crit_chance = stats.value(&"crit_chance")
	request.crit_multiplier = stats.value(&"crit_multiplier")
	request.hit_rating = stats.value(&"hit_rating")
	return {"ok": true, "request": request, "rank_definition": tuning, "cast_time": StatCalculator.effective_cast_time(tuning.fixed_cast_time, tuning.variable_cast_time, stats), "cooldown": StatCalculator.effective_cooldown(tuning.cooldown, stats)}
