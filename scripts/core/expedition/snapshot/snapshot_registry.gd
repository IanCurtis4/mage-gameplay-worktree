class_name SnapshotRegistry
extends RefCounted
## Explicit versioned object graph. No Object, Callable, WeakRef, NodePath or
## process-local identity is stored in the envelope. Factories run off-tree;
## references/signals are resolved before a host may activate the result.
const Encoding = preload("res://scripts/core/expedition/snapshot/snapshot_graph_encoding.gd")
const FORMAT := 1
const MANIFEST := "res://scripts/core/expedition/snapshot/runtime_manifest.json"
const MAX_OBJECTS := 16384
const MAX_DEPTH := 96
const MAX_BYTES := Encoding.MAX_BYTES
var schemas: Dictionary = {}
var entities := StableEntityRegistry.new()
var _objects: Array[Object] = []
var _seen: Dictionary = {}
var _records: Dictionary = {}
var _error: Dictionary = {}
var _assets: Dictionary = {}
var _barrier: SnapshotTickBarrier
var _visited_containers: Array = []
var _container_values: Array = []
var _visited_buckets: Dictionary[int,Array] = {}
var _value_buckets: Dictionary[int,Array] = {}
var _containers: Dictionary = {}
var _decoded_containers: Dictionary = {}
var _referenced_tombstones: Dictionary[String, bool] = {}
var _dead_values: Array = []
var _dead_references: Dictionary = {}
var _dead_proxies: Dictionary = {}
var _class_kinds: Dictionary = {}
## Reflection is invariant within one graph operation, never across captures.
var _field_cache: Dictionary = {}
var _base_property_cache: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if parsed is Dictionary: schemas = parsed

func coverage_manifest() -> Dictionary:
	return schemas.duplicate(true)

func _fail(code: StringName, detail: String = "") -> void:
	if _error.is_empty(): _error = StableEntityRegistry.failure(code, detail)

func _kind(value: Object) -> String:
	if value is RandomNumberGenerator: return "rng"
	if value is EffectProcLedger.RootBudget: return "root_budget"
	if value is GeometerCasting.WallReactionVisual: return "wall_reaction_visual"
	var script: Script = value.get_script()
	return script.resource_path if script != null else ""

func _fields(value: Object) -> Array:
	if value is RandomNumberGenerator: return ["seed","state"]
	var kind := _kind(value)
	if _field_cache.has(kind): return _field_cache[kind]
	if not schemas.has(kind):
		_fail(&"unknown_runtime_kind", kind if not kind.is_empty() else value.get_class())
		return []
	var fields: Array = []
	var script: Script = value.get_script()
	while script != null:
		var key := kind if kind in ["root_budget","wall_reaction_visual"] else script.resource_path
		if not schemas.has(key): _fail(&"unknown_runtime_kind", key); return []
		var schema: Dictionary = schemas[key]
		# The list is explicit. New script state cannot disappear unnoticed.
		for property: Dictionary in script.get_script_property_list():
			if (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0: continue
			var name: String = property["name"]
			if name == "script" or name in schema["fields"] or schema["omitted"].has(name): continue
			# Inherited fields belong to their own explicit base schema.
			var base := script.get_base_script()
			if base != null and _base_has_property(base, name): continue
			_fail(&"checkpoint_incomplete", key + ":" + name)
		for field: String in schema["fields"]:
			if field not in fields: fields.append(field)
		if kind in ["root_budget","wall_reaction_visual"]: break
		script = script.get_base_script()
	if _error.is_empty(): _field_cache[kind] = fields
	return fields

func _base_has_property(script: Script, field: String) -> bool:
	if not _base_property_cache.has(script):
		var names := {}
		for property: Dictionary in script.get_script_property_list(): names[property["name"]] = true
		_base_property_cache[script] = names
	return _base_property_cache[script].has(field)

func _is_asset(value: Object) -> bool:
	return value is Resource and not (value as Resource).resource_path.is_empty() and not value is Script

func _visit(value: Variant, depth: int = 0) -> void:
	if not _error.is_empty(): return
	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value): return
	if depth > MAX_DEPTH: _fail(&"snapshot_too_large", "graph nesting"); return
	if value is Array:
		if _container_seen(value): return
		for item: Variant in value: _visit(item, depth + 1)
	elif value is Dictionary:
		if _container_seen(value): return
		for key: Variant in value: _visit(key, depth + 1); _visit(value[key], depth + 1)
	elif value is Callable:
		var binding: Callable = value
		if binding.is_valid():
			_visit(binding.get_object(), depth + 1)
			_visit(binding.get_bound_arguments(), depth + 1)
	elif value is WeakRef:
		_visit(value.get_ref(), depth + 1)
	elif value is Object and is_instance_valid(value):
		if _presentation_target(value): return
		if _is_asset(value): return
		if value is Script: _fail(&"unknown_runtime_kind", "script value"); return
		var local: int = value.get_instance_id()
		if _seen.has(local): return
		if _objects.size() >= MAX_OBJECTS: _fail(&"snapshot_too_large", "object count"); return
		if value is Node and value.is_queued_for_deletion(): _fail(&"checkpoint_incomplete", "deferred deletion pending"); return
		_seen[local] = true
		_objects.append(value)
		for field: String in _fields(value): _visit(value.get(field), depth + 1)
		# Scripted signal bindings are runtime links, rebuilt without emission.
		for signal_info: Dictionary in value.get_signal_list():
			if _signal_omitted(value,signal_info["name"]): continue
			for connection: Dictionary in value.get_signal_connection_list(signal_info["name"]):
				var callback: Callable = connection["callable"]
				if _presentation_target(callback.get_object()): continue
				_visit(callback, depth + 1)

func _presentation_target(value: Object) -> bool:
	return value is Control or value is CanvasLayer or value is Camera2D or value is Window or value is ArenaView or value is ActorDeathVisual or value is ExpeditionGeometryView or value is EquipmentHeadVisual or value is EquipmentAttachmentVisual

