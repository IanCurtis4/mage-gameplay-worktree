class_name ControlPreferences
extends RefCounted

var cast_mode: int = CastIntent.Mode.CONFIRM
var smart_lock := true
var path := "user://controls.cfg"

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	var stored_mode: Variant = config.get_value("battle", "cast_mode", CastIntent.Mode.CONFIRM)
	if stored_mode is int and stored_mode >= CastIntent.Mode.CONFIRM and stored_mode <= CastIntent.Mode.INSTANT:
		cast_mode = stored_mode
	var stored_lock: Variant = config.get_value("battle", "smart_lock", true)
	if stored_lock is bool:
		smart_lock = stored_lock

func save_settings() -> Error:
	var config := ConfigFile.new()
	config.set_value("battle", "cast_mode", cast_mode)
	config.set_value("battle", "smart_lock", smart_lock)
	return config.save(path)
