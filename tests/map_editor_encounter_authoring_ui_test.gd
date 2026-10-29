extends SceneTree
## Native Shell and Presentation exercise for F9-04 encounters and patrols.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const PopulationPanel = preload("res://scripts/map_authoring/population/population_panel.gd")
const PatrolPanel = preload("res://scripts/map_authoring/patrol/patrol_panel.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PopulationCompiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PopulationStore = preload("res://scripts/map_authoring/population/population_store.gd")
const PopulationCatalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PopulationFixture = preload("res://tests/map_editor_population_test.gd")
const PatrolFixture = preload("res://tests/map_editor_patrol_test.gd")

const EXPECTED_COUNT := 25
var checks: Array[Dictionary] = []
var gui_shell: Variant
var ax_shell: Variant
var gui_panel: Variant
var ax_panel: Variant
var gui_patrol: Variant
var ax_patrol: Variant
var gui_presentation: Variant
var ax_presentation: Variant
var evidence_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func check(id: String, ok: bool, detail: Dictionary = {}) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_ENCOUNTER_UI_CHECK "+id+" "+str(ok))
	if not ok and not detail.is_empty(): print("F9_ENCOUNTER_UI_DIAGNOSTIC "+id+" "+JSON.stringify(detail))

func frames(count: int = 2) -> void:
	for _index: int in count:
		await process_frame
		RenderingServer.force_draw(false)

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.gui_embed_subwindows = true
	root.size = Vector2i(1440,1000)
	DisplayServer.window_set_size(Vector2i(1440,1000))
	evidence_dir = OS.get_environment("F9_EVIDENCE")
	if evidence_dir.is_empty(): evidence_dir = ProjectSettings.globalize_path("res://.godot/f9_encounter_authoring/ui")
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	var run_id: String = Crypto.new().generate_random_bytes(12).hex_encode()
	Presentation.active_mode = "ux"
	gui_shell = Shell.new(); gui_shell.name = "GuiEncounterShell"; root.add_child(gui_shell)
	ax_shell = Shell.new(); ax_shell.name = "AxEncounterShell"; root.add_child(ax_shell)
	gui_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ax_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames(3)
	var gui_piece: Variant = gui_shell.get_node_or_null("AuthoringPresentation")
	var ax_piece: Variant = ax_shell.get_node_or_null("AuthoringPresentation")
	var gui_mode: Dictionary = gui_piece.set_mode("ax") if gui_piece != null else {"ok":false}
	var ax_mode: Dictionary = ax_piece.set_mode("ax") if ax_piece != null else {"ok":false}
	var gui_open_map: Dictionary = gui_piece.ax_invoke("piece/compose_map",{}) if gui_piece != null else {"ok":false}
	var ax_open_map: Dictionary = ax_piece.ax_invoke("piece/compose_map",{}) if ax_piece != null else {"ok":false}
	await frames(4)
	var gui_composition: Variant = gui_shell.composition_window.get_child(0) if gui_shell.composition_window != null else null
	var ax_composition: Variant = ax_shell.composition_window.get_child(0) if ax_shell.composition_window != null else null
	gui_shell.composition_window.position = Vector2i.ZERO; gui_shell.composition_window.size = Vector2i(1440,1000); gui_shell.composition_window.show()
	ax_shell.composition_window.position = Vector2i.ZERO; ax_shell.composition_window.size = Vector2i(1440,1000); ax_shell.composition_window.show()
	if gui_composition != null: gui_composition.open_population()
	if ax_composition != null: ax_composition.open_population()
	await frames(4)
	var gui_window: Window = gui_composition.population_window if gui_composition != null else null
	var ax_window: Window = ax_composition.population_window if ax_composition != null else null
	gui_panel = gui_window.get_child(0) if gui_window != null and gui_window.get_child_count() > 0 else null
	ax_panel = ax_window.get_child(0) if ax_window != null and ax_window.get_child_count() > 0 else null
	gui_presentation = gui_panel.get_node_or_null("AuthoringPresentation") if gui_panel != null else null
	ax_presentation = ax_panel.get_node_or_null("AuthoringPresentation") if ax_panel != null else null
	check("two_shells_open_real_population_windows_and_sessions",gui_mode.ok and ax_mode.ok and gui_open_map.ok and ax_open_map.ok and gui_window != null and gui_window.visible and ax_window != null and ax_window.visible and gui_panel.get_script() == PopulationPanel and ax_panel.get_script() == PopulationPanel and gui_panel.session != ax_panel.session and gui_presentation.ax_snapshot().screen == "population" and ax_presentation.ax_snapshot().screen == "population")
	if gui_panel == null or ax_panel == null: finish(); return
	var source: Dictionary = PopulationFixture.fixture()
	var gui_import: Dictionary = gui_panel.import_map(source.map[0])
	var ax_import: Dictionary = ax_panel.import_map(source.map[0])
	var patrol_fixture: Dictionary = PatrolFixture.fixture()
	var realized_population: Dictionary = patrol_fixture.population[0].duplicate(true)
	gui_panel.session.replace(realized_population); ax_panel.session.replace(realized_population)
	var gui_map_query: Dictionary = gui_panel.map_query()
	var ax_map_query: Dictionary = ax_panel.map_query()
	check("map_query_reads_real_compiled_surfaces_and_sockets",gui_import.ok and ax_import.ok and gui_map_query.ok and ax_map_query.ok and gui_map_query.map_package_hash == ax_map_query.map_package_hash and not gui_map_query.surfaces.is_empty() and not gui_map_query.surfaces[0].vertices_xyz.is_empty() and gui_map_query.surfaces == ax_map_query.surfaces)
	check("map_query_includes_socket_records_and_source_hash_for_real_package",gui_map_query.has("sockets") and ax_map_query.sockets == gui_map_query.sockets and gui_map_query.map_package_hash == gui_panel.canvas.package.package_hash and gui_map_query.map_source_hash == MapDocument.hash_source(source.map[0]))
	var options: Dictionary = PopulationCatalog.list_options()
	check("real_catalog_populates_both_authoring_panels",options.ok and not options.options.is_empty() and gui_panel.species.item_count > 0 and ax_panel.species.item_count > 0)
	var gui_commands: Array = gui_presentation.ax_snapshot().commands
	var ax_commands: Array = ax_presentation.ax_snapshot().commands
	check("population_command_contract_advertised_by_real_presentations",gui_commands.any(func(command: Dictionary) -> bool: return command.id == "population/brush/upsert") and gui_commands.any(func(command: Dictionary) -> bool: return command.id == "population/plan/apply") and ax_commands.any(func(command: Dictionary) -> bool: return command.id == "population/map/query"))
	gui_panel.brushes.select(0); gui_panel.radius.value = source.brushes[0].radius-8; gui_panel.apply_brush()
	var gui_brush: Dictionary = gui_panel.session.data.brushes[0].duplicate(true)
	var gui_operation: Dictionary = ax_presentation.ax_invoke("population/brush/upsert",gui_brush)
	var cloned_brush: Dictionary = gui_brush.duplicate(true); cloned_brush.brush_id = "gui_ax_brush"; cloned_brush.surface_id = source.brushes[1].surface_id; cloned_brush.center_xyz = [700.0,0.0,340.0]; cloned_brush.radius = 30; cloned_brush.group_radius = 20; cloned_brush.quantity = 1
	var gui_clone: Dictionary = gui_panel.apply_operation("brush/upsert",cloned_brush)
	var ax_clone: Dictionary = ax_presentation.ax_invoke("population/brush/upsert",cloned_brush)
	check("gui_controls_and_ax_share_population_producer_and_semantic_hash",gui_operation.ok and gui_clone.ok and ax_clone.ok and PopulationDocument.hash_source(gui_panel.session.data) == PopulationDocument.hash_source(ax_panel.session.data) and gui_panel.session.can_undo() and ax_panel.session.can_undo())
	var invalid_base: String = PopulationDocument.hash_source(ax_panel.session.data); var invalid_depth: int = ax_panel.session._undo.size()
	var invalid_nested: Dictionary = gui_brush.duplicate(true); invalid_nested.unknown = true
	var invalid_result: Dictionary = ax_presentation.ax_invoke("population/brush/upsert",invalid_nested)
	check("invalid_nested_ids_and_confirmations_preserve_ax_source_and_history",not invalid_result.ok and not ax_presentation.ax_invoke("population/brush/remove",{"brush_id":"absent","confirm_remove":false}).ok and PopulationDocument.hash_source(ax_panel.session.data) == invalid_base and ax_panel.session._undo.size() == invalid_depth)
	var prior_hash: String = PopulationDocument.hash_source(gui_panel.session.data)
	var preview_started: Dictionary = gui_panel.prepare_plan()
	var ax_preview: Dictionary = await ax_presentation.ax_invoke("population/plan/preview",{})
	var preview_wait: int = 0
	while (gui_panel.job != null or ax_panel.job != null) and preview_wait < 3000: await process_frame; preview_wait += 1
	var ax_proposal: Dictionary = ax_panel.proposal.duplicate(true)
	var ax_signature: String = ax_panel.proposal_hash()
	check("gui_and_ax_plan_preview_workers_return_proposal_without_applying",preview_started.ok and preview_wait < 3000 and gui_panel.proposal.ok and ax_preview.ok and gui_panel.proposal_hash() != "" and gui_panel.proposal_hash() == ax_signature and ax_panel.proposal.base_hash == prior_hash and PopulationDocument.hash_source(gui_panel.session.data) == prior_hash and gui_panel.session.can_undo())
	var proposal_depth: int = ax_panel.session._undo.size()
	var wrong_confirm: Dictionary = ax_presentation.ax_invoke("population/plan/apply",{"expected_source_hash":ax_proposal.base_hash,"proposal_hash":ax_signature,"confirm_apply":false})
	var invalid_signature: String = "f".repeat(64)
	var tampered_result: Dictionary = ax_presentation.ax_invoke("population/plan/apply",{"expected_source_hash":ax_proposal.base_hash,"proposal_hash":invalid_signature,"confirm_apply":true})
	var original_proposal: Dictionary = ax_panel.proposal.duplicate(true)
	ax_panel.proposal.data.name += " tampered"
	var data_tamper: Dictionary = ax_panel.apply_proposal(prior_hash,ax_signature,true)
	ax_panel.proposal = original_proposal.duplicate(true)
	ax_panel.proposal.diff.added.append("tampered")
	var diff_tamper: Dictionary = ax_panel.apply_proposal(prior_hash,ax_signature,true)
	ax_panel.proposal = original_proposal
	check("proposal_confirmation_signature_and_internal_identity_are_required",not wrong_confirm.ok and not tampered_result.ok and not data_tamper.ok and not diff_tamper.ok and PopulationDocument.hash_source(ax_panel.session.data) == prior_hash and ax_panel.session._undo.size() == proposal_depth)
	var gui_apply: Dictionary = gui_panel.apply_proposal(prior_hash,gui_panel.proposal_hash(),true)
	var ax_apply: Dictionary = ax_presentation.ax_invoke("population/plan/apply",{"expected_source_hash":prior_hash,"proposal_hash":ax_signature,"confirm_apply":true})
	var applied_gui_hash: String = PopulationDocument.hash_source(gui_panel.session.data)
	var applied_ax_hash: String = PopulationDocument.hash_source(ax_panel.session.data)
	var gui_undo: bool = gui_panel.session.undo(); var ax_undo: bool = ax_panel.session.undo()
	var gui_undo_hash: String = PopulationDocument.hash_source(gui_panel.session.data); var ax_undo_hash: String = PopulationDocument.hash_source(ax_panel.session.data)
	var gui_redo: bool = gui_panel.session.redo(); var ax_redo: bool = ax_panel.session.redo()
	check("proposal_apply_commits_once_and_undo_redo_whole_plan",gui_apply.ok and ax_apply.ok and applied_gui_hash == applied_ax_hash and gui_undo and ax_undo and gui_undo_hash == prior_hash and ax_undo_hash == prior_hash and gui_redo and ax_redo and PopulationDocument.hash_source(gui_panel.session.data) == applied_gui_hash and PopulationDocument.hash_source(ax_panel.session.data) == applied_ax_hash and gui_panel.session._undo.size() == proposal_depth+1 and ax_panel.session._undo.size() == proposal_depth+1)
	var stale_hash: String = "0".repeat(64); var stale_depth: int = ax_panel.session._undo.size()
	var stale_apply: Dictionary = ax_presentation.ax_invoke("population/plan/apply",{"expected_source_hash":stale_hash,"proposal_hash":ax_signature,"confirm_apply":true})
	check("stale_proposal_base_is_refused_without_mutation",not stale_apply.ok and PopulationDocument.hash_source(ax_panel.session.data) == applied_ax_hash and ax_panel.session._undo.size() == stale_depth)
	var real_spec: Dictionary = source.brushes[0].species[0]
	var manual_slot: Dictionary = {"slot_id":"manual_ui","brush_id":source.brushes[0].brush_id,"surface_id":source.brushes[0].surface_id,"position_xyz":source.brushes[0].center_xyz,"species_id":real_spec.species_id,"category":real_spec.category,"origin_id":real_spec.origin_id,"fixed":true,"site_id":""}
	var gui_manual: Dictionary = gui_panel.apply_operation("slot/upsert",manual_slot)
	var ax_manual: Dictionary = ax_presentation.ax_invoke("population/slot/upsert",manual_slot)
	var retained_brush_slots: Array = ax_panel.session.data.slots.filter(func(item: Dictionary) -> bool: return item.brush_id != source.brushes[0].brush_id).duplicate(true)
	var gui_remove_brush: Dictionary = gui_panel.apply_operation("brush/remove",{"brush_id":source.brushes[0].brush_id,"confirm_remove":true})
	var ax_remove_brush: Dictionary = ax_presentation.ax_invoke("population/brush/remove",{"brush_id":source.brushes[0].brush_id,"confirm_remove":true})
	check("manual_fixed_slot_and_brush_removal_preserve_other_brush_slots",gui_manual.ok and ax_manual.ok and gui_remove_brush.ok and ax_remove_brush.ok and ax_panel.session.data.slots == retained_brush_slots and gui_panel.session.data.slots == retained_brush_slots and gui_remove_brush.removed_ids.has("manual_ui"))
	var non_fixed_slot: Dictionary = manual_slot.duplicate(true); non_fixed_slot.slot_id = "not_fixed"; non_fixed_slot.fixed = false
	check("ax_rejects_manual_nonfixed_slot_without_partial_history",not ax_presentation.ax_invoke("population/slot/upsert",non_fixed_slot).ok and not ax_panel.session.data.slots.any(func(item: Dictionary) -> bool: return item.slot_id == "not_fixed"))
	gui_panel.session.replace(realized_population); ax_panel.session.replace(realized_population)
	var gui_open_patrols: Callable = func() -> void: gui_panel.open_patrols()
	var ax_open_patrols: Dictionary = ax_presentation.ax_invoke("population/open_patrols",{})
	gui_open_patrols.call(); await frames(4)
	gui_patrol = gui_panel.patrol_window.get_child(0) if gui_panel.patrol_window != null else null
	ax_patrol = ax_panel.patrol_window.get_child(0) if ax_panel.patrol_window != null else null
	var gui_patrol_query: Dictionary = gui_patrol.map_query() if gui_patrol != null else {"ok":false}
	var ax_patrol_presentation: Variant = ax_patrol.get_node_or_null("AuthoringPresentation") if ax_patrol != null else null
	var ax_patrol_query: Dictionary = ax_patrol_presentation.ax_invoke("patrol/map/query",{}) if ax_patrol_presentation != null else {"ok":false}
	check("patrol_windows_import_realized_guard_and_reuse_population_map_query",ax_open_patrols.ok and gui_patrol != null and ax_patrol != null and gui_patrol.get_script() == PatrolPanel and ax_patrol.get_script() == PatrolPanel and gui_patrol.session.data.population[0].slots.any(func(slot: Dictionary) -> bool: return slot.slot_id == "guard") and gui_patrol_query.ok and ax_patrol_query.ok and gui_patrol_query.map_package_hash == ax_patrol_query.map_package_hash and gui_patrol_query.surfaces == ax_patrol_query.surfaces and gui_patrol_query.sockets == ax_patrol_query.sockets)
	if gui_patrol == null or ax_patrol == null: finish(); return
	var route: Dictionary = patrol_fixture.patrols[0].duplicate(true)
	var gui_route: Dictionary = gui_patrol.apply_operation("route/upsert",route)
	var ax_route: Dictionary = ax_patrol_presentation.ax_invoke("patrol/route/upsert",route)
	check("patrol_gui_and_ax_route_proposals_have_equal_source",gui_route.ok and ax_route.ok and PatrolDocument.hash_source(gui_patrol.session.data) == PatrolDocument.hash_source(ax_patrol.session.data))
	var remove_unconfirmed: Dictionary = ax_patrol_presentation.ax_invoke("patrol/route/remove",{"patrol_id":route.patrol_id,"confirm_remove":false})
	check("patrol_route_removal_requires_confirmation",not remove_unconfirmed.ok and PatrolDocument.hash_source(ax_patrol.session.data) == PatrolDocument.hash_source(gui_patrol.session.data))
	var gui_route_data: Dictionary = gui_patrol.current_route()
	gui_patrol.mode.select(1); gui_patrol.apply_mode()
	var ax_mode_route: Dictionary = gui_patrol.current_route()
	var ax_mode_route_result: Dictionary = ax_patrol_presentation.ax_invoke("patrol/route/upsert",ax_mode_route)
	gui_patrol.points.select(1); gui_patrol.wait_time.value = 1.8; gui_patrol.apply_wait()
	var ax_wait_route: Dictionary = gui_patrol.current_route()
	var ax_wait: Dictionary = ax_patrol_presentation.ax_invoke("patrol/route/upsert",ax_wait_route)
	var wait_point_id: String = gui_patrol.current_route().waypoints[1].point_id
	var hash_before_move: String = PatrolDocument.hash_source(ax_patrol.session.data)
	var route_before_move: Dictionary = ax_patrol.session.data.patrols[0].duplicate(true)
	var gui_route_before_move: Dictionary = gui_patrol.current_route()
	var ax_route_before_move: Dictionary = ax_patrol.session.data.patrols[0].duplicate(true)
	var move_point_id: String = wait_point_id
	gui_patrol.points.select(1); gui_patrol.move_point(1)
	var ax_move: Dictionary = ax_patrol_presentation.ax_invoke("patrol/waypoint/move",{"patrol_id":route.patrol_id,"point_id":move_point_id,"direction":1})
	gui_patrol.slots.select(0); gui_patrol.assign_slots()
	var ax_assign_route: Dictionary = gui_patrol.current_route()
	var ax_assign: Dictionary = ax_patrol_presentation.ax_invoke("patrol/route/upsert",ax_assign_route)
	check("real_patrol_controls_mode_wait_move_and_slot_assignment_match_ax",gui_route_data.mode == "loop" and ax_mode_route_result.ok and ax_wait.ok and ax_move.ok and ax_assign.ok and route_before_move == gui_route_before_move and route_before_move == ax_route_before_move and gui_patrol.session.data.patrols[0] == ax_patrol.session.data.patrols[0] and gui_patrol.session.data.patrols[0].mode == "ping_pong" and gui_patrol.session.data.patrols[0].waypoints[2].point_id == wait_point_id and gui_patrol.session.data.patrols[0].waypoints[2].wait_seconds == 1.8 and gui_patrol.session.data.patrols[0].slot_ids == ["guard"] and PatrolDocument.validate(gui_patrol.session.data).ok)
	var patrol_bad: Dictionary = ax_patrol_presentation.ax_invoke("patrol/waypoint/upsert",{"patrol_id":route.patrol_id,"point_id":"bad","surface_id":"missing","position_xyz":[NAN,0,0],"wait_seconds":0})
	check("patrol_nested_nan_and_unknown_references_reject_without_history",not patrol_bad.ok and PatrolDocument.hash_source(ax_patrol.session.data) == PatrolDocument.hash_source(gui_patrol.session.data))
	var route_hash_before_history: String = PatrolDocument.hash_source(ax_patrol.session.data)
	var route_undo: bool = ax_patrol.session.undo(); var route_undo_hash: String = PatrolDocument.hash_source(ax_patrol.session.data)
	var gui_route_undo: bool = gui_patrol.session.undo(); var gui_route_undo_hash: String = PatrolDocument.hash_source(gui_patrol.session.data)
	var route_redo: bool = ax_patrol.session.redo(); var route_redo_hash: String = PatrolDocument.hash_source(ax_patrol.session.data)
	var gui_route_redo: bool = gui_patrol.session.redo(); var gui_route_redo_hash: String = PatrolDocument.hash_source(gui_patrol.session.data)
	check("patrol_route_undo_redo_restore_full_order_and_slot_assignments",route_undo and gui_route_undo and route_undo_hash == hash_before_move and gui_route_undo_hash == hash_before_move and route_redo and gui_route_redo and route_redo_hash == route_hash_before_history and gui_route_redo_hash == route_hash_before_history and ax_patrol.session.data.patrols[0].slot_ids == route.slot_ids)
	gui_patrol.bake(); var ax_compile: Dictionary = ax_patrol_presentation.ax_invoke("patrol/compile",{})
	var patrol_wait: int = 0
	while (gui_patrol.job != null or ax_patrol.job != null) and patrol_wait < 3000: await process_frame; patrol_wait += 1
	check("patrol_workers_complete_against_canonical_compiler",ax_compile.ok and patrol_wait < 3000 and gui_patrol.result.get("ok",false) and ax_patrol.result.get("ok",false) and gui_patrol.result.package.package_hash == ax_patrol.result.package.package_hash and PatrolCompiler.compile(gui_patrol.session.data).output_hash == gui_patrol.result.output_hash)
	var population_path: String = ProjectSettings.globalize_path("res://.godot/f9_encounter_authoring/"+run_id+"/native_population.json")
	DirAccess.make_dir_recursive_absolute(population_path.get_base_dir())
	var save_ax: Dictionary = ax_presentation.ax_invoke("population/document/save",{"path":population_path})
	var loaded: Dictionary = PopulationStore.load_source(population_path)
	var saved_source_hash: String = PopulationDocument.hash_source(loaded.data) if loaded.ok else ""
	var saved_byte_hash: String = ax_panel.expected_hash
	var name_result: Dictionary = ax_presentation.ax_invoke("population/document/name",{"name":"Rascunho pt-BR"})
	var dirty_source_hash: String = PopulationDocument.hash_source(ax_panel.session.data)
	ax_panel.preserve_draft()
	var draft_loaded: Dictionary = PopulationStore.load_source(ax_panel._autosave)
	var draft_hash: String = PopulationDocument.hash_source(draft_loaded.data) if draft_loaded.ok else ""
	var new_without_confirm: Dictionary = ax_presentation.ax_invoke("population/document/new",{"document_id":"replacement","name":"Novo","confirm_discard":false})
	var dirty_preserved_hash: String = PopulationDocument.hash_source(ax_panel.session.data)
	var make_new: Dictionary = ax_presentation.ax_invoke("population/document/new",{"document_id":"replacement","name":"Novo","confirm_discard":true})
	var reopened: Dictionary = ax_presentation.ax_invoke("population/document/open",{"path":population_path,"confirm_discard":true})
	check("document_save_dirty_new_confirmation_draft_and_real_open",save_ax.ok and loaded.ok and name_result.ok and ax_panel.session.dirty() == false and saved_source_hash != dirty_source_hash and draft_loaded.ok and draft_hash == dirty_source_hash and not new_without_confirm.ok and dirty_preserved_hash == dirty_source_hash and make_new.ok and reopened.ok and PopulationDocument.hash_source(ax_panel.session.data) == saved_source_hash and ax_panel.expected_hash == saved_byte_hash)
	var external_edit: Dictionary = loaded.data.duplicate(true); external_edit.name = "Edição externa coerente"
	var external_save: Dictionary = PopulationStore.save_source(population_path,external_edit,saved_byte_hash)
	var expected_before_conflict: String = ax_panel.expected_hash
	var path_before_conflict: String = ax_panel.source_path
	var dirty_name: Dictionary = ax_presentation.ax_invoke("population/document/name",{"name":"Conflito local"})
	var local_dirty_hash_before_conflict: String = PopulationDocument.hash_source(ax_panel.session.data)
	var panel_conflict: Dictionary = ax_presentation.ax_invoke("population/document/save",{"path":population_path})
	var bytes_after_conflict: Dictionary = PopulationStore.load_source(population_path)
	var conflict_expected_hash: String = ax_panel.expected_hash
	var conflict_path: String = ax_panel.source_path
	var conflict_dirty: bool = ax_panel.session.dirty()
	var conflict_source_hash: String = PopulationDocument.hash_source(ax_panel.session.data)
	var reopen_unconfirmed: Dictionary = ax_presentation.ax_invoke("population/document/open",{"path":population_path,"confirm_discard":false})
	var reopen_external: Dictionary = ax_presentation.ax_invoke("population/document/open",{"path":population_path,"confirm_discard":true})
	check("panel_disk_conflict_preserves_state_then_reopens_external_revision",external_save.ok and dirty_name.ok and panel_conflict.code == "io_conflict" and conflict_expected_hash == expected_before_conflict and conflict_path == path_before_conflict and conflict_dirty and conflict_source_hash == local_dirty_hash_before_conflict and bytes_after_conflict.ok and PopulationDocument.hash_source(bytes_after_conflict.data) == PopulationDocument.hash_source(external_edit) and not reopen_unconfirmed.ok and reopen_external.ok and PopulationDocument.hash_source(ax_panel.session.data) == PopulationDocument.hash_source(external_edit) and ax_panel.expected_hash == external_save.byte_hash)
	var stale_compile_before: String = PopulationDocument.hash_source(ax_panel.session.data)
	var started: Dictionary = ax_presentation.ax_invoke("population/compile",{})
	var cancelled: Dictionary = ax_presentation.ax_invoke("population/cancel",{})
	var worker_wait: int = 0
	while ax_panel.job != null and worker_wait < 3000: await process_frame; worker_wait += 1
	var cancelled_cleanly: bool = started.ok and cancelled.ok and worker_wait < 3000 and ax_panel.job == null and PopulationDocument.hash_source(ax_panel.session.data) == stale_compile_before and ax_panel.result.code == "cancelled"
	var stale_preview_started: Dictionary = ax_presentation.ax_invoke("population/plan/preview",{})
	var mutate_during_worker: Dictionary = ax_presentation.ax_invoke("population/document/name",{"name":"Mudança durante prévia"})
	var mutated_source_hash: String = PopulationDocument.hash_source(ax_panel.session.data)
	var mutated_history_depth: int = ax_panel.session._undo.size()
	var stale_worker_wait: int = 0
	while ax_panel.job != null and stale_worker_wait < 3000: await process_frame; stale_worker_wait += 1
	var stale_panel_unpublished: bool = ax_panel.proposal.is_empty() or not ax_panel.proposal.get("ok",false)
	var compiler_probe := PopulationCompiler.new()
	compiler_probe.start(realized_population,"regenerate")
	var compiler_probe_wait: int = 0
	while not compiler_probe.ready() and compiler_probe_wait < 3000: await process_frame; compiler_probe_wait += 1
	var compiler_take_stale: Dictionary = compiler_probe.take("0".repeat(64)) if compiler_probe.ready() else {"ok":false,"code":"timeout"}
	check("worker_cancel_refresh_and_compiler_take_stale_preserve_source_semantics",cancelled_cleanly and stale_preview_started.ok and mutate_during_worker.ok and stale_worker_wait < 3000 and ax_panel.job == null and stale_panel_unpublished and PopulationDocument.hash_source(ax_panel.session.data) == mutated_source_hash and ax_panel.session._undo.size() == mutated_history_depth and ax_panel.session.data.name == "Mudança durante prévia" and compiler_probe_wait < 3000 and compiler_take_stale.code == "stale_source")
	gui_panel.prepare_plan(); var final_plan_wait: int = 0
	while gui_panel.job != null and final_plan_wait < 3000: await process_frame; final_plan_wait += 1
	var final_plan: Dictionary = gui_panel.proposal
	var final_signature: String = gui_panel.proposal_hash()
	var applied_final_plan: Dictionary = gui_panel.apply_proposal(PopulationDocument.hash_source(gui_panel.session.data),final_signature,true) if final_plan.get("ok",false) else {"ok":false}
	gui_panel.bake(); var population_wait: int = 0
	while gui_panel.job != null and population_wait < 3000: await process_frame; population_wait += 1
	check("population_compiler_returns_canonical_package_body",final_plan_wait < 3000 and applied_final_plan.ok and population_wait < 3000 and gui_panel.result.get("ok",false) and gui_panel.result.package.manifest.population.slots.size() == gui_panel.session.data.slots.size() and not gui_panel.result.package.manifest.population.slots.is_empty() and gui_panel.result.package.profile.radius == 20.0 and gui_panel.result.package.profile.height == 32.0 and gui_panel.canvas.encounters.package_hash == gui_panel.result.package.package_hash and PopulationCompiler.compile(gui_panel.session.data).output_hash == gui_panel.result.output_hash)
	ax_window.hide(); ax_patrol.get_parent().hide(); ax_shell.composition_window.hide()
	gui_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gui_shell.composition_window.position = Vector2i.ZERO; gui_shell.composition_window.size = Vector2i(1440,1000); gui_shell.composition_window.show()
	gui_window.position = Vector2i.ZERO; gui_window.size = Vector2i(1400,900); gui_window.show()
	gui_panel.patrol_window.hide()
	await frames(5)
	var population_image: Image = root.get_texture().get_image()
	var population_saved: Error = population_image.save_png(evidence_dir.path_join("encounter_population_native.png")) if population_image != null else FAILED
	var population_size: Vector2i = population_image.get_size() if population_image != null else Vector2i.ZERO
	var population_visible: bool = gui_window.visible and gui_shell.composition_window.visible and gui_panel.is_visible_in_tree()
	gui_window.position = Vector2i.ZERO; gui_window.size = Vector2i(1400,900); gui_window.show()
	gui_panel.patrol_window.position = Vector2i.ZERO; gui_panel.patrol_window.size = Vector2i(1400,900); gui_panel.patrol_window.show()
	await frames(5)
	var patrol_image: Image = root.get_texture().get_image()
	var patrol_saved: Error = patrol_image.save_png(evidence_dir.path_join("encounter_patrol_native.png")) if patrol_image != null else FAILED
	var patrol_size: Vector2i = patrol_image.get_size() if patrol_image != null else Vector2i.ZERO
	var patrol_visible: bool = gui_panel.patrol_window.visible and gui_panel.patrol_window.get_parent().is_visible_in_tree() and gui_window.visible and gui_shell.composition_window.visible
	var capture_details: Dictionary = {"population_saved":population_saved == OK,"population_size":population_size,"population_visible":population_visible,"patrol_saved":patrol_saved == OK,"patrol_size":patrol_size,"patrol_visible":patrol_visible,"physical_window":DisplayServer.window_get_size(),"encounter_package_hash":gui_panel.result.package.package_hash}
	check("separate_native_population_and_patrol_captures_use_visible_real_ancestry_at_1440x1000",population_saved == OK and patrol_saved == OK and population_size == Vector2i(1440,1000) and patrol_size == Vector2i(1440,1000) and DisplayServer.window_get_size() == Vector2i(1440,1000) and population_visible and patrol_visible and gui_panel.result.package.profile.radius == 20.0 and gui_panel.result.package.profile.height == 32.0,capture_details)
	finish()

func finish() -> void:
	var ok: bool = checks.size() == EXPECTED_COUNT and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_ENCOUNTER_UI_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"expected_count":EXPECTED_COUNT,"checks":checks,"evidence_dir":evidence_dir}))
	Presentation.active_mode = "ux"
	for shell: Variant in [gui_shell,ax_shell]:
		if is_instance_valid(shell): shell.free()
	quit(0 if ok else 1)
