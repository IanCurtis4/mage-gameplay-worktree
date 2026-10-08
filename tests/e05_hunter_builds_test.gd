extends SceneTree
## H5 legal Hunter builds, save/menu/run round-trip. Uses only isolated verification saves.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174237"
const ROOT_DIRECTORY := "res://.godot/verification/e05_hunter_builds"
const DIRECTORIES: Array[String] = [
	"blocked", "preparadora", "emboscadora", "menu20", "menu23", "menu25",
	"menu28", "menu31", "menu34", "menu37", "admin",
	"tooltip_hunter", "tooltip_archer", "tooltip_sentinel",
]
const GATES: Array[int] = [20, 20, 23, 25, 28, 31, 34, 37]
const BASE_PURCHASES := {
	&"double_shot": 5, &"piercing_arrow": 5, &"arrow_rain": 5,
	&"archer_precision": 3, &"archer_cadence": 1,
}
const EQUIPPED: Dictionary[StringName, Variant] = {
	&"weapon": null, &"armor": null, &"accessory": null,
}

var directory := ""
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path(ROOT_DIRECTORY)
	_cleanup()
	DirAccess.make_dir_recursive_absolute(directory)
	_check_catalog_and_admin_gate()
	_check_rank_gates()
	await _check_menu_gate(20, "menu20")
	await _check_menu_gate(23, "menu23")
	await _check_menu_gate(25, "menu25")
	await _check_menu_gate(28, "menu28")
	await _check_menu_gate(31, "menu31")
	await _check_menu_gate(34, "menu34")
	await _check_menu_gate(37, "menu37")
	await _check_shelter_tooltips()
	await _check_build("preparadora", {
		&"hunter_freezing_trap": 4, &"hunter_tar_trap": 4, &"hunter_thorn_trap": 4,
		&"hunter_mark": 2, &"hunter_shooting_discipline": 2, &"hunter_easy_prey": 2,
		&"hunter_covering_shot": 1, &"hunter_total_cover": 1,
	}, {&"int": 35, &"dex": 30, &"vit": 25}, [
		&"double_shot", &"piercing_arrow", &"hunter_freezing_trap", &"hunter_tar_trap", &"hunter_thorn_trap",
	])
	await _check_build("emboscadora", {
		&"hunter_tar_trap": 1, &"hunter_mark": 4, &"hunter_shooting_discipline": 3,
		&"hunter_covering_shot": 5, &"hunter_easy_prey": 3, &"hunter_total_cover": 4,
	}, {&"dex": 40, &"agi": 35, &"luk": 25}, [
		&"double_shot", &"hunter_freezing_trap", &"hunter_tar_trap", &"hunter_mark", &"hunter_covering_shot",
	])
	_cleanup()
	print("E05 Caçadora H5 builds/menu/save/run: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({}, {}, {&"hunter": {"content_ready": true}})

func _profile(job_level: int, evolved: bool = true) -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Caçadora H5", &"archer")
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = _job_xp(job_level, evolved)
	character.evolution_id = &"hunter" if evolved else &""
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	return profile

func _path(label: String) -> String:
	assert(label in DIRECTORIES)
	var path := directory.path_join(label)
	DirAccess.make_dir_recursive_absolute(path)
	return path

func _facade(label: String, job_level: int = 40, evolved: bool = true, catalog: ProfileCatalog = null) -> ProfileFacade:
	var actual_catalog := catalog if catalog != null else _catalog()
	var store := ProfileStore.new(_path(label), actual_catalog)
	_check(store.commit(_profile(job_level, evolved))["ok"], "%s isolated profile seeded" % label)
	var facade := ProfileFacade.new(store, _reward_resolver())
	_check(facade.open_profile()["ok"], "%s profile opened through facade" % label)
	return facade

func _check_catalog_and_admin_gate() -> void:
	var production := ProfileCatalog.pilot()
	var ready := _catalog()
	var production_hunter := production.evolution_definition(&"hunter")
	var ready_hunter := ready.evolution_definition(&"hunter")
	_check(production.is_valid() and ready.is_valid() and production_hunter != null and ready_hunter != null, "production and test catalogs contain the Hunter identity")
	if production_hunter == null or ready_hunter == null:
		return
	_check(not production_hunter.content_ready and not production.evolution_is_ready(&"hunter", &"archer"), "production Hunter remains unavailable until class closure")
	_check(ready_hunter.content_ready and ready.evolution_is_ready(&"hunter", &"archer") and ready_hunter.exclusive_skill_ids == HunterTuning.SKILL_IDS, "only the explicit fixture override marks the complete Hunter library ready")
	var facade := _facade("blocked", 40, true, production)
	var id: String = facade.current_profile().selected_character_id
	var ordinary := facade.evolution_options(id)
	var admin := facade.playtest_evolution_options(id)
	var hunter_option := _option(ordinary.get("options", []), &"hunter")
	var admin_hunter := _option(admin.get("options", []), &"hunter")
	_check(not hunter_option.is_empty() and not hunter_option["content_ready"] and not hunter_option["can_select"], "ordinary evolution menu exposes the incomplete class as blocked")
	_check(not admin_hunter.is_empty() and not admin_hunter["content_ready"] and not admin_hunter["can_select"], "admin evolution options do not turn incomplete Hunter content into a selectable class")
	var admin_profile := _profile(40, true)
	admin_profile.characters[0].evolution_id = &"sentinel"
	var admin_store := ProfileStore.new(_path("admin"), production)
	_check(admin_store.commit(admin_profile)["ok"], "admin gate fixture seeds an already fixed production branch")
	var admin_facade := ProfileFacade.new(admin_store, _reward_resolver())
	_check(admin_facade.open_profile()["ok"], "admin gate fixture opens")
	var admin_revision := admin_facade.current_profile().revision
	var changed := admin_facade.change_playtest_evolution("admin-cannot-publish", admin_revision, admin_profile.selected_character_id, &"hunter")
	_check(not changed["ok"] and changed["error_code"] == &"content_unavailable" and admin_facade.current_profile().revision == admin_revision, "admin branch switching cannot commit an unavailable class")
	var blocked_revision := facade.current_profile().revision
	var start := facade.start_run("blocked-start", blocked_revision)
	_check(not start["ok"] and start["error_code"] == &"content_unavailable" and facade.current_profile().revision == blocked_revision and facade.current_profile().reward_session == null, "incomplete Hunter cannot start a reward-backed run")
	var training := facade.prepare_playtest_training(id)
	_check(not training["ok"] and training["error_code"] == &"content_unavailable" and facade.current_profile().revision == blocked_revision, "admin training cannot bypass the production readiness gate")

func _check_rank_gates() -> void:
	var catalog := _catalog()
	var hunter_library := catalog.skill_ids_for_identity(&"archer", &"hunter")
	var all_hunter_ids_present := true
	for skill_id: StringName in HunterTuning.SKILL_IDS:
		all_hunter_ids_present = all_hunter_ids_present and skill_id in hunter_library
	_check(all_hunter_ids_present and &"double_shot" in hunter_library and &"sentinel_headshot" not in hunter_library, "Hunter inherits Archer skills and excludes unrelated evolution libraries")
	for index: int in HunterTuning.SKILL_IDS.size():
		var skill_id := HunterTuning.SKILL_IDS[index]
		var metadata := catalog.skill_metadata(skill_id)
		var maximum := HunterTuning.max_rank(skill_id)
		var free_rank := 1 if skill_id == &"hunter_freezing_trap" else 0
		_check(not metadata.is_empty() and metadata["wallet"] == ProfileCatalog.EVOLUTION_WALLET and metadata["required_evolution_id"] == &"hunter", "Hunter skill uses only the evolution wallet: %s" % skill_id)
		if metadata.is_empty():
			continue
		_check(metadata["category"] == (ProfileCatalog.PASSIVE if maximum == 3 else ProfileCatalog.ACTIVE) and metadata["free_rank"] == free_rank and metadata["max_purchased_rank"] == maximum - free_rank, "Hunter category/free-rank/cap matches the contract: %s" % skill_id)
		for rank: int in range(1, maximum + 1):
			var requirement: Dictionary = metadata["rank_requirements"][rank]
			_check(requirement == {"job_level": GATES[index], "skill_ranks": {}}, "every rank of %s has the exact job gate" % skill_id)
			_check(not catalog.check_rank_requirements(skill_id, rank, GATES[index] - 1, {})["ok"] and catalog.check_rank_requirements(skill_id, rank, GATES[index], {})["ok"], "rank %d of %s opens precisely at job %d" % [rank, skill_id, GATES[index]])
		_check(not catalog.skill_is_allowed(skill_id, &"mage", &"hunter") and not catalog.skill_is_allowed(skill_id, &"archer", &"sentinel"), "Hunter-only progression rejects other origins/evolutions: %s" % skill_id)
		var definition := ClassCatalog.skill_definition(skill_id)
		_check(definition != null and definition.ranks.size() == maximum and definition.is_rank_catalog_valid(), "runtime rank catalog agrees for %s" % skill_id)

func _check_menu_gate(job_level: int, label: String) -> void:
	var facade := _facade(label, job_level)
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	_check(menu.evolution_state_label.text.contains("Caçadora") and menu.evolution_state_label.text.contains("Arqueiro"), "job%d menu identifies Hunter and its Archer origin" % job_level)
	for index: int in HunterTuning.SKILL_IDS.size():
		var skill_id := HunterTuning.SKILL_IDS[index]
		var visible := job_level >= GATES[index]
		var label_node := menu.progression_skill_tree.get_node_or_null("ProgressionSkill_%s" % skill_id) as Label
		var button := menu.progression_skill_tree.get_node_or_null("Learn_%s" % skill_id) as Button
		_check((label_node != null and button != null) == visible, "job%d menu reveals %s at its exact gate" % [job_level, skill_id])
		if label_node != null and button != null:
			var expected_rank := 1 if skill_id == &"hunter_freezing_trap" else 0
			_check(label_node.text.contains("Rank %d/%d" % [expected_rank, HunterTuning.max_rank(skill_id)]), "job%d menu shows current and maximum rank for %s" % [job_level, skill_id])
			_check(label_node.tooltip_text.contains("Próximo rank: %d · Job %d" % [expected_rank + 1, GATES[index]]), "job%d tooltip names the next rank and gate for %s" % [job_level, skill_id])
			if skill_id == &"hunter_freezing_trap":
				_check(label_node.tooltip_text.contains("Atual R1:") and label_node.tooltip_text.contains("Próximo R2:") and label_node.tooltip_text.contains("raio 52"), "Hunter tooltip shows current and next rank effect details")
			if skill_id == &"hunter_total_cover":
				_check(label_node.tooltip_text.contains("3s") and label_node.tooltip_text.contains("18s") and label_node.tooltip_text.contains("Abrigo"), "Cobertura Total tooltip states the shared Abrigo budget and 18-second base cooldown")
	_check(menu.action_editor.slot_buttons.size() == 24 and menu.active_selectors.is_empty() and menu.passive_selectors.is_empty() and menu.automatic_passives_label.text.contains("automáticas"), "Hunter menu keeps 24 shortcuts and treats learned passives as automatic")
	menu.queue_free()
	await process_frame

func _check_shelter_tooltips() -> void:
	for kind: String in ["hunter", "archer", "sentinel"]:
		var catalog := _catalog() if kind == "hunter" else ProfileCatalog.pilot()
		var evolved := kind != "archer"
		var job_level := 40 if evolved else 20
		var character_profile := _profile(job_level, false)
		if kind == "hunter":
			character_profile.characters[0].evolution_id = &"hunter"
		elif kind == "sentinel":
			character_profile.characters[0].evolution_id = &"sentinel"
		var label := "tooltip_%s" % kind
		var store := ProfileStore.new(_path(label), catalog)
		_check(store.commit(character_profile)["ok"], "%s foliage tooltip fixture is a legal Archer-origin profile" % kind)
		var facade := ProfileFacade.new(store, _reward_resolver())
		var opened := facade.open_profile()
		var id: String = character_profile.selected_character_id
		var learned := facade.learn_skill("%s-foliage" % kind, facade.current_profile().revision, id, &"foliage_shelter") if opened["ok"] else {"ok": false}
		_check(learned["ok"] and facade.progression_summary(id)["effective_skill_ranks"].get(&"foliage_shelter", 0) == 1, "%s fixture legally learns Abrigo de Folhagem R1" % kind)
		if not learned["ok"]:
			continue
		var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
		menu.set_profile_facade(facade)
		root.add_child(menu)
		await process_frame
		var shelter_label := menu.progression_skill_tree.get_node_or_null("ProgressionSkill_foliage_shelter") as Label
		var shared_text := "recarga base de 18s"
		_check(shelter_label != null and shelter_label.tooltip_text.contains(shared_text) == (kind == "hunter"), "%s Abrigo tooltip states the shared 18s Hunter cooldown only for Hunter identity" % kind)
		menu.queue_free()
		await process_frame

func _check_build(label: String, evolution_purchases: Dictionary, allocations: Dictionary, legacy_active: Array[Variant]) -> void:
	var catalog := _catalog()
	var path := _path(label)
	var initial := _profile(20, false)
	_check(ProfileStore.new(path, catalog).commit(initial)["ok"], "%s legal unevolved base profile committed" % label)
	var facade := ProfileFacade.new(ProfileStore.new(path, catalog), _reward_resolver())
	_check(facade.open_profile()["ok"], "%s initial facade opens" % label)
	var id: String = facade.current_profile().selected_character_id
	var evolution := facade.change_evolution("%s-evolve" % label, facade.current_profile().revision, id, &"hunter")
	_check(evolution["ok"] and facade.current_profile().character_by_id(id).base_class_id == &"archer", "%s chooses Hunter through the ordinary facade while preserving Archer origin" % label)
	if not evolution["ok"]:
		return
	var maxed := facade.grant_playtest_progression("%s-max-levels" % label, facade.current_profile().revision, id, &"max_levels")
	_check(maxed["ok"] and facade.progression_summary(id)["base_level"] == 30 and facade.progression_summary(id)["job_level"] == 40, "%s reaches base30/job40 through the isolated progression facade" % label)
	var purchases: Dictionary = BASE_PURCHASES.duplicate(true)
	purchases.merge(evolution_purchases)
	for skill_id: StringName in purchases:
		for rank_index: int in int(purchases[skill_id]):
			var bought := facade.learn_skill("%s-%s-%d" % [label, skill_id, rank_index], facade.current_profile().revision, id, skill_id)
			_check(bought["ok"] and bought.get("rank", -1) == rank_index + (1 if skill_id == &"hunter_freezing_trap" else 0) + 1, "%s buys %s rank %d through the profile facade" % [label, skill_id, rank_index + 1])
			if not bought["ok"]:
				return
	var allocated := facade.allocate_attributes("%s-attributes" % label, facade.current_profile().revision, id, allocations)
	_check(allocated["ok"], "%s spends only legal attribute increments using StatThresholds" % label)
	var summary := facade.progression_summary(id)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 20 and summary["evolution_skill_points_available"] == 0, "%s respects separate 19 base / 20 evolution point wallets" % label)
	_check(ProgressionRules.attribute_points_spent(facade.current_profile().character_by_id(id).attribute_allocations, &"archer") <= ProgressionRules.attribute_points_granted(ProgressionRules.MAX_BASE_XP), "%s attribute increments remain within the canonical wallet" % label)
	var overdraw_skill := facade.learn_skill("%s-skill-overdraw" % label, facade.current_profile().revision, id, &"hunter_total_cover")
	_check(not overdraw_skill["ok"] and overdraw_skill["error_code"] == &"insufficient_points", "%s cannot exceed its 20 evolution points" % label)
	var passive_slots: Array[Variant] = [&"archer_precision", &"hunter_shooting_discipline"]
	var saved_preset := facade.update_preset("%s-legacy-preset" % label, facade.current_profile().revision, id, 0, legacy_active, passive_slots, EQUIPPED)
	_check(saved_preset["ok"], "%s saves a legal historical five/two preset without limiting its learned library" % label)
	if not saved_preset["ok"]:
		return
	var action_slots := ActionBarLayout.empty()
	for index: int in legacy_active.size():
		action_slots[index] = legacy_active[index]
	# A sixth, legally learned active proves that old presets are not the library limit.
	var extra_active := &"hunter_mark" if label == "preparadora" else &"arrow_rain"
	if extra_active not in legacy_active:
		action_slots[5] = extra_active
	var action_saved := facade.update_action_slots("%s-action-bar" % label, facade.current_profile().revision, id, action_slots)
	_check(action_saved["ok"] and facade.current_profile().character_by_id(id).action_slots.size() == 24, "%s saves the independent 24-slot action layout" % label)
	var before_reopen := facade.current_profile().character_by_id(id)
	var reload_facade := ProfileFacade.new(ProfileStore.new(path, catalog), _reward_resolver())
	var reopened := reload_facade.open_profile()
	_check(reopened["ok"], "%s durable save reopens through the facade" % label)
	if not reopened["ok"]:
		return
	var durable: CharacterState = reopened["profile"].character_by_id(id)
	_check(durable.base_class_id == &"archer" and durable.evolution_id == &"hunter" and durable.purchased_skill_ranks == purchases and durable.attribute_allocations == before_reopen.attribute_allocations and durable.presets[0]["active_slots"] == legacy_active and durable.presets[0]["passive_slots"] == passive_slots and durable.action_slots == action_slots, "%s reload retains origin, ranks, stats, legacy preset and 24 shortcuts" % label)
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(reload_facade)
	root.add_child(menu)
	await process_frame
	_check(menu.action_editor.slot_buttons.size() == 24 and menu.automatic_passives_label.text.contains("automáticas"), "%s reloaded menu presents the 24 slots and automatic passives" % label)
	_check(menu._save_build()["ok"], "%s saves its legacy equipment preset from the real menu" % label)
	var menu_bar := ActionBarLayout.assign(action_slots, extra_active, 23)
	menu._save_action_slots(menu_bar)
	_check(reload_facade.current_profile().character_by_id(id).action_slots == menu_bar, "%s menu action editor persists a shortcut at slot24" % label)
	var saved_passives: Array[StringName] = []
	for skill_id: StringName in catalog.skill_ids_for_identity(&"archer", &"hunter"):
		if int(summary["effective_skill_ranks"].get(skill_id, 0)) > 0 and catalog.skill_metadata(skill_id)["category"] == ProfileCatalog.PASSIVE:
			saved_passives.append(skill_id)
	_check(saved_passives.size() == 4 and saved_passives.size() > CharacterState.PASSIVE_SLOT_COUNT, "%s learns more passives than the two historical selection slots" % label)
	_check(menu.automatic_passives_label.text.contains("Disciplina de Tiro") and menu.automatic_passives_label.text.contains("Presa Fácil"), "%s menu lists both learned Hunter passives as automatic" % label)
	_check_passive_tooltip(menu, &"hunter_shooting_discipline", int(purchases[&"hunter_shooting_discipline"]))
	_check_passive_tooltip(menu, &"hunter_easy_prey", int(purchases[&"hunter_easy_prey"]))
	var run := reload_facade.start_run("%s-start" % label, reload_facade.current_profile().revision)
	_check(run["ok"] and run["run_state"].class_id == &"archer" and run["run_state"].build_snapshot.evolution_id == &"hunter", "%s starts a normal run from the saved build" % label)
	if not run["ok"]:
		menu.queue_free()
		await process_frame
		return
	var snapshot: BuildSnapshot = run["run_state"].build_snapshot
	var expected_active := snapshot.learned_skill_ids(ProfileCatalog.ACTIVE)
	_check(snapshot.skill_ranks == summary["effective_skill_ranks"] and snapshot.action_slots == menu_bar and snapshot.active_slots == legacy_active, "%s run snapshot receives all saved ranks and both independent slot layouts" % label)
	_check(expected_active.size() > CharacterState.ACTIVE_SLOT_COUNT and snapshot.learned_skill_ids(ProfileCatalog.PASSIVE) == saved_passives, "%s run exposes all learned actives and every learned passive, independent of legacy slots" % label)
	var run_revision := reload_facade.current_profile().revision
	_check(not reload_facade.learn_skill("%s-run-purchase" % label, run_revision, id, &"hunter_mark")["ok"] and not reload_facade.update_preset("%s-run-preset" % label, run_revision, id, 0, legacy_active, passive_slots, EQUIPPED)["ok"] and reload_facade.current_profile().revision == run_revision, "%s build mutations stay locked during the live run" % label)
	var reward := reload_facade.grant_reward("%s-reward" % label, run_revision, run["run_id"], 1, &"encounter_one")
	_check(reward["ok"] and reward["profile"].reward_session["last_committed_seq"] == 1, "%s reward persists through the run facade before returning to menu" % label)
	if reward["ok"]:
		var ended := reload_facade.end_run("%s-end" % label, reload_facade.current_profile().revision, run["run_id"], &"completed")
		_check(ended["ok"] and ended["profile"].reward_session == null and ended["profile"].lifetime_stats[&"runs_completed"] == 1, "%s closes the completed run and records return state" % label)
	menu.queue_free()
	await process_frame
	var returned := ProfileFacade.new(ProfileStore.new(path, catalog), _reward_resolver())
	var returned_open := returned.open_profile()
	var returned_menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	returned_menu.set_profile_facade(returned)
	root.add_child(returned_menu)
	await process_frame
	var returned_character: CharacterState = returned.current_profile().character_by_id(id)
	_check(returned_open["ok"] and returned.current_profile().reward_session == null and returned_menu.evolution_state_label.text.contains("Caçadora"), "%s returns to the real menu with no active session" % label)
	_check(returned_character.evolution_id == &"hunter" and returned_character.purchased_skill_ranks == purchases and returned_character.action_slots == menu_bar, "%s return keeps the saved identity/ranks/24 shortcuts after reward and reload")
	_check(returned.current_profile().lifetime_stats[&"runs_completed"] == 1 and returned.current_profile().lifetime_stats[&"kills"] == 2, "%s run reward and completion survive the menu return")
	returned_menu.queue_free()
	await process_frame

