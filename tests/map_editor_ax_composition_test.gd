extends SceneTree
## End-to-end source/session proof for the map composition AX surface.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapStore = preload("res://scripts/map_authoring/composition/map_store.gd")
const PieceStore = preload("res://scripts/map_authoring/io/source_store.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const MapContext = preload("res://scripts/map_authoring/context/piece_context.gd")
const Operations = preload("res://scripts/map_authoring/composition/map_operations.gd")

const EXPECTED_COUNT := 30
const COMPOSITION_COMMANDS: Array[String] = [
	"map/document/new", "map/document/name", "map/document/open", "map/document/save",
	"map/history/undo", "map/history/redo", "map/piece/add", "map/instance/select",
	"map/instance/transform", "map/instance/remove", "map/link/upsert", "map/link/remove",
	"map/mode/set", "map/context/set", "map/compile_map"]

var checks: Array[Dictionary] = []
var gui_shell: Variant
var ax_shell: Variant
var gui_panel: Variant
var ax_panel: Variant
var gui_presentation: Variant
var ax_presentation: Variant
var work_dir := ""

func _initialize() -> void:
	run.call_deferred()

func check(id: String, ok: bool, detail: Dictionary = {}) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_AX_COMPOSITION_CHECK "+id+" "+str(ok))
	if not ok and not detail.is_empty(): print("F9_AX_COMPOSITION_DIAGNOSTIC "+id+" "+JSON.stringify(detail))

func frames(count: int = 2) -> void:
	for _index: int in count: await process_frame

func run() -> void:
	Presentation.active_mode = "ux"
	root.size = Vector2i(1440,900)
	work_dir = ProjectSettings.globalize_path("res://.godot/f9_ax_composition/"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(work_dir)
	gui_shell = Shell.new(); gui_shell.name = "GuiCompositionShell"; root.add_child(gui_shell)
	ax_shell = Shell.new(); ax_shell.name = "AxCompositionShell"; root.add_child(ax_shell)
	await frames(3)
	var gui_piece_presentation: Variant = gui_shell.get_node_or_null("AuthoringPresentation")
	var ax_piece_presentation: Variant = ax_shell.get_node_or_null("AuthoringPresentation")
	var gui_ax_mode: Dictionary = gui_piece_presentation.set_mode("ax") if gui_piece_presentation != null else {"ok":false}
	var ax_ax_mode: Dictionary = ax_piece_presentation.set_mode("ax") if ax_piece_presentation != null else {"ok":false}
	var gui_open: Dictionary = gui_piece_presentation.ax_invoke("piece/compose_map",{}) if gui_piece_presentation != null else {"ok":false}
	var ax_open: Dictionary = ax_piece_presentation.ax_invoke("piece/compose_map",{}) if ax_piece_presentation != null else {"ok":false}
	await frames(4)
	var gui_window: Window = gui_shell.composition_window
	var ax_window: Window = ax_shell.composition_window
	gui_panel = gui_window.get_child(0) if gui_window != null and gui_window.get_child_count() > 0 else null
	ax_panel = ax_window.get_child(0) if ax_window != null and ax_window.get_child_count() > 0 else null
	gui_presentation = gui_panel.get_node_or_null("AuthoringPresentation") if gui_panel != null else null
	ax_presentation = ax_panel.get_node_or_null("AuthoringPresentation") if ax_panel != null else null
	check("real_shell_action_opens_real_map_panel_and_map_specific_presentations",gui_ax_mode.ok and ax_ax_mode.ok and gui_open.ok and ax_open.ok and gui_window != null and gui_window.visible and ax_window != null and ax_window.visible and gui_panel != null and ax_panel != null and gui_panel.session != null and ax_panel.session != null and gui_presentation != null and ax_presentation != null)
	var gui_mode: Dictionary = gui_presentation.set_mode("ax") if gui_presentation != null else {"ok":false}
	var ax_mode: Dictionary = ax_presentation.set_mode("ax") if ax_presentation != null else {"ok":false}
	var advertised: Array[String] = []
	if ax_presentation != null:
		for command: Dictionary in ax_presentation.ax_snapshot().commands: advertised.append(str(command.id))
	check("map_presentation_advertises_closed_composition_surface",gui_mode.ok and ax_mode.ok and COMPOSITION_COMMANDS.all(func(id: String) -> bool: return id in advertised))
	var ux_hash: String = MapDocument.hash_source(ax_panel.session.data)
	ax_presentation.set_mode("ux")
	var ux_reject: Dictionary = ax_presentation.ax_invoke("map/document/name",{"name":"Denied"})
	ax_presentation.set_mode("ax")
	check("ux_mode_refuses_ax_mutation",not ux_reject.ok and ux_reject.code == "ax_mode_required" and MapDocument.hash_source(ax_panel.session.data) == ux_hash)

	var sample: Dictionary = MapDocument.sample()
	var left_source: Dictionary = sample.pieces[0].source.duplicate(true)
	var right_source: Dictionary = sample.pieces[1].source.duplicate(true)
	var left_path: String = work_dir.path_join("room_left.source.json")
	var right_path: String = work_dir.path_join("room_right.source.json")
	var left_saved: Dictionary = PieceStore.save_source(left_path,left_source,"")
	var right_saved: Dictionary = PieceStore.save_source(right_path,right_source,"")
	var left_read: Dictionary = PieceStore.load_source(left_path)
	var right_read: Dictionary = PieceStore.load_source(right_path)
	var gui_clean: Dictionary = gui_panel.session.replace(MapDocument.empty("composition_fixture"))
	var ax_clean: Dictionary = ax_panel.session.replace(MapDocument.empty("composition_fixture"))
	gui_panel.session.saved_hash = MapDocument.hash_source(gui_panel.session.data)
	ax_panel.session.saved_hash = MapDocument.hash_source(ax_panel.session.data)
	check("two_terminal_fixture_sources_are_canonical_disk_inputs_for_the_shared_map_consumers",left_saved.ok and right_saved.ok and left_read.ok and right_read.ok and left_read.output_hash == sample.pieces[0].piece_hash and right_read.output_hash == sample.pieces[1].piece_hash and gui_clean.ok and ax_clean.ok)
	var gui_left: Dictionary = gui_panel.add_piece(left_path,"left",[0.0,0.0],0)
	var ax_left: Dictionary = ax_presentation.ax_invoke("map/piece/add",{"path":left_path,"instance_id":"left","position_xz":[0.0,0.0],"rotation_quarters":0})
	var gui_right: Dictionary = gui_panel.add_piece(right_path,"right",[100.0,0.0],0)
	var ax_right: Dictionary = ax_presentation.ax_invoke("map/piece/add",{"path":right_path,"instance_id":"right","position_xz":[100.0,0.0],"rotation_quarters":0})
	var gui_hash_after_add: String = MapDocument.hash_source(gui_panel.session.data)
	var ax_hash_after_add: String = MapDocument.hash_source(ax_panel.session.data)
	check("gui_and_ax_add_use_same_loaded_snapshots_explicit_ids_and_semantic_hash",gui_left.ok and ax_left.ok and gui_right.ok and ax_right.ok and gui_left.entity_id == "left" and ax_left.added_ids == ["left"] and gui_right.entity_id == "right" and ax_right.added_ids == ["right"] and gui_hash_after_add == ax_hash_after_add and gui_hash_after_add == ax_right.output_hash and gui_panel.session.data.pieces.size() == 2 and ax_panel.session.data.instances.size() == 2)
	var duplicate_source: Dictionary = ax_presentation.ax_invoke("map/piece/add",{"path":left_path,"instance_id":"left_copy","position_xz":[-100.0,0.0],"rotation_quarters":0})
	check("same_piece_hash_is_deduplicated_while_each_added_instance_keeps_its_identity",duplicate_source.ok and ax_panel.session.data.pieces.size() == 2 and ax_panel.session.data.instances.size() == 3 and duplicate_source.added_ids == ["left_copy"])
	var copy_remove: Dictionary = ax_presentation.ax_invoke("map/instance/remove",{"instance_id":"left_copy","confirm_remove":true})
	var copy_undo: Dictionary = ax_presentation.ax_invoke("map/history/undo",{})
	var count_after_undo: int = ax_panel.session.data.instances.size()
	var copy_redo: Dictionary = ax_presentation.ax_invoke("map/history/redo",{})
	check("remove_returns_identity_and_undo_redo_restores_instance_without_duplicate_snapshot",copy_remove.ok and copy_remove.removed_ids == ["left_copy"] and copy_undo.ok and count_after_undo == 3 and copy_redo.ok and ax_panel.session.data.instances.size() == 2 and ax_panel.session.data.pieces.size() == 2)

	var source_hash_before_selection: String = MapDocument.hash_source(ax_panel.session.data)
	var selection_revision: int = int(ax_panel.session.data.revision)
	var select_result: Dictionary = ax_presentation.ax_invoke("map/instance/select",{"instance_id":"left"})
	var missing_selection: Dictionary = ax_presentation.ax_invoke("map/instance/select",{"instance_id":"missing"})
	check("instance_selection_is_editor_state_and_missing_identity_is_rejected",select_result.ok and not missing_selection.ok and ax_panel.canvas.selected_instance == "left" and MapDocument.hash_source(ax_panel.session.data) == source_hash_before_selection and int(ax_panel.session.data.revision) == selection_revision)
	var transform_params: Dictionary = {"instance_id":"right","position_xz":[100.25,0.5],"rotation_quarters":1}
	gui_panel.select_id("right"); gui_panel.x.value = 100.25; gui_panel.z.value = 0.5; gui_panel.rotation_choice.select(1)
	gui_panel.apply_placement()
	var gui_transform: Dictionary = {"ok":gui_panel.session.data.instances[1].position_xyz == [100.25,0,0.5],"output_hash":MapDocument.hash_source(gui_panel.session.data)}
	var ax_transform: Dictionary = ax_presentation.ax_invoke("map/instance/transform",transform_params)
	check("instance_transform_uses_same_gui_and_ax_proposal_and_preserves_fractional_coordinates",gui_transform.ok and ax_transform.ok and gui_transform.output_hash == ax_transform.output_hash and MapDocument.hash_source(gui_panel.session.data) == MapDocument.hash_source(ax_panel.session.data))
	var pure_before: String = MapDocument.hash_source(ax_panel.session.data)
	var pure_proposal: Dictionary = Operations.propose(ax_panel.session.data,"instance/transform",{"instance_id":"right","position_xz":[100,0],"rotation_quarters":0})
	check("pure_proposal_does_not_mutate_its_input",pure_proposal.ok and pure_proposal.output_hash != pure_before and MapDocument.hash_source(ax_panel.session.data) == pure_before)
	gui_panel.apply_operation("instance/transform",{"instance_id":"right","position_xz":[100,0],"rotation_quarters":0})
	ax_presentation.ax_invoke("map/instance/transform",{"instance_id":"right","position_xz":[100,0],"rotation_quarters":0})
	var invalid_transform_base: String = MapDocument.hash_source(ax_panel.session.data)
	var invalid_transform_depth: int = ax_panel.session._undo.size()
	var bad_rotation: Dictionary = ax_presentation.ax_invoke("map/instance/transform",{"instance_id":"right","position_xz":[0.0,0.0],"rotation_quarters":4})
	var fractional_rotation: Dictionary = ax_presentation.ax_invoke("map/instance/transform",{"instance_id":"right","position_xz":[0.0,0.0],"rotation_quarters":0.5})
	var out_of_range: Dictionary = ax_presentation.ax_invoke("map/instance/transform",{"instance_id":"right","position_xz":[16001.0,0.0],"rotation_quarters":0})
	var nan_position: Dictionary = ax_presentation.ax_invoke("map/instance/transform",{"instance_id":"right","position_xz":[NAN,0.0],"rotation_quarters":0})
	var unknown_key: Dictionary = ax_presentation.ax_invoke("map/instance/transform",{"instance_id":"right","position_xz":[100.0,0.0],"rotation_quarters":0,"unexpected":true})
	check("nonintegral_rotation_nonfinite_range_and_unknown_fields_fail_atomically",not bad_rotation.ok and not fractional_rotation.ok and not out_of_range.ok and not nan_position.ok and not unknown_key.ok and MapDocument.hash_source(ax_panel.session.data) == invalid_transform_base and ax_panel.session._undo.size() == invalid_transform_depth)
	var missing_piece: Dictionary = ax_presentation.ax_invoke("map/piece/add",{"path":work_dir.path_join("missing.json"),"instance_id":"bad","position_xz":[0.0,0.0],"rotation_quarters":0})
	var duplicate_instance: Dictionary = ax_presentation.ax_invoke("map/piece/add",{"path":left_path,"instance_id":"left","position_xz":[0.0,0.0],"rotation_quarters":0})
	check("missing_piece_file_and_duplicate_instance_id_do_not_mutate_composition",not missing_piece.ok and not duplicate_instance.ok and MapDocument.hash_source(ax_panel.session.data) == invalid_transform_base and ax_panel.session._undo.size() == invalid_transform_depth)

	var link: Dictionary = {"link_id":"door_link","a_instance":"left","a_connector":"east","b_instance":"right","b_connector":"west"}
	var gui_link: Dictionary = gui_panel.apply_operation("link/upsert",link)
	var ax_link: Dictionary = ax_presentation.ax_invoke("map/link/upsert",link)
	check("gui_and_ax_link_upsert_share_closed_fields_and_hash",gui_link.ok and ax_link.ok and gui_link.output_hash == ax_link.output_hash and ax_panel.session.data.links == [link])
	var invalid_link_hash: String = MapDocument.hash_source(ax_panel.session.data)
	var missing_endpoint: Dictionary = ax_presentation.ax_invoke("map/link/upsert",{"link_id":"missing","a_instance":"left","a_connector":"absent","b_instance":"right","b_connector":"west"})
	var reuse_endpoint: Dictionary = ax_presentation.ax_invoke("map/link/upsert",{"link_id":"reuse","a_instance":"left","a_connector":"east","b_instance":"right","b_connector":"west"})
	var reuse_compile_request: Dictionary = ax_presentation.ax_invoke("map/compile_map",{})
	var reuse_wait: int = 0
	while ax_panel.job != null and reuse_wait < 3000:
		await process_frame
		reuse_wait += 1
	var reuse_compile: Dictionary = ax_panel.result.duplicate(true)
	var remove_reuse: Dictionary = ax_presentation.ax_invoke("map/link/remove",{"link_id":"reuse"})
	check("missing_link_references_fail_and_connector_reuse_is_rejected_by_the_compiler",not missing_endpoint.ok and reuse_endpoint.ok and reuse_compile_request.ok and reuse_wait < 3000 and not reuse_compile.get("ok",false) and reuse_compile.get("code","") == "connector_reused" and remove_reuse.ok and MapDocument.hash_source(ax_panel.session.data) == invalid_link_hash)
	var remove_link: Dictionary = ax_presentation.ax_invoke("map/link/remove",{"link_id":"door_link"})
	var restore_link: Dictionary = ax_presentation.ax_invoke("map/link/upsert",link)
	check("link_remove_and_restore_keep_canonical_endpoints",remove_link.ok and remove_link.removed_ids == ["door_link"] and restore_link.ok and ax_panel.session.data.links.size() == 1 and ax_panel.session.data.links[0] == link)

	var set_mode: Dictionary = ax_presentation.ax_invoke("map/mode/set",{"mode":"manual"})
	var context_params: Dictionary = {"biome_id":"forest","instance_id":"","rules":[],"reason":""}
	var gui_context: Dictionary = gui_panel.apply_operation("context/set",context_params)
	var set_context: Dictionary = ax_presentation.ax_invoke("map/context/set",context_params)
	var exception_params: Dictionary = {"biome_id":"forest","instance_id":"left","rules":["biome"],"reason":"Peça de entrada preparada para uma floresta."}
	var gui_exception: Dictionary = gui_panel.apply_operation("context/set",exception_params)
	var set_exception: Dictionary = ax_presentation.ax_invoke("map/context/set",exception_params)
	var context_warnings: Array = MapContext.warnings(ax_panel.session.data)
	var invalid_override: Dictionary = ax_presentation.ax_invoke("map/context/set",{"biome_id":"forest","instance_id":"missing","rules":["biome"],"reason":"Motivo"})
	check("manual_context_exception_is_explicit_warned_and_rejects_missing_instance",set_mode.ok and set_context.ok and set_exception.ok and context_warnings.size() == 1 and context_warnings[0].code == "context_manual_override" and not invalid_override.ok)
	check("gui_and_ax_map_context_proposals_produce_equal_sources_and_hashes",gui_context.ok and gui_exception.ok and gui_panel.session.data == ax_panel.session.data and MapDocument.hash_source(gui_panel.session.data) == MapDocument.hash_source(ax_panel.session.data))
	var recipe_mode: Dictionary = ax_presentation.ax_invoke("map/mode/set",{"mode":"recipe"})
	var recipe_context: Dictionary = ax_panel.session.data.get("context",Context.empty_map())
	check("recipe_mode_rejects_manual_exceptions_without_changing_mode",not recipe_mode.ok and ax_panel.session.data.mode == "manual" and not recipe_context.overrides.is_empty())
	var manual_again: Dictionary = ax_presentation.ax_invoke("map/mode/set",{"mode":"manual"})
	var clear_exception: Dictionary = ax_presentation.ax_invoke("map/context/set",{"biome_id":"forest","instance_id":"left","rules":[],"reason":""})
	var context_valid: bool = ax_panel.session.data.context.overrides.is_empty() and ax_panel.session.data.context.biome_id == "forest"
	check("manual_context_can_clear_instance_exception_without_losing_map_biome",manual_again.ok and clear_exception.ok and context_valid)
	var reference_fixture: Dictionary = ax_panel.session.data.duplicate(true)
	reference_fixture.borders = {"version":1,"instances":[{"instance_id":"right","profile_id":"ruin_envelope_v1"}],"transitions":[{"a_instance":"left","b_instance":"right","profile_id":"transition_terrace_v1"}],"decorations":true}
	reference_fixture.context.overrides = [{"instance_id":"right","rules":["biome"],"reason":"Fixture de remoção explícita"}]
	ax_panel.session.replace(reference_fixture)
	var referenced_hash: String = MapDocument.hash_source(ax_panel.session.data)
	var declined_remove: Dictionary = ax_presentation.ax_invoke("map/instance/remove",{"instance_id":"right","confirm_remove":false})
	check("instance_removal_requires_explicit_confirmation",not declined_remove.ok and declined_remove.code == "confirmation_required" and MapDocument.hash_source(ax_panel.session.data) == referenced_hash and ax_panel.session._undo.is_empty())
	var removed_referenced: Dictionary = ax_presentation.ax_invoke("map/instance/remove",{"instance_id":"right","confirm_remove":true})
	var cleaned: Dictionary = ax_panel.session.data.duplicate(true)
	var undone_referenced: Dictionary = ax_presentation.ax_invoke("map/history/undo",{})
	check("remove_cleans_links_borders_transitions_and_override_and_undo_restores_all",removed_referenced.ok and cleaned.instances.size() == 1 and cleaned.links.is_empty() and cleaned.borders.instances.is_empty() and cleaned.borders.transitions.is_empty() and cleaned.context.overrides.is_empty() and cleaned.pieces.size() == 2 and undone_referenced.ok and MapDocument.hash_source(ax_panel.session.data) == referenced_hash)
	reference_fixture.erase("borders"); reference_fixture.context.overrides = []
	ax_panel.session.replace(reference_fixture)
	var valid_recipe: Dictionary = ax_presentation.ax_invoke("map/mode/set",{"mode":"recipe"})
	var valid_recipe_mode: String = ax_panel.session.data.mode
	var valid_manual: Dictionary = ax_presentation.ax_invoke("map/mode/set",{"mode":"manual"})
	check("mode_switch_without_manual_exceptions_preserves_the_map",valid_recipe.ok and valid_recipe_mode == "recipe" and valid_manual.ok and ax_panel.session.data.mode == "manual" and ax_panel.session.data.links == [link])

	var precompile_hash: String = MapDocument.hash_source(ax_panel.session.data)
	var compile_request: Dictionary = ax_presentation.ax_invoke("map/compile_map",{})
	var compile_frames: int = 0
	while ax_panel.job != null and compile_frames < 3000:
		await process_frame
		compile_frames += 1
	var compile_result: Dictionary = ax_panel.result.duplicate(true)
	check("map_compile_waits_for_the_real_worker_and_returns_current_hash_package",compile_request.ok and ax_panel.job == null and compile_result.get("ok",false) and compile_result.get("input_hash","") == precompile_hash and compile_result.package.source_hash == precompile_hash and compile_frames < 3000)
	var stale_border: Dictionary = ax_presentation.ax_invoke("map/borders/apply",{"expected_source_hash":"deliberately-stale".sha256_text(),"command":{"operation":"set_decorations","enabled":false}})
	check("border_command_keeps_its_stale_hash_guard",not stale_border.ok and stale_border.code == "stale_source")

	var map_path: String = work_dir.path_join("composition.json")
	var saved: Dictionary = ax_presentation.ax_invoke("map/document/save",{"path":map_path})
	var loaded: Dictionary = MapStore.load_source(map_path)
	var saved_hash: String = MapDocument.hash_source(ax_panel.session.data)
	var renamed: Dictionary = ax_presentation.ax_invoke("map/document/name",{"name":"Changed after saved snapshot"})
	var reopened: Dictionary = ax_presentation.ax_invoke("map/document/open",{"path":map_path,"confirm_discard":true})
	check("map_file_roundtrip_reopens_saved_hash_after_validated_name_edit",saved.ok and loaded.ok and renamed.ok and reopened.ok and reopened.output_hash == saved_hash and MapDocument.hash_source(ax_panel.session.data) == saved_hash and MapStore.load_source(map_path).output_hash == saved_hash)
	var dirty_hash: String = MapDocument.hash_source(ax_panel.session.data)
	var dirty_depth: int = ax_panel.session._undo.size()
	ax_panel.name_edit.text = "Nome ainda em edição"
	var expected_pending: Dictionary = ax_panel.session.data.duplicate(true); expected_pending.name = ax_panel.name_edit.text
	var pending_hash: String = MapDocument.hash_source(expected_pending)
	var declined_new: Dictionary = ax_presentation.ax_invoke("map/document/new",{"document_id":"declined","name":"Declined","confirm_discard":false})
	var declined_open: Dictionary = ax_presentation.ax_invoke("map/document/open",{"path":map_path,"confirm_discard":false})
	check("dirty_new_and_open_require_confirmation_without_partial_mutation",not declined_new.ok and not declined_open.ok and MapDocument.hash_source(ax_panel.session.data) == dirty_hash and ax_panel.session._undo.size() == dirty_depth)
	var failed_save: Dictionary = ax_presentation.ax_invoke("map/document/save",{"path":work_dir.path_join("absent" ).path_join("failed.json")})
	check("failed_save_path_preserves_session_source_and_undo_stack",not failed_save.ok and MapDocument.hash_source(ax_panel.session.data) == dirty_hash and ax_panel.session._undo.size() == dirty_depth and ax_panel.name_edit.text == "Nome ainda em edição")
	var old_draft_path: String = ax_panel._autosave
	var new_confirmed: Dictionary = ax_presentation.ax_invoke("map/document/new",{"document_id":"new_map_id","name":"Novo mapa de teste","confirm_discard":true})
	var old_recovered: Dictionary = MapStore.load_source(old_draft_path)
	check("confirmed_dirty_new_preserves_prior_composition_in_canonical_autosave",new_confirmed.ok and ax_panel.session.data.document_id == "new_map_id" and old_recovered.ok and old_recovered.output_hash == pending_hash and ax_panel._autosave != old_draft_path)
	var prior_file_hash: String = PieceStore.disk_hash(map_path)
	var foreign_target: Dictionary = ax_presentation.ax_invoke("map/document/save",{"path":map_path})
	check("ax_save_as_never_overwrites_an_existing_foreign_destination",not foreign_target.ok and foreign_target.code == "io_conflict" and PieceStore.disk_hash(map_path) == prior_file_hash)
	var source_hash_after_new: String = MapDocument.hash_source(ax_panel.session.data)
	var save_empty: Dictionary = ax_presentation.ax_invoke("map/document/save",{"path":work_dir.path_join("new_map.json")})
	var conflict_before: String = MapDocument.hash_source(ax_panel.session.data)
	var conflict_path: String = work_dir.path_join("external_conflict.json")
	var initial_conflict_save: Dictionary = ax_presentation.ax_invoke("map/document/save",{"path":conflict_path})
	var file: FileAccess = FileAccess.open(conflict_path,FileAccess.WRITE)
	if file != null: file.store_string("external edit"); file.close()
	var conflict_save: Dictionary = ax_presentation.ax_invoke("map/document/save",{"path":conflict_path})
	check("new_document_saves_but_external_disk_change_is_a_conflict_without_source_mutation",source_hash_after_new == conflict_before and save_empty.ok and initial_conflict_save.ok and not conflict_save.ok and conflict_save.code == "io_conflict" and MapDocument.hash_source(ax_panel.session.data) == conflict_before)
	finish()

func finish() -> void:
	Presentation.active_mode = "ux"
	var all_ok: bool = checks.size() == EXPECTED_COUNT and checks.all(func(item: Dictionary) -> bool: return item.ok)
	var hashes: Dictionary = {"gui":MapDocument.hash_source(gui_panel.session.data) if is_instance_valid(gui_panel) else "","ax":MapDocument.hash_source(ax_panel.session.data) if is_instance_valid(ax_panel) else ""}
	print("F9_AX_COMPOSITION_RESULT "+JSON.stringify({"ok":all_ok,"count":checks.size(),"expected_count":EXPECTED_COUNT,"checks":checks,"final_hashes":hashes,"work_dir":work_dir}))
	for shell: Variant in [gui_shell,ax_shell]:
		if is_instance_valid(shell): shell.free()
	quit(0 if all_ok else 1)
