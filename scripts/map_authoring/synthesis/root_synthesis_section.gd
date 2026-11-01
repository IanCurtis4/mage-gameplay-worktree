@tool
extends VBoxContainer
## Checkpoint44 (F9-05/07/08, P3b): "Variação regional" on the map, encounter and
## patrol screens. The fields build the root request of RootSynthesis (instance,
## layer and region of that instance's piece, seed, one recipe or "preserve" per
## channel); the preview runs in the background and shows the varied piece and the
## reconciliation summary; "Aplicar variação" commits the whole root as one
## undoable change. AX: <screen>/synthesis/{request,preview,apply,discard}.
const Root = preload("res://scripts/map_authoring/synthesis/root_synthesis.gd")
const Piece = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const Canvas = preload("res://scripts/map_authoring/terrain/terrain_canvas.gd")
const MATERIALS := {"earth":"Terra","grass":"Grama","sand":"Areia","stone":"Pedra"}
var panel: Control
var kind := ""
var screen := ""
var open_button: Button
var window: Window
var body: VBoxContainer
var instance_choice: OptionButton
var layer_choice: OptionButton
var region: OptionButton
var seed_text: LineEdit
var terrain_mode: OptionButton
var amplitude: SpinBox
var feature_size: SpinBox
var roughness: SpinBox
var falloff: SpinBox
var material_mode: OptionButton
var material_choice: OptionButton
var coverage: SpinBox
var patch_size: SpinBox
var object_mode: OptionButton
var definition: OptionButton
var count: SpinBox
var spacing: SpinBox
var replace: CheckBox
var encounter_mode: OptionButton
var progress_bar: ProgressBar
var status: Label
var preview_canvas: Control
var job: RefCounted
var _job_request: Dictionary = {}
var pending: Dictionary = {}

