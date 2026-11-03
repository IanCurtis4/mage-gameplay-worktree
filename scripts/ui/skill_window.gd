class_name SkillWindow
extends Control
## A bounded two-panel view; progression and transaction rules belong to the draft.
signal transaction_result(result: Dictionary)
signal closed
signal respec_requested

class SkillButton extends Button:
	var skill_id: StringName = &""
	var cast_rank := 0
	var drag_allowed := false
	func drag_payload() -> Variant:
		return {"kind": "action_skill", "skill_id": skill_id, "rank": cast_rank, "source_index": -1} if drag_allowed else null
	func _get_drag_data(_position: Vector2) -> Variant:
		var payload: Variant = drag_payload()
		if payload == null: return null
		var preview := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = SkillPresentation.icon(skill_id)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(32, 32)
		preview.add_child(icon)
		var label := Label.new()
		label.text = "%s · %s" % [SkillPresentation.name_of(skill_id), "maior rank" if cast_rank == 0 else "R%d" % cast_rank]
		preview.add_child(label)
		set_drag_preview(preview)
		return payload
	func _make_custom_tooltip(for_text: String) -> Object:
		return SkillTooltip.create(for_text, self)

var draft := SkillAllocationDraft.new()
var action_host: VBoxContainer
var skill_panel: Panel
var detail_panel: Panel
var skill_entries: Dictionary = {}
var _body: Control
var _tabs: HFlowContainer
var _scroll: ScrollContainer
var _canvas: Control
var _details: RichTextLabel
var _rank_picker: OptionButton
var _rank_choices: Dictionary = {}
var _wallet: Label
var _status: Label
var _apply: Button
var _undo: Button
var _respec: Button
var _jobs: Array[StringName] = []
var _job: StringName = &""
var _selected: StringName = &""
var _navigation: Array[Dictionary] = []
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
	if character_id != draft.character_id:
		_rank_choices.clear()
		_navigation.clear()
	draft.configure(facade, character_id, editable)
	if draft.facade != null:
		var profile: ProfileState = draft.facade.current_profile()
		var character: CharacterState = profile.character_by_id(draft.character_id) if profile != null else null
		_base = character.base_class_id if character != null else &""
	_refresh()

func configure_catalog(options: Array[Dictionary], summary: Dictionary, base_class: StringName) -> void:
	if draft.is_uncertain(): return
	_navigation.clear()
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
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.focus_mode = Control.FOCUS_ALL
	_details.meta_clicked.connect(_follow_requirement)
	_details.gui_input.connect(_navigation_key)
	_details.fit_content = true
	_details.scroll_active = false
	_details.text = "Selecione uma habilidade para ver seus efeitos e requisitos."
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_color_override("default_color", INK)
	_details.add_theme_font_size_override("normal_font_size", 14)
	detail_scroll.add_child(_details)
	_rank_picker = OptionButton.new()
	_rank_picker.tooltip_text = "Escolha a versão antes de arrastar. Cada versão usa o próprio custo e poder; a recarga é compartilhada."
	_rank_picker.item_selected.connect(_pick_rank)
	detail_panel.add_child(_rank_picker)
	_label(detail_panel, "Arraste da árvore/lista para um atalho", Rect2(14, 256, 500, 26), INK, 14)
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
	detail_scroll.size = Vector2(width - 28, 151)
	_rank_picker.position = Vector2(14, 214)
	_rank_picker.size = Vector2(width - 28, 32)
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
		if ClassCatalog.skill_definition(StringName(option["skill_id"])) == null or not option.get("available", false): continue
		_options.append(option)
		var job := StringName(option["metadata"].get("required_evolution_id", &""))
		if not _jobs.has(job): _jobs.append(job)
	var confirmed_ranks: Dictionary = {}
	for option: Dictionary in _options:
		var id := StringName(option["skill_id"])
		confirmed_ranks[id] = maxi(int(option.get("item_rank", 0)), int(option["rank"]) - int(draft.preview.get("pending_counts", {}).get(id, 0)))
	for child: Node in action_host.get_children():
		if child is ActionBarEditor: child.available_ranks = confirmed_ranks.duplicate()
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
		var placed := _branch_positions(shown, levels)
		positions = placed["positions"]
		y = placed["height"]
		for option: Dictionary in shown:
			var id := StringName(option["skill_id"])
			var requirements := SkillPresentation.prerequisites(option)
			for prerequisite: Variant in requirements:
				if not positions.has(prerequisite): continue
				var start: Vector2 = positions[prerequisite] + Vector2(46, 104)
				var finish: Vector2 = positions[id] + Vector2(46, 0)
				var line := Line2D.new()
				line.width = 1.5
				line.default_color = Color("a1afbe")
				line.points = PackedVector2Array([start, Vector2(start.x, finish.y - 18), Vector2(finish.x, finish.y - 18), finish])
				_canvas.add_child(line)
				_label(_canvas, "R%d" % int(requirements[prerequisite]), Rect2(finish.x + 3, finish.y - 20, 34, 18), INK, 10)
	else:
		for option: Dictionary in shown:
			positions[StringName(option["skill_id"])] = Vector2(10, y)
			y += 58
	_canvas.custom_minimum_size = Vector2(514, maxf(100, y))
	for option: Dictionary in shown:
		_make_entry(option, positions[StringName(option["skill_id"])])

