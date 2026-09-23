class_name PlayerActor
extends CombatActor

signal attack_requested(request: DamageRequest, target: CombatActor)
signal mage_projectile_requested(skill_id: StringName, request: DamageRequest, target: CombatActor, direction: Vector2, count: int)
signal discharge_requested(request: DamageRequest, direction: Vector2, bonus_magic_damage: float)
signal precision_projectile_requested(skill_id: StringName, request: DamageRequest, target: CombatActor, direction: Vector2, count: int, hit_limit: int)
signal arrow_rain_requested(center: Vector2, request: DamageRequest)
signal snare_trap_requested(center: Vector2, root_duration: float)
signal explosive_trap_requested(center: Vector2, request: DamageRequest)
signal slowing_arrow_requested(request: DamageRequest, direction: Vector2, slow_fraction: float, slow_duration: float)
signal foliage_shelter_requested(center: Vector2, duration: float)
signal fire_wall_requested(direction: Vector2, burn_request: DamageRequest)
signal lightning_wall_requested(direction: Vector2, request: DamageRequest)
signal skill_cast_ready(skill_id: StringName, point: Vector2, target_id: int)
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
const MAGE_BASIC_SPEED := 620.0
const MAGE_BASIC_MAX_DISTANCE := 420.0
const ARCHER_BASIC_SPEED := 880.0
const ARCHER_BASIC_MAX_DISTANCE := 520.0
const PIERCING_ARROW_MAX_HITS := 3
const EXTENDED_AIM_RANGE_BONUS := 120.0
const SLOWING_ARROW_SLOW_FRACTION := 0.35
const CONCEALMENT_REVEAL_DURATION := 1.25
const DISCHARGE_MARK_BONUS_WEIGHT := 0.45

var navigation: ArenaNavigation
var run_state: RunState
var class_id: StringName = &"swordsman"
var class_definition: ClassDefinition
var current_sp := 0.0
var max_sp := 0.0
var attack_cooldown := 0.0
var slash_cooldown := 0.0
var dash_cooldown := 0.0
var mage_cooldowns: Dictionary[StringName, float] = {}
var target: CombatActor
var velocity := Vector2.ZERO
var _path := PackedVector2Array()
var _path_index := 0
var _repath_time := 0.0
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
var active_cast_skill: StringName = &""
var active_cast_remaining := 0.0
var active_cast_total := 0.0
var extended_aim_remaining := 0.0
var concealment_reveal_remaining := 0.0
var _active_cast_point := Vector2.ZERO
var _active_cast_target_id: int = 0
var _active_cast_direction := Vector2.RIGHT
var _rank_definitions: Dictionary[StringName, SkillRankDefinition] = {}
var _foliage_shelters: Dictionary[int, Dictionary] = {}

func configure(nav: ArenaNavigation, state: RunState) -> void:
	navigation = nav
	run_state = state
	extended_aim_remaining = 0.0
	clear_foliage_shelters()
	class_id = run_state.class_id
	class_definition = ClassCatalog.class_definition(class_id)
	_capture_rank_definitions()
	var derived := _build_stat_breakdown()
	var class_color := Color("8e73de") if class_id == &"mage" else Color("6fa85a") if class_id == &"archer" else Color("55a8d9")
	setup(class_definition.display_name, class_color, derived, 20.0)
	set_animation_kind(class_id)
	max_sp = stat_breakdown.value(&"max_sp")
	current_sp = max_sp
	for skill_id: StringName in available_skill_ids():
		mage_cooldowns[skill_id] = 0.0
	process_mode = Node.PROCESS_MODE_PAUSABLE

func is_mage() -> bool:
	return class_id == &"mage"

func is_archer() -> bool:
	return class_id == &"archer"

func available_skill_ids() -> Array[StringName]:
	if run_state != null and run_state.uses_persistent_build():
		var equipped: Array[StringName] = []
		for skill_id: Variant in run_state.build_snapshot.active_slots:
			if skill_id == null:
				continue
			var normalized_id := StringName(skill_id)
			if normalized_id in equipped or ClassCatalog.skill_definition(normalized_id) == null or int(run_state.skill_levels.get(normalized_id, 0)) <= 0:
				continue
			equipped.append(normalized_id)
		return equipped
	return class_definition.skill_ids.duplicate()

