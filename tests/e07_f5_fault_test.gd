extends "res://tests/fixtures/e07/f5/suite.gd"
func _run() -> void:
	var f := make("fault")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	var host: RunController = f["controller"]
	var actor: EnemyActor = host.campaign_runtime.actors["entry_field"]
	actor.health.current_hp = 0.0; actor.health._death_emitted = true
	host._on_enemy_died(actor)
	var payload := {"kind": "events", "events": host.campaign_runtime.pending_events.duplicate(true)}
	var before: ProfileState = f["facade"].current_profile()
	var store: Fault.FaultStore = f["store"]
	store.failure_stage = &"write_pending"
	var result := command(f, payload, "failed_death")
	check(not result["ok"] and f["facade"].current_profile().revision == before.revision, "known write failure keeps old durable revision")
	check(host.campaign_runtime.state.slots["entry_field"]["life_state"] == "alive" and not host.reward_service.has_uncollected(), "failed candidate publishes neither tombstone nor ticket")
	store.failure_stage = &""
	check(command(f, payload, "failed_death")["ok"], "retry frozen death succeeds once")
	host = f["controller"]
	check(host.reward_service._queue.size() == 1 and host.campaign_runtime.state.slots["entry_field"]["life_state"] == "dead", "single ticket agrees with committed tombstone")
	actor = host.campaign_runtime.actors["entry_boss"]
	actor.health.current_hp = 0.0; actor.health._death_emitted = true
	host._on_enemy_died(actor)
	payload = {"kind": "events", "events": host.campaign_runtime.pending_events.duplicate(true)}
	store.uncertain = true
	result = command(f, payload, "uncertain_death")
	check(not result["ok"] and result.get("read_only", false), "lost acknowledgment blocks new commands")
	check(command(f, payload, "other").get("error_code") == &"recovery_required", "uncertain intent cannot be bypassed")
	store.hide_reads = false
	result = f["service"].reconcile("uncertain_death")
	check(result["ok"] and result.get("durable", false), "canonical writer reconciles exact committed candidate")
	if result["ok"]: adopt(f, result)
	host = f["controller"]
	check(host.reward_service._queue.size() == 2 and host.campaign_runtime.state.portal_view("entry_to_left")["open"], "ticket, clear and portal published together after reconciliation")
	var primary := FileAccess.get_file_as_string(f["directory"].path_join("profile.json"))
	check(not primary.is_empty(), "durable envelope available for restart")
	dispose(f)
	finish_test()
