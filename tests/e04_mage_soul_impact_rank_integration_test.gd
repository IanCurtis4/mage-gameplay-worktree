extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check_catalog_and_ranks()
	_check_ranked_emission()
	await _check_sequence()
	await _check_menu_and_controller()
	print("E04 MG4 Impacto das Almas: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_catalog_and_ranks() -> void:
	var definition := ClassCatalog.skill_definition(&"soul_impact")
	var catalog := ProfileCatalog.pilot()
	var metadata := catalog.skill_metadata(&"soul_impact")
	_check(definition != null and definition.display_name == "Impacto das Almas" and definition.targeting == SkillDefinition.Targeting.SINGLE_TARGET and definition.handler_id == SkillDefinition.Handler.SOUL_IMPACT and definition.is_rank_catalog_valid(), "catálogo publica alvo único com handler próprio")
	_check(metadata.get("category") == ProfileCatalog.ACTIVE and metadata.get("wallet") == ProfileCatalog.BASE_WALLET and metadata.get("free_rank") == 0 and metadata.get("max_purchased_rank") == 5, "biblioteca persistente começa em R0")
	var powers: Array[float] = [1.35, 1.58, 1.78, 1.95, 2.10]
	var costs: Array[float] = [19.0, 21.0, 23.0, 24.0, 25.0]
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank.power == powers[index] and rank.sp_cost == costs[index], "R%d usa dano total e SP autorados" % [index + 1])
		_check(rank.variable_cast_time == 0.36 and rank.fixed_cast_time == 0.0 and rank.cooldown == 6.0 and rank.range == 400.0 and rank.projectile_speed == 0.0, "R%d mantém preparo, recarga, alcance e três pulsos" % [index + 1])
		_check(rank.magic_weight == 1.0 and rank.physical_weight == 0.0 and rank.precision_weight == 0.0 and rank.effect_ids.is_empty(), "R%d não cria controle nem resistência espiritual" % [index + 1])
	_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "R0 e R6 não caem em rank válido")
	var copied := definition.rank_definition(5)
	copied.power = 99.0
	_check(definition.rank_definition(5).power == 2.10, "consulta não altera catálogo imutável")
	_check(&"soul_impact" not in ClassCatalog.class_definition(&"mage").skill_ids and catalog.initial_skill_slots(&"mage")["active_slots"] == [null, null, null, null, null], "biblioteca nova não vira loadout")

func _check_ranked_emission() -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1200, 800), [], 20.0)
	for rank: int in [0, 1, 5, 6]:
		var source := _snapshot(rank)
		var state := RunState.from_build("soul-impact-r%d" % rank, source)
		source.skill_ranks[&"soul_impact"] = 1
		var player := PlayerActor.new()
		player.configure(navigation, state)
		player.position = Vector2(100, 100)
		root.add_child(player)
		var target := _target(Vector2(300, 100))
		root.add_child(target)
		var requests: Array[DamageRequest] = []
		player.soul_impact_requested.connect(func(request: DamageRequest, emitted_target: CombatActor) -> void:
			if emitted_target == target:
				requests.append(request)
		)
		var before_sp := player.current_sp
		var used := player.use_soul_impact(target)
		if rank in [0, 6]:
			_check(not used and requests.is_empty() and player.current_sp == before_sp and player.skill_rank_definition(&"soul_impact") == null, "R%d não emite nem gasta" % rank)
		else:
			var expected_power := 1.35 if rank == 1 else 2.10
			var expected_cost := 19.0 if rank == 1 else 25.0
			_check(used and requests.size() == 1 and is_equal_approx(requests[0].magic_damage, player.stat_breakdown.value(&"magic_attack") * expected_power), "R%d emite uma sequência com dano total capturado" % rank)
			_check(requests[0].accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY and not requests[0].can_crit and not requests[0].is_secondary and requests[0].target_id == target.get_instance_id(), "R%d captura alvo e impacto sem novo HIT")
			_check(player.current_sp == before_sp - expected_cost and player.skill_cooldown(&"soul_impact") == StatCalculator.effective_cooldown(6.0, player.stat_breakdown), "R%d cobra SP e recarga uma vez" % rank)
			_check(player.skill_cast_time(&"soul_impact") == StatCalculator.effective_cast_time(0.0, 0.36, player.stat_breakdown), "R%d prepara com DES")
			player.mage_cooldowns[&"soul_impact"] = 0.0
			player.current_sp = expected_cost - 1.0
			_check(not player.use_soul_impact(target) and requests.size() == 1 and player.current_sp == expected_cost - 1.0, "R%d bloqueia SP insuficiente")
			player.current_sp = expected_cost
			target.global_position = Vector2(650, 100)
			_check(not player.use_soul_impact(target) and requests.size() == 1 and player.current_sp == expected_cost, "R%d rejeita alvo fora do alcance")
		player.queue_free()
		target.queue_free()

