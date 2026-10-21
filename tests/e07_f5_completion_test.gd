extends "res://tests/fixtures/e07/f5/suite.gd"
func collect_all(f: Dictionary) -> void:
	var host: RunController = f["controller"]
	while host.reward_service.has_uncollected():
		var ticket: String = host.reward_service._queue[0]
		var result: Dictionary = f["service"].collect(host, f["barrier"], ticket, "collect_" + ticket.md5_text(), f["facade"].current_profile().revision)
		check(result["ok"], "canonical material collection: " + str(result.get("error_code")))
		if not result["ok"]: break
func _run() -> void:
	var f := make("completion")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	for stage: String in ["entry", "right", "final"]:
		check(kill(f, stage + "_field", "field_" + stage)["ok"], "normal resolved: " + stage)
		check(kill(f, stage + "_boss", "boss_" + stage)["ok"], "memorable resolved: " + stage)
		collect_all(f)
		if stage != "final":
			var portal := "entry_to_right" if stage == "entry" else "right_to_final"
			var traveled := travel_to(f, portal, "travel_" + stage)
			check(traveled["ok"], "path to final destination: " + stage)
			if not traveled["ok"]: print(traveled); dispose(f); finish_test(); return
	var host: RunController = f["controller"]
	var exit_point: Dictionary
	for objective: Dictionary in host.campaign_runtime.state.manifest_data["objectives"]:
		if objective["objective_id"] == "final_exit": exit_point = objective["point"]
	relocate(f, exit_point)
	var profile: ProfileState = f["facade"].current_profile()
	var old_character := profile.character_by_id(host.run_state.character_id)
	var gold := old_character.gold
	var base_xp := old_character.base_xp_total
	var job_xp := old_character.job_xp_total
	var equipment_count := profile.equipment_instances.size()
	var result := command(f, {"kind": "finish", "outcome": "completed", "source": "final_exit"}, "finish")
	check(result["ok"], "completion through same writer: " + str(result.get("error_code")))
	if not result["ok"]: dispose(f); finish_test(); return
	host = f["controller"]
	profile = f["facade"].current_profile()
	var character := profile.character_by_id(host.run_state.character_id)
	check(character.gold == gold + 100 and character.base_xp_total == ProgressionRules.add_base_xp(base_xp, 300) and character.job_xp_total == ProgressionRules.add_job_xp(job_xp, 200, false), "single exact gold/Base/Job bonus")
	check(profile.equipment_instances.size() == equipment_count, "no guaranteed completion equipment")
	check(profile.reward_session == null and profile.expedition_for_character(host.run_state.character_id) == null, "completion releases session and character reservation")
	check(host.run_state.augment_stacks.is_empty() and host.run_state.pending_choices == 0 and host.campaign_runtime.state.completed, "completion ends temporary build and taint instance")
	var revision := profile.revision
	result = command(f, {"kind": "finish", "outcome": "completed", "source": "final_exit"}, "finish", false)
	check(result.get("already_applied", false) and f["facade"].current_profile().revision == revision, "completion retry grants nothing twice")
	check(f["facade"].current_profile().profile_unlocks.size() == 1, "profile unlock in same completion commit")
	dispose(f)
	finish_test()
