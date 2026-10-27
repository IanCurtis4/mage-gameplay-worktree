extends Control
## Presentation owner outside the canonical RunController snapshot graph.
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const Protocol = preload("res://scripts/map_authoring/preview/gameplay_protocol.gd")
const AuthoredView = preload("res://scripts/world/authored_expedition_view.gd")
var session: Dictionary = {}
var window: Dictionary = {}
var window_claimed := false
var _window_status_cache := ""
var _handling_command := false
var _command_receipts: Dictionary = {}
var _command_error := ""
var prepared: Dictionary = {}
var facade: ProfileFacade
var host: RunController
var status := "idle"
var last_result: Dictionary = {}
var busy := false
var close_after_suspend := false
var quit_on_close := true
var claimed := false
var _elapsed := 0.0
var _status_cache := ""
var _serial := 0
var caption: Label
var suspend_button: Button
var resume_button: Button
var restart_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS; process_priority = 100; mouse_filter = Control.MOUSE_FILTER_IGNORE
	child_entered_tree.connect(_child_entered)
	_build_controls()
	get_tree().auto_accept_quit = false
	if not session.is_empty(): return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--f9-window="):
			var opened := open_window(argument.trim_prefix("--f9-window="))
			if opened.ok: start()
			return
		if argument.begins_with("--f9-session="):
			var result := open(argument.trim_prefix("--f9-session="))
			if result.ok: start()
			return
	_set_result(Candidate.fail("candidate_invalid"))

func open(path: String) -> Dictionary:
	if claimed or is_instance_valid(host): return {"ok":false,"code":"preview_busy"}
	var resolved := Launcher.resolve(path)
	if not resolved.ok: return _set_result(resolved)
	if not window.is_empty() and (window.window.candidate_hash != resolved.session.candidate_hash or window.base_path != resolved.base_path): return _set_result(Candidate.fail("candidate_invalid"))
	var built := Candidate.prepare(resolved.candidate)
	if not built.ok: return _set_result(built)
	var acquired := Launcher.claim(resolved)
	if not acquired.ok: return _set_result(acquired)
	session = resolved; prepared = built; claimed = true
	status = "ready"
	get_tree().root.title = "RagRPG · Teste descartável · "+String(session.session.candidate_hash).substr(0,10)
	_refresh()
	return _set_result({"ok":true})

func open_window(path: String) -> Dictionary:
	if claimed or window_claimed or is_instance_valid(host): return {"ok":false,"code":"preview_busy"}
	var descriptor := Launcher.window_header(path)
	if not descriptor.ok: return _set_result(descriptor)
	var acquired := Launcher.claim_window(descriptor)
	if not acquired.ok: return _set_result(acquired)
	window = descriptor; window_claimed = true
	var result := open(window.window.initial_session)
	if not result.ok:
		Launcher.release(window); window_claimed = false
	return result

