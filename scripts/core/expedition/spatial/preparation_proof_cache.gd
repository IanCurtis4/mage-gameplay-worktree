class_name PreparationProofCache
extends RefCounted
## Passive positive witnesses only. Every disk hit is geometrically verified in
## the requesting world; no boolean verdict or live object is loaded from disk.
const REVISION := "preparation_proof_v1"
const MAX_FILE_BYTES := 16 * 1024 * 1024
const MAX_PROOFS := 32
const MAX_NODES := 32768
const MAX_TARGETS := 4096
const MAX_VIA := 4096
const MAX_VALUES := 1000000
static var _mutex := Mutex.new()
static var _recording := false
static var _overflow := false
static var _recorded: Array = []
static var _loaded: Array = []

static func clear() -> void:
	_mutex.lock()
	_recording = false; _overflow = false; _recorded = []; _loaded = []
	_mutex.unlock()

static func begin_recording() -> void:
	_mutex.lock()
	_recorded = []; _overflow = false; _recording = true
	_mutex.unlock()

static func end_recording() -> Dictionary:
	_mutex.lock()
	_recording = false
	var result: Dictionary = {} if _overflow else {"format_version":1,"revision":REVISION,"proofs":_recorded.duplicate(true)}
	_recorded = []
	_mutex.unlock()
	return result

