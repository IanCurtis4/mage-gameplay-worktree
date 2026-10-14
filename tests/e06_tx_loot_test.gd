extends SceneTree
const F = preload("res://tests/e06_inventory_fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _catalog() -> BuildEffectCatalog:
	var source := F.catalog()
	var mobs := source.mob_catalog()
	var mob := MobDefinition.new()
	mob.id = &"loot_fixture"
	mob.fixed_level = 7
	mob.allowed_occurrence_categories = MobCatalog.CATEGORIES.duplicate()
	mob.card_id = &"bulwark_card"
	for axis: StringName in StatCalculator.PRIMARY_IDS: mob.primary_attributes[axis] = 3
	assert(mobs.register_definition(mob)["ok"])
	var result := BuildEffectCatalog.new()
	result.set_mob_catalog(mobs)
	for origin: StringName in BuildEffectCatalog.ORIGINS:
		for id: StringName in source.ids(origin):
			# Use a published persistent card ID with explicit fixture species/effect binding.
			if origin == &"card" and id == &"bulwark_card": continue
			assert(result.register_definition(origin, source.get_definition(origin, id))["ok"])
	var card := CardDefinition.new()
	card.id = &"bulwark_card"
	card.mob_base_id = mob.id
	card.effects.assign([F.stat(&"loot_hp", &"max_hp", 5)])
	assert(result.register_definition(&"card", card)["ok"])
	return result
func _table() -> MobLootTable:
	var table := MobLootTable.new()
	for category: StringName in MobCatalog.CATEGORIES:
		var qualities := {&"common": 1.0, &"rare": 1.0, &"epic": 1.0}
		if category == &"boss": qualities[&"legendary"] = 1.0
		table.profiles[category] = {"equipment_chance": 0.0, "card_chance": 1.0, "quality_weights": qualities, "equipment_weights": {&"starter_blade": 1.0}, "socket_weights": {0: 1.0, 4: 1.0}}
	return table
func _occurrence(category: StringName) -> MobOccurrence:
	var result := MobOccurrence.new()
	result.occurrence_id = "fixture_" + String(category)
	result.mob_base_id = &"loot_fixture"
	result.category_id = category
	result.origin_id = &"fixture_map"
	return result
func _run() -> void:
	var catalog := _catalog()
	var table := _table()
	var created := MobLootResolver.create(catalog, table)
	_check(created["ok"], "explicit fixture table validates")
	var resolver: MobLootResolver = created["resolver"]
	for category: StringName in MobCatalog.CATEGORIES:
		var low := resolver.roll(_occurrence(category), [0.0, 0.0, 0.0, 0.0, 0.0])
		var high := resolver.roll(_occurrence(category), [1.0, 1.0, 1.0, 1.0, 1.0])
		var guaranteed := MobLootResolver.FLOORS.has(category)
		_check(low["equipment_drops"].size() == (1 if guaranteed else 0) and high["equipment_drops"].size() == (1 if guaranteed else 0), "guarantee yields one item independent of chance " + String(category))
		_check(low["card_id"] == &"bulwark_card" and high["card_id"] == &"bulwark_card", "occurrence variant retains base card even at extreme RNG " + String(category))
		if guaranteed:
			_check(low["equipment_drops"][0]["quality_id"] == MobLootResolver.FLOORS[category], "minimum quality applied once")
			_check(high["equipment_drops"][0]["quality_id"] == (&"legendary" if category == &"boss" else &"epic") and high["equipment_drops"].size() == 1, "superior replaces guaranteed minimum without extra item")
			_check(low["equipment_drops"][0]["socket_capacity"] == 0 and high["equipment_drops"][0]["socket_capacity"] == 4, "socket axis independent of rarity")
			_check(high["equipment_drops"][0]["item_level"] == 7 and high["equipment_drops"][0]["origin_id"] == &"fixture_map", "fixed base level and actual spatial origin frozen")
	var invalid := _table()
	invalid.profiles[&"normal"]["quality_weights"][&"legendary"] = 1.0
	_check(MobLootResolver.create(catalog, invalid)["error_code"] == &"legendary_requires_boss", "legendary non-boss rejected before RNG")
	invalid = _table()
	invalid.profiles[&"boss"]["equipment_weights"] = {}
	_check(not MobLootResolver.create(catalog, invalid)["ok"], "empty guaranteed pool rejected")
	invalid = _table()
	invalid.profiles[&"normal"]["card_chance"] = NAN
	_check(MobLootResolver.create(catalog, invalid)["error_code"] == &"invalid_loot_chance", "non-finite rate rejected")
	invalid = _table()
	invalid.profiles[&"normal"]["socket_weights"] = {5: 1.0}
	_check(not MobLootResolver.create(catalog, invalid)["ok"], "invalid physical capacity rejected")
	_check(not resolver.roll(_occurrence(&"boss"), [0, 0, 0, 0, NAN])["ok"], "invalid RNG value rejected by pure resolver")
	var jewelry := _table()
	jewelry.profiles[&"rare"]["equipment_weights"] = {&"traveler_charm": 1.0}
	var jewel_resolver: MobLootResolver = MobLootResolver.create(catalog, jewelry)["resolver"]
	_check(jewel_resolver.roll(_occurrence(&"rare"), [0, 1, 0, 1, 0])["equipment_drops"][0]["socket_capacity"] == 0, "jewelry never receives rolled sockets")
	table.profiles[&"boss"]["equipment_weights"].clear()
	_check(resolver.roll(_occurrence(&"boss"), [1, 1, 1, 1, 1])["ok"], "resolver freezes table by value")
	_durable_event(catalog)
	print("E06 TX3 loot: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
func _durable_event(catalog: BuildEffectCatalog) -> void:
	var fixture := F.make(self, "tx3_loot")
	var c: RunController = fixture["controller"]
	_check(c.run_state.set_effect_catalog(catalog)["ok"], "run gets shared mob-base authority")
	for actor: CombatActor in c.enemies:
		var occurrence := _occurrence(&"normal")
		occurrence.occurrence_id = "spawn_%d" % actor.get_instance_id()
		_check((actor as EnemyActor).configure_occurrence(occurrence, catalog.mob_catalog(), c.navigation, c.player)["ok"], "fixture species applied to owned world actor")
	var table := _table()
	table.profiles[&"normal"]["equipment_chance"] = 1.0
	table.profiles[&"normal"]["quality_weights"] = {&"rare": 1.0}
	table.profiles[&"normal"]["socket_weights"] = {4: 1.0}
	_check(c.reward_service.configure_mob_loot(table)["ok"], "table atomically installs and registers world spawns")
	_check(c.run_state.set_effect_catalog(BuildEffectCatalog.new())["error_code"] == &"catalog_frozen", "configured loot catalog cannot disappear before frozen card collection")
	var actor := c.enemies[0] as EnemyActor
	var rng_before := c.rng.state
	_check(not c.reward_service.issue_mob_drop(actor)["ok"] and c.rng.state == rng_before, "living actor cannot mint ticket or consume RNG")
	var foreign := EnemyActor.new()
	foreign.configure_occurrence(_occurrence(&"rare"), catalog.mob_catalog(), c.navigation, c.player)
	foreign.health.current_hp = 0
	root.add_child(foreign)
	_check(not c.reward_service.issue_mob_drop(foreign)["ok"] and c.rng.state == rng_before, "foreign actor cannot forge a world event")
	foreign.free()
	var before_disk := F.disk(fixture)
	var before_profile := c.persistent_facade.current_profile().copy_state()
	var event := "mob:" + actor.occurrence.occurrence_id
	actor.occurrence.origin_id = &"changed_after_spawn"
	actor.health.current_hp = 0
	c.encounter_active = true
	c._on_enemy_died(actor)
	var token: String = c.reward_service._events[event]
	var ticket := c.reward_service.ticket(token)
	var rng_after := c.rng.state
	_check(rng_after != rng_before and ticket["payload"]["equipment_drops"][0]["origin_id"] == &"fixture_map", "actual death freezes RNG and registered spatial origin")
	_check(c.reward_service.issue_mob_drop(actor)["ticket_id"] == token and c.rng.state == rng_after, "death replay never rerolls")
	_check(F.disk(fixture) == before_disk and c.run_state.card_inventory.describe()["owned"].is_empty(), "issuance is not acquisition or partial persistence")
	ticket["payload"]["equipment_drops"][0]["quality_id"] = &"common"
	c.encounter_active = false
	var store: F.FaultStore = fixture["store"]
	store.failure_stage = &"write_pending"
	_check(not c.reward_service.collect(token)["ok"] and F.disk(fixture) == before_disk and c.run_state.card_inventory.describe()["owned"].is_empty(), "failed durable collection publishes nothing")
	store.failure_stage = &""
	_check(c.reward_service.collect(token)["ok"] and c.rng.state == rng_after, "retry commits frozen acquisition without RNG")
	var profile := c.persistent_facade.current_profile()
	var acquired: EquipmentInstance = profile.equipment_instances[profile.equipment_instance_ids().back()]
	_check(profile.equipment_instances.size() == before_profile.equipment_instances.size() + 1 and acquired.quality_id == &"rare" and acquired.item_level == 7 and acquired.socket_capacity == 4, "actual metadata and repeated definition create own persistent exemplar")
	_check(c.run_state.card_inventory.describe()["owned"].size() == 1 and c.run_state.pending_choices == 0 and profile.characters[0].base_xp_total == before_profile.characters[0].base_xp_total, "mob gives one permanent card without encounter XP or augment")
	var collected_disk := F.disk(fixture)
	_check(c.reward_service.collect(token)["already_applied"] and F.disk(fixture) == collected_disk and c.run_state.card_inventory.describe()["owned"].size() == 1, "collection replay cannot duplicate gear/card/save")
	var stage := c.reward_service.issue("fixture_stage", &"encounter_two", true)
	_check(stage["ok"] and stage["item_id"] == &"" and stage["card_id"] == &"" and stage["payload"]["base_xp"] == 150 and stage["payload"]["job_xp"] == 100, "per-mob mode replaces only stage equipment/card")
	_check(c.reward_service.collect(stage["ticket_id"])["ok"] and c.run_state.pending_choices == 1 and c.persistent_facade.current_profile().characters[0].base_xp_total == before_profile.characters[0].base_xp_total + 150 and profile.equipment_instances.size() == before_profile.equipment_instances.size() + 1, "encounter still gives XP and one augment choice")
	_check(F.disk(fixture).contains("bulwark_card") and not F.disk(fixture).contains("card_sockets") and profile.card_inventory.describe()["owned"].size() == 1, "card collection persists in its own validated schema field")
	c.run_state.reset()
	_check(c.run_state.card_inventory.describe()["owned"].size() == 1 and c.run_state.card_inventory.to_record() == c.persistent_facade.current_profile().card_inventory.to_record() and c.persistent_facade.current_profile().equipment_instances.size() == before_profile.equipment_instances.size() + 1, "run end preserves acquired cards and equipment")
	c.free()
