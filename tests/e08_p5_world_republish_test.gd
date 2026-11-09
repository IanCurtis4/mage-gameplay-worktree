extends SceneTree
## E08 P5 B2b invariants: the forest maps republished with the new grass/earth/sand
## materials and the prop variants keep geometry, navigation, encounters, routes and
## every physical body of the previous immutable revisions. Only material/prop asset
## dependencies, swapped visual definition ids and the hashes that cover them change.
## The previous .rpp/.navproof bytes stay on disk; they are decoded here without the
## current-dependency validation (which now refuses them, by design).
const Release = preload("res://scripts/map_authoring/release/map_release.gd")
const PatrolStore = preload("res://scripts/map_authoring/patrol/patrol_store.gd")
const Catalog = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Materials = preload("res://scripts/map_authoring/terrain/terrain_material.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const SourceStore = preload("res://scripts/map_authoring/io/source_store.gd")
const FOLDER := "res://data/map_authoring/"
const PREVIOUS := {
	"forest_terraces": {"rpp":"forest_terraces.d9d52701a7a4.rpp","package_hash":"d9d52701a7a40124969d94f1770ef9f3cc3d0f609691afc02ebae48ccdf665ce","oaks":132,"shrubs":90,"boulders":16},
	"forest_valleys": {"rpp":"forest_valleys.2faa15085074.rpp","package_hash":"2faa15085074a74ddec8ba0fa48bc27213e18076a0f37ea7706dc64f30db3dbb","oaks":48,"shrubs":40,"boulders":14},
	"forest_lair": {"rpp":"forest_lair.c19cad53def8.rpp","package_hash":"c19cad53def80a9191ad8782a0d7d7ce2b80d531a6fba4a34c44f169ca28d39b","oaks":10,"shrubs":14,"boulders":0},
}
const SANCTUARY_SOURCE_HASH := "58df5d6386a6222e838763d92a96072ff71ebf2daed168b475ab003d95e29dc1"
const DECOR := ["fern_cluster","wildflower_patch","fallen_log","mushroom_ring"]
## Physical/placement semantics a variant must share with the definition it replaces.
const PHYSICAL := ["footprint_radius","body_box_xyz","max_slope_degrees","allowed_rotations","rotation_mode","capabilities","revision"]
var checks: Array[Dictionary] = []
var report := {}

func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("E08_P5_WORLD_CHECK "+id+" "+str(ok))

static func raw_package(path: String) -> Variant:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 72 or bytes.slice(0,4).get_string_from_utf8() != "RPP1": return null
	var payload := bytes.slice(68)
	if Schema.bytes_hash(payload) != bytes.slice(4,68).get_string_from_utf8(): return null
	return bytes_to_var(payload)

static func raw_proof(path: String) -> Variant:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 76 or bytes.slice(0,4).get_string_from_utf8() != "RNP1": return null
	var payload := bytes.slice(68)
	if Schema.bytes_hash(payload) != bytes.slice(4,68).get_string_from_utf8(): return null
	return bytes_to_var(payload)

## Paths where a and b differ (bounded), for the report.
static func diff(a: Variant, b: Variant, path: String, out: Array, limit: int = 40) -> void:
	if out.size() >= limit: return
	if typeof(a) != typeof(b): out.append(path); return
	if a is Dictionary:
		var keys := {}
		for k: Variant in a: keys[k] = true
		for k: Variant in b: keys[k] = true
		for k: Variant in keys:
			if not a.has(k) or not b.has(k): out.append(path+"/"+str(k)); continue
			if a[k] != b[k]: diff(a[k],b[k],path+"/"+str(k),out,limit)
	elif a is Array:
		if a.size() != b.size(): out.append(path+"[size]"); return
		for i: int in a.size():
			if a[i] != b[i]: diff(a[i],b[i],path+"["+str(i)+"]",out,limit)
	elif a != b: out.append(path)

## Deep copy with every string equal to `from` replaced by `to`.
static func renamed(value: Variant, from: String, to: String) -> Variant:
	if value is String: return to if value == from else value
	if value is Dictionary:
		var result := {}
		for key: Variant in value: result[renamed(key,from,to)] = renamed(value[key],from,to)
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(renamed(item,from,to))
		return result
	return value

## Independent flatness check: ground height on a 48-unit circle (16 samples)
## within 8 units of the centre, bilinear on the placement's height-grid layer.
static func height(layer: Dictionary, x: float, z: float) -> float:
	var columns: int = int(layer.columns); var spacing := float(layer.sample_spacing)
	var fx := (x-float(layer.origin_xz[0]))/spacing; var fz := (z-float(layer.origin_xz[1]))/spacing
	if fx < 0.0 or fz < 0.0 or fx > columns-1 or fz > int(layer.rows)-1: return NAN
	var i := mini(int(fx),columns-2); var j := mini(int(fz),int(layer.rows)-2)
	var h: Array = layer.heights
	return lerpf(lerpf(float(h[j*columns+i]),float(h[j*columns+i+1]),fx-i),lerpf(float(h[(j+1)*columns+i]),float(h[(j+1)*columns+i+1]),fx-i),fz-j)

static func flat(piece: Dictionary, placement: Dictionary) -> bool:
	if placement.is_empty(): return false
	for layer: Dictionary in piece.layers:
		if layer.layer_id != placement.surface_id: continue
		var p: Array = placement.position_xyz
		var centre := height(layer,float(p[0]),float(p[2]))
		if is_nan(centre): return false
		for k: int in 16:
			var value := height(layer,float(p[0])+48.0*cos(k*PI/8.0),float(p[2])+48.0*sin(k*PI/8.0))
			if is_nan(value) or absf(value-centre) > 8.0: return false
		return true
	return false

static func ranked(ids: Array, salt: String) -> Array:
	var copy := ids.duplicate()
	copy.sort_custom(func(x: String,y: String) -> bool: return (salt+x).sha256_text() < (salt+y).sha256_text())
	return copy

static func quota(count: int, percent: int) -> int: return (count*percent+50)/100

## Objects of every render instance, by placement id.
static func objects(package: Dictionary) -> Dictionary:
	var result := {}
	for instance: Dictionary in package.population_package.map_package.render_instances:
		for object: Dictionary in instance.get("objects",[]): result[String(instance.get("instance_id",""))+"/"+String(object.placement_id)] = object
	return result

## The map package without the object records' definition ids/copies and the
## asset dependencies; everything physical and navigational stays in.
static func strip_visual(map_package: Dictionary) -> Dictionary:
	var copy: Dictionary = map_package.duplicate(true)
	copy.erase("package_hash"); copy.erase("dependencies"); copy.erase("source_hash")
	for instance: Dictionary in copy.render_instances:
		instance.erase("piece_hash"); instance.erase("dependencies"); instance.erase("package_hash")
		for object: Dictionary in instance.get("objects",[]): object.erase("definition_id"); object.erase("definition")
	for instance: Dictionary in copy.realized_instances:
		instance.erase("piece_hash")
	return copy

func run() -> void:
	var catalog := Catalog.load_catalog()
	check("catalog_loads_with_variants",catalog.ok and catalog.revision == 3 and catalog.definitions.size() == 11)
	if not catalog.ok: finish(); return
	var oak: Dictionary = catalog.definitions.oak_tree; var shrub: Dictionary = catalog.definitions.woodland_shrub
	var birch: Dictionary = catalog.definitions.birch_tree
	check("birch_has_oak_physical_semantics",PHYSICAL.all(func(key: String) -> bool: return birch[key] == oak[key]) and birch.biome_ids == oak.biome_ids and birch.category == oak.category)
	check("birch_has_its_own_visual",birch.sprite_path != oak.sprite_path and birch.sprite_sha256 != oak.sprite_sha256)
	var decor_ok := true
	for id: String in DECOR:
		var item: Dictionary = catalog.definitions[id]
		decor_ok = decor_ok and PHYSICAL.all(func(key: String) -> bool: return item[key] == shrub[key])
		decor_ok = decor_ok and item.capabilities == {"decoration":true,"body":false,"attack_los":false,"camera_occlusion":false} and item.body_box_xyz == [0,0,0,0,0,0]
	check("decor_variants_are_decoration_only_with_shrub_placement_rules",decor_ok)
	check("stone_slot_keeps_cliff_tile",Materials.STONE_PATH == "res://assets/art/map_authoring/cliff_tile.png" and Materials.REVISION == "terrain_material_v3")
	var old_tiles := ["grass_tile.png","earth_tile.png","sand_tile.png"].all(func(name: String) -> bool: return FileAccess.file_exists("res://assets/art/map_authoring/"+name))
	check("previous_material_files_kept",old_tiles and Materials.GRASS_PATH.ends_with("grass_tile_v2.png") and Materials.EARTH_PATH.ends_with("earth_tile_v2.png") and Materials.SAND_PATH.ends_with("sand_tile_v2.png"))
	var material_paths := {}
	for dependency: Dictionary in Materials.dependencies(): material_paths[dependency.path] = true
	for id: String in PREVIOUS:
		_map(id,catalog,material_paths)
	var registry := Release.registry()
	var sanctuary := Release.entry("sanctuary_woods")
	check("sanctuary_source_unchanged_and_loads",sanctuary.ok and sanctuary.entry.source_hash == SANCTUARY_SOURCE_HASH and Release.load_package("sanctuary_woods").ok)
	check("representative_reference_loads",PatrolStore.load_package(FOLDER+"representative.rpp").ok)
	check("registry_valid",registry.ok)
	finish()

func _map(id: String, catalog: Dictionary, material_paths: Dictionary) -> void:
	var previous: Dictionary = PREVIOUS[id]
	var started := Time.get_ticks_usec()
	var loaded := Release.load_package(id)
	report[id] = {"load_ms":(Time.get_ticks_usec()-started)/1000.0}
	check(id+"_new_revision_loads_pinned",loaded.ok and loaded.package.package_hash != previous.package_hash)
	if not loaded.ok: return
	var now: Dictionary = loaded.package
	var old_value: Variant = raw_package(FOLDER+previous.rpp)
	check(id+"_previous_revision_bytes_intact",old_value is Dictionary and old_value.package_hash == previous.package_hash)
	if not old_value is Dictionary: return
	var old: Dictionary = old_value
	check(id+"_previous_revision_refused_by_current_dependencies",not PatrolStore.load_package(FOLDER+previous.rpp).ok)
	# The composed part is named "piece_"+piece_hash (map_compiler), and the piece hash
	# covers the placements, so the only manifest difference allowed is that name.
	var old_part: String = old.manifest.input.parts[0].part_id; var new_part: String = now.manifest.input.parts[0].part_id
	report[id]["part_id"] = [old_part,new_part]
	check(id+"_part_renamed_by_piece_hash_only",old.manifest.input.parts.size() == 1 and old_part.begins_with("piece_") and new_part.begins_with("piece_") and old_part != new_part)
	# Encounters, routes, navigation surfaces, objectives and portals.
	var old_manifest: Variant = renamed(old.manifest,old_part,new_part)
	var manifest_diff: Array = []; diff(old_manifest,now.manifest,"manifest",manifest_diff)
	report[id]["manifest_diff_after_part_rename"] = manifest_diff
	check(id+"_patrol_manifest_identical_up_to_part_name",old_manifest == now.manifest)
	var old_population: Dictionary = renamed(old.population_package,old_part,new_part); var new_population: Dictionary = now.population_package
	check(id+"_population_manifest_rules_profile_identical",old_population.manifest == new_population.manifest and old_population.rules == new_population.rules and old_population.profile == new_population.profile)
	check(id+"_population_catalog_and_policy_identical",old_population.catalog_hash == new_population.catalog_hash and old_population.policy_hash == new_population.policy_hash)
	var old_map: Dictionary = old_population.map_package; var new_map: Dictionary = new_population.map_package
	check(id+"_map_manifest_barriers_borders_identical",old_map.manifest == new_map.manifest and old_map.barriers == new_map.barriers and old_map.border_spans == new_map.border_spans and old_map.border_geometry == new_map.border_geometry and old_map.border_selection == new_map.border_selection)
	var stripped_diff: Array = []; diff(strip_visual(old_map),strip_visual(new_map),"map_package",stripped_diff)
	report[id]["map_package_diff_without_visual_ids"] = stripped_diff
	check(id+"_map_package_equal_except_visual_definitions",stripped_diff.is_empty())
	# Every object: same placement, position, rotation, surface and body; swaps are the allowed ones.
	var before := objects(old); var after := objects(now)
	var same_set := before.keys().size() == after.keys().size() and before.keys().all(func(key: String) -> bool: return after.has(key))
	var swaps := {}; var bodies_ok := true; var allowed := true
	if same_set:
		for key: String in before:
			var a: Dictionary = before[key]; var b: Dictionary = after[key]
			if a.position != b.position or a.rotation_y != b.rotation_y or a.surface_id != b.surface_id or a.source_surface_id != b.source_surface_id or a.get("body_volume") != b.get("body_volume") or a.has("body_volume") != b.has("body_volume"): bodies_ok = false
			if a.definition_id == b.definition_id:
				if a.definition != b.definition: allowed = false
				continue
			var pair: String = a.definition_id+"->"+b.definition_id
			swaps[pair] = int(swaps.get(pair,0))+1
			if not (a.definition_id == "oak_tree" and b.definition_id == "birch_tree") and not (a.definition_id == "woodland_shrub" and b.definition_id in DECOR): allowed = false
			if b.definition != catalog.definitions[b.definition_id]: allowed = false
	report[id]["swaps"] = swaps
	check(id+"_same_placements_positions_bodies",same_set and bodies_ok)
	check(id+"_only_oak_to_birch_and_shrub_to_decor",same_set and allowed)
	# The documented rule, recomputed independently from the previous revision.
	var oak_ids: Array = []; var shrub_ids: Array = []; var boulders := 0
	for key: String in before:
		var definition_id: String = before[key].definition_id
		if definition_id == "oak_tree": oak_ids.append(String(before[key].placement_id).get_file())
		elif definition_id == "woodland_shrub": shrub_ids.append(String(before[key].placement_id).get_file())
		elif definition_id == "moss_boulder": boulders += 1
	check(id+"_previous_counts",oak_ids.size() == previous.oaks and shrub_ids.size() == previous.shrubs and boulders == previous.boulders)
	var expected := {}
	var birch_ids := ranked(oak_ids,"e08_p5_b2b/birch/").slice(0,quota(oak_ids.size(),25))
	for pid: String in birch_ids: expected[pid] = "birch_tree"
	var decor_ids := ranked(shrub_ids,"e08_p5_b2b/decor/")
	var decor_total := quota(shrub_ids.size(),40)
	var quotas := {"fern_cluster":quota(decor_total,40),"wildflower_patch":quota(decor_total,30),"fallen_log":quota(decor_total,15)}
	quotas["mushroom_ring"] = decor_total-int(quotas.fern_cluster)-int(quotas.wildflower_patch)-int(quotas.fallen_log)
	# Fallen logs and wildflower patches only on flat sites (first flat candidates in
	# rank order, log first); fern and mushroom fill the rest in rank order.
	var source := SourceStore.load_source(FOLDER+id+".source.json")
	var sites := {}
	if source.ok:
		for placement: Dictionary in source.data.placements: sites[placement.placement_id] = placement
	var rest: Array = decor_ids.slice(0,decor_total)
	for variant: String in ["fallen_log","wildflower_patch"]:
		var placed := 0; var left: Array = []
		for pid: String in rest:
			if placed < int(quotas[variant]) and source.ok and flat(source.data,sites[pid]): expected[pid] = variant; placed += 1
			else: left.append(pid)
		quotas.fern_cluster = int(quotas.fern_cluster)+int(quotas[variant])-placed; quotas[variant] = placed
		rest = left
	var cursor := 0
	for variant: String in ["fern_cluster","mushroom_ring"]:
		for j: int in int(quotas[variant]): expected[rest[cursor+j]] = variant
		cursor += int(quotas[variant])
	var flat_sites: bool = source.ok
	for key: String in after:
		if after[key].definition_id in ["fallen_log","wildflower_patch"] and not flat(source.data,sites.get(String(after[key].placement_id).get_file(),{})): flat_sites = false
	check(id+"_logs_and_wildflowers_only_on_flat_sites",flat_sites and int(quotas.fallen_log) > 0 and int(quotas.wildflower_patch) > 0)
	var rule_ok := true; var swapped := 0
	for key: String in after:
		var pid := String(after[key].placement_id).get_file()
		var want: String = expected.get(pid,String(before[key].definition_id))
		if after[key].definition_id != want: rule_ok = false
		if after[key].definition_id != before[key].definition_id: swapped += 1
	report[id]["birch"] = birch_ids.size(); report[id]["decor"] = decor_total
	check(id+"_deterministic_rule_applied",rule_ok and swapped == expected.size() and birch_ids.size()*4 >= oak_ids.size()-2 and birch_ids.size()*4 <= oak_ids.size()+2)
	check(id+"_shrubs_stay_dominant_decoration",shrub_ids.size()-decor_total > decor_total)
	# Asset dependencies: only material textures, the prop catalog and the new sprites differ.
	var old_dependencies := {}; var new_dependencies := {}
	for dependency: Dictionary in old_map.dependencies: old_dependencies[dependency.path] = dependency
	for dependency: Dictionary in new_map.dependencies: new_dependencies[dependency.path] = dependency
	var changed: Array = []
	for path: String in old_dependencies:
		if not new_dependencies.has(path) or new_dependencies[path] != old_dependencies[path]: changed.append(path)
	for path: String in new_dependencies:
		if not old_dependencies.has(path): changed.append(path)
	changed.sort(); report[id]["dependency_paths_changed"] = changed
	var dependency_ok := not changed.is_empty()
	for path: String in changed:
		var material_texture: bool = material_paths.has(path) or path.trim_suffix(".import").get_file() in ["grass_tile.png","earth_tile.png","sand_tile.png"]
		var prop_asset: bool = path == Catalog.PATH or path.trim_suffix(".import").get_file().get_basename() in ["birch_tree","fern_cluster","wildflower_patch","mushroom_ring","fallen_log"]
		if not material_texture and not prop_asset: dependency_ok = false
		if path.contains("cliff_tile") or path.contains("water_tile") or path.ends_with(".gdshader"): dependency_ok = false
	check(id+"_only_material_and_prop_dependencies_changed",dependency_ok)
	# Navigation proof: same positive witnesses, re-pinned to the new package.
	var old_proof: Variant = raw_proof(FOLDER+previous.rpp.trim_suffix(".rpp")+".navproof")
	var new_proof: Variant = raw_proof(Release.proof_path(loaded.entry))
	check(id+"_navproof_pins_new_package",new_proof is Dictionary and new_proof.package_hash == now.package_hash and old_proof is Dictionary and old_proof.package_hash == previous.package_hash)
	# Each proof key hashes the stage record (which names the part); the witnesses
	# themselves (roots, nodes, paths, targets) must be identical.
	var proof_diff: Array = []; var keys_differ := true
	if new_proof is Dictionary and old_proof is Dictionary:
		var a: Dictionary = old_proof.bundle.duplicate(true); var b: Dictionary = new_proof.bundle.duplicate(true)
		keys_differ = a.proofs.size() == b.proofs.size() and a.proofs.size() > 0
		for k: int in mini(a.proofs.size(),b.proofs.size()):
			keys_differ = keys_differ and a.proofs[k].get("key") != b.proofs[k].get("key")
			a.proofs[k].erase("key"); b.proofs[k].erase("key")
		diff(renamed(a,old_part,new_part),b,"navproof",proof_diff)
	report[id]["navproof_diff_without_keys"] = proof_diff
	check(id+"_navproof_witnesses_identical",new_proof is Dictionary and old_proof is Dictionary and proof_diff.is_empty() and keys_differ)

func finish() -> void:
	var ok := not checks.is_empty() and checks.all(func(value: Dictionary) -> bool: return value.ok)
	print("E08_P5_WORLD_REPORT "+JSON.stringify(report))
	print("E08_P5_WORLD_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
