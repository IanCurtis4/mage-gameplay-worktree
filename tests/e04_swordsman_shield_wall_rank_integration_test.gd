extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog()
	await _check_ranked_stance()
	await _check_movement_and_actions()
	await _check_damage_and_projectiles()
	await _check_profile_and_controller()
	print("E04 SW1 Parede de Escudos: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog() -> void:
	var definition := ClassCatalog.skill_definition(&"shield_wall")
	var metadata := ProfileCatalog.pilot().skill_metadata(&"shield_wall")
	_check(definition != null and definition.display_name == "Parede de Escudos" and definition.handler_id == SkillDefinition.Handler.SHIELD_WALL and definition.targeting == SkillDefinition.Targeting.DIRECTION and definition.is_rank_catalog_valid(), "catálogo publica postura direcional")
	_check(definition.action_kind == SkillDefinition.ActionKind.DEFENSIVE and ClassCatalog.skill_definition(&"slash").action_kind == SkillDefinition.ActionKind.OFFENSIVE and ClassCatalog.skill_definition(&"dash").action_kind == SkillDefinition.ActionKind.MOBILITY, "ações têm classificação explícita")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "biblioteca persistente começa em R0")
	var capacities: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == capacities[index] and rank.sp_cost == costs[index], "R%d escala só resistência e SP" % [index + 1])
		_check(rank.cooldown == 12.0 and rank.range == PlayerActor.SHIELD_RADIUS and rank.fixed_cast_time == 0.0 and rank.variable_cast_time == 0.0 and rank.effect_ids == [&"front_projectile_block", &"front_damage_reduction"], "R%d mantém recarga e geometria" % [index + 1])
		_check(rank.physical_weight == 0.0 and rank.magic_weight == 0.0 and rank.precision_weight == 0.0, "R%d não causa dano" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "R0/R6 inválidos não têm fallback")
	var copy := definition.rank_definition(5)
	copy.power = 99.0
	_check(definition.rank_definition(5).power == 6.0, "consulta não altera recurso do catálogo")
	_check(&"shield_wall" not in ClassCatalog.class_definition(&"swordsman").skill_ids and ProfileCatalog.pilot().initial_skill_slots(&"swordsman")["active_slots"] == [null, null, null, null, null], "biblioteca não ocupa slot inicial")

func _check_ranked_stance() -> void:
	for rank: int in [0, 1, 5, 6]:
		var nav := _navigation()
		var state := RunState.from_build("shield-r%d" % rank, _snapshot(rank))
		var player := PlayerActor.new()
		player.configure(nav, state)
		player.position = Vector2(300, 300)
		root.add_child(player)
		player.set_process(false)
		var before_sp := player.current_sp
		var used := player.use_shield_wall(Vector2.RIGHT)
		if rank in [0, 6]:
			_check(not used and not player.has_shield_stance() and player.current_sp == before_sp and player.skill_rank_definition(&"shield_wall") == null, "R%d inválido não ativa/gasta" % rank)
		else:
			var expected_cost := 18.0 if rank == 1 else 24.0
			var expected_capacity := 2 if rank == 1 else 6
			_check(used and player.has_shield_stance() and player.shield_resistance == expected_capacity and player.shield_remaining == PlayerActor.SHIELD_DURATION and player.shield_facing == Vector2.RIGHT, "R%d captura resistência, duração e frente" % rank)
			_check(player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"shield_wall") == StatCalculator.effective_cooldown(12.0, player.stat_breakdown), "R%d inicia custo/recarga na ativação" % rank)
			var cooldown := player.skill_cooldown(&"shield_wall")
			player.current_sp = 0.0
			_check(player.use_shield_wall(Vector2.LEFT) and not player.has_shield_stance() and player.current_sp == 0.0 and player.skill_cooldown(&"shield_wall") == cooldown, "R%d toggle desliga sem custo apesar da recarga" % rank)
			_check(not player.use_shield_wall(Vector2.RIGHT) and not player.has_shield_stance(), "R%d não reativa em recarga/SP zero" % rank)
			player.mage_cooldowns[&"shield_wall"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_shield_wall(Vector2.RIGHT) and player.current_sp == expected_cost - 1.0, "R%d rejeita SP insuficiente")
		player.queue_free()
		await process_frame

