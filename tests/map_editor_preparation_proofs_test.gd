extends SceneTree
## Passive preparation witnesses: coverage, fresh geometry and hostile files.
const Fixture = preload("res://tests/map_editor_height_grid_navigation_test.gd")
const Cache = preload("res://scripts/core/expedition/spatial/preparation_proof_cache.gd")
const Batch = preload("res://scripts/core/expedition/spatial/world_connectivity_batch.gd")
const PROFILE := Fixture.PROFILE
const PIN := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const OTHER_PIN := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
var checks: Array[Dictionary] = []
var helper: SceneTree
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("PREPARATION_PROOFS_CHECK "+id+" "+str(ok))
func context(world: WorldGeometry, profile: Dictionary = PROFILE) -> Dictionary:
	return {"owner":world,"revision":world.geometry_revision,"configuration":world.configuration_revision,"cancellation":Callable(),"limits":Batch.LIMITS.duplicate(true),"started":Time.get_ticks_usec(),"operations":0,"last_poll":0,"error_code":&"","phase":"prepare","metrics":{},"visibility":{},"point_proofs":{},"segment_proofs":{},"snapshot_hash":Batch.signature(world).hash,"profile_hash":Batch._hash(profile).hash,"memo":world._navigation_shared_memo(profile)}
func lookup(world: WorldGeometry, from: ExpeditionWorldPoint, targets: Array[ExpeditionWorldPoint], profile: Dictionary = PROFILE) -> Dictionary:
	return Cache.try_certificate(world,from,targets,profile,world.geometry_revision,context(world,profile))
func hit(result: Dictionary) -> bool: return not result.is_empty() and result.get("ok",false)
func valid_witnesses(world: WorldGeometry, certificate: Dictionary) -> bool:
	if not hit(certificate) or not certificate.data.complete or not certificate.data.all_reachable: return false
	for index: int in certificate.data.targets.size():
		for outward: bool in [true,false]:
			var witness := world.connectivity_witness(certificate,index,outward,world.geometry_revision)
			if not witness.ok or not helper.call("route_valid",world,witness.data.points): return false
	return true
func world_for(stage: Dictionary) -> WorldGeometry:
	var manifest := ExpeditionManifest.new()
	manifest._data = {"input":{"parts":[]},"stages":[stage]}
	var world := WorldGeometry.new()
	world.configure(manifest,stage.stage_id)
	return world
func displace_via(value: Variant) -> bool:
	if value is Dictionary:
		if value.get("via") is Array:
			for point: Variant in value.via:
				if point is Dictionary and point.get("position") is Vector3:
					point.position.y += 1000.0
					return true
		for item: Variant in value.values():
			if displace_via(item): return true
	elif value is Array:
		for item: Variant in value:
			if displace_via(item): return true
	return false
