class_name ExpeditionWaveClock
extends RefCounted
## Simulation time only. No wall clock or offline advancement.
var started := false
var remaining := 0.0
var interval := 900.0
var wave_index := 0

func arm() -> void:
	if started: return
	started = true
	remaining = interval

func advance(delta: float, frozen: bool = false) -> int:
	if frozen or not started or not is_finite(delta) or delta <= 0.0 or delta > float(EquipmentRules.MAX_EXACT_INTEGER - wave_index) * interval: return 0
	if delta < remaining:
		remaining -= delta
		return 0
	var excess := delta - remaining
	var count := 1 + int(floor(excess / interval))
	remaining = interval - fmod(excess, interval)
	wave_index += count
	return count

func penalize(seconds: float) -> bool:
	if not started: return false
	remaining = maxf(0.0, remaining - seconds)
	if remaining > 0.0: return false
	wave_index += 1
	remaining = interval
	return true

func valid() -> bool:
	return is_finite(interval) and interval > 0.0 and is_finite(remaining) and wave_index >= 0 and ((not started and remaining == 0.0 and wave_index == 0) or (started and remaining > 0.0 and remaining <= interval))
