extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_ranks()
	await _check_ranked_casts()
	await _check_dynamic_navigation()
	await _check_profile_and_controller()
	print("E04 MG7 Parede de Gelo: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_ranks() -> void:
	var definition := ClassCatalog.skill_definition(&"ice_wall")
	var metadata := ProfileCatalog.pilot().skill_metadata(&"ice_wall")
	_check(definition != null and definition.display_name == "Parede de Gelo" and definition.targeting == SkillDefinition.Targeting.DIRECTION and definition.handler_id == SkillDefinition.Handler.ICE_WALL and definition.is_rank_catalog_valid(), "catálogo publica parede sólida direcional")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "biblioteca persistente inicia em R0")
	var durations: Array[float] = [3.0, 3.6, 4.1, 4.5, 4.8]
	var costs: Array[float] = [22.0, 24.0, 26.0, 27.0, 28.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == durations[index] and rank.sp_cost == costs[index], "R%d escala duração côncava e SP" % [index + 1])
		_check(rank.variable_cast_time == 0.45 and rank.cooldown == 9.0 and rank.range == 200.0 and rank.projectile_speed == 0.0 and rank.effect_ids == [&"solid_obstacle"], "R%d mantém geometria e preparo" % [index + 1])
		_check(rank.magic_weight == 0.0 and rank.physical_weight == 0.0 and rank.precision_weight == 0.0, "R%d não causa dano" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "R0 e R6 não têm fallback")
	var copy := definition.rank_definition(5)
	copy.power = 90.0
	_check(definition.rank_definition(5).power == 4.8, "recurso de catálogo é imutável")
	_check(&"ice_wall" not in ClassCatalog.class_definition(&"mage").skill_ids and ProfileCatalog.pilot().initial_skill_slots(&"mage")["active_slots"] == [null, null, null, null, null], "novo ID não ocupa slot inicial")

func _check_ranked_casts() -> void:
	for rank: int in [0, 1, 5, 6]:
		var nav := ArenaNavigation.new()
		nav.configure(Rect2(0, 0, 900, 600), [], 22.0)
		var source := _snapshot(rank)
		var state := RunState.from_build("ice-wall-r%d" % rank, source)
		source.skill_ranks[&"ice_wall"] = 1
		var player := PlayerActor.new()
		player.configure(nav, state)
		player.position = Vector2(150, 300)
		root.add_child(player)
		player.set_process(false)
		var walls: Array[IceWall] = []
		player.ice_wall_requested.connect(func(wall: IceWall) -> void:
			walls.append(wall)
			root.add_child(wall)
			wall.set_process(false)
		)
		var before_sp := player.current_sp
		var used := player.use_ice_wall(Vector2.RIGHT, [])
		if rank in [0, 6]:
			_check(not used and walls.is_empty() and player.current_sp == before_sp and player.skill_rank_definition(&"ice_wall") == null, "R%d inválido não emite/gasta" % rank)
		else:
			var expected_cost := 22.0 if rank == 1 else 28.0
			var expected_duration := 3.0 if rank == 1 else 4.8
			_check(used and walls.size() == 1 and is_equal_approx(walls[0].remaining, expected_duration) and walls[0].global_position == Vector2(350, 300), "R%d captura duração e geometria" % rank)
			_check(player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"ice_wall") == StatCalculator.effective_cooldown(9.0, player.stat_breakdown), "R%d cobra SP/recarga uma vez" % rank)
			_check(player.skill_cast_time(&"ice_wall") == StatCalculator.effective_cast_time(0.0, 0.45, player.stat_breakdown), "R%d usa preparo DES" % rank)
			walls[0].expire()
			player.mage_cooldowns[&"ice_wall"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_ice_wall(Vector2.RIGHT, []) and walls.size() == 1 and player.current_sp == expected_cost - 1.0, "R%d recusa SP insuficiente" % rank)
		player.queue_free()
		await process_frame

