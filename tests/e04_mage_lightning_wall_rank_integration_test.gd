extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_ranks()
	_check_ranked_emission()
	await _check_wall_geometry_and_clock()
	await _check_menu_and_controller()
	print("E04 MG3 Parede de Raios: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_ranks() -> void:
	var definition := ClassCatalog.skill_definition(&"lightning_wall")
	var metadata := ProfileCatalog.pilot().skill_metadata(&"lightning_wall")
	_check(definition != null and definition.display_name == "Parede de Raios" and definition.targeting == SkillDefinition.Targeting.DIRECTION and definition.handler_id == SkillDefinition.Handler.LIGHTNING_WALL and definition.is_rank_catalog_valid(), "catálogo publica Parede de Raios direcional")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "biblioteca persistente tem R1–R5, sem rank grátis")
	var powers: Array[float] = [0.50, 0.60, 0.69, 0.77, 0.84]
	var costs: Array[float] = [22.0, 24.0, 26.0, 27.0, 28.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index], "R%d usa dano e SP autorados" % [index + 1])
		_check(rank.variable_cast_time == 0.38 and rank.fixed_cast_time == 0.0 and rank.cooldown == 8.0 and rank.range == 220.0 and rank.projectile_speed == 0.0, "R%d mantém preparo, geometria e duração indireta" % [index + 1])
		_check(rank.magic_weight == 1.0 and rank.effect_ids == [&"electrified"] and rank.physical_weight == 0.0 and rank.precision_weight == 0.0, "R%d usa dano mágico e só aplica marca" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "R0 e R6 não caem em R1")
	var copied := definition.rank_definition(5)
	copied.power = 99.0
	_check(definition.rank_definition(5).power == 0.84, "recurso de catálogo permanece imutável")
	_check(&"lightning_wall" not in ClassCatalog.class_definition(&"mage").skill_ids, "biblioteca nova não altera kit piloto")

func _check_ranked_emission() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	for rank: int in [0, 1, 5, 6]:
		var source := _snapshot(rank)
		var state := RunState.from_build("lightning-wall-r%d" % rank, source)
		source.skill_ranks[&"lightning_wall"] = 1
		var player := PlayerActor.new()
		player.configure(navigation, state)
		player.position = Vector2(100, 100)
		root.add_child(player)
		var requests: Array[DamageRequest] = []
		player.lightning_wall_requested.connect(func(_direction: Vector2, request: DamageRequest) -> void: requests.append(request))
		var before_sp := player.current_sp
		var used := player.use_lightning_wall(Vector2.RIGHT)
		if rank in [0, 6]:
			_check(not used and requests.is_empty() and player.current_sp == before_sp and player.skill_rank_definition(&"lightning_wall") == null, "R%d não emite nem gasta" % rank)
		else:
			var expected_power := 0.50 if rank == 1 else 0.84
			var expected_cost := 22.0 if rank == 1 else 28.0
			_check(used and requests.size() == 1 and is_equal_approx(requests[0].magic_damage, player.stat_breakdown.value(&"magic_attack") * expected_power), "R%d captura dano-base numa emissão" % rank)
			_check(requests[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not requests[0].can_crit and requests[0].is_secondary, "R%d evita novo HIT e cascata de procs após cruzamento" % rank)
			_check(player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"lightning_wall") == StatCalculator.effective_cooldown(8.0, player.stat_breakdown), "R%d gasta SP e recarga uma vez" % rank)
			_check(player.skill_cast_time(&"lightning_wall") == StatCalculator.effective_cast_time(0.0, 0.38, player.stat_breakdown), "R%d escala preparo por DES" % rank)
			player.mage_cooldowns[&"lightning_wall"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_lightning_wall(Vector2.RIGHT) and requests.size() == 1 and player.current_sp == expected_cost - 1.0, "R%d bloqueia SP insuficiente" % rank)
		player.queue_free()

