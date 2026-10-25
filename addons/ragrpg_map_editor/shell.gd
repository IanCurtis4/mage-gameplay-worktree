@tool
extends VBoxContainer
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Document = preload("res://scripts/map_authoring/document/source_document.gd")
const Store = preload("res://scripts/map_authoring/io/source_store.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Terrain = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Composition = preload("res://scripts/map_authoring/composition/map_panel.gd")
var composition_window: Window
var terrain: Control
var session := Session.new()
var source_path := ""
var expected_hash := ""
var recovery_root := ""
var title_edit: LineEdit
var path_edit: LineEdit
var layers: ItemList
var info: Label
var problems: ItemList
var undo_button: Button
var redo_button: Button
var recovery_kind: OptionButton
var _dialog: ConfirmationDialog
var _pending_action: Callable

var exchange_panel: Control
func _ready() -> void:
	exchange_panel = preload("res://scripts/map_authoring/exchange/exchange_panel.gd").mount(self,"piece",func() -> Dictionary: return session.document().to_data().duplicate(true),session.apply)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	recovery_root = ProjectSettings.globalize_path("res://.godot/map_authoring")
	DirAccess.make_dir_recursive_absolute(recovery_root)
	var heading := Label.new()
	heading.text = "Editor de mapas · Terreno e camadas"
	heading.add_theme_font_size_override("font_size", 24)
	add_child(heading)
	var toolbar := HBoxContainer.new()
	add_child(toolbar)
	_button(toolbar, "Nova peça", request_new)
	_button(toolbar, "Compor mapa…", open_composition)
	_button(toolbar, "Abrir…", _choose_open)
	_button(toolbar, "Salvar", save_current)
	_button(toolbar, "Salvar como…", _choose_save)
	undo_button = _button(toolbar, "Desfazer", func() -> void: session.undo())
	redo_button = _button(toolbar, "Refazer", func() -> void: session.redo())
	var path_row := HBoxContainer.new()
	add_child(path_row)
	path_edit = LineEdit.new()
	path_edit.placeholder_text = "Caminho do arquivo de fonte (.json)"
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_row.add_child(path_edit)
	recovery_kind = OptionButton.new()
	for kind: String in ["Rascunho automático", "Gravação interrompida", "Último backup", "Rascunho interrompido", "Backup interrompido"]: recovery_kind.add_item(kind)
	path_row.add_child(recovery_kind)
	_button(path_row, "Recuperar cópia", recover_current)
	_button(path_row, "Buscar rascunho…", _choose_recovery)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 280
	split.add_child(left)
	var label := Label.new()
	label.text = "Camadas"
	left.add_child(label)
	layers = ItemList.new()
	layers.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(layers)
	layers.item_selected.connect(func(index: int) -> void:
		terrain.select_layer(session.document().to_data().layers[index].layer_id))
	var layer_actions := HBoxContainer.new()
	left.add_child(layer_actions)
	_button(layer_actions, "Adicionar", add_layer)
	_button(layer_actions, "Duplicar", duplicate_layer)
	_button(layer_actions, "Travar", toggle_layer_lock)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	scroll.add_child(right)
	var name_label := Label.new()
	name_label.text = "Nome da peça"
	right.add_child(name_label)
	title_edit = LineEdit.new()
	title_edit.max_length = 65536
	title_edit.placeholder_text = "Nome visível"
	right.add_child(title_edit)
	title_edit.text_submitted.connect(rename_document)
	title_edit.focus_exited.connect(_commit_name)
	_button(right, "Aplicar nome", func() -> void: rename_document(title_edit.text))
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(info)
	terrain = Terrain.new()
	right.add_child(terrain)
	terrain.layer_selected.connect(func(id: String) -> void:
		for i: int in session.document().to_data().layers.size():
			if session.document().to_data().layers[i].layer_id == id: layers.select(i))
	terrain.bind(session)
	var problem_title := Label.new()
	problem_title.text = "Diagnósticos"
	right.add_child(problem_title)
	problems = ItemList.new()
	problems.custom_minimum_size.y = 65
	problems.item_selected.connect(_select_problem)
	right.add_child(problems)
	_dialog = ConfirmationDialog.new()
	_dialog.dialog_text = "O documento tem alterações. O rascunho será preservado antes de continuar."
	add_child(_dialog)
	_dialog.confirmed.connect(func() -> void:
		if preserve_draft(): _pending_action.call())
	session.changed.connect(_refresh)
	var timer := Timer.new()
	timer.wait_time = 10
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		if session.dirty(): preserve_draft())
	add_child(timer)
	_new_document()
	preload("res://scripts/map_authoring/context/context_panel.gd").mount(self,session,terrain)
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"piece",func() -> Dictionary: return session.document().to_data(),terrain.canvas)

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func focus_primary() -> void:
	if is_instance_valid(title_edit): title_edit.grab_focus()

