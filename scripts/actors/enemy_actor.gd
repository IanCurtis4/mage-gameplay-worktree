class_name EnemyActor
extends CombatActor

var effect_ledger := EffectProcLedger.new("enemy")

signal attack_requested(request: DamageRequest, target: CombatActor, ranged: bool)
## Actual navigation-applied walking only. Direct placement/push is not walking.
signal ground_walked(from: Vector2, to: Vector2)

const MOVEMENT_EPSILON := 0.01

var archetype: StringName
var navigation: ArenaNavigation
var player: PlayerActor
var attack_cooldown := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _repath_time := 0.0
var _navigation_revision := 0
var player_target_acquired := false
var hunter_last_seen_position := Vector2.INF
var taunt_remaining := 0.0
var scenario_damage_multiplier := 1.0

func apply_defender_push(direction: Vector2, distance: float) -> float:
	if not is_alive() or hard_controls.boss or navigation == null or direction.is_zero_approx() or distance <= 0.0:
		return 0.0
	var before := global_position
	global_position = navigation.move_until_blocked(before, before + direction.normalized() * distance)
	_path.clear()
	_path_index = 0
	_repath_time = 0.0
	return before.distance_to(global_position)

func configure(enemy_type: StringName, nav: ArenaNavigation, target_player: PlayerActor) -> void:
	archetype = enemy_type
	navigation = nav
	_navigation_revision = nav.revision
	player = target_player
	hunter_last_seen_position = Vector2.INF
	if archetype == &"archer":
		var archer_sources: Array[Dictionary] = [{
			"source_id": &"enemy_archer_tuning",
			"flat": {&"max_hp": -68.0, &"move_speed": -45.0},
		}]
		var archer_stats := StatCalculator.calculate({"str": 4, "agi": 5, "vit": 2, "int": 1, "dex": 7, "luk": 1}, {}, 1, archer_sources)
		setup("Arqueiro", Color("d29a4a"), archer_stats, 17.0)
		set_animation_kind(&"archer")
	else:
		var chaser_sources: Array[Dictionary] = [{
			"source_id": &"enemy_warrior_tuning",
			"flat": {&"max_hp": -62.0, &"move_speed": -25.0},
		}]
		var chaser_stats := StatCalculator.calculate({"str": 5, "agi": 3, "vit": 3, "int": 1, "dex": 4, "luk": 1}, {}, 1, chaser_sources)
		setup("Guerreiro", Color("c65a68"), chaser_stats, 19.0)
		set_animation_kind(&"warrior")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_refresh_player_acquisition()

func _process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return
	var was_feared := is_feared()
	super._process(delta)
	if not is_alive() or player == null or not player.is_alive():
		return
	if navigation != null and _navigation_revision != navigation.revision:
		_navigation_revision = navigation.revision
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if taunt_remaining > 0.0:
		taunt_remaining = maxf(0.0, taunt_remaining - delta)
		queue_redraw()
	if was_feared and not is_feared():
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
	if is_stunned():
		_path.clear()
		_path_index = 0
		return
	if is_feared():
		if is_rooted():
			_path.clear()
			_path_index = 0
			return
		_repath_time -= delta
		_update_fear_path()
		_move_along_path(delta)
		return
	if not _refresh_player_acquisition():
		if player.is_hunter() and hunter_last_seen_position.is_finite():
			_repath_time -= delta
			_update_path(hunter_last_seen_position)
			_move_along_path(delta)
			return
		_path.clear()
		_path_index = 0
		return
	_repath_time -= delta
	var distance := global_position.distance_to(player.global_position)
	if taunt_remaining > 0.0:
		var attack_range := 390.0 if archetype == &"archer" else 55.0
		if distance <= attack_range:
			_path.clear()
			_try_attack(archetype == &"archer")
		else:
			_update_path(player.global_position)
		_move_along_path(delta)
		return
	if archetype == &"archer":
		if distance <= 390.0 and distance >= 150.0:
			_path.clear()
			_try_attack(true)
		else:
			var desired := player.global_position + player.global_position.direction_to(global_position) * 280.0
			_update_path(desired)
	else:
		if distance <= 55.0:
			_path.clear()
			_try_attack(false)
		else:
			_update_path(player.global_position)
	_move_along_path(delta)