func _check_movement_and_actions() -> void:
	var nav := _navigation()
	var state := RunState.from_build("shield-actions", _snapshot(5, true))
	var player := PlayerActor.new()
	player.configure(nav, state)
	player.position = Vector2(300, 300)
	root.add_child(player)
	player.set_process(false)
	var old_target := _target(Vector2(500, 300))
	root.add_child(old_target)
	old_target.set_process(false)
	player.pursue(old_target)
	_check(player.target == old_target, "fixture registra perseguição antiga")
	_check(player.use_shield_wall(Vector2.RIGHT) and player.target == null and player._path.is_empty(), "ativar postura limpa auto antigo")
	player._process(0.25)
	_check(player.has_shield_stance() and player.attack_cooldown == 0.0, "auto antigo não derruba postura no frame seguinte")
	var speed := player.stat_breakdown.value(&"move_speed")
	player.move_to(Vector2(360, 300))
	player._process(0.20)
	_check(player.global_position.x > 300.0 and player.stat_breakdown.value(&"move_speed") == speed and player.movement_speed_multiplier() == 1.0 and player.shield_facing == Vector2.RIGHT, "movimento livre acompanha postura sem girar frente")
	player.mage_cooldowns[&"dash"] = 0.0
	_check(player.use_dash(Vector2.UP) and player.has_shield_stance() and player.shield_facing == Vector2.RIGHT, "Investida é mobilidade e mantém orientação fixa")
	player._advance_dash(PlayerActor.DASH_DURATION)
	_check(player.has_shield_stance() and player.shield_facing == Vector2.RIGHT, "fim da Investida não altera frente")
	player.current_sp = 0.0
	_check(not player.use_slash(Vector2.RIGHT, [old_target]) and player.has_shield_stance(), "Corte inválido por SP não cancela")
	player.current_sp = player.max_sp
	player.slash_cooldown = 1.0
	_check(not player.use_slash(Vector2.RIGHT, [old_target]) and player.has_shield_stance(), "Corte em recarga não cancela")
	player.slash_cooldown = 0.0
	var stance_at_emission := [true]
	player.attack_requested.connect(func(_request: DamageRequest, _enemy: CombatActor) -> void: stance_at_emission[0] = player.has_shield_stance())
	old_target.global_position = player.global_position + Vector2(45, 0)
	_check(player.use_slash(Vector2.RIGHT, [old_target]) and not player.has_shield_stance() and not stance_at_emission[0], "Corte válido cancela antes de emitir dano")
	player.mage_cooldowns[&"shield_wall"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_shield_wall(Vector2.RIGHT), "postura reativa após recarga")
	var invalid := _target(Vector2(500, 300))
	root.add_child(invalid)
	invalid.set_process(false)
	invalid.health.current_hp = 0.0
	player.pursue(invalid)
	_check(player.has_shield_stance(), "ordem contra alvo morto não cancela")
	player.pursue(old_target)
	_check(not player.has_shield_stance(), "nova ordem ofensiva válida cancela")
	player.attack_cooldown = 0.0
	player.mage_cooldowns[&"shield_wall"] = 0.0
	player.current_sp = player.max_sp
	player.use_shield_wall(Vector2.RIGHT)
	player.target = old_target
	player.attack_cooldown = 1.0
	player._try_basic_attack()
	_check(player.has_shield_stance(), "auto em recarga não cancela postura")
	player.attack_cooldown = 0.0
	var shield_at_auto := [true]
	player.attack_requested.connect(func(_request: DamageRequest, _enemy: CombatActor) -> void: shield_at_auto[0] = player.has_shield_stance())
	player._try_basic_attack()
	_check(player.attack_cooldown > 0.0 and not player.has_shield_stance() and not shield_at_auto[0], "auto novo cancela postura antes de emitir")
	player.mage_cooldowns[&"shield_wall"] = 0.0
	player.current_sp = player.max_sp
	player.use_shield_wall(Vector2.RIGHT)
	var remaining := player.shield_remaining
	paused = true
	player._process(3.0)
	paused = false
	_check(player.shield_remaining == remaining, "pausa congela duração")
	player._process(remaining)
	_check(not player.has_shield_stance(), "duração expira sem deixar postura")
	player.mage_cooldowns[&"shield_wall"] = 0.0
	player.current_sp = player.max_sp
	player.use_shield_wall(Vector2.RIGHT)
	player._on_health_died(player.get_instance_id())
	_check(not player.has_shield_stance(), "morte limpa postura")
	player.queue_free()
	old_target.queue_free()
	invalid.queue_free()
	await process_frame

