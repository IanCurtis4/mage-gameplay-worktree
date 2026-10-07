extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_ranks()
	_check_fear_and_weaken_contract()
	_check_enemy_fear_navigation()
	_check_ranked_emission()
	await _check_menu_and_controller()
	print("E04 MG5 Assombro: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_ranks() -> void:
	var definition := ClassCatalog.skill_definition(&"haunt")
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"haunt")
	_check(definition != null and definition.display_name == "Assombro" and definition.targeting == SkillDefinition.Targeting.DIRECTION and definition.handler_id == SkillDefinition.Handler.HAUNT and definition.is_rank_catalog_valid(), "catálogo publica Assombro direcional")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "biblioteca começa em R0 e vende R1–R5")
	var powers: Array[float] = [0.35, 0.43, 0.50, 0.56, 0.61]
	var costs: Array[float] = [18.0, 20.0, 21.0, 22.0, 23.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index], "R%d usa dano baixo e SP autorados" % [index + 1])
		_check(rank.variable_cast_time == 0.40 and rank.fixed_cast_time == 0.0 and rank.cooldown == 9.0 and rank.range == 230.0 and rank.projectile_speed == 0.0, "R%d preserva preparo, recarga e cone" % [index + 1])
		_check(rank.magic_weight == 1.0 and rank.physical_weight == 0.0 and rank.precision_weight == 0.0 and rank.effect_ids == [&"fear", &"weaken"], "R%d só escala dano, sem nova resistência" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "R0 e R6 não têm fallback")
	var copy := definition.rank_definition(5)
	copy.power = 99.0
	_check(definition.rank_definition(5).power == 0.61, "rank de catálogo é imutável para consumidores")
	_check(&"haunt" not in ClassCatalog.class_definition(&"mage").skill_ids and catalog.initial_skill_slots(&"mage")["active_slots"] == [null, null, null, null, null], "biblioteca não altera loadout piloto")
	_check(PlayerActor.HAUNT_HALF_ANGLE == deg_to_rad(42.0) and PlayerActor.HAUNT_FEAR_DURATION == 0.90 and PlayerActor.HAUNT_WEAKEN_FRACTION == 0.25 and PlayerActor.HAUNT_WEAKEN_DURATION == 3.0, "ângulo e durações fixos ficam em um contrato")
	_check(SkillGeometry.cone_contains(Vector2.from_angle(deg_to_rad(41.0)) * 220.0, Vector2.RIGHT, 230.0, PlayerActor.HAUNT_HALF_ANGLE), "borda interna do cone recebe efeito")
	_check(not SkillGeometry.cone_contains(Vector2.from_angle(deg_to_rad(43.0)) * 220.0, Vector2.RIGHT, 230.0, PlayerActor.HAUNT_HALF_ANGLE) and not SkillGeometry.cone_contains(Vector2.RIGHT * 231.0, Vector2.RIGHT, 230.0, PlayerActor.HAUNT_HALF_ANGLE), "borda externa e alcance excedido não recebem efeito")

