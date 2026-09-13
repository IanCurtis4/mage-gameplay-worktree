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
	_add_skill(&"slash", "Corte em cone", "Q", SkillDefinition.Targeting.DIRECTION, 15.0, 4.0, 1.45, 155.0)
	_add_skill(&"dash", "Investida", "W", SkillDefinition.Targeting.DIRECTION, 20.0, 6.0, 0.0, 270.0)
	_add_skill(&"fireball", "Bola de Fogo", "Q", SkillDefinition.Targeting.DIRECTION, 18.0, 2.5, 1.80, 700.0, 680.0, 0.32)
	_add_skill(&"fire_wall", "Parede de Fogo", "W", SkillDefinition.Targeting.DIRECTION, 24.0, 7.0, 0.30, 180.0, 0.0, 0.48)
	_add_skill(&"fire_spear", "Lança de Fogo", "A", SkillDefinition.Targeting.SINGLE_TARGET, 16.0, 3.0, 1.35, 360.0, 760.0, 0.22)
	_add_skill(&"ice_spear", "Lança de Gelo", "S", SkillDefinition.Targeting.SINGLE_TARGET, 14.0, 3.0, 1.10, 360.0, 760.0, 0.22)
	_add_skill(&"teleport", "Teleporte", "D", SkillDefinition.Targeting.POINT, 22.0, 6.0, 0.0, 320.0)

	var swordsman := ClassDefinition.new()
	swordsman.id = &"swordsman"
	swordsman.display_name = "Espadachim"
	swordsman.attributes = {"str": 8, "agi": 5, "vit": 8, "int": 2, "dex": 5, "luk": 2}
	swordsman.skill_ids = [&"slash", &"dash"]
	swordsman.passive_id = &"swordsman_resistance"
	swordsman.basic_kind = DamageRequest.Kind.PHYSICAL
	swordsman.basic_power = 1.0
	swordsman.basic_range = 50.0
	_classes[swordsman.id] = swordsman

	var mage := ClassDefinition.new()
	mage.id = &"mage"
	mage.display_name = "Mago"
	mage.attributes = {"str": 2, "agi": 5, "vit": 5, "int": 9, "dex": 7, "luk": 2}
	mage.skill_ids = [&"fireball", &"fire_wall", &"fire_spear", &"ice_spear", &"teleport"]
	mage.passive_id = &"mage_mana_regeneration"
	mage.basic_kind = DamageRequest.Kind.MAGIC
	mage.basic_power = 1.0
	mage.basic_range = 250.0
	_classes[mage.id] = mage

static func _add_skill(
	skill_id: StringName,
	display_name: String,
	input_key: String,
	targeting: SkillDefinition.Targeting,
	mana_cost: float,
	cooldown: float,
	power: float,
	range_value: float,
	projectile_speed: float = 0.0,
	cast_time: float = 0.0
) -> void:
	var definition := SkillDefinition.new()
	definition.id = skill_id
	definition.display_name = display_name
	definition.input_key = input_key
	definition.targeting = targeting
	definition.mana_cost = mana_cost
	definition.cooldown = cooldown
	definition.cast_time = cast_time
	definition.power = power
	definition.range = range_value
	definition.projectile_speed = projectile_speed
	_skills[skill_id] = definition
