extends RefCounted
## Offline ilvl-1 comparison catalog. Not a progression model or live catalog.
const D = preload("res://tools/content/demo_bundle.gd")
const ROUTES := {
	"swordsman": [["slash", "brutal_strike"], ["shield_wall", "provoke"]],
	"mage": [["fire_spear", "ice_spear"], ["fire_wall", "ice_wall"]],
	"archer": [["double_shot", "piercing_arrow"], ["snare_trap", "explosive_trap"]],
	"defender": [["defender_counterstroke", "defender_reprisal_wave"], ["defender_line_lock", "defender_anchor"]],
	"berserker": [["berserker_rupture", "berserker_blood_rift"], ["berserker_execution", "berserker_wound_leap"]],
	"elementalist": [["elementalist_flame_burst", "elementalist_lightning_arc"], ["elementalist_glacial_ring", "elementalist_ember_path"]],
	"spiritualist": [["spiritualist_echo_curse", "spiritualist_procession"], ["spiritualist_soul_drain", "spiritualist_spectral_veil"]],
	"sentinel": [["sentinel_headshot", "sentinel_piercing_shot"], ["sentinel_net_shot", "sentinel_concussion_shot"]],
	"hunter": [["hunter_freezing_trap", "hunter_tar_trap"], ["hunter_covering_shot", "hunter_mark"]],
	"mg_ar": [["geometer_trace", "geometer_rewrite"], ["geometer_triangulation", "geometer_collapse"]],
}
const EXCLUSIVE_PROCS := {
	"defender": ["defender_counterstroke", "defender_line_lock"],
	"berserker": ["berserker_rupture", "berserker_execution"],
	"elementalist": ["elementalist_flame_burst", "elementalist_glacial_ring"],
	"sentinel": ["sentinel_headshot", "sentinel_net_shot"],
}
const NUMERIC_EXCLUSIVES := {
	"spiritualist": [["max_sp", 6.0], ["magic_defense", 2.0]],
	"hunter": [["int", 2.0], ["dex", 2.0]],
	"mg_ar": [["max_sp", 6.0], ["move_speed", 4.0]],
}
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var legacy := BuildEffectCatalog.pilot()
	for id: StringName in legacy.ids(&"augment"):
		result.append(D._entry(&"augment", legacy.get_definition(&"augment", id), "Augment histórico: preservar ID, curva, limite e comportamento; texto pode ser renovado sem adicionar efeitos."))
	for item: Resource in BuildContentLoader.definitions(&"equipment"):
		var effect: EffectDefinition
		match item.id:
			&"starter_blade": effect = D._stat(&"pilot_blade_attack", &"melee_attack", 2)
			&"starter_staff": effect = D._stat(&"pilot_staff_attack", &"magic_attack", 2)
			&"starter_bow": effect = D._stat(&"pilot_bow_attack", &"precision_attack", 2)
			&"traveler_vest": effect = D._stat(&"pilot_vest_defense", &"physical_defense", 2)
			&"traveler_charm": effect = D._stat(&"pilot_charm_hp", &"max_hp", 6)
			&"riposte_blade": effect = _proc(&"pilot_blade_hit", &"physical_damage", 4)
			&"ember_staff": effect = _count(&"pilot_staff_shape", &"fire_spear", 1)
			&"hunters_bow": effect = _proc(&"pilot_bow_hit", &"physical_damage", 4)
			&"warden_mail":
				effect = D._stat(&"pilot_mail_defense", &"physical_defense", 4)
				item.set_id = &"pilot_guard_set"
			&"channeler_robe": effect = D._stat(&"pilot_robe_int", &"int", 3, &"primary_flat")
			&"trailcoat": effect = D._stat(&"pilot_coat_dex", &"dex", 3, &"primary_flat")
			&"prismatic_charm": effect = _grant(&"pilot_prismatic_access", &"fire_spear")
		item.effects.assign([effect])
		result.append(D._entry(&"equipment", item, "Equipamento da Arena demonstrativa, ilvl 1. ID e metadata históricos preservados. Receita piloto explícita; não inventar região, tipo de armadura ou poder além da ficha."))
	for row: Array in [
		["pilot_head", "head", "physical_defense", 2.0, 0],
		["pilot_shoulders", "shoulders", "physical_defense", 2.0, 2],
		["pilot_arms", "arms", "hit_rating", 3.0, 3],
		["pilot_cloak", "cloak", "magic_defense", 2.0, 0],
		["pilot_legs", "legs", "physical_defense", 2.0, 4],
		["pilot_feet", "feet", "move_speed", 3.0, 1],
		["pilot_shield", "off_hand", "physical_defense", 3.0, 2],
		["pilot_focus", "off_hand", "int", 2.0, 0],
		["pilot_sp_jewel", "accessory", "max_sp", 6.0, 0],
		["pilot_stride_jewel", "accessory", "move_speed", 3.0, 0],
		["pilot_ward_jewel", "accessory", "magic_defense", 2.0, 0],
	]:
		var item := _item(StringName(row[0]), StringName(row[1]), int(row[4]))
		if item.id == &"pilot_focus":
			item.item_kind = &"focus"
			item.allowed_origins = [&"mage"]
		if item.id in [&"pilot_shoulders", &"pilot_legs"]:
			item.quality_id = &"rare"
			item.set_id = &"pilot_guard_set"
		item.effects.assign([D._stat(StringName(String(item.id) + "_effect"), StringName(row[2]), float(row[3]), &"primary_flat" if row[2] == "int" else &"flat")])
		result.append(D._entry(&"equipment", item, "Peça da Arena demonstrativa na posição %s, ilvl 1. Nome e flavor descrevem sua função; não prometer habilidade, cura ou transformação." % row[1]))
	var neck := _item(&"pilot_step_neck", &"neck", 0)
	neck.quality_id = &"rare"
	neck.effects.assign([_grant(&"pilot_step_access", &"teleport")])
	result.append(D._entry(&"equipment", neck, "Colar da Arena demonstrativa: acesso a Teleporte enquanto equipado, sem conceder biblioteca ou mecânicas de Mago."))
	var wand := _item(&"pilot_wand", &"main_hand", 2)
	wand.item_kind = &"weapon"
	wand.hand_usage = &"one_hand"
	wand.quality_id = &"common"
	wand.allowed_origins = [&"mage"]
	wand.effects.assign([D._stat(&"pilot_wand_magic", &"magic_attack", 1)])
	result.append(D._entry(&"equipment", wand, "Arma arcana da Arena demonstrativa, de uma mão, ilvl 1; permite foco na secundária. Só ataque mágico numérico, sem magia nova."))
	var guard := EquipmentSetDefinition.new()
	guard.id = &"pilot_guard_set"
	guard.thresholds = {2: [D._stat(&"pilot_guard_hp", &"max_hp", 8)], 3: [D._stat(&"pilot_guard_resist", &"physical_defense", 2)]}
	result.append(D._entry(&"set", guard, "Conjunto de proteção da Arena demonstrativa. Tronco, ombros e pernas; limiares numéricos de duas e três peças, sem reação automática."))
	for row: Array in [["echo_card", "elite"], ["ember_card", "elite"], ["frost_card", "normal"], ["precision_card", "normal"], ["bulwark_card", "normal"], ["trail_card", "normal"]]:
		var mob := MobDefinition.new()
		mob.id = StringName("pilot_" + String(row[0]).trim_suffix("_card") + "_species")
		mob.base_category = StringName(row[1])
		mob.allowed_occurrence_categories.assign([&"elite", &"rare_elite"] if row[1] == "elite" else [&"normal", &"rare", &"elite", &"rare_elite"])
		mob.card_id = StringName(row[0])
		mob.primary_attributes = {&"str": 2, &"agi": 2, &"vit": 2, &"int": 2, &"dex": 2, &"luk": 2}
		var card := CardDefinition.new()
		card.id = mob.card_id
		card.mob_base_id = mob.id
		var effect: EffectDefinition
		match card.id:
			&"echo_card": effect = _proc(&"pilot_card_hit", &"magic_damage", 2)
			&"ember_card":
				effect = _count(&"pilot_card_shape", &"fire_spear", 1)
				card.allowed_origins = [&"mage"]
			&"frost_card":
				effect = _range(&"pilot_card_reach", &"ice_spear", 20)
				card.allowed_origins = [&"mage"]
			&"precision_card": effect = D._stat(&"pilot_card_dex", &"dex", 1, &"primary_flat")
			&"bulwark_card": effect = D._stat(&"pilot_card_defense", &"physical_defense", 2)
			&"trail_card": effect = D._stat(&"pilot_card_speed", &"move_speed", 3)
		card.effects.assign([effect])
		result.append(D._entry(&"mob", mob, "Espécie de referência do piloto, ligada à carta %s. Nível fixo 1, seis stats 2 e ataque básico; não inventar magia, eco ou habilidades no flavor. Não é spawn de campanha." % card.id))
		result.append(D._entry(&"card", card, "Carta passiva da espécie %s, categoria base %s. Nome deve reconhecer o nome da espécie; só a receita é efeito, nenhum botão novo." % [mob.id, mob.base_category]))
	for origin: StringName in IdentityIds.base_class_ids():
		for branch: int in 2:
			var id := StringName("pilot_" + String(origin) + ("_pressure" if branch == 0 else "_reserve"))
			var effect: EffectDefinition
			if branch == 0:
				effect = _proc(StringName(String(id) + "_effect"), &"magic_damage" if origin == &"mage" else &"physical_damage", 6)
			else:
				effect = D._stat(StringName(String(id) + "_effect"), &"max_sp", 6)
			var augment := _augment(id, effect)
			augment.allowed_origins = [origin]
			result.append(D._entry(&"augment", augment, "Escolha da origem %s: %s. Três patamares, sem mecânicas exclusivas da evolução." % [origin, "dano secundário em acertos primários" if branch == 0 else "reserva de SP"]))
	for identity: String in ROUTES:
		if IdentityIds.is_base_class(StringName(identity)): continue
		for branch: int in 2:
			var id := exclusive_id(identity, branch)
			var effect: EffectDefinition
			if EXCLUSIVE_PROCS.has(identity):
				effect = _proc(StringName(String(id) + "_effect"), &"magic_damage" if IdentityIds.evolution_origin(StringName(identity)) == &"mage" else &"physical_damage", 6)
				effect.target_skill_ids = [StringName(EXCLUSIVE_PROCS[identity][branch])]
			else:
				var numeric: Array = NUMERIC_EXCLUSIVES[identity][branch]
				effect = D._stat(StringName(String(id) + "_effect"), StringName(numeric[0]), float(numeric[1]), &"primary_flat" if numeric[0] in ["int", "dex"] else &"flat")
			var augment := _augment(id, effect)
			augment.allowed_origins = [IdentityIds.evolution_origin(StringName(identity))]
			augment.allowed_evolutions = [StringName(identity)]
			result.append(D._entry(&"augment", augment, "Opção exclusiva de %s, comparação %s. %s Não prometer transformação de Foco, armadilhas, ecos ou construções." % [identity, "A" if branch == 0 else "B", "Dano adicional apenas nos acertos primários da habilidade indicada." if EXCLUSIVE_PROCS.has(identity) else "Bônus numérico de apoio à rota; fantasia específica ainda pendente."]))
	return result

