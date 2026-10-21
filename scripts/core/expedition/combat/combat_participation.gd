class_name CombatParticipation
extends RefCounted
## Minimal local combat authority. Threat values and target selection remain F6.
var links: Dictionary[String, bool] = {}
var remaining := 0.0
var exit_delay := 5.0
var damage_since_tick := false

func hostile_damage() -> void:
	damage_since_tick = true
	remaining = exit_delay

func observe(hostile_links: Dictionary, delta: float, frozen: bool = false) -> void:
	if frozen or not is_finite(delta) or delta < 0.0: return
	links.clear()
	for id: String in hostile_links:
		if hostile_links[id]: links[id] = true
	if not links.is_empty():
		remaining = exit_delay
	else:
		remaining = maxf(0.0, remaining - delta)
	damage_since_tick = false

func active() -> bool:
	return not links.is_empty() or remaining > 0.0 or damage_since_tick

func valid() -> bool:
	return is_finite(remaining) and remaining >= 0.0 and remaining <= exit_delay and exit_delay == 5.0
