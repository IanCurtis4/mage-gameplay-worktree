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
	_configure_slash_ranks()
	_configure_dash_ranks()

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
