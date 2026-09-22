extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_ranks()
	_check_stun_contract()
	_check_enemy_stun_interrupts()
	_check_ranked_emission()
	await _check_menu_and_controller()
	print("E04 MG2 Descarga Elétrica: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_ranks() -> void:
	var definition := ClassCatalog.skill_definition(&"electric_discharge")
	var metadata := ProfileCatalog.pilot().skill_metadata(&"electric_discharge")
	_check(definition != null and definition.display_name == "Descarga Elétrica" and definition.targeting == SkillDefinition.Targeting.DIRECTION and definition.handler_id == SkillDefinition.Handler.ELECTRIC_DISCHARGE and definition.is_rank_catalog_valid(), "catálogo publica skillshot linear com handler próprio")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "perfil vende R1–R5 sem equipar R0")
	var powers: Array[float] = [1.10, 1.28, 1.44, 1.58, 1.70]
	var costs: Array[float] = [18.0, 20.0, 22.0, 23.0, 24.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index], "R%d preserva poder e SP autorados" % [index + 1])
		_check(rank.variable_cast_time == 0.30 and rank.fixed_cast_time == 0.0 and rank.cooldown == 5.0 and rank.range == 560.0 and rank.projectile_speed == 800.0, "R%d mantém cast, recarga e geometria fixos" % [index + 1])
		_check(rank.magic_weight == 1.0 and rank.effect_ids == [&"electrified_detonation"] and rank.physical_weight == 0.0 and rank.precision_weight == 0.0, "R%d usa dano mágico e uma detonação" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "R0 e R6 não têm fallback")
	var copied := definition.rank_definition(5)
	copied.power = 99.0
	_check(definition.rank_definition(5).power == 1.70, "consulta de rank não altera catálogo")
	_check(&"electric_discharge" not in ClassCatalog.class_definition(&"mage").skill_ids, "biblioteca persistente não altera kit piloto")

func _check_stun_contract() -> void:
	var target := _target(Vector2.ZERO)
	root.add_child(target)
	_check(target.apply_stun(0.6) == 0.6 and target.is_stunned() and not target.is_rooted(), "stun usa família própria, não root")
	target.advance_statuses(0.3, true)
	_check(target.stun_remaining() == 0.6, "pausa congela stun")
	target.advance_statuses(0.6)
	_check(not target.is_stunned(), "stun expira sem alterar stats")
	target.configure_hard_control_profile(true)
	_check(target.apply_stun(2.0) <= 1.0 and target.hard_controls.boss_budget_remaining < HardControlState.BOSS_BUDGET, "boss respeita teto e orçamento compartilhado")
	target.clear_statuses()
	_check(target.set_unstoppable(1.0) and target.apply_stun(0.6) == 0.0 and not target.is_stunned(), "imunidade impede stun")
	target.clear_statuses()
	target.apply_electrified(4.0)
	_check(target.consume_electrified() and not target.is_electrified() and not target.consume_electrified(), "marca consome uma única vez")
	target.apply_stun(0.6)
	target.apply_electrified(4.0)
	var lethal := DamageRequest.new()
	lethal.target_id = target.get_instance_id()
	lethal.magic_damage = 100000.0
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	target.apply_damage(lethal, RandomNumberGenerator.new())
	_check(not target.is_alive() and not target.is_stunned() and not target.is_electrified(), "morte limpa controle e marca")
	target.queue_free()

