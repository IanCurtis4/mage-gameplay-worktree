extends SceneTree
## Normal Godot gameplay process. No EditorPlugin resources or simulated deaths.
const Candidate = preload("res://scripts/map_authoring/preview/gameplay_candidate.gd")
const Launcher = preload("res://scripts/map_authoring/preview/gameplay_launcher.gd")
const App = preload("res://scripts/map_authoring/preview/gameplay_app.gd")
const View = preload("res://scripts/world/authored_expedition_view.gd")
const PatrolFixture = preload("res://tests/map_editor_patrol_test.gd")
const BridgeFixture = preload("res://tests/map_editor_viewport_test.gd")
const MapFixture = preload("res://tests/map_editor_borders_test.gd")
const Maps = preload("res://scripts/map_authoring/composition/map_compiler.gd")
const Patrols = preload("res://scripts/map_authoring/patrol/patrol_compiler.gd")
class DamageProbe extends Control:
	var actual_damage := 0.0
	func record(result: Dictionary) -> void: actual_damage += float(result.get("actual_damage",0.0))

var checks: Array[Dictionary] = []
var app: App
func _initialize() -> void: run.call_deferred()
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok}); print("F9_GAMEPLAY_CHECK "+id+" "+str(ok))
func run() -> void:
	var source := PatrolFixture.fixture(); var before := ExpeditionCanonical.digest(source)
	var compiled := Patrols.compile(source)
	check("authored_patrol_with_real_population_compiles",compiled.ok)
	if not compiled.ok: print(compiled); finish(); return
	var made := Candidate.create("patrol",compiled.package,Patrols.Document.hash_source(source))
	check("passive_candidate_accepted",made.ok and Candidate.valid(made.candidate))
	check("stale_authorship_rejected",Candidate.create("patrol",compiled.package,"0".repeat(64)).code == "candidate_stale")
	var tampered: Dictionary = made.candidate.duplicate(true); tampered.package.source_hash = "0".repeat(64)
	check("tampered_payload_rejected",not Candidate.valid(tampered))
	tampered = made.candidate.duplicate(true); tampered["script"] = "res://scripts/main.gd"
	check("executable_field_rejected",not Candidate.valid(tampered))
	var prepared := Candidate.prepare(made.candidate)
	check("canonical_body_and_patrol_validation_succeeds",prepared.ok)
	if not prepared.ok: print(prepared); finish(); return
	check("real_player_profile_not_inspection_radius",prepared.manifest._data.input.traversal.radius == 20.0 and prepared.manifest._data.input.traversal.height == 32.0)
	check("authored_entry_kept_and_candidate_bound",not prepared.ephemeral_entry and prepared.manifest._data.input.preview_candidate_hash == made.candidate.candidate_hash)
	check("preparation_preserves_source_and_published_package",ExpeditionCanonical.digest(source) == before and Candidate.valid(made.candidate))
	var mapped := Candidate.create("map",Candidate.map_package(made.candidate),Candidate.map_package(made.candidate).source_hash)
	var map_prepared := Candidate.prepare(mapped.candidate)
	check("map_without_entry_gets_explicit_ephemeral_safe_anchor",map_prepared.ok and map_prepared.ephemeral_entry and not map_prepared.entry.is_empty())
	var narrow_source := Maps.Document.sample()
	for piece: Dictionary in narrow_source.pieces:
		var previous: String = piece.piece_hash
		for port: Dictionary in piece.source.connectors: port.width = 24
		piece.piece_hash = Maps.Document.Schema.semantic_hash(piece.source)
		for instance: Dictionary in narrow_source.instances:
			if instance.piece_hash == previous: instance.piece_hash = piece.piece_hash
	var narrow := Maps.compile(narrow_source)
	check("small_inspection_body_accepts_narrow_door",narrow.ok)
	var narrow_candidate := Candidate.create("map",narrow.package,narrow.package.source_hash)
	var narrow_runtime := Candidate.prepare(narrow_candidate.candidate)
	check("real_player_refuses_narrow_door_without_shrinking",not narrow_runtime.ok and narrow_runtime.code == "body_unreachable")
	var created := Launcher.create_session(made.candidate)
	check("isolated_session_created",created.ok)
	if not created.ok: print(created); finish(); return
	var resolved := Launcher.resolve(created.path)
	check("session_resolves_same_immutable_candidate",resolved.ok and resolved.candidate == made.candidate)
	check("foreign_session_path_refused",not Launcher.resolve(ProjectSettings.globalize_path("user://profile.json")).ok)
	var controls_path := ProjectSettings.globalize_path("user://controls.cfg")
	var personal_before := FileAccess.get_sha256(controls_path) if FileAccess.file_exists(controls_path) else "absent"
	app = App.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var opened := app.open(created.path)
	check("app_claims_session",opened.ok)
	check("second_owner_refused",not Launcher.claim(resolved).ok)
	var started := app.start()
	check("real_campaign_enters_transactionally",started.ok and is_instance_valid(app.host) and app.host.campaign_runtime != null)
	if not started.ok: print(started); finish(); return
	var host := app.host
	var profile_hash := FileAccess.get_sha256(created.directory.path_join("profile/profile.json"))
	check("active_preview_refuses_duplicate_start",not app.start().ok and app.host == host and FileAccess.get_sha256(created.directory.path_join("profile/profile.json")) == profile_hash)
	check("active_preview_refuses_replacement_without_losing_world",not app.open(created.path).ok and app.host == host and host.player.world_motion.is_current_world())
	check("refused_request_keeps_live_session_status",app.status == "active" and app.caption.text.contains("jogando") and not app.caption.text.contains("unknown"))
	check("actual_player_enemy_and_hud_installed",host.player is PlayerActor and host.enemies.size() == 1 and host.enemies[0] is EnemyActor and host.ui_root != null and host.battle_controls != null)
	check("authored_skin_replaces_technical_decks",host.expedition_view is View and host.expedition_view.skin.get_child_count() > 0 and host.expedition_view._decks.is_empty())
	check("profile_and_controls_use_session_paths",host.persistent_facade == app.facade and app.facade._store._base_directory == created.directory.path_join("profile") and host.control_preferences.path == created.directory.path_join("controls.cfg"))
	check("actor_owner_and_world_binding_preserved",host.player.get_parent() == host and host.enemies[0].get_parent() == host and host.player.world_motion.is_current_world())
	await process_frame; await process_frame
	var enemy := host.enemies[0] as EnemyActor
	check("existing_patrol_and_threat_are_real",not enemy.patrol.is_empty() and enemy.patrol_valid() and enemy.threat != null)
	check("shared_ordering_runs_over_foreign_actors",host.expedition_view.ordering.ok and not host.player.z_as_relative)
	await capture("gameplay_start")
	var point := host.player.world_point().position
	# Ground-move intent: smart-lock assist near the enemy is covered by WorldTargeting (checkpoint32).
	host.control_preferences.smart_lock = false
	var clicked := host.spatial_pointer_move(View.project(Vector3(120,0,200)))
	check("canonical_pointer_starts_real_movement",clicked.ok)
	var deadline := Time.get_ticks_msec()+4000
	while is_instance_valid(app.host) and app.host.player.world_point().position.distance_to(point) < 30 and Time.get_ticks_msec() < deadline: await process_frame
	host = app.host
	check("player_advances_world_point_without_editor_circle",host.player.world_point().position.distance_to(point) >= 30 and host.player.world_motion.is_current_world())
	# Read the exact persisted cut; no manual relocation, HP edits, or fake death.
	var suspended := await app.suspend()
	await process_frame
	check("canonical_suspend_returns_to_preview_controls",suspended.ok and not is_instance_valid(app.host) and app.status == "suspended" and not app.get_children().any(func(node: Node) -> bool: return node is CharacterMenu))
	var profile := app.facade.current_profile(); var lock := profile.expedition_for_character(profile.selected_character_id)
	var cut := ExpeditionService.new(app.facade)._restore(lock)
	check("suspension_contains_restorable_real_graph",cut.ok)
	if not cut.ok: print(cut); finish(); return
	var expected := simulation(cut.root); cut.root.free()
	var resumed := app.resume()
	check("resume_installs_same_candidate",resumed.ok and is_instance_valid(app.host) and app.host.expedition_view is View)
	if not resumed.ok: print(resumed); finish(); return
	check("resume_changes_only_expected_lifecycle",expected.state.lifecycle == "suspended" and app.host.campaign_runtime.state.lifecycle == "active")
	expected.state.lifecycle = "active"
	var actual := simulation(app.host)
	if actual != expected:
		for field: String in expected:
			if actual[field] != expected[field]: print("F9_GAMEPLAY_CUT_DIFF "+field+" "+str(expected[field])+" -> "+str(actual[field]))
	check("resume_preserves_exact_gameplay_cut",actual == expected)
	check("restored_controls_are_reassigned_by_preview_owner",app.host.control_preferences.path == app.session.directory.path_join("controls.cfg"))
	await process_frame
	host = app.host; enemy = host.enemies[0]
	var skin_before: int = host.expedition_view.skin.get_instance_id()
	var status_panel := host.ui_root.get_node_or_null("ExpeditionStatus") as ExpeditionStatusPanel
	check("completion_hint_names_living_blockers",status_panel != null and status_panel.completion_hint().begins_with("Ainda há inimigos"))
	var damage := DamageProbe.new(); app.add_child(damage)
	enemy.health.damage_applied.connect(damage.record)
	var attack := host.spatial_pointer_move(View.project(enemy.world_point().position)+Vector2(0,-24))
	check("pointer_selects_actual_enemy_for_combat",attack.ok and host.player.target == enemy)
	deadline = Time.get_ticks_msec()+12000
	while is_instance_valid(enemy) and enemy.is_alive() and is_instance_valid(app.host) and Time.get_ticks_msec() < deadline: await process_frame
	check("real_attack_changes_enemy_health",damage.actual_damage > 0.0)
	# Deaths are committed once combat ends (checkpoint33), not on the killing frame;
	# since checkpoint37 as one journal entry on this same host (no world capture).
	deadline = Time.get_ticks_msec()+30000
	# Checkpoint38: the profile write runs on a worker thread (forced here; headless
	# runs default to the synchronous write, which e07_f7_actions keeps covering).
	OS.set_environment("RAGRPG_BACKGROUND_SAVE","1")
	var journal_frame_ms := 0.0; var frame_clock := Time.get_ticks_usec(); var saw_background := false
	while Time.get_ticks_msec() < deadline and not (is_instance_valid(app.host) and app.host.campaign_runtime != null and app.host.campaign_runtime.state.slots.guard.initial_resolved and not app.host.expedition_save_busy()):
		await process_frame
		journal_frame_ms = maxf(journal_frame_ms,(Time.get_ticks_usec()-frame_clock)/1000.0); frame_clock = Time.get_ticks_usec()
		saw_background = saw_background or (is_instance_valid(app.host) and app.host.expedition_save_busy())
	print("F9_GAMEPLAY_JOURNAL_FRAME_MS "+str(snappedf(journal_frame_ms,0.1)))
	check("real_combat_resolves_population_slot",is_instance_valid(app.host) and app.host.campaign_runtime.state.slots.guard.initial_resolved)
	await process_frame
	var cleared_panel := app.host.ui_root.get_node_or_null("ExpeditionStatus") as ExpeditionStatusPanel if is_instance_valid(app.host) else null
	check("completion_hint_points_to_marker_after_clear",cleared_panel != null and cleared_panel.completion_hint().begins_with("Fique dentro do círculo"))
	var journal_lock := app.facade.current_profile().expedition_for_character(app.facade.current_profile().selected_character_id)
	var journal_payloads: Array = ExpeditionService.Journal.decode(journal_lock.journal,journal_lock.checkpoint).get("payloads",[]) if journal_lock != null else []
	check("death_commits_as_one_journal_entry",journal_payloads.size() >= 1 and not ExpeditionService.Journal.is_collect(journal_payloads[0]) and journal_payloads[0].events.size() == 1 and journal_lock.receipts.values().any(func(receipt: Dictionary) -> bool: return receipt["operation"] == "journal"))
	check("journal_keeps_live_host_and_skin",is_instance_valid(app.host) and app.host == host and app.host.expedition_view.skin.get_instance_id() == skin_before and not app.host.enemies.has(enemy) and not enemy.visible and enemy.process_mode == Node.PROCESS_MODE_DISABLED and not app.host.get_tree().paused)
	check("journal_commit_frame_stays_short",journal_frame_ms < 1500.0)
	check("deaths_are_written_in_the_background",saw_background)
	var reread: Dictionary = ExpeditionAssetLock.from_record(JSON.parse_string(JSON.stringify(journal_lock.to_record()))) if journal_lock != null else {"ok":false}
	check("journal_survives_the_profile_json_round_trip",reread.ok and reread.lock.journal == journal_lock.journal and reread.lock.to_record().size() == 8)
	var replayed := ExpeditionService.new(app.facade)._restore(journal_lock) if journal_lock != null else {"ok":false}
	var same_replay := false
	if replayed.ok:
		var copy: RunController = replayed.root
		var copy_enemy: EnemyActor = copy.campaign_runtime.actors.get("guard")
		var stable: String = replayed.entities.stable_for(copy_enemy.get_instance_id()) if copy_enemy != null else ""
		same_replay = copy.campaign_runtime.state.slots == host.campaign_runtime.state.slots and copy.campaign_runtime.state.stages == host.campaign_runtime.state.stages and copy.reward_service._tickets == host.reward_service._tickets and copy.reward_service._queue == host.reward_service._queue and copy.reward_service._next_sequence == host.reward_service._next_sequence and copy.rng.state == ExpeditionService.Journal.decode(journal_lock.journal,journal_lock.checkpoint).payloads[0].rng_state and copy.enemies.size() == host.enemies.size() and copy.campaign_runtime.pending_events == host.campaign_runtime.pending_events and copy_enemy != null and not copy_enemy.visible and int(replayed.snapshot.objects[stable].node.mode) == Node.PROCESS_MODE_DISABLED
		copy.free()
	check("base_plus_journal_restores_live_campaign_state",same_replay)
	# Checkpoint38: out of combat the drop and its XP reach the character without
	# a button, as one more journal entry on the same host.
	var issued: int = journal_payloads[0].tickets.size() if not journal_payloads.is_empty() else 0
	deadline = Time.get_ticks_msec()+10000
	while issued > 0 and Time.get_ticks_msec() < deadline and is_instance_valid(app.host) and (app.host.reward_service.has_uncollected() or app.host.expedition_save_busy()): await process_frame
	OS.set_environment("RAGRPG_BACKGROUND_SAVE","")
	var collected_lock := app.facade.current_profile().expedition_for_character(app.facade.current_profile().selected_character_id)
	var collected_payloads: Array = ExpeditionService.Journal.decode(collected_lock.journal,collected_lock.checkpoint).get("payloads",[]) if collected_lock != null else []
	check("drops_and_xp_are_collected_automatically",issued > 0 and app.host == host and not host.reward_service.has_uncollected() and not collected_payloads.is_empty() and ExpeditionService.Journal.is_collect(collected_payloads[-1]) and collected_payloads[-1].delivered.size() == issued and app.facade.current_profile().reward_session.last_committed_seq == collected_payloads[-1].session.last_committed_seq and collected_lock.effective_session() == app.facade.current_profile().reward_session)
	var replayed_collect := ExpeditionService.new(app.facade)._restore(collected_lock) if collected_lock != null else {"ok":false}
	check("base_plus_journal_restores_delivered_rewards",replayed_collect.ok and not replayed_collect.root.reward_service.has_uncollected() and replayed_collect.root.reward_service._tickets == host.reward_service._tickets)
	if replayed_collect.ok: replayed_collect.root.free()
	var backdrop: Node = host.get_node_or_null("ExpeditionBackdrop")
	check("themed_parallax_backdrop_follows_stage_biome",backdrop is CanvasLayer and backdrop.layer < 0 and backdrop.biome == backdrop.theme_id(String(host.expedition_view.geometry._stage.get("biome",""))) and backdrop.get_child_count() >= 4)
	await capture("gameplay_combat")
	var old_directory: String = app.session.directory; var old_hash: String = app.session.session.candidate_hash
	var restarted := await app.restart()
	check("restart_creates_fresh_disposable_session",restarted.ok and app.session.directory != old_directory and app.session.session.candidate_hash == old_hash)
	check("restart_preserves_old_profile_and_resets_encounter",FileAccess.file_exists(old_directory.path_join("profile/profile.json")) and app.host.enemies.size() == 1 and not app.host.campaign_runtime.state.slots.guard.initial_resolved)
	check("personal_controls_remain_untouched",(FileAccess.get_sha256(controls_path) if FileAccess.file_exists(controls_path) else "absent") == personal_before)
	await app.suspend(); await process_frame
	app.request_close()
	check("close_releases_only_owned_session_lease",app.status == "closed" and not DirAccess.dir_exists_absolute(app.session.directory.path_join("active.lock")))
	app.free(); app = null
	await bridge_case()
	finish()

