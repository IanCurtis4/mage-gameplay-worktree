extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_mage_integrated")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("mg-integrated-create", 0, "Maga integrada", &"mage")
	_check(created.get("ok", false), "criação do Mago em perfil isolado")
	if not created.get("ok", false):
		_finish()
		return
	var character_id: String = created["character_id"]
	var expected_names := {
		&"fireball": "Bola de Fogo", &"fire_wall": "Parede de Fogo",
		&"fire_spear": "Lança de Fogo", &"ice_spear": "Lança de Gelo",
		&"lightning": "Relâmpago", &"electric_discharge": "Descarga Elétrica",
		&"lightning_wall": "Parede de Raios", &"soul_impact": "Impacto das Almas",
		&"haunt": "Assombro", &"phantom_barrier": "Barreira Fantasma",
		&"ice_wall": "Parede de Gelo", &"teleport": "Teleporte",
		&"mage_mana_regeneration": "Regeneração de SP",
	}
	_check(expected_names.size() == 13 and catalog.initial_skill_slots(&"mage")["active_slots"] == [null, null, null, null, null], "biblioteca e arrays legados vazios mantêm R0 fora da biblioteca aprendida")
	_check(not facade.available_build_options(character_id)["active_skills"].has(&"lightning"), "skill R0 não é atribuível à barra")
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture de 19 pontos usa store transacional isolado")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil com XP reabre")
	var learning_menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	learning_menu.set_profile_facade(facade)
	root.add_child(learning_menu)
	await process_frame
	learning_menu._select_roster_index(0)
	for skill_id: StringName in expected_names:
		var label := learning_menu.progression_skill_tree.get_node("ProgressionSkill_%s" % skill_id) as Label
		var button := learning_menu.progression_skill_tree.get_node("Learn_%s" % skill_id) as Button
		_check(label.text.begins_with(expected_names[skill_id]) and label.text.contains("Rank 0/") and not button.disabled, "menu publica %s comprável" % skill_id)
	var purchases: Array[StringName] = [
		&"fireball", &"fire_wall", &"fire_spear", &"ice_spear", &"lightning",
		&"electric_discharge", &"lightning_wall", &"soul_impact", &"haunt",
		&"phantom_barrier", &"ice_wall", &"teleport", &"mage_mana_regeneration",
		&"lightning", &"lightning", &"electric_discharge", &"phantom_barrier",
		&"ice_wall", &"mage_mana_regeneration",
	]
	for index: int in purchases.size():
		_check(learning_menu._learn_skill(purchases[index]).get("ok", false), "compra %d de 19: %s" % [index + 1, purchases[index]])
	for child: Node in learning_menu.action_editor.library.get_children():
		var skill_id: StringName = child.get("skill_id")
		_check((child as Button).text == expected_names[skill_id], "biblioteca identifica habilidade aprendida %s" % skill_id)
	_check(learning_menu.action_editor.learned_skills.size() == 12 and learning_menu.action_editor.slot_buttons.size() == 24 and learning_menu.automatic_passives_label.text.contains("todas automáticas"), "biblioteca aprendida e 24 atalhos coexistem com passivas automáticas")
	learning_menu.queue_free()
	await process_frame
	var progression := facade.progression_summary(character_id)
	_check(progression["base_skill_points_available"] == 0 and progression["effective_skill_ranks"].size() == 13, "19 pontos compram biblioteca Mago sem pontos gratuitos")
	var elemental: Array[Variant] = [&"fireball", &"fire_wall", &"ice_spear", &"lightning", &"electric_discharge"]
	var spiritual: Array[Variant] = [&"soul_impact", &"haunt", &"phantom_barrier", &"ice_wall", &"teleport"]
	var passive: Array[Variant] = [&"mage_mana_regeneration", null]
	var equipment: Dictionary[StringName, Variant] = facade.current_profile().character_by_id(character_id).equipped.duplicate(true)
	var saved_elemental := facade.update_preset("mg-elemental", facade.current_profile().revision, character_id, 0, elemental, passive, equipment)
	var saved_spiritual := facade.update_preset("mg-spiritual", facade.current_profile().revision, character_id, 1, spiritual, passive, equipment)
	_check(saved_elemental.get("ok", false) and saved_spiritual.get("ok", false), "dois presets distintos persistem com um slot passivo opcional vazio")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var reopened := reloaded.open_profile()
	_check(reopened.get("ok", false), "save com builds reabre")
	if reopened.get("ok", false):
		var character: CharacterState = reopened["profile"].character_by_id(character_id)
		_check(character.presets[0]["active_slots"] == elemental and character.presets[1]["active_slots"] == spiritual, "reload preserva os arrays legados de ativas")
		_check(character.presets[0]["passive_slots"] == passive and character.presets[1]["passive_slots"] == passive, "reload preserva array legado da passiva")
		await _run_build(reloaded, character_id, 0, elemental, passive)
		await _run_build(reloaded, character_id, 1, spiritual, passive)
	_check(catalog.skill_metadata(&"archer_precision").get("category") == ProfileCatalog.PASSIVE and catalog.skill_metadata(&"blood_thirst").get("category") == ProfileCatalog.PASSIVE and ClassCatalog.skill_definition(&"slash") != null, "catálogos Arqueiro/Espadachim permanecem disponíveis")
	_cleanup(directory)
	_finish()

