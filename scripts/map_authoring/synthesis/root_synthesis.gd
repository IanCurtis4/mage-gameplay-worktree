@tool
extends RefCounted
## Checkpoint44 (F9-05/08, P3b): regional variation of one map instance, with the
## map, its population or its patrols as the open root. The piece work is
## regional_synthesis.gd (same mask, same recipes); this adapter:
## - takes the selection in the instance's own (piece) coordinates;
## - protects, on that piece, the body of every encounter anchor and every patrol
##   leg that stays (entrance, interactions, slots, waypoints);
## - writes the varied piece as a NEW snapshot in map.pieces and swaps only that
##   instance's piece_hash; other instances keep theirs, the old snapshot stays
##   while referenced; instance IDs, links, borders and context are untouched;
## - reconciles every anchor of the varied layer by its authored family
##   (instance + layer) and position, never by the nearest floor: bodies must find
##   the same height (else synthesis_support_changed), area centres are resettled
##   and listed in the diff;
## - encounters "regenerate" redraws only the free slots fully inside the
##   selection, after reserving every other slot (PopulationCompiler scope);
##   slots that a patrol uses always stay;
## - compiles the whole final root before offering the proposal; apply() is one
##   session.apply after the base check (one undo).
## Contract: docs/map_editor/contracts/f9_regional_synthesis.md.
const Piece = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const PatrolCompiler = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const Kernel = preload("res://scripts/core/expedition/generation/fixture_geometry.gd")
const Receipts = preload("res://scripts/map_authoring/synthesis/receipts.gd")
const KINDS := ["map","population","patrol"]
const ENCOUNTER_MODES := ["preserve","regenerate"]
const PATROL_MODES := ["preserve"]
const HEIGHT_EPS := 0.05
## Conservative bodies: larger than the player profile and the authored mobs, so
## the terrain kept under a body is never smaller than what stands on it.
const ANCHOR_RADIUS := 24.0
const SLOT_RADIUS := 48.0

static func fail(code: String, entity: String = "", field: String = "synthesis") -> Dictionary:
	var messages := {"synthesis_root_unsupported":"Este documento não aceita variação regional.","synthesis_target_missing":"A instância ou a peça indicada não existe neste mapa.","synthesis_target_mismatch":"A instância não usa mais a peça indicada; refaça a prévia.","synthesis_support_lost":"Um marcador da camada ficou sem piso depois da variação.","synthesis_support_changed":"A variação mudaria a altura sob um marcador preservado.","synthesis_patrol_recipe":"Patrulhas só podem ser preservadas nesta versão; mude as rotas na tela de patrulhas.","synthesis_map_missing":"Os encontros ainda não têm mapa importado."}
	if messages.has(code): return {"ok":false,"code":code,"diagnostics":[{"code":code,"severity":"error","entity_id":entity,"field":field,"message":messages[code]}]}
	return Piece.fail(code,entity,field)

static func kind_of(root: Dictionary) -> String:
	if root.has("patrols"): return "patrol"
	if root.has("brushes"): return "population"
	if root.has("pieces"): return "map"
	return ""

static func root_hash(kind: String, root: Dictionary) -> String:
	match kind:
		"map": return MapDocument.hash_source(root)
		"population": return PopulationDocument.hash_source(root)
		"patrol": return PatrolDocument.hash_source(root)
	return ""

static func validate_root(kind: String, root: Variant) -> Dictionary:
	if not root is Dictionary: return fail("synthesis_root_unsupported")
	match kind:
		"map": return MapDocument.validate(root)
		"population": return PopulationDocument.validate(root)
		"patrol": return PatrolDocument.validate(root)
	return fail("synthesis_root_unsupported")

static func population_of(kind: String, root: Dictionary) -> Dictionary:
	if kind == "population": return root
	if kind == "patrol" and not root.population.is_empty(): return root.population[0]
	return {}

static func map_of(kind: String, root: Dictionary) -> Dictionary:
	if kind == "map": return root
	var population := population_of(kind,root)
	return population.map[0] if not population.is_empty() and not population.map.is_empty() else {}

static func channel_keys(kind: String) -> Array:
	var keys := ["terrain","materials","objects"]
	if kind in ["population","patrol"]: keys.append("encounters")
	if kind == "patrol": keys.append("patrols")
	return keys

