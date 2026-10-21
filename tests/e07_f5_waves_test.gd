extends "res://tests/fixtures/e07/f5/suite.gd"
func wave(f: Dictionary, request: String) -> Dictionary:
	var host: RunController = f["controller"]
	return command(f, {"kind": "events", "events": [{"kind": "wave", "wave_index": host.campaign_runtime.state.clock.wave_index}]}, request)
func _run() -> void:
	var f := make("waves")
	if not enter(f)["ok"]: dispose(f); finish_test(); return
	check(kill(f, "entry_field", "entry_field")["ok"] and kill(f, "entry_boss", "entry_boss")["ok"], "entry clear")
	check(travel_to(f, "entry_to_left", "left")["ok"], "first branch")
	check(kill(f, "left_field", "left_field")["ok"] and kill(f, "left_boss", "left_boss")["ok"], "second stage clear")
	check(travel_to(f, "left_to_entry", "back")["ok"], "return before global wave")
	var host: RunController = f["controller"]
	check(host.campaign_runtime.state.advance(900.0), "one global clock considers both cleared stages")
	check(wave(f, "wave1")["ok"], "wave persisted")
	host = f["controller"]
	check(host.campaign_runtime.state.slots["entry_field"]["generation"] == 1 and host.enemies.size() == 1, "active stage has one eligible replacement")
	check(host.campaign_runtime.state.slots["left_field"]["life_state"] == "respawn_pending" and host.campaign_runtime.state.slots["left_field"]["generation"] == 0, "unloaded stage retains a single intent without advancing local actors")
	check(host.campaign_runtime.state.slots["right_field"]["generation"] == 0 and not host.campaign_runtime.records.has("right"), "uncleared/unvisited stage not simulated or replenished")
	relocate(f, host.campaign_runtime.state.slots["entry_field"]["home"])
	check(kill(f, "entry_field", "replacement_death")["ok"], "generation-one death")
	host = f["controller"]
	host.campaign_runtime.state.advance(900.0)
	check(wave(f, "blocked_wave")["ok"], "occupied home preserves pending intent")
	host = f["controller"]
	check(host.campaign_runtime.state.slots["entry_field"]["generation"] == 1 and host.campaign_runtime.state.slots["entry_field"]["life_state"] == "respawn_pending", "player occupancy does not relocate or duplicate spawn")
	relocate(f, host.campaign_runtime.state.entrance("entry"))
	check(wave(f, "arrival_safe")["ok"], "vacated origin admits replacement")
	host = f["controller"]
	check(host.campaign_runtime.state.slots["entry_field"]["generation"] == 2 and host.enemies.size() == 1 and host.campaign_runtime.state.portal_view("entry_to_left")["open"], "second generation increments once and never closes portal")
	check(travel_to(f, "entry_to_left", "revisit_left")["ok"], "revisit with pending wave")
	host = f["controller"]
	check(host.campaign_runtime.state.slots["left_field"]["generation"] == 1 and host.enemies.size() == 1, "two elapsed waves yield one pending birth on return")
	check(host.campaign_runtime.state.slots["left_boss"]["life_state"] == "dead" and host.run_state.pending_choices == 3, "boss and entry claims remain resolved")
	dispose(f)
	finish_test()
