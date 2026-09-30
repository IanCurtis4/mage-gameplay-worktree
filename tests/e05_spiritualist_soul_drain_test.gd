extends SceneTree

var checks := 0
var failures := 0
var controller: RunController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var definition := ClassCatalog.skill_definition(&"spiritualist_soul_drain")
	var metadata := catalog.skill_metadata(&"spiritualist_soul_drain")
	_check(catalog.is_valid() and metadata["rank_requirements"][1]["job_level"] == 25 and metadata["free_rank"] == 0, "drain unlocks at job 25 without free rank")
	_check(definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_SOUL_DRAIN, "drain has typed handler and rank catalog")
	var powers: Array[float] = [0.36, 0.42, 0.48, 0.54, 0.60]
	for index: int in range(5):
		var rank := definition.rank_definition(index + 1)
		_check(is_equal_approx(rank.power, powers[index]) and is_equal_approx(rank.sp_cost, 22.0 + float(index * 2)) and is_equal_approx(rank.range, 350.0) and is_equal_approx(rank.variable_cast_time, 0.30), "R%d stores approved tick power, SP, range and cast" % (index + 1))
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1, &"spiritualist_soul_drain": 1}
	snapshot.active_slots = [&"spiritualist_soul_drain", &"spiritualist_echo_curse", null, null, null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("drain", snapshot))
	player.global_position = Vector2(400, 350)
	player.health.current_hp = player.health.max_hp * 0.5
	var enemy := _enemy(Vector2(500, 350))
	controller = RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.spiritualist_echo_state.source_id = player.get_instance_id()
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	player.spiritualist_drain_requested.connect(_on_drain_request)
	player.spiritualist_channel_interrupt_requested.connect(controller._cancel_spiritualist_drain)
	player.health.damage_applied.connect(controller._on_player_damage_resolved)
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	_check(player.begin_skill_cast(&"spiritualist_soul_drain", enemy.global_position, enemy), "normal 0.30s cast starts before channel commit")
	player.cancel_active_cast()
	_check(player.current_sp == player.max_sp and player.skill_cooldown(&"spiritualist_soul_drain") == 0.0, "pre-commit cancellation spends nothing")
	controller.spiritualist_echo_state.mark(enemy.get_instance_id(), 0.35)
	var sp_before := player.current_sp
	_check(player.use_spiritualist_soul_drain(enemy) and controller.spiritualist_drain_state.active, "valid commit opens one channel")
	_check(player.character_animation.state.action_remaining > 1.9, "canal mantém pose de cast enquanto ativo")
	_check(player.current_sp == sp_before - 22.0 and player.skill_cooldown(&"spiritualist_soul_drain") > 0.0, "channel spends SP and cooldown once at commit")
	_check(controller.battle_indicators.spiritualist_drain_target_id == enemy.get_instance_id(), "tether follows authoritative target")
	var hp_before := enemy.health.current_hp
	controller._advance_spiritualist_drain(0.49)
	_check(enemy.health.current_hp == hp_before and controller.spiritualist_drain_state.ticks_resolved == 0, "no early tick before half-second")
	var player_hp_before := player.health.current_hp
	controller._advance_spiritualist_drain(0.02)
	_check(enemy.health.current_hp < hp_before and player.health.current_hp > player_hp_before and controller.spiritualist_drain_state.ticks_resolved == 1, "first direct tick deals damage and heals from real HP loss")
	_check(not controller.spiritualist_echo_state.has_mark(enemy.get_instance_id()) and controller.spiritualist_echo_state.pending.size() == 1, "only direct first tick consumes existing curse")
	controller._advance_spiritualist_drain(0.5)
	_check(controller.spiritualist_drain_state.ticks_resolved == 2 and controller.spiritualist_echo_state.pending.size() == 1, "second tick is secondary and cannot cascade")
	controller._advance_spiritualist_drain(0.5)
	controller._advance_spiritualist_drain(0.5)
	_check(not controller.spiritualist_drain_state.active and controller.spiritualist_drain_state.ticks_resolved == 4 and controller.battle_indicators.spiritualist_drain_target_id == 0, "fourth tick completes channel and clears tether")
	_check(controller.spiritualist_drain_state.healed_total <= player.health.max_hp * 0.05 + 0.001, "aggregated healing never exceeds five percent max HP")
	var after_four := enemy.health.current_hp
	controller._advance_spiritualist_drain(2.0)
	_check(enemy.health.current_hp == after_four, "no fifth tick after completion")
	var captured := controller.spiritualist_drain_state.captured_request.copy()
	controller.spiritualist_drain_state.start(enemy, player.global_position, captured)
	player.move_to(Vector2(450, 400))
	_check(not controller.spiritualist_drain_state.active and player.character_animation.state.action_remaining == 0.0, "movimento interrompe canal e solta pose de cast imediatamente")
	player.character_animation.observe(player.global_position, 0.016)
	player.character_animation.observe(player.global_position + Vector2(8, 0), 0.016)
	_check(player.character_animation.state.frame_index() in [4, 5, 6, 7], "após interromper, deslocamento volta aos frames de caminhada")
	controller.spiritualist_drain_state.start(enemy, player.global_position, captured)
	player.presentation_action.emit(&"cast", Vector2.RIGHT, 2.0)
	var incoming := DamageRequest.new()
	incoming.source_id = enemy.get_instance_id()
	incoming.target_id = player.get_instance_id()
	incoming.skill_id = &"basic_attack"
	incoming.physical_damage = 5.0
	incoming.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	player.apply_damage(incoming, controller.rng)
	_check(not controller.spiritualist_drain_state.active and player.character_animation.state.action_remaining == 0.0, "dano de HP interrompe canal e solta pose")
	controller.spiritualist_drain_state.start(enemy, player.global_position, captured)
	player.presentation_action.emit(&"cast", Vector2.RIGHT, 2.0)
	player.hard_controls.apply(&"stun", 0.5, 0.0)
	controller._advance_spiritualist_drain(0.01)
	_check(not controller.spiritualist_drain_state.active and player.character_animation.state.action_remaining == 0.0, "controle interrompe canal e solta pose")
	player.hard_controls.clear()
	player.presentation_action.emit(&"cast", Vector2.RIGHT, 0.6)
	controller._cancel_spiritualist_drain()
	_check(player.character_animation.state.action_remaining > 0.5, "cancelamento sem canal ativo não apaga cast novo")
	controller.spiritualist_drain_state.start(enemy, player.global_position, captured)
	enemy.global_position = Vector2(700, 350)
	controller._advance_spiritualist_drain(0.5)
	_check(not controller.spiritualist_drain_state.active, "loss of line of sight cancels future ticks")
	var blocked_sp := player.current_sp
	_check(not player.use_spiritualist_soul_drain(enemy) and player.current_sp == blocked_sp, "blocked target cannot start drain or spend SP")
	var capped := player.heal_from_spiritualist_drain({"source_id": player.get_instance_id(), "skill_id": &"spiritualist_soul_drain", "actual_damage": 10000.0}, 0.0)
	_check(capped <= player.health.max_hp * 0.05 + 0.001, "single huge tick still obeys channel heal cap")
	player.free()
	enemy.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Espiritualista Drenagem: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _on_drain_request(request: DamageRequest, enemy: CombatActor) -> void:
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	controller._on_spiritualist_drain_requested(request, enemy)

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
