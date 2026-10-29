extends SceneTree
## F9-04 pure population/patrol authoring proposals and persistence invariants.
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PopulationOperations = preload("res://scripts/map_authoring/population/population_operations.gd")
const PopulationSession = preload("res://scripts/map_authoring/population/population_session.gd")
const PopulationStore = preload("res://scripts/map_authoring/population/population_store.gd")
const PopulationCatalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const PopulationCompiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const PatrolOperations = preload("res://scripts/map_authoring/patrol/patrol_operations.gd")
const PatrolSession = preload("res://scripts/map_authoring/patrol/patrol_session.gd")
const PatrolStore = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PopulationFixture = preload("res://tests/map_editor_population_test.gd")
const PatrolFixture = preload("res://tests/map_editor_patrol_test.gd")

const EXPECTED_COUNT := 27
var checks: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("F9_ENCOUNTER_CHECK "+id+" "+str(ok))

func _run() -> void:
	var run_id: String = Crypto.new().generate_random_bytes(12).hex_encode()
	var population: Dictionary = PopulationFixture.fixture()
	var patrol: Dictionary = PatrolFixture.fixture()
	check("real_population_and_patrol_fixtures_validate",PopulationDocument.validate(population).ok and PatrolDocument.validate(patrol).ok)
	var catalog_before: String = PopulationCatalog.load_current().hash
	var options: Array = PopulationCatalog.list_options().options
	check("catalog_options_are_real_and_catalog_is_immutable",not options.is_empty() and PopulationCatalog.load_current().hash == catalog_before)

	var brush: Dictionary = population.brushes[0].duplicate(true); brush.brush_id = "new_brush"
	var source_hash: String = PopulationDocument.hash_source(population)
	var proposed: Dictionary = PopulationOperations.propose(population,"brush/upsert",brush)
	check("population_proposal_is_pure_and_reports_identity_hash",proposed.ok and proposed.entity_id == "new_brush" and proposed.input_hash == source_hash and proposed.added_ids.has("new_brush") and not population.brushes.any(func(item: Dictionary) -> bool: return item.brush_id == "new_brush"))
	var unknown: Dictionary = brush.duplicate(true); unknown.extra = true
	check("unknown_nested_field_rejected",not PopulationOperations.propose(population,"brush/upsert",unknown).ok)
	var nan_brush: Dictionary = brush.duplicate(true); nan_brush.radius = NAN
	check("nested_nan_rejected",not PopulationOperations.propose(population,"brush/upsert",nan_brush).ok)
	var invalid_last: Dictionary = PopulationOperations.propose(population,"brush/upsert",brush)
	var bad_last_brush: Dictionary = brush.duplicate(true); bad_last_brush.brush_id = "bad_last"; bad_last_brush.species[0].unknown = true
	check("invalid_nested_last_candidate_leaves_original_untouched",not PopulationOperations.propose(population,"brush/upsert",bad_last_brush).ok and PopulationDocument.hash_source(population) == source_hash and invalid_last.ok)
	check("missing_brush_reference_is_rejected",not PopulationOperations.propose(population,"slot/upsert",{"slot_id":"orphan","brush_id":"absent","surface_id":"surface","position_xyz":[1,0,1],"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1","fixed":true,"site_id":""}).ok)
	var brush_slot: Dictionary = {"slot_id":"manual","brush_id":population.brushes[0].brush_id,"surface_id":population.brushes[0].surface_id,"position_xyz":population.brushes[0].center_xyz,"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1","fixed":false,"site_id":""}
	check("manual_slot_requires_fixed_true",PopulationOperations.propose(population,"slot/upsert",brush_slot).code == "slot_fixed_required")
	brush_slot.fixed = true
	var fixed_slot: Dictionary = PopulationOperations.propose(population,"slot/upsert",brush_slot)
	check("fixed_manual_slot_is_added_as_explicit_identity",fixed_slot.ok and fixed_slot.data.slots.any(func(item: Dictionary) -> bool: return item.slot_id == "manual" and item.fixed) and fixed_slot.added_ids.has("manual"))
	var with_slot: Dictionary = fixed_slot.data
	var no_confirm: Dictionary = PopulationOperations.propose(with_slot,"brush/remove",{"brush_id":population.brushes[0].brush_id,"confirm_remove":false})
	var removed_brush: Dictionary = PopulationOperations.propose(with_slot,"brush/remove",{"brush_id":population.brushes[0].brush_id,"confirm_remove":true})
	check("brush_removal_requires_confirmation_and_removes_dependent_slots",not no_confirm.ok and no_confirm.code == "confirmation_required" and removed_brush.ok and removed_brush.data.slots.is_empty() and removed_brush.removed_ids.has("manual"))
	var same: Dictionary = PopulationOperations.propose(population,"name",{"name":population.name})
	var population_session: Variant = PopulationSession.new(); population_session.replace(population)
	population_session.apply(same.data)
	check("population_noop_adds_no_history",same.ok and population_session._undo.is_empty() and not population_session.can_undo())
	population_session.apply(proposed.data)
	var population_changed_hash: String = PopulationDocument.hash_source(population_session.data)
	var population_undo: bool = population_session.undo()
	var population_undo_hash: String = PopulationDocument.hash_source(population_session.data)
	var population_redo: bool = population_session.redo()
	var population_redo_hash: String = PopulationDocument.hash_source(population_session.data)
	check("population_apply_undo_redo_are_whole_document",population_undo and population_undo_hash == source_hash and population_redo and population_redo_hash == population_changed_hash and population_session.can_undo())
	var removed_slots_source: Dictionary = PopulationDocument.empty("slot_removal")
	removed_slots_source.brushes = population.brushes.duplicate(true); removed_slots_source.slots = [brush_slot]
	var remove_slot: Dictionary = PopulationOperations.propose(removed_slots_source,"slot/remove",{"slot_id":"manual","confirm_remove":true})
	check("slot_removal_requires_positive_confirmation_and_tracks_id",remove_slot.ok and remove_slot.removed_ids.has("manual") and not PopulationOperations.propose(removed_slots_source,"slot/remove",{"slot_id":"manual","confirm_remove":false}).ok)
	var plan: Dictionary = PopulationCompiler.regenerate(population)
	check("canonical_plan_preview_is_pure_and_bound_to_base",plan.ok and PopulationDocument.hash_source(population) == source_hash and plan.data.plan_hash == PopulationDocument.recipe_hash(plan.data))
	var stale_base: Dictionary = plan.data.duplicate(true); stale_base.name += " stale"
	check("canonical_plan_rejects_stale_source",not PopulationCompiler.compile(stale_base).ok)
	var compiled_population: Dictionary = PopulationCompiler.compile(plan.data)
	check("applied_plan_compiles_canonically",compiled_population.ok and compiled_population.package.source_hash == PopulationDocument.hash_source(plan.data))
	var population_path: String = ProjectSettings.globalize_path("res://.godot/f9_encounter_authoring/"+run_id+"/population.json")
	DirAccess.make_dir_recursive_absolute(population_path.get_base_dir())
	var save_population: Dictionary = PopulationStore.save_source(population_path,population,"")
	var opened_population: Dictionary = PopulationStore.load_source(population_path)
	check("population_store_new_save_open_roundtrip",save_population.ok and opened_population.ok and PopulationDocument.hash_source(opened_population.data) == source_hash)
	check("population_store_conflict_preserves_saved_bytes",PopulationStore.save_source(population_path,population,"stale").code == "io_conflict" and PopulationStore.load_source(population_path).byte_hash == opened_population.byte_hash)
	var patrol_hash: String = PatrolDocument.hash_source(patrol)
	var route: Dictionary = patrol.patrols[0].duplicate(true); route.mode = "ping_pong"
	var route_proposal: Dictionary = PatrolOperations.propose(patrol,"route/upsert",route)
	check("patrol_route_upsert_is_pure_and_hash_identified",route_proposal.ok and route_proposal.input_hash == patrol_hash and PatrolDocument.hash_source(patrol) == patrol_hash and route_proposal.data.patrols[0].mode == "ping_pong")
	var point_params: Dictionary = {"patrol_id":route.patrol_id,"point_id":"last","surface_id":route.waypoints[0].surface_id,"position_xyz":route.waypoints[0].position_xyz,"wait_seconds":1.75}
	var point_added: Dictionary = PatrolOperations.propose(patrol,"waypoint/upsert",point_params)
	var edit_existing: Dictionary = point_params.duplicate(true); edit_existing.point_id = "north"; edit_existing.position_xyz = patrol.patrols[0].waypoints[1].position_xyz
	var point_edited: Dictionary = PatrolOperations.propose(patrol,"waypoint/upsert",edit_existing)
	check("new_waypoint_appends_and_fractional_edit_preserves_existing_order",point_added.ok and point_added.data.patrols[0].waypoints[-1].point_id == "last" and point_added.data.patrols[0].waypoints[-1].wait_seconds == 1.75 and point_added.data.patrols[0].waypoints[0].point_id == route.waypoints[0].point_id and point_edited.ok and point_edited.data.patrols[0].waypoints[1].point_id == "north" and point_edited.data.patrols[0].waypoints[1].wait_seconds == 1.75 and point_edited.data.patrols[0].waypoints[2].point_id == "south")
	var moved: Dictionary = PatrolOperations.propose(patrol,"waypoint/move",{"patrol_id":route.patrol_id,"point_id":"north","direction":1})
	var boundary: Dictionary = PatrolOperations.propose(patrol,"waypoint/move",{"patrol_id":route.patrol_id,"point_id":"west","direction":-1})
	check("waypoint_order_move_and_boundary_are_deterministic",moved.ok and moved.data.patrols[0].waypoints[2].point_id == "north" and boundary.ok and boundary.output_hash == PatrolDocument.hash_source(patrol))
	check("waypoint_invalid_direction_and_nested_nan_are_rejected",not PatrolOperations.propose(patrol,"waypoint/move",{"patrol_id":route.patrol_id,"point_id":"west","direction":0}).ok and not PatrolOperations.propose(patrol,"waypoint/upsert",{"patrol_id":route.patrol_id,"point_id":"bad","surface_id":"surface","position_xyz":[NAN,0,0],"wait_seconds":0}).ok)
	check("waypoint_remove_confirmation_and_duplicate_point_rejection",not PatrolOperations.propose(patrol,"waypoint/remove",{"patrol_id":route.patrol_id,"point_id":"west","confirm_remove":false}).ok and not PatrolDocument.validate(_duplicate_route(patrol)).ok)
	var duplicate_assignment: Dictionary = patrol.duplicate(true); duplicate_assignment.patrols.append({"patrol_id":"second","revision":1,"mode":"loop","slot_ids":["guard"],"waypoints":[]})
	check("exclusive_slot_assignment_is_enforced",not PatrolDocument.validate(duplicate_assignment).ok)
	var patrol_session: Variant = PatrolSession.new(); patrol_session.replace(patrol); patrol_session.apply(route_proposal.data)
	var patrol_changed_hash: String = PatrolDocument.hash_source(patrol_session.data)
	var patrol_undo: bool = patrol_session.undo()
	var patrol_undo_hash: String = PatrolDocument.hash_source(patrol_session.data)
	var patrol_redo: bool = patrol_session.redo()
	var patrol_redo_hash: String = PatrolDocument.hash_source(patrol_session.data)
	check("patrol_session_undo_redo_restore_complete_route",patrol_undo and patrol_undo_hash == patrol_hash and patrol_redo and patrol_redo_hash == patrol_changed_hash)
	var patrol_path: String = ProjectSettings.globalize_path("res://.godot/f9_encounter_authoring/"+run_id+"/patrol.json")
	var saved_patrol: Dictionary = PatrolStore.save_source(patrol_path,patrol,""); var loaded_patrol: Dictionary = PatrolStore.load_source(patrol_path)
	check("patrol_store_roundtrip_and_external_conflict",saved_patrol.ok and loaded_patrol.ok and PatrolDocument.hash_source(loaded_patrol.data) == patrol_hash and PatrolStore.save_source(patrol_path,patrol,"stale").code == "io_conflict")
	var compiled_patrol: Dictionary = PatrolCompiler.compile(patrol)
	check("patrol_compiler_accepts_authored_route",compiled_patrol.ok and PatrolDocument.hash_source(patrol) == patrol_hash)
	finish()

func _duplicate_route(source: Dictionary) -> Dictionary:
	var candidate: Dictionary = source.duplicate(true)
	candidate.patrols[0].waypoints.append(candidate.patrols[0].waypoints[0].duplicate(true))
	return candidate

func finish() -> void:
	var ok: bool = checks.size() == EXPECTED_COUNT and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ENCOUNTER_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"expected_count":EXPECTED_COUNT,"checks":checks}))
	quit(0 if ok else 1)
