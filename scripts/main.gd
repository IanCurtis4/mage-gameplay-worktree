extends Control
## Foundation status screen, intentionally not a playable combat scene.

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 24)
	margin.add_child(column)
	_add_label(column, "RagRPG", 52, Color("e9c67b"))
	_add_label(column, "Fundação técnica • MVP em desenvolvimento", 24)
	_add_label(column, "3 fases + boss  /  Espadachim e Mago  /  Builds por run", 20)
	_add_label(column, "Base: atributos, contrato de dano e definição de augments.\nPróximo marco: arena com navegação por clique e combate.", 20)
	var stats := RpgStats.derive({"str": 5, "agi": 5, "vit": 5, "int": 5, "dex": 5, "luk": 5})
	_add_label(column, "Amostra técnica — seis atributos em 5\nVida: %.0f  |  Mana: %.0f  |  Ataque físico: %.0f" % [stats["max_hp"], stats["max_mana"], stats["physical_attack"]], 18, Color("9dd4c5"))
	_add_label(column, "Esta tela verifica a inicialização. O jogo ainda não está disponível.", 18)
	var close := Button.new()
	close.text = "Fechar"
	close.custom_minimum_size = Vector2(200, 48)
	close.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(get_tree().quit)
	column.add_child(close)

func _add_label(parent: Control, value: String, size: int, color: Color = Color("d7ddea")) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