func _check_enemy_stun_interrupts() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, RunState.new())
	player.position = Vector2(100, 100)
	root.add_child(player)
	var enemy := EnemyActor.new()
	enemy.configure(&"chaser", navigation, player)
	enemy.position = Vector2(250, 100)
	root.add_child(enemy)
	var attacks := [0]
	enemy.attack_requested.connect(func(_request: DamageRequest, _target: CombatActor, _ranged: bool) -> void: attacks[0] += 1)
	var before := enemy.global_position
	var expected_stun := 0.6 * (1.0 - enemy.stat_breakdown.value(&"magic_cc_resistance"))
	_check(is_equal_approx(enemy.apply_stun(0.6), expected_stun) and enemy.is_stunned(), "stun entra na IA inimiga com resistência canônica")
	enemy._process(0.2)
	enemy.player_target_acquired = true
	enemy._try_attack(false)
	_check(enemy.global_position == before and attacks[0] == 0, "inimigo atordoado não anda nem emite ataque")
	enemy.advance_statuses(0.4)
	enemy.global_position = player.global_position + Vector2(45, 0)
	enemy._try_attack(false)
	_check(not enemy.is_stunned() and attacks[0] == 1, "ataque volta ao expirar stun")
	enemy.attack_cooldown = 0.0
	enemy.apply_root(1.0)
	enemy._try_attack(false)
	_check(enemy.is_rooted() and attacks[0] == 2, "root não é stun: ainda permite atacar")
	enemy.queue_free()
	player.queue_free()

func _check_ranked_emission() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	for rank: int in [0, 1, 5, 6]:
		var source := _snapshot(rank)
		var state := RunState.from_build("discharge-r%d" % rank, source)
		source.skill_ranks[&"electric_discharge"] = 1
		var player := PlayerActor.new()
		player.configure(navigation, state)
		player.position = Vector2(100, 100)
		root.add_child(player)
		var emitted: Array[DamageRequest] = []
		var bonuses: Array[float] = []
		player.discharge_requested.connect(func(request: DamageRequest, _direction: Vector2, bonus: float) -> void:
			emitted.append(request)
			bonuses.append(bonus)
		)
		var before_sp := player.current_sp
		var used := player.use_electric_discharge(Vector2.RIGHT)
		if rank in [0, 6]:
			_check(not used and emitted.is_empty() and player.current_sp == before_sp and player.skill_rank_definition(&"electric_discharge") == null, "R%d não emite nem gasta" % rank)
		else:
			var expected_power := 1.10 if rank == 1 else 1.70
			var expected_cost := 18.0 if rank == 1 else 24.0
			_check(used and emitted.size() == 1 and bonuses.size() == 1, "R%d emite um projétil com bônus capturado" % rank)
			_check(is_equal_approx(emitted[0].magic_damage, player.stat_breakdown.value(&"magic_attack") * expected_power) and is_equal_approx(bonuses[0], player.stat_breakdown.value(&"magic_attack") * 0.45), "R%d separa dano-base do bônus de marca" % rank)
			_check(emitted[0].accuracy_mode == DamageRequest.AccuracyMode.CONTESTED and player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"electric_discharge") == StatCalculator.effective_cooldown(5.0, player.stat_breakdown), "R%d captura HIT, SP e recarga uma vez" % rank)
			_check(player.skill_cast_time(&"electric_discharge") == StatCalculator.effective_cast_time(0.0, 0.30, player.stat_breakdown), "R%d escala cast por DES" % rank)
			player.mage_cooldowns[&"electric_discharge"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_electric_discharge(Vector2.RIGHT) and emitted.size() == 1 and player.current_sp == expected_cost - 1.0, "R%d bloqueia SP insuficiente" % rank)
		player.queue_free()

