extends SceneTree

const Compiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PopulationFixture = preload("res://tests/map_editor_population_test.gd")
const Point = preload("res://scripts/core/expedition/model/world_point.gd")
const World = preload("res://scripts/core/expedition/spatial/world_geometry.gd")
const Manifest = preload("res://scripts/core/expedition/model/manifest.gd")

var checks: Array[Dictionary] = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(id: String, value: bool, detail: Variant = null) -> void:
	checks.append({"id":id,"ok":value,"detail":detail})
	if not value: failures.append(id)

func _run() -> void:
	var source: Dictionary = PopulationFixture.fixture()
	check("small_two_room_fixture",not source.is_empty())
	if source.is_empty(): finish(); return
	var frozen_source := source.duplicate(true)
	var context := Compiler.prepare(source)
	check("canonical_population_context",context.ok)
	if not context.ok: finish(); return
	var world: World = context.world
	var root: ExpeditionWorldPoint = Compiler.anchor(source.entrance[0])
	var finish_record: Dictionary = source.interactions.filter(func(item: Dictionary) -> bool: return item.kind == "phase_completion")[0]
	var finish_point: ExpeditionWorldPoint = Compiler.anchor(finish_record)
	var rest_record: Dictionary = source.interactions.filter(func(item: Dictionary) -> bool: return item.kind == "early_exit")[0]
	var rest_point: ExpeditionWorldPoint = Compiler.anchor(rest_record)
	var targets: Array[ExpeditionWorldPoint] = [finish_point,rest_point]
	var profile: Dictionary = Compiler.PROFILE.duplicate(true)
	var world_before: Dictionary = world._stage.duplicate(true)
	var revision_before: int = world.geometry_revision

	var batch := Compiler.reachability(world,root,targets,profile)
	check("batch_query_succeeds",batch.ok,batch.get("code",""))
	check("batch_is_complete",batch.ok and batch.get("reachable",[]).size() == targets.size())
	check("directed_round_trip_reachable",batch.ok and batch.reachable == [true,true],batch.get("reachable",[]))
	var certificate := world.connectivity_batch(root,targets,profile,world.geometry_revision)
	check("certificate_preserves_input_order",certificate.ok and certificate.data.targets.size() == 2 and certificate.data.targets[0].point == finish_point.to_data() and certificate.data.targets[1].point == rest_point.to_data())
	check("certificate_reports_both_directions",certificate.ok and certificate.data.targets.all(func(item: Dictionary) -> bool: return item.outward_reachable and item.inward_reachable))
	var out_witness := world.connectivity_witness(certificate,0,true,world.geometry_revision) if certificate.ok else {"ok":false}
	var back_witness := world.connectivity_witness(certificate,0,false,world.geometry_revision) if certificate.ok else {"ok":false}
	check("outward_witness_reconstructs",out_witness.ok and out_witness.data.points.front().surface_id == root.surface_id and out_witness.data.points.back().surface_id == finish_point.surface_id)
	check("inward_witness_reconstructs",back_witness.ok and back_witness.data.points.front().surface_id == finish_point.surface_id and back_witness.data.points.back().surface_id == root.surface_id)
	var directed_manifest := Manifest.new(); directed_manifest._data = context.manifest.to_data()
	var directed_stage: Dictionary = directed_manifest._data.stages[0]
	var endpoint_surfaces: Dictionary = {}
	for endpoint: Dictionary in directed_stage.connectors: endpoint_surfaces[endpoint.connector_id] = endpoint.surface_id
	var directed_link_found := false
	for connection: Dictionary in directed_stage.connections:
		connection.forward = false; connection.backward = false
		var a_surface: String = endpoint_surfaces.get(connection.a_connector,"")
		var b_surface: String = endpoint_surfaces.get(connection.b_connector,"")
		if (a_surface == root.surface_id or b_surface == root.surface_id) and (a_surface == finish_point.surface_id or b_surface == finish_point.surface_id) and a_surface != b_surface:
			connection.forward = a_surface == root.surface_id
			connection.backward = b_surface == root.surface_id
			directed_link_found = true
	var directed_world := World.new()
	var directed_setup := directed_world.configure(directed_manifest,"map_preview")
	var outward_only := directed_world.connectivity_batch(root,[finish_point],profile,directed_world.geometry_revision) if directed_setup.ok and directed_link_found else {"ok":false}
	var reverse_only := directed_world.connectivity_batch(finish_point,[root],profile,directed_world.geometry_revision) if directed_setup.ok and directed_link_found else {"ok":false}
	check("directed_edge_proves_outward_without_fabricating_return",directed_link_found and outward_only.ok and outward_only.data.targets[0].outward_reachable and not outward_only.data.targets[0].inward_reachable and world.path(root,finish_point,profile,world.geometry_revision).ok)
	check("reverse_query_proves_missing_direction_without_transpose_leak",reverse_only.ok and not reverse_only.data.targets[0].outward_reachable and reverse_only.data.targets[0].inward_reachable and not directed_world.path(finish_point,root,profile,directed_world.geometry_revision).ok)
	var repeated := world.connectivity_batch(root,targets,profile,world.geometry_revision)
	check("batch_result_deterministic",repeated.ok and certificate.ok and repeated.data.targets == certificate.data.targets and repeated.data.states == certificate.data.states and repeated.data.outward_previous == certificate.data.outward_previous and repeated.data.inward_previous == certificate.data.inward_previous)
	check("query_does_not_mutate_source_or_world",source == frozen_source and world._stage == world_before and world.geometry_revision == revision_before)
	var wrapper := Compiler.reachability(world,root,targets,profile)
	check("compiler_wrapper_matches_certificate",wrapper.ok and wrapper.reachable == certificate.data.targets.map(func(item: Dictionary) -> bool: return item.outward_reachable and item.inward_reachable))

	var bad_profile := profile.duplicate(true); bad_profile.radius = NAN
	var invalid_profile := world.connectivity_batch(root,targets,bad_profile,world.geometry_revision)
	check("invalid_profile_is_operational_error",not invalid_profile.ok and str(invalid_profile.error_code) == "invalid_profile")
	check("operational_classifier_keeps_profile_failure",Compiler.operational(str(invalid_profile.error_code)))
	var bad_target := Point.create("map_preview","missing_surface",Vector3(10,0,10))
	var invalid_point := world.connectivity_batch(root,[bad_target],profile,world.geometry_revision)
	check("invalid_point_is_not_negative_reachability",not invalid_point.ok and str(invalid_point.error_code) == "invalid_support" and not invalid_point.data.has("complete"))
	var cancelled := world.connectivity_batch(root,targets,profile,world.geometry_revision,func() -> bool: return true)
	check("cancel_is_distinct_operational_error",not cancelled.ok and str(cancelled.error_code) == "cancelled" and not cancelled.data.has("complete"))
	var cancelled_wrapper := Compiler.reachability(world,root,targets,profile,func() -> bool: return true)
	check("population_wrapper_preserves_cancellation",not cancelled_wrapper.ok and cancelled_wrapper.code == "cancelled" and cancelled_wrapper.has("geometry_diagnostic"))
	var budgeted := world.connectivity_batch(root,targets,profile,world.geometry_revision,Callable(),{"max_targets":0})
	check("budget_exhaustion_is_not_negative",not budgeted.ok and str(budgeted.error_code) == "navigation_budget_exceeded")
	check("budget_failure_has_no_partial_certificate",not budgeted.data.has("complete") and not budgeted.data.has("targets") and not budgeted.data.get("all_reachable",false))
	check("failed_queries_leave_snapshot_unchanged",world._stage == world_before and world.geometry_revision == revision_before)

	var disconnected_manifest := Manifest.new()
	disconnected_manifest._data = context.manifest.to_data()
	var stage: Dictionary = disconnected_manifest._data.stages[0]
	for connection: Dictionary in stage.connections:
		connection.forward = false
		connection.backward = false
	var disconnected_world := World.new()
	var disconnected_setup := disconnected_world.configure(disconnected_manifest,"map_preview")
	var disconnected := disconnected_world.connectivity_batch(root,[finish_point],profile,disconnected_world.geometry_revision) if disconnected_setup.ok else {"ok":false,"error_code":"fixture_invalid"}
	check("disconnected_component_returns_complete_negative",disconnected.ok and disconnected.data.complete and not disconnected.data.all_reachable)
	check("negative_keeps_outward_and_return_separate",disconnected.ok and not disconnected.data.targets[0].outward_reachable and not disconnected.data.targets[0].inward_reachable)
	var overlap_manifest := Manifest.new(); overlap_manifest._data = context.manifest.to_data()
	var overlap_stage: Dictionary = overlap_manifest._data.stages[0]
	var isolated_floor: Dictionary = overlap_stage.surfaces[0].duplicate(true); isolated_floor.surface_id = "isolated_overlapping_floor"
	overlap_stage.surfaces.append(isolated_floor)
	var overlap_world := World.new(); var overlap_setup := overlap_world.configure(overlap_manifest,"map_preview")
	var coincident_other_floor := Point.create(root.stage_id,isolated_floor.surface_id,root.position)
	var floor_negative := overlap_world.connectivity_batch(root,[coincident_other_floor],profile,overlap_world.geometry_revision) if overlap_setup.ok else {"ok":false}
	check("negative_and_overlapping_floor_are_not_operational_failure",disconnected.ok and not Compiler.operational("population_unreachable") and floor_negative.ok and floor_negative.data.complete and not floor_negative.data.targets[0].outward_reachable and not floor_negative.data.targets[0].inward_reachable)
	var oversized_profile := profile.duplicate(true); oversized_profile.radius = 1000.0
	var body_blocked := world.connectivity_batch(root,[finish_point],oversized_profile,world.geometry_revision)
	check("body_clearance_failure_is_invalid_support",not body_blocked.ok and str(body_blocked.error_code) == "invalid_support")

	var planned := Compiler.regenerate(source)
	var repeated_plan := Compiler.regenerate(source)
	var differential: bool = planned.ok and repeated_plan.ok and planned.data == repeated_plan.data and source == frozen_source
	if differential:
		for slot: Dictionary in planned.data.slots:
			var target: ExpeditionWorldPoint = Compiler.anchor(slot)
			var spec := Compiler._spec(slot,context.catalog)
			if not spec.ok or not world.path(root,target,spec.profile,world.geometry_revision).ok or not world.path(target,root,spec.profile,world.geometry_revision).ok:
				differential = false
				break
	check("small_regeneration_matches_individual_round_trips_without_mutation",differential,{"slots":planned.data.slots.size() if planned.ok else 0})
	finish()

func finish() -> void:
	var ok := failures.is_empty() and checks.size() == 27
	print("F9_POPULATION_REACHABILITY_RESULT "+JSON.stringify({"ok":ok,"checks":checks.size(),"failed":failures,"details":checks,"expected_checks":27}))
	quit(0 if ok else 1)
