class_name AssetMigrationPanel
extends PanelContainer
signal completed(result: Dictionary)
var facade: ProfileFacade
var assignments: Dictionary = {}
var preview: Dictionary = {}
var rows: VBoxContainer
var report: RichTextLabel
var confirm_check: CheckBox
var confirm_button: Button
var request_id := ""

func configure(value: ProfileFacade) -> void:
	facade = value
	assignments.clear()
	request_id = "migration_%d" % Time.get_ticks_usec()
	if rows == null: _build()
	refresh()

func _build() -> void:
	name = "AssetMigration"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "Distribuir bens entre personagens"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var help := Label.new()
	help.text = "Escolha o dono de cada exemplar. Sugestões não são aplicadas automaticamente. Cartas encaixadas acompanham a peça."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	report = RichTextLabel.new()
	report.custom_minimum_size.y = 200
	report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(report)
	confirm_check = CheckBox.new()
	confirm_check.text = "Conferi os destinos, avisos e referências removidas desta prévia."
	confirm_check.toggled.connect(func(value: bool) -> void: confirm_button.disabled = not value or not preview.get("complete", false))
	column.add_child(confirm_check)
	confirm_button = Button.new()
	confirm_button.text = "Confirmar distribuição e salvar"
	confirm_button.pressed.connect(confirm)
	column.add_child(confirm_button)
	var update_preview := Button.new()
	update_preview.text = "Atualizar prévia"
	update_preview.pressed.connect(refresh)
	column.add_child(update_preview)
	var close := Button.new()
	close.text = "Voltar sem migrar"
	close.pressed.connect(hide)
	column.add_child(close)

func choose(id: String, owner: String) -> void:
	if owner.is_empty(): assignments.erase(id)
	else: assignments[id] = owner
	refresh()

func refresh() -> void:
	preview = facade.preview_asset_migration(assignments)
	confirm_check.set_pressed_no_signal(false)
	confirm_button.disabled = true
	for child: Node in rows.get_children(): rows.remove_child(child); child.queue_free()
	if not preview.get("ok", false):
		report.text = ExpeditionPresentation.error_text(preview.get("error_code", &"unknown"))
		return
	var plan: Dictionary = preview["plan"]
	var catalog := BuildContentLoader.pilot()
	for asset: Dictionary in plan["assets"]:
		var row := VBoxContainer.new()
		rows.add_child(row)
		var label := Label.new()
		var definition: Resource = catalog.get_definition(StringName(asset["kind"]), StringName(asset["definition_id"]))
		var item_name: String = definition.display_name if definition != null else asset["definition_id"]
		label.text = "%s · exemplar %s" % [item_name, asset["instance_id"]]
		if asset["kind"] == "equipment":
			var metadata: Dictionary = asset["metadata"]
			label.text += "\n%s · ilvl %d · %d encaixe(s) · origem: %s" % [EquipmentPresentation.quality_name(StringName(metadata["quality_id"])), metadata["item_level"], metadata["socket_capacity"], PlaytestGameplay.origin_name(StringName(metadata["origin_id"]))]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var id: String = asset["instance_id"]
		if not String(asset["host_id"]).is_empty():
			var note := Label.new()
			note.text = "Encaixada em %s → %s" % [asset["host_id"], _owner_name(plan["destinations"].get(id, ""))]
			row.add_child(note)
			continue
		var selector := OptionButton.new()
		selector.add_item("Escolha o personagem…")
		selector.set_item_metadata(0, "")
		for character: Dictionary in plan["characters"]:
			selector.add_item(character["display_name"])
			selector.set_item_metadata(selector.item_count - 1, character["character_id"])
			if assignments.get(id) == character["character_id"]: selector.select(selector.item_count - 1)
		selector.item_selected.connect(func(index: int) -> void: choose(id, selector.get_item_metadata(index)))
		row.add_child(selector)
		var suggestion: String = plan["suggestions"].get(id, "")
		if not suggestion.is_empty():
			var hint := Label.new()
			hint.text = "Sugestão: %s (selecione para aceitar)" % _owner_name(suggestion)
			row.add_child(hint)
	var lines: Array[String] = ["Prévia: %d destino(s) pendente(s)." % plan["missing"].size(), "Gold legado: zero por personagem; sem compensação.", "IDs, metadados, cartas, encaixes, contadores e recibos serão preservados."]
	if plan["historical_changes"]["converted"]: lines.append("Haverá conversão histórica: %s" % JSON.stringify(plan["historical_changes"]))
	for asset: Dictionary in plan["assets"]:
		lines.append("%s → %s" % [asset["instance_id"], _owner_name(plan["destinations"].get(asset["instance_id"], ""))])
	for removal: Dictionary in plan["removals"]:
		lines.append("Remover referência de %s · %s · %s: %s" % [_owner_name(removal["character_id"]), "equipamento ativo" if removal["layout"] == -1 else "preset %d" % (removal["layout"] + 1), EquipmentPresentation.SLOT_LABELS.get(StringName(removal["slot"]), removal["slot"]), removal["instance_id"]])
	lines.append("Digest da prévia: %s" % preview["plan_digest"])
	report.text = "\n".join(lines)

func _owner_name(id: String) -> String:
	for character: Dictionary in preview.get("plan", {}).get("characters", []):
		if character["character_id"] == id: return character["display_name"]
	return "Destino pendente"

func confirm() -> Dictionary:
	if not confirm_check.button_pressed or not preview.get("complete", false): return BuildEffectCatalog.failure(&"confirmation_required")
	confirm_button.disabled = true
	var result := facade.apply_asset_migration(preview["plan"], preview["plan_digest"], request_id)
	if result.get("ok", false): hide(); completed.emit(result)
	else:
		confirm_check.set_pressed_no_signal(false)
		report.text = ExpeditionPresentation.error_text(result.get("error_code", &"unknown")) + "\nAtualize a prévia antes de confirmar novamente."
	return result
