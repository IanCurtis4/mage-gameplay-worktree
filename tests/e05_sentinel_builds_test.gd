extends SceneTree
## S6 legal purchases, persistence and comparable allocations. No personal saves.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174216"
const DIRECTORIES: Array[String] = ["blocked", "gates", "critical", "caster", "menu22", "menu31", "menu37", "legacy"]
const GATES: Array[int] = [20, 20, 23, 25, 28, 31, 31, 34, 37]
const BASE_PURCHASES := {&"double_shot": 5, &"piercing_arrow": 5, &"arrow_rain": 5, &"archer_precision": 3, &"archer_cadence": 1}
const EQUIPPED: Dictionary[StringName, Variant] = {&"weapon": null, &"armor": null, &"accessory": null}
var directory: String
var checks := 0
var failures := 0
var critical_snapshot: BuildSnapshot
var caster_snapshot: BuildSnapshot

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_sentinel_builds")
	_cleanup()
	DirAccess.make_dir_recursive_absolute(directory)
	_blocked_candidate()
	_progression_gates()
	await _build("critical", {&"sentinel_headshot": 4, &"sentinel_observe": 3, &"sentinel_piercing_shot": 5, &"sentinel_concussion_shot": 1, &"sentinel_absolute_focus": 1, &"sentinel_precision_stance": 3, &"sentinel_opening_read": 3}, [&"sentinel_headshot", &"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_concussion_shot", &"sentinel_absolute_focus"], {&"dex": 45, &"agi": 27, &"luk": 15})
	await _build("caster", {&"sentinel_observe": 1, &"sentinel_piercing_shot": 5, &"sentinel_net_shot": 5, &"sentinel_explosive_shot": 5, &"sentinel_absolute_focus": 1, &"sentinel_precision_stance": 1, &"sentinel_opening_read": 2}, [&"sentinel_observe", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot", &"sentinel_absolute_focus"], {&"int": 45, &"dex": 27, &"luk": 15})
	_compare_builds()
	await _menu(22)
	await _menu(31)
	await _menu(37)
	_legacy()
	_cleanup()
	print("E05 Sentinel S6 builds/progression: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _catalog() -> ProfileCatalog:
	# Explicit local readiness fixture until the complete class is published in S7.
	return ProfileCatalog.pilot({}, {}, {&"sentinel": {"content_ready": true}})

func _profile(evolved: bool = false, job: int = 20) -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, 1), "Sentinela S6", &"archer")
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = _job_xp(job)
	character.evolution_id = &"sentinel" if evolved else &""
	profile.characters.append(character)
	profile.selected_character_id = character.character_id
	profile.next_character_counter = 2
	return profile

func _facade(label: String, evolved: bool = false, job: int = 20, catalog: ProfileCatalog = null) -> ProfileFacade:
	var actual_catalog := catalog if catalog != null else _catalog()
	var path := _path(label)
	_check(ProfileStore.new(path, actual_catalog).commit(_profile(evolved, job))["ok"], "%s isolated seed committed" % label)
	var facade := ProfileFacade.new(ProfileStore.new(path, actual_catalog), ProfileRewardResolver.pilot_progression())
	_check(facade.open_profile()["ok"], "%s isolated facade opened" % label)
	return facade

func _blocked_candidate() -> void:
	var production := ProfileCatalog.pilot()
	_check(production.is_valid() and _catalog().is_valid(), "production and local-ready catalogs validate")
	# This invariant remains meaningful when S7 later makes production ready.
	var blocked := ProfileCatalog.pilot({}, {}, {&"sentinel": {"content_ready": false}})
	var facade := _facade("blocked", true, 40, blocked)
	var revision := facade.current_profile().revision
	var started := facade.start_run("blocked-start", revision)
	_check(not started["ok"] and started["error_code"] == &"content_unavailable" and facade.current_profile().revision == revision and facade.current_profile().reward_session == null, "partial identity cannot start or write reward session")
	_check(not facade.prepare_playtest_training(facade.current_profile().selected_character_id)["ok"] and facade.current_profile().revision == revision, "partial identity cannot bypass readiness through training")

func _progression_gates() -> void:
	var facade := _facade("gates")
	var id := facade.current_profile().selected_character_id
	var before := facade.current_profile().character_by_id(id)
	_check(not facade.learn_skill("base-cannot-buy", facade.current_profile().revision, id, &"sentinel_observe")["ok"], "base Archer cannot purchase evolution library")
	var evolved := facade.change_evolution("real-evolution", facade.current_profile().revision, id, &"sentinel")
	var character := facade.current_profile().character_by_id(id)
	var summary := facade.progression_summary(id)
	_check(evolved["ok"] and character.evolution_id == &"sentinel" and character.base_class_id == &"archer" and character.base_xp_total == before.base_xp_total and character.job_xp_total == before.job_xp_total, "actual evolution fixes Archer origin and preserves XP")
	_check(summary["effective_skill_ranks"] == {&"sentinel_headshot": 1} and summary["evolution_skill_points_available"] == 0 and character.presets[0]["active_slots"] == [null, null, null, null, null], "Headshot R1 is free without autoequip or paid job20 points")
	var revision := facade.current_profile().revision
	var locked := facade.change_evolution("fixed-evolution", revision, id, &"hunter")
	_check(not locked["ok"] and locked["error_code"] == &"evolution_locked" and facade.current_profile().revision == revision, "normal evolution remains fixed, not replaced by admin shortcut")
	var no_points := facade.learn_skill("job20-empty", revision, id, &"sentinel_headshot")
	_check(not no_points["ok"] and no_points["error_code"] == &"insufficient_points" and facade.current_profile().revision == revision, "free entry cannot overdraft the evolution wallet")
	var catalog := _catalog()
	for index: int in SentinelTuning.SKILL_IDS.size():
		var skill := SentinelTuning.SKILL_IDS[index]
		var max_rank := SentinelTuning.max_rank(skill)
		for rank: int in range(1, max_rank + 1):
			_check(not catalog.check_rank_requirements(skill, rank, GATES[index] - 1, {})["ok"] and catalog.check_rank_requirements(skill, rank, GATES[index], {})["ok"], "each rank enforces exact job gate: %s R%d" % [skill, rank])
	for index: int in range(2, SentinelTuning.SKILL_IDS.size()):
		var skill := SentinelTuning.SKILL_IDS[index]
		var gate := GATES[index]
		if index != 6:
			_advance(facade, id, gate - 1, "below-%d" % index)
			var prior_revision := facade.current_profile().revision
			var prior_ranks := facade.current_profile().character_by_id(id).purchased_skill_ranks
			var rejected := facade.learn_skill("early-%d" % index, prior_revision, id, skill)
			_check(not rejected["ok"] and rejected["error_code"] == &"requirements_unmet" and facade.current_profile().revision == prior_revision and facade.current_profile().character_by_id(id).purchased_skill_ranks == prior_ranks, "real purchase below gate is atomic: %s" % skill)
		_advance(facade, id, gate, "at-%d" % index)
		var bought := facade.learn_skill("legal-%d" % index, facade.current_profile().revision, id, skill)
		_check(bought["ok"] and facade.current_profile().character_by_id(id).purchased_skill_ranks.get(skill) == 1, "real purchase succeeds at gate: %s" % skill)
	var encoded := ProfileCodec.encode(facade.current_profile(), catalog)
	_check(encoded["ok"] and ProfileCodec.decode(encoded["text"])["ok"], "blocked production still preserves valid Sentinel identity/ranks on load")

func _advance(facade: ProfileFacade, id: String, job: int, request: String) -> void:
	var wanted := _job_xp(job)
	var actual := facade.current_profile().character_by_id(id).job_xp_total
	if wanted > actual:
		_check(facade.grant_playtest_progression(request, facade.current_profile().revision, id, &"job_xp", wanted - actual)["ok"], "legal playtest XP reaches job%d" % job)
	_check(facade.progression_summary(id)["job_level"] == job, "derived job level is %d" % job)

func _build(label: String, evolution_purchases: Dictionary, active: Array[Variant], allocations: Dictionary) -> void:
	var facade := _facade(label)
	var id := facade.current_profile().selected_character_id
	_check(facade.change_evolution("%s-evolve" % label, facade.current_profile().revision, id, &"sentinel")["ok"], "%s evolves through real facade" % label)
	_check(facade.grant_playtest_progression("%s-max" % label, facade.current_profile().revision, id, &"max_levels")["ok"], "%s reaches legal base30/job40" % label)
	var purchases: Dictionary = BASE_PURCHASES.duplicate(true)
	purchases.merge(evolution_purchases)
	for skill: StringName in purchases:
		for rank: int in int(purchases[skill]):
			var result := facade.learn_skill("%s-%s-%d" % [label, skill, rank], facade.current_profile().revision, id, skill)
			_check(result["ok"], "%s buys actual %s rank%d" % [label, skill, rank + 1])
	var attribute_result := facade.allocate_attributes("%s-attributes" % label, facade.current_profile().revision, id, allocations)
	_check(attribute_result["ok"], "%s allocates equal legal budget" % label)
	var summary := facade.progression_summary(id)
	_check(summary["base_skill_points_spent"] == 19 and summary["evolution_skill_points_spent"] == 20 and summary["base_skill_points_available"] == 0 and summary["evolution_skill_points_available"] == 0 and summary["attribute_points_spent"] == 87 and summary["attribute_points_available"] == 0, "%s exhausts exactly 19/20/87 points independently" % label)
	var revision := facade.current_profile().revision
	var extra := &"sentinel_net_shot" if label == "critical" else &"sentinel_concussion_shot"
	var overflow := facade.learn_skill("%s-overdraw" % label, revision, id, extra)
	_check(not overflow["ok"] and overflow["error_code"] == &"insufficient_points" and facade.current_profile().revision == revision, "%s cannot overdraw evolution points" % label)
	var base_overflow := facade.learn_skill("%s-base-overdraw" % label, revision, id, &"extended_aim")
	_check(not base_overflow["ok"] and base_overflow["error_code"] == &"insufficient_points" and facade.current_profile().revision == revision, "%s cannot overdraw base wallet instead" % label)
	_check(not facade.allocate_attributes("%s-attribute-overdraw" % label, revision, id, {&"vit": 1})["ok"] and facade.current_profile().revision == revision, "%s cannot overdraw attributes" % label)
	var passive: Array[Variant] = [&"sentinel_precision_stance", &"sentinel_opening_read"]
	_check(facade.update_preset("%s-equip" % label, revision, id, 0, active, passive, EQUIPPED)["ok"], "%s equips real five/two slots" % label)
	revision = facade.current_profile().revision
	_check(not facade.update_preset("%s-six" % label, revision, id, 0, active + [&"double_shot"], passive, EQUIPPED)["ok"] and facade.current_profile().revision == revision, "%s sixth active rejected without revision" % label)
	_check(not facade.update_preset("%s-three" % label, revision, id, 0, active, passive + [&"archer_precision"], EQUIPPED)["ok"] and facade.current_profile().revision == revision, "%s third passive rejected without revision" % label)
	var duplicate: Array[Variant] = active.duplicate()
	duplicate[4] = duplicate[0]
	_check(not facade.update_preset("%s-duplicate" % label, revision, id, 0, duplicate, passive, EQUIPPED)["ok"] and facade.current_profile().revision == revision, "%s duplicate active rejected atomically" % label)
	var foreign: Array[Variant] = active.duplicate()
	foreign[4] = &"geometer_trace"
	_check(not facade.update_preset("%s-foreign" % label, revision, id, 0, foreign, passive, EQUIPPED)["ok"] and facade.current_profile().revision == revision, "%s foreign origin rejected" % label)
	var unlearned: Array[Variant] = active.duplicate()
	unlearned[4] = extra
	_check(not facade.update_preset("%s-unlearned" % label, revision, id, 0, unlearned, passive, EQUIPPED)["ok"] and facade.current_profile().revision == revision, "%s unlearned skills cannot equip" % label)
	_check(not facade.update_preset("%s-category" % label, revision, id, 0, active, [&"sentinel_headshot", &"sentinel_opening_read"], EQUIPPED)["ok"] and facade.current_profile().revision == revision, "%s active/passive categories enforced" % label)
	var encoded := ProfileCodec.encode(facade.current_profile(), _catalog())
	var decoded := ProfileCodec.decode(encoded.get("text", ""))
	_check(encoded["ok"] and decoded["ok"] and not decoded.get("migrated", false) and decoded["profile"].character_by_id(id).purchased_skill_ranks == purchases, "%s all nine IDs save/reload without schema migration" % label)
	var invalid: Dictionary = encoded["data"].duplicate(true)
	invalid["characters"][0]["purchased_skill_ranks"][String(extra)] = 1
	_check(not ProfileCodec.decode(JSON.stringify(invalid), _catalog())["ok"], "%s codec rejects overspent wallet" % label)
	invalid = encoded["data"].duplicate(true)
	invalid["characters"][0]["purchased_skill_ranks"]["sentinel_headshot"] = 5
	_check(not ProfileCodec.decode(JSON.stringify(invalid), _catalog())["ok"], "%s codec rejects Headshot free-plus-paid overflow" % label)
	var persistent_before := _disk("%s/profile.json" % label)
	var training := facade.prepare_playtest_training(id)
	_check(training["ok"] and training["run_state"].run_id.is_empty() and facade.current_profile().revision == revision and facade.current_profile().reward_session == null and _disk("%s/profile.json" % label) == persistent_before, "%s training copies saved build without durable write/reward session" % label)
	if training["ok"]:
		training["run_state"].build_snapshot.attribute_allocations[&"dex"] = 99
		training["run_state"].build_snapshot.skill_ranks[&"sentinel_headshot"] = 99
		var fake_reward := facade.grant_reward("%s-training-reward" % label, revision, "", 1, &"encounter_one")
		_check(not fake_reward["ok"] and _disk("%s/profile.json" % label) == persistent_before and facade.current_profile().revision == revision, "%s training cannot grant normal-run rewards or mutate saved ranks" % label)
	var reloaded := ProfileFacade.new(ProfileStore.new(_path(label), _catalog()), ProfileRewardResolver.pilot_progression())
	_check(reloaded.open_profile()["ok"], "%s durable reload" % label)
	var durable := reloaded.current_profile().character_by_id(id)
	_check(durable.evolution_id == &"sentinel" and durable.base_class_id == &"archer" and durable.purchased_skill_ranks == purchases and durable.presets[0]["active_slots"] == active and durable.presets[0]["passive_slots"] == passive and durable.presets[0]["equipped"] == EQUIPPED, "%s exact durable identity/build/equipment" % label)
	var preview := reloaded.build_preview(id)
	_check(preview["ok"] and preview["snapshot"].skill_ranks[&"sentinel_headshot"] == 1 + int(evolution_purchases.get(&"sentinel_headshot", 0)), "%s preview includes free Headshot rank" % label)
	if label == "critical":
		critical_snapshot = preview["snapshot"]
	else:
		caster_snapshot = preview["snapshot"]
	var run := reloaded.start_run("%s-start" % label, reloaded.current_profile().revision)
	_check(run["ok"] and run["run_state"].class_id == &"archer" and run["run_state"].build_snapshot.evolution_id == &"sentinel", "%s starts actual legal build" % label)
	if run["ok"]:
		var run_revision := reloaded.current_profile().revision
		_check(not reloaded.learn_skill("%s-run-learn" % label, run_revision, id, extra)["ok"] and not reloaded.respec_skills("%s-run-respec" % label, run_revision, id)["ok"] and not reloaded.update_preset("%s-run-build" % label, run_revision, id, 0, active, passive, EQUIPPED)["ok"] and reloaded.current_profile().revision == run_revision, "%s live run locks progression/build mutations" % label)
		_check(reloaded.end_run("%s-end" % label, run_revision, run["run_id"], &"abandoned")["ok"], "%s closes isolated run" % label)
	var refund := reloaded.respec_skills("%s-respec" % label, reloaded.current_profile().revision, id)
	_check(refund["ok"] and refund["base_refund"] == 19 and refund["evolution_refund"] == 20 and reloaded.progression_summary(id)["effective_skill_ranks"] == {&"sentinel_headshot": 1} and reloaded.current_profile().character_by_id(id).evolution_id == &"sentinel", "%s real respec refunds both wallets but keeps fixed identity/free rank" % label)
	var pruned := reloaded.current_profile().character_by_id(id).presets[0]
	_check(pruned["passive_slots"] == [null, null] and pruned["active_slots"] == ([&"sentinel_headshot", null, null, null, null] if label == "critical" else [null, null, null, null, null]), "%s respec prunes exactly paid slots without autoequipping free Headshot" % label)
	await process_frame

func _compare_builds() -> void:
	if critical_snapshot == null or caster_snapshot == null:
		_check(false, "both snapshots exist for equivalent-budget comparison")
		return
	var critical := critical_snapshot.stat_breakdown()
	var caster := caster_snapshot.stat_breakdown()
	_check(critical_snapshot.base_level == caster_snapshot.base_level and critical_snapshot.job_level == caster_snapshot.job_level and critical_snapshot.equipped == caster_snapshot.equipped and ProgressionRules.attribute_points_spent(critical_snapshot.attribute_allocations) == ProgressionRules.attribute_points_spent(caster_snapshot.attribute_allocations), "comparisons control levels, attribute budgets and equipment")
	_check(critical.value(&"precision_attack") > caster.value(&"precision_attack") and critical.value(&"attacks_per_second") > caster.value(&"attacks_per_second"), "DES/AGI build favors auto precision and cadence")
	_check(SentinelMath.raw_power(&"sentinel_headshot", 5, critical) > SentinelMath.raw_power(&"sentinel_headshot", 5, caster), "same-rank Headshot favors critical attributes")
	for skill: StringName in [&"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot"]:
		var tuning := SentinelTuning.values(skill, 5)
		var crit_power := SentinelMath.raw_power(skill, 5, critical)
		var cast_power := SentinelMath.raw_power(skill, 5, caster)
		var crit_cd := SentinelMath.cooldown(skill, tuning["cooldown"], critical)
		var cast_cd := SentinelMath.cooldown(skill, tuning["cooldown"], caster)
		_check(cast_power > crit_power and crit_power > 0.0, "INT build favors per-use magic impact; skill remains useful in both: %s" % skill)
		_check(crit_cd < cast_cd and crit_cd >= float(tuning["cooldown"]) * 0.75 and cast_cd <= float(tuning["cooldown"]), "higher DES helps only bounded local cadence: %s" % skill)
		print("S6 comparable %s R5: critical raw=%.2f cd=%.3fs; caster raw=%.2f cd=%.3fs; SP=%.2f Foco=%.0f" % [skill, crit_power, crit_cd, cast_power, cast_cd, tuning["sp_cost"], tuning["focus_cost"]])
	_check(SentinelMath.cooldown(&"sentinel_headshot", 6.0, critical) == SentinelMath.cooldown(&"sentinel_headshot", 6.0, caster), "local DES rule does not leak to Headshot")
	_check(caster_snapshot.attribute_allocations[&"agi"] == 0 and caster_snapshot.skill_ranks[&"sentinel_net_shot"] == 5 and caster_snapshot.skill_ranks[&"sentinel_explosive_shot"] == 5 and &"sentinel_headshot" not in caster_snapshot.active_slots, "caster legally uses full Rede/Explosivo without paid AGI or Headshot slot")

func _menu(job: int) -> void:
	var facade := _facade("menu%d" % job, true, job)
	var menu := load("res://scenes/character_menu.tscn").instantiate() as CharacterMenu
	menu.set_profile_facade(facade)
	root.add_child(menu)
	await process_frame
	_check(menu.evolution_state_label.text.contains("Sentinela") and menu.evolution_state_label.text.contains("Arqueiro"), "job%d menu presents fixed origin and identity" % job)
	for index: int in SentinelTuning.SKILL_IDS.size():
		var skill := SentinelTuning.SKILL_IDS[index]
		var label := menu.progression_skill_tree.get_node_or_null("ProgressionSkill_%s" % skill) as Label
		var button := menu.progression_skill_tree.get_node_or_null("Learn_%s" % skill) as Button
		_check((label != null and button != null) == (job >= GATES[index]), "job%d hides/reveals correct Sentinel gate: %s" % [job, skill])
		if label != null:
			_check(label.text.contains("Rank %d/%d" % [1 if index == 0 else 0, SentinelTuning.max_rank(skill)]), "job%d menu exact free/purchased rank: %s" % [job, skill])
	_check(menu.active_selectors.size() == 5 and menu.passive_selectors.size() == 2 and menu.progression_skill_tree.get_node_or_null("ProgressionSkill_geometer_trace") == null, "menu keeps five/two slots and excludes unrelated Mage library")
	menu.queue_free()
	await process_frame

func _legacy() -> void:
	var path := _path("legacy")
	var before := _profile(false)
	before.characters[0].purchased_skill_ranks[&"double_shot"] = 1
	before.characters[0].presets[0]["active_slots"][0] = &"double_shot"
	var encoded := ProfileCodec.encode(before)
	var prior: Dictionary = encoded["data"].duplicate(true)
	prior["catalog_version"] = ProfileCodec.PRE_SPIRITUALIST_CATALOG_VERSION
	var prior_text := JSON.stringify(prior)
	var file := FileAccess.open(path.path_join(ProfileStore.PRIMARY_FILE), FileAccess.WRITE)
	file.store_string(prior_text)
	file.close()
	var facade := ProfileFacade.new(ProfileStore.new(path, _catalog()))
	var opened := facade.open_profile()
	_check(opened["ok"], "older catalog Archer save migrates through real facade/store")
	if not opened["ok"]:
		return
	var character := facade.current_profile().characters[0]
	_check(character.evolution_id.is_empty() and character.base_class_id == &"archer" and character.purchased_skill_ranks == {&"double_shot": 1} and character.presets[0]["active_slots"][0] == &"double_shot" and character.base_xp_total == before.characters[0].base_xp_total and character.job_xp_total == before.characters[0].job_xp_total, "legacy identity/purchases/preset/XP survive without automatic Sentinel grant")
	_check(_disk("legacy/profile.backup.json") == prior_text and JSON.parse_string(_disk("legacy/profile.json"))["catalog_version"] == ProfileState.CATALOG_VERSION, "legacy transaction preserves exact backup and commits current catalog")
	var revision := facade.current_profile().revision
	var current_text := _disk("legacy/profile.json")
	_check(facade.open_profile()["ok"] and facade.current_profile().revision == revision and _disk("legacy/profile.json") == current_text, "old-save migration is idempotent")

func _job_xp(job: int) -> int:
	for xp: int in range(ProgressionRules.MAX_JOB_XP + 1):
		if ProgressionRules.job_level_for_xp(xp, true) == job:
			return xp
	return ProgressionRules.MAX_JOB_XP

func _path(label: String) -> String:
	assert(label in DIRECTORIES)
	var path := directory.path_join(label)
	DirAccess.make_dir_recursive_absolute(path)
	return path

func _disk(relative: String) -> String:
	assert(relative.get_slice("/", 0) in DIRECTORIES)
	return FileAccess.get_file_as_string(directory.path_join(relative))

func _cleanup() -> void:
	assert(directory == ProjectSettings.globalize_path("res://.godot/verification/e05_sentinel_builds"))
	for label: String in DIRECTORIES:
		var path := directory.path_join(label)
		if not DirAccess.dir_exists_absolute(path):
			continue
		for filename: String in DirAccess.get_files_at(path):
			DirAccess.remove_absolute(path.path_join(filename))
		DirAccess.remove_absolute(path)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
