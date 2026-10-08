extends SceneTree

class FailingStore:
	extends ProfileStore
	var failure_stage: StringName = &""
	func _should_fail(stage: StringName) -> bool:
		return stage == failure_stage

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174000"
var root_directory: String
var checks := 0
var failures := 0

func _initialize() -> void:
	root_directory = ProjectSettings.globalize_path("res://.godot/verification/stat_migration_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()])
	_test_all_worst_distributions()
	_test_known_envelopes()
	_test_store_migration_and_respec()
	_test_failure_backup_pending_future()
	print("Stat threshold migration: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _test_all_worst_distributions() -> void:
	var file := FileAccess.open("res://docs/fixtures/stat_threshold_migration.csv", FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 7: continue
		var profile := _profile(StringName(line[0]), int(line[1]))
		var allocation := line[6].split("/")
		for index: int in IdentityIds.attribute_ids().size():
			profile.characters[0].attribute_allocations[IdentityIds.attribute_ids()[index]] = int(allocation[index])
		var text := _old_text(profile)
		var result := ProfileCodec.decode(text, ProfileCatalog.pilot())
		_check(result.get("ok",false) and result.get("migrated",false), "worst distribution migrates for every origin/level")
		if not result.get("ok",false): continue
		var current: ProfileState = result["profile"]
		var character := current.characters[0]
		_check(character.attribute_allocations == profile.characters[0].attribute_allocations and character.base_xp_total == profile.characters[0].base_xp_total, "migration preserves exact XP and investments")
		_check(ProgressionRules.attribute_points_spent(character.attribute_allocations, character.base_class_id) == int(line[3]), "runtime migrated price matches independent worst-case oracle")
		_check(ProgressionRules.attribute_points_available(character.base_xp_total,character.attribute_allocations,character.base_class_id) >= 0, "no migration debt")
	file.close()

func _test_known_envelopes() -> void:
	for version: int in range(1,7):
		var profile := _profile(&"swordsman",3)
		profile.characters[0].attribute_allocations[&"str"] = 6
		var result := ProfileCodec.decode(_old_text(profile,version), ProfileCatalog.pilot())
		_check(result.get("ok",false) and result.get("migrated",false), "each known catalog/ruleset pair migrates explicitly")
		if not result.get("ok",false): continue
		var grants: Dictionary = result["profile"].characters[0].granted_skill_ranks
		_check(grants == {&"slash":1,&"dash":1,&"swordsman_resistance":1} if version == 1 else grants.is_empty(), "old learning rights preserved only where specified")
		var encoded := ProfileCodec.encode(result["profile"], ProfileCatalog.pilot())
		_check(encoded["ok"] and not ProfileCodec.decode(encoded["text"],ProfileCatalog.pilot())["migrated"], "conversion idempotent on reload")
		var bad_profile := _profile(&"swordsman",3)
		bad_profile.characters[0].attribute_allocations[&"str"] = 7 # New budget fits, old6 increments does not.
		var invalid := ProfileCodec.decode(_old_text(bad_profile,version),ProfileCatalog.pilot())
		_check(not invalid["ok"] and invalid["error_code"] == &"overspent_attributes", "larger budget cannot certify illegal old investment")
	var unknown: Dictionary = JSON.parse_string(_old_text(_profile(&"swordsman",3)))
	unknown["ruleset_id"] = "unknown_rules"
	_check(not ProfileCodec.decode(JSON.stringify(unknown),ProfileCatalog.pilot())["ok"], "unknown old pair rejected")
	unknown["catalog_version"] = ProfileState.CATALOG_VERSION
	unknown["ruleset_id"] = ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	_check(not ProfileCodec.decode(JSON.stringify(unknown),ProfileCatalog.pilot())["ok"], "old rules never silently assigned to new catalog")

func _test_store_migration_and_respec() -> void:
	var directory := _directory("whole_profile")
	var profile := _profile(&"swordsman",30)
	var character := profile.characters[0]
	character.evolution_id = &"berserker"
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	character.attribute_allocations[&"str"] = 52
	character.attribute_allocations[&"vit"] = 35
	character.purchased_skill_ranks = {&"slash":3,&"blood_thirst":1,&"berserker_execution":1}
	character.action_slots[0] = &"slash"
	character.action_slots[7] = &"berserker_execution"
	character.extension_fields["note"] = ["preservar"]
	profile.extension_fields["note"] = {"keep":true}
	profile.next_run_counter = 9
	var alt := CharacterState.new(IdentityIds.character_id(PROFILE_ID,2),"Alt",&"mage")
	profile.characters.append(alt)
	profile.next_character_counter = 3
	var old_text := _old_text(profile)
	_write(directory.path_join(ProfileStore.PRIMARY_FILE),old_text)
	var store := ProfileStore.new(directory,ProfileCatalog.pilot())
	var migrated := store.load_profile()
	_check(migrated.get("ok",false) and migrated.get("warning",&"") == &"profile_migrated", "durable migration reports explicit warning")
	if not migrated.get("ok",false): return
	_check(FileAccess.get_file_as_string(directory.path_join(ProfileStore.BACKUP_FILE)) == old_text, "backup keeps original bytes before changing envelope")
	var current: ProfileState = migrated["profile"]
	_check(current.revision == profile.revision+1 and current.next_run_counter == 9 and current.next_character_counter == 3 and current.selected_character_id == profile.selected_character_id, "migration conserves IDs/counters/selection and increments revision once")
	var kept := current.characters[0]
	_check(kept.attribute_allocations == character.attribute_allocations and kept.purchased_skill_ranks == character.purchased_skill_ranks and kept.action_slots == character.action_slots and kept.presets == character.presets and kept.equipped == character.equipped and kept.extension_fields == character.extension_fields and current.extension_fields == profile.extension_fields, "migration preserves skills bars presets equips and extensions")
	var facade := ProfileFacade.new(store)
	_check(facade.open_profile()["ok"], "migrated store opens facade normally")
	var revision := facade.current_profile().revision
	var purchase := facade.allocate_attributes("first-new-buy",revision,kept.character_id,{&"dex":1})
	_check(purchase["ok"] and purchase["spent"] == 2, "first mutation after migration respects new canonical cost and old backup guard")
	var refund := facade.respec_attributes("new-refund",revision+1,kept.character_id)
	_check(refund["ok"] and refund["refunded"] == 389 and refund["progression"]["attribute_points_available"] == 458, "current costs refund exactly without legacy count credit")
	var replay := facade.respec_attributes("new-refund",revision+1,kept.character_id)
	_check(not replay["ok"] and replay["error_code"] == &"stale_revision", "respec replay cannot duplicate wallet")
	var again := ProfileFacade.new(ProfileStore.new(directory,ProfileCatalog.pilot()))
	_check(again.open_profile()["ok"] and again.progression_summary(kept.character_id)["attribute_points_available"] == 458 and again.current_profile().characters[1].base_xp_total == 0, "reload and respec keep derived wallet and isolate alt")
	var started := again.start_run("active-migration-fixture", again.current_profile().revision)
	_check(started["ok"], "isolated durable active-run fixture starts")
	var active_profile := again.current_profile()
	var active_dir := _directory("active_session")
	_write(active_dir.path_join(ProfileStore.PRIMARY_FILE), _old_text(active_profile))
	var active_migrated := ProfileStore.new(active_dir, ProfileCatalog.pilot()).load_profile()
	_check(active_migrated["ok"] and active_migrated["profile"].reward_session == active_profile.reward_session and active_migrated["profile"].next_run_counter == active_profile.next_run_counter and active_migrated["profile"].lifetime_stats == active_profile.lifetime_stats, "envelope migration preserves active reward cursor, run counters and lifetime totals")

func _test_failure_backup_pending_future() -> void:
	var profile := _profile(&"archer",18)
	profile.characters[0].attribute_allocations[&"dex"] = 50
	profile.characters[0].attribute_allocations[&"str"] = 1
	var old_text := _old_text(profile)
	for stage: StringName in [&"write_pending",&"validate_pending",&"backup",&"replace"]:
		var directory := _directory(str(stage))
		_write(directory.path_join(ProfileStore.PRIMARY_FILE),old_text)
		var store := FailingStore.new(directory,ProfileCatalog.pilot())
		store.failure_stage = stage
		var result := store.load_profile()
		_check(not result["ok"] and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PRIMARY_FILE)) == old_text, "failed migration leaves original primary intact at each write stage")
		if stage != &"write_pending":
			var pending_text := FileAccess.get_file_as_string(directory.path_join(ProfileStore.PENDING_FILE))
			var retry := ProfileStore.new(directory,ProfileCatalog.pilot()).load_profile()
			_check(not retry["ok"] and retry.get("read_only",false) and FileAccess.get_file_as_string(directory.path_join(ProfileStore.PENDING_FILE)) == pending_text, "uncertain migration pending preserved, never overwritten or promoted")
	var backup_dir := _directory("recovery_backup")
	_write(backup_dir.path_join(ProfileStore.PRIMARY_FILE),"{broken")
	_write(backup_dir.path_join(ProfileStore.BACKUP_FILE),old_text)
	var recovered := ProfileStore.new(backup_dir,ProfileCatalog.pilot()).load_profile()
	_check(recovered.get("ok",false) and recovered.get("recovered",false) and recovered.get("warning",&"") == &"profile_migrated_from_backup", "recognized old backup recovers and migrates explicitly: %s" % recovered)
	for corrupt_primary: bool in [false, true]:
		var guarded_dir := _directory("backup_pending_%s" % corrupt_primary)
		_write(guarded_dir.path_join(ProfileStore.BACKUP_FILE), old_text)
		_write(guarded_dir.path_join(ProfileStore.PENDING_FILE), "unconfirmed transaction evidence")
		if corrupt_primary:
			_write(guarded_dir.path_join(ProfileStore.PRIMARY_FILE), "{broken")
		var blocked_pending := ProfileStore.new(guarded_dir, ProfileCatalog.pilot()).load_profile()
		_check(not blocked_pending["ok"] and blocked_pending.get("read_only", false), "backup recovery cannot replace an unconfirmed pending transaction")
		_check(FileAccess.get_file_as_string(guarded_dir.path_join(ProfileStore.PENDING_FILE)) == "unconfirmed transaction evidence" and FileAccess.get_file_as_string(guarded_dir.path_join(ProfileStore.BACKUP_FILE)) == old_text, "recovery preserves pending and backup bytes")
		_check(FileAccess.get_file_as_string(guarded_dir.path_join(ProfileStore.PRIMARY_FILE)) == "{broken" if corrupt_primary else not FileAccess.file_exists(guarded_dir.path_join(ProfileStore.PRIMARY_FILE)), "guarded recovery neither replaces nor creates primary")
	var only_pending := _directory("pending_only")
	_write(only_pending.path_join(ProfileStore.PENDING_FILE),old_text)
	_check(not ProfileStore.new(only_pending,ProfileCatalog.pilot()).load_profile()["ok"] and not FileAccess.file_exists(only_pending.path_join(ProfileStore.PRIMARY_FILE)), "orphan old pending never promoted")
	for artifact: String in [ProfileStore.PRIMARY_FILE,ProfileStore.BACKUP_FILE]:
		var directory := _directory("future_"+artifact)
		var future: Dictionary = JSON.parse_string(old_text)
		future["catalog_version"] = 99
		var future_text := JSON.stringify(future)
		_write(directory.path_join(ProfileStore.PRIMARY_FILE),old_text)
		_write(directory.path_join(ProfileStore.BACKUP_FILE),old_text)
		_write(directory.path_join(artifact),future_text)
		var blocked := ProfileStore.new(directory,ProfileCatalog.pilot()).load_profile()
		_check(not blocked["ok"] and blocked.get("read_only",false) and FileAccess.get_file_as_string(directory.path_join(artifact)) == future_text, "future primary or backup blocks migration without overwrite")

func _profile(origin: StringName, level: int) -> ProfileState:
	var profile := ProfileState.new(PROFILE_ID)
	profile.revision = 5
	profile.next_character_counter = 2
	profile.selected_character_id = IdentityIds.character_id(PROFILE_ID,1)
	var character := CharacterState.new(profile.selected_character_id,"Referência",origin)
	character.base_xp_total = 100*(level-1) + 25*(level-1)*(level-2)/2
	character.action_slots = ActionBarLayout.empty()
	profile.characters.append(character)
	return profile

func _old_text(profile: ProfileState, version: int = 6) -> String:
	var encoded := ProfileCodec.encode(profile,ProfileCatalog.pilot())
	_check(encoded["ok"], "fixture new profile valid before changing envelope")
	if not encoded["ok"]: return "invalid fixture"
	var data: Dictionary = encoded["data"]
	data["catalog_version"] = version
	data["ruleset_id"] = "e00_v1" if version == 1 else ProfileCodec.PRE_THRESHOLDS_RULESET_ID
	if version == 1:
		for raw: Dictionary in data["characters"]:
			raw.erase("granted_skill_ranks")
	return JSON.stringify(data)

func _directory(name: String) -> String:
	var result := root_directory.path_join(name)
	DirAccess.make_dir_recursive_absolute(result)
	return result

func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(content)
	file.close()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
