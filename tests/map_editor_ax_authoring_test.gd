extends SceneTree
## Headless contract proof for semantic AX authoring through the real editor shell.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const Operations = preload("res://scripts/map_authoring/terrain/terrain_operations.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Store = preload("res://scripts/map_authoring/io/source_store.gd")

var checks: Array[Dictionary] = []
var shell: Control
var presentation: Variant
var terrain_presentation: Variant

func _initialize() -> void:
	run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("F9_AX_AUTHORING_CHECK "+id+" "+str(ok))

func invoke(id: String, parameters: Dictionary = {}) -> Dictionary:
	var target: Variant = terrain_presentation if id.begins_with("terrain/") else presentation
	return target.ax_invoke(id,parameters) if target != null else {"ok":false,"code":"presentation_missing"}

func run() -> void:
	Presentation.active_mode = "ux"
	root.size = Vector2i(1280,900)
	shell = Shell.new()
	root.add_child(shell)
	await process_frame
	presentation = shell.get_node_or_null("AuthoringPresentation")
	terrain_presentation = shell.terrain.get_node_or_null("AuthoringPresentation") if shell.terrain != null else null
	check("real_shell_mounts_piece_and_terrain_presentations",presentation != null and terrain_presentation != null and shell.session.document() != null)
	var piece_commands: Array = presentation.ax_snapshot().commands if presentation != null else []
	var terrain_commands: Array = terrain_presentation.ax_snapshot().commands if terrain_presentation != null else []
	var required_piece := ["piece/document/new","piece/document/name","piece/document/open","piece/document/save","piece/history/undo","piece/history/redo"]
	var required_terrain := ["terrain/grid/create","terrain/layer/select","terrain/layer/lock","terrain/layer/protection","terrain/bridge/create","terrain/connector/upsert","terrain/connector/remove","terrain/brush/stroke"]
	check("closed_semantic_command_surface_is_advertised",required_piece.all(func(id: String) -> bool: return piece_commands.any(func(command: Dictionary) -> bool: return command.id == id)) and required_terrain.all(func(id: String) -> bool: return terrain_commands.any(func(command: Dictionary) -> bool: return command.id == id)))
	var wrong_mode := invoke("terrain/grid/create",grid_parameters("wrong_mode_layer"))
	check("ax_command_refuses_ux_mode_without_mutation",not wrong_mode.ok and wrong_mode.code == "ax_mode_required" and shell.session._undo.is_empty())
	var entered := presentation.set_mode("ax") if presentation != null else {"ok":false}
	check("ax_mode_is_explicitly_entered",entered.ok and presentation.ax_snapshot().mode == "ax")
	shell.session.saved_hash = shell.session.document().semantic_hash()
	var new_piece := presentation.ax_invoke("piece/document/new",{"document_id":"ax_authoring_piece","name":"Peça AX","confirm_discard":false}) if presentation != null else {"ok":false}
	check("new_piece_uses_explicit_identity",new_piece.ok and shell.session.document().to_data().document_id == "ax_authoring_piece" and shell.session.document().to_data().name == "Peça AX")
	var empty_hash: String = shell.session.document().semantic_hash()
	var before_source: Dictionary = shell.session.document().to_data()
	var proposed := Operations.propose(before_source,"grid/create",grid_parameters("ax_layer_one"))
	check("grid_proposal_is_pure_and_valid",proposed.ok and proposed.changed and shell.session.document().semantic_hash() == empty_hash and shell.session.document().to_data() == before_source)
	var first_grid := invoke("terrain/grid/create",grid_parameters("ax_layer_one"))
	var first_hash: String = shell.session.document().semantic_hash()
	check("first_grid_is_committed_through_document_session",first_grid.ok and first_grid.entity_id == "ax_layer_one" and first_grid.output_hash == first_hash and shell.session.can_undo())
	var depth_after_grid: int = shell.session._undo.size()
	var duplicate_grid := invoke("terrain/grid/create",grid_parameters("ax_layer_one"))
	check("duplicate_ids_fail_without_history_or_source_change",not duplicate_grid.ok and shell.session._undo.size() == depth_after_grid and shell.session.document().semantic_hash() == first_hash)
	var non_finite := grid_parameters("nan_layer")
	non_finite.height = NAN
	var invalid_grid := invoke("terrain/grid/create",non_finite)
	check("non_finite_grid_values_fail_without_history",not invalid_grid.ok and shell.session._undo.size() == depth_after_grid and shell.session.document().semantic_hash() == first_hash)
	var extra_field := grid_parameters("unknown_field_layer"); extra_field.unknown = true
	var oversized_grid := grid_parameters("oversized_grid"); oversized_grid.columns = 258
	var surface_as_layer_id := invoke("terrain/bridge/create",{"surface_id":"ax_layer_one","layer_id":"ax_layer_one","origin_xz":[300.0,300.0],"width":100.0,"length":100.0,"height":40.0})
	var malformed_results := [invoke("terrain/grid/create",extra_field),invoke("terrain/grid/create",oversized_grid)]
	check("unknown_fields_caps_and_cross_namespace_ids_are_rejected",malformed_results.all(func(result: Dictionary) -> bool: return not result.ok) and not surface_as_layer_id.ok and shell.session._undo.size() == depth_after_grid)
	var second_grid := invoke("terrain/grid/create",{"layer_id":"ax_layer_two","name":"Segunda camada","origin_xz":[1000.0,1000.0],"columns":3,"rows":3,"sample_spacing":40.0,"height":8.0})
	var selected_first := invoke("terrain/layer/select",{"layer_id":"ax_layer_one"})
	check("second_grid_and_explicit_selection_are_committed",second_grid.ok and second_grid.entity_id == "ax_layer_two" and selected_first.ok and shell.session.document().to_data().layers.size() == 2 and shell.terrain.selected_layer == "ax_layer_one")
	var stroke := invoke("terrain/brush/stroke",{"points":[[64.0,64.0]],"options":{"mode":"raise","shape":"circle","material":"earth","radius":32.0,"strength":8.0,"hardness":0.5,"target":0.0,"end_height":40.0}})
	check("ax_brush_stroke_routes_through_existing_brush_producer",stroke.ok and shell.session.document().to_data().layers[0].heights[12] > 0.0)
	var region_setup: Dictionary = shell.session.document().to_data()
	region_setup.regions.append({"region_id":"protected_plot","layer_id":"ax_layer_one","polygon_xz":[[0.0,100.0],[100.0,100.0],[100.0,200.0],[0.0,200.0]],"purpose":"protected"})
	var region_seeded := shell.session.apply(region_setup)
	var protected := invoke("terrain/layer/protection",{"layer_id":"ax_layer_one","region_ids":["protected_plot"]})
	var protected_depth: int = shell.session._undo.size()
	var blocked_protected_bridge := invoke("terrain/bridge/create",{"surface_id":"protected_bridge","layer_id":"ax_layer_one","origin_xz":[0.0,100.0],"width":100.0,"length":100.0,"height":40.0})
	check("protected_region_refuses_intersecting_bridge_without_partial_history",region_seeded.ok and protected.ok and not blocked_protected_bridge.ok and blocked_protected_bridge.code == "region_protected" and shell.session._undo.size() == protected_depth)
	var bridge := invoke("terrain/bridge/create",{"surface_id":"ax_bridge","layer_id":"ax_layer_one","origin_xz":[300,300],"width":100.0,"length":100.0,"height":40.0})
	var bridge_hash: String = shell.session.document().semantic_hash()
	check("bridge_is_created_on_existing_layer",bridge.ok and bridge.entity_id == "ax_bridge" and shell.session.document().to_data().special_surfaces.size() == 1)
	var connector := connector_parameters("ax_gate","ax_layer_one")
	var connected := invoke("terrain/connector/upsert",connector)
	check("canonical_walk_connector_is_upserted",connected.ok and shell.session.document().to_data().connectors.size() == 1 and shell.session.document().to_data().connectors[0] == connector)
	var no_op_depth: int = shell.session._undo.size()
	var no_op_unlock := invoke("terrain/layer/lock",{"layer_id":"ax_layer_one","locked":false})
	var no_op_connector := invoke("terrain/connector/upsert",connector)
	check("no_op_lock_and_connector_upsert_do_not_add_history",no_op_unlock.ok and no_op_connector.ok and shell.session._undo.size() == no_op_depth)
	var locked := invoke("terrain/layer/lock",{"layer_id":"ax_layer_one","locked":true})
	var locked_depth: int = shell.session._undo.size()
	var blocked_bridge := invoke("terrain/bridge/create",{"surface_id":"blocked_bridge","layer_id":"ax_layer_one","origin_xz":[300,100],"width":100.0,"length":100.0,"height":40.0})
	var blocked_connector := invoke("terrain/connector/upsert",connector_parameters("blocked_gate","ax_layer_one"))
	var blocked_existing_connector := invoke("terrain/connector/remove",{"connector_id":"ax_gate"})
	var blocked_transfer := invoke("terrain/connector/upsert",connector_parameters("ax_gate","ax_layer_two"))
	check("locked_source_rejects_bridge_new_existing_and_transferred_connector_without_partial_history",locked.ok and not blocked_bridge.ok and not blocked_connector.ok and not blocked_existing_connector.ok and not blocked_transfer.ok and blocked_transfer.code == "layer_locked" and shell.session._undo.size() == locked_depth and shell.session.document().to_data().connectors.size() == 1)
	var unlocked := invoke("terrain/layer/lock",{"layer_id":"ax_layer_one","locked":false})
	var bad_connector := connector_parameters("bad_gate","missing_surface")
	var rejected_connector := invoke("terrain/connector/upsert",bad_connector)
	check("connector_reference_failure_preserves_document",unlocked.ok and not rejected_connector.ok and shell.session.document().to_data().connectors.size() == 1)
	var missing_protection := invoke("terrain/layer/protection",{"layer_id":"ax_layer_one","region_ids":["missing_region"]})
	check("protection_requires_existing_region",not missing_protection.ok and shell.session.document().to_data().layers[0].protected_regions == ["protected_plot"])
	var selection_hash: String = shell.session.document().semantic_hash()
	var selected := invoke("terrain/layer/select",{"layer_id":"ax_layer_one"})
	check("layer_selection_changes_editor_target_without_source_revision",selected.ok and shell.terrain.selected_layer == "ax_layer_one" and shell.session.document().semantic_hash() == selection_hash)
	var source_before_undo: String = shell.session.document().semantic_hash()
	var undone := invoke("piece/history/undo",{})
	var undo_hash: String = shell.session.document().semantic_hash()
	var redone := invoke("piece/history/redo",{})
	check("ax_undo_redo_round_trips_exact_semantic_source",undone.ok and redone.ok and shell.session.document().semantic_hash() == source_before_undo and undo_hash != source_before_undo)
	var empty_undo := false
	while shell.session.can_undo(): shell.session.undo()
	empty_undo = not invoke("piece/history/undo",{}).ok
	check("undo_reports_empty_history_without_mutation",empty_undo and shell.session._undo.is_empty())
	var named := presentation.ax_invoke("piece/document/name",{"name":"Peça AX renomeada"}) if presentation != null else {"ok":false}
	check("document_name_is_semantic_and_undoable",named.ok and shell.session.document().to_data().name == "Peça AX renomeada")
	var base := ProjectSettings.globalize_path("res://.godot/f9_ax_authoring")
	DirAccess.make_dir_recursive_absolute(base)
	var run_id := str(Time.get_ticks_usec())
	var source_path := base.path_join("roundtrip_piece_"+run_id+".json")
	var saved := presentation.ax_invoke("piece/document/save",{"path":source_path}) if presentation != null else {"ok":false}
	var saved_hash: String = shell.session.document().semantic_hash()
	check("piece_save_uses_canonical_store_and_hash",saved.ok and FileAccess.file_exists(source_path) and saved.output_hash == saved_hash and not shell.session.dirty())
	var pending_source_hash: String = shell.session.document().semantic_hash()
	var pending_history_depth: int = shell.session._undo.size()
	shell.title_edit.text = "Título temporário pendente"
	var missing_parent_path := base.path_join("parent_missing_"+run_id).path_join("cannot_save.json")
	var failed_save := presentation.ax_invoke("piece/document/save",{"path":missing_parent_path}) if presentation != null else {"ok":false}
	check("failed_save_with_pending_title_preserves_document_and_history",not failed_save.ok and shell.session.document().semantic_hash() == pending_source_hash and shell.session._undo.size() == pending_history_depth and shell.title_edit.text == "Título temporário pendente" and not FileAccess.file_exists(missing_parent_path))
	var changed_name := presentation.ax_invoke("piece/document/name",{"name":"Mudança não salva"}) if presentation != null else {"ok":false}
	var external_data: Dictionary = shell.session.document().to_data()
	external_data.name = "Alterada externamente"
	external_data.revision = int(external_data.revision)+1
	var external_file := FileAccess.open(source_path,FileAccess.WRITE)
	if external_file != null:
		external_file.store_string(JSON.stringify(external_data,"",true,true)); external_file.flush(); external_file.close()
	var external_byte_hash: String = Schema.bytes_hash(FileAccess.get_file_as_bytes(source_path)) if FileAccess.file_exists(source_path) else ""
	var save_conflict := presentation.ax_invoke("piece/document/save",{"path":source_path}) if presentation != null else {"ok":false}
	check("save_conflict_preserves_external_file_and_local_draft",changed_name.ok and not external_byte_hash.is_empty() and not save_conflict.ok and save_conflict.code == "io_conflict" and Schema.bytes_hash(FileAccess.get_file_as_bytes(source_path)) == external_byte_hash and shell.session.document().to_data().name == "Mudança não salva")
	var denied_open := presentation.ax_invoke("piece/document/open",{"path":source_path,"confirm_discard":false}) if presentation != null else {"ok":false}
	var opened := presentation.ax_invoke("piece/document/open",{"path":source_path,"confirm_discard":true}) if presentation != null else {"ok":false}
	check("dirty_open_requires_confirmation_then_restores_external_source",not denied_open.ok and denied_open.code == "confirmation_required" and opened.ok and shell.session.document().to_data().name == "Alterada externamente" and Schema.bytes_hash(FileAccess.get_file_as_bytes(source_path)) == external_byte_hash)
	var dirty_name := presentation.ax_invoke("piece/document/name",{"name":"Rascunho antes de nova peça"}) if presentation != null else {"ok":false}
	var denied_new := presentation.ax_invoke("piece/document/new",{"document_id":"after_dirty_ax_piece","name":"Nova peça","confirm_discard":false}) if presentation != null else {"ok":false}
	var dirty_source_hash: String = shell.session.document().semantic_hash()
	var dirty_history_depth: int = shell.session._undo.size()
	var pending_path := source_path+".autosave.pending"
	var pending_blocker := FileAccess.open(pending_path,FileAccess.WRITE)
	if pending_blocker != null:
		pending_blocker.store_string("existing pending recovery sentinel")
		pending_blocker.flush()
		pending_blocker.close()
	var failed_preserve_new := presentation.ax_invoke("piece/document/new",{"document_id":"after_dirty_ax_piece","name":"Nova peça","confirm_discard":true}) if presentation != null else {"ok":false}
	check("confirmed_dirty_new_refuses_pending_recovery_without_discard",dirty_name.ok and not denied_new.ok and denied_new.code == "confirmation_required" and not failed_preserve_new.ok and failed_preserve_new.code == "io_recovery_required" and shell.session.document().semantic_hash() == dirty_source_hash and shell.session._undo.size() == dirty_history_depth and FileAccess.file_exists(pending_path))
	var preserved_pending_path := source_path+".blocked_pending_"+run_id
	var pending_preserved := DirAccess.rename_absolute(pending_path,preserved_pending_path) == OK
	var accepted_new := presentation.ax_invoke("piece/document/new",{"document_id":"after_dirty_ax_piece","name":"Nova peça","confirm_discard":true}) if presentation != null else {"ok":false}
	var recovered_draft := Store.recover(source_path,"autosave")
	check("dirty_new_confirmation_preserves_and_recovers_autosaved_draft",pending_preserved and accepted_new.ok and shell.session.document().to_data().document_id == "after_dirty_ax_piece" and recovered_draft.ok and recovered_draft.data.name == "Rascunho antes de nova peça" and FileAccess.file_exists(preserved_pending_path))
	var history_before_malformed: int = shell.session._undo.size()
	var malformed_name := presentation.ax_invoke("piece/document/name",{"name":"Nome","unexpected":true}) if presentation != null else {"ok":false}
	check("malformed_document_command_is_rejected_without_history_change",not malformed_name.ok and shell.session._undo.size() == history_before_malformed)
	print("F9_AX_AUTHORING_RESULT "+JSON.stringify({"ok":checks.all(func(item: Dictionary) -> bool: return item.ok),"count":checks.size(),"expected_count":30,"checks":checks,"bridge_source_hash":bridge_hash,"first_grid_hash":first_hash,"run_id":run_id,"source_path":source_path}))
	Presentation.active_mode = "ux"
	quit(0 if checks.size() == 30 and checks.all(func(item: Dictionary) -> bool: return item.ok) else 1)

func grid_parameters(layer_id: String) -> Dictionary:
	return {"layer_id":layer_id,"name":"Camada AX","origin_xz":[0.0,0.0],"columns":5,"rows":5,"sample_spacing":32.0,"height":0.0}

func connector_parameters(connector_id: String, surface_id: String) -> Dictionary:
	return {"connector_id":connector_id,"surface_id":surface_id,"position_xyz":[0.0,0.0,50.0],"kind":"walk","normal_xyz":[0.0,0.0,-1.0],"width":32.0,"headroom":100.0,"tags":["map_editor"],"direction":"both"}
