extends SceneTree
const PackageView = preload("res://scripts/world/map_package_view.gd")
var report := {}
var animate := false
var crowd: Array[CombatActor] = []
func _initialize() -> void: run.call_deferred()
func sample(label: String, seconds: float = 3.0) -> void:
	for k: int in 10: await process_frame
	var values: Array[float] = []; var cpu := 0.0; var draws := 0.0
	var started := Time.get_ticks_usec(); var last := started
	while Time.get_ticks_usec()-started < int(seconds*1e6):
		if animate:
			for enemy: CombatActor in crowd:
				enemy.character_animation.observe(enemy.global_position, 1.0/60.0)
				enemy.queue_redraw()
		await process_frame
		var now := Time.get_ticks_usec(); values.append((now-last)/1000.0); last = now
		cpu += Performance.get_monitor(Performance.TIME_PROCESS)*1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	values.sort(); var total := 0.0
	for value: float in values: total += value
	var row := {"median_ms":values[values.size()/2],"memory_static_bytes":OS.get_static_memory_usage(),"frames":values.size(),"mean_ms":total/values.size(),"p95_ms":values[int((values.size()-1)*0.95)],"p99_ms":values[int((values.size()-1)*0.99)],"max_ms":values[-1],"cpu_ms":cpu/values.size(),"draw_calls":draws/values.size()}
	report[label] = row; print("TERRAIN_PERF_SAMPLE ",label," ",JSON.stringify(row))
func run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var menu: CharacterMenu = load("res://scenes/character_menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu; menu.name_input.text = "Medição de terreno"
	report["memory_before_stage_bytes"] = OS.get_static_memory_usage()
	if not menu.create_character(&"mage").get("ok",false): quit(1); return
	var panel := PhaseSelectionPanel.new(); menu.add_child(panel); panel.configure(menu,menu.facade.current_profile().selected_character_id)
	var phase := -1
	for i: int in panel.phase_choice.item_count:
		if panel.phase_choice.get_item_text(i) == "Floresta do Santuário": phase = i
	if phase < 0: quit(1); return
	panel.seed_input.text = "42"
	panel.phase_choice.select(phase); panel.phase_choice.item_selected.emit(phase)
	var begin := Time.get_ticks_usec()
	var entered: Dictionary = await panel.start()
	report["entry_ms"] = (Time.get_ticks_usec()-begin)/1000.0
	if not entered.get("ok",false): print(entered); quit(1); return
	var host: RunController = entered.root
	report["population"] = host.enemies.size()
	for window: int in 3: await sample("natural_all_on_%d" % window)
	for enemy: CombatActor in host.enemies: enemy.set_process(false)
	await sample("natural_enemy_process_off")
	var view := host.expedition_view
	view.set_process(false)
	await sample("natural_view_sync_off")
	for enemy: CombatActor in host.enemies:
		crowd.append(enemy); enemy.visible = true
		var i := crowd.size()-1
		enemy.global_position = host.player.global_position+Vector2((i%10-5)*65,(i/10-3)*75)
		if enemy.character_animation != null: enemy.character_animation.play(&"walk",Vector2.RIGHT,60.0)
	animate = true
	await sample("crowd_animated_shadows")
	for enemy: CombatActor in crowd: enemy.contact_shadows_enabled = false
	await sample("crowd_animated_no_shadows")
	animate = false
	await sample("crowd_cached_drawing")
	for enemy: CombatActor in crowd: enemy.hide()
	await sample("crowd_hidden")
	for enemy: CombatActor in crowd: enemy.show()
	view.sync()
	var rebuilding: Array[float] = []
	for i: int in 2:
		var skin := PackageView.new(); begin = Time.get_ticks_usec()
		var built := skin.configure(view.package,view.geometry)
		rebuilding.append((Time.get_ticks_usec()-begin)/1000.0)
		print("TERRAIN_PERF_SKIN ",i," ",rebuilding[-1]," ",built.ok)
		if not built.ok: quit(1); return
		skin.free()
	report["skin_build_ms"] = rebuilding
	var screenshot := OS.get_environment("TERRAIN_EVIDENCE").path_join("baseline_crowd.png")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(screenshot)
	crowd.clear()
	host.queue_free()
	for frame: int in 20: await process_frame
	report["memory_after_clear_bytes"] = OS.get_static_memory_usage()
	report["memory_retained_bytes"] = report.memory_after_clear_bytes - report.memory_before_stage_bytes
	print("TERRAIN_PERF_RESULT ",JSON.stringify({"ok":true,"report":report}))
	quit(0)