func _option(options: Array, evolution_id: StringName) -> Dictionary:
	for option: Dictionary in options:
		if option["evolution_id"] == evolution_id:
			return option
	return {}

func _check_passive_tooltip(menu: CharacterMenu, skill_id: StringName, rank: int) -> void:
	var label := menu.progression_skill_tree.get_node_or_null("ProgressionSkill_%s" % skill_id) as Label
	var maximum := HunterTuning.max_rank(skill_id)
	var current := ClassCatalog.hunter_description(skill_id, rank)
	var label_ok := label != null and label.tooltip_text.contains("Atual R%d: %s" % [rank, current])
	if rank < maximum:
		var next := ClassCatalog.hunter_description(skill_id, rank + 1)
		label_ok = label_ok and label.tooltip_text.contains("Próximo R%d: %s" % [rank + 1, next])
	else:
		label_ok = label_ok and label.tooltip_text.contains("Rank máximo atingido.")
	if skill_id == &"hunter_shooting_discipline":
		label_ok = label_ok and current.contains("%d%%" % ([5, 10, 15][rank - 1]))
	else:
		label_ok = label_ok and current.contains("%d%%" % ([8, 12, 16][rank - 1]))
	_check(label_ok, "learned passive tooltip shows exact current/next scaling: %s R%d" % [skill_id, rank])

func _reward_resolver() -> ProfileRewardResolver:
	return ProfileRewardResolver.new({
		&"encounter_one": {"base_xp": 100, "job_xp": 80, "stat_increments": {&"kills": 2}},
	})

func _job_xp(level: int, evolved: bool) -> int:
	for xp: int in range(ProgressionRules.MAX_JOB_XP + 1):
		if ProgressionRules.job_level_for_xp(xp, evolved) == level:
			return xp
	return ProgressionRules.MAX_JOB_XP

func _cleanup() -> void:
	var expected := ProjectSettings.globalize_path(ROOT_DIRECTORY)
	assert(directory.is_empty() or directory == expected)
	for label: String in DIRECTORIES:
		var path := expected.path_join(label)
		if not DirAccess.dir_exists_absolute(path):
			continue
		var dir := DirAccess.open(path)
		if dir == null:
			continue
		for filename: String in dir.get_files():
			DirAccess.remove_absolute(path.path_join(filename))
		DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(expected):
		DirAccess.remove_absolute(expected)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
