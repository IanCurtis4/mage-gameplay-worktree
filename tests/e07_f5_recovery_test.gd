extends "res://tests/fixtures/e07/f5/suite.gd"
func _run() -> void:
	var f := make("recovery")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	var host: RunController = f["controller"]
	host.player.attack_cooldown = 2.75
	host.player.mage_cooldowns[&"fireball"] = 11.5
	host.player.health.current_hp = 0.0
	host.player.health._death_emitted = true
	host.player._on_health_died(host.player.get_instance_id())
	var event_id: String = host.campaign_runtime.pending_events[0]["event_id"]
	var result := command(f, {"kind": "events", "events": host.campaign_runtime.pending_events.duplicate(true)}, "player_death1")
	check(result["ok"], "recovering state durable in same expediton")
	if not result["ok"]: print(result); dispose(f); finish_test(); return
	host = f["controller"]
	check(not host.player.is_alive() and host.campaign_runtime.state.lifecycle == "recovering" and host.run_state.pending_choices == 2, "death is recoverable; build and entry claims retained")
	var suspended: Dictionary = f["service"].checkpoint(host, f["barrier"], "f5_expedition", &"f5_fixture_phase", "suspend_dead", f["facade"].current_profile().revision, true)
	check(suspended["ok"], "dead character can suspend without reviving or discarding build")
	var reopened := ProfileFacade.new(f["store"])
	check(reopened.open_profile()["ok"], "reopen dead suspended expedition through canonical reader")
	f["facade"] = reopened
	f["service"] = ExpeditionService.new(reopened)
	var resumed: Dictionary = f["service"].resume("f5_expedition", host.run_state.character_id, "resume_dead", reopened.current_profile().revision)
	check(resumed["ok"], "resume dead expedition")
	if not resumed["ok"]: print(resumed); dispose(f); finish_test(); return
	adopt(f, resumed)
	check(f["controller"].campaign_runtime.state.lifecycle == "recovering" and not f["controller"].player.is_alive(), "resume is distinct from explicit revive")
	result = command(f, {"kind": "revive", "event_id": event_id}, "revive1")
	check(result["ok"], "recoverable death returns to initial anchor")
	if not result["ok"]: print(result); dispose(f); finish_test(); return
	host = f["controller"]
	check(host.player.is_alive() and host.player.health.current_hp == host.player.health.max_hp * 0.5 and host.player.current_sp == host.player.max_sp * 0.25, "approved HP/SP fractions after explicit revive")
	check(host.player.attack_cooldown == 2.75 and host.player.mage_cooldowns[&"fireball"] == 11.5, "all paid cooldowns survive death/reconstruction")
	check(not host.campaign_runtime.state.clock.started, "death before first clear accrues no wave debt")
	check(kill(f, "entry_field", "normal")["ok"] and kill(f, "entry_boss", "memo")["ok"], "complete clear arms global clock")
	host = f["controller"]
	host.campaign_runtime.state.clock.remaining = 100.0
	host.player.health.current_hp = 0.0; host.player.health._death_emitted = true
	host.player._on_health_died(host.player.get_instance_id())
	event_id = host.campaign_runtime.pending_events[0]["event_id"]
	check(command(f, {"kind": "events", "events": host.campaign_runtime.pending_events.duplicate(true)}, "player_death2")["ok"], "distinct death recorded")
	check(command(f, {"kind": "revive", "event_id": event_id}, "revive2")["ok"], "zero penalty boundary and eligible replenishment committed")
	host = f["controller"]
	check(host.campaign_runtime.state.clock.wave_index == 1 and host.campaign_runtime.state.clock.remaining == 900.0, "one wave, no excess debt")
	check(host.campaign_runtime.state.slots["entry_field"]["generation"] == 1 and host.campaign_runtime.state.slots["entry_boss"]["life_state"] == "dead", "trash returns exactly once and boss stays dead")
	var revision: int = f["facade"].current_profile().revision
	result = f["service"].revive(host, f["barrier"], event_id, "revive2", revision - 1)
	check(result.get("already_applied", false), "same request with original revision replays durable receipt")
	if result.has("root"): result["root"].free()
	check(f["facade"].current_profile().revision == revision, "retry cannot apply another penalty or material revision")
	dispose(f)
	finish_test()
