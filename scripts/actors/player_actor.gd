class_name PlayerActor
extends CombatActor

const IceWallScript = preload("res://scripts/world/ice_wall.gd")

signal attack_requested(request: DamageRequest, target: CombatActor)
signal defender_hit_requested(request: DamageRequest, target: CombatActor, root_duration: float, push_direction: Vector2)
signal berserker_rift_hit_requested(request: DamageRequest, target: CombatActor, bleed_request: DamageRequest)
signal berserker_breath_hit_requested(request: DamageRequest, target: CombatActor, heal_fraction: float, marked_before_hit: bool)
signal mage_projectile_requested(skill_id: StringName, request: DamageRequest, target: CombatActor, direction: Vector2, count: int)
signal discharge_requested(request: DamageRequest, direction: Vector2, bonus_magic_damage: float)
signal precision_projectile_requested(skill_id: StringName, request: DamageRequest, target: CombatActor, direction: Vector2, count: int, hit_limit: int)
signal sentinel_projectile_requested(request: DamageRequest, target: CombatActor, direction: Vector2, payload: Dictionary)
signal arrow_rain_requested(center: Vector2, request: DamageRequest)
signal snare_trap_requested(center: Vector2, root_duration: float)
signal explosive_trap_requested(center: Vector2, request: DamageRequest)
signal hunter_trap_requested(center: Vector2, rank: int, request: DamageRequest, opening: DamageRequest)
signal slowing_arrow_requested(request: DamageRequest, direction: Vector2, slow_fraction: float, slow_duration: float)
signal foliage_shelter_requested(center: Vector2, duration: float)
signal hunter_total_cover_requested(center: Vector2, duration: float, radius: float, exit_grace: float)
signal hunter_covering_shot_requested(request: DamageRequest, origin: Vector2, direction: Vector2)
signal fire_wall_requested(direction: Vector2, burn_request: DamageRequest)
signal elementalist_flame_burst_requested(center: Vector2, request: DamageRequest)
signal elementalist_area_requested(skill_id: StringName, center: Vector2, radius: float, request: DamageRequest, element: StringName)
signal elementalist_lightning_arc_requested(request: DamageRequest, target: CombatActor, jump_damage: float, marked_bonus: float)
signal elementalist_ember_path_requested(centers: Array[Vector2], request: DamageRequest)
signal elementalist_tri_nova_requested(center: Vector2, requests: Array[DamageRequest], marked_bonus: float)
signal spiritualist_echo_curse_requested(request: DamageRequest, target: CombatActor, echo_power: float)
signal spiritualist_drain_requested(request: DamageRequest, target: CombatActor)
signal spiritualist_veil_requested(center: Vector2, duration: float, weaken_fraction: float)
signal spiritualist_procession_requested(request: DamageRequest, target: CombatActor)
signal spiritualist_dissipation_requested(center: Vector2, request: DamageRequest, marked_bonus: float, focus_bonus: float)
signal spiritualist_channel_interrupt_requested
signal spiritualist_focus_event(kind: StringName)
signal lightning_wall_requested(direction: Vector2, request: DamageRequest)
signal soul_impact_requested(request: DamageRequest, target: CombatActor)
signal haunt_requested(origin: Vector2, direction: Vector2, cone_range: float, request: DamageRequest)
signal phantom_barrier_requested(direction: Vector2, placement_range: float, capacity: int)
signal ice_wall_requested(wall: IceWallScript)
signal provoke_requested(target: CombatActor, duration: float)
signal piercing_shout_requested(origin: Vector2, request: DamageRequest, radius: float, duration: float)
signal brutal_strike_requested(request: DamageRequest, target: CombatActor)
signal terrifying_shout_requested(origin: Vector2, radius: float, fear_duration: float)
signal skill_cast_ready(skill_id: StringName, point: Vector2, target_id: int)
signal geometer_cast_ready(command: GeometerCastCommand)
signal resources_changed

const SLASH_SP_COST := 15.0
const DASH_DURATION := 0.18
const BASIC_REACH_BEYOND_BODIES := 50.0
const ATTACK_RETENTION := 16.0
const BASIC_ATTACK_RECOVERY := 0.14
const MOVEMENT_EPSILON := 0.01
const MOVE_ACCELERATION := 1100.0
const MOVE_FRICTION := 1600.0
const MAX_MOVEMENT_STEP := 1.0 / 120.0
const ARRIVAL_TOLERANCE := 0.05
const SLASH_RANGE := 155.0
const SLASH_HALF_ANGLE := deg_to_rad(52.0)
const HAUNT_HALF_ANGLE := deg_to_rad(42.0)
const HAUNT_FEAR_DURATION := 0.90
const HAUNT_WEAKEN_FRACTION := 0.25
const HAUNT_WEAKEN_DURATION := 3.0
const MAGE_BASIC_SPEED := 620.0
const MAGE_BASIC_MAX_DISTANCE := 420.0
const ARCHER_BASIC_SPEED := 880.0
const ARCHER_BASIC_MAX_DISTANCE := 520.0
const PIERCING_ARROW_MAX_HITS := 3
const EXTENDED_AIM_RANGE_BONUS := 120.0
const SLOWING_ARROW_SLOW_FRACTION := 0.35
const CONCEALMENT_REVEAL_DURATION := 1.25
const DISCHARGE_MARK_BONUS_WEIGHT := 0.45
const SHIELD_HALF_ANGLE := deg_to_rad(65.0)
const SHIELD_RADIUS := 34.0
const SHIELD_DURATION := 6.0
const SHIELD_FRONT_REDUCTION := 0.30
const PROVOKE_DEFENSE_REDUCTION := 0.25
const PROVOKE_FLEE_REDUCTION := 0.30
const PROVOKE_DEBUFF_DURATION := 4.0
const PERSEVERANCE_DURATION := 6.0
const PIERCING_SHOUT_DAMAGE_WEIGHT := 0.45
const PIERCING_SHOUT_SLOW_FRACTION := 0.30
const PIERCING_SHOUT_ASPD_FRACTION := 0.25
const FURY_DURATION := 6.0
const BRUTAL_STRIKE_DEFENSE_REDUCTION := 0.30
const BRUTAL_STRIKE_DEBUFF_DURATION := 4.0
const CONCENTRATED_RAGE_HALF_WIDTH := 19.0
const TERRIFYING_SHOUT_DAMAGE_RECEIVED_INCREASE := 0.20
const TERRIFYING_SHOUT_DEBUFF_DURATION := 3.0
const DEFENDER_COUNTER_GUARD_DURATION := 1.2
const DEFENDER_COUNTER_GUARD_REDUCTION := 0.15
const DEFENDER_ADVANCE_GUARD_REDUCTION := 0.20
const DEFENDER_TOKEN_DURATION := 8.0
const DEFENDER_TOKEN_NOTICE_DURATION := 1.5
const DEFENDER_WATCH_DURATION := 2.5
const DEFENDER_ANCHOR_DEFENSE_BONUS := 0.10
const DEFENDER_ANCHOR_SLOW_FRACTION := 0.20
const DEFENDER_PUSH_DISTANCE := 35.0
const BERSERKER_WOUND_DURATION := 8.0
const BERSERKER_WOUND_MAX_STACKS := 3
const BERSERKER_EXECUTION_HP_COST_FRACTION := 0.03
const BERSERKER_EXECUTION_LOW_TARGET_THRESHOLD := 0.35
const BERSERKER_EXECUTION_LOW_TARGET_BONUS := 0.20
const BERSERKER_RIFT_BLEED_DURATION := 4.0
const BERSERKER_BREATH_HEAL_CAP_FRACTION := 0.05
const ELEMENTALIST_FOCUS_WINDOW := 5.0
const ELEMENTALIST_RESONANCE_WINDOW := 6.0
const BERSERKER_DIRECT_MELEE_IDS := [
	&"basic_attack", &"cone_slash", &"brutal_strike", &"concentrated_rage",
	&"berserker_rupture", &"berserker_execution", &"berserker_wound_leap",
	&"berserker_blood_rift", &"berserker_breath_steal",
]

var navigation: ArenaNavigation
var run_state: RunState
var class_id: StringName = &"swordsman"
var class_definition: ClassDefinition
var _sp_deficit := 0.0
var current_sp: float:
	get:
		return maxf(0.0, max_sp - _sp_deficit)
	set(value):
		if is_finite(value):
			_sp_deficit = maxf(0.0, max_sp - clampf(value, 0.0, max_sp))
var max_sp := 0.0
var attack_cooldown := 0.0
var sentinel_state := SentinelFocusState.new()
var hunter_state := HunterOpeningState.new()
var hunter_presentation: HunterPresentation
var hunter_cover := HunterCoverState.new()
var _hunter_emission_serial := 0
var sentinel_combat_active := false
var _sentinel_last_position := Vector2.INF
var _sentinel_stance_active := false
var _sentinel_emission_serial := 0
var _sentinel_last_launch_frame := -1
var slash_cooldown := 0.0
var dash_cooldown := 0.0
var mage_cooldowns: Dictionary[StringName, float] = {}
var target: CombatActor
var velocity := Vector2.ZERO
var _path := PackedVector2Array()
var _path_index := 0
var _repath_time := 0.0
var _navigation_revision := 0
var _path_goal := Vector2.ZERO
var _has_path_goal := false
var _last_facing := Vector2.RIGHT
var _slash_visual_time := 0.0
var _slash_facing := Vector2.RIGHT
var _slash_origin := Vector2.ZERO
var _slash_visual_range := SLASH_RANGE
var _basic_visual_time := 0.0
var _basic_facing := Vector2.RIGHT
var _basic_origin := Vector2.ZERO
var _basic_visual_radius := 62.0
var _attack_engaged := false
var _attack_recovery := 0.0
var _dash_active := false
var _dash_endpoint := Vector2.ZERO
var _dash_speed := 0.0
var _defender_advance_targets: Array[CombatActor] = []
var _defender_advance_hit := false
var _berserker_leap_targets: Array[CombatActor] = []
var _berserker_leap_active := false
var _berserker_leap_hit := false
var active_cast_skill: StringName = &""
var active_cast_remaining := 0.0
var active_cast_total := 0.0
var extended_aim_remaining := 0.0
var concealment_reveal_remaining := 0.0
var _active_cast_point := Vector2.ZERO
var _active_cast_target_id: int = 0
var _active_geometer_command: GeometerCastCommand
var _active_cast_direction := Vector2.RIGHT
var _emission_context: CombatEventContext
var _rank_definitions: Dictionary[StringName, SkillRankDefinition] = {}
var _effect_rank_cache: Dictionary[StringName, SkillRankDefinition] = {}
var _effect_rank_revision := -1
var _foliage_shelters: Dictionary[int, Dictionary] = {}
var shield_remaining := 0.0
var shield_resistance := 0
var shield_facing := Vector2.RIGHT
var perseverance_remaining := 0.0
var piercing_shout_visual_time := 0.0
var fury_remaining := 0.0
var brutal_strike_visual_time := 0.0
var brutal_strike_visual_point := Vector2.ZERO
var concentrated_rage_visual_time := 0.0
var concentrated_rage_visual_origin := Vector2.ZERO
var concentrated_rage_visual_direction := Vector2.RIGHT
var concentrated_rage_visual_range := 0.0
var terrifying_shout_visual_time := 0.0
var defender_token_remaining := 0.0
var defender_token_notice := ""
var defender_token_notice_remaining := 0.0
var defender_counter_guard_remaining := 0.0
var defender_counter_guard_facing := Vector2.RIGHT
var defender_advance_guard_active := false
var defender_advance_guard_facing := Vector2.RIGHT
var defender_guard_return_cooldown := 0.0
var defender_anchor_remaining := 0.0
var defender_anchor_center := Vector2.INF
var _defender_inside_anchor := false
var berserker_wounds: Dictionary[int, Dictionary] = {}
var berserker_pursuit_cooldown := 0.0
var elementalist_focus_history: Dictionary[int, Dictionary] = {}
var elementalist_focus_cooldown := 0.0
var elementalist_resonance_history: Dictionary[int, Dictionary] = {}
var _elementalist_emission_serial := 0
var _elementalist_refunded_emissions: Dictionary[int, bool] = {}
var spiritualist_recovery_cooldown := 0.0
var _spiritualist_emission_serial := 0
var _spiritualist_refunded_emissions: Dictionary[int, bool] = {}
var spiritualist_focus_remaining := 0.0
var spiritualist_focus_power := 0.0

func configure(nav: ArenaNavigation, state: RunState) -> void:
	navigation = nav
	_navigation_revision = nav.revision
	run_state = state
	extended_aim_remaining = 0.0
	clear_foliage_shelters()
	class_id = run_state.class_id
	class_definition = ClassCatalog.class_definition(class_id)
	_capture_rank_definitions()
	fury_remaining = 0.0
	clear_defender_state()
	clear_berserker_state()
	clear_elementalist_state()
	clear_spiritualist_state()
	clear_sentinel_state()
	hunter_state.configure(get_instance_id())
	var derived := _build_stat_breakdown()
	var class_color := Color("8e73de") if class_id == &"mage" else Color("6fa85a") if class_id == &"archer" else Color("55a8d9")
	setup(class_definition.display_name, class_color, derived, 20.0)
	var animation_kind := class_id
	if _is_defender():
		animation_kind = &"defender"
	elif _is_berserker():
		animation_kind = &"berserker"
	elif _is_elementalist():
		animation_kind = &"elementalist"
	elif _is_spiritualist():
		animation_kind = &"spiritualist"
	elif is_geometer():
		animation_kind = &"geometer"
	elif is_sentinel():
		animation_kind = &"sentinel"
	elif is_hunter():
		animation_kind = &"hunter"
	set_animation_kind(animation_kind)
	if is_instance_valid(hunter_presentation):
		hunter_presentation.clear()
		hunter_presentation.free()
		hunter_presentation = null
	if is_hunter():
		hunter_presentation = HunterPresentation.new()
		hunter_presentation.name = "HunterPresentation"
		hunter_presentation.configure(self)
		add_child(hunter_presentation)
	max_sp = stat_breakdown.value(&"max_sp")
	current_sp = max_sp
	shield_remaining = 0.0
	shield_resistance = 0
	perseverance_remaining = 0.0
	for skill_id: StringName in available_skill_ids():
		mage_cooldowns[skill_id] = 0.0
	process_mode = Node.PROCESS_MODE_PAUSABLE

func is_mage() -> bool:
	return class_id == &"mage"

func is_archer() -> bool:
	return class_id == &"archer"

func is_sentinel() -> bool:
	return is_archer() and run_state != null and run_state.uses_persistent_build() and run_state.build_snapshot.evolution_id == &"sentinel"

func is_hunter() -> bool:
	return is_archer() and run_state != null and run_state.uses_persistent_build() and run_state.build_snapshot.evolution_id == &"hunter"

func hunter_opening_snapshot(trap_id: StringName) -> DamageRequest:
	if not is_hunter():
		return null
	var request := HunterMath.opening_request(get_instance_id(), trap_id, skill_rank(trap_id), stat_breakdown, outgoing_damage_multiplier())
	if request != null and _emission_context != null:
		request.inherit_root(_emission_context)
	return request

func activate_hunter_opening(activation_id: int, victim: CombatActor, snapshot: DamageRequest) -> bool:
	if not is_hunter() or not is_alive() or victim == null or not is_instance_valid(victim) or not victim.is_alive() or (is_inside_tree() and get_tree().paused):
		return false
	return hunter_state.activate(activation_id, victim.get_instance_id(), snapshot)

func record_hunter_damage(result: Dictionary) -> void:
	if not is_hunter() or not is_alive() or (is_inside_tree() and get_tree().paused):
		return
	var victim := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if not is_instance_valid(victim) or (not victim.is_alive() and not bool(result.get("killed", false))):
		return
	# Called from damage_applied before an arrow applies its own control. Boss
	# openings qualify even when the shared hard-control budget resists the trap.
	var controlled_or_boss := victim.hard_controls.boss or victim.is_rooted() or victim.is_stunned() or victim.is_feared() or victim.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) > 0.0
	var payload := hunter_state.consume(result, controlled_or_boss)
	if payload.is_empty():
		return
	if bool(payload["granted_step"]):
		_apply_derived_stats(_build_stat_breakdown())
		resources_changed.emit()
	if is_instance_valid(hunter_presentation) and is_instance_valid(victim):
		hunter_presentation.notify_consumed(victim.global_position)
	# Lethal direct arrows still claim the opening/step, but never damage a corpse.
	if is_instance_valid(victim) and victim.is_alive():
		status_damage_requested.emit(payload["request"], victim)
	queue_redraw()

func clear_hunter_state() -> void:
	var had_step := hunter_state.step_remaining > 0.0
	hunter_state.clear()
	if is_instance_valid(hunter_presentation):
		hunter_presentation.clear()
	if is_hunter():
		clear_foliage_shelters()
	if had_step and health != null and run_state != null:
		_apply_derived_stats(_build_stat_breakdown())
	queue_redraw()

func sentinel_free_sp() -> float:
	return maxf(0.0, current_sp - sentinel_state.reserved_sp) if is_sentinel() else current_sp

func clear_sentinel_state() -> void:
	sentinel_state.clear()
	_sentinel_stance_active = false
	_sentinel_last_position = global_position
	if health != null and run_state != null:
		_apply_derived_stats(_build_stat_breakdown())

func use_sentinel_observe(enemy: CombatActor) -> bool:
	if not sentinel_can_use(&"sentinel_observe") or not can_target_skill(&"sentinel_observe", enemy) or not navigation.is_segment_clear(global_position, enemy.global_position, 0.0):
		return false
	_spend(&"sentinel_observe")
	sentinel_state.observe(enemy.get_instance_id(), skill_rank(&"sentinel_observe"))
	presentation_action.emit(&"cast_release", _resolved_facing(aim_direction(enemy.global_position)), 0.15)
	resources_changed.emit()
	return true

