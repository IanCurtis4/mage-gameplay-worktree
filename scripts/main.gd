class_name RunController
extends Node2D

var admin_panel: PlaytestAdminPanel
var _admin_offer_override := false
var _startup_error := false
var snapshot_passive := false
signal memory_snapshot_ready(result: Dictionary)
var _memory_snapshot_pending := false
var _memory_snapshot_previous_pause := false
var _memory_snapshot_barrier: SnapshotTickBarrier

func request_memory_snapshot() -> Dictionary:
	if snapshot_passive or _memory_snapshot_pending or not is_inside_tree(): return WorldSkillCast.failure(&"snapshot_barrier_busy")
	_memory_snapshot_pending = true
	_capture_memory_snapshot.call_deferred()
	return {"ok":true,"queued":true}

func _capture_memory_snapshot() -> void:
	if not _memory_snapshot_pending: return
	# A background journal write publishes first; the cut then includes it.
	if expedition_save_busy() and is_inside_tree():
		get_tree().process_frame.connect(_capture_memory_snapshot,CONNECT_ONE_SHOT)
		return
	_memory_snapshot_previous_pause = get_tree().paused
	get_tree().paused = true
	_memory_snapshot_barrier = SnapshotTickBarrier.new()
	var result := _memory_snapshot_barrier.acquire(self)
	if result["ok"]:
		result = SnapshotRegistry.new().capture(self,_memory_snapshot_barrier)
		if result.get("error_code") == &"checkpoint_incomplete" and result.get("detail") == "deferred deletion pending":
			# Only a queued deletion needs another frame. The barrier already
			# freezes gameplay; a bound signal disconnects if this host is freed.
			get_tree().process_frame.connect(_capture_after_deletion.bind(_memory_snapshot_barrier),CONNECT_ONE_SHOT)
			return
	_finish_memory_snapshot(result)

func _capture_after_deletion(barrier: SnapshotTickBarrier) -> void:
	# A release/new request must never receive the previous request's callback.
	if not _memory_snapshot_pending or not is_same(barrier,_memory_snapshot_barrier) or not is_inside_tree(): return
	_finish_memory_snapshot(SnapshotRegistry.new().capture(self,barrier))

func _finish_memory_snapshot(result: Dictionary) -> void:
	if ui_root != null:
		var recovery_ui := ui_root.get_node_or_null("ExpeditionStatus") as ExpeditionStatusPanel
		if recovery_ui != null: recovery_ui.retain_recovery_input()
	# Stay frozen until the consumer accepts the cut or explicitly recovers.
	# No lobby transition or durable-save claim belongs to this API.
	memory_snapshot_ready.emit(result)

func release_memory_snapshot() -> void:
	if snapshot_passive or not _memory_snapshot_pending: return
	if persistent_facade != null and run_state != null:
		var profile := persistent_facade.current_profile()
		var lock := profile.expedition_for_character(run_state.character_id) if profile != null else null
		# A committed suspension is replaced by a restored graph, never resumed in place.
		if lock != null and lock.lifecycle == &"suspended" and not lock.checkpoint.is_empty(): return
	if _memory_snapshot_barrier != null:
		_memory_snapshot_barrier.release()
		if is_inside_tree(): get_tree().paused = _memory_snapshot_previous_pause
	_memory_snapshot_barrier = null
	_memory_snapshot_pending = false

const IceWallScript = preload("res://scripts/world/ice_wall.gd")
const ExpeditionBackdropScript = preload("res://scripts/world/expedition_backdrop.gd")
const ForestAmbienceScript = preload("res://scripts/presentation/forest_ambience_layer.gd")
const ElementalistSequenceScript = preload("res://scripts/world/elementalist_sequence.gd")

