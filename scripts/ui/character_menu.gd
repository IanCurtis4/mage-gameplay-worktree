class_name CharacterMenu
extends Control
## E02.1 roster screen. It only asks ProfileFacade to mutate the normal profile.

const DEFAULT_PROFILE_DIRECTORY := "user://"
const MAX_CHARACTERS := 8
const ProfileFacadeScript := preload("res://scripts/core/profile_facade.gd")
const ProfileStoreScript := preload("res://scripts/core/profile_store.gd")
const ProfileCatalogScript := preload("res://scripts/core/profile_catalog.gd")
const ProfileRewardResolverScript := preload("res://scripts/core/profile_reward_resolver.gd")
static var pending_focus_character_id := ""

var profile_directory := DEFAULT_PROFILE_DIRECTORY
var facade: RefCounted
var _request_serial := 0
var _selected_index := -1
var _focused_character_id := ""
var _read_only := false
var _progression_retries: Dictionary[String, Dictionary] = {}
var _evolution_pending: Dictionary = {}
var _evolution_retries: Dictionary[String, Dictionary] = {}

var status_label: Label
var roster_list: ItemList
var name_input: LineEdit
var create_button: Button
var create_buttons: Array[Button] = []
var select_button: Button
var empty_label: Label
var build_summary_label: Label
var progression_panel: VBoxContainer
var progression_state_label: Label
var progression_wallets_label: Label
var playtest_toggle: CheckButton
var playtest_panel: VBoxContainer
var playtest_buttons: Array[Button] = []
var progression_attributes_label: Label
var progression_attribute_actions: VBoxContainer
var attribute_increment_buttons: Dictionary[StringName, Button] = {}
var respec_attributes_button: Button
var progression_skill_tree: VBoxContainer
var respec_skills_button: Button
var evolution_panel: VBoxContainer
var evolution_state_label: Label
var evolution_options_list: VBoxContainer
var evolution_confirmation_label: Label
var confirm_evolution_button: Button
var cancel_evolution_button: Button
var preset_selector: OptionButton
var active_slot_a: OptionButton
var active_slot_b: OptionButton
var passive_slot: OptionButton
var active_selectors: Array[OptionButton] = []
var passive_selectors: Array[OptionButton] = []
var weapon_selector: OptionButton
var armor_selector: OptionButton
var accessory_selector: OptionButton
var save_build_button: Button
var start_run_button: Button
var menu_scroll: ScrollContainer
var menu_panel: VBoxContainer

func set_profile_directory(directory: String) -> void:
	profile_directory = directory

func set_profile_facade(value: RefCounted) -> void:
	facade = value

func _ready() -> void:
	_focused_character_id = pending_focus_character_id
	pending_focus_character_id = ""
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_layout_panel()
	get_viewport().size_changed.connect(_layout_panel)
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
	return _show_result(result, "Personagem criado.")

func select_character_at(index: int) -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or index < 0 or index >= profile.characters.size():
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var character: Variant = profile.characters[index]
	return _show_result(facade.select_character(_request_id("select"), profile.revision, character.character_id), "Personagem selecionado.")

func _open_profile() -> void:
	if facade == null:
		facade = ProfileFacadeScript.new(
			ProfileStoreScript.new(profile_directory, ProfileCatalogScript.pilot()),
			ProfileRewardResolverScript.pilot_progression()
		)
	_show_result(facade.open_profile(), "Perfil carregado.")

func _select_current_character() -> void:
	select_character_at(_selected_index)

func _select_roster_index(index: int) -> void:
	if index < 0 or index >= roster_list.item_count:
		return
	_selected_index = index
	roster_list.select(index)
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile != null:
		if _focused_character_id != profile.characters[index].character_id:
			_discard_evolution_intent()
		_focused_character_id = profile.characters[index].character_id
		preset_selector.select(profile.characters[index].selected_preset)
		_populate_build_editor(profile.characters[index])
		build_summary_label.text = _build_summary(profile.characters[index])
		_refresh_progression_panel(profile.characters[index], profile)
		_refresh_start_run_action(profile)
	select_button.disabled = false
	preset_selector.disabled = _read_only
	save_build_button.disabled = _read_only

func _choose_preset(preset_index: int) -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or _selected_index < 0:
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var character: Variant = profile.characters[_selected_index]
	return _show_result(facade.select_preset(_request_id("preset"), profile.revision, character.character_id, preset_index), "Preset selecionado.")

func _save_build() -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or _selected_index < 0:
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var character: Variant = profile.characters[_selected_index]
	var preset: Dictionary = character.presets[character.selected_preset].duplicate(true)
	var active_slots: Array[Variant] = []
	for selector: OptionButton in active_selectors:
		active_slots.append(_selected_option(selector))
	var passive_slots: Array[Variant] = []
	for selector: OptionButton in passive_selectors:
		passive_slots.append(_selected_option(selector))
	var equipped: Dictionary[StringName, Variant] = preset["equipped"].duplicate(true)
	equipped[&"weapon"] = _selected_option(weapon_selector)
	equipped[&"armor"] = _selected_option(armor_selector)
	equipped[&"accessory"] = _selected_option(accessory_selector)
	return _show_result(facade.update_preset(_request_id("build"), profile.revision, character.character_id, character.selected_preset, active_slots, passive_slots, equipped), "Preset salvo.")

func _start_run() -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or _selected_index < 0 or _selected_index >= profile.characters.size():
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var focused_id: String = profile.characters[_selected_index].character_id
	if profile.selected_character_id != focused_id:
		var selected: Dictionary = facade.select_character(_request_id("select-for-run"), profile.revision, focused_id)
		if not selected.get("ok", false):
			return _show_result(selected)
		profile = facade.current_profile()
	var result: Dictionary = facade.start_run(_request_id("start"), profile.revision)
	if result.get("ok", false):
		RunController.pending_run_state = result["run_state"]
		RunController.pending_run_facade = facade
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	return _show_result(result, "Run iniciada.")

