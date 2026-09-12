class_name PlayerActor
extends CombatActor

signal attack_requested(request: DamageRequest, target: CombatActor)
signal resources_changed

const BASE_ATTRIBUTES := {"str": 8, "agi": 5, "vit": 8, "int": 2, "dex": 5, "luk": 2}
const SLASH_MANA_COST := 15.0
const DASH_MANA_COST := 20.0
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

var navigation: ArenaNavigation
var mana := 0.0
var max_mana := 0.0
var attack_cooldown := 0.0
var slash_cooldown := 0.0
var dash_cooldown := 0.0
var target: CombatActor
var velocity := Vector2.ZERO
var _path := PackedVector2Array()
var _path_index := 0
var _repath_time := 0.0
var _last_facing := Vector2.RIGHT
var _slash_visual_time := 0.0
var _basic_visual_time := 0.0
var _basic_facing := Vector2.RIGHT
var _attack_engaged := false
var _attack_recovery := 0.0

func configure(nav: ArenaNavigation, run_state: RunState) -> void:
	navigation = nav
	var modifiers := run_state.get_modifiers()
	var derived := RpgStats.derive(BASE_ATTRIBUTES, modifiers["flat"], _with_passive(modifiers["increased"]))
	setup("Espadachim", Color("55a8d9"), derived, 20.0)
	max_mana = float(stats["max_mana"])
	mana = max_mana
	process_mode = Node.PROCESS_MODE_PAUSABLE

func apply_run_modifiers(run_state: RunState) -> void:
	var modifiers := run_state.get_modifiers()
	var derived := RpgStats.derive(BASE_ATTRIBUTES, modifiers["flat"], _with_passive(modifiers["increased"]))
	_apply_derived_stats(derived)
	resources_changed.emit()
	queue_redraw()

func _apply_derived_stats(derived: Dictionary) -> void:
	var missing_mana := maxf(0.0, max_mana - mana)
	stats = derived
	health.set_max_preserving_missing(float(stats["max_hp"]))
	health.defense = float(stats["defense"])
	max_mana = maxf(0.0, float(stats["max_mana"]))
	mana = clampf(max_mana - missing_mana, 0.0, max_mana)

func move_to(point: Vector2) -> void:
	target = null
	_attack_engaged = false
	_attack_recovery = 0.0
	_set_path(point)

func pursue(enemy: CombatActor) -> void:
	target = enemy
	_attack_engaged = false
	_path.clear()
	_repath_time = 0.0

