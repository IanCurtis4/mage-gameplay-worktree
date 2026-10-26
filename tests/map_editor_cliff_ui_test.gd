@tool
extends EditorPlugin
const Fixture = preload("res://tests/map_editor_cliff_test.gd")
const Probe = preload("res://tests/map_editor_materials_ui_test.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_CLIFF_UI_CHECK "+id+" "+str(ok))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func capture(canvas: Control, name: String) -> Image:
	await frames(); RenderingServer.force_draw(false); await frames()
	var image := canvas.get_viewport().get_texture().get_image()
	check("capture_"+name,image.save_png(OS.get_environment("F9_EVIDENCE").path_join(name+".png")) == OK)
	return image
static func visible(color: Color) -> bool:
	return color.get_luminance() > 0.12 and Vector3(color.r-0.067,color.g-0.106,color.b-0.141).length() > 0.12
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_editor_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	var data := Fixture.source()
	data.layers = [Fixture.layer("floor",0,100,[0,0,-400,0,0,-400])]
	data.layers[0].columns = 3
	var initial := Schema.semantic_hash(data); var compiled := Terrain.compile(data)
	check("mixed_relief_compiles_for_native_editor",compiled.ok and compiled.package.part.surfaces.size() == 1 and compiled.package.part.solid_prisms.size() == 2)
	shell.session.replace(data); await frames()
	var canvas: Control = shell.terrain.canvas
	var scroll := shell.terrain.get_parent().get_parent() as ScrollContainer
	if scroll != null: scroll.ensure_control_visible(canvas)
	await frames(); canvas.fit(); await frames()
	check("draft_preview_keeps_all_faces",canvas._shape.ok and canvas._shape.visuals.size() == 2 and canvas._shape.exposed_sides.size() == 6)
	var count := 0
	for node: Node in canvas._mesh_root.get_children():
		if node is MeshInstance2D and (node.mesh.surface_get_format(0) & Materials.MESH_FLAGS) == Materials.MESH_FLAGS: count += 1
	check("tops_and_sides_share_material_pipeline",count == 8)
	var image := await capture(canvas,"mixed_cliff")
	check("steep_real_face_visible_above_background",visible(Probe.patch(image,canvas,Vector3(150,-200,50))))
	check("exposed_mass_side_visible_above_background",visible(Probe.patch(image,canvas,Vector3(50,-100,100))))
	check("walking_floor_still_visible",visible(Probe.patch(image,canvas,Vector3(50,0,50))))
	check("render_does_not_rewrite_source",shell.session.document().semantic_hash() == initial)
	var map := Map.empty("mixed_native"); map.pieces = [{"piece_hash":initial,"source":data}]; map.instances = [{"instance_id":"mixed","piece_hash":initial,"rotation_quarters":1,"position_xyz":[300,0,0]}]
	var composed := MapCompiler.compile(map)
	check("mixed_rotated_composition_compiles",composed.ok and MapCompiler.validate_package(composed.package))
	if not composed.ok: print(composed); finish(); return
	shell.open_composition(); await frames()
	var composition: Control = shell.composition_window.get_child(0)
	composition.canvas.set_package(composed.package); await frames()
	var rotated := await capture(composition.canvas,"mixed_rotated_map")
	check("rotated_cliff_visible_in_composition",visible(Probe.patch(rotated,composition.canvas,Vector3(250,-200,150))))
	check("rotated_view_keeps_every_face",composition.canvas.package.render_instances[0].visuals.size() == 2)
	shell.composition_window.hide()
	var bridge := Fixture.source()
	bridge.layers = [Fixture.layer("ground",0,100,[40,40,40,40,0,0])]; bridge.layers[0].rows = 3
	bridge.special_surfaces = [{"surface_id":"bridge","layer_id":"ground","vertices_xyz":[[100,40,0],[200,40,0],[200,40,100],[100,40,100]],"headroom":100}]
	var ground := Terrain.compile(bridge)
	check("ground_and_bridge_compile_with_lower_strip",ground.ok)
	shell.session.replace(bridge); await frames()
	if scroll != null: scroll.ensure_control_visible(canvas)
	await frames(); canvas.fit(); await frames()
	var bridge_image := await capture(canvas,"bridge_lower_strip")
	check("bridge_lower_strip_uses_actual_textured_geometry",canvas._shape.ok and canvas._shape.exposed_sides.any(func(side: Dictionary) -> bool: return side.vertices.all(func(p: Vector3) -> bool: return p.x == 100) and side.vertices.any(func(p: Vector3) -> bool: return p.y == -4) and side.vertices.any(func(p: Vector3) -> bool: return p.y == 36)))
	check("exposed_lower_strip_visible_above_background",visible(Probe.patch(bridge_image,canvas,Vector3(100,0,90))))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_CLIFF_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
