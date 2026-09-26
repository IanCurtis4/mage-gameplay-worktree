extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	var expected_ids: Array[StringName] = [
		&"defender_counterstroke", &"defender_watch", &"defender_anchor",
		&"defender_line_lock", &"defender_guard_return",
		&"defender_wall_advance", &"defender_reprisal_wave",
	]
	for skill_id: StringName in expected_ids:
		var definition := ClassCatalog.skill_definition(skill_id)
		_check(definition != null, "%s is registered in the immutable skill catalog" % skill_id)
		if definition == null:
			continue
		_check(definition.is_rank_catalog_valid(), "%s has a continuous, valid rank table" % skill_id)
		_check(
			definition.category == SkillDefinition.Category.PASSIVE
				if skill_id in [&"defender_watch", &"defender_guard_return"]
				else definition.category == SkillDefinition.Category.ACTIVE,
			"%s uses the approved active/passive category" % skill_id
		)
	_check(ClassCatalog.skill_definition(&"defender_counterstroke").handler_id == SkillDefinition.Handler.DEFENDER_COUNTERSTROKE, "Counterstroke handler has its stable typed identifier")
	_check(ClassCatalog.skill_definition(&"defender_watch").handler_id == SkillDefinition.Handler.DEFENDER_WATCH, "Watch handler has its stable typed identifier")
	_check(ClassCatalog.skill_definition(&"defender_anchor").handler_id == SkillDefinition.Handler.DEFENDER_ANCHOR, "Anchor handler has its stable typed identifier")
	_check(ClassCatalog.skill_definition(&"defender_line_lock").handler_id == SkillDefinition.Handler.DEFENDER_LINE_LOCK, "Line Lock handler has its stable typed identifier")
	_check(ClassCatalog.skill_definition(&"defender_guard_return").handler_id == SkillDefinition.Handler.DEFENDER_GUARD_RETURN, "Guard Return handler has its stable typed identifier")
	_check(ClassCatalog.skill_definition(&"defender_wall_advance").handler_id == SkillDefinition.Handler.DEFENDER_WALL_ADVANCE, "Wall Advance handler has its stable typed identifier")
	_check(ClassCatalog.skill_definition(&"defender_reprisal_wave").handler_id == SkillDefinition.Handler.DEFENDER_REPRISAL_WAVE, "Reprisal Wave handler has its stable typed identifier")
	_check(ClassCatalog.skill_ids(&"swordsman") == [&"slash", &"dash"], "evolution-exclusive Defender skills do not become base Espadachim default slots")
	_check(ClassCatalog.skill_definition(&"defender_counterstroke").action_kind == SkillDefinition.ActionKind.OFFENSIVE, "Counterstroke closes Shield Wall as an offensive action")
	_check(ClassCatalog.skill_definition(&"defender_anchor").action_kind == SkillDefinition.ActionKind.DEFENSIVE, "Anchor preserves defensive posture")
	_check(ClassCatalog.skill_definition(&"defender_line_lock").action_kind == SkillDefinition.ActionKind.OFFENSIVE, "Line Lock is classified as offensive")
	_check(ClassCatalog.skill_definition(&"defender_wall_advance").action_kind == SkillDefinition.ActionKind.OFFENSIVE, "damaging Wall Advance is classified as offensive")
	_check(ClassCatalog.skill_definition(&"defender_reprisal_wave").action_kind == SkillDefinition.ActionKind.OFFENSIVE, "Reprisal Wave is classified as offensive")
	_check(ClassCatalog.skill_definition(&"defender_counterstroke").targeting == SkillDefinition.Targeting.DIRECTION, "Counterstroke captures directional aim")
	_check(ClassCatalog.skill_definition(&"defender_anchor").targeting == SkillDefinition.Targeting.POINT, "Anchor is ground targeted")
	_check(ClassCatalog.skill_definition(&"defender_wall_advance").targeting == SkillDefinition.Targeting.DIRECTION, "Wall Advance captures movement direction")
	_check(ClassCatalog.skill_definition(&"defender_reprisal_wave").targeting == SkillDefinition.Targeting.SELF, "Reprisal Wave defaults to self-centered targeting; actor may center it on the active Anchor")
	_check(ClassCatalog.skill_definition(&"defender_line_lock").accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "Line Lock uses shared geometry precision")
	_check(ClassCatalog.skill_definition(&"defender_counterstroke").accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "Counterstroke uses shared geometry precision")
	_check(ClassCatalog.skill_definition(&"defender_reprisal_wave").accuracy_mode == DamageRequest.AccuracyMode.GEOMETRY, "Reprisal Wave uses shared geometry precision")
	_check(ClassCatalog.skill_definition(&"defender_counterstroke").can_crit and ClassCatalog.skill_definition(&"defender_line_lock").can_crit and ClassCatalog.skill_definition(&"defender_wall_advance").can_crit and ClassCatalog.skill_definition(&"defender_reprisal_wave").can_crit, "direct Defender attacks retain critical hit eligibility")
	_check(ClassCatalog.skill_definition(&"defender_watch").ranks.size() == 3 and ClassCatalog.skill_definition(&"defender_guard_return").ranks.size() == 3, "passives expose only the three approved ranks")
	_check(ClassCatalog.skill_definition(&"defender_counterstroke").ranks.size() == 5 and ClassCatalog.skill_definition(&"defender_anchor").ranks.size() == 5 and ClassCatalog.skill_definition(&"defender_line_lock").ranks.size() == 5 and ClassCatalog.skill_definition(&"defender_wall_advance").ranks.size() == 5 and ClassCatalog.skill_definition(&"defender_reprisal_wave").ranks.size() == 5, "actives expose R1 through R5")
	_check_active_table(&"defender_counterstroke", [16.0, 18.0, 20.0, 21.0, 22.0], 6.0, [1.05, 1.25, 1.42, 1.56, 1.68], [120.0, 120.0, 120.0, 120.0, 120.0])
	_check_active_table(&"defender_anchor", [20.0, 22.0, 24.0, 25.0, 26.0], 12.0, [4.0, 4.5, 5.0, 5.5, 6.0], [150.0, 150.0, 150.0, 150.0, 150.0])
	_check_active_table(&"defender_line_lock", [18.0, 20.0, 22.0, 23.0, 24.0], 9.0, [0.70, 0.70, 0.70, 0.70, 0.70], [170.0, 170.0, 170.0, 170.0, 170.0])
	_check_active_table(&"defender_wall_advance", [22.0, 24.0, 26.0, 27.0, 28.0], 10.0, [0.80, 0.80, 0.80, 0.80, 0.80], [80.0, 95.0, 110.0, 120.0, 130.0])
	_check_active_table(&"defender_reprisal_wave", [24.0, 26.0, 28.0, 29.0, 30.0], 12.0, [0.60, 0.73, 0.84, 0.93, 1.00], [130.0, 130.0, 130.0, 130.0, 130.0])
	_check_passive_table(&"defender_watch", [0.08, 0.11, 0.14])
	_check_passive_table(&"defender_guard_return", [2.0, 3.0, 4.0])
	var line_lock := ClassCatalog.skill_definition(&"defender_line_lock")
	for index: int in 5:
		var rank := line_lock.rank_definition(index + 1)
		_check(rank != null and is_equal_approx(rank.secondary_power, [0.5, 0.6, 0.7, 0.8, 0.9][index]), "Line Lock R%s stores root duration independently from its fixed 0.70 ATK damage" % (index + 1))
	var counterstroke := ClassCatalog.skill_definition(&"defender_counterstroke")
	for index: int in 5:
		var rank := counterstroke.rank_definition(index + 1)
		_check(rank != null and is_equal_approx(rank.secondary_power, [0.30, 0.40, 0.50, 0.60, 0.70][index]), "Counterstroke R%s token damage bonus matches contract" % (index + 1))
	var wave := ClassCatalog.skill_definition(&"defender_reprisal_wave")
	for index: int in 5:
		var rank := wave.rank_definition(index + 1)
		_check(rank != null and is_equal_approx(rank.secondary_power, 0.35), "Reprisal Wave R%s token bonus remains 0.35 ATK" % (index + 1))
	var returned := counterstroke.rank_definition(1)
	returned.sp_cost = 999.0
	_check(counterstroke.rank_definition(1).sp_cost == 16.0, "queried Defender rank is an isolated copy of catalog data")
	_check(&"front_guard_1_2s_15pct_130deg" in counterstroke.rank_definition(1).effect_ids and &"damage_cone_90deg_120" in counterstroke.rank_definition(1).effect_ids, "Counterstroke rank describes approved static geometry and guard parameters")
	print("E05 Defendente catalog: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _check_active_table(skill_id: StringName, costs: Array[float], cooldown: float, powers: Array[float], ranges: Array[float]) -> void:
	var definition := ClassCatalog.skill_definition(skill_id)
	for index: int in 5:
		var rank := definition.rank_definition(index + 1)
		_check(
			rank != null
				and rank.rank == index + 1
				and is_equal_approx(rank.sp_cost, costs[index])
				and is_equal_approx(rank.cooldown, cooldown)
				and is_equal_approx(rank.power, powers[index])
				and is_equal_approx(rank.range, ranges[index]),
			"%s R%s matches approved cost, cooldown, rank axis and geometry" % [skill_id, index + 1]
		)

func _check_passive_table(skill_id: StringName, powers: Array[float]) -> void:
	var definition := ClassCatalog.skill_definition(skill_id)
	for index: int in 3:
		var rank := definition.rank_definition(index + 1)
		_check(rank != null and rank.rank == index + 1 and is_equal_approx(rank.power, powers[index]), "%s R%s matches approved passive rank value" % [skill_id, index + 1])

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
