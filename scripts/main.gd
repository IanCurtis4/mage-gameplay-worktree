class_name RunController
extends Node2D

const ARENA_BOUNDS := Rect2(80, 80, 1640, 920)
const ARENA_OBSTACLES: Array[Rect2] = [
	Rect2(610, 280, 190, 140),
	Rect2(1010, 570, 230, 125),
	Rect2(390, 700, 185, 105),
]
const TARGET_ASSIST_RADIUS := BattleTargeting.ASSIST_RADIUS
const TARGET_DIRECT_PADDING := BattleTargeting.DIRECT_PADDING
const ACTOR_BODY_OFFSET := BattleTargeting.BODY_OFFSET

var rng := RandomNumberGenerator.new()
var run_state := RunState.new()
var navigation := ArenaNavigation.new()
var arena_view: ArenaView
var player: PlayerActor
var enemies: Array[CombatActor] = []
var reward: RewardPickup
var encounter_index := 0
var encounter_active := false
var run_finished := false

var health_label: Label
var mana_label: Label
var skill_label: Label
var status_label: Label
var augment_button: Button
var next_button: Button
var ui_root: Control
var hud_panel: PanelContainer
var help_panel: PanelContainer
var bottom_controls: VBoxContainer
var augment_overlay: Control
var choice_column: VBoxContainer
var choice_buttons: VBoxContainer
var choice_title: Label
var augment_panel: PanelContainer
var result_overlay: Control
var result_panel: PanelContainer
var result_title: Label
var result_body: Label
var _hovered_enemy: CombatActor
var _selected_enemy: CombatActor
var _feedback_serial := 0
var cast_intent := CastIntent.new()
var control_preferences := ControlPreferences.new()
var battle_indicators: BattleIndicators
var battle_controls: BattleControls

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	y_sort_enabled = true
	rng.seed = Time.get_ticks_usec()
	navigation.configure(ARENA_BOUNDS, ARENA_OBSTACLES, 22.0)
	control_preferences.load_settings()
	cast_intent.set_mode(control_preferences.cast_mode)
	arena_view = ArenaView.new()
	arena_view.z_index = -2
	arena_view.configure(ARENA_BOUNDS, ARENA_OBSTACLES)
	add_child(arena_view)
	for obstacle: Rect2 in ARENA_OBSTACLES:
		var obstacle_view := ArenaObstacleView.new()
		obstacle_view.configure(obstacle)
		add_child(obstacle_view)
	battle_indicators = BattleIndicators.new()
	battle_indicators.z_index = -1
	battle_indicators.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(battle_indicators)
	player = PlayerActor.new()
	player.configure(navigation, run_state)
	player.global_position = Vector2(300, 520)
	player.attack_requested.connect(_on_attack_requested)
	player.actor_died.connect(_on_player_died)
	player.damage_number.connect(_show_damage_number)
	player.attack_missed.connect(_show_miss)
	add_child(player)
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = int(ARENA_BOUNDS.position.x - 40.0)
	camera.limit_top = int(ARENA_BOUNDS.position.y - 40.0)
	camera.limit_right = int(ARENA_BOUNDS.end.x + 40.0)
	camera.limit_bottom = int(ARENA_BOUNDS.end.y + 40.0)
	player.add_child(camera)
	_build_ui()
	_spawn_encounter(1)

