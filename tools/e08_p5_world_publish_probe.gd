extends SceneTree
## E08 P5 B2b visual proof of the REPUBLISHED forest maps (no runtime swaps): boots
## the pinned package in the real renderer (non-headless) with UI at 120% and
## captures the spawn at zoom 50/100/160, the nearest birch next to an oak, each
## decorative variant and a cliff face at zoom 160/100.
## Usage: --script res://tools/e08_p5_world_publish_probe.gd -- {output} <package_id>
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
const PreviewApp = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const ZOOMS: Array[float] = [0.5, 1.0, 1.6]
const FILES := ["oak_tree.png","birch_tree.png","woodland_shrub.png","fern_cluster.png","wildflower_patch.png","mushroom_ring.png","fallen_log.png","moss_boulder.png"]

var folder := ""
var host: RunController
var view: ExpeditionGeometryView
var map_view: Node2D
var base_offset := Vector2.ZERO
var report := {"captures": []}

func _initialize() -> void: _run.call_deferred()

func find_script(node: Node, suffix: String) -> Node:
	var script: Script = node.get_script()
	if script != null and script.resource_path.ends_with(suffix): return node
	for child: Node in node.get_children():
		var found := find_script(child, suffix)
		if found != null: return found
	return null

func boot(id: String) -> bool:
	var loaded: Dictionary = MapRelease.load_package(id)
	if not loaded.get("ok", false): print("E08P5_B2B_FAIL load ", loaded); return false
	report["entry"] = loaded.entry
	var candidate: Dictionary = Candidate.create("patrol", loaded.package, loaded.package.source_hash)
	var created: Dictionary = Launcher.create_session(candidate.candidate, "mage")
	var window: Dictionary = Launcher.create_window(created.path)
	var preview := PreviewApp.new()
	preview.quit_on_close = false
	root.add_child(preview)
	current_scene = preview
	var opened: Dictionary = preview.open_window(window.path)
	var started: Dictionary = preview.start() if opened.ok else opened
	if not started.get("ok", false): print("E08P5_B2B_FAIL start ", started); return false
	host = preview.host
	paused = true
	host.process_mode = Node.PROCESS_MODE_DISABLED
	host.route_camera.position_smoothing_enabled = false
	host.control_preferences.ui_scale = 1.2
	host._apply_interface_preferences()
	host._update_hud()
	view = host.expedition_view
	map_view = find_script(root, "map_package_view.gd")
	base_offset = host.route_camera.position
	return map_view != null and view != null

func frame(label: String, zoom: float, offset: Vector2) -> void:
	host.route_camera.position = offset
	host.route_camera.zoom = Vector2.ONE * zoom
	host.route_camera.force_update_scroll()
	view.sync()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(folder.path_join(label + ".png"))
	report["captures"].append({"label": label, "zoom": zoom, "offset": [offset.x, offset.y], "error": error})
	print("E08P5_B2B_CAPTURE ", label, " error=", error)

func set_ui_hidden(hidden: bool) -> void:
	for child: Node in host.get_children():
		if child is CanvasLayer: (child as CanvasLayer).visible = not hidden

func sprites_of(file_name: String) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for sprite: Sprite2D in map_view.object_sprites:
		if sprite.texture != null and sprite.texture.resource_path.ends_with(file_name): result.append(sprite)
	result.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.global_position.distance_to(host.player.global_position) < b.global_position.distance_to(host.player.global_position))
	return result

## Camera offset (relative to the player) that frames the sprite's foot and body.
func foot_offset(sprite: Sprite2D, lift: float) -> Vector2:
	return sprite.global_position - host.player.global_position - Vector2(0, lift)

