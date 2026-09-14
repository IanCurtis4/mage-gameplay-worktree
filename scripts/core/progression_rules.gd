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
	return 3 * (base_level_for_xp(total_xp) - 1)

static func base_skill_points_granted(total_xp: int, evolved: bool) -> int:
	return mini(job_level_for_xp(total_xp, evolved), UNEVOLVED_MAX_JOB_LEVEL) - 1

static func evolution_skill_points_granted(total_xp: int, evolved: bool) -> int:
	return maxi(0, job_level_for_xp(total_xp, evolved) - UNEVOLVED_MAX_JOB_LEVEL)

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