func capture(root: Node, barrier: SnapshotTickBarrier) -> Dictionary:
	var started := Time.get_ticks_usec()
	if barrier == null or not barrier.owns(root): return StableEntityRegistry.failure(&"tick_barrier_required")
	_field_cache.clear(); _base_property_cache.clear()
	_objects.clear(); _seen.clear(); _records = {}; _error.clear(); _assets = {}
	_visited_containers.clear(); _container_values.clear(); _visited_buckets.clear(); _value_buckets.clear(); _containers = {}
	_referenced_tombstones.clear()
	_dead_values.clear(); _dead_references = {}
	if root.has_meta(StableEntityRegistry.SCOPE_META):
		if not root.get_meta(StableEntityRegistry.SCOPE_META) is StableEntityRegistry: return StableEntityRegistry.failure(&"invalid_identity")
		entities = root.get_meta(StableEntityRegistry.SCOPE_META)
	else:
		entities = StableEntityRegistry.new()
		root.set_meta(StableEntityRegistry.SCOPE_META,entities)
	_barrier = barrier
	if root is RunController and (root.inventory_frozen or root.run_state.transaction_locked or (root.reward_service != null and root.reward_service.has_pending_transaction())):
		return StableEntityRegistry.failure(&"save_in_progress")
	_visit(root)
	_scan_children(root)
	if not _error.is_empty(): return _error
	var source_semantic := _validate_runtime_graph()
	if not source_semantic["ok"]: return source_semantic
	# Allocation in the original identity order preserves existing deterministic
	# tie breaks after reconstruction, without storing that original identity.
	_objects.sort_custom(func(a: Object, b: Object) -> bool: return a.get_instance_id() < b.get_instance_id())
	for value: Object in _objects:
		var registered := entities.register(value)
		if not registered["ok"]: return registered
	for value: Object in _objects:
		for field: String in _fields(value): _register_identities(value.get(field),field)
	for value: Object in _objects:
		var id := entities.stable_for(value.get_instance_id())
		var fields: Dictionary = {}
		for field: String in _fields(value):
			var raw: Variant = value.get(field)
			if value is RandomNumberGenerator: raw = str(raw)
			if value is PlayerActor and field == "_sentinel_last_launch_frame": raw = int(raw) - Engine.get_process_frames()
			var declared_kind := _field_dead_kind(value,field) if typeof(raw) == TYPE_OBJECT and not is_instance_valid(raw) else ""
			fields[field] = _encode(raw, field,"",0,declared_kind)
		var record := {"kind":_kind(value),"revision":int(schemas[_kind(value)]["revision"]),"generation":entities.generation_for(id),"fields":fields,"signals":_signals(value)}
		if value is Node:
			var parent := (value as Node).get_parent()
			record["node"] = {"parent":entities.stable_for(parent.get_instance_id()) if parent != null else "","name":String(value.name),"index":value.get_index(),"mode":barrier.saved_mode(value),"process":value.is_processing(),"physics":value.is_physics_processing(),"priority":value.process_priority,"physics_priority":value.process_physics_priority,"groups":value.get_groups(),"meta":_encode(_metadata(value))}
			if value is Node2D:
				record["node"]["transform"] = value.transform
				record["node"]["canvas"] = {"visible":value.visible,"z":value.z_index,"relative_z":value.z_as_relative,"y_sort":value.y_sort_enabled,"modulate":value.modulate,"self_modulate":value.self_modulate,"filter":value.texture_filter}
		_records[id] = record
	if not _error.is_empty(): return _error
	if _objects.size()+_dead_references.size() > MAX_OBJECTS: return StableEntityRegistry.failure(&"snapshot_too_large")
	var authority: Dictionary = {}
	if root is RunController and root.persistent_facade != null:
		var profile: ProfileState = root.persistent_facade.current_profile()
		if profile == null: return StableEntityRegistry.failure(&"invalid_session")
		authority = {"profile_id":profile.profile_id,"revision":profile.revision,"reward_session":profile.reward_session}
	var generations: Dictionary = {}
	for id: String in _records: generations[id] = entities.generation_for(id)
	for id: String in _referenced_tombstones: generations[id] = entities.generation_for(id)
	var has_world_view: bool = root is RunController and (root.expedition_view != null or (root.campaign_runtime != null and root.player.world_motion != null))
	var envelope := {"format":FORMAT,"engine":Engine.get_version_info()["string"],"sources":_source_revisions(),"root":entities.stable_for(root.get_instance_id()),"objects":_records,"containers":_containers,"dead_references":_dead_references,"tombstones":_referenced_tombstones.keys(),"identity_generations":generations,"next_entity_serial":entities.next_serial(),"assets":_assets,"coverage":_coverage(),"authority":authority.duplicate(true),"world_view":has_world_view}
	var logical_bytes := var_to_bytes(envelope).size()
	var checked := validate(envelope)
	if not checked["ok"]:
		if checked.get("error_code") == &"snapshot_too_large":
			checked["snapshot_metrics"] = _size_metrics(envelope,logical_bytes)
		return checked
	_objects.clear(); _visited_containers.clear(); _container_values.clear(); _visited_buckets.clear(); _value_buckets.clear()
	# "encoding" is the validated compact form of this envelope. A caller that
	# restores or packs the same unmodified envelope may pass it instead of
	# validating again; any other snapshot keeps the full validation.
	return {"ok":true,"snapshot":envelope,"encoding":checked.encoding,"bytes":checked.byte_count,"logical_bytes":logical_bytes,"capture_usec":Time.get_ticks_usec()-started}

func _size_metrics(envelope: Dictionary, byte_count: int) -> Dictionary:
	# Diagnostics contain counts only; no profile or source payload is exported.
	var kinds := {}
	for descriptor: Dictionary in _containers.values():
		var kind: String = descriptor["$"]
		if not kinds.has(kind): kinds[kind] = {"count":0,"bytes":0}
		kinds[kind].count += 1
		kinds[kind].bytes += var_to_bytes(descriptor).size()
	var raw_geometry: Array = []
	for value: Object in _objects:
		if value is WorldGeometry:
			raw_geometry.append({"stage_bytes":var_to_bytes(value._stage).size(),"surfaces":value._stage.get("surfaces",[]).size(),"connections":value._stage.get("connections",[]).size()})
	return {"envelope_bytes":byte_count,"limit_bytes":MAX_BYTES,"object_count":_objects.size(),"object_record_bytes":var_to_bytes(envelope.objects).size(),"container_count":_containers.size(),"container_record_bytes":var_to_bytes(envelope.containers).size(),"container_kinds":kinds,"raw_geometry":raw_geometry}

func _container_seen(value: Variant) -> bool:
	var bucket := _container_bucket(value)
	for index: int in _visited_buckets.get(bucket,[]):
		if is_same(_visited_containers[index],value): return true
	if not _visited_buckets.has(bucket): _visited_buckets[bucket] = []
	_visited_buckets[bucket].append(_visited_containers.size())
	_visited_containers.append(value)
	return false

func _container_bucket(value: Variant) -> int:
	# The barrier keeps backing containers stable throughout capture. This shallow
	# fingerprint never follows nested containers (cycles are legal). A hash is
	# only a search bucket: is_same remains the authority for container identity.
	var signature: Array[int] = [typeof(value),value.size()]
	if value is Array:
		signature.append(value.get_typed_builtin())
		for index: int in mini(value.size(),8): signature.append(_shallow_hash(value[index]))
	else:
		signature.append(value.get_typed_key_builtin()); signature.append(value.get_typed_value_builtin())
		var count := 0
		for key: Variant in value:
			signature.append(_shallow_hash(key)); signature.append(_shallow_hash(value[key]))
			count += 1
			if count == 8: break
	return hash(signature)

func _shallow_hash(value: Variant) -> int:
	if value is Array or value is Dictionary: return hash(Vector2i(typeof(value),value.size()))
	if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID]: return typeof(value)
	return hash(value)

## F10 Q1: the code of a process does not change while it runs, and hashing every
## script took ~0.6 s per capture and per validation. Once per process; each
## caller gets its own copy, so a tampered snapshot still differs from the truth.
static var _revisions_cache: Dictionary = {}
static var _digest_cache: Dictionary = {}
static var _digest_mutex := Mutex.new()

func _source_revisions() -> Dictionary:
	_digest_mutex.lock(); var known: Dictionary = _revisions_cache; _digest_mutex.unlock()
	if not known.is_empty(): return known.duplicate()
	var paths: Array[String] = [MANIFEST, "res://data/expedition/policies/e07_initial.json"]
	_collect_sources("res://scripts",paths)
	paths.sort()
	var result: Dictionary = {}
	for path: String in paths: result[path] = _content_digest(path)
	_digest_mutex.lock(); _revisions_cache = result; _digest_mutex.unlock()
	return result.duplicate()

func _content_digest(logical_path: String) -> String:
	_digest_mutex.lock(); var known: Variant = _digest_cache.get(logical_path); _digest_mutex.unlock()
	if known != null: return known
	var digest := _file_digest(logical_path)
	if not digest.is_empty():
		_digest_mutex.lock(); _digest_cache[logical_path] = digest; _digest_mutex.unlock()
	return digest

func _file_digest(logical_path: String) -> String:
	# Editor files and exported resources have different physical storage.
	# Hash the exact bytes actually loaded by this build; never omit a digest
	# or accept a missing asset. Cross-build checkpoint migration stays unsupported.
	if FileAccess.file_exists(logical_path): return FileAccess.get_sha256(logical_path)
	for suffix: String in [".remap", ".import"]:
		var sidecar := logical_path + suffix
		if not FileAccess.file_exists(sidecar): continue
		var config := ConfigFile.new()
		if config.load(sidecar) != OK or not config.has_section("remap"): return ""
		var target := ""
		for key: String in config.get_section_keys("remap"):
			if key == "path": target = str(config.get_value("remap", key)); break
			if key.begins_with("path."):
				var compatible := true
				for feature: String in key.trim_prefix("path.").split("."):
					if not OS.has_feature(feature): compatible = false; break
				if compatible: target = str(config.get_value("remap", key))
		if not target.begins_with("res://") or not FileAccess.file_exists(target): return ""
		return FileAccess.get_sha256(target)
	return ""

func _collect_sources(directory: String, paths: Array[String]) -> void:
	var source := DirAccess.open(directory)
	if source == null: return
	for file: String in source.get_files():
		var logical := directory.path_join(file.trim_suffix(".remap"))
		if (logical.ends_with(".gd") or logical.ends_with(".gdshader")) and logical not in paths: paths.append(logical)
	for child: String in source.get_directories(): _collect_sources(directory.path_join(child),paths)

func _scan_children(node: Node) -> void:
	for child: Node in node.get_children():
		if _presentation_target(child): continue
		if child.get_script() != null:
			_visit(child)
			_scan_children(child)
		else:
			_fail(&"unknown_runtime_kind", child.get_class())

func _metadata(node: Node) -> Dictionary:
	var result: Dictionary = {}
	for name: StringName in node.get_meta_list():
		if name != StableEntityRegistry.SCOPE_META: result[name] = node.get_meta(name)
	return result

