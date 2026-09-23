extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_runtime()
	print("E04 SW4 Grito Perfurante: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"piercing_shout")
	var meta := ProfileCatalog.pilot().skill_metadata(&"piercing_shout")
	_check(skill != null and skill.display_name == "Grito Perfurante" and skill.handler_id == SkillDefinition.Handler.PIERCING_SHOUT and skill.targeting == SkillDefinition.Targeting.SELF and skill.action_kind == SkillDefinition.ActionKind.OFFENSIVE and skill.is_rank_catalog_valid(), "catálogo publica pulso ofensivo")
	_check(meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 5 and &"piercing_shout" not in ClassCatalog.class_definition(&"swordsman").skill_ids, "biblioteca R0 sem slot inicial")
	var durations: Array[float] = [1.5, 1.9, 2.2, 2.4, 2.5]
	var costs: Array[float] = [17.0, 19.0, 21.0, 22.0, 23.0]
	for index: int in 5:
		var rank := skill.rank_definition(index + 1)
		_check(rank.power == durations[index] and rank.sp_cost == costs[index] and rank.cooldown == 8.0 and rank.range == 140.0 and rank.physical_weight == 1.0, "R%d prioriza duração limitada" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(6) == null, "ranks inválidos não lançam")

func _check_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 5, 6]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "shout-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.skill_ranks = {&"piercing_shout": rank, &"shield_wall": 1}
		snapshot.active_slots = [&"piercing_shout", &"shield_wall", null, null, null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var near := EnemyActor.new()
		near.configure(&"warrior", nav, player)
		near.position = Vector2(380, 300)
		root.add_child(near)
		near.set_process(false)
		var far := EnemyActor.new()
		far.configure(&"warrior", nav, player)
		far.position = Vector2(520, 300)
		root.add_child(far)
		far.set_process(false)
		var controller := RunController.new()
		controller.player = player
		controller.enemies.append(near)
		controller.enemies.append(far)
		player.piercing_shout_requested.connect(controller._on_piercing_shout_requested)
		player.use_shield_wall(Vector2.RIGHT)
		var before_sp := player.current_sp
		var near_hp := near.health.current_hp
		var far_hp := far.health.current_hp
		var used := player.use_piercing_shout()
		if rank in [0, 6]:
			_check(not used and player.current_sp == before_sp and player.has_shield_stance() and near.health.current_hp == near_hp, "R%d rejeita sem cancelar postura" % rank)
		else:
			_check(used and not player.has_shield_stance() and player.current_sp == before_sp - (17.0 if rank == 1 else 23.0), "R%d cancela postura válida e cobra SP" % rank)
			_check(near.health.current_hp < near_hp and far.health.current_hp == far_hp and player.piercing_shout_visual_time > 0.0, "R%d só atinge raio e cria pulso visual" % rank)
			_check(near.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) == 0.30 and near.attribute_debuffs.fraction(AttributeDebuffState.ATTACK_SPEED) == 0.25 and near.attribute_debuffs.remaining(AttributeDebuffState.ATTACK_SPEED) == (1.5 if rank == 1 else 2.5), "R%d aplica slow e ASPD em canais separados" % rank)
			_check(not player.use_piercing_shout() and player.skill_cooldown(&"piercing_shout") > 0.0, "R%d recarga impede repetição" % rank)
			var before_duration := near.attribute_debuffs.remaining(AttributeDebuffState.ATTACK_SPEED)
			near.advance_statuses(1.0, true)
			_check(near.attribute_debuffs.remaining(AttributeDebuffState.ATTACK_SPEED) == before_duration, "R%d pausa congela debuff" % rank)
			near.advance_statuses(3.0)
			_check(near.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) == 0.0 and near.attribute_debuffs.fraction(AttributeDebuffState.ATTACK_SPEED) == 0.0, "R%d expiração restaura ambos" % rank)
		player.queue_free()
		near.queue_free()
		far.queue_free()
		controller.free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW4: %s" % label)
