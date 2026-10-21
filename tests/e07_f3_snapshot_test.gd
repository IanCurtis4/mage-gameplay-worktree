extends SceneTree
var checks := 0
var failures := 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var nav := ArenaNavigation.new()
	nav.configure(Rect2(0,0,800,800),[],18)
	var actor := PlayerActor.new()
	actor.configure(nav,RunState.new(&"mage"))
	var enemy := CombatActor.new()
	enemy.setup("Alvo",Color.RED,actor.stat_breakdown)
	actor.add_child(enemy)
	actor.target = enemy
	actor.health._hp_deficit = 31.25
	actor._sp_deficit = 12.75
	actor.attack_cooldown = 0.375
	actor.run_state.queue_choice()
	var rng := RandomNumberGenerator.new(); rng.seed = 7141
	var offer := actor.run_state.open_offer(false,rng)
	check(offer["ok"],"real augment offer opens")
	var gone := CombatActor.new(); var gone_id := gone.get_instance_id(); gone.free()
	var plan := actor.run_state.causal_plan([actor.get_instance_id(),enemy.get_instance_id(),gone_id])
	var context := actor.run_state.effect_ledger.new_root(actor.get_instance_id(),false,"",false,plan)
	var family: StringName = plan["families"][0]
	var claim := actor.run_state.effect_ledger.claim_batch(context,[{"family_id":family,"source_id":&"test_proc","target_id":enemy.get_instance_id()}])
	check(claim.size() == 1,"real finite secondary claim is admitted")
	var request := DamageRequest.new()
	request.source_id = actor.get_instance_id(); request.target_id = enemy.get_instance_id()
	request.physical_damage = 100; request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false; request.is_secondary = true; request.context = claim[0]["context"]
	check(float(enemy.apply_damage(request,rng).get("actual_damage",0)) > 0,"secondary effect applies once before cut")
	enemy.burn_request = request
	# Store a real live root through the same actor envelope used by casts.
	actor._emission_context = context
	var barrier := SnapshotTickBarrier.new()
	check(barrier.acquire(actor)["ok"],"detached completed-tick fixture acquires barrier")
	var registry := SnapshotRegistry.new()
	var captured := registry.capture(actor,barrier)
	check(captured["ok"],"explicit actor/run graph captures: "+str(captured.get("detail",captured.get("error_code",""))))
	if not captured["ok"]: barrier.release(); actor.free(); _finish(); return
	var payload: Dictionary = captured["snapshot"]
	var coverage_file := FileAccess.open("res://.godot/verification/e07_f3_snapshot_coverage.json",FileAccess.WRITE)
	coverage_file.store_string(JSON.stringify(payload["coverage"],"  ",true)); coverage_file.close()
	check(payload["tombstones"].size() == 1,"dead causal target has a stable tombstone without a node")
	check(not var_to_str(payload).contains(str(actor.get_instance_id())) and not var_to_str(payload).contains(str(enemy.get_instance_id())) and not var_to_str(payload).contains(str(gone_id)),"captured identity fields contain no engine instance IDs")
	check(registry.validate(payload)["ok"],"snapshot validates")
	check(registry.entities.register(actor,"",1).get("error_code") == &"stale_generation","a surviving instance cannot change generation silently")
	check(registry.entities.register(actor,"invalid_id").get("error_code") == &"invalid_identity","public registry refuses a noncanonical identity")
	var expected_offer := actor.run_state.offer_token()
	var expected_hp := actor.health.current_hp
	var binary_round_trip: Variant = bytes_to_var(var_to_bytes(payload))
	check(binary_round_trip is Dictionary and registry.validate(binary_round_trip)["ok"],"pure Variant bytes round-trip in memory without native handles")
	var restored := SnapshotRegistry.new().restore(binary_round_trip)
	check(restored["ok"],"two-pass reconstruction succeeds: "+str(restored.get("detail",restored.get("error_code",""))))
	if restored["ok"]:
		var copy: PlayerActor = restored["root"]
		check(copy != actor and copy.get_instance_id() != actor.get_instance_id(),"new actor is a distinct engine instance")
		check(copy.target != enemy and copy.target.health.actor_id == copy.target.get_instance_id(),"references and health identity point to reconstructed target")
		check(copy.health.current_hp == expected_hp and copy.sp_deficit() == actor.sp_deficit(),"no HP/SP healing or composition setter")
		check(copy.attack_cooldown == actor.attack_cooldown,"cooldown preserved")
		check(copy.run_state.offer_token() == expected_offer,"offer identity/revision/choices preserved")
		check(copy._emission_context.root_event_id != context.root_event_id,"causal string rebinds to new local identity")
		check(copy._emission_context._budget.owner_id == copy.get_instance_id(),"shared root owner rebound")
		check(copy.run_state.effect_ledger == copy._emission_context.ledger(),"ledger weak link and shared budget restored")
		check(copy.target.burn_request.context._budget == copy._emission_context._budget,"all delayed envelopes share the reconstructed budget")
		check(copy.run_state.effect_ledger.claim_batch(copy._emission_context,[{"family_id":family,"source_id":&"another_source","target_id":copy.target.get_instance_id()}]).is_empty(),"already claimed family/target cannot reopen after restore")
		var hp_before := copy.target.health.current_hp
		check(copy.target.apply_damage(copy.target.burn_request,rng).is_empty() and copy.target.health.current_hp == hp_before,"already applied secondary damage never replays")
		var copy_barrier := SnapshotTickBarrier.new(); copy_barrier.acquire(copy)
		var recaptured := SnapshotRegistry.new().capture(copy,copy_barrier)
		check(recaptured["ok"] and recaptured["snapshot"]["root"] == payload["root"],"restored IDs and dead-target tombstone survive the following cut")
		copy_barrier.release()
		copy.free()
	var future := payload.duplicate(true); future["format"] = 999
	check(not registry.validate(future)["ok"],"future snapshot rejected")
	var unknown := payload.duplicate(true); unknown["objects"][unknown["root"]]["kind"] = "res://unknown.gd"
	check(registry.validate(unknown)["error_code"] == &"unknown_runtime_kind","unknown runtime kind rejected")
	var incomplete := payload.duplicate(true); incomplete["objects"][incomplete["root"]]["fields"].erase("health")
	check(not SnapshotRegistry.new().restore(incomplete)["ok"],"missing field blocks reconstruction")
	var dangling := payload.duplicate(true); dangling["objects"][dangling["root"]]["fields"]["health"] = {"$":"object","id":"entity_missing"}
	check(SnapshotRegistry.new().restore(dangling)["error_code"] == &"dangling_entity_reference","unknown object reference blocks reconstruction")
	var wrong_type := payload.duplicate(true); wrong_type["objects"][wrong_type["root"]]["fields"]["attack_cooldown"] = "invalid"
	check(SnapshotRegistry.new().restore(wrong_type)["error_code"] == &"invalid_payload","wrong scalar type fails before publication")
	var duplicate := payload.duplicate(true); duplicate["tombstones"].append(duplicate["root"])
	check(SnapshotRegistry.new().restore(duplicate)["error_code"] == &"duplicate_stable_id","live/tombstone collision is rejected")
	var revision := payload.duplicate(true); revision["sources"][SnapshotRegistry.MANIFEST] = "changed"
	check(registry.validate(revision)["error_code"] == &"content_revision_unavailable","incompatible runtime source revision cannot resume")
	var native := payload.duplicate(true); native["objects"][native["root"]]["fields"]["target"] = actor
	check(SnapshotRegistry.new().restore(native)["error_code"] == &"invalid_payload","native object smuggled into envelope is rejected")
	var wrong_namespace := payload.duplicate(true); wrong_namespace["objects"][wrong_namespace["root"]]["fields"]["_path"] = {"$":"container","id":payload["root"]}
	check(SnapshotRegistry.new().restore(wrong_namespace)["error_code"] == &"dangling_entity_reference","an entity ID cannot masquerade as a container")
	var malformed_signal := payload.duplicate(true); malformed_signal["objects"][malformed_signal["root"]]["signals"].append({"signal":"health_changed"})
	check(SnapshotRegistry.new().restore(malformed_signal)["error_code"] == &"invalid_payload","incomplete signal descriptor fails before reconstruction")
	var malformed_meta := payload.duplicate(true); malformed_meta["objects"][malformed_meta["root"]]["node"]["meta"] = 12
	check(SnapshotRegistry.new().restore(malformed_meta)["error_code"] == &"invalid_payload","non-dictionary metadata fails before reconstruction")
	var timer := Timer.new(); actor.add_child(timer)
	check(SnapshotRegistry.new().capture(actor,barrier)["error_code"] == &"unknown_runtime_kind","unregistered native Timer cannot disappear from snapshot")
	timer.free()
	var original_bytes := var_to_bytes(payload)
	request.effect_snapshot["source_id"] = StringName("equipment:main_hand:equipment_%d" % actor.get_instance_id())
	request.effect_snapshot["counter"] = actor.get_instance_id()
	var newcomer := CombatActor.new(); newcomer.setup("Novo",Color.WHITE,actor.stat_breakdown); actor.add_child(newcomer)
	var second := SnapshotRegistry.new().capture(actor,barrier)
	check(second["ok"] and second["snapshot"]["root"] == payload["root"],"surviving entity ID is stable across consecutive cuts")
	check(second["snapshot"]["next_entity_serial"] > payload["next_entity_serial"],"new runtime entity advances the stable serial")
	var second_restored := SnapshotRegistry.new().restore(second["snapshot"])
	check(second_restored["ok"],"snapshot with an ordinary numeric collision restores")
	if second_restored["ok"]:
		var second_copy: PlayerActor = second_restored["root"]
		check(second_copy.target.burn_request.effect_snapshot == request.effect_snapshot,"equipment source IDs and counters never become actor references")
		second_copy.free()
	newcomer.free()
	var third := SnapshotRegistry.new().capture(actor,barrier)
	check(third["ok"] and third["snapshot"]["root"] == payload["root"],"removing another entity cannot renumber the survivor")
	check(var_to_bytes(payload) == original_bytes,"later captures cannot mutate an earlier envelope")
	var pursued := CombatActor.new(); pursued.setup("Perseguido",Color.WHITE,actor.stat_breakdown); actor.add_child(pursued)
	actor.position = Vector2(100,100)
	actor.target = pursued
	actor._defender_advance_targets.assign([pursued])
	actor._path = PackedVector2Array([Vector2(500,100)]); actor._path_index = 0; actor._navigation_revision = nav.revision
	actor._has_path_goal = true; actor._path_goal = Vector2(500,100); actor._attack_engaged = true
	pursued.free()
	var dead_cut := SnapshotRegistry.new().capture(actor,barrier)
	check(dead_cut["ok"],"destroyed direct target and cached target array are captured")
	if dead_cut["ok"]:
		var dead_restore := SnapshotRegistry.new().restore(dead_cut["snapshot"])
		check(dead_restore["ok"],"destroyed references hydrate without reviving a target")
		if dead_restore["ok"]:
			var dead_copy: PlayerActor = dead_restore["root"]
			check(not is_instance_valid(dead_copy.target) and is_same(dead_copy.target,dead_copy._defender_advance_targets[0]),"dead-reference liveness and alias match the original")
			barrier.release()
			actor._process(0.1); dead_copy._process(0.1)
			# Godot compares freed references equal to null. The current actor
			# retains this cached route; resume must match that real behavior.
			check(typeof(actor.target) == typeof(dead_copy.target) and is_instance_valid(actor.target) == is_instance_valid(dead_copy.target) and actor._path == dead_copy._path and actor.position == dead_copy.position and actor.velocity == dead_copy.velocity,"next tick matches uninterrupted movement and destroyed-reference liveness")
			dead_copy.free()
	barrier.release()
	actor.free()
	_finish()
func _finish() -> void:
	print("E07 F3 snapshot: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
