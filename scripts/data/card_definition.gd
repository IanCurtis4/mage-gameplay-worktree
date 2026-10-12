class_name CardDefinition
extends Resource
## Immutable catalog entry; possession and sockets belong to runtime/profile.

@export var id: StringName
@export var display_name: String
@export_multiline var flavor_text: String
@export_multiline var description: String
@export var icon: Texture2D
@export var allowed_origins: Array[StringName] = []
@export var allowed_evolutions: Array[StringName] = []
@export var allowed_slots: Array[StringName] = [&"head", &"shoulders", &"arms", &"torso", &"cloak", &"legs", &"feet", &"main_hand", &"off_hand"]
@export var mob_base_id: StringName
@export var effects: Array[EffectDefinition] = []
