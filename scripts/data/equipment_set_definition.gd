class_name EquipmentSetDefinition
extends Resource
## One immutable recipe per threshold; no state lives on the set Resource.
@export var id: StringName
@export var display_name: String
@export var thresholds: Dictionary = {}
