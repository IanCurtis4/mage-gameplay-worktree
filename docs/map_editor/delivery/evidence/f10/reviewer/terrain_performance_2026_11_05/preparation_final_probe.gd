extends SceneTree
const Phase = preload("res://scripts/map_authoring/release/phase_release.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var id := ""
	for phase: Dictionary in Phase.phases():
		if phase.title == "Floresta do Santuário": id = phase.phase_id
	if id.is_empty(): quit(1); return
	var rows: Array = []; var ok := true
	for label: String in ["cold_process","warm_process"]:
		var started := Time.get_ticks_usec()
		var prepared := Phase.prepare(id)
		var ms := (Time.get_ticks_usec()-started)/1000.0
		var digest := ExpeditionCanonical.digest(prepared.manifest.to_data()) if prepared.ok else ""
		var rules := ExpeditionCanonical.digest(prepared.rules) if prepared.ok else ""
		var valid: bool = prepared.ok and digest == "12271a4e44f456e7e2993bcd4d81a405717ab2463be0697a969964bac5916707" and rules == "369eaa4b7b69614cb34f1a2def38f1ed1c8f221860273ce28409cd67e3690e9d"
		ok = ok and valid
		rows.append({"label":label,"ok":valid,"total_ms":ms,"manifest_digest":digest,"rules_digest":rules,"lanes":prepared.get("preparation_lanes",0),"metrics":prepared.get("metrics",[]),"proof_hits_cumulative":WorldConnectivityBatch.preparation_proof_hits,"searches_cumulative":WorldConnectivityBatch.preparation_searches})
		print("PREPARATION_FINAL_SAMPLE ",JSON.stringify(rows[-1]))
	print("PREPARATION_FINAL_RESULT ",JSON.stringify({"ok":ok,"rows":rows})); quit(0 if ok else 1)
