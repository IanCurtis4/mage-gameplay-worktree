class_name ExpeditionStatusPanel
extends PanelContainer
## Disposable UI: rebuilt by _build_ui after install, omitted from snapshots.
var host: RunController
var summary: Label
var threats: Label
var elapsed := 0.0
var actions: VBoxContainer
var message: Label
var service: ExpeditionService
var intent: Dictionary = {}
var request := ""
var busy := false
var uncertain := false
## The capture() result taken under the barrier this panel is still holding.
var _cut: Dictionary = {}
var last_actions := ""

func _ready() -> void:
	name = "ExpeditionStatus"
	# F10 Q3: the panel draws a background; a click on it never reaches the world.
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = 24; offset_right = 414; offset_top = 220
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	summary = Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 350
	column.add_child(summary)
	threats = Label.new()
	threats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(threats)
	actions = VBoxContainer.new()
	column.add_child(actions)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	refresh()

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.2: return
	elapsed = 0.0
	refresh()

func refresh() -> void:
	visible = is_instance_valid(host) and host.campaign_runtime != null
	if not visible or summary == null: return
	summary.text = ExpeditionPresentation.campaign_text(host.campaign_runtime.state.view(), host.campaign_runtime.state.manifest_data)
	var target := host._selected_enemy as EnemyActor
	threats.text = ExpeditionPresentation.threat_text(target.threat.view()) if is_instance_valid(target) and target.is_alive() else "Selecione um inimigo para consultar a ameaça."
	var state := host.campaign_runtime.state
	var views: Array[Dictionary] = []
	for portal: Dictionary in state.manifest_data["portals"]:
		if portal["from_stage"] == state.current_stage_id: views.append(state.portal_view(portal["portal_id"]))
	var next_ticket := host.reward_service.next_pending_ticket()
	var key := str([views, state.lifecycle, next_ticket.get("ticket_id", ""), busy, uncertain, host._memory_snapshot_pending])
	if key == last_actions: return
	last_actions = key
	for child: Node in actions.get_children(): actions.remove_child(child); child.queue_free()
	if busy: return
	if not intent.is_empty():
		_button("Confirmar recuperação" if uncertain else "Tentar novamente", retry)
		return
	if host._memory_snapshot_pending:
		_button("Recuperar transição pendente", host.retry_expedition_events)
		return
	if state.lifecycle == "completed":
		_button("Voltar ao lobby", func() -> void: ExpeditionSceneFlow.lobby(host))
		return
	if state.lifecycle == "recovering":
		_button("Reviver no último portal", run_action.bind({"kind": "revive", "event_id": state.current_death_id}))
		return
	if not next_ticket.is_empty():
		_button("Coletar próxima recompensa", run_action.bind({"kind": "collect", "ticket_id": next_ticket["ticket_id"]}))
	for view: Dictionary in views:
		var button := _button(ExpeditionPresentation.portal_text(view, state.manifest_data), run_action.bind({"kind": "travel", "portal_id": view["portal_id"], "stage_id": state.current_stage_id}))
		button.tooltip_text = "Aproxime-se do portal indicado no mapa antes de viajar."
		button.disabled = not view["open"]
	for objective: Dictionary in state.manifest_data["objectives"]:
		if objective["stage_id"] == state.current_stage_id:
			if objective["outcome"] == "stage_unlock":
				var unlock := _button("Ativar o objetivo do estágio", run_action.bind({"kind": "unlock", "source": objective["objective_id"]}))
				unlock.disabled = state.objectives.has(objective["objective_id"]) or not state.guardians_resolved(state.current_stage_id)
				unlock.tooltip_text = "Derrote o guardião deste estágio antes." if not state.guardians_resolved(state.current_stage_id) else "Aproxime-se do objetivo marcado no mapa."
				continue
			_button("Concluir na saída final" if objective["outcome"] == "phase_completion" else "Suspender no refúgio lateral", run_action.bind({"kind": "finish", "outcome": "completed" if objective["outcome"] == "phase_completion" else "quest", "source": objective["objective_id"]}))
	_button("Suspender e voltar ao lobby", run_action.bind({"kind": "suspend"}))

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.tooltip_text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(callback)
	actions.add_child(button)
	return button

