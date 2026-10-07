extends SceneTree

var checks := 0
var failures := 0
var controller: RunController
var captured_request: DamageRequest
var results: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"spiritualist_procession")
	var definition := ClassCatalog.skill_definition(&"spiritualist_procession")
	_check(catalog.is_valid() and metadata["rank_requirements"][1]["job_level"] == 34 and definition.is_rank_catalog_valid(), "Procession unlocks at job 34 with typed ranks")
	var powers: Array[float] = [0.45, 0.50, 0.55, 0.60, 0.65]
	for index: int in range(5):
		var rank := definition.rank_definition(index + 1)
		_check(is_equal_approx(rank.power, powers[index]) and is_equal_approx(rank.cooldown, 10.0) and is_equal_approx(rank.range, 380.0), "R%d stores approved apparition power and timing" % (index + 1))
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.job_level = 34
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_procession": 1}
	snapshot.active_slots = [&"spiritualist_procession", &"spiritualist_echo_curse", null, null, null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("procession", snapshot))
	player.global_position = Vector2(400, 350)
	var boss := _enemy(Vector2(500, 350))
	controller = RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	controller.spiritualist_echo_state.source_id = player.get_instance_id()
	boss.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	boss.health.damage_applied.connect(_record_result)
	player.spiritualist_procession_requested.connect(_on_request)
	controller.spiritualist_echo_state.mark(boss.get_instance_id(), 0.35)
	var sp_before := player.current_sp
	_check(player.use_spiritualist_procession(boss) and player.current_sp == sp_before - 24.0 and player.skill_cooldown(&"spiritualist_procession") > 0.0, "valid commit spends SP and cooldown once")
	_check(captured_request != null and is_equal_approx(captured_request.magic_damage, player.spiritualist_magic_attack() * 0.45), "raw damage captured at commit")
	_check(controller.battle_indicators.spiritualist_wisps.size() == 1 and controller.spiritualist_procession_state.departures_issued == 1 and results.is_empty(), "first apparition departs at t0 without early damage")
	controller._advance_spiritualist_procession(0.19)
	_check(results.is_empty() and controller.battle_indicators.spiritualist_wisps.size() == 1, "no impact before 0.22s")
	controller._advance_spiritualist_procession(0.02)
	_check(results.is_empty() and controller.spiritualist_procession_state.departures_issued == 2, "second apparition departs at 0.20s")
	controller._advance_spiritualist_procession(0.02)
	_check(results.size() == 1 and bool(results[0]["can_trigger_effects"]) and controller.spiritualist_echo_state.pending.size() == 1, "first impact is direct at 0.22s and can consume curse")
	controller._advance_spiritualist_procession(0.20)
	_check(results.size() == 2 and not bool(results[1]["can_trigger_effects"]) and controller.spiritualist_procession_state.departures_issued == 3, "second impact is secondary after third departure")
	controller._advance_spiritualist_procession(0.20)
	_check(results.size() == 3 and not bool(results[2]["can_trigger_effects"]) and not controller.spiritualist_procession_state.active, "third impact completes finite solo-target sequence")
	_check(controller.battle_indicators.spiritualist_wisps.is_empty() and controller.spiritualist_echo_state.pending.size() == 1, "no companion remains and secondary hits do not cascade")
	var after_three := boss.health.current_hp
	controller._advance_spiritualist_procession(1.0)
	_check(boss.health.current_hp == after_three and results.size() == 3, "no fourth impact")
	controller.spiritualist_procession_state.start(player.global_position, boss, captured_request)
	boss.global_position = Vector2(700, 350)
	controller._advance_spiritualist_procession(0.22)
	_check(not controller.spiritualist_procession_state.active and boss.health.current_hp == after_three and controller.battle_indicators.spiritualist_wisps.is_empty(), "loss of line cancels all pending apparitions")
	var blocked_sp := player.current_sp
	player.mage_cooldowns[&"spiritualist_procession"] = 0.0
	_check(not player.use_spiritualist_procession(boss) and player.current_sp == blocked_sp, "blocked target fails atomically")
	player.free()
	boss.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Espiritualista Procissão: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _on_request(request: DamageRequest, target: CombatActor) -> void:
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	captured_request = request.copy()
	controller._on_spiritualist_procession_requested(request, target)

func _record_result(result: Dictionary) -> void:
	results.append(result.duplicate(true))

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