func _coverage() -> Dictionary:
	var result: Dictionary = {}
	for record: Dictionary in _records.values(): result[record["kind"]] = int(record["revision"])
	return result

func _identity(local: int) -> String:
	if local == 0: return ""
	var stable := entities.stable_for(local)
	if entities.is_tombstone_local(local):
		_referenced_tombstones[stable] = true
		return stable
	var living := instance_from_id(local)
	if living != null and not _seen.has(local):
		_fail(&"dangling_entity_reference", "entity outside captured scope")
		return ""
	if living != null: return stable
	if stable.is_empty(): stable = entities.tombstone(local)
	if stable.is_empty(): _fail(&"snapshot_too_large","identity registry limit"); return ""
	_referenced_tombstones[stable] = true
	return stable

func _register_identities(value: Variant, field: String, depth: int = 0) -> void:
	if depth > MAX_DEPTH: return
	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value): return
	if typeof(value) == TYPE_INT and SnapshotIdentityRoles.value_role(field) == "entity": _identity(value)
	if typeof(value) in [TYPE_STRING,TYPE_STRING_NAME] and SnapshotIdentityRoles.value_role(field) in ["entity","identity_string"]:
		for span: Dictionary in _identity_spans(String(value),field): _identity(int(span["text"]))
	if value is Array:
		for index: int in value.size():
			var item: Variant = value[index]
			if typeof(item) == TYPE_INT and (SnapshotIdentityRoles.value_role(field) == "entities" or (field == "binding:_on_hunter_explosive_hit" and index == 0)): _identity(item)
			_register_identities(item,"",depth+1)
	if value is Dictionary:
		for key: Variant in value:
			if key is Callable: _fail(&"checkpoint_incomplete","callable dictionary key"); return
			if typeof(key) == TYPE_INT and SnapshotIdentityRoles.key_role(field) == "entity": _identity(key)
			if typeof(key) in [TYPE_STRING,TYPE_STRING_NAME] and SnapshotIdentityRoles.key_role(field) in ["entity","identity_string"]:
				for span: Dictionary in _identity_spans(String(key),field): _identity(int(span["text"]))
			if field == "_occurrence_actors" and typeof(value[key]) == TYPE_INT: _identity(value[key])
			_register_identities(value[key],String(key) if typeof(key) in [TYPE_STRING,TYPE_STRING_NAME] else "",depth+1)
	if value is Callable and value.is_valid(): _register_identities(value.get_bound_arguments(),"binding:"+String(value.get_method()),depth+1)

func _identity_spans(text: String, field: String) -> Array[Dictionary]:
	# Closed existing grammars only. Equipment/card/source counters are not
	# actor identities even if their digits happen to equal an engine ID.
	var pattern := "^([0-9]+)$"
	if field in ["root_event_id","ancestor_root_id","_roots"]: pattern = "^.*:([0-9]+):[0-9]+$"
	elif field == "claims": pattern = "^(?:spiritualist_echo:([0-9]+):([0-9]+)|[a-z][a-z0-9_]*:([0-9]+))$"
	elif field == "pairs": pattern = "^([0-9]+):([0-9]+)$"
	elif field in ["burn_streams","bleed_streams"]: pattern = "^([0-9]+):[a-z][a-z0-9_]*$"
	elif field in ["_world_id","_segments","_temporary"]: pattern = "^ice_wall/([0-9]+)/(-?[0-9]+)$"
	elif field in ["occurrence_id","enemy_id","event_id","_events","_occurrence_actors"]: pattern = "^(?:mob:)?(?:trial_[0-9]+_|demo_)([0-9]+)$"
	elif field == "events": pattern = "^(?:outgoing|taunt)_(?:trial_[0-9]+_|demo_)([0-9]+)_[0-9]+$"
	elif text.begins_with("hunter_tar_") or text.begins_with("phantom_barrier_"): pattern = "^(?:hunter_tar_|phantom_barrier_)([0-9]+)$"
	var regex := RegEx.new(); regex.compile(pattern)
	var found := regex.search(text)
	var spans: Array[Dictionary] = []
	if found == null: return spans
	for group: int in range(1,found.get_group_count()+1):
		if found.get_start(group) >= 0: spans.append({"start":found.get_start(group),"end":found.get_end(group),"text":found.get_string(group)})
	return spans

func _encode_identity_string(value: Variant, field: String) -> Variant:
	var text := String(value)
	var parts: Array = []
	var cursor := 0
	for span: Dictionary in _identity_spans(text,field):
		var stable := _identity(int(span["text"]))
		if stable.is_empty(): continue
		parts.append(text.substr(cursor,int(span["start"])-cursor))
		parts.append({"$":"identity","id":stable})
		cursor = int(span["end"])
	if parts.is_empty(): return value
	parts.append(text.substr(cursor))
	return {"$":"identity_string","parts":parts,"name":typeof(value)==TYPE_STRING_NAME}

func _encode(value: Variant, field: String = "", role: String = "", depth: int = 0, declared_kind: String = "") -> Variant:
	if depth > MAX_DEPTH: _fail(&"snapshot_too_large"); return null
	if typeof(value) == TYPE_OBJECT and not is_instance_valid(value): return _encode_dead_reference(value,declared_kind)
	if role.is_empty(): role = SnapshotIdentityRoles.value_role(field)
	if typeof(value) == TYPE_INT and role in ["entity","entities"]:
		return {"$":"identity","id":_identity(value)}
	if typeof(value) in [TYPE_STRING,TYPE_STRING_NAME] and role in ["identity_string","entity"]: return _encode_identity_string(value,field)
	if value is Array:
		var existing := _container_id(value)
		if not existing.is_empty(): return {"$":"container","id":existing}
		var id := _reserve_container(value)
		var items: Array = []
		var item_kind := _dead_kind_from_type(value.get_typed_script(),String(value.get_typed_class_name()))
		for index: int in value.size():
			var item_role := "entity" if role == "entities" or (field == "binding:_on_hunter_explosive_hit" and index == 0) else "value"
			items.append(_encode(value[index],field,item_role,depth+1,item_kind))
		_containers[id] = {"$":"array","items":items,"type":value.get_typed_builtin(),"class":String(value.get_typed_class_name()),"script":_script_path(value.get_typed_script())}
		return {"$":"container","id":id}
	if value is Dictionary:
		var existing := _container_id(value)
		if not existing.is_empty(): return {"$":"container","id":existing}
		var id := _reserve_container(value)
		var items: Array = []
		var key_kind := _dead_kind_from_type(value.get_typed_key_script(),String(value.get_typed_key_class_name()))
		var item_kind := _dead_kind_from_type(value.get_typed_value_script(),String(value.get_typed_value_class_name()))
		for key: Variant in value:
			var item_field := String(key) if typeof(key) in [TYPE_STRING,TYPE_STRING_NAME] else ""
			var item_role := "entity" if field == "_occurrence_actors" else ""
			items.append([_encode(key,field,SnapshotIdentityRoles.key_role(field),depth+1,key_kind),_encode(value[key],item_field,item_role,depth+1,item_kind)])
		_containers[id] = {"$":"dictionary","items":items,"key_type":value.get_typed_key_builtin(),"key_class":String(value.get_typed_key_class_name()),"key_script":_script_path(value.get_typed_key_script()),"value_type":value.get_typed_value_builtin(),"value_class":String(value.get_typed_value_class_name()),"value_script":_script_path(value.get_typed_value_script())}
		return {"$":"container","id":id}
	if value is Callable:
		var callback: Callable = value
		if not callback.is_valid(): return {"$":"binding","target":""}
		var target := entities.stable_for(callback.get_object_id())
		var method := String(callback.get_method())
		if target.is_empty() or method.begins_with("<"): _fail(&"checkpoint_incomplete","unregistered callable"); return null
		return {"$":"binding","target":target,"method":method,"args":_encode(callback.get_bound_arguments(),"binding:"+method),"unbound":callback.get_unbound_arguments_count()}
	if value is WeakRef:
		return {"$":"weak","target":_encode(value.get_ref())}
	if value is Object:
		if not is_instance_valid(value): return null
		if _presentation_target(value): return null
		if _is_asset(value):
			var path: String = value.resource_path
			var digest := _content_digest(path.get_slice("::",0))
			if digest.length() != 64: _fail(&"content_revision_unavailable",path); return null
			_assets[path] = digest
			return {"$":"asset","path":path}
		var id := entities.stable_for(value.get_instance_id())
		if id.is_empty(): _fail(&"unknown_runtime_kind",_kind(value)); return null
		return {"$":"object","id":id}
	if typeof(value) in [TYPE_SIGNAL,TYPE_RID,TYPE_NODE_PATH]: _fail(&"checkpoint_incomplete","native handle"); return null
	return value

