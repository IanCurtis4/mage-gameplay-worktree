extends SceneTree
## E08 compact checkpoint, the cases its contract still listed as uncovered
## (docs/epics/e08_compact_checkpoint.md, "Limitações conhecidas"):
## homes at distinct heights, a full journal over a format 3 base, a death and a
## wave in the same journal write, respawn_pending slots crossing a compact
## resume, and definitive/uncertain results at each format 3 commit boundary.
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
const Compact = preload("res://scripts/core/expedition/persistence/compact_expedition.gd")
const Journal = preload("res://scripts/core/expedition/persistence/expedition_journal_codec.gd")
const Ruins = preload("res://data/expedition/phases/ruined_crossing.gd")
var count := 0
var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	count += 1
	if not ok:
		failures += 1
		push_error("E08 compact coverage: " + label)

func lock_of(f: Dictionary) -> ExpeditionAssetLock:
	return f["facade"].current_profile().expedition_for_character(f["a"])

func durable_lock(f: Dictionary) -> ExpeditionAssetLock:
	var loaded: Dictionary = f["store"].load_profile()
	return loaded["profile"].expedition_for_character(f["a"]) if loaded.get("ok", false) else null

func slot_fields(slots: Dictionary) -> Dictionary:
	var out := {}
	for id: String in slots:
		var slot := {}
		for field: String in Compact.SLOT_FIELDS: slot[field] = slots[id][field]
		out[id] = slot
	return out

func kill(host: RunController, slot_id: String) -> void:
	var actor: EnemyActor = host.campaign_runtime.actors[slot_id]
	actor.health.current_hp = 0.0
	actor.health._death_emitted = true
	host._on_enemy_died(actor)

func flush(f: Dictionary, host: RunController, barrier: SnapshotTickBarrier, request: String, extra: Array = []) -> Dictionary:
	var events: Array = host.campaign_runtime.pending_events.duplicate(true)
	events.append_array(extra)
	return ExpeditionService.new(f["facade"]).journal_events(host, barrier, events, request, f["facade"].current_profile().revision)

func alive_on_stage(host: RunController) -> Array[String]:
	var state := host.campaign_runtime.state
	var ids: Array[String] = []
	for id: String in state.slots:
		var slot: Dictionary = state.slots[id]
		if slot["stage_id"] == state.current_stage_id and slot["life_state"] == "alive" and host.campaign_runtime.actors.has(id): ids.append(id)
	return ids

## The live runtime keeps dead actors as disabled nodes; replay spawns the living.
func living(host: RunController) -> Array:
	var ids := host.campaign_runtime.actors.keys().filter(func(id: String) -> bool: return host.campaign_runtime.state.slots[id]["life_state"] == "alive")
	ids.sort()
	return ids

