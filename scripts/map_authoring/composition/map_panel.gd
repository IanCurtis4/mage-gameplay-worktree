@tool
extends VBoxContainer
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
const RootSynthesisSection = preload("res://scripts/map_authoring/synthesis/root_synthesis_section.gd")
const Session = preload("res://scripts/map_authoring/composition/map_session.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Store = preload("res://scripts/map_authoring/composition/map_store.gd")
const PieceStore = preload("res://scripts/map_authoring/io/source_store.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Canvas = preload("res://scripts/map_authoring/preview/map_canvas.gd")
const Population = preload("res://scripts/map_authoring/population/population_panel.gd")
const Generation = preload("res://scripts/map_authoring/generation/generation_panel.gd")
const BorderOperations = preload("res://scripts/map_authoring/composition/border_operations.gd")
const BorderCatalog = preload("res://scripts/map_authoring/composition/border_profile_catalog.gd")
const Library = preload("res://scripts/map_authoring/library/library_model.gd")
const Operations = preload("res://scripts/map_authoring/composition/map_operations.gd")
var generation_window: Window
var population_window: Window
const Flow = preload("res://scripts/map_authoring/workflow/authoring_flow.gd")
const WorkflowBar = preload("res://scripts/map_authoring/workflow/workflow_bar.gd")
var gameplay_tools: Control
var flow: RefCounted
var workflow_bar: VBoxContainer
var session := Session.new()
var canvas: Control
var job: RefCounted
var result: Dictionary = {}
var source_path := ""
var expected_hash := ""
var instances: ItemList
var problems: ItemList
var status: Label
var x: SpinBox
var z: SpinBox
var rotation_choice: OptionButton
var mode: OptionButton
var surface: OptionButton
var port_a: OptionButton
var port_b: OptionButton
var links: ItemList
var _endpoints: Array = []
var _dialog: FileDialog
var _file_action := ""
var _pending_remove := ""
var _confirmation: ConfirmationDialog
var _autosave := ""
var exchange_panel: Control
var border_choice: OptionButton
var border_decorations: CheckButton
var transition_target: OptionButton
var context_panel: Control
var name_edit: LineEdit
var _replace_confirmation: ConfirmationDialog
var _replace_action: Callable
var inspector_scroll: ScrollContainer
func _ready() -> void:
	exchange_panel = preload("res://scripts/map_authoring/exchange/exchange_panel.gd").mount(self,"map",func() -> Dictionary: return session.data.duplicate(true),session.apply)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Label.new(); heading.text = "Composição de mapas · Peças, vínculos e teste"; heading.add_theme_font_size_override("font_size",22); add_child(heading)
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	for entry: Array in [["Novo mapa",request_new_map],["Abrir…",func() -> void: choose("open")],["Salvar como…",func() -> void: choose("save")],["Adicionar peça…",func() -> void: choose("piece")],["Exemplo com duas peças",sample],["Desfazer",func() -> void: history(false)],["Refazer",func() -> void: history(true)]]: _button(toolbar,entry[0],entry[1])
	var caption := HBoxContainer.new(); add_child(caption)
	name_edit = LineEdit.new(); name_edit.placeholder_text = "Nome do mapa"; name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; caption.add_child(name_edit)
	name_edit.text_submitted.connect(func(value: String) -> void: rename_document(value))
	_button(caption,"Aplicar nome",func() -> void: rename_document(name_edit.text))
	var actions := HBoxContainer.new(); add_child(actions)
	mode = OptionButton.new(); mode.add_item("Manual · posições fixadas"); mode.add_item("Receita · encaixe por árvore"); actions.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void:
		var applied := apply_operation("mode/set",{"mode":"manual" if index == 0 else "recipe"})
		if not applied.ok: mode.select(0 if session.data.mode == "manual" else 1)
		show_result(applied))
	_button(actions,"Compilar mapa",bake); _button(actions,"Cancelar",func() -> void:
		if job != null: job.cancel())
	_button(actions,"Testar / parar",toggle_test); _button(actions,"Publicar localmente…",func() -> void: choose("publish"))
	_button(actions,"Recuperar rascunho",recover)
	_button(actions,"Encontros…",open_population)
	_button(actions,"Geração assistida…",open_generation)
	var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(split)
	inspector_scroll = ScrollContainer.new(); inspector_scroll.custom_minimum_size.x = 310; inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; inspector_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; split.add_child(inspector_scroll)
	var inspector := VBoxContainer.new(); inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL; inspector.custom_minimum_size.x = 290; inspector_scroll.add_child(inspector)
	instances = ItemList.new(); instances.custom_minimum_size.y = 100; inspector.add_child(instances); instances.item_selected.connect(select_instance)
	var placement := HBoxContainer.new(); inspector.add_child(placement)
	x = _number(placement,"X"); z = _number(placement,"Z")
	rotation_choice = OptionButton.new(); for degrees: int in [0,90,180,270]: rotation_choice.add_item("%d°"%degrees)
	placement.add_child(rotation_choice)
	var placement_actions := HBoxContainer.new(); inspector.add_child(placement_actions)
	_button(placement_actions,"Aplicar posição",apply_placement); _button(placement_actions,"Remover…",request_remove)
	var border_label := Label.new(); border_label.text = "Borda da peça selecionada"; inspector.add_child(border_label)
	border_choice = OptionButton.new(); border_choice.add_item("Herdar perfil do mapa"); border_choice.set_item_metadata(0,"")
	border_choice.add_item("Ruína técnica"); border_choice.set_item_metadata(1,BorderOperations.LEGACY)
	var catalog := BorderCatalog.load_catalog()
	if catalog.ok:
		for id: String in BorderCatalog.IDS:
			border_choice.add_item(catalog.definitions[id].name); border_choice.set_item_metadata(border_choice.item_count-1,id)
	inspector.add_child(border_choice); _button(inspector,"Aplicar borda à peça",apply_border_choice)
	_button(inspector,"Aplicar borda a todas as peças",apply_all_borders)
	border_decorations = CheckButton.new(); border_decorations.text = "Vegetação e escombros das bordas"; inspector.add_child(border_decorations)
	border_decorations.toggled.connect(func(enabled: bool) -> void: _border_command({"operation":"set_decorations","enabled":enabled}))
	transition_target = OptionButton.new(); inspector.add_child(transition_target)
	_button(inspector,"Ligar por talude de transição",apply_border_transition)
	var label := Label.new(); label.text = "Aberturas a vincular"; inspector.add_child(label)
	port_a = OptionButton.new(); port_b = OptionButton.new(); inspector.add_child(port_a); inspector.add_child(port_b)
	_button(inspector,"Vincular aberturas",add_link)
	links = ItemList.new(); links.custom_minimum_size.y = 80; inspector.add_child(links)
	_button(inspector,"Remover vínculo selecionado",remove_link)
	var hint := Label.new(); hint.text = "Bordas fecham o perímetro e preservam as aberturas vinculadas.\nClique numa peça para selecionar. No teste, clique para andar.\nEscolha a superfície para testar pisos sobrepostos."; hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; inspector.add_child(hint)
	surface = OptionButton.new(); inspector.add_child(surface); surface.item_selected.connect(func(index: int) -> void: canvas.selected_surface = "" if index == 0 else surface.get_item_text(index))
	canvas = Canvas.new(); split.add_child(canvas); canvas.selected.connect(select_id); canvas.status.connect(func(message: String) -> void: status.text = message)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	problems = ItemList.new(); problems.custom_minimum_size.y = 65; add_child(problems); problems.item_selected.connect(focus_problem)
	_dialog = FileDialog.new(); _dialog.access = FileDialog.ACCESS_FILESYSTEM; _dialog.file_selected.connect(file_selected); _dialog.dir_selected.connect(file_selected); add_child(_dialog)
	_confirmation = ConfirmationDialog.new(); add_child(_confirmation); _confirmation.confirmed.connect(remove_instance)
	_replace_confirmation = ConfirmationDialog.new(); add_child(_replace_confirmation)
	_replace_confirmation.dialog_text = "Preservar o rascunho e substituir a composição atual?"
	_replace_confirmation.confirmed.connect(func() -> void:
		if _replace_action.is_valid(): _replace_action.call()
		_replace_action = Callable())
	_new_draft_path()
	session.changed.connect(refresh)
	var timer := Timer.new(); timer.wait_time = 10; timer.autostart = true; timer.timeout.connect(preserve_draft); add_child(timer)
	refresh()
	context_panel = preload("res://scripts/map_authoring/context/map_context_panel.gd").mount(self,session)
	preload("res://scripts/map_authoring/preview/viewport_tools.gd").mount(canvas,"map")
	gameplay_tools = preload("res://scripts/map_authoring/preview/gameplay_tools.gd").mount(self,"map","map",func() -> Dictionary: return session.data,func() -> Dictionary: return result.get("package",{}) if result.get("ok",false) else {},func() -> String: return Document.hash_source(session.data))
	# Checkpoint44 (F9-05, P3b): regional variation of one instance; its own AX provider.
	synthesis = RootSynthesisSection.new(); add_child(synthesis); synthesis.setup(self,"map","map"); synthesis.refresh()
	# Checkpoint49 (F9-06/07, P6a): the guided step bar shared by the screens.
	var owns_flow: bool = flow == null
	if owns_flow: flow = Flow.new()
	flow.attach("map",self); workflow_bar = WorkflowBar.mount(self,flow,"map","map",owns_flow)
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"map",func() -> Dictionary: return session.data,canvas)
var synthesis: VBoxContainer
func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(action); parent.add_child(button); return button
func open_population() -> void:
	if population_window == null:
		population_window = Window.new(); population_window.title = "Encontros do mapa"; population_window.size = Vector2i(1280,860); population_window.min_size = Vector2i(1100,650)
		population_window.close_requested.connect(population_window.hide); add_child(population_window)
		var panel := Population.new(); panel.flow = flow; panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); population_window.add_child(panel)
		if not session.data.instances.is_empty(): panel.import_map(session.data)
	population_window.popup_centered()
