extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	_test_oracle()
	_test_costs_and_transactions()
	_test_milestones_and_sources()
	_test_skill_boundaries()
	print("Stat threshold rules: %s (%d checks, %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _test_oracle() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/fixtures/stat_threshold_reference.json"))
	_check(fixture["ruleset_id"] == ProfileState.RULESET_ID and int(fixture["catalog_version"]) == ProfileState.CATALOG_VERSION, "oracle tied to threshold contract")
	for row: Dictionary in fixture["builds"]:
		var origin := StringName(row["origin"])
		var allocated: Dictionary[StringName, int] = {}
		for stat_id: StringName in IdentityIds.attribute_ids():
			allocated[stat_id] = int(row["allocations"][str(stat_id)])
		var stats := StatCalculator.calculate(IdentityIds.initial_attributes(origin), allocated, int(row["level"]))
		_check(ProgressionRules.attribute_points_spent(allocated, origin) == int(row["spent"]), "independent oracle allocation price")
		for id: String in row["expected"]:
			_close(stats.value(StringName(id)), float(row["expected"][id]), "oracle %s L%d %s" % [origin, int(row["level"]), id])
	var level_file := FileAccess.open("res://docs/fixtures/stat_threshold_levels.csv", FileAccess.READ)
	level_file.get_csv_line()
	while not level_file.eof_reached():
		var line := level_file.get_csv_line()
		if line.size() < 5: continue
		_check(ProgressionRules.attribute_points_granted(int(line[1])) == int(line[3]), "every level matches independently simulated budget")
	level_file.close()
	_check(ProgressionRules.attribute_points_granted(0) == 0 and ProgressionRules.attribute_points_granted(999999) == 458, "XP clamps levels, not repeated grants")

func _test_costs_and_transactions() -> void:
	for current: int in range(1, 60):
		for amount: int in range(61-current):
			var sum_units := 0
			for offset: int in amount:
				sum_units += ProgressionRules.attribute_increment_cost(current+offset)
			_check(ProgressionRules.attribute_increment_cost(current, amount) == sum_units, "all batches equal exact unit purchase costs")
	_check(ProgressionRules.attribute_increment_cost(9,3) == 7 and ProgressionRules.attribute_increment_cost(10,2) == 5 and ProgressionRules.attribute_increment_cost(11) == 3, "x9/x0/x1 and classic destination boundary explicit")
	_check(ProgressionRules.attribute_increment_cost(60) == -1 and ProgressionRules.attribute_increment_cost(0) == -1 and ProgressionRules.attribute_increment_cost(5,-1) == -1, "invalid price requests fail closed")
	_check(ProgressionRules.attribute_increment_cost(8, 9223372036854775807) == -1 and ProgressionRules.attribute_increment_cost(9223372036854775807) == -1, "integer overflow cannot bypass the permanent cap")
	for origin: StringName in IdentityIds.base_class_ids():
		var batch := CharacterState.new("fixture", "Batch", origin)
		batch.base_xp_total = ProgressionRules.MAX_BASE_XP
		var unit := batch.copy_state()
		var paid := 0
		for stat_id: StringName in IdentityIds.attribute_ids():
			var before := batch.attribute_allocations.duplicate()
			var result := CharacterProgression.allocate_attributes(batch, {stat_id: 8})
			_check(result["ok"], "closed legal batch succeeds")
			for n: int in 8:
				var one := CharacterProgression.allocate_attributes(unit, {stat_id: 1})
				_check(one["ok"], "equivalent unit succeeds")
				paid += int(one["spent"])
			_check(batch.attribute_allocations == unit.attribute_allocations and before != batch.attribute_allocations, "unit and batch allocation identical")
		_check(ProgressionRules.attribute_points_spent(batch.attribute_allocations, origin) == paid, "price telescopes across every origin")
		var refunded := CharacterProgression.respec_attributes(batch)
		_check(refunded["ok"] and refunded["refunded"] == paid and CharacterProgression.respec_attributes(batch)["already_applied"], "respec refunds price not increment count exactly once")
	var poor := CharacterState.new("fixture", "Poor", &"swordsman")
	poor.base_xp_total = 100 #13 points, FOR8→14 costs15.
	var original := poor.attribute_allocations.duplicate()
	_check(not CharacterProgression.allocate_attributes(poor, {&"str": 6})["ok"] and poor.attribute_allocations == original, "unaffordable batch buys nothing")
	for bad: Dictionary in [{&"str": -1}, {&"str": true}, {&"str": 1.5}, {&"str": 9223372036854775807}, {&"banana": 1}, {&"str": 1, &"vit": 99}]:
		_check(not CharacterProgression.allocate_attributes(poor,bad)["ok"] and poor.attribute_allocations == original, "invalid mixed batch preserves whole vector")
	var aliases: Dictionary = {}
	aliases["str"] = 1
	aliases[&"str"] = 1
	# Godot may coalesce text/StringName keys; if distinct, reject rather than sum.
	if aliases.size() > 1:
		_check(not CharacterProgression.allocate_attributes(poor, aliases)["ok"], "duplicate normalized IDs fail closed")
	_check(CharacterProgression.allocate_attributes(poor, {})["already_applied"], "empty batch does not mutate")

