extends SceneTree

const FIXTURE_PATH := "res://docs/fixtures/e03_stats_reference.json"

var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_test_shared_reference()
	var fixture := _load_fixture()
	if fixture.is_empty():
		quit(1)
		return
	_check(fixture.get("contract_version", "") == "e00_v1", "stats matrix uses the accepted E00 ruleset")
	for raw_case: Variant in fixture.get("cases", []):
		if not (raw_case is Dictionary):
			_check(false, "every stats matrix case is an object")
			continue
		_test_case(raw_case as Dictionary)
	print("E03 Stat matrix: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d/%d checks)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _test_shared_reference() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://docs/fixtures/e00_reference.json"))
	_check(parsed is Dictionary, "shared E00 reference is readable")
	if not (parsed is Dictionary):
		return
	var cases: Array = parsed.get("stats", [])
	_check(cases.size() == 3, "shared reference contains all three base classes")
	var ids := [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]
	for reference: Dictionary in cases:
		var initial: Dictionary = {}
		for index: int in ids.size():
			initial[ids[index]] = int(reference["attributes"][index])
		_test_case({
			"id": "e00_%s" % reference["class_id"],
			"initial": initial,
			"base_level": int(reference["level"]),
			"expected": {"derived": reference["expected"]},
		})

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
