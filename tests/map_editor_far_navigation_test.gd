extends SceneTree
## Q5: differential against the pre-optimization local lattice producer and
## the eager visibility graph. Representative authored stretches, a terrain
## wall with a gap, physical masses, directed seams and geometry mutations.
const Grid = preload("res://scripts/core/expedition/spatial/world_height_grid.gd")
const Ground = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const PROFILE := {"profile_id":"ruins_player","revision":1,"radius":20.0,"height":32.0,"connector_kinds":["walk"]}

class ReferenceWorld extends WorldGeometry:
	var fields_built := 0
	# Frozen wrappers from before Q5 endpoint preparation. They still perform
	# both canonical endpoint predicates in sweep and fraction independently.
	func _navigation_clear(a: Vector3, b: Vector3, profile: Dictionary, candidate: WorldSolidSegment, surface: String, memo: Dictionary, mass_context: Dictionary = {}, segment_context: Variant = null) -> bool:
		var value: Variant = _navigation_memo_get(memo,"clear",surface,a,b)
		if value != null: return bool(value)
		var accepted := _clear_path_segment(a,b,profile,candidate,surface,mass_context,segment_context)
		_navigation_memo_put(memo,"clear",surface,a,b,accepted)
		return accepted
	func _navigation_fraction(cell: Dictionary, a: Vector3, b: Vector3, profile: Dictionary, memo: Dictionary, segment_context: Dictionary = {}) -> float:
		var value: Variant = _navigation_memo_get(memo,"fraction",cell.surface_id,a,b)
		if value != null: return float(value)
		_ensure_support_index()
		var fraction: float = SupportPatch._fraction_prepared(cell,a,b,profile,_support_index,segment_context.get("members",{}))
		_navigation_memo_put(memo,"fraction",cell.surface_id,a,b,fraction)
		return fraction
	# Frozen pre-Q5 producer. In particular, it builds the field before route()
	# can return a terrain-clear chord which the producer rejects (<3 points).
	func _navigation_grid_edge(a: Dictionary, b: Dictionary, profile: Dictionary, candidate: WorldSolidSegment, memo: Dictionary, field: Dictionary) -> Dictionary:
		var surface: String = a.surface_id
		var cell := _cell(surface)
		var built := _grid_lattice(surface,float(profile.radius))
		if built.is_empty(): return {"ok":false}
		var parts := _grid_parts(surface,float(profile.radius))
		if not field.has("labels"): field["labels"] = _grid_labels(surface,float(profile.radius),built,parts,Vector2(a.position.x,a.position.z))
		var shared := false
		for label: int in _grid_labels(surface,float(profile.radius),built,parts,Vector2(b.position.x,b.position.z)):
			if field.labels.has(label): shared = true; break
		if not shared: return {"ok":false}
		if not field.has("ok"):
			fields_built += 1
			field.merge(HeightGrid.field(built,Vector2(a.position.x,a.position.z)))
		if not field.get("ok",false): return {"ok":false}
		var routed := HeightGrid.route(built,field,Vector2(b.position.x,b.position.z))
		if not routed.ok or routed.points.size() < 3: return {"ok":false}
		var points: Array[Vector3] = [a.position]
		for index: int in range(1,routed.points.size()-1):
			var corner: Vector2 = routed.points[index]
			points.append(Kernel.support_y(cell,Vector3(corner.x,0,corner.y)))
		points.append(b.position)
		var via: Array = []; var cost := 0.0
		for index: int in range(1,points.size()):
			if index < points.size()-1:
				var state := ExpeditionWorldPoint.create(_stage.stage_id,surface,points[index])
				if not _navigation_point(state,float(profile.radius),float(profile.height),candidate,memo): return {"ok":false}
				via.append(state.to_data())
			if not _navigation_clear(points[index-1],points[index],profile,candidate,surface,memo) or _navigation_fraction(cell,points[index-1],points[index],profile,memo) < 1.0-EPS: return {"ok":false}
			cost += points[index-1].distance_to(points[index])
		return {"ok":true,"via":via,"cost":cost}

var checks: Array[Dictionary] = []
var metrics: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F10_FAR_NAV_CHECK "+id+" "+str(ok))

