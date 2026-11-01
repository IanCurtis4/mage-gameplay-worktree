extends SceneTree
## Checkpoint41: writes the asset manifest for this checkout's map-editor assets.
## Usage: --script res://tools/map_editor_assets/build_manifest.gd -- --output=<file>
const Assets = preload("res://scripts/map_authoring/assets/asset_manifest.gd")
func _initialize() -> void:
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty(): output = ProjectSettings.globalize_path(Assets.PATH)
	var manifest := Assets.build()
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null or not Assets.valid(manifest): print("ASSET_MANIFEST_RESULT {\"ok\":false}"); quit(1); return
	file.store_string(Assets.encode(manifest)); file.close()
	print("ASSET_MANIFEST_RESULT "+JSON.stringify({"ok":true,"entries":manifest.entries.size(),"output":output}))
	quit(0)
