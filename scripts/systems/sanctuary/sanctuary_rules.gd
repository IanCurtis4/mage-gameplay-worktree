class_name SanctuaryRules
extends RefCounted
## E09 T5 (C2) — Santuário/Graça family constants and the "rules inside" as data.
## Contract with the numbers: docs/epics/e09/t5_contract.md. Stateless.

const SHAPE_CIRCLE := &"circle"
const SHAPE_CONE := &"cone"
const SHAPE_WIDE_CIRCLE := &"wide_circle"
const SHAPES: Array[StringName] = [SHAPE_CIRCLE, SHAPE_CONE, SHAPE_WIDE_CIRCLE]

const ANCHOR_WORLD := &"world"
const ANCHOR_OWNER := &"owner"
const ANCHORS: Array[StringName] = [ANCHOR_WORLD, ANCHOR_OWNER]

const ELEMENT_NONE := &"none"
const ELEMENT_FIRE := &"fire"
const ELEMENT_ICE := &"ice"
const ELEMENT_LIGHTNING := &"lightning"
const ELEMENT_TRICOLOR := &"tricolor"
const ELEMENTS: Array[StringName] = [ELEMENT_NONE, ELEMENT_FIRE, ELEMENT_ICE, ELEMENT_LIGHTNING, ELEMENT_TRICOLOR]

# Zone defaults and ranges (t5_contract §2).
const CIRCLE_RADIUS := 130.0
const CIRCLE_RADIUS_RANGE := Vector2(80.0, 200.0)
const CONE_RADIUS := 160.0
const CONE_RADIUS_RANGE := Vector2(100.0, 220.0)
const CONE_HALF_ANGLE := deg_to_rad(55.0)
const CONE_HALF_ANGLE_RANGE := Vector2(deg_to_rad(35.0), deg_to_rad(80.0))
const WIDE_SCALE := 1.6
const WIDE_SCALE_RANGE := Vector2(1.2, 2.0)
const DURATION := 8.0
const DURATION_RANGE := Vector2(3.0, 15.0)
const PULSE_INTERVAL := 1.0
const PULSE_INTERVAL_RANGE := Vector2(0.5, 2.0)
const PRESENCE_INTERVAL := 0.25

# Grace (t5_contract §4).
const GRACE_CAP := 5
const GRACE_UNLIMITED_CEILING := 99
const GRACE_EXCESS_FRACTION := 0.08
const GRACE_EXCESS_FRACTION_RANGE := Vector2(0.04, 0.20)
const GRACE_DECAY_DELAY := 8.0
const GRACE_DECAY_INTERVAL := 2.0
const GRACE_GAIN_RANGE := Vector2i(1, 5)
const GRACE_EVENT_MEMORY := 128

# Helpers (t5_contract §5).
const JUDGMENT_PER_CHARGE := 0.40
const JUDGMENT_COLUMN_RADIUS := 45.0
const JUDGMENT_COLUMN_RADIUS_RANGE := Vector2(30.0, 90.0)
const JUDGMENT_COLUMN_HALF_HEIGHT := 200.0
const AEGIS_DURATION := 6.0
const AEGIS_PULSE_RADIUS := 120.0
const SEAL_DURATION := 6.0
const HEAL_BONUS_SOURCE := &"sanctuary_heal_bonus"
const SLOW_SOURCE := &"sanctuary_ice"
const LIGHT_ELEMENT := &"light"

## Rules inside a zone: key -> [default, minimum, maximum]. burn_stat is the only
## non-numeric key and is checked against BURN_STATS.
const RULES := {
	"owner_damage_taken": [0.80, 0.40, 1.00],
	"heal_multiplier": [1.25, 1.00, 2.00],
	"burn_ratio": [0.20, 0.00, 1.00],
	"fire_burn_multiplier": [1.50, 1.00, 3.00],
	"ice_defense": [0.15, 0.00, 0.50],
	"ice_slow": [0.25, 0.00, 0.50],
	"ice_slow_duration": [1.2, 0.5, 3.0],
	"lightning_sp_regen": [0.50, 0.00, 2.00],
}
const BURN_STATS: Array[StringName] = [&"magic_attack", &"melee_attack"]

static func failure(code: StringName, detail: String = "") -> Dictionary:
	return {"ok": false, "error_code": code, "detail": detail}

## Full rule set: defaults merged with the overrides. {"ok", "rules"} or a failure
## (`invalid_rules`) for an unknown key, a non-finite value or a value out of range.
static func validate_rules(overrides: Dictionary) -> Dictionary:
	var rules := {"burn_stat": &"magic_attack"}
	for key: String in RULES: rules[key] = float(RULES[key][0])
	for key: Variant in overrides:
		var name := String(key)
		var value: Variant = overrides[key]
		if name == "burn_stat":
			if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME] or StringName(value) not in BURN_STATS: return failure(&"invalid_rules", name)
			rules[name] = StringName(value)
			continue
		if not RULES.has(name) or typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)): return failure(&"invalid_rules", name)
		var limits: Array = RULES[name]
		if float(value) < float(limits[1]) or float(value) > float(limits[2]): return failure(&"invalid_rules", name)
		rules[name] = float(value)
	return {"ok": true, "error_code": &"", "rules": rules}

static func in_range(value: float, limits: Vector2) -> bool:
	return is_finite(value) and value >= limits.x - 0.0001 and value <= limits.y + 0.0001

static func has_fire(element: StringName) -> bool:
	return element == ELEMENT_FIRE or element == ELEMENT_TRICOLOR

static func has_ice(element: StringName) -> bool:
	return element == ELEMENT_ICE or element == ELEMENT_TRICOLOR

static func has_lightning(element: StringName) -> bool:
	return element == ELEMENT_LIGHTNING or element == ELEMENT_TRICOLOR

static func default_radius(shape: StringName) -> float:
	return CONE_RADIUS if shape == SHAPE_CONE else CIRCLE_RADIUS
