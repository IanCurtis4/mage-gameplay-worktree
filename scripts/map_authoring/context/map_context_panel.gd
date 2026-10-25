@tool
extends VBoxContainer
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
var session: RefCounted
var biome: LineEdit
var instances: OptionButton
var rules: ItemList
var reason: LineEdit
var warnings: Label

static func mount(parent: Control, document_session: RefCounted) -> void:
	var window := Window.new(); window.title = "Contexto do mapa · Exceções manuais"; window.size = Vector2i(650,440)
	parent.add_child(window); window.close_requested.connect(window.hide)
	var panel := load("res://scripts/map_authoring/context/map_context_panel.gd").new() as Control
	panel.session = document_session; window.add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var button := Button.new(); button.text = "Contexto do mapa…"; parent.add_child(button)
	button.pressed.connect(func() -> void: panel.refresh(); window.popup_centered())
func _ready() -> void:
	var title := Label.new(); title.text = "Bioma de destino e exceções por instância"; add_child(title)
	biome = LineEdit.new(); biome.placeholder_text = "Bioma de destino · ex.: ruin"; add_child(biome)
	instances = OptionButton.new(); add_child(instances); instances.item_selected.connect(func(_i: int) -> void: select_instance())
	rules = ItemList.new(); rules.select_mode = ItemList.SELECT_MULTI; rules.custom_minimum_size.y = 110; add_child(rules)
	for caption: String in ["Bioma permitido","Espécies permitidas","Sorteio de raros","Reserva de encontro"]: rules.add_item(caption)
	reason = LineEdit.new(); reason.placeholder_text = "Motivo obrigatório para a exceção"; add_child(reason)
	var button := Button.new(); button.text = "Salvar contexto / exceção selecionada"; button.pressed.connect(save_context); add_child(button)
	warnings = Label.new(); warnings.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(warnings)
func refresh() -> void:
	var context: Dictionary = session.data.get("context",Context.empty_map()); biome.text = context.biome_id
	instances.clear()
	for instance: Dictionary in session.data.instances: instances.add_item(instance.instance_id)
	select_instance(); show_warnings()
func select_instance() -> void:
	rules.deselect_all(); reason.text = ""
	if instances.selected < 0: return
	var id := instances.get_item_text(instances.selected)
	for exception: Dictionary in session.data.get("context",Context.empty_map()).overrides:
		if exception.instance_id != id: continue
		reason.text = exception.reason
		for index: int in Context.RULES.size():
			if Context.RULES[index] in exception.rules: rules.select(index,false)
func save_context() -> void:
	var data: Dictionary = session.data.duplicate(true); var context: Dictionary = data.get("context",Context.empty_map()).duplicate(true)
	context.biome_id = biome.text.strip_edges()
	if instances.selected >= 0:
		var id := instances.get_item_text(instances.selected)
		context.overrides = context.overrides.filter(func(item: Dictionary) -> bool: return item.instance_id != id)
		var chosen: Array = []
		for index: int in rules.get_selected_items(): chosen.append(Context.RULES[index])
		if not chosen.is_empty(): context.overrides.append({"instance_id":id,"rules":chosen,"reason":reason.text.strip_edges()})
	data.context = context; var result: Dictionary = session.apply(data)
	if result.ok: show_warnings()
	else: warnings.text = "Não foi possível salvar: "+str(result.get("code","context_invalid"))
func show_warnings() -> void:
	var lines := PackedStringArray(["Sem exceções. Geração por seed sempre respeita as regras da peça."])
	if not Context.warnings(session.data).is_empty():
		lines.clear()
		for warning: Dictionary in Context.warnings(session.data): lines.append(warning.message)
	warnings.text = "\n".join(lines)
