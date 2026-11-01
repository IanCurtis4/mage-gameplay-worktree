@tool
extends VBoxContainer
const Document = preload("res://scripts/map_authoring/population/population_document.gd")
const RootSynthesisSection = preload("res://scripts/map_authoring/synthesis/root_synthesis_section.gd")
const Session = preload("res://scripts/map_authoring/population/population_session.gd")
const Compiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const Store = preload("res://scripts/map_authoring/population/population_store.gd")
const MapStore = preload("res://scripts/map_authoring/composition/map_store.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
const Canvas = preload("res://scripts/map_authoring/population/population_canvas.gd")
const Operations = preload("res://scripts/map_authoring/population/population_operations.gd")
const Flow = preload("res://scripts/map_authoring/workflow/authoring_flow.gd")
const WorkflowBar = preload("res://scripts/map_authoring/workflow/workflow_bar.gd")
var gameplay_tools: Control
var flow: RefCounted
var workflow_bar: VBoxContainer
var name_edit: LineEdit
var _proposal_signature := ""
var _imported_map_package: Dictionary = {}
var session := Session.new()
var canvas: Control
var job: RefCounted
var job_kind := "compile"
var result: Dictionary = {}
var proposal: Dictionary = {}
var showing_proposal := false
var status: Label
var problems: ItemList
var brushes: ItemList
var slots: ItemList
var markers: ItemList
var choices: ItemList
var species: OptionButton
var mode: OptionButton
var quota: OptionButton
var paint: OptionButton
var surface: OptionButton
var target: OptionButton
var radius: SpinBox
var spacing: SpinBox
var quantity: SpinBox
var density: SpinBox
var group_radius: SpinBox
var weight: SpinBox
var seed_edit: LineEdit
var round_number: SpinBox
var _options: Array = []
var _marker_ids: Array = []
var _dialog: FileDialog
var _action := ""
var _confirmation: ConfirmationDialog
var _pending := ""
var _autosave := ""
var source_path := ""
var expected_hash := ""
var patrol_window: Window
func open_patrols() -> void:
	if patrol_window == null:
		patrol_window = Window.new(); patrol_window.title = "Patrulhas do encontro"; patrol_window.size = Vector2i(1280,860); patrol_window.min_size = Vector2i(1100,700)
		patrol_window.close_requested.connect(patrol_window.hide); add_child(patrol_window)
		var panel := preload("res://scripts/map_authoring/patrol/patrol_panel.gd").new(); panel.flow = flow; panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); patrol_window.add_child(panel)
		panel.import_population(session.data)
	patrol_window.popup_centered()
