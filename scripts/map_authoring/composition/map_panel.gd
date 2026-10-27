@tool
extends VBoxContainer
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
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
var generation_window: Window
var population_window: Window
var gameplay_tools: Control
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
func _ready() -> void:
	exchange_panel = preload("res://scripts/map_authoring/exchange/exchange_panel.gd").mount(self,"map",func() -> Dictionary: return session.data.duplicate(true),session.apply)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL; size_flags_vertical = Control.SIZE_EXPAND_FILL
	var heading := Label.new(); heading.text = "Composição de mapas · Peças, vínculos e teste"; heading.add_theme_font_size_override("font_size",22); add_child(heading)
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	for entry: Array in [["Novo mapa",new_map],["Abrir…",func() -> void: choose("open")],["Salvar como…",func() -> void: choose("save")],["Adicionar peça…",func() -> void: choose("piece")],["Exemplo com duas peças",sample],["Desfazer",func() -> void: session.undo()],["Refazer",func() -> void: session.redo()]]: _button(toolbar,entry[0],entry[1])
	var actions := HBoxContainer.new(); add_child(actions)
	mode = OptionButton.new(); mode.add_item("Manual · posições fixadas"); mode.add_item("Receita · encaixe por árvore"); actions.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void:
		var data := session.data.duplicate(true); data.mode = "manual" if index == 0 else "recipe"
		var applied := session.apply(data)
		if not applied.ok: mode.select(0 if session.data.mode == "manual" else 1)
		show_result(applied))
	_button(actions,"Compilar mapa",bake); _button(actions,"Cancelar",func() -> void:
		if job != null: job.cancel())
	_button(actions,"Testar / parar",toggle_test); _button(actions,"Publicar localmente…",func() -> void: choose("publish"))
	_button(actions,"Recuperar rascunho",recover)
	_button(actions,"Encontros…",open_population)
	_button(actions,"Geração assistida…",open_generation)
	var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(split)
	var inspector := VBoxContainer.new(); inspector.custom_minimum_size.x = 290; split.add_child(inspector)
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
	_new_draft_path()
	session.changed.connect(refresh)
	var timer := Timer.new(); timer.wait_time = 10; timer.autostart = true; timer.timeout.connect(preserve_draft); add_child(timer)
	refresh()
	preload("res://scripts/map_authoring/context/map_context_panel.gd").mount(self,session)
	preload("res://scripts/map_authoring/preview/viewport_tools.gd").mount(canvas,"map")
	gameplay_tools = preload("res://scripts/map_authoring/preview/gameplay_tools.gd").mount(self,"map","map",func() -> Dictionary: return session.data,func() -> Dictionary: return result.get("package",{}) if result.get("ok",false) else {},func() -> String: return Document.hash_source(session.data))
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"map",func() -> Dictionary: return session.data,canvas)
func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(action); parent.add_child(button); return button
func open_population() -> void:
	if population_window == null:
		population_window = Window.new(); population_window.title = "Encontros do mapa"; population_window.size = Vector2i(1280,860); population_window.min_size = Vector2i(1100,650)
		population_window.close_requested.connect(population_window.hide); add_child(population_window)
		var panel := Population.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); population_window.add_child(panel)
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
	var value := SpinBox.new(); value.min_value = -16000; value.max_value = 16000; value.step = 1; value.custom_minimum_size.x = 80; parent.add_child(value); return value
func _exit_tree() -> void:
	if job != null: job.close()
	if session.dirty(): preserve_draft()
func _new_draft_path() -> void:
	_autosave = ProjectSettings.globalize_path("res://.godot/map_authoring/composition_"+Crypto.new().generate_random_bytes(12).hex_encode()+".json")
	DirAccess.make_dir_recursive_absolute(_autosave.get_base_dir())
func preserve_draft() -> bool:
	if not session.dirty(): return true
	if _autosave.is_empty(): return false
	var saved := Store.save_source(_autosave,session.data,PieceStore.disk_hash(_autosave))
	if not saved.ok: status.text = "Não foi possível preservar o rascunho: "+saved.code
	return saved.ok
func recover() -> void:
	var loaded := Store.load_source(_autosave)
	if loaded.ok: show_result(session.replace(loaded.data))
	else: show_result(loaded)
func new_map() -> void:
	if not preserve_draft(): return
	_new_draft_path(); source_path = ""; expected_hash = ""; session.saved_hash = ""; session.replace(Document.empty())
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
			var loaded := Store.load_source(path)
			if loaded.ok:
				if not preserve_draft(): return
				_new_draft_path(); source_path = path; expected_hash = loaded.byte_hash; session.replace(loaded.data); session.saved_hash = Document.hash_source(session.data)
				Library.register_source(path,"map")
			show_result(loaded)
		"save":
			# Existing destinations require an explicit overwrite dialog from FileDialog,
			# and an optimistic byte hash prevents overwriting a later external edit.
			var expected := expected_hash if path == source_path else PieceStore.disk_hash(path)
			var saved := Store.save_source(path,session.data,expected)
			if saved.ok:
				source_path = path; expected_hash = saved.byte_hash; session.saved_hash = Document.hash_source(session.data)
				Library.register_source(path,"map")
			show_result(saved)
		"piece": import_piece(path)
		"publish":
			if not result.get("ok",false): status.text = "Compile o mapa antes de publicar."; return
			var published := Store.publish(path,result.package,Document.hash_source(session.data)); show_result(published)
			if published.ok: status.text = "Revisão imutável publicada: "+published.path
