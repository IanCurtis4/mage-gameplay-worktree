@tool
extends VBoxContainer
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const MapCanvas = preload("res://scripts/map_authoring/preview/map_canvas.gd")
const TerrainCanvas = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
var kind := "map"
var get_source: Callable
var commit_source: Callable
var request: Dictionary = {}
var proposal: Dictionary = {}
var prepared: Dictionary = {}
var job: Thread
var cancelled := false
var mutex := Mutex.new()
var job_kind := ""
var export_path := ""
var sections: LineEdit
var ids: LineEdit
var protected_paths: LineEdit
var brief: TextEdit
var budget: SpinBox
var differences: ItemList
var details: TextEdit
var status: Label
var apply_button: Button
var before_canvas: Control
var after_canvas: Control
var tabs: TabContainer
var dialog: FileDialog
var action := ""
var request_summary: Label
var section_menu: MenuButton
const SECTION_LABELS := {"name":"Nome","revision":"Revisão","layers":"Terreno e camadas","special_surfaces":"Pontes e rampas","placements":"Objetos","regions":"Regiões","connectors":"Conectores","sockets":"Marcadores","dependencies":"Dependências","composition":"Composição","mode":"Modo","barrier_profile":"Perfil de barreira","pieces":"Peças","instances":"Posições das peças","links":"Vínculos","map":"Mapa-base","entrance":"Entrada","brushes":"Pincéis de população","exclusions":"Exclusões","interactions":"Interações","slots":"Slots","plan_hash":"Plano realizado","population":"Encontros-base","patrols":"Patrulhas","seed_text":"Seed","domains":"Candidatos","pins":"Pins","selection":"Regiões selecionadas","quotas":"Quotas","min_diversity":"Diversidade mínima","budget":"Orçamento"}
var confirmation: ConfirmationDialog
## Checkpoint45 (P3c): conflicts of a three-way review and the explicit choices.
var resolutions: Dictionary = {}
var conflicts: Array = []
var choice: OptionButton

static func mount(parent: Control, source_kind: String, getter: Callable, setter: Callable) -> Control:
	var window := Window.new(); window.title = "Intercâmbio · Revisar proposta"; window.size = Vector2i(1220,820); window.min_size = Vector2i(1080,740)
	window.hide()
	parent.add_child(window)
	var panel: Control = load("res://scripts/map_authoring/exchange/exchange_panel.gd").new(); panel.kind = source_kind; panel.get_source = getter; panel.commit_source = setter
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); window.add_child(panel)
	var provider: Node = load("res://scripts/map_authoring/exchange/exchange_ax.gd").new(); provider.panel = panel; provider.screen = source_kind; parent.add_child(provider)
	window.close_requested.connect(func() -> void: panel.cancel(); window.hide())
	var row := HFlowContainer.new(); parent.add_child(row); parent.move_child(row,1)
	var button := Button.new(); button.text = "Intercâmbio com skills…"; row.add_child(button); button.pressed.connect(func() -> void: window.popup_centered())
	return panel
func _ready() -> void:
	var heading := Label.new(); heading.text = "Intercâmbio · Pedido local e proposta de skill"; heading.add_theme_font_size_override("font_size",22); add_child(heading)
	var hint := Label.new(); hint.text = "Exporte um pedido com permissões. Guarde esse original; importe a proposta separadamente.
