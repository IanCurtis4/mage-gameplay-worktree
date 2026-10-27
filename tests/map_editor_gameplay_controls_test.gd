extends SceneTree
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const Protocol = preload("res://scripts/map_authoring/preview/gameplay_protocol.gd")
const Population = preload("res://scripts/map_authoring/population/population_compiler.gd")
const Fixture = preload("res://tests/map_editor_population_test.gd")
class ObservedApp extends App:
	var dispatches := 0
	func command(action: Dictionary) -> Dictionary:
		dispatches += 1
		return await super.command(action)
var app: ObservedApp
var launcher: Launcher
var checks: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_CONTROLS_CHECK "+id+" "+str(ok))
func run() -> void:
	var source := Fixture.fixture(); source.brushes = []; source.slots = []; source.exclusions = []
	source.plan_hash = Population.Document.recipe_hash(source)
	var built := Population.compile(source)
	check("authored_interactions_compile_without_synthetic_enemies",built.ok)
	if not built.ok: print(built); finish(); return
	var candidate := Candidate.create("population",built.package,built.package.source_hash)
	var created := Launcher.create_session(candidate.candidate,"mage")
	var seed := ProfileFacade.new(ProfileStore.new(String(created.directory).path_join("profile"),ProfileCatalog.pilot()))
	var made := seed.create_character("controls_character",0,"Teste de comandos",&"mage")
	var profile := seed.current_profile()
	var unlocked := seed.grant_playtest_admin("controls_skills",profile.revision,profile.selected_character_id,&"unlock_skills",&"",{})
	profile = seed.current_profile()
	var leveled := seed.grant_playtest_admin("controls_levels",profile.revision,profile.selected_character_id,&"max_levels",&"",{})
	check("disposable_skill_fixture_uses_canonical_profile_admin",made.ok and unlocked.ok and leveled.ok)
	var window := Launcher.create_window(created.path)
	app = ObservedApp.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var opened := app.open_window(window.path); var started := app.start() if opened.ok else opened
	check("real_mage_boots_with_existing_learned_skill",started.ok and app.host.player.available_skill_ids().has(&"fire_wall"))
	if not started.ok: print(started); finish(); return
	launcher = Launcher.new(); launcher.window_path = window.path; launcher.session_path = created.path
	var revision := app.host.player.world_motion.geometry.geometry_revision
	var action := {"kind":"skill","skill_id":"fire_wall","preview":false,"rank":1,"position_xyz":[160,0,200],"geometry_revision":revision}
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(action,"",true,true))
	check("fingerprint_survives_json_integer_float_roundtrip",Protocol.fingerprint(created.session.session_id,action) == Protocol.fingerprint(created.session.session_id,decoded))
	var bad := action.duplicate(true); bad.position_xyz[0] = true
	check("boolean_coordinate_rejected",not Protocol.action_valid(bad))
	bad = action.duplicate(true); bad["script"] = "res://scripts/main.gd"
	check("executable_or_unknown_payload_field_rejected",not Protocol.action_valid(bad))
	bad = action.duplicate(true); bad.geometry_revision = true
	check("boolean_revision_rejected",not Protocol.action_valid(bad))
	var inspected := await send({"kind":"inspect"})
	check("inspect_reports_actual_resources_and_geometry",inspected.ok and inspected.state.player.sp == app.host.player.current_sp and inspected.state.geometry_revision == revision)
	var point := app.host.player.world_point().to_data()
	var stale := await send({"kind":"move","position_xyz":[100,0,200],"geometry_revision":revision+1})
	check("stale_geometry_refuses_without_moving_actor",not stale.ok and stale.code == "command_stale" and app.host.player.world_point().to_data() == point)
	var moved := await send({"kind":"move","position_xyz":[100,0,200],"geometry_revision":revision})
	check("remote_move_uses_real_pointer_authority",moved.ok)
	var deadline := Time.get_ticks_msec()+10000
	while app.host.player.world_point().position.distance_to(Vector3(100,0,200)) > 2 and Time.get_ticks_msec() < deadline: await create_timer(0.02).timeout
	check("remote_move_advances_real_world_point",app.host.player.world_point().position.distance_to(Vector3(100,0,200)) <= 2)
	var preview := action.duplicate(true); preview.preview = true
	var sp := app.host.player.current_sp
	var shown := await send(preview)
	check("skill_preview_does_not_spend_sp",shown.ok and app.host.player.current_sp == sp)
	var request_id := Crypto.new().generate_random_bytes(12).hex_encode()
	var blocked := Protocol.reply_path(window,request_id)
	DirAccess.make_dir_absolute(blocked)
	var dispatches := app.dispatches
	var posted := launcher.request_action(action,created.session.session_id,request_id)
	check("skill_request_accepted_before_ack_io_failure",posted.ok and posted.pending)
	deadline = Time.get_ticks_msec()+20000
	while app.host.player.current_sp >= sp and Time.get_ticks_msec() < deadline: await create_timer(0.02).timeout
	check("actual_cast_spends_sp_and_starts_cooldown",app.host.player.current_sp < sp and app.host.player.skill_cooldown(&"fire_wall") > 0)
	check("actual_world_field_is_emitted",app.host.get_children().any(func(node: Node) -> bool: return node is FireWall and node.world_field != null and node.world_field.is_current()))
	var suspended := await app.suspend(); await process_frame
	check("suspend_during_failed_ack_preserves_real_graph",suspended.ok and app.status == "suspended" and not is_instance_valid(app.host))
	var saved := app.facade.current_profile(); var lock := saved.expedition_for_character(saved.selected_character_id)
	var cut := ExpeditionService.new(app.facade)._restore(lock)
	check("nonzero_skill_state_is_durably_restorable",cut.ok and cut.root.player.current_sp < cut.root.player.max_sp and cut.root.player.skill_cooldown(&"fire_wall") > 0)
	if not cut.ok: print(cut); finish(); return
	var expected_sp: float = cut.root.player.current_sp; var expected_cd: float = cut.root.player.skill_cooldown(&"fire_wall")
	cut.root.free()
	check("failed_ack_never_redispatches_real_skill",app.dispatches == dispatches+1 and launcher.poll_reply(request_id,posted.session_id,posted.fingerprint).get("pending",false))
	DirAccess.remove_absolute(blocked)
	var acknowledged := await reply(posted)
	check("ack_retry_publishes_cached_result",acknowledged.ok and app.dispatches == dispatches+1)
	var repeated := launcher.request_action(action,posted.session_id,request_id)
	check("completed_request_replay_is_cached",repeated.ok and not repeated.pending and app.dispatches == dispatches+1)
	bad = action.duplicate(true); bad.position_xyz[0] = 170
	var conflict := launcher.request_action(bad,posted.session_id,request_id)
	check("request_id_cannot_change_payload",not conflict.ok and conflict.code == "request_conflict")
	var resumed := await send({"kind":"resume"})
	check("remote_resume_keeps_exact_nonzero_sp_and_cooldown",resumed.ok and resumed.state.player.sp == expected_sp and _cooldown(resumed.state,"fire_wall") == expected_cd)
	var rest_move := await send({"kind":"move","position_xyz":[64,0,320],"geometry_revision":revision})
	check("existing_interaction_approach_is_real_movement",rest_move.ok)
	deadline = Time.get_ticks_msec()+10000
	while app.host.player.world_point().position.distance_to(Vector3(64,0,320)) > 3 and Time.get_ticks_msec() < deadline: await create_timer(0.02).timeout
	var rested := await send({"kind":"interaction","interaction_id":"rest"})
	await process_frame
	check("existing_refuge_interaction_suspends_canonically",rested.ok and app.status == "suspended" and not is_instance_valid(app.host))
	var previous_path: String = app.session.path
	var restarted := await send({"kind":"restart"})
	check("remote_restart_changes_run_but_keeps_window",restarted.ok and app.window.path == window.path and app.session.path != previous_path)
	var untouched := app.host.player.world_point().to_data()
	var obsolete := launcher.request_action({"kind":"move","position_xyz":[300,0,200],"geometry_revision":revision},created.session.session_id)
	check("old_run_command_cannot_cross_restart",not obsolete.ok and obsolete.code == "command_stale" and app.host.player.world_point().to_data() == untouched)
	check("restart_does_not_copy_admin_fixture_into_fresh_profile",not app.host.player.available_skill_ids().has(&"fire_wall"))
	var count := app.dispatches
	var malformed: String = String(window.directory).path_join("command.request")
	Launcher.write_atomic(malformed,'{"format_version":1,"kind":"inspect","kind":"close"}'.to_utf8_buffer())
	await create_timer(0.6).timeout
	check("duplicate_json_is_rejected_without_dispatch",app.dispatches == count and app.status == "active" and FileAccess.file_exists(String(window.directory).path_join("command.rejected")))
	var closed := await send({"kind":"close"})
	check("close_reply_is_published_and_leases_released",closed.ok and app.status == "closed" and not app.claimed and not app.window_claimed)
	finish()

static func _cooldown(state: Dictionary, id: String) -> float:
	for skill: Dictionary in state.skills:
		if skill.skill_id == id: return skill.cooldown
	return -1

func send(action: Dictionary) -> Dictionary:
	var posted := launcher.request_action(action)
	if not posted.ok: return posted
	return await reply(posted)

func reply(posted: Dictionary) -> Dictionary:
	var deadline := Time.get_ticks_msec()+90000
	while Time.get_ticks_msec() < deadline:
		var read := launcher.poll_reply(posted.request_id,posted.session_id,posted.fingerprint)
		if not read.ok: return read
		if not read.pending: return read.reply.result
		await create_timer(0.02).timeout
	return {"ok":false,"code":"test_reply_timeout"}

func finish() -> void:
	if is_instance_valid(app): app.free()
	paused = false
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_CONTROLS_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
