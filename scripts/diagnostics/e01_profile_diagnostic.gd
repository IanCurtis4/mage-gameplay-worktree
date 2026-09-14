class_name E01ProfileDiagnostic
extends Control
## Manual E01 diagnostic. It is deliberately not the game's main menu or run scene.

const MANUAL_PROFILE_DIRECTORY := "user://e01_manual_test"
const REWARD_ID: StringName = &"simulation_reward"

var profile_directory := MANUAL_PROFILE_DIRECTORY
var facade: ProfileFacade
var active_run: RunState
var _last_reward_request: Dictionary = {}
var _request_serial := 0

var status_label: Label
var profile_label: Label
var run_label: Label
var log_label: RichTextLabel
var create_swordsman_button: Button
var create_mage_button: Button
var select_swordsman_button: Button
var select_mage_button: Button
var start_run_button: Button
var reward_button: Button
var retry_reward_button: Button
var augment_button: Button
var victory_button: Button
var death_button: Button
var abandon_button: Button

func set_profile_directory(directory: String) -> void:
	profile_directory = directory

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_build_ui()
	_open_profile()

func create_swordsman() -> Dictionary:
	return _create_alt("Alt Espadachim", &"swordsman")

func create_mage() -> Dictionary:
	return _create_alt("Alt Mago", &"mage")

func select_alt(base_class_id: StringName) -> Dictionary:
	var profile := facade.current_profile()
	if profile == null:
		return _show_result("Selecionar alt", {"ok": false, "error_code": &"profile_unavailable"})
	for character: CharacterState in profile.characters:
		if character.base_class_id == base_class_id:
			return _show_result("Selecionar alt", facade.select_character(_request_id("select"), profile.revision, character.character_id))
	return _show_result("Selecionar alt", {"ok": false, "error_code": &"alt_not_created"})

func start_simulation() -> Dictionary:
	var profile := facade.current_profile()
	if profile == null:
		return _show_result("Iniciar simulação", {"ok": false, "error_code": &"profile_unavailable"})
	var result := facade.start_run(_request_id("start"), profile.revision)
	if result.get("ok", false):
		active_run = result["run_state"]
	return _show_result("Iniciar simulação", result)

func grant_simulation_reward() -> Dictionary:
	if active_run == null:
		return _show_result("Recompensa", {"ok": false, "error_code": &"run_inactive"})
	var profile := facade.current_profile()
	var request := {
		"request_id": _request_id("reward"),
		"expected_revision": profile.revision,
		"run_id": active_run.run_id,
		"sequence": _next_reward_sequence(),
		"reward_id": REWARD_ID,
	}
	_last_reward_request = request.duplicate(true)
	return _show_result("Recompensa — SIMULAÇÃO DE TESTE", _grant_request(request))

func retry_last_reward_literal() -> Dictionary:
	if _last_reward_request.is_empty():
		return _show_result("Retry literal", {"ok": false, "error_code": &"no_reward_request"})
	return _show_result("Retry literal", _grant_request(_last_reward_request))

func apply_test_augment() -> void:
	if active_run == null:
		_show_result("Augment", {"ok": false, "error_code": &"run_inactive"})
		return
	active_run.augment_stacks[&"vitality"] = active_run.augment_stacks.get(&"vitality", 0) + 1
	_append("Augment temporário aplicado à RunState em memória: Vitalidade. Não é salvo no alt.")
	_refresh()

func end_simulation(outcome: StringName) -> Dictionary:
	if active_run == null:
		return _show_result("Encerrar simulação", {"ok": false, "error_code": &"run_inactive"})
	var profile := facade.current_profile()
	var result := facade.end_run(_request_id("end"), profile.revision, active_run.run_id, outcome)
	if result.get("ok", false):
		active_run = null
	return _show_result("Encerrar simulação", result)

func _create_alt(display_name: String, base_class_id: StringName) -> Dictionary:
	var profile := facade.current_profile()
	if profile == null:
		return _show_result("Criar alt", {"ok": false, "error_code": &"profile_unavailable"})
	return _show_result("Criar %s" % display_name, facade.create_character(_request_id("create"), profile.revision, display_name, base_class_id))

func _grant_request(request: Dictionary) -> Dictionary:
	return facade.grant_reward(request["request_id"], request["expected_revision"], request["run_id"], request["sequence"], request["reward_id"])

func _open_profile() -> void:
	facade = ProfileFacade.new(ProfileStore.new(profile_directory, _catalog()), _resolver())
	_show_result("Abrir perfil", facade.open_profile())

func _catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({
		&"training_sword": {"slot": &"weapon", "allowed_base_classes": [&"swordsman"], "starter": true},
		&"apprentice_staff": {"slot": &"weapon", "allowed_base_classes": [&"mage"], "starter": true},
	})

func _resolver() -> ProfileRewardResolver:
	return ProfileRewardResolver.new({
		REWARD_ID: {"base_xp": 100, "job_xp": 80, "stat_increments": {&"kills": 1}},
	})

func _next_reward_sequence() -> int:
	var profile := facade.current_profile()
	if profile != null and profile.reward_session != null:
		return int(profile.reward_session["last_committed_seq"]) + 1
	return 1

