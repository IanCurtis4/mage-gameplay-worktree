class_name SkillEffectResolver
extends RefCounted
## Preview and capture share a single pure path. Values are frozen by value.

static func preview(skill_id: StringName, rank: int, composed_build: Dictionary) -> Dictionary:
	return capture(skill_id, rank, composed_build)

static func capture(skill_id: StringName, rank: int, composed_build: Dictionary) -> Dictionary:
	if not composed_build.get("ok", false):
		return BuildEffectCatalog.failure(&"invalid_composed_build")
	if rank <= 0 or int(composed_build.get("skill_ranks", {}).get(skill_id, 0)) != rank:
		return BuildEffectCatalog.failure(&"rank_mismatch")
	var definition := ClassCatalog.skill_definition(skill_id)
	var rank_definition := definition.rank_definition(rank) if definition != null else null
	if rank_definition == null:
		return BuildEffectCatalog.failure(&"skill_not_learned")
	var axes: Dictionary = composed_build.get("skill_rules", {}).get(skill_id, {})
	var values := {"range": rank_definition.range, "sp_cost": rank_definition.sp_cost, "cooldown": rank_definition.cooldown, "projectile_count": 2.0 if skill_id == &"double_shot" else 1.0}
	for axis: StringName in axes:
		var rule: Dictionary = axes[axis]
		var base := float(values[axis])
		var minimum := 1.0 if axis == &"projectile_count" else 0.0
		# Flat first, additive increased once, one final declared cap.
		values[axis] = clampf((base + float(rule["flat"])) * (1.0 + float(rule["increased"])), minimum, maxf(minimum, float(rule["limit"])))
	values["projectile_count"] = floori(float(values["projectile_count"]))
	rank_definition.range = values["range"]
	rank_definition.sp_cost = values["sp_cost"]
	rank_definition.cooldown = values["cooldown"]
	return {"ok": true, "error_code": &"", "request_id": "", "skill_id": skill_id, "rank": rank, "build_version": composed_build.get("build_version", 0), "rank_definition": rank_definition, "values": values.duplicate(true), "procs": composed_build.get("procs", []).duplicate(true)}
