class_name GeometerCastCommand
extends RefCounted
## Value captured at cast confirmation, separate from mutable element selection.

var skill_id: StringName
var element: StringName
var point := Vector2.ZERO
var actor_id := 0

func copy_command() -> GeometerCastCommand:
	var copy := GeometerCastCommand.new()
	copy.skill_id = skill_id
	copy.element = element
	copy.point = point
	copy.actor_id = actor_id
	return copy

static func is_trace_skill(skill: StringName) -> bool:
	return skill in [&"geometer_trace", &"geometer_triangulation"]

static func is_edit_skill(skill: StringName) -> bool:
	return skill in [&"geometer_translation", &"geometer_rewrite"]

static func is_grammar_skill(skill: StringName) -> bool:
	return is_trace_skill(skill) or is_edit_skill(skill) or skill == &"geometer_collapse"