func open_generation() -> void:
	if generation_window == null:
		generation_window = Window.new(); generation_window.title = "Geração assistida"; generation_window.size = Vector2i(1360,900); generation_window.min_size = Vector2i(1180,760)
		generation_window.close_requested.connect(generation_window.hide); add_child(generation_window)
		var panel := Generation.new(); panel.target = session; panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); generation_window.add_child(panel)
	generation_window.popup_centered()
func _number(parent: Node, label: String) -> SpinBox:
	var title := Label.new(); title.text = label; parent.add_child(title)
	var value := SpinBox.new(); value.min_value = -16000; value.max_value = 16000; value.step = 0; value.custom_arrow_step = 1; value.custom_minimum_size.x = 80; parent.add_child(value); return value
func _exit_tree() -> void:
	if job != null: job.close()
	if _dirty(): preserve_draft()
func _new_draft_path() -> void:
	_autosave = ProjectSettings.globalize_path("res://.godot/map_authoring/composition_"+Crypto.new().generate_random_bytes(12).hex_encode()+".json")
	DirAccess.make_dir_recursive_absolute(_autosave.get_base_dir())
func preserve_draft() -> bool:
	if not _dirty(): return true
	if _autosave.is_empty(): return false
	var pending := _pending_source()
	if not pending.ok: show_result(pending); return false
	var saved := Store.save_source(_autosave,pending.data,PieceStore.disk_hash(_autosave))
	if not saved.ok: status.text = "Não foi possível preservar o rascunho: "+saved.code
	return saved.ok
