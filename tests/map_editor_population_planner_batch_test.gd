extends SceneTree

const Planner = preload("res://scripts/core/expedition/population/population_planner.gd")
const Manifest = preload("res://scripts/core/expedition/model/manifest.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const World = preload("res://scripts/core/expedition/spatial/world_geometry.gd")
const CampaignFixture = preload("res://tests/fixtures/e07/f5/campaign_fixture.gd")

const ARCHER_SLOT := "entry_archer_batch_fixture"
const EXPECTED_CHECKS := 20

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
	var loaded: Dictionary = BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(),true)
	check("canonical_gameplay_catalog_loads",loaded.get("ok",false))
	if not loaded.get("ok",false): print(loaded); finish(); return
	var catalog: MobCatalog = loaded.catalog.mob_catalog()
	var archer: MobDefinition = catalog.get_definition(&"demo_archer")
	var base_mob: MobDefinition = catalog.get_definition(&"test_gel")
	check("real_fixture_mobs_have_distinct_radii",archer != null and base_mob != null and archer.collision_radius != base_mob.collision_radius,{"demo_archer":archer.collision_radius if archer != null else -1.0,"test_gel":base_mob.collision_radius if base_mob != null else -1.0})
	if archer == null or base_mob == null: finish(); return
	var fixture_manifest: ExpeditionManifest = with_profile_case(generated.data.manifest)
	var rules: Dictionary = CampaignFixture.rules(fixture_manifest)
	check("profile_fixture_adds_real_species_slot_and_witness",fixture_manifest.population_plan().find_slot(ARCHER_SLOT).species_id == "demo_archer" and not fixture_manifest.witness("population/"+ARCHER_SLOT).is_empty() and rules.has(ARCHER_SLOT))
	var manifest_hash_before: String = fixture_manifest.canonical_hash()
	var rules_before: Dictionary = rules.duplicate(true)
	var catalog_before: String = catalog_signature(catalog)
	var baseline: Dictionary = Planner.build(fixture_manifest,catalog,rules)
	check("planner_builds_all_canonical_slots",baseline.get("ok",false) and baseline.get("slots",{}).size() == fixture_manifest.population_plan().slots().size())
	if not baseline.get("ok",false): print(baseline); finish(); return
	var metrics: Array = baseline.get("navigation_metrics",[])
	check("groups_are_stage_and_profile_scoped",metrics.size() == 5 and stage_group_counts(metrics) == {"entry":2,"left":1,"right":1,"final":1})
	var entry_groups: Array[Dictionary] = []
	for item: Dictionary in metrics:
		if item.stage_id == "entry": entry_groups.append({"radius":item.profile.radius,"targets":item.targets})
	entry_groups.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.radius) < float(b.radius))
	var expected_small_radius: float = maxf(10.0,archer.collision_radius)
	var expected_shared_radius: float = maxf(10.0,base_mob.collision_radius)
	check("distinct_real_radii_receive_independent_profiles",entry_groups.size() == 2 and is_equal_approx(float(entry_groups[0].radius),expected_small_radius) and is_equal_approx(float(entry_groups[1].radius),expected_shared_radius) and expected_small_radius < expected_shared_radius)
	check("same_stage_same_profile_targets_share_one_batch",entry_groups.size() == 2 and int(entry_groups[1].targets) == 2)
	var same_stage_groups: bool = true
	for stage_id: String in ["left","right","final"]:
		for item: Dictionary in metrics:
			if item.stage_id == stage_id and (int(item.targets) != 2 or not is_equal_approx(float(item.profile.radius),expected_shared_radius)):
				same_stage_groups = false
	check("each_stage_batches_its_matching_profiles_only",same_stage_groups)
	var identity_and_rules_preserved: bool = true
	for source_slot: Dictionary in fixture_manifest.population_plan().slots():
		var realized: Dictionary = baseline.slots.get(source_slot.slot_id,{})
		var rule: Dictionary = rules.get(source_slot.slot_id,{})
		if realized.is_empty() or realized.species_id != source_slot.species_id or realized.occurrence_category != source_slot.occurrence_category or realized.origin_id != source_slot.origin_id or realized.stage_id != source_slot.stage_id or realized.home != source_slot.home or realized.trash != rule.trash or realized.base_xp != rule.base_xp or realized.job_xp != rule.job_xp:
			identity_and_rules_preserved = false
			break
	check("species_origin_stage_witness_identity_and_rules_are_preserved",identity_and_rules_preserved)
	check("build_does_not_mutate_manifest_catalog_or_rules",fixture_manifest.canonical_hash() == manifest_hash_before and catalog_signature(catalog) == catalog_before and rules == rules_before)
	var repeated: Dictionary = Planner.build(fixture_manifest,catalog,rules)
	check("repeated_build_keeps_realized_slots_and_grouping",repeated.get("ok",false) and repeated.get("slots",{}) == baseline.slots and group_summary(repeated.get("navigation_metrics",[])) == group_summary(metrics))

	var one_way: Dictionary = one_way_fixture(fixture_manifest,baseline.slots["entry_field"].traversal)
	var one_way_build: Dictionary = Planner.build(one_way.manifest,catalog,rules) if one_way.configured else {"ok":false,"error_code":"fixture_invalid"}
	check("planner_admits_a_valid_outward_only_route",one_way.configured and one_way.connection_found and one_way_build.get("ok",false),one_way_build.get("error_code",""))
	var one_way_world: World = one_way_build.worlds.get("entry") if one_way_build.get("ok",false) else null
	var outward_path: Dictionary = one_way_world.path(one_way.entry,one_way.home,one_way.profile,one_way_world.geometry_revision) if one_way_world != null else {"ok":false}
	var return_path: Dictionary = one_way_world.path(one_way.home,one_way.entry,one_way.profile,one_way_world.geometry_revision) if one_way_world != null else {"ok":false}
	check("one_way_fixture_really_has_only_outward_navigation",outward_path.get("ok",false) and not return_path.get("ok",false))

	var disconnected: Dictionary = disconnected_fixture(fixture_manifest)
	var denied: Dictionary = Planner.build(disconnected.manifest,catalog,rules) if disconnected.configured else {"ok":true,"error_code":"fixture_invalid"}
	check("unreachable_home_is_a_negative_without_partial_result",disconnected.configured and disconnected.connection_found and not denied.get("ok",false) and denied.get("error_code") == &"population_unreachable" and no_partial_payload(denied))
	var missing_witness: ExpeditionManifest = copy_manifest(fixture_manifest)
	missing_witness._data.witnesses.erase("population/entry_field")
	var witness_denied: Dictionary = Planner.build(missing_witness,catalog,rules)
	check("required_population_witness_cannot_be_omitted",not witness_denied.get("ok",false) and witness_denied.get("error_code") == &"population_unreachable" and no_partial_payload(witness_denied))
	var missing_rule: Dictionary = rules.duplicate(true)
	missing_rule.erase("entry_field")
	var policy_denied: Dictionary = Planner.build(fixture_manifest,catalog,missing_rule)
	check("missing_policy_is_preserved_as_operational_failure",not policy_denied.get("ok",false) and policy_denied.get("error_code") == &"policy_unresolved" and no_partial_payload(policy_denied))
	var malformed_rule: Dictionary = rules.duplicate(true)
	malformed_rule.entry_field.base_xp = 1.5
	var malformed_denied: Dictionary = Planner.build(fixture_manifest,catalog,malformed_rule)
	check("invalid_policy_numbers_are_rejected",not malformed_denied.get("ok",false) and malformed_denied.get("error_code") == &"invalid_population_policy" and no_partial_payload(malformed_denied))

	var cancelled_before: Dictionary = Planner.build(fixture_manifest,catalog,rules,func() -> bool: return true)
	check("pre_cancel_never_returns_partial_slots",not cancelled_before.get("ok",false) and cancelled_before.get("error_code") == &"cancelled" and no_partial_payload(cancelled_before))
	var calls: Array[int] = [0]
	var cancel_inside_query := func() -> bool:
		calls[0] += 1
		return calls[0] >= fixture_manifest.population_plan().slots().size()+3
	var cancelled_during: Dictionary = Planner.build(fixture_manifest,catalog,rules,cancel_inside_query)
	var geometry_diagnostic: Dictionary = cancelled_during.get("geometry_diagnostic",{})
	check("query_cancel_propagates_without_partial_result_or_mutation",not cancelled_during.get("ok",false) and cancelled_during.get("error_code") == &"cancelled" and no_partial_payload(cancelled_during) and geometry_diagnostic.has("phase") and fixture_manifest.canonical_hash() == manifest_hash_before and rules == rules_before and catalog_signature(catalog) == catalog_before)
	finish()

