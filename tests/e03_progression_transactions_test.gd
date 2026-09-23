extends SceneTree

class ToggleFailStore:
	extends ProfileStore
	var failure_stage: StringName = &""

	func _should_fail(stage: StringName) -> bool:
		return not failure_stage.is_empty() and stage == failure_stage

class UncertainStore:
	extends ProfileStore
	var hide_next_success := false

	func commit(source: ProfileState) -> Dictionary:
		var result := super.commit(source)
		if hide_next_success and result["ok"]:
			hide_next_success = false
			return {"ok": false, "error_code": &"save_failed"}
		return result

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174000"

var failures := 0
var checks := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e03_progression")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_levels_attributes_ranks_and_snapshot()
	_check_evolution_wallet_and_requirements()
	_check_failure_retry_reload_and_uncertainty()
	_check_catalog_invariants()
	_cleanup_directory(root_directory)
	print("E03 progressão/transações: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_levels_attributes_ranks_and_snapshot() -> void:
	var directory := root_directory.path_join("base_progression")
	_prepare_directory(directory)
	var catalog := _catalog()
	var seeded := _seed_character(directory, catalog, false, ProgressionRules.MAX_BASE_XP, ProgressionRules.UNEVOLVED_MAX_JOB_XP)
	var character_id: String = seeded["character_id"]
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var summary := facade.progression_summary(character_id)
	_check(opened["ok"] and summary["base_level"] == 30 and summary["job_level"] == 20, "capped accumulated XP derives base 30 and unevolved job 20 after reload")
	_check(summary["attribute_points_granted"] == 87 and summary["attribute_points_available"] == 87 and summary["base_skill_points_available"] == 19 and summary["evolution_skill_points_available"] == 0, "three independent wallets derive from XP without persisted balances")
	_check(summary["evolution_eligible"] and summary["job_progress_blocked"], "unevolved base 30/job 20 exposes eligibility and the accepted job-XP gate without evolving the character")
	var skill_options := facade.progression_skill_options(character_id)
	var heavy_slash: Dictionary = _skill_option(skill_options["skills"], &"heavy_slash")
	var rune_entry: Dictionary = _skill_option(skill_options["skills"], &"rune_entry")
	_check(skill_options["ok"] and skill_options["character_id"] == character_id and skill_options["skills"].map(func(option: Dictionary) -> StringName: return option["skill_id"]) == [&"brutal_strike", &"concentrated_rage", &"dash", &"fury", &"heavy_slash", &"late_mastery", &"perseverance", &"piercing_shout", &"provoke", &"rune_chain", &"rune_entry", &"shield_wall", &"slash", &"swordsman_resistance", &"terrifying_shout", &"vigor"], "progression skill options list every origin catalog skill in deterministic order, including rank-zero and future evolution entries")
	_check(heavy_slash["rank"] == 0 and heavy_slash["purchased_rank"] == 0 and heavy_slash["maximum_rank"] == 5 and heavy_slash["available"] and heavy_slash["next_rank"] == 1 and heavy_slash["next_rank_requirement"] == {"job_level": 5, "skill_ranks": {&"slash": 3}} and not heavy_slash["next_rank_available"] and heavy_slash["next_rank_error_code"] == &"requirements_unmet", "rank-zero options expose copied catalog metadata and the authoritative next-rank requirement without UI formulas")
	_check(not rune_entry["available"] and rune_entry["rank"] == 0 and rune_entry["next_rank"] == 1 and rune_entry["next_rank_requirement"]["job_level"] == 20 and not rune_entry["next_rank_available"] and rune_entry["next_rank_error_code"] == &"requirements_unmet", "unevolved characters can render their future evolution branch as unavailable without inventing a rank state")
	heavy_slash["metadata"]["rank_requirements"][1]["job_level"] = 99
	var clean_heavy_slash: Dictionary = _skill_option(facade.progression_skill_options(character_id)["skills"], &"heavy_slash")
	_check(clean_heavy_slash["metadata"]["rank_requirements"][1]["job_level"] == 5 and not facade.progression_skill_options("missing")["ok"], "skill-option metadata is disposable and an unknown character remains a query error")
	_check(ProgressionRules.base_level_for_xp(350) == 3 and ProgressionRules.base_level_for_xp(375) == 4 and ProgressionRules.attribute_points_granted(375) == 9, "one accumulated reward can cross multiple base levels and grant each level exactly once")

	var invalid := facade.allocate_attributes("bad-attributes", 1, character_id, {&"str": 1, &"banana": 1})
	_check(not invalid["ok"] and invalid["error_code"] == &"invalid_attribute_allocations" and facade.current_profile().character_by_id(character_id).attribute_allocations[&"str"] == 0, "invalid multi-attribute request is atomic")
	var strength := facade.allocate_attributes("strength-cap", 1, character_id, {&"str": 52})
	var vitality := facade.allocate_attributes("spend-rest", 2, character_id, {&"vit": 35})
	_check(strength["ok"] and strength["progression"]["attribute_points_available"] == 35 and vitality["ok"] and vitality["progression"]["attribute_points_available"] == 0, "allocation spends exactly one point per primary and conserves the 87-point wallet")
	var cap_fail := facade.allocate_attributes("over-cap", 3, character_id, {&"str": 1})
	var funds_fail := facade.allocate_attributes("no-points", 3, character_id, {&"agi": 1})
	_check(not cap_fail["ok"] and cap_fail["error_code"] == &"attribute_cap_reached" and not funds_fail["ok"] and funds_fail["error_code"] == &"insufficient_points", "attribute investment enforces initial-plus-allocation cap and available balance")

	var reloaded := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var reload_open := reloaded.open_profile()
	var reload_summary := reloaded.progression_summary(character_id)
	_check(reload_open["ok"] and reload_summary["attribute_points_spent"] == 87 and reload_summary["attribute_points_available"] == 0, "allocation and derived balance survive a full facade/store reload")

	var prereq_fail := reloaded.learn_skill("heavy-too-early", 3, character_id, &"heavy_slash")
	_check(not prereq_fail["ok"] and prereq_fail["error_code"] == &"requirements_unmet", "rank purchase rejects an unmet skill prerequisite without a revision")
	var slash_one := reloaded.learn_skill("slash-1", 3, character_id, &"slash")
	var slash_two := reloaded.learn_skill("slash-2", 4, character_id, &"slash")
	var slash_three := reloaded.learn_skill("slash-3", 5, character_id, &"slash")
	var heavy_one := reloaded.learn_skill("heavy-1", 6, character_id, &"heavy_slash")
	_check(slash_one["rank"] == 1 and slash_two["rank"] == 2 and slash_three["rank"] == 3 and heavy_one["ok"] and heavy_one["rank"] == 1, "sequential purchases learn rank one and use explicit next-rank requirements")
	var late_fail := reloaded.learn_skill("late-job", 7, character_id, &"late_mastery")
	_check(not late_fail["ok"] and late_fail["error_code"] == &"requirements_unmet", "job requirement is evaluated from durable accumulated XP")

	var profile := reloaded.current_profile()
	var character: CharacterState = profile.character_by_id(character_id)
	var active: Array[Variant] = character.presets[0]["active_slots"].duplicate(true)
	active[0] = &"heavy_slash"
	var preset := reloaded.update_preset("equip-heavy", 7, character_id, 0, active, character.presets[0]["passive_slots"], character.presets[0]["equipped"])
	var slash_four := reloaded.learn_skill("slash-4", 8, character_id, &"slash")
	var slash_five := reloaded.learn_skill("slash-5", 9, character_id, &"slash")
	var slash_cap := reloaded.learn_skill("slash-cap", 10, character_id, &"slash")
	_check(preset["ok"] and slash_four["ok"] and slash_five["rank"] == 5 and not slash_cap["ok"] and slash_cap["error_code"] == &"rank_cap_reached", "active rank stops at five and learned purchased-only skill can enter a preset")

	var skill_respec := reloaded.respec_skills("respec-skills", 10, character_id)
	var after_skill_respec: CharacterState = skill_respec["profile"].character_by_id(character_id)
	_check(skill_respec["ok"] and skill_respec["base_refund"] == 6 and skill_respec["evolution_refund"] == 0 and skill_respec["progression"]["base_skill_points_available"] == 19, "skill respec refunds exact wallet costs without persisting a balance")
	_check(after_skill_respec.purchased_skill_ranks.is_empty() and after_skill_respec.presets[0]["active_slots"][0] == null and skill_respec["progression"]["effective_skill_ranks"].get(&"slash", 0) == 0, "skill respec prunes illegal preset references and returns non-legacy skills to rank zero")

	var attribute_respec := reloaded.respec_attributes("respec-attributes", 11, character_id)
	var stale_retry := reloaded.respec_attributes("respec-attributes", 11, character_id)
	var no_op := reloaded.respec_attributes("respec-empty", 12, character_id)
	_check(attribute_respec["ok"] and attribute_respec["refunded"] == 87 and attribute_respec["progression"]["attribute_points_available"] == 87, "attribute respec restores the whole allocation wallet and preserves XP")
	_check(not stale_retry["ok"] and stale_retry["error_code"] == &"stale_revision" and no_op["ok"] and no_op["already_applied"] and no_op["new_revision"] == 12, "stale retry cannot duplicate respec and an already-empty respec does not write")

	var preview := reloaded.build_preview(character_id, [{"source_id": &"preview", "primary_flat": {&"str": 2.0}}])
	preview["snapshot"].attribute_allocations[&"str"] = 50
	preview["stat_breakdown"].primary[&"str"]["effective"] = 500.0 # Returned preview is a disposable value object.
	var clean_preview := reloaded.build_preview(character_id, [{"source_id": &"preview", "primary_flat": {&"str": 2.0}}])
	_check(clean_preview["ok"] and clean_preview["snapshot"].attribute_allocations[&"str"] == 0 and is_equal_approx(clean_preview["stat_breakdown"].primary_value(&"str"), 10.0), "menu preview returns isolated snapshot and StatBreakdown instances")
	var invalid_preview := reloaded.build_preview(character_id, [{"source_id": &"bad_preview", "increased": {&"str": 1.0}}])
	_check(not invalid_preview["ok"] and invalid_preview["error_code"] == &"invalid_stat_id", "preview returns calculator validation errors without publishing or duplicating formulas")

	var started := reloaded.start_run("snapshot-run", 12)
	var run_state: RunState = started["run_state"]
	var snapshot := run_state.build_snapshot
	var source := {"source_id": &"snapshot_test", "primary_flat": {&"str": 2.0}}
	var breakdown := snapshot.stat_breakdown([source])
	var detail := breakdown.primary_detail(&"str")
	detail["effective"] = 999.0
	source["primary_flat"][&"str"] = 999.0
	breakdown.primary[&"str"]["effective"] = 777.0 # Consumer violation must remain local to this instance.
	var isolated := snapshot.stat_breakdown([{"source_id": &"snapshot_test", "primary_flat": {&"str": 2.0}}])
	_check(snapshot.base_level == 30 and snapshot.job_level == 20 and snapshot.skill_ranks.is_empty() and snapshot.attribute_allocations[&"str"] == 0, "run snapshot carries effective levels, an empty skill build and copied investments")
	_check(is_equal_approx(isolated.primary_value(&"str"), 10.0) and is_equal_approx(isolated.value(&"melee_attack"), 32.0), "snapshot stats always come from StatCalculator and separate StatBreakdown instances")
	_check(not reloaded.allocate_attributes("during-run", 13, character_id, {&"str": 1})["ok"] and not reloaded.learn_skill("learn-during-run", 13, character_id, &"slash")["ok"], "allocation and rank purchases remain menu-only while a run is active")

func _check_evolution_wallet_and_requirements() -> void:
	var directory := root_directory.path_join("evolution_wallet")
	_prepare_directory(directory)
	var catalog := _catalog()
	var seeded := _seed_character(directory, catalog, true, ProgressionRules.EVOLUTION_MIN_BASE_XP, 5400)
	var character_id: String = seeded["character_id"]
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var summary := facade.progression_summary(character_id)
	_check(opened["ok"] and summary["job_level"] == 21 and summary["base_skill_points_available"] == 19 and summary["evolution_skill_points_available"] == 1, "evolved job 21 exposes separate 19-base and 1-evolution wallets")
	var chain_before_entry := facade.learn_skill("chain-before", 1, character_id, &"rune_chain")
	_check(not chain_before_entry["ok"] and chain_before_entry["error_code"] == &"requirements_unmet", "evolution skill prerequisite checks the free-plus-purchased effective rank")
	var entry_two := facade.learn_skill("entry-2", 1, character_id, &"rune_entry")
	var base_rank := facade.learn_skill("base-rank", 2, character_id, &"slash")
	var no_evolution_points := facade.learn_skill("chain-no-points", 3, character_id, &"rune_chain")
	_check(entry_two["ok"] and entry_two["wallet"] == ProfileCatalog.EVOLUTION_WALLET and base_rank["ok"] and base_rank["wallet"] == ProfileCatalog.BASE_WALLET, "base and evolution purchases debit only their declared wallets")
	_check(not no_evolution_points["ok"] and no_evolution_points["error_code"] == &"insufficient_points" and facade.progression_summary(character_id)["base_skill_points_available"] == 18, "empty evolution wallet cannot consume the independent base balance")

	var invalid_profile := facade.current_profile()
	var invalid_character := invalid_profile.character_by_id(character_id)
	invalid_character.purchased_skill_ranks.erase(&"rune_entry")
	invalid_character.purchased_skill_ranks[&"rune_chain"] = 1
	var invalid_encoding := ProfileCodec.encode(invalid_profile, catalog)
	_check(not invalid_encoding["ok"] and invalid_encoding["error_code"] == &"requirements_unmet", "reload validation rejects persisted ranks that bypass prerequisites")

	var respec := facade.respec_skills("evolved-respec", 3, character_id)
	_check(respec["ok"] and respec["base_refund"] == 1 and respec["evolution_refund"] == 1 and respec["progression"]["effective_skill_ranks"][&"rune_entry"] == 1, "full respec conserves both wallets and reinstalls evolution free rank once")

func _check_failure_retry_reload_and_uncertainty() -> void:
	var catalog := _catalog()
	var directory := root_directory.path_join("definite_failure")
	_prepare_directory(directory)
	var seeded := _seed_character(directory, catalog, false, 100, 0)
	var character_id: String = seeded["character_id"]
	var store := ToggleFailStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	var opened := facade.open_profile()
	var dash_option: Dictionary = _skill_option(facade.progression_skill_options(character_id)["skills"], &"dash")
	_check(not dash_option["next_rank_available"] and dash_option["next_rank_error_code"] == &"insufficient_points", "next-rank state includes the matching empty wallet error before the menu attempts a transaction")
	store.failure_stage = &"write_pending"
	var failed := facade.allocate_attributes("failed-allocation", opened["profile"].revision, character_id, {&"str": 1})
	_check(not failed["ok"] and failed["error_code"] == &"save_failed" and facade.current_profile().character_by_id(character_id).attribute_allocations[&"str"] == 0, "definite save failure publishes no partial allocation")
	store.failure_stage = &""
	var retried := facade.allocate_attributes("retry-allocation", opened["profile"].revision, character_id, {&"str": 1})
	var restarted := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var reloaded := restarted.open_profile()
	_check(retried["ok"] and reloaded["profile"].character_by_id(character_id).attribute_allocations[&"str"] == 1 and restarted.progression_summary(character_id)["attribute_points_available"] == 2, "same revision can retry a definite failure and survives reload exactly once")

	var uncertain_directory := root_directory.path_join("uncertain")
	_prepare_directory(uncertain_directory)
	var uncertain_seed := _seed_character(uncertain_directory, catalog, false, 100, 0)
	var uncertain_store := UncertainStore.new(uncertain_directory, catalog)
	var uncertain := ProfileFacade.new(uncertain_store)
	var uncertain_open := uncertain.open_profile()
	uncertain_store.hide_next_success = true
	var recovered := uncertain.allocate_attributes("uncertain-allocation", uncertain_open["profile"].revision, uncertain_seed["character_id"], {&"dex": 2})
	var replay := uncertain.allocate_attributes("uncertain-allocation", uncertain_open["profile"].revision, uncertain_seed["character_id"], {&"dex": 2})
	_check(recovered["ok"] and recovered["recovered_after_uncertain_result"] and not replay["ok"] and replay["error_code"] == &"stale_revision", "uncertain success is confirmed by durable reread and its literal retry cannot double-spend")
	_check(uncertain.current_profile().character_by_id(uncertain_seed["character_id"]).attribute_allocations[&"dex"] == 2, "uncertain recovery exposes exactly the committed allocation")

func _check_catalog_invariants() -> void:
	var sealed := ProfileCatalog.pilot()
	var sealed_slash := sealed.skill_metadata(&"slash")
	var rejected_sealed_skill := sealed.add_skill(&"sealed_skill", [&"swordsman"], ProfileCatalog.ACTIVE, ProfileCatalog.BASE_WALLET, 0, 1)
	var rejected_sealed_equipment := sealed.add_equipment(&"sealed_sword", &"weapon", [&"swordsman"])
	_check(not rejected_sealed_skill and not rejected_sealed_equipment and sealed.is_valid(), "rejected writes cannot invalidate a sealed catalog")
	_check(sealed.skill_metadata(&"slash") == sealed_slash and sealed.skill_metadata(&"sealed_skill").is_empty() and sealed.equipment_metadata(&"sealed_sword").is_empty(), "sealed catalog content remains unchanged after rejected writes")

	var cyclic := ProfileCatalog.pilot({}, {
		&"cycle_a": _skill(ProfileCatalog.BASE_WALLET, 0, 1, &"", {1: {"job_level": 2, "skill_ranks": {&"cycle_b": 1}}}),
		&"cycle_b": _skill(ProfileCatalog.BASE_WALLET, 0, 1, &"", {1: {"job_level": 2, "skill_ranks": {&"cycle_a": 1}}}),
	})
	var duplicate := ProfileCatalog.pilot({}, {
		&"slash": _skill(ProfileCatalog.BASE_WALLET, 0, 1),
	})
	var unknown_rank := ProfileCatalog.pilot({}, {
		&"unknown_rank": _skill(ProfileCatalog.BASE_WALLET, 0, 1, &"", {
			"wrong_rank": {"job_level": 40, "skill_ranks": {&"missing": 5}},
		}),
	})
	var out_of_range := ProfileCatalog.pilot({}, {
		&"out_of_range": _skill(ProfileCatalog.BASE_WALLET, 0, 1, &"", {
			2: {"job_level": 2},
		}),
	})
	var unknown_field := ProfileCatalog.pilot({}, {
		&"unknown_field": _skill(ProfileCatalog.BASE_WALLET, 0, 1, &"", {
			1: {"job_level": 2, "skill_ranks": {}, "job_lvel": 3},
		}),
	})
	var conflicting_aliases := ProfileCatalog.pilot({}, {
		&"alias_conflict": _skill(ProfileCatalog.BASE_WALLET, 0, 1, &"", {
			1: {"job_level": 2},
			"1": {"job_level": 3},
		}),
	})
	var defaults := ProfileCatalog.pilot({}, {
		&"defaults": _skill(ProfileCatalog.BASE_WALLET, 0, 2, &"", {
			"1": {"job_level": 2},
		}),
	})
	_check(not cyclic.is_valid(), "catalog rejects cyclic skill prerequisites before any profile is loaded")
	_check(not duplicate.is_valid(), "catalog rejects duplicate skill IDs instead of silently replacing immutable definitions")
	_check(not unknown_rank.is_valid() and not out_of_range.is_valid(), "catalog rejects unknown and out-of-range rank requirement keys")
	_check(not unknown_field.is_valid() and not conflicting_aliases.is_valid(), "catalog rejects unknown fields and conflicting numeric aliases before normalization")
	var default_requirements: Dictionary = defaults.skill_metadata(&"defaults")["rank_requirements"]
	_check(defaults.is_valid() and default_requirements[1]["job_level"] == 2 and default_requirements[1]["skill_ranks"].is_empty() and default_requirements[2]["job_level"] == 1, "omitted known fields and ranks keep documented wallet defaults")

func _catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({}, {
		&"heavy_slash": _skill(ProfileCatalog.BASE_WALLET, 0, 5, &"", {
			1: {"job_level": 5, "skill_ranks": {&"slash": 3}},
		}),
		&"late_mastery": _skill(ProfileCatalog.BASE_WALLET, 0, 5, &"", {
			1: {"job_level": 21, "skill_ranks": {}},
		}),
		&"rune_entry": _skill(ProfileCatalog.EVOLUTION_WALLET, 1, 4, &"sp_mg"),
		&"rune_chain": _skill(ProfileCatalog.EVOLUTION_WALLET, 0, 5, &"sp_mg", {
			1: {"job_level": 21, "skill_ranks": {&"rune_entry": 2}},
		}),
	})

func _skill_option(options: Array, skill_id: StringName) -> Dictionary:
	for option: Dictionary in options:
		if option["skill_id"] == skill_id:
			return option
	return {}

func _skill(wallet: StringName, free_rank: int, max_purchased_rank: int, evolution_id: StringName = &"", requirements: Dictionary = {}) -> Dictionary:
	return {
		"allowed_base_classes": [&"swordsman"],
		"category": ProfileCatalog.ACTIVE,
		"wallet": wallet,
		"free_rank": free_rank,
		"max_purchased_rank": max_purchased_rank,
		"required_evolution_id": evolution_id,
		"rank_requirements": requirements,
	}

func _seed_character(directory: String, catalog: ProfileCatalog, evolved: bool, base_xp: int, job_xp: int) -> Dictionary:
	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Teste", &"swordsman")
	character.evolution_id = &"sp_mg" if evolved else &""
	character.base_xp_total = base_xp
	character.job_xp_total = job_xp
	var initial_slots := catalog.initial_skill_slots(&"swordsman")
	for preset: Dictionary in character.presets:
		preset["active_slots"] = initial_slots["active_slots"].duplicate(true)
		preset["passive_slots"] = initial_slots["passive_slots"].duplicate(true)
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	var committed := ProfileStore.new(directory, catalog).commit(profile)
	_check(committed["ok"], "progression fixture is durably seeded")
	return {"character_id": character_id, "profile": committed.get("profile")}

func _prepare_directory(path: String) -> void:
	_cleanup_directory(path)
	DirAccess.make_dir_recursive_absolute(path)

func _cleanup_directory(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for child: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(child))
	for child: String in directory.get_directories():
		_cleanup_directory(path.path_join(child))
		DirAccess.remove_absolute(path.path_join(child))

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
