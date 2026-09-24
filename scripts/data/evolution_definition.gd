class_name EvolutionDefinition
extends Resource
## Immutable-by-convention catalog metadata for one persistent evolution identity.

const BRANCH_2_1: StringName = &"2-1"
const BRANCH_2_2: StringName = &"2-2"
const BRANCH_2_3: StringName = &"2-3"

@export var id: StringName
@export var display_name: String
@export var origin_class_id: StringName
@export var branch_kind: StringName
@export var affinity_class_id: StringName = &""
@export var required_base_level: int = 10
@export var required_job_level: int = 20
@export var entry_skill_id: StringName = &""
@export var exclusive_skill_ids: Array[StringName] = []
@export var content_ready: bool = false

func copy_definition() -> EvolutionDefinition:
	var copy := EvolutionDefinition.new()
	copy.id = id
	copy.display_name = display_name
	copy.origin_class_id = origin_class_id
	copy.branch_kind = branch_kind
	copy.affinity_class_id = affinity_class_id
	copy.required_base_level = required_base_level
	copy.required_job_level = required_job_level
	copy.entry_skill_id = entry_skill_id
	copy.exclusive_skill_ids = exclusive_skill_ids.duplicate()
	copy.content_ready = content_ready
	return copy
