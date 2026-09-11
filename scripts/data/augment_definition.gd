class_name AugmentDefinition
extends Resource
## Immutable catalog entry. Stack counts belong to the run, not this Resource.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Empty means available to either class.
@export var class_id: StringName
@export_range(1, 3) var max_stacks: int = 1
## Stable handler ID dispatched by the future augment runtime.
@export var effect_id: StringName
@export var magnitude_per_stack: float = 0.0

func is_eligible(selected_class: StringName, current_stacks: int) -> bool:
	return not id.is_empty() and not effect_id.is_empty() and (class_id.is_empty() or class_id == selected_class) and current_stacks >= 0 and current_stacks < max_stacks