func _dead_kind_from_type(script: Variant, native: String) -> String:
	if script is Script:
		var path: String = script.resource_path
		return path if schemas.has(path) else ""
	return "native:"+native if native in ["Node","Node2D","CanvasItem"] else ""

func _field_dead_kind(owner: Object, field: String) -> String:
	if _class_kinds.is_empty():
		for kind: String in schemas:
			if kind.begins_with("res://"):
				var script := load(kind) as Script
				if not String(script.get_global_name()).is_empty(): _class_kinds[String(script.get_global_name())] = kind
		_class_kinds["WallReactionVisual"] = "wall_reaction_visual"
	for property: Dictionary in owner.get_property_list():
		if property["name"] == field:
			var name: String = property.get("class_name", "")
			return _class_kinds.get(name,_dead_kind_from_type(null,name))
	return ""

func _dead_kind_allowed(kind: String) -> bool:
	if kind in ["native:Node","native:Node2D","native:CanvasItem"]: return true
	if not schemas.has(kind): return false
	var native := _native_class(kind)
	return native == "Node" or ClassDB.is_parent_class(native,"Node")

func _kind_extends(kind: String, base: String) -> bool:
	if kind == base: return true
	if base.begins_with("native:"):
		var native := kind.trim_prefix("native:") if kind.begins_with("native:") else _native_class(kind)
		return native == base.trim_prefix("native:") or ClassDB.is_parent_class(native,base.trim_prefix("native:"))
	if kind.begins_with("native:") or not kind.begins_with("res://"): return false
	var script := load(kind) as Script
	while script != null:
		if script.resource_path == base: return true
		script = script.get_base_script()
	return false

func _encode_dead_reference(value: Variant, kind: String) -> Variant:
	if not _dead_kind_allowed(kind): _fail(&"dangling_entity_reference","destroyed reference without a declared node type"); return null
	for index: int in _dead_values.size():
		if not is_same(_dead_values[index],value): continue
		var id := "dead_%06d" % (index+1)
		var previous: String = _dead_references[id]["kind"]
		if _kind_extends(kind,previous): _dead_references[id]["kind"] = kind
		elif not _kind_extends(previous,kind): _fail(&"dangling_entity_reference","conflicting destroyed-reference types")
		return {"$":"dead_reference","id":id}
	_dead_values.append(value)
	var id := "dead_%06d" % _dead_values.size()
	_dead_references[id] = {"kind":kind}
	return {"$":"dead_reference","id":id}

func _container_id(value: Variant) -> String:
	for index: int in _value_buckets.get(_container_bucket(value),[]):
		if is_same(_container_values[index],value): return "container_%06d" % (index+1)
	return ""

func _reserve_container(value: Variant) -> String:
	var bucket := _container_bucket(value)
	if not _value_buckets.has(bucket): _value_buckets[bucket] = []
	_value_buckets[bucket].append(_container_values.size())
	_container_values.append(value)
	return "container_%06d" % _container_values.size()

func _script_path(value: Variant) -> String:
	if value == null: return ""
	var path: String = value.resource_path
	if not schemas.has(path): _fail(&"unknown_runtime_kind", path)
	return path

func _signals(value: Object) -> Array:
	var result: Array = []
	for signal_info: Dictionary in value.get_signal_list():
		if _signal_omitted(value,signal_info["name"]): continue
		for connection: Dictionary in value.get_signal_connection_list(signal_info["name"]):
			var callback: Callable = connection["callable"]
			if _presentation_target(callback.get_object()): continue
			result.append({"signal":String(signal_info["name"]),"binding":_encode(callback),"flags":connection["flags"]})
	return result

func _signal_omitted(value: Object, name: String) -> bool:
	return schemas.get(_kind(value),{}).get("omitted_signals",{}).has(name)

