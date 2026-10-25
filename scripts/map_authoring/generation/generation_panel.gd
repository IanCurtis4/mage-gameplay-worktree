@tool
extends VBoxContainer
const Document = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Solver = preload("res://scripts/map_authoring/generation/generation_solver.gd")
const Adapter = preload("res://scripts/map_authoring/generation/assembler_adapter.gd")
const Store = preload("res://scripts/map_authoring/generation/generation_store.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Canvas = preload("res://scripts/map_authoring/preview/map_canvas.gd")
var source: Dictionary = {}
var target: RefCounted
var result: Dictionary = {}
var job: RefCounted
var comparison_thread: Thread
var comparison_hash := ""
var comparison_cancelled := false
var comparison: Dictionary = {}
var _undo: Array = []
var _redo: Array = []
var _updating := false
var _path := ""
var _expected := ""
var _draft := ""
var _dialog: FileDialog
var _file_action := ""
var slots: ItemList
var candidates: ItemList
var pieces: OptionButton
var rotation_choice: OptionButton
var weight: SpinBox
var seed: LineEdit
var enabled: CheckBox
var pin: CheckBox
var regenerate: CheckBox
var diversity: SpinBox
var quota_min: SpinBox
var quota_max: SpinBox
var quota_list: ItemList
var status: Label
var differences: ItemList
var before_canvas: Control
var after_canvas: Control
var apply_button: Button
var history_list: ItemList
var history: Array = []

var exchange_panel: Control
func _ready() -> void:
	exchange_panel = preload("res://scripts/map_authoring/exchange/exchange_panel.gd").mount(self,"generation",func() -> Dictionary: return source.duplicate(true),change)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Label.new(); heading.text = "Geração assistida · Regiões fixas e variantes"; heading.add_theme_font_size_override("font_size",22); add_child(heading)
	var toolbar := HFlowContainer.new(); add_child(toolbar)
	for entry: Array in [["Reimportar composição",reimport_map],["Abrir pedido…",func() -> void: choose("open")],["Salvar pedido…",func() -> void: choose("save")],["Recuperar rascunho",recover],["Desfazer pedido",undo],["Refazer pedido",redo]]: button(toolbar,entry[0],entry[1])
	var actions := HFlowContainer.new(); add_child(actions)
	var label := Label.new(); label.text = "Seed"; actions.add_child(label)
	seed = LineEdit.new(); seed.custom_minimum_size.x = 210; actions.add_child(seed)
	seed.text_submitted.connect(update_seed)
	seed.focus_exited.connect(func() -> void: update_seed(seed.text))
	enabled = CheckBox.new(); enabled.text = "Ativar WFC experimental"; actions.add_child(enabled)
	button(actions,"Gerar prévia",generate); button(actions,"Cancelar",cancel)
	button(actions,"Comparar assembler atual",compare_assembler)
	apply_button = button(actions,"Aplicar proposta ao mapa",apply_result); apply_button.disabled = true
	var hint := Label.new(); hint.text = "Posições e vínculos permanecem fixos. Só as regiões marcadas para regenerar recebem variantes.\nRegiões fixas preservam a instância inteira. O WFC é opcional; cada resultado passa pela geometria e pelas rotas atuais."; add_child(hint)
	var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(split)
	var inspector := VBoxContainer.new(); inspector.custom_minimum_size.x = 370; split.add_child(inspector)
	slots = ItemList.new(); slots.custom_minimum_size.y = 110; inspector.add_child(slots); slots.item_selected.connect(func(_i: int) -> void: refresh_slot())
	var toggles := HBoxContainer.new(); inspector.add_child(toggles)
	pin = CheckBox.new(); pin.text = "Fixar região"; toggles.add_child(pin); pin.toggled.connect(func(on: bool) -> void: toggle_flag("pins",on))
	regenerate = CheckBox.new(); regenerate.text = "Regenerar região"; toggles.add_child(regenerate); regenerate.toggled.connect(func(on: bool) -> void: toggle_flag("selection",on))
	candidates = ItemList.new(); candidates.custom_minimum_size.y = 85; inspector.add_child(candidates)
	pieces = OptionButton.new(); inspector.add_child(pieces)
	var variant := HBoxContainer.new(); inspector.add_child(variant)
	rotation_choice = OptionButton.new(); for degrees: int in [0,90,180,270]: rotation_choice.add_item("%d°"%degrees)
	variant.add_child(rotation_choice); weight = number(variant,"Peso",1,100)
	button(variant,"Adicionar candidato",add_candidate)
	button(inspector,"Remover candidato selecionado",remove_candidate)
	var constraints := HBoxContainer.new(); inspector.add_child(constraints)
	diversity = number(constraints,"Peças distintas mín.",1,16); diversity.value_changed.connect(func(value: float) -> void:
		if not _updating and not source.is_empty():
			var data := source.duplicate(true); data.min_diversity = int(value); change(data))
	var quota := HBoxContainer.new(); inspector.add_child(quota)
	quota_min = number(quota,"Quota mín.",0,16); quota_max = number(quota,"máx.",0,16); quota_max.value = 16
	button(inspector,"Definir quota da peça escolhida",set_quota)
	quota_list = ItemList.new(); quota_list.custom_minimum_size.y = 65; inspector.add_child(quota_list)
	button(inspector,"Remover quota selecionada",remove_quota)
	var tabs := TabContainer.new(); tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(tabs)
	before_canvas = Canvas.new(); before_canvas.name = "Antes"; tabs.add_child(before_canvas)
	after_canvas = Canvas.new(); after_canvas.name = "Proposta"; tabs.add_child(after_canvas)
	differences = ItemList.new(); differences.custom_minimum_size.y = 85; add_child(differences); differences.item_selected.connect(focus_difference)
	history_list = ItemList.new(); history_list.custom_minimum_size.y = 50; history_list.tooltip_text = "Selecione uma seed anterior para restaurar o pedido e inspecionar sua proposta."; add_child(history_list); history_list.item_selected.connect(select_history)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	_dialog = FileDialog.new(); _dialog.access = FileDialog.ACCESS_FILESYSTEM; _dialog.file_selected.connect(file_selected); add_child(_dialog)
	new_draft_path()
	var timer := Timer.new(); timer.wait_time = 10; timer.autostart = true; timer.timeout.connect(preserve); add_child(timer)
	if source.is_empty() and target != null: show_result(import_map(target.data))
	elif not source.is_empty(): refresh()

func button(parent: Node, text: String, callback: Callable) -> Button:
	var control := Button.new(); control.text = text; control.pressed.connect(callback); parent.add_child(control); return control
func number(parent: Node, text: String, low: int, high: int) -> SpinBox:
	var label := Label.new(); label.text = text; parent.add_child(label)
	var spin := SpinBox.new(); spin.min_value = low; spin.max_value = high; spin.step = 1; spin.value = low; spin.custom_minimum_size.x = 65; parent.add_child(spin); return spin
func import_map(map: Dictionary) -> Dictionary:
	var checked := Map.validate(map)
	if not checked.ok: return checked
	var data := Document.from_map(map); checked = Document.validate(data)
	if checked.ok:
		preserve(); source = data; _undo.clear(); _redo.clear()
		if is_node_ready(): new_draft_path(); refresh()
	return checked
func new_draft_path() -> void:
	_draft = ProjectSettings.globalize_path("res://.godot/map_authoring/generation_"+Crypto.new().generate_random_bytes(10).hex_encode()+".json")
	DirAccess.make_dir_recursive_absolute(_draft.get_base_dir())
func reimport_map() -> void:
	if target != null: show_result(import_map(target.data))
func preserve() -> void:
	if not _draft.is_empty() and not source.is_empty():
		var saved := Store.save_source(_draft,source,IO.disk_hash(_draft))
		if not saved.ok: status.text = "Falha ao preservar rascunho: "+saved.code
func recover() -> void:
	var loaded := Store.load_source(_draft)
	if loaded.ok: change(loaded.data)
	else: show_result(loaded)
func change(data: Dictionary) -> Dictionary:
	var checked := Document.validate(data)
	if not checked.ok: show_result(checked); return checked
	if Document.hash_source(data) != Document.hash_source(source):
		_undo.append(source.duplicate(true)); if _undo.size() > 32: _undo.pop_front()
		_redo.clear(); source = data.duplicate(true); refresh()
	return checked
func undo() -> void:
	if _undo.is_empty(): return
	_redo.append(source); source = _undo.pop_back(); refresh()
func redo() -> void:
	if _redo.is_empty(): return
	_undo.append(source); source = _redo.pop_back(); refresh()
func refresh() -> void:
	cancel(); result = {}; comparison = {}; apply_button.disabled = true; after_canvas.clear(); before_canvas.clear(); differences.clear()
	var selected := selected_id(); _updating = true; slots.clear(); pieces.clear(); quota_list.clear()
	seed.text = source.seed_text; diversity.value = source.min_diversity
	for instance: Dictionary in source.map.instances: slots.add_item(instance.instance_id+(" · fixa" if instance.instance_id in source.pins else ""))
	for piece: Dictionary in source.map.pieces:
		pieces.add_item(piece.source.name+" · "+piece.piece_hash.substr(0,8)); pieces.set_item_metadata(pieces.item_count-1,piece.piece_hash)
	for quota: Dictionary in source.quotas: quota_list.add_item(quota.piece_hash.substr(0,8)+" · %d–%d"%[quota.min,quota.max])
	for i: int in source.map.instances.size():
		if source.map.instances[i].instance_id == selected: slots.select(i)
	if slots.get_selected_items().is_empty() and slots.item_count > 0: slots.select(0)
	_updating = false; refresh_slot(); status.text = "Pedido alterado; gere uma prévia para validar."
func selected_id() -> String:
	if slots == null or slots.get_selected_items().is_empty() or source.is_empty(): return ""
	var index: int = slots.get_selected_items()[0]
	return source.map.instances[index].instance_id if index < source.map.instances.size() else ""
func domain(data: Dictionary, id: String) -> Dictionary: return Compiler._find(data.domains,"instance_id",id)
func refresh_slot() -> void:
	var id := selected_id(); _updating = true; candidates.clear()
	if not id.is_empty():
		pin.button_pressed = id in source.pins; regenerate.button_pressed = id in source.selection
		for option: Dictionary in domain(source,id).options: candidates.add_item(option.piece_hash.substr(0,8)+" · %d° · peso %d"%[int(option.rotation_quarters)*90,option.weight])
	_updating = false
func toggle_flag(field: String, on: bool) -> void:
	if _updating or selected_id().is_empty(): return
	var data := source.duplicate(true); var id := selected_id()
	if on and id not in data[field]: data[field].append(id)
	elif not on: data[field].erase(id)
	change(data)
func add_candidate() -> void:
	if selected_id().is_empty() or pieces.selected < 0: return
	var data := source.duplicate(true); var options: Array = domain(data,selected_id()).options
	var added := {"piece_hash":pieces.get_item_metadata(pieces.selected),"rotation_quarters":rotation_choice.selected,"weight":int(weight.value)}
	var found := false
	for option: Dictionary in options:
		if Document.option_key(option) == Document.option_key(added): option.weight = added.weight; found = true
	if not found: options.append(added)
	change(data)
func remove_candidate() -> void:
	if selected_id().is_empty() or candidates.get_selected_items().is_empty(): return
	var data := source.duplicate(true); domain(data,selected_id()).options.remove_at(candidates.get_selected_items()[0]); change(data)
func set_quota() -> void:
	if pieces.selected < 0: return
	var data := source.duplicate(true); var hash_value: String = pieces.get_item_metadata(pieces.selected)
	data.quotas = data.quotas.filter(func(q: Dictionary) -> bool: return q.piece_hash != hash_value)
	data.quotas.append({"piece_hash":hash_value,"min":int(quota_min.value),"max":int(quota_max.value)}); change(data)
func remove_quota() -> void:
	if quota_list.get_selected_items().is_empty(): return
	var data := source.duplicate(true); data.quotas.remove_at(quota_list.get_selected_items()[0]); change(data)
func generate() -> void:
	if source.is_empty() or job != null or comparison_thread != null: return
	update_seed(seed.text)
	if seed.text != source.seed_text: return
	result = {}; apply_button.disabled = true; after_canvas.clear(); differences.clear()
	job = Solver.new(); job.start(source,enabled.button_pressed); status.text = "Gerando e validando emendas/rotas…"
func update_seed(value: String) -> void:
	if _updating or source.is_empty() or value == source.seed_text: return
	var data := source.duplicate(true); data.seed_text = value; change(data)
func cancel() -> void:
	if job != null: job.cancel()
	comparison_cancelled = true
func compare_assembler() -> void:
	if source.is_empty() or job != null or comparison_thread != null: return
	comparison_cancelled = false; comparison_hash = Document.hash_source(source)
	var copy := source.duplicate(true); comparison_thread = Thread.new()
	comparison_thread.start(func() -> Dictionary: return Adapter.build(copy)); status.text = "Comparando o assembler atual; cancelamento descarta seu retorno."
func _process(_delta: float) -> void:
	if comparison_thread != null and not comparison_thread.is_alive():
		comparison = comparison_thread.wait_to_finish(); comparison_thread = null
		if comparison_cancelled or Document.hash_source(source) != comparison_hash: comparison = Document.fail("cancelled" if comparison_cancelled else "stale_source")
		status.text = "Assembler atual: "+("proposta válida" if comparison.ok else str(comparison.code))+". WFC continua opcional."
	if job == null or not job.ready(): return
	result = job.take(Document.hash_source(source)); job = null; show_result(result)
	if result.ok:
		history.append({"source":source.duplicate(true),"result":result.duplicate(true)})
		if history.size() > 8: history.pop_front()
		history_list.clear()
		for item: Dictionary in history: history_list.add_item("Seed "+item.source.seed_text+" · "+item.result.output_hash.substr(0,12)+" · %d alterações"%item.result.diff.size())
		present_result()
func select_history(index: int) -> void:
	var item: Dictionary = history[index].duplicate(true)
	change(item.source); result = item.result; present_result()
func present_result() -> void:
	after_canvas.set_package(result.package); apply_button.disabled = target == null
	differences.clear()
	for entry: Dictionary in result.diff:
		differences.add_item(entry.instance_id+": "+entry.before.piece_hash.substr(0,8)+" → "+entry.after.piece_hash.substr(0,8)+" · %d° → %d°"%[entry.before.rotation_quarters*90,entry.after.rotation_quarters*90]); differences.set_item_metadata(differences.item_count-1,entry.instance_id)
	if result.diff.is_empty(): differences.add_item("Sem mudanças: todas as restrições foram preservadas.")
	status.text = "%d alterações · seed %s · %d passos de busca · %d retornos · %d verificações. Revise antes de aplicar."%[result.diff.size(),source.seed_text,result.diagnostic.operations,result.diagnostic.backtracks,result.diagnostic.validations]
	if result.has("before_package"): before_canvas.set_package(result.before_package)
func apply_result() -> Dictionary:
	if target == null: return Document.fail("stale_source")
	var applied := Solver.apply_proposal(result,target); show_result(applied)
	if applied.ok: apply_button.disabled = true; status.text = "Proposta aplicada em uma ação. Desfaça/refaça na composição."
	return applied
func show_result(value: Dictionary) -> void:
	if value.ok: return
	status.text = value.get("code","Falha")
	differences.clear()
	for diagnostic: Dictionary in value.get("diagnostics",[]):
		status.text += " · "+diagnostic.message+" "+str(diagnostic.entity_id)+" / "+str(diagnostic.field)
		differences.add_item(diagnostic.message+" · "+str(diagnostic.entity_id)+" / "+str(diagnostic.field)); differences.set_item_metadata(differences.item_count-1,str(diagnostic.entity_id))
func focus_difference(index: int) -> void:
	var id: Variant = differences.get_item_metadata(index)
	for i: int in source.get("map",{}).get("instances",[]).size():
		if source.map.instances[i].instance_id == id: slots.select(i); refresh_slot(); before_canvas.selected_instance = id; after_canvas.selected_instance = id; before_canvas.redraw(); after_canvas.redraw()
func choose(action: String) -> void:
	_file_action = action; _dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action == "open" else FileDialog.FILE_MODE_SAVE_FILE; _dialog.filters = PackedStringArray(["*.json ; Pedido de geração"]); _dialog.popup_centered_ratio(0.75)
func file_selected(path: String) -> void:
	if _file_action == "open":
		var loaded := Store.load_source(path)
		if loaded.ok:
			preserve(); new_draft_path(); source = loaded.data; _undo.clear(); _redo.clear(); _path = path; _expected = IO.disk_hash(path); refresh()
		else: show_result(loaded)
	else:
		var saved := Store.save_source(path,source,_expected if path == _path else "")
		if saved.ok: _path = path; _expected = IO.disk_hash(path); status.text = "Pedido salvo."
		else: show_result(saved)
func _exit_tree() -> void:
	if job != null: job.close(); job = null
	if comparison_thread != null: comparison_thread.wait_to_finish(); comparison_thread = null
	preserve()