static func _namespace(value: Variant, stage: String, replacement: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			if key in ["stage_id","from_stage","to_stage"] and value[key] is String and value[key] == stage: value[key] = replacement
			else: _namespace(value[key],stage,replacement)
	elif value is Array:
		for item: Variant in value: _namespace(item,stage,replacement)

static func _key(world: WorldGeometry, root: ExpeditionWorldPoint, profile: Dictionary) -> String:
	var stage: Dictionary = world._stage.duplicate(true)
	stage.erase("sockets"); stage.erase("entrance")
	var stage_id := String(world._stage.stage_id)
	_namespace(stage,stage_id,"")
	var origin := root.to_data(); _namespace(origin,stage_id,"")
	var segments := {}
	for id: String in world._segments: segments[id] = world._segments[id].geometry_record()
	_namespace(segments,stage_id,"")
	var hashed := WorldConnectivityBatch._hash({"proof_revision":REVISION,"navigation_revision":WorldConnectivityBatch.REVISION,"engine":Engine.get_version_info().string,"stage":stage,"temporary":world._temporary,"slabs":world._solid_slabs,"segments":segments,"profile":profile,"root":origin})
	return String(hashed.hash) if hashed.ok else ""

static func _retain(data: Dictionary, targets: Array, outward: bool, nodes: Dictionary) -> Dictionary:
	var result := {}; var all: Dictionary = data.outward_previous if outward else data.inward_previous
	for target: Dictionary in targets:
		var cursor: String = target.node_id; var seen := {}
		while cursor != "@root" and not result.has(cursor):
			if seen.has(cursor) or not all.has(cursor) or not data.states.has(cursor): return {"ok":false}
			seen[cursor] = true
			var row: Dictionary = all[cursor]
			if not data.states.has(row.from): return {"ok":false}
			nodes[cursor] = data.states[cursor].duplicate(true)
			nodes[row.from] = data.states[row.from].duplicate(true)
			result[cursor] = row.duplicate(true); cursor = row.from
	return {"ok":true,"previous":result}

static func record(world: WorldGeometry, root: ExpeditionWorldPoint, targets: Array[ExpeditionWorldPoint], profile: Dictionary, certificate: Dictionary) -> void:
	_mutex.lock(); var enabled := _recording; _mutex.unlock()
	if not enabled or not certificate.get("ok",false) or not certificate.get("data") is Dictionary: return
	var data: Dictionary = certificate.data
	if not data.get("complete",false) or not data.get("all_reachable",false) or data.targets.size() != targets.size(): return
	var key := _key(world,root,profile)
	if key.is_empty(): return
	var nodes := {"@root":root.to_data()}
	var outward := _retain(data,data.targets,true,nodes)
	var inward := _retain(data,data.targets,false,nodes)
	if not outward.ok or not inward.ok: return
	var endpoints: Array = []
	for index: int in targets.size():
		if data.targets[index].point != targets[index].to_data(): return
		endpoints.append({"node_id":data.targets[index].node_id,"point":targets[index].to_data()})
	var proof := {"key":key,"root":root.to_data(),"profile":profile.duplicate(true),"targets":endpoints,"nodes":nodes,"outward":outward.previous,"inward":inward.previous}
	_namespace(proof,String(world._stage.stage_id),"")
	if not _valid_proof(proof): return
	_mutex.lock()
	if _recording:
		if proof not in _recorded:
			if _recorded.size() >= MAX_PROOFS or var_to_bytes(_recorded).size()+var_to_bytes(proof).size() > MAX_FILE_BYTES-1024: _overflow = true
			else: _recorded.append(proof)
	_mutex.unlock()

static func _shape(value: Variant, keys: Array) -> bool:
	return value is Dictionary and value.size() == keys.size() and value.has_all(keys)

static func _hash_string(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for c: String in value:
		if c not in "0123456789abcdef": return false
	return true

static func _point(value: Variant) -> bool:
	return _shape(value,["stage_id","surface_id","position"]) and value.stage_id == "" and value.surface_id is String and value.surface_id.length() <= 1024 and value.position is Vector3 and value.position.is_finite()

static func _passive(value: Variant, state: Array[int], depth: int = 0) -> bool:
	state[0] += 1
	if depth > 32 or state[0] > MAX_VALUES: return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT: return true
		TYPE_FLOAT: return is_finite(value)
		TYPE_STRING: return value.length() <= 4096
		TYPE_VECTOR3: return value.is_finite()
		TYPE_ARRAY:
			if value.size() > MAX_NODES: return false
			for child: Variant in value:
				if not _passive(child,state,depth+1): return false
			return true
		TYPE_DICTIONARY:
			if value.size() > MAX_NODES: return false
			for key: Variant in value:
				if not key is String or key.length() > 4096 or not _passive(value[key],state,depth+1): return false
			return true
	return false

static func _previous(previous: Variant, nodes: Dictionary, outward: bool) -> bool:
	if not previous is Dictionary or previous.size() > MAX_NODES: return false
	for id: String in previous:
		var row: Variant = previous[id]
		if id == "@root" or not nodes.has(id) or not _shape(row,["from","edge"]) or not row.from is String or not nodes.has(row.from): return false
		var edge: Variant = row.edge
		if not edge is Dictionary or not edge.has_all(["to","via","connection_id","cost"]) or edge.size() not in [4,5]: return false
		if edge.size() == 5 and not edge.has("connection_ids"): return false
		if not edge.to is String or edge.to != (id if outward else row.from) or not nodes.has(edge.to): return false
		if not edge.connection_id is String or not edge.via is Array or edge.via.size() > MAX_VIA or not (edge.cost is float or edge.cost is int) or not is_finite(float(edge.cost)) or edge.cost < 0: return false
		for point: Variant in edge.via:
			if not _point(point): return false
		if edge.has("connection_ids"):
			if not edge.connection_ids is Array or edge.connection_ids.size() > MAX_VIA: return false
			for connection: Variant in edge.connection_ids:
				if not connection is String: return false
	# Every predecessor terminates at the root; memoize completed chains to avoid
	# quadratic validation of shared trunks and reject cycles before geometry work.
	var done := {"@root":true}
	for id: String in previous:
		var cursor := id; var chain: Array[String] = []; var seen := {}
		while not done.has(cursor):
			if seen.has(cursor) or not previous.has(cursor): return false
			seen[cursor] = true; chain.append(cursor); cursor = previous[cursor].from
		for node: String in chain: done[node] = true
	return true

static func _valid_proof(proof: Variant) -> bool:
	if not _shape(proof,["key","root","profile","targets","nodes","outward","inward"]) or not _hash_string(proof.key) or not _point(proof.root): return false
	if not proof.profile is Dictionary or not proof.targets is Array or proof.targets.size() > MAX_TARGETS or not proof.nodes is Dictionary or proof.nodes.is_empty() or proof.nodes.size() > MAX_NODES or proof.nodes.get("@root") != proof.root: return false
	var state: Array[int] = [0]
	if not _passive(proof,state): return false
	for id: String in proof.nodes:
		if not _point(proof.nodes[id]): return false
	if not _previous(proof.outward,proof.nodes,true) or not _previous(proof.inward,proof.nodes,false): return false
	for target: Variant in proof.targets:
		if not _shape(target,["node_id","point"]) or not target.node_id is String or not _point(target.point) or proof.nodes.get(target.node_id) != target.point: return false
		if target.node_id != "@root" and (not proof.outward.has(target.node_id) or not proof.inward.has(target.node_id)): return false
	return true

static func _valid_bundle(bundle: Variant) -> bool:
	if not _shape(bundle,["format_version","revision","proofs"]) or not bundle.format_version is int or bundle.format_version != 1 or bundle.revision != REVISION or not bundle.proofs is Array or bundle.proofs.size() > MAX_PROOFS: return false
	for proof: Variant in bundle.proofs:
		if not _valid_proof(proof): return false
	return true

static func save(path: String, package_hash: String, bundle: Dictionary) -> bool:
	if not _hash_string(package_hash) or not _valid_bundle(bundle): return false
	var payload := var_to_bytes({"package_hash":package_hash,"bundle":bundle})
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(payload)
	var bytes := ("RNP1"+digest.finish().hex_encode()).to_utf8_buffer()+payload
	if bytes.size() > MAX_FILE_BYTES: return false
	var pending := path+".pending"
	if FileAccess.file_exists(pending): return false
	var file := FileAccess.open(pending,FileAccess.WRITE)
	if file == null: return false
	file.store_buffer(bytes); file.flush(); file.close()
	var staged := FileAccess.get_file_as_bytes(pending)
	if staged != bytes: DirAccess.remove_absolute(pending); return false
	return DirAccess.rename_absolute(pending,path) == OK

static func load(path: String, expected_package_hash: String) -> bool:
	if not _hash_string(expected_package_hash): return false
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return false
	var length := file.get_length()
	if length < 76 or length > MAX_FILE_BYTES: file.close(); return false
	var bytes := file.get_buffer(length); file.close()
	if bytes.size() != length: return false
	if bytes.slice(0,4).get_string_from_utf8() != "RNP1": return false
	var payload := bytes.slice(68)
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(payload)
	if digest.finish().hex_encode() != bytes.slice(4,68).get_string_from_utf8(): return false
	if payload.size() < 8 or payload.decode_u32(0) != TYPE_DICTIONARY: return false
	var decoded: Variant = bytes_to_var(payload)
	if not _shape(decoded,["package_hash","bundle"]) or decoded.package_hash != expected_package_hash or not _valid_bundle(decoded.bundle): return false
	_mutex.lock()
	for proof: Dictionary in decoded.bundle.proofs:
		if proof in _loaded: continue
		var size := var_to_bytes(proof).size()
		while not _loaded.is_empty() and (_loaded.size() >= MAX_PROOFS or var_to_bytes(_loaded).size()+size > MAX_FILE_BYTES): _loaded.pop_front()
		_loaded.append(proof)
	_mutex.unlock()
	return true

static func try_certificate(world: WorldGeometry, root: ExpeditionWorldPoint, targets: Array[ExpeditionWorldPoint], profile: Dictionary, revision: int, ctx: Dictionary) -> Dictionary:
	_mutex.lock(); var recording := _recording; var proofs: Array = _loaded.duplicate(); _mutex.unlock()
	if recording or proofs.is_empty(): return {}
	var key := _key(world,root,profile)
	if key.is_empty(): return {}
	var stage_id := String(world._stage.stage_id)
	for cached: Dictionary in proofs:
		if cached.key != key or cached.profile != profile: continue
		var proof: Dictionary = cached.duplicate(true)
		_namespace(proof,"",stage_id)
		if proof.root != root.to_data(): continue
		var ids: Array[String] = []; var covered := true
		for point: ExpeditionWorldPoint in targets:
			var id := ""
			if point.to_data() == proof.root: id = "@root"
			else:
				for endpoint: Dictionary in proof.targets:
					if endpoint.point == point.to_data(): id = endpoint.node_id; break
			if id.is_empty(): covered = false; break
			ids.append(id)
		if not covered: continue
		# A rejected optional proof must not seed the normal search's memos or
		# spend its counters. Elapsed wall time still belongs to the operation.
		var trial: Dictionary = ctx.duplicate()
		trial.metrics = ctx.metrics.duplicate(true)
		if not WorldConnectivityBatch.reserve(trial,proof,2): return WorldConnectivityBatch.failed(world,trial)
		trial.point_proofs = {}; trial.segment_proofs = {}
		if not WorldConnectivityBatch.route_valid(world,[proof.root],profile,trial):
			if not trial.error_code.is_empty(): return WorldConnectivityBatch.failed(world,trial)
			continue
		var done := [{"@root":true},{"@root":true}]; var valid := true
		for id: String in ids:
			if not WorldConnectivityBatch._tree_valid(world,proof.nodes,proof.outward,id,true,done[0],profile,trial) or not WorldConnectivityBatch._tree_valid(world,proof.nodes,proof.inward,id,false,done[1],profile,trial): valid = false; break
		if not valid:
			if not trial.error_code.is_empty(): return WorldConnectivityBatch.failed(world,trial)
			continue
		if not WorldConnectivityBatch.tick(trial,"operations",1,true): return WorldConnectivityBatch.failed(world,trial)
		var signature := WorldConnectivityBatch.signature(world)
		if not signature.ok or signature.hash != trial.snapshot_hash or not world._current(revision) or world.configuration_revision != trial.configuration: return WorldConnectivityBatch.failed(world,trial,&"stale_geometry")
		var results: Array = []
		for index: int in targets.size(): results.append({"input_index":index,"point":targets[index].to_data(),"node_id":ids[index],"outward_reachable":true,"inward_reachable":true})
		if not WorldConnectivityBatch.reserve(trial,results,2): return WorldConnectivityBatch.failed(world,trial)
		trial.metrics["preparation_proof"] = "verified"
		trial.metrics["elapsed_ms"] = (Time.get_ticks_usec()-int(trial.started))/1000.0
		return world._success({"complete":true,"all_reachable":true,"configuration_revision":world.configuration_revision,"profile_hash":trial.profile_hash,"profile":profile.duplicate(true),"graph_revision":WorldConnectivityBatch.REVISION,"snapshot_hash":trial.snapshot_hash,"targets":results,"states":proof.nodes,"outward_previous":proof.outward,"inward_previous":proof.inward,"metrics":trial.metrics})
	return {}