func make_manifest(terrain: bool, gap: bool = true, directed: bool = false) -> ExpeditionManifest:
	var cells: Array = []
	for column: int in 3:
		var heights: Array = []
		for z: int in 17:
			for x: int in 17:
				var gx := column*16+x
				var y := 10.0*sin(float(gx)*0.35) if terrain else 0.0
				if terrain and gx == 24 and not (gap and z >= 6 and z <= 10): y += 200.0
				heights.append(snappedf(y,0.25))
		var grid := {"origin_xz":[float(column)*1024.0,0.0],"sample_spacing":64.0,"columns":17,"rows":17,"heights":heights}
		cells.append({"surface_id":"stretch_"+str(column),"headroom":200.0,"vertices":Grid.corners(Grid.view(grid)),"height_grid":grid})
	var connectors: Array = []; var connections: Array = []
	for column: int in 2:
		var a: Dictionary = cells[column]; var b: Dictionary = cells[column+1]
		var spans := Grid.shared_spans(Grid.view(a.height_grid),1,Grid.view(b.height_grid))
		for index: int in spans.size():
			var p: Vector3 = spans[index].a; var q: Vector3 = spans[index].b
			var middle := (p+q)*0.5; middle.y = Grid.support_y_clamped(Grid.view(a.height_grid),middle.x,middle.z)
			var key := "seam_%d_%d"%[column,index]
			connectors.append({"connector_id":key+"_a","surface_id":a.surface_id,"position":middle,"outward":Vector3.RIGHT,"kind":"walk","tags":[],"width":p.distance_to(q),"headroom":200.0,"direction":"both"})
			connectors.append({"connector_id":key+"_b","surface_id":b.surface_id,"position":middle,"outward":Vector3.LEFT,"kind":"walk","tags":[],"width":p.distance_to(q),"headroom":200.0,"direction":"both"})
			connections.append({"connection_id":key,"a_connector":key+"_a","b_connector":key+"_b","forward":true,"backward":not directed})
	var stage := {"stage_id":"far_nav","surfaces":cells,"connectors":connectors,"connections":connections,"sockets":[],"volumes":[],"solid_prisms":[],"part_instances":[]}
	var manifest := ExpeditionManifest.new(); manifest._data = {"input":{"parts":[]},"stages":[stage]}
	return manifest

func pair(manifest: ExpeditionManifest) -> Dictionary:
	var current := WorldGeometry.new(); var reference := ReferenceWorld.new()
	var a := current.configure(manifest,"far_nav"); var b := reference.configure(manifest,"far_nav")
	return {"current":current,"reference":reference,"ok":a.ok and b.ok}

func at(world: WorldGeometry, column: int, x: float, z: float) -> ExpeditionWorldPoint:
	var id := "stretch_"+str(column)
	return ExpeditionWorldPoint.create("far_nav",id,Ground.support_y(world._cell(id),Vector3(x,0,z)))

func walks(world: WorldGeometry, route: Dictionary, profile: Dictionary) -> bool:
	if not route.ok: return false
	for index: int in range(1,route.data.points.size()):
		var a: Dictionary = route.data.points[index-1]; var b: Dictionary = route.data.points[index]
		if a.surface_id == b.surface_id:
			if not world.segment_walkable(a.surface_id,a.position,b.position,profile,world.geometry_revision): return false
		elif Vector3(a.position).distance_to(b.position) > 0.001: return false
	return true

# Compare complete points/connection IDs/cost/error, not only reachability.
func compare(id: String, worlds: Dictionary, from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, expected: bool, profile: Dictionary = PROFILE, candidate: WorldSolidSegment = null) -> Dictionary:
	var current: WorldGeometry = worlds.current; var reference: ReferenceWorld = worlds.reference
	var old_trace := {"enabled":true}; var trace := {"enabled":true}
	var before := reference.fields_built
	var started := Time.get_ticks_usec()
	var old := reference._path(from,to,profile,reference.geometry_revision,candidate,false,old_trace,false)
	var old_usec := Time.get_ticks_usec()-started
	started = Time.get_ticks_usec()
	var route := current._path(from,to,profile,current.geometry_revision,candidate,true,trace,false)
	var new_usec := Time.get_ticks_usec()-started
	var eager := current._path(from,to,profile,current.geometry_revision,candidate,false,{},false)
	var memoized := current._path(from,to,profile,current.geometry_revision,candidate,true,{},true)
	check(id+"_same_complete_result",route == old and route == eager and route == memoized and route.ok == expected)
	if expected and candidate == null: check(id+"_body_walks",walks(current,route,profile))
	var measurement := {"id":id,"reference_usec":old_usec,"current_usec":new_usec,"reference_fields":reference.fields_built-before,"current_fields":trace.get("grid_fields",0),"straight_rejections":trace.get("grid_straight_rejections",0),"cost":route.data.get("cost",0.0)}
	metrics.append(measurement); print("F10_FAR_NAV_CASE "+JSON.stringify(measurement))
	return {"route":route,"trace":trace,"reference_fields":reference.fields_built-before}

