extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f0/fixture_input.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	if not Fixture.sources_current(): push_error("stale fixture sources; run e07_f0_import_test"); quit(1); return
	_run.call_deferred()
func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; push_error(label)
func _run() -> void:
	var input := Fixture.make()
	var before := ExpeditionCanonical.encode(input.to_data())
	var first := ExpeditionAssembler.build(input)
	check(first["ok"],"real branching generation succeeds")
	if not first["ok"]: print(first); quit(1); return
	var manifest: ExpeditionManifest = first["data"]["manifest"]
	var hash_value: String = first["data"]["hash"]
	var repeated := ExpeditionAssembler.build(input)
	check(repeated["ok"] and repeated["data"]["hash"] == hash_value,"same complete input reproduces manifest")
	check(ExpeditionCanonical.encode(repeated["data"]["manifest"].to_data()) == ExpeditionCanonical.encode(manifest.to_data()),"canonical bytes reproduce, not just selected fields")
	check(before == ExpeditionCanonical.encode(input.to_data()),"I01 all input Resources and recipe unchanged")
	input.parts.reverse(); input.species.reverse(); input.policies.reverse(); input.stages.reverse(); input.portals.reverse(); input.population.reverse(); input.objectives.reverse()
	for stage: Dictionary in input.stages:
		stage["parts"].reverse()
		for node: Dictionary in stage["parts"]: node["candidates"].reverse()
	for part: ExpeditionPartDefinition in input.parts:
		part.connectors.reverse(); part.sockets.reverse(); part.surfaces.reverse(); part.allowed_rotations.reverse()
	var reordered := ExpeditionAssembler.build(input)
	check(reordered["ok"] and reordered["data"]["hash"] == hash_value,"candidate/input order is not entropy")
	input.request_id = "another_transport_request"
	check(ExpeditionAssembler.build(input)["data"]["hash"] == hash_value,"request transport identity excluded from content")
	var changed := Fixture.make()
	changed.parts[0].revision += 1
	check(ExpeditionAssembler.build(changed)["data"]["hash"] != hash_value,"part revision captured")
	changed = Fixture.make(); changed.recipe_revision += 1
	check(ExpeditionAssembler.build(changed)["data"]["hash"] != hash_value,"recipe revision captured")
	changed = Fixture.make(); changed.catalog_revision = "fixture_catalog_v2"
	check(ExpeditionAssembler.build(changed)["data"]["hash"] != hash_value,"catalog revision captured")
	changed = Fixture.make(); changed.policies[2].revision += 1
	check(ExpeditionAssembler.build(changed)["data"]["hash"] != hash_value,"policy revision captured")
	changed = Fixture.make(); changed.objectives[0]["revision"] += 1
	check(ExpeditionAssembler.build(changed)["data"]["hash"] != hash_value,"captured objective revision")
	changed = Fixture.make(); changed.parts[1].sockets[0].position.x += 0.000001
	check(ExpeditionAssembler.build(changed)["data"]["hash"] != hash_value,"geometry digest preserves significant float bits")
	check(ExpeditionCanonical.encode({"b":2,"a":1}) == ExpeditionCanonical.encode({"a":1,"b":2}),"dictionary key order canonical")
	check(ExpeditionCanonical.encode(0.0) == ExpeditionCanonical.encode(-0.0),"negative zero normalized")
	check(ExpeditionCanonical.encode(1.0) != ExpeditionCanonical.encode(1),"numeric types not conflated")
	check(ExpeditionCanonical.encode(9223372036854775807) != ExpeditionCanonical.encode(9223372036854775806),"int64 encoded without JSON rounding")
	var layouts := {}
	var corpus: Array[String] = ["0","1","-1","42","2147483647","-2147483648","9223372036854775807","-9223372036854775808","666","999999999999999","17","18"]
	for seed_value: String in corpus:
		var seeded := Fixture.make(seed_value)
		var a := ExpeditionAssembler.build(seeded)
		var b := ExpeditionAssembler.build(seeded)
		check(a["ok"] and b["ok"],"adversarial seed generates "+seed_value)
		if not a["ok"] or not b["ok"]: continue
		check(a["data"]["hash"] == b["data"]["hash"],"seed reproduces "+seed_value)
		check(a["data"]["diagnostic"]["expansions"] <= 4096 and a["data"]["diagnostic"]["attempts"] <= 32,"finite work "+seed_value)
		var layout: Array = []
		for stage: Dictionary in a["data"]["manifest"].to_data()["stages"]: layout.append(stage["part_instances"])
		layouts[ExpeditionCanonical.digest(layout)] = true
		print("seed=",seed_value," manifest_sha256=",a["data"]["hash"]," expansions=",a["data"]["diagnostic"]["expansions"])
	check(layouts.size() > 1,"seed actually changes realized part choices")
	# Native resource round trip, in ignored fixture output, with no ProfileStore or user://.
	var native := Fixture.make()
	var directory := "res://.godot/verification/e07_f0/native"
	DirAccess.make_dir_recursive_absolute(directory)
	check(ResourceSaver.save(native.parts[0],directory+"/hub.tres") == OK,"native immutable definition saved")
	var loaded := ResourceLoader.load(directory+"/hub.tres","",ResourceLoader.CACHE_MODE_IGNORE) as ExpeditionPartDefinition
	check(loaded != null and ExpeditionCanonical.digest(loaded.to_data()) == ExpeditionCanonical.digest(native.parts[0].to_data()),"native resource metadata roundtrip")
	if loaded != null: native.parts[0] = loaded
	check(ExpeditionAssembler.build(native)["data"]["hash"] == hash_value,"native reloaded part reproduces manifest")
	print("E07 F0 generation: %d checks, %d failures; baseline_sha256=%s" % [checks,failures,hash_value])
	quit(0 if failures == 0 else 1)