static func exclusive_id(identity: String, branch: int) -> StringName:
	return StringName("pilot_" + identity + ("_a" if branch == 0 else "_b"))
static func _item(id: StringName, slot: StringName, sockets: int) -> EquipmentDefinition:
	var item := EquipmentDefinition.new()
	item.id = id
	item.slot = slot
	item.item_kind = EquipmentRules.default_kind(slot)
	item.hand_usage = &"none"
	item.origin_id = &"demo_arena"
	item.item_level = 1
	item.quality_id = &"uncommon"
	item.socket_capacity = sockets
	item.allowed_origins = IdentityIds.base_class_ids()
	return item
static func _augment(id: StringName, effect: EffectDefinition) -> AugmentDefinition:
	var augment := AugmentDefinition.new()
	augment.id = id
	augment.max_stacks = 3
	effect.stack_values = [effect.magnitude, effect.magnitude * 2, effect.magnitude * 3]
	augment.effects.assign([effect])
	return augment
static func _proc(id: StringName, axis: StringName, value: float) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = id
	effect.kind = EffectDefinition.Kind.PROC
	effect.handler_id = EffectDefinition.Handler.HIT_DAMAGE
	effect.trigger = EffectDefinition.Trigger.ON_HIT
	effect.axis = axis
	effect.unit = &"damage"
	effect.magnitude = value
	effect.limit = 60
	return effect
