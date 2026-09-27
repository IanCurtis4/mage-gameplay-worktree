extends SceneTree

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174065"

var checks := 0
var failures := 0
var directory: String

func _initialize() -> void:
	directory = ProjectSettings.globalize_path("res://.godot/verification/e05_identity_boundary")
	_cleanup_directory()
	DirAccess.make_dir_recursive_absolute(directory)
	_run.call_deferred()

func _run() -> void:
	var production := ProfileCatalog.pilot()
	_check(production.is_valid() and production.evolution_is_ready(&"defender", &"swordsman") and production.evolution_is_ready(&"berserker", &"swordsman"), "completed Swordsman branches are available in production")
	var catalog := _catalog()
	_check(catalog.is_valid(), "isolated identity fixture is valid")
	var base_ids := catalog.skill_ids_for_identity(&"swordsman")
	var defender_ids := catalog.skill_ids_for_identity(&"swordsman", &"defender")
	var berserker_ids := catalog.skill_ids_for_identity(&"swordsman", &"berserker")
	var geometer_ids := catalog.skill_ids_for_identity(&"mage", &"mg_ar")
	_check(&"slash" in base_ids and &"defender_entry" not in base_ids and &"berserker_entry" not in base_ids, "unevolved identity receives only its base library")
	_check(&"slash" in defender_ids and &"defender_entry" in defender_ids and &"defender_guard" in defender_ids and &"berserker_entry" not in defender_ids and &"fireball" not in defender_ids and &"geometer_entry" not in defender_ids, "Defender resolves base plus its own exclusive library")
	_check(&"slash" in berserker_ids and &"berserker_entry" in berserker_ids and &"defender_entry" not in berserker_ids, "sibling branch cannot inherit Defender skills")
	_check(&"fireball" in geometer_ids and &"geometer_entry" in geometer_ids and &"double_shot" not in geometer_ids and &"slash" not in geometer_ids, "directional Mage-Archer identity retains Mage origin without Archer inheritance")
	_check(catalog.skill_ids_for_identity(&"archer", &"mg_ar").is_empty() and not catalog.skill_is_allowed(&"double_shot", &"archer", &"mg_ar") and catalog.skill_ids_for_identity(&"invalid").is_empty(), "invalid origin and cross-origin identity cannot resolve a library")
	defender_ids.clear()
	_check(&"defender_entry" in catalog.skill_ids_for_identity(&"swordsman", &"defender"), "returned library is isolated from callers")

	var profile := ProfileState.new(PROFILE_ID)
	var character_id := IdentityIds.character_id(PROFILE_ID, 1)
	var character := CharacterState.new(character_id, "Fronteira E05", &"swordsman")
	character.base_xp_total = ProgressionRules.EVOLUTION_MIN_BASE_XP
	character.job_xp_total = ProgressionRules.EVOLUTION_MIN_JOB_XP
	character.evolution_id = &"defender"
	character.purchased_skill_ranks[&"slash"] = 1
	character.presets[0]["active_slots"][0] = &"slash"
	character.presets[0]["active_slots"][1] = &"defender_entry"
	profile.characters.append(character)
	profile.selected_character_id = character_id
	profile.next_character_counter = 2
	var committed := ProfileStore.new(directory, catalog).commit(profile)
	_check(committed["ok"], "fixture persists with the existing schema and catalog versions")
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var opened := facade.open_profile()
	var preview := facade.build_preview(character_id)
	var options := facade.available_build_options(character_id)
	var progression := facade.progression_skill_options(character_id)
	_check(opened["ok"] and preview["ok"] and options["ok"] and progression["ok"], "reloaded profile exposes preview and build queries")
	var snapshot: BuildSnapshot = preview["snapshot"]
	_check(snapshot.base_class_id == &"swordsman" and snapshot.evolution_id == &"defender" and snapshot.library_skill_ids == catalog.skill_ids_for_identity(&"swordsman", &"defender"), "preview snapshot captures origin, evolution and resolved library")
	_check(snapshot.skill_ranks.get(&"slash", 0) == 1 and snapshot.skill_ranks.get(&"defender_entry", 0) == 1 and not snapshot.skill_ranks.has(&"berserker_entry") and options["active_skills"].has(&"defender_entry") and not options["active_skills"].has(&"berserker_entry"), "preview and preset query use only learned ranks of the current identity")
	_check(_option(progression["skills"], &"defender_entry")["available"] and not _option(progression["skills"], &"berserker_entry")["available"], "progression keeps future-branch visibility while marking only the current branch available")
	var started := facade.start_run("e05-sp1-start", facade.current_profile().revision)
	_check(started["ok"], "ready fixture starts a run")
	var state: RunState = started["run_state"]
	_check(state.class_id == &"swordsman" and state.build_snapshot.evolution_id == &"defender" and state.build_snapshot.library_skill_ids == snapshot.library_skill_ids and state.skill_levels == snapshot.skill_ranks, "runtime state retains the copied identity and rank parity without reclassing the base actor")
	snapshot.library_skill_ids.clear()
	_check(&"defender_entry" in state.build_snapshot.library_skill_ids, "run snapshot is isolated from preview mutation")
	var navigation := ArenaNavigation.new()
	navigation.configure(Rect2(0, 0, 1000, 600), [], 20.0)
	var actor := PlayerActor.new()
	actor.configure(navigation, state)
	root.add_child(actor)
	actor.set_process(false)
	_check(actor.class_id == &"swordsman" and actor.available_skill_ids() == [&"slash"] and actor.skill_rank(&"defender_entry") == 1, "HUD/runtime skill source keeps base dispatch and does not expose fixture-only skills without concrete definitions")
	state.build_snapshot.active_slots[2] = &"fireball"
	state.skill_levels[&"fireball"] = 1
	_check(actor.available_skill_ids() == [&"slash"], "runtime/HUD source rejects a foreign equipped skill even when a concrete base definition and rank are injected")
	actor.queue_free()
	await process_frame
	_cleanup_directory()
	print("E05-SP1 fronteira de identidade: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _catalog() -> ProfileCatalog:
	return ProfileCatalog.pilot({}, {
		&"defender_entry": _skill(&"swordsman", &"defender", 1),
		&"defender_guard": _skill(&"swordsman", &"defender", 0),
		&"berserker_entry": _skill(&"swordsman", &"berserker", 1),
		&"geometer_entry": _skill(&"mage", &"mg_ar", 1),
	}, {
		&"defender": {"entry_skill_id": &"defender_entry", "exclusive_skill_ids": [&"defender_entry", &"defender_guard"], "content_ready": true},
		&"berserker": {"entry_skill_id": &"berserker_entry", "exclusive_skill_ids": [&"berserker_entry"], "content_ready": true},
		&"mg_ar": {"entry_skill_id": &"geometer_entry", "exclusive_skill_ids": [&"geometer_entry"], "content_ready": false},
	})

func _skill(origin: StringName, evolution: StringName, free_rank: int) -> Dictionary:
	return {
		"allowed_base_classes": [origin],
		"category": ProfileCatalog.ACTIVE,
		"wallet": ProfileCatalog.EVOLUTION_WALLET,
		"free_rank": free_rank,
		"max_purchased_rank": 4 if free_rank == 1 else 5,
		"required_evolution_id": evolution,
		"rank_requirements": {1: {"job_level": 20, "skill_ranks": {}}} if free_rank == 1 else {},
	}

func _option(options: Array, skill_id: StringName) -> Dictionary:
	for option: Dictionary in options:
		if option["skill_id"] == skill_id:
			return option
	return {}

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _cleanup_directory() -> void:
	if not DirAccess.dir_exists_absolute(directory):
		return
	for file_name: String in DirAccess.get_files_at(directory):
		DirAccess.remove_absolute(directory.path_join(file_name))
	DirAccess.remove_absolute(directory)
