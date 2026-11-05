@tool
extends VBoxContainer
const Operations = preload("res://scripts/map_authoring/terrain/terrain_operations.gd")
const OrganicExample = preload("res://scripts/map_authoring/terrain/organic_example.gd")
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Canvas = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const Library = preload("res://scripts/map_authoring/library/library_model.gd")
const SynthesisSection = preload("res://scripts/map_authoring/synthesis/synthesis_section.gd")
signal layer_selected(id: String)
signal inspection_compiled(completed: Dictionary)
var session: RefCounted
var canvas: Control
var selected_layer := ""
var mode: OptionButton
var shape: OptionButton
var material_choice: OptionButton
var radius: SpinBox
var strength: SpinBox
var hardness: SpinBox
var target: SpinBox
var end_height: SpinBox
var status: Label
var progress_bar: ProgressBar
var job: RefCounted
var result: Dictionary = {}
var _job_generation := 0
var hide_layer: CheckBox
var bridge_x: SpinBox
var bridge_z: SpinBox
var bridge_width: SpinBox
var bridge_length: SpinBox
var bridge_height: SpinBox
var grid_columns: SpinBox
var grid_rows: SpinBox
var grid_spacing: SpinBox
var grid_x: SpinBox
var grid_z: SpinBox
var grid_y: SpinBox
var connector_list: ItemList
var connector_id: LineEdit
var connector_surface: OptionButton
var connector_side: OptionButton
var connector_direction: OptionButton
var connector_x: SpinBox
var connector_y: SpinBox
var connector_z: SpinBox
var connector_width: SpinBox
var connector_headroom: SpinBox
var connector_tags: LineEdit
var preset_choice: OptionButton
var preset_name: LineEdit
var _applying_preset := false
var _preferences_seen := ""
## Checkpoint43 (F9-05): "Variação regional" section; it is its own AX provider.
var synthesis: VBoxContainer

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HFlowContainer.new(); add_child(row)
	mode = OptionButton.new()
	for caption: String in ["Elevar","Baixar","Nivelar","Suavizar","Pintar material","Rampa (arraste início → fim)","Colina arredondada"]: mode.add_item(caption)
	row.add_child(mode)
	shape = OptionButton.new(); shape.add_item("Círculo"); shape.add_item("Quadrado"); row.add_child(shape)
	material_choice = OptionButton.new()
	for caption: String in ["Terra","Grama","Areia","Pedra"]: material_choice.add_item(caption)
	row.add_child(material_choice)
	hide_layer = CheckBox.new(); hide_layer.text = "Ocultar camada"; row.add_child(hide_layer)
	hide_layer.toggled.connect(func(hidden: bool) -> void:
		if hidden and selected_layer not in canvas.hidden_layers: canvas.hidden_layers.append(selected_layer)
		elif not hidden: canvas.hidden_layers.erase(selected_layer)
		canvas.cancel_stroke(); canvas.redraw_terrain())
	var overlay := CheckBox.new(); overlay.text = "Grade técnica"; row.add_child(overlay)
	overlay.toggled.connect(func(enabled: bool) -> void: canvas.wire_overlay = enabled; canvas.queue_redraw())
	var settings := HFlowContainer.new(); add_child(settings)
	radius = _number(settings,"Raio",1,512,48)
	strength = _number(settings,"Força por segundo (exceto rampa)",0,128,8)
	hardness = _number(settings,"Dureza",0,1,0.5,0.05)
	target = _number(settings,"Altura inicial",-512,512,0)
	end_height = _number(settings,"Final",-512,512,40)
	# Presets/AX may carry exact fractional values. Arrow increments must not
	# quantize the stored brush parameters when a preset is loaded.
	for field: SpinBox in [radius,strength,hardness,target,end_height]:
		field.custom_arrow_step = field.step; field.step = 0
	strength.custom_arrow_step = 0.05
	var preset_row := HFlowContainer.new(); add_child(preset_row)
	preset_choice = OptionButton.new(); preset_row.add_child(preset_choice)
	preset_choice.item_selected.connect(func(index: int) -> void:
		var id := str(preset_choice.get_item_metadata(index))
		if not id.is_empty(): apply_preset(id))
	preset_name = LineEdit.new(); preset_name.placeholder_text = "Nome da predefinição"; preset_name.max_length = 80; preset_name.custom_minimum_size.x = 180; preset_row.add_child(preset_name)
	_button(preset_row,"Salvar predefinição",save_preset).set_meta("authoring_keep_visible",true)
	_button(preset_row,"Remover predefinição",remove_preset).set_meta("authoring_keep_visible",true)
	var toolbar := HFlowContainer.new(); add_child(toolbar)
	_button(toolbar,"Enquadrar",func() -> void: canvas.fit())
	_button(toolbar,"Compilar peça",bake)
	_button(toolbar,"Cancelar",func() -> void:
		canvas.cancel_stroke()
		if job != null: job.cancel())
	_button(toolbar,"Exemplo rampa/ponte",create_sample)
	_button(toolbar,"Exemplo de peça grande",create_large_sample)
	_button(toolbar,"Exemplo orgânico",create_organic_example)
	progress_bar = ProgressBar.new(); progress_bar.custom_minimum_size.x = 150; toolbar.add_child(progress_bar)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	var grid := HFlowContainer.new(); add_child(grid)
	grid_columns = _number(grid,"Amostras X",2,257,5)
	grid_rows = _number(grid,"Z",2,257,5)
	grid_spacing = _number(grid,"Passo",4,256,32)
	grid_x = _number(grid,"Origem X",-8192,8192,0)
	grid_z = _number(grid,"Z",-8192,8192,0)
	grid_y = _number(grid,"Altura",-512,512,0)
	_button(grid,"Nova grade",add_grid)
	canvas = Canvas.new(); add_child(canvas); canvas.custom_minimum_size.y = 420
	canvas.stroke_finished.connect(apply_stroke)
	canvas.temporal_finished.connect(_apply_temporal)
	canvas.status.connect(func(message: String) -> void: status.text = message)
	var bridge := HFlowContainer.new(); add_child(bridge)
	bridge_x = _number(bridge,"Ponte X",-8192,8192,0)
	bridge_z = _number(bridge,"Z",-8192,8192,100)
	bridge_width = _number(bridge,"Largura X",4,1024,200)
	bridge_length = _number(bridge,"Z",4,1024,100)
	bridge_height = _number(bridge,"Altura",4,1024,40)
	_button(bridge,"Adicionar ponte",add_bridge)
	var connection_toggle := CheckBox.new(); connection_toggle.text = "Editar pontos de conexão"; add_child(connection_toggle)
	var connections := VBoxContainer.new(); connections.visible = false; add_child(connections)
	connection_toggle.toggled.connect(func(enabled: bool) -> void: connections.visible = enabled)
	connector_list = ItemList.new(); connector_list.custom_minimum_size.y = 75; connections.add_child(connector_list)
	connector_list.item_selected.connect(_select_connector)
	var connection_names := HFlowContainer.new(); connections.add_child(connection_names)
	connector_id = LineEdit.new(); connector_id.placeholder_text = "ID da conexão"; connector_id.custom_minimum_size.x = 180; connection_names.add_child(connector_id)
	connector_surface = OptionButton.new(); connection_names.add_child(connector_surface)
	connector_side = OptionButton.new()
	for caption: String in ["Oeste ←","Leste →","Norte ↖","Sul ↘"]: connector_side.add_item(caption)
	connection_names.add_child(connector_side)
	connector_direction = OptionButton.new()
	for caption: String in ["Ida e volta","Só entrada","Só saída"]: connector_direction.add_item(caption)
	connection_names.add_child(connector_direction)
	connector_tags = LineEdit.new(); connector_tags.placeholder_text = "Compatibilidade · tags separadas por vírgula"; connector_tags.text = "map_editor"; connector_tags.custom_minimum_size.x = 230; connections.add_child(connector_tags)
	var connection_values := HFlowContainer.new(); connections.add_child(connection_values)
	connector_x = _number(connection_values,"X",-8192,8192,0)
	connector_y = _number(connection_values,"Altura",-8192,8192,0)
	connector_z = _number(connection_values,"Z",-8192,8192,50)
	connector_width = _number(connection_values,"Largura",4,8192,32)
	connector_headroom = _number(connection_values,"Folga",12,8192,100)
	_button(connection_values,"Adicionar / atualizar",save_connector)
	_button(connection_values,"Remover",remove_connector)
	synthesis = SynthesisSection.new(); add_child(synthesis); synthesis.setup(self)
	var help := Label.new(); help.text = "Selecione a camada antes de pintar. Arraste: um traço; Esc/sair do quadro: cancelar. Roda: zoom · botão central: mover.\nRampa/nivelar/suavizar/material: força entre 0 e 1. Salve a peça para preservar o terreno e as conexões."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(help)
	for control: OptionButton in [mode,shape,material_choice]: control.item_selected.connect(func(_i: int) -> void: _options_changed())
	for control: SpinBox in [radius,strength,hardness,target,end_height]: control.value_changed.connect(func(_v: float) -> void: _options_changed())
	for field: SpinBox in [radius,strength,hardness,target,end_height]:
		field.get_line_edit().text_submitted.connect(func(_text: String) -> void: _display_brush_number.call_deferred(field))
		field.get_line_edit().focus_exited.connect(func() -> void: _display_brush_number.call_deferred(field))
	_options_changed()
	_refresh_presets()
	preload("res://scripts/map_authoring/preview/viewport_tools.gd").mount(canvas,"terrain")
	preload("res://addons/ragrpg_map_editor/presentation.gd").mount(self,"terrain",func() -> Dictionary: return session.document().to_data() if session != null else {},null,{"Pincel":[row,settings,preset_row],"Nova grade":[grid],"Ponte":[bridge],"Conexões":[connection_toggle,connections],"Variação regional":[synthesis]})
	# Keep the drawing area above the longer tool forms inside the scroll view.
	move_child(canvas.get_parent(),1)

