extends SceneTree
## F10 H1 (contracts/f10_height_grid.md): the pure height-grid surface. Support
## is the renderer's triangulation, exact against the planar kernel; steep
## triangles are holes; bodies, capsules, routes, components and open spans.
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_HEIGHT_GRID_CHECK "+id+" "+str(ok))
func grid(columns: int, rows: int, height: Callable, spacing: float = 64.0, origin: Array = [0.0,0.0]) -> Dictionary:
	var heights: Array = []
	for z: int in rows:
		for x: int in columns: heights.append(float(height.call(x,z)))
	return {"origin_xz":origin,"sample_spacing":spacing,"columns":columns,"rows":rows,"heights":heights}
## A wall of raised samples at x = 8 with an optional gap of flat samples.
func walled(gap: bool) -> Dictionary:
	return Grid.prepare(grid(17,17,func(x: int, z: int) -> float: return 200.0 if x == 8 and not (gap and z >= 6 and z <= 10) else 0.0))
func legs_clear(prepared: Dictionary, points: PackedVector2Array, radius: float) -> bool:
	for k: int in points.size()-1:
		if not Grid.segment_clear(prepared,points[k],points[k+1],radius): return false
	return true
func run() -> void:
	# 1. Validation.
	var flat := grid(5,4,func(_x: int, _z: int) -> float: return 12.0)
	var bad_size := flat.duplicate(true); bad_size.heights.pop_back()
	var bad_value := flat.duplicate(true); bad_value.heights[3] = INF
	var bad_columns := flat.duplicate(true); bad_columns.columns = 1
	var too_big := grid(2,2,func(_x: int, _z: int) -> float: return 0.0); too_big.columns = 258
	check("invalid_grids_refused",Grid.valid(flat) and not Grid.valid(bad_size) and not Grid.valid(bad_value) and not Grid.valid(bad_columns) and not Grid.valid(too_big) and Grid.prepare(bad_size).is_empty())
	# 2. Flat stretch: one height everywhere, all walkable, corners inside.
	var p := Grid.prepare(flat)
	check("flat_support_and_bounds",p.walkable_count == 4*3*2 and is_equal_approx(Grid.support_y(p,100.0,70.0),12.0) and Grid.triangle_at(p,256.0,192.0) >= 0 and Grid.triangle_at(p,256.1,10.0) == -1 and is_nan(Grid.support_y(p,-1.0,0.0)))
	# 3. Organic relief: support equals the planar kernel on the same triangle.
	var organic := Grid.prepare(grid(9,9,func(x: int, z: int) -> float: return float((x*37+z*61)%23)-float(x*z%7)))
	var exact := true; var continuous := true
	var rng := RandomNumberGenerator.new(); rng.seed = 1010
	for k: int in 400:
		var x := rng.randf_range(0.0,512.0); var z := rng.randf_range(0.0,512.0)
		var t := Grid.triangle_at(organic,x,z)
		var cell := {"vertices":Grid.triangle_vertices(organic,t),"headroom":100.0}
		var kernel_y := Kernel.support_y(cell,Vector3(x,0,z)).y
		if absf(Grid.support_y(organic,x,z)-kernel_y) > 0.001 or not Kernel.contains(cell,Vector3(x,kernel_y,z)): exact = false
		var d := rng.randf_range(0.0,64.0); var i := rng.randi_range(0,7); var j := rng.randi_range(0,7)
		var on_diagonal := Vector2(i*64.0+d,j*64.0+d)
		var below := Grid.support_y(organic,on_diagonal.x+0.0001,on_diagonal.y-0.0001); var above := Grid.support_y(organic,on_diagonal.x-0.0001,on_diagonal.y+0.0001)
		if absf(below-above) > 0.01: continuous = false
	check("support_matches_the_planar_kernel",exact)
	check("support_is_continuous_across_the_diagonal",continuous)
	# 4. Steep triangles by the kernel's normal rule (a 45-degree limit).
	var ramp := Grid.prepare(grid(3,2,func(x: int, _z: int) -> float: return 0.0 if x == 0 else (40.0 if x == 1 else 120.0)))
	check("steep_triangles_are_holes",Grid.triangle_walkable(ramp,0) and Grid.triangle_walkable(ramp,1) and not Grid.triangle_walkable(ramp,2) and not Grid.triangle_walkable(ramp,3) and ramp.walkable_count == 2)
	# 5. Body disk and capsule against a steep wall.
	var wall := walled(false)
	var wall_x := 7.0*64.0
	check("disk_keeps_its_radius_from_steep_ground",Grid.disk_clear(wall,Vector2(wall_x-12.0,300.0),10.0) and not Grid.disk_clear(wall,Vector2(wall_x-8.0,300.0),10.0) and not Grid.disk_clear(wall,Vector2(8.0,300.0),10.0) and Grid.disk_clear(wall,Vector2(8.0,300.0),10.0,false))
	check("capsule_along_and_across_the_wall",Grid.segment_clear(wall,Vector2(wall_x-12.0,40.0),Vector2(wall_x-12.0,900.0),10.0) and not Grid.segment_clear(wall,Vector2(100.0,300.0),Vector2(900.0,300.0),10.0))
	# 6. Zero-radius body: may stand on and slide along the steep edge, not cross it.
	check("zero_radius_edges",Grid.disk_clear(wall,Vector2(wall_x,300.0),0.0) and Grid.segment_clear(wall,Vector2(wall_x,100.0),Vector2(wall_x,500.0),0.0) and not Grid.segment_clear(wall,Vector2(wall_x-30.0,300.0),Vector2(wall_x+130.0,300.0),0.0))
	# 7. Routes: around the wall through the gap; none without it; deterministic.
	var gate := walled(true)
	var from := Vector2(100.0,100.0); var to := Vector2(900.0,120.0)
	var started := Time.get_ticks_usec()
	var route := Grid.path(gate,from,to,10.0)
	var route_ms := (Time.get_ticks_usec()-started)/1000.0
	var again := Grid.path(gate,from,to,10.0)
	var through_gap := false
	if route.ok:
		for q: Vector2 in route.points:
			if q.y > 6.0*64.0-1.0 and q.y < 10.0*64.0+1.0: through_gap = true
	check("route_goes_through_the_gap",route.ok and route.points[0] == from and route.points[route.points.size()-1] == to and legs_clear(gate,route.points,10.0) and through_gap and route.length > from.distance_to(to))
	check("route_is_deterministic",route.ok and again.ok and route.points == again.points)
	var blocked := Grid.path(wall,from,to,10.0)
	check("no_route_without_the_gap",not blocked.ok and blocked.code == "height_grid_unreachable" and Grid.path(wall,from,Vector2(300.0,800.0),10.0).ok)
	# 8. Components: the wall splits the stretch in two; the gap joins it.
	var split := Grid.components(wall,10.0); var joined := Grid.components(gate,10.0)
	check("components_follow_the_wall",split.ok and split.count == 2 and joined.ok and joined.count == 1)
	# 9. Open spans along the sides stop at steep triangles.
	var spans := Grid.edge_spans(wall,0)
	check("edge_spans_split_at_steep_ground",spans.size() == 2 and spans[0].from == 0 and spans[0].to == 7 and spans[1].from == 9 and spans[1].to == 16 and spans[0].a == Grid.point(wall,0,0) and Grid.edge_spans(p,1).size() == 1)
	# 10. A 16x16-quad stretch of rough relief: a long route stays cheap.
	var rough := Grid.prepare(grid(17,17,func(x: int, z: int) -> float: return 90.0 if x%4 == 2 and z%4 == 2 else 0.0))
	started = Time.get_ticks_usec()
	var long := Grid.path(rough,Vector2(20.0,20.0),Vector2(1000.0,1000.0),10.0)
	var long_ms := (Time.get_ticks_usec()-started)/1000.0
	print("F10_HEIGHT_GRID_TIMING "+JSON.stringify({"gate_ms":snappedf(route_ms,0.1),"rough_ms":snappedf(long_ms,0.1),"rough_expanded":long.get("expanded",0),"rough_ok":long.ok}))
	check("rough_route_detours_the_bumps",long.ok and legs_clear(rough,long.points,10.0) and long.points.size() > 2 and not Grid.segment_clear(rough,Vector2(20.0,20.0),Vector2(1000.0,1000.0),10.0))
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_HEIGHT_GRID_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
