extends SceneTree
## Renderer proof for the swordsman weaponless candidate and equipment overlays.

const CharacterAnimationScript = preload("res://scripts/actors/character_animation.gd")
const CELL_W := 256
const CELL_H := 150
const PREVIEW_ATLAS := "res://assets/art/animations/swordsman_weaponless.png"

class SpritePreview extends Node2D:
	var animation: CharacterAnimation
	func _draw() -> void:
		if animation != null:
			animation.draw_on(self, Color.WHITE, 2.0)

func _initialize() -> void:
	print("WEAPONLESS_PROBE_INIT")
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color("14272d")
	root.add_child(background)
	var title := Label.new()
	title.text = "E06 · Swordsman weaponless + equipamento · Godot renderer"
	title.position = Vector2(18, 5)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f0d29a"))
	root.add_child(title)
	var gear_keys: Array[Dictionary] = [
		{},
		{"main_hand": &"sword", "off_hand": &""},
		{"main_hand": &"axe", "off_hand": &"shield"},
		{"main_hand": &"bow", "off_hand": &""},
		{"main_hand": &"staff", "off_hand": &"prismatic_focus"},
	]
	var action_names := ["Sem arma", "Espada", "Machado + escudo", "Arco", "Cajado + foco"]
	var action_types: Array[StringName] = [&"idle", &"walk", &"attack", &"hurt", &"death"]
	for page in range(2):
		var row_y := 38.0 + page * CELL_H * 2
		var row_label := Label.new()
		row_label.text = "Frente" if page == 0 else "Costas"
		row_label.position = Vector2(8, row_y)
		row_label.add_theme_color_override("font_color", Color("f0d29a"))
		root.add_child(row_label)
		for column in range(5):
			var heading := Label.new()
			heading.text = action_names[column]
			heading.position = Vector2(column * CELL_W + 8, row_y + 18)
			heading.add_theme_font_size_override("font_size", 12)
			heading.add_theme_color_override("font_color", Color("c6d8cd"))
			root.add_child(heading)
			var animation: CharacterAnimation = CharacterAnimationScript.new()
			animation.configure(&"swordsman")
			animation.atlas = load(PREVIEW_ATLAS) as Texture2D
			animation.equipment_visual = gear_keys[column].duplicate(true)
			var image := animation.atlas.get_image()
			var offsets := PackedFloat32Array()
			for frame in range(32):
				var bounds := image.get_region(Rect2i(Vector2i(frame % 4 * 64, frame / 4 * 64), Vector2i(64, 64))).get_used_rect()
				offsets.append(58.0 - float(bounds.end.y - 1))
			animation._ground_offsets = offsets
			var facing := Vector2.UP if page == 1 else Vector2.DOWN
			animation.state.face(facing)
			match action_types[column]:
				&"walk": animation.state.advance(0.2, facing * 20.0)
				&"attack":
					animation.state.trigger(&"attack", facing, 0.25)
					animation.state.advance(0.12, Vector2.ZERO)
				&"hurt": animation.state.trigger(&"hurt")
				&"death":
					animation.state.trigger(&"death")
					animation.state.advance(0.22, Vector2.ZERO)
			var sprite := SpritePreview.new()
			sprite.animation = animation
			sprite.position = Vector2(column * CELL_W + CELL_W * 0.5, row_y + 105)
			root.add_child(sprite)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var proof_dir := "res://.godot/verification/fixes_art/weaponless_probe"
	print("WEAPONLESS_PROBE_IMAGE ", image.get_width(), "x", image.get_height(), " save=", image.save_png(proof_dir + "/swordsman_weaponless_native.png"))
	quit(0)
