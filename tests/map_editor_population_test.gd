extends SceneTree
const Document = preload("res://scripts/map_authoring/population/population_document.gd")
const Compiler = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Catalog = preload("res://scripts/map_authoring/population/population_catalog.gd")
const Store = preload("res://scripts/map_authoring/population/population_store.gd")
const Session = preload("res://scripts/map_authoring/population/population_session.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Suite = preload("res://tests/fixtures/e07/f5/suite.gd")
var checks: Array = []
var final_hash := ""
var source_path := ""
func _initialize() -> void: _run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M4_CHECK "+id+" "+str(value))
static func fixture() -> Dictionary:
	var map := Map.sample()
	for piece: Dictionary in map.pieces:
		piece.source.layers[0].sample_spacing = 400
		for port: Dictionary in piece.source.connectors:
			port.position_xyz[0] *= 4; port.position_xyz[2] *= 4; port.width = 120
		piece.piece_hash = Schema.semantic_hash(piece.source)
	map.instances[0].piece_hash = map.pieces[0].piece_hash; map.instances[1].piece_hash = map.pieces[1].piece_hash; map.instances[1].position_xyz = [400,0,0]
	var built := MapCompiler.compile(map)
	if not built.ok: return {}
	var source := Document.empty(); source.map = [map]
	var a: String = built.package.manifest.stages[0].surfaces[0].surface_id
	var b: String = built.package.manifest.stages[0].surfaces[1].surface_id
	source.entrance = [{"surface_id":a,"position_xyz":[64,0,200]}]
	var spec := {"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1","weight":1}
	var brush := Document.brush("field",a,Vector3(240,0,200),spec); brush.radius = 112; brush.group_radius = 100; brush.quantity = 4
	var group := Document.brush("group",b,Vector3(600,0,200),spec); group.radius = 112; group.group_radius = 100; group.quantity = 3; group.mode = "concentrated"
	source.brushes = [brush,group]
	source.exclusions = [{"exclusion_id":"safe","surface_id":a,"center_xyz":[210,0,160],"radius":16}]
	source.interactions = [{"interaction_id":"finish","kind":"phase_completion","surface_id":b,"position_xyz":[736,0,320],"target_id":""},{"interaction_id":"rest","kind":"early_exit","surface_id":a,"position_xyz":[64,0,320],"target_id":""},{"interaction_id":"gate_a","kind":"portal","surface_id":a,"position_xyz":[64,0,80],"target_id":"gate_b"},{"interaction_id":"gate_b","kind":"portal","surface_id":b,"position_xyz":[736,0,80],"target_id":"gate_a"}]
	return source
func _run() -> void:
	var source := fixture(); check("fixture_two_rooms",not source.is_empty())
	if source.is_empty(): finish(); return
	var frozen := source.duplicate(true); var loaded := Catalog.load_current(); check("canonical_catalog",loaded.ok)
	var options := Catalog.options(loaded.catalog)
	check("catalog_offers_real_species_and_origins",not options.is_empty() and options.filter(func(o: Dictionary) -> bool: return o.species_id == "test_gel").size() > 0)
	check("summon_not_offered",options.filter(func(o: Dictionary) -> bool: return o.species_id == "animal_companion").is_empty())
	var original_catalog_hash: String = loaded.hash
	var planned := Compiler.regenerate(source); check("both_brushes_realize",planned.ok)
	if not planned.ok: print(planned); finish(); return
	check("no_mutation_before_apply",source == frozen and source.slots.is_empty())
	check("explicit_diff_seven_births",planned.diff.added.size() == 7 and planned.diff.removed.is_empty())
	var realized: Dictionary = planned.data
	check("deterministic_regeneration",Compiler.regenerate(source).data == realized)
	check("dispersed_and_concentrated_counts",realized.slots.filter(func(s: Dictionary) -> bool: return s.brush_id == "field").size() == 4 and realized.slots.filter(func(s: Dictionary) -> bool: return s.brush_id == "group").size() == 3)
	var built := Compiler.compile(realized); check("canonical_compilation",built.ok)
	if not built.ok: print(built); finish(); return
	final_hash = built.output_hash
	check("canonical_manifest_seven_slots",built.package.manifest.population.slots.size() == 7)
	check("canonical_interaction_records",built.package.manifest.portals.size() == 2 and built.package.manifest.objectives.size() == 2)
	check("repeated_compile_same_hash",Compiler.compile(realized).output_hash == final_hash)
	var reordered: Dictionary = realized.duplicate(true); reordered.brushes.reverse(); reordered.slots.reverse(); reordered.interactions.reverse()
	check("array_order_not_identity",Compiler.compile(reordered).output_hash == final_hash)
	var decoded := Document.read(JSON.stringify(realized,"",true,true).to_utf8_buffer())
	check("strict_roundtrip",decoded.ok and Document.hash_source(decoded.data) == Document.hash_source(realized))
	check("roundtrip_compiles_identically",Compiler.compile(decoded.data).output_hash == final_hash)
	for seed: String in ["0","-1","9223372036854775807","-9223372036854775808"]:
		var seeded := source.duplicate(true); seeded.brushes[0].seed = seed
		var attempt := Compiler.regenerate(seeded); var repeat := Compiler.regenerate(seeded)
		check("seed_"+seed,attempt.ok and repeat.ok and attempt.data == repeat.data)
	var bad := source.duplicate(true); bad.brushes[0].seed = "9223372036854775808"; check("overflow_seed_rejected",not Document.validate(bad).ok)
	bad = source.duplicate(true); bad.surprise = true; check("unknown_field_rejected",not Document.validate(bad).ok)
	bad = source.duplicate(true); bad.brushes.append(bad.brushes[0].duplicate(true)); check("duplicate_id_rejected",not Document.validate(bad).ok)
	bad = source.duplicate(true); bad.brushes[0].radius = NAN; check("nan_rejected",not Document.validate(bad).ok)
	check("truncated_json_rejected",not Document.read('{"schema_version":'.to_utf8_buffer()).ok)
	bad = source.duplicate(true); bad.brushes[0].species[0].species_id = "animal_companion"; check("summon_rejected",Compiler.regenerate(bad).code == "species_invalid")
	bad = source.duplicate(true); bad.brushes[0].species[0].origin_id = "unknown"; check("unknown_origin_rejected",not Compiler.regenerate(bad).ok)
	bad = source.duplicate(true); bad.brushes[0].species[0].category = "unknown"; check("illegal_category_rejected",not Compiler.regenerate(bad).ok)
	bad = source.duplicate(true); bad.brushes[0].species[0].category = "boss"; check("memorable_requires_fixed_site",Compiler.regenerate(bad).code == "thematic_site_required")
	bad = source.duplicate(true); bad.brushes[0].quantity = 128; var deficit := Compiler.regenerate(bad)
	check("impossible_quota_explicit_deficit",not deficit.ok and deficit.code == "population_deficit" and deficit.diagnostics[0].counts.requested == 128 and deficit.diagnostics[0].counts.realized < 128 and not deficit.has("package"))
	check("deficit_reports_actual_constraint_counts",deficit.diagnostics[0].causes.spacing > 0 and deficit.diagnostics[0].causes.population_excluded > 0)
	check("deficit_preserves_prior_plan",realized.slots.size() == 7)
	var pinned := realized.duplicate(true); pinned.slots[0].fixed = true; var pin: Dictionary = pinned.slots[0].duplicate(true)
	for brush: Dictionary in pinned.brushes: brush.round = 1
	var rerolled := Compiler.regenerate(pinned); check("pinned_reroll_succeeds",rerolled.ok)
	if rerolled.ok:
		check("pin_exact_identity_and_home",rerolled.data.slots.has(pin) and rerolled.diff.preserved.has(pin.slot_id) and not rerolled.diff.removed.has(pin.slot_id))
		check("reroll_explicit_removals",rerolled.diff.removed.size() == 6 and rerolled.diff.added.size() == 6)
		check("pinned_plan_compiles",Compiler.compile(rerolled.data).ok)
	bad = pinned.duplicate(true)
	for brush: Dictionary in bad.brushes: brush.quantity = 0
	check("pin_above_quota_rejected",Compiler.regenerate(bad).code == "fixed_excess")
	bad = realized.duplicate(true); bad.slots[0].fixed = true; bad.exclusions.append({"exclusion_id":"pin_block","surface_id":pin.surface_id,"center_xyz":pin.position_xyz,"radius":30})
	check("excluded_pin_never_silently_deleted",not Compiler.regenerate(bad).ok and bad.slots[0].fixed)
	bad = realized.duplicate(true); bad.brushes[0].quantity = 2; check("stale_recipe_blocks_publication",Compiler.compile(bad).code == "plan_stale")
	bad = realized.duplicate(true); bad.slots[0].position_xyz = bad.entrance[0].position_xyz; check("entry_occupied_rejected",not Compiler.compile(bad).ok)
	bad = realized.duplicate(true); bad.slots[0].position_xyz = bad.slots[1].position_xyz; bad.slots[0].surface_id = bad.slots[1].surface_id; bad.slots[0].fixed = true; check("overlapping_bodies_rejected",not Compiler.compile(bad).ok)
	bad = source.duplicate(true); bad.entrance[0].position_xyz = [0,0,0]; check("unsafe_entry_rejected",Compiler.regenerate(bad).code == "entrance_invalid")
	bad = source.duplicate(true); bad.interactions[2].target_id = "absent"; check("broken_portal_rejected",Compiler.regenerate(bad).code == "interaction_invalid")
	bad = source.duplicate(true); bad.interactions[0].position_xyz = [9999,0,9999]; check("unreachable_exit_rejected",Compiler.regenerate(bad).code == "interaction_invalid")
	bad = source.duplicate(true); bad.brushes[0].surface_id = "missing"; check("missing_layer_rejected",not Compiler.regenerate(bad).ok)
	var dense := source.duplicate(true); dense.brushes[0].quota_mode = "density"; dense.brushes[0].density = 1.0
	var density_plan := Compiler.regenerate(dense)
	check("density_counts_navigable_samples",density_plan.ok and density_plan.metrics[0].quantity == int(floor(density_plan.metrics[0].sampled_area/10000.0)))
	var weighted := source.duplicate(true); weighted.brushes[0].species.append({"species_id":"test_gel","category":"elite","origin_id":"trial_stage_2","weight":10000})
	var weighted_plan := Compiler.regenerate(weighted); check("weighted_catalog_choices",weighted_plan.ok and weighted_plan.data.slots.filter(func(s: Dictionary) -> bool: return s.brush_id == "field" and s.category == "elite").size() == 4)
	var changed_recipe := realized.duplicate(true); changed_recipe.brushes[0].species = [{"species_id":"test_gel","category":"elite","origin_id":"trial_stage_2","weight":1}]
	var changed_plan := Compiler.regenerate(changed_recipe)
	check("same_identity_content_change_is_in_diff",changed_plan.ok and changed_plan.diff.changed.size() == 4 and changed_plan.diff.preserved.size() == 3)
	var reverse_weights := weighted.duplicate(true); reverse_weights.brushes[0].species.reverse()
	var reordered_weights := Compiler.regenerate(reverse_weights)
	# The authored recipe order is preserved; realized identities and semantic hash are invariant.
	check("weight_enumeration_stable",reordered_weights.data.slots == weighted_plan.data.slots and Document.hash_source(reordered_weights.data) == Document.hash_source(weighted_plan.data))
	check("cancelled_no_package",Compiler.compile(realized,func() -> bool: return true).code == "cancelled")
	var session := Session.new(); session.replace(realized); session.apply(pinned); session.undo(); check("undo_atomic_plan",session.data == realized); session.redo(); check("redo_atomic_plan",session.data == pinned)
	var job := Compiler.new(); job.start(realized)
	while not job.ready(): await process_frame
	check("obsolete_worker_discarded",job.take("changed").code == "stale_source")
	var root := ProjectSettings.globalize_path("res://.godot/m4_test_"+Crypto.new().generate_random_bytes(5).hex_encode()); DirAccess.make_dir_recursive_absolute(root)
	source_path = root.path_join("encounters.json")
	check("source_safe_save",Store.save_source(source_path,realized,"").ok)
	check("reopen_preserves_realization",Store.load_source(source_path).data == decoded.data)
	check("external_edit_conflict",Store.save_source(source_path,realized,"changed").code == "io_conflict")
	var published := Store.publish(root,built.package,Document.hash_source(realized)); check("local_publish",published.ok)
	if not published.ok: print(published); finish(); return
	check("immutable_idempotent",Store.publish(root,built.package,Document.hash_source(realized)).ok)
	check("package_real_reload",Store.load_package(published.path).package == built.package)
	check("stale_publish_rejected",Store.publish(root,built.package,"changed").code == "stale_source")
	var corrupt: Dictionary = built.package.duplicate(true); corrupt.manifest.population.slots.clear(); check("tampered_package_rejected",not Compiler.validate_package(corrupt))
	check("catalog_not_mutated",Catalog.load_current().hash == original_catalog_hash)
	var context := Compiler.prepare(source)
	var giant: MobCatalog = loaded.catalog.copy_catalog(); var definition: MobDefinition = giant.get_definition(&"test_gel"); definition.collision_radius = 500; giant._definitions[&"test_gel"] = definition
	var giant_spec := Compiler._spec(source.brushes[0].species[0],giant)
	check("real_body_radius_cannot_fit",giant_spec.ok and not Compiler._path(context.world,context.entry,Compiler.anchor(realized.slots[0]),giant_spec.profile))
	check("giant_fixture_catalog_isolated",loaded.catalog.get_definition(&"test_gel").collision_radius < 500)
	var narrow := source.duplicate(true); var replacements: Dictionary = {}
	for piece: Dictionary in narrow.map[0].pieces:
		var old: String = piece.piece_hash
		for port: Dictionary in piece.source.connectors: port.width = 24
		piece.piece_hash = Schema.semantic_hash(piece.source); replacements[old] = piece.piece_hash
	for instance: Dictionary in narrow.map[0].instances: instance.piece_hash = replacements[instance.piece_hash]
	check("narrow_source_rejected",not Compiler.regenerate(narrow).ok)
	# Separate canonical oracle: remove the producer's precision-sensitive opening
	# bake from this check and constrain the already-realized connector width.
	var narrow_manifest: ExpeditionManifest = context.manifest
	for endpoint: Dictionary in narrow_manifest._data.stages[0].connectors: endpoint.width = 24.0
	var narrow_world := WorldGeometry.new(); narrow_world.configure(narrow_manifest,"map_preview")
	check("canonical_mob_profile_blocks_narrow_route",not Compiler._path(narrow_world,context.entry,Compiler.Point.create("map_preview",source.brushes[1].surface_id,Vector3(600,0,200)),Compiler.PROFILE))
	var memorable := source.duplicate(true); memorable.brushes = [memorable.brushes[0]]; memorable.brushes[0].quantity = 1
	memorable.interactions.append({"interaction_id":"shrine","kind":"thematic_encounter","surface_id":memorable.brushes[0].surface_id,"position_xyz":[260,0,240],"target_id":""})
	memorable.slots = [{"slot_id":"keeper","brush_id":"field","surface_id":memorable.brushes[0].surface_id,"position_xyz":[260,0,240],"species_id":"test_gel","category":"boss","origin_id":"trial_stage_1","fixed":true,"site_id":"shrine"}]
	var keeper_plan := Compiler.regenerate(memorable); check("fixed_memorable_on_authored_site",keeper_plan.ok)
	if keeper_plan.ok:
		var keeper_package := Compiler.compile(keeper_plan.data); check("memorable_compiles_with_policy",keeper_package.ok and not keeper_package.package.rules.keeper.trash)
		if keeper_package.ok:
			var keeper_created := ExpeditionCampaignState.create("keeper_test","fixture_character",Compiler.manifest(keeper_package.package),loaded.catalog,keeper_package.package.rules)
			var keeper_state: ExpeditionCampaignState = keeper_created.state; keeper_state.visit("map_preview"); keeper_state.record_death("keeper",0,"keeper_death"); keeper_state.advance(900)
			check("canonical_boss_never_respawns",keeper_state.slots.keeper.life_state == "dead" and keeper_state.stages.map_preview.cleared_once)
	memorable.interactions.back().position_xyz = [9999,0,9999]; check("inaccessible_memorable_site_rejected",not Compiler.regenerate(memorable).ok)
	var relief := relief_fixture(source)
	check("relief_has_connected_logical_cells",not relief.is_empty())
	if not relief.is_empty():
		var painted := Compiler.regenerate(relief); check("brush_crosses_cells_in_selected_layer",painted.ok)
		if painted.ok:
			var supports: Dictionary = {}; var raised := false
			for slot: Dictionary in painted.data.slots: supports[slot.surface_id] = true; raised = raised or slot.position_xyz[1] > 0
			check("layer_brush_uses_multiple_heights_and_cells",supports.size() > 1 and raised)
			check("relief_plan_compiles",Compiler.compile(painted.data).ok)
		var protected := relief.duplicate(true); var piece: Dictionary = protected.map[0].pieces[0]
		piece.source.layers[0].protected_regions = ["route"]
		piece.source.regions = [{"region_id":"route","layer_id":"floor","purpose":"population_exclusion","polygon_xz":[[160,120],[240,120],[240,280],[160,280]]}]
		piece.piece_hash = Schema.semantic_hash(piece.source); protected.map[0].instances[0].piece_hash = piece.piece_hash
		var protected_plan := Compiler.regenerate(protected); check("protected_route_realizes_without_spawns",protected_plan.ok)
		if protected_plan.ok:
			var clear := true
			for slot: Dictionary in protected_plan.data.slots:
				var x: float = slot.position_xyz[0]; var z: float = slot.position_xyz[2]
				if x > 140 and x < 260 and z > 100 and z < 300: clear = false
			check("protected_route_keeps_body_clearance",clear)
	await integration(built.package,loaded.effect_catalog)
	finish()
static func relief_fixture(source: Dictionary) -> Dictionary:
	var piece: Dictionary = source.map[0].pieces[0].source.duplicate(true); piece.document_id = "relief"; piece.connectors = []
	piece.layers[0].columns = 3; piece.layers[0].rows = 3; piece.layers[0].sample_spacing = 200; piece.layers[0].heights = [0,0,0,0,16,0,0,0,0]
	var map := Map.empty("relief_map"); var hash_value := Schema.semantic_hash(piece)
	map.pieces = [{"piece_hash":hash_value,"source":piece}]; map.instances = [{"instance_id":"relief","piece_hash":hash_value,"position_xyz":[0,0,0],"rotation_quarters":0}]
	var built := MapCompiler.compile(map)
	if not built.ok: return {}
	var first: Dictionary = built.package.manifest.stages[0].surfaces[0]; var entry := MapCompiler._center(first)
	var result := Document.empty("relief_encounter"); result.map = [map]; result.entrance = [{"surface_id":first.surface_id,"position_xyz":[entry.x,entry.y,entry.z]}]
	var brush := Document.brush("relief",first.surface_id,Vector3(200,16,200),source.brushes[0].species[0]); brush.radius = 160; brush.group_radius = 120; brush.quantity = 4
	result.brushes = [brush]; return result
func integration(package: Dictionary, effect_catalog: BuildEffectCatalog) -> void:
	var manifest := Compiler.manifest(package)
	var created := ExpeditionCampaignState.create("map_editor_integration","fixture_character",manifest,effect_catalog.mob_catalog(),package.rules)
	check("runtime_planner_accepts_exported_manifest",created.ok)
	if not created.ok: print(created); return
	var state: ExpeditionCampaignState = created.state
	check("entry_grants_once",state.visit("map_preview").size() == 2 and state.visit("map_preview").is_empty())
	check("canonical_state_valid",state.valid())
	for id: String in state.slots: state.record_death(id,0,"death_"+id)
	check("clear_and_clock",state.stages.map_preview.cleared_once and state.clock.started)
	state.advance(state.clock.interval)
	check("wave_queues_only_trash",state.slots.values().filter(func(s: Dictionary) -> bool: return s.life_state == "respawn_pending").size() == 7)
	var first: String = state.slots.keys()[0]; state.admit_respawn(first)
	check("one_generation_only",not state.admit_respawn(first).ok and state.slots[first].generation == 1)
	check("existing_reward_policy",state.reward_terms(first).base_xp == 7 and state.reward_terms(first).job_xp == 5 and state.reward_terms(first).gold_factor == 0.6)
	state.player_died("dead_player"); state.revive("dead_player")
	check("death_return_anchor_unchanged",state.anchor == state.entrance("map_preview") and state.visit("map_preview").is_empty())
	check("local_portal_canonical_view",state.portal_view("gate_a").open and state.portal_view("gate_a").to_stage == "map_preview")
	var controller := RunController.new(); controller.run_state = RunState.new(); controller.run_state.character_id = "fixture_character"
	controller.reward_service = RunRewardService.new(controller)
	controller.run_state._effect_catalog = effect_catalog
	# Actual actors consume the exported manifest; no profile writer or personal save.
	controller.player = PlayerActor.new(); controller.player.collision_radius = 20
	controller.player.configure(ArenaNavigation.new(),controller.run_state); controller.add_child(controller.player)
	var runtime := ExpeditionCampaignRuntime.new()
	var configured := runtime.configure(controller,"editor_actor_integration",manifest,package.rules)
	check("real_runtime_configures_actors",configured.ok)
	if configured.ok:
		check("real_actor_count",controller.enemies.size() == 7 and runtime.actors.size() == 7)
		check("real_player_at_authored_entry",controller.player.world_motion.point().position == state.anchor.position)
		var target: Dictionary = manifest._data.portals[0].to_anchor
		check("real_canonical_portal_arrival",runtime.activate_stage(controller,"map_preview",target).ok and controller.player.world_motion.point().position == target.position)
		check("return_keeps_existing_actors",runtime.activate_stage(controller,"map_preview",runtime.state.anchor).ok and runtime.actors.size() == 7)
	controller.free()
	await process_frame
func finish() -> void:
	var ok := true
	for item: Dictionary in checks:
		if not item.ok: ok = false
	print("M4_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"source_path":source_path,"package_hash":final_hash})); quit(0 if ok else 1)
