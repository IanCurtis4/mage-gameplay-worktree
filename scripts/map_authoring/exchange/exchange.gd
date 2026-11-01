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
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Props = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
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
## Checkpoint45 (F9-08/09, P3c): when the open source moved since the request was
## exported, the proposal is merged three ways (base, current, proposal) instead
## of refused: see merge(). resolutions: {change path: "current" | "proposal"}
## for the conflicts a previous review reported.
static func prepare(request: Dictionary, proposal: Dictionary, current: Dictionary, cancellation: Callable = Callable(), resolutions: Dictionary = {}) -> Dictionary:
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
	var diverged: bool = checked.output_hash != local.ticket.base_hash and checked.output_hash != proposal.source_hash
	var merged: Dictionary = {}
	if diverged:
		merged = merge(kind,local.ticket.base,current,incoming.source,resolutions)
		if not merged.ok: return merged
		if merged.output_hash == checked.output_hash:
			return {"ok":true,"code":"","kind":kind,"source":current.duplicate(true),"base_hash":local.ticket.base_hash,"current_hash":checked.output_hash,"source_hash":checked.output_hash,"output_hash":"","package":{},"diff":changes,"merge":merged.report,"already_applied":true}
	# The proposal's own report must still match a local compilation of it.
	var compiled := build(kind,incoming.source,cancellation)
	if not compiled.ok: return compiled
	if digest(report_for(kind,compiled)) != digest(incoming.report): return fail("exchange_compiled_hash")
	if not diverged:
		return {"ok":true,"code":"","kind":kind,"source":incoming.source.duplicate(true),"base_hash":local.ticket.base_hash,"current_hash":checked.output_hash,"source_hash":proposal.source_hash,"output_hash":compiled.output_hash,"package":compiled.package,"diff":changes,"already_applied":checked.output_hash == proposal.source_hash}
	var certified := _recertify(kind,merged.source,cancellation)
	if not certified.ok: return certified
	var readback := read(kind,certified.source)
	if not readback.ok: return merge_failure(readback)
	var combined := build(kind,certified.source,cancellation)
	if not combined.ok: return combined
	return {"ok":true,"code":"","kind":kind,"source":certified.source,"base_hash":local.ticket.base_hash,"current_hash":checked.output_hash,"source_hash":readback.output_hash,"output_hash":combined.output_hash,"package":combined.package,"diff":changes,"merge":merged.report,"already_applied":false}
static func apply_to(request: Dictionary, proposal: Dictionary, current: Dictionary, apply: Callable, resolutions: Dictionary = {}) -> Dictionary:
	# Recheck inputs on commit; cached previews are never an authority.
	var prepared := prepare(request,proposal,current,Callable(),resolutions)
	if not prepared.ok or prepared.already_applied: return prepared
	var result: Dictionary = apply.call(prepared.source.duplicate(true))
	return prepared if result.ok else result

## Three-way merge on identities, fields and samples (fine diff). A proposal
## change applies on top of the current source unless a local change touches the
## same path, a parent or a child of it (or the same sample's material blend):
## the same result on both sides is agreed; anything else is a conflict that
## needs an explicit choice. A protection the current source added or changed
## prevails ("current" is the only choice). Nothing is written here.
static func merge(kind: String, base: Dictionary, current: Dictionary, incoming: Dictionary, resolutions: Dictionary = {}) -> Dictionary:
	if not resolutions is Dictionary or resolutions.size() > 2048: return fail("exchange_resolution_invalid")
	for key: Variant in resolutions:
		if not key is String or resolutions[key] not in ["current","proposal"]: return fail("exchange_resolution_invalid")
	var skipped := ["/plan_hash"]
	if kind == "piece": skipped.append("/revision")
	var local := diff(base,current,"","",true).filter(func(change: Dictionary) -> bool: return change.path not in skipped)
	var theirs := diff(base,incoming,"","",true).filter(func(change: Dictionary) -> bool: return change.path not in skipped)
	var base_guards := guards(base); var current_guards := guards(current)
	var renewed: Array = []
	for path: String in current_guards:
		if base_guards.get(path,"") != current_guards[path]: renewed.append(path)
	var merged := current.duplicate(true)
	var conflicts: Array = []; var applied: Array = []; var agreed: Array = []; var kept: Array = []; var used: Dictionary = {}
	for change: Dictionary in theirs:
		var id: String = change.path
		var clashes: Array = local.filter(func(other: Dictionary) -> bool: return overlaps(other.path,id))
		if clashes.size() == 1 and clashes[0].path == id and clashes[0].operation == change.operation and digest(clashes[0].after) == digest(change.after):
			agreed.append(id); continue
		var guarded: bool = renewed.any(func(path: String) -> bool: return overlaps(path,id))
		if guarded or not clashes.is_empty():
			var choice: String = resolutions.get(id,"")
			if choice != "": used[id] = true
			if choice == "":
				var local_paths: Array = []
				for other: Dictionary in clashes: local_paths.append(other.path)
				conflicts.append({"path":id,"entity_id":change.entity_id,"kind":"protection" if guarded else "value","local_paths":local_paths,"base":change.before,"current":at_path(current,id),"proposal":change.after})
				continue
			if choice == "current": kept.append(id); continue
			if guarded: return fail("exchange_protected")
		if not put(merged,change):
			if resolutions.get(id,"") == "proposal": return merge_failure(fail("exchange_merge_invalid"),id)
			conflicts.append({"path":id,"entity_id":change.entity_id,"kind":"structure","local_paths":[],"base":change.before,"current":at_path(current,id),"proposal":change.after})
			continue
		applied.append(id)
	for key: String in resolutions:
		if not used.has(key) and key not in kept: return fail("exchange_resolution_invalid")
	if not conflicts.is_empty():
		var failure := fail("exchange_conflict")
		failure["conflicts"] = conflicts
		failure.diagnostics[0].message = "%d conflito(s) entre a proposta e a versão atual; escolha \"manter a atual\" ou \"usar a proposta\" para cada um e revalide." % conflicts.size()
		return failure
	var readback := read(kind,merged)
	if not readback.ok: return merge_failure(readback)
	return {"ok":true,"code":"","source":merged,"output_hash":readback.output_hash,"report":{"applied":applied,"agreed":agreed,"kept_current":kept,"local_changes":local.size()}}