func _start_playtest_training() -> Dictionary:
	if playtest_toggle == null or not playtest_toggle.button_pressed:
		return {"ok": false, "error_code": &"playtest_panel_closed"}
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	var result: Dictionary = facade.prepare_playtest_training(context["character_id"])
	if result.get("ok", false):
		pending_focus_character_id = context["character_id"]
		RunController.pending_run_state = result["run_state"]
		RunController.pending_run_facade = null
		RunController.pending_training_mode = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	return _show_result(result, "Treino iniciado sem alterar o perfil.")

func _selected_option(selector: OptionButton) -> Variant:
	if selector.selected < 0:
		return null
	return selector.get_item_metadata(selector.selected)

func _populate_build_editor(character: Variant) -> void:
	var options: Dictionary = facade.available_build_options(character.character_id)
	if not options.get("ok", false):
		return
	var preset: Dictionary = character.presets[character.selected_preset]
	for index: int in active_selectors.size():
		_populate_selector(active_selectors[index], options["active_skills"], preset["active_slots"][index])
	for index: int in passive_selectors.size():
		_populate_selector(passive_selectors[index], options["passive_skills"], preset["passive_slots"][index])
	_populate_selector(weapon_selector, options["equipment_by_slot"][&"weapon"], preset["equipped"][&"weapon"])
	_populate_selector(armor_selector, options["equipment_by_slot"][&"armor"], preset["equipped"][&"armor"])
	_populate_selector(accessory_selector, options["equipment_by_slot"][&"accessory"], preset["equipped"][&"accessory"])

func _populate_selector(selector: OptionButton, values: Array, current: Variant) -> void:
	selector.clear()
	selector.add_item("Nenhum")
	selector.set_item_metadata(0, null)
	var current_index := 0
	var is_skill_selector := selector in active_selectors or selector in passive_selectors
	for value: Variant in values:
		var item_id: StringName = StringName(value)
		selector.add_item(_skill_name(item_id) if is_skill_selector else _equipment_name(item_id))
		var index := selector.item_count - 1
		selector.set_item_metadata(index, item_id)
		if value == current:
			current_index = index
	selector.select(current_index)

func _show_result(result: Dictionary, success_text: String = "Perfil atualizado.") -> Dictionary:
	var ok: bool = result.get("ok", false)
	if ok:
		_read_only = false
	elif result.has("read_only"):
		_read_only = result["read_only"]
	if ok:
		status_label.text = success_text if not result.get("already_applied", false) else "Essa escolha já está ativa."
		if result.has("character_id"):
			_focused_character_id = result["character_id"]
		elif result.has("selected_character_id"):
			_focused_character_id = result["selected_character_id"]
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
		_show_progression_message("Progressão indisponível enquanto o perfil não puder ser lido.")
		_show_evolution_message("Evolução indisponível enquanto o perfil não puder ser lido.")
		preset_selector.disabled = true
		save_build_button.disabled = true
		start_run_button.disabled = true
		start_run_button.text = "Iniciar run"
		_set_attribute_actions_disabled(true)
		_set_skill_actions_disabled(true)
		_refresh_playtest_controls(null)
		return
	roster_list.clear()
	_selected_index = -1
	var persisted_index := -1
	var focused_index := -1
	for character: Variant in profile.characters:
		var selected := "  • selecionado" if character.character_id == profile.selected_character_id else ""
		roster_list.add_item("%s — %s%s" % [character.display_name, _roster_identity_name(character), selected])
		if character.character_id == profile.selected_character_id:
			persisted_index = roster_list.item_count - 1
		if character.character_id == _focused_character_id:
			focused_index = roster_list.item_count - 1
	_selected_index = focused_index if focused_index >= 0 else persisted_index
	if _selected_index >= 0:
		_focused_character_id = profile.characters[_selected_index].character_id
		roster_list.select(_selected_index)
		_populate_build_editor(profile.characters[_selected_index])
		preset_selector.select(profile.characters[_selected_index].selected_preset)
		build_summary_label.text = _build_summary(profile.characters[_selected_index])
		_refresh_progression_panel(profile.characters[_selected_index], profile)
	else:
		build_summary_label.text = "Selecione ou crie um personagem para ver a build inicial."
		_show_progression_message("Crie ou selecione um personagem para consultar a progressão.")
		_show_evolution_message("Crie ou selecione um personagem para consultar a evolução.")
	empty_label.visible = roster_list.item_count == 0
	empty_label.text = "Nenhum personagem criado. Crie seu primeiro alt para começar."
	var locked := _read_only
	for button: Button in create_buttons:
		button.disabled = locked or profile.characters.size() >= MAX_CHARACTERS
	select_button.disabled = locked or _selected_index < 0
	preset_selector.disabled = locked or _selected_index < 0
	save_build_button.disabled = locked or _selected_index < 0
	_refresh_start_run_action(profile)
	_set_attribute_actions_disabled(locked or profile.reward_session != null)
	_set_skill_actions_disabled(locked or profile.reward_session != null)
	_refresh_playtest_controls(profile)
	if profile.characters.size() >= MAX_CHARACTERS:
		status_label.text = "Limite de %d personagens atingido." % MAX_CHARACTERS

func _refresh_start_run_action(profile: ProfileState) -> void:
	if start_run_button == null:
		return
	if profile == null or _selected_index < 0 or _selected_index >= profile.characters.size():
		start_run_button.text = "Iniciar run"
		start_run_button.disabled = true
		return
	var focused: CharacterState = profile.characters[_selected_index]
	start_run_button.text = "Iniciar run com %s" % focused.display_name
	start_run_button.tooltip_text = "Seleciona %s e inicia a arena com a build salva deste personagem." % focused.display_name
	start_run_button.disabled = _read_only or profile.reward_session != null

