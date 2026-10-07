extends SceneTree
## G6 progression fixtures: only isolated verification saves, never user://profile.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174206"
const IDS: Array[StringName] = [
	&"geometer_trace", &"geometer_incidence", &"geometer_translation",
	&"geometer_triangulation", &"geometer_vector_memory", &"geometer_collapse", &"geometer_rewrite",
]
const GATES: Array[int] = [20, 23, 25, 28, 31, 34, 37]
const CAPS: Array[int] = [5, 3, 5, 5, 3, 5, 5]
const DIRECTORIES: Array[String] = ["production", "walls", "triangles", "menu22", "menu23", "menu40"]

var checks := 0
var failures := 0
var root_directory: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e05_geometer_builds")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_catalog()
	_check_progression()
	_check_production_gate()
	await _check_build("walls", {
		&"fireball": 5, &"ice_spear": 5, &"teleport": 5, &"mage_mana_regeneration": 3, &"fire_spear": 1,
		&"geometer_trace": 4, &"geometer_incidence": 3, &"geometer_translation": 5,
		&"geometer_vector_memory": 3, &"geometer_collapse": 5,
	}, [&"geometer_trace", &"geometer_translation", &"geometer_collapse", &"fireball", &"ice_spear"], [&"geometer_incidence", &"geometer_vector_memory"])
	await _check_build("triangles", {
		&"lightning": 5, &"fireball": 5, &"fire_spear": 5, &"mage_mana_regeneration": 3, &"teleport": 1,
		&"geometer_trace": 2, &"geometer_incidence": 3, &"geometer_triangulation": 5,
		&"geometer_vector_memory": 3, &"geometer_collapse": 2, &"geometer_rewrite": 5,
	}, [&"geometer_trace", &"geometer_triangulation", &"geometer_rewrite", &"geometer_collapse", &"lightning"], [&"geometer_incidence", &"geometer_vector_memory"])
	await _check_menu(22)
	await _check_menu(23)
	await _check_menu(40)
	_cleanup()
	print("E05 Geômetra G6 builds/progressão: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _ready_catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot()

func _check_catalog() -> void:
	var production := ProfileCatalog.pilot()
	var ready := _ready_catalog()
	_check(production.is_valid() and ready.is_valid(), "production and ready-only Geometer catalog fixtures validate")
	var definition := production.evolution_definition(&"mg_ar")
	_check(definition != null and definition.origin_class_id == &"mage" and definition.affinity_class_id == &"archer", "Geometer preserves mg_ar Mage origin and directional Archer affinity")
	if definition == null:
		return
	_check(definition.content_ready and production.evolution_is_ready(&"mg_ar", &"mage"), "G7 candidate enables exactly the completed Geometer kit")
	_check(definition.entry_skill_id == &"geometer_trace" and definition.exclusive_skill_ids == IDS, "one free entry and exactly seven ordered exclusive skills")
	_check(ready.evolution_is_ready(&"mg_ar", &"mage") and ready.evolution_definition(&"mg_ar").exclusive_skill_ids == IDS, "content-ready-only override retains the real library")
	var library := ready.skill_ids_for_identity(&"mage", &"mg_ar")
	_check(&"fireball" in library and &"lightning" in library and &"mage_mana_regeneration" in library, "Mage skills are inherited")
	for foreign: StringName in [&"double_shot", &"piercing_arrow", &"snare_trap", &"archer_precision", &"slash", &"elementalist_flame_burst", &"spiritualist_echo_curse"]:
		_check(foreign not in library and not ready.skill_is_allowed(foreign, &"mage", &"mg_ar"), "no foreign affinity or sibling library: %s" % foreign)
	for index: int in IDS.size():
		var skill_id := IDS[index]
		var metadata := ready.skill_metadata(skill_id)
		_check(not metadata.is_empty(), "registered progression metadata: %s" % skill_id)
		if metadata.is_empty():
			continue
		var passive := index in [1, 4]
		var free_rank := 1 if index == 0 else 0
		_check(metadata["category"] == (ProfileCatalog.PASSIVE if passive else ProfileCatalog.ACTIVE), "correct slot category: %s" % skill_id)
		_check(metadata["wallet"] == ProfileCatalog.EVOLUTION_WALLET and metadata["required_evolution_id"] == &"mg_ar" and metadata["allowed_base_classes"] == [&"mage"], "exclusive Mage evolution wallet: %s" % skill_id)
		_check(int(metadata["free_rank"]) == free_rank and int(metadata["max_purchased_rank"]) == CAPS[index] - free_rank, "free/purchased rank cap: %s" % skill_id)
		for rank: int in range(1, CAPS[index] + 1):
			var requirement: Dictionary = metadata["rank_requirements"][rank]
			_check(requirement == {"job_level": GATES[index], "skill_ranks": {}}, "uniform exact job gate: %s R%d" % [skill_id, rank])
			_check(not ready.check_rank_requirements(skill_id, rank, GATES[index] - 1, {})["ok"] and ready.check_rank_requirements(skill_id, rank, GATES[index], {})["ok"], "job immediately below/at gate: %s R%d" % [skill_id, rank])
		_check(not ready.skill_is_allowed(skill_id, &"archer", &"ar_mg") and not ready.skill_is_allowed(skill_id, &"mage", &"elementalist"), "exclusive identity rejects other branch: %s" % skill_id)
		var runtime := ClassCatalog.skill_definition(skill_id)
		_check(runtime != null and runtime.ranks.size() == CAPS[index] and runtime.is_rank_catalog_valid(), "runtime catalog rank cap agrees: %s" % skill_id)
	var copied := ready.skill_metadata(&"geometer_trace")
	if not copied.is_empty():
		copied["rank_requirements"][1]["job_level"] = 40
		_check(ready.skill_metadata(&"geometer_trace")["rank_requirements"][1]["job_level"] == 20, "progression metadata cannot mutate the sealed catalog")
	var replaced := ProfileCatalog.pilot({}, {
		&"fixture_geometer_entry": {"allowed_base_classes": [&"mage"], "category": ProfileCatalog.ACTIVE, "wallet": ProfileCatalog.EVOLUTION_WALLET, "free_rank": 1, "max_purchased_rank": 4, "required_evolution_id": &"mg_ar", "rank_requirements": {1: {"job_level": 20, "skill_ranks": {}}}},
	}, {&"mg_ar": {"entry_skill_id": &"fixture_geometer_entry", "exclusive_skill_ids": [&"fixture_geometer_entry"], "content_ready": true}})
	_check(replaced.is_valid() and replaced.skill_metadata(&"geometer_trace").is_empty() and replaced.evolution_definition(&"mg_ar").exclusive_skill_ids == [&"fixture_geometer_entry"], "explicit exclusive-library override replaces rather than mixes fixture/runtime skills")

func _check_progression() -> void:
	var catalog := _ready_catalog()
	var character := _character(40)
	var summary := CharacterProgression.summary(character, catalog)
	_check(summary["base_skill_points_available"] == 19 and summary["evolution_skill_points_available"] == 20 and summary["effective_skill_ranks"] == {&"geometer_trace": 1}, "job40 grants separate 19/20 wallets and exactly one free entry")
	for index: int in IDS.size():
		var skill_id := IDS[index]
		var metadata := catalog.skill_metadata(skill_id)
		if metadata.is_empty():
			continue
		var capped := _character(40)
		for purchase: int in int(metadata["max_purchased_rank"]):
			var bought := CharacterProgression.learn_skill(capped, catalog, skill_id)
			_check(bought["ok"] and bought.get("rank", 0) == int(metadata["free_rank"]) + purchase + 1, "purchase sequential rank: %s #%d" % [skill_id, purchase + 1])
		var before := capped.copy_state()
		var rejected := CharacterProgression.learn_skill(capped, catalog, skill_id)
		_check(not rejected["ok"] and rejected["error_code"] == &"rank_cap_reached" and capped.purchased_skill_ranks == before.purchased_skill_ranks, "cap rejection is atomic: %s" % skill_id)
		if index == 0:
			continue
		var early := _character(GATES[index] - 1)
		var early_result := CharacterProgression.learn_skill(early, catalog, skill_id)
		_check(not early_result["ok"] and early_result["error_code"] == &"requirements_unmet" and early.purchased_skill_ranks.is_empty(), "gate blocks purchases without mutation: %s" % skill_id)
		var eligible := _character(GATES[index])
		_check(CharacterProgression.learn_skill(eligible, catalog, skill_id)["ok"], "purchase allowed exactly at job gate: %s" % skill_id)
	var entry := _character(20)
	var entry_result := CharacterProgression.learn_skill(entry, catalog, &"geometer_trace")
	_check(not entry_result["ok"] and entry_result["error_code"] == &"insufficient_points" and CharacterProgression.summary(entry, catalog)["effective_skill_ranks"] == {&"geometer_trace": 1}, "job20 free Trace does not spend unavailable evolution points")
	var novice := _character(40)
	novice.evolution_id = &""
	novice.job_xp_total = ProgressionRules.UNEVOLVED_MAX_JOB_XP
	_check(not CharacterProgression.learn_skill(novice, catalog, &"geometer_translation")["ok"] and not CharacterProgression.summary(novice, catalog)["effective_skill_ranks"].has(&"geometer_trace"), "base Mage neither buys Geometer skills nor receives its free entry")

func _check_production_gate() -> void:
	# Preserve G6 gate invariant using an explicitly blocked catalog fixture.
	var catalog := ProfileCatalog.pilot({}, {}, {&"mg_ar": {"content_ready": false}})
	var profile := _profile(40)
	var directory := _directory("production")
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "production-blocked Geometer fixture can be safely stored")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	_check(opened["ok"], "blocked identity is preserved on reload")
	if not opened["ok"]:
		return
	var before := facade.current_profile().revision
	var started := facade.start_run("g6-prod-block", before)
	_check(not started["ok"] and started["error_code"] == &"content_unavailable" and facade.current_profile().revision == before and facade.current_profile().reward_session == null, "production gate blocks run before any revision or reward session")

