class_name EffectDefinition
extends Resource
## Declarative recipe: no code, Node, Callable or mutable run state.

enum Kind { STAT, SKILL_RULE, PROC, ACTIVE_GRANT, KIT_RULE }
enum Handler { STAT_MODIFIER, SKILL_SCALAR, PROJECTILE_COUNT, HIT_DAMAGE, ACTIVE_SKILL, KIT_POLICY }
enum Stacking { ADDITIVE, EXCLUSIVE }
enum Trigger { NONE, ON_HIT, ON_KILL, ON_CAST, ENCOUNTER_END }

@export var id: StringName
@export var unique_effect_id: StringName
@export var tags: Array[StringName] = []
@export var granted_skill_id: StringName
@export var granted_rank: int = 1
@export var family_id: StringName
@export var kind: Kind = Kind.STAT
@export var handler_id: Handler = Handler.STAT_MODIFIER
@export var stacking_mode: Stacking = Stacking.ADDITIVE
@export var conflict_group: StringName
@export var trigger: Trigger = Trigger.NONE
@export var target_skill_ids: Array[StringName] = []
@export var allowed_origins: Array[StringName] = []
@export var allowed_evolutions: Array[StringName] = []
@export var minimum_rank: int = 1
@export var channel: StringName = &"flat"
@export var axis: StringName
@export var unit: StringName
@export var magnitude: float = 0.0
@export var increased: float = 0.0
@export var limit: float = 0.0
@export var stack_values: Array[float] = []

func value_at(stacks: int) -> float:
	return stack_values[stacks - 1] if not stack_values.is_empty() and stacks > 0 and stacks <= stack_values.size() else magnitude * stacks

func capability() -> StringName:
	return {Handler.STAT_MODIFIER: &"stat", Handler.SKILL_SCALAR: &"skill_buff", Handler.PROJECTILE_COUNT: &"transformation", Handler.HIT_DAMAGE: &"proc", Handler.ACTIVE_SKILL: &"active_grant", Handler.KIT_POLICY: &"transformation"}.get(handler_id, &"unsupported")
