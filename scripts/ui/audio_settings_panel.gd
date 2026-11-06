class_name AudioSettingsPanel
extends VBoxContainer
const Catalog = preload("res://scripts/presentation/audio_event_catalog.gd")
var sliders: Dictionary = {}
var mutes: Dictionary = {}
var percentages: Dictionary = {}
var status: Label
var _service: PresentationAudioService
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 6)
	var title := Label.new(); title.text = "Áudio"; title.add_theme_font_size_override("font_size", 22); add_child(title)
	var names := {&"general":"Geral", &"effects":"Efeitos", &"interface":"Interface", &"ambience":"Ambiente"}
	for channel: StringName in Catalog.CHANNELS:
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12); add_child(row)
		var label := Label.new(); label.text = names[channel]; label.custom_minimum_size.x = 100; row.add_child(label)
		var slider := HSlider.new(); slider.min_value = 0.0; slider.max_value = 1.0; slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; slider.custom_minimum_size = Vector2(180, 32)
		slider.tooltip_text = "Volume de " + names[channel] + " · setas ajustam; Tab navega"
		slider.value_changed.connect(_volume_changed.bind(channel)); row.add_child(slider); sliders[channel] = slider
		var percent := Label.new(); percent.custom_minimum_size.x = 52; row.add_child(percent); percentages[channel] = percent
		var mute := CheckBox.new(); mute.text = "Silenciar"; mute.tooltip_text = "Silenciar " + names[channel]
		mute.toggled.connect(_mute_changed.bind(channel)); row.add_child(mute); mutes[channel] = mute
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	_refresh()
func bind_service(service: PresentationAudioService) -> void:
	if _service == service: _refresh(); return
	if is_instance_valid(_service) and _service.preferences_changed.is_connected(_refresh): _service.preferences_changed.disconnect(_refresh)
	_service = service
	if is_instance_valid(_service): _service.preferences_changed.connect(_refresh)
	_refresh()
func _refresh() -> void:
	if status == null: return
	for channel: StringName in sliders:
		sliders[channel].editable = is_instance_valid(_service)
		mutes[channel].disabled = not is_instance_valid(_service)
		if not is_instance_valid(_service): continue
		var value := _service.preferences.value(channel)
		sliders[channel].set_value_no_signal(value.volume)
		mutes[channel].set_pressed_no_signal(value.muted)
		percentages[channel].text = "%d%%" % roundi(value.volume * 100.0)
	status.text = "Preferências de áudio indisponíveis." if not is_instance_valid(_service) else "Volumes salvos neste computador."
	if is_instance_valid(_service):
		if _service.preferences.save_error != OK: status.text = "Áudio aplicado; não foi possível salvar. Ajuste novamente para tentar salvar."
		elif _service.preferences.invalid_config: status.text = "Configuração de áudio inválida; valores seguros aplicados. Ajuste para salvar."
func _volume_changed(value: float, channel: StringName) -> void:
	if is_instance_valid(_service): _service.set_volume(channel, value); _service.confirm_ui()
func _mute_changed(value: bool, channel: StringName) -> void:
	if is_instance_valid(_service): _service.set_muted(channel, value); _service.confirm_ui()
func _exit_tree() -> void: bind_service(null)