func use_sentinel_reset(skill_id: StringName, point: Vector2, enemy: CombatActor = null) -> bool:
	if skill_id not in [&"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_concussion_shot"] or not point.is_finite() or not sentinel_can_use(skill_id):
		return false
	if navigation == null:
		return false
	var piercing := skill_id == &"sentinel_piercing_shot"
	if not piercing and (not can_target_skill(skill_id, enemy) or not navigation.is_segment_clear(global_position, enemy.global_position, 0.0)):
		return false
	if piercing and (point.distance_squared_to(global_position) < 0.001 or not navigation.is_walkable(global_position)):
		return false
	var facing := _resolved_facing(aim_direction(point if piercing else enemy.global_position))
	var definition := ClassCatalog.skill_definition(skill_id)
	var tuning := SentinelTuning.values(skill_id, skill_rank(skill_id))
	var power := SentinelMath.raw_power(skill_id, skill_rank(skill_id), stat_breakdown)
	var request := _make_magic_request(null, skill_id, power, definition.accuracy_mode, definition.can_crit) if piercing else _make_physical_request(enemy, skill_id, power, definition.accuracy_mode, definition.can_crit)
	# Validation complete: one special launch replaces the next ordinary shot.
	cancel_active_cast()
	_spend(skill_id)
	request.context = _emission_context.copy_context()
	request.emission_id = int(_emission_context.root_event_id.get_slice(":", _emission_context.root_event_id.get_slice_count(":") - 1))
	sentinel_state.spend(float(tuning["focus_cost"]))
	_start_sentinel_recovery(facing)
	var payload := tuning.duplicate(true)
	payload["range"] = skill_range(skill_id)
	sentinel_projectile_requested.emit(request, enemy, facing, payload)
	resources_changed.emit()
	return true

func _start_sentinel_recovery(facing: Vector2) -> void:
	attack_cooldown = 1.0 / attacks_per_second()
	_attack_recovery = BASIC_ATTACK_RECOVERY
	_sentinel_last_launch_frame = Engine.get_process_frames()
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	reveal_from_offense()
	presentation_action.emit(&"basic_attack", facing, BASIC_ATTACK_RECOVERY)

func sentinel_can_use(skill_id: StringName) -> bool:
	return is_sentinel() and not is_stunned() and not is_feared() and not (is_inside_tree() and get_tree().paused) and _can_spend(skill_id) and sentinel_state.can_pay(float(SentinelTuning.values(skill_id, skill_rank(skill_id)).get("focus_cost", 0.0)))

func use_sentinel_absolute_focus() -> bool:
	var id := &"sentinel_absolute_focus"
	if not sentinel_can_use(id):
		return false
	_spend(id)
	sentinel_state.absolute_remaining = float(SentinelTuning.values(id, skill_rank(id))["duration"])
	presentation_action.emit(&"cast_release", _last_facing, 0.15)
	resources_changed.emit()
	return true

func sentinel_range_multiplier() -> float:
	if not is_sentinel() or sentinel_state.absolute_remaining <= 0.0:
		return 1.0
	return 1.0 + float(SentinelTuning.values(&"sentinel_absolute_focus", skill_rank(&"sentinel_absolute_focus")).get("range_bonus", 0.0))

func cancel_sentinel_preparation() -> bool:
	if not sentinel_state.explosive_prepared:
		return false
	sentinel_state.cancel_preparation()
	resources_changed.emit()
	queue_redraw()
	return true

func prepare_sentinel_explosive() -> bool:
	if not is_sentinel() or not is_alive() or (is_inside_tree() and get_tree().paused):
		return false
	if sentinel_state.explosive_prepared:
		return cancel_sentinel_preparation()
	var id := &"sentinel_explosive_shot"
	if not sentinel_can_use(id):
		return false
	var tuning := SentinelTuning.values(id, skill_rank(id))
	# Reservation is not payment; no cooldown or recovery is touched here.
	sentinel_state.reserved_sp = skill_cost(id)
	sentinel_state.reserved_focus = float(tuning["focus_cost"])
	sentinel_state.explosive_prepared = true
	resources_changed.emit()
	queue_redraw()
	return true

func _launch_sentinel_explosive(enemy: CombatActor) -> bool:
	var id := &"sentinel_explosive_shot"
	if not sentinel_state.explosive_prepared or not is_sentinel() or not is_alive() or is_stunned() or is_feared() or (is_inside_tree() and get_tree().paused):
		return false
	if id not in available_skill_ids() or skill_cooldown(id) > 0.0 or not can_basic_attack(enemy, _attack_engaged):
		return false
	if current_sp < sentinel_state.reserved_sp or sentinel_state.focus < sentinel_state.reserved_focus:
		return false
	var tuning := SentinelTuning.values(id, skill_rank(id))
	if tuning.is_empty():
		return false
	var reserved_focus := sentinel_state.reserved_focus
	var request := _make_magic_request(enemy, id, SentinelMath.raw_power(id, skill_rank(id), stat_breakdown), DamageRequest.AccuracyMode.GEOMETRY, true)
	var facing := _resolved_facing(aim_direction(enemy.global_position))
	# All launch checks passed. Release then consume the reservation exactly once.
	sentinel_state.cancel_preparation()
	_spend(id)
	request.context = _emission_context.copy_context()
	request.emission_id = int(_emission_context.root_event_id.get_slice(":", _emission_context.root_event_id.get_slice_count(":") - 1))
	sentinel_state.spend(reserved_focus)
	_start_sentinel_recovery(facing)
	var payload := tuning.duplicate(true)
	payload["range"] = archer_basic_projectile_range()
	sentinel_projectile_requested.emit(request, enemy, facing, payload)
	resources_changed.emit()
	return true

func sentinel_net_center(point: Vector2) -> Vector2:
	return global_position + (point - global_position).limit_length(skill_range(&"sentinel_net_shot"))

func can_place_sentinel_net(point: Vector2) -> bool:
	return point.is_finite() and navigation != null and navigation.is_walkable(sentinel_net_center(point))

func use_sentinel_net(point: Vector2) -> bool:
	var id := &"sentinel_net_shot"
	if not sentinel_can_use(id) or not can_place_sentinel_net(point):
		return false
	var center := sentinel_net_center(point)
	var tuning := SentinelTuning.values(id, skill_rank(id))
	var request := _make_magic_request(null, id, SentinelMath.raw_power(id, skill_rank(id), stat_breakdown), DamageRequest.AccuracyMode.GEOMETRY, true)
	var facing := _resolved_facing(aim_direction(center))
	_spend(id)
	request.context = _emission_context.copy_context()
	request.emission_id = int(_emission_context.root_event_id.get_slice(":", _emission_context.root_event_id.get_slice_count(":") - 1))
	var payload := tuning.duplicate(true)
	payload["endpoint"] = center
	payload["range"] = global_position.distance_to(center)
	sentinel_projectile_requested.emit(request, null, facing, payload)
	presentation_action.emit(&"cast_release", facing, 0.15)
	resources_changed.emit()
	return true

func record_sentinel_damage(result: Dictionary) -> void:
	if not is_sentinel() or not is_alive() or (is_inside_tree() and get_tree().paused) or int(result.get("source_id", 0)) != get_instance_id() or not bool(result.get("can_trigger_effects", false)) or float(result.get("actual_damage", 0.0)) <= 0.0:
		return
	var victim := instance_from_id(int(result.get("target_id", 0))) as CombatActor
	if not is_instance_valid(victim) or (not victim.is_alive() and not bool(result.get("killed", false))):
		return
	if not claim_effect_result(result, &"sentinel_focus", victim.get_instance_id()):
		return
	var rank := skill_rank(&"sentinel_opening_read") if run_state.build_snapshot.has_passive(&"sentinel_opening_read") else 0
	var gained := sentinel_state.direct_impact(int(result.get("emission_id", 0)), victim.get_instance_id(), true, bool(result.get("critical", false)), victim.is_rooted() or victim.is_stunned(), rank)
	gained += sentinel_state.intrinsic_direct_impact(int(result.get("emission_id", 0)), sentinel_combat_active)
	if gained > 0.0:
		resources_changed.emit()

func _set_sentinel_stance(active: bool) -> void:
	if active == _sentinel_stance_active:
		return
	_sentinel_stance_active = active
	_apply_derived_stats(_build_stat_breakdown())
	resources_changed.emit()

func available_skill_ids() -> Array[StringName]:
	if run_state != null and run_state.uses_persistent_build():
		var learned: Array[StringName] = []
		for id: StringName in run_state.build_snapshot.learned_skill_ids(ProfileCatalog.ACTIVE):
			# Domain catalogs may include fixture/future metadata without runtime skills.
			if ClassCatalog.skill_definition(id) != null:
				learned.append(id)
		return learned
	return class_definition.skill_ids.duplicate()

func apply_run_modifiers(state: RunState) -> void:
	run_state = state
	var derived := _build_stat_breakdown()
	_apply_derived_stats(derived)
	resources_changed.emit()
	queue_redraw()

func _apply_derived_stats(derived: StatBreakdown) -> void:
	assert(derived != null)
	stat_breakdown = derived
	health.set_stats_preserving_missing(stat_breakdown)
	max_sp = maxf(0.0, stat_breakdown.value(&"max_sp"))

func move_to(point: Vector2) -> void:
	cancel_active_cast()
	target = null
	_attack_engaged = false
	_attack_recovery = 0.0
	_path_goal = point
	_has_path_goal = true
	_set_path(point)

func pursue(enemy: CombatActor) -> void:
	cancel_active_cast()
	if enemy != null and is_instance_valid(enemy) and enemy.is_alive():
		_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	target = enemy
	_attack_engaged = false
	_has_path_goal = false
	_path.clear()
	_repath_time = 0.0

func use_slash(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"slash")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"slash"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"slash").action_kind)
	var facing := _resolved_facing(direction)
	_spend(&"slash")
	reveal_from_offense()
	_slash_visual_time = 0.20
	_slash_facing = facing
	_slash_origin = global_position
	_slash_visual_range = rank_definition.range
	presentation_action.emit(&"slash", facing, 0.20)
	queue_redraw()
	for enemy: CombatActor in enemies.duplicate():
		if not enemy.is_alive():
			continue
		var offset := enemy.global_position - global_position
		if SkillGeometry.cone_contains(offset, facing, rank_definition.range, SLASH_HALF_ANGLE):
			var definition := ClassCatalog.skill_definition(&"slash")
			attack_requested.emit(_make_physical_request(enemy, &"cone_slash", stat_breakdown.value(&"melee_attack") * rank_definition.power, definition.accuracy_mode, definition.can_crit), enemy)
	resources_changed.emit()
	return true

func use_defender_counterstroke(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"defender_counterstroke")
	if not _defender_active_equipped(&"defender_counterstroke") or rank_definition == null or not _can_spend(&"defender_counterstroke"):
		return false
	var facing := _resolved_facing(direction)
	var empowered := has_defender_token()
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"defender_counterstroke")
	if empowered:
		_consume_defender_token()
	defender_counter_guard_remaining = DEFENDER_COUNTER_GUARD_DURATION
	defender_counter_guard_facing = facing
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"defender_counterstroke")
	var weight := rank_definition.power + (rank_definition.secondary_power if empowered else 0.0)
	for enemy: CombatActor in enemies.duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var offset := enemy.global_position - global_position
		if not SkillGeometry.cone_contains(offset, facing, SkillGeometry.DEFENDER_COUNTERSTROKE_RANGE, SkillGeometry.DEFENDER_COUNTERSTROKE_HALF_ANGLE):
			continue
		if not navigation.is_segment_clear(global_position, enemy.global_position, 0.0):
			continue
		attack_requested.emit(_make_physical_request(enemy, &"defender_counterstroke", stat_breakdown.value(&"melee_attack") * weight, definition.accuracy_mode, definition.can_crit), enemy)
	presentation_action.emit(&"slash", facing, 0.20)
	resources_changed.emit()
	queue_redraw()
	return true

func use_berserker_rupture(enemy: CombatActor) -> bool:
	var rank_definition := _runtime_rank_definition(&"berserker_rupture")
	if not _is_berserker() or rank_definition == null or not can_target_skill(&"berserker_rupture", enemy) or not _can_spend(&"berserker_rupture"):
		return false
	var facing := _resolved_facing(global_position.direction_to(enemy.global_position))
	var stacks := berserker_wound_stacks(enemy.get_instance_id())
	var detonate := stacks > 0
	var power := stat_breakdown.value(&"melee_attack") * (rank_definition.secondary_power * stacks if detonate else rank_definition.power)
	var definition := ClassCatalog.skill_definition(&"berserker_rupture")
	_commit_action(definition.action_kind)
	_spend(&"berserker_rupture")
	reveal_from_offense()
	var request := _make_physical_request(enemy, &"berserker_rupture_detonation" if detonate else &"berserker_rupture", power, definition.accuracy_mode, definition.can_crit and not detonate)
	request.is_secondary = detonate
	request.intrinsic_contested = detonate
	attack_requested.emit(request, enemy)
	presentation_action.emit(&"slash", facing, 0.20)
	resources_changed.emit()
	return true

func use_berserker_execution(enemy: CombatActor) -> bool:
	var rank_definition := _runtime_rank_definition(&"berserker_execution")
	if not _is_berserker() or rank_definition == null or not can_target_skill(&"berserker_execution", enemy) or not _can_spend(&"berserker_execution"):
		return false
	var hp_cost := berserker_execution_hp_cost()
	if not can_pay_berserker_execution_hp():
		return false
	var stacks := berserker_wound_stacks(enemy.get_instance_id())
	var target_low := enemy.health.current_hp <= enemy.health.max_hp * BERSERKER_EXECUTION_LOW_TARGET_THRESHOLD
	var weight := rank_definition.power + rank_definition.secondary_power * stacks
	if target_low:
		weight *= 1.0 + BERSERKER_EXECUTION_LOW_TARGET_BONUS
	var facing := _resolved_facing(global_position.direction_to(enemy.global_position))
	if not health.spend_hp_nonlethal(hp_cost):
		return false
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"berserker_execution")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"berserker_execution")
	var request := _make_physical_request(enemy, &"berserker_execution", stat_breakdown.value(&"melee_attack") * weight, definition.accuracy_mode, definition.can_crit)
	attack_requested.emit(request, enemy)
	presentation_action.emit(&"slash", facing, 0.20)
	resources_changed.emit()
	return true

func berserker_execution_hp_cost() -> float:
	return maxf(1.0, ceilf(health.max_hp * BERSERKER_EXECUTION_HP_COST_FRACTION)) if health != null else INF

func can_pay_berserker_execution_hp() -> bool:
	return health != null and health.current_hp > berserker_execution_hp_cost()

func use_berserker_breath_steal(enemy: CombatActor) -> bool:
	var rank_definition := _runtime_rank_definition(&"berserker_breath_steal")
	if not _is_berserker() or rank_definition == null or not can_target_skill(&"berserker_breath_steal", enemy) or not _can_spend(&"berserker_breath_steal"):
		return false
	var marked_before_hit := berserker_wound_stacks(enemy.get_instance_id()) > 0
	var facing := _resolved_facing(global_position.direction_to(enemy.global_position))
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"berserker_breath_steal")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"berserker_breath_steal")
	var request := _make_physical_request(enemy, &"berserker_breath_steal", stat_breakdown.value(&"melee_attack") * rank_definition.power, definition.accuracy_mode, definition.can_crit)
	berserker_breath_hit_requested.emit(request, enemy, rank_definition.secondary_power, marked_before_hit)
	presentation_action.emit(&"slash", facing, 0.20)
	resources_changed.emit()
	return true

func heal_from_berserker_breath_steal(result: Dictionary, heal_fraction: float) -> float:
	if not _is_berserker() or not is_alive() or int(result.get("source_id", 0)) != get_instance_id() or StringName(result.get("skill_id", &"")) != &"berserker_breath_steal" or not bool(result.get("can_trigger_effects", false)) or bool(result.get("killed", false)) or heal_fraction <= 0.0:
		return 0.0
	if not claim_effect_result(result, &"berserker_breath_heal", int(result.get("target_id", 0))):
		return 0.0
	var amount := minf(float(result.get("actual_damage", 0.0)) * heal_fraction, health.max_hp * BERSERKER_BREATH_HEAL_CAP_FRACTION)
	var healed := minf(maxf(0.0, amount), health.max_hp - health.current_hp)
	if healed > 0.0:
		health.heal(healed)
		resources_changed.emit()
		queue_redraw()
	return healed

func berserker_wound_leap_destination(direction: Vector2) -> Vector2:
	if navigation == null or is_rooted():
		return global_position
	var facing := direction.normalized()
	if facing.is_zero_approx():
		facing = _last_facing
	return navigation.move_until_blocked(global_position, global_position + facing * skill_range(&"berserker_wound_leap"))

func use_berserker_wound_leap(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"berserker_wound_leap")
	if not _is_berserker() or rank_definition == null or not _can_spend(&"berserker_wound_leap") or is_rooted():
		return false
	var facing := _resolved_facing(direction)
	var endpoint := berserker_wound_leap_destination(facing)
	var distance := global_position.distance_to(endpoint)
	if distance <= MOVEMENT_EPSILON:
		return false
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"berserker_wound_leap")
	reveal_from_offense()
	_stop_dash()
	_dash_endpoint = endpoint
	_dash_speed = distance / DASH_DURATION
	_dash_active = true
	_berserker_leap_active = true
	_berserker_leap_targets = enemies.duplicate()
	_berserker_leap_hit = false
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	_attack_recovery = 0.0
	_repath_time = 0.0
	presentation_action.emit(&"dash", facing, DASH_DURATION)
	resources_changed.emit()
	return true

func use_berserker_blood_rift(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"berserker_blood_rift")
	if not _is_berserker() or rank_definition == null or not _can_spend(&"berserker_blood_rift") or navigation == null:
		return false
	var facing := _resolved_facing(direction)
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"berserker_blood_rift")
	reveal_from_offense()
	target = null
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	var definition := ClassCatalog.skill_definition(&"berserker_blood_rift")
	var melee_attack := stat_breakdown.value(&"melee_attack")
	for enemy: CombatActor in enemies.duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if not SkillGeometry.strip_contains(enemy.global_position - global_position, facing, SkillGeometry.BERSERKER_RIFT_LENGTH, SkillGeometry.BERSERKER_RIFT_HALF_WIDTH, enemy.collision_radius):
			continue
		if not navigation.is_segment_clear(global_position, enemy.global_position, 0.0):
			continue
		var direct := _make_physical_request(enemy, &"berserker_blood_rift", melee_attack * rank_definition.power, definition.accuracy_mode, definition.can_crit)
		var bleed := _make_physical_request(enemy, &"berserker_blood_rift_tick", melee_attack * rank_definition.secondary_power, DamageRequest.AccuracyMode.GEOMETRY, false)
		bleed.is_secondary = true
		berserker_rift_hit_requested.emit(direct, enemy, bleed)
	presentation_action.emit(&"slash", facing, 0.25)
	resources_changed.emit()
	return true

func berserker_wound_stacks(target_id: int) -> int:
	if not _is_berserker() or not berserker_wounds.has(target_id):
		return 0
	var wound: Dictionary = berserker_wounds[target_id]
	return int(wound.get("stacks", 0)) if float(wound.get("remaining", 0.0)) > 0.0 else 0

func berserker_wound_remaining(target_id: int) -> float:
	if berserker_wound_stacks(target_id) <= 0:
		return 0.0
	var wound: Dictionary = berserker_wounds[target_id]
	return float(wound.get("remaining", 0.0))