func _test_milestones_and_sources() -> void:
	var file := FileAccess.open("res://docs/fixtures/stat_threshold_milestones.csv", FileAccess.READ)
	var header := file.get_csv_line()
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() != header.size(): continue
		var stat := StringName(line[0])
		var initial := IdentityIds.initial_attributes(&"swordsman")
		var value := int(line[2])
		initial[stat] = mini(60,value)
		var sources: Array[Dictionary] = []
		if value > 60:
			sources.append({"source_id": &"oracle_modifier", "primary_flat": {stat: value-60}})
		var stats := StatCalculator.calculate(initial, {}, 10, sources)
		for index: int in range(4,header.size()):
			_close(stats.value(StringName(header[index])), float(line[index]), "independent before/on/after milestone")
	file.close()
	var before := StatCalculator.calculate({&"str": 9, &"int": 5})
	var crossing := StatCalculator.calculate({&"str": 9, &"int": 5}, {}, 1, [{"source_id": &"fraction", "primary_flat": {&"str": 1.5, &"int": 1.0}, "flat": {&"melee_attack": 5.0}, "increased": {&"melee_attack": 0.3}}])
	_close(before.value(&"melee_attack"), 28.0, "below decade continuous")
	_close(crossing.value(&"melee_attack"), 48.1, "effective fractional crossing then flat then increased once")
	_close(crossing.value(&"sp_regen"), 2.92, "INT6 regen milestone independent of MATK")
	_check(StatCalculator.next_attribute_milestones(&"int", 9.5) == [10,12,14] and StatCalculator.next_attribute_milestones(&"vit", 10.0) == [15,20], "next distinct milestones authoritative after fractions")
	_check(StatCalculator.next_attribute_milestones(&"agi", 120.0).is_empty() and StatCalculator.next_attribute_milestones(&"banana",10.0).is_empty(), "no impossible milestone beyond effective cap")
	var capped := StatCalculator.calculate({&"agi": 60, &"dex": 60, &"luk": 60}, {}, 1, [{"source_id": &"clamp", "primary_flat": {&"agi": 999, &"dex": 999, &"luk": 999}, "flat": {&"crit_chance": 999, &"crit_resistance": 999, &"variable_cast_multiplier": -999}, "increased": {&"attacks_per_second": 9.0}}])
	_check(capped.primary_value(&"agi") == 120 and capped.value(&"attacks_per_second") == 4 and capped.value(&"attack_speed_index") == 400 and capped.value(&"crit_chance") == 0.75 and capped.value(&"crit_resistance") == 0.5 and capped.value(&"variable_cast_multiplier") == 0.25, "modifier crossings activate real primary and derived clamps")
	_close(capped.value(&"move_speed"), 220.0, "AGI never supplies movement")
	for stat: StringName in IdentityIds.attribute_ids():
		var previous: StatBreakdown = null
		for value: int in range(121):
			var stats := StatCalculator.calculate({stat: mini(60,value)}, {}, 1, [{"source_id": &"monotonic", "primary_flat": {stat: maxi(0,value-60)}}])
			if previous != null:
				for id: StringName in StatCalculator.DERIVED_IDS:
					_check(stats.value(id) <= previous.value(id) + 0.000001 if id == &"variable_cast_multiplier" else stats.value(id) >= previous.value(id)-0.000001, "all derived monotonic through every effective milestone")
			previous = stats

func _test_skill_boundaries() -> void:
	var stats := StatCalculator.calculate(IdentityIds.initial_attributes(&"archer"), {&"int": 20, &"dex": 20}, 10)
	var stronger := StatCalculator.calculate(IdentityIds.initial_attributes(&"archer"), {&"int": 20, &"dex": 20}, 10, [{"source_id": &"unrelated", "flat": {&"magic_attack": 999, &"crit_multiplier": 1.0}, "primary_flat": {&"str": 30.0, &"agi": 30.0, &"luk": 30.0}}])
	for id: StringName in [&"sentinel_net_shot", &"sentinel_explosive_shot", &"sentinel_piercing_shot"]:
		_close(SentinelMath.raw_power(id, 1,stats), SentinelMath.raw_power(id,1,stronger), "local INT/DES formulas exclude unrelated stats")
	var dex_only := StatCalculator.calculate(IdentityIds.initial_attributes(&"archer"), {&"int": 20, &"dex": 21}, 10)
	_close(SentinelMath.raw_power(&"sentinel_net_shot",1,stats), SentinelMath.raw_power(&"sentinel_net_shot",1,dex_only), "net remains INT-only")
	_close(SentinelMath.raw_power(&"sentinel_explosive_shot",1,stats), SentinelMath.raw_power(&"sentinel_explosive_shot",1,dex_only), "explosive remains INT-only")
	_close(SentinelMath.raw_power(&"sentinel_piercing_shot",1,dex_only)-SentinelMath.raw_power(&"sentinel_piercing_shot",1,stats), 1.4, "piercing DES remains local coefficient")
	_close(ClassCatalog.skill_definition(&"slash").rank_definition(1).power, 1.45, "oracle representative slash coefficient unchanged")
	_close(ClassCatalog.skill_definition(&"fireball").rank_definition(1).power, 1.8, "oracle fireball coefficient unchanged")
	_close(ClassCatalog.skill_definition(&"fireball").rank_definition(1).variable_cast_time, 0.32, "oracle cast timing unchanged")

func _close(actual: float, expected: float, label: String) -> void:
	_check(absf(actual-expected) < 0.00001, "%s expected %.6f got %.6f" % [label, expected, actual])

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
