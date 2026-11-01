extends SceneTree
## Checkpoint44 (F9-05/08, P3b): regional variation of one map instance with the
## map, the population and the patrols as root. A small two-room map (one shared
## piece, two instances) keeps every compile fast; the Bosque proof is measured
## apart. New snapshot for one instance, anchors reconciled by layer, bodies and
## patrol legs kept, encounters redrawn only inside, one undo per root.
const Root = preload("res://scripts/map_authoring/synthesis/root_synthesis.gd")
const Piece = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Source = preload("res://scripts/map_authoring/document/source_document.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PopulationSession = preload("res://scripts/map_authoring/population/population_session.gd")
const PatrolSession = preload("res://scripts/map_authoring/patrol/patrol_session.gd")
const AREA := [[192,128],[576,128],[576,640],[192,640]]
const SPEC := {"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1","weight":1}
var checks: Array[Dictionary] = []
var metrics := {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_ROOT_SYNTH_CHECK "+id+" "+str(ok))
static func piece_source() -> Dictionary:
	var data := Source.empty("variation_room","Sala de variação")
	var heights: Array = []; heights.resize(169); heights.fill(0.0)
	data.layers = [{"layer_id":"ground","name":"Chão","origin_xz":[0,0],"sample_spacing":64,"columns":13,"rows":13,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}]
	data.connectors = [{"connector_id":"east","surface_id":"ground","position_xyz":[768,0,384],"normal_xyz":[1,0,0],"kind":"walk","width":192,"headroom":100,"tags":["ruin"],"direction":"both"}]
	data.regions = [{"region_id":"variation_area","layer_id":"ground","polygon_xz":AREA,"purpose":"encounter"}]
	return data
static func fixture_at(built: Dictionary, instance: String, x: float, z: float) -> Dictionary:
	var found := Root.locate(built,instance+"/layer/ground",Vector2(x,z))
	return {"surface_id":found.get("surface_id",""),"position_xyz":[x,found.get("y",0.0),z]}
static func request(kind: String, root: Dictionary, instance: String, piece_hash: String, channels: Dictionary, seed: String = "17") -> Dictionary:
	return {"algorithm_revision":Piece.REVISION,"seed_text":seed,"base_hash":Root.root_hash(kind,root),"target":{"instance_id":instance,"piece_hash":piece_hash,"layer_id":"ground"},"selection":{"region_id":"variation_area"},"channels":channels,"preserve":{"entity_ids":[],"region_ids":[]}}
static func relief() -> Dictionary: return {"mode":"relief","amplitude":32.0,"feature_size":192.0,"roughness":0.5,"falloff":32.0}
static func keep() -> Dictionary: return {"mode":"preserve"}
## The two-room fixture, also used by the native test.
static func fixture() -> Dictionary:
	var room := piece_source(); var room_hash := Schema.semantic_hash(room)
	var map := MapDocument.empty("variation_map"); map.name = "Duas salas · variação"
	map.context = {"biome_id":"ruin","overrides":[],"version":1}
	map.pieces = [{"piece_hash":room_hash,"source":room}]
	map.instances = [{"instance_id":"west_room","piece_hash":room_hash,"position_xyz":[0,0,0],"rotation_quarters":0},{"instance_id":"east_room","piece_hash":room_hash,"position_xyz":[1536,0,768],"rotation_quarters":2}]
	map.links = [{"link_id":"seam","a_instance":"west_room","a_connector":"east","b_instance":"east_room","b_connector":"east"}]
	var base_index := Root.index(map)
	var population := PopulationDocument.empty("variation_encounters"); population.map = [map]
	population.entrance = [fixture_at(base_index,"west_room",96,384)]
	var field := fixture_at(base_index,"west_room",384,384)
	population.brushes = [PopulationDocument.brush("field",field.surface_id,Root.vector(field.position_xyz),SPEC)]
	population.brushes[0].radius = 160
	var finish := fixture_at(base_index,"east_room",1344,384)
	population.interactions = [{"interaction_id":"finish","kind":"phase_completion","surface_id":finish.surface_id,"position_xyz":finish.position_xyz,"target_id":""}]
	var guard := fixture_at(base_index,"west_room",448,512)
	population.slots = [{"slot_id":"guard","brush_id":"field","surface_id":guard.surface_id,"position_xyz":guard.position_xyz,"species_id":SPEC.species_id,"category":SPEC.category,"origin_id":SPEC.origin_id,"fixed":true,"site_id":""}]
	var t := Time.get_ticks_msec()
	# The pinned guard counts in the brush quota: two drawn slots plus the guard.
	var planned := Population.regenerate(population)
	if planned.ok: population = planned.data
	var patrols := PatrolDocument.empty("variation_patrols"); patrols.population = [population]
	var north := fixture_at(base_index,"west_room",448,320)
	patrols.patrols = [{"patrol_id":"watch","revision":1,"mode":"ping_pong","slot_ids":["guard"],"waypoints":[{"point_id":"north","surface_id":north.surface_id,"position_xyz":north.position_xyz,"wait_seconds":1},{"point_id":"south","surface_id":guard.surface_id,"position_xyz":guard.position_xyz,"wait_seconds":1}]}]
	return {"room_hash":room_hash,"map":map,"base_index":base_index,"population":population,"planned":planned,"patrols":patrols,"plan_ms":Time.get_ticks_msec()-t}
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var built := fixture()
	var room_hash: String = built.room_hash; var map: Dictionary = built.map; var base_index: Dictionary = built.base_index
	var population: Dictionary = built.population; var planned: Dictionary = built.planned; var patrols: Dictionary = built.patrols
	metrics["plan_ms"] = built.plan_ms
	var t := 0
	var patrol_ok := PatrolCompiler.compile(patrols)
	check("fixture_plans_and_compiles",base_index.ok and planned.ok and population.slots.size() == int(population.brushes[0].quantity) and patrol_ok.ok)
	# 1. Closed requests per root.
	var all3 := {"terrain":relief(),"materials":keep(),"objects":keep()}
	var with_encounters := all3.duplicate(true); with_encounters["encounters"] = keep()
	var with_patrols := with_encounters.duplicate(true); with_patrols["patrols"] = {"mode":"regenerate"}
	var wrong_piece := request("map",map,"west_room","0".repeat(64),all3)
	var stale := request("map",map,"west_room",room_hash,all3); stale.base_hash = "1".repeat(64)
	check("requests_are_closed_per_root",Root.prepare("map",map,request("map",map,"west_room",room_hash,with_encounters)).code == "synthesis_channel_missing" and Root.prepare("population",population,request("population",population,"west_room",room_hash,all3)).code == "synthesis_channel_missing" and Root.prepare("patrol",patrols,request("patrol",patrols,"west_room",room_hash,with_patrols)).code == "synthesis_patrol_recipe" and Root.prepare("map",map,wrong_piece).code == "synthesis_target_missing" and Root.prepare("map",map,stale).code == "base_diverged")
	# 2. Map root: a new snapshot for one instance only.
	t = Time.get_ticks_msec()
	var varied := Root.prepare("map",map,request("map",map,"west_room",room_hash,all3))
	metrics["map_ms"] = Time.get_ticks_msec()-t
	var west: Dictionary = Piece._find(varied.source.instances,"instance_id","west_room") if varied.ok else {}
	var east: Dictionary = Piece._find(varied.source.instances,"instance_id","east_room") if varied.ok else {}
	check("map_variation_is_a_new_snapshot_for_one_instance",varied.ok and west.piece_hash != room_hash and east.piece_hash == room_hash and varied.source.pieces.size() == 2 and varied.diff.snapshots_added == [west.piece_hash] and varied.diff.snapshots_removed.is_empty() and varied.source.links == map.links and varied.diff.piece.terrain_samples.size() > 0 and not varied.compiled_hash.is_empty())
	var again := Root.prepare("map",varied.source,request("map",varied.source,"west_room",west.piece_hash,all3,"23")) if varied.ok else {"ok":false}
	check("an_unreferenced_snapshot_is_dropped",again.ok and again.diff.snapshots_removed == [west.piece_hash] and again.source.pieces.size() == 2 and not Piece._find(again.source.pieces,"piece_hash",room_hash).is_empty())
	# 3. Population root, encounters preserved.
	t = Time.get_ticks_msec()
	var kept := Root.prepare("population",population,request("population",population,"west_room",room_hash,with_encounters))
	metrics["population_preserve_ms"] = Time.get_ticks_msec()-t
	var same_slots: bool = kept.ok
	if kept.ok:
		var before_ids: Array = []; var after_ids: Array = []
		for slot: Dictionary in population.slots: before_ids.append([slot.slot_id,slot.position_xyz])
		for slot: Dictionary in kept.source.slots: after_ids.append([slot.slot_id,slot.position_xyz])
		before_ids.sort(); after_ids.sort(); same_slots = before_ids == after_ids and kept.source.plan_hash == PopulationDocument.recipe_hash(kept.source) and kept.diff.slots_added.is_empty() and kept.diff.slots_removed.is_empty()
	check("preserved_encounters_keep_every_slot",same_slots and kept.diff.piece.terrain_samples.size() > 0)
	var new_index := Root.index(kept.source.map[0]) if kept.ok else {"ok":false}
	var follow: bool = kept.ok and new_index.ok
	var heights_kept: bool = follow
	if follow:
		for anchor: Dictionary in Root.anchors("population",kept.source):
			if new_index.families.get(anchor.ref.surface_id,"") != "west_room/layer/ground": continue
			var p := Root.vector(anchor.ref[anchor.field])
			var now := Root.locate(new_index,"west_room/layer/ground",Vector2(p.x,p.z))
			if not now.ok or now.surface_id != anchor.ref.surface_id: follow = false
			if anchor.body:
				var was := Root.locate(base_index,"west_room/layer/ground",Vector2(p.x,p.z))
				if absf(float(now.get("y",0.0))-float(was.get("y",0.0))) > Root.HEIGHT_EPS: heights_kept = false
			elif absf(float(now.get("y",0.0))-p.y) > 0.0001: follow = false
	check("anchors_follow_their_layer_not_the_nearest_floor",follow and kept.diff.anchors_remapped.size() > 0)
	check("bodies_keep_their_height",heights_kept)
	var twice := Root.prepare("population",population,request("population",population,"west_room",room_hash,with_encounters))
	check("same_request_same_hash",twice.ok and kept.ok and twice.source_hash == kept.source_hash and twice.compiled_hash == kept.compiled_hash)
	# 4. Population root, encounters redrawn only inside the selection.
	var redraw := with_encounters.duplicate(true); redraw.encounters = {"mode":"regenerate"}
	var moved := population.duplicate(true)
	moved.brushes[0].seed = "41"; moved.plan_hash = PopulationDocument.recipe_hash(moved)
	t = Time.get_ticks_msec()
	var redrawn := Root.prepare("population",moved,request("population",moved,"west_room",room_hash,redraw))
	metrics["population_regenerate_ms"] = Time.get_ticks_msec()-t
	var inside: bool = redrawn.ok and not redrawn.diff.slots_removed.is_empty() and redrawn.diff.slots_added.size() == redrawn.diff.slots_removed.size() and "guard" not in redrawn.diff.slots_removed
	if redrawn.ok:
		var selection := Piece._polygon(AREA)
		for id: String in redrawn.diff.slots_removed:
			var old := Piece._find(moved.slots,"slot_id",id); var p := Root.vector(old.position_xyz)
			if not Piece._disk_inside(Vector2(p.x,p.z),Root.SLOT_RADIUS,selection): inside = false
		for id: String in redrawn.diff.slots_added:
			var slot := Piece._find(redrawn.source.slots,"slot_id",id); var p := Root.vector(slot.position_xyz)
			if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),selection): inside = false
		for slot: Dictionary in moved.slots:
			if slot.slot_id in redrawn.diff.slots_removed: continue
			var now := Piece._find(redrawn.source.slots,"slot_id",slot.slot_id)
			if now.is_empty() or now.position_xyz != slot.position_xyz: inside = false
		var brush_count := 0
		for slot: Dictionary in redrawn.source.slots:
			if slot.brush_id == "field": brush_count += 1
		if brush_count != int(moved.brushes[0].quantity) or redrawn.source.plan_hash != PopulationDocument.recipe_hash(redrawn.source): inside = false
	check("regenerate_redraws_only_free_slots_inside",inside)
	# 5. Patrol root: the patrol's slot and legs stay.
	var patrol_request := request("patrol",patrols,"west_room",room_hash,with_encounters.duplicate(true))
	patrol_request.channels.encounters = {"mode":"regenerate"}; patrol_request.channels["patrols"] = keep()
	t = Time.get_ticks_msec()
	var routed := Root.prepare("patrol",patrols,patrol_request)
	metrics["patrol_ms"] = Time.get_ticks_msec()-t
	var legs: bool = routed.ok and "guard" not in routed.diff.slots_removed and routed.metrics.protected_legs == 1
	if routed.ok:
		var routed_index := Root.index(routed.source.population[0].map[0])
		for point: Dictionary in routed.source.patrols[0].waypoints:
			var p := Root.vector(point.position_xyz)
			var was := Root.locate(base_index,"west_room/layer/ground",Vector2(p.x,p.z)); var now := Root.locate(routed_index,"west_room/layer/ground",Vector2(p.x,p.z))
			if not now.ok or now.surface_id != point.surface_id or absf(float(now.y)-float(was.y)) > Root.HEIGHT_EPS: legs = false
		for index: int in routed.diff.piece.terrain_samples:
			var sample := Vector2(index % 13,index / 13)*64.0
			if Piece._segment_touches(Vector2(448,320),Vector2(448,512),Root.ANCHOR_RADIUS,Piece._square(sample,64.0)): legs = false
	check("patrol_slot_and_legs_stay",legs)
	# 6. One undo per root; a stale proposal is refused.
	var session := PopulationSession.new(); session.replace(population)
	var base_hash := PopulationDocument.hash_source(population)
	var applied := Root.apply(kept,session,base_hash)
	var repeated := Root.apply(kept,session,base_hash)
	session.undo()
	var patrol_session := PatrolSession.new(); patrol_session.replace(patrols)
	var patrol_applied := Root.apply(routed,patrol_session,PatrolDocument.hash_source(patrols))
	patrol_session.undo()
	check("apply_is_one_undo_per_root",applied.ok and repeated.code == "base_diverged" and PopulationDocument.hash_source(session.data) == base_hash and not session.can_undo() and patrol_applied.ok and PatrolDocument.hash_source(patrol_session.data) == PatrolDocument.hash_source(patrols))
	var cancelled := Root.prepare("population",population,request("population",population,"west_room",room_hash,with_encounters),func(_p: float) -> bool: return true)
	check("cancel_refuses_without_mutation",cancelled.code == "cancelled" and PopulationDocument.hash_source(population) == base_hash)
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ROOT_SYNTH_METRICS "+JSON.stringify(metrics))
	print("F9_ROOT_SYNTH_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
