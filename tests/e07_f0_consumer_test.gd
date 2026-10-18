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
	var built := ExpeditionAssembler.build(input)
	check(built["ok"],"consumer receives real manifest")
	if not built["ok"]: print(built); quit(1); return
	var manifest: ExpeditionManifest = built["data"]["manifest"]
	var data := manifest.to_data()
	check(data["stage_ids"] == ["entry","left","right"] and data["portals"].size() == 4,"phase branches and return edges realized")
	for portal: Dictionary in data["portals"]:
		check(not manifest.witness("arrival/"+portal["portal_id"]).is_empty(),"arrival-to-entrance witness retained")
	check(data["stages"].size() == 3 and data["population"]["slots"].size() == 6,"population independent of Node instances")
	check(data["input_hash"] == ExpeditionCanonical.digest(input.to_data()),"manifest retains complete versioned input")
	var all_ids := {}
	for stage: Dictionary in data["stages"]:
		check(stage["part_instances"].size() == 4 and stage["connections"].size() == 3,"parts assembled, not fixed arena spawn jitter")
		for cell: Dictionary in stage["surfaces"]:
			check(not all_ids.has(cell["surface_id"]),"surface identity collision free")
			all_ids[cell["surface_id"]] = true
			check(manifest.surface(cell["surface_id"]) == cell,"surface lookup reads realized transform")
			check(cell["triangles"] == [[0,1,2],[0,2,3]],"authored support triangulated")
		for connection: Dictionary in stage["connections"]:
			var a := manifest.connector(connection["a_connector"])
			var b := manifest.connector(connection["b_connector"])
			check(Vector3(a["position"]).distance_to(b["position"]) < 0.00001,"world endpoints coincide")
			check(Vector3(a["outward"]).dot(b["outward"]) < -0.99999,"outward normals oppose")
			check(minf(a["width"],b["width"]) >= 1.0 and minf(a["headroom"],b["headroom"]) >= 2.0,"independent radius/height oracle")
	var plan := manifest.population_plan()
	for slot: Dictionary in plan.slots():
		var path := manifest.witness("population/"+slot["slot_id"])
		check(not path.is_empty(),"every population slot has witnessed path")
		if path.is_empty(): continue
		check(path["points"][-1] == slot["home"],"witness reaches exact home, no nearest-point repair")
		check(path["profile"]["radius"] == 0.5 and path["profile"]["height"] == 2.0,"witness captures traversal contract")
		var distance := 0.0
		for index: int in range(path["points"].size()):
			var point: Dictionary = path["points"][index]
			var cell := manifest.surface(point["surface_id"])
			check(point["stage_id"] == slot["stage_id"] and not cell.is_empty(),"WorldPoint stage/support retained")
			# Independent triangle-plane oracle; no graph helper used for this check.
			var v: Array = cell["vertices"]
			var normal: Vector3 = (Vector3(v[1])-Vector3(v[0])).cross(Vector3(v[2])-Vector3(v[0]))
			check(absf(normal.dot(Vector3(point["position"])-Vector3(v[0]))) < 0.0001,"point on realized support plane")
			if index > 0: distance += Vector3(path["points"][index-1]["position"]).distance_to(point["position"])
		check(is_equal_approx(distance,path["cost"]),"cost includes actual three-dimensional path")
		if slot["occurrence_category"] == "boss":
			check(path["connection_ids"].size() == 2 and slot["home"]["position"].y == 4.0,"memorable reachable through genuine ramp/upper support")
			var horizontal := 0.0
			for index: int in range(1,path["points"].size()):
				var a: Vector3 = path["points"][index-1]["position"]
				var b: Vector3 = path["points"][index]["position"]
				horizontal += Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
			check(path["cost"] > horizontal,"elevation adds real path length")
		check(plan.find_slot(slot["slot_id"]) == slot,"PopulationPlan query consumes concrete realized slot")
	check(not manifest.witness("objectives/quest_left").is_empty(),"captured quest route")
	var hash_value := manifest.canonical_hash()
	data["stages"].clear()
	var external := manifest.surface("entry/root/surface/floor"); external["vertices"].clear()
	var slots := plan.slots(); slots.clear()
	var external_path := manifest.witness("population/entry_boss"); external_path["points"].clear()
	check(manifest.canonical_hash() == hash_value and plan.slots().size() == 6,"query DTOs own deep copies")
	input.parts[0].surfaces[0].vertices[0] = Vector3(999,999,999)
	input.population.clear()
	check(manifest.canonical_hash() == hash_value,"manifest owns detached input and geometry")
	check(manifest.surface("missing").is_empty() and manifest.connector("missing").is_empty() and plan.find_slot("missing").is_empty(),"unknown query never fabricates result")
	print("E07 F0 consumer: %d checks, %d failures; manifest_sha256=%s" % [checks,failures,hash_value])
	quit(0 if failures == 0 else 1)