func with_profile_case(original: ExpeditionManifest) -> ExpeditionManifest:
	var manifest := copy_manifest(original)
	var data: Dictionary = manifest._data
	var input_data: Dictionary = data["input"]
	var input_traversal: Dictionary = input_data["traversal"]
	input_traversal["radius"] = 10.0
	var manifest_traversal: Dictionary = data["traversal"]
	manifest_traversal["radius"] = 10.0
	var population_data: Dictionary = data["population"]
	var population_slots: Array = population_data["slots"]
	var slot: Dictionary = population_slots.filter(func(item: Dictionary) -> bool: return item.slot_id == "entry_field")[0].duplicate(true)
	var clone: Dictionary = slot.duplicate(true)
	clone.slot_id = ARCHER_SLOT
	clone.species_id = "demo_archer"
	clone.occurrence_category = "normal"
	population_slots.append(clone)
	var witnesses: Dictionary = data["witnesses"]
	witnesses["population/"+ARCHER_SLOT] = witnesses["population/entry_field"].duplicate(true)
	var recipes: Array = input_data["population"]
	var recipe: Dictionary = recipes.filter(func(item: Dictionary) -> bool: return item.slot_id == "entry_field")[0].duplicate(true)
	recipe.slot_id = ARCHER_SLOT
	recipe.species_id = "demo_archer"
	recipes.append(recipe)
	var species_definitions: Array = input_data["species"]
	var species: Dictionary = species_definitions.filter(func(item: Dictionary) -> bool: return item.species_id == "test_gel")[0].duplicate(true)
	species.species_id = "demo_archer"
	species.occurrence_categories = ["normal"]
	species_definitions.append(species)
	data["input_hash"] = ExpeditionCanonical.digest(input_data)
	manifest._data = data
	return manifest

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

