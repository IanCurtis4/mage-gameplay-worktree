extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_runtime()
	print("E04 SW6 Golpe Brutal: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"brutal_strike")
	var meta := ProfileCatalog.pilot().skill_metadata(&"brutal_strike")
	_check(skill != null and skill.display_name == "Golpe Brutal" and skill.handler_id == SkillDefinition.Handler.BRUTAL_STRIKE and skill.targeting == SkillDefinition.Targeting.SINGLE_TARGET and skill.action_kind == SkillDefinition.ActionKind.OFFENSIVE and skill.is_rank_catalog_valid(), "catálogo publica golpe corpo a corpo")
	_check(meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 5 and &"brutal_strike" not in ClassCatalog.class_definition(&"swordsman").skill_ids, "R0 não ocupa slot")
	var powers: Array[float] = [2.20, 2.55, 2.85, 3.10, 3.30]
	var costs: Array[float] = [20.0, 23.0, 25.0, 27.0, 28.0]
	for index: int in 5:
		var rank := skill.rank_definition(index + 1)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index] and rank.variable_cast_time == 0.55 and rank.cooldown == 8.0 and rank.range == 110.0 and rank.physical_weight == 1.0, "R%d prioriza dano com preparo" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(6) == null, "ranks inválidos não lançam")

func _check_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 5, 6]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "brutal-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.skill_ranks = {&"brutal_strike": rank, &"shield_wall": 1}
		snapshot.active_slots = [&"brutal_strike", &"shield_wall", null, null, null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var target := CombatActor.new()
		target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 50}), 19.0)
		target.position = Vector2(390, 300)
		root.add_child(target)
		target.set_process(false)
		var controller := RunController.new()
		controller.player = player
		player.brutal_strike_requested.connect(controller._on_brutal_strike_requested)
		var results: Array[Dictionary] = []
		target.health.damage_applied.connect(func(result: Dictionary) -> void: results.append(result))
		player.use_shield_wall(Vector2.RIGHT)
		player.current_sp = player.max_sp
		var before_sp := player.current_sp
		if rank in [0, 6]:
			_check(not player.use_brutal_strike(target) and player.has_shield_stance() and player.current_sp == before_sp, "R%d rejeita sem cancelar postura" % rank)
		else:
			var cast_time := player.skill_cast_time(&"brutal_strike")
			_check(cast_time > 0.0 and player.begin_skill_cast(&"brutal_strike", target.global_position, target) and player.current_sp == before_sp and player.has_shield_stance(), "R%d prepara sem custo antecipado" % rank)
			player.cancel_active_cast()
			_check(not player.has_active_cast() and player.current_sp == before_sp and target.attribute_debuffs.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.0, "R%d cancelamento não aplica dano/debuff" % rank)
			var old_defense := target.health.physical_defense
			var used := player.use_brutal_strike(target)
			_check(used and not player.has_shield_stance() and player.current_sp == before_sp - (20.0 if rank == 1 else 28.0) and player.skill_cooldown(&"brutal_strike") > 0.0, "R%d commit cancela postura e cobra uma vez" % rank)
			_check(results.size() == 1 and is_equal_approx(float(results[0]["physical_component"]), player.stat_breakdown.value(&"melee_attack") * (2.20 if rank == 1 else 3.30) * 100.0 / (100.0 + old_defense)), "R%d próprio impacto usa defesa anterior" % rank)
			_check(target.attribute_debuffs.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.30 and target.attribute_debuffs.remaining(AttributeDebuffState.PHYSICAL_DEFENSE) == 4.0 and target.is_alive(), "R%d debuff entra após dano positivo" % rank)
			_check(not player.use_brutal_strike(target) and results.size() == 1, "R%d recarga não duplica impacto" % rank)
			target.advance_statuses(5.0)
			_check(target.attribute_debuffs.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.0, "R%d debuff expira" % rank)
		player.queue_free()
		target.queue_free()
		controller.free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW6: %s" % label)