func run() -> void:
	Cache.clear()
	helper = Fixture.new()
	var built: Dictionary = helper.call("build",true,true)
	var world: WorldGeometry = built.world
	var from: ExpeditionWorldPoint = helper.call("at",built,"A",200.0,150.0)
	var near: ExpeditionWorldPoint = helper.call("at",built,"A",400.0,150.0)
	var far: ExpeditionWorldPoint = helper.call("at",built,"C",2900.0,150.0)
	var targets: Array[ExpeditionWorldPoint] = [near,far,from]
	var stage_before := ExpeditionCanonical.digest(world._stage)
	Cache.begin_recording()
	var original := world.connectivity_batch(from,targets,PROFILE,world.geometry_revision)
	check("fixture_has_real_round_trip_certificate",built.ok and valid_witnesses(world,original))
	if not original.ok: Cache.end_recording(); finish(); return
	Cache.record(world,from,targets,PROFILE,original)
	var bundle: Dictionary = Cache.end_recording()
	var folder := ProjectSettings.globalize_path("res://.godot/verification/preparation_proofs_test")
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("proof.bin")
	check("passive_bundle_saves",Cache.save(path,PIN,bundle))
	Cache.clear()
	check("exact_package_pin_loads",Cache.load(path,PIN))
	var fresh := world_for(built.stage.duplicate(true))
	# The stored proof was born in configuration 1; a later equivalent world is
	# still fresh and must receive certificates carrying its CURRENT revisions.
	var manifest := ExpeditionManifest.new(); manifest._data = {"input":{"parts":[]},"stages":[built.stage.duplicate(true)]}
	fresh.configure(manifest,"grid_nav")
	var subset: Array[ExpeditionWorldPoint] = [far,near,far,from]
	var restored := lookup(fresh,from,subset)
	check("subset_duplicates_reordering_and_root_have_valid_witnesses",valid_witnesses(fresh,restored) and restored.data.targets.size() == subset.size() and restored.data.targets[0].node_id == restored.data.targets[2].node_id)
	check("certificate_uses_fresh_world_revisions",hit(restored) and restored.geometry_revision == fresh.geometry_revision and restored.data.configuration_revision == fresh.configuration_revision and fresh.configuration_revision != world.configuration_revision)
	var limited_ctx := context(fresh); limited_ctx.limits.max_storage_bytes = 1
	var limited := Cache.try_certificate(fresh,from,targets,PROFILE,fresh.geometry_revision,limited_ctx)
	check("proof_verification_obeys_storage_budget",not limited.get("ok",false) and limited.get("error_code") == &"navigation_budget_exceeded" and not limited.get("data",{}).has("complete"))
	var cancelled_ctx := context(fresh); cancelled_ctx.cancellation = func() -> bool: return true
	var cancelled := Cache.try_certificate(fresh,from,targets,PROFILE,fresh.geometry_revision,cancelled_ctx)
	check("proof_verification_obeys_cancellation",not cancelled.get("ok",false) and cancelled.get("error_code") == &"cancelled" and not cancelled.get("data",{}).has("complete"))
	check("record_and_verify_leave_stage_and_occupancy_unchanged",ExpeditionCanonical.digest(world._stage) == stage_before and fresh._stage == world._stage and world._occupancy.is_empty() and fresh._occupancy.is_empty())
	var renamed_stage: Dictionary = built.stage.duplicate(true); renamed_stage.stage_id = "renamed_grid"
	var renamed := world_for(renamed_stage)
	var renamed_root := ExpeditionWorldPoint.create("renamed_grid",from.surface_id,from.position)
	var renamed_targets: Array[ExpeditionWorldPoint] = []
	for target: ExpeditionWorldPoint in subset: renamed_targets.append(ExpeditionWorldPoint.create("renamed_grid",target.surface_id,target.position))
	var renamed_result := lookup(renamed,renamed_root,renamed_targets)
	check("stage_namespace_only_can_change",valid_witnesses(renamed,renamed_result) and renamed_result.data.states["@root"].stage_id == "renamed_grid")
	var different_profile := PROFILE.duplicate(true); different_profile.radius = 11.0
	check("different_body_is_not_a_proof_hit",not hit(lookup(fresh,from,targets,different_profile)))
	check("different_root_is_not_a_proof_hit",not hit(lookup(fresh,near,targets)))
	var missing: Array[ExpeditionWorldPoint] = [helper.call("at",built,"B",1300.0,800.0)]
	check("unrecorded_destination_is_not_a_proof_hit",not hit(lookup(fresh,from,missing)))
	var fallback := fresh.connectivity_batch(from,missing,PROFILE,fresh.geometry_revision)
	check("unrecorded_destination_keeps_normal_fallback",valid_witnesses(fresh,fallback))
	fresh.insert_obstacle("proof_cut",AABB(Vector3(1480,-50,0),Vector3(100,400,1024)),fresh.geometry_revision)
	check("changed_geometry_is_not_a_proof_hit",not hit(lookup(fresh,from,targets)))
	var blocked := fresh.connectivity_batch(from,targets,PROFILE,fresh.geometry_revision)
	check("blocked_geometry_keeps_complete_normal_negative",blocked.ok and blocked.data.complete and not blocked.data.targets[1].outward_reachable)
	Cache.clear()
	check("different_package_pin_refused",not Cache.load(path,OTHER_PIN))
	var broken_path := folder.path_join("broken.bin")
	var file := FileAccess.open(broken_path,FileAccess.WRITE); file.store_buffer(PackedByteArray([1,2,3,4,5])); file.close()
	check("corrupt_file_refused",not Cache.load(broken_path,PIN))
	var hostile := bundle.duplicate(true)
	var displaced := displace_via(hostile)
	check("hostile_control_changes_a_real_route",displaced)
	var hostile_path := folder.path_join("hostile.bin")
	var written := Cache.save(hostile_path,PIN,hostile)
	Cache.clear()
	var accepted := written and Cache.load(hostile_path,PIN)
	check("forged_route_never_admits_geometry",not accepted or not hit(lookup(world,from,targets)))
	Cache.clear()
	check("clear_removes_loaded_proofs",not hit(lookup(world,from,targets)))
	var directed_stage: Dictionary = built.stage.duplicate(true)
	for link: Dictionary in directed_stage.connections: link.backward = false
	var directed := world_for(directed_stage)
	var outward_only: Array[ExpeditionWorldPoint] = [far]
	Cache.begin_recording()
	var one_way := directed.connectivity_batch(from,outward_only,PROFILE,directed.geometry_revision)
	check("one_way_control_has_only_outward_access",one_way.ok and one_way.data.complete and one_way.data.targets[0].outward_reachable and not one_way.data.targets[0].inward_reachable)
	Cache.record(directed,from,outward_only,PROFILE,one_way)
	var one_way_bundle := Cache.end_recording()
	var one_way_path := folder.path_join("one_way.bin")
	var one_way_written := Cache.save(one_way_path,PIN,one_way_bundle)
	Cache.clear()
	var one_way_loaded := one_way_written and Cache.load(one_way_path,PIN)
	check("outward_only_result_never_becomes_round_trip_hit",not one_way_loaded or not hit(lookup(directed,from,outward_only)))
	check("final_stage_and_occupancy_remain_unchanged",ExpeditionCanonical.digest(world._stage) == stage_before and world._occupancy.is_empty())
	for candidate: String in [path,broken_path,hostile_path,one_way_path]:
		if FileAccess.file_exists(candidate): DirAccess.remove_absolute(candidate)
	finish()
func finish() -> void:
	Cache.clear()
	if helper != null: helper.free()
	var ok := not checks.is_empty() and checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("PREPARATION_PROOFS_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks}))
	quit(0 if ok else 1)
