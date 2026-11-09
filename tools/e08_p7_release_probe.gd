extends SceneTree
## E08 P7-C3: native standard engine mounting the EXACT exported candidate PCK (--main-pack),
## isolated APPDATA. Never runs inside the release template; never touches personal profiles.
## Modes (user args):
##   inspect <evidence_dir> <expected_assets.json> <app_name>
##       application identity + every expected E08 runtime asset present/loadable in the pack
##       + functional catalog loads (audio cues, VFX flipbooks, directional/species bodies,
##       map packages) + full res:// listing of the pack (asset manifest).
##   forest <evidence_dir>
##       pilot P0/P3 forest probe adapted to P4-P6: entry seed 42, UI 120%, minimap, species
##       bodies (V2 directional), P6 feedback layer, P5 ambience, limiter, suspend/resume.
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
const PilotVisual = preload("res://scripts/presentation/e08_pilot_visual.gd")
const Species = preload("res://scripts/presentation/species_presentation_catalog.gd")
const FOREST_SPECIES: Array[StringName] = [&"forest_wolf", &"forest_boar", &"forest_stalker", &"forest_canopy_archer", &"forest_ancient_warden"]
var checks: Array[Dictionary] = []
var timings := {}
var folder := ""

func _initialize() -> void: _run.call_deferred()

func check(id: String, value: bool, detail: Variant = "") -> void:
	checks.append({"id": id, "ok": value, "detail": str(detail)})
	print("E08_P7_CHECK ", id, " ", value, " ", str(detail).left(300))

func frames(count: int) -> void:
	for index: int in count: await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2: push_error("Usage: -- <inspect|forest> <evidence_dir> ..."); quit(2); return
	folder = args[1]
	if args[0] == "inspect" and args.size() == 4: inspect(args[2], args[3])
	elif args[0] == "forest": await forest()
	else: push_error("Unknown mode"); quit(2)

# --- inspect ---------------------------------------------------------------------------------

func _walk(path: String, out: Array[String]) -> void:
	for file: String in DirAccess.get_files_at(path): out.append(path.path_join(file))
	for dir: String in DirAccess.get_directories_at(path):
		_walk(path.path_join(dir), out)

