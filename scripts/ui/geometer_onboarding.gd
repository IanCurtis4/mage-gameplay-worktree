class_name GeometerOnboarding
extends Control
## Read-only construction guide. Opening help never changes targeting or the run.

var status_label: Label
var toggle_button: Button
var help_label: Label
var _casting: GeometerCasting
var _panel: PanelContainer
var _expanded := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	refresh()

func configure(casting: GeometerCasting) -> void:
	_casting = casting
	if is_node_ready():
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
	style.bg_color = Color(0.035, 0.075, 0.10, 0.86)
	style.border_color = Color("8bb8cc", 0.5)
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
	title.text = "CADERNO GEOMÉTRICO"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("f4d69a"))
	header.add_child(title)
	toggle_button = Button.new()
	toggle_button.text = "Guia +"
	toggle_button.tooltip_text = "Mostrar ou recolher o guia; não dispara nem desfaz a figura."
	toggle_button.focus_mode = Control.FOCUS_NONE
	toggle_button.add_theme_font_size_override("font_size", 13)
	toggle_button.pressed.connect(_toggle_help)
	header.add_child(toggle_button)
	status_label = Label.new()
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("d5e8ef"))
	column.add_child(status_label)
	help_label = Label.new()
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color("b9ced8"))
	help_label.text = "F1 Fogo · F2 Gelo · F3 Raio: selecionam, sem disparar.\nTraçado cria A/B; Triangulação cria C (job 28).\nTriangulação R1: puros; R3: mistos; R5: tricolores.\nChão fixa; corpo vincula; Shift força chão.\nTranslação move o último; Reescrita troca o primeiro.\nEditar não renova a figura nem repete a resolução.\nEsc cancela a mira; F6 desfaz SEM Colapso.\nColapso consome parede/triângulo válido; expirar só desfaz."
	column.add_child(help_label)
	help_label.hide()

func _toggle_help() -> void:
	_expanded = not _expanded
	help_label.visible = _expanded
	toggle_button.text = "Guia −" if _expanded else "Guia +"
	_resize_panel()

func _resize_panel() -> void:
	# Wrapped labels can shrink after their initial layout or after help closes.
	# The plain Control parent otherwise retains the old Container height forever.
	if _panel != null:
		_panel.size.y = _panel.get_combined_minimum_size().y

func refresh() -> void:
	if status_label == null:
		return
	visible = is_instance_valid(_casting) and is_instance_valid(_casting.player) and _casting.player.is_geometer()
	if not visible:
		return
	var state := _casting.construction
	var pending := state.grammar.pending_count()
	var heading := _shape_name(state)
	if pending > 0:
		heading += " · %d em trânsito" % pending
	if is_inside_tree() and get_tree().paused:
		heading += " · pausa"
	var marks: Array[String] = []
	var remaining := state.figure_remaining
	for index: int in state.vertices.size():
		var anchor := state.vertices[index]
		marks.append("%s:%s%s" % ["ABC"[index], _element_name(anchor.element), "↟" if anchor.actor_id > 0 else ""])
		remaining = minf(remaining, anchor.remaining) if remaining > 0.0 else anchor.remaining
	var sequence := " · ".join(marks) if not marks.is_empty() else "F1 Fogo · F2 Gelo · F3 Raio"
	if remaining > 0.0:
		sequence += " · %.1f s" % remaining
	var message := "%s\n%s\n%s" % [heading, sequence, _next_step(state, pending)]
	if status_label.text != message:
		status_label.text = message
		# Content shrinks after an earlier wrapped hint without relayout on every frame.
		_resize_panel()
	status_label.tooltip_text = "Selecionado: %s. ↟ = vínculo móvel; sem ↟ = chão. O tempo é o menor prazo restante, sem renovação pela edição." % _element_name(state.grammar.selected_element)

func _shape_name(state: GeometerConstructionState) -> String:
	var name := ["Vazio", "Vértice A", "Preparação", "Parede", "Triângulo"][state.shape] as String
	return "%s · suspensa" % name if state.suspended else name

func _next_step(state: GeometerConstructionState, pending: int) -> String:
	if pending > 0:
		return "Aguarde o impacto; edição/Colapso após a entrega."
	if state.suspended:
		return "Sem efeitos; reposicione vínculos ou edite. O prazo continua."
	match state.shape:
		GeometerConstructionState.Shape.EMPTY:
			return "Traçado cria A · selecionado: %s" % _element_name(state.grammar.selected_element)
		GeometerConstructionState.Shape.VERTEX:
			return "Traçado cria B; diferente forma parede, igual prepara."
		GeometerConstructionState.Shape.PREPARATION, GeometerConstructionState.Shape.WALL:
			var player := _casting.player
			var rank := player.skill_rank(&"geometer_triangulation")
			if rank <= 0:
				return "C exige aprender Triangulação no job 28."
			if &"geometer_triangulation" not in player.available_skill_ids():
				return "Triangulação R%d exige requisitos legais para criar C." % rank
			return "Triangulação R%d cria C · %s" % [rank, "puros" if rank < 3 else ("puros/mistos" if rank < 5 else "todas as receitas")]
		GeometerConstructionState.Shape.TRIANGLE:
			return "Edite ou use Colapso; F6 desfaz sem dano."
	return ""

func _element_name(element: StringName) -> String:
	return "Fogo" if element == &"fire" else ("Gelo" if element == &"ice" else "Raio")
