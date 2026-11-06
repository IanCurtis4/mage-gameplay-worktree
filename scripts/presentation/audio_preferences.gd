class_name AudioPreferences
extends RefCounted
const Catalog = preload("res://scripts/presentation/audio_event_catalog.gd")
var path := "user://audio.cfg"
var load_error: Error = OK
var save_error: Error = OK
var invalid_config := false
var _values: Dictionary = {}
func _init() -> void: _defaults()
func _defaults() -> void:
	_values.clear()
	for channel: StringName in Catalog.CHANNELS: _values[channel] = {"volume":1.0, "muted":false}
func read(from_path: String) -> Error:
	path = from_path; _defaults(); invalid_config = false; save_error = OK
	var config := ConfigFile.new()
	load_error = config.load(path)
	if load_error == ERR_FILE_NOT_FOUND: load_error = OK; return OK
	if load_error != OK: invalid_config = true; return load_error
	for channel: StringName in Catalog.CHANNELS:
		var volume: Variant = config.get_value(String(channel), "volume", 1.0)
		var muted: Variant = config.get_value(String(channel), "muted", false)
		if typeof(volume) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(volume)) or float(volume) < 0.0 or float(volume) > 1.0 or not muted is bool:
			invalid_config = true; load_error = ERR_INVALID_DATA
			continue
		_values[channel] = {"volume":float(volume), "muted":muted}
	return load_error
func value(channel: StringName) -> Dictionary: return _values.get(channel, {}).duplicate()
func set_volume(channel: StringName, linear: float) -> Error:
	if not _values.has(channel) or not is_finite(linear): return ERR_INVALID_PARAMETER
	_values[channel].volume = clampf(linear, 0.0, 1.0)
	return save()
func set_muted(channel: StringName, muted: bool) -> Error:
	if not _values.has(channel): return ERR_INVALID_PARAMETER
	_values[channel].muted = muted
	return save()
func save() -> Error:
	var config := ConfigFile.new()
	for channel: StringName in Catalog.CHANNELS:
		config.set_value(String(channel), "volume", _values[channel].volume)
		config.set_value(String(channel), "muted", _values[channel].muted)
	save_error = config.save(path)
	if save_error == OK: load_error = OK; invalid_config = false
	return save_error
