extends SceneTree

const NEW_PROFILE_ID := "123e4567-e89b-42d3-a456-426614174010"
const LEGACY_PROFILE_ID := "123e4567-e89b-42d3-a456-426614174011"

var checks := 0
var failures := 0
var root_directory: String

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/e04_learn_from_zero")
	_cleanup_directory(root_directory)
	DirAccess.make_dir_recursive_absolute(root_directory)
	_check_new_character_flow()
	_check_catalog_v1_migration_and_respec()
	_cleanup_directory(root_directory)
	print("E04 aprendizado do zero/migração: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_new_character_flow() -> void:
	var directory := root_directory.path_join("new_character")
	_prepare_directory(directory)
	var facade := ProfileFacade.new(
		ProfileStore.new(directory),
		ProfileRewardResolver.pilot_progression()
	)
	var opened := facade.open_profile()
	var created := facade.create_character("create-zero", opened["profile"].revision, "Zero", &"swordsman")
	var character: CharacterState = created["profile"].character_by_id(created["character_id"])
	var progression := facade.progression_summary(character.character_id)
	_check(
		created["ok"]
		and character.granted_skill_ranks.is_empty()
		and character.purchased_skill_ranks.is_empty()
		and progression["effective_skill_ranks"].is_empty(),
		"new character starts with every base skill at rank zero"
	)
	_check(
		character.presets[0]["active_slots"] == [null, null, null, null, null]
		and character.presets[0]["passive_slots"] == [null, null],
		"new character keeps both preset skill bars empty"
	)

	var started := facade.start_run("empty-bar-run", created["new_revision"])
	_check(
		started["ok"]
		and started["run_state"].skill_levels.is_empty()
		and started["run_state"].build_snapshot.active_slots == [null, null, null, null, null],
		"empty skill bar starts a run and produces an empty skill snapshot"
	)
	var rewarded := facade.grant_reward(
		"first-crystal",
		started["new_revision"],
		started["run_id"],
		1,
		&"encounter_one"
	)
	var after_reward := facade.progression_summary(character.character_id)
	_check(
		rewarded["ok"]
		and rewarded["applied_reward"]["job_xp"] == 80
		and after_reward["job_level"] == 2
		and after_reward["base_skill_points_available"] == 1,
		"first 80-job-XP crystal reaches job level two and unlocks one point"
	)
	var ended := facade.end_run("close-first-run", rewarded["new_revision"], started["run_id"], &"completed")
	var learned := facade.learn_skill("learn-slash", ended["new_revision"], character.character_id, &"slash")
	var learned_character: CharacterState = learned["profile"].character_by_id(character.character_id)
	_check(
		learned["ok"]
		and learned["rank"] == 1
		and learned["progression"]["base_skill_points_spent"] == 1
		and learned["progression"]["base_skill_points_available"] == 0,
		"learning rank one costs exactly one base-skill point"
	)
	_check(
		learned_character.presets[0]["active_slots"] == [null, null, null, null, null],
		"learning a skill does not auto-equip it"
	)
	var no_second_point := facade.learn_skill("learn-slash-again", learned["new_revision"], character.character_id, &"slash")
	_check(not no_second_point["ok"] and no_second_point["error_code"] == &"insufficient_points", "a second rank cannot be bought without a second point")

	var reloaded := ProfileFacade.new(ProfileStore.new(directory), ProfileRewardResolver.pilot_progression())
	var reload_result := reloaded.open_profile()
	var reload_character: CharacterState = reload_result["profile"].character_by_id(character.character_id)
	_check(
		reload_result["ok"]
		and reload_character.purchased_skill_ranks == {&"slash": 1}
		and reload_character.presets[0]["active_slots"] == [null, null, null, null, null],
		"reload preserves the purchase and empty bar independently"
	)
	var second_run := reloaded.start_run("learned-empty-run", reload_result["profile"].revision)
	_check(
		second_run["ok"]
		and second_run["run_state"].skill_levels == {&"slash": 1}
		and second_run["run_state"].build_snapshot.active_slots == [null, null, null, null, null],
		"run snapshot preserves a learned but unequipped skill"
	)
	var second_end := reloaded.end_run("close-second-run", second_run["new_revision"], second_run["run_id"], &"abandoned")
	var respec := reloaded.respec_skills("respec-new", second_end["new_revision"], character.character_id)
	_check(
		respec["ok"]
		and respec["base_refund"] == 1
		and respec["profile"].character_by_id(character.character_id).purchased_skill_ranks.is_empty()
		and respec["progression"]["effective_skill_ranks"].is_empty(),
		"new-character respec refunds only the purchased rank and returns it to zero"
	)

func _check_catalog_v1_migration_and_respec() -> void:
	var directory := root_directory.path_join("legacy_catalog")
	_prepare_directory(directory)
	var legacy_profile := ProfileState.new(LEGACY_PROFILE_ID)
	legacy_profile.revision = 7
	legacy_profile.next_character_counter = 3
	legacy_profile.next_run_counter = 4
	var character_id := IdentityIds.character_id(LEGACY_PROFILE_ID, 1)
	var legacy_character := CharacterState.new(character_id, "Legado", &"swordsman")
	legacy_character.base_xp_total = 250
	legacy_character.job_xp_total = 180
	legacy_character.attribute_allocations[&"str"] = 2
	legacy_character.granted_skill_ranks = {
		&"slash": 1,
		&"dash": 1,
		&"swordsman_resistance": 1,
	}
	legacy_character.purchased_skill_ranks[&"slash"] = 1
	for preset: Dictionary in legacy_character.presets:
		preset["active_slots"][0] = &"slash"
		preset["active_slots"][1] = &"dash"
		preset["passive_slots"][0] = &"swordsman_resistance"
	legacy_profile.characters.append(legacy_character)
	var legacy_mage_id := IdentityIds.character_id(LEGACY_PROFILE_ID, 2)
	var legacy_mage := CharacterState.new(legacy_mage_id, "Maga Legada", &"mage")
	legacy_mage.granted_skill_ranks = {
		&"fireball": 1,
		&"fire_wall": 1,
		&"mage_mana_regeneration": 1,
	}
	for preset: Dictionary in legacy_mage.presets:
		preset["active_slots"][0] = &"fireball"
		preset["active_slots"][1] = &"fire_wall"
		preset["passive_slots"][0] = &"mage_mana_regeneration"
	legacy_profile.characters.append(legacy_mage)
	legacy_profile.selected_character_id = character_id
	var encoded := ProfileCodec.encode(legacy_profile)
	var legacy_data: Dictionary = encoded["data"].duplicate(true)
	legacy_data["catalog_version"] = ProfileCodec.LEGACY_CATALOG_VERSION
	legacy_data["ruleset_id"] = ProfileCodec.LEGACY_RULESET_ID
	for raw_character: Dictionary in legacy_data["characters"]:
		raw_character.erase("granted_skill_ranks")
	var legacy_text := JSON.stringify(legacy_data, "\t")
	_write_text(directory.path_join(ProfileStore.PRIMARY_FILE), legacy_text)

	var store := ProfileStore.new(directory)
	var migrated := store.load_profile()
	var migrated_profile: ProfileState = migrated["profile"]
	var migrated_character: CharacterState = migrated_profile.character_by_id(character_id)
	var summary := CharacterProgression.summary(migrated_character, ProfileCatalog.pilot())
	_check(
		migrated["ok"]
		and migrated["migrated"]
		and migrated_profile.profile_id == LEGACY_PROFILE_ID
		and migrated_profile.revision == 8
		and migrated_profile.next_character_counter == 3
		and migrated_profile.next_run_counter == 4,
		"catalog migration preserves profile identity and counters while committing one revision"
	)
	_check(
		migrated_character.display_name == "Legado"
		and migrated_character.base_xp_total == 250
		and migrated_character.job_xp_total == 180
		and migrated_character.attribute_allocations[&"str"] == 2
		and migrated_character.purchased_skill_ranks == {&"slash": 1},
		"catalog migration preserves character identity, XP, attributes and purchases"
	)
	_check(
		migrated_profile.character_by_id(legacy_mage_id).display_name == "Maga Legada"
		and migrated_profile.character_by_id(legacy_mage_id).granted_skill_ranks == {&"fireball": 1, &"fire_wall": 1, &"mage_mana_regeneration": 1}
		and migrated_profile.character_by_id(legacy_mage_id).presets[0]["active_slots"].slice(0, 2) == [&"fireball", &"fire_wall"],
		"catalog migration preserves the mage legacy kit independently"
	)
	_check(
		migrated_character.granted_skill_ranks == {&"slash": 1, &"dash": 1, &"swordsman_resistance": 1}
		and summary["effective_skill_ranks"] == {&"slash": 2, &"dash": 1, &"swordsman_resistance": 1}
		and summary["base_skill_points_spent"] == 1
		and summary["base_skill_points_available"] == 1,
		"legacy free ranks become non-wallet grants without inflating or spending the wallet"
	)
	_check(
		migrated_character.presets[0]["active_slots"].slice(0, 2) == [&"slash", &"dash"]
		and migrated_character.presets[0]["passive_slots"][0] == &"swordsman_resistance"
		and _read_text(directory.path_join(ProfileStore.BACKUP_FILE)) == legacy_text,
		"migration retains equipped rights and preserves the original catalog-v1 bytes as backup"
	)

	var facade := ProfileFacade.new(ProfileStore.new(directory))
	var opened := facade.open_profile()
	var respec := facade.respec_skills("legacy-respec", opened["profile"].revision, character_id)
	var respec_character: CharacterState = respec["profile"].character_by_id(character_id)
	_check(
		respec["ok"]
		and respec["base_refund"] == 1
		and respec_character.purchased_skill_ranks.is_empty()
		and respec_character.granted_skill_ranks == {&"slash": 1, &"dash": 1, &"swordsman_resistance": 1}
		and respec["progression"]["base_skill_points_available"] == 2,
		"legacy respec refunds only purchases and retains grandfathered rights"
	)
	_check(
		respec_character.presets[0]["active_slots"].slice(0, 2) == [&"slash", &"dash"]
		and respec_character.presets[0]["passive_slots"][0] == &"swordsman_resistance",
		"legacy-granted skills remain legal in presets after respec"
	)
	var final_reload := ProfileStore.new(directory).load_profile()
	_check(
		final_reload["ok"]
		and not final_reload.get("migrated", false)
		and final_reload["profile"].revision == respec["new_revision"],
		"catalog migration is durable and idempotent on later reloads"
	)

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not write test fixture: %s" % path)
		return
	file.store_string(text)
	file.close()

func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text

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