func _number(parent: Node, caption: String, low: float, high: float, value: float, step: float = 1.0) -> SpinBox:
	var label := Label.new(); label.text = caption; parent.add_child(label)
	var number := SpinBox.new(); number.min_value = low; number.max_value = high; number.step = step; number.value = value; number.custom_minimum_size.x = 80; parent.add_child(number)
	return number

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var button := Button.new(); button.text = caption; button.pressed.connect(action); parent.add_child(button)
	return button

func bind(document_session: RefCounted) -> void:
	session = document_session
	session.changed.connect(refresh)
	refresh()

func select_layer(id: String) -> void:
	selected_layer = id
	if is_instance_valid(hide_layer): hide_layer.set_pressed_no_signal(id in canvas.hidden_layers)
	refresh()
	layer_selected.emit(selected_layer)

func refresh() -> void:
	if session == null or session.document() == null or not is_instance_valid(canvas): return
	var data: Dictionary = session.document().to_data()
	var exists := false
	for layer: Dictionary in data.layers:
		if layer.layer_id == selected_layer: exists = true
	if not exists: selected_layer = data.layers[0].layer_id if not data.layers.is_empty() else ""
	canvas.set_source(data,selected_layer)
	_refresh_connectors(data)
	result = {}
	if job != null: job.cancel()
	if synthesis != null: synthesis.refresh()
	status.text = "Selecione ou adicione uma camada; compile após editar para conferir suporte e aberturas."

