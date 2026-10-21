extends Control
var facade: ProfileFacade
var events := 0
var saw_durable_cursor := false
func confirmed(_receipt: Dictionary) -> void:
	events += 1
	saw_durable_cursor = facade.current_profile().expeditions["fixture_expedition"].checkpoint["session"]["last_committed_seq"] == 1
