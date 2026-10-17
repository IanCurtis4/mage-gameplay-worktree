extends SceneTree

var checks := 0
var failures := 0

class FaultStore:
	extends ProfileStore
	var uncertain := false
	var hide_reads := false
	func commit(source: ProfileState) -> Dictionary:
		var result := super.commit(source)
		if uncertain and result["ok"]:
			uncertain = false
			hide_reads = true
			return {"ok": false, "error_code": &"save_failed"}
		return result
	func load_profile() -> Dictionary:
		if hide_reads: return {"ok": false, "error_code": &"result_uncertain", "read_only": true}
		return super.load_profile()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_admin_profile_%d" % Time.get_ticks_usec())
	var catalog := ProfileCatalog.pilot()
	var facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var created := facade.create_character("create-admin", 0, "Admin permanente", &"swordsman")
	if not created["ok"]: print(created)
	check(created["ok"], "create isolated character")
	if not created["ok"]: finish(); return
	var character_id: String = facade.current_profile().selected_character_id
	var item_ids := catalog.equipment_ids()
	item_ids.sort()
	var item_id: StringName = item_ids[0]
	var first := PlaytestProfileAdmin.grant(facade, "item-1", facade.current_profile().revision, character_id, &"equipment", item_id)
	check(first["ok"] and facade.current_profile().equipment_instances.has(StringName(first.get("equipment_instance_id", ""))), "equipment commits one permanent instance")
	var replay := PlaytestProfileAdmin.grant(facade, "item-1", 0, character_id, &"equipment", item_id)
	check(replay["ok"] and replay.get("already_applied", false) and replay.get("equipment_instance_id") == first.get("equipment_instance_id"), "request replay returns original instance before stale check")
	var second := PlaytestProfileAdmin.grant(facade, "item-2", facade.current_profile().revision, character_id, &"equipment", item_id)
	check(second["ok"] and second.get("equipment_instance_id") != first.get("equipment_instance_id"), "new request creates another allowed instance")
	var item_metadata := catalog.equipment_metadata(item_id)
	var ui_options := {"item_level": int(item_metadata["item_level"]), "quality_id": item_metadata["quality_id"], "socket_capacity": int(item_metadata["socket_capacity"])}
	var explicit := PlaytestProfileAdmin.grant(facade, "item-options", facade.current_profile().revision, character_id, &"equipment", item_id, ui_options)
	check(explicit["ok"] and facade.current_profile().equipment_instances.has(StringName(explicit.get("equipment_instance_id", ""))), "UI metadata options commit a canonical exemplar")
	var stale := PlaytestProfileAdmin.grant(facade, "stale-admin", 0, character_id, &"equipment", item_id)
	check(not stale["ok"] and stale["error_code"] == &"stale_revision", "stale revision blocks new grant")
	var cards := catalog.card_ids()
	cards.sort()
	var card := PlaytestProfileAdmin.grant(facade, "card-1", facade.current_profile().revision, character_id, &"card", cards[0])
	check(card["ok"] and facade.current_profile().card_inventory.owns(StringName(card.get("card_instance_id", ""))), "card is profile owned")
	var instance_count := facade.current_profile().equipment_instances.size()
	var bad_options := PlaytestProfileAdmin.grant(facade, "bad-item", facade.current_profile().revision, character_id, &"equipment", item_id, {"item_level": 31})
	check(not bad_options["ok"] and facade.current_profile().equipment_instances.size() == instance_count, "invalid item level cannot create instance")
	var unlock := PlaytestProfileAdmin.grant(facade, "skill-1", facade.current_profile().revision, character_id, &"unlock_skills")
	check(unlock["ok"] and facade.current_profile().character_by_id(character_id).admin_skills_unlocked, "admin skill flag persists")
	var character: CharacterState = facade.current_profile().character_by_id(character_id)
	var projected := CharacterProgression.effective_skill_ranks(character, catalog)
	var ordinary := catalog.effective_skill_ranks(character.base_class_id, character.evolution_id, character.purchased_skill_ranks, character.granted_skill_ranks)
	check(projected.size() >= ordinary.size() and character.purchased_skill_ranks.is_empty(), "overlay leaves purchase ledger untouched")
	var maxed := PlaytestProfileAdmin.grant(facade, "max-1", facade.current_profile().revision, character_id, &"max_levels")
	check(maxed["ok"] and facade.current_profile().character_by_id(character_id).job_xp_total == ProgressionRules.UNEVOLVED_MAX_JOB_XP, "unevolved job cap remains legal")
	character = facade.current_profile().character_by_id(character_id)
	projected = CharacterProgression.effective_skill_ranks(character, catalog)
	for skill_id: StringName in catalog.skill_ids_for_identity(character.base_class_id, character.evolution_id):
		var metadata := catalog.skill_metadata(skill_id)
		var cap := int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
		check(int(projected.get(skill_id, 0)) <= cap, "overlay respects cap " + String(skill_id))
		for rank: int in range(int(metadata["free_rank"]) + 1, int(projected.get(skill_id, 0)) + 1):
			check(catalog.check_rank_requirements(skill_id, rank, ProgressionRules.UNEVOLVED_MAX_JOB_LEVEL, projected)["ok"], "overlay respects dependency " + String(skill_id))
	var respec := facade.respec_skills("respec-admin", facade.current_profile().revision, character_id)
	check(respec["ok"] and facade.current_profile().character_by_id(character_id).admin_skills_unlocked, "respec preserves admin projection")
	var evolved := facade.change_evolution("evolve-admin", facade.current_profile().revision, character_id, &"defender")
	check(evolved["ok"] and facade.current_profile().character_by_id(character_id).admin_skills_unlocked, "evolution preserves flag")
	var saved := ProfileCodec.encode(facade.current_profile(), catalog)
	check(saved["ok"] and saved["data"]["schema_version"] == 7 and saved["data"]["characters"][0]["admin_skills_unlocked"] == true, "schema 7 serializes strict flag")
	if saved["ok"]:
		var historical: Dictionary = saved["data"].duplicate(true)
		historical["schema_version"] = 6
		historical["characters"][0].erase("admin_skills_unlocked")
		historical.erase("playtest_admin_receipts_v1")
		var migrated := ProfileCodec.decode(JSON.stringify(historical), catalog)
		check(migrated["ok"] and migrated["migrated"] and not migrated["profile"].characters[0].admin_skills_unlocked, "schema 6 migrates to false after validation")
		var invalid: Dictionary = saved["data"].duplicate(true)
		invalid["characters"][0]["admin_skills_unlocked"] = 1
		check(not ProfileCodec.decode(JSON.stringify(invalid), catalog)["ok"], "schema 7 rejects numeric flag")
		invalid = saved["data"].duplicate(true)
		invalid["characters"][0].erase("admin_skills_unlocked")
		check(not ProfileCodec.decode(JSON.stringify(invalid), catalog)["ok"], "schema 7 requires flag")
	var reopened := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var loaded := reopened.open_profile()
	check(loaded["ok"] and reopened.current_profile().character_by_id(character_id).admin_skills_unlocked and reopened.current_profile().card_inventory.owns(StringName(card["card_instance_id"])), "collection and flag reopen durably")
	check(reopened.current_profile().equipment_instances.has(StringName(explicit.get("equipment_instance_id", ""))), "UI metadata receipt survives JSON reload")
	if saved["ok"]:
		var malformed: Dictionary = saved["data"].duplicate(true)
		malformed["playtest_admin_receipts_v1"][0]["result"]["equipment_instance_id"] = "equipment_999999"
		check(not ProfileCodec.decode(JSON.stringify(malformed), catalog)["ok"], "receipt cannot claim missing equipment")
		malformed = saved["data"].duplicate(true)
		malformed["characters"][0]["granted_skill_ranks"]["defender_anchor"] = 1
		check(not ProfileCodec.decode(JSON.stringify(malformed), catalog)["ok"], "admin flag cannot smuggle legacy grants")
	var identity_count := 0
	for origin: StringName in IdentityIds.base_class_ids():
		var identities: Array[StringName] = [&""]
		for evolution: StringName in IdentityIds.pure_evolution_ids() + IdentityIds.hybrid_evolution_ids():
			if IdentityIds.evolution_belongs_to(evolution, origin) and catalog.evolution_is_ready(evolution, origin):
				identities.append(evolution)
		for evolution: StringName in identities:
			identity_count += 1
			var probe := CharacterState.new("probe_%d" % identity_count, "Prova", origin)
			probe.evolution_id = evolution
			probe.job_xp_total = ProgressionRules.MAX_JOB_XP if not evolution.is_empty() else ProgressionRules.UNEVOLVED_MAX_JOB_XP
			probe.admin_skills_unlocked = true
			var ranks := CharacterProgression.effective_skill_ranks(probe, catalog)
			var level := ProgressionRules.job_level_for_xp(probe.job_xp_total, not evolution.is_empty())
			for id: StringName in catalog.skill_ids_for_identity(origin, evolution):
				var metadata := catalog.skill_metadata(id)
				var cap := int(metadata["free_rank"]) + int(metadata["max_purchased_rank"])
				check(int(ranks.get(id, 0)) <= cap, "identity cap " + String(id))
				for rank: int in range(int(metadata["free_rank"]) + 1, int(ranks.get(id, 0)) + 1):
					check(catalog.check_rank_requirements(id, rank, level, ranks)["ok"], "identity dependency " + String(id))
	check(identity_count == 10, "ten ready identities projected")
	_durable_migration(saved, catalog, character_id)
	_uncertain_reconcile(catalog, item_id, ui_options)
	finish()

