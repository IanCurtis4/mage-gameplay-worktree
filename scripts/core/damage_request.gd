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
var is_secondary: bool = false

func copy() -> DamageRequest:
	var result := DamageRequest.new()
	result.source_id = source_id
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
	result.is_secondary = is_secondary
	return result
