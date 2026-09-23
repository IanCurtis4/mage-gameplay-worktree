extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_runtime()
	print("E04 SW8 Grito Aterrorizante: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"terrifying_shout")
	var meta := ProfileCatalog.pilot().skill_metadata(&"terrifying_shout")
	_check(skill != null and skill.display_name == "Grito Aterrorizante" and skill.handler_id == SkillDefinition.Handler.TERRIFYING_SHOUT and skill.targeting == SkillDefinition.Targeting.SELF and skill.action_kind == SkillDefinition.ActionKind.OFFENSIVE and skill.is_rank_catalog_valid(), "catálogo publica fear em área")
	_check(meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 5 and &"terrifying_shout" not in ClassCatalog.class_definition(&"swordsman").skill_ids, "R0 sem slot inicial")
	var durations: Array[float] = [0.75, 0.90, 1.00, 1.10, 1.15]
	var costs: Array[float] = [20.0, 22.0, 24.0, 25.0, 26.0]
	for index: int in 5:
		var rank := skill.rank_definition(index + 1)
		_check(rank.power == durations[index] and rank.sp_cost == costs[index] and rank.cooldown == 11.0 and rank.range == 170.0 and rank.effect_ids == [&"fear", &"damage_received_increase"], "R%d prioriza fear curto" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(6) == null, "ranks inválidos não lançam")

func _check_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 5, 6]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "terrify-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.skill_ranks = {&"terrifying_shout": rank, &"shield_wall": 1}
		snapshot.active_slots = [&"terrifying_shout", &"shield_wall", null, null, null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var near := _enemy(nav, player, Vector2(400, 300))
		var immune := _enemy(nav, player, Vector2(350, 350))
		immune.set_unstoppable(2.0)
		var far := _enemy(nav, player, Vector2(600, 300))
		var controller := RunController.new()
		controller.player = player
		controller.enemies.append(near)
		controller.enemies.append(immune)
		controller.enemies.append(far)
		player.terrifying_shout_requested.connect(controller._on_terrifying_shout_requested)
		player.use_shield_wall(Vector2.RIGHT)
		player.current_sp = player.max_sp
		var before_sp := player.current_sp
		var near_hp := near.health.current_hp
		var used := player.use_terrifying_shout()
		if rank in [0, 6]:
			_check(not used and player.has_shield_stance() and player.current_sp == before_sp and not near.is_feared(), "R%d rejeita sem cancelar postura" % rank)
		else:
			_check(used and not player.has_shield_stance() and player.current_sp == before_sp - (20.0 if rank == 1 else 26.0) and player.skill_cooldown(&"terrifying_shout") > 0.0, "R%d cobra e cancela postura" % rank)
			_check(near.health.current_hp == near_hp and near.is_feared() and near.fear_remaining() <= HardControlState.NORMAL_DURATION_CAP and player.terrifying_shout_visual_time > 0.0, "R%d aplica fear sem dano direto" % rank)
			_check(not immune.is_feared() and immune.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_RECEIVED) == 0.20 and not far.is_feared() and far.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_RECEIVED) == 0.0, "R%d imunidade bloqueia fear mas não aumento de dano" % rank)
			var request := DamageRequest.new()
			request.source_id = player.get_instance_id()
			request.physical_damage = 30.0
			request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
			request.can_crit = false
			request.target_id = near.get_instance_id()
			var amplified := near.apply_damage(request, RandomNumberGenerator.new())
			request.target_id = far.get_instance_id()
			var plain := far.apply_damage(request, RandomNumberGenerator.new())
			_check(int(amplified["damage"]) > int(plain["damage"]) and request.damage_dealt_multiplier == 1.0, "R%d dano recebido compõe cópia sem mutar pedido" % rank)
			var remaining := near.fear_remaining()
			near.advance_statuses(1.0, true)
			_check(near.fear_remaining() == remaining and near.attribute_debuffs.remaining(AttributeDebuffState.DAMAGE_RECEIVED) == 3.0, "R%d pausa congela fear e debuff" % rank)
			near.clear_statuses()
			_check(not near.is_feared() and near.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_RECEIVED) == 0.0, "R%d limpeza retira ambos" % rank)
		player.queue_free()
		near.queue_free()
		immune.queue_free()
		far.queue_free()
		controller.free()
		await process_frame

func _enemy(nav: ArenaNavigation, player: PlayerActor, point: Vector2) -> EnemyActor:
	var enemy := EnemyActor.new()
	enemy.configure(&"warrior", nav, player)
	enemy.position = point
	root.add_child(enemy)
	enemy.set_process(false)
	return enemy

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW8: %s" % label)
