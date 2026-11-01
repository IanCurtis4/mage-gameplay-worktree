@tool
extends VBoxContainer
## Checkpoint43 (F9-05/07, P3a): "Variação regional" on the terrain screen. The
## fields build the passive request of RegionalSynthesis; "Prévia regional" runs
## prepare() in the background and shows the proposal on the canvas; "Aplicar
## variação" commits it as one undoable change. AX calls the same service
## synchronously (terrain/synthesis/*); the CLI is synthesis/headless.gd.
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Preferences = preload("res://scripts/map_authoring/library/editor_preferences.gd")
const MATERIALS := {"earth":"Terra","grass":"Grama","sand":"Areia","stone":"Pedra"}
var panel: Control
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
var job: RefCounted
var _job_request: Dictionary = {}
var pending: Dictionary = {}

func setup(owner_panel: Control) -> void:
	panel = owner_panel; name = "RegionalSynthesis"
	set_meta("authoring_command_provider",true)
	var intro := Label.new(); intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.text = "Gera uma variação só dentro de uma região da camada. Regiões protegidas, conexões, objetos travados e tudo que cruza a borda ficam como estão. Cada canal diz se preserva ou o que gerar."
	add_child(intro)
	var where := HFlowContainer.new(); add_child(where)
	var region_label := Label.new(); region_label.text = "Região"; where.add_child(region_label)
	region = OptionButton.new(); region.custom_minimum_size.x = 180; where.add_child(region)
	var seed_label := Label.new(); seed_label.text = "Seed"; where.add_child(seed_label)
	seed_text = LineEdit.new(); seed_text.text = "1"; seed_text.custom_minimum_size.x = 120; where.add_child(seed_text)
	var relief := HFlowContainer.new(); add_child(relief)
	terrain_mode = _choice(relief,"Relevo",["Preservar","Gerar relevo"])
	amplitude = panel._number(relief,"Amplitude",0,512,32)
	feature_size = panel._number(relief,"Tamanho",8,4096,256)
	roughness = panel._number(relief,"Aspereza",0,1,0.5,0.05)
	falloff = panel._number(relief,"Transição",0,4096,96)
	var paint := HFlowContainer.new(); add_child(paint)
	material_mode = _choice(paint,"Materiais",["Preservar","Gerar manchas"])
	material_choice = OptionButton.new()
	for id: String in MATERIALS: material_choice.add_item(MATERIALS[id]); material_choice.set_item_metadata(material_choice.item_count-1,id)
	paint.add_child(material_choice)
	coverage = panel._number(paint,"Cobertura",0,1,0.4,0.05)
	patch_size = panel._number(paint,"Tamanho",8,4096,192)
	var scatter := HFlowContainer.new(); add_child(scatter)
	object_mode = _choice(scatter,"Objetos",["Preservar","Espalhar"])
	definition = OptionButton.new(); scatter.add_child(definition)
	var catalog := Catalog.load_catalog()
	if catalog.ok:
		for id: String in catalog.definitions: definition.add_item(String(catalog.definitions[id].get("name",id))); definition.set_item_metadata(definition.item_count-1,id)
	count = panel._number(scatter,"Quantidade",0,1024,6)
	spacing = panel._number(scatter,"Folga",0,8192,16)
	replace = CheckBox.new(); replace.text = "Substituir os soltos dentro"; scatter.add_child(replace)
	var actions := HFlowContainer.new(); add_child(actions)
	for entry: Array in [["Prévia regional",preview],["Aplicar variação",apply_pending],["Descartar prévia",discard],["Cancelar variação",cancel]]:
		panel._button(actions,entry[0],entry[1]).set_meta("authoring_keep_visible",true)

func cancel() -> void:
	if job != null: job.cancel()

func _choice(parent: Node, caption: String, items: Array) -> OptionButton:
	var label := Label.new(); label.text = caption; parent.add_child(label)
	var option := OptionButton.new()
	for item: String in items: option.add_item(item)
	parent.add_child(option)
	return option

func _source() -> Dictionary: return panel.session.document().to_data()
func _hash() -> String: return panel.session.document().semantic_hash()

## Called by the terrain panel after every source change and layer switch.
func refresh() -> void:
	if panel == null or panel.session == null or panel.session.document() == null: return
	var previous := str(region.get_item_metadata(region.selected)) if region.selected >= 0 else ""
	region.clear()
	for item: Dictionary in _source().regions:
		if item.layer_id != panel.selected_layer: continue
		region.add_item(item.region_id); region.set_item_metadata(region.item_count-1,item.region_id)
		if item.region_id == previous: region.select(region.item_count-1)
	# The canvas now shows the open source again, so a preview is no longer on screen.
	pending = {}

