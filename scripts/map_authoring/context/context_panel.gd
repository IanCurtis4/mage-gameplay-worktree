@tool
extends VBoxContainer
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
var session: RefCounted
var terrain: Control
var biomes: LineEdit
var species: ItemList
var rare: CheckBox
var areas: ItemList
var layer: OptionButton
var area_id: LineEdit
var area_species: ItemList
var area_rare: CheckBox
var reserved: CheckBox
var encounter: LineEdit
var quest: LineEdit
var occurrence: OptionButton
var options: Array = []
var bounds: Array[SpinBox] = []
var message: Label
var _species: Array = []

static func mount(parent: Control, document_session: RefCounted, terrain_panel: Control) -> void:
	var window := Window.new(); window.title = "Contexto da peça · Biomas e encontros"; window.size = Vector2i(750,820)
	window.hide()
	parent.add_child(window); window.close_requested.connect(window.hide)
	var scroll := ScrollContainer.new(); window.add_child(scroll); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := load("res://scripts/map_authoring/context/context_panel.gd").new() as Control
	panel.session = document_session; panel.terrain = terrain_panel; panel.size_flags_horizontal = SIZE_EXPAND_FILL; scroll.add_child(panel)
	var button := Button.new(); button.text = "Contexto da peça…"; parent.add_child(button)
	button.pressed.connect(func() -> void: panel.refresh(); window.popup_centered())

func _ready() -> void:
	label("Uma peça pode servir a vários biomas. Lista de espécies vazia permite todo o catálogo.")
	biomes = text("Biomas separados por vírgula · ex.: ruin, forest")
	species = species_list(); rare = toggle("Permitir sorteio de raros nesta peça")
	button("Salvar regras da peça",save_piece)
	label("Áreas internas · selecione para editar ou crie um retângulo na camada")
	areas = ItemList.new(); areas.custom_minimum_size.y = 80; add_child(areas); areas.item_selected.connect(select_area)
	area_id = text("Nome técnico da área · ex.: clearing")
	layer = OptionButton.new(); add_child(layer)
	var row := HFlowContainer.new(); add_child(row)
	for caption: String in ["X inicial","Z inicial","X final","Z final"]:
		var title := Label.new(); title.text = caption; row.add_child(title)
		var number := SpinBox.new(); number.min_value = -8192; number.max_value = 8192; number.custom_minimum_size.x = 100; row.add_child(number); bounds.append(number)
	bounds[2].value = 128; bounds[3].value = 128
	label("Espécies permitidas na área · vazio mantém a regra da peça")
	area_species = species_list(); area_rare = toggle("Permitir sorteio de raros nesta área")
	reserved = toggle("Reservar esta área para um encontro específico")
	encounter = text("Identificação do encontro · ex.: clearing_guardian")
	occurrence = OptionButton.new(); occurrence.clip_text = true; add_child(occurrence)
	var catalog := Catalog.list_options()
	if catalog.ok:
		options = catalog.options
		for option: Dictionary in options: occurrence.add_item(option.label)
	quest = text("Referência de quest opcional · não cria comportamento de quest")
	button("Adicionar / atualizar área",save_area); button("Remover área selecionada",remove_area)
	message = Label.new(); message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(message)

func label(caption: String) -> void:
	var control := Label.new(); control.text = caption; control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(control)
func text(placeholder: String) -> LineEdit:
	var control := LineEdit.new(); control.placeholder_text = placeholder; add_child(control); return control
func toggle(caption: String) -> CheckBox:
	var control := CheckBox.new(); control.text = caption; add_child(control); return control
func button(caption: String, action: Callable) -> void:
	var control := Button.new(); control.text = caption; control.pressed.connect(action); add_child(control)
func species_list() -> ItemList:
	var list := ItemList.new(); list.select_mode = ItemList.SELECT_MULTI; list.custom_minimum_size.y = 90; add_child(list)
	if _species.is_empty():
		var loaded := Catalog.list_options()
		if loaded.ok:
			var seen := {}
			for option: Dictionary in loaded.options:
				if not seen.has(option.species_id): _species.append(option.species_id); seen[option.species_id] = true
	for id: String in _species: list.add_item(id)
	return list
func selected(list: ItemList) -> Array:
	var result: Array = []
	for index: int in list.get_selected_items(): result.append(_species[index])
	return result
func set_selected(list: ItemList, ids: Array) -> void:
	list.deselect_all()
	for index: int in _species.size():
		if _species[index] in ids: list.select(index,false)
