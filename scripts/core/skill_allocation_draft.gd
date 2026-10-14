class_name SkillAllocationDraft
extends RefCounted
## Presentation draft; only ProfileFacade owns mutation and persistence.
var facade: RefCounted
var character_id := ""
var revision := -1
var sequence: Array[StringName] = []
var preview: Dictionary = {}
var editable := false
var _request := ""
var _uncertain := false
var _serial := 0

func configure(value: RefCounted, id: String, can_edit: bool) -> void:
	if _uncertain:
		return # Preserve the reconciliation identity even if selection changes.
	var profile: ProfileState = value.current_profile() if value != null else null
	var next_revision := profile.revision if profile != null else -1
	if facade != value or character_id != id or revision != next_revision:
		sequence.clear()
		_request = ""
	facade = value
	character_id = id
	revision = next_revision
	editable = can_edit
	_refresh()

func _refresh() -> void:
	preview = facade.skill_allocation_preview(character_id, revision, sequence) if facade != null else {"ok": false, "error_code": &"profile_unavailable"}

func add(skill_id: StringName) -> Dictionary:
	if not editable or _uncertain or not preview.get("can_apply", false):
		return {"ok": false, "error_code": &"run_active"}
	var trial := sequence.duplicate()
	trial.append(skill_id)
	return _accept(trial)

func remove(skill_id: StringName) -> Dictionary:
	if not editable or _uncertain:
		return {"ok": false, "error_code": &"run_active"}
	var trial := sequence.duplicate()
	var index := trial.rfind(skill_id)
	if index < 0:
		return {"ok": false, "error_code": &"no_pending_points"}
	trial.remove_at(index)
	return _accept(trial)

func _accept(trial: Array[StringName]) -> Dictionary:
	var result: Dictionary = facade.skill_allocation_preview(character_id, revision, trial)
	if result.get("ok", false):
		sequence = trial
		preview = result
		_request = ""
	return result

func reset() -> void:
	if _uncertain:
		return
	sequence.clear()
	_request = ""
	_refresh()

func is_uncertain() -> bool:
	return _uncertain

func apply() -> Dictionary:
	if facade == null or sequence.is_empty():
		return {"ok": false, "error_code": &"invalid_skill_allocations"}
	if not _uncertain and (not editable or not preview.get("can_apply", false)):
		return {"ok": false, "error_code": &"run_active"}
	if _request.is_empty():
		_serial += 1
		_request = "skill-draft-%d-%d" % [get_instance_id(), _serial]
	var result: Dictionary = facade.reconcile_transaction(_request) if _uncertain else facade.apply_skill_allocations(_request, revision, character_id, sequence)
	_uncertain = result.get("error_code", &"") == &"result_uncertain"
	if result.get("ok", false):
		sequence.clear()
		_request = ""
		revision = facade.current_profile().revision
		_refresh()
	elif result.get("error_code", &"") == &"stale_revision":
		sequence.clear()
		_request = ""
		revision = facade.current_profile().revision
		_refresh()
	return result
