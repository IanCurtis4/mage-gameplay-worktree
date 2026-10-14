class_name SkillWindow
extends Control
## A bounded two-panel view; progression and transaction rules belong to the draft.
signal transaction_result(result: Dictionary)
signal closed
signal respec_requested

class SkillButton extends Button:
	func _make_custom_tooltip(for_text: String) -> Object:
		return SkillTooltip.create(for_text)

var draft := SkillAllocationDraft.new()
var action_host: VBoxContainer
var skill_panel: Panel
var detail_panel: Panel
var skill_entries: Dictionary = {}
var _body: Control
var _tabs: HFlowContainer
var _scroll: ScrollContainer
var _canvas: Control
var _details: Label
var _wallet: Label
var _status: Label
var _apply: Button
var _undo: Button
var _respec: Button
var _jobs: Array[StringName] = []
var _job: StringName = &""
var _selected: StringName = &""
var _base: StringName = &""
var _tree := true
var _embedded := true
var _options: Array[Dictionary] = []
var _gray_material: ShaderMaterial
const INK := Color("263b54")
const BLUE := Color("397fb9")
const RED := Color("af4d4e")
const GRAY := Color("87919a")
const CREAM := Color("f7f5ef")

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	visible = false
	resized.connect(_layout)

func configure(facade: RefCounted, character_id: String, editable: bool) -> void:
	draft.configure(facade, character_id, editable)
	if draft.facade != null:
		var profile: ProfileState = draft.facade.current_profile()
		var character: CharacterState = profile.character_by_id(draft.character_id) if profile != null else null
		_base = character.base_class_id if character != null else &""
	_refresh()

func configure_catalog(options: Array[Dictionary], summary: Dictionary, base_class: StringName) -> void:
	if draft.is_uncertain(): return
	draft.facade = null
	draft.character_id = ""
	draft.revision = -1
	draft.editable = false
	draft.sequence.clear()
	draft.preview = {"ok": true, "skills": options.duplicate(true), "summary": summary.duplicate(true), "can_apply": false, "pending_counts": {}}
	_base = base_class
	_refresh()

func set_embedded(value: bool) -> void:
	_embedded = value
	if value: visible = true
	_layout()

func open() -> void:
	if draft.facade != null:
		configure(draft.facade, draft.character_id, draft.editable)
	visible = true
	_layout()

func dismiss() -> void:
	if draft.facade != null: draft.reset()
	else: draft.sequence.clear()
	_refresh()
	visible = false
	closed.emit()

