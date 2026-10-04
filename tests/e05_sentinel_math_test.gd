extends SceneTree
var checks := 0
var failures := 0

func _initialize() -> void:
	var low := _stats(5, 5)
	var intelligence := _stats(55, 5)
	var dexterity := _stats(5, 55)
	for rank: int in range(1, 6):
		for id: StringName in [&"sentinel_net_shot", &"sentinel_explosive_shot"]:
			_check(is_equal_approx(SentinelMath.raw_power(id, rank, low), SentinelMath.raw_power(id, rank, dexterity)), "INT-only damage rejects DES/MATK leakage")
			_check(SentinelMath.raw_power(id, rank, intelligence) > SentinelMath.raw_power(id, rank, low), "INT increases per-use damage")
		for stats: StatBreakdown in [intelligence, dexterity]:
			_check(SentinelMath.raw_power(&"sentinel_piercing_shot", rank, stats) > SentinelMath.raw_power(&"sentinel_piercing_shot", rank, low), "Piercing adds INT and DES independently")
		for id: StringName in [&"sentinel_headshot", &"sentinel_concussion_shot"]:
			_check(SentinelMath.raw_power(id, rank, dexterity) > SentinelMath.raw_power(id, rank, intelligence), "precision shot uses physical precision")
		if rank > 1:
			for id: StringName in [&"sentinel_headshot", &"sentinel_concussion_shot", &"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot"]:
				_check(SentinelMath.raw_power(id, rank, low) > SentinelMath.raw_power(id, rank - 1, low), "offensive paid rank improves real damage")
	for id: StringName in [&"sentinel_piercing_shot", &"sentinel_net_shot", &"sentinel_explosive_shot"]:
		var high_cd := SentinelMath.cooldown(id, 10, dexterity)
		_check(high_cd < SentinelMath.cooldown(id, 10, low) and high_cd >= 7.5, "DES local cooldown reduction bounded")
		_check(is_equal_approx(SentinelMath.cooldown(id, 10, intelligence), SentinelMath.cooldown(id, 10, low)), "INT cannot reduce local cooldown")
	for id: StringName in [&"piercing_arrow", &"fireball", &"sentinel_headshot", &"sentinel_concussion_shot"]:
		_check(is_equal_approx(SentinelMath.cooldown(id, 10, dexterity), StatCalculator.effective_cooldown(10, dexterity)), "other skills preserve canonical cooldown")
	var source := SentinelMath.stance_source(3)
	var augmented := StatCalculator.calculate({&"str": 5, &"agi": 5, &"vit": 5, &"int": 5, &"dex": 5, &"luk": 5}, {}, 1, [source])
	_check(augmented.primary_value(&"dex") == 14 and augmented.primary_value(&"luk") == 11, "stance goes through the single stat authority")
	_check(SentinelMath.stance_source(0).is_empty() and SentinelMath.stance_source(4).is_empty(), "invalid passive ranks cannot grant stats")
	print("Sentinel S0 math: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _stats(intelligence: int, dexterity: int) -> StatBreakdown:
	return StatCalculator.calculate({&"str": 5, &"agi": 5, &"vit": 5, &"int": intelligence, &"dex": dexterity, &"luk": 5})

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
