@tool
extends RefCounted
## Checkpoint49 (F9-06/07, P6a): the guided authoring flow shared by the terrain,
## map, encounter and patrol screens. It reads each screen's own session, compile
## result and job (never a copy of its state), says what each step needs and runs
## the next step through the screen's own producers: compile, open the next
## screen, start a map with the open piece, carry a changed document forward
## (carry_forward.gd, in the background, applied only after confirmation as one
## undoable change), prepare/apply the encounter plan, test. A failure keeps its
## diagnostic with the step that owns it; show() opens that screen and focuses the
## entity through the screen's own diagnostics list.
signal changed
const Carry = preload("res://scripts/map_authoring/workflow/carry_forward.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const ORDER := ["piece","map","population","patrol","test"]
const TITLES := {"piece":"Peça","map":"Mapa","population":"Encontros","patrol":"Patrulhas","test":"Teste"}
const STATES := {"ready":"pronta","todo":"a fazer","stale":"desatualizada","busy":"em andamento","blocked":"com problema","waiting":"aguarda a anterior","absent":"não aberta","optional":"opcional","review":"a revisar"}
const LABELS := {"compile_piece":"Compilar a peça","open_map":"Abrir a composição do mapa","start_map":"Começar o mapa com a peça aberta","carry_piece":"Levar a peça atual ao mapa","compile_map":"Compilar o mapa","open_population":"Levar o mapa aos encontros","import_map":"Levar o mapa aos encontros","carry_map":"Atualizar o mapa nos encontros","mark_population":"Marcar a entrada e pintar encontros","prepare_plan":"Preparar o plano dos encontros","apply_plan":"Aplicar a prévia do plano…","compile_population":"Compilar os encontros","open_patrols":"Levar os encontros às patrulhas","import_population":"Levar os encontros às patrulhas","carry_population":"Atualizar os encontros nas patrulhas","compile_patrols":"Validar as patrulhas","test":"Testar no jogo","confirm_carry":"Revisar e aplicar a atualização…"}
const CARRIES := {"carry_piece":"map","carry_map":"population","carry_population":"patrol"}
var _panels: Dictionary = {}
var _hashes: Dictionary = {}
var job: Thread
var job_action := ""
var _cancel := false
var pending: Dictionary = {}
var failure: Dictionary = {}
var last_action := ""

func attach(kind: String, panel: Control) -> void:
	_panels[kind] = weakref(panel)
	var session: Object = panel.get("session")
	if session != null and session.has_signal("changed") and not session.changed.is_connected(_session_changed.bind(kind)):
		session.changed.connect(_session_changed.bind(kind))
	changed.emit()

func _session_changed(kind: String) -> void:
	_hashes.erase(kind); _hashes.erase(kind+":upstream"); _hashes.erase(kind+":planned")
	if not pending.is_empty() and pending.get("kind","") == kind: pending = {}
	if failure.get("step","") == kind: failure = {}
	changed.emit()

func panel(kind: String) -> Control:
	var reference: WeakRef = _panels.get(kind)
	var value: Variant = reference.get_ref() if reference != null else null
	return value if is_instance_valid(value) else null

func data(kind: String) -> Dictionary:
	var owner := panel(kind)
	if owner == null: return {}
	if kind == "piece": return owner.session.document().to_data() if owner.session.document() != null else {}
	return owner.session.data

## Hash of a step's current source, recomputed only after its session changed.
func current_hash(kind: String) -> String:
	if not _hashes.has(kind):
		var value := data(kind)
		if value.is_empty(): return ""
		_hashes[kind] = Schema.semantic_hash(value) if kind == "piece" else Carry.root_hash(kind,value)
	return _hashes[kind]

func _compiled(kind: String) -> Dictionary:
	var owner := panel(kind)
	if owner == null: return {}
	var holder: Object = owner.terrain if kind == "piece" else owner
	return holder.get("result") if holder.get("result") is Dictionary else {}

func _busy(kind: String) -> bool:
	var owner := panel(kind)
	if owner == null: return false
	var holder: Object = owner.terrain if kind == "piece" else owner
	return holder.get("job") != null or (job != null and CARRIES.get(job_action,"") == kind)

func _step(id: String, state: String, action: String, detail: String, diagnostic: Dictionary = {}) -> Dictionary:
	return {"id":id,"title":TITLES[id],"state":state,"state_label":STATES[state],"action":action,"action_label":LABELS.get(action,""),"detail":detail,"diagnostic":diagnostic}

const COMPILES := {"piece":"compile_piece","map":"compile_map","population":"compile_population","patrol":"compile_patrols"}
func _failed(kind: String) -> Dictionary:
	if failure.get("step","") == kind and not failure.get("diagnostics",[]).is_empty(): return failure.diagnostics[0]
	var compiled := _compiled(kind)
	if not compiled.is_empty() and not compiled.get("ok",true):
		var diagnostics: Array = compiled.get("diagnostics",[])
		return diagnostics[0] if not diagnostics.is_empty() else {"code":compiled.get("code",""),"entity_id":"","message":"A compilação falhou: "+str(compiled.get("code",""))}
	return {}

## The open piece is in the map with another revision.
func piece_is_stale() -> bool:
	var piece := data("piece"); var map := data("map")
	if piece.is_empty() or map.is_empty(): return false
	var current := current_hash("piece")
	for snapshot: Dictionary in map.pieces:
		if snapshot.source.get("document_id","") == piece.get("document_id","") and snapshot.piece_hash != current: return true
	return false

## Hash of the upstream snapshot a step carries (cached like current_hash).
func _snapshot_hash(kind: String) -> String:
	var key := kind+":upstream"
	if not _hashes.has(key):
		var value := data(kind)
		if kind == "population" and not value.get("map",[]).is_empty(): _hashes[key] = MapDocument.hash_source(value.map[0])
		elif kind == "patrol" and not value.get("population",[]).is_empty(): _hashes[key] = PopulationDocument.hash_source(value.population[0])
		else: return ""
	return _hashes[key]

## Whether the encounter plan was drawn for the current recipe (cached).
func planned() -> bool:
	if not _hashes.has("population:planned"):
		var population := data("population")
		_hashes["population:planned"] = not population.is_empty() and population.plan_hash == PopulationDocument.recipe_hash(population)
	return _hashes["population:planned"]

## A step with a failure retries the carry that failed there, or compiles.
func _retry(kind: String) -> String:
	return last_action if CARRIES.get(last_action,"") == kind else COMPILES.get(kind,"")

func _pending_step(kind: String) -> Dictionary:
	return _step(kind,"review","confirm_carry",Carry.summary(pending)) if pending.get("kind","") == kind else {}

func steps() -> Array:
	var result: Array = []
	# 1. Piece: compiling it is optional; a failed compile is a problem to show.
	if panel("piece") == null: result.append(_step("piece","absent","","Abra a peça na tela Mapas do editor."))
	else:
		var problem := _failed("piece")
		if _busy("piece"): result.append(_step("piece","busy","","Compilando a peça…"))
		elif not problem.is_empty(): result.append(_step("piece","blocked","compile_piece",problem.get("message",""),problem))
		elif _compiled("piece").get("ok",false): result.append(_step("piece","ready","","Terreno, encaixes e objetos validados."))
		else: result.append(_step("piece","optional","compile_piece","Compile para conferir a peça antes de usá-la."))
	# 2. Map.
	var map_ready := false
	if panel("map") == null: result.append(_step("map","absent","open_map","Monte o mapa com as peças na composição."))
	else:
		var map := data("map"); var problem := _failed("map")
		if _busy("map"): result.append(_step("map","busy","","Compilando ou atualizando o mapa…"))
		elif not _pending_step("map").is_empty(): result.append(_pending_step("map"))
		elif failure.get("step","") == "map": result.append(_step("map","blocked",_retry("map"),problem.get("message",""),problem))
		elif map.instances.is_empty(): result.append(_step("map","todo","start_map" if not data("piece").is_empty() else "","O mapa está vazio; adicione peças na composição."))
		elif piece_is_stale(): result.append(_step("map","stale","carry_piece","A peça aberta mudou depois de entrar no mapa."))
		elif not problem.is_empty(): result.append(_step("map","blocked","compile_map",problem.get("message",""),problem))
		elif _compiled("map").get("ok",false): result.append(_step("map","ready","","%d peça(s) com emendas validadas." % map.instances.size())); map_ready = true
		else: result.append(_step("map","todo","compile_map","Compile para validar emendas e rotas."))
	# 3. Encounters.
	var population_ready := false
	if not map_ready: result.append(_step("population","waiting","","Primeiro deixe o mapa pronto."))
	elif panel("population") == null: result.append(_step("population","absent","open_population","Os encontros recebem o mapa compilado."))
	else:
		var population := data("population"); var owner := panel("population"); var problem := _failed("population")
		if _busy("population"): result.append(_step("population","busy","","Preparando ou validando os encontros…"))
		elif not _pending_step("population").is_empty(): result.append(_pending_step("population"))
		elif failure.get("step","") == "population": result.append(_step("population","blocked",_retry("population"),problem.get("message",""),problem))
		elif population.map.is_empty(): result.append(_step("population","todo","import_map","Os encontros ainda não têm mapa."))
		elif _snapshot_hash("population") != current_hash("map"): result.append(_step("population","stale","carry_map","O mapa mudou depois de entrar nos encontros."))
		elif population.entrance.is_empty() or (population.brushes.is_empty() and population.slots.is_empty()): result.append(_step("population","todo","mark_population","Marque a entrada e pinte ao menos um encontro."))
		elif not problem.is_empty(): result.append(_step("population","blocked","compile_population" if planned() else "prepare_plan",problem.get("message",""),problem))
		elif not planned(): result.append(_step("population","todo","apply_plan" if owner.proposal.get("ok",false) else "prepare_plan","O plano ainda não foi sorteado para a receita atual."))
		elif _compiled("population").get("ok",false): result.append(_step("population","ready","","%d slot(s) validados." % population.slots.size())); population_ready = true
		else: result.append(_step("population","todo","compile_population","Compile para validar corpos e rotas."))
	# 4. Patrols.
	var patrol_ready := false
	if not population_ready: result.append(_step("patrol","waiting","","Primeiro deixe os encontros prontos."))
	elif panel("patrol") == null: result.append(_step("patrol","absent","open_patrols","As patrulhas recebem os encontros compilados."))
	else:
		var patrol := data("patrol"); var problem := _failed("patrol")
		if _busy("patrol"): result.append(_step("patrol","busy","","Validando ou atualizando as patrulhas…"))
		elif not _pending_step("patrol").is_empty(): result.append(_pending_step("patrol"))
		elif failure.get("step","") == "patrol": result.append(_step("patrol","blocked",_retry("patrol"),problem.get("message",""),problem))
		elif patrol.population.is_empty(): result.append(_step("patrol","todo","import_population","As patrulhas ainda não têm encontros."))
		elif _snapshot_hash("patrol") != current_hash("population"): result.append(_step("patrol","stale","carry_population","Os encontros mudaram depois de entrar nas patrulhas."))
		elif not problem.is_empty(): result.append(_step("patrol","blocked","compile_patrols",problem.get("message",""),problem))
		elif _compiled("patrol").get("ok",false): result.append(_step("patrol","ready","","%d rota(s) validadas." % patrol.patrols.size())); patrol_ready = true
		else: result.append(_step("patrol","todo","compile_patrols","Valide corpo, limite de retorno e trechos."))
	# 5. Test.
	if not patrol_ready: result.append(_step("test","waiting","","Primeiro valide as patrulhas."))
	else: result.append(_step("test","todo","test","Abre o jogo real com o pacote validado, perfil descartável."))
	return result

func next_step() -> Dictionary:
	for step: Dictionary in steps():
		if step.state in ["ready","optional","waiting"] or step.action.is_empty(): continue
		return step
	return {}

func screen_of(kind: String) -> String: return "patrol" if kind == "test" else kind

## Opens (or brings forward) the screen of a step.
func open(kind: String) -> Dictionary:
	match screen_of(kind):
		"piece": return {"ok":panel("piece") != null}
		"map":
			if panel("map") != null: _popup(panel("map")); return {"ok":true}
			if panel("piece") == null: return {"ok":false,"code":"flow_screen_missing"}
			panel("piece").open_composition(); return {"ok":panel("map") != null}
		"population":
			if panel("population") != null: _popup(panel("population")); return {"ok":true}
			if panel("map") == null: return {"ok":false,"code":"flow_screen_missing"}
			panel("map").open_population(); return {"ok":panel("population") != null}
		"patrol":
			if panel("patrol") != null: _popup(panel("patrol")); return {"ok":true}
			if panel("population") == null: return {"ok":false,"code":"flow_screen_missing"}
			panel("population").open_patrols(); return {"ok":panel("patrol") != null}
	return {"ok":false,"code":"flow_step_invalid"}

static func _popup(owner: Control) -> void:
	var window := owner.get_parent() as Window
	if window != null and not window.visible: window.popup_centered()
	elif window != null: window.grab_focus()

func run(action: String) -> Dictionary:
	if job != null: return {"ok":false,"code":"flow_busy"}
	var step := next_step()
	if step.is_empty() or step.action != action: return {"ok":false,"code":"flow_action_unavailable"}
	if action == "confirm_carry":
		open(pending.kind)
		return {"ok":true,"action":action,"confirmation_required":true,"proposal_hash":pending.source_hash,"kind":pending.kind,"summary":Carry.summary(pending),"diff":pending.diff.duplicate(true)}
	failure = {}; pending = {}; last_action = action
	var result: Dictionary = {"ok":true,"action":action}
	match action:
		"compile_piece": panel("piece").terrain.bake()
		"open_map": result = open("map")
		"start_map":
			var piece := data("piece")
			result = panel("map").apply_operation("instance/add",{"instance_id":String(piece.document_id),"position_xz":[0,0],"rotation_quarters":0},piece)
		"compile_map": panel("map").bake()
		"open_population": result = open("population")
		"import_map":
			open("population"); result = panel("population").import_map(data("map"))
		"mark_population": result = open("population")
		"prepare_plan": open("population"); result = panel("population").prepare_plan()
		"apply_plan": open("population"); panel("population").request_apply()
		"compile_population": open("population"); result = panel("population").bake()
		"open_patrols": result = open("patrol")
		"import_population":
			open("patrol"); result = panel("patrol").import_population(data("population"),panel("patrol").session.data.patrols.is_empty())
		"compile_patrols": open("patrol"); result = panel("patrol").bake()
		"test": open("patrol"); result = panel("patrol").gameplay_tools.toggle()
		"carry_piece", "carry_map", "carry_population": result = _start_carry(action)
		_: return {"ok":false,"code":"flow_action_unavailable"}
	if result is Dictionary and not result.get("ok",true) and result.has("diagnostics"): failure = result.duplicate(true); failure["step"] = step.id
	changed.emit()
	if not result is Dictionary: result = {"ok":true}
	result["action"] = action
	return result

func _start_carry(action: String) -> Dictionary:
	var target: String = CARRIES[action]
	var source_kind: String = {"map":"piece","population":"map","patrol":"population"}[target]
	var root := data(target).duplicate(true); var upstream := data(source_kind).duplicate(true)
	_cancel = false; job_action = action; job = Thread.new()
	var stop := func() -> bool: return _cancel
	match target:
		"map": job.start(func() -> Dictionary: return Carry.piece_into_map(root,upstream,stop))
		"population": job.start(func() -> Dictionary: return Carry.map_into_population(root,upstream,stop))
		"patrol": job.start(func() -> Dictionary: return Carry.population_into_patrol(root,upstream,stop))
	return {"ok":true,"pending":true}

func cancel() -> void: _cancel = true

## Called every frame by the bars: collects a finished carry.
func poll() -> bool:
	if job == null or job.is_alive(): return false
	var outcome: Dictionary = job.wait_to_finish(); job = null
	var target: String = CARRIES.get(job_action,""); job_action = ""
	if outcome.get("ok",false) and outcome.base_hash == current_hash(target): pending = outcome
	elif outcome.get("ok",false): failure = Carry.fail("flow_stale_proposal","",target)
	else:
		failure = outcome.duplicate(true)
		if not failure.has("step") or String(failure.step).is_empty(): failure["step"] = target
	changed.emit()
	return true

## Commits the pending proposal on its screen as one undoable change.
func apply_pending(proposal_hash: String) -> Dictionary:
	if pending.is_empty() or proposal_hash != pending.source_hash: return Carry.fail("flow_stale_proposal","",pending.get("kind",""))
	var kind: String = pending.kind
	var applied := Carry.apply(pending,panel(kind).session,data(kind))
	pending = {}
	if not applied.ok: failure = applied.duplicate(true); failure["step"] = kind
	else: open(kind)
	changed.emit()
	return applied

func discard_pending() -> void:
	pending = {}; changed.emit()

## Opens the screen that owns the diagnostic and focuses its entity there.
func show(diagnostic: Dictionary) -> Dictionary:
	var kind: String = diagnostic.get("step","")
	if kind.is_empty() or panel(screen_of(kind)) == null: return {"ok":false,"code":"flow_screen_missing"}
	open(kind)
	var list: ItemList = panel(screen_of(kind)).problems
	var index := -1
	for i: int in list.item_count:
		var item: Variant = list.get_item_metadata(i)
		if item is Dictionary and item.get("entity_id","") == diagnostic.get("entity_id","") and item.get("code","") == diagnostic.get("code",""): index = i
	if index < 0:
		list.add_item(String(diagnostic.get("message",""))); index = list.item_count-1
		list.set_item_metadata(index,diagnostic.duplicate(true))
	list.select(index); list.item_selected.emit(index)
	return {"ok":true,"step":kind,"entity_id":diagnostic.get("entity_id","")}

## The diagnostic the flow shows for a step: its own failure or the screen's.
func blocking(kind: String) -> Dictionary:
	var diagnostic := _failed(kind)
	if not diagnostic.is_empty() and not diagnostic.has("step"):
		diagnostic = diagnostic.duplicate(true); diagnostic["step"] = kind
	return diagnostic

func close() -> void:
	if job != null: _cancel = true; job.wait_to_finish(); job = null
