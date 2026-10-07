class_name SentinelOnboarding
extends Control
## Read-only run guide; only its help button captures mouse input.

var status_label: Label
var toggle_button: Button
var help_label: Label
var _player: PlayerActor
var _panel: PanelContainer
var _expanded := false

func configure(player: PlayerActor) -> void:
	_player = player
	if is_node_ready():
		refresh()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	refresh()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -440.0
	_panel.offset_right = -24.0
	_panel.offset_top = 112.0
	_panel.offset_bottom = 112.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.065, 0.87)
	style.border_color = Color("a1c2ad", 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 9.0
	_panel.add_theme_stylebox_override("panel", style)
	_panel.minimum_size_changed.connect(_resize_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	_panel.add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var title := Label.new()
	title.text = "JANELA DE PRECISÃO"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("e8dba8"))
	header.add_child(title)
	toggle_button = Button.new()
	toggle_button.text = "Guia +"
	toggle_button.tooltip_text = "Mostrar ou recolher a ajuda; não dispara nem cancela um preparo."
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.add_theme_font_size_override("font_size", 13)
	toggle_button.pressed.connect(_toggle_help)
	header.add_child(toggle_button)
	status_label = Label.new()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("d8eadd"))
	column.add_child(status_label)
	help_label = Label.new()
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color("c1d4cd"))
	help_label.text = "Acerto direto próprio: +4 Foco por ação, a cada 0,5 s.\nEm combate: pare 0,5 s → Foco +10/s. Mover preserva Foco.\nObservar: próximos 3 acertos diretos geram Foco adicional.\nCabeça / Perfurante / Concussão: reset, sem auto extra.\nExplosivo: próximo auto comum; não reseta.\nRepita Explosivo ou Esc: libera a reserva antes de disparar.\nFora de combate: Foco decai; reserva insuficiente é liberada.\nRede: dano INT e imobiliza; alvo ainda pode atacar.\nINT: Rede/Explosivo. INT + DES: Perfurante.\nDES reduz só a recarga desses três tiros; SOR permite crítico.\nAbsoluto: alcance +20%; Foco +15/s ao parar, sem 0,5 s.\nAtivas aprendidas na biblioteca; passivas automáticas."
	column.add_child(help_label)
	help_label.hide()

func _toggle_help() -> void:
	_expanded = not _expanded
	help_label.visible = _expanded
	toggle_button.text = "Guia −" if _expanded else "Guia +"
	_resize_panel()

func _resize_panel() -> void:
	if _panel != null:
		_panel.size.y = _panel.get_combined_minimum_size().y

func refresh() -> void:
	if status_label == null:
		return
	visible = is_instance_valid(_player) and _player.is_sentinel() and _player.is_alive()
	if not visible:
		return
	var state := _player.sentinel_state
	var pace := "Fora de combate"
	if _player.sentinel_combat_active:
		if state.absolute_remaining > 0.0:
			pace = "Absoluto %.1f s · +15/s ao parar" % state.absolute_remaining
		elif state.stable_time >= SentinelFocusState.STABLE_DELAY:
			pace = "Parado · +10/s"
		else:
			pace = "Firmeza %.1f/0,5 s" % minf(state.stable_time, SentinelFocusState.STABLE_DELAY)
	if is_inside_tree() and get_tree().paused:
		pace = "Pausa · relógios congelados"
	var resource := "Foco %.0f livre" % state.free_focus()
	if state.reserved_focus > 0.0:
		resource += " · %.0f reservado" % state.reserved_focus
	var mark := "Observar —"
	if state.observed_target_id > 0 and state.observation_remaining > 0.0:
		mark = "Observar %d/3 · %.1f s" % [state.observation_charges, state.observation_remaining]
	var ammunition := "Munição livre"
	if state.explosive_prepared:
		ammunition = "Explosivo pronto · %.0f SP reservado" % state.reserved_sp
	var message := "%s · %s\n%s · %s" % [resource, pace, mark, ammunition]
	if status_label.text != message:
		status_label.text = message
		_resize_panel()
	status_label.tooltip_text = "Foco e SP reservados não estão livres para outras skills. Abrir o guia não pausa nem altera a run."
