@tool
extends VBoxContainer
const Model = preload("res://scripts/map_authoring/library/library_model.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const TerrainCompiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const TerrainCanvas = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
const MapCanvas = preload("res://scripts/map_authoring/preview/map_canvas.gd")
var source_action: Callable
var asset_action: Callable
var search: LineEdit
var category: OptionButton
var favorites_only: CheckButton
var palette: ItemList
var details: Label
var status: Label
var progress: ProgressBar
var preview: TextureRect
var _entries: Array = []
var _selected: Dictionary = {}
var _images := {}
var _environment := ""
var _queue: Array[String] = []
var _pending := ""
var _job: RefCounted
var _active: Dictionary = {}
var _rendering := false
var _cancelled := false
var _generation := 0
var _diagnostic_code := ""
var _preferences_seen := ""
var _recovery_button: Button
var _recovery_dialog: ConfirmationDialog
var _recovery_hash := ""
var _viewport: SubViewport
var _piece_canvas: Control
var _map_canvas: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row := HFlowContainer.new(); add_child(row)
	search = LineEdit.new(); search.placeholder_text = "Buscar nome, categoria ou ID"; search.custom_minimum_size.x = 260; row.add_child(search); search.text_changed.connect(func(_text: String) -> void: filter_items())
	category = OptionButton.new(); category.add_item("Todas as categorias"); category.set_item_metadata(0,"")
	for id: String in Model.CATEGORIES: category.add_item(Model.CATEGORIES[id]); category.set_item_metadata(category.item_count-1,id)
	row.add_child(category); category.item_selected.connect(func(_i: int) -> void: filter_items())
	favorites_only = CheckButton.new(); favorites_only.text = "Favoritos"; row.add_child(favorites_only); favorites_only.toggled.connect(func(_on: bool) -> void: filter_items())
	_button(row,"Registrar fonte…",choose_sources); _button(row,"Atualizar biblioteca",refresh)
	_recovery_button = _button(row,"Recuperar preferências…",request_preferences_recovery); _recovery_button.set_meta("authoring_keep_visible",false)
	var split := HSplitContainer.new(); split.size_flags_vertical = Control.SIZE_EXPAND_FILL; add_child(split)
	palette = ItemList.new(); palette.custom_minimum_size = Vector2(360,320); palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL; palette.size_flags_vertical = Control.SIZE_EXPAND_FILL; palette.fixed_icon_size = Vector2i(112,84); palette.icon_mode = ItemList.ICON_MODE_TOP; palette.max_columns = 3; split.add_child(palette)
	palette.item_selected.connect(func(i: int) -> void: select_entry(str(palette.get_item_metadata(i))))
	palette.item_activated.connect(func(_i: int) -> void: activate_selected(false))
	var right := VBoxContainer.new(); right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; split.add_child(right)
	preview = TextureRect.new(); preview.custom_minimum_size = Vector2(400,300); preview.size_flags_vertical = Control.SIZE_EXPAND_FILL; preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; right.add_child(preview)
	details = Label.new(); details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; right.add_child(details)
	var actions := HFlowContainer.new(); right.add_child(actions)
	_button(actions,"Abrir / usar seleção",func() -> void: activate_selected(false))
	_button(actions,"Criar cópia da fonte",func() -> void: activate_selected(true))
	_button(actions,"Favoritar / desfavoritar",toggle_favorite)
	_button(actions,"Esquecer registro",forget_source)
	_button(actions,"Cancelar miniaturas",cancel_preview)
	progress = ProgressBar.new(); progress.show_percentage = true; add_child(progress)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	_recovery_dialog = ConfirmationDialog.new(); add_child(_recovery_dialog)
	_recovery_dialog.confirmed.connect(func() -> void:
		var recovered := Preferences.recover(_recovery_hash)
		if recovered.ok: refresh(); status.text = "Preferências recuperadas. A cópia anterior foi preservada."
		else: _diagnostic(recovered.code))
	_viewport = SubViewport.new(); _viewport.name = "LibraryThumbnailViewport"; _viewport.size = Vector2i(512,384); _viewport.gui_disable_input = true; _viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED; add_child(_viewport)
	var frame := Control.new(); frame.size = Vector2(512,384); _viewport.add_child(frame)
	_piece_canvas = TerrainCanvas.new(); frame.add_child(_piece_canvas); _piece_canvas.custom_minimum_size = Vector2.ZERO; _piece_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _piece_canvas.hide()
	_map_canvas = MapCanvas.new(); frame.add_child(_map_canvas); _map_canvas.custom_minimum_size = Vector2.ZERO; _map_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); _map_canvas.hide()
	refresh()
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"library",func() -> Dictionary: return {"selected_entry":_selected.get("id",""),"preferences":Preferences.read().get("data",{})})

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new(); button.text = caption; button.pressed.connect(action); button.set_meta("authoring_keep_visible",true); parent.add_child(button)
	return button