func inspect(expected_path: String, app_name: String) -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var name: String = ProjectSettings.get_setting("application/config/name", "")
	check("app_name", name == app_name, name)
	check("isolated_user_dir", OS.get_user_data_dir().ends_with("/" + app_name), OS.get_user_data_dir())
	check("normal_main_scene", main_scene == "res://scenes/character_menu.tscn" and ResourceLoader.exists(main_scene), main_scene)
	check("forest_phase_registry", FileAccess.file_exists("res://data/expedition/phases/forest_sanctuary.json") and FileAccess.file_exists("res://data/map_authoring/release_packages.json"))
	check("preparation_manifest", FileAccess.file_exists("res://scripts/core/expedition/snapshot/runtime_manifest.json"))
	check("native_limiter_class", ClassDB.class_exists("AudioEffectHardLimiter"))
	# Expected assets (computed by the packaging script from the candidate commit).
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	var groups := {}
	var missing: Array[String] = []
	for group: String in expected:
		var total := 0
		var present := 0
		for path: String in expected[group]:
			total += 1
			var ok := false
			match path.get_extension():
				"png":
					var texture := load(path) as Texture2D
					ok = texture != null and texture.get_width() > 0
				"wav":
					var stream := load(path) as AudioStreamWAV
					ok = stream != null and stream.get_length() > 0.0
				"json":
					ok = FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)) != null
				_:
					ok = FileAccess.file_exists(path) and FileAccess.get_file_as_bytes(path).size() > 0
			if ok: present += 1
			else: missing.append(path)
		groups[group] = [present, total]
		check("assets_" + group, present == total and total > 0, "%d/%d" % [present, total])
	# Functional catalogs.
	var cue_ids: Array = AudioEventCatalog.ids()
	var loadable_cues := 0
	for id: StringName in cue_ids:
		var stream := load(str(AudioEventCatalog.definition(id).get("path", ""))) as AudioStreamWAV
		if stream != null and stream.get_length() > 0.0: loadable_cues += 1
	var planned: int = AudioEventCatalog.planned_cue_ids().size()
	check("audio_cues_all_registered_and_loadable", cue_ids.size() == AudioEventCatalog.EVENTS.size() + planned and loadable_cues == cue_ids.size(), "%d/%d (planned %d)" % [loadable_cues, cue_ids.size(), planned])
	var flipbooks := 0
	for id: StringName in VfxFlipbookCatalog.ids():
		if not VfxFlipbookCatalog.definition(id).is_empty() and VfxFlipbookCatalog.texture(id) != null: flipbooks += 1
	check("vfx_flipbooks_load", flipbooks == VfxFlipbookCatalog.ids().size() and flipbooks == 9, "%d/%d" % [flipbooks, VfxFlipbookCatalog.ids().size()])
	var bodies := 0
	var body_total := 0
	for path: String in expected.get("directional_bodies", []):
		if not path.ends_with("presentation.json"): continue
		body_total += 1
		if DirectionalAnimationSet.load_manifest(path).get("ok", false): bodies += 1
	check("directional_manifests_load", bodies == body_total and body_total > 0, "%d/%d" % [bodies, body_total])
	var species := 0
	for id: StringName in FOREST_SPECIES:
		if DirectionalAnimationSet.load_manifest(PilotVisual.manifest_path(Species.visual_id(id))).get("ok", false): species += 1
	check("forest_species_bodies_load", species == FOREST_SPECIES.size(), "%d/%d" % [species, FOREST_SPECIES.size()])
	var registry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map_authoring/release_packages.json"))
	var packages: Array = []
	for entry: Dictionary in registry.get("packages", []):
		var loaded: Dictionary = MapRelease.load_package(String(entry.package_id))
		packages.append({"package_id": entry.package_id, "ok": loaded.get("ok", false), "error": loaded.get("error_code", "")})
	check("map_packages_load", not packages.is_empty() and packages.all(func(row: Dictionary) -> bool: return row.ok), packages)
	var listing: Array[String] = []
	_walk("res://", listing)
	listing.sort()
	var file := FileAccess.open(folder.path_join("pack_listing.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(listing, "\t") + "\n"); file.close()
	var ok := checks.all(func(row: Dictionary) -> bool: return row.ok)
	var result := {"ok": ok, "count": checks.size(), "checks": checks, "groups": groups, "missing": missing, "pack_entries": listing.size(), "user_data_dir": OS.get_user_data_dir(), "editor_feature": OS.has_feature("editor"), "mode": "native_standard_engine_exact_release_pack"}
	print("E08_P7_INSPECT_RESULT ", JSON.stringify(result))
	quit(0 if ok else 1)

# --- forest ----------------------------------------------------------------------------------

func forest() -> void:
	root.size = Vector2i(1280, 720)
	var menu: CharacterMenu = load("res://scenes/character_menu.tscn").instantiate()
	root.add_child(menu); current_scene = menu
	menu.name_input.text = "Prova do candidato"
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
	panel.seed_input.text = "42"
	panel.phase_choice.select(index); panel.phase_choice.item_selected.emit(index)
	var started := Time.get_ticks_usec()
	var entered: Dictionary = await panel.start()
	timings["entry_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	check("forest_enters_from_exported_pack", entered.get("ok", false), entered.get("error_code", ""))
	if not entered.get("ok", false): finish(); return
	var host: RunController = entered["root"]
	await frames(12)
	host.change_interface_preferences(1.2, false)
	host._update_hud()
	await frames(3)
	var stage_panel := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	stage_panel.fit_available_space()
	await frames(3)
	check("ui120_panel_clears_footer_bar", is_equal_approx(host.ui_root.scale.x, 1.2) and not rect(stage_panel).intersects(rect(host.bottom_controls)) and not rect(stage_panel).intersects(rect(host.battle_controls.skill_bar)))
	var seen := species_bodies(host)
	check("forest_species_v2_bodies", seen.wolf_boar_v2 and seen.bad.is_empty(), seen)
	var bridge := host.presentation_events()
	var layer: Node = bridge.get_node_or_null("E08PilotFeedback") if bridge != null else null
	check("p6_feedback_layer_installed", layer != null and layer.get_script() != null and String(layer.get_script().resource_path).ends_with("feedback_vfx_layer.gd"), layer.get_script().resource_path if layer != null else "")
	var audio := host.presentation_audio()
	var general_bus: int = AudioServer.get_bus_index(audio._buses[&"general"])
	check("private_sum_native_limiter", general_bus > 0 and AudioServer.get_bus_effect_count(general_bus) == 1 and AudioServer.get_bus_effect(general_bus, 0) is AudioEffectHardLimiter)
	check("forest_ambience_bed_and_layer", audio.stage_biome() == "forest" and host.expedition_view.get_node_or_null("ForestAmbience") != null, audio.stage_biome())
	host._update_stage_minimap(0.1)
	var minimap := host.stage_minimap
	check("canonical_terrain_mesh_installed", minimap._background.terrain_mesh != null and minimap._background.terrain_mesh.surface_get_array_len(0) > 1000)
	var live := 0
	var outside_camera := false
	for enemy: CombatActor in host.enemies:
		if is_instance_valid(enemy) and enemy.is_alive():
			live += 1
			outside_camera = outside_camera or not root.get_visible_rect().has_point(host.get_canvas_transform() * enemy.global_position)
	timings["population"] = live
	check("whole_forest_population_marked", live > 0 and minimap._markers.enemies.size() == live, [live, minimap._markers.enemies.size()])
	check("offscreen_enemies_marked", outside_camera)
	var panel_rect: Rect2 = minimap.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, minimap.size)
	var class_rect: Rect2 = host.class_button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, host.class_button.size)
	check("map_clears_class_button", not panel_rect.intersects(class_rect), [panel_rect, class_rect])
	var bounds := minimap._background.bounds
	var hud_scale := host.ui_root.scale
	host.reset_camera_zoom(); host.change_camera_zoom(-3)
	await frames(4)
	check("zoom_out_without_changing_map_or_hud", host.route_camera.zoom.is_equal_approx(Vector2.ONE * 0.7) and minimap._background.bounds == bounds and host.ui_root.scale == hud_scale)
	await RenderingServer.frame_post_draw
	check("native_capture", root.get_texture().get_image().save_png(folder.path_join("candidate_forest_zoom.png")) == OK)
	var status := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	started = Time.get_ticks_usec()
	var suspended: Dictionary = await status.run_action({"kind": "suspend"})
	timings["suspend_ms"] = (Time.get_ticks_usec() - started) / 1000.0
	check("forest_suspends", suspended.get("ok", false), suspended.get("error_code", ""))
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
		paused = true
		await frames(3)
		restored._update_stage_minimap(0.1)
		var again_seen := species_bodies(restored)
		check("species_bodies_survive_resume", again_seen.wolf_boar_v2 and again_seen.bad.is_empty(), again_seen)
		var active: Dictionary = restored.presentation_audio().diagnostics().active
		check("resume_current_ambient_no_transients", active.effects == 0 and active.interface == 0 and active.ambience == 1, active)
		check("minimap_rebuilt_from_resumed_world", restored.stage_minimap._markers.has_player and restored.stage_minimap._background.bounds == bounds and restored.stage_minimap._markers.enemies.size() == live)
	finish()

func rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

## Every forest species occurrence either draws its own valid V2 body or (only for species
## without an installed unit) keeps the generic body; wolf and boar must be V2.
func species_bodies(host: RunController) -> Dictionary:
	var counts := {}
	var bad: Array[String] = []
	var wolf_boar := {}
	for enemy: CombatActor in host.enemies:
		var occurrence: MobOccurrence = enemy.get("occurrence")
		if occurrence == null: continue
		var id: StringName = occurrence.mob_base_id
		if not Species.has(id): continue
		var owns := PilotVisual.owns_species_body(enemy.character_animation, id)
		counts[String(id)] = int(counts.get(String(id), 0)) + 1
		if FileAccess.file_exists(PilotVisual.manifest_path(Species.visual_id(id))) and not owns: bad.append(String(id))
		if id in [&"forest_wolf", &"forest_boar"] and owns: wolf_boar[String(id)] = true
	return {"counts": counts, "bad": bad, "wolf_boar_v2": wolf_boar.size() == 2}

func finish() -> void:
	var ok := checks.size() == 19 and checks.all(func(value: Dictionary) -> bool: return value["ok"])
	print("E08_P7_FOREST_RESULT ", JSON.stringify({"ok": ok, "count": checks.size(), "checks": checks, "timings": timings, "mode": "native_standard_engine_exact_release_pack"}))
	paused = false
	quit(0 if ok else 1)