func apply_run_modifiers(state: RunState) -> void:
	run_state = state
	var derived := _build_stat_breakdown()
	_apply_derived_stats(derived)
	resources_changed.emit()
	queue_redraw()

func _apply_derived_stats(derived: StatBreakdown) -> void:
	assert(derived != null)
	var missing_sp := maxf(0.0, max_sp - current_sp)
	stat_breakdown = derived
	health.set_stats_preserving_missing(stat_breakdown)
	max_sp = maxf(0.0, stat_breakdown.value(&"max_sp"))
	current_sp = clampf(max_sp - missing_sp, 0.0, max_sp)

func move_to(point: Vector2) -> void:
	cancel_active_cast()
	target = null
	_attack_engaged = false
	_attack_recovery = 0.0
	_set_path(point)

func pursue(enemy: CombatActor) -> void:
	cancel_active_cast()
	target = enemy
	_attack_engaged = false
	_path.clear()
	_repath_time = 0.0

func use_slash(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	var rank_definition := _runtime_rank_definition(&"slash")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"slash"):
		return false
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

func use_dash(direction: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"dash")
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"dash") or is_rooted():
		return false
	var facing := _resolved_facing(direction)
	_spend(&"dash")
	_dash_endpoint = dash_destination(facing)
	_dash_speed = global_position.distance_to(_dash_endpoint) / DASH_DURATION
	_dash_active = global_position.distance_to(_dash_endpoint) > MOVEMENT_EPSILON
	_path.clear()
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
	precision_projectile_requested.emit(&"double_shot", request, null, facing, 2, 1)
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
	return skill_id in [&"snare_trap", &"explosive_trap"] and skill_range(skill_id) > 0.0 and navigation != null and navigation.is_walkable(trap_center(skill_id, point))

func trap_armed_duration(base_duration: float) -> float:
	return run_state.build_snapshot.trap_armed_duration(base_duration)

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

func foliage_shelter_center(point: Vector2) -> Vector2:
	var offset := point - global_position
	var maximum_range := skill_range(&"foliage_shelter")
	if offset.length() > maximum_range:
		offset = offset.normalized() * maximum_range
	return global_position + offset

func can_place_foliage_shelter(point: Vector2) -> bool:
	return skill_range(&"foliage_shelter") > 0.0 and navigation != null and navigation.is_walkable(foliage_shelter_center(point))

func use_foliage_shelter(point: Vector2) -> bool:
	var rank_definition := _runtime_rank_definition(&"foliage_shelter")
	if class_id != &"archer" or rank_definition == null or not _can_spend(&"foliage_shelter") or not can_place_foliage_shelter(point):
		return false
	var center := foliage_shelter_center(point)
	_spend(&"foliage_shelter")
	foliage_shelter_requested.emit(center, rank_definition.power)
	presentation_action.emit(&"cast", aim_direction(center), 0.18)
	resources_changed.emit()
	return true

func register_foliage_shelter(source_id: int, center: Vector2, radius: float) -> bool:
	if source_id <= 0 or not center.is_finite() or not is_finite(radius) or radius <= 0.0:
		return false
	_foliage_shelters[source_id] = {"center": center, "radius": radius}
	queue_redraw()
	return true

func unregister_foliage_shelter(source_id: int) -> bool:
	if not _foliage_shelters.erase(source_id):
		return false
	if _foliage_shelters.is_empty():
		concealment_reveal_remaining = 0.0
	queue_redraw()
	return true

func clear_foliage_shelters() -> void:
	_foliage_shelters.clear()
	concealment_reveal_remaining = 0.0
	queue_redraw()

func is_concealed() -> bool:
	return is_alive() and concealment_reveal_remaining <= 0.0 and not _containing_foliage_shelters().is_empty()

func can_be_acquired_by(observer_position: Vector2) -> bool:
	if not is_alive():
		return false
	var containing := _containing_foliage_shelters()
	if concealment_reveal_remaining > 0.0 or containing.is_empty():
		return true
	for shelter: Dictionary in containing:
		if observer_position.distance_to(shelter["center"]) <= float(shelter["radius"]):
			return true
	return false