func stage_group_counts(metrics: Array) -> Dictionary:
	var result := {"entry":0,"left":0,"right":0,"final":0}
	for item: Dictionary in metrics:
		if result.has(item.stage_id): result[item.stage_id] += 1
	return result

func group_summary(metrics: Array) -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	for item: Dictionary in metrics: summary.append({"stage_id":item.stage_id,"radius":item.profile.radius,"targets":item.targets})
	summary.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return ExpeditionCanonical.encode(a) < ExpeditionCanonical.encode(b))
	return summary

func no_partial_payload(result: Dictionary) -> bool:
	return not result.has("slots") and not result.has("worlds") and not result.has("navigation_metrics")

func catalog_signature(catalog: MobCatalog) -> String:
	var definitions: Array[Dictionary] = []
	for id: StringName in catalog.ids():
		var definition: MobDefinition = catalog.get_definition(id)
		definitions.append({"id":str(id),"collision_radius":definition.collision_radius,"categories":definition.allowed_occurrence_categories,"origins":definition.origin_levels,"visual_kind":str(definition.visual_kind),"summons_companion":definition.summons_companion})
	return ExpeditionCanonical.digest(definitions)

func copy_manifest(original: ExpeditionManifest) -> ExpeditionManifest:
	var result := Manifest.new()
	result._data = original.to_data()
	return result

func finish() -> void:
	var ok := failed.is_empty() and checks.size() == EXPECTED_CHECKS
	print("F9_POPULATION_PLANNER_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"failed":failed,"expected_count":EXPECTED_CHECKS}))
	quit(0 if ok else 1)
