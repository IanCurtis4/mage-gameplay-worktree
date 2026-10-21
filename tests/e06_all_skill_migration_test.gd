extends SceneTree
const H = preload("res://tests/fixtures/e07/f2/confirmed_history.gd")
## Catalog 13 is validated before catalog 14 refunds; references survive disabled.

const PROFILE_ID := "123e4567-e89b-42d3-a456-426614174390"
var checks := 0
var failures := 0

class FailingStore:
	extends ProfileStore
	var stage: StringName = &""
	func _should_fail(candidate: StringName) -> bool:
		return candidate == stage and not stage.is_empty()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var old := catalog.pre_all_skill_dependencies_catalog()
	_check(old.is_valid() and catalog.is_valid(), "both catalog authorities are valid")
	var mage := _character(&"mage", &"elementalist", 1)
	mage.granted_skill_ranks[&"fireball"] = 1
	mage.granted_skill_ranks[&"fire_wall"] = 1
	mage.granted_skill_ranks[&"mage_mana_regeneration"] = 1
	_buy(mage, old, &"electric_discharge", 2)
	_buy(mage, old, &"lightning_wall", 2)
	_buy(mage, old, &"fire_spear", 2)
	_buy(mage, old, &"elementalist_glacial_ring", 2)
	mage.presets[0]["active_slots"][0] = &"electric_discharge"
	mage.presets[1]["active_slots"][0] = &"lightning_wall"
	mage.action_slots = ActionBarLayout.empty()
	mage.action_slots[0] = ActionBarLayout.entry(&"lightning_wall", 2)
	mage.action_slots[23] = &"elementalist_glacial_ring"
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(mage)
	profile.next_character_counter = 2
	profile.selected_character_id = mage.character_id
	var encoded := ProfileCodec.encode(profile, old)
	if not encoded["ok"]:
		push_error("catalog 13 fixture: %s" % str(encoded))
	_check(encoded["ok"], "legal catalog 13 fixture encodes")
	if not encoded["ok"]:
		_finish()
		return
	var raw: Dictionary = H.legacy_envelope(encoded["data"])
	raw["schema_version"] = 6
	for entry: Dictionary in raw["characters"]: entry.erase("admin_skills_unlocked")
	raw["catalog_version"] = 13
	var text := JSON.stringify(raw)
	var migrated := H.decode_confirmed(text, catalog)
	_check(migrated.get("ok", false) and migrated.get("migration_kind", &"") == &"all_skill_dependencies_v1", "catalog 13 migrates with dedicated kind")
	if not migrated.get("ok", false):
		_finish()
		return
	var result: ProfileState = migrated["profile"]
	var restored: CharacterState = result.characters[0]
	var receipt: Dictionary = result.extension_fields["all_skill_dependencies_migration"]
	_check(receipt["characters"].size() == 1 and receipt["characters"][0]["base_refund"] == 6 and receipt["characters"][0]["evolution_refund"] == 2, "separate wallets refund purchased ranks")
	_check(restored.purchased_skill_ranks.is_empty() and restored.granted_skill_ranks[&"fireball"] == 1, "transitive purchases disappear, legitimate grant remains")
	_check(restored.action_slots[0] == mage.action_slots[0] and restored.action_slots[23] == mage.action_slots[23] and restored.presets == mage.presets, "24-slot references and both presets remain")
	_check(restored.base_xp_total == mage.base_xp_total and restored.job_xp_total == mage.job_xp_total and restored.character_id == mage.character_id, "identity and XP remain")
	var current := ProfileCodec.encode(result, catalog)
	_check(current.get("ok", false) and current["data"]["catalog_version"] == 14, "disabled references encode in catalog 14")
	if current.get("ok", false):
		var again := H.decode_confirmed(current["text"], catalog)
		_check(again.get("ok", false) and not again.get("migrated", false) and again["profile"].characters[0].action_slots == restored.action_slots, "catalog 14 roundtrip is idempotent")
	var forged := raw.duplicate(true)
	forged["characters"][0]["purchased_skill_ranks"]["lightning_wall"] = 99
	_check(not H.decode_confirmed(JSON.stringify(forged), catalog)["ok"], "invalid catalog 13 purchase is rejected before refund")
	forged = raw.duplicate(true)
	forged["characters"][0]["action_slots"][5] = "soul_impact"
	_check(not H.decode_confirmed(JSON.stringify(forged), catalog)["ok"], "catalog 13 cannot smuggle unlearned reference")
	forged = raw.duplicate(true)
	forged["catalog_version"] = 15
	_check(not H.decode_confirmed(JSON.stringify(forged), catalog)["ok"], "future catalog is rejected")
	_older_shortcut_migration(catalog)
	_store(text, catalog)
	_finish()