func _error_text(error_code: StringName, read_only: bool) -> String:
	if read_only:
		return "Perfil em modo somente leitura. %s" % _error_text(error_code, false)
	match error_code:
		&"save_in_progress": return "O perfil ainda está sendo salvo. Tente novamente em instantes."
		&"stale_revision": return "O perfil mudou; a lista foi atualizada. Escolha novamente."
		&"character_limit": return "Você atingiu o limite de personagens."
		&"run_active": return "Há uma run ativa. Volte ao menu após encerrá-la."
		&"evolution_locked": return "A evolução já foi fixada. Trocas só estão disponíveis no modo admin de testes."
		&"invalid_origin": return "Essa classe ainda não está disponível."
		&"invalid_character_id": return "O personagem selecionado não existe mais. Escolha outro personagem."
		&"invalid_presets": return "O preset contém skills inválidas ou repetidas. Revise os slots escolhidos."
		&"invalid_equipment": return "O equipamento escolhido não pertence a este personagem ou ao slot informado."
		&"invalid_loadout": return "A build selecionada não é válida para iniciar a run."
		&"content_unavailable": return "A evolução escolhida ainda não possui conteúdo pronto para iniciar uma run."
		&"invalid_attribute_allocations": return "A distribuição de atributos informada é inválida."
		&"attribute_cap_reached": return "Este atributo já atingiu o limite de investimento."
		&"insufficient_points": return "Você não tem pontos suficientes para essa escolha."
		&"invalid_skill_id": return "Esta skill não está disponível para o personagem."
		&"requirements_unmet": return "Os requisitos desta skill ainda não foram atendidos."
		&"rank_cap_reached": return "Esta skill já atingiu o rank máximo."
		&"recovery_required": return "Há uma gravação pendente que precisa ser recuperada antes de iniciar uma run."
		&"unsupported_schema": return "Este perfil foi criado por uma versão mais nova do jogo."
		&"invalid_catalog": return "O catálogo de personagem está incompatível com este perfil."
		&"save_failed": return "Não foi possível salvar o perfil. Nenhuma alteração foi confirmada."
		&"invalid_playtest_amount": return "Informe uma quantidade positiva de XP para o atalho de playtest."
		&"invalid_playtest_action": return "Atalho de playtest desconhecido."
		_: return "Não foi possível atualizar o perfil (%s)." % error_code

func _class_name(base_class_id: StringName) -> String:
	match base_class_id:
		&"swordsman": return "Espadachim"
		&"mage": return "Mago"
		&"archer": return "Arqueiro"
		_: return "Classe indisponível"

func _roster_identity_name(character: CharacterState) -> String:
	var origin := _class_name(character.base_class_id)
	if character.evolution_id.is_empty():
		return origin
	var options: Dictionary = facade.evolution_options(character.character_id)
	if options.get("ok", false):
		for option: Dictionary in options["options"]:
			if option["is_current"]:
				return "%s → %s" % [origin, option["display_name"]]
	return origin

func _build_summary(character: Variant) -> String:
	var preset: Dictionary = character.presets[character.selected_preset]
	var preview: Dictionary = facade.build_preview(character.character_id)
	var derived_stats: StatBreakdown = preview.get("stat_breakdown") if preview.get("ok", false) else null
	var active: Array[String] = []
	for skill_id: Variant in preset["active_slots"]:
		if skill_id != null:
			active.append(_skill_name(skill_id))
	var passive: Array[String] = []
	for skill_id: Variant in preset["passive_slots"]:
		if skill_id != null:
			passive.append(_skill_name(skill_id))
	var weapon: Variant = preset["equipped"].get(&"weapon")
	if derived_stats == null:
		return "Build indisponível (%s)." % preview.get("error_code", &"preview_failed")
	var active_text := "Nenhuma" if active.is_empty() else ", ".join(active)
	var passive_text := "Nenhuma" if passive.is_empty() else ", ".join(passive)
	return "Build inicial\nAtivas: %s\nPassiva: %s\nArma: %s\nStats: Vida %d · SP %d · ATQ corpo %d · ATQ precisão %d · ATQ mágico %d" % [active_text, passive_text, _equipment_name(weapon), int(derived_stats.value(&"max_hp")), int(derived_stats.value(&"max_sp")), int(derived_stats.value(&"melee_attack")), int(derived_stats.value(&"precision_attack")), int(derived_stats.value(&"magic_attack"))]

