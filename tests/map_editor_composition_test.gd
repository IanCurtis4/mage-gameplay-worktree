extends SceneTree
const Document = preload("res://scripts/map_authoring/composition/map_document.gd")
const Session = preload("res://scripts/map_authoring/composition/map_session.gd")
const Compiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Store = preload("res://scripts/map_authoring/composition/map_store.gd")
const IO = preload("res://scripts/map_authoring/io/source_store.gd")
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const TerrainPanel = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
var checks: Array = []
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("M3_CHECK "+id+" "+str(ok))
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	# These legacy obstruction oracles intentionally use the technical24 door.
	# The human sample80 is covered by the actual Editor/CLI player tests.
	var source := Document.sample()
	for index: int in source.pieces.size():
		for port: Dictionary in source.pieces[index].source.connectors: port.width = 24
		rehash(source,index)
	var original := Document.hash_source(source)
	var tick := Time.get_ticks_usec(); var built := Compiler.compile(source); var elapsed := (Time.get_ticks_usec()-tick)/1000.0
	check("two_piece_compile",built.ok)
	if not built.ok: print(built); finish(); return
	var package: Dictionary = built.package
	check("authorship_unchanged",Document.hash_source(source) == original)
	check("exact_authored_transforms",package.realized_instances[1].position_xyz == [100,0,0])
	check("two_authored_pieces_two_supports",package.piece_count == 2 and package.manifest.stages[0].surfaces.size() == 2)
	check("package_integrity",Compiler.validate_package(package))
	check("deterministic",Compiler.compile(source).output_hash == built.output_hash)
	var reordered := source.duplicate(true); reordered.pieces.reverse(); reordered.instances.reverse()
	check("order_independent_identity",Compiler.compile(reordered).output_hash == built.output_hash)
	var world := WorldGeometry.new(); check("canonical_world",world.configure(Compiler.manifest(package),"map_preview").ok)
	var cells: Array = package.manifest.stages[0].surfaces
	var start := ExpeditionWorldPoint.create("map_preview",cells[0].surface_id,Vector3(20,0,50))
	var destination := ExpeditionWorldPoint.create("map_preview",cells[1].surface_id,Vector3(180,0,50))
	check("seam_route",world.path(start,destination,package.profile,world.geometry_revision).ok)
	var actor := WorldActorMotion.new(); check("actor_bind",actor.configure(world,start,package.profile,"fixture_actor").ok)
	check("actor_plan",actor.plan(destination,world.geometry_revision).ok)
	var arrived := false; var crossed := false; var continuous := true; var previous := actor.point().position
	for i: int in 100:
		var step := actor.advance(3)
		if not step.ok: continuous = false; break
		if actor.point().position.distance_to(previous) > 3.001: continuous = false
		if actor.point().position.x >= 100: crossed = true
		previous = actor.point().position
		if step.data.arrived: arrived = true; break
	check("continuous_actor_crosses_seam",continuous and crossed and arrived and actor.point().position == destination.position)
	actor.release()
	# Six exterior edges plus two closed spans of the shared edge; unique owner.
	check("wall_matches_manifest",package.barriers.size() == 8 and package.manifest.stages[0].volumes.size() == 8)
	check("closed_edge_blocks_sweep",world.sweep(Vector3(20,0,50),Vector3(20,0,-10),package.profile,world.geometry_revision).data.hit)
	check("seam_closed_outside_opening",world.sweep(Vector3(80,0,20),Vector3(120,0,20),package.profile,world.geometry_revision).data.hit)
	check("seam_opening_free",not world.sweep(Vector3(80,0,50),Vector3(120,0,50),package.profile,world.geometry_revision).data.hit)
	var attack_from := ExpeditionWorldPoint.create("map_preview",cells[0].surface_id,Vector3(80,0,20))
	var attack_to := ExpeditionWorldPoint.create("map_preview",cells[1].surface_id,Vector3(120,0,20))
	check("wall_blocks_los",not world.query_attack({"geometry_rule_id":&"direct_volume","range":100.0},attack_from,attack_to,world.geometry_revision).data.los_ok)
	var invalid := source.duplicate(true); invalid.instances[1].position_xyz[0] = 101
	check("misaligned_seam_rejected",Compiler.compile(invalid).code == "seam_position")
	invalid = source.duplicate(true); invalid.instances[1].position_xyz[0] = 50
	check("overlap_rejected",Compiler.compile(invalid).code == "geometry_overlap")
	invalid = source.duplicate(true); invalid.links.clear()
	check("unlinked_opening_rejected",Compiler.compile(invalid).code == "opening_unlinked")
	invalid = source.duplicate(true); invalid.links[0].b_connector = "absent"
	check("broken_reference_rejected",Compiler.compile(invalid).code == "connector_missing")
	invalid = source.duplicate(true); invalid.links.append(invalid.links[0].duplicate()); invalid.links[1].link_id = "duplicate_use"
	check("connector_single_owner",Compiler.compile(invalid).code == "connector_reused")
	invalid = source.duplicate(true); invalid.instances[1].rotation_quarters = 1
	check("rotated_wrong_opening_rejected",not Compiler.compile(invalid).ok)
	invalid = source.duplicate(true); invalid.instances[1].position_xyz[1] = 5
	check("no_vertical_repair",Compiler.compile(invalid).code == "transform_unsupported")
	invalid = source.duplicate(true); invalid.instances[1].position_xyz[0] = NAN
	check("nonfinite_rejected",not Compiler.compile(invalid).ok)
	invalid = source.duplicate(true); invalid.instances[0].instance_id = "right"
	check("duplicate_id_rejected",Compiler.compile(invalid).code == "duplicate_instance")
	invalid = source.duplicate(true); invalid.barrier_profile = "forest"
	check("missing_biome_profile_rejected",Compiler.compile(invalid).code == "profile_missing")
	invalid = source.duplicate(true); invalid.pieces[0].source.revision = 2
	check("immutable_piece_reference",Compiler.compile(invalid).code == "piece_hash_mismatch")
	invalid = source.duplicate(true); invalid.extra = "unknown"
	check("unknown_fields_rejected",not Compiler.compile(invalid).ok)
	invalid = source.duplicate(true); invalid.schema_version = 2
	check("unknown_version_rejected",Compiler.compile(invalid).code == "map_version_unsupported")
	var changed := source.duplicate(true)
	changed.pieces[1].source.connectors[0].width = 20; rehash(changed,1)
	check("width_mismatch_rejected",Compiler.compile(changed).code == "seam_dimensions")
	changed = source.duplicate(true); changed.pieces[1].source.layers[0].heights = [10,10,10,10]; changed.pieces[1].source.connectors[0].position_xyz[1] = 10; rehash(changed,1)
	check("height_mismatch_rejected",Compiler.compile(changed).code == "seam_position")
	changed = source.duplicate(true); changed.pieces[0].source.connectors[0].direction = "out"; changed.pieces[1].source.connectors[0].direction = "out"; rehash(changed,0); rehash(changed,1)
	check("direction_mismatch_rejected",Compiler.compile(changed).code == "seam_direction")
	changed = source.duplicate(true); changed.pieces[1].source.connectors[0].tags = ["forest"]; rehash(changed,1)
	check("tag_mismatch_rejected",Compiler.compile(changed).code == "seam_tags")
	var recipe := source.duplicate(true); recipe.mode = "recipe"; recipe.instances[1].position_xyz = [999,0,999]
	var realized := Compiler.compile(recipe)
	check("recipe_realizes_explicit_tree",realized.ok and Compiler._vector(realized.package.realized_instances[1].position_xyz) == Vector3(100,0,0))
	check("recipe_does_not_mutate_draft",recipe.instances[1].position_xyz == [999,0,999])
	check("recipe_deterministic",Compiler.compile(recipe).output_hash == realized.output_hash)
	recipe.links.clear(); check("recipe_disconnected_rejected",Compiler.compile(recipe).code == "recipe_tree")
	var rotated := source.duplicate(true)
	rotated.instances[0].rotation_quarters = 1; rotated.instances[1].rotation_quarters = 1; rotated.instances[1].position_xyz = [0,0,100]
	check("quarter_rotation_preserves_seam",Compiler.compile(rotated).ok)
	# A 200x200 piece shares only half its boundary with a 100x100 room.
	var varied := source.duplicate(true)
	var layer: Dictionary = varied.pieces[0].source.layers[0]
	layer.columns = 3; layer.rows = 3; layer.heights = [0,0,0,0,0,0,0,0,0]
	varied.pieces[0].source.connectors[0].position_xyz[0] = 200
	varied.instances[1].position_xyz[0] = 200; rehash(varied,0)
	var uneven := Compiler.compile(varied)
	check("different_piece_dimensions",uneven.ok and uneven.package.piece_count == 2)
	var duplicate_span := false
	if uneven.ok:
		var walls: Array = uneven.package.barriers
		for i: int in walls.size():
			for j: int in i:
				var va: AABB = walls[i].volume; var vb: AABB = walls[j].volume
				if is_equal_approx(va.position.x,199) and is_equal_approx(vb.position.x,199) and va.intersects(vb): duplicate_span = true
	check("partial_shared_boundary_single_owner",uneven.ok and not duplicate_span)
	var session := Session.new(); session.replace(source); changed = source.duplicate(true); changed.instances[1].position_xyz[0] = 150
	check("placement_edit_atomic",session.apply(changed).ok)
	check("undo_placements_links",session.undo() and Document.hash_source(session.data) == original)
	check("redo_placements_links",session.redo() and session.data.links == source.links and session.data.instances[1].position_xyz[0] == 150)
	var before := Document.hash_source(session.data)
	check("invalid_edit_no_mutation",not session.apply(invalid).ok and Document.hash_source(session.data) == before)
	var root_path := ProjectSettings.globalize_path("res://.godot/m3_"+Crypto.new().generate_random_bytes(5).hex_encode()); DirAccess.make_dir_recursive_absolute(root_path)
	var source_path := root_path.path_join("map.json")
	check("save_composition",Store.save_source(source_path,source,"").ok)
	var loaded := Store.load_source(source_path)
	check("reopen_exact_placements_links",loaded.ok and loaded.data == source)
	check("reopen_same_package",Compiler.compile(loaded.data).output_hash == built.output_hash)
	check("writer_conflict_preserves_source",Store.save_source(source_path,changed,"").code == "io_conflict" and Store.load_source(source_path).data == source)
	check("duplicate_json_key_rejected",not Document.read('{"schema_version":1,"schema_version":1}'.to_utf8_buffer()).ok)
	var published := Store.publish(root_path,package,original)
	check("local_immutable_publish",published.ok)
	check("published_package_readable",published.ok and Store.load_package(published.path).package == package)
	check("idempotent_publication",Store.publish(root_path,package,original).ok)
	check("stale_publication_rejected",Store.publish(root_path,package,"wrong").code == "stale_source")
	var corrupt := package.duplicate(true); corrupt.realized_instances[0].position_xyz[0] = 1
	check("tampered_package_rejected",not Compiler.validate_package(corrupt))
	check("tampered_publication_rejected",not Store.publish(root_path,corrupt,original).ok)
	IO._write(published.path,"broken".to_utf8_buffer())
	check("corrupted_file_no_overwrite",Store.publish(root_path,package,original).code == "immutable_conflict")
	check("cancellation_no_package",Compiler.compile(source,func(_p: float) -> bool: return true).code == "cancelled")
	var job := Compiler.new(); job.start(source)
	while not job.ready(): await process_frame
	check("stale_worker_no_package",job.take("changed").code == "stale_source")
	job = Compiler.new(); job.start(source); job.cancel()
	while not job.ready(): await process_frame
	check("cancelled_worker_no_package",job.take(original).code == "cancelled")
	# The multi-support fixture must retain F2's actual internal graph.
	var single := Document.empty("bridge_map"); var piece := TerrainPanel.sample_source(Piece.empty("bridge")); var h := Schema.semantic_hash(piece)
	single.pieces = [{"piece_hash":h,"source":piece}]; single.instances = [{"instance_id":"bridge","piece_hash":h,"position_xyz":[0,0,0],"rotation_quarters":0}]
	var bridge := Compiler.compile(single)
	check("f2_internal_adjacency_consumed",bridge.ok and bridge.package.manifest.stages[0].surfaces.size() == 4 and bridge.package.manifest.stages[0].connections.size() == 3)
	# An authored field remains one piece even with 4096 grid quads.
	var field := TerrainPanel.large_sample_source(Piece.empty("field")); field.connectors = []
	var room: Dictionary = source.pieces[0].source.duplicate(true); room.connectors[0].position_xyz = [100,0,50]; room.connectors[0].tags = ["map_editor"]
	field.connectors = [{"connector_id":"west","kind":"walk","surface_id":"field","position_xyz":[0,0,3500],"normal_xyz":[-1,0,0],"width":24,"headroom":100,"tags":["map_editor"],"direction":"both"}]
	var large := Document.empty("field_and_room"); var fh := Schema.semantic_hash(field); var rh := Schema.semantic_hash(room)
	large.pieces = [{"piece_hash":fh,"source":field},{"piece_hash":rh,"source":room}]
	large.instances = [{"instance_id":"field","piece_hash":fh,"position_xyz":[0,0,0],"rotation_quarters":0},{"instance_id":"room","piece_hash":rh,"position_xyz":[-100,0,3450],"rotation_quarters":0}]
	large.links = [{"link_id":"gate","a_instance":"field","a_connector":"west","b_instance":"room","b_connector":"east"}]
	tick = Time.get_ticks_usec(); var large_built := Compiler.compile(large); var large_elapsed := (Time.get_ticks_usec()-tick)/1000.0
	if not large_built.ok: print("M3_LARGE_DIAGNOSTIC "+JSON.stringify(large_built))
	check("large_field_plus_small_room",large_built.ok and large_built.package.piece_count == 2 and large_built.package.manifest.stages[0].surfaces.size() == 4)
	var large_read := Document.read(JSON.stringify(large,"",true,true).to_utf8_buffer())
	if not large_read.ok: print("M3_LARGE_READ_DIAGNOSTIC "+JSON.stringify(large_read))
	check("large_source_roundtrip",large_read.output_hash == Document.hash_source(large))
	var info := {"source_path":source_path,"package_hash":built.output_hash,"compile_ms":elapsed,"package_bytes":var_to_bytes(package).size(),"piece_count":2,"large_compile_ms":large_elapsed,"large_package_bytes":var_to_bytes(large_built.get("package",{})).size()}
	finish(info)
func rehash(source: Dictionary,index: int) -> void:
	var old: String = source.pieces[index].piece_hash; var updated := Schema.semantic_hash(source.pieces[index].source); source.pieces[index].piece_hash = updated
	for instance: Dictionary in source.instances:
		if instance.piece_hash == old: instance.piece_hash = updated
func finish(info: Dictionary = {}) -> void:
	var ok := true
	for item: Dictionary in checks:
		if not item.ok: ok = false
	info.merge({"ok":ok,"count":checks.size(),"checks":checks}); print("M3_RESULT "+JSON.stringify(info)); quit(0 if ok else 1)
