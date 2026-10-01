extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174124"

var checks := 0
var failures := 0
var directory := ""
var request_sequence := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_spiritualist_integrated_closure")
	_cleanup(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	_check(catalog.is_valid() and catalog.evolution_is_ready(&"spiritualist", &"mage"), "catálogo de produção libera Espiritualista completo")
	var profile := ProfileState.new(PROFILE_ID)
	var boss_id := IdentityIds.character_id(PROFILE_ID, 1)
	var field_id := IdentityIds.character_id(PROFILE_ID, 2)
	for index: int in range(2):
		var character_id := boss_id if index == 0 else field_id
		var character := CharacterState.new(character_id, "Espiritualista %d" % index, &"mage")
		character.base_xp_total = ProgressionRules.MAX_BASE_XP
		character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
		profile.characters.append(character)
	profile.selected_character_id = boss_id
	profile.next_character_counter = 3
	var seeded := ProfileStore.new(directory, catalog).commit(profile)
	_check(seeded["ok"], "dois Magos de teste são persistidos sem tocar no save real")
	if not seeded["ok"]:
		_finish()
		return
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	_check(facade.open_profile()["ok"], "perfil isolado abre no menu")
	var menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	var pending := menu._begin_evolution_change(&"spiritualist")
	_check(pending["ok"] and facade.current_profile().character_by_id(boss_id).evolution_id.is_empty(), "menu exige confirmação para evoluir")
	var evolved := menu._confirm_evolution_change()
	_check(evolved["ok"] and facade.current_profile().character_by_id(boss_id).evolution_id == &"spiritualist", "menu confirma identidade Espiritualista")
	var summary := facade.progression_summary(boss_id)
	_check(summary["effective_skill_ranks"].get(&"spiritualist_echo_curse", 0) == 1 and facade.current_profile().character_by_id(boss_id).presets[0]["active_slots"].find(&"spiritualist_echo_curse") < 0, "Maldição R1 é grátis mas não autoequipada")
	menu.playtest_toggle.button_pressed = true
	var thousand := menu._apply_playtest_progression(&"job_xp", 1000)
	var gated := menu._learn_skill(&"spiritualist_soul_drain")
	_check(thousand["ok"] and facade.progression_summary(boss_id)["job_level"] == 22 and not gated["ok"] and gated["error_code"] == &"requirements_unmet", "+1000 XP leva ao job 22 e preserva gate 25")
	_check(menu._apply_playtest_progression(&"max_levels")["ok"], "atalho de playtest libera todos os gates do primeiro personagem")
	menu._select_roster_index(1)
	_check(menu._begin_evolution_change(&"spiritualist")["ok"] and menu._confirm_evolution_change()["ok"], "segundo Mago evolui pelo mesmo menu")
	_check(menu._apply_playtest_progression(&"max_levels")["ok"], "atalho libera gates do segundo personagem")
	menu.queue_free()
	await process_frame
	var boss_active: Array[Variant] = [&"spiritualist_echo_curse", &"spiritualist_soul_drain", &"spiritualist_procession", &"soul_impact", &"phantom_barrier"]
	var boss_passive: Array[Variant] = [&"spiritualist_echo_recovery", &"spiritualist_channel_focus"]
	var field_active: Array[Variant] = [&"spiritualist_echo_curse", &"spiritualist_spectral_veil", &"spiritualist_procession", &"spiritualist_dissipation", &"ice_wall"]
	var field_passive: Array[Variant] = [&"mage_mana_regeneration", &"spiritualist_echo_recovery"]
	_buy_build(facade, boss_id, {&"soul_impact": 5, &"phantom_barrier": 5, &"spiritualist_echo_curse": 4, &"spiritualist_soul_drain": 5, &"spiritualist_procession": 3, &"spiritualist_echo_recovery": 3, &"spiritualist_channel_focus": 3}, boss_active, boss_passive)
	_buy_build(facade, field_id, {&"ice_wall": 5, &"mage_mana_regeneration": 3, &"spiritualist_echo_curse": 2, &"spiritualist_spectral_veil": 5, &"spiritualist_procession": 3, &"spiritualist_dissipation": 5, &"spiritualist_echo_recovery": 2}, field_active, field_passive)
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := reloaded.open_profile()
	_check(opened["ok"] and opened["profile"].character_by_id(boss_id).presets[0]["active_slots"] == boss_active and opened["profile"].character_by_id(field_id).presets[0]["active_slots"] == field_active, "reload mantém as duas builds independentes")
	var selected := reloaded.select_character("spiritualist-select-boss", reloaded.current_profile().revision, boss_id)
	_check(selected["ok"], "perfil seleciona a build de boss")
	var entry := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	entry.set_profile_facade(reloaded)
	root.add_child(entry)
	await process_frame
	entry._select_roster_index(0)
	_check(entry.evolution_state_label.text.contains("Espiritualista"), "menu real identifica a classe persistida")
	var started := entry._start_run()
	if started["ok"]:
		await scene_changed
		await process_frame
	var controller := current_scene as RunController
	_check(started["ok"] and started["run_state"].build_snapshot.evolution_id == &"spiritualist" and started["run_state"].build_snapshot.skill_ranks[&"spiritualist_echo_curse"] == 5 and started["run_state"].build_snapshot.active_slots == boss_active, "menu→run conserva identidade, Maldição R5 e slots")
	_check(controller != null and controller.player.character_animation.actor_kind == &"spiritualist" and controller.class_button.text == "Classe: Espiritualista" and controller.battle_controls.skill_buttons.has(&"spiritualist_soul_drain"), "cena real usa atlas, HUD e comando do Espiritualista")
	if started["ok"]:
		_check_boss(started["run_state"])
		var ended := reloaded.end_run("spiritualist-end", started["new_revision"], started["run_id"], &"completed")
		_check(ended["ok"], "run encerra sem alterar a identidade")
		if ended["ok"]:
			var field_selected := reloaded.select_character("spiritualist-select-field", ended["new_revision"], field_id)
			_check(field_selected["ok"], "segundo personagem pode iniciar run com outra carteira legal")
			if field_selected["ok"]:
				var field_started := reloaded.start_run("spiritualist-field-run", field_selected["new_revision"])
				_check(field_started["ok"] and field_started["run_state"].build_snapshot.active_slots == field_active, "snapshot da segunda run conserva build de campo")
				if field_started["ok"]:
					_check_field_boss(field_started["run_state"])
					_check(reloaded.end_run("spiritualist-field-end", field_started["new_revision"], field_started["run_id"], &"completed")["ok"], "segunda run encerra sem vazar sessão")
	if controller != null:
		controller.queue_free()
	entry.queue_free()
	await process_frame
	_finish()

func _buy_build(facade: ProfileFacade, character_id: String, purchases: Dictionary, active: Array[Variant], passive: Array[Variant]) -> void:
	var revision: int = facade.current_profile().revision
	for skill_id: StringName in purchases:
		for rank_index: int in int(purchases[skill_id]):
			request_sequence += 1
			var result := facade.learn_skill("spiritualist-buy-%d" % request_sequence, revision, character_id, skill_id)
			_check(result["ok"], "compra legal de %s rank %d" % [skill_id, rank_index + 1])
			if result["ok"]:
				revision = result["new_revision"]
	var equipment: Dictionary[StringName, Variant] = {&"weapon": null, &"armor": null, &"accessory": null}
	var saved := facade.update_preset("build-%s" % character_id, revision, character_id, 0, active, passive, equipment)
	_check(saved["ok"], "preset legal equipa cinco ativas e duas passivas")

func _check_boss(run_state: RunState) -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, run_state)
	player.global_position = Vector2(400, 350)
	var boss := CombatActor.new()
	boss.setup("Boss", Color.WHITE, StatCalculator.calculate({&"vit": 20}), 24.0)
	boss.global_position = Vector2(470, 350)
	boss.health.max_hp = 100000.0
	boss.health.current_hp = 100000.0
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.enemies = [boss]
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller.rng.seed = 11
	controller.spiritualist_echo_state.source_id = player.get_instance_id()
	boss.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	player.spiritualist_echo_curse_requested.connect(func(request: DamageRequest, target: CombatActor, power: float) -> void:
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		request.can_crit = false
		controller._on_spiritualist_echo_curse_requested(request, target, power)
	)
	player.spiritualist_drain_requested.connect(func(request: DamageRequest, target: CombatActor) -> void:
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		request.can_crit = false
		controller._on_spiritualist_drain_requested(request, target)
	)
	player.spiritualist_procession_requested.connect(func(request: DamageRequest, target: CombatActor) -> void:
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		request.can_crit = false
		controller._on_spiritualist_procession_requested(request, target)
	)
	var hp_before := boss.health.current_hp
	var used := player.use_spiritualist_echo_curse(boss)
	_check(used and boss.health.current_hp < hp_before and controller.spiritualist_echo_state.has_mark(boss.get_instance_id()), "Maldição da build causa dano e marca boss solo")
	var after_curse := boss.health.current_hp
	_check(player.use_spiritualist_soul_drain(boss) and controller.spiritualist_drain_state.active, "Drenagem abre canal no mesmo boss")
	for tick_index: int in range(4):
		controller._advance_spiritualist_drain(0.5)
	_check(boss.health.current_hp < after_curse and controller.spiritualist_drain_state.ticks_resolved == 4 and not controller.spiritualist_drain_state.active and player.spiritualist_focus_remaining > 0.0, "quatro ticks reduzem HP e geram Foco no boss sem adds")
	var drain_pulses := controller.battle_indicators.spiritualist_return_wisps.filter(func(wisp: Dictionary) -> bool: return wisp["kind"] == &"drain")
	var recovery_pulses := controller.battle_indicators.spiritualist_return_wisps.filter(func(wisp: Dictionary) -> bool: return wisp["kind"] == &"recovery")
	_check(controller.spiritualist_echo_state.pending.size() == 1 and not controller.spiritualist_echo_state.has_mark(boss.get_instance_id()) and drain_pulses.size() == 4 and recovery_pulses.size() == 1, "primeiro tick consome marca uma vez; quatro pulsos de Drenagem e um Recolhimento real retornam ao caster")
	var before_echo := boss.health.current_hp
	for echo: Dictionary in controller.spiritualist_echo_state.advance(0.36):
		controller._apply_spiritualist_echo(echo)
	_check(boss.health.current_hp < before_echo and controller.spiritualist_echo_state.pending.is_empty(), "eco secundário atinge uma vez sem cascata")
	player.mage_cooldowns[&"spiritualist_echo_curse"] = 0.0
	player.current_sp = player.max_sp
	_check(player.use_spiritualist_echo_curse(boss) and player.spiritualist_focus_remaining == 0.0 and controller.spiritualist_echo_state.has_mark(boss.get_instance_id()), "segunda Maldição consome Foco no commit e renova marca")
	var before_procession := boss.health.current_hp
	_check(player.use_spiritualist_procession(boss), "Procissão é utilizável contra boss solo")
	controller._advance_spiritualist_procession(0.23)
	controller._advance_spiritualist_procession(0.20)
	controller._advance_spiritualist_procession(0.20)
	_check(boss.health.current_hp < before_procession and not controller.spiritualist_procession_state.active and controller.spiritualist_echo_state.pending.size() == 2, "Maldição reaplicada e primeiro impacto de Procissão criam ondas; impactos secundários não")
	player.free()
	boss.free()
	controller.battle_indicators.free()
	controller.free()

