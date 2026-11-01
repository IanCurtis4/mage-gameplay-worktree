extends SceneTree
## Checkpoint46 (F9-05, P3d): receipts and replay of regional variations. A
## receipt at the root (never nested, never the source), no self-referencing
## hash, old sources unchanged, replay from the passive ledger or from a bundle,
## later human edits and changed dependencies reported, bounded retention.
const Synthesis = preload("res://scripts/map_authoring/synthesis/regional_synthesis.gd")
const Root = preload("res://scripts/map_authoring/synthesis/root_synthesis.gd")
const Receipts = preload("res://scripts/map_authoring/synthesis/receipts.gd")
const Shape = preload("res://scripts/map_authoring/synthesis/receipt_schema.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Session = preload("res://scripts/map_authoring/document/document_session.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const PopulationSession = preload("res://scripts/map_authoring/population/population_session.gd")
const Rooms = preload("res://tests/map_editor_root_synthesis_test.gd")
const SELECTION := [[384,352],[1152,352],[1152,992],[384,992]]
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_RECEIPT_CHECK "+id+" "+str(ok))
func request_for(source: Dictionary, seed: String = "17") -> Dictionary:
	return {"algorithm_revision":Synthesis.REVISION,"seed_text":seed,"base_hash":Schema.semantic_hash(source),"target":{"layer_id":"a_ground"},"selection":{"polygon_xz":SELECTION},"channels":{"terrain":{"mode":"relief","amplitude":48.0,"feature_size":256.0,"roughness":0.5,"falloff":96.0},"materials":{"mode":"preserve"},"objects":{"mode":"preserve"}},"preserve":{"entity_ids":[],"region_ids":[]}}
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var base: Dictionary = Schema.read(FileAccess.get_file_as_bytes("res://data/map_authoring/sanctuary_woods_clearing.source.json")).data
	# 1. Old sources keep their hash: the Bosque map still names this exact piece.
	var bosque: Dictionary = MapDocument.read(FileAccess.get_file_as_bytes("res://data/map_authoring/sanctuary_woods.map.json")).data
	var named := false
	for piece: Dictionary in bosque.pieces:
		if piece.piece_hash == Schema.semantic_hash(base): named = true
	check("old_sources_keep_their_hash",named and not base.has(Receipts.KEY) and not bosque.has(Receipts.KEY))
	# 2. One receipt at the root; no source inside; no self-reference.
	var request := request_for(base)
	var proposal := Synthesis.prepare(base,request)
	var receipt: Dictionary = proposal.source.get(Receipts.KEY,[{}])[0] if proposal.ok else {}
	var carried: bool = proposal.ok and proposal.source[Receipts.KEY].size() == 1 and Shape.valid_receipt(receipt) and receipt.request == request and receipt.request_hash == Schema.semantic_hash(request) and receipt.base_hash == request.base_hash
	carried = carried and receipt.result_content_hash == Receipts.content_hash("piece",proposal.source) and proposal.source_hash == Schema.semantic_hash(proposal.source) and receipt.result_content_hash != proposal.source_hash and not JSON.stringify(receipt).contains("heights")
	check("proposal_carries_one_receipt_without_source",carried and receipt.summary.terrain_samples == proposal.diff.terrain_samples.size())
	var again := Synthesis.prepare(base,request)
	check("receipt_is_deterministic",again.ok and again.source_hash == proposal.source_hash)
	# 3. Closed shape, root only, bounded.
	var extra: Dictionary = proposal.source.duplicate(true); extra[Receipts.KEY][0]["note"] = "x"
	var many: Dictionary = proposal.source.duplicate(true)
	for i: int in Shape.MAX: many[Receipts.KEY].append(receipt.duplicate(true))
	var nested_map: Dictionary = bosque.duplicate(true); nested_map.pieces[0].source[Receipts.KEY] = [receipt]
	check("receipts_are_closed_and_root_only",not Schema.read(JSON.stringify(extra).to_utf8_buffer()).valid and not Schema.read(JSON.stringify(many).to_utf8_buffer()).valid and MapDocument.validate(nested_map).code == "receipts_nested" and Schema.read(JSON.stringify(proposal.source).to_utf8_buffer()).valid)
	var kept: Dictionary = proposal.source.duplicate(true)
	for i: int in Shape.MAX+3: Receipts.attach(kept,receipt.duplicate(true))
	check("retention_keeps_the_last_receipts",kept[Receipts.KEY].size() == Shape.MAX and Shape.valid(kept[Receipts.KEY]))
	# 4. Apply stores the base; replay reproduces from the ledger.
	var session := Session.new(); session.replace(base)
	var applied := Synthesis.apply(proposal,session,Schema.semantic_hash(base))
	var stored := FileAccess.file_exists(Receipts._path(request.base_hash))
	var replayed := Receipts.replay("piece",session.document().to_data(),0)
	check("apply_stores_the_base_and_replay_reproduces",applied.ok and applied.ledger and stored and replayed.ok and replayed.reproduced and replayed.current_is_result and not replayed.dependencies_changed)
	# 5. A later human edit is not rebuilt by the seed.
	var edited := session.document().to_data(); edited.name = "Clareira editada à mão"; session.apply(edited)
	var after_edit := Receipts.replay("piece",session.document().to_data(),0)
	check("later_edits_are_reported",after_edit.ok and after_edit.reproduced and not after_edit.current_is_result)
	# 6. Changed dependencies are reported.
	var drifted: Dictionary = session.document().to_data(); drifted[Receipts.KEY][0].dependencies_hash = "0".repeat(64)
	var drift := Receipts.replay("piece",drifted,0)
	check("changed_dependencies_are_reported",drift.ok and drift.dependencies_changed and drift.reproduced)
	# 7. A bundle carries the base; a missing base is a diagnostic; tampering is refused.
	var bundled := Receipts.bundle("piece",session.document().to_data(),0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Receipts._path(request.base_hash)))
	var missing := Receipts.replay("piece",session.document().to_data(),0)
	var read := Receipts.read_bundle(bundled.get("bundle",{}),"piece") if bundled.ok else {"ok":false}
	var from_bundle := Receipts.replay("piece",session.document().to_data(),0,Callable(),read.get("base",{})) if read.ok else {"ok":false}
	var tampered: Dictionary = bundled.get("bundle",{}).duplicate(true)
	if not tampered.is_empty(): tampered.base.name = "Outra base"
	check("missing_base_and_bundle",bundled.ok and missing.code == "replay_base_missing" and read.ok and from_bundle.get("reproduced",false) and not Receipts.read_bundle(tampered,"piece").ok and not Receipts.read_bundle(bundled.bundle,"map").ok)
	# 8. Roots: a population variation carries its receipt at the root and replays.
	var built := Rooms.fixture()
	var population: Dictionary = built.population
	var channels := {"terrain":Rooms.relief(),"materials":Rooms.keep(),"objects":Rooms.keep(),"encounters":Rooms.keep()}
	var root_request := Rooms.request("population",population,"west_room",built.room_hash,channels)
	var root_proposal := Root.prepare("population",population,root_request)
	var root_receipt: Dictionary = root_proposal.source.get(Receipts.KEY,[{}])[0] if root_proposal.ok else {}
	var recipe_clean: bool = root_proposal.ok and root_proposal.source.plan_hash == PopulationDocument.recipe_hash(root_proposal.source) and not root_proposal.source.map[0].has(Receipts.KEY)
	var pop_session := PopulationSession.new(); pop_session.replace(population)
	var root_applied := Root.apply(root_proposal,pop_session,PopulationDocument.hash_source(population)) if root_proposal.ok else {"ok":false}
	var root_replay := Receipts.replay("population",pop_session.data,0) if root_applied.ok else {"ok":false}
	check("root_receipt_and_replay",recipe_clean and root_receipt.get("kind","") == "population" and root_receipt.get("result_content_hash","") == Receipts.content_hash("population",root_proposal.source) and root_replay.get("reproduced",false))
	# 9. The ledger is bounded.
	for i: int in Receipts.LEDGER_FILES+2:
		var filler := base.duplicate(true); filler.name = "Livro %d" % i
		Receipts.store("piece",filler)
	var files := 0
	for name: String in DirAccess.get_files_at(ProjectSettings.globalize_path(Receipts.LEDGER)):
		if name.ends_with(".json"): files += 1
	check("ledger_is_bounded",files <= Receipts.LEDGER_FILES)
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_RECEIPT_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
