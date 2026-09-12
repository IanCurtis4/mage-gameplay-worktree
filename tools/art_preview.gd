extends SceneTree
## Development-only contact sheet of the exact imported runtime textures.
## Run with Godot --path <project> --script res://tools/art_preview.gd (renderer on).

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var canvas := Control.new()
	root.add_child(canvas)
	var background := ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color("142c30")
	canvas.add_child(background)
	_label(canvas, "RagRPG · Piloto de arte 01", Vector2(40, 26), 32, Color("f1d19a"))
	_label(canvas, "Sprites 64×64 · poses estáticas · ampliação 3× com nearest", Vector2(40, 76), 20)
	var actors := ["hero", "warrior", "archer"]
	var titles := ["Espadachim", "Guerreiro", "Arqueiro"]
	for index: int in range(3):
		var x := 40.0 + index * 410.0
		var panel := ColorRect.new()
		panel.position = Vector2(x, 120)
		panel.size = Vector2(380, 300)
		panel.color = Color("243f42")
		canvas.add_child(panel)
		_texture(canvas, actors[index], Rect2(x + 94, 128, 192, 192))
		_label(canvas, titles[index], Vector2(x + 28, 350), 25, Color("f1d19a"))
		_label(canvas, "Pivô nos pés · fundo transparente", Vector2(x + 28, 386), 17)
	_label(canvas, "Materiais de cenário", Vector2(40, 445), 25, Color("f1d19a"))
	for index: int in range(3):
		var x := 40.0 + index * 410.0
		_texture(canvas, ["grass", "dirt", "stone"][index], Rect2(x, 493, 160, 160))
		_label(canvas, ["Grama", "Terra", "Pedra"][index], Vector2(x + 184, 528), 23, Color("f1d19a"))
		_label(canvas, "128×128", Vector2(x + 184, 565), 19)
	_label(canvas, "Fontes geradas com imagegen nativo; resolução reduzida na importação Godot.", Vector2(40, 680), 18)
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://docs/art")
	var result := root.get_texture().get_image().save_png("res://docs/art/pilot_contact_sheet.png")
	print("Art contact sheet: ", error_string(result))
	quit(0 if result == OK else 1)

func _texture(parent: Control, id: String, rect: Rect2) -> void:
	var control := TextureRect.new()
	control.texture = load("res://assets/art/pilot/%s.png" % id) as Texture2D
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.position = rect.position
	control.size = rect.size
	parent.add_child(control)

func _label(parent: Control, text: String, point: Vector2, size: int, color: Color = Color("dce7df")) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
