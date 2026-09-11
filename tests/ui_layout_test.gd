extends SceneTree

var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var test_viewport := SubViewport.new()
		test_viewport.size = viewport_size
		root.add_child(test_viewport)
		var scene := load("res://scenes/main.tscn") as PackedScene
		var controller := scene.instantiate() as RunController
		test_viewport.add_child(controller)
		await process_frame
		await process_frame
		var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
		_check(_inside(viewport_rect, controller.help_panel.get_global_rect()), "help remains visible at %s" % viewport_size)
		_check(_inside(viewport_rect, controller.bottom_controls.get_global_rect()), "status and buttons remain visible at %s" % viewport_size)
		_check(_inside(viewport_rect, controller.augment_panel.get_global_rect()), "augment panel remains visible at %s" % viewport_size)
		_check(_inside(viewport_rect, controller.result_panel.get_global_rect()), "result panel remains visible at %s" % viewport_size)
		_check(controller.ui_root.get_global_rect().size == Vector2(viewport_size), "fullscreen UI root follows viewport %s" % viewport_size)
		controller.encounter_active = false
		controller.run_state.queue_choice()
		controller._open_augment_menu()
		_check(controller.choice_title.get_parent() == controller.choice_column and controller.choice_buttons.get_child_count() == 3, "choice title and buttons coexist at %s" % viewport_size)
		controller._confirm_augment(controller.run_state.current_offer[0].id)
		paused = false
		test_viewport.queue_free()
		await process_frame
	print("Layout da UI: %s" % ("PASS (%d checks)" % checks if failures == 0 else "FAIL (%d de %d)" % [failures, checks]))
	quit(0 if failures == 0 else 1)

func _inside(container: Rect2, child: Rect2) -> bool:
	return child.size.x > 0.0 and child.size.y > 0.0 and container.encloses(child)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
