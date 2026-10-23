class_name PhaseSelectionPanel
extends PanelContainer
const Phase = preload("res://data/expedition/phases/ruined_crossing.gd")
var facade: ProfileFacade
var menu: CharacterMenu
var character_id := ""
var seed_input: LineEdit
var message: Label
var start_button: Button
var retry_button: Button
var close_button: Button
var service: ExpeditionService
var host: RunController
var manifest: ExpeditionManifest
var request := ""
var busy := false
var uncertain := false
var service_pending := false

func configure(owner_menu: CharacterMenu, id: String) -> void:
	menu = owner_menu; facade = menu.facade as ProfileFacade; character_id = id
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("101821")
	background.set_content_margin_all(20.0)
	add_theme_stylebox_override("panel", background)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "Expedições · " + Phase.TITLE
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	var description := Label.new()
	description.text = "Quatro estágios, ramo lateral com retorno, rampa e ponte sobre uma passagem.\nNível mínimo 1 · sem chave ou custo. Conclusão: 100 gold, 300 EXP Base e 200 EXP Job; sem equipamento garantido.\nSair suspende a mesma expedição. Seu personagem fica reservado até concluí-la."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)
	seed_input = LineEdit.new()
	seed_input.text = str(Time.get_ticks_usec())
	seed_input.placeholder_text = "Seed decimal da montagem"
	column.add_child(seed_input)
	start_button = Button.new()
	start_button.custom_minimum_size.y = 48
	start_button.pressed.connect(start)
	column.add_child(start_button)
	retry_button = Button.new()
	retry_button.text = "Tentar novamente / confirmar recuperação"
	retry_button.hide(); retry_button.pressed.connect(retry)
	column.add_child(retry_button)
	close_button = Button.new()
	close_button.text = "Voltar à preparação"
	close_button.pressed.connect(queue_free)
	column.add_child(close_button)
	var profile := facade.current_profile()
	var character := profile.character_by_id(id) if profile != null else null
	var lock := profile.expedition_for_character(id) if profile != null else null
	message.text = "Personagem: %s" % character.display_name if character != null else "Selecione um personagem válido."
	start_button.text = "Retomar expedição deste personagem" if lock != null else "Iniciar Travessia das Ruínas"
	start_button.disabled = character == null
	seed_input.editable = lock == null
	seed_input.visible = lock == null
	if lock != null: message.text += "\nMontagem preservada; a retomada conserva a expedição existente."

func start() -> Dictionary:
	if busy: return BuildEffectCatalog.failure(&"save_in_progress")
	busy = true; start_button.disabled = true; close_button.disabled = true
	service_pending = false; seed_input.editable = false
	service = ExpeditionService.new(facade)
	request = "f7_entry_%d" % Time.get_ticks_usec()
	var profile := facade.current_profile()
	var lock := profile.expedition_for_character(character_id)
	if lock != null:
		service_pending = true
		var resumed := service.resume(lock.expedition_id, character_id, request, profile.revision)
		return _finish(resumed)
	var generated := ExpeditionAssembler.build(Phase.input(seed_input.text.strip_edges()))
	if not generated["ok"]: return _finish(generated)
	manifest = generated["data"]["manifest"]
	if profile.selected_character_id != character_id:
		var selected := facade.select_character("select_" + request, profile.revision, character_id)
		if not selected["ok"]: return _finish(selected)
		profile = facade.current_profile()
	var started := facade.start_run("start_" + request, profile.revision)
	if not started["ok"]: return _finish(started)
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_gameplay_extension = true
	host = RunController.new()
	host.expedition_entry_mode = true
	# Keep the staging world visible in the captured simulation; only the old
	# menu covers it until the service commits. Visibility is snapshot state.
	menu.z_index = 4095
	get_tree().root.add_child(host)
	host.arena_view.hide(); host.ui_root.hide()
	host.route_camera.enabled = false
	var requested := host.request_memory_snapshot()
	if not requested["ok"]: return _finish(requested)
	var captured: Dictionary = await host.memory_snapshot_ready
	await get_tree().process_frame
	if not captured["ok"]: return _finish(captured)
	service_pending = true
	return _finish(service.enter(host, host._memory_snapshot_barrier, "exp_" + host.run_state.run_id.md5_text(), manifest, Phase.rules(manifest), request, facade.current_profile().revision))

func _finish(result: Dictionary) -> Dictionary:
	busy = false
	if result.get("ok", false) and result.has("root"):
		var installed := ExpeditionSceneFlow.install(result, menu)
		if installed.get("ok", false):
			if is_instance_valid(host): host.queue_free()
			return result
		result = installed
	uncertain = result.get("read_only", false)
	message.text = ExpeditionPresentation.error_text(result.get("error_code", &"unknown"))
	retry_button.show()
	close_button.disabled = uncertain or is_instance_valid(host)
	start_button.disabled = uncertain or is_instance_valid(host)
	seed_input.editable = not uncertain and not is_instance_valid(host) and facade.current_profile().expedition_for_character(character_id) == null
	if uncertain and not service_pending:
		retry_button.disabled = true
		message.text += "\nA preparação não foi confirmada. Reabra o perfil para avaliar a recuperação; nenhuma expedição nova será iniciada por esta tela."
	return result

func retry() -> Dictionary:
	if busy: return BuildEffectCatalog.failure(&"save_in_progress")
	if uncertain: return _finish(service.reconcile(request))
	if is_instance_valid(host) and host._memory_snapshot_barrier != null:
		return _finish(service.enter(host, host._memory_snapshot_barrier, "exp_" + host.run_state.run_id.md5_text(), manifest, Phase.rules(manifest), request, facade.current_profile().revision))
	return await start()