func _refresh_progression_panel(character: Variant, profile: Variant) -> void:
	if character == null or facade == null:
		_show_progression_message("Crie ou selecione um personagem para consultar a progressão.")
		_show_evolution_message("Crie ou selecione um personagem para consultar a evolução.")
		return
	var summary: Dictionary = facade.progression_summary(character.character_id)
	var options: Dictionary = facade.progression_skill_options(character.character_id)
	var preview: Dictionary = facade.build_preview(character.character_id)
	if not summary.get("ok", false) or not options.get("ok", false) or not preview.get("ok", false):
		_show_progression_message("Não foi possível consultar a progressão deste personagem.")
		_show_evolution_message("Não foi possível consultar a evolução deste personagem.")
		return
	var evolution_state := "Evolução disponível para este personagem." if summary["evolution_eligible"] else "Job bloqueado até evoluir." if summary["job_progress_blocked"] else "Evolução ainda não disponível."
	if profile.reward_session != null:
		evolution_state = "Run ativa: a progressão é somente leitura até o encerramento."
	progression_state_label.text = "XP base: %d · Nível base: %d\nXP job: %d · Nível de job: %d\n%s" % [character.base_xp_total, summary["base_level"], character.job_xp_total, summary["job_level"], evolution_state]
	progression_wallets_label.text = "Pontos livres\nAtributos: %d/%d livres\nSkills base: %d/%d livres\nSkills de evolução: %d/%d livres" % [summary["attribute_points_available"], summary["attribute_points_granted"], summary["base_skill_points_available"], summary["base_skill_points_granted"], summary["evolution_skill_points_available"], summary["evolution_skill_points_granted"]]
	var breakdown: StatBreakdown = preview["stat_breakdown"]
	var attribute_lines: Array[String] = ["Atributos"]
	for attribute_id: StringName in IdentityIds.attribute_ids():
		var detail := breakdown.primary_detail(attribute_id)
		attribute_lines.append("%s: base %d · investido %d · base + investido: teto %d · efetivo %d · limite efetivo %d" % [_attribute_name(attribute_id), int(detail["initial"]), int(detail["allocated"]), StatCalculator.INVESTED_ATTRIBUTE_MAX, int(detail["effective"]), int(detail["maximum"])])
	progression_attributes_label.text = "\n".join(attribute_lines)
	_clear_progression_skill_tree()
	for option: Dictionary in options["skills"]:
		var skill_label := Label.new()
		var skill_id: StringName = option["skill_id"]
		skill_label.name = "ProgressionSkill_%s" % skill_id
		skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		skill_label.text = "%s — Rank %d/%d%s" % [_skill_name(skill_id), option["rank"], option["maximum_rank"], " · ramo futuro" if not option["available"] else ""]
		skill_label.tooltip_text = _skill_progression_tooltip(option)
		progression_skill_tree.add_child(skill_label)
		var learn_button := Button.new()
		learn_button.name = "Learn_%s" % skill_id
		learn_button.text = "Comprar rank %d" % option["next_rank"] if option["next_rank"] != null else "Rank máximo"
		learn_button.tooltip_text = _skill_purchase_tooltip(option)
		learn_button.disabled = _read_only or profile.reward_session != null or not option["next_rank_available"]
		learn_button.pressed.connect(_learn_skill.bind(skill_id))
		progression_skill_tree.add_child(learn_button)
	_set_attribute_actions_disabled(_read_only or profile.reward_session != null)
	_set_skill_actions_disabled(_read_only or profile.reward_session != null)
	_refresh_evolution_panel(character, profile)

func _refresh_evolution_panel(character: Variant, profile: Variant) -> void:
	if evolution_panel == null:
		return
	_clear_evolution_options()
	if character == null or facade == null:
		_show_evolution_message("Crie ou selecione um personagem para consultar a evolução.")
		return
	if not _evolution_pending.is_empty() and _evolution_pending.get("character_id", "") != character.character_id:
		_discard_evolution_intent()
	var admin_mode := playtest_toggle != null and playtest_toggle.button_pressed
	var result: Dictionary = facade.playtest_evolution_options(character.character_id) if admin_mode else facade.evolution_options(character.character_id)
	if not result.get("ok", false):
		_show_evolution_message("Não foi possível consultar as evoluções deste personagem.")
		return
	var current_name := "Nenhuma"
	for option: Dictionary in result["options"]:
		if option["is_current"]:
			current_name = option["display_name"]
	evolution_state_label.text = "Origem: %s\nEvolução atual: %s\nNível base %d · Job %d%s" % [_class_name(result["base_class_id"]), current_name, result["base_level"], result["job_level"], "\nModo admin: trocas de evolução liberadas para testes." if admin_mode else "\nA evolução fica fixa após a primeira escolha."]
	for option: Dictionary in result["options"]:
		var option_label := Label.new()
		option_label.name = "EvolutionOption_%s" % option["evolution_id"]
		option_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option_label.text = "%s · ramo %s\nRequisitos: base %d / job %d\n%s" % [option["display_name"], option["branch_kind"], option["required_base_level"], option["required_job_level"], _evolution_option_state(option)]
		evolution_options_list.add_child(option_label)
		var choose_button := Button.new()
		choose_button.name = "ChooseEvolution_%s" % option["evolution_id"]
		choose_button.text = "%s %s" % ["Trocar para" if admin_mode and not result["current_evolution_id"].is_empty() else "Escolher", option["display_name"]]
		choose_button.disabled = not option["can_select"]
		choose_button.tooltip_text = _evolution_option_tooltip(option)
		choose_button.pressed.connect(_begin_evolution_change.bind(option["evolution_id"]))
		evolution_options_list.add_child(choose_button)
	if _evolution_pending.is_empty():
		evolution_confirmation_label.text = "Escolher uma evolução pede confirmação; depois ela fica fixa. Trocas exigem modo admin de testes."
		confirm_evolution_button.text = "Confirmar evolução"
		confirm_evolution_button.disabled = true
		cancel_evolution_button.disabled = true
	else:
		var pending_name: String = _evolution_pending.get("display_name", "Evolução")
		var current_display: String = _evolution_pending.get("current_name", "Nenhuma")
		evolution_confirmation_label.text = "Confirmar %s → %s? Compras exclusivas serão reembolsadas e slots dos dois presets que deixarem de ser legais serão esvaziados." % [current_display, pending_name]
		confirm_evolution_button.text = "Confirmar %s" % pending_name
		confirm_evolution_button.disabled = _read_only or profile.reward_session != null
		cancel_evolution_button.disabled = false

func _begin_evolution_change(evolution_id: StringName) -> Dictionary:
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	var admin_mode := playtest_toggle != null and playtest_toggle.button_pressed
	var options: Dictionary = facade.playtest_evolution_options(context["character_id"]) if admin_mode else facade.evolution_options(context["character_id"])
	if not options.get("ok", false):
		return _show_result(options)
	var option := _evolution_option(options["options"], evolution_id)
	if option.is_empty():
		return _show_result({"ok": false, "error_code": &"invalid_origin"})
	if not option["can_select"]:
		status_label.text = "Esta evolução não pode ser escolhida: %s" % _evolution_option_state(option)
		_refresh()
		return {"ok": false, "error_code": _evolution_blocking_error(option)}
	var current_name := "Nenhuma"
	for current_option: Dictionary in options["options"]:
		if current_option["is_current"]:
			current_name = current_option["display_name"]
	_discard_evolution_intent()
	_evolution_pending = {
		"character_id": context["character_id"],
		"evolution_id": evolution_id,
		"display_name": option["display_name"],
		"current_name": current_name,
		"admin_mode": admin_mode,
		"revision": context["revision"],
	}
	_refresh()
	status_label.text = "Escolha pendente: %s. Confirme a evolução para salvá-la." % option["display_name"]
	confirm_evolution_button.call_deferred("grab_focus")
	menu_scroll.call_deferred("ensure_control_visible", confirm_evolution_button)
	return {"ok": true, "pending_confirmation": true, "character_id": context["character_id"], "evolution_id": evolution_id}