static func threat_data(view: ThreatView) -> Dictionary:
	return {"enemy_id":view.enemy_id,"current_id":view.current_id,"forced_id":view.forced_id,"forced_remaining":view.forced_remaining,"engaged":view.engaged,"revision":view.revision,"switch_threshold":view.switch_threshold,"entries":view.entries.duplicate(true)}

func bridge_case() -> void:
	var built := Maps.compile(MapFixture.map_source(BridgeFixture.source(),"ruin_envelope_v1"))
	check("real_bridge_map_compiles",built.ok)
	if not built.ok: print(built); return
	var made := Candidate.create("map",built.package,built.package.source_hash)
	var prepared := Candidate.prepare(made.candidate)
	check("bridge_supports_real_body_and_lower_passage",prepared.ok)
	if not prepared.ok: print(prepared); return
	var created := Launcher.create_session(made.candidate)
	app = App.new(); app.quit_on_close = false; root.add_child(app); current_scene = app
	var opened := app.open(created.path)
	var started := app.start() if opened.ok else opened
	check("bridge_uses_actual_player_campaign",started.ok and is_instance_valid(app.host))
	if not started.ok: print(started); return
	var host := app.host; var world := host.player.world_motion.geometry
	var lower := BridgeFixture.at(world,Vector3(50,0,150)); var upper := BridgeFixture.at(world,Vector3(50,40,150))
	var picked := host.expedition_view.pick(View.project(upper.position),world.geometry_revision)
	check("gameplay_pointer_keeps_upper_floor_occlusion",lower != null and upper != null and picked.ok and picked.data.point.surface_id == upper.surface_id and lower.surface_id != upper.surface_id)
	var moved := host.spatial_pointer_move(View.project(upper.position))
	check("bridge_click_plans_canonical_ramp_route",moved.ok)
	var deadline := Time.get_ticks_msec()+12000
	while host.player.world_point().position.distance_to(upper.position) > 5 and Time.get_ticks_msec() < deadline: await process_frame
	check("real_player_walks_ramp_and_reaches_bridge",host.player.world_point().surface_id == upper.surface_id and host.player.world_point().position.distance_to(upper.position) <= 5)
	check("bridge_keeps_body_dimensions_and_actor_owner",host.player.get_parent() == host and host.player.collision_radius == 20.0 and host.player.world_motion.profile().radius == 20.0 and host.expedition_view.ordering.ok)
	await capture("gameplay_bridge")
	await app.suspend(); await process_frame; app.request_close()