func validate(snapshot: Dictionary) -> Dictionary:
	if snapshot.get("format") != FORMAT: return StableEntityRegistry.failure(&"content_revision_unavailable")
	var pure := _validate_pure_value(snapshot,0)
	if not pure["ok"]: return pure
	var envelope_fields := ["format","engine","sources","root","objects","containers","dead_references","tombstones","identity_generations","next_entity_serial","assets","coverage","authority","world_view"]
	if not snapshot.has_all(envelope_fields): return StableEntityRegistry.failure(&"checkpoint_incomplete")
	if snapshot.size() != envelope_fields.size(): return StableEntityRegistry.failure(&"invalid_payload","unknown envelope field")
	if snapshot.get("engine") != Engine.get_version_info()["string"] or not snapshot.get("sources") is Dictionary or snapshot["sources"] != _source_revisions(): return StableEntityRegistry.failure(&"content_revision_unavailable")
	if not snapshot.get("objects") is Dictionary or not snapshot.get("containers") is Dictionary or not snapshot.get("assets") is Dictionary or not snapshot.get("tombstones") is Array or not snapshot.get("coverage") is Dictionary: return StableEntityRegistry.failure(&"checkpoint_incomplete")
	if not snapshot.get("authority") is Dictionary or typeof(snapshot.get("world_view")) != TYPE_BOOL: return StableEntityRegistry.failure(&"checkpoint_incomplete")
	if not snapshot.get("identity_generations") is Dictionary or typeof(snapshot.get("next_entity_serial")) != TYPE_INT or int(snapshot["next_entity_serial"]) < 1 or int(snapshot["next_entity_serial"]) > StableEntityRegistry.MAX_IDENTITIES+1: return StableEntityRegistry.failure(&"invalid_identity")
	if not snapshot.get("dead_references") is Dictionary: return StableEntityRegistry.failure(&"checkpoint_incomplete")
	var objects: Dictionary = snapshot["objects"]
	if objects.size()+snapshot["dead_references"].size() > MAX_OBJECTS: return StableEntityRegistry.failure(&"snapshot_too_large")
	if not objects.has(snapshot.get("root","")): return StableEntityRegistry.failure(&"dangling_entity_reference")
	var ids: Dictionary = {}
	for id: Variant in objects:
		if not id is String or not id.begins_with("entity_"): return StableEntityRegistry.failure(&"invalid_identity")
		ids[id] = true
	for id: Variant in snapshot["tombstones"]:
		if not id is String or ids.has(id): return StableEntityRegistry.failure(&"duplicate_stable_id")
		ids[id] = true
	if ids.size() != snapshot["identity_generations"].size(): return StableEntityRegistry.failure(&"invalid_identity")
	for id: String in ids:
		var serial := int(id.trim_prefix("entity_"))
		if serial < 1 or serial >= int(snapshot["next_entity_serial"]) or id != "entity_%06d" % serial or typeof(snapshot["identity_generations"].get(id)) != TYPE_INT or int(snapshot["identity_generations"][id]) < 0: return StableEntityRegistry.failure(&"invalid_identity")
		if objects.has(id) and (not objects[id] is Dictionary or objects[id].get("generation") != snapshot["identity_generations"][id]): return StableEntityRegistry.failure(&"invalid_identity")
	var references: Dictionary = {}
	for id: String in ids: references[id] = "identity"
	for id: Variant in snapshot["dead_references"]:
		var descriptor: Variant = snapshot["dead_references"][id]
		if not id is String or not id.begins_with("dead_") or not descriptor is Dictionary or not descriptor.get("kind") is String or not _dead_kind_allowed(descriptor["kind"]): return StableEntityRegistry.failure(&"dangling_entity_reference","destroyed-reference descriptor")
		references[id] = "dead_reference"
	for id: Variant in snapshot["containers"]:
		if not id is String or not id.begins_with("container_") or references.has(id): return StableEntityRegistry.failure(&"duplicate_stable_id")
		if not snapshot["containers"][id] is Dictionary or snapshot["containers"][id].get("$") not in ["array","dictionary"]: return StableEntityRegistry.failure(&"invalid_payload","container descriptor")
		references[id] = snapshot["containers"][id]["$"]
	for descriptor: Variant in snapshot["containers"].values():
		if not descriptor is Dictionary or descriptor.get("$") not in ["array","dictionary"] or not descriptor.get("items") is Array: return StableEntityRegistry.failure(&"invalid_payload")
		for prefix: String in ([""] if descriptor["$"] == "array" else ["key_","value_"]):
			if typeof(descriptor.get(prefix+"type")) != TYPE_INT or int(descriptor[prefix+"type"]) < TYPE_NIL or int(descriptor[prefix+"type"]) >= TYPE_MAX: return StableEntityRegistry.failure(&"invalid_payload","container type")
			if not descriptor.get(prefix+"class") is String or not descriptor.get(prefix+"script") is String: return StableEntityRegistry.failure(&"invalid_payload","container class")
			var script: String = descriptor[prefix+"script"]
			if not script.is_empty() and not schemas.has(script): return StableEntityRegistry.failure(&"unknown_runtime_kind",script)
		if descriptor["$"] == "dictionary":
			for pair: Variant in descriptor["items"]:
				if not pair is Array or pair.size() != 2: return StableEntityRegistry.failure(&"invalid_payload","dictionary pair")
		var valid := _validate_value(descriptor["items"],objects,references,snapshot["assets"],0)
		if not valid["ok"]: return valid
	for path: Variant in snapshot["assets"]:
		if not path is String or not path.begins_with("res://") or not snapshot["assets"][path] is String or snapshot["assets"][path].length() != 64 or _content_digest(path.get_slice("::",0)) != snapshot["assets"][path]: return StableEntityRegistry.failure(&"content_revision_unavailable")
	var coverage: Dictionary = {}
	for record: Variant in objects.values():
		if not record is Dictionary or not schemas.has(record.get("kind","")): return StableEntityRegistry.failure(&"unknown_runtime_kind")
		var schema: Dictionary = schemas[record["kind"]]
		if record.get("revision") != int(schema["revision"]): return StableEntityRegistry.failure(&"content_revision_unavailable")
		if typeof(record.get("generation")) != TYPE_INT or int(record["generation"]) < 0: return StableEntityRegistry.failure(&"invalid_identity")
		coverage[record["kind"]] = record["revision"]
		if not record.get("fields") is Dictionary or not record.get("signals") is Array: return StableEntityRegistry.failure(&"checkpoint_incomplete")
		for connection: Variant in record["signals"]:
			if not connection is Dictionary or not connection.get("signal") is String or typeof(connection.get("flags")) != TYPE_INT or not connection.get("binding") is Dictionary or connection["binding"].get("$") != "binding": return StableEntityRegistry.failure(&"invalid_payload","signal descriptor")
		if record["kind"] == "rng":
			for key: String in ["seed","state"]:
				var raw: Variant = record["fields"].get(key)
				if not raw is String or str(int(raw)) != raw: return StableEntityRegistry.failure(&"invalid_rng_state")
		var expected := _schema_fields(record["kind"])
		if record["fields"].size() != expected.size(): return StableEntityRegistry.failure(&"checkpoint_incomplete")
		for field: String in expected:
			if not record["fields"].has(field): return StableEntityRegistry.failure(&"checkpoint_incomplete",field)
		var native := _native_class(record["kind"])
		var is_node := native == "Node" or ClassDB.is_parent_class(native,"Node")
		if is_node != record.has("node"): return StableEntityRegistry.failure(&"checkpoint_incomplete","node kind")
		if record.has("node"):
			if not record["node"] is Dictionary: return StableEntityRegistry.failure(&"checkpoint_incomplete")
			var node: Dictionary = record["node"]
			if not node.has_all(["parent","name","index","mode","process","physics","priority","physics_priority","groups","meta"]): return StableEntityRegistry.failure(&"checkpoint_incomplete","node metadata")
			if not node["parent"] is String or not node["name"] is String or typeof(node["index"]) != TYPE_INT or typeof(node["mode"]) != TYPE_INT or int(node["mode"]) < 0 or int(node["mode"]) > Node.PROCESS_MODE_DISABLED or typeof(node["process"]) != TYPE_BOOL or typeof(node["physics"]) != TYPE_BOOL or not node["groups"] is Array: return StableEntityRegistry.failure(&"invalid_payload","node metadata")
			if typeof(node["priority"]) != TYPE_INT or typeof(node["physics_priority"]) != TYPE_INT: return StableEntityRegistry.failure(&"invalid_payload","process priority")
			if not _container_reference_is(node["meta"],snapshot["containers"],"dictionary"): return StableEntityRegistry.failure(&"invalid_payload","metadata container")
			for group: Variant in node["groups"]:
				if typeof(group) not in [TYPE_STRING,TYPE_STRING_NAME]: return StableEntityRegistry.failure(&"invalid_payload","node group")
			if native == "Node2D" or ClassDB.is_parent_class(native,"Node2D"):
				if typeof(node.get("transform")) != TYPE_TRANSFORM2D or not node.get("canvas") is Dictionary: return StableEntityRegistry.failure(&"invalid_payload","canvas metadata")
				var canvas: Dictionary = node["canvas"]
				if not canvas.has_all(["visible","z","relative_z","y_sort","modulate","self_modulate","filter"]): return StableEntityRegistry.failure(&"checkpoint_incomplete","canvas metadata")
				if typeof(canvas["visible"]) != TYPE_BOOL or typeof(canvas["relative_z"]) != TYPE_BOOL or typeof(canvas["y_sort"]) != TYPE_BOOL or typeof(canvas["z"]) != TYPE_INT or typeof(canvas["filter"]) != TYPE_INT or typeof(canvas["modulate"]) != TYPE_COLOR or typeof(canvas["self_modulate"]) != TYPE_COLOR: return StableEntityRegistry.failure(&"invalid_payload","canvas types")
			var parent: String = record["node"].get("parent", "")
			if not parent.is_empty() and not objects.has(parent): return StableEntityRegistry.failure(&"dangling_entity_reference")
			var visited: Dictionary = {}
			while not parent.is_empty():
				if visited.has(parent): return StableEntityRegistry.failure(&"dangling_entity_reference","parent cycle")
				visited[parent] = true
				if not objects[parent].get("node") is Dictionary: return StableEntityRegistry.failure(&"dangling_entity_reference","parent kind")
				parent = objects[parent]["node"].get("parent", "")
				if not parent.is_empty() and not objects.has(parent): return StableEntityRegistry.failure(&"dangling_entity_reference")
		var checked := _validate_value(record,objects,references,snapshot["assets"],0)
		if not checked["ok"]: return checked
	if coverage != snapshot["coverage"]: return StableEntityRegistry.failure(&"checkpoint_incomplete","coverage mismatch")
	if not objects[snapshot["root"]].has("node") or not String(objects[snapshot["root"]]["node"]["parent"]).is_empty(): return StableEntityRegistry.failure(&"invalid_payload","root node")
	for id: String in objects:
		if id != snapshot["root"] and objects[id].has("node") and String(objects[id]["node"]["parent"]).is_empty(): return StableEntityRegistry.failure(&"dangling_entity_reference","node outside scope")
	var authority_check := _validate_value(snapshot["authority"],objects,references,snapshot["assets"],0)
	if not authority_check["ok"]: return authority_check
	return Encoding.encode_snapshot(snapshot)

func _validate_pure_value(value: Variant, depth: int) -> Dictionary:
	if depth > MAX_DEPTH: return StableEntityRegistry.failure(&"snapshot_too_large")
	if typeof(value) in [TYPE_OBJECT,TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID,TYPE_NODE_PATH]: return StableEntityRegistry.failure(&"invalid_payload","runtime handle")
	if value is Array:
		for item: Variant in value:
			var checked := _validate_pure_value(item,depth+1)
			if not checked["ok"]: return checked
	if value is Dictionary:
		for key: Variant in value:
			var checked := _validate_pure_value(key,depth+1)
			if not checked["ok"]: return checked
			checked = _validate_pure_value(value[key],depth+1)
			if not checked["ok"]: return checked
	return {"ok":true}

func _native_class(kind: String) -> String:
	if kind == "rng": return "RandomNumberGenerator"
	if kind == "root_budget": return "RefCounted"
	if kind == "wall_reaction_visual": return "Node2D"
	return (load(kind) as Script).get_instance_base_type()

func _schema_fields(kind: String) -> Array:
	var fields: Array = []
	while schemas.has(kind):
		for field: String in schemas[kind]["fields"]:
			if field not in fields: fields.append(field)
		if kind in ["root_budget","wall_reaction_visual","rng"]: break
		var script := load(kind) as Script
		var base := script.get_base_script()
		kind = base.resource_path if base != null else ""
	return fields

