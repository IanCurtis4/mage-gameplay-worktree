@tool
extends RefCounted
## Passive JSON only. Virtual filenames are never resolved or extracted.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Reader = preload("res://scripts/map_authoring/io/strict_json.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_document.gd")
const Patrol = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Generation = preload("res://scripts/map_authoring/generation/generation_document.gd")
const TerrainCompiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const PopulationCompiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const REVISION := "map_exchange_v1"
const KINDS := ["piece","map","population","patrol","generation"]
const IDS := ["placement_id","connector_id","socket_id","region_id","slot_id","patrol_id","point_id","brush_id","exclusion_id","interaction_id","instance_id","link_id","layer_id","definition_id","piece_hash","surface_id"]
const REVISIONS := {"piece":"map_terrain_v2","map":"map_composition_v1","population":PopulationCompiler.REVISION,"patrol":"map_patrol_v1","generation":"map_slot_wfc_v1"}

static func fail(code: String) -> Dictionary:
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"message":"Intercâmbio recusado: "+code,"severity":"error"}]}
static func digest(value: Variant) -> String: return Schema.bytes_hash(Schema._canonical(value).to_utf8_buffer())
static func shape(value: Variant, keys: Array) -> bool: return value is Dictionary and value.size() == keys.size() and value.has_all(keys)
static func read(kind: String, data: Variant) -> Dictionary:
	if kind not in KINDS or not data is Dictionary: return fail("exchange_kind")
	var bytes := JSON.stringify(data,"",true,true).to_utf8_buffer()
	var result: Dictionary
	match kind:
		"piece": result = Schema.read(bytes)
		"map": result = Map.read(bytes)
		"population": result = Population.read(bytes)
		"patrol": result = Patrol.read(bytes)
		_: result = Generation.read(bytes)
	if result.ok and not result.get("valid",true): return fail("source_invalid")
	return result
