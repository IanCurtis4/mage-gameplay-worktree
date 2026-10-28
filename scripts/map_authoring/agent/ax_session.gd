extends SceneTree
## Passive action transport. Every mutation goes through the real AX presentation.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
var shell: Control
var objects_panel: Control
var _capture_screen := "terrain"
var _request_path := ""
var _result_path := ""
var _capture_path := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ax-request=") and _request_path.is_empty(): _request_path = argument.trim_prefix("--ax-request=")
		elif argument.begins_with("--ax-result=") and _result_path.is_empty(): _result_path = argument.trim_prefix("--ax-result=")
		elif argument.begins_with("--ax-capture=") and _capture_path.is_empty(): _capture_path = argument.trim_prefix("--ax-capture=")
		else: _finish({"ok":false,"code":"arguments_invalid"}); return
	if _request_path.is_empty() or _result_path.is_empty() or _request_path == _result_path or _capture_path == _request_path or _capture_path == _result_path:
		_finish({"ok":false,"code":"arguments_invalid"}); return
	# Result/capture are new artifacts, never overwrite a previous recipe or result.
	if FileAccess.file_exists(_result_path) or (not _capture_path.is_empty() and FileAccess.file_exists(_capture_path)):
		print("F9_AX_SESSION_RESULT "+JSON.stringify({"ok":false,"code":"io_conflict"})); quit(1); return
	var request := _read_request()
	if not request.ok: _finish(request); return
	# This is an editor host; the game's fixed rendering resolution must not
	# shrink its UI texture independently of the native window dimensions.
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	root.size = Vector2i(1440,1000)
	shell = Shell.new()
	root.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await process_frame
	var piece: Node = shell.get_node("AuthoringPresentation")
	var terrain: Node = shell.terrain.get_node("AuthoringPresentation")
	piece.set_mode("ax")
	var outcomes: Array = []
	var ok := true
	for action: Dictionary in request.actions:
		var before: String = shell.session.document().semantic_hash()
		var outcome: Dictionary = {"ok":true}
		var presentation: Node = piece if action.screen == "piece" else terrain
		if action.screen == "objects":
			if objects_panel == null:
				outcome = piece.ax_invoke("piece/open_objects")
				await process_frame
				if outcome.ok and is_instance_valid(shell.objects_window): objects_panel = shell.objects_window.get_child(0)
				elif outcome.ok: outcome = {"ok":false,"code":"screen_missing"}
			if objects_panel != null: presentation = objects_panel.get_node("AuthoringPresentation")
			_capture_screen = "objects"
		elif action.screen == "terrain": _capture_screen = "terrain"
		if outcome.ok: outcome = presentation.ax_invoke(action.id,action.parameters)
		if outcome.get("ok",false) and action.screen == "terrain" and action.id == "terrain/compile_piece":
			# The GUI action starts its normal worker. Keep this client alive until
			# the panel publishes that worker's canonical, revision-checked result.
			var started := Time.get_ticks_msec()
			while shell.terrain.job != null and Time.get_ticks_msec()-started < 300000:
				await process_frame
			if shell.terrain.job != null:
				shell.terrain.job.cancel()
				outcome = {"ok":false,"code":"compile_timeout"}
			else: outcome = shell.terrain.result.duplicate(true)
		# Only the final snapshot carries the full source; keeping one copy per
		# stroke would make long, otherwise valid authoring batches grow quadratically.
		outcome.erase("data")
		outcome.erase("package")
		outcomes.append({"screen":action.screen,"id":action.id,"input_hash":before,"output_hash":shell.session.document().semantic_hash(),"result":outcome})
		if not outcome.get("ok",false): ok = false; break
		await process_frame
	var terrain_snapshot: Dictionary = terrain.ax_snapshot()
	terrain_snapshot.erase("source")
	terrain_snapshot.source_hash = shell.session.document().semantic_hash()
	var objects_snapshot: Dictionary = {}
	if objects_panel != null:
		objects_snapshot = objects_panel.get_node("AuthoringPresentation").ax_snapshot()
		objects_snapshot.erase("source"); objects_snapshot.source_hash = shell.session.document().semantic_hash()
		objects_snapshot.selected_ids = objects_panel.selected_ids.duplicate()
		objects_snapshot.selected_surface = objects_panel.surface_id()
		objects_snapshot.preview_hash = objects_panel.pending.get("proposal",{}).get("output_hash","")
	var response := {"objects_snapshot":objects_snapshot,"ok":ok,"code":"" if ok else "action_rejected","completed_actions":outcomes.size(),"requested_actions":request.actions.size(),"actions":outcomes,"source_hash":shell.session.document().semantic_hash(),"snapshot":piece.ax_snapshot(),"terrain_snapshot":terrain_snapshot,"state":{"selected_layer":shell.terrain.selected_layer,"can_undo":shell.session.can_undo(),"can_redo":shell.session.can_redo(),"dirty":shell.session.dirty(),"source_path":shell.source_path},"diagnostics":shell.session.document().diagnostics()}
	if not _capture_path.is_empty() and DisplayServer.get_name() == "headless":
		response.ok = false; response.code = "capture_requires_display"
	elif not _capture_path.is_empty():
		var canvas: Control = objects_panel.canvas if _capture_screen == "objects" and objects_panel != null else shell.terrain.canvas
		if _capture_screen != "objects" and is_instance_valid(shell.objects_window): shell.objects_window.hide()
		if _capture_screen == "objects" and objects_panel != null:
			shell.objects_window.show()
			shell.objects_window.position = Vector2i.ZERO
			shell.objects_window.size = root.size
		# Capture a useful terrain view through normal presentation controls.
		# This affects this client's viewport only, never the authored source.
		canvas.custom_minimum_size.y = maxf(canvas.custom_minimum_size.y,440.0)
		await process_frame
		var ancestor: Node = canvas.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(canvas)
			ancestor = ancestor.get_parent()
		await process_frame
		canvas.fit()
		await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(_capture_path) != OK: response.ok = false; response.code = "capture_failed"
	_finish(response)

