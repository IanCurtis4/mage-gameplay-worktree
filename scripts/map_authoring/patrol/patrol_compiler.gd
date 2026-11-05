@tool
extends RefCounted
## F10 Q4: a patrol package embeds its encounter package (itself up to 4 MiB);
## a field-scale map exceeds 4 MiB here, so the patrol and release ceiling is twice
## the encounter ceiling and the worker request twice that.
const MAX_PACKAGE_BYTES := 8*1024*1024
const MAX_REQUEST_BYTES := 16*1024*1024
const Document = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Patrol = preload("res://scripts/core/expedition/patrol/enemy_patrol.gd")
const Worker = preload("res://scripts/map_authoring/population/population_worker.gd")
const REVISION := "map_patrol_v1"
const PREVIEW_PHASE := "editor_patrol_preview"
## Exact package bytes, after all live dependencies have been checked below.
## The bounded proof cache contains no actor, graph or mutable run state.
static var _proofs: Dictionary = {}
static var _proof_mutex := Mutex.new()
static func fail(code: String, id: String = "", point: Dictionary = {}) -> Dictionary:
	var messages := {"patrol_empty":"Importe encontros com slots realizados.","patrol_invalid":"A rota precisa de dois a 32 pontos, modo e slots válidos.","patrol_waypoint_invalid":"Ponto sem suporte, corpo válido ou fora do leash fixo.","patrol_unreachable":"Um trecho da patrulha não é transitável pelo corpo do inimigo.","patrol_leash":"O caminho sai do leash fixo do slot.","patrol_slot_missing":"O slot referenciado não existe neste encontro.","patrol_slot_duplicate":"Um slot não pode ter duas patrulhas.","patrol_unsupported":"Esta espécie não usa o engajamento necessário à patrulha.","patrol_limit":"A patrulha excede o orçamento técnico.","cancelled":"Operação cancelada.","stale_source":"A fonte mudou; compile novamente."}
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"entity_id":id,"field":"patrol","surface_id":point.get("surface_id",""),"location":Population.vector(point.position_xyz) if point.has("position_xyz") else Vector3.ZERO,"severity":"error","message":messages.get(code,"Revise os dados da patrulha: "+code),"suggestion":"Selecione a rota e ajuste o ponto ou o slot."}]}
static func definition(route: Dictionary) -> Dictionary:
	var result := route.duplicate(true); result.waypoints = []; result.slot_ids.sort()
	for p: Dictionary in route.waypoints: result.waypoints.append({"point_id":p.point_id,"point":Population.anchor(p).to_data(),"wait_seconds":float(p.wait_seconds)})
	return result
static func compile(source: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	if Engine.is_editor_hint(): return request({"source":source},cancel)
	var checked := Document.validate(source)
	if not checked.ok: return fail(checked.code)
	if source.population.is_empty(): return fail("patrol_empty")
	if cancel.is_valid() and cancel.call(): return fail("cancelled")
	var built := Population.compile(source.population[0],cancel)
	if not built.ok: return built
	var manifest := Population.manifest(built.package)
	manifest._data.input["phase_id"] = PREVIEW_PHASE
	var world := WorldGeometry.new(); world.configure(manifest,"map_preview")
	var loaded := Catalog.load_current()
	if not loaded.ok: return loaded
	var routes: Array = source.patrols.duplicate(true); routes.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.patrol_id < b.patrol_id)
	for route: Dictionary in routes:
		if cancel.is_valid() and cancel.call(): return fail("cancelled")
		var def := definition(route)
		if not Patrol.valid_definition(def): return fail("patrol_invalid",route.patrol_id)
		for id: String in def.slot_ids:
			for slot: Dictionary in manifest._data.population.slots:
				if slot.slot_id != id: continue
				var mob: MobDefinition = loaded.catalog.get_definition(StringName(slot.species_id))
				if mob == null or mob.aggro_radius <= 0: return fail("patrol_unsupported",id)
				var profile: Dictionary = built.package.profile.duplicate(true); profile.radius = maxf(float(profile.radius),mob.collision_radius)
				var result := Patrol.validate_route(def,world,ExpeditionPopulationPlanner.point(slot.home),profile,mob.leash_radius)
				if not result.ok:
					var where: Dictionary = {}
					for p: Dictionary in route.waypoints:
						if p.point_id == result.get("point_id",""): where = p
					return fail(result.code,route.patrol_id,where)
				slot["patrol"] = def.duplicate(true)
	var package := {"format_version":1,"compiler_revision":REVISION,"source_hash":Document.hash_source(source),"population_package":built.package,"manifest":manifest.to_data()}
	package["package_hash"] = ExpeditionCanonical.digest(package)
	if var_to_bytes(package).size() > MAX_PACKAGE_BYTES: return fail("patrol_limit")
	return {"ok":true,"code":"","input_hash":package.source_hash,"output_hash":package.package_hash,"diagnostics":[],"package":package}
