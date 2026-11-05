@tool
extends RefCounted
## Passive immutable handoff. Runtime uses the existing campaign authorities.
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Patrols = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Phase = preload("res://data/expedition/phases/ruined_crossing.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const MAX_BYTES := 5*1024*1024
const VERSION := 1

static func fail(code: String, entity: String = "", detail: Dictionary = {}) -> Dictionary:
	var messages := {"candidate_invalid":"O candidato de teste está inválido ou foi alterado.","candidate_stale":"A fonte mudou; compile novamente antes de testar.","candidate_io":"Não foi possível preservar o candidato de teste.","entrance_unsafe":"A entrada não tem espaço para o personagem real.","body_unreachable":"O personagem real não consegue percorrer este trecho.","interaction_unreachable":"A interação não tem acesso de ida e volta para o personagem real.","runtime_required":"A preparação de gameplay exige o processo de jogo.","candidate_kind":"Este tipo de pacote ainda não tem consumidor de gameplay."}
	return {"ok":false,"code":code,"message":messages.get(code,"O teste não pôde ser preparado."),"entity":entity,"detail":detail}

static func package_valid(kind: String, value: Dictionary) -> bool:
	match kind:
		"map": return Maps.validate_package(value)
		"population": return Population.validate_package(value)
		"patrol": return Patrols.validate_package(value)
	return false

static func create(kind: String, value: Dictionary, current_source_hash: String) -> Dictionary:
	if kind not in ["map","population","patrol"]: return fail("candidate_kind")
	if not ExpeditionCanonical.valid(value) or var_to_bytes(value).size() > MAX_BYTES or not package_valid(kind,value): return fail("candidate_invalid")
	if value.source_hash != current_source_hash: return fail("candidate_stale")
	return _create_approved(kind,value,current_source_hash)

## Private immediate handoff, only after create() or the pinned release loader
## has validated these exact bytes. No caller-supplied trust flag or cache.
static func _create_approved(kind: String, value: Dictionary, current_source_hash: String) -> Dictionary:
	# The loader has its own larger transport limit. Preserve the candidate's
	# existing 5 MiB admission boundary even on this closed handoff.
	if var_to_bytes(value).size() > MAX_BYTES: return fail("candidate_invalid")
	var candidate := {"format_version":VERSION,"kind":kind,"source_hash":current_source_hash,"package":value.duplicate(true)}
	candidate["candidate_hash"] = ExpeditionCanonical.digest(candidate)
	return {"ok":true,"candidate":candidate}

static func valid(value: Dictionary) -> bool:
	if not ExpeditionCanonical.valid(value) or value.size() != 5 or not value.has_all(["format_version","kind","source_hash","package","candidate_hash"]): return false
	if var_to_bytes(value).size() > MAX_BYTES or value.format_version != VERSION or not value.kind is String or not value.package is Dictionary: return false
	if not value.source_hash is String or not value.candidate_hash is String: return false
	var content := value.duplicate(true); content.erase("candidate_hash")
	return ExpeditionCanonical.digest(content) == value.candidate_hash and value.package.get("source_hash") == value.source_hash and package_valid(value.kind,value.package)

static func map_package(candidate: Dictionary) -> Dictionary:
	match candidate.kind:
		"map": return candidate.package
		"population": return candidate.package.map_package
		"patrol": return candidate.package.population_package.map_package
	return {}

static func prepare(candidate: Dictionary) -> Dictionary:
	if Engine.is_editor_hint(): return fail("runtime_required")
	var started := Time.get_ticks_usec()
	if not valid(candidate): return fail("candidate_invalid")
	var validation_ms := (Time.get_ticks_usec()-started)/1000.0
	var result := _prepare_approved(candidate)
	if result.ok: result.prepare_timings["validate_ms"] = validation_ms
	return result

## All geometry/admission checks below still run; only repeated validation of
## the exact package just returned by the loader is avoided.
static func _prepare_approved(candidate: Dictionary) -> Dictionary:
	var timings: Dictionary = {}
	var stamp := Time.get_ticks_usec()
	if Engine.is_editor_hint(): return fail("runtime_required")
	if var_to_bytes(candidate).size() > MAX_BYTES: return fail("candidate_invalid")
	stamp = _prepare_stamp(timings,"validate_ms",stamp)
	var value: Dictionary = candidate.package
	var raw: Dictionary = value.manifest.duplicate(true)
	var rules: Dictionary = {}
	if candidate.kind == "population": rules = value.rules.duplicate(true)
	elif candidate.kind == "patrol": rules = value.population_package.rules.duplicate(true)
	var profile := Phase.input("map_authoring_preview").traversal.to_data()
	raw.input["traversal"] = profile.duplicate(true); raw["traversal"] = profile.duplicate(true)
	raw.input["preview_candidate_hash"] = candidate.candidate_hash
	raw.input["entry_stage_id"] = "map_preview"; raw.input["phase_id"] = "editor_gameplay_preview"
	var manifest := ExpeditionManifest.new(); manifest._data = raw
	var world := WorldGeometry.new(); var configured := world.configure(manifest,"map_preview")
	if not configured.ok: return configured
	var stage: Dictionary = raw.stages[0]; var entry: ExpeditionWorldPoint
	var ephemeral: bool = stage.entrance.is_empty()
	if ephemeral:
		for cell: Dictionary in stage.surfaces:
			entry = Maps._walkable_point(world,cell,profile)
			if entry != null: break
		if entry == null: return fail("entrance_unsafe")
		stage.entrance = "preview_entry"
		stage.sockets.append({"socket_id":"preview_entry","kind":"entrance","tags":[],"surface_id":entry.surface_id,"position":entry.position})
		configured = world.configure(manifest,"map_preview")
		if not configured.ok: return configured
	else:
		for socket: Dictionary in stage.sockets:
			if socket.socket_id == stage.entrance: entry = ExpeditionWorldPoint.create("map_preview",socket.surface_id,socket.position)
	if entry == null or not world.position_query(entry,profile,world.geometry_revision).ok: return fail("entrance_unsafe",stage.entrance)
	stamp = _prepare_stamp(timings,"world_and_entry_ms",stamp)
	var destinations: Array[ExpeditionWorldPoint] = []
	for cell: Dictionary in stage.surfaces:
		var point := Maps._walkable_point(world,cell,profile)
		if point == null: return fail("body_unreachable",cell.surface_id)
		destinations.append(point)
	stamp = _prepare_stamp(timings,"surface_probes_ms",stamp)
	var access := world.connectivity_batch(entry,destinations,profile,world.geometry_revision)
	if not access.ok: return access
	if not access.data.complete or not access.data.all_reachable: return fail("body_unreachable","",access.data)
	stamp = _prepare_stamp(timings,"surface_connectivity_ms",stamp)
	# Preparation needs round-trip existence, never a shortest movement cost.
	var interactions: Array[ExpeditionWorldPoint] = []; var interaction_ids: Array[String] = []
	for objective: Dictionary in raw.objectives:
		interactions.append(ExpeditionPopulationPlanner.point(objective.point)); interaction_ids.append(String(objective.objective_id))
	for portal: Dictionary in raw.portals:
		for anchor: String in ["from_anchor","to_anchor"]:
			interactions.append(ExpeditionPopulationPlanner.point(portal[anchor])); interaction_ids.append(String(portal.portal_id))
	var reached := _round_trips(world,entry,interactions,profile,interaction_ids,"interaction_unreachable")
	if not reached.ok: return reached
	stamp = _prepare_stamp(timings,"interaction_proofs_ms",stamp)
	var loaded := Catalog.load_current()
	if not loaded.ok: return loaded
	stamp = _prepare_stamp(timings,"catalog_ms",stamp)
	var planned := ExpeditionPopulationPlanner.build(manifest,loaded.catalog,rules)
	if not planned.ok: return planned
	stamp = _prepare_stamp(timings,"population_build_ms",stamp)
	# Group slot homes by stage authority and entire traversal profile, keeping slot order.
	var groups: Dictionary = {}; var group_order: Array[String] = []
	for slot: Dictionary in planned.slots.values():
		var key: String = String(slot.stage_id)+"/"+ExpeditionCanonical.digest(slot.traversal)
		if not groups.has(key):
			var homes: Array[ExpeditionWorldPoint] = []; var ids: Array[String] = []
			groups[key] = {"stage_id":slot.stage_id,"profile":slot.traversal,"homes":homes,"ids":ids}; group_order.append(key)
		groups[key].homes.append(ExpeditionPopulationPlanner.point(slot.home)); groups[key].ids.append(String(slot.slot_id))
	var failures: Dictionary = {}
	for key: String in group_order:
		var group: Dictionary = groups[key]
		var checked := _round_trips(planned.worlds[group.stage_id],entry,group.homes,group.profile,group.ids,"body_unreachable")
		if not checked.ok:
			if checked.code != "body_unreachable": return checked
			failures[checked.entity] = checked
	stamp = _prepare_stamp(timings,"home_round_trips_ms",stamp)
	for slot: Dictionary in planned.slots.values():
		var authority: WorldGeometry = planned.worlds[slot.stage_id]
		if failures.has(String(slot.slot_id)): return failures[String(slot.slot_id)]
		if slot.has("patrol"):
			var mob: MobDefinition = loaded.catalog.get_definition(StringName(slot.species_id))
			var route := Patrols.Patrol.validate_route(slot.patrol,authority,ExpeditionPopulationPlanner.point(slot.home),slot.traversal,mob.leash_radius)
			if not route.ok: return route
	_prepare_stamp(timings,"patrol_proofs_ms",stamp)
	return {"ok":true,"prepare_timings":timings,"manifest":manifest,"rules":rules,"map_package":map_package(candidate),"entry":entry.to_data(),"ephemeral_entry":ephemeral,"candidate_hash":candidate.candidate_hash,"metrics":access.data.metrics}

## Diagnostics stay local to preparation, outside the candidate and manifest.
static func _prepare_stamp(timings: Dictionary, label: String, previous: int) -> int:
	var now := Time.get_ticks_usec()
	timings[label] = (now-previous)/1000.0
	return now

static func _both(world: WorldGeometry, a: ExpeditionWorldPoint, b: ExpeditionWorldPoint, profile: Dictionary) -> bool:
	# Individual reference kept for differential tests; preparation uses _round_trips.
	return world.position_query(b,profile,world.geometry_revision).ok and world.path(a,b,profile,world.geometry_revision).ok and world.path(b,a,profile,world.geometry_revision).ok

static func _round_trips(world: WorldGeometry, entry: ExpeditionWorldPoint, points: Array[ExpeditionWorldPoint], profile: Dictionary, ids: Array[String], negative: String) -> Dictionary:
	# First failing item in original order is reported, as with the individual checks.
	var legal: Array[bool] = []; var targets: Array[ExpeditionWorldPoint] = []; var indexes: Array[int] = []
	for index: int in points.size():
		var valid_point: bool = world.position_query(points[index],profile,world.geometry_revision).ok
		legal.append(valid_point)
		if valid_point: indexes.append(index); targets.append(points[index])
	var reachable: Dictionary = {}
	if not targets.is_empty():
		var certified := world.connectivity_batch(entry,targets,profile,world.geometry_revision)
		if not certified.ok:
			if certified.error_code == &"invalid_support": return fail(negative,"",{"geometry_diagnostic":certified.get("data",{}).duplicate(true) if certified.get("data") is Dictionary else {}})
			return fail(String(certified.error_code),"",{"geometry_diagnostic":certified.get("data",{}).duplicate(true) if certified.get("data") is Dictionary else {}})
		if not certified.data.complete: return fail("navigation_budget_exceeded")
		for target: Dictionary in certified.data.targets:
			if target.outward_reachable and target.inward_reachable: reachable[indexes[int(target.input_index)]] = true
	for index: int in points.size():
		if not legal[index] or not reachable.has(index): return fail(negative,ids[index])
	return {"ok":true}

static func publish(candidate: Dictionary, directory: String) -> Dictionary:
	if not valid(candidate): return fail("candidate_invalid")
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return fail("candidate_io")
	var target := directory.path_join(candidate.candidate_hash+".bin")
	var bytes := var_to_bytes(candidate)
	if FileAccess.file_exists(target):
		return {"ok":true,"path":target} if FileAccess.get_file_as_bytes(target) == bytes else fail("candidate_io")
	var temporary := target+"."+Crypto.new().generate_random_bytes(12).hex_encode()+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return fail("candidate_io")
	file.store_buffer(bytes); file.flush(); var error := file.get_error(); file.close()
	if error != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
		DirAccess.remove_absolute(temporary); return fail("candidate_io")
	# Another writer may have published the same immutable value in the meantime.
	if FileAccess.file_exists(target):
		DirAccess.remove_absolute(temporary)
		return {"ok":true,"path":target} if FileAccess.get_file_as_bytes(target) == bytes else fail("candidate_io")
	if DirAccess.rename_absolute(temporary,target) != OK:
		DirAccess.remove_absolute(temporary); return fail("candidate_io")
	return {"ok":true,"path":target}

static func read(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES: return fail("candidate_invalid")
	var bytes := file.get_buffer(file.get_length()); file.close()
	var decoded: Variant = bytes_to_var(bytes)
	if not decoded is Dictionary or not valid(decoded): return fail("candidate_invalid")
	return {"ok":true,"candidate":decoded}
