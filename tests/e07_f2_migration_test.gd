extends "res://tests/fixtures/e07/f2/suite.gd"
func _run() -> void:
	var f := F.make("migration")
	var facade: ProfileFacade = f["facade"]
	var source := F.legacy(facade.current_profile())
	var original_digest := source.sha256_text()
	var decoded := ProfileCodec.decode(source)
	check(decoded.get("error_code") == &"migration_required" and not decoded["ok"], "legacy decode never returns writable profile")
	var legacy: ProfileState = decoded["legacy_profile"]
	check(ProfileCodec.encode(legacy).get("error_code") == &"migration_required", "legacy candidate cannot be accidentally saved")
	var first := MigrationPlan.dry_run(source)
	check(first["ok"] and not first["complete"] and first["plan"]["destinations"].is_empty(), "suggestions do not silently assign destinations")
	var complete := F.complete(source)
	var plan: Dictionary = complete["plan"]
	check(complete["ok"] and complete["complete"] and not plan["removals"].is_empty(), "preview accounts for every asset and removed alt reference")
	check(MigrationPlan.validate(plan, source)["ok"], "complete map validates")
	check(MigrationPlan.apply(plan, source, "", "migration").get("error_code") == &"confirmation_required", "confirmation required before apply")
	check(MigrationPlan.validate(plan, source + " ").get("error_code") == &"source_changed", "even semantically equivalent changed source invalidates preview")
	var incomplete: Dictionary = first["plan"]
	check(MigrationPlan.validate(incomplete, source).get("error_code") == &"incomplete_migration_map", "incomplete map cannot commit")
	var forged := plan.duplicate(true); forged["removals"].clear()
	check(MigrationPlan.validate(forged, source).get("error_code") == &"invalid_migration_plan", "removal report cannot be forged")
	forged = plan["destinations"].duplicate(true); forged["equipment_unknown"] = f["a"]
	check(MigrationPlan.dry_run(source, null, forged).get("error_code") == &"unknown_asset", "unknown assignment rejected")
	var host: String = ""; var socket_card: String = ""
	for key: Variant in legacy.card_inventory.sockets():
		host = String(key); socket_card = String(legacy.card_inventory.sockets()[key][0])
	forged = plan["destinations"].duplicate(true); forged[socket_card] = f["b"]
	check(MigrationPlan.dry_run(source, null, forged).get("error_code") == &"host_owner_mismatch", "socket card cannot diverge from host owner")
	forged = plan["destinations"].duplicate(true); forged.erase(socket_card)
	var inherited := MigrationPlan.dry_run(source, null, forged)
	check(inherited["ok"] and inherited["complete"] and inherited["plan"]["destinations"][socket_card] == inherited["plan"]["destinations"][host], "socket follows explicit host destination")
	var applied := MigrationPlan.apply(plan, source, complete["plan_digest"], "migration")
	check(applied["ok"], "confirmed pure apply succeeds")
	if not applied["ok"]: finish(); return
	var migrated: ProfileState = applied["profile"]
	check(migrated.equipment_instance_ids() == legacy.equipment_instance_ids() and migrated.card_inventory.to_record() == legacy.card_inventory.to_record(), "all IDs cards sockets grants counters and metadata preserved")
	for id: StringName in migrated.equipment_instances:
		check(migrated.equipment_instances[id].to_record() == legacy.equipment_instances[id].to_record(), "equipment metadata preserved per exemplar")
	check(migrated.extension_fields == legacy.extension_fields and migrated.characters[0].extension_fields == legacy.characters[0].extension_fields, "unknown fields preserved")
	check(migrated.characters[1].equipped.values().all(func(value: Variant) -> bool: return value == null), "foreign alt references removed exactly as previewed")
	check(migrated.characters[0].gold == 0 and migrated.characters[1].gold == 0 and source.sha256_text() == original_digest, "legacy gold zero and source immutable")
	check(ProfileCodec.decode(ProfileCodec.encode(migrated)["text"])["ok"], "migration result validates through production codec")
	var reserved: Dictionary = JSON.parse_string(source); reserved["profile_unlocks"] = {"unknown": "preserve"}
	check(MigrationPlan.dry_run(JSON.stringify(reserved)).get("error_code") == &"reserved_migration_field", "reserved unknown collision preserved by refusing migration")
	# Validate and migrate the actual older accepted envelope, not a synthetic schema7-only shape.
	var historical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/fixtures/e00_reference.json"))
	var historical_text := JSON.stringify(historical["profile"])
	var historical_preview := MigrationPlan.dry_run(historical_text)
	check(historical_preview["ok"], "actual E00 envelope passes historical validator before preview")
	if historical_preview["ok"]:
		var old: ProfileState = ProfileCodec.decode(historical_text)["legacy_profile"]
		var destinations := {}
		for id: StringName in old.equipment_instances: destinations[String(id)] = old.characters[0].character_id
		var selected := MigrationPlan.dry_run(historical_text, null, destinations)
		check(selected["ok"] and selected["complete"], "actual E00 envelope gets complete explicit assignments")
		if selected["ok"]:
			var converted := MigrationPlan.apply(selected["plan"], historical_text, selected["plan_digest"], "actual_e00")
			check(converted["ok"] and converted["profile"].characters[0].display_name == "Referência", "historical Unicode and identity survive confirmed migration")
	var oversize := migrated.copy_state(); oversize.extension_fields["oversize"] = "x".repeat(ProfileCodec.MAX_FILE_BYTES)
	check(ProfileCodec.encode(oversize).get("error_code") == &"profile_too_large", "size limit refuses data without pruning IDs or receipts")
	finish()