func _check_fear_and_weaken_contract() -> void:
	var target := _target(Vector2.ZERO)
	root.add_child(target)
	var base_multiplier := target.outgoing_damage_multiplier()
	var expected := 0.90 * (1.0 - target.stat_breakdown.value(&"magic_cc_resistance"))
	_check(is_equal_approx(target.apply_fear(0.90), expected) and target.is_feared() and not target.is_rooted() and not target.is_stunned(), "fear usa família própria e resistência mágica")
	target.apply_weaken(0.25, 3.0)
	_check(is_equal_approx(target.outgoing_damage_multiplier(), base_multiplier * 0.75) and target.weaken_remaining == 3.0, "enfraquecimento modifica dano causado, não stats de catálogo")
	target.advance_statuses(0.5, true)
	_check(is_equal_approx(target.fear_remaining(), expected) and target.weaken_remaining == 3.0, "pausa congela fear e enfraquecimento")
	target.advance_statuses(expected)
	_check(not target.is_feared() and target.weaken_remaining < 3.0, "fear expira antes do debuff")
	target.apply_weaken(0.10, 1.0)
	_check(target.weaken_fraction == 0.25 and target.weaken_remaining > 1.0, "reaplicação fraca não soma nem encurta debuff")
	target.advance_statuses(3.0)
	_check(target.weaken_remaining == 0.0 and target.weaken_fraction == 0.0 and target.outgoing_damage_multiplier() == base_multiplier, "debuff expira sem alterar multiplicador base")
	target.configure_hard_control_profile(true)
	var boss_fear := target.apply_fear(2.0)
	var budget_after_fear := target.hard_controls.boss_budget_remaining
	_check(boss_fear <= HardControlState.BOSS_DURATION_CAP and budget_after_fear < HardControlState.BOSS_BUDGET, "boss respeita teto e orçamento")
	target.apply_stun(0.6)
	_check(target.hard_controls.boss_budget_remaining == budget_after_fear, "sobreposição de fear/stun não cobra mesmo intervalo duas vezes")
	target.advance_statuses(1.0)
	target.apply_fear(2.0)
	_check(target.hard_controls.boss_budget_remaining == 0.0, "segunda janela de fear consome orçamento restante do boss")
	target.advance_statuses(1.0)
	_check(target.apply_fear(0.90) == 0.0 and not target.is_feared(), "boss sem orçamento não recebe novo fear")
	target.clear_statuses()
	target.set_unstoppable(1.0)
	_check(target.apply_fear(0.90) == 0.0 and not target.is_feared(), "unstoppable bloqueia fear")
	target.clear_statuses()
	target.apply_fear(0.90)
	target.apply_weaken(0.25, 3.0)
	target.clear_statuses()
	_check(not target.is_feared() and target.weaken_remaining == 0.0 and target.outgoing_damage_multiplier() == base_multiplier, "limpeza remove ambos os estados")
	target.apply_fear(0.90)
	target.apply_weaken(0.25, 3.0)
	var lethal := DamageRequest.new()
	lethal.target_id = target.get_instance_id()
	lethal.magic_damage = 100000.0
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	target.apply_damage(lethal, RandomNumberGenerator.new())
	_check(not target.is_alive() and not target.is_feared() and target.weaken_remaining == 0.0, "morte limpa fear e debuff")
	target.queue_free()

