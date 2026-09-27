extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	var active_ids: Array[StringName] = [
		&"elementalist_flame_burst", &"elementalist_glacial_ring", &"elementalist_lightning_arc",
		&"elementalist_ember_path", &"elementalist_tri_nova",
	]
	var passive_ids: Array[StringName] = [&"elementalist_prismatic_focus", &"elementalist_prismatic_resonance"]
	for skill_id: StringName in active_ids + passive_ids:
		var definition := ClassCatalog.skill_definition(skill_id)
		_check(definition != null and definition.is_rank_catalog_valid(), "%s has a valid immutable rank catalog" % skill_id)
		if definition != null:
			_check(definition.handler_id > SkillDefinition.Handler.BERSERKER_BREATH_STEAL, "%s uses an Elementalist-specific handler" % skill_id)
	_check(ClassCatalog.skill_ids(&"mage") == [&"fireball", &"fire_wall", &"fire_spear", &"ice_spear", &"teleport"], "Elementalist IDs do not enter initial Mage slots")
	_check(ClassCatalog.skill_definition(&"elementalist_flame_burst").handler_id == SkillDefinition.Handler.ELEMENTALIST_FLAME_BURST, "Flame Burst handler is stable")
	_check(ClassCatalog.skill_definition(&"elementalist_prismatic_focus").handler_id == SkillDefinition.Handler.ELEMENTALIST_PRISMATIC_FOCUS, "Prismatic Focus handler is stable")
	_check(ClassCatalog.skill_definition(&"elementalist_glacial_ring").handler_id == SkillDefinition.Handler.ELEMENTALIST_GLACIAL_RING, "Glacial Ring handler is stable")
	_check(ClassCatalog.skill_definition(&"elementalist_lightning_arc").handler_id == SkillDefinition.Handler.ELEMENTALIST_LIGHTNING_ARC, "Lightning Arc handler is stable")
	_check(ClassCatalog.skill_definition(&"elementalist_prismatic_resonance").handler_id == SkillDefinition.Handler.ELEMENTALIST_PRISMATIC_RESONANCE, "Prismatic Resonance handler is stable")
	_check(ClassCatalog.skill_definition(&"elementalist_ember_path").handler_id == SkillDefinition.Handler.ELEMENTALIST_EMBER_PATH, "Ember Path handler is stable")
	_check(ClassCatalog.skill_definition(&"elementalist_tri_nova").handler_id == SkillDefinition.Handler.ELEMENTALIST_TRI_NOVA, "Tri Nova handler is stable")
	for skill_id: StringName in active_ids:
		var definition := ClassCatalog.skill_definition(skill_id)
		_check(definition.category == SkillDefinition.Category.ACTIVE and definition.ranks.size() == 5, "%s exposes active R1-R5" % skill_id)
		_check(definition.rank_definition(0) == null and definition.rank_definition(6) == null, "%s rejects R0 and ranks above R5" % skill_id)
		var previous_power := -1.0
		for rank_number: int in range(1, 6):
			var rank := definition.rank_definition(rank_number)
			_check(rank != null and rank.rank == rank_number and rank.power > previous_power, "%s R%d grows in power" % [skill_id, rank_number])
			previous_power = rank.power if rank != null else previous_power
	_check_active(&"elementalist_flame_burst", [20.0, 22.0, 24.0, 25.0, 26.0], 6.0, 380.0, 0.45, [1.30, 1.50, 1.67, 1.82, 1.95])
	_check_active(&"elementalist_glacial_ring", [19.0, 21.0, 23.0, 24.0, 25.0], 8.0, 145.0, 0.35, [0.90, 1.05, 1.18, 1.29, 1.38])
	_check_active(&"elementalist_lightning_arc", [22.0, 24.0, 26.0, 27.0, 28.0], 8.0, 380.0, 0.35, [1.10, 1.25, 1.38, 1.49, 1.58])
	_check_active(&"elementalist_ember_path", [24.0, 26.0, 28.0, 29.0, 30.0], 10.0, 240.0, 0.50, [1.10, 1.25, 1.38, 1.49, 1.58])
	_check_active(&"elementalist_tri_nova", [30.0, 32.0, 34.0, 35.0, 36.0], 16.0, 170.0, 0.65, [0.70, 0.80, 0.88, 0.95, 1.01])
	_check_passive(&"elementalist_prismatic_focus", [2.0, 3.0, 4.0])
	_check_passive(&"elementalist_prismatic_resonance", [0.25, 0.35, 0.45])
	var arc := ClassCatalog.skill_definition(&"elementalist_lightning_arc")
	for rank_number: int in range(1, 6):
		_check(is_equal_approx(arc.rank_definition(rank_number).secondary_power, 0.40), "Lightning Arc R%d keeps marked-target bonus at 0.40" % rank_number)
	_check(&"chain_jump_power_0_60" in arc.rank_definition(1).effect_ids, "Lightning Arc records fixed 0.60 jump power")
	var copy := ClassCatalog.skill_definition(&"elementalist_flame_burst").rank_definition(1)
	copy.power = 99.0
	_check(is_equal_approx(ClassCatalog.skill_definition(&"elementalist_flame_burst").rank_definition(1).power, 1.30), "rank queries return isolated catalog copies")
	print("E05 Elementalista catalog: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_active(skill_id: StringName, costs: Array[float], cooldown: float, skill_range: float, cast_time: float, powers: Array[float]) -> void:
	var definition := ClassCatalog.skill_definition(skill_id)
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(rank != null and is_equal_approx(rank.sp_cost, costs[index]) and is_equal_approx(rank.cooldown, cooldown) and is_equal_approx(rank.range, skill_range) and is_equal_approx(rank.variable_cast_time, cast_time) and is_equal_approx(rank.power, powers[index]), "%s R%d preserves approved cost, range, cast and power" % [skill_id, index + 1])

func _check_passive(skill_id: StringName, powers: Array[float]) -> void:
	var definition := ClassCatalog.skill_definition(skill_id)
	_check(definition.category == SkillDefinition.Category.PASSIVE and definition.ranks.size() == 3, "%s exposes passive R1-R3" % skill_id)
	_check(definition.rank_definition(0) == null and definition.rank_definition(4) == null, "%s rejects invalid passive ranks" % skill_id)
	for index: int in 3:
		_check(is_equal_approx(definition.rank_definition(index + 1).power, powers[index]), "%s R%d stores approved passive power" % [skill_id, index + 1])

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