const ARENA_BOUNDS := Rect2(80, 80, 1640, 920)
const ARENA_OBSTACLES: Array[Rect2] = [
	Rect2(610, 280, 190, 140),
	Rect2(1010, 570, 230, 125),
	Rect2(390, 700, 185, 105),
]
const TARGET_ASSIST_RADIUS := BattleTargeting.ASSIST_RADIUS
const AUGMENT_COMBAT_TEXT := "Augments só podem ser escolhidos fora de combate."
const TARGET_DIRECT_PADDING := BattleTargeting.DIRECT_PADDING
const ACTOR_BODY_OFFSET := BattleTargeting.BODY_OFFSET
const DEFENDER_WATCH_DIRECT_MELEE_IDS := [
	&"basic_attack", &"cone_slash", &"brutal_strike", &"concentrated_rage",
	&"defender_counterstroke", &"defender_line_lock", &"defender_wall_advance", &"defender_reprisal_wave", &"defender_riposte",
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
static var pending_gameplay_extension := false

var rng := RandomNumberGenerator.new()
var campaign_runtime: ExpeditionCampaignRuntime
var combat_participation := CombatParticipation.new()
var _expedition_transaction_service: ExpeditionService
var _expedition_flush_running := false
var expedition_entry_mode := false
var run_state: RunState
var navigation := ArenaNavigation.new()
var arena_view: ArenaView
var player: PlayerActor
var enemies: Array[CombatActor] = []
var hunter_tar_field: HunterTarField
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
# Internal presentation switches for diagnostics/probes; never persisted or exposed in the UI.
var spiritualist_debug_text := false
var combat_numbers_visible := true
var world_spawn_error: StringName = &""
var expedition_view: ExpeditionGeometryView
var expedition_field_height := 0.0
## Ground click whose route is searched in the background (checkpoint36).
## Transient: {request, destination, retried}; omitted from snapshots.
var _pending_world_click: Dictionary = {}
## Earliest time for the next automatic collection after a refusal (checkpoint38).
## Transient; omitted from snapshots.
var _auto_collect_after_msec := 0
# Checkpoint40: during combat, mob deaths go to the journal at most once per interval.
const DEATH_JOURNAL_INTERVAL_MSEC := 2000
var _death_flush_after_msec := 0
var _world_companion_attempts: Dictionary[int, bool] = {}
var _world_pending_companions: Dictionary[int, WeakRef] = {}
var reward: RewardPickup
var encounter_index := 0
var _legacy_encounter_active := false
var encounter_active: bool:
	get:
		return combat_participation.active() if campaign_runtime != null and combat_participation != null else _legacy_encounter_active
	set(value): _legacy_encounter_active = value
var run_finished := false
var build_service: RunBuildService
var acquisition_journal := AcquisitionJournal.new()
var reward_feedback: RewardFeedbackPanel
var skill_window: SkillWindow
var _skill_action_editor_home: Node
var _skill_action_editor_index := 0
var _acquisition_augment_serial := 0
var reward_service: RunRewardService
var inventory_panel: RunInventoryPanel
var inventory_button: Button
var equipment_head: EquipmentHeadVisual
var inventory_frozen := false
var _inventory_previous_pause := false
var _terminal_outcome: StringName = &"abandoned"
var persistent_facade: ProfileFacade = null
var _close_request_serial := 0
var _reward_retry_pending := false
var training_mode := false
var gameplay_extension := false
var active_bounds := ARENA_BOUNDS
var _world_obstacle_views: Array[Node2D] = []
var route_camera: Camera2D
var stage_minimap: StageMinimap
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
var _intent_rank := 0
var action_bar_input := ActionBarInput.new()
var action_slots: Array[Variant] = []
var battle_indicators: BattleIndicators
var spiritualist_ground: SpiritualistHaloUnderlay
var geometer_casting: GeometerCasting
var geometer_onboarding: GeometerOnboarding
var sentinel_onboarding: SentinelOnboarding
var sentinel_focus_label: Label
var sentinel_focus_bar: ProgressBar
var geometer_element_buttons: Dictionary[StringName, Button] = {}
var _geometer_pointer_screen := Vector2.INF
var trap_registry: PlayerTrapRegistry
var battle_controls: BattleControls
var class_button: Button
var class_overlay: Control
var class_label: Label

func presentation_events() -> PresentationEventBridge:
	return get_node_or_null("PresentationEvents") as PresentationEventBridge

func presentation_audio() -> PresentationAudioService:
	var bridge := presentation_events()
	return bridge.get_node_or_null("PresentationAudio") as PresentationAudioService if bridge != null else null

func _present_ui(cancelled: bool = false) -> void:
	var audio := presentation_audio()
	if audio != null: audio.confirm_ui(cancelled)

func _begin_presentation_stage(id: String, resumed: bool = false, biome: String = "") -> void:
	var bridge := presentation_events()
	if bridge == null:
		bridge = PresentationEventBridge.new()
		add_child(bridge)
		bridge.bind_controller(self)
	var audio := presentation_audio()
	if audio == null:
		audio = PresentationAudioService.new()
		bridge.add_child(audio)
		audio.configure(bridge)
	if bridge.get_node_or_null("E08PilotFeedback") == null:
		var feedback := preload("res://scripts/presentation/feedback_vfx_layer.gd").new()
		bridge.add_child(feedback)
		feedback.configure(bridge, self)
	audio.set_stage_biome(biome) # Chooses the biome ambience bed when the stage activates.
	if bridge.stage_id != id: bridge.begin_stage(id, resumed)
	if is_instance_valid(battle_controls): battle_controls.audio_panel.bind_service(audio)

func _pilot_actor_entered(node: Node) -> void:
	if node is EnemyActor and node.occurrence != null and preload("res://scripts/presentation/e08_pilot_visual.gd").has_species_presentation(node.occurrence.mob_base_id):
		if not preload("res://scripts/presentation/e08_pilot_visual.gd").install_forest_atlas(node):
			push_error("Não foi possível aplicar o atlas visual da espécie " + str(node.occurrence.mob_base_id))

func _ready() -> void:
	if not child_entered_tree.is_connected(_pilot_actor_entered): child_entered_tree.connect(_pilot_actor_entered)
	if snapshot_passive: return
	process_mode = Node.PROCESS_MODE_ALWAYS
	y_sort_enabled = true
	rng.seed = Time.get_ticks_usec()
	if pending_run_state != null:
		run_state = pending_run_state
		persistent_facade = pending_run_facade
		training_mode = pending_training_mode
		gameplay_extension = pending_gameplay_extension and not training_mode and persistent_facade != null
		pending_run_state = null
		pending_run_facade = null
		pending_training_mode = false
		pending_gameplay_extension = false
	else:
		run_state = RunState.new(selected_class_id)
	if gameplay_extension:
		var loaded := BuildContentLoader.load_catalog_for_profile(run_state.build_snapshot._skill_catalog, true)
		var configured_effects := run_state.set_effect_catalog(loaded["catalog"]) if loaded.get("ok", false) else loaded
		if not configured_effects.get("ok", false):
			_startup_failure("O conteúdo da partida não pôde ser carregado.")
			return
	control_preferences.load_settings()
	cast_intent.set_mode(control_preferences.cast_mode)
	arena_view = ArenaView.new()
	arena_view.z_index = -2
	add_child(arena_view)
	_configure_world(1)
	battle_indicators = BattleIndicators.new()
	battle_indicators.z_index = 2 if run_state.build_snapshot != null and run_state.build_snapshot.evolution_id == &"spiritualist" else -1
	battle_indicators.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(battle_indicators)
	if run_state.build_snapshot != null and run_state.build_snapshot.evolution_id == &"spiritualist":
		spiritualist_ground = SpiritualistHaloUnderlay.new()
		spiritualist_ground.indicators = battle_indicators
		spiritualist_ground.z_index = -1
		spiritualist_ground.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(spiritualist_ground)
	trap_registry = PlayerTrapRegistry.new()
	trap_registry.y_sort_enabled = true
	add_child(trap_registry)
	player = PlayerActor.new()
	if not run_state.uses_persistent_build():
		var catalog := ProfileCatalog.pilot()
		for slot: StringName in IdentityIds.equipment_slots():
			var definition_id: Variant = catalog.starter_equipment(run_state.class_id)[slot]
			if definition_id == null:
				continue
			var created := run_state.add_local_equipment(definition_id, catalog.equipment_metadata(definition_id))
			if created["ok"]:
				run_state.build_snapshot.equipped[slot] = created["instance_id"]
				run_state.build_snapshot.equipment_instances[created["instance_id"]] = run_state.local_equipment_instances[created["instance_id"]].copy_instance()
	else:
		for id: StringName in run_state.build_snapshot.equipment_instances:
			run_state.local_equipment_instances[id] = run_state.build_snapshot.equipment_instances[id].copy_instance()
	player.configure(navigation, run_state)
	build_service = RunBuildService.new(self)
	reward_service = RunRewardService.new(self)
	reward_service.reward_confirmed.connect(_on_reward_confirmed)
	if persistent_facade != null and not training_mode and run_state.effect_catalog().get_definition(&"equipment", &"arena_legendary_ward") != null:
		var production := EquipmentLootProfiles.production(run_state.effect_catalog())
		var configured := reward_service.configure_mob_loot(production)
		assert(configured["ok"], str(configured))
	player.global_position = PlaytestGameplay.ENTRANCE if gameplay_extension else Vector2(300, 520)
	player.attack_requested.connect(_on_attack_requested)
	player.world_attack_requested.connect(_on_world_attack_requested)
	player.defender_hit_requested.connect(_on_defender_hit_requested)
	player.world_defender_hit_requested.connect(_on_world_defender_hit_requested)
	player.berserker_rift_hit_requested.connect(_on_berserker_rift_hit_requested)
	player.berserker_breath_hit_requested.connect(_on_berserker_breath_hit_requested)
	player.mage_projectile_requested.connect(_on_mage_projectile_requested)
	player.discharge_requested.connect(_on_discharge_requested)
	player.precision_projectile_requested.connect(_on_precision_projectile_requested)
	player.sentinel_projectile_requested.connect(_on_sentinel_projectile_requested)
	player.arrow_rain_requested.connect(_on_arrow_rain_requested)
	player.snare_trap_requested.connect(_on_snare_trap_requested)
	player.explosive_trap_requested.connect(_on_explosive_trap_requested)
	player.hunter_trap_requested.connect(_on_hunter_trap_requested)
	player.slowing_arrow_requested.connect(_on_slowing_arrow_requested)
	player.foliage_shelter_requested.connect(_on_foliage_shelter_requested)
	player.hunter_total_cover_requested.connect(_on_hunter_total_cover_requested)
	player.hunter_covering_shot_requested.connect(_on_hunter_covering_shot_requested)
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
	player.health.healed.connect(_on_player_healed)
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
	if player.is_geometer():
		geometer_casting = GeometerCasting.new()
		add_child(geometer_casting)
		geometer_casting.configure(player)
		geometer_casting.targets = enemies
		geometer_casting.hit.connect(_on_attack_requested)
		geometer_casting.feedback.connect(_on_geometer_feedback)
	spiritualist_echo_state.source_id = player.get_instance_id()
	_create_runtime_camera()
	_build_ui()
	if training_mode:
		_spawn_training_boss()
	elif not expedition_entry_mode:
		_spawn_encounter(1)

func _create_runtime_camera() -> void:
	control_preferences.load_camera_zoom()
	var camera := Camera2D.new()
	route_camera = camera
	camera.zoom = Vector2.ONE * control_preferences.camera_zoom
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = int(active_bounds.position.x - 40.0)
	camera.limit_top = int(active_bounds.position.y - 40.0)
	camera.limit_right = int(active_bounds.end.x + 40.0)
	camera.limit_bottom = int(active_bounds.end.y + 40.0)
	if campaign_runtime != null:
		# The pilot's positive flat bounds are not projected expedition bounds.
		# Keep following the player; WorldGeometry still constrains movement.
		camera.limit_left = -1000000; camera.limit_top = -1000000
		camera.limit_right = 1000000; camera.limit_bottom = 1000000
	player.add_child(camera)

func _advance_runtime(_delta: float) -> void:
	if campaign_runtime != null:
		_advance_expedition_runtime(_delta)
	if not get_tree().paused and not run_finished: _advance_world_companion_requests()
	player.sentinel_combat_active = encounter_active and not run_finished
	player.regenerate_hp(_delta, encounter_active, get_tree().paused or run_finished)
	if not get_tree().paused and not run_finished:
		_spiritualist_channel_notice_remaining = maxf(0.0, _spiritualist_channel_notice_remaining - _delta)
		_spiritualist_recent_feedback_remaining = maxf(0.0, _spiritualist_recent_feedback_remaining - _delta)
		if training_mode and player.is_alive() and training_boss != null and training_boss.is_alive():
			_advance_training_adds(_delta)
		_sync_defender_anchor()
		_sync_berserker_wound_visuals()
		if player.is_alive():
			if geometer_casting != null:
				geometer_casting.targets = enemies
				geometer_casting.advance(_delta)
			var marks_before := spiritualist_echo_state.marks.keys()
			var due_echoes := spiritualist_echo_state.advance(_delta)
			_announce_spiritualist_mark_expiry(marks_before)
			for echo: Dictionary in due_echoes:
				_apply_spiritualist_echo(echo)
			spiritualist_echo_state.finish_resolution()
			_advance_spiritualist_drain(_delta)
			_advance_spiritualist_veil(_delta)
			_advance_spiritualist_procession(_delta)
			_sync_spiritualist_combat_state()
			battle_indicators.sync_spiritualist_focus(player.get_instance_id(), player.spiritualist_focus_remaining)

func _process(_delta: float) -> void:
	_pump_world_navigation()
	_auto_collect()
	_advance_runtime(_delta)
	_update_hud()
	_update_stage_minimap(_delta)
	for element: StringName in geometer_element_buttons:
		var element_button := geometer_element_buttons[element]
		element_button.disabled = get_tree().paused or run_finished or not player.is_alive()
		element_button.set_pressed_no_signal(element == geometer_casting.construction.grammar.selected_element)
	if not get_tree().paused and not run_finished:
		if _world_pointer_available():
			_update_hover(_world_mouse_point())
		else:
			_clear_hover()
		_update_aim(_world_mouse_point())
	if get_tree().paused or _reward_retry_pending or reward == null or not is_instance_valid(reward):
		return
	if player.world_motion != null:
		# Collection is refused in combat; polling then would only pay a ground path per frame.
		if not encounter_active and reward.can_collect_world(player,48.0): _collect_reward()
	elif player.global_position.distance_to(reward.global_position) <= 48.0:
		_collect_reward()

func _input(event: InputEvent) -> void:
	if snapshot_passive or _memory_snapshot_pending: return
	if player != null and player.world_motion != null and expedition_view == null: return # Logical-only consumers have no pointer adapter.
	if event is InputEventMouse:
		_geometer_pointer_screen = event.position
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and (cast_intent.active_skill != &"" or player.has_active_cast()):
		_cancel_casting()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and not event.echo:
		if battle_controls != null and battle_controls.handle_binding_event(event):
			_cancel_aim()
			get_viewport().set_input_as_handled()
			return
		if _keyboard_text_focused():
			_cancel_aim()
			return
		if event.keycode == KEY_F10 and event.pressed:
			if admin_panel != null and admin_panel.visible: admin_panel.dismiss()
			else: _open_admin_tools()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and event.pressed:
			if admin_panel != null and admin_panel.visible:
				admin_panel.dismiss()
			elif skill_window != null and skill_window.visible:
				skill_window.dismiss()
			elif reward_feedback != null and reward_feedback.history_panel.visible:
				reward_feedback.hide_history()
			elif inventory_panel != null and inventory_panel.visible:
				inventory_panel.dismiss()
			elif class_overlay.visible:
				_close_class_menu()
			elif battle_controls.settings_overlay.visible:
				_toggle_settings(false)
			elif cast_intent.active_skill != &"" or player.has_active_cast() or player.sentinel_state.explosive_prepared:
				_cancel_casting()
			elif not get_tree().paused and not run_finished:
				_toggle_settings(true)
			get_viewport().set_input_as_handled()
		elif not event.pressed:
			var skill := action_bar_input.release(event)
			if cast_intent.mode == CastIntent.Mode.RELEASE and skill != &"" and skill == cast_intent.active_skill:
				var to_cast := cast_intent.release(skill)
				if _world_pointer_available():
					_commit_skill(to_cast, _world_mouse_point())
				_cancel_aim()
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if player != null and player.world_motion != null and expedition_view == null: return # Logical-only consumers have no pointer adapter.
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not _camera_zoom_available() or not _world_pointer_available(): return
		change_camera_zoom(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _keyboard_text_focused():
			return
		var auxiliary: bool = not event.alt_pressed and not event.ctrl_pressed and not event.shift_pressed and not event.meta_pressed
		if auxiliary and event.keycode == KEY_F8 and _reward_retry_pending:
			_reward_retry_pending = false
			_collect_reward()
			get_viewport().set_input_as_handled()
			return
		if auxiliary and event.keycode == KEY_F9 and (not player.is_alive() or run_finished):
			_restart_run()
			return
		if auxiliary and event.keycode == KEY_F8 and not run_finished and run_state.can_open_choice(encounter_active):
			_open_augment_menu()
			return
		if auxiliary and event.keycode == KEY_F8 and not run_finished and encounter_active and run_state.pending_choices > 0:
			status_label.text = AUGMENT_COMBAT_TEXT
			return
		if get_tree().paused or not player.is_alive() or run_finished:
			return
		if auxiliary and _handle_geometer_key(event.keycode):
			get_viewport().set_input_as_handled()
			return
		var skill := action_bar_input.press(event, control_preferences, action_slots)
		if skill != &"" and skill in player.available_skill_ids() and SkillCastRank.resolve(skill, action_bar_input.pending_rank, run_state.effective_skill_rank(skill)) > 0:
			player.cancel_active_cast()
			_intent_rank = action_bar_input.pending_rank
			var definition := ClassCatalog.skill_definition(skill)
			if definition != null and definition.targeting == SkillDefinition.Targeting.SELF:
				cast_intent.cancel()
				_commit_skill(skill, player.global_position)
				_cancel_aim()
			elif _world_pointer_available():
				_commit_skill(cast_intent.press(skill), _world_mouse_point())
				_update_aim(_world_mouse_point())
			else:
				# A rejected retarget must not leave an older aim without its release latch.
				_cancel_aim()
			get_viewport().set_input_as_handled()
		elif auxiliary and event.keycode == KEY_SPACE and next_button.visible:
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
	var event := InputEventKey.new()
	event.keycode = key
	var index := control_preferences.slot_for_event(event)
	return ActionBarLayout.skill_id(action_slots[index]) if index >= 0 and index < action_slots.size() else &""

func _keyboard_text_focused() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	return focused is LineEdit or focused is TextEdit

func _commit_skill(skill: StringName, point: Vector2) -> void:
	if skill.is_empty():
		return
	var previous := player.push_cast_rank(skill, _intent_rank)
	if player.selected_cast_rank_valid(skill):
		_commit_skill_with_rank(skill, point)
	else:
		status_label.text = "Rank do atalho indisponível."
	player.restore_cast_rank(previous)

func _commit_skill_with_rank(skill: StringName, point: Vector2) -> void:
	if player.world_motion != null:
		if expedition_view != null:
			var result := spatial_pointer_skill(skill,point,false)
			status_label.text = "Habilidade preparada" if result["ok"] else "Destino ou alvo indisponível; recurso preservado."
		return
	if skill == &"" or get_tree().paused or run_finished or not player.is_alive() or skill not in player.available_skill_ids():
		return
	if spiritualist_drain_state.active:
		_cancel_spiritualist_drain()
	if GeometerCastCommand.is_grammar_skill(skill):
		if geometer_casting != null:
			geometer_casting.targets = enemies
			geometer_casting.begin(geometer_casting.capture(skill, point, Input.is_key_pressed(KEY_SHIFT)))
		return
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
	if skill == &"sentinel_absolute_focus":
		if not player.use_sentinel_absolute_focus():
			_report_skill_failure(skill, selected_target)
		return
	if skill == &"sentinel_explosive_shot":
		if not player.prepare_sentinel_explosive():
			_report_skill_failure(skill, selected_target)
		return
	if skill == &"sentinel_net_shot":
		if not player.use_sentinel_net(point):
			_report_skill_failure(skill, selected_target)
		return
	if skill in [&"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_concussion_shot"]:
		if not player.use_sentinel_reset(skill, point, selected_target):
			_report_skill_failure(skill, selected_target)
		return
	if skill == &"sentinel_observe":
		if not player.use_sentinel_observe(selected_target):
			_report_skill_failure(skill, selected_target)
		return
	var direction := player.aim_direction(point)
	var definition := ClassCatalog.skill_definition(skill)
	if definition == null:
		return
	if definition.handler_id == SkillDefinition.Handler.DEFENDER_RIPOSTE:
		if not player.use_defender_riposte(direction, enemies):
			status_label.text = "Rebater exige token e um alvo frontal ao alcance."
	elif definition.handler_id == SkillDefinition.Handler.DEFENDER_RETREAT_GUARD:
		if not player.use_defender_retreat_guard(direction):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.BERSERKER_PURSUIT_CUT:
		if not player.use_berserker_pursuit_cut(selected_target):
			_report_skill_failure(skill, selected_target)
	elif definition.handler_id == SkillDefinition.Handler.SLASH:
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
	elif definition.handler_id in [SkillDefinition.Handler.HUNTER_FREEZING_TRAP, SkillDefinition.Handler.HUNTER_TAR_TRAP, SkillDefinition.Handler.HUNTER_THORN_TRAP]:
		if not player.use_hunter_trap(skill, point):
			if not player.can_place_trap(skill, point):
				status_label.text = definition.display_name + " cancelada — POSIÇÃO BLOQUEADA"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.SLOWING_ARROW:
		if not player.use_slowing_arrow(direction):
			_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.HUNTER_MARK:
		if not player.use_hunter_mark(selected_target):
			status_label.text = definition.display_name + " cancelada — ALVO INVÁLIDO OU SKILL INDISPONÍVEL"
	elif definition.handler_id == SkillDefinition.Handler.HUNTER_COVERING_SHOT:
		if not player.use_hunter_covering_shot(direction):
			if not player.can_use_hunter_covering_shot(direction):
				status_label.text = definition.display_name + " cancelada — RECUO BLOQUEADO"
			else:
				_show_skill_blocked(definition.display_name, player.skill_cooldown(skill), player.skill_cost(skill))
	elif definition.handler_id == SkillDefinition.Handler.HUNTER_TOTAL_COVER:
		if not player.use_hunter_total_cover(point):
			if not player.can_place_hunter_total_cover(point):
				status_label.text = definition.display_name + " cancelada — POSIÇÃO BLOQUEADA"
			else:
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

func _select_skill_from_bar(skill: StringName, rank: int = 0) -> void:
	_intent_rank = rank
	if get_tree().paused or run_finished or not player.is_alive():
		return
	action_bar_input.cancel() # A card creates mouse-only confirmation, not held-key release.
	player.cancel_active_cast()
	var definition := ClassCatalog.skill_definition(skill)
	if definition != null and definition.targeting == SkillDefinition.Targeting.SELF:
		cast_intent.cancel()
		_commit_skill(skill, player.global_position)
		_cancel_aim()
		return
	cast_intent.active_skill = skill
	_update_aim(_world_mouse_point())

func _update_aim(point: Vector2) -> void:
	if player != null and player.world_motion != null:
		if expedition_view != null and not cast_intent.active_skill.is_empty():
			var result := spatial_pointer_skill(cast_intent.active_skill,point,true)
			battle_controls.set_aim_text("PRONTO · clique para confirmar" if result["ok"] else "DESTINO / ALVO INDISPONÍVEL")
		return
	if cast_intent.active_skill.is_empty():
		_update_aim_with_rank(point)
		return
	var previous := player.push_cast_rank(cast_intent.active_skill, _intent_rank)
	if player.selected_cast_rank_valid(cast_intent.active_skill):
		_update_aim_with_rank(point)
	else:
		battle_controls.set_aim_text("Rank do atalho indisponível.")
	player.restore_cast_rank(previous)

func _update_aim_with_rank(point: Vector2) -> void:
	var skill := cast_intent.active_skill
	if geometer_casting != null:
		geometer_casting.preview_command = null
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
	if GeometerCastCommand.is_grammar_skill(skill) and geometer_casting != null:
		battle_indicators.clear_aim()
		geometer_casting.targets = enemies
		var command := geometer_casting.capture(skill, point, Input.is_key_pressed(KEY_SHIFT))
		var preview := geometer_casting.check(command)
		if _world_pointer_available():
			geometer_casting.preview_command = command
			geometer_casting.preview_valid = preview["ok"]
		var destination := "INIMIGO · vínculo móvel" if command.actor_id > 0 else "CHÃO · vértice fixo"
		if skill == &"geometer_collapse":
			destination = "FIGURA ATUAL · consome uma vez"
		var availability: String = "PRONTO" if preview["ok"] else preview["reason"]
		var action := "Solte a tecla ou clique" if cast_intent.mode == CastIntent.Mode.RELEASE else ("Clique para editar" if GeometerCastCommand.is_edit_skill(skill) else "Clique para confirmar")
		battle_controls.set_aim_text("%s · %s · %s | %s | Shift: chão · Esc cancela" % [ClassCatalog.skill_definition(skill).display_name, destination, availability, action])
		bottom_controls.visible = false
		geometer_casting.queue_redraw()
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
	elif skill == &"sentinel_net_shot" and not player.can_place_sentinel_net(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"explosive_trap" and not player.can_place_explosive_trap(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill in HunterMath.NEW_TRAP_IDS and not player.can_place_trap(skill, point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"foliage_shelter" and not player.can_place_foliage_shelter(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"hunter_total_cover" and not player.can_place_hunter_total_cover(point):
		state = "POSIÇÃO BLOQUEADA"
	elif skill == &"hunter_covering_shot" and not player.can_use_hunter_covering_shot(player.aim_direction(point)):
		state = "RECUO BLOQUEADO"
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
	_intent_rank = 0
	cast_intent.cancel()
	action_bar_input.cancel()
	if geometer_casting != null:
		geometer_casting.preview_command = null
		geometer_casting.queue_redraw()
	if battle_indicators != null:
		battle_indicators.clear_aim()
	if battle_controls != null:
		battle_controls.set_aim_text("")
	if bottom_controls != null:
		bottom_controls.visible = player == null or not player.has_active_cast()

func _cancel_casting(cancel_ammunition: bool = true) -> void:
	if player != null:
		player.cancel_active_cast()
		if cancel_ammunition:
			player.cancel_sentinel_preparation()
	_cancel_aim()

func _world_mouse_point() -> Vector2:
	# All keyboard casts use the same viewport event coordinates as clicks.
	# Keep screen space so camera motion is still resolved at confirmation time.
	if _geometer_pointer_screen.is_finite():
		return get_canvas_transform().affine_inverse() * _geometer_pointer_screen
	return get_global_mouse_position()

func _world_pointer_available() -> bool:
	return get_viewport().gui_get_hovered_control() == null

func _handle_geometer_key(key: Key) -> bool:
	if geometer_casting == null or not _world_pointer_available():
		return false
	if key in [KEY_F1, KEY_F2, KEY_F3]:
		_select_geometer_element(GeometerGeometry.ELEMENTS[[KEY_F1, KEY_F2, KEY_F3].find(key)])
		return true
	if key == KEY_F6:
		_clear_geometer_construction()
		return true
	return false

func _select_geometer_element(element: StringName) -> void:
	if geometer_casting == null or run_finished or get_tree().paused or not player.is_alive():
		return
	if geometer_casting.select(element):
		for token: StringName in geometer_element_buttons:
			geometer_element_buttons[token].set_pressed_no_signal(token == element)

func _change_action_slots(slots: Array[Variant]) -> void:
	_cancel_casting(false)
	if not ActionBarLayout.valid_preserving(slots, player.available_skill_ids(), action_slots, ItemSkillAdapters.reference_ids(player.class_id)):
		battle_controls.set_action_bar(player.available_skill_ids(), action_slots, control_preferences)
		return
	if persistent_facade != null and not training_mode:
		var profile := persistent_facade.current_profile()
		var result := persistent_facade.update_action_slots("bar-%d" % Time.get_ticks_usec(), profile.revision, run_state.character_id, slots)
		if not result["ok"]:
			status_label.text = "Não foi possível salvar os atalhos; organização anterior mantida."
			battle_controls.set_action_bar(player.available_skill_ids(), action_slots, control_preferences)
			return
	var changed := action_slots != slots
	action_slots = slots.duplicate(true)
	if changed: _present_ui()
	# No build, rank, stats, cooldown or resource recalculation for shortcut edits.

func _change_action_bindings() -> void:
	_cancel_casting(false)
	if control_preferences.save_settings() != OK:
		status_label.text = "Atalhos válidos nesta sessão; não foi possível salvar os controles."

func _clear_geometer_construction() -> void:
	if geometer_casting == null or run_finished or get_tree().paused or not player.is_alive():
		return
	_cancel_casting()
	geometer_casting.clear_construction()
	status_label.text = "Construção desfeita — elemento selecionado preservado"

func _on_geometer_feedback(message: String) -> void:
	if not run_finished and status_label != null:
		status_label.text = "Traçado: " + message

func _clear_hover() -> void:
	if is_instance_valid(_hovered_enemy):
		_hovered_enemy.set_hovered(false)
	_hovered_enemy = null

func _notification(what: int) -> void:
	if snapshot_passive or _memory_snapshot_pending: return
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_cancel_casting(false)
		_apply_cursor_mode(false)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_apply_cursor_mode(true)

func _toggle_settings(open: bool) -> void:
	if battle_controls.settings_overlay.visible == open: return
	if open and (get_tree().paused or run_finished):
		return
	_cancel_casting(false)
	_clear_hover()
	battle_controls.settings_overlay.visible = open
	class_button.visible = not open
	if not open:
		battle_controls.cancel_binding_capture()
	get_tree().paused = open
	_present_ui(not open)

## F10 Q3: scale and cursor capture are applied live and kept in controls.cfg.
func change_interface_preferences(ui_scale: float, confine_cursor: bool) -> void:
	control_preferences.ui_scale = clampf(ui_scale, GuiMetrics.MIN_SCALE, GuiMetrics.MAX_SCALE)
	control_preferences.confine_cursor = confine_cursor
	_apply_interface_preferences()
	if control_preferences.save_settings() != OK:
		status_label.text = "Interface aplicada; não foi possível salvar a preferência."

func _apply_interface_preferences() -> void:
	if ui_root != null: GuiMetrics.set_scale(control_preferences.ui_scale, ui_root)
	_layout_stage_minimap()
	_apply_cursor_mode(true)

func _camera_zoom_available() -> bool:
	return is_inside_tree() and not snapshot_passive and not _memory_snapshot_pending and not inventory_frozen and not get_tree().paused and not run_finished and is_instance_valid(route_camera)

func change_camera_zoom(step: int) -> void:
	_set_camera_zoom(control_preferences.camera_zoom + float(step) * ControlPreferences.CAMERA_ZOOM_STEP)

func reset_camera_zoom() -> void:
	_set_camera_zoom(1.0)

func _set_camera_zoom(value: float) -> void:
	if not _camera_zoom_available() or not is_finite(value): return
	control_preferences.camera_zoom = snappedf(clampf(value, ControlPreferences.CAMERA_ZOOM_MIN, ControlPreferences.CAMERA_ZOOM_MAX), 0.1)
	route_camera.zoom = Vector2.ONE * control_preferences.camera_zoom
	route_camera.force_update_scroll()
	if is_instance_valid(stage_minimap): stage_minimap.set_camera_zoom(control_preferences.camera_zoom)
	if control_preferences.save_settings() != OK:
		status_label.text = "Zoom aplicado; não foi possível salvar a preferência."

func _build_stage_minimap() -> void:
	stage_minimap = StageMinimap.new()
	stage_minimap.name = "StageMinimap"
	ui_root.add_child(stage_minimap)
	# Keep all modals above the map, including inventory and settings.
	ui_root.move_child(stage_minimap, hud_panel.get_index())
	stage_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stage_minimap.zoom_requested.connect(change_camera_zoom)
	stage_minimap.zoom_reset_requested.connect(reset_camera_zoom)
	stage_minimap.set_camera_zoom(control_preferences.camera_zoom)
	stage_minimap.minimum_size_changed.connect(_layout_stage_minimap)
	ui_root.resized.connect(_layout_stage_minimap)
	bottom_controls.item_rect_changed.connect(_layout_stage_minimap)
	bottom_controls.minimum_size_changed.connect(_layout_stage_minimap)
	class_button.item_rect_changed.connect(_layout_stage_minimap)
	_configure_stage_minimap()
	_layout_stage_minimap()
	_update_stage_minimap(0.1)

func _layout_stage_minimap() -> void:
	if not is_instance_valid(stage_minimap) or ui_root == null: return
	# Use real footer content height and the available root width at the chosen
	# scale. FlowContainer keeps all buttons when a narrower window wraps them.
	if is_instance_valid(bottom_controls) and is_instance_valid(battle_controls):
		var width := minf(1200.0, ui_root.size.x - 48.0)
		bottom_controls.offset_left = -width * 0.5
		bottom_controls.offset_right = width * 0.5
		bottom_controls.offset_bottom = battle_controls.skill_bar.offset_top - 12.0
		bottom_controls.offset_top = bottom_controls.offset_bottom - bottom_controls.get_combined_minimum_size().y
	var extent := stage_minimap.get_combined_minimum_size()
	if extent.x <= 0.0 or extent.y <= 0.0: return
	var bar_top := bottom_controls.position.y if is_instance_valid(bottom_controls) else ui_root.size.y - 286.0
	var map_top := 76.0
	if is_instance_valid(class_button): map_top = maxf(map_top, class_button.position.y + class_button.size.y + 12.0)
	var fit := clampf((bar_top - map_top - 12.0) / extent.y, 0.45, 1.0)
	stage_minimap.scale = Vector2.ONE * fit
	stage_minimap.offset_left = -24.0 - extent.x * fit
	stage_minimap.offset_right = stage_minimap.offset_left + extent.x
	stage_minimap.offset_top = map_top
	stage_minimap.offset_bottom = map_top + extent.y
	if is_instance_valid(help_panel):
		var desired_top := stage_minimap.offset_top + extent.y * fit + 12.0
		# Hidden help still needs a valid rectangle: reopening/resizing must never
		# leave its last layout outside the root. Existing contextual visibility stays.
		help_panel.offset_top = minf(desired_top, ui_root.size.y - 158.0)
		help_panel.offset_bottom = help_panel.offset_top + 146.0
		# Contextual guides (Geometer / Sentinel onboarding) keep replacing the generic help.
		help_panel.visible = geometer_casting == null and not is_instance_valid(sentinel_onboarding) and desired_top + 146.0 < bar_top - 12.0

func _configure_stage_minimap(force: bool = false) -> void:
	if not is_instance_valid(stage_minimap) or not is_instance_valid(player): return
	var world := player.world_motion.geometry if player.world_motion != null else null
	if world != null:
		var same_map: bool = not force and stage_minimap.has_meta("geometry") and stage_minimap.get_meta("geometry") == world and stage_minimap.get_meta("configuration", -1) == world.configuration_revision
		if same_map and stage_minimap.get_meta("revision",-1) == world.geometry_revision: return
		var snapshot := world.presentation_snapshot(world.geometry_revision)
		if not snapshot["ok"]: return
		if same_map:
			stage_minimap.update_obstacles(StageMinimapData.world_obstacles(snapshot["data"]["volumes"]))
			stage_minimap.set_meta("revision",world.geometry_revision)
			return
		var data := StageMinimapData.world_map(snapshot["data"],float(player.world_motion.profile().height))
		stage_minimap.configure_map(data["bounds"], data["surfaces"], data["obstacles"], data["terrain"])
		stage_minimap.set_meta("geometry", world)
		stage_minimap.set_meta("configuration", world.configuration_revision)
		stage_minimap.set_meta("revision",world.geometry_revision)
	elif is_instance_valid(arena_view):
		if not force and stage_minimap.has_meta("flat_map"): return
		var data := StageMinimapData.flat_map(arena_view.bounds, arena_view.obstacles)
		stage_minimap.configure_map(data["bounds"], data["surfaces"], data["obstacles"])
		stage_minimap.set_meta("flat_map", true)

func _update_stage_minimap(delta: float) -> void:
	if not is_instance_valid(stage_minimap) or snapshot_passive: return
	var elapsed := float(stage_minimap.get_meta("elapsed", 0.0)) + delta
	if elapsed < 0.1: stage_minimap.set_meta("elapsed", elapsed); return
	stage_minimap.set_meta("elapsed", 0.0)
	_configure_stage_minimap()
	var markers := StageMinimapData.actor_markers(player, enemies)
	if markers["ok"]: stage_minimap.update_markers(markers["player"], markers["heading"], markers["enemies"])
	stage_minimap.set_zoom_enabled(_camera_zoom_available())

func _apply_cursor_mode(focused: bool) -> void:
	if DisplayServer.get_name() == "headless": return
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED if control_preferences.confine_cursor and focused else Input.MOUSE_MODE_VISIBLE

func _change_control_preferences(mode: int, smart_lock: bool) -> void:
	_cancel_casting(false)
	_clear_hover()
	cast_intent.set_mode(mode)
	control_preferences.cast_mode = mode
	control_preferences.smart_lock = smart_lock
	if control_preferences.save_settings() != OK:
		status_label.text = "Controles aplicados; não foi possível salvar a preferência."

func _spawn_encounter(index: int) -> void:
	if is_instance_valid(player) and player.world_motion != null:
		world_spawn_error = &"world_lifecycle_required"
		return # Stage switching is outside F1; never relocate a bound actor using pixels.
	_clear_admin_spawns()
	if reward_feedback != null:
		reward_feedback.hide_history()
	encounter_index = index
	encounter_active = true
	_credited_kills.clear()
	_reward_retry_pending = false
	next_button.visible = false
	augment_button.disabled = true
	if gameplay_extension:
		_configure_world(index)
		player.global_position = PlaytestGameplay.ENTRANCE
		player.move_to(player.global_position)
		if route_camera != null: route_camera.reset_smoothing()
		for entry: Dictionary in PlaytestGameplay.spawns(index, rng):
			_spawn_route_enemy(entry, index)
		status_label.text = "%s · encontro %d/6 — puxe grupos e encontre o cristal após vencer" % [PlaytestGameplay.AREA_NAMES[int((index - 1) / 2.0)], index]
		return
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
	if is_instance_valid(player) and player.world_motion != null: world_spawn_error = &"world_birth_required"; return null
	var enemy := EnemyActor.new()
	enemy.configure(enemy_type, navigation, player)
	# The Geometer's area already defines occupancy; do not cover it with status rings.
	enemy.compact_control_visuals = player.is_geometer() or player.is_sentinel()
	enemy.global_position = spawn_position
	enemy.attack_requested.connect(_on_enemy_attack_requested)
	enemy.mob_skill_requested.connect(_on_mob_skill_requested)
	enemy.actor_died.connect(_on_enemy_died)
	enemy.health.damage_applied.connect(_on_enemy_damage_resolved)
	enemy.damage_number.connect(_show_damage_number)
	enemy.attack_missed.connect(_show_miss)
	enemy.status_damage_requested.connect(_on_attack_requested)
	add_child(enemy)
	enemies.append(enemy)
	if reward_service != null and reward_service.mob_loot_enabled():
		var registered := reward_service.register_mob_actor(enemy)
		assert(registered["ok"], str(registered))
	if trap_registry != null:
		for trap: PlayerTrap in trap_registry.active_traps():
			if trap is HunterTrap:
				(trap as HunterTrap).track_target(enemy)
	if is_instance_valid(hunter_tar_field) and hunter_tar_field.active:
		hunter_tar_field.track_target(enemy)
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

func _bind_world_projectile(projectile: Node, source: CombatActor, victim: CombatActor) -> Dictionary:
	if source == null or source.world_motion == null or not is_instance_valid(victim) or victim.world_motion == null: return {"ok":false,"error_code":&"incompatible_target"}
	var radius: float = projectile.projectile_radius
	var height := radius*2.0
	var offset := Vector3.UP*maxf(0.0,(float(source.world_motion.profile()["height"])-height)*0.5)
	var endpoint := victim.world_point().position+Vector3.UP*(float(victim.world_motion.profile()["height"])-height)*0.5
	var heading := endpoint-source.world_point().position-offset
	if heading.is_zero_approx(): heading = Vector3.RIGHT
	if geometer_casting != null: projectile.geometer_field = geometer_casting.wall_field
	return projectile.bind_world_flight(source.world_motion.geometry,source.world_point(),offset,heading,{"radius":radius,"height":height},source.world_motion.geometry.geometry_revision)

func _on_world_attack_requested(request: DamageRequest, victim: CombatActor, kind: StringName) -> void:
	if player.world_motion == null or not is_instance_valid(victim) or not victim.is_alive(): return
	if kind == &"direct":
		if player.can_basic_attack(victim,true): _on_attack_requested(request,victim)
		return
	var projectile: PlayerProjectile = MageProjectile.new() if kind == &"mage" else PlayerProjectile.new()
	var speed := PlayerActor.MAGE_BASIC_SPEED if kind == &"mage" else PlayerActor.ARCHER_BASIC_SPEED
	var maximum_range := PlayerActor.MAGE_BASIC_MAX_DISTANCE if kind == &"mage" else player.archer_basic_projectile_range()
	var targets: Array[CombatActor] = []
	if kind == &"mage": targets.append(victim)
	else: targets.assign(enemies)
	projectile.configure_directional(request.copy(),Vector2.ZERO,Vector2.RIGHT,targets,navigation,speed,maximum_range)
	var result := _bind_world_projectile(projectile,player,victim)
	if not result["ok"]: projectile.free(); return
	projectile.hit.connect(_on_mage_projectile_hit if kind == &"mage" else _on_precision_projectile_hit)
	add_child(projectile)
	projectile.add_to_group("player_projectiles")

func _on_attack_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor != null and target_actor.is_alive():
		target_actor.apply_damage(request, rng)

func _on_world_defender_hit_requested(request: DamageRequest, target_actor: CombatActor, root_duration: float, push: Vector3) -> void:
	_on_defender_hit_requested(request,target_actor,root_duration,Vector2.ZERO,push)

func _on_defender_hit_requested(request: DamageRequest, target_actor: CombatActor, root_duration: float, push_direction: Vector2, world_push: Vector3 = Vector3.ZERO) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if not bool(result.get("can_trigger_effects", false)) or float(result.get("actual_damage", 0.0)) <= 0.0 or not target_actor.is_alive():
		return
	if root_duration > 0.0:
		target_actor.apply_root(root_duration, &"physical")
	if not world_push.is_zero_approx() and target_actor is EnemyActor and target_actor.world_motion != null:
		(target_actor as EnemyActor).apply_world_defender_push_direction(world_push,PlayerActor.DEFENDER_PUSH_DISTANCE,target_actor.world_motion.geometry.geometry_revision)
	elif not push_direction.is_zero_approx() and target_actor is EnemyActor:
		(target_actor as EnemyActor).apply_defender_push(push_direction, PlayerActor.DEFENDER_PUSH_DISTANCE)

func _on_berserker_rift_hit_requested(request: DamageRequest, target_actor: CombatActor, bleed_request: DamageRequest) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if bool(result.get("can_trigger_effects", false)) and float(result.get("actual_damage", 0.0)) > 0.0 and target_actor.is_alive():
		target_actor.apply_bleed(bleed_request, float(bleed_request.effect_snapshot.get("bleed_duration", PlayerActor.BERSERKER_RIFT_BLEED_DURATION)))

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
	if is_instance_valid(player) and player.world_motion != null: player._update_defender_anchor_presence()
	var active := player != null and is_instance_valid(player) and player.has_defender_anchor()
	for enemy_id: int in _defender_slowed_enemies.keys():
		var previous: CombatActor = _defender_slowed_enemies[enemy_id]
		if not is_instance_valid(previous) or not active or not player.defender_anchor_contains(previous):
			if is_instance_valid(previous):
				previous.remove_attribute_debuff(AttributeDebuffState.MOVE_SPEED, &"defender_anchor")
			_defender_slowed_enemies.erase(enemy_id)
	if not active:
		return
	for enemy: CombatActor in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive() or not player.defender_anchor_contains(enemy):
			continue
		if not _defender_slowed_enemies.has(enemy.get_instance_id()):
			_defender_slowed_enemies[enemy.get_instance_id()] = enemy
			enemy.apply_slow(PlayerActor.DEFENDER_ANCHOR_SLOW_FRACTION, player.defender_anchor_remaining, &"defender_anchor")

func cast_world_skill(skill: StringName, anchor: ExpeditionWorldPoint, facing: Vector3, victim: CombatActor, revision: int, rank: int = 0, field_height: float = 0.0) -> Dictionary:
	if not is_instance_valid(player): return WorldSkillCast.failure(&"spatial_binding_required")
	if geometer_casting != null and geometer_casting.wall_field != null and skill in WorldSkillCast.PROJECTILES and not geometer_casting.wall_field.supports_world(player.world_motion.geometry): return WorldSkillCast.failure(&"spatial_interceptor_required")
	return player.request_world_skill(skill,anchor,facing,victim,enemies,revision,rank,field_height)

func _spawn_world_cast_projectiles(skill: StringName, request: DamageRequest, victim: CombatActor, hit_limit: int, callback: Callable, mage: bool, tint: Color, discharge_bonus: float = 0.0, sentinel: bool = false) -> void:
	if not player.world_motion.is_current_world(): return
	# Origins, dimensions, count and rank-sensitive speed/range were validated together before cost.
	for spec: Dictionary in player.world_cast_projectiles(skill):
		var projectile: PlayerProjectile = MageProjectile.new() if mage else (SentinelProjectile.new() if sentinel else PlayerProjectile.new())
		if (mage and skill in [&"fire_spear",&"ice_spear",&"lightning"]) or (sentinel and skill != &"sentinel_piercing_shot"):
			projectile.configure_homing(request.copy(),victim,Vector2.ZERO,navigation,spec["speed"],spec["range"],tint)
		else:
			projectile.configure_directional(request.copy(),Vector2.ZERO,Vector2.RIGHT,enemies,navigation,spec["speed"],spec["range"],hit_limit,tint)
		if projectile is MageProjectile: (projectile as MageProjectile).electrified_bonus_magic_damage = discharge_bonus
		var point := ExpeditionWorldPoint.create(spec["origin"]["stage_id"],spec["origin"]["surface_id"],spec["origin"]["position"])
		if geometer_casting != null: projectile.geometer_field = geometer_casting.wall_field
		var bound := projectile.bind_world_flight(player.world_motion.geometry,point,spec["offset"],spec["direction"],spec["collider"],player.world_motion.geometry.geometry_revision)
		if not bound["ok"]: projectile.free(); continue
		projectile.hit.connect(callback)
		add_child(projectile)
		projectile.add_to_group("player_projectiles")

func _bind_cast_ground(effect: Node) -> bool:
	if not player.world_motion.is_current_world(): return false
	var anchor := player.world_cast_anchor()
	if anchor == null: return false
	return effect.bind_world_area(player.world_motion.geometry,anchor,player.world_motion.profile(),player.world_motion.geometry.geometry_revision)["ok"]

func _cast_ground_area() -> WorldEffectArea:
	if not player.world_motion.is_current_world(): return null
	var anchor := player.world_cast_anchor()
	if anchor == null: return null
	var area := WorldEffectArea.new()
	var result := area.configure(player.world_motion.geometry,anchor,player.world_motion.profile(),&"ground_connected",player.world_motion.geometry.geometry_revision)
	return area if result["ok"] else null

func _on_mage_projectile_requested(skill_id: StringName, request: DamageRequest, target_actor: CombatActor, direction: Vector2, count: int) -> void:
	if player.world_motion != null:
		var tint := Color("e9d76a") if skill_id == &"lightning" else Color("74c9ff") if skill_id == &"ice_spear" else Color("ff793d")
		_spawn_world_cast_projectiles(skill_id,request,target_actor,1,_on_mage_projectile_hit,true,tint)
		return
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
		if geometer_casting != null:
			projectile.geometer_field = geometer_casting.wall_field
		add_child(projectile)
		projectile.add_to_group("player_projectiles")

func _on_precision_projectile_requested(skill_id: StringName, request: DamageRequest, _target_actor: CombatActor, direction: Vector2, count: int, hit_limit: int) -> void:
	_spawn_precision_projectiles(skill_id, request, direction, count, hit_limit, _on_precision_projectile_hit)

func _on_sentinel_projectile_requested(request: DamageRequest, target_actor: CombatActor, direction: Vector2, payload: Dictionary) -> void:
	if player.world_motion != null:
		if request.skill_id in [&"sentinel_net_shot",&"sentinel_explosive_shot"]:
			_spawn_world_sentinel_area(request,target_actor,payload)
			return
		if request.skill_id not in [&"sentinel_headshot",&"sentinel_piercing_shot",&"sentinel_concussion_shot"]: return
		_spawn_world_cast_projectiles(request.skill_id,request,target_actor,20 if request.skill_id == &"sentinel_piercing_shot" else 1,_on_sentinel_direct_hit.bind(payload.duplicate(true)),false,Color("a6e3ee") if request.skill_id == &"sentinel_piercing_shot" else Color("d7f0de"),0.0,true)
		return
	if request.skill_id in [&"sentinel_net_shot", &"sentinel_explosive_shot"]:
		var area := SentinelAreaProjectile.new()
		var origin := player.global_position + PlayerProjectile.BODY_OFFSET
		if request.skill_id == &"sentinel_net_shot":
			area.configure_directional(request.copy(), origin, direction, enemies, navigation, float(payload["projectile_speed"]), float(payload["range"]))
			area.endpoint = Vector2(payload["endpoint"]) + PlayerProjectile.BODY_OFFSET
		else:
			area.configure_homing(request.copy(), target_actor, origin, navigation, float(payload["projectile_speed"]), float(payload["range"]), Color("ffbf69"))
		area.payload = payload.duplicate(true)
		area.burst.connect(_on_sentinel_burst)
		add_child(area)
		area.add_to_group("player_projectiles")
		return
	var projectile := SentinelProjectile.new()
	var origin := player.global_position + PlayerProjectile.BODY_OFFSET
	if request.skill_id == &"sentinel_piercing_shot":
		projectile.configure_directional(request.copy(), origin, direction, enemies, navigation, float(payload["projectile_speed"]), float(payload["range"]), 20, Color("a6e3ee"))
	else:
		projectile.configure_homing(request.copy(), target_actor, origin, navigation, float(payload["projectile_speed"]), float(payload["range"]), Color("d7f0de"))
	projectile.direction = direction
	projectile.hit.connect(_on_sentinel_direct_hit.bind(payload.duplicate(true)))
	add_child(projectile)
	projectile.add_to_group("player_projectiles")

func _spawn_world_sentinel_area(request: DamageRequest, victim: CombatActor, payload: Dictionary) -> void:
	if not player.world_motion.is_current_world(): return
	for spec: Dictionary in player.world_cast_projectiles(request.skill_id):
		var area := SentinelAreaProjectile.new()
		if request.skill_id == &"sentinel_net_shot": area.configure_directional(request.copy(),Vector2.ZERO,Vector2.RIGHT,enemies,navigation,spec["speed"],spec["range"])
		else: area.configure_homing(request.copy(),victim,Vector2.ZERO,navigation,spec["speed"],spec["range"],Color("ffbf69"))
		area.payload = payload.duplicate(true)
		var valid := area.bind_world_delivery(player.world_motion.geometry,spec,player.world_motion.profile(),player.world_cast_anchor())
		if not valid["ok"]: area.free(); continue
		area.world_burst.connect(_on_world_sentinel_burst)
		add_child(area)
		area.add_to_group("player_projectiles")

func _on_world_sentinel_burst(area: WorldEffectArea, center: Vector3, request: DamageRequest, payload: Dictionary) -> void:
	_on_sentinel_burst(Vector2.ZERO,request,payload,area,center)

func _on_sentinel_direct_hit(request: DamageRequest, enemy: CombatActor, payload: Dictionary) -> void:
	if not is_instance_valid(enemy) or not enemy.is_alive():
		return
	var result := enemy.apply_damage(request, rng)
	if float(result.get("actual_damage", 0.0)) <= 0.0:
		return
	if request.skill_id == &"sentinel_concussion_shot" and enemy.is_alive():
		enemy.apply_stun(float(payload["stun_duration"]))
		enemy.apply_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, &"sentinel_concussion_shot", float(payload["damage_dealt_reduction"]), float(payload["duration"]))
	_show_sentinel_visual(request.skill_id, enemy.global_position + PlayerProjectile.BODY_OFFSET, 20.0)

func _on_sentinel_burst(center: Vector2, request: DamageRequest, payload: Dictionary, world_area: WorldEffectArea = null, world_center: Vector3 = Vector3.ZERO) -> void:
	if world_area == null: _show_sentinel_visual(request.skill_id, center, float(payload["radius"]))
	var seen: Dictionary[int, bool] = {}
	# Death callbacks remove actors from enemies synchronously.
	for candidate: Variant in enemies.duplicate():
		if not is_instance_valid(candidate): continue
		var enemy := candidate as CombatActor
		if enemy == null or not enemy.is_alive() or seen.has(enemy.get_instance_id()): continue
		if world_area != null:
			if not _world_sentinel_burst_contains(world_area,world_center,enemy,float(payload["radius"]),request.skill_id): continue
		elif center.distance_to(enemy.global_position) > float(payload["radius"]) + enemy.collision_radius or not navigation.is_segment_clear(center + PlayerProjectile.BODY_OFFSET, enemy.global_position + PlayerProjectile.BODY_OFFSET, 0.0): continue
		seen[enemy.get_instance_id()] = true
		var hit_request := request.copy()
		hit_request.target_id = enemy.get_instance_id()
		# Health emits the direct impact/proc before any new root is applied.
		var result := enemy.apply_damage(hit_request, rng)
		if is_instance_valid(enemy) and enemy.is_alive() and float(result.get("actual_damage", 0.0)) > 0.0 and request.skill_id == &"sentinel_net_shot":
			enemy.apply_root(float(payload["root_duration"]), &"magic")

func _world_sentinel_burst_contains(area: WorldEffectArea, center: Vector3, enemy: CombatActor, radius: float, skill: StringName) -> bool:
	if not area.is_current_world() or enemy.world_motion == null or not enemy.world_motion.is_current_world() or enemy.world_motion.geometry != area.geometry: return false
	if skill == &"sentinel_net_shot":
		if not area.contains_actor(enemy,radius): return false
		var sight := area.geometry.query_attack({"geometry_rule_id":&"direct_volume","range":1.0e20},area.anchor(),enemy.world_point(),area.geometry.geometry_revision)
		return sight["ok"] and sight["data"]["hit"]
	var body := enemy.world_motion.profile()
	var query := area.query(enemy,radius+float(body["radius"]),{"source_offset":center-area.anchor().position,"target_offset":Vector3.UP*float(body["height"])*0.5})
	return query["ok"] and query["data"]["hit"]

func _show_sentinel_visual(skill: StringName, center: Vector2, radius: float) -> void:
	# Cosmetic scene budget independent of hit count, never suppresses damage/CC.
	var count := 0
	for child: Node in get_children():
		if child is SentinelBurst and not child.is_queued_for_deletion():
			count += 1
	if count >= 12:
		return
	var visual := SentinelBurst.new()
	visual.skill_id = skill
	visual.radius = radius
	visual.position = center
	add_child(visual)
	visual.add_to_group("player_effects")

func _on_discharge_requested(request: DamageRequest, direction: Vector2, bonus_magic_damage: float) -> void:
	if player.world_motion != null:
		_spawn_world_cast_projectiles(&"electric_discharge",request,null,1,_on_discharge_hit,true,Color("ffe37a"),bonus_magic_damage)
		return
	var projectile := MageProjectile.new()
	var origin := player.global_position + PlayerProjectile.BODY_OFFSET
	projectile.configure_directional(request.copy(), origin, direction, enemies, navigation, player.skill_projectile_speed(&"electric_discharge"), player.skill_range(&"electric_discharge"), 1, Color("ffe37a"))
	projectile.electrified_bonus_magic_damage = bonus_magic_damage
	projectile.hit.connect(_on_discharge_hit)
	if geometer_casting != null:
		projectile.geometer_field = geometer_casting.wall_field
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

func _spawn_precision_projectiles(skill_id: StringName, request: DamageRequest, direction: Vector2, count: int, hit_limit: int, hit_callback: Callable, visual_color: Color = Color("f6dfad"), captured_origin: Vector2 = Vector2.INF) -> void:
	if player.world_motion != null:
		_spawn_world_cast_projectiles(skill_id,request,null,hit_limit,hit_callback,false,visual_color)
		return
	for index: int in range(count):
		var projectile := PlayerProjectile.new()
		var side_offset := direction.orthogonal() * (float(index) - float(count - 1) * 0.5) * 14.0
		var origin := (captured_origin if captured_origin.is_finite() else player.global_position + PlayerProjectile.BODY_OFFSET) + side_offset
		var speed := PlayerActor.ARCHER_BASIC_SPEED if skill_id == &"basic_attack" else player.skill_projectile_speed(skill_id)
		var max_distance := player.archer_basic_projectile_range() if skill_id == &"basic_attack" else player.skill_range(skill_id)
		projectile.configure_directional(request.copy(), origin, direction, enemies, navigation, speed, max_distance, hit_limit, visual_color)
		projectile.hit.connect(hit_callback)
		if geometer_casting != null:
			projectile.geometer_field = geometer_casting.wall_field
		add_child(projectile)
		projectile.add_to_group("player_projectiles")

func _on_precision_projectile_hit(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor != null and is_instance_valid(target_actor) and target_actor.is_alive():
		target_actor.apply_damage(request, rng)

func _on_arrow_rain_requested(center: Vector2, request: DamageRequest) -> void:
	var rain := ArrowRain.new()
	rain.configure(center, request, enemies)
	if player.world_motion != null and not _bind_cast_ground(rain): rain.free(); return
	rain.hit.connect(_on_precision_projectile_hit)
	add_child(rain)
	rain.add_to_group("player_effects")

func _on_snare_trap_requested(center: Vector2, root_duration: float) -> void:
	var trap := SnareTrap.new()
	trap.configure_snare(player.get_instance_id(), center, root_duration, enemies, player.trap_armed_duration(SnareTrap.ARMED_DURATION))
	if player.world_motion != null and not _bind_cast_ground(trap): trap.free(); return
	if player.is_hunter():
		trap.target_filter = _hunter_trap_target_valid.bind(center,trap.world_area)
		trap.root_applied.connect(_on_hunter_snare_triggered.bind(player.hunter_opening_snapshot(&"snare_trap")))
	trap_registry.register_trap(trap)

func _on_hunter_snare_triggered(trap: SnareTrap, victim: CombatActor, _applied_duration: float, snapshot: DamageRequest) -> void:
	if not _hunter_trap_target_valid(victim,trap.global_position,trap.world_area):
		return
	player.activate_hunter_opening(trap.get_instance_id(), victim, snapshot)

func _hunter_trap_target_valid(victim: CombatActor, center: Vector2, area: WorldEffectArea = null) -> bool:
	if not is_instance_valid(player) or not player.is_alive() or not is_instance_valid(victim) or not victim.is_alive() or victim.is_queued_for_deletion(): return false
	if player.world_motion != null:
		if area == null or not player.world_motion.is_current_world() or not area.is_current_world() or area.geometry != player.world_motion.geometry: return false
		var ground := area.query(victim,1.0e20)
		if not ground["ok"] or not ground["data"]["hit"]: return false
		# Hunter's explicit nominal LoS is additional to connected ground membership.
		var sight := area.geometry.query_attack({"geometry_rule_id":&"direct_volume","range":1.0e20},area.anchor(),victim.world_point(),area.geometry.geometry_revision)
		return sight["ok"] and sight["data"]["hit"]
	return victim.world_motion == null and area == null and navigation != null and navigation.is_segment_clear(center,victim.global_position,0.0)

func _on_explosive_trap_requested(center: Vector2, request: DamageRequest) -> void:
	var trap := ExplosiveTrap.new()
	trap.configure_explosive(player.get_instance_id(), center, request, enemies, player.trap_armed_duration(ExplosiveTrap.ARMED_DURATION))
	if player.world_motion != null and not _bind_cast_ground(trap): trap.free(); return
	if player.is_hunter():
		trap.target_filter = _hunter_trap_target_valid.bind(center,trap.world_area)
		trap.reaction_callback = _consume_hunter_tar.bind(trap.world_area)
		trap.hit.connect(_on_hunter_explosive_hit.bind(trap.get_instance_id(), center, player.hunter_opening_snapshot(&"explosive_trap"),trap.world_area))
	else:
		trap.hit.connect(_on_precision_projectile_hit)
	trap_registry.register_trap(trap)

func _on_hunter_trap_requested(center: Vector2, rank: int, request: DamageRequest, opening: DamageRequest) -> void:
	var trap := HunterTrap.new()
	trap.configure_hunter(center, rank, request, opening, enemies, player.trap_armed_duration(HunterTuning.ARMED_TRAP_LIFETIME))
	if player.world_motion != null and not _bind_cast_ground(trap): trap.free(); return
	trap.target_filter = _hunter_trap_target_valid.bind(center,trap.world_area)
	trap.sprung.connect(_on_hunter_trap_sprung)
	trap_registry.register_trap(trap)

func _on_hunter_trap_sprung(trap: HunterTrap, victims: Array[CombatActor]) -> void:
	if not is_instance_valid(player) or not player.is_alive() or get_tree().paused or run_finished:
		return
	if is_instance_valid(player.hunter_presentation):
		player.hunter_presentation.notify_trap(trap.global_position, trap.source_skill_id, trap.effect_radius)
	if trap.source_skill_id == &"hunter_tar_trap":
		_clear_hunter_tar()
		hunter_tar_field = HunterTarField.new()
		if player.world_motion != null:
			if trap.world_area == null or not trap.world_area.is_current_world() or not player.world_motion.is_current_world(): hunter_tar_field.free(); hunter_tar_field = null; return
			var bound := hunter_tar_field.bind_world_area(player.world_motion.geometry,trap.world_area.anchor(),player.world_motion.profile(),player.world_motion.geometry.geometry_revision)
			if not bound["ok"]: hunter_tar_field.free(); hunter_tar_field = null; return
		hunter_tar_field.configure_tar(player, trap.global_position, trap.tuning, enemies)
		hunter_tar_field.target_filter = _hunter_trap_target_valid.bind(trap.global_position,hunter_tar_field.world_area)
		add_child(hunter_tar_field)
		hunter_tar_field.add_to_group("player_effects")
		hunter_tar_field.refresh_occupants()
	for candidate: Variant in victims:
		if not is_instance_valid(candidate): continue
		var victim := candidate as CombatActor
		if run_finished or not _hunter_trap_target_valid(victim,trap.global_position,trap.world_area): continue
		player.activate_hunter_opening(trap.get_instance_id(), victim, trap.opening_request)
		if trap.source_skill_id == &"hunter_tar_trap":
			continue
		var request := trap.damage_request.copy()
		request.target_id = victim.get_instance_id()
		if trap.source_skill_id == &"hunter_freezing_trap":
			victim.apply_root(float(trap.tuning["root_duration"]), &"magic")
		else:
			victim.apply_slow(float(trap.tuning["slow_fraction"]), float(trap.tuning["slow_duration"]), &"hunter_thorn_trap")
			var bleed := request.copy()
			bleed.skill_id = &"hunter_thorn_bleed"
			bleed.physical_damage *= float(trap.tuning["bleed_fraction"])
			victim.apply_bleed(bleed, float(trap.tuning["bleed_duration"]))
		_on_precision_projectile_hit(request, victim)

func _consume_hunter_tar(center: Vector2, blast_radius: float, area: WorldEffectArea = null) -> float:
	if not is_instance_valid(hunter_tar_field) or not is_instance_valid(player) or hunter_tar_field.owner_id != player.get_instance_id() or run_finished:
		return 0.0
	if player.world_motion != null:
		if area == null or not area.is_current_world() or not player.world_motion.is_current_world() or area.geometry != player.world_motion.geometry: return 0.0
		return hunter_tar_field.consume_for_world_explosion(area.anchor(),blast_radius)
	return hunter_tar_field.consume_for_explosion(center, blast_radius, navigation)

func _clear_hunter_tar() -> void:
	if is_instance_valid(hunter_tar_field):
		hunter_tar_field.expire()
	hunter_tar_field = null

func _clear_hunter_trap_effects() -> void:
	_clear_hunter_tar()
	if not is_instance_valid(player):
		return
	var bleed_key := "%d:hunter_thorn_bleed" % player.get_instance_id()
	for victim: CombatActor in enemies:
		if victim != null and is_instance_valid(victim):
			victim.bleed_streams.erase(bleed_key)
			victim.remove_attribute_debuff(AttributeDebuffState.MOVE_SPEED, HunterTarField.slow_source(player.get_instance_id()))
			victim.remove_attribute_debuff(AttributeDebuffState.MOVE_SPEED, &"hunter_thorn_trap")

func _on_hunter_explosive_hit(request: DamageRequest, victim: CombatActor, activation_id: int, center: Vector2, snapshot: DamageRequest, area: WorldEffectArea = null) -> void:
	if run_finished or not _hunter_trap_target_valid(victim,center,area):
		return
	player.activate_hunter_opening(activation_id, victim, snapshot)
	# Mark before applying damage: lethal callbacks may remove all enemy nodes.
	_on_precision_projectile_hit(request, victim)

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
	_spawn_foliage_shelter(center, duration, FoliageShelter.RADIUS, 0.0)

func _on_hunter_total_cover_requested(center: Vector2, duration: float, radius: float, exit_grace: float) -> void:
	_spawn_foliage_shelter(center, duration, radius, exit_grace)

func _on_hunter_covering_shot_requested(request: DamageRequest, origin: Vector2, direction: Vector2) -> void:
	_spawn_precision_projectiles(&"hunter_covering_shot", request, direction, 1, 1, _on_precision_projectile_hit, Color("e2d3a0"), origin)

func _spawn_foliage_shelter(center: Vector2, duration: float, radius: float, exit_grace: float) -> void:
	if not is_instance_valid(player) or not player.is_alive() or run_finished or get_tree().paused:
		return
	if player.is_hunter():
		for node: Node in get_tree().get_nodes_in_group("foliage_shelters"):
			if is_instance_valid(node) and node is FoliageShelter and node.player_owner == player:
				node.expire(&"replaced")
				# Removal signals can finish the encounter or invalidate the owner.
				if not is_instance_valid(player) or not player.is_alive() or run_finished or get_tree().paused:
					return
	var shelter := FoliageShelter.new()
	if player.world_motion != null:
		var anchor := player.world_cast_anchor()
		if anchor == null or not player.world_motion.is_current_world(): shelter.free(); return
		var bound := shelter.configure_world(player,anchor,player.world_motion.profile(),duration,radius,exit_grace,player.world_motion.geometry.geometry_revision)
		if not bound["ok"]: shelter.free(); return
		add_child(shelter)
	else:
		add_child(shelter)
		shelter.configure(player, center, duration, radius, exit_grace)
	shelter.add_to_group("player_effects")

func _on_mage_projectile_hit(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(_elementalist_resonance_request(request, target_actor), rng)
	if result.is_empty() or not bool(result["landed"]) or float(result["actual_damage"]) <= 0.0:
		return
	SkillImpactRules.spear(request.skill_id, result, target_actor)
	if request.skill_id == &"lightning" and target_actor.is_alive():
		target_actor.apply_electrified(4.0)

func _on_fire_wall_requested(direction: Vector2, burn_request: DamageRequest) -> void:
	var wall := FireWall.new()
	wall.configure(player, direction, burn_request, enemies, player.skill_range(&"fire_wall"))
	if player.world_motion != null:
		var field := player.world_cast_field(&"fire_wall")
		if field == null or not wall.bind_world_field(field)["ok"]: wall.free(); return
	add_child(wall)
	wall.add_to_group("player_effects")

func _on_elementalist_flame_burst_requested(center: Vector2, request: DamageRequest) -> void:
	_on_elementalist_area_requested(&"elementalist_flame_burst", center, SkillGeometry.ELEMENTALIST_FLAME_BURST_RADIUS, request, &"fire")

func _on_world_elementalist_area_requested(skill_id: StringName, area: WorldEffectArea, radius: float, request: DamageRequest, element: StringName, marked_bonus: float, once_per_target: bool, hit_ids: Dictionary) -> void:
	_on_elementalist_area_requested(skill_id,Vector2.ZERO,radius,request,element,marked_bonus,once_per_target,hit_ids,area)

func _on_elementalist_area_requested(skill_id: StringName, center: Vector2, radius: float, request: DamageRequest, element: StringName, marked_bonus: float = 0.0, once_per_target: bool = false, hit_ids: Dictionary = {}, world_area: WorldEffectArea = null) -> void:
	if player.world_motion != null and world_area == null:
		world_area = _cast_ground_area()
		if world_area == null: return
	if world_area == null and battle_indicators != null: battle_indicators.show_elementalist_pulse(skill_id, center, radius, element)
	elif world_area != null and expedition_view != null: expedition_view.show_elementalist_pulse(skill_id, world_area.anchor().position, radius, element)
	for target_actor: CombatActor in enemies.duplicate():
		if not is_instance_valid(player): return
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if world_area != null:
			if not world_area.contains_actor(target_actor,radius): continue
		elif target_actor.world_motion != null or center.distance_to(target_actor.global_position) > radius+target_actor.collision_radius or not navigation.is_segment_clear(center,target_actor.global_position,0.0):
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
	if player.world_motion != null:
		sequence.world_pulse_requested.connect(_on_world_elementalist_area_requested)
		var anchors := player.world_cast_ground_points(&"elementalist_ember_path")
		var valid := sequence.configure_world(player,anchors,requests,elements,SkillGeometry.ELEMENTALIST_EMBER_PATH_RADIUS,0.15,true,player.world_motion.geometry.geometry_revision)
		if not valid["ok"]: sequence.queue_free()
	else:
		sequence.configure(player, centers, requests, elements, SkillGeometry.ELEMENTALIST_EMBER_PATH_RADIUS, 0.15, true)

func _on_elementalist_tri_nova_requested(center: Vector2, requests: Array[DamageRequest], marked_bonus: float) -> void:
	var centers: Array[Vector2] = [center, center, center]
	var elements: Array[StringName] = [&"fire", &"ice", &"lightning"]
	var sequence := ElementalistSequenceScript.new()
	sequence.pulse_requested.connect(_on_elementalist_area_requested)
	add_child(sequence)
	sequence.add_to_group("player_effects")
	if player.world_motion != null:
		var anchor := player.world_cast_anchor()
		if anchor == null: sequence.queue_free(); return
		sequence.world_pulse_requested.connect(_on_world_elementalist_area_requested)
		var anchors: Array[ExpeditionWorldPoint] = [anchor,anchor,anchor]
		var valid := sequence.configure_world(player,anchors,requests,elements,SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS,0.25,false,player.world_motion.geometry.geometry_revision,marked_bonus)
		if not valid["ok"]: sequence.queue_free()
	else:
		sequence.configure(player, centers, requests, elements, SkillGeometry.ELEMENTALIST_TRI_NOVA_RADIUS, 0.25, false, marked_bonus)

func _apply_elementalist_hit(request: DamageRequest, target_actor: CombatActor, element: StringName, marked_bonus: float = 0.0) -> Dictionary:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return {}
	var bridge := presentation_events()
	if bridge != null: bridge.note_element(target_actor, element) # Presentation hint: the element is only known here.
	var marked := element == &"lightning" and target_actor.is_electrified()
	var resolved_request := _elementalist_resonance_request(request, target_actor)
	resolved_request.target_id = target_actor.get_instance_id()
	if marked:
		resolved_request.magic_damage += marked_bonus
	var result := target_actor.apply_damage(resolved_request, rng)
	if float(result.get("actual_damage", 0.0)) <= 0.0 or not is_instance_valid(target_actor):
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

func _on_world_elementalist_lightning_arc_requested(request: DamageRequest, target_actor: CombatActor, jump_damage: float, marked_bonus: float) -> void:
	if not player.world_motion.is_current_world(): return
	var origin := WorldEffectArea.new()
	if not origin.configure(player.world_motion.geometry,player.world_point(),player.world_motion.profile(),&"direct_volume",player.world_motion.geometry.geometry_revision)["ok"]: return
	var source_height := float(player.world_motion.profile()["height"])*0.5
	var reach := player.skill_range(&"elementalist_lightning_arc")
	var visited: Array[int] = []
	var current := target_actor
	var visual_from := player.world_point().position + Vector3.UP * source_height # Presentation only.
	for index: int in range(3):
		if not is_instance_valid(current) or not current.is_alive() or current.world_motion == null: break
		var shape := {"source_offset":Vector3.UP*source_height,"target_offset":Vector3.UP*float(current.world_motion.profile()["height"])*0.5}
		var admission := origin.query(current,reach,shape)
		if not admission["ok"] or not admission["data"]["hit"]: break
		# Capture the next source before death/reentry callbacks can remove its actor.
		var next_origin := WorldEffectArea.new()
		if not next_origin.configure(origin.geometry,current.world_point(),current.world_motion.profile(),&"direct_volume",origin.geometry.geometry_revision)["ok"]: break
		source_height = float(current.world_motion.profile()["height"])*0.5
		visited.append(current.get_instance_id())
		if expedition_view != null:
			var visual_to := current.world_point().position + Vector3.UP * source_height
			expedition_view.show_elementalist_arc_link(visual_from, visual_to)
			expedition_view.show_elementalist_pulse(&"elementalist_lightning_arc", current.world_point().position, 30.0, &"lightning")
			visual_from = visual_to
		var hit_request := request.copy()
		if index > 0:
			hit_request.magic_damage = jump_damage
			hit_request.is_secondary = true
		var result := _apply_elementalist_hit(hit_request,current,&"lightning",marked_bonus)
		if float(result.get("actual_damage",0.0)) <= 0.0: break
		origin = next_origin
		reach = SkillGeometry.ELEMENTALIST_LIGHTNING_CHAIN_RANGE
		current = _world_elementalist_chain_target(origin,source_height,visited)

func _world_elementalist_chain_target(origin: WorldEffectArea, source_height: float, visited: Array[int]) -> CombatActor:
	var chosen: CombatActor
	var nearest := INF
	for enemy: CombatActor in enemies.duplicate():
		if not is_instance_valid(enemy) or not enemy.is_alive() or enemy.world_motion == null or visited.has(enemy.get_instance_id()): continue
		var result := origin.query(enemy,SkillGeometry.ELEMENTALIST_LIGHTNING_CHAIN_RANGE,{"source_offset":Vector3.UP*source_height,"target_offset":Vector3.UP*float(enemy.world_motion.profile()["height"])*0.5})
		if not result["ok"] or not result["data"]["hit"]: continue
		var distance := float(result["data"]["distance"])
		if distance < nearest or (is_equal_approx(distance,nearest) and chosen != null and enemy.get_instance_id() < chosen.get_instance_id()):
			chosen = enemy
			nearest = distance
	return chosen

func _on_elementalist_lightning_arc_requested(request: DamageRequest, target_actor: CombatActor, jump_damage: float, marked_bonus: float) -> void:
	if player.world_motion != null:
		_on_world_elementalist_lightning_arc_requested(request,target_actor,jump_damage,marked_bonus)
		return
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
	if player.world_motion != null:
		var field := player.world_cast_field(&"lightning_wall")
		if field == null or not wall.bind_world_field(field)["ok"]: wall.free(); return
	add_child(wall)
	wall.add_to_group("player_effects")

func _on_lightning_wall_crossed(request: DamageRequest, target_actor: CombatActor) -> void:
	if not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var result := target_actor.apply_damage(request, rng)
	if not result.is_empty() and bool(result["landed"]) and float(result["actual_damage"]) > 0.0 and is_instance_valid(target_actor) and not target_actor.is_queued_for_deletion() and target_actor.is_alive():
		target_actor.apply_electrified(4.0)

func _on_soul_impact_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var sequence := SoulImpactSequence.new()
	if player.world_motion != null:
		var valid := sequence.configure_world(player,request,target_actor,player.skill_range(&"soul_impact"),player.world_motion.geometry.geometry_revision)
		if not valid["ok"]: sequence.free(); return
	else:
		sequence.configure(request, target_actor)
	sequence.impact.connect(_on_attack_requested)
	add_child(sequence)
	sequence.add_to_group("player_effects")

func _on_spiritualist_echo_curse_requested(request: DamageRequest, target_actor: CombatActor, echo_power: float) -> void:
	if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
		return
	var origin := target_actor.global_position
	var world_area: WorldEffectArea
	if player.world_motion != null:
		if target_actor.world_motion == null or not player.world_can_reach(target_actor,player.skill_range(&"spiritualist_echo_curse")): return
		world_area = WorldEffectArea.new()
		if not world_area.configure(player.world_motion.geometry,target_actor.world_point(),player.world_motion.profile(),&"ground_connected",player.world_motion.geometry.geometry_revision)["ok"]: return
	var result := target_actor.apply_damage(request, rng)
	if bool(result.get("can_trigger_effects", false)) and not run_finished:
		var candidates: Array[CombatActor] = []
		if is_instance_valid(target_actor) and target_actor.is_alive():
			candidates.append(target_actor)
		for enemy: CombatActor in enemies.duplicate():
			if enemy != target_actor:
				candidates.append(enemy)
		for candidate: CombatActor in candidates:
			if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive():
				continue
			if world_area != null:
				if not world_area.contains_actor(candidate,SkillGeometry.SPIRITUALIST_ECHO_SPREAD_RADIUS): continue
			elif candidate != target_actor and origin.distance_to(candidate.global_position) > SkillGeometry.SPIRITUALIST_ECHO_SPREAD_RADIUS + candidate.collision_radius:
				continue
			if world_area == null and candidate != target_actor and not navigation.is_segment_clear(origin, candidate.global_position, 0.0):
				continue
			if world_area != null:
				if not spiritualist_echo_state.mark_world(candidate,echo_power): continue
			else: spiritualist_echo_state.mark(candidate.get_instance_id(), echo_power)
			if battle_indicators != null:
				battle_indicators.show_spiritualist_event(&"sigil", candidate.global_position + Vector2(0, -22), candidate)
				if candidate != target_actor:
					battle_indicators.show_spiritualist_spread(origin, candidate.global_position)
			_show_spiritualist_feedback(candidate, "AMALDIÇOADO", Color("e6d9f2"))

func _echo_positions() -> Dictionary[int, Vector2]:
	var positions: Dictionary[int, Vector2] = {}
	for actor: CombatActor in enemies:
		if is_instance_valid(actor) and actor.is_alive(): positions[actor.get_instance_id()] = actor.global_position
	return positions

func _apply_spiritualist_echo(echo: Dictionary) -> void:
	if not is_instance_valid(player): return
	if is_instance_valid(player) and player.is_inside_tree() and player.get_tree().paused: return
	var carrier := instance_from_id(int(echo["target_id"])) as CombatActor
	if carrier == null or not is_instance_valid(carrier) or not carrier.is_alive():
		return
	var fixed := bool(echo.get("fixed_origin", false))
	var world_area: WorldEffectArea = echo.get("world_origin")
	if player.world_motion != null and world_area == null: return
	if world_area != null:
		if not world_area.is_current_world() or player.world_motion == null or player.world_motion.geometry != world_area.geometry or not player.world_motion.is_current_world() or carrier.world_motion == null or not carrier.world_motion.is_current_world() or carrier.world_motion.geometry != world_area.geometry or carrier.world_point().stage_id != world_area.anchor().stage_id: return
		if not fixed:
			var following := WorldEffectArea.new()
			if not following.configure(world_area.geometry,carrier.world_point(),carrier.world_motion.profile(),&"ground_connected",world_area.geometry.geometry_revision)["ok"]: return
			world_area = following
	var center: Vector2 = echo["center"] if fixed else carrier.global_position
	var affected: Array[CombatActor] = []
	if not fixed: affected.append(carrier)
	for candidate: CombatActor in enemies.duplicate():
		if candidate == null or (candidate == carrier and not fixed) or not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		if world_area.contains_actor(candidate,SkillGeometry.SPIRITUALIST_ECHO_SPREAD_RADIUS) if world_area != null else (center.distance_to(candidate.global_position) <= SkillGeometry.SPIRITUALIST_ECHO_SPREAD_RADIUS + candidate.collision_radius and navigation.is_segment_clear(center, candidate.global_position, 0.0)):
			affected.append(candidate)
	affected.sort_custom(func(a: CombatActor, b: CombatActor) -> bool: return a.get_instance_id() < b.get_instance_id())
	for target_actor: CombatActor in affected:
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if not is_instance_valid(player): return
		# Recheck geometry at resolution, not only when the wave was scheduled.
		if world_area != null:
			if not world_area.is_current_world(): return
			if not world_area.contains_actor(target_actor,SkillGeometry.SPIRITUALIST_ECHO_SPREAD_RADIUS): continue
		elif (fixed or target_actor != carrier) and (center.distance_to(target_actor.global_position) > SkillGeometry.SPIRITUALIST_ECHO_SPREAD_RADIUS + target_actor.collision_radius or not navigation.is_segment_clear(center, target_actor.global_position, 0.0)):
			continue
		if not spiritualist_echo_state.claim_pair(int(echo["wave_id"]), int(echo["target_id"]), target_actor.get_instance_id()):
			continue
		var request := player.make_spiritualist_echo_request(target_actor, float(echo["magic_damage"]))
		request.damage_dealt_multiplier = float(echo.get("damage_multiplier", 1.0))
		var parent: CombatEventContext = echo.get("context")
		if parent != null:
			var claimed := parent.ledger().claim_echo_pair(parent, int(echo["target_id"]), target_actor.get_instance_id()) if parent.ledger() != null else null
			if claimed == null:
				continue
			request.context = claimed
		_spiritualist_echo_number_target_id = target_actor.get_instance_id()
		var result := target_actor.apply_damage(request, rng)
		_spiritualist_echo_number_target_id = 0
		var actual := float(result.get("actual_damage", 0.0))
		if actual > 0.0:
			var first_spread := spiritualist_echo_state.record_echo_impact(int(echo["wave_id"]), result, float(echo["echo_power"]), _echo_positions())
			if battle_indicators != null:
				if target_actor == carrier:
					battle_indicators.show_spiritualist_event(&"echo_hit", target_actor.global_position + Vector2(0, -18), target_actor)
				elif first_spread:
					battle_indicators.show_spiritualist_spread(center, target_actor.global_position)
		elif float(result.get("absorbed_damage", 0.0)) > 0.0:
			if battle_indicators != null:
				battle_indicators.show_spiritualist_event(&"echo_absorbed", target_actor.global_position + Vector2(0, -18), target_actor)
			_show_spiritualist_feedback(target_actor, "ABSORVIDO", Color("b9cbd3"))

func _announce_spiritualist_mark_expiry(marks_before: Array) -> void:
	if not _is_spiritualist_run() or battle_indicators == null:
		return
	for target_id: int in marks_before:
		if spiritualist_echo_state.marks.has(target_id):
			continue
		var target := instance_from_id(target_id) as CombatActor
		if target != null and is_instance_valid(target) and target.is_alive():
			battle_indicators.show_spiritualist_event(&"expire", target.global_position + Vector2(0, -37), target)
			if target == _focused_spiritualist_target():
				_show_spiritualist_feedback(target, "MALDIÇÃO EXPIROU", Color("b9cbd3"))

func _sync_spiritualist_combat_state() -> void:
	if battle_indicators == null or not _is_spiritualist_run():
		return
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
	if player.world_motion != null:
		if not spiritualist_drain_state.start_world(player,target_actor,request,player.skill_range(&"spiritualist_soul_drain"),player.world_motion.geometry.geometry_revision)["ok"]: return
	else:
		spiritualist_drain_state.start(target_actor, player.global_position, request)
	if battle_indicators != null and spiritualist_drain_state.active:
		battle_indicators.sync_spiritualist_drain(player.get_instance_id(), spiritualist_drain_state.target_id)

func _advance_spiritualist_drain(delta: float) -> void:
	if not spiritualist_drain_state.active:
		return
	var moved := player.global_position.distance_to(spiritualist_drain_state.origin) > PlayerActor.MOVEMENT_EPSILON if player.world_motion == null else spiritualist_drain_state.world_action == null
	if not player.is_alive() or moved or player.is_stunned() or player.is_feared() or player.is_rooted():
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
		var inscription_power := spiritualist_drain_state.claim_completion_inscription(request) if channel_completed else 0.0
		if channel_completed:
			player.grant_spiritualist_focus(request.context)
		var result := target_actor.apply_damage(request, rng)
		if inscription_power > 0.0 and not run_finished and player.is_alive() and is_instance_valid(target_actor) and target_actor.is_alive() and float(result.get("actual_damage", 0.0)) > 0.0:
			if player.world_motion != null: spiritualist_echo_state.mark_world(target_actor,inscription_power)
			else: spiritualist_echo_state.mark(target_actor.get_instance_id(), inscription_power)
		var healed := player.heal_from_spiritualist_drain(result, healed_before)
		spiritualist_drain_state.healed_total = healed_before + healed
		if healed > 0.0:
			if battle_indicators != null:
				battle_indicators.show_spiritualist_event(&"heal_receive", player.global_position + Vector2(0, -24), player)
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

func _on_player_healed(amount: float, sequence: int) -> void:
	if not is_instance_valid(player) or not is_finite(amount) or amount <= 0.0 or sequence <= 0: return
	# Freeze the recipient decision even when the effective heal happened outside combat.
	if not combat_participation.claim_event("heal_player_%d" % sequence): return
	var engaged_enemies: Array[EnemyActor] = []
	for actor: CombatActor in enemies:
		if actor is EnemyActor and actor.is_alive() and actor.threat.linked("local_party"): engaged_enemies.append(actor)
	for enemy: EnemyActor in engaged_enemies:
		var source := enemy.threat_id_for(player)
		if not source.is_empty(): enemy.observe_threat_heal(source, amount, sequence, engaged_enemies.size())
	if not engaged_enemies.is_empty() and combat_participation != null: combat_participation.hostile_damage()

func _on_player_damage_resolved(result: Dictionary) -> void:
	if combat_participation != null and float(result.get("actual_damage", 0.0)) > 0.0: combat_participation.hostile_damage("incoming_%d" % int(result.get("application_sequence", 0)))
	if float(result.get("actual_damage", 0.0)) > 0.0:
		_cancel_spiritualist_drain()

func _on_spiritualist_focus_event(kind: StringName) -> void:
	if battle_indicators != null:
		battle_indicators.show_spiritualist_event(&"focus_grant" if kind == &"grant" else &"focus_consume", player.global_position + Vector2(0, -28))
	_show_spiritualist_feedback(player, "FOCO PRONTO" if kind == &"grant" else "FOCO CONSUMIDO", Color("e9d9f5"))

func _on_spiritualist_veil_requested(center: Vector2, duration: float, weaken_fraction: float) -> void:
	_clear_spiritualist_veil()
	if player.world_motion != null:
		if not player.world_motion.is_current_world(): return
		var anchor := player.world_cast_anchor()
		if anchor == null: return
		var valid := spiritualist_veil_state.start_world(player.world_motion.geometry,anchor,player.world_motion.profile(),duration,player.world_motion.geometry.geometry_revision)
		if not valid["ok"]: return
	else:
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
		if not spiritualist_veil_state.contains_actor(enemy) or (spiritualist_veil_state.world_area == null and not navigation.is_segment_clear(spiritualist_veil_state.center, enemy.global_position, 0.0)):
			continue
		enemy.apply_weaken(spiritualist_veil_fraction, 0.20, &"spiritualist_spectral_veil")
		if not _spiritualist_veil_members.has(enemy.get_instance_id()) and enemy.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil") > 0.0 and battle_indicators != null:
			battle_indicators.show_spiritualist_event(&"veil_apply", enemy.global_position + Vector2(0, -12), enemy)
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
		battle_indicators.sync_spiritualist_veil_members(_spiritualist_veil_members.keys())

func _clear_spiritualist_veil() -> void:
	for enemy: CombatActor in _spiritualist_veil_members.values():
		if enemy != null and is_instance_valid(enemy):
			enemy.remove_attribute_debuff(AttributeDebuffState.DAMAGE_DEALT, &"spiritualist_spectral_veil")
	_spiritualist_veil_members.clear()
	spiritualist_veil_state.clear()
	spiritualist_veil_fraction = 0.0
	if battle_indicators != null:
		battle_indicators.sync_spiritualist_veil(Vector2.INF, 0.0)
		battle_indicators.sync_spiritualist_veil_members([])

func _on_spiritualist_procession_requested(request: DamageRequest, target_actor: CombatActor) -> void:
	if player.world_motion != null:
		if not spiritualist_procession_state.start_world(player,target_actor,request,player.skill_range(&"spiritualist_procession"),player.world_motion.geometry.geometry_revision)["ok"]: return
	else:
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
			battle_indicators.show_spiritualist_event(&"procession_hit", target_actor.global_position + Vector2(0, -18), target_actor)
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
	var area := _cast_ground_area() if player.world_motion != null else null
	if player.world_motion != null and area == null: return
	if battle_indicators != null:
		battle_indicators.show_spiritualist_event(&"ritual", center)
	var target_index := 0
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if area != null:
			if not area.contains_actor(target_actor,SkillGeometry.SPIRITUALIST_DISSIPATION_RADIUS): continue
		elif target_actor.world_motion != null or center.distance_to(target_actor.global_position) > SkillGeometry.SPIRITUALIST_DISSIPATION_RADIUS + target_actor.collision_radius or not navigation.is_segment_clear(center,target_actor.global_position,0.0):
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
			if battle_indicators != null:
				battle_indicators.show_spiritualist_event(&"break", target_actor.global_position + Vector2(0, -22), target_actor)
			_show_spiritualist_feedback(target_actor, "ECO PREPARADO", Color("f5dacf"))
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
		if player.world_motion != null:
			var shape := {"geometry_rule_id":&"direct_volume","kind":&"cone","direction":player.world_cast_direction(),"range":cone_range,"half_angle":PlayerActor.HAUNT_HALF_ANGLE}
			var checked := player.world_attack_query(target_actor,shape,player.world_motion.geometry.geometry_revision)
			if not checked["ok"] or not checked["data"]["hit"]: continue
		elif target_actor.world_motion != null or not SkillGeometry.cone_contains(target_actor.global_position-origin,direction,cone_range,PlayerActor.HAUNT_HALF_ANGLE):
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
	if player.world_motion != null:
		var field := player.world_cast_field(&"phantom_barrier")
		if field == null or not barrier.bind_world_field(field)["ok"]: barrier.free(); return
	add_child(barrier)
	barrier.add_to_group("player_effects")

func _on_ice_wall_requested(wall: IceWallScript) -> void:
	add_child(wall)
	wall.add_to_group("player_effects")

func _on_provoke_requested(target_actor: CombatActor, duration: float) -> void:
	var enemy := target_actor as EnemyActor
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return
	if not enemy.apply_taunt(duration, player): return
	if combat_participation != null: combat_participation.hostile_damage("taunt_%s_%d" % [enemy.threat.enemy_id, enemy.threat_taunt_sequence])
	enemy.apply_attribute_debuff(AttributeDebuffState.PHYSICAL_DEFENSE, &"provoke", PlayerActor.PROVOKE_DEFENSE_REDUCTION, PlayerActor.PROVOKE_DEBUFF_DURATION)
	enemy.apply_attribute_debuff(AttributeDebuffState.FLEE, &"provoke", PlayerActor.PROVOKE_FLEE_REDUCTION, PlayerActor.PROVOKE_DEBUFF_DURATION)

func _on_piercing_shout_requested(origin: Vector2, request: DamageRequest, radius: float, duration: float) -> void:
	var area := _cast_ground_area() if player.world_motion != null else null
	if player.world_motion != null and area == null: return
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if area != null:
			var checked := area.query(target_actor,radius)
			if not checked["ok"] or not checked["data"]["hit"]: continue
		elif target_actor.world_motion != null or origin.distance_to(target_actor.global_position) > radius: continue
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
	var area := _cast_ground_area() if player.world_motion != null else null
	if player.world_motion != null and area == null: return
	for target_actor: CombatActor in enemies.duplicate():
		if target_actor == null or not is_instance_valid(target_actor) or not target_actor.is_alive():
			continue
		if area != null:
			var checked := area.query(target_actor,radius)
			if not checked["ok"] or not checked["data"]["hit"]: continue
		elif target_actor.world_motion != null or origin.distance_to(target_actor.global_position) > radius: continue
		target_actor.apply_fear(fear_duration)
		target_actor.apply_attribute_debuff(AttributeDebuffState.DAMAGE_RECEIVED, &"terrifying_shout", PlayerActor.TERRIFYING_SHOUT_DAMAGE_RECEIVED_INCREASE, PlayerActor.TERRIFYING_SHOUT_DEBUFF_DURATION)

func _on_enemy_attack_requested(request: DamageRequest, target_actor: CombatActor, ranged: bool) -> void:
	var spatial_source := instance_from_id(request.source_id) as CombatActor
	if spatial_source != null and spatial_source.world_motion != null:
		if not ranged:
			if spatial_source.world_can_reach(target_actor,55.0): _on_attack_requested(request,target_actor)
			return
		var arrow := ArrowProjectile.new()
		arrow.configure(request,target_actor,Vector2.ZERO,navigation)
		var bound := _bind_world_projectile(arrow,spatial_source,target_actor)
		if not bound["ok"]: arrow.free(); return
		arrow.hit.connect(_on_attack_requested)
		add_child(arrow)
		arrow.add_to_group("enemy_projectiles")
		return
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
	if geometer_casting != null:
		projectile.geometer_field = geometer_casting.wall_field
	add_child(projectile)
	projectile.add_to_group("enemy_projectiles")

func _on_enemy_died(actor: CombatActor) -> void:
	if campaign_runtime != null and not actor.get_meta("admin_spawn", false):
		var slot_id := campaign_runtime.slot_for_actor(actor)
		if not slot_id.is_empty():
			var slot: Dictionary = campaign_runtime.state.slots[slot_id]
			campaign_runtime.pending_events.append({"kind": "mob_death", "slot_id": slot_id, "generation": slot["generation"], "event_id": "death_" + actor.occurrence.occurrence_id})
			# Checkpoint40: written at once through the journal (in combat, at most
			# once per DEATH_JOURNAL_INTERVAL_MSEC). The dead actor stays a tombstone;
			# valid() admits it while its mob_death event is pending.
			if _death_flush_due(): _flush_expedition_events.call_deferred()
			return
		if actor is EnemyActor and actor.is_summoned:
			enemies.erase(actor)
			actor.hide()
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			return
		return # Unknown/stale campaign actors can never enter the legacy clear path.
	if not training_mode and not actor.get_meta("admin_spawn", false) and actor is EnemyActor and not actor.is_summoned and reward_service != null and reward_service.mob_loot_enabled():
		var issued := reward_service.issue_mob_drop(actor)
		if not issued["ok"]:
			status_label.text = "Não foi possível preparar o loot: %s" % issued["error_code"]
	_remove_master_companion(actor.get_instance_id())
	_defender_slowed_enemies.erase(actor.get_instance_id())
	player.hunter_state.discard_target(actor.get_instance_id())
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
	if actor.get_meta("admin_spawn", false): return
	if training_mode:
		if actor == training_boss:
			training_boss = null
			encounter_active = false
			_show_result(true)
		return
	if not _required_enemies().is_empty():
		return
	_remove_remaining_companions()
	encounter_active = false
	player.clear_shield_stance()
	player.clear_hunter_state()
	player.clear_perseverance()
	_clear_hunter_trap_effects()
	player.clear_fury()
	_clear_defender_runtime()
	player.clear_berserker_state()
	player.clear_elementalist_state()
	player.clear_spiritualist_state()
	spiritualist_echo_state.clear()
	if geometer_casting != null:
		geometer_casting.clear_construction()
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
	var placed := _create_reward_pickup()
	if not placed["ok"]:
		status_label.text = "Não foi possível colocar a coleta: %s" % placed["error_code"]
		return
	_ensure_reward_ticket()
	status_label.text = "Encontro concluído — toque no cristal dourado"

func _prepare_hunter_fan(result: Dictionary) -> void:
	if not player.is_hunter() or not player.hunter_state.can_consume(result) or StringName(result.get("skill_id", &"")) != &"hunter_covering_shot" or not bool(result.get("effect_snapshot", {}).get("kit_policies", {}).get(&"hunter_covering_fan", false)) or get_tree().paused: return
	var victim := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if not is_instance_valid(victim) or not victim.is_alive(): return
	var selected: CombatActor
	var distance := INF
	for candidate: CombatActor in enemies.duplicate():
		if not is_instance_valid(candidate) or not candidate.is_alive() or candidate.is_queued_for_deletion() or candidate == victim: continue
		var squared: float
		if player.world_motion != null:
			if victim.world_motion == null or candidate.world_motion == null or not player.world_motion.is_current_world() or not victim.world_motion.is_current_world() or not candidate.world_motion.is_current_world() or victim.world_motion.geometry != player.world_motion.geometry or candidate.world_motion.geometry != player.world_motion.geometry: continue
			var query := player.world_motion.geometry.query_attack({"geometry_rule_id":&"direct_volume","range":80.0},victim.world_point(),candidate.world_point(),player.world_motion.geometry.geometry_revision)
			if not query["ok"] or not query["data"]["hit"]: continue
			squared = float(query["data"]["distance"])*float(query["data"]["distance"])
		else:
			if candidate.world_motion != null or victim.world_motion != null: continue
			squared = victim.global_position.distance_squared_to(candidate.global_position)
			if squared > 80.0 * 80.0 or not navigation.is_segment_clear(victim.global_position, candidate.global_position, 0.0): continue
		if selected == null or squared < distance or (is_equal_approx(squared, distance) and candidate.get_instance_id() < selected.get_instance_id()):
			selected = candidate
			distance = squared
	var context: CombatEventContext = result.get("context")
	if selected != null and context != null and context.ledger() != null and context.ledger().admit_hunter_fan(result, selected.get_instance_id()): result["_hunter_fan_target_id"] = selected.get_instance_id()

func _on_enemy_damage_resolved(result: Dictionary) -> void:
	if combat_participation != null and float(result.get("actual_damage", 0.0)) > 0.0:
		var recipient := instance_from_id(int(result.get("target_id", 0))) as EnemyActor
		if is_instance_valid(recipient): combat_participation.hostile_damage("outgoing_%s_%d" % [recipient.threat.enemy_id, int(result.get("application_sequence", 0))])
	if player == null or not is_instance_valid(player) or not player.is_alive() or int(result.get("source_id", 0)) != player.get_instance_id():
		return
	var candidates: Array[Dictionary] = []
	var build := player.run_state.build_snapshot
	var victim_id_for_claim := int(result.get("target_id", 0))
	if build.evolution_id == &"defender" and build.has_passive(&"defender_watch") and StringName(result.get("skill_id", &"")) in DEFENDER_WATCH_DIRECT_MELEE_IDS:
		candidates.append({"family_id": &"defender_watch", "source_id": &"defender_watch", "target_id": victim_id_for_claim})
	if spiritualist_echo_state.can_record_hit(result) and build.has_passive(&"spiritualist_echo_recovery") and player.spiritualist_recovery_cooldown <= 0.0 and player.current_sp < player.max_sp and not player._spiritualist_refunded_emissions.has(int(result.get("emission_id", 0))):
		candidates.append({"family_id": &"spiritualist_echo_recovery", "source_id": &"spiritualist_echo_recovery", "target_id": player.get_instance_id()})
	_prepare_hunter_fan(result)
	player.prepare_effect_claims(result, candidates)
	player.resolve_build_effect_procs(result)
	player.record_berserker_damage(result)
	player.record_sentinel_damage(result)
	player.record_hunter_damage(result)
	var echo_triggered := spiritualist_echo_state.record_hit(result, player.spiritualist_magic_attack(), _echo_positions())
	if echo_triggered:
		if battle_indicators != null:
			var mark_target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
			if mark_target != null and is_instance_valid(mark_target):
				battle_indicators.show_spiritualist_event(&"echo_ready", mark_target.global_position + Vector2(0, -37), mark_target)
				_show_spiritualist_feedback(mark_target, "ECO PREPARADO", Color("d9eafa"))
		var recovered := player.recover_spiritualist_echo_sp(int(result.get("emission_id", 0)), result)
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
	if player.run_state != null and player.run_state.uses_persistent_build() and player.run_state.build_snapshot.evolution_id == &"defender" and player.run_state.build_snapshot.has_passive(&"defender_watch") and bool(result.get("can_trigger_effects", false)) and float(result.get("actual_damage", 0.0)) > 0.0 and StringName(result.get("skill_id", &"")) in DEFENDER_WATCH_DIRECT_MELEE_IDS:
		var watch_rank := ClassCatalog.skill_definition(&"defender_watch").rank_definition(player.skill_rank(&"defender_watch"))
		var watch_target := instance_from_id(int(result.get("target_id", 0))) as CombatActor
		if watch_rank != null and watch_target != null and is_instance_valid(watch_target) and watch_target.is_alive():
			if player.claim_effect_result(result, &"defender_watch", watch_target.get_instance_id()):
				watch_target.apply_weaken(watch_rank.power, PlayerActor.DEFENDER_WATCH_DURATION, &"defender_watch")
	if not bool(result.get("killed", false)):
		return
	var victim_id := int(result.get("target_id", 0))
	var defeated := instance_from_id(victim_id) as EnemyActor
	if defeated != null and (defeated.is_summoned or defeated.get_meta("admin_spawn", false)): return
	if victim_id <= 0 or _credited_kills.has(victim_id):
		return
	_credited_kills[victim_id] = true
	if build.has_passive(&"blood_thirst") and player.claim_effect_result(result, &"blood_thirst", victim_id, true):
		player.heal_from_kill()

func _create_reward_pickup() -> Dictionary:
	if is_instance_valid(reward): return {"ok":true,"error_code":&"","data":{"already_placed":true}}
	if not is_instance_valid(player) or not player.is_alive(): return WorldSkillCast.failure(&"invalid_collector")
	var pickup := RewardPickup.new()
	if player.world_motion != null:
		if not player.world_motion.is_current_world(): pickup.free(); return WorldSkillCast.failure(&"world_reconfigured")
		var bound := pickup.bind_world_area(player.world_motion.geometry,player.world_point(),player.world_motion.profile(),player.world_motion.geometry.geometry_revision)
		if not bound["ok"]: pickup.free(); return bound
	else: pickup.global_position = navigation.get_path(player.global_position,player.global_position)[-1] if gameplay_extension else Vector2(880,500)
	pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
	reward = pickup
	add_child(pickup)
	return {"ok":true,"error_code":&"","data":{}}

func _collect_reward() -> Dictionary:
	if reward == null:
		return {"ok": false, "error_code": &"reward_unavailable"}
	if player.world_motion != null:
		if run_finished or encounter_active or not player.is_alive() or (is_inside_tree() and get_tree().paused) or not reward.can_collect_world(player,48.0): return WorldSkillCast.failure(&"world_collection_unavailable")
	elif reward.world_area != null: return WorldSkillCast.failure(&"spatial_binding_required")
	var progression_result := _grant_persistent_encounter_reward()
	if not progression_result.get("ok", false):
		_reward_retry_pending = true
		status_label.text = "%s Pressione F8 para tentar novamente ou use Personagem para sair; a coleta ainda não foi consumida." % _reward_error_text(StringName(progression_result.get("error_code", &"unknown")))
		return progression_result
	reward.queue_free()
	reward = null
	_reward_retry_pending = false
	augment_button.disabled = false
	if not training_mode:
		reward_feedback.open_history(encounter_index)
	if progression_result.get("persistent", false):
		var applied: Dictionary = progression_result.get("acquisition", {})
		if applied.is_empty():
			status_label.text = "XP persistente já salvo — abra a escolha com F8"
		else:
			status_label.text = "XP salvo: +%d base · +%d job — abra a escolha com F8" % [applied["base_xp"], applied["job_xp"]]
	else:
		status_label.text = "Recompensa coletada — abra a escolha com F8"
	return progression_result

func _ensure_reward_ticket() -> Dictionary:
	if reward == null or reward_service == null:
		return BuildEffectCatalog.failure(&"reward_unavailable")
	if not reward.ticket_id.is_empty():
		return reward_service.ticket(reward.ticket_id)
	var issued := reward_service.issue("encounter_%d" % encounter_index, PlaytestGameplay.reward_id(encounter_index) if gameplay_extension else ProfileRewardResolver.pilot_encounter_reward_id(encounter_index), gameplay_extension or encounter_index == 2)
	if issued["ok"]:
		reward.ticket_id = issued["ticket_id"]
	return issued

func _grant_persistent_encounter_reward() -> Dictionary:
	var mobs := reward_service.collect_pending_mob_tickets()
	if not mobs["ok"]: return mobs
	var issued := _ensure_reward_ticket()
	if not issued["ok"]:
		return issued
	return reward_service.collect(issued["ticket_id"])

func set_inventory_freeze(frozen: bool) -> void:
	if inventory_frozen == frozen:
		return
	inventory_frozen = frozen
	run_state.transaction_locked = frozen
	if not is_inside_tree():
		return
	if frozen:
		_inventory_previous_pause = get_tree().paused
		_cancel_casting(false)
		get_tree().paused = true
	else:
		get_tree().paused = _inventory_previous_pause

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
	if run_finished or inventory_frozen or get_tree().paused:
		return
	var offer_result := run_state.open_offer(encounter_active and not _admin_offer_override, rng)
	if not offer_result["ok"]:
		if offer_result.get("error_code") == &"encounter_active": status_label.text = AUGMENT_COMBAT_TEXT
		return
	var offer: Array[AugmentDefinition] = []
	offer.assign(offer_result["definitions"])
	if offer.is_empty():
		var consumed := run_state.consume_empty_offer(offer_result, encounter_active and not _admin_offer_override)
		if consumed["ok"]:
			status_label.text = consumed["message"]
			_admin_offer_override = false
			augment_button.disabled = encounter_active or run_state.pending_choices <= 0
			if run_state.pending_choices <= 0 and not encounter_active:
				next_button.visible = true
				next_button.text = "Encerrar demonstração" if encounter_index >= _encounter_count() else "Próximo encontro"
		return
	_cancel_casting(false)
	_clear_hover()
	for child: Node in choice_buttons.get_children():
		child.queue_free()
	for definition: AugmentDefinition in offer:
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 120)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s\n%s\n%s" % [definition.display_name, definition.description, BuildPresentation.augment_progress(self, definition)]
		button.add_theme_font_size_override("font_size", 17)
		button.pressed.connect(_confirm_augment.bind(definition.id))
		choice_buttons.add_child(button)
	reward_feedback.hide_history()
	augment_overlay.visible = true
	get_tree().paused = true

func _confirm_augment(augment_id: StringName) -> void:
	if not run_state.confirm(augment_id, encounter_active and not _admin_offer_override):
		return
	_admin_offer_override = false
	player.apply_run_modifiers(run_state)
	if not training_mode:
		_acquisition_augment_serial += 1
		acquisition_journal.record_augment(str(_acquisition_augment_serial), encounter_index, run_state.effect_catalog().get_definition(&"augment", augment_id) as AugmentDefinition, int(run_state.augment_stacks.get(augment_id, 1)))
	augment_overlay.visible = false
	get_tree().paused = false
	augment_button.disabled = encounter_active or run_state.pending_choices <= 0
	if campaign_runtime != null:
		next_button.hide()
		status_label.text = "Augment aplicado — continue explorando."
		return
	if encounter_active:
		next_button.hide()
		status_label.text = "Augment admin aplicado — combate retomado"
		return
	if run_state.pending_choices > 0:
		status_label.text = "Aprimoramento aplicado — há escolhas pendentes"
		return
	next_button.visible = true
	next_button.text = "Encerrar demonstração" if encounter_index >= _encounter_count() else "Próximo encontro"
	status_label.text = "Recompensas disponíveis — prepare a build ou encerre a demonstração" if encounter_index >= _encounter_count() else "Augment aplicado — inicie o próximo encontro"

func _start_next_encounter() -> void:
	if campaign_runtime != null: return
	if encounter_active or reward != null or run_state.pending_choices > 0 or run_state.has_open_offer() or inventory_frozen or run_finished or reward_service.has_uncollected():
		return
	if encounter_index >= _encounter_count():
		_show_result(true)
	else:
		_spawn_encounter(encounter_index + 1)

func _spawn_death_visual(actor: CombatActor, after_run: bool = false) -> void:
	if actor.world_motion != null: return # Multilevel presentation awaits D05.
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
	var hostiles: Array = enemies.duplicate()
	if campaign_runtime != null:
		for actor: EnemyActor in campaign_runtime.actors.values():
			if actor not in hostiles: hostiles.append(actor)
	for actor: CombatActor in hostiles:
		if actor is EnemyActor and is_instance_valid(actor):
			var source: String = actor.threat_id_for(player)
			if not source.is_empty(): actor.threat.eligibility(source, false, false); actor._select_threat_target()
	if campaign_runtime != null:
		campaign_runtime.death_serial += 1
		campaign_runtime.pending_events.append({"kind": "player_death", "event_id": "player_death_%d" % campaign_runtime.death_serial})
		_flush_expedition_events.call_deferred()
		return
	_spawn_death_visual(_actor, true)
	encounter_active = false
	_show_result(false)

func _advance_expedition_runtime(delta: float) -> void:
	if snapshot_passive or run_finished or get_tree().paused or _memory_snapshot_pending: return
	var links := {}
	for enemy: CombatActor in enemies:
		if enemy is EnemyActor and enemy.is_alive() and (enemy.engagement_mode == &"engaged" or enemy.threat.linked("local_party")):
			links[enemy.occurrence.occurrence_id if enemy.occurrence != null else "companion"] = true
	combat_participation.observe(links, delta)
	encounter_active = combat_participation.active()
	if _death_flush_due() and not _expedition_flush_running and campaign_runtime.pending_events.any(func(event: Dictionary) -> bool: return event["kind"] == "mob_death"):
		_flush_expedition_events.call_deferred()
	var wave := campaign_runtime.state.advance(delta)
	var pending_safe := false
	# Checkpoint40: births decided by the journal arrive one per frame.
	if not campaign_runtime.birth_queue.is_empty():
		var born := campaign_runtime.drain_births(self, 1)
		if not born["ok"]: push_warning("expedition birth refused: %s" % born.get("error_code", ""))
	for slot_id: String in campaign_runtime.state.slots:
		var slot: Dictionary = campaign_runtime.state.slots[slot_id]
		if slot["stage_id"] != campaign_runtime.state.current_stage_id or slot["life_state"] != "respawn_pending" or campaign_runtime.birth_queued(slot_id): continue
		var world: WorldGeometry = campaign_runtime.worlds[slot["stage_id"]]
		var query := world.position_query(ExpeditionPopulationPlanner.point(slot["home"]), slot["traversal"], world.geometry_revision)
		if query["ok"] and query["data"]["occupants"].is_empty(): pending_safe = true; break
	if wave or pending_safe:
		if not campaign_runtime.pending_events.any(func(event: Dictionary) -> bool: return event["kind"] == "wave"):
			campaign_runtime.pending_events.append({"kind": "wave", "wave_index": campaign_runtime.state.clock.wave_index})
		_flush_expedition_events.call_deferred()

func _flush_expedition_events(allow_journal: bool = true) -> void:
	if campaign_runtime == null or _expedition_flush_running or campaign_runtime.pending_events.is_empty() or _memory_snapshot_pending: return
	if allow_journal and _journal_flush(): return
	# The full transaction stops the game; mob deaths alone still wait for the end
	# of combat when the journal cannot take them (full journal, no base).
	if encounter_active and campaign_runtime.pending_events.all(func(event: Dictionary) -> bool: return event["kind"] == "mob_death"): return
	_expedition_flush_running = true
	var saved_status := status_label.text
	status_label.text = "Salvando a expedição…"
	# Let the notice render once before the frozen capture.
	await get_tree().process_frame
	if campaign_runtime == null or campaign_runtime.pending_events.is_empty() or _memory_snapshot_pending: _expedition_flush_running = false; status_label.text = saved_status; return
	var requested := request_memory_snapshot()
	if not requested["ok"]: _expedition_flush_running = false; status_label.text = saved_status; return
	var captured: Dictionary = await memory_snapshot_ready
	if not captured["ok"]:
		status_label.text = "A expedição está pausada: %s" % captured["error_code"]
		return
	_expedition_transaction_service = ExpeditionService.new(persistent_facade)
	var command := {"kind": "events", "events": campaign_runtime.pending_events.duplicate(true)}
	var request := "events_" + ExpeditionCanonical.digest(command).substr(0, 56)
	# The frozen cut is reused: the barrier guarantees nothing changed since it was taken.
	var result := _expedition_transaction_service.campaign_command(self, _memory_snapshot_barrier, command, request, persistent_facade.current_profile().revision, captured)
	if result["ok"]:
		_install_expedition_result(result)
	else:
		status_label.text = "A expedição está pausada; confirme a recuperação antes de continuar: %s" % result["error_code"]

# Checkpoint37 (J2): deaths alone are written as one journal entry, in the same
# frame, without capturing or replacing the world. Returns false when the full
# transaction must run instead (waves, no base checkpoint, full journal, or a
# refusal the full path reports itself).
func _journal_flush() -> bool:
	if not campaign_runtime.pending_events.all(func(event: Dictionary) -> bool: return event["kind"] in ["mob_death", "player_death", "wave"]): return false
	var profile := persistent_facade.current_profile() if persistent_facade != null else null
	var lock := profile.expedition_for_character(run_state.character_id) if profile != null else null
	if lock == null or lock.checkpoint.is_empty() or lock.journal.size() >= ExpeditionService.Journal.MAX_ENTRIES: return false
	_memory_snapshot_pending = true
	_memory_snapshot_previous_pause = get_tree().paused
	get_tree().paused = true
	_memory_snapshot_barrier = SnapshotTickBarrier.new()
	if not _memory_snapshot_barrier.acquire(self)["ok"]:
		release_memory_snapshot(); return false
	var events := campaign_runtime.pending_events.duplicate(true)
	var request := "events_" + ExpeditionCanonical.digest({"kind": "events", "events": events}).substr(0, 56)
	_death_flush_after_msec = Time.get_ticks_msec() + DEATH_JOURNAL_INTERVAL_MSEC
	_expedition_transaction_service = ExpeditionService.new(persistent_facade)
	# Checkpoint38: the effect is resolved under the barrier, the profile is
	# written on a worker thread and the game keeps running meanwhile.
	var result := _expedition_transaction_service.journal_events(self, _memory_snapshot_barrier, events, request, profile.revision, _background_saves())
	if result.get("pending", false):
		release_memory_snapshot(); _expedition_flush_running = true; _watch_expedition_save(); return true
	if result["ok"]:
		release_memory_snapshot(); _settle_lifecycle(false); return true
	if result.get("read_only", false):
		# Uncertain write: stay frozen until the player confirms recovery.
		_expedition_flush_running = true
		status_label.text = "A expedição está pausada; confirme a recuperação antes de continuar: %s" % result["error_code"]
		return true
	release_memory_snapshot()
	return false

# Background profile writes outside headless runs; RAGRPG_SYNC_SAVE=1 forces the
# synchronous write and RAGRPG_BACKGROUND_SAVE=1 the background one (tests).
func _background_saves() -> bool:
	if OS.get_environment("RAGRPG_BACKGROUND_SAVE") == "1": return true
	return DisplayServer.get_name() != "headless" and OS.get_environment("RAGRPG_SYNC_SAVE") != "1"

# Checkpoint38: out of combat, the mob drops and their XP waiting in the queue go
# to the character in journal entries of ExpeditionService.COLLECT_BATCH, written
# in the background. The status panel button remains the explicit fallback.
func _auto_collect() -> void:
	if campaign_runtime == null or reward_service == null or persistent_facade == null or not reward_service.has_uncollected(): return
	if snapshot_passive or _expedition_flush_running or expedition_save_busy() or _memory_snapshot_pending or encounter_active or run_finished or inventory_frozen: return
	if not is_inside_tree() or get_tree().paused or not player.is_alive() or run_state.has_open_offer() or not campaign_runtime.pending_events.is_empty(): return
	if Time.get_ticks_msec() < _auto_collect_after_msec or not reward_service.next_pending_ticket().get("mob_ticket", false): return
	var profile := persistent_facade.current_profile()
	var lock := profile.expedition_for_character(run_state.character_id) if profile != null else null
	if lock == null or lock.checkpoint.is_empty() or lock.lifecycle != &"active": return
	if lock.journal.size() >= ExpeditionService.Journal.MAX_ENTRIES:
		_compact_reward_journal()
		return
	_memory_snapshot_pending = true
	_memory_snapshot_previous_pause = get_tree().paused
	get_tree().paused = true
	_memory_snapshot_barrier = SnapshotTickBarrier.new()
	if not _memory_snapshot_barrier.acquire(self)["ok"]:
		release_memory_snapshot(); return
	var queued: Array = []
	for ticket_id: String in reward_service._queue: queued.append(ticket_id)
	var request := "collect_" + ExpeditionCanonical.digest(queued).substr(0, 56)
	_expedition_transaction_service = ExpeditionService.new(persistent_facade)
	var result := _expedition_transaction_service.journal_collect(self, _memory_snapshot_barrier, request, profile.revision, _background_saves())
	if result.get("pending", false):
		release_memory_snapshot(); _expedition_flush_running = true; _watch_expedition_save(); return
	if result.get("ok", false):
		release_memory_snapshot(); return
	if result.get("read_only", false):
		_expedition_flush_running = true
		status_label.text = "A expedição está pausada; confirme a recuperação antes de continuar: %s" % result["error_code"]
		return
	release_memory_snapshot()
	_auto_collect_after_msec = Time.get_ticks_msec() + 5000

## Keep queued drops live across the bounded journal boundary. The same frozen
## cut and canonical checkpoint writer used by suspension replace the chain;
## no ticket is granted and no RNG is consumed by compaction itself.
func _compact_reward_journal() -> void:
	var queued := request_memory_snapshot()
	if not queued.get("ok",false): return
	var captured: Dictionary = await memory_snapshot_ready
	var profile := persistent_facade.current_profile()
	var lock := profile.expedition_for_character(run_state.character_id) if profile != null else null
	if not captured.get("ok",false) or lock == null or lock.lifecycle != &"active" or encounter_active or run_finished or inventory_frozen or not player.is_alive() or run_state.has_open_offer() or not campaign_runtime.pending_events.is_empty():
		release_memory_snapshot()
		_auto_collect_after_msec = Time.get_ticks_msec() + 5000
		return
	var request := "compact_" + ExpeditionCanonical.digest([lock.expedition_id,lock.revision,lock.checkpoint.get("sha256","")]).substr(0,56)
	_expedition_transaction_service = ExpeditionService.new(persistent_facade)
	var result := _expedition_transaction_service.checkpoint(self,_memory_snapshot_barrier,lock.expedition_id,lock.phase_id,request,profile.revision,false,captured)
	if result.get("read_only",false):
		_expedition_flush_running = true
		status_label.text = "A expedição está pausada; confirme a recuperação antes de continuar: %s" % result["error_code"]
		return
	release_memory_snapshot()
	_auto_collect_after_msec = 0 if result.get("ok",false) else Time.get_ticks_msec() + 5000

# Checkpoint39: a death leaves the game paused in recovery, like the installed
# host of the full transaction; a revive resumes it.
func _settle_lifecycle(revived: bool) -> void:
	if campaign_runtime == null or not is_inside_tree(): return
	if campaign_runtime.state.lifecycle != "active": get_tree().paused = true
	elif revived: get_tree().paused = false

# The tree is paused during recovery, so the result is polled per frame even then.
func _watch_expedition_save() -> void:
	if is_inside_tree() and not get_tree().process_frame.is_connected(_poll_expedition_save): get_tree().process_frame.connect(_poll_expedition_save)

## Checkpoint39: revive at the last portal through the journal (status panel).
## Returns pending/ok/read_only when handled; any other refusal means the caller
## uses the full transaction.
func try_journal_revive(event_id: String) -> Dictionary:
	if campaign_runtime == null or persistent_facade == null or _memory_snapshot_pending or _expedition_flush_running or expedition_save_busy() or not is_inside_tree(): return WorldSkillCast.failure(&"journal_unavailable")
	var profile := persistent_facade.current_profile()
	if profile == null: return WorldSkillCast.failure(&"journal_unavailable")
	_memory_snapshot_pending = true
	_memory_snapshot_previous_pause = get_tree().paused
	get_tree().paused = true
	_memory_snapshot_barrier = SnapshotTickBarrier.new()
	if not _memory_snapshot_barrier.acquire(self)["ok"]:
		release_memory_snapshot(); return WorldSkillCast.failure(&"journal_unavailable")
	var request := "revive_" + event_id.sha256_text().substr(0, 56)
	_expedition_transaction_service = ExpeditionService.new(persistent_facade)
	var result := _expedition_transaction_service.journal_revive(self, _memory_snapshot_barrier, event_id, request, profile.revision, _background_saves())
	if result.get("pending", false):
		release_memory_snapshot(); _expedition_flush_running = true; _watch_expedition_save(); return result
	if result.get("ok", false):
		release_memory_snapshot(); _settle_lifecycle(true); return result
	if result.get("read_only", false):
		_expedition_flush_running = true
		status_label.text = "A expedição está pausada; confirme a recuperação antes de continuar: %s" % result["error_code"]
		return result
	release_memory_snapshot()
	return result

# Checkpoint40: out of combat at once; in combat once per interval.
func _death_flush_due() -> bool:
	return not encounter_active or Time.get_ticks_msec() >= _death_flush_after_msec

# Events queued while a background write ran (a death, a wave) go next.
func _flush_queued_events() -> void:
	if campaign_runtime == null or campaign_runtime.pending_events.is_empty(): return
	if campaign_runtime.pending_events.all(func(event: Dictionary) -> bool: return event["kind"] == "mob_death") and not _death_flush_due(): return
	_flush_expedition_events.call_deferred()

func expedition_save_busy() -> bool:
	return _expedition_transaction_service != null and _expedition_transaction_service.background_pending()

func _poll_expedition_save() -> void:
	if not expedition_save_busy(): return
	var result := _expedition_transaction_service.poll_background()
	if result.get("pending", false): return
	if is_inside_tree() and get_tree().process_frame.is_connected(_poll_expedition_save): get_tree().process_frame.disconnect(_poll_expedition_save)
	if result.get("ok", false):
		_expedition_flush_running = false
		_settle_lifecycle(result.get("journal_kind", "") == "revive")
		_flush_queued_events()
		return
	if result.get("read_only", false):
		# Same rule as a synchronous uncertain write: freeze until recovery.
		_memory_snapshot_pending = true
		_memory_snapshot_previous_pause = get_tree().paused
		get_tree().paused = true
		_memory_snapshot_barrier = SnapshotTickBarrier.new()
		_memory_snapshot_barrier.acquire(self)
		status_label.text = "A expedição está pausada; confirme a recuperação antes de continuar: %s" % result["error_code"]
		return
	# Refused without a write: the full transaction reports or repairs it.
	_expedition_flush_running = false
	_flush_expedition_events.call_deferred(false)

func reconcile_expedition_transaction(request_id: String) -> Dictionary:
	if _expedition_transaction_service == null: return WorldSkillCast.failure(&"invalid_transaction")
	var result := _expedition_transaction_service.reconcile(request_id)
	if result["ok"]: _install_expedition_result(result)
	return result

func retry_expedition_events() -> Dictionary:
	if campaign_runtime == null or not _memory_snapshot_pending: return WorldSkillCast.failure(&"invalid_transaction")
	var command := {"kind": "events", "events": campaign_runtime.pending_events.duplicate(true)}
	var request := "events_" + ExpeditionCanonical.digest(command).substr(0, 56)
	# An uncertain journal write may be a collection, not the pending deaths.
	if _expedition_transaction_service != null and not _expedition_transaction_service._pending.is_empty(): request = String(_expedition_transaction_service._pending.get("request_id", request))
	if _expedition_transaction_service != null:
		var result := _expedition_transaction_service.reconcile(request)
		if result["ok"]: return _install_expedition_result(result)
		if result.get("read_only", false): return result
	_expedition_flush_running = false
	release_memory_snapshot()
	_flush_expedition_events.call_deferred()
	return {"ok": true, "queued": true}

func _install_expedition_result(result: Dictionary) -> Dictionary:
	if not result.has("root"):
		# A journal entry was applied to this same host: only unfreeze it.
		if result.has("journal_seq") or (result.get("durable",false) and result.get("lifecycle") == &"active"):
			release_memory_snapshot(); _expedition_flush_running = false
			_settle_lifecycle(result.get("journal_kind", "") == "revive")
		return result
	var registry: SnapshotRegistry = result["registry"]
	var copy: RunController = result["root"]
	var parent := get_parent()
	var installed := registry.install(result, parent)
	if not installed["ok"]: return installed
	var activated := registry.activate(result)
	if not activated["ok"]: return activated
	if copy.route_camera != null:
		copy.route_camera.make_current()
		copy.route_camera.reset_smoothing()
		copy.route_camera.force_update_scroll()
	var tree := get_tree()
	if tree.current_scene == self: tree.current_scene = copy
	parent.remove_child(self)
	tree.paused = copy.campaign_runtime.state.lifecycle != "active"
	queue_free()
	return result

func _show_result(victory: bool) -> void:
	if run_finished:
		return
	if victory and not training_mode and (reward != null or run_state.pending_choices > 0 or run_state.has_open_offer() or inventory_frozen or reward_service.has_uncollected()):
		return
	reward_feedback.hide_history()
	reward_feedback.hide_recent()
	_clear_admin_spawns()
	if admin_panel != null: admin_panel.hide()
	run_finished = true # Claim terminal before clearing buffs can recalculate lethal maxima.
	run_state.effect_ledger.cancel()
	player.clear_sentinel_state()
	player.clear_hunter_state()
	_clear_hunter_trap_effects()
	_cancel_casting()
	if geometer_casting != null:
		geometer_casting.clear_construction()
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
	run_state.reset()
	run_state.effect_ledger.cancel()
	_training_add_elapsed = 0.0
	_terminal_outcome = &"completed" if victory else &"death"
	result_title.text = ("Treino concluído!" if training_mode else "Arena concluída!") if victory else "Você caiu em combate"
	var next_step := "Pressione R ou use o botão para voltar ao menu e iniciar outra run." if _persistent_run_active() else "Pressione R ou use o botão para reiniciar."
	restart_button.text = "Voltar ao menu (R)" if _persistent_run_active() else "Reiniciar arena (R)"
	if training_mode:
		result_body.text = ("O Guardião caiu.\n" if victory else "Treino encerrado.\n") + "Nenhum XP ou recompensa foi salvo.\n" + next_step
	else:
		result_body.text = (("As três áreas e seus seis encontros foram vencidos.\n" if gameplay_extension else "Os dois encontros do Marco 1 foram vencidos.\n") if victory else "A run terminou e todo o estado temporário será descartado.\n") + next_step
	if not training_mode:
		var gained := acquisition_journal.totals()
		result_body.text += "\nXP obtida nesta run: Base +%d · Job +%d" % [gained["base_xp"], gained["job_xp"]]
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
		pending_run_state = _training_restart_state()
		pending_training_mode = true
	get_tree().paused = false
	get_tree().reload_current_scene()

func _training_restart_state() -> RunState:
	# Keep session organization on retry without mutating the current build or save.
	var snapshot := run_state.build_snapshot.copy_snapshot()
	snapshot.action_slots = action_slots.duplicate()
	return RunState.from_build("", snapshot)

func _return_to_character_menu() -> void:
	if campaign_runtime != null:
		if campaign_runtime.state.lifecycle == "completed": ExpeditionSceneFlow.lobby(self)
		else:
			var panel := ui_root.get_node_or_null("ExpeditionStatus") as ExpeditionStatusPanel
			if panel != null: panel.run_action({"kind": "suspend"})
		return
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
	if augment_overlay.visible or class_overlay.visible or (inventory_panel != null and inventory_panel.visible):
		return
	if battle_controls.settings_overlay.visible:
		battle_controls.settings_overlay.visible = false
		battle_controls.cancel_binding_capture()
		class_button.show()
	_cancel_casting(false)
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
	if expedition_view != null: return _world_enemy_at(point,cast_intent.active_skill)
	if GeometerCastCommand.is_trace_skill(cast_intent.active_skill):
		return BattleTargeting.pick(point, enemies, null, false)
	return BattleTargeting.pick(point, enemies, _hovered_enemy, control_preferences.smart_lock)

## World picking keeps the flat-mode contract: assist and lock only for single-target intents.
func _world_enemy_at(point: Vector2, skill: StringName = &"") -> CombatActor:
	if GeometerCastCommand.is_trace_skill(skill): return expedition_view.actor_at(point,enemies)
	var definition: SkillDefinition = ClassCatalog.skill_definition(skill) if skill != &"" else null
	var single := skill == &"" or (definition != null and definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET)
	return expedition_view.actor_at(point,enemies,_hovered_enemy if single else null,single and control_preferences.smart_lock)

func _handle_world_click(point: Vector2) -> void:
	if player.world_motion != null:
		spatial_pointer_move(point)
		return
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
	if amount <= 0 or not combat_numbers_visible:
		return
	if _spiritualist_echo_number_target_id == actor.get_instance_id():
		_remember_spiritualist_feedback(actor, "ECO! %d" % amount)
		_show_spiritualist_combat_text(actor, "ECO! %d" % amount, Color("d9eafa"), 22)
		return
	var label_text := ("CRÍTICO %d" if critical else "%d") % amount
	var label_color := Color("ffd166") if critical else Color.WHITE
	var label_size := 20 if critical else 17
	if _is_spiritualist_run():
		_show_spiritualist_combat_text(actor, label_text, label_color, label_size)
	else:
		_show_combat_text(actor, label_text, label_color, label_size)

func _show_miss(actor: CombatActor) -> void:
	if not combat_numbers_visible:
		return
	if _is_spiritualist_run():
		_show_spiritualist_combat_text(actor, "ERROU", Color("b9cbd3"), 16)
	else:
		_show_combat_text(actor, "ERROU", Color("b9cbd3"), 16)

func _show_spiritualist_feedback(actor: CombatActor, message: String, color: Color) -> void:
	if not spiritualist_debug_text or actor == null or not is_instance_valid(actor):
		return
	_show_spiritualist_combat_text(actor, message, color, 15)
	_remember_spiritualist_feedback(actor, message)

func _show_spiritualist_combat_text(actor: CombatActor, message: String, color: Color, font_size: int) -> void:
	for index: int in range(_spiritualist_feedback_labels.size() - 1, -1, -1):
		if not is_instance_valid(_spiritualist_feedback_labels[index]) or _spiritualist_feedback_labels[index].is_queued_for_deletion():
			_spiritualist_feedback_labels.remove_at(index)
	while _spiritualist_feedback_labels.size() >= 12:
		var oldest: Label = _spiritualist_feedback_labels.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var used_lanes: Array[int] = []
	for label: Label in _spiritualist_feedback_labels:
		if is_instance_valid(label) and label.get_meta("actor_id", 0) == actor.get_instance_id():
			used_lanes.append(int(label.get_meta("lane", 0)))
	if used_lanes.size() >= 3:
		for index: int in range(_spiritualist_feedback_labels.size()):
			var oldest_for_actor := _spiritualist_feedback_labels[index]
			if is_instance_valid(oldest_for_actor) and oldest_for_actor.get_meta("actor_id", 0) == actor.get_instance_id():
				used_lanes.erase(int(oldest_for_actor.get_meta("lane", 0)))
				oldest_for_actor.queue_free()
				_spiritualist_feedback_labels.remove_at(index)
				break
	var lane := 0
	while used_lanes.has(lane):
		lane += 1
	var feedback_label := _show_combat_text(actor, message, color, font_size, lane * 28.0)
	feedback_label.set_meta("actor_id", actor.get_instance_id())
	feedback_label.set_meta("lane", lane)
	_spiritualist_feedback_labels.append(feedback_label)

func _is_spiritualist_run() -> bool:
	return run_state != null and run_state.build_snapshot != null and run_state.build_snapshot.evolution_id == &"spiritualist"

func set_spiritualist_debug_text(enabled: bool) -> void:
	spiritualist_debug_text = enabled
	if spiritualist_panel != null:
		spiritualist_panel.visible = enabled
		if enabled:
			_update_spiritualist_panel()

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
	var spiritualist_style := _is_spiritualist_run()
	if spiritualist_style:
		label.custom_minimum_size = Vector2(200, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.global_position = actor.global_position + Vector2(-100, -maxf(82.0, 64.0 * actor.sprite_visual_scale + 20.0) - vertical_offset)
		label.add_theme_color_override("font_outline_color", Color("101725"))
		label.add_theme_constant_override("outline_size", 3)
	else:
		label.global_position = actor.global_position + Vector2(-22, -78 - vertical_offset)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 20
	add_child(label)
	var tween := create_tween()
	if not spiritualist_style:
		tween.tween_property(label, "position", label.position + Vector2(0, -34), 0.55)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55)
	else:
		tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.tween_callback(label.queue_free)
	return label

func _update_hud() -> void:
	if inventory_button != null:
		inventory_button.disabled = encounter_active or run_finished or inventory_frozen or not player.is_alive()
	if geometer_onboarding != null:
		geometer_onboarding.refresh()
	if sentinel_onboarding != null:
		sentinel_onboarding.refresh()
	if player == null or player.health == null:
		return
	health_label.text = "VIDA  %d / %d" % [ceili(player.health.current_hp), ceili(player.health.max_hp)]
	sp_label.text = "SP  %d / %d" % [floori(player.current_sp), floori(player.max_sp)]
	if player.is_sentinel() and player.sentinel_state.reserved_sp > 0.0:
		sp_label.text = "SP LIVRE %d / %d · %d reservado" % [floori(player.sentinel_free_sp()), floori(player.max_sp), ceili(player.sentinel_state.reserved_sp)]
	if sentinel_focus_label != null:
		var focus := player.sentinel_state
		sentinel_focus_label.text = "FOCO  %d / 100%s" % [floori(focus.free_focus()), " · %d reservado" % floori(focus.reserved_focus) if focus.reserved_focus > 0.0 else ""]
		sentinel_focus_bar.value = focus.focus
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
	augment_button.text = "Escolher augment (F8) — %d pendente(s)" % run_state.pending_choices
	augment_button.visible = run_state.pending_choices > 0
	if battle_controls != null:
		var available := player.available_skill_ids()
		battle_controls.set_skill_ranks(run_state.composed_build().get("skill_ranks", {}))
		if battle_controls.learned_skills != available:
			battle_controls.set_action_bar(available, action_slots, control_preferences)
			if not cast_intent.active_skill.is_empty() and cast_intent.active_skill not in available:
				_cancel_aim()
		for skill_id: StringName in player.available_skill_ids():
			battle_controls.show_skill_cooldown(skill_id, player.skill_cooldown(skill_id))
			var definition := ClassCatalog.skill_definition(skill_id)
			var cost := 0.0 if skill_id == &"shield_wall" and player.has_shield_stance() else player.skill_cost(skill_id)
			var rank_text := " R%d" % player.skill_rank(skill_id) if not definition.ranks.is_empty() else ""
			var state := _display_skill_state(skill_id, cost)
			battle_controls.show_skill_state(skill_id, "%s · %s%s\n%d SP · %s" % [_skill_input_label(skill_id), definition.display_name.to_upper(), rank_text, int(cost), state], cast_intent.active_skill == skill_id or player.active_cast_skill == skill_id)

		_update_slot_skill_states()

func _update_slot_skill_states() -> void:
	for index: int in action_slots.size():
		var skill := ActionBarLayout.skill_id(action_slots[index])
		if skill.is_empty():
			continue
		var requested := ActionBarLayout.selected_rank(action_slots[index])
		var previous := player.push_cast_rank(skill, requested)
		var accessible := skill in player.available_skill_ids() and player.selected_cast_rank_valid(skill)
		var definition := ClassCatalog.skill_definition(skill)
		var resolved := player.skill_rank(skill)
		var cost := player.skill_cost(skill)
		if not accessible and requested > 0:
			var preview := SkillEffectResolver.preview_retained(skill, requested, run_state.composed_build())
			var authored := definition.rank_definition(requested)
			cost = float(preview["values"]["sp_cost"]) if preview.get("ok", false) else (authored.sp_cost if authored != null else 0.0)
		if accessible and skill == &"shield_wall" and player.has_shield_stance():
			cost = 0.0
		var state := _display_skill_state(skill, cost) if accessible else "RANK INDISPONÍVEL"
		var active := (cast_intent.active_skill == skill and _intent_rank == requested) or (player.active_cast_skill == skill and player.active_cast_rank == resolved)
		var rank_text := " R%d" % (resolved if resolved > 0 else requested) if not definition.ranks.is_empty() else ""
		var resources := "%d SP" % ceili(cost)
		if accessible and player.is_sentinel() and skill in SentinelTuning.SKILL_IDS:
			resources += " · %d Foco" % ceili(float(SentinelTuning.values(skill, resolved)["focus_cost"]))
		battle_controls.show_skill_state(skill, "%s · %s%s\n%s · %s" % [control_preferences.binding_label(index), definition.display_name.to_upper(), rank_text, resources, state], active, requested)
		var details := _slot_runtime_description(skill, resolved)
		if not details.is_empty(): battle_controls.slot_buttons[index].tooltip_text += "\n" + details
		battle_controls.show_skill_cooldown(skill, player.skill_cooldown(skill))
		player.restore_cast_rank(previous)

func _slot_runtime_description(skill: StringName, rank: int) -> String:
	if rank <= 0: return ""
	if player.is_sentinel() and skill in SentinelTuning.SKILL_IDS:
		return ClassCatalog.sentinel_description(skill, rank)
	if player.is_hunter():
		if skill in HunterTuning.SKILL_IDS: return ClassCatalog.hunter_description(skill, rank)
		if skill == &"foliage_shelter": return ClassCatalog.hunter_cover_description()
	if skill == &"geometer_triangulation" and geometer_casting != null:
		var elements := geometer_casting.construction.elements()
		if elements.size() == 2: elements.append(geometer_casting.construction.grammar.selected_element)
		var suspended := "Construção suspensa — sem efeitos.\n" if geometer_casting.construction.suspended else ""
		return suspended + ClassCatalog.geometer_triangle_description(elements)
	return ""

func _skill_input_label(skill_id: StringName) -> String:
	var index := -1
	for slot: int in action_slots.size():
		if ActionBarLayout.skill_id(action_slots[slot]) == skill_id:
			index = slot
			break
	return control_preferences.binding_label(index) if index >= 0 else "Sem atalho"

func _display_skill_state(skill_id: StringName, sp_cost: float) -> String:
	if skill_id == &"sentinel_absolute_focus" and player.sentinel_state.absolute_remaining > 0.0:
		return "ATIVO %.1fs · %s" % [player.sentinel_state.absolute_remaining, _skill_state(player.skill_cooldown(skill_id), sp_cost, skill_id)]
	if skill_id == &"sentinel_explosive_shot" and player.sentinel_state.explosive_prepared:
		return "PREPARADO · CANCELAR"
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
	if player.is_sentinel():
		if skill_id in SentinelTuning.SKILL_IDS and not player.sentinel_state.can_pay(float(SentinelTuning.values(skill_id, player.skill_rank(skill_id)).get("focus_cost", 0.0))):
			return "SEM FOCO"
		if player.sentinel_free_sp() < sp_cost:
			return "SEM SP LIVRE"
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
		status_label.text = "Recompensa coletada — abra a escolha com F8"
	elif encounter_index < 2:
		status_label.text = "Augment aplicado — inicie o próximo encontro"

func _update_spiritualist_panel() -> void:
	if spiritualist_panel == null or not spiritualist_debug_text:
		return
	var target := _focused_spiritualist_target()
	var lines: Array[String] = []
	if target == null:
		lines.append("Alvo: nenhum · clique ou mire um inimigo")
	else:
		var target_id := target.get_instance_id()
		lines.append("Alvo: %s" % target.actor_name)
		if spiritualist_echo_state.marks.has(target_id):
			lines.append("MALDIÇÃO %.1fs · próxima skill direta prepara onda" % float(spiritualist_echo_state.marks[target_id]["remaining"]))
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
			hint = "Skill direta → onda de Eco em área."
			if equipped.has(&"spiritualist_dissipation"):
				hint += " Rito também ativa a onda."
		elif spiritualist_echo_state.pending.any(func(echo: Dictionary) -> bool: return int(echo["target_id"]) == target_id):
			hint = "Eco preparado; confirme o dano no impacto."
		elif equipped.has(&"spiritualist_echo_curse"):
			hint = "Maldição em área → skill direta → onda de Eco."
		else:
			hint = "Use as ações aprendidas; Maldição ainda não foi aprendida."
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
		lines.append("Maldição em área → skill direta → onda após %.2fs." % SpiritualistEchoState.ECHO_DELAY)
		if equipped.has(&"spiritualist_dissipation"):
			lines.append("Rito ativa a onda e preserva bônus contra marcados.")
	if equipped.has(&"spiritualist_soul_drain"):
		if player.run_state.build_snapshot.has_passive(&"spiritualist_channel_focus"):
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
	spiritualist_panel.visible = spiritualist_debug_text
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

func _build_geometer_controls() -> void:
	var panel := HBoxContainer.new()
	panel.position = Vector2(24, 284)
	panel.add_theme_constant_override("separation", 6)
	ui_root.add_child(panel)
	var names := ["F1 · Fogo", "F2 · Gelo", "F3 · Raio"]
	for index: int in range(3):
		var element := GeometerGeometry.ELEMENTS[index]
		var button := Button.new()
		button.text = names[index]
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(110, 38)
		button.button_pressed = element == &"fire"
		button.pressed.connect(_select_geometer_element.bind(element))
		panel.add_child(button)
		geometer_element_buttons[element] = button
	var clear_button := Button.new()
	clear_button.text = "⌫ · Desfazer"
	clear_button.custom_minimum_size = Vector2(132, 38)
	clear_button.tooltip_text = "Remove figura e flechas em trânsito sem Colapso. Esc apenas cancela a mira."
	clear_button.pressed.connect(_clear_geometer_construction)
	panel.add_child(clear_button)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 50
	add_child(canvas)
	ui_root = Control.new()
	canvas.add_child(ui_root)
	GuiMetrics.configure_root(ui_root)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = _battle_theme()
	var admin_button := Button.new()
	admin_button.text = "Admin · F10"
	admin_button.position = Vector2(24, 172)
	admin_button.pressed.connect(_open_admin_tools)
	ui_root.add_child(admin_button)
	admin_panel = PlaytestAdminPanel.new()
	ui_root.add_child(admin_panel)
	admin_panel.closed.connect(_close_admin_tools)
	admin_panel.changed.connect(_refresh_admin_profile)
	admin_panel.offer_requested.connect(_admin_open_offer)

	hud_panel = PanelContainer.new()
	ui_root.add_child(hud_panel)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_panel.offset_left = 24.0
	hud_panel.offset_top = 20.0
	hud_panel.offset_right = 544.0
	hud_panel.offset_bottom = 150.0
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
	# The action bar owns skill status; the complete learned library no longer
	# expands a duplicate HUD list over the arena and lower row.
	skill_label.hide()
	hud_column.add_child(health_label)
	hud_column.add_child(sp_label)
	if player.is_sentinel():
		hud_panel.offset_bottom = 156.0
		sentinel_focus_label = _make_label("FOCO 0 / 100", 16, Color("b4decb"))
		hud_column.add_child(sentinel_focus_label)
		sentinel_focus_bar = ProgressBar.new()
		sentinel_focus_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sentinel_focus_bar.custom_minimum_size = Vector2(0, 5)
		sentinel_focus_bar.show_percentage = false
		sentinel_focus_bar.max_value = SentinelFocusState.CAP
		hud_column.add_child(sentinel_focus_bar)
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
	var help_text := "CLIQUE: mover / autoatacar o alvo\nBarras: atalhos configuráveis em Controles\nDIREITO / ESC: cancelar mira\nF8: augment · F9: reiniciar ao concluir"
	if player.is_geometer():
		help_text = "F1 / F2 / F3: Fogo / Gelo / Raio\nTraçado: corpo = vínculo; fora = chão\nShift: forçar chão · F6: desfazer\nBarra: skills · Esc: cancelar mira"
	var help_label := _make_label(help_text, 16, Color("d7ddea"))
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_panel.add_child(help_label)
	if geometer_casting != null:
		help_panel.hide()
		geometer_onboarding = GeometerOnboarding.new()
		ui_root.add_child(geometer_onboarding)
		geometer_onboarding.configure(geometer_casting)
	if player.is_sentinel():
		help_panel.hide()
		sentinel_onboarding = SentinelOnboarding.new()
		ui_root.add_child(sentinel_onboarding)
		sentinel_onboarding.configure(player)
	if run_state.build_snapshot != null and run_state.build_snapshot.evolution_id == &"spiritualist":
		_build_spiritualist_panel()
	if geometer_casting != null:
		_build_geometer_controls()

	bottom_controls = VBoxContainer.new()
	ui_root.add_child(bottom_controls)
	bottom_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_controls.offset_left = -600.0
	bottom_controls.offset_top = -286.0
	bottom_controls.offset_right = 600.0
	bottom_controls.offset_bottom = -142.0
	bottom_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	status_label = _make_label("", 20, Color.WHITE)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bottom_controls.add_child(status_label)
	var buttons := HFlowContainer.new()
	buttons.alignment = FlowContainer.ALIGNMENT_CENTER
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_controls.add_child(buttons)
	augment_button = Button.new()
	augment_button.custom_minimum_size = Vector2(280, 44)
	augment_button.pressed.connect(_open_augment_menu)
	buttons.add_child(augment_button)
	inventory_button = Button.new()
	inventory_button.text = "Equipamentos / cartas"
	inventory_button.pressed.connect(_open_inventory)
	buttons.add_child(inventory_button)
	var acquisitions_button := Button.new()
	acquisitions_button.text = "Recompensas"
	acquisitions_button.visible = not training_mode
	acquisitions_button.pressed.connect(func() -> void: reward_feedback.open_history(0))
	buttons.add_child(acquisitions_button)
	inventory_panel = RunInventoryPanel.new()
	ui_root.add_child(inventory_panel)
	inventory_panel.closed.connect(_close_inventory)
	equipment_head = EquipmentHeadVisual.new()
	player.add_child(equipment_head)
	equipment_head.configure(player)
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
	var choices_scroll := ScrollContainer.new()
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_column.add_child(choices_scroll)
	choice_buttons = VBoxContainer.new()
	choice_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_buttons.add_theme_constant_override("separation", 14)
	choices_scroll.add_child(choice_buttons)
	augment_overlay.visible = false

	result_overlay = _make_overlay(ui_root)
	result_panel = PanelContainer.new()
	result_overlay.add_child(result_panel)
	result_panel.set_anchors_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -340.0
	result_panel.offset_top = -270.0
	result_panel.offset_right = 340.0
	result_panel.offset_bottom = 270.0
	var result_column := VBoxContainer.new()
	result_column.alignment = BoxContainer.ALIGNMENT_CENTER
	result_column.add_theme_constant_override("separation", 12)
	result_panel.add_child(result_column)
	result_title = _make_label("", 34, Color("e9c67b"))
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_column.add_child(result_title)
	result_body = _make_label("", 20, Color("d7ddea"))
	result_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_column.add_child(result_body)
	var result_rewards := Button.new()
	result_rewards.text = "Ver recompensas desta run"
	result_rewards.custom_minimum_size = Vector2(320,44)
	result_rewards.visible = not training_mode
	result_rewards.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result_rewards.pressed.connect(func() -> void: reward_feedback.open_history(0))
	result_column.add_child(result_rewards)
	restart_button = Button.new()
	restart_button.text = "Reiniciar arena (F9)"
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
	battle_controls.audio_panel.bind_service(presentation_audio())
	battle_controls.ui_action_confirmed.connect(_present_ui)
	battle_controls.set_options(control_preferences.cast_mode, control_preferences.smart_lock)
	battle_controls.set_interface_options(control_preferences.ui_scale, control_preferences.confine_cursor)
	battle_controls.interface_changed.connect(change_interface_preferences)
	_apply_interface_preferences()
	battle_controls.skill_selected.connect(_select_skill_from_bar)
	battle_controls.settings_requested.connect(_toggle_settings)
	battle_controls.preferences_changed.connect(_change_control_preferences)
	action_slots = run_state.build_snapshot.action_slots.duplicate(true)
	if action_slots.is_empty():
		action_slots = ActionBarLayout.from_legacy(run_state.build_snapshot.active_slots)
	if not ActionBarLayout.valid_references(action_slots):
		action_slots = ActionBarLayout.empty()
	battle_controls.set_skill_ranks(run_state.composed_build().get("skill_ranks", {}))
	battle_controls.set_action_bar(player.available_skill_ids(), action_slots, control_preferences)
	battle_controls.layout_changed.connect(_change_action_slots)
	battle_controls.bindings_changed.connect(_change_action_bindings)
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

	reward_feedback = RewardFeedbackPanel.new()
	ui_root.add_child(reward_feedback)
	reward_feedback.configure(acquisition_journal, run_state.effect_catalog(), persistent_facade != null)
	skill_window = SkillWindow.new()
	ui_root.add_child(skill_window)
	skill_window.set_embedded(false)
	skill_window.closed.connect(_close_skill_window)
	_skill_action_editor_home = battle_controls.action_editor.get_parent()
	_skill_action_editor_index = battle_controls.action_editor.get_index()
	var skill_open := Button.new()
	skill_open.text = "Habilidades"
	skill_open.focus_mode = Control.FOCUS_NONE
	buttons.add_child(skill_open)
	skill_open.pressed.connect(_open_skill_window)
	if campaign_runtime != null:
		var expedition_status := ExpeditionStatusPanel.new()
		expedition_status.host = self
		ui_root.add_child(expedition_status)
	_build_stage_minimap()


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

func _on_mob_skill_requested(request: DamageRequest, target_actor: CombatActor, speed: float, maximum_range: float) -> void:
	var source := instance_from_id(request.source_id) as Node2D
	if source == null or target_actor == null: return
	var projectile := MageProjectile.new()
	var color := Color("74c9ff") if request.skill_id == &"ice_spear" else Color("ff793d")
	projectile.configure_homing(request.copy(), target_actor, source.global_position + Vector2(0, -18), navigation, speed, maximum_range, color)
	projectile.hit.connect(_on_mob_skill_hit)
	if source is CombatActor and source.world_motion != null:
		var bound := _bind_world_projectile(projectile,source,target_actor)
		if not bound["ok"]: projectile.free(); return
	elif geometer_casting != null: projectile.geometer_field = geometer_casting.wall_field
	add_child(projectile)
	projectile.add_to_group("enemy_projectiles")

func _on_mob_skill_hit(request: DamageRequest, target_actor: CombatActor) -> void:
	if target_actor == null or not target_actor.is_alive(): return
	var result := target_actor.apply_damage(request, rng)
	SkillImpactRules.spear(request.skill_id, result, target_actor)

func _open_inventory() -> void:
	reward_feedback.hide_history()
	reward_feedback.hide_recent()
	if encounter_active or run_finished or not player.is_alive() or get_tree().paused or inventory_frozen: return
	_cancel_casting(false)
	_clear_hover()
	# F10 Q3: the windows stay above the action bar and its shortcuts.
	if is_instance_valid(bottom_controls) and ui_root != null and ui_root.scale.y > 0.0:
		var bar_top := bottom_controls.get_global_transform_with_canvas().origin.y
		inventory_panel.bottom_reserved = maxf(0.0, get_viewport().get_visible_rect().size.y - bar_top) / ui_root.scale.y
	inventory_panel.configure(self)
	get_tree().paused = true
func _close_inventory() -> void:
	inventory_panel.hide()
	_cancel_casting(false)
	get_tree().paused = run_finished or inventory_frozen or augment_overlay.visible or class_overlay.visible or battle_controls.settings_overlay.visible

func _encounter_count() -> int:
	return PlaytestGameplay.STAGE_COUNT if gameplay_extension else 2

func _configure_world(stage: int) -> void:
	if is_instance_valid(player) and player.world_motion != null: world_spawn_error = &"world_lifecycle_required"; return
	active_bounds = PlaytestGameplay.BOUNDS if gameplay_extension else ARENA_BOUNDS
	var obstacles: Array[Rect2] = PlaytestGameplay.obstacles(stage) if gameplay_extension else ARENA_OBSTACLES.duplicate()
	if expedition_entry_mode: obstacles.clear()
	_begin_presentation_stage("legacy/%d" % stage)
	navigation.configure(active_bounds, obstacles, 22.0)
	arena_view.configure(active_bounds, obstacles)
	_configure_stage_minimap(true)
	for view: Node2D in _world_obstacle_views:
		if is_instance_valid(view): view.free()
	_world_obstacle_views.clear()
	for obstacle: Rect2 in obstacles:
		var view := ArenaObstacleView.new()
		view.configure(obstacle)
		add_child(view)
		_world_obstacle_views.append(view)
	if route_camera != null:
		route_camera.limit_left = int(active_bounds.position.x - 40)
		route_camera.limit_top = int(active_bounds.position.y - 40)
		route_camera.limit_right = int(active_bounds.end.x + 40)
		route_camera.limit_bottom = int(active_bounds.end.y + 40)
	if gameplay_extension:
		arena_view.modulate = [Color("f2ffe7"), Color("d6ead8"), Color("d8e1ef")][int((stage - 1) / 2.0)]

func spawn_world_enemy(entry: Dictionary, point: ExpeditionWorldPoint, traversal: Dictionary, revision: int, stage: int = 1, companion_traversal: Dictionary = {}) -> Dictionary:
	if not is_instance_valid(player) or player.world_motion == null: return WorldSkillCast.failure(&"spatial_binding_required")
	if _startup_error: return WorldSkillCast.failure(&"startup_unavailable")
	if stage < 1 or stage > PlaytestGameplay.STAGE_COUNT: return WorldSkillCast.failure(&"invalid_stage")
	if not entry.has_all(["species","category"]): return WorldSkillCast.failure(&"invalid_occurrence")
	if not (entry["species"] is String or entry["species"] is StringName) or not (entry["category"] is String or entry["category"] is StringName): return WorldSkillCast.failure(&"invalid_occurrence")
	world_spawn_error = &""
	var birth := {"point":point,"traversal":traversal.duplicate(true),"revision":revision,"companion_traversal":companion_traversal.duplicate(true)}
	var actor := _spawn_route_enemy(entry.duplicate(true),stage,false,0,false,birth)
	return {"ok":actor != null,"error_code":&"" if actor != null else world_spawn_error,"data":{"actor":actor} if actor != null else {}}

func _world_birth_check(point: ExpeditionWorldPoint, traversal: Dictionary, revision: int, source: CombatActor) -> Dictionary:
	if not is_instance_valid(player) or player.world_motion == null or not is_instance_valid(source) or source.world_motion == null: return WorldSkillCast.failure(&"spatial_binding_required")
	var world := player.world_motion.geometry
	if run_finished or (is_inside_tree() and get_tree().paused) or not player.is_alive() or not source.is_alive(): return WorldSkillCast.failure(&"world_birth_unavailable")
	if not player.world_motion.is_current_world() or not source.world_motion.is_current_world() or source.world_motion.geometry != world: return WorldSkillCast.failure(&"world_reconfigured")
	var placed := world.position_query(point,traversal,revision)
	if not placed["ok"]: return placed
	if not placed["data"]["occupants"].is_empty(): return WorldSkillCast.failure(&"occupied")
	return world.path(source.world_point(),point,traversal,revision)

func _spawn_route_enemy(entry: Dictionary, stage: int, summoned: bool = false, owner_id: int = 0, admin_spawn: bool = false, world_birth: Dictionary = {}) -> EnemyActor:
	if _startup_error: return null
	var source: CombatActor = player
	if summoned:
		source = instance_from_id(owner_id) as EnemyActor
		if not is_instance_valid(source) or not source.is_alive() or source.get_parent() != self or source not in enemies: world_spawn_error = &"invalid_summoner"; return null
	var logical := player.world_motion != null
	var position := Vector2.ZERO
	if logical:
		if not world_birth.has_all(["point","traversal","revision","companion_traversal"]): world_spawn_error = &"world_birth_required"; return null
		var valid := _world_birth_check(world_birth["point"],world_birth["traversal"],world_birth["revision"],source)
		if not valid["ok"]: world_spawn_error = valid["error_code"]; return null
	else:
		if not world_birth.is_empty(): world_spawn_error = &"spatial_binding_required"; return null
		var path := navigation.get_path(source.global_position,entry["position"])
		if path.is_empty():
			_startup_failure("Uma posição de inimigo está inacessível.")
			return null
		position = path[-1]
	var enemy := EnemyActor.new()
	enemy.global_position = position
	enemy.set_meta("admin_spawn", admin_spawn)
	enemy.is_summoned = summoned
	enemy.summoner_id = owner_id
	enemy.companion_requested.connect(_queue_companion_request)
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "trial_%d_%d" % [stage, enemy.get_instance_id()]
	occurrence.mob_base_id = entry["species"]
	occurrence.category_id = entry["category"]
	occurrence.origin_id = PlaytestGameplay.origin(stage)
	if summoned and campaign_runtime != null and source is EnemyActor and source.occurrence != null:
		occurrence.origin_id = source.occurrence.origin_id
		occurrence.occurrence_id = "summon_" + source.occurrence.occurrence_id.sha256_text().substr(0, 57)
	var checked := enemy.configure_occurrence(occurrence, run_state.effect_catalog().mob_catalog(), navigation, player)
	if not checked.get("ok", false):
		enemy.free()
		if logical: world_spawn_error = checked["error_code"]
		else: _startup_failure("O conteúdo de um inimigo não pôde ser carregado.")
		return null
	if logical:
		if enemy._mob_definition.summons_companion and not player.world_motion.geometry._profile_valid(world_birth["companion_traversal"]):
			enemy.free(); world_spawn_error = &"companion_profile_required"; return null
		var bound := enemy.bind_world_geometry(player.world_motion.geometry,world_birth["point"],world_birth["traversal"],str(enemy.get_instance_id()))
		if not bound["ok"]: enemy.free(); world_spawn_error = bound["error_code"]; return null
		enemy.set_meta("world_companion_traversal",world_birth["companion_traversal"].duplicate(true))
		enemy.set_meta("world_birth_stage",stage)
	enemy.compact_control_visuals = player.is_geometer() or player.is_sentinel()
	enemy.actor_name += " · %s · Nv.%d" % [MobPrototypeVisual.category_name(occurrence.category_id), checked.get("level", run_state.effect_catalog().mob_catalog().level_for_occurrence(occurrence)["level"])]
	if enemy._mob_definition.animation_kind in [&"gel", &"beast_master", &"animal_companion"]:
		enemy.sprite_visual_scale = 1.0 + MobCatalog.CATEGORIES.find(occurrence.category_id) * 0.13
	var caption := Label.new()
	caption.text = "%s · Nv.%d" % [enemy._mob_definition.display_name, enemy.stat_breakdown.base_level]
	caption.text += "\n" + MobPrototypeVisual.category_name(occurrence.category_id)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(-110, -54.0 * enemy.sprite_visual_scale - (42 if enemy._mob_definition.visual_kind == &"humanoid" else 28))
	caption.size = Vector2(220, 36)
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("f2f5ef"))
	caption.add_theme_color_override("font_outline_color", Color("172723"))
	caption.add_theme_constant_override("outline_size", 4)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy.add_child(caption)
	enemy.attack_requested.connect(_on_enemy_attack_requested)
	enemy.mob_skill_requested.connect(_on_mob_skill_requested)
	enemy.actor_died.connect(_on_enemy_died)
	enemy.health.damage_applied.connect(_on_enemy_damage_resolved)
	enemy.damage_number.connect(_show_damage_number)
	enemy.attack_missed.connect(_show_miss)
	enemy.status_damage_requested.connect(_on_attack_requested)
	add_child(enemy)
	enemies.append(enemy)
	if not summoned and not admin_spawn and reward_service != null and reward_service.mob_loot_enabled():
		var registered_loot := reward_service.register_mob_actor(enemy)
		if not registered_loot.get("ok", false):
			if logical:
				enemies.erase(enemy); enemy.free(); world_spawn_error = registered_loot["error_code"]; return null
			_startup_failure("Não foi possível preparar as recompensas dos inimigos.")
	if trap_registry != null:
		for trap: PlayerTrap in trap_registry.active_traps():
			if trap is HunterTrap: (trap as HunterTrap).track_target(enemy)
	if is_instance_valid(hunter_tar_field) and hunter_tar_field.active: hunter_tar_field.track_target(enemy)
	return enemy

func _queue_companion_request(master: EnemyActor) -> void:
	if not is_instance_valid(master): return
	_world_pending_companions[master.get_instance_id()] = weakref(master)
	_deliver_companion_request.call_deferred(weakref(master))

func _deliver_companion_request(reference: WeakRef) -> void:
	var master := reference.get_ref() as EnemyActor
	if not is_instance_valid(master) or not _world_pending_companions.has(master.get_instance_id()) or (is_inside_tree() and get_tree().paused): return
	_world_pending_companions.erase(master.get_instance_id())
	_on_companion_requested(master)

func _on_companion_requested(master: EnemyActor) -> void:
	if not is_instance_valid(master) or not master.is_alive() or master.is_summoned or master.get_parent() != self or master not in enemies or run_finished or (not encounter_active and not master.get_meta("admin_spawn", false)): return
	if master.get_meta("admin_spawn", false):
		var living := 0
		for actor: CombatActor in enemies:
			if is_instance_valid(actor) and actor.is_alive(): living += 1
		if living >= PlaytestRunAdmin.ACTOR_CAP: return
	if master.world_motion != null:
		_spawn_world_companion(master)
		return
	if player.world_motion != null: return
	var category := MobTierRules.lower_category(master.occurrence.category_id)
	if category.is_empty(): return
	for offset: Vector2 in [Vector2(-185,45), Vector2(185,45), Vector2(0,170), Vector2(0,-170)]:
		var position := master.global_position + offset
		if not navigation.is_walkable(position) or position.distance_to(player.global_position) < 45.0: continue
		var occupied := false
		for actor: CombatActor in enemies:
			if actor.is_alive() and actor.global_position.distance_to(position) < 45.0: occupied = true
		if occupied: continue
		_spawn_route_enemy({"species": &"test_animal_companion", "category": category, "position": position}, clampi(encounter_index, 1, PlaytestGameplay.STAGE_COUNT), true, master.get_instance_id(), bool(master.get_meta("admin_spawn", false)))
		return

func _advance_world_companion_requests() -> void:
	if (is_inside_tree() and get_tree().paused) or _world_pending_companions.is_empty(): return
	var pending: Array = _world_pending_companions.values()
	_world_pending_companions.clear() # Before callbacks can add another request.
	for reference: WeakRef in pending:
		var master := reference.get_ref() as EnemyActor
		if is_instance_valid(master): _on_companion_requested(master)

func _spawn_world_companion(master: EnemyActor) -> void:
	var stage := int(master.get_meta("world_birth_stage",0))
	if stage < 1 or stage > PlaytestGameplay.STAGE_COUNT: world_spawn_error = &"invalid_stage"; return
	if _world_companion_attempts.has(master.get_instance_id()): return
	if not master.summon_used or master.occurrence == null or not master.world_motion.is_current_world() or player.world_motion == null or not player.world_motion.is_current_world() or master.world_motion.geometry != player.world_motion.geometry: return
	if is_inside_tree() and get_tree().paused:
		_world_pending_companions[master.get_instance_id()] = weakref(master)
		return
	_world_companion_attempts[master.get_instance_id()] = true # One finite handling, including a failed supported search.
	var world := master.world_motion.geometry
	var traversal: Dictionary = master.get_meta("world_companion_traversal",{})
	if not world._profile_valid(traversal): world_spawn_error = &"companion_profile_required"; return
	var category := MobTierRules.lower_category(master.occurrence.category_id)
	if category.is_empty(): return
	for offset: Vector2 in [Vector2(-185,45),Vector2(185,45),Vector2(0,170),Vector2(0,-170)]:
		var center := master.world_point()
		var exact := world.ground_line_point_at(center,Vector2(center.position.x,center.position.z)+offset,traversal,world.geometry_revision)
		if not exact["ok"]: continue
		var data: Dictionary = exact["data"]["point"]
		var point := ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
		if not _world_birth_check(point,traversal,world.geometry_revision,master)["ok"]: continue
		var occupied := player.world_point().position.distance_to(point.position) < 45.0
		for candidate: Variant in enemies:
			if not is_instance_valid(candidate): continue
			var actor := candidate as CombatActor
			if actor == null or not actor.is_alive(): continue
			if actor.world_motion == null or not actor.world_motion.is_current_world() or actor.world_motion.geometry != world: occupied = true; break
			if actor.world_point().position.distance_to(point.position) < 45.0: occupied = true; break
		if occupied: continue
		_spawn_route_enemy({"species":&"test_animal_companion","category":category},stage,true,master.get_instance_id(),bool(master.get_meta("admin_spawn",false)),{"point":point,"traversal":traversal.duplicate(true),"revision":world.geometry_revision,"companion_traversal":{}})
		return

func _remove_master_companion(owner_id: int) -> void:
	for actor: CombatActor in enemies.duplicate():
		if actor is EnemyActor and actor.is_summoned and actor.summoner_id == owner_id:
			_discard_companion(actor)

func _remove_remaining_companions() -> void:
	for actor: CombatActor in enemies.duplicate():
		if actor is EnemyActor and actor.is_summoned:
			_discard_companion(actor)

func _required_enemies() -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	for actor: CombatActor in enemies:
		if is_instance_valid(actor) and actor.is_alive() and not actor.get_meta("admin_spawn", false) and not (actor is EnemyActor and actor.is_summoned): result.append(actor)
	return result

func _discard_companion(actor: EnemyActor) -> void:
	actor.health.current_hp = 0.0
	actor.clear_statuses()
	_defender_slowed_enemies.erase(actor.get_instance_id())
	player.hunter_state.discard_target(actor.get_instance_id())
	player.remove_berserker_wound(actor.get_instance_id())
	player.remove_elementalist_target(actor.get_instance_id())
	spiritualist_echo_state.remove_target(actor.get_instance_id())
	if spiritualist_drain_state.target_id == actor.get_instance_id(): _cancel_spiritualist_drain()
	if spiritualist_procession_state.target_id == actor.get_instance_id(): _cancel_spiritualist_procession()
	_spiritualist_veil_members.erase(actor.get_instance_id())
	if player.target == actor: player.target = null
	if _hovered_enemy == actor: _hovered_enemy = null
	if _selected_enemy == actor: _selected_enemy = null
	enemies.erase(actor)
	actor.queue_free()

func _on_reward_confirmed(receipt: Dictionary) -> void:
	if not training_mode:
		acquisition_journal.record_reward(receipt, run_state.effect_catalog())

func _open_skill_window() -> void:
	if skill_window == null or run_finished or get_tree().paused:
		return
	_cancel_casting(false)
	_clear_hover()
	reward_feedback.hide_history()
	reward_feedback.hide_recent()
	var composed := run_state.composed_build()
	if not composed.get("ok", false):
		status_label.text = "Habilidades indisponíveis — build inválida."
		return
	battle_controls.set_skill_ranks(composed["skill_ranks"])
	var skill_preview := SkillPresentation.run_preview(run_state, persistent_facade)
	skill_window.configure_catalog(skill_preview["skills"], skill_preview["summary"], skill_preview["base_class_id"])
	battle_controls.action_editor.reparent(skill_window.action_host)
	battle_controls.action_editor.slots_grid.columns = 6
	skill_window.open()
	battle_controls.set_skill_ranks(composed["skill_ranks"])
	get_tree().paused = true

func _close_skill_window() -> void:
	battle_controls.cancel_binding_capture()
	if is_instance_valid(_skill_action_editor_home):
		battle_controls.action_editor.reparent(_skill_action_editor_home)
		_skill_action_editor_home.move_child(battle_controls.action_editor, _skill_action_editor_index)
		battle_controls.action_editor.slots_grid.columns = 12
	get_tree().paused = run_finished or augment_overlay.visible or inventory_panel.visible or class_overlay.visible or battle_controls.settings_overlay.visible

func _open_admin_tools() -> void:
	if run_finished or inventory_frozen or not player.is_alive(): return
	if admin_panel.visible: return
	if get_tree().paused or run_state.has_open_offer(): return
	_cancel_casting(false)
	_clear_hover()
	admin_panel.configure(persistent_facade, run_state.character_id, self)
	get_tree().paused = true

func _close_admin_tools() -> void:
	get_tree().paused = run_finished or inventory_frozen or augment_overlay.visible or inventory_panel.visible or skill_window.visible or class_overlay.visible or battle_controls.settings_overlay.visible

func _admin_open_offer() -> void:
	_close_admin_tools()
	_open_augment_menu()

func _refresh_admin_profile() -> void:
	if persistent_facade == null: return
	var profile := persistent_facade.current_profile()
	var character := profile.character_by_id(run_state.character_id)
	if character == null: return
	var snapshot := persistent_facade._build_snapshot(character)
	snapshot.build_version = run_state.build_snapshot.build_version + 1
	run_state.build_snapshot = snapshot
	run_state.skill_levels = snapshot.skill_ranks.duplicate(true)
	run_state.card_inventory = profile.card_inventory.copy_inventory()
	run_state.card_sockets = run_state.card_inventory.sockets()
	run_state.card_instances = run_state.card_inventory.describe()["instances"]
	run_state.runtime_revision += 1
	player.apply_run_modifiers(run_state)
	battle_controls.set_skill_ranks(run_state.composed_build()["skill_ranks"])
	if inventory_frozen: set_inventory_freeze(false)

func _clear_admin_spawns() -> void:
	for actor: CombatActor in enemies.duplicate():
		if is_instance_valid(actor) and actor.get_meta("admin_spawn", false):
			_discard_companion(actor as EnemyActor)

func _startup_failure(message: String) -> void:
	if _startup_error: return
	_startup_error = true
	push_error(message)
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.layer = 200
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color("101b27")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var box := VBoxContainer.new()
	box.position = Vector2(80, 120)
	box.custom_minimum_size = Vector2(640, 100)
	background.add_child(box)
	var label := Label.new()
	label.text = message + "\nA partida foi interrompida sem conceder recompensas.\nConfira os arquivos da versão instalada."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var back := Button.new()
	back.text = "Voltar ao menu"
	back.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/character_menu.tscn")
	)
	box.add_child(back)

func attach_expedition_view(view: ExpeditionGeometryView, field_height: float) -> Dictionary:
	if player.world_motion == null or not view.current() or view.geometry != player.world_motion.geometry or not is_finite(field_height) or field_height <= 0: return WorldSkillCast.failure(&"invalid_presentation_binding")
	if geometer_casting != null:
		var bound := geometer_casting.bind_world_construction(field_height)
		if not bound["ok"]: return bound
	expedition_view = view; expedition_field_height = field_height; view.controller = self
	var stage_biome := String(view.geometry._stage.get("biome",""))
	_begin_presentation_stage(player.world_point().stage_id, snapshot_passive, stage_biome)
	_configure_stage_minimap()
	# Interactive play searches long routes on a worker thread; headless runs,
	# tests and RAGRPG_SYNC_NAVIGATION=1 stay synchronous.
	view.geometry.navigation_async = DisplayServer.get_name() != "headless" and OS.get_environment("RAGRPG_SYNC_NAVIGATION") != "1"
	# Checkpoint38: themed parallax behind the world instead of a flat colour.
	var backdrop: Variant = get_node_or_null("ExpeditionBackdrop")
	if backdrop == null:
		backdrop = ExpeditionBackdropScript.new(); add_child(backdrop)
	backdrop.configure(stage_biome)
	# P5 A2: forest-only ambience, a disposable child of the view (snapshot-excluded).
	var campaign_input: Dictionary = campaign_runtime.state.manifest_data.get("input",{}) if campaign_runtime != null else {}
	ForestAmbienceScript.install(view,stage_biome,ForestAmbienceScript.stage_seed(String(campaign_input.get("seed_text","")),player.world_point().stage_id))
	view.observe(player)
	view.present_campaign(self)
	for actor: CombatActor in enemies:
		if actor.world_motion != null and actor.world_motion.geometry == view.geometry: view.observe(actor)
	return {"ok":true,"error_code":&""}
func spatial_pointer_move(point: Vector2) -> Dictionary:
	if expedition_view == null or get_tree().paused or run_finished or not player.is_alive(): return WorldSkillCast.failure(&"pointer_unavailable")
	var victim := _world_enemy_at(point)
	if victim != null:
		player.pursue(victim); _select_enemy(victim)
		expedition_view.indicate(victim.world_point(),true)
		return {"ok":true,"error_code":&""}
	var result := expedition_view.pick(point,expedition_view.geometry.geometry_revision)
	if not result["ok"]:
		expedition_view.indicate(null,false); status_label.text = "Clique sem superfície visível única."
		return result
	var data: Dictionary = result["data"]["point"]
	var destination := ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
	return _request_world_click(destination,result["geometry_revision"],false)

# Plan before cancelling the current action: a rejected click changes no gameplay
# state. In the background, the player keeps the current action until the answer.
func _request_world_click(destination: ExpeditionWorldPoint, revision: int, retried: bool) -> Dictionary:
	if not _pending_world_click.is_empty(): _pending_world_click.request.cancel()
	_pending_world_click = {}
	var request := expedition_view.geometry.request_path(player.world_point(),destination,player.world_motion.profile(),revision,null,10)
	if request.done(): return _apply_world_click(request.result,destination,revision,false)
	_pending_world_click = {"request":request,"destination":destination,"retried":retried}
	expedition_view.indicate(destination,true)
	status_label.text = "Calculando caminho…"
	return {"ok":true,"pending":true,"error_code":&"","geometry_revision":revision,"data":{}}

func _apply_world_click(route: Dictionary, destination: ExpeditionWorldPoint, revision: int, background: bool) -> Dictionary:
	if route["ok"]:
		if background:
			# Join the answer to where the player is now; a route that cannot be
			# joined is refused before any gameplay state changes.
			route = player.world_motion.adopt_route(route,destination,revision,false)
			if not route["ok"]: return route
		player.cancel_active_cast(); player.target = null
		route = player.world_motion.adopt_route(route,destination,revision)
		expedition_view.indicate(destination,route["ok"])
	else: expedition_view.indicate(destination,false)
	status_label.text = "Movendo pela superfície" if route["ok"] else "Destino sem caminho transitável."
	return route

func _pump_world_navigation() -> void:
	if expedition_view == null or expedition_view.geometry == null: return
	expedition_view.geometry.navigation_pump()
	if _pending_world_click.is_empty() or not _pending_world_click.request.done(): return
	var pending := _pending_world_click; _pending_world_click = {}
	if run_finished or not is_instance_valid(player) or not player.is_alive() or player.world_motion == null: return
	var request: WorldGeometry.PathRequest = pending.request
	var applied := _apply_world_click(request.result,pending.destination,request.revision,true)
	# The player walked off the route's start meanwhile: search once more from here.
	if not applied["ok"] and applied.get("error_code",&"") == &"route_moved" and not pending.retried:
		_request_world_click(pending.destination,expedition_view.geometry.geometry_revision,true)
	elif not applied["ok"]:
		expedition_view.indicate(pending.destination,false); status_label.text = "Destino sem caminho transitável."
func spatial_pointer_skill(skill: StringName, point: Vector2, preview: bool) -> Dictionary:
	if expedition_view == null or not expedition_view.current() or get_tree().paused or run_finished or not player.is_alive(): return WorldSkillCast.failure(&"pointer_unavailable")
	var revision := expedition_view.geometry.geometry_revision
	var victim := _world_enemy_at(point,skill)
	var result := expedition_view.pick(point,revision)
	var anchor: ExpeditionWorldPoint
	if victim != null and not Input.is_key_pressed(KEY_SHIFT): anchor = victim.world_point()
	elif result["ok"]:
		var data: Dictionary = result["data"]["point"]
		anchor = ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
	elif skill in WorldSkillCast.SELF_AREAS or skill in WorldSkillCast.SELF_STATE or skill in [&"shield_wall",&"sentinel_explosive_shot",&"geometer_collapse"]: anchor = player.world_point()
	else: expedition_view.indicate(null,false); return result
	if Input.is_key_pressed(KEY_SHIFT): victim = null
	var facing := anchor.position-player.world_point().position
	var ground_field := skill in [&"fire_wall",&"lightning_wall",&"phantom_barrier",&"ice_wall"]
	if ground_field: facing.y = 0.0 # Ground heading selects x/z; support supplies height.
	if facing.is_zero_approx(): facing = Vector3.RIGHT
	var field_preview: Dictionary = {}
	var rank := _intent_rank
	if GeometerCastCommand.is_grammar_skill(skill):
		result = geometer_casting.preview_world_trace(skill,anchor,victim,revision,rank) if preview else geometer_casting.begin_world_trace(skill,anchor,victim,revision,rank)
	elif skill in [&"dash",&"teleport"]:
		var rule := &"walk_path" if skill == &"dash" else &"teleport_legal"
		if preview:
			result = expedition_view.geometry.path(player.world_point(),anchor,player.world_motion.profile(),revision) if rule == &"walk_path" else expedition_view.geometry.query_attack({"geometry_rule_id":rule,"range":player.skill_range(skill),"traversal":player.world_motion.profile()},player.world_point(),anchor,revision)
			if result["ok"] and (not result["data"].get("hit",true) or float(result["data"].get("cost",0)) > player.skill_range(skill)): result = WorldSkillCast.failure(&"out_of_range")
		else: result = {"ok":player.use_world_dash(anchor,revision) if skill == &"dash" else player.use_world_teleport(anchor,revision)}
	elif skill == &"shield_wall":
		result = {"ok":player.has_shield_stance() or player._can_pay_skill(&"shield_wall")} if preview else {"ok":player.use_world_shield_wall(Vector3(facing.x,0,facing.z).normalized(),revision)}
	elif skill == &"sentinel_explosive_shot":
		result = {"ok":player.sentinel_state.explosive_prepared or player._can_pay_skill(skill)} if preview else player.prepare_world_sentinel_explosive(revision)
	else:
		if ground_field and not preview: field_preview = player.preview_world_skill(skill,anchor,facing,victim,enemies,revision,rank,expedition_field_height)
		result = player.preview_world_skill(skill,anchor,facing,victim,enemies,revision,rank,expedition_field_height) if preview else cast_world_skill(skill,anchor,facing,victim,revision,rank,expedition_field_height)
		if ground_field and preview: field_preview = result
	var feedback_anchor := anchor
	if ground_field and field_preview.get("ok",false):
		var data: Dictionary = field_preview.get("data",{}).get("field",{}).get("anchor",{})
		if not data.is_empty(): feedback_anchor = ExpeditionWorldPoint.create(data["stage_id"],data["surface_id"],data["position"])
	expedition_view.attack_preview = {"from":player.world_point().position,"to":feedback_anchor.position,"valid":result["ok"]}
	expedition_view.indicate(feedback_anchor,result["ok"])
	return result

# This foundation API queues the same F3 barrier. F7 owns lobby/navigation UI.
func request_durable_suspend(expedition_id: String, phase_id: StringName, request_id: String, expected_revision: int) -> Dictionary:
	if persistent_facade == null: return WorldSkillCast.failure(&"invalid_session")
	var requested := request_memory_snapshot()
	if not requested["ok"]: return requested
	var captured: Dictionary = await memory_snapshot_ready
	# Complete the signal emission before a caller may retire/free this host.
	await get_tree().process_frame
	if not captured["ok"]: return captured
	var service := ExpeditionService.new(persistent_facade)
	var result := service.commit_cut(self,captured["snapshot"],expedition_id,phase_id,request_id,expected_revision,true,captured["encoding"])
	# Keep reconciliation context reachable while this scene remains frozen.
	if result.get("read_only",false): result["transaction_service"] = service
	return result
