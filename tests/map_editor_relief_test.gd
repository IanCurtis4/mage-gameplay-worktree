extends SceneTree
const Prism = preload("res://scripts/core/expedition/spatial/world_solid_prism.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_RELIEF_CHECK "+id+" "+str(ok))
func run() -> void:
	var mass := fixture(); var initial := Canonical.digest(mass)
	check("convex_terrain_mass_valid",Prism.valid(mass))
	var invalid := mass.duplicate(true); invalid.top[2] = Vector3(20,10,20)
	check("concave_cap_rejected",not Prism.valid(invalid))
	invalid = mass.duplicate(true); invalid.bottom_y = 1
	check("base_above_cap_rejected",not Prism.valid(invalid))
	invalid = mass.duplicate(true); invalid.bottom_y = NAN
	check("non_finite_mass_rejected",not Prism.valid(invalid))
	invalid = mass.duplicate(true); invalid.script = "res://scripts/main.gd"
	check("closed_passive_fields",not Prism.valid(invalid))
	var prepared := Prism.prepare(mass)
	var hit := Prism.sweep(Vector3(50,100,50),Vector3(50,-20,50),prepared,0,0)
	check("cap_height_oracle",not hit.is_empty() and absf(float(hit.fraction)-0.625) < 0.000001)
	hit = Prism.sweep(Vector3(-10,20,50),Vector3(110,20,50),prepared,0,0)
	check("sloping_face_not_bounding_box",not hit.is_empty() and absf(float(hit.fraction)-50.0/120.0) < 0.000001)
	check("ray_above_mass_clear",Prism.sweep(Vector3(-10,80,50),Vector3(110,80,50),prepared,0,0).is_empty())
	check("ray_below_base_clear",Prism.sweep(Vector3(-10,-20,50),Vector3(110,-20,50),prepared,0,0).is_empty())
	var flat := mass.duplicate(true)
	for index: int in flat.top.size(): flat.top[index].y = 10.0
	var level := Prism.prepare(flat)
	check("tangent_to_floor_is_clear",Prism.sweep(Vector3(20,10,20),Vector3(80,10,80),level,0,0).is_empty())
	check("body_height_hits_underside",not Prism.sweep(Vector3(50,-25,50),Vector3(50,-25,50),prepared,0,20).is_empty())
	check("body_radius_hits_side",not Prism.sweep(Vector3(-2,5,50),Vector3(-2,5,50),level,3,2).is_empty())
	check("zero_radius_outside_is_clear",Prism.sweep(Vector3(-2,5,50),Vector3(-2,5,50),level,0,2).is_empty())
	check("disk_outside_square_corner_clear",Prism.sweep(Vector3(-9,5,-9),Vector3(-8,5,-8),level,10,2).is_empty())
	check("disk_contact_with_square_corner_blocks",not Prism.sweep(Vector3(-7,5,-7),Vector3(-7,5,-7),level,10,2).is_empty())
	var corner_hit := Prism.sweep(Vector3(-20,5,-20),Vector3(20,5,20),level,10,2)
	check("rounded_corner_entry_distance_oracle",not corner_hit.is_empty() and absf(float(corner_hit.fraction)-(20.0-10.0/sqrt(2.0))/40.0) < 0.000001)
	check("fast_crossing_cannot_tunnel_through_rounded_corner",not Prism.sweep(Vector3(-20,5,5),Vector3(5,5,-20),level,12,2).is_empty())
	var triangle := mass.duplicate(true); triangle.top.remove_at(3)
	check("triangle_corner_outside_mass",Prism.sweep(Vector3(10,80,90),Vector3(10,-5,90),Prism.prepare(triangle),0,0).is_empty())
	var transformed := Prism.transformed(mass,1,Vector3(300,160,400),"piece/","piece/")
	check("transform_preserves_identity_namespace",Prism.valid(transformed) and transformed.volume_id == "piece/mass" and transformed.support_surface_id == "piece/floor")
	hit = Prism.sweep(Vector3(250,250,450),Vector3(250,100,450),Prism.prepare(transformed),0,0)
	check("rotated_translated_height_oracle",not hit.is_empty() and absf(float(hit.fraction)-65.0/150.0) < 0.000001)
	check("record_immutable",Canonical.digest(mass) == initial)
	var far := Prism.transformed(mass,0,Vector3(7600,200,0))
	hit = Prism.sweep(Vector3(7650,300,50),Vector3(7650,180,50),Prism.prepare(far),0,0)
	check("far_coordinates_keep_height_oracle",not hit.is_empty() and absf(float(hit.fraction)-0.625) < 0.000001)
	var polygon := PackedVector2Array([Vector2(20,20),Vector2(80,20),Vector2(80,80),Vector2(20,80)])
	check("region_above_mass_clear",not Prism.intersects_patch(prepared,polygon,{"origin":Vector3(0,60,0),"normal":Vector3.UP},12))
	check("region_under_mass_hits_underside",Prism.intersects_patch(prepared,polygon,{"origin":Vector3(0,-15,0),"normal":Vector3.UP},12))
	var normal := Kernel.plane_normal(mass.top)
	if normal.y < 0: normal = -normal
	check("region_on_own_cap_is_clear",not Prism.intersects_patch(prepared,polygon,{"origin":mass.top[0],"normal":normal},12))
	var outside := PackedVector2Array([Vector2(150,20),Vector2(180,20),Vector2(180,80),Vector2(150,80)])
	check("region_outside_footprint_clear",not Prism.intersects_patch(prepared,outside,{"origin":Vector3.ZERO,"normal":Vector3.UP},12))
	var deck := fixture(); deck.erase("bottom_y"); deck["thickness_y"] = 4.0
	check("sloping_thin_deck_valid",Prism.valid(deck))
	var thin := Prism.prepare(deck)
	check("passage_below_sloping_deck_clear",Prism.sweep(Vector3(50,15,50),Vector3(50,15,50),thin,0,3).is_empty())
	check("body_height_reaches_sloping_underside",not Prism.sweep(Vector3(50,15,50),Vector3(50,15,50),thin,0,8).is_empty())
	var moved_deck := Prism.transformed(deck,0,Vector3(7600,200,0))
	check("thin_deck_transform_preserves_underside",moved_deck.thickness_y == 4.0 and not Prism.sweep(Vector3(7650,223,50),Vector3(7650,223,50),Prism.prepare(moved_deck),0,0).is_empty() and Prism.sweep(Vector3(7650,220,50),Vector3(7650,220,50),Prism.prepare(moved_deck),0,0).is_empty())
	deck.thickness_y = 0.0; check("zero_deck_thickness_rejected",not Prism.valid(deck))
	world_cases()
	spatial_cases()
	finish()
