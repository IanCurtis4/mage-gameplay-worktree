class_name EquipmentSetDefinition
extends Resource
## One immutable recipe per threshold; no state lives on the set Resource.
@export var id: StringName
@export var display_name: String
@export_multiline var flavor_text: String
@export_multiline var description: String
@export var thresholds: Dictionary = {}
