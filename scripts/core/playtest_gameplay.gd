class_name PlaytestGameplay
extends RefCounted
## Six finite stages: immutable exposure data, separate from the legacy arena.
const STAGE_COUNT := 6
const LEVELS := [2, 4, 6, 9, 12, 15]
const AREA_NAMES := ["Campina dos Géis", "Bosque das Feras", "Ruínas do Núcleo"]
const BOUNDS := Rect2(80, 80, 2600, 1700)
const ENTRANCE := Vector2(300, 900)
const NORMAL_COUNTS := [8, 6, 7, 6, 6, 4]
const PILOTS: Array[StringName] = [&"pilot_bulwark_species", &"pilot_frost_species", &"pilot_precision_species", &"pilot_trail_species"]
const POSITIONS: Array[Vector2] = [Vector2(950,450),Vector2(1120,540),Vector2(1560,500),Vector2(1750,630),Vector2(970,1230),Vector2(1160,1340),Vector2(1660,1270),Vector2(1870,1390),Vector2(2350,950),Vector2(2420,1130)]
static func origin(stage: int) -> StringName:
	return StringName("trial_stage_%d" % stage)
static func origin_name(id: StringName) -> String:
	for stage: int in range(1, STAGE_COUNT + 1):
		if id == origin(stage): return "%s · etapa %d" % [AREA_NAMES[(stage - 1) / 2], stage]
	return "Arena demonstrativa" if id == &"demo_arena" else String(id)
static func obstacles(stage: int) -> Array[Rect2]:
	var area := (stage - 1) / 2
	if area == 0: return [Rect2(620,650,180,240),Rect2(1280,780,190,260),Rect2(2050,440,170,240),Rect2(2100,1250,180,220)]
	if area == 1: return [Rect2(650,620,180,260),Rect2(1280,430,180,240),Rect2(1360,1080,180,260),Rect2(2080,700,180,270)]
	return [Rect2(650,660,180,240),Rect2(1280,780,190,260),Rect2(2050,420,170,240),Rect2(2080,1260,180,230),Rect2(460,1320,170,160)]
static func reward_id(stage: int) -> StringName:
	return StringName("trial_reward_%d" % stage)
static func reward_definitions() -> Dictionary:
	var result := {}
	var amounts := [[100,80],[150,100],[200,140],[250,180],[300,220],[400,280]]
	for stage: int in range(1, STAGE_COUNT + 1):
		result[reward_id(stage)] = {"base_xp": amounts[stage - 1][0], "job_xp": amounts[stage - 1][1]}
	return result
static func spawns(stage: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	assert(stage >= 1 and stage <= STAGE_COUNT)
	var result: Array[Dictionary] = []
	for index: int in NORMAL_COUNTS[stage - 1]:
		var species: StringName = PILOTS[(stage + index) % PILOTS.size()] if index < 2 else &"test_gel"
		result.append({"species": species, "category": &"normal"})
	match stage:
		2: result.append({"species": &"test_gel", "category": &"rare"})
		3:
			result.append({"species": &"test_gel", "category": &"elite"})
			result.append({"species": &"pilot_echo_species", "category": &"elite"})
		4: result.append({"species": &"test_beast_master", "category": &"rare"})
		5:
			result.append({"species": &"test_gel", "category": &"rare_elite"})
			result.append({"species": &"test_beast_master", "category": &"elite"})
			result.append({"species": &"pilot_ember_species", "category": &"elite"})
		6:
			result.append({"species": &"test_beast_master", "category": &"rare_elite"})
			result.append({"species": &"test_gel", "category": &"boss"})
	for index: int in result.size():
		result[index]["position"] = POSITIONS[index] + Vector2(rng.randf_range(-32,32),rng.randf_range(-32,32))
	return result
