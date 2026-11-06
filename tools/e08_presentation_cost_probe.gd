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
	var bridge: Node = host.call("presentation_events") if host.has_method("presentation_events") else null
	var feedback: Node = bridge.get_node_or_null("E08PilotFeedback") if bridge != null else null
	var audio: Node = host.call("presentation_audio") if host.has_method("presentation_audio") else null
	var campaign_panel: Control = host.ui_root.get_node("ExpeditionStatus")
	var audio_bus_name: StringName = audio.get("_buses")[&"general"] if audio != null else &""
	for window: int in 3:
		await sample("normal_%d" % window)
		if bridge != null: bridge.set_process(false)
		if feedback != null: feedback.set_process(false)
		await sample("without_bridge_tick_%d" % window)
		if bridge != null: bridge.set_process(true)
		if feedback != null: feedback.set_process(true)
		campaign_panel.set_process(false); campaign_panel.hide()
		await sample("without_stage_panel_%d" % window)
		report["panel_hidden_%d" % window] = not campaign_panel.visible
		campaign_panel.set_process(true); campaign_panel.show()
		if audio != null:
			audio.call("_pause_world",true)
			AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(audio_bus_name),0,false)
		await sample("without_world_audio_%d" % window)
		if audio != null:
			AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(audio_bus_name),0,true)
			audio.call("_pause_world",false)
	print("TERRAIN_PERF_RESULT ",JSON.stringify({"ok":true,"report":report,"mode":"counterfactual_cosmetic_ablation_no_runtime_changes"}))
	quit(0)

