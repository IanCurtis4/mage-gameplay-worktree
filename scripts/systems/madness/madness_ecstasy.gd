class_name MadnessEcstasy
extends RefCounted
## E10a T4 (C2) — Êxtase: charges 0..5 on the owner (D4), +MATK and -SP cost per
## charge, more damage taken from 3 charges on, one charge lost per interval without
## gain. Player state: it survives the exact and the compact snapshot formats. Clocks
## advance only in tick() (forwarded from ClassKit.on_tick, never in pause).
## Event deduplication lives in MadnessAuthority (one ring for Madness and Ecstasy).

var charges := 0
var enabled := false
var idle_time := 0.0
var decay_remaining := MadnessRules.ECSTASY_DECAY_INTERVAL
var matk_per_charge := MadnessRules.ECSTASY_MATK_PER_CHARGE
var cost_per_charge := MadnessRules.ECSTASY_COST_PER_CHARGE
var onus_per_charge := MadnessRules.ECSTASY_ONUS_PER_CHARGE
var gained_total := 0

## Applies validated per-charge values (MadnessRules "ecstasy" options).
func configure(options: Dictionary) -> Dictionary:
	var checked := MadnessRules.validate("ecstasy", options)
	if not checked["ok"]: return checked
	matk_per_charge = float(checked["options"]["matk_per_charge"])
	cost_per_charge = float(checked["options"]["cost_per_charge"])
	onus_per_charge = float(checked["options"]["onus_per_charge"])
	return checked

## One charge (already deduplicated by the authority). Returns the charges added.
func gain() -> int:
	if not enabled: return 0
	idle_time = 0.0
	decay_remaining = MadnessRules.ECSTASY_DECAY_INTERVAL
	if charges >= MadnessRules.ECSTASY_CAP: return 0
	charges += 1
	gained_total += 1
	return 1

## Gameplay clock. Returns true when the charges changed.
func tick(delta: float) -> bool:
	if delta <= 0.0 or not is_finite(delta) or charges <= 0:
		if charges <= 0:
			idle_time = 0.0
			decay_remaining = MadnessRules.ECSTASY_DECAY_INTERVAL
		return false
	var before := idle_time
	idle_time += delta
	if idle_time < MadnessRules.ECSTASY_DECAY_DELAY: return false
	if before < MadnessRules.ECSTASY_DECAY_DELAY:
		decay_remaining = MadnessRules.ECSTASY_DECAY_INTERVAL - (idle_time - MadnessRules.ECSTASY_DECAY_DELAY)
	else:
		decay_remaining -= delta
	var changed := false
	while decay_remaining <= 0.0 and charges > 0:
		charges -= 1
		changed = true
		decay_remaining += MadnessRules.ECSTASY_DECAY_INTERVAL
	if charges <= 0: decay_remaining = MadnessRules.ECSTASY_DECAY_INTERVAL
	return changed

func active_charges() -> int:
	return charges if enabled else 0

func matk_bonus() -> float:
	return matk_per_charge * float(active_charges())

## SP cost after the charges (floor 0 by the seam).
func skill_cost(base_cost: float) -> float:
	if not is_finite(base_cost): return base_cost
	return maxf(0.0, base_cost * (1.0 - cost_per_charge * float(active_charges())))

func has_onus() -> bool:
	return active_charges() >= MadnessRules.ECSTASY_ONUS_FROM

## Damage taken multiplier of the onus: 1 + onus * (charges - 2) from 3 charges.
func damage_taken_multiplier() -> float:
	if not has_onus(): return 1.0
	return 1.0 + onus_per_charge * float(active_charges() - (MadnessRules.ECSTASY_ONUS_FROM - 1))

func reset() -> void:
	charges = 0
	idle_time = 0.0
	decay_remaining = MadnessRules.ECSTASY_DECAY_INTERVAL
