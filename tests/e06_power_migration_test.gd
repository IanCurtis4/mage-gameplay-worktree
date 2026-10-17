extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_power/migration_%d" % Time.get_ticks_usec())
	var catalog := ProfileCatalog.pilot()
	var store := ProfileStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	_check(facade.create_character("create", 0, "Preservado", &"mage")["ok"], "source character")
	var profile := facade.current_profile()
	for id: StringName in catalog.equipment_ids():
		# Historical catalog-10 contained only the preceding 39 recipes.
		if catalog.equipment_metadata(id).has("allowed_identities"): continue
		if profile.first_instance_for_definition(id).is_empty(): profile.add_equipment_instance(id, catalog.equipment_metadata(id))
	var original := ProfileCodec.encode(profile)
	_check(original["ok"], "source current codec")
	var legacy: Dictionary = original["data"].duplicate(true)
	legacy["schema_version"] = 3; legacy["catalog_version"] = 10
	for fixture_character: Dictionary in legacy["characters"]: fixture_character.erase("admin_skills_unlocked")
	legacy.erase("card_inventory")
	for record: Dictionary in legacy["equipment_instances"]:
		record.erase("recipe_revision_id"); record.erase("power_ruleset_id")
		record["item_level"] = 30
	var text := JSON.stringify(legacy)
	var decoded := ProfileCodec.decode(text, catalog)
	_check(decoded["ok"] and decoded.get("migrated", false), "schema3catalog10 migrates explicitly")
	if not decoded["ok"]: print(decoded); quit(1); return
	var migrated: ProfileState = decoded["profile"]
	_check(migrated.characters[0].equipped == profile.characters[0].equipped and migrated.characters[0].presets == profile.characters[0].presets, "all IDs/layout/preset references preserved")
	_check(migrated.characters[0].base_xp_total == profile.characters[0].base_xp_total and migrated.characters[0].job_xp_total == profile.characters[0].job_xp_total, "XP untouched")
	var effects := BuildContentLoader.pilot()
	for instance: EquipmentInstance in migrated.equipment_instances.values():
		_check(instance.power_ruleset_id == &"legacy_unscaled" and instance.recipe_revision_id == &"catalog_v1" and instance.item_level == 30, "all old instances frozen including high ilvl")
		var item := effects.get_definition(&"equipment", instance.definition_id) as EquipmentDefinition
		for effect: EffectDefinition in item.effects:
			_check(EquipmentPowerRules.modifier_magnitude(effect, instance, item) == effect.value_at(1), "legacy exact original values")
	var encoded := ProfileCodec.encode(migrated, catalog)
	_check(encoded["ok"] and encoded["data"]["schema_version"] == 7 and encoded["data"]["catalog_version"] == 14, "new envelope schema6catalog14")
	var again := ProfileCodec.decode(encoded["text"], catalog)
	_check(again["ok"] and not again.get("migrated", true), "migration is not reapplied")
	var invalid: Dictionary = encoded["data"].duplicate(true)
	invalid["equipment_instances"][0].erase("power_ruleset_id")
	_check(not ProfileCodec.decode(JSON.stringify(invalid), catalog)["ok"], "schema4 missing refs rejected")
	invalid = legacy.duplicate(true)
	invalid["equipment_instances"][0]["power_ruleset_id"] = "equipment_growth_v1"
	_check(not ProfileCodec.decode(JSON.stringify(invalid), catalog)["ok"], "historical envelope cannot smuggle growth")
	invalid = encoded["data"].duplicate(true)
	invalid["equipment_instances"][0]["recipe_revision_id"] = "unknown_revision"
	_check(not ProfileCodec.decode(JSON.stringify(invalid), catalog)["ok"], "unknown revision rejected")
	var meta := catalog.equipment_metadata(&"arena_warden_mail")
	meta["power_ruleset_id"] = &"equipment_growth_v1"; meta["item_level"] = 30
	var added := migrated.add_equipment_instance(&"arena_warden_mail", meta)
	_check(added["ok"], "new exemplar growth explicit")
	var growth: EquipmentInstance = migrated.equipment_instances[added["instance_id"]]
	var definition := effects.get_definition(&"equipment", growth.definition_id) as EquipmentDefinition
	_check(EquipmentPresentation.instance_description(definition, growth).contains("8.64"), "tooltip uses canonical growth value")
	_check(store.commit(migrated)["ok"], "current growth saved")
	var reopened := store.load_profile()
	_check(reopened["ok"] and reopened["profile"].equipment_instances[growth.instance_id].to_record() == growth.to_record(), "growth refs stable after reopen")
	# Real store migration protects original bytes in backup and pending does not overwrite.
	var second := directory.path_join("historical")
	DirAccess.make_dir_recursive_absolute(second)
	var file := FileAccess.open(second.path_join("profile.json"), FileAccess.WRITE); file.store_string(text); file.close()
	var old_store := ProfileStore.new(second, catalog)
	var loaded := old_store.load_profile()
	_check(loaded["ok"] and loaded.get("migrated", false), "historical store performs durable migration")
	_check(FileAccess.get_file_as_string(second.path_join("profile.backup.json")) == text, "historical original backup byte-preserved")
	var pending_dir := directory.path_join("pending")
	DirAccess.make_dir_recursive_absolute(pending_dir)
	file = FileAccess.open(pending_dir.path_join("profile.json"), FileAccess.WRITE); file.store_string(text); file.close()
	file = FileAccess.open(pending_dir.path_join("profile.pending.json"), FileAccess.WRITE); file.store_string("pending-user-bytes"); file.close()
	loaded = ProfileStore.new(pending_dir, catalog).load_profile()
	_check(not loaded["ok"] and loaded.get("read_only", false), "pending blocks migration")
	_check(FileAccess.get_file_as_string(pending_dir.path_join("profile.json")) == text and FileAccess.get_file_as_string(pending_dir.path_join("profile.pending.json")) == "pending-user-bytes", "pending and original never overwritten")
	var incompatible := legacy.duplicate(true)
	incompatible["equipment_instances"][0]["quality_id"] = "future_quality"
	var bad_text := JSON.stringify(incompatible)
	var bad_decode := ProfileCodec.decode(bad_text, catalog)
	_check(not bad_decode["ok"] and bad_decode.get("catalog_incompatible", false), "old unknown metadata is incompatible, not repairable corruption")
	var protected_dir := directory.path_join("incompatible")
	DirAccess.make_dir_recursive_absolute(protected_dir)
	file = FileAccess.open(protected_dir.path_join("profile.json"), FileAccess.WRITE); file.store_string(bad_text); file.close()
	file = FileAccess.open(protected_dir.path_join("profile.backup.json"), FileAccess.WRITE); file.store_string(encoded["text"]); file.close()
	loaded = ProfileStore.new(protected_dir, catalog).load_profile()
	_check(not loaded["ok"] and loaded.get("read_only", false), "incompatible historical primary blocks backup recovery")
	_check(FileAccess.get_file_as_string(protected_dir.path_join("profile.json")) == bad_text and FileAccess.get_file_as_string(protected_dir.path_join("profile.backup.json")) == encoded["text"], "incompatible primary and good backup preserved byte for byte")
	print("E06 power migration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