func _check_build(label: String, purchases: Dictionary, active: Array[Variant], passive: Array[Variant]) -> void:
	var directory := _directory(label)
	var catalog := _ready_catalog()
	var profile := _profile(40)
	var character_id: String = profile.selected_character_id
	_check(ProfileStore.new(directory, catalog).commit(profile)["ok"], "%s fixture committed" % label)
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	_check(facade.open_profile()["ok"], "%s fixture opens" % label)
	for skill_id: StringName in purchases:
		for index: int in int(purchases[skill_id]):
			var learned := facade.learn_skill("%s-%s-%d" % [label, skill_id, index], facade.current_profile().revision, character_id, skill_id)
			_check(learned["ok"], "%s legally buys %s #%d" % [label, skill_id, index + 1])
			if not learned["ok"]:
				return
	var summary := facade.progression_summary(character_id)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 20 and summary["base_skill_points_available"] == 0 and summary["evolution_skill_points_available"] == 0, "%s independently exhausts 19 base and 20 evolution points" % label)
	var exhausted := facade.learn_skill("%s-empty-wallet" % label, facade.current_profile().revision, character_id, &"geometer_rewrite" if label == "walls" else &"geometer_translation")
	_check(not exhausted["ok"] and exhausted["error_code"] == &"insufficient_points", "%s cannot overdraw evolution wallet" % label)
	var equipped: Dictionary[StringName, Variant] = {&"weapon": null, &"armor": null, &"accessory": null}
	var preset := facade.update_preset("%s-equip" % label, facade.current_profile().revision, character_id, 0, active, passive, equipped)
	_check(preset["ok"], "%s preserves valid historical five/two preset arrays without limiting learned skills" % label)
	if not preset["ok"]:
		return
	var revision := facade.current_profile().revision
	var illegal_active: Array[Variant] = active.duplicate()
	illegal_active[4] = &"double_shot"
	_check(not facade.update_preset("%s-foreign" % label, revision, character_id, 0, illegal_active, passive, equipped)["ok"] and facade.current_profile().revision == revision, "%s foreign active is rejected atomically" % label)
	var illegal_passive: Array[Variant] = passive.duplicate()
	illegal_passive[0] = &"geometer_trace"
	_check(not facade.update_preset("%s-wrong-category" % label, revision, character_id, 0, active, illegal_passive, equipped)["ok"] and facade.current_profile().revision == revision, "%s active in passive slot is rejected atomically" % label)
	_check(not facade.update_preset("%s-six-legacy" % label, revision, character_id, 0, active + [&"teleport"], passive, equipped)["ok"], "%s legacy preset format stays five entries; this is not a learned-active limit" % label)
	var action_slots := ActionBarLayout.from_legacy(active + [&"teleport"])
	var bar := facade.update_action_slots("%s-six-shortcuts" % label, revision, character_id, action_slots)
	_check(bar["ok"] and facade.current_profile().character_by_id(character_id).action_slots.size() == 24 and facade.current_profile().character_by_id(character_id).action_slots[5] == &"teleport", "%s sixth learned active is legal in the 24-slot action bar" % label)
	var illegal_bar: Array[Variant] = action_slots.duplicate()
	illegal_bar[23] = &"double_shot"
	revision = facade.current_profile().revision
	_check(not facade.update_action_slots("%s-foreign-bar" % label, revision, character_id, illegal_bar)["ok"] and facade.current_profile().revision == revision, "%s foreign active shortcut is rejected without changing save" % label)
	illegal_bar[23] = &"mage_mana_regeneration"
	_check(not facade.update_action_slots("%s-passive-bar" % label, revision, character_id, illegal_bar)["ok"] and facade.current_profile().revision == revision, "%s passive is automatic, never an active-bar entry" % label)
	illegal_bar[23] = &"geometer_rewrite" if label == "walls" else &"geometer_translation"
	_check(not facade.update_action_slots("%s-unlearned-bar" % label, revision, character_id, illegal_bar)["ok"] and facade.current_profile().revision == revision, "%s legal identity alone does not let a shortcut learn a missing active" % label)
	var encoded := ProfileCodec.encode(facade.current_profile(), catalog)
	_check(encoded["ok"], "%s profile codec encodes all new IDs" % label)
	if not encoded["ok"]:
		return
	var decoded := ProfileCodec.decode(encoded["text"], catalog)
	_check(decoded["ok"] and not decoded.get("migrated", false), "%s current save round-trips without migration" % label)
	var production_decoded := ProfileCodec.decode(encoded["text"])
	_check(production_decoded["ok"] and production_decoded["profile"].character_by_id(character_id).purchased_skill_ranks == purchases, "%s completed production catalog preserves G6 saves" % label)
	var corrupt: Dictionary = encoded["data"].duplicate(true)
	corrupt["characters"][0]["purchased_skill_ranks"]["geometer_trace"] = 5
	_check(not ProfileCodec.decode(JSON.stringify(corrupt), catalog)["ok"], "%s codec refuses entry ranks over free-plus-four cap" % label)
	corrupt = encoded["data"].duplicate(true)
	corrupt["characters"][0]["base_class_id"] = "archer"
	_check(not ProfileCodec.decode(JSON.stringify(corrupt), catalog)["ok"], "%s codec refuses affinity replacing persistent origin" % label)
	corrupt = encoded["data"].duplicate(true)
	corrupt["characters"][0]["purchased_skill_ranks"]["geometer_rewrite" if label == "walls" else "geometer_translation"] = 1
	_check(not ProfileCodec.decode(JSON.stringify(corrupt), catalog)["ok"], "%s codec refuses overspent evolution wallet" % label)
	if decoded["ok"]:
		var round_trip: CharacterState = decoded["profile"].character_by_id(character_id)
		_check(round_trip.purchased_skill_ranks == purchases and round_trip.evolution_id == &"mg_ar" and round_trip.base_class_id == &"mage" and round_trip.presets[0]["active_slots"] == active and round_trip.presets[0]["passive_slots"] == passive and round_trip.action_slots == action_slots, "%s codec retains identity, paid ranks, legacy preset and independent24-slot layout exactly" % label)
		_check(encoded["data"]["schema_version"] == ProfileState.SCHEMA_VERSION and encoded["data"]["catalog_version"] == ProfileState.CATALOG_VERSION and not encoded["data"]["characters"][0].has("geometer_construction") and not encoded["data"]["characters"][0].has("cooldowns"), "%s stores current schema metadata, never construction/run state" % label)
	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := reloaded.open_profile()
	_check(opened["ok"], "%s durable reload opens" % label)
	if not opened["ok"]:
		return
	var durable: CharacterState = opened["profile"].character_by_id(character_id)
	_check(durable.purchased_skill_ranks == purchases and durable.presets[0]["active_slots"] == active and durable.presets[0]["passive_slots"] == passive and durable.action_slots == action_slots, "%s durable reload preserves exact build and independent action layout" % label)
	var preview := reloaded.build_preview(character_id)
	_check(preview["ok"] and preview["snapshot"].active_slots == active and preview["snapshot"].passive_slots == passive and preview["snapshot"].action_slots == action_slots and preview["snapshot"].skill_ranks[&"geometer_trace"] == int(purchases[&"geometer_trace"]) + 1, "%s preview copies ranks including free entry, action layout and legacy data" % label)
	var started := reloaded.start_run("%s-run" % label, reloaded.current_profile().revision)
	_check(started["ok"] and started["run_state"].build_snapshot.evolution_id == &"mg_ar", "%s isolated run starts from reloaded legal build" % label)
	if not started["ok"]:
		return
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 700), [], 20.0)
	var player := PlayerActor.new()
	player.configure(navigation, started["run_state"])
	root.add_child(player)
	player.set_process(false)
	var learned: Array[StringName] = []
	for id: StringName in catalog.skill_ids_for_identity(&"mage", &"mg_ar"):
		if int(summary["effective_skill_ranks"].get(id, 0)) > 0 and catalog.skill_metadata(id)["category"] == ProfileCatalog.ACTIVE:
			learned.append(id)
	_check(player.available_skill_ids() == learned and learned.size() == (7 if label == "walls" else 8) and player.skill_rank(&"geometer_trace") == int(purchases[&"geometer_trace"]) + 1, "%s runtime exposes every learned legal active, including skills absent from shortcut bar" % label)
	_check(player.run_state.build_snapshot.learned_skill_ids(ProfileCatalog.PASSIVE).size() == 3 and player.run_state.build_snapshot.has_passive(&"mage_mana_regeneration") and player.run_state.build_snapshot.has_passive(&"geometer_incidence") and player.run_state.build_snapshot.has_passive(&"geometer_vector_memory"), "%s base plus two evolution passives all operate automatically despite legacy selection of two" % label)
	var copy: BuildSnapshot = started["run_state"].build_snapshot.copy_snapshot()
	copy.skill_ranks[&"geometer_trace"] = 99
	copy.active_slots[0] = null
	copy.action_slots[0] = null
	_check(player.skill_rank(&"geometer_trace") == int(purchases[&"geometer_trace"]) + 1 and player.run_state.build_snapshot.action_slots == action_slots and reloaded.current_profile().character_by_id(character_id).presets[0]["active_slots"] == active and reloaded.current_profile().character_by_id(character_id).action_slots == action_slots, "%s disposable snapshot cannot mutate live actor, durable preset or action layout" % label)
	player.queue_free()
	await process_frame
	var respec_character := durable.copy_state()
	var refund := CharacterProgression.respec_skills(respec_character, catalog)
	_check(refund["ok"] and refund["base_refund"] == 19 and refund["evolution_refund"] == 20 and CharacterProgression.summary(respec_character, catalog)["effective_skill_ranks"] == {&"geometer_trace": 1}, "%s respec refunds both wallets and preserves only free Trace" % label)
	_check(respec_character.presets[0]["active_slots"] == [&"geometer_trace", null, null, null, null] and respec_character.presets[0]["passive_slots"] == [null, null] and respec_character.action_slots == ActionBarLayout.from_legacy([&"geometer_trace"]), "%s respec prunes paid legacy references and action shortcuts without erasing free entry" % label)

