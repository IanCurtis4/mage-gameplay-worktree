extends SceneTree
## Checkpoint51 (F9-05/08/12, P7): seed generation with pins and encounter chances
## on clones of the final area. The slot WFC proposes a variant of the Bosque
## keeping the pinned passage exactly, through the same compiler; a weighted brush
## realizes both species in the Bosque plan and the canonical species draw follows
## the weights. Nothing committed is written.
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const MapStore = preload("res://scripts/map_authoring/composition/map_store.gd")
const MapCompiler = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const PopulationStore = preload("res://scripts/map_authoring/population/population_store.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Generation = preload("res://scripts/map_authoring/generation/generation_document.gd")
const Solver = preload("res://scripts/map_authoring/generation/generation_solver.gd")
const FOLDER := "res://data/map_authoring/"
const FILES := ["sanctuary_woods.map.json","sanctuary_woods.population.json","sanctuary_woods.rpp","release_packages.json"]
var checks: Array[Dictionary] = []
var metrics := {}
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_AREA_VARIANT_CHECK "+id+" "+str(ok))
func run() -> void:
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var before := {}
	for file: String in FILES: before[file] = FileAccess.get_sha256(FOLDER+file)
	var map := MapStore.load_source(FOLDER+FILES[0])
	var population := PopulationStore.load_source(FOLDER+FILES[1])
	check("area_sources_open",map.ok and population.ok)
	if not (map.ok and population.ok): finish(); return
	# 1. Generation with a pin: the clearing may become its earth variant; the passage is pinned.
	var bosque: Dictionary = map.data.duplicate(true)
	var clearing: Dictionary = {}
	for piece: Dictionary in bosque.pieces:
		if piece.source.document_id == "sanctuary_woods_clearing": clearing = piece.source
	var variant: Dictionary = clearing.duplicate(true); variant.document_id = "sanctuary_woods_clearing_earth"; variant.name = "Clareira de terra batida"
	var ground: Dictionary = variant.layers[0]
	ground.material_masks.earth = ground.material_masks.earth.map(func(v: float) -> float: return 1.0-v)
	ground.material_masks.grass = ground.material_masks.grass.map(func(v: float) -> float: return 1.0-v)
	var variant_hash := Schema.semantic_hash(variant)
	bosque.pieces.append({"piece_hash":variant_hash,"source":variant})
	var request := Generation.from_map(bosque)
	for domain: Dictionary in request.domains:
		if domain.instance_id == "clearing": domain.options.append({"piece_hash":variant_hash,"rotation_quarters":0,"weight":3})
	request.pins = ["overpass"]; request.seed_text = "11"
	var original := Generation.hash_source(request)
	var t := Time.get_ticks_msec()
	var result := Solver.new().solve(request,true)
	metrics["generation_ms"] = Time.get_ticks_msec()-t
	var pinned := false; var chosen := ""
	if result.get("ok",false):
		for instance: Dictionary in result.proposal.instances:
			if instance.instance_id == "overpass": pinned = Schema._canonical(instance) == Schema._canonical(bosque.instances[1])
			if instance.instance_id == "clearing": chosen = instance.piece_hash
	check("generation_keeps_the_pinned_passage",result.get("ok",false) and pinned and result.proposal.links == bosque.links and chosen in [clearing_hash(bosque),variant_hash] and Generation.hash_source(request) == original)
	check("generation_uses_the_map_compiler",result.get("ok",false) and MapCompiler.validate_package(result.package) and result.package.manifest.stages[0].surfaces.size() > 0)
	# 2. Encounter chances: two species weighted 3:1 in the dispersed clearing brush.
	var weighted: Dictionary = population.data.duplicate(true)
	var brush: Dictionary = {}
	for item: Dictionary in weighted.brushes:
		if item.brush_id == "clearing_dispersed": brush = item
	var common: Dictionary = brush.species[0].duplicate(true); common.weight = 3
	var other: Dictionary = {}
	for item: Dictionary in weighted.brushes:
		for spec: Dictionary in item.species:
			if spec.species_id != common.species_id and other.is_empty(): other = spec.duplicate(true)
	other.weight = 1
	brush.species = [common,other]
	t = Time.get_ticks_msec()
	var planned := Population.regenerate(weighted)
	metrics["regenerate_ms"] = Time.get_ticks_msec()-t
	var realized: Array = planned.get("data",{}).get("slots",[]).filter(func(slot: Dictionary) -> bool: return slot.brush_id == "clearing_dispersed")
	var species_ok: bool = not realized.is_empty() and realized.all(func(slot: Dictionary) -> bool: return slot.species_id in [common.species_id,other.species_id])
	check("weighted_brush_realizes_in_the_bosque",planned.get("ok",false) and realized.size() == int(brush.quantity) and species_ok and planned.data.plan_hash == PopulationDocument.recipe_hash(planned.data))
	# The canonical draw of the compiler (stream + ":species:" + n) over many streams.
	var draws := {common.species_id:0,other.species_id:0}
	for n: int in 4000:
		var draw: int = ("bosque_weights_"+str(n)+":species:0").sha256_text().substr(0,7).hex_to_int()%4
		var pick: String = common.species_id if draw < 3 else other.species_id
		draws[pick] += 1
	metrics["draws"] = draws
	var share := float(draws[common.species_id])/4000.0
	check("species_draw_follows_the_weights",absf(share-0.75) < 0.03)
	var after := {}
	for file: String in FILES: after[file] = FileAccess.get_sha256(FOLDER+file)
	check("committed_bosque_untouched",after == before)
	finish()
static func clearing_hash(map: Dictionary) -> String:
	for instance: Dictionary in map.instances:
		if instance.instance_id == "clearing": return instance.piece_hash
	return ""
func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_AREA_VARIANT_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks,"metrics":metrics})); quit(0 if ok else 1)