func _durable_migration(saved: Dictionary, catalog: ProfileCatalog, character_id: String) -> void:
	if not saved["ok"]: return
	var historical: Dictionary = saved["data"].duplicate(true)
	historical["schema_version"] = 6
	for entry: Dictionary in historical["characters"]: entry.erase("admin_skills_unlocked")
	historical.erase("playtest_admin_receipts_v1")
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_admin_schema6_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join(ProfileStore.PRIMARY_FILE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(historical, "\t"))
	file.close()
	var original_bytes := FileAccess.get_file_as_bytes(path)
	var migrated_facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var first := migrated_facade.open_profile()
	check(first["ok"] and first.get("migrated", false) and migrated_facade.current_profile().revision == int(historical["revision"]) + 1, "store durably migrates real schema 6 exactly once")
	check(FileAccess.get_file_as_bytes(directory.path_join(ProfileStore.BACKUP_FILE)) == original_bytes, "migration backup preserves exact schema 6 bytes")
	check(migrated_facade.current_profile().character_by_id(character_id) != null and not migrated_facade.current_profile().character_by_id(character_id).admin_skills_unlocked, "migration preserves character with admin flag false")
	var second_facade := ProfileFacade.new(ProfileStore.new(directory, catalog))
	var second := second_facade.open_profile()
	check(second["ok"] and not second.get("migrated", false) and second_facade.current_profile().revision == int(historical["revision"]) + 1, "second open does not remigrate")
	var created := second_facade.create_character("after-schema7", second_facade.current_profile().revision, "Outro", &"mage")
	check(created["ok"] and second_facade.current_profile().characters.size() == 2 and second_facade.current_profile().character_by_id(character_id) != null, "profile remains writable after migration")