func _branch_positions(shown: Array[Dictionary], levels: Dictionary) -> Dictionary:
	# Pack each actual prerequisite root as an independent vertical cluster.
	# No decorative dependency is invented for skills without a prerequisite.
	var roots: Array[StringName] = []
	var branch: Dictionary = {}
	var ordered := shown.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(levels[a["skill_id"]]) < int(levels[b["skill_id"]]))
	for option: Dictionary in ordered:
		var id := StringName(option["skill_id"])
		if int(levels[id]) == 0:
			roots.append(id)
			branch[id] = id
		else:
			for prerequisite: Variant in SkillPresentation.prerequisites(option):
				if branch.has(prerequisite):
					branch[id] = branch[prerequisite]
					break
			if not branch.has(id):
				roots.append(id)
				branch[id] = id
	var result: Dictionary = {}
	var x := 10.0
	var base_y := 10.0
	var band_height := 0.0
	for root_id: StringName in roots:
		var by_depth: Dictionary = {}
		var width := 1
		for option: Dictionary in ordered:
			var id := StringName(option["skill_id"])
			if branch[id] != root_id: continue
			var depth := int(levels[id])
			if not by_depth.has(depth): by_depth[depth] = []
			by_depth[depth].append(id)
			width = maxi(width, by_depth[depth].size())
		if x + width * 100 > 514 and x > 10:
			x = 10.0
			base_y += band_height + 30.0
			band_height = 0.0
		for depth: int in by_depth:
			var nodes: Array = by_depth[depth]
			for index: int in nodes.size():
				result[nodes[index]] = Vector2(x + (width - nodes.size()) * 50 + index * 100, base_y + depth * 140)
			band_height = maxf(band_height, (depth + 1) * 140)
		x += width * 100
	return {"positions": result, "height": base_y + band_height + 10}

