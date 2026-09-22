class_name HardControlState
extends RefCounted
## Shared hard-control durations and boss budget. Families overlap without
## charging the same disabled interval twice.

const NORMAL_DURATION_CAP := 3.0
const BOSS_DURATION_CAP := 1.0
const BOSS_BUDGET := 2.0
const BOSS_WINDOW := 10.0

var boss := false
var unstoppable_remaining := 0.0
var boss_window_remaining := BOSS_WINDOW
var boss_budget_remaining := BOSS_BUDGET
var _family_remaining: Dictionary[StringName, float] = {}

func configure(is_boss: bool) -> void:
	boss = is_boss
	clear()

func apply(family: StringName, base_duration: float, resistance: float) -> float:
	if family.is_empty() or not is_finite(base_duration) or base_duration <= 0.0 or unstoppable_remaining > 0.0:
		return 0.0
	var duration_cap := BOSS_DURATION_CAP if boss else NORMAL_DURATION_CAP
	var effective_duration := minf(duration_cap, base_duration * (1.0 - clampf(resistance, 0.0, 0.5)))
	if effective_duration <= 0.0:
		return 0.0
	var current_family: float = _family_remaining.get(family, 0.0)
	var desired_family := maxf(current_family, effective_duration)
	if boss:
		var current_global := longest_remaining()
		var uncovered_duration := maxf(0.0, desired_family - current_global)
		if uncovered_duration > boss_budget_remaining:
			desired_family = maxf(current_family, current_global + boss_budget_remaining)
			uncovered_duration = boss_budget_remaining
		if desired_family <= current_family:
			return current_family
		boss_budget_remaining = maxf(0.0, boss_budget_remaining - uncovered_duration)
	_family_remaining[family] = desired_family
	return desired_family

func set_unstoppable(duration: float) -> bool:
	if not is_finite(duration) or duration <= 0.0:
		return false
	unstoppable_remaining = maxf(unstoppable_remaining, duration)
	return true

func remaining(family: StringName) -> float:
	return _family_remaining.get(family, 0.0)

func is_active(family: StringName) -> bool:
	return remaining(family) > 0.0

func longest_remaining() -> float:
	var longest := 0.0
	for duration: float in _family_remaining.values():
		longest = maxf(longest, duration)
	return longest

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	unstoppable_remaining = maxf(0.0, unstoppable_remaining - delta)
	for family: StringName in _family_remaining.keys():
		var remaining_duration := maxf(0.0, _family_remaining[family] - delta)
		if remaining_duration <= 0.0:
			_family_remaining.erase(family)
		else:
			_family_remaining[family] = remaining_duration
	if not boss:
		return
	var window_delta := delta
	while window_delta >= boss_window_remaining:
		window_delta -= boss_window_remaining
		boss_window_remaining = BOSS_WINDOW
		boss_budget_remaining = BOSS_BUDGET
	boss_window_remaining = maxf(0.0, boss_window_remaining - window_delta)

func clear() -> void:
	_family_remaining.clear()
	unstoppable_remaining = 0.0
	boss_window_remaining = BOSS_WINDOW
	boss_budget_remaining = BOSS_BUDGET
