extends SceneTree
## F10 Q1: after a stroke on a field, only the touched stretches are rebuilt, the
## package is byte-equal to a cold compile, and receivers agree.
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const Grid = preload("res://scripts/map_authoring/compiler/grid_piece.gd")
const HeightGrid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_GRID_REGIONAL_CHECK "+id+" "+str(ok))
func height(x: int, z: int) -> float:
	var value := 6.0*sin(float(x)*0.3)+4.0*cos(float(z)*0.25)
	if x == 80 and not (z >= 70 and z <= 90): value += 180.0
	return snappedf(value,0.25)
func field() -> Dictionary:
	var source := Piece.empty("grid_regional","Campo de teste")
	var heights: Array = []
	for z: int in 161:
		for x: int in 161: heights.append(height(x,z))
	source.layers = [{"layer_id":"ground","name":"Campo","origin_xz":[-5120.0,-5120.0],"sample_spacing":64,"columns":161,"rows":161,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[],"surface_mode":"height_grid"}]
	source.sockets = [{"socket_id":"entry","surface_id":"ground","position_xyz":[-5120.0+192.0,height(3,3),-5120.0+192.0],"kind":"entrance"}]
	return source
func map_of(source: Dictionary) -> Dictionary:
	var data := MapDocument.empty("grid_regional_map"); data.name = "Campo em grade"
	var piece_hash := Schema.semantic_hash(source)
	data.pieces.append({"piece_hash":piece_hash,"source":source})
	data.instances.append({"instance_id":"field","piece_hash":piece_hash,"position_xyz":[0,0,0],"rotation_quarters":0})
	return data
func timed(action: Callable) -> Array:
	var started := Time.get_ticks_usec()
	var result: Variant = action.call()
	return [result,(Time.get_ticks_usec()-started)/1000.0]
func cold() -> void:
	Grid.clear_cache(); HeightGrid.clear_shared_lattices()
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	cold()
	var source := field()
	var first: Array = timed(func() -> Dictionary: return Terrain.compile(source))
	check("cold_compile_builds_every_stretch",first[0].ok and Grid.rebuilt_stretches == 100)
	var again: Array = timed(func() -> Dictionary: return Terrain.compile(source))
	var repeated := Grid.rebuilt_stretches-100
	check("unchanged_field_rebuilds_nothing",again[0].ok and repeated == 0 and again[0].output_hash == first[0].output_hash)
	var map_cold: Array = timed(func() -> Dictionary: return MapCompiler.compile(map_of(source)))
	var lattices_cold := HeightGrid.lattices_built
	check("cold_map_compiles",map_cold[0].ok)
	# A stroke in one stretch, far from the wall; the mass base does not change.
	var stroke := Brush.stroke(source,"ground",[Vector2(-4800.0,-4800.0)],{"mode":"raise","radius":60.0,"strength":4.0,"hardness":0.5})
	check("stroke_changes_the_field",stroke.ok and stroke.changed > 0)
	var edited: Dictionary = stroke.data
	var count_before := Grid.rebuilt_stretches
	var warm: Array = timed(func() -> Dictionary: return Terrain.compile(edited))
	var rebuilt := Grid.rebuilt_stretches-count_before
	check("stroke_rebuilds_the_touched_stretches",warm[0].ok and rebuilt > 0 and rebuilt <= 4)
	var boundaries: Array = warm[0].package.boundaries
	boundaries[0].openings = ["must_not_reach_the_cache"]
	var unpolluted: Dictionary = Terrain.compile(edited)
	check("cached_records_are_not_shared",unpolluted.ok and unpolluted.package.boundaries[0].openings.is_empty())
	var map_before := HeightGrid.lattices_built
	var map_warm: Array = timed(func() -> Dictionary: return MapCompiler.compile(map_of(edited)))
	var lattices_warm := HeightGrid.lattices_built-map_before
	check("map_rebuilds_only_touched_lattices",map_warm[0].ok and lattices_warm > 0 and lattices_warm <= 4 and lattices_cold >= 100)
	# Cold twins: the regional result is the very same bytes.
	cold()
	var twin: Array = timed(func() -> Dictionary: return Terrain.compile(edited))
	var map_twin: Array = timed(func() -> Dictionary: return MapCompiler.compile(map_of(edited)))
	check("regional_piece_equals_cold_piece",twin[0].ok and Canonical.encode(twin[0].package) == Canonical.encode(unpolluted.package))
	check("regional_map_equals_cold_map",map_twin[0].ok and Canonical.encode(map_twin[0].package) == Canonical.encode(map_warm[0].package))
	check("receivers_accept_the_regional_result",Terrain.validate_package(unpolluted.package) and MapCompiler.validate_package(map_warm[0].package))
	print("F10_GRID_REGIONAL_TIMING "+JSON.stringify({"piece_cold_ms":snappedf(first[1],1.0),"piece_same_ms":snappedf(again[1],1.0),"piece_stroke_ms":snappedf(warm[1],1.0),"piece_cold_twin_ms":snappedf(twin[1],1.0),"map_cold_ms":snappedf(map_cold[1],1.0),"map_stroke_ms":snappedf(map_warm[1],1.0),"map_cold_twin_ms":snappedf(map_twin[1],1.0),"stretches_rebuilt":rebuilt,"lattices_rebuilt":lattices_warm}))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_GRID_REGIONAL_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
