extends SceneTree
## Checkpoint45 (F9-08/09, P3c): three-way exchange. The open source moved after
## the request was exported; disjoint changes compose per identity, field and
## sample, equal changes agree, conflicts need an explicit choice, protections
## of the current source prevail, a broken reference refuses, a protected region
## no longer freezes its layer, and a merged population plan is re-certified.
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Rooms = preload("res://tests/map_editor_root_synthesis_test.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const PopulationSession = preload("res://scripts/map_authoring/population/population_session.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const GUARD := [[0,0],[96,0],[96,96],[0,96]]
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_MERGE_CHECK "+id+" "+str(ok))
func heights(piece: Dictionary, values: Dictionary) -> Dictionary:
	var copy := piece.duplicate(true)
	for index: int in values: copy.layers[0].heights[index] = float(values[index])
	return copy
func offer(request: Dictionary, candidate: Dictionary) -> Dictionary:
	var made := Exchange.propose(request,candidate)
	return made.bundle if made.ok else {"failed":made.get("code","")}
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var base: Dictionary = Rooms.piece_source()
	var catalog := Exchange.Props.load_catalog()
	base.placements = [{"placement_id":"stone_a","definition_id":"moss_boulder","revision":int(catalog.definitions.moss_boulder.revision),"position_xyz":[640,0,640],"rotation_y":0.0,"surface_id":"ground"}]
	base.dependencies = [Exchange.Props.dependency(catalog.definitions.moss_boulder)]
	var exported := Exchange.export_bundle("piece",base,Exchange.policy(["layers","placements","regions"]),"Relevo e objetos")
	check("fixture_exports",exported.ok)
	if not exported.ok: print(exported); finish(); return
	var request: Dictionary = exported.bundle
	# 1. Disjoint sample edits compose.
	var current := heights(base,{20:8.0}); current.revision = 2
	var proposal := offer(request,heights(base,{100:12.0}))
	var merged := Exchange.prepare(request,proposal,current)
	check("disjoint_samples_compose",merged.ok and not merged.already_applied and merged.source.layers[0].heights[20] == 8.0 and merged.source.layers[0].heights[100] == 12.0 and merged.merge.applied == ["/layers/@ground/heights/100"] and merged.source.revision == 2 and merged.output_hash == Exchange.build("piece",merged.source).output_hash)
	# 2. The same change on both sides agrees.
	var same := Exchange.prepare(request,offer(request,heights(base,{20:8.0,100:12.0})),current)
	check("equal_changes_agree",same.ok and "/layers/@ground/heights/20" in same.merge.agreed and same.source.layers[0].heights[100] == 12.0)
	# 3. A conflicting value needs a choice; both choices work.
	var rival := offer(request,heights(base,{20:-6.0}))
	var conflict := Exchange.prepare(request,rival,current)
	var listed: bool = conflict.code == "exchange_conflict" and conflict.conflicts.size() == 1 and conflict.conflicts[0].path == "/layers/@ground/heights/20" and conflict.conflicts[0].kind == "value" and conflict.conflicts[0].current == 8.0 and conflict.conflicts[0].proposal == -6.0
	check("conflict_is_reported_without_mutation",listed and current.layers[0].heights[20] == 8.0)
	var keep := Exchange.prepare(request,rival,current,Callable(),{"/layers/@ground/heights/20":"current"})
	var take := Exchange.prepare(request,rival,current,Callable(),{"/layers/@ground/heights/20":"proposal"})
	check("explicit_choice_resolves",keep.ok and keep.already_applied and take.ok and take.source.layers[0].heights[20] == -6.0)
	check("unknown_choice_is_refused",Exchange.prepare(request,rival,current,Callable(),{"/layers/@ground/heights/21":"current"}).code == "exchange_resolution_invalid")
	# 4. Removal against edit is a conflict; taking the edit of a removed object is invalid.
	var removed := base.duplicate(true); removed.placements = []
	var turned := base.duplicate(true); turned.placements[0].rotation_y = 90.0
	var edit := offer(request,turned)
	var clash := Exchange.prepare(request,edit,removed)
	var dropped := Exchange.prepare(request,edit,removed,Callable(),{"/placements/@stone_a/rotation_y":"current"})
	var forced := Exchange.prepare(request,edit,removed,Callable(),{"/placements/@stone_a/rotation_y":"proposal"})
	check("remove_versus_edit",clash.code == "exchange_conflict" and clash.conflicts[0].local_paths == ["/placements/@stone_a"] and dropped.ok and dropped.already_applied and forced.code == "exchange_merge_invalid")
	# 5. A reference the current source removed refuses the merge.
	var unregioned := base.duplicate(true); unregioned.regions = []
	var protecting := base.duplicate(true); protecting.layers[0].protected_regions = ["variation_area"]
	var broken := Exchange.prepare(request,offer(request,protecting),unregioned)
	check("broken_reference_refuses",broken.code == "exchange_merge_invalid" and broken.cause == "source_invalid")
	# 6. A protection added in the current source prevails.
	var guarded := base.duplicate(true)
	guarded.regions.append({"region_id":"corner_guard","layer_id":"ground","polygon_xz":GUARD,"purpose":"fixed"}); guarded.layers[0].protected_regions = ["corner_guard"]
	var corner := offer(request,heights(base,{0:5.0,100:12.0}))
	var held := Exchange.prepare(request,corner,guarded)
	var forced_guard := Exchange.prepare(request,corner,guarded,Callable(),{"/layers/@ground/heights/0":"proposal"})
	var yielded := Exchange.prepare(request,corner,guarded,Callable(),{"/layers/@ground/heights/0":"current"})
	check("current_protection_prevails",held.code == "exchange_conflict" and held.conflicts[0].kind == "protection" and forced_guard.code == "exchange_protected" and yielded.ok and yielded.source.layers[0].heights[0] == 0.0 and yielded.source.layers[0].heights[100] == 12.0)
	# 7. The shared mask: a protected region guards its samples, not the whole layer.
	var masked := Exchange.export_bundle("piece",guarded,Exchange.policy(["layers"]),"Camada com proteção")
	var far := Exchange.propose(masked.bundle,heights(guarded,{100:12.0}))
	var near := Exchange.propose(masked.bundle,heights(guarded,{0:5.0}))
	var tinted := guarded.duplicate(true); var sand: Array = []; sand.resize(169); sand.fill(0.0); sand[100] = 1.0; tinted.layers[0].material_masks = {"sand":sand}
	var painted_far := Exchange.propose(masked.bundle,tinted)
	var smeared := tinted.duplicate(true); smeared.layers[0].material_masks.sand[0] = 1.0
	check("protected_region_guards_only_its_samples",masked.ok and far.ok and near.code == "exchange_protected" and painted_far.ok and Exchange.propose(masked.bundle,smeared).code == "exchange_protected")
	# 8. Population: a merged recipe re-certifies the plan without redrawing.
	var built := Rooms.fixture()
	var population: Dictionary = built.population
	var pop_request := Exchange.export_bundle("population",population,Exchange.policy(["name","exclusions","plan_hash"]),"Exclusões")
	var local_pop := population.duplicate(true); local_pop.name = "Encontros revisados"
	var fenced := population.duplicate(true)
	var east := Rooms.fixture_at(built.base_index,"east_room",1408,640)
	fenced.exclusions = [{"exclusion_id":"quiet_corner","surface_id":east.surface_id,"center_xyz":east.position_xyz,"radius":48}]
	fenced.plan_hash = PopulationDocument.recipe_hash(fenced)
	var pop_proposal := offer(pop_request.bundle,fenced) if pop_request.ok else {}
	var pop_merged := Exchange.prepare(pop_request.bundle,pop_proposal,local_pop) if pop_request.ok else {"ok":false}
	var same_slots: bool = pop_merged.ok and pop_merged.source.slots == local_pop.slots
	check("population_plan_is_recertified",pop_merged.ok and same_slots and pop_merged.source.name == "Encontros revisados" and pop_merged.source.exclusions.size() == 1 and pop_merged.source.plan_hash == PopulationDocument.recipe_hash(pop_merged.source))
	# 9. One undo; nothing changes before the commit.
	var session := PopulationSession.new(); session.replace(local_pop)
	var before := PopulationDocument.hash_source(local_pop)
	var applied := Exchange.apply_to(pop_request.bundle,pop_proposal,session.data,session.apply) if pop_request.ok else {"ok":false}
	var after := PopulationDocument.hash_source(session.data)
	session.undo()
	check("merged_apply_is_one_undo",applied.ok and after == pop_merged.get("source_hash","") and PopulationDocument.hash_source(session.data) == before and not session.can_undo())
	var piece_session := Session.new(); piece_session.replace(current)
	var piece_applied := Exchange.apply_to(request,proposal,piece_session.document().to_data(),piece_session.apply)
	var again := Exchange.prepare(request,proposal,piece_session.document().to_data())
	check("merged_piece_reapply_is_noop",piece_applied.ok and piece_session.document().to_data().layers[0].heights[100] == 12.0 and again.ok and again.already_applied)
	finish()
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_MERGE_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