func reveal_from_offense(duration: float = CONCEALMENT_REVEAL_DURATION) -> bool:
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

func begin_skill_cast(skill_id: StringName, point: Vector2, enemy: CombatActor = null) -> bool:
	var definition := ClassCatalog.skill_definition(skill_id)
	var cast_time := skill_cast_time(skill_id)
	if definition == null or cast_time <= 0.0 or skill_id not in available_skill_ids() or not _can_spend(skill_id):
		return false
	if definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET and not can_target_skill(skill_id, enemy):
		return false
	cancel_active_cast()
	active_cast_skill = skill_id
	active_cast_total = cast_time
	active_cast_remaining = active_cast_total
	_active_cast_point = point
	_active_cast_target_id = enemy.get_instance_id() if enemy != null else 0
	_path.clear()
	velocity = Vector2.ZERO
	_attack_recovery = 0.0
	var facing := aim_direction(enemy.global_position if enemy != null else point)
	_active_cast_direction = facing
	presentation_action.emit(&"cast", facing, active_cast_total)
	resources_changed.emit()
	return true

func cancel_active_cast() -> bool:
	if active_cast_skill == &"":
		return false
	active_cast_skill = &""
	active_cast_remaining = 0.0
	active_cast_total = 0.0
	_active_cast_target_id = 0
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
	return global_position.distance_to(enemy.global_position) <= skill_range(skill_id)

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
		return rank_definition.range + _extended_aim_bonus(skill_id)
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
	for skill_id: StringName in run_state.skill_levels:
		var catalog_definition := ClassCatalog.skill_definition(skill_id)
		if catalog_definition == null or catalog_definition.ranks.is_empty():
			continue
		var rank_definition := catalog_definition.rank_definition(skill_rank(skill_id))
		if rank_definition != null:
			_rank_definitions[skill_id] = rank_definition

func _runtime_rank_definition(skill_id: StringName) -> SkillRankDefinition:
	return _rank_definitions.get(skill_id)

func _process(delta: float) -> void:
	super._process(delta)
	if not is_alive():
		velocity = Vector2.ZERO
		return
	var simulation_paused := is_inside_tree() and get_tree().paused
	if simulation_paused:
		return
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
	if concealment_reveal_remaining > 0.0:
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
			_dash_active = false
			velocity = Vector2.ZERO
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
	active_cast_skill = &""
	active_cast_total = 0.0
	_active_cast_target_id = 0
	resources_changed.emit()
	skill_cast_ready.emit(completed_skill, completed_point, completed_target_id)

func _advance_dash(delta: float) -> void:
	var distance := global_position.distance_to(_dash_endpoint)
	if distance <= MOVEMENT_EPSILON:
		global_position = _dash_endpoint
		_dash_active = false
		return
	var next_position := global_position.move_toward(_dash_endpoint, _dash_speed * delta)
	var safe_position := navigation.move_until_blocked(global_position, next_position)
	global_position = safe_position
	if safe_position.distance_to(next_position) > MOVEMENT_EPSILON or global_position.distance_to(_dash_endpoint) <= MOVEMENT_EPSILON:
		global_position = safe_position if safe_position.distance_to(next_position) > MOVEMENT_EPSILON else _dash_endpoint
		_dash_active = false

func _regenerate_sp(delta: float, simulation_paused: bool) -> bool:
	if simulation_paused or not is_alive() or current_sp >= max_sp:
		return false
	var previous_sp := current_sp
	current_sp = minf(max_sp, current_sp + stat_breakdown.value(&"sp_regen") * delta)
	if is_equal_approx(previous_sp, current_sp):
		return false
	resources_changed.emit()
	return true

func regenerate_hp(delta: float, encounter_active: bool, simulation_paused: bool) -> bool:
	if encounter_active or simulation_paused or delta <= 0.0 or not is_alive() or health.current_hp >= health.max_hp:
		return false
	var previous_hp := health.current_hp
	health.current_hp = minf(health.max_hp, health.current_hp + stat_breakdown.value(&"hp_regen") * delta)
	if is_equal_approx(previous_hp, health.current_hp):
		return false
	resources_changed.emit()
	queue_redraw()
	return true

