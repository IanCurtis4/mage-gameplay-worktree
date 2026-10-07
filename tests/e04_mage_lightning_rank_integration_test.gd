extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_ranks()
	_check_electrified_lifecycle()
	_check_ranked_emission()
	await _check_menu_and_controller()
	print("E04 MG1 Relâmpago: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_ranks() -> void:
	var definition := ClassCatalog.skill_definition(&"lightning")
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"lightning")
	_check(definition != null and definition.display_name == "Relâmpago" and definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET and definition.handler_id == SkillDefinition.Handler.LIGHTNING and definition.is_rank_catalog_valid(), "catálogo publica Relâmpago de alvo único com handler tipado")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "perfil vende R1–R5 sem rank gratuito")
	var powers: Array[float] = [1.25, 1.43, 1.60, 1.75, 1.90]
	var costs: Array[float] = [16.0, 18.0, 20.0, 21.0, 22.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index], "R%d usa dano e custo autorados" % [index + 1])
		_check(rank.cooldown == 4.0 and rank.range == 380.0 and rank.projectile_speed == 820.0 and rank.variable_cast_time == 0.26 and rank.fixed_cast_time == 0.0, "R%d mantém preparo, recarga e alcance" % [index + 1])
		_check(rank.magic_weight == 1.0 and rank.effect_ids == [&"electrified"] and rank.physical_weight == 0.0 and rank.precision_weight == 0.0, "R%d usa pipeline mágico e uma marca sem controle" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "ranks R0 e R6 não produzem fallback")
	var copied := definition.rank_definition(5)
	copied.power = 99.0
	_check(definition.rank_definition(5).power == 1.90, "consulta de rank não altera catálogo imutável")
	_check(&"lightning" not in ClassCatalog.class_definition(&"mage").skill_ids and catalog.initial_skill_slots(&"mage")["active_slots"] == [null, null, null, null, null], "biblioteca nova não é loadout piloto nem equipa personagem novo")

func _check_electrified_lifecycle() -> void:
	var target := _target(Vector2.ZERO)
	root.add_child(target)
	_check(not target.is_electrified(), "alvo nasce sem marca")
	target.apply_electrified(4.0)
	_check(target.is_electrified() and target.electrified_remaining == 4.0 and not target.hard_controls.is_active(&"stun"), "aplicação não causa dano, stack ou stun")
	target.advance_statuses(1.5, true)
	_check(target.electrified_remaining == 4.0, "pausa congela duração da marca")
	target.advance_statuses(2.0)
	target.apply_electrified(4.0)
	_check(target.electrified_remaining == 4.0, "reaplicação renova, sem acumular duração")
	target.advance_statuses(4.0)
	_check(not target.is_electrified(), "marca expira no tempo autorado")
	target.apply_electrified(4.0)
	target.clear_statuses()
	_check(not target.is_electrified(), "limpeza explícita remove marca")
	target.apply_electrified(4.0)
	var lethal := DamageRequest.new()
	lethal.target_id = target.get_instance_id()
	lethal.magic_damage = 100000.0
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	target.apply_damage(lethal, RandomNumberGenerator.new())
	_check(not target.is_alive() and not target.is_electrified(), "morte remove marca")
	target.apply_electrified(4.0)
	_check(not target.is_electrified(), "morto não recebe marca")
	target.queue_free()

func _check_ranked_emission() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	for rank: int in [0, 1, 5, 6]:
		var source := _snapshot(rank)
		var state := RunState.from_build("lightning-r%d" % rank, source)
		source.skill_ranks[&"lightning"] = 1
		var player := PlayerActor.new()
		player.configure(navigation, state)
		player.position = Vector2(100, 100)
		root.add_child(player)
		var target := _target(Vector2(300, 100))
		root.add_child(target)
		var emitted: Array[DamageRequest] = []
		var counts := [0]
		player.mage_projectile_requested.connect(func(skill_id: StringName, request: DamageRequest, _target: CombatActor, _direction: Vector2, count: int) -> void:
			if skill_id == &"lightning":
				emitted.append(request)
				counts[0] = count
		)
		var before_sp := player.current_sp
		var used := player.use_lightning(target)
		if rank in [0, 6]:
			_check(not used and emitted.is_empty() and player.current_sp == before_sp and player.skill_rank_definition(&"lightning") == null, "R%d é inelegível e não gasta SP" % rank)
		else:
			var expected_power := 1.25 if rank == 1 else 1.90
			var expected_cost := 16.0 if rank == 1 else 22.0
			_check(used and emitted.size() == 1 and counts[0] == 1, "R%d emite exatamente um projétil" % rank)
			_check(is_equal_approx(emitted[0].magic_damage, player.stat_breakdown.value(&"magic_attack") * expected_power) and emitted[0].accuracy_mode == DamageRequest.AccuracyMode.CONTESTED, "R%d captura dano mágico e HIT contestado" % rank)
			_check(player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"lightning") == StatCalculator.effective_cooldown(4.0, player.stat_breakdown), "R%d gasta SP e recarga uma vez" % rank)
			_check(player.skill_cast_time(&"lightning") == StatCalculator.effective_cast_time(0.0, 0.26, player.stat_breakdown), "R%d usa preparo escalado por DES" % rank)
			player.mage_cooldowns[&"lightning"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_lightning(target) and emitted.size() == 1 and player.current_sp == expected_cost - 1.0, "R%d bloqueia SP insuficiente sem segunda emissão" % rank)
		player.queue_free()
		target.queue_free()

