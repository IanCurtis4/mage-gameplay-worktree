extends SceneTree
## Checkpoint43 (F9-05, P3a): regional synthesis inside one piece, on the real
## Bosque clearing piece. Mask, protections, preserved objects, determinism,
## one-step apply/undo, cancellation and refusals without mutation.
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Ops = preload("res://scripts/map_authoring/objects/object_operations.gd")
const Terrain = preload("res://scripts/map_authoring/compiler/terrain_compiler.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const SELECTION := [[384,352],[1152,352],[1152,992],[384,992]]
const GUARD := [[576,512],[704,512],[704,640],[576,640]]
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_SYNTH_CHECK "+id+" "+str(ok))
func request_for(source: Dictionary, channels: Dictionary, seed: String = "17", preserve: Dictionary = {"entity_ids":[],"region_ids":[]}) -> Dictionary:
	return {"algorithm_revision":Synthesis.REVISION,"seed_text":seed,"base_hash":Schema.semantic_hash(source),"target":{"layer_id":"a_ground"},"selection":{"polygon_xz":SELECTION},"channels":channels,"preserve":preserve}
func relief() -> Dictionary: return {"mode":"relief","amplitude":48.0,"feature_size":256.0,"roughness":0.5,"falloff":96.0}
func keep() -> Dictionary: return {"mode":"preserve"}
func layer(source: Dictionary) -> Dictionary: return Synthesis._find(source.layers,"layer_id","a_ground")
func sample(lay: Dictionary, index: int) -> Vector2:
	return Vector2(lay.origin_xz[0],lay.origin_xz[1])+Vector2(index % int(lay.columns),index / int(lay.columns))*float(lay.sample_spacing)
func run() -> void:
	var loaded := Schema.read(FileAccess.get_file_as_bytes("res://data/map_authoring/sanctuary_woods_clearing.source.json"))
	var base: Dictionary = loaded.data
	# A protected region inside the selection, and one locked object in it.
	base.regions.append({"region_id":"test_guard","layer_id":"a_ground","polygon_xz":GUARD,"purpose":"population_exclusion"})
	layer(base).protected_regions.append("test_guard")
	var inside_ids: Array[String] = []
	var catalog := Catalog.load_catalog()
	var selection := Synthesis._polygon(SELECTION)
	for placement: Dictionary in base.placements:
		var radius := float(catalog.definitions[placement.definition_id].footprint_radius)
		if Synthesis._disk_inside(Vector2(placement.position_xyz[0],placement.position_xyz[2]),radius,selection): inside_ids.append(placement.placement_id)
	var locked_id: String = inside_ids[0] if not inside_ids.is_empty() else ""
	var locked := Ops.propose(base,"lock",{"ids":[locked_id],"value":true}) if not locked_id.is_empty() else {"ok":false}
	if locked.ok: base = locked.data
	check("fixture_has_objects_inside_the_selection",inside_ids.size() >= 4 and locked.ok)
	var base_hash := Schema.semantic_hash(base)
	# 1. Refusals.
	var no_channel := request_for(base,{"terrain":relief(),"materials":keep()})
	var bad_seed := request_for(base,{"terrain":relief(),"materials":keep(),"objects":keep()},"07")
	var nothing := request_for(base,{"terrain":keep(),"materials":keep(),"objects":keep()})
	var stale := request_for(base,{"terrain":relief(),"materials":keep(),"objects":keep()}); stale.base_hash = "0".repeat(64)
	var foreign := request_for(base,{"terrain":relief(),"materials":keep(),"objects":keep()}); foreign.selection = {"region_id":"absent_region"}
	check("every_channel_must_be_explicit",Synthesis.prepare(base,no_channel).code == "synthesis_channel_missing")
	check("seed_and_base_are_checked",Synthesis.prepare(base,bad_seed).code == "synthesis_seed_invalid" and Synthesis.prepare(base,stale).code == "base_diverged" and Synthesis.prepare(base,nothing).code == "synthesis_empty" and Synthesis.prepare(base,foreign).code == "source_reference_missing")
	# 2. Terrain relief changes only samples whose whole influence is free.
	var request := request_for(base,{"terrain":relief(),"materials":keep(),"objects":keep()})
	var proposal := Synthesis.prepare(base,request)
	check("relief_proposal_compiles",proposal.ok and proposal.compiled_hash == Terrain.compile(proposal.source).output_hash and proposal.diff.terrain_samples.size() > 0)
	var before := layer(base); var after: Dictionary = layer(proposal.source) if proposal.ok else {}
	var only_free: bool = proposal.ok
	var built := Synthesis.mask(base,request,[])
	var guard := Synthesis._polygon(GUARD)
	var spacing := float(before.sample_spacing)
	for index: int in (proposal.diff.terrain_samples if proposal.ok else []):
		var influence := Synthesis._square(sample(before,index),spacing)
		if not Synthesis._inside(influence,selection) or Synthesis._touches(influence,guard): only_free = false
	check("changes_stay_inside_the_selection_and_off_protection",only_free)
	var outside_same: bool = proposal.ok
	for index: int in (before.heights.size() if proposal.ok else 0):
		if index in proposal.diff.terrain_samples: continue
		if float(before.heights[index]) != float(after.heights[index]): outside_same = false
	check("every_other_sample_is_untouched",outside_same and proposal.source.placements == base.placements)
	# Objects that stay keep the samples under their footprint.
	var footprints_kept: bool = proposal.ok
	for placement: Dictionary in base.placements:
		var center := Vector2(placement.position_xyz[0],placement.position_xyz[2]); var radius := float(catalog.definitions[placement.definition_id].footprint_radius)
		for index: int in (proposal.diff.terrain_samples if proposal.ok else []):
			if Synthesis._disk_touches(center,radius,Synthesis._square(sample(before,index),spacing)): footprints_kept = false
	check("objects_that_stay_keep_their_support",footprints_kept)
	var again := Synthesis.prepare(base,request)
	var other_seed := Synthesis.prepare(base,request_for(base,{"terrain":relief(),"materials":keep(),"objects":keep()},"-9223372036854775808"))
	check("same_request_same_result_other_seed_other_result",again.ok and again.source_hash == proposal.source_hash and other_seed.ok and other_seed.source_hash != proposal.source_hash)
	# 3. Material patches.
	var painted := Synthesis.prepare(base,request_for(base,{"terrain":keep(),"materials":{"mode":"patches","material":"sand","coverage":0.6,"feature_size":192.0},"objects":keep()}))
	var paint_ok: bool = painted.ok and painted.diff.material_samples.size() > 0 and painted.diff.terrain_samples.is_empty()
	if painted.ok:
		var lay := layer(painted.source)
		for index: int in lay.heights.size():
			var weights := Materials.weights(lay,index); var total := 0.0
			for w: float in weights: total += w
			if absf(total-1.0) > 0.0001: paint_ok = false
			if index not in painted.diff.material_samples and Materials.weights(before,index) != weights: paint_ok = false
		for index: int in painted.diff.material_samples:
			if not built.free[index]: paint_ok = false
	check("material_patches_stay_in_the_mask_and_normalized",paint_ok)
	# 4. Scatter that replaces: only unlocked, unpreserved, fully inside objects go.
	var preserved_id: String = inside_ids[1] if inside_ids.size() > 1 else ""
	var scatter_request := request_for(base,{"terrain":keep(),"materials":keep(),"objects":{"mode":"scatter","definition_id":"woodland_shrub","count":3,"spacing":8.0,"replace":true}},"23",{"entity_ids":[preserved_id],"region_ids":[]})
	var scattered := Synthesis.prepare(base,scatter_request)
	var scatter_ok: bool = scattered.ok and scattered.diff.objects_added.size() == 3 and scattered.diff.objects_removed.size() == inside_ids.size()-2 and locked_id not in scattered.diff.objects_removed and preserved_id not in scattered.diff.objects_removed
	if scattered.ok:
		for id: String in scattered.diff.objects_removed:
			if id not in inside_ids: scatter_ok = false
		for placement: Dictionary in scattered.source.placements:
			if placement.placement_id not in scattered.diff.objects_added: continue
			var center := Vector2(placement.position_xyz[0],placement.position_xyz[2]); var radius := float(catalog.definitions[placement.definition_id].footprint_radius)
			if not Synthesis._disk_inside(center,radius,selection) or Synthesis._disk_touches(center,radius,guard): scatter_ok = false
	check("scatter_replaces_only_free_objects_and_places_inside",scatter_ok)
	# 5. One apply, one undo; stale and failed proposals change nothing.
	var session := Session.new(); session.replace(base)
	var applied := Synthesis.apply(proposal,session,base_hash)
	var committed := session.document().semantic_hash()
	var repeated := Synthesis.apply(proposal,session,base_hash)
	session.undo()
	check("apply_is_one_undoable_change",applied.ok and committed != base_hash and repeated.code == "base_diverged" and session.document().semantic_hash() == base_hash and not session.can_undo())
	var crowded := Synthesis.prepare(base,request_for(base,{"terrain":keep(),"materials":keep(),"objects":{"mode":"scatter","definition_id":"oak_tree","count":200,"spacing":0.0,"replace":false}}))
	var cancelled := Synthesis.prepare(base,request,func(_progress: float) -> bool: return true)
	check("deficit_and_cancel_refuse_without_mutation",crowded.code == "object_scatter_deficit" and cancelled.code == "cancelled" and session.document().semantic_hash() == base_hash)
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_SYNTH_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