func open_composition() -> void:
	if composition_window == null:
		composition_window = Window.new(); composition_window.title = "RagRPG · Composição de mapas"; composition_window.size = Vector2i(1360,850)
		var panel := Composition.new(); composition_window.add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		composition_window.close_requested.connect(func() -> void:
			panel.preserve_draft(); panel.canvas.stop_test(); composition_window.hide())
		add_child(composition_window)
	composition_window.popup_centered()

func _id(prefix: String) -> String:
	return prefix + "_" + Crypto.new().generate_random_bytes(12).hex_encode()

func _confirm(action: Callable) -> void:
	_commit_name()
	if session.dirty():
		_pending_action = action
		_dialog.popup_centered()
	else: action.call()

func request_new() -> void: _confirm(_new_document)

func _new_document() -> void:
	source_path = ""
	expected_hash = ""
	path_edit.text = ""
	session.saved_hash = ""
	session.replace(Document.empty(_id("piece")))

func rename_document(value: String) -> void:
	var data: Dictionary = session.document().to_data()
	if data.name == value: return
	data.name = value
	_show(session.apply(data))

func _commit_name() -> void:
	if session.document() != null: rename_document(title_edit.text)

func add_layer() -> void:
	var data: Dictionary = session.document().to_data()
	var heights: Array = []; heights.resize(81); heights.fill(0.0)
	data.layers.append({"layer_id": _id("layer"), "name": "Camada %d" % (data.layers.size() + 1), "origin_xz": [0, 0], "sample_spacing": 32, "columns": 9, "rows": 9, "heights": heights, "material_masks": {}, "locked": false, "protected_regions": []})
	_show(session.apply(data))
	terrain.select_layer(data.layers[-1].layer_id)
	terrain.canvas.fit()

func duplicate_layer() -> void:
	var selected := layers.get_selected_items()
	if selected.is_empty(): return
	var data: Dictionary = session.document().to_data()
	_show(session.duplicate_layer(data.layers[selected[0]].layer_id))

func toggle_layer_lock() -> void:
	var selected := layers.get_selected_items()
	if selected.is_empty(): return
	var data: Dictionary = session.document().to_data()
	data.layers[selected[0]].locked = not data.layers[selected[0]].locked
	_show(session.apply(data))

func _refresh() -> void:
	if session.document() == null: return
	var data: Dictionary = session.document().to_data()
	title_edit.text = data.name
	layers.clear()
	for layer: Dictionary in data.layers:
		layers.add_item(("[Travada] " if layer.locked else "") + layer.name)
		if terrain != null and layer.layer_id == terrain.selected_layer: layers.select(layers.item_count-1)
	undo_button.disabled = not session.can_undo()
	redo_button.disabled = not session.can_redo()
	info.text = "Revisão %d · %s · rascunho automático a cada 10 s" % [data.revision, "alterado" if session.dirty() else "salvo"]
	info.tooltip_text = data.document_id + "\nRascunho: " + _draft_path() + ".autosave"
	problems.clear()
	for diagnostic: Dictionary in session.document().diagnostics():
		problems.add_item(diagnostic.message)
		problems.set_item_metadata(problems.item_count - 1, diagnostic)
	if problems.item_count == 0: problems.add_item("Sem problemas de documento. Compile a peça para conferir o terreno.")

func _select_problem(index: int) -> void:
	var diagnostic: Variant = problems.get_item_metadata(index)
	if not diagnostic is Dictionary: return
	var data: Dictionary = session.document().to_data()
	for i: int in data.layers.size():
		if data.layers[i].layer_id == diagnostic.entity_id: layers.select(i)

func _draft_path() -> String:
	return source_path if not source_path.is_empty() else recovery_root.path_join(session.document().to_data().document_id + ".json")

func preserve_draft() -> bool:
	_commit_name()
	if session.document() == null or not session.dirty(): return true
	var result := Store.autosave(_draft_path(), session.document().to_data(), expected_hash)
	if not result.ok: _show(result)
	return result.ok