func run_action(command: Dictionary) -> Dictionary:
	if busy or host._memory_snapshot_pending: return BuildEffectCatalog.failure(&"save_in_progress")
	busy = true; intent = command.duplicate(true)
	request = "f7_action_%d" % Time.get_ticks_usec()
	service = ExpeditionService.new(host.persistent_facade)
	message.text = "Gravando a expedição…"
	# Checkpoint39: reviving on the current stage is one journal entry, without
	# capturing the world; anything else keeps the full transaction below.
	if intent["kind"] == "revive" and host.has_method("try_journal_revive"):
		var quick: Dictionary = host.try_journal_revive(intent["event_id"])
		if quick.get("pending", false):
			while is_instance_valid(host) and host.expedition_save_busy(): await get_tree().process_frame
			quick = {"ok": is_instance_valid(host) and host.player.is_alive(), "error_code": &"" if is_instance_valid(host) and host.player.is_alive() else &"save_failed"}
		if quick.get("ok", false):
			busy = false; uncertain = false; intent.clear(); message.text = ""
			return quick
		if quick.get("read_only", false):
			busy = false; uncertain = true
			message.text = ExpeditionPresentation.error_text(quick.get("error_code", &"unknown"))
			return quick
	var requested := host.request_memory_snapshot()
	if not requested["ok"]: return _finish(requested)
	var captured: Dictionary = await host.memory_snapshot_ready
	await get_tree().process_frame
	if not captured["ok"]: return _finish(captured)
	# The world stays frozen under the held barrier: the service reuses this cut
	# instead of capturing and validating the same world a second time.
	_cut = captured
	return _execute()

func _execute() -> Dictionary:
	var revision := host.persistent_facade.current_profile().revision
	var result: Dictionary
	if intent["kind"] == "suspend":
		var state := host.campaign_runtime.state
		result = service.checkpoint(host, host._memory_snapshot_barrier, state.expedition_id, StringName(state.manifest_data["input"]["phase_id"]), request, revision, true, _cut)
	elif intent["kind"] == "collect":
		result = service.collect(host, host._memory_snapshot_barrier, intent["ticket_id"], request, revision)
	else: result = service.campaign_command(host, host._memory_snapshot_barrier, intent, request, revision, _cut)
	return _finish(result)

func _finish(result: Dictionary) -> Dictionary:
	busy = false
	# A cut serves one attempt: an uncertain write retries by reconciliation,
	# and any other retry captures again under its own barrier.
	_cut = {}
	if result.get("ok", false):
		if intent.get("kind") == "suspend" or (intent.get("kind") == "finish" and intent.get("outcome") == "quest"):
			if result.has("root"): result["root"].free()
			ExpeditionSceneFlow.lobby(host)
		elif result.has("root"): return host._install_expedition_result(result)
		else:
			host.release_memory_snapshot()
			intent.clear(); uncertain = false
			message.text = "Recompensa confirmada."
	else:
		uncertain = result.get("read_only", false)
		var code: StringName = result.get("error_code", &"unknown")
		message.text = completion_hint() if code == &"completion_unmet" and intent.get("kind") == "finish" else ExpeditionPresentation.error_text(code)
		# A known eligibility error has no pending writer intent. Resume the
		# unchanged world so the player can approach the portal/leave combat.
		if not uncertain:
			host.release_memory_snapshot()
			intent.clear()
	last_actions = ""
	refresh()
	return result

## completion_unmet covers both "stage not cleared" and "not on the marker";
## tell the player which one. Deaths waiting for the end-of-combat save count.
func completion_hint() -> String:
	var runtime := host.campaign_runtime
	var state := runtime.state
	if not state.stages[state.current_stage_id]["cleared_once"]:
		for id: String in state.slots:
			var slot: Dictionary = state.slots[id]
			if slot["stage_id"] != state.current_stage_id or not slot["blocks_clear"] or slot["initial_resolved"]: continue
			if runtime.pending_events.any(func(event: Dictionary) -> bool: return event["kind"] == "mob_death" and event["slot_id"] == id): continue
			return "Ainda há inimigos vivos que bloqueiam a saída deste estágio."
	return "Fique dentro do círculo do marco ◆ da saída final para concluir."

func retry() -> Dictionary:
	if busy: return BuildEffectCatalog.failure(&"save_in_progress")
	busy = true
	return _finish(service.reconcile(request)) if uncertain else _execute()

func retain_recovery_input() -> void:
	# Only this disposable control subtree may run while the captured world is
	# frozen. run_action refuses new intentions until the barrier is released.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restore_control_input(self)

func _restore_control_input(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.process_mode = Node.PROCESS_MODE_INHERIT
		_restore_control_input(child)
