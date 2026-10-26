@tool
extends EditorPlugin
const Fixture = preload("res://tests/map_editor_materials_test.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_MATERIAL_UI_CHECK "+id+" "+str(ok))
static func palette_source() -> Dictionary:
	var data := Fixture.source(); var layer: Dictionary = data.layers[0]
	layer.columns = 9; layer.rows = 9; layer.sample_spacing = 32.0; layer.heights = []; layer.material_masks = {}
	for id: String in Materials.IDS: layer.material_masks[id] = []
	for z: int in 9:
		for x: int in 9:
			layer.heights.append(0.0)
			var selected := (1 if x >= 4 else 0)+(2 if z >= 4 else 0)
			for k: int in 4: layer.material_masks[Materials.IDS[k]].append(1.0 if k == selected else 0.0)
	return data
func capture(control: Control, name: String) -> Image:
	await frames(); RenderingServer.force_draw(false); await frames()
	var result: Image = control.get_viewport().get_texture().get_image()
	check("capture_"+name,result.save_png(OS.get_environment("F9_EVIDENCE").path_join(name+".png")) == OK)
	return result
static func patch(image: Image, canvas: Control, world: Vector3) -> Color:
	var point: Vector2 = canvas.get_global_transform_with_canvas()*canvas.screen(world)
	point *= Vector2(image.get_size())/canvas.get_viewport().get_visible_rect().size
	var value := Color(0,0,0,0); var count := 0
	for y: int in range(roundi(point.y)-5,roundi(point.y)+6):
		for x: int in range(roundi(point.x)-5,roundi(point.x)+6):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height(): continue
			value += image.get_pixel(x,y); count += 1
	return value/float(maxi(1,count))
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_editor_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	var source := palette_source(); var before := Schema.semantic_hash(source)
	shell.session.replace(source); await frames()
	var panel: Control = shell.terrain
	check("four_material_choices_in_controls",panel.material_choice.item_count == 4 and panel.material_choice.get_item_text(2) == "Areia" and panel.material_choice.get_item_text(3) == "Pedra")
	panel.mode.select(4); panel.material_choice.select(2); panel.material_choice.item_selected.emit(2)
	check("sand_control_uses_shared_brush",panel.canvas.options.mode == "material" and panel.canvas.options.material == "sand")
	panel.material_choice.select(3); panel.material_choice.item_selected.emit(3)
	check("stone_control_uses_shared_brush",panel.canvas.options.material == "stone")
	panel.material_choice.select(2); panel.material_choice.item_selected.emit(2)
	panel.strength.value = 1; panel.radius.value = 12; panel.hardness.value = 1
	check("editor_applies_four_material_paint",panel.apply_stroke([Vector2(64,64)],panel.canvas.options).ok and shell.session.document().to_data().layers[0].material_masks.sand[20] == 1.0)
	var painted: String = shell.session.document().semantic_hash()
	check("editor_undo_restores_source",shell.session.undo() and shell.session.document().semantic_hash() == before)
	check("editor_redo_restores_paint",shell.session.redo() and shell.session.document().semantic_hash() == painted)
	check("restore_base_for_visual_oracle",shell.session.undo() and shell.session.document().semantic_hash() == before)
	var mipmaps := true
	for path: String in Materials.PATHS:
		var texture := load(path) as Texture2D
		mipmaps = mipmaps and texture != null and texture.get_image().has_mipmaps()
	check("all_four_tiles_have_mipmaps",mipmaps)
	var scroll := panel.get_parent().get_parent() as ScrollContainer
	if scroll != null: scroll.ensure_control_visible(panel.canvas)
	await frames(); panel.canvas.fit(); await frames()
	var custom_meshes := 0
	for node: Node in panel.canvas._mesh_root.get_children():
		if node is MeshInstance2D and (node.mesh.surface_get_format(0) & Materials.MESH_FLAGS) == Materials.MESH_FLAGS: custom_meshes += 1
	check("native_canvas_uses_world_custom_channels",custom_meshes > 0)
	var image := await capture(panel.canvas,"materials_palette")
	var colors: Array[Color] = []
	for point: Vector3 in [Vector3(64,0,64),Vector3(192,0,64),Vector3(64,0,192),Vector3(192,0,192)]: colors.append(patch(image,panel.canvas,point))
	check("grass_weight_with_zero_alpha_is_visible",colors[0].g > colors[0].r*1.05 and colors[0].g > colors[0].b*1.05 and colors[0].get_luminance() > 0.1)
	var distinct := true
	for i: int in colors.size():
		for j: int in range(i+1,colors.size()):
			if Vector3(colors[i].r,colors[i].g,colors[i].b).distance_to(Vector3(colors[j].r,colors[j].g,colors[j].b)) < 0.025: distinct = false
	check("four_rendered_materials_are_distinct",distinct)
	print("F9_MATERIAL_UI_COLORS "+str(colors))
	var sloping := source.duplicate(true)
	for z: int in 9:
		for x: int in 9: sloping.layers[0].heights[z*9+x] = -float(x)*24.0
	var slope_hash := Schema.semantic_hash(sloping)
	check("slope_keeps_real_walkable_geometry",Terrain.compile(sloping).ok)
	shell.session.replace(sloping); await frames()
	if scroll != null: scroll.ensure_control_visible(panel.canvas)
	await frames(); panel.canvas.fit()
	var slope_image := await capture(panel.canvas,"materials_slope")
	var slope_grass := patch(slope_image,panel.canvas,Vector3(64,-48,64))
	check("slope_visibly_blends_stone",slope_grass.get_luminance() > 0.15 and Vector3(slope_grass.r-0.067,slope_grass.g-0.106,slope_grass.b-0.141).length() > 0.12 and colors[0].g-colors[0].r > slope_grass.g-slope_grass.r+0.02)
	check("slope_shading_does_not_repaint_source",Schema.semantic_hash(sloping) == slope_hash and shell.session.document().to_data().layers[0].material_masks == source.layers[0].material_masks)
	var map := Map.empty("materials_native"); map.pieces = [{"piece_hash":before,"source":source}]; map.instances = [{"instance_id":"palette","piece_hash":before,"rotation_quarters":1,"position_xyz":[256,0,0]}]
	var built := MapCompiler.compile(map)
	check("compiled_map_uses_same_material_dependencies",built.ok and built.package.dependencies == Materials.dependencies())
	if built.ok:
		shell.open_composition(); await frames()
		var composition: Control = shell.composition_window.get_child(0)
		composition.canvas.set_package(built.package); await frames()
		var count := 0
		for node: Node in composition.canvas._meshes.get_children():
			if node is MeshInstance2D and (node.mesh.surface_get_format(0) & Materials.MESH_FLAGS) == Materials.MESH_FLAGS: count += 1
		check("composition_keeps_custom_world_attributes",count > 0)
		await capture(composition,"materials_rotated_map")
		shell.composition_window.hide()
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_MATERIAL_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
