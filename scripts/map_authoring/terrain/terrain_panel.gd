@tool
extends VBoxContainer
const Brush = preload("res://scripts/map_authoring/terrain/brush.gd")
const Compiler = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Canvas = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
signal layer_selected(id: String)
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

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new(); add_child(row)
	mode = OptionButton.new()
	for caption: String in ["Elevar","Baixar","Nivelar","Suavizar","Pintar material","Rampa (arraste início → fim)"]: mode.add_item(caption)
	row.add_child(mode)
	shape = OptionButton.new(); shape.add_item("Círculo"); shape.add_item("Quadrado"); row.add_child(shape)
	material_choice = OptionButton.new(); material_choice.add_item("Terra"); material_choice.add_item("Grama"); row.add_child(material_choice)
	hide_layer = CheckBox.new(); hide_layer.text = "Ocultar camada"; row.add_child(hide_layer)
	hide_layer.toggled.connect(func(hidden: bool) -> void:
		if hidden and selected_layer not in canvas.hidden_layers: canvas.hidden_layers.append(selected_layer)
		elif not hidden: canvas.hidden_layers.erase(selected_layer)
		canvas.cancel_stroke(); canvas.queue_redraw())
	var settings := HFlowContainer.new(); add_child(settings)
	radius = _number(settings,"Raio",1,512,48)
	strength = _number(settings,"Força",0,128,8)
	hardness = _number(settings,"Dureza",0,1,0.5,0.05)
	target = _number(settings,"Altura inicial",-512,512,0)
	end_height = _number(settings,"Final",-512,512,40)
	var toolbar := HBoxContainer.new(); add_child(toolbar)
	_button(toolbar,"Enquadrar",func() -> void: canvas.fit())
	_button(toolbar,"Compilar peça",bake)
	_button(toolbar,"Cancelar",func() -> void:
		canvas.cancel_stroke()
		if job != null: job.cancel())
	_button(toolbar,"Exemplo rampa/ponte",create_sample)
	progress_bar = ProgressBar.new(); progress_bar.custom_minimum_size.x = 150; toolbar.add_child(progress_bar)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(status)
	var grid := HFlowContainer.new(); add_child(grid)
	grid_columns = _number(grid,"Grade X",2,17,5)
	grid_rows = _number(grid,"Z",2,17,5)
	grid_spacing = _number(grid,"Passo",4,256,32)
	grid_x = _number(grid,"Origem X",-8192,8192,0)
	grid_z = _number(grid,"Z",-8192,8192,0)
	grid_y = _number(grid,"Altura",-512,512,0)
	_button(grid,"Nova grade",add_grid)
	canvas = Canvas.new(); add_child(canvas)
	canvas.stroke_finished.connect(apply_stroke)
	var bridge := HFlowContainer.new(); add_child(bridge)
	bridge_x = _number(bridge,"Ponte X",-8192,8192,0)
	bridge_z = _number(bridge,"Z",-8192,8192,100)
	bridge_width = _number(bridge,"Largura X",4,1024,200)
	bridge_length = _number(bridge,"Z",4,1024,100)
	bridge_height = _number(bridge,"Altura",4,1024,40)
	_button(bridge,"Adicionar ponte",add_bridge)
	var help := Label.new(); help.text = "Selecione a camada antes de pintar. Arraste: um traço; Esc/sair do quadro: cancelar. Roda: zoom · botão central: mover.\nRampa/nivelar/suavizar/material: força entre 0 e 1. Ponte: piso retangular com 4 unidades de espessura. Teste jogável completo: F3."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; add_child(help)
	for control: OptionButton in [mode,shape,material_choice]: control.item_selected.connect(func(_i: int) -> void: _options_changed())
	for control: SpinBox in [radius,strength,hardness,target,end_height]: control.value_changed.connect(func(_v: float) -> void: _options_changed())
	_options_changed()

func _number(parent: Node, caption: String, low: float, high: float, value: float, step: float = 1.0) -> SpinBox:
	var label := Label.new(); label.text = caption; parent.add_child(label)
	var number := SpinBox.new(); number.min_value = low; number.max_value = high; number.step = step; number.value = value; number.custom_minimum_size.x = 80; parent.add_child(number)
	return number