func _style(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var value := StyleBoxFlat.new()
	value.bg_color = background
	value.border_color = border
	value.set_border_width_all(width)
	value.set_corner_radius_all(5)
	value.set_content_margin_all(5)
	return value

func _label(parent: Node, text: String, rect: Rect2, color: Color = INK, font_size: int = 14, wrap: bool = false) -> Label:
	var label := Label.new()
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", GRAY)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_stylebox_override("normal", _style(Color.WHITE, Color("bcc6ce")))
	button.add_theme_stylebox_override("hover", _style(Color("e8f2fa"), BLUE))
	button.add_theme_stylebox_override("pressed", _style(Color("d8e9f5"), BLUE))
	button.add_theme_stylebox_override("disabled", _style(Color("eeeae5"), Color("c5c7c8")))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build() -> void:
	_body = Control.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	var classic_theme := Theme.new()
	classic_theme.set_color("font_color", "Label", INK)
	classic_theme.set_color("font_color", "Button", INK)
	classic_theme.set_color("font_hover_color", "Button", INK)
	classic_theme.set_color("font_pressed_color", "Button", INK)
	classic_theme.set_stylebox("normal", "Button", _style(Color.WHITE, GRAY))
	classic_theme.set_stylebox("hover", "Button", _style(Color("e8f2fa"), BLUE))
	classic_theme.set_stylebox("pressed", "Button", _style(Color("d8e9f5"), BLUE))
	_body.theme = classic_theme
	skill_panel = Panel.new()
	detail_panel = Panel.new()
	for panel: Panel in [skill_panel, detail_panel]:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_theme_stylebox_override("panel", _style(CREAM, Color("a6b2bf")))
		_body.add_child(panel)
	for panel: Panel in [skill_panel, detail_panel]:
		var header := Panel.new()
		header.name = "Header"
		header.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_theme_stylebox_override("panel", _style(INK, INK))
		panel.add_child(header)
		_label(header, "Habilidades" if panel == skill_panel else "Detalhes e atalhos", Rect2(14, 5, 330, 36), Color.WHITE, 20)
	var close := _button(detail_panel, "×", dismiss)
	close.name = "Close"
	close.tooltip_text = "Fechar habilidades"
	_tabs = HFlowContainer.new()
	_tabs.add_theme_constant_override("h_separation", 4)
	_tabs.add_theme_constant_override("v_separation", 4)
	skill_panel.add_child(_tabs)
	_wallet = _label(skill_panel, "", Rect2(), INK, 13)
	var switch_view := _button(skill_panel, "Árvore / Lista", func() -> void:
		_tree = not _tree
		_render_skills())
	switch_view.name = "ViewSwitch"
	var legend := _label(skill_panel, "Azul: disponível  ·  Vermelho: adquirido  ·  Cinza: bloqueado", Rect2(14, 139, 520, 25), INK, 12)
	legend.name = "Legend"
	legend.clip_text = true
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	skill_panel.add_child(_scroll)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(_canvas)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "DetailScroll"
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(detail_scroll)
	_details = Label.new()
	_details.text = "Selecione uma habilidade para ver seus efeitos e requisitos."
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_color_override("font_color", INK)
	_details.add_theme_font_size_override("font_size", 14)
	detail_scroll.add_child(_details)
	_label(detail_panel, "Atalhos · apenas habilidades já aprendidas", Rect2(14, 256, 500, 26), INK, 14)
	var action_scroll := ScrollContainer.new()
	action_scroll.name = "ActionScroll"
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_panel.add_child(action_scroll)
	action_host = VBoxContainer.new()
	action_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_scroll.add_child(action_host)
	_undo = _button(skill_panel, "Desfazer pendências", func() -> void:
		draft.reset()
		_status.text = "Pendências desfeitas."
		_refresh())
	_apply = _button(skill_panel, "✓ Aplicar", _confirm)
	_respec = _button(skill_panel, "Redistribuir aprendidas", func() -> void: respec_requested.emit())
	_status = _label(skill_panel, "", Rect2(), INK, 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _layout() -> void:
	if _body == null: return
	var extent := size
	if extent.x < 100 or extent.y < 100: return
	_body.size = extent if _embedded else Vector2(minf(1160, extent.x - 32), minf(540, extent.y - 32))
	_body.position = Vector2.ZERO if _embedded else (extent - _body.size) * 0.5
	var width := (_body.size.x - 14) * 0.5
	var height := _body.size.y
	skill_panel.position = Vector2.ZERO
	detail_panel.position = Vector2(width + 14, 0)
	skill_panel.size = Vector2(width, height)
	detail_panel.size = Vector2(width, height)
	for panel: Panel in [skill_panel, detail_panel]:
		var header := panel.get_node("Header") as Panel
		header.size = Vector2(width, 46)
	var close := detail_panel.get_node("Close") as Button
	close.position = Vector2(width - 58, 1)
	close.size = Vector2(52, 44)
	_tabs.position = Vector2(12, 53)
	_tabs.size = Vector2(width - 24, 58)
	_wallet.position = Vector2(14, 116)
	_wallet.size = Vector2(width - 145, 24)
	(skill_panel.get_node("Legend") as Label).size = Vector2(width - 28, 25)
	var view := skill_panel.get_node("ViewSwitch") as Button
	view.position = Vector2(width - 134, 112)
	view.size = Vector2(120, 28)
	_scroll.position = Vector2(12, 167)
	_scroll.size = Vector2(width - 24, maxf(70, height - 267))
	_undo.position = Vector2(12, height - 92)
	_undo.size = Vector2((width - 36) * 0.57, 32)
	_apply.position = Vector2(_undo.position.x + _undo.size.x + 12, height - 92)
	_apply.size = Vector2(width - _apply.position.x - 12, 32)
	_respec.position = Vector2(12, height - 53)
	_respec.size = Vector2(192, 30)
	_status.position = Vector2(213, height - 55)
	_status.size = Vector2(width - 225, 47)
	var detail_scroll := detail_panel.get_node("DetailScroll") as ScrollContainer
	detail_scroll.position = Vector2(14, 58)
	detail_scroll.size = Vector2(width - 28, 190)
	var action_scroll := detail_panel.get_node("ActionScroll") as ScrollContainer
	action_scroll.position = Vector2(12, 287)
	action_scroll.size = Vector2(width - 24, maxf(70, height - 299))

func _refresh() -> void:
	if not draft.preview.get("ok", false):
		_status.text = "Selecione um personagem para ver suas habilidades."
		_details.text = "Crie ou selecione um personagem no lobby."
	elif not draft.editable and not draft.is_uncertain():
		_status.text = "Consulta: confirme pontos no lobby."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_options.clear()
	_jobs.clear()
	_jobs.append(&"")
	for option: Dictionary in draft.preview.get("skills", []):
		if ClassCatalog.skill_definition(StringName(option["skill_id"])) == null: continue
		_options.append(option)
		var job := StringName(option["metadata"].get("required_evolution_id", &""))
		if not _jobs.has(job): _jobs.append(job)
	if not _jobs.has(_job): _job = &""
	for child: Node in _tabs.get_children():
		_tabs.remove_child(child)
		child.queue_free()
	for job: StringName in _jobs:
		var button := _button(_tabs, SkillPresentation.job_name(job, _base), _choose_job.bind(job))
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_stylebox_override("normal", _style(Color("dbeaf4") if job == _job else Color.WHITE, BLUE if job == _job else GRAY))
	var summary: Dictionary = draft.preview.get("summary", {})
	_wallet.text = "Livres: Base %d · Evolução %d" % [int(summary.get("base_skill_points_available", 0)), int(summary.get("evolution_skill_points_available", 0))]
	_undo.disabled = draft.sequence.is_empty() or draft.is_uncertain() or not draft.editable
	_apply.disabled = not draft.is_uncertain() and (draft.sequence.is_empty() or not draft.editable or not draft.preview.get("can_apply", false))
	_apply.text = "Verificar aplicação" if draft.is_uncertain() else "✓ Aplicar (%d)" % draft.sequence.size()
	_respec.disabled = not draft.editable or draft.is_uncertain() or not draft.preview.get("can_apply", false)
	_render_skills()
	_show_details()

func _choose_job(job: StringName) -> void:
	_job = job
	_refresh()

func _render_skills() -> void:
	for child: Node in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	skill_entries.clear()
	var shown: Array[Dictionary] = []
	for option: Dictionary in _options:
		if StringName(option["metadata"].get("required_evolution_id", &"")) == _job: shown.append(option)
	var levels: Dictionary = {}
	for option: Dictionary in shown: levels[StringName(option["skill_id"])] = 0
	# Bounded relaxation gives vertical levels from the actual prerequisite DAG.
	for iteration: int in shown.size():
		var changed := false
		for option: Dictionary in shown:
			var id := StringName(option["skill_id"])
			for prerequisite: Variant in SkillPresentation.prerequisites(option):
				if levels.has(prerequisite) and int(levels[id]) <= int(levels[prerequisite]):
					levels[id] = int(levels[prerequisite]) + 1
					changed = true
		if not changed: break
	var positions: Dictionary = {}
	var y := 10.0
	if _tree:
		var max_level := 0
		for value: Variant in levels.values(): max_level = maxi(max_level, int(value))
		for level: int in range(max_level + 1):
			var index := 0
			for option: Dictionary in shown:
				var id := StringName(option["skill_id"])
				if int(levels[id]) != level: continue
				positions[id] = Vector2(10 + (index % 4) * 126, y + (index / 4) * 158)
				index += 1
			if index > 0: y += ceilf(float(index) / 4.0) * 158
		for option: Dictionary in shown:
			var id := StringName(option["skill_id"])
			var requirements := SkillPresentation.prerequisites(option)
			for prerequisite: Variant in requirements:
				if not positions.has(prerequisite): continue
				var start: Vector2 = positions[prerequisite] + Vector2(55, 132)
				var finish: Vector2 = positions[id] + Vector2(55, 0)
				var line := Line2D.new()
				line.width = 1.5
				line.default_color = Color("a1afbe")
				line.points = PackedVector2Array([start, Vector2(start.x, finish.y - 18), Vector2(finish.x, finish.y - 18), finish])
				_canvas.add_child(line)
				_label(_canvas, "R%d" % int(requirements[prerequisite]), Rect2(finish.x + 3, finish.y - 20, 34, 18), INK, 10)
	else:
		for option: Dictionary in shown:
			positions[StringName(option["skill_id"])] = Vector2(10, y)
			y += 82
	_canvas.custom_minimum_size = Vector2(514, maxf(100, y))
	for option: Dictionary in shown:
		_make_entry(option, positions[StringName(option["skill_id"])])

func _make_entry(option: Dictionary, point: Vector2) -> void:
	var id := StringName(option["skill_id"])
	var pending := int(draft.preview.get("pending_counts", {}).get(id, 0))
	var rank := int(option["rank"])
	var item_rank := int(option.get("item_rank", 0))
	var can_add := bool(option.get("next_rank_available", false))
	var color := RED if rank > 0 or item_rank > 0 else (BLUE if can_add else GRAY)
	var card := Panel.new()
	card.position = point
	card.size = Vector2(110, 132) if _tree else Vector2(484, 72)
	card.add_theme_stylebox_override("panel", _style(Color.WHITE, BLUE if pending > 0 else color, 2 if pending > 0 or id == _selected else 1))
	_canvas.add_child(card)
	var button := SkillButton.new()
	button.flat = true
	button.size = Vector2(110, 98) if _tree else Vector2(398, 72)
	button.tooltip_text = SkillPresentation.describe(option, draft.preview.get("summary", {}))
	button.pressed.connect(_select.bind(id))
	card.add_child(button)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = SkillPresentation.icon(id)
	if rank == 0 and item_rank == 0 and not can_add:
		if _gray_material == null:
			_gray_material = ShaderMaterial.new()
			_gray_material.shader = load("res://scripts/ui/skill_locked_icon.gdshader") as Shader
		icon.material = _gray_material
	icon.position = Vector2(31, 4) if _tree else Vector2(8, 11)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(48, 48)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var name_label := _label(button, SkillPresentation.name_of(id), Rect2(4, 54, 102, 30) if _tree else Rect2(66, 5, 324, 32), color, 12, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size = Vector2(102, 30) if _tree else Vector2(324, 32)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _tree else HORIZONTAL_ALIGNMENT_LEFT
	var state := "Item R%d" % item_rank if item_rank > 0 else ("Disponível" if can_add else ("Aprendida" if rank > 0 else "Bloqueada"))
	var text := "%d/%d · %s" % [rank, int(option["maximum_rank"]), state]
	if pending > 0: _label(button, "+%d" % pending, Rect2(82, 4, 28, 20) if _tree else Rect2(357, 5, 36, 20), BLUE, 13)
	var rank_label := _label(button, text, Rect2(3, 85, 104, 18) if _tree else Rect2(66, 40, 324, 22), color, 10 if _tree else 12)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _tree else HORIZONTAL_ALIGNMENT_LEFT
	var plus := _button(card, "+", _change.bind(id, true))
	var minus := _button(card, "−", _change.bind(id, false))
	plus.position = Vector2(60, 104) if _tree else Vector2(438, 19)
	minus.position = Vector2(8, 104) if _tree else Vector2(402, 19)
	plus.size = Vector2(42, 28) if _tree else Vector2(32, 32)
	minus.size = plus.size
	plus.disabled = not can_add or not draft.editable or draft.is_uncertain() or not draft.preview.get("can_apply", false)
	minus.disabled = pending <= 0 or not draft.editable or draft.is_uncertain()
	minus.tooltip_text = "Remover apenas um aumento pendente; dependências precisam continuar válidas."
	skill_entries[id] = {"button": button, "plus": plus, "minus": minus, "card": card, "option": option}

func _select(id: StringName) -> void:
	_selected = id
	_show_details()

func _show_details() -> void:
	for option: Dictionary in _options:
		if StringName(option["skill_id"]) != _selected: continue
		var text := SkillPresentation.describe(option, draft.preview.get("summary", {}))
		var dependents: Array[String] = []
		for other: Dictionary in _options:
			var requirements := SkillPresentation.prerequisites(other)
			if requirements.has(_selected): dependents.append("%s (exige R%d)" % [SkillPresentation.name_of(StringName(other["skill_id"])), int(requirements[_selected])])
		if not dependents.is_empty(): text += "\nCaminho seguinte: " + ", ".join(dependents)
		var summary: Dictionary = draft.preview.get("summary", {})
		text += "\nInvestimento total: Base %d · Evolução %d\nPendências deste lote: %d ponto(s)." % [int(summary.get("base_skill_points_spent", 0)), int(summary.get("evolution_skill_points_spent", 0)), draft.sequence.size()]
		_details.text = text
		return
	_details.text = "Selecione uma habilidade para ver seus efeitos e requisitos.\nCada aumento custa 1 ponto da carteira indicada.\nAtalhos recebem somente habilidades já aprendidas."

func _change(id: StringName, increase: bool) -> void:
	var result: Dictionary = draft.add(id) if increase else draft.remove(id)
	_status.text = "%d ponto(s) pendente(s)." % draft.sequence.size() if result.get("ok", false) else "A mudança exige manter os requisitos das habilidades."
	_refresh()

func _confirm() -> void:
	var result := draft.apply()
	_status.text = "Habilidades aplicadas." if result.get("ok", false) else ("Verifique a aplicação pendente." if draft.is_uncertain() else "Aplicação não concluída; confira os requisitos e tente novamente.")
	_refresh()
	transaction_result.emit(result)