func request_preferences_recovery() -> void:
	var proposal := Preferences.recovery_preview()
	if not proposal.ok: _diagnostic(proposal.code); return
	_recovery_hash = proposal.expected_hash
	_recovery_dialog.dialog_text = "Recuperar %d favoritos, %d predefinições e %d registros da última cópia válida? As preferências atuais serão guardadas numa cópia de recuperação."%[proposal.data.favorites.size(),proposal.data.presets.size(),proposal.data.sources.size()]
	_recovery_dialog.popup_centered()

func _diagnostic(code: String) -> void:
	_diagnostic_code = code; status.tooltip_text = code
	status.text = {"stale_source":"A fonte mudou durante a prévia. Atualize a biblioteca para conferir a nova revisão.","cancelled":"Prévia cancelada; fontes e registros preservados.","io_missing":"O arquivo não foi encontrado. O registro foi preservado.","preferences_invalid":"As preferências precisam de recuperação. Nenhum registro foi substituído.","preferences_stale":"As preferências mudaram em outra janela. Atualize a biblioteca.","io_recovery_required":"Não foi possível preservar o rascunho atual. Salve uma cópia antes de abrir outra fonte.","border_transition_requires_two_instances":"Selecione duas peças do mapa para configurar a transição entre elas.","library_source_changed":"A fonte mudou desde a seleção. Confira a nova revisão antes de abrir.","library_source_required":"Escolha uma peça ou mapa salvo para criar uma cópia."}.get(code,"Não foi possível concluir a operação. Confira a fonte, seus dados e as dependências.")

func refresh() -> void:
	_generation += 1
	if _job != null: _job.cancel()
	var prefs := Preferences.read()
	_recovery_button.disabled = prefs.ok
	if not prefs.ok: _diagnostic(prefs.code); return
	var found := Model.entries(prefs.data)
	if not found.ok: _diagnostic(found.code); return
	var environment := Model.thumbnail_environment()
	if not environment.ok: _diagnostic(environment.code); return
	_environment = environment.hash; _entries = found.entries; _queue.clear(); _cancelled = false
	_prune_images()
	for entry: Dictionary in _entries:
		if entry.kind != "source": continue
		var cached := Model.cached_thumbnail(entry.source_hash,_environment)
		if cached.ok: _images[entry.id] = ImageTexture.create_from_image(cached.image)
		else: _queue.append(entry.id)
	filter_items(); _diagnostic_code = ""; status.tooltip_text = ""; status.text = "Escolha uma fonte para abrir ou criar uma cópia. Miniaturas são reconstruídas localmente; o registro mostra a revisão salva."

func _prune_images() -> void:
	for id: String in _images.keys():
		if _entry(id).is_empty(): _images.erase(id)

func refresh_preferences() -> void:
	var prefs := Preferences.read()
	if not prefs.ok: _recovery_button.disabled = false; _diagnostic(prefs.code); return
	_recovery_button.disabled = true
	if _preferences_seen == prefs.hash: return
	var sources := Model.source_entries(prefs.data)
	if sources != _entries.filter(func(entry: Dictionary) -> bool: return entry.kind == "source"):
		_generation += 1
		if _job != null: _job.cancel()
		_entries = _entries.filter(func(entry: Dictionary) -> bool: return entry.kind != "source")+sources; _queue.clear(); _prune_images()
		for entry: Dictionary in sources:
			var cached := Model.cached_thumbnail(entry.source_hash,_environment)
			if cached.ok: _images[entry.id] = ImageTexture.create_from_image(cached.image)
			else: _queue.append(entry.id)
		if not _selected.is_empty():
			if not _entry(_selected.id).is_empty(): select_entry(_selected.id)
			else: _selected = {}; preview.texture = null; details.text = "O registro foi removido. O arquivo foi preservado."
	filter_items()

func filter_items() -> void:
	var prefs := Preferences.read()
	if not prefs.ok: return
	palette.clear()
	for entry: Dictionary in Model.query(_entries,search.text,str(category.get_item_metadata(category.selected)),favorites_only.button_pressed,prefs.data.favorites):
		var icon: Texture2D = _images.get(entry.id)
		if entry.kind != "source": icon = load(entry.thumbnail) as Texture2D
		var i := palette.add_item(("★ " if entry.id in prefs.data.favorites else "")+entry.name,icon)
		palette.set_item_metadata(i,entry.id); palette.set_item_tooltip(i,"%s · revisão%s\n%s"%[Model.CATEGORIES[entry.category],str(entry.revision),entry.get("path",entry.id)])
		if entry.id == _selected.get("id"): palette.select(i)
	if not palette.get_selected_items().is_empty(): palette.ensure_current_is_visible.call_deferred()
	_preferences_seen = prefs.hash

