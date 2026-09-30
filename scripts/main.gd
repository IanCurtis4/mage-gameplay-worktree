class_name RunController
extends Node2D

const IceWallScript = preload("res://scripts/world/ice_wall.gd")
const ElementalistSequenceScript = preload("res://scripts/world/elementalist_sequence.gd")

const ARENA_BOUNDS := Rect2(80, 80, 1640, 920)
const ARENA_OBSTACLES: Array[Rect2] = [
	Rect2(610, 280, 190, 140),
	Rect2(1010, 570, 230, 125),
	Rect2(390, 700, 185, 105),
]
const TARGET_ASSIST_RADIUS := BattleTargeting.ASSIST_RADIUS
const TARGET_DIRECT_PADDING := BattleTargeting.DIRECT_PADDING
const ACTOR_BODY_OFFSET := BattleTargeting.BODY_OFFSET
const SKILL_KEYS := [KEY_Q, KEY_W, KEY_A, KEY_S, KEY_D]
const DEFENDER_WATCH_DIRECT_MELEE_IDS := [
	&"basic_attack", &"cone_slash", &"brutal_strike", &"concentrated_rage",
	&"defender_counterstroke", &"defender_line_lock", &"defender_wall_advance", &"defender_reprisal_wave",
]
const TRAINING_BOSS_HP := 50000.0
const TRAINING_ADD_HP := 1500.0
const TRAINING_BOSS_DAMAGE_MULTIPLIER := 0.18
const TRAINING_ADD_DAMAGE_MULTIPLIER := 0.15
const TRAINING_ADD_INTERVAL := 8.0
const TRAINING_ADD_CAP := 6
const TRAINING_ADD_OFFSETS: Array[Vector2] = [
	Vector2(210, -125), Vector2(-210, -125), Vector2(220, 145), Vector2(-220, 145),
	Vector2(320, 30), Vector2(-320, 30), Vector2(80, -260), Vector2(-80, 260),
]
static var selected_class_id: StringName = &"swordsman"
static var pending_run_state: RunState = null
static var pending_run_facade: ProfileFacade = null
static var pending_training_mode := false

var rng := RandomNumberGenerator.new()
var run_state: RunState
var navigation := ArenaNavigation.new()
var arena_view: ArenaView
var player: PlayerActor
var enemies: Array[CombatActor] = []
var _credited_kills: Dictionary[int, bool] = {}
var _defender_slowed_enemies: Dictionary[int, CombatActor] = {}
var spiritualist_echo_state := SpiritualistEchoState.new()
var spiritualist_drain_state := SpiritualistDrainState.new()
var spiritualist_veil_state := SpiritualistVeilState.new()
var spiritualist_procession_state := SpiritualistProcessionState.new()
var spiritualist_veil_fraction := 0.0
var _spiritualist_veil_members: Dictionary[int, CombatActor] = {}
var _spiritualist_echo_number_target_id := 0
var _spiritualist_feedback_labels: Array[Label] = []
var _spiritualist_channel_notice_remaining := 0.0
var _spiritualist_recent_feedback := ""
var _spiritualist_recent_feedback_remaining := 0.0
var reward: RewardPickup
var encounter_index := 0
var encounter_active := false
var run_finished := false
var _terminal_outcome: StringName = &"abandoned"
var persistent_facade: ProfileFacade = null
var _close_request_serial := 0
var _reward_retry_pending := false
var training_mode := false
var training_boss: EnemyActor = null
var _training_add_elapsed := 0.0
var _training_wave_index := 0

var health_label: Label
var sp_label: Label
var skill_label: Label
var defender_status_label: Label
var training_status_label: Label
var status_label: Label
var augment_button: Button
var next_button: Button
var ui_root: Control
var hud_panel: PanelContainer
var help_panel: PanelContainer
var spiritualist_panel: PanelContainer
var spiritualist_state_label: Label
var spiritualist_hint_label: Label
var spiritualist_help_label: Label
var spiritualist_help_toggle: Button
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
var restart_button: Button
var _hovered_enemy: CombatActor
var _selected_enemy: CombatActor
var _feedback_serial := 0
var cast_intent := CastIntent.new()
var control_preferences := ControlPreferences.new()
var battle_indicators: BattleIndicators
var trap_registry: PlayerTrapRegistry
var battle_controls: BattleControls
var class_button: Button
var class_overlay: Control
var class_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	y_sort_enabled = true
	rng.seed = Time.get_ticks_usec()
	if pending_run_state != null:
		run_state = pending_run_state
		persistent_facade = pending_run_facade
		training_mode = pending_training_mode
		pending_run_state = null
		pending_run_facade = null
		pending_training_mode = false
	else:
		run_state = RunState.new(selected_class_id)
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
	trap_registry = PlayerTrapRegistry.new()
	trap_registry.y_sort_enabled = true
	add_child(trap_registry)
	player = PlayerActor.new()
	player.configure(navigation, run_state)
	player.global_position = Vector2(300, 520)
	player.attack_requested.connect(_on_attack_requested)
	player.defender_hit_requested.connect(_on_defender_hit_requested)
	player.berserker_rift_hit_requested.connect(_on_berserker_rift_hit_requested)
	player.berserker_breath_hit_requested.connect(_on_berserker_breath_hit_requested)
	player.mage_projectile_requested.connect(_on_mage_projectile_requested)
	player.discharge_requested.connect(_on_discharge_requested)
	player.precision_projectile_requested.connect(_on_precision_projectile_requested)
	player.arrow_rain_requested.connect(_on_arrow_rain_requested)
	player.snare_trap_requested.connect(_on_snare_trap_requested)
	player.explosive_trap_requested.connect(_on_explosive_trap_requested)
	player.slowing_arrow_requested.connect(_on_slowing_arrow_requested)
	player.foliage_shelter_requested.connect(_on_foliage_shelter_requested)
	player.fire_wall_requested.connect(_on_fire_wall_requested)
	player.elementalist_flame_burst_requested.connect(_on_elementalist_flame_burst_requested)
	player.elementalist_area_requested.connect(_on_elementalist_area_requested)
	player.elementalist_lightning_arc_requested.connect(_on_elementalist_lightning_arc_requested)
	player.elementalist_ember_path_requested.connect(_on_elementalist_ember_path_requested)
	player.elementalist_tri_nova_requested.connect(_on_elementalist_tri_nova_requested)
	player.spiritualist_echo_curse_requested.connect(_on_spiritualist_echo_curse_requested)
	player.spiritualist_drain_requested.connect(_on_spiritualist_drain_requested)
	player.spiritualist_veil_requested.connect(_on_spiritualist_veil_requested)
	player.spiritualist_procession_requested.connect(_on_spiritualist_procession_requested)
	player.spiritualist_dissipation_requested.connect(_on_spiritualist_dissipation_requested)
	player.spiritualist_channel_interrupt_requested.connect(_cancel_spiritualist_drain)
	player.spiritualist_focus_event.connect(_on_spiritualist_focus_event)
	player.health.damage_applied.connect(_on_player_damage_resolved)
	player.lightning_wall_requested.connect(_on_lightning_wall_requested)
	player.soul_impact_requested.connect(_on_soul_impact_requested)
	player.haunt_requested.connect(_on_haunt_requested)
	player.phantom_barrier_requested.connect(_on_phantom_barrier_requested)
	player.ice_wall_requested.connect(_on_ice_wall_requested)
	player.provoke_requested.connect(_on_provoke_requested)
	player.piercing_shout_requested.connect(_on_piercing_shout_requested)
	player.brutal_strike_requested.connect(_on_brutal_strike_requested)
	player.terrifying_shout_requested.connect(_on_terrifying_shout_requested)
	player.skill_cast_ready.connect(_on_skill_cast_ready)
	player.status_damage_requested.connect(_on_attack_requested)
	player.actor_died.connect(_on_player_died)
	player.damage_number.connect(_show_damage_number)
	player.attack_missed.connect(_show_miss)
	add_child(player)
	spiritualist_echo_state.source_id = player.get_instance_id()
	var camera := Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = int(ARENA_BOUNDS.position.x - 40.0)
	camera.limit_top = int(ARENA_BOUNDS.position.y - 40.0)
	camera.limit_right = int(ARENA_BOUNDS.end.x + 40.0)
	camera.limit_bottom = int(ARENA_BOUNDS.end.y + 40.0)
	player.add_child(camera)
	_build_ui()
	if training_mode:
		_spawn_training_boss()
	else:
		_spawn_encounter(1)