func _confirm_evolution_change() -> Dictionary:
	if _evolution_pending.is_empty():
		return _show_result({"ok": false, "error_code": &"invalid_origin"})
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	if context["character_id"] != _evolution_pending["character_id"]:
		_discard_evolution_intent()
		return _show_result({"ok": false, "error_code": &"invalid_character_id"})
	var evolution_id: StringName = _evolution_pending["evolution_id"]
	if bool(_evolution_pending.get("admin_mode", false)) != (playtest_toggle != null and playtest_toggle.button_pressed):
		_discard_evolution_intent()
		return _show_result({"ok": false, "error_code": &"evolution_locked"})
	var retry_key := "evolution:%s:%s" % [context["character_id"], evolution_id]
	var retry: Dictionary = _evolution_retries.get(retry_key, {})
	var request_id: String = retry.get("request_id", _request_id("evolution-%s" % evolution_id))
	var revision: int = retry.get("revision", _evolution_pending["revision"])
	var result: Dictionary = facade.change_playtest_evolution(request_id, revision, context["character_id"], evolution_id) if bool(_evolution_pending["admin_mode"]) else facade.change_evolution(request_id, revision, context["character_id"], evolution_id)
	var error_code: StringName = result.get("error_code", &"")
	if result.get("ok", false):
		var success_text := _evolution_success_text(result, String(_evolution_pending["display_name"]))
		_discard_evolution_intent()
		return _show_result(result, success_text)
	if error_code == &"save_failed":
		_evolution_retries[retry_key] = {"request_id": request_id, "revision": revision}
	else:
		_discard_evolution_intent()
	return _show_result(result)

func _cancel_evolution_change() -> void:
	_discard_evolution_intent()
	_refresh()
	status_label.text = "Escolha de evolução cancelada."

func _discard_evolution_intent() -> void:
	if _evolution_pending.is_empty():
		return
	var character_id: String = _evolution_pending["character_id"]
	var evolution_id: StringName = _evolution_pending["evolution_id"]
	_evolution_retries.erase("evolution:%s:%s" % [character_id, evolution_id])
	_evolution_pending.clear()

func _clear_evolution_options() -> void:
	if evolution_options_list == null:
		return
	for child: Node in evolution_options_list.get_children():
		evolution_options_list.remove_child(child)
		child.queue_free()

func _show_evolution_message(message: String) -> void:
	if evolution_state_label == null:
		return
	_clear_evolution_options()
	evolution_state_label.text = message
	if evolution_confirmation_label != null:
		evolution_confirmation_label.text = ""
	if confirm_evolution_button != null:
		confirm_evolution_button.disabled = true
	if cancel_evolution_button != null:
		cancel_evolution_button.disabled = true

func _evolution_option(option_list: Array, evolution_id: StringName) -> Dictionary:
	for option: Dictionary in option_list:
		if option["evolution_id"] == evolution_id:
			return option
	return {}

func _evolution_option_state(option: Dictionary) -> String:
	var states: Array[String] = []
	if option["is_current"]:
		states.append("Atual")
	if option["requirements_met"]:
		states.append("requisitos atendidos")
	else:
		states.append("requisitos pendentes")
	states.append("conteúdo pronto" if option["content_ready"] else "conteúdo indisponível")
	var reasons: Array[String] = []
	for reason: StringName in option["blocking_reasons"]:
		reasons.append(_evolution_blocking_text(reason))
	if not reasons.is_empty():
		states.append("bloqueios: %s" % ", ".join(reasons))
	return " · ".join(states)

func _evolution_option_tooltip(option: Dictionary) -> String:
	if option["can_select"]:
		return "Abrir confirmação para esta evolução."
	return "Indisponível: %s" % _evolution_option_state(option)

func _evolution_blocking_text(reason: StringName) -> String:
	match reason:
		&"requirements_unmet": return "requisitos não atendidos"
		&"content_unavailable": return "conteúdo indisponível"
		&"run_active": return "run ativa"
		&"profile_read_only": return "perfil somente leitura"
		&"already_current": return "já ativa"
		&"evolution_locked": return "evolução fixa; trocas só no modo admin"
		_: return "indisponível"

func _evolution_blocking_error(option: Dictionary) -> StringName:
	for reason: StringName in option["blocking_reasons"]:
		match reason:
			&"run_active": return &"run_active"
			&"profile_read_only": return &"recovery_required"
			&"content_unavailable": return &"content_unavailable"
			&"requirements_unmet": return &"requirements_unmet"
			&"evolution_locked": return &"evolution_locked"
	return &"invalid_origin"

func _evolution_success_text(result: Dictionary, display_name: String) -> String:
	var cleared := 0
	for preset: Dictionary in result.get("cleared_slots_by_preset", []):
		cleared += preset["active_slot_indices"].size() + preset["passive_slot_indices"].size()
	return "%s confirmada. Reembolso de evolução: %d ponto(s). Slots esvaziados: %d." % [display_name, result.get("evolution_refund", 0), cleared]

