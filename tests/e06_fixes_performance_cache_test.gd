extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var first := BuildContentLoader.load_catalog(true, false)
	var second := BuildContentLoader.load_catalog(true, false)
	_check(first["ok"] and second["ok"], "production catalogs load")
	var first_catalog: BuildEffectCatalog = first["catalog"]
	var second_catalog: BuildEffectCatalog = second["catalog"]
	var first_equipment := first_catalog.get_definition(&"equipment", &"arena_starter_staff") as EquipmentDefinition
	var second_equipment := second_catalog.get_definition(&"equipment", &"arena_starter_staff") as EquipmentDefinition
	_check(first_catalog != second_catalog and first_equipment != second_equipment, "registries and definitions are isolated")
	first_equipment.display_name = "alterado"
	_check(second_catalog.get_definition(&"equipment", &"arena_starter_staff").display_name != "alterado", "getter mutation does not leak")
	var injected := ProfileCatalog.pilot({&"fixture_blade": {"slot": &"main_hand", "allowed_base_classes": [&"swordsman"], "starter": false}})
	var injected_loaded := BuildContentLoader.load_catalog_for_profile(injected)
	_check(injected_loaded["ok"] and injected_loaded["catalog"].get_definition(&"equipment", &"fixture_blade") != null, "injected metadata is included")
	_check(second_catalog.get_definition(&"equipment", &"fixture_blade") == null, "fixture cannot pollute production cache")
	var pilot_a := ProfileCatalog.pilot()
	var pilot_b := ProfileCatalog.pilot()
	_check(pilot_a != pilot_b and pilot_a.is_valid() and pilot_b.is_valid(), "default profile copies remain valid")
	var original := pilot_b.skill_metadata(&"slash")
	var changed := pilot_a.skill_metadata(&"slash")
	changed["rank_requirements"][1]["job_level"] = 99
	_check(pilot_b.skill_metadata(&"slash") == original, "profile metadata getter is deep copied")
	pilot_a._skills[&"slash"]["rank_requirements"][1]["job_level"] = 99
	_check(not pilot_a.is_valid() and pilot_b.is_valid(), "sealed catalog validation observes external mutation without stale memo")
	var unextended := BuildContentLoader.load_catalog(false, false)
	_check(unextended["ok"] and unextended["catalog"].ids(&"equipment").size() < second_catalog.ids(&"equipment").size(), "progression flag remains keyed")
	var alternate := ProfileCatalog.pilot({&"fixture_blade": {"slot": &"main_hand", "allowed_base_classes": [&"mage"], "starter": false}})
	var alternate_loaded := BuildContentLoader.load_catalog_for_profile(alternate)
	var injected_item: EquipmentDefinition = injected_loaded["catalog"].get_definition(&"equipment", &"fixture_blade")
	var alternate_item: EquipmentDefinition = alternate_loaded["catalog"].get_definition(&"equipment", &"fixture_blade")
	_check(injected_item.allowed_origins == [&"swordsman"] and alternate_item.allowed_origins == [&"mage"], "same injected ID keeps each profile's metadata")
	var bare_snapshot := BuildSnapshot.new()
	_check(bare_snapshot._skill_catalog.is_valid(), "standalone snapshot initializes catalog on first access")
	var snapshot_copy := bare_snapshot.copy_snapshot()
	bare_snapshot._skill_catalog._skills[&"slash"]["rank_requirements"][1]["job_level"] = 99
	_check(snapshot_copy._skill_catalog.is_valid(), "snapshot copy owns its catalog")
	var gameplay := BuildContentLoader.load_catalog(true, true)
	var neutral := BuildContentLoader.load_catalog(true, false)
	_check(gameplay["ok"] and neutral["ok"], "behavior flag variants load")
	var gameplay_catalog: BuildEffectCatalog = gameplay["catalog"]
	var gameplay_mob: MobDefinition = gameplay_catalog.mob_catalog().get_definition(&"pilot_bulwark_species")
	var neutral_catalog: BuildEffectCatalog = neutral["catalog"]
	var neutral_mob: MobDefinition = neutral_catalog.mob_catalog().get_definition(&"pilot_bulwark_species")
	if gameplay_mob != null and neutral_mob != null:
		_check(gameplay_mob.aggro_radius != neutral_mob.aggro_radius, "behavior flag remains keyed")
	print("PERF_CACHE_TEST failures=", failures)
	quit(1 if failures > 0 else 0)


