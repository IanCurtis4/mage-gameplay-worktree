extends SceneTree

var failures: int = 0

func _initialize() -> void:
	_test_reference_classes()
	_test_level_scaling()
	_test_modifier_order_and_sources()
	_test_caps_and_special_aspd()
	_test_validation()
	_test_hit_crit_and_timing()
	print("E03 StatCalculator: %s" % ("PASS (39 checks)" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _test_reference_classes() -> void:
	var swordsman := StatCalculator.calculate(
		{&"str": 8, &"agi": 5, &"vit": 8, &"int": 2, &"dex": 5, &"luk": 2}
	)
	_close(swordsman.value(&"max_hp"), 180.0, "swordsman max_hp fixture")
	_close(swordsman.value(&"max_sp"), 50.0, "swordsman max_sp fixture")
	_close(swordsman.value(&"melee_attack"), 28.0, "swordsman melee fixture")
	_close(swordsman.value(&"precision_attack"), 23.2, "swordsman precision fixture")
	_close(swordsman.value(&"physical_defense"), 20.0, "swordsman physical defense fixture")
	_close(swordsman.value(&"hit_rating"), 111.4, "swordsman hit fixture")
	_close(swordsman.value(&"flee_rating"), 108.9, "swordsman flee fixture")
	_close(swordsman.value(&"crit_chance"), 0.0585, "swordsman crit fixture")

	var mage := StatCalculator.calculate(
		{&"str": 2, &"agi": 5, &"vit": 5, &"int": 9, &"dex": 7, &"luk": 2}
	)
	_close(mage.value(&"magic_attack"), 30.8, "mage magic fixture")
	_close(mage.value(&"magic_defense"), 20.5, "mage magic defense fixture")
	_close(mage.value(&"variable_cast_multiplier"), 0.97, "mage cast fixture")

	var archer := StatCalculator.calculate(
		{&"str": 3, &"agi": 7, &"vit": 5, &"int": 2, &"dex": 10, &"luk": 3}
	)
	_close(archer.value(&"precision_attack"), 31.2, "archer precision fixture")
	_close(archer.value(&"attacks_per_second"), 1.155, "archer aspd fixture")

func _test_level_scaling() -> void:
	var level_ten := StatCalculator.calculate(
		{&"str": 8, &"agi": 5, &"vit": 8, &"int": 2, &"dex": 5, &"luk": 2},
		{},
		10
	)
	_close(level_ten.value(&"max_hp"), 252.0, "base level scales HP")
	_close(level_ten.value(&"max_sp"), 77.0, "base level scales SP")
	_close(level_ten.value(&"hit_rating"), 120.4, "base level scales HIT")
	_close(level_ten.value(&"flee_rating"), 117.9, "base level participates in FLEE")

func _test_modifier_order_and_sources() -> void:
	var sources: Array[Dictionary] = [
		{
			"source_id": &"equipment:test",
			"label": "Fixture equipment",
			"primary_flat": {&"str": 2.5},
			"flat": {&"max_hp": 10.0, &"melee_attack": 5.0},
			"increased": {&"max_hp": 0.10, &"melee_attack": 0.10},
		},
		{
			"source_id": &"augment:test",
			"flat": {},
			"increased": {&"max_hp": 0.20, &"melee_attack": 0.20},
		},
	]
	var breakdown := StatCalculator.calculate(
		{&"str": 8, &"vit": 8, &"dex": 5},
		{},
		1,
		sources
	)
	_close(breakdown.primary_value(&"str"), 10.5, "primary flat may be fractional")
	# raw HP = 180; (180 + 10) * (1 + .10 + .20) = 247
	_close(breakdown.value(&"max_hp"), 247.0, "flat precedes additive increased modifiers")
	# raw melee with effective STR 10.5 and DEX 5 = 33; (33 + 5) * 1.3 = 49.4
	_close(breakdown.value(&"melee_attack"), 49.4, "derived values consume effective primaries once")
	_check(breakdown.sources().size() == 2, "identified modifier sources are preserved")
	_close(float(breakdown.derived_detail(&"max_hp")["increased"]), 0.30, "breakdown exposes summed increased")

func _test_caps_and_special_aspd() -> void:
	var primary_cap := StatCalculator.calculate(
		{&"str": 60},
		{},
		1,
		[{"source_id": &"buff:primary_cap", "primary_flat": {&"str": 100.0}}]
	)
	_close(primary_cap.primary_value(&"str"), 120.0, "primary effective value clamps at 120")

	var capped := StatCalculator.calculate(
		{&"agi": 60, &"dex": 60},
		{},
		1,
		[{
			"source_id": &"buff:caps",
			"flat": {&"move_speed": 1000.0},
			"increased": {&"attacks_per_second": 10.0},
		}]
	)
	_close(capped.value(&"move_speed"), 440.0, "move speed respects cap")
	_close(capped.value(&"attacks_per_second"), 4.0, "attacks per second respects cap")
	_close(capped.value(&"attack_speed_index"), 400.0, "ASPD index follows effective attacks per second")

func _test_validation() -> void:
	var bad_level := StatCalculator.try_calculate({}, {}, 31)
	_check(not bad_level["ok"] and bad_level["error_code"] == &"invalid_base_level", "invalid base level rejected")

	var bad_primary := StatCalculator.try_calculate({&"str": 61})
	_check(not bad_primary["ok"] and bad_primary["error_code"] == &"investment_cap_exceeded", "investment cap enforced before bonuses")

	var bad_id := StatCalculator.try_calculate({&"banana": 1})
	_check(not bad_id["ok"] and bad_id["error_code"] == &"invalid_stat_id", "unknown primary id rejected")

	var bad_modifier := StatCalculator.try_calculate(
		{},
		{},
		1,
		[{"source_id": &"bad:aspd", "flat": {&"attack_speed_index": 10.0}}]
	)
	_check(not bad_modifier["ok"] and bad_modifier["error_code"] == &"modifier_not_allowed", "ASPD index refuses direct modifiers")

	var bad_percentage := StatCalculator.try_calculate(
		{},
		{},
		1,
		[{"source_id": &"bad:primary_percent", "primary_increased": {&"str": 0.2}}]
	)
	_check(not bad_percentage["ok"] and bad_percentage["error_code"] == &"primary_percentage_not_allowed", "primary percentage modifiers rejected")

	var bad_number := StatCalculator.try_calculate(
		{},
		{},
		1,
		[{"source_id": &"bad:nan", "flat": {&"max_hp": NAN}}]
	)
	_check(not bad_number["ok"] and bad_number["error_code"] == &"non_finite_modifier", "non-finite modifiers rejected")

func _test_hit_crit_and_timing() -> void:
	_close(StatCalculator.contested_hit_chance(100.0, 100.0), 0.90, "equal HIT/FLEE gives 90 percent")
	_close(StatCalculator.contested_hit_chance(600.0, 100.0), 0.98, "hit chance upper cap")
	_close(StatCalculator.contested_hit_chance(100.0, 600.0), 0.05, "hit chance lower cap")
	_close(StatCalculator.effective_crit_chance(0.20, 0.05), 0.15, "crit resistance subtracts percentage points")

	var caster := StatCalculator.calculate({&"dex": 50, &"int": 20})
	_close(StatCalculator.effective_cast_time(0.2, 0.8, caster), 0.864, "fixed and variable cast use distinct reductions")
	_close(StatCalculator.effective_after_cast(1.0, caster), 1.0, "zero after-cast reduction preserves duration")
	_close(StatCalculator.effective_cooldown(5.0, caster), 5.0, "zero cooldown reduction preserves duration")

func _close(actual: float, expected: float, label: String, epsilon: float = 0.00001) -> void:
	_check(absf(actual - expected) <= epsilon, "%s — expected %.6f, got %.6f" % [label, expected, actual])

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
