@tool
extends RefCounted
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const Borders = preload("res://scripts/map_authoring/composition/border_operations.gd")
const ROOT := {"schema_version":"int","document_id":"id","revision":"int","name":"string","mode":"id","barrier_profile":"id","pieces":"array","instances":"array","links":"array"}
const INSTANCE := {"instance_id":"id","piece_hash":"hash","position_xyz":"v3","rotation_quarters":"number"}
const LINK := {"link_id":"id","a_instance":"id","a_connector":"id","b_instance":"id","b_connector":"id"}

static func empty(id: String = "map") -> Dictionary:
	return {"schema_version":1,"document_id":id,"revision":1,"name":"Novo mapa","mode":"manual","barrier_profile":"ruin_envelope_v1","pieces":[],"instances":[],"links":[]}

static func hash_source(data: Dictionary) -> String:
	var normalized := data.duplicate(true)
	for collection: String in ["pieces","instances","links"]:
		var key: String = {"pieces":"piece_hash","instances":"instance_id","links":"link_id"}[collection]
		normalized[collection].sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a[key] < b[key])
	if normalized.has("borders"): normalized.borders = Borders.normalized(normalized.borders)
	return Schema.semantic_hash(normalized)

static func read(bytes: PackedByteArray) -> Dictionary:
	var decoded := StrictJSON.new().decode(bytes)
	if not decoded.ok: return Schema.result(false,decoded.code)
	return validate(decoded.value)

static func validate(data: Variant) -> Dictionary:
	var errors: Array = []
	var root_fields := ROOT.duplicate(); if data is Dictionary and data.has("context"): root_fields.context = "object"
	if data is Dictionary and data.has("borders"): root_fields.borders = "object"
	# Checkpoint46 (P3d): receipts only at the root map, never inside a snapshot.
	if data is Dictionary and data.has("synthesis_receipts"): root_fields.synthesis_receipts = "array"
	Schema._shape(data,root_fields,"map",errors)
	if errors.is_empty() and data.has("synthesis_receipts") and not load("res://scripts/map_authoring/synthesis/receipt_schema.gd").valid(data.synthesis_receipts): return Schema.result(false,"receipts_invalid")
	if not errors.is_empty(): return Schema.result(false,"map_invalid",errors)
	if data.schema_version != 1: return Schema.result(false,"map_version_unsupported")
	if data.mode not in ["manual","recipe"]: return Schema.result(false,"map_mode_unsupported")
	if data.pieces.size() > 32 or data.instances.size() > 32 or data.links.size() > 64: return Schema.result(false,"map_limit")
	var pieces: Dictionary = {}; var instances: Dictionary = {}; var links: Dictionary = {}
	for piece: Variant in data.pieces:
		if not piece is Dictionary or piece.size() != 2 or not Schema._type(piece.get("piece_hash"),"hash") or not piece.get("source") is Dictionary: return Schema.result(false,"piece_invalid")
		if piece.source.has("synthesis_receipts"): return Schema.result(false,"receipts_nested")
		var source := Schema.read(JSON.stringify(piece.source,"",true,true).to_utf8_buffer())
		if not source.ok or not source.valid: return Schema.result(false,"piece_source_invalid",source.get("diagnostics",[]))
		if source.output_hash != piece.piece_hash: return Schema.result(false,"piece_hash_mismatch")
		if pieces.has(piece.piece_hash): return Schema.result(false,"duplicate_piece")
		pieces[piece.piece_hash] = true
	for instance: Variant in data.instances:
		Schema._shape(instance,INSTANCE,"instance",errors)
		if not errors.is_empty(): return Schema.result(false,"instance_invalid",errors)
		if instances.has(instance.instance_id): return Schema.result(false,"duplicate_instance")
		if not pieces.has(instance.piece_hash): return Schema.result(false,"piece_reference_missing")
		if instance.rotation_quarters != floor(instance.rotation_quarters) or instance.rotation_quarters < 0 or instance.rotation_quarters > 3 or instance.position_xyz[1] != 0: return Schema.result(false,"transform_unsupported")
		instances[instance.instance_id] = true
	if data.has("context"):
		var checked := Context.validate_map(data.context,data.instances,data.mode,Schema)
		if not checked.ok: return checked
	if data.has("borders"):
		var checked := Borders.validate(data.borders,data.instances)
		if not checked.ok: return checked
	for link: Variant in data.links:
		Schema._shape(link,LINK,"link",errors)
		if not errors.is_empty(): return Schema.result(false,"link_invalid",errors)
		if links.has(link.link_id): return Schema.result(false,"duplicate_link")
		if link.a_instance == link.b_instance or not instances.has(link.a_instance) or not instances.has(link.b_instance): return Schema.result(false,"link_reference_missing")
		links[link.link_id] = true
	var result := Schema.result(true)
	result.data = data.duplicate(true); result.output_hash = hash_source(data)
	return result

static func sample() -> Dictionary:
	var source := Piece.empty("room")
	source.layers = [{"layer_id":"floor","name":"Chão","origin_xz":[0,0],"sample_spacing":100,"columns":2,"rows":2,"heights":[0,0,0,0],"material_masks":{},"locked":false,"protected_regions":[]}]
	for side: String in ["west","east"]:
		source.connectors.append({"connector_id":side,"surface_id":"floor","position_xyz":[0 if side == "west" else 100,0,50],"normal_xyz":[-1 if side == "west" else 1,0,0],"kind":"walk","width":80,"headroom":100,"tags":["ruin"],"direction":"both"})
	# Terminal pieces have only their inward opening: external edges remain closed.
	var left := source.duplicate(true); left.document_id = "room_left"; left.connectors.remove_at(0)
	var right := source.duplicate(true); right.document_id = "room_right"; right.connectors.remove_at(1)
	var data := empty("two_rooms"); data.name = "Duas peças · Ruína"
	var a := Schema.semantic_hash(left); var b := Schema.semantic_hash(right)
	data.pieces = [{"piece_hash":a,"source":left},{"piece_hash":b,"source":right}]
	data.instances = [{"instance_id":"left","piece_hash":a,"position_xyz":[0,0,0],"rotation_quarters":0},{"instance_id":"right","piece_hash":b,"position_xyz":[100,0,0],"rotation_quarters":0}]
	data.links = [{"link_id":"door","a_instance":"left","a_connector":"east","b_instance":"right","b_connector":"west"}]
	return data
