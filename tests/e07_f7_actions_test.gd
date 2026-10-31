extends SceneTree
const F = preload("res://tests/fixtures/e07/f2/fixture.gd")
var checks := 0
var failures := 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> bool:
	checks += 1
	if not value: failures += 1; push_error(label); quit(1)
	return value
func settled(previous: RunController) -> RunController:
	var deadline := Time.get_ticks_msec() + 90000
	while current_scene == previous and Time.get_ticks_msec() < deadline: await process_frame
	if not check(current_scene != previous, "event published a confirmed replacement"): return null
	paused = true
	return current_scene as RunController
# Checkpoint37: mob deaths alone are one campaign journal entry applied to this
# same host; the other events below still publish a confirmed replacement.
func journaled(host: RunController, slot: String) -> bool:
	var deadline := Time.get_ticks_msec() + 90000
	while (host.campaign_runtime.state.slots[slot]["life_state"] != "dead" or not host.campaign_runtime.pending_events.is_empty()) and Time.get_ticks_msec() < deadline: await process_frame
	if not check(current_scene == host and host.campaign_runtime.state.slots[slot]["life_state"] == "dead" and host.campaign_runtime.pending_events.is_empty(), "death is journaled on the same host"): return false
	var lock := host.persistent_facade.current_profile().expedition_for_character(host.run_state.character_id)
	if not check(lock != null and not lock.journal.is_empty(), "death entry is durable in the journal"): return false
	paused = true
	return true
func move_to(host: RunController, record: Dictionary) -> bool:
	var motion := host.player.world_motion
	var point := ExpeditionPopulationPlanner.point(record)
	if not check(motion.plan(point, motion.geometry.geometry_revision)["ok"], "legal portal route"): return false
	var moved := motion.advance(10000.0)
	if not check(moved["ok"] and moved["data"]["arrived"], "movement traverses the validated route without teleport"): return false
	host.expedition_view.sync()
	return true
func _run() -> void:
	var f := F.make("f7_ui_actions")
	var facade: ProfileFacade = f["facade"]
	var menu := CharacterMenu.new()
	menu.set_profile_facade(facade); root.add_child(menu); current_scene = menu
	var phase := PhaseSelectionPanel.new()
	menu.add_child(phase); phase.configure(menu, f["a"]); phase.seed_input.text = "43"
	var entered: Dictionary = await phase.start()
	if not check(entered.get("ok", false), "authored expedition entry"): return
	var host := current_scene as RunController
	paused = true
	for slot: String in ["entry_guard", "entry_keeper"]:
		var actor: EnemyActor = host.campaign_runtime.actors[slot]
		actor.health.current_hp = 0.0; actor.health._death_emitted = true
		host._on_enemy_died(actor)
		if not await journaled(host, slot): return
	check(host.campaign_runtime.state.stages["entry"]["cleared_once"], "complete manifest death events open the entry portals")
	host.combat_participation.observe({}, 6.0)
	if not check(not host.encounter_active, "canonical out-of-combat fixture window"): return
	var before_xp: int = facade.current_profile().character_by_id(f["a"]).base_xp_total
	var tickets := 0
	while host.reward_service.has_uncollected():
		var ticket := host.reward_service.next_pending_ticket()
		if not check(ticket.get("ok", false), "public pending ticket DTO"): return
		var original: Dictionary = ticket["payload"].duplicate(true)
		ticket["payload"]["base_xp"] = -1
		check(host.reward_service.next_pending_ticket()["payload"] == original, "pending ticket is a detached deep copy")
		var panel := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
		var collected: Dictionary = await panel.run_action({"kind": "collect", "ticket_id": ticket["ticket_id"]})
		if not check(collected.get("ok", false) and current_scene == host, "UI collection confirms in the existing host"): return
		tickets += 1
	check(tickets == 2 and facade.current_profile().character_by_id(f["a"]).base_xp_total == before_xp + 20, "two frozen origin tickets pay once")
	for portal_id: String in ["entry_to_left", "left_to_entry"]:
		var portal := host.campaign_runtime.state.portal_view(portal_id)
		if not move_to(host, portal["from_anchor"]): return
		var panel := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
		var travelled: Dictionary = await panel.run_action({"kind": "travel", "portal_id": portal_id, "stage_id": portal["from_stage"]})
		if not check(travelled.get("ok", false), "UI travel/return service intent"): return
		host = current_scene as RunController; paused = true
	check(host.run_state.pending_choices == 3 and host.campaign_runtime.state.current_stage_id == "entry", "return adds no second entry grant")
	var remaining: float = host.campaign_runtime.state.clock.remaining
	host.player.attack_cooldown = 1.25
	host.player.health.current_hp = 0.0; host.player.health._death_emitted = true
	host._on_player_died(host.player)
	host = await settled(host)
	if host == null: return
	check(host.campaign_runtime.state.lifecycle == "recovering", "death exposes recovery rather than a new run")
	var panel := host.ui_root.get_node("ExpeditionStatus") as ExpeditionStatusPanel
	var revived: Dictionary = await panel.run_action({"kind": "revive", "event_id": host.campaign_runtime.state.current_death_id})
	if not check(revived.get("ok", false), "UI revive uses the same expedition service"): return
	host = current_scene as RunController; paused = true
	check(host.player.is_alive() and host.player.health.current_hp == host.player.health.max_hp * 0.5, "approved half-HP return")
	check(host.player.attack_cooldown == 1.25 and host.run_state.pending_choices == 3, "return preserves cooldown and build grants")
	check(host.campaign_runtime.state.clock.remaining < remaining and host.campaign_runtime.state.current_stage_id == "entry", "death penalizes the existing clock and returns to last arrival")
	print("E07 F7 actions: %d checks, %d failures" % [checks, failures])
	host.queue_free(); paused = false
	await process_frame
	quit(0 if failures == 0 else 1)