func record_berserker_damage(result: Dictionary) -> void:
	if not _is_berserker() or not is_alive() or int(result.get("source_id", 0)) != get_instance_id():
		return
	var target_id := int(result.get("target_id", 0))
	if target_id <= 0:
		return
	var skill_id := StringName(result.get("skill_id", &""))
	if skill_id == &"berserker_rupture_detonation":
		if float(result.get("actual_damage", 0.0)) > 0.0:
			berserker_wounds.erase(target_id)
		return
	if skill_id == &"berserker_execution":
		if bool(result.get("can_trigger_effects", false)) and float(result.get("actual_damage", 0.0)) > 0.0:
			_trigger_berserker_pursuit(target_id, result)
			berserker_wounds.erase(target_id)
		return
	if not bool(result.get("can_trigger_effects", false)) or float(result.get("actual_damage", 0.0)) <= 0.0 or skill_id not in BERSERKER_DIRECT_MELEE_IDS or skill_rank(&"berserker_rupture") <= 0:
		return
	var previous := berserker_wound_stacks(target_id)
	if previous == 0 and skill_id != &"berserker_rupture":
		return
	if previous > 0:
		_trigger_berserker_pursuit(target_id, result)
	if not claim_effect_result(result, &"berserker_wound", target_id):
		return
	berserker_wounds[target_id] = {"stacks": mini(BERSERKER_WOUND_MAX_STACKS, previous + 1), "remaining": BERSERKER_WOUND_DURATION}

func _trigger_berserker_pursuit(target_id: int, result: Dictionary) -> void:
	if berserker_wound_stacks(target_id) <= 0 or berserker_pursuit_cooldown > 0.0 or not run_state.build_snapshot.has_passive(&"berserker_pursuit"):
		return
	var rank_definition := _runtime_rank_definition(&"berserker_pursuit")
	if rank_definition == null:
		return
	if not claim_effect_result(result, &"berserker_pursuit", get_instance_id()):
		return
	recover_sp(rank_definition.power)
	berserker_pursuit_cooldown = 1.0
	resources_changed.emit()

func remove_berserker_wound(target_id: int) -> void:
	berserker_wounds.erase(target_id)

func clear_berserker_state() -> void:
	berserker_wounds.clear()
	berserker_pursuit_cooldown = 0.0
	if _berserker_leap_active:
		_stop_dash()

func record_elementalist_damage(result: Dictionary) -> void:
	if not _is_elementalist() or not is_alive() or not bool(result.get("can_trigger_effects", false)) or float(result.get("actual_damage", 0.0)) <= 0.0 or int(result.get("source_id", 0)) != get_instance_id():
		return
	var target_id := int(result.get("target_id", 0))
	var element := _elementalist_direct_element(StringName(result.get("skill_id", &"")))
	if target_id <= 0 or element == &"":
		return
	var previous: Dictionary = elementalist_focus_history.get(target_id, {})
	var alternating := float(previous.get("remaining", 0.0)) > 0.0 and StringName(previous.get("element", &"")) != element
	var emission_id := int(result.get("emission_id", 0))
	var emission_available := emission_id <= 0 or not _elementalist_refunded_emissions.has(emission_id)
	if alternating and emission_available and elementalist_focus_cooldown <= 0.0 and run_state.build_snapshot.has_passive(&"elementalist_prismatic_focus"):
		var rank_definition := _runtime_rank_definition(&"elementalist_prismatic_focus")
		if rank_definition != null and claim_effect_result(result, &"elementalist_focus", get_instance_id()):
			var previous_sp := current_sp
			recover_sp(rank_definition.power)
			elementalist_focus_cooldown = 1.0
			if emission_id > 0:
				_elementalist_refunded_emissions[emission_id] = true
			if current_sp > previous_sp:
				resources_changed.emit()
	elementalist_focus_history[target_id] = {"element": element, "remaining": ELEMENTALIST_FOCUS_WINDOW}
	var resonance: Dictionary = elementalist_resonance_history.get(target_id, {})
	var elements: Array = resonance.get("elements", [])
	if elements.size() == 2 and not elements.has(element):
		elementalist_resonance_history.erase(target_id)
	elif not elements.has(element):
		elements.append(element)
		elementalist_resonance_history[target_id] = {"elements": elements, "remaining": float(resonance.get("remaining", ELEMENTALIST_RESONANCE_WINDOW))}

func elementalist_resonance_ready(target_id: int, skill_id: StringName) -> bool:
	if not _is_elementalist() or not is_alive() or not run_state.build_snapshot.has_passive(&"elementalist_prismatic_resonance") or _runtime_rank_definition(&"elementalist_prismatic_resonance") == null:
		return false
	var element := _elementalist_direct_element(skill_id)
	var history: Dictionary = elementalist_resonance_history.get(target_id, {})
	var elements: Array = history.get("elements", [])
	return element != &"" and float(history.get("remaining", 0.0)) > 0.0 and elements.size() == 2 and not elements.has(element)

func remove_elementalist_target(target_id: int) -> void:
	elementalist_focus_history.erase(target_id)
	elementalist_resonance_history.erase(target_id)

func clear_elementalist_state() -> void:
	elementalist_focus_history.clear()
	elementalist_focus_cooldown = 0.0
	elementalist_resonance_history.clear()
	_elementalist_refunded_emissions.clear()

func _elementalist_direct_element(skill_id: StringName) -> StringName:
	if skill_id in [&"fireball", &"fire_spear", &"elementalist_flame_burst", &"elementalist_ember_path", &"elementalist_tri_nova"]:
		return &"fire"
	if skill_id in [&"ice_spear", &"elementalist_glacial_ring"]:
		return &"ice"
	if skill_id in [&"lightning", &"electric_discharge", &"elementalist_lightning_arc"]:
		return &"lightning"
	return &""

func defender_wall_advance_destination(direction: Vector2) -> Vector2:
	if navigation == null or is_rooted():
		return global_position
	var facing := direction.normalized()
	if facing.is_zero_approx():
		facing = _last_facing
	return navigation.move_until_blocked(global_position, global_position + facing * skill_range(&"defender_wall_advance"))

func use_defender_anchor(point: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"defender_anchor")
	if not _defender_active_equipped(&"defender_anchor") or rank_definition == null or not _can_spend(&"defender_anchor") or navigation == null:
		return false
	var center := global_position + (point - global_position).limit_length(rank_definition.range)
	if not center.is_finite() or not navigation.is_walkable(center):
		return false
	_spend(&"defender_anchor")
	defender_anchor_center = center
	defender_anchor_remaining = rank_definition.power
	_update_defender_anchor_presence()
	resources_changed.emit()
	return true

func use_defender_line_lock(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"defender_line_lock")
	if not _defender_active_equipped(&"defender_line_lock") or rank_definition == null or not _can_spend(&"defender_line_lock"):
		return false
	var facing := _resolved_facing(direction)
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"defender_line_lock")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"defender_line_lock")
	for enemy: CombatActor in enemies.duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if not SkillGeometry.strip_contains(enemy.global_position - global_position, facing, SkillGeometry.DEFENDER_LINE_LOCK_LENGTH, SkillGeometry.DEFENDER_LINE_LOCK_HALF_WIDTH, enemy.collision_radius):
			continue
		if not navigation.is_segment_clear(global_position, enemy.global_position, 0.0):
			continue
		var request := _make_physical_request(enemy, &"defender_line_lock", stat_breakdown.value(&"melee_attack") * rank_definition.power, definition.accuracy_mode, definition.can_crit)
		defender_hit_requested.emit(request, enemy, rank_definition.secondary_power, Vector2.ZERO)
	presentation_action.emit(&"slash", facing, 0.20)
	resources_changed.emit()
	return true

func use_defender_wall_advance(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"defender_wall_advance")
	if not _defender_active_equipped(&"defender_wall_advance") or rank_definition == null or not _can_spend(&"defender_wall_advance") or is_rooted():
		return false
	var facing := _resolved_facing(direction)
	var endpoint := defender_wall_advance_destination(facing)
	var distance := global_position.distance_to(endpoint)
	if distance <= MOVEMENT_EPSILON:
		return false
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"defender_wall_advance")
	reveal_from_offense()
	_stop_dash()
	_dash_endpoint = endpoint
	_dash_speed = distance / DASH_DURATION
	_dash_active = true
	defender_advance_guard_active = true
	defender_advance_guard_facing = facing
	_defender_advance_targets = enemies.duplicate()
	_defender_advance_hit = false
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	_attack_recovery = 0.0
	_repath_time = 0.0
	presentation_action.emit(&"dash", facing, DASH_DURATION)
	resources_changed.emit()
	return true

func use_defender_reprisal_wave(enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"defender_reprisal_wave")
	if not _defender_active_equipped(&"defender_reprisal_wave") or rank_definition == null or not _can_spend(&"defender_reprisal_wave"):
		return false
	var center := defender_anchor_center if has_defender_anchor() else global_position
	var empowered := has_defender_token()
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(&"defender_reprisal_wave")
	if empowered:
		_consume_defender_token()
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"defender_reprisal_wave")
	var weight := rank_definition.power + (rank_definition.secondary_power if empowered else 0.0)
	for enemy: CombatActor in enemies.duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive() or center.distance_to(enemy.global_position) > SkillGeometry.DEFENDER_REPRISAL_WAVE_RADIUS + enemy.collision_radius:
			continue
		if not navigation.is_segment_clear(center, enemy.global_position, 0.0):
			continue
		var request := _make_physical_request(enemy, &"defender_reprisal_wave", stat_breakdown.value(&"melee_attack") * weight, definition.accuracy_mode, definition.can_crit)
		var push := (enemy.global_position - center).normalized() if empowered else Vector2.ZERO
		defender_hit_requested.emit(request, enemy, 0.0, push)
	resources_changed.emit()
	return true

func use_dash(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"dash")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"dash") or is_rooted():
		return false
	_commit_action(ClassCatalog.skill_definition(&"dash").action_kind)
	var facing := _resolved_facing(direction)
	_spend(&"dash")
	_stop_dash()
	_dash_endpoint = dash_destination(facing)
	_dash_speed = global_position.distance_to(_dash_endpoint) / DASH_DURATION
	_dash_active = global_position.distance_to(_dash_endpoint) > MOVEMENT_EPSILON
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	_attack_recovery = 0.0
	_repath_time = 0.0
	presentation_action.emit(&"dash", facing, DASH_DURATION)
	resources_changed.emit()
	return true

func use_fireball(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"fireball")
	if class_id != &"mage" or rank_definition == null or not _can_spend(&"fireball"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"fireball")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"fireball")
	var request := _make_magic_request(null, &"fireball", _magic_power(&"fireball"), definition.accuracy_mode, definition.can_crit)
	mage_projectile_requested.emit(&"fireball", request, null, facing, 1)
	resources_changed.emit()
	return true

func use_fire_wall(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"fire_wall")
	if class_id != &"mage" or rank_definition == null or not _can_spend(&"fire_wall"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"fire_wall")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"fire_wall")
	var request := _make_magic_request(null, &"fire_wall", _magic_power(&"fire_wall"), definition.accuracy_mode, definition.can_crit)
	fire_wall_requested.emit(facing, request)
	resources_changed.emit()
	return true

func elementalist_flame_burst_center(point: Vector2) -> Vector2:
	return global_position + (point - global_position).limit_length(skill_range(&"elementalist_flame_burst"))

func can_place_elementalist_flame_burst(point: Vector2) -> bool:
	if navigation == null or skill_range(&"elementalist_flame_burst") <= 0.0:
		return false
	var center := elementalist_flame_burst_center(point)
	return navigation.is_walkable(center) and navigation.is_segment_clear(global_position, center, 0.0)

func use_elementalist_flame_burst(point: Vector2) -> bool:
	if not _is_elementalist() or _runtime_rank_definition(&"elementalist_flame_burst") == null or not _can_spend(&"elementalist_flame_burst") or not can_place_elementalist_flame_burst(point):
		return false
	var center := elementalist_flame_burst_center(point)
	_spend(&"elementalist_flame_burst")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"elementalist_flame_burst")
	var request := _make_magic_request(null, &"elementalist_flame_burst", _magic_power(&"elementalist_flame_burst"), definition.accuracy_mode, definition.can_crit)
	elementalist_flame_burst_requested.emit(center, request)
	resources_changed.emit()
	return true

func use_elementalist_glacial_ring() -> bool:
	if not _is_elementalist() or not _can_spend(&"elementalist_glacial_ring"):
		return false
	_spend(&"elementalist_glacial_ring")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"elementalist_glacial_ring")
	var request := _make_magic_request(null, &"elementalist_glacial_ring", _magic_power(&"elementalist_glacial_ring"), definition.accuracy_mode, definition.can_crit)
	elementalist_area_requested.emit(&"elementalist_glacial_ring", global_position, SkillGeometry.ELEMENTALIST_GLACIAL_RING_RADIUS, request, &"ice")
	resources_changed.emit()
	return true

func use_elementalist_lightning_arc(enemy: CombatActor) -> bool:
	if not _is_elementalist() or not _can_spend(&"elementalist_lightning_arc") or not can_target_skill(&"elementalist_lightning_arc", enemy):
		return false
	_spend(&"elementalist_lightning_arc")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"elementalist_lightning_arc")
	var rank_definition := _runtime_rank_definition(&"elementalist_lightning_arc")
	var magic_attack := stat_breakdown.value(&"magic_attack")
	var request := _make_magic_request(enemy, &"elementalist_lightning_arc", magic_attack * rank_definition.power, definition.accuracy_mode, definition.can_crit)
	elementalist_lightning_arc_requested.emit(request, enemy, magic_attack * 0.60, magic_attack * rank_definition.secondary_power)
	resources_changed.emit()
	return true

func elementalist_ember_centers(direction: Vector2) -> Array[Vector2]:
	var centers: Array[Vector2] = []
	if navigation == null or not direction.is_finite():
		return centers
	var facing := direction.normalized() if not direction.is_zero_approx() else _last_facing
	for index: int in range(1, 4):
		var center := global_position + facing * SkillGeometry.ELEMENTALIST_EMBER_PATH_STEP * float(index)
		if not navigation.is_walkable(center) or not navigation.is_segment_clear(global_position, center, 0.0):
			break
		centers.append(center)
	return centers

func use_elementalist_ember_path(direction: Vector2) -> bool:
	if not _is_elementalist() or not _can_spend(&"elementalist_ember_path"):
		return false
	var centers := elementalist_ember_centers(direction)
	if centers.is_empty():
		return false
	_spend(&"elementalist_ember_path")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"elementalist_ember_path")
	var request := _make_magic_request(null, &"elementalist_ember_path", _magic_power(&"elementalist_ember_path"), definition.accuracy_mode, definition.can_crit)
	elementalist_ember_path_requested.emit(centers, request)
	resources_changed.emit()
	return true

func use_elementalist_tri_nova() -> bool:
	if not _is_elementalist() or not _can_spend(&"elementalist_tri_nova"):
		return false
	_spend(&"elementalist_tri_nova")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"elementalist_tri_nova")
	var rank_definition := _runtime_rank_definition(&"elementalist_tri_nova")
	var magic_attack := stat_breakdown.value(&"magic_attack")
	var requests: Array[DamageRequest] = []
	var powers: Array[float] = [rank_definition.power, rank_definition.secondary_power, 0.60]
	for index: int in range(3):
		var request := _make_magic_request(null, &"elementalist_tri_nova", magic_attack * powers[index], definition.accuracy_mode, definition.can_crit)
		request.is_secondary = index > 0
		if index > 0 and request.context != null:
			request.context.family_id = &"elementalist_tri_nova_ice" if index == 1 else &"elementalist_tri_nova_lightning"
		requests.append(request)
	elementalist_tri_nova_requested.emit(global_position, requests, magic_attack * 0.40)
	resources_changed.emit()
	return true

func use_spiritualist_echo_curse(enemy: CombatActor) -> bool:
	var skill_id := &"spiritualist_echo_curse"
	var rank_definition := _runtime_rank_definition(skill_id)
	if not _is_spiritualist() or rank_definition == null or not can_target_skill(skill_id, enemy) or not _can_spend(skill_id):
		return false
	_spend(skill_id)
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(skill_id)
	var request := _make_magic_request(enemy, skill_id, _magic_power(skill_id) + consume_spiritualist_focus(), definition.accuracy_mode, definition.can_crit)
	spiritualist_echo_curse_requested.emit(request, enemy, rank_definition.secondary_power)
	resources_changed.emit()
	return true

func spiritualist_magic_attack() -> float:
	return stat_breakdown.value(&"magic_attack")