var exchange_panel: Control
func _ready() -> void:
	exchange_panel = preload("res://scripts/map_authoring/exchange/exchange_panel.gd").mount(self,"population",func() -> Dictionary: return session.data.duplicate(true),session.apply)
	size_flags_vertical = Control.SIZE_EXPAND_FILL; size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var heading := Label.new(); heading.text = "Encontros · População e interações"; heading.add_theme_font_size_override("font_size",22); add_child(heading)
	var name_row := HBoxContainer.new(); add_child(name_row)
	name_edit = LineEdit.new(); name_edit.size_flags_horizontal = SIZE_EXPAND_FILL; name_row.add_child(name_edit)
	_button(name_row,"Aplicar nome",func() -> void: apply_operation("name",{"name":name_edit.text}))
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	for entry: Array in [["Novo",new_document],["Importar mapa…",func() -> void: choose("map")],["Abrir…",func() -> void: choose("open")],["Salvar como…",func() -> void: choose("save")],["Desfazer",func() -> void: history(false)],["Refazer",func() -> void: history(true)],["Recuperar",recover]]: _button(toolbar,entry[0],entry[1])
	var actions := HBoxContainer.new(); add_child(actions)
	for entry: Array in [["Preparar prévia",prepare_plan],["Atual / prévia",toggle_proposal],["Aplicar prévia…",request_apply],["Compilar",bake],["Cancelar",func() -> void:
		cancel_job()],["Testar / parar",toggle_test],["Publicar localmente…",func() -> void: choose("publish")]]: _button(actions,entry[0],entry[1])
	var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(split)
	_button(actions,"Patrulhas…",open_patrols)
	var scroll := ScrollContainer.new(); scroll.custom_minimum_size.x = 365; scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; split.add_child(scroll)
	var inspector := VBoxContainer.new(); inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scroll.add_child(inspector)
	_label(inspector,"Clique no mapa para a ação escolhida")
	paint = OptionButton.new()
	for text: String in ["Selecionar slot","Marcar entrada","Pintar pincel","Excluir região","Colocar slot fixo","Palco memorável","Portal local","Saída de conclusão","Saída antecipada","Mover slot selecionado"]: paint.add_item(text)
	inspector.add_child(paint); paint.item_selected.connect(func(index: int) -> void: canvas.paint_enabled = index > 0)
	surface = OptionButton.new(); surface.add_item("Todas as superfícies visíveis"); inspector.add_child(surface); surface.item_selected.connect(func(index: int) -> void: canvas.selected_surface = "" if index == 0 else surface.get_item_text(index))
	_label(inspector,"Catálogo · espécie, categoria e origem")
	species = OptionButton.new(); species.clip_text = true; species.custom_minimum_size.x = 330; inspector.add_child(species)
	var loaded := Catalog.list_options()
	if loaded.ok:
		_options = loaded.options
		for option: Dictionary in _options: species.add_item(option.label)
	brushes = ItemList.new(); brushes.custom_minimum_size.y = 75; inspector.add_child(brushes); brushes.item_selected.connect(select_brush)
	mode = _choice(inspector,["Disperso","Concentrado"]); quota = _choice(inspector,["Quantidade exata","Densidade por 10.000 unidades²"])
	radius = _number(inspector,"Raio do pincel",1,512,80); group_radius = _number(inspector,"Raio do grupo",1,512,60)
	quantity = _number(inspector,"Quantidade (inclui fixos)",0,128,3); density = _number(inspector,"Densidade",0,100,1,0.1)
	spacing = _number(inspector,"Espaço além dos corpos",0,1024,8)
	_label(inspector,"Semente numérica (inteiro de 64 bits)")
	seed_edit = LineEdit.new(); seed_edit.text = "0"; inspector.add_child(seed_edit)
	round_number = _number(inspector,"Rodada (novo sorteio explícito)",0,2147483647,0)
	_button(inspector,"Aplicar parâmetros ao pincel",apply_brush)
	choices = ItemList.new(); choices.custom_minimum_size.y = 70; inspector.add_child(choices)
	weight = _number(inspector,"Peso da espécie escolhida",1,10000,1)
	var choice_row := HBoxContainer.new(); inspector.add_child(choice_row)
	_button(choice_row,"Adicionar / atualizar peso",add_species); _button(choice_row,"Remover espécie",remove_species)
	slots = ItemList.new(); slots.custom_minimum_size.y = 90; inspector.add_child(slots); slots.item_selected.connect(func(index: int) -> void: canvas.selected_slot = session.data.slots[index].slot_id; canvas.redraw())
	var slot_row := HBoxContainer.new(); inspector.add_child(slot_row)
	_button(slot_row,"Fixar / liberar",pin_slot); _button(slot_row,"Remover slot…",func() -> void: request_remove("slot"))
	markers = ItemList.new(); markers.custom_minimum_size.y = 65; inspector.add_child(markers)
	target = OptionButton.new(); inspector.add_child(target)
	_button(inspector,"Vincular portal selecionado ao destino",link_portal)
	_button(inspector,"Remover marcador / pincel…",func() -> void: request_remove("marker"))
	_label(inspector,"Teste técnico descartável: marcadores e ciclo canônico.\nNão concede bens nem usa o save pessoal.")
	_button(inspector,"Simular morte do slot selecionado",simulate_death); _button(inspector,"Avançar uma onda de respawn",simulate_wave)
	canvas = Canvas.new(); split.add_child(canvas); canvas.painted.connect(paint_at); canvas.slot_selected.connect(select_slot); canvas.status.connect(func(message: String) -> void: status.text = message)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	problems = ItemList.new(); problems.custom_minimum_size.y = 65; add_child(problems)
	problems.item_selected.connect(focus_problem)
	_dialog = FileDialog.new(); _dialog.access = FileDialog.ACCESS_FILESYSTEM; _dialog.file_selected.connect(file_selected); _dialog.dir_selected.connect(file_selected); add_child(_dialog)
	_confirmation = ConfirmationDialog.new(); _confirmation.confirmed.connect(confirm_action); add_child(_confirmation)
	session.changed.connect(refresh); _new_draft()
	var timer := Timer.new(); timer.wait_time = 10; timer.autostart = true; timer.timeout.connect(preserve_draft); add_child(timer); refresh()
	preload("res://scripts/map_authoring/preview/viewport_tools.gd").mount(canvas,"population")
	gameplay_tools = preload("res://scripts/map_authoring/preview/gameplay_tools.gd").mount(self,"population","population",func() -> Dictionary: return session.data,func() -> Dictionary: return result.get("package",{}) if result.get("ok",false) else {},func() -> String: return Document.hash_source(session.data))
	# Checkpoint44 (F9-05, P3b): regional variation of one instance; its own AX provider.
	synthesis = RootSynthesisSection.new(); add_child(synthesis); synthesis.setup(self,"population","population"); synthesis.refresh()
	# Checkpoint49 (F9-06/07, P6a): the guided step bar shared by the screens.
	var owns_flow: bool = flow == null
	if owns_flow: flow = Flow.new()
	flow.attach("population",self); workflow_bar = WorkflowBar.mount(self,flow,"population","population",owns_flow)
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"population",func() -> Dictionary: return session.data,canvas)
var synthesis: VBoxContainer
func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new(); button.text = text; button.pressed.connect(action); parent.add_child(button); return button
func _label(parent: Node, text: String) -> void:
	var label := Label.new(); label.text = text; label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label)
