extends SceneTree
## Renderer-on evidence, using the actual animator and BattleIndicators.
## Godot --path <project> --script res://tools/elementalist_visual_review.gd
class PoseSample extends Node2D:
	var animation := CharacterAnimation.new()
	func _draw() -> void:
		draw_line(Vector2(-32, 0), Vector2(32, 0), Color("81dfd0"), 1.0)
		animation.draw_on(self)

var effects: BattleIndicators

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	var background := ColorRect.new()
	background.color = Color("243f42")
	background.size = Vector2(1280, 900)
	root.add_child(background)
	_label("Elementalista · poses reais e VFX", Vector2(22, 8))
	for index: int in range(8):
		var sample := PoseSample.new()
		sample.animation.configure(&"elementalist")
		sample.animation.state.moving = true
		sample.animation.state.back_view = index >= 4
		sample.animation.state.walk_distance = (index % 4) * CombatAnimationState.WALK_FRAME_DISTANCE
		sample.position = Vector2(85 + index * 156, 228)
		sample.scale = Vector2(3, 3)
		sample.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(sample)
		_label("%s %d" % ["costas" if index >= 4 else "frente", index % 4 + 1], Vector2(40 + index * 156, 245))
	effects = BattleIndicators.new()
	root.add_child(effects)
	effects.set_process(false)
	for index: int in range(6):
		_label(["Explosão de Chamas", "Anel Glacial", "Arco Voltaico", "Trilha de Brasas", "Nova Tríplice", "Foco / Ressonância"][index], Vector2(30 + index % 3 * 420, 300 + index / 3 * 300))
	for phase: float in [0.10, 0.35, 0.60]:
		effects.elementalist_pulses.clear()
		effects.elementalist_arc_links.clear()
		effects.elementalist_prisms.clear()
		effects.show_elementalist_pulse(&"elementalist_flame_burst", Vector2(210, 450), 90, &"fire")
		effects.show_elementalist_pulse(&"elementalist_glacial_ring", Vector2(630, 450), 145, &"ice")
		for point: Vector2 in [Vector2(970, 460), Vector2(1050, 430), Vector2(1130, 460)]:
			effects.show_elementalist_pulse(&"elementalist_lightning_arc", point, 30, &"lightning")
		effects.show_elementalist_arc_link(Vector2(915, 470), Vector2(970, 442))
		effects.show_elementalist_arc_link(Vector2(970, 442), Vector2(1050, 412))
		effects.show_elementalist_arc_link(Vector2(1050, 412), Vector2(1130, 442))
		for point: Vector2 in [Vector2(120, 750), Vector2(200, 750), Vector2(280, 750)]:
			effects.show_elementalist_pulse(&"elementalist_ember_path", point, 55, &"fire")
		effects.show_elementalist_pulse(&"elementalist_tri_nova", Vector2(630, 750), 170, &"fire")
		effects.show_elementalist_prism(Vector2(1030, 750), &"elementalist_prismatic_focus")
		effects.show_elementalist_prism(Vector2(1150, 750), &"elementalist_prismatic_resonance")
		effects._process(phase)
		# Nova's elements are emitted at their actual simulation offsets.
		if phase >= 0.25:
			effects.show_elementalist_pulse(&"elementalist_tri_nova", Vector2(630, 750), 170, &"ice")
			effects.elementalist_pulses[-1]["remaining"] -= phase - 0.25
		if phase >= 0.50:
			effects.show_elementalist_pulse(&"elementalist_tri_nova", Vector2(630, 750), 170, &"lightning")
			effects.elementalist_pulses[-1]["remaining"] -= phase - 0.50
		effects.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/verification/elementalist_visual")
		var output := "res://.godot/verification/elementalist_visual/phase_%d.png" % roundi(phase * 100)
		var result := root.get_texture().get_image().save_png(output)
		print(output, ": ", error_string(result))
		if result != OK:
			quit(1)
			return
	await _capture_arena()
	quit()

func _capture_arena() -> void:
	for child: Node in root.get_children():
		child.queue_free()
	await process_frame
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var snapshot := BuildSnapshot.new()
	snapshot.base_class_id = &"mage"
	snapshot.evolution_id = &"elementalist"
	snapshot.library_skill_ids = ProfileCatalog.pilot().skill_ids_for_identity(&"mage", &"elementalist")
	snapshot.active_slots = [&"elementalist_flame_burst", &"elementalist_glacial_ring", &"elementalist_lightning_arc", &"elementalist_ember_path", &"elementalist_tri_nova"]
	for skill_id: StringName in snapshot.active_slots:
		snapshot.skill_ranks[skill_id] = 5
	RunController.pending_run_state = RunState.from_build("visual-review-only", snapshot)
	var controller := load("res://scenes/main.tscn").instantiate() as RunController
	root.add_child(controller)
	await process_frame
	controller.process_mode = Node.PROCESS_MODE_DISABLED
	controller.player.global_position = Vector2(600, 650)
	for child: Node in controller.player.get_children():
		if child is Camera2D:
			child.position_smoothing_enabled = false
			child.reset_smoothing()
			child.force_update_scroll()
	for index: int in range(controller.enemies.size()):
		controller.enemies[index].global_position = Vector2(830 + index * 65, 650)
	for skill_id: StringName in [&"elementalist_flame_burst", &"elementalist_glacial_ring", &"elementalist_tri_nova"]:
		controller.battle_indicators.elementalist_pulses.clear()
		var center := controller.player.global_position
		var radius := 145.0
		var element: StringName = &"ice"
		if skill_id == &"elementalist_flame_burst":
			center += Vector2(120, 0)
			radius = 90.0
			element = &"fire"
		elif skill_id == &"elementalist_tri_nova":
			radius = 170.0
			element = &"lightning"
		controller.battle_indicators.show_elementalist_pulse(skill_id, center, radius, element)
		controller.battle_indicators._process(0.25)
		controller.battle_indicators.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var output := "res://.godot/verification/elementalist_visual/arena_%s.png" % skill_id
		print(output, ": ", error_string(root.get_texture().get_image().save_png(output)))

func _label(text: String, point: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", 18)
	root.add_child(label)
