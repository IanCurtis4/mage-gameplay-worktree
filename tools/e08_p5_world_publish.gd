extends SceneTree
## E08 P5 B2b: republishes the forest maps with the new materials and prop variants
## through the existing producer (carry_forward + patrol compiler + MapRelease
## publication format). Runs inside the shared fixture, so nothing is written under
## res://data; every output goes to the evidence folder and is copied back by hand.
## Usage (wrapper -Stage probe -Headless): -- {output} <mode> <args...>
##   variants <id>                     piece variants + piece->map (writes source/map json)
##   population <id> <map.json>        map->population (re-certifies the kept plan)
##   patrol <id> <population.json>     population->patrol, compile and publication bytes
##   republish <id>                    unchanged source, new package (catalog/material deps)
##   file <source.json> <name.rpp>     reference package outside the registry
##   registry <entry.json>...          registry with the given entries replaced
##   bake <id>                         navigation proof for the pinned package (written in res://)
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const Carry = preload("res://scripts/map_authoring/workflow/carry_forward.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const SourceStore = preload("res://scripts/map_authoring/io/source_store.gd")
const MapStore = preload("res://scripts/map_authoring/composition/map_store.gd")
const PopulationStore = preload("res://scripts/map_authoring/population/population_store.gd")
const PatrolStore = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Patrol = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
const PatrolDocument = preload("res://scripts/map_authoring/patrol/patrol_document.gd")
const MapDocument = preload("res://scripts/map_authoring/composition/map_document.gd")
const PopulationDocument = preload("res://scripts/map_authoring/population/population_document.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const FOLDER := "res://data/map_authoring/"
## Placement rule (documented in docs/epics/e08_p5_world_delivery.md). Ranking key is
## sha256(<salt> + placement_id); quotas are round-half-up of the share.
const BIRCH_SALT := "e08_p5_b2b/birch/"
const DECOR_SALT := "e08_p5_b2b/decor/"
const BIRCH_PERCENT := 25
const DECOR_PERCENT := 40
## Decorative share split: fern 40%, wildflower 30% and fallen log 15% (both flat sites only), mushroom ring rest.
const DECOR_SPLIT := [["fern_cluster",40],["wildflower_patch",30],["fallen_log",15],["mushroom_ring",0]]

var out := ""
var report := {}

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]; var mode: String = args[1]
	OS.set_environment("RAGRPG_COMPILE_CACHE","1")
	var started := Time.get_ticks_usec()
	var result: Dictionary
	match mode:
		"variants": result = _variants(args[2])
		"population": result = _population(args[2],args[3])
		"population_keep": result = _population_keep(args[2],args[3])
		"patrol_keep": result = _patrol(args[2],args[3],true)
		"recertify": result = _recertify(args[2],args[3])
		"popcompile": result = _popcompile(args[2],args[3])
		"patrol": result = _patrol(args[2],args[3])
		"republish": result = _republish(args[2])
		"file": result = _file(args[2],args[3])
		"registry": result = _registry(args.slice(2))
		"bake": result = _bake(args[2])
		_: result = {"ok":false,"code":"mode_invalid"}
	result["mode"] = mode; result["elapsed_ms"] = (Time.get_ticks_usec()-started)/1000.0
	var file := FileAccess.open(out.path_join("result_"+mode+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t",true,true)); file.close()
	print("E08P5_B2B_RESULT "+JSON.stringify(result).left(6000))
	quit(0 if result.get("ok",false) else 1)

static func quota(count: int, percent: int) -> int: return (count*percent+50)/100

static func ranked(placements: Array, definition_id: String, salt: String) -> Array:
	var chosen: Array = placements.filter(func(p: Dictionary) -> bool: return p.definition_id == definition_id)
	chosen.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var ka := (salt+String(a.placement_id)).sha256_text(); var kb := (salt+String(b.placement_id)).sha256_text()
		return ka < kb or (ka == kb and String(a.placement_id) < String(b.placement_id)))
	return chosen

## The variant swap of a piece: definition ids only, same position/rotation/surface/revision.
static func apply_variants(piece: Dictionary, catalog: Dictionary) -> Dictionary:
	var data: Dictionary = piece.duplicate(true)
	var target := {}
	var oaks := ranked(data.placements,"oak_tree",BIRCH_SALT)
	var birch_count := quota(oaks.size(),BIRCH_PERCENT)
	for k: int in birch_count: target[oaks[k].placement_id] = "birch_tree"
	var shrubs := ranked(data.placements,"woodland_shrub",DECOR_SALT)
	var decor_count := quota(shrubs.size(),DECOR_PERCENT)
	# Quotas per variant (round-half-up, mushroom takes the rest). The flat, wide
	# variants (fallen log ~81 u, wildflower patch ~66 u lying on the ground) only go
	# to flat sites, so none lies across a cliff edge: each takes the first flat
	# candidates in rank order (log first); the others fill fern and mushroom in rank
	# order. A flat-only quota without enough flat sites becomes ferns.
	var selected: Array = shrubs.slice(0,decor_count)
	var quotas := {}; var assigned := 0
	for k: int in DECOR_SPLIT.size():
		var n: int = decor_count-assigned if k == DECOR_SPLIT.size()-1 else quota(decor_count,DECOR_SPLIT[k][1])
		quotas[DECOR_SPLIT[k][0]] = n; assigned += n
	var rest: Array = selected.duplicate()
	for id: String in FLAT_ONLY:
		var placed := 0; var left: Array = []
		for placement: Dictionary in rest:
			if placed < int(quotas[id]) and flat_site(data,placement): target[placement.placement_id] = id; placed += 1
			else: left.append(placement)
		quotas.fern_cluster = int(quotas.fern_cluster)+int(quotas[id])-placed; quotas[id] = placed
		rest = left
	var cursor := 0
	for id: String in ["fern_cluster","mushroom_ring"]:
		for j: int in int(quotas[id]): target[rest[cursor+j].placement_id] = id
		cursor += int(quotas[id])
	var counts := quotas
	var changes: Array = []
	for placement: Dictionary in data.placements:
		if not target.has(placement.placement_id): continue
		var to: String = target[placement.placement_id]
		var found := Catalog.definition(to,catalog)
		if not found.ok or int(found.definition.revision) != int(placement.revision): return {"ok":false,"code":"variant_definition","id":to}
		changes.append({"placement_id":placement.placement_id,"from":placement.definition_id,"to":to})
		placement.definition_id = to
	var present := {}
	for dependency: Dictionary in data.dependencies: present[dependency.definition_id] = true
	for id: String in ["birch_tree","fern_cluster","wildflower_patch","mushroom_ring","fallen_log"]:
		if present.has(id) or not data.placements.any(func(p: Dictionary) -> bool: return p.definition_id == id): continue
		data.dependencies.append(Catalog.dependency(Catalog.definition(id,catalog).definition))
	changes.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.placement_id < b.placement_id)
	var totals := {}
	for placement: Dictionary in data.placements: totals[placement.definition_id] = int(totals.get(placement.definition_id,0))+1
	return {"ok":true,"data":data,"changes":changes,"oaks":oaks.size(),"birch":birch_count,"shrubs":shrubs.size(),"decor":counts,"totals":totals}

const FLAT_ONLY := ["fallen_log","wildflower_patch"]
const FLAT_RADIUS := 48.0
const FLAT_TOLERANCE := 8.0
## Height of a height-grid layer at (x, z), bilinear; NAN outside the grid.
static func layer_height(layer: Dictionary, x: float, z: float) -> float:
	var columns: int = int(layer.columns); var rows: int = int(layer.rows); var spacing := float(layer.sample_spacing)
	var fx := (x-float(layer.origin_xz[0]))/spacing; var fz := (z-float(layer.origin_xz[1]))/spacing
	if fx < 0.0 or fz < 0.0 or fx > columns-1 or fz > rows-1: return NAN
	var i := mini(int(fx),columns-2); var j := mini(int(fz),rows-2); var tx := fx-i; var tz := fz-j
	var heights: Array = layer.heights
	var top := lerpf(float(heights[j*columns+i]),float(heights[j*columns+i+1]),tx)
	var bottom := lerpf(float(heights[(j+1)*columns+i]),float(heights[(j+1)*columns+i+1]),tx)
	return lerpf(top,bottom,tz)

## Flat site: the ground on a 48-unit circle (16 samples) stays within 8 units of the centre.
static func flat_site(piece: Dictionary, placement: Dictionary) -> bool:
	for layer: Dictionary in piece.layers:
		if layer.layer_id != placement.surface_id or layer.get("surface_mode","") != "height_grid": continue
		var p: Array = placement.position_xyz
		var centre := layer_height(layer,float(p[0]),float(p[2]))
		if is_nan(centre): return false
		for k: int in 16:
			var angle := k*PI/8.0
			var h := layer_height(layer,float(p[0])+FLAT_RADIUS*cos(angle),float(p[2])+FLAT_RADIUS*sin(angle))
			if is_nan(h) or absf(h-centre) > FLAT_TOLERANCE: return false
		return true
	return false

static func encode(data: Dictionary) -> PackedByteArray: return JSON.stringify(data,"\t",true,true).to_utf8_buffer()

func _write(name: String, bytes: PackedByteArray) -> String:
	var path := out.path_join(name)
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_buffer(bytes); file.close()
	return path

func _roundtrip(path: String, data: Dictionary) -> bool: return encode(data) == FileAccess.get_file_as_bytes(path)

func _variants(id: String) -> Dictionary:
	var piece_path := FOLDER+id+".source.json"; var map_path := FOLDER+id+".map.json"
	var piece_read := SourceStore.load_source(piece_path)
	var map_read := MapStore.load_source(map_path)
	if not piece_read.ok or not map_read.ok: return {"ok":false,"code":"read_failed","piece":piece_read.get("code",""),"map":map_read.get("code","")}
	var piece: Dictionary = piece_read.data; var map: Dictionary = map_read.data
	var piece_hash := Schema.semantic_hash(piece)
	var snapshot_matches: bool = map.pieces.size() == 1 and map.pieces[0].piece_hash == piece_hash and Schema.semantic_hash(map.pieces[0].source) == piece_hash
	if not snapshot_matches: return {"ok":false,"code":"piece_not_the_map_snapshot"}
	var catalog := Catalog.load_catalog()
	if not catalog.ok: return catalog
	var swapped := apply_variants(piece,catalog)
	if not swapped.ok: return swapped
	var carried := Carry.piece_into_map(map,swapped.data)
	if not carried.ok: return carried
	_write(id+".source.json",encode(swapped.data)); _write(id+".map.json",encode(carried.source))
	_write(id+".changes.json",JSON.stringify(swapped.changes,"\t",true,true).to_utf8_buffer())
	return {"ok":true,"id":id,"roundtrip_source":_roundtrip(piece_path,piece),"roundtrip_map":_roundtrip(map_path,map),"piece_hash_before":piece_hash,"piece_hash_after":Schema.semantic_hash(swapped.data),
		"map_hash_before":MapDocument.hash_source(map),"map_hash_after":carried.source_hash,"map_compiled_hash":carried.compiled_hash,"diff":carried.diff,
		"oaks":swapped.oaks,"birch":swapped.birch,"shrubs":swapped.shrubs,"decor":swapped.decor,"totals":swapped.totals,"changes":swapped.changes.size(),"placements":swapped.data.placements.size()}

func _population(id: String, map_json: String) -> Dictionary:
	var path := FOLDER+id+".population.json"
	var read := PopulationStore.load_source(path)
	var map_read := MapStore.load_source(map_json)
	if not read.ok or not map_read.ok: return {"ok":false,"code":"read_failed"}
	var carried := Carry.map_into_population(read.data,map_read.data)
	if not carried.ok: return carried
	_write(id+".population.json",encode(carried.source))
	var slots_equal: bool = carried.source.slots == read.data.slots
	return {"ok":true,"id":id,"roundtrip":_roundtrip(path,read.data),"hash_before":PopulationDocument.hash_source(read.data),"hash_after":carried.source_hash,"compiled_hash":carried.compiled_hash,"diff":carried.diff,
		"slots_identical":slots_equal,"plan_hash_before":read.data.plan_hash,"plan_hash_after":carried.source.plan_hash}

## Same as carry_forward.map_into_population when no instance moved: the anchor
## rebind is skipped (an identity transform), so every authored anchor keeps its
## exact literal and surface; the plan is re-certified keeping every slot and the
## encounters are compiled. The canonical carry re-wrote every anchor as float32 and
## re-tied anchors lying exactly on grid-cell borders to the neighbouring cell
## (valleys: 7), a change without geometric cause, so it is not used for publication.
static func same_layout(old_map: Dictionary, new_map: Dictionary) -> bool:
	var a: Dictionary = old_map.duplicate(true); var b: Dictionary = new_map.duplicate(true)
	a.erase("pieces"); b.erase("pieces")
	for instance: Dictionary in a.instances: instance.erase("piece_hash")
	for instance: Dictionary in b.instances: instance.erase("piece_hash")
	return a == b and old_map.pieces.size() == new_map.pieces.size()

func _population_keep(id: String, map_json: String) -> Dictionary:
	var path := FOLDER+id+".population.json"
	var read := PopulationStore.load_source(path)
	var map_read := MapStore.load_source(map_json)
	if not read.ok or not map_read.ok: return {"ok":false,"code":"read_failed"}
	var population: Dictionary = read.data; var map: Dictionary = map_read.data
	if not PopulationDocument.validate(population).ok or not MapDocument.validate(map).ok: return {"ok":false,"code":"flow_invalid"}
	if not same_layout(population.map[0],map): return {"ok":false,"code":"layout_changed"}
	if population.plan_hash != PopulationDocument.recipe_hash(population): return {"ok":false,"code":"plan_not_realized"}
	var data: Dictionary = population.duplicate(true); data.map = [map.duplicate(true)]
	var kept: Array = []
	for slot: Dictionary in data.slots:
		if not slot.fixed: kept.append(slot.slot_id)
	if kept.size() > Carry.KEEP_LIMIT: return {"ok":false,"code":"flow_plan_too_large"}
	var redrawn := Population.regenerate(data,Callable(),{"keep":kept,"redraw":false})
	if not redrawn.ok: return redrawn
	data.slots = redrawn.data.slots; data.plan_hash = redrawn.data.plan_hash
	var compiled := Population.compile(data)
	if not compiled.ok: return compiled
	_write(id+".population.json",encode(data))
	var others := true
	for key: String in population:
		if key not in ["map","plan_hash"] and population[key] != data[key]: others = false
	var text_others := true
	for key: String in population:
		if key not in ["map","plan_hash"] and JSON.stringify(population[key],"",true,true) != JSON.stringify(data[key],"",true,true): text_others = false
	return {"ok":true,"id":id,"roundtrip":_roundtrip(path,population),"hash_before":PopulationDocument.hash_source(population),"hash_after":PopulationDocument.hash_source(data),"compiled_hash":compiled.output_hash,
		"slots_identical":data.slots == population.slots,"only_map_and_plan_hash_changed":others and text_others,"plan_hash_before":population.plan_hash,"plan_hash_after":data.plan_hash}

## carry_forward.map_into_population split in two processes (the 300 s wrapper limit):
## the same index/rebind/regenerate steps here, then the population compile below,
## which fills the compile cache for the patrol step.
func _recertify(id: String, map_json: String) -> Dictionary:
	var path := FOLDER+id+".population.json"
	var read := PopulationStore.load_source(path)
	var map_read := MapStore.load_source(map_json)
	if not read.ok or not map_read.ok: return {"ok":false,"code":"read_failed"}
	var population: Dictionary = read.data; var map: Dictionary = map_read.data
	if not PopulationDocument.validate(population).ok or not MapDocument.validate(map).ok: return {"ok":false,"code":"flow_invalid"}
	var old_map: Dictionary = population.map[0]
	var planned: bool = population.plan_hash == PopulationDocument.recipe_hash(population)
	if not planned: return {"ok":false,"code":"plan_not_realized"}
	var base := Carry.Root.index(old_map)
	var after := Carry.Root.index(map)
	if not base.ok or not after.ok: return {"ok":false,"code":"index_failed"}
	var data: Dictionary = population.duplicate(true); data.map = [map.duplicate(true)]
	var rebound := Carry._rebind(Carry.Root.anchors("population",data),old_map,map,base,after,"population")
	if not rebound.ok: return rebound
	var kept: Array = []
	for slot: Dictionary in data.slots:
		if not slot.fixed: kept.append(slot.slot_id)
	if kept.size() > Carry.KEEP_LIMIT: return {"ok":false,"code":"flow_plan_too_large"}
	var redrawn := Population.regenerate(data,Callable(),{"keep":kept,"redraw":false})
	if not redrawn.ok: return redrawn
	data.slots = redrawn.data.slots; data.plan_hash = redrawn.data.plan_hash
	_write(id+".population.json",encode(data))
	return {"ok":true,"id":id,"roundtrip":_roundtrip(path,population),"hash_before":PopulationDocument.hash_source(population),"hash_after":PopulationDocument.hash_source(data),
		"anchors_moved":rebound.moved,"anchors_settled":rebound.settled,"slots_kept":data.slots.size(),"slots_identical":data.slots == population.slots,"plan_hash_before":population.plan_hash,"plan_hash_after":data.plan_hash}

func _popcompile(id: String, population_json: String) -> Dictionary:
	var read := PopulationStore.load_source(population_json)
	if not read.ok: return {"ok":false,"code":"read_failed"}
	var compiled := Population.compile(read.data)
	if not compiled.ok: return compiled
	return {"ok":true,"id":id,"compiled_hash":compiled.output_hash,"source_hash":PopulationDocument.hash_source(read.data)}

func _patrol(id: String, population_json: String, keep: bool = false) -> Dictionary:
	var path := FOLDER+id+".patrol.json"
	var read := PatrolStore.load_source(path)
	var population_read := PopulationStore.load_source(population_json)
	if not read.ok or not population_read.ok: return {"ok":false,"code":"read_failed"}
	var carried: Dictionary
	if keep:
		# Identity rebind (same layout): waypoints keep their literals; routes keep their slots.
		var old_population: Dictionary = read.data.population[0]
		if not same_layout(old_population.map[0],population_read.data.map[0]): return {"ok":false,"code":"layout_changed"}
		var slots := {}
		for slot: Dictionary in population_read.data.slots: slots[slot.slot_id] = true
		for route: Dictionary in read.data.patrols:
			for slot_id: String in route.slot_ids:
				if not slots.has(slot_id): return {"ok":false,"code":"flow_slot_missing"}
		var data: Dictionary = read.data.duplicate(true); data.population = [population_read.data.duplicate(true)]
		carried = {"ok":true,"source":data,"diff":{"mode":"identity_rebind","routes":data.patrols.size(),"slots_kept":population_read.data.slots.size()}}
	else:
		carried = Carry.population_into_patrol(read.data,population_read.data)
	if not carried.ok: return carried
	var stamp := Time.get_ticks_usec()
	var compiled := Patrol.compile(carried.source)
	if not compiled.ok: return compiled
	var published := _publication(id,compiled.package,carried.source)
	published["roundtrip"] = _roundtrip(path,read.data); published["carry"] = carried.diff
	published["routes_identical"] = carried.source.patrols == read.data.patrols and JSON.stringify(carried.source.patrols,"",true,true) == JSON.stringify(read.data.patrols,"",true,true)
	published["patrol_compile_ms"] = (Time.get_ticks_usec()-stamp)/1000.0
	return published

## MapRelease.publish's checks and bytes, written to the evidence folder instead of res://.
func _publication(id: String, package: Dictionary, source: Dictionary) -> Dictionary:
	if not PatrolDocument.validate(source).ok or PatrolDocument.hash_source(source) != package.source_hash: return {"ok":false,"code":"release_stale_source"}
	if not Patrol.validate_package(package): return {"ok":false,"code":"release_package_invalid"}
	var payload := var_to_bytes(package)
	var bytes := ("RPP1"+Schema.bytes_hash(payload)).to_utf8_buffer()+payload
	if bytes.size() > Patrol.MAX_PACKAGE_BYTES: return {"ok":false,"code":"release_package_invalid"}
	var current := Release.entry(id)
	var name: String = current.entry.name if current.ok else id
	var file_name := Release.package_file(id,package.package_hash)
	_write(file_name,bytes); _write(Release.source_file(id),encode(source))
	var pinned := {"package_id":id,"name":name,"kind":"patrol","path":FOLDER.path_join(file_name),"source_path":FOLDER.path_join(Release.source_file(id)),"compiler_revision":package.compiler_revision,"source_hash":package.source_hash,"package_hash":package.package_hash}
	_write(id+".entry.json",JSON.stringify(pinned,"\t",false).to_utf8_buffer())
	return {"ok":true,"id":id,"entry":pinned,"previous":current.get("entry",{}),"rpp":file_name,"rpp_bytes":bytes.size(),"rpp_sha256":Schema.bytes_hash(bytes)}

func _republish(id: String) -> Dictionary:
	var current := Release.entry(id)
	if not current.ok: return current
	var read := PatrolStore.load_source(current.entry.source_path)
	if not read.ok: return read
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var compiled := Patrol.compile(read.data)
	if not compiled.ok: return compiled
	if compiled.package.source_hash != current.entry.source_hash: return {"ok":false,"code":"source_changed"}
	var published := _publication(id,compiled.package,read.data)
	published["source_unchanged"] = encode(read.data) == FileAccess.get_file_as_bytes(current.entry.source_path)
	return published

func _file(source_path: String, name: String) -> Dictionary:
	var read := PatrolStore.load_source(source_path)
	if not read.ok: return read
	OS.set_environment("RAGRPG_COMPILE_CACHE","0")
	var compiled := Patrol.compile(read.data)
	if not compiled.ok: return compiled
	var payload := var_to_bytes(compiled.package)
	var bytes := ("RPP1"+Schema.bytes_hash(payload)).to_utf8_buffer()+payload
	_write(name,bytes)
	return {"ok":true,"package_hash":compiled.package.package_hash,"source_hash":compiled.package.source_hash,"rpp_sha256":Schema.bytes_hash(bytes)}

func _registry(entries: Array) -> Dictionary:
	var current := Release.registry()
	if not current.ok: return current
	var listing: Dictionary = current.registry.duplicate(true)
	var replaced: Array = []
	for path: String in entries:
		var pinned: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not pinned is Dictionary: return {"ok":false,"code":"entry_invalid","path":path}
		var ordered := {}
		for key: String in Release.KEYS: ordered[key] = pinned[key]
		for index: int in listing.packages.size():
			if listing.packages[index].package_id == ordered.package_id: listing.packages[index] = ordered; replaced.append(ordered.package_id)
	if not Release.valid_registry(listing): return {"ok":false,"code":"release_registry_invalid"}
	_write("release_packages.json",(JSON.stringify(listing,"\t",false)+"\n").to_utf8_buffer())
	return {"ok":true,"replaced":replaced,"previous_registry_sha256":current.registry_hash}

func _bake(id: String) -> Dictionary:
	var baked := Release.bake_preparation(id)
	if not baked.ok: return baked
	baked.erase("bundle")
	return baked
