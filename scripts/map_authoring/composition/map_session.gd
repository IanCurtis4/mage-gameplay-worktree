@tool
extends RefCounted
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
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