func make_spiritualist_echo_request(enemy: CombatActor, magic_damage: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = get_instance_id()
	request.target_id = enemy.get_instance_id()
	request.skill_id = &"spiritualist_echo_curse"
	request.magic_damage = magic_damage
	request.damage_dealt_multiplier = outgoing_damage_multiplier()
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	request.is_secondary = true
	return request

func use_spiritualist_soul_drain(enemy: CombatActor) -> bool:
	var skill_id := &"spiritualist_soul_drain"
	if not _is_spiritualist() or _runtime_rank_definition(skill_id) == null or not can_target_skill(skill_id, enemy) or not _can_spend(skill_id):
		return false
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_spend(skill_id)
	reveal_from_offense()
	_path.clear()
	_has_path_goal = false
	target = null
	_attack_engaged = false
	velocity = Vector2.ZERO
	var definition := ClassCatalog.skill_definition(skill_id)
	var request := _make_magic_request(enemy, skill_id, _magic_power(skill_id), definition.accuracy_mode, definition.can_crit)
	spiritualist_drain_requested.emit(request, enemy)
	presentation_action.emit(&"cast", global_position.direction_to(enemy.global_position), 2.0)
	resources_changed.emit()
	return true

func spiritualist_veil_center(point: Vector2) -> Vector2:
	return global_position + (point - global_position).limit_length(skill_range(&"spiritualist_spectral_veil"))

func can_place_spiritualist_veil(point: Vector2) -> bool:
	if navigation == null or skill_range(&"spiritualist_spectral_veil") <= 0.0:
		return false
	var center := spiritualist_veil_center(point)
	return navigation.is_walkable(center) and navigation.is_segment_clear(global_position, center, 0.0)

func use_spiritualist_spectral_veil(point: Vector2) -> bool:
	var skill_id := &"spiritualist_spectral_veil"
	var rank_definition := _runtime_rank_definition(skill_id)
	if not _is_spiritualist() or rank_definition == null or not _can_spend(skill_id) or not can_place_spiritualist_veil(point):
		return false
	var center := spiritualist_veil_center(point)
	_spend(skill_id)
	reveal_from_offense()
	spiritualist_veil_requested.emit(center, rank_definition.secondary_power, rank_definition.power)
	resources_changed.emit()
	return true

func use_spiritualist_procession(enemy: CombatActor) -> bool:
	var skill_id := &"spiritualist_procession"
	if not _is_spiritualist() or _runtime_rank_definition(skill_id) == null or not can_target_skill(skill_id, enemy) or not _can_spend(skill_id):
		return false
	_spend(skill_id)
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(skill_id)
	var request := _make_magic_request(enemy, skill_id, _magic_power(skill_id), definition.accuracy_mode, definition.can_crit)
	spiritualist_procession_requested.emit(request, enemy)
	resources_changed.emit()
	return true

func spiritualist_dissipation_center(point: Vector2) -> Vector2:
	return global_position + (point - global_position).limit_length(skill_range(&"spiritualist_dissipation"))

func can_place_spiritualist_dissipation(point: Vector2) -> bool:
	if navigation == null or skill_range(&"spiritualist_dissipation") <= 0.0:
		return false
	var center := spiritualist_dissipation_center(point)
	return navigation.is_walkable(center) and navigation.is_segment_clear(global_position, center, 0.0)

func use_spiritualist_dissipation(point: Vector2) -> bool:
	var skill_id := &"spiritualist_dissipation"
	var rank_definition := _runtime_rank_definition(skill_id)
	if not _is_spiritualist() or rank_definition == null or not _can_spend(skill_id) or not can_place_spiritualist_dissipation(point):
		return false
	var center := spiritualist_dissipation_center(point)
	_spend(skill_id)
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(skill_id)
	var magic_attack := spiritualist_magic_attack()
	var focus_bonus := consume_spiritualist_focus()
	var request := _make_magic_request(null, skill_id, magic_attack * rank_definition.power, definition.accuracy_mode, definition.can_crit)
	spiritualist_dissipation_requested.emit(center, request, magic_attack * rank_definition.secondary_power, focus_bonus)
	resources_changed.emit()
	return true

func heal_from_spiritualist_drain(result: Dictionary, already_healed: float) -> float:
	if not _is_spiritualist() or not is_alive() or int(result.get("source_id", 0)) != get_instance_id() or StringName(result.get("skill_id", &"")) != &"spiritualist_soul_drain":
		return 0.0
	if float(result.get("actual_damage", 0.0)) <= 0.0 or not claim_effect_result(result, &"spiritualist_drain_heal", int(result.get("target_id", 0)), true):
		return 0.0
	var actual_damage := maxf(0.0, float(result.get("actual_damage", 0.0)))
	var remaining_channel_cap := maxf(0.0, health.max_hp * 0.05 - already_healed)
	var healed := minf(minf(actual_damage * 0.15, remaining_channel_cap), health.max_hp - health.current_hp)
	if healed > 0.0:
		health.heal(healed)
		resources_changed.emit()
		queue_redraw()
	return healed

func recover_spiritualist_echo_sp(emission_id: int, result: Dictionary = {}) -> float:
	if not _is_spiritualist() or not is_alive() or spiritualist_recovery_cooldown > 0.0 or not run_state.build_snapshot.has_passive(&"spiritualist_echo_recovery"):
		return 0.0
	var rank_definition := _runtime_rank_definition(&"spiritualist_echo_recovery")
	if rank_definition == null or (emission_id > 0 and _spiritualist_refunded_emissions.has(emission_id)):
		return 0.0
	var recovered := minf(rank_definition.power, sp_deficit())
	if recovered <= 0.0 or not claim_effect_result(result, &"spiritualist_echo_recovery", get_instance_id()):
		return 0.0
	recover_sp(recovered)
	spiritualist_recovery_cooldown = 1.0
	if emission_id > 0:
		_spiritualist_refunded_emissions[emission_id] = true
	resources_changed.emit()
	return recovered

func clear_spiritualist_state() -> void:
	spiritualist_recovery_cooldown = 0.0
	_spiritualist_refunded_emissions.clear()
	spiritualist_focus_remaining = 0.0
	spiritualist_focus_power = 0.0

func grant_spiritualist_focus(context: CombatEventContext = null) -> bool:
	if not _is_spiritualist() or not is_alive() or not run_state.build_snapshot.has_passive(&"spiritualist_channel_focus"):
		return false
	var rank_definition := _runtime_rank_definition(&"spiritualist_channel_focus")
	if rank_definition == null:
		return false
	if context != null and (context.ledger() == null or context.ledger().claim_intrinsic(context, [{"family_id": &"spiritualist_channel_focus", "source_id": &"spiritualist_channel_focus", "target_id": get_instance_id()}]).is_empty()):
		return false
	spiritualist_focus_power = rank_definition.power
	spiritualist_focus_remaining = 5.0
	spiritualist_focus_event.emit(&"grant")
	return true

func consume_spiritualist_focus() -> float:
	if not _is_spiritualist() or not is_alive() or spiritualist_focus_remaining <= 0.0 or spiritualist_focus_power <= 0.0:
		return 0.0
	var bonus := stat_breakdown.value(&"magic_attack") * spiritualist_focus_power
	spiritualist_focus_remaining = 0.0
	spiritualist_focus_power = 0.0
	spiritualist_focus_event.emit(&"consume")
	return bonus

func use_spear(skill_id: StringName, enemy: CombatActor) -> bool:
	if class_id != &"mage" or skill_id not in [&"fire_spear", &"ice_spear"] or not can_target_skill(skill_id, enemy) or not _can_spend(skill_id):
		return false
	var facing := _resolved_facing(global_position.direction_to(enemy.global_position))
	_spend(skill_id)
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(skill_id)
	var request := _make_magic_request(enemy, skill_id, _magic_power(skill_id), definition.accuracy_mode, definition.can_crit)
	var count := run_state.projectile_count(skill_id)
	mage_projectile_requested.emit(skill_id, request, enemy, facing, count)
	resources_changed.emit()
	return true

func use_lightning_wall(direction: Vector2) -> bool:
	if class_id != &"mage" or _runtime_rank_definition(&"lightning_wall") == null or not _can_spend(&"lightning_wall"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"lightning_wall")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"lightning_wall")
	var request := _make_magic_request(null, &"lightning_wall", _magic_power(&"lightning_wall"), definition.accuracy_mode, definition.can_crit)
	request.is_secondary = true
	lightning_wall_requested.emit(facing, request)
	resources_changed.emit()
	return true

func has_shield_stance() -> bool:
	return is_alive() and shield_remaining > 0.0 and shield_resistance > 0

func use_shield_wall(direction: Vector2) -> bool:
	if class_id != &"swordsman" or not is_alive():
		return false
	if has_shield_stance():
		clear_shield_stance()
		return true
	var rank_definition := _runtime_rank_definition(&"shield_wall")
	if rank_definition == null or not _can_spend(&"shield_wall"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"shield_wall").action_kind)
	var facing := _resolved_facing(direction)
	_spend(&"shield_wall")
	shield_remaining = SHIELD_DURATION
	shield_resistance = roundi(rank_definition.power)
	shield_facing = facing
	if target != null:
		target = null
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
		_attack_engaged = false
		_attack_recovery = 0.0
	resources_changed.emit()
	queue_redraw()
	return true

func use_provoke(enemy: CombatActor) -> bool:
	var rank_definition := _runtime_rank_definition(&"provoke")
	if class_id != &"swordsman" or rank_definition == null or not can_target_skill(&"provoke", enemy) or not _can_spend(&"provoke"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"provoke").action_kind)
	var facing := _resolved_facing(global_position.direction_to(enemy.global_position))
	_spend(&"provoke")
	presentation_action.emit(&"cast", facing, 0.15)
	provoke_requested.emit(enemy, rank_definition.power)
	resources_changed.emit()
	return true

func use_perseverance() -> bool:
	var rank_definition := _runtime_rank_definition(&"perseverance")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"perseverance"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"perseverance").action_kind)
	var capacity := StatCalculator.personal_shield_capacity(rank_definition.power, stat_breakdown)
	if not health.grant_shield(capacity):
		return false
	_spend(&"perseverance")
	perseverance_remaining = PERSEVERANCE_DURATION
	presentation_action.emit(&"cast", _last_facing, 0.15)
	resources_changed.emit()
	queue_redraw()
	return true

func use_piercing_shout() -> bool:
	var rank_definition := _runtime_rank_definition(&"piercing_shout")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"piercing_shout"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"piercing_shout").action_kind)
	_spend(&"piercing_shout")
	reveal_from_offense()
	piercing_shout_visual_time = 0.25
	var definition := ClassCatalog.skill_definition(&"piercing_shout")
	var request := _make_physical_request(null, &"piercing_shout", stat_breakdown.value(&"melee_attack") * PIERCING_SHOUT_DAMAGE_WEIGHT, definition.accuracy_mode, definition.can_crit)
	piercing_shout_requested.emit(global_position, request, rank_definition.range, rank_definition.power)
	presentation_action.emit(&"cast", _last_facing, 0.25)
	resources_changed.emit()
	queue_redraw()
	return true

func use_fury() -> bool:
	if class_id != &"swordsman" or _runtime_rank_definition(&"fury") == null or not _can_spend(&"fury"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"fury").action_kind)
	_spend(&"fury")
	fury_remaining = FURY_DURATION
	_apply_derived_stats(_build_stat_breakdown())
	reveal_from_offense()
	presentation_action.emit(&"cast", _last_facing, 0.20)
	resources_changed.emit()
	queue_redraw()
	return true

func use_brutal_strike(enemy: CombatActor) -> bool:
	var rank_definition := _runtime_rank_definition(&"brutal_strike")
	if class_id != &"swordsman" or rank_definition == null or not can_target_skill(&"brutal_strike", enemy) or not _can_spend(&"brutal_strike"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"brutal_strike").action_kind)
	var facing := _resolved_facing(global_position.direction_to(enemy.global_position))
	_spend(&"brutal_strike")
	reveal_from_offense()
	brutal_strike_visual_time = 0.20
	brutal_strike_visual_point = enemy.global_position
	var definition := ClassCatalog.skill_definition(&"brutal_strike")
	var request := _make_physical_request(enemy, &"brutal_strike", stat_breakdown.value(&"melee_attack") * rank_definition.power, definition.accuracy_mode, definition.can_crit)
	brutal_strike_requested.emit(request, enemy)
	presentation_action.emit(&"slash", facing, 0.20)
	resources_changed.emit()
	queue_redraw()
	return true

func use_concentrated_rage(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"concentrated_rage")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"concentrated_rage"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"concentrated_rage").action_kind)
	var facing := _resolved_facing(direction)
	_spend(&"concentrated_rage")
	reveal_from_offense()
	target = null
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	_stop_dash()
	concentrated_rage_visual_time = 0.22
	concentrated_rage_visual_origin = global_position
	concentrated_rage_visual_direction = facing
	concentrated_rage_visual_range = rank_definition.range
	var definition := ClassCatalog.skill_definition(&"concentrated_rage")
	var power := stat_breakdown.value(&"melee_attack") * rank_definition.power
	for enemy: CombatActor in enemies.duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if SkillGeometry.strip_contains(enemy.global_position - global_position, facing, rank_definition.range, CONCENTRATED_RAGE_HALF_WIDTH, enemy.collision_radius):
			attack_requested.emit(_make_physical_request(enemy, &"concentrated_rage", power, definition.accuracy_mode, definition.can_crit), enemy)
	presentation_action.emit(&"slash", facing, 0.22)
	resources_changed.emit()
	queue_redraw()
	return true

func use_terrifying_shout() -> bool:
	var rank_definition := _runtime_rank_definition(&"terrifying_shout")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"terrifying_shout"):
		return false
	_commit_action(ClassCatalog.skill_definition(&"terrifying_shout").action_kind)
	_spend(&"terrifying_shout")
	reveal_from_offense()
	terrifying_shout_visual_time = 0.28
	terrifying_shout_requested.emit(global_position, rank_definition.range, rank_definition.power)
	presentation_action.emit(&"cast", _last_facing, 0.28)
	resources_changed.emit()
	queue_redraw()
	return true

func clear_fury() -> void:
	if fury_remaining <= 0.0:
		return
	fury_remaining = 0.0
	_apply_derived_stats(_build_stat_breakdown())
	resources_changed.emit()
	queue_redraw()

func clear_perseverance() -> void:
	if perseverance_remaining <= 0.0 and health.shield_hp <= 0.0:
		return
	perseverance_remaining = 0.0
	health.clear_shield()
	resources_changed.emit()
	queue_redraw()

func clear_shield_stance() -> void:
	if shield_remaining <= 0.0 and shield_resistance <= 0:
		return
	shield_remaining = 0.0
	shield_resistance = 0
	resources_changed.emit()
	queue_redraw()

func shield_interception_fraction(from: Vector2, to: Vector2, projectile_radius: float) -> float:
	if not has_shield_stance():
		return -1.0
	var center := global_position + Vector2(0, -18)
	var radius := SHIELD_RADIUS + maxf(0.0, projectile_radius)
	var offset := from - center
	if offset.length_squared() <= radius * radius:
		return -1.0
	var travel := to - from
	var a := travel.length_squared()
	if a <= 0.0001:
		return -1.0
	var b := 2.0 * offset.dot(travel)
	var c := offset.length_squared() - radius * radius
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var fraction := (-b - sqrt(discriminant)) / (2.0 * a)
	if fraction < 0.0 or fraction > 1.0:
		return -1.0
	var contact_direction := (from.lerp(to, fraction) - center).normalized()
	return fraction if contact_direction.dot(shield_facing) >= cos(SHIELD_HALF_ANGLE) else -1.0

func absorb_shield_projectile() -> bool:
	if not has_shield_stance():
		return false
	_grant_defender_front_event()
	shield_resistance -= 1
	if shield_resistance <= 0:
		clear_shield_stance()
	else:
		resources_changed.emit()
		queue_redraw()
	return true

func _commit_action(action_kind: SkillDefinition.ActionKind) -> void:
	if action_kind == SkillDefinition.ActionKind.OFFENSIVE:
		clear_shield_stance()

func apply_damage(request: DamageRequest, rng: RandomNumberGenerator) -> Dictionary:
	if request == null:
		return {}
	if request.is_secondary or request.target_id != get_instance_id():
		return _apply_damage_with_shield(request, rng)
	var source := instance_from_id(request.source_id) as Node2D
	if source == null or not is_instance_valid(source):
		return _apply_damage_with_shield(request, rng)
	var front_reduction := 0.0
	if has_shield_stance() and _faces_position(shield_facing, source.global_position):
		front_reduction = SHIELD_FRONT_REDUCTION
	if _is_defender() and defender_counter_guard_remaining > 0.0 and _faces_position(defender_counter_guard_facing, source.global_position):
		front_reduction = maxf(front_reduction, DEFENDER_COUNTER_GUARD_REDUCTION)
	if _is_defender() and defender_advance_guard_active and _faces_position(defender_advance_guard_facing, source.global_position):
		front_reduction = maxf(front_reduction, DEFENDER_ADVANCE_GUARD_REDUCTION)
	var effective_request := request.copy() if front_reduction > 0.0 else request
	if front_reduction > 0.0:
		effective_request.damage_dealt_multiplier *= 1.0 - front_reduction
	var result := _apply_damage_with_shield(effective_request, rng)
	var frontal_shield_absorption := _faces_position(_defender_event_facing(), source.global_position) and float(result.get("absorbed_damage", 0.0)) > 0.0
	if bool(result.get("landed", false)) and float(result.get("damage", 0.0)) > 0.0 and (front_reduction > 0.0 or frontal_shield_absorption):
		_grant_defender_front_event(result)
	return result

func _apply_damage_with_shield(request: DamageRequest, rng: RandomNumberGenerator) -> Dictionary:
	var result := super.apply_damage(request, rng)
	if not result.is_empty() and float(result.get("absorbed_damage", 0.0)) > 0.0:
		if health.shield_hp <= 0.0:
			clear_perseverance()
		else:
			resources_changed.emit()
			queue_redraw()
	return result

func _shield_faces_position(position: Vector2) -> bool:
	return _faces_position(shield_facing, position)

func _faces_position(facing: Vector2, position: Vector2) -> bool:
	var offset := position - global_position
	return not offset.is_zero_approx() and offset.normalized().dot(facing) >= cos(SkillGeometry.DEFENDER_GUARD_HALF_ANGLE)

func _defender_event_facing() -> Vector2:
	if defender_advance_guard_active:
		return defender_advance_guard_facing
	if defender_counter_guard_remaining > 0.0:
		return defender_counter_guard_facing
	return shield_facing if has_shield_stance() else _last_facing

func _is_defender() -> bool:
	return run_state != null and run_state.uses_persistent_build() and run_state.build_snapshot.evolution_id == &"defender" and class_id == &"swordsman"

func _is_berserker() -> bool:
	return run_state != null and run_state.uses_persistent_build() and run_state.build_snapshot.evolution_id == &"berserker" and class_id == &"swordsman"

func _is_elementalist() -> bool:
	return run_state != null and run_state.uses_persistent_build() and run_state.build_snapshot.evolution_id == &"elementalist" and class_id == &"mage"

func _is_spiritualist() -> bool:
	return run_state != null and run_state.uses_persistent_build() and run_state.build_snapshot.evolution_id == &"spiritualist" and class_id == &"mage"

func _defender_active_equipped(skill_id: StringName) -> bool:
	return _is_defender() and skill_id in available_skill_ids()

func _grant_defender_front_event(result: Dictionary = {}) -> void:
	if not _is_defender() or skill_rank(&"defender_counterstroke") <= 0 or not is_alive():
		return
	var context: CombatEventContext = result.get("context")
	if context != null:
		var candidates: Array[Dictionary] = [{"family_id": &"defender_token", "source_id": &"defender_token", "target_id": get_instance_id()}]
		if run_state.build_snapshot.has_passive(&"defender_guard_return") and defender_guard_return_cooldown <= 0.0:
			candidates.append({"family_id": &"defender_guard_return", "source_id": &"defender_guard_return", "target_id": get_instance_id()})
		result["_effect_claims"] = context.ledger().claim_batch(context, candidates) if context.ledger() != null else []
		if not claim_effect_result(result, &"defender_token", get_instance_id()):
			return
	var renewed := has_defender_token()
	defender_token_remaining = DEFENDER_TOKEN_DURATION
	_set_defender_token_notice("TOKEN RENOVADO" if renewed else "TOKEN PRONTO")
	var return_rank := _runtime_rank_definition(&"defender_guard_return")
	if return_rank != null and run_state.build_snapshot.has_passive(&"defender_guard_return") and defender_guard_return_cooldown <= 0.0 and claim_effect_result(result, &"defender_guard_return", get_instance_id()):
		recover_sp(return_rank.power)
		defender_guard_return_cooldown = return_rank.cooldown
	resources_changed.emit()
	queue_redraw()

