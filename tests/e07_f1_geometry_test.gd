extends SceneTree
const Fixture = preload("res://tests/fixtures/e07/f1/fixture_input.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	if not Fixture.sources_current(): push_error("staged inputs differ from source"); quit(1); return
	var input := Fixture.make()
	var original := ExpeditionCanonical.digest(input.to_data())
	var result := ExpeditionAssembler.build(input)
	check(result["ok"], "unmodified F0 generates bridge fixture: "+str(result.get("data", {})))
	if not result["ok"]: quit(1); return
	var manifest: ExpeditionManifest = result["data"]["manifest"]
	var manifest_hash := manifest.canonical_hash()
	var geometry := WorldGeometry.new()
	check(geometry.configure(manifest,"sample")["ok"], "geometry consumes F0 manifest")
	var revision := geometry.geometry_revision
	var profile := input.traversal.to_data()
	var lower := Fixture.point("root",Vector3(50,0,150))
	var upper := Fixture.point("bridge",Vector3(50,40,150))
	var start := Fixture.point("root",Vector3(20,0,50))
	var slope := Fixture.point("slope",Vector3(150,20,50))
	check(geometry.position_query(slope,profile,revision)["ok"], "continuous ramp support at intermediate height")
	check(not geometry.position_query(Fixture.point("slope",Vector3(150,0,50)),profile,revision)["ok"], "ramp cannot flatten y")
	var route := geometry.path(start,upper,profile,revision)
	check(route["ok"], "real connected path to bridge")
	if route["ok"]:
		check(route["data"]["connection_ids"].size() == 3, "ramp and landing connections used")
		check(route["data"]["cost"] > start.position.distance_to(upper.position), "route measures actual 3D travel")
		check(route["data"]["points"][-1] == upper.to_data(), "path preserves exact destination")
	check(geometry.path(lower,start,profile,revision)["ok"], "walk below solid bridge")
	var large := profile.duplicate(true)
	large["height"] = 38.0
	check(not geometry.position_query(lower,large,revision)["ok"], "head intersects slab below bridge")
	large = profile.duplicate(true)
	large["radius"] = 25.0
	check(not geometry.path(lower,upper,large,revision)["ok"], "wide actor cannot cross narrow connector")
	var direct := {"geometry_rule_id": &"direct_volume", "range": 100.0}
	var attack := geometry.query_attack(direct,lower,upper,revision)
	check(attack["ok"] and attack["data"]["range_ok"] and not attack["data"]["los_ok"] and not attack["data"]["hit"], "slab blocks attacks between coincident projections")
	var airborne := geometry.sweep(Vector3(50,20,150),Vector3(50,70,150),{"radius":0.0,"height":0.0},revision)
	check(airborne["ok"] and airborne["data"]["hit"] and is_equal_approx(airborne["data"]["fraction"],0.3200002), "continuous projectile sweep catches thin slab")
	var ground := {"geometry_rule_id": &"ground_connected", "range": 100.0, "traversal": profile}
	check(not geometry.query_attack(ground,lower,upper,revision)["data"]["hit"], "ground AoE cannot jump projection to upper surface")
	ground["range"] = 1000.0
	check(geometry.query_attack(ground,lower,upper,revision)["data"]["hit"], "ground propagation follows long real connections when in range")
	var teleport := {"geometry_rule_id": &"teleport_legal", "range": 100.0, "traversal": profile}
	check(not geometry.query_attack(teleport,lower,upper,revision)["data"]["hit"], "teleport cannot cross solid slab")
	var upper_far := Fixture.point("bridge",Vector3(100,40,150))
	direct["range"] = 49.0
	check(not geometry.query_attack(direct,upper,upper_far,revision)["data"]["range_ok"], "range uses world units")
	var source := Fixture.point("root",Vector3(20,0,50))
	var target := Fixture.point("root",Vector3(80,0,50))
	check(geometry.insert_obstacle("wall",AABB(Vector3(45,0,25),Vector3(10,20,50)),revision)["ok"], "insert temporary lower wall")
	check(not geometry.path(source,target,profile,revision)["ok"], "old revision invalidates route")
	revision = geometry.geometry_revision
	check(not geometry.query_attack({"geometry_rule_id": &"direct_volume", "range":100.0},source,target,revision)["data"]["hit"], "wall blocks direct attack")
	check(geometry.query_attack(teleport,source,target,revision)["data"]["hit"], "E06 teleport crosses planar wall")
	check(geometry.path(source,target,profile,revision)["ok"], "visibility graph detours around wall")
	check(geometry.path(upper,upper_far,profile,revision)["ok"], "wall downstairs does not block upstairs")
	check(geometry.set_occupant("player",lower,profile,revision)["ok"], "occupancy registers legal support")
	check(not geometry.insert_obstacle("occupied",AABB(Vector3(45,0,145),Vector3(10,20,10)),revision)["ok"], "obstacle cannot intersect actor")
	check(geometry.remove_obstacle("wall",revision)["ok"], "remove obstacle advances revision")
	revision = geometry.geometry_revision
	var hit := geometry.resolve_surface(Vector3(50,100,150),Vector3.DOWN,[upper.surface_id,lower.surface_id],revision)
	check(hit["ok"] and hit["data"]["point"] == upper.to_data(), "pure ray resolves upper visible support")
	check(not geometry.resolve_surface(Vector3(50,100,150),Vector3.DOWN,[lower.surface_id],revision)["ok"], "hidden slab still occludes lower support")
	check(not geometry.resolve_surface(Vector3(50,100,150),Vector3.DOWN,[],revision)["ok"], "no visible support fails")
	check(not geometry.query_attack({"geometry_rule_id":&"missing","range":10.0},source,target,revision)["ok"], "unknown policy fails explicitly")
	check(not geometry.path(Fixture.point("missing",Vector3.ZERO),target,profile,revision)["ok"], "unknown surface never falls back to 2D")
	check(manifest.canonical_hash() == manifest_hash and ExpeditionCanonical.digest(input.to_data()) == original, "geometry never mutates catalog or manifest")
	print("E07 F1 geometry: %d checks, %d failures; seed=711 manifest=%s" % [checks,failures,manifest_hash])
	quit(0 if failures == 0 else 1)
