class_name MadnessRules
extends RefCounted
## E10a T4 (C2) — constants, ranges and option validation of the Madness family
## authority (Cultista family: base Acólito, Cultista, later the seven Acólito-affinity
## hybrids). Numbers: docs/epics/e10a/t4_contract.md. The user limits of D4 are
## constants, never options: Delirium cap 3, one Idol per owner, Ecstasy 0..5 with the
## onus from 3, one contagion hop, immunity after the boss Disorientation.

# --- Madness -------------------------------------------------------------------------
const THRESHOLD := 100.0
const HOLD_SECONDS := 4.0
const DECAY_PER_SECOND := 20.0
const EVENT_MEMORY := 256

# --- Delirium (D4) ---------------------------------------------------------------------
const DELIRIUM_CAP := 3
const DELIRIUM_DURATION := 5.0
const DELIRIUM_DURATION_RANGE := Vector2(2.0, 8.0)
const DELIRIUM_REASON := &"madness_delirium"

# --- Boss Disorientation ---------------------------------------------------------------
const DISORIENT_DURATION := 4.0
const DISORIENT_DURATION_RANGE := Vector2(2.0, 8.0)
const DISORIENT_DAMAGE_TAKEN := 1.20
const DISORIENT_DAMAGE_TAKEN_RANGE := Vector2(1.0, 1.6)
const DISORIENT_ACCURACY := 0.25
const DISORIENT_ACCURACY_RANGE := Vector2(0.0, 0.6)
const DISORIENT_MINION_CHANCE := 0.35
const DISORIENT_MINION_CHANCE_RANGE := Vector2(0.0, 1.0)
const DISORIENT_MINION_RADIUS := 110.0
const DISORIENT_MINION_RADIUS_RANGE := Vector2(60.0, 200.0)
const IMMUNITY := 12.0
const IMMUNITY_RANGE := Vector2(6.0, 30.0)
const DISORIENT_SOURCE := &"madness_disorientation"

# --- Ecstasy (D4) ----------------------------------------------------------------------
const ECSTASY_CAP := 5
const ECSTASY_ONUS_FROM := 3
const ECSTASY_MATK_PER_CHARGE := 0.04
const ECSTASY_COST_PER_CHARGE := 0.04
const ECSTASY_ONUS_PER_CHARGE := 0.08
const ECSTASY_PER_CHARGE_RANGE := Vector2(0.0, 0.08)
const ECSTASY_ONUS_RANGE := Vector2(0.0, 0.15)
const ECSTASY_DECAY_DELAY := 6.0
const ECSTASY_DECAY_INTERVAL := 3.0

# --- Idol (D4) -------------------------------------------------------------------------
const IDOL_TAG := &"madness_idol"
const IDOL_DRAWER := &"madness_idol"
## Flipbook ID reserved for a future authored Idol (C3.4 rule: <prefix><effect>).
const IDOL_FLIPBOOK_ID := &"cultist_impossible_idol"
const IDOL_REASON := &"madness_idol"
const IDOL_HP_FRACTION := 0.30
const IDOL_HP_FRACTION_RANGE := Vector2(0.10, 0.60)
const IDOL_DURATION := 8.0
const IDOL_DURATION_RANGE := Vector2(4.0, 15.0)
const IDOL_RADIUS := 180.0
const IDOL_RADIUS_RANGE := Vector2(100.0, 260.0)
const IDOL_TICK := 1.0
const IDOL_TICK_RANGE := Vector2(0.5, 2.0)
const IDOL_MADNESS := 8.0
const IDOL_MADNESS_RANGE := Vector2(1.0, 40.0)

# --- Contagion (D4: one hop) -----------------------------------------------------------
const CONTAGION_DURATION := 8.0
const CONTAGION_DURATION_RANGE := Vector2(2.0, 15.0)
const CONTAGION_FRACTION := 0.50
const CONTAGION_FRACTION_RANGE := Vector2(0.10, 1.0)
const CONTAGION_RADIUS := 140.0
const CONTAGION_RADIUS_RANGE := Vector2(80.0, 220.0)
const CONTAGION_PULSE := 25.0
const CONTAGION_PULSE_RANGE := Vector2(0.0, 100.0)

# --- Marks on the enemy (ActorMarks, owner = the player's instance ID) -----------------
const MARK_MADNESS := &"madness"
const MARK_HOLD := &"madness_hold"
const MARK_DELIRIUM := &"madness_delirium"
const MARK_DISORIENTED := &"madness_disoriented"
const MARK_IMMUNE := &"madness_immune"
const MARK_CONTAGION := &"madness_contagion"

