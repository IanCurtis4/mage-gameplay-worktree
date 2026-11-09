extends SceneTree
## E08 P7-C3 measurements, run with the standard engine and --main-pack on an exact PCK
## (F10 baseline, P3 pilot or P7 candidate). Must parse against every one of them, so it
## references no E08-only class by name: E08 nodes are reached dynamically and recorded as
## unavailable on older packs. Windowed (real renderer), 1280x720, vsync off, seed 42.
## Modes (user args):
##   preparation  -> phase preparation, first call in a new process then a second call in the
##                   same process; manifest/rules digests are RECORDED (P5 republished the forest
##                   maps, so they legitimately differ from the F10 digests), not asserted.
##   ablation     -> forest seed 42 entered through the normal menu; 3 interleaved rounds of
##                   3 s windows: normal / without P6 feedback layer / without P5 forest ambience /
##                   without world audio / all three off. Presentation only, restored after each.
## Output lines: PREPARATION_FINAL_RESULT / TERRAIN_PERF_RESULT (same markers as the F10 tools).
const Phase = preload("res://scripts/map_authoring/release/phase_release.gd")
var report := {}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() else ""
	if mode == "preparation": preparation()
	elif mode == "ablation": await ablation()
	else: push_error("Usage: -- <preparation|ablation>"); quit(2)

func preparation() -> void:
	var id := ""
	for phase: Dictionary in Phase.phases():
		if phase.title == "Floresta do Santuário": id = phase.phase_id
	if id.is_empty(): quit(1); return
	var rows: Array = []
	var ok := true
	for label: String in ["cold_process", "warm_process"]:
		var started := Time.get_ticks_usec()
		var prepared: Dictionary = Phase.prepare(id)
		var ms := (Time.get_ticks_usec() - started) / 1000.0
		var digest := ExpeditionCanonical.digest(prepared.manifest.to_data()) if prepared.get("ok", false) else ""
		var rules := ExpeditionCanonical.digest(prepared.rules) if prepared.get("ok", false) else ""
		ok = ok and prepared.get("ok", false)
		rows.append({"label": label, "ok": prepared.get("ok", false), "total_ms": ms, "manifest_digest": digest, "rules_digest": rules, "lanes": prepared.get("preparation_lanes", 0), "memory_static_bytes": OS.get_static_memory_usage()})
		print("PREPARATION_FINAL_SAMPLE ", JSON.stringify(rows[-1]))
	ok = ok and rows[0].manifest_digest == rows[1].manifest_digest and rows[0].rules_digest == rows[1].rules_digest
	print("PREPARATION_FINAL_RESULT ", JSON.stringify({"ok": ok, "rows": rows}))
	quit(0 if ok else 1)

func sample(label: String, seconds: float = 3.0) -> void:
	for k: int in 10: await process_frame
	var values: Array[float] = []
	var cpu := 0.0
	var draws := 0.0
	var started := Time.get_ticks_usec()
	var last := started
	while Time.get_ticks_usec() - started < int(seconds * 1e6):
		await process_frame
		var now := Time.get_ticks_usec(); values.append((now - last) / 1000.0); last = now
		cpu += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	values.sort()
	var total := 0.0
	for value: float in values: total += value
	var row := {"median_ms": values[values.size() / 2], "memory_static_bytes": OS.get_static_memory_usage(), "frames": values.size(), "mean_ms": total / values.size(), "p95_ms": values[int((values.size() - 1) * 0.95)], "p99_ms": values[int((values.size() - 1) * 0.99)], "max_ms": values[-1], "cpu_ms": cpu / values.size(), "draw_calls": draws / values.size()}
	report[label] = row
	print("TERRAIN_PERF_SAMPLE ", label, " ", JSON.stringify(row))

