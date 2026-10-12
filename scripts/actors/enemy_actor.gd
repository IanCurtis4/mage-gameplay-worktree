class_name EnemyActor
extends CombatActor

var effect_ledger := EffectProcLedger.new("enemy")

signal attack_requested(request: DamageRequest, target: CombatActor, ranged: bool)
## Actual navigation-applied walking only. Direct placement/push is not walking.
signal ground_walked(from: Vector2, to: Vector2)
signal mob_skill_requested(request: DamageRequest, target: CombatActor, projectile_speed: float, maximum_range: float)
var occurrence: MobOccurrence
var _mob_definition: MobDefinition
var _mob_cast: Dictionary = {}
var _mob_cooldowns: Dictionary = {}
var _mob_sp := 0.0

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
	var catalog := BuildContentLoader.pilot().mob_catalog()
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "demo_%d" % get_instance_id()
	spawn.mob_base_id = &"demo_archer" if enemy_type == &"archer" else &"demo_chaser"
	spawn.category_id = &"normal"
	spawn.origin_id = &"demo_arena"
	var result := configure_occurrence(spawn, catalog, nav, target_player)
	assert(result["ok"], str(result))

func configure_occurrence(spawn: MobOccurrence, catalog: MobCatalog, nav: ArenaNavigation, target_player: PlayerActor) -> Dictionary:
	if spawn == null or nav == null or target_player == null:
		return BuildEffectCatalog.failure(&"invalid_occurrence")
	var checked := spawn.validate(catalog)
	if not checked["ok"]:
		return checked
	var derived := catalog.stats(spawn.mob_base_id)
	if not derived["ok"]:
		return derived
	var definition: MobDefinition = checked["definition"]
	occurrence = spawn.copy_occurrence()
	_mob_definition = definition.duplicate(true) as MobDefinition
	archetype = definition.archetype
	navigation = nav
	_navigation_revision = nav.revision
	player = target_player
	hunter_last_seen_position = Vector2.INF
	_mob_cast.clear()
	_mob_cooldowns.clear()
	_mob_sp = derived["breakdown"].value(&"max_sp")
	setup(definition.display_name, definition.tint, derived["breakdown"], definition.collision_radius)
	set_animation_kind(definition.animation_kind)
	hard_controls.boss = occurrence.category_id == &"boss"
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_refresh_player_acquisition()
	return {"ok": true}

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
	for skill: StringName in _mob_cooldowns:
		_mob_cooldowns[skill] = maxf(0.0, float(_mob_cooldowns[skill]) - delta)
	if taunt_remaining > 0.0:
		taunt_remaining = maxf(0.0, taunt_remaining - delta)
		queue_redraw()
	if was_feared and not is_feared():
		_path.clear()
		_path_index = 0
		_repath_time = 0.0
	if is_stunned():
		_mob_cast.clear()
		_path.clear()
		_path_index = 0
		return
	if is_feared():
		_mob_cast.clear()
		if is_rooted():
			_path.clear()
			_path_index = 0
			return
		_repath_time -= delta
		_update_fear_path()
		_move_along_path(delta)
		return
	if not _mob_cast.is_empty():
		_advance_mob_cast(delta)
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
		var attack_range := _declared_attack_range() if archetype == &"archer" else 55.0
		if distance <= attack_range:
			_path.clear()
			_try_attack(archetype == &"archer")
		else:
			_update_path(player.global_position)
		_move_along_path(delta)
		return
	if archetype == &"archer":
		if distance <= _declared_attack_range() and distance >= minf(150.0, _declared_attack_range() * 0.5):
			_path.clear()
			_try_attack(true)
		else:
			var standoff := 280.0
			if _mob_definition != null and not _mob_definition.skill_ids.is_empty():
				standoff = minf(standoff, _declared_attack_range() * 0.75)
			var desired := player.global_position + player.global_position.direction_to(global_position) * standoff
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
	if _mob_definition != null and not _mob_definition.skill_ids.is_empty():
		_try_declared_skill()
		return
	if not effect_ledger.can_create_root() or (ranged and is_inside_tree() and not EffectProcLedger.projectile_slots_available(get_tree(), 1)):
		return
	attack_cooldown = (1.70 if ranged else 1.30) * stat_breakdown.value(&"attacks_per_second") / attacks_per_second()
	var request := DamageRequest.new()
	request.context = effect_ledger.new_root(get_instance_id(), false, "", false, _causal_plan())
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
	_mob_cast.clear()
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