# --- States reported by describe() -----------------------------------------------------
const STATE_NONE := &"none"
const STATE_PENDING := &"pending"
const STATE_DELIRIUM := &"delirium"
const STATE_DISORIENTED := &"disoriented"
const STATE_IMMUNE := &"immune"

## Default options of each feature (keys accepted by the authority calls).
const DISORIENT_DEFAULTS := {"duration": DISORIENT_DURATION, "damage_taken": DISORIENT_DAMAGE_TAKEN, "accuracy": DISORIENT_ACCURACY, "minion_chance": DISORIENT_MINION_CHANCE, "minion_radius": DISORIENT_MINION_RADIUS, "immunity": IMMUNITY, "bypass_immunity": false}
const IDOL_DEFAULTS := {"hp_fraction": IDOL_HP_FRACTION, "duration": IDOL_DURATION, "radius": IDOL_RADIUS, "tick": IDOL_TICK, "madness": IDOL_MADNESS}
const CONTAGION_DEFAULTS := {"duration": CONTAGION_DURATION, "fraction": CONTAGION_FRACTION, "radius": CONTAGION_RADIUS, "pulse": CONTAGION_PULSE}
const ECSTASY_DEFAULTS := {"matk_per_charge": ECSTASY_MATK_PER_CHARGE, "cost_per_charge": ECSTASY_COST_PER_CHARGE, "onus_per_charge": ECSTASY_ONUS_PER_CHARGE}

const _RANGES := {
	"disorient": {"duration": DISORIENT_DURATION_RANGE, "damage_taken": DISORIENT_DAMAGE_TAKEN_RANGE, "accuracy": DISORIENT_ACCURACY_RANGE, "minion_chance": DISORIENT_MINION_CHANCE_RANGE, "minion_radius": DISORIENT_MINION_RADIUS_RANGE, "immunity": IMMUNITY_RANGE},
	"idol": {"hp_fraction": IDOL_HP_FRACTION_RANGE, "duration": IDOL_DURATION_RANGE, "radius": IDOL_RADIUS_RANGE, "tick": IDOL_TICK_RANGE, "madness": IDOL_MADNESS_RANGE},
	"contagion": {"duration": CONTAGION_DURATION_RANGE, "fraction": CONTAGION_FRACTION_RANGE, "radius": CONTAGION_RADIUS_RANGE, "pulse": CONTAGION_PULSE_RANGE},
	"ecstasy": {"matk_per_charge": ECSTASY_PER_CHARGE_RANGE, "cost_per_charge": ECSTASY_PER_CHARGE_RANGE, "onus_per_charge": ECSTASY_ONUS_RANGE},
}

static func failure(code: StringName, detail: String = "") -> Dictionary:
	return {"ok": false, "error_code": code, "detail": detail}

static func in_range(value: float, bounds: Vector2) -> bool:
	return is_finite(value) and value >= bounds.x - 0.000001 and value <= bounds.y + 0.000001

## Merges `options` over the defaults of `feature` ("disorient", "idol", "contagion",
## "ecstasy"). Unknown keys or values outside the ranges refuse (invalid_options).
## Returns {"ok", "error_code", "detail", "options"}.
static func validate(feature: String, options: Dictionary) -> Dictionary:
	var defaults: Dictionary = {"disorient": DISORIENT_DEFAULTS, "idol": IDOL_DEFAULTS, "contagion": CONTAGION_DEFAULTS, "ecstasy": ECSTASY_DEFAULTS}.get(feature, {})
	if defaults.is_empty(): return failure(&"invalid_options", feature)
	var ranges: Dictionary = _RANGES[feature]
	var merged := defaults.duplicate(true)
	for key: Variant in options:
		var name := String(key)
		if not merged.has(name): return failure(&"invalid_options", "%s.%s" % [feature, name])
		var value: Variant = options[key]
		if typeof(merged[name]) == TYPE_BOOL:
			if typeof(value) != TYPE_BOOL: return failure(&"invalid_options", "%s.%s" % [feature, name])
			merged[name] = value
			continue
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not in_range(float(value), ranges[name]): return failure(&"invalid_options", "%s.%s=%s" % [feature, name, value])
		merged[name] = float(value)
	return {"ok": true, "error_code": &"", "detail": "", "options": merged}

static func delirium_duration_valid(seconds: float) -> bool:
	return in_range(seconds, DELIRIUM_DURATION_RANGE)
