extends SceneTree

const Effect = preload("res://scripts/data/effect_definition.gd")
const Equipment = preload("res://scripts/data/equipment_definition.gd")
const EquipmentSet = preload("res://scripts/data/equipment_set_definition.gd")
const ROOT := "res://resources/e06_inventory_content/"
const SETS := {
	"low": {"label": "Trilha do Primeiro Passo", "min": 2, "max": 5, "ids": [], "head": "Capuz de Folha Macia", "torso": "Colete de Caminhante", "feet": "Botas de Trilha", "flavor": "Peças leves para quem começa a explorar a Arena, costuradas em tons de bosque."},
	"mid": {"label": "Rota da Lua Serena", "min": 6, "max": 10, "ids": [], "head": "Faixa da Lua Serena", "torso": "Casaco Lunar", "feet": "Sapatos de Luar", "flavor": "Um conjunto de viagem com detalhes prateados, feito para jornadas já conhecidas."},
	"high": {"label": "Vigília das Estrelas", "min": 11, "max": 15, "ids": [], "head": "Diadema Estelar", "torso": "Manto das Constelações", "feet": "Grevas Celestes", "flavor": "Três peças bordadas com mapas de estrelas vistos sobre a Arena."},
}
const CLASSES := {
	"swordsman": {"label": "Espadachim", "base": "swordsman", "evolutions": [], "min": 2, "max": 5, "axis": "melee_attack", "value": 4, "head": "Bandana do Corte Firme", "torso": "Jaqueta do Duelista", "feet": "Botas do Avanço", "flavor": "Couro vermelho e costuras resistentes acompanham quem luta de perto."},
	"mage": {"label": "Mago", "base": "mage", "evolutions": [], "min": 2, "max": 5, "axis": "magic_attack", "value": 4, "head": "Capuz de Fagulha", "torso": "Túnica do Aprendiz Lunar", "feet": "Sapatos de Conjuração", "flavor": "Tecido azul com pequenos bordados de estrelas guia a concentração."},
	"archer": {"label": "Arqueiro", "base": "archer", "evolutions": [], "min": 2, "max": 5, "axis": "precision_attack", "value": 4, "head": "Boina do Mirante", "torso": "Colete da Flecha Certa", "feet": "Botas do Passo Leve", "flavor": "Couro verde e fivelas leves deixam braços e pernas livres para mirar."},
	"defender": {"label": "Defensor", "base": "swordsman", "evolutions": ["defender"], "min": 6, "max": 10, "axis": "physical_defense", "value": 4, "head": "Elmo da Guarda Serena", "torso": "Couraça do Portão", "feet": "Grevas do Baluarte", "flavor": "Placas polidas trazem o emblema de uma muralha e a disciplina de uma guarda."},
	"berserker": {"label": "Furioso", "base": "swordsman", "evolutions": ["berserker"], "min": 6, "max": 10, "axis": "melee_attack", "value": 4, "head": "Faixa da Fúria Rubra", "torso": "Peitoral do Rugido", "feet": "Botas do Impacto", "flavor": "Tiras escarlates e rebites largos lembram uma investida sem hesitação."},
	"elementalist": {"label": "Elementalista", "base": "mage", "evolutions": ["elementalist"], "min": 6, "max": 10, "axis": "magic_attack", "value": 4, "head": "Grinalda dos Quatro Ventos", "torso": "Manto das Marés e Chamas", "feet": "Sandálias do Círculo Elemental", "flavor": "Fios coloridos representam vento, água, terra e fogo em equilíbrio."},
	"spiritualist": {"label": "Espiritualista", "base": "mage", "evolutions": ["spiritualist"], "min": 6, "max": 10, "axis": "magic_attack", "value": 4, "head": "Véu do Sino Distante", "torso": "Manto dos Ecos Gentis", "feet": "Sandálias do Caminho Silencioso", "flavor": "Sinos pequenos e contas de madeira acompanham uma jornada de escuta."},
	"sentinel": {"label": "Sentinela", "base": "archer", "evolutions": ["sentinel"], "min": 6, "max": 10, "axis": "precision_attack", "value": 4, "head": "Capuz do Olho Atento", "torso": "Jaqueta do Vigia", "feet": "Botas da Linha Segura", "flavor": "Equipamento discreto de observação, com marcações para manter a distância."},
	"hunter": {"label": "Caçadora", "base": "archer", "evolutions": ["hunter"], "min": 6, "max": 10, "axis": "precision_attack", "value": 4, "head": "Chapéu da Trilha", "torso": "Casaco de Batedora", "feet": "Botas de Rastreamento", "flavor": "Tecido de viagem reforçado para seguir rastros sem perder o passo."},
	"mg_ar": {"label": "Geômetra", "base": "mage", "evolutions": ["mg_ar"], "min": 11, "max": 15, "axis": "magic_attack", "value": 2, "axis2": "precision_attack", "value2": 2, "head": "Diadema do Traçado", "torso": "Manto da Figura Perfeita", "feet": "Botas do Compasso", "flavor": "Linhas geométricas bordadas lembram construções precisas traçadas no chão."},
}
const SHARED_CLASS_IDS := {
	"swordsman": ["swordsman", "defender", "berserker"],
	"mage": ["mage", "elementalist", "spiritualist", "mg_ar"],
	"archer": ["archer", "sentinel", "hunter"],
}
const IDENTITIES := ["swordsman", "mage", "archer", "defender", "berserker", "elementalist", "spiritualist", "sentinel", "hunter", "mg_ar"]

