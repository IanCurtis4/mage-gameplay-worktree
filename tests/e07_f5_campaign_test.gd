extends "res://tests/fixtures/e07/f5/suite.gd"
func _run() -> void:
	var f := make("campaign")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	var host: RunController = f["controller"]
	check(host.geometer_casting == null, "stage services preserve mage class identity")
	check(host.run_state.pending_choices == 2 and host.campaign_runtime.actors.size() == 2, "first stage creates two claims and required population")
	check(command(f, {"kind": "travel", "portal_id": "entry_to_left", "stage_id": "entry"}, "closed").get("error_code") == &"portal_closed", "uncleared travel cannot bypass service")
	check(kill(f, "entry_field", "kill_field")["ok"], "normal death ticket/tombstone same commit")
	check(kill(f, "entry_boss", "kill_boss")["ok"], "mandatory memorable death opens portal atomically")
	host = f["controller"]
	var field_ticket: String = host.reward_service._events["mob:" + host.campaign_runtime.state.occurrence("entry_field").occurrence_id]
	check(host.reward_service.ticket(field_ticket)["payload"]["base_xp"] == 10, "initial EXP by origin, no stage EXP")
	check(host.run_state.pending_choices == 2, "clear grants no end-of-encounter augment")
	var hp := host.player.health.current_hp
	var sp := host.player.current_sp
	host.player.attack_cooldown = 1.25
	check(travel_to(f, "entry_to_left", "left")["ok"], "clear allows branch travel")
	host = f["controller"]
	check(host.run_state.pending_choices == 3 and host.player.health.current_hp == hp and host.player.current_sp == sp and host.player.attack_cooldown == 1.25, "first entry claim; travel never heals or clears cooldown")
	var living: EnemyActor = host.campaign_runtime.actors["left_field"]
	living.health._hp_deficit = 3.5
	living._mob_sp = maxf(0.0, living._mob_sp - 2.0)
	var expected_sp := living._mob_sp
	check(travel_to(f, "left_to_entry", "return")["ok"], "return remains allowed without clearing destination branch")
	host = f["controller"]
	check(host.run_state.pending_choices == 3 and host.campaign_runtime.state.clock.remaining == 900.0, "return preserves entry claims and global clock")
	check(travel_to(f, "entry_to_left", "revisit")["ok"], "revisit same realized branch")
	host = f["controller"]
	living = host.campaign_runtime.actors["left_field"]
	check(living.health._hp_deficit == 3.5 and living._mob_sp == expected_sp and host.run_state.pending_choices == 3, "unloaded actors retain exact HP/SP, no repeated entry grant")
	check(host.campaign_runtime.state.slots["entry_boss"]["life_state"] == "dead", "unloaded boss tombstone survives all reconstruction")
	dispose(f)
	finish_test()
