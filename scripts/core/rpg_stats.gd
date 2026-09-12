class_name RpgStats
extends RefCounted
## Pure stat calculation. Callers own current HP/mana and preserve their deficits
## when recalculating maxima; deriving stats must never heal a character.

const ATTRIBUTES := [&"str", &"agi", &"vit", &"int", &"dex", &"luk"]

static func derive(attributes: Dictionary, flat: Dictionary = {}, increased: Dictionary = {}) -> Dictionary:
	var strength := maxf(0.0, float(attributes.get("str", 0)))
	var agility := maxf(0.0, float(attributes.get("agi", 0)))
	var vitality := maxf(0.0, float(attributes.get("vit", 0)))
	var intelligence := maxf(0.0, float(attributes.get("int", 0)))
	var dexterity := maxf(0.0, float(attributes.get("dex", 0)))
	var luck := maxf(0.0, float(attributes.get("luk", 0)))
	var result: Dictionary = {
		"max_hp": 100.0 + 10.0 * vitality,
		"max_mana": 40.0 + 5.0 * intelligence,
		"physical_attack": 10.0 + 2.0 * strength,
		"magic_attack": 10.0 + 2.0 * intelligence,
		"defense": vitality,
		"attacks_per_second": 1.0 + 0.02 * agility,
		"hit_chance": 0.90 + 0.005 * dexterity,
		"cast_multiplier": 1.0 - 0.01 * dexterity,
		"crit_chance": 0.05 + 0.005 * luck,
		"move_speed": 220.0,
		"mana_regen_per_second": 6.0,
	}
	for key: String in result:
		result[key] = maxf(0.0, (float(result[key]) + float(flat.get(key, 0.0))) * (1.0 + float(increased.get(key, 0.0))))
	result["max_hp"] = maxf(1.0, result["max_hp"])
	result["hit_chance"] = clampf(result["hit_chance"], 0.05, 1.0)
	result["crit_chance"] = clampf(result["crit_chance"], 0.0, 0.75)
	result["cast_multiplier"] = clampf(result["cast_multiplier"], 0.25, 2.0)
	result["attacks_per_second"] = clampf(result["attacks_per_second"], 0.2, 4.0)
	return result
