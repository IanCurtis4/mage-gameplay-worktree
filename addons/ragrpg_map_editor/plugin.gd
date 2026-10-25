@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
const Export = preload("res://addons/ragrpg_map_editor/export_plugin.gd")
var shell: Control
var exporter: EditorExportPlugin

func _enter_tree() -> void:
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

func _has_main_screen() -> bool: return true
func _get_plugin_name() -> String: return "Mapas"
func _make_visible(visible: bool) -> void:
	if is_instance_valid(shell):
		shell.visible = visible
		if visible: shell.focus_primary.call_deferred()
