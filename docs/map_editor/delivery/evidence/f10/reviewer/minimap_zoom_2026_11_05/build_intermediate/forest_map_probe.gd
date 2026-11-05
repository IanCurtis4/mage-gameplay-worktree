extends SceneTree
## Native standard engine mounting the exact exported PCK, with isolated APPDATA.
var checks: Array[Dictionary] = []
var timings := {}
func _initialize() -> void: run.call_deferred()
func check(id: String, value: bool, detail: Variant = "") -> void:
	checks.append({"id": id, "ok": value, "detail": str(detail)})
	print("F10_FOREST_MAP_CHECK ", id, " ", value, " ", detail)
func frames(count: int) -> void:
	for index: int in count: await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	var menu: CharacterMenu = load("res://scenes/character_menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	menu.name_input.text = "Prova do minimapa"
	var created := menu.create_character(&"mage")
	check("packaged_menu_creates_character", created.get("ok", false))
	if not created.get("ok", false): finish(); return
	var character: String = menu.facade.current_profile().selected_character_id
	var panel := PhaseSelectionPanel.new()
	menu.add_child(panel); panel.configure(menu, character)
	var index := -1
	for candidate: int in panel.phase_choice.item_count:
		if panel.phase_choice.get_item_text(candidate) == "Floresta do Santuário": index = candidate
	check("forest_available", index >= 0)
	if index < 0: finish(); return
	panel.phase_choice.select(index); panel.phase_choice.item_selected.emit(index)
	var started := Time.get_ticks_usec()
	var entered: Dictionary = await panel.start()
	timings["entry_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	check("forest_enters_from_exported_pack", entered.get("ok", false), entered.get("error_code", ""))
	if not entered.get("ok", false): finish(); return
	var host: RunController = entered["root"]
	await frames(12)
	host._update_stage_minimap(0.1)
	var minimap := host.stage_minimap
	var live := 0
	var outside_camera := false
	for enemy: CombatActor in host.enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			live += 1
			outside_camera = outside_camera or not root.get_visible_rect().has_point(host.get_canvas_transform() * enemy.global_position)
	check("whole_forest_population_marked", live > 0 and minimap._markers.enemies.size() == live, [live, minimap._markers.enemies.size()])
	check("offscreen_enemies_marked", outside_camera)
	var square: Rect2 = minimap._background.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, minimap._background.size)
	check("square_map_on_screen", is_equal_approx(square.size.x, square.size.y) and root.get_visible_rect().encloses(square), square)
	check("player_marker_and_heading_match", minimap._markers.player.is_equal_approx(ExpeditionGeometryView.project(host.player.world_point().position)) and minimap._markers.heading.is_equal_approx(host.player.character_animation.state.facing.normalized()))
	var bounds := minimap._background.bounds
	var hud_scale := host.ui_root.scale
	host.reset_camera_zoom(); host.change_camera_zoom(-3)
	await frames(4)
	check("zoom_out_without_changing_map_or_hud", host.route_camera.zoom.is_equal_approx(Vector2.ONE * 0.7) and minimap._background.bounds == bounds and host.ui_root.scale == hud_scale)
	var evidence := OS.get_environment("F10_EVIDENCE")
	check("native_map_capture", root.get_texture().get_image().save_png(evidence.path_join("forest_minimap_zoom.png")) == OK)
	var status := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	started = Time.get_ticks_usec()
	var suspended: Dictionary = await status.run_action({"kind": "suspend"})
	timings["suspend_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	check("forest_suspends_with_minimap", suspended.get("ok", false), suspended.get("error_code", ""))
	if not suspended.get("ok", false): finish(); return
	var lobby := current_scene as CharacterMenu
	var again := PhaseSelectionPanel.new()
	lobby.add_child(again); again.configure(lobby, character)
	started = Time.get_ticks_usec()
	var resumed: Dictionary = await again.start()
	timings["resume_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	check("forest_resumes_with_zoom_preference", resumed.get("ok", false) and (resumed.get("root") as RunController).route_camera.zoom.is_equal_approx(Vector2.ONE * 0.7), resumed.get("error_code", ""))
	if resumed.get("ok", false):
		var restored := resumed["root"] as RunController
		await frames(12)
		restored._update_stage_minimap(0.1)
		check("minimap_rebuilt_from_resumed_world", restored.stage_minimap._markers.has_player and restored.stage_minimap._background.bounds == bounds and restored.stage_minimap._markers.enemies.size() == live)
	finish()
func finish() -> void:
	var ok := checks.size() == 12 and checks.all(func(value: Dictionary) -> bool: return value["ok"])
	print("F10_FOREST_MAP_RESULT ", JSON.stringify({"ok": ok, "count": checks.size(), "checks": checks, "timings": timings, "mode": "standard_engine_with_exported_pack"}))
	paused = false
	quit(0 if ok else 1)