func _check_wall_geometry_and_clock() -> void:
	var caster := _target(Vector2(100, 100))
	var crossing := _target(Vector2(250, 100))
	var outside := _target(Vector2(250, 310))
	var overlapping := _target(Vector2(320, 100))
	for actor: CombatActor in [caster, crossing, outside, overlapping]:
		root.add_child(actor)
		actor.set_process(false)
	var request := DamageRequest.new()
	request.skill_id = &"lightning_wall"
	request.magic_damage = 15.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var targets: Array[CombatActor] = [crossing, outside, overlapping]
	var wall := LightningWall.new()
	wall.configure(caster, Vector2.RIGHT, request, targets, 220.0)
	root.add_child(wall)
	wall.set_process(false)
	var hits: Array[int] = []
	wall.crossed.connect(func(_request: DamageRequest, target: CombatActor) -> void: hits.append(target.get_instance_id()))
	_check(wall.global_position == Vector2(320, 100), "parede nasce no alcance direcional")
	_check(is_zero_approx(wall.axis.dot(Vector2.RIGHT)) and is_equal_approx(wall.axis.length(), 1.0), "parede é perpendicular ao cast")
	_check(wall.remaining == LightningWall.DURATION, "parede inicia com duração autorada")
	wall._process(0.01)
	_check(hits.is_empty(), "alvo inicialmente sobre a parede não sofre tick de criação")
	crossing.global_position = Vector2(390, 100)
	outside.global_position = Vector2(390, 310)
	wall._process(0.01)
	_check(hits == [crossing.get_instance_id()], "varredura captura travessia rápida sem acertar fora da extensão")
	wall._process(0.01)
	_check(hits.size() == 1, "alvo parado não recebe acertos por frame")
	crossing.global_position = Vector2(250, 100)
	wall._process(0.01)
	_check(hits.size() == 1, "intervalo por alvo bloqueia retravessia instantânea")
	var clock_before := wall.remaining
	paused = true
	wall._process(2.0)
	paused = false
	_check(wall.remaining == clock_before, "pausa congela vida e intervalos da parede")
	wall._process(LightningWall.TARGET_INTERVAL)
	crossing.global_position = Vector2(390, 100)
	wall._process(0.01)
	_check(hits.size() == 2, "após intervalo, nova travessia gera um novo contato")
	overlapping.global_position = Vector2(250, 100)
	wall._process(0.01)
	overlapping.global_position = Vector2(320, 100)
	wall._process(0.01)
	_check(hits.size() == 3 and hits[2] == overlapping.get_instance_id(), "alvo que nasceu sobre a linha só acerta ao sair e reentrar")
	wall._process(LightningWall.DURATION)
	_check(wall.remaining == 0.0 and wall.is_queued_for_deletion(), "parede expira e agenda limpeza")
	for actor: CombatActor in [caster, crossing, outside, overlapping]:
		actor.queue_free()
	await process_frame