func _validate_value(value: Variant, objects: Dictionary, ids: Dictionary, assets: Dictionary, depth: int) -> Dictionary:
	if depth > MAX_DEPTH: return StableEntityRegistry.failure(&"snapshot_too_large")
	if value is Object or typeof(value) in [TYPE_CALLABLE,TYPE_SIGNAL,TYPE_RID,TYPE_NODE_PATH]: return StableEntityRegistry.failure(&"invalid_payload","runtime handle")
	if value is Array:
		for item: Variant in value:
			var checked := _validate_value(item,objects,ids,assets,depth+1)
			if not checked["ok"]: return checked
	if value is Dictionary:
		if value.has("$") and not value["$"] is String: return StableEntityRegistry.failure(&"invalid_payload","value tag")
		var tag: String = value.get("$", "")
		if not tag.is_empty() and tag not in ["container","object","identity","identity_string","binding","weak","asset","dead_reference"]: return StableEntityRegistry.failure(&"invalid_payload","unknown tag")
		if tag == "dead_reference" and (not value.get("id") is String or ids.get(value["id"]) != "dead_reference"): return StableEntityRegistry.failure(&"dangling_entity_reference")
		if tag in ["object","identity","container"] and not value.get("id") is String: return StableEntityRegistry.failure(&"invalid_payload","reference identity")
		if tag == "weak" and (not value.has("target") or (value["target"] != null and (not value["target"] is Dictionary or value["target"].get("$") != "object"))): return StableEntityRegistry.failure(&"invalid_payload","weak reference")
		if tag == "identity_string" and (not value.get("parts") is Array or typeof(value.get("name")) != TYPE_BOOL): return StableEntityRegistry.failure(&"invalid_payload","identity string")
		if tag == "identity_string":
			for part: Variant in value["parts"]:
				if not part is String and not (part is Dictionary and part.get("$") == "identity"): return StableEntityRegistry.failure(&"invalid_payload","identity string part")
		if tag == "binding":
			if not value.get("target") is String: return StableEntityRegistry.failure(&"invalid_payload","binding target")
			if not String(value["target"]).is_empty() and (not value.get("method") is String or not value.get("args") is Dictionary or typeof(value.get("unbound")) != TYPE_INT or int(value["unbound"]) < 0): return StableEntityRegistry.failure(&"invalid_payload","binding descriptor")
			if not String(value["target"]).is_empty() and (value["args"].get("$") != "container" or ids.get(value["args"].get("id","")) != "array"): return StableEntityRegistry.failure(&"invalid_payload","binding arguments")
		if tag == "container" and ids.get(value.get("id", "")) not in ["array","dictionary"]: return StableEntityRegistry.failure(&"dangling_entity_reference")
		if tag in ["object","identity"] and not String(value.get("id", "")).is_empty():
			if (tag == "object" and not objects.has(value["id"])) or (tag == "identity" and ids.get(value["id"]) != "identity"): return StableEntityRegistry.failure(&"dangling_entity_reference")
		if tag == "binding" and not String(value.get("target", "")).is_empty() and not objects.has(value["target"]): return StableEntityRegistry.failure(&"dangling_entity_reference")
		if tag == "rng" and (not String(value.get("state", "")).is_valid_int() or not String(value.get("seed", "")).is_valid_int()): return StableEntityRegistry.failure(&"invalid_rng_state")
		if tag == "asset" and not assets.has(value.get("path", "")): return StableEntityRegistry.failure(&"content_revision_unavailable")
		for key: Variant in value:
			var checked := _validate_value(value[key],objects,ids,assets,depth+1)
			if not checked["ok"]: return checked
	return {"ok":true}

func _container_reference_is(value: Variant, containers: Dictionary, kind: String) -> bool:
	return value is Dictionary and value.get("$") == "container" and containers.get(value.get("id",""),{}).get("$") == kind

func _factory(kind: String) -> Object:
	match kind:
		"rng": return RandomNumberGenerator.new()
		"root_budget": return EffectProcLedger.RootBudget.new()
		"wall_reaction_visual": return GeometerCasting.WallReactionVisual.new()
		"res://scripts/core/run_state.gd": return RunState.new(RunState.DEFAULT_CLASS_ID, true)
		"res://scripts/core/run_reward_service.gd": return RunRewardService.new(null)
		"res://scripts/core/run_build_service.gd": return RunBuildService.new(null)
		"res://scripts/core/expedition/spatial/flat_world_geometry.gd": return FlatWorldGeometry.new(null)
	return (load(kind) as Script).new()