func _check_enemy_fear_navigation() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 900, 600), [Rect2(330, 80, 70, 170)], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.new())
	player.position = Vector2(100, 220)
	root.add_child(player)
	player.set_process(false)
	var enemy := EnemyActor.new()
	enemy.configure(&"chaser", navigation, player)
	enemy.position = Vector2(270, 220)
	root.add_child(enemy)
	enemy.set_process(false)
	var attacks: Array[DamageRequest] = []
	enemy.attack_requested.connect(func(request: DamageRequest, _target_actor: CombatActor, _ranged: bool) -> void: attacks.append(request))
	enemy.player_target_acquired = true
	enemy._path = PackedVector2Array([player.global_position])
	enemy._path_index = 0
	enemy._repath_time = 0.45
	var initial_distance := enemy.global_position.distance_to(player.global_position)
	_check(enemy.apply_fear(0.90) > 0.0 and enemy._path.is_empty() and enemy._repath_time == 0.0, "fear cancela rota de perseguição imediatamente")
	enemy.attack_cooldown = 0.0
	enemy._try_attack(false)
	_check(attacks.is_empty(), "fear impede novo ataque mesmo com cooldown livre")
	for _index: int in 4:
		enemy._process(0.15)
		_check(navigation.is_walkable(enemy.global_position), "fuga mantém inimigo em posição navegável")
	_check(enemy.global_position.distance_to(player.global_position) >= initial_distance - 1.0, "fuga não avança para o jogador ao contornar obstáculo")
	enemy.apply_root(1.0)
	var rooted_position := enemy.global_position
	enemy._process(0.10)
	_check(enemy.is_feared() and enemy.is_rooted() and enemy.global_position == rooted_position and attacks.is_empty(), "root sobreposto impede fuga sem permitir ataque")
	enemy.clear_statuses()
	player.global_position = Vector2(400, 350)
	enemy.global_position = Vector2(450, 350)
	var open_distance := enemy.global_position.distance_to(player.global_position)
	enemy.apply_fear(0.90)
	enemy._process(0.20)
	_check(enemy.global_position.distance_to(player.global_position) > open_distance and navigation.is_walkable(enemy.global_position), "fear gera fuga real em área aberta")
	enemy.clear_statuses()
	enemy.global_position = player.global_position + Vector2(45, 0)
	enemy.player_target_acquired = true
	enemy.attack_cooldown = 0.0
	enemy._try_attack(false)
	_check(attacks.size() == 1, "ataque volta após limpeza de fear")
	var emitted := attacks[0].copy()
	enemy.apply_weaken(0.25, 3.0)
	enemy.attack_cooldown = 0.0
	enemy._try_attack(false)
	_check(attacks.size() == 2 and is_equal_approx(attacks[1].damage_dealt_multiplier, emitted.damage_dealt_multiplier * 0.75) and attacks[0].damage_dealt_multiplier == emitted.damage_dealt_multiplier, "debuff só reduz ataques emitidos depois da aplicação")
	enemy.queue_free()
	player.queue_free()

func _check_ranked_emission() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	for rank: int in [0, 1, 5, 6]:
		var source := _snapshot(rank)
		var state := RunState.from_build("haunt-r%d" % rank, source)
		source.skill_ranks[&"haunt"] = 1
		var player := PlayerActor.new()
		player.configure(navigation, state)
		player.position = Vector2(100, 100)
		root.add_child(player)
		var requests: Array[DamageRequest] = []
		var origins: Array[Vector2] = []
		var directions: Array[Vector2] = []
		var ranges: Array[float] = []
		player.haunt_requested.connect(func(origin: Vector2, direction: Vector2, cone_range: float, request: DamageRequest) -> void:
			origins.append(origin)
			directions.append(direction)
			ranges.append(cone_range)
			requests.append(request)
		)
		var before_sp := player.current_sp
		var used := player.use_haunt(Vector2.RIGHT)
		if rank in [0, 6]:
			_check(not used and requests.is_empty() and player.current_sp == before_sp and player.skill_rank_definition(&"haunt") == null, "R%d não emite nem gasta" % rank)
		else:
			var expected_power := 0.35 if rank == 1 else 0.61
			var expected_cost := 18.0 if rank == 1 else 23.0
			_check(used and requests.size() == 1 and origins[0] == Vector2(100, 100) and directions[0] == Vector2.RIGHT and ranges[0] == 230.0, "R%d emite cone com geometria capturada" % rank)
			_check(is_equal_approx(requests[0].magic_damage, player.stat_breakdown.value(&"magic_attack") * expected_power) and requests[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not requests[0].can_crit, "R%d captura dano baixo sem crítico ou HIT adicional" % rank)
			_check(player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"haunt") == StatCalculator.effective_cooldown(9.0, player.stat_breakdown), "R%d cobra SP e recarga uma vez" % rank)
			_check(player.skill_cast_time(&"haunt") == StatCalculator.effective_cast_time(0.0, 0.40, player.stat_breakdown), "R%d prepara com DES" % rank)
			player.mage_cooldowns[&"haunt"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_haunt(Vector2.RIGHT) and requests.size() == 1 and player.current_sp == expected_cost - 1.0, "R%d bloqueia SP insuficiente" % rank)
		player.queue_free()

