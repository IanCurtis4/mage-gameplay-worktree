extends SceneTree

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e04_swordsman_integrated")
	_cleanup(directory)
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	var created := facade.create_character("sw-integrated-create", 0, "Espadachim integrado", &"swordsman")
	_check(created.get("ok", false), "criação persistente do Espadachim")
	if not created.get("ok", false):
		_finish()
		return
	var character_id: String = created["character_id"]
	var seeded := facade.current_profile()
	seeded.character_by_id(character_id).job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(store.commit(seeded).get("ok", false), "fixture usa store isolado com 19 pontos de job")
	facade = ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile().get("ok", false), "perfil reabre sem migração")
	var menu_scene := load("res://scenes/character_menu.tscn") as PackedScene
	var learning_menu := menu_scene.instantiate() as CharacterMenu
	learning_menu.set_profile_facade(facade)
	root.add_child(learning_menu)
	await process_frame
	learning_menu._select_roster_index(0)
	var expected_names := {
		&"slash": "Corte em cone", &"dash": "Investida", &"shield_wall": "Parede de Escudos",
		&"provoke": "Provocar", &"perseverance": "Perseverança", &"piercing_shout": "Grito Perfurante",
		&"fury": "Fúria", &"brutal_strike": "Golpe Brutal", &"concentrated_rage": "Raiva Concentrada",
		&"terrifying_shout": "Grito Aterrorizante", &"swordsman_resistance": "Resistência",
		&"vigor": "Vigor", &"blood_thirst": "Sede de Sangue",
	}
	_check(expected_names.size() == 13 and catalog.initial_skill_slots(&"swordsman")["active_slots"] == [null, null, null, null, null], "biblioteca tem dez ativas/três passivas e não equipa R0")
	for skill_id: StringName in expected_names:
		var label := learning_menu.progression_skill_tree.get_node("ProgressionSkill_%s" % skill_id) as Label
		var button := learning_menu.progression_skill_tree.get_node("Learn_%s" % skill_id) as Button
		_check(label.text.begins_with(expected_names[skill_id]) and label.text.contains("Rank 0/") and not button.disabled, "menu mostra %s comprável" % skill_id)
	var purchases: Array[StringName] = [
		&"slash", &"dash", &"shield_wall", &"provoke", &"perseverance", &"piercing_shout",
		&"fury", &"brutal_strike", &"concentrated_rage", &"terrifying_shout",
		&"swordsman_resistance", &"vigor", &"blood_thirst",
		&"shield_wall", &"shield_wall", &"provoke", &"brutal_strike", &"vigor", &"blood_thirst",
	]
	for index: int in purchases.size():
		_check(learning_menu._learn_skill(purchases[index]).get("ok", false), "compra %d de %d: %s" % [index + 1, purchases.size(), purchases[index]])
	learning_menu.queue_free()
	await process_frame
	var progression := facade.progression_summary(character_id)
	_check(progression["base_skill_points_available"] == 0 and progression["effective_skill_ranks"].size() == 13, "19 pontos compram todo o catálogo Espadachim sem crédito grátis")
	var defender_active: Array[Variant] = [&"slash", &"shield_wall", &"provoke", &"perseverance", &"piercing_shout"]
	var berserker_active: Array[Variant] = [&"dash", &"fury", &"brutal_strike", &"concentrated_rage", &"terrifying_shout"]
	var defender_passive: Array[Variant] = [&"swordsman_resistance", &"vigor"]
	var berserker_passive: Array[Variant] = [&"blood_thirst", &"vigor"]
	var equipment: Dictionary[StringName, Variant] = facade.current_profile().character_by_id(character_id).equipped.duplicate(true)
	var defender_saved := facade.update_preset("sw-defender", facade.current_profile().revision, character_id, 0, defender_active, defender_passive, equipment)
	var berserker_saved := facade.update_preset("sw-berserker", facade.current_profile().revision, character_id, 1, berserker_active, berserker_passive, equipment)
	_check(defender_saved.get("ok", false) and berserker_saved.get("ok", false), "dois presets manuais persistem")
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), ProfileRewardResolver.pilot_progression())
	var reopened := reloaded.open_profile()
	_check(reopened.get("ok", false), "save reabre")
	if reopened.get("ok", false):
		var character: CharacterState = reopened["profile"].character_by_id(character_id)
		_check(character.presets[0]["active_slots"] == defender_active and character.presets[1]["active_slots"] == berserker_active, "reload preserva ativas distintas")
		_check(character.presets[0]["passive_slots"] == defender_passive and character.presets[1]["passive_slots"] == berserker_passive, "reload preserva passivas distintas")
		await _run_build(reloaded, 0, defender_active, defender_passive)
		await _run_build(reloaded, 1, berserker_active, berserker_passive)
	_check(ClassCatalog.class_definition(&"mage").skill_ids.size() == 5 and ClassCatalog.class_definition(&"archer").skill_ids.size() == 5 and catalog.skill_metadata(&"haunt").get("category") == ProfileCatalog.ACTIVE and catalog.skill_metadata(&"slowing_arrow").get("category") == ProfileCatalog.ACTIVE, "catálogos Mago/Arqueiro permanecem disponíveis")
	_cleanup(directory)
	_finish()

