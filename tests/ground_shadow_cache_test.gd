extends SceneTree
const Shadow = preload("res://scripts/world/ground_shadow.gd")
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Patch = preload("res://scripts/core/expedition/spatial/world_support_patch.gd")
const ProjectionMath = preload("res://scripts/world/expedition_projection.gd")
const Reference = preload("res://tests/map_editor_shadows_test.gd")
var checks := 0; var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func stage(heights: Array) -> Dictionary:
	var grid := {"origin_xz":[0.0,0.0],"sample_spacing":64.0,"columns":3,"rows":3,"heights":heights}
	return {"surfaces":[{"surface_id":"floor","vertices":Grid.corners(Grid.view(grid)),"height_grid":grid,"headroom":200.0}],"connectors":[],"connections":[]}
func run() -> void:
	var source := stage([0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]); var before := var_to_bytes(source)
	var index := Patch.index(source); var cache := {}; var radii := Vector2(8,4); var anchor := Vector3(32,0,32)
	check(Shadow._flat_cached(anchor,radii,index,"floor",ProjectionMath.project,cache,[1,1,1]),"full footprint on flat quad is cached")
	var first_mesh: ArrayMesh = cache.get("mesh")
	check(first_mesh != null,"flat cache owns a mesh")
	if first_mesh != null:
		var arrays := first_mesh.surface_get_arrays(0)
		# ExpeditionProjection uses axes (0.85, 0.425), not normalized (1, 0.5).
		var expected := PackedVector2Array([Vector2(-3.4,-5.1),Vector2(10.2,1.7),Vector2(3.4,5.1),Vector2(-10.2,-1.7)])
		var projected: PackedVector2Array = arrays[Mesh.ARRAY_VERTEX]
		var aligned := projected.size() == expected.size()
		for i: int in mini(projected.size(),expected.size()): aligned = aligned and projected[i].is_equal_approx(expected[i])
		check(aligned,"flat footprint matches the documented 0.85/0.425 projection within f32 rounding")
		check(arrays[Mesh.ARRAY_TEX_UV] == PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),"radial UV extent and orientation are unchanged")
	var moved := Vector3(34,0,36)
	check(Shadow._flat_cached(moved,radii,index,"floor",ProjectionMath.project,cache,[1,1,1]) and cache.mesh == first_mesh and cache.anchor == moved,"movement inside proven quad reuses the mesh")
	var reference := Shadow.mesh_data(moved,radii,index,"floor",ProjectionMath.project)
	check(reference.ok and absf(Reference.area(reference)-128.0) < 0.0001,"original clipped footprint covers same 16 by 8 world rectangle")
	check(not Shadow._flat_cached(Vector3(2,0,32),radii,index,"floor",ProjectionMath.project,{},[1,1,1]),"outer edge keeps original clipping")
	var edge := Shadow.mesh_data(Vector3(2,0,32),radii,index,"floor",ProjectionMath.project)
	check(edge.ok and Reference.area(edge) < 128.0,"edge reference really requires a clipped footprint")
	check(not Shadow._flat_cached(Vector3(64,0,32),radii,index,"floor",ProjectionMath.project,{},[1,1,1]),"crossing a quad seam keeps original clipping")
	check(not Shadow._flat_cached(Vector3(32,1,32),radii,index,"floor",ProjectionMath.project,cache,[1,1,1]),"different support height cannot reuse prior proof")
	var slope := Patch.index(stage([0.0,16.0,32.0,0.0,16.0,32.0,0.0,16.0,32.0]))
	check(not Shadow._flat_cached(Vector3(32,8,32),radii,slope,"floor",ProjectionMath.project,cache,[2,2,2]),"ramp falls back even when walkable")
	var steep := Patch.index(stage([0.0,300.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0]))
	check(not Shadow._flat_cached(anchor,radii,steep,"floor",ProjectionMath.project,cache,[3,3,3]),"steep quad cannot use flat cache after revision")
	var other_projection := func(p: Vector3) -> Vector2: return Vector2(p.x,p.z)
	check(not Shadow._flat_cached(anchor,radii,index,"floor",other_projection,{},[1,1,1]),"other projection retains generic algorithm")
	check(Shadow._flat_cached(anchor,Vector2(4,4),index,"floor",ProjectionMath.project,cache,[4,4,4]) and cache.radii == Vector2(4,4) and cache.epoch == [4,4,4],"radius and epoch invalidate the receiver proof")
	check(not Shadow._flat_cached(anchor,radii,index,"missing",ProjectionMath.project,cache,[4,4,4]),"another surface never inherits the proof")
	var shared := {}
	check(Shadow._flat_cached(anchor,radii,index,"floor",ProjectionMath.project,shared,[9,9,9]) and shared.mesh == first_mesh,"independent actors share only the geometry-free radial mesh")
	for i: int in 129: Shadow._flat_mesh(Vector2.ONE*float(i+1))
	check(Shadow._flat_meshes.size() <= Shadow.MAX_FLAT_MESHES,"shared draw meshes remain bounded after saturation")
	check(var_to_bytes(source) == before,"visual caching does not mutate canonical stage")
	print("Ground shadow cache: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
