class_name EnemyActor
extends CombatActor

signal attack_requested(request: DamageRequest, target: CombatActor, ranged: bool)

const MOVEMENT_EPSILON := 0.01

var archetype: StringName
var navigation: ArenaNavigation
var player: PlayerActor
var attack_cooldown := 0.0
var _path := PackedVector2Array()
var _path_index := 0
var _repath_time := 0.0

func configure(enemy_type: StringName, nav: ArenaNavigation, target_player: PlayerActor) -> void:
	archetype = enemy_type
	navigation = nav
	player = target_player
	if archetype == &"archer":
		var archer_stats := RpgStats.derive({"str": 4, "agi": 5, "vit": 2, "int": 1, "dex": 7, "luk": 1}, {"max_hp": -68.0, "move_speed": -45.0})
		setup("Arqueiro", Color("d29a4a"), archer_stats, 17.0)
	else:
		var chaser_stats := RpgStats.derive({"str": 5, "agi": 3, "vit": 3, "int": 1, "dex": 4, "luk": 1}, {"max_hp": -62.0, "move_speed": -25.0})
		setup("Perseguidor", Color("c65a68"), chaser_stats, 19.0)
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _process(delta: float) -> void:
	super._process(delta)
	if not is_alive() or player == null or not player.is_alive():
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	_repath_time -= delta
	var distance := global_position.distance_to(player.global_position)
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
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 1.70 if ranged else 1.30
	var request := DamageRequest.new()
	request.source_id = get_instance_id()
	request.target_id = player.get_instance_id()
	request.skill_id = &"enemy_arrow" if ranged else &"enemy_claw"
	request.kind = DamageRequest.Kind.PHYSICAL
	request.base_damage = float(stats["physical_attack"]) * (0.45 if ranged else 0.45)
	request.hit_chance = float(stats["hit_chance"])
	request.crit_chance = 0.0
	request.can_crit = false
	attack_requested.emit(request, player, ranged)

func _update_path(destination: Vector2) -> void:
	if _repath_time > 0.0:
		return
	_path = navigation.get_path(global_position, destination)
	_path_index = 0
	_repath_time = 0.45

func _move_along_path(delta: float) -> void:
	var remaining_distance := float(stats["move_speed"]) * delta
	while remaining_distance > 0.0 and _path_index < _path.size():
		var point := _path[_path_index]
		var distance := global_position.distance_to(point)
		if distance < MOVEMENT_EPSILON:
			_path_index += 1
			continue
		var direction := global_position.direction_to(point)
		var travel := minf(distance, remaining_distance)
		var desired := global_position + direction * travel
		var moved_to := navigation.move_until_blocked(global_position, desired)
		var actual_travel := global_position.distance_to(moved_to)
		global_position = moved_to
		if actual_travel <= 0.0:
			break
		if actual_travel + MOVEMENT_EPSILON < travel:
			_path.clear()
			break
		# Consume the planned budget after a successful segment. Vector2 rounding can
		# otherwise leave a positive subpixel remainder that never makes progress.
		remaining_distance = maxf(0.0, remaining_distance - travel)
		if travel >= distance - MOVEMENT_EPSILON:
			_path_index += 1

func _draw() -> void:
	super._draw()
	if archetype == &"archer":
		draw_arc(Vector2(0, -20), 15.0, -1.5, 1.5, 18, Color("f6dfad"), 3.0)
		draw_line(Vector2(0, -35), Vector2(0, -5), Color("f6dfad"), 2.0)
	else:
		draw_line(Vector2(-15, -35), Vector2(-27, -12), Color("ffd1d6"), 4.0)
		draw_line(Vector2(15, -35), Vector2(27, -12), Color("ffd1d6"), 4.0)
