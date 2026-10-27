@tool
extends EditorPlugin
const Tools = preload("res://scripts/map_authoring/preview/viewport_tools.gd")
const Fixture = preload("res://tests/map_editor_viewport_test.gd")
const Borders = preload("res://tests/map_editor_borders_test.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapCanvasClass = preload("res://scripts/map_authoring/preview/map_canvas.gd")
const TerrainCanvasClass = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
const PatrolCanvasClass = preload("res://scripts/map_authoring/patrol/patrol_canvas.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PatrolFixture = preload("res://tests/map_editor_patrol_test.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func frames() -> void: await get_tree().process_frame; await get_tree().process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_VIEWPORT_UI_CHECK "+id+" "+str(ok))
func click(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true; event.position = at; return event
func capture(window: Window, id: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	check("capture_"+id,window.get_texture().get_image().save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
func run() -> void:
	await get_tree().create_timer(2).timeout
	var source := Fixture.source(); var recipe := Borders.map_source(source,"ruin_envelope_v1")
	var before := recipe.duplicate(true); var built := Compiler.compile(recipe)
	check("real_bridge_map_compiles",built.ok)
	if not built.ok: print(built); finish(); return
	var window := Window.new(); window.title = "Navegação de autoria F9 · fixture"; window.size = Vector2i(1200,860)
	EditorInterface.get_base_control().add_child(window); window.popup_centered(); await frames()
	var host := VBoxContainer.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(host)
	var canvas := MapCanvasClass.new(); host.add_child(canvas); await frames()
	var tools: Control = Tools.mount(canvas,"map"); canvas.set_package(built.package); await frames(); canvas.fit(); await frames()
	var world: WorldGeometry = canvas.geometry; var revision: int = world.geometry_revision; var package_hash: String = canvas.package.package_hash
	check("native_tools_and_minimap_visible",tools.mini.is_visible_in_tree() and tools.mini.size.x >= 160 and canvas.size.y >= 300)
	check("map_model_is_compiled_geometry",tools.model.compiled and tools.model.faces.size() >= world._stage.surfaces.size())
	var upper := Fixture.at(world,Vector3(50,40,150)); var lower := Fixture.at(world,Vector3(50,0,150))
	check("two_levels_preserved_in_model",upper != null and lower != null and upper.surface_id != lower.surface_id)
	# Native editor tests use the same real animated CombatActor as ShadowsNative.
	# RunState content resources execute in gameplay, not the editor placeholder context.
	var actor := CombatActor.new(); actor.set_animation_kind(&"mage"); canvas._meshes.add_child(actor)
	var binding := actor.bind_world_geometry(world,upper,built.package.profile,"viewport_actor")
	actor.position = Tools.ProjectionMath.project(upper.position); actor.set_process(false)
	var actor_before := actor.world_point().to_data()
	tools.focus_world(upper.position,1.5); await frames()
	check("focus_centers_actual_upper_support",binding.ok and canvas.screen(upper.position).distance_to(canvas.size*0.5) < 0.0001)
	check("focus_preserves_actor_source_and_physics",actor.world_point().to_data() == actor_before and recipe == before and world.geometry_revision == revision and canvas.package.package_hash == package_hash)
	var footprint: Array = tools.camera_footprint(); var footprint_ok := footprint.size() == 4
	var corners := [Vector2.ZERO,Vector2(canvas.size.x,0),canvas.size,Vector2(0,canvas.size.y)]
	for index: int in footprint.size(): footprint_ok = footprint_ok and absf(footprint[index].y-40) < 0.0001 and canvas.screen(footprint[index]).distance_to(corners[index]) < 0.001
	check("camera_footprint_matches_projection_at_named_height",footprint_ok)
	var mini_at: Vector2 = tools.minimap_point(Vector3(100,40,100)); tools._minimap_input(click(mini_at)); await frames()
	check("minimap_click_moves_camera_to_xz_at_focus_height",canvas.screen(Vector3(100,40,100)).distance_to(canvas.size*0.5) < 0.001)
	check("minimap_never_teleports_actor",actor.world_point().to_data() == actor_before)
	var cursor := Vector2(230,180); var state: Dictionary = canvas.camera_state(); var projected := (cursor-Vector2(state.offset))/float(state.scale)
	var wheel := click(cursor); wheel.button_index = MOUSE_BUTTON_WHEEL_UP; canvas._gui_input(wheel)
	check("zoom_preserves_point_under_cursor",(projected*canvas._scale+canvas._origin).distance_to(cursor) < 0.001)
	state = canvas.camera_state(); var pan := InputEventMouseMotion.new(); pan.button_mask = MOUSE_BUTTON_MASK_MIDDLE; pan.relative = Vector2(17,-9); canvas._gui_input(pan)
	check("middle_button_pans_exactly",canvas._origin == Vector2(state.offset)+Vector2(17,-9))
	var key := InputEventKey.new(); key.pressed = true; key.keycode = KEY_F
	tools._query.grab_focus(); state = canvas.camera_state()
	check("fit_shortcut_ignores_text_focus",not Tools.camera_input(canvas,key) and canvas.camera_state() == state)
	canvas.grab_focus(); check("fit_shortcut_runs_only_on_canvas",Tools.camera_input(canvas,key)); await frames()
	var presentation: Control = Presentation.mount(host,"map",func() -> Dictionary: return recipe,canvas); await frames()
	presentation.set_mode("ux"); check("ax_requires_authoring_mode",presentation.ax_invoke("map/viewport/inspect").code == "ax_mode_required")
	presentation.set_mode("ax")
	check("eight_viewport_commands_in_presentation",presentation.ax_snapshot().commands.size() == 8 and presentation.ax_invoke("map/viewport/inspect").ok)
	var focused: Dictionary = presentation.ax_invoke("map/viewport/focus_entity",{"entity_id":"surface/"+upper.surface_id})
	check("ax_and_gui_focus_share_camera_authority",focused.ok and canvas.screen(Tools.bounds(world._cell(upper.surface_id).vertices).get_center()).distance_to(canvas.size*0.5) < 0.001)
	state = canvas.camera_state(); var bad: Dictionary = presentation.ax_invoke("map/viewport/focus_world",{"position_xyz":[1,2,3],"unexpected":1})
	check("invalid_ax_arguments_do_not_move_camera",not bad.ok and state == canvas.camera_state() and recipe == before)
	bad = presentation.ax_invoke("map/viewport/focus_world",{"position_xyz":[3.0e38,0,-3.0e38],"zoom":8})
	check("projection_overflow_is_rejected_without_camera_change",not bad.ok and state == canvas.camera_state())
	var menu: PopupMenu = tools._overlay_menu.get_popup(); menu.id_pressed.emit(0)
	check("gui_overlay_and_ax_snapshot_agree",presentation.ax_invoke("map/viewport/inspect").overlays.height and menu.is_item_checked(0))
	check("missing_focus_target_is_explicit",tools.focus_entity("missing").code == "focus_target_missing")
	var profile_result: Dictionary = presentation.ax_invoke("map/viewport/set_probe",{"mode":"clearance","radius":2.1257,"height":12.3456}); await frames()
	check("exact_probe_dimensions_and_visible_decimals",profile_result.ok and tools.profile().radius == 2.1257 and tools.profile().height == 12.3456 and tools._radius.get_line_edit().text.to_float() == 2.1257 and tools._height.get_line_edit().text.to_float() == 12.3456)
	tools.ax_command("map/viewport/set_probe",{"mode":"clearance","radius":2,"height":12})
	check("lower_body_fits_below_bridge",tools.probe_point(lower.to_data()).ok)
	tools.ax_command("map/viewport/set_probe",{"mode":"clearance","radius":2,"height":40})
	check("large_body_fails_real_bridge_headroom",not tools.probe_point(lower.to_data()).ok)
	tools.ax_command("map/viewport/set_probe",{"mode":"clearance","radius":2,"height":12})
	var false_point := lower.to_data(); false_point.position.y = 10
	check("false_support_height_rejected",not tools.probe_point(false_point).ok)
	world.set_occupant("probe_occupant",lower,tools.profile(),world.geometry_revision)
	var occupied: Dictionary = tools.probe_point(lower.to_data()); tools._show(occupied)
	check("occupancy_is_reported_without_calling_it_free",occupied.ok and occupied.data.occupants == ["probe_occupant"] and tools._notice.text.contains("ocupado"))
	world.remove_occupant("probe_occupant")
	var start := Fixture.at(world,Vector3(20,0,20)); var end := Fixture.at(world,Vector3(80,0,20))
	var ray: Dictionary = tools.probe_los(start.to_data(),end.to_data())
	check("real_los_clear_without_obstacle",ray.ok and not ray.data.hit)
	var inserted := world.insert_obstacle("probe_wall",AABB(Vector3(45,0,10),Vector3(10,24,20)),world.geometry_revision)
	ray = tools.probe_los(start.to_data(),end.to_data())
	check("real_los_hits_named_volume_at_exact_entry",inserted.ok and ray.ok and ray.data.hit and ray.data.volume_id == "temporary/probe_wall" and absf(ray.data.position.x-45) < 0.0001)
	check("overlay_cache_tracks_world_revision_and_actual_blocker",tools.model.volumes.has(AABB(Vector3(45,0,10),Vector3(10,24,20))))
	world.remove_obstacle("probe_wall",world.geometry_revision); ray = tools.probe_los(start.to_data(),end.to_data())
	check("removing_obstacle_restores_los",ray.ok and not ray.data.hit)
	tools.ax_command("map/viewport/set_probe",{"mode":"clearance","radius":2,"height":12})
	var default_pick: Dictionary = canvas.inspection_pick(canvas.screen(lower.position))
	print("F9_VIEWPORT_DEFAULT_PICK "+str(default_pick))
	check("ordinary_click_preserves_real_occlusion",not default_pick.ok and default_pick.error_code == &"occluded_surface")
	for index: int in tools._surface.item_count:
		if tools._surface.get_item_metadata(index) == lower.surface_id: tools._surface.select(index); tools._surface.item_selected.emit(index); break
	canvas._gui_input(click(canvas.screen(lower.position)))
	print("F9_VIEWPORT_EXPLICIT_PICK "+str(tools.last_probe))
	check("gui_inspection_uses_canonical_query_without_moving_actor",not tools.last_probe.is_empty() and tools.last_probe.kind == "clearance" and tools.last_probe.result.ok and tools.last_probe.result.data.point.surface_id == lower.surface_id and tools.last_probe.result.data.point.position.distance_to(lower.position) < 0.001 and actor.world_point().to_data() == actor_before)
	var chosen: Dictionary = presentation.ax_invoke("map/viewport/set_probe",{"mode":"clearance","radius":2,"height":40,"surface_id":lower.surface_id})
	canvas._gui_input(click(canvas.screen(lower.position)))
	check("explicit_support_keeps_real_bridge_collision",chosen.ok and not tools.last_probe.result.ok and canvas.inspection_surface == lower.surface_id)
	var cached_model: Dictionary = tools.model
	for index: int in 20: tools.focus_world(Vector3(100+index,40,150))
	await frames()
	check("camera_only_changes_reuse_static_model",is_same(cached_model,tools.model) and world.geometry_revision == revision+2 and recipe == before)
	presentation.set_mode("ux"); tools.set_overlays({"height":false,"support":true,"blocking":true}); await capture(window,"viewport_map")
	actor.world_motion.release(); host.queue_free(); await frames()
	await terrain_case(window,source)
	await patrol_case(window)
	window.queue_free(); await frames()
	await objects_case(source)
	finish()

func objects_case(source: Dictionary) -> void:
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	if shell == null: check("objects_prepare_inspection_uses_shared_compiler",false); return
	shell.session.replace(source); await frames(); shell.open_objects(); await frames()
	var panel: Control = shell.objects_window.get_child(0); var before: String = shell.session.document().semantic_hash(); var undo: bool = shell.session.can_undo()
	var enabled: bool = not panel.prepare_button.disabled; panel.prepare_button.pressed.emit()
	var deadline := Time.get_ticks_msec()+45000
	while shell.terrain.job != null and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	await frames()
	var ready: bool = shell.terrain.result.get("ok",false) and not panel.canvas.package.is_empty()
	check("objects_prepare_inspection_uses_shared_compiler",enabled and ready and panel.canvas.package == shell.terrain.canvas.package)
	var physical_ok := false
	if ready:
		var world: WorldGeometry = panel.canvas.inspection_world(); var point := Fixture.at(world,Vector3(50,0,150))
		physical_ok = world.position_query(point,panel.canvas.package.profile,world.geometry_revision).ok and not world.position_query(point,{"radius":2,"height":40,"connector_kinds":["walk"]},world.geometry_revision).ok
	check("objects_shared_inspection_preserves_source_history_and_real_bridge",physical_ok and shell.session.document().semantic_hash() == before and shell.session.can_undo() == undo)
	await capture(shell.objects_window,"viewport_objects"); shell.objects_window.hide()

func terrain_case(window: Window, source: Dictionary) -> void:
	var host := VBoxContainer.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(host)
	var canvas := TerrainCanvasClass.new(); host.add_child(canvas); await frames()
	var tools: Control = Tools.mount(canvas,"terrain"); canvas.set_source(source,"plateau"); canvas.fit(); await frames()
	check("terrain_has_shared_native_navigation",tools.mini.visible and tools.screen_id == "terrain" and not tools.model.compiled)
	check("draft_refuses_physics_inspection",tools.probe_point({"surface_id":"bridge","position_xyz":[50,40,150]}).code == "compile_required")
	var built := Fixture.Terrain.compile(source); canvas.package = built.package; await frames()
	var world: WorldGeometry = canvas.inspection_world(); var upper := Fixture.at(world,Vector3(50,40,150)); var lower := Fixture.at(world,Vector3(50,0,150))
	var hit: Dictionary = canvas.inspection_pick(canvas.screen(upper.position))
	check("terrain_pick_uses_real_upper_support",hit.ok and hit.data.point.surface_id == upper.surface_id and hit.data.point.position.distance_to(upper.position) < 0.0001)
	canvas.hidden_layers.append("plateau"); canvas.redraw_terrain(); await frames()
	tools.ax_command("terrain/viewport/set_probe",{"mode":"clearance","radius":2,"height":40})
	check("hidden_bridge_unpickable_but_still_blocks_large_body",not canvas.inspection_pick(canvas.screen(upper.position)).ok and not tools.probe_point(lower.to_data()).ok)
	canvas.hidden_layers.clear(); canvas.redraw_terrain(); await frames()
	tools.set_overlays({"height":true,"blocking":true}); check("terrain_overlays_reflect_same_flags",tools.overlays.height and tools.overlays.blocking)
	tools.ax_command("terrain/viewport/set_probe",{"mode":"clearance","radius":2,"height":12})
	var strokes: Array = []; canvas.stroke_finished.connect(func(_points: Array,_options: Dictionary) -> void: strokes.append(true))
	canvas._gui_input(click(canvas.screen(upper.position)))
	check("inspection_click_never_starts_brush_transaction",strokes.is_empty() and not canvas._dragging and tools.last_probe.result.ok)
	var initial := Fixture.Schema.semantic_hash(source); var camera: Dictionary = canvas.camera_state(); var cursor := Vector2(310,160); var projected := (cursor-Vector2(camera.offset))/float(camera.scale)
	var wheel := click(cursor); wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN; canvas._gui_input(wheel)
	check("terrain_zoom_is_camera_only",(projected*canvas._scale+canvas._origin+canvas._pan).distance_to(cursor) < 0.001 and Fixture.Schema.semantic_hash(canvas.source) == initial)
	var changed := source.duplicate(true); changed.name = "Fonte alterada"; canvas.set_source(changed,"plateau")
	check("source_edit_invalidates_compiled_inspection",canvas.inspection_world() == null and tools.probe_point(upper.to_data()).code == "compile_required")
	canvas.package = Fixture.Terrain.compile(changed).package; await frames(); canvas.fit(); await capture(window,"viewport_terrain")
	host.queue_free(); await frames()

func patrol_case(window: Window) -> void:
	var source := PatrolFixture.fixture(); var before := source.duplicate(true); var compiled := PatrolCompiler.compile(source)
	check("real_patrol_package_compiles",compiled.ok)
	if not compiled.ok: print(compiled); return
	var host := VBoxContainer.new(); host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(host)
	var canvas := PatrolCanvasClass.new(); host.add_child(canvas); await frames()
	var tools: Control = Tools.mount(canvas,"patrol"); canvas.set_encounters(compiled.package.population_package); canvas.source = source.population[0]; canvas.patrol_source = source; await frames(); canvas.fit()
	check("minimap_uses_real_slots_and_waypoints",tools.model.slots.size() == 1 and tools.model.routes.size() == 1 and tools.model.routes[0].points[0] == Vector3(240,0,200))
	var focused: Dictionary = tools.focus_entity("route/guard_route"); check("route_focus_uses_authored_bounds",focused.ok and canvas.screen(Vector3(270,0,200)).distance_to(canvas.size*0.5) < 0.001)
	tools.set_overlays({"population":false,"routes":false}); check("overlay_toggle_controls_existing_population_and_route_renderer",not canvas.show_population_overlay and not canvas.show_routes_overlay)
	check("focus_and_visibility_preserve_encounter_authorship",source == before and canvas.source == before.population[0] and canvas.patrol_source == before)
	tools.set_overlays({"population":true,"routes":true}); await capture(window,"viewport_patrol")
	host.queue_free(); await frames()

func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_VIEWPORT_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
