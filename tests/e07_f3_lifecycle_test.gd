extends SceneTree
var checks := 0
var failures := 0
var received: Dictionary = {}
var calls := 0
var exercised_kinds: Dictionary = {}
func check(value: bool,label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func _initialize() -> void: _run.call_deferred()
func _received(result: Dictionary) -> void:
	received = result
	calls += 1
func _disable(node: Node) -> void:
	node.set_process(false); node.set_physics_process(false)
	for child: Node in node.get_children(): _disable(child)
func _all_inert(node: Node) -> bool:
	if node.can_process(): return false
	for child: Node in node.get_children(true):
		if not _all_inert(child): return false
	return true
func _run() -> void:
	RunController.selected_class_id = &"mage"
	var source := RunController.new(); root.add_child(source); _disable(source)
	source.encounter_active = false
	source.rng.seed = 20261020
	source.set_meta("shared_rng",source.rng)
	source.set_meta("numeric_collision",source.player.get_instance_id())
	var numeric := source.player.get_instance_id()
	var issued := source.reward_service.issue("lifecycle_source",ProfileRewardResolver.pilot_encounter_reward_id(1))
	check(issued["ok"],"real reward service freezes a ticket before capture")
	var ticket_id: String = issued.get("ticket_id","")
	check(source._create_reward_pickup()["ok"],"real reward pickup is placed before capture")
	source.reward.ticket_id = ticket_id
	_disable(source.reward) # This new child also uses the fixture's manual clock.
	source.player.attack_cooldown = 0.7
	var enemy: CombatActor = source.enemies[0]
	source._selected_enemy = enemy; source._hovered_enemy = enemy
	source.control_preferences.cast_mode = CastIntent.Mode.INSTANT
	source.control_preferences.smart_lock = false
	source.control_preferences.clear_binding(0)
	enemy.global_position = source.player.global_position+Vector2(150,0)
	check(source.player.begin_skill_cast(&"fire_spear",enemy.global_position,enemy),"real preparation is active at barrier")
	var remaining := source.player.active_cast_remaining
	source.memory_snapshot_ready.connect(_received)
	paused = true
	check(source.request_memory_snapshot()["ok"],"paused scene accepts a queued cut")
	source.release_memory_snapshot()
	await process_frame
	check(paused and calls == 0 and not source._memory_snapshot_pending,"releasing a queued cut cancels its callback and preserves the prior pause")
	paused = false
	check(source.request_memory_snapshot()["ok"],"capture is queued after the current tick")
	check(not source.request_memory_snapshot()["ok"],"second concurrent request is refused")
	source.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(source.player.active_cast_remaining == remaining,"focus-out cannot cancel the requested cut")
	await process_frame
	check(calls == 1 and received.get("ok",false),"one snapshot is delivered from the deferred barrier: "+str(received.get("detail",received.get("error_code",""))))
	if not received.get("ok",false): source.release_memory_snapshot(); source.free(); quit(1); return
	check(paused and source.process_mode == Node.PROCESS_MODE_DISABLED,"successful cut remains frozen for its consumer")
	await process_frame
	check(source.player.active_cast_remaining == remaining and source.player.attack_cooldown == 0.7,"waiting on the frozen cut advances no clocks")
	var snapshot: Dictionary = received["snapshot"]
	exercised_kinds.merge(snapshot["coverage"],true)
	var original_bytes := var_to_bytes(snapshot)
	source.release_memory_snapshot()
	check(not paused and not source._memory_snapshot_pending,"explicit release restores previous pause state")
	var restorer := SnapshotRegistry.new()
	var restored := restorer.restore(snapshot)
	check(restored["ok"],"tickets/claims/cast restore without a writer")
	if not restored["ok"]: source.free(); quit(1); return
	var copy: RunController = restored["root"]
	check(restorer.activate(restored).get("error_code") == &"invalid_session" and copy.snapshot_passive,"controller cannot activate before passive installation")
	check(restorer.install(restored,root)["ok"] and _all_inert(copy) and copy.snapshot_passive,"installation freezes every new presentation node until explicit activation")
	await process_frame
	check(_all_inert(copy) and copy.player.active_cast_remaining == remaining and copy.player.attack_cooldown == 0.7,"waiting after installation advances no clocks and exposes no active controls")
	check(restorer.activate(restored)["ok"] and not copy.snapshot_passive and copy.battle_controls.can_process(),"activation publishes the validated scene and presentation together")
	check(restorer.activate(restored).get("already_active",false),"repeated activation is idempotent")
	_disable(copy)
	check(is_same(copy.rng,copy.get_meta("shared_rng")),"shared RNG stream remains one object")
	check(copy.get_meta("numeric_collision") == numeric,"ordinary numeric data equal to an engine ID is never remapped")
	check(copy.player.active_cast_remaining == remaining and copy.player._active_cast_target_id == copy.enemies[0].get_instance_id(),"preparation and target resume exactly")
	check(copy._selected_enemy == copy.enemies[0] and copy._hovered_enemy == copy.enemies[0],"selection references point to the restored actor")
	check(copy.control_preferences.cast_mode == CastIntent.Mode.INSTANT and not copy.control_preferences.smart_lock and copy.control_preferences.bindings == source.control_preferences.bindings,"in-memory controls survive without loading settings again")
	check(copy.player.get_children().any(func(child: Node) -> bool: return child is Camera2D),"runtime camera is rebuilt for the restored player")
	check(copy.reward_service.ticket(ticket_id)["payload"] == issued["payload"],"ticket payload is frozen rather than rerolled")
	check(is_instance_valid(copy.reward) and copy.reward.ticket_id == ticket_id and copy.reward._time == source.reward._time,"visible pickup retains its exact frozen ticket and animation clock")
	var source_grant := source.reward_service.collect(ticket_id)
	var restored_grant := copy.reward_service.collect(ticket_id)
	check(source_grant["ok"] and restored_grant["ok"],"same previously issued reward can be collected after restore")
	check(source.run_state.local_equipment_instances.keys() == copy.run_state.local_equipment_instances.keys() and source.run_state.pending_choices == copy.run_state.pending_choices,"collection grants exactly the same exemplars and choice")
	var choices := copy.run_state.pending_choices
	var count := copy.run_state.local_equipment_instances.size()
	check(copy.reward_service.collect(ticket_id).get("already_applied",false) and copy.run_state.pending_choices == choices and copy.run_state.local_equipment_instances.size() == count,"retry never grants a second item or choice")
	check(source.run_state.open_offer(false,source.rng)["ok"] and copy.run_state.open_offer(false,copy.rng)["ok"],"same next augment offer opens")
	check(source.run_state.offer_token() == copy.run_state.offer_token() and source.rng.state == copy.rng.state,"offer IDs/revision and next RNG match")
	var augment: StringName = source.run_state.current_offer[0].id
	check(source.run_state.confirm_offer(source.run_state.offer_token(),augment,false)["ok"] and copy.run_state.confirm_offer(copy.run_state.offer_token(),augment,false)["ok"],"same choice commits in both runs")
	check(source.run_state.augment_stacks == copy.run_state.augment_stacks,"augment stacks are conserved")
	check(var_to_bytes(snapshot) == original_bytes,"live RNG/reward/augment mutation cannot alter the frozen envelope")
	var invalid := snapshot.duplicate(true)
	for record: Dictionary in invalid["objects"].values():
		if record["kind"] == "rng": record["fields"]["state"] = "invalid"
	check(SnapshotRegistry.new().validate(invalid)["error_code"] == &"invalid_rng_state","invalid RNG state is refused before reconstruction")
	var timer := Timer.new(); source.add_child(timer)
	received = {}
	check(source.request_memory_snapshot()["ok"],"failure case queues through the real barrier")
	await process_frame
	check(not received.get("ok",true) and received.get("error_code") == &"unknown_runtime_kind" and paused,"unknown kind preserves the paused recoverable scene")
	timer.free(); source.release_memory_snapshot()
	check(not paused and source.player.active_cast_remaining == remaining,"explicit failure recovery resumes the exact old state")
	copy.free(); source.free()
	await process_frame
	await _persistent_binding()
	await _flat_geometer()
	var coverage_file := FileAccess.open("res://.godot/verification/e07_f3_lifecycle_coverage.json",FileAccess.WRITE)
	coverage_file.store_string(JSON.stringify(exercised_kinds,"  ",true)); coverage_file.close()
	print("E07 F3 lifecycle: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _persistent_binding() -> void:
	var fixture: Dictionary = preload("res://tests/e06_tx_fixture.gd").make(self,"f3_binding")
	var controller: RunController = fixture["controller"]
	var facade: ProfileFacade = fixture["facade"]
	_disable(controller)
	await process_frame
	var disk_before := FileAccess.get_file_as_bytes(String(fixture["directory"]).path_join(ProfileStore.PRIMARY_FILE))
	paused = true
	var barrier := SnapshotTickBarrier.new(); barrier.acquire(controller)
	var captured := SnapshotRegistry.new().capture(controller,barrier)
	check(captured["ok"],"persistent session captures with an external authority descriptor: "+str(captured.get("detail","")))
	if captured["ok"]:
		var payload: Dictionary = captured["snapshot"]
		exercised_kinds.merge(payload["coverage"],true)
		check(SnapshotRegistry.new().restore(payload).get("error_code") == &"restore_binding_required","persistent graph cannot resume with no facade")
		var stale := payload.duplicate(true); stale["authority"]["revision"] += 1
		check(SnapshotRegistry.new().restore(stale,facade).get("error_code") == &"stale_revision","divergent authority revision is refused")
		var foreign := payload.duplicate(true); foreign["authority"]["profile_id"] += "_foreign"
		check(SnapshotRegistry.new().restore(foreign,facade).get("error_code") == &"invalid_session","foreign profile authority is refused")
		var restored := SnapshotRegistry.new().restore(payload,facade)
		check(restored["ok"],"matching persistent facade binds without cloning its writer: "+str(restored.get("detail","")))
		if restored["ok"]:
			var copy: RunController = restored["root"]
			check(copy.persistent_facade == facade and copy.run_state._uses_persistent_build == controller.run_state._uses_persistent_build and copy.run_state.card_inventory.to_record() == controller.run_state.card_inventory.to_record() and copy.run_state.card_inventory._projection_owner == controller.run_state.card_inventory._projection_owner,"persistent build projection and facade authority are preserved")
			copy.free()
	check(FileAccess.get_file_as_bytes(String(fixture["directory"]).path_join(ProfileStore.PRIMARY_FILE)) == disk_before,"capture/reconstruction never writes the profile fixture")
	barrier.release(); paused = false; controller.free()
	await process_frame

func _flat_geometer() -> void:
	var build := BuildSnapshot.new()
	build.character_id = "f3_flat_geometer"; build.base_class_id = &"mage"; build.evolution_id = &"mg_ar"
	build.base_level = 30; build.job_level = 40; build.skill_ranks = {&"geometer_trace":1}
	preload("res://tests/e05_dependency_fixture.gd").complete_snapshot(build)
	build.library_skill_ids = [&"geometer_trace"]
	RunController.pending_run_state = RunState.from_build("f3_flat_geometer",build)
	var source := RunController.new(); root.add_child(source); _disable(source)
	source.navigation.configure(Rect2(0,0,1000,800),[],18)
	source.player.position = Vector2(100,100)
	source.rng.seed = 8181
	check(source.geometer_casting.begin(source.geometer_casting.capture(&"geometer_trace",Vector2(250,100),true)),"legacy flat Geometer starts a real pending command")
	await process_frame
	paused = true
	var barrier := SnapshotTickBarrier.new(); barrier.acquire(source)
	var captured := SnapshotRegistry.new().capture(source,barrier)
	check(captured["ok"],"legacy construction and cast command capture: "+str(captured.get("detail","")))
	barrier.release(); paused = false
	if captured["ok"]:
		exercised_kinds.merge(captured["snapshot"]["coverage"],true)
		var expected: Array[Dictionary] = []
		for index: int in 40: expected.append(_flat_tick(source))
		check(source.geometer_casting.construction.vertices.size() == 1,"uninterrupted flat cast actually delivers its ground vertex")
		source.free(); await process_frame
		var restorer := SnapshotRegistry.new(); var restored := restorer.restore(captured["snapshot"])
		check(restored["ok"],"legacy flat command reconstructs passively: "+str(restored.get("detail","")))
		if restored["ok"]:
			var copy: RunController = restored["root"]
			check(restorer.install(restored,root)["ok"] and restorer.activate(restored)["ok"],"legacy graph installs and activates without reset")
			_disable(copy)
			for index: int in 40: check(_flat_tick(copy) == expected[index],"legacy Geometer next tick matches cast, flight, cost, construction and RNG")
			copy.free()
	else: source.free()
	await process_frame

func _flat_tick(controller: RunController) -> Dictionary:
	controller._advance_runtime(0.1); controller.player._process(0.1)
	_flat_effects(controller)
	return {"sp":controller.player.current_sp,"cast":controller.player.active_cast_remaining,"cooldowns":controller.player.mage_cooldowns.duplicate(),"pending":controller.geometer_casting.construction.grammar.pending_count(),"positions":controller.geometer_casting.construction.positions(),"rng":controller.rng.state}

func _flat_effects(node: Node) -> void:
	for child: Node in node.get_children():
		if child.is_queued_for_deletion(): continue
		if child is GeometerTraceProjectile: child._process(0.1)
		_flat_effects(child)
