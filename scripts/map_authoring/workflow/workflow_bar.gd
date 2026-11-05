@tool
extends VBoxContainer
## Checkpoint49 (F9-06/07, P6a): the step bar at the top of the terrain, map,
## encounter and patrol screens. Shows every step of authoring_flow.gd with its
## state, marks the screen the person is on, runs the next step, reviews a carry
## before applying it (one undoable change) and opens the screen that owns a
## problem with its entity focused. Not collected into the screen menus; its own
## AX provider: <screen>/workflow/{state,next,apply,discard,show,open,publish}.
## Checkpoint49 (P6b): "Publicar no jogo…" asks for the identifier and the name,
## says what changes in the game's list of maps and publishes after "Publicar".
const Flow = preload("res://scripts/map_authoring/workflow/authoring_flow.gd")
const Carry = preload("res://scripts/map_authoring/workflow/carry_forward.gd")
var flow: RefCounted
var step_id := "piece"
var screen := "piece"
var owns_flow := false
var step_buttons: Dictionary = {}
var next_button: Button
var show_button: Button
var cancel_button: Button
var detail: Label
var confirmation: ConfirmationDialog
var publish_dialog: ConfirmationDialog
var publish_id: LineEdit
var publish_name: LineEdit
var publish_summary: Label
var publish_plan: Dictionary = {}
var _dirty := true
var _clock := 0.0
var _shown: Dictionary = {}
var steps_toggle: Button
var steps_row: HFlowContainer

static func mount(parent: Control, shared: RefCounted, step: String, screen_id: String, owner: bool) -> VBoxContainer:
	var bar: VBoxContainer = load("res://scripts/map_authoring/workflow/workflow_bar.gd").new()
	bar.setup(shared,step,screen_id,owner)
	parent.add_child(bar); parent.move_child(bar,0)
	return bar

func setup(shared: RefCounted, step: String, screen_id: String, owner: bool) -> void:
	flow = shared; step_id = step; screen = screen_id; owns_flow = owner; name = "AuthoringWorkflow"
	set_meta("authoring_command_provider",true); set_meta("authoring_skip_collect",true)
	var actions := HFlowContainer.new(); add_child(actions)
	steps_toggle = Button.new(); steps_toggle.text = "Mostrar roteiro do mapa"; steps_toggle.toggle_mode = true; actions.add_child(steps_toggle)
	steps_row = HFlowContainer.new(); steps_row.visible = false; add_child(steps_row)
	steps_toggle.toggled.connect(func(open: bool) -> void:
		steps_row.visible = open
		detail.visible = open
		steps_toggle.text = "Ocultar roteiro do mapa" if open else "Mostrar roteiro do mapa")
	var row := steps_row
	for index: int in Flow.ORDER.size():
		var id: String = Flow.ORDER[index]
		var button := Button.new(); button.toggle_mode = true
		button.pressed.connect(func() -> void: button.set_pressed_no_signal(id == step_id); flow.open(id))
		row.add_child(button); step_buttons[id] = button
	var label := Label.new(); label.text = "Próximo passo:"; actions.add_child(label)
	next_button = Button.new(); next_button.pressed.connect(func() -> void: run_next()); actions.add_child(next_button)
	show_button = Button.new(); show_button.text = "Mostrar o problema"; show_button.pressed.connect(func() -> void: show_problem()); actions.add_child(show_button)
	cancel_button = Button.new(); cancel_button.text = "Cancelar atualização"; cancel_button.pressed.connect(func() -> void: flow.cancel()); actions.add_child(cancel_button)
	detail = Label.new(); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; detail.visible = false; add_child(detail)
	confirmation = ConfirmationDialog.new(); confirmation.title = "Atualizar a etapa"; add_child(confirmation)
	confirmation.ok_button_text = "Aplicar (um desfazer)"; confirmation.cancel_button_text = "Descartar"
	confirmation.confirmed.connect(func() -> void: flow.apply_pending(String(confirmation.get_meta("proposal_hash",""))))
	confirmation.canceled.connect(func() -> void: flow.discard_pending())
	publish_dialog = ConfirmationDialog.new(); publish_dialog.title = "Publicar no jogo"; publish_dialog.ok_button_text = "Publicar"; add_child(publish_dialog)
	var form := VBoxContainer.new(); publish_dialog.add_child(form)
	var id_label := Label.new(); id_label.text = "Identificador no jogo (minúsculas, dígitos, _ ou -)"; form.add_child(id_label)
	publish_id = LineEdit.new(); publish_id.custom_minimum_size.x = 420; form.add_child(publish_id)
	var name_label := Label.new(); name_label.text = "Nome visível"; form.add_child(name_label)
	publish_name = LineEdit.new(); form.add_child(publish_name)
	publish_summary = Label.new(); publish_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; publish_summary.custom_minimum_size = Vector2(420,96); form.add_child(publish_summary)
	publish_id.text_changed.connect(func(_text: String) -> void: _replan())
	publish_name.text_changed.connect(func(_text: String) -> void: _replan())
	publish_dialog.confirmed.connect(func() -> void:
		if publish_plan.get("ok",false): flow.publish(publish_plan.package_id,publish_plan.name,publish_plan.registry_hash))
	flow.changed.connect(func() -> void: _dirty = true)
	refresh()

