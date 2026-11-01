@tool
extends VBoxContainer
## Checkpoint49 (F9-06/07, P6a): the step bar at the top of the terrain, map,
## encounter and patrol screens. Shows every step of authoring_flow.gd with its
## state, marks the screen the person is on, runs the next step, reviews a carry
## before applying it (one undoable change) and opens the screen that owns a
## problem with its entity focused. Not collected into the screen menus; its own
## AX provider: <screen>/workflow/{state,next,apply,discard,show,open}.
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
var _dirty := true
var _clock := 0.0
var _shown: Dictionary = {}

static func mount(parent: Control, shared: RefCounted, step: String, screen_id: String, owner: bool) -> VBoxContainer:
	var bar: VBoxContainer = load("res://scripts/map_authoring/workflow/workflow_bar.gd").new()
	bar.setup(shared,step,screen_id,owner)
	parent.add_child(bar); parent.move_child(bar,0)
	return bar

func setup(shared: RefCounted, step: String, screen_id: String, owner: bool) -> void:
	flow = shared; step_id = step; screen = screen_id; owns_flow = owner; name = "AuthoringWorkflow"
	set_meta("authoring_command_provider",true); set_meta("authoring_skip_collect",true)
	var row := HFlowContainer.new(); add_child(row)
	var title := Label.new(); title.text = "Roteiro do mapa"; row.add_child(title)
	for index: int in Flow.ORDER.size():
		var id: String = Flow.ORDER[index]
		var button := Button.new(); button.toggle_mode = true; button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: button.set_pressed_no_signal(id == step_id); flow.open(id))
		row.add_child(button); step_buttons[id] = button
	var actions := HFlowContainer.new(); add_child(actions)
	var label := Label.new(); label.text = "Próximo passo:"; actions.add_child(label)
	next_button = Button.new(); next_button.pressed.connect(func() -> void: run_next()); actions.add_child(next_button)
	show_button = Button.new(); show_button.text = "Mostrar o problema"; show_button.pressed.connect(func() -> void: show_problem()); actions.add_child(show_button)
	cancel_button = Button.new(); cancel_button.text = "Cancelar atualização"; cancel_button.pressed.connect(func() -> void: flow.cancel()); actions.add_child(cancel_button)
	detail = Label.new(); detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(detail)
	confirmation = ConfirmationDialog.new(); confirmation.title = "Atualizar a etapa"; add_child(confirmation)
	confirmation.ok_button_text = "Aplicar (um desfazer)"; confirmation.cancel_button_text = "Descartar"
	confirmation.confirmed.connect(func() -> void: flow.apply_pending(String(confirmation.get_meta("proposal_hash",""))))
	confirmation.canceled.connect(func() -> void: flow.discard_pending())
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
	if flow.job != null: detail.text = "Atualizando %s em segundo plano; a tela continua livre." % String(Flow.TITLES.get(Flow.CARRIES.get(flow.job_action,""),"a etapa")).to_lower()
	elif not problem.is_empty(): detail.text = "%s · %s" % [Flow.TITLES.get(problem.step,""),problem.get("message","")]
	elif not next.is_empty(): detail.text = "%s · %s" % [next.title,next.detail]
	else: detail.text = "Todas as etapas estão prontas para esta revisão."

func _problem() -> Dictionary:
	for id: String in ["piece","map","population","patrol"]:
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
	if result.get("confirmation_required",false): _confirm(result)
	refresh()
	return result

func _confirm(result: Dictionary) -> void:
	# The screen that receives the change asks for it.
	var bar: Node = flow.panel(result.kind).get_node_or_null("AuthoringWorkflow") if flow.panel(result.kind) != null else null
	var target: VBoxContainer = bar if bar != null else self
	target.confirmation.dialog_text = String(result.summary)+"\n\nAplicar como uma ação desfazível?"
	target.confirmation.set_meta("proposal_hash",result.proposal_hash)
	target.confirmation.popup_centered()

func show_problem() -> Dictionary:
	var problem := _problem()
	return flow.show(problem) if not problem.is_empty() else {"ok":false,"code":"flow_no_problem"}

func authoring_commands() -> Array:
	var prefix := screen+"/workflow/"
	return [{"id":prefix+"state","parameters":{}},{"id":prefix+"next","parameters":{"action":"string"}},{"id":prefix+"apply","parameters":{"proposal_hash":"sha256"}},{"id":prefix+"discard","parameters":{}},{"id":prefix+"show","parameters":{"step":"string"}},{"id":prefix+"open","parameters":{"step":"string"}}]

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
		"open":
			if parameters.size() != 1 or not parameters.get("step") is String or parameters.step not in Flow.ORDER: return {"ok":false,"code":"arguments_invalid"}
			return flow.open(parameters.step)
	return {"ok":false,"code":"action_missing"}

func _exit_tree() -> void:
	if owns_flow and flow != null: flow.close()