func _check_menu_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mg5_haunt")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg5-create", 0, "Maga assombrosa", &"mage")
	_check(created.get("ok", false), "menu cria Mago")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	_check(&"haunt" not in facade.available_build_options(character_id)["active_skills"], "R0 não é equipável")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP usa store real")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil reabre antes da compra")
	for rank: int in range(1, 6):
		_check(facade.learn_skill("mg5-haunt-%d" % rank, facade.current_profile().revision, character_id, &"haunt").get("ok", false), "compra persistente R%d" % rank)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var learned_button: Button
	for child: Node in menu.action_editor.library.get_children():
		if child.get("skill_id") == &"haunt":
			learned_button = child as Button
	_check(learned_button != null and learned_button.text == "Assombro", "biblioteca apresenta nome humano da skill aprendida")
	menu.action_editor.assign_skill(&"haunt", 0)
	_check(facade.current_profile().character_by_id(character_id).action_slots[0] == &"haunt", "menu salva organização de atalhos pela fachada")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).action_slots[0] == &"haunt", "reload preserva preset")
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
	var front := _target(controller.player.global_position + Vector2(140, 0))
	var behind := _target(controller.player.global_position + Vector2(-140, 0))
	for target: CombatActor in [front, behind]:
		controller.add_child(target)
		target.set_process(false)
		controller.enemies.append(target)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"haunt"]
	_check(controller.run_state.skill_levels[&"haunt"] == 5 and card.tooltip_text.contains("ASSOMBRO") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("23 SP"), "HUD mostra rank e custo persistidos")
	controller.cast_intent.active_skill = &"haunt"
	controller._update_aim(controller.player.global_position + Vector2(1000, 0))
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.active_range == 230.0, "mira mostra cone autorado")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"haunt", controller.player.global_position + Vector2(1000, 0))
	_check(controller.player.has_active_cast() and controller.player.current_sp == before_sp, "preparo não gasta cedo")
	controller.player.cancel_active_cast()
	_check(not controller.player.has_active_cast() and controller.player.current_sp == before_sp and get_nodes_in_group("player_effects").is_empty(), "cancelamento não cria efeito")
	front.set_unstoppable(1.0)
	var front_hp := front.health.current_hp
	var behind_hp := behind.health.current_hp
	controller._commit_skill(&"haunt", controller.player.global_position + Vector2(1000, 0))
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var effects := get_nodes_in_group("player_effects")
	var visual := effects.back() as HauntConeVisual if not effects.is_empty() else null
	_check(visual != null and controller.player.current_sp == before_sp - 23.0 and controller.player.skill_cooldown(&"haunt") == StatCalculator.effective_cooldown(9.0, controller.player.stat_breakdown), "controller emite cone e cobra uma vez")
	_check(front.health.current_hp < front_hp and front.weaken_remaining == PlayerActor.HAUNT_WEAKEN_DURATION and not front.is_feared(), "alvo imune ainda recebe dano e debuff, sem fear")
	_check(behind.health.current_hp == behind_hp and not behind.is_feared() and behind.weaken_remaining == 0.0, "alvo fora do cone não é afetado")
	front.clear_statuses()
	controller.player.mage_cooldowns[&"haunt"] = 0.0
	controller.player.current_sp = 23.0
	controller._commit_skill(&"haunt", controller.player.global_position + Vector2(1000, 0))
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(front.is_feared() and front.weaken_remaining == 3.0, "novo acerto aplica fear e enfraquecimento ao mesmo alvo")
	if visual != null:
		controller._on_player_died(controller.player)
		_check(visual.is_queued_for_deletion(), "morte do jogador limpa VFX")
	paused = false
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false), "run fecha sem persistir estados temporários")
	controller.queue_free()
	menu.queue_free()
	await process_frame
	_cleanup(directory)

func _option_index(selector: OptionButton, skill_id: StringName) -> int:
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == skill_id:
			return index
	return -1

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "haunt-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"haunt": rank}
	snapshot.active_slots = [&"haunt", null, null, null, null]
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
