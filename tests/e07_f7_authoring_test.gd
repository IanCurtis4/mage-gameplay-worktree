extends SceneTree
const Phase = preload("res://data/expedition/phases/ruined_crossing.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _run() -> void:
	var layouts := {}
	var catalog := BuildContentLoader.load_catalog_for_profile(ProfileCatalog.pilot(), true)
	check(catalog["ok"], "real catalog")
	for seed_text: String in ["42", "43", "44", "45"]:
		var input := Phase.input(seed_text)
		var before := ExpeditionCanonical.digest(input.to_data())
		var generated := ExpeditionAssembler.build(input)
		check(generated["ok"], "real assembly: " + str(generated.get("error_code")))
		if not generated["ok"]: continue
		var manifest: ExpeditionManifest = generated["data"]["manifest"]
		var data := manifest.to_data()
		var variants: Array = []
		for stage: Dictionary in data["stages"]: variants.append(stage["part_instances"])
		layouts[ExpeditionCanonical.digest(variants)] = seed_text
		check(data["stage_ids"].size() == 4 and manifest.population_plan().slots().size() == 5, "bounded four-stage authored sample, not eight-slot fixture")
		check(ExpeditionPopulationPlanner.build(manifest, catalog["catalog"].mob_catalog(), Phase.rules(manifest))["ok"], "all real species have legal paths at their actual radius")
		check(ExpeditionCanonical.digest(input.to_data()) == before, "definition resources immutable")
		check(ExpeditionAssembler.build(input)["data"]["manifest"].canonical_hash() == manifest.canonical_hash(), "seed/revisions reproduce manifest")
		check(not manifest.witness("population/entry_keeper").is_empty() and not manifest.witness("objectives/final_exit").is_empty(), "thematic keeper and final objective witnessed")
		print("F7 authored seed %s hash %s" % [seed_text, manifest.canonical_hash()])
	check(layouts.size() >= 2, "at least two realized part layouts")
	print("E07 F7 authoring: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
