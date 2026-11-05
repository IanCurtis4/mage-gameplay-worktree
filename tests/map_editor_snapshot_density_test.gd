extends SceneTree
## Density, identity and type preservation in snapshot metadata graphs.
const GraphEncoding = preload("res://scripts/core/expedition/snapshot/snapshot_graph_encoding.gd")
const CheckpointCodec = preload("res://scripts/core/expedition/persistence/expedition_checkpoint_codec.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void: _run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_SNAPSHOT_DENSITY_CHECK "+id+" "+str(ok))

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0,0,800,800),[],18)
	var actor := PlayerActor.new()
	actor.configure(navigation,RunState.new(&"mage"))
	var shared_vertices: Array[Vector3] = []
	for index: int in 24: shared_vertices.append(Vector3(index,0,index*2))
	var shared_names: Array[String] = ["shared", "terrain", "fixture"]
	var cells: Array[Dictionary] = []
	for cell_index: int in 1000:
		var vertices: Array[Vector3] = []
		for vertex_index: int in 8:
			vertices.append(Vector3(cell_index,vertex_index,cell_index+vertex_index))
		var adjacency: Dictionary[String,int] = {}
		adjacency["west"] = (cell_index+999)%1000
		adjacency["east"] = (cell_index+1)%1000
		adjacency["north"] = (cell_index+997)%1000
		adjacency["south"] = (cell_index+3)%1000
		cells.append({"id":"cell_%04d"%cell_index,"name":"tile_%04d"%cell_index,"vertices":vertices,"adjacency":adjacency,"tags":shared_names,"shared_vertices":shared_vertices})
	var equal_left: Array[int] = [1,2,3,5,8]
	var equal_right: Array[int] = equal_left.duplicate()
	var collision_left: Array[int] = [1,2,3,4,5,6,7,8,9]
	var collision_right: Array[int] = [1,2,3,4,5,6,7,8,10]
	var legacy_values: Array = ["legacy_a", "legacy_b"]
	var legacy_counts: Dictionary = {"legacy_a":1,"legacy_b":2}
	var graph: Dictionary = {"cells":cells,"shared_a":shared_vertices,"shared_b":shared_vertices,"equal_left":equal_left,"equal_right":equal_right,"collision_left":collision_left,"collision_right":collision_right,"legacy_values":legacy_values,"legacy_counts":legacy_counts}
	graph["self"] = graph
	actor.set_meta("snapshot_density_graph",graph)
	var barrier := SnapshotTickBarrier.new()
	check("real_player_actor_run_state_acquires_cut",barrier.acquire(actor).get("ok",false))
	var registry := SnapshotRegistry.new()
	var captured: Dictionary = registry.capture(actor,barrier,true)
	check("one_thousand_cell_metadata_graph_captures_under_four_mib",captured.get("ok",false) and captured.get("bytes",SnapshotRegistry.MAX_BYTES+1) <= SnapshotRegistry.MAX_BYTES)
	if not captured.get("ok",false):
		print("F9_SNAPSHOT_DENSITY_CAPTURE "+JSON.stringify({"error_code":captured.get("error_code",""),"detail":captured.get("detail",""),"snapshot_metrics":captured.get("snapshot_metrics",{})}))
		barrier.release(); actor.free(); _finish(); return
	var payload: Dictionary = captured.snapshot
	var original_bytes: PackedByteArray = var_to_bytes(payload)
	check("capture_preserves_source_metadata_graph",is_same(actor.get_meta("snapshot_density_graph"),graph) and is_same(graph,graph.self) and is_same(graph.shared_a,graph.shared_b))
	var logical_bytes: int = original_bytes.size()
	check("snapshot_payload_validates",registry.validate(payload).get("ok",false))
	var encoded: Dictionary = GraphEncoding.encode_snapshot(payload)
	check("capture_metrics_separate_encoded_and_logical_sizes",captured.bytes == encoded.get("byte_count",-1) and captured.get("logical_bytes",-1) == logical_bytes and captured.bytes <= SnapshotRegistry.MAX_BYTES)
	check("structural_encoding_is_uncompressed_and_within_budget",encoded.get("ok",false) and encoded.get("byte_count",SnapshotRegistry.MAX_BYTES+1) == encoded.get("encoding",PackedByteArray()).size() and encoded.get("byte_count",SnapshotRegistry.MAX_BYTES+1) <= SnapshotRegistry.MAX_BYTES)
	var decoded_encoding: Dictionary = GraphEncoding.decode_snapshot(encoded.encoding) if encoded.get("ok",false) else {"ok":false}
	check("structural_encoding_round_trips_exact_logical_bytes",decoded_encoding.get("ok",false) and var_to_bytes(decoded_encoding.snapshot) == original_bytes)
	var wire_v2: Array = bytes_to_var(encoded.encoding) if encoded.get("ok",false) else []
	var legacy_wire: Array = _wire_v1_expanded(wire_v2)
	var legacy_wire_decoded: Dictionary = GraphEncoding.decode_snapshot(var_to_bytes(legacy_wire)) if not legacy_wire.is_empty() else {"ok":false}
	check("wire_v1_expanded_dictionary_descriptors_remain_compatible",legacy_wire_decoded.get("ok",false) and var_to_bytes(legacy_wire_decoded.snapshot) == original_bytes)
	var out_of_range_wire: Array = wire_v2.duplicate(true)
	var pooled_record_index: int = _pooled_record_index(out_of_range_wire)
	var valid_pool_record: bool = pooled_record_index >= 0
	if valid_pool_record: out_of_range_wire[2][pooled_record_index][2] = out_of_range_wire[3].size()
	check("wire_v2_rejects_out_of_range_key_layout_reference",valid_pool_record and not GraphEncoding.decode_snapshot(var_to_bytes(out_of_range_wire)).get("ok",false))
	var bad_arity_wire: Array = wire_v2.duplicate(true)
	pooled_record_index = _pooled_record_index(bad_arity_wire)
	valid_pool_record = pooled_record_index >= 0 and bad_arity_wire[2][pooled_record_index].size() > 3
	if valid_pool_record: bad_arity_wire[2][pooled_record_index].pop_back()
	check("wire_v2_rejects_key_layout_arity_mismatch",valid_pool_record and not GraphEncoding.decode_snapshot(var_to_bytes(bad_arity_wire)).get("ok",false))
	var duplicate_layout_wire: Array = wire_v2.duplicate(true)
	pooled_record_index = _pooled_record_index(duplicate_layout_wire)
	var layout_index: int = duplicate_layout_wire[2][pooled_record_index][2] if pooled_record_index >= 0 else -1
	var duplicate_layout_valid: bool = layout_index >= 0 and duplicate_layout_wire[3][layout_index].size() >= 2
	if duplicate_layout_valid: duplicate_layout_wire[3][layout_index][1] = duplicate_layout_wire[3][layout_index][0]
	check("wire_v2_rejects_duplicate_key_layout_entries",duplicate_layout_valid and not GraphEncoding.decode_snapshot(var_to_bytes(duplicate_layout_wire)).get("ok",false))
	var unsupported_wire: Array = wire_v2.duplicate(true)
	if not unsupported_wire.is_empty(): unsupported_wire[0] = 99
	check("wire_encoding_version_ninety_nine_is_rejected",not GraphEncoding.decode_snapshot(var_to_bytes(unsupported_wire)).get("ok",false))
	var malformed_wire: Variant = bytes_to_var(encoded.encoding) if encoded.get("ok",false) else null
	var reference_corrupted: bool = _corrupt_first_reference(malformed_wire)
	var malformed_wire_bytes: PackedByteArray = var_to_bytes(malformed_wire) if reference_corrupted else PackedByteArray()
	check("structural_encoding_rejects_dangling_container_reference",reference_corrupted and not GraphEncoding.decode_snapshot(malformed_wire_bytes).get("ok",false))
	var session := {"run_id":"snapshot_density","character_id":"mage","last_committed_seq":1}
	var packed: Dictionary = CheckpointCodec.pack(payload,"a".repeat(64),session)
	var checkpoint: Dictionary = packed.get("checkpoint",{})
	check("codec_writes_transport_format_two_with_encoded_byte_count",packed.get("ok",false) and checkpoint.get("format",0) == 2 and checkpoint.get("byte_count",SnapshotRegistry.MAX_BYTES+1) <= SnapshotRegistry.MAX_BYTES)
	var unpacked: Dictionary = CheckpointCodec.unpack(checkpoint) if packed.get("ok",false) else {"ok":false}
	check("codec_v2_pack_unpack_preserves_exact_var_bytes",unpacked.get("ok",false) and var_to_bytes(unpacked.snapshot) == original_bytes)
	var legacy_actor := PlayerActor.new()
	legacy_actor.configure(navigation,RunState.new(&"mage"))
	var legacy_barrier := SnapshotTickBarrier.new()
	var legacy_acquired: Dictionary = legacy_barrier.acquire(legacy_actor)
	var legacy_capture: Dictionary = SnapshotRegistry.new().capture(legacy_actor,legacy_barrier) if legacy_acquired.get("ok",false) else {"ok":false}
	check("logical_expansion_is_opt_in_without_skipping_compact_encoding",legacy_capture.get("ok",false) and legacy_capture.get("logical_bytes",0) == -1 and legacy_capture.get("encoding",PackedByteArray()).size() == legacy_capture.get("bytes",-1))
	var legacy_payload: Dictionary = legacy_capture.get("snapshot",{})
	var legacy_bytes: PackedByteArray = var_to_bytes(legacy_payload)
	var compressed_legacy: PackedByteArray = legacy_bytes.compress(FileAccess.COMPRESSION_DEFLATE)
	var legacy_record := {"format":1,"snapshot":Marshalls.raw_to_base64(compressed_legacy),"byte_count":legacy_bytes.size(),"sha256":CheckpointCodec.digest_bytes(legacy_bytes),"owner_digest":"b".repeat(64),"session":session}
	var legacy_unpacked: Dictionary = CheckpointCodec.unpack(legacy_record)
	var legacy_restored: Dictionary = SnapshotRegistry.new().restore(legacy_unpacked.snapshot) if legacy_unpacked.get("ok",false) else {"ok":false}
	check("legacy_format_one_deflate_bytes_still_restore",legacy_capture.get("ok",false) and legacy_bytes.size() <= SnapshotRegistry.MAX_BYTES and legacy_unpacked.get("ok",false) and var_to_bytes(legacy_unpacked.snapshot) == legacy_bytes and legacy_restored.get("ok",false))
	if legacy_restored.get("ok",false): legacy_restored.root.free()
	legacy_barrier.release(); legacy_actor.free()
	var future_checkpoint: Dictionary = checkpoint.duplicate(true); future_checkpoint["format"] = 3
	check("transport_format_three_is_rejected",not CheckpointCodec.unpack(future_checkpoint).get("ok",false))
	var truncated_checkpoint: Dictionary = checkpoint.duplicate(true)
	if truncated_checkpoint.get("snapshot") is String: truncated_checkpoint["snapshot"] = truncated_checkpoint["snapshot"].substr(0,maxi(1,int(truncated_checkpoint["snapshot"].length()/2)))
	check("truncated_transport_payload_is_rejected",not CheckpointCodec.unpack(truncated_checkpoint).get("ok",false))
	var digest_checkpoint: Dictionary = checkpoint.duplicate(true); digest_checkpoint["sha256"] = "0".repeat(64)
	check("transport_digest_mismatch_is_rejected",not CheckpointCodec.unpack(digest_checkpoint).get("ok",false))
	var malformed_payload: Dictionary = payload.duplicate(true); malformed_payload["root"] = "entity_missing"
	var malformed_encoding: Dictionary = GraphEncoding.encode_snapshot(malformed_payload)
	var malformed_raw: PackedByteArray = malformed_encoding.get("encoding",PackedByteArray())
	var malformed_compressed: PackedByteArray = malformed_raw.compress(FileAccess.COMPRESSION_DEFLATE)
	var malformed_record := {"format":2,"snapshot":Marshalls.raw_to_base64(malformed_compressed),"byte_count":malformed_raw.size(),"sha256":CheckpointCodec.digest_bytes(malformed_raw),"compressed_sha256":CheckpointCodec.digest_bytes(malformed_compressed),"owner_digest":"c".repeat(64),"session":session}
	check("well_hashed_invalid_snapshot_payload_is_rejected",malformed_encoding.get("ok",false) and not CheckpointCodec.unpack(malformed_record).get("ok",false))
	var restored: Dictionary = SnapshotRegistry.new().restore(unpacked.snapshot) if unpacked.get("ok",false) else {"ok":false}
	check("metadata_graph_restores_with_actor_and_run_state",restored.get("ok",false) and restored.get("root") is PlayerActor)
	if restored.get("ok",false):
		var copy: PlayerActor = restored.root
		var graph_copy: Dictionary = copy.get_meta("snapshot_density_graph")
		check("one_thousand_cells_round_trip",graph_copy.cells is Array and graph_copy.cells.size() == 1000 and graph_copy.cells[999].id == "cell_0999")
		check("typed_vector_arrays_keep_builtin_type",graph_copy.cells[0].vertices is Array and graph_copy.cells[0].vertices.get_typed_builtin() == TYPE_VECTOR3 and graph_copy.cells[0].vertices[0] is Vector3)
		check("typed_string_int_dictionary_keeps_both_types",graph_copy.cells[0].adjacency.get_typed_key_builtin() == TYPE_STRING and graph_copy.cells[0].adjacency.get_typed_value_builtin() == TYPE_INT and graph_copy.cells[0].adjacency["east"] == 1)
		check("cyclic_metadata_reference_is_preserved",is_same(graph_copy,graph_copy.self))
		check("repeated_shared_container_alias_is_preserved",is_same(graph_copy.shared_a,graph_copy.shared_b) and is_same(graph_copy.shared_a,graph_copy.cells[0].shared_vertices) and is_same(graph_copy.shared_a,graph_copy.cells[999].shared_vertices))
		check("equal_but_distinct_arrays_stay_distinct",graph_copy.equal_left == graph_copy.equal_right and not is_same(graph_copy.equal_left,graph_copy.equal_right))
		check("fingerprint_collision_does_not_merge_distinct_arrays",graph_copy.collision_left.size() == 9 and graph_copy.collision_right.size() == 9 and graph_copy.collision_left.slice(0,8) == graph_copy.collision_right.slice(0,8) and graph_copy.collision_left[8] != graph_copy.collision_right[8] and not is_same(graph_copy.collision_left,graph_copy.collision_right))
		check("full_untyped_legacy_descriptors_validate_and_restore",graph_copy.legacy_values == legacy_values and graph_copy.legacy_counts == legacy_counts and graph_copy.legacy_values.get_typed_builtin() == TYPE_NIL and graph_copy.legacy_counts.get_typed_key_builtin() == TYPE_NIL and graph_copy.legacy_counts.get_typed_value_builtin() == TYPE_NIL)
		var partial: Dictionary = payload.duplicate(true)
		var legacy_array_id := _find_array_descriptor(partial.containers,["legacy_a","legacy_b"])
		var partial_rejected := false
		if not legacy_array_id.is_empty():
			partial.containers[legacy_array_id].erase("script")
			partial_rejected = not SnapshotRegistry.new().validate(partial).get("ok",false)
		check("partial_legacy_descriptor_is_rejected",partial_rejected)
		var malformed: Dictionary = payload.duplicate(true)
		var typed_array_id := _find_vector_array_descriptor(malformed.containers)
		var malformed_rejected := false
		if not typed_array_id.is_empty():
			malformed.containers[typed_array_id].type = TYPE_STRING
			malformed_rejected = SnapshotRegistry.new().restore(malformed).get("error_code") == &"invalid_payload"
		check("malformed_typed_container_is_rejected",malformed_rejected)
		var immutable_capture: bool = var_to_bytes(payload) == original_bytes
		var recaptured: Dictionary = SnapshotRegistry.new().capture(actor,barrier)
		check("later_capture_does_not_mutate_earlier_payload",immutable_capture and recaptured.get("ok",false) and var_to_bytes(payload) == original_bytes)
		copy.free()
	graph["oversized_probe"] = "x".repeat(SnapshotRegistry.MAX_BYTES+1024)
	actor.set_meta("snapshot_density_graph",graph)
	var oversize: Dictionary = SnapshotRegistry.new().capture(actor,barrier)
	check("oversized_graph_still_fails_four_mib_budget",oversize.get("error_code") == &"snapshot_too_large" and oversize.get("snapshot_metrics",{}).get("limit_bytes",0) == SnapshotRegistry.MAX_BYTES)
	barrier.release(); actor.free()
	_finish()

