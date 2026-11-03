@tool
extends RefCounted
## Closed population proposals shared by GUI and AX; compilation owns gameplay validity.
const Document = preload("res://scripts/map_authoring/population/population_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const FIELDS := {
	"name":{"name":"string"},
	"entrance/set":Document.ANCHOR,
	"brush/upsert":Document.BRUSH,
	"brush/remove":{"brush_id":"id","confirm_remove":"bool"},
	"exclusion/upsert":Document.EXCLUSION,
	"exclusion/remove":{"exclusion_id":"id","confirm_remove":"bool"},
	"interaction/upsert":Document.INTERACTION,
	"interaction/remove":{"interaction_id":"id","confirm_remove":"bool"},
	"slot/upsert":Document.SLOT,
	"slot/pin":{"slot_id":"id","fixed":"bool"},
	"slot/remove":{"slot_id":"id","confirm_remove":"bool"}}
const IDS := {"brushes":"brush_id","exclusions":"exclusion_id","interactions":"interaction_id","slots":"slot_id"}

static func fail(code: String, entity: String = "") -> Dictionary:
	var messages := {"arguments_invalid":"Revise os parâmetros da operação.","entity_missing":"Selecione uma identidade existente.","confirmation_required":"Confirme a alteração antes de aplicar.","slot_fixed_required":"Um slot colocado manualmente deve ser fixado.","history_empty":"Não há ação para desfazer ou refazer.","job_running":"Aguarde ou cancele o trabalho atual.","io_recovery_required":"Não foi possível preservar o rascunho.","map_already_present":"Crie um novo encontro para importar outro snapshot sem perder autoria."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"entity_id":entity,"field":"population","severity":"error","message":messages.get(code,"Não foi possível concluir a operação: "+code)}]}

static func propose(source: Dictionary, operation: String, parameters: Dictionary) -> Dictionary:
	if not FIELDS.has(operation): return fail("action_missing")
	var errors: Array = []
	Schema._shape(parameters,Document._fields("brushes",FIELDS[operation],parameters) if operation == "brush/upsert" else FIELDS[operation],"parameters",errors)
	if not errors.is_empty(): return fail("arguments_invalid")
	var checked := Document.validate(source)
	if not checked.ok: return checked
	var data: Dictionary = checked.data
	var entity: String = data.document_id
	if operation == "name": data.name = parameters.name
	elif operation == "entrance/set": data.entrance = [parameters.duplicate(true)]
	else:
		var collection: String = {"brush":"brushes","exclusion":"exclusions","interaction":"interactions","slot":"slots"}[operation.get_slice("/",0)]
		var field: String = IDS[collection]
		entity = parameters[field]
		var current := find(data[collection],field,entity)
		match operation.get_slice("/",1):
			"upsert":
				if collection == "slots" and not parameters.fixed: return fail("slot_fixed_required",entity)
				if current.is_empty(): data[collection].append(parameters.duplicate(true))
				else:
					for key: String in parameters: current[key] = parameters[key].duplicate(true) if parameters[key] is Array or parameters[key] is Dictionary else parameters[key]
			"pin":
				if current.is_empty(): return fail("entity_missing",entity)
				current.fixed = parameters.fixed
			"remove":
				if current.is_empty(): return fail("entity_missing",entity)
				if not parameters.confirm_remove: return fail("confirmation_required",entity)
				data[collection] = data[collection].filter(func(item: Dictionary) -> bool: return item[field] != entity)
				if collection == "brushes": data.slots = data.slots.filter(func(item: Dictionary) -> bool: return item.brush_id != entity)
	checked = Document.validate(data)
	if not checked.ok: return checked
	checked.entity_id = entity; checked.input_hash = Document.hash_source(source)
	checked.added_ids = []; checked.removed_ids = []
	for collection: String in IDS:
		var field: String = IDS[collection]
		for item: Dictionary in data[collection]:
			if find(source[collection],field,item[field]).is_empty(): checked.added_ids.append(item[field])
		for item: Dictionary in source[collection]:
			if find(data[collection],field,item[field]).is_empty(): checked.removed_ids.append(item[field])
	return checked

static func find(items: Array, field: String, id: String) -> Dictionary:
	for item: Dictionary in items:
		if item[field] == id: return item
	return {}

static func query_package(package: Dictionary) -> Dictionary:
	var stages: Array = package.get("manifest",{}).get("stages",[])
	if stages.size() != 1: return fail("map_missing")
	var surfaces: Array = []; var sockets: Array = []
	for cell: Dictionary in stages[0].surfaces:
		var vertices: Array = []
		for point: Vector3 in cell.vertices: vertices.append([point.x,point.y,point.z])
		surfaces.append({"surface_id":cell.surface_id,"vertices_xyz":vertices})
	for socket: Dictionary in stages[0].sockets:
		var point: Vector3 = socket.position
		sockets.append({"socket_id":socket.socket_id,"surface_id":socket.surface_id,"kind":socket.kind,"position_xyz":[point.x,point.y,point.z]})
	return {"ok":true,"map_source_hash":package.source_hash,"map_package_hash":package.package_hash,"biome":stages[0].get("biome",""),"surfaces":surfaces,"sockets":sockets}