func spatial_cases() -> void:
	var items: Array = []
	for z: int in 10:
		for x: int in 10: items.append(Prism.prepare(Prism.transformed(fixture(),0,Vector3(x*140,0,z*140),"%d_%d/"%[x,z])))
	var wide := {"volume_id":"wide","support_surface_id":"","top":[Vector3(-4000,0,-4000),Vector3(4000,0,-4000),Vector3(4000,0,4000),Vector3(-4000,0,4000)],"bottom_y":-10.0}
	items.append(Prism.prepare(wide))
	var index := Prism.spatial_index(items)
	var rng := RandomNumberGenerator.new(); rng.seed = 714
	var matches := true
	for sample: int in 80:
		var from := Vector3(rng.randf_range(-100,1600),rng.randf_range(-30,120),rng.randf_range(-100,1600))
		var to := Vector3(rng.randf_range(-100,1600),rng.randf_range(-30,120),rng.randf_range(-100,1600))
		var radius := float(sample%3)*9.0; var height := float(sample%4)*12.0
		var candidates := Prism.spatial_candidates(items,index,from,to,radius,height)
		for item: Dictionary in items:
			if not Prism.sweep(from,to,item,radius,height).is_empty() and item not in candidates: matches = false
	check("spatial_index_keeps_all_full_scan_hits",matches)
	var local := Prism.spatial_candidates(items,index,Vector3(50,20,50),Vector3(50,20,50),2,12)
	check("local_query_reduces_candidate_count",local.size() < items.size()/4)
	var huge := Prism.spatial_candidates(items,index,Vector3(0,25,0),Vector3(0,25,0),1e20,12)
	var huge_matches := true
	for item: Dictionary in items:
		if not Prism.sweep(Vector3(0,25,0),Vector3(0,25,0),item,1e20,12).is_empty() and item not in huge: huge_matches = false
	check("extreme_finite_radius_uses_safe_fallback",huge_matches and not huge.is_empty())
	var small := fixture()
	for k: int in small.top.size(): small.top[k] *= 0.1
	small.bottom_y = -1.0
	var dense: Array = []
	for z: int in 20:
		for x: int in 20: dense.append(Prism.prepare(Prism.transformed(small,0,Vector3(x*14,0,z*14),"dense_%d_%d/"%[x,z])))
	var dense_index := Prism.spatial_index(dense); var dense_matches := true
	for sample: int in 40:
		var from := Vector3(rng.randf_range(-10,280),rng.randf_range(0,8),rng.randf_range(-10,280))
		var to := Vector3(rng.randf_range(-10,280),rng.randf_range(0,8),rng.randf_range(-10,280))
		var selected := Prism.spatial_candidates(dense,dense_index,from,to,2,3)
		for item: Dictionary in dense:
			if not Prism.sweep(from,to,item,2,3).is_empty() and item not in selected: dense_matches = false
	check("dense_index_keeps_all_full_scan_hits",dense_matches)
	check("dense_point_query_prunes_unrelated_masses",Prism.spatial_candidates(dense,dense_index,Vector3(70,2,70),Vector3(70,2,70),2,3).size() < 10)
