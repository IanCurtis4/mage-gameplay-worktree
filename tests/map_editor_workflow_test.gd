extends SceneTree
## Checkpoint49 (F9-06/07/08, P6a): carrying a document forward along the flow.
## Two-room fixture: a changed piece enters the map, the moved map enters the
## encounters (anchors follow their instance and settle on the new ground, the
## plan is re-certified with the same slots), the encounters enter the patrols
## (waypoints follow, routes keep their slots). Nothing mutates the input; a
## removed instance, a lost layer or a missing slot names the entity and the
## screen; apply is one undo on the base it was made from.
const Carry = preload("res://scripts/map_authoring/workflow/carry_forward.gd")
const Rooms = preload("res://tests/map_editor_root_synthesis_test.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const PopulationSession = preload("res://scripts/map_authoring/population/population_session.gd")
const DocumentSession = preload("res://scripts/map_authoring/document/document_session.gd")
const SHIFT := Vector3(128,16,0)
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_WORKFLOW_CHECK "+id+" "+str(ok))
static func raised(room: Dictionary, lift: float) -> Dictionary:
	var copy := room.duplicate(true)
	for layer: Dictionary in copy.layers:
		for i: int in layer.heights.size(): layer.heights[i] = float(layer.heights[i])+lift
	for connector: Dictionary in copy.connectors: connector.position_xyz[1] = float(connector.position_xyz[1])+lift
	return copy
static func shifted(map: Dictionary, offset: Vector3) -> Dictionary:
	var copy := map.duplicate(true)
	for instance: Dictionary in copy.instances:
		instance.position_xyz = [float(instance.position_xyz[0])+offset.x,float(instance.position_xyz[1]),float(instance.position_xyz[2])+offset.z]
	return copy
static func at(entry: Dictionary, field: String = "position_xyz") -> Vector3:
	return Vector3(float(entry[field][0]),float(entry[field][1]),float(entry[field][2]))
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var built := Rooms.fixture()
	var room: Dictionary = built.map.pieces[0].source
	var map: Dictionary = built.map; var population: Dictionary = built.population; var patrols: Dictionary = built.patrols
	check("fixture_ready",built.planned.ok and Rooms.PatrolCompiler.compile(patrols).ok)
	# Up to date and unrelated pieces.
	var other := room.duplicate(true); other.document_id = "another_room"
	check("up_to_date_and_unrelated_are_reported",Carry.piece_into_map(map,room).code == "flow_up_to_date" and Carry.map_into_population(population,map).code == "flow_up_to_date" and Carry.population_into_patrol(patrols,population).code == "flow_up_to_date" and Carry.piece_into_map(map,other).code == "flow_piece_not_in_map")
	# 1. Piece → map.
	var map_hash := MapDocument.hash_source(map)
	var room2 := raised(room,SHIFT.y)
	var into_map := Carry.piece_into_map(map,room2)
	var new_hash := Schema.semantic_hash(room2)
	check("piece_replaces_its_snapshot",into_map.ok and into_map.source.pieces.size() == 1 and into_map.source.pieces[0].piece_hash == new_hash and into_map.diff.instances == ["east_room","west_room"] and into_map.source.instances.all(func(i: Dictionary) -> bool: return i.piece_hash == new_hash) and into_map.compiled_hash.length() == 64 and MapDocument.hash_source(map) == map_hash)
	# 2. Map → encounters: both rooms moved together and raised.
	var map2 := shifted(into_map.get("source",map),SHIFT)
	var population_hash := PopulationDocument.hash_source(population)
	var t := Time.get_ticks_msec()
	var into_population := Carry.map_into_population(population,map2)
	var carry_ms := Time.get_ticks_msec()-t
	var followed: bool = into_population.ok
	if followed:
		var before := population; var after: Dictionary = into_population.source
		followed = at(after.entrance[0]).is_equal_approx(at(before.entrance[0])+SHIFT) and at(after.brushes[0],"center_xyz").is_equal_approx(at(before.brushes[0],"center_xyz")+SHIFT) and at(after.interactions[0]).is_equal_approx(at(before.interactions[0])+SHIFT)
		for slot: Dictionary in after.slots:
			var old := Rooms.Piece._find(before.slots,"slot_id",slot.slot_id)
			if old.is_empty() or not at(slot).is_equal_approx(at(old)+SHIFT): followed = false
	check("anchors_follow_their_instance_and_settle",followed and "entrance" in into_population.diff.anchors_moved and "finish" in into_population.diff.anchors_moved and PopulationDocument.hash_source(population) == population_hash)
	var ids := func(root: Dictionary) -> Array:
		var list: Array = root.slots.map(func(slot: Dictionary) -> String: return slot.slot_id); list.sort(); return list
	check("plan_is_recertified_with_the_same_slots",into_population.ok and into_population.diff.plan_recertified and ids.call(into_population.source) == ids.call(population) and into_population.source.plan_hash == PopulationDocument.recipe_hash(into_population.source) and into_population.compiled_hash.length() == 64)
	var again := Carry.map_into_population(population,map2)
	check("carry_is_deterministic",again.ok and again.source_hash == into_population.get("source_hash",""))
	# 3. Encounters → patrols.
	var into_patrol := Carry.population_into_patrol(patrols,into_population.get("source",population))
	var waypoints_ok: bool = into_patrol.ok
	if waypoints_ok:
		for n: int in patrols.patrols[0].waypoints.size():
			if not at(into_patrol.source.patrols[0].waypoints[n]).is_equal_approx(at(patrols.patrols[0].waypoints[n])+SHIFT): waypoints_ok = false
	check("waypoints_follow_and_routes_keep_slots",waypoints_ok and into_patrol.source.patrols[0].slot_ids == patrols.patrols[0].slot_ids and into_patrol.compiled_hash.length() == 64 and into_patrol.diff.anchors_moved.size() == 2)
	# 4. Localized refusals.
	var renamed: Dictionary = map2.duplicate(true)
	for instance: Dictionary in renamed.instances:
		if instance.instance_id == "east_room": instance.instance_id = "east_wing"
	for link: Dictionary in renamed.links:
		if link.a_instance == "east_room": link.a_instance = "east_wing"
		if link.b_instance == "east_room": link.b_instance = "east_wing"
	var missing := Carry.map_into_population(population,renamed)
	check("removed_instance_names_the_marker",missing.code == "flow_instance_missing" and missing.diagnostics[0].entity_id == "finish" and missing.diagnostics[0].step == "population")
	var floor_room := room.duplicate(true); floor_room.layers[0].layer_id = "floor"; floor_room.connectors[0].surface_id = "floor"; floor_room.regions[0].layer_id = "floor"
	var floor_map := Carry.piece_into_map(map,floor_room)
	var lost := Carry.map_into_population(population,floor_map.get("source",map))
	check("lost_layer_names_the_marker",floor_map.ok and lost.code == "flow_support_lost" and lost.diagnostics[0].entity_id == "entrance" and lost.diagnostics[0].step == "population")
	var without := population.duplicate(true); without.slots = without.slots.filter(func(slot: Dictionary) -> bool: return slot.slot_id != "guard")
	var orphan := Carry.population_into_patrol(patrols,without)
	check("missing_slot_names_the_route",orphan.code == "flow_slot_missing" and orphan.diagnostics[0].entity_id == "watch" and orphan.diagnostics[0].step == "patrol")
	# 5. One undo on the base it was made from.
	var session := PopulationSession.new(); session.replace(population)
	var applied := Carry.apply(into_population,session,session.data)
	var undone := session.undo()
	var back := PopulationDocument.hash_source(session.data) == population_hash
	var changed: Dictionary = population.duplicate(true); changed.name = "Encontros editados"; session.apply(changed)
	var stale := Carry.apply(into_population,session,session.data)
	check("apply_is_one_undo_on_its_base",applied.ok and applied.output_hash == into_population.source_hash and undone and back and stale.code == "flow_stale_proposal")
	# 6. An opened piece has the hash its map snapshot names (no false "changed").
	var read := Schema.read(FileAccess.get_file_as_bytes("res://data/map_authoring/sanctuary_woods_clearing.source.json"))
	var bosque: Dictionary = MapDocument.read(FileAccess.get_file_as_bytes("res://data/map_authoring/sanctuary_woods.map.json")).data
	var opened := DocumentSession.new(); opened.replace(read.data)
	var named := false
	for snapshot: Dictionary in bosque.pieces:
		if snapshot.source.document_id == "sanctuary_woods_clearing": named = snapshot.piece_hash == Schema.semantic_hash(opened.document().to_data())
	check("opened_piece_matches_its_snapshot",named and Carry.piece_into_map(bosque,opened.document().to_data()).code == "flow_up_to_date")
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_WORKFLOW_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"metrics":{"carry_ms":carry_ms}})); quit(0 if ok else 1)
