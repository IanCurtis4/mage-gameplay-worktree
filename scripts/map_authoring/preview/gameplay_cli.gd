extends SceneTree
## One bounded passive request file; GUI/AX use the same launcher and protocol.
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const Protocol = preload("res://scripts/map_authoring/preview/gameplay_protocol.gd")
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_store.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_store.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Patrols = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var result: Dictionary = {"ok":false,"code":"usage"}
	if args.size() == 1:
		var read := Protocol.read_json(args[0],16384)
		result = await execute(read.data) if read.ok else read
	print("F9_GAMEPLAY_CLI_RESULT "+ascii_json(result)); quit(0 if result.ok else 1)

static func shape(value: Dictionary, required: Array, optional: Array = []) -> bool:
	return value.has_all(required) and value.keys().all(func(key: Variant) -> bool: return key in required or key in optional)

func execute(request: Dictionary) -> Dictionary:
	if not request.get("command") is String: return {"ok":false,"code":"usage"}
	var client := Launcher.new()
	if request.command == "launch":
		if not shape(request,["command","kind","source_path","package_path"],["class_id","headless"]) or not request.kind is String or not request.source_path is String or not request.package_path is String or not request.get("class_id","swordsman") is String or not request.get("headless",false) is bool: return {"ok":false,"code":"arguments_invalid"}
		var source := Exchange.load_json(request.source_path)
		if not source.ok: return source
		var validated := Exchange.read(request.kind,source.data)
		if not validated.ok or not validated.get("valid",true): return {"ok":false,"code":"source_invalid"}
		var loaded: Dictionary; var hash_value := ""
		match request.kind:
			"map": loaded = Maps.load_package(request.package_path); hash_value = MapDocument.hash_source(source.data)
			"population": loaded = Population.load_package(request.package_path); hash_value = PopulationDocument.hash_source(source.data)
			"patrol": loaded = Patrols.load_package(request.package_path); hash_value = PatrolDocument.hash_source(source.data)
			_: return {"ok":false,"code":"candidate_kind"}
		if not loaded.ok: return loaded
		return client.launch(request.kind,loaded.package,hash_value,request.get("class_id","swordsman"),request.get("headless",false))
	if request.command == "resume":
		if not shape(request,["command","window_path"],["headless"]) or not request.window_path is String or not request.get("headless",false) is bool: return {"ok":false,"code":"arguments_invalid"}
		return client.resume_window(request.window_path,request.get("headless",false))
	if request.command in ["stop","inspect"]:
		if not shape(request,["command","window_path"]) or not request.window_path is String: return {"ok":false,"code":"arguments_invalid"}
		client.window_path = request.window_path
		return client.stop() if request.command == "stop" else client.state()
	if request.command == "reply":
		if not shape(request,["command","window_path","request_id"],["session_id","fingerprint"]) or not request.window_path is String or not request.request_id is String or not request.get("session_id","") is String or not request.get("fingerprint","") is String: return {"ok":false,"code":"arguments_invalid"}
		client.window_path = request.window_path
		return completed(client.poll_reply(request.request_id,request.get("session_id",""),request.get("fingerprint","")))
	if request.command == "action":
		if not shape(request,["command","window_path","action"],["session_id","request_id","wait"]) or not request.window_path is String or not request.action is Dictionary or not request.get("session_id","") is String or not request.get("request_id","") is String or not request.get("wait",true) is bool: return {"ok":false,"code":"arguments_invalid"}
		client.window_path = request.window_path
		var posted := client.request_action(request.action,request.get("session_id",""),request.get("request_id",""))
		if not posted.ok or not request.get("wait",true) or not posted.pending: return completed(posted)
		var deadline := Time.get_ticks_msec()+90000
		while Time.get_ticks_msec() < deadline:
			var read := client.poll_reply(posted.request_id,posted.session_id,posted.fingerprint)
			if not read.ok or not read.pending: return completed(read)
			await create_timer(0.05).timeout
		return {"ok":false,"code":"reply_pending","request":posted}
	return {"ok":false,"code":"usage"}

static func completed(value: Dictionary) -> Dictionary:
	# Transport completion and gameplay acceptance are distinct; process exit follows gameplay.
	if value.get("ok",false) and not value.get("pending",true) and value.get("reply") is Dictionary:
		value = value.duplicate(true); value.ok = value.reply.result.ok
	return value

static func ascii_json(value: Dictionary) -> String:
	# Native process readers may use an OEM code page on Windows. JSON escapes
	# preserve every Unicode path without depending on that console encoding.
	var source := JSON.stringify(value,"",true,true); var encoded := ""
	for index: int in source.length():
		var code := source.unicode_at(index)
		if code <= 127: encoded += source[index]
		elif code <= 65535: encoded += "\\u%04x"%code
		else:
			code -= 65536; encoded += "\\u%04x\\u%04x"%[55296+(code>>10),56320+(code&1023)]
	return encoded
