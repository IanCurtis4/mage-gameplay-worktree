extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_ranked_shield()
	print("E04 SW3 Perseverança: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"perseverance")
	var meta := ProfileCatalog.pilot().skill_metadata(&"perseverance")
	_check(skill != null and skill.display_name == "Perseverança" and skill.handler_id == SkillDefinition.Handler.PERSEVERANCE and skill.targeting == SkillDefinition.Targeting.SELF and skill.action_kind == SkillDefinition.ActionKind.DEFENSIVE and skill.is_rank_catalog_valid(), "catálogo publica escudo pessoal defensivo")
	_check(meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 5 and &"perseverance" not in ClassCatalog.class_definition(&"swordsman").skill_ids, "R0 sem ocupar slot inicial")
	var bases: Array[float] = [40.0, 55.0, 68.0, 80.0, 90.0]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in 5:
		var rank := skill.rank_definition(index + 1)
		_check(rank.power == bases[index] and rank.sp_cost == costs[index] and rank.cooldown == 10.0 and rank.effect_ids == [&"personal_shield"], "R%d aumenta capacidade-base sem mudar duração" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(6) == null, "ranks inválidos não têm fallback")

func _check_ranked_shield() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 5, 6]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "perseverance-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.attribute_allocations = {&"vit": 6, &"int": 4}
		snapshot.skill_ranks = {&"perseverance": rank, &"shield_wall": 1}
		snapshot.active_slots = [&"perseverance", &"shield_wall", null, null, null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var initial_sp := player.current_sp
		var used := player.use_perseverance()
		if rank in [0, 6]:
			_check(not used and player.current_sp == initial_sp and player.health.shield_hp == 0.0, "R%d rejeita uso sem gasto" % rank)
		else:
			var expected_capacity := StatCalculator.personal_shield_capacity(40.0 if rank == 1 else 90.0, player.stat_breakdown)
			_check(used and player.health.shield_hp == expected_capacity and player.perseverance_remaining == 6.0, "R%d usa VIT/INT efetivas e duração fixa" % rank)
			_check(player.current_sp == initial_sp - (18.0 if rank == 1 else 24.0) and player.skill_cooldown(&"perseverance") == StatCalculator.effective_cooldown(10.0, player.stat_breakdown), "R%d cobra e inicia recarga" % rank)
			_check(not player.use_perseverance() and player.health.shield_hp == expected_capacity, "R%d recarga não empilha escudo" % rank)
			player.mage_cooldowns[&"shield_wall"] = 0.0
			_check(player.use_shield_wall(Vector2.RIGHT) and player.has_shield_stance() and player.health.shield_hp == expected_capacity, "R%d postura e escudo coexistem" % rank)
			var source := CombatActor.new()
			source.setup("Fonte", Color.WHITE, StatCalculator.calculate({&"str": 1}))
			source.position = Vector2(400, 300)
			root.add_child(source)
			source.set_process(false)
			var request := DamageRequest.new()
			request.source_id = source.get_instance_id()
			request.target_id = player.get_instance_id()
			request.physical_damage = 100.0
			request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
			request.can_crit = false
			var before_hp := player.health.current_hp
			var before_shield := player.health.shield_hp
			var result := player.apply_damage(request, RandomNumberGenerator.new())
			_check(float(result["absorbed_damage"]) > 0.0 and float(result["absorbed_damage"]) <= float(result["damage"]) and player.health.shield_hp == before_shield - float(result["absorbed_damage"]), "R%d resolve dano uma vez e absorve antes do HP" % rank)
			_check(player.health.current_hp == before_hp - float(result["actual_damage"]) and float(result["actual_damage"]) + float(result["absorbed_damage"]) == float(result["damage"]), "R%d registra partes absorvida e HP sem duplicação" % rank)
			player.advance_statuses(2.0, true)
			_check(player.perseverance_remaining == 6.0, "R%d pausa não avança escudo" % rank)
			player._process(6.1)
			_check(player.perseverance_remaining == 0.0 and player.health.shield_hp == 0.0, "R%d expiração limpa capacidade" % rank)
			source.queue_free()
		player.queue_free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW3: %s" % label)
