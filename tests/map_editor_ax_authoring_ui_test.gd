extends SceneTree
## Native-window proof that GUI and semantic AX share terrain producers and source hashes.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")

var checks: Array[Dictionary] = []
var gui_shell: Control
var ax_shell: Control
var gui_presentation: Variant
var ax_presentation: Variant
var evidence_dir := ""
const PIECE_CONTEXT_TITLE := "Contexto da peça · Biomas e encontros"
const PIECE_EXCHANGE_TITLE := "Intercâmbio · Revisar proposta"
const MAP_CONTEXT_TITLE := "Contexto do mapa · Exceções manuais"

func _initialize() -> void:
	run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("F9_AX_AUTHORING_UI_CHECK "+id+" "+str(ok))

func frames(count: int = 2) -> void:
	for _index: int in count:
		await process_frame
		RenderingServer.force_draw(false)

func run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1600,1000)
	DisplayServer.window_set_size(Vector2i(1600,1000))
	evidence_dir = OS.get_environment("F9_EVIDENCE")
	if evidence_dir.is_empty(): evidence_dir = ProjectSettings.globalize_path("res://.godot/f9_ax_authoring/ui")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	Presentation.active_mode = "ux"
	gui_shell = Shell.new(); gui_shell.name = "GuiAuthoringShell"; root.add_child(gui_shell)
	ax_shell = Shell.new(); ax_shell.name = "AxAuthoringShell"; root.add_child(ax_shell)
	await frames(3)
	gui_shell.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); gui_shell.position = Vector2(0,0); gui_shell.size = Vector2(790,960)
	ax_shell.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT); ax_shell.position = Vector2(800,0); ax_shell.size = Vector2(790,960)
	gui_presentation = gui_shell.get_node_or_null("AuthoringPresentation")
	ax_presentation = ax_shell.get_node_or_null("AuthoringPresentation")
	var gui_terrain_presentation: Variant = gui_shell.terrain.get_node_or_null("AuthoringPresentation") if gui_shell.terrain != null else null
	var ax_terrain_presentation: Variant = ax_shell.terrain.get_node_or_null("AuthoringPresentation") if ax_shell.terrain != null else null
	var gui_piece_context_window: Window = find_window(gui_shell,PIECE_CONTEXT_TITLE)
	var gui_piece_exchange_window: Window = find_window(gui_shell,PIECE_EXCHANGE_TITLE)
	var ax_piece_context_window: Window = find_window(ax_shell,PIECE_CONTEXT_TITLE)
	var ax_piece_exchange_window: Window = find_window(ax_shell,PIECE_EXCHANGE_TITLE)
	check("two_real_shells_mount_presentations_with_auxiliary_windows_initially_hidden",gui_presentation != null and ax_presentation != null and gui_terrain_presentation != null and ax_terrain_presentation != null and gui_piece_context_window != null and not gui_piece_context_window.visible and gui_piece_exchange_window != null and not gui_piece_exchange_window.visible and ax_piece_context_window != null and not ax_piece_context_window.visible and ax_piece_exchange_window != null and not ax_piece_exchange_window.visible)
	var gui_grid_button := find_button(gui_shell.terrain,"Nova grade")
	var create_menu: MenuButton = gui_terrain_presentation.menus.get("Criar") if gui_terrain_presentation != null else null
	var create_popup: PopupMenu = create_menu.get_popup() if create_menu != null else null
	var grid_action_id: String = str(gui_grid_button.get_meta("authoring_action_id","")) if gui_grid_button != null else ""
	var grid_menu_index := find_menu_action(create_popup,"Nova grade",grid_action_id)
	if gui_terrain_presentation != null:
		for index: int in gui_terrain_presentation.section_choice.item_count:
			if gui_terrain_presentation.section_choice.get_item_text(index) == "Nova grade": gui_terrain_presentation.section_choice.select(index)
		gui_terrain_presentation._apply_mode()
		gui_terrain_presentation._update_menu("Criar")
	check("gui_grid_control_has_enabled_native_menu_entry",gui_grid_button != null and not gui_grid_button.disabled and create_menu != null and create_menu.visible and grid_menu_index >= 0 and not create_popup.is_item_disabled(grid_menu_index))
	var base: Dictionary = TerrainPanel.sample_source(Document.empty("ax_gui_shared_piece"))
	var gui_replace: Dictionary = gui_shell.session.replace(base)
	var ax_replace: Dictionary = ax_shell.session.replace(base)
	gui_shell.session.saved_hash = gui_shell.session.document().semantic_hash()
	ax_shell.session.saved_hash = ax_shell.session.document().semantic_hash()
	gui_shell.terrain.select_layer("lower"); ax_shell.terrain.select_layer("lower")
	check("same_test_only_ramp_plateau_and_real_bridge_source_loaded",gui_replace.ok and ax_replace.ok and base.layers.size() == 3 and base.special_surfaces.size() == 1 and gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash())
	var compiled_gui: Dictionary = Compiler.compile(gui_shell.session.document().to_data())
	var compiled_ax: Dictionary = Compiler.compile(ax_shell.session.document().to_data())
	check("same_authored_ramp_bridge_fixture_compiles_headless_with_matching_package",compiled_gui.ok and compiled_ax.ok and compiled_gui.package.package_hash == compiled_ax.package.package_hash and compiled_gui.package.source_hash == gui_shell.session.document().semantic_hash())
	if not compiled_gui.ok or not compiled_ax.ok:
		print("F9_AX_AUTHORING_UI_COMPILE "+JSON.stringify({"gui":compiled_gui,"ax":compiled_ax}))
		finish(); return
	var far_grid_source: Dictionary = base.duplicate(true)
	var far_heights: Array[float] = []; far_heights.resize(25); far_heights.fill(0.0)
	far_grid_source.layers.append({"layer_id":"far_grid","name":"Grade distante","origin_xz":[5000.0,5000.0],"sample_spacing":32.0,"columns":5,"rows":5,"heights":far_heights,"material_masks":{},"locked":false,"protected_regions":[]})
	var far_grid_compile: Dictionary = Compiler.compile(far_grid_source)
	check("compiler_rejects_disconnected_far_grid_with_route_unreachable",not far_grid_compile.ok and far_grid_compile.code == "route_unreachable")
	var source_before_grid: String = gui_shell.session.document().semantic_hash()
	gui_shell.terrain.grid_x.value = 300.0; gui_shell.terrain.grid_z.value = 0.0; gui_shell.terrain.grid_y.value = 40.0
	gui_shell.terrain.add_grid("shared_ax_grid")
	var ax_mode: Dictionary = ax_presentation.set_mode("ax") if ax_presentation != null else {"ok":false}
	var ax_grid: Dictionary = ax_terrain_presentation.ax_invoke("terrain/grid/create",{"layer_id":"shared_ax_grid","name":"Camada 4","origin_xz":[300.0,0.0],"columns":5,"rows":5,"sample_spacing":32.0,"height":40.0}) if ax_terrain_presentation != null else {"ok":false}
	var gui_grid_hash: String = gui_shell.session.document().semantic_hash()
	check("gui_and_ax_grid_share_producer_and_explicit_identity",gui_grid_hash != source_before_grid and ax_mode.ok and ax_grid.ok and gui_grid_hash == ax_shell.session.document().semantic_hash() and ax_grid.entity_id == "shared_ax_grid")
	var piece_hash_before_aux: String = ax_shell.session.document().semantic_hash()
	var opened_piece_context: Dictionary = ax_presentation.ax_invoke("piece/piece_context",{}) if ax_presentation != null else {"ok":false}
	await frames(2)
	var piece_context_open: bool = ax_piece_context_window != null and ax_piece_context_window.visible
	var opened_piece_exchange: Dictionary = ax_presentation.ax_invoke("piece/exchange",{}) if ax_presentation != null else {"ok":false}
	await frames(2)
	var piece_exchange_open: bool = ax_piece_exchange_window != null and ax_piece_exchange_window.visible
	if ax_piece_context_window != null: ax_piece_context_window.close_requested.emit()
	if ax_piece_exchange_window != null: ax_piece_exchange_window.close_requested.emit()
	await frames(2)
	check("piece_context_and_exchange_ax_windows_open_close_without_source_changes",opened_piece_context.ok and piece_context_open and opened_piece_exchange.ok and piece_exchange_open and not ax_piece_context_window.visible and not ax_piece_exchange_window.visible and ax_shell.session.document().semantic_hash() == piece_hash_before_aux)
	var ax_compiled_grid: Dictionary = Compiler.compile(ax_shell.session.document().to_data())
	var gui_compiled_grid: Dictionary = Compiler.compile(gui_shell.session.document().to_data())
	check("identical_gui_ax_grid_inputs_have_identical_headless_compilation",ax_compiled_grid.ok and gui_compiled_grid.ok and ax_compiled_grid.package.package_hash == gui_compiled_grid.package.package_hash and ax_compiled_grid.package.source_hash == gui_grid_hash)
	gui_shell.terrain.bridge_x.value = 300.0; gui_shell.terrain.bridge_z.value = 128.0
	gui_shell.terrain.bridge_width.value = 128.0; gui_shell.terrain.bridge_length.value = 72.0; gui_shell.terrain.bridge_height.value = 40.0
	gui_shell.terrain.add_bridge("shared_ax_bridge")
	var ax_bridge: Dictionary = ax_terrain_presentation.ax_invoke("terrain/bridge/create",{"surface_id":"shared_ax_bridge","layer_id":"shared_ax_grid","origin_xz":[300.0,128.0],"width":128.0,"length":72.0,"height":40.0})
	check("gui_and_ax_bridge_use_same_semantic_operation",ax_bridge.ok and ax_bridge.entity_id == "shared_ax_bridge" and gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash())
	var gate := {"connector_id":"shared_ax_gate","surface_id":"shared_ax_grid","position_xyz":[428.0,40.0,64.0],"kind":"walk","normal_xyz":[1,0,0],"width":32.0,"headroom":100.0,"tags":["map_editor"],"direction":"both"}
	gui_shell.terrain.connector_id.text = "shared_ax_gate"
	gui_shell.terrain.connector_x.value = 428.0; gui_shell.terrain.connector_y.value = 40.0; gui_shell.terrain.connector_z.value = 64.0
	gui_shell.terrain.connector_width.value = 32.0; gui_shell.terrain.connector_headroom.value = 100.0
	gui_shell.terrain.connector_side.select(1); gui_shell.terrain.connector_direction.select(0); gui_shell.terrain.connector_tags.text = "map_editor"
	var gui_connector_surface := find_surface_index(gui_shell.terrain,"shared_ax_grid")
	if gui_connector_surface >= 0: gui_shell.terrain.connector_surface.select(gui_connector_surface)
	gui_shell.terrain.save_connector()
	var ax_connector: Dictionary = ax_terrain_presentation.ax_invoke("terrain/connector/upsert",gate)
	check("gui_and_ax_connector_share_full_canonical_parameters",gui_connector_surface >= 0 and ax_connector.ok and gui_shell.session.document().to_data().connectors.size() == 1 and gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash())
	check("shared_authoring_hash_matches_across_complete_gui_and_ax_sources",gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash() and gui_shell.session.document().to_data() == ax_shell.session.document().to_data())
	var full_gui_compile: Dictionary = Compiler.compile(gui_shell.session.document().to_data())
	var full_ax_compile: Dictionary = Compiler.compile(ax_shell.session.document().to_data())
	check("completed_grid_bridge_connector_compiles_identically_in_gui_and_ax",full_gui_compile.ok and full_ax_compile.ok and full_gui_compile.package.package_hash == full_ax_compile.package.package_hash and full_gui_compile.package.source_hash == gui_shell.session.document().semantic_hash() and full_ax_compile.package.source_hash == ax_shell.session.document().semantic_hash())
	if not full_gui_compile.ok or not full_ax_compile.ok:
		print("F9_AX_AUTHORING_UI_FULL_COMPILE "+JSON.stringify({"gui":full_gui_compile,"ax":full_ax_compile}))
	var piece_hash_before_composition: String = ax_shell.session.document().semantic_hash()
	var composed: Dictionary = ax_presentation.ax_invoke("piece/compose_map",{}) if ax_presentation != null else {"ok":false}
	await frames(3)
	var composition_window: Window = ax_shell.composition_window
	var map_panel: Control = composition_window.get_child(0) as Control if composition_window != null and composition_window.get_child_count() > 0 else null
	var map_presentation: Variant = map_panel.get_node_or_null("AuthoringPresentation") if map_panel != null else null
	var map_context_window: Window = find_window(map_panel,MAP_CONTEXT_TITLE) if map_panel != null else null
	var map_exchange_window: Window = find_window(map_panel,PIECE_EXCHANGE_TITLE) if map_panel != null else null
	var composition_hash_unchanged: bool = ax_shell.session.document().semantic_hash() == piece_hash_before_composition
	check("composition_ax_action_mounts_map_with_auxiliary_windows_closed_and_preserves_piece_hash",composed.ok and composition_window != null and composition_window.visible and map_panel != null and map_presentation != null and map_context_window != null and not map_context_window.visible and map_exchange_window != null and not map_exchange_window.visible and composition_hash_unchanged)
	var opened_map_context: Dictionary = map_presentation.ax_invoke("map/map_context",{}) if map_presentation != null else {"ok":false}
	await frames(2)
	var map_context_open: bool = map_context_window != null and map_context_window.visible
	if map_context_window != null: map_context_window.close_requested.emit()
	await frames(2)
	var map_context_closed: bool = map_context_window != null and not map_context_window.visible
	if composition_window != null: composition_window.close_requested.emit()
	await frames(2)
	check("map_context_ax_window_closes_with_map_and_preserves_piece_hash",opened_map_context.ok and map_context_open and map_context_closed and composition_window != null and not composition_window.visible and ax_shell.session.document().semantic_hash() == piece_hash_before_composition)
	await frames(3)
	gui_shell.hide()
	ax_shell.position = Vector2.ZERO; ax_shell.size = Vector2(1600,960)
	var canvas: Variant = ax_shell.terrain.canvas
	canvas.custom_minimum_size.y = 440.0
	await frames(3)
	var canvas_scroll: ScrollContainer = find_scroll_ancestor(canvas)
	if canvas_scroll != null: canvas_scroll.ensure_control_visible(canvas)
	await frames(2)
	canvas.fit()
	await frames(2)
	var image: Image = root.get_texture().get_image()
	var capture := image.save_png(evidence_dir.path_join("ax_gui_shared_authorship.png")) if image != null else FAILED
	var canvas_rect: Rect2 = canvas.get_global_rect() if is_instance_valid(canvas) else Rect2()
	var rendered_colors: int = sample_canvas_colors(image,canvas_rect) if image != null else 0
	var actual_size: Vector2i = DisplayServer.window_get_size()
	var visible_windows := has_visible_auxiliary_windows(ax_shell)
	var image_size: Vector2i = image.get_size() if image != null else Vector2i.ZERO
	var mesh_count: int = canvas._mesh_root.get_child_count() if is_instance_valid(canvas) else 0
	var canvas_visible: bool = canvas.is_visible_in_tree() if is_instance_valid(canvas) else false
	var capture_predicates := {"capture_written":capture == OK,"image_size":image_size,"window_size":actual_size,"image_matches_window":image_size == actual_size,"window_minimum":image_size.x >= 1280 and image_size.y >= 720,"visible_auxiliary_windows":visible_windows,"canvas_visible":canvas_visible,"canvas_size":canvas.size if is_instance_valid(canvas) else Vector2.ZERO,"canvas_minimum":is_instance_valid(canvas) and canvas.size.x >= 600.0 and canvas.size.y >= 400.0,"mesh_count":mesh_count,"rendered_colors":rendered_colors}
	print("F9_AX_AUTHORING_UI_CAPTURE "+JSON.stringify(capture_predicates))
	check("native_ax_capture_has_visible_terrain_and_real_window_dimensions",capture == OK and image != null and image_size == actual_size and image_size.x >= 1280 and image_size.y >= 720 and not visible_windows and canvas_visible and canvas.size.x >= 600.0 and canvas.size.y >= 400.0 and mesh_count > 0 and rendered_colors >= 4)
	Presentation.active_mode = "ux"
	finish()

