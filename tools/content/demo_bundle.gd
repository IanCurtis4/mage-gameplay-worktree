extends RefCounted
## Demonstrative authoring Resources, never loaded by BuildContentLoader.
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: StringName in IdentityIds.equipment_slots():
		var item := EquipmentDefinition.new()
		item.id = StringName("demo_" + String(slot))
		item.slot = EquipmentRules.definition_slot(slot)
		item.item_kind = &"armor" if slot in EquipmentRules.ARMOR_SLOTS else (&"weapon" if slot == &"main_hand" else (&"shield" if slot == &"off_hand" else &"jewelry"))
		item.hand_usage = &"one_hand" if item.item_kind == &"weapon" else &"none"
		item.origin_id = &"authoring_demo"
		item.item_level = 1
		item.quality_id = &"common"
		item.socket_capacity = EquipmentRules.ARMOR_SLOTS.find(slot) % 5 if item.item_kind == &"armor" else (2 if item.item_kind in [&"weapon", &"shield"] else 0)
		item.allowed_origins = [&"swordsman", &"mage", &"archer"]
		item.effects.assign([_stat(StringName("demo_stat_" + String(slot)), &"physical_defense", 1)])
		var purpose := "Proteção simples; peça de demonstração da posição %s, sem origem narrativa definitiva." % slot
		if slot in [&"torso", &"shoulders"]:
			item.quality_id = &"rare"
			item.set_id = &"demo_armor_set"
			purpose = "Proteção coordenada: esta armadura pertence ao mesmo conjunto demonstrativo que a outra peça."
		if slot == &"main_hand":
			item.quality_id = &"rare"
			var proc := EffectDefinition.new()
			proc.id = &"demo_weapon_proc"
			proc.unique_effect_id = &"demo_weapon_proc"
			proc.family_id = &"demo_weapon_hit"
			proc.kind = EffectDefinition.Kind.PROC
			proc.handler_id = EffectDefinition.Handler.HIT_DAMAGE
			proc.trigger = EffectDefinition.Trigger.ON_HIT
			proc.axis = &"physical_damage"
			proc.unit = &"damage"
			proc.magnitude = 3
			proc.limit = 20
			item.effects.assign([proc])
			purpose = "Arma de uma mão para pressão em acertos reais; não atribuir magia, sangramento ou área ao texto."
		if slot == &"neck":
			item.quality_id = &"rare"
			var grant := EffectDefinition.new()
			grant.id = &"demo_teleport_access"
			grant.family_id = &"demo_teleport_access"
			grant.kind = EffectDefinition.Kind.ACTIVE_GRANT
			grant.handler_id = EffectDefinition.Handler.ACTIVE_SKILL
			grant.granted_skill_id = &"teleport"
			grant.granted_rank = 1
			grant.unit = &"points"
			grant.allowed_origins = [&"swordsman", &"mage", &"archer"]
			grant.tags = [&"ethereal"]
			item.effects.assign([grant])
			purpose = "Joia de mobilidade: concede acesso a Teleporte enquanto equipada; não concede o restante do kit de Mago."
		result.append(_entry(&"equipment", item, purpose))
	var set_recipe := EquipmentSetDefinition.new()
	set_recipe.id = &"demo_armor_set"
	set_recipe.thresholds = {2: [_stat(&"demo_set_hp", &"max_hp", 4)]}
	result.append(_entry(&"set", set_recipe, "Conjunto de duas armaduras para proteção; tema deve unir tronco e ombros, sem prometer efeitos elementais."))
	for complex: bool in [false, true]:
		var mob := MobDefinition.new()
		mob.id = &"demo_elite_species" if complex else &"demo_normal_species"
		mob.base_category = &"elite" if complex else &"normal"
		mob.allowed_occurrence_categories.assign([&"elite", &"rare_elite"] if complex else [&"normal", &"rare", &"elite"])
		mob.primary_attributes = {&"str": 2, &"agi": 2, &"vit": 2, &"int": 2, &"dex": 2, &"luk": 2}
		mob.card_id = &"demo_elite_card" if complex else &"demo_normal_card"
		if complex:
			mob.archetype = &"archer"
			mob.animation_kind = &"archer"
			mob.skill_ids = [&"fire_spear"]
			mob.skill_ranks = {&"fire_spear": 1}
		result.append(_entry(&"mob", mob, "Espécie demonstrativa ligada a lanças de fogo, base elite." if complex else "Espécie demonstrativa resistente e comum, sem magia ou poderes novos."))
		var card := CardDefinition.new()
		card.id = mob.card_id
		card.mob_base_id = mob.id
		if complex:
			card.allowed_origins = [&"mage"]
			card.effects.assign([_projectile(&"demo_card_fire_shape")])
		else:
			card.effects.assign([_stat(&"demo_card_vit", &"vit", 1, &"primary_flat")])
		result.append(_entry(&"card", card, "Carta passiva da espécie elite: transforma Lança de Fogo, sem conceder ação nova." if complex else "Carta passiva da espécie comum: resistência numérica; não atribuir transformação."))
	var sp := AugmentDefinition.new()
	sp.id = &"demo_sp_growth"
	sp.max_stacks = 3
	var effect := _stat(&"demo_sp_growth_effect", &"max_sp", 2)
	effect.stack_values = [2.0, 4.0, 6.0]
	sp.effects.assign([effect])
	result.append(_entry(&"augment", sp, "Reserva de SP da run, três patamares cumulativos; não promete cura ou recarga."))
	var shape := AugmentDefinition.new()
	shape.id = &"demo_fire_shape"
	shape.allowed_origins = [&"mage"]
	shape.effects.assign([_projectile(&"demo_augment_fire_shape")])
	result.append(_entry(&"augment", shape, "Transformação exclusiva de Lança de Fogo na run; alternativa à carta transformadora, sem novo botão."))
	var range_recipe := AugmentDefinition.new()
	range_recipe.id = &"demo_spear_range"
	range_recipe.allowed_origins = [&"mage"]
	range_recipe.max_stacks = 2
	var range_effect := EffectDefinition.new()
	range_effect.id = &"demo_spear_range_effect"
	range_effect.family_id = &"demo_spear_range_effect"
	range_effect.kind = EffectDefinition.Kind.SKILL_RULE
	range_effect.handler_id = EffectDefinition.Handler.SKILL_SCALAR
	range_effect.target_skill_ids = [&"fire_spear", &"ice_spear"]
	range_effect.axis = &"range"
	range_effect.unit = &"units"
	range_effect.magnitude = 20
	range_effect.stack_values = [20.0, 40.0]
	range_effect.limit = 1200
	range_recipe.effects.assign([range_effect])
	result.append(_entry(&"augment", range_recipe, "Alcance de Lanças de Fogo/Gelo em duas etapas; não aumenta dano, velocidade ou quantidade."))
	var focus := EquipmentDefinition.new()
	focus.id = &"demo_focus"
	focus.slot = &"off_hand"
	focus.item_kind = &"focus"
	focus.hand_usage = &"none"
	focus.origin_id = &"authoring_demo"
	focus.item_level = 1
	focus.quality_id = &"common"
	focus.allowed_origins = [&"mage"]
	focus.effects.assign([_stat(&"demo_focus_int", &"int", 1, &"primary_flat")])
	result.append(_entry(&"equipment", focus, "Foco de condução arcana na mão secundária, sem encaixes; não é escudo nem arma adicional."))
	var two_hands := focus.duplicate(true) as EquipmentDefinition
	two_hands.id = &"demo_two_hands"
	two_hands.slot = &"main_hand"
	two_hands.item_kind = &"weapon"
	two_hands.hand_usage = &"two_hands"
	two_hands.quality_id = &"rare"
	two_hands.socket_capacity = 4
	var reach := range_effect.duplicate(true) as EffectDefinition
	reach.id = &"demo_two_hands_reach"
	reach.family_id = &"demo_two_hands_reach"
	reach.magnitude = 10
	reach.stack_values = []
	two_hands.effects.assign([reach])
	result.append(_entry(&"equipment", two_hands, "Arma arcana de duas mãos para alcance; exige secundária vazia, não pode combinar com foco ou escudo."))
	return result

static func _entry(origin: StringName, definition: Resource, purpose: String) -> Dictionary:
	return {"origin": origin, "definition": definition, "purpose": purpose}
static func _stat(id: StringName, axis: StringName, value: float, channel: StringName = &"flat") -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = id
	effect.axis = axis
	effect.magnitude = value
	effect.unit = &"points"
	effect.channel = channel
	return effect
static func _projectile(id: StringName) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = &"demo_fire_shape"
	effect.kind = EffectDefinition.Kind.SKILL_RULE
	effect.handler_id = EffectDefinition.Handler.PROJECTILE_COUNT
	effect.stacking_mode = EffectDefinition.Stacking.EXCLUSIVE
	effect.conflict_group = &"demo_fire_shape"
	effect.target_skill_ids = [&"fire_spear"]
	effect.axis = &"projectile_count"
	effect.unit = &"count"
	effect.magnitude = 1
	effect.limit = 16
	effect.tags = [&"flaming"]
	return effect
