class_name EquipmentPresentation
extends RefCounted
## Visual metadata only; never contributes to recipe or acquisition records.
const SLOT_LABELS := {&"head": "Cabeça", &"neck": "Pescoço", &"shoulders": "Ombros", &"arms": "Braços", &"torso": "Tronco", &"cloak": "Capa", &"legs": "Calças", &"feet": "Pés", &"main_hand": "Mão principal", &"off_hand": "Mão secundária", &"accessory_1": "Acessório 1", &"accessory_2": "Acessório 2", &"accessory_3": "Acessório 3", &"accessory_4": "Acessório 4"}
const QUALITY_LABELS := {&"common": "Comum", &"uncommon": "Incomum", &"rare": "Raro", &"epic": "Épico", &"legendary": "Lendário"}
const OLD_NAMES := {&"starter_blade": "Espada inicial", &"starter_staff": "Cajado inicial", &"starter_bow": "Arco inicial", &"traveler_vest": "Colete de viagem", &"traveler_charm": "Berloque de viagem", &"riposte_blade": "Lâmina de réplica", &"ember_staff": "Cajado de brasas", &"hunters_bow": "Arco de caça", &"warden_mail": "Armadura da guarda", &"channeler_robe": "Manto do canalizador", &"trailcoat": "Casaco de trilha", &"prismatic_charm": "Berloque prismático"}
# Art patterns describe the icon's surface, not a mechanical armor subtype.
const SURFACES := {&"traveler_vest": "leather", &"arena_traveler_vest": "leather", &"warden_mail": "mail", &"arena_warden_mail": "mail", &"channeler_robe": "cloth", &"arena_channeler_robe": "cloth", &"trailcoat": "leather", &"arena_trailcoat": "leather", &"pilot_head": "head", &"pilot_shoulders": "plate", &"pilot_arms": "leather", &"pilot_cloak": "cloth", &"pilot_legs": "scales", &"pilot_feet": "leather"}
static func quality_name(id: StringName) -> String:
	return QUALITY_LABELS.get(id, String(id))
static func item_name(item: EquipmentDefinition) -> String:
	if item == null: return "Vazio"
	return OLD_NAMES[item.id] + " (antigo)" if OLD_NAMES.has(item.id) else item.display_name
static func icon(item: EquipmentDefinition) -> Texture2D:
	if item == null: return null
	if item.icon != null: return item.icon
	var key: String = SURFACES.get(item.id, {&"weapon": "weapon", &"shield": "shield", &"focus": "focus", &"jewelry": "jewelry", &"armor": "plate"}.get(item.item_kind, "plate"))
	return load("res://assets/art/icons/equipment/%s.svg" % key) as Texture2D
static func card_icon() -> Texture2D:
	return load("res://assets/art/icons/equipment/card.svg") as Texture2D

static func instance_description(item: EquipmentDefinition, instance: EquipmentInstance) -> String:
	if instance.power_ruleset_id == &"legacy_unscaled": return item.description
	var lines: Array[String] = []
	for effect: EffectDefinition in item.effects:
		if not EquipmentPowerRules.scales(effect): continue
		var value := EquipmentPowerRules.modifier_magnitude(effect, instance, item)
		lines.append("%s: %s%s" % [ContentAuthoring.STAT_LABELS.get(effect.axis, String(effect.axis)), "+" if value >= 0 else "", BuildPresentation.value_text(effect.axis, value)])
	return item.description if lines.is_empty() else "Bônus deste exemplar:\n" + "\n".join(lines) + "\nReceita: " + item.description