func _check_menu_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mg3_lightning_wall")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg3-create", 0, "Maga de raios", &"mage")
	_check(created.get("ok", false), "Mago novo conserva slots vazios")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	_check(&"lightning_wall" not in facade.available_build_options(character_id)["active_skills"], "R0 não é equipável")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP usa store real")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil reabre antes das compras")
	for rank: int in range(1, 6):
		_check(facade.learn_skill("mg3-wall-%d" % rank, facade.current_profile().revision, character_id, &"lightning_wall").get("ok", false), "compra persistente da parede R%d" % rank)
	_check(facade.learn_skill("mg3-discharge", facade.current_profile().revision, character_id, &"electric_discharge").get("ok", false), "Descarga R1 compõe build de raio")
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var wall_selector := menu.active_selectors[0]
	var discharge_selector := menu.active_selectors[1]
	var wall_index := _option_index(wall_selector, &"lightning_wall")
	var discharge_index := _option_index(discharge_selector, &"electric_discharge")
	_check(wall_index >= 0 and discharge_index >= 0 and wall_selector.get_item_text(wall_index) == "Parede de Raios", "menu mostra as duas skills e nome visível")
	wall_selector.select(wall_index)
	discharge_selector.select(discharge_index)
	_check(menu._save_build().get("ok", false), "menu salva Parede e Descarga em slots distintos")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).presets[0]["active_slots"].slice(0, 2) == [&"lightning_wall", &"electric_discharge"], "reload preserva build de raio")
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
	var target := _target(controller.player.global_position + Vector2(160, 0))
	controller.add_child(target)
	target.set_process(false)
	controller.enemies.append(target)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"lightning_wall"]
	_check(controller.run_state.skill_levels[&"lightning_wall"] == 5 and card.text.contains("PAREDE DE RAIOS") and card.text.contains("R5") and card.text.contains("28 SP"), "HUD mostra rank e custo persistentes")
	controller.cast_intent.active_skill = &"lightning_wall"
	controller._update_aim(controller.player.global_position + Vector2(1000, 0))
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == controller.player.global_position + Vector2(220, 0), "mira mostra a linha na distância de colocação")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"lightning_wall", controller.player.global_position + Vector2(1000, 0))
	_check(controller.player.has_active_cast() and controller.player.current_sp == before_sp, "preparo não gasta cedo")
	controller.player.cancel_active_cast()
	_check(not controller.player.has_active_cast() and controller.player.current_sp == before_sp and get_nodes_in_group("player_effects").is_empty(), "cancelamento não cria parede")
	controller._commit_skill(&"lightning_wall", controller.player.global_position + Vector2(1000, 0))
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var effects := get_nodes_in_group("player_effects")
	var wall := effects.back() as LightningWall if not effects.is_empty() else null
	_check(wall != null and controller.player.current_sp == before_sp - 28.0 and controller.player.skill_cooldown(&"lightning_wall") == StatCalculator.effective_cooldown(8.0, controller.player.stat_breakdown), "controller cria parede e cobra uma vez")
	if wall != null:
		wall.set_process(false)
		var base_hp := target.health.current_hp
		target.global_position = controller.player.global_position + Vector2(280, 0)
		wall._process(0.01)
		_check(target.health.current_hp < base_hp and target.is_electrified() and not target.is_stunned(), "primeira travessia causa dano e marca sem stun")
		var after_first := target.health.current_hp
		target.global_position = controller.player.global_position + Vector2(160, 0)
		wall._process(0.01)
		_check(target.health.current_hp == after_first, "retravessia instantânea não gera dano múltiplo")
		wall._process(LightningWall.TARGET_INTERVAL)
		target.global_position = controller.player.global_position + Vector2(280, 0)
		wall._process(0.01)
		_check(target.health.current_hp < after_first and target.electrified_remaining == 4.0, "nova travessia após intervalo renova marca")
		controller._commit_skill(&"electric_discharge", target.global_position)
		controller.player._process(controller.player.active_cast_remaining + 0.01)
		var projectiles := get_nodes_in_group("player_projectiles")
		_check(projectiles.size() == 1, "Descarga equipada usa marca gerada pela parede")
		if projectiles.size() == 1:
			var projectile := projectiles[0] as MageProjectile
			projectile.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
			controller.rng.seed = 2
			projectile._process(0.40)
			_check(not target.is_electrified() and projectile.request.magic_damage > controller.player.stat_breakdown.value(&"magic_attack") * 1.10, "Descarga consome marca da parede e recebe bônus")
		controller._on_player_died(controller.player)
		_check(wall.is_queued_for_deletion(), "morte do jogador limpa Parede de Raios")
	paused = false
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false), "run fecha sem persistir parede ou marca")
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
	snapshot.character_id = "lightning-wall-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"lightning_wall": rank}
	snapshot.active_slots = [&"lightning_wall", null, null, null, null]
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