func _consume_defender_token() -> void:
	defender_token_remaining = 0.0
	_set_defender_token_notice("TOKEN CONSUMIDO")

func _set_defender_token_notice(message: String) -> void:
	defender_token_notice = message
	defender_token_notice_remaining = DEFENDER_TOKEN_NOTICE_DURATION
	queue_redraw()

func defender_feedback_text() -> String:
	if not _is_defender() or not is_alive():
		return ""
	var lines := PackedStringArray()
	if has_defender_token():
		lines.append("CONTRA-ATAQUE PRONTO · %.1fs" % defender_token_remaining)
	elif defender_token_notice_remaining > 0.0:
		lines.append(defender_token_notice)
	else:
		lines.append("CONTRA-ATAQUE SEM TOKEN")
	if defender_counter_guard_remaining > 0.0:
		lines.append("GUARDA FRONTAL · %.1fs" % defender_counter_guard_remaining)
	elif defender_advance_guard_active:
		lines.append("GUARDA FRONTAL · AVANÇO")
	return "\n".join(lines)

func clear_defender_state() -> void:
	defender_token_remaining = 0.0
	defender_token_notice = ""
	defender_token_notice_remaining = 0.0
	defender_counter_guard_remaining = 0.0
	_stop_dash()
	defender_guard_return_cooldown = 0.0
	defender_anchor_remaining = 0.0
	defender_anchor_center = Vector2.INF
	if _defender_inside_anchor:
		_defender_inside_anchor = false
		if run_state != null and stat_breakdown != null:
			_apply_derived_stats(_build_stat_breakdown())
	resources_changed.emit()
	queue_redraw()

func has_defender_token() -> bool:
	return _is_defender() and defender_token_remaining > 0.0 and is_alive()

func has_defender_anchor() -> bool:
	return _is_defender() and defender_anchor_remaining > 0.0 and defender_anchor_center.is_finite() and is_alive()

func _update_defender_anchor_presence() -> void:
	var inside := has_defender_anchor() and global_position.distance_to(defender_anchor_center) <= SkillGeometry.DEFENDER_ANCHOR_RADIUS
	if inside == _defender_inside_anchor:
		return
	_defender_inside_anchor = inside
	_apply_derived_stats(_build_stat_breakdown())
	resources_changed.emit()
	queue_redraw()

func use_soul_impact(enemy: CombatActor) -> bool:
	if class_id != &"mage" or _runtime_rank_definition(&"soul_impact") == null or not can_target_skill(&"soul_impact", enemy) or not _can_spend(&"soul_impact"):
		return false
	_spend(&"soul_impact")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"soul_impact")
	var request := _make_magic_request(enemy, &"soul_impact", _magic_power(&"soul_impact"), definition.accuracy_mode, definition.can_crit)
	soul_impact_requested.emit(request, enemy)
	resources_changed.emit()
	return true

func use_haunt(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"haunt")
	if class_id != &"mage" or rank_definition == null or not _can_spend(&"haunt"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"haunt")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"haunt")
	var request := _make_magic_request(null, &"haunt", _magic_power(&"haunt"), definition.accuracy_mode, definition.can_crit)
	haunt_requested.emit(global_position, facing, rank_definition.range, request)
	resources_changed.emit()
	return true

func use_phantom_barrier(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"phantom_barrier")
	if class_id != &"mage" or rank_definition == null or not _can_spend(&"phantom_barrier"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"phantom_barrier")
	reveal_from_offense()
	phantom_barrier_requested.emit(facing, rank_definition.range, roundi(rank_definition.power))
	resources_changed.emit()
	return true

func can_place_ice_wall(direction: Vector2, nearby_actors: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"ice_wall")
	if class_id != &"mage" or rank_definition == null or navigation == null or not is_alive():
		return false
	var facing := direction.normalized() if not direction.is_zero_approx() else _last_facing
	var points := IceWallScript.endpoints(global_position, facing, rank_definition.range)
	return navigation.can_add_temporary_segment(points[0], points[1], IceWallScript.HALF_WIDTH, _ice_wall_occupied_positions(nearby_actors))

func use_ice_wall(direction: Vector2, nearby_actors: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"ice_wall")
	if class_id != &"mage" or rank_definition == null or not _can_spend(&"ice_wall") or not can_place_ice_wall(direction, nearby_actors):
		return false
	var facing := _resolved_facing(direction)
	var occupied := _ice_wall_occupied_positions(nearby_actors)
	var wall := IceWallScript.new()
	if not wall.configure(navigation, global_position, facing, rank_definition.range, rank_definition.power, occupied):
		wall.free()
		return false
	_spend(&"ice_wall")
	reveal_from_offense()
	ice_wall_requested.emit(wall)
	resources_changed.emit()
	return true

func _ice_wall_occupied_positions(nearby_actors: Array[CombatActor]) -> Array[Vector2]:
	var positions: Array[Vector2] = [global_position]
	for actor: CombatActor in nearby_actors:
		if actor != null and is_instance_valid(actor) and actor.is_alive():
			positions.append(actor.global_position)
	return positions

func use_lightning(enemy: CombatActor) -> bool:
	if class_id != &"mage" or not can_target_skill(&"lightning", enemy) or not _can_spend(&"lightning"):
		return false
	var facing := _resolved_facing(global_position.direction_to(enemy.global_position))
	_spend(&"lightning")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"lightning")
	var request := _make_magic_request(enemy, &"lightning", _magic_power(&"lightning"), definition.accuracy_mode, definition.can_crit)
	mage_projectile_requested.emit(&"lightning", request, enemy, facing, 1)
	resources_changed.emit()
	return true

func use_electric_discharge(direction: Vector2) -> bool:
	if class_id != &"mage" or _runtime_rank_definition(&"electric_discharge") == null or not _can_spend(&"electric_discharge"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"electric_discharge")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"electric_discharge")
	var request := _make_magic_request(null, &"electric_discharge", _magic_power(&"electric_discharge"), definition.accuracy_mode, definition.can_crit)
	var bonus_magic_damage := stat_breakdown.value(&"magic_attack") * DISCHARGE_MARK_BONUS_WEIGHT
	discharge_requested.emit(request, facing, bonus_magic_damage)
	resources_changed.emit()
	return true

func use_double_shot(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"double_shot")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"double_shot"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"double_shot")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"double_shot")
	var power := stat_breakdown.value(&"precision_attack") * rank_definition.power
	var request := _make_physical_request(null, &"double_shot", power, definition.accuracy_mode, definition.can_crit)
	precision_projectile_requested.emit(&"double_shot", request, null, facing, run_state.projectile_count(&"double_shot"), 1)
	resources_changed.emit()
	return true

func use_piercing_arrow(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"piercing_arrow")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"piercing_arrow"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"piercing_arrow")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"piercing_arrow")
	var power := stat_breakdown.value(&"precision_attack") * rank_definition.power
	var request := _make_physical_request(null, &"piercing_arrow", power, definition.accuracy_mode, definition.can_crit)
	precision_projectile_requested.emit(&"piercing_arrow", request, null, facing, 1, PIERCING_ARROW_MAX_HITS)
	resources_changed.emit()
	return true

func use_arrow_rain(point: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"arrow_rain")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"arrow_rain"):
		return false
	var center := arrow_rain_center(point)
	_spend(&"arrow_rain")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"arrow_rain")
	var volley_power := stat_breakdown.value(&"precision_attack") * rank_definition.power / float(ArrowRain.VOLLEY_COUNT)
	var request := _make_physical_request(null, &"arrow_rain", volley_power, definition.accuracy_mode, definition.can_crit)
	arrow_rain_requested.emit(center, request)
	resources_changed.emit()
	return true

func use_extended_aim() -> bool:
	var rank_definition := _runtime_rank_definition(&"extended_aim")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"extended_aim"):
		return false
	_spend(&"extended_aim")
	extended_aim_remaining = rank_definition.power
	presentation_action.emit(&"cast", _last_facing, 0.18)
	resources_changed.emit()
	queue_redraw()
	return true

func trap_center(skill_id: StringName, point: Vector2) -> Vector2:
	var offset := point - global_position
	var maximum_range := skill_range(skill_id)
	if offset.length() > maximum_range:
		offset = offset.normalized() * maximum_range
	return global_position + offset

func can_place_trap(skill_id: StringName, point: Vector2) -> bool:
	if not point.is_finite() or skill_id not in HunterMath.TRAP_IDS or skill_range(skill_id) <= 0.0 or navigation == null:
		return false
	if skill_id in HunterMath.NEW_TRAP_IDS and not is_hunter():
		return false
	var center := trap_center(skill_id, point)
	return navigation.is_walkable(center) and (not is_hunter() or navigation.is_segment_clear(global_position, center, 0.0))

func trap_armed_duration(base_duration: float) -> float:
	return run_state.build_snapshot.trap_armed_duration(base_duration)

func use_hunter_trap(skill_id: StringName, point: Vector2) -> bool:
	if not is_hunter() or skill_id not in HunterMath.NEW_TRAP_IDS or not _can_spend(skill_id) or not can_place_trap(skill_id, point) or (is_inside_tree() and get_tree().paused):
		return false
	var rank := skill_rank(skill_id)
	var request := HunterMath.trap_request(get_instance_id(), skill_id, rank, stat_breakdown, outgoing_damage_multiplier())
	var opening := hunter_opening_snapshot(skill_id)
	if request == null or opening == null:
		return false
	var center := trap_center(skill_id, point)
	_spend(skill_id)
	request.context = _emission_context.copy_context()
	opening.inherit_root(_emission_context)
	reveal_from_offense()
	hunter_trap_requested.emit(center, rank, request, opening)
	presentation_action.emit(&"cast_release", aim_direction(center), 0.18)
	resources_changed.emit()
	return true

func snare_trap_center(point: Vector2) -> Vector2:
	return trap_center(&"snare_trap", point)

func can_place_snare_trap(point: Vector2) -> bool:
	return can_place_trap(&"snare_trap", point)

func use_snare_trap(point: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"snare_trap")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"snare_trap") or not can_place_snare_trap(point):
		return false
	var center := snare_trap_center(point)
	_spend(&"snare_trap")
	reveal_from_offense()
	snare_trap_requested.emit(center, rank_definition.power)
	presentation_action.emit(&"cast", aim_direction(center), 0.18)
	resources_changed.emit()
	return true

func explosive_trap_center(point: Vector2) -> Vector2:
	return trap_center(&"explosive_trap", point)

func can_place_explosive_trap(point: Vector2) -> bool:
	return can_place_trap(&"explosive_trap", point)

func use_explosive_trap(point: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"explosive_trap")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"explosive_trap") or not can_place_explosive_trap(point):
		return false
	var center := explosive_trap_center(point)
	_spend(&"explosive_trap")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"explosive_trap")
	var power := stat_breakdown.value(&"precision_attack") * rank_definition.power
	var request := _make_physical_request(null, &"explosive_trap", power, definition.accuracy_mode, definition.can_crit)
	if is_hunter():
		request.physical_damage = HunterMath.explosive_raw(skill_rank(&"explosive_trap"), stat_breakdown)
		request.can_crit = false
	explosive_trap_requested.emit(center, request)
	presentation_action.emit(&"cast", aim_direction(center), 0.18)
	resources_changed.emit()
	return true

func use_slowing_arrow(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"slowing_arrow")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"slowing_arrow"):
		return false
	var facing := _resolved_facing(direction)
	_spend(&"slowing_arrow")
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(&"slowing_arrow")
	var power := stat_breakdown.value(&"precision_attack") * definition.power
	var request := _make_physical_request(null, &"slowing_arrow", power, definition.accuracy_mode, definition.can_crit)
	slowing_arrow_requested.emit(request, facing, SLOWING_ARROW_SLOW_FRACTION, rank_definition.power)
	resources_changed.emit()
	return true

func use_hunter_mark(enemy: CombatActor) -> bool:
	if not is_hunter() or (is_inside_tree() and get_tree().paused) or not _can_spend(&"hunter_mark") or not can_target_skill(&"hunter_mark", enemy):
		return false
	if not hunter_state.mark(enemy.get_instance_id(), skill_rank(&"hunter_mark")):
		return false
	_spend(&"hunter_mark")
	reveal_from_offense()
	presentation_action.emit(&"cast", aim_direction(enemy.global_position), 0.18)
	resources_changed.emit()
	return true

func hunter_recoil_destination(direction: Vector2) -> Vector2:
	var facing := direction.normalized() if not direction.is_zero_approx() else _last_facing
	return global_position - facing * float(HunterTuning.values(&"hunter_covering_shot", skill_rank(&"hunter_covering_shot")).get("recoil_distance", 0.0))

func can_use_hunter_covering_shot(direction: Vector2) -> bool:
	return is_hunter() and direction.is_finite() and not is_rooted() and navigation != null and _runtime_rank_definition(&"hunter_covering_shot") != null and navigation.is_segment_walkable(global_position, hunter_recoil_destination(direction))

func use_hunter_covering_shot(direction: Vector2) -> bool:
	if (is_inside_tree() and get_tree().paused) or not _can_spend(&"hunter_covering_shot") or not can_use_hunter_covering_shot(direction):
		return false
	var facing := _resolved_facing(direction)
	var origin := global_position + PlayerProjectile.BODY_OFFSET
	var destination := hunter_recoil_destination(facing)
	var rank_definition := _runtime_rank_definition(&"hunter_covering_shot")
	var request := _make_physical_request(null, &"hunter_covering_shot", stat_breakdown.value(&"precision_attack") * rank_definition.power, DamageRequest.AccuracyMode.GEOMETRY, true)
	_spend(&"hunter_covering_shot")
	request.context = _emission_context.copy_context()
	request.emission_id = int(_emission_context.root_event_id.get_slice(":", _emission_context.root_event_id.get_slice_count(":") - 1))
	reveal_from_offense()
	global_position = destination
	_path.clear()
	_path_index = 0
	_has_path_goal = false
	_repath_time = 0.0
	velocity = Vector2.ZERO
	# Movement and the captured shot commit together; basic attack clocks remain.
	hunter_covering_shot_requested.emit(request, origin, facing)
	presentation_action.emit(&"basic_attack", facing, 0.18)
	resources_changed.emit()
	return true

func hunter_total_cover_center(point: Vector2) -> Vector2:
	return global_position + (point - global_position).limit_length(skill_range(&"hunter_total_cover"))

func can_place_hunter_total_cover(point: Vector2) -> bool:
	if not is_hunter() or not point.is_finite() or skill_range(&"hunter_total_cover") <= 0.0 or navigation == null:
		return false
	var center := hunter_total_cover_center(point)
	return navigation.is_walkable(center) and navigation.is_segment_clear(global_position, center, 0.0)

func use_hunter_total_cover(point: Vector2) -> bool:
	if (is_inside_tree() and get_tree().paused) or not _can_spend(&"hunter_total_cover") or not can_place_hunter_total_cover(point):
		return false
	var center := hunter_total_cover_center(point)
	var tuning := HunterTuning.values(&"hunter_total_cover", skill_rank(&"hunter_total_cover"))
	_spend(&"hunter_total_cover")
	hunter_cover.begin_cycle()
	hunter_total_cover_requested.emit(center, float(tuning["duration"]), float(tuning["radius"]), float(tuning["exit_grace"]))
	presentation_action.emit(&"cast", aim_direction(center), 0.18)
	resources_changed.emit()
	return true

func foliage_shelter_center(point: Vector2) -> Vector2:
	var offset := point - global_position
	var maximum_range := skill_range(&"foliage_shelter")
	if offset.length() > maximum_range:
		offset = offset.normalized() * maximum_range
	return global_position + offset

func can_place_foliage_shelter(point: Vector2) -> bool:
	if is_hunter() and (not point.is_finite() or navigation == null or not navigation.is_segment_clear(global_position, foliage_shelter_center(point), 0.0)):
		return false
	return skill_range(&"foliage_shelter") > 0.0 and navigation != null and navigation.is_walkable(foliage_shelter_center(point))

func use_foliage_shelter(point: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"foliage_shelter")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"foliage_shelter") or not can_place_foliage_shelter(point):
		return false
	if is_hunter() and is_inside_tree() and get_tree().paused:
		return false
	var center := foliage_shelter_center(point)
	_spend(&"foliage_shelter")
	if is_hunter():
		hunter_cover.begin_cycle()
	foliage_shelter_requested.emit(center, rank_definition.power)
	presentation_action.emit(&"cast", aim_direction(center), 0.18)
	resources_changed.emit()
	return true

func register_foliage_shelter(source_id: int, center: Vector2, radius: float, exit_grace: float = 0.0) -> bool:
	if source_id <= 0 or not center.is_finite() or not is_finite(radius) or radius <= 0.0:
		return false
	if is_hunter():
		if not hunter_cover.bind_zone(source_id, center, radius, exit_grace):
			return false
		_foliage_shelters.clear()
	_foliage_shelters[source_id] = {"center": center, "radius": radius}
	queue_redraw()
	return true

func unregister_foliage_shelter(source_id: int) -> bool:
	if not _foliage_shelters.erase(source_id):
		return false
	if is_hunter():
		hunter_cover.unbind_zone(source_id)
	elif _foliage_shelters.is_empty():
		concealment_reveal_remaining = 0.0
	queue_redraw()
	return true

func clear_foliage_shelters() -> void:
	_foliage_shelters.clear()
	concealment_reveal_remaining = 0.0
	hunter_cover.clear()
	queue_redraw()

func is_concealed() -> bool:
	if is_hunter():
		return is_alive() and hunter_cover.is_hidden(global_position)
	return is_alive() and concealment_reveal_remaining <= 0.0 and not _containing_foliage_shelters().is_empty()

func can_be_acquired_by(observer_position: Vector2) -> bool:
	if not is_alive():
		return false
	if is_hunter():
		return not is_concealed() or observer_position.distance_to(hunter_cover.center) <= hunter_cover.radius
	var containing := _containing_foliage_shelters()
	if concealment_reveal_remaining > 0.0 or containing.is_empty():
		return true
	for shelter: Dictionary in containing:
		if observer_position.distance_to(shelter["center"]) <= float(shelter["radius"]):
			return true
	return false

func reveal_from_offense(duration: float = CONCEALMENT_REVEAL_DURATION) -> bool:
	if is_hunter():
		var revealed := hunter_cover.reveal(duration)
		concealment_reveal_remaining = hunter_cover.reveal_remaining
		queue_redraw()
		return revealed
	if _foliage_shelters.is_empty() or duration <= 0.0:
		return false
	concealment_reveal_remaining = maxf(concealment_reveal_remaining, duration)
	queue_redraw()
	return true