static func merge_failure(cause: Dictionary, path: String = "") -> Dictionary:
	var failure := fail("exchange_merge_invalid")
	failure["cause"] = cause.get("code","")
	failure.diagnostics[0].message = "A combinação da proposta com a versão atual não é uma fonte válida (%s)%s; nada foi aplicado." % [cause.get("code",""),(" em "+path) if not path.is_empty() else ""]
	failure.diagnostics[0]["entity_id"] = path
	return failure

## Paths touch when equal or one contains the other; every material mask of a
## sample counts as that sample's blend.
static func overlaps(a: String, b: String) -> bool:
	var x := _blend(a); var y := _blend(b)
	return x == y or x.begins_with(y+"/") or y.begins_with(x+"/")
static func _blend(path: String) -> String:
	var regex := RegEx.create_from_string("/material_masks(/[^/]+)?(/(\\d+))?$")
	var found := regex.search(path)
	if found == null: return path
	var head := path.substr(0,found.get_start())
	return head+"/#weights"+("/"+found.get_string(3) if found.get_string(3) != "" else "")

## Writes one diff change into a document copy; false when its place is gone.
static func put(document: Variant, change: Dictionary) -> bool:
	var path: String = change.path
	if path.is_empty() or not path.begins_with("/"): return false
	var segments := path.trim_prefix("/").split("/")
	var parent: Variant = document
	for i: int in segments.size()-1:
		parent = _step(parent,segments[i].replace("~1","/").replace("~0","~"))
		if not (parent is Dictionary or parent is Array): return false
	var last := segments[segments.size()-1].replace("~1","/").replace("~0","~")
	var value: Variant = change.after.duplicate(true) if change.after is Dictionary or change.after is Array else change.after
	if parent is Dictionary:
		match change.operation:
			"remove":
				if not parent.has(last): return false
				parent.erase(last)
			"add":
				if parent.has(last): return false
				parent[last] = value
			_:
				if not parent.has(last): return false
				parent[last] = value
		return true
	if last.begins_with("@"):
		var index := -1
		for j: int in parent.size():
			if _id(parent[j]) == last.substr(1): index = j
		match change.operation:
			"remove":
				if index < 0: return false
				parent.remove_at(index)
			"add":
				if index >= 0: return false
				parent.append(value)
			_:
				if index < 0: return false
				parent[index] = value
		return true
	if last.is_valid_int() and change.operation == "replace" and int(last) >= 0 and int(last) < parent.size():
		parent[int(last)] = value; return true
	return false
static func _step(container: Variant, segment: String) -> Variant:
	if container is Dictionary: return container.get(segment)
	if container is Array and segment.begins_with("@"):
		for entry: Variant in container:
			if _id(entry) == segment.substr(1): return entry
		return null
	if container is Array and segment.is_valid_int() and int(segment) >= 0 and int(segment) < container.size(): return container[int(segment)]
	return null
static func _numeric(values: Array) -> bool:
	for value: Variant in values:
		if not (value is int or value is float): return false
	return true

