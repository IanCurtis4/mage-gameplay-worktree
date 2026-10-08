class_name ClassCatalog
extends RefCounted
## Single source for initial class and skill tuning. Returned Resources are catalog-only.

static var _classes: Dictionary[StringName, ClassDefinition] = {}
static var _skills: Dictionary[StringName, SkillDefinition] = {}

static func class_definition(class_id: StringName) -> ClassDefinition:
	_ensure_built()
	return _classes.get(class_id)

static func skill_definition(skill_id: StringName) -> SkillDefinition:
	_ensure_built()
	return _skills.get(skill_id)

static func skill_ids(class_id: StringName) -> Array[StringName]:
	var definition := class_definition(class_id)
	return definition.skill_ids.duplicate() if definition != null else []

static func passive_modifier_source(skill_id: StringName, rank: int, invested_vit: float = 0.0) -> Dictionary:
	var definition := skill_definition(skill_id)
	if definition == null or definition.category != SkillDefinition.Category.PASSIVE:
		return {}
	var rank_definition := definition.rank_definition(rank)
	if rank_definition == null:
		return {}
	match definition.handler_id:
		SkillDefinition.Handler.SWORDSMAN_RESISTANCE:
			return {
				"source_id": &"passive_swordsman_resistance",
				"label": "Resistência do Espadachim",
				"increased": {&"physical_defense": rank_definition.power},
			}
		SkillDefinition.Handler.MAGE_SP_REGENERATION:
			return {
				"source_id": &"passive_mage_sp_regeneration",
				"label": "Regeneração de SP do Mago",
				"increased": {&"sp_regen": rank_definition.power},
			}
		SkillDefinition.Handler.ARCHER_PRECISION:
			return {
				"source_id": &"passive_archer_precision",
				"label": "Precisão do Arqueiro",
				"flat": {&"hit_rating": rank_definition.power},
			}
		SkillDefinition.Handler.ARCHER_CADENCE:
			return {
				"source_id": &"passive_archer_cadence",
				"label": "Cadência do Arqueiro",
				"increased": {&"attacks_per_second": rank_definition.power},
			}
		SkillDefinition.Handler.VIGOR:
			return {
				"source_id": &"passive_swordsman_vigor",
				"label": "Vigor do Espadachim",
				"increased": {&"hp_regen": rank_definition.power},
			}
		SkillDefinition.Handler.BLOOD_THIRST:
			return {
				"source_id": &"passive_swordsman_blood_thirst",
				"label": "Sede de Sangue do Espadachim",
				"flat": {&"melee_attack": maxf(0.0, invested_vit) * rank_definition.power},
			}
	return {}

static func blood_thirst_heal_fraction(rank: int) -> float:
	return 0.01 + float(rank) * 0.01 if rank >= 1 and rank <= 3 else 0.0

static func passive_rule_source(skill_id: StringName, rank: int) -> Dictionary:
	var definition := skill_definition(skill_id)
	if definition == null or definition.category != SkillDefinition.Category.PASSIVE:
		return {}
	var rank_definition := definition.rank_definition(rank)
	if rank_definition == null:
		return {}
	if definition.handler_id == SkillDefinition.Handler.TRAP_TECHNIQUE:
		return {
			"source_id": &"passive_trap_technique",
			"label": "Técnica de Armadilhas do Arqueiro",
			"armed_duration_bonus": rank_definition.power,
		}
	return {}

static func active_modifier_source(skill_id: StringName, rank_definition: SkillRankDefinition) -> Dictionary:
	if skill_id == &"fury" and rank_definition != null:
		return {
			"source_id": &"active_fury",
			"label": "Fúria ativa",
			"increased": {
				&"melee_attack": rank_definition.power,
				&"attacks_per_second": rank_definition.power * 0.60,
				&"physical_defense": -0.25,
				&"magic_defense": -0.25,
			},
		}
	return {}