func restore(snapshot: Dictionary, facade: ProfileFacade = null, validated_encoding: PackedByteArray = PackedByteArray()) -> Dictionary:
	var started := Time.get_ticks_usec()
	_field_cache.clear(); _base_property_cache.clear()
	# Only the encoding returned by capture() for this same envelope skips it.
	var checked := {"ok":true} if not validated_encoding.is_empty() else validate(snapshot)
	if not checked["ok"]: return checked
	if not snapshot["authority"].is_empty():
		if facade == null: return StableEntityRegistry.failure(&"restore_binding_required")
		var profile := facade.current_profile()
		var authority: Dictionary = snapshot["authority"]
		if profile == null or profile.profile_id != authority.get("profile_id"): return StableEntityRegistry.failure(&"invalid_session")
		if profile.revision != authority.get("revision") or profile.reward_session != authority.get("reward_session"): return StableEntityRegistry.failure(&"stale_revision")
	entities = StableEntityRegistry.new()
	_objects.clear()
	_error.clear()
	var ids: Array = snapshot["objects"].keys()
	ids.sort()
	# Pass 1: all objects exist off-tree, with no configure/start/reset calls.
	for id: String in ids:
		var record: Dictionary = snapshot["objects"][id]
		var value := _factory(record["kind"])
		if value is RunController: value.snapshot_passive = true
		if value is Node: value.process_mode = Node.PROCESS_MODE_DISABLED
		_objects.append(value)
		entities.register(value,id,record["generation"])
		_fields(value)
		if not _error.is_empty(): return _discard(_error)
	for id: String in snapshot["tombstones"]:
		var tombstone := entities.allocate_tombstone(id,snapshot["identity_generations"][id])
		if not tombstone["ok"]: return _discard(tombstone)
	entities.reserve_serial(snapshot["next_entity_serial"])
	_dead_proxies.clear()
	for id: String in snapshot["dead_references"]:
		var kind: String = snapshot["dead_references"][id]["kind"]
		var proxy: Node = (Node.new() if kind == "native:Node" else Node2D.new()) if kind.begins_with("native:") else _factory(kind)
		proxy.process_mode = Node.PROCESS_MODE_DISABLED
		_dead_proxies[id] = proxy
	_decoded_containers.clear()
	for id: String in snapshot["containers"]:
		var descriptor: Dictionary = snapshot["containers"][id]
		if descriptor["$"] == "array":
			_decoded_containers[id] = Array([],int(descriptor["type"]),StringName(descriptor["class"]),_typed_script(descriptor["script"]))
		else:
			_decoded_containers[id] = Dictionary({},int(descriptor["key_type"]),StringName(descriptor["key_class"]),_typed_script(descriptor["key_script"]),int(descriptor["value_type"]),StringName(descriptor["value_class"]),_typed_script(descriptor["value_script"]))
	var deferred_bindings: Array[Dictionary] = []
	for id: String in snapshot["containers"]:
		var descriptor: Dictionary = snapshot["containers"][id]
		var container: Variant = _decoded_containers[id]
		if descriptor["$"] == "array":
			for item: Variant in descriptor["items"]:
				var binding: bool = item is Dictionary and item.get("$") == "binding"
				var decoded: Variant = Callable() if binding else _decode(item)
				if not _container_accepts(decoded,int(descriptor["type"]),descriptor["class"],descriptor["script"]): return _discard(StableEntityRegistry.failure(&"invalid_payload","array element"))
				if binding: deferred_bindings.append({"container":id,"key":container.size(),"value":item})
				container.append(decoded)
		else:
			for pair: Array in descriptor["items"]:
				var key: Variant = _decode(pair[0])
				var binding: bool = pair[1] is Dictionary and pair[1].get("$") == "binding"
				var decoded: Variant = Callable() if binding else _decode(pair[1])
				if not _container_accepts(key,int(descriptor["key_type"]),descriptor["key_class"],descriptor["key_script"]) or not _container_accepts(decoded,int(descriptor["value_type"]),descriptor["value_class"],descriptor["value_script"]): return _discard(StableEntityRegistry.failure(&"invalid_payload","dictionary element"))
				if container.has(key): return _discard(StableEntityRegistry.failure(&"invalid_payload","duplicate dictionary key"))
				container[key] = decoded
				if binding: deferred_bindings.append({"container":id,"key":key,"value":pair[1]})
	for binding: Dictionary in deferred_bindings: _decoded_containers[binding["container"]][binding["key"]] = _decode(binding["value"])
	# Pass 2: restore backing state, then method bindings/signals. No setters
	# which recompose health/SP or reset a run are included in the manifest.
	var pending_fields: Dictionary = {}
	for id: String in ids:
		var value := entities.resolve(id)
		var record: Dictionary = snapshot["objects"][id]
		var fields: Dictionary = {}
		# Query once per object. Typed containers still compare against this
		# object's initial value, so instance-specific types are not cached.
		var properties := {}
		for property: Dictionary in value.get_property_list(): properties[property["name"]] = property
		for field: String in record["fields"]:
			var decoded: Variant = _decode(record["fields"][field])
			if value is RandomNumberGenerator:
				if not decoded is String or str(int(decoded)) != decoded: return _discard(StableEntityRegistry.failure(&"invalid_rng_state"))
				decoded = int(decoded)
			if not _assignable(value,field,decoded,properties): return _discard(StableEntityRegistry.failure(&"invalid_payload",record["kind"]+":"+field))
			fields[field] = decoded
		pending_fields[id] = fields
	if not _error.is_empty(): return _discard(_error)
	for id: String in ids:
		var value := entities.resolve(id)
		var record: Dictionary = snapshot["objects"][id]
		for field: String in _schema_fields(record["kind"]):
			var decoded: Variant = pending_fields[id][field]
			var previous: Variant = value.get(field)
			if previous is Node and is_instance_valid(previous) and previous != decoded and previous.get_parent() == null and entities.stable_for(previous.get_instance_id()).is_empty(): previous.free()
			if value is PlayerActor and field == "_sentinel_last_launch_frame": decoded = int(decoded) + Engine.get_process_frames()
			value.set(field,decoded)
		if value is ArenaNavigation: value._rebuild_grid()
		if value is Node:
			var node: Dictionary = record["node"]
			if not String(node["name"]).is_empty(): value.name = node["name"]
			if value is Node2D: value.transform = node["transform"]
			if value is Node2D:
				var canvas: Dictionary = node["canvas"]
				value.visible = canvas["visible"]; value.z_index = canvas["z"]; value.z_as_relative = canvas["relative_z"]; value.y_sort_enabled = canvas["y_sort"]; value.modulate = canvas["modulate"]; value.self_modulate = canvas["self_modulate"]; value.texture_filter = canvas["filter"]
			value.process_priority = node["priority"]
			value.process_physics_priority = node["physics_priority"]
			for name: StringName in _decode(node["meta"]): value.set_meta(name,_decode(node["meta"])[name])
			for group: StringName in node["groups"]: value.add_to_group(group)
	if not _error.is_empty(): return _discard(_error)
	var semantic := _validate_runtime_graph()
	if not semantic["ok"]: return _discard(semantic)
	for id: String in ids:
		var value := entities.resolve(id)
		var record: Dictionary = snapshot["objects"][id]
		for connection: Dictionary in record["signals"]:
			var callback: Callable = _decode(connection["binding"])
			if not value.has_signal(connection["signal"]) or not callback.is_valid(): return _discard(StableEntityRegistry.failure(&"checkpoint_incomplete","signal binding"))
			if not value.is_connected(connection["signal"], callback): value.connect(connection["signal"],callback,int(connection["flags"]))
	# Assemble the detached node tree last; _ready never runs in these passes.
	for id: String in ids:
		var value := entities.resolve(id)
		if not value is Node: continue
		var node: Dictionary = snapshot["objects"][id]["node"]
		if not String(node["parent"]).is_empty():
			var parent := entities.resolve(node["parent"]) as Node
			if parent == null or parent == value or value.is_ancestor_of(parent): return _discard(StableEntityRegistry.failure(&"dangling_entity_reference","parent cycle"))
			parent.add_child(value)
		value.set_process(node["process"])
		value.set_physics_process(node["physics"])
	# Keep sibling execution order even when nodes were moved after creation.
	# Disposable presentation siblings do not define simulation order.
	var parents: Dictionary = {}
	for id: String in ids:
		if not snapshot["objects"][id].has("node"): continue
		var node: Dictionary = snapshot["objects"][id]["node"]
		if String(node["parent"]).is_empty(): continue
		if not parents.has(node["parent"]): parents[node["parent"]] = []
		parents[node["parent"]].append({"id":id,"index":node["index"]})
	for id: String in parents:
		var children: Array = parents[id]
		children.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a["index"]) < int(b["index"]))
		var parent := entities.resolve(id) as Node
		for index: int in children.size(): parent.move_child(entities.resolve(children[index]["id"]),index)
	# Ownership keeps weak ledger roots and tombstones valid until the caller
	# transfers graph ownership. The host explicitly activates only after QA.
	var root := entities.resolve(snapshot["root"])
	# Preserve a destroyed direct reference as destroyed, including its aliases.
	# Keep the Variant type/liveness as well as aliases; the next tick uses
	# the same cached state as uninterrupted play. Proxies never enter a tree.
	_release_dead_proxies()
	root.set_meta(StableEntityRegistry.SCOPE_META,entities)
	if root is RunController: root.persistent_facade = facade
	var result := {"ok":true,"root":root,"entities":entities,"owners":_objects.duplicate(),"snapshot":snapshot,"restore_usec":Time.get_ticks_usec()-started}
	# The result owns hydration temporaries until activation, not this helper.
	_objects.clear(); _decoded_containers.clear()
	return result

func install(restored: Dictionary, parent: Node) -> Dictionary:
	if not restored.get("ok",false) or not is_instance_valid(parent) or not restored.get("root") is Node or restored["root"].is_inside_tree(): return StableEntityRegistry.failure(&"invalid_session")
	var root: Node = restored["root"]
	parent.add_child(root)
	if root is RunController:
		root.arena_view = ArenaView.new()
		root.arena_view.z_index = -2
		root.add_child(root.arena_view)
		root.arena_view.configure(root.navigation._bounds,root.navigation._obstacles)
		if root.campaign_runtime != null: root.arena_view.hide()
		root._create_runtime_camera()
		root._build_ui()
		if restored["snapshot"]["world_view"]:
			var view := ExpeditionGeometryView.new()
			root.add_child(view)
			var configured := view.configure(root.player.world_motion.geometry)
			if not configured["ok"]: return _abort_install(root,configured)
			var attached: Dictionary = root.attach_expedition_view(view,root.expedition_field_height)
			if not attached["ok"]: return _abort_install(root,attached)
	var modes: Array[Dictionary] = []
	_freeze_installed(root,restored["entities"],modes)
	restored["presentation_modes"] = modes
	restored["installed"] = true
	return {"ok":true}

func _freeze_installed(node: Node, identity_service: StableEntityRegistry, modes: Array[Dictionary]) -> void:
	if identity_service.stable_for(node.get_instance_id()).is_empty(): modes.append({"node":weakref(node),"mode":node.process_mode})
	for child: Node in node.get_children(true): _freeze_installed(child,identity_service,modes)
	node.process_mode = Node.PROCESS_MODE_DISABLED

func _abort_install(root: Node, reason: Dictionary) -> Dictionary:
	# Return the rejected scene detached and inert for its caller to discard.
	root.get_parent().remove_child(root)
	var ignored: Array[Dictionary] = []
	_freeze_installed(root,StableEntityRegistry.new(),ignored)
	return reason

func _assignable(owner: Object, field: String, value: Variant, properties: Dictionary) -> bool:
	if not properties.has(field): return false
	var property: Dictionary = properties[field]
	var expected := int(property["type"])
	if expected == TYPE_NIL: return true
	if value == null: return expected == TYPE_OBJECT
	if typeof(value) != expected and not (expected == TYPE_FLOAT and typeof(value) == TYPE_INT): return false
	if expected == TYPE_OBJECT:
		var name: String = property.get("class_name", "")
		if name.is_empty() or value.is_class(name): return true
		var script: Script = value.get_script()
		while script != null:
			if String(script.get_global_name()) == name: return true
			script = script.get_base_script()
		return false
	if value is Array:
		var initial: Array = owner.get(field)
		if not initial.is_typed(): return true
		return initial.get_typed_builtin() == value.get_typed_builtin() and initial.get_typed_class_name() == value.get_typed_class_name() and initial.get_typed_script() == value.get_typed_script()
	if value is Dictionary:
		var initial: Dictionary = owner.get(field)
		if not initial.is_typed(): return true
		return initial.get_typed_key_builtin() == value.get_typed_key_builtin() and initial.get_typed_key_class_name() == value.get_typed_key_class_name() and initial.get_typed_key_script() == value.get_typed_key_script() and initial.get_typed_value_builtin() == value.get_typed_value_builtin() and initial.get_typed_value_class_name() == value.get_typed_value_class_name() and initial.get_typed_value_script() == value.get_typed_value_script()
	return true

