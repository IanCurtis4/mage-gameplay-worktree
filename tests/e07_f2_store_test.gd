extends "res://tests/fixtures/e07/f2/suite.gd"
func _run() -> void:
	for stage: StringName in [&"", &"write_pending", &"validate_pending", &"backup", &"replace", &"lost_ack"]:
		var f := F.make("migration_store_" + String(stage))
		var store: F.FaultStore = f["store"]
		var text := F.legacy((f["facade"] as ProfileFacade).current_profile())
		var path := String(f["directory"]).path_join(ProfileStore.PRIMARY_FILE)
		F.write(path, text)
		var bytes := FileAccess.get_file_as_bytes(path)
		check(store.load_profile().get("error_code") == &"migration_required" and FileAccess.get_file_as_bytes(path) == bytes, "opening legacy never mutates bytes")
		var preview := F.complete(text)
		check(store.preview_migration(preview["plan"]["destinations"])["plan_digest"] == preview["plan_digest"] and FileAccess.get_file_as_bytes(path) == bytes, "store preview is pure")
		if stage == &"lost_ack": store.lose_ack = true
		else: store.fail_stage = stage
		var result := store.apply_migration(preview["plan"], preview["plan_digest"], "migrate")
		if stage == &"": check(result["ok"], "migration durable success")
		else: check(not result["ok"], "fault is not silently reported as success " + String(stage))
		if stage not in [&"", &"lost_ack"]: check(FileAccess.get_file_as_bytes(path) == bytes, "failure before replace preserves source " + String(stage))
		store.fail_stage = &""
		var retry := store.apply_migration(preview["plan"], preview["plan_digest"], "migrate")
		check(retry["ok"], "same frozen migration retries or reconciles " + String(stage))
		if not retry["ok"]: continue
		var migrated: ProfileState = retry["profile"]
		var opened := ProfileStore.new(f["directory"]).load_profile()
		check(opened["ok"] and opened["profile"].revision == migrated.revision, "restart sees committed migration once")
		check(store.apply_migration(preview["plan"], preview["plan_digest"], "migrate").get("already_applied", false), "replay does not advance revision")
		check(FileAccess.get_sha256(String(f["directory"]).path_join("profile.ownership.%s.json" % text.sha256_text())) == text.sha256_text(), "exact legacy archive survives")
		migrated.settings["fixture_after"] = true
		var archive_path := String(f["directory"]).path_join("profile.ownership.%s.json" % text.sha256_text())
		check(DirAccess.rename_absolute(archive_path, archive_path + ".held") == OK, "archive omission fixture isolates exact original")
		check(store.commit(migrated).get("error_code") == &"recovery_required", "cannot rotate legacy backup without verified archive")
		check(DirAccess.rename_absolute(archive_path + ".held", archive_path) == OK, "exact archive restored")
		check(store.commit(migrated)["ok"], "normal writer accepts lineage of pre-migration backup")
		check(FileAccess.get_file_as_bytes(String(f["directory"]).path_join("profile.ownership.%s.json" % text.sha256_text())) == bytes, "archive not lost by backup rotation")
	var f := F.make("changed_source")
	var store: ProfileStore = f["store"]
	var path := String(f["directory"]).path_join(ProfileStore.PRIMARY_FILE)
	var source := F.legacy((f["facade"] as ProfileFacade).current_profile())
	F.write(path, source)
	var plan := F.complete(source)
	F.write(path, source + " ")
	check(store.apply_migration(plan["plan"], plan["plan_digest"], "stale").get("error_code") == &"source_changed", "changed disk rejected before pending write")
	var future: Dictionary = JSON.parse_string(source); future["schema_version"] = 99
	F.write(path, JSON.stringify(future))
	var future_bytes := FileAccess.get_file_as_bytes(path)
	check(store.load_profile().get("error_code") == &"unsupported_schema" and FileAccess.get_file_as_bytes(path) == future_bytes, "future version preserved instead of restoring older backup")
	# Current-schema backup recovery retains ownership and receipts.
	f = F.make("current_recovery"); store = f["store"]
	var facade: ProfileFacade = f["facade"]
	check(facade.commit_assets(f["a"], {"kind": "credit_gold", "amount": 3}, "recover_gold", facade.current_profile().revision)["ok"], "current receipt prepared")
	var backup_bytes := FileAccess.get_file_as_bytes(String(f["directory"]).path_join(ProfileStore.BACKUP_FILE))
	F.write(String(f["directory"]).path_join(ProfileStore.PRIMARY_FILE), "corrupt")
	var recovered := store.load_profile()
	check(recovered["ok"] and recovered.get("recovered", false), "current backup recovers through same writer")
	check(ProfileCodec.encode(recovered["profile"])["ok"] and FileAccess.get_file_as_bytes(String(f["directory"]).path_join(ProfileStore.PRIMARY_FILE)) == backup_bytes, "recovery preserves the complete backed-up cut")
	# Known-schema ownership errors are protected, so fallback cannot silently replace an unknown asset cut.
	f = F.make("unknown_owner"); store = f["store"]
	facade = f["facade"]
	var owned := ProfileCodec.encode(facade.current_profile())
	var invalid: Dictionary = owned["data"].duplicate(true)
	invalid["equipment_instances"][0]["owner_character_id"] = "unknown_character"
	var invalid_path := String(f["directory"]).path_join(ProfileStore.PRIMARY_FILE)
	F.write(invalid_path, JSON.stringify(invalid))
	var invalid_bytes := FileAccess.get_file_as_bytes(invalid_path)
	var refused := store.load_profile()
	check(not refused["ok"] and refused.get("read_only", false) and FileAccess.get_file_as_bytes(invalid_path) == invalid_bytes, "unknown owner never triggers destructive fallback")
	f = F.make("uncertain_wallet"); facade = f["facade"]
	var fault: F.FaultStore = f["store"]
	fault.lose_ack = true; fault.hide_after_ack = true
	var before := facade.current_profile().revision
	var uncertain := facade.commit_assets(f["a"], {"kind": "credit_gold", "amount": 7}, "uncertain_gold", before)
	check(not uncertain["ok"] and uncertain.get("read_only", false) and facade.current_profile().character_by_id(f["a"]).gold == 0, "unknown wallet result freezes without publishing")
	check(facade.commit_assets(f["a"], {"kind": "credit_gold", "amount": 8}, "uncertain_gold", before).get("error_code") == &"request_conflict", "uncertain wallet payload cannot be substituted")
	fault.hide_reads = false
	var reconciled := facade.commit_assets(f["a"], {"kind": "credit_gold", "amount": 7}, "uncertain_gold", before)
	check(reconciled["ok"] and reconciled["data"]["gold"] == 7 and facade.current_profile().revision == before + 1, "frozen wallet receipt reconciles once")
	var reopened := ProfileFacade.new(ProfileStore.new(f["directory"]))
	check(reopened.open_profile()["ok"] and reopened.commit_assets(f["a"], {"kind": "credit_gold", "amount": 7}, "uncertain_gold", before).get("already_applied", false), "wallet replay survives process state replacement")
	f = F.make("unsafe_unknown_integer"); store = f["store"]
	var unsafe := ProfileCodec.owned_dictionary((f["facade"] as ProfileFacade).current_profile())
	unsafe["future_integer"] = 9007199254740992.0
	var unsafe_path := String(f["directory"]).path_join(ProfileStore.PRIMARY_FILE)
	F.write(unsafe_path, JSON.stringify(unsafe))
	var unsafe_bytes := FileAccess.get_file_as_bytes(unsafe_path)
	check(store.load_profile().get("error_code") == &"invalid_json_value" and FileAccess.get_file_as_bytes(unsafe_path) == unsafe_bytes, "unrepresentable unknown integer is protected without fallback or rounding")
	finish()
