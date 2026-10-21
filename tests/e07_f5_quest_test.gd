extends "res://tests/fixtures/e07/f5/suite.gd"
func _run() -> void:
	var f := make("quest")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	check(kill(f, "entry_field", "field")["ok"] and kill(f, "entry_boss", "boss")["ok"], "route unlock")
	check(travel_to(f, "entry_to_left", "left")["ok"], "quest branch reached")
	var host: RunController = f["controller"]
	var quest_point: Dictionary
	for objective: Dictionary in host.campaign_runtime.state.manifest_data["objectives"]:
		if objective["objective_id"] == "quest_left": quest_point = objective["point"]
	relocate(f, quest_point)
	var profile: ProfileState = f["facade"].current_profile()
	var before := profile.character_by_id(host.run_state.character_id)
	var result := command(f, {"kind": "finish", "outcome": "quest", "source": "quest_left"}, "quest")
	check(result["ok"], "early quest suspends exact expedition")
	if not result["ok"]: print(result); dispose(f); finish_test(); return
	host = f["controller"]
	profile = f["facade"].current_profile()
	var after := profile.character_by_id(host.run_state.character_id)
	check(before.gold == after.gold and before.base_xp_total == after.base_xp_total and before.job_xp_total == after.job_xp_total, "early quest receives no implicit completion bonus")
	check(host.campaign_runtime.state.objectives.has("quest_left") and not host.campaign_runtime.state.completed and profile.reward_session == null, "objective and suspended state in same durable cut")
	var remaining := host.campaign_runtime.state.clock.remaining
	result = f["service"].resume("f5_expedition", host.run_state.character_id, "resume_quest", profile.revision)
	check(result["ok"], "quest continuation uses F4 resume")
	if result["ok"]:
		adopt(f, result)
		host = f["controller"]
		check(host.campaign_runtime.state.lifecycle == "active" and host.campaign_runtime.state.clock.remaining == remaining and host.run_state.pending_choices == 3, "resume retains layout, clock, claims and temporary build")
	dispose(f)
	finish_test()
