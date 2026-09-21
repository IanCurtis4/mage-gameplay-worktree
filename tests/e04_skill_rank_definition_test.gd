extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	var active := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 5)
	_check(active.is_rank_catalog_valid(), "active skill accepts continuous ranks one through five")
	var queried := active.rank_definition(3)
	_check(queried != null and queried.rank == 3 and queried.sp_cost == 13.0, "rank query returns the exact requested values")
	queried.sp_cost = 999.0
	_check(active.rank_definition(3).sp_cost == 13.0, "rank query returns an isolated copy instead of mutable catalog state")
	_check(active.rank_definition(0) == null and active.rank_definition(6) == null, "rank query rejects zero and values above the catalog")

	var passive := _skill(SkillDefinition.Category.PASSIVE, SkillDefinition.Handler.SLASH, 3)
	_check(passive.is_rank_catalog_valid(), "passive skill accepts continuous ranks one through three")
	passive.ranks.append(_rank(4))
	_check(not passive.is_rank_catalog_valid(), "passive skill rejects ranks above three")

	var unknown_handler := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 1)
	unknown_handler.handler_id = 999 as SkillDefinition.Handler
	_check(not unknown_handler.is_rank_catalog_valid(), "unknown handler is rejected")
	var unknown_category := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 1)
	unknown_category.category = 999 as SkillDefinition.Category
	_check(not unknown_category.is_rank_catalog_valid(), "unknown category is rejected")
	var duplicate := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 2)
	duplicate.ranks[1].rank = 1
	_check(not duplicate.is_rank_catalog_valid(), "duplicate rank is rejected")
	var hole := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 2)
	hole.ranks[1].rank = 3
	_check(not hole.is_rank_catalog_valid(), "rank holes are rejected")
	var zero := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 1)
	zero.ranks[0].rank = 0
	_check(not zero.is_rank_catalog_valid(), "rank zero is rejected")
	var excessive := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 6)
	_check(not excessive.is_rank_catalog_valid(), "active skill rejects ranks above five")

	var invalid_value := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 1)
	invalid_value.ranks[0].cooldown = -1.0
	_check(not invalid_value.is_rank_catalog_valid(), "negative execution values are rejected")
	var invalid_weights := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 1)
	invalid_weights.ranks[0].physical_weight = 0.7
	invalid_weights.ranks[0].magic_weight = 0.7
	_check(not invalid_weights.is_rank_catalog_valid(), "non-normalized damage weights are rejected")
	var duplicate_effect := _skill(SkillDefinition.Category.ACTIVE, SkillDefinition.Handler.SLASH, 1)
	duplicate_effect.ranks[0].effect_ids = [&"direct_damage", &"direct_damage"]
	_check(not duplicate_effect.is_rank_catalog_valid(), "duplicate typed effect IDs are rejected")

	var legacy := ClassCatalog.skill_definition(&"fireball")
	_check(legacy != null and legacy.sp_cost == 18.0 and legacy.power == 1.8, "legacy catalog fields remain available without consumer migration")
	print("E04 skill ranks: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _skill(category: SkillDefinition.Category, handler: SkillDefinition.Handler, rank_count: int) -> SkillDefinition:
	var definition := SkillDefinition.new()
	definition.category = category
	definition.handler_id = handler
	for rank: int in range(1, rank_count + 1):
		definition.ranks.append(_rank(rank))
	return definition

func _rank(rank: int) -> SkillRankDefinition:
	var definition := SkillRankDefinition.new()
	definition.rank = rank
	definition.sp_cost = 10.0 + rank
	definition.cooldown = 1.0
	definition.range = 100.0
	definition.power = 1.0
	definition.physical_weight = 1.0
	definition.effect_ids = [&"direct_damage"]
	return definition

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