func _choice(parent: Node, texts: Array) -> OptionButton:
	var choice := OptionButton.new()
	for text: String in texts: choice.add_item(text)
	parent.add_child(choice); return choice
func _number(parent: Node, title: String, low: float, high: float, value: float, step: float = 1) -> SpinBox:
	var row := HBoxContainer.new(); parent.add_child(row); var label := Label.new(); label.text = title; label.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(label)
	var number := SpinBox.new(); number.min_value = low; number.max_value = high; number.step = step; number.value = value; row.add_child(number); return number
func _new_draft() -> void:
	_autosave = ProjectSettings.globalize_path("res://.godot/map_authoring/encounters_"+Crypto.new().generate_random_bytes(12).hex_encode()+".json"); DirAccess.make_dir_recursive_absolute(_autosave.get_base_dir())
func _exit_tree() -> void:
	if job != null: job.close()
	if _dirty(): preserve_draft()
func preserve_draft() -> bool:
	if not _dirty(): return true
	if _autosave.is_empty(): return false
	var pending_source := _pending_source()
	if not pending_source.ok: return false
	var saved := Store.save_source(_autosave,pending_source.data,IO.disk_hash(_autosave))
	show_result(saved); return saved.ok
func recover() -> void:
	var loaded := Store.load_source(_autosave)
	if loaded.ok: session.replace(loaded.data)
	show_result(loaded)
func _dirty() -> bool:
	return session.dirty() or (name_edit != null and name_edit.text != session.data.name)
func _pending_source() -> Dictionary:
	return Operations.propose(session.data,"name",{"name":name_edit.text if name_edit != null else session.data.name})
func _confirm_replace(confirmed: bool) -> Dictionary:
	if not _dirty(): return {"ok":true}
	if not confirmed: return Operations.fail("confirmation_required")
	return {"ok":true} if preserve_draft() else Operations.fail("io_recovery_required")
func new_document(document_id: String = "encounters", caption: String = "Encontros", confirmed: bool = true) -> Dictionary:
	var data := Document.empty(document_id); data.name = caption
	var checked := Document.validate(data)
	if not checked.ok: return checked
	var allowed := _confirm_replace(confirmed)
	if not allowed.ok: return allowed
	_new_draft(); source_path = ""; expected_hash = ""; session.saved_hash = ""; canvas.clear()
	return session.replace(data)
func _valid_path(path: String) -> bool:
	return not path.strip_edges().is_empty() and not path.to_utf8_buffer().has(0)
func open_document(path: String, confirmed: bool) -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var loaded := Store.load_source(path)
	if not loaded.ok: return loaded
	var allowed := _confirm_replace(confirmed)
	if not allowed.ok: return allowed
	_new_draft(); source_path = ProjectSettings.globalize_path(path).simplify_path(); expected_hash = loaded.byte_hash
	canvas.clear(); var applied := session.replace(loaded.data)
	session.saved_hash = Document.hash_source(session.data); return applied
func save_document(path: String, overwrite_hash: String = "") -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var normalized := ProjectSettings.globalize_path(path).simplify_path()
	var same: bool = normalized.to_lower() == source_path.to_lower() if OS.has_feature("windows") else normalized == source_path
	var pending_source := _pending_source()
	if not pending_source.ok: return pending_source
	var saved := Store.save_source(normalized,pending_source.data,expected_hash if same else overwrite_hash)
	if saved.ok:
		session.apply(pending_source.data); source_path = normalized; expected_hash = saved.byte_hash; session.saved_hash = Document.hash_source(session.data)
	return saved
