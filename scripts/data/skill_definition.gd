class_name SkillDefinition
extends Resource
## Read-only catalog data. Cooldowns, levels and counts belong to run/actor state.

enum Targeting { DIRECTION, SINGLE_TARGET, POINT, SELF }
enum Category { ACTIVE, PASSIVE }
enum ActionKind { OFFENSIVE, MOBILITY, DEFENSIVE }
enum Handler {
	UNASSIGNED,
	SLASH,
	DASH,
	FIREBALL,
	FIRE_WALL,
	SPEAR,
	TELEPORT,
	SWORDSMAN_RESISTANCE,
	MAGE_SP_REGENERATION,
	DOUBLE_SHOT,
	PIERCING_ARROW,
	ARROW_RAIN,
	EXTENDED_AIM,
	SNARE_TRAP,
	EXPLOSIVE_TRAP,
	SLOWING_ARROW,
	FOLIAGE_SHELTER,
	ARCHER_PRECISION,
	ARCHER_CADENCE,
	TRAP_TECHNIQUE,
	LIGHTNING,
	ELECTRIC_DISCHARGE,
	LIGHTNING_WALL,
	SOUL_IMPACT,
	HAUNT,
	PHANTOM_BARRIER,
	ICE_WALL,
	SHIELD_WALL,
	PROVOKE,
	PERSEVERANCE,
	PIERCING_SHOUT,
	FURY,
	BRUTAL_STRIKE,
	CONCENTRATED_RAGE,
	TERRIFYING_SHOUT,
}

const MAX_ACTIVE_RANK := 5
const MAX_PASSIVE_RANK := 3

@export var id: StringName
@export var display_name: String
@export var input_key: String
@export var targeting: Targeting = Targeting.DIRECTION
@export var category: Category = Category.ACTIVE
@export var action_kind: ActionKind = ActionKind.OFFENSIVE
@export var handler_id: Handler = Handler.UNASSIGNED
@export var ranks: Array[SkillRankDefinition] = []
@export var accuracy_mode: DamageRequest.AccuracyMode = DamageRequest.AccuracyMode.CONTESTED
@export var can_crit: bool = false
@export var sp_cost: float = 0.0
@export var cooldown: float = 0.0
@export var cast_time: float = 0.0
@export var power: float = 0.0
@export var range: float = 0.0
@export var projectile_speed: float = 0.0

func is_rank_catalog_valid() -> bool:
	if category < Category.ACTIVE or category > Category.PASSIVE:
		return false
	if handler_id <= Handler.UNASSIGNED or handler_id > Handler.TERRIFYING_SHOUT:
		return false
	if action_kind < ActionKind.OFFENSIVE or action_kind > ActionKind.DEFENSIVE:
		return false
	var maximum_rank := MAX_ACTIVE_RANK if category == Category.ACTIVE else MAX_PASSIVE_RANK
	if ranks.is_empty() or ranks.size() > maximum_rank:
		return false
	for index: int in ranks.size():
		var definition := ranks[index]
		if definition == null or definition.rank != index + 1 or not definition.is_valid():
			return false
	return true

func rank_definition(rank: int) -> SkillRankDefinition:
	if not is_rank_catalog_valid() or rank < 1 or rank > ranks.size():
		return null
	return ranks[rank - 1].duplicate(true) as SkillRankDefinition
