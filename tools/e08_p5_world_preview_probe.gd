extends SceneTree
## E08 P5 B2a read-only world preview (non-headless). Boots a published forest map in the
## real renderer and swaps materials / prop textures ONLY at runtime in this process.
## Usage: --script res://tools/e08_p5_world_preview_probe.gd -- {output} [package_id] [full|lite]
##        --script ... -- {output} mosaic {spec.json}
const MapRelease = preload("res://scripts/map_authoring/release/map_release.gd")
const PreviewApp = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const STAGING := "res://assets/art/e08_world/staging/"
const MATERIAL_FILES := {"grass": "materials/grass_tile.png", "earth": "materials/earth_tile.png", "sand": "materials/sand_tile.png", "stone": "materials/stone_tile.png"}
const PROP_FILES := {"birch_tree": "props/birch_tree.png", "fallen_log": "props/fallen_log.png", "fern_cluster": "props/fern_cluster.png", "mushroom_ring": "props/mushroom_ring.png", "wildflower_patch": "props/wildflower_patch.png"}
const SHRUB_PIVOT := Vector2(0.49, 0.91)
const SHRUB_HEIGHT := 46.0
const OAK_PIVOT := Vector2(0.53, 0.94)
const OAK_HEIGHT := 226.0
const ZOOMS: Array[float] = [0.5, 1.0, 1.6]

var folder := ""
var package_id := "forest_terraces"
var full := true
var host: RunController
var view: ExpeditionGeometryView
var map_view: Node2D
var app: Node
var records: Array[Dictionary] = []
var old_tex := {}
var new_tex := {}
var prop_tex := {}
var prop_metrics := {}
var cache := {}
var report := {"captures": {}}
var base_offset := Vector2.ZERO

func _initialize() -> void: _run.call_deferred()

func shot(label: String) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var error := image.save_png(folder.path_join(label + ".png"))
	print("E08P5_CAPTURE ", label, " error=", error)
	report["captures"][label] = frame_stats(image)
	return image

func frame_stats(image: Image) -> Dictionary:
	var r := 0.0; var g := 0.0; var b := 0.0; var sat := 0.0; var n := 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var c := image.get_pixel(x, y)
			r += c.r; g += c.g; b += c.b; sat += c.s; n += 1
	var fn := float(maxi(n, 1))
	return {"mean_rgb": [snappedf(r / fn, 0.001), snappedf(g / fn, 0.001), snappedf(b / fn, 0.001)], "mean_saturation": snappedf(sat / fn, 0.001), "mean_luma": snappedf(0.299 * r / fn + 0.587 * g / fn + 0.114 * b / fn, 0.001)}

func frame(label: String, zoom: float, offset: Vector2) -> Image:
	host.route_camera.position = offset
	host.route_camera.zoom = Vector2.ONE * zoom
	host.route_camera.force_update_scroll()
	view.sync()
	var image: Image = await shot(label)
	return image

# ---------------------------------------------------------------- boot
func find_script(node: Node, suffix: String) -> Node:
	var script: Script = node.get_script()
	if script != null and script.resource_path.ends_with(suffix): return node
	for child: Node in node.get_children():
		var found := find_script(child, suffix)
		if found != null: return found
	return null

func boot(id: String) -> bool:
	var loaded: Dictionary = MapRelease.load_package(id)
	if not loaded.get("ok", false): print("E08P5_FAIL load ", loaded); return false
	var candidate: Dictionary = Candidate.create("patrol", loaded.package, loaded.package.source_hash)
	var created: Dictionary = Launcher.create_session(candidate.candidate, "mage")
	var window: Dictionary = Launcher.create_window(created.path)
	var preview := PreviewApp.new()
	preview.quit_on_close = false
	root.add_child(preview)
	current_scene = preview
	app = preview
	var opened: Dictionary = preview.open_window(window.path)
	var started: Dictionary = preview.start() if opened.ok else opened
	if not started.get("ok", false): print("E08P5_FAIL start ", started); return false
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

