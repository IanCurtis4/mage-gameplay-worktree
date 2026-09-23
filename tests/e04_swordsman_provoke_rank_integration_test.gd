extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	_check_debuff_channels()
	await _check_provoke_runtime()
	print("E04 SW2 Provocar: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var skill := ClassCatalog.skill_definition(&"provoke")
	var metadata := ProfileCatalog.pilot().skill_metadata(&"provoke")
	_check(skill != null and skill.display_name == "Provocar" and skill.handler_id == SkillDefinition.Handler.PROVOKE and skill.targeting == SkillDefinition.Targeting.SINGLE_TARGET and skill.action_kind == SkillDefinition.ActionKind.DEFENSIVE and skill.is_rank_catalog_valid(), "catálogo publica alvo único defensivo")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "biblioteca começa em R0")
	var durations: Array[float] = [2.0, 2.4, 2.8, 3.2, 3.6]
	var costs: Array[float] = [14.0, 16.0, 18.0, 19.0, 20.0]
	for index: int in 5:
		var rank := skill.rank_definition(index + 1)
		_check(rank.power == durations[index] and rank.sp_cost == costs[index] and rank.cooldown == 10.0 and rank.range == 300.0, "R%d escala duração e custo" % [index + 1])
		_check(rank.effect_ids == [&"taunt", &"physical_defense_reduction", &"flee_reduction"] and rank.physical_weight == 0.0 and rank.magic_weight == 0.0, "R%d não causa dano" % [index + 1])
	_check(skill.rank_definition(0) == null and skill.rank_definition(6) == null and &"provoke" not in ClassCatalog.class_definition(&"swordsman").skill_ids, "ranks inválidos e slots iniciais preservados")

func _check_debuff_channels() -> void:
	var state := AttributeDebuffState.new()
	_check(not state.apply(AttributeDebuffState.PHYSICAL_DEFENSE, &"", 0.4, 2.0) and not state.apply(&"unknown", &"x", 0.4, 2.0), "fontes e canais inválidos rejeitados")
	state.apply(AttributeDebuffState.PHYSICAL_DEFENSE, &"weak", 0.20, 6.0)
	state.apply(AttributeDebuffState.PHYSICAL_DEFENSE, &"strong", 0.40, 2.0)
	state.apply(AttributeDebuffState.FLEE, &"other", 0.30, 4.0)
	_check(state.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.40 and state.fraction(AttributeDebuffState.FLEE) == 0.30, "canais não se somam ou confundem")
	state.advance(2.1)
	_check(state.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.20 and state.remaining(AttributeDebuffState.PHYSICAL_DEFENSE, &"weak") > 3.8 and state.fraction(AttributeDebuffState.FLEE) == 0.30, "fonte fraca reaparece com duração própria")
	state.apply(AttributeDebuffState.PHYSICAL_DEFENSE, &"weak", 0.25, 3.0)
	_check(state.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.25 and state.remaining(AttributeDebuffState.PHYSICAL_DEFENSE, &"weak") == 3.0, "reaplicação renova só a mesma fonte")
	state.apply(AttributeDebuffState.PHYSICAL_DEFENSE, &"cap", 5.0, 1.0)
	_check(state.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.60 and StatCalculator.runtime_reduced_value(&"physical_defense", 100.0, state.fraction(AttributeDebuffState.PHYSICAL_DEFENSE)) == 40.0, "DEF conserva mitigação mesmo sob cap")
	state.apply(AttributeDebuffState.DAMAGE_RECEIVED, &"weak", 0.10, 5.0)
	state.apply(AttributeDebuffState.DAMAGE_RECEIVED, &"strong", 0.30, 1.0)
	state.advance(1.1)
	_check(state.fraction(AttributeDebuffState.DAMAGE_RECEIVED) == 0.10, "aumento de dano recebido segue mesma política")
	state.clear()
	_check(state.fraction(AttributeDebuffState.FLEE) == 0.0 and state.fraction(AttributeDebuffState.DAMAGE_RECEIVED) == 0.0, "limpeza retira todas as fontes")

func _check_provoke_runtime() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for rank: int in [0, 1, 5, 6]:
		var snapshot := BuildSnapshot.new()
		snapshot.character_id = "provoke-r%d" % rank
		snapshot.base_class_id = &"swordsman"
		snapshot.skill_ranks = {&"provoke": rank, &"shield_wall": 1}
		snapshot.active_slots = [&"provoke", &"shield_wall", null, null, null]
		var player := PlayerActor.new()
		player.configure(nav, RunState.from_build(snapshot.character_id, snapshot))
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var enemy := EnemyActor.new()
		enemy.configure(&"archer", nav, player)
		enemy.position = Vector2(450, 300)
		root.add_child(enemy)
		enemy.set_process(false)
		var controller := RunController.new()
		controller.player = player
		player.provoke_requested.connect(controller._on_provoke_requested)
		var before_sp := player.current_sp
		var used := player.use_provoke(enemy)
		if rank in [0, 6]:
			_check(not used and player.current_sp == before_sp and enemy.taunt_remaining == 0.0, "R%d não executa" % rank)
		else:
			_check(used and enemy.taunt_remaining == (2.0 if rank == 1 else 3.6) and player.current_sp == before_sp - (14.0 if rank == 1 else 20.0), "R%d aplica duração e SP" % rank)
			_check(enemy.attribute_debuffs.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == PlayerActor.PROVOKE_DEFENSE_REDUCTION and enemy.attribute_debuffs.fraction(AttributeDebuffState.FLEE) == PlayerActor.PROVOKE_FLEE_REDUCTION and player.skill_cooldown(&"provoke") > 0.0, "R%d aplica DEF/FLEE separados e recarga" % rank)
			_check(not player.use_provoke(enemy) and player.current_sp == before_sp - (14.0 if rank == 1 else 20.0), "R%d recarga rejeita segundo uso" % rank)
			enemy.global_position = Vector2(700, 300)
			enemy._process(0.5)
			_check(enemy.global_position.x < 700.0 and enemy.taunt_remaining > 0.0, "R%d arqueiro aproxima em vez de fugir" % rank)
			enemy.advance_statuses(1.0, true)
			_check(enemy.taunt_remaining > 0.0 and enemy.attribute_debuffs.remaining(AttributeDebuffState.FLEE) == PlayerActor.PROVOKE_DEBUFF_DURATION - 0.5, "R%d pausa não avança debuffs" % rank)
			enemy.clear_statuses()
			_check(enemy.taunt_remaining == 0.0 and enemy.attribute_debuffs.fraction(AttributeDebuffState.PHYSICAL_DEFENSE) == 0.0, "R%d limpeza retira estados" % rank)
		player.queue_free()
		enemy.queue_free()
		controller.free()
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW2: %s" % label)