func _older_shortcut_migration(catalog: ProfileCatalog) -> void:
	var previous := catalog.pre_all_skill_dependencies_catalog().pre_swordsman_cluster_catalog()
	var defender := _character(&"swordsman", &"defender", 1)
	_buy(defender, previous, &"defender_anchor", 2)
	defender.action_slots = ActionBarLayout.empty()
	defender.action_slots[0] = ActionBarLayout.entry(&"defender_anchor", 2)
	defender.action_slots[23] = &"defender_anchor"
	defender.presets[0]["active_slots"][0] = &"defender_anchor"
	defender.presets[1]["active_slots"][4] = &"defender_anchor"
	var profile := ProfileState.new(PROFILE_ID)
	profile.characters.append(defender)
	profile.next_character_counter = 2
	profile.selected_character_id = defender.character_id
	var encoded := ProfileCodec.encode(profile, previous)
	_check(encoded.get("ok", false), "catalog 12 fixture validates under its original gates")
	if not encoded.get("ok", false):
		return
	var raw: Dictionary = H.legacy_envelope(encoded["data"])
	raw["schema_version"] = 6
	for entry: Dictionary in raw["characters"]: entry.erase("admin_skills_unlocked")
	raw["catalog_version"] = 12
	var decoded := H.decode_confirmed(JSON.stringify(raw), catalog)
	_check(decoded.get("ok", false), "catalog 12 follows historical validation and migration")
	if not decoded.get("ok", false):
		return
	var restored: CharacterState = decoded["profile"].characters[0]
	_check(decoded["migration_kind"] == &"swordsman_clusters_v1" and decoded["migration_kinds"] == [&"admin_skills_v1", &"swordsman_clusters_v1", &"all_skill_dependencies_v1"], "older migration keeps durable provenance and records all stages")
	_check(restored.purchased_skill_ranks.is_empty() and decoded["migration_removals"][0]["evolution_refund"] == 2, "older incompatible purchase is refunded and reported")
	_check(restored.action_slots == defender.action_slots and restored.presets == defender.presets, "older preset and both action rank forms remain disabled")
	_check(decoded["profile"].extension_fields["swordsman_skill_tree_migration"]["characters"][0]["cleared_action_slots"].is_empty(), "historical receipt does not claim preserved slots were cleared")
	var saved := ProfileCodec.encode(decoded["profile"], catalog)
	_check(saved.get("ok", false) and H.decode_confirmed(saved.get("text", ""), catalog).get("ok", false), "older disabled reference survives catalog 14 roundtrip")

func _character(origin: StringName, evolution: StringName, index: int) -> CharacterState:
	var character := CharacterState.new(IdentityIds.character_id(PROFILE_ID, index), "Migração", origin)
	character.evolution_id = evolution
	character.base_xp_total = ProgressionRules.MAX_BASE_XP
	character.job_xp_total = ProgressionRules.MAX_JOB_XP
	return character

func _buy(character: CharacterState, catalog: ProfileCatalog, id: StringName, rank: int) -> void:
	while int(catalog.effective_skill_ranks(character.base_class_id, character.evolution_id, character.purchased_skill_ranks, character.granted_skill_ranks).get(id, 0)) < rank:
		var purchase := CharacterProgression.learn_skill(character, catalog, id)
		_check(purchase["ok"], "fixture buys %s" % id)
		if not purchase["ok"]:
			return

func _store(text: String, catalog: ProfileCatalog) -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/all_skill_migration_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(ProfileStore.PRIMARY_FILE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	var store := FailingStore.new(directory, catalog)
	store.stage = &"replace"
	var failed := H.load_confirmed(store)
	_check(not failed.get("ok", false) and FileAccess.get_file_as_string(path) == text, "failed replace preserves historical primary")
	# Pending is evidence of an interrupted transaction; recovery must not discard it.
	_check(FileAccess.file_exists(directory.path_join(ProfileStore.PENDING_FILE)), "failed replace retains pending")
	DirAccess.remove_absolute(directory.path_join(ProfileStore.PENDING_FILE))
	store.stage = &""
	var loaded := H.load_confirmed(store)
	_check(loaded.get("ok", false) and loaded.get("migrated", false), "durable migration commits")
	if loaded.get("ok", false):
		_check(loaded["profile"].revision == 1 and FileAccess.get_file_as_string(directory.path_join(ProfileStore.BACKUP_FILE)) == text, "revision advances once and original backup survives")
		var reopened := H.load_confirmed(store)
		_check(reopened.get("ok", false) and not reopened.get("migrated", false), "durable reload does not refund again")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _finish() -> void:
	print("E06 all-skill migration: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