func _try_basic_attack() -> void:
	if target == null or attack_cooldown > 0.0 or not can_basic_attack(target, _attack_engaged):
		return
	_last_facing = global_position.direction_to(target.global_position)
	attack_cooldown = 1.0 / stat_breakdown.value(&"attacks_per_second")
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
	request.source_id = get_instance_id()
	request.target_id = enemy.get_instance_id() if enemy != null else 0
	request.skill_id = skill_id
	request.accuracy_mode = accuracy_mode
	request.hit_rating = stat_breakdown.value(&"hit_rating")
	request.crit_chance = stat_breakdown.value(&"crit_chance")
	request.crit_multiplier = stat_breakdown.value(&"crit_multiplier")
	request.damage_dealt_multiplier = stat_breakdown.value(&"damage_dealt_multiplier")
	request.can_crit = can_crit
	return request

func _make_physical_request(enemy: CombatActor, skill_id: StringName, power: float, accuracy_mode: DamageRequest.AccuracyMode, can_crit: bool) -> DamageRequest:
	var request := _make_request(enemy, skill_id, accuracy_mode, can_crit)
	request.physical_damage = power
	return request

func _make_magic_request(enemy: CombatActor, skill_id: StringName, power: float, accuracy_mode: DamageRequest.AccuracyMode, can_crit: bool) -> DamageRequest:
	var request := _make_request(enemy, skill_id, accuracy_mode, can_crit)
	request.magic_damage = power
	return request

func _magic_power(skill_id: StringName) -> float:
	var rank_definition := _runtime_rank_definition(skill_id)
	var definition := ClassCatalog.skill_definition(skill_id)
	var power := rank_definition.power if rank_definition != null else definition.power
	return stat_breakdown.value(&"magic_attack") * power

func _can_spend(skill_id: StringName) -> bool:
	var definition := ClassCatalog.skill_definition(skill_id)
	var has_runtime_definition := definition != null and (definition.ranks.is_empty() or _runtime_rank_definition(skill_id) != null)
	return has_runtime_definition and skill_id in available_skill_ids() and is_alive() and skill_cooldown(skill_id) <= 0.0 and current_sp >= skill_cost(skill_id)

func _spend(skill_id: StringName) -> void:
	var definition := ClassCatalog.skill_definition(skill_id)
	var rank_definition := _runtime_rank_definition(skill_id)
	var cost := rank_definition.sp_cost if rank_definition != null else definition.sp_cost
	var base_cooldown := rank_definition.cooldown if rank_definition != null else definition.cooldown
	current_sp -= cost
	var cooldown := StatCalculator.effective_cooldown(base_cooldown, stat_breakdown)
	if skill_id == &"slash":
		slash_cooldown = cooldown
	elif skill_id == &"dash":
		dash_cooldown = cooldown
	else:
		mage_cooldowns[skill_id] = cooldown

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
	global_position = safe_position
	if safe_position.distance_to(desired_position) > MOVEMENT_EPSILON:
		velocity = Vector2.ZERO
		if has_destination:
			_set_path(_path[-1])
		return
	if reaches_waypoint:
		_path_index += 1
		if _path_index >= _path.size():
			velocity = Vector2.ZERO
	if not velocity.is_zero_approx():
		_last_facing = velocity.normalized()

func _on_health_died(actor_id: int) -> void:
	cancel_active_cast()
	extended_aim_remaining = 0.0
	clear_foliage_shelters()
	velocity = Vector2.ZERO
	_path.clear()
	target = null
	_dash_active = false
	_attack_recovery = 0.0
	super._on_health_died(actor_id)

func basic_attack_distance(enemy: CombatActor) -> float:
	return collision_radius + enemy.collision_radius + class_definition.basic_range + _extended_aim_bonus(&"basic_attack")

func archer_basic_projectile_range() -> float:
	return ARCHER_BASIC_MAX_DISTANCE + _extended_aim_bonus(&"basic_attack")

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

func _build_stat_breakdown() -> StatBreakdown:
	return run_state.build_snapshot.stat_breakdown(run_state.stat_modifier_sources())

func _draw() -> void:
	super._draw()
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