func recover() -> void:
	var loaded := Store.load_source(_autosave)
	if loaded.ok: show_result(session.replace(loaded.data))
	else: show_result(loaded)
func new_map() -> void:
	# Existing internal callers already request replacement; the visible action
	# uses request_new_map and AX must supply its own explicit confirmation.
	show_result(new_document("map","Novo mapa",true))
func request_new_map() -> void:
	var created := new_document("map","Novo mapa",false)
	if created.get("code","") == "confirmation_required":
		_replace_action = func() -> void: show_result(new_document("map","Novo mapa",true))
		_replace_confirmation.popup_centered()
	else: show_result(created)
func sample() -> void:
	# Do not replace authored content with an example.
	if not session.data.instances.is_empty(): status.text = "Crie um novo mapa para carregar o exemplo."; return
	show_result(session.apply(Document.sample()))
func choose(action: String) -> void:
	_file_action = action
	_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action == "save" else (FileDialog.FILE_MODE_OPEN_DIR if action == "publish" else FileDialog.FILE_MODE_OPEN_FILE)
	_dialog.filters = PackedStringArray(["*.json ; Fontes de mapa/peça"]) if action != "publish" else PackedStringArray()
	_dialog.title = {"open":"Abrir mapa ou rascunho","save":"Salvar composição","piece":"Adicionar snapshot de peça","publish":"Pasta de publicações locais"}[action]
	_dialog.popup_centered_ratio(0.75)
