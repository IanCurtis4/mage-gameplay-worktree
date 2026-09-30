extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	var animation := CharacterAnimation.new()
	animation.configure(&"spiritualist")
	_check(animation.actor_kind == &"spiritualist" and animation.atlas != null and animation.atlas.get_size() == Vector2(256, 512), "atlas do Espiritualista ocupa 32 células de 64px")
	if animation.atlas != null:
		var bitmap := animation.atlas.get_image()
		var grounded := true
		var alpha_gutters := true
		for index: int in range(32):
			var region := Rect2i(Vector2i(index % 4 * 64, index / 4 * 64), Vector2i(64, 64))
			var frame := bitmap.get_region(region)
			var bounds := frame.get_used_rect()
			grounded = grounded and bounds.has_area() and is_zero_approx(animation.destination_rect(index).position.y + bounds.end.y - 1)
			alpha_gutters = alpha_gutters and frame.get_pixel(0, 0).a == 0.0 and frame.get_pixel(63, 63).a == 0.0 and animation.source_region(index) == Rect2(region)
		_check(grounded and alpha_gutters, "todas as poses mantêm contato no chão sem cortar a célula vizinha")
		var distinct_steps := true
		for index: int in range(4, 7):
			distinct_steps = distinct_steps and bitmap.get_region(Rect2i(animation.source_region(index))).get_data() != bitmap.get_region(Rect2i(animation.source_region(index + 1))).get_data()
		for index: int in range(12, 15):
			distinct_steps = distinct_steps and bitmap.get_region(Rect2i(animation.source_region(index))).get_data() != bitmap.get_region(Rect2i(animation.source_region(index + 1))).get_data()
		_check(distinct_steps, "passos alternam de frente e de costas")
	_check(animation.death_copy().atlas == animation.atlas, "cópia de morte preserva a identidade visual")
	var mage := CharacterAnimation.new()
	mage.configure(&"mage")
	_check(mage.atlas != animation.atlas, "Mago base mantém atlas próprio")
	for file_name: String in ["spiritualist_soul_wisp", "spiritualist_curse_sigil", "spiritualist_spectral_burst", "spiritualist_ritual_halo"]:
		var texture := load("res://assets/art/vfx/%s.png" % file_name) as Texture2D
		_check(texture != null and texture.get_size() == Vector2(384, 96), "%s importa como quatro frames 96px" % file_name)
		if texture != null:
			var image := texture.get_image()
			var distinct := true
			for index: int in range(3):
				var frame := image.get_region(Rect2i(index * 96, 0, 96, 96))
				var next_frame := image.get_region(Rect2i((index + 1) * 96, 0, 96, 96))
				distinct = distinct and frame.get_used_rect().has_area() and frame.get_data() != next_frame.get_data()
			_check(distinct, "%s tem animação legível e não quatro cópias" % file_name)
	var indicators := BattleIndicators.new()
	var halo_rect := indicators.spiritualist_frame_rect(Vector2(220, 220), 135.0, Vector2(48, 63))
	_check(is_equal_approx(halo_rect.position.y + halo_rect.size.y * 63.0 / 96.0, 220.0) and halo_rect.position.y < 220.0 - 135.0 * 0.5, "pivô do halo 48,63 ancora o chão, não o centro da textura")
	for kind: StringName in [&"sigil", &"break", &"burst", &"focus_grant", &"focus_consume", &"ritual"]:
		indicators.show_spiritualist_event(kind, Vector2(200, 200))
	_check(indicators.spiritualist_events.size() == 6, "registry aceita apenas eventos instantâneos reais")
	indicators.show_spiritualist_event(&"unknown", Vector2(200, 200))
	indicators.show_spiritualist_event(&"drain", Vector2(200, 200))
	_check(indicators.spiritualist_events.size() == 6, "evento desconhecido ou wisp estático não desenha proc inventado")
	for index: int in range(100):
		indicators.show_spiritualist_event(&"burst", Vector2(200, 200))
	_check(indicators.spiritualist_events.size() == 64, "fila visual de eventos é finita")
	indicators._process(0.33)
	_check(indicators.spiritualist_events.is_empty(), "eventos expiram sem resíduo")
	indicators.show_spiritualist_return_wisp(Vector2(300, 200), 7, &"drain")
	indicators.show_spiritualist_return_wisp(Vector2(320, 200), 7, &"recovery")
	_check(indicators.spiritualist_return_wisps.size() == 2 and indicators.spiritualist_return_wisps[0]["source"] == Vector2(300, 200) and indicators.spiritualist_return_wisps[0]["caster_id"] == 7, "pulsos de Drenagem e restituição têm origem no alvo e destino no personagem")
	indicators.clear_spiritualist_drain_wisps()
	_check(indicators.spiritualist_return_wisps.size() == 1 and indicators.spiritualist_return_wisps[0]["kind"] == &"recovery", "cancelamento do canal apaga só os pulsos de Drenagem")
	for index: int in range(30):
		indicators.show_spiritualist_return_wisp(Vector2(300, 200), 7, &"recovery")
	_check(indicators.spiritualist_return_wisps.size() == 16, "fila de wisps de retorno permanece limitada")
	indicators._process(0.25)
	_check(indicators.spiritualist_return_wisps.is_empty(), "wisps de retorno expiram sem fantasma remanescente")
	indicators.sync_spiritualist_veil(Vector2(220, 220), 3.0)
	indicators.sync_spiritualist_drain(1, 2)
	indicators.sync_spiritualist_focus(1, 5.0)
	indicators.sync_spiritualist_marks([2])
	indicators.show_spiritualist_procession_wisp(Vector2(100, 100), 2)
	indicators.clear_spiritualist_visuals()
	_check(indicators.spiritualist_marks.is_empty() and indicators.spiritualist_wisps.is_empty() and indicators.spiritualist_return_wisps.is_empty() and indicators.spiritualist_veil_remaining == 0.0 and indicators.spiritualist_drain_caster_id == 0 and indicators.spiritualist_focus_caster_id == 0, "fim de encontro limpa marca, zona, canal, carga e aparições")
	indicators.free()
	print("E05 Espiritualista visual: %s (%d checks)" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
