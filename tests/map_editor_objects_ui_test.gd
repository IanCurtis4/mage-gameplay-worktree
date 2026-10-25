@tool
extends EditorPlugin
const Fixture = preload("res://tests/map_editor_objects_test.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_OBJECT_UI_CHECK "+id+" "+str(ok))
func capture(control: Control, name: String) -> void:
	await frames(); RenderingServer.force_draw(false); await frames()
	var image: Image = control.get_viewport().get_texture().get_image()
	check("capture_"+name,image.save_png(OS.get_environment("F9_EVIDENCE").path_join(name+".png")) == OK)
func run() -> void:
	await get_tree().create_timer(2).timeout
	EditorInterface.set_main_screen_editor("Mapas"); await frames()
	var shell: Control
	for node: Node in EditorInterface.get_editor_main_screen().get_children():
		if node.get_script() == preload("res://addons/ragrpg_map_editor/shell.gd"): shell = node
	check("native_shell",shell != null and shell.is_visible_in_tree())
	if shell == null: finish(); return
	shell.session.replace(Fixture.fixture())
	var presentation: Control = shell.get_node("AuthoringPresentation")
	check("stable_open_action",presentation.actions.has("piece/open_objects"))
	presentation.actions["piece/open_objects"].control.pressed.emit(); await frames()
	var panel: Control = shell.objects_window.get_child(0)
	check("native_objects_window",shell.objects_window.visible and panel.is_visible_in_tree())
	check("catalog_thumbnails",panel.palette.item_count == 3 and panel.palette.get_item_icon(0) != null)
	var oak_texture := load("res://assets/art/map_authoring/props/oak_tree.png") as Texture2D
	check("mipmaps_imported",oak_texture != null and oak_texture.get_image().has_mipmaps())
	panel.selected_definition = "oak_tree"; panel.x.value = 600; panel.z.value = 600; panel.snap.value = 0
	check("place_tree_from_controls",panel.place_at_fields().ok)
	panel.selected_definition = "moss_boulder"; panel.x.value = 400; panel.z.value = 400
	check("place_rock_from_controls",panel.place_at_fields().ok)
	panel.selected_definition = "woodland_shrub"; panel.x.value = 200; panel.z.value = 200
	check("place_shrub_from_controls",panel.place_at_fields().ok)
	await frames(); panel.canvas.fit(); await frames()
	check("same_source_shared_with_main_screen",shell.session.document().to_data().placements.size() == 3 and shell.terrain.canvas.source.placements.size() == 3)
	var sprites := 0
	for node: Node in panel.canvas._mesh_root.get_children():
		if node is Sprite2D: sprites += 1
	check("actual_sprites_rendered",sprites == 3 and panel.canvas._object_records.size() == 3)
	var before: String = shell.session.document().semantic_hash()
	shell.session.undo(); check("undo_native",shell.session.document().to_data().placements.size() == 2)
	shell.session.redo(); check("redo_native",shell.session.document().semantic_hash() == before)
	var tree: Dictionary = shell.session.document().to_data().placements[0]
	var tree_at: Vector2 = panel.canvas.screen(Vector3(tree.position_xyz[0],tree.position_xyz[1],tree.position_xyz[2])+Vector3.UP*25)
	var picked: String = preload("res://scripts/map_authoring/objects/object_view.gd").pick(panel.canvas._object_records,tree_at,panel.canvas.screen,panel.canvas._scale)
	check("alpha_selection_picks_tree",picked == tree.placement_id)
	panel.selected_ids.clear(); panel.selected_ids.append(tree.placement_id); panel._inspect_selection()
	check("lock_from_native_panel",panel.apply_operation("lock",{"ids":panel.selected_ids,"value":true}).ok)
	panel.x.value = 650; panel.z.value = 600
	check("locked_native_move_rejected",not panel.move_at_fields().ok)
	check("unlock_from_native_panel",panel.apply_operation("lock",{"ids":panel.selected_ids,"value":false}).ok)
	panel.selected_definition = "woodland_shrub"; panel.x.value = 400; panel.z.value = 400; panel.radius.value = 220; panel.quantity.value = 6; panel.spacing.value = 20
	var count: int = shell.session.document().to_data().placements.size()
	check("scatter_preview",panel.prepare_scatter().ok and shell.session.document().to_data().placements.size() == count and panel.canvas.source.placements.size() == count+6)
	panel._confirmation.popup_centered(); await frames()
	check("native_confirmation",panel._confirmation.visible)
	panel._confirmation.confirmed.emit(); panel._confirmation.hide(); await frames()
	check("scatter_confirmed_once",shell.session.document().to_data().placements.size() == count+6)
	panel.canvas.fit(); await capture(panel,"objects")
	var source: Dictionary = shell.session.document().to_data()
	var package := Terrain.compile(source)
	check("native_headless_package",package.ok and package.package.objects.size() == count+6)
	var map := Map.empty("objects_native"); var hash_source := Schema.semantic_hash(source)
	map.pieces = [{"piece_hash":hash_source,"source":source}]
	map.instances = [{"instance_id":"garden","piece_hash":hash_source,"position_xyz":[0,0,0],"rotation_quarters":0}]
	var compiled := MapCompiler.compile(map)
	check("composition_with_occupied_center",compiled.ok)
	if compiled.ok:
		shell.open_composition(); await frames()
		var composition: Control = shell.composition_window.get_child(0)
		composition.canvas.set_package(compiled.package); await frames()
		check("composition_sprites_preserved",composition.canvas._object_sprites.size() == count+6)
		check("free_spawn_around_center_object",composition.canvas.start_test().ok)
		await capture(composition,"objects_map")
		composition.canvas.stop_test(); shell.composition_window.hide()
	shell.objects_window.hide()
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_OBJECTS_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