func _check_sequence() -> void:
	var target := _target(Vector2(300, 100))
	root.add_child(target)
	target.set_process(false)
	var total := DamageRequest.new()
	total.skill_id = &"soul_impact"
	total.magic_damage = 90.0
	total.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	var sequence := SoulImpactSequence.new()
	sequence.configure(total, target)
	root.add_child(sequence)
	sequence.set_process(false)
	total.magic_damage = 900.0
	var pulses: Array[DamageRequest] = []
	sequence.impact.connect(func(request: DamageRequest, _target_actor: CombatActor) -> void: pulses.append(request))
	sequence._process(0.0)
	_check(pulses.size() == 1 and pulses[0].magic_damage == 30.0 and not pulses[0].is_secondary, "primeiro pulso divide orçamento capturado e mantém origem primária")
	_check(SoulImpactSequence.ORB_TEXTURE.get_size() == Vector2(64, 64) and sequence.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and sequence.z_index > target.z_index, "esfera 64×64 usa nearest e aparece acima do alvo")
	sequence._process(SoulImpactSequence.IMPACT_INTERVAL * 0.5)
	_check(pulses.size() == 1 and sequence.visual_remaining < SoulImpactSequence.VISUAL_TAIL and sequence.visual_remaining > 0.0, "esfera expande e perde opacidade entre impactos sem novo dano")
	var clock := sequence.time_to_next
	paused = true
	sequence._process(2.0)
	paused = false
	_check(sequence.time_to_next == clock and pulses.size() == 1, "pausa congela sequência")
	target.global_position = Vector2(900, 300)
	sequence._process(SoulImpactSequence.IMPACT_INTERVAL)
	_check(pulses.size() == 2 and sequence.global_position == target.global_position and pulses[1].magic_damage == 30.0 and pulses[1].is_secondary, "alvo travado continua recebendo pulso sem recálculo ou novo proc")
	sequence._process(SoulImpactSequence.IMPACT_INTERVAL)
	_check(pulses.size() == 3 and pulses[2].magic_damage == 30.0 and pulses[2].is_secondary and pulses[0].magic_damage + pulses[1].magic_damage + pulses[2].magic_damage == 90.0, "três pulsos respeitam dano total, sem multiplicá-lo")
	sequence._process(SoulImpactSequence.VISUAL_TAIL)
	_check(sequence.is_queued_for_deletion(), "sequência remove cauda visual")
	var interrupted := SoulImpactSequence.new()
	interrupted.configure(total, target)
	root.add_child(interrupted)
	interrupted.set_process(false)
	interrupted._process(0.0)
	var lethal := DamageRequest.new()
	lethal.target_id = target.get_instance_id()
	lethal.magic_damage = 100000.0
	lethal.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	target.apply_damage(lethal, RandomNumberGenerator.new())
	interrupted._process(SoulImpactSequence.IMPACT_INTERVAL)
	_check(interrupted.emitted == 1 and interrupted.is_queued_for_deletion(), "morte do alvo interrompe pulsos restantes")
	target.queue_free()
	await process_frame