func _run_build(facade: ProfileFacade, character_id: String, preset_index: int, active: Array[Variant], passive: Array[Variant]) -> void:
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var selected := menu._choose_preset(preset_index)
	var learned: Array[StringName] = []
	learned.assign(facade.available_build_options(character_id)["active_skills"])
	var bar := ActionBarLayout.empty()
	var ordered := _active_names(active)
	for id: StringName in learned:
		if id not in ordered:
			ordered.append(id)
	for index: int in ordered.size():
		bar[index] = ordered[index]
	menu._save_action_slots(bar)
	_check(facade.current_profile().character_by_id(character_id).action_slots == bar and facade.progression_summary(character_id)["base_skill_points_available"] == 0, "organizar todas aprendidas preserva carteira e persiste barra por personagem")
	var preview := facade.build_preview(character_id)
	var started := menu._start_run()
	_check(selected.get("ok", false) and preview.get("ok", false) and started.get("ok", false), "preset %d inicia run via menu" % preset_index)
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
	var snapshot := controller.run_state.build_snapshot
	_check(snapshot.active_slots == active and snapshot.passive_slots == passive and snapshot.action_slots == bar and controller.player.available_skill_ids() == learned and snapshot.learned_skill_ids(ProfileCatalog.PASSIVE).size() == 1, "run %d preserva arrays legados e usa todas aprendidas legais sem limite de cinco" % preset_index)
	_check(controller.run_state.skill_levels[&"lightning"] == 3 and controller.run_state.skill_levels[&"electric_discharge"] == 2 and controller.run_state.skill_levels[&"ice_wall"] == 2 and controller.run_state.skill_levels[&"mage_mana_regeneration"] == 2, "run %d captura ranks comprados")
	_check(controller.run_state.pending_choices == 0 and controller.run_state.augment_stacks.is_empty(), "run %d começa sem augment obrigatório" % preset_index)
	_check(is_equal_approx(controller.player.stat_breakdown.value(&"magic_attack"), preview["stat_breakdown"].value(&"magic_attack")) and is_equal_approx(controller.player.stat_breakdown.value(&"sp_regen"), preview["stat_breakdown"].value(&"sp_regen")), "preview/run compartilham MATQ e SP regen canônicos")
	var sp_before_regen: float = controller.player.max_sp - 10.0
	controller.player.current_sp = sp_before_regen
	controller.player._process(1.0)
	_check(is_equal_approx(controller.player.current_sp - sp_before_regen, controller.player.stat_breakdown.value(&"sp_regen")), "passiva R2 regenera SP pelo stat canônico durante encontro")
	controller.player.current_sp = controller.player.max_sp
	controller._update_hud()
	for skill_id: StringName in _active_names(active):
		var card: Button = controller.battle_controls.skill_buttons[skill_id]
		_check(card.tooltip_text.contains(ClassCatalog.skill_definition(skill_id).display_name.to_upper()) and card.tooltip_text.contains("R%d" % controller.run_state.skill_levels[skill_id]), "HUD apresenta %s equipado" % skill_id)
	var melee := controller.enemies[0] as EnemyActor
	melee.global_position = controller.player.global_position + Vector2(45, 0)
	controller.enemies[1].global_position = controller.player.global_position + Vector2(500, 150)
	var ranged := EnemyActor.new()
	ranged.configure(&"archer", controller.navigation, controller.player)
	ranged.global_position = controller.player.global_position + Vector2(300, 0)
	ranged.health.max_hp = 400.0
	ranged.health.current_hp = 400.0
	ranged.attack_requested.connect(controller._on_enemy_attack_requested)
	ranged.actor_died.connect(controller._on_enemy_died)
	ranged.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	ranged.damage_number.connect(controller._show_damage_number)
	ranged.attack_missed.connect(controller._show_miss)
	ranged.status_damage_requested.connect(controller._on_attack_requested)
	controller.add_child(ranged)
	controller.enemies.append(ranged)
	ranged.set_process(false)
	melee.player_target_acquired = true
	melee._try_attack(false)
	ranged.player_target_acquired = true
	ranged._try_attack(true)
	_check(melee.attack_cooldown > 0.0 and ranged.attack_cooldown > 0.0 and get_nodes_in_group("enemy_projectiles").size() == 1, "build %d enfrenta ataques melee/ranged reais" % preset_index)
	for arrow: Node in get_nodes_in_group("enemy_projectiles"):
		arrow.queue_free()
	melee.global_position = controller.player.global_position + Vector2(100, -150)
	if preset_index == 0:
		await _elemental_actions(controller, ranged)
	else:
		await _spiritual_actions(controller, melee, ranged)
	for enemy: CombatActor in controller.enemies.duplicate():
		var finishing := DamageRequest.new()
		finishing.source_id = controller.player.get_instance_id()
		finishing.target_id = enemy.get_instance_id()
		finishing.magic_damage = 100000.0
		finishing.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		finishing.can_crit = false
		enemy.apply_damage(finishing, controller.rng)
	_check(controller.enemies.is_empty() and not controller.encounter_active and controller.reward != null and not _has_ice_wall() and get_nodes_in_group("phantom_barriers").all(func(node: Node) -> bool: return node.is_queued_for_deletion()), "run %d encerra encontro e limpa barreiras temporárias" % preset_index)
	var collected := controller._collect_reward()
	_check(collected.get("ok", false) and controller.run_state.pending_choices == 1, "run %d concede recompensa antes do augment opcional" % preset_index)
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false) and facade.current_profile().reward_session == null, "run %d fecha sem persistir estados temporários" % preset_index)
	controller.queue_free()
	menu.queue_free()
	await process_frame

