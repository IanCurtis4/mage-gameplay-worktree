extends SceneTree

const Planner = preload("res://scripts/core/expedition/population/population_planner.gd")
const Manifest = preload("res://scripts/core/expedition/model/manifest.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const World = preload("res://scripts/core/expedition/spatial/world_geometry.gd")
const CampaignFixture = preload("res://tests/fixtures/e07/f5/campaign_fixture.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")

const ENTRY_STAGE := "entry"
const FIELD_SLOT := "entry_field"
const FAR_OFFSET := Vector3(100000.0, 0.0, 100000.0)
const EXPECTED_CHECKS := 18

var checks: Array[Dictionary] = []
var failed: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(id: String, ok: bool, detail: Variant = null) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	if not ok: failed.append(id)

func _run() -> void:
	var generated: Dictionary = ExpeditionAssembler.build(CampaignFixture.input())
	check("existing_f5_fixture_generates_manifest",generated.get("ok",false))
	if not generated.get("ok",false): print(generated); finish(); return
	var manifest: ExpeditionManifest = generated.data.manifest
	var profile: Dictionary = traversal_profile(manifest)
	var world: World = world_for(manifest)
	check("entry_world_configures",world != null)
	if world == null: finish(); return
	var entry: ExpeditionWorldPoint = entrance_point(stage_record(manifest,ENTRY_STAGE))
	check("entry_socket_resolves",entry != null)
	if entry == null: finish(); return
	var field_slot: Dictionary = manifest.population_plan().find_slot(FIELD_SLOT)
	var field_home: ExpeditionWorldPoint = Planner.point(field_slot.home)
	var field_points: Array[ExpeditionWorldPoint] = [field_home]
	var field_ids: Array[String] = [FIELD_SLOT]

	# Positive set: every entry-stage slot home must pass both the reference and the batch.
	var entry_slots: Array[Dictionary] = []
	for slot: Dictionary in manifest.population_plan().slots():
		if slot.get("stage_id","") == ENTRY_STAGE: entry_slots.append(slot)
	check("entry_stage_has_population_slots",not entry_slots.is_empty(),entry_slots.size())
	var homes: Array[ExpeditionWorldPoint] = []
	var home_ids: Array[String] = []
	var two_way_reference: bool = true
	for slot: Dictionary in entry_slots:
		var home: ExpeditionWorldPoint = Planner.point(slot.home)
		homes.append(home)
		home_ids.append(String(slot.slot_id))
		if not Candidate._both(world,entry,home,profile): two_way_reference = false
	check("entry_slot_homes_have_two_way_reference",not entry_slots.is_empty() and two_way_reference)
	var positive: Dictionary = Candidate._round_trips(world,entry,homes,profile,home_ids,"body_unreachable")
	check("entry_slots_pass_round_trip_batch",positive.get("ok",false) == true,positive)

	var no_points: Array[ExpeditionWorldPoint] = []
	var no_ids: Array[String] = []
	var empty: Dictionary = Candidate._round_trips(world,entry,no_points,profile,no_ids,"body_unreachable")
	check("empty_point_list_returns_ok",empty.get("ok",false) == true,empty)

	# One-way fixture: outward route exists, return route does not. Must be rejected.
	var one_way: Dictionary = one_way_fixture(manifest,profile)
	var one_way_world: World = world_for(one_way.manifest)
	var one_way_ready: bool = one_way.get("configured",false) and one_way.get("connection_found",false) and one_way_world != null
	check("one_way_fixture_configures_with_connection",one_way_ready)
	if not one_way_ready: finish(); return
	check("one_way_pair_reference_rejects_return_path",not Candidate._both(one_way_world,entry,field_home,profile))
	var one_way_result: Dictionary = Candidate._round_trips(one_way_world,entry,field_points,profile,field_ids,"body_unreachable")
	check("one_way_round_trip_reports_body_unreachable",one_way_result.get("ok",true) == false and one_way_result.get("code","") == "body_unreachable" and one_way_result.get("entity","") == FIELD_SLOT,one_way_result)

	# Disconnected fixture: no route in either direction.
	var disconnected: Dictionary = disconnected_fixture(manifest)
	var disconnected_world: World = world_for(disconnected.manifest)
	var disconnected_ready: bool = disconnected.get("configured",false) and disconnected.get("connection_found",false) and disconnected_world != null
	check("disconnected_fixture_configures_with_connection",disconnected_ready)
	if not disconnected_ready: finish(); return
	check("disconnected_pair_reference_is_false",not Candidate._both(disconnected_world,entry,field_home,profile))
	var disconnected_result: Dictionary = Candidate._round_trips(disconnected_world,entry,field_points,profile,field_ids,"body_unreachable")
	check("disconnected_round_trip_reports_body_unreachable",disconnected_result.get("ok",true) == false and disconnected_result.get("code","") == "body_unreachable" and disconnected_result.get("entity","") == FIELD_SLOT,disconnected_result)

	# Order: an illegal point must not break the batch, and the first failure in original order is reported.
	var far_point: ExpeditionWorldPoint = offset_point(field_home,FAR_OFFSET)
	var far_point_other: ExpeditionWorldPoint = offset_point(field_home,-FAR_OFFSET)
	var illegal_middle: Array[ExpeditionWorldPoint] = [field_home,far_point,field_home]
	var order_ids: Array[String] = ["a","b","c"]
	var order_result: Dictionary = Candidate._round_trips(world,entry,illegal_middle,profile,order_ids,"interaction_unreachable")
	check("order_reports_first_illegal_point_without_breaking_batch",order_result.get("ok",true) == false and order_result.get("code","") == "interaction_unreachable" and order_result.get("entity","") == "b",order_result)
	var illegal_pair: Array[ExpeditionWorldPoint] = [far_point,field_home,far_point_other]
	var pair_ids: Array[String] = ["x","a","y"]
	var pair_result: Dictionary = Candidate._round_trips(world,entry,illegal_pair,profile,pair_ids,"interaction_unreachable")
	check("order_reports_first_failure_in_original_order",pair_result.get("ok",true) == false and pair_result.get("code","") == "interaction_unreachable" and pair_result.get("entity","") == "x",pair_result)

	# Negative label is only a label: a list of valid points passes under any label.
	var label_result: Dictionary = Candidate._round_trips(world,entry,homes,profile,home_ids,"interaction_unreachable")
	check("valid_points_pass_regardless_of_negative_label",label_result.get("ok",false) == true,label_result)

	# No mutation: revisions and manifest hash are unchanged across candidate calls.
	# world.configuration_revision is not in the provided files, so it is read from the batch envelope data.
	var geometry_before: int = world.geometry_revision
	var configuration_before: Variant = configuration_revision_of(world,entry,field_home,profile)
	var manifest_before: String = manifest.canonical_hash()
	Candidate._round_trips(world,entry,homes,profile,home_ids,"body_unreachable")
	Candidate._round_trips(world,entry,illegal_middle,profile,order_ids,"interaction_unreachable")
	Candidate._both(world,entry,field_home,profile)
	var mutated: bool = world.geometry_revision != geometry_before or configuration_revision_of(world,entry,field_home,profile) != configuration_before or manifest.canonical_hash() != manifest_before
	check("candidate_does_not_mutate_world_or_manifest",configuration_before != null and not mutated,{"geometry_before":geometry_before,"configuration_before":configuration_before})

	# Determinism: identical calls return identical dictionaries, positive and negative.
	var positive_again: Dictionary = Candidate._round_trips(world,entry,homes,profile,home_ids,"body_unreachable")
	var order_again: Dictionary = Candidate._round_trips(world,entry,illegal_middle,profile,order_ids,"interaction_unreachable")
	check("repeated_calls_return_identical_dictionaries",positive == positive_again and order_result == order_again,{"positive":positive_again,"order":order_again})
	finish()

func traversal_profile(manifest: ExpeditionManifest) -> Dictionary:
	var data: Dictionary = manifest.to_data()
	var input_data: Dictionary = data["input"]
	var traversal: Dictionary = input_data["traversal"]
	return traversal.duplicate(true)

func world_for(manifest: ExpeditionManifest) -> World:
	var world := World.new()
	if not world.configure(manifest,ENTRY_STAGE).get("ok",false): return null
	return world

func entrance_point(stage: Dictionary) -> ExpeditionWorldPoint:
	var socket: Dictionary = entry_socket_record(stage)
	if socket.is_empty(): return null
	return Point.create(ENTRY_STAGE,socket.get("surface_id",""),socket.get("position",Vector3.ZERO))

func offset_point(origin_point: ExpeditionWorldPoint, offset: Vector3) -> ExpeditionWorldPoint:
	return Point.create(ENTRY_STAGE,origin_point.surface_id,origin_point.position+offset)

func configuration_revision_of(world: World, entry: ExpeditionWorldPoint, target: ExpeditionWorldPoint, profile: Dictionary) -> Variant:
	var targets: Array[ExpeditionWorldPoint] = [target]
	var probe: Dictionary = world.connectivity_batch(entry,targets,profile,world.geometry_revision)
	if not probe.get("ok",false): return null
	var data: Dictionary = probe.get("data",{})
	return data.get("configuration_revision",null)

func one_way_fixture(original: ExpeditionManifest, mob_profile: Dictionary) -> Dictionary:
	var manifest := copy_manifest(original)
	var stage: Dictionary = stage_record(manifest,"entry")
	var entry_socket: Dictionary = entry_socket_record(stage)
	var source_slot: Dictionary = manifest.population_plan().find_slot("entry_field")
	var entry_surface: String = entry_socket.get("surface_id","")
	var home_surface: String = source_slot.get("home",{}).get("surface_id","")
	var endpoints: Dictionary = endpoint_surface_index(stage)
	var found := false
	for connection: Dictionary in stage.connections:
		var a_surface: String = endpoints.get(connection.a_connector,"")
		var b_surface: String = endpoints.get(connection.b_connector,"")
		if (a_surface == entry_surface and b_surface == home_surface) or (a_surface == home_surface and b_surface == entry_surface):
			connection.forward = a_surface == entry_surface
			connection.backward = b_surface == entry_surface
			found = true
	var world := World.new()
	var configured: Dictionary = world.configure(manifest,"entry")
	var entry_position: Vector3 = entry_socket.get("position",Vector3.ZERO)
	var entry: ExpeditionWorldPoint = Point.create("entry",entry_surface,entry_position)
	var home: ExpeditionWorldPoint = Planner.point(source_slot.home)
	return {"manifest":manifest,"configured":configured.get("ok",false),"connection_found":found,"entry":entry,"home":home,"profile":mob_profile.duplicate(true)}

func disconnected_fixture(original: ExpeditionManifest) -> Dictionary:
	var manifest := copy_manifest(original)
	var stage: Dictionary = stage_record(manifest,"entry")
	var entry_socket: Dictionary = entry_socket_record(stage)
	var source_slot: Dictionary = manifest.population_plan().find_slot("entry_field")
	var entry_surface: String = entry_socket.get("surface_id","")
	var home_surface: String = source_slot.get("home",{}).get("surface_id","")
	var endpoints: Dictionary = endpoint_surface_index(stage)
	var found := false
	for connection: Dictionary in stage.connections:
		var a_surface: String = endpoints.get(connection.a_connector,"")
		var b_surface: String = endpoints.get(connection.b_connector,"")
		if (a_surface == entry_surface and b_surface == home_surface) or (a_surface == home_surface and b_surface == entry_surface):
			connection.forward = false
			connection.backward = false
			found = true
	var world := World.new()
	var configured: Dictionary = world.configure(manifest,"entry")
	return {"manifest":manifest,"configured":configured.get("ok",false),"connection_found":found}

func entry_socket_record(stage: Dictionary) -> Dictionary:
	for socket: Dictionary in stage.get("sockets",[]):
		if socket.socket_id == stage.get("entrance",""): return socket
	return {}

func stage_record(manifest: ExpeditionManifest, stage_id: String) -> Dictionary:
	for stage: Dictionary in manifest._data.get("stages",[]):
		if stage.stage_id == stage_id: return stage
	return {}

func endpoint_surface_index(stage: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for endpoint: Dictionary in stage.get("connectors",[]): result[endpoint.connector_id] = endpoint.surface_id
	return result

func copy_manifest(original: ExpeditionManifest) -> ExpeditionManifest:
	var result := Manifest.new()
	result._data = original.to_data()
	return result

func finish() -> void:
	var ok := failed.is_empty() and checks.size() == EXPECTED_CHECKS
	print("F9_CANDIDATE_BATCH_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"failed":failed,"expected_count":EXPECTED_CHECKS}))
	quit(0 if ok else 1)
