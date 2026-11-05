extends SceneTree
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var records: Array = []
	for id: String in ["forest_terraces","forest_valleys","forest_lair"]:
		var started := Time.get_ticks_usec()
		var result := Release.bake_preparation(id)
		if not result.ok:
			print("PREPARATION_BAKE_FAILED "+JSON.stringify(result)); quit(1); return
		records.append({"id":id,"path":result.path,"bytes":result.bytes,"manifest_hash":result.manifest_hash,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0})
	print("PREPARATION_BAKE_RESULT "+JSON.stringify({"ok":true,"records":records}))
	quit()