func file_selected(path: String) -> void:
	match _file_action:
		"open":
			var opened := open_document(path,false)
			if opened.get("code","") == "confirmation_required":
				_replace_action = func() -> void: show_result(open_document(path,true))
				_replace_confirmation.popup_centered()
			else: show_result(opened)
		"save":
			# Existing destinations require an explicit overwrite dialog from FileDialog,
			# and an optimistic byte hash prevents overwriting a later external edit.
			show_result(save_document(path,PieceStore.disk_hash(path)))
		"piece": import_piece(path)
		"publish":
			if not result.get("ok",false): status.text = "Compile o mapa antes de publicar."; return
			var published := Store.publish(path,result.package,Document.hash_source(session.data)); show_result(published)
			if published.ok: status.text = "Revisão imutável publicada: "+published.path
func import_piece(path: String) -> Dictionary:
	return add_piece(path,"piece_"+Crypto.new().generate_random_bytes(6).hex_encode(),[x.value,z.value],rotation_choice.selected)
func add_piece(path: String, instance_id: String, position_xz: Array, rotation_quarters: float) -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var loaded := PieceStore.load_source(path)
	if not loaded.ok: show_result(loaded); return loaded
	return apply_operation("instance/add",{"instance_id":instance_id,"position_xz":position_xz,"rotation_quarters":rotation_quarters},loaded.data)
func apply_operation(operation: String, parameters: Dictionary, piece_source: Dictionary = {}) -> Dictionary:
	var selected: String = canvas.selected_instance
	var base := {"ok":true,"data":session.data} if operation == "name" else _pending_source()
	if not base.ok: return base
	var proposed := Operations.propose(base.data,operation,parameters,piece_source)
	if not proposed.ok: show_result(proposed); return proposed
	var applied := session.apply(proposed.data)
	if applied.ok:
		applied.added_ids = proposed.added_ids; applied.removed_ids = proposed.removed_ids
		applied.entity_id = proposed.entity_id
		if operation == "name": name_edit.text = session.data.name
		if not proposed.added_ids.is_empty(): selected = proposed.added_ids[0]
		if not selected.is_empty(): select_id(selected)
	show_result(applied); return applied
func rename_document(value: String) -> Dictionary:
	return apply_operation("name",{"name":value})
func _dirty() -> bool:
	return session.dirty() or (name_edit != null and name_edit.text != session.data.name)
func _pending_source() -> Dictionary:
	return Operations.propose(session.data,"name",{"name":name_edit.text if name_edit != null else session.data.name})
func _confirm_replace(confirmed: bool) -> Dictionary:
	if not _dirty(): return {"ok":true}
	if not confirmed: return Operations.fail("confirmation_required")
	return {"ok":true} if preserve_draft() else Operations.fail("io_recovery_required")
func new_document(document_id: String, caption: String, confirmed: bool) -> Dictionary:
	var data := Document.empty(document_id); data.name = caption
	var checked := Document.validate(data)
	if not checked.ok: return checked
	var allowed := _confirm_replace(confirmed)
	if not allowed.ok: return allowed
	_new_draft_path(); source_path = ""; expected_hash = ""; session.saved_hash = ""
	return session.replace(data)
func open_document(path: String, confirmed: bool) -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var loaded := Store.load_source(path)
	if not loaded.ok: return loaded
	var allowed := _confirm_replace(confirmed)
	if not allowed.ok: return allowed
	_new_draft_path(); source_path = ProjectSettings.globalize_path(path).simplify_path(); expected_hash = loaded.byte_hash
	var applied := session.replace(loaded.data)
	session.saved_hash = Document.hash_source(session.data)
	Library.register_source(source_path,"map"); return applied