## A realized plan covers the whole recipe (map included). After a merge that
## changed the recipe, every slot is reserved and re-validated on the merged
## source and nothing is drawn (PopulationCompiler scope redraw=false); a slot
## or quota the merge broke fails here instead of being redrawn in silence.
static func _recertify(kind: String, source: Dictionary, cancellation: Callable) -> Dictionary:
	var population: Dictionary = {}
	if kind == "population": population = source
	elif kind == "patrol" and not source.population.is_empty(): population = source.population[0]
	if population.is_empty() or population.plan_hash == Population.recipe_hash(population): return {"ok":true,"source":source}
	var keep: Array = []
	for slot: Dictionary in population.slots:
		if not slot.fixed: keep.append(slot.slot_id)
	var checked := PopulationCompiler.regenerate(population,func() -> bool: return cancellation.is_valid() and cancellation.call(0.0),{"keep":keep,"redraw":false})
	if not checked.ok: return checked
	population.slots = checked.data.slots; population.plan_hash = checked.data.plan_hash
	return {"ok":true,"source":source}
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
## fine=true (checkpoint45, three-way merge): numeric arrays of the same size are
## compared per index (one change per terrain or material sample). Authorization
## and the change budget keep using the coarse diff.
static func diff(before: Variant, after: Variant, path: String = "", entity: String = "", fine: bool = false) -> Array:
	if digest(before) == digest(after): return []
	var result: Array = []
	if fine and before is Array and after is Array and not before.is_empty() and before.size() == after.size() and _numeric(before) and _numeric(after):
		for i: int in before.size():
			if digest(before[i]) != digest(after[i]): result.append({"path":path+"/"+str(i),"entity_id":entity,"operation":"replace","before":before[i],"after":after[i]})
		return result
	if before is Dictionary and after is Dictionary:
		var keys: Array = before.keys()
		for key: String in after:
			if key not in keys: keys.append(key)
		keys.sort()
		for key: String in keys:
			var next := path+"/"+key.replace("~","~0").replace("/","~1")
			if not before.has(key) or not after.has(key): result.append({"path":next,"entity_id":entity,"operation":"add" if after.has(key) else "remove","before":before.get(key),"after":after.get(key)})
			else: result.append_array(diff(before[key],after[key],next,entity,fine))
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
				else: result.append_array(diff(a[key],b[key],next,key,fine))
		else: result.append({"path":path,"entity_id":entity,"operation":"replace","before":before,"after":after})
	else: result.append({"path":path,"entity_id":entity,"operation":"replace","before":before,"after":after})
	return result
static func guards(value: Variant, path: String = "") -> Dictionary:
	var result := {}
	if value is Dictionary:
		if value.get("locked",false) == true or value.get("fixed",false) == true: result[path] = digest(value)
		if value.get("layers") is Array and value.get("regions") is Array:
			# Checkpoint45 (P3c): the shared mask, not the whole layer. A layer with
			# protected regions keeps its grid, its list of protections, every
			# sample whose influence touches a protected region (height and
			# material weights) and every object whose footprint touches one.
			var catalog: Dictionary = {}
			for layer: Dictionary in value.layers:
				for region: Dictionary in value.regions:
					if region.region_id in layer.protected_regions: result[path+"/regions/@"+region.region_id] = digest(region)
				if layer.get("locked",false) == true or layer.protected_regions.is_empty(): continue
				var at: String = path+"/layers/@"+layer.layer_id
				for key: String in ["protected_regions","origin_xz","sample_spacing","columns","rows"]: result[at+"/"+key] = digest(layer[key])
				for index: int in Synthesis.protected_samples(value,layer):
					result[at+"/heights/"+str(index)] = digest(layer.heights[index])
					result[at+"/#weights/"+str(index)] = digest(Materials.weights(layer,index))
				if catalog.is_empty(): catalog = Props.load_catalog()
				for placement: Dictionary in value.get("placements",[]):
					if Synthesis._layer_of(value,placement.surface_id) != layer.layer_id: continue
					var radius := float(catalog.get("definitions",{}).get(placement.definition_id,{}).get("footprint_radius",0.0))
					var center := Vector2(placement.position_xyz[0],placement.position_xyz[2])
					for region: Dictionary in value.regions:
						if region.region_id in layer.protected_regions and Synthesis._disk_touches(center,radius,Synthesis._polygon(region.polygon_xz)): result[path+"/placements/@"+placement.placement_id] = digest(placement); break
		if value.get("pins") is Array and value.get("map") is Dictionary:
			for instance: Dictionary in value.map.instances:
				if instance.instance_id in value.pins: result[path+"/map/instances/@"+instance.instance_id] = digest(instance)
			result[path+"/pins"] = digest(value.pins)
		for key: String in value: result.merge(guards(value[key],path+"/"+key))
	elif value is Array:
		for i: int in value.size():
			var id := _id(value[i]); result.merge(guards(value[i],path+"/"+("@"+id if not id.is_empty() else str(i))))
	return result
## Value behind a guard path; "#weights/<i>" is the effective material blend of
## sample i of the layer above it.
static func guard_value(value: Variant, path: String) -> Variant:
	var marker := path.find("/#weights/")
	if marker < 0: return at_path(value,path)
	var layer: Variant = at_path(value,path.substr(0,marker))
	var index := path.substr(marker+10)
	if not layer is Dictionary or not index.is_valid_int() or not layer.get("heights") is Array or int(index) < 0 or int(index) >= layer.heights.size() or not layer.get("material_masks") is Dictionary: return null
	return Materials.weights(layer,int(index))
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
		if digest(guard_value(source,path)) != protected_values[path]: return fail("exchange_protected")
	return {"ok":true,"code":""}
