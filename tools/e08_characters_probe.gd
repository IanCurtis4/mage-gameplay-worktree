extends SceneTree
## Native renderer inspection: ten equipped identities, front/back and states.
const KINDS: Array[StringName] = [&"swordsman", &"archer", &"mage", &"berserker", &"defender", &"hunter", &"sentinel", &"elementalist", &"spiritualist", &"geometer"]
const KEYS: Array[StringName] = [&"sword", &"bow", &"staff", &"axe", &"sword", &"bow", &"bow", &"staff", &"staff", &"bow"]
class Preview extends Node2D:
	var animation: CharacterAnimation
	func _draw() -> void:
		animation.draw_on(self, Color.WHITE, float(OS.get_environment("RAGRPG_P4_SCALE")))
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1000, 600)
	var bg := ColorRect.new()
	bg.size = Vector2(1000,600)
	bg.color = Color("d5d8cb") if OS.get_environment("RAGRPG_P4_LIGHT") == "1" else Color("33484b")
	root.add_child(bg)
	var page := int(OS.get_environment("RAGRPG_P4_PAGE"))
	for row: int in 5:
		var index := row + page * 5
		var label := Label.new()
		label.text = String(KINDS[index])
		label.position = Vector2(4, row * 110 + 8)
		root.add_child(label)
		for col: int in 8:
			var animation := CharacterAnimation.new()
			animation.configure(KINDS[index])
			var unarmed := OS.get_environment("RAGRPG_P4_UNARMED") == "1"
			animation.set_equipment_visual({"main_hand": &"" if unarmed else KEYS[index], "off_hand": &"shield" if not unarmed and KINDS[index] == &"defender" else &"", "arms": &""})
			var facing := Vector2.UP if col >= 4 else Vector2.DOWN
			animation.state.face(facing)
			animation.state.flip_h = OS.get_environment("RAGRPG_P4_FLIP") == "1"
			match col % 4:
				1: animation.state.advance(0.2, facing * 20.0)
				2:
					animation.state.trigger(&"attack", facing, 0.25)
					animation.state.advance(0.12, Vector2.ZERO)
				3:
					if OS.get_environment("RAGRPG_P4_HURT") == "1":
						animation.state.trigger(&"hurt")
					else:
						animation.state.trigger(&"death")
						animation.state.advance(0.22, Vector2.ZERO)
			var sprite := Preview.new()
			sprite.animation = animation
			sprite.position = Vector2(150 + col * 110, row * 110 + 95)
			root.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var target := OS.get_environment("RAGRPG_P4_CAPTURE")
	var error := root.get_texture().get_image().save_png(target)
	print("P4_RENDER_CAPTURE ", target, " error=", error)
	quit(0 if error == OK else 1)
