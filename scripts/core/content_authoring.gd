class_name ContentAuthoring
extends RefCounted
## Offline authoring boundary. Mechanics are Resources; editorial input is text only.
const ORIGINS: Array[StringName] = [&"mob", &"set", &"equipment", &"card", &"augment"]
const EDITORIAL_FIELDS: Array[StringName] = [&"display_name", &"description", &"flavor_text", &"icon"]
const STAT_LABELS := {&"str": "FOR", &"agi": "AGI", &"vit": "VIT", &"int": "INT", &"dex": "DES", &"luk": "SOR", &"max_hp": "Vida máxima", &"max_sp": "SP máximo", &"hp_regen": "Regeneração de Vida", &"sp_regen": "Regeneração de SP", &"melee_attack": "Ataque corpo a corpo", &"precision_attack": "Ataque de precisão", &"magic_attack": "Ataque mágico", &"physical_defense": "Defesa física", &"magic_defense": "Defesa mágica", &"hit_rating": "Acerto", &"flee_rating": "Esquiva", &"crit_chance": "Chance de crítico", &"crit_multiplier": "Multiplicador de crítico", &"crit_resistance": "Resistência a crítico", &"attacks_per_second": "Ataques por segundo", &"move_speed": "Velocidade de movimento", &"variable_cast_multiplier": "Multiplicador de conjuração variável", &"fixed_cast_reduction": "Redução de conjuração fixa", &"after_cast_reduction": "Redução de pós-conjuração", &"cooldown_reduction": "Redução de recarga", &"physical_cc_resistance": "Resistência a controle físico", &"magic_cc_resistance": "Resistência a controle mágico", &"damage_dealt_multiplier": "Multiplicador de dano causado"}
# Omit additive neutral defaults so historical recipes retain their canonical digest.
# Every effective gameplay value still participates in the mechanical signature.
const NEUTRAL_MOB_FIELDS := {&"origin_levels": {}, &"encounter_tiers": false, &"aggro_radius": 0.0, &"leash_radius": 0.0, &"sight_timeout": 4.0, &"visual_kind": &"humanoid", &"summons_companion": false}
const FRACTION_AXES: Array[StringName] = [&"crit_chance", &"crit_resistance", &"fixed_cast_reduction", &"after_cast_reduction", &"cooldown_reduction", &"physical_cc_resistance", &"magic_cc_resistance"]

static func prepare(entries: Array[Dictionary]) -> Dictionary:
	var checked := _catalog(entries)
	if not checked["ok"]: return checked
	var mechanics: Dictionary = {}
	var briefs: Array[Dictionary] = []
	var texts: Dictionary = {}
	for entry: Dictionary in entries:
		var definition: Resource = entry["definition"]
		var key := _key(entry)
		mechanics[key] = _resource_data(definition)
		briefs.append({"key": key, "purpose": entry["purpose"], "mechanics": mechanics[key], "description": describe(entry["origin"], definition), "editable_fields": ["name", "flavor"], "name_max_length": 80, "flavor_max_length": 220})
		texts[key] = {"name": "", "flavor": ""}
	briefs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["key"] < b["key"])
	var digest := JSON.stringify(mechanics, "", true).sha256_text()
	return {"ok": true, "mechanical_digest": digest, "briefs": briefs, "text_template": {"schema_version": 1, "mechanical_digest": digest, "entries": texts}}