func _options_changed() -> void:
	if _applying_preset or not is_instance_valid(canvas): return
	canvas.cancel_stroke()
	canvas.options = {"mode":Preferences.MODES[mode.selected],"shape":"circle" if shape.selected == 0 else "square","material":["earth","grass","sand","stone"][material_choice.selected],"radius":radius.value,"strength":strength.value,"hardness":hardness.value,"target":target.value,"end_height":end_height.value}
	for field: SpinBox in [radius,strength,hardness,target,end_height]:
		_display_brush_number(field); _display_brush_number.call_deferred(field)

func _display_brush_number(field: SpinBox) -> void:
	if not is_instance_valid(field): return
	# SpinBox formats step0 as an integer. Keep the shortest decimal that parses
	# back to the exact value, independently of the arrow increment.
	var text := JSON.stringify(field.value,"",true,true)
	for decimals: int in 18:
		var candidate := String.num(field.value,decimals)
		if candidate.to_float() == field.value: text = candidate; break
	field.get_line_edit().text = text

func _refresh_presets(selected: String = "") -> void:
	preset_choice.clear(); preset_choice.add_item("Predefinição · parâmetros atuais"); preset_choice.set_item_metadata(0,"")
	var prefs := Preferences.read()
	if not prefs.ok:
		status.text = "As preferências precisam de recuperação; as predefinições foram preservadas."
		return
	for item: Dictionary in Library.presets(prefs.data):
		preset_choice.add_item(item.name); preset_choice.set_item_metadata(preset_choice.item_count-1,item.id)
		if item.id == selected: preset_choice.select(preset_choice.item_count-1)
	_preferences_seen = prefs.hash

