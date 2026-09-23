extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_runtime()
	print("E04 SW7 Raiva Concentrada: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"concentrated_rage")
	var meta := ProfileCatalog.pilot().skill_metadata(&"concentrated_rage")
	_check(skill != null and skill.display_name == "Raiva Concentrada" and skill.handler_id == SkillDefinition.Handler.CONCENTRATED_RAGE and skill.targeting == SkillDefinition.Targeting.DIRECTION and skill.action_kind == SkillDefinition.ActionKind.OFFENSIVE and skill.is_rank_catalog_valid(), "catálogo publica faixa direcional")
	_check(meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 5 and &"concentrated_rage" not in ClassCatalog.class_definition(&"swordsman").skill_ids, "R0 não ocupa slot")
	var powers: Array[float] = [1.45, 1.65, 1.83, 1.99, 2.12]
	var costs: Array[float] = [19.0, 21.0, 23.0, 24.0, 25.0]
	for index: int in 5:
		var rank := skill.rank_definition(index + 1)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index] and rank.variable_cast_time == 0.35 and rank.cooldown == 7.5 and rank.range == 230.0, "R%d escala dano, mantém preparo/faixa" % [index + 1])
	_check(SkillGeometry.strip_contains(Vector2(100, 20), Vector2.RIGHT, 230.0, 19.0, 2.0) and not SkillGeometry.strip_contains(Vector2(100, 50), Vector2.RIGHT, 230.0, 19.0, 2.0) and not SkillGeometry.strip_contains(Vector2(-50, 0), Vector2.RIGHT, 230.0, 19.0, 2.0), "geometria estreita respeita frente e largura")
	_check(skill.rank_definition(0) == null and skill.rank_definition(6) == null, "ranks inválidos não lançam")

func _check_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 5, 6]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "rage-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.skill_ranks = {&"concentrated_rage": rank, &"shield_wall": 1}
		snapshot.active_slots = [&"concentrated_rage", &"shield_wall", null, null, null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var targets: Array[CombatActor] = []
		for point: Vector2 in [Vector2(400, 300), Vector2(510, 300), Vector2(430, 350), Vector2(270, 300)]:
			var target := CombatActor.new()
			target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 50}), 19.0)
			target.position = point
			root.add_child(target)
			target.set_process(false)
			targets.append(target)
		var emissions: Array[DamageRequest] = []
		player.attack_requested.connect(func(request: DamageRequest, target: CombatActor) -> void:
			emissions.append(request)
			target.apply_damage(request, RandomNumberGenerator.new())
		)
		player.use_shield_wall(Vector2.RIGHT)
		player.current_sp = player.max_sp
		var before_sp := player.current_sp
		var used := player.use_concentrated_rage(Vector2.RIGHT, targets)
		if rank in [0, 6]:
			_check(not used and emissions.is_empty() and player.current_sp == before_sp and player.has_shield_stance(), "R%d rejeita sem cancelar postura" % rank)
		else:
			_check(used and not player.has_shield_stance() and player.current_sp == before_sp - (19.0 if rank == 1 else 25.0) and player.skill_cooldown(&"concentrated_rage") > 0.0, "R%d cobra e cancela postura no commit" % rank)
			_check(emissions.size() == 2 and emissions[0].target_id == targets[0].get_instance_id() and emissions[1].target_id == targets[1].get_instance_id(), "R%d atravessa dois alvos sem atingir flanco/costas" % rank)
			_check(is_equal_approx(emissions[0].physical_damage, player.stat_breakdown.value(&"melee_attack") * (1.45 if rank == 1 else 2.12)) and emissions[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "R%d captura dano por rank sem segundo HIT" % rank)
			_check(targets[0].health.current_hp < targets[0].health.max_hp and targets[1].health.current_hp < targets[1].health.max_hp and targets[2].health.current_hp == targets[2].health.max_hp, "R%d aplica dano a cada alvo da faixa" % rank)
			_check(player.velocity == Vector2.ZERO and not player._dash_active and player.target == null and player.concentrated_rage_visual_time > 0.0, "R%d firma os pés sem Investida" % rank)
			_check(not player.use_concentrated_rage(Vector2.RIGHT, targets) and emissions.size() == 2, "R%d recarga impede repetição" % rank)
		player.queue_free()
		for target: CombatActor in targets:
			target.queue_free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW7: %s" % label)
