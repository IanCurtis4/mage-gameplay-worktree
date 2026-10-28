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
	check("two_real_shells_mount_gui_and_ax_terrain_panels",gui_presentation != null and ax_presentation != null and gui_terrain_presentation != null and ax_terrain_presentation != null)
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
	var base := TerrainPanel.sample_source(Document.empty("ax_gui_shared_piece"))
	var gui_replace := gui_shell.session.replace(base)
	var ax_replace := ax_shell.session.replace(base)
	gui_shell.session.saved_hash = gui_shell.session.document().semantic_hash()
	ax_shell.session.saved_hash = ax_shell.session.document().semantic_hash()
	gui_shell.terrain.select_layer("lower"); ax_shell.terrain.select_layer("lower")
	check("same_test_only_ramp_plateau_and_real_bridge_source_loaded",gui_replace.ok and ax_replace.ok and base.layers.size() == 3 and base.special_surfaces.size() == 1 and gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash())
	var compiled_gui := Compiler.compile(gui_shell.session.document().to_data())
	var compiled_ax := Compiler.compile(ax_shell.session.document().to_data())
	check("same_authored_ramp_bridge_fixture_compiles_headless_with_matching_package",compiled_gui.ok and compiled_ax.ok and compiled_gui.package.package_hash == compiled_ax.package.package_hash and compiled_gui.package.source_hash == gui_shell.session.document().semantic_hash())
	if not compiled_gui.ok or not compiled_ax.ok:
		print("F9_AX_AUTHORING_UI_COMPILE "+JSON.stringify({"gui":compiled_gui,"ax":compiled_ax}))
		finish(); return
	var source_before_grid: String = gui_shell.session.document().semantic_hash()
	gui_shell.terrain.grid_x.value = 5000.0; gui_shell.terrain.grid_z.value = 5000.0
	gui_shell.terrain.add_grid("shared_ax_grid")
	var ax_mode := ax_presentation.set_mode("ax") if ax_presentation != null else {"ok":false}
	var ax_grid := ax_terrain_presentation.ax_invoke("terrain/grid/create",{"layer_id":"shared_ax_grid","name":"Camada 4","origin_xz":[5000.0,5000.0],"columns":5,"rows":5,"sample_spacing":32.0,"height":0.0}) if ax_terrain_presentation != null else {"ok":false}
	var gui_grid_hash: String = gui_shell.session.document().semantic_hash()
	check("gui_and_ax_grid_share_producer_and_explicit_identity",gui_grid_hash != source_before_grid and ax_mode.ok and ax_grid.ok and gui_grid_hash == ax_shell.session.document().semantic_hash() and ax_grid.entity_id == "shared_ax_grid")
	var ax_compiled_grid := Compiler.compile(ax_shell.session.document().to_data())
	var gui_compiled_grid := Compiler.compile(gui_shell.session.document().to_data())
	check("identical_gui_ax_grid_inputs_have_identical_headless_compilation",ax_compiled_grid.ok and gui_compiled_grid.ok and ax_compiled_grid.package.package_hash == gui_compiled_grid.package.package_hash and ax_compiled_grid.package.source_hash == gui_grid_hash)
	gui_shell.terrain.bridge_x.value = 5000.0; gui_shell.terrain.bridge_z.value = 5200.0
	gui_shell.terrain.bridge_width.value = 100.0; gui_shell.terrain.bridge_length.value = 100.0; gui_shell.terrain.bridge_height.value = 40.0
	gui_shell.terrain.add_bridge("shared_ax_bridge")
	var ax_bridge := ax_terrain_presentation.ax_invoke("terrain/bridge/create",{"surface_id":"shared_ax_bridge","layer_id":"shared_ax_grid","origin_xz":[5000.0,5200.0],"width":100.0,"length":100.0,"height":40.0})
	check("gui_and_ax_bridge_use_same_semantic_operation",ax_bridge.ok and ax_bridge.entity_id == "shared_ax_bridge" and gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash())
	var gate := {"connector_id":"shared_ax_gate","surface_id":"shared_ax_grid","position_xyz":[5000.0,0.0,5050.0],"kind":"walk","normal_xyz":[-1,0,0],"width":32.0,"headroom":100.0,"tags":["map_editor"],"direction":"both"}
	gui_shell.terrain.connector_id.text = "shared_ax_gate"
	gui_shell.terrain.connector_x.value = 5000.0; gui_shell.terrain.connector_y.value = 0.0; gui_shell.terrain.connector_z.value = 5050.0
	gui_shell.terrain.connector_width.value = 32.0; gui_shell.terrain.connector_headroom.value = 100.0
	gui_shell.terrain.connector_side.select(0); gui_shell.terrain.connector_direction.select(0); gui_shell.terrain.connector_tags.text = "map_editor"
	var gui_connector_surface := find_surface_index(gui_shell.terrain,"shared_ax_grid")
	if gui_connector_surface >= 0: gui_shell.terrain.connector_surface.select(gui_connector_surface)
	gui_shell.terrain.save_connector()
	var ax_connector := ax_terrain_presentation.ax_invoke("terrain/connector/upsert",gate)
	check("gui_and_ax_connector_share_full_canonical_parameters",gui_connector_surface >= 0 and ax_connector.ok and gui_shell.session.document().to_data().connectors.size() == 1 and gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash())
	check("shared_authoring_hash_matches_across_complete_gui_and_ax_sources",gui_shell.session.document().semantic_hash() == ax_shell.session.document().semantic_hash() and gui_shell.session.document().to_data() == ax_shell.session.document().to_data())
	await frames(3)
	var image := root.get_texture().get_image()
	var capture := image.save_png(evidence_dir.path_join("ax_gui_shared_authorship.png")) if image != null else FAILED
	check("native_ax_authoring_capture_written",capture == OK and image.get_size().x >= 1280 and image.get_size().y >= 720)
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
	var ok: bool = checks.size() == 10 and checks.all(func(item: Dictionary) -> bool: return item.ok)
	var source_hash := gui_shell.session.document().semantic_hash() if is_instance_valid(gui_shell) else ""
	if ax_shell != null and is_instance_valid(ax_shell): ax_shell.free()
	if gui_shell != null and is_instance_valid(gui_shell): gui_shell.free()
	print("F9_AX_AUTHORING_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"expected_count":10,"checks":checks,"source_hash":source_hash}))
	quit(0 if ok else 1)
