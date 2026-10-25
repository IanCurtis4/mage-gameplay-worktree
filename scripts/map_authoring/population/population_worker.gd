@tool
extends RefCounted
## The editor never executes non-tool gameplay Resources as placeholder instances.
## A local script process runs the same compiler; only passive data crosses this boundary.
static func request(payload: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	var root := ProjectSettings.globalize_path("res://.godot/map_authoring/jobs/"+Crypto.new().generate_random_bytes(12).hex_encode())
	if DirAccess.make_dir_recursive_absolute(root) != OK: return failure("worker_io")
	var request_path := root.path_join("request.json"); var response_path := root.path_join("response.bin")
	var file := FileAccess.open(request_path,FileAccess.WRITE)
	if file == null: return failure("worker_io")
	file.store_string(JSON.stringify(payload,"",true,true)); file.close()
	if cancel.is_valid() and cancel.call(): return failure("cancelled")
	var pid := OS.create_process(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--log-file",root.path_join("engine.log"),"--script","res://scripts/map_authoring/population/worker_headless.gd","--",request_path,response_path],false)
	if pid < 0: return failure("worker_start_failed")
	var started := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		if cancel.is_valid() and cancel.call(): OS.kill(pid); return failure("cancelled")
		if Time.get_ticks_msec()-started > 180000: OS.kill(pid); return failure("worker_timeout")
		OS.delay_msec(20)
	var log_text := FileAccess.get_file_as_string(root.path_join("engine.log")) if FileAccess.file_exists(root.path_join("engine.log")) else ""
	if "SCRIPT ERROR:" in log_text or "Parse Error:" in log_text or "ERROR:" in log_text: return failure("worker_error")
	if not FileAccess.file_exists(response_path): return failure("worker_incomplete")
	var reader := FileAccess.open(response_path,FileAccess.READ)
	if reader == null or reader.get_length() > 32*1024*1024: return failure("worker_io")
	var result: Variant = bytes_to_var(reader.get_buffer(reader.get_length()))
	if not result is Dictionary or not result.get("ok") is bool: return failure("worker_invalid_response")
	return result
static func failure(code: String) -> Dictionary:
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"entity_id":"","field":"worker","message":{"cancelled":"Operação cancelada.","worker_timeout":"O trabalho atingiu o limite de três minutos.","worker_error":"O processo de validação relatou um erro; consulte o log em .godot/map_authoring/jobs."}.get(code,"Não foi possível concluir o processo de validação local."),"severity":"error"}]}