func _check_damage_and_projectiles() -> void:
	var nav := _navigation()
	var player := PlayerActor.new()
	player.configure(nav, RunState.from_build("shield-combat", _snapshot(5)))
	player.position = Vector2(400, 250)
	root.add_child(player)
	player.set_process(false)
	var front := _target(Vector2(650, 250))
	var back := _target(Vector2(150, 250))
	var flank := _target(Vector2(400, 80))
	for actor: CombatActor in [front, back, flank]:
		root.add_child(actor)
		actor.set_process(false)
	player.use_shield_wall(Vector2.RIGHT)
	var request := DamageRequest.new()
	request.target_id = player.get_instance_id()
	request.source_id = front.get_instance_id()
	request.physical_damage = 80.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	var rng := RandomNumberGenerator.new()
	var front_result := player.apply_damage(request, rng)
	var reduced := request.copy()
	reduced.damage_dealt_multiplier *= 1.0 - PlayerActor.SHIELD_FRONT_REDUCTION
	var expected := CombatMath.resolve(reduced, player.health.physical_defense, player.health.magic_defense, player.health.flee_rating, player.health.crit_resistance, 0.0, 0.0)
	_check(int(front_result["damage"]) == int(expected["damage"]) and request.damage_dealt_multiplier == 1.0, "frente mitiga sem alterar pedido capturado")
	player.health.current_hp = player.health.max_hp
	request.magic_damage = 40.0
	var mixed_result := player.apply_damage(request, rng)
	var mixed_reduced := request.copy()
	mixed_reduced.damage_dealt_multiplier *= 1.0 - PlayerActor.SHIELD_FRONT_REDUCTION
	var mixed_expected := CombatMath.resolve(mixed_reduced, player.health.physical_defense, player.health.magic_defense, player.health.flee_rating, player.health.crit_resistance, 0.0, 0.0)
	_check(int(mixed_result["damage"]) == int(mixed_expected["damage"]), "mitigação frontal usa pipeline canônico para dano misto")
	request.magic_damage = 0.0
	player.health.current_hp = player.health.max_hp
	request.source_id = back.get_instance_id()
	var rear_result := player.apply_damage(request, rng)
	var full := CombatMath.resolve(request, player.health.physical_defense, player.health.magic_defense, player.health.flee_rating, player.health.crit_resistance, 0.0, 0.0)
	_check(int(rear_result["damage"]) == int(full["damage"]) and int(rear_result["damage"]) > int(front_result["damage"]), "costas recebem dano integral")
	player.health.current_hp = player.health.max_hp
	request.source_id = flank.get_instance_id()
	var flank_result := player.apply_damage(request, rng)
	_check(int(flank_result["damage"]) == int(full["damage"]), "flanco recebe dano integral")
	player.health.current_hp = player.health.max_hp
	request.source_id = front.get_instance_id()
	request.is_secondary = true
	_check(int(player.apply_damage(request, rng)["damage"]) == int(full["damage"]), "dano secundário não recebe mitigação direcional")
	request.is_secondary = false
	player.health.current_hp = player.health.max_hp
	var caster := _target(Vector2(330, 250))
	root.add_child(caster)
	caster.set_process(false)
	var phantom := PhantomBarrier.new()
	phantom.configure(caster, Vector2.RIGHT, [], 210.0, 2)
	root.add_child(phantom)
	phantom.set_process(false)
	var first_arrow := _arrow(front, player, nav)
	root.add_child(first_arrow)
	first_arrow.set_process(false)
	first_arrow._process(1.0)
	_check(first_arrow.is_queued_for_deletion() and phantom.remaining_capacity == 1 and player.shield_resistance == 6, "barreira fantasma mais próxima intercepta primeiro")
	phantom.queue_free()
	await process_frame
	var second_arrow := _arrow(front, player, nav)
	root.add_child(second_arrow)
	second_arrow.set_process(false)
	var second_hits := [0]
	second_arrow.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: second_hits[0] += 1)
	second_arrow._process(1.0)
	_check(second_arrow.is_queued_for_deletion() and second_hits[0] == 0 and player.shield_resistance == 5, "flecha frontal rápida gasta uma resistência sem atingir")
	var rear_arrow := _arrow(back, player, nav)
	root.add_child(rear_arrow)
	rear_arrow.set_process(false)
	var rear_hits := [0]
	rear_arrow.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: rear_hits[0] += 1)
	rear_arrow._process(1.0)
	_check(rear_hits[0] == 1 and player.shield_resistance == 5, "flecha traseira atravessa arco sem gastar resistência")
	var flank_arrow := _arrow(flank, player, nav)
	root.add_child(flank_arrow)
	flank_arrow.set_process(false)
	var flank_hits := [0]
	flank_arrow.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: flank_hits[0] += 1)
	flank_arrow._process(1.0)
	_check(flank_hits[0] == 1 and player.shield_resistance == 5, "flecha lateral permanece vulnerável")
	nav.configure(Rect2(0, 0, 900, 600), [Rect2(510, 210, 50, 80)], 22.0)
	var blocked_arrow := _arrow(front, player, nav)
	root.add_child(blocked_arrow)
	blocked_arrow.set_process(false)
	blocked_arrow._process(1.0)
	_check(blocked_arrow.is_queued_for_deletion() and player.shield_resistance == 5, "obstáculo anterior não consome resistência")
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	for _index: int in 5:
		_check(player.absorb_shield_projectile(), "resistência restante absorve projétil")
	_check(not player.has_shield_stance() and not player.absorb_shield_projectile(), "última resistência encerra postura sem carga negativa")
	player.queue_free()
	front.queue_free()
	back.queue_free()
	flank.queue_free()
	caster.queue_free()
	await process_frame

