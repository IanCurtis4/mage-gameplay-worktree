@tool
extends RefCounted
## Checkpoint49 (F9-06/07/08, P6a): carrying a document forward along the
## authoring flow (piece → map → encounters → patrols) without losing authorship.
## Each function builds a proposal on a copy and never touches a session:
## - piece_into_map: every snapshot of the open piece's document is replaced by
##   the open piece; the instances that used it follow; the map is compiled.
## - map_into_population: the encounters get the current map; every authored
##   anchor (entrance, brushes, exclusions, interactions, slots) follows its
##   instance (moved or rotated) and its layer family, settling on the new ground;
##   a realized plan is re-certified keeping every slot and drawing none.
## - population_into_patrol: the patrols get the current encounters; waypoints
##   follow their instance the same way; routes keep their slots.
## A missing instance or layer, a lost support or a slot that no longer exists is
## a diagnostic that names the entity and the screen that owns it. apply() commits
## a proposal as one undoable change after checking the target did not move.
const Root = preload("res://scripts/map_authoring/synthesis/root_synthesis.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const REVISION := "map_flow_carry_v1"
const KEEP_LIMIT := 128
const STEPS := {"map":"map","population":"population","patrol":"patrol"}

static func fail(code: String, entity: String = "", step: String = "", field: String = "flow") -> Dictionary:
	var messages := {"flow_up_to_date":"Esta etapa já usa a versão atual da anterior.","flow_piece_not_in_map":"A peça aberta não está neste mapa; adicione-a na composição.","flow_no_map":"Os encontros ainda não têm mapa; leve o mapa aos encontros.","flow_no_population":"As patrulhas ainda não têm encontros; leve os encontros às patrulhas.","flow_instance_missing":"A peça deste marcador saiu do mapa; mova o marcador ou devolva a peça.","flow_support_lost":"Este marcador ficou sem chão na versão atual do mapa; mova-o para um apoio.","flow_slot_missing":"A rota usa um slot que não existe mais nos encontros; vincule outro slot.","flow_plan_too_large":"O plano tem slots demais para ser reconferido de uma vez; prepare a prévia nos encontros.","flow_stale_proposal":"A etapa mudou depois da proposta; prepare de novo.","flow_invalid":"O documento desta etapa está inválido.","cancelled":"Operação cancelada."}
	return {"ok":false,"code":code,"step":step,"diagnostics":[{"code":code,"severity":"error","entity_id":entity,"field":field,"step":step,"message":messages.get(code,"Não foi possível levar a etapa adiante: "+code)}]}

## Compiler failures keep their diagnostics and learn which screen owns them.
static func _owned(result: Dictionary, step: String) -> Dictionary:
	var copy := result.duplicate(true); copy["step"] = step
	var diagnostics: Array = copy.get("diagnostics",[])
	if diagnostics.is_empty(): diagnostics.append({"code":copy.get("code","failed"),"severity":"error","entity_id":"","field":"flow","message":"A compilação desta etapa falhou: "+str(copy.get("code","failed"))})
	for diagnostic: Dictionary in diagnostics: diagnostic["step"] = step
	copy.diagnostics = diagnostics
	return copy

static func _instance(map: Dictionary, id: String) -> Dictionary:
	for instance: Dictionary in map.instances:
		if instance.instance_id == id: return instance
	return {}

## Moves every anchor with its instance and family from the old map to the new
## one. family = "<instance>/layer/<id>" or "<instance>/special/<id>".
static func _rebind(anchors: Array, old_map: Dictionary, new_map: Dictionary, base: Dictionary, after: Dictionary, step: String) -> Dictionary:
	var moved: Array[String] = []; var settled: Array[String] = []
	for anchor: Dictionary in anchors:
		var family: String = base.families.get(anchor.ref.surface_id,"")
		if family.is_empty(): return fail("flow_support_lost",anchor.id,step,anchor.kind)
		var instance_id := family.get_slice("/",0)
		var before := _instance(old_map,instance_id); var now := _instance(new_map,instance_id)
		if before.is_empty() or now.is_empty(): return fail("flow_instance_missing",anchor.id,step,anchor.kind)
		var world := Root.vector(anchor.ref[anchor.field])
		var target := Root.to_world(now,Root.to_local(before,world))
		var found := Root.locate(after,family,Vector2(target.x,target.z))
		if not found.ok: return fail("flow_support_lost",anchor.id,step,anchor.kind)
		var placed := [target.x,float(found.y),target.z]
		if not Vector3(placed[0],placed[1],placed[2]).is_equal_approx(world) or found.surface_id != anchor.ref.surface_id:
			if Vector2(target.x,target.z).is_equal_approx(Vector2(world.x,world.z)): settled.append(anchor.id)
			else: moved.append(anchor.id)
		anchor.ref[anchor.field] = placed; anchor.ref.surface_id = found.surface_id
	moved.sort(); settled.sort()
	return {"ok":true,"moved":moved,"settled":settled}

static func piece_into_map(map: Dictionary, piece: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	if not MapDocument.validate(map).ok: return fail("flow_invalid","","map")
	var piece_hash := Schema.semantic_hash(piece)
	var targets: Array[String] = []; var current := false
	for snapshot: Dictionary in map.pieces:
		if snapshot.source.get("document_id","") != piece.get("document_id","x"): continue
		if snapshot.piece_hash == piece_hash: current = true
		else: targets.append(snapshot.piece_hash)
	if targets.is_empty(): return fail("flow_up_to_date" if current else "flow_piece_not_in_map","","map")
	var data: Dictionary = map.duplicate(true)
	data.pieces = data.pieces.filter(func(entry: Dictionary) -> bool: return entry.piece_hash not in targets)
	if not current: data.pieces.append({"piece_hash":piece_hash,"source":piece.duplicate(true)})
	var instances: Array[String] = []
	for instance: Dictionary in data.instances:
		if instance.piece_hash in targets: instance.piece_hash = piece_hash; instances.append(instance.instance_id)
	instances.sort()
	if cancel.is_valid() and cancel.call(): return fail("cancelled","","map")
	var built := MapCompiler.compile(data)
	if not built.ok: return _owned(built,"map")
	return {"ok":true,"code":"","kind":"map","revision":REVISION,"base_hash":MapDocument.hash_source(map),"source":data,"source_hash":MapDocument.hash_source(data),"compiled_hash":built.output_hash,"diff":{"piece_hash":piece_hash,"snapshots_replaced":targets,"instances":instances,"anchors_moved":[],"anchors_settled":[],"slots_kept":0},"diagnostics":[]}

static func map_into_population(population: Dictionary, map: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	if not PopulationDocument.validate(population).ok or not MapDocument.validate(map).ok: return fail("flow_invalid","","population")
	if population.map.is_empty(): return fail("flow_no_map","","population")
	var old_map: Dictionary = population.map[0]
	if MapDocument.hash_source(old_map) == MapDocument.hash_source(map): return fail("flow_up_to_date","","population")
	var planned: bool = population.plan_hash == PopulationDocument.recipe_hash(population)
	var halt := func() -> bool: return cancel.is_valid() and cancel.call()
	var base := Root.index(old_map)
	if not base.ok: return _owned(base,"map")
	if halt.call(): return fail("cancelled","","population")
	var after := Root.index(map)
	if not after.ok: return _owned(after,"map")
	var data: Dictionary = population.duplicate(true); data.map = [map.duplicate(true)]
	var rebound := _rebind(Root.anchors("population",data),old_map,map,base,after,"population")
	if not rebound.ok: return rebound
	var kept: Array = []; var compiled_hash := ""
	for slot: Dictionary in data.slots:
		if not slot.fixed: kept.append(slot.slot_id)
	if planned:
		if kept.size() > KEEP_LIMIT: return fail("flow_plan_too_large","","population")
		# Every slot stays where it is and is re-certified on the new map; nothing is drawn.
		var redrawn := Population.regenerate(data,halt,{"keep":kept,"redraw":false})
		if not redrawn.ok: return _owned(redrawn,"population")
		data.slots = redrawn.data.slots; data.plan_hash = redrawn.data.plan_hash
		var compiled := Population.compile(data,halt)
		if not compiled.ok: return _owned(compiled,"population")
		compiled_hash = compiled.output_hash
	return {"ok":true,"code":"","kind":"population","revision":REVISION,"base_hash":PopulationDocument.hash_source(population),"source":data,"source_hash":PopulationDocument.hash_source(data),"compiled_hash":compiled_hash,"diff":{"map_hash_before":MapDocument.hash_source(old_map),"map_hash_after":MapDocument.hash_source(map),"anchors_moved":rebound.moved,"anchors_settled":rebound.settled,"slots_kept":data.slots.size(),"plan_recertified":planned},"diagnostics":[]}

static func population_into_patrol(patrol: Dictionary, population: Dictionary, cancel: Callable = Callable()) -> Dictionary:
	if not PatrolDocument.validate(patrol).ok or not PopulationDocument.validate(population).ok: return fail("flow_invalid","","patrol")
	if patrol.population.is_empty(): return fail("flow_no_population","","patrol")
	var old_population: Dictionary = patrol.population[0]
	if PopulationDocument.hash_source(old_population) == PopulationDocument.hash_source(population): return fail("flow_up_to_date","","patrol")
	var halt := func() -> bool: return cancel.is_valid() and cancel.call()
	var slots := {}
	for slot: Dictionary in population.slots: slots[slot.slot_id] = true
	for route: Dictionary in patrol.patrols:
		for id: String in route.slot_ids:
			if not slots.has(id): return fail("flow_slot_missing",route.patrol_id,"patrol","slot_ids")
	var data: Dictionary = patrol.duplicate(true); data.population = [population.duplicate(true)]
	var moved: Array = []; var settled: Array = []
	var old_map: Dictionary = old_population.map[0] if not old_population.map.is_empty() else {}
	var new_map: Dictionary = population.map[0] if not population.map.is_empty() else {}
	if not old_map.is_empty() and not new_map.is_empty() and MapDocument.hash_source(old_map) != MapDocument.hash_source(new_map):
		var base := Root.index(old_map)
		if not base.ok: return _owned(base,"map")
		if halt.call(): return fail("cancelled","","patrol")
		var after := Root.index(new_map)
		if not after.ok: return _owned(after,"map")
		var waypoints: Array = Root.anchors("patrol",data).filter(func(anchor: Dictionary) -> bool: return anchor.kind == "waypoint")
		var rebound := _rebind(waypoints,old_map,new_map,base,after,"patrol")
		if not rebound.ok: return rebound
		moved = rebound.moved; settled = rebound.settled
	var compiled := PatrolCompiler.compile(data,halt)
	if not compiled.ok: return _owned(compiled,"patrol")
	return {"ok":true,"code":"","kind":"patrol","revision":REVISION,"base_hash":PatrolDocument.hash_source(patrol),"source":data,"source_hash":PatrolDocument.hash_source(data),"compiled_hash":compiled.output_hash,"diff":{"population_hash_before":PopulationDocument.hash_source(old_population),"population_hash_after":PopulationDocument.hash_source(population),"anchors_moved":moved,"anchors_settled":settled,"routes":data.patrols.size(),"slots_kept":population.slots.size()},"diagnostics":[]}

static func root_hash(kind: String, root: Dictionary) -> String:
	match kind:
		"map": return MapDocument.hash_source(root)
		"population": return PopulationDocument.hash_source(root)
		"patrol": return PatrolDocument.hash_source(root)
	return ""

## One undoable change of the target session, only on the base it was made from.
static func apply(proposal: Dictionary, session: RefCounted, current: Dictionary) -> Dictionary:
	if not proposal.get("ok",false) or root_hash(proposal.kind,current) != proposal.base_hash: return fail("flow_stale_proposal","",proposal.get("kind",""))
	var applied: Dictionary = session.apply(proposal.source.duplicate(true))
	if not applied.get("ok",false): return applied
	return {"ok":true,"code":"","kind":proposal.kind,"output_hash":proposal.source_hash,"diff":proposal.diff.duplicate(true)}

## One line for the confirmation and the status.
static func summary(proposal: Dictionary) -> String:
	var diff: Dictionary = proposal.get("diff",{})
	match proposal.get("kind",""):
		"map": return "A peça atual entra em %d posição(ões) do mapa (%s); o mapa foi compilado com as emendas." % [diff.instances.size(),", ".join(diff.instances)]
		"population":
			var text := "O mapa atual entra nos encontros: %d marcador(es) seguiram a peça, %d assentaram no novo chão." % [diff.anchors_moved.size(),diff.anchors_settled.size()]
			if diff.plan_recertified: text += " Plano reconferido com os %d slots, sem sortear novos." % diff.slots_kept
			return text
		"patrol": return "Os encontros atuais entram nas patrulhas: %d rota(s) mantidas, %d ponto(s) seguiram a peça, %d assentaram; patrulhas validadas." % [diff.routes,diff.anchors_moved.size(),diff.anchors_settled.size()]
	return ""
