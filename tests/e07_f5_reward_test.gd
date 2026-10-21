extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var loaded := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(), true)
	var catalog: BuildEffectCatalog = loaded["catalog"]
	var occurrence := MobOccurrence.new()
	occurrence.occurrence_id = "fixture_reward_source"
	occurrence.mob_base_id = &"pilot_bulwark_species"
	occurrence.category_id = &"normal"
	var definition := catalog.mob_catalog().get_definition(occurrence.mob_base_id)
	occurrence.origin_id = StringName(definition.origin_levels.keys()[0]) if not definition.origin_levels.is_empty() else &"demo_arena"
	var created := MobLootResolver.create(catalog, EquipmentLootProfiles.production(catalog))
	check(created["ok"], "canonical loot resolver")
	var resolver: MobLootResolver = created["resolver"]
	var initial := resolver.roll(occurrence, [0.03, 0.5, 0.5, 0.5, 0.015])
	check(initial["ok"] and initial["equipment_drops"].size() == 1 and not StringName(initial["card_id"]).is_empty(), "initial generation preserves original equipment/card chances")
	var replacement := resolver.roll(occurrence, [0.03, 0.5, 0.5, 0.5, 0.015], 0.5, 0.5)
	check(replacement["ok"] and replacement["equipment_drops"].is_empty() and StringName(replacement["card_id"]).is_empty(), "reduction applies to both probability thresholds before rolling")
	var passed := resolver.roll(occurrence, [0.0, 0.5, 0.5, 0.5, 0.0], 0.5, 0.5)
	check(passed["equipment_drops"][0] == initial["equipment_drops"][0], "admitted drop keeps quality, ilvl, origin and sockets")
	occurrence.mob_base_id = &"test_gel"; occurrence.category_id = &"boss"; occurrence.origin_id = &"trial_stage_1"
	check(resolver.roll(occurrence, [1.0, 0.5, 0.5, 0.5, 1.0])["equipment_drops"].size() == 1, "initial guaranteed boss drop preserved")
	check(resolver.roll(occurrence, [1.0, 0.5, 0.5, 0.5, 1.0], 0.5, 0.5).get("error_code") == &"invalid_respawn_policy", "guaranteed categories cannot silently opt into replacement reduction")
	print("E07 F5 rewards: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
