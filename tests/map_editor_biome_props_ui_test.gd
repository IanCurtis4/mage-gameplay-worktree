@tool
extends EditorPlugin
const Fixture = preload("res://tests/map_editor_biome_props_test.gd")
const Objects = preload("res://scripts/map_authoring/objects/object_view.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_BIOME_PROPS_UI_CHECK "+id+" "+str(ok))
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func capture(control: Control, name: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	var image := control.get_viewport().get_texture().get_image()
	check("capture_"+name,image.save_png(OS.get_environment("F9_EVIDENCE").path_join(name+".png")) == OK)
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	shell.session.replace(Fixture.source()); await frames()
	var presentation: Control = shell.get_node("AuthoringPresentation")
	presentation.actions["piece/open_objects"].control.pressed.emit(); await frames()
	var panel: Control = shell.objects_window.get_child(0)
	check("six_named_palette_entries",panel.palette.item_count == 6 and panel.palette.get_item_icon(0) != null)
	panel.search.text = "Estruturas"; panel.search.text_changed.emit(panel.search.text)
	check("structure_category_uses_portuguese_search",panel.palette.item_count == 1 and panel.palette.get_item_metadata(0) == "broken_pillar")
	panel.search.text = ""; panel.search.text_changed.emit("")
	for k: int in Fixture.IDS.size():
		panel.selected_definition = Fixture.IDS[k]; panel.x.value = 180+k*220; panel.z.value = 400; panel.snap.value = 0
		check("native_place_"+Fixture.IDS[k],panel.place_at_fields().ok)
	await frames(); panel.canvas.fit(); await frames()
	var sprites: Array[Sprite2D] = []
	for node: Node in panel.canvas._mesh_root.get_children():
		if node is Sprite2D: sprites.append(node)
	check("three_native_sprite_nodes",sprites.size() == 3)
	var source: Dictionary = shell.session.document().to_data(); var initial := Schema.semantic_hash(source)
	var catalog := Catalog.load_catalog()
	for id: String in Fixture.IDS:
		var placement: Dictionary = {}
		for value: Dictionary in source.placements:
			if value.definition_id == id: placement = value
		var sprite: Sprite2D
		for value: Sprite2D in sprites:
			if value.get_meta("placement_id") == placement.placement_id: sprite = value
		var definition: Dictionary = catalog.definitions[id]
		check(id+"_sprite_scale_and_mipmaps",sprite != null and is_equal_approx(sprite.scale.y*float(sprite.texture.get_height()),float(definition.world_height)) and sprite.texture.get_image().has_mipmaps())
		var position := Vector3(placement.position_xyz[0],placement.position_xyz[1],placement.position_xyz[2])
		var picked := Objects.pick(panel.canvas._object_records,panel.canvas.screen(position+Vector3.UP*15),panel.canvas.screen,panel.canvas._scale)
		check(id+"_alpha_pick_hits_actual_asset",picked == placement.placement_id)
		Objects.reveal_actor(sprites,position)
		check(id+"_occlusion_fades_sprite",sprite != null and is_equal_approx(sprite.modulate.a,0.38))
	Objects.reveal_actor(sprites,Vector3(9999,0,9999))
	check("occlusion_clears_after_actor_leaves",sprites.all(func(sprite: Sprite2D) -> bool: return is_equal_approx(sprite.modulate.a,1.0)))
	await capture(panel,"biome_props_light")
	var dark := source.duplicate(true); dark.layers[0].material_masks.erase("sand"); dark.layers[0].material_masks["earth"] = [1.0,1.0,1.0,1.0]
	check("dark_ground_uses_shared_source_operation",shell.session.apply(dark).ok)
	await frames(); panel.canvas.fit(); await capture(panel,"biome_props_dark")
	check("dark_ground_keeps_same_object_definitions",shell.session.document().to_data().placements == source.placements)
	check("undo_restores_exact_light_source",shell.session.undo() and shell.session.document().semantic_hash() == initial)
	check("native_source_receives_compiled_objects",Terrain.compile(shell.session.document().to_data()).ok)
	shell.objects_window.hide(); finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_BIOME_PROPS_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
