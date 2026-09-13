extends SceneTree
## Deterministic renderer snapshot of the integrated Mage, UI and animation poses.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	RunController.selected_class_id = &"mage"
	var controller := RunController.new()
	root.add_child(controller)
	await process_frame
	controller.player.position = Vector2(480, 520)
	controller.player.get_child(0).position_smoothing_enabled = false
	for index: int in range(controller.enemies.size()):
		var enemy := controller.enemies[index]
		enemy.set_process(false)
		enemy.position = Vector2(690 + index * 85, 505 + (index % 2) * 70)
		enemy.character_animation.play(&"basic_attack", Vector2.LEFT, 0.4)
	controller.player.set_process(false)
	controller.player.character_animation.play(&"cast", Vector2.RIGHT, 0.4)
	controller.player.character_animation.state.advance(0.24, Vector2.ZERO)
	controller.player.queue_redraw()
	controller.player.fire_wall_requested.emit(Vector2.RIGHT, 8.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://docs/art/mage_runtime.png")
	print("Mage runtime snapshot: ", error_string(result))
	controller.queue_free()
	await process_frame
	quit(0 if result == OK else 1)