func start() -> Dictionary:
	if not claimed or busy or is_instance_valid(host): return _set_result({"ok":false,"code":"preview_busy"})
	busy = true
	var catalog := ProfileCatalog.pilot()
	var directory: String = session.directory.path_join("profile")
	facade = ProfileFacade.new(ProfileStore.new(directory,catalog))
	var opened := facade.open_profile()
	if not opened.ok: busy = false; return _set_result(opened)
	var profile := facade.current_profile()
	if profile.characters.is_empty():
		var created := facade.create_character(_request("create"),profile.revision,"Teste descartável",StringName(session.session.class_id))
		if not created.ok: busy = false; return _set_result(created)
		profile = facade.current_profile()
	var lock := profile.expedition_for_character(profile.selected_character_id)
	if lock != null:
		busy = false
		return resume()
	if not profile.expeditions.is_empty() or profile.reward_session != null:
		busy = false; status = "stopped"
		return _set_result({"ok":false,"code":"preview_finished","message":"A sessão anterior foi preservada. Reinicie para testar novamente."})
	var loaded := BuildContentLoader.load_catalog_for_profile(catalog,true)
	if not loaded.ok: busy = false; return _set_result(loaded)
	var started := facade.start_run(_request("run"),profile.revision)
	if not started.ok: busy = false; return _set_result(started)
	var run: RunState = started.run_state
	var effects := run.set_effect_catalog(loaded.catalog)
	if not effects.ok: busy = false; return _set_result(effects)
	RunController.pending_run_state = run; RunController.pending_run_facade = facade
	RunController.pending_training_mode = false; RunController.pending_gameplay_extension = false
	var previous := RunController.new()
	previous.expedition_entry_mode = true
	previous.control_preferences.path = session.directory.path_join("controls.cfg")
	previous.expedition_field_height = prepared.manifest._data.input.traversal.height
	var was_paused := get_tree().paused; get_tree().paused = true
	add_child(previous)
	if previous.player == null or previous.reward_service == null:
		previous.free(); get_tree().paused = was_paused; busy = false
		return _set_result({"ok":false,"code":"preview_startup","message":"O personagem não pôde ser preparado; a sessão foi preservada."})
	var loot := previous.reward_service.configure_mob_loot(EquipmentLootProfiles.production(run.effect_catalog()))
	if not loot.ok:
		previous.free(); get_tree().paused = was_paused; busy = false; return _set_result(loot)
	var barrier := SnapshotTickBarrier.new(); var held := barrier.acquire(previous)
	if not held.ok:
		previous.free(); get_tree().paused = was_paused; busy = false; return _set_result(held)
	var entered := ExpeditionService.new(facade).enter(previous,barrier,"preview_"+session.session.session_id,prepared.manifest,prepared.rules,_request("enter"),facade.current_profile().revision)
	barrier.release()
	if not entered.ok:
		previous.free(); get_tree().paused = was_paused; busy = false; return _set_result(entered)
	var installed := ExpeditionSceneFlow.install(entered,previous)
	busy = false
	if not installed.ok:
		if is_instance_valid(entered.root): entered.root.free()
		if is_instance_valid(previous): previous.free()
		get_tree().paused = was_paused; return _set_result(installed)
	return _adopt(entered.root)

func resume() -> Dictionary:
	if not claimed or busy or is_instance_valid(host) or facade == null: return _set_result({"ok":false,"code":"preview_busy"})
	var profile := facade.current_profile()
	var lock := profile.expedition_for_character(profile.selected_character_id)
	if lock == null: return _set_result({"ok":false,"code":"preview_finished"})
	var service := ExpeditionService.new(facade)
	# Validate compatibility and candidate identity before any durable resume mutation.
	var inspected := service._restore(lock)
	if not inspected.ok: return _set_result(inspected)
	var restored: RunController = inspected.root
	var matches: bool = restored.campaign_runtime != null and restored.campaign_runtime.state.manifest_data.input.get("preview_candidate_hash") == session.session.candidate_hash
	restored.free()
	if not matches: return _set_result(Candidate.fail("candidate_invalid"))
	busy = true
	var result := service.resume(lock.expedition_id,lock.character_id,_request("resume"),profile.revision)
	if not result.ok: busy = false; return _set_result(result)
	var installed: Dictionary = result.registry.install(result,self)
	if installed.ok: installed = result.registry.activate(result)
	busy = false
	if not installed.ok:
		if is_instance_valid(result.root): result.root.free()
		return _set_result(installed)
	get_tree().paused = result.root.campaign_runtime.state.lifecycle != "active"
	return _adopt(result.root)