static func compile_bundle(entries: Array[Dictionary], text_document: Dictionary, require_complete: bool = true) -> Dictionary:
	var prepared := prepare(entries)
	if not prepared["ok"]: return prepared
	if text_document.size() != 3 or not text_document.has("schema_version") or not text_document.has("mechanical_digest") or not text_document.has("entries") or not EquipmentRules.exact_integer(text_document["schema_version"], 1, 1) or not text_document["entries"] is Dictionary:
		return BuildEffectCatalog.failure(&"invalid_editorial_document")
	if not text_document["mechanical_digest"] is String or text_document["mechanical_digest"] != prepared["mechanical_digest"]:
		return BuildEffectCatalog.failure(&"stale_editorial_document")
	var texts: Dictionary = text_document["entries"]
	var known: Dictionary = prepared["text_template"]["entries"]
	for key: Variant in texts:
		if not known.has(key): return BuildEffectCatalog.failure(&"unknown_editorial_id", str(key))
	var definitions: Array[Dictionary] = []
	var pending: Array[String] = []
	for entry: Dictionary in entries:
		var key := _key(entry)
		var copy: Resource = entry["definition"].duplicate(true)
		var text: Variant = texts.get(key, {"name": "", "flavor": ""})
		if not text is Dictionary or text.size() != 2 or not text.has("name") or not text.has("flavor") or not text["name"] is String or not text["flavor"] is String:
			return BuildEffectCatalog.failure(&"invalid_editorial_fields", key)
		var name: String = text["name"].strip_edges()
		var flavor: String = text["flavor"].strip_edges()
		if name.length() > 80 or flavor.length() > 220 or name.contains("\n") or name.contains("\r") or _has_controls(name) or _has_controls(flavor):
			return BuildEffectCatalog.failure(&"invalid_editorial_text", key)
		if name.is_empty() or flavor.is_empty(): pending.append(key)
		copy.display_name = String(copy.id) if name.is_empty() else name
		copy.flavor_text = flavor
		copy.description = describe(entry["origin"], copy)
		definitions.append({"origin": entry["origin"], "definition": copy, "purpose": entry["purpose"]})
	if require_complete and not pending.is_empty(): return BuildEffectCatalog.failure(&"incomplete_editorial_document", ", ".join(pending))
	var catalog := _catalog(definitions)
	if not catalog["ok"]: return catalog
	return {"ok": true, "ready": pending.is_empty(), "pending": pending, "mechanical_digest": prepared["mechanical_digest"], "entries": definitions, "catalog": catalog["catalog"]}

static func _catalog(entries: Array[Dictionary]) -> Dictionary:
	if entries.is_empty(): return BuildEffectCatalog.failure(&"empty_authoring_bundle")
	var seen: Dictionary = {}
	var mobs := MobCatalog.new()
	var catalog := BuildEffectCatalog.new()
	for entry: Dictionary in entries:
		if entry.size() != 3 or not entry.has("origin") or not entry.has("definition") or not entry.has("purpose") or not entry["purpose"] is String or entry["purpose"].strip_edges().is_empty() or entry["origin"] not in ORIGINS:
			return BuildEffectCatalog.failure(&"invalid_authoring_entry")
		var definition: Resource = entry["definition"] if entry["definition"] is Resource else null
		if not _matches(entry["origin"], definition): return BuildEffectCatalog.failure(&"invalid_definition_type")
		if not IdentityIds.is_technical_id(String(definition.id)) or seen.has(_key(entry)):
			return BuildEffectCatalog.failure(&"duplicate_or_empty_id")
		seen[_key(entry)] = definition
	for entry: Dictionary in entries:
		if entry["origin"] == &"mob":
			var checked := mobs.register_definition(entry["definition"])
			if not checked["ok"]: return checked
	catalog.set_mob_catalog(mobs)
	for entry: Dictionary in entries:
		if entry["origin"] == &"set":
			var checked := catalog.register_set(entry["definition"])
			if not checked["ok"]: return checked
	for entry: Dictionary in entries:
		if entry["origin"] in BuildEffectCatalog.ORIGINS:
			var checked := catalog.register_definition(entry["origin"], entry["definition"])
			if not checked["ok"]: return checked
	for entry: Dictionary in entries:
		var definition: Resource = entry["definition"]
		if definition is EquipmentDefinition:
			var instance := EquipmentInstance.from_metadata(&"equipment_1", definition.id, definition.metadata())
			if not instance["ok"]: return instance
			var checked := EquipmentRules.validate_instance(instance["instance"], definition.metadata())
			if not checked["ok"]: return checked
			checked = catalog.validate_equipment_quality(definition, definition.quality_id)
			if not checked["ok"]: return checked
		if definition is MobDefinition and not definition.card_id.is_empty():
			var card: CardDefinition = seen.get("card:%s" % definition.card_id)
			if card == null or card.mob_base_id != definition.id: return BuildEffectCatalog.failure(&"invalid_authoring_card_link")
		if definition is EquipmentSetDefinition:
			var slots: Dictionary = {}
			for member: Dictionary in entries:
				if member["definition"] is EquipmentDefinition and member["definition"].set_id == definition.id:
					slots[member["definition"].slot] = true
			for threshold: int in definition.thresholds:
				if slots.size() < threshold or not _set_has_identity(entries, definition.id, threshold): return BuildEffectCatalog.failure(&"unreachable_authoring_set")
	return {"ok": true, "catalog": catalog}