func _check_menu_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mg2_discharge")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg2-create", 0, "Maga de descarga", &"mage")
	_check(created.get("ok", false), "Mago novo mantém biblioteca R0")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	_check(&"electric_discharge" not in facade.available_build_options(character_id)["active_skills"], "R0 não aparece como equipável")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP usa store real")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil recarrega antes do aprendizado")
	for rank: int in range(1, 6):
		_check(facade.learn_skill("mg2-learn-%d" % rank, facade.current_profile().revision, character_id, &"electric_discharge").get("ok", false), "compra persistente R%d" % rank)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var selector := menu.active_selectors[0]
	var selected_index := -1
	for index: int in selector.item_count:
		if selector.get_item_metadata(index) == &"electric_discharge":
			selected_index = index
	_check(selected_index >= 0 and (selector.get_item_text(selected_index) == "Descarga Elétrica" if selected_index >= 0 else false), "menu apresenta nome visível")
	selector.select(selected_index)
	_check(menu._save_build().get("ok", false), "menu salva skill no primeiro slot")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).presets[0]["active_slots"][0] == &"electric_discharge", "reload preserva preset")
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
	var target := _target(controller.player.global_position + Vector2(200, 0))
	controller.add_child(target)
	target.set_process(false)
	controller.enemies.append(target)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"electric_discharge"]
	_check(controller.run_state.skill_levels[&"electric_discharge"] == 5 and card.text.contains("DESCARGA ELÉTRICA") and card.text.contains("R5") and card.text.contains("24 SP"), "HUD lê rank, nome e custo do snapshot")
	controller.cast_intent.active_skill = &"electric_discharge"
	controller._update_aim(target.global_position)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == controller.player.global_position + Vector2(560, 0), "mira mostra corredor direcional de 560")
	var sp_before := controller.player.current_sp
	controller._commit_skill(&"electric_discharge", target.global_position)
	_check(controller.player.has_active_cast() and controller.player.current_sp == sp_before, "preparo não gasta cedo")
	controller.player.cancel_active_cast()
	_check(not controller.player.has_active_cast() and controller.player.current_sp == sp_before and get_nodes_in_group("player_projectiles").is_empty(), "cancelamento não emite")
	controller._commit_skill(&"electric_discharge", target.global_position)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and controller.player.current_sp == sp_before - 24.0, "cast completo emite uma vez")
	if projectiles.size() == 1:
		var projectile := projectiles[0] as MageProjectile
		var base_damage := controller.player.stat_breakdown.value(&"magic_attack") * 1.70
		var bonus := controller.player.stat_breakdown.value(&"magic_attack") * 0.45
		_check(not projectile.homing and projectile.max_hits == 1 and projectile.speed == 800.0 and projectile.max_distance == 560.0 and projectile.request.magic_damage == base_damage and projectile.electrified_bonus_magic_damage == bonus, "skillshot fixa direção, valores e primeiro impacto")
		target.apply_electrified(4.0)
		controller.rng.seed = _seed_for_stun(true)
		projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		projectile._process(0.30)
		_check(projectile.request.magic_damage == base_damage + bonus and not target.is_electrified() and target.is_stunned(), "acerto marcado soma bônus, consome marca e pode aplicar stun")
		var stun_before := target.stun_remaining()
		target.advance_statuses(0.3, true)
		_check(target.stun_remaining() == stun_before, "pausa congela stun aplicado")
		target.advance_statuses(1.0)
		_check(not target.is_stunned(), "stun aplicado expira")
		var unmarked := projectile.request.copy()
		unmarked.magic_damage = base_damage
		var hp_before := target.health.current_hp
		controller._on_discharge_hit(unmarked, target)
		_check(target.health.current_hp < hp_before and not target.is_stunned(), "sem marca, Descarga causa só dano-base")
		target.apply_electrified(4.0)
		var missed := unmarked.copy()
		missed.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
		missed.hit_rating = -10000.0
		controller.rng.seed = _seed_for_miss()
		var hp_before_miss := target.health.current_hp
		controller._on_discharge_hit(missed, target)
		_check(target.is_electrified() and target.health.current_hp == hp_before_miss and not target.is_stunned(), "falha de HIT preserva marca, HP e controle")
		controller.rng.seed = _seed_for_stun(false)
		var no_stun := unmarked.copy()
		no_stun.magic_damage = base_damage + bonus
		controller._on_discharge_hit(no_stun, target)
		_check(not target.is_electrified() and not target.is_stunned(), "rolagem sem proc também consome marca")
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false), "run fecha sem persistir controle ou marca")
	controller.queue_free()
	menu.queue_free()
	await process_frame
	_cleanup(directory)

func _seed_for_stun(want_stun: bool) -> int:
	for seed_value: int in range(1, 1000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		probe.randf()
		probe.randf()
		var roll := probe.randf()
		if (roll < 0.25) == want_stun:
			return seed_value
	return -1

func _seed_for_miss() -> int:
	for seed_value: int in range(1, 1000):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		if probe.randf() > 0.05:
			return seed_value
	return -1

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "discharge-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"electric_discharge": rank}
	snapshot.active_slots = [&"electric_discharge", null, null, null, null]
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
