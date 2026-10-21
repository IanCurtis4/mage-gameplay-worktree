class_name CombatParticipation
extends RefCounted
## Local party participation. Links are independent of target and threat amount.
var links: Dictionary[String, bool] = {}
var remaining := 0.0
var exit_delay := 5.0
var damage_since_tick := false
var events: Dictionary[String, bool] = {}

func claim_event(event: String) -> bool:
	if event.is_empty() or events.has(event): return false
	events[event] = true
	return true

func hostile_damage(event: String = "") -> void:
	if not event.is_empty() and not claim_event(event): return
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
	for event: String in events:
		if event.is_empty() or not events[event]: return false
	return is_finite(remaining) and remaining >= 0.0 and remaining <= exit_delay and exit_delay == 5.0
