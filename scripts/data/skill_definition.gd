class_name SkillDefinition
extends Resource
## Read-only catalog data. Cooldowns, levels and counts belong to run/actor state.

enum Targeting { DIRECTION, SINGLE_TARGET, POINT }

@export var id: StringName
@export var display_name: String
@export var input_key: String
@export var targeting: Targeting = Targeting.DIRECTION
@export var mana_cost: float = 0.0
@export var cooldown: float = 0.0
@export var power: float = 0.0
@export var range: float = 0.0
@export var projectile_speed: float = 0.0