func _make_entry(option: Dictionary, point: Vector2) -> void:
	var id := StringName(option["skill_id"])
	var pending := int(draft.preview.get("pending_counts", {}).get(id, 0))
	var rank := int(option["rank"])
	var item_rank := int(option.get("item_rank", 0))
	var can_add := bool(option.get("next_rank_available", false))
	var color := RED if rank > 0 or item_rank > 0 else (BLUE if can_add else GRAY)
	var card := Panel.new()
	card.position = point
	card.size = Vector2(92, 104) if _tree else Vector2(484, 50)
	card.add_theme_stylebox_override("panel", _style(Color.WHITE, BLUE if pending > 0 else color, 2 if pending > 0 or id == _selected else 1))
	_canvas.add_child(card)
	var button := SkillButton.new()
	button.flat = true
	button.skill_id = id
	var confirmed := maxi(0, rank - pending)
	confirmed = maxi(confirmed, item_rank)
	button.drag_allowed = confirmed > 0 and ClassCatalog.skill_definition(id).category == SkillDefinition.Category.ACTIVE and option.get("available", false)
	button.cast_rank = int(_rank_choices.get(id, 0))
	if button.cast_rank > confirmed: button.cast_rank = 0
	button.size = Vector2(92, 78) if _tree else Vector2(420, 50)
	button.tooltip_text = SkillPresentation.describe(option, draft.preview.get("summary", {}))
	if button.drag_allowed: button.tooltip_text += "\n[b]Versão para arrastar: %s[/b]" % ("maior rank disponível" if button.cast_rank == 0 else "R%d" % button.cast_rank)
	button.pressed.connect(pin_skill.bind(id))
	button.focus_entered.connect(_select.bind(id))
	button.mouse_entered.connect(hover_skill.bind(id))
	button.gui_input.connect(_navigation_key)
	card.add_child(button)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = SkillPresentation.icon(id)
	if rank == 0 and item_rank == 0 and not can_add:
		if _gray_material == null:
			_gray_material = ShaderMaterial.new()
			_gray_material.shader = load("res://scripts/ui/skill_locked_icon.gdshader") as Shader
		icon.material = _gray_material
	icon.position = Vector2(30, 3) if _tree else Vector2(8, 9)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2(32, 32)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var name_label := _label(button, SkillPresentation.name_of(id), Rect2(3, 39, 86, 32) if _tree else Rect2(50, 2, 344, 24), color, 12, true)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.clip_text = true
	name_label.max_lines_visible = 2
	name_label.size = Vector2(86, 38) if _tree else Vector2(344, 24)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _tree else HORIZONTAL_ALIGNMENT_LEFT
	var state := "Item R%d" % item_rank if item_rank > 0 else ("Disponível" if can_add else ("Aprendida" if rank > 0 else "Bloqueada"))
	var text := "%d/%d" % [rank, int(option["maximum_rank"])] if _tree else "%d/%d · %s" % [rank, int(option["maximum_rank"]), state]
	if pending > 0: _label(button, "+%d" % pending, Rect2(69, 3, 23, 20) if _tree else Rect2(357, 5, 36, 20), BLUE, 13)
	var rank_label := _label(button, text, Rect2(26, 81, 40, 18) if _tree else Rect2(50, 26, 344, 20), color, 10 if _tree else 12)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _tree else HORIZONTAL_ALIGNMENT_LEFT
	var plus := _button(card, "+", _change.bind(id, true))
	var minus := _button(card, "−", _change.bind(id, false))
	for control: Button in [plus, minus]:
		control.add_theme_font_size_override("font_size", 10)
		for state_name: String in ["normal", "hover", "pressed", "disabled"]:
			var compact := control.get_theme_stylebox(state_name).duplicate() as StyleBoxFlat
			compact.content_margin_top = 0
			compact.content_margin_bottom = 0
			control.add_theme_stylebox_override(state_name, compact)
	plus.position = Vector2(68, 82) if _tree else Vector2(454, 17)
	minus.position = Vector2(4, 82) if _tree else Vector2(422, 17)
	plus.size = Vector2(20, 16) if _tree else Vector2(24, 16)
	minus.size = plus.size
	plus.disabled = not can_add or not draft.editable or draft.is_uncertain() or not draft.preview.get("can_apply", false)
	minus.disabled = pending <= 0 or not draft.editable or draft.is_uncertain()
	minus.tooltip_text = "Remover apenas um aumento pendente; dependências precisam continuar válidas."
	var inspection := SkillDependencyRules.inspect(id, _options, draft.preview.get("summary", {}))
	var external: Array[Dictionary] = []
	for requirement: Dictionary in inspection["requirements"]:
		if StringName(requirement["job_id"]) != _job: external.append(requirement)
	if not external.is_empty():
		var badge := _label(card, "↗", Rect2(2, 2, 18, 18) if _tree else Rect2(400, 2, 18, 18), BLUE, 13)
		badge.name = "OriginBadge"
		var descriptions: Array[String] = []
		for requirement: Dictionary in external:
			var source := StringName(requirement["skill_id"])
			var needed := int(requirement["required_rank"])
			var learned := int(requirement["learned_rank"])
			descriptions.append("%s · %s · R%d exigido · R%d aprendido · %s · %s" % [SkillPresentation.job_name(StringName(requirement["job_id"]), _base), SkillPresentation.name_of(source), needed, learned, "satisfeito" if requirement["satisfied"] else "falta rank", "Base" if StringName(requirement["job_id"]).is_empty() else "Evolução"])
		button.tooltip_text += "\nVínculo externo: " + "; ".join(descriptions)
	skill_entries[id] = {"button": button, "plus": plus, "minus": minus, "card": card, "option": option}

func _select(id: StringName) -> void:
	_selected = id
	_render_selection()
	_show_details()

