extends SceneTree
const F = preload("res://tests/e06_tx_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _catalog() -> BuildEffectCatalog:
	var source := BuildContentLoader.pilot()
	var mobs := MobCatalog.new()
	for id: StringName in source.mob_catalog().ids():
		var mob := source.mob_catalog().get_definition(id)
		if id == &"pilot_bulwark_species":
			# Isolated exposure fixture, not a production boss/level change.
			mob.allowed_occurrence_categories = MobCatalog.CATEGORIES.duplicate()
			mob.fixed_level = 30
		assert(mobs.register_definition(mob)["ok"])
	var catalog := BuildEffectCatalog.new()
	catalog.set_mob_catalog(mobs)
	for set: Resource in BuildContentLoader.definitions(&"set"): catalog.register_set(set)
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in source.ids(origin): catalog.register_definition(origin, source.get_definition(origin, id))
	return catalog
func _occurrence(category: StringName, base: StringName = &"pilot_bulwark_species") -> MobOccurrence:
	var mob := MobOccurrence.new()
	mob.occurrence_id = "balance_" + String(category)
	mob.category_id = category; mob.mob_base_id = base; mob.origin_id = &"demo_arena"
	return mob
func _run() -> void:
	var catalog := _catalog()
	var table := EquipmentLootProfiles.production(catalog)
	var created := MobLootResolver.create(catalog, table)
	_check(created["ok"], "approved production table and tier pools validate")
	if not created["ok"]: print(created); quit(1); return
	var resolver: MobLootResolver = created["resolver"]
	var expected_eq := [0.04, 1.0, 0.12, 1.0, 1.0]
	var expected_card := [0.02, 0.06, 0.08, 0.16, 0.40]
	var categories: Array[StringName] = [&"normal", &"rare", &"elite", &"rare_elite", &"boss"]
	for index: int in categories.size():
		var category: StringName = categories[index]
		_check(table.profiles[category]["equipment_chance"] == expected_eq[index] and table.profiles[category]["card_chance"] == expected_card[index], "literal approved rates " + String(category))
		var low := resolver.roll(_occurrence(category), [0.0, 0.0, 0.0, 0.0, 0.0])
		var high := resolver.roll(_occurrence(category), [1.0, 1.0, 1.0, 1.0, 1.0])
		_check(low["ok"] and high["ok"] and low["equipment_drops"].size() == 1 and high["equipment_drops"].size() == (1 if category in [&"rare", &"rare_elite", &"boss"] else 0), "one item guarantee and chance extremes")
		_check(low["card_id"] == &"bulwark_card" and high["card_id"] == &"", "base card invariant across category")
		var boundary := resolver.roll(_occurrence(category), [1.0, 1.0, 0.0, 0.0, expected_card[index]])
		_check(boundary["card_id"] == &"", "strict card probability boundary")
		var sampled := resolver.roll(_occurrence(category), [0.0, 1.0, 1.0, 0.99, 0.0])
		var drop: Dictionary = sampled["equipment_drops"][0]
		var item := catalog.get_definition(&"equipment", drop["definition_id"]) as EquipmentDefinition
		_check(drop["quality_id"] == item.quality_id and drop["power_ruleset_id"] == &"equipment_growth_v1" and drop["recipe_revision_id"] == &"catalog_v1" and drop["item_level"] == 30, "exact authored tier/level/revision frozen")
		_check(category == &"boss" or drop["quality_id"] != &"legendary", "legendary impossible outside boss")
		if category == &"boss": _check(drop["definition_id"] == &"arena_legendary_ward", "boss uses exclusive authored legendary")
	var uniforms := [0.0, 0.0, 0.0, 0.0, 1.0]
	for pair: Array in [[0.0, 0], [0.6, 1], [0.85, 2], [0.95, 3], [0.99, 4]]:
		uniforms[3] = pair[0]
		var drop: Dictionary = resolver.roll(_occurrence(&"normal"), uniforms)["equipment_drops"][0]
		_check(drop["socket_capacity"] == pair[1], "literal independent socket threshold")
	var no_drop := resolver.roll(_occurrence(&"normal"), [0.04, 0.0, 0.0, 0.0, 1.0])
	_check(no_drop["equipment_drops"].is_empty(), "literal4percent exact boundary")
	var demo := resolver.roll(_occurrence(&"normal", &"demo_chaser"), [0.0, 0.0, 0.0, 0.0, 0.0])
	_check(demo["ok"] and demo["card_id"] == &"", "explicit demo species has no invented card")
	var original := resolver.roll(_occurrence(&"boss"), [0.0, 1.0, 0.0, 0.99, 0.0])
	table.power_ruleset_id = &"unknown"; table.profiles[&"boss"]["quality_weights"] = {&"common": 1}
	_check(resolver.roll(_occurrence(&"boss"), [0.0, 1.0, 0.0, 0.99, 0.0]) == original, "resolver freezes table and power references")
	# Production writer uses the real complete profile catalog; historical F.make
	# intentionally owns only its closed fixture metadata, not the new tier IDs.
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e06_power/ticket_%d" % Time.get_ticks_usec())
	var store := F.FaultStore.new(directory, ProfileCatalog.pilot())
	var facade := ProfileFacade.new(store, ProfileRewardResolver.pilot_progression())
	_check(facade.create_character("create", 0, "Loot real", &"mage")["ok"], "production profile created")
	var started := facade.start_run("start", facade.current_profile().revision)
	_check(started["ok"] and started["run_state"].set_effect_catalog(catalog)["ok"], "production state uses explicit fixture exposure before configure")
	RunController.pending_run_state = started["run_state"]
	RunController.pending_run_facade = facade
	RunController.pending_training_mode = false
	var controller := RunController.new()
	root.add_child(controller); controller.set_process(false); controller.player.set_process(false)
	controller.encounter_active = false
	var fixture := {"controller": controller, "directory": directory, "store": store}
	_check(controller.reward_service.mob_loot_enabled(), "Main installs production table in real persistent run")
	for enemy: CombatActor in controller.enemies: enemy.free()
	controller.enemies.clear()
	controller.player.apply_run_modifiers(controller.run_state)
	_check(controller.reward_service.configure_mob_loot(EquipmentLootProfiles.production(catalog))["ok"], "real service configures approved rates")
	var actor := EnemyActor.new()
	actor.configure_occurrence(_occurrence(&"boss"), catalog.mob_catalog(), controller.navigation, controller.player)
	controller.add_child(actor); controller.enemies.append(actor); actor.set_process(false)
	_check(controller.reward_service.register_mob_actor(actor)["ok"], "real occurrence registered")
	actor.health.current_hp = 0
	var before_disk := F.disk(fixture)
	var minted := controller.reward_service.issue_mob_drop(actor)
	var rng_state := controller.rng.state
	_check(minted["ok"] and F.disk(fixture) == before_disk, "ticket captures growth before acquisition")
	_check(controller.reward_service.issue_mob_drop(actor)["ticket_id"] == minted["ticket_id"] and controller.rng.state == rng_state, "death replay retains RNG")
	var frozen: Dictionary = minted["payload"]["equipment_drops"][0].duplicate(true)
	store.failure_stage = &"write_pending"
	_check(not controller.reward_service.collect(minted["ticket_id"])["ok"] and F.disk(fixture) == before_disk, "failed save does not publish growth")
	store.failure_stage = &""
	var collected := controller.reward_service.collect(minted["ticket_id"])
	_check(collected["ok"] and controller.rng.state == rng_state, "retry preserves frozen recipe and RNG: " + String(collected.get("error_code", "")))
	if not collected["ok"]:
		controller.free()
		print("E06 production loot: %d checks, %d failures" % [checks, failures])
		quit(1); return
	var profile := controller.persistent_facade.current_profile()
	var instance: EquipmentInstance = profile.equipment_instances[profile.equipment_instance_ids().back()]
	_check(instance.definition_id == frozen["definition_id"] and instance.item_level == 30 and instance.power_ruleset_id == &"equipment_growth_v1" and instance.recipe_revision_id == &"catalog_v1", "durable collection retains growth references")
	var count := profile.equipment_instances.size()
	_check(controller.reward_service.collect(minted["ticket_id"])["already_applied"] and controller.persistent_facade.current_profile().equipment_instances.size() == count, "collection idempotent")
	var stage := controller.reward_service.issue("growth_stage", &"encounter_two", true)
	_check(stage["ok"] and stage["payload"]["equipment_drops"].is_empty() and stage["card_id"] == &"" and stage["payload"]["base_xp"] == 150 and stage["payload"]["job_xp"] == 100, "mob loot replaces stage gear/card only: " + String(stage.get("error_code", "")))
	if stage["ok"]: _check(controller.reward_service.collect(stage["ticket_id"])["ok"] and controller.run_state.pending_choices == 1, "stage augment access unchanged")
	controller.free()
	await process_frame
	print("E06 production loot: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
