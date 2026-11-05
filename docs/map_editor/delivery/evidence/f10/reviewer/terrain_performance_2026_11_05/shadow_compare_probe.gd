extends SceneTree
const Shadow = preload("res://scripts/world/ground_shadow.gd")
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Patch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const Project = preload("res://scripts/world/expedition_projection.gd")
class ShadowCanvas extends Node2D:
	const S = preload("res://scripts/world/ground_shadow.gd")
	const P = preload("res://scripts/world/expedition_projection.gd")
	var anchor := Vector3.ZERO
	var radii := Vector2(12.96,12.96)
	var index := {}
	var epoch: Array = []
	var reference := false
	var cache := {}
	var reference_mesh: ArrayMesh
	func _draw() -> void:
		if reference:
			var data := S.mesh_data(anchor,radii,index,"floor",P.project)
			if data.ok:
				reference_mesh = S.mesh(data); draw_mesh(reference_mesh,S.texture())
		else: S.draw_on(self,anchor,radii,index,"floor",P.project,cache,epoch)
func _initialize() -> void: run.call_deferred()
func make_index(heights: Array, offset: float = 0.0) -> Dictionary:
	var grid := {"origin_xz":[offset,offset],"sample_spacing":64.0,"columns":3,"rows":3,"heights":heights}
	return Patch.index({"surfaces":[{"surface_id":"floor","vertices":Grid.corners(Grid.view(grid)),"height_grid":grid,"headroom":200.0}],"connectors":[],"connections":[]})
func run() -> void:
	root.size = Vector2i(600,300)
	var views: Array[SubViewport] = []; var canvases: Array[ShadowCanvas] = []
	for i: int in 2:
		var viewport := SubViewport.new(); viewport.size = Vector2i(256,256); viewport.transparent_bg = true; viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport); views.append(viewport)
		var canvas := ShadowCanvas.new(); canvas.position = Vector2(128,128); canvas.scale = Vector2.ONE*4.0; canvas.reference = i == 0; canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		viewport.add_child(canvas); canvases.append(canvas)
	var flat := make_index([0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0])
	var slope := make_index([0.0,16.0,32.0,0.0,16.0,32.0,0.0,16.0,32.0])
	var high := make_index([0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0],9024.0)
	var cases: Array = [
		{"id":"flat","point":Vector3(32,0,32),"index":flat,"epoch":[1]},
		{"id":"moving_flat","point":Vector3(34,0,36),"index":flat,"epoch":[1]},
		{"id":"outer_edge","point":Vector3(2,0,32),"index":flat,"epoch":[1]},
		{"id":"quad_seam","point":Vector3(64,0,32),"index":flat,"epoch":[1]},
		{"id":"ramp","point":Vector3(32,8,32),"index":slope,"epoch":[2]},
		{"id":"large_world_coordinates","point":Vector3(9056,0,9056),"index":high,"epoch":[3]}]
	var checks: Array = []
	for item: Dictionary in cases:
		for canvas: ShadowCanvas in canvases:
			canvas.anchor = item.point; canvas.index = item.index; canvas.epoch = item.epoch; canvas.queue_redraw()
		await process_frame; await process_frame; await RenderingServer.frame_post_draw
		var a := views[0].get_texture().get_image(); var b := views[1].get_texture().get_image()
		a.convert(Image.FORMAT_RGBA8); b.convert(Image.FORMAT_RGBA8)
		var av := a.get_data(); var bv := b.get_data(); var largest := 0; var changed := 0
		for i: int in av.size():
			var delta := absi(int(av[i])-int(bv[i])); largest = maxi(largest,delta)
			if delta > 0: changed += 1
		var visible := 0; var max_alpha := 0
		for i: int in range(3,av.size(),4):
			max_alpha = maxi(max_alpha,int(av[i]))
			if av[i] > 0: visible += 1
		var ok := largest <= 2 and visible > 100 and max_alpha > 0 and max_alpha < 250
		checks.append({"id":item.id,"ok":ok,"max_channel_delta":largest,"different_bytes":changed,"visible_shadow_pixels":visible,"max_alpha":max_alpha})
		print("SHADOW_COMPARE_CHECK ",JSON.stringify(checks[-1]))
		if item.id == "moving_flat":
			var folder := OS.get_environment("TERRAIN_EVIDENCE")
			a.save_png(folder.path_join("reference_shadow.png")); b.save_png(folder.path_join("cached_shadow.png"))
	var ok: bool = checks.all(func(c: Dictionary) -> bool: return c.ok)
	print("SHADOW_COMPARE_RESULT ",JSON.stringify({"ok":ok,"checks":checks,"count":checks.size()})); quit(0 if ok else 1)
