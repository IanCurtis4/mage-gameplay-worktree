@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Export = preload("res://addons/ragrpg_map_editor/export_plugin.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
var shell: Control
var exporter: EditorExportPlugin

func _enter_tree() -> void:
	Preferences.install_storage(func(fallback: Dictionary) -> Variant: return EditorInterface.get_editor_settings().get_project_metadata(Preferences.SECTION,Preferences.KEY,fallback),_write_preferences,_recover_preferences)
	exporter = Export.new(); add_export_plugin(exporter)
	shell = Shell.new()
	EditorInterface.get_editor_main_screen().add_child(shell)
	_make_visible(false)

func _exit_tree() -> void:
	if exporter != null: remove_export_plugin(exporter); exporter = null
	if is_instance_valid(shell):
		shell.preserve_draft()
		shell.free()
	shell = null
	Preferences.install_storage(Callable(),Callable())

func _write_preferences(data: Dictionary) -> void:
	var settings := EditorInterface.get_editor_settings()
	settings.set_project_metadata(Preferences.SECTION,Preferences.KEY+"_last_valid",data.duplicate(true))
	settings.set_project_metadata(Preferences.SECTION,Preferences.KEY,data.duplicate(true))
	if is_instance_valid(shell): shell.authoring_preferences_changed.call_deferred()

func _recover_preferences(raw: Variant, commit: bool) -> Dictionary:
	var settings := EditorInterface.get_editor_settings()
	var previous: Variant = settings.get_project_metadata(Preferences.SECTION,Preferences.KEY+"_last_valid",Preferences.empty())
	var restored: Dictionary = previous.duplicate(true) if Preferences.validate(previous) else Preferences.empty()
	if not commit: return {"ok":true,"data":restored}
	var index: Variant = settings.get_project_metadata(Preferences.SECTION,Preferences.KEY+"_recovery_index",[])
	if not index is Array or not index.all(func(key: Variant) -> bool: return key is String) or index.size() >= Preferences.RECOVERY_LIMIT: return {"ok":false,"code":"preferences_recovery_limit"}
	var key := Preferences.KEY+"_recovery_"+Crypto.new().generate_random_bytes(12).hex_encode()
	settings.set_project_metadata(Preferences.SECTION,key,raw)
	var next: Array = index.duplicate(); next.append(key); settings.set_project_metadata(Preferences.SECTION,Preferences.KEY+"_recovery_index",next)
	return {"ok":true,"data":restored,"backup_id":key}

func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "Mapas"
func _make_visible(visible: bool) -> void:
	if is_instance_valid(shell):
		shell.visible = visible
		if visible: shell.focus_primary.call_deferred()
