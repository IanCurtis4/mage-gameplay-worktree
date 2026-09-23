extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_ranks()
	_check_ranked_emission()
	await _check_crossing_and_lifetime()
	await _check_projectile_ordering()
	await _check_menu_and_controller()
	print("E04 MG6 Barreira Fantasma: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_ranks() -> void:
	var definition := ClassCatalog.skill_definition(&"phantom_barrier")
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"phantom_barrier")
	_check(definition != null and definition.display_name == "Barreira Fantasma" and definition.targeting == SkillDefinition.Targeting.DIRECTION and definition.handler_id == SkillDefinition.Handler.PHANTOM_BARRIER and definition.is_rank_catalog_valid(), "catálogo publica barreira direcional sem dano")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "biblioteca começa em R0 e vende R1–R5")
	var capacities: Array[float] = [2.0, 3.0, 4.0, 5.0, 6.0]
	var costs: Array[float] = [20.0, 22.0, 24.0, 25.0, 26.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == capacities[index] and rank.sp_cost == costs[index], "R%d escala somente capacidade com SP autorado" % [index + 1])
		_check(rank.variable_cast_time == 0.42 and rank.fixed_cast_time == 0.0 and rank.cooldown == 10.0 and rank.range == 210.0 and rank.projectile_speed == 0.0, "R%d preserva preparo, recarga e colocação" % [index + 1])
		_check(rank.magic_weight == 0.0 and rank.physical_weight == 0.0 and rank.precision_weight == 0.0 and rank.effect_ids == [&"projectile_intercept", &"slow", &"weaken"], "R%d não gera dano ou novo controle" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "R0 e R6 não têm fallback")
	var copy := definition.rank_definition(5)
	copy.power = 99.0
	_check(definition.rank_definition(5).power == 6.0, "rank de catálogo permanece imutável")
	_check(&"phantom_barrier" not in ClassCatalog.class_definition(&"mage").skill_ids and catalog.initial_skill_slots(&"mage")["active_slots"] == [null, null, null, null, null], "biblioteca não altera kit inicial")

func _check_ranked_emission() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	for rank: int in [0, 1, 5, 6]:
		var source := _snapshot(rank)
		var state := RunState.from_build("phantom-barrier-r%d" % rank, source)
		source.skill_ranks[&"phantom_barrier"] = 1
		var player := PlayerActor.new()
		player.configure(navigation, state)
		player.position = Vector2(100, 100)
		root.add_child(player)
		var directions: Array[Vector2] = []
		var ranges: Array[float] = []
		var capacities: Array[int] = []
		player.phantom_barrier_requested.connect(func(direction: Vector2, placement_range: float, capacity: int) -> void:
			directions.append(direction)
			ranges.append(placement_range)
			capacities.append(capacity)
		)
		var before_sp := player.current_sp
		var used := player.use_phantom_barrier(Vector2.RIGHT)
		if rank in [0, 6]:
			_check(not used and capacities.is_empty() and player.current_sp == before_sp and player.skill_rank_definition(&"phantom_barrier") == null, "R%d não emite nem gasta" % rank)
		else:
			var expected_capacity := 2 if rank == 1 else 6
			var expected_cost := 20.0 if rank == 1 else 26.0
			_check(used and capacities == [expected_capacity] and directions == [Vector2.RIGHT] and ranges == [210.0], "R%d captura direção, alcance e cargas" % rank)
			_check(player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"phantom_barrier") == StatCalculator.effective_cooldown(10.0, player.stat_breakdown), "R%d cobra SP e recarga uma vez" % rank)
			_check(player.skill_cast_time(&"phantom_barrier") == StatCalculator.effective_cast_time(0.0, 0.42, player.stat_breakdown), "R%d prepara com DES" % rank)
			player.mage_cooldowns[&"phantom_barrier"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_phantom_barrier(Vector2.RIGHT) and capacities.size() == 1 and player.current_sp == expected_cost - 1.0, "R%d bloqueia SP insuficiente" % rank)
		player.queue_free()

