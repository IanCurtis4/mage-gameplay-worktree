extends "res://tests/fixtures/e07/f4/suite.gd"
func _run() -> void:
	var directory := ProjectSettings.globalize_path("res://.godot/verification/e07_f4/restart_%d" % Time.get_ticks_usec())
	for phase: String in ["write","recover","confirm"]:
		var output: Array = []
		var exit := OS.execute(OS.get_executable_path(),["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/fixtures/e07/f4/restart_worker.gd","--",phase,directory],output,true)
		var errors := false
		for chunk: String in output:
			print(chunk)
			if chunk.contains("ERROR:") or chunk.contains("SCRIPT ERROR:") or chunk.contains("Parse Error:"): errors = true
		check(exit == 0 and not errors and str(output).contains("worker PASS "+phase),"separate native process completed "+phase)
		if exit != 0 or errors: break
	finish()