func _containing_foliage_shelters() -> Array[Dictionary]:
	var containing: Array[Dictionary] = []
	for raw_source_id: Variant in _foliage_shelters:
		var shelter: Dictionary = _foliage_shelters[raw_source_id]
		if global_position.distance_to(shelter["center"]) <= float(shelter["radius"]):
			containing.append(shelter)
	return containing

func is_geometer() -> bool:
	return class_id == &"mage" and run_state != null and run_state.uses_persistent_build() and run_state.build_snapshot.evolution_id == &"mg_ar"

func geometer_shot_check(command: GeometerCastCommand, construction: GeometerConstructionState, actors: Array[CombatActor]) -> Dictionary:
	if not is_geometer() or command == null or construction == null or not GeometerCastCommand.is_trace_skill(command.skill_id) or command.element not in GeometerGeometry.ELEMENTS or command.actor_id < 0 or not command.point.is_finite():
		return {"ok": false, "reason": "Comando de Traçado inválido."}
	if is_inside_tree() and get_tree().paused:
		return {"ok": false, "reason": "Combate pausado."}
	if not _can_spend(command.skill_id):
		return {"ok": false, "reason": "Skill indisponível, em recarga ou sem SP."}
	var point := command.point
	var enemy: CombatActor
	if command.actor_id > 0:
		for actor: CombatActor in actors:
			if is_instance_valid(actor) and actor.is_alive() and actor.get_instance_id() == command.actor_id:
				enemy = actor
				point = actor.global_position
				break
		if enemy == null:
			return {"ok": false, "reason": "Alvo do Traçado inválido."}
	if navigation == null or not point.is_finite() or global_position.distance_to(point) > skill_range(command.skill_id) or not navigation.is_segment_clear(global_position, point, 4.0):
		return {"ok": false, "reason": "Traçado fora de alcance ou bloqueado."}
	var result := construction.preview_shot(point, command.skill_id == &"geometer_triangulation", skill_rank(&"geometer_triangulation"), navigation, command.element)
	result["point"] = point
	result["target"] = enemy
	return result

func begin_geometer_cast(command: GeometerCastCommand, construction: GeometerConstructionState, actors: Array[CombatActor]) -> bool:
	var check := geometer_shot_check(command, construction, actors)
	if not check["ok"]:
		return false
	return begin_skill_cast(command.skill_id, check["point"], check["target"], command)

func commit_geometer_shot(command: GeometerCastCommand, construction: GeometerConstructionState, actors: Array[CombatActor]) -> Dictionary:
	var check := geometer_shot_check(command, construction, actors)
	if not check["ok"]:
		return check
	var durations := geometer_durations()
	var ticket := construction.reserve_shot(check["point"], command.actor_id, command.skill_id == &"geometer_triangulation", skill_rank(&"geometer_triangulation"), navigation, durations.x, durations.y, command.element)
	if ticket == 0:
		return {"ok": false, "reason": "Construção indisponível."}
	_spend(command.skill_id)
	reveal_from_offense()
	var definition := ClassCatalog.skill_definition(command.skill_id)
	var request := _make_magic_request(check["target"], command.skill_id, _magic_power(command.skill_id), definition.accuracy_mode, definition.can_crit)
	check["ticket"] = ticket
	check["request"] = request
	check["wall_snapshot"] = geometer_wall_snapshot()
	check["triangle_snapshot"] = geometer_triangle_snapshot()
	check["speed"] = skill_projectile_speed(command.skill_id)
	check["range"] = skill_range(command.skill_id)
	presentation_action.emit(&"cast_release", _resolved_facing(aim_direction(check["point"])), 0.12)
	resources_changed.emit()
	return check

func geometer_durations() -> Vector2:
	var durations := Vector2(8.0, 6.0)
	if is_geometer() and run_state.build_snapshot.has_passive(&"geometer_vector_memory"):
		var memory := _runtime_rank_definition(&"geometer_vector_memory")
		if memory != null:
			durations += Vector2(memory.power, memory.secondary_power)
	return Vector2(minf(12.0, durations.x), minf(12.0, durations.y))

func geometer_action_check(command: GeometerCastCommand, construction: GeometerConstructionState, actors: Array[CombatActor]) -> Dictionary:
	if command != null and GeometerCastCommand.is_trace_skill(command.skill_id):
		return geometer_shot_check(command, construction, actors)
	if not is_geometer() or command == null or construction == null or not GeometerCastCommand.is_grammar_skill(command.skill_id) or command.element not in GeometerGeometry.ELEMENTS or command.actor_id < 0 or not command.point.is_finite():
		return {"ok": false, "reason": "Comando geométrico inválido."}
	if (is_inside_tree() and get_tree().paused) or not _can_spend(command.skill_id):
		return {"ok": false, "reason": "Skill indisponível, em recarga, pausada ou sem SP."}
	if construction.grammar.pending_count() > 0:
		return {"ok": false, "reason": "Aguarde os disparos em trânsito."}
	if command.skill_id == &"geometer_collapse":
		return {"ok": construction.has_active_figure(), "reason": "Colapso requer parede ou triângulo válido."}
	var point := command.point
	if command.actor_id > 0:
		var found := false
		for actor: CombatActor in actors:
			if is_instance_valid(actor) and actor.is_alive() and actor.get_instance_id() == command.actor_id:
				point = actor.global_position
				found = true
				break
		if not found:
			return {"ok": false, "reason": "Vínculo da edição inválido."}
	if navigation == null or global_position.distance_to(point) > skill_range(command.skill_id) or not navigation.is_segment_clear(global_position, point, 0.0):
		return {"ok": false, "reason": "Edição fora de alcance ou bloqueada."}
	var durations := geometer_durations()
	var result := construction.preview_edit(point, command.actor_id, command.skill_id == &"geometer_rewrite", skill_rank(&"geometer_triangulation"), navigation, durations.x, durations.y, command.element)
	result.erase("candidate")
	result["point"] = point
	return result

func commit_geometer_edit(command: GeometerCastCommand, construction: GeometerConstructionState, actors: Array[CombatActor]) -> Dictionary:
	var check := geometer_action_check(command, construction, actors)
	if not check["ok"] or not GeometerCastCommand.is_edit_skill(command.skill_id):
		return check if not check["ok"] else {"ok": false, "reason": "Skill não é edição."}
	var durations := geometer_durations()
	var result := construction.edit(check["point"], command.actor_id, command.skill_id == &"geometer_rewrite", skill_rank(&"geometer_triangulation"), navigation, durations.x, durations.y, command.element)
	if result["ok"]:
		cancel_active_cast()
		_spend(command.skill_id)
		reveal_from_offense()
		presentation_action.emit(&"cast_release", _resolved_facing(aim_direction(check["point"])), 0.12)
		resources_changed.emit()
	return result

func commit_geometer_collapse(command: GeometerCastCommand, construction: GeometerConstructionState, actors: Array[CombatActor]) -> Dictionary:
	var check := geometer_action_check(command, construction, actors)
	if not check["ok"] or command.skill_id != &"geometer_collapse":
		return check if not check["ok"] else {"ok": false, "reason": "Skill não é Colapso."}
	var captured := construction.consume_collapse()
	if captured.is_empty():
		return {"ok": false, "reason": "Sem figura ativa."}
	# Consume before any signal/damage; callbacks cannot finalize the same instance twice.
	cancel_active_cast()
	_spend(command.skill_id)
	var element: StringName = captured["elements"][2] if captured["shape"] == GeometerConstructionState.Shape.TRIANGLE else &"wall"
	var tuning := ClassCatalog.geometer_collapse_tuning(skill_rank(command.skill_id))
	var request := _make_magic_request(null, command.skill_id, stat_breakdown.value(&"magic_attack") * float(tuning[element]), DamageRequest.AccuracyMode.GEOMETRY, false)
	request.is_secondary = true
	captured["request"] = request
	captured["ok"] = true
	reveal_from_offense()
	return captured

func geometer_wall_snapshot() -> Dictionary:
	var tuning := ClassCatalog.geometer_wall_tuning(skill_rank(&"geometer_trace"))
	if not is_geometer() or tuning.is_empty():
		return {}
	var bonus := 0.0
	var refund := 0.0
	if run_state.build_snapshot.has_passive(&"geometer_incidence"):
		var passive := _runtime_rank_definition(&"geometer_incidence")
		if passive != null:
			bonus = passive.power
			refund = passive.secondary_power
	var magic := stat_breakdown.value(&"magic_attack")
	var entry := _make_magic_request(null, &"geometer_wall_entry", magic * float(tuning["entry_power"]) * (1.0 + bonus), DamageRequest.AccuracyMode.GEOMETRY, false)
	var exit := _make_magic_request(null, &"geometer_wall_exit", magic * float(tuning["exit_power"]) * (1.0 + bonus), DamageRequest.AccuracyMode.GEOMETRY, false)
	entry.is_secondary = true
	exit.is_secondary = true
	return {"entry_request": entry, "exit_request": exit, "slow_fraction": tuning["slow_fraction"], "incidence_fraction": bonus, "incidence_sp": refund}

func geometer_triangle_snapshot() -> Dictionary:
	var tuning := ClassCatalog.geometer_triangle_tuning(skill_rank(&"geometer_triangulation"))
	if not is_geometer() or tuning.is_empty():
		return {}
	var captured: Dictionary = {}
	for component: StringName in tuning:
		var request := _make_magic_request(null, StringName("geometer_" + String(component)), stat_breakdown.value(&"magic_attack") * float(tuning[component]), DamageRequest.AccuracyMode.GEOMETRY, false)
		request.is_secondary = true
		captured[component] = request
	return captured

func begin_skill_cast(skill_id: StringName, point: Vector2, enemy: CombatActor = null, geometer_command: GeometerCastCommand = null) -> bool:
	var definition := ClassCatalog.skill_definition(skill_id)
	var cast_time := skill_cast_time(skill_id)
	if definition == null or cast_time <= 0.0 or skill_id not in available_skill_ids() or not _can_spend(skill_id):
		return false
	if skill_id == &"sentinel_net_shot" and (not sentinel_can_use(skill_id) or not can_place_sentinel_net(point)):
		return false
	if skill_id in HunterMath.NEW_TRAP_IDS and not can_place_trap(skill_id, point):
		return false
	if definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET and not can_target_skill(skill_id, enemy):
		return false
	cancel_active_cast()
	active_cast_skill = skill_id
	active_cast_total = cast_time
	active_cast_remaining = active_cast_total
	_active_cast_point = point
	_active_cast_target_id = enemy.get_instance_id() if enemy != null else 0
	_active_geometer_command = geometer_command.copy_command() if geometer_command != null else null
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	_attack_recovery = 0.0
	var facing := aim_direction(enemy.global_position if enemy != null else point)
	_active_cast_direction = facing
	presentation_action.emit(&"cast", facing, active_cast_total)
	resources_changed.emit()
	return true

func cancel_active_cast() -> bool:
	spiritualist_channel_interrupt_requested.emit()
	if active_cast_skill == &"":
		return false
	active_cast_skill = &""
	active_cast_remaining = 0.0
	active_cast_total = 0.0
	_active_cast_target_id = 0
	_active_geometer_command = null
	presentation_action.emit(&"cast_cancel", _active_cast_direction, 0.0)
	resources_changed.emit()
	return true

func has_active_cast() -> bool:
	return active_cast_skill != &""

func skill_cast_time(skill_id: StringName) -> float:
	var rank_definition := _runtime_rank_definition(skill_id)
	if rank_definition != null:
		return StatCalculator.effective_cast_time(rank_definition.fixed_cast_time, rank_definition.variable_cast_time, stat_breakdown)
	var definition := ClassCatalog.skill_definition(skill_id)
	if definition != null and not definition.ranks.is_empty():
		return 0.0
	return StatCalculator.effective_cast_time(0.0, definition.cast_time, stat_breakdown) if definition != null else 0.0

func teleport_destination(point: Vector2) -> Vector2:
	var offset := point - global_position
	var maximum_range := skill_range(&"teleport")
	if offset.length() > maximum_range:
		offset = offset.normalized() * maximum_range
	return global_position + offset

func can_teleport(point: Vector2) -> bool:
	return not is_rooted() and skill_range(&"teleport") > 0.0 and navigation != null and navigation.is_walkable(teleport_destination(point))

func use_teleport(point: Vector2) -> bool:
	if class_id != &"mage" or not _can_spend(&"teleport") or not can_teleport(point):
		return false
	var destination := teleport_destination(point)
	var facing := _resolved_facing(global_position.direction_to(destination))
	_spend(&"teleport")
	global_position = destination
	_path.clear()
	_has_path_goal = false
	velocity = Vector2.ZERO
	target = null
	_attack_engaged = false
	_attack_recovery = 0.0
	_repath_time = 0.0
	presentation_action.emit(&"teleport", facing, 0.12)
	resources_changed.emit()
	return true

func can_target_skill(skill_id: StringName, enemy: CombatActor) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return false
	if global_position.distance_to(enemy.global_position) > skill_range(skill_id):
		return false
	return skill_id not in [&"brutal_strike", &"berserker_rupture", &"berserker_execution", &"berserker_breath_steal", &"spiritualist_echo_curse", &"spiritualist_soul_drain", &"spiritualist_procession", &"hunter_mark"] or (navigation != null and navigation.is_segment_clear(global_position, enemy.global_position, 0.0))

func aim_direction(point: Vector2) -> Vector2:
	var direction := global_position.direction_to(point)
	return _last_facing if direction.is_zero_approx() else direction

func arrow_rain_center(point: Vector2) -> Vector2:
	var offset := point - global_position
	var maximum_range := skill_range(&"arrow_rain")
	if offset.length() > maximum_range:
		offset = offset.normalized() * maximum_range
	return global_position + offset

func dash_destination(direction: Vector2) -> Vector2:
	if is_rooted():
		return global_position
	return navigation.move_until_blocked(global_position, global_position + direction.normalized() * skill_range(&"dash"))

func skill_cooldown(skill_id: StringName) -> float:
	if is_hunter() and skill_id in [&"foliage_shelter", &"hunter_total_cover"]:
		return maxf(mage_cooldowns.get(&"foliage_shelter", 0.0), mage_cooldowns.get(&"hunter_total_cover", 0.0))
	if skill_id == &"slash":
		return slash_cooldown
	if skill_id == &"dash":
		return dash_cooldown
	return mage_cooldowns.get(skill_id, 0.0)

func skill_cost(skill_id: StringName) -> float:
	var rank_definition := _runtime_rank_definition(skill_id)
	if rank_definition != null:
		return rank_definition.sp_cost
	var definition := ClassCatalog.skill_definition(skill_id)
	if definition != null and not definition.ranks.is_empty():
		return 0.0
	return definition.sp_cost if definition != null else 0.0

func skill_range(skill_id: StringName) -> float:
	var rank_definition := _runtime_rank_definition(skill_id)
	if rank_definition != null:
		return (rank_definition.range + _extended_aim_bonus(skill_id)) * sentinel_range_multiplier()
	var definition := ClassCatalog.skill_definition(skill_id)
	if definition != null and not definition.ranks.is_empty():
		return 0.0
	return definition.range if definition != null else 0.0

func skill_projectile_speed(skill_id: StringName) -> float:
	var rank_definition := _runtime_rank_definition(skill_id)
	if rank_definition != null:
		return rank_definition.projectile_speed
	var definition := ClassCatalog.skill_definition(skill_id)
	if definition != null and not definition.ranks.is_empty():
		return 0.0
	return definition.projectile_speed if definition != null else 0.0

func skill_rank(skill_id: StringName) -> int:
	return int(run_state.skill_levels.get(skill_id, 0)) if run_state != null else 0

func skill_rank_definition(skill_id: StringName) -> SkillRankDefinition:
	var definition := _runtime_rank_definition(skill_id)
	return definition.duplicate(true) as SkillRankDefinition if definition != null else null

func _capture_rank_definitions() -> void:
	_rank_definitions.clear()
	_effect_rank_cache.clear()
	_effect_rank_revision = -1
	for skill_id: StringName in run_state.skill_levels:
		var catalog_definition := ClassCatalog.skill_definition(skill_id)
		if catalog_definition == null or catalog_definition.ranks.is_empty():
			continue
		var rank_definition := catalog_definition.rank_definition(skill_rank(skill_id))
		if rank_definition != null:
			_rank_definitions[skill_id] = rank_definition

func _runtime_rank_definition(skill_id: StringName) -> SkillRankDefinition:
	if run_state != null and _rank_definitions.has(skill_id):
		var revision := run_state.composition_revision()
		if revision != _effect_rank_revision:
			_effect_rank_cache.clear()
			_effect_rank_revision = revision
		if not _effect_rank_cache.has(skill_id):
			var captured := run_state.skill_effect_capture(skill_id)
			_effect_rank_cache[skill_id] = captured["rank_definition"] if captured["ok"] else null
		return _effect_rank_cache[skill_id]
	return _rank_definitions.get(skill_id)

func _process(delta: float) -> void:
	if is_sentinel() and is_alive() and not (is_inside_tree() and get_tree().paused):
		if _sentinel_last_position.is_finite() and _sentinel_last_position.distance_to(global_position) > SentinelFocusState.MOVEMENT_EPSILON:
			sentinel_state.stable_time = 0.0
			_set_sentinel_stance(false)
		var previous := global_position
		_advance_player(delta)
		var moved := previous.distance_to(global_position) > SentinelFocusState.MOVEMENT_EPSILON or (_sentinel_last_position.is_finite() and _sentinel_last_position.distance_to(previous) > SentinelFocusState.MOVEMENT_EPSILON)
		sentinel_state.advance(delta, moved, sentinel_combat_active)
		_sentinel_last_position = global_position
		var has_stance := run_state.build_snapshot.has_passive(&"sentinel_precision_stance")
		_set_sentinel_stance(has_stance and sentinel_state.stable_time >= SentinelFocusState.STANCE_DELAY)
		if sentinel_state.observed_target_id > 0:
			var observed := instance_from_id(sentinel_state.observed_target_id) as CombatActor
			if not is_instance_valid(observed) or not observed.is_alive():
				sentinel_state.clear_observation()
		queue_redraw()
	else:
		_advance_player(delta)

