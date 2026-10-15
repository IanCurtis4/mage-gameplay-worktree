class_name SkillCastRank
extends RefCounted
## Explicit policy: only synchronous handlers whose emitted parameters are captured.
## Multi-stage casts that recapture a rank later remain highest-rank only until verified.
## Exclusions: Geometer grammar, Fury stat recaptures, Sentinel ammo reservations/absolute aura,
## traps/Hunter kit, Spiritualist drain/procession. Melee dash impacts copy launch requests.
const IDS: Array[StringName] = [&"slash", &"dash", &"fireball", &"fire_wall", &"fire_spear", &"ice_spear", &"teleport", &"double_shot", &"piercing_arrow", &"arrow_rain", &"lightning", &"electric_discharge", &"lightning_wall", &"soul_impact", &"haunt", &"phantom_barrier", &"ice_wall", &"shield_wall", &"provoke", &"perseverance", &"piercing_shout", &"brutal_strike", &"concentrated_rage", &"terrifying_shout", &"slowing_arrow", &"extended_aim", &"defender_counterstroke", &"defender_anchor", &"defender_line_lock", &"defender_reprisal_wave", &"elementalist_flame_burst", &"elementalist_glacial_ring", &"elementalist_lightning_arc", &"elementalist_ember_path", &"elementalist_tri_nova", &"spiritualist_echo_curse", &"spiritualist_spectral_veil", &"spiritualist_dissipation", &"berserker_rupture", &"berserker_execution", &"berserker_breath_steal", &"berserker_blood_rift", &"defender_riposte", &"defender_retreat_guard", &"berserker_pursuit_cut", &"berserker_wound_leap", &"defender_wall_advance"]

static func supports(id: StringName) -> bool:
	var definition := ClassCatalog.skill_definition(id)
	return id in IDS and definition != null and definition.category == SkillDefinition.Category.ACTIVE and definition.handler_id != SkillDefinition.Handler.UNASSIGNED and not definition.ranks.is_empty()

static func resolve(id: StringName, requested: int, effective: int) -> int:
	if requested == 0:
		return effective
	if requested < 0 or requested > effective or not supports(id):
		return 0
	var definition := ClassCatalog.skill_definition(id)
	return requested if definition.rank_definition(requested) != null else 0
