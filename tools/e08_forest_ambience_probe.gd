extends SceneTree
## E08 P5 A2 native probe (non-headless). Boots the forest stage (seed 42), captures it
## with and without the ambience layer at camera zoom 50/100/160 and UI scale 120%,
## then compares frame cost with the layer on and off.
## Usage: --script res://tools/e08_forest_ambience_probe.gd -- {output} forest
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
const Layer = preload("res://scripts/presentation/forest_ambience_layer.gd")
const COST_SECONDS := 3.0
const COST_ROUNDS := 2
var folder := ""
func _initialize() -> void: _run.call_deferred()

func shot(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var path := folder.path_join(label + ".png")
	var error := root.get_texture().get_image().save_png(path)
	print("E08_CAPTURE ", path, " error=", error)

func _run() -> void:
	root.size = Vector2i(1280, 720)
	folder = OS.get_cmdline_user_args()[0]
	var f := F.make("e08_ambience_probe")
	var menu := CharacterMenu.new()
	menu.set_profile_facade(f["facade"])
	root.add_child(menu)
	current_scene = menu
	var panel := PhaseSelectionPanel.new()
	menu.add_child(panel)
	panel.configure(menu, f["a"])
	panel.seed_input.text = "42"
	var index := -1
	for k: int in panel.phase_choice.item_count:
		if panel.phase_choice.get_item_text(k) == "Floresta do Santuário": index = k
	if index < 0: push_error("forest missing"); quit(1); return
	panel.phase_choice.select(index)
	panel.phase_choice.item_selected.emit(index)
	var entered: Dictionary = await panel.start()
	if not entered.get("ok", false): push_error(str(entered)); quit(1); return
	var host := entered["root"] as RunController
	paused = true
	host.process_mode = Node.PROCESS_MODE_DISABLED
	host.route_camera.position_smoothing_enabled = false
	host.control_preferences.ui_scale = 1.2
	host._apply_interface_preferences()
	host._update_hud()
	var view := host.expedition_view
	var layer: Variant = view.get_node_or_null(Layer.NODE_NAME)
	var report := {"renderer":RenderingServer.get_current_rendering_method(), "driver":DisplayServer.get_name(), "viewport":[root.size.x, root.size.y], "ui_scale":1.2, "layer_present":layer != null, "particles":Layer.particle_count(), "z_index":Layer.Z_INDEX, "indicator_z":view._effects.z_index if view._effects != null else -1, "seed_text":panel.seed_input.text}
	if layer == null: push_error("forest stage has no ambience layer"); quit(1); return
	# A target marker on the nearest enemy plus the player's own marker, so legibility
	# of the indicators can be judged under the layer.
	var target: EnemyActor = null
	for enemy: EnemyActor in host.enemies:
		if target == null or enemy.global_position.distance_to(host.player.global_position) < target.global_position.distance_to(host.player.global_position): target = enemy
	if target != null: view.indicate(target.world_point(), true)
	view.sync()
	layer.elapsed = 23.0
	for mode: String in ["with", "without"]:
		if mode == "without": layer.visible = false
		for zoom: float in [0.5, 1.0, 1.6]:
			host.route_camera.zoom = Vector2.ONE * zoom
			host.route_camera.force_update_scroll()
			layer.advance(0.0)
			await shot("forest_%s_layer_%d" % [mode, int(zoom * 100)])
	layer.visible = true
	# Cost: unlimited frame rate, static paused scene; only the layer is made to run.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	host.route_camera.zoom = Vector2.ONE
	host.route_camera.force_update_scroll()
	var samples := {"with":{"frame_ms":[], "script_ms":[], "draw_calls":[]}, "without":{"frame_ms":[], "script_ms":[], "draw_calls":[]}}
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	for round_index: int in COST_ROUNDS:
		for mode: String in ["with", "without"]:
			layer.visible = mode == "with"
			layer.set_process(mode == "with")
			for unused: int in 30: await process_frame
			var deadline := Time.get_ticks_usec() + int(COST_SECONDS * 1000000.0)
			var last := Time.get_ticks_usec()
			while Time.get_ticks_usec() < deadline:
				await process_frame
				var now := Time.get_ticks_usec()
				samples[mode].frame_ms.append(float(now - last) / 1000.0); last = now
				samples[mode].script_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
				samples[mode].draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var cost := {}
	for mode: String in ["with", "without"]:
		cost[mode] = {"frames":samples[mode].frame_ms.size(), "frame_ms_median":_percentile(samples[mode].frame_ms, 0.5), "frame_ms_p95":_percentile(samples[mode].frame_ms, 0.95), "script_ms_median":_percentile(samples[mode].script_ms, 0.5), "script_ms_p95":_percentile(samples[mode].script_ms, 0.95), "draw_calls_median":_percentile(samples[mode].draw_calls, 0.5)}
	report["cost"] = cost
	report["note"] = "tree paused, host disabled, only the layer processes; vsync off; two interleaved A/B rounds of %.0f s" % COST_SECONDS
	var file := FileAccess.open(folder.path_join("ambience_cost.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true)); file.close()
	print("E08_AMBIENCE_COST ", JSON.stringify(report))
	quit()

func _percentile(values: Array, fraction: float) -> float:
	if values.is_empty(): return 0.0
	var sorted := values.duplicate(); sorted.sort()
	return float(sorted[mini(sorted.size() - 1, int(floorf(fraction * float(sorted.size()))))])