func _check_profile_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_sw1_shield_wall")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("sw1-create", 0, "Guardião", &"swordsman")
	_check(created.get("ok", false), "menu cria Espadachim")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	_check(&"shield_wall" not in facade.available_build_options(character_id)["active_skills"], "R0 não é equipável")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP usa store isolado")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil reabre")
	for rank: int in range(1, 6):
		_check(facade.learn_skill("sw1-shield-%d" % rank, facade.current_profile().revision, character_id, &"shield_wall").get("ok", false), "compra R%d persiste" % rank)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var learned_button: Button
	for child: Node in menu.action_editor.library.get_children():
		if child.get("skill_id") == &"shield_wall":
			learned_button = child as Button
	_check(learned_button != null and learned_button.text == "Parede de Escudos", "biblioteca apresenta nome humano da skill aprendida")
	menu.action_editor.assign_skill(&"shield_wall", 0)
	_check(facade.current_profile().character_by_id(character_id).action_slots[0] == &"shield_wall", "menu salva organização de atalhos pela fachada")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).action_slots[0] == &"shield_wall", "save/reload preserva slot")
	menu.queue_free()
	await process_frame
	menu = scene.instantiate() as CharacterMenu
	menu.set_profile_facade(reopened)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var started := menu._start_run()
	_check(started.get("ok", false), "menu inicia run")
	if not started.get("ok", false):
		menu.queue_free()
		return
	await scene_changed
	await process_frame
	var controller := current_scene as RunController
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies:
		enemy.set_process(false)
		enemy.global_position = Vector2(1450, 850)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"shield_wall"]
	_check(controller.run_state.skill_levels[&"shield_wall"] == 5 and card.tooltip_text.contains("PAREDE DE ESCUDOS") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("24 SP"), "HUD reflete rank e custo")
	var aim := controller.player.global_position + Vector2(500, 0)
	controller.cast_intent.active_skill = &"shield_wall"
	controller._update_aim(aim)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == controller.player.global_position + Vector2(PlayerActor.SHIELD_RADIUS, 0), "mira indica arco frontal")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"shield_wall", aim)
	_check(controller.player.has_shield_stance() and controller.player.current_sp == before_sp - 24.0, "controller ativa instantaneamente")
	controller._update_hud()
	controller._update_aim(aim)
	_check(card.tooltip_text.contains("0 SP") and card.tooltip_text.contains("DESLIGAR") and controller.battle_controls.aim_label.text.contains("DESLIGAR"), "HUD/mira mostram toggle gratuito")
	var cooldown := controller.player.skill_cooldown(&"shield_wall")
	controller.player.current_sp = 0.0
	controller._commit_skill(&"shield_wall", aim)
	_check(not controller.player.has_shield_stance() and controller.player.current_sp == 0.0 and controller.player.skill_cooldown(&"shield_wall") == cooldown, "toggle via dispatch ignora recarga e SP")
	controller.player.current_sp = controller.player.max_sp
	controller.player.mage_cooldowns[&"shield_wall"] = 0.0
	controller._commit_skill(&"shield_wall", aim)
	_check(controller.player.has_shield_stance(), "postura reativa para limpeza")
	var last_enemy := controller.enemies[0]
	controller.enemies = [last_enemy]
	controller._on_enemy_died(last_enemy)
	_check(not controller.player.has_shield_stance(), "fim de encontro limpa postura")
	controller.player.mage_cooldowns[&"shield_wall"] = 0.0
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"shield_wall", aim)
	controller._on_player_died(controller.player)
	_check(not controller.player.has_shield_stance(), "morte/resultado limpam postura")
	paused = false
	_check(controller._close_persistent_run(&"abandoned").get("ok", false), "run fecha sem persistir postura")
	controller.queue_free()
	menu.queue_free()
	await process_frame
	_cleanup(directory)

