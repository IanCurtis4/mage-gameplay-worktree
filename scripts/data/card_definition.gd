class_name CardDefinition
extends Resource
## Immutable catalog entry; possession and sockets belong to runtime/profile.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var allowed_origins: Array[StringName] = []
@export var allowed_evolutions: Array[StringName] = []
@export var allowed_slots: Array[StringName] = [&"weapon", &"armor", &"accessory"]
@export var effects: Array[EffectDefinition] = []