Revise as diferenças e a prévia antes de confirmar. Aplicar permite desfazer na tela de origem."; add_child(hint)
	var bar := HFlowContainer.new(); add_child(bar)
	button(bar,"Exportar pedido…",func() -> void: choose("export")); button(bar,"Abrir pedido confiável…",func() -> void: choose("request")); button(bar,"Importar proposta…",func() -> void: choose("proposal"))
	button(bar,"Validar e comparar",review); button(bar,"Cancelar / rejeitar",cancel)
	apply_button = button(bar,"Aplicar proposta…",func() -> void: confirmation.popup_centered()); apply_button.disabled = true
	var permissions := HFlowContainer.new(); add_child(permissions)
	section_menu = MenuButton.new(); section_menu.text = "Escolher áreas permitidas…"; permissions.add_child(section_menu)
	sections = LineEdit.new(); sections.visible = false; sections.text = "seed_text" if kind == "generation" else "name"; permissions.add_child(sections)
	var fields: Array = {"piece":Exchange.Schema.ROOT,"map":Exchange.Map.ROOT,"population":Exchange.Population.ROOT,"patrol":Exchange.Patrol.ROOT,"generation":Exchange.Generation.ROOT}[kind].keys()
	for key: String in fields:
		if key in ["schema_version","document_id","units","algorithm_revision"]: continue
		var popup := section_menu.get_popup(); popup.add_check_item(SECTION_LABELS.get(key,key)); popup.set_item_metadata(popup.item_count-1,key); popup.set_item_checked(popup.item_count-1,key in values(sections.text))
	section_menu.get_popup().hide_on_checkable_item_selection = false
	section_menu.get_popup().index_pressed.connect(func(index: int) -> void:
		var popup := section_menu.get_popup(); popup.set_item_checked(index,not popup.is_item_checked(index))
		var selected: Array = []
		for i: int in popup.item_count:
			if popup.is_item_checked(i): selected.append(popup.get_item_metadata(i))
		sections.text = ",".join(selected))
	ids = field(permissions,"IDs permitidos (vazio: todos)","")
	protected_paths = field(permissions,"Caminhos protegidos","")
	var limit_label := Label.new(); limit_label.text = "Máx. diferenças"; permissions.add_child(limit_label)
	budget = SpinBox.new(); budget.min_value = 1; budget.max_value = 2048; budget.value = 256; permissions.add_child(budget); budget.tooltip_text = "Máximo de diferenças permitido no pedido"
	request_summary = Label.new(); request_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; request_summary.text = "Permissões acima valem para o próximo pedido exportado."; add_child(request_summary)
	brief = TextEdit.new(); brief.placeholder_text = "Brief para a skill (sem dados pessoais)"; brief.custom_minimum_size.y = 55; add_child(brief)
	var split := HSplitContainer.new(); split.size_flags_vertical = SIZE_EXPAND_FILL; add_child(split)
	var left := VBoxContainer.new(); left.custom_minimum_size.x = 360; split.add_child(left)
	differences = ItemList.new(); differences.size_flags_vertical = SIZE_EXPAND_FILL; left.add_child(differences); differences.item_selected.connect(select_difference)
	details = TextEdit.new(); details.editable = false; details.custom_minimum_size.y = 180; left.add_child(details)
	var resolve := HFlowContainer.new(); left.add_child(resolve)
	var choice_label := Label.new(); choice_label.text = "Conflito selecionado"; resolve.add_child(choice_label)
	choice = OptionButton.new()
	for caption: String in ["Escolher…","Manter a versão atual","Usar a proposta"]: choice.add_item(caption)
	choice.disabled = true; resolve.add_child(choice); choice.item_selected.connect(set_choice)
	button(resolve,"Revalidar com as escolhas",review)
	tabs = TabContainer.new(); tabs.size_flags_horizontal = SIZE_EXPAND_FILL; split.add_child(tabs)
	before_canvas = TerrainCanvas.new() if kind == "piece" else MapCanvas.new(); before_canvas.name = "Antes"; tabs.add_child(before_canvas)
	after_canvas = TerrainCanvas.new() if kind == "piece" else MapCanvas.new(); after_canvas.name = "Proposta"; tabs.add_child(after_canvas)
	if kind == "piece": before_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE; after_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status); status.text = "Nenhuma proposta aplicada."
	dialog = FileDialog.new(); dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.filters = PackedStringArray(["*.rpx ; Bundle de autoria"]); dialog.file_selected.connect(file_selected); add_child(dialog)
	confirmation = ConfirmationDialog.new(); confirmation.dialog_text = "Aplicar as diferenças revisadas como uma ação desfazível?"; confirmation.confirmed.connect(apply_async); add_child(confirmation)