func _button(parent: Node, caption: String, action: Callable) -> void:
	var button := Button.new(); button.text = caption; button.pressed.connect(action); parent.add_child(button)

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
	result = {}
	if job != null: job.cancel()
	status.text = "Selecione ou adicione uma camada; compile após editar para conferir suporte e aberturas."

func _options_changed() -> void:
	if not is_instance_valid(canvas): return
	canvas.cancel_stroke()
	canvas.options = {"mode":["raise","lower","flatten","smooth","material","ramp"][mode.selected],"shape":"circle" if shape.selected == 0 else "square","material":"earth" if material_choice.selected == 0 else "grass","radius":radius.value,"strength":strength.value,"hardness":hardness.value,"target":target.value,"end_height":end_height.value}

func apply_stroke(points: Array, options: Dictionary) -> Dictionary:
	var proposal := Brush.stroke(session.document().to_data(),selected_layer,points,options)
	if proposal.ok and proposal.changed > 0: proposal = session.apply(proposal.data)
	if not proposal.ok: status.text = "Destrave a camada para editar." if proposal.code == "layer_locked" else "O traço não pôde ser aplicado. Confira a camada e os parâmetros."
	return proposal

func add_bridge() -> void:
	if selected_layer.is_empty(): return
	var data: Dictionary = session.document().to_data()
	for layer: Dictionary in data.layers:
		if layer.layer_id == selected_layer and layer.locked: status.text = "Destrave a camada para adicionar a ponte."; return
	var x := bridge_x.value; var z := bridge_z.value; var y := bridge_height.value
	data.special_surfaces.append({"surface_id":"bridge_"+Crypto.new().generate_random_bytes(8).hex_encode(),"layer_id":selected_layer,"vertices_xyz":[[x,y,z],[x+bridge_width.value,y,z],[x+bridge_width.value,y,z+bridge_length.value],[x,y,z+bridge_length.value]],"headroom":100.0})
	var applied: Dictionary = session.apply(data)
	if not applied.ok: status.text = "A ponte não pôde ser adicionada. Confira a fonte."
	else: canvas.fit()

func add_grid() -> void:
	var data: Dictionary = session.document().to_data()
	var heights: Array = []; heights.resize(int(grid_columns.value)*int(grid_rows.value)); heights.fill(grid_y.value)
	var id := "layer_"+Crypto.new().generate_random_bytes(8).hex_encode()
	data.layers.append({"layer_id":id,"name":"Camada %d"%(data.layers.size()+1),"origin_xz":[grid_x.value,grid_z.value],"sample_spacing":grid_spacing.value,"columns":int(grid_columns.value),"rows":int(grid_rows.value),"heights":heights,"material_masks":{},"locked":false,"protected_regions":[]})
	var applied: Dictionary = session.apply(data)
	if applied.ok: select_layer(id); canvas.fit()
	else: status.text = "A grade não pôde ser adicionada. Confira a fonte."

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
	if job == null: return
	progress_bar.value = job.progress()*100
	if not job.ready(): return
	var completed: Dictionary = job.take(session.document().semantic_hash()); job = null
	if _job_generation != session.generation: completed = Compiler.failure("stale_source")
	result = completed
	if completed.ok:
		canvas.package = completed.package; canvas.queue_redraw()
		status.text = "%d células · %d ligações · %d bordas · pacote %s" % [completed.package.part.surfaces.size(),completed.package.adjacency.size(),completed.package.boundaries.size(),completed.output_hash.substr(0,12)]
	else:
		var messages := {"cancelled":"Compilação cancelada.","stale_source":"A fonte mudou; compile novamente.","geometry_overlap":"Há pisos sobrepostos na mesma altura.","insufficient_headroom":"A passagem sob a ponte não tem folga.","slope_too_steep":"A inclinação supera 45°; alongue a rampa.","terrain_limit_exceeded":"A peça excede o limite técnico de 256 células.","connector_invalid":"Um conector não coincide com uma abertura válida."}
		status.text = messages.get(completed.code,completed.diagnostics[0].message if not completed.diagnostics.is_empty() else "Não foi possível compilar; confira a fonte.")
		if not completed.diagnostics.is_empty(): status.text += " Região: " + str(completed.diagnostics[0].entity_id)

func _exit_tree() -> void:
	if job != null: job.close(); job = null