func _uncertain_reconcile(catalog: ProfileCatalog, item_id: StringName, ui_options: Dictionary) -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_admin_uncertain_%d" % Time.get_ticks_usec())
	var store := FaultStore.new(directory, catalog)
	var facade := ProfileFacade.new(store)
	var created := facade.create_character("create-live-admin", 0, "Admin live", &"swordsman")
	check(created["ok"], "create isolated live profile")
	if not created["ok"]: return
	var character_id: String = facade.current_profile().selected_character_id
	var started := facade.start_run("start-live-admin", facade.current_profile().revision)
	check(started["ok"], "start persistent run for admin reconciliation")
	if not started["ok"]: return
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_gameplay_extension = false
	var controller := RunController.new()
	root.add_child(controller)
	controller.set_process(false)
	controller.player.set_process(false)
	for enemy: CombatActor in controller.enemies: enemy.set_process(false)
	controller._open_admin_tools()
	check(controller.admin_panel.visible and paused, "live admin panel owns the paused authority")
	store.uncertain = true
	var revision := facade.current_profile().revision
	var runtime_revision := controller.run_state.runtime_revision
	var uncertain_result := PlaytestProfileAdmin.grant(facade, "live-uncertain-item", revision, character_id, &"equipment", item_id, ui_options, controller)
	check(not uncertain_result["ok"] and uncertain_result.get("read_only", false) and controller.inventory_frozen and not facade._admin_pending.is_empty(), "uncertain commit freezes live inventory and retains exact intent")
	store.hide_reads = false
	var other := PlaytestProfileAdmin.grant(facade, "other-live-item", revision, character_id, &"equipment", item_id, ui_options, controller)
	check(not other["ok"] and other["error_code"] == &"result_uncertain", "different request cannot overtake uncertain transaction")
	var reconciled := PlaytestProfileAdmin.grant(facade, "live-uncertain-item", revision, character_id, &"equipment", item_id, ui_options, controller)
	if not reconciled["ok"] or not facade._admin_pending.is_empty() or not facade.current_profile().equipment_instances.has(StringName(reconciled.get("equipment_instance_id", ""))):
		print("admin reconcile diagnostic: ", reconciled, " pending=", facade._admin_pending, " frozen=", controller.inventory_frozen)
	check(reconciled["ok"] and facade._admin_pending.is_empty() and facade.current_profile().equipment_instances.has(StringName(reconciled.get("equipment_instance_id", ""))), "same live intent reconciles exactly one durable instance")
	check(controller.run_state.runtime_revision == runtime_revision and controller.inventory_frozen, "runtime remains unpublished until controller refresh")
	controller._refresh_admin_profile()
	check(controller.run_state.runtime_revision == runtime_revision + 1 and not controller.inventory_frozen, "controller publishes reconciled profile once and unfreezes")
	paused = false
	controller.queue_free()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func finish() -> void:
	print("E06 admin profile: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)