func panel_for(lobby: CharacterMenu, character_id: String) -> PhaseSelectionPanel:
	var panel := PhaseSelectionPanel.new()
	lobby.add_child(panel)
	panel.configure(lobby, character_id)
	return panel

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var f := F.make("e08_compact_cov")
	var facade: ProfileFacade = f["facade"]
	var store: F.FaultStore = f["store"]
	var menu := CharacterMenu.new()
	menu.set_profile_facade(facade)
	root.add_child(menu)
	current_scene = menu
	var panel := panel_for(menu, f["a"])
	panel.seed_input.text = "42"
	var entered: Dictionary = await panel.start()
	check(entered.get("ok", false), "entry " + str(entered))
	if not entered.get("ok", false): _finish(); return
	var host := entered["root"] as RunController
	await process_frame
	paused = true
	var barrier := SnapshotTickBarrier.new()
	check(barrier.acquire(host)["ok"], "barrier for the coverage cuts")
	var runtime := host.campaign_runtime
	var state := runtime.state
	var lock := lock_of(f)
	var expedition_id := lock.expedition_id
	var phase_id := lock.phase_id
	check(lock.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "entry base is format 3")

	# 1. Homes at distinct heights: the vertical interval decides, as occupancy does.
	var profile: Dictionary = host.player.world_motion._profile
	var home_ids := alive_on_stage(host)
	check(home_ids.size() >= 2, "at least two living homes on the entry stage")
	var first: Dictionary = state.slots[home_ids[0]]
	var home := ExpeditionPopulationPlanner.point(first["home"])
	var body_h := float(first["traversal"]["height"])
	var player_h := float(profile["height"])
	var at := func(dy: float) -> ExpeditionWorldPoint: return ExpeditionWorldPoint.create(home.stage_id, home.surface_id, home.position + Vector3(0, dy, 0))
	check(not Compact._homes_clear(runtime, at.call(0.0), profile), "same height on a living home is occupied")
	check(not Compact._homes_clear(runtime, at.call(body_h - 0.01), profile), "overlapping vertical interval is occupied")
	check(Compact._homes_clear(runtime, at.call(body_h + 0.01), profile), "player above the living body is clear")
	check(Compact._homes_clear(runtime, at.call(-player_h - 0.01), profile), "player below the living body is clear")
	var second_id := home_ids[1]
	var second_home: Dictionary = state.slots[second_id]["home"].duplicate(true)
	var far := host.player.world_point()
	check(Compact._homes_clear(runtime, far, profile), "player starts away from homes")
	var stacked: Dictionary = first["home"].duplicate(true)
	stacked["position"] = home.position + Vector3(0, body_h + float(state.slots[second_id]["traversal"]["height"]) + 0.01, 0)
	state.slots[second_id]["home"] = stacked
	check(Compact._homes_clear(runtime, far, profile), "two homes stacked at distinct heights do not collide")
	stacked = first["home"].duplicate(true)
	state.slots[second_id]["home"] = stacked
	check(not Compact._homes_clear(runtime, far, profile), "two homes at the same height collide")
	state.slots[second_id]["home"] = second_home

	# 2. Commit boundary: an active compact checkpoint, definitive and uncertain.
	# definitive: nothing written; after_replace: written, error reported but the
	# primary is readable; lost_ack: written with the reads hidden (uncertain).
	for mode: String in ["definitive", "after_replace", "lost_ack"]:
		var cut := Compact.capture(host, barrier)
		check(cut.get("ok", false), "eligible cut for " + mode + " " + str(cut))
		if not cut.get("ok", false): continue
		var svc := ExpeditionService.new(facade)
		var request := "cov_checkpoint_" + mode
		var before := durable_lock(f).checkpoint.duplicate(true)
		var revision := facade.current_profile().revision
		if mode == "lost_ack": store.lose_ack = true; store.hide_after_ack = true
		else: store.fail_stage = StringName("replace" if mode == "definitive" else mode)
		var result := svc.checkpoint(host, barrier, expedition_id, phase_id, request, revision, false, cut)
		store.fail_stage = &""
		if mode == "definitive":
			check(not result.get("ok", false) and not result.get("read_only", false), "definitive failure is reported " + str(result))
			check(durable_lock(f).checkpoint == before and facade.current_profile().revision == revision, "definitive failure keeps the durable base")
			result = svc.checkpoint(host, barrier, expedition_id, phase_id, request, revision, false, cut)
			check(result.get("ok", false), "same request retries after a definitive failure " + str(result))
		elif mode == "after_replace":
			check(result.get("ok", false) and result.get("recovered_after_uncertain_result", false), "readable write after a reported error is confirmed " + str(result))
		else:
			check(not result.get("ok", false) and result.get("read_only", false), mode + " freezes as uncertain " + str(result))
			check(svc.checkpoint(host, barrier, expedition_id, phase_id, "cov_other_" + mode, revision, false, cut).get("error_code") == &"recovery_required", mode + " blocks another write")
			store.hide_reads = false
			result = svc.reconcile(request)
			check(result.get("ok", false) and result.get("recovered_after_uncertain_result", false), "lost ack reconciles the written format 3 " + str(result))
		var written := durable_lock(f)
		check(written != null and written.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT and written.checkpoint != before, mode + " ends with a new format 3 base")
		var replay := svc.commit_cut(host, cut["snapshot"]["authority"], expedition_id, phase_id, request, revision, false, cut["encoding"], true)
		check(replay.get("ok", false) and replay.get("already_applied", false) and durable_lock(f).checkpoint == written.checkpoint, mode + " retry after confirmation is a replay without a write")

	# 3. Full journal over a format 3 base: replay, cap, compaction, new chain.
	var victims := alive_on_stage(host)
	kill(host, victims[0])
	var journaled := flush(f, host, barrier, "cov_full_seed")
	check(journaled.get("ok", false) and journaled.get("journal_kind") == "deaths", "real death seeds the journal " + str(journaled))
	await process_frame
	lock = lock_of(f)
	var seeded := Journal.decode(lock.journal, lock.checkpoint)
	check(seeded.get("ok", false) and seeded["payloads"].size() == 1, "one service-written entry over format 3")
	var seed_payload: Dictionary = seeded["payloads"][0] if seeded.get("ok", false) else {}
	var full_profile := facade.current_profile().copy_state()
	var full_lock := full_profile.expedition_for_character(f["a"])
	while full_lock.journal.size() < Journal.MAX_ENTRIES:
		var made := Journal.make_entry(full_lock.journal, full_lock.checkpoint, "cov_full_%03d" % full_lock.journal.size(), seed_payload)
		if not made.get("ok", false): break
		full_lock.journal.append(made["entry"])
	check(full_lock.journal.size() == Journal.MAX_ENTRIES, "journal filled to its cap over format 3")
	check(Journal.make_entry(full_lock.journal, full_lock.checkpoint, "cov_full_over", seed_payload).get("error_code") == &"journal_full", "cap refuses another entry")
	full_profile.expeditions[full_lock.expedition_id] = full_lock
	check(store.commit(full_profile).get("ok", false) and facade.open_profile().get("ok", false), "full chain persisted and reread")
	lock = lock_of(f)
	check(lock.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT and lock.journal.size() == Journal.MAX_ENTRIES, "reread lock is format 3 with a full journal")
	var replayed := ExpeditionService.new(facade)._restore(lock)
	check(replayed.get("ok", false), "full journal replays over the compact base " + str(replayed.get("error_code", "")))
	if replayed.get("ok", false):
		var copy: RunController = replayed["root"]
		check(slot_fields(copy.campaign_runtime.state.slots) == slot_fields(state.slots), "replayed slots equal the live slots")
		check(copy.reward_service._queue == host.reward_service._queue and copy.rng.state == host.rng.state, "replayed drops and RNG equal the live run")
		check(living(copy) == living(host), "replayed living population equals the live one")
		copy.free()
	var compact_cut := Compact.capture(host, barrier)
	check(compact_cut.get("ok", false), "compaction cut is eligible " + str(compact_cut))
	var compacted := ExpeditionService.new(facade).checkpoint(host, barrier, expedition_id, phase_id, "cov_full_compact", facade.current_profile().revision, false, compact_cut)
	lock = lock_of(f)
	check(compacted.get("ok", false) and lock.journal.is_empty() and lock.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "full journal compacts into a new format 3 base " + str(compacted))
	victims = alive_on_stage(host)
	kill(host, victims[0])
	journaled = flush(f, host, barrier, "cov_after_compact")
	check(journaled.get("ok", false) and lock_of(f).journal.size() == 1, "journal restarts after compaction")
	await process_frame

	# 4. respawn_pending crosses the compact resume. Ruins has one trash slot per
	# stage; the player holds its home so the wave leaves it waiting.
	var leftover := alive_on_stage(host)
	for id: String in leftover: kill(host, id)
	if not leftover.is_empty():
		journaled = flush(f, host, barrier, "cov_clear_stage")
		check(journaled.get("ok", false), "clearing deaths " + str(journaled))
		await process_frame
	check(state.stages[state.current_stage_id]["cleared_once"] and state.clock.started, "stage cleared and wave clock armed")
	var held := ""
	for id: String in state.slots:
		if state.slots[id]["stage_id"] == state.current_stage_id and state.slots[id]["trash"]: held = id
	check(not held.is_empty() and state.slots[held]["life_state"] == "dead", "entry stage has a dead trash slot")
	if held.is_empty(): _finish(); return
	var start_point := host.player.world_point()
	var geometry := host.player.world_motion.geometry
	var stood := host.player.world_motion.teleport(ExpeditionPopulationPlanner.point(state.slots[held]["home"]), 1.0e20, geometry.geometry_revision)
	check(stood.get("ok", false), "player stands on the dead trash home " + str(stood))
	check(state.advance(state.clock.remaining), "wave fires")
	journaled = flush(f, host, barrier, "cov_wave_1", [{"kind": "wave", "wave_index": int(state.clock.wave_index)}])
	check(journaled.get("ok", false) and journaled.get("journal_kind") == "wave", "wave journaled " + str(journaled))
	check(runtime.birth_queue.is_empty() and runtime.pending_events.is_empty(), "held home admits no birth")
	check(state.slots[held]["life_state"] == "respawn_pending" and int(state.slots[held]["pending_wave"]) >= 1, "held slot waits with its wave")
	var expected_slots := slot_fields(state.slots)
	var held_generation := int(state.slots[held]["generation"])
	var suspend_cut := Compact.capture(host, barrier)
	check(suspend_cut.get("ok", false), "cut with a pending slot under the player is compact " + str(suspend_cut))
	if not suspend_cut.get("ok", false): _finish(); return
	var suspended := ExpeditionService.new(facade).checkpoint(host, barrier, expedition_id, phase_id, "cov_suspend", facade.current_profile().revision, true, suspend_cut)
	check(suspended.get("ok", false) and lock_of(f).lifecycle == &"suspended" and lock_of(f).checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT and lock_of(f).journal.is_empty(), "suspension writes format 3 " + str(suspended))
	barrier.release()

	# 5. Commit boundary: compact resume, definitive and uncertain.
	for mode: String in ["definitive", "lost_ack"]:
		var svc := ExpeditionService.new(facade)
		var request := "cov_resume_" + mode
		var revision := facade.current_profile().revision
		var before := durable_lock(f).checkpoint.duplicate(true)
		if mode == "definitive": store.fail_stage = &"replace"
		else: store.lose_ack = true; store.hide_after_ack = true
		var result := svc.resume(expedition_id, f["a"], request, revision)
		store.fail_stage = &""
		if mode == "definitive":
			check(not result.get("ok", false) and not result.get("read_only", false) and durable_lock(f).lifecycle == &"suspended" and durable_lock(f).checkpoint == before, "definitive resume failure keeps the suspended base " + str(result))
			result = svc.resume(expedition_id, f["a"], request, revision)
			check(result.get("ok", false), "same resume request retries " + str(result))
		else:
			check(not result.get("ok", false) and result.get("read_only", false) and not result.has("root"), "uncertain resume publishes no world " + str(result))
			store.hide_reads = false
			result = svc.reconcile(request)
			check(result.get("ok", false) and result.has("root"), "lost ack resume reconciles to the staged world " + str(result))
		if not result.get("ok", false): continue
		var resumed: RunController = result["root"]
		var rstate := resumed.campaign_runtime.state
		check(slot_fields(rstate.slots) == expected_slots, mode + ": slots, including the pending one, cross the compact resume")
		check(not resumed.campaign_runtime.actors.has(held), mode + ": the pending slot has no actor")
		var moved := resumed.player.world_motion.teleport(start_point, 1.0e20, resumed.player.world_motion.geometry.geometry_revision)
		check(moved.get("ok", false), mode + ": player leaves the pending home")
		check(resumed.campaign_runtime.admit_pending(resumed).get("ok", false), mode + ": pending birth admitted after the resume")
		check(rstate.slots[held]["life_state"] == "alive" and int(rstate.slots[held]["generation"]) == held_generation + 1 and resumed.campaign_runtime.actors.has(held), mode + ": pending slot is born at the next generation")
		check(resumed.campaign_runtime.valid(), mode + ": resumed population is valid")
		resumed.free()
		if mode == "definitive":
			# Put the expedition back to suspended for the next boundary mode.
			var again := svc.resume(expedition_id, f["a"], request, revision)
			check(again.get("ok", false) and again.get("already_applied", false), "confirmed resume retry reconstructs without a write")
			if again.get("ok", false):
				var copy: RunController = again["root"]
				var re_barrier := SnapshotTickBarrier.new()
				check(re_barrier.acquire(copy)["ok"], "barrier on the rebuilt world")
				var re_cut := Compact.capture(copy, re_barrier)
				check(re_cut.get("ok", false), "rebuilt world cuts compact " + str(re_cut))
				if re_cut.get("ok", false):
					var re_suspended := ExpeditionService.new(facade).checkpoint(copy, re_barrier, expedition_id, phase_id, "cov_resuspend", facade.current_profile().revision, true, re_cut)
					check(re_suspended.get("ok", false), "rebuilt world suspends again " + str(re_suspended))
				re_barrier.release()
				copy.free()
	paused = false

	# 6. Commit boundary: compact entry, definitive and uncertain.
	for mode: String in ["definitive", "lost_ack"]:
		var g := F.make("e08_compact_cov_entry_" + mode)
		var gf: ProfileFacade = g["facade"]
		var gs: F.FaultStore = g["store"]
		var started := gf.start_run("start_cov_" + mode, gf.current_profile().revision)
		check(started.get("ok", false), "entry run starts " + mode)
		if not started.get("ok", false): continue
		RunController.pending_run_state = started["run_state"]
		RunController.pending_run_facade = gf
		RunController.pending_gameplay_extension = true
		var staging := RunController.new()
		staging.expedition_entry_mode = true
		root.add_child(staging)
		staging.arena_view.hide(); staging.ui_root.hide()
		staging.route_camera.enabled = false
		check(staging.request_memory_snapshot().get("ok", false), "entry snapshot queued " + mode)
		var captured: Dictionary = await staging.memory_snapshot_ready
		await process_frame
		check(captured.get("ok", false), "entry snapshot " + mode)
		var built := ExpeditionAssembler.build(Ruins.input("42"))
		var manifest: ExpeditionManifest = built["data"]["manifest"]
		var svc := ExpeditionService.new(gf)
		var request := "cov_entry_" + mode
		var exp_id := "exp_" + staging.run_state.run_id.md5_text()
		var revision := gf.current_profile().revision
		if mode == "definitive": gs.fail_stage = &"replace"
		else: gs.lose_ack = true; gs.hide_after_ack = true
		var result := svc.enter(staging, staging._memory_snapshot_barrier, exp_id, manifest, Ruins.rules(manifest), request, revision)
		gs.fail_stage = &""
		if mode == "definitive":
			check(not result.get("ok", false) and not result.get("read_only", false) and durable_lock(g) == null, "definitive entry failure writes no expedition " + str(result))
			result = svc.enter(staging, staging._memory_snapshot_barrier, exp_id, manifest, Ruins.rules(manifest), request, gf.current_profile().revision)
			check(result.get("ok", false), "same entry request retries " + str(result))
		else:
			check(not result.get("ok", false) and result.get("read_only", false) and not result.has("root"), "uncertain entry publishes no world " + str(result))
			gs.hide_reads = false
			result = svc.reconcile(request)
			check(result.get("ok", false) and result.has("root"), "lost ack entry reconciles " + str(result))
		var entry_lock := durable_lock(g)
		check(entry_lock != null and entry_lock.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, mode + ": entry ends durable in format 3")
		if result.has("root") and is_instance_valid(result["root"]): result["root"].free()
		staging.release_memory_snapshot()
		staging.queue_free()
		await process_frame
	host.queue_free()
	await process_frame

	# 7. A death and a wave in the same write, replayed over the format 3 base.
	# With one trash slot per stage, the death in that write is the player's.
	var h := F.make("e08_compact_cov_wave")
	var hf: ProfileFacade = h["facade"]
	var hmenu := CharacterMenu.new()
	hmenu.set_profile_facade(hf)
	root.add_child(hmenu)
	current_scene = hmenu
	var hpanel := panel_for(hmenu, h["a"])
	hpanel.seed_input.text = "42"
	var hentered: Dictionary = await hpanel.start()
	check(hentered.get("ok", false), "second entry " + str(hentered))
	if not hentered.get("ok", false): _finish(); return
	var live := hentered["root"] as RunController
	await process_frame
	paused = true
	var hb := SnapshotTickBarrier.new()
	check(hb.acquire(live)["ok"], "barrier on the second run")
	var hstate := live.campaign_runtime.state
	for id: String in alive_on_stage(live): kill(live, id)
	check(flush(h, live, hb, "cov2_clear").get("ok", false), "second run clears the entry stage")
	await process_frame
	var hheld := ""
	for id: String in hstate.slots:
		if hstate.slots[id]["stage_id"] == hstate.current_stage_id and hstate.slots[id]["trash"]: hheld = id
	var hgeo := live.player.world_motion.geometry
	check(live.player.world_motion.teleport(ExpeditionPopulationPlanner.point(hstate.slots[hheld]["home"]), 1.0e20, hgeo.geometry_revision).get("ok", false), "player holds the trash home")
	check(hstate.advance(hstate.clock.remaining), "first wave fires")
	check(flush(h, live, hb, "cov2_wave_1", [{"kind": "wave", "wave_index": int(hstate.clock.wave_index)}]).get("ok", false), "first wave journaled")
	live.player.health.current_hp = 0.0
	live.player.health._death_emitted = true
	check(hstate.advance(hstate.clock.remaining), "second wave fires with the player's death pending")
	var hbefore := lock_of(h).journal.size()
	var together := flush(h, live, hb, "cov2_death_wave", [{"kind": "player_death", "event_id": "cov2_player_death"}, {"kind": "wave", "wave_index": int(hstate.clock.wave_index)}])
	check(together.get("ok", false), "death and wave written together " + str(together))
	var hlock := lock_of(h)
	var hchain := Journal.decode(hlock.journal, hlock.checkpoint)
	var htail: Array = hchain["payloads"].slice(hbefore) if hchain.get("ok", false) else []
	check(hlock.checkpoint["format"] == ExpeditionCheckpointCodec.COMPACT_FORMAT, "journal still sits on the format 3 entry base")
	check(htail.size() == 2 and not Journal.is_wave(htail[0]) and Journal.is_wave(htail[1]) and hlock.lifecycle == &"recovering", "one write holds the death entry then the wave entry")
	var hcopy := ExpeditionService.new(hf)._restore(hlock)
	check(hcopy.get("ok", false), "death and wave replay over the compact base " + str(hcopy.get("error_code", "")))
	if hcopy.get("ok", false):
		var copy: RunController = hcopy["root"]
		check(slot_fields(copy.campaign_runtime.state.slots) == slot_fields(hstate.slots), "replayed slots equal the live slots")
		check(copy.campaign_runtime.state.slots[hheld]["life_state"] == "respawn_pending" and copy.campaign_runtime.state.clock.wave_index == hstate.clock.wave_index, "replay keeps the pending slot and the wave clock")
		check(copy.campaign_runtime.state.lifecycle == "recovering" and not copy.player.is_alive(), "replay keeps the player's death")
		copy.free()
	hb.release()
	paused = false
	live.queue_free()
	_finish()

func _finish() -> void:
	print("E08 compact coverage: %d checks, %d failures" % [count, failures])
	print("E08_COMPACT_TALLY " + JSON.stringify(Compact.cut_tally))
	quit(1 if failures > 0 or count == 0 else 0)
