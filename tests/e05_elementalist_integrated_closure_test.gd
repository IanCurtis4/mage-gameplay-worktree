extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174123"

var checks := 0
var failures := 0
var directory := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_elementalist_integrated_closure")
	_cleanup(directory)
	DirAccess.make_dir_recursive_absolute(directory)
	var catalog := ProfileCatalog.pilot()
	if not catalog.evolution_is_ready(&"elementalist", &"mage"):
		print("E05 Elementalista fechamento: BLOQUEADO por content_ready=false; reexecute após habilitar o catálogo de produção")
		_cleanup(directory)
		quit(0)
		return
	var resolver := ProfileRewardResolver.new({&"elementalist_completion": {"base_xp": 100, "job_xp": 80}})
	_check(catalog.is_valid(), "catálogo de produção está íntegro no fechamento")
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Elementalista E05", &"mage")
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	var seeded := ProfileStore.new(directory, catalog).commit(profile)
	if not seeded["ok"]:
		print("fixture seed result: ", seeded)
	_check(seeded["ok"], "fixture mage é persistida em diretório isolado")
	if not seeded["ok"]:
		_cleanup(directory)
		quit(1)
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog), resolver)
	var opened := facade.open_profile()
	var before: CharacterState = opened["profile"].character_by_id(character_id)
	var evolved := facade.change_evolution("elementalist-choice", opened["profile"].revision, character_id, &"elementalist")
	var evolved_character: CharacterState = facade.current_profile().character_by_id(character_id)
	_check(evolved["ok"] and evolved_character.evolution_id == &"elementalist" and evolved_character.job_xp_total == before.job_xp_total, "menu/evolução sintética preserva XP e grava identidade Elementalista")
	_check(facade.progression_summary(character_id)["effective_skill_ranks"].get(&"elementalist_flame_burst", 0) == 1 and evolved_character.presets[0]["active_slots"].find(&"elementalist_flame_burst") < 0, "entrada R1 é gratuita, mas não autoequipada")
	var at_entry_revision := facade.current_profile().revision
	var xp := facade.grant_playtest_progression("job-xp-1000", at_entry_revision, character_id, &"job_xp", 1000)
	var gated := facade.learn_skill("gate-check", xp["new_revision"], character_id, &"elementalist_glacial_ring")
	_check(xp["ok"] and facade.progression_summary(character_id)["job_level"] == 22 and not gated["ok"] and gated["error_code"] == &"requirements_unmet", "XP de job atualiza carteira e mantém skill de gate 25 bloqueada no job 22")
	var maxed := facade.grant_playtest_progression("max-levels", facade.current_profile().revision, character_id, &"max_levels")
	_check(maxed["ok"], "XP de job sintético alcança todos os gates sem save real de produção")
	var base_revision: int = maxed["new_revision"]
	for base_skill_id: StringName in [&"fire_spear", &"ice_spear"]:
		var base_learned := facade.learn_skill("buy-base-%s" % base_skill_id, base_revision, character_id, base_skill_id)
		_check(base_learned["ok"], "compra %s usa carteira base separada" % base_skill_id)
		if base_learned["ok"]:
			base_revision = base_learned["new_revision"]
	var purchases := {
		&"elementalist_flame_burst": 4, &"elementalist_glacial_ring": 1,
		&"elementalist_lightning_arc": 1, &"elementalist_ember_path": 1,
		&"elementalist_tri_nova": 1, &"elementalist_prismatic_focus": 3,
		&"elementalist_prismatic_resonance": 3,
	}
	var revision: int = base_revision
	for skill_id: StringName in purchases:
		for rank_index: int in int(purchases[skill_id]):
			var learned := facade.learn_skill("buy-%s-%d" % [skill_id, rank_index], revision, character_id, skill_id)
			_check(learned["ok"], "compra de %s rank %d respeita carteira/gate" % [skill_id, rank_index + 1])
			if learned["ok"]:
				revision = learned["new_revision"]
	var build_a_active: Array[Variant] = [&"elementalist_flame_burst", &"elementalist_glacial_ring", &"elementalist_lightning_arc", &"elementalist_ember_path", &"elementalist_tri_nova"]
	var build_a_passive: Array[Variant] = [&"elementalist_prismatic_focus", &"elementalist_prismatic_resonance"]
	var build_b_active: Array[Variant] = [&"elementalist_flame_burst", &"elementalist_glacial_ring", &"elementalist_lightning_arc", null, null]
	var build_b_passive: Array[Variant] = [&"elementalist_prismatic_focus", null]
	var empty_equipment: Dictionary[StringName, Variant] = {&"weapon": null, &"armor": null, &"accessory": null}
	var saved_a := facade.update_preset("build-a", revision, character_id, 0, build_a_active, build_a_passive, empty_equipment)
	_check(saved_a["ok"], "primeira build Elementalista equipa 5 ativas e 2 passivas legais")
	revision = saved_a["new_revision"]
	var saved_b := facade.update_preset("build-b", revision, character_id, 1, build_b_active, build_b_passive, empty_equipment)
	_check(saved_b["ok"], "segunda build combina herdadas do Mago e Elementalista em slots legais")
	revision = saved_b["new_revision"]
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog), resolver)
	var reload_result := reloaded.open_profile()
	var durable: CharacterState = reload_result["profile"].character_by_id(character_id)
	_check(reload_result["ok"] and durable.evolution_id == &"elementalist" and durable.presets[0]["active_slots"] == build_a_active and durable.presets[1]["active_slots"] == build_b_active, "reload preserva identidade, ranks e ambas as builds")
	var menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	menu.set_profile_facade(reloaded)
	root.add_child(menu)
	await process_frame
	menu._select_roster_index(0)
	_check(menu.evolution_state_label.text.contains("Elementalista") and menu.start_run_button.text.contains("Elementalista E05"), "menu real reflete identidade e caminho de evolução persistidos")
	var started := reloaded.start_run("elementalist-run", reload_result["profile"].revision)
	_check(started["ok"] and started["run_state"].build_snapshot.evolution_id == &"elementalist" and started["run_state"].build_snapshot.skill_ranks[&"elementalist_flame_burst"] == 5 and started["run_state"].build_snapshot.active_slots == build_b_active, "run snapshot preserva evolução, R5 e a build selecionada")
	if started["ok"]:
		_check_elementalist_boss(started["run_state"])
		var run_id: String = started["run_id"]
		var reward := reloaded.grant_reward("elementalist-reward", started["new_revision"], run_id, 1, &"elementalist_completion")
		_check(reward["ok"] and reloaded.current_profile().character_by_id(character_id).evolution_id == &"elementalist", "recompensa aplica XP sem trocar identidade Elementalista")
		var ended := reloaded.end_run("elementalist-end", reward["new_revision"], run_id, &"completed")
		_check(ended["ok"] and reloaded.current_profile().reward_session == null, "encerramento limpa sessão de run após recompensa")
	menu.queue_free()
	print("E05 Elementalista fechamento integrado: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	_cleanup(directory)
	quit(0 if failures == 0 else 1)

func _check_elementalist_boss(run_state: RunState) -> void:
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, run_state)
	player.global_position = Vector2(400, 350)
	var boss := CombatActor.new()
	boss.setup("Boss Elementalista", Color.WHITE, StatCalculator.calculate({&"vit": 20}), 24.0)
	boss.global_position = Vector2(470, 350)
	boss.health.max_hp = 100000.0
	boss.health.current_hp = 100000.0
	var controller := RunController.new()
	controller.player = player
	controller.enemies = [boss]
	player.elementalist_flame_burst_requested.connect(controller._on_elementalist_flame_burst_requested)
	var hp_before := boss.health.current_hp
	var emitted := player.use_elementalist_flame_burst(boss.global_position)
	_check(emitted and boss.health.current_hp < hp_before and boss.is_alive(), "boss solo recebe dano real pelo callback da habilidade Elementalista")
	player.free()
	boss.free()
	controller.free()

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