func _allocate_attribute(attribute_id: StringName) -> Dictionary:
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	var retry_key := "allocate:%s:%s" % [context["character_id"], attribute_id]
	var retry: Dictionary = _progression_retries.get(retry_key, {})
	var request_id: String = retry.get("request_id", _request_id("attribute-%s" % attribute_id))
	var revision: int = retry.get("revision", context["revision"])
	var result: Dictionary = facade.allocate_attributes(request_id, revision, context["character_id"], {attribute_id: 1})
	if result.get("ok", false) or result.get("error_code", &"") != &"save_failed":
		_progression_retries.erase(retry_key)
	else:
		_progression_retries[retry_key] = {"request_id": request_id, "revision": revision}
	return _show_result(result, "%s aumentado." % _attribute_name(attribute_id))

func _respec_attributes() -> Dictionary:
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	var retry_key := "respec:%s" % context["character_id"]
	var retry: Dictionary = _progression_retries.get(retry_key, {})
	var request_id: String = retry.get("request_id", _request_id("respec-attributes"))
	var revision: int = retry.get("revision", context["revision"])
	var result: Dictionary = facade.respec_attributes(request_id, revision, context["character_id"])
	if result.get("ok", false) or result.get("error_code", &"") != &"save_failed":
		_progression_retries.erase(retry_key)
	else:
		_progression_retries[retry_key] = {"request_id": request_id, "revision": revision}
	return _show_result(result, "Atributos redistribuídos.")

func _learn_skill(skill_id: StringName) -> Dictionary:
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	var retry_key := "learn:%s:%s" % [context["character_id"], skill_id]
	var retry: Dictionary = _progression_retries.get(retry_key, {})
	var request_id: String = retry.get("request_id", _request_id("learn-%s" % skill_id))
	var revision: int = retry.get("revision", context["revision"])
	var result: Dictionary = facade.learn_skill(request_id, revision, context["character_id"], skill_id)
	if result.get("ok", false) or result.get("error_code", &"") != &"save_failed":
		_progression_retries.erase(retry_key)
	else:
		_progression_retries[retry_key] = {"request_id": request_id, "revision": revision}
	var success_text := "Skill aprendida: %s." % _skill_name(skill_id) if result.get("rank", 0) == 1 else "Skill aprimorada: %s." % _skill_name(skill_id)
	return _show_result(result, success_text)

func _respec_skills() -> Dictionary:
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	var retry_key := "respec-skills:%s" % context["character_id"]
	var retry: Dictionary = _progression_retries.get(retry_key, {})
	var request_id: String = retry.get("request_id", _request_id("respec-skills"))
	var revision: int = retry.get("revision", context["revision"])
	var result: Dictionary = facade.respec_skills(request_id, revision, context["character_id"])
	if result.get("ok", false) or result.get("error_code", &"") != &"save_failed":
		_progression_retries.erase(retry_key)
	else:
		_progression_retries[retry_key] = {"request_id": request_id, "revision": revision}
	return _show_result(result, "Skills redistribuídas.")

func _selected_progression_context() -> Dictionary:
	var profile: Variant = facade.current_profile() if facade != null else null
	if profile == null or _selected_index < 0 or _selected_index >= profile.characters.size():
		return {"ok": false, "error_code": &"invalid_character_id"}
	if profile.reward_session != null:
		return {"ok": false, "error_code": &"run_active"}
	return {"ok": true, "character_id": profile.characters[_selected_index].character_id, "revision": profile.revision}

func _apply_playtest_progression(action: StringName, amount: int = 0) -> Dictionary:
	if playtest_toggle == null or not playtest_toggle.button_pressed:
		return {"ok": false, "error_code": &"playtest_panel_closed"}
	var context := _selected_progression_context()
	if not context["ok"]:
		return _show_result(context)
	var result: Dictionary = facade.grant_playtest_progression(_request_id("playtest"), context["revision"], context["character_id"], action, amount)
	return _show_result(result, "XP de playtest salvo neste personagem.")

func _refresh_playtest_controls(profile: Variant) -> void:
	if playtest_toggle == null:
		return
	var disabled := profile == null or _read_only or _selected_index < 0 or profile.reward_session != null
	playtest_toggle.disabled = disabled
	playtest_panel.visible = playtest_toggle.button_pressed
	for button: Button in playtest_buttons:
		button.disabled = disabled or not playtest_toggle.button_pressed

func _set_attribute_actions_disabled(disabled: bool) -> void:
	for button: Button in attribute_increment_buttons.values():
		button.disabled = disabled
	if respec_attributes_button != null:
		respec_attributes_button.disabled = disabled

func _set_skill_actions_disabled(disabled: bool) -> void:
	if respec_skills_button != null:
		respec_skills_button.disabled = disabled

func _show_progression_message(message: String) -> void:
	if progression_state_label == null:
		return
	progression_state_label.text = message
	progression_wallets_label.text = ""
	progression_attributes_label.text = ""
	_clear_progression_skill_tree()
	_set_skill_actions_disabled(true)

func _clear_progression_skill_tree() -> void:
	if progression_skill_tree == null:
		return
	for child: Node in progression_skill_tree.get_children():
		progression_skill_tree.remove_child(child)
		child.queue_free()

func _skill_progression_tooltip(option: Dictionary) -> String:
	var metadata: Dictionary = option["metadata"]
	var category := "Ativa" if metadata["category"] == ProfileCatalog.ACTIVE else "Passiva"
	var wallet := "base" if metadata["wallet"] == ProfileCatalog.BASE_WALLET else "evolução"
	var lines: Array[String] = ["%s · carteira %s" % [category, wallet], "Rank atual: %d/%d" % [option["rank"], option["maximum_rank"]]]
	if option["next_rank"] != null:
		var requirement: Dictionary = option["next_rank_requirement"]
		lines.append("Próximo rank: %d · Job %d" % [option["next_rank"], requirement["job_level"]])
		var prerequisites: Array[String] = []
		for prerequisite_id: StringName in requirement["skill_ranks"]:
			prerequisites.append("%s R%d" % [_skill_name(prerequisite_id), requirement["skill_ranks"][prerequisite_id]])
		lines.append("Pré-requisitos: %s" % (", ".join(prerequisites) if not prerequisites.is_empty() else "nenhum"))
	else:
		lines.append("Rank máximo atingido.")
	lines.append("Aprender não equipa automaticamente. Escolha a habilidade nos slots da build.")
	return "\n".join(lines)