func import_piece(path: String) -> Dictionary:
	var loaded := PieceStore.load_source(path)
	if not loaded.ok: show_result(loaded); return loaded
	var data := session.data.duplicate(true); var hash_value: String = loaded.output_hash
	var found := false
	for piece: Dictionary in data.pieces:
		if piece.piece_hash == hash_value: found = true
	if not found: data.pieces.append({"piece_hash":hash_value,"source":loaded.data})
	data.instances.append({"instance_id":"piece_"+Crypto.new().generate_random_bytes(6).hex_encode(),"piece_hash":hash_value,"position_xyz":[x.value,0,z.value],"rotation_quarters":rotation_choice.selected})
	var applied := session.apply(data); show_result(applied); return applied
func refresh() -> void:
	if job != null: job.cancel()
	result = {}; canvas.clear(); instances.clear(); links.clear(); port_a.clear(); port_b.clear(); surface.clear(); surface.add_item("Todas as superfícies visíveis"); _endpoints.clear()
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
	var data := session.data.duplicate(true); data.instances[selected[0]].position_xyz = [x.value,0,z.value]; data.instances[selected[0]].rotation_quarters = rotation_choice.selected; show_result(session.apply(data))
func request_remove() -> void:
	var selected := instances.get_selected_items()
	if selected.is_empty(): return
	_pending_remove = session.data.instances[selected[0]].instance_id
	var affected := 0
	for link: Dictionary in session.data.links:
		if _pending_remove in [link.a_instance,link.b_instance]: affected += 1
	_confirmation.dialog_text = "Remover %s e seus %d vínculos? A operação pode ser desfeita."%[_pending_remove,affected]; _confirmation.popup_centered()
func remove_instance() -> void:
	var data := BorderOperations.remove_references(session.data,_pending_remove)
	data.instances = data.instances.filter(func(item: Dictionary) -> bool: return item.instance_id != _pending_remove)
	data.links = data.links.filter(func(item: Dictionary) -> bool: return _pending_remove not in [item.a_instance,item.b_instance])
	if data.has("context"): data.context.overrides = data.context.overrides.filter(func(item: Dictionary) -> bool: return item.instance_id != _pending_remove)
	show_result(session.apply(data))
func _border_command(command: Dictionary) -> Dictionary:
	var selected := instances.get_selected_items(); var previous := "" if selected.is_empty() else str(session.data.instances[selected[0]].instance_id)
	var applied := session.apply_border(command,Document.hash_source(session.data)); show_result(applied)
	if applied.ok and not previous.is_empty(): select_id(previous)
	return applied
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
	return [{"id":"map/borders/apply","label":"Editar perfil, transição ou decoração","parameters":{"expected_source_hash":"hash","command":{"operation":["set_instance_profile","clear_instance_profile","set_transition","set_decorations"],"fields":"closed_by_operation"}}}]
func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	if id != "map/borders/apply": return {"ok":false,"code":"action_missing"}
	var errors: Array = []; Schema._shape(parameters,{"expected_source_hash":"hash","command":"object"},"border_request",errors)
	if not errors.is_empty(): return {"ok":false,"code":"arguments_invalid","diagnostics":errors}
	var applied := session.apply_border(parameters.command,parameters.expected_source_hash); show_result(applied); return applied
func add_link() -> void:
	if port_a.selected < 0 or port_b.selected < 0: return
	var a: Dictionary = _endpoints[port_a.selected]; var b: Dictionary = _endpoints[port_b.selected]
	var data := session.data.duplicate(true)
	data.links.append({"link_id":"link_"+Crypto.new().generate_random_bytes(6).hex_encode(),"a_instance":a.instance,"a_connector":a.connector,"b_instance":b.instance,"b_connector":b.connector}); show_result(session.apply(data))
func remove_link() -> void:
	var selected := links.get_selected_items()
	if selected.is_empty(): return
	var data := session.data.duplicate(true); data.links.remove_at(selected[0]); show_result(session.apply(data))
func bake() -> void:
	if job != null: status.text = "Aguarde o cancelamento da compilação anterior."; return
	result = {}; canvas.clear(); job = Compiler.new(); job.start(session.data); status.text = "Compilando mapa…"
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
	for diagnostic: Dictionary in value.get("diagnostics",[]):
		problems.add_item(diagnostic.message); problems.set_item_metadata(problems.item_count-1,diagnostic)
	if not value.ok: status.text = value.get("code","Falha")
func focus_problem(index: int) -> void:
	var diagnostic: Variant = problems.get_item_metadata(index)
	if diagnostic is Dictionary:
		select_id(str(diagnostic.entity_id).get_slice("/",0)); status.text = diagnostic.message
		canvas._viewport_tools.focus_entity(str(diagnostic.entity_id))
