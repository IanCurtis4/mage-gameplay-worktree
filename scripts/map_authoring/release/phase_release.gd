@tool
extends RefCounted
## F10 Q4 (contracts/f10_first_phase.md): an authored phase is a sequence of
## published maps. Each map stays one certified stage; the composer renames its
## stage, prefixes its slots, objectives, portals and witnesses, and turns the
## named exit of every map but the last into a travel portal (both ways) to the
## next map's entrance. Pure composition; preparation runs only in the game.
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const FOLDER := "res://data/expedition/phases"
const REVISION := "authored_phase_v2"
const MAX_MAPS := 8
const STAGE_KEYS := ["stage_id","from_stage","to_stage"]

static func fail(code: String, id: String = "") -> Dictionary:
	var messages := {"phase_missing":"A fase não está registrada.","phase_invalid":"O registro da fase está inválido.","phase_exit_missing":"Um mapa da fase não tem a saída indicada para o próximo.","phase_completion_missing":"O último mapa da fase precisa de uma saída de conclusão.","phase_completion_misplaced":"Só o último mapa da fase pode concluir a fase."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":id,"field":"phase","message":messages.get(code,"Não foi possível preparar a fase: "+code)}]}

static func valid_definition(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or value.get("registry_version") != 1: return false
	if not MapRelease.valid_id(value.get("phase_id")) or not MapRelease.valid_name(value.get("title")): return false
	var maps: Variant = value.get("maps")
	if not maps is Array or maps.size() < 2 or maps.size() > MAX_MAPS: return false
	for index: int in maps.size():
		var item: Variant = maps[index]
		var last: bool = index == maps.size()-1
		if not item is Dictionary or item.size() != (1 if last else 2) or not MapRelease.valid_id(item.get("package_id")): return false
		if not last and not MapRelease.valid_id(item.get("exit")): return false
	return true

static func definition(phase_id: String, folder: String = FOLDER) -> Dictionary:
	if not MapRelease.valid_id(phase_id): return fail("phase_missing",phase_id)
	var path := folder.path_join(phase_id+".json")
	if not FileAccess.file_exists(path): return fail("phase_missing",phase_id)
	var decoded := StrictJSON.new().decode(FileAccess.get_file_as_bytes(path))
	if not decoded.ok or not valid_definition(decoded.value) or decoded.value.phase_id != phase_id: return fail("phase_invalid",phase_id)
	return {"ok":true,"definition":decoded.value}

## [{phase_id, title}] of every valid registered phase, by file name.
static func phases(folder: String = FOLDER) -> Array:
	var result: Array = []
	var files := DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		if not file.ends_with(".json"): continue
		var read := definition(file.trim_suffix(".json"),folder)
		if read.ok: result.append({"phase_id":read.definition.phase_id,"title":read.definition.title})
	return result

## Runtime only: prepares every map like the gameplay test, then composes.
static func prepare(phase_id: String, listing: Dictionary = {}, folder: String = FOLDER) -> Dictionary:
	var read := definition(phase_id,folder)
	if not read.ok: return read
	var prepared: Array = []; var metrics: Array = []
	for item: Dictionary in read.definition.maps:
		var started := Time.get_ticks_usec()
		var map := MapRelease.prepare(item.package_id,listing)
		if not map.ok: return map
		prepared.append(map)
		metrics.append({"package_id":item.package_id,"prepare_ms":(Time.get_ticks_usec()-started)/1000.0})
	var composed := compose(read.definition,prepared)
	if composed.ok: composed["metrics"] = metrics
	return composed

## Pure: prepared[i] is MapRelease.prepare of definition.maps[i].
static func compose(phase: Dictionary, prepared: Array) -> Dictionary:
	if not valid_definition(phase) or prepared.size() != phase.maps.size(): return fail("phase_invalid")
	var maps: Array = []
	for index: int in prepared.size():
		var data: Dictionary = (prepared[index].manifest as ExpeditionManifest).to_data()
		if data.stages.size() != 1: return fail("phase_invalid",phase.maps[index].package_id)
		var stage_id := "%s_%d" % [phase.phase_id,index+1]
		var prefix := "m%d_" % (index+1)
		var old_stage: String = data.stages[0].stage_id
		_restage(data,old_stage,stage_id)
		var entry: Dictionary = prepared[index].entry.duplicate(true); _restage(entry,old_stage,stage_id)
		for slot: Dictionary in data.population.slots: slot.slot_id = prefix+String(slot.slot_id)
		for objective: Dictionary in data.objectives: objective.objective_id = prefix+String(objective.objective_id)
		for portal: Dictionary in data.portals: portal.portal_id = prefix+String(portal.portal_id)
		var witnesses: Dictionary = {}
		for key: String in data.witnesses: witnesses[key.get_slice("/",0)+"/"+prefix+key.substr(key.find("/")+1)] = data.witnesses[key]
		data.witnesses = witnesses
		var rules: Dictionary = {}
		for key: String in prepared[index].rules: rules[prefix+key] = prepared[index].rules[key].duplicate(true)
		maps.append({"data":data,"entry":entry,"rules":rules,"stage_id":stage_id,"prefix":prefix,"candidate_hash":prepared[index].candidate_hash})
	var objectives: Array = []; var portals: Array = []; var slots: Array = []; var stages: Array = []; var witnesses: Dictionary = {}; var rules: Dictionary = {}
	for index: int in maps.size():
		var map: Dictionary = maps[index]
		var last: bool = index == maps.size()-1
		var exit_id: String = "" if last else map.prefix+String(phase.maps[index].exit)
		var exit: Dictionary = {}; var completions := 0
		if not last and not map.data.objectives.any(func(objective: Dictionary) -> bool: return objective.objective_id == exit_id): return fail("phase_exit_missing",exit_id)
		for objective: Dictionary in map.data.objectives:
			if objective.objective_id == exit_id: exit = objective; continue
			if objective.outcome == "phase_completion":
				if not last: return fail("phase_completion_misplaced",String(objective.objective_id))
				completions += 1
			objectives.append(objective)
		if last and completions == 0: return fail("phase_completion_missing",phase.maps[index].package_id)
		if not last:
			if exit.is_empty() or exit.outcome not in ["early_exit","phase_completion"]: return fail("phase_exit_missing",exit_id)
			var next: Dictionary = maps[index+1]
			var entrance: String = next.data.stages[0].entrance
			portals.append({"portal_id":map.prefix+"to_next","kind":"travel","from_stage":map.stage_id,"from_socket":exit.socket_id,"to_stage":next.stage_id,"to_socket":entrance,"from_anchor":exit.point.duplicate(true),"to_anchor":next.entry.duplicate(true)})
			portals.append({"portal_id":next.prefix+"back","kind":"travel","from_stage":next.stage_id,"from_socket":entrance,"to_stage":map.stage_id,"to_socket":exit.socket_id,"from_anchor":next.entry.duplicate(true),"to_anchor":exit.point.duplicate(true)})
		portals.append_array(map.data.portals)
		slots.append_array(map.data.population.slots)
		stages.append_array(map.data.stages)
		witnesses.merge(map.data.witnesses)
		rules.merge(map.rules)
	var hashes: Array = []
	for map: Dictionary in maps: hashes.append(map.candidate_hash)
	var root: Dictionary = maps[0].data.duplicate(true)
	root.stages = stages; root.objectives = objectives; root.portals = portals; root.witnesses = witnesses
	root.population.slots = slots
	root.input.phase_id = phase.phase_id; root.input.entry_stage_id = maps[0].stage_id
	root.input.erase("preview_candidate_hash")
	var phase_hash := Canonical.digest([REVISION,phase,hashes])
	root.input["phase_hash"] = phase_hash
	var presentations := {}
	for index: int in maps.size():
		if not prepared[index].get("release") is Dictionary or not MapRelease.valid_entry(prepared[index].release): return fail("phase_invalid",phase.maps[index].package_id)
		presentations[maps[index].stage_id] = prepared[index].release.duplicate(true)
	root.input["authored_presentations"] = presentations
	var manifest := ExpeditionManifest.new(); manifest._data = root
	return {"ok":true,"manifest":manifest,"rules":rules,"phase_hash":phase_hash,"entry":maps[0].entry.duplicate(true),"stages":stages.map(func(stage: Dictionary) -> String: return stage.stage_id)}

static func _restage(value: Variant, from: String, to: String) -> void:
	if value is Dictionary:
		for key: Variant in value:
			if key in STAGE_KEYS and value[key] is String and value[key] == from: value[key] = to
			else: _restage(value[key],from,to)
	elif value is Array:
		for item: Variant in value: _restage(item,from,to)
