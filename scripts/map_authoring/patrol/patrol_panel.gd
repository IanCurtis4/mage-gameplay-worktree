@tool
extends VBoxContainer
const Document = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const Compiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Store = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Session = preload("res://scripts/map_authoring/patrol/patrol_session.gd")
const Canvas = preload("res://scripts/map_authoring/patrol/patrol_canvas.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PopulationStore = preload("res://scripts/map_authoring/population/population_store.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
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
func _ready() -> void:
	size_flags_vertical = SIZE_EXPAND_FILL; size_flags_horizontal = SIZE_EXPAND_FILL
	var heading := Label.new(); heading.text = "Patrulhas · rotas, espera e continuidade"; heading.add_theme_font_size_override("font_size",22); add_child(heading)
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	for entry: Array in [["Novo",new_document],["Importar encontros…",func() -> void: choose("population")],["Abrir…",func() -> void: choose("open")],["Salvar como…",func() -> void: choose("save")],["Desfazer",func() -> void: session.undo()],["Refazer",func() -> void: session.redo()],["Recuperar…",func() -> void: choose("recover")]]: button(toolbar,entry[0],entry[1])
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
			if session.data.patrols[n].patrol_id == diagnostic.entity_id: routes.select(n); refresh_route())
	dialog = FileDialog.new(); dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.file_selected.connect(file_selected); dialog.dir_selected.connect(file_selected); add_child(dialog)
	confirmation = ConfirmationDialog.new(); confirmation.confirmed.connect(confirm_remove); add_child(confirmation)
	session.changed.connect(changed); _new_draft(); refresh()
	var timer := Timer.new(); timer.wait_time = 10; timer.autostart = true; timer.timeout.connect(preserve_draft); add_child(timer)
func button(parent: Node, caption: String, callback: Callable) -> void:
	var b := Button.new(); b.text = caption; b.pressed.connect(callback); parent.add_child(b)
func _new_draft() -> void:
	autosave = ProjectSettings.globalize_path("res://.godot/map_authoring/patrol_"+Crypto.new().generate_random_bytes(12).hex_encode()+".json"); DirAccess.make_dir_recursive_absolute(autosave.get_base_dir())
func preserve_draft() -> void:
	if session.dirty() and autosave != "": Store.save_source(autosave,session.data,IO.disk_hash(autosave))
func new_document() -> void:
	preserve_draft(); _new_draft(); source_path = ""; expected_hash = ""; session.replace(Document.empty()); canvas.clear()
func import_population(source: Dictionary) -> Dictionary:
	var checked := PopulationStore.Document.validate(source)
	if not checked.ok: show_result(checked); return checked
	var data := Document.empty(); data.population = [source.duplicate(true)]
	preserve_draft(); _new_draft(); source_path = ""; expected_hash = ""; session.replace(data)
	var map := Population.MapCompiler.compile(source.map[0]) if not source.map.is_empty() else {"ok":false}
	if map.ok: canvas.set_package(map.package); _surfaces()
	status.text = "Encontros importados. Crie uma rota e vincule slots."; return {"ok":true}
func changed() -> void:
	result = {}; refresh(); status.text = "Alterações pendentes de compilação."
func refresh() -> void:
	if routes == null: return
	var selected := routes.get_selected_items(); var index := selected[0] if not selected.is_empty() else 0
	routes.clear()
	for route: Dictionary in session.data.patrols: routes.add_item(route.patrol_id)
	if routes.item_count > 0: routes.select(mini(index,routes.item_count-1))
	slots.clear()
	if not session.data.population.is_empty():
		canvas.source = session.data.population[0].duplicate(true)
		for slot: Dictionary in session.data.population[0].slots: slots.add_item(slot.slot_id+" · "+slot.species_id)
	canvas.patrol_source = session.data.duplicate(true); refresh_route(); canvas.redraw()
func current_route() -> Dictionary:
	var selected := routes.get_selected_items()
	return session.data.patrols[selected[0]].duplicate(true) if not selected.is_empty() else {}
func replace_route(route: Dictionary) -> void:
	var data: Dictionary = session.data.duplicate(true)
	for i: int in data.patrols.size():
		if data.patrols[i].patrol_id == route.patrol_id: data.patrols[i] = route
	show_result(session.apply(data))
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
	var data: Dictionary = session.data.duplicate(true); var id := "patrol_"+Crypto.new().generate_random_bytes(4).hex_encode()
	data.patrols.append({"patrol_id":id,"revision":1,"mode":"loop","slot_ids":[],"waypoints":[]}); show_result(session.apply(data)); routes.select(routes.item_count-1); refresh_route()
