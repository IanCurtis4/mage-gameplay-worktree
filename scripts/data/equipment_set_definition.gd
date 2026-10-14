class_name EquipmentSetDefinition
extends Resource
## One immutable recipe per threshold; no state lives on the set Resource.
@export var id: StringName
@export var display_name: String
@export_multiline var flavor_text: String
@export_multiline var description: String
@export var thresholds: Dictionary = {}

# Optional policy for newly authored IDs; neutral defaults preserve legacy recipes.
@export var min_item_level: int = 1
@export var max_item_level: int = 30
@export var allowed_identities: Array[StringName] = []