func _check_menu_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mg1_lightning")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg1-create", 0, "Maga de teste", &"mage")
	_check(created.get("ok", false), "menu pode criar Mago com catálogo expandido")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	var initial_options := facade.available_build_options(character_id)
	_check(&"lightning" not in initial_options["active_skills"], "Relâmpago R0 não pode ser equipado")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP usa store transacional sem schema novo")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil recarrega antes da compra")
	for rank: int in range(1, 6):
		var learned := facade.learn_skill("mg1-learn-%d" % rank, facade.current_profile().revision, character_id, &"lightning")
		_check(learned.get("ok", false), "aprendizado persistente compra Relâmpago R%d" % rank)
	var options := facade.available_build_options(character_id)
	_check(&"lightning" in options["active_skills"], "Relâmpago aprendido aparece na biblioteca equipável")
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var learned_button: Button
	for child: Node in menu.action_editor.library.get_children():
		if child.get("skill_id") == &"lightning":
			learned_button = child as Button
	_check(learned_button != null and learned_button.text == "Relâmpago", "biblioteca apresenta nome humano da skill aprendida")
	menu.action_editor.assign_skill(&"lightning", 0)
	_check(facade.current_profile().character_by_id(character_id).action_slots[0] == &"lightning", "menu salva organização de atalhos pela fachada")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).action_slots[0] == &"lightning", "save/reload preserva slot de Relâmpago")
	menu.queue_free()
	await process_frame
	menu = scene.instantiate() as CharacterMenu
	menu.set_profile_facade(reopened)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var started := menu._start_run()
	_check(started.get("ok", false), "menu inicia run persistente com Relâmpago equipado")
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
	var target := _target(controller.player.global_position + Vector2(200, 0))
	controller.add_child(target)
	target.set_process(false)
	controller.enemies.append(target)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"lightning"]
	_check(controller.run_state.skill_levels[&"lightning"] == 5 and controller.player.available_skill_ids() == [&"lightning"] and card.tooltip_text.contains("RELÂMPAGO") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("22 SP"), "HUD consome R5 e nome do snapshot persistente")
	controller.cast_intent.active_skill = &"lightning"
	controller._update_aim(target.global_position)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == target.global_position, "mira de alvo único aceita alvo válido")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"lightning", target.global_position)
	_check(controller.player.has_active_cast() and controller.player.current_sp == before_sp, "preparo não antecipa gasto")
	controller.player.cancel_active_cast()
	_check(not controller.player.has_active_cast() and controller.player.current_sp == before_sp and get_nodes_in_group("player_projectiles").is_empty(), "cancelamento não emite nem gasta")
	controller._commit_skill(&"lightning", target.global_position)
	target.global_position += Vector2(500, 0)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(controller.player.current_sp == before_sp and get_nodes_in_group("player_projectiles").is_empty(), "alvo que sai do alcance durante preparo cancela sem custo")
	target.global_position -= Vector2(500, 0)
	controller._commit_skill(&"lightning", target.global_position)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var projectiles := get_nodes_in_group("player_projectiles")
	_check(projectiles.size() == 1 and controller.player.current_sp == before_sp - 22.0, "cast válido consome uma vez e cria um projétil")
	if projectiles.size() == 1:
		var projectile := projectiles[0] as MageProjectile
		_check(projectile.homing and projectile.target == target and projectile.color == Color("e9d76a") and projectile.speed == 820.0 and projectile.max_distance == 380.0, "projétil reutiliza colisão e distingue raio visualmente")
		projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		projectile._process(0.30)
		_check(target.is_electrified() and target.electrified_remaining == 4.0 and not target.hard_controls.is_active(&"stun"), "impacto válido marca uma vez sem stun")
	var hp_after := target.health.current_hp
	target.advance_statuses(2.0)
	var harmless := DamageRequest.new()
	harmless.skill_id = &"lightning"
	harmless.target_id = target.get_instance_id()
	harmless.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	controller._on_mage_projectile_hit(harmless, target)
	_check(target.electrified_remaining == 2.0 and target.health.current_hp == hp_after, "impacto sem dano não renova marca")
	var invalid := harmless.copy()
	invalid.target_id = 0
	invalid.magic_damage = 10.0
	controller._on_mage_projectile_hit(invalid, target)
	_check(target.electrified_remaining == 2.0, "requisição sem alvo válido não marca")
	var missed := harmless.copy()
	missed.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	missed.hit_rating = -10000.0
	missed.magic_damage = 10.0
	var miss_seed := 1
	var probe := RandomNumberGenerator.new()
	probe.seed = miss_seed
	while probe.randf() < 0.05:
		miss_seed += 1
		probe.seed = miss_seed
	controller.rng.seed = miss_seed
	controller._on_mage_projectile_hit(missed, target)
	_check(target.electrified_remaining == 2.0 and target.health.current_hp == hp_after, "erro de HIT não causa dano nem renova Eletrizado")
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false), "run fecha sem persistir a marca temporária")
	controller.queue_free()
	menu.queue_free()
	await process_frame
	_cleanup(directory)

func _snapshot(rank: int) -> BuildSnapshot:
	var snapshot := BuildSnapshot.new()
	snapshot.character_id = "lightning-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"lightning": rank}
	snapshot.active_slots = [&"lightning", null, null, null, null]
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
