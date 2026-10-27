@tool
extends RefCounted
## Authoring preferences only. Never part of a source hash, run, or publication.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const SECTION := "ragrpg_map_editor"
const KEY := "authoring_library_v1"
const OPTIONS := ["mode","radius","strength","hardness","shape","material","target","end_height"]
const MODES := ["raise","lower","flatten","smooth","material","ramp"]
const RECOVERY_LIMIT := 16
static var _memory: Dictionary = {}
static var _reader: Callable
static var _writer: Callable
static var _recovery: Callable
static var _memory_valid: Dictionary = {}
static var _memory_backups: Dictionary = {}

static func install_storage(reader: Callable, writer: Callable, recovery: Callable = Callable()) -> void:
	_reader = reader; _writer = writer; _recovery = recovery

static func source_id(path: String) -> String:
	return "source:"+(path.to_lower() if OS.get_name() == "Windows" else path).sha256_text()

static func empty() -> Dictionary:
	return {"version":1,"favorites":[],"presets":[],"sources":[]}

static func _keys(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size(): return false
	for field: String in fields:
		if not value.has(field): return false
	return true

static func _text(value: Variant, maximum: int) -> bool:
	return value is String and not value.is_empty() and value.length() <= maximum

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high

static func _id(value: Variant) -> bool:
	if not _text(value,192): return false
	for c: String in value:
		if c not in "abcdefghijklmnopqrstuvwxyz0123456789_-:.": return false
	return true

static func valid_options(value: Variant) -> bool:
	return _keys(value,OPTIONS) and value.mode in MODES and value.shape in ["circle","square"] and value.material in ["grass","earth","sand","stone"] and _number(value.radius,1,512) and _number(value.strength,0,128) and _number(value.hardness,0,1) and _number(value.target,-512,512) and _number(value.end_height,-512,512)

static func valid_source(value: Variant) -> bool:
	if not _keys(value,["id","kind","path","name","document_id","revision","source_hash","byte_hash"]): return false
	if not _id(value.id) or not value.id.begins_with("source:") or value.kind not in ["piece","map"] or not _text(value.path,4096) or not value.path.is_absolute_path() or not _text(value.name,65536) or not _id(value.document_id) or not _number(value.revision,1,2147483647) or value.revision != floor(value.revision): return false
	for field: String in ["source_hash","byte_hash"]:
		if not value[field] is String or value[field].length() != 64 or not value[field].is_valid_hex_number(false): return false
	return value.id == source_id(value.path)

static func validate(data: Variant) -> bool:
	if not _keys(data,["version","favorites","presets","sources"]) or not _number(data.version,1,1) or not data.favorites is Array or not data.presets is Array or not data.sources is Array or data.favorites.size() > 512 or data.presets.size() > 64 or data.sources.size() > 256: return false
	var seen := {}
	for id: Variant in data.favorites:
		if not _id(id) or seen.has(id): return false
		seen[id] = true
	seen = {}
	for preset: Variant in data.presets:
		if not _keys(preset,["id","name","options"]) or not _id(preset.id) or not preset.id.begins_with("custom_") or seen.has(preset.id) or not _text(preset.name,80) or preset.name.strip_edges().is_empty() or not valid_options(preset.options): return false
		seen[preset.id] = true
	seen = {}
	for source: Variant in data.sources:
		if not valid_source(source) or seen.has(source.id): return false
		seen[source.id] = true
	return JSON.stringify(data,"",true,true).to_utf8_buffer().size() <= 1024*1024

static func digest(data: Dictionary) -> String:
	var normalized := data.duplicate(true)
	normalized.favorites.sort()
	for key: String in ["presets","sources"]: normalized[key].sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.id < b.id)
	return Schema.bytes_hash(JSON.stringify(normalized,"",true,true).to_utf8_buffer())

static func read() -> Dictionary:
	var raw: Variant = _reader.call(empty()) if _reader.is_valid() else (_memory if not _memory.is_empty() else empty())
	if not validate(raw): return {"ok":false,"code":"preferences_invalid"}
	return {"ok":true,"data":raw.duplicate(true),"hash":digest(raw)}

static func write(data: Dictionary, expected_hash: String) -> Dictionary:
	if not validate(data): return {"ok":false,"code":"preferences_invalid"}
	var current := read()
	if not current.ok: return current
	if current.hash != expected_hash: return {"ok":false,"code":"preferences_stale"}
	if _writer.is_valid(): _writer.call(data.duplicate(true))
	else: _memory = data.duplicate(true); _memory_valid = data.duplicate(true)
	return {"ok":true,"data":data.duplicate(true),"hash":digest(data),"storage":"editor_project_metadata" if _writer.is_valid() else "headless_memory"}