func apply_preset(id: String) -> Dictionary:
	var prefs := Preferences.read()
	if not prefs.ok: return prefs
	var found := Library.preset(id,prefs.data)
	if not found.ok: return found
	var options: Dictionary = found.preset.options
	_applying_preset = true
	mode.select(Preferences.MODES.find(options.mode)); shape.select(0 if options.shape == "circle" else 1); material_choice.select(["earth","grass","sand","stone"].find(options.material))
	radius.value = options.radius; strength.value = options.strength; hardness.value = options.hardness; target.value = options.target; end_height.value = options.end_height
	_applying_preset = false; _options_changed(); preset_name.text = found.preset.name; _refresh_presets(id)
	status.text = "Predefinição aplicada ao pincel. O terreno muda somente no próximo traço."
	return {"ok":true,"preset_id":id,"options":canvas.options.duplicate(true)}

func save_preset() -> void:
	var saved := save_named_preset(preset_name.text,canvas.options)
	status.text = "Predefinição salva neste projeto." if saved.ok else "Não foi possível salvar a predefinição (%s)."%saved.code

func save_named_preset(caption: String, options: Dictionary) -> Dictionary:
	var title := caption.strip_edges()
	if title.is_empty(): return {"ok":false,"code":"preset_name_missing"}
	var id := "custom_"+Library.folded(title).sha256_text().substr(0,24)
	var saved := Preferences.transact({"operation":"preset_save","preset":{"id":id,"name":title,"options":options.duplicate(true)}})
	if saved.ok: _refresh_presets(id)
	return saved

func remove_preset() -> void:
	var id := str(preset_choice.get_item_metadata(preset_choice.selected))
	var result := Preferences.transact({"operation":"preset_remove","id":id})
	if result.ok: _refresh_presets(); status.text = "Predefinição removida; os parâmetros atuais do pincel foram mantidos."
	else: status.text = "Escolha uma predefinição pessoal para remover. As predefinições do projeto são preservadas."

func authoring_commands() -> Array:
	return [{"id":"terrain/example/organic","parameters":{}},{"id":"terrain/brush/stroke","parameters":{"points":"number[2][]","options":"brush_options"}},{"id":"terrain/presets/list","parameters":{}},{"id":"terrain/presets/apply","parameters":{"preset_id":"string"}},{"id":"terrain/presets/save","parameters":{"name":"string","options":"brush_options"}},
		{"id":"terrain/grid/create","parameters":{"layer_id":"id","name":"string","origin_xz":"number[2]","columns":"integer 2..257","rows":"integer 2..257","sample_spacing":"number 4..256","height":"number -512..512","surface_mode":"optional: exact_planes | height_grid"}},
		{"id":"terrain/layer/surface_mode","parameters":{"layer_id":"id","surface_mode":"exact_planes | height_grid"}},
		{"id":"terrain/layer/select","parameters":{"layer_id":"id"}},
		{"id":"terrain/layer/lock","parameters":{"layer_id":"id","locked":"boolean"}},
		{"id":"terrain/layer/protection","parameters":{"layer_id":"id","region_ids":"existing region IDs[]"}},
		{"id":"terrain/bridge/create","parameters":{"surface_id":"id","layer_id":"id","origin_xz":"number[2]","width":"number 4..1024","length":"number 4..1024","height":"number 4..1024"}},
		{"id":"terrain/connector/upsert","parameters":Operations.Schema.FIELDS.connectors.duplicate()},
		{"id":"terrain/connector/remove","parameters":{"connector_id":"id"}}]

