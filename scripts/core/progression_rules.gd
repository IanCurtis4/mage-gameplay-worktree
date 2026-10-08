class_name ProgressionRules
extends RefCounted
## Accepted E00 progression curves used to validate persisted totals.

const MAX_BASE_LEVEL := 30
const MAX_JOB_LEVEL := 40
const UNEVOLVED_MAX_JOB_LEVEL := 20
const MAX_BASE_XP := 13050
const MAX_JOB_XP := 17940
const UNEVOLVED_MAX_JOB_XP := 4940
const EVOLUTION_MIN_BASE_XP := 1800
const EVOLUTION_MIN_JOB_XP := UNEVOLVED_MAX_JOB_XP

static func base_level_for_xp(total_xp: int) -> int:
	return _level_for_xp(total_xp, MAX_BASE_LEVEL, 100, 25)

static func job_level_for_xp(total_xp: int, evolved: bool) -> int:
	var cap := MAX_JOB_LEVEL if evolved else UNEVOLVED_MAX_JOB_LEVEL
	return _level_for_xp(total_xp, cap, 80, 20)

static func attribute_points_granted(total_xp: int) -> int:
	var granted := 0
	for reached_level: int in range(2, base_level_for_xp(total_xp) + 1):
		granted += 13 + floori(float(reached_level) / 5.0)
	return granted

static func legacy_attribute_points_granted(total_xp: int) -> int:
	# Decode known pre-threshold envelopes against THEIR budget, never today's.
	return 3 * (base_level_for_xp(total_xp) - 1)

static func attribute_increment_cost(permanent_value: int, amount: int = 1) -> int:
	if permanent_value < 1 or permanent_value > StatCalculator.INVESTED_ATTRIBUTE_MAX or amount < 0 or amount > StatCalculator.INVESTED_ATTRIBUTE_MAX - permanent_value:
		return -1
	var cost := 0
	for current: int in range(permanent_value, permanent_value + amount):
		cost += 2 + floori(float(current - 1) / 10.0)
	return cost

static func base_skill_points_granted(total_xp: int, evolved: bool) -> int:
	return mini(job_level_for_xp(total_xp, evolved), UNEVOLVED_MAX_JOB_LEVEL) - 1

static func evolution_skill_points_granted(total_xp: int, evolved: bool) -> int:
	return maxi(0, job_level_for_xp(total_xp, evolved) - UNEVOLVED_MAX_JOB_LEVEL)

static func skill_points_granted(wallet: StringName, total_xp: int, evolved: bool) -> int:
	match wallet:
		&"base":
			return base_skill_points_granted(total_xp, evolved)
		&"evolution":
			return evolution_skill_points_granted(total_xp, evolved)
	return 0

static func attribute_points_spent(allocations: Dictionary[StringName, int], base_class_id: StringName) -> int:
	var initial := IdentityIds.initial_attributes(base_class_id)
	if initial.is_empty():
		return -1
	var spent := 0
	for attribute_id: StringName in allocations:
		if not initial.has(attribute_id):
			return -1
		var cost := attribute_increment_cost(initial[attribute_id], allocations[attribute_id])
		if cost < 0:
			return -1
		spent += cost
	return spent

static func attribute_points_available(total_xp: int, allocations: Dictionary[StringName, int], base_class_id: StringName) -> int:
	var spent := attribute_points_spent(allocations, base_class_id)
	return attribute_points_granted(total_xp) - spent if spent >= 0 else -1

static func add_base_xp(current_xp: int, gained_xp: int) -> int:
	assert(current_xp >= 0 and gained_xp >= 0)
	return mini(MAX_BASE_XP, current_xp + gained_xp)

static func add_job_xp(current_xp: int, gained_xp: int, evolved: bool) -> int:
	assert(current_xp >= 0 and gained_xp >= 0)
	var cap := MAX_JOB_XP if evolved else UNEVOLVED_MAX_JOB_XP
	return mini(cap, current_xp + gained_xp)

static func _level_for_xp(total_xp: int, level_cap: int, first_cost: int, growth: int) -> int:
	var level := 1
	var remaining := maxi(0, total_xp)
	while level < level_cap:
		var cost := first_cost + growth * (level - 1)
		if remaining < cost:
			break
		remaining -= cost
		level += 1
	return level