static func validate_package(package: Dictionary) -> bool:
	if package.size() != 6 or not package.has_all(["format_version","compiler_revision","source_hash","population_package","manifest","package_hash"]) or not ExpeditionCanonical.valid(package): return false
	var bytes := var_to_bytes(package)
	if bytes.size() > MAX_PACKAGE_BYTES: return false
	if package.format_version != 1 or package.compiler_revision != REVISION or not Schema._type(package.source_hash,"hash") or not Schema._type(package.package_hash,"hash") or not package.population_package is Dictionary or not package.manifest is Dictionary: return false
	var copy := package.duplicate(true); copy.erase("package_hash")
	if ExpeditionCanonical.digest(copy) != package.package_hash: return false
	if Engine.is_editor_hint(): return request({"package":package}).ok
	var diagnostic_stamp := Time.get_ticks_usec()
	if not Population.validate_package(package.population_package): return false
	var population_validation_ms := (Time.get_ticks_usec()-diagnostic_stamp)/1000.0
	var base: Dictionary = package.population_package.manifest.duplicate(true)
	base.input["phase_id"] = PREVIEW_PHASE
	var candidate: Dictionary = package.manifest.duplicate(true)
	if not candidate.get("population") is Dictionary or not candidate.population.get("slots") is Array: return false
	if candidate.population.slots.size() != base.population.slots.size(): return false
	for slot: Variant in candidate.population.slots:
		if not slot is Dictionary: return false
		if slot.has("patrol"):
			if not Patrol.valid_definition(slot.patrol) or slot.slot_id not in slot.patrol.slot_ids: return false
			slot.erase("patrol")
	if candidate != base: return false
	var loaded := Catalog.load_current()
	if not loaded.ok: return false
	var proof_key: String = Schema.bytes_hash(bytes)+"/"+loaded.hash+"/"+loaded.policy_hash
	_proof_mutex.lock(); var known: bool = _proofs.has(proof_key); _proof_mutex.unlock()
	if known: return true
	diagnostic_stamp = Time.get_ticks_usec()
	var planned := ExpeditionPopulationPlanner.build(manifest(package),loaded.catalog,package.population_package.rules)
	if OS.get_environment("RAGRPG_PREPARATION_PROFILE") == "1":
		print("F10_PACKAGE_VALIDATION_PROFILE "+JSON.stringify({"package_hash":package.package_hash,"population_validation_ms":population_validation_ms,"population_admission_ms":(Time.get_ticks_usec()-diagnostic_stamp)/1000.0,"navigation":planned.get("navigation_metrics",[])}))
	if not planned.ok: return false
	for slot: Dictionary in planned.slots.values():
		if not slot.has("patrol"): continue
		var def: Dictionary = slot.patrol
		for id: String in def.slot_ids:
			if not planned.slots.has(id) or planned.slots[id].get("patrol",{}) != def: return false
		var mob: MobDefinition = loaded.catalog.get_definition(StringName(slot.species_id))
		if mob == null or mob.aggro_radius <= 0 or not Patrol.validate_route(def,planned.worlds[slot.stage_id],ExpeditionPopulationPlanner.point(slot.home),slot.traversal,mob.leash_radius).ok: return false
	_proof_mutex.lock()
	if _proofs.size() >= 8: _proofs.clear()
	_proofs[proof_key] = true
	_proof_mutex.unlock()
	return true
static func manifest(package: Dictionary) -> ExpeditionManifest:
	var result := ExpeditionManifest.new(); result._data = package.manifest.duplicate(true); return result
static func request(payload: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	# Reuse the producer's process lifecycle, retaining one compiler authority.
	var worker_script := "res://scripts/map_authoring/patrol/worker_headless.gd"
	var root := ProjectSettings.globalize_path("res://.godot/map_authoring/jobs/"+Crypto.new().generate_random_bytes(12).hex_encode())
	DirAccess.make_dir_recursive_absolute(root)
	var input := root.path_join("input.bin"); var output := root.path_join("output.bin")
	var file := FileAccess.open(input,FileAccess.WRITE)
	if file == null: return fail("worker_io")
	file.store_buffer(var_to_bytes(payload)); file.close()
	if cancel.is_valid() and cancel.call(): return fail("cancelled")
	var pid := OS.create_process(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",root.path_join("engine.log"),"--script",worker_script,"--",input,output],false)
	if pid < 0: return fail("worker_start_failed")
	var start := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if cancel.is_valid() and cancel.call(): OS.kill(pid); return fail("cancelled")
		if Time.get_ticks_msec()-start > 180000: OS.kill(pid); return fail("worker_timeout")
		OS.delay_msec(20)
	var log_text := FileAccess.get_file_as_string(root.path_join("engine.log")) if FileAccess.file_exists(root.path_join("engine.log")) else ""
	if "SCRIPT ERROR:" in log_text or "ERROR:" in log_text or not FileAccess.file_exists(output): return fail("worker_incomplete")
	var bytes := FileAccess.get_file_as_bytes(output)
	Worker.discard(root)
	if bytes.size() > MAX_REQUEST_BYTES: return fail("patrol_limit")
	var result: Variant = bytes_to_var(bytes)
	return result if result is Dictionary and result.get("ok") is bool else fail("worker_incomplete")