func _advance_player(delta: float) -> void:
	super._process(delta)
	if not is_alive():
		velocity = Vector2.ZERO
		return
	var simulation_paused := is_inside_tree() and get_tree().paused
	if simulation_paused:
		return
	if is_hunter():
		var had_step := hunter_state.step_remaining > 0.0
		hunter_state.advance(delta)
		hunter_cover.advance(delta, global_position)
		concealment_reveal_remaining = hunter_cover.reveal_remaining
		if had_step and hunter_state.step_remaining <= 0.0:
			_apply_derived_stats(_build_stat_breakdown())
			resources_changed.emit()
	berserker_pursuit_cooldown = maxf(0.0, berserker_pursuit_cooldown - delta)
	elementalist_focus_cooldown = maxf(0.0, elementalist_focus_cooldown - delta)
	spiritualist_recovery_cooldown = maxf(0.0, spiritualist_recovery_cooldown - delta)
	spiritualist_focus_remaining = maxf(0.0, spiritualist_focus_remaining - delta)
	if spiritualist_focus_remaining <= 0.0:
		spiritualist_focus_power = 0.0
	for target_id: int in elementalist_focus_history.keys():
		var focus: Dictionary = elementalist_focus_history[target_id]
		focus["remaining"] = maxf(0.0, float(focus["remaining"]) - delta)
		if float(focus["remaining"]) <= 0.0:
			elementalist_focus_history.erase(target_id)
		else:
			elementalist_focus_history[target_id] = focus
	for target_id: int in elementalist_resonance_history.keys():
		var resonance: Dictionary = elementalist_resonance_history[target_id]
		resonance["remaining"] = maxf(0.0, float(resonance["remaining"]) - delta)
		if float(resonance["remaining"]) <= 0.0:
			elementalist_resonance_history.erase(target_id)
		else:
			elementalist_resonance_history[target_id] = resonance
	for target_id: int in berserker_wounds.keys():
		var wound: Dictionary = berserker_wounds[target_id]
		wound["remaining"] = maxf(0.0, float(wound["remaining"]) - delta)
		if wound["remaining"] <= 0.0:
			berserker_wounds.erase(target_id)
		else:
			berserker_wounds[target_id] = wound
	defender_token_notice_remaining = maxf(0.0, defender_token_notice_remaining - delta)
	var token_was_active := defender_token_remaining > 0.0
	defender_token_remaining = maxf(0.0, defender_token_remaining - delta)
	if token_was_active and defender_token_remaining <= 0.0:
		_set_defender_token_notice("TOKEN EXPIROU")
	defender_counter_guard_remaining = maxf(0.0, defender_counter_guard_remaining - delta)
	if defender_token_remaining > 0.0 or defender_counter_guard_remaining > 0.0 or defender_advance_guard_active:
		queue_redraw()
	defender_guard_return_cooldown = maxf(0.0, defender_guard_return_cooldown - delta)
	if defender_anchor_remaining > 0.0:
		defender_anchor_remaining = maxf(0.0, defender_anchor_remaining - delta)
		if defender_anchor_remaining <= 0.0:
			defender_anchor_center = Vector2.INF
			_update_defender_anchor_presence()
	if navigation != null and _navigation_revision != navigation.revision:
		_navigation_revision = navigation.revision
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
		if target == null and _has_path_goal:
			_set_path(_path_goal)
	if has_shield_stance():
		shield_remaining = maxf(0.0, shield_remaining - delta)
		if shield_remaining <= 0.0:
			clear_shield_stance()
		else:
			queue_redraw()
	if perseverance_remaining > 0.0:
		perseverance_remaining = maxf(0.0, perseverance_remaining - delta)
		if perseverance_remaining <= 0.0:
			clear_perseverance()
		else:
			queue_redraw()
	if piercing_shout_visual_time > 0.0:
		piercing_shout_visual_time = maxf(0.0, piercing_shout_visual_time - delta)
		queue_redraw()
	if fury_remaining > 0.0:
		if delta >= fury_remaining:
			clear_fury()
		else:
			fury_remaining -= delta
			queue_redraw()
	if brutal_strike_visual_time > 0.0:
		brutal_strike_visual_time = maxf(0.0, brutal_strike_visual_time - delta)
		queue_redraw()
	if concentrated_rage_visual_time > 0.0:
		concentrated_rage_visual_time = maxf(0.0, concentrated_rage_visual_time - delta)
		queue_redraw()
	if terrifying_shout_visual_time > 0.0:
		terrifying_shout_visual_time = maxf(0.0, terrifying_shout_visual_time - delta)
		queue_redraw()
	_regenerate_sp(delta, false)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_attack_recovery = maxf(0.0, _attack_recovery - delta)
	slash_cooldown = maxf(0.0, slash_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	for skill_id: StringName in mage_cooldowns:
		mage_cooldowns[skill_id] = maxf(0.0, mage_cooldowns[skill_id] - delta)
	if extended_aim_remaining > 0.0:
		var previous_extended_aim := extended_aim_remaining
		extended_aim_remaining = maxf(0.0, extended_aim_remaining - delta)
		if previous_extended_aim > 0.0 and extended_aim_remaining <= 0.0:
			resources_changed.emit()
		queue_redraw()
	if not is_hunter() and concealment_reveal_remaining > 0.0:
		concealment_reveal_remaining = maxf(0.0, concealment_reveal_remaining - delta)
		queue_redraw()
	if _slash_visual_time > 0.0:
		_slash_visual_time = maxf(0.0, _slash_visual_time - delta)
		queue_redraw()
	if _basic_visual_time > 0.0:
		_basic_visual_time = maxf(0.0, _basic_visual_time - delta)
		queue_redraw()
	if has_active_cast():
		_advance_active_cast(delta)
		return
	if _dash_active:
		if is_rooted():
			_stop_dash()
			return
		_advance_dash(delta)
		return
	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		target = null
		_attack_engaged = false
		_path.clear()
	if target != null:
		_repath_time -= delta
		if can_basic_attack(target, _attack_engaged):
			_attack_engaged = true
			_path.clear()
			velocity = Vector2.ZERO
			_try_basic_attack()
			return
		elif _attack_recovery > 0.0:
			_path.clear()
			velocity = Vector2.ZERO
			return
		else:
			_attack_engaged = false
			if _repath_time <= 0.0 or _path_index >= _path.size():
				_set_path(target.global_position)
				_repath_time = 0.22
	_move_along_path(delta)
	if target != null and can_basic_attack(target, _attack_engaged):
		_attack_engaged = true
		_path.clear()
		velocity = Vector2.ZERO
		_try_basic_attack()

func _advance_active_cast(delta: float) -> void:
	active_cast_remaining = maxf(0.0, active_cast_remaining - delta)
	if active_cast_remaining > 0.0:
		return
	var completed_skill := active_cast_skill
	var completed_point := _active_cast_point
	var completed_target_id := _active_cast_target_id
	var completed_geometer_command := _active_geometer_command
	active_cast_skill = &""
	active_cast_total = 0.0
	_active_cast_target_id = 0
	_active_geometer_command = null
	resources_changed.emit()
	if completed_geometer_command != null:
		geometer_cast_ready.emit(completed_geometer_command)
	else:
		skill_cast_ready.emit(completed_skill, completed_point, completed_target_id)

func _advance_dash(delta: float) -> void:
	var previous_position := global_position
	var distance := global_position.distance_to(_dash_endpoint)
	if distance <= MOVEMENT_EPSILON:
		global_position = _dash_endpoint
		_stop_dash()
		_update_defender_anchor_presence()
		return
	var next_position := global_position.move_toward(_dash_endpoint, _dash_speed * delta)
	var safe_position := navigation.move_until_blocked(global_position, next_position)
	global_position = safe_position
	_try_defender_advance_hit(previous_position, global_position)
	_try_berserker_leap_hit(previous_position, global_position)
	_update_defender_anchor_presence()
	if safe_position.distance_to(next_position) > MOVEMENT_EPSILON or global_position.distance_to(_dash_endpoint) <= MOVEMENT_EPSILON:
		global_position = safe_position if safe_position.distance_to(next_position) > MOVEMENT_EPSILON else _dash_endpoint
		_stop_dash()
		_update_defender_anchor_presence()

func _stop_dash() -> void:
	_dash_active = false
	defender_advance_guard_active = false
	_defender_advance_targets.clear()
	_defender_advance_hit = false
	_berserker_leap_active = false
	_berserker_leap_targets.clear()
	_berserker_leap_hit = false
	velocity = Vector2.ZERO

func _try_defender_advance_hit(from: Vector2, to: Vector2) -> void:
	if not defender_advance_guard_active or _defender_advance_hit or from.distance_to(to) <= MOVEMENT_EPSILON:
		return
	var definition := ClassCatalog.skill_definition(&"defender_wall_advance")
	var rank_definition := _runtime_rank_definition(&"defender_wall_advance")
	for enemy: CombatActor in _defender_advance_targets:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if closest.distance_to(enemy.global_position) > collision_radius + enemy.collision_radius:
			continue
		_defender_advance_hit = true
		var request := _make_physical_request(enemy, &"defender_wall_advance", stat_breakdown.value(&"melee_attack") * rank_definition.power, definition.accuracy_mode, definition.can_crit)
		defender_hit_requested.emit(request, enemy, 0.0, defender_advance_guard_facing)
		return

func _try_berserker_leap_hit(from: Vector2, to: Vector2) -> void:
	if not _berserker_leap_active or _berserker_leap_hit or from.distance_to(to) <= MOVEMENT_EPSILON:
		return
	var chosen: CombatActor
	var chosen_distance := INF
	for enemy: CombatActor in _berserker_leap_targets:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, from, to)
		if closest.distance_to(enemy.global_position) > collision_radius + enemy.collision_radius or not navigation.is_segment_clear(from, enemy.global_position, 0.0):
			continue
		var along := from.distance_to(closest)
		if along < chosen_distance:
			chosen = enemy
			chosen_distance = along
	if chosen == null:
		return
	_berserker_leap_hit = true
	var definition := ClassCatalog.skill_definition(&"berserker_wound_leap")
	var rank_definition := _runtime_rank_definition(&"berserker_wound_leap")
	var request := _make_physical_request(chosen, &"berserker_wound_leap", stat_breakdown.value(&"melee_attack") * rank_definition.power, definition.accuracy_mode, definition.can_crit)
	attack_requested.emit(request, chosen)

func _regenerate_sp(delta: float, simulation_paused: bool) -> bool:
	if simulation_paused or delta <= 0.0 or not is_alive() or sp_deficit() <= 0.0:
		return false
	var previous_sp := current_sp
	recover_sp(stat_breakdown.value(&"sp_regen") * delta)
	if is_equal_approx(previous_sp, current_sp):
		return false
	resources_changed.emit()
	return true

func regenerate_hp(delta: float, encounter_active: bool, simulation_paused: bool) -> bool:
	if encounter_active or simulation_paused or delta <= 0.0 or not is_alive() or health.current_hp >= health.max_hp:
		return false
	var previous_hp := health.current_hp
	health.heal(stat_breakdown.value(&"hp_regen") * delta)
	if is_equal_approx(previous_hp, health.current_hp):
		return false
	resources_changed.emit()
	queue_redraw()
	return true

func heal_from_kill() -> float:
	if not is_alive() or run_state == null or not run_state.build_snapshot.has_passive(&"blood_thirst"):
		return 0.0
	var rank := int(run_state.skill_levels.get(&"blood_thirst", 0))
	var fraction := ClassCatalog.blood_thirst_heal_fraction(rank)
	if fraction <= 0.0:
		return 0.0
	var previous_hp := health.current_hp
	health.heal(health.max_hp * fraction)
	var healed := health.current_hp - previous_hp
	if healed > 0.0:
		resources_changed.emit()
		queue_redraw()
	return healed

func _try_basic_attack() -> void:
	if not run_state.effect_ledger.can_create_root() or not has_projectile_capacity(&"basic_attack"):
		return
	if is_sentinel() and _sentinel_last_launch_frame == Engine.get_process_frames():
		return
	if target == null or attack_cooldown > 0.0 or not can_basic_attack(target, _attack_engaged):
		return
	if is_sentinel() and sentinel_state.explosive_prepared:
		_launch_sentinel_explosive(target)
		return
	_begin_effect_emission()
	_commit_action(SkillDefinition.ActionKind.OFFENSIVE)
	_last_facing = global_position.direction_to(target.global_position)
	attack_cooldown = 1.0 / attacks_per_second()
	_attack_recovery = BASIC_ATTACK_RECOVERY
	_basic_visual_time = BASIC_ATTACK_RECOVERY
	_basic_facing = _last_facing
	_basic_origin = global_position + Vector2(0, -18)
	_basic_visual_radius = maxf(12.0, global_position.distance_to(target.global_position))
	reveal_from_offense()
	queue_redraw()
	var request: DamageRequest
	if is_mage():
		request = _make_magic_request(target, &"basic_attack", stat_breakdown.value(&"magic_attack") * class_definition.basic_power, DamageRequest.AccuracyMode.CONTESTED, true)
	elif is_archer():
		request = _make_physical_request(target, &"basic_attack", stat_breakdown.value(&"precision_attack") * class_definition.basic_power, DamageRequest.AccuracyMode.CONTESTED, true)
	else:
		request = _make_physical_request(target, &"basic_attack", stat_breakdown.value(&"melee_attack") * class_definition.basic_power, DamageRequest.AccuracyMode.CONTESTED, true)
	if is_mage():
		mage_projectile_requested.emit(&"basic_attack", request, target, _last_facing, 1)
	elif is_archer():
		precision_projectile_requested.emit(&"basic_attack", request, target, _last_facing, 1, 1)
	else:
		attack_requested.emit(request, target)
	presentation_action.emit(&"basic_attack", _last_facing, BASIC_ATTACK_RECOVERY)

func _make_request(enemy: CombatActor, skill_id: StringName, accuracy_mode: DamageRequest.AccuracyMode, can_crit: bool) -> DamageRequest:
	var request := DamageRequest.new()
	request.context = _emission_context.copy_context() if _emission_context != null else null
	var composed := run_state.composed_build()
	request.effect_snapshot = {"procs": composed.get("procs", []).duplicate(true), "build_version": run_state.build_snapshot.build_version}
	request.source_id = get_instance_id()
	request.target_id = enemy.get_instance_id() if enemy != null else 0
	request.skill_id = skill_id
	request.accuracy_mode = accuracy_mode
	request.hit_rating = stat_breakdown.value(&"hit_rating")
	request.crit_chance = stat_breakdown.value(&"crit_chance")
	request.crit_multiplier = stat_breakdown.value(&"crit_multiplier")
	request.damage_dealt_multiplier = outgoing_damage_multiplier()
	request.can_crit = can_crit
	request.emission_id = int(_emission_context.root_event_id.get_slice(":", _emission_context.root_event_id.get_slice_count(":") - 1)) if _emission_context != null else _next_fixture_emission_id()
	if is_hunter() and skill_id in HunterOpeningState.BOW_SKILLS:
		var build := run_state.build_snapshot
		if build.has_passive(&"hunter_shooting_discipline"):
			request.hunter_precision_damage = HunterMath.discipline_raw(skill_rank(&"hunter_shooting_discipline"), stat_breakdown)
		if build.has_passive(&"hunter_easy_prey"):
			request.hunter_easy_prey_bonus = HunterMath.easy_prey_bonus(skill_rank(&"hunter_easy_prey"))
	return request

func _make_physical_request(enemy: CombatActor, skill_id: StringName, power: float, accuracy_mode: DamageRequest.AccuracyMode, can_crit: bool) -> DamageRequest:
	var request := _make_request(enemy, skill_id, accuracy_mode, can_crit)
	request.physical_damage = power
	if _is_berserker() and skill_id in BERSERKER_DIRECT_MELEE_IDS and run_state.build_snapshot.has_passive(&"berserker_obstinacy") and health.current_hp <= health.max_hp * 0.50:
		var rank_definition := _runtime_rank_definition(&"berserker_obstinacy")
		if rank_definition != null:
			request.damage_dealt_multiplier *= 1.0 + rank_definition.power
	return request

func _make_magic_request(enemy: CombatActor, skill_id: StringName, power: float, accuracy_mode: DamageRequest.AccuracyMode, can_crit: bool) -> DamageRequest:
	var request := _make_request(enemy, skill_id, accuracy_mode, can_crit)
	request.magic_damage = power
	if _is_elementalist() and run_state.build_snapshot.has_passive(&"elementalist_prismatic_resonance"):
		var resonance_rank := _runtime_rank_definition(&"elementalist_prismatic_resonance")
		if resonance_rank != null:
			request.prismatic_resonance_damage = stat_breakdown.value(&"magic_attack") * resonance_rank.power
	return request

func _magic_power(skill_id: StringName) -> float:
	var rank_definition := _runtime_rank_definition(skill_id)
	var definition := ClassCatalog.skill_definition(skill_id)
	var power := rank_definition.power if rank_definition != null else definition.power
	return stat_breakdown.value(&"magic_attack") * power

func _can_spend(skill_id: StringName) -> bool:
	var definition := ClassCatalog.skill_definition(skill_id)
	var has_runtime_definition := definition != null and (definition.ranks.is_empty() or _runtime_rank_definition(skill_id) != null)
	return run_state.effect_ledger.can_create_root() and run_state.effects_valid() and has_projectile_capacity(skill_id) and has_runtime_definition and skill_id in available_skill_ids() and is_alive() and skill_cooldown(skill_id) <= 0.0 and sentinel_free_sp() >= skill_cost(skill_id)

func _spend(skill_id: StringName) -> void:
	_begin_effect_emission()
	var definition := ClassCatalog.skill_definition(skill_id)
	var rank_definition := _runtime_rank_definition(skill_id)
	var cost := rank_definition.sp_cost if rank_definition != null else definition.sp_cost
	var base_cooldown := rank_definition.cooldown if rank_definition != null else definition.cooldown
	_sp_deficit += cost
	var cooldown := SentinelMath.cooldown(skill_id, base_cooldown, stat_breakdown) if is_sentinel() else StatCalculator.effective_cooldown(base_cooldown, stat_breakdown)
	if skill_id == &"slash":
		slash_cooldown = cooldown
	elif skill_id == &"dash":
		dash_cooldown = cooldown
	else:
		mage_cooldowns[skill_id] = cooldown
	if is_hunter() and skill_id in [&"foliage_shelter", &"hunter_total_cover"]:
		var shared_cooldown := StatCalculator.effective_cooldown(HunterTuning.COVER_COOLDOWN, stat_breakdown)
		mage_cooldowns[&"foliage_shelter"] = shared_cooldown
		mage_cooldowns[&"hunter_total_cover"] = shared_cooldown

func _resolved_facing(direction: Vector2) -> Vector2:
	var facing := direction.normalized()
	if facing.is_zero_approx():
		facing = _last_facing
	_last_facing = facing
	return facing

func _set_path(point: Vector2) -> void:
	_path = navigation.get_path(global_position, point)
	_path_index = 0
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 0.01:
		_path_index += 1

func _move_along_path(delta: float) -> void:
	if is_rooted():
		velocity = Vector2.ZERO
		return
	var remaining_time := maxf(0.0, delta)
	while remaining_time > 0.0:
		var step := minf(MAX_MOVEMENT_STEP, remaining_time)
		_move_step(step)
		remaining_time = maxf(0.0, remaining_time - step)