func refresh() -> void:
	var data: Dictionary = session.document().to_data(); var context: Dictionary = data.get("context",Context.empty())
	biomes.text = ", ".join(context.biome_ids); set_selected(species,context.allowed_species); rare.button_pressed = context.allow_rare
	areas.clear(); layer.clear()
	for entry: Dictionary in data.layers: layer.add_item(entry.name); layer.set_item_metadata(layer.item_count-1,entry.layer_id)
	for area: Dictionary in context.areas: areas.add_item(area.region_id+(" · reservado" if not area.reserved.is_empty() else " · livre"))
func apply(data: Dictionary) -> void:
	var result: Dictionary = session.apply(data)
	message.text = "Regras salvas. Reimporte a peça nos mapas que devem usar esta revisão." if result.ok else "Não foi possível salvar: "+str(result.get("code","context_invalid"))
	if result.ok: refresh()
func save_piece() -> void:
	var data: Dictionary = session.document().to_data(); var context: Dictionary = data.get("context",Context.empty()).duplicate(true)
	context.biome_ids = []
	for id: String in biomes.text.split(",",false): context.biome_ids.append(id.strip_edges())
	context.allowed_species = selected(species); context.allow_rare = rare.button_pressed; data.context = context; apply(data)
func select_area(index: int) -> void:
	var data: Dictionary = session.document().to_data(); var area: Dictionary = data.context.areas[index]
	var region := Context._find(data.regions,"region_id",area.region_id)
	area_id.text = area.region_id; set_selected(area_species,area.allowed_species); area_rare.button_pressed = area.allow_rare
	for i: int in layer.item_count:
		if layer.get_item_metadata(i) == region.layer_id: layer.select(i)
	var xs: Array = []; var zs: Array = []
	for pair: Array in region.polygon_xz: xs.append(pair[0]); zs.append(pair[1])
	bounds[0].value = xs.min(); bounds[1].value = zs.min(); bounds[2].value = xs.max(); bounds[3].value = zs.max()
	reserved.button_pressed = not area.reserved.is_empty(); encounter.text = ""; quest.text = ""
	if not area.reserved.is_empty():
		var record: Dictionary = area.reserved[0]; encounter.text = record.encounter_id; quest.text = record.quest_id
		for i: int in options.size():
			if options[i].species_id == record.species_id and options[i].category == record.category and options[i].origin_id == record.origin_id: occurrence.select(i)
func save_area() -> void:
	if layer.selected < 0: message.text = "Crie uma camada antes da área."; return
	if bounds[0].value >= bounds[2].value or bounds[1].value >= bounds[3].value: message.text = "O retângulo precisa ter largura e comprimento positivos."; return
	var id := area_id.text.strip_edges(); var data: Dictionary = session.document().to_data(); var context: Dictionary = data.get("context",Context.empty()).duplicate(true)
	var region := {"region_id":id,"layer_id":layer.get_item_metadata(layer.selected),"polygon_xz":[[bounds[0].value,bounds[1].value],[bounds[2].value,bounds[1].value],[bounds[2].value,bounds[3].value],[bounds[0].value,bounds[3].value]],"purpose":"encounter"}
	var previous := Context._find(data.regions,"region_id",id)
	if not previous.is_empty() and previous.purpose != "encounter": message.text = "Este nome pertence a uma região protegida. Escolha outro."; return
	data.regions = data.regions.filter(func(item: Dictionary) -> bool: return item.region_id != id); data.regions.append(region)
	var area := {"region_id":id,"allowed_species":selected(area_species),"allow_rare":area_rare.button_pressed,"reserved":[]}
	if reserved.button_pressed:
		if occurrence.selected < 0: message.text = "Selecione um monstro do catálogo."; return
		var record: Dictionary = options[occurrence.selected].duplicate(true); record.erase("label"); record.erase("weight"); record.encounter_id = encounter.text.strip_edges(); record.quest_id = quest.text.strip_edges(); area.reserved = [record]
	context.areas = context.areas.filter(func(item: Dictionary) -> bool: return item.region_id != id); context.areas.append(area); data.context = context; apply(data)
func remove_area() -> void:
	var chosen := areas.get_selected_items(); if chosen.is_empty(): return
	var data: Dictionary = session.document().to_data(); var id: String = data.context.areas[chosen[0]].region_id
	data.context.areas.remove_at(chosen[0]); data.regions = data.regions.filter(func(item: Dictionary) -> bool: return item.region_id != id)
	for grid: Dictionary in data.layers: grid.protected_regions.erase(id)
	apply(data)
