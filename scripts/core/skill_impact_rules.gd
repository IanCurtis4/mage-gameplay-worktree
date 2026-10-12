class_name SkillImpactRules
extends RefCounted
## Shared declared spear impact; no class passive or damage formula lives here.
static func spear(skill: StringName, result: Dictionary, target: CombatActor) -> void:
	if skill == &"ice_spear" and target != null and target.is_alive() and result.get("landed", false) and float(result.get("actual_damage", 0.0)) > 0.0:
		target.apply_slow(0.30, 2.0, &"ice_spear")