func _check_menu(job_level: int) -> void:
	var directory := _directory("menu%d" % job_level)
	var catalog := _ready_catalog()
	_check(ProfileStore.new(directory, catalog).commit(_profile(job_level))["ok"], "job%d menu fixture is isolated" % job_level)
	var scene := load("res://scenes/character_menu.tscn") as PackedScene
	var menu := scene.instantiate() as CharacterMenu
	menu.set_profile_facade(ProfileFacade.new(ProfileStore.new(directory, catalog)))
	root.add_child(menu)
	await process_frame
	_check(menu.evolution_state_label.text.contains("Geômetra") and menu.evolution_state_label.text.contains("Mago"), "job%d menu presents the correct origin/evolution" % job_level)
	for index: int in IDS.size():
		var skill_id := IDS[index]
		var label := menu.progression_skill_tree.get_node_or_null("ProgressionSkill_%s" % skill_id) as Label
		var button := menu.progression_skill_tree.get_node_or_null("Learn_%s" % skill_id) as Button
		var revealed := job_level >= GATES[index]
		_check((label != null and button != null) == revealed, "job%d reveals %s exactly when its gate opens" % [job_level, skill_id])
		if label != null and button != null:
			_check(label.text.contains("Rank %d/%d" % [1 if index == 0 else 0, CAPS[index]]) and not button.disabled, "job%d offers the legal next rank of %s" % [job_level, skill_id])
	var character_id: String = menu.facade.current_profile().selected_character_id
	var foreign_label := menu.progression_skill_tree.get_node_or_null("ProgressionSkill_double_shot")
	_check(foreign_label == null and menu.action_editor.slot_buttons.size() == 24 and menu.active_selectors.is_empty() and menu.passive_selectors.is_empty() and menu.automatic_passives_label.text.contains("automáticas"), "job%d menu has24 action slots and automatic passives, with no old selectors or Archer branch" % job_level)
	if job_level == 23:
		var learned := menu._learn_skill(&"geometer_incidence")
		var incidence := menu.progression_skill_tree.get_node_or_null("ProgressionSkill_geometer_incidence") as Label
		_check(learned["ok"] and incidence != null and incidence.text.contains("Rank 1/3") and menu.facade.progression_summary(character_id)["evolution_skill_points_available"] == 2, "job23 menu buys Incidence and refreshes the independent evolution wallet")
	menu.queue_free()
	await process_frame

func _character(job_level: int) -> CharacterState:
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Geômetra G6", &"mage")
	character.evolution_id = &"mg_ar"
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = _job_xp(job_level)
	return character

func _profile(job_level: int) -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(_character(job_level))
	profile.selected_character_id = profile.characters[0].character_id
	profile.next_character_counter = 2
	return profile

func _job_xp(level: int) -> int:
	for value: int in range(ProgressionRules.MAX_JOB_XP + 1):
		if ProgressionRules.job_level_for_xp(value, true) == level:
			return value
	return ProgressionRules.MAX_JOB_XP

func _directory(label: String) -> String:
	assert(label in DIRECTORIES)
	var path := root_directory.path_join(label)
	DirAccess.make_dir_recursive_absolute(path)
	return path

func _cleanup() -> void:
	# Flat, explicitly named fixture directories. Never recurse through arbitrary saves.
	var expected := ProjectSettings.globalize_path("res://.godot/verification/e05_geometer_builds")
	assert(root_directory == expected)
	for label: String in DIRECTORIES:
		var path := root_directory.path_join(label)
		if not DirAccess.dir_exists_absolute(path):
			continue
		for file: String in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(file))
		DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(root_directory):
		DirAccess.remove_absolute(root_directory)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