func _check_dynamic_navigation() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0, 0, 800, 500), [Rect2(60, 60, 50, 50)], 22.0)
	var start := Vector2(200, 250)
	var finish := Vector2(600, 250)
	_check(nav.get_path(start, finish).size() == 1, "arena aberta usa destino real")
	_check(not nav.can_add_temporary_segment(Vector2(400, 145), Vector2(400, 355), IceWall.HALF_WIDTH, [Vector2(400, 250)]), "colocação sobre ator é recusada")
	_check(not nav.can_add_temporary_segment(Vector2(8, 180), Vector2(8, 390), IceWall.HALF_WIDTH, []), "colocação sobre borda é recusada")
	_check(not nav.can_add_temporary_segment(Vector2(90, 90), Vector2(90, 300), IceWall.HALF_WIDTH, []), "colocação sobre obstáculo fixo é recusada")
	var wall := IceWall.new()
	_check(wall.configure(nav, Vector2(200, 250), Vector2.RIGHT, 200.0, 3.0, [start, finish]), "parede registra segmento sólido")
	root.add_child(wall)
	wall.set_process(false)
	var id := wall.get_instance_id()
	_check(nav.has_temporary_segment(id) and not nav.is_segment_walkable(start, finish) and not nav.is_segment_walkable(finish, start), "parede bloqueia movimento de ambos os lados")
	_check(not nav.is_segment_clear(start + Vector2(0, -18), finish + Vector2(0, -18), 4.0) and not nav.is_segment_clear(finish + Vector2(0, -18), start + Vector2(0, -18), 4.0), "projéteis dos dois lados encontram a parede")
	var arrow_target := CombatActor.new()
	arrow_target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 30}), 19.0)
	arrow_target.position = finish
	root.add_child(arrow_target)
	arrow_target.set_process(false)
	var arrow := ArrowProjectile.new()
	var arrow_request := DamageRequest.new()
	arrow_request.target_id = arrow_target.get_instance_id()
	arrow.configure(arrow_request, arrow_target, start + Vector2(0, -18), nav)
	root.add_child(arrow)
	arrow.set_process(false)
	var arrow_hits := [0]
	arrow.hit.connect(func(_request: DamageRequest, _target: CombatActor) -> void: arrow_hits[0] += 1)
	arrow._process(1.0)
	_check(arrow.is_queued_for_deletion() and arrow_hits[0] == 0, "flecha inimiga real morre na parede sem atingir")
	var own_projectile := PlayerProjectile.new()
	var own_request := DamageRequest.new()
	var no_targets: Array[CombatActor] = []
	own_projectile.configure_directional(own_request, finish + Vector2(0, -18), Vector2.LEFT, no_targets, nav, 500.0, 600.0)
	root.add_child(own_projectile)
	own_projectile.set_process(false)
	own_projectile._process(1.0)
	_check(own_projectile.is_queued_for_deletion() and own_projectile.global_position.x > 400.0, "projétil próprio real é bloqueado do outro lado")
	arrow_target.queue_free()
	var route := nav.get_path(start, finish)
	var route_valid := route.size() > 1
	var previous := start
	for waypoint: Vector2 in route:
		route_valid = route_valid and nav.is_segment_walkable(previous, waypoint)
		previous = waypoint
	_check(route_valid and previous == finish, "AStar desvia pelas pontas sem atravessar sólido")
	var stopped := nav.move_until_blocked(start, finish)
	_check(stopped.x < 400.0 - IceWall.HALF_WIDTH - 22.0 and nav.is_walkable(stopped), "passo contínuo para antes da parede")
	var revision := nav.revision
	wall.expire()
	_check(nav.revision == revision + 1 and not nav.has_temporary_segment(id) and nav.get_path(start, finish).size() == 1, "expiração libera navegação no mesmo frame")
	wall.expire()
	_check(nav.revision == revision + 1, "expiração é idempotente")
	await process_frame

	var mage_nav := ArenaNavigation.new()
	mage_nav.configure(Rect2(0, 0, 800, 500), [], 22.0)
	var player := PlayerActor.new()
	player.configure(mage_nav, RunState.new(&"mage"))
	player.position = start
	root.add_child(player)
	player.set_process(false)
	player.move_to(finish)
	var first_path := player._path.duplicate()
	var enemy := EnemyActor.new()
	enemy.configure(&"warrior", mage_nav, player)
	enemy.position = finish
	root.add_child(enemy)
	enemy.set_process(false)
	enemy._path = mage_nav.get_path(finish, start)
	enemy._repath_time = 0.45
	var moving_wall := IceWall.new()
	_check(moving_wall.configure(mage_nav, start, Vector2.RIGHT, 200.0, 3.0, [start, finish]), "parede pode surgir durante movimento")
	root.add_child(moving_wall)
	moving_wall.set_process(false)
	player._process(0.05)
	_check(first_path.size() == 1 and player._navigation_revision == mage_nav.revision and player._path.size() > 1 and mage_nav.is_segment_walkable(player.global_position, player._path[player._path_index]), "jogador recompõe clique antigo ao mudar malha")
	enemy._process(0.01)
	_check(enemy._navigation_revision == mage_nav.revision and enemy._path.size() > 1 and mage_nav.is_segment_walkable(enemy.global_position, enemy._path[enemy._path_index]), "inimigo descarta rota velha e contorna parede")
	moving_wall.expire()
	player._process(0.05)
	enemy._process(0.01)
	_check(player._navigation_revision == mage_nav.revision and mage_nav.is_segment_walkable(player.global_position, finish), "jogador replaneja ao expirar")
	_check(enemy._navigation_revision == mage_nav.revision and mage_nav.is_segment_walkable(enemy.global_position, start), "inimigo replaneja ao expirar")
	player.queue_free()
	enemy.queue_free()
	await process_frame