## The closed root request: the piece request plus target.instance_id and
## target.piece_hash, and the encounter/patrol channels the root has.
static func validate_request(kind: String, request: Variant) -> Dictionary:
	if kind not in KINDS: return fail("synthesis_root_unsupported")
	if not request is Dictionary or request.size() != Piece.REQUEST_KEYS.size() or not request.has_all(Piece.REQUEST_KEYS): return fail("synthesis_request_invalid")
	var target: Variant = request.target
	if not target is Dictionary or target.size() != 3 or not Schema._type(target.get("instance_id"),"id") or not Schema._type(target.get("piece_hash"),"hash") or not Schema._type(target.get("layer_id"),"id"): return fail("synthesis_request_invalid","","target")
	var channels: Variant = request.channels
	var keys := channel_keys(kind)
	if not channels is Dictionary or channels.size() != keys.size() or not channels.has_all(keys): return fail("synthesis_channel_missing","","channels")
	if channels.has("encounters") and (not channels.encounters is Dictionary or channels.encounters.size() != 1 or channels.encounters.get("mode") not in ENCOUNTER_MODES): return fail("synthesis_request_invalid","","channels.encounters")
	if channels.has("patrols"):
		if not channels.patrols is Dictionary or channels.patrols.size() != 1 or not channels.patrols.get("mode") is String: return fail("synthesis_request_invalid","","channels.patrols")
		if channels.patrols.mode not in PATROL_MODES: return fail("synthesis_patrol_recipe","","channels.patrols")
	var checked := Piece.validate_request(piece_request(request))
	if not checked.ok and not (checked.code == "synthesis_empty" and regenerates(request)): return checked
	return {"ok":true}

static func regenerates(request: Dictionary) -> bool:
	return request.channels.has("encounters") and request.channels.encounters.mode == "regenerate"

static func piece_changes(request: Dictionary) -> bool:
	for key: String in ["terrain","materials","objects"]:
		if request.channels[key].mode != "preserve": return true
	return false

static func piece_request(request: Dictionary) -> Dictionary:
	return {"algorithm_revision":request.algorithm_revision,"seed_text":request.seed_text,"base_hash":request.target.get("piece_hash",""),"target":{"layer_id":request.target.get("layer_id","")},"selection":request.selection,"channels":{"terrain":request.channels.get("terrain"),"materials":request.channels.get("materials"),"objects":request.channels.get("objects")},"preserve":request.preserve}

static func vector(xyz: Array) -> Vector3: return Vector3(float(xyz[0]),float(xyz[1]),float(xyz[2]))
static func to_local(instance: Dictionary, world: Vector3) -> Vector3:
	return Kernel.rotate(world-vector(instance.position_xyz),posmod(-int(instance.rotation_quarters),4))
static func to_world(instance: Dictionary, local: Vector3) -> Vector3:
	return Kernel.rotate(local,int(instance.rotation_quarters))+vector(instance.position_xyz)