func _process(_delta: float) -> void:
	_update_hud()
	if not get_tree().paused and not run_finished:
		if _world_pointer_available():
			_update_hover(get_global_mouse_position())
		else:
			_clear_hover()
		_update_aim(get_global_mouse_position())
	if get_tree().paused or reward == null or not is_instance_valid(reward):
		return
	if player.global_position.distance_to(reward.global_position) <= 48.0:
		_collect_reward()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and cast_intent.active_skill != &"":
		_cancel_aim()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if battle_controls.settings_overlay.visible:
				_toggle_settings(false)
			elif cast_intent.active_skill != &"":
				_cancel_aim()
			elif not get_tree().paused and not run_finished:
				_toggle_settings(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed and cast_intent.mode == CastIntent.Mode.RELEASE:
			var skill := _key_skill(event.keycode)
			if skill != &"" and skill == cast_intent.active_skill:
				var to_cast := cast_intent.release(skill)
				if _world_pointer_available():
					_commit_skill(to_cast, get_global_mouse_position())
				_cancel_aim()
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and (not player.is_alive() or run_finished):
			_restart_run()
			return
		if event.keycode == KEY_E and not run_finished and run_state.can_open_choice(encounter_active):
			_open_augment_menu()
			return
		if get_tree().paused or not player.is_alive() or run_finished:
			return
		var skill := _key_skill(event.keycode)
		if skill != &"":
			if _world_pointer_available():
				_commit_skill(cast_intent.press(skill), get_global_mouse_position())
				_update_aim(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and next_button.visible:
			_start_next_encounter()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_aim()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if get_tree().paused or not player.is_alive() or run_finished:
			return
		var world_point: Vector2 = get_canvas_transform().affine_inverse() * event.position
		if cast_intent.active_skill != &"":
			_commit_skill(cast_intent.confirm(), world_point)
			_cancel_aim()
		else:
			_handle_world_click(world_point)
		get_viewport().set_input_as_handled()

func _key_skill(key: Key) -> StringName:
	return &"slash" if key == KEY_Q else (&"dash" if key == KEY_W else &"")

func _commit_skill(skill: StringName, point: Vector2) -> void:
	if skill == &"" or get_tree().paused or run_finished or not player.is_alive():
		return
	var direction := player.aim_direction(point)
	if skill == &"slash":
		if not player.use_slash(direction, enemies):
			_show_skill_blocked("Corte em cone", player.slash_cooldown, PlayerActor.SLASH_MANA_COST)
	elif skill == &"dash":
		if not player.use_dash(direction):
			_show_skill_blocked("Investida", player.dash_cooldown, PlayerActor.DASH_MANA_COST)

func _select_skill_from_bar(skill: StringName) -> void:
	if get_tree().paused or run_finished or not player.is_alive():
		return
	cast_intent.active_skill = skill
	_update_aim(get_global_mouse_position())

func _update_aim(point: Vector2) -> void:
	var skill := cast_intent.active_skill
	if skill == &"" or get_tree().paused or run_finished:
		battle_indicators.clear_aim()
		battle_controls.set_aim_text("")
		bottom_controls.visible = true
		return
	var is_slash := skill == &"slash"
	var cooldown := player.slash_cooldown if is_slash else player.dash_cooldown
	var cost := PlayerActor.SLASH_MANA_COST if is_slash else PlayerActor.DASH_MANA_COST
	var state := _skill_state(cooldown, cost)
	if _world_pointer_available():
		battle_indicators.show_aim(skill, player, point, state == "PRONTO")
	else:
		battle_indicators.clear_aim()
	var action := "Solte a tecla ou clique" if cast_intent.mode == CastIntent.Mode.RELEASE else "Clique para lançar"
	battle_controls.set_aim_text("%s · %s  |  %s  |  Direito / Esc cancela" % ["Corte" if is_slash else "Investida", state, action])
	bottom_controls.visible = false

func _cancel_aim() -> void:
	cast_intent.cancel()
	if battle_indicators != null:
		battle_indicators.clear_aim()
	if battle_controls != null:
		battle_controls.set_aim_text("")
	if bottom_controls != null:
		bottom_controls.visible = true

func _world_pointer_available() -> bool:
	return get_viewport().gui_get_hovered_control() == null

func _clear_hover() -> void:
	if is_instance_valid(_hovered_enemy):
		_hovered_enemy.set_hovered(false)
	_hovered_enemy = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_aim()

func _toggle_settings(open: bool) -> void:
	if open and (get_tree().paused or run_finished):
		return
	_cancel_aim()
	_clear_hover()
	battle_controls.settings_overlay.visible = open
	get_tree().paused = open

func _change_control_preferences(mode: int, smart_lock: bool) -> void:
	_cancel_aim()
	_clear_hover()
	cast_intent.set_mode(mode)
	control_preferences.cast_mode = mode
	control_preferences.smart_lock = smart_lock
	if control_preferences.save_settings() != OK:
		status_label.text = "Controles aplicados; não foi possível salvar a preferência."

func _spawn_encounter(index: int) -> void:
	encounter_index = index
	encounter_active = true
	next_button.visible = false
	augment_button.disabled = true
	var entries: Array[Dictionary]
	if index == 1:
		entries = [
			{"type": &"chaser", "position": Vector2(1220, 300)},
			{"type": &"chaser", "position": Vector2(1390, 720)},
		]
	else:
		entries = [
			{"type": &"chaser", "position": Vector2(1160, 240)},
			{"type": &"chaser", "position": Vector2(1370, 800)},
			{"type": &"archer", "position": Vector2(1500, 350)},
			{"type": &"archer", "position": Vector2(960, 850)},
		]
	for entry: Dictionary in entries:
		var enemy := EnemyActor.new()
		enemy.configure(entry["type"], navigation, player)
		enemy.global_position = entry["position"]
		enemy.attack_requested.connect(_on_enemy_attack_requested)
		enemy.actor_died.connect(_on_enemy_died)
		enemy.damage_number.connect(_show_damage_number)
		enemy.attack_missed.connect(_show_miss)
		add_child(enemy)
		enemies.append(enemy)
	status_label.text = "Encontro %d/2 — elimine todos os inimigos" % index

func _on_attack_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor != null and target_actor.is_alive():
		target_actor.apply_damage(request, rng)

func _on_enemy_attack_requested(request: DamageRequest, target_actor: CombatActor, ranged: bool) -> void:
	if not ranged:
		_on_attack_requested(request, target_actor)
		return
	var projectile := ArrowProjectile.new()
	var source := instance_from_id(request.source_id) as Node2D
	if source == null:
		projectile.queue_free()
		return
	projectile.configure(request, target_actor, source.global_position + Vector2(0, -18), navigation)
	projectile.hit.connect(_on_attack_requested)
	add_child(projectile)
	projectile.add_to_group("enemy_projectiles")

func _on_enemy_died(actor: CombatActor) -> void:
	if actor == _hovered_enemy:
		_hovered_enemy = null
	if actor == _selected_enemy:
		_selected_enemy = null
	enemies.erase(actor)
	actor.queue_free()
	if not enemies.is_empty():
		return
	encounter_active = false
	for projectile: Node in get_tree().get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()
	reward = RewardPickup.new()
	reward.global_position = Vector2(880, 500)
	reward.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(reward)
	status_label.text = "Encontro concluído — toque no cristal dourado"

func _collect_reward() -> void:
	if reward == null:
		return
	reward.queue_free()
	reward = null
	run_state.queue_choice()
	augment_button.disabled = false
	status_label.text = "Recompensa coletada — abra a escolha com E"

func _open_augment_menu() -> void:
	if run_finished or get_tree().paused:
		return
	var offer := run_state.build_offer(encounter_active, rng)
	if offer.is_empty():
		return
	_cancel_aim()
	_clear_hover()
	for child: Node in choice_buttons.get_children():
		child.queue_free()
	for definition: AugmentDefinition in offer:
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 88)
		button.text = "%s\n%s\n%s" % [definition.display_name, definition.description, run_state.describe_progress(definition)]
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_confirm_augment.bind(definition.id))
		choice_buttons.add_child(button)
	augment_overlay.visible = true
	get_tree().paused = true