## kind: "map" | "population" | "patrol"; screen: the AX prefix of the panel.
func setup(owner_panel: Control, root_kind: String, screen_id: String) -> void:
	panel = owner_panel; kind = root_kind; screen = screen_id; name = "RootSynthesis"
	set_meta("authoring_command_provider",true)
	# The screen keeps one button (also in the presentation menus); the tool opens
	# in its own scrollable window so it never pushes the screen off its window.
	open_button = Button.new(); open_button.text = "Variação regional…"; open_button.pressed.connect(open); open_button.set_meta("authoring_keep_visible",true); add_child(open_button)
	window = Window.new(); window.title = "Variação regional · "+{"map":"mapa","population":"encontros","patrol":"patrulhas"}.get(kind,kind); window.size = Vector2i(1040,800); window.min_size = Vector2i(720,480); window.visible = false
	window.close_requested.connect(window.hide); add_child(window)
	var scroll := ScrollContainer.new(); scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; window.add_child(scroll)
	var margin := MarginContainer.new(); margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side: String in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	scroll.add_child(margin)
	body = VBoxContainer.new(); body.size_flags_horizontal = Control.SIZE_EXPAND_FILL; margin.add_child(body)
	var intro := Label.new(); intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Gera uma variação dentro de uma região de uma peça do mapa. Só esta posição recebe a peça nova; as outras que usam a mesma peça ficam como estão. Encontros, entrada, saídas e rotas de patrulha mantêm o chão sob eles."
	body.add_child(intro)
	var where := HFlowContainer.new(); body.add_child(where)
	instance_choice = _choice(where,"Posição",[]); instance_choice.item_selected.connect(func(_i: int) -> void: _fill_layers())
	layer_choice = _choice(where,"Camada",[]); layer_choice.item_selected.connect(func(_i: int) -> void: _fill_regions())
	region = _choice(where,"Região",[])
	var seed_label := Label.new(); seed_label.text = "Seed"; where.add_child(seed_label)
	seed_text = LineEdit.new(); seed_text.text = "1"; seed_text.custom_minimum_size.x = 120; where.add_child(seed_text)
	var relief := HFlowContainer.new(); body.add_child(relief)
	terrain_mode = _choice(relief,"Relevo",["Preservar","Gerar relevo"])
	amplitude = _number(relief,"Amplitude",0,512,32)
	feature_size = _number(relief,"Tamanho",8,4096,256)
	roughness = _number(relief,"Aspereza",0,1,0.5,0.05)
	falloff = _number(relief,"Transição",0,4096,96)
	var paint := HFlowContainer.new(); body.add_child(paint)
	material_mode = _choice(paint,"Materiais",["Preservar","Gerar manchas"])
	material_choice = OptionButton.new()
	for id: String in MATERIALS: material_choice.add_item(MATERIALS[id]); material_choice.set_item_metadata(material_choice.item_count-1,id)
	paint.add_child(material_choice)
	coverage = _number(paint,"Cobertura",0,1,0.4,0.05)
	patch_size = _number(paint,"Tamanho",8,4096,192)
	var scatter := HFlowContainer.new(); body.add_child(scatter)
	object_mode = _choice(scatter,"Objetos",["Preservar","Espalhar"])
	definition = OptionButton.new(); scatter.add_child(definition)
	var catalog := Catalog.load_catalog()
	if catalog.ok:
		for id: String in catalog.definitions: definition.add_item(String(catalog.definitions[id].get("name",id))); definition.set_item_metadata(definition.item_count-1,id)
	count = _number(scatter,"Quantidade",0,1024,6)
	spacing = _number(scatter,"Folga",0,8192,16)
	replace = CheckBox.new(); replace.text = "Substituir os soltos dentro"; scatter.add_child(replace)
	if kind in ["population","patrol"]:
		var encounters := HFlowContainer.new(); body.add_child(encounters)
		encounter_mode = _choice(encounters,"Encontros",["Preservar todos","Redistribuir os soltos dentro da região"])
		if kind == "patrol":
			var routes := Label.new(); routes.text = "Patrulhas: preservadas (rotas e seus monstros ficam; o chão sob as rotas não muda)."; encounters.add_child(routes)
	var actions := HFlowContainer.new(); body.add_child(actions)
	for entry: Array in [["Prévia regional",preview],["Aplicar variação",apply_pending],["Descartar prévia",discard],["Cancelar variação",cancel]]:
		var button := Button.new(); button.text = entry[0]; button.pressed.connect(entry[1]); button.set_meta("authoring_keep_visible",true); actions.add_child(button)
	progress_bar = ProgressBar.new(); progress_bar.custom_minimum_size.x = 150; actions.add_child(progress_bar)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; body.add_child(status)
	preview_canvas = Canvas.new(); preview_canvas.custom_minimum_size.y = 240; preview_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE; preview_canvas.visible = false; body.add_child(preview_canvas)

func _choice(parent: Node, caption: String, items: Array) -> OptionButton:
	var label := Label.new(); label.text = caption; parent.add_child(label)
	var option := OptionButton.new()
	for item: String in items: option.add_item(item)
	parent.add_child(option)
	return option

func _number(parent: Node, caption: String, low: float, high: float, value: float, step: float = 1.0) -> SpinBox:
	var label := Label.new(); label.text = caption; parent.add_child(label)
	var number := SpinBox.new(); number.min_value = low; number.max_value = high; number.step = step; number.value = value; number.custom_minimum_size.x = 80; parent.add_child(number)
	return number

func open() -> void:
	refresh(); window.popup_centered()

func cancel() -> void:
	if job != null: job.cancel()

func _root() -> Dictionary: return panel.session.data
func _hash() -> String: return Root.root_hash(kind,_root())
func _map() -> Dictionary: return Root.map_of(kind,_root())
func _selected(option: OptionButton) -> String: return str(option.get_item_metadata(option.selected)) if option.selected >= 0 else ""

func _piece() -> Dictionary:
	var map := _map()
	if map.is_empty(): return {}
	var instance := Piece._find(map.instances,"instance_id",_selected(instance_choice))
	return Piece._find(map.pieces,"piece_hash",instance.get("piece_hash","")).get("source",{}) if not instance.is_empty() else {}

