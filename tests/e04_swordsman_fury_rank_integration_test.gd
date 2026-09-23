extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_runtime()
	print("E04 SW5 Fúria: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"fury")
	var meta := ProfileCatalog.pilot().skill_metadata(&"fury")
	_check(skill != null and skill.display_name == "Fúria" and skill.handler_id == SkillDefinition.Handler.FURY and skill.targeting == SkillDefinition.Targeting.SELF and skill.action_kind == SkillDefinition.ActionKind.OFFENSIVE and skill.is_rank_catalog_valid(), "catálogo publica buff ofensivo")
	_check(meta.get("free_rank") == 0 and meta.get("max_purchased_rank") == 5 and &"fury" not in ClassCatalog.class_definition(&"swordsman").skill_ids, "R0 não ocupa slot inicial")
	var powers: Array[float] = [0.30, 0.38, 0.45, 0.51, 0.56]
	var costs: Array[float] = [22.0, 24.0, 26.0, 27.0, 28.0]
	for index: int in 5:
		var rank := skill.rank_definition(index + 1)
		var source := ClassCatalog.active_modifier_source(&"fury", rank)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index] and rank.cooldown == 14.0, "R%d aumenta benefício com custos côncavos" % [index + 1])
		_check(source["increased"][&"melee_attack"] == powers[index] and source["increased"][&"attacks_per_second"] == powers[index] * 0.60 and source["increased"][&"physical_defense"] == -0.25 and source["increased"][&"magic_defense"] == -0.25, "R%d mantém penalidade fixa" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(6) == null, "ranks inválidos não lançam")

func _check_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 5, 6]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "fury-%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.skill_ranks = {&"fury": rank, &"shield_wall": 1}
		snapshot.active_slots = [&"fury", &"shield_wall", null, null, null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var base_melee := player.stat_breakdown.value(&"melee_attack")
		var base_aps := player.stat_breakdown.value(&"attacks_per_second")
		var base_def := player.stat_breakdown.value(&"physical_defense")
		var base_magic_def := player.stat_breakdown.value(&"magic_defense")
		player.use_shield_wall(Vector2.RIGHT)
		var before_sp := player.current_sp
		var used := player.use_fury()
		if rank in [0, 6]:
			_check(not used and player.current_sp == before_sp and player.has_shield_stance() and player.fury_remaining == 0.0, "R%d rejeita sem cancelar postura" % rank)
		else:
			var power := 0.30 if rank == 1 else 0.56
			_check(used and not player.has_shield_stance() and player.current_sp == before_sp - (22.0 if rank == 1 else 28.0) and player.fury_remaining == 6.0, "R%d inicia buff e cancela postura" % rank)
			_check(is_equal_approx(player.stat_breakdown.value(&"melee_attack"), base_melee * (1.0 + power)) and is_equal_approx(player.stat_breakdown.value(&"attacks_per_second"), base_aps * (1.0 + power * 0.60)), "R%d aumenta melee e ASPD pelo cálculo canônico" % rank)
			_check(is_equal_approx(player.stat_breakdown.value(&"physical_defense"), base_def * 0.75) and is_equal_approx(player.stat_breakdown.value(&"magic_defense"), base_magic_def * 0.75), "R%d reduz DEF física e mágica" % rank)
			_check(not player.use_fury() and player.skill_cooldown(&"fury") > 0.0, "R%d recarga rejeita repetição" % rank)
			player._process(2.0)
			_check(player.fury_remaining == 4.0, "R%d janela avança em simulação" % rank)
			player.apply_run_modifiers(player.run_state)
			_check(is_equal_approx(player.stat_breakdown.value(&"melee_attack"), base_melee * (1.0 + power)) and player.stat_breakdown.sources().filter(func(source: Dictionary) -> bool: return source["source_id"] == &"active_fury").size() == 1, "R%d recálculo não duplica fonte" % rank)
			player.clear_fury()
			_check(player.fury_remaining == 0.0 and player.stat_breakdown.value(&"melee_attack") == base_melee and player.stat_breakdown.value(&"physical_defense") == base_def and player.stat_breakdown.value(&"magic_defense") == base_magic_def, "R%d limpeza restaura stats" % rank)
		player.queue_free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW5: %s" % label)