func button(parent: Node, text: String, callback: Callable) -> Button:
	var control := Button.new(); control.text = text; control.pressed.connect(callback); parent.add_child(control); return control
func field(parent: Node, text: String, value: String) -> LineEdit:
	var label := Label.new(); label.text = text; parent.add_child(label)
	var edit := LineEdit.new(); edit.text = value; edit.custom_minimum_size.x = 160; parent.add_child(edit); return edit
func values(text: String) -> Array:
	var result: Array = []
	for entry: String in text.split(",",false): result.append(entry.strip_edges())
	return result
func choose(value: String) -> void:
	action = value; dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if value == "export" else FileDialog.FILE_MODE_OPEN_FILE; dialog.popup_centered_ratio(0.7)
func file_selected(path: String) -> void:
	if action == "export": export_current(path); return
	var loaded := Exchange.load_json(path)
	if not loaded.ok: show_result(loaded); return
	if action == "request":
		var checked := Exchange.validate_bundle(loaded.data)
		if not checked.ok: show_result(checked); return
		if checked.ticket.kind != kind or loaded.data.source_hash != checked.ticket.base_hash: show_result(Exchange.fail("exchange_not_request")); return
		cancel(); request = loaded.data.duplicate(true); proposal = {}; resolutions = {}; summarize_request(); status.text = "Pedido confiável aberto. Importe a proposta separada."
	elif action == "proposal":
		cancel(); proposal = loaded.data.duplicate(true) if loaded.data is Dictionary else {}; resolutions = {}; review()
func export_current(path: String = "") -> void:
	cancel(); var source: Dictionary = get_source.call(); var permissions := Exchange.policy(values(sections.text),values(ids.text),values(protected_paths.text),int(budget.value)); var message := brief.text
	export_path = path; job_kind = "export"; mutex.lock(); cancelled = false; mutex.unlock(); job = Thread.new()
	job.start(func() -> Dictionary: return Exchange.export_bundle(kind,source,permissions,message,[],is_cancelled))
	status.text = "Validando o pedido…"
func review() -> void:
	cancel()
	if request.is_empty() or proposal.is_empty(): show_result(Exchange.fail("exchange_request_required")); return
	var source: Dictionary = get_source.call(); var local := request.duplicate(true); var incoming := proposal.duplicate(true)
	job_kind = "review"; mutex.lock(); cancelled = false; mutex.unlock(); job = Thread.new()
	# Checkpoint42 (F9-10): the base preview compiles in the same job, not on the UI.
	var base_kind := kind; var chosen := resolutions.duplicate(true)
	job.start(func() -> Dictionary:
		var result := Exchange.prepare(local,incoming,source,is_cancelled,chosen)
		if result.ok and not is_cancelled(): result["base_package"] = Exchange.build(base_kind,local.ticket.base,is_cancelled).get("package",{})
		return result)
	status.text = "Validando a proposta em cópia…"
func _process(_delta: float) -> void:
	if job == null or job.is_alive(): return
	var result: Dictionary = job.wait_to_finish(); job = null
	if cancelled: show_result(Exchange.fail("cancelled")); return
	if not result.ok and result.get("code","") == "exchange_conflict" and job_kind == "review": show_review(result); return
	if not result.ok: show_result(result); return
	if job_kind == "apply":
		finish_apply(result); return
	if job_kind == "export":
		var saved := Exchange.save_json(export_path,result.bundle)
		if not saved.ok: show_result(saved); return
		request = result.bundle; proposal = {}; summarize_request(); status.text = "Pedido exportado. Preserve este original. Hash compilado: "+result.output_hash
	else:
		var current: Dictionary = get_source.call(); var checked := Exchange.read(kind,current)
		if not checked.ok or checked.output_hash != result.current_hash: show_result(Exchange.fail("stale_source")); return
		show_review(result)
