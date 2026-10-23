extends Node
## Diagnostic entry point: explicit checks execute in the Windows release template.
## Artificial death events below test transactions, never combat viability.
const Phase = preload("res://data/expedition/phases/ruined_crossing.gd")
var checks := 0
var failures := 0
var output := ""
var mode := "prepare"
var seed_text := "42"
var report := {}
var facade: ProfileFacade
var host: RunController
var tree: SceneTree

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tree = get_tree()
	_run.call_deferred()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		failures += 1
		push_error("F8: " + label)
	return value

func stop() -> void:
	report["checks"] = checks
	report["failures"] = failures
	write_json(output.path_join(mode + ".json"), report)
	print("E07 F8 CANDIDATE %s: %s checks=%d failures=%d release=%s" % [mode, "PASS" if failures == 0 else "FAIL", checks, failures, not OS.is_debug_build()])
	tree.paused = false
	tree.quit(0 if failures == 0 else 1)

func write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures += 1
		push_error("F8 output unavailable: " + path)
		return
	file.store_string(JSON.stringify(value, "  ", true))
	file.close()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--f8-output="): output = arg.trim_prefix("--f8-output=")
		elif arg.begins_with("--f8-mode="): mode = arg.trim_prefix("--f8-mode=")
		elif arg.begins_with("--f8-seed="): seed_text = arg.trim_prefix("--f8-seed=")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://.godot/verification/e07_f8/probe_headless")
	if not check(output.is_absolute_path() and not output.begins_with("user://"), "explicit isolated output directory"): tree.quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	tree.root.size = Vector2i(1920, 1080)
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	report = {"mode": mode, "seed": seed_text, "release": not OS.is_debug_build(), "engine": Engine.get_version_info(), "cpu": OS.get_processor_name(), "cpu_threads": OS.get_processor_count(), "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(), "gpu": RenderingServer.get_video_adapter_name(), "window": str(tree.root.size), "vsync": "disabled", "max_fps": 0}
	var registry := SnapshotRegistry.new()
	if not check(not registry.coverage_manifest().is_empty(), "snapshot adapter manifest is packaged"): stop(); return
	if not check(registry._content_digest("res://assets/art/animations/mage_weaponless.png").length() == 64 and registry._content_digest("res://assets/art/animations/f8_missing_asset.png").is_empty(), "source or imported texture has a strict digest; missing content is rejected"): stop(); return
	var loaded := BuildContentLoader.load_catalog(true)
	if not check(loaded.get("ok", false), "production catalog available from source or PCK"): stop(); return
	var catalog := ProfileCatalog.pilot()
	if not check(catalog != null and loaded["catalog"].mob_catalog().ids().size() == 11, "eleven production mob definitions"): stop(); return
	facade = ProfileFacade.new(ProfileStore.new(output.path_join("profile"), catalog), ProfileRewardResolver.pilot_progression())
	var opened := facade.open_profile()
	if not check(opened.get("ok", false), "isolated profile opens: " + str(opened.get("error_code"))): stop(); return
	if mode == "prepare": await prepare()
	elif mode == "resume": await resume_and_complete()
	else: check(false, "unsupported probe mode")
	stop()

func enter(id: String) -> bool:
	var menu := CharacterMenu.new()
	menu.set_profile_facade(facade)
	tree.root.add_child(menu)
	tree.current_scene = menu
	var panel := PhaseSelectionPanel.new()
	menu.add_child(panel)
	panel.configure(menu, id)
	panel.seed_input.text = seed_text
	var start := Time.get_ticks_usec()
	var result: Dictionary = await panel.start()
	report["entry_or_resume_ms"] = (Time.get_ticks_usec() - start) / 1000.0
	if not check(result.get("ok", false), "UI entry/restore: " + str(result.get("error_code"))): return false
	host = tree.current_scene as RunController
	return check(host != null and host.visible and host.campaign_runtime != null and host.player.is_alive(), "installed visible runtime and living player")

func prepare() -> void:
	if not check(facade.current_profile().characters.is_empty(), "prepare requires fresh synthetic profile"): return
	var generated_start := Time.get_ticks_usec()
	var generated := ExpeditionAssembler.build(Phase.input(seed_text))
	report["generation_ms"] = (Time.get_ticks_usec() - generated_start) / 1000.0
	if not check(generated.get("ok", false), "real modular assembler"): return
	var manifest: ExpeditionManifest = generated["data"]["manifest"]
	var repeated := ExpeditionAssembler.build(Phase.input(seed_text))
	if not check(repeated.get("ok", false) and repeated["data"]["manifest"].to_data() == manifest.to_data(), "deterministic realized manifest"): return
	var made := facade.create_character("f8_create", facade.current_profile().revision, "Prova F8", &"mage")
	if not check(made.get("ok", false), "create synthetic level-one character"): return
	var id := facade.current_profile().selected_character_id
	if not await enter(id): return
	var state := host.campaign_runtime.state
	report["manifest_sha256"] = JSON.stringify(state.manifest_data, "", true).sha256_text()
	report["stages"] = state.stages.size()
	report["population_total"] = state.slots.size()
	report["population_active"] = host.enemies.size()
	report["stage_geometry"] = []
	for stage: Dictionary in state.manifest_data["stages"]:
		report["stage_geometry"].append(stage)
	if not check(state.stages.size() == 4 and state.slots.size() == 5 and host.enemies.size() == 2, "approved small sample, five total and two active initial slots"): return
	if not check(host.run_state.pending_choices == 2, "two distinct initial augment grants"): return
	# Natural combat uses the actual level-one player, HP, attacks, AI and geometry.
	# Stop sampling if a durable death transition replaces the current scene.
	var victim := host.enemies[0] as EnemyActor
	var player_hp := host.player.health.current_hp
	var enemy_hp := victim.health.current_hp
	host.player.pursue(victim)
	host._select_enemy(victim)
	report["natural_combat"] = await sample_frames(5.0)
	if tree.current_scene is RunController: host = tree.current_scene as RunController
	report["natural_combat"]["player_hp_before"] = player_hp
	report["natural_combat"]["player_hp_after"] = host.player.health.current_hp
	report["natural_combat"]["enemy_hp_before"] = enemy_hp
	report["natural_combat"]["enemy_hp_after"] = victim.health.current_hp if is_instance_valid(victim) else 0.0
	report["natural_combat"]["lifecycle_after"] = host.campaign_runtime.state.lifecycle
	if not await settle_events(): return
	if not check(host.campaign_runtime.state.slots["entry_guard"]["life_state"] == "dead", "natural projectile death commits without a stuck snapshot barrier"): return
	tree.paused = true
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(tree.root.get_texture().get_image().save_png(output.path_join("natural_combat.png")) == OK, "native screenshot saved")
	var before := state_record()
	var save_start := Time.get_ticks_usec()
	var suspended: Dictionary = await status().run_action({"kind": "suspend"})
	report["suspend_ms"] = (Time.get_ticks_usec() - save_start) / 1000.0
	if not check(suspended.get("ok", false), "suspend through canonical writer: " + str(suspended.get("error_code"))): return
	before["character_id"] = id
	write_json(output.path_join("expected.json"), before)
	var profile_path := output.path_join("profile/profile.json")
	report["profile_bytes"] = FileAccess.get_file_as_bytes(profile_path).size()
	report["profile_sha256"] = FileAccess.get_sha256(profile_path)

func settle_events() -> bool:
	var deadline := Time.get_ticks_msec() + 90000
	while Time.get_ticks_msec() < deadline:
		if tree.current_scene is RunController: host = tree.current_scene as RunController
		if host.status_label.text.begins_with("A expedição está pausada"):
			report["blocked_status"] = host.status_label.text
			var diagnostic := SnapshotRegistry.new().capture(host, host._memory_snapshot_barrier)
			report["capture_diagnostic"] = {"ok": diagnostic.get("ok", false), "error_code": diagnostic.get("error_code", ""), "detail": diagnostic.get("detail", ""), "bytes": diagnostic.get("bytes", 0)}
			return check(false, host.status_label.text)
		if not host._memory_snapshot_pending and host.campaign_runtime.pending_events.is_empty(): return true
		await tree.process_frame
	return check(false, "event transaction did not settle before deadline: " + host.status_label.text)

func sample_frames(seconds: float) -> Dictionary:
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	var previous := started
	var initial_scene := tree.current_scene
	while Time.get_ticks_usec() - started < seconds * 1000000.0 and tree.current_scene == initial_scene:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - previous) / 1000.0)
		previous = now
	samples.sort()
	if samples.is_empty(): return {"samples": 0}
	return {"samples": samples.size(), "seconds": (previous - started) / 1000000.0, "p50_ms": samples[int((samples.size()-1)*0.50)], "p95_ms": samples[int((samples.size()-1)*0.95)], "p99_ms": samples[int((samples.size()-1)*0.99)], "max_ms": samples[-1], "note": "wall time between process frames; includes transition stalls; no HP refill or stat boost"}

