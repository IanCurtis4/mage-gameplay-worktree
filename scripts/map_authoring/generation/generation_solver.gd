@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
var request: Dictionary
var operations := 0
var backtracks := 0
var validations := 0
var last_entity := ""
var last_rule := "domain"
var stopped := ""
var cancellation: Callable
var _thread: Thread
var _mutex := Mutex.new()
var _cancelled := false

func start(source: Dictionary, enabled: bool) -> void:
	var copy := source.duplicate(true)
	_thread = Thread.new()
	_thread.start(func() -> Dictionary: return solve(copy,enabled,_poll))
func _poll(_progress: float = 0.0) -> bool:
	_mutex.lock(); var cancelled := _cancelled; _mutex.unlock(); return cancelled
func cancel() -> void:
	_mutex.lock(); _cancelled = true; _mutex.unlock()
func ready() -> bool: return _thread != null and not _thread.is_alive()
func take(current_hash: String) -> Dictionary:
	var result: Dictionary = _thread.wait_to_finish(); _thread = null
	if _poll():
		var cancelled := Document.fail("cancelled")
		for key: String in ["input_hash","diagnostic"]:
			if result.has(key): cancelled[key] = result[key]
		return cancelled
	if result.has("input_hash") and result.input_hash != current_hash: return Document.fail("stale_source")
	return result
func close() -> void:
	if _thread != null: cancel(); _thread.wait_to_finish(); _thread = null

func _spend(entity: String = "", rule: String = "domain") -> bool:
	last_entity = entity; last_rule = rule
	if cancellation.is_valid() and cancellation.call(0.0): stopped = "cancelled"; return false
	if operations >= request.budget.operations: stopped = "budget_exhausted"; return false
	operations += 1
	return true

func solve(source: Dictionary, enabled: bool = false, cancel_callback: Callable = Callable()) -> Dictionary:
	if not enabled: return Document.fail("experimental_disabled")
	var checked := Document.validate(source)
	if not checked.ok: return checked
	request = checked.data; cancellation = cancel_callback
	operations = 0; backtracks = 0; validations = 0; stopped = ""; last_entity = ""; last_rule = "domain"
	var result := _search(Document.domains(request))
	if not result.ok:
		result = Document.fail(stopped if not stopped.is_empty() else "contradiction",last_entity,last_rule)
	else:
		var before := Compiler.compile(request.map,cancellation)
		if before.get("code","") == "cancelled" or (cancellation.is_valid() and cancellation.call(1.0)):
			result = Document.fail("cancelled")
		elif before.ok: result["before_package"] = before.package
	result.input_hash = checked.output_hash
	result.diagnostic = {"seed_text":request.seed_text,"algorithm_revision":Document.REVISION,"operations":operations,"backtracks":backtracks,"validations":validations,"region":last_entity,"rule":last_rule,"budget":request.budget.duplicate(true)}
	return result

func _search(domains: Dictionary) -> Dictionary:
	if not _propagate(domains): return {"ok":false}
	var selected := ""; var entropy := INF
	for id: String in domains:
		if domains[id].size() <= 1: continue
		var total := 0.0; var weighted_log := 0.0
		for option: Dictionary in domains[id]: total += option.weight; weighted_log += option.weight*log(float(option.weight))
		var candidate_entropy := log(total)-weighted_log/total
		if candidate_entropy < entropy-0.0000001: entropy = candidate_entropy; selected = id
	if selected.is_empty(): return _complete(domains)
	var ordered: Array = domains[selected].duplicate(true)
	# Exponential race implements weighted ordering without shared mutable RNG state.
	ordered.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var sa := rank(selected,a); var sb := rank(selected,b)
		return sa < sb if sa != sb else Document.option_key(a) < Document.option_key(b))
	for option: Dictionary in ordered:
		if not _spend(selected,"decision"): return {"ok":false}
		var branch := domains.duplicate(true); branch[selected] = [option]
		var result := _search(branch)
		if result.ok: return result
		if not stopped.is_empty(): return result
		if backtracks >= request.budget.backtracks: stopped = "budget_exhausted"; return {"ok":false}
		backtracks += 1
	return {"ok":false}

func rank(id: String, option: Dictionary) -> float:
	var digest: String = ("layout/"+Document.REVISION+"/"+request.seed_text+"/"+id+"/"+Document.option_key(option)).sha256_text()
	var unit := (float(digest.substr(0,12).hex_to_int())+1.0)/281474976710657.0
	return -log(unit)/float(option.weight)