static func _matches(origin: StringName, definition: Resource) -> bool:
	return (origin == &"mob" and definition is MobDefinition) or (origin == &"set" and definition is EquipmentSetDefinition) or (origin == &"equipment" and definition is EquipmentDefinition) or (origin == &"card" and definition is CardDefinition) or (origin == &"augment" and definition is AugmentDefinition)

static func _key(entry: Dictionary) -> String:
	return "%s:%s" % [entry["origin"], entry["definition"].id]

static func _resource_data(resource: Resource) -> Dictionary:
	var result := {"type": resource.get_script().get_global_name()}
	for property: Dictionary in resource.get_property_list():
		var field := StringName(property["name"])
		if int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE and int(property["usage"]) & PROPERTY_USAGE_STORAGE and field not in EDITORIAL_FIELDS:
			if resource is MobDefinition and NEUTRAL_MOB_FIELDS.has(field) and resource.get(field) == NEUTRAL_MOB_FIELDS[field]:
				continue
			result[String(field)] = _value_data(resource.get(field))
	return result

static func _value_data(value: Variant) -> Variant:
	if value is Resource: return _resource_data(value)
	if value is StringName: return String(value)
	if value is Color: return [value.r, value.g, value.b, value.a]
	if value is Array:
		var values: Array = []
		for item: Variant in value: values.append(_value_data(item))
		return values
	if value is Dictionary:
		var values: Dictionary = {}
		for key: Variant in value: values[str(key)] = _value_data(value[key])
		return values
	return value

static func describe(origin: StringName, definition: Resource) -> String:
	var lines: Array[String] = []
	if definition is MobDefinition:
		lines.append("Nível fixo %d. Categoria base: %s." % [definition.fixed_level, definition.base_category])
		for skill: StringName in definition.skill_ids: lines.append("Usa %s no rank %d." % [_skill_name(skill), definition.skill_ranks[skill]])
	elif definition is EquipmentSetDefinition:
		var thresholds: Array = definition.thresholds.keys()
		thresholds.sort()
		for threshold: int in thresholds:
			for effect: EffectDefinition in definition.thresholds[threshold]: lines.append("%d peças: %s" % [threshold, _effect_text(effect)])
	else:
		for effect: EffectDefinition in definition.effects:
			lines.append(_effect_text(effect))
		if definition is AugmentDefinition: lines.append("Acumula até %d vez(es)." % definition.max_stacks)
		if definition is EquipmentDefinition and definition.item_kind == &"weapon":
			for effect: EffectDefinition in definition.effects:
				if effect.kind == EffectDefinition.Kind.PROC:
					lines.append("O efeito de acerto exige uso desta arma.")
					break
	if lines.is_empty(): lines.append("Sem efeito adicional declarado.")
	return "\n".join(lines)

