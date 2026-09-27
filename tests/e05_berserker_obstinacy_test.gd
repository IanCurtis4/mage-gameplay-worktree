extends SceneTree

var checks := 0
var failures := 0
var emitted: Array[DamageRequest] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := _player(navigation, 1, true)
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	player.global_position = Vector2(400, 350)
	enemy.global_position = Vector2(470, 350)
	var base_multiplier := player.outgoing_damage_multiplier()
	player.health.current_hp = player.health.max_hp * 0.50 + 0.01
	_check(is_equal_approx(_request(player, enemy, &"basic_attack").damage_dealt_multiplier, base_multiplier), "HP above 50% grants no Obstination bonus")
	player.health.current_hp = player.health.max_hp * 0.50
	var low := _request(player, enemy, &"basic_attack")
	_check(is_equal_approx(low.damage_dealt_multiplier, base_multiplier * 1.08), "inclusive 50% HP adds R1 bonus to direct melee")
	player.health.current_hp = player.health.max_hp
	_check(is_equal_approx(low.damage_dealt_multiplier, base_multiplier * 1.08), "emitted damage request keeps its captured low-HP bonus")
	player.health.current_hp = 1.0
	for skill_id: StringName in [&"cone_slash", &"brutal_strike", &"concentrated_rage", &"berserker_rupture", &"berserker_execution", &"berserker_wound_leap", &"berserker_blood_rift", &"berserker_breath_steal"]:
		_check(is_equal_approx(_request(player, enemy, skill_id).damage_dealt_multiplier, base_multiplier * 1.08), "%s is classified as direct melee" % skill_id)
	for skill_id: StringName in [&"berserker_rupture_detonation", &"piercing_shout", &"terrifying_shout"]:
		_check(is_equal_approx(_request(player, enemy, skill_id).damage_dealt_multiplier, base_multiplier), "%s never receives Obstination bonus" % skill_id)
	player.free()
	var rank_three := _player(navigation, 3, true)
	rank_three.health.current_hp = rank_three.health.max_hp * 0.40
	_check(is_equal_approx(_request(rank_three, enemy, &"basic_attack").damage_dealt_multiplier, rank_three.outgoing_damage_multiplier() * 1.14), "R3 uses its approved 14% direct melee bonus")
	rank_three.free()
	var unequipped := _player(navigation, 3, false)
	unequipped.health.current_hp = unequipped.health.max_hp * 0.40
	_check(is_equal_approx(_request(unequipped, enemy, &"basic_attack").damage_dealt_multiplier, unequipped.outgoing_damage_multiplier()), "learned but unequipped Obstination is inert")
	unequipped.free()
	var execution := _player(navigation, 1, true)
	execution.global_position = Vector2(400, 350)
	execution.health.current_hp = execution.health.max_hp * 0.51
	execution.attack_requested.connect(func(request: DamageRequest, _target: CombatActor) -> void: emitted.append(request))
	_check(execution.use_berserker_execution(enemy) and emitted.size() == 1 and execution.health.current_hp < execution.health.max_hp * 0.50 and is_equal_approx(emitted[0].damage_dealt_multiplier, execution.outgoing_damage_multiplier() * 1.08), "Execution HP cost crosses threshold before its direct hit is emitted")
	execution.free()
	enemy.free()
	print("E05 Berserker Obstinação: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _player(navigation: ArenaNavigation, passive_rank: int, equipped: bool) -> PlayerActor:
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"swordsman"
	snapshot.evolution_id = &"berserker"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"swordsman", &"berserker")
	snapshot.skill_ranks = {&"berserker_rupture": 1, &"berserker_execution": 1, &"berserker_obstinacy": passive_rank}
	snapshot.active_slots = [&"berserker_execution", null, null, null, null]
	snapshot.passive_slots = [&"berserker_obstinacy" if equipped else null, null]
	var player := PlayerActor.new()
	player.configure(navigation, RunState.from_build("obstinacy-test", snapshot))
	return player

func _request(player: PlayerActor, enemy: CombatActor, skill_id: StringName) -> DamageRequest:
	return player._make_physical_request(enemy, skill_id, 100.0, DamageRequest.AccuracyMode.GEOMETRY, false)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
