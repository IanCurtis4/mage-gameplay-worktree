@tool
extends RefCounted
## Each process owns an explicit disposable profile. Stop is a tokened request.
const Protocol = preload("res://scripts/map_authoring/preview/gameplay_protocol.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const SCENE := "res://scenes/map_authoring/gameplay_preview.tscn"
const ROOTS := ["res://.godot/map_authoring/play","user://map_authoring/play"]
var session_path := ""
var window_path := ""
var process_id := -1

static func normalized(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\","/").simplify_path()

static func token_valid(token: String) -> bool:
	return Protocol.token_valid(token)

static func create_session(candidate: Dictionary, class_id: String = "swordsman", root_path: String = "") -> Dictionary:
	if root_path.is_empty(): root_path = ROOTS[0] if OS.has_feature("editor") else ROOTS[1]
	if not Candidate.valid(candidate): return Candidate.fail("candidate_invalid")
	if root_path not in ROOTS or not IdentityIds.is_base_class(StringName(class_id)): return Candidate.fail("candidate_invalid")
	var base := normalized(root_path)
	var published := Candidate.publish(candidate,base.path_join("candidates"))
	if not published.ok: return published
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	var directory := base.path_join("sessions").path_join(token)
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return Candidate.fail("candidate_io")
	var descriptor := {"format_version":1,"session_id":token,"class_id":class_id,"candidate_hash":candidate.candidate_hash}
	var target := directory.path_join("session.bin")
	var saved := write_atomic(target,var_to_bytes(descriptor))
	if not saved.ok: return saved
	return {"ok":true,"path":target,"session":descriptor,"directory":directory,"candidate":candidate}

static func _namespace(path: String, folder: String, filename: String) -> Dictionary:
	var target := normalized(path); var directory := target.get_base_dir(); var token := directory.get_file()
	if target.get_file() != filename or not token_valid(token): return Candidate.fail("candidate_invalid")
	var base := directory.get_base_dir().get_base_dir()
	if directory.get_base_dir().get_file() != folder: return Candidate.fail("candidate_invalid")
	var allowed := ""
	for root_path: String in ROOTS:
		if base.nocasecmp_to(normalized(root_path)) == 0: allowed = root_path
	if allowed.is_empty(): return Candidate.fail("candidate_invalid")
	return {"ok":true,"path":target,"directory":directory,"base_path":base,"root_path":allowed,"token":token}

static func _descriptor(path: String, limit: int) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > limit: return Candidate.fail("candidate_invalid")
	var decoded: Variant = bytes_to_var(file.get_buffer(file.get_length())); file.close()
	if not decoded is Dictionary or not ExpeditionCanonical.valid(decoded): return Candidate.fail("candidate_invalid")
	return {"ok":true,"data":decoded}

static func session_header(path: String) -> Dictionary:
	var result := _namespace(path,"sessions","session.bin")
	if not result.ok: return result
	var read := _descriptor(result.path,2048)
	if not read.ok: return read
	var decoded: Dictionary = read.data
	if decoded.size() != 4 or not decoded.has_all(["format_version","session_id","class_id","candidate_hash"]): return Candidate.fail("candidate_invalid")
	if decoded.format_version != 1 or decoded.session_id != result.token or not _hash(decoded.candidate_hash): return Candidate.fail("candidate_invalid")
	if not decoded.class_id is String or not IdentityIds.is_base_class(StringName(decoded.class_id)): return Candidate.fail("candidate_invalid")
	result["session"] = decoded
	return result

static func _hash(value: Variant) -> bool:
	return value is String and value.length() == 64 and value.is_valid_hex_number(false)

static func resolve(path: String) -> Dictionary:
	var result := session_header(path)
	if not result.ok: return result
	var read := Candidate.read(String(result.base_path).path_join("candidates").path_join(result.session.candidate_hash+".bin"))
	if not read.ok or read.candidate.candidate_hash != result.session.candidate_hash: return Candidate.fail("candidate_invalid")
	result["candidate"] = read.candidate
	return result

static func create_window(session_file: String) -> Dictionary:
	var run := session_header(session_file)
	if not run.ok: return run
	var token := Crypto.new().generate_random_bytes(12).hex_encode()
	var directory: String = String(run.base_path).path_join("windows").path_join(token)
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return Candidate.fail("candidate_io")
	var descriptor := {"format_version":1,"window_id":token,"candidate_hash":run.session.candidate_hash,"initial_session":run.path}
	var path := directory.path_join("window.bin")
	var written := write_atomic(path,var_to_bytes(descriptor))
	if not written.ok: return written
	return window_header(path)

static func window_header(path: String) -> Dictionary:
	var result := _namespace(path,"windows","window.bin")
	if not result.ok: return result
	var read := _descriptor(result.path,4096)
	if not read.ok: return read
	var descriptor: Dictionary = read.data
	if descriptor.size() != 4 or not descriptor.has_all(["format_version","window_id","candidate_hash","initial_session"]): return Candidate.fail("candidate_invalid")
	if descriptor.format_version != 1 or descriptor.window_id != result.token or not _hash(descriptor.candidate_hash) or not descriptor.initial_session is String: return Candidate.fail("candidate_invalid")
	var run := session_header(descriptor.initial_session)
	if not run.ok or run.base_path != result.base_path or run.session.candidate_hash != descriptor.candidate_hash: return Candidate.fail("candidate_invalid")
	result["window"] = descriptor
	return result

static func claim_window(window: Dictionary) -> Dictionary:
	var marker: String = String(window.directory).path_join("started.token")
	if FileAccess.file_exists(marker): return {"ok":false,"code":"window_consumed","message":"Esta janela já foi usada. Abra uma janela nova para retomar o teste."}
	var held := claim(window)
	if not held.ok: return held
	if FileAccess.file_exists(marker): release(window); return {"ok":false,"code":"window_consumed"}
	var saved := write_atomic(marker,String(window.window.window_id).to_utf8_buffer())
	if not saved.ok: release(window)
	return saved

static func window_state(path: String) -> Dictionary:
	var window := window_header(path)
	if not window.ok: return window
	var status_path: String = String(window.directory).path_join("status.json")
	if not FileAccess.file_exists(status_path): return {"ok":true,"state":{"state":"starting","current_session_path":window.window.initial_session,"candidate_hash":window.window.candidate_hash,"window_id":window.window.window_id}}
	var file := FileAccess.open(status_path,FileAccess.READ)
	# The window replaces status.json atomically; a reader can briefly lose that race on Windows.
	for attempt: int in 3:
		if file != null or not FileAccess.file_exists(status_path): break
		OS.delay_msec(5); file = FileAccess.open(status_path,FileAccess.READ)
	if file == null or file.get_length() > 128*1024: return Candidate.fail("candidate_invalid")
	var raw: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if not raw is Dictionary or raw.get("window_id") != window.window.window_id or raw.get("candidate_hash") != window.window.candidate_hash or not raw.get("current_session_path") is String or not raw.get("state") is String: return Candidate.fail("candidate_invalid")
	var run := session_header(raw.current_session_path)
	if not run.ok or run.base_path != window.base_path or run.session.candidate_hash != window.window.candidate_hash: return Candidate.fail("candidate_invalid")
	return {"ok":true,"state":raw}

static func write_atomic(path: String, bytes: PackedByteArray) -> Dictionary:
	var temporary := path+"."+Crypto.new().generate_random_bytes(12).hex_encode()+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return Candidate.fail("candidate_io")
	file.store_buffer(bytes); file.flush(); var error := file.get_error(); file.close()
	if error != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
		DirAccess.remove_absolute(temporary); return Candidate.fail("candidate_io")
	if DirAccess.rename_absolute(temporary,path) != OK:
		DirAccess.remove_absolute(temporary); return Candidate.fail("candidate_io")
	return {"ok":true}

static func claim(resolved: Dictionary) -> Dictionary:
	var lock: String = resolved.directory.path_join("active.lock")
	# A foreign PID is not observable with OS.is_process_running on Windows.
	# An existing lease is conservatively busy, including after a crash. Only
	# its tokened owner releases it; explicit recovery must preserve old data.
	if DirAccess.dir_exists_absolute(lock): return {"ok":false,"code":"preview_busy","message":"Esta sessão já está aberta ou requer recuperação."}
	if DirAccess.make_dir_absolute(lock) != OK: return {"ok":false,"code":"preview_busy"}
	var owner := FileAccess.open(lock.path_join("pid.txt"),FileAccess.WRITE)
	if owner == null: DirAccess.remove_absolute(lock); return Candidate.fail("candidate_io")
	owner.store_string(str(OS.get_process_id())); owner.close()
	return {"ok":true}

static func release(resolved: Dictionary) -> void:
	var lock: String = resolved.directory.path_join("active.lock")
	if not FileAccess.file_exists(lock.path_join("pid.txt")) or FileAccess.get_file_as_string(lock.path_join("pid.txt")) != str(OS.get_process_id()): return
	DirAccess.remove_absolute(lock.path_join("pid.txt")); DirAccess.remove_absolute(lock)

func launch(kind: String, package: Dictionary, current_source_hash: String, class_id: String = "swordsman", headless: bool = false, hold_start: bool = false) -> Dictionary:
	if running(): return {"ok":false,"code":"preview_busy"}
	var made := Candidate.create(kind,package,current_source_hash)
	if not made.ok: return made
	var created := create_session(made.candidate,class_id)
	if not created.ok: return created
	return open_session(created.path,headless,hold_start)

func running() -> bool:
	if window_path.is_empty(): return process_id > 0 and OS.is_process_running(process_id)
	var current := window_state(window_path)
	if current.ok and current.state.state == "closed": return false
	if process_id > 0 and OS.is_process_running(process_id): return true
	var window := window_header(window_path)
	if not window.ok: return false
	# A reloaded panel did not spawn this process and cannot probe its PID.
	return DirAccess.dir_exists_absolute(String(window.directory).path_join("active.lock"))

func open_session(path: String, headless: bool = false, hold_start: bool = false) -> Dictionary:
	if running(): return {"ok":false,"code":"preview_busy"}
	var resolved := resolve(path)
	if not resolved.ok: return resolved
	if DirAccess.dir_exists_absolute(String(resolved.directory).path_join("active.lock")): return {"ok":false,"code":"preview_busy"}
	var window := create_window(resolved.path)
	if not window.ok: return window
	var args := PackedStringArray()
	if headless: args.append("--headless")
	args.append_array(["--log-file",String(window.directory).path_join("engine.log")])
	if OS.has_feature("editor"): args.append_array(["--path",ProjectSettings.globalize_path("res://")])
	args.append_array([SCENE,"--","--f9-window="+window.path])
	# Human tests may keep the prepared world paused until "Iniciar teste".
	if hold_start: args.append("--f9-hold-start")
	process_id = OS.create_process(OS.get_executable_path(),args,false)
	if process_id <= 0: return {"ok":false,"code":"preview_launch","message":"Não foi possível abrir a janela de teste."}
	session_path = resolved.path; window_path = window.path
	return {"ok":true,"session_path":session_path,"window_path":window_path,"process_id":process_id}

func resume_window(path: String = "", headless: bool = false, hold_start: bool = false) -> Dictionary:
	if path.is_empty(): path = window_path
	var current := window_state(path)
	if not current.ok: return current
	return open_session(current.state.current_session_path,headless,hold_start)

func stop() -> Dictionary:
	if not window_path.is_empty():
		var window := window_header(window_path)
		if not window.ok: return window
		return write_atomic(String(window.directory).path_join("stop.request"),String(window.window.window_id).to_utf8_buffer())
	var resolved := session_header(session_path)
	if not resolved.ok: return resolved
	return write_atomic(String(resolved.directory).path_join("stop.request"),String(resolved.session.session_id).to_utf8_buffer())

func state() -> Dictionary:
	if not window_path.is_empty():
		var current := window_state(window_path)
		if current.ok: session_path = current.state.current_session_path
		return current
	var resolved := session_header(session_path)
	if not resolved.ok: return resolved
	var path: String = String(resolved.directory).path_join("status.json")
	if not FileAccess.file_exists(path): return {"ok":true,"state":{"state":"starting"}}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > 16384: return Candidate.fail("candidate_invalid")
	var raw: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if not raw is Dictionary or raw.get("session_id") != resolved.session.session_id or raw.get("candidate_hash") != resolved.session.candidate_hash: return Candidate.fail("candidate_invalid")
	return {"ok":true,"state":raw}

func request_action(action: Dictionary, expected_session_id: String = "", request_id: String = "") -> Dictionary:
	var window := window_header(window_path)
	if not window.ok: return window
	var current := window_state(window_path)
	if not current.ok: return current
	var run := session_header(current.state.current_session_path)
	if not run.ok: return run
	return Protocol.post(window,run,action,write_atomic,expected_session_id,request_id)

func poll_reply(request_id: String, session_id: String = "", fingerprint: String = "") -> Dictionary:
	var window := window_header(window_path)
	if not window.ok: return window
	return Protocol.read_reply(window,request_id,session_id,fingerprint)