func use_slash(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	if not is_alive() or slash_cooldown > 0.0 or mana < SLASH_MANA_COST:
		return false
	var facing := direction.normalized()
	if facing.is_zero_approx():
		facing = _last_facing
	_last_facing = facing
	mana -= SLASH_MANA_COST
	slash_cooldown = 4.0 * float(stats["cast_multiplier"])
	_slash_visual_time = 0.20
	queue_redraw()
	for enemy: CombatActor in enemies.duplicate():
		if not enemy.is_alive():
			continue
		var offset := enemy.global_position - global_position
		if offset.length() <= SLASH_RANGE and absf(facing.angle_to(offset.normalized())) <= SLASH_HALF_ANGLE:
			attack_requested.emit(_make_request(enemy, &"cone_slash", float(stats["physical_attack"]) * 1.45, 1.0, true), enemy)
	resources_changed.emit()
	return true

func use_dash(direction: Vector2) -> bool:
	if not is_alive() or dash_cooldown > 0.0 or mana < DASH_MANA_COST:
		return false
	var facing := direction.normalized()
	if facing.is_zero_approx():
		facing = _last_facing
	_last_facing = facing
	mana -= DASH_MANA_COST
	dash_cooldown = 6.0 * float(stats["cast_multiplier"])
	global_position = navigation.move_until_blocked(global_position, global_position + facing * 270.0)
	_path.clear()
	velocity = Vector2.ZERO
	_attack_recovery = 0.0
	_repath_time = 0.0
	resources_changed.emit()
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if not is_alive():
		velocity = Vector2.ZERO
		return
	var simulation_paused := is_inside_tree() and get_tree().paused
	if simulation_paused:
		return
	_regenerate_mana(delta, false)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_attack_recovery = maxf(0.0, _attack_recovery - delta)
	slash_cooldown = maxf(0.0, slash_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if _slash_visual_time > 0.0:
		_slash_visual_time = maxf(0.0, _slash_visual_time - delta)
		queue_redraw()
	if _basic_visual_time > 0.0:
		_basic_visual_time = maxf(0.0, _basic_visual_time - delta)
		queue_redraw()
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
			# Plant briefly after a strike; a fleeing enemy can leave the reach.
			_path.clear()
			velocity = Vector2.ZERO
			return
		else:
			_attack_engaged = false
			if _repath_time <= 0.0 or _path_index >= _path.size():
				# Chase the actual target, not an obsolete point on its range border.
				_set_path(target.global_position)
				_repath_time = 0.22
	_move_along_path(delta)
	# Resolve contact in the same update instead of letting the enemy escape
	# before the next frame's pre-movement range check.
	if target != null and can_basic_attack(target, _attack_engaged):
		_attack_engaged = true
		_path.clear()
		velocity = Vector2.ZERO
		_try_basic_attack()

func _regenerate_mana(delta: float, simulation_paused: bool) -> bool:
	if simulation_paused or not is_alive() or mana >= max_mana:
		return false
	var previous_mana := mana
	mana = minf(max_mana, mana + float(stats["mana_regen_per_second"]) * delta)
	if is_equal_approx(previous_mana, mana):
		return false
	resources_changed.emit()
	return true

func _try_basic_attack() -> void:
	if target == null or attack_cooldown > 0.0 or not can_basic_attack(target, _attack_engaged):
		return
	_last_facing = global_position.direction_to(target.global_position)
	attack_cooldown = 1.0 / float(stats["attacks_per_second"])
	_attack_recovery = BASIC_ATTACK_RECOVERY
	_basic_visual_time = BASIC_ATTACK_RECOVERY
	_basic_facing = _last_facing
	queue_redraw()
	attack_requested.emit(_make_request(target, &"basic_attack", float(stats["physical_attack"]), float(stats["hit_chance"]), true), target)

func _make_request(enemy: CombatActor, skill_id: StringName, power: float, hit_chance: float, can_crit: bool) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = get_instance_id()
	request.target_id = enemy.get_instance_id()
	request.skill_id = skill_id
	request.kind = DamageRequest.Kind.PHYSICAL
	request.base_damage = power
	request.hit_chance = hit_chance
	request.crit_chance = float(stats["crit_chance"])
	request.can_crit = can_crit
	return request

func _set_path(point: Vector2) -> void:
	_path = navigation.get_path(global_position, point)
	_path_index = 0
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 0.01:
		_path_index += 1

func _move_along_path(delta: float) -> void:
	# Small bounded steps keep braking/collision stable even on a long render frame.
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
		# Drift can reveal the next leg earlier: turn only when the full shortcut
		# clears inflated geometry, never by snapping to a grid center.
		for index: int in range(_path.size() - 1, _path_index, -1):
			if navigation.is_segment_walkable(global_position, _path[index]):
				_path_index = index
				break
		offset = _path[_path_index] - global_position
		var desired_speed := minf(float(stats["move_speed"]), sqrt(2.0 * MOVE_FRICTION * offset.length()))
		desired_velocity = offset.normalized() * desired_speed
	var previous_velocity := velocity
	var acceleration := MOVE_FRICTION if desired_velocity.length() < velocity.length() else MOVE_ACCELERATION
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	var displacement := (previous_velocity + velocity) * 0.5 * delta
	var desired_position := global_position + displacement
	var reaches_waypoint := false
	if has_destination:
		reaches_waypoint = offset.length() <= ARRIVAL_TOLERANCE or (
			displacement.length() >= offset.length()
			and displacement.normalized().dot(offset.normalized()) > 0.99
		)
		if reaches_waypoint:
			desired_position = _path[_path_index]
	var safe_position := navigation.move_until_blocked(global_position, desired_position)
	global_position = safe_position
	if safe_position.distance_to(desired_position) > MOVEMENT_EPSILON:
		# Contact removes blocked momentum. Rebuild from the actual safe position
		# so inertia at a corner cannot strand the actor on an obsolete segment.
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
	velocity = Vector2.ZERO
	_path.clear()
	target = null
	_attack_recovery = 0.0
	super._on_health_died(actor_id)

func basic_attack_distance(enemy: CombatActor) -> float:
	return collision_radius + enemy.collision_radius + BASIC_REACH_BEYOND_BODIES

func can_basic_attack(enemy: CombatActor, retain: bool = false) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
		return false
	var allowed_distance := basic_attack_distance(enemy) + (ATTACK_RETENTION if retain else 0.0)
	return global_position.distance_to(enemy.global_position) <= allowed_distance and navigation.is_segment_clear(global_position, enemy.global_position, 0.0)

func _with_passive(increased: Dictionary) -> Dictionary:
	var result: Dictionary = increased.duplicate()
	# Espadachim's fixed passive: +50% defense through the shared stat pipeline.
	result["defense"] = float(result.get("defense", 0.0)) + 0.50
	return result

func _draw() -> void:
	super._draw()
	draw_line(Vector2(-22, -12), Vector2(23, -40), Color("e9c67b"), 5.0)
	draw_circle(Vector2(0, -18), 5.0, Color("dcecff"))
	if _basic_visual_time > 0.0:
		var swing_angle := _basic_facing.angle()
		draw_arc(Vector2(0, -18), 62.0, swing_angle - 0.65, swing_angle + 0.65, 16, Color(1.0, 0.89, 0.60, _basic_visual_time / BASIC_ATTACK_RECOVERY), 4.0)
	if _slash_visual_time > 0.0:
		var angle := _last_facing.angle()
		draw_arc(Vector2.ZERO, SLASH_RANGE, angle - SLASH_HALF_ANGLE, angle + SLASH_HALF_ANGLE, 28, Color(0.91, 0.78, 0.48, _slash_visual_time * 3.5), 7.0)
