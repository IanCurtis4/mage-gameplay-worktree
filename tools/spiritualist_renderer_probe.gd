extends SceneTree
## Optional visible-renderer probe. It writes screenshots only to ignored .godot/verification.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output_dir := ProjectSettings.globalize_path("res://.godot/verification")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("353a42")
	background.size = Vector2(512, 512)
	viewport.add_child(background)
	var indicators := BattleIndicators.new()
	viewport.add_child(indicators)
	indicators.sync_spiritualist_veil(Vector2(256, 256), 3.0)
	indicators.show_spiritualist_event(&"ritual", Vector2(128, 140))
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null:
		push_error("O probe requer renderer visível; execute sem --headless.")
		viewport.free()
		quit(1)
		return
	print("image size: ", image.get_size(), " center: ", image.get_pixel(256, 256))
	print("save: ", image.save_png(ProjectSettings.globalize_path("res://.godot/verification/spiritualist_renderer_probe.png")))
	indicators.clear_spiritualist_visuals()
	var caster := CombatActor.new()
	caster.setup("Caster", Color.WHITE, StatCalculator.calculate({&"vit": 10}), 18.0)
	caster.global_position = Vector2(400, 320)
	viewport.add_child(caster)
	indicators.show_spiritualist_return_wisp(Vector2(110, 320), caster.get_instance_id(), &"drain")
	indicators._process(0.14)
	await process_frame
	await process_frame
	print("return save: ", viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.godot/verification/spiritualist_return_renderer_probe.png")))
	viewport.free()
	quit()
