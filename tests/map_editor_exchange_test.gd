@tool
extends SceneTree
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const PatrolFixture = preload("res://tests/map_editor_patrol_test.gd")
const Generation = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Session = preload("res://scripts/map_authoring/composition/map_session.gd")
var checks: Array = []
var package_hash := ""
func _initialize() -> void: run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M7_CHECK "+id+" "+str(value))
static func rehash(bundle: Dictionary) -> Dictionary:
	for file: Dictionary in bundle.files: file.sha256 = Exchange.digest(file.data)
	bundle.ticket_hash = Exchange.digest(bundle.ticket)
	bundle.erase("bundle_hash"); bundle.bundle_hash = Exchange.digest(bundle); return bundle
func run() -> void:
	var patrol := PatrolFixture.fixture()
	var sources := {"piece":Map.sample().pieces[0].source,"map":Map.sample(),"population":patrol.population[0],"patrol":patrol,"generation":Generation.from_map(Map.sample())}
	var root := ProjectSettings.globalize_path("res://.godot/m7_samples"); DirAccess.make_dir_recursive_absolute(root)
	for kind: String in sources:
		var source: Dictionary = sources[kind]; var original := Exchange.digest(source)
		var allowed := ["name"] if kind != "generation" else ["seed_text"]
		if kind == "population": allowed.append("plan_hash")
		var exported := Exchange.export_bundle(kind,source,Exchange.policy(allowed),"Alteração autorizada",["0","-1","9223372036854775807","-9223372036854775808"])
		check(kind+"_export",exported.ok)
		if not exported.ok: print(exported); finish(); return
		check(kind+"_safe_roundtrip",Exchange.validate_bundle(exported.bundle).ok)
		var candidate := source.duplicate(true)
		if kind == "generation": candidate.seed_text = "-9223372036854775808"
		else: candidate.name = "Nome revisado"
		if kind == "population": candidate.plan_hash = Exchange.Population.recipe_hash(candidate)
		var proposed := Exchange.propose(exported.bundle,candidate)
		check(kind+"_propose",proposed.ok)
		if not proposed.ok: print(proposed); finish(); return
		var prepared := Exchange.prepare(exported.bundle,proposed.bundle,source)
		check(kind+"_prepare",prepared.ok and not prepared.diff.is_empty())
		check(kind+"_authority_hash",prepared.output_hash == Exchange.build(kind,prepared.source).output_hash)
		check(kind+"_no_input_mutation",Exchange.digest(source) == original)
		check(kind+"_idempotent",Exchange.prepare(exported.bundle,proposed.bundle,prepared.source).already_applied)
		check(kind+"_io_request",save_sample(root.path_join(kind+".rpx"),exported.bundle).ok)
		check(kind+"_io_proposal",save_sample(root.path_join(kind+"_proposal.rpx"),proposed.bundle).ok)
		check(kind+"_io_source",save_sample(root.path_join(kind+".json"),source).ok)
		check(kind+"_io_candidate",save_sample(root.path_join(kind+"_candidate.json"),candidate).ok)
		check(kind+"_disk_roundtrip",Exchange.validate_bundle(Exchange.load_json(root.path_join(kind+".rpx")).data).ok)
		if kind == "map": package_hash = prepared.output_hash
	var source: Dictionary = sources.map
	var request: Dictionary = Exchange.load_json(root.path_join("map.rpx")).data
	var proposal: Dictionary = Exchange.load_json(root.path_join("map_proposal.rpx")).data
	var session := Session.new(); session.replace(source); var before := Map.hash_source(source)
	var result := Exchange.apply_to(request,proposal,session.data,session.apply)
	check("atomic_apply",result.ok and session.data.name == "Nome revisado")
	check("undo_preserves_authorship",session.undo() and Map.hash_source(session.data) == before)
	check("redo",session.redo() and session.data.name == "Nome revisado")
	check("reapply_noop",Exchange.apply_to(request,proposal,session.data,session.apply).already_applied and session._undo.size() == 1)
	var divergent := source.duplicate(true); divergent.name = "Mudança humana"
	check("base_diverged",Exchange.prepare(request,proposal,divergent).code == "base_diverged")
	var candidate := source.duplicate(true); candidate.mode = "recipe"
	check("section_denied",Exchange.propose(request,candidate).code == "exchange_section_denied")
	var altered := proposal.duplicate(true); altered.ticket.policy.sections.append("mode"); altered = rehash(altered)
	check("untrusted_permissions",Exchange.prepare(request,altered,source).code == "exchange_permission_mismatch")
	altered = proposal.duplicate(true); altered.ticket.base_hash = "a".repeat(64); altered = rehash(altered)
	check("base_integrity",not Exchange.validate_bundle(altered).ok)
	altered = proposal.duplicate(true); altered.files[0].data.name = "Adulterado"
	check("file_integrity",Exchange.validate_bundle(altered).code == "exchange_file_hash")
	altered = proposal.duplicate(true); altered.bundle_hash = "a".repeat(64)
	check("bundle_integrity",Exchange.validate_bundle(altered).code == "exchange_hash")
	for path: String in ["../source.json","C:/source.json","/tmp/source.json","source.gd","scene.tscn","assets/evil.svg","https://example.com/x","a\\b.json"]:
		altered = proposal.duplicate(true); altered.files[0].path = path; altered = rehash(altered)
		check("unsafe_path_"+path,Exchange.validate_bundle(altered).code == "unsafe_bundle_path")
	altered = proposal.duplicate(true); altered.files[1].path = "source.json"; altered = rehash(altered)
	check("duplicate_file",Exchange.validate_bundle(altered).code == "exchange_duplicate_file")
	altered = proposal.duplicate(true); altered.files[1].data.compiled_hash = "f".repeat(64); altered = rehash(altered)
	check("compiled_integrity",Exchange.prepare(request,altered,source).code == "exchange_compiled_hash")
	altered = proposal.duplicate(true); altered.files[0].data.instances.append(altered.files[0].data.instances[0]); altered = rehash(altered)
	check("duplicate_identity",not Exchange.validate_bundle(altered).ok)
	altered = proposal.duplicate(true); altered.exchange_version = 9; altered = rehash(altered)
	check("unknown_version",Exchange.validate_bundle(altered).code == "exchange_version")
	check("duplicate_json_key",not Exchange.Reader.new().decode('{"x":1,"x":2}'.to_utf8_buffer()).ok)
	check("truncated_json",not Exchange.Reader.new().decode('{"x":'.to_utf8_buffer()).ok)
	check("size_limit",not Exchange.Reader.new().decode(" ".repeat(Exchange.Reader.MAX_BYTES+1).to_utf8_buffer()).ok)
	check("depth_limit",not Exchange.Reader.new().decode(("[".repeat(40)+"0"+"]".repeat(40)).to_utf8_buffer()).ok)
	check("unknown_source_field",not Exchange.read("map",dict(source,"script","evil.gd")).ok)
	check("io_conflict",Exchange.save_json(root.path_join("map.rpx"),request).code == "io_conflict")
	Exchange.IO._write(root.path_join("blocked.rpx.pending"),"{}".to_utf8_buffer())
	check("pending_preserved",Exchange.save_json(root.path_join("blocked.rpx"),request).code == "io_recovery_pending")
	check("pending_intact",FileAccess.get_file_as_string(root.path_join("blocked.rpx.pending")) == "{}")
	candidate = source.duplicate(true); candidate.instances[0].position_xyz[0] = -1
	var restricted := Exchange.export_bundle("map",source,Exchange.policy(["instances"],["right"]),"IDs restritos")
	check("ids_denied",Exchange.propose(restricted.bundle,candidate).code == "exchange_id_denied")
	check("semantic_entity_diff",Exchange.diff(source,candidate)[0].entity_id == "left" and Exchange.diff(source,candidate)[0].path == "/instances/@left/position_xyz")
	restricted = Exchange.export_bundle("map",source,Exchange.policy(["name","revision"],[],[],1),"Limite")
	candidate = source.duplicate(true); candidate.name = "Novo"; candidate.revision = 2
	check("change_budget",Exchange.propose(restricted.bundle,candidate).code == "exchange_budget")
	restricted = Exchange.export_bundle("map",source,Exchange.policy(["instances"],[],["/instances/@left"]),"Protegido")
	candidate = source.duplicate(true); candidate.instances[0].position_xyz[0] = -1
	check("protected_path",Exchange.propose(restricted.bundle,candidate).code == "exchange_protected")
	var piece: Dictionary = sources.piece.duplicate(true); piece.layers[0].locked = true
	restricted = Exchange.export_bundle("piece",piece,Exchange.policy(["layers"]),"Camada travada")
	candidate = piece.duplicate(true); candidate.layers[0].locked = false
	check("locked_layer",Exchange.propose(restricted.bundle,candidate).code == "exchange_protected")
	var fixed: Dictionary = sources.population.duplicate(true); candidate = fixed.duplicate(true); candidate.slots[0].position_xyz[0] += 5
	restricted = Exchange.export_bundle("population",fixed,Exchange.policy(["slots"]),"Slot fixado")
	check("fixed_slot",Exchange.propose(restricted.bundle,candidate).code == "exchange_protected")
	var generation: Dictionary = sources.generation.duplicate(true); generation.pins = ["left"]
	restricted = Exchange.export_bundle("generation",generation,Exchange.policy(["pins"]),"Pin")
	candidate = generation.duplicate(true); candidate.pins = []
	check("pinned_region",Exchange.propose(restricted.bundle,candidate).code == "exchange_protected")
	piece = sources.piece.duplicate(true); piece.layers[0].material_masks = {"missing":[1,1,1,1]}
	check("missing_asset",not Exchange.export_bundle("piece",piece,Exchange.policy(["name"]),"Asset ausente").ok)
	var snapshot := Exchange.digest(session.data)
	check("invalid_apply_no_mutation",not Exchange.apply_to(request,altered,session.data,session.apply).ok and Exchange.digest(session.data) == snapshot)
	check("new_identity_denied",Exchange.propose(request,dict(source,"document_id","other")).code == "exchange_identity")
	check("policy_invalid",not Exchange.export_bundle("map",source,Exchange.policy(["name"],[],[],0),"Budget inválido").ok)
	check("not_request",Exchange.propose(proposal,source).code == "exchange_not_request")
	# Real terrain and route changes, not only metadata roundtrips.
	piece = sources.piece.duplicate(true)
	restricted = Exchange.export_bundle("piece",piece,Exchange.policy(["layers"],["floor"]),"Pintar material existente")
	candidate = piece.duplicate(true); candidate.layers[0].material_masks = {"earth":[1,1,1,1]}
	var painted := Exchange.propose(restricted.bundle,candidate)
	check("material_proposal",painted.ok)
	if painted.ok:
		var piece_session := preload("res://scripts/map_authoring/document/document_session.gd").new(); piece_session.replace(piece)
		var applied := Exchange.apply_to(restricted.bundle,painted.bundle,piece_session.document().to_data(),piece_session.apply)
		check("piece_revision_matches_session",applied.ok and piece_session.document().semantic_hash() == painted.bundle.source_hash)
		check("piece_package_matches_preview",Exchange.build("piece",piece_session.document().to_data()).output_hash == painted.output_hash)
		check("piece_undo",piece_session.undo() and piece_session.document().semantic_hash() == Exchange.read("piece",piece).output_hash)
	candidate = sources.patrol.duplicate(true); candidate.patrols[0].waypoints[0].wait_seconds = 3.0
	restricted = Exchange.export_bundle("patrol",sources.patrol,Exchange.policy(["patrols"],["guard_route"]),"Alterar espera")
	var route_proposal := Exchange.propose(restricted.bundle,candidate)
	check("route_wait_proposal",route_proposal.ok)
	if route_proposal.ok: check("route_wait_compiled",Exchange.prepare(restricted.bundle,route_proposal.bundle,sources.patrol).source.patrols[0].waypoints[0].wait_seconds == 3.0)
	piece = sources.piece.duplicate(true)
	piece.regions = [{"region_id":"protected","layer_id":"floor","polygon_xz":[[0,0],[10,0],[0,10]],"purpose":"fixed"}]; piece.layers[0].protected_regions = ["protected"]
	restricted = Exchange.export_bundle("piece",piece,Exchange.policy(["regions"]),"Região protegida")
	check("protected_region_exports",restricted.ok)
	if restricted.ok:
		candidate = piece.duplicate(true); candidate.regions[0].polygon_xz[1] = [20,0]
		check("protected_region_geometry",Exchange.propose(restricted.bundle,candidate).code == "exchange_protected")
	candidate = source.duplicate(true); candidate.instances[0].position_xyz[0] = -10
	restricted = Exchange.export_bundle("map",source,Exchange.policy(["instances"]),"Emenda inválida")
	check("broken_seam_not_importable",not Exchange.propose(restricted.bundle,candidate).ok)
	var reordered := source.duplicate(true); reordered.instances.reverse()
	check("semantic_diff_stable_ids",Exchange.diff(source,reordered).is_empty())
	check("cancelled_export",Exchange.export_bundle("map",source,Exchange.policy(["name"]),"Cancelar",[],func(_progress: float = 0.0) -> bool: return true).code == "cancelled")
	finish()
static func save_sample(path: String, value: Dictionary) -> Dictionary: return Exchange.save_json(path,value,Exchange.IO.disk_hash(path))
static func dict(data: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := data.duplicate(true); copy[key] = value; return copy
func finish() -> void:
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M7_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"package_hash":package_hash})); quit(0 if ok else 1)
