@tool
extends SceneTree
const Document = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Solver = preload("res://scripts/map_authoring/generation/generation_solver.gd")
const Adapter = preload("res://scripts/map_authoring/generation/assembler_adapter.gd")
const Store = preload("res://scripts/map_authoring/generation/generation_store.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Session = preload("res://scripts/map_authoring/composition/map_session.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
var checks: Array = []
static func fixture() -> Dictionary:
	var map := Map.sample()
	map.pieces[0].source.name = "Sala de grama"; map.pieces[1].source.name = "Sala de grama"
	for i: int in 2:
		map.pieces[i].piece_hash = Schema.semantic_hash(map.pieces[i].source); map.instances[i].piece_hash = map.pieces[i].piece_hash
	var alternate: Dictionary = map.pieces[1].source.duplicate(true); alternate.document_id = "room_earth"; alternate.name = "Sala de terra"; alternate.layers[0].material_masks = {"earth":[1,1,1,1],"grass":[0,0,0,0]}
	var hash_value := Schema.semantic_hash(alternate); map.pieces.append({"piece_hash":hash_value,"source":alternate})
	var source := Document.from_map(map)
	source.domains[1].options.append({"piece_hash":hash_value,"rotation_quarters":0,"weight":1})
	source.pins = ["left"]; return source
static func with_bad_candidate() -> Dictionary:
	var source := fixture(); var bad: Dictionary = source.map.pieces[1].source.duplicate(true)
	bad.document_id = "unlinked_room"; bad.connectors.append({"connector_id":"north","surface_id":"floor","position_xyz":[50,0,0],"normal_xyz":[0,0,-1],"kind":"walk","width":24,"headroom":100,"tags":["ruin"],"direction":"both"})
	var hash_value := Schema.semantic_hash(bad); source.map.pieces.append({"piece_hash":hash_value,"source":bad})
	source.domains[1].options = [source.domains[1].options[0],{"piece_hash":hash_value,"rotation_quarters":0,"weight":100}]
	return source
static func cycle_fixture() -> Dictionary:
	var map := Map.empty("cycle"); var template: Dictionary = Map.sample().pieces[0].source
	var sides := {"east":[[100,0,50],[1,0,0]],"west":[[0,0,50],[-1,0,0]],"north":[[50,0,0],[0,0,-1]],"south":[[50,0,100],[0,0,1]]}
	var shapes := {"a":["east","south"],"b":["west","south"],"c":["west","north"],"d":["east","north"]}
	var positions := {"a":[0,0,0],"b":[100,0,0],"c":[100,0,100],"d":[0,0,100]}
	for id: String in shapes:
		var piece := template.duplicate(true); piece.document_id = "corner_"+id; piece.connectors = []
		for side: String in shapes[id]: piece.connectors.append({"connector_id":side,"surface_id":"floor","position_xyz":sides[side][0],"normal_xyz":sides[side][1],"kind":"walk","width":24,"headroom":100,"tags":["ruin"],"direction":"both"})
		var hash_value := Schema.semantic_hash(piece); map.pieces.append({"piece_hash":hash_value,"source":piece}); map.instances.append({"instance_id":id,"piece_hash":hash_value,"position_xyz":positions[id],"rotation_quarters":0})
	for pair: Array in [["a","east","b","west"],["b","south","c","north"],["c","west","d","east"],["d","north","a","south"]]: map.links.append({"link_id":pair[0]+pair[2],"a_instance":pair[0],"a_connector":pair[1],"b_instance":pair[2],"b_connector":pair[3]})
	return Document.from_map(map)
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("M6_CHECK "+id+" "+str(ok))
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var source := fixture(); var original := Document.hash_source(source)
	check("schema",Document.validate(source).ok)
	check("opt_in_required",Solver.new().solve(source).code == "experimental_disabled")
	var result := Solver.new().solve(source,true)
	check("generates",result.ok)
	if not result.ok: print(result); finish(); return
	check("unchanged_authorship",Document.hash_source(source) == original)
	check("package_valid",Compiler.validate_package(result.package))
	check("same_authority",Compiler.compile(result.proposal).output_hash == result.output_hash)
	check("pin_exact",Schema._canonical(result.proposal.instances[0]) == Schema._canonical(source.map.instances[0]))
	check("fixed_transforms_links",result.proposal.links == source.map.links and result.proposal.instances[1].position_xyz == source.map.instances[1].position_xyz)
	check("snapshot_unchanged",result.proposal.pieces == source.map.pieces)
	check("repeat",Solver.new().solve(source,true).output_hash == result.output_hash)
	var reordered := source.duplicate(true); reordered.map.pieces.reverse(); reordered.map.instances.reverse(); reordered.map.links.reverse(); reordered.domains.reverse(); reordered.selection.reverse()
	for domain: Dictionary in reordered.domains: domain.options.reverse()
	var order_result := Solver.new().solve(reordered,true)
	check("order_hash",Document.hash_source(reordered) == original)
	check("order_result",order_result.ok and order_result.output_hash == result.output_hash and order_result.diagnostic == result.diagnostic)
	var realized := {}; var corpus: Array = []
	for seed_text: String in ["0","-1","9223372036854775807","-9223372036854775808","1","2","3","4"]:
		var item := source.duplicate(true); item.seed_text = seed_text
		var tick := Time.get_ticks_usec(); var wfc := Solver.new().solve(item,true); var elapsed := (Time.get_ticks_usec()-tick)/1000.0
		var tick_a := Time.get_ticks_usec(); var baseline := Adapter.build(item); var elapsed_a := (Time.get_ticks_usec()-tick_a)/1000.0
		check("seed_valid_"+seed_text,Document.validate(item).ok and wfc.ok)
		check("seed_repeat_"+seed_text,wfc.ok and Solver.new().solve(item,true).output_hash == wfc.output_hash)
		check("assembler_real_"+seed_text,baseline.ok and baseline.metrics.revision == ExpeditionAssembler.REVISION and Compiler.validate_package(baseline.package))
		if wfc.ok: realized[wfc.output_hash] = true
		corpus.append({"seed_text":seed_text,"request_hash":Document.hash_source(item),"wfc":{"ok":wfc.ok,"code":wfc.code,"hash":wfc.get("output_hash",""),"elapsed_ms":elapsed,"diagnostic":wfc.get("diagnostic",{})},"assembler":{"ok":baseline.ok,"code":baseline.code,"hash":baseline.get("output_hash",""),"elapsed_total_ms":elapsed_a,"metrics":baseline.get("metrics",{})}})
	check("two_real_variants",realized.size() > 1)
	var rotated := source.duplicate(true)
	for instance: Dictionary in rotated.map.instances:
		instance.rotation_quarters = 1; instance.position_xyz = [0,0,100] if instance.instance_id == "right" else [0,0,0]
	for domain: Dictionary in rotated.domains:
		for option: Dictionary in domain.options: option.rotation_quarters = 1
	check("allowed_rotation_works",Solver.new().solve(rotated,true).ok)
	var cycle := cycle_fixture(); var cycle_result := Solver.new().solve(cycle,true); var cycle_baseline := Adapter.build(cycle)
	check("cyclic_graph_global_validation",cycle_result.ok and cycle_result.package.piece_count == 4)
	check("assembler_cycle_explicit",cycle_baseline.code == "assembler_unsupported")
	corpus.append({"case":"four_room_cycle","request_hash":Document.hash_source(cycle),"wfc":{"ok":cycle_result.ok,"code":cycle_result.code},"assembler":{"ok":cycle_baseline.ok,"code":cycle_baseline.code}})
	var invalid := source.duplicate(true); invalid.seed_text = "9223372036854775808"; check("seed_overflow",not Document.validate(invalid).ok)
	for bad_seed: String in ["-9223372036854775809","01","-0","1.0","+1",""]:
		invalid = source.duplicate(true); invalid.seed_text = bad_seed; check("seed_reject_"+bad_seed,Document.validate(invalid).code == "generation_seed")
	invalid = source.duplicate(true); invalid.extra = 1; check("unknown_field",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.schema_version = 2; check("future_version",Document.validate(invalid).code == "generation_version")
	invalid = source.duplicate(true); invalid.algorithm_revision = "new"; check("future_algorithm",Document.validate(invalid).code == "generation_version")
	invalid = source.duplicate(true); invalid.domains[1].options.clear(); check("zero_candidates",Solver.new().solve(invalid,true).code == "generation_domain")
	invalid = source.duplicate(true); invalid.domains[1].options[0].weight = NAN; check("nonfinite",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.domains[1].options[0].rotation_quarters = 0.5; check("rotation_integer",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.domains[1].options[0].weight = 0; check("weight_positive",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.pins.append("absent"); check("pin_reference",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.selection.append("right"); check("selection_duplicate",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.domains[1].instance_id = "left"; check("domain_duplicate",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.domains[1].options.append(invalid.domains[1].options[0]); check("option_duplicate",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.domains[0].options[0].piece_hash = source.domains[1].options[0].piece_hash
	var failed := Solver.new().solve(invalid,true)
	check("incompatible_pin",failed.code == "contradiction" and failed.diagnostic.region == "left")
	check("error_has_context",failed.diagnostic.seed_text == "0" and failed.diagnostic.algorithm_revision == Document.REVISION and failed.diagnostic.has("budget"))
	check("no_partial_proposal",not failed.has("proposal") and not failed.has("package"))
	corpus.append({"case":"pin_conflict","request_hash":Document.hash_source(invalid),"wfc":{"ok":failed.ok,"code":failed.code},"assembler":{"ok":Adapter.build(invalid).ok,"code":Adapter.build(invalid).code}})
	invalid = source.duplicate(true); invalid.selection = ["left"]
	var frozen := Solver.new().solve(invalid,true)
	check("outside_selection_exact",frozen.ok and frozen.proposal.instances == source.map.instances)
	invalid = source.duplicate(true); invalid.pins = ["left","right"]
	check("all_pinned",Solver.new().solve(invalid,true).diff.is_empty())
	invalid = source.duplicate(true); invalid.quotas = [{"piece_hash":source.map.pieces[2].piece_hash,"min":1,"max":1}]
	var forced := Solver.new().solve(invalid,true)
	check("quota_forces_variant",forced.ok and forced.proposal.instances[1].piece_hash == source.map.pieces[2].piece_hash)
	invalid.quotas[0].min = 2; invalid.quotas[0].max = 2
	check("impossible_quota",Solver.new().solve(invalid,true).code == "contradiction")
	corpus.append({"case":"impossible_quota","request_hash":Document.hash_source(invalid),"wfc":{"code":Solver.new().solve(invalid,true).code},"assembler":{"code":Adapter.build(invalid).code}})
	invalid = source.duplicate(true); invalid.min_diversity = 2
	check("diversity",Solver.new().solve(invalid,true).ok)
	invalid.min_diversity = 3; check("diversity_limit",not Document.validate(invalid).ok)
	invalid = source.duplicate(true); invalid.budget.operations = 1
	failed = Solver.new().solve(invalid,true); check("global_budget",failed.code == "budget_exhausted" and failed.diagnostic.operations == 1 and not failed.has("package"))
	failed = Solver.new().solve(source,true,func(_progress: float) -> bool: return true)
	check("cancel_no_output",failed.code == "cancelled" and not failed.has("proposal"))
	var adverse := with_bad_candidate(); var adverse_result := Solver.new().solve(adverse,true)
	check("global_validation_backtracks",adverse_result.ok and adverse_result.diagnostic.backtracks > 0 and adverse_result.diagnostic.validations > 1)
	invalid = adverse.duplicate(true); invalid.budget.backtracks = 0
	check("backtrack_budget",Solver.new().solve(invalid,true).code == "budget_exhausted")
	invalid = adverse.duplicate(true); invalid.budget.validations = 1
	check("validation_budget",Solver.new().solve(invalid,true).code == "budget_exhausted")
	invalid = adverse.duplicate(true); invalid.domains[1].options.remove_at(0)
	failed = Solver.new().solve(invalid,true)
	check("global_reject_not_local_success",failed.code == "contradiction" and failed.diagnostic.rule == "opening_unlinked" and not failed.has("proposal"))
	invalid = source.duplicate(true); invalid.domains[1].options[0].rotation_quarters = 2; invalid.domains[1].options.remove_at(1)
	failed = Solver.new().solve(invalid,true)
	check("connector_rotation_contradiction",failed.code == "contradiction" and failed.diagnostic.rule == "door")
	var session := Session.new(); session.replace(source.map)
	check("apply_one_action",Solver.apply_proposal(forced,session).ok and session.data.instances[1].piece_hash == source.map.pieces[2].piece_hash)
	check("undo_map",session.undo() and Map.hash_source(session.data) == Map.hash_source(source.map))
	check("redo_map",session.redo() and session.data.instances[1].piece_hash == source.map.pieces[2].piece_hash)
	check("stale_apply",Solver.apply_proposal(result,session).code == "stale_source")
	check("failure_not_applied",not Solver.apply_proposal(failed,session).ok)
	var tampered := forced.duplicate(true); tampered.proposal.instances[0].position_xyz[0] = 1
	session.undo(); check("tampered_proposal_rejected",Solver.apply_proposal(tampered,session).code == "generation_invalid")
	var job := Solver.new(); job.start(source,true)
	while not job.ready(): await process_frame
	check("stale_worker",job.take("different").code == "stale_source")
	job = Solver.new(); job.start(source,true); job.cancel()
	while not job.ready(): await process_frame
	check("cancel_worker",job.take(original).code == "cancelled")
	var directory := ProjectSettings.globalize_path("res://.godot/m6_samples"); DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("generation.json")
	check("save",Store.save_source(path,source,IO.disk_hash(path)).ok)
	var loaded := Store.load_source(path)
	check("roundtrip",loaded.ok and loaded.output_hash == original and Solver.new().solve(loaded.data,true).output_hash == result.output_hash)
	check("conflict_preserves",Store.save_source(path,invalid,"wrong").code == "io_conflict" and Store.load_source(path).output_hash == original)
	IO._write(path+".pending","interrupted".to_utf8_buffer())
	check("pending_preserved",Store.save_source(path,source,IO.disk_hash(path)).code == "io_recovery_pending")
	DirAccess.remove_absolute(path+".pending")
	check("duplicate_json_rejected",not Document.read('{"schema_version":1,"schema_version":1}'.to_utf8_buffer()).ok)
	invalid = source.duplicate(true); invalid.map.links.clear()
	check("assembler_unsupported",Adapter.build(invalid).code == "assembler_unsupported")
	invalid = source.duplicate(true); invalid.map.instances[1].position_xyz[0] = 999
	var baseline := Adapter.build(invalid)
	check("assembler_preserves_authoring_or_fails",baseline.code == "assembler_constraint" and not baseline.has("proposal"))
	corpus.append({"case":"authored_position_999","request_hash":Document.hash_source(invalid),"assembler":{"ok":baseline.ok,"code":baseline.code},"wfc":{"code":Solver.new().solve(invalid,true).code}})
	var evidence := OS.get_environment("M6_EVIDENCE")
	if not evidence.is_empty():
		IO._write(evidence.path_join("comparison.json"),JSON.stringify(corpus,"\t",true,true).to_utf8_buffer())
		IO._write(evidence.path_join("generation.json"),JSON.stringify(source,"\t",true,true).to_utf8_buffer())
	finish(result.output_hash)
func finish(hash_value: String = "") -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M6_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"package_hash":hash_value})); quit(0 if ok else 1)
