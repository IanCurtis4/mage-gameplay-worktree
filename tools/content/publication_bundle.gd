extends RefCounted
## Approved publication mapping; never migrates owned instances.
const Transform = preload("res://tools/content/transform_bundle.gd")
const Directions = preload("res://tools/content/directions_bundle.gd")
const ID_MAPPING := {
	&"starter_blade": &"arena_starter_blade", &"starter_staff": &"arena_starter_staff", &"starter_bow": &"arena_starter_bow",
	&"traveler_vest": &"arena_traveler_vest", &"traveler_charm": &"arena_traveler_charm", &"riposte_blade": &"arena_riposte_blade",
	&"ember_staff": &"arena_ember_staff", &"hunters_bow": &"arena_hunters_bow", &"warden_mail": &"arena_warden_mail",
	&"channeler_robe": &"arena_channeler_robe", &"trailcoat": &"arena_trailcoat", &"prismatic_charm": &"arena_prismatic_charm",
}
const SOURCE_DIGEST := "b2480230ac8691fe155976ce4e311cfef233e6b32618a3ebd8a7c87fbd0658fd"
const PRESERVED_MOBS: Array[StringName] = [&"demo_chaser", &"demo_archer"]
static func compile() -> Dictionary:
	var editorial: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/authoring/transform_texts.json"))
	if not editorial is Dictionary: return BuildEffectCatalog.failure(&"invalid_editorial_document")
	var source := ContentAuthoring.compile_bundle(Transform.entries(), editorial)
	if not source["ok"]: return source
	if source["mechanical_digest"] != SOURCE_DIGEST: return BuildEffectCatalog.failure(&"stale_publication_source")
	var entries: Array[Dictionary] = []
	for entry: Dictionary in source["entries"]:
		var copy: Resource = entry["definition"].duplicate(true)
		if entry["origin"] == &"equipment" and ID_MAPPING.has(copy.id):
			copy.id = ID_MAPPING[copy.id]
			copy.starter = false
		entries.append({"origin": entry["origin"], "definition": copy, "purpose": entry["purpose"]})
	var legacy_count := 0
	for item: Resource in BuildContentLoader.definitions(&"equipment"):
		if item.id not in ID_MAPPING: continue
		if not item.effects.is_empty() or not item.set_id.is_empty(): return BuildEffectCatalog.failure(&"legacy_recipe_changed")
		entries.append({"origin": &"equipment", "definition": item, "purpose": "Definição histórica preservada; sem remapeamento de instância."})
		legacy_count += 1
	for mob: Resource in BuildContentLoader.definitions(&"mob"):
		if mob.id not in PRESERVED_MOBS: continue
		entries.append({"origin": &"mob", "definition": mob, "purpose": "Base demonstrativa preservada; nenhuma nova ocorrência."})
		legacy_count += 1
	if legacy_count != 14: return BuildEffectCatalog.failure(&"missing_legacy_definition")
	var prepared := ContentAuthoring.prepare(entries)
	if not prepared["ok"]: return prepared
	var checked := ContentAuthoring._catalog(entries)
	if not checked["ok"]: return checked
	return {"ok": true, "catalog": checked["catalog"], "source_catalog": source["catalog"], "entries": entries, "source_mechanical_digest": source["mechanical_digest"], "mechanical_digest": prepared["mechanical_digest"], "id_mapping": ID_MAPPING.duplicate(true)}

static func comparison(identity: String, branch: int, catalog: BuildEffectCatalog, source_catalog: BuildEffectCatalog = null) -> Dictionary:
	if source_catalog == null:
		var compiled := compile()
		if not compiled["ok"]: return compiled
		source_catalog = compiled["source_catalog"]
	var result: Dictionary = Directions.comparison(identity, branch, source_catalog)
	if not result["ok"]: return result
	var snapshot: BuildSnapshot = result["snapshot"]
	for instance: EquipmentInstance in snapshot.equipment_instances.values():
		instance.definition_id = ID_MAPPING.get(instance.definition_id, instance.definition_id)
	result["composed"] = BuildEffectComposer.compose(snapshot, result["run_effects"], [], catalog)
	if not result["composed"]["ok"]: return result["composed"]
	return result