func save_document(path: String, overwrite_hash: String = "") -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var normalized := ProjectSettings.globalize_path(path).simplify_path()
	var same := normalized.to_lower() == source_path.to_lower() if OS.has_feature("windows") else normalized == source_path
	var expected := expected_hash if same else overwrite_hash
	var pending := _pending_source()
	if not pending.ok: return pending
	var saved := Store.save_source(normalized,pending.data,expected)
	if saved.ok:
		session.apply(pending.data)
		source_path = normalized; expected_hash = saved.byte_hash; session.saved_hash = Document.hash_source(session.data)
		Library.register_source(source_path,"map")
	return saved
func history(redo: bool) -> Dictionary:
	var pending := _pending_source()
	if not pending.ok: return pending
	if pending.output_hash != Document.hash_source(session.data):
		if not preserve_draft(): return Operations.fail("io_recovery_required")
		session.apply(pending.data)
	var changed: bool = session.redo() if redo else session.undo()
	return {"ok":true,"output_hash":Document.hash_source(session.data)} if changed else Operations.fail("history_empty")
func _valid_path(path: String) -> bool:
	return not path.strip_edges().is_empty() and not path.to_utf8_buffer().has(0)
func refresh() -> void:
	if job != null: job.cancel()
	if synthesis != null: synthesis.refresh()
	result = {}; canvas.clear(); instances.clear(); links.clear(); port_a.clear(); port_b.clear(); surface.clear(); surface.add_item("Todas as superfícies visíveis"); _endpoints.clear()
	name_edit.text = session.data.name
	canvas.selected_instance = ""
	if context_panel != null: context_panel.refresh()
	mode.select(0 if session.data.mode == "manual" else 1)
	border_choice.select(0); border_decorations.set_pressed_no_signal(session.data.get("borders",{}).get("decorations",true)); transition_target.clear()
	for instance: Dictionary in session.data.instances:
		instances.add_item(instance.instance_id)
		transition_target.add_item(instance.instance_id); transition_target.set_item_metadata(transition_target.item_count-1,instance.instance_id)
		for piece: Dictionary in session.data.pieces:
			if piece.piece_hash != instance.piece_hash: continue
			for connector: Dictionary in piece.source.connectors:
				_endpoints.append({"instance":instance.instance_id,"connector":connector.connector_id})
				port_a.add_item(instance.instance_id+" / "+connector.connector_id); port_b.add_item(instance.instance_id+" / "+connector.connector_id)
	for link: Dictionary in session.data.links: links.add_item(link.link_id+": "+link.a_instance+" → "+link.b_instance)
	if port_b.item_count > 1: port_b.select(1)
	status.text = "Rascunho alterado; compile para validar emendas e testar."; problems.clear()
	for warning: Dictionary in Compiler.Context.warnings(session.data): problems.add_item(warning.message); problems.set_item_metadata(problems.item_count-1,warning)
func select_instance(index: int) -> void:
	var instance: Dictionary = session.data.instances[index]
	x.value = instance.position_xyz[0]; z.value = instance.position_xyz[2]; rotation_choice.select(instance.rotation_quarters); canvas.selected_instance = instance.instance_id; canvas.redraw()
	border_choice.select(0)
	for entry: Dictionary in session.data.get("borders",{}).get("instances",[]):
		if entry.instance_id != instance.instance_id: continue
		for k: int in border_choice.item_count:
			if border_choice.get_item_metadata(k) == entry.profile_id: border_choice.select(k)
func select_id(id: String) -> void:
	for i: int in session.data.instances.size():
		if session.data.instances[i].instance_id == id: instances.select(i); select_instance(i)
func apply_placement() -> void:
	var selected := instances.get_selected_items()
	if selected.is_empty(): return
	apply_operation("instance/transform",{"instance_id":session.data.instances[selected[0]].instance_id,"position_xz":[x.value,z.value],"rotation_quarters":rotation_choice.selected})
func request_remove() -> void:
	var selected := instances.get_selected_items()
	if selected.is_empty(): return
	_pending_remove = session.data.instances[selected[0]].instance_id
	var affected := 0
	for link: Dictionary in session.data.links:
		if _pending_remove in [link.a_instance,link.b_instance]: affected += 1
	_confirmation.dialog_text = "Remover %s e seus %d vínculos? A operação pode ser desfeita."%[_pending_remove,affected]; _confirmation.popup_centered()
