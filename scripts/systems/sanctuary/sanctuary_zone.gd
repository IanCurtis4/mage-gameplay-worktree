class_name SanctuaryZone
extends RefCounted
## E09 T5 (C2) — one Santuário zone: owner, role, shape, anchor, clocks, element
## and rules as data. Owned by a SanctuaryAuthority; never holds a Node. Membership
## uses the world geometry (WorldEffectArea, ground_connected: height counts) or, on
## the legacy flat arena, the arena positions. Numbers: docs/epics/e09/t5_contract.md.

var role: StringName = &""
var owner_id := 0
var shape: StringName = SanctuaryRules.SHAPE_CIRCLE
var base_radius := SanctuaryRules.CIRCLE_RADIUS
var radius := SanctuaryRules.CIRCLE_RADIUS
var half_angle := SanctuaryRules.CONE_HALF_ANGLE
var anchor_mode: StringName = SanctuaryRules.ANCHOR_WORLD
## Fixed anchor on the flat arena (world zones use `area`).
var center := Vector2.ZERO
var area: WorldEffectArea
var duration := SanctuaryRules.DURATION
var remaining := 0.0
var pulse_interval := SanctuaryRules.PULSE_INTERVAL
var pulse_remaining := SanctuaryRules.PULSE_INTERVAL
var pulses := 0
var element: StringName = SanctuaryRules.ELEMENT_NONE
var rules: Dictionary = {}
var skill_id: StringName = &""
## Causal family of the pulse ticks (claimed by HealthState per target and root).
var family_id: StringName = &""
## Secondary burn prototype captured at the cast commit (amount from the owner's stats).
var prototype: DamageRequest
var owner_inside := true
## Enemies found inside at the last pulse (presentation and tests).
var _inside: Dictionary = {}

func is_active() -> bool:
	return remaining > 0.0

func describe() -> Dictionary:
	return {"role": role, "shape": shape, "radius": radius, "half_angle": half_angle, "anchor_mode": anchor_mode, "element": element, "remaining": remaining, "duration": duration, "pulses": pulses, "owner_inside": owner_inside, "center": center if area == null else area.anchor().position}

## Changes the shape of an active zone without restarting its clocks. A zero radius
## keeps the base radius (circle, cone) or scales it by WIDE_SCALE (wide circle).
func set_shape(value: StringName, value_radius: float = 0.0) -> Dictionary:
	if value not in SanctuaryRules.SHAPES: return SanctuaryRules.failure(&"invalid_shape", String(value))
	if value == SanctuaryRules.SHAPE_CONE and anchor_mode != SanctuaryRules.ANCHOR_OWNER: return SanctuaryRules.failure(&"invalid_anchor", "cone is anchored on the owner")
	var resolved := value_radius
	if resolved <= 0.0: resolved = base_radius * (SanctuaryRules.WIDE_SCALE if value == SanctuaryRules.SHAPE_WIDE_CIRCLE else 1.0)
	if not is_finite(resolved) or resolved <= 0.0 or resolved > base_radius * SanctuaryRules.WIDE_SCALE_RANGE.y + 0.001: return SanctuaryRules.failure(&"invalid_radius", str(resolved))
	shape = value
	radius = resolved
	return {"ok": true, "error_code": &""}

func set_element(value: StringName) -> bool:
	if value not in SanctuaryRules.ELEMENTS: return false
	element = value
	return true

## Burn amount of one pulse for the current element (before defenses).
func pulse_amount() -> float:
	if prototype == null: return 0.0
	var amount := prototype.magic_damage
	if SanctuaryRules.has_fire(element): amount *= float(rules.get("fire_burn_multiplier", 1.0))
	return amount

## True when `actor` is inside the zone of `owner` (the owner of this zone).
## `owner_query_area` lets a caller reuse one owner area for many actors.
func contains(owner: PlayerActor, actor: CombatActor, owner_query_area: WorldEffectArea = null) -> bool:
	if not is_active() or not is_instance_valid(owner) or not is_instance_valid(actor) or not actor.is_alive(): return false
	if anchor_mode == SanctuaryRules.ANCHOR_OWNER and actor == owner: return true
	if owner.world_motion != null:
		var query_area := area
		if anchor_mode == SanctuaryRules.ANCHOR_OWNER: query_area = owner_query_area if owner_query_area != null else owner_area(owner)
		if query_area == null or not query_area.is_current_world() or not query_area.contains_actor(actor, radius): return false
		if shape != SanctuaryRules.SHAPE_CONE: return true
		var offset := actor.world_point().position - query_area.anchor().position
		offset.y = 0.0
		return _within_cone(Vector2(offset.x, offset.z), _ground_facing_2d(owner))
	var origin := center if anchor_mode == SanctuaryRules.ANCHOR_WORLD else owner.global_position
	var flat := actor.global_position - origin
	if flat.length() > radius + actor.collision_radius: return false
	return shape != SanctuaryRules.SHAPE_CONE or _within_cone(flat, owner.gameplay_facing())

## A fresh ground area at the owner's current point (owner-anchored zones in the world).
static func owner_area(owner: PlayerActor) -> WorldEffectArea:
	if owner.world_motion == null or not owner.world_motion.is_current_world(): return null
	var result := WorldEffectArea.new()
	var geometry: WorldGeometry = owner.world_motion.geometry
	return result if result.configure(geometry, owner.world_point(), owner.world_motion.profile(), &"ground_connected", geometry.geometry_revision)["ok"] else null

## A direct hit with this facing dot (pipeline hit["facing_dot"]) counts as frontal for the zone.
func covers_hit(facing_dot: float) -> bool:
	if shape != SanctuaryRules.SHAPE_CONE: return true
	return facing_dot >= cos(half_angle) - 0.0001

func _within_cone(offset: Vector2, facing: Vector2) -> bool:
	if offset.length() <= 0.001: return true
	if facing.is_zero_approx(): return false
	return absf(facing.angle_to(offset)) <= half_angle + 0.0001

static func _ground_facing_2d(owner: PlayerActor) -> Vector2:
	var facing := owner.gameplay_ground_facing()
	return Vector2(facing.x, facing.z)