func _validate_runtime_graph() -> Dictionary:
	for value: Object in _objects:
		if value is WorldGeometry and not WorldGeometry._stage_prisms_valid(value._stage): return StableEntityRegistry.failure(&"invalid_payload", "terrain mass")
		if value is ExpeditionCampaignRuntime and not value.valid(): return StableEntityRegistry.failure(&"invalid_payload", "campaign state")
		if value is ThreatService and not value.valid(): return StableEntityRegistry.failure(&"invalid_payload", "threat state")
		if value is HealthState and (value.damage_sequence < 0 or value.heal_sequence < 0): return StableEntityRegistry.failure(&"invalid_payload", "health sequence")
		if value is EnemyActor:
			if not value.patrol_valid(): return StableEntityRegistry.failure(&"invalid_payload", "patrol state")
			if value.threat == null or value.threat_taunt_sequence < 0: return StableEntityRegistry.failure(&"invalid_payload", "threat binding")
			for id: String in value.threat_actors:
				if not value.threat.participants.has(id) or not is_instance_valid(value.threat_actors[id]): return StableEntityRegistry.failure(&"invalid_payload", "threat actor")
		if value is CombatParticipation and not value.valid(): return StableEntityRegistry.failure(&"invalid_payload", "combat participation")
		if value is BuildSnapshot:
			if value.catalog_version != ProfileState.CATALOG_VERSION or value.ruleset_id != ProfileState.RULESET_ID: return StableEntityRegistry.failure(&"content_revision_unavailable")
		if value is CombatActor:
			if value.health == null or value.stat_breakdown == null or value.health.actor_id != value.get_instance_id(): return StableEntityRegistry.failure(&"checkpoint_incomplete","actor identity/health")
			if not is_finite(value.health.max_hp) or value.health.max_hp <= 0 or not is_finite(value.health._hp_deficit) or value.health._hp_deficit < 0: return StableEntityRegistry.failure(&"invalid_payload","health deficit")
		if value is PlayerActor:
			if value.run_state == null or not is_finite(value.max_sp) or value.max_sp < 0 or not is_finite(value._sp_deficit) or value._sp_deficit < 0: return StableEntityRegistry.failure(&"invalid_payload","SP deficit")
			if not is_finite(value.active_cast_remaining) or value.active_cast_remaining < 0 or not is_finite(value.active_cast_total) or value.active_cast_total < value.active_cast_remaining: return StableEntityRegistry.failure(&"invalid_payload","cast clock")
		if value is EffectProcLedger.RootBudget:
			if value.owner_id <= 0 or value.next_event_id < 1 or value.used < 0 or value.used != value.claims.size() or value.used > value.application_limit: return StableEntityRegistry.failure(&"invalid_payload","causal claims")
			if not value.plan.is_empty():
				if not EffectProcLedger.validate_plan(value.plan)["ok"] or value.targets.size() != value.plan["targets"].size() or value.carriers.size() != value.plan["carriers"].size() or value.application_limit != (value.families.size()+value.carriers.size())*value.targets.size(): return StableEntityRegistry.failure(&"invalid_payload","causal plan: checked=%s targets=%s carriers=%s families=%s size=%d limit=%d" % [EffectProcLedger.validate_plan(value.plan),value.plan["targets"],value.plan["carriers"],value.plan["families"],value.plan.size(),value.application_limit])
				for key: String in ["families","targets","carriers"]:
					for member: Variant in value.plan[key]:
						if not value.get(key).has(member): return StableEntityRegistry.failure(&"invalid_payload","causal domain")
			for event: Variant in value.applied:
				if typeof(event) != TYPE_INT or event <= 0 or event >= value.next_event_id: return StableEntityRegistry.failure(&"invalid_payload","applied causal event")
		if value is CombatEventContext:
			if not value._budget is EffectProcLedger.RootBudget or value.event_id < 0 or value.event_id >= value._budget.next_event_id: return StableEntityRegistry.failure(&"dangling_entity_reference","causal envelope")
	return {"ok":true}

func _container_accepts(value: Variant, builtin: int, class_name_value: String, script_path: String) -> bool:
	if builtin == TYPE_NIL: return true
	if value == null: return builtin == TYPE_OBJECT
	if typeof(value) != builtin: return builtin == TYPE_FLOAT and typeof(value) == TYPE_INT
	if builtin != TYPE_OBJECT: return true
	if not class_name_value.is_empty() and not value.is_class(class_name_value): return false
	if script_path.is_empty(): return true
	var script: Script = value.get_script()
	while script != null:
		if script.resource_path == script_path: return true
		script = script.get_base_script()
	return false

func activate(restored: Dictionary) -> Dictionary:
	if not restored.get("ok",false): return StableEntityRegistry.failure(&"checkpoint_incomplete")
	var root: Node = restored["root"]
	if root is RunController and (not restored.get("installed",false) or not root.is_inside_tree()): return StableEntityRegistry.failure(&"invalid_session")
	if restored.get("activated",false): return {"ok":true,"already_active":true}
	for id: String in restored["snapshot"]["objects"]:
		var value: Object = restored["entities"].resolve(id)
		if value is Node: value.process_mode = int(restored["snapshot"]["objects"][id]["node"]["mode"])
	for entry: Dictionary in restored.get("presentation_modes",[]):
		var node: Node = entry["node"].get_ref()
		if is_instance_valid(node): node.process_mode = entry["mode"]
	if root is RunController: root.snapshot_passive = false
	restored["activated"] = true
	restored.erase("presentation_modes")
	# Release temporary graph ownership: a weak root must retire when its last
	# real envelope retires, just as in uninterrupted execution.
	restored["owners"].clear()
	_objects.clear()
	_decoded_containers.clear()
	return {"ok":true}

func _discard(reason: Dictionary) -> Dictionary:
	_release_dead_proxies()
	for value: Object in _objects:
		if is_instance_valid(value) and value is Node and value.get_parent() == null: value.free()
	_objects.clear()
	return reason

func _release_dead_proxies() -> void:
	for proxy: Node in _dead_proxies.values():
		if is_instance_valid(proxy): proxy.free()
	_dead_proxies.clear()

func _typed_script(path: String) -> Script:
	return load(path) as Script if not path.is_empty() and schemas.has(path) else null

func _decode(value: Variant) -> Variant:
	if not value is Dictionary or not value.has("$"): return value
	match value["$"]:
		"dead_reference": return _dead_proxies[value["id"]]
		"container": return _decoded_containers[value["id"]]
		"object": return entities.resolve(value["id"])
		"identity": return entities.local_for(value["id"]) if not String(value["id"]).is_empty() else 0
		"identity_string":
			var parts: PackedStringArray = []
			for part: Variant in value["parts"]: parts.append(str(_decode(part)))
			var result := "".join(parts)
			return StringName(result) if value["name"] else result
		"asset": return load(value["path"])
		"weak":
			var target: Variant = _decode(value["target"])
			return weakref(target) if is_instance_valid(target) else WeakRef.new()
		"rng":
			var rng := RandomNumberGenerator.new()
			rng.seed = int(value["seed"])
			rng.state = int(value["state"])
			return rng
		"binding":
			if String(value["target"]).is_empty(): return Callable()
			var owner := entities.resolve(value["target"])
			if owner == null or not owner.has_method(value["method"]): _fail(&"checkpoint_incomplete","method binding"); return Callable()
			var callback := Callable(owner,value["method"])
			if int(value["unbound"]) > 0: callback = callback.unbind(value["unbound"])
			return callback.bindv(_decode(value["args"]))
		"array":
			var result: Array = Array([],int(value["type"]),StringName(value["class"]),_typed_script(value["script"]))
			for item: Variant in value["items"]: result.append(_decode(item))
			return result
		"dictionary":
			var result: Dictionary = Dictionary({},int(value["key_type"]),StringName(value["key_class"]),_typed_script(value["key_script"]),int(value["value_type"]),StringName(value["value_class"]),_typed_script(value["value_script"]))
			for pair: Array in value["items"]: result[_decode(pair[0])] = _decode(pair[1])
			return result
	_fail(&"invalid_payload","unknown value tag")
	return null