func remove_instance() -> void:
	apply_operation("instance/remove",{"instance_id":_pending_remove,"confirm_remove":true})
func _border_command(command: Dictionary) -> Dictionary:
	var selected := instances.get_selected_items(); var previous := "" if selected.is_empty() else str(session.data.instances[selected[0]].instance_id)
	var applied := apply_border(command,Document.hash_source(session.data))
	if applied.ok and not previous.is_empty(): select_id(previous)
	return applied
func apply_border(command: Dictionary, expected_source_hash: String) -> Dictionary:
	return apply_borders([command],expected_source_hash)
func apply_borders(commands: Array, expected_source_hash: String) -> Dictionary:
	var selected: String = canvas.selected_instance
	var previous_choice: int = border_choice.selected
	var applied := session.apply_borders(commands,expected_source_hash,name_edit.text)
	if applied.ok:
		if not selected.is_empty(): select_id(selected)
		else: border_choice.select(previous_choice)
	show_result(applied); return applied
func apply_all_borders() -> Dictionary:
	if session.data.instances.is_empty():
		var empty := Compiler.fail("map_empty"); show_result(empty); return empty
	var profile: String = border_choice.get_item_metadata(border_choice.selected)
	var commands: Array = []
	for instance: Dictionary in session.data.instances:
		commands.append({"operation":"clear_instance_profile","instance_id":instance.instance_id} if profile.is_empty() else {"operation":"set_instance_profile","instance_id":instance.instance_id,"profile_id":profile})
	return apply_borders(commands,Document.hash_source(session.data))
func apply_border_choice() -> void:
	var selected := instances.get_selected_items()
	if selected.is_empty(): status.text = "Selecione a peça que receberá a borda."; return
	var id: String = session.data.instances[selected[0]].instance_id; var profile: String = border_choice.get_item_metadata(border_choice.selected)
	_border_command({"operation":"clear_instance_profile","instance_id":id} if profile.is_empty() else {"operation":"set_instance_profile","instance_id":id,"profile_id":profile})
func apply_border_transition() -> void:
	var selected := instances.get_selected_items()
	if selected.is_empty() or transition_target.selected < 0: status.text = "Selecione as duas peças da transição."; return
	_border_command({"operation":"set_transition","a_instance":session.data.instances[selected[0]].instance_id,"b_instance":transition_target.get_item_metadata(transition_target.selected),"profile_id":"transition_terrace_v1"})
func authoring_commands() -> Array:
	var commands: Array = [{"id":"map/borders/apply","label":"Editar perfil, transição ou decoração","parameters":{"expected_source_hash":"hash","command":{"operation":["set_instance_profile","clear_instance_profile","set_transition","set_decorations"],"fields":"closed_by_operation"}}}]
	commands.append({"id":"map/borders/apply_batch","label":"Aplicar lote de bordas","parameters":{"expected_source_hash":"hash","commands":"closed border commands[1..529]"}})
	for id: String in _ax_fields(): commands.append({"id":id,"parameters":_ax_fields()[id]})
	return commands
func _ax_fields() -> Dictionary:
	var fields := {"map/document/new":{"document_id":"id","name":"string","confirm_discard":"bool"},"map/document/name":Operations.FIELDS.name,"map/document/open":{"path":"string","confirm_discard":"bool"},"map/document/save":{"path":"string"},"map/history/undo":{},"map/history/redo":{},"map/instance/select":{"instance_id":"id"},"map/compile_map":{}}
	var addition: Dictionary = Operations.FIELDS["instance/add"].duplicate(); addition.path = "string"; fields["map/piece/add"] = addition
	for operation: String in ["instance/transform","instance/remove","link/upsert","link/remove","context/set","mode/set"]: fields["map/"+operation] = Operations.FIELDS[operation]
	return fields
