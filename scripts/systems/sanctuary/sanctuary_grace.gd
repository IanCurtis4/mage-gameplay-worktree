class_name SanctuaryGrace
extends RefCounted
## E09 T5 (C2) — Graça: charges 0..cap (5), an unlimited mode for the peaks, the
## system's own source (excess healing measured after the heal) and a gain that is
## deduplicated per event. Event identity comes from the EffectProcLedger
## (root_event_id + event_id, the identity the ledger uses in apply_once) or from an
## explicit key for events without a causal context. Clocks advance only in tick().

var charges := 0
var cap := SanctuaryRules.GRACE_CAP
var unlimited_remaining := 0.0
## Excess healing (HP) waiting to become charges.
var excess_pool := 0.0
var excess_fraction := SanctuaryRules.GRACE_EXCESS_FRACTION
var idle_time := 0.0
var decay_remaining := SanctuaryRules.GRACE_DECAY_INTERVAL
var heal_serial := 0
var gained_total := 0
var spent_total := 0
var last_spend_key := ""
var last_spend_amount := 0
## Accepted event keys (bounded, oldest first).
var _claimed: Dictionary = {}
var _claim_order: Array[String] = []

func is_unlimited() -> bool:
	return unlimited_remaining > 0.0

func ceiling() -> int:
	return SanctuaryRules.GRACE_UNLIMITED_CEILING if is_unlimited() else cap

func can_spend(minimum: int = 1) -> bool:
	return minimum >= 0 and charges >= maxi(1, minimum)

## Event key of a gain. With a CombatEventContext (damage or hit result) the key is the
## ledger identity of that application; otherwise the explicit "key" of the event.
static func event_key(event: Dictionary, family: StringName) -> String:
	var context := event.get("context") as CombatEventContext
	if context != null and not context.root_event_id.is_empty():
		return "%s@%s#%d:%d" % [family, context.root_event_id, context.event_id, int(event.get("target_id", context.target_id))]
	var explicit := String(event.get("key", ""))
	return "%s@%s" % [family, explicit] if not explicit.is_empty() else ""

## Adds `amount` charges once per event. Returns the charges actually added (0 for a
## repeated or keyless event, an invalid amount or a full reserve).
func gain(event: Dictionary, amount: int = 1, family: StringName = &"grace") -> int:
	if amount < SanctuaryRules.GRACE_GAIN_RANGE.x or amount > SanctuaryRules.GRACE_GAIN_RANGE.y: return 0
	var key := event_key(event, family)
	if key.is_empty() or _claimed.has(key): return 0
	_remember(key)
	idle_time = 0.0
	decay_remaining = SanctuaryRules.GRACE_DECAY_INTERVAL
	var added := clampi(amount, 0, maxi(0, ceiling() - charges))
	charges += added
	gained_total += added
	return added

func has_claimed(event: Dictionary, family: StringName = &"grace") -> bool:
	return _claimed.has(event_key(event, family))

## The system's own source: excess healing (requested - applied, measured after the
## heal). Each `excess_fraction` of max HP accumulated becomes one charge.
func record_excess(requested: float, applied: float, max_hp: float) -> int:
	if not is_finite(requested) or not is_finite(applied) or max_hp <= 0.0: return 0
	var excess := maxf(0.0, requested - maxf(0.0, applied))
	if excess <= 0.0001: return 0
	heal_serial += 1
	excess_pool += excess
	var threshold := max_hp * excess_fraction
	var whole := int(floor(excess_pool / threshold + 0.000001))
	if whole <= 0: return 0
	excess_pool = maxf(0.0, excess_pool - threshold * whole)
	var added := 0
	var remaining_whole := whole
	var part := 0
	while remaining_whole > 0:
		var chunk := mini(remaining_whole, SanctuaryRules.GRACE_GAIN_RANGE.y)
		added += gain({"key": "heal:%d:%d" % [heal_serial, part]}, chunk)
		remaining_whole -= chunk
		part += 1
	return added

## Spends charges for one committed cast (call from on_cast_confirmed). The same
## commit (skill and kit_time) never spends twice. Returns the charges spent.
func spend_for_cast(cast: Dictionary, kit_time: float, minimum: int = 1, maximum: int = -1) -> int:
	var key := "%s@%.5f" % [String(cast.get("skill_id", &"")), kit_time]
	if key == last_spend_key: return last_spend_amount
	if not can_spend(minimum): return 0
	var spent := charges if maximum < 0 else mini(charges, maximum)
	charges -= spent
	spent_total += spent
	last_spend_key = key
	last_spend_amount = spent
	idle_time = 0.0
	decay_remaining = SanctuaryRules.GRACE_DECAY_INTERVAL
	return spent

func begin_unlimited(seconds: float) -> bool:
	if not is_finite(seconds) or seconds <= 0.0: return false
	unlimited_remaining = maxf(unlimited_remaining, seconds)
	return true

func end_unlimited() -> void:
	unlimited_remaining = 0.0
	charges = mini(charges, cap)

## Gameplay clock (never called in pause). `zone_active` holds the decay.
func tick(delta: float, zone_active: bool) -> void:
	if delta <= 0.0 or not is_finite(delta): return
	if unlimited_remaining > 0.0:
		unlimited_remaining = maxf(0.0, unlimited_remaining - delta)
		if unlimited_remaining <= 0.0: end_unlimited()
		return
	if zone_active or (charges <= 0 and excess_pool <= 0.0):
		if zone_active: idle_time = 0.0
		decay_remaining = SanctuaryRules.GRACE_DECAY_INTERVAL
		return
	var before := idle_time
	idle_time += delta
	if idle_time < SanctuaryRules.GRACE_DECAY_DELAY: return
	if before < SanctuaryRules.GRACE_DECAY_DELAY:
		excess_pool = 0.0
		decay_remaining = SanctuaryRules.GRACE_DECAY_INTERVAL - (idle_time - SanctuaryRules.GRACE_DECAY_DELAY)
	else:
		decay_remaining -= delta
	while decay_remaining <= 0.0 and charges > 0:
		charges -= 1
		decay_remaining += SanctuaryRules.GRACE_DECAY_INTERVAL
	if charges <= 0: decay_remaining = SanctuaryRules.GRACE_DECAY_INTERVAL

## Death of the owner: the unlimited mode ends and the reserve empties.
func reset_on_death() -> void:
	unlimited_remaining = 0.0
	charges = 0
	excess_pool = 0.0
	idle_time = 0.0
	decay_remaining = SanctuaryRules.GRACE_DECAY_INTERVAL

func _remember(key: String) -> void:
	_claimed[key] = true
	_claim_order.append(key)
	while _claim_order.size() > SanctuaryRules.GRACE_EVENT_MEMORY:
		_claimed.erase(_claim_order.pop_front())