func cliff_offset(node: Node) -> Variant:
	var best: Variant = null; var best_distance := INF
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child: Node in current.get_children(): stack.append(child)
		var mesh_node := current as MeshInstance2D
		if mesh_node == null or mesh_node.mesh == null: continue
		var material := mesh_node.material as ShaderMaterial
		if material == null or material.shader == null or not material.shader.resource_path.ends_with("terrain_material.gdshader"): continue
		var am := mesh_node.mesh as ArrayMesh
		if am == null or am.get_surface_count() == 0: continue
		var normals: Variant = am.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM1]
		if not normals is PackedFloat32Array or (normals as PackedFloat32Array).size() < 4 or (normals as PackedFloat32Array)[1] > 0.5: continue
		var box := am.get_aabb()
		if box.size.y < 40.0: continue
		var center := mesh_node.get_global_transform() * Vector2(box.get_center().x, box.get_center().y)
		var distance := center.distance_to(host.player.global_position)
		if distance > 60.0 and distance < best_distance: best_distance = distance; best = center - host.player.global_position
	return best

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	var id: String = args[1]
	if not boot(id): quit(1); return
	await process_frame
	var short := id.replace("forest_", "")
	var counts := {}
	for file_name: String in FILES: counts[file_name] = sprites_of(file_name).size()
	report["sprite_counts"] = counts
	report["renderer"] = RenderingServer.get_current_rendering_method()
	for zoom: float in ZOOMS: await frame("%s_spawn_z%d" % [short, int(zoom * 100)], zoom, base_offset)
	# Birch closest to an oak (mixed grove reading), at 160 and 100.
	var birches := sprites_of("birch_tree.png"); var oaks := sprites_of("oak_tree.png")
	var pair_offset: Variant = null; var best := INF
	for birch: Sprite2D in birches:
		for oak: Sprite2D in oaks:
			var distance := birch.global_position.distance_to(oak.global_position)
			if distance > 40.0 and distance < best: best = distance; pair_offset = (birch.global_position + oak.global_position) * 0.5 - host.player.global_position
	if pair_offset != null:
		report["birch_oak_pair_distance"] = best
		await frame("%s_birch_oak_z160" % short, 1.6, pair_offset - Vector2(0, 56))
		await frame("%s_birch_oak_z100" % short, 1.0, pair_offset - Vector2(0, 60))
	if not birches.is_empty(): await frame("%s_birch_nearest_z160" % short, 1.6, foot_offset(birches[0], 56))
	for file_name: String in ["fern_cluster.png", "wildflower_patch.png", "mushroom_ring.png", "fallen_log.png"]:
		var found := sprites_of(file_name)
		if found.is_empty(): continue
		var name := file_name.get_basename()
		await frame("%s_%s_z160" % [short, name], 1.6, foot_offset(found[0], 15))
		await frame("%s_%s_z100" % [short, name], 1.0, foot_offset(found[0], 15))
	var cliff: Variant = cliff_offset(map_view)
	if cliff != null: await frame("%s_cliff_z100" % short, 1.0, cliff)
	# Ground-contact views with the HUD hidden (the 120% HUD covers the lower half).
	set_ui_hidden(true)
	if pair_offset != null: await frame("%s_birch_oak_z160_noui" % short, 1.6, pair_offset - Vector2(0, 110))
	if not birches.is_empty():
		var birch: Sprite2D = birches[0]
		await frame("%s_birch_z160_noui" % short, 1.6, foot_offset(birch, 110))
		# Runtime-only comparison of the alternative pivot suggested by B2a (.977, height 228.5).
		var original_offset := birch.offset; var original_scale := birch.scale
		var texture_size := birch.texture.get_size()
		birch.scale = Vector2.ONE * 228.5 / texture_size.y
		birch.offset = -Vector2((1.0 - 0.515 if birch.flip_h else 0.515) * texture_size.x, 0.977 * texture_size.y)
		await frame("%s_birch_z160_noui_alt_pivot977" % short, 1.6, foot_offset(birch, 110))
		birch.offset = original_offset; birch.scale = original_scale
	if not oaks.is_empty(): await frame("%s_oak_z160_noui" % short, 1.6, foot_offset(oaks[0], 110))
	for file_name: String in ["fern_cluster.png", "wildflower_patch.png", "mushroom_ring.png", "fallen_log.png", "woodland_shrub.png"]:
		var found := sprites_of(file_name)
		if not found.is_empty(): await frame("%s_%s_z160_noui" % [short, file_name.get_basename()], 1.6, foot_offset(found[0], 0))
	await frame("%s_spawn_z50_noui" % short, 0.5, base_offset)
	set_ui_hidden(false)
	var file := FileAccess.open(folder.path_join("report_%s.json" % short), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("E08P5_B2B_PROBE_DONE ", JSON.stringify(report["sprite_counts"]))
	quit(0)