## A review result: the differences, or the conflicts that need a choice.
func show_review(result: Dictionary) -> void:
	differences.clear(); details.text = ""; conflicts = []; choice.disabled = true
	if not result.ok and result.get("code","") == "exchange_conflict":
		prepared = {}; apply_button.disabled = true; conflicts = result.conflicts.duplicate(true)
		for conflict: Dictionary in conflicts:
			var label: String = {"protection":"Proteção atual","value":"Conflito","structure":"Estrutura"}.get(conflict.kind,"Conflito")
			var chosen: String = {"current":" · manter atual","proposal":" · usar proposta"}.get(resolutions.get(conflict.path,""),"")
			differences.add_item(label+" · "+conflict.path+chosen)
		status.text = result.diagnostics[0].message
		return
	if not result.ok: show_result(result); return
	prepared = result
	for change: Dictionary in result.diff: differences.add_item({"replace":"Alterar","add":"Adicionar","remove":"Remover"}[change.operation]+" · "+change.path)
	apply_button.disabled = result.already_applied
	if not result.get("package",{}).is_empty():
		preview(before_canvas,request.ticket.base,result.get("base_package",{}))
		preview(after_canvas,result.source,result.package)
	var merged := ""
	if result.has("merge"): merged = " · combinada com a versão atual: %d da proposta, %d iguais, %d mantidas como estão"%[result.merge.applied.size(),result.merge.agreed.size(),result.merge.kept_current.size()]
	status.text = "%d diferenças · %s · hash compilado %s%s"%[result.diff.size(),"já aplicada" if result.already_applied else "pronta para revisão",result.output_hash,merged]
func set_choice(index: int) -> void:
	var selected := differences.get_selected_items()
	if selected.is_empty() or selected[0] >= conflicts.size(): return
	var path: String = conflicts[selected[0]].path
	if index == 0: resolutions.erase(path)
	else: resolutions[path] = "current" if index == 1 else "proposal"
	var label: String = {"protection":"Proteção atual","value":"Conflito","structure":"Estrutura"}.get(conflicts[selected[0]].kind,"Conflito")
	differences.set_item_text(selected[0],label+" · "+path+{"current":" · manter atual","proposal":" · usar proposta"}.get(resolutions.get(path,""),""))
func summarize_request() -> void:
	var permission: Dictionary = request.ticket.policy; var labels: Array = []
	for key: String in permission.sections: labels.append(SECTION_LABELS.get(key,key))
	request_summary.text = "Pedido aberto · áreas: %s · IDs: %s · máx. %d diferenças · %d caminhos protegidos"%[", ".join(labels),"todos" if permission.ids.is_empty() else ",".join(permission.ids),permission.max_changes,permission.protected_paths.size()]
	request_summary.tooltip_text = "Base: "+request.ticket.base_hash+"\nPermissões do pedido guardado; os controles acima só afetam nova exportação."
func preview(canvas: Control, source: Dictionary, package: Dictionary) -> void:
	if package.is_empty(): return
	if kind == "piece":
		canvas.set_source(source,"" if source.layers.is_empty() else source.layers[0].layer_id); canvas.package = package; canvas.redraw_terrain(); canvas.fit()
	else:
		if kind == "population": package = package.map_package
		if kind == "patrol": package = package.population_package.map_package
		canvas.set_package(package)
