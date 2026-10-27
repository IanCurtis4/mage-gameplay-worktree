@tool
extends EditorPlugin
## Native comparisons on real packages and the actual animated CombatActor.
const Fixture = preload("res://tests/map_editor_borders_test.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Canvas = preload("res://scripts/map_authoring/preview/map_canvas.gd")
const Operations = preload("res://scripts/map_authoring/objects/object_operations.gd")
const ProjectionView = preload("res://scripts/world/expedition_geometry_view.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Shadow = preload("res://scripts/world/ground_shadow.gd")
const SampleTerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
var checks: Array[Dictionary] = []
func _enter_tree() -> void: run.call_deferred()
func frames() -> void:
	await get_tree().process_frame; await get_tree().process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_SHADOW_UI_CHECK "+id+" "+str(ok))
static func source(material: String, rise: float = 0.0) -> Dictionary:
	var data := Piece.empty("shadow_native")
	var layer := {"layer_id":"floor","name":"Piso","origin_xz":[0,0],"sample_spacing":400,"columns":2,"rows":2,"heights":[0,rise,0,rise],"material_masks":{},"locked":false,"protected_regions":[]}
	for id: String in ["grass","earth","sand","stone"]: layer.material_masks[id] = [1.0 if id == material else 0.0,1.0 if id == material else 0.0,1.0 if id == material else 0.0,1.0 if id == material else 0.0]
	data.layers = [layer]
	for spec: Array in [["oak_tree",80,80],["desert_cactus",270,80],["sandstone_boulder",80,270],["broken_pillar",270,270]]:
		var proposed := Operations.propose(data,"place",{"placement_id":spec[0],"definition_id":spec[0],"surface_id":"floor","position_xz":[spec[1],spec[2]]})
		if not proposed.ok: return {}
		data = proposed.data
	return data
func capture(window: Window, name: String) -> Image:
	await frames(); RenderingServer.force_draw(false); await frames()
	var image: Image = window.get_texture().get_image()
	check("capture_"+name,image.save_png(OS.get_environment("F9_EVIDENCE").path_join(name+".png")) == OK)
	return image
static func darkened_in(before: Image, after: Image, rect: Rect2) -> int:
	var count := 0
	for y: int in range(maxi(0,floori(rect.position.y)),mini(after.get_height(),ceili(rect.end.y)+1)):
		for x: int in range(maxi(0,floori(rect.position.x)),mini(after.get_width(),ceili(rect.end.x)+1)):
			if before.get_pixel(x,y).get_luminance()-after.get_pixel(x,y).get_luminance() > 0.005: count += 1
	return count
func run() -> void:
	await get_tree().create_timer(2).timeout
	var window := Window.new(); window.title = "Sombras de contato F9 · fixture"; window.size = Vector2i(1024,760)
	EditorInterface.get_base_control().add_child(window); window.popup_centered(); await frames()
	var canvas := Canvas.new(); canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(canvas); await frames()
	for spec: Array in [["sand",0.0,0],["earth",0.0,0],["sand",60.0,0],["sand",0.0,1]]:
		var data := source(spec[0],spec[1]); var name: String = spec[0]+("_rotated" if spec[2] == 1 else ("_ramp" if spec[1] > 0 else "_flat"))
		check(name+"_source_authored",not data.is_empty())
		if data.is_empty(): continue
		var map := Fixture.map_source(data,"ruin_envelope_v1")
		if spec[2] == 1: map.instances[0].rotation_quarters = 1; map.instances[0].position_xyz = [400,0,0]
		var built := Compiler.compile(map)
		check(name+"_compiled_real_package",built.ok)
		if not built.ok: continue
		canvas.set_package(built.package); await frames(); canvas.fit()
		var actor := CombatActor.new(); actor.set_animation_kind(&"swordsman"); actor.actor_name = "Preview sombra"; canvas._meshes.add_child(actor)
		var cell: Dictionary = built.package.manifest.stages[0].surfaces[0]; var point := Kernel.support_y(cell,Vector3(200,0,200))
		var bound := actor.bind_world_geometry(canvas.geometry,ExpeditionWorldPoint.create("map_preview",cell.surface_id,point),built.package.profile,"shadow_native_actor")
		actor.position = ProjectionView.project(point); actor.z_index = 9+floori(point.y*4.0); actor.set_process(false)
		var ordering := canvas.update_canvas_order()
		canvas.reveal_object_occlusion(point)
		check(name+"_actual_world_order_resolves",ordering.ok)
		check(name+"_real_animated_actor_bound",bound.ok and actor.character_animation != null and actor.character_animation.atlas != null)
		var revision: int = canvas.geometry.geometry_revision; var package_hash: String = canvas.package.package_hash
		canvas.set_contact_shadows(false); actor.contact_shadows_enabled = false; actor.queue_redraw()
		var before := await capture(window,name+"_before")
		canvas.set_contact_shadows(true); actor.contact_shadows_enabled = true; actor.queue_redraw()
		var after := await capture(window,name+"_after")
		var nodes := 0
		for sprite: Sprite2D in canvas._object_sprites:
			var node := sprite.get_node_or_null("ContactShadow")
			var shown := false
			if node != null and node.visible and node.z_index == 0 and node.show_behind_parent and node.get_meta("world_vertices",[]).size() >= 3:
				nodes += 1
				var bounds := Rect2(); var first := true
				for p: Vector3 in node.get_meta("world_vertices"):
					var at: Vector2 = canvas.screen(p)
					if first: bounds = Rect2(at,Vector2.ZERO); first = false
					else: bounds = bounds.expand(at)
				shown = darkened_in(before,after,bounds) > 4
			check(name+"_"+str(sprite.get_meta("placement_id"))+"_shadow_changes_ground_pixels",shown)
		check(name+"_props_have_grounded_contact_shadows",nodes == 4)
		var framed := true
		for sprite: Sprite2D in canvas._object_sprites:
			var rect := sprite.get_rect(); var low: Vector2 = (sprite.position+rect.position*sprite.scale)*canvas._scale+canvas._origin
			var high: Vector2 = (sprite.position+rect.end*sprite.scale)*canvas._scale+canvas._origin
			if low.x < 0 or low.y < 0 or high.x > canvas.size.x or high.y > canvas.size.y: framed = false
		check(name+"_full_prop_silhouettes_fit_view",framed)
		check(name+"_presentation_does_not_mutate_physics_or_source",canvas.geometry.geometry_revision == revision and canvas.package.package_hash == package_hash)
		var darkened := 0
		for y: int in after.get_height():
			for x: int in after.get_width():
				if before.get_pixel(x,y).get_luminance()-after.get_pixel(x,y).get_luminance() > 0.01: darkened += 1
		check(name+"_contact_shadows_visibly_darken_ground",darkened > 100)
		check(name+"_actor_uses_receiver_mesh_cache",actor._ground_shadow_cache.has("mesh"))
		var actor_rect := Rect2(canvas.screen(point)-Vector2(24,14)*canvas._scale,Vector2(48,28)*canvas._scale)
		check(name+"_actor_shadow_changes_ground_pixels",darkened_in(before,after,actor_rect) > 4)
		var stationary: ArrayMesh = actor._ground_shadow_cache.mesh
		actor.queue_redraw(); await frames(); RenderingServer.force_draw(false); await frames()
		check(name+"_stationary_actor_reuses_mesh",actor._ground_shadow_cache.mesh == stationary)
		var destination := Kernel.support_y(cell,point+Vector3(20,0,0))
		var planned := actor.move_world_to(ExpeditionWorldPoint.create("map_preview",cell.surface_id,destination),canvas.geometry.geometry_revision)
		var advanced := actor.advance_world(10.0) if planned.ok else {"ok":false}
		actor.position = ProjectionView.project(actor.world_point().position); actor.queue_redraw(); await frames(); RenderingServer.force_draw(false); await frames()
		check(name+"_movement_updates_mesh_and_anchor",advanced.ok and actor._ground_shadow_cache.anchor == actor.world_point().position and actor._ground_shadow_cache.mesh != stationary)
		var prior_mesh: ArrayMesh = actor._ground_shadow_cache.mesh
		var inserted := canvas.geometry.insert_obstacle("shadow_epoch_probe",AABB(Vector3(-800,-10,-800),Vector3(10,20,10)),canvas.geometry.geometry_revision)
		actor.queue_redraw(); await frames(); RenderingServer.force_draw(false); await frames()
		check(name+"_world_epoch_refreshes_shadow_mesh",inserted.ok and actor._ground_shadow_cache.mesh != prior_mesh and actor._ground_shadow_cache.epoch[2] == canvas.geometry.geometry_revision)
		actor.world_motion.release(); actor.queue_free(); await frames()
	await bridge_case(window,canvas)
	window.queue_free(); await frames()
	var ok := checks.all(func(entry: Dictionary) -> bool: return entry.ok)
	print("F9_SHADOW_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); get_tree().quit(0 if ok else 1)
func bridge_case(window: Window, canvas: Control) -> void:
	var piece := SampleTerrainPanel.sample_source(Piece.empty("shadow_bridge"))
	var built := Compiler.compile(Fixture.map_source(piece,"ruin_envelope_v1"))
	check("bridge_sample_compiles",built.ok)
	if not built.ok: print(built); return
	canvas.set_package(built.package); await frames(); canvas.fit()
	check("bridge_view_receives_real_package",canvas.package == built.package)
	var point := Vector3(100,40,150); var cell := {}
	for candidate: Dictionary in built.package.manifest.stages[0].surfaces:
		if Kernel.contains(candidate,point): cell = candidate; break
	var actor := CombatActor.new(); actor.set_animation_kind(&"swordsman"); canvas._meshes.add_child(actor)
	var bound := actor.bind_world_geometry(canvas.geometry,ExpeditionWorldPoint.create("map_preview",cell.surface_id,point),built.package.profile,"shadow_bridge_actor")
	actor.position = ProjectionView.project(point); actor.set_process(false)
	check("bridge_actor_binds_to_upper_support",bound.ok and actor.world_point().position.y == 40.0)
	check("bridge_world_order_resolves",canvas.update_canvas_order().ok)
	var revision: int = canvas.geometry.geometry_revision; var hash_value: String = canvas.package.package_hash
	actor.contact_shadows_enabled = false; actor.queue_redraw(); var before := await capture(window,"bridge_before")
	actor.contact_shadows_enabled = true; actor.queue_redraw(); var after := await capture(window,"bridge_after")
	check("bridge_shadow_uses_upper_receiver",actor._ground_shadow_cache.surface_id == cell.surface_id and actor._ground_shadow_cache.anchor == point)
	var upper := Rect2(canvas.screen(point)-Vector2(24,14)*canvas._scale,Vector2(48,28)*canvas._scale)
	var lower := Rect2(canvas.screen(Vector3(point.x,0,point.z))-Vector2(24,14)*canvas._scale,Vector2(48,28)*canvas._scale)
	check("bridge_shadow_changes_upper_ground_pixels",darkened_in(before,after,upper) > 4)
	check("bridge_shadow_does_not_paint_lower_floor",darkened_in(before,after,lower) == 0)
	check("bridge_shadow_preserves_physics_and_package",canvas.geometry.geometry_revision == revision and canvas.package.package_hash == hash_value)
	actor.world_motion.release(); actor.queue_free(); await frames()