func history(redo: bool) -> Dictionary:
	var pending_source := _pending_source()
	if not pending_source.ok: return pending_source
	if pending_source.output_hash != Document.hash_source(session.data):
		if not preserve_draft(): return Operations.fail("io_recovery_required")
		session.apply(pending_source.data)
	var changed: bool = session.redo() if redo else session.undo()
	return {"ok":true,"output_hash":Document.hash_source(session.data)} if changed else Operations.fail("history_empty")
func apply_operation(operation: String, parameters: Dictionary) -> Dictionary:
	var base := {"ok":true,"data":session.data} if operation == "name" else _pending_source()
	if not base.ok: return base
	var proposed := Operations.propose(base.data,operation,parameters)
	if not proposed.ok: show_result(proposed); return proposed
	var applied := session.apply(proposed.data)
	if applied.ok:
		applied.entity_id = proposed.entity_id; applied.added_ids = proposed.added_ids; applied.removed_ids = proposed.removed_ids
		applied.output_hash = Document.hash_source(session.data)
		if operation.begins_with("slot/"): select_slot(proposed.entity_id)
		elif operation.begins_with("brush/"):
			for index: int in session.data.brushes.size():
				if session.data.brushes[index].brush_id == proposed.entity_id: brushes.select(index); select_brush(index)
	show_result(applied); return applied
func import_map(source: Dictionary) -> Dictionary:
	if not session.data.map.is_empty(): return Operations.fail("map_already_present")
	var built := MapCompiler.compile(source)
	if not built.ok: show_result(built); return built
	var pending_source := _pending_source()
	if not pending_source.ok: return pending_source
	var data: Dictionary = pending_source.data; data.map = [source.duplicate(true)]
	# A synchronous handoff of the package just validated for this exact snapshot.
	# refresh must not compile the identical map a second time during Session.apply.
	_imported_map_package = built.package
	var applied := session.apply(data)
	_imported_map_package = {}
	if not applied.ok: return applied
	if canvas.package.get("package_hash","") != built.output_hash: canvas.set_package(built.package); _surfaces()
	status.text = "Mapa importado. Marque a entrada e pinte um brush."; return applied
func _surfaces() -> void:
	surface.clear(); surface.add_item("Todas as superfícies visíveis")
	for cell: Dictionary in canvas.package.get("manifest",{}).get("stages",[{}])[0].get("surfaces",[]): surface.add_item(cell.surface_id)
func refresh() -> void:
	if job != null: job.cancel()
	if synthesis != null: synthesis.refresh()
	result = {}; proposal = {}; _proposal_signature = ""; showing_proposal = false; canvas.preview_diff = {}; canvas.stop_test(); canvas.encounters = {}; canvas.source = session.data.duplicate(true)
	name_edit.text = session.data.name
	if session.data.map.is_empty(): canvas.clear()
	elif canvas.package.get("source_hash","") != MapDocument.hash_source(session.data.map[0]):
		var map_hash: String = MapDocument.hash_source(session.data.map[0])
		var built: Dictionary = {"ok":true,"package":_imported_map_package} if _imported_map_package.get("source_hash","") == map_hash else MapCompiler.compile(session.data.map[0])
		if built.ok: canvas.set_package(built.package); _surfaces()
		else: canvas.clear()
	canvas.redraw()
	brushes.clear(); slots.clear(); markers.clear(); choices.clear(); target.clear(); _marker_ids.clear()
	for brush: Dictionary in session.data.brushes: brushes.add_item(brush.brush_id+" · "+("Disperso" if brush.mode == "dispersed" else "Concentrado"))
	for slot: Dictionary in session.data.slots: slots.add_item(("Fixo · " if slot.fixed else "Gerado · ")+slot.species_id+" · "+slot.slot_id.right(6))
	for collection: String in ["exclusions","interactions","brushes"]:
		for marker: Dictionary in session.data[collection]:
			var id: String = marker.get("exclusion_id",marker.get("interaction_id",marker.get("brush_id","")))
			markers.add_item(id); _marker_ids.append({"collection":collection,"id":id})
	for interaction: Dictionary in session.data.interactions:
		if interaction.kind == "portal": target.add_item(interaction.interaction_id)
	if brushes.item_count > 0: brushes.select(0); select_brush(0)
	status.text = "Fonte alterada. Prepare uma prévia ou compile o plano aplicado."; problems.clear()
func _selected_brush() -> Dictionary:
	var selected := brushes.get_selected_items(); return {} if selected.is_empty() else session.data.brushes[selected[0]]
