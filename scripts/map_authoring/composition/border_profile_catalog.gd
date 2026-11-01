@tool
extends RefCounted
## Project-owned passive profile definitions. Imported content can reference IDs,
## never provide executable resources or substitute this catalog at runtime.
const Reader = preload("res://scripts/map_authoring/io/strict_json.gd")
const Props = preload("res://scripts/map_authoring/objects/prop_catalog.gd")
const Assets = preload("res://scripts/map_authoring/assets/asset_manifest.gd")
const PATH := "res://data/map_authoring/border_profiles.json"
const WATER_PATH := "res://assets/art/map_authoring/water_tile.png"
const BORDER_SHADER := "res://scripts/map_authoring/terrain/border_material.gdshader"
const WATER_SHADER := "res://scripts/map_authoring/terrain/water_material.gdshader"
const IDS := ["ruin_rubble_v1","forest_rootbank_v1","desert_ridge_v1","meadow_stream_v1"]
const BIOMES := ["ruin","forest","desert","meadow"]
const COMMON := ["profile_id","revision","name","geometry","outward_width","rise","base_depth","material_weights","props","minimum_spacing"]
static func fail(code: String, id: String = "") -> Dictionary:
	var message: String = {"profile_missing":"O perfil de borda escolhido não está publicado.","profile_invalid":"O catálogo de bordas precisa ser corrigido.","profile_asset_missing":"Um asset do perfil de borda está ausente ou mudou.","profile_space_conflict":"O canal invade outro piso ou obstáculo. Escolha uma transição explícita.","transition_required":"Escolha um perfil de transição para a fronteira entre estes biomas.","border_limit":"A borda excede o orçamento técnico. Simplifique a região."}.get(code,"Revise o perfil de borda.")
	return {"ok":false,"code":code,"diagnostics":[{"code":code,"entity_id":id,"field":"barrier_profile","severity":"error","message":message,"suggestion":"Selecione um perfil publicado ou revise a emenda indicada."}]}
static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))
static func load_catalog() -> Dictionary:
	if not FileAccess.file_exists(PATH): return fail("profile_missing")
	var decoded := Reader.new().decode(FileAccess.get_file_as_bytes(PATH))
	if not decoded.ok or not decoded.value is Dictionary: return fail("profile_invalid")
	var raw: Dictionary = decoded.value
	if raw.size() != 5 or not raw.has_all(["schema_version","catalog_id","revision","profiles","transitions"]) or raw.schema_version != 1 or raw.revision != 1 or raw.catalog_id != "ragrpg_editor_border_profiles" or not raw.profiles is Array or not raw.transitions is Array: return fail("profile_invalid")
	if raw.profiles.size() != 4 or raw.transitions.size() > 16: return fail("profile_invalid")
	var definitions := {}
	for entry: Variant in raw.profiles+raw.transitions:
		if not entry is Dictionary or not entry.has_all(COMMON): return fail("profile_invalid")
		var transition: bool = entry.has("pairs")
		if entry.size() != COMMON.size()+1 or not entry.profile_id is String or entry.profile_id.is_empty() or entry.profile_id.length() > 128 or definitions.has(entry.profile_id) or not entry.name is String or entry.revision != 1: return fail("profile_invalid")
		if transition:
			if entry.profile_id in IDS: return fail("profile_invalid")
			if not entry.pairs is Array or entry.pairs.is_empty() or entry.pairs.size() > 6: return fail("profile_invalid")
			for pair: Variant in entry.pairs:
				if not pair is Array or pair.size() != 2 or pair[0] not in BIOMES or pair[1] not in BIOMES or pair[0] >= pair[1]: return fail("profile_invalid")
		else:
			if entry.profile_id not in IDS or entry.get("biome_id") != BIOMES[IDS.find(entry.profile_id)]: return fail("profile_invalid")
		if entry.geometry != ("unsupported_channel" if entry.profile_id == "meadow_stream_v1" else "raised_bank"): return fail("profile_invalid")
		for field: String in ["outward_width","base_depth","minimum_spacing"]:
			if not number(entry[field]) or entry[field] <= 0 or entry[field] > 512: return fail("profile_invalid")
		if not number(entry.rise) or absf(entry.rise) > 128 or (entry.geometry == "unsupported_channel" and entry.rise >= 0) or (entry.geometry != "unsupported_channel" and entry.rise <= 0): return fail("profile_invalid")
		if not entry.material_weights is Array or entry.material_weights.size() != 4: return fail("profile_invalid")
		var total := 0.0
		for weight: Variant in entry.material_weights:
			if not number(weight) or weight < 0 or weight > 1: return fail("profile_invalid")
			total += float(weight)
		if absf(total-1.0) > 0.000000001 or not entry.props is Array or entry.props.size() > 8: return fail("profile_invalid")
		for prop: Variant in entry.props:
			if not prop is String or prop.is_empty(): return fail("profile_invalid")
		definitions[entry.profile_id] = entry.duplicate(true)
	for id: String in IDS:
		if not definitions.has(id): return fail("profile_invalid",id)
	return {"ok":true,"definitions":definitions}
static func resolve(id: String, catalog: Dictionary = {}) -> Dictionary:
	var data := catalog if not catalog.is_empty() else load_catalog()
	if not data.ok: return data
	if not data.definitions.has(id): return fail("profile_missing",id)
	return {"ok":true,"definition":data.definitions[id].duplicate(true)}
static func dependencies(definition: Dictionary) -> Dictionary:
	var paths: Array[String] = [PATH,BORDER_SHADER]; var prop_revision := 1
	var labels := {PATH:"border_profiles_json"}
	if definition.geometry == "unsupported_channel": paths.append_array([WATER_PATH,WATER_PATH+".import",WATER_SHADER])
	if not definition.props.is_empty():
		var catalog := Props.load_catalog()
		if not catalog.ok: return fail("profile_asset_missing",definition.profile_id)
		prop_revision = int(catalog.revision)
		paths.append(Props.PATH); labels[Props.PATH] = "prop_catalog_json"
		for id: String in definition.props:
			var found := Props.definition(id,catalog)
			if not found.ok: return fail("profile_asset_missing",definition.profile_id)
			labels[found.definition.sprite_path] = id+"_sprite"; labels[found.definition.sprite_path+".import"] = id+"_sprite_import"
			for path: String in [found.definition.sprite_path,found.definition.sprite_path+".import"]:
				if path not in paths: paths.append(path)
	paths.sort()
	var result: Array = []
	for path: String in paths:
		var digest := Assets.sha256(path)
		if digest.is_empty(): return fail("profile_asset_missing",definition.profile_id)
		result.append({"definition_id":labels.get(path,path.get_file().replace(".","_")),"revision":prop_revision if path == Props.PATH else 1,"path":path,"sha256":digest})
	return {"ok":true,"dependencies":result}