static func build(kind: String, data: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	match kind:
		"piece": return TerrainCompiler.compile(data,cancellation)
		"map": return MapCompiler.compile(data,cancellation)
		"population": return PopulationCompiler.compile(data,cancellation)
		"patrol": return PatrolCompiler.compile(data,cancellation)
		"generation":
			# Import never opts into WFC or rerolls authored content.
			return MapCompiler.compile(data.map,cancellation)
	return fail("exchange_kind")
static func load_json(path: String) -> Dictionary:
	var raw := IO._bytes(path)
	if not raw.ok: return raw
	var decoded := Reader.new().decode(raw.bytes)
	if not decoded.ok: return decoded
	return {"ok":true,"code":"","data":decoded.value}
static func save_json(path: String, value: Dictionary, expected: String = "") -> Dictionary:
	var bytes := JSON.stringify(value,"\t",true,true).to_utf8_buffer()
	if bytes.size() > Reader.MAX_BYTES: return fail("exchange_limit")
	if not DirAccess.dir_exists_absolute(path.get_base_dir()): return fail("io_failure")
	var lock := path+".writer_lock"
	if DirAccess.make_dir_absolute(lock) != OK: return fail("io_writer_locked")
	var result := _save_locked(path,bytes,expected)
	DirAccess.remove_absolute(lock)
	return result
static func _save_locked(path: String, bytes: PackedByteArray, expected: String) -> Dictionary:
	if IO.disk_hash(path) != expected: return fail("io_conflict")
	if FileAccess.file_exists(path+".pending"): return fail("io_recovery_pending")
	if not IO._write(path+".pending",bytes): return fail("io_failure")
	if IO.disk_hash(path) != expected: return fail("io_conflict")
	if DirAccess.rename_absolute(path+".pending",path) != OK: return fail("io_failure")
	return {"ok":true,"code":"","output_hash":Schema.bytes_hash(bytes)}
static func policy(sections: Array, ids: Array = [], protected_paths: Array = [], max_changes: int = 256) -> Dictionary:
	return {"sections":sections,"ids":ids,"protected_paths":protected_paths,"max_changes":max_changes}
static func valid_policy(value: Variant) -> bool:
	if not shape(value,["sections","ids","protected_paths","max_changes"]): return false
	if not value.sections is Array or not value.ids is Array or not value.protected_paths is Array: return false
	if value.sections.is_empty() or value.sections.size() > 32 or value.ids.size() > 128 or value.protected_paths.size() > 128: return false
	if not Schema._type(value.max_changes,"number") or value.max_changes != floor(value.max_changes) or value.max_changes < 1 or value.max_changes > 2048: return false
	for entry: Variant in value.sections+value.ids:
		if not Schema._type(entry,"id"): return false
	for path: Variant in value.protected_paths:
		if not path is String or not path.begins_with("/") or ".." in path or "\\" in path or path.length() > 512: return false
	return true
static func export_bundle(kind: String, source: Dictionary, permissions: Dictionary, brief: String, corpus: Array = [], cancellation: Callable = Callable()) -> Dictionary:
	var checked := read(kind,source)
	if not checked.ok: return checked
	if not valid_policy(permissions) or brief.length() > 8192 or corpus.size() > 32: return fail("exchange_policy")
	for seed_value: Variant in corpus:
		if not seed_value is String or seed_value != str(seed_value.to_int()): return fail("exchange_seed")
	var compiled := build(kind,source,cancellation)
	if not compiled.ok: return compiled
	var ticket := {"exchange_version":1,"compiler_revision":REVISIONS[kind],"kind":kind,"base_hash":checked.output_hash,"policy":permissions.duplicate(true),"brief":brief,"corpus":corpus.duplicate(),"base":source.duplicate(true)}
	return _bundle(ticket,source,compiled)
static func report_for(kind: String, compiled: Dictionary) -> Dictionary:
	var package: Dictionary = compiled.package
	return {"ok":true,"code":"","compiled_hash":compiled.output_hash,"compiler_revision":REVISIONS[kind],"dependencies":package.get("dependencies",[]),"catalog_hash":package.get("catalog_hash",package.get("population_package",{}).get("catalog_hash","")),"policy_hash":package.get("policy_hash",package.get("population_package",{}).get("policy_hash",""))}
static func _bundle(ticket: Dictionary, source: Dictionary, compiled: Dictionary) -> Dictionary:
	var source_hash: String = read(ticket.kind,source).output_hash
	var report := report_for(ticket.kind,compiled)
	var files := [{"path":"source.json","sha256":digest(source),"data":source.duplicate(true)},{"path":"report.json","sha256":digest(report),"data":report}]
	var bundle := {"exchange_version":1,"revision":REVISION,"ticket":ticket.duplicate(true),"ticket_hash":digest(ticket),"source_hash":source_hash,"files":files}
	bundle["bundle_hash"] = digest(bundle)
	return {"ok":true,"code":"","bundle":bundle,"output_hash":compiled.output_hash}
static func validate_bundle(raw: Variant) -> Dictionary:
	if not shape(raw,["exchange_version","revision","ticket","ticket_hash","source_hash","files","bundle_hash"]): return fail("exchange_invalid")
	if raw.exchange_version != 1 or raw.revision != REVISION: return fail("exchange_version")
	if not shape(raw.ticket,["exchange_version","compiler_revision","kind","base_hash","policy","brief","corpus","base"]): return fail("exchange_ticket")
	var ticket: Dictionary = raw.ticket
	if not ticket.kind is String or ticket.kind not in KINDS or ticket.exchange_version != 1 or ticket.compiler_revision != REVISIONS[ticket.kind]: return fail("exchange_version")
	if not valid_policy(ticket.policy) or not ticket.brief is String or ticket.brief.length() > 8192 or not ticket.corpus is Array or ticket.corpus.size() > 32: return fail("exchange_ticket")
	for seed_value: Variant in ticket.corpus:
		if not seed_value is String or seed_value != str(seed_value.to_int()): return fail("exchange_seed")
	if not raw.files is Array or raw.files.size() != 2: return fail("exchange_files")
	var seen := {}; var files := {}
	for file: Variant in raw.files:
		if not shape(file,["path","sha256","data"]) or not file.path is String: return fail("exchange_files")
		# An allowlist, not path normalization. No filesystem access to these names.
		if file.path not in ["source.json","report.json"]: return fail("unsafe_bundle_path")
		if seen.has(file.path): return fail("exchange_duplicate_file")
		seen[file.path] = true; files[file.path] = file.data
		if file.sha256 != digest(file.data): return fail("exchange_file_hash")
	var copy: Dictionary = raw.duplicate(true); copy.erase("bundle_hash")
	if raw.bundle_hash != digest(copy) or raw.ticket_hash != digest(ticket): return fail("exchange_hash")
	var base := read(ticket.kind,ticket.base)
	if not base.ok: return base
	if base.output_hash != ticket.base_hash: return fail("exchange_base_hash")
	var source := read(ticket.kind,files["source.json"])
	if not source.ok: return source
	if source.output_hash != raw.source_hash: return fail("exchange_source_hash")
	if not shape(files["report.json"],["ok","code","compiled_hash","compiler_revision","dependencies","catalog_hash","policy_hash"]) or files["report.json"].ok != true or files["report.json"].compiler_revision != REVISIONS[ticket.kind]: return fail("exchange_report")
	return {"ok":true,"code":"","ticket":ticket.duplicate(true),"source":source.data,"report":files["report.json"]}
static func propose(request: Dictionary, candidate: Dictionary) -> Dictionary:
	var checked := validate_bundle(request)
	if not checked.ok: return checked
	# Only an unchanged exported request can mint a proposal.
	if request.source_hash != checked.ticket.base_hash: return fail("exchange_not_request")
	var source := candidate.duplicate(true)
	if checked.ticket.kind == "piece" and digest(source) != digest(checked.ticket.base): source.revision = int(checked.ticket.base.revision)+1
	var readback := read(checked.ticket.kind,source)
	if not readback.ok: return readback
	var changes := diff(checked.ticket.base,source)
	var permitted := authorize(checked.ticket,source,changes)
	if not permitted.ok: return permitted
	var compiled := build(checked.ticket.kind,source)
	if not compiled.ok: return compiled
	return _bundle(checked.ticket,source,compiled)
static func prepare(request: Dictionary, proposal: Dictionary, current: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	var local := validate_bundle(request)
	if not local.ok: return local
	if request.source_hash != local.ticket.base_hash: return fail("exchange_not_request")
	var incoming := validate_bundle(proposal)
	if not incoming.ok: return incoming
	if digest(local.ticket) != digest(incoming.ticket): return fail("exchange_permission_mismatch")
	var kind: String = local.ticket.kind
	var checked := read(kind,current)
	if not checked.ok: return checked
	var changes := diff(local.ticket.base,incoming.source)
	var permitted := authorize(local.ticket,incoming.source,changes)
	if not permitted.ok: return permitted
	if checked.output_hash != local.ticket.base_hash and checked.output_hash != proposal.source_hash: return fail("base_diverged")
	var compiled := build(kind,incoming.source,cancellation)
	if not compiled.ok: return compiled
	if digest(report_for(kind,compiled)) != digest(incoming.report): return fail("exchange_compiled_hash")
	return {"ok":true,"code":"","kind":kind,"source":incoming.source.duplicate(true),"base_hash":local.ticket.base_hash,"current_hash":checked.output_hash,"source_hash":proposal.source_hash,"output_hash":compiled.output_hash,"package":compiled.package,"diff":changes,"already_applied":checked.output_hash == proposal.source_hash}
static func apply_to(request: Dictionary, proposal: Dictionary, current: Dictionary, apply: Callable) -> Dictionary:
	# Recheck inputs on commit; cached previews are never an authority.
	var prepared := prepare(request,proposal,current)
	if not prepared.ok or prepared.already_applied: return prepared
	var result: Dictionary = apply.call(prepared.source.duplicate(true))
	return prepared if result.ok else result
static func _id(value: Variant) -> String:
	if value is Dictionary:
		if value.has("vertices_xyz") and value.get("surface_id") is String: return value.surface_id
		for key: String in IDS:
			if value.has(key) and value[key] is String: return value[key]
	return ""
static func _keyed(values: Array) -> Dictionary:
	var result := {}
	for value: Variant in values:
		var id := _id(value)
		if id.is_empty() or result.has(id): return {}
		result[id] = value
	return result
static func diff(before: Variant, after: Variant, path: String = "", entity: String = "") -> Array:
	if digest(before) == digest(after): return []
	var result: Array = []
	if before is Dictionary and after is Dictionary:
		var keys: Array = before.keys()
		for key: String in after:
			if key not in keys: keys.append(key)
		keys.sort()
		for key: String in keys:
			var next := path+"/"+key.replace("~","~0").replace("/","~1")
			if not before.has(key) or not after.has(key): result.append({"path":next,"entity_id":entity,"operation":"add" if after.has(key) else "remove","before":before.get(key),"after":after.get(key)})
			else: result.append_array(diff(before[key],after[key],next,entity))
	elif before is Array and after is Array:
		var a := _keyed(before); var b := _keyed(after)
		# Ordered waypoints must keep order; an order change is a section-level diff.
		if (before.is_empty() or a.size() == before.size()) and (after.is_empty() or b.size() == after.size()) and not path.ends_with("/waypoints"):
			var keys: Array = a.keys()
			for key: String in b:
				if key not in keys: keys.append(key)
			keys.sort()
			for key: String in keys:
				var next := path+"/@"+key
				if not a.has(key) or not b.has(key): result.append({"path":next,"entity_id":key,"operation":"add" if b.has(key) else "remove","before":a.get(key),"after":b.get(key)})
				else: result.append_array(diff(a[key],b[key],next,key))
		else: result.append({"path":path,"entity_id":entity,"operation":"replace","before":before,"after":after})
	else: result.append({"path":path,"entity_id":entity,"operation":"replace","before":before,"after":after})
	return result
static func guards(value: Variant, path: String = "") -> Dictionary:
	var result := {}
	if value is Dictionary:
		if value.get("locked",false) == true or value.get("fixed",false) == true or (value.get("protected_regions") is Array and not value.protected_regions.is_empty()): result[path] = digest(value)
		if value.get("layers") is Array and value.get("regions") is Array:
			for layer: Dictionary in value.layers:
				for region: Dictionary in value.regions:
					if region.region_id in layer.protected_regions: result[path+"/regions/@"+region.region_id] = digest(region)
		if value.get("pins") is Array and value.get("map") is Dictionary:
			for instance: Dictionary in value.map.instances:
				if instance.instance_id in value.pins: result[path+"/map/instances/@"+instance.instance_id] = digest(instance)
			result[path+"/pins"] = digest(value.pins)
		for key: String in value: result.merge(guards(value[key],path+"/"+key))
	elif value is Array:
		for i: int in value.size():
			var id := _id(value[i]); result.merge(guards(value[i],path+"/"+("@"+id if not id.is_empty() else str(i))))
	return result
static func at_path(value: Variant, path: String) -> Variant:
	var current: Variant = value
	for segment: String in path.trim_prefix("/").split("/"):
		segment = segment.replace("~1","/").replace("~0","~")
		if current is Dictionary: current = current.get(segment)
		elif current is Array and segment.begins_with("@"):
			var found: Variant = null
			for entry: Variant in current:
				if _id(entry) == segment.substr(1): found = entry
			current = found
		elif current is Array and segment.is_valid_int() and int(segment) >= 0 and int(segment) < current.size(): current = current[int(segment)]
		else: return null
	return current
static func authorize(ticket: Dictionary, source: Dictionary, changes: Array) -> Dictionary:
	if changes.size() > ticket.policy.max_changes: return fail("exchange_budget")
	if source.get("document_id") != ticket.base.get("document_id") or source.get("schema_version") != ticket.base.get("schema_version"): return fail("exchange_identity")
	for change: Dictionary in changes:
		var section: String = change.path.get_slice("/",1)
		if section == "revision" and ticket.kind == "piece": continue
		if section not in ticket.policy.sections: return fail("exchange_section_denied")
		if not ticket.policy.ids.is_empty() and (change.entity_id.is_empty() or change.entity_id not in ticket.policy.ids): return fail("exchange_id_denied")
	var protected_values := guards(ticket.base)
	for path: String in ticket.policy.protected_paths: protected_values[path] = digest(at_path(ticket.base,path))
	for path: String in protected_values:
		if digest(at_path(source,path)) != protected_values[path]: return fail("exchange_protected")
	return {"ok":true,"code":""}