func _render_selection() -> void:
	for entry_id: StringName in skill_entries:
		var entry: Dictionary = skill_entries[entry_id]
		var card: Panel = entry["card"]
		var option: Dictionary = entry["option"]
		var rank := int(option["rank"])
		var color := RED if rank > 0 or int(option.get("item_rank", 0)) > 0 else (BLUE if option.get("next_rank_available", false) else GRAY)
		card.add_theme_stylebox_override("panel", _style(Color.WHITE, BLUE if entry_id == _selected else color, 2 if entry_id == _selected else 1))

func _follow_requirement(meta: Variant) -> void:
	var target := String(meta)
	if target == "back":
		if _navigation.is_empty(): return
		var previous: Dictionary = _navigation.pop_back()
		_job = StringName(previous["job"])
		_selected = StringName(previous["selected"])
		_refresh()
		_scroll.scroll_horizontal = int(previous["horizontal"])
		_scroll.scroll_vertical = int(previous["vertical"])
		return
	if not target.begins_with("skill:"): return
	var id := StringName(target.trim_prefix("skill:"))
	for option: Dictionary in _options:
		if StringName(option["skill_id"]) != id: continue
		var job := StringName(option["metadata"].get("required_evolution_id", &""))
		if not _jobs.has(job): return
		_navigation.append({"job": _job, "selected": _selected, "horizontal": _scroll.scroll_horizontal, "vertical": _scroll.scroll_vertical})
		_job = job
		_selected = id
		_refresh()
		_scroll.ensure_control_visible(skill_entries[id]["card"])
		return