# ---------------------------------------------------------------- textures
func load_tex(path: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty(): return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func texture_stats(image: Image) -> Dictionary:
	var w := image.get_width(); var h := image.get_height()
	var r := 0.0; var g := 0.0; var b := 0.0; var sat := 0.0; var l2 := 0.0; var l1 := 0.0; var n := 0
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := image.get_pixel(x, y)
			var l := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			r += c.r; g += c.g; b += c.b; sat += c.s; l1 += l; l2 += l * l; n += 1
	var fn := float(n)
	var mean := l1 / fn
	var grad := 0.0; var gn := 0
	for y in range(0, h - 1, 3):
		for x in range(0, w - 1, 3):
			var a := image.get_pixel(x, y); var c := image.get_pixel(x + 1, y)
			grad += absf(a.get_luminance() - c.get_luminance()); gn += 1
	var seam_h := 0.0; var seam_v := 0.0
	for y in range(0, h, 3): seam_h += absf(image.get_pixel(0, y).get_luminance() - image.get_pixel(w - 1, y).get_luminance())
	for x in range(0, w, 3): seam_v += absf(image.get_pixel(x, 0).get_luminance() - image.get_pixel(x, h - 1).get_luminance())
	var seam_h_n := float(ceili(float(h) / 3.0)); var seam_v_n := float(ceili(float(w) / 3.0))
	return {"size": [w, h], "mean_rgb": [snappedf(r / fn, 0.001), snappedf(g / fn, 0.001), snappedf(b / fn, 0.001)], "mean_rgb_255": [roundi(r / fn * 255.0), roundi(g / fn * 255.0), roundi(b / fn * 255.0)], "mean_saturation": snappedf(sat / fn, 0.001), "mean_luma": snappedf(mean, 0.001), "luma_std": snappedf(sqrt(maxf(0.0, l2 / fn - mean * mean)), 0.001), "mean_neighbor_luma_diff": snappedf(grad / float(maxi(gn, 1)), 0.0001), "edge_wrap_diff_lr": snappedf(seam_h / seam_h_n, 0.0001), "edge_wrap_diff_tb": snappedf(seam_v / seam_v_n, 0.0001)}

func load_textures() -> bool:
	for k: int in Materials.IDS.size():
		var id: String = Materials.IDS[k]
		old_tex[id] = load(Materials.PATHS[k])
		new_tex[id] = load_tex(STAGING + String(MATERIAL_FILES[id]))
		if new_tex[id] == null or old_tex[id] == null: print("E08P5_FAIL texture ", id); return false
	for id: String in PROP_FILES:
		prop_tex[id] = load_tex(STAGING + String(PROP_FILES[id]))
		if prop_tex[id] == null: print("E08P5_FAIL prop ", id); return false
	var stats := {}
	for id: String in old_tex:
		var old_image: Image = (old_tex[id] as Texture2D).get_image()
		var new_image: Image = (new_tex[id] as Texture2D).get_image()
		stats[id] = {"old": texture_stats(old_image), "new": texture_stats(new_image)}
	report["texture_stats"] = stats
	return true

# ---------------------------------------------------------------- material swap
func mean_normal_y(mesh: Mesh) -> float:
	var am := mesh as ArrayMesh
	if am == null or am.get_surface_count() == 0: return 1.0
	var arrays: Array = am.surface_get_arrays(0)
	var values: Variant = arrays[Mesh.ARRAY_CUSTOM1]
	if not values is PackedFloat32Array: return 1.0
	var data: PackedFloat32Array = values
	var count := mini(int(data.size() / 4.0), 64)
	if count == 0: return 1.0
	var sum := 0.0
	for i: int in count: sum += data[i * 4 + 1]
	return sum / float(count)

func collect(node: Node) -> void:
	for child: Node in node.get_children():
		var mesh_node := child as MeshInstance2D
		if mesh_node != null:
			var material := mesh_node.material as ShaderMaterial
			if material != null and material.shader != null and not material.shader.resource_path.ends_with("water_material.gdshader"):
				var kind := "top"
				if mesh_node.has_meta("border_face_id"): kind = "border"
				elif mean_normal_y(mesh_node.mesh) < 0.5: kind = "face"
				records.append({"node": mesh_node, "orig": material, "kind": kind})
		collect(child)

func spec_all(kind: String) -> Dictionary:
	var result := {}
	for id: String in Materials.IDS: result[id] = [kind, id]
	return result

func floor_spec(kind: String, source: String, with_stone: bool) -> Dictionary:
	var result := {"grass": [kind, source], "earth": [kind, source], "sand": [kind, source]}
	if with_stone: result["stone"] = [kind, source]
	return result

func variant_spec(name: String) -> Dictionary:
	match name:
		"new_all": return {"top": spec_all("new"), "face": spec_all("new")}
		"new_grass_sand": return {"top": {"grass": ["new", "grass"], "sand": ["new", "sand"]}, "face": {"grass": ["new", "grass"], "sand": ["new", "sand"]}}
		"new_earth": return {"top": {"earth": ["new", "earth"]}, "face": {"earth": ["new", "earth"]}}
		"new_stone_top": return {"top": {"stone": ["new", "stone"]}, "face": {}}
		"new_stone_all": return {"top": {"stone": ["new", "stone"]}, "face": {"stone": ["new", "stone"]}}
		"floor_earth_old": return {"top": floor_spec("old", "earth", false), "face": {}}
		"floor_earth_new": return {"top": floor_spec("new", "earth", false), "face": {}}
		"floor_stone_old": return {"top": floor_spec("old", "stone", true), "face": {}}
		"floor_stone_new": return {"top": floor_spec("new", "stone", true), "face": {}}
	return {}

func apply_variant(name: String) -> void:
	var spec := variant_spec(name)
	for record: Dictionary in records:
		var node: MeshInstance2D = record["node"]
		var orig: ShaderMaterial = record["orig"]
		var side := "top" if record["kind"] == "top" else "face"
		var overrides: Dictionary = spec.get(side, {})
		if overrides.is_empty():
			node.material = orig
			continue
		var key := "%s|%s|%s" % [orig.shader.resource_path, name, side]
		if not cache.has(key):
			var copy := orig.duplicate() as ShaderMaterial
			for id: String in overrides:
				var pair: Array = overrides[id]
				var source: Dictionary = new_tex if pair[0] == "new" else old_tex
				copy.set_shader_parameter(id + "_tile", source[pair[1]])
			cache[key] = copy
		node.material = cache[key]

# ---------------------------------------------------------------- camera helpers
func cliff_offset() -> Variant:
	var best: Variant = null
	var best_distance := INF
	for record: Dictionary in records:
		if record["kind"] == "top": continue
		var node: MeshInstance2D = record["node"]
		var box := node.mesh.get_aabb()
		if box.size.y < 40.0: continue
		var center := node.get_global_transform() * Vector2(box.get_center().x, box.get_center().y)
		var distance := center.distance_to(host.player.global_position)
		if distance < 60.0: continue
		if distance < best_distance: best_distance = distance; best = center - host.player.global_position
	return best

func set_ui_hidden(hidden: bool) -> void:
	for child: Node in host.get_children():
		if child is CanvasLayer: (child as CanvasLayer).visible = not hidden

# ---------------------------------------------------------------- indicators
func lum(c: Color) -> float:
	var l := c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b

func contrast_one(ground: Image, rect: Rect2i, indicator: Color) -> Dictionary:
	var li := lum(indicator)
	var ratios := PackedFloat32Array()
	var dluma := 0.0; var dist := 0.0; var gl := 0.0; var low := 0
	var il := indicator.get_luminance()
	for y in range(rect.position.y, rect.end.y, 2):
		for x in range(rect.position.x, rect.end.x, 2):
			var c := ground.get_pixel(x, y)
			var lg := lum(c)
			var ratio := (maxf(li, lg) + 0.05) / (minf(li, lg) + 0.05)
			ratios.append(ratio)
			if ratio < 1.5: low += 1
			dluma += absf(il - c.get_luminance())
			gl += c.get_luminance()
			dist += Vector3(c.r - indicator.r, c.g - indicator.g, c.b - indicator.b).length()
	ratios.sort()
	var n := float(maxi(ratios.size(), 1))
	return {"samples": ratios.size(), "ground_mean_luma": snappedf(gl / n, 0.001), "indicator_luma": snappedf(il, 0.001), "mean_abs_luma_diff": snappedf(dluma / n, 0.001), "mean_rgb_distance": snappedf(dist / n, 0.001), "wcag_ratio_mean": snappedf(float(ratios[ratios.size() / 2]) if ratios.size() > 0 else 0.0, 0.01), "wcag_ratio_p05": snappedf(float(ratios[int(float(ratios.size()) * 0.05)]) if ratios.size() > 0 else 0.0, 0.01), "fraction_ratio_below_1_5": snappedf(float(low) / n, 0.001)}

func indicator_section() -> void:
	var results := {}
	var wp: ExpeditionWorldPoint = host.player.world_point()
	var base: Vector3 = wp.position
	var target := base + Vector3(90, 0, 0)
	var target_point := ExpeditionWorldPoint.create(wp.stage_id, wp.surface_id, target)
	var preview_to := base + Vector3(0, 0, -110)
	var screen_points: Array[Vector2] = []
	host.route_camera.position = base_offset
	host.route_camera.zoom = Vector2.ONE
	host.route_camera.force_update_scroll()
	var to_screen := view.get_global_transform_with_canvas()
	for point: Vector3 in [base, target, preview_to]: screen_points.append(to_screen * ExpeditionGeometryView.project(point))
	var area := Rect2(screen_points[0], Vector2.ZERO)
	for p: Vector2 in screen_points: area = area.expand(p)
	area = area.grow(34.0)
	var rect := Rect2i(area).intersection(Rect2i(0, 0, 1280, 720))
	results["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	host.player.visible = false
	for enemy: EnemyActor in host.enemies: enemy.visible = false
	for name: String in ["old", "floor_earth_old", "floor_earth_new", "floor_stone_old", "floor_stone_new", "new_all"]:
		apply_variant(name)
		var short := name.replace("floor_", "floor_")
		view.indicate(null, false, [])
		view.attack_preview = {}
		var ground: Image = await frame("ind_%s_ground" % short, 1.0, base_offset)
		view.indicate(target_point, false, [{"position": base}, {"position": target}])
		view.attack_preview = {"from": base, "to": preview_to, "valid": false}
		await frame("ind_%s_danger" % short, 1.0, base_offset)
		results[name] = {"danger_ff807d": contrast_one(ground, rect, Color("ff807d")), "valid_79e5ba": contrast_one(ground, rect, Color("79e5ba"))}
		if name in ["floor_earth_old", "floor_earth_new", "floor_stone_old", "floor_stone_new"]:
			view.indicate(target_point, true, [{"position": base}, {"position": target}])
			view.attack_preview = {"from": base, "to": preview_to, "valid": true}
			await frame("ind_%s_valid" % short, 1.0, base_offset)
	view.indicate(null, false, [])
	view.attack_preview = {}
	host.player.visible = true
	for enemy: EnemyActor in host.enemies: enemy.visible = true
	apply_variant("old")
	report["indicators"] = results

# ---------------------------------------------------------------- props
func prop_info(image: Image) -> Dictionary:
	var w := image.get_width(); var h := image.get_height()
	var x0 := w; var y0 := h; var x1 := 0; var y1 := 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			if image.get_pixel(x, y).a > 0.25:
				x0 = mini(x0, x); x1 = maxi(x1, x); y0 = mini(y0, y); y1 = maxi(y1, y)
	var band_top := y1 - maxi(2, int(float(y1 - y0) * 0.04))
	var sum := 0.0; var count := 0
	for y in range(band_top, y1 + 1):
		for x in range(x0, x1 + 1, 2):
			if image.get_pixel(x, y).a > 0.25: sum += float(x); count += 1
	var cx := sum / float(count) if count > 0 else float(x0 + x1) / 2.0
	return {"size": [w, h], "bbox": [x0, y0, x1, y1], "bbox_w": x1 - x0, "bbox_h": y1 - y0, "base_centroid_x_uv": snappedf(cx / float(w), 0.001), "bottom_uv": snappedf(float(y1) / float(h), 0.001)}

func fit_pivot(id: String) -> Vector2:
	var info: Dictionary = prop_metrics[id]
	return Vector2(float(info["base_centroid_x_uv"]), float(info["bottom_uv"]) - 0.03)

func set_prop(sprite: Sprite2D, texture: Texture2D, pivot: Vector2, world_height: float) -> void:
	sprite.texture = texture
	sprite.scale = Vector2.ONE * world_height / float(texture.get_height())
	sprite.offset = -Vector2(pivot.x * texture.get_width(), pivot.y * texture.get_height())
	if sprite.flip_h: sprite.offset.x = -(1.0 - pivot.x) * texture.get_width()

func sprites_of(file_name: String) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	for sprite: Sprite2D in map_view.object_sprites:
		if sprite.texture != null and sprite.texture.resource_path.ends_with(file_name): result.append(sprite)
	result.sort_custom(func(a: Sprite2D, b: Sprite2D) -> bool: return a.global_position.distance_to(host.player.global_position) < b.global_position.distance_to(host.player.global_position))
	return result

func sprite_center_offset(sprite: Sprite2D) -> Vector2:
	var center := sprite.to_global(sprite.offset + sprite.texture.get_size() * 0.5)
	return center - host.player.global_position

func prop_variants() -> Dictionary:
	# name -> [texture id, pivot, world_height]; decorative ones keep the shrub pivot/height
	# (contract), the log keeps the shrub pixel scale with a pivot fitted from its alpha.
	var log_height := SHRUB_HEIGHT * 724.0 / 1024.0
	return {"fern": ["fern_cluster", SHRUB_PIVOT, SHRUB_HEIGHT], "mushroom": ["mushroom_ring", SHRUB_PIVOT, SHRUB_HEIGHT], "flower": ["wildflower_patch", SHRUB_PIVOT, SHRUB_HEIGHT], "log": ["fallen_log", fit_pivot("fallen_log"), log_height]}

func props_section() -> void:
	var results := {}
	var oak_image: Image = (load("res://assets/art/map_authoring/props/oak_tree.png") as Texture2D).get_image()
	var shrub_image: Image = (load("res://assets/art/map_authoring/props/woodland_shrub.png") as Texture2D).get_image()
	prop_metrics["oak_tree"] = prop_info(oak_image)
	prop_metrics["woodland_shrub"] = prop_info(shrub_image)
	for id: String in PROP_FILES: prop_metrics[id] = prop_info((prop_tex[id] as Texture2D).get_image())
	results["metrics"] = prop_metrics
	var variants := prop_variants()
	var shrubs := sprites_of("woodland_shrub.png")
	results["shrub_count"] = shrubs.size()
	for index: int in mini(2, shrubs.size()):
		var sprite := shrubs[index]
		var original_texture := sprite.texture; var original_offset := sprite.offset; var original_scale := sprite.scale
		var offset := sprite_center_offset(sprite)
		await frame("prop_shrub%d_old_z160" % index, 1.6, offset)
		for name: String in variants:
			var spec: Array = variants[name]
			set_prop(sprite, prop_tex[spec[0]], spec[1], spec[2])
			await frame("prop_shrub%d_%s_z160" % [index, name], 1.6, offset)
			if index == 0:
				await frame("prop_shrub0_%s_z100" % name, 1.0, offset)
		sprite.texture = original_texture; sprite.offset = original_offset; sprite.scale = original_scale
		if index == 0: await frame("prop_shrub0_old_z100", 1.0, offset)
	var oaks := sprites_of("oak_tree.png")
	results["oak_count"] = oaks.size()
	if not oaks.is_empty():
		var oak := oaks[0]
		var oak_texture := oak.texture; var oak_offset := oak.offset; var oak_scale := oak.scale
		var offset := sprite_center_offset(oak)
		var info: Dictionary = prop_metrics["oak_tree"]
		var birch: Dictionary = prop_metrics["birch_tree"]
		var fit_height := OAK_HEIGHT * float(info["bbox_h"]) / float(oak_texture.get_height()) / (float(birch["bbox_h"]) / float(prop_tex["birch_tree"].get_height()))
		await frame("prop_oak_old_z100", 1.0, offset)
		set_prop(oak, prop_tex["birch_tree"], OAK_PIVOT, OAK_HEIGHT)
		await frame("prop_birch_contract_z100", 1.0, offset)
		set_prop(oak, prop_tex["birch_tree"], fit_pivot("birch_tree"), fit_height)
		await frame("prop_birch_fit_z100", 1.0, offset)
		results["birch_fit_world_height"] = fit_height
		oak.texture = oak_texture; oak.offset = oak_offset; oak.scale = oak_scale
		# every oak -> birch (contract pivot/height): stand-level read
		var saved: Array = []
		for sprite: Sprite2D in oaks:
			saved.append([sprite, sprite.texture, sprite.offset, sprite.scale])
			set_prop(sprite, prop_tex["birch_tree"], OAK_PIVOT, OAK_HEIGHT)
		for zoom: float in [0.5, 1.0]:
			await frame("prop_allbirch_z%d" % int(zoom * 100), zoom, base_offset)
		for entry: Array in saved:
			var sprite: Sprite2D = entry[0]
			sprite.texture = entry[1]; sprite.offset = entry[2]; sprite.scale = entry[3]
		for zoom: float in [0.5, 1.0]:
			await frame("prop_alloak_z%d" % int(zoom * 100), zoom, base_offset)
	# lineup beside the player for scale
	var wp: ExpeditionWorldPoint = host.player.world_point()
	var p1 := ExpeditionGeometryView.project(Vector3(1, 0, 0)); var p2 := ExpeditionGeometryView.project(Vector3(0, 0, 1))
	var det := p1.x * p2.y - p2.x * p1.y
	var clones: Array[Sprite2D] = []
	var rows := [[Vector2(-330, 100), "woodland_shrub", null], [Vector2(-165, 100), "fern", null], [Vector2(0, 100), "mushroom", null], [Vector2(165, 100), "flower", null], [Vector2(330, 100), "log", null], [Vector2(-200, -80), "oak_tree", null], [Vector2(200, -80), "birch", null]]
	for row: Array in rows:
		var screen: Vector2 = row[0]
		var a := (screen.x * p2.y - p2.x * screen.y) / det
		var b := (p1.x * screen.y - screen.x * p1.y) / det
		var clone := Sprite2D.new()
		clone.centered = false
		clone.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var name: String = row[1]
		if name == "woodland_shrub": set_prop(clone, load("res://assets/art/map_authoring/props/woodland_shrub.png"), SHRUB_PIVOT, SHRUB_HEIGHT)
		elif name == "oak_tree": set_prop(clone, load("res://assets/art/map_authoring/props/oak_tree.png"), OAK_PIVOT, OAK_HEIGHT)
		elif name == "birch": set_prop(clone, prop_tex["birch_tree"], OAK_PIVOT, OAK_HEIGHT)
		else:
			var spec: Array = variants[name]
			set_prop(clone, prop_tex[spec[0]], spec[1], spec[2])
		clone.position = ExpeditionGeometryView.project(wp.position + Vector3(a, 0, b))
		clone.z_index = host.player.z_index + (1 if screen.y > 0 else -1)
		map_view.add_child(clone); clones.append(clone)
	for zoom: float in [1.0, 1.6]:
		await frame("prop_lineup_z%d" % int(zoom * 100), zoom, base_offset)
	for clone: Sprite2D in clones: clone.free()
	report["props"] = results

# ---------------------------------------------------------------- shimmer
func shimmer_one(variant: String) -> Dictionary:
	apply_variant(variant)
	host.route_camera.zoom = Vector2.ONE * 0.5
	var frames: Array[PackedByteArray] = []
	var size := Vector2i.ZERO
	for k: int in 8:
		host.route_camera.position = base_offset + Vector2(float(k), 0.0)  # 1 canvas px = 0.5 screen px at zoom 0.5
		host.route_camera.force_update_scroll()
		view.sync()
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if k == 0 or k == 7: image.save_png(folder.path_join("shimmer_%s_f%d.png" % [variant, k]))
		image.convert(Image.FORMAT_L8)
		size = image.get_size()
		frames.append(image.get_data())
	var x0 := 320; var x1 := 960; var y0 := 180; var y1 := 540
	var variance_sum := 0.0; var residual_sum := 0.0; var grad_sum := 0.0; var n := 0
	for y in range(y0, y1):
		var row := y * size.x
		for x in range(x0, x1):
			var mean := 0.0
			for k: int in 8: mean += float(frames[k][row + x])
			mean /= 8.0
			var v := 0.0
			for k: int in 8:
				var d := float(frames[k][row + x]) - mean
				v += d * d
			variance_sum += v / 8.0
			for k: int in 7: residual_sum += absf(float(frames[k + 1][row + x]) - (float(frames[k][row + x]) + float(frames[k][row + x + 1])) * 0.5)
			grad_sum += absf(float(frames[0][row + x + 1]) - float(frames[0][row + x]))
			n += 1
	var fn := float(n)
	return {"temporal_variance_mean": snappedf(variance_sum / fn, 0.01), "half_pixel_interp_residual_mean": snappedf(residual_sum / (fn * 7.0), 0.001), "static_horizontal_gradient_mean": snappedf(grad_sum / fn, 0.001), "region": [x0, y0, x1 - x0, y1 - y0], "frames": 8, "pan": "0.5 screen px per frame at zoom 0.5"}

func shimmer_section() -> void:
	set_ui_hidden(true)
	host.player.visible = false
	var results := {}
	for variant: String in ["old", "new_all", "old", "new_all"]:
		var tag := variant + ("_rep" if results.has(variant) else "")
		results[tag] = await shimmer_one(variant)
	host.player.visible = true
	set_ui_hidden(false)
	apply_variant("old")
	report["shimmer"] = results

# ---------------------------------------------------------------- mosaic
func mosaic(spec_path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(spec_path))
	if not parsed is Dictionary: print("E08P5_FAIL spec"); quit(1); return
	var spec: Dictionary = parsed
	var columns: Array = spec["columns"]
	var cell := Vector2i(int(spec["cell"][0]), int(spec["cell"][1]))
	root.size = Vector2i(cell.x * columns.size(), cell.y * 2)
	var background := ColorRect.new(); background.color = Color(0.06, 0.06, 0.07); background.size = Vector2(root.size); root.add_child(background)
	for index: int in columns.size():
		var column: Dictionary = columns[index]
		for row: int in 2:
			var key := "old" if row == 0 else "new"
			var image := Image.load_from_file(String(column[key]))
			if image == null or image.is_empty(): print("E08P5_FAIL image ", column[key]); quit(1); return
			var texture: Texture2D = ImageTexture.create_from_image(image)
			if column.has("crop"):
				var crop: Array = column["crop"]
				var atlas := AtlasTexture.new(); atlas.atlas = texture; atlas.region = Rect2(crop[0], crop[1], crop[2], crop[3]); texture = atlas
			var rect := TextureRect.new(); rect.texture = texture
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; rect.stretch_mode = TextureRect.STRETCH_SCALE
			rect.position = Vector2(index * cell.x + 1, row * cell.y + 1); rect.size = Vector2(cell.x - 2, cell.y - 2)
			root.add_child(rect)
			var shade := ColorRect.new(); shade.color = Color(0, 0, 0, 0.62); shade.position = rect.position; shade.size = Vector2(minf(float(cell.x - 2), 12.0 + 8.2 * float(String(column["title"]).length() + 8)), 20)
			root.add_child(shade)
			var label := Label.new(); label.text = ("ANTIGO · " if row == 0 else "NOVO · ") + String(column["title"])
			label.position = rect.position + Vector2(5, 0); label.add_theme_font_size_override("font_size", 13)
			root.add_child(label)
	await process_frame
	var out := String(spec.get("out", "mosaic"))
	await shot(out)
	quit()

# ---------------------------------------------------------------- main
func _run() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	folder = args[0]
	var mode: String = args[1] if args.size() > 1 else "forest_terraces"
	if mode == "mosaic":
		await mosaic(args[2]); return
	package_id = mode
	full = (args[2] if args.size() > 2 else "full") == "full"
	if not boot(package_id) or not load_textures():
		print("E08P5_FAIL boot"); quit(1); return
	await process_frame
	collect(map_view)
	var counts := {"top": 0, "face": 0, "border": 0}
	for record: Dictionary in records: counts[record["kind"]] = int(counts[record["kind"]]) + 1
	report["package"] = package_id; report["mode"] = "full" if full else "lite"
	report["mesh_nodes_by_class"] = counts
	report["renderer"] = RenderingServer.get_current_rendering_method()
	report["camera_base_offset"] = str(base_offset)
	report["viewport"] = [root.size.x, root.size.y]; report["ui_scale"] = 1.2
	var short := package_id.replace("forest_", "")
	# a) old vs new at 50/100/160 (same camera)
	for variant: String in ["old", "new_all"]:
		apply_variant(variant)
		for zoom: float in ZOOMS: await frame("%s_%s_z%d" % [short, variant, int(zoom * 100)], zoom, base_offset)
	# b) isolated variants
	for variant: String in ["new_grass_sand", "new_earth", "new_stone_top", "new_stone_all"]:
		apply_variant(variant)
		await frame("%s_%s_z100" % [short, variant], 1.0, base_offset)
	# cliff / border view (stone-vs-cliff evidence)
	var cliff: Variant = cliff_offset()
	report["cliff_view_found"] = cliff != null
	if cliff != null:
		for variant: String in ["old", "new_all", "new_stone_top", "new_earth", "new_grass_sand"]:
			apply_variant(variant)
			await frame("%s_cliff_%s_z100" % [short, variant], 1.0, cliff)
	apply_variant("old")
	if full:
		await indicator_section()
		await props_section()
		await shimmer_section()
	var file := FileAccess.open(folder.path_join("preview_%s.json" % package_id), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ", true)); file.close()
	print("E08P5_DONE ", package_id)
	paused = false
	await app.suspend()
	quit()