func world_cases() -> void:
	var source := Piece.empty("relief_world")
	source.layers = [{"layer_id":"floor","name":"Encosta","origin_xz":[0,0],"sample_spacing":100,"columns":2,"rows":2,"heights":[0,50,0,50],"material_masks":{},"locked":false,"protected_regions":[]}]
	var built := Terrain.compile(source)
	if not built.ok: check("world_configures_terrain_mass",false); print(built); return
	var manifest := Terrain.preview_manifest(built.package)
	var cell: Dictionary = manifest._data.stages[0].surfaces[0]
	var mass := fixture(); mass.support_surface_id = cell.surface_id
	manifest._data.stages[0]["solid_prisms"] = [mass]
	var world := WorldGeometry.new()
	check("world_configures_terrain_mass",world.configure(manifest,"terrain_preview").ok)
	var profile := {"radius":2.0,"height":12.0,"connector_kinds":["walk"]}
	var from := ExpeditionWorldPoint.create("terrain_preview",cell.surface_id,Vector3(20,10,50))
	var to := ExpeditionWorldPoint.create("terrain_preview",cell.surface_id,Vector3(80,40,50))
	check("canonical_position_supported_on_own_mass",world.position_query(from,profile,world.geometry_revision).ok)
	var motion := WorldActorMotion.new(); var walking: bool = motion.configure(world,from,profile,"relief_actor").ok
	if walking: walking = motion.plan(to,world.geometry_revision).ok
	var budget := 1000
	while walking and motion.has_route() and budget > 0:
		budget -= 1; walking = motion.advance(1.0).ok
	walking = walking and budget > 0 and motion.point().position.distance_to(to.position) < 0.001
	check("real_actor_walks_over_own_mass",walking); motion.release()
	check("generic_swept_body_sees_mass",world.sweep(from.position,to.position,profile,world.geometry_revision).data.hit)
	check("ground_sweep_excludes_only_own_support",not world.ground_sweep(cell.surface_id,from.position,to.position,profile,world.geometry_revision).data.hit)
	var polygon := PackedVector2Array([Vector2(20,20),Vector2(80,20),Vector2(80,80),Vector2(20,80)])
	check("ground_region_on_own_mass_clear",world.ground_region(from,polygon,profile,world.geometry_revision).ok)
	check("teleport_along_support_cap",world.query_attack({"geometry_rule_id":"teleport_legal","range":100,"traversal":profile},from,to,world.geometry_revision).data.hit)
	check("attack_ray_tangent_to_slope_clear",world.query_attack({"geometry_rule_id":"direct_volume","range":100},from,to,world.geometry_revision).data.hit)
	var invalid := Terrain.preview_manifest(built.package)
	var wrong := mass.duplicate(true)
	for index: int in wrong.top.size(): wrong.top[index].y += 100
	invalid._data.stages[0]["solid_prisms"] = [wrong]
	var previous := world.geometry_revision
	check("invalid_mass_binding_preserves_world",not world.configure(invalid,"terrain_preview").ok and world.geometry_revision == previous and world.position_query(from,profile,world.geometry_revision).ok)
	check("ground_sweep_rejects_stale_revision",world.ground_sweep(cell.surface_id,from.position,to.position,profile,world.geometry_revision-1).error_code == &"stale_geometry")
	world.insert_obstacle("wall",AABB(Vector3(48,-10,0),Vector3(4,100,100)),world.geometry_revision)
	check("ground_sweep_retains_other_obstacles",not world.path(from,to,profile,world.geometry_revision).ok)
	var nav := ArenaNavigation.new(); nav.configure(Rect2(0,0,100,100),[],2.0)
	var hero := PlayerActor.new(); hero.configure(nav,RunState.new(&"mage"))
	check("snapshot_actor_binds_mass_world",hero.bind_world_geometry(world,from,profile,"mass_snapshot").ok)
	var barrier := SnapshotTickBarrier.new(); barrier.acquire(hero)
	var captured := SnapshotRegistry.new().capture(hero,barrier)
	check("snapshot_captures_canonical_mass",captured.ok)
	var restored := SnapshotRegistry.new().restore(captured.snapshot) if captured.ok else {"ok":false}
	var continued := false
	if restored.ok:
		var copy: PlayerActor = restored.root
		continued = copy.world_motion.geometry._stage.solid_prisms.size() == 1 and copy.world_motion.geometry.position_query(copy.world_point(),profile,copy.world_motion.geometry.geometry_revision).ok
		copy.free()
	check("restored_mass_rebuilds_collision",continued)
	world._stage.solid_prisms[0]["untrusted"] = true
	check("malformed_mass_cannot_enter_snapshot",not SnapshotRegistry.new().capture(hero,barrier).ok)
	world._stage.solid_prisms[0].erase("untrusted"); barrier.release(); hero.free()
	var column := {"volume_id":"column","support_surface_id":"","top":[Vector3(40,80,40),Vector3(60,80,40),Vector3(60,80,60),Vector3(40,80,60)],"bottom_y":-10.0}
	manifest._data.stages[0].solid_prisms = [mass,column]
	world.configure(manifest,"terrain_preview")
	check("non_walkable_mass_blocks_attack_ray",not world.query_attack({"geometry_rule_id":"direct_volume","range":100},from,to,world.geometry_revision).data.hit)
	var route := world.path(from,to,profile,world.geometry_revision)
	check("route_detours_around_terrain_mass",route.ok and route.data.cost > from.position.distance_to(to.position))
	check("real_actor_takes_mass_detour",walk(world,from,to,profile))
	var map := Map.sample(); var replaced: Dictionary = {}
	for piece: Dictionary in map.pieces:
		var old: String = piece.piece_hash
		for port: Dictionary in piece.source.connectors: port.width = 80
		piece.piece_hash = Schema.semantic_hash(piece.source); replaced[old] = piece.piece_hash
	for instance: Dictionary in map.instances: instance.piece_hash = replaced[instance.piece_hash]
	var composed := MapCompiler.compile(map)
	if composed.ok:
		var joined := MapCompiler.manifest(composed.package)
		var middle := {"volume_id":"middle","support_surface_id":"","top":[Vector3(90,50,43),Vector3(110,50,43),Vector3(110,50,57),Vector3(90,50,57)],"bottom_y":-5.0}
		joined._data.stages[0].solid_prisms.append(middle)
		world.configure(joined,"map_preview")
		from = point_at(world,"map_preview",Vector3(20,0,25)); to = point_at(world,"map_preview",Vector3(180,0,75))
	check("mass_at_opening_keeps_free_width",composed.ok and world.path(from,to,profile,world.geometry_revision).ok)
	check("real_actor_detours_through_opening",composed.ok and walk(world,from,to,profile))
	var generation := ExpeditionWitnessGraph.new()
	var stages: Array[Dictionary] = [world._stage.duplicate(true)]
	stages[0].sockets = [{"socket_id":"from","surface_id":from.surface_id,"position":from.position,"kind":"entrance","tags":[]},{"socket_id":"to","surface_id":to.surface_id,"position":to.position,"kind":"exit","tags":[]}]
	var prepared := generation.prepare(stages,profile)
	var witness := generation.path("from","to") if prepared.ok else {"ok":false}
	check("generation_witness_uses_free_opening_width",witness.ok)
	check("generation_witness_accounts_for_terrain_mass",witness.ok and witness.data.cost > from.position.distance_to(to.position) and not witness.data.connection_ids.is_empty() and witness.data.points[-1] == to.to_data())
static func point_at(world: WorldGeometry, stage: String, position: Vector3) -> ExpeditionWorldPoint:
	for cell: Dictionary in world._stage.surfaces:
		if Kernel.contains(cell,position): return ExpeditionWorldPoint.create(stage,cell.surface_id,position)
	return null
static func walk(world: WorldGeometry, from: ExpeditionWorldPoint, to: ExpeditionWorldPoint, profile: Dictionary) -> bool:
	var motion := WorldActorMotion.new()
	if not motion.configure(world,from,profile,"relief_walk").ok: return false
	if not motion.plan(to,world.geometry_revision).ok: motion.release(); return false
	var ok := true; var budget := 2000
	while ok and motion.has_route() and budget > 0:
		budget -= 1; ok = motion.advance(1.0).ok
	ok = ok and budget > 0 and motion.point().position.distance_to(to.position) < 0.001
	motion.release(); return ok
static func fixture() -> Dictionary:
	return {"volume_id":"mass","top":[Vector3(0,0,0),Vector3(100,50,0),Vector3(100,50,100),Vector3(0,0,100)],"bottom_y":-10.0,"support_surface_id":"floor"}
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_RELIEF_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