func run() -> void:
	# The terrain chord is free; physical masses force the general graph. The
	# old producer's fields cannot contribute any bent edge on this terrain.
	var flat := make_manifest(false)
	flat._data.stages[0].volumes.append(AABB(Vector3(480,-80,-20),Vector3(60,400,700)))
	var masses := pair(flat)
	check("representative_stretches_configure",masses.ok)
	var from := at(masses.current,0,200.0,150.0); var to := at(masses.current,2,2900.0,150.0)
	var physical := compare("mass_detour",masses,from,to,true)
	check("terrain_clear_mass_failure_avoids_fields",physical.reference_fields > 0 and physical.trace.get("grid_fields",0) == 0 and physical.trace.get("grid_straight_rejections",0) > 0)
	compare("mass_detour_reverse",masses,to,from,true)
	var wide := PROFILE.duplicate(true); wide.radius = 48.0
	compare("mass_detour_wide_body",masses,from,to,true,wide)

	# Here the field IS required: the direct terrain capsule crosses a steep
	# wall, and the exact same bent edge must survive the optimization.
	var relief := pair(make_manifest(true))
	var start := at(relief.current,0,200.0,150.0); var end := at(relief.current,2,2900.0,150.0)
	var bent := compare("steep_gap",relief,start,end,true)
	check("terrain_detour_still_builds_fields",bent.trace.get("grid_fields",0) > 0)
	compare("steep_gap_reverse",relief,end,start,true)
	var raised_mass := make_manifest(true)
	raised_mass._data.stages[0].volumes.append(AABB(Vector3(480,5,120),Vector3(48,100,70)))
	var raised := pair(raised_mass)
	compare("steep_gap_and_mass",raised,at(raised.current,0,200.0,150.0),at(raised.current,2,2900.0,150.0),true)
	var closed := pair(make_manifest(true,false))
	compare("steep_wall_unreachable",closed,at(closed.current,0,200.0,150.0),at(closed.current,2,2900.0,150.0),false)

	var one_way := pair(make_manifest(true,true,true))
	var first := at(one_way.current,0,200.0,150.0); var last := at(one_way.current,2,2900.0,150.0)
	compare("directed_forward",one_way,first,last,true)
	compare("directed_reverse",one_way,last,first,false)

	# A blocked candidate is transient and does not turn the free terrain chord
	# into a usable local edge. Shared warm predicates must also invalidate when
	# an obstacle is inserted/removed or the same world is reconfigured.
	var clean := pair(make_manifest(false))
	var a := at(clean.current,0,200.0,150.0); var b := at(clean.current,2,2900.0,150.0)
	var candidate := WorldSolidSegment.new(); candidate.configure(at(clean.current,0,500.0,300.0),Vector3.RIGHT,280.0,8.0,80.0,PROFILE)
	compare("speculative_segment",clean,a,b,true,PROFILE,candidate)
	var warm: Dictionary = clean.current.path(a,b,PROFILE,clean.current.geometry_revision)
	var old_revision: int = clean.current.geometry_revision
	var wall := AABB(Vector3(480,-80,-20),Vector3(60,400,1064))
	var inserted: Dictionary = clean.current.insert_obstacle("closed",wall,clean.current.geometry_revision)
	var inserted_ref: Dictionary = clean.reference.insert_obstacle("closed",wall,clean.reference.geometry_revision)
	check("temporary_wall_inserts",inserted.ok and inserted_ref.ok)
	compare("temporary_wall_unreachable",clean,a,b,false)
	check("warm_result_does_not_hide_temporary",warm.ok and not clean.current.path(a,b,PROFILE,clean.current.geometry_revision).ok)
	check("old_revision_rejected",clean.current.path(a,b,PROFILE,old_revision).error_code == &"stale_geometry")
	clean.current.remove_obstacle("closed",clean.current.geometry_revision); clean.reference.remove_obstacle("closed",clean.reference.geometry_revision)
	compare("temporary_removed",clean,a,b,true)
	var replaced := make_manifest(true,false)
	clean.current.configure(replaced,"far_nav"); clean.reference.configure(replaced,"far_nav")
	compare("reconfigured_wall_unreachable",clean,at(clean.current,0,200.0,150.0),at(clean.current,2,2900.0,150.0),false)
	endpoint_preparation()
	finish()