func find_button(parent: Node, caption: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and child.text == caption: return child
		var nested := find_button(child,caption)
		if nested != null: return nested
	return null

func find_menu_action(popup: PopupMenu, caption: String, action_id: String) -> int:
	if popup == null: return -1
	for index: int in popup.item_count:
		if popup.get_item_text(index) == caption and popup.get_item_metadata(index) == action_id: return index
	return -1

func find_surface_index(panel: Control, surface_id: String) -> int:
	for index: int in panel.connector_surface.item_count:
		if panel.connector_surface.get_item_metadata(index) == surface_id: return index
	return -1

func compiled_grid_hash(result: Dictionary) -> String:
	return str(result.get("package",{}).get("package_hash",""))

func finish() -> void:
	Presentation.active_mode = "ux"
	var ok: bool = checks.size() == 15 and checks.all(func(item: Dictionary) -> bool: return item.ok)
	var source_hash: String = gui_shell.session.document().semantic_hash() if is_instance_valid(gui_shell) else ""
	if ax_shell != null and is_instance_valid(ax_shell): ax_shell.free()
	if gui_shell != null and is_instance_valid(gui_shell): gui_shell.free()
	print("F9_AX_AUTHORING_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"expected_count":15,"checks":checks,"source_hash":source_hash}))
	quit(0 if ok else 1)

func find_window(parent: Node, caption: String) -> Window:
	if parent == null: return null
	for child: Node in parent.get_children():
		if child is Window and child.title == caption: return child as Window
		var nested: Window = find_window(child,caption)
		if nested != null: return nested
	return null

func has_visible_auxiliary_windows(parent: Node) -> bool:
	if parent == null: return false
	for child: Node in parent.get_children():
		if child is Window and child.visible: return true
		if has_visible_auxiliary_windows(child): return true
	return false

func find_scroll_ancestor(node: Node) -> ScrollContainer:
	var ancestor: Node = node.get_parent() if node != null else null
	while ancestor != null:
		if ancestor is ScrollContainer: return ancestor as ScrollContainer
		ancestor = ancestor.get_parent()
	return null

func sample_canvas_colors(image: Image, rect: Rect2) -> int:
	if image == null or rect.size.x <= 0.0 or rect.size.y <= 0.0: return 0
	var left: int = clampi(floori(rect.position.x+rect.size.x*0.25),0,image.get_width()-1)
	var right: int = clampi(floori(rect.position.x+rect.size.x*0.75),0,image.get_width()-1)
	var top: int = clampi(floori(rect.position.y+rect.size.y*0.25),0,image.get_height()-1)
	var bottom: int = clampi(floori(rect.position.y+rect.size.y*0.75),0,image.get_height()-1)
	var colors: Dictionary = {}
	for yi: int in 9:
		for xi: int in 9:
			var x: int = roundi(lerpf(float(left),float(right),float(xi)/8.0))
			var y: int = roundi(lerpf(float(top),float(bottom),float(yi)/8.0))
			colors[image.get_pixel(x,y).to_html(false)] = true
	return colors.size()
