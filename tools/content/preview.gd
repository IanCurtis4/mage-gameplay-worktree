extends SceneTree
## Explicit authoring command, never called by the game or the production loader.
const Demo = preload("res://tools/content/demo_bundle.gd")
const BRIEFS := "res://content/authoring/demo_briefs.json"
const TEXTS := "res://content/authoring/demo_texts.json"
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var entries: Array[Dictionary] = Demo.entries()
	var prepared := ContentAuthoring.prepare(entries)
	if not prepared["ok"]:
		push_error(str(prepared)); quit(1); return
	if "--prepare" in OS.get_cmdline_user_args():
		if not _write(BRIEFS, {"scope": "authoring_demo_only", "mechanical_digest": prepared["mechanical_digest"], "briefs": prepared["briefs"]}):
			quit(1); return
		if not FileAccess.file_exists(TEXTS) and not _write(TEXTS, prepared["text_template"]):
			quit(1); return
		print("Fichas preparadas: %d; texto existente preservado." % entries.size())
		quit(0); return
	if not FileAccess.file_exists(TEXTS):
		push_error("Prepare as fichas antes da prévia."); quit(1); return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEXTS))
	if not parsed is Dictionary:
		push_error("Documento editorial inválido."); quit(1); return
	var compiled := ContentAuthoring.compile_bundle(entries, parsed)
	if not compiled["ok"]:
		push_error(str(compiled)); quit(1); return
	var output := "res://.godot/content_authoring/preview_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(output)
	var files: Array[String] = []
	for entry: Dictionary in compiled["entries"]:
		var file := output.path_join("%s_%s.tres" % [entry["origin"], entry["definition"].id])
		if ResourceSaver.save(entry["definition"], file) != OK:
			push_error("Falha ao salvar prévia."); quit(1); return
		files.append(file)
	if not _write(output.path_join("manifest.json"), {"scope": "authoring_demo_only", "production_published": false, "mechanical_digest": compiled["mechanical_digest"], "editorial_sha256": FileAccess.get_file_as_string(TEXTS).sha256_text(), "resource_paths": files}):
		quit(1); return
	print("Prévia validada: %d recursos. Nenhum recurso de produção alterado. %s" % [files.size(), output])
	quit(0)
func _write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível escrever %s" % path); return false
	file.store_string(JSON.stringify(data, "\t", true) + "\n")
	file.close()
	return true
