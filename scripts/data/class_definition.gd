class_name ClassDefinition
extends Resource
## Read-only class catalog data. Runtime resources and selections live in RunState.

@export var id: StringName
@export var display_name: String
@export var attributes: Dictionary = {}
@export var skill_ids: Array[StringName] = []
@export var passive_id: StringName
@export var basic_kind: DamageRequest.Kind = DamageRequest.Kind.PHYSICAL
@export var basic_power: float = 1.0
@export var basic_range: float = 50.0