func _check_crossing_and_lifetime() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 800, 500), [], 20.0)
	var caster := _target(Vector2(100, 100))
	var crossing := _target(Vector2(250, 100))
	var outside := _target(Vector2(250, 310))
	var overlapping := _target(Vector2(310, 100))
	for actor: CombatActor in [caster, crossing, outside, overlapping]:
		root.add_child(actor)
		actor.set_process(false)
	var targets: Array[CombatActor] = [crossing, outside, overlapping]
	var barrier := PhantomBarrier.new()
	barrier.configure(caster, Vector2.RIGHT, targets, 210.0, 2)
	root.add_child(barrier)
	barrier.set_process(false)
	_check(barrier.global_position == Vector2(310, 100) and is_zero_approx(barrier.axis.dot(Vector2.RIGHT)) and barrier.remaining_capacity == 2, "barreira nasce perpendicular ao cast com duas cargas")
	_check(navigation.is_segment_walkable(Vector2(250, 100), Vector2(370, 100)), "barreira não altera a navegação")
	barrier._process(0.01)
	_check(overlapping.slow_remaining == 0.0 and overlapping.weaken_remaining == 0.0 and caster.slow_remaining == 0.0, "sobreposição inicial e jogador não recebem debuff")
	crossing.global_position = Vector2(370, 100)
	outside.global_position = Vector2(370, 310)
	barrier._process(0.01)
	_check(crossing.slow_fraction == PhantomBarrier.SLOW_FRACTION and crossing.slow_remaining == PhantomBarrier.SLOW_DURATION and crossing.weaken_fraction == PhantomBarrier.WEAKEN_FRACTION and crossing.weaken_remaining == PhantomBarrier.WEAKEN_DURATION, "travessia rápida aplica slow e redução de dano")
	_check(outside.slow_remaining == 0.0 and outside.weaken_remaining == 0.0, "alvo fora da extensão não recebe efeito")
	crossing.advance_statuses(0.2)
	var slowed_remaining := crossing.slow_remaining
	crossing.global_position = Vector2(250, 100)
	barrier._process(0.01)
	_check(crossing.slow_remaining == slowed_remaining, "retravessia instantânea não renova efeito")
	var life_before := barrier.remaining
	var cooldown_before: float = barrier._cooldowns[crossing.get_instance_id()]
	paused = true
	barrier._process(2.0)
	crossing.advance_statuses(2.0, true)
	paused = false
	_check(barrier.remaining == life_before and barrier._cooldowns[crossing.get_instance_id()] == cooldown_before and crossing.slow_remaining == slowed_remaining, "pausa congela parede, intervalo e status")
	barrier._process(PhantomBarrier.TARGET_INTERVAL)
	crossing.global_position = Vector2(370, 100)
	barrier._process(0.01)
	_check(crossing.slow_remaining == PhantomBarrier.SLOW_DURATION and crossing.weaken_remaining == PhantomBarrier.WEAKEN_DURATION, "nova travessia após intervalo renova sem empilhar")
	overlapping.global_position = Vector2(250, 100)
	barrier._process(0.01)
	overlapping.global_position = Vector2(310, 100)
	barrier._process(0.01)
	_check(overlapping.slow_remaining == PhantomBarrier.SLOW_DURATION, "alvo nascido na faixa só recebe ao sair e reentrar")
	_check(barrier.interception_fraction(Vector2(370, 100), Vector2(250, 100), 4.0) >= 0.0 and barrier.interception_fraction(Vector2(370, 310), Vector2(250, 310), 4.0) < 0.0, "segmento contínuo discrimina dentro e fora da linha")
	_check(barrier.absorb_projectile() and barrier.remaining_capacity == 1 and barrier.is_active(), "primeiro projétil consome uma carga")
	_check(barrier.absorb_projectile() and barrier.remaining_capacity == 0 and barrier.is_queued_for_deletion() and not barrier.absorb_projectile(), "carga final encerra barreira sem valor negativo")
	var expired := PhantomBarrier.new()
	expired.configure(caster, Vector2.RIGHT, targets, 210.0, 3)
	root.add_child(expired)
	expired.set_process(false)
	expired._process(PhantomBarrier.DURATION)
	_check(expired.remaining == 0.0 and expired.is_queued_for_deletion(), "barreira expira pelo tempo sem precisar consumir cargas")
	for actor: CombatActor in [caster, crossing, outside, overlapping]:
		actor.queue_free()
	await process_frame

