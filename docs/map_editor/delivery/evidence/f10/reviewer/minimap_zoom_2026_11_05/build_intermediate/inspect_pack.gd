extends SceneTree
func _initialize() -> void:
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene", "")
	var app_name: String = ProjectSettings.get_setting("application/config/name", "")
	var result := {"main_scene": main_scene, "app_name": app_name, "user_data_dir": OS.get_user_data_dir(), "character_menu": ResourceLoader.exists("res://scenes/character_menu.tscn"), "forest_phase": FileAccess.file_exists("res://data/expedition/phases/forest_sanctuary.json"), "registry": FileAccess.file_exists("res://data/map_authoring/release_packages.json"), "preparation_manifest": FileAccess.file_exists("res://scripts/core/expedition/snapshot/runtime_manifest.json")}
	var ok := main_scene == "res://scenes/character_menu.tscn" and app_name == "RagRPG F10 Q5 Mapa" and OS.get_user_data_dir().ends_with("RagRPG F10 Q5 Mapa")
	for key: String in ["character_menu", "forest_phase", "registry", "preparation_manifest"]:
		ok = ok and bool(result[key])
	result["ok"] = ok
	print("F10_PACK_INSPECTION ", JSON.stringify(result))
	quit(0 if ok else 1)