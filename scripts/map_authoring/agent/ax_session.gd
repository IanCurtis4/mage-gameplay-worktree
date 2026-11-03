extends SceneTree
## Passive action transport. Every mutation goes through the real AX presentation.
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const StrictJSON = preload("res://scripts/map_authoring/io/strict_json.gd")
var shell: Control
var objects_panel: Control
var map_panel: Control
var population_panel: Control
var patrol_panel: Control
var _capture_screen := "terrain"
var _request_path := ""
var _result_path := ""
var _capture_path := ""
## F10 Q4: how long the client waits for a panel job (a field-scale encounter
## plan exceeded the earlier 300 s). A wait, not a content guard.
const AX_JOB_WAIT_MSEC := 1800000

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
	# A headless display has no usable desktop for centering child windows.
	# Keep the same real windows embedded in the editor host in both modes.
	root.gui_embed_subwindows = true
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
		elif action.screen == "map":
			outcome = await _ensure_map()
			if map_panel != null: presentation = map_panel.get_node("AuthoringPresentation")
			_capture_screen = "map"
		elif action.screen == "population":
			outcome = await _ensure_population()
			if population_panel != null: presentation = population_panel.get_node("AuthoringPresentation")
			_capture_screen = "population"
		elif action.screen == "patrol":
			outcome = await _ensure_patrol()
			if patrol_panel != null: presentation = patrol_panel.get_node("AuthoringPresentation")
			_capture_screen = "patrol"
		elif action.screen == "terrain": _capture_screen = "terrain"
		var before := _action_hash(action.screen)
		if outcome.ok: outcome = presentation.ax_invoke(action.id,action.parameters)
		var compile_owner: Control
		if action.screen == "terrain" and action.id == "terrain/compile_piece": compile_owner = shell.terrain
		elif action.screen == "map" and action.id == "map/compile_map": compile_owner = map_panel
		elif action.screen == "population" and action.id in ["population/compile","population/plan/preview","population/prepare_preview"]: compile_owner = population_panel
		elif action.screen == "patrol" and action.id == "patrol/compile": compile_owner = patrol_panel
		if outcome.get("ok",false) and compile_owner != null:
			# The GUI action starts its normal worker. Keep this client alive until
			# the panel publishes that worker's canonical, revision-checked result.
			var started := Time.get_ticks_msec()
			while compile_owner.job != null and Time.get_ticks_msec()-started < AX_JOB_WAIT_MSEC:
				await process_frame
			if compile_owner.job != null:
				if action.screen == "patrol": compile_owner.cancel()
				else: compile_owner.job.cancel()
				outcome = {"ok":false,"code":"compile_timeout"}
			elif action.screen == "population" and action.id in ["population/plan/preview","population/prepare_preview"]:
				outcome = compile_owner.proposal.duplicate(true)
				if outcome.get("ok",false): outcome.proposal_hash = compile_owner.proposal_hash()
			else: outcome = compile_owner.result.duplicate(true)
		# Only the final snapshot carries the full source; keeping one copy per
		# stroke would make long, otherwise valid authoring batches grow quadratically.
		outcome.erase("data")
		outcome.erase("package")
		outcomes.append({"screen":action.screen,"id":action.id,"input_hash":before,"output_hash":_action_hash(action.screen),"result":outcome})
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
	var map_snapshot: Dictionary = {}
	if map_panel != null:
		map_snapshot = map_panel.get_node("AuthoringPresentation").ax_snapshot()
		map_snapshot.source_hash = _action_hash("map")
		map_snapshot.state = {"source_path":map_panel.source_path,"dirty":map_panel._dirty(),"can_undo":map_panel.session.can_undo(),"can_redo":map_panel.session.can_redo(),"selected_instance":map_panel.canvas.selected_instance}
		map_snapshot.diagnostics = map_panel.result.get("diagnostics",[])
	var response := {"map_snapshot":map_snapshot,"objects_snapshot":objects_snapshot,"ok":ok,"code":"" if ok else "action_rejected","completed_actions":outcomes.size(),"requested_actions":request.actions.size(),"actions":outcomes,"source_hash":shell.session.document().semantic_hash(),"snapshot":piece.ax_snapshot(),"terrain_snapshot":terrain_snapshot,"state":{"selected_layer":shell.terrain.selected_layer,"can_undo":shell.session.can_undo(),"can_redo":shell.session.can_redo(),"dirty":shell.session.dirty(),"source_path":shell.source_path},"diagnostics":shell.session.document().diagnostics()}
	response.population_snapshot = _linked_snapshot(population_panel,"population")
	response.patrol_snapshot = _linked_snapshot(patrol_panel,"patrol")
	if not _capture_path.is_empty() and DisplayServer.get_name() == "headless":
		response.ok = false; response.code = "capture_requires_display"
	elif not _capture_path.is_empty():
		var canvas: Control = shell.terrain.canvas
		if _capture_screen == "map" and map_panel != null: canvas = map_panel.canvas
		elif _capture_screen == "objects" and objects_panel != null: canvas = objects_panel.canvas
		elif _capture_screen == "population" and population_panel != null: canvas = population_panel.canvas
		elif _capture_screen == "patrol" and patrol_panel != null: canvas = patrol_panel.canvas
		_prepare_capture_windows()
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