func _initialize() -> void:
	var equipment_count := 0
	var set_count := 0
	for key: String in SETS:
		var data: Dictionary = SETS[key]
		var set_id := "shared_set_" + key
		var identity_ids: Array[StringName] = []
		var set_def := EquipmentSet.new()
		set_def.id = StringName(set_id)
		set_def.display_name = String(data["label"])
		set_def.flavor_text = String(data["flavor"])
		set_def.description = "2 peças: Vida máxima +12.\n3 peças: Defesa física +3."
		set_def.min_item_level = data["min"]
		set_def.max_item_level = data["max"]
		set_def.allowed_identities = identity_ids
		set_def.thresholds = {2: [_stat(set_id + "_threshold_2_hp", &"max_hp", 12)], 3: [_stat(set_id + "_threshold_3_defense", &"physical_defense", 3)]}
		_save("set", set_id, set_def)
		set_count += 1
		for part: String in ["head", "torso", "feet"]:
			var display := String(data[part])
			var piece := _armor_piece(set_id + "_" + part, display, set_id, StringName(part), data["min"], data["max"], identity_ids, [], [], String(data["flavor"]))
			_save("equipment", String(piece.id), piece)
			equipment_count += 1
	for identity: String in CLASSES:
		var data: Dictionary = CLASSES[identity]
		var set_id := "class_set_" + identity
		var identity_ids: Array[StringName] = [StringName(identity)]
		if identity == "swordsman": identity_ids = [&"swordsman", &"defender", &"berserker"]
		elif identity == "mage": identity_ids = [&"mage", &"elementalist", &"spiritualist", &"mg_ar"]
		elif identity == "archer": identity_ids = [&"archer", &"sentinel", &"hunter"]
		var origins: Array[StringName] = [StringName(data["base"])]
		var evolutions: Array[StringName] = []
		for evolution: String in data["evolutions"]: evolutions.append(StringName(evolution))
		var set_def := EquipmentSet.new()
		set_def.id = StringName(set_id)
		set_def.display_name = "Conjunto %s" % data["label"]
		set_def.flavor_text = String(data["flavor"])
		var t3_axis := &"max_hp" if identity not in ["mage", "elementalist", "spiritualist", "mg_ar"] else &"max_sp"
		var t3_value := 15 if t3_axis == &"max_hp" else 8
		var threshold_2: Array[EffectDefinition] = [_stat(set_id + "_threshold_2_" + String(data["axis"]), StringName(data["axis"]), float(data["value"]), origins, evolutions)]
		if identity == "mg_ar": threshold_2.append(_stat(set_id + "_threshold_2_" + String(data["axis2"]), StringName(data["axis2"]), float(data["value2"]), origins, evolutions))
		set_def.description = "2 peças: %s +%s.\n3 peças: %s +%s." % [_stat_label(StringName(data["axis"])), str(data["value"]), _stat_label(t3_axis), str(t3_value)]
		if identity == "mg_ar": set_def.description = "2 peças: %s +%s; %s +%s.\n3 peças: %s +%s." % [_stat_label(StringName(data["axis"])), str(data["value"]), _stat_label(StringName(data["axis2"])), str(data["value2"]), _stat_label(t3_axis), str(t3_value)]
		set_def.min_item_level = data["min"]
		set_def.max_item_level = data["max"]
		set_def.allowed_identities = identity_ids
		set_def.thresholds = {2: threshold_2, 3: [_stat(set_id + "_threshold_3_" + String(t3_axis), t3_axis, float(t3_value), origins, evolutions)]}
		_save("set", set_id, set_def)
		set_count += 1
		for part: String in ["head", "torso", "feet"]:
			var piece := _armor_piece(set_id + "_" + part, String(data[part]), set_id, StringName(part), data["min"], data["max"], identity_ids, origins, evolutions, String(data["flavor"]))
			_save("equipment", String(piece.id), piece)
			equipment_count += 1
	_add_extra("shared_sword", "Espada da Brisa", "Uma lâmina simples, polida para treinos e viagens.", "Arma de uma mão: ataque corpo a corpo +2.", &"main_hand", &"weapon", &"one_hand", &"melee_attack", 2, [&"swordsman", &"defender", &"berserker"], [&"swordsman"], [], 1, &"sword")
	_add_extra("shared_axe", "Machado da Forja Alegre", "Um machado compacto com cabo de madeira clara.", "Arma de uma mão: ataque corpo a corpo +3.", &"main_hand", &"weapon", &"one_hand", &"melee_attack", 3, [&"swordsman", &"defender", &"berserker"], [&"swordsman"], [], 1, &"axe")
	_add_extra("shared_wand", "Varinha de Estrela", "Uma varinha de madeira com uma pequena estrela entalhada.", "Arma de uma mão: ataque mágico +2.", &"main_hand", &"weapon", &"one_hand", &"magic_attack", 2, [&"mage", &"elementalist", &"spiritualist", &"mg_ar"], [&"mage"], [], 1, &"staff")
	_add_extra("shared_bow", "Arco do Vento Claro", "Um arco de madeira leve, pronto para a prática de tiro.", "Arma de duas mãos: ataque de precisão +2.", &"main_hand", &"weapon", &"two_hands", &"precision_attack", 2, [&"archer", &"sentinel", &"hunter"], [&"archer"], [], 1, &"bow")
	_add_extra("shared_shield", "Broquel da Praça", "Um escudo redondo com borda reforçada e pintura azul.", "Escudo: defesa física +2.", &"off_hand", &"shield", &"none", &"physical_defense", 2, IDENTITIES.map(func(value: String) -> StringName: return StringName(value)), [&"swordsman", &"mage", &"archer"], [], 1, &"shield")
	_add_extra("spiritualist_prayer_beads", "Japamala do Eco Calmo", "Contas de madeira de um japamala, polidas pelo manuseio cuidadoso.", "Armadura nos braços: SP máximo +5.", &"arms", &"armor", &"none", &"max_sp", 5, [&"spiritualist"], [&"mage"], [&"spiritualist"], 1, &"wooden_beads", 6, 10, &"rare")
	_add_extra("elementalist_prism", "Prisma Elemental", "Um foco prismático que separa a luz em cores nítidas.", "Foco secundário: ataque mágico +2.", &"off_hand", &"focus", &"none", &"magic_attack", 2, [&"elementalist"], [&"mage"], [&"elementalist"], 0, &"prismatic_focus", 6, 10, &"rare")
	print("inventory_fixes_bundle_generated equipment=%d sets=%d total=%d" % [equipment_count + 7, set_count, equipment_count + 7 + set_count])
	quit()