func _adopt(value: RunController) -> Dictionary:
	if not is_instance_valid(value) or value.get_parent() != self or value.campaign_runtime == null: return {"ok":false,"code":"preview_detached"}
	if value.expedition_view is AuthoredView:
		host = value; return {"ok":true}
	var view := AuthoredView.new(); value.add_child(view)
	var made := view.configure_package(prepared.map_package,value.player.world_motion.geometry)
	if not made.ok: view.free(); get_tree().paused = true; return _set_result(made)
	var old := value.expedition_view
	var attached := value.attach_expedition_view(view,prepared.manifest._data.input.traversal.height)
	if not attached.ok: view.free(); get_tree().paused = true; return _set_result(attached)
	if is_instance_valid(old): old.get_parent().remove_child(old); old.queue_free()
	host = value; status = host.campaign_runtime.state.lifecycle
	if host.class_button != null: host.class_button.hide()
	if host.class_overlay != null: host.class_overlay.hide()
	if host.route_camera != null:
		host.route_camera.make_current(); host.route_camera.reset_smoothing(); host.route_camera.force_update_scroll()
	return _set_result({"ok":true})

func _child_entered(node: Node) -> void:
	if node is RunController:
		# External write destinations are deliberately omitted from snapshots.
		# Assign before _ready / presentation installation can expose controls.
		if not session.is_empty(): node.control_preferences.path = session.directory.path_join("controls.cfg")
		_adopt_deferred.call_deferred(weakref(node))
	elif node is CharacterMenu:
		node.hide(); node.process_mode = Node.PROCESS_MODE_DISABLED
		_lobby.call_deferred(node)

func _adopt_deferred(reference: WeakRef) -> void:
	var value := reference.get_ref() as RunController
	if is_instance_valid(value) and value.get_parent() == self and value.campaign_runtime != null: _adopt(value)

func _lobby(menu: CharacterMenu) -> void:
	if not is_instance_valid(menu): return
	var same: bool = menu.facade == facade
	remove_child(menu); menu.queue_free(); host = null
	if not same: _set_result(Candidate.fail("candidate_invalid")); return
	var profile := facade.current_profile(); var lock := profile.expedition_for_character(profile.selected_character_id)
	status = "suspended" if lock != null else "completed"
	_refresh(); _write_status()
	if close_after_suspend: _close()

func suspend() -> Dictionary:
	if busy or not is_instance_valid(host): return {"ok":false,"code":"preview_busy"}
	if host.campaign_runtime.state.lifecycle == "completed":
		ExpeditionSceneFlow.lobby(host); return {"ok":true}
	var panel := host.ui_root.get_node_or_null("ExpeditionStatus") as ExpeditionStatusPanel
	if panel == null: return _set_result({"ok":false,"code":"preview_detached"})
	busy = true
	var result: Dictionary = await panel.run_action({"kind":"suspend"})
	busy = false
	if not result.ok: close_after_suspend = false
	return _set_result(result)

func restart() -> Dictionary:
	if busy: return {"ok":false,"code":"preview_busy"}
	if is_instance_valid(host):
		var saved := await suspend()
		if not saved.ok: return saved
		await get_tree().process_frame
	var created := Launcher.create_session(session.candidate,session.session.class_id,session.root_path)
	if not created.ok: return _set_result(created)
	Launcher.release(session); claimed = false
	session = {}; prepared = {}; facade = null; host = null
	var opened := open(created.path)
	return start() if opened.ok else opened

func request_close() -> void:
	if busy: return
	if is_instance_valid(host):
		close_after_suspend = true
		await suspend()
	else: _close()

func _close() -> void:
	status = "closed"; _write_status()
	if claimed: Launcher.release(session); claimed = false
	if window_claimed: Launcher.release(window); window_claimed = false
	if quit_on_close: get_tree().quit()

func _exit_tree() -> void:
	if claimed: Launcher.release(session); claimed = false
	if window_claimed: Launcher.release(window); window_claimed = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: request_close()

func _process(delta: float) -> void:
	if is_instance_valid(host):
		if host.class_button != null: host.class_button.hide()
		_localize_stage()
	_elapsed += delta
	if _elapsed < 0.25 or (session.is_empty() and window.is_empty()): return
	_elapsed = 0.0; _write_status(); _refresh()
	_poll_command()
	var directory: String = window.directory if not window.is_empty() else session.directory
	var token: String = window.window.window_id if not window.is_empty() else session.session.session_id
	var path := directory.path_join("stop.request")
	if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == token and not busy:
		DirAccess.remove_absolute(path); request_close()

