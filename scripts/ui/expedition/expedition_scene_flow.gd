class_name ExpeditionSceneFlow
extends RefCounted
## Scene ownership changes only after a confirmed service result.
static func install(result: Dictionary, previous: Node) -> Dictionary:
	if not result.get("ok", false) or not result.has("root"): return result
	var tree := previous.get_tree()
	var installed: Dictionary = result["registry"].install(result, previous.get_parent())
	if not installed.get("ok", false): return installed
	var activated: Dictionary = result["registry"].activate(result)
	if not activated.get("ok", false): return activated
	var host: RunController = result["root"]
	if host.route_camera != null:
		host.route_camera.make_current()
		host.route_camera.reset_smoothing()
		host.route_camera.force_update_scroll()
	if tree.current_scene == previous: tree.current_scene = host
	tree.paused = host.campaign_runtime.state.lifecycle != "active"
	previous.get_parent().remove_child(previous)
	previous.queue_free()
	return result

static func lobby(host: RunController) -> void:
	var tree := host.get_tree()
	var menu := (load("res://scenes/character_menu.tscn") as PackedScene).instantiate() as CharacterMenu
	menu.set_profile_facade(host.persistent_facade)
	CharacterMenu.pending_focus_character_id = host.run_state.character_id
	host.get_parent().add_child(menu)
	if tree.current_scene == host: tree.current_scene = menu
	tree.paused = false
	host.get_parent().remove_child(host)
	host.queue_free()