func _request_id(prefix: String) -> String:
	_request_serial += 1
	return "diagnostic-%s-%d" % [prefix, _request_serial]

func _show_result(action: String, result: Dictionary) -> Dictionary:
	var summary := "OK" if result.get("ok", false) else "ERRO %s" % String(result.get("error_code", &"unknown"))
	if result.get("already_applied", false):
		summary += " (no-op confirmado)"
	if result.get("abandoned_run_closed", false):
		summary += " — sessão abandonada fechada na reabertura: %s" % String(result.get("abandoned_run_id", "desconhecida"))
	_append("%s: %s" % [action, summary])
	_refresh()
	return result

func _refresh() -> void:
	if facade == null or facade.current_profile() == null:
		return
	var profile := facade.current_profile()
	status_label.text = "Perfil isolado: %s | revisão %d | save normal não é usado" % [profile_directory, profile.revision]
	var lines: Array[String] = []
	for character: CharacterState in profile.characters:
		var selected := " [SELECIONADO]" if character.character_id == profile.selected_character_id else ""
		lines.append("%s%s — XP base %d (nível %d), job %d (nível %d)" % [character.display_name, selected, character.base_xp_total, ProgressionRules.base_level_for_xp(character.base_xp_total), character.job_xp_total, ProgressionRules.job_level_for_xp(character.job_xp_total, not character.evolution_id.is_empty())])
	profile_label.text = "Alts persistentes\n" + ("\n".join(lines) if not lines.is_empty() else "Nenhum alt criado.")
	if active_run == null:
		run_label.text = "Run: nenhuma. Encontro/recompensa: SIMULAÇÃO DE TESTE; não há combate real."
	else:
		run_label.text = "Run SIMULAÇÃO DE TESTE: %s | snapshot base %d / job %d | Vitalidade runtime %d\nEste augment existe apenas nesta RunState em memória." % [active_run.run_id, active_run.build_snapshot.base_level, active_run.build_snapshot.job_level, active_run.augment_stacks.get(&"vitality", 0)]
	var enabled := active_run != null
	var has_swordsman := _has_alt(profile, &"swordsman")
	var has_mage := _has_alt(profile, &"mage")
	create_swordsman_button.disabled = enabled or has_swordsman
	create_mage_button.disabled = enabled or has_mage
	select_swordsman_button.disabled = enabled or not has_swordsman
	select_mage_button.disabled = enabled or not has_mage
	start_run_button.disabled = enabled or profile.selected_character_id.is_empty()
	reward_button.disabled = not enabled
	retry_reward_button.disabled = not enabled or _last_reward_request.is_empty()
	augment_button.disabled = not enabled
	victory_button.disabled = not enabled
	death_button.disabled = not enabled
	abandon_button.disabled = not enabled

func _has_alt(profile: ProfileState, base_class_id: StringName) -> bool:
	for character: CharacterState in profile.characters:
		if character.base_class_id == base_class_id:
			return true
	return false

func _append(message: String) -> void:
	if log_label != null:
		log_label.append_text(message + "\n")

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101722")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36
	panel.offset_top = 28
	panel.offset_right = -36
	panel.offset_bottom = -28
	panel.add_theme_constant_override("separation", 10)
	add_child(panel)
	var title := Label.new()
	title.text = "E01.3-C — Diagnóstico manual de perfil"
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(status_label)
	profile_label = Label.new()
	profile_label.name = "ProfileSummary"
	profile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(profile_label)
	run_label = Label.new()
	run_label.name = "RunSummary"
	run_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(run_label)
	var buttons := GridContainer.new()
	buttons.columns = 3
	buttons.add_theme_constant_override("h_separation", 8)
	buttons.add_theme_constant_override("v_separation", 6)
	panel.add_child(buttons)
	create_swordsman_button = _button(buttons, "Criar alt Espadachim", create_swordsman)
	create_mage_button = _button(buttons, "Criar alt Mago", create_mage)
	select_swordsman_button = _button(buttons, "Selecionar Espadachim", func() -> void: select_alt(&"swordsman"))
	select_mage_button = _button(buttons, "Selecionar Mago", func() -> void: select_alt(&"mage"))
	start_run_button = _button(buttons, "Iniciar SIMULAÇÃO DE TESTE", start_simulation)
	reward_button = _button(buttons, "Conceder recompensa local de teste", grant_simulation_reward)
	retry_reward_button = _button(buttons, "Repetir última requisição literal", retry_last_reward_literal)
	augment_button = _button(buttons, "Aplicar augment runtime", apply_test_augment)
	victory_button = _button(buttons, "Encerrar por vitória", func() -> void: end_simulation(&"completed"))
	death_button = _button(buttons, "Encerrar por morte", func() -> void: end_simulation(&"death"))
	abandon_button = _button(buttons, "Abandonar simulação", func() -> void: end_simulation(&"abandoned"))
	log_label = RichTextLabel.new()
	log_label.name = "MessageLog"
	log_label.fit_content = false
	log_label.custom_minimum_size = Vector2(0, 120)
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(log_label)

func _button(parent: GridContainer, text_value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(280, 38)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