func _process(delta: float) -> void:
	if flow == null: return
	if flow.poll(): _dirty = true
	_clock += delta
	if _dirty or _clock > 0.5: _clock = 0.0; _dirty = false; refresh()

func refresh() -> void:
	var steps: Array = flow.steps()
	for index: int in steps.size():
		var step: Dictionary = steps[index]
		var button: Button = step_buttons[step.id]
		button.text = "%d %s · %s" % [index+1,step.title,step.state_label]
		button.tooltip_text = step.detail
		button.set_pressed_no_signal(step.id == step_id)
		_shown[step.id] = step
	var next: Dictionary = flow.next_step()
	next_button.text = next.get("action_label","Tudo pronto") if not next.is_empty() else "Tudo pronto"
	next_button.disabled = next.is_empty() or flow.job != null
	cancel_button.visible = flow.job != null
	var problem := _problem()
	show_button.visible = not problem.is_empty()
	if flow.job != null and flow.job_action == "publish": detail.text = "Publicando no jogo em segundo plano; a tela continua livre."
	elif flow.job != null: detail.text = "Atualizando %s em segundo plano; a tela continua livre." % String(Flow.TITLES.get(Flow.CARRIES.get(flow.job_action,""),"a etapa")).to_lower()
	elif not problem.is_empty(): detail.text = "%s · %s" % [Flow.TITLES.get(problem.step,""),problem.get("message","")]
	elif not next.is_empty(): detail.text = "%s · %s" % [next.title,next.detail]
	else: detail.text = "Todas as etapas estão prontas para esta revisão."

func _problem() -> Dictionary:
	for id: String in ["piece","map","population","patrol","publish"]:
		var step: Dictionary = _shown.get(id,{})
		if step.get("state","") == "blocked":
			var diagnostic: Dictionary = step.diagnostic.duplicate(true)
			if not diagnostic.has("step"): diagnostic["step"] = id
			return diagnostic
	return {}

func run_next() -> Dictionary:
	var next: Dictionary = flow.next_step()
	if next.is_empty(): return {"ok":false,"code":"flow_action_unavailable"}
	var result: Dictionary = flow.run(next.action)
	if result.get("confirmation_required",false) and result.get("kind","") == "publish": _confirm_publish(result.plan)
	elif result.get("confirmation_required",false): _confirm(result)
	refresh()
	return result

func _confirm(result: Dictionary) -> void:
	# The screen that receives the change asks for it.
	var bar: Node = flow.panel(result.kind).get_node_or_null("AuthoringWorkflow") if flow.panel(result.kind) != null else null
	var target: VBoxContainer = bar if bar != null else self
	target.confirmation.dialog_text = String(result.summary)+"\n\nAplicar como uma ação desfazível?"
	target.confirmation.set_meta("proposal_hash",result.proposal_hash)
	target.confirmation.popup_centered()

