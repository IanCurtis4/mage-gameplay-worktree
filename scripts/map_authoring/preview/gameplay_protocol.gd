@tool
extends RefCounted
## Closed passive input protocol. No gameplay formulas or sender executables.
const Reader = preload("res://scripts/map_authoring/io/strict_json.gd")
const MAX_COMMAND_BYTES := 4096
const MAX_REPLY_BYTES := 128*1024
const MAX_RECEIPTS := 256

static func failure(code: String) -> Dictionary:
	return {"ok":false,"code":code}

static func token_valid(value: Variant) -> bool:
	if not value is String or value.length() != 24: return false
	for index: int in value.length():
		if value.substr(index,1) not in "0123456789abcdef": return false
	return true

static func _shape(value: Dictionary, keys: Array) -> bool:
	return value.size() == keys.size() and value.has_all(keys)

static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func _revision(value: Variant) -> bool:
	return _number(value) and value >= 0 and value <= 2147483647 and value == floor(value)

static func _text(value: Variant, limit: int = 256) -> bool:
	return value is String and not value.is_empty() and value.length() <= limit

static func action_valid(value: Dictionary) -> bool:
	if not value.get("kind") is String: return false
	match value.kind:
		"inspect","suspend","resume","restart","close": return _shape(value,["kind"])
		"interaction": return _shape(value,["kind","interaction_id"]) and _text(value.interaction_id)
		"collect": return _shape(value,["kind","ticket_id"]) and _text(value.ticket_id)
		"move","skill":
			var keys: Array = ["kind","position_xyz","geometry_revision"]
			if value.kind == "skill": keys.append_array(["skill_id","preview","rank"])
			if not _shape(value,keys) or not _revision(value.geometry_revision) or not value.position_xyz is Array or value.position_xyz.size() != 3: return false
			if not value.position_xyz.all(func(item: Variant) -> bool: return _number(item)): return false
			if value.kind == "skill" and (not _text(value.skill_id,128) or not value.preview is bool or not _revision(value.rank)): return false
			return true
	return false

static func normalize_action(value: Dictionary) -> Dictionary:
	var output := value.duplicate(true)
	if output.has("geometry_revision"): output.geometry_revision = int(output.geometry_revision)
	if output.has("rank"): output.rank = int(output.rank)
	if output.has("position_xyz"): output.position_xyz = output.position_xyz.map(func(item: Variant) -> float: return float(item))
	return output

static func fingerprint(session_id: String, value: Dictionary) -> String:
	return ExpeditionCanonical.digest({"session_id":session_id,"payload":normalize_action(value)})

static func envelope_valid(value: Dictionary) -> bool:
	return _shape(value,["format_version","window_id","session_id","request_id","payload"]) and _revision(value.format_version) and value.format_version == 1 and token_valid(value.window_id) and token_valid(value.session_id) and token_valid(value.request_id) and value.payload is Dictionary and action_valid(value.payload)

static func read_json(path: String, limit: int) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > limit: return failure("command_io")
	var bytes := file.get_buffer(file.get_length()); file.close()
	var decoded := Reader.new().decode(bytes)
	if not decoded.ok or not decoded.value is Dictionary: return failure("command_invalid")
	return {"ok":true,"data":decoded.value}

static func reply_path(window: Dictionary, request_id: String) -> String:
	return String(window.directory).path_join("reply_"+request_id+".json")

static func read_reply(window: Dictionary, request_id: String, session_id: String = "", expected_fingerprint: String = "") -> Dictionary:
	if not token_valid(request_id): return failure("command_invalid")
	var path := reply_path(window,request_id)
	if not FileAccess.file_exists(path): return {"ok":true,"pending":true}
	var read := read_json(path,MAX_REPLY_BYTES)
	if not read.ok: return read
	var data: Dictionary = read.data
	if not _shape(data,["format_version","window_id","session_id","request_id","fingerprint","result"]) or not _revision(data.format_version) or data.format_version != 1 or data.window_id != window.window.window_id or data.request_id != request_id or not token_valid(data.session_id) or not data.fingerprint is String or data.fingerprint.length() != 64 or not data.fingerprint.is_valid_hex_number(false) or not data.result is Dictionary or not data.result.get("ok") is bool: return failure("command_invalid")
	if (not session_id.is_empty() and data.session_id != session_id) or (not expected_fingerprint.is_empty() and data.fingerprint != expected_fingerprint): return failure("request_conflict")
	return {"ok":true,"pending":false,"reply":data}

static func post(window: Dictionary, run: Dictionary, value: Dictionary, writer: Callable, expected_session_id: String = "", request_id: String = "") -> Dictionary:
	if not action_valid(value): return failure("command_invalid")
	var session_id: String = run.session.session_id if expected_session_id.is_empty() else expected_session_id
	if not token_valid(session_id): return failure("command_invalid")
	if request_id.is_empty(): request_id = Crypto.new().generate_random_bytes(12).hex_encode()
	if not token_valid(request_id): return failure("command_invalid")
	var signature := fingerprint(session_id,value)
	var previous := read_reply(window,request_id,session_id,signature)
	if not previous.ok: return previous
	if not previous.pending: return {"ok":true,"request_id":request_id,"session_id":session_id,"fingerprint":signature,"pending":false,"reply":previous.reply}
	if session_id != run.session.session_id: return failure("command_stale")
	var envelope := {"format_version":1,"window_id":window.window.window_id,"session_id":session_id,"request_id":request_id,"payload":normalize_action(value)}
	var bytes := JSON.stringify(envelope,"",true,true).to_utf8_buffer()
	if bytes.size() > MAX_COMMAND_BYTES: return failure("command_limit")
	var lock: String = String(window.directory).path_join("command.writer_lock")
	if DirAccess.make_dir_absolute(lock) != OK: return failure("command_busy")
	var path: String = String(window.directory).path_join("command.request")
	var result: Dictionary
	if FileAccess.file_exists(path):
		var pending := read_json(path,MAX_COMMAND_BYTES)
		result = {"ok":true} if pending.ok and pending.data == envelope else failure("command_busy")
	else: result = writer.call(path,bytes)
	DirAccess.remove_absolute(lock)
	if not result.ok: return result
	return {"ok":true,"request_id":request_id,"session_id":session_id,"fingerprint":signature,"pending":true}
