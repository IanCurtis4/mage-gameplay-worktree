extends "res://tests/fixtures/e07/f4/suite.gd"
func _run() -> void:
	var f := make("compatibility")
	var facade: ProfileFacade = f["facade"]
	var store: ProfileStore = f["store"]
	check(cut(f,"base")["ok"] and cut(f,"suspended",true)["ok"],"two complete cuts for recovery")
	var good := F.disk(f)
	var path := String(f["directory"]).path_join(ProfileStore.PRIMARY_FILE)
	for fault: String in ["future_schema","future_checkpoint","digest","length","owner","missing","oversize"]:
		var data: Dictionary = JSON.parse_string(good)
		var record: Dictionary = data["expeditions"]["fixture_expedition"]
		match fault:
			"future_schema": data["schema_version"] = 99
			"future_checkpoint": record["checkpoint"]["format"] = 99
			"digest": record["checkpoint"]["sha256"] = "0".repeat(64)
			"length": record["checkpoint"]["byte_count"] = 4194305
			"owner": record["checkpoint"]["owner_digest"] = "0".repeat(64)
			"missing": record.erase("checkpoint")
			"oversize": data["padding"] = "x".repeat(ProfileCodec.MAX_FILE_BYTES)
		write(path,JSON.stringify(data))
		var bytes := FileAccess.get_file_as_bytes(path)
		var refused := store.load_profile()
		check(not refused["ok"] and refused.get("read_only",false) and FileAccess.get_file_as_bytes(path) == bytes,"incompatible/unknown checkpoint preserves primary without fallback: "+fault)
	write(path,good)
	var profile := store.load_profile()["profile"] as ProfileState
	var slot := profile.expeditions["fixture_expedition"]
	var decoded := ExpeditionCheckpointCodec.unpack(slot.checkpoint)
	check(decoded["ok"],"transport validates complete original graph")
	var snapshot: Dictionary = decoded["snapshot"]
	var changed := snapshot.duplicate(true); changed["engine"] = "future"
	check(ExpeditionCheckpointCodec.pack(changed,slot.checkpoint["owner_digest"],slot.checkpoint["session"]).get("error_code") == &"content_revision_unavailable","engine/content compatibility is explicit")
	changed = snapshot.duplicate(true); changed["sources"]["res://scripts/main.gd"] = "different"
	check(SnapshotRegistry.new().validate(changed).get("error_code") == &"content_revision_unavailable","unavailable source revision cannot silently reset")
	changed = snapshot.duplicate(true); changed["containers"]["unexpected"] = {"data":"x".repeat(ExpeditionCheckpointCodec.MAX_BYTES)}
	check(not ExpeditionCheckpointCodec.pack(changed,slot.checkpoint["owner_digest"],slot.checkpoint["session"])["ok"],"oversized or malformed snapshot fails without truncation")
	var oversized := facade.current_profile()
	oversized.extension_fields["fixture_size_limit"] = "x".repeat(ProfileCodec.MAX_FILE_BYTES)
	check(store.commit(oversized).get("error_code") == &"profile_too_large" and FileAccess.get_file_as_string(path) == good,"writer rejects oversized candidate without trimming state or replacing primary")
	# Corrupted primary falls back only to a complete older valid cut.
	var backup := FileAccess.get_file_as_bytes(String(f["directory"]).path_join(ProfileStore.BACKUP_FILE))
	write(path,"corrupt")
	var recovered := store.load_profile()
	check(recovered["ok"] and recovered.get("recovered",false) and FileAccess.get_file_as_bytes(path) == backup,"backup restores world/assets/receipts as a single cut")
	check(recovered["profile"].expeditions["fixture_expedition"].checkpoint["session"] == recovered["profile"].reward_session,"backup session and world agree")
	dispose(f)
	finish()