func _read_request() -> Dictionary:
	if not FileAccess.file_exists(_request_path): return {"ok":false,"code":"io_missing"}
	var file := FileAccess.open(_request_path,FileAccess.READ)
	if file == null: return {"ok":false,"code":"io_failure"}
	if file.get_length() > StrictJSON.MAX_BYTES: return {"ok":false,"code":"source_limit_exceeded"}
	var decoded := StrictJSON.new().decode(file.get_buffer(file.get_length()))
	file.close()
	if not decoded.ok: return decoded
	var errors: Array = []
	Schema._shape(decoded.value,{"ax_version":"int","actions":"array"},"request",errors)
	if not errors.is_empty(): return {"ok":false,"code":"arguments_invalid"}
	var data: Dictionary = decoded.value
	if data.ax_version != 1 or data.actions.is_empty() or data.actions.size() > 4096: return {"ok":false,"code":"arguments_invalid"}
	for action: Variant in data.actions:
		Schema._shape(action,{"screen":"string","id":"string","parameters":"object"},"action",errors)
		if not errors.is_empty() or action.screen not in ["piece","terrain","objects"]: return {"ok":false,"code":"arguments_invalid"}
	return {"ok":true,"actions":data.actions}

func _finish(response: Dictionary) -> void:
	var written := true
	if not _result_path.is_empty() and FileAccess.file_exists(_result_path):
		response = {"ok":false,"code":"io_conflict"}
	elif not _result_path.is_empty():
		var file := FileAccess.open(_result_path,FileAccess.WRITE)
		written = file != null
		if file != null:
			file.store_string(JSON.stringify(response,"\t",true,true)); file.flush()
			written = file.get_error() == OK; file.close()
	if not written: response = {"ok":false,"code":"io_failure"}
	print("F9_AX_SESSION_RESULT "+JSON.stringify({"ok":response.get("ok",false),"code":response.get("code",""),"source_hash":response.get("source_hash",""),"completed_actions":response.get("completed_actions",0)}))
	if shell != null: shell.free()
	quit(0 if response.get("ok",false) else 1)