func endpoint_preparation() -> void:
	var world := WorldGeometry.new(); world.configure(make_manifest(false),"far_nav")
	var other := WorldGeometry.new(); other.configure(make_manifest(false),"far_nav")
	var a := Vector3(200,0,150); var b := Vector3(300,0,150); var surface := "stretch_0"
	var memo := {"point":{},"clear":{},"fraction":{},"entries":WorldGeometry.NAVIGATION_SHARED_MEMO_LIMIT,"hits":0,"misses":0,"peak":0,"stored":0,"released":0,"limit":WorldGeometry.NAVIGATION_SHARED_MEMO_LIMIT}
	var context := {}
	var clear := world._navigation_clear(a,b,PROFILE,null,surface,memo,{},context)
	var fraction := world._navigation_fraction(world._cell(surface),a,b,PROFILE,memo,context)
	var public_clear := world.ground_sweep(surface,a,b,PROFILE,world.geometry_revision)
	var public_fraction := WorldGeometry.SupportPatch.fraction(world._cell(surface),a,b,PROFILE,world._support_index)
	check("endpoint_cache_is_separate_from_saturated_pairs",clear and public_clear.ok and not public_clear.data.hit and fraction == public_fraction and memo.get("contains_entries",0) == 2)
	var before: int = memo.get("contains_evaluations",0)
	world._navigation_clear(a,b,PROFILE,null,surface,memo,{},{}); world._navigation_fraction(world._cell(surface),a,b,PROFILE,memo,{})
	check("exact_endpoints_reuse_canonical_membership",memo.get("contains_evaluations",0) == before and memo.get("contains_hits",0) >= 4)
	check("private_receipt_is_bound_to_owner_order_and_surface",world._navigation_support_known(context,surface,a,b) and not other._navigation_support_known(context,surface,a,b) and not world._navigation_support_known(context,surface,b,a) and not world._navigation_support_known(context,"stretch_1",a,b))
	var forged := {"endpoint_support":[null,world.configuration_revision,world.geometry_revision,surface,a,Vector3(300,40,150),true]}
	var bad := world._ground_sweep(surface,a,Vector3(300,40,150),PROFILE,world.geometry_revision,{},forged)
	check("data_only_receipt_cannot_bypass_public_support",not bad.ok and bad.error_code == &"invalid_support" and world._navigation_fraction(world._cell(surface),a,Vector3(300,40,150),PROFILE,memo,{}) == 0.0)
	var saturated := {"contains":{},"contains_entries":WorldGeometry.NAVIGATION_CONTAINS_MEMO_LIMIT}
	check("endpoint_saturation_falls_back_without_new_entries",world._navigation_contains(surface,a,saturated) and not world._navigation_contains(surface,Vector3(200,40,150),saturated) and saturated.contains.is_empty() and saturated.contains_entries == WorldGeometry.NAVIGATION_CONTAINS_MEMO_LIMIT)
	world.insert_obstacle("revision_change",AABB(Vector3(700,0,700),Vector3(20,80,20)),world.geometry_revision)
	var stale := not world._navigation_support_known(context,surface,a,b)
	world.configure(make_manifest(true,false),"far_nav")
	check("private_receipt_expires_on_revision_and_reconfigure",stale and not world._navigation_support_known(context,surface,a,b))

func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F10_FAR_NAV_METRICS "+JSON.stringify(metrics))
	print("F10_FAR_NAV_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