func _elemental_actions(controller: RunController, ranged: EnemyActor) -> void:
	var point := ranged.global_position
	controller.cast_intent.active_skill = &"lightning"
	controller._update_aim(point)
	_check(controller.battle_controls.aim_label.text.contains("PRONTO") and controller.battle_indicators.endpoint == point, "mira de Relâmpago acompanha alvo real")
	var before_sp := controller.player.current_sp
	controller._commit_skill(&"lightning", point)
	_check(controller.player.has_active_cast() and controller.player.current_sp == before_sp, "preparo de Relâmpago não antecipa custo")
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var lightning := _latest_projectile() as MageProjectile
	_check(lightning != null, "Relâmpago emite projétil na run")
	if lightning != null:
		lightning.set_process(false)
		lightning.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		lightning._process(0.5)
	_check(ranged.is_electrified(), "Relâmpago aplica Eletrizado após impacto")
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"electric_discharge", point)
	_check(controller.player.has_active_cast(), "Descarga prepara sobre alvo marcado")
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var discharge := _latest_projectile() as MageProjectile
	var hp_before := ranged.health.current_hp
	if discharge != null:
		discharge.set_process(false)
		discharge.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		discharge._process(0.5)
	_check(discharge != null and ranged.health.current_hp < hp_before and not ranged.is_electrified(), "Descarga consome marca e causa dano sem exigir stun aleatório")
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"ice_spear", point)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var ice := _latest_projectile() as MageProjectile
	if ice != null:
		ice.set_process(false)
		ice.request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		ice._process(0.5)
	_check(ice != null and ranged.slow_remaining > 0.0, "Lança de Gelo antiga ainda aplica slow")
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"fire_wall", point)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(get_nodes_in_group("player_effects").any(func(node: Node) -> bool: return node is FireWall), "Parede de Fogo antiga ainda cria efeito")
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"fireball", point)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(_latest_projectile() != null, "Bola de Fogo antiga ainda emite projétil")