func _check_field_boss(run_state: RunState) -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, run_state)
	player.global_position = Vector2(400, 350)
	var boss := CombatActor.new()
	boss.setup("Boss de campo", Color.WHITE, StatCalculator.calculate({&"vit": 20}), 24.0)
	boss.global_position = Vector2(480, 350)
	boss.health.max_hp = 100000.0
	boss.health.current_hp = 100000.0
	var controller := RunController.new()
	controller.player = player
	controller.battle_indicators = BattleIndicators.new()
	controller.enemies = [boss]
	controller.navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	controller.rng.seed = 17
	controller.spiritualist_echo_state.source_id = player.get_instance_id()
	boss.health.damage_applied.connect(controller._on_enemy_damage_resolved)
	player.spiritualist_echo_curse_requested.connect(func(request: DamageRequest, target: CombatActor, power: float) -> void:
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		request.can_crit = false
		controller._on_spiritualist_echo_curse_requested(request, target, power)
	)
	player.spiritualist_veil_requested.connect(controller._on_spiritualist_veil_requested)
	player.spiritualist_dissipation_requested.connect(func(center: Vector2, request: DamageRequest, marked_bonus: float, focus_bonus: float) -> void:
		request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
		request.can_crit = false
		controller._on_spiritualist_dissipation_requested(center, request, marked_bonus, focus_bonus)
	)
	_check(player.use_spiritualist_echo_curse(boss) and controller.spiritualist_echo_state.has_mark(boss.get_instance_id()), "build de campo também marca boss solo")
	_check(player.use_spiritualist_spectral_veil(boss.global_position) and boss.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) >= 0.15, "Véu enfraquece boss dentro da área")
	var hp_before := boss.health.current_hp
	_check(player.use_spiritualist_dissipation(boss.global_position) and boss.health.current_hp < hp_before and not controller.spiritualist_echo_state.has_mark(boss.get_instance_id()) and controller.spiritualist_echo_state.pending.size() == 1, "Dissipação ativa onda após dano real em marcado")
	_check(boss.attribute_debuffs.fraction(AttributeDebuffState.DAMAGE_DEALT) >= 0.20, "fraqueza do Rito prevalece sobre Véu sem somar fontes")
	player.free()
	boss.free()
	controller.battle_indicators.free()
	controller.free()

func _finish() -> void:
	print("E05 Espiritualista fechamento integrado: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	_cleanup(directory)
	quit(0 if failures == 0 else 1)

func _cleanup(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for child: String in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
