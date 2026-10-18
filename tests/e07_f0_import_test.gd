extends SceneTree
## A clean native import of byte-identical F0 sources; does not load the production editor's GitPlugin.
const TARGET := "res://.godot/verification/e07_f0/fixture_project"
var files: Array[String] = []
func collect(directory: String) -> void:
	var dir := DirAccess.open(directory)
	for file: String in dir.get_files():
		if file.ends_with(".gd") or file.ends_with(".gd.uid"): files.append(directory.path_join(file))
func _initialize() -> void:
	collect("res://scripts/core/expedition/model")
	collect("res://scripts/core/expedition/generation")
	collect("res://scripts/data/expedition")
	for file: String in DirAccess.get_files_at("res://tests"):
		if file.begins_with("e07_f0_") and (file.ends_with(".gd") or file.ends_with(".gd.uid")): files.append("res://tests/"+file)
	files.append("res://tests/fixtures/e07/f0/fixture_input.gd")
	if FileAccess.file_exists("res://tests/fixtures/e07/f0/fixture_input.gd.uid"): files.append("res://tests/fixtures/e07/f0/fixture_input.gd.uid")
	files.sort()
	var hashes := {}
	for source: String in files:
		var target := TARGET.path_join(source.trim_prefix("res://"))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if DirAccess.copy_absolute(source,target) != OK: push_error("fixture source copy failed: "+source); quit(1); return
		var source_hash := FileAccess.get_sha256(source)
		if FileAccess.get_sha256(target) != source_hash: push_error("fixture source differs: "+source); quit(1); return
		hashes[source.trim_prefix("res://")] = source_hash
	var config := "res://tests/fixtures/e07/f0/import_project.godot"
	if DirAccess.copy_absolute(config,TARGET+"/project.godot") != OK: push_error("fixture config copy failed"); quit(1); return
	hashes["tests/fixtures/e07/f0/import_project.godot"] = FileAccess.get_sha256(config)
	var location := FileAccess.open(TARGET+"/source_root.txt",FileAccess.WRITE)
	location.store_string(ProjectSettings.globalize_path("res://")); location.close()
	var record := FileAccess.open(TARGET+"/source_hashes.json",FileAccess.WRITE)
	record.store_string(JSON.stringify(hashes,"  ",true)); record.close()
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path(TARGET),"--editor","--import","--quit","--log-file",ProjectSettings.globalize_path(TARGET+"/import.engine.log")],output,true)
	for chunk: String in output: print(chunk)
	var errors := false
	for chunk: String in output:
		if chunk.contains("ERROR:") or chunk.contains("SCRIPT ERROR:") or chunk.contains("Parse Error:"): errors = true
	if code != 0 or errors: push_error("isolated import failed"); quit(1); return
	print("E07 F0 import: %d byte-identical files; source_manifest_sha256=%s" % [hashes.size(),FileAccess.get_sha256(TARGET+"/source_hashes.json")])
	quit(0)
