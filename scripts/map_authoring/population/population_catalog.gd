@tool
extends RefCounted
const Canonical = preload("res://scripts/core/expedition/generation/canonical.gd")
const Phase = preload("res://data/expedition/phases/ruined_crossing.gd")
const Schema = preload("res://scripts/map_authoring/document/source_schema.gd")
const Worker = preload("res://scripts/map_authoring/population/population_worker.gd")
static func list_options() -> Dictionary:
	if Engine.is_editor_hint(): return Worker.request({"operation":"catalog"})
	var loaded := load_current()
	return {"ok":true,"options":options(loaded.catalog)} if loaded.ok else loaded
static func load_current() -> Dictionary:
	var loaded := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(),true)
	if not loaded.ok: return {"ok":false,"code":"catalog_unavailable","diagnostics":[]}
	var catalog: MobCatalog = loaded.catalog.mob_catalog()
	var records: Array = []
	for id: StringName in catalog.ids():
		var definition := catalog.get_definition(id)
		var record: Dictionary = {}
		for field: String in ["id","display_name","base_category","allowed_occurrence_categories","fixed_level","primary_attributes","modifier_sources","archetype","animation_kind","collision_radius","skill_ranks","skill_ids","card_id","origin_levels","encounter_tiers","aggro_radius","leash_radius","sight_timeout","visual_kind","summons_companion"]:
			# Canonical encoding accepts StringNames and arrays; normalize packed arrays.
			var value: Variant = definition.get(field)
			record[field] = Array(value) if value is PackedStringArray else value
		record["tint"] = definition.tint.to_html(); records.append(record)
	# StringName ordering depends on interning; content identity must use text order.
	records.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return String(a.id) < String(b.id))
	var policy := FileAccess.get_file_as_string("res://data/expedition/policies/e07_initial.json")
	# Resources can represent equivalent dictionary keys/numbers as StringName/int
	# or String/float after engine initialization. Fingerprint their semantic data.
	var normalized: Dictionary = {"records":JSON.parse_string(JSON.stringify(records,"",true,true))}
	return {"ok":true,"catalog":catalog,"hash":Schema.semantic_hash(normalized),"policy_hash":policy.sha256_text(),"effect_catalog":loaded.catalog}

static func options(catalog: MobCatalog) -> Array:
	var result: Array = []
	for id: StringName in catalog.ids():
		if id == &"animal_companion": continue
		var definition := catalog.get_definition(id)
		if definition.visual_kind == &"companion": continue
		for category: StringName in definition.allowed_occurrence_categories:
			# Only existing phase origin policies are offered. Other origins fail explicitly.
			for index: int in range(1,5):
				var origin := "trial_stage_%d"%index
				var occurrence := MobOccurrence.new(); occurrence.occurrence_id = "editor_catalog"; occurrence.mob_base_id = id; occurrence.category_id = category; occurrence.origin_id = StringName(origin)
				if occurrence.validate(catalog).ok:
					result.append({"species_id":String(id),"category":String(category),"origin_id":origin,"weight":1,"label":"%s · %s · origem %d"%[definition.display_name,{"normal":"Comum","rare":"Raro","elite":"Elite","rare_elite":"Elite raro","boss":"Chefe"}[String(category)],index]})
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return (a.species_id+"/"+a.category+"/"+a.origin_id) < (b.species_id+"/"+b.category+"/"+b.origin_id))
	return result

static func rule(spec: Dictionary) -> Dictionary:
	if spec.origin_id not in ["trial_stage_1","trial_stage_2","trial_stage_3","trial_stage_4"]: return {}
	# Reuse the phase authority; do not reproduce its reward arithmetic.
	var manifest := ExpeditionManifest.new()
	var index := int(String(spec.origin_id).get_slice("_",2))-1
	manifest._data = {"population":{"slots":[{"slot_id":"rule","stage_id":Phase.STAGES[index],"origin_id":spec.origin_id,"occurrence_category":spec.category}]}}
	return Phase.rules(manifest).rule