func _process(_delta: float) -> void:
	player.regenerate_hp(_delta, encounter_active, get_tree().paused or run_finished)
	if not get_tree().paused and not run_finished:
		_spiritualist_channel_notice_remaining = maxf(0.0, _spiritualist_channel_notice_remaining - _delta)
		_spiritualist_recent_feedback_remaining = maxf(0.0, _spiritualist_recent_feedback_remaining - _delta)
		if training_mode and player.is_alive() and training_boss != null and training_boss.is_alive():
			_advance_training_adds(_delta)
		_sync_defender_anchor()
		_sync_berserker_wound_visuals()
		if player.is_alive():
			var marks_before := spiritualist_echo_state.marks.keys()
			for echo: Dictionary in spiritualist_echo_state.advance(_delta):
				_apply_spiritualist_echo(echo)
			_advance_spiritualist_drain(_delta)
			_advance_spiritualist_veil(_delta)
			_advance_spiritualist_procession(_delta)
			_sync_spiritualist_combat_state(marks_before)
			battle_indicators.sync_spiritualist_focus(player.get_instance_id(), player.spiritualist_focus_remaining)
	_update_hud()
	if not get_tree().paused and not run_finished:
		if _world_pointer_available():
			_update_hover(get_global_mouse_position())
		else:
			_clear_hover()
		_update_aim(get_global_mouse_position())
	if get_tree().paused or _reward_retry_pending or reward == null or not is_instance_valid(reward):
		return
	if player.global_position.distance_to(reward.global_position) <= 48.0:
		_collect_reward()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and (cast_intent.active_skill != &"" or player.has_active_cast()):
		_cancel_casting()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if class_overlay.visible:
				_close_class_menu()
			elif battle_controls.settings_overlay.visible:
				_toggle_settings(false)
			elif cast_intent.active_skill != &"" or player.has_active_cast():
				_cancel_casting()
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
		if event.keycode == KEY_E and _reward_retry_pending:
			_reward_retry_pending = false
			_collect_reward()
			get_viewport().set_input_as_handled()
			return
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
			player.cancel_active_cast()
			var definition := ClassCatalog.skill_definition(skill)
			if definition != null and definition.targeting == SkillDefinition.Targeting.SELF:
				cast_intent.cancel()
				_commit_skill(skill, player.global_position)
				_cancel_aim()
			elif _world_pointer_available():
				_commit_skill(cast_intent.press(skill), get_global_mouse_position())
				_update_aim(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE and next_button.visible:
			_start_next_encounter()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_casting()
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
	var index := SKILL_KEYS.find(key)
	var skill_ids := player.available_skill_ids()
	return skill_ids[index] if index >= 0 and index < skill_ids.size() else &""

func _commit_skill(skill: StringName, point: Vector2) -> void:
	if skill == &"" or get_tree().paused or run_finished or not player.is_alive():
		return
	if spiritualist_drain_state.active:
		_cancel_spiritualist_drain()
	var definition := ClassCatalog.skill_definition(skill)
	var selected_target: CombatActor
	if definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET:
		selected_target = _enemy_at(point)
	if player.skill_cast_time(skill) > 0.0:
		if not player.begin_skill_cast(skill, point, selected_target):
			_report_skill_failure(skill, selected_target)
		return
	_execute_skill(skill, point, selected_target)

func _on_skill_cast_ready(skill: StringName, point: Vector2, target_id: int) -> void:
	if get_tree().paused or run_finished or not player.is_alive():
		return
	var selected_target := instance_from_id(target_id) as CombatActor if target_id != 0 else null
	_execute_skill(skill, point, selected_target)

func _execute_skill(skill: StringName, point: Vector2, selected_target: CombatActor = null) -> void:
	var direction := player.aim_direction(point)
	var definition := ClassCatalog.skill_definition(skill)
	if definition == null:
		return
	if definition.handler_id == SkillDefinition.Handler.SLASH:
		if not player.use_slash(direction, enemies):
			_show_skill_blocked(definition.display_name, player.slash_cooldown, player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.DASH:
		if not player.use_dash(direction):
			_show_skill_blocked(definition.display_name, player.dash_cooldown, player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.SHIELD_WALL:
		if not player.use_shield_wall(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.PROVOKE:
		if not player.use_provoke(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.PERSEVERANCE:
		if not player.use_perseverance():
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.PIERCING_SHOUT:
		if not player.use_piercing_shout():
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.FURY:
		if not player.use_fury():
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.BRUTAL_STRIKE:
		if not player.use_brutal_strike(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.CONCENTRATED_RAGE:
		if not player.use_concentrated_rage(direction, enemies):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.TERRIFYING_SHOUT:
		if not player.use_terrifying_shout():
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.FIREBALL:
		if not player.use_fireball(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.FIRE_WALL:
		if not player.use_fire_wall(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.ELEMENTALIST_FLAME_BURST:
		if not player.use_elementalist_flame_burst(point):
			if not player.can_place_elementalist_flame_burst(point):
				status_label.text = "Explosão de Chamas cancelada — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.LIGHTNING_WALL:
		if not player.use_lightning_wall(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.SOUL_IMPACT:
		if not player.use_soul_impact(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.HAUNT:
		if not player.use_haunt(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.PHANTOM_BARRIER:
		if not player.use_phantom_barrier(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.ICE_WALL:
		if not player.use_ice_wall(direction, enemies):
			if not player.can_place_ice_wall(direction, enemies):
				status_label.text = "Parede de Gelo cancelada — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.SPEAR:
		if not player.use_spear(skill, selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.LIGHTNING:
		if not player.use_lightning(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.ELECTRIC_DISCHARGE:
		if not player.use_electric_discharge(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.TELEPORT:
		if not player.use_teleport(point):
			if not player.can_teleport(point):
				status_label.text = "Teleporte indisponível — DESTINO BLOQUEADO"
			else:
				_show_skill_blocked("Teleporte", player.skill_cooldown(skill), player.skill_cost(skill))
		else:
			_select_enemy(null)
	elif definition.handler_id == SkillDefinition.Handler.DOUBLE_SHOT:
		if not player.use_double_shot(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.PIERCING_ARROW:
		if not player.use_piercing_arrow(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.ARROW_RAIN:
		if not player.use_arrow_rain(point):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.EXTENDED_AIM:
		if not player.use_extended_aim():
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.SNARE_TRAP:
		if not player.use_snare_trap(point):
			if not player.can_place_snare_trap(point):
				status_label.text = "Armadilha de Laço cancelada — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.EXPLOSIVE_TRAP:
		if not player.use_explosive_trap(point):
			if not player.can_place_explosive_trap(point):
				status_label.text = "Armadilha Explosiva cancelada — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.SLOWING_ARROW:
		if not player.use_slowing_arrow(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.FOLIAGE_SHELTER:
		if not player.use_foliage_shelter(point):
			if not player.can_place_foliage_shelter(point):
				status_label.text = "Abrigo de Folhagem cancelado — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.DEFENDER_COUNTERSTROKE:
		if not player.use_defender_counterstroke(direction, enemies):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.DEFENDER_ANCHOR:
		if player.use_defender_anchor(point):
			battle_indicators.show_defender_anchor(player.defender_anchor_center, player.defender_anchor_remaining)
			_sync_defender_anchor()
		else:
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.DEFENDER_LINE_LOCK:
		if not player.use_defender_line_lock(direction, enemies):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.DEFENDER_WALL_ADVANCE:
		if not player.use_defender_wall_advance(direction, enemies):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.DEFENDER_REPRISAL_WAVE:
		var center := player.defender_anchor_center if player.has_defender_anchor() else player.global_position
		if player.use_defender_reprisal_wave(enemies):
			battle_indicators.show_defender_reprisal_wave(center)
		else:
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.ELEMENTALIST_GLACIAL_RING:
		if not player.use_elementalist_glacial_ring():
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.ELEMENTALIST_LIGHTNING_ARC:
		if not player.use_elementalist_lightning_arc(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_ECHO_CURSE:
		if not player.use_spiritualist_echo_curse(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_SOUL_DRAIN:
		if not player.use_spiritualist_soul_drain(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_SPECTRAL_VEIL:
		if not player.use_spiritualist_spectral_veil(point):
			if not player.can_place_spiritualist_veil(point):
				status_label.text = "Véu Espectral cancelado — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_PROCESSION:
		if not player.use_spiritualist_procession(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_DISSIPATION:
		if not player.use_spiritualist_dissipation(point):
			if not player.can_place_spiritualist_dissipation(point):
				status_label.text = "Rito de Dissipação cancelado — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.ELEMENTALIST_EMBER_PATH:
		if not player.use_elementalist_ember_path(direction):
			if player.elementalist_ember_centers(direction).is_empty():
				status_label.text = "Trilha de Brasas cancelada — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.ELEMENTALIST_TRI_NOVA:
		if not player.use_elementalist_tri_nova():
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.BERSERKER_RUPTURE:
		if not player.use_berserker_rupture(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.BERSERKER_EXECUTION:
		if not player.use_berserker_execution(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.BERSERKER_WOUND_LEAP:
		if not player.use_berserker_wound_leap(direction, enemies):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.BERSERKER_BLOOD_RIFT:
		if not player.use_berserker_blood_rift(direction, enemies):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.BERSERKER_BREATH_STEAL:
		if not player.use_berserker_breath_steal(selected_target):
			_report_skill_failure(skill, selected_target)

func _report_skill_failure(skill: StringName, selected_target: CombatActor = null) -> void:
	var definition := ClassCatalog.skill_definition(skill)
	if definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET and not player.can_target_skill(skill, selected_target):
		status_label.text = "%s cancelada — ALVO INVÁLIDO OU FORA DE ALCANCE" % definition.display_name
	else:
		_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill), skill)

func _select_skill_from_bar(skill: StringName) -> void:
	if get_tree().paused or run_finished or not player.is_alive():
		return
	player.cancel_active_cast()
	var definition := ClassCatalog.skill_definition(skill)
	if definition != null and definition.targeting == SkillDefinition.Targeting.SELF:
		cast_intent.cancel()
		_commit_skill(skill, player.global_position)
		_cancel_aim()
		return
	cast_intent.active_skill = skill
	_update_aim(get_global_mouse_position())

func _update_aim(point: Vector2) -> void:
	var skill := cast_intent.active_skill
	if skill == &"" or get_tree().paused or run_finished:
		battle_indicators.clear_aim()
		if player != null and player.has_active_cast() and not get_tree().paused and not run_finished:
			var cast_definition := ClassCatalog.skill_definition(player.active_cast_skill)
			battle_controls.set_aim_text("Conjurando %s · %.1fs  |  mover / Direito / Esc cancela" % [cast_definition.display_name, player.active_cast_remaining])
			bottom_controls.visible = false
		else:
			battle_controls.set_aim_text("")
			bottom_controls.visible = true
		return
	var definition := ClassCatalog.skill_definition(skill)
	var cooldown := player.skill_cooldown(skill)
	var cost := player.skill_cost(skill)
	var state := _skill_state(cooldown, cost, skill)
	if skill == &"shield_wall" and player.has_shield_stance():
		state = "DESLIGAR"
	var selected_target: CombatActor
	if definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET:
		selected_target = _enemy_at(point)
		if not player.can_target_skill(skill, selected_target):
			selected_target = null
			state = "ALVO INVÁLIDO"
	elif skill == &"teleport" and not player.can_teleport(point):
		state = "DESTINO BLOQUEADO"
	elif skill == &"snare_trap" and not player.can_place_snare_trap(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"explosive_trap" and not player.can_place_explosive_trap(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"foliage_shelter" and not player.can_place_foliage_shelter(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"elementalist_ember_path" and player.elementalist_ember_centers(player.aim_direction(point)).is_empty():
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"ice_wall" and not player.can_place_ice_wall(player.aim_direction(point), enemies):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"elementalist_flame_burst" and not player.can_place_elementalist_flame_burst(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"spiritualist_spectral_veil" and not player.can_place_spiritualist_veil(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"spiritualist_dissipation" and not player.can_place_spiritualist_dissipation(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"defender_anchor" and not navigation.is_walkable(BattleIndicators.defender_clamped_point(player.global_position, point, player.skill_range(skill))):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"defender_wall_advance" and player.defender_wall_advance_destination(player.aim_direction(point)).distance_to(player.global_position) <= PlayerActor.MOVEMENT_EPSILON:
		state = "TRAJETO BLOQUEADO"
	elif skill == &"berserker_wound_leap" and player.berserker_wound_leap_destination(player.aim_direction(point)).distance_to(player.global_position) <= PlayerActor.MOVEMENT_EPSILON:
		state = "TRAJETO BLOQUEADO"
	if _world_pointer_available():
		if skill in [&"defender_counterstroke", &"defender_anchor", &"defender_line_lock", &"defender_wall_advance", &"defender_reprisal_wave"]:
			var advance_endpoint := player.defender_wall_advance_destination(player.aim_direction(point)) if skill == &"defender_wall_advance" else Vector2.INF
			battle_indicators.show_defender_aim(skill, player, point, state == "PRONTO", advance_endpoint, player.skill_range(skill), player.defender_anchor_center if player.has_defender_anchor() else Vector2.INF)
		else:
			battle_indicators.show_aim(skill, player, point, state in ["PRONTO", "DESLIGAR"], selected_target)
	else:
		battle_indicators.clear_aim()
	var action := "Solte a tecla ou clique" if cast_intent.mode == CastIntent.Mode.RELEASE else "Clique para lançar"
	var prepare_time := player.skill_cast_time(skill)
	var prepare := "  |  preparo %.2fs" % prepare_time if prepare_time > 0.0 else ""
	battle_controls.set_aim_text("%s · %s  |  %s%s  |  Direito / Esc cancela" % [definition.display_name, state, action, prepare])
	bottom_controls.visible = false

func _cancel_aim() -> void:
	cast_intent.cancel()
	if battle_indicators != null:
		battle_indicators.clear_aim()
	if battle_controls != null:
		battle_controls.set_aim_text("")
	if bottom_controls != null:
		bottom_controls.visible = player == null or not player.has_active_cast()

func _cancel_casting() -> void:
	if player != null:
		player.cancel_active_cast()
	_cancel_aim()

func _world_pointer_available() -> bool:
	return get_viewport().gui_get_hovered_control() == null

func _clear_hover() -> void:
	if is_instance_valid(_hovered_enemy):
		_hovered_enemy.set_hovered(false)
	_hovered_enemy = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_casting()

func _toggle_settings(open: bool) -> void:
	if open and (get_tree().paused or run_finished):
		return
	_cancel_casting()
	_clear_hover()
	battle_controls.settings_overlay.visible = open
	get_tree().paused = open

func _change_control_preferences(mode: int, smart_lock: bool) -> void:
	_cancel_casting()
	_clear_hover()
	cast_intent.set_mode(mode)
	control_preferences.cast_mode = mode
	control_preferences.smart_lock = smart_lock
	if control_preferences.save_settings() != OK:
		status_label.text = "Controles aplicados; não foi possível salvar a preferência."

func _spawn_encounter(index: int) -> void:
	encounter_index = index
	encounter_active = true
	_credited_kills.clear()
	_reward_retry_pending = false
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
		_spawn_enemy(entry["type"], entry["position"])
	status_label.text = "Encontro %d/2 — elimine todos os inimigos" % index

func _spawn_enemy(enemy_type: StringName, spawn_position: Vector2) -> EnemyActor:
	var enemy := EnemyActor.new()
	enemy.configure(enemy_type, navigation, player)
	enemy.global_position = spawn_position
	enemy.attack_requested.connect(_on_enemy_attack_requested)
	enemy.actor_died.connect(_on_enemy_died)
	enemy.health.damage_applied.connect(_on_enemy_damage_resolved)
	enemy.damage_number.connect(_show_damage_number)
	enemy.attack_missed.connect(_show_miss)
	enemy.status_damage_requested.connect(_on_attack_requested)
	add_child(enemy)
	enemies.append(enemy)
	return enemy

func _spawn_training_boss() -> void:
	encounter_active = true
	encounter_index = 1
	training_boss = _spawn_enemy(&"chaser", Vector2(1370, 450))
	training_boss.actor_name = "Guardião de Treino"
	training_boss.collision_radius = 33.0
	training_boss.sprite_visual_scale = 1.8
	training_boss.scenario_damage_multiplier = TRAINING_BOSS_DAMAGE_MULTIPLIER
	training_boss.configure_hard_control_profile(true)
	training_boss.health.max_hp = TRAINING_BOSS_HP
	training_boss.health.current_hp = TRAINING_BOSS_HP
	training_boss.queue_redraw()
	status_label.text = "Treino isolado · Guardião 50.000 HP · reforços a cada 8 s"

func _advance_training_adds(delta: float) -> void:
	_training_add_elapsed += delta
	if _training_add_elapsed < TRAINING_ADD_INTERVAL:
		return
	_training_add_elapsed = fmod(_training_add_elapsed, TRAINING_ADD_INTERVAL)
	_spawn_training_add_wave()

func _spawn_training_add_wave() -> void:
	if not training_mode or run_finished or training_boss == null or not training_boss.is_alive() or not player.is_alive():
		return
	var living_adds := enemies.size() - 1
	var spawn_count := mini(2, TRAINING_ADD_CAP - living_adds)
	for spawn_index: int in range(spawn_count):
		var spawn_position := _training_add_position()
		if spawn_position == Vector2.INF:
			break
		var enemy_type: StringName = &"chaser" if (_training_wave_index + spawn_index) % 2 == 0 else &"archer"
		var enemy := _spawn_enemy(enemy_type, spawn_position)
		enemy.actor_name = "Reforço de Treino"
		enemy.scenario_damage_multiplier = TRAINING_ADD_DAMAGE_MULTIPLIER
		enemy.health.max_hp = TRAINING_ADD_HP
		enemy.health.current_hp = TRAINING_ADD_HP
		enemy.queue_redraw()
	_training_wave_index += 1

func _training_add_position() -> Vector2:
	for offset: Vector2 in TRAINING_ADD_OFFSETS:
		var candidate := training_boss.global_position + offset
		if not navigation.is_walkable(candidate) or candidate.distance_to(player.global_position) < 130.0:
			continue
		var occupied := false
		for enemy: CombatActor in enemies:
			if is_instance_valid(enemy) and enemy.is_alive() and candidate.distance_to(enemy.global_position) < 95.0:
				occupied = true
				break
		if not occupied:
			return candidate
	return Vector2.INF

func _on_attack_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor != null and target_actor.is_alive():
		target_actor.apply_damage(request, rng)

func _on_defender_hit_requested(request: DamageRequest, target_actor: CombatActor, root_duration: float, push_direction: Vector2) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if not bool(result.get("can_trigger_effects", false)) or float(result.get("actual_damage", 0.0)) <= 0.0 or not target_actor.is_alive():
		return
	if root_duration > 0.0:
		target_actor.apply_root(root_duration, &"physical")
	if not push_direction.is_zero_approx() and target_actor is EnemyActor:
		(target_actor as EnemyActor).apply_defender_push(push_direction, PlayerActor.DEFENDER_PUSH_DISTANCE)

func _on_berserker_rift_hit_requested(request: DamageRequest, target_actor: CombatActor, bleed_request: DamageRequest) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if bool(result.get("can_trigger_effects", false)) and float(result.get("actual_damage", 0.0)) > 0.0 and target_actor.is_alive():
		target_actor.apply_bleed(bleed_request, PlayerActor.BERSERKER_RIFT_BLEED_DURATION)

func _on_berserker_breath_hit_requested(request: DamageRequest, target_actor: CombatActor, heal_fraction: float, marked_before_hit: bool) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if marked_before_hit and target_actor.is_alive() and player != null and is_instance_valid(player):
		player.heal_from_berserker_breath_steal(result, heal_fraction)

func _sync_berserker_wound_visuals() -> void:
	if player == null or not is_instance_valid(player):
		return
	for enemy: CombatActor in enemies:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var enemy_id := enemy.get_instance_id()
		enemy.set_berserker_wound_visual(player.berserker_wound_stacks(enemy_id), player.berserker_wound_remaining(enemy_id))

func _sync_defender_anchor() -> void:
	var active := player != null and is_instance_valid(player) and player.has_defender_anchor()
	for enemy_id: int in _defender_slowed_enemies.keys():
		var previous: CombatActor = _defender_slowed_enemies[enemy_id]
		if not is_instance_valid(previous) or not active or previous.global_position.distance_to(player.defender_anchor_center) > SkillGeometry.DEFENDER_ANCHOR_RADIUS:
			if is_instance_valid(previous):
				previous.remove_attribute_debuff(AttributeDebuffState.MOVE_SPEED, &"defender_anchor")
			_defender_slowed_enemies.erase(enemy_id)
	if not active:
		return
	for enemy: CombatActor in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive() or enemy.global_position.distance_to(player.defender_anchor_center) > SkillGeometry.DEFENDER_ANCHOR_RADIUS:
			continue
		if not _defender_slowed_enemies.has(enemy.get_instance_id()):
			_defender_slowed_enemies[enemy.get_instance_id()] = enemy
			enemy.apply_slow(PlayerActor.DEFENDER_ANCHOR_SLOW_FRACTION, player.defender_anchor_remaining, &"defender_anchor")

func _on_mage_projectile_requested(skill_id: StringName, request: DamageRequest, target_actor: CombatActor, direction: Vector2, count: int) -> void:
	var definition := ClassCatalog.skill_definition(skill_id)
	for index: int in range(count):
		var projectile := MageProjectile.new()
		var side_offset := direction.orthogonal() * (float(index) - float(count - 1) * 0.5) * 14.0
		var origin := player.global_position + Vector2(0, -18) + side_offset
		var projectile_request := request.copy()
		if skill_id == &"fireball":
			projectile.configure_directional(projectile_request, origin, direction, enemies, navigation, player.skill_projectile_speed(skill_id), player.skill_range(skill_id))
		else:
			var speed := PlayerActor.MAGE_BASIC_SPEED if skill_id == &"basic_attack" else player.skill_projectile_speed(skill_id)
			var max_distance := PlayerActor.MAGE_BASIC_MAX_DISTANCE if skill_id == &"basic_attack" else player.skill_range(skill_id)
			var visual_color := Color("e9d76a") if skill_id == &"lightning" else Color("74c9ff") if skill_id == &"ice_spear" else Color("ff793d")
			projectile.configure_homing(projectile_request, target_actor, origin, navigation, speed, max_distance, visual_color)
			if skill_id == &"basic_attack":
				projectile.homing = false
				projectile.targets = [target_actor]
				projectile.direction = direction
		projectile.hit.connect(_on_mage_projectile_hit)
		add_child(projectile)
		projectile.add_to_group("player_projectiles")

func _on_precision_projectile_requested(skill_id: StringName, request: DamageRequest, _target_actor: CombatActor, direction: Vector2, count: int, hit_limit: int) -> void:
	_spawn_precision_projectiles(skill_id, request, direction, count, hit_limit, _on_precision_projectile_hit)

func _on_discharge_requested(request: DamageRequest, direction: Vector2, bonus_magic_damage: float) -> void:
	var projectile := MageProjectile.new()
	var origin := player.global_position + PlayerProjectile.BODY_OFFSET
	projectile.configure_directional(request.copy(), origin, direction, enemies, navigation, player.skill_projectile_speed(&"electric_discharge"), player.skill_range(&"electric_discharge"), 1, Color("ffe37a"))
	projectile.electrified_bonus_magic_damage = bonus_magic_damage
	projectile.hit.connect(_on_discharge_hit)
	add_child(projectile)
	projectile.add_to_group("player_projectiles")

func _on_discharge_hit(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not target_actor.is_alive():
		return
	var marked := target_actor.is_electrified()
	var result := target_actor.apply_damage(_elementalist_resonance_request(request, target_actor), rng)
	if result.is_empty() or not bool(result["landed"]) or float(result["actual_damage"]) <= 0.0 or not marked:
		return
	target_actor.consume_electrified()
	var stun_roll := rng.randf()
	if target_actor.is_alive() and stun_roll < 0.25:
		target_actor.apply_stun(0.6)

func _spawn_precision_projectiles(skill_id: StringName, request: DamageRequest, direction: Vector2, count: int, hit_limit: int, hit_callback: Callable, visual_color: Color = Color("f6dfad")) -> void:
	for index: int in range(count):
		var projectile := PlayerProjectile.new()
		var side_offset := direction.orthogonal() * (float(index) - float(count - 1) * 0.5) * 14.0
		var origin := player.global_position + PlayerProjectile.BODY_OFFSET + side_offset
		var speed := PlayerActor.ARCHER_BASIC_SPEED if skill_id == &"basic_attack" else player.skill_projectile_speed(skill_id)
		var max_distance := player.archer_basic_projectile_range() if skill_id == &"basic_attack" else player.skill_range(skill_id)
		projectile.configure_directional(request.copy(), origin, direction, enemies, navigation, speed, max_distance, hit_limit, visual_color)
		projectile.hit.connect(hit_callback)
		add_child(projectile)
		projectile.add_to_group("player_projectiles")

func _on_precision_projectile_hit(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor != null and target_actor.is_alive():
		target_actor.apply_damage(request, rng)

func _on_arrow_rain_requested(center: Vector2, request: DamageRequest) -> void:
	var rain := ArrowRain.new()
	rain.configure(center, request, enemies)
	rain.hit.connect(_on_precision_projectile_hit)
	add_child(rain)
	rain.add_to_group("player_effects")

func _on_snare_trap_requested(center: Vector2, root_duration: float) -> void:
	var trap := SnareTrap.new()
	trap.configure_snare(player.get_instance_id(), center, root_duration, enemies, player.trap_armed_duration(SnareTrap.ARMED_DURATION))
	trap_registry.register_trap(trap)

func _on_explosive_trap_requested(center: Vector2, request: DamageRequest) -> void:
	var trap := ExplosiveTrap.new()
	trap.configure_explosive(player.get_instance_id(), center, request, enemies, player.trap_armed_duration(ExplosiveTrap.ARMED_DURATION))
	trap.hit.connect(_on_precision_projectile_hit)
	trap_registry.register_trap(trap)

func _on_slowing_arrow_requested(request: DamageRequest, direction: Vector2, slow_fraction: float, slow_duration: float) -> void:
	var hit_callback := _on_slowing_arrow_hit.bind(slow_fraction, slow_duration)
	_spawn_precision_projectiles(&"slowing_arrow", request, direction, 1, 1, hit_callback, Color("72c9ff"))

func _on_slowing_arrow_hit(request: DamageRequest, target_actor: CombatActor, slow_fraction: float, slow_duration: float) -> void:
	if target_actor == null or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if result.is_empty() or not bool(result["landed"]) or float(result["actual_damage"]) <= 0.0:
		return
	if target_actor.is_alive():
		target_actor.apply_slow(slow_fraction, slow_duration, &"slowing_arrow")

func _on_foliage_shelter_requested(center: Vector2, duration: float) -> void:
	var shelter := FoliageShelter.new()
	add_child(shelter)
	shelter.configure(player, center, duration)
	shelter.add_to_group("player_effects")

func _on_mage_projectile_hit(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(_elementalist_resonance_request(request, target_actor), rng)
	if result.is_empty() or not bool(result["landed"]) or float(result["actual_damage"]) <= 0.0:
		return
	if request.skill_id == &"ice_spear" and target_actor.is_alive():
		target_actor.apply_slow(0.30, 2.0, &"ice_spear")
	elif request.skill_id == &"lightning" and target_actor.is_alive():
		target_actor.apply_electrified(4.0)

func _on_fire_wall_requested(direction: Vector2, burn_request: DamageRequest) -> void:
	var wall := FireWall.new()
	wall.configure(player, direction, burn_request, enemies, player.skill_range(&"fire_wall"))
	add_child(wall)
	wall.add_to_group("player_effects")

func _on_elementalist_flame_burst_requested(center: Vector2, request: DamageRequest) -> void:
	_on_elementalist_area_requested(&"elementalist_flame_burst", center, SkillGeometry.ELEMENTALIST_FLAME_BURST_RADIUS, request, &"fire")

func _on_elementalist_area_requested(skill_id: StringName, center: Vector2, radius: float, request: DamageRequest, element: StringName, marked_bonus: float = 0.0, once_per_target: bool = false, hit_ids: Dictionary = {}) -> void:
	battle_indicators.show_elementalist_pulse(skill_id, center, radius, element)
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if center.distance_to(target_actor.global_position) > radius + target_actor.collision_radius:
			continue
		if not navigation.is_segment_clear(center, target_actor.global_position, 0.0):
			continue
		if once_per_target:
			if hit_ids.has(target_actor.get_instance_id()):
				continue
			hit_ids[target_actor.get_instance_id()] = true
		var target_request := request.copy()
		target_request.target_id = target_actor.get_instance_id()
		_apply_elementalist_hit(target_request, target_actor, element, marked_bonus)

func _on_elementalist_ember_path_requested(centers: Array[Vector2], request: DamageRequest) -> void:
	var requests: Array[DamageRequest] = []
	var elements: Array[StringName] = []
	for _center: Vector2 in centers:
		requests.append(request.copy())
		elements.append(&"fire")
	var sequence := ElementalistSequenceScript.new()
	sequence.pulse_requested.connect(_on_elementalist_area_requested)
	add_child(sequence)
	sequence.add_to_group("player_effects")
	sequence.configure(player, centers, requests, elements, SkillGeometry.ELEMENTALIST_EMBER_PATH_RADIUS, 0.15, true)

func _on_elementalist_tri_nova_requested(center: Vector2, requests: Array[DamageRequest], marked_bonus: float) -> void:
	var centers: Array[Vector2] = [center, center, center]
	var elements: Array[StringName] = [&"fire", &"ice", &"lightning"]
	var sequence := ElementalistSequenceScript.new()
	sequence.pulse_requested.connect(_on_elementalist_area_requested)
	add_child(sequence)
	sequence.add_to_group("player_effects")
	sequence.configure(player, centers, requests, elements, SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS, 0.25, false, marked_bonus)

func _apply_elementalist_hit(request: DamageRequest, target_actor: CombatActor, element: StringName, marked_bonus: float = 0.0) -> Dictionary:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return {}
	var marked := element == &"lightning" and target_actor.is_electrified()
	var resolved_request := _elementalist_resonance_request(request, target_actor)
	resolved_request.target_id = target_actor.get_instance_id()
	if marked:
		resolved_request.magic_damage += marked_bonus
	var result := target_actor.apply_damage(resolved_request, rng)
	if float(result.get("actual_damage", 0.0)) <= 0.0:
		return result
	if element == &"ice" and target_actor.is_alive():
		target_actor.apply_slow(0.40, 2.5, request.skill_id)
	elif element == &"lightning":
		if marked:
			target_actor.consume_electrified()
			var stun_roll := rng.randf()
			if target_actor.is_alive() and stun_roll < 0.25:
				target_actor.apply_stun(0.6)
		elif target_actor.is_alive():
			target_actor.apply_electrified(4.0)
	return result

func _elementalist_resonance_request(request: DamageRequest, target_actor: CombatActor) -> DamageRequest:
	var resolved := request.copy()
	if not request.is_secondary and request.source_id == player.get_instance_id() and request.prismatic_resonance_damage > 0.0 and player.elementalist_resonance_ready(target_actor.get_instance_id(), request.skill_id):
		resolved.magic_damage += request.prismatic_resonance_damage
	return resolved

func _on_elementalist_lightning_arc_requested(request: DamageRequest, target_actor: CombatActor, jump_damage: float, marked_bonus: float) -> void:
	var visited: Array[int] = []
	var current := target_actor
	var visual_origin := player.global_position + Vector2(0, -24)
	for index: int in range(3):
		if current == null or not is_instance_valid(current) or not current.is_alive():
			break
		visited.append(current.get_instance_id())
		var center := current.global_position
		battle_indicators.show_elementalist_arc_link(visual_origin, center + Vector2(0, -18))
		battle_indicators.show_elementalist_pulse(&"elementalist_lightning_arc", center, 30.0, &"lightning")
		var hit_request := request.copy()
		if index > 0:
			hit_request.magic_damage = jump_damage
			hit_request.is_secondary = true
		var result := _apply_elementalist_hit(hit_request, current, &"lightning", marked_bonus)
		if float(result.get("actual_damage", 0.0)) <= 0.0:
			break
		visual_origin = center + Vector2(0, -18)
		current = _elementalist_chain_target(center, visited)

func _elementalist_chain_target(origin: Vector2, visited: Array[int]) -> CombatActor:
	var chosen: CombatActor
	var nearest := INF
	for enemy: CombatActor in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive() or visited.has(enemy.get_instance_id()):
			continue
		var distance := origin.distance_to(enemy.global_position)
		if distance > SkillGeometry.ELEMENTALIST_LIGHTNING_CHAIN_RANGE or not navigation.is_segment_clear(origin, enemy.global_position, 0.0):
			continue
		if distance < nearest or (is_equal_approx(distance, nearest) and chosen != null and enemy.get_instance_id() < chosen.get_instance_id()):
			chosen = enemy
			nearest = distance
	return chosen

func _on_lightning_wall_requested(direction: Vector2, request: DamageRequest) -> void:
	var wall := LightningWall.new()
	wall.configure(player, direction, request, enemies, player.skill_range(&"lightning_wall"))
	wall.crossed.connect(_on_lightning_wall_crossed)
	add_child(wall)
	wall.add_to_group("player_effects")

func _on_lightning_wall_crossed(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if not result.is_empty() and bool(result["landed"]) and float(result["actual_damage"]) > 0.0 and target_actor.is_alive():
		target_actor.apply_electrified(4.0)

func _on_soul_impact_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var sequence := SoulImpactSequence.new()
	sequence.configure(request, target_actor)
	sequence.impact.connect(_on_attack_requested)
	add_child(sequence)
	sequence.add_to_group("player_effects")

func _on_spiritualist_echo_curse_requested(request: DamageRequest, target_actor: CombatActor, echo_power: float) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if bool(result.get("can_trigger_effects", false)) and target_actor.is_alive():
		spiritualist_echo_state.mark(target_actor.get_instance_id(), echo_power)
		if battle_indicators != null:
			battle_indicators.show_spiritualist_event(&"sigil", target_actor.global_position + Vector2(0, -22))
		_show_spiritualist_feedback(target_actor, "AMALDIÇOADO", Color("e6d9f2"))

func _apply_spiritualist_echo(echo: Dictionary) -> void:
	var target_actor := instance_from_id(int(echo["target_id"])) as CombatActor
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var request := player.make_spiritualist_echo_request(target_actor, float(echo["magic_damage"]))
	_spiritualist_echo_number_target_id = target_actor.get_instance_id()
	var result := target_actor.apply_damage(request, rng)
	_spiritualist_echo_number_target_id = 0
	if float(result.get("actual_damage", 0.0)) > 0.0 and battle_indicators != null:
		battle_indicators.show_spiritualist_event(&"echo_hit", target_actor.global_position + Vector2(0, -18))
	elif float(result.get("absorbed_damage", 0.0)) > 0.0 and float(result.get("actual_damage", 0.0)) <= 0.0:
		_show_spiritualist_feedback(target_actor, "ABSORVIDO", Color("b9cbd3"))

func _sync_spiritualist_combat_state(marks_before: Array = []) -> void:
	if battle_indicators == null or player.run_state == null or player.run_state.build_snapshot.evolution_id != &"spiritualist":
		return
	var focus := _focused_spiritualist_target()
	for target_id: int in marks_before:
		if spiritualist_echo_state.marks.has(target_id):
			continue
		var target := instance_from_id(target_id) as CombatActor
		if target != null and is_instance_valid(target) and target == focus and target.is_alive():
			battle_indicators.show_spiritualist_event(&"expire", target.global_position + Vector2(0, -37))
			_show_spiritualist_feedback(target, "MALDIÇÃO EXPIROU", Color("b9cbd3"))
	var weakened: Dictionary[int, Dictionary] = {}
	for enemy: CombatActor in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var state := enemy.attribute_debuffs.effective_state(AttributeDebuffState.DAMAGE_DEALT)
		if float(state["fraction"]) > 0.0:
			weakened[enemy.get_instance_id()] = state
	battle_indicators.sync_spiritualist_combat_state(spiritualist_echo_state.marks, spiritualist_echo_state.pending, weakened)

func _focused_spiritualist_target() -> CombatActor:
	if _selected_enemy != null and is_instance_valid(_selected_enemy) and _selected_enemy.is_alive():
		return _selected_enemy
	if _hovered_enemy != null and is_instance_valid(_hovered_enemy) and _hovered_enemy.is_alive():
		return _hovered_enemy
	return null

func _on_spiritualist_drain_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	spiritualist_drain_state.start(target_actor, player.global_position, request)
	if battle_indicators != null and spiritualist_drain_state.active:
		battle_indicators.sync_spiritualist_drain(player.get_instance_id(), spiritualist_drain_state.target_id)

func _advance_spiritualist_drain(delta: float) -> void:
	if not spiritualist_drain_state.active:
		return
	if not player.is_alive() or player.global_position.distance_to(spiritualist_drain_state.origin) > PlayerActor.MOVEMENT_EPSILON or player.is_stunned() or player.is_feared() or player.is_rooted():
		_cancel_spiritualist_drain()
		return
	var target_actor := instance_from_id(spiritualist_drain_state.target_id) as CombatActor
	if target_actor == null or not is_instance_valid(target_actor) or not player.can_target_skill(&"spiritualist_soul_drain", target_actor):
		_cancel_spiritualist_drain()
		return
	for request: DamageRequest in spiritualist_drain_state.advance(delta):
		if not spiritualist_drain_state.active or not player.can_target_skill(&"spiritualist_soul_drain", target_actor):
			_cancel_spiritualist_drain()
			return
		var healed_before := spiritualist_drain_state.healed_total
		var channel_completed := spiritualist_drain_state.resolve_tick()
		if channel_completed:
			player.grant_spiritualist_focus()
		var result := target_actor.apply_damage(request, rng)
		var healed := player.heal_from_spiritualist_drain(result, healed_before)
		spiritualist_drain_state.healed_total = healed_before + healed
		if healed > 0.0:
			_show_spiritualist_feedback(player, "+%d HP" % ceili(healed), Color("9ce6c7"))
		if battle_indicators != null and float(result.get("actual_damage", 0.0)) > 0.0:
			battle_indicators.show_spiritualist_return_wisp(target_actor.global_position + Vector2(0, -18), player.get_instance_id(), &"drain")
		if not target_actor.is_alive():
			_cancel_spiritualist_drain()
			return
	if not spiritualist_drain_state.active and battle_indicators != null:
		battle_indicators.sync_spiritualist_drain(0, 0)

func _cancel_spiritualist_drain() -> void:
	var was_active := spiritualist_drain_state.active
	spiritualist_drain_state.cancel()
	if was_active and player != null and is_instance_valid(player) and player.is_alive() and encounter_active and not run_finished:
		_spiritualist_channel_notice_remaining = 1.1
	if was_active and player != null and is_instance_valid(player) and player.character_animation != null and player.character_animation.state.action == &"cast":
		player.presentation_action.emit(&"cast_cancel", Vector2.ZERO, 0.0)
	if battle_indicators != null:
		battle_indicators.sync_spiritualist_drain(0, 0)
		if was_active:
			battle_indicators.clear_spiritualist_drain_wisps()

func _on_player_damage_resolved(result: Dictionary) -> void:
	if float(result.get("actual_damage", 0.0)) > 0.0:
		_cancel_spiritualist_drain()

func _on_spiritualist_focus_event(kind: StringName) -> void:
	if battle_indicators != null:
		battle_indicators.show_spiritualist_event(&"focus_grant" if kind == &"grant" else &"focus_consume", player.global_position + Vector2(0, -28))
	_show_spiritualist_feedback(player, "FOCO PRONTO" if kind == &"grant" else "FOCO CONSUMIDO", Color("e9d9f5"))

func _on_spiritualist_veil_requested(center: Vector2, duration: float, weaken_fraction: float) -> void:
	_clear_spiritualist_veil()
	spiritualist_veil_state.start(center, duration)
	spiritualist_veil_fraction = weaken_fraction
	if battle_indicators != null:
		battle_indicators.sync_spiritualist_veil(center, duration)
	_advance_spiritualist_veil(0.0)

func _advance_spiritualist_veil(delta: float) -> void:
	if not spiritualist_veil_state.active:
		return
	if spiritualist_veil_state.advance(delta):
		_clear_spiritualist_veil()
		return
	var current_members: Dictionary[int, CombatActor] = {}
	for enemy: CombatActor in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if not spiritualist_veil_state.contains(enemy.global_position) or not navigation.is_segment_clear(spiritualist_veil_state.center, enemy.global_position, 0.0):
			continue
		enemy.apply_weaken(spiritualist_veil_fraction, 0.20, &"spiritualist_spectral_veil")
		current_members[enemy.get_instance_id()] = enemy
	for target_id: int in _spiritualist_veil_members.keys():
		if current_members.has(target_id):
			continue
		var previous := _spiritualist_veil_members[target_id]
		if previous != null and is_instance_valid(previous):
			previous.remove_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil")
	_spiritualist_veil_members = current_members
	if battle_indicators != null:
		battle_indicators.sync_spiritualist_veil(spiritualist_veil_state.center, spiritualist_veil_state.remaining)

func _clear_spiritualist_veil() -> void:
	for enemy: CombatActor in _spiritualist_veil_members.values():
		if enemy != null and is_instance_valid(enemy):
			enemy.remove_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil")
	_spiritualist_veil_members.clear()
	spiritualist_veil_state.clear()
	spiritualist_veil_fraction = 0.0
	if battle_indicators != null:
		battle_indicators.sync_spiritualist_veil(Vector2.INF, 0.0)

func _on_spiritualist_procession_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	spiritualist_procession_state.start(player.global_position + Vector2(0, -24), target_actor, request)
	_advance_spiritualist_procession(0.0)

func _advance_spiritualist_procession(delta: float) -> void:
	if not spiritualist_procession_state.active:
		return
	var target_actor := instance_from_id(spiritualist_procession_state.target_id) as CombatActor
	if target_actor == null or not is_instance_valid(target_actor) or not player.can_target_skill(&"spiritualist_procession", target_actor):
		_cancel_spiritualist_procession()
		return
	for event: Dictionary in spiritualist_procession_state.advance(delta):
		if not spiritualist_procession_state.active or not player.can_target_skill(&"spiritualist_procession", target_actor):
			_cancel_spiritualist_procession()
			return
		if event["kind"] == &"departure":
			if battle_indicators != null:
				battle_indicators.show_spiritualist_procession_wisp(spiritualist_procession_state.source, target_actor.get_instance_id())
			continue
		var request: DamageRequest = event["request"]
		var result := target_actor.apply_damage(request, rng)
		if battle_indicators != null and float(result.get("actual_damage", 0.0)) > 0.0:
			battle_indicators.show_spiritualist_event(&"burst", target_actor.global_position + Vector2(0, -18))
		if not target_actor.is_alive():
			_cancel_spiritualist_procession()
			return
	if spiritualist_procession_state.all_impacts_issued():
		_cancel_spiritualist_procession()

func _cancel_spiritualist_procession() -> void:
	spiritualist_procession_state.cancel()
	if battle_indicators != null:
		battle_indicators.clear_spiritualist_procession_wisps()

func _on_spiritualist_dissipation_requested(center: Vector2, request: DamageRequest, marked_bonus: float, focus_bonus: float) -> void:
	if battle_indicators != null:
		battle_indicators.show_spiritualist_event(&"ritual", center)
	var target_index := 0
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if center.distance_to(target_actor.global_position) > SkillGeometry.SPIRITUALIST_DISSIPATION_RADIUS + target_actor.collision_radius:
			continue
		if not navigation.is_segment_clear(center, target_actor.global_position, 0.0):
			continue
		var target_id := target_actor.get_instance_id()
		var was_marked := spiritualist_echo_state.has_mark(target_id)
		var target_request := request.copy()
		target_request.target_id = target_id
		if target_index == 0:
			target_request.magic_damage += focus_bonus
		if was_marked:
			target_request.magic_damage += marked_bonus
		target_index += 1
		var result := target_actor.apply_damage(target_request, rng)
		if float(result.get("actual_damage", 0.0)) <= 0.0:
			continue
		if was_marked:
			if spiritualist_echo_state.consume_mark(target_id):
				if battle_indicators != null:
					battle_indicators.show_spiritualist_event(&"break", target_actor.global_position + Vector2(0, -22))
				_show_spiritualist_feedback(target_actor, "MARCA DISSIPADA", Color("f5dacf"))
		if target_actor.is_alive():
			target_actor.apply_weaken(0.20, 2.0, &"spiritualist_dissipation")

func _on_haunt_requested(origin: Vector2, direction: Vector2, cone_range: float, request: DamageRequest) -> void:
	var visual := HauntConeVisual.new()
	visual.configure(origin, direction, cone_range, PlayerActor.HAUNT_HALF_ANGLE)
	add_child(visual)
	visual.add_to_group("player_effects")
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if not SkillGeometry.cone_contains(target_actor.global_position - origin, direction, cone_range, PlayerActor.HAUNT_HALF_ANGLE):
			continue
		var impact := request.copy()
		impact.target_id = target_actor.get_instance_id()
		var result := target_actor.apply_damage(impact, rng)
		if not result.is_empty() and bool(result["landed"]) and float(result["actual_damage"]) > 0.0 and target_actor.is_alive():
			target_actor.apply_fear(PlayerActor.HAUNT_FEAR_DURATION)
			target_actor.apply_weaken(PlayerActor.HAUNT_WEAKEN_FRACTION, PlayerActor.HAUNT_WEAKEN_DURATION, &"haunt")

func _on_phantom_barrier_requested(direction: Vector2, placement_range: float, capacity: int) -> void:
	var barrier := PhantomBarrier.new()
	barrier.configure(player, direction, enemies, placement_range, capacity)
	add_child(barrier)
	barrier.add_to_group("player_effects")

func _on_ice_wall_requested(wall: IceWallScript) -> void:
	add_child(wall)
	wall.add_to_group("player_effects")

func _on_provoke_requested(target_actor: CombatActor, duration: float) -> void:
	var enemy := target_actor as EnemyActor
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	enemy.apply_taunt(duration)
	enemy.apply_attribute_debuff(AttributeDebuffState.PHYSICAL_DEFENSE, &"provoke", PlayerActor.PROVOKE_DEFENSE_REDUCTION, PlayerActor.PROVOKE_DEBUFF_DURATION)
	enemy.apply_attribute_debuff(AttributeDebuffState.FLEE, &"provoke", PlayerActor.PROVOKE_FLEE_REDUCTION, PlayerActor.PROVOKE_DEBUFF_DURATION)

func _on_piercing_shout_requested(origin: Vector2, request: DamageRequest, radius: float, duration: float) -> void:
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive() or origin.distance_to(target_actor.global_position) > radius:
			continue
		var impact := request.copy()
		impact.target_id = target_actor.get_instance_id()
		var result := target_actor.apply_damage(impact, rng)
		if result.is_empty() or not bool(result["landed"]) or float(result["actual_damage"]) <= 0.0 or not target_actor.is_alive():
			continue
		target_actor.apply_attribute_debuff(AttributeDebuffState.MOVE_SPEED, &"piercing_shout", PlayerActor.PIERCING_SHOUT_SLOW_FRACTION, duration)
		target_actor.apply_attribute_debuff(AttributeDebuffState.ATTACK_SPEED, &"piercing_shout", PlayerActor.PIERCING_SHOUT_ASPD_FRACTION, duration)

func _on_brutal_strike_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if not result.is_empty() and bool(result["landed"]) and float(result["actual_damage"]) > 0.0 and target_actor.is_alive():
		target_actor.apply_attribute_debuff(AttributeDebuffState.PHYSICAL_DEFENSE, &"brutal_strike", PlayerActor.BRUTAL_STRIKE_DEFENSE_REDUCTION, PlayerActor.BRUTAL_STRIKE_DEBUFF_DURATION)

func _on_terrifying_shout_requested(origin: Vector2, radius: float, fear_duration: float) -> void:
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive() or origin.distance_to(target_actor.global_position) > radius:
			continue
		target_actor.apply_fear(fear_duration)
		target_actor.apply_attribute_debuff(AttributeDebuffState.DAMAGE_RECEIVED, &"terrifying_shout", PlayerActor.TERRIFYING_SHOUT_DAMAGE_RECEIVED_INCREASE, PlayerActor.TERRIFYING_SHOUT_DEBUFF_DURATION)

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
	_defender_slowed_enemies.erase(actor.get_instance_id())
	player.remove_berserker_wound(actor.get_instance_id())
	player.remove_elementalist_target(actor.get_instance_id())
	spiritualist_echo_state.remove_target(actor.get_instance_id())
	if spiritualist_drain_state.target_id == actor.get_instance_id():
		_cancel_spiritualist_drain()
	if spiritualist_procession_state.target_id == actor.get_instance_id():
		_cancel_spiritualist_procession()
	_spiritualist_veil_members.erase(actor.get_instance_id())
	_spawn_death_visual(actor)
	if actor == _hovered_enemy:
		_hovered_enemy = null
	if actor == _selected_enemy:
		_selected_enemy = null
	enemies.erase(actor)
	actor.queue_free()
	if training_mode:
		if actor == training_boss:
			training_boss = null
			encounter_active = false
			_show_result(true)
		return
	if not enemies.is_empty():
		return
	encounter_active = false
	player.clear_shield_stance()
	player.clear_perseverance()
	player.clear_fury()
	_clear_defender_runtime()
	player.clear_berserker_state()
	player.clear_elementalist_state()
	player.clear_spiritualist_state()
	spiritualist_echo_state.clear()
	_cancel_spiritualist_drain()
	_clear_spiritualist_veil()
	_cancel_spiritualist_procession()
	battle_indicators.clear_spiritualist_visuals()
	_clear_spiritualist_feedback()
	trap_registry.clear_all(&"encounter_end")
	for group_name: StringName in [&"enemy_projectiles", &"player_projectiles", &"player_effects"]:
		for runtime_node: Node in get_tree().get_nodes_in_group(group_name):
			if runtime_node is FoliageShelter:
				(runtime_node as FoliageShelter).expire(&"encounter_end")
			elif runtime_node is IceWallScript:
				(runtime_node as IceWallScript).expire()
			else:
				runtime_node.queue_free()
	reward = RewardPickup.new()
	reward.global_position = Vector2(880, 500)
	reward.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(reward)
	status_label.text = "Encontro concluído — toque no cristal dourado"

func _on_enemy_damage_resolved(result: Dictionary) -> void:
	if player == null or not is_instance_valid(player) or not player.is_alive() or int(result.get("source_id", 0)) != player.get_instance_id():
		return
	player.record_berserker_damage(result)
	var echo_triggered := spiritualist_echo_state.record_hit(result, player.spiritualist_magic_attack())
	if echo_triggered:
		if battle_indicators != null:
			var mark_target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
			if mark_target != null and is_instance_valid(mark_target):
				battle_indicators.show_spiritualist_event(&"echo_ready", mark_target.global_position + Vector2(0, -37))
				_show_spiritualist_feedback(mark_target, "ECO PREPARADO", Color("d9eafa"))
		var recovered := player.recover_spiritualist_echo_sp(int(result.get("emission_id", 0)))
		if recovered > 0.0:
			_show_spiritualist_feedback(player, "+%d SP" % ceili(recovered), Color("9fcdf2"))
		if recovered > 0.0 and battle_indicators != null:
			var recovery_target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
			var source := recovery_target.global_position + Vector2(0, -18) if recovery_target != null and is_instance_valid(recovery_target) else player.global_position + Vector2(0, -42)
			battle_indicators.show_spiritualist_return_wisp(source, player.get_instance_id(), &"recovery")
	var previous_sp := player.current_sp
	var resonance_feedback := bool(result.get("can_trigger_effects", false)) and float(result.get("actual_damage", 0.0)) > 0.0 and player.elementalist_resonance_ready(int(result.get("target_id", 0)), StringName(result.get("skill_id", &"")))
	player.record_elementalist_damage(result)
	if battle_indicators != null:
		if player.current_sp > previous_sp:
			battle_indicators.show_elementalist_prism(player.global_position, &"elementalist_prismatic_focus")
		if resonance_feedback:
			var resonance_target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
			if resonance_target != null and is_instance_valid(resonance_target):
				battle_indicators.show_elementalist_prism(resonance_target.global_position, &"elementalist_prismatic_resonance")
	if player.run_state != null and player.run_state.uses_persistent_build() and player.run_state.build_snapshot.evolution_id == &"defender" and &"defender_watch" in player.run_state.build_snapshot.passive_slots and bool(result.get("can_trigger_effects", false)) and float(result.get("actual_damage", 0.0)) > 0.0 and StringName(result.get("skill_id", &"")) in DEFENDER_WATCH_DIRECT_MELEE_IDS:
		var watch_rank := ClassCatalog.skill_definition(&"defender_watch").rank_definition(player.skill_rank(&"defender_watch"))
		var watch_target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
		if watch_rank != null and watch_target != null and is_instance_valid(watch_target) and watch_target.is_alive():
			watch_target.apply_weaken(watch_rank.power, PlayerActor.DEFENDER_WATCH_DURATION, &"defender_watch")
	if not bool(result.get("killed", false)):
		return
	var victim_id := int(result.get("target_id", 0))
	if victim_id <= 0 or _credited_kills.has(victim_id):
		return
	_credited_kills[victim_id] = true
	player.heal_from_kill()

func _collect_reward() -> Dictionary:
	if reward == null:
		return {"ok": false, "error_code": &"reward_unavailable"}
	var progression_result := _grant_persistent_encounter_reward()
	if not progression_result.get("ok", false):
		_reward_retry_pending = true
		status_label.text = "%s Pressione E para tentar novamente ou use Personagem para sair; a coleta ainda não foi consumida." % _reward_error_text(StringName(progression_result.get("error_code", &"unknown")))
		return progression_result
	reward.queue_free()
	reward = null
	run_state.queue_choice()
	augment_button.disabled = false
	if progression_result.get("persistent", false):
		var applied: Dictionary = progression_result.get("applied_reward", {})
		if applied.is_empty():
			status_label.text = "XP persistente já salvo — abra a escolha com E"
		else:
			status_label.text = "XP salvo: +%d base · +%d job — abra a escolha com E" % [applied["base_xp"], applied["job_xp"]]
	else:
		status_label.text = "Recompensa coletada — abra a escolha com E"
	return progression_result

func _grant_persistent_encounter_reward() -> Dictionary:
	if not _persistent_run_active():
		return {"ok": true, "persistent": false}
	var profile := persistent_facade.current_profile()
	if profile == null:
		return {"ok": false, "error_code": &"profile_unavailable"}
	var reward_id := ProfileRewardResolver.pilot_encounter_reward_id(encounter_index)
	if reward_id.is_empty():
		return {"ok": false, "error_code": &"invalid_reward"}
	var request_id := "reward-%s-%d" % [run_state.run_id.md5_text(), encounter_index]
	var result := persistent_facade.grant_reward(request_id, profile.revision, run_state.run_id, encounter_index, reward_id)
	if result.get("ok", false):
		result["persistent"] = true
	return result

func _reward_error_text(error_code: StringName) -> String:
	match error_code:
		&"save_in_progress": return "O perfil ainda está sendo salvo."
		&"stale_revision": return "O perfil mudou antes desta coleta."
		&"recovery_required": return "Há uma gravação pendente que precisa ser recuperada."
		&"save_failed": return "Não foi possível salvar o XP."
		&"result_uncertain": return "Não foi possível confirmar se o XP foi salvo."
		&"profile_unavailable": return "O perfil não está disponível."
		&"invalid_reward", &"invalid_reward_sequence", &"invalid_catalog": return "A recompensa persistente desta etapa está inválida."
		_: return "A recompensa persistente falhou (%s)." % error_code

func _open_augment_menu() -> void:
	if run_finished or get_tree().paused:
		return
	var offer := run_state.build_offer(encounter_active, rng)
	if offer.is_empty():
		return
	_cancel_casting()
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

func _spawn_death_visual(actor: CombatActor, after_run: bool = false) -> void:
	if actor.character_animation == null:
		return
	var visual := ActorDeathVisual.new()
	visual.animation = actor.character_animation.death_copy()
	visual.position = actor.position
	visual.scale = Vector2.ONE * actor.sprite_visual_scale
	actor.get_parent().add_child(visual)
	# Only the terminal cosmetic continues behind the paused result overlay.
	if after_run:
		visual.process_mode = Node.PROCESS_MODE_ALWAYS
	actor.hide()

func _on_player_died(_actor: CombatActor) -> void:
	_spawn_death_visual(_actor, true)
	encounter_active = false
	_show_result(false)

func _show_result(victory: bool) -> void:
	_cancel_casting()
	_clear_hover()
	if trap_registry != null:
		trap_registry.clear_all(&"run_end")
	player.clear_shield_stance()
	player.clear_perseverance()
	player.clear_fury()
	_clear_defender_runtime()
	player.clear_berserker_state()
	player.clear_elementalist_state()
	player.clear_spiritualist_state()
	spiritualist_echo_state.clear()
	_cancel_spiritualist_drain()
	_clear_spiritualist_veil()
	_cancel_spiritualist_procession()
	battle_indicators.clear_spiritualist_visuals()
	_clear_spiritualist_feedback()
	player.clear_foliage_shelters()
	for shelter: Node in get_tree().get_nodes_in_group("foliage_shelters"):
		if shelter is FoliageShelter:
			(shelter as FoliageShelter).expire(&"run_end")
	for effect: Node in get_tree().get_nodes_in_group("player_effects"):
		if effect is IceWallScript:
			(effect as IceWallScript).expire()
		elif effect is LightningWall or effect is SoulImpactSequence or effect is HauntConeVisual or effect is PhantomBarrier or effect is ElementalistSequenceScript:
			effect.queue_free()
	run_finished = true
	_training_add_elapsed = 0.0
	_terminal_outcome = &"completed" if victory else &"death"
	result_title.text = ("Treino concluído!" if training_mode else "Arena concluída!") if victory else "Você caiu em combate"
	var next_step := "Pressione R ou use o botão para voltar ao menu e iniciar outra run." if _persistent_run_active() else "Pressione R ou use o botão para reiniciar."
	restart_button.text = "Voltar ao menu (R)" if _persistent_run_active() else "Reiniciar arena (R)"
	if training_mode:
		result_body.text = ("O Guardião caiu.\n" if victory else "Treino encerrado.\n") + "Nenhum XP ou recompensa foi salvo.\n" + next_step
	else:
		result_body.text = ("Os dois encontros do Marco 1 foram vencidos.\n" if victory else "A run terminou e todo o estado temporário será descartado.\n") + next_step
	result_overlay.visible = true
	get_tree().paused = true

func _clear_defender_runtime() -> void:
	for enemy: CombatActor in _defender_slowed_enemies.values():
		if is_instance_valid(enemy):
			enemy.remove_attribute_debuff(AttributeDebuffState.MOVE_SPEED, &"defender_anchor")
	_defender_slowed_enemies.clear()
	if player != null and is_instance_valid(player):
		player.clear_defender_state()
	if battle_indicators != null and is_instance_valid(battle_indicators):
		battle_indicators.clear_defender_anchor()

func _restart_run() -> void:
	if _persistent_run_active():
		_return_to_character_menu()
		return
	if training_mode:
		pending_run_state = RunState.from_build("", run_state.build_snapshot)
		pending_training_mode = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func _return_to_character_menu() -> void:
	var closed := _close_persistent_run(_terminal_outcome)
	if not closed["ok"]:
		_report_run_close_failure(closed)
		return
	get_tree().paused = false
	pending_run_state = null
	pending_run_facade = null
	pending_training_mode = false
	get_tree().change_scene_to_file("res://scenes/character_menu.tscn")

func _persistent_run_active() -> bool:
	return persistent_facade != null and run_state != null and not run_state.run_id.is_empty()

func _close_persistent_run(outcome: StringName) -> Dictionary:
	if not _persistent_run_active():
		return {"ok": true, "already_closed": true}
	var profile := persistent_facade.current_profile()
	if profile == null:
		return {"ok": false, "error_code": &"profile_unavailable"}
	if profile.reward_session == null:
		persistent_facade = null
		return {"ok": true, "already_closed": true}
	_close_request_serial += 1
	var result := persistent_facade.end_run("run-close-%d" % _close_request_serial, profile.revision, run_state.run_id, outcome)
	if result["ok"]:
		persistent_facade = null
	return result

func _report_run_close_failure(result: Dictionary) -> void:
	var detail := _run_close_error_text(StringName(result.get("error_code", &"unknown")))
	status_label.text = detail
	if result_overlay.visible:
		result_body.text = "A run continua aberta. %s\nTente novamente para voltar ao menu." % detail
	else:
		class_label.text = "Não foi possível encerrar esta run.\n%s\nTente novamente ou corrija o perfil antes de sair." % detail
	get_tree().paused = true

func _run_close_error_text(error_code: StringName) -> String:
	match error_code:
		&"save_in_progress": return "O perfil ainda está sendo salvo."
		&"stale_revision": return "O perfil foi atualizado; tente novamente."
		&"recovery_required": return "Há uma gravação pendente que precisa ser recuperada."
		&"save_failed": return "Não foi possível gravar o encerramento da run."
		&"profile_unavailable": return "O perfil não está disponível."
		_: return "O encerramento da run falhou (%s)." % error_code

func _open_class_menu() -> void:
	if augment_overlay.visible or class_overlay.visible:
		return
	if battle_controls.settings_overlay.visible:
		battle_controls.settings_overlay.visible = false
	_cancel_casting()
	_clear_hover()
	class_label.text = "Treino isolado da build atual. Saia pelo botão de treino para mudar a build." if training_mode else ("Esta run usa o personagem persistente %s.\nVolte ao menu para trocar personagem ou iniciar outra run." % player.class_definition.display_name if _persistent_run_active() else "Classe atual: %s\nEscolher uma classe inicia uma run nova e limpa todo o estado temporário." % player.class_definition.display_name)
	class_overlay.visible = true
	get_tree().paused = true

func _close_class_menu() -> void:
	class_overlay.visible = false
	get_tree().paused = run_finished or augment_overlay.visible or battle_controls.settings_overlay.visible

func _select_class(new_class_id: StringName) -> void:
	if ClassCatalog.class_definition(new_class_id) == null:
		return
	if training_mode:
		_return_to_character_menu()
		return
	if _persistent_run_active():
		var closed := _close_persistent_run(&"abandoned")
		if not closed["ok"]:
			_report_run_close_failure(closed)
			return
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/character_menu.tscn")
		return
	selected_class_id = new_class_id
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
	if _spiritualist_echo_number_target_id == actor.get_instance_id():
		_remember_spiritualist_feedback(actor, "ECO! %d" % amount)
		_show_combat_text(actor, "ECO! %d" % amount, Color("d9eafa"), 22)
		return
	_show_combat_text(actor, ("CRÍTICO %d" if critical else "%d") % amount, Color("ffd166") if critical else Color.WHITE, 20 if critical else 17)

func _show_miss(actor: CombatActor) -> void:
	_show_combat_text(actor, "ERROU", Color("b9cbd3"), 16)

func _show_spiritualist_feedback(actor: CombatActor, message: String, color: Color) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	for index: int in range(_spiritualist_feedback_labels.size() - 1, -1, -1):
		if not is_instance_valid(_spiritualist_feedback_labels[index]):
			_spiritualist_feedback_labels.remove_at(index)
	while _spiritualist_feedback_labels.size() >= 12:
		var oldest: Label = _spiritualist_feedback_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var stacked := 0
	for label: Label in _spiritualist_feedback_labels:
		if is_instance_valid(label) and label.get_meta("actor_id", 0) == actor.get_instance_id():
			stacked += 1
	var feedback_label := _show_combat_text(actor, message, color, 15, mini(stacked, 2) * 20.0)
	feedback_label.set_meta("actor_id", actor.get_instance_id())
	_spiritualist_feedback_labels.append(feedback_label)
	_remember_spiritualist_feedback(actor, message)

func _remember_spiritualist_feedback(actor: CombatActor, message: String) -> void:
	if actor != player and actor != _focused_spiritualist_target():
		return
	if message.begins_with("+") and _spiritualist_recent_feedback_remaining > 0.0 and not _spiritualist_recent_feedback.begins_with("+"):
		return
	_spiritualist_recent_feedback = message
	_spiritualist_recent_feedback_remaining = 0.9

func _clear_spiritualist_feedback() -> void:
	for label: Label in _spiritualist_feedback_labels:
		if is_instance_valid(label):
			label.queue_free()
	_spiritualist_feedback_labels.clear()
	_spiritualist_channel_notice_remaining = 0.0
	_spiritualist_recent_feedback_remaining = 0.0
	_spiritualist_recent_feedback = ""

func _show_combat_text(actor: CombatActor, text: String, color: Color, font_size: int, vertical_offset: float = 0.0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spiritualist_style := run_state != null and run_state.build_snapshot != null and run_state.build_snapshot.evolution_id == &"spiritualist"
	if spiritualist_style:
		label.custom_minimum_size = Vector2(200, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.global_position = actor.global_position + Vector2(-100, -maxf(78.0, 52.0 * actor.sprite_visual_scale + 20.0) - vertical_offset)
		label.add_theme_color_override("font_outline_color", Color("101725"))
		label.add_theme_constant_override("outline_size", 3)
	else:
		label.global_position = actor.global_position + Vector2(-22, -78 - vertical_offset)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 20
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", label.position + Vector2(0, -34), 0.55)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)
	return label

func _update_hud() -> void:
	if player == null or player.health == null:
		return
	health_label.text = "VIDA  %d / %d" % [ceili(player.health.current_hp), ceili(player.health.max_hp)]
	sp_label.text = "SP  %d / %d" % [floori(player.current_sp), floori(player.max_sp)]
	if training_mode and training_boss != null and training_boss.is_alive():
		training_status_label.text = "TREINO · Guardião %d/%d HP · reforços %d/%d" % [ceili(training_boss.health.current_hp), ceili(training_boss.health.max_hp), enemies.size() - 1, TRAINING_ADD_CAP]
	var skill_lines: PackedStringArray = []
	for skill_id: StringName in player.available_skill_ids():
		var definition := ClassCatalog.skill_definition(skill_id)
		var cost := 0.0 if skill_id == &"shield_wall" and player.has_shield_stance() else player.skill_cost(skill_id)
		var rank_text := " R%d" % player.skill_rank(skill_id) if not definition.ranks.is_empty() else ""
		var state := _display_skill_state(skill_id, cost)
		skill_lines.append("%s  %s%s — %s" % [_skill_input_label(skill_id), definition.display_name, rank_text, state])
	skill_label.text = "\n".join(skill_lines)
	if defender_status_label != null:
		defender_status_label.text = player.defender_feedback_text()
		defender_status_label.visible = not defender_status_label.text.is_empty()
	_update_spiritualist_panel()
	augment_button.text = "Escolher augment (E) — %d pendente(s)" % run_state.pending_choices
	augment_button.visible = run_state.pending_choices > 0
	if battle_controls != null:
		for skill_id: StringName in player.available_skill_ids():
			var definition := ClassCatalog.skill_definition(skill_id)
			var cost := 0.0 if skill_id == &"shield_wall" and player.has_shield_stance() else player.skill_cost(skill_id)
			var rank_text := " R%d" % player.skill_rank(skill_id) if not definition.ranks.is_empty() else ""
			var state := _display_skill_state(skill_id, cost)
			battle_controls.show_skill_state(skill_id, "%s · %s%s\n%d SP · %s" % [_skill_input_label(skill_id), definition.display_name.to_upper(), rank_text, int(cost), state], cast_intent.active_skill == skill_id or player.active_cast_skill == skill_id)

func _skill_input_label(skill_id: StringName) -> String:
	var index := player.available_skill_ids().find(skill_id)
	var labels := ["Q", "W", "A", "S", "D"]
	return labels[index] if index >= 0 and index < labels.size() else ClassCatalog.skill_definition(skill_id).input_key

func _display_skill_state(skill_id: StringName, sp_cost: float) -> String:
	if player.active_cast_skill == skill_id:
		return "CONJURANDO %.1fs" % player.active_cast_remaining
	if skill_id == &"shield_wall" and player.has_shield_stance():
		return "ATIVA %.1fs · %d cargas · DESLIGAR" % [player.shield_remaining, player.shield_resistance]
	if skill_id == &"perseverance" and player.perseverance_remaining > 0.0:
		return "ESCUDO %d · %.1fs" % [ceili(player.health.shield_hp), player.perseverance_remaining]
	if skill_id == &"fury" and player.fury_remaining > 0.0:
		return "ATIVA %.1fs" % player.fury_remaining
	if skill_id == &"extended_aim" and player.has_extended_aim():
		return "ATIVA %.1fs" % player.extended_aim_remaining
	return _skill_state(player.skill_cooldown(skill_id), sp_cost, skill_id)

func _skill_state(cooldown: float, sp_cost: float, skill_id: StringName = &"") -> String:
	if cooldown > 0.0:
		return "RECARGA %.1fs" % cooldown
	if player.current_sp < sp_cost:
		return "SEM SP"
	if skill_id == &"berserker_execution" and not player.can_pay_berserker_execution_hp():
		return "HP INSUFICIENTE"
	return "PRONTO"

func _show_skill_blocked(skill_name: String, cooldown: float, sp_cost: float, skill_id: StringName = &"") -> void:
	_feedback_serial += 1
	var serial := _feedback_serial
	status_label.text = "%s indisponível — %s" % [skill_name, _skill_state(cooldown, sp_cost, skill_id)]
	get_tree().create_timer(1.2).timeout.connect(_restore_context_status.bind(serial))

func _restore_context_status(serial: int) -> void:
	if serial != _feedback_serial or run_finished:
		return
	if training_mode:
		status_label.text = "Treino isolado · pratique a rotação ou saia para mudar build"
		return
	if encounter_active:
		status_label.text = "Encontro %d/2 — elimine todos os inimigos" % encounter_index
	elif reward != null:
		status_label.text = "Encontro concluído — toque no cristal dourado"
	elif run_state.pending_choices > 0:
		status_label.text = "Recompensa coletada — abra a escolha com E"
	elif encounter_index < 2:
		status_label.text = "Augment aplicado — inicie o próximo encontro"

func _update_spiritualist_panel() -> void:
	if spiritualist_panel == null:
		return
	var target := _focused_spiritualist_target()
	var lines: Array[String] = []
	if target == null:
		lines.append("Alvo: nenhum · clique ou mire um inimigo")
	else:
		var target_id := target.get_instance_id()
		lines.append("Alvo: %s" % target.actor_name)
		if spiritualist_echo_state.marks.has(target_id):
			lines.append("MALDIÇÃO %.1fs · próximo acerto direto prepara Eco" % float(spiritualist_echo_state.marks[target_id]["remaining"]))
		else:
			for echo: Dictionary in spiritualist_echo_state.pending:
				if int(echo["target_id"]) == target_id:
					lines.append("ECO PREPARADO %.1fs" % float(echo["remaining"]))
					break
		var weakened := target.attribute_debuffs.effective_state(AttributeDebuffState.DAMAGE_DEALT)
		if float(weakened["fraction"]) > 0.0:
			lines.append("DANO CAUSADO −%d%% · %.1fs" % [roundi(float(weakened["fraction"]) * 100.0), float(weakened["remaining"])])
	if spiritualist_drain_state.active:
		lines.append("CANALIZANDO %d/%d" % [spiritualist_drain_state.ticks_resolved, SpiritualistDrainState.TICK_COUNT])
	elif _spiritualist_channel_notice_remaining > 0.0:
		lines.append("CANAL INTERROMPIDO")
	if player.spiritualist_focus_remaining > 0.0:
		lines.append("FOCO PRONTO %.1fs" % player.spiritualist_focus_remaining)
	var state_text := "\n".join(lines)
	if spiritualist_state_label.text != state_text:
		spiritualist_state_label.text = state_text
	var equipped := player.available_skill_ids()
	var hint := "Selecione um alvo para ler os efeitos ativos."
	if target != null:
		var target_id := target.get_instance_id()
		if spiritualist_echo_state.marks.has(target_id):
			hint = "Autoataque/acerto direto → Eco."
			if equipped.has(&"spiritualist_dissipation"):
				hint += " Rito rompe a marca sem gerar Eco."
		elif spiritualist_echo_state.pending.any(func(echo: Dictionary) -> bool: return int(echo["target_id"]) == target_id):
			hint = "Eco preparado; confirme o dano no impacto."
		elif equipped.has(&"spiritualist_echo_curse"):
			hint = "Maldição → acerto direto → Eco."
		else:
			hint = "Use as ações equipadas; Maldição não está na barra."
	if player.spiritualist_focus_remaining > 0.0:
		var consumers: Array[String] = []
		if equipped.has(&"spiritualist_echo_curse"):
			consumers.append("Maldição")
		if equipped.has(&"spiritualist_dissipation"):
			consumers.append("Rito")
		if not consumers.is_empty():
			hint += " Foco fortalece %s." % " ou ".join(consumers)
	if _spiritualist_recent_feedback_remaining > 0.0:
		hint = _spiritualist_recent_feedback
	if spiritualist_hint_label.text != hint:
		spiritualist_hint_label.text = hint
	var help_text := _spiritualist_route_help(equipped)
	if spiritualist_help_label.text != help_text:
		spiritualist_help_label.text = help_text

func _spiritualist_route_help(equipped: Array) -> String:
	var lines: Array[String] = []
	if equipped.has(&"spiritualist_echo_curse"):
		lines.append("Maldição → auto/acerto direto → Eco após %.2fs." % SpiritualistEchoState.ECHO_DELAY)
		if equipped.has(&"spiritualist_dissipation"):
			lines.append("Alternativa: Maldição → Rito → marca dissipada; sem Eco.")
	if equipped.has(&"spiritualist_soul_drain"):
		if player.run_state.build_snapshot.passive_slots.has(&"spiritualist_channel_focus"):
			lines.append("Drenagem completa (4 ticks) → Foco por 5s.")
		lines.append("Movimento, dano e controle interrompem Drenagem.")
	if lines.is_empty():
		lines.append("Equipe ações do Espiritualista no preset para ver rotas.")
	return "\n".join(lines)

func _build_spiritualist_panel() -> void:
	spiritualist_panel = PanelContainer.new()
	spiritualist_panel.name = "SpiritualistReadability"
	spiritualist_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	spiritualist_panel.offset_left = -440.0
	spiritualist_panel.offset_top = 265.0
	spiritualist_panel.offset_right = -24.0
	spiritualist_panel.offset_bottom = 445.0
	ui_root.add_child(spiritualist_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	spiritualist_panel.add_child(column)
	var title := _make_label("Leitura espiritual", 17, Color("e9d9f5"))
	column.add_child(title)
	spiritualist_state_label = _make_label("", 14, Color("e5eff3"))
	spiritualist_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(spiritualist_state_label)
	spiritualist_hint_label = _make_label("", 14, Color("ddcce7"))
	spiritualist_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(spiritualist_hint_label)
	spiritualist_help_toggle = Button.new()
	spiritualist_help_toggle.text = "Como combinar ▾"
	spiritualist_help_toggle.toggle_mode = true
	spiritualist_help_toggle.toggled.connect(func(expanded: bool) -> void:
		spiritualist_help_label.visible = expanded
		spiritualist_help_toggle.text = "Ocultar rotas ▴" if expanded else "Como combinar ▾"
		spiritualist_panel.offset_bottom = 515.0 if expanded else 445.0
	)
	column.add_child(spiritualist_help_toggle)
	spiritualist_help_label = _make_label("", 13, Color("cbd4df"))
	spiritualist_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	spiritualist_help_label.visible = false
	column.add_child(spiritualist_help_label)

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
	hud_panel.offset_bottom = 270.0
	var hud_margin := MarginContainer.new()
	hud_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		hud_margin.add_theme_constant_override("margin_" + side, 14)
	hud_panel.add_child(hud_margin)
	var hud_column := VBoxContainer.new()
	hud_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_margin.add_child(hud_column)
	health_label = _make_label("", 22, Color("ff8b8b"))
	sp_label = _make_label("", 19, Color("79bfff"))
	skill_label = _make_label("", 17, Color("e9c67b"))
	hud_column.add_child(health_label)
	hud_column.add_child(sp_label)
	if training_mode:
		training_status_label = _make_label("Treino isolado", 16, Color("f5cc77"))
		hud_column.add_child(training_status_label)
	hud_column.add_child(skill_label)
	defender_status_label = _make_label("", 16, Color("f5cc77"))
	hud_column.add_child(defender_status_label)

	help_panel = PanelContainer.new()
	ui_root.add_child(help_panel)
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	help_panel.offset_left = -440.0
	help_panel.offset_top = 112.0
	help_panel.offset_right = -24.0
	help_panel.offset_bottom = 258.0
	var help_text := "CLIQUE: mover / autoatacar o alvo\nQ / W / A / S / D: ações da classe\nDIREITO / ESC: cancelar mira\nR: reiniciar ao concluir · sem XP/recompensas" if training_mode else "CLIQUE: mover / autoatacar o alvo\nQ / W / A / S / D: ações da classe\nDIREITO / ESC: cancelar mira\nE: augment  ·  R: reiniciar ao concluir"
	var help_label := _make_label(help_text, 16, Color("d7ddea"))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_panel.add_child(help_label)
	if run_state.build_snapshot != null and run_state.build_snapshot.evolution_id == &"spiritualist":
		_build_spiritualist_panel()

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
	if training_mode:
		var restart_training := Button.new()
		restart_training.text = "Reiniciar treino"
		restart_training.pressed.connect(_restart_run)
		buttons.add_child(restart_training)
		var exit_training := Button.new()
		exit_training.text = "Sair e mudar build"
		exit_training.pressed.connect(_return_to_character_menu)
		buttons.add_child(exit_training)

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
	result_panel.offset_top = -190.0
	result_panel.offset_right = 280.0
	result_panel.offset_bottom = 190.0
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
	restart_button = Button.new()
	restart_button.text = "Reiniciar arena (R)"
	restart_button.custom_minimum_size = Vector2(260, 54)
	restart_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart_button.pressed.connect(_restart_run)
	result_column.add_child(restart_button)
	var return_menu := Button.new()
	return_menu.text = "Voltar ao menu de personagens"
	return_menu.custom_minimum_size = Vector2(320, 48)
	return_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return_menu.pressed.connect(_return_to_character_menu)
	result_column.add_child(return_menu)
	var result_class := Button.new()
	result_class.text = "Mudar build" if training_mode else "Trocar classe e iniciar nova run"
	result_class.custom_minimum_size = Vector2(320, 48)
	result_class.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_class.pressed.connect(_return_to_character_menu if training_mode else _open_class_menu)
	result_column.add_child(result_class)
	result_overlay.visible = false
	battle_controls = BattleControls.new()
	ui_root.add_child(battle_controls)
	battle_controls.set_options(control_preferences.cast_mode, control_preferences.smart_lock)
	battle_controls.skill_selected.connect(_select_skill_from_bar)
	battle_controls.settings_requested.connect(_toggle_settings)
	battle_controls.preferences_changed.connect(_change_control_preferences)
	battle_controls.set_class_skills(player.available_skill_ids())
	# The battle controls belong below end-of-run and reward modals.
	ui_root.move_child(battle_controls, augment_overlay.get_index())

	class_button = Button.new()
	class_button.text = "Classe: %s" % player.class_definition.display_name
	if player.run_state != null and player.run_state.uses_persistent_build() and not player.run_state.build_snapshot.evolution_id.is_empty():
		var evolution := ProfileCatalog.pilot().evolution_definition(player.run_state.build_snapshot.evolution_id)
		if evolution != null:
			class_button.text = "Classe: %s" % evolution.display_name
	class_button.custom_minimum_size = Vector2(184, 38)
	ui_root.add_child(class_button)
	class_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	class_button.offset_left = -208
	class_button.offset_top = 64
	class_button.offset_right = -24
	class_button.offset_bottom = 102
	class_button.pressed.connect(_open_class_menu)
	ui_root.move_child(class_button, augment_overlay.get_index())

	class_overlay = _make_overlay(ui_root)
	var class_panel := PanelContainer.new()
	class_overlay.add_child(class_panel)
	class_panel.set_anchors_preset(Control.PRESET_CENTER)
	class_panel.offset_left = -330
	class_panel.offset_top = -180
	class_panel.offset_right = 330
	class_panel.offset_bottom = 180
	var class_column := VBoxContainer.new()
	class_column.alignment = BoxContainer.ALIGNMENT_CENTER
	class_column.add_theme_constant_override("separation", 18)
	class_panel.add_child(class_column)
	class_label = _make_label("", 21, Color("d7ddea"))
	class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_column.add_child(class_label)
	if training_mode:
		var exit_class := Button.new()
		exit_class.text = "Sair do treino e mudar build"
		exit_class.pressed.connect(_return_to_character_menu)
		class_column.add_child(exit_class)
	else:
		for class_id: StringName in [&"swordsman", &"mage"]:
			var definition := ClassCatalog.class_definition(class_id)
			var choose := Button.new()
			choose.text = "Jogar de %s — iniciar nova run" % definition.display_name
			choose.custom_minimum_size = Vector2(420, 54)
			choose.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			choose.pressed.connect(_select_class.bind(class_id))
			class_column.add_child(choose)
	var cancel_class := Button.new()
	cancel_class.text = "Voltar sem reiniciar"
	cancel_class.custom_minimum_size = Vector2(300, 44)
	cancel_class.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_class.pressed.connect(_close_class_menu)
	class_column.add_child(cancel_class)
	class_overlay.visible = false

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