func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	if id in ["map/borders/apply","map/borders/apply_batch"]:
		var fields: Dictionary = {"expected_source_hash":"hash","commands":"array"} if id == "map/borders/apply_batch" else {"expected_source_hash":"hash","command":"object"}
		var errors: Array = []; Schema._shape(parameters,fields,"border_request",errors)
		if not errors.is_empty(): return {"ok":false,"code":"arguments_invalid","diagnostics":errors}
		var commands: Array = parameters.commands if id == "map/borders/apply_batch" else [parameters.command]
		var applied := apply_borders(commands,parameters.expected_source_hash); show_result(applied); return applied
	var fields := _ax_fields()
	if not fields.has(id): return Operations.fail("action_missing")
	var errors: Array = []; Schema._shape(parameters,fields[id],"parameters",errors)
	if not errors.is_empty(): return Operations.fail("arguments_invalid")
	var applied: Dictionary
	match id:
		"map/document/new": applied = new_document(parameters.document_id,parameters.name,parameters.confirm_discard)
		"map/document/name": applied = rename_document(parameters.name)
		"map/document/open": applied = open_document(parameters.path,parameters.confirm_discard)
		"map/document/save": applied = save_document(parameters.path)
		"map/piece/add": applied = add_piece(parameters.path,parameters.instance_id,parameters.position_xz,parameters.rotation_quarters)
		"map/history/undo", "map/history/redo": applied = history(id == "map/history/redo")
		"map/instance/select":
			if Operations._find(session.data.instances,"instance_id",parameters.instance_id).is_empty(): return Operations.fail("instance_missing",parameters.instance_id)
			select_id(parameters.instance_id); applied = {"ok":true}
		"map/compile_map": applied = start_compile()
		_: applied = apply_operation(id.trim_prefix("map/"),parameters)
	if applied.ok:
		applied.output_hash = Document.hash_source(session.data)
		if not applied.has("entity_id"): applied.entity_id = session.data.document_id
	show_result(applied); return applied
func add_link() -> void:
	if port_a.selected < 0 or port_b.selected < 0: return
	var a: Dictionary = _endpoints[port_a.selected]; var b: Dictionary = _endpoints[port_b.selected]
	apply_operation("link/upsert",{"link_id":"link_"+Crypto.new().generate_random_bytes(6).hex_encode(),"a_instance":a.instance,"a_connector":a.connector,"b_instance":b.instance,"b_connector":b.connector})
func remove_link() -> void:
	var selected := links.get_selected_items()
	if selected.is_empty(): return
	apply_operation("link/remove",{"link_id":session.data.links[selected[0]].link_id})
func bake() -> void:
	show_result(start_compile())
func start_compile() -> Dictionary:
	if job != null: status.text = "Aguarde o cancelamento da compilação anterior."; return Operations.fail("compile_busy")
	var pending := _pending_source()
	if not pending.ok: return pending
	session.apply(pending.data)
	result = {}; canvas.clear(); job = Compiler.new(); job.start(session.data); status.text = "Compilando mapa…"
	return {"ok":true,"pending":true}
func _process(_delta: float) -> void:
	if job == null or not job.ready(): return
	result = job.take(Document.hash_source(session.data)); job = null; show_result(result)
	if result.ok:
		canvas.set_package(result.package); surface.clear(); surface.add_item("Todas as superfícies visíveis")
		for cell: Dictionary in result.package.manifest.stages[0].surfaces: surface.add_item(cell.surface_id)
		status.text = "%d peças · emendas e rotas validadas · clique para selecionar ou teste para andar."%result.package.piece_count
func toggle_test() -> void:
	var opened: Dictionary = gameplay_tools.toggle()
	status.text = "Teste de jogo solicitado; o rascunho foi preservado." if opened.ok else gameplay_tools.message.text
func show_result(value: Dictionary) -> void:
	problems.clear()
	var diagnostics: Array = value.get("diagnostics",[]).duplicate(true)
	if value.ok:
		for warning: Dictionary in Compiler.Context.warnings(session.data):
			if not diagnostics.any(func(item: Dictionary) -> bool: return item.code == warning.code and item.entity_id == warning.entity_id): diagnostics.append(warning)
	for diagnostic: Dictionary in diagnostics:
		problems.add_item(diagnostic.message); problems.set_item_metadata(problems.item_count-1,diagnostic)
	if not value.ok: status.text = value.get("code","Falha")
func focus_problem(index: int) -> void:
	var diagnostic: Variant = problems.get_item_metadata(index)
	if diagnostic is Dictionary:
		select_id(str(diagnostic.entity_id).get_slice("/",0)); status.text = diagnostic.message
		canvas._viewport_tools.focus_entity(str(diagnostic.entity_id))
