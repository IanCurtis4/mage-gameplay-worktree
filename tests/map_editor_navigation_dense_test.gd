extends SceneTree
## Exact historic ports_graph_dense_03 input; compiler authority is now enabled.
const Fixture = preload("res://tests/map_editor_port_fragments_test.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_DENSE_CHECK "+id+" "+str(ok))
func run() -> void:
	var started := Time.get_ticks_usec(); var built := Compiler.compile(Fixture.map_source())
	var compile_usec := Time.get_ticks_usec()-started
	check("historic_dense_source_publishes_without_bypass",built.ok)
	if not built.ok: print(built); finish(); return
	var world := WorldGeometry.new(); world.configure(Compiler.manifest(built.package),"map_preview")
	var before := ExpeditionCanonical.digest(world._stage)
	var eager := OS.get_environment("F9_DENSE_MODE") == "eager"
	var records: Array[Dictionary] = []
	for target: Vector2 in [Vector2(175,4),Vector2(175,95)]:
		var from := Fixture.instance_at(world,"left",Vector2(8,4)); var to := Fixture.instance_at(world,"right",target)
		var trace := {"enabled":true}; started = Time.get_ticks_usec()
		var result := world._path(from,to,built.package.profile,world.geometry_revision,null,not eager,trace)
		var elapsed := Time.get_ticks_usec()-started
		check("historic_target_%s_route"%target.y,result.ok)
		records.append({"target":target,"elapsed_usec":elapsed,"trace":trace,"route_digest":ExpeditionCanonical.digest(result),"result":result})
		print("F9_DENSE_CASE "+JSON.stringify({"target_z":target.y,"elapsed_usec":elapsed,"trace":trace}))
	check("detour_and_direct_fast_path_are_both_exercised",not records[0].trace.get("direct",false) and records[1].trace.get("direct",false))
	check("query_preserves_world",ExpeditionCanonical.digest(world._stage) == before and world._occupancy.is_empty())
	var file := FileAccess.open(OS.get_environment("F9_EVIDENCE").path_join("dense_metrics.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"variant":"eager" if eager else "lazy","compile_usec":compile_usec,"world_digest":before,"authored_volumes":world._stage.volumes.size(),"masses":world._support_index.solid_prisms.size(),"profile":built.package.profile,"records":records},"\t",true,true)); file.close()
	finish()
func finish() -> void:
	var ok := checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_DENSE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