func status() -> ExpeditionStatusPanel:
	return host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel

func state_record() -> Dictionary:
	return {"manifest_sha256": JSON.stringify(host.campaign_runtime.state.manifest_data, "", true).sha256_text(), "stage": host.campaign_runtime.state.current_stage_id, "clock": host.campaign_runtime.state.clock.remaining, "hp": host.player.health.current_hp, "sp": host.player.current_sp, "pending_choices": host.run_state.pending_choices, "run_id": host.run_state.run_id, "lifecycle": host.campaign_runtime.state.lifecycle}

func move_to(point_data: Dictionary) -> bool:
	var motion := host.player.world_motion
	var planned := motion.plan(ExpeditionPopulationPlanner.point(point_data), motion.geometry.geometry_revision)
	if not check(planned.get("ok", false), "route through canonical multilevel geometry"): return false
	var moved := motion.advance(10000.0)
	host.expedition_view.sync()
	return check(moved.get("ok", false) and moved["data"]["arrived"], "route arrival without direct teleport")

func command(intent: Dictionary) -> bool:
	var started := Time.get_ticks_usec()
	var result: Dictionary = await status().run_action(intent)
	if not check(result.get("ok", false), str(intent) + ": " + str(result.get("error_code"))): return false
	report["transaction_ms"].append({"kind": intent["kind"], "ms": (Time.get_ticks_usec() - started) / 1000.0})
	if tree.current_scene is RunController: host = tree.current_scene as RunController
	tree.paused = true
	return true

