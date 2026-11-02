extends SceneTree
## F10 H5 (contracts/f10_height_grid.md): a height-grid map drawn per stretch in
## the shared game/editor view and in the editor's terrain canvas. Drawn
## vertices are the exact support (also after a half turn), sprites are ordered
## against that support, the canvas renderer culls what the camera does not
## see, and AX switches a layer's surface mode.
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const Grid = preload("res://scripts/map_authoring/compiler/grid_piece.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const PackageView = preload("res://scripts/world/map_package_view.gd")
const CanvasOrder = preload("res://scripts/world/world_canvas_order.gd")
const TerrainCanvas = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
const Operations = preload("res://scripts/map_authoring/terrain/terrain_operations.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_GRID_VIEW_CHECK "+id+" "+str(ok))
func frames(count: int = 2) -> void:
	for i: int in count: await process_frame
func height(gx: int, gz: int) -> float:
	return snappedf(14.0*sin(float(gx)*0.21)+9.0*cos(float(gz)*0.17)+(30.0 if (gx/12+gz/12)%2 == 0 else 0.0)*0.0,0.25)
func field(id: String, columns: int) -> Dictionary:
	var source := Piece.empty(id,"Campo desenhado")
	var heights: Array = []; var grass: Array = []; var earth: Array = []
	for z: int in columns:
		for x: int in columns:
			heights.append(height(x,z)); grass.append(1.0 if (x+z)%7 != 0 else 0.3); earth.append(0.0 if (x+z)%7 != 0 else 0.7)
	source.layers = [{"layer_id":"ground","name":"Campo","origin_xz":[0,0],"sample_spacing":64,"columns":columns,"rows":columns,"heights":heights,"material_masks":{"grass":grass,"earth":earth},"locked":false,"protected_regions":[],"surface_mode":"height_grid"}]
	return source
func map_of(source: Dictionary, quarter: int) -> Dictionary:
	var data := MapDocument.empty("grid_view"); data.name = "Campo desenhado"
	var digest := Schema.semantic_hash(source)
	data.pieces = [{"piece_hash":digest,"source":source}]
	data.instances = [{"instance_id":"field","piece_hash":digest,"position_xyz":[0,0,0],"rotation_quarters":quarter}]
	return data
func stretch_meshes(root: Node) -> Array[MeshInstance2D]:
	var result: Array[MeshInstance2D] = []
	for child: Node in root.get_children():
		if child is MeshInstance2D and child.has_meta("grid_stretch"): result.append(child)
	return result
## Every drawn vertex lies on the stretch support of its own mesh.
func vertices_on_support(meshes: Array[MeshInstance2D]) -> bool:
	for mesh: MeshInstance2D in meshes:
		var view := HeightGrid.view(mesh.get_meta("canvas_order_cap_grid"))
		var values: PackedFloat32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
		for i: int in range(0,values.size(),4):
			var y := HeightGrid.support_y(view,values[i],values[i+2])
			if is_nan(y) or absf(y-values[i+1]) > 0.01: return false
	return true
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	root.size = Vector2i(1280,720)
	var piece := field("grid_view_piece",97)
	var compiled := MapCompiler.compile(map_of(piece,0))
	check("map_compiles",compiled.ok)
	if not compiled.ok: print("F10_GRID_VIEW_CODE "+str(compiled.code)); finish(); return
	# 1. The shared view draws one mesh per stretch, on the exact support.
	var view := PackageView.new(); root.add_child(view)
	var started := Time.get_ticks_usec()
	var configured: Dictionary = view.configure(compiled.package)
	var build_ms := (Time.get_ticks_usec()-started)/1000.0
	var meshes := stretch_meshes(view)
	check("one_mesh_per_stretch",configured.ok and meshes.size() == 36)
	check("drawn_vertices_are_the_support",vertices_on_support(meshes))
	var sides := 0
	for child: Node in view.get_children():
		if child is MeshInstance2D and not child.has_meta("grid_stretch"): sides += 1
	check("outline_sides_are_drawn",sides >= 4*96)
	# 2. Sprites standing on the relief are drawn over it; one below it is not.
	var record: Dictionary = CanvasOrder._mesh_record(meshes[7],"probe")
	var grid_view := HeightGrid.view(record.cap_grid)
	var box := HeightGrid.bounds(grid_view)
	var spot := box.get_center()
	var ground := HeightGrid.support_y(grid_view,spot.x,spot.y)
	var standing := {"anchor":Vector3(spot.x,ground,spot.y),"bounds":AABB(Vector3(spot.x-10,ground,spot.y-10),Vector3(20,60,20))}
	var buried := {"anchor":Vector3(spot.x,ground-80.0,spot.y),"bounds":AABB(Vector3(spot.x-10,ground-80.0,spot.y-10),Vector3(20,40,20))}
	check("sprites_are_ordered_by_the_real_support",record.has("cap_grid") and CanvasOrder._caps_at(record,standing) == -1 and CanvasOrder._caps_at(record,buried) == 1)
	# 3. A half turn draws the turned support.
	var turned := MapCompiler.compile(map_of(piece,2))
	var turned_view := PackageView.new(); root.add_child(turned_view)
	var turned_ok: bool = turned.ok and turned_view.configure(turned.package).ok
	check("half_turn_is_drawn_on_its_support",turned_ok and stretch_meshes(turned_view).size() == 36 and vertices_on_support(stretch_meshes(turned_view)))
	turned_view.queue_free()
	# 4. Frames over the whole field and over one corner; culling keeps the corner cheap.
	var camera := Camera2D.new(); view.add_child(camera); camera.make_current()
	var whole := await measure(camera,Vector2(0,1500),0.18)
	var corner := await measure(camera,Vector2(0,200),1.4)
	print("F10_GRID_VIEW_TIMING "+JSON.stringify({"build_ms":snappedf(build_ms,0.1),"whole":whole,"corner":corner}))
	check("frames_stay_interactive",whole.worst_ms < 250.0 and corner.worst_ms < 250.0 and corner.draw_calls <= whole.draw_calls)
	view.queue_free(); await frames()
	# 5. The editor's terrain canvas draws the same stretches and the outline.
	var canvas := TerrainCanvas.new(); canvas.size = Vector2(1280,720); root.add_child(canvas)
	await frames()
	started = Time.get_ticks_usec()
	canvas.set_source(piece,"ground")
	var canvas_ms := (Time.get_ticks_usec()-started)/1000.0
	var canvas_meshes := stretch_meshes(canvas._mesh_root)
	var canvas_sides := 0
	for child: Node in canvas._mesh_root.get_children():
		if child is MeshInstance2D and not child.has_meta("grid_stretch"): canvas_sides += 1
	print("F10_GRID_VIEW_CANVAS "+JSON.stringify({"redraw_ms":snappedf(canvas_ms,0.1),"stretches":canvas_meshes.size(),"sides":canvas_sides}))
	check("editor_canvas_draws_the_stretches",canvas_meshes.size() == 36 and canvas_sides == 4*96 and vertices_on_support(canvas_meshes))
	canvas.queue_free()
	# 6. AX: surface mode on create and on an existing layer; unknown mode refused.
	var empty := Piece.empty("grid_ax","AX")
	var made := Operations.propose(empty,"grid/create",{"layer_id":"field","name":"Campo","origin_xz":[0,0],"columns":33,"rows":33,"sample_spacing":64,"height":0,"surface_mode":"height_grid"})
	var flat := Operations.propose(made.get("data",{}),"layer/surface_mode",{"layer_id":"field","surface_mode":"exact_planes"}) if made.ok else {"ok":false}
	var back := Operations.propose(flat.get("data",{}),"layer/surface_mode",{"layer_id":"field","surface_mode":"height_grid"}) if flat.ok else {"ok":false}
	var bogus := Operations.propose(made.get("data",{}),"layer/surface_mode",{"layer_id":"field","surface_mode":"voxels"}) if made.ok else {"ok":true}
	check("ax_switches_the_surface_mode",made.ok and made.data.layers[0].get("surface_mode") == "height_grid" and flat.ok and not flat.data.layers[0].has("surface_mode") and back.ok and back.data.layers[0].surface_mode == "height_grid" and not bogus.ok)
	finish()
## Average and worst frame over 20 frames at one camera placement.
func measure(camera: Camera2D, at: Vector2, zoom: float) -> Dictionary:
	camera.position = at; camera.zoom = Vector2.ONE*zoom
	await frames(4)
	var worst := 0.0; var total := 0.0; var draws := 0
	for i: int in 20:
		var started := Time.get_ticks_usec()
		await process_frame
		var spent := (Time.get_ticks_usec()-started)/1000.0
		worst = maxf(worst,spent); total += spent
		draws = maxi(draws,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	return {"average_ms":snappedf(total/20.0,0.01),"worst_ms":snappedf(worst,0.01),"draw_calls":draws}
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_GRID_VIEW_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
