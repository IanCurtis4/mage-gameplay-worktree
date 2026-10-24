@tool
extends EditorPlugin
const Shell = preload("res://addons/ragrpg_map_editor/shell.gd")
var shell: Control

func _enter_tree() -> void:
	shell = Shell.new()
	EditorInterface.get_editor_main_screen().add_child(shell)
	_make_visible(false)

func _exit_tree() -> void:
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