func _arrow(source: CombatActor, player: PlayerActor, nav: ArenaNavigation) -> ArrowProjectile:
	var request := DamageRequest.new()
	request.source_id = source.get_instance_id()
	request.target_id = player.get_instance_id()
	request.physical_damage = 10.0
	var arrow := ArrowProjectile.new()
	arrow.configure(request, player, source.global_position + ArrowProjectile.BODY_OFFSET, nav)
	return arrow

func _navigation() -> ArenaNavigation:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
	return nav

func _target(position: Vector2) -> CombatActor:
	var actor := CombatActor.new()
	actor.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 50}), 19.0)
	actor.position = position
	return actor

func _snapshot(rank: int, include_slash_dash: bool = false) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "shield-test"
	snapshot.base_class_id = &"swordsman"
	snapshot.skill_ranks = {&"shield_wall": rank}
	snapshot.active_slots = [&"shield_wall", null, null, null, null]
	if include_slash_dash:
		snapshot.skill_ranks[&"slash"] = 1
		snapshot.skill_ranks[&"dash"] = 1
		snapshot.active_slots = [&"shield_wall", &"slash", &"dash", null, null]
	return snapshot

func _option_index(selector: OptionButton, skill_id: StringName) -> int:
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == skill_id:
			return index
	return -1

func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	for child: String in dir.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in dir.get_directories():
		_cleanup(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("Falha SW1: %s" % label)