## Compiled map, its walkable families (instance/layer/<id> or instance/special/<id>)
## and the cells of each family.
static func index(map: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	var built := MapCompiler.compile(map,func(progress: float) -> bool: return cancellation.is_valid() and cancellation.call(progress))
	if not built.ok: return built
	# Plain package data: no gameplay Resource is built in the editor process.
	var families: Dictionary = {}; var cells: Dictionary = {}
	for instance: Dictionary in built.package.render_instances:
		for visual: Dictionary in instance.visuals:
			if visual.walkable: families[instance.instance_id+"/"+visual.surface_id] = instance.instance_id+("/special/" if visual.special else "/layer/")+visual.source_id
	for cell: Dictionary in built.package.manifest.stages[0].surfaces:
		var family: String = families.get(cell.surface_id,cell.surface_id)
		if not cells.has(family): cells[family] = []
		cells[family].append(cell)
	return {"ok":true,"compiled_hash":built.output_hash,"families":families,"cells":cells}

## The cell of that family under (x, z), and its height there.
static func locate(built: Dictionary, family: String, xz: Vector2) -> Dictionary:
	for cell: Dictionary in built.cells.get(family,[]):
		var normal := Kernel.plane_normal(cell.vertices)
		if absf(normal.y) < 0.001: continue
		var at := Kernel.support_y(cell,Vector3(xz.x,0,xz.y))
		if Kernel.contains(cell,at): return {"ok":true,"surface_id":cell.surface_id,"y":at.y}
	return {"ok":false}

## Every authored anchor of the root: {id, kind, ref (the dictionary to update),
## field, body, radius}. Bodies keep their terrain; area centres are resettled.
static func anchors(kind: String, root: Dictionary) -> Array:
	var result: Array = []
	var population := population_of(kind,root)
	if population.is_empty(): return result
	for entry: Dictionary in population.entrance: result.append({"id":"entrance","kind":"entrance","ref":entry,"field":"position_xyz","body":true,"radius":ANCHOR_RADIUS})
	for brush: Dictionary in population.brushes: result.append({"id":brush.brush_id,"kind":"brush","ref":brush,"field":"center_xyz","body":false,"radius":0.0})
	for exclusion: Dictionary in population.exclusions: result.append({"id":exclusion.exclusion_id,"kind":"exclusion","ref":exclusion,"field":"center_xyz","body":false,"radius":0.0})
	for interaction: Dictionary in population.interactions: result.append({"id":interaction.interaction_id,"kind":"interaction","ref":interaction,"field":"position_xyz","body":true,"radius":ANCHOR_RADIUS})
	for slot: Dictionary in population.slots: result.append({"id":slot.slot_id,"kind":"slot","ref":slot,"field":"position_xyz","body":true,"radius":SLOT_RADIUS})
	if kind == "patrol":
		for route: Dictionary in root.patrols:
			for point: Dictionary in route.waypoints: result.append({"id":route.patrol_id+"/"+point.point_id,"kind":"waypoint","ref":point,"field":"position_xyz","body":true,"radius":ANCHOR_RADIUS,"route":route.patrol_id})
	return result

static func _patrol_slots(kind: String, root: Dictionary) -> Array:
	var ids: Array = []
	if kind != "patrol": return ids
	for route: Dictionary in root.patrols:
		for id: String in route.slot_ids:
			if id not in ids: ids.append(id)
	return ids

## Builds the whole proposal on a copy; never mutates the session.
static func prepare(kind: String, root: Dictionary, request: Dictionary, cancellation: Callable = Callable()) -> Dictionary:
	var started := Time.get_ticks_usec()
	var checked := validate_request(kind,request)
	if not checked.ok: return checked
	var read := validate_root(kind,root)
	if not read.ok: return read
	if root_hash(kind,root) != request.base_hash: return fail("base_diverged","","base_hash")
	var data: Dictionary = root.duplicate(true)
	var map := map_of(kind,data)
	if map.is_empty(): return fail("synthesis_map_missing")
	var instance := Piece._find(map.instances,"instance_id",request.target.instance_id)
	var snapshot := Piece._find(map.pieces,"piece_hash",request.target.piece_hash)
	if instance.is_empty() or snapshot.is_empty(): return fail("synthesis_target_missing",request.target.instance_id,"target")
	if instance.piece_hash != request.target.piece_hash: return fail("synthesis_target_mismatch",request.target.instance_id,"target")
	var stop := func(progress: float) -> bool: return cancellation.is_valid() and cancellation.call(progress)
	var halt := func() -> bool: return cancellation.is_valid() and cancellation.call(-1.0)
	var family: String = instance.instance_id+"/layer/"+request.target.layer_id
	var local_request := piece_request(request)
	var region := Piece.mask(snapshot.source,local_request)
	if not region.ok: return region
	var world_polygon: Array = []
	for point: Vector2 in region.selection:
		var at := to_world(instance,Vector3(point.x,0,point.y)); world_polygon.append([at.x,at.z])
	var world_selection := Piece._polygon(world_polygon)
	if stop.call(0.02): return Piece.fail("cancelled")
	var base := index(map,stop)
	if not base.ok: return base
	# Slots that a regeneration may redraw: free (not fixed, not reserved, not in
	# a patrol, not preserved) and with the whole body inside the selection.
	var removed: Array[String] = []
	var population := population_of(kind,data)
	var used := _patrol_slots(kind,data)
	# An unplanned population (no realized plan yet) keeps its slots as drafts;
	# regenerating part of a plan that does not exist is refused.
	var planned: bool = not population.is_empty() and population.plan_hash == PopulationDocument.recipe_hash(population)
	if regenerates(request) and not planned: return Population.fail("plan_stale")
	if regenerates(request):
		for slot: Dictionary in population.slots:
			if slot.fixed or not slot.site_id.is_empty() or slot.slot_id in used or slot.slot_id in request.preserve.entity_ids: continue
			if base.families.get(slot.surface_id,"") != family: continue
			var at := vector(slot.position_xyz)
			if Piece._disk_inside(Vector2(at.x,at.z),SLOT_RADIUS,world_selection): removed.append(slot.slot_id)
	# Bodies and patrol legs that stay on the varied layer, in piece coordinates.
	var discs: Array = []; var segments: Array = []
	var all := anchors(kind,data)
	for anchor: Dictionary in all:
		if not anchor.body or anchor.id in removed or base.families.get(anchor.ref.surface_id,"") != family: continue
		var local := to_local(instance,vector(anchor.ref[anchor.field]))
		discs.append({"center":Vector2(local.x,local.z),"radius":float(anchor.radius),"id":anchor.id})
	if kind == "patrol":
		for route: Dictionary in data.patrols:
			var points: Array = route.waypoints
			var legs: Array = []
			for i: int in points.size()-1: legs.append([points[i],points[i+1]])
			if route.mode == "loop" and points.size() > 2: legs.append([points[points.size()-1],points[0]])
			for leg: Array in legs:
				if base.families.get(leg[0].surface_id,"") != family and base.families.get(leg[1].surface_id,"") != family: continue
				var a := to_local(instance,vector(leg[0].position_xyz)); var b := to_local(instance,vector(leg[1].position_xyz))
				segments.append({"a":Vector2(a.x,a.z),"b":Vector2(b.x,b.z),"radius":ANCHOR_RADIUS,"id":route.patrol_id})
	# The varied piece becomes a new snapshot used only by this instance.
	var piece_diff: Dictionary = {}
	var snapshots_added: Array = []; var snapshots_removed: Array = []
	var before_hash: String = instance.piece_hash
	if piece_changes(request):
		var piece := Piece.prepare(snapshot.source,local_request,func(progress: float) -> bool: return stop.call(0.05+0.35*progress),{"discs":discs,"segments":segments,"nested":true})
		if not piece.ok: return piece
		piece_diff = piece.diff
		var after_hash: String = piece.source_hash
		if Piece._find(map.pieces,"piece_hash",after_hash).is_empty():
			map.pieces.append({"piece_hash":after_hash,"source":piece.source}); snapshots_added.append(after_hash)
		instance.piece_hash = after_hash
		var referenced := false
		for other: Dictionary in map.instances:
			if other.piece_hash == before_hash: referenced = true
		if not referenced:
			map.pieces = map.pieces.filter(func(entry: Dictionary) -> bool: return entry.piece_hash != before_hash); snapshots_removed.append(before_hash)
	if stop.call(0.45): return Piece.fail("cancelled")
	# Checkpoint46 (P3d): a map root is final here; its receipt goes in before the
	# compilation that certifies it.
	if kind == "map": Receipts.attach(data,Receipts.make(kind,request,data,_summary(piece_diff,[],[],[]),Piece.REVISION))
	var after: Dictionary = index(map,stop) if piece_changes(request) else base
	if not after.ok: return after
	# Reconcile every anchor of the varied layer by family and position.
	var remapped: Array[String] = []; var resettled: Array[String] = []
	if not population.is_empty():
		population.slots = population.slots.filter(func(slot: Dictionary) -> bool: return slot.slot_id not in removed)
		for anchor: Dictionary in anchors(kind,data):
			if base.families.get(anchor.ref.surface_id,"") != family: continue
			var at := vector(anchor.ref[anchor.field])
			var xz := Vector2(at.x,at.z)
			var now := locate(after,family,xz)
			if not now.ok: return fail("synthesis_support_lost",anchor.id,anchor.kind)
			if anchor.body:
				var was := locate(base,family,xz)
				if not was.ok or absf(float(now.y)-float(was.y)) > HEIGHT_EPS: return fail("synthesis_support_changed",anchor.id,anchor.kind)
				if now.surface_id != anchor.ref.surface_id: anchor.ref.surface_id = now.surface_id; remapped.append(anchor.id)
			elif now.surface_id != anchor.ref.surface_id or absf(float(now.y)-at.y) > 0.0001:
				anchor.ref.surface_id = now.surface_id; anchor.ref[anchor.field][1] = now.y; resettled.append(anchor.id)
	# Encounters. The plan hash covers the map, so a realized plan is always
	# re-certified on the new map: every slot that stays is reserved and
	# validated first; "regenerate" then redraws only inside the selection,
	# "preserve" draws nothing (a changed quota is a deficit, never a new slot).
	var slots_added: Array = []
	if planned:
		var kept: Array = []
		for slot: Dictionary in population.slots:
			if not slot.fixed: kept.append(slot.slot_id)
		var scope := {"keep":kept,"within":{"family":family,"polygon_xz":world_polygon}}
		if not regenerates(request): scope["redraw"] = false
		var redrawn := Population.regenerate(population,halt,scope)
		if not redrawn.ok: return redrawn
		for slot: Dictionary in redrawn.data.slots:
			if Piece._find(population.slots,"slot_id",slot.slot_id).is_empty(): slots_added.append(slot.slot_id)
		population.slots = redrawn.data.slots; population.plan_hash = redrawn.data.plan_hash
	if stop.call(0.7): return Piece.fail("cancelled")
	if kind != "map": Receipts.attach(data,Receipts.make(kind,request,data,_summary(piece_diff,slots_added,removed,remapped),Piece.REVISION))
	# Compile the whole final root before offering it.
	var final := validate_root(kind,data)
	if not final.ok: return final
	var compiled: Dictionary = {"ok":true,"output_hash":after.compiled_hash}
	if planned and kind == "population": compiled = Population.compile(data,halt)
	elif planned and kind == "patrol": compiled = PatrolCompiler.compile(data,halt)
	if not compiled.ok: return compiled
	slots_added.sort(); removed.sort(); remapped.sort(); resettled.sort()
	return {"ok":true,"code":"","kind":kind,"algorithm_revision":Piece.REVISION,"base_hash":request.base_hash,"request_hash":Piece.request_hash(request),"source":data,"source_hash":root_hash(kind,data),"compiled_hash":compiled.output_hash,
		"diff":{"instance_id":instance.instance_id,"layer_id":request.target.layer_id,"piece_hash_before":before_hash,"piece_hash_after":instance.piece_hash,"piece":piece_diff,"snapshots_added":snapshots_added,"snapshots_removed":snapshots_removed,"anchors_remapped":remapped,"anchors_resettled":resettled,"slots_removed":removed,"slots_added":slots_added},
		"diagnostics":[] if planned or kind == "map" else [{"code":"plan_stale","severity":"warning","entity_id":"","field":"plan_hash","message":"Os encontros ainda não têm plano realizado; só o mapa foi compilado."}],"metrics":{"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"protected_bodies":discs.size(),"protected_legs":segments.size()}}

static func _summary(piece_diff: Dictionary, added: Array, removed: Array, remapped: Array) -> Dictionary:
	return {"terrain_samples":piece_diff.get("terrain_samples",[]).size(),"material_samples":piece_diff.get("material_samples",[]).size(),"objects_added":piece_diff.get("objects_added",[]).size(),"objects_removed":piece_diff.get("objects_removed",[]).size(),"slots_added":added.size(),"slots_removed":removed.size(),"anchors_remapped":remapped.size()}

## Commits the proposal as one undoable change of the open root, after the base check.
static func apply(proposal: Dictionary, session: RefCounted, expected_hash: String) -> Dictionary:
	if not proposal.get("ok",false) or session == null: return fail("synthesis_stale_proposal")
	var current := root_hash(proposal.kind,session.data)
	if current != expected_hash or current != proposal.base_hash: return fail("base_diverged")
	var stored := Receipts.store(proposal.kind,session.data)
	var applied: Dictionary = session.apply(proposal.source)
	if not applied.ok: return applied
	applied["proposal_hash"] = proposal.source_hash
	applied["ledger"] = stored
	return applied

# Background preparation for the GUI (same prepare(), on copies).
var _thread: Thread
var _mutex := Mutex.new()
var _progress := 0.0
var _stop := false
var _done := false
var _result: Dictionary = {}

func start(kind: String, root: Dictionary, request: Dictionary) -> void:
	var data := root.duplicate(true); var copy := request.duplicate(true)
	_thread = Thread.new()
	_thread.start(func() -> void:
		var outcome := prepare(kind,data,copy,_tick)
		_mutex.lock(); _result = outcome; _done = true; _mutex.unlock())

func _tick(value: float) -> bool:
	_mutex.lock()
	if value >= 0.0: _progress = value
	var stop := _stop
	_mutex.unlock()
	return stop

func progress() -> float:
	_mutex.lock(); var value := _progress; _mutex.unlock()
	return value

func ready() -> bool:
	_mutex.lock(); var value := _done; _mutex.unlock()
	return value

func cancel() -> void:
	_mutex.lock(); _stop = true; _mutex.unlock()

func take() -> Dictionary:
	if _thread != null: _thread.wait_to_finish(); _thread = null
	_mutex.lock(); var value := _result; _mutex.unlock()
	return value

func close() -> void:
	cancel()
	if _thread != null: _thread.wait_to_finish(); _thread = null