func _find_array_descriptor(containers: Dictionary, expected_items: Array) -> String:
	for id: String in containers:
		var descriptor: Dictionary = containers[id]
		if descriptor.get("$") == "array" and descriptor.get("items") == expected_items: return id
	return ""

func _find_vector_array_descriptor(containers: Dictionary) -> String:
	for id: String in containers:
		var descriptor: Dictionary = containers[id]
		if descriptor.get("$") == "array" and descriptor.get("type") == TYPE_VECTOR3: return id
	return ""

func _corrupt_first_reference(value: Variant) -> bool:
	if not value is Array: return false
	if value.size() == 2 and typeof(value[0]) == TYPE_INT and value[0] == 2 and typeof(value[1]) == TYPE_INT:
		value[1] = 2147483647
		return true
	for index: int in value.size():
		if _corrupt_first_reference(value[index]): return true
	return false

func _pooled_record_index(wire: Array) -> int:
	if wire.size() != 4 or not wire[2] is Array: return -1
	for index: int in wire[2].size():
		var record: Variant = wire[2][index]
		if record is Array and record.size() >= 3 and record[1] == 5: return index
	return -1

func _wire_v1_expanded(wire: Array) -> Array:
	if wire.size() != 4 or not wire[2] is Array or not wire[3] is Array: return []
	var legacy: Array = [1,wire[1],wire[2].duplicate(true)]
	for record_index: int in legacy[2].size():
		var record: Variant = legacy[2][record_index]
		if not record is Array or record.size() < 3 or record[1] != 5: continue
		var layout_index: int = record[2]
		if layout_index < 0 or layout_index >= wire[3].size(): return []
		var keys: Array = wire[3][layout_index]
		if record.size() != 3+keys.size(): return []
		var expanded: Array = [record[0],2]
		for key_index: int in keys.size():
			expanded.append(keys[key_index]); expanded.append(record[3+key_index])
		legacy[2][record_index] = expanded
	return legacy

func _finish() -> void:
	var ok: bool = checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_SNAPSHOT_DENSITY_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)