func _run_build(facade: ProfileFacade, preset_index: int, active: Array[Variant], passive: Array[Variant]) -> void:
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var selected := menu._choose_preset(preset_index)
	var character_id: String = facade.current_profile().characters[0].character_id
	var preview := facade.build_preview(character_id)
	var started := menu._start_run()
	_check(selected.get("ok", false) and preview.get("ok", false) and started.get("ok", false), "preset %d inicia run a partir do menu" % preset_index)
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
	_check(snapshot.active_slots == active and snapshot.passive_slots == passive and controller.player.available_skill_ids() == _active_names(active), "run %d usa exatamente cinco ativas e duas passivas" % preset_index)
	_check(controller.run_state.skill_levels[&"shield_wall"] == 3 and controller.run_state.skill_levels[&"provoke"] == 2 and controller.run_state.skill_levels[&"brutal_strike"] == 2 and controller.run_state.skill_levels[&"vigor"] == 2 and controller.run_state.skill_levels[&"blood_thirst"] == 2, "run %d captura ranks persistidos")
	_check(is_equal_approx(controller.player.stat_breakdown.value(&"melee_attack"), preview["stat_breakdown"].value(&"melee_attack")), "run %d e preview compartilham ATQ canônico" % preset_index)
	controller._update_hud()
	for skill_id: StringName in _active_names(active):
		var card: Button = controller.battle_controls.skill_buttons[skill_id]
		_check(card.text.contains(ClassCatalog.skill_definition(skill_id).display_name.to_upper()) and card.text.contains("R%d" % controller.run_state.skill_levels[skill_id]), "HUD mostra %s equipada no preset %d" % [skill_id, preset_index])
	var melee := controller.enemies[0] as EnemyActor
	melee.global_position = controller.player.global_position + Vector2(80, 0)
	controller.enemies[1].global_position = controller.player.global_position + Vector2(500, 0)
	var ranged := EnemyActor.new()
	ranged.configure(&"archer", controller.navigation, controller.player)
	ranged.global_position = controller.player.global_position + Vector2(280, 0)
	ranged.attack_requested.connect(controller._on_enemy_attack_requested)
	ranged.actor_died.connect(controller._on_enemy_died)
	ranged.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	ranged.damage_number.connect(controller._show_damage_number)
	ranged.attack_missed.connect(controller._show_miss)
	ranged.status_damage_requested.connect(controller._on_attack_requested)
	controller.add_child(ranged)
	controller.enemies.append(ranged)
	ranged.set_process(false)
	_check(controller.enemies.size() == 3 and ranged.is_alive() and melee.is_alive(), "run %d contém inimigos melee/ranged")
	var point := controller.player.global_position + Vector2(500, 0)
	if preset_index == 0:
		controller._commit_skill(&"shield_wall", point)
		_check(controller.player.has_shield_stance() and controller.player.shield_resistance == 4, "Defendente ergue postura R3")
		controller.player.current_sp = controller.player.max_sp
		controller._commit_skill(&"provoke", ranged.global_position)
		_check(controller.player.has_shield_stance() and ranged.taunt_remaining > 0.0 and ranged.attribute_debuffs.fraction(AttributeDebuffState.FLEE) == 0.30, "Provocar mantém postura e pressiona arqueiro")
		controller.player.current_sp = controller.player.max_sp
		controller._commit_skill(&"perseverance", controller.player.global_position)
		_check(controller.player.has_shield_stance() and controller.player.health.shield_hp > 0.0, "Perseverança e Parede coexistem")
		controller.player.current_sp = controller.player.max_sp
		controller._commit_skill(&"piercing_shout", controller.player.global_position)
		_check(not controller.player.has_shield_stance() and melee.attribute_debuffs.fraction(AttributeDebuffState.MOVE_SPEED) == 0.30 and melee.attribute_debuffs.fraction(AttributeDebuffState.ATTACK_SPEED) == 0.25, "pulso ofensivo encerra postura e afeta melee")
	else:
		var base_attack := controller.player.stat_breakdown.value(&"melee_attack")
		controller._commit_skill(&"fury", controller.player.global_position)
		_check(controller.player.fury_remaining > 0.0 and controller.player.stat_breakdown.value(&"melee_attack") > base_attack, "Berserker ativa Fúria")
		controller.player.health.current_hp -= 40.0
		var hp_before_kill := controller.player.health.current_hp
		melee.health.current_hp = 20.0
		controller.player.current_sp = controller.player.max_sp
		controller._commit_skill(&"brutal_strike", melee.global_position)
		_check(controller.player.has_active_cast() and controller.player.current_sp == controller.player.max_sp, "Golpe Brutal prepara sem gastar SP")
		controller.player._process(controller.player.active_cast_remaining + 0.01)
		_check(not melee.is_alive() and controller.player.health.current_hp > hp_before_kill, "Golpe Brutal mata e Sede de Sangue cura uma vez")
		ranged.global_position = controller.player.global_position + Vector2(120, 0)
		controller.player.current_sp = controller.player.max_sp
		controller._commit_skill(&"terrifying_shout", controller.player.global_position)
		_check(ranged.is_feared() and ranged.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_RECEIVED) == 0.20, "Grito Aterrorizante usa fear e amplificação")
		var ranged_hp := ranged.health.current_hp
		controller.player.current_sp = controller.player.max_sp
		controller._commit_skill(&"concentrated_rage", point)
		_check(controller.player.has_active_cast(), "Raiva Concentrada tem preparo por DES")
		controller.player._process(controller.player.active_cast_remaining + 0.01)
		_check(ranged.health.current_hp < ranged_hp and controller.player.velocity == Vector2.ZERO, "Raiva Concentrada atinge sem deslocar")
	for enemy: CombatActor in controller.enemies.duplicate():
		var finishing := DamageRequest.new()
		finishing.source_id = controller.player.get_instance_id()
		finishing.target_id = enemy.get_instance_id()
		finishing.physical_damage = 100000.0
		finishing.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		finishing.can_crit = false
		enemy.apply_damage(finishing, controller.rng)
	_check(controller.enemies.is_empty() and not controller.encounter_active and controller.reward != null and controller.player.health.shield_hp == 0.0 and controller.player.fury_remaining == 0.0, "run %d limpa estados temporários ao encerrar encontro" % preset_index)
	var collected := controller._collect_reward()
	_check(collected.get("ok", false) and controller.run_state.pending_choices == 1, "run %d registra recompensa sem depender de augments" % preset_index)
	var closed := controller._close_persistent_run(&"abandoned")
	_check(closed.get("ok", false) and facade.current_profile().reward_session == null, "run %d fecha sem persistir estados de combate" % preset_index)
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
		push_error("Falha SWI: %s" % label)

func _finish() -> void:
	print("E04 Espadachim integrado: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)
