class_name DamageRequest
extends RefCounted
## Runtime message, never serialized as a content Resource.

enum Kind { PHYSICAL, MAGIC }

var source_id: int = 0
var target_id: int = 0
var skill_id: StringName = &"basic_attack"
var kind: Kind = Kind.PHYSICAL
var base_damage: float = 0.0
var hit_chance: float = 1.0
var crit_chance: float = 0.0
var can_crit: bool = true
## Explicit impact rule used by fireball against a target already burning.
## It still requires a landed hit and can_crit=true.
var force_critical: bool = false
var is_secondary: bool = false

func copy() -> DamageRequest:
	var result := DamageRequest.new()
	result.source_id = source_id
	result.target_id = target_id
	result.skill_id = skill_id
	result.kind = kind
	result.base_damage = base_damage
	result.hit_chance = hit_chance
	result.crit_chance = crit_chance
	result.can_crit = can_crit
	result.force_critical = force_critical
	result.is_secondary = is_secondary
	return result
