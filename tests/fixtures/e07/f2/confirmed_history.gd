extends RefCounted
## Explicit confirmation ONLY for closed legacy fixtures; never a production default.

static func legacy_envelope(current: Dictionary) -> Dictionary:
	var data := current.duplicate(true)
	for field: String in ProfileCodec.OWNERSHIP_FIELDS: data.erase(field)
	if data.get("characters") is Array:
		for character: Dictionary in data["characters"]: character.erase("gold")
	if data.get("equipment_instances") is Array:
		for item: Dictionary in data["equipment_instances"]: item.erase("owner_character_id")
	if data.get("card_inventory") is Dictionary: data["card_inventory"].erase("owners")
	if int(data.get("schema_version", 0)) == ProfileState.SCHEMA_VERSION: data["schema_version"] = ProfileCodec.LEGACY_SCHEMA_VERSION
	return data

static func _chosen_preview(text: String, catalog: ProfileCatalog) -> Dictionary:
	var decoded := ProfileCodec.decode(text, catalog)
	if decoded.get("ok", false): return BuildEffectCatalog.failure(&"expected_migration_required")
	if decoded.get("error_code") != &"migration_required": return decoded
	var initial := MigrationPlan.dry_run(text, catalog)
	if not initial.get("ok", false): return initial
	var profile: ProfileState = decoded["legacy_profile"]
	var assignments := {}
	# This fixture policy explicitly chooses the sole referencing character, otherwise primary.
	for id: Variant in initial["plan"]["suggestions"]:
		var owner: String = initial["plan"]["suggestions"][id]
		if owner.is_empty() and not profile.characters.is_empty(): owner = profile.characters[0].character_id
		if not owner.is_empty(): assignments[id] = owner
	# Host assignment is the fixture's decision; socketed cards always accompany it.
	for host: Variant in profile.card_inventory.sockets():
		for card: Variant in profile.card_inventory.sockets()[host]:
			if card != null and assignments.has(String(host)): assignments[String(card)] = assignments[String(host)]
	return MigrationPlan.dry_run(text, catalog, assignments)

static func _metadata(result: Dictionary, text: String, catalog: ProfileCatalog) -> Dictionary:
	if not result.get("ok", false): return result
	var previous := ProfileCodec._decode_legacy(text, catalog)
	for key: String in ["migration_kind", "migration_kinds", "migration_removals"]:
		if previous.has(key): result[key] = previous[key]
	result["migrated"] = true
	return result

static func decode_confirmed(text: String, catalog: ProfileCatalog = null) -> Dictionary:
	var decoded := ProfileCodec.decode(text, catalog)
	if decoded.get("ok", false): return decoded
	if decoded.get("error_code") != &"migration_required": return decoded
	var selected := _chosen_preview(text, catalog)
	if not selected.get("ok", false): return selected
	return _metadata(MigrationPlan.apply(selected["plan"], text, selected["plan_digest"], "fixture_confirmed", catalog), text, catalog)

static func load_confirmed(store: ProfileStore) -> Dictionary:
	var root := ProjectSettings.globalize_path("res://.godot/verification").replace("\\", "/").trim_suffix("/") + "/"
	if not store._absolute_base_directory().replace("\\", "/").begins_with(root): return BuildEffectCatalog.failure(&"fixture_directory_required")
	var opened := store.load_profile()
	if opened.get("ok", false) or opened.get("error_code") != &"migration_required": return opened
	if store.has_pending_transaction(): return opened
	var source := store._migration_source()
	if not source.get("ok", false): return opened
	var selected := _chosen_preview(source["text"], store.catalog_copy())
	if not selected.get("ok", false): return selected
	var preview := store.preview_migration(selected["plan"]["destinations"])
	if not preview.get("ok", false): return preview
	var result := _metadata(store.apply_migration(preview["plan"], preview["plan_digest"], "fixture_confirmed"), source["text"], store.catalog_copy())
	if not result.get("ok", false) and opened.get("read_only", false): result["read_only"] = true
	return result

static func open_confirmed(facade: ProfileFacade) -> Dictionary:
	var loaded := load_confirmed(facade._store)
	if not loaded.get("ok", false): return loaded
	var opened := facade.open_profile()
	if opened.get("ok", false) and loaded.get("migrated", false): opened["migrated"] = true
	return opened