func select_difference(index: int) -> void:
	if not conflicts.is_empty() and index >= 0 and index < conflicts.size():
		var conflict: Dictionary = conflicts[index]
		details.text = "Base:\n"+JSON.stringify(conflict.base,"\t",true,true)+"\nVersão atual:\n"+JSON.stringify(conflict.current,"\t",true,true)+"\nProposta:\n"+JSON.stringify(conflict.proposal,"\t",true,true)
		if conflict.kind == "protection": details.text += "\n\nUma proteção da versão atual prevalece: só é possível manter a atual."
		choice.disabled = false; choice.set_item_disabled(2,conflict.kind == "protection")
		choice.select({"current":1,"proposal":2}.get(resolutions.get(conflict.path,""),0))
		return
	if index < 0 or index >= prepared.get("diff",[]).size(): return
	var change: Dictionary = prepared.diff[index]; details.text = "Antes:\n"+JSON.stringify(change.before,"\t",true,true)+"\nProposta:\n"+JSON.stringify(change.after,"\t",true,true)
	if kind != "piece": before_canvas.selected_instance = change.entity_id; after_canvas.selected_instance = change.entity_id; before_canvas.redraw(); after_canvas.redraw()
func apply_result() -> Dictionary:
	if prepared.is_empty() or request.is_empty() or proposal.is_empty(): return Exchange.fail("exchange_review_required")
	var current: Dictionary = get_source.call()
	var checked := Exchange.read(kind,current)
	if not checked.ok or checked.output_hash != prepared.current_hash: show_result(Exchange.fail("stale_source")); return Exchange.fail("stale_source")
	var result := Exchange.apply_to(request,proposal,current,commit_source,resolutions)
	show_result(result); apply_button.disabled = true
	return result
# Checkpoint42 (F9-10): the confirmation button applies like apply_result (same
# recheck and compilation of the proposal), with the compilation on a worker
# thread; the commit itself and the stale check stay on the UI thread.
# apply_result() remains the synchronous path used by AX/tests.
func apply_async() -> void:
	if prepared.is_empty() or request.is_empty() or proposal.is_empty(): show_result(Exchange.fail("exchange_review_required")); return
	if job != null: return
	var current: Dictionary = get_source.call()
	var checked := Exchange.read(kind,current)
	if not checked.ok or checked.output_hash != prepared.current_hash: show_result(Exchange.fail("stale_source")); return
	var local := request.duplicate(true); var incoming := proposal.duplicate(true); var snapshot := current.duplicate(true); var chosen := resolutions.duplicate(true)
	apply_button.disabled = true
	job_kind = "apply"; mutex.lock(); cancelled = false; mutex.unlock(); job = Thread.new()
	job.start(func() -> Dictionary: return Exchange.prepare(local,incoming,snapshot,is_cancelled,chosen))
	status.text = "Compilando a proposta para aplicar…"
func finish_apply(result: Dictionary) -> void:
	if not result.ok or result.get("already_applied",false): show_result(result); return
	var current: Dictionary = get_source.call()
	var checked := Exchange.read(kind,current)
	if not checked.ok or checked.output_hash != result.current_hash: show_result(Exchange.fail("stale_source")); return
	var applied: Dictionary = commit_source.call(result.source.duplicate(true))
	show_result(result if applied.ok else applied); apply_button.disabled = true
func is_cancelled(_progress: float = 0.0) -> bool:
	mutex.lock(); var value := cancelled; mutex.unlock(); return value
func cancel() -> void:
	if confirmation != null: confirmation.hide()
	mutex.lock(); cancelled = true; mutex.unlock(); prepared = {}
	if job != null: job.wait_to_finish(); job = null
	if apply_button != null: apply_button.disabled = true
	conflicts = []
	if differences != null: differences.clear(); details.text = ""
	if status != null: status.text = "Proposta rejeitada ou cancelada; autoria preservada."
func show_result(value: Dictionary) -> void:
	var reason: String = value.get("diagnostics",[{}])[0].get("message","") if not value.ok and not value.get("diagnostics",[]).is_empty() else ""
	status.text = ("Proposta aplicada; use Desfazer na tela de origem. Hash: "+value.output_hash) if value.ok else "Intercâmbio recusado: "+value.code+(" · "+reason if not reason.is_empty() and not reason.ends_with(value.code) else "")
	if not value.ok: prepared = {}; apply_button.disabled = true
func _exit_tree() -> void:
	if job != null: job.wait_to_finish(); job = null