## The request the fields describe, on the open source and selected layer.
func gui_request() -> Dictionary:
	var terrain := {"mode":"preserve"}
	if terrain_mode.selected == 1: terrain = {"mode":"relief","amplitude":amplitude.value,"feature_size":feature_size.value,"roughness":roughness.value,"falloff":falloff.value}
	var materials := {"mode":"preserve"}
	if material_mode.selected == 1: materials = {"mode":"patches","material":str(material_choice.get_item_metadata(material_choice.selected)),"coverage":coverage.value,"feature_size":patch_size.value}
	var objects := {"mode":"preserve"}
	if object_mode.selected == 1 and definition.selected >= 0: objects = {"mode":"scatter","definition_id":str(definition.get_item_metadata(definition.selected)),"count":int(count.value),"spacing":spacing.value,"replace":replace.button_pressed}
	var region_id := str(region.get_item_metadata(region.selected)) if region.selected >= 0 else ""
	return {"algorithm_revision":Synthesis.REVISION,"seed_text":seed_text.text.strip_edges(),"base_hash":_hash(),"target":{"layer_id":panel.selected_layer},"selection":{"region_id":region_id},"channels":{"terrain":terrain,"materials":materials,"objects":objects},"preserve":{"entity_ids":[],"region_ids":[]}}

func preview() -> void:
	if job != null: return
	discard()
	if region.selected < 0:
		panel.status.text = "Crie uma região nesta camada (tela de contexto) para gerar uma variação dentro dela."; return
	_job_request = gui_request()
	var checked := Synthesis.validate_request(_job_request)
	if not checked.ok: _report(checked); return
	job = Synthesis.new(); job.start(_source(),_job_request)
	panel.status.text = "Preparando a variação regional…"

## Polled by the terrain panel every frame.
func poll() -> void:
	if job == null: return
	panel.progress_bar.value = job.progress()*100
	if not job.ready(): return
	var outcome: Dictionary = job.take(); job = null
	panel.progress_bar.value = 100
	if outcome.get("ok",false) and _job_request.base_hash != _hash(): outcome = Synthesis.fail("base_diverged")
	if outcome.get("ok",false): show_proposal(outcome)
	else: _report(outcome)

func show_proposal(proposal: Dictionary) -> void:
	pending = proposal
	panel.canvas.set_source(proposal.source,panel.selected_layer)
	var diff: Dictionary = proposal.diff
	panel.status.text = "Prévia: %d amostra(s) de relevo, %d de material, %d objeto(s) novo(s), %d removido(s). Confira no quadro e aplique; nada mudou ainda." % [diff.terrain_samples.size(),diff.material_samples.size(),diff.objects_added.size(),diff.objects_removed.size()]

func apply_pending() -> Dictionary:
	if pending.is_empty(): panel.status.text = "Faça a prévia regional antes de aplicar."; return Synthesis.fail("synthesis_stale_proposal")
	var proposal := pending; pending = {}
	var applied := Synthesis.apply(proposal,panel.session,proposal.base_hash)
	if applied.ok: panel.status.text = "Variação aplicada como uma única alteração; Desfazer volta tudo."
	else: _report(applied); panel.refresh()
	return applied

func discard() -> void:
	if pending.is_empty(): return
	pending = {}
	panel.canvas.set_source(_source(),panel.selected_layer)
	panel.status.text = "Prévia descartada; a peça não mudou."

func _report(outcome: Dictionary) -> void:
	var diagnostics: Array = outcome.get("diagnostics",[])
	panel.status.text = diagnostics[0].get("message","Variação recusada.") if not diagnostics.is_empty() else "Variação recusada: "+str(outcome.get("code",""))

static func summary(proposal: Dictionary) -> Dictionary:
	var result := proposal.duplicate(true); result.erase("source"); result.erase("package")
	if proposal.get("ok",false): result["proposal_hash"] = proposal.source_hash
	return result

func authoring_commands() -> Array:
	return [{"id":"terrain/synthesis/request","parameters":{}},{"id":"terrain/synthesis/preview","parameters":{"request":"regional_request"}},{"id":"terrain/synthesis/apply","parameters":{"proposal_hash":"sha256"}},{"id":"terrain/synthesis/discard","parameters":{}}]

func ax_command(id: String, parameters: Dictionary) -> Dictionary:
	if id == "terrain/synthesis/request":
		if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
		return {"ok":true,"request":gui_request()}
	if id == "terrain/synthesis/preview":
		if not Preferences._keys(parameters,["request"]) or not parameters.request is Dictionary: return {"ok":false,"code":"arguments_invalid"}
		if job != null: job.close(); job = null
		discard()
		var proposal := Synthesis.prepare(_source(),parameters.request)
		if proposal.ok: show_proposal(proposal)
		else: _report(proposal)
		return summary(proposal)
	if id == "terrain/synthesis/apply":
		if not Preferences._keys(parameters,["proposal_hash"]) or not Schema._type(parameters.proposal_hash,"hash"): return {"ok":false,"code":"arguments_invalid"}
		if pending.is_empty(): return Synthesis.fail("synthesis_stale_proposal")
		if parameters.proposal_hash != pending.source_hash: return Synthesis.fail("synthesis_stale_proposal")
		return apply_pending()
	if id == "terrain/synthesis/discard":
		if not parameters.is_empty(): return {"ok":false,"code":"arguments_invalid"}
		discard(); return {"ok":true,"output_hash":_hash()}
	return {"ok":false,"code":"action_missing"}

func _exit_tree() -> void:
	if job != null: job.close(); job = null
