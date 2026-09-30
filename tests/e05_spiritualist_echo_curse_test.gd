extends SceneTree

var checks := 0
var failures := 0
var controller: RunController

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var evolution := catalog.evolution_definition(&"spiritualist")
	_check(catalog.is_valid() and evolution != null and evolution.content_ready and evolution.entry_skill_id == &"spiritualist_echo_curse", "complete Spiritualist kit is available for real evolution")
	var metadata := catalog.skill_metadata(&"spiritualist_echo_curse")
	_check(metadata["free_rank"] == 1 and metadata["max_purchased_rank"] == 4 and metadata["rank_requirements"][1]["job_level"] == 20, "entry is free R1 at job 20 with four paid ranks")
	var definition := ClassCatalog.skill_definition(&"spiritualist_echo_curse")
	_check(definition != null and definition.is_rank_catalog_valid() and definition.handler_id == SkillDefinition.Handler.SPIRITUALIST_ECHO_CURSE, "typed rank catalog and dispatch are present")
	var powers: Array[float] = [0.85, 1.00, 1.12, 1.22, 1.30]
	var echoes: Array[float] = [0.35, 0.42, 0.49, 0.55, 0.60]
	for index: int in range(5):
		var rank := definition.rank_definition(index + 1)
		_check(is_equal_approx(rank.power, powers[index]) and is_equal_approx(rank.secondary_power, echoes[index]) and is_equal_approx(rank.cooldown, 6.0) and is_equal_approx(rank.range, 380.0), "R%d preserves direct/echo/range/cooldown" % (index + 1))
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 1000, 700), [Rect2(600, 300, 40, 100)], 20.0)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"spiritualist"
	snapshot.library_skill_ids = catalog.skill_ids_for_identity(&"mage", &"spiritualist")
	snapshot.skill_ranks = {&"spiritualist_echo_curse": 1}
	snapshot.active_slots = [&"spiritualist_echo_curse", null, null, null, null]
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("curse-test", snapshot))
	player.global_position = Vector2(400, 350)
	var enemy := _enemy(Vector2(500, 350))
	controller = RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.spiritualist_echo_state.source_id = player.get_instance_id()
	enemy.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	player.spiritualist_echo_curse_requested.connect(_on_curse_request)
	_check(player.character_animation.actor_kind == &"spiritualist", "evolved mage uses Spiritualist atlas")
	_check(is_equal_approx(player.skill_cast_time(&"spiritualist_echo_curse"), StatCalculator.effective_cast_time(0.0, 0.35, player.stat_breakdown)), "cast uses shared DEX formula")
	_check(player.begin_skill_cast(&"spiritualist_echo_curse", enemy.global_position, enemy), "curse begins cancellable cast")
	player.cancel_active_cast()
	_check(player.skill_cooldown(&"spiritualist_echo_curse") == 0.0 and player.current_sp == player.max_sp, "cancelled cast costs nothing")
	var sp_before := player.current_sp
	_check(player.use_spiritualist_echo_curse(enemy) and is_equal_approx(player.current_sp, sp_before - 18.0) and player.skill_cooldown(&"spiritualist_echo_curse") > 0.0, "commit spends ranked SP and cooldown")
	_check(controller.spiritualist_echo_state.has_mark(enemy.get_instance_id()), "positive surviving target receives mark")
	_check(controller.battle_indicators.spiritualist_events.size() == 1 and controller.battle_indicators.spiritualist_events[0]["kind"] == &"sigil", "real mark creates sigil animation")
	var state := controller.spiritualist_echo_state
	var invalid := _hit(player.get_instance_id(), enemy.get_instance_id(), &"soul_impact", false, 0.0)
	_check(not state.record_hit(invalid, 100.0) and state.has_mark(enemy.get_instance_id()), "miss or absorbed hit leaves mark")
	invalid["can_trigger_effects"] = false
	invalid["actual_damage"] = 20.0
	_check(not state.record_hit(invalid, 100.0), "secondary hit leaves mark")
	_check(not state.record_hit(_hit(player.get_instance_id(), enemy.get_instance_id(), &"spiritualist_echo_curse", true, 10.0), 100.0), "reapplying curse never consumes its own mark")
	var first_health := enemy.health.current_hp
	var trigger := DamageRequest.new()
	trigger.source_id = player.get_instance_id()
	trigger.target_id = enemy.get_instance_id()
	trigger.skill_id = &"basic_attack"
	trigger.magic_damage = 20.0
	trigger.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	enemy.apply_damage(trigger, controller.rng)
	_check(not state.has_mark(enemy.get_instance_id()) and state.pending.size() == 1 and enemy.health.current_hp < first_health, "one direct positive hit consumes mark and schedules one echo")
	_check(controller.battle_indicators.spiritualist_events[-1]["kind"] == &"echo_ready", "real consumption announces the delayed echo without claiming damage")
	_check(is_equal_approx(float(state.pending[0]["magic_damage"]), player.spiritualist_magic_attack() * 0.35), "echo captures ATQM at trigger")
	_check(state.advance(0.34).is_empty() and state.pending.size() == 1, "echo does not hit early")
	var before_echo := enemy.health.current_hp
	for due: Dictionary in state.advance(0.02):
		controller._apply_spiritualist_echo(due)
	_check(enemy.health.current_hp < before_echo and state.pending.is_empty() and not state.has_mark(enemy.get_instance_id()), "echo hits after 0.35s without cascade")
	_check(controller.battle_indicators.spiritualist_events[-1]["kind"] == &"echo_hit", "echo impact uses spectral burst only after real damage")
	state.mark(enemy.get_instance_id(), 0.60)
	_check(state.advance(5.01).is_empty() and not state.has_mark(enemy.get_instance_id()), "mark expires after five simulated seconds")
	state.mark(enemy.get_instance_id(), 0.35)
	root.add_child(player)
	paused = true
	player._process(6.0)
	_check(state.has_mark(enemy.get_instance_id()), "paused game does not advance mark without controller simulation")
	paused = false
	state.remove_target(enemy.get_instance_id())
	_check(not state.has_mark(enemy.get_instance_id()) and state.pending.is_empty(), "death removes target state")
	state.mark(enemy.get_instance_id(), 0.35)
	state.clear()
	_check(state.marks.is_empty() and state.pending.is_empty(), "encounter and run cleanup remove transient state")
	var base_snapshot := snapshot.copy_snapshot()
	base_snapshot.evolution_id = &""
	var base := PlayerActor.new()
	base.configure(nav, RunState.from_build("base", base_snapshot))
	_check(not base.use_spiritualist_echo_curse(enemy) and base.character_animation.actor_kind == &"mage", "base Mage cannot cast exclusive curse")
	player.free()
	base.free()
	enemy.free()
	controller.battle_indicators.free()
	controller.free()
	print("E05 Espiritualista Maldição do Eco: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _enemy(position: Vector2) -> CombatActor:
	var enemy := CombatActor.new()
	enemy.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	enemy.global_position = position
	enemy.health.max_hp = 10000.0
	enemy.health.current_hp = 10000.0
	return enemy

func _on_curse_request(request: DamageRequest, target: CombatActor, power: float) -> void:
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	controller._on_spiritualist_echo_curse_requested(request, target, power)

func _hit(source_id: int, target_id: int, skill_id: StringName, triggers: bool, damage: float) -> Dictionary:
	return {"source_id": source_id, "target_id": target_id, "skill_id": skill_id, "can_trigger_effects": triggers, "actual_damage": damage}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
