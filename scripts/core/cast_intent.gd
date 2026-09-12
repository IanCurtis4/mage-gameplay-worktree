class_name CastIntent
extends RefCounted
## Input intent only: resources and eligibility are checked when actually casting.

enum Mode { CONFIRM, RELEASE, INSTANT }

var mode: Mode = Mode.CONFIRM
var active_skill: StringName = &""

func press(skill: StringName) -> StringName:
	if mode == Mode.INSTANT:
		cancel()
		return skill
	active_skill = skill
	return &""

func release(skill: StringName) -> StringName:
	if mode == Mode.RELEASE and active_skill == skill:
		return confirm()
	return &""

func confirm() -> StringName:
	var result := active_skill
	cancel()
	return result

func cancel() -> void:
	active_skill = &""

func set_mode(value: int) -> void:
	mode = clampi(value, Mode.CONFIRM, Mode.INSTANT) as Mode
	cancel()