func _check_projectile_ordering() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 800, 400), [], 4.0)
	var player := _target(Vector2(100, 100))
	root.add_child(player)
	player.set_process(false)
	var targets: Array[CombatActor] = []
	var barrier := PhantomBarrier.new()
	barrier.configure(player, Vector2.RIGHT, targets, 200.0, 2)
	root.add_child(barrier)
	barrier.set_process(false)
	var hits := [0]
	var first := _enemy_arrow(player, navigation)
	first.hit.connect(func(_request: DamageRequest, _target_actor: CombatActor) -> void: hits[0] += 1)
	root.add_child(first)
	first.set_process(false)
	var arrow_position := first.global_position
	paused = true
	first._process(1.0)
	paused = false
	_check(first.global_position == arrow_position and barrier.remaining_capacity == 2, "pausa congela projétil e cargas")
	first._process(1.0)
	_check(first.is_queued_for_deletion() and hits[0] == 0 and barrier.remaining_capacity == 1, "projétil rápido é interceptado sem atingir jogador")
	var second := _enemy_arrow(player, navigation)
	second.hit.connect(func(_request: DamageRequest, _target_actor: CombatActor) -> void: hits[0] += 1)
	root.add_child(second)
	second.set_process(false)
	second._process(1.0)
	_check(second.is_queued_for_deletion() and barrier.remaining_capacity == 0 and barrier.is_queued_for_deletion(), "segundo impacto esgota resistência")
	var third := _enemy_arrow(player, navigation)
	third.hit.connect(func(_request: DamageRequest, _target_actor: CombatActor) -> void: hits[0] += 1)
	root.add_child(third)
	third.set_process(false)
	third._process(1.0)
	_check(hits[0] == 1 and third.is_queued_for_deletion(), "sem resistência, projétil seguinte alcança jogador")
	var behind := PhantomBarrier.new()
	behind.configure(player, Vector2.LEFT, targets, 20.0, 1)
	root.add_child(behind)
	behind.set_process(false)
	var before_hit: int = hits[0]
	var ahead_arrow := _enemy_arrow(player, navigation)
	ahead_arrow.hit.connect(func(_request: DamageRequest, _target_actor: CombatActor) -> void: hits[0] += 1)
	root.add_child(ahead_arrow)
	ahead_arrow.set_process(false)
	ahead_arrow._process(1.0)
	_check(hits[0] == before_hit + 1 and behind.remaining_capacity == 1, "alvo antes da barreira recebe projétil")
	behind.queue_free()
	var blocked_navigation := ArenaNavigation.new()
	blocked_navigation.configure(Rect2(0, 0, 800, 400), [Rect2(390, 40, 40, 120)], 4.0)
	var behind_obstacle := PhantomBarrier.new()
	behind_obstacle.configure(player, Vector2.RIGHT, targets, 200.0, 1)
	root.add_child(behind_obstacle)
	behind_obstacle.set_process(false)
	var blocked_arrow := _enemy_arrow(player, blocked_navigation)
	blocked_arrow.hit.connect(func(_request: DamageRequest, _target_actor: CombatActor) -> void: hits[0] += 1)
	root.add_child(blocked_arrow)
	blocked_arrow.set_process(false)
	blocked_arrow._process(1.0)
	_check(blocked_arrow.is_queued_for_deletion() and behind_obstacle.remaining_capacity == 1 and hits[0] == before_hit + 1, "obstáculo anterior impede projétil sem gastar barreira posterior")
	var nearer := PhantomBarrier.new()
	nearer.configure(player, Vector2.RIGHT, targets, 300.0, 1)
	root.add_child(nearer)
	nearer.set_process(false)
	var nearer_arrow := _enemy_arrow(player, navigation)
	root.add_child(nearer_arrow)
	nearer_arrow.set_process(false)
	nearer_arrow._process(1.0)
	_check(nearer.remaining_capacity == 0 and behind_obstacle.remaining_capacity == 1, "entre duas barreiras, primeiro contato absorve")
	var enemy := _target(Vector2(500, 100))
	root.add_child(enemy)
	enemy.set_process(false)
	var player_request := DamageRequest.new()
	player_request.skill_id = &"fireball"
	player_request.magic_damage = 10.0
	var projectile := MageProjectile.new()
	var enemy_targets: Array[CombatActor] = [enemy]
	projectile.configure_directional(player_request, Vector2(100, 82), Vector2.RIGHT, enemy_targets, navigation, 800.0, 600.0)
	var player_hits := [0]
	projectile.hit.connect(func(_request: DamageRequest, _target_actor: CombatActor) -> void: player_hits[0] += 1)
	root.add_child(projectile)
	projectile.set_process(false)
	projectile._process(0.6)
	_check(player_hits[0] == 1 and behind_obstacle.remaining_capacity == 1, "projétil do jogador atravessa sem consumir cargas")
	behind_obstacle.queue_free()
	player.queue_free()
	enemy.queue_free()
	await process_frame

