extends SceneTree

var failures: int = 0

func _initialize() -> void:
	var base := RpgStats.derive({"str": 5, "vit": 5})
	_check(is_equal_approx(base["max_hp"], 150.0), "VIT changes max HP")
	_check(is_equal_approx(base["mana_regen_per_second"], 6.0), "base mana regeneration is part of derived stats")
	var equipped := RpgStats.derive({"str": 5}, {"physical_attack": 10.0}, {"physical_attack": 0.5})
	_check(is_equal_approx(equipped["physical_attack"], 45.0), "flat bonuses precede additive percentages")
	var capped := RpgStats.derive({"agi": 10000, "dex": 10000, "luk": 10000})
	_check(capped["crit_chance"] == 0.75 and capped["cast_multiplier"] == 0.25 and capped["attacks_per_second"] == 4.0, "extreme builds respect caps")
	var request := DamageRequest.new()
	request.base_damage = 100.0
	request.crit_chance = 0.5
	var hit := CombatMath.resolve(request, 100.0, 0.0, 0.9)
	_check(hit["damage"] == 50, "defense mitigation")
	_check(CombatMath.resolve(request, 100.0, 0.0, 0.1)["damage"] == 75, "critical follows mitigation")
	request.hit_chance = 0.5
	var miss := CombatMath.resolve(request, 0.0, 0.7, 0.0)
	_check(miss["damage"] == 0 and not miss["can_trigger_effects"], "miss has no damage or effects")
	request.is_secondary = true
	var secondary := CombatMath.resolve(request, 0.0, 0.0, 0.9)
	_check(secondary["damage"] == 100 and not secondary["can_trigger_effects"], "secondary damage cannot recurse")
	request.base_damage = 0.0
	_check(CombatMath.resolve(request, 0.0, 0.0, 0.9)["damage"] == 0, "zero damage cannot manufacture one damage")
	request.base_damage = 100.0
	request.is_secondary = false
	request.force_critical = true
	request.can_crit = true
	request.hit_chance = 1.0
	_check(CombatMath.resolve(request, 0.0, 0.0, 0.99)["critical"], "explicit guaranteed critical still resolves through CombatMath")
	request.can_crit = false
	_check(not CombatMath.resolve(request, 0.0, 0.0, 0.0)["critical"], "guaranteed critical still respects can_crit")
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
	_check(mage_run.class_id == &"mage" and mage_run.skill_levels.size() == 5 and mage_run.skill_levels[&"teleport"] == 1, "new mage run owns independent level-one skill state")
	var swordsman_run := RunState.new()
	_check(swordsman_run.skill_levels.size() == 2 and not swordsman_run.skill_levels.has(&"fireball"), "class run states do not share foreign skills")
	_check(mage_run.get_modifiers()["spear_count"] == 1, "spear runtime count starts at one")
	print("Foundation: %s" % ("PASS (19 checks)" if failures == 0 else "FAIL (%d)" % failures))
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
