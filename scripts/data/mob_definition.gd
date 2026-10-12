class_name MobDefinition
extends Resource
## Species identity and fixed stats. Occurrence category is a separate axis.
@export var id: StringName
@export var display_name: String
@export var base_category: StringName = &"normal"
@export var allowed_occurrence_categories: Array[StringName] = [&"normal"]
@export var fixed_level: int = 1
@export var primary_attributes: Dictionary = {}
@export var skill_ids: Array[StringName] = []
@export var card_id: StringName
