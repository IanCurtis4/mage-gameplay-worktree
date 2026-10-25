extends SceneTree
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Context = preload("res://scripts/map_authoring/context/piece_context.gd")
const PopulationContext = preload("res://scripts/map_authoring/context/population_context.gd")
const Map = preload("res://scripts/map_authoring/composition/map_document.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PopulationFixture = preload("res://tests/map_editor_population_test.gd")
const Generation = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Solver = preload("res://scripts/map_authoring/generation/generation_solver.gd")
const Adapter = preload("res://scripts/map_authoring/generation/assembler_adapter.gd")
const Exchange = preload("res://scripts/map_authoring/exchange/exchange.gd")
const Terrain = preload("res://scripts/map_authoring/terrain/terrain_panel.gd")
const Piece = preload("res://scripts/map_authoring/document/source_document.gd")
const Patrol = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PatrolStore = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
var checks: Array = []
var samples: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(id: String, value: bool) -> void:
	checks.append({"id":id,"ok":value}); print("M8_CHECK "+id+" "+str(value))
static func rehash(map: Dictionary, index: int) -> void:
	var old: String = map.pieces[index].piece_hash; var next := Schema.semantic_hash(map.pieces[index].source); map.pieces[index].piece_hash = next
	for instance: Dictionary in map.instances:
		if instance.piece_hash == old: instance.piece_hash = next
static func contextual() -> Dictionary:
	var source := PopulationFixture.fixture(); source.map[0].context = Context.empty_map(); source.map[0].context.biome_id = "ruin"
	for index: int in source.map[0].pieces.size():
		var context := Context.empty(); context.biome_ids = ["ruin","forest"]; context.allowed_species = ["test_gel"]; context.allow_rare = true
		source.map[0].pieces[index].source.context = context; rehash(source.map[0],index)
	return source
static func add_reservation(source: Dictionary) -> void:
	var piece: Dictionary = source.map[0].pieces[0].source
	piece.regions.append({"region_id":"guardian_area","layer_id":"floor","polygon_xz":[[200,220],[360,220],[360,360],[200,360]],"purpose":"encounter"})
	piece.context.areas.append({"region_id":"guardian_area","allowed_species":[],"allow_rare":false,"reserved":[{"encounter_id":"guardian","species_id":"test_gel","category":"boss","origin_id":"trial_stage_1","quest_id":"find_guardian"}]})
	rehash(source.map[0],0)
func run() -> void:
	var legacy := Map.sample(); var legacy_hash := Map.hash_source(legacy)
	check("legacy_hash_unchanged",Map.read(JSON.stringify(legacy).to_utf8_buffer()).output_hash == legacy_hash)
	var source := contextual(); var map: Dictionary = source.map[0]; var frozen := source.duplicate(true)
	check("context_source_valid",Map.validate(map).ok)
	if not Map.validate(map).ok:
		print(Map.validate(map))
		for piece: Dictionary in map.pieces: print("HASH_DEBUG ",piece.piece_hash," ",Schema.semantic_hash(piece.source)," ",Schema.read(JSON.stringify(piece.source,"",true,true).to_utf8_buffer()))
		finish(); return
	check("context_compile",MapCompiler.compile(map).ok)
	check("context_roundtrip",Map.read(JSON.stringify(map).to_utf8_buffer()).output_hash == Map.hash_source(map))
	check("textual_key_identity",Schema.semantic_hash({"context":{"version":1}}) == Schema.semantic_hash({&"context":{&"version":1}}))
	var malformed := map.duplicate(true); malformed.instances = [null]
	check("malformed_instance_rejects_without_script_error",not Map.validate(malformed).ok)
	malformed = map.duplicate(true); malformed.pieces[0].source.context.version = 2; rehash(malformed,0)
	check("future_context_rejected",not Map.validate(malformed).ok)
	var bad := map.duplicate(true); bad.context.biome_id = "desert"
	check("biome_rejected",MapCompiler.compile(bad).code == "context_biome")
	bad.context.overrides = [{"instance_id":"left","rules":["biome"],"reason":"Ensaio manual"},{"instance_id":"right","rules":["biome"],"reason":"Ensaio manual"}]
	var overridden := MapCompiler.compile(bad)
	check("manual_override_compiles",overridden.ok)
	check("manual_override_warns",overridden.ok and overridden.diagnostics.size() == 2)
	check("manual_override_exported",overridden.ok and overridden.package.authoring_context.overrides.size() == 2)
	check("override_exact_payload",overridden.ok and overridden.package.authoring_context == bad.context)
	var one_exception := bad.duplicate(true); one_exception.context.overrides.remove_at(1)
	check("override_is_per_instance",MapCompiler.compile(one_exception).code == "context_biome")
	one_exception = bad.duplicate(true); one_exception.context.overrides[1].rules = ["species"]
	check("override_is_per_rule",MapCompiler.compile(one_exception).code == "context_biome")
	one_exception = bad.duplicate(true); one_exception.instances[1].position_xyz[0] += 30
	check("override_never_bypasses_seam",MapCompiler.compile(one_exception).code == "seam_position")
	var request: Dictionary = Exchange.export_bundle("map",bad,Exchange.policy(["name"]),"Teste com exceções")
	check("override_bundle_preserved",request.ok and request.bundle.ticket.base.context == bad.context)
	if request.ok:
		var changed := bad.duplicate(true); changed.name = "Revisão com exceções"
		var proposal := Exchange.propose(request.bundle,changed)
		var prepared := Exchange.prepare(request.bundle,proposal.bundle,bad) if proposal.ok else {"ok":false}
		check("override_import_roundtrip",prepared.ok and prepared.source.context == bad.context)
	check("solver_does_not_inherit_override",Solver.new().solve(Generation.from_map(bad),true).code == "context_override_invalid")
	check("assembler_does_not_inherit_override",Adapter.build(Generation.from_map(bad)).code == "context_override_invalid")
	bad.context.overrides[0].reason = " "
	check("override_reason_required",not Map.validate(bad).ok)
	bad = map.duplicate(true); bad.mode = "recipe"; bad.context.overrides = [{"instance_id":"left","rules":["biome"],"reason":"Não pode"}]
	check("recipe_override_rejected",not Map.validate(bad).ok)
	bad = map.duplicate(true); bad.context.biome_id = "desert"
	var solved := Solver.new().solve(Generation.from_map(bad),true)
	check("seed_context_contradiction",not solved.ok and solved.diagnostic.rule == "context_biome")
	for seed_text: String in ["0","-1","9223372036854775807","-9223372036854775808"]:
		var generation := Generation.from_map(map); generation.seed_text = seed_text
		var first := Solver.new().solve(generation,true); var second := Solver.new().solve(generation,true)
		check("seed_"+seed_text,first.ok and second.ok and first.output_hash == second.output_hash)
	var plan := Population.regenerate(source)
	check("population_context_plan",plan.ok)
	check("no_input_mutation",source == frozen)
	if not plan.ok: print(plan); finish(); return
	check("population_context_compile",Population.compile(plan.data).ok)
	bad = plan.data.duplicate(true); bad.map[0].pieces[0].source.context.allowed_species = ["another_species"]; rehash(bad.map[0],0); bad.plan_hash = Population.Document.recipe_hash(bad)
	check("species_policy_enforced",Population.compile(bad).code == "context_species")
	bad.map[0].context.overrides = [{"instance_id":"left","rules":["species"],"reason":"Teste explícito"}]; bad.plan_hash = Population.Document.recipe_hash(bad)
	check("manual_species_exception",Population.compile(bad).ok)
	var rare := source.duplicate(true); rare.brushes[0].species[0].category = "rare"
	var rare_plan := Population.regenerate(rare)
	check("rare_generation_allowed",rare_plan.ok)
	if rare_plan.ok:
		check("rare_theme_is_not_gate",Population.compile(rare_plan.data).ok and rare_plan.data.slots.filter(func(slot: Dictionary) -> bool: return slot.category == "rare" and slot.site_id == "").size() == 4)
		var denied: Dictionary = rare_plan.data.duplicate(true); denied.map[0].pieces[0].source.context.allow_rare = false; rehash(denied.map[0],0); denied.plan_hash = Population.Document.recipe_hash(denied)
		check("rare_policy_enforced",Population.compile(denied).code == "context_rare")
		denied.map[0].context.overrides = [{"instance_id":"left","rules":["rare"],"reason":"Raro inserido manualmente neste mapa"}]; denied.plan_hash = Population.Document.recipe_hash(denied)
		check("manual_rare_exception",Population.compile(denied).ok)
	var manual := PopulationFixture.fixture(); manual.brushes = [manual.brushes[0]]; manual.brushes[0].quantity = 1; manual.interactions = []; manual.exclusions = []
	manual.slots = [{"slot_id":"manual_rare","brush_id":"field","surface_id":manual.brushes[0].surface_id,"position_xyz":[260,0,240],"species_id":"test_gel","category":"rare","origin_id":"trial_stage_1","fixed":true,"site_id":""}]
	manual.plan_hash = Population.Document.recipe_hash(manual)
	check("manual_rare_without_theme_allowed",Population.compile(manual).ok)
	var manual_context := contextual(); manual_context.brushes = [manual_context.brushes[0]]; manual_context.brushes[0].quantity = 1
	manual_context.slots = manual.slots.duplicate(true); manual_context.interactions = []; manual_context.exclusions = []
	for index: int in manual_context.map[0].pieces.size():
		manual_context.map[0].pieces[index].source.context.allow_rare = false; rehash(manual_context.map[0],index)
	manual_context.plan_hash = Population.Document.recipe_hash(manual_context)
	check("manual_rare_ignores_random_permission",Population.compile(manual_context).ok)
	var reserved := contextual(); add_reservation(reserved)
	var reserved_plan := Population.regenerate(reserved)
	check("reservation_realized",reserved_plan.ok)
	if reserved_plan.ok:
		var built := Population.compile(reserved_plan.data)
		check("reservation_compiles",built.ok)
		var site := PopulationContext.site_id("left",reserved.map[0].pieces[0].source.context.areas[0].reserved[0])
		check("reservation_fixed_unique",reserved_plan.data.slots.filter(func(slot: Dictionary) -> bool: return slot.site_id == site and slot.fixed).size() == 1)
		check("reservation_quest_passive",built.ok and built.package.map_package.piece_contexts.left.areas[0].reserved[0].quest_id == "find_guardian" and built.package.manifest.objectives.size() == 2)
		if built.ok:
			var no_quest: Dictionary = reserved_plan.data.duplicate(true); no_quest.map[0].pieces[0].source.context.areas[0].reserved[0].quest_id = ""; rehash(no_quest.map[0],0); no_quest.plan_hash = Population.Document.recipe_hash(no_quest)
			var no_quest_package := Population.compile(no_quest)
			check("quest_does_not_change_objectives_or_rewards",no_quest_package.ok and no_quest_package.package.manifest.objectives == built.package.manifest.objectives and no_quest_package.package.rules == built.package.rules)
		var again := Population.regenerate(reserved_plan.data)
		check("reservation_regeneration_idempotent",again.ok and again.data == reserved_plan.data)
		var missing: Dictionary = reserved_plan.data.duplicate(true); missing.slots = missing.slots.filter(func(slot: Dictionary) -> bool: return slot.site_id != site); missing.plan_hash = Population.Document.recipe_hash(missing)
		check("reservation_required_on_compile",Population.compile(missing).code == "context_reservation_missing")
		var occupying: Dictionary = reserved_plan.data.duplicate(true); var protected_slot := MapCompiler._find(occupying.slots,"slot_id",site); protected_slot.site_id = ""; protected_slot.category = "normal"; occupying.plan_hash = Population.Document.recipe_hash(occupying)
		check("ordinary_spawn_cannot_take_reserved_area",Population.compile(occupying).code == "context_reservation_missing")
		var protected_record := MapCompiler._find(reserved_plan.data.slots,"slot_id",site)
		var forbidden_point := Population.anchor(protected_record)
		var prepared_context := Population.prepare(reserved_plan.data)
		check("ordinary_pool_excludes_reservation_directly",PopulationContext.policy(reserved_plan.data,prepared_context,forbidden_point,{"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1"},20) == "context_reserved")
		var ordinary_inside := false
		for slot: Dictionary in reserved_plan.data.slots:
			if slot.fixed: continue
			if PopulationContext.policy(reserved_plan.data,prepared_context,Population.anchor(slot),slot,20) != "": ordinary_inside = true
		check("ordinary_population_stays_outside_reservation",not ordinary_inside and reserved_plan.data.slots.size() > 1)
		check("reservation_editorial_reference_roundtrip",Population.Document.read(JSON.stringify(reserved_plan.data).to_utf8_buffer()).ok)
		var invalid_context := reserved.duplicate(true); invalid_context.map[0].pieces[0].source.context.areas[0].region_id = "absent"; rehash(invalid_context.map[0],0)
		check("missing_region_rejected",not Map.validate(invalid_context.map[0]).ok)
		samples.context_population = reserved_plan.data
	make_representative()
	finish()

func make_representative() -> void:
	var source := representative_map()
	var built := MapCompiler.compile(source)
	check("representative_geometry",built.ok)
	if not built.ok: print(built); return
	samples.map = source
	var population := Population.Document.empty("representative_encounters"); population.name = "Clareira e santuário"; population.map = [source]
	var a := surface_at(built.package,"land","lower",Vector3(64,0,200)); var b := surface_at(built.package,"sanctuary","floor",Vector3(1400,40,200))
	population.entrance = [{"surface_id":a,"position_xyz":[64,0,200]}]
	var spec := {"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1","weight":1}
	var brush := Population.Document.brush("field",a,Vector3(240,0,200),spec); brush.quantity = 3; brush.radius = 112
	var group := Population.Document.brush("group",b,Vector3(1400,40,200),spec); group.quantity = 3; group.mode = "concentrated"; group.radius = 112; group.group_radius = 100
	population.brushes = [brush,group]
	population.slots = [{"slot_id":"scout","brush_id":"field","surface_id":a,"position_xyz":[240,0,200],"species_id":"test_gel","category":"normal","origin_id":"trial_stage_1","fixed":true,"site_id":""}]
	population.interactions = [{"interaction_id":"finish","kind":"phase_completion","surface_id":b,"position_xyz":[1512,40,720],"target_id":""},{"interaction_id":"refuge","kind":"early_exit","surface_id":a,"position_xyz":[64,0,320],"target_id":""}]
	var plan := Population.regenerate(population)
	check("representative_encounters",plan.ok)
	if not plan.ok: print(plan); return
	samples.population = plan.data
	var patrol := Patrol.Document.empty(); patrol.population = [plan.data]
	patrol.patrols = [{"patrol_id":"scout_route","revision":1,"mode":"ping_pong","slot_ids":["scout"],"waypoints":[{"point_id":"a","surface_id":a,"position_xyz":[240,0,200],"wait_seconds":1},{"point_id":"b","surface_id":a,"position_xyz":[320,0,260],"wait_seconds":0.5}]}]
	var compiled := Patrol.compile(patrol); check("representative_patrol",compiled.ok)
	if not compiled.ok: print(compiled); return
	samples.patrol = patrol
	var directory := ProjectSettings.globalize_path("res://.godot/m8_samples"); DirAccess.make_dir_recursive_absolute(directory)
	for kind: String in samples:
		var file := FileAccess.open(directory.path_join(kind+".json"),FileAccess.WRITE); file.store_string(JSON.stringify(samples[kind],"\t",true,true)); file.close()
	var published := PatrolStore.publish(directory,compiled.package,Patrol.Document.hash_source(patrol))
	check("representative_package_published",published.ok)
	if published.ok:
		var file := FileAccess.open(directory.path_join("package_path.txt"),FileAccess.WRITE); file.store_string(published.path); file.close()
	var report := {"source_hash":Patrol.Document.hash_source(patrol),"package_hash":compiled.output_hash,"bytes":var_to_bytes(compiled.package).size(),"piece_count":2,"slots":plan.data.slots.size(),"surfaces":built.package.manifest.stages[0].surfaces.size()}
	var output := FileAccess.open(directory.path_join("sample_report.json"),FileAccess.WRITE); output.store_string(JSON.stringify(report)); output.close()

static func representative_map() -> Dictionary:
	var land := Terrain.sample_source(Piece.empty("land"))
	for layer: Dictionary in land.layers:
		layer.origin_xz[0] *= 4; layer.origin_xz[1] *= 4; layer.sample_spacing *= 4
		for index: int in layer.heights.size(): layer.heights[index] *= 1
	for special: Dictionary in land.special_surfaces:
		for xyz: Array in special.vertices_xyz:
			xyz[0] *= 4; xyz[1] *= 1; xyz[2] *= 4
	land.connectors = [{"connector_id":"east","surface_id":"plateau","position_xyz":[1200,40,200],"normal_xyz":[1,0,0],"kind":"walk","width":120,"headroom":100,"tags":["ruin"],"direction":"both"}]
	land.context = Context.empty(); land.context.biome_ids = ["ruin","forest"]; land.context.allowed_species = ["test_gel"]; land.context.allow_rare = true
	var sanctuary := Piece.empty("sanctuary","Santuário · encontro reservado")
	sanctuary.layers = [Terrain._layer("floor","Santuário",0,0,400,2,3,[40,40,40,40,40,40])]
	sanctuary.connectors = [{"connector_id":"west","surface_id":"floor","position_xyz":[0,40,200],"normal_xyz":[-1,0,0],"kind":"walk","width":120,"headroom":100,"tags":["ruin"],"direction":"both"}]
	sanctuary.context = land.context.duplicate(true)
	sanctuary.regions = [{"region_id":"guardian_area","layer_id":"floor","polygon_xz":[[120,400],[280,400],[280,600],[120,600]],"purpose":"encounter"}]
	sanctuary.context.areas = [{"region_id":"guardian_area","allowed_species":[],"allow_rare":false,"reserved":[{"encounter_id":"sanctuary_guardian","species_id":"test_gel","category":"boss","origin_id":"trial_stage_1","quest_id":"find_guardian"}]}]
	var map := Map.empty("representative_map"); map.name = "Clareira, ponte e santuário"; map.context = Context.empty_map(); map.context.biome_id = "ruin"
	var a := Schema.semantic_hash(land); var b := Schema.semantic_hash(sanctuary)
	map.pieces = [{"piece_hash":a,"source":land},{"piece_hash":b,"source":sanctuary}]
	map.instances = [{"instance_id":"land","piece_hash":a,"position_xyz":[0,0,0],"rotation_quarters":0},{"instance_id":"sanctuary","piece_hash":b,"position_xyz":[1200,0,0],"rotation_quarters":0}]
	map.links = [{"link_id":"sanctuary_gate","a_instance":"land","a_connector":"east","b_instance":"sanctuary","b_connector":"west"}]
	return map
static func surface_at(package: Dictionary, instance: String, layer: String, point: Vector3) -> String:
	for record: Dictionary in package.render_instances:
		if record.instance_id != instance: continue
		for visual: Dictionary in record.visuals:
			if visual.source_id != layer: continue
			var id: String = instance+"/"+visual.surface_id
			var cell := MapCompiler._find(package.manifest.stages[0].surfaces,"surface_id",id)
			if Kernel_contains(cell,point): return id
	return ""
static func Kernel_contains(cell: Dictionary, point: Vector3) -> bool:
	return not cell.is_empty() and MapCompiler.Kernel.contains(cell,point)
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("M8_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
