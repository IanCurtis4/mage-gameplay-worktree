class_name CharacterMenu
extends Control
## E02.1 roster screen. It only asks ProfileFacade to mutate the normal profile.

const DEFAULT_PROFILE_DIRECTORY := "user://"
const MAX_CHARACTERS := 8
const ProfileFacadeScript := preload("res://scripts/core/profile_facade.gd")
const ProfileStoreScript := preload("res://scripts/core/profile_store.gd")
const ProfileCatalogScript := preload("res://scripts/core/profile_catalog.gd")

var profile_directory := DEFAULT_PROFILE_DIRECTORY
var facade: RefCounted
var _request_serial := 0
var _selected_index := -1
var _read_only := false

var status_label: Label
var roster_list: ItemList
var name_input: LineEdit
var create_button: Button
var create_buttons: Array[Button] = []
var select_button: Button
var empty_label: Label
var build_summary_label: Label

func set_profile_directory(directory: String) -> void:
	profile_directory = directory

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_open_profile()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or roster_list == null or roster_list.item_count == 0:
		return
	if event.is_action_pressed(&"ui_up"):
		_select_roster_index(maxi(0, _selected_index - 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_down"):
		_select_roster_index(mini(roster_list.item_count - 1, _selected_index + 1))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_accept") and _selected_index >= 0:
		_select_current_character()
		get_viewport().set_input_as_handled()

func create_character(base_class_id: StringName) -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null:
		return _show_result({"ok": false, "error_code": &"profile_unavailable"})
	var display_name := name_input.text.strip_edges()
	if display_name.is_empty():
		display_name = "Novo %s" % _class_name(base_class_id)
	var result: Dictionary = facade.create_character(_request_id("create"), profile.revision, display_name, base_class_id)
	if result.get("ok", false):
		name_input.clear()
	return _show_result(result)

func select_character_at(index: int) -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or index < 0 or index >= profile.characters.size():
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var character: Variant = profile.characters[index]
	return _show_result(facade.select_character(_request_id("select"), profile.revision, character.character_id))

func _open_profile() -> void:
	facade = ProfileFacadeScript.new(ProfileStoreScript.new(profile_directory, ProfileCatalogScript.pilot()))
	_show_result(facade.open_profile())

func _select_current_character() -> void:
	select_character_at(_selected_index)

func _select_roster_index(index: int) -> void:
	if index < 0 or index >= roster_list.item_count:
		return
	_selected_index = index
	roster_list.select(index)
	select_button.disabled = false

func _show_result(result: Dictionary) -> Dictionary:
	var ok: bool = result.get("ok", false)
	if ok:
		_read_only = false
	elif result.has("read_only"):
		_read_only = result["read_only"]
	if ok:
		status_label.text = "Perfil atualizado." if not result.get("already_applied", false) else "Este personagem já está selecionado."
	else:
		status_label.text = _error_text(StringName(result.get("error_code", &"unknown")), result.get("read_only", false))
	_refresh()
	return result

func _refresh() -> void:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null:
		roster_list.clear()
		empty_label.visible = true
		empty_label.text = "Não foi possível carregar os personagens."
		for button: Button in create_buttons:
			button.disabled = true
		select_button.disabled = true
		build_summary_label.text = "Build indisponível enquanto o perfil não puder ser lido."
		return
	roster_list.clear()
	_selected_index = -1
	for character: Variant in profile.characters:
		var selected := "  • selecionado" if character.character_id == profile.selected_character_id else ""
		roster_list.add_item("%s — %s%s" % [character.display_name, _class_name(character.base_class_id), selected])
		if character.character_id == profile.selected_character_id:
			_selected_index = roster_list.item_count - 1
	if _selected_index >= 0:
		roster_list.select(_selected_index)
		build_summary_label.text = _build_summary(profile.characters[_selected_index])
	else:
		build_summary_label.text = "Selecione ou crie um personagem para ver a build inicial."
	empty_label.visible = roster_list.item_count == 0
	empty_label.text = "Nenhum personagem criado. Crie seu primeiro alt para começar."
	var locked := _read_only
	for button: Button in create_buttons:
		button.disabled = locked or profile.characters.size() >= MAX_CHARACTERS
	select_button.disabled = locked or _selected_index < 0
	if profile.characters.size() >= MAX_CHARACTERS:
		status_label.text = "Limite de %d personagens atingido." % MAX_CHARACTERS

func _error_text(error_code: StringName, read_only: bool) -> String:
	if read_only:
		return "Perfil em modo somente leitura (%s). Nenhuma alteração foi feita." % error_code
	match error_code:
		&"save_in_progress": return "O perfil ainda está sendo salvo. Tente novamente em instantes."
		&"stale_revision": return "O perfil mudou; a lista foi atualizada. Escolha novamente."
		&"character_limit": return "Você atingiu o limite de personagens."
		&"run_active": return "Há uma run ativa. Volte ao menu após encerrá-la."
		&"invalid_origin": return "Essa classe ainda não está disponível."
		_: return "Não foi possível atualizar o perfil (%s)." % error_code

func _class_name(base_class_id: StringName) -> String:
	match base_class_id:
		&"swordsman": return "Espadachim"
		&"mage": return "Mago"
		_: return "Classe indisponível"

func _build_summary(character: Variant) -> String:
	var preset: Dictionary = character.presets[character.selected_preset]
	var active: Array[String] = []
	for skill_id: Variant in preset["active_slots"]:
		if skill_id != null:
			active.append(_skill_name(skill_id))
	var passive: Array[String] = []
	for skill_id: Variant in preset["passive_slots"]:
		if skill_id != null:
			passive.append(_skill_name(skill_id))
	var weapon: Variant = preset["equipped"].get(&"weapon")
	return "Build inicial (somente leitura)\nAtivas: %s\nPassiva: %s\nArma: %s\nAtributos e edição de presets serão liberados com o contrato de build." % [", ".join(active), ", ".join(passive), _equipment_name(weapon)]

func _skill_name(skill_id: Variant) -> String:
	match StringName(skill_id):
		&"slash": return "Corte"
		&"dash": return "Investida"
		&"swordsman_resistance": return "Resistência"
		&"fireball": return "Bola de fogo"
		&"fire_wall": return "Parede de fogo"
		&"mage_mana_regeneration": return "Regeneração de mana"
		_: return "Skill indisponível"

func _equipment_name(item_id: Variant) -> String:
	var normalized_id: StringName = StringName(item_id) if item_id != null else &""
	match normalized_id:
		&"training_sword": return "Espada de treino"
		&"apprentice_staff": return "Cajado de aprendiz"
		_: return "Nenhuma"

func _request_id(action: String) -> String:
	_request_serial += 1
	return "character-menu-%s-%d" % [action, _request_serial]

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -410
	panel.offset_top = -300
	panel.offset_right = 410
	panel.offset_bottom = 300
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)
	var title := Label.new()
	title.text = "RagRPG — Personagens"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	panel.add_child(title)
	status_label = Label.new()
	status_label.name = "ProfileStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	panel.add_child(content)
	var roster_column := VBoxContainer.new()
	roster_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(roster_column)
	var roster_title := Label.new()
	roster_title.text = "Seus personagens"
	roster_title.add_theme_font_size_override("font_size", 22)
	roster_column.add_child(roster_title)
	roster_list = ItemList.new()
	roster_list.name = "CharacterRoster"
	roster_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_list.item_selected.connect(_select_roster_index)
	roster_list.item_activated.connect(select_character_at)
	roster_column.add_child(roster_list)
	empty_label = Label.new()
	empty_label.name = "EmptyState"
	empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_column.add_child(empty_label)
	select_button = Button.new()
	select_button.text = "Selecionar personagem"
	select_button.custom_minimum_size = Vector2(0, 44)
	select_button.pressed.connect(_select_current_character)
	roster_column.add_child(select_button)
	build_summary_label = Label.new()
	build_summary_label.name = "BuildSummary"
	build_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_column.add_child(build_summary_label)
	var create_column := VBoxContainer.new()
	create_column.custom_minimum_size = Vector2(310, 0)
	create_column.add_theme_constant_override("separation", 10)
	content.add_child(create_column)
	var create_title := Label.new()
	create_title.text = "Criar personagem"
	create_title.add_theme_font_size_override("font_size", 22)
	create_column.add_child(create_title)
	var description := Label.new()
	description.text = "Escolha uma classe disponível. A build será configurada no próximo passo do menu."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_column.add_child(description)
	name_input = LineEdit.new()
	name_input.name = "CharacterName"
	name_input.placeholder_text = "Nome do personagem (opcional)"
	name_input.max_length = 48
	create_column.add_child(name_input)
	for class_id: StringName in [&"swordsman", &"mage"]:
		var button := Button.new()
		button.text = "Criar %s" % _class_name(class_id)
		button.custom_minimum_size = Vector2(0, 44)
		button.pressed.connect(create_character.bind(class_id))
		create_column.add_child(button)
		create_buttons.append(button)
		if class_id == &"swordsman":
			create_button = button
	var notice := Label.new()
	notice.text = "A arena será liberada após a configuração de build."
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	create_column.add_child(notice)
