extends SceneTree
## Full native gameplay import with the sole local VCS startup delta declared below.
const TARGET := "res://.godot/verification/e07_f1/fixture_project"
var files: Array[String] = []
func collect(directory: String) -> void:
	var dir := DirAccess.open(directory)
	if dir == null: return
	for file: String in dir.get_files(): files.append(directory.path_join(file))
	for child: String in dir.get_directories(): collect(directory.path_join(child))
func _initialize() -> void:
	for directory: String in ["scripts", "scenes", "assets", "data", "resources", "content", "addons", "tests", "tools", "docs/fixtures"]: collect("res://"+directory)
	files.sort()
	var hashes := {}
	var auxiliary := {}
	for source: String in files:
		var target := TARGET.path_join(source.trim_prefix("res://"))
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		if DirAccess.copy_absolute(source,target) != OK: push_error("fixture source copy failed: "+source); quit(1); return
		var source_hash := FileAccess.get_sha256(source)
		if FileAccess.get_sha256(target) != source_hash: push_error("fixture source differs: "+source); quit(1); return
		if source.ends_with(".import") or source == "res://addons/godot-git-plugin/windows/~libgit_plugin.windows.editor.x86_64.dll":
			auxiliary[source.trim_prefix("res://")] = source_hash
		else:
			hashes[source.trim_prefix("res://")] = source_hash
	var config := FileAccess.get_file_as_string("res://project.godot")
	if config.count("version_control/autoload_on_startup=true") != 1: push_error("unexpected VCS configuration"); quit(1); return
	config = config.replace("version_control/autoload_on_startup=true", "version_control/autoload_on_startup=false")
	var project := FileAccess.open(TARGET+"/project.godot",FileAccess.WRITE)
	project.store_string(config); project.close()
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
	if code != 0 or errors: push_error("F1 full isolated import failed"); quit(1); return
	if DirAccess.make_dir_recursive_absolute(TARGET+"/.godot/verification") != OK: push_error("fixture verification directory unavailable"); quit(1); return
	var generated_delta := {}
	for relative: String in auxiliary:
		var target := TARGET.path_join(relative)
		var imported_hash := FileAccess.get_sha256(target) if FileAccess.file_exists(target) else "removed_by_native_import"
		if imported_hash != auxiliary[relative]: generated_delta[relative] = {"source_sha256":auxiliary[relative],"imported_sha256":imported_hash}
	var auxiliary_record := FileAccess.open(TARGET+"/import_generated_delta.json",FileAccess.WRITE)
	auxiliary_record.store_string(JSON.stringify(generated_delta,"  ",true)); auxiliary_record.close()
	for relative: String in hashes:
		if FileAccess.get_sha256(TARGET.path_join(relative)) != hashes[relative]: push_error("primary runtime source changed by import: "+relative); quit(1); return
	print("E07 F1 import PASS: %d byte-identical files; sole project delta VCS autoload true -> false; source_manifest_sha256=%s" % [hashes.size(),FileAccess.get_sha256(TARGET+"/source_hashes.json")])
	quit(0)
