@tool
extends EditorPlugin
const Fixture = preload("res://tests/map_editor_borders_test.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Canvas = preload("res://scripts/map_authoring/preview/map_canvas.gd")
const MapPanelClass = preload("res://scripts/map_authoring/composition/map_panel.gd")
const Store = preload("res://scripts/map_authoring/composition/map_store.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_BORDER_UI_CHECK "+id+" "+str(ok))
static func source() -> Dictionary:
	var piece := Piece.empty("border_native")
	piece.layers = [{"layer_id":"floor","name":"Piso","origin_xz":[0,0],"sample_spacing":400,"columns":2,"rows":2,"heights":[0,0,0,0],"material_masks":{},"locked":false,"protected_regions":[]}]
	return piece
func run() -> void:
	await get_tree().create_timer(2).timeout
	var window := Window.new(); window.title = "Perfis de borda F9 · fixture"; window.size = Vector2i(1024,760); window.position = Vector2i(120,80)
	EditorInterface.get_base_control().add_child(window); window.popup_centered(); await frames()
	var canvas := Canvas.new(); canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(canvas); await frames()
	for id: String in Catalog.IDS:
		var built := Compiler.compile(Fixture.map_source(source(),id))
		check(id+"_compiles_for_native_view",built.ok)
		if not built.ok: continue
		canvas.set_package(built.package); await frames(); canvas.fit(); await frames()
		check(id+"_view_receives_exact_package",canvas.package == built.package and canvas.geometry != null)
		var count := 0; var format_valid := true
		for node: Node in canvas._meshes.get_children():
			if not node.has_meta("border_face_id"): continue
			count += 1
			if not node is MeshInstance2D or (node.mesh.surface_get_format(0)&Materials.MESH_FLAGS) != Materials.MESH_FLAGS: format_valid = false
		check(id+"_uses_shared_world_channels",format_valid and count == built.package.border_geometry.faces.size()+built.package.border_geometry.water.size())
		check(id+"_renders_all_derived_props",canvas._object_sprites.size() == built.package.border_geometry.props.size())
		RenderingServer.force_draw(false); await frames()
		var image: Image = window.get_texture().get_image()
		check(id+"_capture_saved",image.save_png(OS.get_environment("F9_EVIDENCE").path_join(id+".png")) == OK)
		var visible := 0
		for point: Vector3 in [Vector3(200,0,200),Vector3(200,12,-40),Vector3(200,0,440)]:
			var screen: Vector2 = canvas.screen(point)
			if screen.x < 0 or screen.y < 0 or screen.x >= image.get_width() or screen.y >= image.get_height(): continue
			var color := image.get_pixel(roundi(screen.x),roundi(screen.y))
			if Vector3(color.r-0.09,color.g-0.141,color.b-0.169).length() > 0.1: visible += 1
		check(id+"_ground_and_borders_are_visible",visible >= 2)
	canvas.queue_free(); await frames()
	var panel := MapPanelClass.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(panel); await frames()
	var initial := Fixture.map_source(source(),"ruin_envelope_v1"); panel.session.replace(initial); panel.select_id("land")
	for k: int in panel.border_choice.item_count:
		if panel.border_choice.get_item_metadata(k) == "forest_rootbank_v1": panel.border_choice.select(k)
	panel.apply_border_choice(); var gui: Dictionary = panel.session.data.duplicate(true)
	check("gui_profile_uses_shared_transaction",gui.get("borders",{}).get("instances",[]) == [{"instance_id":"land","profile_id":"forest_rootbank_v1"}])
	panel.session.undo(); var presentation: Control = panel.get_node("AuthoringPresentation"); var before := Map.hash_source(panel.session.data)
	presentation.set_mode("ax")
	check("mode_switch_preserves_source_hash",Map.hash_source(panel.session.data) == before)
	var request := {"expected_source_hash":before,"command":{"operation":"set_instance_profile","instance_id":"land","profile_id":"forest_rootbank_v1"}}
	var result: Dictionary = presentation.ax_invoke("map/borders/apply",request)
	check("ax_parameterized_action_matches_gui",result.ok and panel.session.data == gui)
	check("ax_snapshot_exposes_parameter_schema",presentation.ax_snapshot().commands.any(func(entry: Dictionary) -> bool: return entry.id == "map/borders/apply" and entry.parameters.has("expected_source_hash")))
	result = presentation.ax_invoke("map/borders/apply",request)
	check("ax_stale_request_has_no_mutation",not result.ok and result.code == "stale_source" and panel.session.data == gui)
	result = presentation.ax_invoke("map/borders/apply",{"command":request.command})
	check("ax_incomplete_request_has_no_mutation",not result.ok and panel.session.data == gui)
	var root := OS.get_environment("F9_EVIDENCE"); var input_path := root.path_join("cli_input.json"); var command_path := root.path_join("cli_request.json"); var output_path := root.path_join("cli_output.json")
	var file := FileAccess.open(input_path,FileAccess.WRITE); file.store_string(JSON.stringify(initial,"",true,true)); file.close()
	file = FileAccess.open(command_path,FileAccess.WRITE); file.store_string(JSON.stringify(request,"",true,true)); file.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://scripts/map_authoring/composition/headless.gd","--","--border-command",input_path,command_path,output_path,"-"],output,true)
	var loaded := Store.load_source(output_path)
	check("cli_command_completes_without_errors",code == 0 and not "SCRIPT ERROR:" in str(output) and not "ERROR:" in str(output))
	check("cli_source_matches_gui_and_ax",loaded.ok and loaded.data == gui)
	window.queue_free(); await frames()
	var ok := checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_BORDER_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