func resume_and_complete() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("expected.json")))
	if not check(expected is Dictionary, "previous-process durable expectations available"): return
	var lock := facade.current_profile().expedition_for_character(expected["character_id"])
	if not check(lock != null and lock.lifecycle == &"suspended", "new process finds suspended expedition"): return
	if not await enter(expected["character_id"]): return
	tree.paused = true
	var actual := state_record()
	for key: String in ["manifest_sha256", "stage", "clock", "hp", "sp", "pending_choices", "run_id"]:
		if not check(actual[key] == expected[key], "new process preserves " + key): return
	report["transaction_ms"] = []
	if host.campaign_runtime.state.lifecycle == "recovering":
		if not await command({"kind": "revive", "event_id": host.campaign_runtime.state.current_death_id}): return
	# Injected death events exercise every authored stage/receipt with no claim of
	# winning a fight. Actual combat frames are measured separately in prepare.
	for stage: String in ["entry", "left", "entry", "right", "final"]:
		if not check(host.campaign_runtime.state.current_stage_id == stage, "expected authored destination " + stage): return
		var slots: Array = host.campaign_runtime.actors.keys()
		for slot: String in slots:
			var actor: EnemyActor = host.campaign_runtime.actors[slot]
			if host.campaign_runtime.state.slots[slot]["stage_id"] != stage or not actor.is_alive(): continue
			actor.health.current_hp = 0.0
			actor.health._death_emitted = true
			var previous := host
			host._on_enemy_died(actor)
			var deadline := Time.get_ticks_msec() + 90000
			while tree.current_scene == previous and Time.get_ticks_msec() < deadline: await tree.process_frame
			if not check(tree.current_scene != previous and tree.current_scene is RunController, "death persisted before replacement"): return
			host = tree.current_scene as RunController
			tree.paused = true
		host.combat_participation.observe({}, 6.0)
		if not check(not host.encounter_active, "canonical combat participation window expires"): return
		while host.reward_service.has_uncollected():
			var ticket := host.reward_service.next_pending_ticket()
			if not check(ticket.get("ok", false), "detached pending ticket DTO"): return
			if not await command({"kind": "collect", "ticket_id": ticket["ticket_id"]}): return
		if stage == "final": break
		var portal_id := "entry_to_left" if stage == "entry" and not host.campaign_runtime.state.stages["left"]["visited"] else ("left_to_entry" if stage == "left" else ("entry_to_right" if stage == "entry" else "right_to_final"))
		var portal := host.campaign_runtime.state.portal_view(portal_id)
		if not move_to(portal["from_anchor"]): return
		if not await command({"kind": "travel", "portal_id": portal_id, "stage_id": stage}): return
	var exit_point := {}
	for objective: Dictionary in host.campaign_runtime.state.manifest_data["objectives"]:
		if objective["objective_id"] == "final_exit": exit_point = objective["point"]
	if not move_to(exit_point): return
	var profile := facade.current_profile()
	var character := profile.character_by_id(expected["character_id"])
	var before := {"gold": character.gold, "base": character.base_xp_total, "job": character.job_xp_total, "equipment": profile.equipment_instances.size()}
	if not await command({"kind": "finish", "outcome": "completed", "source": "final_exit"}): return
	profile = facade.current_profile()
	character = profile.character_by_id(expected["character_id"])
	check(character.gold == before["gold"] + 100 and character.base_xp_total == ProgressionRules.add_base_xp(before["base"], 300) and character.job_xp_total == ProgressionRules.add_job_xp(before["job"], 200, false), "exact final gold/Base/Job grant")
	check(profile.equipment_instances.size() == before["equipment"], "no guaranteed completion equipment")
	check(profile.reward_session == null and profile.expedition_for_character(expected["character_id"]) == null, "completion releases owner and session")
	check(host.run_state.pending_choices == 0 and host.run_state.augment_stacks.is_empty(), "temporary build ends on completion")
	report["completed"] = host.campaign_runtime.state.completed
	report["completion_gold"] = character.gold
	report["all_four_stages_visited"] = host.campaign_runtime.state.stages.values().all(func(record: Dictionary) -> bool: return record["visited"])
	check(report["completed"] and report["all_four_stages_visited"], "full authored branch and return completed")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(tree.root.get_texture().get_image().save_png(output.path_join("completed.png")) == OK, "native completion capture")