func select_brush(index: int) -> void:
	var brush: Dictionary = session.data.brushes[index]
	mode.select(0 if brush.mode == "dispersed" else 1); quota.select(0 if brush.quota_mode == "count" else 1)
	radius.value = brush.radius; group_radius.value = brush.group_radius; quantity.value = brush.quantity; density.value = brush.density; spacing.value = brush.spacing; seed_edit.text = brush.seed; round_number.value = brush.round
	choices.clear()
	for spec: Dictionary in brush.species: choices.add_item("%s · %s · peso %d"%[spec.species_id,spec.category,spec.weight])
func _parameters(brush: Dictionary) -> Dictionary:
	var copy := brush.duplicate(true); copy.mode = "dispersed" if mode.selected == 0 else "concentrated"; copy.quota_mode = "count" if quota.selected == 0 else "density"
	copy.radius = radius.value; copy.group_radius = group_radius.value; copy.quantity = quantity.value; copy.density = density.value; copy.spacing = spacing.value; copy.seed = seed_edit.text; copy.round = int(round_number.value); return copy
func apply_brush() -> void:
	var selected := brushes.get_selected_items()
	if selected.is_empty(): return
	apply_operation("brush/upsert",_parameters(session.data.brushes[selected[0]]))
func add_species() -> void:
	var selected := brushes.get_selected_items()
	if selected.is_empty() or species.selected < 0: return
	var brush: Dictionary = session.data.brushes[selected[0]].duplicate(true); var spec: Dictionary = _options[species.selected].duplicate(true); spec.erase("label"); spec.weight = int(weight.value)
	var items: Array = brush.species
	for i: int in items.size():
		if items[i].species_id == spec.species_id and items[i].category == spec.category and items[i].origin_id == spec.origin_id: items[i] = spec; apply_operation("brush/upsert",brush); return
	items.append(spec); apply_operation("brush/upsert",brush)
func remove_species() -> void:
	var brush_indices := brushes.get_selected_items(); var choice_indices := choices.get_selected_items()
	if brush_indices.is_empty() or choice_indices.is_empty(): return
	var brush: Dictionary = session.data.brushes[brush_indices[0]].duplicate(true); brush.species.remove_at(choice_indices[0]); apply_operation("brush/upsert",brush)
func paint_at(point: Dictionary) -> void:
	if canvas.testing or canvas.package.is_empty() or species.selected < 0: return
	var data := session.data.duplicate(true); var suffix := Crypto.new().generate_random_bytes(6).hex_encode()
	match paint.selected:
		1: apply_operation("entrance/set",point)
		2:
			var brush := Document.brush("brush_"+suffix,point.surface_id,Compiler.vector(point.position_xyz),_options[species.selected]); apply_operation("brush/upsert",_parameters(brush))
		3: apply_operation("exclusion/upsert",{"exclusion_id":"exclude_"+suffix,"surface_id":point.surface_id,"center_xyz":point.position_xyz,"radius":radius.value})
		4:
			var brush := _selected_brush()
			if brush.is_empty(): status.text = "Selecione um pincel para este slot."; return
			var spec: Dictionary = _options[species.selected]; var site := ""
			for marker: Dictionary in data.interactions:
				if marker.kind == "thematic_encounter" and marker.surface_id == point.surface_id and Compiler.vector(marker.position_xyz).distance_to(Compiler.vector(point.position_xyz)) < 24: site = marker.interaction_id; point = {"surface_id":marker.surface_id,"position_xyz":marker.position_xyz}
			apply_operation("slot/upsert",{"slot_id":"fixed_"+suffix,"brush_id":brush.brush_id,"surface_id":point.surface_id,"position_xyz":point.position_xyz,"species_id":spec.species_id,"category":spec.category,"origin_id":spec.origin_id,"fixed":true,"site_id":site})
		5,6,7,8:
			apply_operation("interaction/upsert",{"interaction_id":"marker_"+suffix,"kind":{5:"thematic_encounter",6:"portal",7:"phase_completion",8:"early_exit"}[paint.selected],"surface_id":point.surface_id,"position_xyz":point.position_xyz,"target_id":""})
		9:
			var selected := slots.get_selected_items()
			if selected.is_empty(): status.text = "Selecione um slot para mover."; return
			var slot: Dictionary = data.slots[selected[0]]; slot.position_xyz = point.position_xyz; slot.surface_id = point.surface_id; slot.fixed = true
			apply_operation("slot/upsert",slot)
func select_slot(id: String) -> void:
	for i: int in session.data.slots.size():
		if session.data.slots[i].slot_id == id: slots.select(i); canvas.selected_slot = id; canvas.redraw()
