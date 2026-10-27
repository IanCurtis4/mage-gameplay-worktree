extends SceneTree
const Organic = preload("res://tests/map_editor_organic_test.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Prism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const PROFILE := {"radius":20.0,"height":32.0,"connector_kinds":["walk"]}
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_CONTEXT_CHECK "+id+" "+str(ok))
func run() -> void:
	var built := Maps.compile(Organic.map_source(Organic.gaussian(5)))
	check("real_curved_terrain_publishes_with_masses",built.ok and not built.package.manifest.stages[0].solid_prisms.is_empty())
	if not built.ok: finish(); return
	var manifest := Maps.manifest(built.package)
	for index: int in 24: manifest._data.stages[0].volumes.append(AABB(Vector3(2000+index*50,1000,2000),Vector3(20,20,20)))
	for index: int in 2: manifest._data.stages[0].volumes.append(AABB(Vector3(500,150,500),Vector3(200,200,200)))
	var world := WorldGeometry.new(); world.configure(manifest,"map_preview")
	var original := ExpeditionCanonical.digest(world._stage)
	var a: Dictionary = world._stage.surfaces[0]; var b: Dictionary = world._stage.surfaces[-1]
	var from := ExpeditionWorldPoint.create("map_preview",a.surface_id,Maps._center(a))
	var to := ExpeditionWorldPoint.create("map_preview",b.surface_id,Maps._center(b))
	var graph := world._navigation_graph(from,to,PROFILE,null)
	var scopes := {}; var strict_subset := false
	for id: String in graph.by_surface:
		scopes[id] = world._navigation_mass_context(graph,id,PROFILE)
		strict_subset = strict_subset or scopes[id].items.size() < world._support_index.solid_prisms.size()
	var first := audit(world,graph,scopes)
	check("authored_volume_subset_preserves_equal_fraction_hit_order",collision_probe(world,"map_preview/volume/"+str(world._stage.volumes.size()-1)) and first.sweeps)
	check("envelope_selects_a_strict_mass_subset",strict_subset)
	check("ordered_pair_candidates_match_full_index",first.candidates)
	check("all_sampled_ground_sweeps_match_full_authority",first.sweeps)
	check("all_sampled_clear_predicates_match_full_authority",first.clear)
	world.insert_obstacle("context_obstacle",AABB(Vector3(500,150,500),Vector3(200,200,200)),world.geometry_revision)
	var after := audit(world,graph,scopes)
	check("temporary_volume_is_still_checked",after.sweeps and after.clear and collision_probe(world,"temporary/context_obstacle"))
	var candidate := WorldSolidSegment.new(); candidate.configure(from,Vector3.RIGHT,80,5,40,PROFILE)
	check("speculative_segment_is_still_checked",not world._clear_path_segment(from.position,from.position,PROFILE,candidate,from.surface_id) and not world._clear_path_segment(from.position,from.position,PROFILE,candidate,from.surface_id,scopes[from.surface_id]))
	var eager := world._path(from,to,PROFILE,world.geometry_revision,null,false)
	var lazy := world.path(from,to,PROFILE,world.geometry_revision)
	check("real_mass_detour_matches_eager_exactly",eager.ok and lazy == eager)
	check("real_mass_route_walks_with_player_body",lazy.ok and Organic.walk(world,lazy.data,PROFILE))
	check("queries_preserve_stage_and_release_actor",ExpeditionCanonical.digest(world._stage) == original and world._occupancy.is_empty())
	finish()
# Collision fixtures include a deliberately occupied but geometrically valid
# anchor. Graph production correctly excludes it; sparse valid-node samples
# cannot by themselves prove that a collider was actually hit.
func collision_probe(world: WorldGeometry, expected: String) -> bool:
	for cell: Dictionary in world._stage.surfaces:
		var supported := world.support_at(cell.surface_id,Vector2(600,600),world.geometry_revision)
		if not supported.ok: continue
		var position: Vector3 = supported.data.point.position
		var graph := {"nodes":{"probe":{"position":position}},"by_surface":{cell.surface_id:["probe"]}}
		var scope := world._navigation_mass_context(graph,cell.surface_id,PROFILE)
		var full := world.ground_sweep(cell.surface_id,position,position,PROFILE,world.geometry_revision)
		var bounded := world._ground_sweep(cell.surface_id,position,position,PROFILE,world.geometry_revision,scope)
		return full == bounded and full.ok and full.data.hit and full.data.volume_id == expected
	return false
func audit(world: WorldGeometry, graph: Dictionary, scopes: Dictionary) -> Dictionary:
	var result := {"candidates":true,"sweeps":true,"clear":true,"hits":0,"authored_hits":0}
	for id: String in graph.by_surface:
		var ids: Array = graph.by_surface[id]; var selected: Array = []
		for index: int in range(0,ids.size(),maxi(1,ids.size()/3)): selected.append(ids[index])
		if not selected.has(ids[-1]): selected.append(ids[-1])
		for left: String in selected:
			for right: String in selected:
				var p: Vector3 = graph.nodes[left].position; var q: Vector3 = graph.nodes[right].position
				var all := Prism.spatial_candidates(world._support_index.solid_prisms,world._support_index.mass_broadphase,p,q,PROFILE.radius,PROFILE.height)
				var scoped := Prism.spatial_candidates(scopes[id].items,scopes[id].index,p,q,PROFILE.radius,PROFILE.height)
				result.candidates = result.candidates and all == scoped
				var full_sweep := world.ground_sweep(id,p,q,PROFILE,world.geometry_revision)
				result.sweeps = result.sweeps and full_sweep == world._ground_sweep(id,p,q,PROFILE,world.geometry_revision,scopes[id])
				result.clear = result.clear and world._clear_path_segment(p,q,PROFILE,null,id) == world._clear_path_segment(p,q,PROFILE,null,id,scopes[id])
				if full_sweep.ok and full_sweep.data.hit:
					result.hits += 1
					if full_sweep.data.volume_id == "map_preview/volume/"+str(world._stage.volumes.size()-1): result.authored_hits += 1
	return result
func finish() -> void:
	var ok := checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("F9_CONTEXT_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
