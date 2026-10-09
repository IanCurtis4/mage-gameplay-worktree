class_name DamageRequest
extends RefCounted
## Runtime message, never serialized as a content Resource.

enum AccuracyMode { CONTESTED, GEOMETRY }

var source_id: int = 0
var target_id: int = 0
var skill_id: StringName = &"basic_attack"
## Runtime cast identity shared by copies/projectiles, never serialized.
var emission_id: int = 0
## Raw components captured when the action commits. Target defenses are read only
## on impact so projectiles and damage over time obey the E00 timing contract.
var physical_damage: float = 0.0
var magic_damage: float = 0.0
## Optional Elementalist passive power captured at commit; applied at impact
## only when that target's direct elemental sequence is ready.
var prismatic_resonance_damage: float = 0.0
## Hunter passive powers captured on bow emission, not from later actor stats.
## These are eligibility payloads, never added to the primary arrow damage.
var hunter_precision_damage: float = 0.0
var hunter_easy_prey_bonus: float = 0.0
var damage_dealt_multiplier: float = 1.0
var accuracy_mode: AccuracyMode = AccuracyMode.CONTESTED
var hit_rating: float = 0.0
var crit_chance: float = 0.0
var crit_multiplier: float = 1.5
var can_crit: bool = true
## Explicit impact rule used by fireball against a target already burning.
## It still requires a landed hit and can_crit=true.
var force_critical: bool = false
## E05 paid Rupture detonation keeps its declared contested test; never a proc.
var intrinsic_contested: bool = false
var cancelled: bool = false
var context: CombatEventContext
var effect_snapshot: Dictionary = {}
var _is_secondary: bool = false
var is_secondary: bool:
	get: return _is_secondary or (context != null and context.secondary)
	set(value):
		_is_secondary = value
		if value and context != null:
			context = context.secondary_prototype()

func copy() -> DamageRequest:
	var result := DamageRequest.new()
	result.source_id = source_id
	result.cancelled = cancelled
	result.intrinsic_contested = intrinsic_contested
	result.target_id = target_id
	result.skill_id = skill_id
	result.emission_id = emission_id
	result.physical_damage = physical_damage
	result.magic_damage = magic_damage
	result.prismatic_resonance_damage = prismatic_resonance_damage
	result.hunter_precision_damage = hunter_precision_damage
	result.hunter_easy_prey_bonus = hunter_easy_prey_bonus
	result.damage_dealt_multiplier = damage_dealt_multiplier
	result.accuracy_mode = accuracy_mode
	result.hit_rating = hit_rating
	result.crit_chance = crit_chance
	result.crit_multiplier = crit_multiplier
	result.can_crit = can_crit
	result.force_critical = force_critical
	result.context = context.copy_context() if context != null else null
	result.effect_snapshot = effect_snapshot.duplicate(true)
	result.is_secondary = is_secondary
	return result

func scheduled_tick() -> DamageRequest:
	var result := copy()
	if context != null:
		var tick := context.scheduled_tick()
		if tick == null:
			result.cancelled = true
		else:
			result.context = tick
	return result

func inherit_root(parent: CombatEventContext) -> void:
	if parent != null:
		context = parent.copy_context()
		context.event_id = 0
		context.parent_event_id = parent.event_id
		if is_secondary:
			context = context.secondary_prototype()

func child_request(parent: CombatEventContext, family: StringName, source: StringName, victim_id: int) -> DamageRequest:
	if parent == null or parent.ledger() == null:
		return null
	var claims := parent.ledger().claim_batch(parent, [{"family_id": family, "source_id": source, "target_id": victim_id}])
	if claims.is_empty():
		return null
	var child := copy()
	child.context = claims[0]["context"]
	child.target_id = victim_id
	child.is_secondary = true
	child.can_crit = false
	child.force_critical = false
	child.accuracy_mode = AccuracyMode.GEOMETRY
	return child

func requires_hit_roll() -> bool:
	return accuracy_mode == AccuracyMode.CONTESTED and (not is_secondary or (intrinsic_contested and skill_id == &"berserker_rupture_detonation" and (context == null or not context.proc_child)))
