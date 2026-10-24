@tool
extends EditorPlugin

const Document = preload("res://addons/m0_subject/probe_document.gd")
var panel: VBoxContainer
var focus_button: Button
var document: Resource = Document.new()

func _enter_tree() -> void:
	var state: Dictionary = Engine.get_meta("m0_state")
	state["entries"] += 1
	Engine.set_meta("m0_subject", self)
	# A source document is an external resource, not a scene subresource.
	document.take_over_path("res://.godot/m0_document.tres")
	panel = VBoxContainer.new()
	panel.name = "M0HostingPanel"
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = "Editor de mapas — prova de hospedagem F0"
	panel.add_child(title)
	var note := Label.new()
	note.text = "Tela isolada. Terreno e mapas serão implementados nos próximos pacotes."
	panel.add_child(note)
	focus_button = Button.new()
	focus_button.text = "Controle de foco — prova"
	panel.add_child(focus_button)
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.hide()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Mapas F0"

func _make_visible(visible: bool) -> void:
	if is_instance_valid(panel):
		panel.visible = visible

func _exit_tree() -> void:
	var state: Dictionary = Engine.get_meta("m0_state")
	state["exits"] += 1
	get_undo_redo().clear_history(0)
	if is_instance_valid(panel):
		panel.free()
	Engine.remove_meta("m0_subject")