func _entry(id: String) -> Dictionary:
	for entry: Dictionary in _entries:
		if entry.id == id: return entry.duplicate(true)
	return {}

func select_entry(id: String) -> Dictionary:
	var entry := _entry(id)
	if entry.is_empty(): return {"ok":false,"code":"library_entry_missing"}
	if _selected.get("id") != id:
		_generation += 1
		if _job != null: _job.cancel()
	_pending = ""
	_selected = entry; details.text = entry.name+"\n"+Model.CATEGORIES[entry.category]+" · revisão "+str(entry.revision)+"\n"+(str(entry.path).get_file() if entry.kind == "source" else entry.definition_id); details.tooltip_text = entry.get("path",entry.id)
	if entry.kind == "source":
		preview.texture = _images.get(id); _cancelled = false
		if (_job == null and not _rendering) or _active.get("id") != id or _active.get("generation") != _generation: _pending = id
	else: preview.texture = load(entry.thumbnail) as Texture2D
	return {"ok":true,"entry":entry}

func choose_sources() -> void:
	var dialog := FileDialog.new(); dialog.access = FileDialog.ACCESS_FILESYSTEM; dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES; dialog.filters = PackedStringArray(["*.json ; Peças e mapas passivos"]); add_child(dialog)
	dialog.files_selected.connect(func(paths: PackedStringArray) -> void:
		for path: String in paths:
			var registered := Model.register_source(path)
			if not registered.ok: status.text = "Não foi possível registrar a fonte (%s)."%registered.code; dialog.queue_free(); return
		refresh(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free); dialog.popup_centered_ratio(0.75)

func activate_selected(copy_requested: bool) -> Dictionary:
	if _selected.is_empty(): return {"ok":false,"code":"library_entry_missing"}
	var result: Dictionary
	if _selected.kind == "source":
		result = source_action.call(_selected.path,_selected.source_kind,copy_requested) if source_action.is_valid() else {"ok":false,"code":"library_consumer_missing"}
	else:
		result = asset_action.call(_selected.duplicate(true)) if not copy_requested and asset_action.is_valid() else {"ok":false,"code":"library_source_required"}
	if result.ok: _diagnostic_code = ""; status.text = "Seleção encaminhada ao editor."
	else: _diagnostic(result.code)
	return result

func toggle_favorite() -> void:
	if _selected.is_empty(): return
	var prefs := Preferences.read()
	if not prefs.ok: return
	var changed := Preferences.transact({"operation":"favorite","id":_selected.id,"enabled":_selected.id not in prefs.data.favorites})
	if changed.ok: filter_items()
	else: status.text = "Os favoritos foram preservados (%s)."%changed.code

func forget_source() -> void:
	if _selected.get("kind") != "source": status.text = "Escolha uma fonte salva. Catálogos do projeto são imutáveis."; return
	var removed := Preferences.transact({"operation":"source_remove","id":_selected.id})
	if removed.ok: _selected = {}; preview.texture = null; details.text = "Registro removido. O arquivo da fonte foi preservado."; refresh()
	else: status.text = "O registro foi preservado (%s)."%removed.code

func cancel_preview() -> void:
	_generation += 1
	_cancelled = true; _pending = ""; _queue.clear()
	if _job != null: _job.cancel()
	if is_instance_valid(status): status.text = "Miniaturas canceladas; fontes e registros preservados."

func _process(_delta: float) -> void:
	if _rendering: return
	if _job != null:
		progress.value = _job.progress()*80
		if not _job.ready(): return
		var current := Model.describe_source(_active.path,_active.source_kind)
		var result: Dictionary = _job.take(current.entry.source_hash if current.ok else ""); _job = null
		if result.ok and not _cancelled and _active.get("generation") == _generation:
			_render_result(result.package); return
		if _selected.get("id") == _active.id: _diagnostic(result.get("code","library_preview_failed"))
	if _cancelled: return
	var id := _pending
	if not id.is_empty(): _pending = ""
	elif not _queue.is_empty(): id = _queue.pop_front()
	if id.is_empty(): return
	_queue.erase(id); var entry := _entry(id)
	if entry.is_empty() or entry.kind != "source": return
	var described := Model.describe_source(entry.path,entry.source_kind)
	if not described.ok:
		if _selected.get("id") == id: _diagnostic(described.code)
		return
	_active = entry.duplicate(true); _active["source_data"] = described.data; _active.source_hash = described.entry.source_hash
	_active["environment_hash"] = _environment
	_active["generation"] = _generation
	_job = TerrainCompiler.new() if entry.source_kind == "piece" else MapCompiler.new(); _job.start(described.data)
	_diagnostic_code = ""; status.text = "Preparando miniatura: "+described.entry.name

func _render_result(package: Dictionary) -> void:
	_rendering = true; progress.value = 80; var active := _active.duplicate(true)
	if active.source_kind == "piece":
		_map_canvas.hide(); _piece_canvas.show()
		var layer: String = active.source_data.layers[0].layer_id if not active.source_data.layers.is_empty() else ""
		_piece_canvas.set_source(active.source_data,layer); _piece_canvas.package = package; _piece_canvas.fit(); _piece_canvas._overlay.hide()
	else:
		_piece_canvas.hide(); _map_canvas.show(); _map_canvas.set_package(package); _map_canvas._overlay.hide()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await get_tree().process_frame; await get_tree().process_frame
	RenderingServer.force_draw(false)
	await get_tree().process_frame; await get_tree().process_frame
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var current := Model.describe_source(active.path,active.source_kind); var environment := Model.thumbnail_environment()
	if _cancelled or active.generation != _generation or not current.ok or current.entry.source_hash != active.source_hash or not environment.ok or environment.hash != active.environment_hash:
		status.text = "Miniatura descartada: fonte, dependência ou pedido mudou."; _rendering = false; return
	var image := _viewport.get_texture().get_image()
	progress.value = 90
	var saved := Model.save_thumbnail(active.source_hash,active.environment_hash,package.package_hash,image)
	if saved.ok:
		_images[active.id] = ImageTexture.create_from_image(saved.image); filter_items()
		if _selected.get("id") == active.id:
			preview.texture = ImageTexture.create_from_image(image); _diagnostic_code = ""; status.text = "Prévia pronta. Arquivo e dependências conferidos."
	else: status.text = "Não foi possível guardar a miniatura (%s). Fontes preservadas."%saved.code
	progress.value = 100; _rendering = false

func _exit_tree() -> void:
	if _job != null: _job.close(); _job = null

func authoring_commands() -> Array:
	return [{"id":"library/query","parameters":{"query":"string?","category":"string?","favorites_only":"bool?"}},{"id":"library/select","parameters":{"entry_id":"string"}},{"id":"library/register","parameters":{"path":"string","kind":"piece|map?"}},{"id":"library/open","parameters":{"duplicate":"bool"}},{"id":"library/jobs/status","parameters":{}},{"id":"library/jobs/cancel","parameters":{}},{"id":"library/preferences/review_recovery","parameters":{}},{"id":"library/preferences/recover","parameters":{"expected_hash":"string"}}]

func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	match id:
		"library/preferences/review_recovery": return Preferences.recovery_preview() if parameters.is_empty() else {"ok":false,"code":"arguments_invalid"}
		"library/preferences/recover":
			if not Preferences._keys(parameters,["expected_hash"]) or not parameters.expected_hash is String: return {"ok":false,"code":"arguments_invalid"}
			var recovered := Preferences.recover(parameters.expected_hash)
			if recovered.ok: refresh()
			return recovered
		"library/query":
			for key: Variant in parameters:
				if key not in ["query","category","favorites_only"]: return {"ok":false,"code":"arguments_invalid"}
			if not parameters.get("query","") is String or not parameters.get("category","") is String or parameters.get("category","") not in [""]+Model.CATEGORIES.keys() or not parameters.get("favorites_only",false) is bool: return {"ok":false,"code":"arguments_invalid"}
			var prefs := Preferences.read()
			return {"ok":true,"entries":Model.query(_entries,parameters.get("query",""),parameters.get("category",""),parameters.get("favorites_only",false),prefs.data.favorites)} if prefs.ok else prefs
		"library/select":
			return select_entry(parameters.entry_id) if Preferences._keys(parameters,["entry_id"]) and parameters.entry_id is String else {"ok":false,"code":"arguments_invalid"}
		"library/register":
			for key: Variant in parameters:
				if key not in ["path","kind"]: return {"ok":false,"code":"arguments_invalid"}
			if not parameters.get("path") is String or not parameters.get("kind","") is String: return {"ok":false,"code":"arguments_invalid"}
			var registered := Model.register_source(parameters.path,parameters.get("kind",""))
			if registered.ok: refresh()
			return registered
		"library/open": return activate_selected(parameters["duplicate"]) if Preferences._keys(parameters,["duplicate"]) and parameters["duplicate"] is bool else {"ok":false,"code":"arguments_invalid"}
		"library/jobs/status":
			if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
			return {"ok":true,"busy":_job != null or _rendering,"progress":progress.value,"pending":_pending,"queued":_queue.size(),"cancelled":_cancelled,"diagnostic_code":_diagnostic_code}
		"library/jobs/cancel":
			if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
			cancel_preview(); return {"ok":true}
	return {"ok":false,"code":"action_missing"}
