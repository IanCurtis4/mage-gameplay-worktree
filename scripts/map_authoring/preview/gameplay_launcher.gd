@tool
extends RefCounted
## Each process owns an explicit disposable profile. Stop is a tokened request.
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const SCENE := "res://scenes/map_authoring/gameplay_preview.tscn"
const ROOTS := ["res://.godot/map_authoring/play","user://map_authoring/play"]
var session_path := ""
var process_id := -1

static func normalized(path: String) -> String:
	return ProjectSettings.globalize_path(path).replace("\\","/").simplify_path()

static func token_valid(token: String) -> bool:
	if token.length() != 24: return false
	for index: int in token.length():
		if token.substr(index,1) not in "0123456789abcdef": return false
	return true

static func create_session(candidate: Dictionary, class_id: String = "swordsman", root_path: String = ROOTS[0]) -> Dictionary:
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

static func resolve(path: String) -> Dictionary:
	var target := normalized(path); var directory := target.get_base_dir(); var token := directory.get_file()
	if target.get_file() != "session.bin" or not token_valid(token): return Candidate.fail("candidate_invalid")
	var base := directory.get_base_dir().get_base_dir()
	if directory.get_base_dir().get_file() != "sessions": return Candidate.fail("candidate_invalid")
	var allowed := false
	for root_path: String in ROOTS:
		if base.nocasecmp_to(normalized(root_path)) == 0: allowed = true
	if not allowed: return Candidate.fail("candidate_invalid")
	var file := FileAccess.open(target,FileAccess.READ)
	if file == null or file.get_length() > 2048: return Candidate.fail("candidate_invalid")
	var decoded: Variant = bytes_to_var(file.get_buffer(file.get_length())); file.close()
	if not decoded is Dictionary or decoded.size() != 4 or not decoded.has_all(["format_version","session_id","class_id","candidate_hash"]): return Candidate.fail("candidate_invalid")
	if decoded.format_version != 1 or decoded.session_id != token or not decoded.candidate_hash is String or decoded.candidate_hash.length() != 64 or not decoded.candidate_hash.is_valid_hex_number(false): return Candidate.fail("candidate_invalid")
	if not decoded.class_id is String or not IdentityIds.is_base_class(StringName(decoded.class_id)): return Candidate.fail("candidate_invalid")
	var read := Candidate.read(base.path_join("candidates").path_join(decoded.candidate_hash+".bin"))
	if not read.ok or read.candidate.candidate_hash != decoded.candidate_hash: return Candidate.fail("candidate_invalid")
	return {"ok":true,"path":target,"session":decoded,"directory":directory,"candidate":read.candidate}

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
	if DirAccess.dir_exists_absolute(lock):
		if not FileAccess.file_exists(lock.path_join("pid.txt")): return {"ok":false,"code":"preview_busy"}
		var pid_text := FileAccess.get_file_as_string(lock.path_join("pid.txt"))
		# Conservatively refuse a reused live PID. Never terminate it.
		if not pid_text.is_valid_int() or OS.is_process_running(int(pid_text)): return {"ok":false,"code":"preview_busy","message":"Esta sessão já está aberta ou requer recuperação."}
		if DirAccess.remove_absolute(lock.path_join("pid.txt")) != OK or DirAccess.remove_absolute(lock) != OK: return Candidate.fail("candidate_io")
	if DirAccess.make_dir_absolute(lock) != OK: return {"ok":false,"code":"preview_busy"}
	var owner := FileAccess.open(lock.path_join("pid.txt"),FileAccess.WRITE)
	if owner == null: DirAccess.remove_absolute(lock); return Candidate.fail("candidate_io")
	owner.store_string(str(OS.get_process_id())); owner.close()
	return {"ok":true}

static func release(resolved: Dictionary) -> void:
	var lock: String = resolved.directory.path_join("active.lock")
	if not FileAccess.file_exists(lock.path_join("pid.txt")) or FileAccess.get_file_as_string(lock.path_join("pid.txt")) != str(OS.get_process_id()): return
	DirAccess.remove_absolute(lock.path_join("pid.txt")); DirAccess.remove_absolute(lock)

func launch(kind: String, package: Dictionary, current_source_hash: String, class_id: String = "swordsman") -> Dictionary:
	var made := Candidate.create(kind,package,current_source_hash)
	if not made.ok: return made
	var created := create_session(made.candidate,class_id)
	if not created.ok: return created
	return open_session(created.path)

func open_session(path: String) -> Dictionary:
	var resolved := resolve(path)
	if not resolved.ok: return resolved
	if process_id > 0 and OS.is_process_running(process_id): return {"ok":false,"code":"preview_busy"}
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),SCENE,"--","--f9-session="+resolved.path])
	process_id = OS.create_process(OS.get_executable_path(),args)
	if process_id <= 0: return {"ok":false,"code":"preview_launch","message":"Não foi possível abrir a janela de teste."}
	session_path = resolved.path
	return {"ok":true,"session_path":session_path,"process_id":process_id}

func stop() -> Dictionary:
	var resolved := resolve(session_path)
	if not resolved.ok: return resolved
	return write_atomic(resolved.directory.path_join("stop.request"),resolved.session.session_id.to_utf8_buffer())

func state() -> Dictionary:
	var resolved := resolve(session_path)
	if not resolved.ok: return resolved
	var path: String = resolved.directory.path_join("status.json")
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"ok":true,"state":"starting"}
	if file.get_length() > 16384: return Candidate.fail("candidate_invalid")
	var raw: Variant = JSON.parse_string(file.get_as_text()); file.close()
	if not raw is Dictionary or raw.get("session_id") != resolved.session.session_id or raw.get("candidate_hash") != resolved.session.candidate_hash: return Candidate.fail("candidate_invalid")
	return {"ok":true,"state":raw}
