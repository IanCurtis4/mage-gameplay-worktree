@tool
extends VBoxContainer
const Document = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const RootSynthesisSection = preload("res://scripts/map_authoring/synthesis/root_synthesis_section.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Session = preload("res://scripts/map_authoring/patrol/patrol_session.gd")
const Canvas = preload("res://scripts/map_authoring/patrol/patrol_canvas.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PopulationStore = preload("res://scripts/map_authoring/population/population_store.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
const Operations = preload("res://scripts/map_authoring/patrol/patrol_operations.gd")
const Common = preload("res://scripts/map_authoring/population/population_operations.gd")
const Flow = preload("res://scripts/map_authoring/workflow/authoring_flow.gd")
const WorkflowBar = preload("res://scripts/map_authoring/workflow/workflow_bar.gd")
var gameplay_tools: Control
var flow: RefCounted
var workflow_bar: VBoxContainer
var name_edit: LineEdit
var session := Session.new()
var canvas: Control
var routes: ItemList
var points: ItemList
var slots: ItemList
var mode: OptionButton
var surface: OptionButton
var wait_time: SpinBox
var status: Label
var problems: ItemList
var dialog: FileDialog
var confirmation: ConfirmationDialog
var action := ""
var pending := ""
var source_path := ""
var expected_hash := ""
var autosave := ""
var result: Dictionary = {}
var job: Thread
var cancelled := false
var mutex := Mutex.new()
var preview_pid := -1
var preview_package := ""
var exchange_panel: Control
func _ready() -> void:
	exchange_panel = preload("res://scripts/map_authoring/exchange/exchange_panel.gd").mount(self,"patrol",func() -> Dictionary: return session.data.duplicate(true),session.apply)
	size_flags_vertical = SIZE_EXPAND_FILL; size_flags_horizontal = SIZE_EXPAND_FILL
	var heading := Label.new(); heading.text = "Patrulhas · rotas, espera e continuidade"; heading.add_theme_font_size_override("font_size",22); add_child(heading)
	var name_row := HBoxContainer.new(); add_child(name_row); name_edit = LineEdit.new(); name_edit.size_flags_horizontal = SIZE_EXPAND_FILL; name_row.add_child(name_edit)
	button(name_row,"Aplicar nome",func() -> void: apply_operation("name",{"name":name_edit.text}))
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	for entry: Array in [["Novo",new_document],["Importar encontros…",func() -> void: choose("population")],["Abrir…",func() -> void: choose("open")],["Salvar como…",func() -> void: choose("save")],["Desfazer",func() -> void: history(false)],["Refazer",func() -> void: history(true)],["Recuperar…",func() -> void: choose("recover")]]: button(toolbar,entry[0],entry[1])
	var commands := HBoxContainer.new(); add_child(commands)
	for entry: Array in [["Compilar",bake],["Cancelar",cancel],["Testar atores",func() -> void: test(false)],["Retomar teste",func() -> void: test(true)],["Publicar localmente…",func() -> void: choose("publish")]]: button(commands,entry[0],entry[1])
	var split := HSplitContainer.new(); split.size_flags_vertical = SIZE_EXPAND_FILL; add_child(split)
	var inspector := VBoxContainer.new(); inspector.custom_minimum_size.x = 310; split.add_child(inspector)
	var info := Label.new(); info.text = "Adicione pontos na ordem com um clique.\nLinhas guiam; o teste usa a rota válida.\nOrigem e limite de retorno fixos."; inspector.add_child(info)
	routes = ItemList.new(); routes.custom_minimum_size.y = 75; inspector.add_child(routes); routes.item_selected.connect(func(_i: int) -> void: refresh_route())
	var row := HBoxContainer.new(); inspector.add_child(row); button(row,"Nova rota",add_route); button(row,"Remover…",func() -> void: request_remove("route"))
	mode = OptionButton.new(); mode.add_item("Loop"); mode.add_item("Ida e volta"); inspector.add_child(mode); mode.item_selected.connect(func(_i: int) -> void: apply_mode())
	surface = OptionButton.new(); surface.add_item("Todas as superfícies visíveis"); inspector.add_child(surface); surface.item_selected.connect(func(i: int) -> void: canvas.selected_surface = "" if i == 0 else surface.get_item_text(i))
	points = ItemList.new(); points.custom_minimum_size.y = 130; inspector.add_child(points); points.item_selected.connect(func(i: int) -> void:
		var route := current_route()
		if not route.is_empty(): wait_time.value = route.waypoints[i].wait_seconds)
	var wait_row := HBoxContainer.new(); inspector.add_child(wait_row); var wait_label := Label.new(); wait_label.text = "Espera (s)"; wait_row.add_child(wait_label)
	wait_time = SpinBox.new(); wait_time.max_value = 300; wait_time.step = 0.1; wait_row.add_child(wait_time); button(wait_row,"Aplicar",apply_wait)
	row = HBoxContainer.new(); inspector.add_child(row); button(row,"↑",func() -> void: move_point(-1)); button(row,"↓",func() -> void: move_point(1)); button(row,"Remover ponto…",func() -> void: request_remove("point"))
	var slot_label := Label.new(); slot_label.text = "Slots do encontro (seleção múltipla)"; inspector.add_child(slot_label)
	slots = ItemList.new(); slots.select_mode = ItemList.SELECT_MULTI; slots.custom_minimum_size.y = 110; inspector.add_child(slots); button(inspector,"Vincular slots selecionados",assign_slots)
	canvas = Canvas.new(); canvas.paint_enabled = true; split.add_child(canvas); canvas.painted.connect(add_point)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	problems = ItemList.new(); problems.custom_minimum_size.y = 60; add_child(problems)
	problems.item_selected.connect(func(i: int) -> void:
		var diagnostic: Dictionary = problems.get_item_metadata(i)
		for n: int in session.data.patrols.size():
			if session.data.patrols[n].patrol_id == diagnostic.entity_id: routes.select(n); refresh_route()
		canvas._viewport_tools.focus_entity(str(diagnostic.entity_id)))
	dialog = FileDialog.new(); dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.file_selected.connect(file_selected); dialog.dir_selected.connect(file_selected); add_child(dialog)
	confirmation = ConfirmationDialog.new(); confirmation.confirmed.connect(confirm_remove); add_child(confirmation)
	session.changed.connect(changed); _new_draft(); refresh()
	var timer := Timer.new(); timer.wait_time = 10; timer.autostart = true; timer.timeout.connect(preserve_draft); add_child(timer)
	preload("res://scripts/map_authoring/preview/viewport_tools.gd").mount(canvas,"patrol")
	gameplay_tools = preload("res://scripts/map_authoring/preview/gameplay_tools.gd").mount(self,"patrol","patrol",func() -> Dictionary: return session.data,func() -> Dictionary: return result.get("package",{}) if result.get("ok",false) else {},func() -> String: return Document.hash_source(session.data))
	# Checkpoint44 (F9-05, P3b): regional variation of one instance; its own AX provider.
	synthesis = RootSynthesisSection.new(); add_child(synthesis); synthesis.setup(self,"patrol","patrol"); synthesis.refresh()
	# Checkpoint49 (F9-06/07, P6a): the guided step bar shared by the screens.
	var owns_flow: bool = flow == null
	if owns_flow: flow = Flow.new()
	flow.attach("patrol",self); workflow_bar = WorkflowBar.mount(self,flow,"patrol","patrol",owns_flow)
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"patrol",func() -> Dictionary: return session.data,canvas)
var synthesis: VBoxContainer
func button(parent: Node, caption: String, callback: Callable) -> void:
	var b := Button.new(); b.text = caption; b.pressed.connect(callback); parent.add_child(b)
func _new_draft() -> void:
	autosave = ProjectSettings.globalize_path("res://.godot/map_authoring/patrol_"+Crypto.new().generate_random_bytes(12).hex_encode()+".json"); DirAccess.make_dir_recursive_absolute(autosave.get_base_dir())
func _dirty() -> bool:
	return session.dirty() or (name_edit != null and name_edit.text != session.data.name)
func _pending_source() -> Dictionary:
	return Operations.propose(session.data,"name",{"name":name_edit.text if name_edit != null else session.data.name})
func preserve_draft() -> bool:
	if not _dirty(): return true
	if autosave.is_empty(): return false
	var pending_source := _pending_source()
	if not pending_source.ok: return false
	return Store.save_source(autosave,pending_source.data,IO.disk_hash(autosave)).ok
func _confirm_replace(confirmed: bool) -> Dictionary:
	if not _dirty(): return {"ok":true}
	if not confirmed: return Operations.fail("confirmation_required")
	return {"ok":true} if preserve_draft() else Operations.fail("io_recovery_required")
func new_document(document_id: String = "patrols", caption: String = "Patrulhas", confirmed: bool = true) -> Dictionary:
	var data := Document.empty(document_id); data.name = caption
	var checked := Document.validate(data)
	if not checked.ok: return checked
	var allowed := _confirm_replace(confirmed)
	if not allowed.ok: return allowed
	_new_draft(); source_path = ""; expected_hash = ""; session.saved_hash = ""; canvas.clear()
	return session.replace(data)
func _valid_path(path: String) -> bool:
	return not path.strip_edges().is_empty() and not path.to_utf8_buffer().has(0)
func open_document(path: String, confirmed: bool, recovery: bool = false) -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var loaded := Store.load_source(path)
	if not loaded.ok: return loaded
	var allowed := _confirm_replace(confirmed)
	if not allowed.ok: return allowed
	_new_draft(); source_path = "" if recovery else ProjectSettings.globalize_path(path).simplify_path(); expected_hash = "" if recovery else loaded.byte_hash
	session.saved_hash = ""; canvas.clear(); var applied := session.replace(loaded.data)
	if not recovery: session.saved_hash = Document.hash_source(session.data)
	if not loaded.data.population.is_empty() and not loaded.data.population[0].map.is_empty():
		var built := Population.MapCompiler.compile(loaded.data.population[0].map[0])
		if built.ok: canvas.set_package(built.package); _surfaces()
	return applied
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
	var changed_history: bool = session.redo() if redo else session.undo()
	return {"ok":true,"output_hash":Document.hash_source(session.data)} if changed_history else Operations.fail("history_empty")
func import_population(source: Dictionary, confirmed: bool = true) -> Dictionary:
	var checked := PopulationStore.Document.validate(source)
	if not checked.ok: show_result(checked); return checked
	var map := Population.MapCompiler.compile(source.map[0]) if not source.map.is_empty() else {"ok":true}
	if not map.ok: return map
	var pending_source := _pending_source()
	if not pending_source.ok: return pending_source
	var data := Document.empty(session.data.document_id); data.name = pending_source.data.name; data.revision = session.data.revision; data.population = [source.duplicate(true)]
	var allowed := _confirm_replace(confirmed)
	if not allowed.ok: return allowed
	_new_draft(); source_path = ""; expected_hash = ""; session.saved_hash = ""; canvas.clear(); session.replace(data)
	if map.has("package"): canvas.set_package(map.package); _surfaces()
	status.text = "Encontros importados. Crie uma rota e vincule slots."; return {"ok":true}
func import_population_path(path: String, confirmed: bool) -> Dictionary:
	if not _valid_path(path): return Operations.fail("arguments_invalid")
	var loaded := PopulationStore.load_source(path)
	return import_population(loaded.data,confirmed) if loaded.ok else loaded
func apply_operation(operation: String, parameters: Dictionary) -> Dictionary:
	var base := {"ok":true,"data":session.data} if operation == "name" else _pending_source()
	if not base.ok: return base
	var proposed := Operations.propose(base.data,operation,parameters)
	if not proposed.ok: show_result(proposed); return proposed
	var applied := session.apply(proposed.data)
	if applied.ok:
		applied.entity_id = proposed.entity_id; applied.added_ids = proposed.added_ids; applied.removed_ids = proposed.removed_ids; applied.output_hash = Document.hash_source(session.data)
		if parameters.has("patrol_id"): select_route(parameters.patrol_id)
		if parameters.has("point_id"):
			var route := current_route()
			for index: int in route.get("waypoints",[]).size():
				if route.waypoints[index].point_id == parameters.point_id: points.select(index); wait_time.value = route.waypoints[index].wait_seconds
	show_result(applied); return applied
func select_route(id: String) -> void:
	for index: int in session.data.patrols.size():
		if session.data.patrols[index].patrol_id == id: routes.select(index); refresh_route(); return
func changed() -> void:
	result = {}; refresh(); status.text = "Alterações pendentes de compilação."
func refresh() -> void:
	if routes == null: return
	if synthesis != null: synthesis.refresh()
	name_edit.text = session.data.name
	var selected := routes.get_selected_items(); var index := selected[0] if not selected.is_empty() else 0
	routes.clear()
	for route: Dictionary in session.data.patrols: routes.add_item(route.patrol_id)
	if routes.item_count > 0: routes.select(mini(index,routes.item_count-1))
	slots.clear()
	canvas.source = {} if session.data.population.is_empty() else session.data.population[0].duplicate(true)
	if not session.data.population.is_empty():
		for slot: Dictionary in session.data.population[0].slots: slots.add_item(slot.slot_id+" · "+slot.species_id)
	canvas.patrol_source = session.data.duplicate(true); refresh_route(); canvas.redraw()
func current_route() -> Dictionary:
	var selected := routes.get_selected_items()
	return session.data.patrols[selected[0]].duplicate(true) if not selected.is_empty() else {}
func replace_route(route: Dictionary) -> void:
	apply_operation("route/upsert",route)
func refresh_route() -> void:
	points.clear(); slots.deselect_all(); var route := current_route(); canvas.selected_route = route.get("patrol_id","")
	if route.is_empty(): return
	mode.select(0 if route.mode == "loop" else 1)
	for i: int in route.waypoints.size(): points.add_item("%d · %s · %.1f s"%[i+1,route.waypoints[i].point_id,route.waypoints[i].wait_seconds])
	if not session.data.population.is_empty():
		for i: int in session.data.population[0].slots.size():
			if session.data.population[0].slots[i].slot_id in route.slot_ids: slots.select(i,false)
	canvas.redraw()
func add_route() -> void:
	var id := "patrol_"+Crypto.new().generate_random_bytes(4).hex_encode()
	apply_operation("route/upsert",{"patrol_id":id,"revision":1,"mode":"loop","slot_ids":[],"waypoints":[]})
func add_point(point: Dictionary) -> void:
	var route := current_route()
	if route.is_empty(): status.text = "Crie ou selecione uma rota."; return
	var waypoint := point.duplicate(true); waypoint["point_id"] = "point_"+Crypto.new().generate_random_bytes(4).hex_encode(); waypoint["wait_seconds"] = wait_time.value
	waypoint.patrol_id = route.patrol_id; apply_operation("waypoint/upsert",waypoint)
func apply_mode() -> void:
	var route := current_route()
	if not route.is_empty(): route.mode = "loop" if mode.selected == 0 else "ping_pong"; replace_route(route)
func apply_wait() -> void:
	var route := current_route(); var selected := points.get_selected_items()
	if route.is_empty() or selected.is_empty(): return
	route.waypoints[selected[0]].wait_seconds = wait_time.value; replace_route(route)
func move_point(direction: int) -> void:
	var route := current_route(); var selected := points.get_selected_items()
	if route.is_empty() or selected.is_empty(): return
	apply_operation("waypoint/move",{"patrol_id":route.patrol_id,"point_id":route.waypoints[selected[0]].point_id,"direction":direction})
func assign_slots() -> void:
	var route := current_route()
	if route.is_empty() or session.data.population.is_empty(): return
	route.slot_ids = []
	for i: int in slots.get_selected_items(): route.slot_ids.append(session.data.population[0].slots[i].slot_id)
	replace_route(route)
func request_remove(kind: String) -> void:
	if current_route().is_empty() or (kind == "point" and points.get_selected_items().is_empty()): return
	pending = kind; confirmation.dialog_text = "Remover "+("a rota e seus vínculos?" if kind == "route" else "o ponto selecionado?"); confirmation.popup_centered()
func confirm_remove() -> void:
	var route := current_route()
	if route.is_empty(): return
	if pending == "route": apply_operation("route/remove",{"patrol_id":route.patrol_id,"confirm_remove":true})
	elif not points.get_selected_items().is_empty(): apply_operation("waypoint/remove",{"patrol_id":route.patrol_id,"point_id":route.waypoints[points.get_selected_items()[0]].point_id,"confirm_remove":true})
func _surfaces() -> void:
	surface.clear(); surface.add_item("Todas as superfícies visíveis")
	for cell: Dictionary in canvas.package.manifest.stages[0].surfaces: surface.add_item(cell.surface_id)
func bake() -> Dictionary:
	if job != null: return Operations.fail("job_running")
	var pending_source := _pending_source()
	if not pending_source.ok: return pending_source
	session.apply(pending_source.data)
	result = {}; cancelled = false; var data: Dictionary = session.data.duplicate(true); var hash := Document.hash_source(data)
	job = Thread.new(); job.start(func() -> Dictionary:
		var output := Compiler.compile(data,func() -> bool:
			mutex.lock(); var stopped := cancelled; mutex.unlock(); return stopped)
		output["base_hash"] = hash; return output)
	status.text = "Validando corpo, limite de retorno e todos os trechos…"
	return {"ok":true}
func cancel() -> Dictionary:
	mutex.lock(); cancelled = true; mutex.unlock()
	return {"ok":true}
func _process(_delta: float) -> void:
	if job == null or job.is_alive(): return
	result = job.wait_to_finish(); job = null
	if cancelled: result = Compiler.fail("cancelled")
	elif result.get("base_hash","") != Document.hash_source(session.data): result = Compiler.fail("stale_source")
	show_result(result)
	if result.ok: status.text = "Patrulhas validadas. Teste os atores ou publique localmente."
func show_result(value: Dictionary) -> void:
	problems.clear()
	if not value.ok: status.text = "Não concluído: "+String(value.get("code","erro"))
	for diagnostic: Dictionary in value.get("diagnostics",[]): problems.add_item(diagnostic.message); problems.set_item_metadata(problems.item_count-1,diagnostic)
func choose(kind: String) -> void:
	action = kind; dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if kind == "save" else (FileDialog.FILE_MODE_OPEN_DIR if kind == "publish" else FileDialog.FILE_MODE_OPEN_FILE)
	dialog.title = {"population":"Importar encontros","open":"Abrir patrulhas","save":"Salvar patrulhas","recover":"Recuperar rascunho, .pending ou .bak","publish":"Publicar pacote local"}[kind]
	dialog.filters = PackedStringArray() if kind == "publish" else PackedStringArray(["*.json,*.pending,*.bak ; Fontes e recuperação"]); dialog.popup_centered_ratio(0.75)
func file_selected(path: String) -> void:
	if action == "population":
		show_result(import_population_path(path,true))
	elif action in ["open","recover"]:
		show_result(open_document(path,true,action == "recover"))
	elif action == "save":
		var saved := save_document(path,IO.disk_hash(path)); show_result(saved)
		if saved.ok: status.text = "Patrulhas salvas."
	elif action == "publish":
		if not result.get("ok",false): status.text = "Compile antes de publicar."; return
		var published := Store.publish(path,result.package,Document.hash_source(session.data)); show_result(published)
		if published.ok: status.text = "Pacote local publicado: "+published.path
func map_query() -> Dictionary: return Common.query_package(canvas.package)
func _ax_fields() -> Dictionary:
	var fields := {"patrol/document/new":{"document_id":"id","name":"string","confirm_discard":"bool"},"patrol/document/name":Operations.FIELDS.name,"patrol/document/open":{"path":"string","confirm_discard":"bool"},"patrol/document/save":{"path":"string"},"patrol/history/undo":{},"patrol/history/redo":{},"patrol/population/import":{"path":"string","confirm_discard":"bool"},"patrol/map/query":{},"patrol/route/select":{"patrol_id":"id"},"patrol/surface/select":{"surface_id":"string"},"patrol/compile":{},"patrol/cancel":{}}
	for operation: String in Operations.FIELDS:
		if operation != "name": fields["patrol/"+operation] = Operations.FIELDS[operation]
	return fields
func authoring_commands() -> Array:
	var commands: Array = []
	for id: String in _ax_fields(): commands.append({"id":id,"parameters":_ax_fields()[id]})
	return commands
func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	var fields := _ax_fields()
	if not fields.has(id): return Operations.fail("action_missing")
	var errors: Array = []; Common.Schema._shape(parameters,fields[id],"parameters",errors)
	if not errors.is_empty(): return Operations.fail("arguments_invalid")
	var applied: Dictionary
	match id:
		"patrol/document/new": applied = new_document(parameters.document_id,parameters.name,parameters.confirm_discard)
		"patrol/document/name": applied = apply_operation("name",parameters)
		"patrol/document/open": applied = open_document(parameters.path,parameters.confirm_discard)
		"patrol/document/save": applied = save_document(parameters.path)
		"patrol/history/undo", "patrol/history/redo": applied = history(id == "patrol/history/redo")
		"patrol/population/import": applied = import_population_path(parameters.path,parameters.confirm_discard)
		"patrol/map/query": applied = map_query()
		"patrol/compile": applied = bake()
		"patrol/cancel": applied = cancel()
		"patrol/route/select":
			if Common.find(session.data.patrols,"patrol_id",parameters.patrol_id).is_empty(): return Operations.fail("entity_missing",parameters.patrol_id)
			select_route(parameters.patrol_id); applied = {"ok":true}
		"patrol/surface/select":
			var selected := -1
			for index: int in surface.item_count:
				if (index == 0 and parameters.surface_id.is_empty()) or surface.get_item_text(index) == parameters.surface_id: selected = index; break
			if selected < 0: return Operations.fail("entity_missing",parameters.surface_id)
			surface.select(selected); canvas.selected_surface = parameters.surface_id; canvas.redraw(); applied = {"ok":true}
		_: applied = apply_operation(id.trim_prefix("patrol/"),parameters)
	if applied.ok:
		applied.output_hash = Document.hash_source(session.data)
		if not applied.has("entity_id"): applied.entity_id = session.data.document_id
	show_result(applied); return applied
func test(resume: bool) -> void:
	var opened: Dictionary = gameplay_tools.resume() if resume else gameplay_tools.launch()
	status.text = "Teste de jogo solicitado; use a janela para jogar ou suspender." if opened.ok else gameplay_tools.message.text
func _exit_tree() -> void:
	if job != null: cancel(); job.wait_to_finish(); job = null
	preserve_draft()
