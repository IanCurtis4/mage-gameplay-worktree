extends SceneTree

const FIXTURE_PATH := "res://docs/fixtures/e03_stats_reference.json"

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	var fixture := _load_fixture()
	if fixture.is_empty():
		quit(1)
		return
	_check(fixture.get("contract_version", "") == "stat_thresholds_v1", "stats matrix uses the stat thresholds contract")
	_test_shared_reference(fixture)
	for raw_case: Variant in fixture.get("cases", []):
		if not (raw_case is Dictionary):
			_check(false, "every stats matrix case is an object")
			continue
		if str(raw_case.get("id", "")) in ["swordsman_level_1", "mage_level_1", "archer_level_1"]:
			continue
		_test_case(raw_case as Dictionary)
	print("E03 Stat matrix: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d/%d checks)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_shared_reference(matrix: Dictionary) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/fixtures/e00_reference.json"))
	_check(parsed is Dictionary, "shared E00 reference is readable")
	if not (parsed is Dictionary):
		return
	var cases: Array = parsed.get("stats", [])
	_check(cases.size() == 3, "shared reference contains all three base classes")
	var expected_origins := {
		"swordsman": [8, 5, 8, 2, 5, 2],
		"mage": [2, 5, 5, 9, 7, 2],
		"archer": [3, 7, 5, 2, 10, 3],
	}
	var historical_values := {
		"swordsman": {"max_hp": 180, "melee_attack": 28, "variable_cast_multiplier": 0.983},
		"mage": {"max_hp": 150, "magic_attack": 30.8, "variable_cast_multiplier": 0.97},
		"archer": {"max_hp": 150, "precision_attack": 31.2, "variable_cast_multiplier": 0.968},
	}
	var matrix_by_id: Dictionary = {}
	for raw_case: Variant in matrix.get("cases", []):
		if raw_case is Dictionary:
			matrix_by_id[str(raw_case.get("id", ""))] = raw_case
	var ids := [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]
	for reference: Dictionary in cases:
		var class_id := str(reference.get("class_id", ""))
		_check(expected_origins.has(class_id), "E00 retains the historical %s origin entry" % class_id)
		if not expected_origins.has(class_id):
			continue
		_check(int(reference.get("level", 0)) == 1, "E00 %s historical level remains readable" % class_id)
		var historical_origin: Array = []
		for raw_value: Variant in reference.get("attributes", []):
			historical_origin.append(int(raw_value))
		_check(historical_origin == expected_origins[class_id], "E00 %s historical origin numbers remain readable" % class_id)
		var historical_expected: Variant = reference.get("expected", {})
		_check(historical_expected is Dictionary and (historical_expected as Dictionary).size() == 12, "E00 %s historical derived numbers remain readable" % class_id)
		if historical_expected is Dictionary:
			for raw_stat: Variant in historical_values[class_id]:
				_close(
					float(historical_expected.get(raw_stat, NAN)),
					float(historical_values[class_id][raw_stat]),
					"E00 %s historical %s" % [class_id, raw_stat]
				)
			for raw_value: Variant in (historical_expected as Dictionary).values():
				_check(typeof(raw_value) == TYPE_INT or typeof(raw_value) == TYPE_FLOAT, "E00 %s historical expected values remain numeric" % class_id)
		var matrix_case_id := "%s_level_1" % class_id
		_check(matrix_by_id.has(matrix_case_id), "E03 matrix has a replacement case for %s" % class_id)
		if not matrix_by_id.has(matrix_case_id):
			continue
		var matrix_case: Dictionary = matrix_by_id[matrix_case_id]
		var initial: Dictionary = {}
		for index: int in ids.size():
			initial[String(ids[index])] = int(reference["attributes"][index])
		_check(_integer_values(matrix_case.get("initial", {})) == initial, "E03 %s case uses the E00 historical origin vector" % class_id)
		_test_case(matrix_case)

func _load_fixture() -> Dictionary:
	var file := FileAccess.open(FIXTURE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open %s" % FIXTURE_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Stats matrix fixture is not a JSON object")
		return {}
	return parsed as Dictionary

func _test_case(test_case: Dictionary) -> void:
	var case_id := str(test_case.get("id", "<unnamed>"))
	# JSON numbers are parsed as floats by Godot; the public API intentionally
	# requires integer initial values and allocations.
	var initial := _integer_values(test_case.get("initial", {}))
	var allocations := _integer_values(test_case.get("allocations", {}))
	var base_level := int(test_case.get("base_level", 1))
	var result: Dictionary = StatCalculator.try_calculate(
		initial,
		allocations,
		base_level,
		_sources(test_case.get("sources", []))
	)
	_check(result.get("ok", false), "%s calculates successfully" % case_id)
	if not result.get("ok", false):
		return

	var breakdown: StatBreakdown = result["breakdown"]
	_check(breakdown.base_level == base_level, "%s preserves base level" % case_id)
	var expected_primary := test_case.get("expected", {}).get("primary", {}) as Dictionary
	for raw_id: Variant in expected_primary:
		_close(
			breakdown.primary_value(StringName(raw_id)),
			float(expected_primary[raw_id]),
			"%s primary %s" % [case_id, raw_id]
		)
	var expected_derived := test_case.get("expected", {}).get("derived", {}) as Dictionary
	for raw_id: Variant in expected_derived:
		_close(
			breakdown.value(StringName(raw_id)),
			float(expected_derived[raw_id]),
			"%s derived %s" % [case_id, raw_id]
		)

func _sources(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (value is Array):
		return result
	for raw_source: Variant in value:
		if raw_source is Dictionary:
			result.append(raw_source as Dictionary)
	return result

func _integer_values(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	for raw_id: Variant in value:
		result[raw_id] = int(value[raw_id])
	return result

func _close(actual: float, expected: float, label: String, epsilon: float = 0.00001) -> void:
	_check(absf(actual - expected) <= epsilon, "%s — expected %.6f, got %.6f" % [label, expected, actual])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