func _confirm_augment(augment_id: StringName) -> void:
	if not run_state.confirm(augment_id, encounter_active):
		return
	player.apply_run_modifiers(run_state)
	augment_overlay.visible = false
	get_tree().paused = false
	augment_button.disabled = true
	if encounter_index >= 2:
		_show_result(true)
	else:
		next_button.visible = true
		status_label.text = "Augment aplicado — inicie o próximo encontro"

func _start_next_encounter() -> void:
	if encounter_active or reward != null or run_state.pending_choices > 0 or encounter_index >= 2:
		return
	_spawn_encounter(encounter_index + 1)

func _on_player_died(_actor: CombatActor) -> void:
	encounter_active = false
	_show_result(false)

func _show_result(victory: bool) -> void:
	_cancel_aim()
	_clear_hover()
	run_finished = true
	result_title.text = "Arena concluída!" if victory else "Você caiu em combate"
	result_body.text = ("Os dois encontros do Marco 1 foram vencidos.\n" if victory else "A run terminou e todo o estado temporário será descartado.\n") + "Pressione R ou use o botão para reiniciar."
	result_overlay.visible = true
	get_tree().paused = true

func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _enemy_at(point: Vector2) -> CombatActor:
	return BattleTargeting.pick(point, enemies, _hovered_enemy, control_preferences.smart_lock)

func _handle_world_click(point: Vector2) -> void:
	var clicked_enemy := _enemy_at(point)
	_select_enemy(clicked_enemy)
	if clicked_enemy != null:
		battle_indicators.show_click(clicked_enemy.global_position, true)
		player.pursue(clicked_enemy)
		status_label.text = "Perseguindo %s" % clicked_enemy.actor_name
	else:
		player.move_to(point)
		var route := navigation.get_path(player.global_position, point)
		if not route.is_empty():
			battle_indicators.show_click(route[-1])
		status_label.text = "Movendo"

func _update_hover(point: Vector2) -> void:
	var hovered := _enemy_at(point)
	if hovered == _hovered_enemy:
		return
	if _hovered_enemy != null and is_instance_valid(_hovered_enemy):
		_hovered_enemy.set_hovered(false)
	_hovered_enemy = hovered
	if _hovered_enemy != null:
		_hovered_enemy.set_hovered(true)

