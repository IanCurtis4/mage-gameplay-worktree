@tool
extends RefCounted
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const JSONReader = preload("res://scripts/map_authoring/io/strict_json.gd")
const ROOT := {"schema_version":"int","algorithm_revision":"string","map":"dictionary","seed_text":"string","domains":"array","pins":"strings","selection":"strings","quotas":"array","min_diversity":"number","budget":"dictionary"}
const OPTION := {"piece_hash":"hash","rotation_quarters":"number","weight":"number"}
const REVISION := "map_slot_wfc_v1"

static func fail(code: String, entity: String = "", field: String = "generation") -> Dictionary:
	var messages := {"generation_invalid":"Revise os dados da geração.","generation_version":"Versão de geração indisponível.","generation_seed":"Informe uma seed decimal signed64 sem zeros à esquerda.","generation_domain":"Revise os candidatos da região.","generation_reference":"Há uma referência ausente ou repetida.","generation_limit":"O pedido excede os limites da geração.","contradiction":"Não há combinação que preserve estas restrições.","budget_exhausted":"O orçamento global terminou; nenhuma proposta foi aplicada.","cancelled":"Geração cancelada; autoria preservada.","stale_source":"A fonte mudou. Gere novamente.","assembler_unsupported":"O assembler atual não representa este grafo.","assembler_constraint":"O assembler não preservou as restrições autoradas.","experimental_disabled":"Ative explicitamente o solver experimental."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"entity_id":entity,"field":field,"severity":"error","message":messages.get(code,"Revise a geração: "+code)}]}

static func _shape(value: Variant, fields: Dictionary) -> bool:
	if not value is Dictionary or value.size() != fields.size(): return false
	for key: String in fields:
		if not value.has(key): return false
		if fields[key] == "dictionary":
			if not value[key] is Dictionary: return false
		elif not Schema._type(value[key],fields[key]): return false
	return true

static func _integer(value: Variant, low: int, high: int) -> bool:
	return Schema._type(value,"number") and value == floor(value) and value >= low and value <= high

static func from_map(map: Dictionary) -> Dictionary:
	var domains: Array = []; var selection: Array = []
	for instance: Dictionary in map.instances:
		domains.append({"instance_id":instance.instance_id,"options":[{"piece_hash":instance.piece_hash,"rotation_quarters":instance.rotation_quarters,"weight":1}]})
		selection.append(instance.instance_id)
	return {"schema_version":1,"algorithm_revision":REVISION,"map":map.duplicate(true),"seed_text":"0","domains":domains,"pins":[],"selection":selection,"quotas":[],"min_diversity":1,"budget":{"operations":200000,"backtracks":128,"validations":32}}

static func read(bytes: PackedByteArray) -> Dictionary:
	var decoded := JSONReader.new().decode(bytes)
	return validate(decoded.value) if decoded.ok else fail(decoded.code)

static func validate(value: Variant) -> Dictionary:
	if not _shape(value,ROOT): return fail("generation_invalid")
	if value.schema_version != 1 or value.algorithm_revision != REVISION: return fail("generation_version")
	if value.seed_text != str(value.seed_text.to_int()): return fail("generation_seed","","seed_text")
	var checked := Map.validate(value.map)
	if not checked.ok: return checked
	if value.map.mode != "manual": return fail("generation_invalid","","map.mode")
	if value.map.instances.is_empty() or value.map.instances.size() > 16 or value.domains.size() != value.map.instances.size(): return fail("generation_limit")
	var pieces := {}; var ids := {}; var seen := {}
	for piece: Dictionary in value.map.pieces: pieces[piece.piece_hash] = true
	for instance: Dictionary in value.map.instances: ids[instance.instance_id] = true
	for domain: Variant in value.domains:
		if not _shape(domain,{"instance_id":"id","options":"array"}): return fail("generation_domain")
		var id: String = domain.instance_id
		if not ids.has(id) or seen.has(id): return fail("generation_reference",id)
		seen[id] = true
		if domain.options.is_empty() or domain.options.size() > 16: return fail("generation_domain",id)
		var options := {}
		for option: Variant in domain.options:
			if not _shape(option,OPTION): return fail("generation_domain",id)
			if not pieces.has(option.piece_hash) or not _integer(option.rotation_quarters,0,3) or not _integer(option.weight,1,100): return fail("generation_domain",id)
			var key: String = option.piece_hash+"/"+str(int(option.rotation_quarters))
			if options.has(key): return fail("generation_domain",id)
			options[key] = true
	for collection: String in ["pins","selection"]:
		seen.clear()
		for id: String in value[collection]:
			if not ids.has(id) or seen.has(id): return fail("generation_reference",id,collection)
			seen[id] = true
	if not _integer(value.min_diversity,1,value.map.instances.size()) or value.quotas.size() > 32: return fail("generation_limit")
	seen.clear()
	for quota: Variant in value.quotas:
		if not _shape(quota,{"piece_hash":"hash","min":"number","max":"number"}): return fail("generation_invalid","","quotas")
		if not pieces.has(quota.piece_hash) or seen.has(quota.piece_hash) or not _integer(quota.min,0,16) or not _integer(quota.max,int(quota.min),16): return fail("generation_invalid","","quotas")
		seen[quota.piece_hash] = true
	if not _shape(value.budget,{"operations":"number","backtracks":"number","validations":"number"}): return fail("generation_invalid","","budget")
	for key: String in ["operations","backtracks","validations"]:
		if not _integer(value.budget[key],0 if key == "backtracks" else 1,{"operations":200000,"backtracks":256,"validations":64}[key]): return fail("generation_limit","",key)
	return {"ok":true,"code":"","data":value.duplicate(true),"output_hash":hash_source(value)}

static func hash_source(value: Dictionary) -> String:
	var copy := value.duplicate(true)
	copy.map = Map.hash_source(copy.map)
	copy.domains.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	for domain: Dictionary in copy.domains:
		domain.options.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return option_key(a) < option_key(b))
	copy.pins.sort(); copy.selection.sort()
	copy.quotas.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.piece_hash < b.piece_hash)
	return Schema.semantic_hash(copy)

static func option_key(option: Dictionary) -> String: return option.piece_hash+"/"+str(int(option.rotation_quarters))

static func domains(value: Dictionary) -> Dictionary:
	var result := {}
	var sorted: Array = value.map.instances.duplicate(true)
	sorted.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	for instance: Dictionary in sorted:
		var options: Array = []
		for domain: Dictionary in value.domains:
			if domain.instance_id == instance.instance_id: options = domain.options.duplicate(true)
		if instance.instance_id in value.pins or instance.instance_id not in value.selection:
			options = options.filter(func(o: Dictionary) -> bool: return o.piece_hash == instance.piece_hash and o.rotation_quarters == instance.rotation_quarters)
		options.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return option_key(a) < option_key(b))
		result[instance.instance_id] = options
	return result
