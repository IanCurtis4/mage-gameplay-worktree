extends SceneTree
## Optional real-renderer check. Output remains in ignored .godot/verification.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := CombatActor.new()
	actor.setup("Guardião", Color.WHITE, StatCalculator.calculate({&"str": 5, &"vit": 3}), 22.0)
	actor.set_animation_kind(&"warrior")
	actor.health = null # Only the live sprite and its low-alpha contact shadow are measured.
	actor.position = Vector2(128, 180)
	viewport.add_child(actor)
	actor.set_process(false)
	var normal := await _capture(viewport, "training_boss_normal.png")
	actor.sprite_visual_scale = 1.8
	actor.queue_redraw()
	var large := await _capture(viewport, "training_boss_large.png")
	actor.character_animation.state.face(Vector2.LEFT)
	actor.queue_redraw()
	var flipped := await _capture(viewport, "training_boss_large_flipped.png")
	var success := normal.size.x > 0 and normal.size.y > 0
	success = success and large.size.x >= normal.size.x * 1.45 and large.size.y >= normal.size.y * 1.45
	success = success and abs(large.end.y - normal.end.y) <= 3
	success = success and abs(flipped.size.x - large.size.x) <= 3 and abs(flipped.end.y - large.end.y) <= 3
	print("Training renderer bounds normal=", normal, " large=", large, " flipped=", flipped)
	print("Training boss renderer: ", "PASS" if success else "FAIL")
	viewport.free()
	quit(0 if success else 1)

func _capture(viewport: SubViewport, file_name: String) -> Rect2i:
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("Este probe exige renderer visível; execute sem --headless.")
		return Rect2i()
	var output := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(output)
	image.save_png(output.path_join(file_name))
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i.ZERO
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= 0.5:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x + 1)
			maximum.y = maxi(maximum.y, y + 1)
	return Rect2i(minimum, maximum - minimum) if maximum.x > minimum.x else Rect2i()