## Called by the owning panel after every root change.
func refresh() -> void:
	if panel == null or panel.session == null: return
	if not pending.is_empty() and pending.base_hash != _hash():
		pending = {}; preview_canvas.visible = false
	var previous := _selected(instance_choice)
	instance_choice.clear()
	var map := _map()
	for instance: Dictionary in (map.instances if not map.is_empty() else []):
		instance_choice.add_item(instance.instance_id); instance_choice.set_item_metadata(instance_choice.item_count-1,instance.instance_id)
		if instance.instance_id == previous: instance_choice.select(instance_choice.item_count-1)
	_fill_layers()

func _fill_layers() -> void:
	var previous := _selected(layer_choice); layer_choice.clear()
	for layer: Dictionary in _piece().get("layers",[]):
		layer_choice.add_item(layer.name); layer_choice.set_item_metadata(layer_choice.item_count-1,layer.layer_id)
		if layer.layer_id == previous: layer_choice.select(layer_choice.item_count-1)
	_fill_regions()

func _fill_regions() -> void:
	var previous := _selected(region); region.clear()
	for item: Dictionary in _piece().get("regions",[]):
		if item.layer_id != _selected(layer_choice): continue
		region.add_item(item.region_id); region.set_item_metadata(region.item_count-1,item.region_id)
		if item.region_id == previous: region.select(region.item_count-1)

## The request the fields describe, on the open root.
func gui_request() -> Dictionary:
	var instance := Piece._find(_map().get("instances",[]),"instance_id",_selected(instance_choice))
	var channels := {"terrain":{"mode":"preserve"},"materials":{"mode":"preserve"},"objects":{"mode":"preserve"}}
	if terrain_mode.selected == 1: channels.terrain = {"mode":"relief","amplitude":amplitude.value,"feature_size":feature_size.value,"roughness":roughness.value,"falloff":falloff.value}
	if material_mode.selected == 1: channels.materials = {"mode":"patches","material":_selected(material_choice),"coverage":coverage.value,"feature_size":patch_size.value}
	if object_mode.selected == 1 and definition.selected >= 0: channels.objects = {"mode":"scatter","definition_id":_selected(definition),"count":int(count.value),"spacing":spacing.value,"replace":replace.button_pressed}
	if kind in ["population","patrol"]: channels["encounters"] = {"mode":"regenerate" if encounter_mode.selected == 1 else "preserve"}
	if kind == "patrol": channels["patrols"] = {"mode":"preserve"}
	return {"algorithm_revision":Piece.REVISION,"seed_text":seed_text.text.strip_edges(),"base_hash":_hash(),"target":{"instance_id":_selected(instance_choice),"piece_hash":str(instance.get("piece_hash","")),"layer_id":_selected(layer_choice)},"selection":{"region_id":_selected(region)},"channels":channels,"preserve":{"entity_ids":[],"region_ids":[]}}

func preview() -> void:
	if job != null: return
	discard()
	if region.selected < 0:
		status.text = "Escolha a posição, a camada e uma região da peça (crie regiões na tela de contexto da peça)."; return
	_job_request = gui_request()
	var checked := Root.validate_request(kind,_job_request)
	if not checked.ok: _report(checked); return
	job = Root.new(); job.start(kind,_root(),_job_request)
	status.text = "Preparando a variação e conferindo encontros e rotas…"

func _process(_delta: float) -> void:
	if job == null: return
	progress_bar.value = job.progress()*100
	if not job.ready(): return
	var outcome: Dictionary = job.take(); job = null
	progress_bar.value = 100
	if outcome.get("ok",false) and _job_request.base_hash != _hash(): outcome = Root.fail("base_diverged")
	if outcome.get("ok",false): show_proposal(outcome)
	else: _report(outcome)