static func apply(data: Dictionary, request: Dictionary) -> Dictionary:
	if not validate(data): return {"ok":false,"code":"preferences_invalid"}
	var output := data.duplicate(true)
	match request.get("operation",""):
		"favorite":
			if not _keys(request,["operation","id","enabled"]) or not _id(request.id) or not request.enabled is bool: return {"ok":false,"code":"library_request_invalid"}
			output.favorites.erase(request.id)
			if request.enabled: output.favorites.append(request.id)
		"preset_save":
			if not _keys(request,["operation","preset"]): return {"ok":false,"code":"library_request_invalid"}
			var preset: Variant = request.preset
			if not _keys(preset,["id","name","options"]) or not _id(preset.id): return {"ok":false,"code":"library_request_invalid"}
			output.presets = output.presets.filter(func(entry: Dictionary) -> bool: return entry.id != preset.id)
			output.presets.append(preset.duplicate(true))
		"preset_remove":
			if not _keys(request,["operation","id"]) or not _id(request.id) or not request.id.begins_with("custom_"): return {"ok":false,"code":"library_request_invalid"}
			output.presets = output.presets.filter(func(entry: Dictionary) -> bool: return entry.id != request.id)
		"source_register":
			if not _keys(request,["operation","entry"]) or not valid_source(request.entry): return {"ok":false,"code":"library_request_invalid"}
			var canonical: String = request.entry.path.replace("\\","/").simplify_path()
			var starred: bool = request.entry.id in output.favorites
			for prior: Dictionary in output.sources:
				if prior.path.replace("\\","/").simplify_path() != canonical: continue
				starred = starred or prior.id in output.favorites; output.favorites.erase(prior.id)
			output.sources = output.sources.filter(func(entry: Dictionary) -> bool: return entry.id != request.entry.id and entry.path.replace("\\","/").simplify_path() != canonical)
			output.sources.append(request.entry.duplicate(true))
			if starred and request.entry.id not in output.favorites: output.favorites.append(request.entry.id)
		"source_remove":
			if not _keys(request,["operation","id"]) or not _id(request.id): return {"ok":false,"code":"library_request_invalid"}
			output.sources = output.sources.filter(func(entry: Dictionary) -> bool: return entry.id != request.id)
			output.favorites.erase(request.id)
		_: return {"ok":false,"code":"library_request_invalid"}
	if not validate(output): return {"ok":false,"code":"library_limit_or_value_invalid"}
	output.favorites.sort()
	for key: String in ["presets","sources"]: output[key].sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.id < b.id)
	return {"ok":true,"data":output,"hash":digest(output)}

static func transact(request: Dictionary, expected_hash: String = "") -> Dictionary:
	var current := read()
	if not current.ok: return current
	if not expected_hash.is_empty() and current.hash != expected_hash: return {"ok":false,"code":"preferences_stale"}
	var changed := apply(current.data,request)
	return write(changed.data,current.hash) if changed.ok else changed

static func recovery_preview() -> Dictionary:
	var raw: Variant = _reader.call(empty()) if _reader.is_valid() else (_memory if not _memory.is_empty() else empty())
	if validate(raw): return {"ok":false,"code":"preferences_recovery_not_needed"}
	var proposed: Dictionary = _recovery.call(raw,false) if _recovery.is_valid() else {"ok":true,"data":_memory_valid.duplicate(true) if validate(_memory_valid) else empty()}
	if not proposed.ok: return proposed
	if not validate(proposed.get("data")): return {"ok":false,"code":"preferences_recovery_invalid"}
	proposed["expected_hash"] = Schema.bytes_hash(var_to_bytes(raw)); return proposed

static func recover(expected_hash: String) -> Dictionary:
	var preview := recovery_preview()
	if not preview.ok: return preview
	if preview.expected_hash != expected_hash: return {"ok":false,"code":"preferences_stale"}
	var raw: Variant = _reader.call(empty()) if _reader.is_valid() else _memory
	if Schema.bytes_hash(var_to_bytes(raw)) != expected_hash: return {"ok":false,"code":"preferences_stale"}
	var copied: Dictionary
	if _recovery.is_valid(): copied = _recovery.call(raw,true)
	else:
		if _memory_backups.size() >= RECOVERY_LIMIT: return {"ok":false,"code":"preferences_recovery_limit"}
		var id := "recovery_"+str(Time.get_ticks_usec()); _memory_backups[id] = raw.duplicate(true) if raw is Dictionary or raw is Array else raw
		copied = {"ok":true,"backup_id":id,"data":preview.data}
	if not copied.ok: return copied
	if not validate(copied.get("data")): return {"ok":false,"code":"preferences_recovery_invalid"}
	if _writer.is_valid(): _writer.call(copied.data.duplicate(true))
	else: _memory = copied.data.duplicate(true); _memory_valid = _memory.duplicate(true)
	return {"ok":true,"backup_id":copied.backup_id,"data":copied.data.duplicate(true),"hash":digest(copied.data)}