func _action_hash(screen: String) -> String:
	if screen == "map": return "" if map_panel == null else map_panel.Document.hash_source(map_panel.session.data)
	if screen == "population": return "" if population_panel == null else population_panel.Document.hash_source(population_panel.session.data)
	if screen == "patrol": return "" if patrol_panel == null else patrol_panel.Document.hash_source(patrol_panel.session.data)
	return shell.session.document().semantic_hash()

func _ensure_map() -> Dictionary:
	if map_panel != null: return {"ok":true}
	var opened: Dictionary = shell.get_node("AuthoringPresentation").ax_invoke("piece/compose_map")
	await process_frame
	if opened.ok and is_instance_valid(shell.composition_window): map_panel = shell.composition_window.get_child(0)
	return {"ok":true} if map_panel != null else (opened if not opened.ok else {"ok":false,"code":"screen_missing"})
func _ensure_population() -> Dictionary:
	if population_panel != null: return {"ok":true}
	var opened: Dictionary = await _ensure_map()
	if not opened.ok: return opened
	opened = map_panel.get_node("AuthoringPresentation").ax_invoke("map/open_population")
	await process_frame
	if opened.ok and is_instance_valid(map_panel.population_window): population_panel = map_panel.population_window.get_child(0)
	return {"ok":true} if population_panel != null else (opened if not opened.ok else {"ok":false,"code":"screen_missing"})
func _ensure_patrol() -> Dictionary:
	if patrol_panel != null: return {"ok":true}
	var opened: Dictionary = await _ensure_population()
	if not opened.ok: return opened
	opened = population_panel.get_node("AuthoringPresentation").ax_invoke("population/open_patrols")
	await process_frame
	if opened.ok and is_instance_valid(population_panel.patrol_window): patrol_panel = population_panel.patrol_window.get_child(0)
	return {"ok":true} if patrol_panel != null else (opened if not opened.ok else {"ok":false,"code":"screen_missing"})
func _linked_snapshot(panel: Control, screen_id: String) -> Dictionary:
	if panel == null: return {}
	var snapshot: Dictionary = panel.get_node("AuthoringPresentation").ax_snapshot()
	snapshot.source_hash = _action_hash(screen_id)
	snapshot.state = {"source_path":panel.source_path,"dirty":panel._dirty(),"can_undo":panel.session.can_undo(),"can_redo":panel.session.can_redo(),"selected_surface":panel.canvas.selected_surface,"pending_name":panel.name_edit.text}
	snapshot.diagnostics = panel.result.get("diagnostics",[])
	if screen_id == "population":
		snapshot.proposal_hash = panel.proposal_hash()
		if panel.proposal.get("ok",false): snapshot.proposal = {"base_hash":panel.proposal.base_hash,"source":panel.proposal.data.duplicate(true),"diff":panel.proposal.diff.duplicate(true),"proposal_hash":panel.proposal_hash()}
	return snapshot
func _prepare_capture_windows() -> void:
	if is_instance_valid(shell.objects_window): shell.objects_window.hide()
	if map_panel != null:
		if is_instance_valid(map_panel.population_window): map_panel.population_window.hide()
		if population_panel != null and is_instance_valid(population_panel.patrol_window): population_panel.patrol_window.hide()
	if is_instance_valid(shell.composition_window): shell.composition_window.hide()
	if _capture_screen == "objects" and objects_panel != null:
		_fit_window(shell.objects_window)
	elif _capture_screen in ["map","population","patrol"] and map_panel != null:
		_fit_window(shell.composition_window)
		if _capture_screen in ["population","patrol"] and population_panel != null: _fit_window(map_panel.population_window)
		if _capture_screen == "patrol" and patrol_panel != null: _fit_window(population_panel.patrol_window)
func _fit_window(window: Window) -> void:
	window.position = Vector2i.ZERO; window.size = root.size; window.show()

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
		if not errors.is_empty() or action.screen not in ["piece","terrain","objects","map","population","patrol"]: return {"ok":false,"code":"arguments_invalid"}
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