func show_proposal(proposal: Dictionary) -> void:
	pending = proposal
	var diff: Dictionary = proposal.diff
	var map := Root.map_of(kind,proposal.source)
	var piece := Piece._find(map.pieces,"piece_hash",diff.piece_hash_after)
	if not piece.is_empty():
		preview_canvas.visible = true; preview_canvas.set_source(piece.source,diff.layer_id); preview_canvas.fit()
	var parts: Array[String] = []
	var piece_diff: Dictionary = diff.piece
	if not piece_diff.is_empty(): parts.append("%d amostra(s) de relevo, %d de material, %d objeto(s) novo(s), %d removido(s)" % [piece_diff.terrain_samples.size(),piece_diff.material_samples.size(),piece_diff.objects_added.size(),piece_diff.objects_removed.size()])
	if not diff.snapshots_added.is_empty(): parts.append("peça nova só para a posição "+diff.instance_id)
	if not diff.anchors_remapped.is_empty(): parts.append("%d marcador(es) religado(s) ao piso novo" % diff.anchors_remapped.size())
	if not diff.anchors_resettled.is_empty(): parts.append("%d centro(s) de área reassentado(s)" % diff.anchors_resettled.size())
	if not diff.slots_removed.is_empty() or not diff.slots_added.is_empty(): parts.append("encontros: %d redistribuído(s) dentro da região" % diff.slots_added.size())
	status.text = "Prévia: "+"; ".join(parts)+". Confira e aplique; nada mudou ainda."

func apply_pending() -> Dictionary:
	if pending.is_empty(): status.text = "Faça a prévia regional antes de aplicar."; return Root.fail("synthesis_stale_proposal")
	var proposal := pending; pending = {}
	var applied := Root.apply(proposal,panel.session,proposal.base_hash)
	if applied.ok: status.text = "Variação aplicada como uma única alteração; Desfazer volta tudo."
	else: _report(applied)
	return applied

func discard() -> void:
	if pending.is_empty(): return
	pending = {}; preview_canvas.visible = false
	status.text = "Prévia descartada; nada mudou."

func _report(outcome: Dictionary) -> void:
	var diagnostics: Array = outcome.get("diagnostics",[])
	var message: String = diagnostics[0].get("message","Variação recusada.") if not diagnostics.is_empty() else "Variação recusada: "+str(outcome.get("code",""))
	var entity: String = str(diagnostics[0].get("entity_id","")) if not diagnostics.is_empty() else ""
	status.text = message+(" ("+entity+")" if not entity.is_empty() else "")

static func summary(proposal: Dictionary) -> Dictionary:
	var result := proposal.duplicate(true); result.erase("source")
	if proposal.get("ok",false): result["proposal_hash"] = proposal.source_hash
	return result

func authoring_commands() -> Array:
	return [{"id":screen+"/synthesis/request","parameters":{}},{"id":screen+"/synthesis/preview","parameters":{"request":"regional_root_request"}},{"id":screen+"/synthesis/apply","parameters":{"proposal_hash":"sha256"}},{"id":screen+"/synthesis/discard","parameters":{}}]

func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	if id == screen+"/synthesis/request":
		if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
		return {"ok":true,"request":gui_request()}
	if id == screen+"/synthesis/preview":
		if not Preferences._keys(parameters,["request"]) or not parameters.request is Dictionary: return {"ok":false,"code":"arguments_invalid"}
		if job != null: job.close(); job = null
		discard()
		var proposal := Root.prepare(kind,_root(),parameters.request)
		if proposal.ok: show_proposal(proposal)
		else: _report(proposal)
		return summary(proposal)
	if id == screen+"/synthesis/apply":
		if not Preferences._keys(parameters,["proposal_hash"]) or not Schema._type(parameters.proposal_hash,"hash"): return {"ok":false,"code":"arguments_invalid"}
		if pending.is_empty() or parameters.proposal_hash != pending.source_hash: return Root.fail("synthesis_stale_proposal")
		return apply_pending()
	if id == screen+"/synthesis/discard":
		if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
		discard(); return {"ok":true,"output_hash":_hash()}
	return {"ok":false,"code":"action_missing"}

func _exit_tree() -> void:
	if job != null: job.close(); job = null
