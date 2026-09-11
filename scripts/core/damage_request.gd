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
var is_secondary: bool = false