func _skill_purchase_tooltip(option: Dictionary) -> String:
	if option["next_rank"] == null:
		return "Esta skill já atingiu o rank máximo."
	if option["next_rank_available"]:
		return "Comprar o rank %d pela carteira indicada." % option["next_rank"]
	match StringName(option["next_rank_error_code"]):
		&"insufficient_points": return "Pontos insuficientes na carteira desta skill."
		&"requirements_unmet": return "Os requisitos do próximo rank ainda não foram atendidos."
		&"rank_cap_reached": return "Esta skill já atingiu o rank máximo."
		_: return "Este rank não está disponível agora."

func _attribute_name(attribute_id: StringName) -> String:
	match attribute_id:
		&"str": return "FOR"
		&"agi": return "AGI"
		&"vit": return "VIT"
		&"int": return "INT"
		&"dex": return "DES"
		&"luk": return "SOR"
		_: return "Atributo indisponível"

func _skill_name(skill_id: Variant) -> String:
	var definition := ClassCatalog.skill_definition(StringName(skill_id))
	return definition.display_name if definition != null else "Habilidade não implementada"

func _equipment_name(item_id: Variant) -> String:
	var normalized_id: StringName = StringName(item_id) if item_id != null else &""
	match normalized_id:
		&"training_sword": return "Espada de treino"
		&"apprentice_staff": return "Cajado de aprendiz"
		_: return "Nenhuma"

func _request_id(action: String) -> String:
	_request_serial += 1
	return "character-menu-%s-%d" % [action, _request_serial]