func _select_enemy(enemy: CombatActor) -> void:
	if _selected_enemy != null and is_instance_valid(_selected_enemy):
		_selected_enemy.set_selected(false)
	_selected_enemy = enemy
	if _selected_enemy != null:
		_selected_enemy.set_selected(true)

func _show_damage_number(actor: CombatActor, amount: int, critical: bool) -> void:
	if amount <= 0:
		return
	_show_combat_text(actor, ("CRÍTICO %d" if critical else "%d") % amount, Color("ffd166") if critical else Color.WHITE, 20 if critical else 17)

func _show_miss(actor: CombatActor) -> void:
	_show_combat_text(actor, "ERROU", Color("b9cbd3"), 16)

func _show_combat_text(actor: CombatActor, text: String, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.global_position = actor.global_position + Vector2(-22, -78)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 20
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -34), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)

func _update_hud() -> void:
	if player == null or player.health == null:
		return
	health_label.text = "VIDA  %d / %d" % [ceili(player.health.current_hp), ceili(player.health.max_hp)]
	mana_label.text = "MANA  %d / %d" % [floori(player.mana), floori(player.max_mana)]
	skill_label.text = "Q  Corte (%d mana) — %s\nW  Investida (%d mana) — %s" % [int(PlayerActor.SLASH_MANA_COST), _skill_state(player.slash_cooldown, PlayerActor.SLASH_MANA_COST), int(PlayerActor.DASH_MANA_COST), _skill_state(player.dash_cooldown, PlayerActor.DASH_MANA_COST)]
	augment_button.text = "Escolher augment (E) — %d pendente(s)" % run_state.pending_choices
	augment_button.visible = run_state.pending_choices > 0
	if battle_controls != null:
		battle_controls.show_skill_state(&"slash", "Q  ·  CORTE\n%d mana  ·  %s" % [int(PlayerActor.SLASH_MANA_COST), _skill_state(player.slash_cooldown, PlayerActor.SLASH_MANA_COST)], cast_intent.active_skill == &"slash")
		battle_controls.show_skill_state(&"dash", "W  ·  INVESTIDA\n%d mana  ·  %s" % [int(PlayerActor.DASH_MANA_COST), _skill_state(player.dash_cooldown, PlayerActor.DASH_MANA_COST)], cast_intent.active_skill == &"dash")

func _skill_state(cooldown: float, mana_cost: float) -> String:
	if cooldown > 0.0:
		return "RECARGA %.1fs" % cooldown
	if player.mana < mana_cost:
		return "SEM MANA"
	return "PRONTO"

func _show_skill_blocked(skill_name: String, cooldown: float, mana_cost: float) -> void:
	_feedback_serial += 1
	var serial := _feedback_serial
	status_label.text = "%s indisponível — %s" % [skill_name, _skill_state(cooldown, mana_cost)]
	get_tree().create_timer(1.2).timeout.connect(_restore_context_status.bind(serial))

