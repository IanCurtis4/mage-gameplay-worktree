class_name PlayerActor
extends CombatActor

signal attack_requested(request: DamageRequest, target: CombatActor)
signal mage_projectile_requested(skill_id: StringName, request: DamageRequest, target: CombatActor, direction: Vector2, count: int)
signal fire_wall_requested(direction: Vector2, burn_request: DamageRequest)
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
var _active_cast_point := Vector2.ZERO
var _active_cast_target_id: int = 0
var _active_cast_direction := Vector2.RIGHT
var _rank_definitions: Dictionary[StringName, SkillRankDefinition] = {}

func configure(nav: ArenaNavigation, state: RunState) -> void:
	navigation = nav
	run_state = state
	class_id = run_state.class_id
	class_definition = ClassCatalog.class_definition(class_id)
	_capture_rank_definitions()
	var derived := _build_stat_breakdown()
	setup(class_definition.display_name, Color("8e73de") if class_id == &"mage" else Color("55a8d9"), derived, 20.0)
	set_animation_kind(class_id)
	max_sp = stat_breakdown.value(&"max_sp")
	current_sp = max_sp
	for skill_id: StringName in available_skill_ids():
		mage_cooldowns[skill_id] = 0.0
	process_mode = Node.PROCESS_MODE_PAUSABLE

func is_mage() -> bool:
	return class_id == &"mage"

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
	if class_id != &"swordsman" or rank_definition == null or not _can_spend(&"dash"):
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
	var definition := ClassCatalog.skill_definition(skill_id)
	var request := _make_magic_request(enemy, skill_id, _magic_power(skill_id), definition.accuracy_mode, definition.can_crit)
	var count := run_state.projectile_count(skill_id)
	mage_projectile_requested.emit(skill_id, request, enemy, facing, count)
	resources_changed.emit()
	return true

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
	return skill_range(&"teleport") > 0.0 and navigation != null and navigation.is_walkable(teleport_destination(point))

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

func dash_destination(direction: Vector2) -> Vector2:
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
		return rank_definition.range
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
	queue_redraw()
	var request: DamageRequest
	if is_mage():
		request = _make_magic_request(target, &"basic_attack", stat_breakdown.value(&"magic_attack") * class_definition.basic_power, DamageRequest.AccuracyMode.CONTESTED, true)
	else:
		request = _make_physical_request(target, &"basic_attack", stat_breakdown.value(&"melee_attack") * class_definition.basic_power, DamageRequest.AccuracyMode.CONTESTED, true)
	if is_mage():
		mage_projectile_requested.emit(&"basic_attack", request, target, _last_facing, 1)
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
	velocity = Vector2.ZERO
	_path.clear()
	target = null
	_dash_active = false
	_attack_recovery = 0.0
	super._on_health_died(actor_id)

func basic_attack_distance(enemy: CombatActor) -> float:
	return collision_radius + enemy.collision_radius + class_definition.basic_range

func can_basic_attack(enemy: CombatActor, retain: bool = false) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return false
	var allowed_distance := basic_attack_distance(enemy) + (ATTACK_RETENTION if retain else 0.0)
	return global_position.distance_to(enemy.global_position) <= allowed_distance and navigation.is_segment_clear(global_position, enemy.global_position, 0.0)

func _build_stat_breakdown() -> StatBreakdown:
	return run_state.build_snapshot.stat_breakdown(run_state.stat_modifier_sources())

func _draw() -> void:
	super._draw()
	if _basic_visual_time > 0.0 and not is_mage():
		var swing_angle := _basic_facing.angle()
		draw_arc(_basic_origin - global_position, _basic_visual_radius, swing_angle - 0.65, swing_angle + 0.65, 16, Color(1.0, 0.89, 0.60, _basic_visual_time / BASIC_ATTACK_RECOVERY), 4.0)
	if _slash_visual_time > 0.0:
		var angle := _slash_facing.angle()
		draw_arc(_slash_origin - global_position, _slash_visual_range, angle - SLASH_HALF_ANGLE, angle + SLASH_HALF_ANGLE, 28, Color(0.91, 0.78, 0.48, _slash_visual_time * 3.5), 7.0)
