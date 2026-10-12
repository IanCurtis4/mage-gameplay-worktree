class_name MobDefinition
extends Resource
## Species identity and fixed stats. Occurrence category is a separate axis.
@export var id: StringName
@export var display_name: String
@export var base_category: StringName = &"normal"
@export var allowed_occurrence_categories: Array[StringName] = [&"normal"]
@export var fixed_level: int = 1
@export var primary_attributes: Dictionary = {}
@export var modifier_sources: Array[Dictionary] = []
@export var archetype: StringName = &"chaser"
@export var animation_kind: StringName = &"warrior"
@export var tint: Color = Color("c65a68")
@export var collision_radius: float = 19.0
@export var skill_ranks: Dictionary = {}
@export var skill_ids: Array[StringName] = []
@export var card_id: StringName
