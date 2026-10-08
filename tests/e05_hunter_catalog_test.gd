extends SceneTree
## Closed catalog package coverage; this does not exercise Hunter runtime consumers.

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func _run() -> void:
	var catalog := ProfileCatalog.pilot()
	var hunter := catalog.evolution_definition(&"hunter")
	_check(catalog.is_valid(), "production profile catalog remains valid")
	_check(hunter != null and hunter.display_name == "Caçadora" and hunter.origin_class_id == &"archer", "Hunter evolution is the approved Caçadora identity from Arqueiro")
	_check(hunter != null and hunter.entry_skill_id == &"hunter_freezing_trap" and hunter.exclusive_skill_ids == HunterTuning.SKILL_IDS and hunter.content_ready, "H7 candidate exposes exactly the complete ordered Hunter library")
	_check(ProfileState.SCHEMA_VERSION == 2 and ProfileState.CATALOG_VERSION == 8, "Hunter bumps only catalog version, preserving save schema")
	_check(ClassCatalog.skill_ids(&"archer") == [&"double_shot", &"piercing_arrow", &"arrow_rain", &"extended_aim", &"snare_trap"], "Hunter skills do not leak into Archer's default actions")
	var gates: Array[int] = [20, 20, 23, 25, 28, 31, 34, 37]
	for index: int in HunterTuning.SKILL_IDS.size():
		var skill_id := HunterTuning.SKILL_IDS[index]
		var metadata := catalog.skill_metadata(skill_id)
		var definition := ClassCatalog.skill_definition(skill_id)
		var maximum := HunterTuning.max_rank(skill_id)
		var passive := skill_id in [&"hunter_shooting_discipline", &"hunter_easy_prey"]
		_check(not metadata.is_empty() and definition != null, "%s has profile metadata and execution definition" % skill_id)
		if definition == null:
			continue
		_check(metadata["allowed_base_classes"] == [&"archer"] and metadata["wallet"] == ProfileCatalog.EVOLUTION_WALLET and metadata["required_evolution_id"] == &"hunter", "%s is exclusive to the Hunter evolution wallet" % skill_id)
		_check(metadata["category"] == (ProfileCatalog.PASSIVE if passive else ProfileCatalog.ACTIVE) and metadata["max_purchased_rank"] == maximum - (1 if index == 0 else 0), "%s metadata has correct category and cap" % skill_id)
		_check(metadata["free_rank"] == (1 if index == 0 else 0), "%s free rank is exact" % skill_id)
		_check(metadata["rank_requirements"].size() == maximum, "%s has requirements for every legal rank" % skill_id)
		for rank_number: int in range(1, maximum + 1):
			_check(metadata["rank_requirements"][rank_number]["job_level"] == gates[index], "%s R%d has its fixed gate" % [skill_id, rank_number])
		var rank_cap := SkillDefinition.MAX_PASSIVE_RANK if passive else SkillDefinition.MAX_ACTIVE_RANK
		_check(definition.id == skill_id and definition.display_name != "" and definition.category == (SkillDefinition.Category.PASSIVE if passive else SkillDefinition.Category.ACTIVE), "%s typed class definition agrees with profile metadata" % skill_id)
		_check(definition.is_rank_catalog_valid() and definition.ranks.size() == maximum and maximum <= rank_cap, "%s has a continuous exact rank definition" % skill_id)
		_check(skill_id not in catalog.skill_ids_for_identity(&"archer") and skill_id in catalog.skill_ids_for_identity(&"archer", &"hunter") and skill_id not in catalog.skill_ids_for_identity(&"mage", &"mg_ar"), "%s library access follows identity" % skill_id)
		_check(HunterTuning.values(skill_id, 0).is_empty() and HunterTuning.values(skill_id, maximum + 1).is_empty(), "%s rejects invalid ranks without clamping" % skill_id)
		_check(not ClassCatalog.hunter_description(skill_id, 1).is_empty() and ClassCatalog.hunter_description(skill_id, 0).is_empty(), "%s has useful pt-BR tooltip and rejects invalid rank" % skill_id)
		for rank_number: int in range(1, maximum + 1):
			var tuning := HunterTuning.values(skill_id, rank_number)
			var resource := definition.rank_definition(rank_number)
			_check(resource != null and resource.is_valid() and resource.rank == rank_number and is_equal_approx(resource.sp_cost, tuning["sp_cost"]) and is_equal_approx(resource.cooldown, tuning["cooldown"]) and is_equal_approx(resource.range, tuning["range"]), "%s R%d resource matches tuning" % [skill_id, rank_number])
			for field: Variant in tuning:
				var value: Variant = tuning[field]
				_check((value is float or value is int) and is_finite(float(value)) and float(value) >= 0.0, "%s R%d %s is finite/nonnegative" % [skill_id, rank_number, field])
	_check(_close(HunterTuning.values(&"hunter_freezing_trap", 1)["base"], 12.0) and _close(HunterTuning.values(&"hunter_freezing_trap", 5)["int_coefficient"], 1.8), "freezing damage recipe uses approved base and INT coefficient")
	_check(_close(HunterTuning.values(&"hunter_freezing_trap", 5)["rank_factor"], 1.4) and _close(HunterTuning.values(&"hunter_thorn_trap", 5)["rank_factor"], 1.4), "new trap damage rank factor matches contract")
	_check(not HunterTuning.values(&"hunter_tar_trap", 5).has("base") and not HunterTuning.values(&"hunter_tar_trap", 5).has("int_coefficient"), "Tar field has no damage recipe")
	_check(HunterTuning.max_rank(&"unknown") == 0 and HunterTuning.values(&"unknown", 1).is_empty(), "unknown skills rejected")
	var covering_shot := ClassCatalog.skill_definition(&"hunter_covering_shot")
	_check(covering_shot.projectile_speed == 880.0 and covering_shot.can_crit and covering_shot.accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "Covering Shot uses bow flight speed, geometry accuracy, and critical hits")
	for rank_number: int in 5:
		_check(covering_shot.rank_definition(rank_number + 1).projectile_speed == 880.0, "Covering Shot R%d preserves base bow projectile speed" % (rank_number + 1))
	_check(HunterTuning.OPENING_DURATION == 4.0 and HunterTuning.STEP_DURATION == 1.5 and HunterTuning.STEP_COOLDOWN == 3.0 and HunterTuning.STEP_SPEED_BONUS == 0.25, "shared opening and movement constants match contract")
	_check(HunterTuning.EMISSION_LIFETIME == 12.0 and HunterTuning.EMISSION_CAP == 256 and HunterTuning.ACTIVATION_LIFETIME == 16.0 and HunterTuning.ACTIVATION_CAP == 256 and HunterTuning.OPENING_CAP == 32, "bounded ledgers match contract")
	_assert_overrides()
	_assert_immutability()
	for evolution_id: StringName in [&"defender", &"berserker", &"elementalist", &"spiritualist", &"sentinel", &"mg_ar", &"sp_mg", &"sp_ar", &"mg_sp", &"ar_sp", &"ar_mg"]:
		var evolution := catalog.evolution_definition(evolution_id)
		_check(evolution != null and evolution.id == evolution_id, "other evolution identity remains registered: %s" % evolution_id)
		var expected_ready := evolution_id in [&"defender", &"berserker", &"elementalist", &"spiritualist", &"sentinel", &"mg_ar"]
		_check(evolution != null and evolution.content_ready == expected_ready, "other evolution readiness state is preserved: %s" % evolution_id)
	print("E05 Caçadora catalog: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _assert_overrides() -> void:
	var ready_override := ProfileCatalog.pilot({}, {}, {&"hunter": {"content_ready": true}})
	_check(ready_override.is_valid() and ready_override.evolution_definition(&"hunter").content_ready and ready_override.evolution_definition(&"hunter").exclusive_skill_ids == HunterTuning.SKILL_IDS, "content-only fixture override retains production metadata/library")
	var not_ready_override := ProfileCatalog.pilot({}, {}, {&"hunter": {"content_ready": false}})
	_check(not_ready_override.is_valid() and not not_ready_override.evolution_definition(&"hunter").content_ready and not not_ready_override.skill_metadata(&"hunter_freezing_trap").is_empty(), "false readiness override retains production definitions")
	var fixture_skills := {&"fixture_hunter_entry": {"allowed_base_classes": [&"archer"], "category": ProfileCatalog.ACTIVE, "wallet": ProfileCatalog.EVOLUTION_WALLET, "free_rank": 1, "max_purchased_rank": 4, "required_evolution_id": &"hunter"}}
	var replaced := ProfileCatalog.pilot({}, fixture_skills, {&"hunter": {"entry_skill_id": &"fixture_hunter_entry", "exclusive_skill_ids": [&"fixture_hunter_entry"], "content_ready": false}})
	_check(replaced.is_valid() and replaced.skill_metadata(&"hunter_freezing_trap").is_empty() and replaced.evolution_definition(&"hunter").exclusive_skill_ids == [&"fixture_hunter_entry"], "exclusive fixture replacement does not mix libraries")

func _assert_immutability() -> void:
	var values := HunterTuning.values(&"hunter_mark", 1)
	values["duration"] = 999.0
	_check(HunterTuning.values(&"hunter_mark", 1)["duration"] == 6.0, "tuning result is an isolated dictionary")
	var rank := ClassCatalog.skill_definition(&"hunter_freezing_trap").rank_definition(1)
	rank.effect_ids.clear()
	_check(not ClassCatalog.skill_definition(&"hunter_freezing_trap").rank_definition(1).effect_ids.is_empty(), "resource rank results do not mutate the catalog")
	var evolution := ProfileCatalog.pilot().evolution_definition(&"hunter")
	evolution.exclusive_skill_ids.clear()
	_check(ProfileCatalog.pilot().evolution_definition(&"hunter").exclusive_skill_ids.size() == 8, "evolution definitions are returned as copies")

func _close(a: float, b: float) -> bool:
	return is_equal_approx(a, b)
