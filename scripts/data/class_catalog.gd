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

static func passive_modifier_source(skill_id: StringName, rank: int) -> Dictionary:
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
	return {}

static func _ensure_built() -> void:
	if not _classes.is_empty():
		return
	_add_skill(&"slash", "Corte em cone", "Q", SkillDefinition.Targeting.DIRECTION, 15.0, 4.0, 1.45, 155.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"dash", "Investida", "W", SkillDefinition.Targeting.DIRECTION, 20.0, 6.0, 0.0, 270.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"fireball", "Bola de Fogo", "Q", SkillDefinition.Targeting.DIRECTION, 18.0, 2.5, 1.80, 700.0, 680.0, 0.32, DamageRequest.AccuracyMode.GEOMETRY, true)
	_add_skill(&"fire_wall", "Parede de Fogo", "W", SkillDefinition.Targeting.DIRECTION, 24.0, 7.0, 0.30, 180.0, 0.0, 0.48, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_skill(&"fire_spear", "Lança de Fogo", "A", SkillDefinition.Targeting.SINGLE_TARGET, 16.0, 3.0, 1.35, 360.0, 760.0, 0.22, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"ice_spear", "Lança de Gelo", "S", SkillDefinition.Targeting.SINGLE_TARGET, 14.0, 3.0, 1.10, 360.0, 760.0, 0.22, DamageRequest.AccuracyMode.CONTESTED, true)
	_add_skill(&"teleport", "Teleporte", "D", SkillDefinition.Targeting.POINT, 22.0, 6.0, 0.0, 320.0, 0.0, 0.0, DamageRequest.AccuracyMode.GEOMETRY, false)
	_add_passive_skill(&"swordsman_resistance", "Resistência")
	_add_passive_skill(&"mage_mana_regeneration", "Regeneração de SP")
	_configure_slash_ranks()
	_configure_dash_ranks()
	_configure_swordsman_resistance_ranks()
	_configure_fireball_ranks()
	_configure_fire_wall_ranks()
	_configure_fire_spear_ranks()
	_configure_ice_spear_ranks()
	_configure_teleport_ranks()
	_configure_mage_sp_regeneration_ranks()

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
	archer.skill_ids = []
	archer.passive_id = &""
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
	can_crit: bool = false
) -> void:
	var definition := SkillDefinition.new()
	definition.id = skill_id
	definition.display_name = display_name
	definition.input_key = input_key
	definition.targeting = targeting
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