func pin_slot() -> void:
	var selected := slots.get_selected_items()
	if selected.is_empty(): return
	var slot: Dictionary = session.data.slots[selected[0]]; apply_operation("slot/pin",{"slot_id":slot.slot_id,"fixed":not slot.fixed})
func link_portal() -> void:
	var selected := markers.get_selected_items()
	if selected.is_empty() or target.selected < 0: return
	var marker: Dictionary = _marker_ids[selected[0]]
	if marker.collection != "interactions": return
	for interaction: Dictionary in session.data.interactions:
		if interaction.interaction_id == marker.id and interaction.kind == "portal":
			var copy: Dictionary = interaction.duplicate(true); copy.target_id = target.get_item_text(target.selected); apply_operation("interaction/upsert",copy); return
func request_remove(kind: String) -> void:
	if (slots.get_selected_items() if kind == "slot" else markers.get_selected_items()).is_empty(): return
	var description := "Remover o slot selecionado?"
	if kind == "marker":
		var marker: Dictionary = _marker_ids[markers.get_selected_items()[0]]
		var count := 0; var fixed := 0
		if marker.collection == "brushes":
			for slot: Dictionary in session.data.slots:
				if slot.brush_id == marker.id: count += 1; fixed += int(slot.fixed)
			description = "Remover o pincel e seus %d slots (%d fixados)?"%[count,fixed]
		else: description = "Remover o marcador? Referências pendentes serão apontadas na próxima compilação."
	_pending = kind; _confirmation.dialog_text = description+" A operação pode ser desfeita."; _confirmation.popup_centered()
func confirm_action() -> void:
	if _pending == "plan":
		show_result(apply_proposal(proposal.get("base_hash",""),proposal_hash(),true)); return
	if _pending == "slot":
		var selected := slots.get_selected_items()
		if not selected.is_empty(): apply_operation("slot/remove",{"slot_id":session.data.slots[selected[0]].slot_id,"confirm_remove":true})
	elif _pending == "marker":
		var selected := markers.get_selected_items()
		if selected.is_empty(): return
		var marker: Dictionary = _marker_ids[selected[0]]; var field: String = Operations.IDS[marker.collection]
		var parameters: Dictionary = {"confirm_remove":true}; parameters[field] = marker.id
		apply_operation({"exclusions":"exclusion/remove","interactions":"interaction/remove","brushes":"brush/remove"}[marker.collection],parameters)
func _commit_pending() -> Dictionary:
	var pending_source := _pending_source()
	return session.apply(pending_source.data) if pending_source.ok else pending_source
func prepare_plan() -> Dictionary:
	if job != null: return Operations.fail("job_running")
	var committed := _commit_pending()
	if not committed.ok: return committed
	canvas.stop_test()
	proposal = {}; _proposal_signature = ""; job_kind = "regenerate"; job = Compiler.new(); job.start(session.data,"regenerate"); status.text = "Preparando prévia; você pode cancelar…"
	return {"ok":true}
func toggle_proposal() -> void:
	if not proposal.get("ok",false): return
	canvas.stop_test()
	showing_proposal = not showing_proposal; canvas.source = (proposal.data if showing_proposal else session.data).duplicate(true); canvas.redraw()
	canvas.preview_diff = proposal.diff if showing_proposal else {}
	status.text = "Visualizando prévia ainda não aplicada." if showing_proposal else "Visualizando o plano atual."
func request_apply() -> void:
	if not proposal.get("ok",false): status.text = "Prepare uma prévia válida."; return
	_pending = "plan"; _confirmation.dialog_text = "Aplicar prévia? %d novos, %d removidos, %d alterados e %d preservados. Slots fixados permanecem. Uma ação desfazível."%[proposal.diff.added.size(),proposal.diff.removed.size(),proposal.diff.changed.size(),proposal.diff.preserved.size()]; _confirmation.popup_centered()
func bake() -> Dictionary:
	if job != null: return Operations.fail("job_running")
	var committed := _commit_pending()
	if not committed.ok: return committed
	canvas.stop_test(); canvas.encounters = {}; result = {}; job_kind = "compile"; job = Compiler.new(); job.start(session.data); status.text = "Validando população, corpos e rotas…"
	return {"ok":true}
func cancel_job() -> Dictionary:
	if job != null: job.cancel()
	return {"ok":true}