static func _ensure_built() -> void:
	if not _classes.is_empty():
		return
	_add_skill(&"slash", "Corte em cone", "Q", SkillDefinition.Targeting.DIRECTION, 15.0, 4.0, 1.45, 155.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"dash", "Investida", "W", SkillDefinition.Targeting.DIRECTION, 20.0, 6.0, 0.0, 270.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.MOBILITY)
	_add_skill(&"shield_wall", "Parede de Escudos", "D", SkillDefinition.Targeting.DIRECTION, 18.0, 12.0, 2.0, 34.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.DEFENSIVE)
	_add_skill(&"provoke", "Provocar", "D", SkillDefinition.Targeting.SINGLE_TARGET, 14.0, 10.0, 2.0, 300.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.DEFENSIVE)
	_add_skill(&"perseverance", "Perseverança", "D", SkillDefinition.Targeting.SELF, 18.0, 10.0, 40.0, 0.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.DEFENSIVE)
	_add_skill(&"piercing_shout", "Grito Perfurante", "D", SkillDefinition.Targeting.SELF, 17.0, 8.0, 1.5, 140.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"fury", "Fúria", "D", SkillDefinition.Targeting.SELF, 22.0, 14.0, 0.30, 0.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"brutal_strike", "Golpe Brutal", "D", SkillDefinition.Targeting.SINGLE_TARGET, 20.0, 8.0, 2.20, 110.0, 0.0, 0.55, DamageRequest.AccuracyMode.GEOMETRY, true, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"concentrated_rage", "Raiva Concentrada", "D", SkillDefinition.Targeting.DIRECTION, 19.0, 7.5, 1.45, 230.0, 0.0, 0.35, DamageRequest.AccuracyMode.GEOMETRY, true, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"terrifying_shout", "Grito Aterrorizante", "D", SkillDefinition.Targeting.SELF, 20.0, 11.0, 0.75, 170.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"fireball", "Bola de Fogo", "Q", SkillDefinition.Targeting.DIRECTION, 18.0, 2.5, 1.80, 700.0, 680.0, 0.32, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"fire_wall", "Parede de Fogo", "W", SkillDefinition.Targeting.DIRECTION, 24.0, 7.0, 0.30, 180.0, 0.0, 0.48, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"fire_spear", "Lança de Fogo", "A", SkillDefinition.Targeting.SINGLE_TARGET, 16.0, 3.0, 1.35, 360.0, 760.0, 0.22, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"ice_spear", "Lança de Gelo", "S", SkillDefinition.Targeting.SINGLE_TARGET, 14.0, 3.0, 1.10, 360.0, 760.0, 0.22, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"lightning", "Relâmpago", "D", SkillDefinition.Targeting.SINGLE_TARGET, 16.0, 4.0, 1.25, 380.0, 820.0, 0.26, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"electric_discharge", "Descarga Elétrica", "D", SkillDefinition.Targeting.DIRECTION, 18.0, 5.0, 1.10, 560.0, 800.0, 0.30, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"lightning_wall", "Parede de Raios", "D", SkillDefinition.Targeting.DIRECTION, 22.0, 8.0, 0.50, 220.0, 0.0, 0.38, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"soul_impact", "Impacto das Almas", "D", SkillDefinition.Targeting.SINGLE_TARGET, 19.0, 6.0, 1.35, 400.0, 0.0, 0.36, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"haunt", "Assombro", "D", SkillDefinition.Targeting.DIRECTION, 18.0, 9.0, 0.35, 230.0, 0.0, 0.40, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"phantom_barrier", "Barreira Fantasma", "D", SkillDefinition.Targeting.DIRECTION, 20.0, 10.0, 2.0, 210.0, 0.0, 0.42, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"ice_wall", "Parede de Gelo", "D", SkillDefinition.Targeting.DIRECTION, 22.0, 9.0, 3.0, 200.0, 0.0, 0.45, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"teleport", "Teleporte", "D", SkillDefinition.Targeting.POINT, 22.0, 6.0, 0.0, 320.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"double_shot", "Disparo Duplo", "Q", SkillDefinition.Targeting.DIRECTION, 14.0, 4.0, 0.70, 520.0, 880.0, 0.0, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"piercing_arrow", "Flecha Perfurante", "W", SkillDefinition.Targeting.DIRECTION, 18.0, 5.0, 1.05, 600.0, 920.0, 0.0, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"arrow_rain", "Chuva de Flechas", "A", SkillDefinition.Targeting.POINT, 22.0, 7.0, 1.80, 480.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"extended_aim", "Mira Estendida", "S", SkillDefinition.Targeting.SELF, 16.0, 12.0, 4.0, 0.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"snare_trap", "Armadilha de Laço", "D", SkillDefinition.Targeting.POINT, 18.0, 8.0, 1.4, 360.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"explosive_trap", "Armadilha Explosiva", "D", SkillDefinition.Targeting.POINT, 20.0, 9.0, 1.35, 360.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"slowing_arrow", "Flecha Entorpecente", "D", SkillDefinition.Targeting.DIRECTION, 15.0, 5.0, 0.90, 560.0, 880.0, 0.0, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"foliage_shelter", "Abrigo de Folhagem", "D", SkillDefinition.Targeting.POINT, 18.0, 12.0, 4.0, 360.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_passive_skill(&"swordsman_resistance", "Resistência")
	_add_passive_skill(&"vigor", "Vigor")
	_add_passive_skill(&"blood_thirst", "Sede de Sangue")
	_add_passive_skill(&"mage_mana_regeneration", "Regeneração de SP")
	_add_passive_skill(&"archer_precision", "Precisão")
	_add_passive_skill(&"archer_cadence", "Cadência")
	_add_passive_skill(&"trap_technique", "Técnica de Armadilhas")
	_add_skill(&"defender_counterstroke", "Contraforte", "D", SkillDefinition.Targeting.DIRECTION, 16.0, 6.0, 1.05, 120.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true, SkillDefinition.ActionKind.OFFENSIVE)
	_add_passive_skill(&"defender_watch", "Vigília")
	_add_skill(&"defender_anchor", "Marco de Guarda", "D", SkillDefinition.Targeting.POINT, 20.0, 12.0, 4.0, 150.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false, SkillDefinition.ActionKind.DEFENSIVE)
	_add_skill(&"defender_line_lock", "Trava de Linha", "D", SkillDefinition.Targeting.DIRECTION, 18.0, 9.0, 0.70, 170.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true, SkillDefinition.ActionKind.OFFENSIVE)
	_add_passive_skill(&"defender_guard_return", "Resguardo")
	_add_skill(&"defender_wall_advance", "Avanço de Muralha", "D", SkillDefinition.Targeting.DIRECTION, 22.0, 10.0, 0.80, 80.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"defender_reprisal_wave", "Onda de Represália", "D", SkillDefinition.Targeting.SELF, 24.0, 12.0, 0.60, 130.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true, SkillDefinition.ActionKind.OFFENSIVE)
	_add_skill(&"berserker_rupture", "Ruptura", "D", SkillDefinition.Targeting.SINGLE_TARGET, 17.0, 5.0, 1.0, 110.0, 0.0, 0.0, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_passive_skill(&"berserker_obstinacy", "Obstinação")
	_add_skill(&"berserker_wound_leap", "Salto Cruento", "D", SkillDefinition.Targeting.DIRECTION, 18.0, 8.0, 0.80, 140.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"berserker_execution", "Execução", "D", SkillDefinition.Targeting.SINGLE_TARGET, 22.0, 9.0, 1.20, 110.0, 0.0, 0.0, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_passive_skill(&"berserker_pursuit", "Caça Persistente")
	_add_skill(&"berserker_blood_rift", "Fenda Sangrenta", "D", SkillDefinition.Targeting.DIRECTION, 21.0, 9.0, 0.90, 220.0, 0.0, 0.3, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"berserker_breath_steal", "Arrancar Fôlego", "D", SkillDefinition.Targeting.SINGLE_TARGET, 18.0, 12.0, 1.0, 110.0, 0.0, 0.0, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"elementalist_flame_burst", "Explosão de Chamas", "D", SkillDefinition.Targeting.POINT, 20.0, 6.0, 1.30, 380.0, 0.0, 0.45, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_passive_skill(&"elementalist_prismatic_focus", "Foco Prismático")
	_add_skill(&"elementalist_glacial_ring", "Anel Glacial", "D", SkillDefinition.Targeting.SELF, 19.0, 8.0, 0.90, 145.0, 0.0, 0.35, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"elementalist_lightning_arc", "Arco Voltaico", "D", SkillDefinition.Targeting.SINGLE_TARGET, 22.0, 8.0, 1.10, 380.0, 0.0, 0.35, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_passive_skill(&"elementalist_prismatic_resonance", "Ressonância Prismática")
	_add_skill(&"elementalist_ember_path", "Trilha de Brasas", "D", SkillDefinition.Targeting.DIRECTION, 24.0, 10.0, 1.10, 240.0, 0.0, 0.50, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"elementalist_tri_nova", "Nova Tríplice", "D", SkillDefinition.Targeting.SELF, 30.0, 16.0, 0.70, 170.0, 0.0, 0.65, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"spiritualist_echo_curse", "Maldição do Eco", "D", SkillDefinition.Targeting.SINGLE_TARGET, 18.0, 6.0, 0.85, 380.0, 0.0, 0.35, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_passive_skill(&"spiritualist_echo_recovery", "Recolhimento")
	_add_skill(&"spiritualist_soul_drain", "Drenagem Espiritual", "D", SkillDefinition.Targeting.SINGLE_TARGET, 22.0, 10.0, 0.36, 350.0, 0.0, 0.30, DamageRequest.AccuracyMode.CONTESTED, false)
	_add_skill(&"spiritualist_spectral_veil", "Véu Espectral", "D", SkillDefinition.Targeting.POINT, 20.0, 12.0, 0.15, 250.0, 0.0, 0.25, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_passive_skill(&"spiritualist_channel_focus", "Foco do Além")
	_add_skill(&"spiritualist_procession", "Procissão de Espectros", "D", SkillDefinition.Targeting.SINGLE_TARGET, 24.0, 10.0, 0.45, 380.0, 0.0, 0.40, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"spiritualist_dissipation", "Rito de Dissipação", "D", SkillDefinition.Targeting.POINT, 27.0, 14.0, 0.85, 330.0, 0.0, 0.60, DamageRequest.AccuracyMode.GEOMETRY, true)
	# Execution data only: ProfileCatalog keeps mg_ar unavailable until G7.
	_add_skill(&"geometer_trace", "Traçado Elemental", "Q", SkillDefinition.Targeting.POINT, 8.0, 0.4, 0.30, 600.0, 900.0, 0.12, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"geometer_triangulation", "Triangulação", "W", SkillDefinition.Targeting.POINT, 16.0, 3.0, 0.0, 600.0, 900.0, 0.12, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_passive_skill(&"geometer_incidence", "Teorema de Incidência")
	_add_skill(&"geometer_translation", "Translação", "A", SkillDefinition.Targeting.POINT, 12.0, 4.0, 0.0, 600.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_passive_skill(&"geometer_vector_memory", "Memória Vetorial")
	_add_skill(&"geometer_collapse", "Colapso Geométrico", "S", SkillDefinition.Targeting.SELF, 18.0, 8.0, 0.60, 0.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"geometer_rewrite", "Reescrita", "D", SkillDefinition.Targeting.POINT, 14.0, 5.0, 0.0, 600.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_configure_slash_ranks()
	_configure_dash_ranks()
	_configure_shield_wall_ranks()
	_configure_provoke_ranks()
	_configure_perseverance_ranks()
	_configure_piercing_shout_ranks()
	_configure_fury_ranks()
	_configure_brutal_strike_ranks()
	_configure_concentrated_rage_ranks()
	_configure_terrifying_shout_ranks()
	_configure_swordsman_resistance_ranks()
	_configure_vigor_ranks()
	_configure_blood_thirst_ranks()
	_configure_fireball_ranks()
	_configure_fire_wall_ranks()
	_configure_fire_spear_ranks()
	_configure_ice_spear_ranks()
	_configure_lightning_ranks()
	_configure_electric_discharge_ranks()
	_configure_lightning_wall_ranks()
	_configure_soul_impact_ranks()
	_configure_haunt_ranks()
	_configure_phantom_barrier_ranks()
	_configure_ice_wall_ranks()
	_configure_teleport_ranks()
	_configure_mage_sp_regeneration_ranks()
	_configure_double_shot_ranks()
	_configure_piercing_arrow_ranks()
	_configure_arrow_rain_ranks()
	_configure_extended_aim_ranks()
	_configure_snare_trap_ranks()
	_configure_explosive_trap_ranks()
	_configure_slowing_arrow_ranks()
	_configure_foliage_shelter_ranks()
	_configure_archer_precision_ranks()
	_configure_archer_cadence_ranks()
	_configure_trap_technique_ranks()
	_configure_defender_counterstroke_ranks()
	_configure_defender_watch_ranks()
	_configure_defender_anchor_ranks()
	_configure_defender_line_lock_ranks()
	_configure_defender_guard_return_ranks()
	_configure_defender_wall_advance_ranks()
	_configure_defender_reprisal_wave_ranks()
	_configure_berserker_ranks()
	_configure_elementalist_ranks()
	_configure_spiritualist_curse_ranks()
	_configure_spiritualist_recovery_ranks()
	_configure_spiritualist_drain_ranks()
	_configure_spiritualist_veil_ranks()
	_configure_spiritualist_focus_ranks()
	_configure_spiritualist_procession_ranks()
	_configure_spiritualist_dissipation_ranks()
	_configure_geometer_trace_ranks()
	_configure_geometer_edit_ranks()
	_configure_sentinel_skills()
	_configure_hunter_skills()

	var swordsman := ClassDefinition.new()
	swordsman.id = IdentityIds.SWORDSMAN
	swordsman.display_name = "Espadachim"
	swordsman.attributes = IdentityIds.initial_attributes(IdentityIds.SWORDSMAN)
	swordsman.skill_ids = [&"slash", &"dash"]
	swordsman.passive_id = &"swordsman_resistance"
	swordsman.basic_power = 1.0
	swordsman.basic_range = 50.0
	_classes[swordsman.id] = swordsman

	var mage := ClassDefinition.new()
	mage.id = IdentityIds.MAGE
	mage.display_name = "Mago"
	mage.attributes = IdentityIds.initial_attributes(IdentityIds.MAGE)
	mage.skill_ids = [&"fireball", &"fire_wall", &"fire_spear", &"ice_spear", &"teleport"]
	mage.passive_id = &"mage_mana_regeneration"
	mage.basic_power = 1.0
	mage.basic_range = 250.0
	_classes[mage.id] = mage

	var archer := ClassDefinition.new()
	archer.id = IdentityIds.ARCHER
	archer.display_name = "Arqueiro"
	archer.attributes = IdentityIds.initial_attributes(IdentityIds.ARCHER)
	archer.skill_ids = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"snare_trap"]
	archer.passive_id = &"archer_precision"
	archer.basic_power = 1.0
	archer.basic_range = 340.0
	_classes[archer.id] = archer

static func _add_skill(
	skill_id: StringName,
	display_name: String,
	input_key: String,
	targeting: SkillDefinition.Targeting,
	sp_cost: float,
	cooldown: float,
	power: float,
	range_value: float,
	projectile_speed: float = 0.0,
	cast_time: float = 0.0,
	accuracy_mode: DamageRequest.AccuracyMode = DamageRequest.AccuracyMode.CONTESTED,
	can_crit: bool = false,
	action_kind: SkillDefinition.ActionKind = SkillDefinition.ActionKind.OFFENSIVE
) -> void:
	var definition := SkillDefinition.new()
	definition.id = skill_id
	definition.display_name = display_name
	definition.input_key = input_key
	definition.targeting = targeting
	definition.action_kind = action_kind
	definition.accuracy_mode = accuracy_mode
	definition.can_crit = can_crit
	definition.sp_cost = sp_cost
	definition.cooldown = cooldown
	definition.cast_time = cast_time
	definition.power = power
	definition.range = range_value
	definition.projectile_speed = projectile_speed
	_skills[skill_id] = definition

static func _add_passive_skill(skill_id: StringName, display_name: String) -> void:
	var definition := SkillDefinition.new()
	definition.id = skill_id
	definition.display_name = display_name
	definition.category = SkillDefinition.Category.PASSIVE
	_skills[skill_id] = definition

static func _configure_sentinel_skills() -> void:
	var names: Array[String] = ["Tiro na Cabeça", "Observar", "Postura de Precisão", "Tiro Perfurante", "Tiro de Rede", "Tiro Explosivo", "Leitura de Aberturas", "Tiro de Concussão", "Foco Absoluto"]
	var handlers: Array[SkillDefinition.Handler] = [SkillDefinition.Handler.SENTINEL_HEADSHOT, SkillDefinition.Handler.SENTINEL_OBSERVE, SkillDefinition.Handler.SENTINEL_PRECISION_STANCE, SkillDefinition.Handler.SENTINEL_PIERCING_SHOT, SkillDefinition.Handler.SENTINEL_NET_SHOT, SkillDefinition.Handler.SENTINEL_EXPLOSIVE_SHOT, SkillDefinition.Handler.SENTINEL_OPENING_READ, SkillDefinition.Handler.SENTINEL_CONCUSSION_SHOT, SkillDefinition.Handler.SENTINEL_ABSOLUTE_FOCUS]
	for index: int in SentinelTuning.SKILL_IDS.size():
		var skill_id := SentinelTuning.SKILL_IDS[index]
		var first := SentinelTuning.values(skill_id, 1)
		var maximum := SentinelTuning.max_rank(skill_id)
		var contested := skill_id in [&"sentinel_headshot", &"sentinel_concussion_shot"]
		var offensive := skill_id in [&"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot", &"sentinel_concussion_shot"]
		if maximum == 3:
			_add_passive_skill(skill_id, names[index])
		else:
			var targeting := SkillDefinition.Targeting.SINGLE_TARGET
			if skill_id == &"sentinel_piercing_shot":
				targeting = SkillDefinition.Targeting.DIRECTION
			elif skill_id == &"sentinel_net_shot":
				targeting = SkillDefinition.Targeting.POINT
			elif skill_id in [&"sentinel_explosive_shot", &"sentinel_absolute_focus"]:
				targeting = SkillDefinition.Targeting.SELF
			_add_skill(skill_id, names[index], "D", targeting, first["sp_cost"], first["cooldown"], first["power"], first["range"], first["projectile_speed"], first["variable_cast_time"], DamageRequest.AccuracyMode.CONTESTED if contested else DamageRequest.AccuracyMode.GEOMETRY, offensive, SkillDefinition.ActionKind.OFFENSIVE if offensive else SkillDefinition.ActionKind.DEFENSIVE)
		var definition: SkillDefinition = _skills[skill_id]
		definition.handler_id = handlers[index]
		for current_rank: int in range(1, maximum + 1):
			var values := SentinelTuning.values(skill_id, current_rank)
			var rank := SkillRankDefinition.new()
			rank.rank = current_rank
			rank.sp_cost = values["sp_cost"]
			rank.cooldown = values["cooldown"]
			rank.range = values["range"]
			rank.projectile_speed = values["projectile_speed"]
			rank.variable_cast_time = values["variable_cast_time"]
			rank.power = values["power"]
			rank.secondary_power = values["secondary_power"]
			if contested:
				rank.precision_weight = 1.0
			elif offensive:
				# Explicit INT/INT+DES tuning is consumed by the Sentinel math helper;
				# these skills must not use the global DES-bearing magic_attack stat.
				rank.magic_weight = 1.0
			rank.effect_ids = _sentinel_effect_ids(skill_id)
			definition.ranks.append(rank)
		assert(definition.is_rank_catalog_valid())

static func _configure_hunter_skills() -> void:
	var names: Array[String] = [
		"Armadilha Congelante", "Armadilha de Piche", "Armadilha de Espinhos",
		"Marca do Caçador", "Disciplina de Tiro", "Tiro de Cobertura",
		"Presa Fácil", "Cobertura Total",
	]
	var handlers: Array[SkillDefinition.Handler] = [
		SkillDefinition.Handler.HUNTER_FREEZING_TRAP,
		SkillDefinition.Handler.HUNTER_TAR_TRAP,
		SkillDefinition.Handler.HUNTER_THORN_TRAP,
		SkillDefinition.Handler.HUNTER_MARK,
		SkillDefinition.Handler.HUNTER_SHOOTING_DISCIPLINE,
		SkillDefinition.Handler.HUNTER_COVERING_SHOT,
		SkillDefinition.Handler.HUNTER_EASY_PREY,
		SkillDefinition.Handler.HUNTER_TOTAL_COVER,
	]
	for index: int in HunterTuning.SKILL_IDS.size():
		var skill_id := HunterTuning.SKILL_IDS[index]
		var first := HunterTuning.values(skill_id, 1)
		var maximum := HunterTuning.max_rank(skill_id)
		if maximum == 3:
			_add_passive_skill(skill_id, names[index])
		else:
			var targeting := SkillDefinition.Targeting.POINT
			var offensive := skill_id != &"hunter_total_cover"
			if skill_id == &"hunter_mark":
				targeting = SkillDefinition.Targeting.SINGLE_TARGET
			elif skill_id == &"hunter_covering_shot":
				targeting = SkillDefinition.Targeting.DIRECTION
			_add_skill(skill_id, names[index], "D", targeting, first["sp_cost"], first["cooldown"], first["power"], first["range"], first["projectile_speed"], first["variable_cast_time"], DamageRequest.AccuracyMode.GEOMETRY, skill_id == &"hunter_covering_shot", SkillDefinition.ActionKind.OFFENSIVE if offensive else SkillDefinition.ActionKind.DEFENSIVE)
		var definition: SkillDefinition = _skills[skill_id]
		definition.handler_id = handlers[index]
		for current_rank: int in range(1, maximum + 1):
			var values := HunterTuning.values(skill_id, current_rank)
			var rank := SkillRankDefinition.new()
			rank.rank = current_rank
			rank.sp_cost = values["sp_cost"]
			rank.cooldown = values["cooldown"]
			rank.range = values["range"]
			rank.projectile_speed = values["projectile_speed"]
			rank.variable_cast_time = values["variable_cast_time"]
			rank.power = values["power"]
			rank.secondary_power = values["secondary_power"]
			if skill_id == &"hunter_freezing_trap":
				rank.magic_weight = 1.0
			elif skill_id == &"hunter_thorn_trap":
				rank.physical_weight = 1.0
			elif skill_id == &"hunter_covering_shot":
				rank.precision_weight = 1.0
			rank.effect_ids = _hunter_effect_ids(skill_id)
			definition.ranks.append(rank)
		assert(definition.is_rank_catalog_valid())

static func _hunter_effect_ids(skill_id: StringName) -> Array[StringName]:
	match skill_id:
		&"hunter_freezing_trap":
			return [&"hunter_trap_place_validate_terrain_los", &"armed_stationary_trigger", &"opening_on_primary_activation", &"magic_root_after_damage"]
		&"hunter_tar_trap":
			return [&"hunter_trap_place_validate_terrain_los", &"armed_stationary_trigger", &"opening_on_primary_activation", &"replace_owner_tar_field_no_damage"]
		&"hunter_thorn_trap":
			return [&"hunter_trap_place_validate_terrain_los", &"armed_stationary_trigger", &"opening_on_primary_activation", &"physical_bleed_snapshot", &"slow_after_positive_damage"]
		&"hunter_mark":
			return [&"one_priority_mark_per_victim", &"extends_captured_opening", &"opening_reward_bonus"]
		&"hunter_shooting_discipline":
			return [&"precision_secondary_on_exploration_shot_only"]
		&"hunter_covering_shot":
			return [&"direct_precision_shot", &"validated_recoil_segment", &"opening_trigger_reuses_consumption_rules", &"does_not_reset_auto"]
		&"hunter_easy_prey":
			return [&"bonus_when_marked_or_controlled_before_shot", &"opening_alone_suffices_against_resistant_boss"]
		&"hunter_total_cover":
			return [&"shared_cover_budget_and_cooldown", &"one_second_exit_grace", &"does_not_replace_foliage_shelter"]
	return []

static func hunter_description(skill_id: StringName, rank: int = 1) -> String:
	var values := HunterTuning.values(skill_id, rank)
	if values.is_empty():
		return ""
	match skill_id:
		&"hunter_freezing_trap":
			return "Arma uma armadilha em até 360: raio %.0f, aprisionamento mágico por %.1fs e dano %.0f + %.1f×INT, escalado pelo rank da armadilha." % [values["radius"], values["root_duration"], values["base"], values["int_coefficient"]]
		&"hunter_tar_trap":
			return "Arma uma armadilha em até 360: campo de %.0f por %.1fs, lentidão de %.0f%% e resíduo por %.1fs; não causa dano." % [values["field_radius"], values["field_duration"], values["slow_fraction"] * 100.0, values["residual_duration"]]
		&"hunter_thorn_trap":
			return "Arma uma armadilha em até 360: área %.0f, dano físico %.0f + %.1f×INT, sangramento por %.0fs e lentidão por %.0fs." % [values["radius"], values["base"], values["int_coefficient"], values["bleed_duration"], values["slow_duration"]]
		&"hunter_mark":
			return "Marca um alvo a até 360 por %.0fs: estende em %.2fs a abertura capturada e aumenta sua parcela de INT em %.1f%%." % [values["duration"], values["opening_extension"], values["reward_bonus"] * 100.0]
		&"hunter_shooting_discipline":
			return "Tiros que exploram uma abertura causam um impacto físico secundário de %.0f%% do ATQ de precisão capturado." % (values["power"] * 100.0)
		&"hunter_covering_shot":
			return "Dispara na direção escolhida até 520, causando ATQ de precisão × %.2f e recuando 80 unidades. Recuo bloqueado cancela toda a ação sem custo." % values["power"]
		&"hunter_easy_prey":
			return "Aprendida (automática): aumenta em %.0f%% somente a parcela de INT da abertura se a presa estava marcada ou controlada antes do controle do próprio tiro; contra chefes resistentes, a abertura basta." % (values["power"] * 100.0)
		&"hunter_total_cover":
			return "Cria cobertura em até 300, raio 125 por %.1fs, com 1s para sair. " % values["duration"] + hunter_cover_description()
	return ""

static func hunter_cover_description() -> String:
	return "Na Caçadora, Abrigo e Cobertura Total compartilham %.0fs de ocultação e recarga base de %.0fs (reduzida pelos atributos). Ofensiva válida revela por %.2fs; reentrar não renova o orçamento." % [HunterTuning.COVER_BUDGET, HunterTuning.COVER_COOLDOWN, HunterTuning.COVER_REVEAL]

static func _sentinel_effect_ids(skill_id: StringName) -> Array[StringName]:
	match skill_id:
		&"sentinel_headshot":
			return [&"validated_single_special_shot_resets_auto", &"physical_precision_damage_normal_crit", &"focus_cost_30"]
		&"sentinel_observe":
			return [&"one_mark_three_positive_direct_actions", &"shared_half_second_focus_return", &"mark_eight_seconds"]
		&"sentinel_precision_stance":
			return [&"conditional_effective_dex_luk_after_stability", &"remove_on_actual_movement_no_static_build_bonus"]
		&"sentinel_piercing_shot":
			return [&"validated_directional_special_shot_resets_auto", &"explicit_int_dex_magic_damage", &"once_per_victim_stops_at_terrain", &"local_bounded_dex_cooldown", &"focus_cost_20"]
		&"sentinel_net_shot":
			return [&"projectile_area_on_first_valid_contact", &"explicit_int_only_magic_damage", &"root_after_positive_direct_damage", &"local_bounded_dex_cooldown"]
		&"sentinel_explosive_shot":
			return [&"reserve_sp_focus_for_next_ordinary_auto", &"cancel_refunds_before_launch", &"exclusive_int_magic_area_no_double_primary", &"local_bounded_dex_cooldown", &"focus_cost_25"]
		&"sentinel_opening_read":
			return [&"positive_direct_crit_or_preexisting_root_stun_focus_return", &"one_proc_per_action_shared_one_second"]
		&"sentinel_concussion_shot":
			return [&"validated_single_special_shot_resets_auto", &"physical_precision_damage_normal_crit", &"stun_after_positive_damage", &"damage_dealt_reduction_ten_percent"]
		&"sentinel_absolute_focus":
			return [&"finite_buff_twenty_percent_range", &"stationary_focus_fifteen_per_second_without_resource_warmup", &"precision_passive_warmup_unchanged"]
	return []

static func sentinel_description(skill_id: StringName, rank: int = 1) -> String:
	var values := SentinelTuning.values(skill_id, rank)
	if values.is_empty():
		return ""
	match skill_id:
		&"sentinel_headshot":
			return "Um tiro físico de precisão (%.2f×), crítico normal por SOR. Consome 30 Foco; reseta o auto sem tiro comum extra." % values["power"]
		&"sentinel_observe":
			return "Marca por 8s: próximos 3 acertos diretos próprios devolvem %.0f Foco, uma vez por ação a cada 0,5s. Nova marca substitui a anterior." % values["focus_return"]
		&"sentinel_precision_stance":
			return "Equipada: após 0,75s parado, +%.0f DES/+%.0f SOR efetivas. Andar/teleportar remove; não muda atributos comprados." % [values["dex_bonus"], values["luk_bonus"]]
		&"sentinel_piercing_shot":
			return "Um tiro linear até 600: dano mágico %.0f + %.2f×INT + %.2f×DES, crítico por SOR. Atravessa inimigos uma vez; terreno bloqueia. Reseta auto; 20 Foco; DES reduz apenas esta recarga até 25%%." % [values["base"], values["int_coefficient"], values["dex_coefficient"]]
		&"sentinel_net_shot":
			return "Projétil no chão, raio 90: dano mágico %.0f + %.2f×INT e root %.2fs. DES reduz preparo/recarga, não dano; root não bloqueia ataques. Obstáculos interceptam." % [values["base"], values["int_coefficient"], values["root_duration"]]
		&"sentinel_explosive_shot":
			return "Reserva SP/25 Foco para o próximo auto comum: dano mágico %.0f + %.2f×INT em raio 80, sem dano físico extra ou repetição na vítima principal. Não reseta auto; cancelar antes do disparo devolve reserva; CD começa no disparo." % [values["base"], values["int_coefficient"]]
		&"sentinel_opening_read":
			return "Equipada: acerto direto crítico OU em alvo já preso/atordoado devolve %.0f Foco, uma vez por ação a cada 1s. Controle aplicado pelo próprio impacto não qualifica." % values["focus_return"]
		&"sentinel_concussion_shot":
			return "Um tiro físico de precisão (%.2f×), stun %.2fs e dano causado -10%% por %.1fs após acerto positivo. Reseta auto sem duplicar; boss usa resistência canônica." % [values["power"], values["stun_duration"], values["duration"]]
		&"sentinel_absolute_focus":
			return "Por %.1fs: alcance +20%% e Foco parado 15/s sem preparação de 0,5s. Mover preserva reserva, mas não gera; não dispensa preparo da Postura. CD começa ao ativar." % values["duration"]
	return ""

static func _configure_slash_ranks() -> void:
	var definition: SkillDefinition = _skills[&"slash"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.SLASH
	var powers: Array[float] = [1.45, 1.65, 1.85, 2.05, 2.25]
	var costs: Array[float] = [15.0, 17.0, 18.0, 19.0, 20.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 4.0
		rank.range = 155.0
		rank.power = powers[index]
		rank.physical_weight = 1.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_dash_ranks() -> void:
	var definition: SkillDefinition = _skills[&"dash"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.DASH
	var cooldowns: Array[float] = [6.0, 5.7, 5.4, 5.1, 4.8]
	for index: int in cooldowns.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = 20.0
		rank.cooldown = cooldowns[index]
		rank.range = 270.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_shield_wall_ranks() -> void:
	var definition: SkillDefinition = _skills[&"shield_wall"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.SHIELD_WALL
	var capacities: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in capacities.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 12.0
		rank.range = 34.0
		rank.power = capacities[index]
		rank.effect_ids = [&"front_projectile_block", &"front_damage_reduction"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_provoke_ranks() -> void:
	var definition: SkillDefinition = _skills[&"provoke"]
	definition.handler_id = SkillDefinition.Handler.PROVOKE
	var durations: Array[float] = [2.0, 2.4, 2.8, 3.2, 3.6]
	var costs: Array[float] = [14.0, 16.0, 18.0, 19.0, 20.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 10.0
		rank.range = 300.0
		rank.power = durations[index]
		rank.effect_ids = [&"taunt", &"physical_defense_reduction", &"flee_reduction"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_perseverance_ranks() -> void:
	var definition: SkillDefinition = _skills[&"perseverance"]
	definition.handler_id = SkillDefinition.Handler.PERSEVERANCE
	var bases: Array[float] = [40.0, 55.0, 68.0, 80.0, 90.0]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in bases.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 10.0
		rank.power = bases[index]
		rank.effect_ids = [&"personal_shield"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_piercing_shout_ranks() -> void:
	var definition: SkillDefinition = _skills[&"piercing_shout"]
	definition.handler_id = SkillDefinition.Handler.PIERCING_SHOUT
	var durations: Array[float] = [1.5, 1.9, 2.2, 2.4, 2.5]
	var costs: Array[float] = [17.0, 19.0, 21.0, 22.0, 23.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 8.0
		rank.range = 140.0
		rank.power = durations[index]
		rank.physical_weight = 1.0
		rank.effect_ids = [&"slow", &"attack_speed_reduction"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_fury_ranks() -> void:
	var definition: SkillDefinition = _skills[&"fury"]
	definition.handler_id = SkillDefinition.Handler.FURY
	var bonuses: Array[float] = [0.30, 0.38, 0.45, 0.51, 0.56]
	var costs: Array[float] = [22.0, 24.0, 26.0, 27.0, 28.0]
	for index: int in bonuses.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 14.0
		rank.power = bonuses[index]
		rank.effect_ids = [&"melee_attack_increase", &"attack_speed_increase", &"defense_penalty"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_brutal_strike_ranks() -> void:
	var definition: SkillDefinition = _skills[&"brutal_strike"]
	definition.handler_id = SkillDefinition.Handler.BRUTAL_STRIKE
	var powers: Array[float] = [2.20, 2.55, 2.85, 3.10, 3.30]
	var costs: Array[float] = [20.0, 23.0, 25.0, 27.0, 28.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.55
		rank.cooldown = 8.0
		rank.range = 110.0
		rank.power = powers[index]
		rank.physical_weight = 1.0
		rank.effect_ids = [&"physical_defense_reduction"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_concentrated_rage_ranks() -> void:
	var definition: SkillDefinition = _skills[&"concentrated_rage"]
	definition.handler_id = SkillDefinition.Handler.CONCENTRATED_RAGE
	var powers: Array[float] = [1.45, 1.65, 1.83, 1.99, 2.12]
	var costs: Array[float] = [19.0, 21.0, 23.0, 24.0, 25.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.35
		rank.cooldown = 7.5
		rank.range = 230.0
		rank.power = powers[index]
		rank.physical_weight = 1.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_terrifying_shout_ranks() -> void:
	var definition: SkillDefinition = _skills[&"terrifying_shout"]
	definition.handler_id = SkillDefinition.Handler.TERRIFYING_SHOUT
	var durations: Array[float] = [0.75, 0.90, 1.00, 1.10, 1.15]
	var costs: Array[float] = [20.0, 22.0, 24.0, 25.0, 26.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 11.0
		rank.range = 170.0
		rank.power = durations[index]
		rank.effect_ids = [&"fear", &"damage_received_increase"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_swordsman_resistance_ranks() -> void:
	var definition: SkillDefinition = _skills[&"swordsman_resistance"]
	definition.handler_id = SkillDefinition.Handler.SWORDSMAN_RESISTANCE
	var defense_increases: Array[float] = [0.50, 0.75, 1.00]
	for index: int in defense_increases.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = defense_increases[index]
		rank.effect_ids = [&"physical_defense_increased"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_fireball_ranks() -> void:
	var definition: SkillDefinition = _skills[&"fireball"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.FIREBALL
	var powers: Array[float] = [1.80, 2.05, 2.30, 2.55, 2.80]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.32
		rank.cooldown = 2.5
		rank.range = 700.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.projectile_speed = 680.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_fire_wall_ranks() -> void:
	var definition: SkillDefinition = _skills[&"fire_wall"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.FIRE_WALL
	var powers: Array[float] = [0.30, 0.34, 0.38, 0.42, 0.46]
	var costs: Array[float] = [24.0, 27.0, 29.0, 30.0, 32.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.48
		rank.cooldown = 7.0
		rank.range = 180.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.effect_ids = [&"burn"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_fire_spear_ranks() -> void:
	var definition: SkillDefinition = _skills[&"fire_spear"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.SPEAR
	var powers: Array[float] = [1.35, 1.55, 1.75, 1.95, 2.15]
	var costs: Array[float] = [16.0, 18.0, 19.0, 20.0, 21.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.22
		rank.cooldown = 3.0
		rank.range = 360.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.projectile_speed = 760.0
		rank.effect_ids = [&"burning_target_bonus"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_ice_spear_ranks() -> void:
	var definition: SkillDefinition = _skills[&"ice_spear"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.SPEAR
	var powers: Array[float] = [1.10, 1.25, 1.40, 1.55, 1.70]
	var costs: Array[float] = [14.0, 15.0, 16.0, 17.0, 18.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.22
		rank.cooldown = 3.0
		rank.range = 360.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.projectile_speed = 760.0
		rank.effect_ids = [&"slow"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_vigor_ranks() -> void:
	var definition: SkillDefinition = _skills[&"vigor"]
	definition.handler_id = SkillDefinition.Handler.VIGOR
	var bonuses: Array[float] = [0.50, 0.80, 1.10]
	for index: int in bonuses.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = bonuses[index]
		rank.effect_ids = [&"hp_regeneration_increase"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_blood_thirst_ranks() -> void:
	var definition: SkillDefinition = _skills[&"blood_thirst"]
	definition.handler_id = SkillDefinition.Handler.BLOOD_THIRST
	var ratios: Array[float] = [0.60, 0.90, 1.20]
	for index: int in ratios.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = ratios[index]
		rank.effect_ids = [&"invested_vit_melee_attack", &"kill_heal"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_lightning_ranks() -> void:
	var definition: SkillDefinition = _skills[&"lightning"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.LIGHTNING
	var powers: Array[float] = [1.25, 1.43, 1.60, 1.75, 1.90]
	var costs: Array[float] = [16.0, 18.0, 20.0, 21.0, 22.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.26
		rank.cooldown = 4.0
		rank.range = 380.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.projectile_speed = 820.0
		rank.effect_ids = [&"electrified"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_electric_discharge_ranks() -> void:
	var definition: SkillDefinition = _skills[&"electric_discharge"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.ELECTRIC_DISCHARGE
	var powers: Array[float] = [1.10, 1.28, 1.44, 1.58, 1.70]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.30
		rank.cooldown = 5.0
		rank.range = 560.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.projectile_speed = 800.0
		rank.effect_ids = [&"electrified_detonation"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_lightning_wall_ranks() -> void:
	var definition: SkillDefinition = _skills[&"lightning_wall"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.LIGHTNING_WALL
	var powers: Array[float] = [0.50, 0.60, 0.69, 0.77, 0.84]
	var costs: Array[float] = [22.0, 24.0, 26.0, 27.0, 28.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.38
		rank.cooldown = 8.0
		rank.range = 220.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.effect_ids = [&"electrified"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_soul_impact_ranks() -> void:
	var definition: SkillDefinition = _skills[&"soul_impact"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.SOUL_IMPACT
	var powers: Array[float] = [1.35, 1.58, 1.78, 1.95, 2.10]
	var costs: Array[float] = [19.0, 21.0, 23.0, 24.0, 25.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.36
		rank.cooldown = 6.0
		rank.range = 400.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_haunt_ranks() -> void:
	var definition: SkillDefinition = _skills[&"haunt"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.HAUNT
	var powers: Array[float] = [0.35, 0.43, 0.50, 0.56, 0.61]
	var costs: Array[float] = [18.0, 20.0, 21.0, 22.0, 23.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.40
		rank.cooldown = 9.0
		rank.range = 230.0
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.effect_ids = [&"fear", &"weaken"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_phantom_barrier_ranks() -> void:
	var definition: SkillDefinition = _skills[&"phantom_barrier"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.PHANTOM_BARRIER
	var capacities: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0]
	var costs: Array[float] = [20.0, 22.0, 24.0, 25.0, 26.0]
	for index: int in capacities.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.42
		rank.cooldown = 10.0
		rank.range = 210.0
		rank.power = capacities[index]
		rank.effect_ids = [&"projectile_intercept", &"slow", &"weaken"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_ice_wall_ranks() -> void:
	var definition: SkillDefinition = _skills[&"ice_wall"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.ICE_WALL
	var durations: Array[float] = [3.0, 3.6, 4.1, 4.5, 4.8]
	var costs: Array[float] = [22.0, 24.0, 26.0, 27.0, 28.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.variable_cast_time = 0.45
		rank.cooldown = 9.0
		rank.range = 200.0
		rank.power = durations[index]
		rank.effect_ids = [&"solid_obstacle"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_teleport_ranks() -> void:
	var definition: SkillDefinition = _skills[&"teleport"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.TELEPORT
	var cooldowns: Array[float] = [6.0, 5.7, 5.4, 5.1, 4.8]
	for index: int in cooldowns.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = 22.0
		rank.cooldown = cooldowns[index]
		rank.range = 320.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_mage_sp_regeneration_ranks() -> void:
	var definition: SkillDefinition = _skills[&"mage_mana_regeneration"]
	definition.handler_id = SkillDefinition.Handler.MAGE_SP_REGENERATION
	var regeneration_increases: Array[float] = [0.50, 0.75, 1.00]
	for index: int in regeneration_increases.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = regeneration_increases[index]
		rank.effect_ids = [&"sp_regen_increased"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_double_shot_ranks() -> void:
	var definition: SkillDefinition = _skills[&"double_shot"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.DOUBLE_SHOT
	var powers: Array[float] = [0.70, 0.80, 0.90, 1.00, 1.10]
	var costs: Array[float] = [14.0, 16.0, 17.0, 18.0, 19.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 4.0
		rank.range = 520.0
		rank.power = powers[index]
		rank.precision_weight = 1.0
		rank.projectile_speed = 880.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_piercing_arrow_ranks() -> void:
	var definition: SkillDefinition = _skills[&"piercing_arrow"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.PIERCING_ARROW
	var powers: Array[float] = [1.05, 1.20, 1.35, 1.50, 1.65]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 5.0
		rank.range = 600.0
		rank.power = powers[index]
		rank.precision_weight = 1.0
		rank.projectile_speed = 920.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_arrow_rain_ranks() -> void:
	var definition: SkillDefinition = _skills[&"arrow_rain"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.ARROW_RAIN
	var powers: Array[float] = [1.80, 2.10, 2.40, 2.70, 3.00]
	var costs: Array[float] = [22.0, 24.0, 26.0, 28.0, 30.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 7.0
		rank.range = 480.0
		rank.power = powers[index]
		rank.precision_weight = 1.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_extended_aim_ranks() -> void:
	var definition: SkillDefinition = _skills[&"extended_aim"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.EXTENDED_AIM
	var durations: Array[float] = [4.0, 5.0, 6.0, 7.0, 8.0]
	var costs: Array[float] = [16.0, 17.0, 18.0, 19.0, 20.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 12.0
		rank.power = durations[index]
		rank.effect_ids = [&"extended_aim"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_snare_trap_ranks() -> void:
	var definition: SkillDefinition = _skills[&"snare_trap"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.SNARE_TRAP
	var durations: Array[float] = [1.4, 1.8, 2.2, 2.6, 3.0]
	var costs: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 8.0
		rank.range = 360.0
		rank.power = durations[index]
		rank.effect_ids = [&"physical_root"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_explosive_trap_ranks() -> void:
	var definition: SkillDefinition = _skills[&"explosive_trap"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.EXPLOSIVE_TRAP
	var powers: Array[float] = [1.35, 1.60, 1.85, 2.10, 2.35]
	var costs: Array[float] = [20.0, 22.0, 24.0, 26.0, 28.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 9.0
		rank.range = 360.0
		rank.power = powers[index]
		rank.precision_weight = 1.0
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_slowing_arrow_ranks() -> void:
	var definition: SkillDefinition = _skills[&"slowing_arrow"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.SLOWING_ARROW
	var durations: Array[float] = [1.4, 1.8, 2.2, 2.6, 3.0]
	var costs: Array[float] = [15.0, 16.0, 17.0, 18.0, 19.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 5.0
		rank.range = 560.0
		# This skill's rank axis is control duration; direct damage stays at definition.power.
		rank.power = durations[index]
		rank.precision_weight = 1.0
		rank.projectile_speed = 880.0
		rank.effect_ids = [&"slow"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_foliage_shelter_ranks() -> void:
	var definition: SkillDefinition = _skills[&"foliage_shelter"]
	definition.category = SkillDefinition.Category.ACTIVE
	definition.handler_id = SkillDefinition.Handler.FOLIAGE_SHELTER
	var durations: Array[float] = [4.0, 5.0, 6.0, 7.0, 8.0]
	var costs: Array[float] = [18.0, 19.0, 20.0, 21.0, 22.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 12.0
		rank.range = 360.0
		rank.power = durations[index]
		rank.effect_ids = [&"concealment_area"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_archer_precision_ranks() -> void:
	var definition: SkillDefinition = _skills[&"archer_precision"]
	definition.handler_id = SkillDefinition.Handler.ARCHER_PRECISION
	var hit_bonuses: Array[float] = [8.0, 12.0, 16.0]
	for index: int in hit_bonuses.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = hit_bonuses[index]
		rank.effect_ids = [&"hit_rating_flat"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_archer_cadence_ranks() -> void:
	var definition: SkillDefinition = _skills[&"archer_cadence"]
	definition.handler_id = SkillDefinition.Handler.ARCHER_CADENCE
	var cadence_increases: Array[float] = [0.10, 0.15, 0.20]
	for index: int in cadence_increases.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = cadence_increases[index]
		rank.effect_ids = [&"attacks_per_second_increased"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_trap_technique_ranks() -> void:
	var definition: SkillDefinition = _skills[&"trap_technique"]
	definition.handler_id = SkillDefinition.Handler.TRAP_TECHNIQUE
	var armed_duration_bonuses: Array[float] = [3.0, 6.0, 9.0]
	for index: int in armed_duration_bonuses.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = armed_duration_bonuses[index]
		rank.effect_ids = [&"trap_armed_duration_flat"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_defender_counterstroke_ranks() -> void:
	var definition: SkillDefinition = _skills[&"defender_counterstroke"]
	definition.handler_id = SkillDefinition.Handler.DEFENDER_COUNTERSTROKE
	var powers: Array[float] = [1.05, 1.25, 1.42, 1.56, 1.68]
	var token_bonuses: Array[float] = [0.30, 0.40, 0.50, 0.60, 0.70]
	var costs: Array[float] = [16.0, 18.0, 20.0, 21.0, 22.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 6.0
		rank.range = 120.0
		rank.power = powers[index]
		rank.secondary_power = token_bonuses[index]
		rank.physical_weight = 1.0
		rank.effect_ids = [&"direct_damage", &"front_guard_1_2s_15pct_130deg", &"guard_token_on_valid_front_event", &"consume_guard_token", &"damage_cone_90deg_120"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_defender_watch_ranks() -> void:
	var definition: SkillDefinition = _skills[&"defender_watch"]
	definition.handler_id = SkillDefinition.Handler.DEFENDER_WATCH
	var reductions: Array[float] = [0.08, 0.11, 0.14]
	for index: int in reductions.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = reductions[index]
		rank.effect_ids = [&"direct_melee_damage_dealt_reduction"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_defender_anchor_ranks() -> void:
	var definition: SkillDefinition = _skills[&"defender_anchor"]
	definition.handler_id = SkillDefinition.Handler.DEFENDER_ANCHOR
	var durations: Array[float] = [4.0, 4.5, 5.0, 5.5, 6.0]
	var costs: Array[float] = [20.0, 22.0, 24.0, 25.0, 26.0]
	for index: int in durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 12.0
		rank.range = 150.0
		rank.power = durations[index]
		rank.effect_ids = [&"anchor_radius_100", &"defense_increased_physical_and_magic_10pct", &"enemy_slow_20pct"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_defender_line_lock_ranks() -> void:
	var definition: SkillDefinition = _skills[&"defender_line_lock"]
	definition.handler_id = SkillDefinition.Handler.DEFENDER_LINE_LOCK
	var root_durations: Array[float] = [0.5, 0.6, 0.7, 0.8, 0.9]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in root_durations.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 9.0
		rank.range = 170.0
		rank.power = 0.70
		rank.secondary_power = root_durations[index]
		rank.physical_weight = 1.0
		rank.effect_ids = [&"direct_damage", &"line_width_44", &"physical_root_after_positive_damage", &"boss_cc_budget"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_defender_guard_return_ranks() -> void:
	var definition: SkillDefinition = _skills[&"defender_guard_return"]
	definition.handler_id = SkillDefinition.Handler.DEFENDER_GUARD_RETURN
	var sp_returns: Array[float] = [2.0, 3.0, 4.0]
	for index: int in sp_returns.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = sp_returns[index]
		rank.cooldown = 2.0
		rank.effect_ids = [&"equipped_passive_front_guard_event_sp_return"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_defender_wall_advance_ranks() -> void:
	var definition: SkillDefinition = _skills[&"defender_wall_advance"]
	definition.handler_id = SkillDefinition.Handler.DEFENDER_WALL_ADVANCE
	var distances: Array[float] = [80.0, 95.0, 110.0, 120.0, 130.0]
	var costs: Array[float] = [22.0, 24.0, 26.0, 27.0, 28.0]
	for index: int in distances.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 10.0
		rank.range = distances[index]
		rank.power = 0.80
		rank.physical_weight = 1.0
		rank.effect_ids = [&"direct_damage_0_80_atk_body_one_target_per_path", &"front_guard_130deg_mitigation_20pct_during_displacement", &"normal_enemy_push_35", &"navigation_validate_segment", &"end_shield_wall"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_defender_reprisal_wave_ranks() -> void:
	var definition: SkillDefinition = _skills[&"defender_reprisal_wave"]
	definition.handler_id = SkillDefinition.Handler.DEFENDER_REPRISAL_WAVE
	var powers: Array[float] = [0.60, 0.73, 0.84, 0.93, 1.00]
	var costs: Array[float] = [24.0, 26.0, 28.0, 29.0, 30.0]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 12.0
		rank.range = 130.0
		rank.power = powers[index]
		rank.secondary_power = 0.35
		rank.physical_weight = 1.0
		rank.effect_ids = [&"direct_area_pulse_radius_130", &"consume_guard_token_for_bonus_0_35_atk_body_and_normal_knockback_35", &"boss_damage_without_displacement"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_berserker_ranks() -> void:
	_skills[&"berserker_rupture"].handler_id = SkillDefinition.Handler.BERSERKER_RUPTURE
	_berserker_active_ranks(&"berserker_rupture", [17.0, 19.0, 21.0, 22.0, 23.0], [1.00, 1.12, 1.22, 1.31, 1.38], [0.40, 0.52, 0.63, 0.72, 0.80], 110.0, 5.0, 0.0, [&"direct_melee_first_activation", &"wound_max_three_eight_seconds", &"secondary_contested_detonation"])
	_skills[&"berserker_obstinacy"].handler_id = SkillDefinition.Handler.BERSERKER_OBSTINACY
	_berserker_passive_ranks(&"berserker_obstinacy", [0.08, 0.11, 0.14], [&"low_hp_direct_melee_bonus"])
	_skills[&"berserker_wound_leap"].handler_id = SkillDefinition.Handler.BERSERKER_WOUND_LEAP
	_berserker_active_ranks(&"berserker_wound_leap", [18.0, 20.0, 22.0, 23.0, 24.0], [0.80, 0.96, 1.08, 1.17, 1.24], [], 140.0, 8.0, 0.0, [&"offensive_mobility_safe_segment", &"direct_melee_one_target"])
	_skills[&"berserker_execution"].handler_id = SkillDefinition.Handler.BERSERKER_EXECUTION
	_berserker_active_ranks(&"berserker_execution", [22.0, 25.0, 27.0, 29.0, 30.0], [1.20, 1.40, 1.60, 1.75, 1.90], [0.40, 0.40, 0.40, 0.40, 0.40], 110.0, 9.0, 0.0, [&"nonlethal_hp_cost_three_percent", &"consume_existing_wound_on_positive_damage", &"target_hp_at_most_35pct_bonus_20pct"])
	_skills[&"berserker_pursuit"].handler_id = SkillDefinition.Handler.BERSERKER_PURSUIT
	_berserker_passive_ranks(&"berserker_pursuit", [2.0, 3.0, 4.0], [&"wounded_direct_melee_sp_return_once_per_second"])
	_skills[&"berserker_blood_rift"].handler_id = SkillDefinition.Handler.BERSERKER_BLOOD_RIFT
	_berserker_active_ranks(&"berserker_blood_rift", [21.0, 23.0, 25.0, 26.0, 27.0], [0.90, 0.90, 0.90, 0.90, 0.90], [0.10, 0.12, 0.14, 0.16, 0.18], 220.0, 9.0, 0.3, [&"directional_strip_width_44", &"direct_damage", &"secondary_bleed_four_seconds"])
	_skills[&"berserker_breath_steal"].handler_id = SkillDefinition.Handler.BERSERKER_BREATH_STEAL
	_berserker_active_ranks(&"berserker_breath_steal", [18.0, 20.0, 22.0, 23.0, 24.0], [1.00, 1.08, 1.16, 1.23, 1.30], [0.15, 0.18, 0.21, 0.24, 0.27], 110.0, 12.0, 0.0, [&"direct_melee", &"heal_if_previously_wounded_and_survives_cap_five_percent_max_hp"])

static func _configure_elementalist_ranks() -> void:
	_elementalist_active_ranks(&"elementalist_flame_burst", SkillDefinition.Handler.ELEMENTALIST_FLAME_BURST, [20.0, 22.0, 24.0, 25.0, 26.0], [1.30, 1.50, 1.67, 1.82, 1.95], 380.0, 6.0, 0.45, [&"direct_magic_damage"])
	_elementalist_passive_ranks(&"elementalist_prismatic_focus", SkillDefinition.Handler.ELEMENTALIST_PRISMATIC_FOCUS, [2.0, 3.0, 4.0], [&"two_direct_distinct_elements_within_five_seconds_sp_return_once_per_second"])
	_elementalist_active_ranks(&"elementalist_glacial_ring", SkillDefinition.Handler.ELEMENTALIST_GLACIAL_RING, [19.0, 21.0, 23.0, 24.0, 25.0], [0.90, 1.05, 1.18, 1.29, 1.38], 145.0, 8.0, 0.35, [&"direct_magic_damage", &"slow_40pct_2_5s_after_positive_damage"])
	_elementalist_active_ranks(&"elementalist_lightning_arc", SkillDefinition.Handler.ELEMENTALIST_LIGHTNING_ARC, [22.0, 24.0, 26.0, 27.0, 28.0], [1.10, 1.25, 1.38, 1.49, 1.58], 380.0, 8.0, 0.35, [&"direct_magic_damage", &"chain_up_to_two_targets_110_no_repeat", &"chain_jump_power_0_60", &"marked_target_bonus_secondary_power", &"electric_mark_and_stun_rule"] , 0.40)
	_elementalist_passive_ranks(&"elementalist_prismatic_resonance", SkillDefinition.Handler.ELEMENTALIST_PRISMATIC_RESONANCE, [0.25, 0.35, 0.45], [&"three_direct_distinct_elements_within_six_seconds_third_hit_bonus_before_mitigation"])
	_elementalist_active_ranks(&"elementalist_ember_path", SkillDefinition.Handler.ELEMENTALIST_EMBER_PATH, [24.0, 26.0, 28.0, 29.0, 30.0], [1.10, 1.25, 1.38, 1.49, 1.58], 240.0, 10.0, 0.50, [&"three_eruptions_at_80_160_240", &"direct_magic_damage_once_per_target_emission"])
	_elementalist_active_ranks(&"elementalist_tri_nova", SkillDefinition.Handler.ELEMENTALIST_TRI_NOVA, [30.0, 32.0, 34.0, 35.0, 36.0], [0.70, 0.80, 0.88, 0.95, 1.01], 170.0, 16.0, 0.65, [&"three_pulses_fire_ice_lightning_at_0_0_25_0_50", &"ice_pulse_0_55_slow", &"lightning_pulse_0_60_electrified", &"root_only_first_pulse"] , 0.55)

static func _configure_geometer_trace_ranks() -> void:
	var incidence: SkillDefinition = _skills[&"geometer_incidence"]
	incidence.handler_id = SkillDefinition.Handler.GEOMETER_INCIDENCE
	for index: int in range(3):
		var passive := SkillRankDefinition.new()
		passive.rank = index + 1
		passive.power = 0.10 + 0.05 * index
		passive.secondary_power = 2.0 + index
		passive.effect_ids = [&"actual_wall_interaction_bonus", &"hostile_interception_sp_refund_two_seconds"]
		incidence.ranks.append(passive)
	assert(incidence.is_rank_catalog_valid())
	for skill_id: StringName in [&"geometer_trace", &"geometer_triangulation"]:
		var definition: SkillDefinition = _skills[skill_id]
		definition.handler_id = SkillDefinition.Handler.GEOMETER_TRACE if skill_id == &"geometer_trace" else SkillDefinition.Handler.GEOMETER_TRIANGULATION
		for index: int in range(5):
			var rank := SkillRankDefinition.new()
			rank.rank = index + 1
			rank.sp_cost = definition.sp_cost
			rank.cooldown = definition.cooldown
			rank.range = definition.range
			rank.projectile_speed = definition.projectile_speed
			rank.variable_cast_time = definition.cast_time
			# Third shot carries grammar only; resolution damage belongs to G5.
			rank.power = 0.30 + 0.05 * index if skill_id == &"geometer_trace" else 0.0
			rank.magic_weight = 1.0
			rank.effect_ids = [&"explicit_ground_or_actor_anchor", &"ordered_frozen_element_delivery"]
			definition.ranks.append(rank)
		assert(definition.is_rank_catalog_valid())

static func _configure_geometer_edit_ranks() -> void:
	var memory: SkillDefinition = _skills[&"geometer_vector_memory"]
	memory.handler_id = SkillDefinition.Handler.GEOMETER_VECTOR_MEMORY
	for index: int in range(3):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = [1.0, 2.0, 4.0][index]
		rank.secondary_power = index + 1.0
		rank.effect_ids = [&"new_vertex_duration_bonus", &"new_figure_duration_bonus_capped_twelve"]
		memory.ranks.append(rank)
	assert(memory.is_rank_catalog_valid())
	var handlers := {&"geometer_translation": SkillDefinition.Handler.GEOMETER_TRANSLATION, &"geometer_rewrite": SkillDefinition.Handler.GEOMETER_REWRITE, &"geometer_collapse": SkillDefinition.Handler.GEOMETER_COLLAPSE}
	for skill: StringName in handlers:
		var definition: SkillDefinition = _skills[skill]
		definition.handler_id = handlers[skill]
		for index: int in range(5):
			var rank := SkillRankDefinition.new()
			rank.rank = index + 1
			rank.sp_cost = definition.sp_cost
			rank.cooldown = definition.cooldown - (0.25 * index if skill != &"geometer_collapse" else 0.0)
			rank.range = definition.range
			rank.magic_weight = 1.0
			rank.power = 0.60 + 0.10 * index if skill == &"geometer_collapse" else 0.0
			rank.effect_ids.assign([&"consume_current_figure_once"] if skill == &"geometer_collapse" else [&"atomic_explicit_anchor_edit", &"preserve_instance_and_figure_deadline"])
			definition.ranks.append(rank)
		assert(definition.is_rank_catalog_valid())

static func geometer_collapse_tuning(rank: int) -> Dictionary:
	# Initial tuning: independent rank/MAG at explicit collapse, never stored C damage.
	if rank < 1 or rank > 5:
		return {}
	return {&"wall": 0.60 + 0.10 * (rank - 1), &"fire": 0.80 + 0.10 * (rank - 1), &"ice": 0.30 + 0.05 * (rank - 1), &"lightning": 0.60 + 0.10 * (rank - 1)}

static func geometer_wall_tuning(rank: int) -> Dictionary:
	if rank < 1 or rank > 5:
		return {}
	return {"entry_power": 0.35 + 0.05 * (rank - 1), "exit_power": 0.30 + 0.05 * (rank - 1), "slow_fraction": 0.20 + 0.025 * (rank - 1)}

static func geometer_triangle_tuning(rank: int) -> Dictionary:
	if rank < 1 or rank > 5:
		return {}
	var step := rank - 1
	return {&"foundation_fire": 0.12 + 0.02 * step, &"rule_fire": 0.18 + 0.03 * step,
		&"foundation_lightning": 0.12 + 0.02 * step, &"rule_lightning": 0.20 + 0.0375 * step,
		&"resolution_fire": 0.80 + 0.10 * step, &"resolution_ice": 0.30 + 0.05 * step,
		&"resolution_lightning": 0.60 + 0.10 * step}

static func geometer_triangle_description(elements: Array[StringName]) -> String:
	if GeometerGeometry.triangle_rank(elements) == 0:
		return "Confirme dois vértices e selecione Triangulação para lançar o terceiro."
	var foundations := {&"fire": "Brasas: dano a ocupantes a cada 1s.", &"ice": "Geada: slow de 10%; residual de 0,6s.", &"lightning": "Condutor: componente mágico no próximo impacto de projétil próprio na área."}
	var rules := {&"fire": "Pulso: dano a ocupantes a cada 1s, somado às brasas.", &"ice": "Lento: slow de 20%; não soma com Geada.", &"lightning": "Condução: próximo impacto na área emite um arco para outro ocupante a até 110."}
	var resolutions := {&"fire": "Explosão: dano à área uma vez no fechamento.", &"ice": "Contenção: dano e root mágico curto no fechamento, limitado pela resistência do boss.", &"lightning": "Descarga: até três ocupantes únicos, por elos de até 110, no fechamento."}
	return "Fundação — %s\nRegra — %s\nResolução — %s\nRequer Triangulação R%d. Sem efeitos de parede; alvos exigem área e visão." % [foundations[elements[0]], rules[elements[1]], resolutions[elements[2]], GeometerGeometry.triangle_rank(elements)]

static func _configure_spiritualist_curse_ranks() -> void:
	var definition: SkillDefinition = _skills[&"spiritualist_echo_curse"]
	definition.handler_id = SkillDefinition.Handler.SPIRITUALIST_ECHO_CURSE
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	var powers: Array[float] = [0.85, 1.00, 1.12, 1.22, 1.30]
	var echoes: Array[float] = [0.35, 0.42, 0.49, 0.55, 0.60]
	for index: int in range(powers.size()):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 6.0
		rank.range = 380.0
		rank.variable_cast_time = 0.35
		rank.power = powers[index]
		rank.secondary_power = echoes[index]
		rank.magic_weight = 1.0
		rank.effect_ids = [&"direct_magic_damage", &"mark_target_and_neighbors_radius_110_five_seconds", &"direct_skill_on_existing_mark_starts_finite_echo_wave_after_0_35s"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_spiritualist_recovery_ranks() -> void:
	var definition: SkillDefinition = _skills[&"spiritualist_echo_recovery"]
	definition.handler_id = SkillDefinition.Handler.SPIRITUALIST_ECHO_RECOVERY
	var refunds: Array[float] = [2.0, 3.0, 4.0]
	for index: int in range(refunds.size()):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = refunds[index]
		rank.effect_ids = [&"echo_trigger_sp_refund_once_per_emission_and_second"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_spiritualist_drain_ranks() -> void:
	var definition: SkillDefinition = _skills[&"spiritualist_soul_drain"]
	definition.handler_id = SkillDefinition.Handler.SPIRITUALIST_SOUL_DRAIN
	var costs: Array[float] = [22.0, 24.0, 26.0, 28.0, 30.0]
	var powers: Array[float] = [0.36, 0.42, 0.48, 0.54, 0.60]
	for index: int in range(powers.size()):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 10.0
		rank.range = 350.0
		rank.variable_cast_time = 0.30
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.effect_ids = [&"four_ticks_each_half_second", &"heal_fifteen_percent_actual_hp_damage_capped_five_percent_caster_max_hp", &"interrupt_on_movement_cast_control_damage_or_death"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_spiritualist_veil_ranks() -> void:
	var definition: SkillDefinition = _skills[&"spiritualist_spectral_veil"]
	definition.handler_id = SkillDefinition.Handler.SPIRITUALIST_SPECTRAL_VEIL
	var costs: Array[float] = [20.0, 22.0, 24.0, 25.0, 26.0]
	var durations: Array[float] = [3.0, 3.5, 4.0, 4.5, 5.0]
	for index: int in range(durations.size()):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 12.0
		rank.range = 250.0
		rank.variable_cast_time = 0.25
		rank.power = 0.15
		rank.secondary_power = durations[index]
		rank.effect_ids = [&"ground_radius_110", &"one_zone_per_caster_replaces", &"damage_dealt_reduction_same_channel_as_dissipation"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_spiritualist_focus_ranks() -> void:
	var definition: SkillDefinition = _skills[&"spiritualist_channel_focus"]
	definition.handler_id = SkillDefinition.Handler.SPIRITUALIST_CHANNEL_FOCUS
	var bonuses: Array[float] = [0.20, 0.30, 0.40]
	for index: int in range(bonuses.size()):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = bonuses[index]
		rank.effect_ids = [&"four_valid_drain_ticks_grant_one_charge_five_seconds", &"next_valid_curse_or_dissipation_root_bonus"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_spiritualist_procession_ranks() -> void:
	var definition: SkillDefinition = _skills[&"spiritualist_procession"]
	definition.handler_id = SkillDefinition.Handler.SPIRITUALIST_PROCESSION
	var costs: Array[float] = [24.0, 26.0, 28.0, 29.0, 30.0]
	var powers: Array[float] = [0.45, 0.50, 0.55, 0.60, 0.65]
	for index: int in range(powers.size()):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 10.0
		rank.range = 380.0
		rank.variable_cast_time = 0.40
		rank.power = powers[index]
		rank.magic_weight = 1.0
		rank.effect_ids = [&"three_apparitions_depart_0_0_20_0_40", &"impacts_after_0_22s", &"root_only_first_impact", &"cancel_on_invalid_target_or_line"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _configure_spiritualist_dissipation_ranks() -> void:
	var definition: SkillDefinition = _skills[&"spiritualist_dissipation"]
	definition.handler_id = SkillDefinition.Handler.SPIRITUALIST_DISSIPATION
	var costs: Array[float] = [27.0, 29.0, 31.0, 32.0, 33.0]
	var powers: Array[float] = [0.85, 1.00, 1.12, 1.23, 1.32]
	for index: int in range(powers.size()):
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = 14.0
		rank.range = 330.0
		rank.variable_cast_time = 0.60
		rank.power = powers[index]
		rank.secondary_power = 0.55
		rank.magic_weight = 1.0
		rank.effect_ids = [&"point_radius_100_root_direct", &"marked_target_add_0_55_atqm_same_request", &"positive_direct_hit_on_mark_starts_echo_wave", &"weaken_damage_dealt_20pct_2s_after_positive_damage"]
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _elementalist_active_ranks(skill_id: StringName, handler: SkillDefinition.Handler, costs: Array[float], powers: Array[float], skill_range: float, cooldown: float, variable_cast: float, effects: Array[StringName], secondary_power: float = 0.0) -> void:
	var definition: SkillDefinition = _skills[skill_id]
	definition.handler_id = handler
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = cooldown
		rank.range = skill_range
		rank.variable_cast_time = variable_cast
		rank.power = powers[index]
		rank.secondary_power = secondary_power
		rank.magic_weight = 1.0
		rank.effect_ids = effects.duplicate()
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _elementalist_passive_ranks(skill_id: StringName, handler: SkillDefinition.Handler, powers: Array[float], effects: Array[StringName]) -> void:
	var definition: SkillDefinition = _skills[skill_id]
	definition.handler_id = handler
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = powers[index]
		rank.effect_ids = effects.duplicate()
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _berserker_active_ranks(skill_id: StringName, costs: Array[float], powers: Array[float], secondary_powers: Array[float], skill_range: float, cooldown: float, variable_cast: float, effects: Array[StringName]) -> void:
	var definition: SkillDefinition = _skills[skill_id]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.sp_cost = costs[index]
		rank.cooldown = cooldown
		rank.range = skill_range
		rank.variable_cast_time = variable_cast
		rank.power = powers[index]
		rank.secondary_power = secondary_powers[index] if index < secondary_powers.size() else 0.0
		rank.physical_weight = 1.0
		rank.effect_ids = effects.duplicate()
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())

static func _berserker_passive_ranks(skill_id: StringName, powers: Array[float], effects: Array[StringName]) -> void:
	var definition: SkillDefinition = _skills[skill_id]
	for index: int in powers.size():
		var rank := SkillRankDefinition.new()
		rank.rank = index + 1
		rank.power = powers[index]
		rank.effect_ids = effects.duplicate()
		definition.ranks.append(rank)
	assert(definition.is_rank_catalog_valid())
