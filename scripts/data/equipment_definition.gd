class_name EquipmentDefinition
extends Resource
## Immutable catalog entry; possession and sockets belong to runtime/profile.

@export var id: StringName
@export var display_name: String
@export_multiline var flavor_text: String
@export_multiline var description: String
@export var icon: Texture2D
@export var allowed_origins: Array[StringName] = []
@export var allowed_evolutions: Array[StringName] = []
@export var slot: StringName = &"main_hand"
@export var item_kind: StringName = &"weapon"
@export var hand_usage: StringName = &"one_hand"
@export var origin_id: StringName
@export var item_level: int = 0
@export var quality_id: StringName
@export var socket_capacity: int = 0
@export var set_id: StringName
@export var starter: bool = false
@export var effects: Array[EffectDefinition] = []

func metadata() -> Dictionary:
	var result := {"slot": slot, "item_kind": item_kind, "hand_usage": hand_usage, "origin_id": origin_id, "item_level": item_level, "quality_id": quality_id, "socket_capacity": socket_capacity, "allowed_base_classes": IdentityIds.base_class_ids() if allowed_origins.is_empty() else allowed_origins.duplicate(), "allowed_evolutions": allowed_evolutions.duplicate(), "starter": starter}

	if min_item_level != 1 or max_item_level != 30 or not allowed_identities.is_empty():
		result["min_item_level"] = min_item_level
		result["max_item_level"] = max_item_level
		result["allowed_identities"] = allowed_identities.duplicate()
	return result

# Optional policy for newly authored IDs; neutral defaults preserve legacy recipes.
@export var min_item_level: int = 1
@export var max_item_level: int = 30
@export var allowed_identities: Array[StringName] = []
@export var visual_key: StringName = &""
