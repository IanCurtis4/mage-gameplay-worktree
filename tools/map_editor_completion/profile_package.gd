extends SceneTree
## Cold loader timing only; semantic regression coverage remains in the suites.
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var started := Time.get_ticks_usec()
	var loaded := Release.load_package("forest_terraces")
	var ms := (Time.get_ticks_usec()-started)/1000.0
	print("F10_PACKAGE_PROFILE_RESULT "+JSON.stringify({"ok":loaded.ok,"count":1,"checks":[{"id":"published_first_field_loads","ok":loaded.ok}],"load_ms":ms,"code":loaded.get("code","")}))
	quit(0 if loaded.ok else 1)