func add_point(point: Dictionary) -> void:
	var route := current_route()
	if route.is_empty(): status.text = "Crie ou selecione uma rota."; return
	var waypoint := point.duplicate(true); waypoint["point_id"] = "point_"+Crypto.new().generate_random_bytes(4).hex_encode(); waypoint["wait_seconds"] = wait_time.value
	route.waypoints.append(waypoint); replace_route(route)
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
	var i := selected[0]; var j := i+direction
	if j < 0 or j >= route.waypoints.size(): return
	var p: Dictionary = route.waypoints[i]; route.waypoints[i] = route.waypoints[j]; route.waypoints[j] = p; replace_route(route); points.select(j)
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
	var data: Dictionary = session.data.duplicate(true); var index := routes.get_selected_items()[0]
	if pending == "route": data.patrols.remove_at(index)
	elif not points.get_selected_items().is_empty(): data.patrols[index].waypoints.remove_at(points.get_selected_items()[0])
	show_result(session.apply(data))
func _surfaces() -> void:
	surface.clear(); surface.add_item("Todas as superfícies visíveis")
	for cell: Dictionary in canvas.package.manifest.stages[0].surfaces: surface.add_item(cell.surface_id)
func bake() -> void:
	if job != null: return
	result = {}; cancelled = false; var data: Dictionary = session.data.duplicate(true); var hash := Document.hash_source(data)
	job = Thread.new(); job.start(func() -> Dictionary:
		var output := Compiler.compile(data,func() -> bool:
			mutex.lock(); var stopped := cancelled; mutex.unlock(); return stopped)
		output["base_hash"] = hash; return output)
	status.text = "Validando corpo, limite de retorno e todos os trechos…"
func cancel() -> void:
	mutex.lock(); cancelled = true; mutex.unlock()
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
		var loaded := PopulationStore.load_source(path)
		if loaded.ok: import_population(loaded.data)
		else: show_result(loaded)
	elif action in ["open","recover"]:
		var loaded := Store.load_source(path)
		if not loaded.ok: show_result(loaded); return
		preserve_draft(); _new_draft(); session.replace(loaded.data)
		source_path = path if action == "open" else ""; expected_hash = IO.disk_hash(path) if action == "open" else ""
		if action == "open": session.saved_hash = Document.hash_source(session.data)
		canvas.clear()
		if not loaded.data.population.is_empty() and not loaded.data.population[0].map.is_empty():
			var built := Population.MapCompiler.compile(loaded.data.population[0].map[0])
			if built.ok: canvas.set_package(built.package); _surfaces()
	elif action == "save":
		var saved := Store.save_source(path,session.data,expected_hash if path == source_path else "")
		show_result(saved)
		if saved.ok: source_path = path; expected_hash = IO.disk_hash(path); session.saved_hash = Document.hash_source(session.data); status.text = "Patrulhas salvas."
	elif action == "publish":
		if not result.get("ok",false): status.text = "Compile antes de publicar."; return
		var published := Store.publish(path,result.package,Document.hash_source(session.data)); show_result(published)
		if published.ok: status.text = "Pacote local publicado: "+published.path
func test(resume: bool) -> void:
	if not result.get("ok",false): status.text = "Compile antes de testar."; return
	if preview_pid > 0 and OS.is_process_running(preview_pid): status.text = "O teste já está aberto."; return
	var directory := ProjectSettings.globalize_path("res://.godot/map_authoring/patrol_tests/"+result.output_hash); DirAccess.make_dir_recursive_absolute(directory)
	var published := Store.publish(directory,result.package,Document.hash_source(session.data))
	if not published.ok: show_result(published); return
	preview_package = published.path
	var args := PackedStringArray(["--path",ProjectSettings.globalize_path("res://"),"--log-file",directory.path_join("preview.log"),"--script","res://scripts/map_authoring/patrol/patrol_preview.gd","--",preview_package])
	if resume: args.append("resume")
	preview_pid = OS.create_process(OS.get_executable_path(),args,false); status.text = "Teste descartável aberto. Suspenda na janela para retomar depois."
func _exit_tree() -> void:
	if job != null: cancel(); job.wait_to_finish(); job = null
	preserve_draft()