func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	if id == "terrain/layer/select":
		if not Preferences._keys(parameters,["layer_id"]) or not Operations.Schema._type(parameters.layer_id,"id"): return {"ok":false,"code":"arguments_invalid"}
		if Operations._layer(session.document().to_data(),parameters.layer_id).is_empty(): return {"ok":false,"code":"source_reference_missing"}
		select_layer(parameters.layer_id)
		return {"ok":true,"entity_id":selected_layer,"output_hash":session.document().semantic_hash()}
	if id.trim_prefix("terrain/") in ["grid/create","bridge/create","connector/upsert","connector/remove","layer/lock","layer/protection","layer/surface_mode"]:
		return apply_operation(id.trim_prefix("terrain/"),parameters)
	if id == "terrain/example/organic":
		if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
		return create_organic_example()
	if id == "terrain/brush/stroke":
		if not Preferences._keys(parameters,["points","options"]) or not parameters.points is Array or not Preferences.valid_options(parameters.options): return {"ok":false,"code":"arguments_invalid"}
		var points: Array = []
		for point: Variant in parameters.points:
			if not point is Array or point.size() != 2 or not (point[0] is int or point[0] is float) or not (point[1] is int or point[1] is float): return {"ok":false,"code":"arguments_invalid"}
			points.append(Vector2(point[0],point[1]))
		return apply_stroke(points,parameters.options)
	if id == "terrain/presets/list":
		if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
		var prefs := Preferences.read()
		return {"ok":true,"presets":Library.presets(prefs.data),"preferences_hash":prefs.hash} if prefs.ok else prefs
	if id == "terrain/presets/apply":
		if not Preferences._keys(parameters,["preset_id"]) or not parameters.preset_id is String: return {"ok":false,"code":"arguments_invalid"}
		return apply_preset(parameters.preset_id)
	if id == "terrain/presets/save":
		if not Preferences._keys(parameters,["name","options"]) or not parameters.name is String or not parameters.options is Dictionary: return {"ok":false,"code":"arguments_invalid"}
		return save_named_preset(parameters.name,parameters.options)
	return {"ok":false,"code":"action_missing"}

func _apply_temporal(proposal: Dictionary) -> void:
	if not proposal.ok:
		status.text = "O traço não pôde ser aplicado. Confira a camada e os parâmetros."
		return
	if proposal.changed <= 0: return
	var followed: Array = proposal.followed_sockets
	var applied: Dictionary = session.apply(proposal.data)
	if not applied.ok:
		status.text = "O traço não pôde ser aplicado. Confira a camada e os parâmetros."
		canvas.redraw_terrain()
	elif not followed.is_empty(): status.text = "Marcadores que acompanharam o relevo: "+", ".join(followed)+"."

func apply_stroke(points: Array, options: Dictionary) -> Dictionary:
	var proposal := Brush.stroke(session.document().to_data(),selected_layer,points,options)
	var followed: Array = proposal.get("followed_sockets",[])
	if proposal.ok and proposal.changed > 0: proposal = session.apply(proposal.data)
	if not proposal.ok: status.text = "Destrave a camada para editar." if proposal.code == "layer_locked" else "O traço não pôde ser aplicado. Confira a camada e os parâmetros."
	elif not followed.is_empty():
		proposal.followed_sockets = followed
		status.text = "Marcadores que acompanharam o relevo: "+", ".join(followed)+"."
	return proposal

func apply_operation(operation: String, parameters: Dictionary) -> Dictionary:
	var proposal := Operations.propose(session.document().to_data(),operation,parameters)
	if not proposal.ok:
		status.text = "Destrave a camada para editar." if proposal.code == "layer_locked" else "A operação não pôde ser aplicada. Confira os parâmetros e as regiões protegidas."
		return proposal
	if not proposal.changed: return proposal
	var applied: Dictionary = session.apply(proposal.data)
	applied.entity_id = proposal.entity_id
	if applied.ok:
		if operation == "grid/create": select_layer(proposal.entity_id)
		if operation in ["grid/create","bridge/create"]: canvas.fit()
		status.text = "Alteração aplicada. Compile a peça para conferir a geometria."
	return applied

func add_bridge(surface_id: String = "") -> void:
	if selected_layer.is_empty(): return
	if surface_id.is_empty(): surface_id = "bridge_"+Crypto.new().generate_random_bytes(8).hex_encode()
	apply_operation("bridge/create",{"surface_id":surface_id,"layer_id":selected_layer,"origin_xz":[bridge_x.value,bridge_z.value],"width":bridge_width.value,"length":bridge_length.value,"height":bridge_height.value})

func add_grid(layer_id: String = "") -> void:
	if layer_id.is_empty(): layer_id = "layer_"+Crypto.new().generate_random_bytes(8).hex_encode()
	apply_operation("grid/create",{"layer_id":layer_id,"name":"Camada %d"%(session.document().to_data().layers.size()+1),"origin_xz":[grid_x.value,grid_z.value],"columns":int(grid_columns.value),"rows":int(grid_rows.value),"sample_spacing":grid_spacing.value,"height":grid_y.value})