func _navigation_key(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo: return
	if event.keycode == KEY_B and not _navigation.is_empty():
		_follow_requirement("back")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_O:
		var inspection := SkillDependencyRules.inspect(_selected, _options, draft.preview.get("summary", {}))
		if inspection["requirements"].is_empty(): return
		_follow_requirement("skill:%s" % String(inspection["requirements"][0]["skill_id"]))
		get_viewport().set_input_as_handled()

## F10 Q3: hovering previews a skill; a click pins its description, so moving
## the pointer away to read it does not replace it. A second click releases it.
var pinned_skill: StringName = &""
func hover_skill(id: StringName) -> void:
	if pinned_skill.is_empty(): _select(id)

func pin_skill(id: StringName) -> void:
	pinned_skill = &"" if pinned_skill == id else id
	_select(id)

func _show_details() -> void:
	_rank_picker.clear()
	_rank_picker.visible = false
	for option: Dictionary in _options:
		if StringName(option["skill_id"]) != _selected: continue
		var text := SkillPresentation.describe(option, draft.preview.get("summary", {}))
		var inspection := SkillDependencyRules.inspect(_selected, _options, draft.preview.get("summary", {}))
		var quick_links: Array[String] = []
		for requirement: Dictionary in inspection["requirements"]:
			var source := StringName(requirement["skill_id"])
			quick_links.append("[url=skill:%s]%s · %s %d/%d[/url]" % [String(source), SkillPresentation.job_name(StringName(requirement["job_id"]), _base), SkillPresentation.name_of(source), int(requirement["learned_rank"]), int(requirement["required_rank"])])
		if not quick_links.is_empty():
			var title_end := text.find("\n")
			text = text.insert(title_end if title_end >= 0 else text.length(), "\nRequer: " + " · ".join(quick_links))
		text += "\n\n[b]Requisitos e caminho[/b]"
		for requirement: Dictionary in inspection["requirements"]:
			var origin := StringName(requirement["job_id"])
			var source := StringName(requirement["skill_id"])
			var learned := int(requirement["learned_rank"])
			var needed := int(requirement["required_rank"])
			var state := "satisfeito" if requirement["satisfied"] else "faltam %d ranks" % (needed - learned)
			text += "\n• [url=skill:%s]Ver na origem[/url] · %s (%s): R%d exigido · R%d aprendido · %s · %s" % [String(source), SkillPresentation.name_of(source), SkillPresentation.job_name(origin, _base), needed, learned, state, "Base" if origin.is_empty() else "Evolução"]
		var direct: Dictionary = {}
		for requirement: Dictionary in inspection["requirements"]: direct[StringName(requirement["skill_id"])] = true
		var ancestors: Array = inspection.get("ancestors", [])
		var has_older := false
		for requirement: Dictionary in ancestors:
			if direct.has(StringName(requirement["skill_id"])): continue
			if not has_older:
				text += "\n[b]Cadeia de requisitos[/b]"
				has_older = true
			var origin := StringName(requirement["job_id"])
			var source := StringName(requirement["skill_id"])
			var learned := int(requirement["learned_rank"])
			var needed := int(requirement["required_rank"])
			var state := "satisfeito" if requirement["satisfied"] else "faltam %d ranks" % (needed - learned)
			text += "\n• [url=skill:%s]Ver na origem[/url] · %s (%s): R%d exigido · R%d aprendido · %s · %s" % [String(source), SkillPresentation.name_of(source), SkillPresentation.job_name(origin, _base), needed, learned, state, "Base" if origin.is_empty() else "Evolução"]
		var missing: Dictionary = inspection["missing_by_wallet"]
		var purchase: Dictionary = inspection["purchase_by_wallet"]
		text += "\nFaltam para liberar: Base %d · Evolução %d." % [int(missing[&"base"]), int(missing[&"evolution"])]
		if option.get("item_only", false):
			text += "\nConcedida por equipamento; não conta como investimento aprendido."
		elif not inspection["maximum"]:
			text += "\nComprar esta habilidade R%d: Base %d · Evolução %d." % [int(option["rank"]) + 1, int(purchase[&"base"]), int(purchase[&"evolution"])]
		else:
			text += "\nRank máximo aprendido."
		text += "\nJob %d: %s · Pontos por carteira: %s." % [int(inspection["required_job"]), "satisfeito" if inspection["job_met"] else "falta job", "suficientes" if inspection["points_met"] else "insuficientes"]
		if not inspection["requirements"].is_empty(): text += "\nTeclado: O abre a primeira origem; B volta."
		if not _navigation.is_empty():
			var previous: Dictionary = _navigation.back()
			text += "\n[url=back]Voltar para %s[/url]" % SkillPresentation.name_of(StringName(previous["selected"]))
		var confirmed := maxi(int(option.get("item_rank", 0)), int(option["rank"]) - int(draft.preview.get("pending_counts", {}).get(_selected, 0)))
		var definition := ClassCatalog.skill_definition(_selected)
		if confirmed > 0 and definition.category == SkillDefinition.Category.ACTIVE:
			_rank_picker.visible = true
			_rank_picker.add_item("Versão: maior rank disponível (R%d)" % confirmed, 0)
			if SkillCastRank.supports(_selected):
				for rank: int in range(1, confirmed + 1):
					var values := definition.rank_definition(rank)
					_rank_picker.add_item("Versão R%d · %.0f SP base" % [rank, values.sp_cost], rank)
			for index: int in _rank_picker.item_count:
				if _rank_picker.get_item_id(index) == int(_rank_choices.get(_selected, 0)): _rank_picker.select(index)
		var dependents: Array[String] = []
		for other: Dictionary in _options:
			var requirements := SkillPresentation.prerequisites(other)
			if requirements.has(_selected): dependents.append("%s (exige R%d)" % [SkillPresentation.name_of(StringName(other["skill_id"])), int(requirements[_selected])])
		if not dependents.is_empty(): text += "\nCaminho seguinte: " + ", ".join(dependents)
		var summary: Dictionary = draft.preview.get("summary", {})
		text += "\nInvestimento total: Base %d · Evolução %d\nPendências deste lote: %d ponto(s)." % [int(summary.get("base_skill_points_spent", 0)), int(summary.get("evolution_skill_points_spent", 0)), draft.sequence.size()]
		_details.text = text
		return
	_details.text = "Selecione uma habilidade para ver seus efeitos e requisitos.\nCada aumento custa 1 ponto da carteira indicada.\nSelecione uma ativa confirmada, escolha a versão e arraste até um atalho."

func _pick_rank(index: int) -> void:
	_rank_choices[_selected] = _rank_picker.get_item_id(index)
	_render_skills()
	_show_details()

func _change(id: StringName, increase: bool) -> void:
	var result: Dictionary = draft.add(id) if increase else draft.remove(id)
	_status.text = "%d ponto(s) pendente(s)." % draft.sequence.size() if result.get("ok", false) else "A mudança exige manter os requisitos das habilidades."
	_refresh()

func _confirm() -> void:
	var result := draft.apply()
	_status.text = "Habilidades aplicadas." if result.get("ok", false) else ("Verifique a aplicação pendente." if draft.is_uncertain() else "Aplicação não concluída; confira os requisitos e tente novamente.")
	_refresh()
	transaction_result.emit(result)
