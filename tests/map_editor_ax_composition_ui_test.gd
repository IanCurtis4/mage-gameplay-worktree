extends SceneTree
## Native-window proof that the real map composition screen renders the AX-authored map.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PieceStore = preload("res://scripts/map_authoring/io/source_store.gd")

const EXPECTED_COUNT := 13
const MAP_CONTEXT_TITLE := "Contexto do mapa · Exceções manuais"
var checks: Array[Dictionary] = []
var shell: Variant
var map_panel: Variant
var presentation: Variant
var evidence_dir := ""
var fixture_dir := ""

func _initialize() -> void:
	run.call_deferred()

func check(id: String, ok: bool, detail: Dictionary = {}) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_AX_COMPOSITION_UI_CHECK "+id+" "+str(ok))
	if not ok and not detail.is_empty(): print("F9_AX_COMPOSITION_UI_DIAGNOSTIC "+id+" "+JSON.stringify(detail))

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
	if evidence_dir.is_empty(): evidence_dir = ProjectSettings.globalize_path("res://.godot/f9_ax_composition/ui")
	fixture_dir = ProjectSettings.globalize_path("res://.godot/f9_ax_composition/ui_fixtures_"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	DirAccess.make_dir_recursive_absolute(fixture_dir)
	Presentation.active_mode = "ux"
	shell = Shell.new(); shell.name = "AxCompositionNativeShell"; root.add_child(shell)
	await frames(3)
	var piece_presentation: Variant = shell.get_node_or_null("AuthoringPresentation")
	var ax_mode: Dictionary = piece_presentation.set_mode("ax") if piece_presentation != null else {"ok":false}
	var opened: Dictionary = piece_presentation.ax_invoke("piece/compose_map",{}) if piece_presentation != null else {"ok":false}
	await frames(4)
	var composition_window: Window = shell.composition_window
	composition_window.position = Vector2i.ZERO; composition_window.size = root.size
	map_panel = composition_window.get_child(0) if composition_window != null and composition_window.get_child_count() > 0 else null
	presentation = map_panel.get_node_or_null("AuthoringPresentation") if map_panel != null else null
	var map_mode: Dictionary = presentation.set_mode("ax") if presentation != null else {"ok":false}
	check("real_shell_opens_the_real_composition_window_and_its_own_ax_presentation",ax_mode.ok and opened.ok and composition_window != null and composition_window.visible and map_panel != null and map_panel.session != null and presentation != null and presentation.ax_snapshot().screen == "map" and map_mode.ok)
	var context_window_initial: Window = find_window(map_panel,MAP_CONTEXT_TITLE)
	var exchange_window_initial: Window = find_window(map_panel,"Intercâmbio · Revisar proposta")
	check("map_context_and_exchange_auxiliary_windows_start_closed",context_window_initial != null and not context_window_initial.visible and exchange_window_initial != null and not exchange_window_initial.visible)
	var initial_commands: Array[String] = []
	if presentation != null:
		for command: Dictionary in presentation.ax_snapshot().commands: initial_commands.append(str(command.id))
	check("map_screen_advertises_the_closed_instance_link_context_and_compile_actions",["map/piece/add","map/instance/select","map/instance/transform","map/instance/remove","map/link/upsert","map/link/remove","map/context/set","map/mode/set","map/compile_map"].all(func(id: String) -> bool: return id in initial_commands))
	var source_sample: Dictionary = MapDocument.sample()
	var left_path: String = fixture_dir.path_join("native_left.json")
	var right_path: String = fixture_dir.path_join("native_right.json")
	var left_save: Dictionary = PieceStore.save_source(left_path,source_sample.pieces[0].source,"")
	var right_save: Dictionary = PieceStore.save_source(right_path,source_sample.pieces[1].source,"")
	var start: Dictionary = map_panel.session.replace(MapDocument.empty("native_composition"))
	map_panel.session.saved_hash = MapDocument.hash_source(map_panel.session.data)
	var left_add: Dictionary = presentation.ax_invoke("map/piece/add",{"path":left_path,"instance_id":"native_left","position_xz":[0.0,0.0],"rotation_quarters":0})
	var right_add: Dictionary = presentation.ax_invoke("map/piece/add",{"path":right_path,"instance_id":"native_right","position_xz":[100.0,0.0],"rotation_quarters":0})
	var link: Dictionary = {"link_id":"native_seam","a_instance":"native_left","a_connector":"east","b_instance":"native_right","b_connector":"west"}
	var linked: Dictionary = presentation.ax_invoke("map/link/upsert",link)
	var source_hash: String = MapDocument.hash_source(map_panel.session.data)
	var command_result: Dictionary = presentation.ax_snapshot()
	var map_snapshot: Dictionary = command_result.get("source",{})
	check("native_map_ax_actions_load_valid_piece_snapshots_add_identities_link_seam_and_expose_map_source",left_save.ok and right_save.ok and start.ok and left_add.ok and right_add.ok and linked.ok and map_panel.session.data.instances.size() == 2 and map_panel.session.data.links == [link] and map_snapshot.document_id == "native_composition" and MapDocument.hash_source(map_snapshot) == source_hash)
	var gui_baseline: String = MapDocument.hash_source(map_panel.session.data)
	map_panel.select_id("native_right")
	map_panel.x.value = 101.0
	map_panel.z.value = 0.0
	map_panel.apply_placement()
	var gui_changed_hash: String = MapDocument.hash_source(map_panel.session.data)
	var ax_restore: Dictionary = presentation.ax_invoke("map/instance/transform",{"instance_id":"native_right","position_xz":[100.0,0.0],"rotation_quarters":0})
	var restored_position: Array = map_panel.session.data.instances[1].position_xyz
	var restored_point := Vector3(restored_position[0],restored_position[1],restored_position[2])
	check("visible_gui_placement_control_and_ax_transform_share_map_session",gui_changed_hash != gui_baseline and ax_restore.ok and MapDocument.hash_source(map_panel.session.data) == gui_baseline and restored_point == Vector3(100,0,0),{"baseline":gui_baseline,"gui_changed":gui_changed_hash,"restored":MapDocument.hash_source(map_panel.session.data),"position":restored_position,"restore_ok":ax_restore.ok})
	var invalid_hash: String = MapDocument.hash_source(map_panel.session.data)
	var invalid_depth: int = map_panel.session._undo.size()
	var invalid_transform: Dictionary = presentation.ax_invoke("map/instance/transform",{"instance_id":"native_right","position_xz":[16001.0,0.0],"rotation_quarters":0})
	check("native_ax_rejects_out_of_range_transform_without_source_or_history_mutation",not invalid_transform.ok and MapDocument.hash_source(map_panel.session.data) == invalid_hash and map_panel.session._undo.size() == invalid_depth)
	var context_window: Window = find_window(map_panel,MAP_CONTEXT_TITLE)
	var source_before_context: String = MapDocument.hash_source(map_panel.session.data)
	var context_open: Dictionary = presentation.ax_invoke("map/map_context",{})
	await frames(3)
	var is_context_open: bool = context_window != null and context_window.visible
	if context_window != null: context_window.close_requested.emit()
	await frames(2)
	check("map_context_opens_and_closes_as_a_real_auxiliary_window_without_source_mutation",context_open.ok and context_window != null and is_context_open and not context_window.visible and MapDocument.hash_source(map_panel.session.data) == source_before_context)
	var context_change: Dictionary = presentation.ax_invoke("map/context/set",{"biome_id":"forest","instance_id":"native_left","rules":["biome"],"reason":"Entrada preparada para floresta."})
	var context_form: Control = map_panel.context_panel
	context_form.refresh()
	for index: int in context_form.instances.item_count:
		if context_form.instances.get_item_text(index) == "native_left": context_form.instances.select(index)
	context_form.select_instance(); context_form.biome.text = "forest"; context_form.rules.select(0,false); context_form.reason.text = "Motivo preenchido no formulário."
	context_form.save_context()
	var form_hash: String = MapDocument.hash_source(map_panel.session.data)
	var ax_form: Dictionary = presentation.ax_invoke("map/context/set",{"biome_id":"forest","instance_id":"native_left","rules":["biome"],"reason":"Motivo preenchido no formulário."})
	check("native_context_form_and_parameterized_ax_share_policy_producer",ax_form.ok and ax_form.output_hash == form_hash and map_panel.session.data.context.overrides[0].reason == "Motivo preenchido no formulário.")
	var warning_count: int = map_panel.problems.item_count
	var context_clear: Dictionary = presentation.ax_invoke("map/context/set",{"biome_id":"forest","instance_id":"native_left","rules":[],"reason":""})
	check("native_map_context_exception_produces_warning_and_can_be_cleared",context_change.ok and warning_count > 0 and context_clear.ok and map_panel.session.data.context.overrides.is_empty())
	source_hash = MapDocument.hash_source(map_panel.session.data)
	var compile_request: Dictionary = presentation.ax_invoke("map/compile_map",{})
	var wait_frames: int = 0
	while map_panel.job != null and wait_frames < 3000:
		await process_frame
		RenderingServer.force_draw(false)
		wait_frames += 1
	var compiled: Dictionary = map_panel.result.duplicate(true)
	await frames(3)
	check("native_composition_screen_waits_for_successful_current_compiler_result",compile_request.ok and wait_frames < 3000 and map_panel.job == null and compiled.get("ok",false) and compiled.package.source_hash == source_hash and map_panel.canvas.package.package_hash == compiled.package.package_hash)
	check("compiled_native_package_contains_both_real_pieces_and_render_meshes",compiled.package.piece_count == 2 and compiled.package.manifest.stages.size() > 0 and map_panel.canvas._meshes.get_child_count() > 0)
	var canvas: Control = map_panel.canvas
	canvas.custom_minimum_size.y = 440.0
	await frames(4)
	var scroll: ScrollContainer = find_scroll_ancestor(canvas)
	if scroll != null: scroll.ensure_control_visible(canvas)
	await frames(3)
	canvas.fit()
	await frames(3)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var capture_status: Error = image.save_png(evidence_dir.path_join("map_composition_ax_native.png")) if image != null else FAILED
	var image_size: Vector2i = image.get_size() if image != null else Vector2i.ZERO
	var physical_size: Vector2i = DisplayServer.window_get_size()
	var colors: int = sample_colors(image,canvas.get_global_rect()) if image != null and root.gui_embed_subwindows else (sample_colors(image,Rect2(Vector2.ZERO,canvas.size)) if image != null else 0)
	var mesh_count: int = canvas._meshes.get_child_count() if is_instance_valid(canvas) and canvas._meshes != null else 0
	var capture_predicates: Dictionary = {"saved":capture_status == OK,"image_size":image_size,"physical_window_size":physical_size,"matching_dimensions":image_size == physical_size,"canvas_visible":canvas.is_visible_in_tree(),"canvas_size":canvas.size,"canvas_minimum":canvas.size.x >= 600.0 and canvas.size.y >= 400.0,"mesh_count":mesh_count,"rendered_colors":colors,"auxiliary_visible":has_visible_auxiliary_windows(map_panel),"source_hash":MapDocument.hash_source(map_panel.session.data),"package_hash":compiled.package.package_hash}
	print("F9_AX_COMPOSITION_UI_CAPTURE "+JSON.stringify(capture_predicates))
	check("native_capture_shows_the_actual_compiled_map_and_meets_viewport_dimensions",capture_status == OK and image != null and image_size == physical_size and image_size.x >= 1280 and image_size.y >= 720 and canvas.is_visible_in_tree() and canvas.size.x >= 600.0 and canvas.size.y >= 400.0 and mesh_count > 0 and colors >= 4 and not has_visible_auxiliary_windows(map_panel) and capture_predicates.source_hash == source_hash)
	var final_snapshot: Dictionary = presentation.ax_snapshot()
	var final_map_snapshot: Dictionary = final_snapshot.get("source",{})
	check("final_native_snapshot_still_matches_visible_map_and_semantic_source",final_map_snapshot.instances.size() == 2 and MapDocument.hash_source(final_map_snapshot) == source_hash and MapDocument.hash_source(map_panel.session.data) == source_hash)
	Presentation.active_mode = "ux"
	finish()

func finish() -> void:
	Presentation.active_mode = "ux"
	var all_ok: bool = checks.size() == EXPECTED_COUNT and checks.all(func(item: Dictionary) -> bool: return item.ok)
	var source_hash: String = MapDocument.hash_source(map_panel.session.data) if is_instance_valid(map_panel) else ""
	print("F9_AX_COMPOSITION_UI_RESULT "+JSON.stringify({"ok":all_ok,"count":checks.size(),"expected_count":EXPECTED_COUNT,"checks":checks,"source_hash":source_hash,"evidence_dir":evidence_dir}))
	if is_instance_valid(shell): shell.free()
	quit(0 if all_ok else 1)

func find_window(parent: Node, title: String) -> Window:
	if parent == null: return null
	for child: Node in parent.get_children():
		if child is Window and child.title == title: return child as Window
		var nested: Window = find_window(child,title)
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
