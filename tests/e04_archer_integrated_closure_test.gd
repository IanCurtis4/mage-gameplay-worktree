extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_archer_integrated")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("archer-create", 0, "Arqueira integrada", &"archer")
	_check(created.get("ok", false), "Arqueiro pode ser criado no perfil real")
	if not created.get("ok", false):
		_finish()
		return
	var character_id: String = created["character_id"]
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture concede XP de job válido pelo armazenamento transacional")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil com XP reabre sem migração")
	var learning_menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	learning_menu.set_profile_facade(facade)
	root.add_child(learning_menu)
	await process_frame
	learning_menu._select_roster_index(0)
	var expected_names := {
		&"double_shot": "Disparo Duplo", &"piercing_arrow": "Flecha Perfurante",
		&"arrow_rain": "Chuva de Flechas", &"extended_aim": "Mira Estendida",
		&"snare_trap": "Armadilha de Laço", &"explosive_trap": "Armadilha Explosiva",
		&"slowing_arrow": "Flecha Entorpecente", &"foliage_shelter": "Abrigo de Folhagem",
		&"archer_precision": "Precisão", &"archer_cadence": "Cadência",
		&"trap_technique": "Técnica de Armadilhas",
	}
	for skill_id: StringName in expected_names:
		var label := learning_menu.progression_skill_tree.get_node("ProgressionSkill_%s" % skill_id) as Label
		var button := learning_menu.progression_skill_tree.get_node("Learn_%s" % skill_id) as Button
		_check(label.text.begins_with(expected_names[skill_id]) and label.text.contains("Rank 0/") and not button.disabled, "árvore identifica e permite aprender %s em R0" % skill_id)
		_check(not label.tooltip_text.contains("ainda não estão disponíveis") and label.tooltip_text.contains("não equipa automaticamente"), "tooltip de %s descreve o fluxo vigente" % skill_id)
	var purchases: Array[StringName] = [
		&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim",
		&"snare_trap", &"explosive_trap", &"slowing_arrow", &"foliage_shelter",
		&"archer_precision", &"archer_cadence", &"trap_technique",
		&"double_shot", &"double_shot", &"arrow_rain", &"explosive_trap",
		&"archer_precision", &"archer_precision", &"trap_technique", &"trap_technique",
	]
	for index: int in purchases.size():
		var skill_id := purchases[index]
		var result := learning_menu._learn_skill(skill_id)
		_check(result.get("ok", false), "compra persistente %d: %s" % [index + 1, skill_id])
	for selector: OptionButton in [learning_menu.active_selectors[0], learning_menu.passive_selectors[0]]:
		for index: int in range(1, selector.item_count):
			var skill_id: StringName = selector.get_item_metadata(index)
			_check(selector.get_item_text(index) == expected_names[skill_id], "slot identifica habilidade aprendida %s" % skill_id)
	learning_menu.queue_free()
	await process_frame
	var progression := facade.progression_summary(character_id)
	_check(progression["base_skill_points_available"] == 0 and progression["effective_skill_ranks"].size() == 11, "19 pontos compram oito ativas e três passivas com ranks distintos")

	var bow_active: Array[Variant] = [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"slowing_arrow"]
	var trap_active: Array[Variant] = [&"snare_trap", &"explosive_trap", &"foliage_shelter", &"slowing_arrow", &"double_shot"]
	var bow_passive: Array[Variant] = [&"archer_precision", &"archer_cadence"]
	var trap_passive: Array[Variant] = [&"trap_technique", &"archer_precision"]
	var equipment: Dictionary[StringName, Variant] = facade.current_profile().character_by_id(character_id).equipped.duplicate(true)
	var bow_saved := facade.update_preset("bow-build", facade.current_profile().revision, character_id, 0, bow_active, bow_passive, equipment)
	var trap_saved := facade.update_preset("trap-build", facade.current_profile().revision, character_id, 1, trap_active, trap_passive, equipment)
	_check(bow_saved.get("ok", false) and trap_saved.get("ok", false), "dois presets diferentes persistem sem alterar catálogo")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var reopened := reloaded.open_profile()
	_check(reopened.get("ok", false), "perfil com dois presets reabre")
	if reopened.get("ok", false):
		var character: CharacterState = reopened["profile"].character_by_id(character_id)
		_check(character.presets[0]["active_slots"] == bow_active and character.presets[1]["active_slots"] == trap_active, "reload preserva ambos os atalhos ativos")
		_check(character.presets[0]["passive_slots"] == bow_passive and character.presets[1]["passive_slots"] == trap_passive, "reload preserva combinações passivas diferentes")
		await _run_build(reloaded, character_id, 0, bow_active, bow_passive)
		await _run_build(reloaded, character_id, 1, trap_active, trap_passive)
	_cleanup(directory)
	_finish()

