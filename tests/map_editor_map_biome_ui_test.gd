extends SceneTree
## Native GUI/AX comparison for forest biome metadata and the apply-all border action.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapContext = preload("res://scripts/map_authoring/context/piece_context.gd")
const BorderOperations = preload("res://scripts/map_authoring/composition/border_operations.gd")

const EXPECTED_COUNT := 13
const FOREST_PROFILE := "forest_rootbank_v1"
var checks: Array[Dictionary] = []
var gui_shell: Variant
var ax_shell: Variant
var gui_panel: Variant
var ax_panel: Variant
var gui_presentation: Variant
var ax_presentation: Variant
var evidence_dir := ""

func _initialize() -> void:
	run.call_deferred()

func check(id: String, ok: bool, detail: Dictionary = {}) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_MAP_BIOME_UI_CHECK "+id+" "+str(ok))
	if not ok and not detail.is_empty(): print("F9_MAP_BIOME_UI_DIAGNOSTIC "+id+" "+JSON.stringify(detail))

func frames(count: int = 2) -> void:
	for _index: int in count:
		await process_frame
		RenderingServer.force_draw(false)

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.gui_embed_subwindows = true
	root.size = Vector2i(1600,1000)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	evidence_dir = OS.get_environment("F9_EVIDENCE")
	if evidence_dir.is_empty(): evidence_dir = ProjectSettings.globalize_path("res://.godot/f9_map_biome/ui")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	Presentation.active_mode = "ux"
	gui_shell = Shell.new(); gui_shell.name = "GuiForestBiomeShell"; root.add_child(gui_shell)
	ax_shell = Shell.new(); ax_shell.name = "AxForestBiomeShell"; root.add_child(ax_shell)
	await frames(3)
	var gui_piece_presentation: Variant = gui_shell.get_node_or_null("AuthoringPresentation")
	var ax_piece_presentation: Variant = ax_shell.get_node_or_null("AuthoringPresentation")
	var gui_mode: Dictionary = gui_piece_presentation.set_mode("ax") if gui_piece_presentation != null else {"ok":false}
	var ax_mode: Dictionary = ax_piece_presentation.set_mode("ax") if ax_piece_presentation != null else {"ok":false}
	var gui_open: Dictionary = gui_piece_presentation.ax_invoke("piece/compose_map",{}) if gui_piece_presentation != null else {"ok":false}
	var ax_open: Dictionary = ax_piece_presentation.ax_invoke("piece/compose_map",{}) if ax_piece_presentation != null else {"ok":false}
	await frames(4)
	var gui_window: Window = gui_shell.composition_window
	var ax_window: Window = ax_shell.composition_window
	if gui_window != null: gui_window.position = Vector2i.ZERO; gui_window.size = root.size
	if ax_window != null: ax_window.position = Vector2i.ZERO; ax_window.size = root.size
	gui_panel = gui_window.get_child(0) if gui_window != null and gui_window.get_child_count() > 0 else null
	ax_panel = ax_window.get_child(0) if ax_window != null and ax_window.get_child_count() > 0 else null
	gui_presentation = gui_panel.get_node_or_null("AuthoringPresentation") if gui_panel != null else null
	ax_presentation = ax_panel.get_node_or_null("AuthoringPresentation") if ax_panel != null else null
	var gui_map_mode: Dictionary = gui_presentation.set_mode("ux") if gui_presentation != null else {"ok":false}
	check("two_real_shells_open_independent_composition_sessions_and_screen_specific_presentations",gui_mode.ok and ax_mode.ok and gui_open.ok and ax_open.ok and gui_window != null and gui_window.visible and ax_window != null and ax_window.visible and gui_panel.session != null and ax_panel.session != null and gui_map_mode.ok and gui_presentation.ax_snapshot().screen == "map" and ax_presentation.ax_snapshot().screen == "map")
	var fixture: Dictionary = MapDocument.sample()
	var gui_load: Dictionary = gui_panel.session.replace(fixture)
	var ax_load: Dictionary = ax_panel.session.replace(fixture)
	gui_panel.session.saved_hash = MapDocument.hash_source(gui_panel.session.data)
	ax_panel.session.saved_hash = MapDocument.hash_source(ax_panel.session.data)
	var context_params: Dictionary = {"biome_id":"forest","instance_id":"","rules":[],"reason":""}
	var gui_context: Dictionary = gui_panel.apply_operation("context/set",context_params)
	var ax_map_mode: Dictionary = ax_presentation.set_mode("ax") if ax_presentation != null else {"ok":false}
	var ax_context: Dictionary = ax_presentation.ax_invoke("map/context/set",context_params)
	var forest_source_hash: String = MapDocument.hash_source(gui_panel.session.data)
	check("gui_and_ax_set_explicit_forest_context_with_equal_map_source_hashes",gui_load.ok and ax_load.ok and gui_context.ok and ax_map_mode.ok and ax_context.ok and forest_source_hash == MapDocument.hash_source(ax_panel.session.data) and gui_panel.session.data.context.biome_id == "forest" and ax_panel.session.data.context.biome_id == "forest")
	var advertised: Array[String] = []
	for command: Dictionary in ax_presentation.ax_snapshot().commands: advertised.append(str(command.id))
	var border_choice_index: int = -1
	for index: int in gui_panel.border_choice.item_count:
		if gui_panel.border_choice.get_item_metadata(index) == FOREST_PROFILE: border_choice_index = index
	var apply_all_button: Button = find_button(gui_panel,"Aplicar borda a todas as peças")
	check("forest_profile_and_gui_apply_all_control_exist_and_ax_batch_is_advertised",border_choice_index >= 0 and apply_all_button != null and "map/borders/apply_batch" in advertised)
	if border_choice_index >= 0: gui_panel.border_choice.select(border_choice_index)
	var gui_ux_mode: Dictionary = gui_presentation.set_mode("ux") if gui_presentation != null else {"ok":false}
	var gui_batch_base: String = MapDocument.hash_source(gui_panel.session.data)
	var gui_batch_command_count: int = gui_panel.session._undo.size()
	if apply_all_button != null: apply_all_button.pressed.emit()
	var commands: Array[Dictionary] = []
	for instance: Dictionary in ax_panel.session.data.instances:
		commands.append({"operation":"set_instance_profile","instance_id":instance.instance_id,"profile_id":FOREST_PROFILE})
	var ax_batch_base: String = MapDocument.hash_source(ax_panel.session.data)
	var ax_operation_mode: Dictionary = ax_presentation.set_mode("ax") if ax_presentation != null else {"ok":false}
	var ax_profile_index: int = -1
	for index: int in ax_panel.border_choice.item_count:
		if ax_panel.border_choice.get_item_metadata(index) == FOREST_PROFILE: ax_profile_index = index
	if ax_profile_index >= 0: ax_panel.border_choice.select(ax_profile_index)
	var ax_batch: Dictionary = ax_presentation.ax_invoke("map/borders/apply_batch",{"expected_source_hash":ax_batch_base,"commands":commands})
	check("gui_apply_all_and_ax_batch_apply_one_profile_per_instance_as_one_session_action",gui_ux_mode.ok and apply_all_button != null and gui_panel.session._undo.size() == gui_batch_command_count+1 and gui_panel.session.data.borders.instances.size() == 2 and gui_panel.session.data.borders.instances.all(func(entry: Dictionary) -> bool: return entry.profile_id == FOREST_PROFILE) and ax_operation_mode.ok and ax_batch.ok and ax_batch.command_count == 2 and ax_panel.session._undo.size() == 2 and gui_panel.session.data == ax_panel.session.data and MapDocument.hash_source(gui_panel.session.data) != gui_batch_base)
	var expected_profile_ids: Array[String] = ["left","right"]
	var selected_profile_ids: Array[String] = []
	for entry: Dictionary in gui_panel.session.data.borders.instances: selected_profile_ids.append(entry.instance_id)
	selected_profile_ids.sort()
	check("apply_all_respects_each_existing_instance_identity_without_changing_link_graph",selected_profile_ids == expected_profile_ids and gui_panel.session.data.links == fixture.links and gui_panel.session.data.pieces == fixture.pieces and ax_batch.output_hash == MapDocument.hash_source(ax_panel.session.data))
	var apply_all_action_depth: int = ax_panel.session._undo.size()
	var apply_all_action_hash: String = MapDocument.hash_source(ax_panel.session.data)
	var apply_all_action: Dictionary = ax_presentation.ax_invoke("map/apply_all_border_profiles",{})
	check("ax_apply_all_button_action_uses_the_same_batch_producer_without_duplicate_history",ax_profile_index >= 0 and apply_all_action.ok and ax_panel.session._undo.size() == apply_all_action_depth and MapDocument.hash_source(ax_panel.session.data) == apply_all_action_hash)
	var single_base: String = MapDocument.hash_source(ax_panel.session.data)
	var single_depth: int = ax_panel.session._undo.size()
	var single_command: Dictionary = ax_presentation.ax_invoke("map/borders/apply",{"expected_source_hash":single_base,"command":{"operation":"set_decorations","enabled":true}})
	check("single_command_border_contract_remains_available_and_no_op_adds_no_history",single_command.ok and ax_panel.session._undo.size() == single_depth and MapDocument.hash_source(ax_panel.session.data) == single_base)
	var invalid_before: String = MapDocument.hash_source(ax_panel.session.data)
	var invalid_depth: int = ax_panel.session._undo.size()
	var bad_batch: Dictionary = ax_presentation.ax_invoke("map/borders/apply_batch",{"expected_source_hash":invalid_before,"commands":[{"operation":"set_decorations","enabled":false},{"operation":"unsupported"}]})
	var stale_batch: Dictionary = ax_presentation.ax_invoke("map/borders/apply_batch",{"expected_source_hash":"stale".sha256_text(),"commands":[{"operation":"set_decorations","enabled":false}]})
	check("invalid_last_and_stale_batches_preserve_authored_border_state_and_history",not bad_batch.ok and not stale_batch.ok and stale_batch.code == "stale_source" and MapDocument.hash_source(ax_panel.session.data) == invalid_before and ax_panel.session._undo.size() == invalid_depth)

	var inspector_scroll: ScrollContainer = gui_panel.inspector_scroll
	var border_footer: Button = apply_all_button
	if inspector_scroll != null and border_footer != null: inspector_scroll.ensure_control_visible(border_footer)
	await frames(4)
	var inspector_rect: Rect2 = inspector_scroll.get_global_rect() if inspector_scroll != null else Rect2()
	var footer_rect: Rect2 = border_footer.get_global_rect() if border_footer != null else Rect2()
	var footer_reachable: bool = inspector_scroll != null and border_footer != null and inspector_rect.encloses(footer_rect) and border_footer.is_visible_in_tree()
	check("native_inspector_scroll_reaches_the_apply_all_border_footer",inspector_scroll != null and border_footer != null and footer_reachable)
	var gui_compile: Dictionary = gui_panel.start_compile()
	var ax_compile: Dictionary = ax_presentation.ax_invoke("map/compile_map",{})
	var wait_frames: int = 0
	while (gui_panel.job != null or ax_panel.job != null) and wait_frames < 3000:
		await process_frame
		RenderingServer.force_draw(false)
		wait_frames += 1
	var gui_package_result: Dictionary = gui_panel.result.duplicate(true)
	var ax_package_result: Dictionary = ax_panel.result.duplicate(true)
	await frames(3)
	check("gui_and_ax_compilers_finish_and_write_forest_to_the_runtime_stage",gui_compile.ok and ax_compile.ok and wait_frames < 3000 and gui_panel.job == null and ax_panel.job == null and gui_package_result.get("ok",false) and ax_package_result.get("ok",false) and gui_package_result.package.manifest.stages[0].biome == "forest" and ax_package_result.package.manifest.stages[0].biome == "forest" and gui_package_result.package.source_hash == MapDocument.hash_source(gui_panel.session.data) and ax_package_result.package.source_hash == MapDocument.hash_source(ax_panel.session.data))
	var forest_spans: Array = gui_package_result.package.border_spans.filter(func(span: Dictionary) -> bool: return span.profile_id == FOREST_PROFILE)
	check("compiled_runtime_package_keeps_the_selected_forest_border_and_identical_gui_ax_package_hash",forest_spans.size() > 0 and gui_package_result.package.package_hash == ax_package_result.package.package_hash and gui_package_result.package.authoring_context.biome_id == "forest" and gui_panel.canvas.package.package_hash == gui_package_result.package.package_hash and ax_panel.canvas.package.package_hash == ax_package_result.package.package_hash)

	ax_window.hide()
	var capture_mode: Dictionary = gui_presentation.set_mode("ux") if gui_presentation != null else {"ok":false}
	var canvas: Control = gui_panel.canvas
	canvas.custom_minimum_size.y = 440.0
	await frames(4)
	var canvas_scroll: ScrollContainer = find_scroll_ancestor(canvas)
	if canvas_scroll != null: canvas_scroll.ensure_control_visible(canvas)
	if inspector_scroll != null and border_footer != null: inspector_scroll.ensure_control_visible(border_footer)
	await frames(3)
	canvas.fit()
	await frames(3)
	var image: Image = root.get_texture().get_image()
	var save_result: Error = image.save_png(evidence_dir.path_join("forest_border_batch_native.png")) if image != null else FAILED
	var image_size: Vector2i = image.get_size() if image != null else Vector2i.ZERO
	var window_size: Vector2i = DisplayServer.window_get_size()
	var colors: int = sample_colors(image,canvas.get_global_rect()) if image != null and root.gui_embed_subwindows else (sample_colors(image,Rect2(Vector2.ZERO,canvas.size)) if image != null else 0)
	var meshes: int = canvas._meshes.get_child_count() if canvas._meshes != null else 0
	var capture: Dictionary = {"saved":save_result == OK,"image_size":image_size,"physical_window":window_size,"matching_dimensions":image_size == window_size,"canvas_size":canvas.size,"canvas_visible":canvas.is_visible_in_tree(),"mesh_count":meshes,"forest_spans":forest_spans.size(),"colors":colors,"visible_auxiliary":has_visible_auxiliary_windows(gui_panel),"source_hash":MapDocument.hash_source(gui_panel.session.data),"package_hash":gui_package_result.package.package_hash}
	print("F9_MAP_BIOME_UI_CAPTURE "+JSON.stringify(capture))
	check("native_capture_contains_compiled_forest_borders_and_matches_the_real_window",capture_mode.ok and save_result == OK and image != null and image_size == window_size and image_size.x >= 1280 and image_size.y >= 720 and canvas.size.x >= 600.0 and canvas.size.y >= 400.0 and canvas.is_visible_in_tree() and meshes > 0 and colors >= 4 and forest_spans.size() > 0 and not has_visible_auxiliary_windows(gui_panel))
	var final_gui_source: Dictionary = gui_presentation.ax_snapshot().source
	var final_ax_source: Dictionary = ax_presentation.ax_snapshot().source
	check("final_gui_ax_snapshots_and_rendered_maps_keep_equal_forest_authorship",MapDocument.hash_source(final_gui_source) == MapDocument.hash_source(final_ax_source) and MapDocument.hash_source(final_gui_source) == MapDocument.hash_source(gui_panel.session.data) and gui_package_result.package.manifest.stages[0].biome == "forest")
	Presentation.active_mode = "ux"
	finish()