static func _effect_text(effect: EffectDefinition) -> String:
	var text := ""
	match effect.kind:
		EffectDefinition.Kind.STAT:
			var suffix := "%" if effect.channel == &"increased" else (" p.p." if effect.axis in FRACTION_AXES else "")
			var scale := 100.0 if effect.channel == &"increased" or effect.axis in FRACTION_AXES else 1.0
			var values: Array[String] = []
			var curve: Array[float] = []
			curve.assign(effect.stack_values if not effect.stack_values.is_empty() else [effect.magnitude])
			for value: float in curve: values.append("%s%s" % [_number(value * scale, true), suffix])
			text = "%s: %s%s." % [STAT_LABELS[effect.axis], " / ".join(values), " (bônus aumentado)" if effect.channel == &"increased" else ""]
		EffectDefinition.Kind.SKILL_RULE:
			var skills: Array[String] = []
			for skill: StringName in effect.target_skill_ids: skills.append(_skill_name(skill))
			text = "%s: %s %s; limite final %s." % [", ".join(skills), _curve_text(effect), "projétil(is)" if effect.handler_id == EffectDefinition.Handler.PROJECTILE_COUNT else "unidades de alcance", _number(effect.limit)]
		EffectDefinition.Kind.PROC:
			var targets: Array[String] = []
			for skill: StringName in effect.target_skill_ids: targets.append(_skill_name(skill))
			text = "Ao acertar: bônus de %s de dano %s e %s%% proporcional; limite do bônus %s." % [_curve_text(effect), "físico" if effect.axis == &"physical_damage" else "mágico", _number(effect.increased * 100.0), _number(effect.limit)]
			if not targets.is_empty(): text += " Apenas em acertos de %s." % ", ".join(targets)
		EffectDefinition.Kind.KIT_RULE:
			match effect.axis:
				&"echo_origin_fixed": text = "Eco resolve no ponto onde o portador foi agendado, com espera, dano e alcance da habilidade."
				&"geometer_ground_anchor": text = "Traçado e Triangulação fixam vértices no ponto do impacto, sem acompanhar o alvo."
				&"drain_inscription": text = "Drenagem completa de quatro impactos marca por 5 s o alvo que sobrevive ao último dano positivo. Potência de Maldição capturada no início. Requer Drenagem e Maldição aprendidas; não dispara eco nesse impacto."
				&"hunter_marked_mechanism": text = "Congelante, Piche e Espinhos só são disparadas pelo alvo da Marca capturada na colocação. Sem Marca viva, não há custo nem colocação. Área e vítimas seguem as regras da armadilha. Requer Marca e uma dessas armadilhas aprendidas."
				&"hunter_covering_fan": text = "Tiro de Cobertura divide a exploração bruta da abertura: 50% no alvo, 50% no segundo inimigo mais próximo até 80 unidades com visão. Empate por ID; sem segundo, 100% no alvo. Defesas resolvem cada parcela separadamente."
				&"geometer_collapse_first_element": text = "Colapso de triângulo usa o elemento de A em vez de C; corrente elétrica começa em A. Paredes não mudam. Requer Triangulação e Colapso aprendidos, preservando os gates do kit."
		EffectDefinition.Kind.ACTIVE_GRANT:
			text = "Concede %s no rank %d; vale o maior rank disponível, com recarga compartilhada." % [_skill_name(effect.granted_skill_id), effect.granted_rank]
	if not effect.target_skill_ids.is_empty(): text += " Requer rank %d na habilidade afetada." % effect.minimum_rank
	if effect.stacking_mode == EffectDefinition.Stacking.EXCLUSIVE: text += " Não combina com outra transformação do mesmo grupo."
	return text

static func _skill_name(id: StringName) -> String:
	var skill := ClassCatalog.skill_definition(id)
	return skill.display_name if skill != null else "Autoataque"

static func _has_controls(text: String) -> bool:
	for index: int in text.length():
		if text.unicode_at(index) < 32 or text.unicode_at(index) in [127, 133, 8232, 8233, 65533]: return true
	return false

static func _curve_text(effect: EffectDefinition) -> String:
	var values: Array[String] = []
	var curve: Array[float] = []
	curve.assign(effect.stack_values if not effect.stack_values.is_empty() else [effect.magnitude])
	for value: float in curve: values.append(_number(value, true))
	return " / ".join(values)

static func _number(value: float, signed: bool = false) -> String:
	var text := String.num(value, 6)
	if text.contains("."):
		while text.ends_with("0"): text = text.left(-1)
		text = text.trim_suffix(".")
	return ("+" if signed and value >= 0.0 else "") + text.replace(".", ",")

static func _set_has_identity(entries: Array[Dictionary], set_id: StringName, threshold: int) -> bool:
	var catalog := ProfileCatalog.pilot()
	for origin: StringName in IdentityIds.base_class_ids():
		var evolutions: Array[StringName] = [&""]
		for evolution: EvolutionDefinition in catalog.evolution_definitions_for_origin(origin):
			if catalog.evolution_is_ready(evolution.id, origin): evolutions.append(evolution.id)
		for evolution: StringName in evolutions:
			var snapshot := BuildSnapshot.new()
			snapshot.base_class_id = origin
			snapshot.evolution_id = evolution
			var slots: Dictionary = {}
			for entry: Dictionary in entries:
				var item: Resource = entry["definition"]
				if item is EquipmentDefinition and item.set_id == set_id and BuildEffectCatalog.definition_allowed(item, snapshot): slots[item.slot] = true
			if slots.size() >= threshold: return true
	return false