func _propagate(domains: Dictionary) -> bool:
	var changed := true
	var links: Array = request.map.links.duplicate(true)
	links.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.link_id < b.link_id)
	while changed:
		changed = false
		for id: String in domains:
			if not _spend(id,"domain"): return false
			if domains[id].is_empty(): return false
		for link: Dictionary in links:
			for forward: bool in [true,false]:
				var a: String = link.a_instance if forward else link.b_instance
				var b: String = link.b_instance if forward else link.a_instance
				var retained: Array = []
				for option: Dictionary in domains[a]:
					var supported := false
					for other: Dictionary in domains[b]:
						if not _spend(a,link.link_id): return false
						if compatible(a,option,link.a_connector if forward else link.b_connector,b,other,link.b_connector if forward else link.a_connector): supported = true; break
					if supported: retained.append(option)
				if retained.is_empty(): last_entity = a; last_rule = link.link_id; return false
				if retained.size() != domains[a].size(): domains[a] = retained; changed = true
		if not constraints_possible(request,domains): last_rule = "quota_or_diversity"; last_entity = ""; return false
	return true

func compatible(a: String, option: Dictionary, a_port: String, b: String, other: Dictionary, b_port: String) -> bool:
	var pa := port(request,a,option,a_port); var pb := port(request,b,other,b_port)
	if pa.is_empty() or pb.is_empty(): return false
	if pa.position.distance_to(pb.position) > Compiler.EPS or pa.normal.dot(pb.normal) > -1.0+Compiler.EPS: return false
	if absf(pa.width-pb.width) > Compiler.EPS or absf(pa.headroom-pb.headroom) > Compiler.EPS or pa.kind != pb.kind: return false
	var shared := false
	for tag: String in pa.tags:
		if tag in pb.tags: shared = true
	return shared and ((pa.direction in ["both","out"] and pb.direction in ["both","in"]) or (pb.direction in ["both","out"] and pa.direction in ["both","in"]))

static func port(source: Dictionary, id: String, option: Dictionary, port_id: String) -> Dictionary:
	var instance := Compiler._find(source.map.instances,"instance_id",id)
	var piece := Compiler._find(source.map.pieces,"piece_hash",option.piece_hash)
	var connector := Compiler._find(piece.source.connectors,"connector_id",port_id)
	if connector.is_empty(): return {}
	return {"position":Kernel.rotate(Compiler._vector(connector.position_xyz),int(option.rotation_quarters))+Compiler._vector(instance.position_xyz),"normal":Kernel.rotate(Compiler._vector(connector.normal_xyz),int(option.rotation_quarters)),"width":connector.width,"headroom":connector.headroom,"kind":connector.kind,"tags":connector.tags,"direction":connector.direction}

static func constraints_possible(source: Dictionary, domains: Dictionary) -> bool:
	var all := {}
	for id: String in domains:
		if domains[id].is_empty(): return false
		for option: Dictionary in domains[id]: all[option.piece_hash] = true
	if all.size() < source.min_diversity: return false
	for quota: Dictionary in source.quotas:
		var forced := 0; var possible := 0
		for id: String in domains:
			var matches := 0
			for option: Dictionary in domains[id]:
				if option.piece_hash == quota.piece_hash: matches += 1
			if matches > 0: possible += 1
			if matches == domains[id].size(): forced += 1
		if forced > quota.max or possible < quota.min: return false
	return true

func _complete(domains: Dictionary) -> Dictionary:
	if not _spend("","global_validation"): return {"ok":false}
	if validations >= request.budget.validations: stopped = "budget_exhausted"; return {"ok":false}
	validations += 1
	var proposed: Dictionary = request.map.duplicate(true)
	for instance: Dictionary in proposed.instances:
		var option: Dictionary = domains[instance.instance_id][0]
		instance.piece_hash = option.piece_hash; instance.rotation_quarters = int(option.rotation_quarters)
	var compiled := Compiler.compile(proposed,cancellation)
	if not compiled.ok:
		last_rule = compiled.code
		if not compiled.get("diagnostics",[]).is_empty(): last_entity = str(compiled.diagnostics[0].entity_id)
		if compiled.code == "cancelled": stopped = "cancelled"
		return {"ok":false}
	if cancellation.is_valid() and cancellation.call(1.0): stopped = "cancelled"; return {"ok":false}
	return {"ok":true,"code":"","proposal":proposed,"package":compiled.package,"output_hash":compiled.output_hash,"base_hash":Map.hash_source(request.map),"diff":diff(request.map,proposed)}

static func diff(before: Dictionary, after: Dictionary) -> Array:
	var changes: Array = []
	var sorted: Array = after.instances.duplicate(true); sorted.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.instance_id < b.instance_id)
	for instance: Dictionary in sorted:
		var prior := Compiler._find(before.instances,"instance_id",instance.instance_id)
		if Schema.semantic_hash(prior) != Schema.semantic_hash(instance): changes.append({"instance_id":instance.instance_id,"before":prior.duplicate(true),"after":instance.duplicate(true)})
	return changes

static func apply_proposal(result: Dictionary, session: RefCounted) -> Dictionary:
	if not result.get("ok",false) or not result.has_all(["base_hash","proposal","package","output_hash"]): return Document.fail("generation_invalid")
	if Map.hash_source(session.data) != result.base_hash: return Document.fail("stale_source")
	if not Compiler.validate_package(result.package) or result.package.source_hash != Map.hash_source(result.proposal) or result.package.package_hash != result.output_hash: return Document.fail("generation_invalid")
	return session.apply(result.proposal)