func finish() -> void:
	Presentation.active_mode = "ux"
	var all_ok: bool = checks.size() == EXPECTED_COUNT and checks.all(func(item: Dictionary) -> bool: return item.ok)
	var source_hash: String = MapDocument.hash_source(gui_panel.session.data) if is_instance_valid(gui_panel) else ""
	print("F9_MAP_BIOME_UI_RESULT "+JSON.stringify({"ok":all_ok,"count":checks.size(),"expected_count":EXPECTED_COUNT,"checks":checks,"source_hash":source_hash,"evidence_dir":evidence_dir}))
	for shell: Variant in [gui_shell,ax_shell]:
		if is_instance_valid(shell): shell.free()
	quit(0 if all_ok else 1)

func find_button(parent: Node, caption: String) -> Button:
	if parent == null: return null
	for child: Node in parent.get_children():
		if child is Button and child.text == caption: return child as Button
		var nested: Button = find_button(child,caption)
		if nested != null: return nested
	return null

func find_scroll_ancestor(node: Node) -> ScrollContainer:
	var ancestor: Node = node.get_parent() if node != null else null
	while ancestor != null:
		if ancestor is ScrollContainer: return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null

func has_visible_auxiliary_windows(parent: Node) -> bool:
	if parent == null: return false
	for child: Node in parent.get_children():
		if child is Window and child.visible: return true
		if has_visible_auxiliary_windows(child): return true
	return false

func sample_colors(image: Image, rect: Rect2) -> int:
	if image == null or rect.size.x <= 0.0 or rect.size.y <= 0.0: return 0
	var colors: Dictionary = {}
	for yi: int in 8:
		for xi: int in 8:
			var x: int = clampi(roundi(rect.position.x+rect.size.x*float(xi)/7.0),0,image.get_width()-1)
			var y: int = clampi(roundi(rect.position.y+rect.size.y*float(yi)/7.0),0,image.get_height()-1)
			colors[image.get_pixel(x,y).to_html(false)] = true
	return colors.size()