func _restore_context_status(serial: int) -> void:
	if serial != _feedback_serial or run_finished:
		return
	if encounter_active:
		status_label.text = "Encontro %d/2 — elimine todos os inimigos" % encounter_index
	elif reward != null:
		status_label.text = "Encontro concluído — toque no cristal dourado"
	elif run_state.pending_choices > 0:
		status_label.text = "Recompensa coletada — abra a escolha com E"
	elif encounter_index < 2:
		status_label.text = "Augment aplicado — inicie o próximo encontro"

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	add_child(canvas)
	ui_root = Control.new()
	canvas.add_child(ui_root)
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _battle_theme()

	hud_panel = PanelContainer.new()
	ui_root.add_child(hud_panel)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_panel.offset_left = 24.0
	hud_panel.offset_top = 20.0
	hud_panel.offset_right = 544.0
	hud_panel.offset_bottom = 190.0
	var hud_margin := MarginContainer.new()
	hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		hud_margin.add_theme_constant_override("margin_" + side, 14)
	hud_panel.add_child(hud_margin)
	var hud_column := VBoxContainer.new()
	hud_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_margin.add_child(hud_column)
	health_label = _make_label("", 22, Color("ff8b8b"))
	mana_label = _make_label("", 19, Color("79bfff"))
	skill_label = _make_label("", 17, Color("e9c67b"))
	hud_column.add_child(health_label)
	hud_column.add_child(mana_label)
	hud_column.add_child(skill_label)

	help_panel = PanelContainer.new()
	ui_root.add_child(help_panel)
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help_panel.offset_left = -440.0
	help_panel.offset_top = 68.0
	help_panel.offset_right = -24.0
	help_panel.offset_bottom = 214.0
	var help_label := _make_label("CLIQUE: mover / autoatacar o alvo\nQ / W: skills no mouse\nDIREITO / ESC: cancelar mira\nE: augment  ·  ESPAÇO: próximo encontro", 16, Color("d7ddea"))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_panel.add_child(help_label)

	bottom_controls = VBoxContainer.new()
	ui_root.add_child(bottom_controls)
	bottom_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_controls.offset_left = -310.0
	bottom_controls.offset_top = -186.0
	bottom_controls.offset_right = 310.0
	bottom_controls.offset_bottom = -98.0
	bottom_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	status_label = _make_label("", 20, Color.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_controls.add_child(status_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_controls.add_child(buttons)
	augment_button = Button.new()
	augment_button.custom_minimum_size = Vector2(280, 44)
	augment_button.pressed.connect(_open_augment_menu)
	buttons.add_child(augment_button)
	next_button = Button.new()
	next_button.text = "Iniciar encontro 2 (Espaço)"
	next_button.custom_minimum_size = Vector2(250, 44)
	next_button.pressed.connect(_start_next_encounter)
	next_button.visible = false
	buttons.add_child(next_button)

	augment_overlay = _make_overlay(ui_root)
	augment_panel = PanelContainer.new()
	augment_overlay.add_child(augment_panel)
	augment_panel.set_anchors_preset(Control.PRESET_CENTER)
	augment_panel.offset_left = -300.0
	augment_panel.offset_top = -245.0
	augment_panel.offset_right = 300.0
	augment_panel.offset_bottom = 245.0
	var augment_margin := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		augment_margin.add_theme_constant_override("margin_" + side, 24)
	augment_panel.add_child(augment_margin)
	choice_column = VBoxContainer.new()
	choice_column.add_theme_constant_override("separation", 14)
	augment_margin.add_child(choice_column)
	choice_title = _make_label("Escolha um augment", 30, Color("e9c67b"))
	choice_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_column.add_child(choice_title)
	choice_buttons = VBoxContainer.new()
	choice_buttons.add_theme_constant_override("separation", 14)
	choice_column.add_child(choice_buttons)
	augment_overlay.visible = false

	result_overlay = _make_overlay(ui_root)
	result_panel = PanelContainer.new()
	result_overlay.add_child(result_panel)
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -280.0
	result_panel.offset_top = -150.0
	result_panel.offset_right = 280.0
	result_panel.offset_bottom = 150.0
	var result_column := VBoxContainer.new()
	result_column.alignment = BoxContainer.ALIGNMENT_CENTER
	result_column.add_theme_constant_override("separation", 24)
	result_panel.add_child(result_column)
	result_title = _make_label("", 34, Color("e9c67b"))
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_column.add_child(result_title)
	result_body = _make_label("", 20, Color("d7ddea"))
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_column.add_child(result_body)
	var restart := Button.new()
	restart.text = "Reiniciar arena (R)"
	restart.custom_minimum_size = Vector2(260, 54)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(_restart_run)
	result_column.add_child(restart)
	result_overlay.visible = false
	battle_controls = BattleControls.new()
	ui_root.add_child(battle_controls)
	battle_controls.set_options(control_preferences.cast_mode, control_preferences.smart_lock)
	battle_controls.skill_selected.connect(_select_skill_from_bar)
	battle_controls.settings_requested.connect(_toggle_settings)
	battle_controls.preferences_changed.connect(_change_control_preferences)
	# The battle controls belong below end-of-run and reward modals.
	ui_root.move_child(battle_controls, augment_overlay.get_index())

func _battle_theme() -> Theme:
	var theme_value := Theme.new()
	theme_value.default_font_size = 16
	var panel := _panel_style(Color(0.045, 0.085, 0.11, 0.92), Color("415b67"))
	theme_value.set_stylebox("panel", "PanelContainer", panel)
	theme_value.set_stylebox("normal", "Button", _panel_style(Color("132b35"), Color("587784")))
	theme_value.set_stylebox("hover", "Button", _panel_style(Color("23454d"), Color("81dfd0")))
	theme_value.set_stylebox("pressed", "Button", _panel_style(Color("30554f"), Color("f5cc77")))
	theme_value.set_stylebox("disabled", "Button", _panel_style(Color("17252b"), Color("35454d")))
	theme_value.set_color("font_color", "Button", Color("e8efee"))
	theme_value.set_color("font_pressed_color", "Button", Color("ffe0a0"))
	return theme_value

func _panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _make_overlay(parent: Control) -> Control:
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.025, 0.04, 0.82)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return overlay

func _make_label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