func _request(kind: String) -> String:
	_serial += 1; return "preview_%s_%d_%d"%[kind,Time.get_ticks_usec(),_serial]

func _set_result(result: Dictionary) -> Dictionary:
	last_result = result
	if not result.ok and not is_instance_valid(host): status = "error"
	_refresh(); _write_status(); return result

func _write_status() -> void:
	if session.is_empty() and window.is_empty(): return
	var error := String(last_result.get("code",last_result.get("error_code","")))
	if not session.is_empty():
		var view := {"session_id":session.session.session_id,"candidate_hash":session.session.candidate_hash,"state":status,"busy":busy,"error":error}
		var encoded := JSON.stringify(view)
		if encoded != _status_cache:
			var saved := Launcher.write_atomic(String(session.directory).path_join("status.json"),encoded.to_utf8_buffer())
			if saved.ok: _status_cache = encoded
	if not window.is_empty():
		var current: String = session.path if not session.is_empty() else window.window.initial_session
		var view := {"window_id":window.window.window_id,"candidate_hash":window.window.candidate_hash,"current_session_path":current,"state":status,"busy":busy or _handling_command,"error":error,"command_error":_command_error,"gameplay":describe_gameplay()}
		var encoded := JSON.stringify(view)
		if encoded != _window_status_cache:
			var saved := Launcher.write_atomic(String(window.directory).path_join("status.json"),encoded.to_utf8_buffer())
			if saved.ok: _window_status_cache = encoded

func _build_controls() -> void:
	var layer := CanvasLayer.new(); layer.layer = 100; add_child(layer)
	var bar := PanelContainer.new(); layer.add_child(bar)
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP); bar.offset_left = -330; bar.offset_right = 330; bar.offset_top = 4
	var column := VBoxContainer.new(); bar.add_child(column)
	caption = Label.new(); caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; column.add_child(caption)
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_CENTER; column.add_child(row)
	suspend_button = _button(row,"Suspender",suspend)
	resume_button = _button(row,"Retomar",resume)
	restart_button = _button(row,"Reiniciar",restart)
	_button(row,"Fechar",request_close); _refresh()

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(callback); parent.add_child(button); return button

func _refresh() -> void:
	if caption == null: return
	_localize_stage()
	var revision: String = session.session.candidate_hash.substr(0,10) if not session.is_empty() else (String(window.window.candidate_hash).substr(0,10) if not window.is_empty() else "—")
	var message: String = last_result.get("message",_error_text(last_result)) if not last_result.is_empty() and not last_result.ok else ""
	caption.text = "TESTE DESCARTÁVEL · %s · %s%s"%[revision,{"active":"jogando","ready":"pronto","suspended":"suspenso","completed":"concluído","error":"falha","closed":"encerrado"}.get(status,status),(" · "+message) if not message.is_empty() else ""]
	suspend_button.disabled = busy or not is_instance_valid(host)
	resume_button.disabled = busy or is_instance_valid(host) or facade == null or status not in ["suspended","error"]
	restart_button.disabled = busy or session.is_empty()

func _localize_stage() -> void:
	if not is_instance_valid(host) or host.ui_root == null: return
	var panel := host.ui_root.get_node_or_null("ExpeditionStatus") as ExpeditionStatusPanel
	if panel != null and panel.summary != null and "map_preview" in panel.summary.text:
		panel.summary.text = panel.summary.text.replace("map_preview","Mapa de teste")

func _error_text(result: Dictionary) -> String:
	match String(result.get("code",result.get("error_code",""))):
		"preview_busy": return "A sessão já está aberta ou ocupada."
		"preview_finished": return "Esta sessão terminou; reinicie para testar novamente."
		"preview_detached": return "O personagem ainda está sendo preparado."
	return ExpeditionPresentation.error_text(StringName(result.get("error_code",result.get("code","unknown"))))

func _live_host() -> bool:
	return is_instance_valid(host) and host.is_inside_tree() and host.get_parent() == self and host.campaign_runtime != null and not host.snapshot_passive

