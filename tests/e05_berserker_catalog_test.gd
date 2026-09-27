extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	var catalog := ProfileCatalog.pilot()
	var ids: Array[StringName] = [
		&"berserker_rupture", &"berserker_obstinacy", &"berserker_wound_leap",
		&"berserker_execution", &"berserker_pursuit", &"berserker_blood_rift",
		&"berserker_breath_steal",
	]
	var gates: Array[int] = [20, 23, 25, 28, 31, 34, 37]
	var evolution := catalog.evolution_definition(&"berserker")
	_check(catalog.is_valid() and evolution != null and not evolution.content_ready and evolution.entry_skill_id == &"berserker_rupture" and evolution.exclusive_skill_ids == ids, "Berserker has a complete but unavailable exclusive library")
	var library := catalog.skill_ids_for_identity(&"swordsman", &"berserker")
	_check(&"slash" in library and library.slice(library.size() - 7) == ids and &"defender_counterstroke" not in library and &"berserker_rupture" not in catalog.skill_ids_for_identity(&"swordsman", &"defender"), "Berserker resolves only its own branch and inherited Swordsman skills")
	for index: int in ids.size():
		var id := ids[index]
		var metadata := catalog.skill_metadata(id)
		var definition := ClassCatalog.skill_definition(id)
		_check(not metadata.is_empty() and metadata["wallet"] == ProfileCatalog.EVOLUTION_WALLET and metadata["required_evolution_id"] == &"berserker" and metadata["rank_requirements"][1]["job_level"] == gates[index], "%s uses approved evolution wallet and job gate" % id)
		_check(definition != null and definition.is_rank_catalog_valid() and definition.ranks.size() == (3 if id in [&"berserker_obstinacy", &"berserker_pursuit"] else 5), "%s has a complete valid rank table" % id)
		_check(not catalog.skill_is_allowed(id, &"mage", &"berserker") and not catalog.skill_is_allowed(id, &"swordsman", &"defender"), "%s cannot leak into another origin or branch" % id)
	_check(not catalog.evolution_is_ready(&"berserker", &"swordsman"), "catalog-only Berserker cannot be selected in production")
	_check(ClassCatalog.skill_definition(&"berserker_wound_leap").action_kind == SkillDefinition.ActionKind.OFFENSIVE and ClassCatalog.skill_definition(&"berserker_blood_rift").rank_definition(1).variable_cast_time == 0.3, "Leap is offensive and Rift has approved variable preparation")
	_check_active(&"berserker_rupture", [17.0, 19.0, 21.0, 22.0, 23.0], [1.00, 1.12, 1.22, 1.31, 1.38], [0.40, 0.52, 0.63, 0.72, 0.80], 110.0, 5.0)
	_check_active(&"berserker_wound_leap", [18.0, 20.0, 22.0, 23.0, 24.0], [0.80, 0.96, 1.08, 1.17, 1.24], [], 140.0, 8.0)
	_check_active(&"berserker_execution", [22.0, 25.0, 27.0, 29.0, 30.0], [1.20, 1.40, 1.60, 1.75, 1.90], [0.40, 0.40, 0.40, 0.40, 0.40], 110.0, 9.0)
	_check_active(&"berserker_blood_rift", [21.0, 23.0, 25.0, 26.0, 27.0], [0.90, 0.90, 0.90, 0.90, 0.90], [0.10, 0.12, 0.14, 0.16, 0.18], 220.0, 9.0)
	_check_active(&"berserker_breath_steal", [18.0, 20.0, 22.0, 23.0, 24.0], [1.00, 1.08, 1.16, 1.23, 1.30], [0.15, 0.18, 0.21, 0.24, 0.27], 110.0, 12.0)
	_check_passive(&"berserker_obstinacy", [0.08, 0.11, 0.14])
	_check_passive(&"berserker_pursuit", [2.0, 3.0, 4.0])
	var copy := ClassCatalog.skill_definition(&"berserker_rupture").rank_definition(1)
	copy.power = 999.0
	_check(ClassCatalog.skill_definition(&"berserker_rupture").rank_definition(1).power == 1.0, "rank query does not mutate catalog data")
	print("E05 Berserker catalog: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_active(id: StringName, costs: Array[float], powers: Array[float], secondary: Array[float], skill_range: float, cooldown: float) -> void:
	var definition := ClassCatalog.skill_definition(id)
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank != null and is_equal_approx(rank.sp_cost, costs[index]) and is_equal_approx(rank.power, powers[index]) and is_equal_approx(rank.secondary_power, secondary[index] if index < secondary.size() else 0.0) and is_equal_approx(rank.range, skill_range) and is_equal_approx(rank.cooldown, cooldown), "%s R%s matches approved cost, damage and range" % [id, index + 1])

func _check_passive(id: StringName, powers: Array[float]) -> void:
	var definition := ClassCatalog.skill_definition(id)
	for index: int in 3:
		_check(is_equal_approx(definition.rank_definition(index + 1).power, powers[index]), "%s R%s matches approved passive value" % [id, index + 1])

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
