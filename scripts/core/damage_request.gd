class_name DamageRequest
extends RefCounted
## Runtime message, never serialized as a content Resource.

enum AccuracyMode { CONTESTED, GEOMETRY }

var source_id: int = 0
var target_id: int = 0
var skill_id: StringName = &"basic_attack"
## Raw components captured when the action commits. Target defenses are read only
## on impact so projectiles and damage over time obey the E00 timing contract.
var physical_damage: float = 0.0
var magic_damage: float = 0.0
var damage_dealt_multiplier: float = 1.0
var accuracy_mode: AccuracyMode = AccuracyMode.CONTESTED
var hit_rating: float = 0.0
var crit_chance: float = 0.0
var crit_multiplier: float = 1.5
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
	result.physical_damage = physical_damage
	result.magic_damage = magic_damage
	result.damage_dealt_multiplier = damage_dealt_multiplier
	result.accuracy_mode = accuracy_mode
	result.hit_rating = hit_rating
	result.crit_chance = crit_chance
	result.crit_multiplier = crit_multiplier
	result.can_crit = can_crit
	result.force_critical = force_critical
	result.is_secondary = is_secondary
	return result