func _spiritual_actions(controller: RunController, melee: EnemyActor, ranged: EnemyActor) -> void:
	var point := ranged.global_position
	controller._commit_skill(&"soul_impact", point)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(get_nodes_in_group("player_effects").any(func(node: Node) -> bool: return node is SoulImpactSequence), "Impacto das Almas cria sequência independente")
	melee.global_position = controller.player.global_position + Vector2(110, 0)
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"haunt", melee.global_position)
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	_check(melee.is_feared() and melee.weaken_remaining > 0.0, "Assombro aplica controle e enfraquecimento no melee")
	melee.global_position = controller.player.global_position + Vector2(100, -150)
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"phantom_barrier", controller.player.global_position + Vector2(500, 0))
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var barrier := _first_phantom_barrier()
	_check(barrier != null and barrier.remaining_capacity == 3 and controller.navigation.is_segment_walkable(controller.player.global_position, ranged.global_position), "Barreira Fantasma R2 intercepta sem bloquear navegação")
	if barrier != null:
		barrier.set_process(false)
		var arrow := ArrowProjectile.new()
		var request := DamageRequest.new()
		request.target_id = controller.player.get_instance_id()
		request.physical_damage = 100.0
		arrow.configure(request, controller.player, controller.player.global_position + Vector2(440, -18), controller.navigation)
		controller.add_child(arrow)
		arrow.set_process(false)
		var hp_before := controller.player.health.current_hp
		arrow._process(1.0)
		_check(arrow.is_queued_for_deletion() and barrier.remaining_capacity == 2 and controller.player.health.current_hp == hp_before, "barreira absorve projétil ranged antes do jogador")
	controller.player.current_sp = controller.player.max_sp
	controller._commit_skill(&"ice_wall", controller.player.global_position + Vector2(500, 0))
	controller.player._process(controller.player.active_cast_remaining + 0.01)
	var wall := _first_ice_wall()
	_check(wall != null and controller.navigation.has_temporary_segment(wall.get_instance_id()) and not controller.navigation.is_segment_walkable(controller.player.global_position, ranged.global_position), "Parede de Gelo R2 altera colisão temporária real")
	controller.player.current_sp = controller.player.max_sp
	var old_position := controller.player.global_position
	controller._commit_skill(&"teleport", old_position + Vector2(0, 120))
	_check(controller.player.global_position != old_position, "Teleporte antigo mantém mobilidade no preset espiritual")

func _first_ice_wall() -> IceWall:
	for node: Node in get_nodes_in_group("player_effects"):
		if node is IceWall and not node.is_queued_for_deletion():
			return node as IceWall
	return null

func _has_ice_wall() -> bool:
	return _first_ice_wall() != null

func _first_phantom_barrier() -> PhantomBarrier:
	for node: Node in get_nodes_in_group("phantom_barriers"):
		if node is PhantomBarrier and not node.is_queued_for_deletion():
			return node as PhantomBarrier
	return null

func _latest_projectile() -> PlayerProjectile:
	for node: Node in get_nodes_in_group("player_projectiles"):
		if node is PlayerProjectile and not node.is_queued_for_deletion():
			return node as PlayerProjectile
	return null

func _active_names(slots: Array[Variant]) -> Array[StringName]:
	var result: Array[StringName] = []
	for skill_id: Variant in slots:
		result.append(StringName(skill_id))
	return result

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
		push_error("Falha MGI: %s" % label)

func _finish() -> void:
	print("E04 Mago integrado: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)