static func _count(id: StringName, skill: StringName, value: float) -> EffectDefinition:
	var effect := D._projectile(id)
	effect.family_id = id
	effect.stacking_mode = EffectDefinition.Stacking.ADDITIVE
	effect.conflict_group = &""
	effect.target_skill_ids = [skill]
	effect.magnitude = value
	return effect
static func _range(id: StringName, skill: StringName, value: float) -> EffectDefinition:
	var effect := _count(id, skill, value)
	effect.handler_id = EffectDefinition.Handler.SKILL_SCALAR
	effect.axis = &"range"
	effect.unit = &"units"
	effect.limit = 1200
	effect.tags.assign([&"freezing"] if skill == &"ice_spear" else [&"flaming"])
	return effect
static func _grant(id: StringName, skill: StringName) -> EffectDefinition:
	var effect := EffectDefinition.new()
	effect.id = id
	effect.family_id = id
	effect.kind = EffectDefinition.Kind.ACTIVE_GRANT
	effect.handler_id = EffectDefinition.Handler.ACTIVE_SKILL
	effect.unit = &"points"
	effect.granted_skill_id = skill
	effect.allowed_origins = IdentityIds.base_class_ids()
	return effect

static func comparison(identity: String, branch: int, catalog: BuildEffectCatalog) -> Dictionary:
	if not ROUTES.has(identity) or branch not in [0, 1]: return BuildEffectCatalog.failure(&"unknown_comparison")
	var base := StringName(identity) if IdentityIds.is_base_class(StringName(identity)) else IdentityIds.evolution_origin(StringName(identity))
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "pilot_%s_%d" % [identity, branch]
	snapshot.base_class_id = base
	snapshot.evolution_id = &"" if IdentityIds.is_base_class(StringName(identity)) else StringName(identity)
	snapshot.base_level = ProgressionRules.MAX_BASE_LEVEL
	snapshot.job_level = 20 if snapshot.evolution_id.is_empty() else 40
	snapshot.library_skill_ids = snapshot._skill_catalog.skill_ids_for_identity(base, snapshot.evolution_id)
	var purchased: Dictionary[StringName, int] = {}
	for raw_skill: String in ROUTES[identity][branch]:
		purchased[StringName(raw_skill)] = 0 if not snapshot.evolution_id.is_empty() and snapshot._skill_catalog.evolution_definition(snapshot.evolution_id).entry_skill_id == StringName(raw_skill) else 1
	snapshot.skill_ranks = snapshot._skill_catalog.effective_skill_ranks(base, snapshot.evolution_id, purchased)
	var learned_check: Dictionary = snapshot._skill_catalog.validate_purchased_ranks(base, snapshot.evolution_id, snapshot.job_level, purchased)
	if not learned_check["ok"]: return learned_check
	snapshot.action_slots = ActionBarLayout.empty()
	for index: int in ROUTES[identity][branch].size(): snapshot.action_slots[index] = StringName(ROUTES[identity][branch][index])
	var weapon: StringName = {&"swordsman": &"riposte_blade", &"mage": &"ember_staff" if identity == "mage" else &"pilot_wand", &"archer": &"hunters_bow"}[base] if branch == 0 else {&"swordsman": &"starter_blade", &"mage": &"pilot_wand", &"archer": &"starter_bow"}[base]
	var layout := {&"head": &"pilot_head", &"neck": &"pilot_step_neck", &"shoulders": &"pilot_shoulders", &"arms": &"pilot_arms", &"torso": &"warden_mail", &"cloak": &"pilot_cloak", &"legs": &"pilot_legs", &"feet": &"pilot_feet", &"main_hand": weapon, &"off_hand": &"pilot_focus" if base == &"mage" else &"pilot_shield", &"accessory_1": &"traveler_charm", &"accessory_2": &"pilot_sp_jewel", &"accessory_3": &"pilot_stride_jewel", &"accessory_4": &"pilot_ward_jewel"}
	if catalog.get_definition(&"equipment", weapon).hand_usage == &"two_hands": layout[&"off_hand"] = null
	for slot: StringName in IdentityIds.equipment_slots():
		if layout[slot] == null: continue
		var item := catalog.get_definition(&"equipment", layout[slot]) as EquipmentDefinition
		if item == null: return BuildEffectCatalog.failure(&"unknown_definition")
		var id := StringName("pilot_instance_" + String(slot))
		var created := EquipmentInstance.from_metadata(id, item.id, item.metadata())
		if not created["ok"]: return created
		snapshot.equipment_instances[id] = created["instance"]
		snapshot.equipped[slot] = id
	var stacks := {&"vitality": 1, StringName("pilot_" + String(base) + ("_pressure" if branch == 0 and identity != "mg_ar" else "_reserve")): 1}
	if not snapshot.evolution_id.is_empty(): stacks[exclusive_id(identity, branch)] = 1
	var run_effects := {"augment_stacks": stacks, "card_instances": {&"pilot_card_one": &"echo_card" if branch == 0 else &"bulwark_card"}, "card_sockets": {&"pilot_instance_shoulders": [&"pilot_card_one", null]}}
	var composed := BuildEffectComposer.compose(snapshot, run_effects, [], catalog)
	if not composed["ok"]: return composed
	return {"ok": true, "snapshot": snapshot, "run_effects": run_effects, "purchased_ranks": purchased, "composed": composed, "identity": identity, "branch": branch, "tactical_validated": false}
