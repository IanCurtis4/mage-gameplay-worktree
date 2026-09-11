class_name PlayerActor
extends CombatActor

signal attack_requested(request: DamageRequest, target: CombatActor)
signal resources_changed

const BASE_ATTRIBUTES := {"str": 8, "agi": 5, "vit": 8, "int": 2, "dex": 5, "luk": 2}
const MELEE_RANGE := 62.0
const SLASH_RANGE := 155.0
const SLASH_HALF_ANGLE := deg_to_rad(52.0)

var navigation: ArenaNavigation
var mana := 0.0
var max_mana := 0.0
var attack_cooldown := 0.0
var slash_cooldown := 0.0
var dash_cooldown := 0.0
var target: CombatActor
var _path := PackedVector2Array()
var _path_index := 0
var _repath_time := 0.0
var _last_facing := Vector2.RIGHT
var _slash_visual_time := 0.0

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
	_set_path(point)

func pursue(enemy: CombatActor) -> void:
	target = enemy
	_repath_time = 0.0

func use_slash(direction: Vector2, enemies: Array[CombatActor]) -> bool:
	if not is_alive() or slash_cooldown > 0.0 or mana < 15.0:
		return false
	var facing := direction.normalized()
	if facing.is_zero_approx():
		facing = _last_facing
	_last_facing = facing
	mana -= 15.0
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
	if not is_alive() or dash_cooldown > 0.0 or mana < 20.0:
		return false
	var facing := direction.normalized()
	if facing.is_zero_approx():
		facing = _last_facing
	_last_facing = facing
	mana -= 20.0
	dash_cooldown = 6.0 * float(stats["cast_multiplier"])
	global_position = navigation.move_until_blocked(global_position, global_position + facing * 270.0)
	_path.clear()
	resources_changed.emit()
	return true

func _process(delta: float) -> void:
	super._process(delta)
	if not is_alive():
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	slash_cooldown = maxf(0.0, slash_cooldown - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if _slash_visual_time > 0.0:
		_slash_visual_time = maxf(0.0, _slash_visual_time - delta)
		queue_redraw()
	if target != null and (not is_instance_valid(target) or not target.is_alive()):
		target = null
		_path.clear()
	if target != null:
		var distance := global_position.distance_to(target.global_position)
		if distance <= MELEE_RANGE:
			_path.clear()
			_try_basic_attack()
		else:
			_repath_time -= delta
			if _repath_time <= 0.0:
				var stop_point := target.global_position + target.global_position.direction_to(global_position) * MELEE_RANGE * 0.72
				_set_path(stop_point)
				_repath_time = 0.22
	_move_along_path(delta)
	resources_changed.emit()

func _try_basic_attack() -> void:
	if target == null or attack_cooldown > 0.0:
		return
	_last_facing = global_position.direction_to(target.global_position)
	attack_cooldown = 1.0 / float(stats["attacks_per_second"])
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
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 12.0:
		_path_index += 1

func _move_along_path(delta: float) -> void:
	if _path_index >= _path.size():
		return
	var point := _path[_path_index]
	var direction := global_position.direction_to(point)
	if not direction.is_zero_approx():
		_last_facing = direction
	var desired := global_position.move_toward(point, float(stats["move_speed"]) * delta)
	global_position = navigation.move_until_blocked(global_position, desired)
	if global_position.distance_to(point) < 5.0:
		_path_index += 1

func _with_passive(increased: Dictionary) -> Dictionary:
	var result: Dictionary = increased.duplicate()
	# Espadachim's fixed passive: +50% defense through the shared stat pipeline.
	result["defense"] = float(result.get("defense", 0.0)) + 0.50
	return result

func _draw() -> void:
	super._draw()
	draw_line(Vector2(-22, -12), Vector2(23, -40), Color("e9c67b"), 5.0)
	draw_circle(Vector2(0, -18), 5.0, Color("dcecff"))
	if _slash_visual_time > 0.0:
		var angle := _last_facing.angle()
		draw_arc(Vector2.ZERO, SLASH_RANGE, angle - SLASH_HALF_ANGLE, angle + SLASH_HALF_ANGLE, 28, Color(0.91, 0.78, 0.48, _slash_visual_time * 3.5), 7.0)