func _run_build(facade: ProfileFacade, character_id: String, preset_index: int, active: Array[Variant], passive: Array[Variant]) -> void:
	var menu_scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var selected := menu._choose_preset(preset_index)
	var preview := facade.build_preview(character_id)
	var started := menu._start_run()
	_check(selected.get("ok", false) and preview.get("ok", false) and started.get("ok", false), "preset %d passa do menu ao início da run" % preset_index)
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
	_check(snapshot.active_slots == active and snapshot.passive_slots == passive and controller.player.available_skill_ids() == _active_names(active), "run %d usa slots do preset selecionado" % preset_index)
	_check(controller.run_state.skill_levels[&"double_shot"] == 3 and controller.run_state.skill_levels[&"archer_precision"] == 3 and controller.run_state.skill_levels[&"trap_technique"] == 3, "run %d captura ranks comprados sem depender de augments" % preset_index)
	_check(controller.run_state.pending_choices == 0 and controller.run_state.augment_stacks.is_empty(), "run %d começa sem escolha ou modificador de augment" % preset_index)
	_check(is_equal_approx(controller.player.stat_breakdown.value(&"hit_rating"), preview["stat_breakdown"].value(&"hit_rating")), "run %d compartilha HIT canônico com preview" % preset_index)
	var ranged := EnemyActor.new()
	ranged.configure(&"archer", controller.navigation, controller.player)
	ranged.global_position = controller.player.global_position + Vector2(280, 0)
	ranged.attack_requested.connect(controller._on_enemy_attack_requested)
	ranged.actor_died.connect(controller._on_enemy_died)
	ranged.damage_number.connect(controller._show_damage_number)
	ranged.attack_missed.connect(controller._show_miss)
	ranged.status_damage_requested.connect(controller._on_attack_requested)
	controller.add_child(ranged)
	controller.enemies.append(ranged)
	ranged.set_process(false)
	_check(controller.enemies.size() == 3 and ranged.is_alive(), "build %d enfrenta melee e ranged no mesmo encontro" % preset_index)
	var melee := controller.enemies[0] as EnemyActor
	melee.global_position = controller.player.global_position + Vector2(45, 0)
	melee.player_target_acquired = true
	melee._try_attack(false)
	ranged.player_target_acquired = true
	ranged._try_attack(true)
	_check(melee.attack_cooldown > 0.0 and ranged.attack_cooldown > 0.0 and get_nodes_in_group("enemy_projectiles").size() == 1, "build %d recebe investida melee e disparo ranged reais" % preset_index)
	if preset_index == 0:
		controller._commit_skill(&"double_shot", ranged.global_position)
		controller._commit_skill(&"arrow_rain", ranged.global_position)
		_check(get_nodes_in_group("player_projectiles").size() >= 2 and get_nodes_in_group("player_effects").size() >= 1, "build de arco emite projéteis e chuva no controller real")
	else:
		var snare_point := controller.player.global_position + Vector2(180, 0)
		var explosive_point := controller.player.global_position + Vector2(180, 80)
		controller._commit_skill(&"snare_trap", snare_point)
		controller._commit_skill(&"explosive_trap", explosive_point)
		var traps := controller.trap_registry.active_traps(controller.player.get_instance_id())
		_check(traps.size() == 2 and traps[0].armed_duration == 21.0 and traps[1].armed_duration == 21.0, "build de armadilhas aplica Técnica R3 aos dois tipos")
	for enemy: CombatActor in controller.enemies.duplicate():
		var finishing := DamageRequest.new()
		finishing.source_id = controller.player.get_instance_id()
		finishing.target_id = enemy.get_instance_id()
		finishing.physical_damage = 100000.0
		finishing.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		finishing.can_crit = false
		enemy.apply_damage(finishing, controller.rng)
	_check(controller.enemies.is_empty() and not controller.encounter_active and controller.reward != null, "build %d conclui encontro e gera recompensa" % preset_index)
	var collected := controller._collect_reward()
	_check(collected.get("ok", false) and controller.run_state.pending_choices == 1, "build %d salva XP antes de oferecer augment opcional" % preset_index)
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false) and facade.current_profile().reward_session == null, "build %d fecha run sem escolher augment" % preset_index)
	controller.queue_free()
	menu.queue_free()
	await process_frame

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
		push_error(label)

func _finish() -> void:
	print("E04 Arqueiro integrado: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)