func proposal_hash() -> String: return _proposal_signature
func _proposal_identity() -> String:
	if not proposal.get("ok",false): return ""
	var checked := Document.validate(proposal.get("data"))
	if not checked.ok or not Operations.Schema._type(proposal.get("base_hash"),"hash"): return ""
	var errors: Array = []
	Operations.Schema._shape(proposal.get("diff"),{"added":"strings","removed":"strings","changed":"strings","preserved":"strings"},"diff",errors)
	if not errors.is_empty(): return ""
	return Operations.Schema.semantic_hash({"base_hash":proposal.base_hash,"source_hash":checked.output_hash,"diff":proposal.diff})
func apply_proposal(expected_source_hash: String, signature: String, confirmed: bool) -> Dictionary:
	var pending_source := _pending_source()
	if not pending_source.ok: return pending_source
	if expected_source_hash != Document.hash_source(session.data) or pending_source.output_hash != expected_source_hash: return Operations.fail("stale_source")
	if not confirmed: return Operations.fail("confirmation_required")
	if not proposal.get("ok",false) or proposal.get("base_hash","") != expected_source_hash: return Operations.fail("proposal_missing")
	if signature.is_empty() or signature != _proposal_signature or _proposal_identity() != signature: return Operations.fail("proposal_invalid")
	var checked := Document.validate(proposal.data)
	if not checked.ok: return checked
	var diff: Dictionary = proposal.diff.duplicate(true)
	var applied := session.apply(proposal.data)
	if applied.ok: applied.diff = diff; applied.output_hash = Document.hash_source(session.data)
	return applied
func _process(_delta: float) -> void:
	if job == null or not job.ready(): return
	if job_kind == "regenerate":
		proposal = job.take(Document.hash_source(session.data)); job = null; show_result(proposal)
		if proposal.ok:
			_proposal_signature = _proposal_identity()
			showing_proposal = true; canvas.source = proposal.data.duplicate(true); canvas.preview_diff = proposal.diff; canvas.redraw()
			status.text = "Prévia: +%d novos · −%d removidos · %d alterados · %d preservados. Ainda não aplicada."%[proposal.diff.added.size(),proposal.diff.removed.size(),proposal.diff.changed.size(),proposal.diff.preserved.size()]
		return
	result = job.take(Document.hash_source(session.data)); job = null; show_result(result)
	if result.ok: canvas.set_encounters(result.package); canvas.source = session.data.duplicate(true); _surfaces(); status.text = "%d slots validados · pronto para teste técnico e publicação local."%session.data.slots.size()
func toggle_test() -> void:
	var opened: Dictionary = gameplay_tools.toggle()
	status.text = "Teste de jogo solicitado; o rascunho foi preservado." if opened.ok else gameplay_tools.message.text
func simulate_death() -> void:
	var selected := slots.get_selected_items()
	if selected.is_empty() or not canvas.testing: return
	var death: Dictionary = canvas.simulate_death(session.data.slots[selected[0]].slot_id)
	if death.ok: status.text = "Morte simulada. Limpeza canônica: "+("concluída" if canvas.campaign.stages.map_preview.cleared_once else "pendente")
func simulate_wave() -> void:
	canvas.simulate_wave(); status.text = "Onda técnica processada pela autoridade de respawn."
func choose(action: String) -> void:
	_action = action; _dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action == "save" else (FileDialog.FILE_MODE_OPEN_DIR if action == "publish" else FileDialog.FILE_MODE_OPEN_FILE)
	_dialog.title = {"map":"Importar snapshot de composição","open":"Abrir encontros ou rascunho","save":"Salvar encontros","publish":"Publicações locais"}[action]; _dialog.filters = PackedStringArray(["*.json ; Fonte de mapa/encontros"]) if action != "publish" else PackedStringArray(); _dialog.popup_centered_ratio(0.75)
func file_selected(path: String) -> void:
	match _action:
		"map":
			show_result(import_map_path(path))
		"open":
			show_result(open_document(path,true))
		"save":
			show_result(save_document(path,IO.disk_hash(path)))
		"publish":
			if not result.get("ok",false): status.text = "Compile antes de publicar."; return
			var published := Store.publish(path,result.package,Document.hash_source(session.data)); show_result(published)
			if published.ok: status.text = "Revisão imutável publicada: "+published.path
func import_map_path(path: String) -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var loaded := MapStore.load_source(path)
	return import_map(loaded.data) if loaded.ok else loaded
func map_query() -> Dictionary: return Operations.query_package(canvas.package)
func discard_proposal() -> Dictionary:
	proposal = {}; _proposal_signature = ""; showing_proposal = false
	canvas.source = session.data.duplicate(true); canvas.preview_diff = {}; canvas.redraw(); return {"ok":true}