func _causal_plan() -> Dictionary:
	var controller := get_parent() as RunController
	if controller == null:
		return {} # Legacy isolated fixtures only.
	var targets: Array[int] = [get_instance_id(), player.get_instance_id()]
	for actor: CombatActor in controller.enemies:
		if is_instance_valid(actor) and actor.is_alive() and actor.get_instance_id() not in targets:
			targets.append(actor.get_instance_id())
	var families := BuildEffectCatalog.INTRINSIC_FAMILIES.duplicate()
	families.append_array(BuildEffectCatalog.INTRINSIC_COMPONENTS)
	for skill: StringName in _mob_definition.skill_ids:
		if skill not in families: families.append(skill)
	return {"families": families, "targets": targets, "carriers": []}

func _try_declared_skill() -> bool:
	if _mob_definition == null or not _mob_cast.is_empty() or not effect_ledger.can_create_root():
		return false
	for skill: StringName in _mob_definition.skill_ids:
		if float(_mob_cooldowns.get(skill, 0.0)) > 0.0:
			continue
		var captured := MobSkillAdapters.capture(skill, int(_mob_definition.skill_ranks[skill]), stat_breakdown, get_instance_id(), player.get_instance_id())
		var rank: SkillRankDefinition = captured["rank_definition"]
		if _mob_sp < rank.sp_cost or global_position.distance_to(player.global_position) > rank.range or not navigation.is_segment_clear(global_position, player.global_position, 0.0):
			continue
		captured["remaining"] = captured["cast_time"]
		_mob_cast = captured
		_path.clear()
		if float(captured["remaining"]) <= 0.0:
			_advance_mob_cast(0.0)
		return true
	return false

func _advance_mob_cast(delta: float) -> void:
	if _mob_cast.is_empty(): return
	_mob_cast["remaining"] = maxf(0.0, float(_mob_cast["remaining"]) - delta)
	if float(_mob_cast["remaining"]) > 0.0: return
	var captured := _mob_cast
	_mob_cast = {}
	var rank: SkillRankDefinition = captured["rank_definition"]
	if not is_alive() or player == null or not player.is_alive() or is_stunned() or is_feared() or global_position.distance_to(player.global_position) > rank.range or not navigation.is_segment_clear(global_position, player.global_position, 0.0) or _mob_sp < rank.sp_cost or not effect_ledger.can_create_root():
		return
	if is_inside_tree() and not EffectProcLedger.projectile_slots_available(get_tree(), 1): return
	var request: DamageRequest = captured["request"]
	request.context = effect_ledger.new_root(get_instance_id(), false, "", false, _causal_plan())
	request.damage_dealt_multiplier = outgoing_damage_multiplier() * scenario_damage_multiplier
	_mob_sp -= rank.sp_cost
	_mob_cooldowns[request.skill_id] = captured["cooldown"]
	presentation_action.emit(&"cast_release", global_position.direction_to(player.global_position), 0.18)
	mob_skill_requested.emit(request, player, rank.projectile_speed, rank.range)

func _declared_attack_range() -> float:
	if _mob_definition == null or _mob_definition.skill_ids.is_empty(): return 390.0
	var result := 0.0
	for skill: StringName in _mob_definition.skill_ids:
		var rank := ClassCatalog.skill_definition(skill).rank_definition(int(_mob_definition.skill_ranks[skill]))
		result = maxf(result, rank.range)
	return result
