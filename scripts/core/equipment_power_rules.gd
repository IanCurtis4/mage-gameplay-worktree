class_name EquipmentPowerRules
extends RefCounted
## Pure magnitude authority for immutable catalog recipes and acquired exemplars.

const RECIPE_REVISION: StringName = &"catalog_v1"
const LEGACY_RULESET: StringName = &"legacy_unscaled"
const GROWTH_RULESET: StringName = &"equipment_growth_v1"
const LEVEL_STEP := 0.04
const QUALITY_FACTORS := {&"common": 1.0, &"uncommon": 1.15, &"rare": 1.35, &"epic": 1.65, &"legendary": 2.0}
const PRIMARY_AXES: Array[StringName] = [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]
const FLAT_AXES: Array[StringName] = [&"max_hp", &"max_sp", &"hp_regen", &"sp_regen", &"melee_attack", &"precision_attack", &"magic_attack", &"physical_defense", &"magic_defense", &"hit_rating", &"flee_rating", &"move_speed"]

static func validate_instance(instance: EquipmentInstance) -> Dictionary:
	if instance == null or instance.item_level < 1 or instance.quality_id not in EquipmentRules.QUALITY_IDS:
		return BuildEffectCatalog.failure(&"invalid_equipment_instance")
	if instance.recipe_revision_id != RECIPE_REVISION or instance.power_ruleset_id not in [LEGACY_RULESET, GROWTH_RULESET]:
		return BuildEffectCatalog.failure(&"invalid_equipment_power")
	if instance.power_ruleset_id == GROWTH_RULESET and instance.item_level > 30:
		return BuildEffectCatalog.failure(&"invalid_equipment_power")
	return {"ok": true}

static func scales(effect: EffectDefinition) -> bool:
	return effect != null and effect.kind == EffectDefinition.Kind.STAT and ((effect.channel == &"primary_flat" and effect.axis in PRIMARY_AXES) or (effect.channel == &"flat" and effect.axis in FLAT_AXES))

static func modifier_magnitude(effect: EffectDefinition, instance: EquipmentInstance, definition: EquipmentDefinition) -> float:
	# Callers validate the exemplar before composition; there is no fallback for unknown rules.
	if effect == null or definition == null or not validate_instance(instance)["ok"]:
		return NAN
	var original := effect.value_at(1)
	if instance.power_ruleset_id == LEGACY_RULESET or not scales(effect):
		return original
	if definition.item_level < 1 or definition.item_level > 30 or not QUALITY_FACTORS.has(definition.quality_id):
		return NAN
	var level_factor := (1.0 + LEVEL_STEP * (instance.item_level - 1)) / (1.0 + LEVEL_STEP * (definition.item_level - 1))
	var quality_factor := float(QUALITY_FACTORS[instance.quality_id]) / float(QUALITY_FACTORS[definition.quality_id])
	return original * level_factor * quality_factor