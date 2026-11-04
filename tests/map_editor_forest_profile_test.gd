extends SceneTree
## F10 Q4: where the frame goes on a published field. Opens forest_terraces in
## the real gameplay app and measures frames with everything on, with enemies
## paused, with the map drawing hidden, and with both.
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
var app: App
var checks: Array[Dictionary] = []
var report: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool, detail: Variant = "") -> void:
	checks.append({"id":id,"ok":ok,"detail":str(detail)}); print("F10_FOREST_PROFILE_CHECK "+id+" "+str(ok)+" "+str(detail))
func sample(label: String, seconds: float = 2.0) -> Dictionary:
	await process_frame; await process_frame
	var frames := 0; var total := 0.0; var worst := 0.0; var process := 0.0; var physics := 0.0; var draws := 0.0
	var last := Time.get_ticks_usec(); var begin := last
	while Time.get_ticks_usec()-begin < int(seconds*1000000.0):
		await process_frame
		var now := Time.get_ticks_usec(); var ms := (now-last)/1000.0; last = now
		frames += 1; total += ms; worst = maxf(worst,ms)
		process += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var row := {"frames":frames,"mean_ms":snappedf(total/maxf(1,frames),0.1),"worst_ms":snappedf(worst,0.1),"process_ms":snappedf(process/maxf(1,frames),0.1),"physics_ms":snappedf(physics/maxf(1,frames),0.1),"draw_calls":int(draws/maxf(1,frames)),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))}
	report[label] = row; print("F10_FOREST_PROFILE_SAMPLE "+label+" "+JSON.stringify(row))
	return row
func set_enemies(host: Node, enabled: bool) -> void:
	for enemy: Node in host.enemies:
		if is_instance_valid(enemy): enemy.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
func run() -> void:
	root.size = Vector2i(1280,720)
	var loaded := MapRelease.load_package("forest_terraces")
	check("package_loads",loaded.ok,loaded.get("code",""))
	if not loaded.ok: finish(); return
	var candidate := Candidate.create("patrol",loaded.package,loaded.package.source_hash)
	var created := Launcher.create_session(candidate.candidate,"mage")
	var window := Launcher.create_window(created.path)
	app = App.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var started_at := Time.get_ticks_usec()
	var opened := app.open_window(window.path); var started := app.start() if opened.ok else opened
	report["open_start_ms"] = snappedf((Time.get_ticks_usec()-started_at)/1000.0,1.0)
	check("field_starts",started.get("ok",false),started.get("code",""))
	if not started.get("ok",false): finish(); return
	var host := app.host
	report["enemies"] = host.enemies.size()
	await sample("all_on")
	set_enemies(host,false)
	await sample("enemies_paused")
	set_enemies(host,true)
	var view := host.expedition_view as CanvasItem
	view.visible = false
	await sample("map_hidden")
	set_enemies(host,false)
	await sample("both_off")
	view.visible = true
	host.expedition_view.set_process(false)
	await sample("paused_view_sync_off")
	host.expedition_view.set_process(true)
	host.ui_root.process_mode = Node.PROCESS_MODE_DISABLED
	await sample("paused_ui_off")
	host.ui_root.process_mode = Node.PROCESS_MODE_INHERIT
	host.set_process(false)
	await sample("paused_host_process_off")
	host.set_process(true)
	host.player.process_mode = Node.PROCESS_MODE_DISABLED
	await sample("paused_player_off")
	host.player.process_mode = Node.PROCESS_MODE_INHERIT
	set_enemies(host,true)

	check("measured",report.size() >= 5)
	print("F10_FOREST_PROFILE_REPORT "+JSON.stringify(report))
	await app.suspend()
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_FOREST_PROFILE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