func describe_gameplay() -> Dictionary:
	var result := {"ready":_live_host(),"session_id":session.session.session_id if not session.is_empty() else "","lifecycle":status}
	if not result.ready: return result
	var state := host.campaign_runtime.state
	result.lifecycle = state.lifecycle; result["run_id"] = host.run_state.run_id
	result["geometry_revision"] = host.player.world_motion.geometry.geometry_revision
	result["player"] = {"point":_actor_point(host.player),"hp":host.player.health.current_hp,"max_hp":host.player.health.max_hp,"sp":host.player.current_sp,"max_sp":host.player.max_sp,"active_cast":String(host.player.active_cast_skill),"cast_remaining":host.player.active_cast_remaining}
	var skills: Array = []
	for id: StringName in host.player.available_skill_ids(): skills.append({"skill_id":String(id),"rank":host.run_state.effective_skill_rank(id),"cooldown":host.player.skill_cooldown(id)})
	result["skills"] = skills
	var enemies: Array = []
	for id: String in state.slots:
		var slot: Dictionary = state.slots[id]
		var record := {"slot_id":id,"generation":slot.generation,"life_state":slot.life_state}
		var actor: EnemyActor = host.campaign_runtime.actors.get(id)
		if is_instance_valid(actor): record.merge({"point":_actor_point(actor),"hp":actor.health.current_hp,"max_hp":actor.health.max_hp})
		enemies.append(record)
	result["enemies"] = enemies
	var interactions: Array = []
	for portal: Dictionary in state.manifest_data.portals:
		if portal.from_stage == state.current_stage_id: interactions.append({"interaction_id":portal.portal_id,"kind":"portal","point":_point_data(portal.from_anchor)})
	for objective: Dictionary in state.manifest_data.objectives:
		if objective.stage_id == state.current_stage_id: interactions.append({"interaction_id":objective.objective_id,"kind":objective.outcome,"point":_point_data(objective.point)})
	result["interactions"] = interactions
	var ticket := host.reward_service.next_pending_ticket()
	result["reward_ticket_id"] = String(ticket.get("ticket_id",""))
	return result

static func _point_data(point: Dictionary) -> Dictionary:
	var at: Vector3 = point.position
	return {"stage_id":point.stage_id,"surface_id":point.surface_id,"position_xyz":[at.x,at.y,at.z]}

static func _actor_point(actor: CombatActor) -> Variant:
	var point := actor.world_point()
	return _point_data(point.to_data()) if point != null else null

func command(action: Dictionary) -> Dictionary:
	if not Protocol.action_valid(action): return {"ok":false,"code":"command_invalid"}
	if action.kind == "inspect": return {"ok":true,"state":describe_gameplay()}
	if busy: return {"ok":false,"code":"command_busy"}
	match action.kind:
		"suspend": return await suspend()
		"resume": return resume()
		"restart": return await restart()
		"close": await request_close(); return {"ok":true}
	if not _live_host() or host._memory_snapshot_pending: return {"ok":false,"code":"command_busy"}
	var value := Protocol.normalize_action(action)
	if value.kind in ["move","skill"]:
		if value.geometry_revision != host.player.world_motion.geometry.geometry_revision: return {"ok":false,"code":"command_stale"}
		var point := Vector3(value.position_xyz[0],value.position_xyz[1],value.position_xyz[2])
		var projected := AuthoredView.project(point)
		if value.kind == "move": return host.spatial_pointer_move(projected)
		var prior_rank := host._intent_rank
		host._intent_rank = int(value.rank)
		var result := host.spatial_pointer_skill(StringName(value.skill_id),projected,value.preview)
		host._intent_rank = prior_rank
		return result
	var panel := host.ui_root.get_node_or_null("ExpeditionStatus") as ExpeditionStatusPanel
	if panel == null: return {"ok":false,"code":"preview_detached"}
	if value.kind == "collect": return await panel.run_action({"kind":"collect","ticket_id":value.ticket_id})
	var state := host.campaign_runtime.state
	for portal: Dictionary in state.manifest_data.portals:
		if portal.portal_id == value.interaction_id and portal.from_stage == state.current_stage_id:
			return await panel.run_action({"kind":"travel","portal_id":portal.portal_id,"stage_id":state.current_stage_id})
	for objective: Dictionary in state.manifest_data.objectives:
		if objective.objective_id == value.interaction_id and objective.stage_id == state.current_stage_id:
			return await panel.run_action({"kind":"finish","outcome":"completed" if objective.outcome == "phase_completion" else "quest","source":objective.objective_id})
	return {"ok":false,"code":"interaction_missing"}