static func simulation(value: RunController) -> Dictionary:
	var actors: Dictionary = {}
	for id: String in value.campaign_runtime.actors:
		var actor: EnemyActor = value.campaign_runtime.actors[id]
		actors[id] = {"point":actor.world_point().to_data(),"hp":actor.health.current_hp,"patrol":actor.patrol.duplicate(true),"threat":threat_data(actor.threat.view())}
	return {"point":value.player.world_point().to_data(),"hp":value.player.health.current_hp,"sp":value.player.current_sp,"attack_cd":value.player.attack_cooldown,"slash_cd":value.player.slash_cooldown,"rng":value.rng.state,"actors":actors,"state":value.campaign_runtime.state.view(),"claims":value.campaign_runtime.state.entry_claims.duplicate(true)}

func capture(label: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	var target := OS.get_environment("F9_EVIDENCE").path_join(label+".png")
	var image := root.get_texture().get_image()
	check("capture_"+label,image != null and not image.is_empty() and image.save_png(target) == OK)

func finish() -> void:
	if is_instance_valid(app): app.free()
	paused = false
	var ok := checks.all(func(item: Dictionary) -> bool: return item.ok)
	print("F9_GAMEPLAY_RESULT "+JSON.stringify({"ok":ok,"count":checks.size(),"checks":checks})); quit(0 if ok else 1)