func _check_menu_and_controller() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mg4_soul_impact")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg4-create", 0, "Maga das almas", &"mage")
	_check(created.get("ok", false), "menu cria Mago com slots vazios")
	if not created.get("ok", false):
		return
	var character_id: String = created["character_id"]
	_check(&"soul_impact" not in facade.available_build_options(character_id)["active_skills"], "R0 não é equipável")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de XP usa store real")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil reabre antes das compras")
	for rank: int in range(1, 6):
		_check(facade.learn_skill("mg4-impact-%d" % rank, facade.current_profile().revision, character_id, &"soul_impact").get("ok", false), "compra persistente R%d" % rank)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var learned_button: Button
	for child: Node in menu.action_editor.library.get_children():
		if child.get("skill_id") == &"soul_impact":
			learned_button = child as Button
	_check(learned_button != null and learned_button.text == "Impacto das Almas", "biblioteca apresenta nome humano da skill aprendida")
	menu.action_editor.assign_skill(&"soul_impact", 0)
	_check(facade.current_profile().character_by_id(character_id).action_slots[0] == &"soul_impact", "menu salva organização de atalhos pela fachada")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var opened := reopened.open_profile()
	_check(opened.get("ok", false) and opened["profile"].character_by_id(character_id).action_slots[0] == &"soul_impact", "save/reload conserva preset")
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
	var target := _target(controller.player.global_position + Vector2(180, 0))
	controller.add_child(target)
	target.set_process(false)
	controller.enemies.append(target)
	controller._update_hud()
	var card: Button = controller.battle_controls.skill_buttons[&"soul_impact"]
	_check(controller.run_state.skill_levels[&"soul_impact"] == 5 and card.tooltip_text.contains("IMPACTO DAS ALMAS") and card.tooltip_text.contains("R5") and card.tooltip_text.contains("25 SP"), "HUD reflete rank e custo persistidos")
	controller.cast_intent.active_skill = &"soul_impact"
	controller._update_aim(target.global_position)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == target.global_position, "mira fixa alvo selecionado")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"soul_impact", target.global_position)
	_check(controller.player.has_active_cast() and controller.player.current_sp == before_sp, "preparo não gasta antecipadamente")
	controller.player.cancel_active_cast()
	_check(not controller.player.has_active_cast() and controller.player.current_sp == before_sp and get_nodes_in_group("player_effects").is_empty(), "cancelamento não gera pulsos")
	controller._commit_skill(&"soul_impact", target.global_position)
	target.global_position = controller.player.global_position + Vector2(600, 0)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(controller.player.current_sp == before_sp and get_nodes_in_group("player_effects").is_empty(), "alvo que sai do alcance durante preparo cancela sem gasto")
	target.global_position = controller.player.global_position + Vector2(180, 0)
	controller._commit_skill(&"soul_impact", target.global_position)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var effects := get_nodes_in_group("player_effects")
	var sequence := effects.back() as SoulImpactSequence if not effects.is_empty() else null
	_check(sequence != null and controller.player.current_sp == before_sp - 25.0 and controller.player.skill_cooldown(&"soul_impact") == StatCalculator.effective_cooldown(6.0, controller.player.stat_breakdown), "controller cria sequência e cobra uma vez")
	if sequence != null:
		sequence.set_process(false)
		var before_hp := target.health.current_hp
		sequence._process(0.0)
		sequence._process(SoulImpactSequence.IMPACT_INTERVAL)
		sequence._process(SoulImpactSequence.IMPACT_INTERVAL)
		_check(sequence.emitted == 3 and target.health.current_hp < before_hp and not target.is_electrified() and not target.is_stunned(), "três danos mágicos aplicados sem marca ou controle")
		controller._on_player_died(controller.player)
		_check(sequence.is_queued_for_deletion(), "morte do jogador limpa sequência")
	paused = false
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false), "run fecha sem persistir sequência")
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
	snapshot.character_id = "soul-impact-test"
	snapshot.base_class_id = &"mage"
	snapshot.skill_ranks = {&"soul_impact": rank}
	snapshot.active_slots = [&"soul_impact", null, null, null, null]
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