func _try_attack(ranged: bool) -> void:
	if is_stunned() or is_feared() or attack_cooldown > 0.0 or not player_target_acquired or (taunt_remaining <= 0.0 and not player.can_be_acquired_by(global_position)):
		return
	if not effect_ledger.can_create_root() or (ranged and is_inside_tree() and not EffectProcLedger.projectile_slots_available(get_tree(), 1)):
		return
	attack_cooldown = (1.70 if ranged else 1.30) * stat_breakdown.value(&"attacks_per_second") / attacks_per_second()
	var request := DamageRequest.new()
	request.context = effect_ledger.new_root(get_instance_id())
	request.source_id = get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_arrow" if ranged else &"enemy_claw"
	var attack_id := &"precision_attack" if ranged else &"melee_attack"
	request.physical_damage = stat_breakdown.value(attack_id) * 0.45
	request.damage_dealt_multiplier = outgoing_damage_multiplier() * scenario_damage_multiplier
	request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	request.hit_rating = stat_breakdown.value(&"hit_rating")
	request.crit_chance = 0.0
	request.can_crit = false
	presentation_action.emit(&"basic_attack", global_position.direction_to(player.global_position), 0.18)
	attack_requested.emit(request, player, ranged)

func apply_fear(base_duration: float) -> float:
	var applied_duration := super.apply_fear(base_duration)
	if applied_duration > 0.0:
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
	return applied_duration

func apply_taunt(duration: float) -> bool:
	if not is_alive() or not is_finite(duration) or duration <= 0.0:
		return false
	taunt_remaining = duration
	_path.clear()
	_path_index = 0
	_repath_time = 0.0
	queue_redraw()
	return true

func clear_statuses() -> void:
	taunt_remaining = 0.0
	super.clear_statuses()

func _draw() -> void:
	super._draw()
	if taunt_remaining > 0.0:
		draw_arc(Vector2(0, -18), collision_radius + 21.0, 0.0, TAU, 32, Color("efb453"), 2.5, true)

func _update_fear_path() -> void:
	if _repath_time > 0.0:
		return
	_path.clear()
	_path_index = 0
	_repath_time = 0.18
	var away := player.global_position.direction_to(global_position)
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var initial_distance := global_position.distance_to(player.global_position)
	var best_gain := 8.0
	for angle: float in [0.0, -PI * 0.25, PI * 0.25, -PI * 0.5, PI * 0.5]:
		var direction := away.rotated(angle)
		for distance: float in [180.0, 100.0]:
			var candidate_path := navigation.get_path(global_position, global_position + direction * distance)
			if candidate_path.is_empty() or candidate_path[0].distance_to(player.global_position) < initial_distance - 1.0:
				continue
			var gain := candidate_path[-1].distance_to(player.global_position) - initial_distance
			if gain > best_gain:
				best_gain = gain
				_path = candidate_path

func _refresh_player_acquisition() -> bool:
	var was_acquired := player_target_acquired
	player_target_acquired = player != null and is_instance_valid(player) and player.is_alive() and (taunt_remaining > 0.0 or player.can_be_acquired_by(global_position))
	if player != null and is_instance_valid(player) and player.is_hunter():
		if player_target_acquired:
			hunter_last_seen_position = player.global_position
		elif was_acquired:
			_path.clear()
			_path_index = 0
			_repath_time = 0.0
	return player_target_acquired

func _update_path(destination: Vector2) -> void:
	if _repath_time > 0.0:
		return
	_path = navigation.get_path(global_position, destination)
	_path_index = 0
	_repath_time = 0.45

func _move_along_path(delta: float) -> void:
	if is_rooted() or is_stunned():
		return
	var remaining_distance := stat_breakdown.value(&"move_speed") * movement_speed_multiplier() * delta
	while remaining_distance > 0.0 and _path_index < _path.size():
		var point := _path[_path_index]
		var distance := global_position.distance_to(point)
		if distance < MOVEMENT_EPSILON:
			_path_index += 1
			continue
		var direction := global_position.direction_to(point)
		var travel := minf(distance, remaining_distance)
		var desired := global_position + direction * travel
		var before := global_position
		var moved_to := navigation.move_until_blocked(before, desired)
		var actual_travel := before.distance_to(moved_to)
		global_position = moved_to
		if actual_travel <= 0.0:
			break
		ground_walked.emit(before, moved_to)
		if not is_alive():
			return
		if actual_travel + MOVEMENT_EPSILON < travel:
			_path.clear()
			break
		# Consume the planned budget after a successful segment. Vector2 rounding can
		# otherwise leave a positive subpixel remainder that never makes progress.
		remaining_distance = maxf(0.0, remaining_distance - travel)
		if travel >= distance - MOVEMENT_EPSILON:
			_path_index += 1