func _ax_fields() -> Dictionary:
	var fields := {"population/document/new":{"document_id":"id","name":"string","confirm_discard":"bool"},"population/document/name":Operations.FIELDS.name,"population/document/open":{"path":"string","confirm_discard":"bool"},"population/document/save":{"path":"string"},"population/history/undo":{},"population/history/redo":{},"population/map/import":{"path":"string"},"population/map/query":{},"population/catalog/options":{},"population/brush/select":{"brush_id":"id"},"population/slot/select":{"slot_id":"id"},"population/surface/select":{"surface_id":"string"},"population/plan/preview":{},"population/plan/apply":{"expected_source_hash":"hash","proposal_hash":"hash","confirm_apply":"bool"},"population/plan/discard":{},"population/compile":{},"population/cancel":{}}
	for operation: String in Operations.FIELDS:
		if operation != "name": fields["population/"+operation] = Operations.FIELDS[operation]
	return fields
func authoring_commands() -> Array:
	var commands: Array = []
	for id: String in _ax_fields(): commands.append({"id":id,"parameters":_ax_fields()[id]})
	return commands
func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	var fields := _ax_fields()
	if not fields.has(id): return Operations.fail("action_missing")
	var errors: Array = []; Operations.Schema._shape(parameters,fields[id],"parameters",errors)
	if not errors.is_empty(): return Operations.fail("arguments_invalid")
	var applied: Dictionary
	match id:
		"population/document/new": applied = new_document(parameters.document_id,parameters.name,parameters.confirm_discard)
		"population/document/name": applied = apply_operation("name",parameters)
		"population/document/open": applied = open_document(parameters.path,parameters.confirm_discard)
		"population/document/save": applied = save_document(parameters.path)
		"population/history/undo", "population/history/redo": applied = history(id == "population/history/redo")
		"population/map/import": applied = import_map_path(parameters.path)
		"population/map/query": applied = map_query()
		"population/catalog/options": applied = Catalog.list_options()
		"population/plan/preview": applied = prepare_plan()
		"population/plan/apply": applied = apply_proposal(parameters.expected_source_hash,parameters.proposal_hash,parameters.confirm_apply)
		"population/plan/discard": applied = discard_proposal()
		"population/compile": applied = bake()
		"population/cancel": applied = cancel_job()
		"population/slot/select":
			if Operations.find(session.data.slots,"slot_id",parameters.slot_id).is_empty(): return Operations.fail("entity_missing",parameters.slot_id)
			select_slot(parameters.slot_id); applied = {"ok":true}
		"population/brush/select":
			if Operations.find(session.data.brushes,"brush_id",parameters.brush_id).is_empty(): return Operations.fail("entity_missing",parameters.brush_id)
			for index: int in session.data.brushes.size():
				if session.data.brushes[index].brush_id == parameters.brush_id: brushes.select(index); select_brush(index)
			applied = {"ok":true}
		"population/surface/select":
			var selected := -1
			for index: int in surface.item_count:
				if (index == 0 and parameters.surface_id.is_empty()) or surface.get_item_text(index) == parameters.surface_id: selected = index; break
			if selected < 0: return Operations.fail("entity_missing",parameters.surface_id)
			surface.select(selected); canvas.selected_surface = parameters.surface_id; canvas.redraw(); applied = {"ok":true}
		_: applied = apply_operation(id.trim_prefix("population/"),parameters)
	if applied.ok:
		applied.output_hash = Document.hash_source(session.data)
		if not applied.has("entity_id"): applied.entity_id = session.data.document_id
	show_result(applied); return applied
func show_result(value: Dictionary) -> void:
	problems.clear()
	for diagnostic: Dictionary in value.get("diagnostics",[]): problems.add_item(diagnostic.message); problems.set_item_metadata(problems.item_count-1,diagnostic)
	if not value.ok: status.text = value.get("code","Falha")+" · "+(str(value.diagnostics[0].message) if not value.get("diagnostics",[]).is_empty() else "A fonte atual foi preservada.")
func focus_problem(index: int) -> void:
	var diagnostic: Dictionary = problems.get_item_metadata(index); var id: String = diagnostic.entity_id
	select_slot(id)
	for i: int in session.data.brushes.size():
		if session.data.brushes[i].brush_id == id: brushes.select(i); select_brush(i)
	for i: int in _marker_ids.size():
		if _marker_ids[i].id == id: markers.select(i)
	status.text = diagnostic.message
	canvas._viewport_tools.focus_entity(id)
