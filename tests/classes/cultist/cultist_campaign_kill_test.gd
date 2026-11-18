extends SceneTree
## E10a T7 (A7.7) — campaign proof that a kill by Delirium gives XP and loot once to the
## Cultista, retry included. The expedition is entered through the real phase selection of
## E07 F7 (installed host in the tree, canonical loot, ExpeditionService journal and
## collection). The Cultista modules (the T7 stand-in of the Acólito base holding the
## Madness authority, and the production Cultista kit) are attached to the fixture
## character; a forest wolf bound to the same world goes into Delirium and kills a normal
## mob of the entry stage with its own attack, relayed by the RunController (T1 relay
## authorship). The death goes through _on_enemy_died, the journal, the reward ticket and its
## collection. Fixture profile directory only; the personal save is never touched.
const FixtureBase = preload("res://scripts/classes/cultist/fixture/cultist_fixture_base.gd")
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	ClassKitRegistry.clear_fixtures()
	root.size = Vector2i(1280, 720)
	var f := F.make("t7_delirium_kill")
	var facade: ProfileFacade = f["facade"]
	var menu := CharacterMenu.new()
	menu.set_profile_facade(facade)
	root.add_child(menu)
	current_scene = menu
	var panel := PhaseSelectionPanel.new()
	menu.add_child(panel)
	panel.configure(menu, f["a"])
	panel.seed_input.text = "42"
	var entered: Dictionary = await panel.start()
	check(entered.get("ok", false), "the expedition is entered through phase selection: " + str(entered.get("error_code", "")))
	if not entered.get("ok", false): _finish(); return
	var host := entered["root"] as RunController
	paused = true
	var player := host.player
	player.attach_origin_kit(FixtureBase.new().create_runtime())
	player.attach_kit(ClassKitRegistry.module(&"cultist").create_runtime())
	var authority := MadnessAuthority.of(player) as MadnessAuthority
	check(authority != null and player.kit != null and player.kit.get_script().resource_path == "res://scripts/classes/cultist/cultist_kit.gd", "Cultista modules attached; the origin holds the authority")
	var victim: EnemyActor = null
	for actor: CombatActor in host.enemies:
		if not MadnessHelpers.is_boss(actor): victim = actor as EnemyActor
	check(victim != null and victim.is_alive() and victim.is_inside_tree(), "a normal campaign mob is alive in the installed host")
	if victim == null: _finish(host); return
	var slot_id := host.campaign_runtime.slot_for_actor(victim)
	var slot: Dictionary = host.campaign_runtime.state.slots[slot_id]
	var occurrence_id: String = victim.occurrence.occurrence_id
	var xp_before := facade.current_profile().character_by_id(host.run_state.character_id).base_xp_total
	var job_before := facade.current_profile().character_by_id(host.run_state.character_id).job_xp_total
	# A real forest wolf bound to the same world, beside the victim (not a campaign slot).
	var attacker := EnemyActor.new()
	var spawn := MobOccurrence.new()
	spawn.occurrence_id = "t7_delirious_wolf"
	spawn.mob_base_id = &"forest_wolf"
	spawn.category_id = &"normal"
	spawn.origin_id = victim.occurrence.origin_id
	check(attacker.configure_occurrence(spawn, host.run_state.effect_catalog().mob_catalog(), host.navigation, player)["ok"], "the attacker is a real catalog mob")
	var world: WorldGeometry = host.campaign_runtime.worlds[slot["stage_id"]]
	var traversal: Dictionary = slot["traversal"]
	var center := victim.world_point()
	var bound := {"ok": false}
	for offset: Vector2 in [Vector2(36, 0), Vector2(-36, 0), Vector2(0, 36), Vector2(0, -36), Vector2(30, 30)]:
		var exact := world.ground_line_point_at(center, Vector2(center.position.x, center.position.z) + offset, traversal, world.geometry_revision)
		if not exact["ok"]: continue
		var data: Dictionary = exact["data"]["point"]
		bound = attacker.bind_world_geometry(world, ExpeditionWorldPoint.create(data["stage_id"], data["surface_id"], data["position"]), traversal, "t7_attacker")
		if bound["ok"]: break
	check(bound["ok"], "the attacker stands in the same world beside the victim: " + str(bound))
	if not bound["ok"]: attacker.free(); _finish(host); return
	attacker.global_position = Vector2(attacker.world_point().position.x, attacker.world_point().position.z)
	attacker.attack_requested.connect(host._on_enemy_attack_requested)
	host.add_child(attacker)
	attacker.set_process(false)
	victim.health.current_hp = 1.0
	var kills: Array[Dictionary] = []
	var recorder := func(result: Dictionary) -> void: if bool(result.get("killed", false)): kills.append(result)
	victim.health.damage_applied.connect(recorder)
	# Delirium: the authority points the attacker at the nearest non-boss enemy (the victim).
	var entered_state := authority.add(attacker, 100.0, "cast:t7_campaign", player)
	check(entered_state["entered"] == MadnessRules.STATE_DELIRIUM and attacker.combat_target() == victim, "the wolf enters Delirium and targets the campaign mob, never the boss: %s" % [entered_state])
	paused = false
	check(attacker.world_can_reach(victim, 55.0), "the delirious wolf reaches the victim in the world")
	for attempt: int in 20:
		if not victim.is_alive(): break
		attacker.attack_cooldown = 0.0
		attacker._advance_override_world(0.05) # the override step of EnemyActor._process
	paused = true
	check(kills.size() == 1 and EnemyActor.is_relay_result(kills[0]) and int(kills[0]["source_id"]) == player.get_instance_id(), "the Delirium hit kills the mob with the Cultista's authorship (%d kills)" % kills.size())
	check(host._credited_kills.has(victim.get_instance_id()) and player.origin_kit.get("calls").count("kill") == 1, "the kill is credited to the Cultista once")
	var deaths := host.campaign_runtime.pending_events.filter(func(event: Dictionary) -> bool: return event["kind"] == "mob_death" and event["slot_id"] == slot_id)
	check(deaths.size() == 1, "one campaign death event for the slot (through _on_enemy_died)")
	if not kills.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 9
		var events_before := host.campaign_runtime.pending_events.size()
		var retry := victim.apply_damage(_replay_request(kills[0], victim), rng)
		check(retry.is_empty() and player.origin_kit.get("calls").count("kill") == 1 and host.campaign_runtime.pending_events.size() == events_before, "a retried hit on the dead mob credits nothing again")
	# The test probe and the attacker leave before the journal (neither is part of the run).
	victim.health.damage_applied.disconnect(recorder)
	host.remove_child(attacker)
	if attacker.world_motion != null: attacker.world_motion.release()
	attacker.free()
	if deaths.is_empty(): _finish(host); return
	var service := ExpeditionService.new(facade)
	var barrier := SnapshotTickBarrier.new()
	check(barrier.acquire(host)["ok"], "coherent barrier")
	var journaled := service.journal_events(host, barrier, deaths, "t7_death", facade.current_profile().revision)
	check(journaled.get("ok", false), "the death journals through ExpeditionService: " + str(journaled.get("error_code", "")))
	var event_key := "mob:" + occurrence_id
	check(host.reward_service._events.has(event_key), "the Delirium kill mints the mob reward ticket")
	if not host.reward_service._events.has(event_key): barrier.release(); _finish(host); return
	var ticket_id: String = host.reward_service._events[event_key]
	var payload: Dictionary = host.reward_service.ticket(ticket_id)["payload"]
	check(int(payload["base_xp"]) > 0 and int(payload["job_xp"]) >= 0, "normal XP terms of the slot: %s" % [payload])
	var tickets := host.reward_service._tickets.size()
	var replay := service.journal_events(host, barrier, deaths, "t7_death", facade.current_profile().revision)
	var repeated := service.journal_events(host, barrier, deaths, "t7_death_again", facade.current_profile().revision)
	check(replay.get("ok", false) and host.reward_service._tickets.size() == tickets and host.reward_service._events.get(event_key) == ticket_id, "retry never mints a second ticket (replay ok, repeat: %s)" % [repeated.get("error_code", repeated.get("ok"))])
	# Collection happens out of combat (the game collects after the encounter, as in E07 F5).
	# Campaign combat ends five seconds after the last hostile damage without aggro links (E07 F5).
	host.combat_participation.observe({}, 5.0)
	check(not host.run_state.has_open_offer() and not host.inventory_frozen and not host.reward_service.has_pending_transaction(), "nothing else holds the collection (offer %s, frozen %s, finished %s, alive %s, encounter %s)" % [host.run_state.has_open_offer(), host.inventory_frozen, host.run_finished, host.player.is_alive(), host.encounter_active])
	print("collection guards: offer %s frozen %s finished %s alive %s encounter %s pending %s" % [host.run_state.has_open_offer(), host.inventory_frozen, host.run_finished, host.player.is_alive(), host.encounter_active, host.reward_service.has_pending_transaction()])
	var collected := service.collect(host, barrier, ticket_id, "t7_collect", facade.current_profile().revision)
	check(collected.get("ok", false), "the ticket is collected: " + str(collected.get("error_code", "")) + " " + str(collected.get("detail", "")))
	var after: CharacterState = facade.current_profile().character_by_id(host.run_state.character_id)
	check(after.base_xp_total == xp_before + int(payload["base_xp"]) and after.job_xp_total == job_before + int(payload["job_xp"]), "XP reaches the character exactly once (%d -> %d, +%d)" % [xp_before, after.base_xp_total, int(payload["base_xp"])])
	var again := service.collect(host, barrier, ticket_id, "t7_collect_again", facade.current_profile().revision)
	var final: CharacterState = facade.current_profile().character_by_id(host.run_state.character_id)
	check(final.base_xp_total == after.base_xp_total and final.job_xp_total == after.job_xp_total, "collecting again adds nothing (%s)" % [again.get("error_code", again.get("already_applied", again.get("ok")))])
	barrier.release()
	_finish(host)

## A copy of the lethal request as the attacker relayed it (same authorship, new instance).
func _replay_request(result: Dictionary, victim: EnemyActor) -> DamageRequest:
	var request := DamageRequest.new()
	request.source_id = int(result.get("source_id", 0))
	request.target_id = victim.get_instance_id()
	request.skill_id = StringName(result.get("skill_id", &"enemy_claw"))
	request.physical_damage = 100.0
	request.accuracy_mode = DamageRequest.AccuracyMode.GEOMETRY
	request.can_crit = false
	return request

func _finish(host: Node = null) -> void:
	paused = false
	if host != null and is_instance_valid(host): host.queue_free()
	await process_frame
	ClassKitRegistry.clear_fixtures()
	KitDecoy.unregister_drawer(MadnessRules.IDOL_DRAWER)
	print("E10a T7 cultist campaign kill: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