func _armor_piece(id: String, name: String, set_id: String, slot: StringName, min_level: int, max_level: int, identities: Array[StringName], origins: Array[StringName], evolutions: Array[StringName], flavor: String) -> EquipmentDefinition:
	var axis := &"max_sp" if slot == &"head" else (&"max_hp" if slot == &"torso" else &"move_speed")
	var value := 3 if slot == &"head" else (12 if slot == &"torso" else 2)
	var piece := Equipment.new()
	piece.id = StringName(id)
	piece.display_name = name
	piece.flavor_text = flavor
	piece.description = "%s: %s +%d." % [_slot_label(slot), _stat_label(axis), value]
	piece.allowed_origins = origins.duplicate()
	piece.allowed_evolutions = evolutions.duplicate()
	piece.allowed_identities = identities.duplicate()
	piece.slot = slot
	piece.item_kind = &"armor"
	piece.hand_usage = &"none"
	piece.origin_id = &"demo_arena"
	piece.item_level = min_level
	piece.min_item_level = min_level
	piece.max_item_level = max_level
	piece.quality_id = &"rare"
	piece.socket_capacity = 1
	piece.set_id = StringName(set_id)
	piece.effects = [_stat(id + "_effect", axis, float(value), origins, evolutions)]
	return piece

func _add_extra(id: String, name: String, flavor: String, description: String, slot: StringName, kind: StringName, hands: StringName, axis: StringName, value: float, identities_raw: Array, origins_raw: Array, evolutions_raw: Array, sockets: int, visual: StringName, min_level: int = 1, max_level: int = 30, quality: StringName = &"common") -> void:
	var item := Equipment.new()
	item.id = StringName(id)
	item.display_name = name
	item.flavor_text = flavor
	item.description = description
	for identity: Variant in identities_raw: item.allowed_identities.append(StringName(identity))
	for origin: Variant in origins_raw: item.allowed_origins.append(StringName(origin))
	for evolution: Variant in evolutions_raw: item.allowed_evolutions.append(StringName(evolution))
	item.slot = slot
	item.item_kind = kind
	item.hand_usage = hands
	item.origin_id = &"demo_arena"
	item.item_level = min_level
	item.min_item_level = min_level
	item.max_item_level = max_level
	item.quality_id = quality
	item.socket_capacity = sockets
	item.visual_key = visual
	item.effects = [_stat(id + "_effect", axis, value, item.allowed_origins, item.allowed_evolutions)]
	_save("equipment", id, item)

