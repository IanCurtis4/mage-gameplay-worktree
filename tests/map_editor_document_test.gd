extends SceneTree
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
var checks: Array[Dictionary] = []
var failed := false

func check(id: String, ok: bool) -> void:
	checks.append({"id": id, "ok": ok})
	if not ok: failed = true

func read(data: Dictionary) -> Dictionary:
	return Schema.read(JSON.stringify(data, "", true, true).to_utf8_buffer())

func layer(id: String = "ground") -> Dictionary:
	return {"layer_id": id, "name": "Chão açucarado", "origin_xz": [0, 0], "sample_spacing": 1, "columns": 2, "rows": 2, "heights": [0, 1.25, -3.5, 0], "material_masks": {"sand": [1, 0.5, 0, 1]}, "locked": false, "protected_regions": []}

func _initialize() -> void:
	if "--interruption" in OS.get_cmdline_user_args():
		var path := ProjectSettings.globalize_path("res://.godot/interruption.json")
		var initial := Document.empty("restart_piece", "Versão íntegra")
		var saved := Store.save_source(path, initial, "")
		var draft := initial.duplicate(true)
		draft.name = "Trabalho antes da interrupção"
		draft.revision = 2
		var autosaved := Store.autosave(path, draft, saved.byte_hash)
		var staged := Store._write(path + ".pending", JSON.stringify(draft, "", true, true).to_utf8_buffer())
		print("M1_INTERRUPTION_READY " + JSON.stringify({"ok": saved.ok and autosaved.ok and staged, "output_hash": Schema.semantic_hash(draft)}))
		var ready := FileAccess.open("res://.godot/interruption.ready", FileAccess.WRITE)
		ready.store_string("ready")
		ready.close()
		# The supervising runner terminates this process before any cleanup.
		return
	var base := Document.empty("fixture", "Clareira de João")
	base.layers = [layer(), layer("upper")]
	base.special_surfaces = [{"surface_id": "bridge", "layer_id": "upper", "vertices_xyz": [[0, 4, 0], [1, 4, 0], [0, 4, 1]], "headroom": 3}]
	base.regions = [{"region_id": "protected", "layer_id": "ground", "polygon_xz": [[0, 0], [1, 0], [0, 1]], "purpose": "protected"}]
	base.layers[0].protected_regions = ["protected"]
	base.dependencies = [{"definition_id": "tree", "revision": 1, "sha256": "a".repeat(64), "kind": "prop"}]
	base.placements = [{"placement_id": "tree_1", "definition_id": "tree", "revision": 1, "position_xyz": [0, 0, 0], "rotation_y": 0, "surface_id": "ground"}]
	base.connectors = [{"connector_id": "exit", "surface_id": "ground", "position_xyz": [0, 0, 0], "normal_xyz": [1, 0, 0], "kind": "passage", "width": 2, "headroom": 3, "tags": ["forest"], "direction": "both"}]
	base.sockets = [{"socket_id": "entry", "surface_id": "bridge", "position_xyz": [0, 4, 0], "kind": "entry"}]
	base.composition = {"document_id": "map", "revision": 1, "sha256": "b".repeat(64)}
	var decoded := read(base)
	check("full_source_roundtrip", decoded.ok and decoded.diagnostics.is_empty() and decoded.data == base)
	var doc := Document.new(decoded.data)
	var copy: Dictionary = doc.to_data()
	copy.layers[0].heights[0] = 999
	check("copy_boundary", doc.to_data().layers[0].heights[0] == 0)
	var reordered := base.duplicate(true)
	reordered.layers.reverse()
	check("set_order_hash", Schema.semantic_hash(base) == Schema.semantic_hash(reordered))
	reordered.layers[0].heights.reverse()
	check("sequence_order_hash", Schema.semantic_hash(base) != Schema.semantic_hash(reordered))
	check("canonical_numeric_oracle", Schema._canonical([1, 1.0, -0.0, 0]) == "a4[d000000000000f03f,d000000000000f03f,d0000000000000000,d0000000000000000]")
	check("canonical_unicode_oracle", Schema._canonical({"z": "João", "a": true}) == 'o2{s"a":t,s"z":s"João"}')
	check("sha256_oracle", Schema.bytes_hash("abc".to_utf8_buffer()) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
	for case: String in ['{"a":1,"a":2}', '{"a":{"\\u0061":1,"a":2}}']:
		check("duplicate_key_" + str(checks.size()), Schema.read(case.to_utf8_buffer()).code == "source_duplicate_key")
	for case: String in ['{"a":1,}', '[1,]', '01', '1.', '+1', 'NaN', 'Infinity', '"a\nb"', '"\\x"', 'true false', '{', '{"a" 1}']:
		check("strict_grammar_" + str(checks.size()), not StrictJSON.new().decode(case.to_utf8_buffer()).ok)
	check("non_finite", StrictJSON.new().decode("1e999".to_utf8_buffer()).code == "source_non_finite")
	check("bounded_depth", StrictJSON.new().decode(("[".repeat(34) + "0" + "]".repeat(34)).to_utf8_buffer()).code == "source_limit_exceeded")
	check("bounded_string", StrictJSON.new().decode(JSON.stringify("a".repeat(65537)).to_utf8_buffer()).code == "source_limit_exceeded")
	var huge := PackedByteArray()
	huge.resize(StrictJSON.MAX_BYTES + 1)
	check("bounded_bytes", StrictJSON.new().decode(huge).code == "source_limit_exceeded")
	for invalid_utf8: PackedByteArray in [PackedByteArray([0xff]), PackedByteArray([0xc0, 0xaf]), PackedByteArray([0xed, 0xa0, 0x80]), PackedByteArray([0xf4, 0x90, 0x80, 0x80])]:
		check("utf8_strict_" + str(checks.size()), not StrictJSON.new().decode(invalid_utf8).ok)
	for invalid_escape: String in ['"\\ud800"', '"\\udc00"', '"\\ud800\\u0041"']:
		check("surrogate_strict_" + str(checks.size()), not StrictJSON.new().decode(invalid_escape.to_utf8_buffer()).ok)
	check("surrogate_pair", StrictJSON.new().decode('"\\ud83c\\udf33"'.to_utf8_buffer()).value == "🌳")
	var token_limit := StrictJSON.new()
	token_limit._text = "0"
	token_limit._tokens = StrictJSON.MAX_TOKENS
	token_limit._value(0)
	check("token_budget", token_limit._error == "source_limit_exceeded")
	var wrong := base.duplicate(true)
	wrong.schema_version = 2
	check("unknown_version", read(wrong).code == "source_version_unsupported")
	wrong = base.duplicate(true)
	wrong.future = 1
	check("unknown_field", read(wrong).code == "source_unknown_field")
	wrong = base.duplicate(true)
	wrong.layers[0].locked = 1
	check("typed_bool", read(wrong).code == "source_invalid_type")
	wrong = base.duplicate(true)
	wrong.layers[0].columns = true
	check("typed_integer", read(wrong).code == "source_invalid_type")
	wrong = base.duplicate(true)
	wrong.layers[0].heights.pop_back()
	check("invalid_draft_readable", read(wrong).ok and read(wrong).diagnostics[0].code == "source_sample_count")
	wrong = base.duplicate(true)
	wrong.layers.append(layer())
	check("duplicate_ids", read(wrong).diagnostics[0].code == "source_duplicate_id")
	wrong = base.duplicate(true)
	wrong.sockets[0].surface_id = "absent"
	check("broken_reference", read(wrong).diagnostics[0].code == "source_reference_missing")
	wrong = base.duplicate(true)
	wrong.dependencies.clear()
	check("dependency_reference", read(wrong).diagnostics[0].code == "dependency_missing")
	var many := Document.empty("many")
	for i: int in 4097: many.layers.append(layer("layer_" + str(i)))
	check("entity_limit", read(many).code == "source_limit_exceeded")
	var session := Session.new()
	session.replace(base)
	session.saved_hash = session.document().semantic_hash()
	check("clean_baseline", not session.dirty())
	var edit: Dictionary = session.document().to_data()
	edit.name = "Platô"
	check("edit_atomic", session.apply(edit).ok and session.document().to_data().revision == 2 and session.dirty())
	var generation: int = session.generation
	check("undo", session.undo() and session.document().to_data() == base and not session.dirty() and session.generation > generation)
	check("redo", session.redo() and session.document().to_data().name == "Platô")
	var hash_before: String = session.document().semantic_hash()
	var gen_before: int = session.generation
	check("reject_without_mutation", not session.apply(wrong).ok and hash_before == session.document().semantic_hash() and gen_before == session.generation and session.can_undo())
	session.undo()
	edit.name = "Nova direção"
	session.apply(edit)
	check("redo_branch_cleared", not session.can_redo())
	var old: Dictionary = session.document().to_data()
	check("replace_rejection", not session.replace({}).ok and old == session.document().to_data() and session.can_undo())
	var renamed_identity := session.document().to_data()
	renamed_identity.document_id = "other"
	check("identity_stable", session.apply(renamed_identity).code == "base_diverged" and session.document().to_data() == old)
	session.replace(base)
	check("duplicate_layer_graph", session.duplicate_layer("ground").ok)
	var duplicated := session.document().to_data()
	check("duplicate_internal_references", duplicated.layers.size() == 3 and duplicated.regions.size() == 2 and duplicated.placements.size() == 2 and duplicated.connectors.size() == 2 and duplicated.layers[2].protected_regions[0] == duplicated.regions[1].region_id and duplicated.regions[1].layer_id == duplicated.layers[2].layer_id and duplicated.placements[1].surface_id == duplicated.layers[2].layer_id and duplicated.dependencies.size() == 1 and Schema.validate(duplicated).is_empty())
	check("duplicate_atomic_undo", session.undo() and session.document().to_data() == base)
	check("duplicate_missing_rejected", not session.duplicate_layer("absent").ok and session.document().to_data() == base)
	var root_path := ProjectSettings.globalize_path("res://.godot/map_document_fixture")
	DirAccess.make_dir_recursive_absolute(root_path)
	var path := root_path.path_join("source_" + Crypto.new().generate_random_bytes(8).hex_encode() + ".json")
	var saved := Store.save_source(path, base, "")
	check("save_roundtrip", saved.ok and Store.load_source(path).data == base)
	var next := base.duplicate(true)
	next.name = "Novo nome"
	next.revision = 2
	check("overwrite_requires_hash", Store.save_source(path, next, "").code == "io_conflict" and Store.load_source(path).data == base)
	var second := Store.save_source(path, next, saved.byte_hash)
	check("save_backup", second.ok and Store.recover(path, "bak").data == base and Store.load_source(path).data == next)
	check("autosave", Store.autosave(path, base, second.byte_hash).ok and Store.recover(path, "autosave").data == base and Store.load_source(path).data == next)
	Store._write(path, JSON.stringify(base, "", true, true).to_utf8_buffer())
	check("external_edit", Store.save_source(path, next, second.byte_hash).code == "io_conflict")
	check("recovery_divergence", Store.recover(path, "autosave").base_diverged)
	Store._write(path + ".pending", JSON.stringify(next, "", true, true).to_utf8_buffer())
	check("interruption_original_intact", Store.load_source(path).data == base and Store.recover(path, "pending").data == next)
	check("pending_preserved", Store.save_source(path, next, Store.disk_hash(path)).code == "io_recovery_pending")
	DirAccess.make_dir_absolute(path + ".writer_lock")
	check("concurrent_writer_rejected", Store.save_source(path, next, Store.disk_hash(path)).code == "io_writer_locked")
	DirAccess.remove_absolute(path + ".writer_lock")
	Store._write(path + ".pending", "{".to_utf8_buffer())
	check("truncated_pending_rejected", not Store.recover(path, "pending").ok and Store.load_source(path).data == base)
	check("missing_directory", not Store.save_source(root_path.path_join("absent/file.json"), base, "").ok)
	Store._write(path, "{".to_utf8_buffer())
	check("truncated_file", not Store.load_source(path).ok and Store.recover(path, "bak").data == base)
	check("draft_saved", Store.save_source(path + ".draft", wrong, "").ok)
	check("recovery_kind_safe", not Store.recover(path, "../../other").ok)
	var length_path := path + ".large"
	var file := FileAccess.open(length_path, FileAccess.WRITE)
	file.store_buffer(huge)
	file.close()
	check("io_length_limit", Store.load_source(length_path).code == "source_limit_exceeded")
	print("M1_RESULT " + JSON.stringify({"ok": not failed, "checks": checks, "count": checks.size()}))
	quit(1 if failed else 0)