func _check_profile_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mg7_ice_wall")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg7-create", 0, "Maga glacial", &"mage")
	_check(created.get("ok", false), "menu cria Mago com Parede de Gelo na biblioteca")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	_check(&"ice_wall" not in facade.available_build_options(character_id)["active_skills"], "R0 não é equipável")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP persiste em store isolado")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil reabre")
	for rank: int in range(1, 6):
		_check(facade.learn_skill("mg7-ice-%d" % rank, facade.current_profile().revision, character_id, &"ice_wall").get("ok", false), "compra persistente R%d" % rank)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var selector := menu.active_selectors[0]
	var index := _option_index(selector, &"ice_wall")
	_check(index >= 0 and selector.get_item_text(index) == "Parede de Gelo", "menu mostra nome no seletor")
	selector.select(index)
	_check(menu._save_build().get("ok", false), "menu salva equipagem manual")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).presets[0]["active_slots"][0] == &"ice_wall", "reload conserva preset")
	menu.queue_free()
	await process_frame
	menu = scene.instantiate() as CharacterMenu
	menu.set_profile_facade(reopened)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var started := menu._start_run()
	_check(started.get("ok", false), "menu inicia run com skill equipada")
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
	var card: Button = controller.battle_controls.skill_buttons[&"ice_wall"]
	_check(controller.run_state.skill_levels[&"ice_wall"] == 5 and card.text.contains("PAREDE DE GELO") and card.text.contains("R5") and card.text.contains("28 SP"), "HUD mostra rank e custo persistidos")
	var aim := controller.player.global_position + Vector2(1000, 0)
	controller.cast_intent.active_skill = &"ice_wall"
	controller._update_aim(aim)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == controller.player.global_position + Vector2(200, 0), "mira desenha segmento no alcance")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"ice_wall", aim)
	_check(controller.player.has_active_cast() and controller.player.current_sp == before_sp, "preparo não cobra antes de concluir")
	controller.player.cancel_active_cast()
	_check(not controller.player.has_active_cast() and controller.player.current_sp == before_sp and not _has_ice_wall(), "cancelamento não registra parede")
	controller._commit_skill(&"ice_wall", aim)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var wall := _first_ice_wall()
	_check(wall != null and controller.player.current_sp == before_sp - 28.0 and controller.player.skill_cooldown(&"ice_wall") == StatCalculator.effective_cooldown(9.0, controller.player.stat_breakdown), "cast cria parede e cobra uma vez")
	if wall != null:
		wall.set_process(false)
		_check(controller.navigation.has_temporary_segment(wall.get_instance_id()) and not controller.navigation.is_segment_walkable(controller.player.global_position, controller.player.global_position + Vector2(400, 0)), "parede real bloqueia arena")
		var remaining := wall.remaining
		paused = true
		wall._process(10.0)
		_check(wall.remaining == remaining and controller.navigation.has_temporary_segment(wall.get_instance_id()), "pausa congela duração")
		paused = false
		wall._process(remaining)
		_check(not controller.navigation.has_temporary_segment(wall.get_instance_id()), "expiração remove obstáculo durante run")
		await process_frame
		controller.player.mage_cooldowns[&"ice_wall"] = 0.0
		var blocker := CombatActor.new()
		blocker.setup("Bloqueio", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 19.0)
		blocker.global_position = controller.player.global_position + Vector2(200, 0)
		controller.add_child(blocker)
		controller.enemies.append(blocker)
		var blocked_sp := controller.player.current_sp
		controller._update_aim(aim)
		_check(controller.battle_controls.aim_label.text.contains("POSIÇÃO BLOQUEADA"), "mira aponta sobreposição com inimigo")
		controller._execute_skill(&"ice_wall", aim)
		_check(controller.player.current_sp == blocked_sp and not _has_ice_wall() and controller.status_label.text.contains("POSIÇÃO BLOQUEADA"), "posição inválida não cobra SP")
		controller.enemies.erase(blocker)
		blocker.queue_free()
		await process_frame
		controller._execute_skill(&"ice_wall", aim)
		var encounter_wall := _first_ice_wall()
		_check(encounter_wall != null, "novo cast após desbloqueio")
		if encounter_wall != null:
			var last_enemy := controller.enemies[0]
			controller.enemies = [last_enemy]
			controller._on_enemy_died(last_enemy)
			_check(not controller.navigation.has_temporary_segment(encounter_wall.get_instance_id()), "fim de encontro remove sólido sincronicamente")
			await process_frame
		controller.player.current_sp = controller.player.max_sp
		controller.player.mage_cooldowns[&"ice_wall"] = 0.0
		controller._execute_skill(&"ice_wall", aim)
		var death_wall := _first_ice_wall()
		_check(death_wall != null, "cast continua válido após limpeza de encontro")
		if death_wall != null:
			controller._on_player_died(controller.player)
			_check(not controller.navigation.has_temporary_segment(death_wall.get_instance_id()), "morte remove sólido sincronicamente")
	paused = false
	_check(controller._close_persistent_run(&"abandoned").get("ok", false), "run fecha sem persistir obstáculo")
	controller.queue_free()
	menu.queue_free()
	await process_frame
	_cleanup(directory)

func _has_ice_wall() -> bool:
	return _first_ice_wall() != null

func _first_ice_wall() -> IceWall:
	for effect: Node in get_nodes_in_group("player_effects"):
		if effect is IceWall and not effect.is_queued_for_deletion():
			return effect as IceWall
	return null

func _option_index(selector: OptionButton, skill_id: StringName) -> int:
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == skill_id:
			return index
	return -1

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "ice-wall-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"ice_wall": rank}
	snapshot.active_slots = [&"ice_wall", null, null, null, null]
	return snapshot

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
		push_error("Falha MG7: %s" % label)