func _move_step(delta: float) -> void:
	var desired_velocity := Vector2.ZERO
	var offset := Vector2.ZERO
	var has_destination := _path_index < _path.size()
	if has_destination:
		for index: int in range(_path.size() - 1, _path_index, -1):
			if navigation.is_segment_walkable(global_position, _path[index]):
				_path_index = index
				break
		offset = _path[_path_index] - global_position
		var desired_speed := minf(stat_breakdown.value(&"move_speed") * movement_speed_multiplier(), sqrt(2.0 * MOVE_FRICTION * offset.length()))
		desired_velocity = offset.normalized() * desired_speed
	var previous_velocity := velocity
	var acceleration := MOVE_FRICTION if desired_velocity.length() < velocity.length() else MOVE_ACCELERATION
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	var displacement := (previous_velocity + velocity) * 0.5 * delta
	var desired_position := global_position + displacement
	var reaches_waypoint := false
	if has_destination:
		reaches_waypoint = offset.length() <= ARRIVAL_TOLERANCE or (displacement.length() >= offset.length() and displacement.normalized().dot(offset.normalized()) > 0.99)
		if reaches_waypoint:
			desired_position = _path[_path_index]
	var safe_position := navigation.move_until_blocked(global_position, desired_position)
	var previous_position := global_position
	global_position = safe_position
	if is_sentinel() and global_position.distance_to(previous_position) > SentinelFocusState.MOVEMENT_EPSILON:
		_set_sentinel_stance(false)
	_update_defender_anchor_presence()
	if safe_position.distance_to(desired_position) > MOVEMENT_EPSILON:
		velocity = Vector2.ZERO
		if has_destination:
			_set_path(_path[-1])
		return
	if reaches_waypoint:
		_path_index += 1
		if _path_index >= _path.size():
			velocity = Vector2.ZERO
			_has_path_goal = false
	if not velocity.is_zero_approx():
		_last_facing = velocity.normalized()

func _on_health_died(actor_id: int) -> void:
	clear_sentinel_state()
	clear_hunter_state()
	cancel_active_cast()
	clear_shield_stance()
	clear_perseverance()
	clear_fury()
	clear_defender_state()
	clear_elementalist_state()
	brutal_strike_visual_time = 0.0
	concentrated_rage_visual_time = 0.0
	terrifying_shout_visual_time = 0.0
	piercing_shout_visual_time = 0.0
	extended_aim_remaining = 0.0
	clear_foliage_shelters()
	velocity = Vector2.ZERO
	_path.clear()
	_has_path_goal = false
	target = null
	_stop_dash()
	_attack_recovery = 0.0
	super._on_health_died(actor_id)

func basic_attack_distance(enemy: CombatActor) -> float:
	return collision_radius + enemy.collision_radius + (class_definition.basic_range + _extended_aim_bonus(&"basic_attack")) * sentinel_range_multiplier()

func archer_basic_projectile_range() -> float:
	return (ARCHER_BASIC_MAX_DISTANCE + _extended_aim_bonus(&"basic_attack")) * sentinel_range_multiplier()

func has_extended_aim() -> bool:
	return is_archer() and extended_aim_remaining > 0.0

func _extended_aim_bonus(skill_id: StringName) -> float:
	if not has_extended_aim() or skill_id not in [&"basic_attack", &"double_shot", &"piercing_arrow", &"arrow_rain", &"slowing_arrow"]:
		return 0.0
	return EXTENDED_AIM_RANGE_BONUS

func can_basic_attack(enemy: CombatActor, retain: bool = false) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return false
	var allowed_distance := basic_attack_distance(enemy) + (ATTACK_RETENTION if retain else 0.0)
	return global_position.distance_to(enemy.global_position) <= allowed_distance and navigation.is_segment_clear(global_position, enemy.global_position, 0.0)

func temporary_stat_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if is_hunter() and hunter_state.step_remaining > 0.0:
		sources.append(HunterMath.step_source())
	if is_sentinel() and _sentinel_stance_active:
		var stance := SentinelMath.stance_source(skill_rank(&"sentinel_precision_stance"))
		if not stance.is_empty():
			sources.append(stance)
	if fury_remaining > 0.0:
		var source := ClassCatalog.active_modifier_source(&"fury", _runtime_rank_definition(&"fury"))
		if not source.is_empty():
			sources.append(source)
	if _defender_inside_anchor and has_defender_anchor():
		sources.append({"source_id": &"defender_anchor", "label": "Marco de Guarda", "increased": {&"physical_defense": DEFENDER_ANCHOR_DEFENSE_BONUS, &"magic_defense": DEFENDER_ANCHOR_DEFENSE_BONUS}})
	return sources

func _build_stat_breakdown() -> StatBreakdown:
	var sources := run_state.stat_modifier_sources()
	sources.append_array(temporary_stat_sources())
	return run_state.build_snapshot.stat_breakdown(sources)

func sp_deficit() -> float:
	return _sp_deficit

func recover_sp(amount: float) -> float:
	if not is_alive() or not is_finite(amount) or amount <= 0.0:
		return 0.0
	var recovered := minf(amount, _sp_deficit)
	_sp_deficit -= recovered
	return recovered

func resource_state() -> Dictionary:
	return {"hp_deficit": health.hp_deficit(), "sp_deficit": sp_deficit(), "temporary_sources": temporary_stat_sources()}

func _draw() -> void:
	super._draw()
	if is_sentinel():
		var aim_size := lerpf(15.0, 8.0, clampf(sentinel_state.stable_time / SentinelFocusState.STANCE_DELAY, 0.0, 1.0))
		if sentinel_state.absolute_remaining > 0.0:
			draw_arc(Vector2(0, -18), 25.0, -PI * 0.8, PI * 0.2, 24, Color("a6e3ee", 0.75), 1.5, true)
		if sentinel_state.explosive_prepared:
			draw_colored_polygon(PackedVector2Array([Vector2(20, -22), Vector2(24, -18), Vector2(20, -14), Vector2(16, -18)]), Color("ffbf69"))
		for side: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var point := Vector2(0, -22) + side * aim_size
			draw_line(point, point - side * 3.0, Color("b4decb", 0.65), 1.0)
		if sentinel_state.observed_target_id > 0:
			var observed := instance_from_id(sentinel_state.observed_target_id) as CombatActor
			if is_instance_valid(observed) and observed.is_alive():
				var point := to_local(observed.global_position) + Vector2(0, -40)
				draw_arc(point, 7.0, 0.0, TAU, 16, Color("b4decb"), 1.5)
				for index: int in sentinel_state.observation_charges:
					draw_line(point + Vector2(-5 + index * 5, -12), point + Vector2(-5 + index * 5, -9), Color("b4decb"), 2.0)
	if has_defender_token():
		draw_arc(Vector2(0, -18), collision_radius + 25.0, 0.0, TAU, 40, Color("f5cc77", 0.75), 2.0, true)
	if defender_counter_guard_remaining > 0.0:
		var angle := defender_counter_guard_facing.angle()
		draw_arc(Vector2(0, -18), SHIELD_RADIUS + 15.0, angle - SkillGeometry.DEFENDER_GUARD_HALF_ANGLE, angle + SkillGeometry.DEFENDER_GUARD_HALF_ANGLE, 26, Color("f5cc77", 0.92), 4.0, true)
	elif defender_advance_guard_active:
		var angle := defender_advance_guard_facing.angle()
		draw_arc(Vector2(0, -18), SHIELD_RADIUS + 15.0, angle - SkillGeometry.DEFENDER_GUARD_HALF_ANGLE, angle + SkillGeometry.DEFENDER_GUARD_HALF_ANGLE, 26, Color("7bd5e5", 0.92), 4.0, true)
	if terrifying_shout_visual_time > 0.0:
		var progress := 1.0 - terrifying_shout_visual_time / 0.28
		draw_arc(Vector2(0, -18), lerpf(20.0, skill_range(&"terrifying_shout"), progress), 0.0, TAU, 48, Color(0.70, 0.44, 0.90, 1.0 - progress), 4.0, true)
	if concentrated_rage_visual_time > 0.0:
		var origin := concentrated_rage_visual_origin - global_position
		var endpoint := origin + concentrated_rage_visual_direction * concentrated_rage_visual_range
		draw_line(origin, endpoint, Color(1.0, 0.51, 0.31, concentrated_rage_visual_time / 0.22), CONCENTRATED_RAGE_HALF_WIDTH * 2.0, true)
	if brutal_strike_visual_time > 0.0:
		draw_line(Vector2(0, -18), brutal_strike_visual_point - global_position + Vector2(0, -18), Color(1.0, 0.48, 0.33, brutal_strike_visual_time / 0.20), 6.0, true)
	if fury_remaining > 0.0:
		draw_circle(Vector2(0, -18), collision_radius + 12.0, Color(0.95, 0.29, 0.13, 0.10))
		draw_arc(Vector2(0, -18), collision_radius + 12.0, 0.0, TAU, 32, Color("f7784b"), 2.5, true)
	if piercing_shout_visual_time > 0.0:
		var progress := 1.0 - piercing_shout_visual_time / 0.25
		draw_arc(Vector2(0, -18), lerpf(20.0, skill_range(&"piercing_shout"), progress), 0.0, TAU, 48, Color(0.96, 0.68, 0.42, 1.0 - progress), 4.0, true)
	if perseverance_remaining > 0.0 and health != null and health.shield_hp > 0.0:
		draw_circle(Vector2(0, -18), collision_radius + 8.0, Color(0.53, 0.80, 0.97, 0.09))
		draw_arc(Vector2(0, -18), collision_radius + 8.0, 0.0, TAU, 32, Color("a7dbfb"), 2.0, true)
	if has_shield_stance():
		var center := Vector2(0, -18)
		var shield_angle := shield_facing.angle()
		var ratio := float(shield_resistance) / 6.0
		draw_arc(center, SHIELD_RADIUS + 5.0, shield_angle - SHIELD_HALF_ANGLE, shield_angle + SHIELD_HALF_ANGLE, 26, Color(0.12, 0.28, 0.40, 0.72), 9.0, true)
		draw_arc(center, SHIELD_RADIUS, shield_angle - SHIELD_HALF_ANGLE, shield_angle + SHIELD_HALF_ANGLE, 26, Color(0.53, 0.78, 0.96, 0.75 + ratio * 0.20), 5.0, true)
		for offset_angle: float in [-0.55, 0.0, 0.55]:
			var angle := shield_angle + offset_angle
			var marker := center + Vector2.from_angle(angle) * SHIELD_RADIUS
			draw_circle(marker, 3.5, Color(0.87, 0.95, 1.0, 0.88))
	if is_concealed():
		draw_circle(Vector2(0, -18), collision_radius + 10.0, Color(0.20, 0.48, 0.22, 0.12))
		draw_arc(Vector2(0, -18), collision_radius + 10.0, 0.0, TAU, 36, Color(0.48, 0.78, 0.38, 0.85), 2.0, true)
	if has_extended_aim():
		draw_circle(Vector2(0, -18), collision_radius + 13.0, Color(0.67, 0.89, 0.44, 0.10))
		draw_arc(Vector2(0, -18), collision_radius + 13.0, 0.0, TAU, 36, Color(0.75, 0.95, 0.50, 0.8), 2.0, true)
	if _basic_visual_time > 0.0 and class_id == &"swordsman":
		var swing_angle := _basic_facing.angle()
		draw_arc(_basic_origin - global_position, _basic_visual_radius, swing_angle - 0.65, swing_angle + 0.65, 16, Color(1.0, 0.89, 0.60, _basic_visual_time / BASIC_ATTACK_RECOVERY), 4.0)
	if _slash_visual_time > 0.0:
		var angle := _slash_facing.angle()
		draw_arc(_slash_origin - global_position, _slash_visual_range, angle - SLASH_HALF_ANGLE, angle + SLASH_HALF_ANGLE, 28, Color(0.91, 0.78, 0.48, _slash_visual_time * 3.5), 7.0)

func _next_fixture_emission_id() -> int:
	# Private request factories also serve isolated legacy fixtures without a paid action.
	_hunter_emission_serial += 1
	return _hunter_emission_serial

func _begin_effect_emission() -> void:
	_emission_context = run_state.effect_ledger.new_root(get_instance_id()) if run_state != null else null

func claim_effect_result(result: Dictionary, family: StringName, target_id: int, kit_recovery: bool = false) -> bool:
	var context: CombatEventContext = result.get("context")
	if context == null:
		return true # Legacy pure fixtures; live producers always supply a context.
	var ledger := context.ledger()
	if ledger == null:
		return false
	if result.has("_effect_claims"):
		var reserved := EffectProcLedger.take_result_claim(result, family, target_id)
		if reserved != null:
			return true
		if not (kit_recovery and context.secondary):
			return false
	if kit_recovery:
		return ledger.claim_kit_recovery(context, family, family, target_id)
	return not ledger.claim_batch(context, [{"family_id": family, "source_id": family, "target_id": target_id}]).is_empty()

func resolve_build_effect_procs(result: Dictionary) -> void:
	if not bool(result.get("can_trigger_effects", false)) or int(result.get("source_id", 0)) != get_instance_id() or not is_alive():
		return
	var context: CombatEventContext = result.get("context")
	if context == null or not context.is_active():
		return
	var target_id := int(result.get("target_id", 0))
	if not result.has("_effect_claims"):
		prepare_effect_claims(result)
	var claims: Array[Dictionary] = []
	for reserved: Dictionary in result.get("_effect_claims", []):
		if not reserved.get("build_proc", false):
			continue
		if EffectProcLedger.take_result_claim(result, reserved["family_id"], target_id) != null:
			claims.append(reserved)
	for claim: Dictionary in claims:
		var victim := instance_from_id(target_id) as CombatActor
		if not is_instance_valid(victim) or not victim.is_alive() or not is_alive():
			continue
		var request := DamageRequest.new()
		request.context = claim["context"]
		request.source_id = get_instance_id()
		request.target_id = target_id
		request.skill_id = claim["family_id"]
		request.emission_id = int(result.get("emission_id", 0))
		request.is_secondary = true
		request.can_crit = false
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		var magnitude := clampf(float(claim["flat"]) + float(result.get("actual_damage", 0.0)) * float(claim["increased"]), 0.0, float(claim["limit"]))
		if claim["axis"] == &"physical_damage":
			request.physical_damage = magnitude
		else:
			request.magic_damage = magnitude
		request.damage_dealt_multiplier = 1.0
		status_damage_requested.emit(request, victim)

func has_projectile_capacity(skill_id: StringName) -> bool:
	if not is_inside_tree():
		return true
	var projectile_skills: Array[StringName] = [&"basic_attack", &"fireball", &"fire_spear", &"ice_spear", &"lightning", &"electric_discharge", &"double_shot", &"piercing_arrow", &"slowing_arrow", &"hunter_covering_shot", &"sentinel_headshot", &"sentinel_piercing_shot", &"sentinel_concussion_shot", &"sentinel_net_shot", &"sentinel_explosive_shot", &"geometer_trace", &"geometer_triangulation"]
	if skill_id not in projectile_skills or (skill_id == &"basic_attack" and class_id == &"swordsman"):
		return true
	var needed := run_state.projectile_count(skill_id) if skill_id in BuildEffectCatalog.PROJECTILE_SKILLS else 1
	return EffectProcLedger.projectile_slots_available(get_tree(), needed)

func prepare_effect_claims(result: Dictionary, additional: Array[Dictionary] = []) -> void:
	if result.has("_effect_claims"):
		return
	var context: CombatEventContext = result.get("context")
	if context == null:
		return
	result["_effect_claims"] = []
	if not context.is_active() or context.secondary or not is_alive() or not bool(result.get("can_trigger_effects", false)) or int(result.get("source_id", 0)) != get_instance_id() or float(result.get("actual_damage", 0.0)) <= 0.0:
		return
	var candidates: Array[Dictionary] = additional.duplicate(true)
	var target_id := int(result.get("target_id", 0))
	var skill := StringName(result.get("skill_id", &""))
	var emission := int(result.get("emission_id", 0))
	for proc: Dictionary in result.get("effect_snapshot", {}).get("procs", []):
		if proc["trigger"] != EffectDefinition.Trigger.ON_HIT or (not proc["targets"].is_empty() and skill not in proc["targets"]):
			continue
		var candidate := proc.duplicate(true)
		candidate["target_id"] = target_id
		candidate["build_proc"] = true
		candidates.append(candidate)
	if is_sentinel() and not (is_inside_tree() and get_tree().paused):
		_append_kit_candidate(candidates, &"sentinel_focus", target_id)
	if is_hunter() and hunter_state.can_consume(result) and not (is_inside_tree() and get_tree().paused):
		_append_kit_candidate(candidates, &"hunter_exploit", target_id, &"hunter_opening")
	if _is_berserker():
		var previous := berserker_wound_stacks(target_id)
		var direct := skill in BERSERKER_DIRECT_MELEE_IDS and skill_rank(&"berserker_rupture") > 0 and (previous > 0 or skill == &"berserker_rupture")
		if direct:
			_append_kit_candidate(candidates, &"berserker_wound", target_id)
		if previous > 0 and (direct or skill == &"berserker_execution") and berserker_pursuit_cooldown <= 0.0 and run_state.build_snapshot.has_passive(&"berserker_pursuit"):
			_append_kit_candidate(candidates, &"berserker_pursuit", get_instance_id())
		if skill == &"berserker_breath_steal" and previous > 0 and not bool(result.get("killed", false)):
			_append_kit_candidate(candidates, &"berserker_breath_heal", target_id)
	if _is_elementalist():
		var element := _elementalist_direct_element(skill)
		var previous: Dictionary = elementalist_focus_history.get(target_id, {})
		if element != &"" and float(previous.get("remaining", 0.0)) > 0.0 and StringName(previous.get("element", &"")) != element and (emission <= 0 or not _elementalist_refunded_emissions.has(emission)) and elementalist_focus_cooldown <= 0.0 and run_state.build_snapshot.has_passive(&"elementalist_prismatic_focus"):
			_append_kit_candidate(candidates, &"elementalist_focus", get_instance_id())
	if _is_spiritualist() and skill == &"spiritualist_soul_drain":
		_append_kit_candidate(candidates, &"spiritualist_drain_heal", target_id)
	if bool(result.get("killed", false)) and run_state.build_snapshot.has_passive(&"blood_thirst"):
		_append_kit_candidate(candidates, &"blood_thirst", target_id)
	result["_effect_claims"] = context.ledger().claim_batch(context, candidates)

func _append_kit_candidate(candidates: Array[Dictionary], family: StringName, target_id: int, source: StringName = &"") -> void:
	candidates.append({"family_id": family, "source_id": family if source.is_empty() else source, "target_id": target_id})