func _check_menu_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mg6_phantom_barrier")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg6-create", 0, "Maga guardiã", &"mage")
	_check(created.get("ok", false), "menu cria Mago com biblioteca expandida")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	_check(&"phantom_barrier" not in facade.available_build_options(character_id)["active_skills"], "R0 não é equipável")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP usa store real")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil reabre antes das compras")
	for rank: int in range(1, 6):
		_check(facade.learn_skill("mg6-barrier-%d" % rank, facade.current_profile().revision, character_id, &"phantom_barrier").get("ok", false), "compra persistente R%d" % rank)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var selector := menu.active_selectors[0]
	var index := _option_index(selector, &"phantom_barrier")
	_check(index >= 0 and selector.get_item_text(index) == "Barreira Fantasma", "menu mostra nome e equipagem")
	selector.select(index)
	_check(menu._save_build().get("ok", false), "menu salva slot ativo")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).presets[0]["active_slots"][0] == &"phantom_barrier", "reload preserva preset")
	menu.queue_free()
	await process_frame
	menu = scene.instantiate() as CharacterMenu
	menu.set_profile_facade(reopened)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var started := menu._start_run()
	_check(started.get("ok", false), "menu inicia run persistente")
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
	var target := _target(controller.player.global_position + Vector2(300, 0))
	controller.add_child(target)
	target.set_process(false)
	controller.enemies.append(target)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"phantom_barrier"]
	_check(controller.run_state.skill_levels[&"phantom_barrier"] == 5 and card.text.contains("BARREIRA FANTASMA") and card.text.contains("R5") and card.text.contains("26 SP"), "HUD mostra rank e custo persistidos")
	controller.cast_intent.active_skill = &"phantom_barrier"
	controller._update_aim(controller.player.global_position + Vector2(1000, 0))
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == controller.player.global_position + Vector2(210, 0), "mira fixa centro da faixa no alcance")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"phantom_barrier", controller.player.global_position + Vector2(1000, 0))
	_check(controller.player.has_active_cast() and controller.player.current_sp == before_sp, "preparo não consome SP antes do commit")
	controller.player.cancel_active_cast()
	_check(not controller.player.has_active_cast() and controller.player.current_sp == before_sp and get_nodes_in_group("player_effects").is_empty(), "cancelamento não cria barreira")
	controller._commit_skill(&"phantom_barrier", controller.player.global_position + Vector2(1000, 0))
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var effects := get_nodes_in_group("player_effects")
	var barrier := effects.back() as PhantomBarrier if not effects.is_empty() else null
	_check(barrier != null and controller.player.current_sp == before_sp - 26.0 and controller.player.skill_cooldown(&"phantom_barrier") == StatCalculator.effective_cooldown(10.0, controller.player.stat_breakdown), "controller cria barreira e cobra uma vez")
	if barrier != null:
		barrier.set_process(false)
		_check(barrier.remaining_capacity == 6 and barrier in get_nodes_in_group("phantom_barriers"), "rank R5 cria seis cargas interceptáveis")
		target.global_position = controller.player.global_position + Vector2(150, 0)
		barrier._process(0.01)
		_check(target.slow_remaining == PhantomBarrier.SLOW_DURATION and target.weaken_remaining == PhantomBarrier.WEAKEN_DURATION and controller.player.slow_remaining == 0.0 and controller.player.weaken_remaining == 0.0, "inimigo cruzado recebe debuffs, jogador permanece imune")
		var player_hp := controller.player.health.current_hp
		var arrow := ArrowProjectile.new()
		var request := DamageRequest.new()
		request.target_id = controller.player.get_instance_id()
		request.physical_damage = 100.0
		arrow.configure(request, controller.player, controller.player.global_position + Vector2(440, -18), controller.navigation)
		controller.add_child(arrow)
		arrow.set_process(false)
		arrow._process(1.0)
		_check(arrow.is_queued_for_deletion() and barrier.remaining_capacity == 5 and controller.player.health.current_hp == player_hp, "projétil inimigo real é absorvido antes do jogador")
		controller._on_player_died(controller.player)
		_check(barrier.is_queued_for_deletion(), "morte do jogador limpa barreira")
	paused = false
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false), "run fecha sem persistir barreira ou debuff")
	controller.queue_free()
	menu.queue_free()
	await process_frame
	_cleanup(directory)

func _enemy_arrow(target: CombatActor, navigation: ArenaNavigation) -> ArrowProjectile:
	var request := DamageRequest.new()
	request.target_id = target.get_instance_id()
	request.physical_damage = 10.0
	var arrow := ArrowProjectile.new()
	arrow.configure(request, target, Vector2(500, 82), navigation)
	return arrow

func _option_index(selector: OptionButton, skill_id: StringName) -> int:
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == skill_id:
			return index
	return -1

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "phantom-barrier-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"phantom_barrier": rank}
	snapshot.active_slots = [&"phantom_barrier", null, null, null, null]
	return snapshot

func _target(position: Vector2) -> CombatActor:
	var target := CombatActor.new()
	target.setup("Alvo", Color.WHITE, StatCalculator.calculate({&"vit": 50}), 19.0)
	target.position = position
	return target

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
		push_error(label)
