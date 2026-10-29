@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
const Borders = preload("res://scripts/map_authoring/composition/border_operations.gd")
signal changed
var data: Dictionary = Document.empty()
var saved_hash := ""
var _undo: Array = []
var _redo: Array = []
func replace(value: Dictionary) -> Dictionary:
	var result := Document.validate(value)
	if result.ok:
		data = value.duplicate(true); _undo.clear(); _redo.clear(); changed.emit()
	return result
func apply(value: Dictionary) -> Dictionary:
	var result := Document.validate(value)
	if result.ok and Document.hash_source(value) != Document.hash_source(data):
		_undo.append(data.duplicate(true))
		if _undo.size() > 32: _undo.pop_front()
		_redo.clear(); data = value.duplicate(true); changed.emit()
	return result
func undo() -> bool:
	if _undo.is_empty(): return false
	_redo.append(data); data = _undo.pop_back(); changed.emit(); return true
func redo() -> bool:
	if _redo.is_empty(): return false
	_undo.append(data); data = _redo.pop_back(); changed.emit(); return true
func dirty() -> bool: return Document.hash_source(data) != saved_hash
func can_undo() -> bool: return not _undo.is_empty()
func can_redo() -> bool: return not _redo.is_empty()
func apply_border(command: Dictionary, expected_source_hash: String) -> Dictionary:
	if Document.hash_source(data) != expected_source_hash: return {"ok":false,"code":"stale_source"}
	var proposed := Borders.apply(data,command)
	if not proposed.ok: return proposed
	var applied := apply(proposed.data)
	if applied.ok: applied["diff"] = proposed.diff; applied["source_hash"] = Document.hash_source(data)
	return applied