func _layout_panel() -> void:
	if menu_panel == null:
		return
	var half_height := clampf(get_viewport_rect().size.y * 0.5 - 20.0, 96.0, 300.0)
	menu_panel.offset_top = -half_height
	menu_panel.offset_bottom = half_height

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	menu_panel = VBoxContainer.new()
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.offset_left = -410
	menu_panel.offset_right = 410
	menu_panel.add_theme_constant_override("separation", 14)
	add_child(menu_panel)
	var title := Label.new()
	title.text = "RagRPG — Personagens"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	menu_panel.add_child(title)
	status_label = Label.new()
	status_label.name = "ProfileStatus"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_panel.add_child(status_label)
	menu_scroll = ScrollContainer.new()
	menu_scroll.name = "MenuScroll"
	menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.follow_focus = true
	menu_panel.add_child(menu_scroll)
	var content := HBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_theme_constant_override("separation", 18)
	menu_scroll.add_child(content)
	var roster_column := VBoxContainer.new()
	roster_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(roster_column)
	var roster_title := Label.new()
	roster_title.text = "Seus personagens"
	roster_title.add_theme_font_size_override("font_size", 22)
	roster_column.add_child(roster_title)
	roster_list = ItemList.new()
	roster_list.name = "CharacterRoster"
	roster_list.custom_minimum_size = Vector2(0, 96)
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
	preset_selector = OptionButton.new()
	preset_selector.name = "PresetSelector"
	preset_selector.add_item("Preset 1")
	preset_selector.add_item("Preset 2")
	preset_selector.item_selected.connect(_choose_preset)
	roster_column.add_child(preset_selector)
	build_summary_label = Label.new()
	build_summary_label.name = "BuildSummary"
	build_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_column.add_child(build_summary_label)
	progression_panel = VBoxContainer.new()
	progression_panel.name = "ProgressionPanel"
	progression_panel.add_theme_constant_override("separation", 6)
	roster_column.add_child(progression_panel)
	var progression_title := Label.new()
	progression_title.text = "Progressão"
	progression_title.add_theme_font_size_override("font_size", 18)
	progression_panel.add_child(progression_title)
	progression_state_label = Label.new()
	progression_state_label.name = "ProgressionState"
	progression_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_panel.add_child(progression_state_label)
	playtest_toggle = CheckButton.new()
	playtest_toggle.name = "PlaytestAdminToggle"
	playtest_toggle.text = "Modo admin de testes"
	playtest_toggle.tooltip_text = "Abre XP e troca de evolução no save, além do treino isolado sem recompensa."
	playtest_toggle.toggled.connect(func(_pressed: bool) -> void:
		_discard_evolution_intent()
		_refresh()
	)
	progression_panel.add_child(playtest_toggle)
	playtest_panel = VBoxContainer.new()
	playtest_panel.name = "PlaytestAdminPanel"
	playtest_panel.visible = false
	progression_panel.add_child(playtest_panel)
	var playtest_notice := Label.new()
	playtest_notice.text = "XP e troca de evolução alteram o save. Treino usa a build atual sem recompensa persistente."
	playtest_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	playtest_panel.add_child(playtest_notice)
	for shortcut: Dictionary in [
		{"name": "PlaytestBaseXP", "text": "+1.000 XP base", "action": &"base_xp", "amount": 1000},
		{"name": "PlaytestJobXP", "text": "+1.000 XP job", "action": &"job_xp", "amount": 1000},
		{"name": "PlaytestPrepareEvolution", "text": "Preparar evolução (mín. base 10 / job 20)", "action": &"prepare_evolution", "amount": 0},
		{"name": "PlaytestMaxLevels", "text": "Níveis máximos legais", "action": &"max_levels", "amount": 0},
	]:
		var button := Button.new()
		button.name = shortcut["name"]
		button.text = shortcut["text"]
		button.pressed.connect(_apply_playtest_progression.bind(shortcut["action"], shortcut["amount"]))
		playtest_panel.add_child(button)
		playtest_buttons.append(button)
	var training_button := Button.new()
	training_button.name = "PlaytestTrainingBoss"
	training_button.text = "Treinar contra boss e reforços (sem salvar XP)"
	training_button.pressed.connect(_start_playtest_training)
	playtest_panel.add_child(training_button)
	playtest_buttons.append(training_button)
	progression_wallets_label = Label.new()
	progression_wallets_label.name = "ProgressionWallets"
	progression_wallets_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_panel.add_child(progression_wallets_label)
	progression_attributes_label = Label.new()
	progression_attributes_label.name = "ProgressionAttributes"
	progression_attributes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progression_panel.add_child(progression_attributes_label)
	progression_attribute_actions = VBoxContainer.new()
	progression_attribute_actions.name = "ProgressionAttributeActions"
	progression_attribute_actions.add_theme_constant_override("separation", 2)
	progression_panel.add_child(progression_attribute_actions)
	for attribute_id: StringName in IdentityIds.attribute_ids():
		var increment_button := Button.new()
		increment_button.name = "Allocate_%s" % attribute_id
		increment_button.text = "+1 %s" % _attribute_name(attribute_id)
		increment_button.tooltip_text = "Investir 1 ponto de atributo via perfil."
		increment_button.pressed.connect(_allocate_attribute.bind(attribute_id))
		progression_attribute_actions.add_child(increment_button)
		attribute_increment_buttons[attribute_id] = increment_button
	respec_attributes_button = Button.new()
	respec_attributes_button.name = "RespecAttributes"
	respec_attributes_button.text = "Redistribuir atributos"
	respec_attributes_button.tooltip_text = "Devolve os pontos de atributos investidos."
	respec_attributes_button.pressed.connect(_respec_attributes)
	progression_attribute_actions.add_child(respec_attributes_button)
	var skill_tree_title := Label.new()
	skill_tree_title.text = "Árvore de skills"
	skill_tree_title.add_theme_font_size_override("font_size", 16)
	progression_panel.add_child(skill_tree_title)
	progression_skill_tree = VBoxContainer.new()
	progression_skill_tree.name = "ProgressionSkillTree"
	progression_skill_tree.add_theme_constant_override("separation", 2)
	progression_panel.add_child(progression_skill_tree)
	respec_skills_button = Button.new()
	respec_skills_button.name = "RespecSkills"
	respec_skills_button.text = "Redistribuir skills"
	respec_skills_button.tooltip_text = "Devolve as compras das carteiras base e de evolução."
	respec_skills_button.pressed.connect(_respec_skills)
	progression_panel.add_child(respec_skills_button)
	evolution_panel = VBoxContainer.new()
	evolution_panel.name = "EvolutionPanel"
	evolution_panel.add_theme_constant_override("separation", 4)
	roster_column.add_child(evolution_panel)
	var evolution_title := Label.new()
	evolution_title.text = "Evolução"
	evolution_title.add_theme_font_size_override("font_size", 18)
	evolution_panel.add_child(evolution_title)
	evolution_state_label = Label.new()
	evolution_state_label.name = "EvolutionState"
	evolution_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evolution_panel.add_child(evolution_state_label)
	evolution_options_list = VBoxContainer.new()
	evolution_options_list.name = "EvolutionOptions"
	evolution_options_list.add_theme_constant_override("separation", 2)
	evolution_panel.add_child(evolution_options_list)
	evolution_confirmation_label = Label.new()
	evolution_confirmation_label.name = "EvolutionConfirmation"
	evolution_confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evolution_panel.add_child(evolution_confirmation_label)
	var evolution_actions := HBoxContainer.new()
	evolution_actions.name = "EvolutionActions"
	evolution_panel.add_child(evolution_actions)
	confirm_evolution_button = Button.new()
	confirm_evolution_button.name = "ConfirmEvolution"
	confirm_evolution_button.text = "Confirmar evolução"
	confirm_evolution_button.pressed.connect(_confirm_evolution_change)
	evolution_actions.add_child(confirm_evolution_button)
	cancel_evolution_button = Button.new()
	cancel_evolution_button.name = "CancelEvolution"
	cancel_evolution_button.text = "Cancelar"
	cancel_evolution_button.pressed.connect(_cancel_evolution_change)
	evolution_actions.add_child(cancel_evolution_button)
	var editor_title := Label.new()
	editor_title.text = "Editar preset legal"
	editor_title.add_theme_font_size_override("font_size", 18)
	roster_column.add_child(editor_title)
	for index: int in CharacterState.ACTIVE_SLOT_COUNT:
		var selector := _build_selector(roster_column, "Ativa %d" % (index + 1))
		active_selectors.append(selector)
		if index == 0:
			active_slot_a = selector
		elif index == 1:
			active_slot_b = selector
	for index: int in CharacterState.PASSIVE_SLOT_COUNT:
		var selector := _build_selector(roster_column, "Passiva %d" % (index + 1))
		passive_selectors.append(selector)
		if index == 0:
			passive_slot = selector
	weapon_selector = _build_selector(roster_column, "Arma")
	armor_selector = _build_selector(roster_column, "Armadura")
	accessory_selector = _build_selector(roster_column, "Acessório")
	save_build_button = Button.new()
	save_build_button.text = "Salvar preset"
	save_build_button.custom_minimum_size = Vector2(0, 40)
	save_build_button.pressed.connect(_save_build)
	roster_column.add_child(save_build_button)
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
	for class_id: StringName in [&"swordsman", &"mage", &"archer"]:
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
	start_run_button = Button.new()
	start_run_button.name = "StartRun"
	start_run_button.text = "Iniciar run com este personagem"
	start_run_button.tooltip_text = "Abrir a arena usando o personagem selecionado"
	start_run_button.custom_minimum_size = Vector2(0, 48)
	start_run_button.pressed.connect(_start_run)
	menu_panel.add_child(start_run_button)

func _build_selector(parent: Container, label_text: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(82, 0)
	row.add_child(label)
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(190, 32)
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(selector)
	return selector
