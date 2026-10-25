@tool
extends RefCounted
## Passive authoring context; no quest behavior or reward policy lives here.
const FIELDS := {"version":"int","biome_ids":"strings","allowed_species":"strings","allow_rare":"bool","areas":"array"}
const AREA := {"region_id":"id","allowed_species":"strings","allow_rare":"bool","reserved":"array"}
const RESERVED := {"encounter_id":"id","species_id":"id","category":"id","origin_id":"id","quest_id":"string"}
const MAP := {"version":"int","biome_id":"string","overrides":"array"}
const OVERRIDE := {"instance_id":"id","rules":"strings","reason":"string"}
const RULES := ["biome","species","rare","reservation"]

static func empty() -> Dictionary:
	return {"version":1,"biome_ids":[],"allowed_species":[],"allow_rare":false,"areas":[]}
static func empty_map() -> Dictionary: return {"version":1,"biome_id":"","overrides":[]}
static func fail(code: String, entity: String = "") -> Dictionary:
	var message: String = {"context_invalid":"Revise os campos do contexto da peça.","context_region_missing":"A área de encontro precisa apontar para uma região existente.","context_biome":"A peça não permite o bioma escolhido. Registre uma exceção manual ou escolha outra peça.","context_species":"A espécie não é permitida neste local.","context_rare":"Este local não permite sorteio de monstros raros.","context_reserved":"Esta área está reservada para um encontro identificado.","context_reservation_missing":"Realize o encontro reservado antes de publicar.","context_override_invalid":"Exceções exigem instância, regras válidas e motivo; apenas no modo manual."}.get(code,"Revise o contexto de autoria.")
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":entity,"field":"context","message":message,"suggestion":"Abra Contexto e ajuste a regra ou registre uma exceção manual."}]}

static func validate(value: Variant, regions: Array, schema: Script) -> Dictionary:
	var errors: Array = []; schema._shape(value,FIELDS,"context",errors)
	if not errors.is_empty(): return fail("context_invalid")
	if value.version != 1 or value.biome_ids.size() > 32 or value.allowed_species.size() > 128 or value.areas.size() > 64: return fail("context_invalid")
	for list: Array in [value.biome_ids,value.allowed_species]:
		if _duplicates(list): return fail("context_invalid")
	var seen := {}; var reserved := {}
	for area: Variant in value.areas:
		schema._shape(area,AREA,"area",errors)
		if not errors.is_empty(): return fail("context_invalid")
		if seen.has(area.region_id) or area.allowed_species.size() > 128 or _duplicates(area.allowed_species) or area.reserved.size() > 1: return fail("context_invalid")
		seen[area.region_id] = true
		if _find(regions,"region_id",area.region_id).is_empty(): return fail("context_region_missing",area.region_id)
		for encounter: Variant in area.reserved:
			schema._shape(encounter,RESERVED,"reserved",errors)
			if not errors.is_empty() or encounter.category not in ["normal","elite","rare","rare_elite","boss"] or encounter.quest_id.length() > 128: return fail("context_invalid")
			if encounter.quest_id != "" and not schema._type(encounter.quest_id,"id"): return fail("context_invalid")
			if reserved.has(encounter.encounter_id): return fail("context_invalid")
			reserved[encounter.encounter_id] = true
	return {"ok":true}

static func validate_map(value: Variant, instances: Array, mode: String, schema: Script) -> Dictionary:
	var errors: Array = []; schema._shape(value,MAP,"map.context",errors)
	if not errors.is_empty(): return fail("context_invalid")
	if value.version != 1 or value.overrides.size() > 32 or (value.biome_id != "" and not schema._type(value.biome_id,"id")): return fail("context_invalid")
	if mode != "manual" and not value.overrides.is_empty(): return fail("context_override_invalid")
	var seen := {}
	for exception: Variant in value.overrides:
		schema._shape(exception,OVERRIDE,"override",errors)
		if not errors.is_empty(): return fail("context_override_invalid")
		if seen.has(exception.instance_id) or _find(instances,"instance_id",exception.instance_id).is_empty() or exception.rules.is_empty() or exception.rules.size() > 4 or _duplicates(exception.rules) or exception.reason.strip_edges().is_empty() or exception.reason.length() > 512: return fail("context_override_invalid")
		for rule: String in exception.rules:
			if rule not in RULES: return fail("context_override_invalid")
		seen[exception.instance_id] = true
	return {"ok":true}

static func overridden(map: Dictionary, id: String, rule: String, generated: bool = false) -> bool:
	if generated or map.mode != "manual": return false
	for exception: Dictionary in map.get("context",empty_map()).overrides:
		if exception.instance_id == id and rule in exception.rules: return true
	return false

static func eligible(map: Dictionary, instance: Dictionary, piece: Dictionary, generated: bool = false) -> Dictionary:
	var context: Dictionary = piece.get("context",{})
	if context.is_empty(): return {"ok":true}
	var biome: String = map.get("context",empty_map()).biome_id
	if not context.biome_ids.is_empty() and (biome.is_empty() or biome not in context.biome_ids) and not overridden(map,instance.instance_id,"biome",generated): return fail("context_biome",instance.instance_id)
	return {"ok":true}

static func warnings(map: Dictionary) -> Array:
	var result: Array = []
	for exception: Dictionary in map.get("context",empty_map()).overrides:
		result.append({"code":"context_manual_override","severity":"warning","entity_id":exception.instance_id,"field":"context","message":"Exceção manual em %s · %s: %s"%[exception.instance_id,", ".join(exception.rules),exception.reason]})
	return result

static func _duplicates(list: Array) -> bool:
	var seen := {}
	for item: Variant in list:
		if seen.has(item): return true
		seen[item] = true
	return false
static func _find(list: Array, field: String, id: String) -> Dictionary:
	for item: Dictionary in list:
		if item[field] == id: return item
	return {}
