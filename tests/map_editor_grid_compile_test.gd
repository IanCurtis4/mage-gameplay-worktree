extends SceneTree
## F10 H4 (contracts/f10_height_grid.md): a layer declared `surface_mode:
## "height_grid"` compiles to stretches, seams, outline boundaries and sides,
## packages that their receivers rebuild exactly, and maps that are certified
## per walkable component, cross piece links and refuse what is not supported.
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const Grid = preload("res://scripts/map_authoring/compiler/grid_piece.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const PROFILE := {"radius":10.0,"height":40.0,"connector_kinds":["walk"]}
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_GRID_COMPILE_CHECK "+id+" "+str(ok))
## Gentle relief over global sample x (so linked pieces share their seam) and a
## steep wall across the middle column with an optional gap.
func height(gx: int, gz: int, wall_x: int, gap: bool) -> float:
	var base := 6.0*sin(float(gx)*0.3)+4.0*cos(float(gz)*0.25)
	if gx == wall_x and not (gap and gz >= 22 and gz <= 26): base += 180.0
	return snappedf(base,0.25)
func field(id: String, columns: int, first_x: int, wall_x: int, gap: bool, connectors: Array = [], origin: float = 0.0) -> Dictionary:
	var source := Piece.empty(id,"Campo de teste")
	var heights: Array = []; var grass: Array = []; var earth: Array = []
	for z: int in columns:
		for x: int in columns:
			heights.append(height(first_x+x,z,wall_x,gap)); grass.append(1.0); earth.append(0.0)
	source.layers = [{"layer_id":"ground","name":"Campo","origin_xz":[origin,origin],"sample_spacing":64,"columns":columns,"rows":columns,"heights":heights,"material_masks":{"grass":grass,"earth":earth},"locked":false,"protected_regions":[],"surface_mode":"height_grid"}]
	var edge := float(columns-1)*64.0
	for side: String in connectors:
		var x := 0.0 if side == "west" else edge
		var gx := first_x if side == "west" else first_x+columns-1
		var z := float((columns-1)/2)*64.0
		source.connectors.append({"connector_id":side,"surface_id":"ground","position_xyz":[x,height(gx,(columns-1)/2,wall_x,gap),z],"normal_xyz":[-1 if side == "west" else 1,0,0],"kind":"walk","width":256,"headroom":128,"tags":["ruin"],"direction":"both"})
	source.sockets = [{"socket_id":"entry","surface_id":"ground","position_xyz":[origin+192.0,height(first_x+3,3,wall_x,gap),origin+192.0],"kind":"entrance"}]
	return source
func map_of(pieces: Array, instances: Array, links: Array = []) -> Dictionary:
	var data := MapDocument.empty("grid_field"); data.name = "Campo em grade"
	for source: Dictionary in pieces: data.pieces.append({"piece_hash":Schema.semantic_hash(source),"source":source})
	for item: Array in instances: data.instances.append({"instance_id":item[0],"piece_hash":Schema.semantic_hash(item[1]),"position_xyz":item[2],"rotation_quarters":item[3]})
	data.links = links
	return data
func compile_piece(source: Dictionary) -> Dictionary:
	return Terrain.compile(source)
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	# 1. Schema: the mode is accepted, an unknown mode is refused.
	var piece := field("grid_piece",49,0,24,true)
	var unknown := piece.duplicate(true); unknown.layers[0].surface_mode = "voxels"
	var read := Schema.read(JSON.stringify(piece,"",true,true).to_utf8_buffer())
	var refused := Schema.read(JSON.stringify(unknown,"",true,true).to_utf8_buffer())
	var codes: Array = []
	for item: Dictionary in refused.get("diagnostics",[]): codes.append(item.code)
	check("schema_accepts_the_mode",read.ok and read.valid and refused.ok and not refused.valid and "source_surface_mode_invalid" in codes)
	# 2. A 3x3-stretch piece: cells, seams, outline and a receiver that agrees.
	var started := Time.get_ticks_usec()
	var compiled := compile_piece(piece)
	var piece_ms := (Time.get_ticks_usec()-started)/1000.0
	var package: Dictionary = compiled.get("package",{})
	var gridded: bool = compiled.ok and package.part.surfaces.size() == 9
	if gridded:
		for cell: Dictionary in package.part.surfaces:
			if not cell.has("height_grid") or not Kernel_valid(cell): gridded = false
	check("piece_compiles_to_stretches",gridded and package.part.solid_prisms.is_empty() and package.exposed_sides.size() == 4*48 and not package.adjacency.is_empty() and package.part.sockets.size() == 1)
	check("receiver_rebuilds_the_package",compiled.ok and Terrain.validate_package(package))
	var tampered := package.duplicate(true)
	if compiled.ok: tampered.part.surfaces[4].height_grid.heights[7] = float(tampered.part.surfaces[4].height_grid.heights[7])+1.0
	check("tampered_stretch_is_refused",compiled.ok and not Terrain.validate_package(tampered))
	var mixed := piece.duplicate(true)
	mixed.layers.append({"layer_id":"ledge","name":"Beiral","origin_xz":[4000,0],"sample_spacing":64,"columns":2,"rows":2,"heights":[0,0,0,0],"material_masks":{},"locked":false,"protected_regions":[]})
	var mixed_result := compile_piece(mixed)
	check("mixed_piece_is_refused",not mixed_result.ok and mixed_result.code == "height_grid_piece_mixed")
	# 3. Field scale: 161x161 samples (10 240 units) in 100 stretches, centred
	# (a piece keeps every coordinate within 8192).
	var big := field("grid_big",161,0,80,true,[],-5120.0)
	started = Time.get_ticks_usec()
	var big_compiled := compile_piece(big)
	var big_ms := (Time.get_ticks_usec()-started)/1000.0
	started = Time.get_ticks_usec()
	var big_valid: bool = big_compiled.ok and Terrain.validate_package(big_compiled.package)
	var big_validate_ms := (Time.get_ticks_usec()-started)/1000.0
	check("field_scale_piece_compiles",big_compiled.ok and big_compiled.package.part.surfaces.size() == 100 and big_valid)
	# 4. A map of the piece: certified per component, receivers agree.
	started = Time.get_ticks_usec()
	var map := MapCompiler.compile(map_of([piece],[["field",piece,[0,0,0],0]]))
	var map_ms := (Time.get_ticks_usec()-started)/1000.0
	check("map_certifies_the_field",map.ok and MapCompiler.validate_package(map.package) and map.package.manifest.stages[0].surfaces.size() == 9)
	var turned := MapCompiler.compile(map_of([piece],[["field",piece,[0,0,0],2]]))
	var quarter := MapCompiler.compile(map_of([piece],[["field",piece,[0,0,0],1]]))
	check("half_turn_compiles_quarter_turn_is_refused",turned.ok and MapCompiler.validate_package(turned.package) and not quarter.ok and quarter.code == "height_grid_rotation_unsupported")
	var walled := field("grid_walled",49,0,24,false)
	var cut := MapCompiler.compile(map_of([walled],[["field",walled,[0,0,0],0]]))
	check("wall_without_gap_fails_certification",not cut.ok and cut.code == "route_unreachable")
	# 5. Two linked field pieces: the link crosses stretch boundaries and routes.
	var left := field("grid_left",49,0,24,true,["east"]); var right := field("grid_right",49,48,72,true,["west"])
	var linked := MapCompiler.compile(map_of([left,right],[["left",left,[0,0,0],0],["right",right,[3072,0,0],0]],[{"link_id":"seam","a_instance":"left","a_connector":"east","b_instance":"right","b_connector":"west"}]))
	var crossed := false
	if linked.ok:
		var world := WorldGeometry.new()
		var manifest := MapCompiler.manifest(linked.package)
		if manifest != null and world.configure(manifest,"map_preview").ok:
			var stage: Dictionary = linked.package.manifest.stages[0]
			var a := _point(stage,"left/",300.0,300.0); var b := _point(stage,"right/",5800.0,2800.0)
			if a != null and b != null:
				var route: Dictionary = world.path(a,b,PROFILE,world.geometry_revision)
				crossed = route.ok and route.data.points[-1].surface_id.begins_with("right/")
	check("linked_pieces_route_across_the_seam",linked.ok and MapCompiler.validate_package(linked.package) and crossed)
	print("F10_GRID_COMPILE_TIMING "+JSON.stringify({"piece_ms":snappedf(piece_ms,0.1),"big_piece_ms":snappedf(big_ms,0.1),"big_validate_ms":snappedf(big_validate_ms,0.1),"map_ms":snappedf(map_ms,0.1),"map_code":map.get("code",""),"big_code":big_compiled.get("code",""),"linked_code":linked.get("code",""),"map_metrics":map.get("metrics",{})}))
	finish()
func Kernel_valid(cell: Dictionary) -> bool:
	return ExpeditionFixtureGeometry.valid_cell(cell)
## A supported point on the stretch of `prefix` containing (x, z).
func _point(stage: Dictionary, prefix: String, x: float, z: float) -> ExpeditionWorldPoint:
	for cell: Dictionary in stage.surfaces:
		if not str(cell.surface_id).begins_with(prefix) or not cell.has("height_grid"): continue
		var view := HeightGrid.view(cell.height_grid)
		if HeightGrid.triangle_at(view,x,z) < 0: continue
		return ExpeditionWorldPoint.create("map_preview",cell.surface_id,Vector3(x,HeightGrid.support_y(view,x,z),z))
	return null
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_GRID_COMPILE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
