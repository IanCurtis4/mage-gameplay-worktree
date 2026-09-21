extends SceneTree

var failures: int = 0

func _initialize() -> void:
	var base := StatCalculator.calculate({"str": 5, "vit": 5})
	_check(is_equal_approx(base.value(&"max_hp"), 150.0), "VIT changes max HP")
	_check(is_equal_approx(base.value(&"sp_regen"), 2.0), "base SP regeneration is part of derived stats")
	var equipment_sources: Array[Dictionary] = [{"source_id": &"equipment", "flat": {&"melee_attack": 10.0}, "increased": {&"melee_attack": 0.5}}]
	var equipped := StatCalculator.calculate({"str": 5}, {}, 1, equipment_sources)
	_check(is_equal_approx(equipped.value(&"melee_attack"), 45.0), "flat bonuses precede additive percentages")
	var cap_sources: Array[Dictionary] = [{"source_id": &"limits", "flat": {&"crit_chance": 10.0, &"variable_cast_multiplier": -10.0, &"attacks_per_second": 10.0}}]
	var capped := StatCalculator.calculate({}, {}, 1, cap_sources)
	_check(capped.value(&"crit_chance") == 0.75 and capped.value(&"variable_cast_multiplier") == 0.25 and capped.value(&"attacks_per_second") == 4.0, "extreme builds respect caps")
	var request := DamageRequest.new()
	request.physical_damage = 100.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.crit_chance = 0.5
	var hit := CombatMath.resolve(request, 100.0, 0.0, 0.0, 0.0, 0.0, 0.9)
	_check(hit["damage"] == 50, "defense mitigation")
	_check(CombatMath.resolve(request, 100.0, 0.0, 0.0, 0.0, 0.0, 0.1)["damage"] == 75, "critical follows mitigation")
	request.accuracy_mode = DamageRequest.AccuracyMode.CONTESTED
	request.hit_rating = 0.0
	var miss := CombatMath.resolve(request, 0.0, 0.0, 100.0, 0.0, 0.7, 0.0)
	_check(miss["damage"] == 0 and not miss["can_trigger_effects"], "miss has no damage or effects")
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.is_secondary = true
	var secondary := CombatMath.resolve(request, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9)
	_check(secondary["damage"] == 100 and not secondary["can_trigger_effects"], "secondary damage cannot recurse")
	request.physical_damage = 0.0
	_check(CombatMath.resolve(request, 0.0, 0.0, 0.0, 0.0, 0.0, 0.9)["damage"] == 0, "zero damage cannot manufacture one damage")
	request.physical_damage = 100.0
	request.is_secondary = false
	request.force_critical = true
	request.can_crit = true
	_check(CombatMath.resolve(request, 0.0, 0.0, 0.0, 0.0, 0.0, 0.99)["critical"], "explicit guaranteed critical still resolves through CombatMath")
	request.can_crit = false
	_check(not CombatMath.resolve(request, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0)["critical"], "guaranteed critical still respects can_crit")
	var augment := AugmentDefinition.new()
	augment.id = &"wide_slash"
	augment.effect_id = &"slash_radius"
	augment.class_id = &"swordsman"
	_check(augment.is_eligible(&"swordsman", 0), "eligible class can take augment")
	_check(not augment.is_eligible(&"mage", 0), "foreign class excluded")
	_check(not augment.is_eligible(&"swordsman", 1), "unique augment excluded after selection")
	var mage := ClassCatalog.class_definition(&"mage")
	_check(mage != null and mage.attributes["int"] == 9 and mage.skill_ids.size() == 5, "mage catalog defines attributes and five initial actions")
	var fireball := ClassCatalog.skill_definition(&"fireball")
	_check(fireball != null and fireball.range == 700.0 and fireball.projectile_speed == 680.0, "fireball tuning lives in immutable catalog data")
	var mage_run := RunState.new(&"mage")
	_check(mage_run.class_id == &"mage" and mage_run.skill_levels.size() == 6 and mage_run.skill_levels[&"teleport"] == 1, "new mage run owns independent level-one skill state")
	var swordsman_run := RunState.new()
	_check(swordsman_run.skill_levels.size() == 3 and not swordsman_run.skill_levels.has(&"fireball"), "class run states do not share foreign skills")
	_check(mage_run.projectile_count(&"fire_spear") == 1 and mage_run.projectile_count(&"ice_spear") == 1, "each spear runtime count starts independently at one")
	_check(ClassCatalog.skill_definition(&"fireball").cast_time > ClassCatalog.skill_definition(&"fire_spear").cast_time and ClassCatalog.skill_definition(&"teleport").cast_time == 0.0, "impact skills own short cast tuning while teleport stays instant")
	print("Foundation: %s" % ("PASS (20 checks)" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