func _poll_command() -> void:
	if window.is_empty() or not window_claimed or busy or _handling_command: return
	var path: String = String(window.directory).path_join("command.request")
	if not FileAccess.file_exists(path): return
	var read := Protocol.read_json(path,Protocol.MAX_COMMAND_BYTES)
	if not read.ok or not Protocol.envelope_valid(read.data):
		_command_error = "command_invalid"
		# Preserve invalid bytes for diagnosis; no sender path is used as a target.
		var rejected: String = String(window.directory).path_join("command.rejected")
		if not FileAccess.file_exists(rejected): DirAccess.rename_absolute(path,rejected)
		return
	var envelope: Dictionary = read.data
	var id: String = envelope.request_id
	var signature := Protocol.fingerprint(envelope.session_id,envelope.payload)
	if _command_receipts.has(id):
		var receipt: Dictionary = _command_receipts[id]
		if receipt.fingerprint != signature: _command_error = "request_conflict"; return
		if receipt.has("reply"): _flush_reply(envelope,receipt.reply)
		return
	if _command_receipts.size() >= Protocol.MAX_RECEIPTS:
		_flush_reply(envelope,_make_reply(envelope,{"ok":false,"code":"command_receipt_limit"})); return
	_command_receipts[id] = {"fingerprint":signature}
	_handling_command = true
	_run_command.call_deferred(envelope)

func _run_command(envelope: Dictionary) -> void:
	var result: Dictionary
	if envelope.window_id != window.window.window_id or session.is_empty() or envelope.session_id != session.session.session_id:
		result = {"ok":false,"code":"command_stale"}
	else: result = await command(envelope.payload)
	var reply := _make_reply(envelope,result)
	_command_receipts[envelope.request_id]["reply"] = reply
	_handling_command = false
	_flush_reply(envelope,reply)

func _make_reply(envelope: Dictionary, result: Dictionary) -> Dictionary:
	var public := {"ok":bool(result.get("ok",false)),"code":String(result.get("code",result.get("error_code",""))),"state":describe_gameplay()}
	for field: String in ["durable","already_applied"]:
		if result.get(field) is bool: public[field] = result[field]
	return {"format_version":1,"window_id":window.window.window_id,"session_id":envelope.session_id,"request_id":envelope.request_id,"fingerprint":Protocol.fingerprint(envelope.session_id,envelope.payload),"result":public}

func _flush_reply(envelope: Dictionary, reply: Dictionary) -> void:
	var path := Protocol.reply_path(window,envelope.request_id)
	var bytes := JSON.stringify(reply,"",true,true).to_utf8_buffer()
	if bytes.size() > Protocol.MAX_REPLY_BYTES: _command_error = "command_limit"; return
	var saved: Dictionary
	if FileAccess.file_exists(path):
		var previous := Protocol.read_reply(window,envelope.request_id,envelope.session_id,reply.fingerprint)
		saved = {"ok":true} if previous.ok and not previous.pending else {"ok":false}
	else: saved = Launcher.write_atomic(path,bytes)
	if not saved.ok: _command_error = "command_io"; return
	var request_path: String = String(window.directory).path_join("command.request")
	if FileAccess.file_exists(request_path):
		var pending := Protocol.read_json(request_path,Protocol.MAX_COMMAND_BYTES)
		if pending.ok and pending.data.get("request_id") == envelope.request_id: DirAccess.remove_absolute(request_path)
	_command_error = ""
