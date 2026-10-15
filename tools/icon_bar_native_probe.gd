extends "res://tools/compact_gui_native_probe.gd"
var bar_checked := false
func _capture(viewport: SubViewport, directory: String, file_name: String) -> void:
	await super._capture(viewport,directory,file_name)
	if file_name != "game_shared_icons_1280" or bar_checked: return
	bar_checked = true
	var controller := viewport.get_child(0) as RunController
	var slot := controller.battle_controls.slot_buttons[0] as ActionBarSlot
	assert(slot.skill_id == &"fireball" and slot.text.is_empty())
	assert(slot.combat_icon.texture == SkillPresentation.icon(&"fireball"))
	controller.player.mage_cooldowns[&"fireball"] = 8.0
	controller._update_hud()
	await super._capture(viewport,directory,"icon_bar_cooldown_start")
	controller.player.mage_cooldowns[&"fireball"] = 4.0
	controller._update_hud()
	assert(slot.cooldown_fraction == .5 and slot.cooldown_hint.text == "4.0")
	assert((controller.battle_controls.slot_buttons[2] as ActionBarSlot).cooldown_fraction == .5)
	await super._capture(viewport,directory,"icon_bar_cooldown_half")
	controller.player.mage_cooldowns[&"fireball"] = 0.0
	controller._update_hud()
	await super._capture(viewport,directory,"icon_bar_ready")
	var actual_icon := slot.combat_icon.texture
	var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
	image.fill(Color(.8,.8,.8))
	slot.combat_icon.texture = ImageTexture.create_from_image(image)
	await process_frame
	await RenderingServer.frame_post_draw
	var baseline := _quadrants(viewport,slot.combat_icon)
	for step: int in 5:
		if step == 0:
			controller.player.mage_cooldowns[&"fireball"] = 8.0
		else:
			controller.player.mage_cooldowns[&"fireball"] = 8.0 - step * 2.0
		controller._update_hud()
		await process_frame
		await RenderingServer.frame_post_draw
		var values := _quadrants(viewport,slot.combat_icon)
		for quadrant: int in 4:
			var ratio := values[quadrant] / baseline[quadrant]
			assert(ratio > .85 if quadrant < step else ratio < .65)
		print("ICON_SWEEP_PIXELS phase=",step*.25," samples=",values)
		await super._capture(viewport,directory,"icon_bar_pixel_phase_%d" % step)
	slot.combat_icon.texture = actual_icon
	controller.player.mage_cooldowns[&"fireball"] = 0.0
	controller._update_hud()
	var sp := controller.player.current_sp
	await _click(viewport,GuiMetrics.visual_rect(slot).get_center())
	assert(controller.player.current_sp == sp)
	assert(controller.cast_intent.active_skill == &"fireball")
	controller._cancel_aim()
	print("ICON_BAR_NATIVE_OK full_icons=true clockwise_pixels=20 shared_rank_cooldown=true actual_slot_click=true")

func _quadrants(viewport: SubViewport, icon: TextureRect) -> Array[float]:
	var result: Array[float] = []
	var image := viewport.get_texture().get_image()
	for uv: Vector2 in [Vector2(.75,.25),Vector2(.75,.75),Vector2(.25,.75),Vector2(.25,.25)]:
		var at := icon.get_global_transform_with_canvas() * (icon.size * uv)
		result.append(image.get_pixelv(Vector2i(at)).get_luminance())
	return result
