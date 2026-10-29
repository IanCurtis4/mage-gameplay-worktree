extends SceneTree
## Headless proof for runtime biome metadata and atomic map border batches.
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapSession = preload("res://scripts/map_authoring/composition/map_session.gd")
const MapStore = preload("res://scripts/map_authoring/composition/map_store.gd")
const BorderOperations = preload("res://scripts/map_authoring/composition/border_operations.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapContext = preload("res://scripts/map_authoring/context/piece_context.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PopulationCompiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const SourceSchema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Presentation = preload("res://addons/ragrpg_map_editor/presentation.gd")

const EXPECTED_COUNT := 15
var checks: Array[Dictionary] = []
var gui_shell: Variant
var ax_shell: Variant

func _initialize() -> void:
	run.call_deferred()

func check(id: String, ok: bool, detail: Dictionary = {}) -> void:
	checks.append({"id":id,"ok":ok,"detail":detail})
	print("F9_MAP_BIOME_CHECK "+id+" "+str(ok))
	if not ok and not detail.is_empty(): print("F9_MAP_BIOME_DIAGNOSTIC "+id+" "+JSON.stringify(detail))

func run() -> void:
	var legacy_map: Dictionary = MapDocument.sample()
	var legacy_hash: String = MapDocument.hash_source(legacy_map)
	var legacy_compile: Dictionary = MapCompiler.compile(legacy_map)
	var legacy_stage: Dictionary = legacy_compile.package.manifest.stages[0] if legacy_compile.ok else {}
	var empty_context_map: Dictionary = legacy_map.duplicate(true)
	empty_context_map.context = MapContext.empty_map()
	var empty_context_compile: Dictionary = MapCompiler.compile(empty_context_map)
	check("legacy_missing_and_empty_context_use_ruin_without_mutating_source",legacy_compile.ok and empty_context_compile.ok and legacy_stage.get("biome","") == "ruin" and empty_context_compile.package.manifest.stages[0].biome == "ruin" and not legacy_compile.package.has("authoring_context") and empty_context_compile.package.authoring_context == MapContext.empty_map() and MapDocument.hash_source(legacy_map) == legacy_hash)
	var forest_map: Dictionary = legacy_map.duplicate(true)
	forest_map.context = MapContext.empty_map(); forest_map.context.biome_id = "forest"
	var forest_hash: String = MapDocument.hash_source(forest_map)
	var forest_compile: Dictionary = MapCompiler.compile(forest_map)
	check("explicit_authoring_biome_reaches_manifest_and_changes_only_compiled_metadata",forest_compile.ok and forest_compile.package.manifest.stages[0].biome == "forest" and forest_compile.package.authoring_context.biome_id == "forest" and forest_compile.package.source_hash == forest_hash and MapDocument.hash_source(forest_map) == forest_hash and forest_compile.package.package_hash != legacy_compile.package.package_hash)
	var tampered: Dictionary = forest_compile.package.duplicate(true) if forest_compile.ok else {}
	var tampered_content: Dictionary = tampered.duplicate(true); tampered_content.erase("package_hash")
	if tampered.has("manifest") and not tampered.manifest.stages.is_empty(): tampered.manifest.stages[0].biome = "ruin"
	tampered_content = tampered.duplicate(true); tampered_content.erase("package_hash")
	tampered.package_hash = Canonical.digest(tampered_content)
	var valid_rehash: bool = Canonical.valid(tampered)
	var package_probe_path: String = ProjectSettings.globalize_path("res://.godot/f9_map_biome/incoherent_rehashed.rmp")
	DirAccess.make_dir_recursive_absolute(package_probe_path.get_base_dir())
	var tampered_payload: PackedByteArray = var_to_bytes(tampered)
	var tampered_bytes: PackedByteArray = ("RMP1"+SourceSchema.bytes_hash(tampered_payload)).to_utf8_buffer(); tampered_bytes.append_array(tampered_payload)
	var package_probe_file: FileAccess = FileAccess.open(package_probe_path,FileAccess.WRITE)
	if package_probe_file != null: package_probe_file.store_buffer(tampered_bytes); package_probe_file.close()
	var package_probe_before: PackedByteArray = FileAccess.get_file_as_bytes(package_probe_path) if FileAccess.file_exists(package_probe_path) else PackedByteArray()
	var package_probe_result: Dictionary = MapStore.load_package(package_probe_path)
	var package_probe_after: PackedByteArray = FileAccess.get_file_as_bytes(package_probe_path) if FileAccess.file_exists(package_probe_path) else PackedByteArray()
	check("rehashing_cannot_make_context_and_runtime_biome_disagreement_valid",forest_compile.ok and valid_rehash and not MapCompiler.validate_package(tampered) and package_probe_file != null and not package_probe_result.ok and package_probe_before == package_probe_after)
	var legacy_rehashed: Dictionary = forest_compile.package.duplicate(true) if forest_compile.ok else {}
	legacy_rehashed.erase("authoring_context")
	if legacy_rehashed.has("manifest") and not legacy_rehashed.manifest.stages.is_empty(): legacy_rehashed.manifest.stages[0].biome = "ruin"
	var legacy_rehashed_content: Dictionary = legacy_rehashed.duplicate(true); legacy_rehashed_content.erase("package_hash")
	legacy_rehashed.package_hash = Canonical.digest(legacy_rehashed_content)
	check("legacy_package_without_authoring_context_remains_valid_with_legacy_ruin_stage",legacy_compile.ok and MapCompiler.validate_package(legacy_compile.package) and Canonical.valid(legacy_rehashed) and MapCompiler.validate_package(legacy_rehashed))
	var population: Dictionary = PopulationDocument.empty("forest_population")
	population.map = [forest_map.duplicate(true)]
	var compiled_surfaces: Array = forest_compile.package.manifest.stages[0].surfaces if forest_compile.ok else []
	var entry_surface: Dictionary = compiled_surfaces[0] if not compiled_surfaces.is_empty() else {}
	population.entrance = [{"surface_id":entry_surface.get("surface_id",""),"position_xyz":[50.0,0.0,50.0]}]
	var population_prepared: Dictionary = PopulationCompiler.prepare(population)
	check("population_preparation_consumes_the_forest_map_package_and_manifest_biome",population_prepared.ok and population_prepared.map_package.authoring_context.biome_id == "forest" and population_prepared.map_package.manifest.stages[0].biome == "forest" and population_prepared.map_package.source_hash == forest_hash)

	var cap_source: Dictionary = MapDocument.sample()
	var original_instances: Array = cap_source.instances.duplicate(true)
	for index: int in range(2,32):
		var entry: Dictionary = original_instances[0].duplicate(true)
		entry.instance_id = "cap_%02d"%index
		entry.position_xyz = [float(index*160),0.0,0.0]
		cap_source.instances.append(entry)
	var cap_valid: Dictionary = MapDocument.validate(cap_source)
	var cap_commands: Array[Dictionary] = []
	for instance: Dictionary in cap_source.instances:
		cap_commands.append({"operation":"set_instance_profile","instance_id":instance.instance_id,"profile_id":"forest_rootbank_v1"})
	for left_index: int in cap_source.instances.size():
		for right_index: int in range(left_index+1,cap_source.instances.size()):
			cap_commands.append({"operation":"set_transition","a_instance":cap_source.instances[left_index].instance_id,"b_instance":cap_source.instances[right_index].instance_id,"profile_id":"forest_rootbank_v1"})
	cap_commands.append({"operation":"set_decorations","enabled":false})
	var cap_hash: String = MapDocument.hash_source(cap_source)
	var max_batch: Dictionary = BorderOperations.apply_batch(cap_source,cap_commands)
	var diff_before_alias_safe: bool = max_batch.ok and max_batch.diff.before == null
	var diff_after_alias_safe: bool = max_batch.ok and max_batch.diff.after == max_batch.data.borders and not is_same(max_batch.diff.after,max_batch.data.borders)
	if max_batch.ok: max_batch.diff.after.decorations = true
	var bordered_cap_source: Dictionary = cap_source.duplicate(true); bordered_cap_source.borders = BorderOperations.empty()
	var bordered_source_copy: Dictionary = bordered_cap_source.borders.duplicate(true)
	var bordered_diff: Dictionary = BorderOperations.apply_batch(bordered_cap_source,[{"operation":"set_decorations","enabled":false}])
	var bordered_diff_isolated: bool = bordered_diff.ok and bordered_diff.diff.before == bordered_source_copy and not is_same(bordered_diff.diff.before,bordered_cap_source.borders) and not is_same(bordered_diff.diff.after,bordered_diff.data.borders)
	if bordered_diff.ok: bordered_diff.diff.after.decorations = true
	var empty_batch: Dictionary = BorderOperations.apply_batch(cap_source,[])
	check("529_command_batch_cap_accepts_every_instance_pair_and_is_pure",cap_valid.ok and cap_commands.size() == BorderOperations.MAX_COMMANDS and cap_commands.size() == 529 and max_batch.ok and max_batch.command_count == 529 and max_batch.data.borders.instances.size() == 32 and max_batch.data.borders.transitions.size() == 496 and max_batch.data.borders.decorations == false and diff_before_alias_safe and diff_after_alias_safe and max_batch.diff.after.decorations == true and bordered_diff_isolated and bordered_diff.diff.before == bordered_source_copy and bordered_diff.data.borders.decorations == false and not empty_batch.ok and MapDocument.hash_source(cap_source) == cap_hash and not cap_source.has("borders") and bordered_cap_source.borders == bordered_source_copy)
	var over_cap_commands: Array = cap_commands.duplicate(true); over_cap_commands.append({"operation":"set_decorations","enabled":true})
	var over_cap: Dictionary = BorderOperations.apply_batch(cap_source,over_cap_commands)
	check("batch_over_529_is_rejected_without_mutating_source",not over_cap.ok and MapDocument.hash_source(cap_source) == cap_hash and not cap_source.has("borders"))
	var malformed_commands: Array[Dictionary] = [{"operation":"set_decorations","enabled":false},{"operation":"unknown_operation"}]
	var bad_last: Dictionary = BorderOperations.apply_batch(legacy_map,malformed_commands)
	var unknown_field: Dictionary = BorderOperations.apply_batch(legacy_map,[{"operation":"set_decorations","enabled":false,"extra":true}])
	var non_dictionary: Dictionary = BorderOperations.apply_batch(legacy_map,[{"operation":"set_decorations","enabled":false},17])
	check("invalid_last_command_non_dictionary_and_unknown_fields_fail_batch_atomically",not bad_last.ok and not unknown_field.ok and not non_dictionary.ok and MapDocument.hash_source(legacy_map) == legacy_hash and not legacy_map.has("borders"))
	var transition_source: Dictionary = MapDocument.sample()
	var expected_hash: String = MapDocument.hash_source(transition_source)
	var transactional_session: Variant = MapSession.new()
	transactional_session.replace(transition_source)
	var batch_commands: Array[Dictionary] = [{"operation":"set_instance_profile","instance_id":"left","profile_id":"forest_rootbank_v1"},{"operation":"set_instance_profile","instance_id":"right","profile_id":"forest_rootbank_v1"}]
	var applied_batch: Dictionary = transactional_session.apply_borders(batch_commands,expected_hash,"Nome de rascunho")
	var after_batch_hash: String = MapDocument.hash_source(transactional_session.data)
	check("session_batch_applies_pending_name_and_all_commands_as_one_history_entry",applied_batch.ok and applied_batch.command_count == 2 and applied_batch.diff.before == null and applied_batch.diff.after.instances.size() == 2 and transactional_session.data.name == "Nome de rascunho" and transactional_session._undo.size() == 1 and after_batch_hash == applied_batch.source_hash)
	var undo_ok: bool = transactional_session.undo()
	var undo_hash: String = MapDocument.hash_source(transactional_session.data)
	var undo_name: String = transactional_session.data.name
	var redo_ok: bool = transactional_session.redo()
	var redo_hash: String = MapDocument.hash_source(transactional_session.data)
	check("one_undo_and_redo_restore_entire_atomic_batch_and_pending_name",undo_ok and undo_hash == expected_hash and undo_name == transition_source.name and redo_ok and redo_hash == after_batch_hash and transactional_session.data.name == "Nome de rascunho")
	var no_op_session: Variant = MapSession.new()
	var bordered: Dictionary = transition_source.duplicate(true); bordered.borders = BorderOperations.empty()
	no_op_session.replace(bordered)
	var no_op_hash: String = MapDocument.hash_source(bordered)
	var no_op: Dictionary = no_op_session.apply_borders([{"operation":"set_decorations","enabled":true}],no_op_hash)
	var stale: Dictionary = no_op_session.apply_borders([{"operation":"set_decorations","enabled":false}],"stale".sha256_text())
	var invalid_base: String = MapDocument.hash_source(no_op_session.data)
	var invalid_depth: int = no_op_session._undo.size()
	var rollback: Dictionary = no_op_session.apply_borders(malformed_commands,no_op_hash)
	check("batch_no_op_and_stale_or_invalid_batches_do_not_add_history_or_change_source",no_op.ok and no_op_hash == MapDocument.hash_source(no_op_session.data) and no_op_session._undo.is_empty() and not stale.ok and stale.code == "stale_source" and not rollback.ok and MapDocument.hash_source(no_op_session.data) == invalid_base and no_op_session._undo.size() == invalid_depth)
	var pending_name_hash: String = MapDocument.hash_source(no_op_session.data)
	var pending_name: Dictionary = no_op_session.apply_borders([{"operation":"set_decorations","enabled":false}],pending_name_hash,"Pending title")
	var pending_invalid: Dictionary = no_op_session.apply_borders([{"operation":"set_decorations","enabled":false}],MapDocument.hash_source(no_op_session.data),17)
	check("pending_name_is_validated_and_batch_rejects_invalid_name_without_second_history_entry",pending_name.ok and pending_name.data.name == "Pending title" and not pending_invalid.ok and no_op_session.data.name == "Pending title" and no_op_session._undo.size() == 1)
	var cli_dir: String = ProjectSettings.globalize_path("res://.godot/f9_map_biome/cli")
	DirAccess.make_dir_recursive_absolute(cli_dir)
	var cli_token: String = str(Time.get_ticks_usec())
	var cli_source_path: String = cli_dir.path_join("input_"+cli_token+".json")
	var cli_request_path: String = cli_dir.path_join("request_"+cli_token+".json")
	var cli_output_path: String = cli_dir.path_join("output_"+cli_token+".json")
	var cli_source_saved: Dictionary = MapStore.save_source(cli_source_path,legacy_map,"")
	var cli_commands: Array[Dictionary] = [{"operation":"set_decorations","enabled":false}]
	var cli_request: Dictionary = {"expected_source_hash":legacy_hash,"commands":cli_commands}
	var cli_request_file: FileAccess = FileAccess.open(cli_request_path,FileAccess.WRITE)
	if cli_request_file != null: cli_request_file.store_string(JSON.stringify(cli_request)); cli_request_file.close()
	var project_path: String = ProjectSettings.globalize_path("res://")
	var cli_args: PackedStringArray = ["--path",project_path,"--headless","--script","res://scripts/map_authoring/composition/headless.gd","--","--border-batch",cli_source_path,cli_request_path,cli_output_path,"-"]
	var cli_output: Array[String] = []
	var cli_exit: int = OS.execute(OS.get_executable_path(),cli_args,cli_output,true)
	var cli_loaded: Dictionary = MapStore.load_source(cli_output_path)
	var cli_input_read: Dictionary = MapStore.load_source(cli_source_path)
	var cli_log := ""
	for output_line: String in cli_output: cli_log += output_line+"\n"
	check("composition_cli_batch_reads_closed_request_and_saves_through_map_store",cli_source_saved.ok and cli_request_file != null and cli_exit == 0 and cli_log.contains("MAP_COMPOSITION_RESULT") and cli_loaded.ok and cli_loaded.data.borders.decorations == false and cli_input_read.output_hash == legacy_hash and cli_loaded.data.document_id == legacy_map.document_id)

	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.gui_embed_subwindows = true
	root.size = Vector2i(1440,1000)
	DisplayServer.window_set_size(Vector2i(1440,1000))
	Presentation.active_mode = "ux"
	gui_shell = Shell.new(); gui_shell.name = "GuiBorderBatchShell"; root.add_child(gui_shell)
	ax_shell = Shell.new(); ax_shell.name = "AxBorderBatchShell"; root.add_child(ax_shell)
	for _frame: int in 3: await process_frame
	var gui_piece_presentation: Variant = gui_shell.get_node_or_null("AuthoringPresentation")
	var ax_piece_presentation: Variant = ax_shell.get_node_or_null("AuthoringPresentation")
	var gui_open_mode: Dictionary = gui_piece_presentation.set_mode("ax") if gui_piece_presentation != null else {"ok":false}
	var gui_open: Dictionary = gui_piece_presentation.ax_invoke("piece/compose_map",{}) if gui_piece_presentation != null else {"ok":false}
	var ax_open_mode: Dictionary = ax_piece_presentation.set_mode("ax") if ax_piece_presentation != null else {"ok":false}
	var ax_open: Dictionary = ax_piece_presentation.ax_invoke("piece/compose_map",{}) if ax_piece_presentation != null else {"ok":false}
	for _frame: int in 4: await process_frame
	var gui_panel: Variant = gui_shell.composition_window.get_child(0) if gui_shell.composition_window != null else null
	var ax_panel: Variant = ax_shell.composition_window.get_child(0) if ax_shell.composition_window != null else null
	var gui_presentation: Variant = gui_panel.get_node_or_null("AuthoringPresentation") if gui_panel != null else null
	var ax_presentation: Variant = ax_panel.get_node_or_null("AuthoringPresentation") if ax_panel != null else null
	var ax_mode: Dictionary = ax_presentation.set_mode("ax") if ax_presentation != null else {"ok":false}
	var gui_loaded: Dictionary = gui_panel.session.replace(MapDocument.sample()) if gui_panel != null else {"ok":false}
	var ax_loaded: Dictionary = ax_panel.session.replace(MapDocument.sample()) if ax_panel != null else {"ok":false}
	var commands: Array[Dictionary] = [{"operation":"set_instance_profile","instance_id":"left","profile_id":"forest_rootbank_v1"},{"operation":"set_instance_profile","instance_id":"right","profile_id":"forest_rootbank_v1"}]
	var gui_batch_base: String = MapDocument.hash_source(gui_panel.session.data) if gui_panel != null else ""
	var gui_batch: Dictionary = gui_panel.apply_borders(commands,gui_batch_base) if gui_panel != null else {"ok":false}
	var ax_batch_base: String = MapDocument.hash_source(ax_panel.session.data) if ax_panel != null else ""
	var ax_batch: Dictionary = ax_presentation.ax_invoke("map/borders/apply_batch",{"expected_source_hash":ax_batch_base,"commands":commands}) if ax_presentation != null else {"ok":false}
	check("real_gui_and_ax_panels_apply_the_same_closed_border_batch_and_semantic_hash",gui_open_mode.ok and gui_open.ok and ax_open_mode.ok and ax_open.ok and ax_mode.ok and gui_loaded.ok and ax_loaded.ok and gui_batch.ok and ax_batch.ok and gui_batch.command_count == 2 and ax_batch.command_count == 2 and gui_batch.source_hash == ax_batch.output_hash and MapDocument.hash_source(gui_panel.session.data) == MapDocument.hash_source(ax_panel.session.data) and gui_panel.session._undo.size() == 1 and ax_panel.session._undo.size() == 1)
	var ax_bad_base: String = MapDocument.hash_source(ax_panel.session.data)
	var ax_bad_depth: int = ax_panel.session._undo.size()
	var bad_shape: Dictionary = ax_presentation.ax_invoke("map/borders/apply_batch",{"expected_source_hash":ax_bad_base,"commands":commands,"extra":true})
	var stale_batch: Dictionary = ax_presentation.ax_invoke("map/borders/apply_batch",{"expected_source_hash":"stale".sha256_text(),"commands":[{"operation":"set_decorations","enabled":false}]})
	check("ax_batch_shape_and_stale_source_reject_before_session_mutation",not bad_shape.ok and not stale_batch.ok and stale_batch.code == "stale_source" and MapDocument.hash_source(ax_panel.session.data) == ax_bad_base and ax_panel.session._undo.size() == ax_bad_depth)
	finish()

func finish() -> void:
	var all_ok: bool = checks.size() == EXPECTED_COUNT and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_MAP_BIOME_RESULT "+JSON.stringify({"ok":all_ok,"count":checks.size(),"expected_count":EXPECTED_COUNT,"checks":checks}))
	Presentation.active_mode = "ux"
	for shell: Variant in [gui_shell,ax_shell]:
		if is_instance_valid(shell): shell.free()
	quit(0 if all_ok else 1)
