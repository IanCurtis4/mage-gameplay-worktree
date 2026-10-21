extends SceneTree
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	pass
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func finish() -> void:
	print("E07 F2 %s: %d checks, %d failures" % [get_script().resource_path.get_file(), checks, failures])
	quit(0 if failures == 0 else 1)