func open_path(path: String) -> Dictionary:
	var result := Store.load_source(path)
	if result.ok:
		source_path = path
		expected_hash = result.byte_hash
		session.saved_hash = result.output_hash
		path_edit.text = path
		session.replace(result.data)
	_show(result)
	return result

func save_path(path: String) -> Dictionary:
	_commit_name()
	var expected := expected_hash if path == source_path else ""
	var result := Store.save_source(path, session.document().to_data(), expected)
	if result.ok:
		source_path = path
		expected_hash = result.byte_hash
		session.saved_hash = result.output_hash
		path_edit.text = path
		_refresh()
	_show(result)
	return result

func save_current() -> void:
	if source_path.is_empty(): _choose_save()
	else: save_path(source_path)

func recover_current() -> void:
	var path := path_edit.text.strip_edges()
	if path.is_empty(): path = _draft_path()
	var kinds := ["autosave", "pending", "bak", "autosave.pending", "bak.pending"]
	var result := Store.recover(path, kinds[recovery_kind.selected])
	_recover_result(result)

func _recover_result(result: Dictionary) -> void:
	if not result.ok:
		_show(result)
		return
	_confirm(func() -> void:
		# Recovery opens a detached copy. Save As cannot overwrite the source.
		source_path = ""
		expected_hash = ""
		session.saved_hash = ""
		session.replace(result.data)
		info.text += "\nCópia recuperada; use Salvar como para um novo arquivo.")

func _choose_recovery() -> void:
	var dialog := _file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.filters = PackedStringArray(["*.autosave,*.pending,*.bak ; Rascunhos e backups"])
	dialog.current_dir = recovery_root
	dialog.show_hidden_files = true
	dialog.file_selected.connect(func(path: String) -> void:
		for kind: String in ["autosave.pending", "bak.pending", "autosave", "pending", "bak"]:
			if path.ends_with("." + kind):
				_recover_result(Store.recover(path.trim_suffix("." + kind), kind))
				return)
	dialog.popup_centered_ratio(0.7)

func _choose_open() -> void:
	var dialog := _file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	dialog.file_selected.connect(func(path: String) -> void: _confirm(func() -> void: open_path(path)))
	dialog.popup_centered_ratio(0.7)

func _choose_save() -> void:
	var dialog := _file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	dialog.current_file = "peca.json"
	dialog.file_selected.connect(func(path: String) -> void: save_path(path))
	dialog.popup_centered_ratio(0.7)

func _file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode
	dialog.filters = PackedStringArray(["*.json ; Fonte de mapa"])
	add_child(dialog)
	dialog.canceled.connect(dialog.queue_free)
	dialog.file_selected.connect(func(_path: String) -> void: dialog.queue_free())
	return dialog

func _show(result: Dictionary) -> void:
	if not result.ok:
		var messages := {"io_conflict": "O arquivo mudou fora do editor. Reabra-o ou salve uma cópia em outro caminho.", "io_recovery_pending": "Há uma gravação interrompida. Recupere uma cópia antes de continuar.", "io_writer_locked": "Outro processo está gravando, ou deixou uma trava. Salve uma cópia em outro caminho.", "io_failure": "Não foi possível gravar ou ler nesse local.", "io_missing": "O arquivo não foi encontrado.", "source_parse_error": "O arquivo está incompleto ou não contém JSON válido.", "source_version_unsupported": "Esta versão de documento ainda não é suportada.", "source_limit_exceeded": "O arquivo excede os limites de leitura.", "source_invalid_type": "O arquivo tem campos com tipos inválidos.", "source_unknown_field": "O arquivo contém campos não reconhecidos."}
		info.text = messages.get(result.code, "Não foi possível concluir a operação (%s)." % result.code) + " O documento atual foi preservado."

func _shortcut_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo or not event.is_command_or_control_pressed(): return
	match event.keycode:
		KEY_S:
			if event.shift_pressed: _choose_save()
			else: save_current()
		KEY_O: _choose_open()
		KEY_N: request_new()
		KEY_Z:
			# Text fields keep their local editing shortcuts.
			if get_viewport().gui_get_focus_owner() is LineEdit: return
			if event.shift_pressed: session.redo()
			else: session.undo()
		_: return
	get_viewport().set_input_as_handled()
