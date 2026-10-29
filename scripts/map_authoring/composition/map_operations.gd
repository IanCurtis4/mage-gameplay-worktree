@tool
extends RefCounted
## Closed proposals shared by the map controls and their AX presentation.
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const Borders = preload("res://scripts/map_authoring/composition/border_operations.gd")
const FIELDS := {
	"name":{"name":"string"},
	"mode/set":{"mode":"string"},
	"instance/add":{"instance_id":"id","position_xz":"v2","rotation_quarters":"number"},
	"instance/transform":{"instance_id":"id","position_xz":"v2","rotation_quarters":"number"},
	"instance/remove":{"instance_id":"id","confirm_remove":"bool"},
	"link/upsert":Document.LINK,
	"link/remove":{"link_id":"id"},
	"context/set":{"biome_id":"string","instance_id":"string","rules":"strings","reason":"string"}}

static func fail(code: String, entity: String = "") -> Dictionary:
	var message: String = {"arguments_invalid":"Revise os parâmetros da operação.","instance_missing":"Selecione uma instância existente.","duplicate_instance":"Esta identidade de instância já está em uso.","connector_missing":"Escolha uma abertura existente na peça.","link_missing":"Selecione um vínculo existente.","confirmation_required":"Confirme a remoção da instância e de suas referências.","transform_unsupported":"Use X/Z entre -16000 e 16000 e uma rotação inteira de 0 a 3."}.get(code,"Não foi possível alterar a composição.")
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":entity,"field":"composition","message":message,"suggestion":"Revise a seleção e os parâmetros antes de aplicar."}]}

static func propose(source: Dictionary, operation: String, parameters: Dictionary, piece_source: Dictionary = {}) -> Dictionary:
	if not FIELDS.has(operation): return fail("action_missing")
	var errors: Array = []
	Schema._shape(parameters,FIELDS[operation],"parameters",errors)
	if not errors.is_empty(): return fail("arguments_invalid")
	var checked := Document.validate(source)
	if not checked.ok: return checked
	var data: Dictionary = checked.data
	match operation:
		"name": data.name = parameters.name
		"mode/set":
			if parameters.mode not in ["manual","recipe"]: return fail("map_mode_unsupported")
			data.mode = parameters.mode
		"instance/add", "instance/transform":
			var position: Array = parameters.position_xz
			var rotation: float = float(parameters.rotation_quarters)
			if absf(position[0]) > 16000.0 or absf(position[1]) > 16000.0 or rotation < 0 or rotation > 3 or rotation != floor(rotation): return fail("transform_unsupported",parameters.instance_id)
			var instance := _find(data.instances,"instance_id",parameters.instance_id)
			if operation == "instance/add":
				if not instance.is_empty(): return fail("duplicate_instance",parameters.instance_id)
				var read := Schema.read(JSON.stringify(piece_source,"",true,true).to_utf8_buffer())
				if not read.ok or not read.valid: return fail("piece_source_invalid")
				if _find(data.pieces,"piece_hash",read.output_hash).is_empty(): data.pieces.append({"piece_hash":read.output_hash,"source":read.data.duplicate(true)})
				instance = {"instance_id":parameters.instance_id,"piece_hash":read.output_hash,"position_xyz":[position[0],0,position[1]],"rotation_quarters":rotation}
				data.instances.append(instance)
			else:
				if instance.is_empty(): return fail("instance_missing",parameters.instance_id)
				instance.position_xyz = [position[0],0,position[1]]; instance.rotation_quarters = rotation
		"instance/remove":
			if _find(data.instances,"instance_id",parameters.instance_id).is_empty(): return fail("instance_missing",parameters.instance_id)
			if not parameters.confirm_remove: return fail("confirmation_required",parameters.instance_id)
			data = Borders.remove_references(data,parameters.instance_id)
			data.instances = data.instances.filter(func(item: Dictionary) -> bool: return item.instance_id != parameters.instance_id)
			data.links = data.links.filter(func(item: Dictionary) -> bool: return parameters.instance_id not in [item.a_instance,item.b_instance])
			if data.has("context"): data.context.overrides = data.context.overrides.filter(func(item: Dictionary) -> bool: return item.instance_id != parameters.instance_id)
		"link/upsert":
			for side: String in ["a","b"]:
				var instance := _find(data.instances,"instance_id",parameters[side+"_instance"])
				if instance.is_empty(): return fail("instance_missing",parameters[side+"_instance"])
				var piece := _find(data.pieces,"piece_hash",instance.piece_hash)
				if _find(piece.source.connectors,"connector_id",parameters[side+"_connector"]).is_empty(): return fail("connector_missing",parameters[side+"_connector"])
			var link := _find(data.links,"link_id",parameters.link_id)
			if link.is_empty(): data.links.append(parameters.duplicate(true))
			else:
				for key: String in Document.LINK: link[key] = parameters[key]
		"link/remove":
			if _find(data.links,"link_id",parameters.link_id).is_empty(): return fail("link_missing",parameters.link_id)
			data.links = data.links.filter(func(item: Dictionary) -> bool: return item.link_id != parameters.link_id)
		"context/set":
			var context: Dictionary = data.get("context",Context.empty_map()).duplicate(true)
			context.biome_id = parameters.biome_id.strip_edges()
			if parameters.instance_id.is_empty():
				if not parameters.rules.is_empty() or not parameters.reason.is_empty(): return Context.fail("context_override_invalid")
			else:
				if _find(data.instances,"instance_id",parameters.instance_id).is_empty(): return fail("instance_missing",parameters.instance_id)
				context.overrides = context.overrides.filter(func(item: Dictionary) -> bool: return item.instance_id != parameters.instance_id)
				if not parameters.rules.is_empty(): context.overrides.append({"instance_id":parameters.instance_id,"rules":parameters.rules.duplicate(),"reason":parameters.reason.strip_edges()})
			data.context = context
	checked = Document.validate(data)
	if not checked.ok: return checked
	checked.added_ids = []; checked.removed_ids = []
	for collection: String in ["instances","links"]:
		var field: String = "instance_id" if collection == "instances" else "link_id"
		for item: Dictionary in data[collection]:
			if _find(source[collection],field,item[field]).is_empty(): checked.added_ids.append(item[field])
		for item: Dictionary in source[collection]:
			if _find(data[collection],field,item[field]).is_empty(): checked.removed_ids.append(item[field])
	checked.entity_id = parameters.get("instance_id",parameters.get("link_id",data.document_id))
	return checked

static func _find(items: Array, field: String, id: String) -> Dictionary:
	for item: Dictionary in items:
		if item[field] == id: return item
	return {}