## Text of what publishing changes in the game's list of maps.
static func describe(plan: Dictionary) -> String:
	if not plan.get("ok",false):
		var diagnostics: Array = plan.get("diagnostics",[])
		return diagnostics[0].message if not diagnostics.is_empty() else "Não é possível publicar: "+String(plan.get("code",""))
	if plan.unchanged: return "Este pacote já é o publicado como %s." % plan.package_id
	var text: String = "Novo mapa no jogo: %s (%s). Pacote %s." % [plan.name,plan.package_id,String(plan.package_hash).left(12)] if plan.new else "Nova revisão de %s (%s): pacote %s → %s. A revisão anterior continua em %s; a lista de mapas passa a apontar para a nova." % [plan.name,plan.package_id,String(plan.previous.package_hash).left(12),String(plan.package_hash).left(12),String(plan.previous.path).get_file()]
	text += " Fonte: %s%s." % [String(plan.source_path).get_file()," (atualizada)" if plan.source_exists else " (nova)"]
	return text

func _confirm_publish(plan: Dictionary) -> void:
	var bar: Node = flow.panel("patrol").get_node_or_null("AuthoringWorkflow") if flow.panel("patrol") != null else null
	var target: VBoxContainer = bar if bar != null else self
	target.publish_id.text = String(plan.get("package_id","")); target.publish_name.text = String(plan.get("name",""))
	target._replan()
	target.publish_dialog.popup_centered()

func _replan() -> void:
	publish_plan = flow.plan_publication(publish_id.text.strip_edges(),publish_name.text)
	publish_summary.text = describe(publish_plan)
	publish_dialog.get_ok_button().disabled = not publish_plan.get("ok",false) or publish_plan.get("unchanged",false)

func show_problem() -> Dictionary:
	var problem := _problem()
	return flow.show(problem) if not problem.is_empty() else {"ok":false,"code":"flow_no_problem"}

func authoring_commands() -> Array:
	var prefix := screen+"/workflow/"
	return [{"id":prefix+"state","parameters":{}},{"id":prefix+"next","parameters":{"action":"string"}},{"id":prefix+"apply","parameters":{"proposal_hash":"sha256"}},{"id":prefix+"discard","parameters":{}},{"id":prefix+"show","parameters":{"step":"string"}},{"id":prefix+"open","parameters":{"step":"string"}},{"id":prefix+"publish","parameters":{"package_id":"id","name":"string","registry_hash":"sha256 or empty"}}]

func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	var suffix := id.trim_prefix(screen+"/workflow/")
	match suffix:
		"state":
			if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
			var next: Dictionary = flow.next_step()
			return {"ok":true,"steps":flow.steps(),"next":next.get("action",""),"busy":flow.job != null,"pending":{} if flow.pending.is_empty() else {"kind":flow.pending.kind,"proposal_hash":flow.pending.source_hash,"diff":flow.pending.diff.duplicate(true)}}
		"next":
			if parameters.size() != 1 or not parameters.get("action") is String: return {"ok":false,"code":"arguments_invalid"}
			return flow.run(parameters.action)
		"apply":
			if parameters.size() != 1 or not parameters.get("proposal_hash") is String: return {"ok":false,"code":"arguments_invalid"}
			return flow.apply_pending(parameters.proposal_hash)
		"discard":
			if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
			flow.discard_pending(); return {"ok":true}
		"show":
			if parameters.size() != 1 or not parameters.get("step") is String or parameters.step not in Flow.ORDER: return {"ok":false,"code":"arguments_invalid"}
			var diagnostic: Dictionary = flow.blocking(parameters.step)
			return flow.show(diagnostic) if not diagnostic.is_empty() else {"ok":false,"code":"flow_no_problem"}
		"publish":
			if parameters.size() != 3 or not parameters.get("package_id") is String or not parameters.get("name") is String or not parameters.get("registry_hash") is String: return {"ok":false,"code":"arguments_invalid"}
			return flow.publish(parameters.package_id,parameters.name,parameters.registry_hash)
		"open":
			if parameters.size() != 1 or not parameters.get("step") is String or parameters.step not in Flow.ORDER: return {"ok":false,"code":"arguments_invalid"}
			return flow.open(parameters.step)
	return {"ok":false,"code":"action_missing"}

func _exit_tree() -> void:
	if owns_flow and flow != null: flow.close()