func _stat(id: String, axis: StringName, value: float, origins: Array[StringName] = [], evolutions: Array[StringName] = []) -> EffectDefinition:
	var effect := Effect.new()
	effect.id = StringName(id)
	effect.unique_effect_id = StringName(id)
	effect.family_id = StringName(id)
	effect.kind = Effect.Kind.STAT
	effect.axis = axis
	effect.unit = &"points"
	effect.channel = &"flat"
	effect.magnitude = value
	effect.allowed_origins = origins.duplicate()
	effect.allowed_evolutions = evolutions.duplicate()
	return effect

func _save(folder: String, id: String, value: Resource) -> void:
	var directory := ROOT + folder + "/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var error := ResourceSaver.save(value, directory + id + ".tres")
	if error != OK: push_error("ResourceSaver failed for %s/%s: %s" % [folder, id, error_string(error)])

func _slot_label(slot: StringName) -> String:
	return {&"head": "Cabeça", &"torso": "Tronco", &"feet": "Pés"}.get(slot, String(slot))

func _stat_label(axis: StringName) -> String:
	return {&"max_hp": "Vida máxima", &"max_sp": "SP máximo", &"move_speed": "Velocidade de movimento", &"physical_defense": "Defesa física", &"magic_attack": "Ataque mágico", &"melee_attack": "Ataque corpo a corpo", &"precision_attack": "Ataque de precisão"}.get(axis, String(axis))