static func sample_source(data: Dictionary) -> Dictionary:
	var source := data.duplicate(true)
	source.name = "Clareira, rampa e ponte"
	source.layers = [
		_layer("lower","Clareira / passagem inferior",0,0,100,2,3,[0,0,0,0,0,0]),
		_layer("ramp","Rampa",100,0,100,2,2,[0,40,0,40]),
		_layer("plateau","Platô",200,0,100,2,3,[40,40,40,40,40,40])]
	source.layers[0].material_masks = {"grass":[1,1,0.3,0.3,1,1],"earth":[0,0,0.7,0.7,0,0]}
	source.special_surfaces = [{"surface_id":"bridge","layer_id":"plateau","vertices_xyz":[[0,40,100],[200,40,100],[200,40,200],[0,40,200]],"headroom":100}]
	source.connectors = []; source.sockets = []; source.regions = []; source.dependencies = []; source.placements = []; source.composition = null
	return source

static func _layer(id: String, caption: String, x: float, z: float, spacing: float, columns: int, rows: int, heights: Array) -> Dictionary:
	return {"layer_id":id,"name":caption,"origin_xz":[x,z],"sample_spacing":spacing,"columns":columns,"rows":rows,"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]}

static func large_sample_source(data: Dictionary, axis: int = 65) -> Dictionary:
	var source := data.duplicate(true); source.name = "Campo amplo · uma peça"
	var heights: Array = []; var earth: Array = []; var grass: Array = []
	var spacing := 8192.0/float(axis-1)
	for z: int in axis:
		for x: int in axis:
			var wx := x*spacing; var wz := z*spacing
			heights.append(clampf((wx-3072.0)/1024.0,0.0,1.0)*128.0)
			var center := 3500.0+sin(wx/1700.0)*700.0
			var weight := clampf(1.0-absf(wz-center)/500.0,0.0,1.0)
			earth.append(weight); grass.append(1.0-weight)
	source.layers = [_layer("field","Campo, subida e platô",0,0,spacing,axis,axis,heights)]
	source.layers[0].material_masks = {"grass":grass,"earth":earth}
	source.special_surfaces = []; source.regions = []; source.dependencies = []; source.placements = []; source.sockets = []; source.composition = null
	source.connectors = [{"connector_id":"west_gate","surface_id":"field","position_xyz":[0,0,3500],"kind":"walk","normal_xyz":[-1,0,0],"width":256,"headroom":100,"tags":["map_editor"],"direction":"both"}]
	return source

func create_organic_example() -> Dictionary:
	var proposal := OrganicExample.create(session.document().to_data())
	if not proposal.ok:
		status.text = "Crie uma peça vazia para abrir o exemplo orgânico; seu conteúdo foi preservado." if proposal.code == "source_occupied" else "O exemplo orgânico não pôde ser preparado."
		return proposal
	var applied: Dictionary = session.apply(proposal.data)
	if applied.ok:
		select_layer("organic_field"); canvas.fit()
	else: status.text = "O exemplo orgânico não pôde ser aplicado."
	return applied

func create_large_sample() -> void:
	if not session.document().to_data().layers.is_empty(): status.text = "Crie uma peça vazia para abrir o exemplo grande; seu terreno foi preservado."; return
	session.apply(large_sample_source(session.document().to_data()))
	select_layer("field"); canvas.fit()

func _refresh_connectors(data: Dictionary) -> void:
	if not is_instance_valid(connector_list): return
	var current_surface := str(connector_surface.get_item_metadata(connector_surface.selected)) if connector_surface.selected >= 0 else selected_layer
	connector_list.clear(); connector_surface.clear()
	for layer: Dictionary in data.layers:
		connector_surface.add_item(layer.name); connector_surface.set_item_metadata(connector_surface.item_count-1,layer.layer_id)
		if layer.layer_id == current_surface: connector_surface.select(connector_surface.item_count-1)
	for special: Dictionary in data.special_surfaces:
		connector_surface.add_item("Piso especial · "+special.surface_id); connector_surface.set_item_metadata(connector_surface.item_count-1,special.surface_id)
		if special.surface_id == current_surface: connector_surface.select(connector_surface.item_count-1)
	for connector: Dictionary in data.connectors:
		connector_list.add_item(connector.connector_id)
		if connector.connector_id == connector_id.text: connector_list.select(connector_list.item_count-1)

func _select_connector(index: int) -> void:
	var connector: Dictionary = session.document().to_data().connectors[index]
	connector_id.text = connector.connector_id
	for i: int in connector_surface.item_count:
		if connector_surface.get_item_metadata(i) == connector.surface_id: connector_surface.select(i)
	connector_x.value = connector.position_xyz[0]; connector_y.value = connector.position_xyz[1]; connector_z.value = connector.position_xyz[2]
	connector_width.value = connector.width; connector_headroom.value = connector.headroom
	connector_side.select(0 if connector.normal_xyz[0] < 0 else (1 if connector.normal_xyz[0] > 0 else (2 if connector.normal_xyz[2] < 0 else 3)))
	connector_direction.select(["both","in","out"].find(connector.direction))
	connector_tags.text = ", ".join(connector.tags)

func _surface_locked(data: Dictionary, id: String) -> bool:
	return Operations.surface_locked(data,id)

func save_connector() -> void:
	if connector_surface.selected < 0: return
	var normals: Array = [[-1,0,0],[1,0,0],[0,0,-1],[0,0,1]]
	var next := {"connector_id":connector_id.text.strip_edges(),"surface_id":connector_surface.get_item_metadata(connector_surface.selected),"position_xyz":[connector_x.value,connector_y.value,connector_z.value],"normal_xyz":normals[connector_side.selected],"width":connector_width.value,"headroom":connector_headroom.value,"kind":"walk","tags":[],"direction":["both","in","out"][connector_direction.selected]}
	for tag: String in connector_tags.text.split(",",false):
		var value := tag.strip_edges()
		if value not in next.tags: next.tags.append(value)
	apply_operation("connector/upsert",next)

func remove_connector() -> void:
	apply_operation("connector/remove",{"connector_id":connector_id.text})

func create_sample() -> void:
	if not session.document().to_data().layers.is_empty():
		status.text = "Crie uma peça vazia para abrir o exemplo; seu terreno atual foi preservado."
		return
	session.apply(sample_source(session.document().to_data()))
	select_layer("lower"); canvas.fit()

func bake() -> void:
	if job != null: return
	canvas.cancel_stroke()
	_job_generation = session.generation
	job = Compiler.new(); job.start(session.document().to_data())
	status.text = "Compilando terreno…"; result = {}; canvas.package = {}

func _process(_delta: float) -> void:
	if synthesis != null: synthesis.poll()
	if job == null: return
	progress_bar.value = job.progress()*100
	if not job.ready(): return
	var completed: Dictionary = job.take(session.document().semantic_hash()); job = null
	if _job_generation != session.generation: completed = Compiler.failure("stale_source")
	result = completed
	if completed.ok:
		canvas.package = completed.package; canvas.queue_redraw()
		status.text = "Peça compilada. Terreno e pontos de conexão válidos."
	else:
		var messages := {"cancelled":"Compilação cancelada.","stale_source":"A fonte mudou; compile novamente.","geometry_overlap":"Há pisos sobrepostos na mesma altura.","insufficient_headroom":"A passagem sob a ponte não tem folga.","slope_too_steep":"A inclinação supera 45°; alongue a rampa.","terrain_limit_exceeded":"O relevo excede o orçamento de 1024 suportes gerados. Reduza a densidade de amostras ou simplifique o relevo.","connector_invalid":"Um conector não coincide com uma abertura válida."}
		status.text = messages.get(completed.code,completed.diagnostics[0].message if not completed.diagnostics.is_empty() else "Não foi possível compilar; confira a fonte.")
		if not completed.diagnostics.is_empty():
			var diagnostic: Dictionary = completed.diagnostics[0]
			if diagnostic.has("position_xyz"):
				var at: Array = diagnostic.position_xyz
				if is_instance_valid(canvas._viewport_tools): canvas._viewport_tools.focus_world(Vector3(at[0],at[1],at[2]))
			else: status.text += " Região: " + str(diagnostic.entity_id)
	inspection_compiled.emit(completed.duplicate(true))

func _exit_tree() -> void:
	if job != null: job.close(); job = null