func ablation() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var menu: Node = load("res://scenes/character_menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	menu.get("name_input").text = "Medição P7"
	report["memory_before_stage_bytes"] = OS.get_static_memory_usage()
	if not menu.call("create_character", &"mage").get("ok", false): quit(1); return
	var panel := PhaseSelectionPanel.new(); menu.add_child(panel)
	panel.configure(menu, menu.get("facade").current_profile().selected_character_id)
	var phase := -1
	for i: int in panel.phase_choice.item_count:
		if panel.phase_choice.get_item_text(i) == "Floresta do Santuário": phase = i
	if phase < 0: quit(1); return
	panel.seed_input.text = "42"
	panel.phase_choice.select(phase); panel.phase_choice.item_selected.emit(phase)
	var begin := Time.get_ticks_usec()
	var entered: Dictionary = await panel.start()
	report["entry_ms"] = (Time.get_ticks_usec() - begin) / 1000.0
	if not entered.get("ok", false): print(entered); quit(1); return
	var host: Node = entered.root
	report["population"] = (host.get("enemies") as Array).size()
	report["memory_after_entry_bytes"] = OS.get_static_memory_usage()
	var bridge: Node = host.call("presentation_events") if host.has_method("presentation_events") else null
	var feedback: CanvasItem = bridge.get_node_or_null("E08PilotFeedback") as CanvasItem if bridge != null else null
	var audio: Node = host.call("presentation_audio") if host.has_method("presentation_audio") else null
	var view: Node = host.get("expedition_view")
	var ambience: CanvasItem = view.get_node_or_null("ForestAmbience") as CanvasItem if view != null else null
	# The bus is resolved by NAME at each use (P0 ablation lesson): the staging buses are
	# recreated after entry, so an index cached here can point past the bus list.
	var audio_bus: StringName = &""
	if audio != null and audio.get("_buses") is Dictionary: audio_bus = audio.get("_buses")[&"general"]
	report["available"] = {"bridge": bridge != null, "feedback_layer": feedback != null, "feedback_script": str(feedback.get_script().resource_path) if feedback != null and feedback.get_script() != null else "", "forest_ambience": ambience != null, "audio": audio != null}
	for window: int in 3:
		await sample("normal_%d" % window)
		_feedback(bridge, feedback, false)
		await sample("without_feedback_layer_%d" % window)
		_feedback(bridge, feedback, true)
		_ambience(ambience, false)
		await sample("without_forest_ambience_%d" % window)
		_ambience(ambience, true)
		_audio(audio, audio_bus, false)
		await sample("without_world_audio_%d" % window)
		_audio(audio, audio_bus, true)
		_feedback(bridge, feedback, false); _ambience(ambience, false); _audio(audio, audio_bus, false)
		await sample("without_e08_presentation_%d" % window)
		_feedback(bridge, feedback, true); _ambience(ambience, true); _audio(audio, audio_bus, true)
	report["memory_end_bytes"] = OS.get_static_memory_usage()
	await RenderingServer.frame_post_draw
	var evidence := OS.get_environment("TERRAIN_EVIDENCE")
	if not evidence.is_empty(): root.get_texture().get_image().save_png(evidence.path_join("ablation_forest.png"))
	host.queue_free()
	for frame: int in 20: await process_frame
	report["memory_after_clear_bytes"] = OS.get_static_memory_usage()
	report["memory_retained_bytes"] = report.memory_after_clear_bytes - report.memory_before_stage_bytes
	print("TERRAIN_PERF_RESULT ", JSON.stringify({"ok": true, "report": report, "mode": "p7_presentation_ablation_no_runtime_changes"}))
	quit(0)

func _feedback(bridge: Node, feedback: CanvasItem, on: bool) -> void:
	if bridge != null: bridge.set_process(on)
	if feedback != null:
		feedback.set_process(on); feedback.visible = on

func _ambience(ambience: CanvasItem, on: bool) -> void:
	if ambience != null:
		ambience.set_process(on); ambience.visible = on

func _audio(audio: Node, bus_name: StringName, on: bool) -> void:
	if audio == null or not audio.has_method("_pause_world"): return
	audio.call("_pause_world", not on)
	var bus := AudioServer.get_bus_index(bus_name) if not bus_name.is_empty() else -1
	report["audio_bus_resolved"] = bus
	if bus > 0 and AudioServer.get_bus_effect_count(bus) > 0: AudioServer.set_bus_effect_enabled(bus, 0, on)
