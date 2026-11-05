extends SceneTree
const Phase = preload("res://scripts/map_authoring/release/phase_release.gd")
const Maps = preload("res://scripts/map_authoring/release/map_release.gd")
func _initialize() -> void: run.call_deferred()
static func lane(items: Array, ordinal: int) -> Array:
	var values: Array = []
	for index: int in range(ordinal,items.size(),2):
		var begin := Time.get_ticks_usec()
		var built := Maps.prepare(items[index].package_id)
		values.append({"index":index,"built":built,"ms":(Time.get_ticks_usec()-begin)/1000.0})
	return values
func run() -> void:
	var phases := Phase.phases(); var id := ""
	for phase: Dictionary in phases:
		if phase.title == "Floresta do Santuário": id = phase.phase_id
	if id.is_empty(): quit(1); return
	var begin := Time.get_ticks_usec(); var result: Dictionary; var metrics: Array = []
	var mode := OS.get_environment("PREPARATION_MODE")
	if mode == "parallel":
		var definition := Phase.definition(id)
		var threads: Array[Thread] = [Thread.new(),Thread.new()]
		for index: int in 2:
			if threads[index].start(lane.bind(definition.definition.maps,index)) != OK: quit(2); return
		var prepared: Array = []; prepared.resize(definition.definition.maps.size())
		for worker: Thread in threads:
			var rows: Array = worker.wait_to_finish()
			for row: Dictionary in rows:
				if not row.built.ok: print(row.built); quit(1); return
				prepared[row.index] = row.built; metrics.append({"index":row.index,"ms":row.ms,"details":row.built.get("prepare_timings",{})})
		result = Phase.compose(definition.definition,prepared)
	else:
		result = Phase.prepare(id); metrics = result.get("metrics",[])
	var elapsed := (Time.get_ticks_usec()-begin)/1000.0
	print("PREPARATION_LANES_RESULT ",JSON.stringify({"ok":result.ok,"mode":mode,"total_ms":elapsed,"metrics":metrics,"manifest_digest":ExpeditionCanonical.digest(result.manifest.to_data()) if result.ok else "","rules_digest":ExpeditionCanonical.digest(result.rules) if result.ok else "","cpus":OS.get_processor_count()}))
	quit(0 if result.ok else 1)
